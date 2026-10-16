// Disposable-VM-only protocol client for the exact production root helper.
#include "HostsWriterCore.h"
#include <Security/Security.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
static int exact(int fd,void *p,size_t size,int writing) {
    size_t at=0;while(at<size){ssize_t n=writing ? write(fd,(char*)p+at,size-at):read(fd,(char*)p+at,size-at);if(n<=0)return 0;at+=n;}return 1;
}
int main(int argc,char **argv) {
    char model[128]={0};size_t modelSize=sizeof model;
    if(sysctlbyname("hw.model",model,&modelSize,NULL,0) || !strstr(model,"VirtualMac") ||
       access("/private/var/tmp/gasmask-disposable-vm",F_OK) || getuid()==0)return 78;
    if(argc!=4)return 64;
    SecCodeRef code=NULL;CFDictionaryRef info=NULL;
    if(SecCodeCopySelf(0,&code) || SecCodeCopySigningInformation(code,kSecCSSigningInformation,&info))return 1;
    CFDataRef hash=CFDictionaryGetValue(info,kSecCodeInfoUnique);
    FILE *ready=fopen(argv[1],"w");if(!ready)return 1;
    fprintf(ready,"%d %u ",getpid(),getuid());
    for(CFIndex i=0;i<CFDataGetLength(hash);i++)fprintf(ready,"%02x",CFDataGetBytePtr(hash)[i]);
    fprintf(ready,"\n");fclose(ready);CFRelease(info);CFRelease(code);
    FILE *stage=NULL;for(int i=0;i<100 && !(stage=fopen(argv[2],"r"));i++)usleep(200000);
    if(!stage)return 2;
    char path[104]={0};if(!fgets(path,sizeof path,stage))return 2;fclose(stage);
    path[strcspn(path,"\r\n")]=0;
    struct sockaddr_un address={0};address.sun_family=AF_UNIX;strlcpy(address.sun_path,path,sizeof address.sun_path);
    int fd=socket(AF_UNIX,SOCK_STREAM,0);if(connect(fd,(struct sockaddr*)&address,sizeof address))return 3;
    struct GMRequest request={0};request.magic=htonl(GM_PROTOCOL_MAGIC);request.operation=htonl(GM_OPERATION_STATUS);
    if(!strcmp(argv[3],"malformed"))request.magic=0;
    if(!exact(fd,&request,sizeof request,1))return 4;
    struct GMReply reply={0};int received=exact(fd,&reply,sizeof reply,0);close(fd);
    if(!strcmp(argv[3],"malformed")){puts(received ? "FAIL malformed accepted":"PASS malformed refused");return received?5:0;}
    if(!strcmp(argv[3],"rejected")) {
        puts(received ? "FAIL untrusted peer accepted":"PASS untrusted peer refused");return received?5:0;
    }
    if(!strcmp(argv[3],"unsafe")) {
        int refused=received && ntohl(reply.magic)==GM_PROTOCOL_MAGIC && ntohl(reply.status)==GM_UNSAFE_TARGET;
        puts(refused ? "PASS unsafe target refused":"FAIL unsafe target accepted");return refused?0:5;
    }
    int valid=received && ntohl(reply.magic)==GM_PROTOCOL_MAGIC && ntohl(reply.status)==GM_OK;
    puts(valid ? "PASS authenticated status":"FAIL authenticated status");return valid?0:5;
}
