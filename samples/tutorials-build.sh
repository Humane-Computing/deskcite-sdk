#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MESGD_SDK="${MESGD_SDK:-$(CDPATH= cd ../mesgd-sdk && pwd)}"
DESKCITE_SDK="$PWD"
mkdir -p samples/04-c/tutorials/bin samples/07-go/tutorials/bin
for program in hello rotate bus; do
 cc -std=c11 -Wall -Wextra -Werror -I "$DESKCITE_SDK/c" -I "$MESGD_SDK/c" -I "$MESGD_SDK/3rd-party/cJSON" "samples/04-c/tutorials/$program.c" "$DESKCITE_SDK/c/deskcite.c" "$DESKCITE_SDK/c/deskcite_http.c" "$MESGD_SDK/c/mesgd.c" "$MESGD_SDK/c/pki.c" "$MESGD_SDK/3rd-party/cJSON/cJSON.c" -lcurl -lssl -lcrypto -o "samples/04-c/tutorials/bin/$program"
done
(cd samples/07-go/tutorials && go build -o bin/hello ./cmd/hello && go build -o bin/bus ./cmd/bus && go build -o bin/rotate ./cmd/rotate)
(cd samples/08-rust/tutorials && cargo build --offline --locked --bins)
(cd samples/18-dart/tutorials && dart pub get)
