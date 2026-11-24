import {startFixture} from './tutorial-fixture.mjs';
import {spawn} from 'node:child_process';
import {readFileSync,statSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import assert from 'node:assert/strict';
const root=dirname(dirname(fileURLToPath(import.meta.url)));
const fixture=await startFixture();
const manifest=JSON.parse(readFileSync(join(root,'samples/tutorials.json'),'utf8'));
const commands=Object.fromEntries(Object.entries(manifest).map(([language,topics])=>[language,mode=>topics[mode].argv]));
const env={...process.env,...fixture.env,MESGD_SDK:join(root,'../mesgd-sdk'),PYTHONPATH:[join(root,'python'),join(root,'../mesgd-sdk/python')].join(':'),GOCACHE:'/tmp/deskcite-go-cache'};
function launch(command,args=[]){
 const [bin,...tail]=command;const p=spawn(bin,[...tail,...args],{cwd:root,env,stdio:['ignore','pipe','pipe']});let text='';
 const timer=setTimeout(()=>p.kill('SIGKILL'),30000);
 const done=new Promise((resolve,reject)=>{p.on('error',reject);p.stdout.on('data',d=>text+=d);p.stderr.on('data',d=>text+=d);p.on('close',code=>{clearTimeout(timer);code===0?resolve(text):reject(Error(`${bin}: exit ${code}: ${text}`))})});
 return{p,done,text:()=>text};
}
try{
 for(const[name,command]of Object.entries(commands)){
  const before=fixture.reset();env.MESGD_KEY_FILE=join(fixture.temp,name+'-keys.json');
  let out=await launch(command('hello')).done;assert.match(out,/Source: \/deskcite\/documents\/user-guide.md/);assert.doesNotMatch(out,/tutorial-token/);console.log(`PASS ${name} search`);
  out=await launch(command('rotate')).done;assert.match(out,/old bearer rejected/);assert.doesNotMatch(out,/tutorial-token/);assert.equal(readFileSync(fixture.env.DESKCITE_TOKEN_FILE,'utf8').trim(),'rotated-tutorial-token');assert.equal(statSync(fixture.env.DESKCITE_TOKEN_FILE).mode&0o777,0o600);assert.equal(fixture.counts().refreshes-before.refreshes,1);assert.equal(fixture.counts().oldRejected-before.oldRejected,1);
  await launch(command('hello')).done;console.log(`PASS ${name} rotation, retired bearer rejection, private atomic file and reload`);
  const service=launch(command('bus'),['server']);service.done.catch(()=>{});
  try{
   const deadline=Date.now()+15000;while(!service.text().includes('ready: server')){if(service.p.exitCode!==null)await service.done;if(Date.now()>deadline)throw Error('service not ready');await new Promise(r=>setTimeout(r,30))}
   out=await launch(command('bus'),['client']).done;assert.match(out,/"text"\s*:\s*"hello"/);assert.match(service.text(),/agent received:/);assert.equal(fixture.counts().replies-before.replies,1);console.log(`PASS ${name} WSS caller → echo agent → caller`);
  }finally{service.p.kill('SIGTERM');await service.done.catch(()=>{});}
 }
 console.log(`PASS: ${Object.keys(commands).length*3} public samples tutorials; isolated HTTPS/WSS fixture, no live account mutations.`);
}finally{await fixture.close()}
