#ifndef TUTORIAL_COMMON_H
#define TUTORIAL_COMMON_H
#include "deskcite.h"
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
static inline char *load_token(void) {
  const char *path = getenv("DESKCITE_TOKEN_FILE");
  if (!path) {
    const char *v = getenv("DESKCITE_TOKEN");
    return v ? strdup(v) : NULL;
  }
  FILE *f = fopen(path, "r");
  if (!f)
    return NULL;
  char *s = calloc(65537, 1);
  if (!s) {
    fclose(f);
    return NULL;
  }
  size_t n = fread(s, 1, 65536, f);
  int bad = ferror(f) || !feof(f);
  fclose(f);
  if (bad) {
    free(s);
    return NULL;
  }
  while (n && (s[n - 1] == '\n' || s[n - 1] == '\r'))
    s[--n] = 0;
  return s;
}
static inline int store_token(const char *token) {
  const char *path = getenv("DESKCITE_TOKEN_FILE");
  if (!path)
    return -1;
  char *temp = malloc(strlen(path) + 20);
  if (!temp)
    return -1;
  sprintf(temp, "%s.rotate-XXXXXX", path);
  int fd = mkstemp(temp);
  if (fd < 0) {
    free(temp);
    return -1;
  }
  FILE *f = fdopen(fd, "w");
  if (!f) {
    close(fd);
    unlink(temp);
    free(temp);
    return -1;
  }
  int bad = fprintf(f, "%s\n", token) < 0;
  if (fflush(f) || fsync(fd))
    bad = 1;
  if (fclose(f))
    bad = 1;
  if (!bad && rename(temp, path))
    bad = 1;
  if (bad)
    unlink(temp);
  free(temp);
  return bad ? -1 : 0;
}
#endif
