import json
import os
import sys
from mesgd import Mesgd


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("server", "client"):
        raise SystemExit("usage: python pubsub.py server|client")
    role = sys.argv[1]
    address = "service" if role == "server" else "client"
    origin = os.environ["MESGD_WSS"].rstrip("/")
    conn = Mesgd.connect(origin + "/to=" + address,
                         token=os.environ.get("MESGD_TOKEN"))
    done = False

    def receive(message):
        nonlocal done
        if role == "server":
            print("agent received:", json.dumps(message["body"]), flush=True)
            conn.send({"to": message["from"], "from": "service",
                       "type": "echo.reply", "body": message["body"]})
        else:
            print(json.dumps(message["body"]), flush=True)
            done = True

    conn.on("echo.request" if role == "server" else "echo.reply", receive)
    print("ready: " + role, flush=True)
    try:
        if role == "client":
            conn.send({"to": "service", "from": "client",
                       "type": "echo.request", "body": {"text": "hello"}})
        while not done:
            conn.recv()
    finally:
        conn.close()


if __name__ == "__main__":
    main()
