import os
import ssl
from pathlib import Path
from deskcite import Client

def load():
    path = os.environ.get('DESKCITE_TOKEN_FILE')
    token = Path(path).read_text().strip() if path else os.environ['DESKCITE_TOKEN']
    context = ssl.create_default_context(cafile=os.environ.get('DESKCITE_CA'))
    return Client(os.environ['DESKCITE_URL'], token, context=context), token

def store(token):
    import tempfile
    target = Path(os.environ['DESKCITE_TOKEN_FILE'])
    fd, temp = tempfile.mkstemp(prefix='.rotate-', dir=target.parent)
    try:
        with os.fdopen(fd, 'w') as out:
            out.write(token + '\n'); out.flush(); os.fsync(out.fileno())
        os.replace(temp, target)
    finally:
        if os.path.exists(temp): os.unlink(temp)
