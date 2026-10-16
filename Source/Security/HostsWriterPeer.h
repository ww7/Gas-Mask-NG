#ifndef GM_HOSTS_WRITER_PEER_H
#define GM_HOSTS_WRITER_PEER_H
#include <sys/types.h>
#include <stdint.h>
// Checks kernel-provided audit identity AND the running code's exact CDHash.
int GMValidatePeer(int socketFD, pid_t pid, uid_t uid, const uint8_t codeHash[20]);
#endif
