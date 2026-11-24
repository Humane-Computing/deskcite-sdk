.PHONY: build test
export GOCACHE ?= /tmp/deskcite-go-cache
build:
	sh samples/tutorials-build.sh
test: build
	node tests/tutorial-samples.mjs
