#ifndef GM_HOSTS_WRITER_CORE_H
#define GM_HOSTS_WRITER_CORE_H
#include <sys/types.h>
#include <stdint.h>
#include <stddef.h>
#define GM_MAX_HOSTS_BYTES (32U * 1024U * 1024U)
#define GM_PROTOCOL_MAGIC 0x474d4831U
#define GM_OPERATION_WRITE 1U
#define GM_OPERATION_STATUS 2U
// Fixed-size wire fields are network byte order. No path or command is accepted.
struct GMRequest { uint32_t magic, operation, length; uint8_t expected[32]; };
struct GMReply { uint32_t magic, status; uint8_t digest[32]; };
enum GMStatus { GM_OK=0, GM_INVALID=1, GM_UNSAFE_TARGET=2, GM_CONFLICT=3, GM_IO=4, GM_TOO_LARGE=5, GM_UNAUTHORIZED=6 };
// Production always passes a securely opened /private/etc fd and expectedOwner=0.
// The fd boundary lets tests use a temporary directory, never the system file.
int GMApplyHosts(int directoryFD, uid_t expectedOwner, const void *bytes, size_t length,
                 const uint8_t expected[32], uint8_t result[32]);
int GMHostsDigest(int directoryFD, uid_t expectedOwner, uint8_t digest[32]);
int GMValidUTF8(const void *bytes, size_t length);
#endif
