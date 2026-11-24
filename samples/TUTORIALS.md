# SDK video follow-along samples

## Website tutorials

Watch the [SDK tutorials](https://deskcite.com/sdk-guide.html) and follow along with these sources:

- [Python: your first search](https://deskcite.com/sdk-guide.html#python-search) — `hello.py`.
- [Python: send work to an agent](https://deskcite.com/sdk-guide.html#python-agent-messaging) — `bus.py`.
- [Python: credentials and rotation](https://deskcite.com/sdk-guide.html#python-credentials) — `rotate.py` and `common.py`.

Repository: [Humane-Computing/deskcite-sdk](https://github.com/Humane-Computing/deskcite-sdk).


These are the source programs used by the SDK tutorials. All new tutorial examples belong in the matching `samples/##-language/tutorials/` directory. Video recorders read these files, including helper code; do not maintain a separate inline program in a recording script.

| Language | Follow-along source |
| --- | --- |
| Python | [01-python/tutorials](01-python/tutorials/README.md) |
| JavaScript | [02-javascript/tutorials](02-javascript/tutorials/README.md) |
| C | [04-c/tutorials](04-c/tutorials/README.md) |
| Go | [07-go/tutorials](07-go/tutorials/README.md) |
| Rust | [08-rust/tutorials](08-rust/tutorials/README.md) |
| Ruby | [11-ruby/tutorials](11-ruby/tutorials/README.md) |
| Dart | [18-dart/tutorials](18-dart/tutorials/README.md) |

Each directory contains search (`hello`), agent messaging (`bus`), credential refresh (`rotate`), and their support files. [tutorials.json](tutorials.json) is the source/command manifest. These lessons use both mesgd's messaging transport and Deskcite's search API. Clone `mesgd-sdk` and `deskcite-sdk` side by side, as `~/Code/mesgd-sdk` and `~/Code/deskcite-sdk`.

## Prepare the checkout

Run from the deskcite-sdk root:

```sh
export MESGD_SDK="$PWD/../mesgd-sdk"
export PYTHONPATH="$PWD/python:$MESGD_SDK/python"
```

Python needs `cryptography`: create a virtual environment and install `samples/01-python/tutorials/requirements.txt`. To reproduce the search video's package installation, build a wheel with `python3 -m pip wheel --no-deps --wheel-dir /tmp/deskcite-packages ./python`, then install that wheel in the virtual environment. The Python bus uses the sibling mesgd SDK's `python/` modules via `PYTHONPATH`; run commands with the virtual environment activated.

JavaScript needs the `ws` dependency installed in `javascript/` (run `npm install` there). Ruby uses its standard libraries and OpenSSL. C needs a compiler, OpenSSL, and libcurl with WebSocket support. Go and Rust require their toolchains and the SDKs' existing dependencies. Native tutorial builds are offline and do not fetch dependencies:

```sh
make -f samples/tutorials.mk build
```

## Configure search and refresh

Use your own Deskcite address and a private credential file. Obtain the key through your trusted credential owner or Deskcite API-key settings; do not paste it into source code.

```sh
export DESKCITE_URL=https://demo.deskcite.com
export DESKCITE_TOKEN_FILE=/absolute/private/directory/credential
export DESKCITE_CA=/absolute/path/to/trusted-ca.pem
```

The credential directory should be mode 0700, and its file mode 0600. The exact filmed Python `hello.py` requires the token file and a trusted CA file. Other helpers also accept system trust when no custom CA is supplied. For a public endpoint, the Python sample can use your system CA bundle as `DESKCITE_CA`. Keep TLS certificate and hostname checks enabled. For the other transports, configure the same private trust as needed:

```sh
export MESGD_CA="$DESKCITE_CA"
export SSL_CERT_FILE="$DESKCITE_CA"
export NODE_EXTRA_CA_CERTS="$DESKCITE_CA"
```

Import the Deskcite guide before searching for its upload instructions. Search returns indexed answers and source paths; an empty result is valid if the content has not been indexed.

Rotation needs refresh and status/knowledge-count permissions. Run `hello`, then `rotate`, then `hello` again with the same token file. The sample refreshes exactly once, saves the replacement, checks that it works, and requires HTTP 401 for the old bearer. Refresh preserves restrictions and the original absolute expiry. Pause work during rotation and reconnect event streams with the replacement. If refresh succeeds but saving fails, recover through your credential owner; do not blindly retry. The file helper demonstrates a Unix, single-owner private store, not a production vault transaction.

## Configure the messaging lesson

```sh
export MESGD_WSS=wss://demo.deskcite.com
# Supply MESGD_TOKEN through your trusted secret provider.
```

Use a separate messaging credential authorized for subscriptions `/to=service` and `/to=client`, and for publishing to those destinations. A Deskcite search API key does not confer these publish permissions. Start `bus server` in one terminal and wait for `ready: server`; start `bus client` in another. Both are WebSocket clients of the same broker. The agent echoes a JSON body; it is not an LLM. The `on` callback filters locally, while the connection path determines the subscription. Concurrent callers need distinct reply addresses, correlation, and timeouts. These plain-JSON examples do not demonstrate signing/sealing, durable delivery, acknowledgments, or automatic reconnect; the original PKI ping/pong samples remain separate.

## Verify the examples

With the sibling mesgd SDK and dependencies already available:

```sh
make -f samples/tutorials.mk test
```

This builds C, Go, Rust, and Dart, then runs all 21 tutorial programs against the Deskcite SDK's isolated HTTPS/WSS fixture. It verifies citations, request/reply, one refresh, rejection of the old bearer, private storage, and reload. No live account is changed. For manual rehearsal, run `node tests/tutorial-fixture.mjs --serve`, source the printed private environment-file path in another shell without displaying its contents, and keep that fixture running. Restart it for a fresh rotation rehearsal.

## Maintaining the video sources

The current Python files match the code in the narrated videos, including the self-contained search program and the setup-display helpers. The recorder in `video-pipeline/guides/sdk/record-python.mjs` copies these files into its isolated recording project and reads `hello.py` for the on-screen creation step. If code changes, update the narration and record a new take. Preserve the previous take and keep test-fixture provenance in recording metadata.

## Transport limits in these samples

There is no durable delivery, replay, acknowledgment, or automatic reconnect. JavaScript uses an explicit reply timeout. C bounds its receive/idle loop to 30 seconds because the transport return code combines would-block and errors. Python, Ruby, Go, and Rust synchronous receive calls rely on the recording/test harness timeout if the broker stops responding. Read the shared support file with the short programs; production applications need their own cancellation and recovery policies.
