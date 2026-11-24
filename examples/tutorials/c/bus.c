#define _POSIX_C_SOURCE 200809L
#include "mesgd.h"
#include <curl/curl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct state {
  mesgd *conn;
  int server;
  int done;
  int failed;
};

static void receive(cJSON *message, void *context) {
  struct state *s = context;
  const char *type =
      cJSON_GetStringValue(cJSON_GetObjectItemCaseSensitive(message, "type"));
  if (!type || strcmp(type, s->server ? "echo.request" : "echo.reply"))
    return;
  cJSON *body = cJSON_GetObjectItemCaseSensitive(message, "body");
  if (!body) {
    s->failed = 1;
    return;
  }
  if (s->server) {
    char *received = cJSON_PrintUnformatted(body);
    if (!received) {
      s->failed = 1;
      return;
    }
    printf("agent received: %s\n", received);
    fflush(stdout);
    free(received);
    const char *sender =
        cJSON_GetStringValue(cJSON_GetObjectItemCaseSensitive(message, "from"));
    if (!sender) {
      s->failed = 1;
      return;
    }
    cJSON *reply = cJSON_CreateObject();
    cJSON_AddStringToObject(reply, "to", sender);
    cJSON_AddStringToObject(reply, "from", "service");
    cJSON_AddStringToObject(reply, "type", "echo.reply");
    cJSON_AddItemToObject(reply, "body", cJSON_Duplicate(body, 1));
    s->failed = mesgd_send(s->conn, reply, (mesgd_opts){0, 0}) != 0;
    cJSON_Delete(reply);
  } else {
    char *text = cJSON_PrintUnformatted(body);
    puts(text);
    free(text);
    s->done = 1;
  }
}

static int run(int server) {
  const char *origin = getenv("MESGD_WSS");
  if (!origin) {
    fputs("set MESGD_WSS\n", stderr);
    return 1;
  }
  size_t length = strlen(origin);
  while (length && origin[length - 1] == '/')
    --length;
  if (!length || length > 4096)
    return 1;
  char url[4120];
  snprintf(url, sizeof url, "%.*s/to=%s", (int)length, origin,
           server ? "service" : "client");
  mesgd conn = {0};
  if (mesgd_connect(&conn, url, getenv("MESGD_TOKEN"), NULL)) {
    fputs("connection failed\n", stderr);
    return 1;
  }
  struct state state = {&conn, server, 0, 0};
  mesgd_on(&conn, receive, &state);
  printf("ready: %s\n", server ? "server" : "client");
  fflush(stdout);
  if (!server) {
    cJSON *request =
        cJSON_Parse("{\"to\":\"service\",\"from\":\"client\","
                    "\"type\":\"echo.request\",\"body\":{\"text\":\"hello\"}}");
    state.failed = mesgd_send(&conn, request, (mesgd_opts){0, 0}) != 0;
    cJSON_Delete(request);
  }
  time_t deadline = time(NULL) + 30;
  while (!state.done && !state.failed && time(NULL) < deadline) {
    /* mesgd_recv collapses libcurl's WOULD_BLOCK and transport errors to -1.
       Retry briefly, with a deadline, rather than treating -1 as disconnect. */
    if (mesgd_recv(&conn) == 0) {
      if (server)
        deadline = time(NULL) + 30;
    } else {
      struct timespec delay = {0, 10000000};
      nanosleep(&delay, NULL);
    }
  }
  mesgd_close(&conn);
  if (state.failed || !state.done) {
    fputs("send failed or 30-second receive/idle timeout\n", stderr);
    return 1;
  }
  return 0;
}

int main(int argc, char **argv) {
  if (argc != 2 || (strcmp(argv[1], "server") && strcmp(argv[1], "client"))) {
    fputs("usage: pubsub server|client\n", stderr);
    return 1;
  }
  if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK)
    return 1;
  int result = run(!strcmp(argv[1], "server"));
  curl_global_cleanup();
  return result;
}
