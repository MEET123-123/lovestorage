const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {DatabaseSync}=require('node:sqlite');
const root=path.resolve(__dirname,'../harmonyos/entry/src/main/ets');
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
function loader(store){
 const cache=new Map();
 const native={ '@kit.ArkTS':{util:{generateRandomUUID:randomUUID}},'@kit.ArkData':{relationalStore:{SecurityLevel:{S1:1},getRdbStore:async()=>store,RdbPredicates:Predicates}} };
 function load(file){file=path.resolve(file); if(cache.has(file))return cache.get(file);const exports={};cache.set(file,exports);
 const result=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}});
 vm.runInNewContext(result.outputText,{exports,require:name=>{if(native[name])return native[name];if(name.startsWith('.'))return load(path.resolve(path.dirname(file),name+'.ets'));throw Error('Unexpected import '+name);},console,Date,JSON,Error,setTimeout});
 return exports;
 }
 return file=>load(path.join(root,file+'.ets'));
}
async function main(){
 const store=new Store(),load=loader(store);
 const {InventoryDomain:D}=load('domain/InventoryDomain'),{ReminderPlan}=load('domain/ReminderPlan');
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
 check('空库迁移至 v2',()=>assert.equal(store.version,2));
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
 check('v1 升级保留旧记录、远端 ID 和同步状态',()=>{assert.equal(oldItem.name,'旧物品');assert.equal(oldItem.remoteId,'existing-remote');assert.equal(oldItem.pending,0);assert.equal(oldItem.expiryDate,'2026-10-30');assert.equal(oldItem.quantity,1);assert.equal(legacy.version,2);});
 store.db.close();legacy.db.close();console.log(`PASS: ${checks} frontend domain/storage checks. Native ArkData/notification APIs still require device verification.`);
}
main().catch(error=>{console.error(error);process.exitCode=1;});
