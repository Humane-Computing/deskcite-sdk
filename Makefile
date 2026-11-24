MESGD_SDK ?= $(HOME)/Code/mesgd-sdk
ERLANG_ROOT ?= $(HOME)/erlang
BEAMER ?= $(ERLANG_ROOT)/beamer/beamer
SOURCES := $(wildcard erlang/src/*.erl examples/erlang/*.erl erlang/test/*.erl)
export MESGD_SDK
export GOCACHE ?= /tmp/deskcite-go-cache
CC ?= cc
CFLAGS ?= -Wall -Wextra -Werror -std=c11
CINCLUDES := -I c -I $(MESGD_SDK)/c -I $(MESGD_SDK)/3rd-party/cJSON
CSOURCES := c/deskcite.c c/deskcite_http.c $(MESGD_SDK)/c/mesgd.c $(MESGD_SDK)/c/pki.c $(MESGD_SDK)/3rd-party/cJSON/cJSON.c

.PHONY: all erlang native format check test test-unit clean
all: erlang native
erlang: format
	mkdir -p erlang/ebin
	erlc -Werror -o erlang/ebin erlang/src/*.erl examples/erlang/*.erl erlang/test/*.erl
	erlc -o erlang/ebin $(MESGD_SDK)/erlang/mesgd.erl $(MESGD_SDK)/erlang/pki.erl
	erlc -o erlang/ebin $(ERLANG_ROOT)/json/src/json.erl $(ERLANG_ROOT)/http/src/url.erl $(ERLANG_ROOT)/http/src/sock.erl $(ERLANG_ROOT)/websocket/src/websocket_client.erl $(ERLANG_ROOT)/websocket/src/websocket_rfc6455.erl
format:
	$(BEAMER) lint write $(SOURCES)
check:
	$(BEAMER) lint check $(SOURCES)
	$(ERLANG_ROOT)/agent/scripts/check-exceptions erlang/src erlang/test examples/erlang
	node scripts/generate.mjs --check
native: tests/c_test
	cd go && go test ./...
	cd rust && cargo test --locked
tests/c_test: tests/c_test.c $(CSOURCES) c/deskcite.h c/deskcite_http.h c/operations.h c/operations.inc
	$(CC) $(CFLAGS) $(CINCLUDES) tests/c_test.c $(CSOURCES) -lcurl -lssl -lcrypto -o $@
test-unit: erlang check
	erl -noshell -eval 'code:add_patha(filename:absname("erlang/ebin")), case eunit:test(deskcite_tests, [verbose]) of ok -> halt(0); _ -> halt(1) end.'
test: all test-unit
	node tests/integration.mjs
clean:
	rm -rf erlang/ebin rust/target tests/c_test

.PHONY: tutorial-build test-tutorials
tutorial-build:
	sh scripts/build-tutorials.sh
test-tutorials: tutorial-build
	node tests/tutorials.mjs
