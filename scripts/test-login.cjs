const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const ts=require(path.join(process.env.DEVECO_HOME||'D:/DevEco/DevEco Studio','tools/hvigor/hvigor/node_modules/typescript'));
const root=path.resolve(__dirname,'../entry/src/main/ets');
function load(name,deps={}) {
 const exports={}; const source=ts.transpileModule(fs.readFileSync(path.join(root,name+'.ets'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
 vm.runInNewContext(source,{exports,require:key=>{assert.ok(deps[key],key);return deps[key];},Date,JSON,Error,console});return exports;
}
const http={RequestMethod:{GET:'GET',POST:'POST',PUT:'PUT',DELETE:'DELETE'},createHttp:()=>({destroy(){},async request(url,options){const res=await fetch(url,{method:options.method,headers:options.header,body:options.extraData||undefined,signal:AbortSignal.timeout(15000)});return {responseCode:res.status,result:await res.text()};}})};
const expiry=load('domain/ExpiryService');
const {ApiClient}=load('data/remote/ApiClient',{'@kit.NetworkKit':{http},'../../domain/ExpiryService':expiry});
const switches=[];let rejectDatabase=false;
const {SessionManager:S}=load('data/SessionManager',{'./remote/ApiClient':{ApiClient},'./local/AppDatabase':{AppDatabase:{async switchAccount(id){if(rejectDatabase)throw Error('database unavailable');switches.push(id||'guest');}}},'./local/ItemLocalRepository':{ItemLocalRepository:class{async setSetting(){} async setServer(){}}},'../reminder/ReminderService':{ReminderService:{async clear(){throw Error('permission denied');}}}});
async function main(){
 const session={user:{id:randomUUID(),username:'tester'},accessToken:'opaque',expiresAt:new Date(Date.now()+60000).toISOString()};
 assert.equal(S.active(),false);
 await S.enter(session,'http://localhost:18081');assert.equal(S.active(),true);assert.equal(switches.at(-1),session.user.id);
 ApiClient.baseUrl='http://other';assert.equal(S.active(),false);ApiClient.baseUrl=S.server;
 ApiClient.token='wrong';assert.equal(S.active(),false);ApiClient.token=session.accessToken;
 S.current={...session,expiresAt:new Date(0).toISOString()};assert.equal(S.active(),false);
 await S.clear();assert.equal(S.active(),false);assert.equal(switches.at(-1),'guest');
 rejectDatabase=true;await assert.rejects(()=>S.enter(session,'http://localhost:18081'));assert.equal(S.active(),false);rejectDatabase=false;
 console.log('PASS: login gate, account switching, notification failure isolation, expiry, origin/token binding, failed database transition');
 const url=process.argv[2];if(!url)return;
 ApiClient.baseUrl=url;ApiClient.token='';
 const username='login_'+randomUUID().replaceAll('-','').slice(0,16),password='local-login-test-password';
 const auth=await ApiClient.authenticate(username,password,true);ApiClient.token=auth.accessToken;
 const profile={displayName:'小满',avatarKey:'cat',bio:'认真生活',allergies:['花生'],dislikes:['香菜'],preferences:['清淡']};
 assert.equal((await ApiClient.saveProfile(profile)).displayName,'小满');await ApiClient.logout();
 const again=await ApiClient.authenticate(username,password,false);ApiClient.token=again.accessToken;
 assert.equal((await ApiClient.getProfile()).avatarKey,'cat');assert.equal((await ApiClient.getProfile()).allergies[0],'花生');await ApiClient.logout();
 const methods=await ApiClient.loginMethods();assert.equal(methods.huaweiEnabled,false);
 if(methods.phoneMode==='LOCAL_DEBUG'){
   const phone='139'+String(Math.floor(Math.random()*100000000)).padStart(8,'0');
   const challenge=await ApiClient.sendPhoneCode(phone);assert.match(challenge.debugCode,/^\d{6}$/);
   const authPhone=await ApiClient.phoneLogin(phone,challenge.debugCode);ApiClient.token=authPhone.accessToken;
   assert.equal((await ApiClient.getProfile()).allergies.length,0);
   await assert.rejects(()=>ApiClient.phoneLogin(phone,challenge.debugCode));
   ApiClient.token=authPhone.accessToken;await ApiClient.logout();
 }else throw Error('Use local-sms profile to exercise the approved debug phone flow');
 console.log('PASS: actual password register/login, profile persistence, local phone code login/replay denial and Huawei unavailable state');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
