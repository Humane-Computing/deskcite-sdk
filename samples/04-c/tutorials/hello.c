#define _POSIX_C_SOURCE 200809L
#include "common.h"
int main(void) {
  if (curl_global_init(CURL_GLOBAL_DEFAULT))
    return 1;
  char *token = load_token();
  deskcite c;
  int rc = 1;
  if (!token || deskcite_init(&c, getenv("DESKCITE_URL"), token))
    goto end;
  c.ca_file = getenv("DESKCITE_CA");
  cJSON *args = cJSON_Parse(
      "{\"text\":\"How do I upload a document in Deskcite?\",\"n\":3}");
  dc_response r;
  if (deskcite_similar(&c, args, &r) == 0) {
    cJSON *body = cJSON_ParseWithLength((char *)r.body, r.body_len), *row;
    if (body && cJSON_IsArray(cJSON_GetObjectItemCaseSensitive(body, "rows"))) {
      rc = 0;
      cJSON_ArrayForEach(row, cJSON_GetObjectItemCaseSensitive(body, "rows")) {
        const char *answer = cJSON_GetStringValue(
                       cJSON_GetObjectItemCaseSensitive(row, "answer")),
                   *path = cJSON_GetStringValue(
                       cJSON_GetObjectItemCaseSensitive(row, "path"));
        if (!answer || !path) {
          rc = 1;
          break;
        }
        printf("%s\nSource: %s\n", answer, path);
      }
    }
    cJSON_Delete(body);
  }
  dc_response_free(&r);
  cJSON_Delete(args);
  deskcite_free(&c);
end:
  free(token);
  curl_global_cleanup();
  if (rc)
    fputs("Search failed; check URL, trust and credential permissions.\n",
          stderr);
  return rc;
}
