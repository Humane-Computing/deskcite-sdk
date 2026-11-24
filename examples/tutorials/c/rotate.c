#define _POSIX_C_SOURCE 200809L
#include "common.h"
int main(void) {
  if (!getenv("DESKCITE_TOKEN_FILE"))
    return 1;
  if (curl_global_init(CURL_GLOBAL_DEFAULT))
    return 1;
  char *old = load_token();
  deskcite c;
  int rc = 1;
  if (!old || deskcite_init(&c, getenv("DESKCITE_URL"), old))
    goto end;
  c.ca_file = getenv("DESKCITE_CA");
  dc_response r;
  if (deskcite_refresh(&c, NULL, &r) != 0) {
    dc_response_free(&r);
    goto done;
  }
  cJSON *body = cJSON_ParseWithLength((char *)r.body, r.body_len);
  const char *token = cJSON_GetStringValue(
      cJSON_GetObjectItemCaseSensitive(body, "access_token"));
  if (!token || !*token || store_token(token) ||
      deskcite_set_token(&c, token)) {
    cJSON_Delete(body);
    dc_response_free(&r);
    goto done;
  }
  dc_response_free(&r);
  int code = deskcite_status(&c, NULL, &r);
  dc_response_free(&r);
  if (code) {
    cJSON_Delete(body);
    goto done;
  }
  if (deskcite_set_token(&c, old)) {
    cJSON_Delete(body);
    goto done;
  }
  code = deskcite_status(&c, NULL, &r);
  int rejected = code == -2 && r.status == 401;
  dc_response_free(&r);
  if (rejected && !deskcite_set_token(&c, token)) {
    puts("Credential rotated and saved; replacement works; old bearer "
         "rejected.");
    rc = 0;
  }
  cJSON_Delete(body);
done:
  deskcite_free(&c);
end:
  free(old);
  curl_global_cleanup();
  if (rc)
    fputs("Rotation stopped; do not retry refresh blindly.\n", stderr);
  return rc;
}
