import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Client, DeskciteError} from '../javascript/deskcite.mjs';
const origin = process.env.DS_TEST_URL;
const client = new Client(origin, 'test-bearer');
const ops = JSON.parse(readFileSync(new URL('../api/operations.json', import.meta.url)));
for (const [op, spec] of Object.entries(ops)) {
  if (['refresh','document','question'].includes(op)) continue;
  const r = await client.call(op, spec.kind === 'json' ? {text:'café & ?', q:'test', action:'calendar'} : {});
  assert.equal(r.body.ok, true);
}
assert.match((await client.question('id/ ?#')).body.path, /id%2F%20%3F%23$/);
assert.deepEqual([...(await client.document('/deskcite/documents/a%20b.pdf')).body], [0,255,10]);
for (const [text, status] of [['__error__',503], ['__redirect__',302]]) {
  await assert.rejects(client.similar({text}), e => e instanceof DeskciteError && e.response.status === status && e.response.body.length > 0);
}
for (const path of ['https://elsewhere.test/x', '/deskcite/documents/%2e%2e/x','/deskcite/documents/a?x=1']) {
  await assert.rejects(client.document(path));
}
const renewed = await client.refresh(); client.setToken(renewed.body.access_token);
assert.equal((await client.status()).body.credential, 'rotated');
const event = new Promise(async (resolve, reject) => {
  try { const conn = await client.events(m => { conn.close(); resolve(m); }); }
  catch (e) { reject(e); }
});
assert.equal((await event).type, 'import.done');
console.log('JavaScript: HTTPS routes, bytes, errors, rotation, WSS passed');
