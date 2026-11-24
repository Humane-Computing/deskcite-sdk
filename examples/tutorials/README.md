# SDK video follow-along sources

The canonical tutorial programs now live in the [Deskcite SDK samples](../../samples/TUTORIALS.md), under the matching `##-language/tutorials/` directory. The Python `hello.py` here is synchronized with the complete program shown in the video. Future recordings read the Deskcite SDK samples directly. The examples below remain as earlier Deskcite SDK references.

# SDK tutorial examples

Three lessons in each of the six non-Erlang languages with mesgd transport: Python, JavaScript, Go, Ruby, Rust and C. Erlang remains an additional reference SDK. These are runnable source-checkout examples, not registry installation instructions for a released package.

| Language | Search | Agent pub/sub | Credential refresh |
| --- | --- | --- | --- |
| Python | `examples/tutorials/python/hello.py` | `examples/tutorials/python/bus.py` | `examples/tutorials/python/rotate.py` |
| JavaScript | `examples/tutorials/javascript/hello.mjs` | `examples/tutorials/javascript/bus.mjs` | `examples/tutorials/javascript/rotate.mjs` |
| Go | `go/cmd/tutorial-hello/main.go` | `go/cmd/tutorial-bus/main.go` | `go/cmd/tutorial-rotate/main.go` |
| Ruby | `examples/tutorials/ruby/hello.rb` | `examples/tutorials/ruby/bus.rb` | `examples/tutorials/ruby/rotate.rb` |
| Rust | `rust/examples/tutorial_hello.rs` | `rust/examples/tutorial_bus.rs` | `rust/examples/tutorial_rotate.rs` |
| C | `examples/tutorials/c/hello.c` | `examples/tutorials/c/bus.c` | `examples/tutorials/c/rotate.c` |

Paths are relative to the SDK root. Go and Rust examples use their native module/crate trees. C, Python, JavaScript and Ruby sources live here. `common`/`tutorial_support` modules contain the private credential-file and CA handling; read those with the short programs.

## Prepare once

Use the prerequisites in the root README. Node needs this checkout's `javascript/node_modules/ws`. Python needs the sibling mesgd SDK's `cryptography` dependency. Go/Rust use the sibling source dependencies. C requires libcurl built with WebSocket support. Native builds use existing Cargo dependencies and `--offline --locked`.

From the SDK root, with dependencies already installed:

```sh
export MESGD_SDK="$HOME/Code/mesgd-sdk"
export PYTHONPATH="$PWD/python:$MESGD_SDK/python"
make tutorial-build
```

Use a search-only API key from **Settings → API Keys** for the first lesson. The rotation example also checks `status`, so include knowledge-count access and permitted refresh. API keys do not have administrative key-management permissions. Keep the token in a file in a host-owned directory with mode 0700; the file must be mode 0600. Populate it through your trusted credential/secret provider outside the recording. Set an absolute path without printing its contents:

```sh
export DESKCITE_URL=https://demo.deskcite.com
export DESKCITE_TOKEN_FILE=/absolute/private/directory/credential
```

`DESKCITE_TOKEN` is accepted for the search example if no token file is supplied. Rotation requires a token file before making the request, and writes a mode-0600 temporary file in the same directory before atomic rename. The sample assumes one credential owner and no concurrent writers. It demonstrates local-file replacement on Unix, not a production vault integration or crash recovery. Configure your application's secret-provider transaction instead in deployment. If refresh succeeds but storage fails, the previous bearer is already retired: stop and recover through your trusted credential owner. Never blindly retry refresh.

For a private CA, set its absolute PEM path. Keep certificate and hostname checks enabled:

```sh
export DESKCITE_CA=/absolute/path/to/ca.pem
export MESGD_CA="$DESKCITE_CA"
export SSL_CERT_FILE="$DESKCITE_CA"
export NODE_EXTRA_CA_CERTS="$DESKCITE_CA"
```

Publicly trusted deployments need no private CA override. The examples fail on TLS errors and do not follow redirects with credentials.

## Lesson 1: search

Each `hello` calls `similar` with `text` and `n: 3`, then prints answer text and its source path. `ask` and `similar` retrieve stored answers; they do not synthesize replies. The example question assumes Deskcite's guide has been imported. An empty response is a valid search outcome; import/index an authorized source before the production shoot.

## Lesson 2: an echo agent over the bus

Use a **separate messaging credential** in `MESGD_TOKEN`, authorized for the connection subscriptions `/to=service`, `/to=client` and those publish destinations. `MESGD_WSS` is the broker origin, without a subscription path. Provision these permissions with the credential owner. Do not assume that a login or a Deskcite API key bypasses current route policy.

```sh
export MESGD_WSS=wss://demo.deskcite.com
# Supply MESGD_TOKEN from the messaging secret provider; do not echo it.
```

Start `bus server` in terminal A, wait for `ready: server`, then run `bus client` in terminal B. Both roles are WebSocket clients. The server is a small application agent that echoes the body; it is not an LLM or an implicit agent-framework service. `to` determines routing; `type` selects a local callback. `on` is not another broker subscription. Replies use a fixed client address to keep the first demonstration readable. Concurrent callers need unique reply addresses, correlation IDs and application timeouts. Use separate demo credentials and isolated routes when recording multiple pairs concurrently.

These are plain JSON messages over verified TLS. Signing/sealing and receive-side verification are separate advanced topics. There is no durable delivery, replay, acknowledgment or automatic reconnect. C bounds its receive/idle loop to 30 seconds because its upstream receive return code combines would-block and errors. Python, Ruby, Go and Rust synchronous receive calls rely on the recording/test harness timeout if the broker stops responding. JavaScript uses an explicit reply timeout. See the upstream transport limitations before production use.

## Lesson 3: refresh and replace a bearer

Run `hello`, then `rotate`, then `hello` again using the same private file. `rotate` calls `/auth/refresh` **once**, saves the replacement, updates the client, checks the replacement works and requires HTTP 401 for the old bearer. It prints only verification text. For Deskcite API keys, refresh preserves the key's restrictions, stable identity and original absolute expiry. It does not extend lifetime or confer bus-publish rights. Expired/revoked credentials need reprovisioning.

These short examples have no open event connection during refresh. In a running application, pause work, close old connections and reopen them with the replacement before resuming. Refresh does not update a separate already-running process's environment. Existing mesgd administrator `issue`/`roll`, key-pair changes and account recovery are distinct operations and are not invoked by these examples.

## Run commands

Run from the SDK root. For each bus pair, use two terminals with the matching environment; the listed commands are separate invocations, not a sequential shell script that waits for the service to exit. Native executables are built by `make tutorial-build`.

### Python

```sh
python3 examples/tutorials/python/hello.py
python3 examples/tutorials/python/bus.py server
python3 examples/tutorials/python/bus.py client
python3 examples/tutorials/python/rotate.py
```

### JavaScript

```sh
node examples/tutorials/javascript/hello.mjs
node examples/tutorials/javascript/bus.mjs server
node examples/tutorials/javascript/bus.mjs client
node examples/tutorials/javascript/rotate.mjs
```

### Go

```sh
examples/tutorials/bin/go-hello
examples/tutorials/bin/go-bus server
examples/tutorials/bin/go-bus client
examples/tutorials/bin/go-rotate
```

### Ruby

```sh
ruby examples/tutorials/ruby/hello.rb
ruby examples/tutorials/ruby/bus.rb server
ruby examples/tutorials/ruby/bus.rb client
ruby examples/tutorials/ruby/rotate.rb
```

### Rust

```sh
rust/target/debug/examples/tutorial_hello
rust/target/debug/examples/tutorial_bus server
rust/target/debug/examples/tutorial_bus client
rust/target/debug/examples/tutorial_rotate
```

### C

```sh
examples/tutorials/bin/c-hello
examples/tutorials/bin/c-bus server
examples/tutorials/bin/c-bus client
examples/tutorials/bin/c-rotate
```

## Verification

```sh
make test-tutorials
```

This builds C, Go and Rust, then runs all 18 programs against an isolated HTTPS/WSS **protocol fixture** with a temporary CA and dummy credentials. The test routes real frames between the two actual SDK processes, checks search citations, one refresh, retirement of the old bearer, private file permissions and reload in another process. It does not test a deployed broker's policy, a real Deskcite index, a live model or production key expiry. Fixture provenance is retained in recording metadata; the tutorial videos omit the visible fixture badge.

For an interactive rehearsal, run `node tests/tutorial-fixture.mjs --serve`. It prints the path of a private `demo.env`; source that file in another shell without displaying its contents. It supplies only dummy local credentials. Keep the fixture running while rehearsing, and stop it afterward. A refresh invalidates its original test bearer; restart the fixture for a clean rotation rehearsal.
