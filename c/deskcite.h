#ifndef DESKCITE_H
#define DESKCITE_H
#include "deskcite_http.h"
#include "mesgd.h"
typedef struct { char *origin; char *token; const char *ca_file; long timeout_ms; } deskcite;
/* Client owns origin/token copies; ca_file is borrowed. curl_global_init must
 * be called once before concurrent use, as with mesgd. */
int deskcite_init(deskcite *client, const char *origin, const char *token);
int deskcite_set_token(deskcite *client, const char *token);
void deskcite_free(deskcite *client);
/* args is a JSON object; NULL is accepted for empty arguments. out owns raw
 * bytes/headers: always dc_response_free after use. Return 0 for 2xx, -1 for
 * invalid input, -2 for non-2xx (out preserved), positive CURLcode on failure. */
int deskcite_call(deskcite *client, const char *operation, const cJSON *args, dc_response *out);
int deskcite_events(deskcite *client, mesgd *connection, mesgd_handler handler, void *context);
/* Events use mesgd_recv/mesgd_close. MESGD_CA configures upstream WSS trust. */
#include "operations.h"
#endif
