#include "deskcite.h"
#include <curl/curl.h>
#include <stdlib.h>
#include <string.h>

struct operation { const char *name, *method, *path, *kind; };
#include "operations.inc"
static char *copy(const char *s) {
    char *p = malloc(strlen(s)+1); if (p) strcpy(p,s); return p;
}
int deskcite_set_token(deskcite *c, const char *token) {
    if (!token || !*token) return -1;
    for (const unsigned char *p = (const unsigned char *)token; *p; p++) if (*p < 33 || *p > 126) return -1;
    char *next = copy(token); if (!next) return -1;
    free(c->token); c->token = next; return 0;
}
int deskcite_init(deskcite *c, const char *origin, const char *token) {
    memset(c, 0, sizeof(*c));
    if (!dc_origin_valid(origin)) return -1;
    c->origin = copy(origin); c->timeout_ms = 30000;
    if (!c->origin || deskcite_set_token(c, token)) { deskcite_free(c); return -1; }
    return 0;
}
void deskcite_free(deskcite *c) { free(c->origin); free(c->token); memset(c,0,sizeof(*c)); }
static int document_valid(const char *p) {
    if (strncmp(p,"/deskcite/documents/",20) || strpbrk(p,"?#\\")) return 0;
    for (const unsigned char *b = (const unsigned char *)p; *b; b++) if (*b <= 32 || *b == 127) return 0;
    int n = 0; char *decoded = curl_easy_unescape(NULL,p,0,&n); if (!decoded) return 0;
    int valid = 1;
    for (int i=0;i<n;i++) if ((unsigned char)decoded[i]<32 || decoded[i]==127 || decoded[i]=='\\') valid=0;
    const char *part = decoded;
    while (*part) {
        const char *end = strchr(part,'/'); size_t len = end ? (size_t)(end-part) : strlen(part);
        if ((len==1 && part[0]=='.') || (len==2 && part[0]=='.' && part[1]=='.')) valid=0;
        if (!end) break;
        part = end+1;
    }
    curl_free(decoded); return valid;
}
int deskcite_call(deskcite *c, const char *name, const cJSON *args, dc_response *out) {
    memset(out,0,sizeof(*out));
    if (!name || (args && !cJSON_IsObject(args))) return -1;
    const struct operation *op = NULL;
    for (size_t i=0;i<sizeof(operations)/sizeof(operations[0]);i++) if (!strcmp(name,operations[i].name)) { op=&operations[i]; break; }
    if (!op) return -1;
    char *path = NULL, *payload = NULL;
    if (!strcmp(op->kind,"id")) {
        const cJSON *id = cJSON_GetObjectItemCaseSensitive(args,"id");
        if (!cJSON_IsString(id) || !*id->valuestring) return -1;
        char *escaped = curl_easy_escape(NULL,id->valuestring,0); if (!escaped) return -1;
        path = malloc(strlen(op->path)+strlen(escaped)+1);
        if (path) { strcpy(path,op->path); strcat(path,escaped); } curl_free(escaped);
    } else if (!strcmp(op->kind,"document")) {
        const cJSON *p = cJSON_GetObjectItemCaseSensitive(args,"path");
        if (!cJSON_IsString(p) || !document_valid(p->valuestring)) return -1;
        path = copy(p->valuestring);
    } else {
        if (!strcmp(op->kind,"none") && args && cJSON_GetArraySize(args)) return -1;
        path = copy(op->path);
        if (!strcmp(op->kind,"json")) payload = args ? cJSON_PrintUnformatted(args) : copy("{}");
    }
    if (!path || (!strcmp(op->kind,"json") && !payload)) { free(path); free(payload); return -1; }
    int result = dc_http(c->origin,c->token,op->method,path,payload,c->ca_file,c->timeout_ms,out);
    free(path); free(payload);
    if (!result && (out->status<200 || out->status>=300)) return -2;
    return result;
}
int deskcite_events(deskcite *c, mesgd *connection, mesgd_handler handler, void *ctx) {
    /* The upstream mesgd wrapper has a 4096-byte protocol-header buffer. */
    if (strlen(c->token) + strlen("Sec-WebSocket-Protocol: json, ") >= 4096) return -1;
    size_t n = strlen(c->origin);
    if (n && c->origin[n-1]=='/') n--;
    char *url = malloc(n+strlen("/deskcite/events")+1); if (!url) return -1;
    strcpy(url,"wss:"); memcpy(url+4,c->origin+6,n-6); strcpy(url+n-2,"/deskcite/events");
    int result = mesgd_connect(connection,url,c->token,NULL); free(url);
    if (!result) mesgd_on(connection,handler,ctx);
    return result;
}
