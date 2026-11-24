"""Deskcite HTTPS product API and mesgd WebSocket events."""
import json
import ssl
from pathlib import Path
from urllib.parse import urlsplit, quote, unquote
from http.client import HTTPSConnection

OPERATIONS = json.loads(Path(__file__).with_name('operations.json').read_text())


class DeskciteError(Exception):
    def __init__(self, response):
        self.response = response
        super().__init__(f"Deskcite HTTP {response['status']}")


class Client:
    def __init__(self, origin, token, *, context=None, timeout=30, transport=None, mesgd=None):
        u = urlsplit(origin)
        if u.scheme != 'https' or not u.hostname or u.username or u.password or u.path not in ('', '/') or u.query or u.fragment:
            raise ValueError('expected an HTTPS origin')
        self.origin = origin.rstrip('/')
        self._host, self._port = u.hostname, u.port or 443
        self._context = context or ssl.create_default_context()
        if self._context.verify_mode != ssl.CERT_REQUIRED or not self._context.check_hostname:
            raise ValueError('TLS certificate and hostname verification required')
        self.timeout, self._transport, self._mesgd = timeout, transport, mesgd
        self.set_token(token)

    def set_token(self, token):
        if not isinstance(token, str) or not token or any(ord(c) < 33 or ord(c) > 126 for c in token):
            raise ValueError('expected bearer token')
        self._token = token

    def _https(self, method, path, body, token):
        headers = {'Accept': 'application/json', 'Authorization': 'Bearer ' + token}
        payload = None if body is None else json.dumps(body, separators=(',', ':')).encode()
        if payload is not None:
            headers['Content-Type'] = 'application/json'
        conn = HTTPSConnection(self._host, self._port, context=self._context, timeout=self.timeout)
        try:
            conn.request(method, path, payload, headers)
            r = conn.getresponse()
            return r.status, dict(r.getheaders()), r.read()
        finally:
            conn.close()

    def call(self, operation, args=None):
        args = {} if args is None else args
        if not isinstance(args, dict):
            raise ValueError('expected argument map')
        spec = OPERATIONS[operation]
        path = spec['path']
        if spec['kind'] == 'id':
            if not isinstance(args.get('id'), str) or not args['id']:
                raise ValueError('expected id')
            path += quote(args['id'], safe='')
        if spec['kind'] == 'document':
            path = args['path']
            decoded = unquote(path)
            if not path.startswith('/deskcite/documents/') or any(c in path for c in '?#\\') or any(ord(c) <= 32 for c in path) or any(ord(c) < 32 or ord(c) == 127 or c == '\\' for c in decoded) or any(s in ('.', '..') for s in decoded.split('/')):
                raise ValueError('expected a Deskcite document URL path')
        if spec['kind'] == 'none' and args:
            raise ValueError('operation takes no arguments')
        status, headers, raw = (self._transport or self._https)(spec['method'], path,
            args if spec['kind'] == 'json' else None, self._token)
        response = dict(status=status, headers=headers, body=raw)
        if not 200 <= status < 300:
            raise DeskciteError(response)
        if spec['kind'] != 'document':
            response['body'] = json.loads(raw)
        return response

    def question(self, id):
        return self.call('question', {'id': id})

    def document(self, path):
        return self.call('document', {'path': path})

    def events(self, handler, **options):
        cls = self._mesgd
        if cls is None:
            from mesgd import Mesgd
            cls = Mesgd
        options['token'] = self._token
        options['ssl_context'] = self._context
        conn = cls.connect(self.origin.replace('https:', 'wss:', 1) + '/deskcite/events', **options)
        conn.on('*', handler)
        return conn


def _method(operation):
    def method(self, args=None):
        return self.call(operation, args)
    method.__name__ = operation
    return method


for _op in OPERATIONS:
    if not hasattr(Client, _op):
        setattr(Client, _op, _method(_op))
