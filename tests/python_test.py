import os
import ssl
from deskcite import Client, DeskciteError, OPERATIONS

c = Client(os.environ['DS_TEST_URL'], 'test-bearer', context=ssl.create_default_context(cafile=os.environ['DS_TEST_CA']))
for op, spec in OPERATIONS.items():
    if op in ('refresh', 'document', 'question'):
        continue
    args = dict(text='café & ?', q='test', action='calendar') if spec['kind'] == 'json' else {}
    assert c.call(op, args)['body']['ok']
assert c.question('id/ ?#')['body']['path'].endswith('id%2F%20%3F%23')
assert c.document('/deskcite/documents/a%20b.pdf')['body'] == bytes([0, 255, 10])
for text, status in [('__error__', 503), ('__redirect__', 302)]:
    try:
        c.similar({'text': text})
        raise AssertionError('expected error')
    except DeskciteError as e:
        assert e.response['status'] == status and e.response['body']
for path in ('https://elsewhere.test/x', '/deskcite/documents/%2e%2e/x', '/deskcite/documents/a?x=1'):
    try:
        c.document(path)
        raise AssertionError('accepted invalid path')
    except ValueError:
        pass
c.set_token(c.refresh()['body']['access_token'])
assert c.status()['body']['credential'] == 'rotated'
events = []
conn = c.events(events.append)
try:
    conn.recv()
    assert events[0]['type'] == 'import.done'
finally:
    conn.close()
print('Python: HTTPS routes, bytes, errors, rotation, WSS passed')
