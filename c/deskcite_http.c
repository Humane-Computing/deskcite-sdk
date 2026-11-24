#include "deskcite_http.h"
#include <curl/curl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct buffer { unsigned char **data; size_t *length; };
static size_t append(void *data, size_t size, size_t count, void *ctx) {
    struct buffer *b = ctx;
    if (size && count > SIZE_MAX / size) return 0;
    size_t n = size * count;
    if (*b->length == SIZE_MAX || n > SIZE_MAX - *b->length - 1) return 0;
    unsigned char *p = realloc(*b->data, *b->length + n + 1);
    if (!p) return 0;
    memcpy(p + *b->length, data, n);
    *b->length += n; p[*b->length] = 0; *b->data = p;
    return n;
}
int dc_origin_valid(const char *origin) {
    if (!origin) return 0;
    for (const unsigned char *p = (const unsigned char *)origin; *p; p++) if (*p <= 32 || *p == 127) return 0;
    CURLU *u = curl_url();
    if (!u) return 0;
    int valid = curl_url_set(u, CURLUPART_URL, origin, 0) == CURLUE_OK;
    char *scheme = NULL, *host = NULL, *path = NULL;
    valid = valid && curl_url_get(u, CURLUPART_SCHEME, &scheme, 0) == CURLUE_OK && strcmp(scheme, "https") == 0;
    valid = valid && curl_url_get(u, CURLUPART_HOST, &host, 0) == CURLUE_OK && host[0];
    valid = valid && curl_url_get(u, CURLUPART_PATH, &path, 0) == CURLUE_OK && strcmp(path, "/") == 0;
    CURLUPart forbidden[] = {CURLUPART_USER, CURLUPART_PASSWORD, CURLUPART_QUERY, CURLUPART_FRAGMENT};
    for (size_t i = 0; i < sizeof(forbidden)/sizeof(forbidden[0]); i++) {
        char *value = NULL;
        if (curl_url_get(u, forbidden[i], &value, 0) == CURLUE_OK) valid = 0;
        curl_free(value);
    }
    curl_free(scheme); curl_free(host); curl_free(path); curl_url_cleanup(u);
    return valid;
}
void dc_response_free(dc_response *r) {
    if (!r) return;
    free(r->body); free(r->headers); memset(r, 0, sizeof(*r));
}
int dc_http(const char *origin, const char *token, const char *method,
    const char *path, const char *payload, const char *ca_file, long timeout_ms, dc_response *out) {
    if (!out) return CURLE_BAD_FUNCTION_ARGUMENT;
    memset(out, 0, sizeof(*out));
    if (!dc_origin_valid(origin) || !token || !*token || !method || !path || path[0] != '/' || path[1] == '/' || timeout_ms <= 0) return CURLE_BAD_FUNCTION_ARGUMENT;
    for (const unsigned char *p = (const unsigned char *)token; *p; p++) if (*p < 33 || *p > 126) return CURLE_BAD_FUNCTION_ARGUMENT;
    if (strcmp(method, "GET") && strcmp(method, "POST")) return CURLE_BAD_FUNCTION_ARGUMENT;
    size_t base_len = strlen(origin);
    if (origin[base_len-1] == '/') base_len--;
    char *url = malloc(base_len + strlen(path) + 1);
    char *auth = malloc(strlen(token) + 23);
    if (!url || !auth) { free(url); free(auth); return CURLE_OUT_OF_MEMORY; }
    memcpy(url, origin, base_len); strcpy(url + base_len, path);
    strcpy(auth, "Authorization: Bearer "); strcat(auth, token);
    CURL *curl = curl_easy_init();
    if (!curl) { free(url); free(auth); return CURLE_FAILED_INIT; }
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, auth);
    headers = curl_slist_append(headers, "Accept: application/json");
    if (payload || !strcmp(method, "POST")) headers = curl_slist_append(headers, "Content-Type: application/json");
    struct buffer body = {&out->body, &out->body_len}, head = {&out->headers, &out->headers_len};
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 0L);
    curl_easy_setopt(curl, CURLOPT_PROTOCOLS_STR, "https");
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, timeout_ms);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, append);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, append);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &head);
    if (ca_file) curl_easy_setopt(curl, CURLOPT_CAINFO, ca_file);
    if (!strcmp(method, "POST")) curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload ? payload : "");
    CURLcode result = curl_easy_perform(curl);
    if (result == CURLE_OK) curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &out->status);
    curl_easy_cleanup(curl); curl_slist_free_all(headers); free(url); free(auth);
    if (result != CURLE_OK) dc_response_free(out);
    return (int)result;
}
