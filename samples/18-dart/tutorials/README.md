# Dart SDK video tutorials

## Website tutorials

Watch the [SDK tutorials](https://deskcite.com/sdk-guide.html) and follow along with these sources:

- [Dart: your first search](https://deskcite.com/sdk-guide.html#dart-search) — `hello.dart`.
- [Dart: send work to an agent](https://deskcite.com/sdk-guide.html#dart-agent-messaging) — `bus.dart`.
- [Dart: credentials and rotation](https://deskcite.com/sdk-guide.html#dart-credentials) — `rotate.dart` and `common.dart`.

Repository: [Humane-Computing/deskcite-sdk](https://github.com/Humane-Computing/deskcite-sdk).


These are the follow-along sources for the three SDK lessons: search, agent messaging, and credential refresh. See [shared setup](../../TUTORIALS.md) first. Resolve the path dependencies once (`deskcite` and `mesgd` are sibling source checkouts), then run the programs from the deskcite-sdk checkout root.

```sh
dart pub get -C samples/18-dart/tutorials
dart run samples/18-dart/tutorials/hello.dart
dart run samples/18-dart/tutorials/bus.dart server
dart run samples/18-dart/tutorials/bus.dart client
dart run samples/18-dart/tutorials/rotate.dart
```

Start the bus server in one terminal, wait for `ready: server`, then start the client in another. Run search before and after rotation to verify that the saved replacement is loaded. Read `common.dart` alongside `rotate.dart`.

`hello.dart` is self-contained and requires `DESKCITE_TOKEN_FILE` and `DESKCITE_CA`. `common.dart` supplies the credential loader and the atomic mode-0600 store for `rotate.dart`. The bus programs trust `MESGD_CA` when it is set and otherwise use system trust; the credential store is a Unix single-owner demonstration, not a production vault.
