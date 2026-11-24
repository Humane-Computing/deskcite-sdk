# Go SDK video tutorials

These are the follow-along sources for the three SDK lessons: search, agent messaging, and credential refresh. See [shared setup](../../TUTORIALS.md) first. Run these commands from the deskcite-sdk checkout root.

```sh
samples/07-go/tutorials/bin/hello
samples/07-go/tutorials/bin/bus server
samples/07-go/tutorials/bin/bus client
samples/07-go/tutorials/bin/rotate
```

Start the bus server in one terminal, wait for `ready: server`, then start the client in another. Run search before and after rotation to verify that the saved replacement is loaded. Read the accompanying helper source alongside each program.
