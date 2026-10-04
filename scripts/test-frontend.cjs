const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {DatabaseSync}=require('node:sqlite');
const root=path.resolve(__dirname,'../entry/src/main/ets');
const ts=require(path.join(process.env.DEVECO_HOME||'D:/DevEco/DevEco Studio','tools/hvigor/hvigor/node_modules/typescript'));
let checks=0;
function check(name,body){body(); checks++; console.log('PASS '+name);}
class Result {
  constructor(statement,args){this.names=statement.columns().map(c=>c.name);this.rows=statement.all(...args);this.index=-1;}
  goToNextRow(){return ++this.index<this.rows.length;}
  goToFirstRow(){this.index=0;return this.rows.length>0;}
  getColumnIndex(name){assert.ok(this.names.includes(name),name);return this.names.indexOf(name);}
  getString(i){return String(this.rows[this.index][this.names[i]]??'');}
  getLong(i){return Number(this.rows[this.index][this.names[i]]);}
  getDouble(i){return this.getLong(i);}
  isColumnNull(i){return this.rows[this.index][this.names[i]]==null;}
  close(){}
}
class Predicates {
  constructor(table){this.table=table;this.keys=[];this.args=[];}
  equalTo(key,value){this.keys.push(key+' = ?');this.args.push(value);return this;}
}
class Store {
  close() {} // The adapter retains memory files so account switching can reopen them.
  constructor(){this.db=new DatabaseSync(':memory:');this.failBatch=false;}
  get version(){return this.db.prepare('PRAGMA user_version').get().user_version;}
  set version(value){this.db.exec('PRAGMA user_version='+value);}
  beginTransaction(){this.db.exec('BEGIN');}
  commit(){this.db.exec('COMMIT');}
  rollBack(){this.db.exec('ROLLBACK');}
  async executeSql(sql,args=[]){if(this.failBatch&&sql.startsWith('UPDATE inventory_batch'))throw Error('injected batch failure');this.db.prepare(sql).run(...args);}
  async querySql(sql,args=[]){return new Result(this.db.prepare(sql),args);}
  async insert(table,values){const keys=Object.keys(values);return this.db.prepare(`INSERT INTO ${table} (${keys.join(',')}) VALUES (${keys.map(()=>'?').join(',')})`).run(...keys.map(k=>values[k])).lastInsertRowid;}
  async update(values,predicates){const keys=Object.keys(values);return this.db.prepare(`UPDATE ${predicates.table} SET ${keys.map(k=>k+' = ?').join(',')} WHERE ${predicates.keys.join(' AND ')}`).run(...keys.map(k=>values[k]),...predicates.args).changes;}
}
function loader(store, databases){
 const cache=new Map();
 const native={ '@kit.ArkTS':{util:{generateRandomUUID:randomUUID}},'@kit.ArkData':{relationalStore:{SecurityLevel:{S1:1},getRdbStore:async(context,config)=>{if(!databases)return store;if(!databases.has(config.name))databases.set(config.name,new Store());return databases.get(config.name);},RdbPredicates:Predicates}} };
 function load(file){file=path.resolve(file); if(cache.has(file))return cache.get(file);const exports={};cache.set(file,exports);
 const result=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}});
 vm.runInNewContext(result.outputText,{exports,require:name=>{if(native[name])return native[name];if(name.startsWith('.'))return load(path.resolve(path.dirname(file),name+'.ets'));throw Error('Unexpected import '+name);},console,Date,JSON,Error,setTimeout});
 return exports;
 }
 return file=>load(path.join(root,file+'.ets'));
}
async function main(){
 const store=new Store(),load=loader(store);
 const {InventoryDomain:D}=load('algorithm/InventoryDomain'),{ReminderPlan}=load('algorithm/ReminderPlan');
 const now=Date.now();
 const make=(id='one')=>({id,name:'牛奶',categoryId:'food',expiryDate:'2026-10-30',lifecycleStatus:'ACTIVE',quantity:2,unit:'盒',createdAt:now,updatedAt:now,brand:'测试品牌',location:'冷藏',notes:'包装完整',reminderDays:7});
 check('拒绝溢出的自然日期',()=>{assert.equal(D.validDate('2026-02-30'),false);assert.equal(D.validDate('2024-02-29'),true);});
 check('拒绝非正数量、空名称和负提醒天数',()=>{assert.ok(D.validate({...make(),quantity:0}));assert.ok(D.validate({...make(),name:' '}));assert.ok(D.validate({...make(),reminderDays:-1}));});
 check('开封后期限取更早日期',()=>assert.equal(D.evaluate({...make(),openedDate:'2026-10-01',afterOpenValue:2,afterOpenUnit:'DAY'},'2026-10-03').effectiveExpiryDate,'2026-10-03'));
 check('临期边界与已处理状态分离',()=>{assert.equal(D.evaluate(make(),'2026-10-23').status,'NEAR_EXPIRY');assert.equal(D.urgent([{...make(),lifecycleStatus:'CONSUMED'}],'2026-10-30').length,0);});
 check('稍后处理不修改日期或隐藏库存',()=>{const item={...make(),snoozeUntil:'2026-10-31'};assert.equal(D.urgent([item],'2026-10-30').length,0);assert.equal(D.filter([item],'冷藏','all','ACTIVE',0,'2026-10-30').length,1);assert.equal(D.evaluate(item,'2026-10-30').remainingDays,0);});
 check('默认库存不混入已处理物品',()=>assert.equal(D.filter([make(),{...make('two'),lifecycleStatus:'DISCARDED'}],'','all','ACTIVE',0,'2026-10-01').length,1));
 check('带标签文本提取且不臆测无标签日期',()=>{const draft=D.parseText('名称：牛奶\n生产日期：2026/10/3\n保质期：30天');assert.equal(draft.name,'牛奶');assert.equal(draft.production,'2026-10-03');assert.equal(draft.shelfLife,'30');assert.equal(D.parseText('牛奶 2026-10-03').expiry,'');});
 check('未来提醒计划、09:00、本地时区与已过时过滤',()=>{const plans=ReminderPlan.create([make()],new Date('2026-10-22T09:00:00').getTime());assert.equal(plans.length,1);assert.equal(new Date(plans[0].at).getHours(),9);assert.equal(new Date(plans[0].at).getDate(),23);assert.equal(ReminderPlan.create([make()],new Date('2026-10-24T09:00:00').getTime()).length,0);});
 check('已用完与删除物品不注册提醒',()=>assert.equal(ReminderPlan.create([{...make(),deletedAt:now},{...make(),lifecycleStatus:'CONSUMED'}],0).length,0));
 const {AppDatabase}=load('data/local/AppDatabase'); AppDatabase.initialize({}); await AppDatabase.getStore();
 const {ItemLocalRepository}=load('data/local/ItemLocalRepository'),repo=new ItemLocalRepository();
 check('空库迁移至 v4',()=>assert.equal(store.version,4));
 await repo.create(make()); let item=(await repo.listActive())[0];
 check('持久化身份、批次、备注和远端 ID',()=>{assert.equal(item.location,'冷藏');assert.equal(item.brand,'测试品牌');assert.equal(item.quantity,2);assert.ok(item.remoteId);assert.equal(store.db.prepare('SELECT count(*) AS n FROM inventory_batch').get().n,1);});
 await repo.acknowledge(item); check('确认同步清理待上传状态',()=>assert.equal(store.db.prepare('SELECT pending FROM item').get().pending,0));
 await repo.update({...item,name:'更新牛奶',openedDate:'2026-10-01',afterOpenValue:3,afterOpenUnit:'DAY'});
 await repo.acknowledge(item);check('旧版本确认不会吞掉新编辑',()=>assert.equal(store.db.prepare('SELECT pending FROM item').get().pending,1));
 item=(await repo.listActive())[0];check('编辑后扩展字段完整',()=>{assert.equal(item.quantity,2);assert.equal(item.notes,'包装完整');assert.equal(item.openedDate,'2026-10-01');});
 store.failBatch=true;await assert.rejects(()=>repo.update({...item,name:'不应保留'}));store.failBatch=false;
 check('批次保存失败时身份修改回滚',()=>assert.equal(store.db.prepare('SELECT name FROM item').get().name,'更新牛奶'));
 await repo.transition(item,'CONSUMED'); item=(await repo.listActive())[0];await repo.transition(item,'CONSUMED');
 check('同一已处理状态不重复创建流水',()=>assert.equal(store.db.prepare('SELECT count(*) AS n FROM consumption_record').get().n,1));
 let records=await repo.records();check('消费统计来自有效流水',()=>assert.equal(D.overview([],records,'2026-10-03').consumed,1));
 await repo.transition(item,'ACTIVE'); records=await repo.records();check('恢复在库撤销统计并保留审计记录',()=>{assert.equal(records.length,1);assert.equal(records[0].revoked,1);assert.equal(D.overview([],records,'2026-10-03').consumed,0);});
 await repo.addShopping('牛奶');await repo.addShopping('牛奶');let shopping=await repo.shopping();check('补货去重',()=>assert.equal(shopping.length,1));
 await repo.toggleShopping(shopping[0]);shopping=await repo.shopping();check('勾选补货持久化',()=>assert.equal(shopping[0].done,1));await repo.removeShopping(shopping[0].id);
 await repo.softDelete(item.id);check('软删除保留批次与处理历史',()=>{assert.equal(store.db.prepare('SELECT count(*) AS n FROM inventory_batch').get().n,1);assert.equal(store.db.prepare('SELECT count(*) AS n FROM consumption_record').get().n,1);});assert.equal((await repo.listActive()).length,0);assert.equal((await repo.listPending()).length,1);
 const legacy=new Store();legacy.db.exec("CREATE TABLE item (id TEXT PRIMARY KEY,name TEXT NOT NULL,category_id TEXT NOT NULL,expiry_date TEXT,lifecycle_status TEXT NOT NULL,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,deleted_at INTEGER,pending INTEGER NOT NULL DEFAULT 1,remote_id TEXT); INSERT INTO item VALUES ('legacy','旧物品','food','2026-10-30','ACTIVE',1,1,NULL,0,'existing-remote'); PRAGMA user_version=1;");
 const oldLoad=loader(legacy),oldDb=oldLoad('data/local/AppDatabase').AppDatabase;oldDb.initialize({});await oldDb.getStore();const OldRepo=oldLoad('data/local/ItemLocalRepository').ItemLocalRepository;const oldItem=(await new OldRepo().listActive())[0];
 check('v1 升级保留旧记录、远端 ID 和同步状态',()=>{assert.equal(oldItem.name,'旧物品');assert.equal(oldItem.remoteId,'existing-remote');assert.equal(oldItem.pending,0);assert.equal(oldItem.expiryDate,'2026-10-30');assert.equal(oldItem.quantity,1);assert.equal(legacy.version,4);});
 const snapshot=await repo.exportBackup();
 const restoredStore=new Store(),restoreLoad=loader(restoredStore);restoreLoad('data/local/AppDatabase').AppDatabase.initialize({});
 const restored=new (restoreLoad('data/local/ItemLocalRepository').ItemLocalRepository)();
 await restored.restoreBackup(snapshot,3);
 const roundtrip=await restored.exportBackup();
 check('完整备份恢复保留软删除、原始开封、备注、流水和远端 ID',()=>{assert.equal(roundtrip.items[0].remoteId,snapshot.items[0].remoteId);assert.equal(roundtrip.items[0].openedDate,'2026-10-01');assert.equal(roundtrip.items[0].notes,'包装完整');assert.ok(roundtrip.items[0].deletedAt);assert.equal(roundtrip.records.length,1);});
 await assert.rejects(()=>restored.restoreBackup(snapshot,3));checks++;
 const failedStore=new Store(),failedLoad=loader(failedStore);failedLoad('data/local/AppDatabase').AppDatabase.initialize({});const failed=new (failedLoad('data/local/ItemLocalRepository').ItemLocalRepository)();
 await assert.rejects(()=>failed.restoreBackup({...snapshot,records:[...snapshot.records,{id:'bad',itemId:'missing',action:'CONSUMED',quantity:1,createdAt:1,revoked:0}]},3));
 check('无效备份流水导致整个恢复回滚',()=>assert.equal(failedStore.db.prepare('SELECT count(*) n FROM item').get().n,0));
 const engine=load('algorithm/RecognitionEngine').RecognitionEngine;
 const cases=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../algorithm/contracts/recognition-test-cases.json'),'utf8'));
 for(const c of cases)check('识别 '+c.id,()=>{const result=engine.parse(c.text);for(const key of ['name','production','expiry','shelfLife','unit'])assert.equal(result[key],c[key]);assert.equal(result.candidates.length,c.candidateCount);assert.equal(result.requiresConfirmation,true);});
 const databases=new Map(),scopedLoad=loader(null,databases),scopedDb=scopedLoad('data/local/AppDatabase').AppDatabase;
 scopedDb.initialize({});const scopedRepo=new (scopedLoad('data/local/ItemLocalRepository').ItemLocalRepository)();
 await scopedRepo.create(make('guest'));const first=randomUUID(),second=randomUUID();await scopedDb.switchAccount(first);
 check('账号数据库不读取访客物品',()=>assert.equal(databases.get('account_'+first+'.db').db.prepare('SELECT count(*) n FROM item').get().n,0));
 await scopedRepo.create(make('account-a'));await scopedDb.switchAccount(second);assert.equal((await scopedRepo.listActive()).length,0);checks++;
 await scopedDb.switchAccount(first);assert.equal((await scopedRepo.listActive())[0].id,'account-a');checks++;
 await scopedDb.switchAccount();assert.equal((await scopedRepo.listActive())[0].id,'guest');checks++;
 for(const db of databases.values())db.db.close();
 const P=load('domain/UserProfile').ProfileDomain;
 check('个人标签去空白、兼容中文分隔符并去重',()=>assert.equal(P.tags('花生，牛奶、花生; 芝麻').join('|'),'花生|牛奶|芝麻'));
 check('昵称、头像和偏好数量边界',()=>{assert.ok(P.validate(P.empty(' ')));assert.ok(P.validate({...P.empty('小满'),avatarKey:'missing'}));assert.ok(P.validate({...P.empty('小满'),preferences:Array(21).fill('清淡')}));assert.equal(P.validate({...P.empty('小满'),avatarKey:'cat'}),'');});
 check('忌口命中保留过期告警且不推荐食用',()=>{const text=P.advice({...make(),name:'花生牛奶',expiryDate:'2026-01-01'},'2026-10-03',{...P.empty('小满'),allergies:['花生']});assert.ok(text.includes('忌口'));assert.ok(text.includes('已超过'));});
 check('饮食偏好不作用于非食品',()=>assert.equal(P.advice({...make(),categoryId:'cosmetics'},'2026-10-03',{...P.empty('小满'),allergies:['牛奶']}),D.advice({...make(),categoryId:'cosmetics'},'2026-10-03')));
 check('忌口拦截后不再追加食用建议',()=>{const advice=P.advice({...make(),name:'花生牛奶'},'2026-10-03',{...P.empty('小满'),allergies:['花生']});assert.ok(advice.includes('忌口'));assert.ok(!advice.includes('可优先安排近期使用'));});
 const {AttentionEngine:A}=load('algorithm/AttentionEngine');
 const attentionCases=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../algorithm/contracts/attention-test-cases.json'),'utf8'));
 const attentionItems=[];
 for(const c of attentionCases.cases)check('Attention '+c.id,()=>{
   const item={id:c.id,name:c.id,categoryId:'food',quantity:1,reminderDays:7,lifecycleStatus:'ACTIVE',createdAt:1,updatedAt:1,...c.input,deletedAt:c.input.deleted?1:undefined};
   attentionItems.push(item);const result=new A().evaluate(item,attentionCases.today);
   if(c.excluded){assert.equal(result,undefined);return;}
   assert.equal(result.score,c.score);assert.equal(result.priority,c.priority);assert.deepEqual(Array.from(result.reasonCodes),c.reasonCodes);
   if(c.effectiveExpiryDate)assert.equal(result.effectiveExpiryDate,c.effectiveExpiryDate);
 });
 check('Attention 稳定排序、开封期限与限额',()=>assert.deepEqual(Array.from(new A().rank(attentionItems,attentionCases.today,3),d=>d.itemId),['month-clamp','pao','expired']));
 check('同分同日期使用 ID 稳定排序',()=>assert.deepEqual(Array.from(new A().rank([{...make('b'),expiryDate:'2026-10-03'},{...make('a'),expiryDate:'2026-10-03'}],'2026-10-03',2),d=>d.itemId),['a','b']));
 const todayStore=new Store(),todayLoad=loader(todayStore);todayLoad('data/local/AppDatabase').AppDatabase.initialize({});
 const TodayRepo=todayLoad('data/local/ItemLocalRepository').ItemLocalRepository,todayRepo=new TodayRepo();
 const UC=todayLoad('usecase/TodayUseCase').TodayUseCase,uc=new UC(todayRepo);
 await todayRepo.create(make('today-action'));const stale=(await todayRepo.listActive())[0];
 let undo=await uc.perform('today-action','CONSUMED','2026-10-03');
 check('Today 本地处理写流水并排队同步',()=>{assert.equal(todayStore.db.prepare('SELECT lifecycle_status FROM item').get().lifecycle_status,'CONSUMED');assert.equal(todayStore.db.prepare('SELECT count(*) n FROM consumption_record WHERE revoked=0').get().n,1);});
 await uc.undo(undo);
 check('Today 撤销恢复在库且撤销流水',()=>{assert.equal(todayStore.db.prepare('SELECT lifecycle_status FROM item').get().lifecycle_status,'ACTIVE');assert.equal(todayStore.db.prepare('SELECT count(*) n FROM consumption_record WHERE revoked=0').get().n,0);});
 await assert.rejects(()=>todayRepo.transition(stale,'DISCARDED'));checks++;
 undo=await uc.perform('today-action','SNOOZE','2026-10-03');assert.equal((await todayRepo.listActive())[0].snoozeUntil,'2026-10-04');await uc.undo(undo);
 check('稍后提醒撤销不改变到期日与库存数量',()=>{const item=todayStore.db.prepare('SELECT * FROM item').get();assert.equal(JSON.parse(item.metadata).snoozeUntil,undefined);assert.equal(item.expiry_date,'2026-10-30');});
 undo=await uc.perform('today-action','CONSUMED','2026-10-03');let modified=(await todayRepo.listActive())[0];await todayRepo.update({...modified,notes:'之后的编辑'});
 await assert.rejects(()=>uc.undo(undo));checks++;
 check('撤销拒绝覆盖后续编辑',()=>assert.equal((todayStore.db.prepare('SELECT lifecycle_status FROM item').get()).lifecycle_status,'CONSUMED'));
 const VM=todayLoad('viewmodel/TodayViewModel').TodayViewModel;
 check('规则异常退回本地日期排序',()=>{const cards=new VM(uc,{rank(){throw Error('injected');}}).cards([{...make(),expiryDate:'2026-10-03'}],'2026-10-03',P.empty('小满'));assert.equal(cards[0].decision.ruleVersion,'expiry-sort-v1');});
 await todayRepo.transition((await todayRepo.listActive())[0],'ACTIVE');todayStore.failBatch=true;
 await assert.rejects(()=>uc.perform('today-action','SNOOZE','2026-10-03'));todayStore.failBatch=false;checks++;
 check('稍后保存失败后状态与日期完整保留',()=>assert.equal(JSON.parse(todayStore.db.prepare('SELECT metadata FROM item').get().metadata).snoozeUntil,undefined));
 const batchRepo=new (todayLoad('data/local/BatchLocalRepository').BatchLocalRepository)();
 let base=(await todayRepo.listActive())[0];
 await batchRepo.add(base,{quantity:3,unit:base.unit,expiryDate:'2026-10-10'});
 base=(await todayRepo.listActive())[0];
 check('多批次合计数量且优先展示更早到期',()=>{assert.equal(base.quantity,5);assert.equal(base.expiryDate,'2026-10-10');});
 let batchRows=await batchRepo.list(base.id);const earlier=batchRows.find(b=>b.expiryDate==='2026-10-10');
 let token=await batchRepo.consume(base,earlier.id,1.25);
 check('部分消耗精确更新余量与批次流水',()=>{assert.equal(todayStore.db.prepare('SELECT action FROM consumption_record WHERE id=?').get(token.recordId).action,'PARTIAL_CONSUMED');assert.equal(todayStore.db.prepare('SELECT quantity FROM consumption_record WHERE id=?').get(token.recordId).quantity,1.25);});
 await assert.rejects(()=>batchRepo.consume(base,earlier.id,1));checks++;
 await batchRepo.undo(token);base=(await todayRepo.listActive())[0];assert.equal(base.quantity,5);checks++;
 await assert.rejects(()=>batchRepo.consume(base,earlier.id,4));checks++;
 token=await batchRepo.consume(base,earlier.id,3);base=(await todayRepo.listActive())[0];
 check('单批次耗尽后其他批次仍在库',()=>{assert.equal(base.lifecycleStatus,'ACTIVE');assert.equal(base.quantity,2);assert.equal(base.expiryDate,'2026-10-30');});
 const remaining=(await batchRepo.list(base.id)).find(b=>b.lifecycleStatus==='ACTIVE');
 await batchRepo.consume(base,remaining.id,2);base=(await todayRepo.listActive())[0];await todayRepo.transition(base,'ACTIVE');
 check('全部耗尽后恢复最近处理批次并保留其他已处理批次',()=>{const rows=todayStore.db.prepare('SELECT lifecycle_status FROM inventory_batch WHERE item_id=?').all(base.id);assert.equal(rows.filter(b=>b.lifecycle_status==='ACTIVE').length,1);});
 const DraftRepo=todayLoad('data/local/DraftLocalRepository').DraftLocalRepository,draftRepo=new DraftRepo();
 const before=(await todayRepo.listActive()).length;
 const draft=await draftRepo.create('MOCK_OCR','品名：样例牛奶；到期日期：2027-01-01');
 check('Mock 草稿持久化且不直接入库',()=>{assert.equal(todayStore.db.prepare("SELECT count(*) n FROM item_draft WHERE state='DRAFT'").get().n,1);assert.equal(todayStore.db.prepare('SELECT count(*) n FROM item').get().n,before);});
 await todayRepo.create(make('confirmed-draft'),draft.id);
 check('确认保存与草稿状态、事件同事务写入',()=>{assert.equal(todayStore.db.prepare('SELECT state FROM item_draft WHERE id=?').get(draft.id).state,'SAVED');assert.equal(todayStore.db.prepare("SELECT count(*) n FROM local_event_outbox WHERE event_type='DRAFT_SAVED'").get().n,1);});
 const plan=load('algorithm/ReminderPlan').ReminderPlan;
 check('默认食品提醒使用 7、3、1 天多个节点',()=>{const nodes=plan.create([{...make(),reminderDays:undefined,expiryDate:'2026-11-01'}],new Date('2026-10-01T00:00:00').getTime());assert.equal(nodes.length,3);assert.deepEqual(Array.from(nodes,p=>new Date(p.at).getDate()),[25,29,31]);});
 const batchBackup=await todayRepo.exportBackup(),copyStore=new Store(),copyLoad=loader(copyStore);copyLoad('data/local/AppDatabase').AppDatabase.initialize({});
 await new (copyLoad('data/local/ItemLocalRepository').ItemLocalRepository)().restoreBackup(batchBackup,1);
 check('v2 备份完整保留多批次与部分处理流水',()=>{assert.equal(copyStore.db.prepare('SELECT count(*) n FROM inventory_batch').get().n,batchBackup.batches.length);assert.equal(copyStore.db.prepare("SELECT count(*) n FROM consumption_record WHERE action='PARTIAL_CONSUMED'").get().n,1);});
 const snapshotRepo=new (copyLoad('data/local/SnapshotLocalRepository').SnapshotLocalRepository)();
 let copied=(await new (copyLoad('data/local/ItemLocalRepository').ItemLocalRepository)().listActive())[0];
 const doc={item:{...copied,name:'云端更新'},batches:batchBackup.batches.filter(b=>b.itemId===copied.id)};
 const remote={id:copied.remoteId,version:4,payload:JSON.stringify(doc),updatedAt:new Date().toISOString()};
 await snapshotRepo.conflict(copied,remote);assert.equal((await snapshotRepo.conflicts()).length,1);checks++;
 await snapshotRepo.apply(remote,copied);
 check('采用云端保留所有批次与本机流水、清除冲突并保存版本',()=>{assert.equal(copyStore.db.prepare('SELECT name,remote_version,pending FROM item WHERE id=?').get(copied.id).name,'云端更新');assert.equal(copyStore.db.prepare('SELECT remote_version FROM item WHERE id=?').get(copied.id).remote_version,4);assert.equal(copyStore.db.prepare('SELECT count(*) n FROM sync_conflict').get().n,0);assert.equal(copyStore.db.prepare('SELECT count(*) n FROM consumption_record').get().n,batchBackup.records.length);});
 await assert.rejects(()=>snapshotRepo.apply(remote,copied));checks++;
 const safety=load('algorithm/SafetyGuard').SafetyGuard;
 check('结构化安全拦截优先于偏好和排序',()=>{const result=safety.evaluate({...make(),name:'花生牛奶',expiryDate:'2026-01-01'},'2026-10-03',['花生'],[]);assert.equal(result.blocked,true);assert.deepEqual(Array.from(result.reasonCodes),['EXPIRED','ALLERGY_MATCH']);});
 check('缺日期和已处理物品不生成使用建议',()=>{assert.equal(safety.evaluate({...make(),expiryDate:undefined},'2026-10-03').blocked,true);assert.equal(safety.evaluate({...make(),lifecycleStatus:'CONSUMED'},'2026-10-03').blocked,true);});
 const matcher=load('algorithm/EntityMatcher').EntityMatcher;
 check('名称标准化匹配但不混合品牌与单位',()=>{assert.equal(matcher.candidates({...make('new'),name:'牛 奶'},[make()]).length,1);assert.equal(matcher.candidates({...make('new'),brand:'另一个品牌'},[make()]).length,0);assert.equal(matcher.candidates({...make('new'),unit:'瓶'},[make()]).length,0);});
 const timing=load('algorithm/ReminderTiming').ReminderTiming;
 const history=Array.from({length:6},(_,i)=>({id:String(i),itemId:'one',name:'牛奶',action:'CONSUMED',quantity:1,revoked:0,createdAt:new Date(`2026-10-0${1+i%3}T18:00:00`).getTime()}));
 check('历史时段需要最小样本且撤销记录不参与',()=>{const now=new Date('2026-10-10T00:00:00').getTime();assert.equal(timing.recommend(history,now).hour,18);assert.equal(timing.recommend(history.map(r=>({...r,revoked:1})),now).source,'FALLBACK');assert.equal(timing.recommend(history.slice(0,2),now).hour,9);});
 check('用户确认的提醒小时进入实际计划',()=>assert.equal(new Date(plan.create([make()],new Date('2026-10-01T00:00:00').getTime(),18)[0].at).getHours(),18));
 const decisionRepo=new (todayLoad('data/local/DecisionLocalRepository').DecisionLocalRepository)();
 const cards=new VM().cards([{...make('today-action'),expiryDate:'2026-10-03'}],'2026-10-03',P.empty('小满'));
 await decisionRepo.record(cards,'2026-10-03');await decisionRepo.record(cards,'2026-10-03');
 check('相同展示决策去重，曝光事件与日志同时保存',()=>{assert.equal(todayStore.db.prepare('SELECT count(*) n FROM algorithm_decision').get().n,1);assert.equal(todayStore.db.prepare("SELECT count(*) n FROM local_event_outbox WHERE event_type='DECISION_SHOWN'").get().n,1);});
 await decisionRepo.feedback('today-action','CONSUMED');await decisionRepo.feedback('today-action','UNDO');
 check('撤销反馈保留 decisionId 且不带名称备注',()=>{const events=todayStore.db.prepare("SELECT properties FROM local_event_outbox WHERE event_type='DECISION_FEEDBACK'").all().map(r=>JSON.parse(r.properties));assert.equal(events.length,2);assert.equal(events[0].decisionId,events[1].decisionId);assert.equal(events[1].action,'UNDO');assert.equal(events[0].name,undefined);assert.equal(events[0].notes,undefined);});
 const forecast=load('algorithm/MockForecast').MockForecast.predict(make(),'2026-10-03');
 check('预测样例明确标记 Mock Shadow',()=>assert.equal(forecast.mode,'MOCK_SHADOW'));
 check('Mock 草稿不合并到真实库存',()=>assert.equal(matcher.candidates({...make('new'),sourceMode:'MOCK_OCR'},[make()]).length,0));
 const stats=load('algorithm/StatisticsEngine').StatisticsEngine;
 check('部分消耗计入使用操作，撤销和未来记录不计入',()=>{const rows=stats.records([{...history[0],action:'PARTIAL_CONSUMED'},{...history[1],action:'DISCARDED'},{...history[2],revoked:1},{...history[3],createdAt:new Date('2030-01-01T00:00:00').getTime()}],'2026-10-10',30);const summary=stats.summary(rows);assert.equal(rows.length,2);assert.equal(summary.partial,1);assert.equal(summary.useRate,50);});
 let editable=(await todayRepo.listActive()).find(i=>i.id==='today-action');
 const activeBatch=(await batchRepo.list(editable.id)).find(b=>b.lifecycleStatus==='ACTIVE');
 const corrected={...activeBatch,expiryDate:'2026-11-20',location:'储物柜'};
 await batchRepo.update(editable,activeBatch.id,corrected);
 check('编辑指定批次不改写其他批次',()=>{const rows=todayStore.db.prepare('SELECT id,payload FROM inventory_batch WHERE item_id=?').all(editable.id);assert.equal(JSON.parse(rows.find(b=>b.id===activeBatch.id).payload).expiryDate,'2026-11-20');assert.equal(JSON.parse(rows.find(b=>b.id!==activeBatch.id).payload).expiryDate,'2026-10-10');});
 await assert.rejects(()=>batchRepo.update(editable,activeBatch.id,corrected));checks++;
 editable=(await todayRepo.listActive()).find(i=>i.id==='today-action');todayStore.failBatch=true;
 await assert.rejects(()=>batchRepo.update(editable,activeBatch.id,{...corrected,expiryDate:'2027-01-01'}));todayStore.failBatch=false;
 check('批次编辑失败整体回滚',()=>assert.equal(JSON.parse(todayStore.db.prepare('SELECT payload FROM inventory_batch WHERE id=?').get(activeBatch.id).payload).expiryDate,'2026-11-20'));
 const copyRepo=new (copyLoad('data/local/ItemLocalRepository').ItemLocalRepository)();
 await copyRepo.setServer('http://localhost:18081');copied=(await copyRepo.listActive())[0];
 await snapshotRepo.conflict(copied,remote);await copyRepo.setServer('https://api.example.test');
 check('切换云地址清除旧服务器版本和冲突，保留库存待同步',()=>{assert.equal(copyStore.db.prepare('SELECT count(*) n FROM item WHERE remote_version IS NOT NULL').get().n,0);assert.equal(copyStore.db.prepare('SELECT count(*) n FROM sync_conflict').get().n,0);assert.equal(copyStore.db.prepare('SELECT count(*) n FROM item WHERE pending=1').get().n,batchBackup.items.length);});
 copyStore.db.close();todayStore.db.close();store.db.close();legacy.db.close();restoredStore.db.close();failedStore.db.close();console.log(`PASS: ${checks} frontend domain/storage checks. Native ArkData/notification APIs still require device verification.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
