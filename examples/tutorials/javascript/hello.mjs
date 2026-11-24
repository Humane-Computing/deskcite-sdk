import {load} from './common.mjs';
const [client] = await load();
const result = await client.similar({text: 'How do I upload a document in Deskcite?', n: 3});
for (const row of result.body.rows) {
  console.log(row.answer);
  console.log('Source:', row.path);
}
