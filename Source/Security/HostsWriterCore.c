#include "HostsWriterCore.h"
#include <CommonCrypto/CommonDigest.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/stat.h>
#include <sys/acl.h>
#include <sys/errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

int GMValidUTF8(const void *bytes, size_t length) {
    if (length > GM_MAX_HOSTS_BYTES || (length && (!bytes || memchr(bytes, 0, length)))) return 0;
    if (!length) return 1;
    CFStringRef text = CFStringCreateWithBytes(NULL, bytes, (CFIndex)length, kCFStringEncodingUTF8, false);
    if (!text) return 0;
    CFRelease(text); return 1;
}

static int readLeaf(int dir, const char *leaf, uid_t owner, struct stat *metadata, uint8_t digest[32]) {
    int fd = openat(dir, leaf, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    if (fd < 0) return GM_UNSAFE_TARGET;
    int status = GM_UNSAFE_TARGET;
    if (fstat(fd, metadata) || !S_ISREG(metadata->st_mode) || metadata->st_uid != owner || metadata->st_nlink != 1) goto done;
    if (metadata->st_size < 0 || metadata->st_size > GM_MAX_HOSTS_BYTES) { status = GM_TOO_LARGE; goto done; }
    CC_SHA256_CTX hash; CC_SHA256_Init(&hash);
    uint8_t block[65536]; ssize_t count; size_t total=0;
    while ((count = read(fd, block, sizeof block)) != 0) {
        if (count < 0) { if (errno == EINTR) continue; status=GM_IO; goto done; }
        total += (size_t)count;
        if (total > GM_MAX_HOSTS_BYTES) { status=GM_TOO_LARGE; goto done; }
        CC_SHA256_Update(&hash, block, (CC_LONG)count);
    }
    struct stat after;
    if (fstat(fd, &after) || after.st_size != metadata->st_size ||
        after.st_mtimespec.tv_sec != metadata->st_mtimespec.tv_sec || after.st_mtimespec.tv_nsec != metadata->st_mtimespec.tv_nsec ||
        total != (size_t)metadata->st_size) { status=GM_CONFLICT; goto done; }
    CC_SHA256_Final(digest, &hash); status=GM_OK;
done:
    close(fd); return status;
}

int GMHostsDigest(int dir, uid_t owner, uint8_t digest[32]) {
    struct stat metadata; return readLeaf(dir, "hosts", owner, &metadata, digest);
}

int GMApplyHosts(int dir, uid_t owner, const void *bytes, size_t length,
                 const uint8_t expected[32], uint8_t result[32]) {
    if (length > GM_MAX_HOSTS_BYTES) return GM_TOO_LARGE;
    if (!GMValidUTF8(bytes, length)) return GM_INVALID;
    struct stat directory, before;
    if (fstat(dir, &directory) || !S_ISDIR(directory.st_mode) || directory.st_uid != owner || (directory.st_mode & 0022)) return GM_UNSAFE_TARGET;
    acl_t directoryACL = acl_get_fd(dir);
    acl_entry_t directoryEntry;
    if (!directoryACL && errno != ENOENT) return GM_UNSAFE_TARGET;
    int hasDirectoryACL = directoryACL && acl_get_entry(directoryACL, ACL_FIRST_ENTRY, &directoryEntry) == 1;
    if (directoryACL) acl_free(directoryACL);
    if (hasDirectoryACL) return GM_UNSAFE_TARGET;
    uint8_t current[32];
    int status = readLeaf(dir, "hosts", owner, &before, current);
    if (status != GM_OK) return status;
    if (memcmp(current, expected, 32)) return GM_CONFLICT;
    char temporary[64];
    snprintf(temporary, sizeof temporary, ".gasmask-%08x%08x", arc4random(), arc4random());
    int fd = openat(dir, temporary, O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC, 0600);
    if (fd < 0) return GM_IO;
    status=GM_IO;
    size_t offset=0;
    while (offset < length) {
        ssize_t count = write(fd, (const uint8_t*)bytes+offset, length-offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) goto cleanup;
        offset += (size_t)count;
    }
    // Never carry the legacy per-user write ACL into the replacement inode.
    acl_t empty = acl_init(0);
    if (!empty) goto cleanup;
    int aclResult = acl_set_fd(fd, empty); acl_free(empty);
    if (aclResult || fchown(fd, owner, owner == 0 ? 0 : getgid()) || fchmod(fd, 0644) || fsync(fd)) goto cleanup;
    struct stat now;
    if (fstatat(dir, "hosts", &now, AT_SYMLINK_NOFOLLOW) || !S_ISREG(now.st_mode) ||
        now.st_dev != before.st_dev || now.st_ino != before.st_ino || now.st_nlink != 1 || now.st_uid != owner) {
        status=GM_CONFLICT; goto cleanup;
    }
    // Atomic exchange keeps the old inode until the commit is durable. A failed
    // pre-commit step cannot truncate the system file or follow a replacement link.
    if (renameatx_np(dir, temporary, dir, "hosts", RENAME_SWAP)) goto cleanup;
    // A legacy user-write ACL may have allowed an in-place edit between the
    // initial hash and swap. Validate the retained old inode after exchange too.
    struct stat retained;
    uint8_t retainedHash[32];
    int retainedStatus = readLeaf(dir, temporary, owner, &retained, retainedHash);
    int conflict = retainedStatus != GM_OK || retained.st_ino != before.st_ino || memcmp(retainedHash, expected, 32);
    if (conflict || (fsync(dir) && errno != EINVAL && errno != ENOTSUP)) {
        status = conflict ? GM_CONFLICT : GM_IO;
        if (renameatx_np(dir, temporary, dir, "hosts", RENAME_SWAP) == 0) { fsync(dir); goto cleanup; }
        // A committed write with failed rollback is reported explicitly; never
        // claim the old file is intact. The returned digest lets the caller verify.
        GMHostsDigest(dir, owner, result); close(fd); return GM_IO; // retain the old inode for recovery
    }
    CC_SHA256(bytes, (CC_LONG)length, result);
    status=GM_OK;
cleanup:
    close(fd); unlinkat(dir, temporary, 0); return status;
}
