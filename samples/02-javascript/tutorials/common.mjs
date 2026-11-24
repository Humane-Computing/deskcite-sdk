import {readFile, open, rename, unlink} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {dirname, join} from 'node:path';
import {Client} from '../../../javascript/deskcite.mjs';
export async function load() {
  const file = process.env.DESKCITE_TOKEN_FILE;
  const token = file ? (await readFile(file, 'utf8')).trim() : process.env.DESKCITE_TOKEN;
  return [new Client(process.env.DESKCITE_URL, token), token];
}
export async function store(token) {
  const target = process.env.DESKCITE_TOKEN_FILE;
  const temp = join(dirname(target), '.rotate-' + randomUUID());
  const file = await open(temp, 'wx', 0o600);
  try { await file.writeFile(token+'\n'); await file.sync(); }
  finally { await file.close(); }
  try { await rename(temp, target); }
  catch(error) { await unlink(temp); throw error; }
}
