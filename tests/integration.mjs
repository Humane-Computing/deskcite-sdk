// Isolated HTTPS/WSS contract fixture. Does not contact a deployed service.
import https from 'node:https';
import {createHash} from 'node:crypto';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn, spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const temp = mkdtempSync(join(tmpdir(), 'deskcite-test-'));
const ca = join(temp,'ca.pem'), key = join(temp,'key.pem'), leaf = join(temp,'server.pem');
function openssl(args) { const r=spawnSync('openssl',args,{encoding:'utf8'});assert.equal(r.status,0,r.stderr); }
openssl(['req','-x509','-newkey','rsa:2048','-nodes','-keyout',join(temp,'ca.key'),
  '-out',ca,'-days','1','-subj','/CN=Deskcite Test CA','-addext','basicConstraints=critical,CA:TRUE']);
openssl(['req','-new','-newkey','rsa:2048','-nodes','-keyout',key,'-out',join(temp,'server.csr'),'-subj','/CN=localhost']);
writeFileSync(join(temp,'extensions'),'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n');
openssl(['x509','-req','-in',join(temp,'server.csr'),'-CA',ca,'-CAkey',join(temp,'ca.key'),'-CAcreateserial',
  '-out',leaf,'-days','1','-extfile',join(temp,'extensions')]);
const failures = []; let captures=0, upgrades=0;
const routes = new Map([
  ['/deskcite','GET'],['/deskcite/similar','POST'],['/deskcite/ask','POST'],
  ['/deskcite/rate','POST'],['/deskcite/question','POST'],['/deskcite/search','POST'],
  ['/deskcite/search/graph','POST'],['/deskcite/import','POST'],['/deskcite/embed','POST'],
  ['/deskcite/agents','GET'],['/deskcite/agents/schedules','GET'],['/deskcite/agents/tasks','POST'],
  ['/deskcite/agents/schedule','POST'],['/auth/refresh','POST'],['/auth/logout','POST']
]);
const server = https.createServer({key:readFileSync(key),cert:readFileSync(leaf)},async(req,res)=>{
  try {
    if (req.url === '/capture') {captures++;res.end('capture');return;}
    const token=req.headers.authorization;
    assert.ok(['Bearer test-bearer','Bearer rotated-bearer'].includes(token),'missing or incorrect bearer');
    let expected=routes.get(req.url);
    if (req.url.startsWith('/deskcite/documents/') || req.url.startsWith('/deskcite/question/')) expected='GET';
    assert.equal(req.method,expected,`wrong method or path ${req.method} ${req.url}`);
    const chunks=[];for await(const chunk of req) chunks.push(chunk);
    const raw=Buffer.concat(chunks).toString();const args=raw ? JSON.parse(raw) : {};
    if (raw) assert.match(req.headers['content-type'],/application\/json/);
    if (args.text==='__error__') {res.writeHead(503,{'retry-after':'1'});res.end('unavailable');return;}
    if (args.text==='__redirect__') {res.writeHead(302,{location:`${origin}/capture`});res.end('redirect refused');return;}
    if (req.url.startsWith('/deskcite/documents/')) {
      res.writeHead(200,{'content-type':'application/pdf'});res.end(Buffer.from([0,255,10]));return;
    }
    const status=req.url==='/deskcite/question'?201:['/deskcite/import','/deskcite/embed'].includes(req.url)?202:200;
    res.writeHead(status,{'content-type':'application/json'});
    res.end(JSON.stringify({ok:true,status:status===202?'queued':'ok',path:req.url,args,
      credential:token==='Bearer rotated-bearer'?'rotated':'original',
      ...(req.url==='/auth/refresh'?{access_token:'rotated-bearer'}:{})}));
  } catch(e) {failures.push(e.message);res.writeHead(500);res.end('fixture assertion failed');}
});
const sockets=new Set();server.on('connection',s=>{sockets.add(s);s.on('close',()=>sockets.delete(s));});
server.on('upgrade',(req,socket)=>{
  try {
    assert.equal(req.url,'/deskcite/events');
    assert.ok(req.headers.authorization==='Bearer rotated-bearer' || req.headers['sec-websocket-protocol']==='json, rotated-bearer','incorrect event credential');
    upgrades++;
    const accept=createHash('sha1').update(req.headers['sec-websocket-key']+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
    socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Protocol: json\r\nSec-WebSocket-Accept: '+accept+'\r\n\r\n');
    socket.on('error',()=>{});socket.on('data',data=>{
      if ((data[0] & 15) === 8) socket.end(Buffer.from([0x88,0]));
    });
    setTimeout(()=>{if(!socket.destroyed){const msg=Buffer.from(JSON.stringify({type:'import.done',source:'fixture.md'}));socket.write(Buffer.concat([Buffer.from([0x81,msg.length]),msg]));}},150);
  } catch(e) {failures.push(e.message);socket.destroy();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`https://127.0.0.1:${server.address().port}`;
const env={...process.env, DS_TEST_URL:origin,DS_TEST_CA:ca,MESGD_CA:ca,NODE_EXTRA_CA_CERTS:ca,
  MESGD_SDK:process.env.MESGD_SDK || join(root,'../mesgd-sdk'),
  GOCACHE:process.env.GOCACHE || '/tmp/deskcite-go-cache'};
env.PYTHONPATH=[join(root,'python'),join(env.MESGD_SDK,'python')].join(':');
async function run(name,command,args,cwd=root) {
  console.log(`Checking ${name}...`);
  await new Promise((resolve,reject)=>{
    const child=spawn(command,args,{cwd,env:{...env,DS_TEST_KEY_FILE:join(temp,`${name}-keys.json`)},stdio:['ignore','pipe','pipe']});
    const timer=setTimeout(()=>{child.kill('SIGKILL');reject(new Error(`${name} timed out`));},60000);
    child.stdout.on('data',d=>process.stdout.write(d));child.stderr.on('data',d=>process.stderr.write(d));
    child.on('error',e=>{clearTimeout(timer);reject(e)});
    child.on('exit',code=>{clearTimeout(timer);code===0?resolve():reject(new Error(`${name} exited ${code}`));});
  });
}
try {
  const selected=process.argv.slice(2);
  const jobs=[
    ['Erlang','erl',['-noshell','-eval','code:add_patha(filename:absname("erlang/ebin")), deskcite_live_tests:run(), halt().']],
    ['JavaScript','node',['tests/javascript.mjs']],
    ['Python','python3',['tests/python_test.py']],
    ['Ruby','ruby',['tests/ruby_test.rb']],
    ['Go','go',['test','-count=1','-v','./...'],join(root,'go')],
    ['Rust','cargo',['test','--locked','--','--nocapture'],join(root,'rust')],
    ['C',join(root,'tests/c_test'),[]],
    ['Dart','dart',['test'],join(root,'dart')]
  ].filter(([name])=>!selected.length || selected.includes(name));
  for(const job of jobs) await run(...job);
  assert.equal(captures,0,'a client followed a redirect with credentials');
  assert.deepEqual(failures,[]);
  assert.equal(upgrades,jobs.length,'each client must receive a real WSS event');
  console.log(`PASS: ${jobs.length} languages; verified HTTPS and WSS, no redirect following.`);
} finally {
  for(const socket of sockets) socket.destroy();
  await new Promise(resolve=>server.close(resolve));
  rmSync(temp,{recursive:true,force:true});
}
