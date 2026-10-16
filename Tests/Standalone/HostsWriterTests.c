#include "HostsWriterCore.h"
#include "HostsWriterPeer.h"
#include <Security/Security.h>
#include <CommonCrypto/CommonDigest.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/acl.h>
#include <membership.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#define CHECK(value) do { if (!(value)) { fprintf(stderr,"FAIL line %d: %s (errno=%d)\n",__LINE__,#value,errno); exit(1); } checks++; } while(0)
static unsigned checks;
static int failWrite, failSync, failDirectorySync, failSwap;
ssize_t GMFixtureWrite(int fd, const void *bytes, size_t size) {
    if(failWrite) { failWrite=0; errno=ENOSPC; return -1; } return write(fd,bytes,size);
}
int GMFixtureFsync(int fd) {
    struct stat info; fstat(fd,&info);
    if(failSync || (failDirectorySync && S_ISDIR(info.st_mode))) {
        failSync=0;failDirectorySync=0;errno=EIO;return -1;
    } return fsync(fd);
}
int GMFixtureRename(int a,const char*b,int c,const char*d,unsigned flags) {
    if(failSwap) { failSwap=0;errno=EIO;return -1; }return renameatx_np(a,b,c,d,flags);
}
static void writeAt(int dir, const char *leaf, const char *text) {
    int fd=openat(dir,leaf,O_CREAT|O_TRUNC|O_WRONLY|O_NOFOLLOW,0600); CHECK(fd>=0);
    CHECK(write(fd,text,strlen(text))==(ssize_t)strlen(text)); CHECK(close(fd)==0);
}
int main(int argc, char **argv) {
    int unsafe = argc == 2 && !strcmp(argv[1], "--expect-unsafe-signature");
    char directory[]="/private/tmp/gasmask-writer-test.XXXXXXXX";
    CHECK(mkdtemp(directory)); int dir=open(directory,O_DIRECTORY|O_RDONLY); CHECK(dir>=0);
    const char *old="127.0.0.1 original.test\n", *next="::1 replacement.test\n";
    writeAt(dir,"hosts",old); uint8_t expected[32], result[32], hash[32];
    CHECK(GMHostsDigest(dir,getuid(),expected)==GM_OK);
    int legacy=openat(dir,"hosts",O_RDONLY);CHECK(legacy>=0);
    acl_t granted=acl_init(1);acl_entry_t added;CHECK(acl_create_entry(&granted,&added)==0);
    uuid_t user;CHECK(mbr_uid_to_uuid(getuid(),user)==0);
    CHECK(acl_set_tag_type(added,ACL_EXTENDED_ALLOW)==0 && acl_set_qualifier(added,user)==0);
    acl_permset_t permissions;CHECK(acl_get_permset(added,&permissions)==0 && acl_add_perm(permissions,ACL_WRITE_DATA)==0);
    CHECK(acl_set_fd(legacy,granted)==0);acl_free(granted);close(legacy);
    CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_OK);
    CC_SHA256(next,(CC_LONG)strlen(next),hash); CHECK(!memcmp(hash,result,32));
    struct stat info; CHECK(fstatat(dir,"hosts",&info,AT_SYMLINK_NOFOLLOW)==0);
    CHECK(info.st_uid==getuid() && (info.st_mode&0777)==0644 && info.st_nlink==1);
    int target=openat(dir,"hosts",O_RDONLY); acl_t acl=acl_get_fd(target); CHECK(acl!=NULL || errno==ENOENT);
    acl_entry_t entry; CHECK(acl==NULL || (acl_get_entry(acl,ACL_FIRST_ENTRY,&entry)==-1 && errno==EINVAL)); if(acl)acl_free(acl);close(target);
    CHECK(GMApplyHosts(dir,getuid(),old,strlen(old),expected,result)==GM_CONFLICT);
    CHECK(GMApplyHosts(dir,getuid(),"\xff",1,hash,result)==GM_INVALID);
    CHECK(GMApplyHosts(dir,getuid(),"x\0y",3,hash,result)==GM_INVALID);
    CHECK(GMApplyHosts(dir,getuid(),NULL,GM_MAX_HOSTS_BYTES+1,hash,result)==GM_TOO_LARGE);
    CHECK(GMHostsDigest(dir,getuid(),result)==GM_OK && !memcmp(hash,result,32));
    CHECK(linkat(dir,"hosts",dir,"alias",0)==0);
    CHECK(GMApplyHosts(dir,getuid(),old,strlen(old),hash,result)==GM_UNSAFE_TARGET);
    CHECK(unlinkat(dir,"alias",0)==0); CHECK(unlinkat(dir,"hosts",0)==0);
    writeAt(dir,"victim",old); CHECK(symlinkat("victim",dir,"hosts")==0);
    CHECK(GMHostsDigest(dir,getuid(),result)==GM_UNSAFE_TARGET);
    CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),hash,result)==GM_UNSAFE_TARGET);
    CHECK(unlinkat(dir,"hosts",0)==0); CHECK(mkdirat(dir,"hosts",0700)==0);
    CHECK(GMHostsDigest(dir,getuid(),result)==GM_UNSAFE_TARGET);
    CHECK(unlinkat(dir,"hosts",AT_REMOVEDIR)==0);
    CHECK(mkfifoat(dir,"hosts",0600)==0);
    CHECK(GMHostsDigest(dir,getuid(),result)==GM_UNSAFE_TARGET);
    CHECK(unlinkat(dir,"hosts",0)==0);writeAt(dir,"hosts",old);
    CHECK(GMHostsDigest(dir,getuid()+1,result)==GM_UNSAFE_TARGET);
    // Darwin returns 0 for a found ACL entry (not POSIX's 1). Refuse
    // even an owner-only directory ACE: a mode-bit check alone is insufficient.
    granted=acl_init(1);CHECK(acl_create_entry(&granted,&added)==0);
    CHECK(acl_set_tag_type(added,ACL_EXTENDED_ALLOW)==0 && acl_set_qualifier(added,user)==0);
    CHECK(acl_get_permset(added,&permissions)==0 && acl_add_perm(permissions,ACL_WRITE_DATA)==0);
    CHECK(acl_set_fd(dir,granted)==0);acl_free(granted);
    CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_UNSAFE_TARGET);
    granted=acl_init(0);CHECK(acl_set_fd(dir,granted)==0);acl_free(granted);
    CHECK(fchmod(dir,0777)==0);
    CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_UNSAFE_TARGET);
    CHECK(fchmod(dir,0700)==0);
    // Fault injection exists only in this standalone core object; release builds
    // compile the ordinary libc calls, with no runtime test switch.
    failWrite=1;CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_IO);
    CHECK(GMHostsDigest(dir,getuid(),hash)==GM_OK && !memcmp(hash,expected,32));
    failSync=1;CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_IO);
    CHECK(GMHostsDigest(dir,getuid(),hash)==GM_OK && !memcmp(hash,expected,32));
    failSwap=1;CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_IO);
    CHECK(GMHostsDigest(dir,getuid(),hash)==GM_OK && !memcmp(hash,expected,32));
    failDirectorySync=1;CHECK(GMApplyHosts(dir,getuid(),next,strlen(next),expected,result)==GM_IO);
    CHECK(GMHostsDigest(dir,getuid(),hash)==GM_OK && !memcmp(hash,expected,32));
    CHECK(GMApplyHosts(dir,getuid(),NULL,0,expected,result)==GM_OK);
    CHECK(fstatat(dir,"hosts",&info,0)==0 && info.st_size==0);
    CHECK(GMValidUTF8("# українська\n",strlen("# українська\n")));
    CHECK(!GMValidUTF8("\xc0\xaf",2));
    // Kernel audit-token and exact code identity: use a real local connection,
    // not socketpair (which has no connecting peer audit token on macOS).
    char socketPath[104];snprintf(socketPath,sizeof socketPath,"%s/peer",directory);
    struct sockaddr_un address={0};address.sun_family=AF_UNIX;strlcpy(address.sun_path,socketPath,sizeof address.sun_path);
    int listener=socket(AF_UNIX,SOCK_STREAM,0), client=socket(AF_UNIX,SOCK_STREAM,0);CHECK(listener>=0 && client>=0);
    CHECK(bind(listener,(struct sockaddr*)&address,sizeof address)==0 && listen(listener,1)==0);
    CHECK(connect(client,(struct sockaddr*)&address,sizeof address)==0); int peer=accept(listener,NULL,NULL);CHECK(peer>=0);
    SecCodeRef code=NULL;CFDictionaryRef signing=NULL; CHECK(SecCodeCopySelf(0,&code)==errSecSuccess);
    CHECK(SecCodeCopySigningInformation(code,kSecCSSigningInformation,&signing)==errSecSuccess);
    CFDataRef cdhash=CFDictionaryGetValue(signing,kSecCodeInfoUnique); CHECK(cdhash && CFDataGetLength(cdhash)==20);
    uint8_t correct[20];memcpy(correct,CFDataGetBytePtr(cdhash),20);
    CHECK(GMValidatePeer(peer,getpid(),getuid(),correct) == !unsafe);
    CHECK(!GMValidatePeer(peer,getpid()+1,getuid(),correct));
    CHECK(!GMValidatePeer(peer,getpid(),getuid()+1,correct));
    correct[0]^=1;CHECK(!GMValidatePeer(peer,getpid(),getuid(),correct));
    CFRelease(signing);CFRelease(code);close(peer);close(client);close(listener);
    CHECK(unlink(socketPath)==0);CHECK(unlinkat(dir,"hosts",0)==0);CHECK(unlinkat(dir,"victim",0)==0);
    close(dir);CHECK(rmdir(directory)==0);
    printf("Hosts writer: %u fixture assertions passed; no system-file writes.\n",checks);return 0;
}
