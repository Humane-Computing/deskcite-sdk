// Isolated protocol fixture: no deployed service, account or paid model calls.
import https from 'node:https';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
import {WebSocketServer} from '../javascript/node_modules/ws/wrapper.mjs';
export async function startFixture(){
 const temp=mkdtempSync(join(tmpdir(),'sdk-tutorial-')),ca=join(temp,'ca.pem');
 function openssl(args){const r=spawnSync('openssl',args,{encoding:'utf8'});if(r.status!==0)throw Error(r.stderr)}
 openssl(['req','-x509','-newkey','rsa:2048','-nodes','-keyout',join(temp,'ca.key'),'-out',ca,'-days','1','-subj','/CN=SDK Tutorial Fixture CA','-addext','basicConstraints=critical,CA:TRUE']);
 openssl(['req','-newkey','rsa:2048','-nodes','-keyout',join(temp,'key.pem'),'-out',join(temp,'request.pem'),'-subj','/CN=localhost']);
 writeFileSync(join(temp,'extensions'),'subjectAltName=DNS:localhost,IP:127.0.0.1\nbasicConstraints=critical,CA:FALSE\nextendedKeyUsage=serverAuth\n');
 openssl(['x509','-req','-in',join(temp,'request.pem'),'-CA',ca,'-CAkey',join(temp,'ca.key'),'-CAcreateserial','-out',join(temp,'server.pem'),'-days','1','-extfile',join(temp,'extensions')]);
 let token='tutorial-token',refreshes=0,searches=0,replies=0,oldRejected=0;
 const server=https.createServer({key:readFileSync(join(temp,'key.pem')),cert:readFileSync(join(temp,'server.pem'))},async(req,res)=>{
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
  if(req.headers.authorization!=='Bearer '+token){oldRejected++;res.writeHead(401);res.end('{"ok":false}');return}
  const chunks=[];for await(const c of req)chunks.push(c);
  if(req.method==='POST'&&req.url==='/deskcite/similar'){
   const args=JSON.parse(Buffer.concat(chunks));if(!args.text||args.n!==3){res.writeHead(400);res.end('{"ok":false}');return}searches++;
   res.end(JSON.stringify({ok:true,rows:[{answer:'Choose dataset, select your file, then Upload & Import.',path:'/deskcite/documents/user-guide.md',headings:'Upload a document',distance:.1}]}));
  }else if(req.method==='GET'&&req.url==='/deskcite'){res.end('{"ok":true,"questions":1,"answers":1}');}
  else if(req.method==='POST'&&req.url==='/auth/refresh'){
   token='rotated-tutorial-token';refreshes++;res.end(JSON.stringify({ok:true,access_token:token}));
  }else{res.writeHead(404);res.end('{"ok":false}');}
 });
 const sockets=new Set();server.on('connection',s=>{sockets.add(s);s.on('close',()=>sockets.delete(s))});
 const ws=new WebSocketServer({noServer:true});
 server.on('upgrade',(req,socket,head)=>{
  const bearer=req.headers.authorization?.replace(/^Bearer /,'')??req.headers['sec-websocket-protocol']?.split(',').map(x=>x.trim())[1];
  if(bearer!=='bus-tutorial-token'||!['/to=service','/to=client'].includes(req.url)){socket.end('HTTP/1.1 403 Forbidden\r\n\r\n');return}
  ws.handleUpgrade(req,socket,head,peer=>{peer.address=req.url.split('=')[1];ws.emit('connection',peer,req)});
 });
 ws.on('connection',peer=>peer.on('message',bytes=>{
  const message=JSON.parse(bytes);if(message.type==='echo.reply')replies++;
  for(const target of ws.clients)if(target.readyState===1&&target.address===message.to)target.send(JSON.stringify(message));
 }));
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const origin=`https://127.0.0.1:${server.address().port}`,file=join(temp,'credential');
 const env={DESKCITE_URL:origin,DESKCITE_CA:ca,DESKCITE_TOKEN_FILE:file,MESGD_WSS:origin.replace('https:','wss:'),MESGD_TOKEN:'bus-tutorial-token',MESGD_CA:ca,SSL_CERT_FILE:ca,NODE_EXTRA_CA_CERTS:ca};
 return{temp,env,reset(){token='tutorial-token';writeFileSync(file,token+'\n',{mode:0o600});return{refreshes,searches,replies,oldRejected}},counts:()=>({refreshes,searches,replies,oldRejected}),async close(){for(const p of ws.clients)p.terminate();for(const s of sockets)s.destroy();await new Promise(r=>ws.close(r));await new Promise(r=>server.close(r));rmSync(temp,{recursive:true,force:true})}};
}
if(process.argv.includes('--serve')){
 const fixture=await startFixture();fixture.reset();
 const quote=s=>"'"+s.replaceAll("'","'\\''")+"'";
 const envfile=join(fixture.temp,'demo.env');writeFileSync(envfile,Object.entries(fixture.env).map(([k,v])=>`export ${k}=${quote(v)}`).join('\n')+'\n',{mode:0o600});
 console.log('LOCAL TEST FIXTURE — protocol demonstration; no production knowledge or credentials.');console.log('Environment file: '+envfile);
 for(const signal of ['SIGINT','SIGTERM'])process.on(signal,async()=>{await fixture.close();process.exit(0)});
}
