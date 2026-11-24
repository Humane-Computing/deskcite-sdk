# Ruby SDK video tutorials

These are the follow-along sources for the three SDK lessons: search, agent messaging, and credential refresh. See [shared setup](../../TUTORIALS.md) first. Run these commands from the deskcite-sdk checkout root.

```sh
ruby samples/11-ruby/tutorials/hello.rb
ruby samples/11-ruby/tutorials/bus.rb server
ruby samples/11-ruby/tutorials/bus.rb client
ruby samples/11-ruby/tutorials/rotate.rb
```

Start the bus server in one terminal, wait for `ready: server`, then start the client in another. Run search before and after rotation to verify that the saved replacement is loaded. Read the accompanying helper source alongside each program.
