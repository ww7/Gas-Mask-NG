#include "HostsWriterPeer.h"
#include <Security/Security.h>
#include <bsm/libbsm.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <string.h>

int GMValidatePeer(int fd, pid_t pid, uid_t uid, const uint8_t hash[20]) {
    audit_token_t audit; socklen_t size=sizeof audit;
    if (getsockopt(fd, SOL_LOCAL, LOCAL_PEERTOKEN, &audit, &size) || size != sizeof audit ||
        audit_token_to_pid(audit) != pid || audit_token_to_euid(audit) != uid || audit_token_to_ruid(audit) != uid) return 0;
    CFDataRef data=CFDataCreate(NULL, (const UInt8*)&audit, sizeof audit);
    const void *keys[]={kSecGuestAttributeAudit}; const void *values[]={data};
    CFDictionaryRef attributes=CFDictionaryCreate(NULL, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    SecCodeRef code=NULL; CFDictionaryRef info=NULL;
    int valid=0;
    if (SecCodeCopyGuestWithAttributes(NULL, attributes, kSecCSDefaultFlags, &code) != errSecSuccess ||
        SecCodeCheckValidity(code, kSecCSStrictValidate, NULL) != errSecSuccess ||
        SecCodeCopySigningInformation(code, kSecCSSigningInformation, &info) != errSecSuccess) goto done;
    CFNumberRef flags = CFDictionaryGetValue(info, kSecCodeInfoFlags);
    uint32_t flagValue = 0;
    if (!flags || CFGetTypeID(flags) != CFNumberGetTypeID() || !CFNumberGetValue(flags, kCFNumberSInt32Type, &flagValue) ||
        !(flagValue & kSecCodeSignatureRuntime)) goto done;
    CFDataRef actual=CFDictionaryGetValue(info, kSecCodeInfoUnique);
    if (!actual || CFGetTypeID(actual) != CFDataGetTypeID() || CFDataGetLength(actual) != 20 || memcmp(CFDataGetBytePtr(actual), hash, 20)) goto done;
    CFDictionaryRef entitlements=CFDictionaryGetValue(info, kSecCodeInfoEntitlementsDict);
    if (entitlements && CFGetTypeID(entitlements) == CFDictionaryGetTypeID()) {
        CFStringRef forbidden[] = {CFSTR("com.apple.security.get-task-allow"),
            CFSTR("com.apple.security.cs.disable-library-validation"),
            CFSTR("com.apple.security.cs.allow-dyld-environment-variables"),
            CFSTR("com.apple.security.cs.allow-unsigned-executable-memory"),
            CFSTR("com.apple.security.cs.disable-executable-page-protection")};
        for (size_t i=0;i<sizeof forbidden/sizeof forbidden[0];i++)
            if(CFDictionaryGetValue(entitlements,forbidden[i])==kCFBooleanTrue)goto done;
    }
    valid=1;
done:
    if (info) CFRelease(info); if (code) CFRelease(code);
    CFRelease(attributes); CFRelease(data); return valid;
}
