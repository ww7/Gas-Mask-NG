// Session-scoped helper. No launchd registration, arbitrary executable, pathname
// command, updater or network access. Only the authenticated app's stream remains
// after the first connection; EOF/app exit ends the helper and removes its stage.
#include "HostsWriterCore.h"
#include "HostsWriterPeer.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/poll.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <limits.h>

static int exact(int fd, void *buffer, size_t length, int writing) {
    size_t at=0;
    while (at<length) {
        ssize_t n=writing ? write(fd,(char*)buffer+at,length-at) : read(fd,(char*)buffer+at,length-at);
        if (n<0 && errno==EINTR) continue;
        if (n<=0) return 0;
        at+=(size_t)n;
    }
    return 1;
}
static int parseHex(const char *input, uint8_t *output, size_t size) {
    if (strlen(input)!=size*2) return 0;
    for (size_t i=0;i<size;i++) { unsigned value; char byte[3]={input[i*2],input[i*2+1],0};
        if (strspn(byte,"0123456789abcdefABCDEF")!=2 || sscanf(byte,"%x",&value)!=1) return 0;
        output[i]=(uint8_t)value;
    } return 1;
}
static int parseID(const char *input, unsigned long *value) {
    if (!input[0] || strspn(input,"0123456789")!=strlen(input)) return 0;
    char *end; errno=0; *value=strtoul(input,&end,10);
    return !errno && !*end && *value>0 && *value<=INT_MAX;
}
int main(int argc, char **argv) {
    if (argc==2 && !strcmp(argv[1],"--version")) { puts("Gas Mask NG session writer 1"); return 0; }
    // Stage is created by the administrator-authorized system shell, not the app.
    if (geteuid()!=0 || argc!=6 || strcmp(argv[1],"--serve")) return 64;
    unsigned long appPID, appUID; uint8_t hash[20];
    if (!parseID(argv[2],&appPID) || !parseID(argv[3],&appUID) || !parseHex(argv[4],hash,sizeof hash)) return 64;
    const char *stage=argv[5];
    if (strncmp(stage,"/private/var/run/gas-mask-ng.",27) || strlen(stage)<35 || strlen(stage)>75 ||
        strspn(stage+27,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")!=strlen(stage+27)) return 64;
    int stageFD=open(stage,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    struct stat metadata;
    if (stageFD<0 || fstat(stageFD,&metadata) || metadata.st_uid!=0 || (metadata.st_mode&0022)) return 65;
    char socketPath[sizeof(((struct sockaddr_un*)0)->sun_path)];
    if (snprintf(socketPath,sizeof socketPath,"%s/control.sock",stage)>=(int)sizeof socketPath) return 65;
    struct sockaddr_un address={0}; address.sun_family=AF_UNIX;
    strlcpy(address.sun_path,socketPath,sizeof address.sun_path);
    int listener=socket(AF_UNIX,SOCK_STREAM,0);
    if (listener<0 || bind(listener,(struct sockaddr*)&address,sizeof address) ||
        chown(socketPath,(uid_t)appUID,(gid_t)-1) || chmod(socketPath,0600) || listen(listener,8)) return 66;
    pid_t child=fork();
    if (child<0) return 67;
    if (child>0) { close(listener); close(stageFD); return 0; }
    setsid(); signal(SIGPIPE,SIG_IGN);
    int nullFD=open("/dev/null",O_RDWR);
    if (nullFD>=0) { for(int i=0;i<3;i++) dup2(nullFD,i); if(nullFD>2)close(nullFD); }
    int connection=-1;
    uint64_t deadline=clock_gettime_nsec_np(CLOCK_MONOTONIC)+30ULL*1000000000;
    while (clock_gettime_nsec_np(CLOCK_MONOTONIC)<deadline) {
        struct pollfd wait={listener,POLLIN,0};
        int ready=poll(&wait,1,1000);
        if(ready<0 && errno==EINTR)continue;
        if(ready<=0)continue;
        int candidate=accept(listener,NULL,NULL);
        if(candidate<0)continue;
        if(GMValidatePeer(candidate,(pid_t)appPID,(uid_t)appUID,hash)) { connection=candidate; break; }
        close(candidate);
    }
    close(listener); unlinkat(stageFD,"control.sock",0);
    int directory=open("/private/etc",O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    if(connection>=0 && directory>=0) {
        int noSignal=1; setsockopt(connection,SOL_SOCKET,SO_NOSIGPIPE,&noSignal,sizeof noSignal);
        // Only an authenticated stream is retained. The peer's CLOEXEC fd closes
        // on exec and EOF closes the helper when the owning app exits.
        for(;;) {
            struct GMRequest request;
            if(!exact(connection,&request,sizeof request,0))break;
            uint32_t op=ntohl(request.operation), length=ntohl(request.length);
            if(ntohl(request.magic)!=GM_PROTOCOL_MAGIC || length>GM_MAX_HOSTS_BYTES ||
                (op!=GM_OPERATION_WRITE && op!=GM_OPERATION_STATUS) || (op==GM_OPERATION_STATUS && length))break;
            void *payload=malloc(length ? length : 1); if(!payload)break;
            if(length && !exact(connection,payload,length,0)){free(payload);break;}
            struct GMReply reply={0}; reply.magic=htonl(GM_PROTOCOL_MAGIC);
            int status=op==GM_OPERATION_STATUS ? GMHostsDigest(directory,0,reply.digest) :
                GMApplyHosts(directory,0,payload,length,request.expected,reply.digest);
            free(payload); reply.status=htonl((uint32_t)status);
            if(!exact(connection,&reply,sizeof reply,1))break;
        }
    }
    if(directory>=0)close(directory); if(connection>=0)close(connection);
    unlinkat(stageFD,"writer",0); close(stageFD); rmdir(stage);
    return 0;
}
