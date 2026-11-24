#ifndef DESKCITE_HTTP_H
#define DESKCITE_HTTP_H
#include <stddef.h>
typedef struct {
    long status;
    unsigned char *body;
    size_t body_len;
    unsigned char *headers;
    size_t headers_len;
} dc_response;
/* Raw shared HTTPS engine for C and Rust. 0 means transport success; inspect status. */
int dc_origin_valid(const char *origin);
int dc_http(const char *origin, const char *token, const char *method,
    const char *path, const char *payload, const char *ca_file, long timeout_ms, dc_response *out);
void dc_response_free(dc_response *response);
#endif
