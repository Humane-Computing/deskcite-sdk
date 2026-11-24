import {load, store} from './common.mjs';
if (!process.env.DESKCITE_TOKEN_FILE) throw new Error('Set DESKCITE_TOKEN_FILE before rotation');
const [client, old] = await load();
const replacement = (await client.refresh()).body.access_token; // One attempt only.
await store(replacement);
client.setToken(replacement);
await client.status();
client.setToken(old);
try {
  await client.status();
  throw new Error('Old bearer was unexpectedly accepted');
} catch(error) { if (error.response?.status !== 401) throw error; }
client.setToken(replacement);
console.log('Credential rotated and saved; replacement works; old bearer rejected.');
