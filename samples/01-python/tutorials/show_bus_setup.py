import os
from mesgd import Mesgd
print('WSS broker:', os.environ['MESGD_WSS'])
print('Messaging credential configured:', bool(os.environ['MESGD_TOKEN']))
