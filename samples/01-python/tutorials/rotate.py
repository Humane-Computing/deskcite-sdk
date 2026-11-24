import os
from common import load, store
from deskcite import DeskciteError
os.environ['DESKCITE_TOKEN_FILE']  # A private host-owned file is required before refresh.
client, old = load()
replacement = client.refresh()['body']['access_token']  # Exactly one attempt.
store(replacement)  # Atomic replacement before resuming work; never print the bearer.
client.set_token(replacement)
client.status()
client.set_token(old)
try:
    client.status()
    raise RuntimeError('Old bearer was unexpectedly accepted')
except DeskciteError as error:
    if error.response['status'] != 401: raise
client.set_token(replacement)
print('Credential rotated and saved; replacement works; old bearer rejected.')
