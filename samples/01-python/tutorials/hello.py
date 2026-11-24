import os
import ssl
from pathlib import Path
from deskcite import Client

token = Path(os.environ['DESKCITE_TOKEN_FILE']).read_text().strip()
trust = ssl.create_default_context(cafile=os.environ['DESKCITE_CA'])
client = Client(os.environ['DESKCITE_URL'], token, context=trust)
result = client.similar({
    'text': 'How do I upload a document in Deskcite?', 'n': 3
})
for row in result['body']['rows']:
    print(row['answer'])
    print('Source:', row['path'])
