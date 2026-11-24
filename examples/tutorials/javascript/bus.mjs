import {pathToFileURL} from 'node:url';
import {join} from 'node:path';
const {Mesgd} = await import(pathToFileURL(join(process.env.MESGD_SDK, 'javascript/mesgd.mjs')));
import WebSocket from '../../../javascript/node_modules/ws/wrapper.mjs';

// Send the bearer in an HTTP header, avoiding the broker's exact
// "json, TOKEN" spacing requirement for a subprotocol credential.
class BearerWebSocket extends WebSocket {
  constructor(url, protocols) {
    const [format, token] = protocols;
    super(url, [format], {headers: token ? {Authorization: `Bearer ${token}`} : {}});
  }
}

const role = process.argv[2];
if (!['server', 'client'].includes(role)) {
  throw new Error('usage: node pubsub.mjs server|client');
}
const address = role === 'server' ? 'service' : 'client';
const origin = process.env.MESGD_WSS.replace(/\/$/, '');
let conn;
try {
  conn = await Mesgd.connect(`${origin}/to=${address}`, {
    WebSocket: BearerWebSocket, token: process.env.MESGD_TOKEN
  });
} catch {
  throw new Error('WebSocket connection failed; check TLS, bearer, and broker URL');
}

if (role === 'server') {
  conn.on('echo.request', message => {
    console.log('agent received:', JSON.stringify(message.body));
    conn.send({to: message.from, from: 'service',
      type: 'echo.reply', body: message.body}).catch(error => {
      console.error(error.message);
      conn.close();
      process.exitCode = 1;
    });
  });
  console.log('ready: server');
} else {
  try {
    const reply = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('reply timed out')), 10000);
      conn.on('echo.reply', message => {
        clearTimeout(timer);
        resolve(message.body);
      });
    });
    console.log('ready: client');
    await conn.send({to: 'service', from: 'client',
      type: 'echo.request', body: {text: 'hello'}});
    console.log(JSON.stringify(await reply));
  } finally {
    conn.close();
  }
}
