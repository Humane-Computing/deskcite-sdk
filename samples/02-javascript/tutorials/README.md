# JavaScript SDK video tutorials

These are the follow-along sources for the three SDK lessons: search, agent messaging, and credential refresh. See [shared setup](../../TUTORIALS.md) first. Run these commands from the deskcite-sdk checkout root.

```sh
node samples/02-javascript/tutorials/hello.mjs
node samples/02-javascript/tutorials/bus.mjs server
node samples/02-javascript/tutorials/bus.mjs client
node samples/02-javascript/tutorials/rotate.mjs
```

Start the bus server in one terminal, wait for `ready: server`, then start the client in another. Run search before and after rotation to verify that the saved replacement is loaded. Read the accompanying helper source alongside each program.

`show_setup.mjs` is the configuration check used during filming. It displays the configured server and broker and confirms that credential settings exist, without displaying the credentials. The videos run these exact source files from the SDK checkout; no separate recording-only implementation is used.
