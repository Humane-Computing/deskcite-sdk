# deskcite-sdk

## Website tutorials

Watch the [SDK tutorials](https://deskcite.com/sdk-guide.html) and follow along with these sources:

- [Python: your first search](https://deskcite.com/sdk-guide.html#python-search) — `hello.py`.
- [Python: send work to an agent](https://deskcite.com/sdk-guide.html#python-agent-messaging) — `bus.py`.
- [Python: credentials and rotation](https://deskcite.com/sdk-guide.html#python-credentials) — `rotate.py` and `common.py`.

Repository: [Humane-Computing/deskcite-sdk](https://github.com/Humane-Computing/deskcite-sdk).


Deskcite's product API for agents and applications, over authenticated mesgd HTTPS routes with mesgd WebSocket events. Implemented in **Erlang, C, Go, JavaScript, Python, Ruby, Rust, and Dart**. The Erlang `deskcite_agent` example registers remote Deskcite tools in the existing agent framework.

This is an initial local SDK checkout, not a published package release. It uses the sibling `mesgd-sdk` checkout for WebSockets and PKI; HTTPS adapters preserve product response status, headers, error bodies, and document bytes that the existing mesgd auth transports do not expose. Existing mesgd, Deskcite, and agent repositories are unchanged.

## Video tutorial samples

Follow along using [samples/TUTORIALS.md](samples/TUTORIALS.md). The search, agent messaging, and credential-refresh programs live in the matching `samples/##-language/tutorials/` directory for Python, JavaScript, C, Go, Rust, Ruby, and Dart. All new video examples belong there, and the recorder reads those public files directly.

## Layout and prerequisites

Expected checkouts:

```text
~/Code/deskcite-sdk/        this repository
~/Code/mesgd-sdk/           upstream language SDKs
~/erlang/{agent,beamer,http,json,websocket}/
```

| Language | Entry point | Dependencies |
|---|---|---|
| Erlang | `erlang/src/deskcite.erl` | Erlang/OTP, beamer, mesgd Erlang SDK, json/http/websocket; framework for the agent example |
| JavaScript | `javascript/deskcite.mjs` | Node 22+, `npm install --prefix javascript`; mesgd SDK location in `MESGD_SDK` |
| Python | `python/deskcite/` | Python 3.9+; `pip install ./python`; mesgd Python directory on `PYTHONPATH`, and its cryptography dependency for events |
| Ruby | `ruby/deskcite.rb` | Ruby/OpenSSL; `MESGD_SDK` points at upstream checkout |
| Go | `go/` package `deskcite` | Go 1.21+; local module replacement points at sibling mesgd SDK |
| Rust | `rust/` crate `deskcite` | Cargo, C compiler, libcurl and OpenSSL development libraries; sibling `mesgd-pki` crate |
| C | `c/deskcite.h` | C11, libcurl with WebSocket support, OpenSSL, upstream mesgd and cJSON sources |
| Dart | `dart/lib/deskcite.dart` | Dart 3; path dependency on the sibling `mesgd` Dart SDK |

Rust and C share a small libcurl HTTPS engine in `c/deskcite_http.c`. Build Rust from this full repository; its build script includes that source. The local Go replacement and Rust path dependency must be changed to released upstream versions before registry publication.

## Credentials

Pass an already-issued JWT/mesgd bearer to the client. For product integrations, create a scoped key in Deskcite **Settings → API Keys**; see the service's [API-key documentation](../../erlang/deskcite/documentation/api-keys.md). A trusted credential owner can also issue managed agent credentials with the existing mesgd `issue`/`roll` workflow. The SDK does not issue credentials, assign roles, log in or consume OTP codes.

Product HTTPS permissions, import-event subscriptions and general message publishing are separate capabilities. Deskcite API keys cannot publish arbitrary bus messages. Use an appropriately scoped mesgd messaging credential for those examples. Role requirements are documented by the service; there is no agent-specific authorization bypass. See [mesgd account authentication](../mesgd-sdk/AUTH.md) and the current server routing documentation.

`refresh` calls `POST /auth/refresh` once. A successful refresh retires the prior bearer. Pause new work, obtain the replacement, atomically replace the host's stored credential, close old event connections, and reconnect with the replacement before resuming. For a Deskcite API key, refresh preserves its role, filters and original absolute expiry; it does not extend its lifetime. Refresh is never retried automatically. Expired/revoked credentials need trusted reprovisioning. `logout` revokes a session. Do not embed live tokens in source control or command-line arguments.

## Product API

All languages expose `call(operation, arguments)` and named convenience methods. Arguments use the API's JSON field names. Go uses exported CamelCase names; Dart uses lowerCamelCase; C uses `deskcite_*` functions/macros. JavaScript, Python, Ruby, Rust and Erlang use the snake_case names below.

| Operation | HTTPS route | Arguments |
|---|---|---|
| `status` | GET `/deskcite` | none |
| `similar` | POST `/deskcite/similar` | `text`, optional `n` (1–100) |
| `ask` | POST `/deskcite/ask` | `text`; nearest stored answer, not synthesis |
| `rate` | POST `/deskcite/rate` | `id`, original `text`, `vote`: up/down/clear; shared feedback |
| `question` | GET `/deskcite/question/ID` | `id`; convenience method accepts a string |
| `create_question` | POST `/deskcite/question` | `question`, `answer`, `path`, optional `segment`, `headings` |
| `search` | POST `/deskcite/search` | `q`, optional `types`, `document` |
| `search_graph` | POST `/deskcite/search/graph` | search fields, optional `mode`, `hop` |
| `document` | GET source URL path | `path`; convenience method accepts a string |
| `import_source` | POST `/deskcite/import` | `url`, or `name`/`content`; optional `encoding`, `folder` |
| `embed` | POST `/deskcite/embed` | none |
| `agents` | GET `/deskcite/agents` | none |
| `schedules` | GET `/deskcite/agents/schedules` | none |
| `tasks` | POST `/deskcite/agents/tasks` | `action: cancel_queued` |
| `schedule` | POST `/deskcite/agents/schedule` | full save/toggle/propose/calendar payload, including existing `id`/`version` when editing |
| `refresh` | POST `/auth/refresh` | none |
| `logout` | POST `/auth/logout` | none |

`api/operations.json` is the shared route contract. Search uses the documented POST variant to keep Unicode and filters in JSON. Server validation remains authoritative. The SDK does not invent alternate schemas for erag search results. `document` accepts an already-encoded `/deskcite/documents/...` path returned by the service, including the prefix; it rejects origins, unrelated paths, queries, fragments, and traversal. Other source paths are citations, not necessarily downloadable URLs.

Success preserves HTTP status, headers, and body. JavaScript/Python/Ruby/Erlang/Dart decode JSON success bodies and return raw bytes for documents. Go/Rust/C return bytes for every response, with `Response.JSON`, `Response::json`, or cJSON available for decoding. Errors preserve raw bytes because authentication middleware and proxies may return non-JSON bodies.

| Language | Success | HTTP failure |
|---|---|---|
| Erlang | `{ok, #{status => N, headers => H, body => B}}` | `{error, #{status => N, headers => H, body => Bytes}}`; network errors use `{error, {transport, Reason}}` |
| JavaScript | `{status, headers, body}` | `DeskciteError.response` |
| Python | dictionary with `status`, `headers`, `body` | `DeskciteError.response` |
| Ruby | hash with symbol keys | `Deskcite::Error#response` |
| Go | `*Response` | `*HTTPError` contains response; network failures return ordinary errors |
| Rust | `Response` | `Error::Http(Response)` or a transport/input error |
| C | `dc_response`, return 0 | -2 for HTTP error with response retained, -1 for invalid input, positive CURLcode for transport failure; always free responses with `dc_response_free` |
| Dart | `Response` with `status`, `headers`, `body` | `DeskciteError.response` |

Erlang `refresh/1` returns `{ok, NewClient, Response}` to make replacement explicit. Other wrappers return the ordinary refresh response; pass its `access_token` to the token setter. C convenience methods accept a cJSON arguments object (including `id` or `path`), or NULL for no arguments.

All HTTPS adapters verify server certificates and hostnames and refuse redirects. They use a 30-second request/read timeout by default. Configure a private CA rather than disabling verification: Erlang `cacerts`, Python `context`, Ruby `ca_file`, Go a verifying HTTP transport, Rust `ca_file`, C `client.ca_file`, Dart `securityContext`, Node `NODE_EXTRA_CA_CERTS`.

No wrapper automatically replays writes. `201` means a record was created; creation does not embed it. `202` for import/embed means accepted or running, not complete. Search to verify indexing. Imports have no durable job ID, and repeating one can repeat work. Preserve source paths/headings as citations and treat distance as a ranking signal, not calibrated confidence. Enforce the host application's disclosure policy before presenting results.

## Examples

For complete runnable search, pub/sub agent and credential-refresh programs in the seven transport languages, see [Tutorial samples](samples/TUTORIALS.md). Run `make test-tutorials` for the isolated 21-example checks.

Set `DESKCITE_URL` to your HTTPS instance origin and obtain `DESKCITE_TOKEN` from your secret provider. For local source examples:

```sh
export MESGD_SDK="$HOME/Code/mesgd-sdk"
export PYTHONPATH="$HOME/Code/deskcite-sdk/python:$MESGD_SDK/python"
```

Python:

```python
import os
import deskcite
c = deskcite.Client(os.environ['DESKCITE_URL'], os.environ['DESKCITE_TOKEN'])
result = c.similar({'text': 'How do I reset an authenticator?', 'n': 8})
for row in result['body']['rows']:
    print(row['answer'], row['path'], row['headings'])
```

JavaScript:

```javascript
import * as deskcite from './javascript/deskcite.mjs';
const c = new deskcite.Client(process.env.DESKCITE_URL, process.env.DESKCITE_TOKEN);
const result = await c.similar({text: 'How do I reset an authenticator?', n: 8});
console.log(result.body.rows);
const events = await c.events(message => console.log(message));
// Later: events.close();
```

Ruby:

```ruby
require_relative 'ruby/deskcite'
c = Deskcite::Client.new(ENV.fetch('DESKCITE_URL'), ENV.fetch('DESKCITE_TOKEN'))
puts c.similar({'text' => 'How do I reset an authenticator?'})[:body]
```

Go (local development: require `deskcite-sdk` and replace it with this repo's `go` directory; the consuming module also needs the `mesgd-sdk` replacement):

```go
c, err := deskcite.New(os.Getenv("DESKCITE_URL"), os.Getenv("DESKCITE_TOKEN"), nil)
if err != nil { return err }
r, err := c.Similar(context.Background(), map[string]any{"text": "How do I reset an authenticator?"})
if err != nil { return err }
var result map[string]any
if err := r.JSON(&result); err != nil { return err }
```

Rust (add this repo's `rust` directory as a path dependency; it exports crate `deskcite`):

```rust
let c = deskcite::Client::new(&std::env::var("DESKCITE_URL")?, &std::env::var("DESKCITE_TOKEN")?)?;
let response = c.similar(serde_json::json!({"text":"How do I reset an authenticator?"}))?;
let result = response.json()?;
```

C:

```c
curl_global_init(CURL_GLOBAL_DEFAULT);
deskcite c;
if (deskcite_init(&c, getenv("DESKCITE_URL"), getenv("DESKCITE_TOKEN"))) return 1;
cJSON *args = cJSON_Parse("{\"text\":\"How do I reset an authenticator?\"}");
dc_response response;
int rc = deskcite_similar(&c, args, &response);
/* Inspect rc/status, parse response.body with response.body_len as needed. */
dc_response_free(&response);
cJSON_Delete(args);
deskcite_free(&c);
curl_global_cleanup();
```

Compile/link `c/deskcite.c`, `c/deskcite_http.c`, upstream `c/mesgd.c`, `c/pki.c`, and `3rd-party/cJSON/cJSON.c` with `-lcurl -lssl -lcrypto` and the corresponding include paths. `make tests/c_test` provides a full build example.

## Erlang SDK and reference agent

```sh
make erlang
```

In a **separate Erlang VM** from the Deskcite service, with the agent framework and its dependencies already built:

```erlang
code:add_patha(filename:absname("erlang/ebin")).
C = deskcite:new(os:getenv("DESKCITE_URL"), list_to_binary(os:getenv("DESKCITE_TOKEN"))).
{ok, #{body := Results}} = deskcite:similar(C, #{<<"text">> => <<"OTP recovery">>, <<"n">> => 8}).

%% Start/configure the existing agent application as usual, then:
agent:start().
deskcite_agent:install(C).
deskcite_agent:chat(C, <<"Find our authenticator recovery procedure and cite the source.">>).
```

The example exposes six read tools named `deskcite_remote_*`. `install(C, #{allow_writes => true})` adds import, embed, and shared feedback tools. Reinstalling without that flag removes the optional write tools. This controls these Deskcite tools; the framework's other tools retain their existing permissions. Reinstall after the framework's tool registry restarts. LLM execution uses the framework's configured providers; the SDK does not configure or provision a model.

For rotation, install a zero-argument provider instead of a fixed client:

```erlang
%% Your credential owner implements current_client/0 and atomic replacement.
deskcite_agent:install(fun my_credentials:current_client/0).
```

The Deskcite server already has a different `deskcite_agent` module for local imports. Keep this reference client in a separate VM and explicitly put this SDK's `erlang/ebin` first on the code path. Do not build the example into the server's global beamer output directory.

## Events

`events` connects the underlying mesgd client to `wss://HOST/deskcite/events` with the same bearer. It returns that client's connection. JavaScript and Erlang dispatch through their runtime; Python/Ruby/Go/Rust/C require the host's `recv`/`Recv`/`mesgd_recv` loop. Close using the underlying client's close operation (or Erlang `close_events/1`). Use OTP supervision or the host's connection manager for recovery. Open a fresh connection after token replacement.

Erlang `events(C, Handler, #{key_file => Path})` delegates to mesgd, which initializes a local PKI identity even for plain event reception; choose a private writable key path. Its current WSS client uses the VM CA store (`public_key:cacerts_load/1` for a private CA), separately from the HTTPS client's `cacerts` option. Rust passes a mesgd `Options` identity/connector. Go accepts mesgd `Options`; C uses upstream `MESGD_CA`; Python uses the client's verifying SSL context; Ruby supplies a verifying context and hostname checks. JavaScript uses a `ws` adapter with an Authorization header and only `json` as a subprotocol to accommodate the broker's exact protocol-header spacing. Tests can inject a compatible adapter.

Events are live, with no replay guarantee. Registering a handler after connection establishment can miss early events. Types include `import.start`, `import.progress`, `import.done`, and `import.error`. Correlate by `source`; simultaneous imports of the same source are ambiguous. The wrappers inherit upstream WebSocket limits: Python/Go/Ruby/Rust have limited frame/upgrade handling; C requires a libcurl build with WSS support and has receive chunk/partial-write limitations. The C event adapter rejects credentials that exceed upstream's fixed 4096-byte protocol-header buffer instead of silently truncating them. These wrappers do not add automatic reconnection, automatic signature verification, durable jobs, or event replay.

## Build and verification

```sh
npm install --prefix javascript
# Install mesgd Python requirements if not already present.
make test
```

`make test` builds the clients, checks Erlang formatting/failure-handling, checks generated contract copies, runs unit checks, and runs all seven languages against an isolated HTTPS/WSS fixture with a temporary CA. It needs permission to bind localhost, OpenSSL CLI, and the dependencies above. It uses dummy credentials and does not contact a deployed Deskcite service. Real deployed authorization, imports/indexing, schedule execution, and a live LLM are not exercised by this fixture. The Erlang integration test registers/invokes tools through the actual agent framework. Select languages with `node tests/integration.mjs Python Go` after building.

Update `api/operations.json`, synchronize the Erlang dispatch table, run `node scripts/generate.mjs`, and run `make test` when adding a route. Generated package-local manifests/aliases are checked for drift.

Sources inspected on 2026-11-10: mesgd-sdk `4e87422753c4b34068dd90f14f9cec7abbb93931`, Deskcite `d5c082a60990d78ebf1283c84baacbcde0d79923`, agent `c9ebf2fe0ae3a2e4a59ee7ab8ff52166aa2951a6`, mesgd `f399dec8a9e81b8d10e49a7ee24643ef2d0bd706`. The SDK was tested against the local working copies; these hashes identify their base revisions, not a claim that those working copies were clean.
