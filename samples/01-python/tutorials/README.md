# Python SDK video tutorials

These are the follow-along sources for the three SDK lessons: search, agent messaging, and credential refresh. See [shared setup](../../TUTORIALS.md) first. Run these commands from the deskcite-sdk checkout root.

```sh
python3 samples/01-python/tutorials/hello.py
python3 samples/01-python/tutorials/bus.py server
python3 samples/01-python/tutorials/bus.py client
python3 samples/01-python/tutorials/rotate.py
```

Start the bus server in one terminal, wait for `ready: server`, then start the client in another. Run search before and after rotation to verify that the saved replacement is loaded. Read the accompanying helper source alongside each program.

The filmed `hello.py` is self-contained and requires `DESKCITE_TOKEN_FILE` and `DESKCITE_CA`. `common.py` supplies the credential loader and atomic store for `rotate.py`. `show_setup.py` and `show_bus_setup.py` are the exact configuration checks used during filming. From this directory you can use the same short commands shown in the videos: `python3 hello.py`, `python3 bus.py server`, `python3 bus.py client`, and `python3 rotate.py`.
