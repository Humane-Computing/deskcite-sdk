import os
print('HTTPS server:', os.environ['DESKCITE_URL'])
print('Private credential file configured:', bool(os.environ['DESKCITE_TOKEN_FILE']))
print('Trusted certificate configured:', bool(os.environ['DESKCITE_CA']))
