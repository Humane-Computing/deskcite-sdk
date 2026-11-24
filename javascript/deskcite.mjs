import operations from './operations.json' with {type: 'json'};
import {pathToFileURL} from 'node:url';
import {join} from 'node:path';

export class DeskciteError extends Error {
  constructor(response) { super(`Deskcite HTTP ${response.status}`); this.response = response; }
}
function bearer(token) {
  if (typeof token !== 'string' || !/^[\x21-\x7e]+$/.test(token)) throw new TypeError('expected bearer token');
  return token;
}
function documentPath(path) {
  if (typeof path !== 'string' || !path.startsWith('/deskcite/documents/') || /[?#\s\\]/.test(path))
    throw new TypeError('expected a Deskcite document URL path');
  const decoded = decodeURIComponent(path);
  if (/[\x00-\x1f\x7f\\]/.test(decoded) || decoded.split('/').some(s => s === '.' || s === '..'))
    throw new TypeError('invalid document path');
  return path;
}
export class Client {
  #token;
  constructor(origin, token, {fetch: fetchImpl = globalThis.fetch, timeout = 30000, mesgd} = {}) {
    const u = new URL(origin);
    if (u.protocol !== 'https:' || u.username || u.password || u.pathname !== '/' || u.search || u.hash)
      throw new TypeError('expected an HTTPS origin');
    this.origin = u.origin; this.#token = bearer(token);
    this.fetch = fetchImpl; this.timeout = timeout; this.mesgd = mesgd;
  }
  setToken(token) { this.#token = bearer(token); }
  async call(operation, args = {}) {
    const spec = operations[operation];
    if (!spec || !args || typeof args !== 'object' || Array.isArray(args)) throw new TypeError('invalid operation or arguments');
    let path = spec.path;
    if (spec.kind === 'id') {
      if (typeof args.id !== 'string' || !args.id) throw new TypeError('expected id');
      path += encodeURIComponent(args.id);
    }
    if (spec.kind === 'document') path = documentPath(args.path);
    const body = spec.kind === 'json' ? JSON.stringify(args) : undefined;
    if (spec.kind === 'none' && Object.keys(args).length) throw new TypeError('operation takes no arguments');
    const headers = {Accept: 'application/json', Authorization: `Bearer ${this.#token}`};
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const raw = await this.fetch(this.origin + path, {method: spec.method, headers, body,
      redirect: 'manual', credentials: 'omit', cache: 'no-store', signal: AbortSignal.timeout(this.timeout)});
    const bytes = new Uint8Array(await raw.arrayBuffer());
    const response = {status: raw.status, headers: Object.fromEntries(raw.headers), body: bytes};
    if (raw.status < 200 || raw.status >= 300) throw new DeskciteError(response);
    if (spec.kind !== 'document') response.body = JSON.parse(new TextDecoder().decode(bytes));
    return response;
  }
  question(id) { return this.call('question', {id}); }
  document(path) { return this.call('document', {path}); }
  async events(handler, options = {}) {
    let Mesgd = this.mesgd;
    if (!Mesgd) {
      if (!process.env.MESGD_SDK) throw new Error('set MESGD_SDK or inject mesgd');
      ({Mesgd} = await import(pathToFileURL(join(process.env.MESGD_SDK, 'javascript/mesgd.mjs'))));
    }
    // ws sends a bearer header and selects json only; this avoids the broker's
    // exact subprotocol whitespace requirement. An adapter can be injected.
    let WebSocket = options.WebSocket;
    if (!WebSocket) {
      const {default: WS} = await import('ws');
      const token = this.#token;
      WebSocket = class extends WS {
        constructor(url) { super(url, ['json'], {headers: {Authorization: `Bearer ${token}`}, handshakeTimeout: 30000}); }
      };
    }
    const connection = await Mesgd.connect(this.origin.replace(/^https:/, 'wss:') + '/deskcite/events',
      {...options, WebSocket, token: this.#token});
    connection.on('*', handler);
    return connection;
  }
}
for (const operation of Object.keys(operations)) {
  if (!(operation in Client.prototype)) Object.defineProperty(Client.prototype, operation, {
    value(args = {}) { return this.call(operation, args); }
  });
}
