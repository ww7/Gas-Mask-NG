/***************************************************************************
 *   Copyright (C) 2009-2013 by Clockwise   *
 *   copyright@clockwise.ee   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

#import "PrivilegedActions.h"
#import "Security/HostsWriterCore.h"
#import "HostsWriterHash.h"
#import <AppKit/AppKit.h>
#import <Security/Security.h>
#import <Carbon/Carbon.h>
#import <CommonCrypto/CommonDigest.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/stat.h>
#import <sys/acl.h>
#import <arpa/inet.h>
#import <fcntl.h>
#import <unistd.h>

static int sessionFD = -1;
static BOOL authorizing;
static NSString *const WriterErrorDomain = @"work.ww7.gasmask.writer";

static NSString *hex(const void *bytes, NSUInteger length) {
    const unsigned char *buffer=bytes; NSMutableString *result=[NSMutableString new];
    for(NSUInteger i=0;i<length;i++)[result appendFormat:@"%02x",buffer[i]];
    return result;
}
static NSData *digest(NSData *data) {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes,(CC_LONG)data.length,hash);
    return [NSData dataWithBytes:hash length:sizeof hash];
}
static BOOL exactIO(int fd, void *buffer, size_t size, BOOL writing) {
    size_t at=0;
    while(at<size) {
        ssize_t count=writing ? write(fd,(char*)buffer+at,size-at) : read(fd,(char*)buffer+at,size-at);
        if(count<0 && errno==EINTR)continue;
        if(count<=0)return NO;
        at+=(size_t)count;
    }
    return YES;
}
static BOOL fail(NSError **output, NSInteger code, NSString *message) {
    if(output)*output=[NSError errorWithDomain:WriterErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}

static NSData *readSystemHosts(void) {
    int fd=open("/private/etc/hosts",O_RDONLY|O_NOFOLLOW|O_CLOEXEC|O_NONBLOCK);
    if(fd<0)return nil;
    struct stat info;
    if(fstat(fd,&info) || !S_ISREG(info.st_mode) || info.st_uid!=0 || info.st_nlink!=1 ||
       info.st_size<0 || info.st_size>GM_MAX_HOSTS_BYTES) { close(fd); return nil; }
    NSMutableData *result=[NSMutableData data];
    unsigned char buffer[65536];
    for(;;) {
        ssize_t count=read(fd,buffer,sizeof buffer);
        if(count<0 && errno==EINTR)continue;
        if(count==0)break;
        if(count<0 || (size_t)count>GM_MAX_HOSTS_BYTES-result.length) { close(fd);return nil; }
        [result appendBytes:buffer length:(NSUInteger)count];
    }
    close(fd);return result;
}
@implementation PrivilegedActions
+ (BOOL)trustedDirectoryAtPath:(NSString*)path owner:(uid_t)owner {
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    if(fd<0)return NO;
    struct stat info;
    BOOL safe=!fstat(fd,&info) && S_ISDIR(info.st_mode) && info.st_uid==owner && !(info.st_mode&0022);
    acl_t acl=acl_get_fd(fd);
    if(acl) {
        acl_entry_t entry;errno=0;
        int found=acl_get_entry(acl,ACL_FIRST_ENTRY,&entry);
        safe=safe && found==-1 && errno==EINVAL; // Darwin: 0 means an entry exists
        acl_free(acl);
    } else if(errno!=ENOENT) safe=NO;
    close(fd);return safe;
}
+ (NSString*)quotedShellArgument:(NSString*)value {
    return [NSString stringWithFormat:@"'%@'",[value stringByReplacingOccurrencesOfString:@"'" withString:@"'\"'\"'"]];
}
+ (NSString*)bootstrapCommandForHelper:(NSString*)path digest:(NSString*)hash pid:(pid_t)pid uid:(uid_t)uid codeHash:(NSString*)codeHash {
    NSCharacterSet *nonHex=[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    if(!path.isAbsolutePath || [path rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location!=NSNotFound ||
        hash.length!=64 || codeHash.length!=40 || [hash rangeOfCharacterFromSet:nonHex].location!=NSNotFound ||
        [codeHash rangeOfCharacterFromSet:nonHex].location!=NSNotFound || pid<=0 || uid==0)return nil;
    NSString *script=[NSString stringWithFormat:
        @"set -eu\numask 077\n"
         "stage=$(/usr/bin/mktemp -d /private/var/db/gas-mask-ng.XXXXXXXX)\n"
         "trap '/bin/rm -f \"$stage/writer\" \"$stage/control.sock\"; /bin/rmdir \"$stage\" 2>/dev/null || true' EXIT\n"
         "/bin/cp -X %@ \"$stage/writer\"\n/bin/chmod 700 \"$stage/writer\"\n/usr/sbin/chown 0:0 \"$stage/writer\"\n"
         "actual=$(/usr/bin/shasum -a 256 \"$stage/writer\")\n[ \"${actual%%%% *}\" = %@ ]\n"
         "/bin/chmod 711 \"$stage\"\n"
         "/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C \"$stage/writer\" --serve %d %u %@ \"$stage\"\n"
         "trap - EXIT\nprintf '%%s/control.sock' \"$stage\"",
        [self quotedShellArgument:path],[self quotedShellArgument:hash],pid,uid,[self quotedShellArgument:codeHash]];
    return [@"/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C /bin/sh -c " stringByAppendingString:[self quotedShellArgument:script]];
}
+ (NSString*)currentSystemContents {
    if(NSClassFromString(@"XCTestCase"))return nil;
    NSData *data=readSystemHosts();
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

+ (NSString*)authorizationScriptSource {
    return @"on runauthorized(commandText, promptText)\n do shell script commandText with administrator privileges with prompt promptText\nend runauthorized";
}
+ (BOOL)hasAuthorizedSession { return sessionFD>=0; }
+ (void)endSession { if(sessionFD>=0)close(sessionFD); sessionFD=-1; }

+ (BOOL)startSession:(NSError**)output {
    NSAssert(NSThread.isMainThread,@"Authorization is a foreground app action");
    if(authorizing)return fail(output,GM_UNAUTHORIZED,@"Administrator approval is already in progress.");
    if(NSClassFromString(@"XCTestCase"))return fail(output,GM_UNAUTHORIZED,@"Live system authorization is disabled in the test host.");
    // The execution stage must not be renameable by a non-root user/group.
    // /var/run can be group-writable (daemon) on macOS; use root-only parents.
    for(NSString *parent in @[@"/private",@"/private/var",@"/private/var/db"])
        if(![self trustedDirectoryAtPath:parent owner:0])return fail(output,GM_UNSAFE_TARGET,@"A secure root-owned staging directory is unavailable. System changes were refused.");
    SecCodeRef ownCode=NULL; CFDictionaryRef signing=NULL;
    OSStatus result=SecCodeCopySelf(kSecCSDefaultFlags,&ownCode);
    if(result==errSecSuccess)result=SecCodeCheckValidity(ownCode,kSecCSStrictValidate,NULL);
    if(result==errSecSuccess)result=SecCodeCopySigningInformation(ownCode,kSecCSSigningInformation,&signing);
    NSData *codeHash=signing ? [(__bridge NSDictionary*)signing objectForKey:(__bridge NSString*)kSecCodeInfoUnique] : nil;
    NSNumber *flags=signing ? [(__bridge NSDictionary*)signing objectForKey:(__bridge NSString*)kSecCodeInfoFlags] : nil;
    NSString *identifier=codeHash.length==20 && (flags.unsignedIntValue & kSecCodeSignatureRuntime) ? hex(codeHash.bytes,codeHash.length) : nil;
    if(signing)CFRelease(signing);if(ownCode)CFRelease(ownCode);
    if(result!=errSecSuccess || !identifier)return fail(output,GM_UNAUTHORIZED,@"This application bundle failed its local integrity check. Reinstall the release archive.");
    NSString *helper=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Helpers/HostsWriter"];
    struct stat helperInfo;
    if(lstat(helper.fileSystemRepresentation,&helperInfo) || !S_ISREG(helperInfo.st_mode) || helperInfo.st_nlink!=1 || helperInfo.st_size>4*1024*1024)
        return fail(output,GM_UNAUTHORIZED,@"The bundled hosts writer is missing or unsafe.");
    NSData *helperData=[NSData dataWithContentsOfFile:helper];
    NSString *actual=helperData ? hex(digest(helperData).bytes,CC_SHA256_DIGEST_LENGTH) : nil;
    if(![actual isEqualToString:GM_HOSTS_WRITER_SHA256])return fail(output,GM_UNAUTHORIZED,@"The bundled hosts writer failed its pinned hash check.");
    NSString *command=[self bootstrapCommandForHelper:helper digest:GM_HOSTS_WRITER_SHA256 pid:getpid() uid:getuid() codeHash:identifier];
    if(!command)return fail(output,GM_UNAUTHORIZED,@"The hosts-writer launch request was invalid.");
    // Arguments cross the AppleScript boundary as descriptors, never as source.
    NSAppleScript *script=[[NSAppleScript alloc] initWithSource:[self authorizationScriptSource]];
    NSAppleEventDescriptor *event=[NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent
        targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
    [event setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:@"runauthorized"] forKeyword:keyASSubroutineName];
    NSAppleEventDescriptor *arguments=[NSAppleEventDescriptor listDescriptor];
    [arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:command] atIndex:1];
    [arguments insertDescriptor:[NSAppleEventDescriptor descriptorWithString:@"Allow Gas Mask NG to apply hosts changes for this app session. No permanent system-file write permission is granted."] atIndex:2];
    [event setParamDescriptor:arguments forKeyword:keyDirectObject];
    NSDictionary *scriptError=nil;
    authorizing=YES;
    NSAppleEventDescriptor *reply=[script executeAppleEvent:event error:&scriptError];
    authorizing=NO;
    if(!reply) return fail(output,[scriptError[NSAppleScriptErrorNumber] integerValue]==-128 ? NSUserCancelledError : GM_UNAUTHORIZED,
        @"System changes were not authorized. Your profile remains available; try Activate again when ready.");
    NSString *socketPath=reply.stringValue;
    NSString *parent=socketPath.stringByDeletingLastPathComponent;
    struct stat stageInfo;
    if(![socketPath hasPrefix:@"/private/var/db/gas-mask-ng."] || ![socketPath.lastPathComponent isEqualToString:@"control.sock"] ||
        socketPath.length>=sizeof(((struct sockaddr_un*)0)->sun_path) || lstat(parent.fileSystemRepresentation,&stageInfo) ||
        !S_ISDIR(stageInfo.st_mode) || stageInfo.st_uid!=0 || (stageInfo.st_mode&0022))
        return fail(output,GM_UNAUTHORIZED,@"The hosts writer did not return a safe session endpoint.");
    int fd=socket(AF_UNIX,SOCK_STREAM,0);
    if(fd<0)return fail(output,GM_IO,@"Could not open the hosts-writer connection.");
    fcntl(fd,F_SETFD,FD_CLOEXEC);
    int noSignal=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&noSignal,sizeof noSignal);
    struct timeval timeout={15,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof timeout);
    struct sockaddr_un address={0};address.sun_family=AF_UNIX;strlcpy(address.sun_path,socketPath.fileSystemRepresentation,sizeof address.sun_path);
    uid_t peerUID;gid_t peerGID;
    if(connect(fd,(struct sockaddr*)&address,sizeof address) || getpeereid(fd,&peerUID,&peerGID) || peerUID!=0) {
        close(fd);return fail(output,GM_UNAUTHORIZED,@"Could not authenticate the administrator-approved hosts writer.");
    }
    struct GMRequest hello={0};hello.magic=htonl(GM_PROTOCOL_MAGIC);hello.operation=htonl(GM_OPERATION_STATUS);
    struct GMReply welcome;
    if(!exactIO(fd,&hello,sizeof hello,YES) || !exactIO(fd,&welcome,sizeof welcome,NO) ||
        ntohl(welcome.magic)!=GM_PROTOCOL_MAGIC || ntohl(welcome.status)!=GM_OK) {
        close(fd);return fail(output,GM_UNAUTHORIZED,@"The writer rejected this app or the system hosts file. Symlinks, hard links and unsafe targets are refused.");
    }
    sessionFD=fd;return YES;
}

+ (BOOL)writeHostsContents:(NSString*)contents allowAuthorization:(BOOL)interactive error:(NSError**)output {
    NSAssert(NSThread.isMainThread,@"Serialize system writes on the model's main thread");
    NSData *data=[contents dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!data || data.length>GM_MAX_HOSTS_BYTES || [contents rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location!=NSNotFound)
        return fail(output,GM_INVALID,@"Hosts text must be UTF-8 without NUL bytes and no larger than 32 MiB.");
    if(authorizing)return fail(output,GM_UNAUTHORIZED,@"System changes are waiting for administrator approval.");
    if (NSClassFromString(@"XCTestCase")) return fail(output,GM_UNAUTHORIZED,@"System writes are disabled in the test host; use a fixture controller.");
    if (sessionFD<0 && !interactive) return fail(output,GM_UNAUTHORIZED,@"Activate to approve system changes for this session.");
    NSData *current=readSystemHosts();
    if(!current || current.length>GM_MAX_HOSTS_BYTES)return fail(output,GM_UNSAFE_TARGET,@"Could not safely read the current system hosts file.");
    // Capture the expected system state before any administrator dialog.
    // No automatic prompts from a timer, download, watcher, or startup.
    if(sessionFD<0 && (!interactive || ![self startSession:output])) {
        if(!interactive)fail(output,GM_UNAUTHORIZED,@"Activate to approve system changes for this session.");
        return NO;
    }
    struct GMRequest request={0};request.magic=htonl(GM_PROTOCOL_MAGIC);request.operation=htonl(GM_OPERATION_WRITE);request.length=htonl((uint32_t)data.length);
    memcpy(request.expected,digest(current).bytes,32);
    struct GMReply reply;
    if(!exactIO(sessionFD,&request,sizeof request,YES) || !exactIO(sessionFD,(void*)data.bytes,data.length,YES) || !exactIO(sessionFD,&reply,sizeof reply,NO) || ntohl(reply.magic)!=GM_PROTOCOL_MAGIC) {
        [self endSession];return fail(output,GM_IO,@"The authorized session ended before the write could be confirmed. Review the system file and activate again.");
    }
    uint32_t status=ntohl(reply.status);
    if(status==GM_OK && memcmp(reply.digest,digest(data).bytes,32)==0)return YES;
    return fail(output,status,status==GM_CONFLICT ? @"The system hosts file changed during approval. Review the new state and activate again." :
        @"The hosts writer refused the change. The target must be a regular root-owned file; the previous content is retained when a pre-commit check fails.");
}
@end
