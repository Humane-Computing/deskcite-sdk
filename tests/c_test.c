#define _POSIX_C_SOURCE 200809L
#include "deskcite.h"
#include <assert.h>
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static int received;
static void on_event(cJSON *m, void *ctx) {
    (void)ctx;
    assert(!strcmp(cJSON_GetObjectItemCaseSensitive(m,"type")->valuestring,"import.done")); received=1;
}
int main(void) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    deskcite c; assert(deskcite_init(&c,"http://example.test","token") == -1);
    assert(deskcite_init(&c,getenv("DS_TEST_URL"),"test-bearer")==0); c.ca_file=getenv("DS_TEST_CA");
    dc_response r;
    const char *names[]={"status","similar","ask","rate","create_question","search","search_graph","import_source","embed","agents","schedules","tasks","schedule","logout"};
    cJSON *args=cJSON_Parse("{\"text\":\"café & ?\",\"q\":\"test\",\"action\":\"calendar\"}");
    for (size_t i=0;i<sizeof(names)/sizeof(names[0]);i++) {
        const char *name=names[i]; int none=!strcmp(name,"status")||!strcmp(name,"embed")||!strcmp(name,"agents")||!strcmp(name,"schedules")||!strcmp(name,"logout");
        assert(deskcite_call(&c,name,none?NULL:args,&r)==0); assert(r.status>=200 && r.status<300); dc_response_free(&r);
    }
    cJSON_Delete(args); args=cJSON_Parse("{\"id\":\"id/ ?#\"}");
    assert(deskcite_question(&c,args,&r)==0); assert(strstr((char*)r.body,"id%2F%20%3F%23")); dc_response_free(&r); cJSON_Delete(args);
    args=cJSON_Parse("{\"path\":\"/deskcite/documents/a%20b.pdf\"}");
    assert(deskcite_document(&c,args,&r)==0); assert(r.body_len==3 && !memcmp(r.body,"\0\xff\n",3)); dc_response_free(&r); cJSON_Delete(args);
    args=cJSON_Parse("{\"path\":\"/deskcite/documents/%2e%2e/private\"}"); assert(deskcite_document(&c,args,&r)==-1); cJSON_Delete(args);
    args=cJSON_Parse("{\"text\":\"__error__\"}"); assert(deskcite_similar(&c,args,&r)==-2 && r.status==503 && r.body_len>0); dc_response_free(&r); cJSON_Delete(args);
    args=cJSON_Parse("{\"text\":\"__redirect__\"}"); assert(deskcite_similar(&c,args,&r)==-2 && r.status==302); dc_response_free(&r); cJSON_Delete(args);
    assert(deskcite_refresh(&c,NULL,&r)==0); args=cJSON_Parse((char*)r.body);
    assert(deskcite_set_token(&c,cJSON_GetObjectItemCaseSensitive(args,"access_token")->valuestring)==0); cJSON_Delete(args); dc_response_free(&r);
    assert(deskcite_status(&c,NULL,&r)==0); assert(strstr((char*)r.body,"rotated")); dc_response_free(&r);
    mesgd conn; assert(deskcite_events(&c,&conn,on_event,NULL)==0);
    struct timespec delay={0,10000000};
    for(int i=0;i<300 && !received;i++) {mesgd_recv(&conn); nanosleep(&delay,NULL);}
    assert(received); mesgd_close(&conn); deskcite_free(&c); curl_global_cleanup();
    puts("C: HTTPS routes, bytes, errors, rotation, WSS passed"); return 0;
}
