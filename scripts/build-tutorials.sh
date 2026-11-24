#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MESGD_SDK=${MESGD_SDK:-"$HOME/Code/mesgd-sdk"}
mkdir -p examples/tutorials/bin
for program in hello rotate bus; do
 cc -std=c11 -Wall -Wextra -Werror -I c -I "$MESGD_SDK/c" -I "$MESGD_SDK/3rd-party/cJSON" examples/tutorials/c/$program.c c/deskcite.c c/deskcite_http.c "$MESGD_SDK/c"/mesgd.c "$MESGD_SDK/c"/pki.c "$MESGD_SDK/3rd-party/cJSON"/cJSON.c -lcurl -lssl -lcrypto -o examples/tutorials/bin/c-$program
done
cd go
go build -o ../examples/tutorials/bin/go-hello ./cmd/tutorial-hello
go build -o ../examples/tutorials/bin/go-rotate ./cmd/tutorial-rotate
go build -o ../examples/tutorials/bin/go-bus ./cmd/tutorial-bus
cd ../rust
cargo build --offline --locked --examples
