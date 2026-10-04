import { EntityMatcher } from '../algorithm/EntityMatcher';
import { ReminderTiming } from '../algorithm/ReminderTiming';
import { DecisionLocalRepository, DecisionLog } from '../data/local/DecisionLocalRepository';
import { BatchLocalRepository } from '../data/local/BatchLocalRepository';
import { util } from '@kit.ArkTS';
import { Item, InventoryBatch, BatchRecord, ConsumptionRecord, ShoppingEntry } from '../domain/Item';
import { SyncConflict } from '../domain/Sync';
import { BatchUseCase } from '../usecase/BatchUseCase';
import { SyncUseCase } from '../usecase/SyncUseCase';
import { BatchPanel } from '../features/BatchPanel';
import { SyncConflictPanel } from '../features/SyncConflictPanel';
import { CapturePanel } from '../features/CapturePanel';
import { AlgorithmDemoPanel } from '../features/AlgorithmDemoPanel';
import { DraftLocalRepository, CaptureDraft } from '../data/local/DraftLocalRepository';
import { InventoryDomain } from '../algorithm/InventoryDomain';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';
import { ApiClient } from '../data/remote/ApiClient';
import { SessionManager } from '../data/SessionManager';
import { UserProfile, ProfileDomain } from '../domain/UserProfile';
import { ProfileEditor } from '../features/ProfileEditor';
import { InventoryBackup } from '../domain/Backup';
import { ReminderService } from '../reminder/ReminderService';
import { HomePanel } from '../features/HomePanel';
import { InventoryPanel } from '../features/InventoryPanel';
import { ItemEditor } from '../features/ItemEditor';
import { ItemDetail } from '../features/ItemDetail';
import { SuggestionsPanel } from '../features/SuggestionsPanel';
import { StatisticsPanel } from '../features/StatisticsPanel';
import { ProfilePanel } from '../features/ProfilePanel';
import { TodayViewModel } from '../viewmodel/TodayViewModel';

@Entry
@Component
struct Index {
  @State private items: Item[] = [];
  @State private records: ConsumptionRecord[] = [];
  @State private shopping: ShoppingEntry[] = [];
  @State private tab: number = 0;
  @State private screen: string = 'main';
  @State private selectedId: string = '';
  @State private editorItem: Item = { id: '', name: '', categoryId: 'food', lifecycleStatus: 'ACTIVE', createdAt: 0, updatedAt: 0 };
  @State private textMode: boolean = false;
  @State private category: string = 'all';
  @State private status: string = 'ACTIVE';
  @State private inventoryQuery: string = '';
  @State private inventoryOrder: number = 0;
  @State private message: string = '';
  @State private busy: boolean = false;
  @State private ready: boolean = false;
  @State private today: string = InventoryDomain.today();
  @State private server: string = '';
  @State private accountName: string = '';
  @State private profile: UserProfile = ProfileDomain.empty();
  private accountServer: string = '';
  @State private pending: number = 0;
  @State private lastSync: string = '';
  @State private reminderEnabled: boolean = false;
  @State private reminderStatus: string = '';
  @State private undoAvailable: boolean = false;
  @State private undoBatchAvailable: boolean = false;
  @State private batches: BatchRecord[] = [];
  @State private conflicts: SyncConflict[] = [];
  @State private drafts: CaptureDraft[] = [];
  private draftId: string = '';
  @State private decisions: DecisionLog[]=[];
  @State private reminderHour: number=9;
  private lastTodayItem: string='';
  private eventWarning: string='';
  private readonly decisionRepository: DecisionLocalRepository=new DecisionLocalRepository();
  private readonly draftRepository: DraftLocalRepository = new DraftLocalRepository();
  private readonly batchUseCase: BatchUseCase = new BatchUseCase();
  private readonly syncUseCase: SyncUseCase = new SyncUseCase();
  private readonly todayViewModel: TodayViewModel = new TodayViewModel();
  private readonly repository: ItemLocalRepository = new ItemLocalRepository();
  private timer: number = -1;
  private redirecting: boolean = false;
  aboutToAppear(): void {
    this.initialize();
    this.timer = setInterval(() => { const date = InventoryDomain.today(); if (date !== this.today) this.today = date; }, 60000);
  }
  aboutToDisappear(): void { if (this.timer >= 0) clearInterval(this.timer); }
  onPageShow(): void { this.today = InventoryDomain.today(); if (!SessionManager.active()) this.redirectLogin(); }
  onBackPress(): boolean {
    if (this.screen !== 'main') { this.back(); return true; }
    if (this.tab !== 0) { this.tab = 0; return true; }
    return false;
  }
  private async redirectLogin(): Promise<void> {
    if (this.redirecting) return;
    this.redirecting = true;
    this.ready = false; this.undoAvailable = false; this.items = []; this.records = []; this.shopping = []; this.profile = ProfileDomain.empty();
    this.undoBatchAvailable=false; this.batches=[]; this.conflicts=[]; this.drafts=[]; this.draftId=''; this.decisions=[]; this.lastTodayItem=''; this.reminderHour=9;
    try { await SessionManager.clear(); }
    finally { try { await this.getUIContext().getRouter().replaceUrl({ url: 'pages/Login' }); } finally { this.redirecting = false; } }
  }
  private async initialize(): Promise<void> {
    if (!SessionManager.active()) { await this.redirectLogin(); return; }
    await this.run(async () => {
      this.accountName = SessionManager.current?.user.username ?? '';
      this.accountServer = SessionManager.server; this.server = SessionManager.server;
      this.lastSync = await this.repository.getSetting('last_sync');
      this.reminderHour=Number(await this.repository.getSetting('reminder_hour','9'));
      this.reminderEnabled = (await this.repository.getSetting('reminders', 'false')) === 'true';
      const cached = await this.repository.getSetting('profile');
      this.profile = cached ? JSON.parse(cached) as UserProfile : ProfileDomain.empty(this.accountName);
      try {
        this.profile = await ApiClient.getProfile();
        await this.repository.setSetting('profile', JSON.stringify(this.profile));
      } catch (error) {
        if (!ApiClient.token) throw new Error(String(error));
      }
      this.ready = true; this.tab = 0; this.screen = 'main';
    }, '');
  }
  private async reload(): Promise<void> {
    this.items = await this.repository.listActive(); this.records = await this.repository.records();
    this.shopping = await this.repository.shopping(); this.pending = (await this.repository.listPending()).length;
    this.today = InventoryDomain.today();
    this.conflicts = await this.syncUseCase.conflicts();
    this.drafts = await this.draftRepository.list();
    await this.recordDecisions();
    this.decisions=await this.decisionRepository.list();
    if (this.selectedId) this.batches = await this.batchUseCase.list(this.selectedId);
  }
  private async refreshReminders(): Promise<void> {
    if (!this.reminderEnabled) return;
    try { this.reminderStatus = await ReminderService.rebuild(this.items,this.reminderHour); }
    catch (error) { this.reminderStatus = `系统提醒未完整注册，首页待办仍有效：${String(error)}`; }
  }
  private async run(action: () => Promise<void>, message: string, rebuild: boolean = true): Promise<void> {
    if (this.busy) return;
    this.busy = true;this.eventWarning='';
    try { await action(); if (!SessionManager.active()) { await this.redirectLogin(); return; } await this.reload(); if (rebuild) await this.refreshReminders(); this.message = [message,this.eventWarning].filter((value:string)=>value.length>0).join('；'); }
    catch (error) { this.message = `操作未完成，本地已保存的数据会保留：${String(error)}`; if (!SessionManager.active()) await this.redirectLogin(); }
    finally { this.busy = false; }
  }
  private selected(): Item { return this.items.find((i: Item) => i.id === this.selectedId) ?? this.editorItem; }
  private browse(status: string, category: string): void { this.status = status; this.category = category; this.inventoryQuery = ''; this.inventoryOrder = 0; this.tab = 1; }
  private open(item: Item): void { this.selectedId = item.id; this.editorItem = item; this.screen = 'detail'; }
  private add(textMode: boolean = false): void {
    this.draftId='';
    this.editorItem = { id: '', name: '', categoryId: 'food', lifecycleStatus: 'ACTIVE', createdAt: 0, updatedAt: 0 };
    this.textMode = textMode; this.screen = 'editor';
  }
  private async createDraft(mode: string, text: string): Promise<void> {
    await this.run(async()=> { await this.draftRepository.create(mode,text); },'草稿已保存在本机，请核对后再加入库存',false);
  }
  private confirmDraft(draft: CaptureDraft): void {
    this.add(); this.draftId=draft.id;
    this.editorItem.sourceMode=draft.mode;
    this.editorItem.name=draft.result.name; this.editorItem.expiryDate=draft.result.expiry||undefined;
    this.editorItem.productionDate=draft.result.production||undefined;
    this.editorItem.shelfLifeValue=draft.result.shelfLife?Number(draft.result.shelfLife):undefined;
    this.editorItem.shelfLifeUnit=draft.result.shelfLife?['DAY','MONTH','YEAR'][draft.result.unit]:undefined;
  }
  private edit(): void { this.editorItem = this.selected(); this.textMode = false; this.screen = 'editor'; }
  private back(): void {
    if (this.busy) return;
    if (this.screen === 'profile') { AlertDialog.show({ title: '离开个人资料编辑？', message: '尚未保存的修改不会保留。', primaryButton: { value: '继续编辑', action: () => {} }, secondaryButton: { value: '离开', action: () => { this.screen = 'main'; } } }); return; }
    if (this.screen === 'editor') AlertDialog.show({ title: '离开编辑？', message: '尚未保存的修改不会保留。',
      primaryButton: { value: '继续编辑', action: () => {} }, secondaryButton: { value: '离开', action: () => { this.screen = this.editorItem.id ? 'detail' : 'main'; } } });
    else this.screen = 'main';
  }
  private async recordDecisions(): Promise<void> {
    if(this.screen!=='main' || this.tab!==0 || !this.ready) return;
    try { await this.decisionRepository.record(this.todayViewModel.cards(this.items,this.today,this.profile),this.today); }
    catch(error) { this.eventWarning='库存可继续使用，排序记录暂未保存：'+String(error);this.message=this.eventWarning; }
  }
  private async recordFeedback(id: string,action: string,strict: boolean=false): Promise<void> {
    try { await this.decisionRepository.feedback(id,action); }
    catch(error) { if(strict)throw new Error(String(error));this.eventWarning='物品操作已保存，算法反馈暂未保存：'+String(error); }
  }
  private async discardDraft(id: string): Promise<void> {
    await this.run(async()=>{await this.draftRepository.discard(id);},'草稿已删除',false);
  }
  private async setReminderHour(hour: number): Promise<void> {
    await this.run(async()=>{
      if(!Number.isInteger(hour) || hour<8 || hour>21) throw new Error('请选择 08:00–21:00');
      await this.repository.setSetting('reminder_hour',`${hour}`);this.reminderHour=hour;
    },'提醒时段已保存');
  }
  private requestSave(item: Item): void {
    if(this.busy)return;
    const error=InventoryDomain.validate(item);if(error){this.message=error;return;}
    const matches=item.id?[]:EntityMatcher.candidates(item,this.items);
    if(!matches.length){this.save(item);return;}
    const candidate=matches[0];
    AlertDialog.show({title:'发现可能相同的物品',message:`${candidate.item.name}：${candidate.reason}。可将本次录入作为独立批次，保留原批次日期和余量。`,
      primaryButton:{value:'新增到该物品的批次',action:()=>{this.save(item,candidate.item);}},
      secondaryButton:{value:'仍然新建物品',action:()=>{this.save(item);}}});
  }
  private async save(item: Item, merge?: Item): Promise<void> {
    await this.run(async () => {
      const error = InventoryDomain.validate(item); if (error) throw new Error(error);
      if(merge) {
        const batch:InventoryBatch={quantity:item.quantity,unit:item.unit,expiryDate:item.expiryDate,productionDate:item.productionDate,
          shelfLifeValue:item.shelfLifeValue,shelfLifeUnit:item.shelfLifeUnit,openedDate:item.openedDate,afterOpenValue:item.afterOpenValue,afterOpenUnit:item.afterOpenUnit,location:item.location};
        await new BatchLocalRepository().add(merge,batch,this.draftId); this.draftId=''; this.selectedId=merge.id; this.editorItem=merge; this.screen='batches'; return;
      }
      if (!item.id) { item.id = util.generateRandomUUID(); item.createdAt = Date.now(); item.updatedAt = item.createdAt; await this.repository.create(item,this.draftId); this.draftId=''; }
      else await this.repository.update(item);
      this.selectedId = item.id; this.editorItem = item; this.screen = 'detail';
    }, '已保存到本机');
  }
  private async changeLifecycle(status: string): Promise<void> {
    await this.run(async () => { await this.repository.transition(this.selected(), status); }, status === 'ACTIVE' ? '已恢复在库，对应处理统计已撤销' : '状态和处理记录已保存');
  }
  private async todayAction(item: Item, action: string): Promise<void> {
    if (this.busy) return;
    await this.run(async () => {
      this.items = this.items.filter((row: Item) => row.id !== item.id);
      try { await this.todayViewModel.act(item.id, action, this.today); this.undoAvailable = true; this.lastTodayItem=item.id; await this.recordFeedback(item.id,action); }
      catch (error) { await this.reload(); throw new Error(String(error)); }
    }, action === 'SNOOZE' ? '已安排明天再提醒，可撤销' : action === 'CONSUMED' ? '已标记为用完，可撤销' : '已记录丢弃，可撤销');
  }
  private async undoToday(): Promise<void> {
    await this.run(async () => { this.undoAvailable = false; await this.todayViewModel.undo(); await this.recordFeedback(this.lastTodayItem,'UNDO'); }, '已撤销，物品恢复到待处理列表');
  }
  private async remove(): Promise<void> {
    await this.run(async () => { await this.repository.softDelete(this.selectedId); this.screen = 'main'; }, '物品已移除');
  }
  private async openBatches(): Promise<void> {
    await this.run(async () => { this.batches=await this.batchUseCase.list(this.selectedId); this.screen='batches'; },'',false);
  }
  private async addBatch(batch: InventoryBatch): Promise<void> {
    await this.run(async () => { await this.batchUseCase.add(this.selected(),batch); this.undoBatchAvailable=false; },'新批次已保存');
  }
  private async updateBatch(id:string,batch:InventoryBatch):Promise<void> {
    await this.run(async()=>{await this.batchUseCase.update(this.selected(),id,batch);this.undoBatchAvailable=false;},'批次修改已保存');
  }
  private async consumeBatch(id: string, quantity: number, discarded: boolean): Promise<void> {
    await this.run(async () => { await this.batchUseCase.consume(this.selected(),id,quantity,discarded); this.undoBatchAvailable=true; this.undoAvailable=false; },'批次余量与处理流水已更新，可撤销');
  }
  private async undoBatch(): Promise<void> {
    await this.run(async () => { this.undoBatchAvailable=false; await this.batchUseCase.undo(); },'批次处理已撤销');
  }
  private async resolveConflict(conflict: SyncConflict, keepLocal: boolean): Promise<void> {
    await this.run(async () => { await this.syncUseCase.resolve(conflict,keepLocal); },'冲突已处理');
  }
  private async snooze(): Promise<void> {
    await this.run(async () => {
      const item = JSON.parse(JSON.stringify(this.selected())) as Item;
      const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1); item.snoozeUntil = InventoryDomain.dateText(tomorrow);
      await this.repository.update(item);
    }, '已安排明天再处理，到期日期保持不变');
  }
  private address(url: string): string {
    const clean = url.trim().replace(/\/+$/, '');
    if (!/^https?:\/\/[^\s/?#]+$/.test(clean)) throw new Error('请输入服务地址，例如 http://192.168.1.10:18080');
    return clean;
  }
  private async saveServer(url: string): Promise<void> {
    await this.run(async () => {
      const clean = this.address(url);
      if (this.accountName && clean !== this.accountServer) throw new Error('更换服务器前请先退出当前账号');
      await this.repository.setServer(clean); this.server = clean;
    }, '地址已保存，可登录后同步上传', false);
  }
  private async sync(url: string): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      if (!this.accountName || !ApiClient.token) throw new Error('请先登录后再同步');
      if (this.address(url) !== this.accountServer) throw new Error('服务器与登录账号不一致，请重新登录');
      ApiClient.baseUrl = this.address(url); await ApiClient.health(); await this.repository.setServer(ApiClient.baseUrl); this.server = ApiClient.baseUrl;
      const result = await this.syncUseCase.sync();
      this.lastSync = `${InventoryDomain.today()} ${new Date().toLocaleTimeString()}`; await this.repository.setSetting('last_sync', this.lastSync);
      await this.reload(); await this.refreshReminders(); this.message = `已上传 ${result.uploaded}、下载 ${result.downloaded} 条完整库存；${this.conflicts.length} 项冲突待确认`;
    } catch (error) {
      this.message = `同步未全部完成，已保存的本机数据和待重试队列保留：${String(error)}`;
      if (!SessionManager.active()) await this.redirectLogin();
      else { try { await this.reload(); } catch (ignored) { /* Preserve the sync error. */ } }
    } finally { this.busy = false; }
  }
  private async logout(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try { await ApiClient.logout(); } catch (ignored) {}
    finally {
      this.accountName = ''; this.accountServer = '';
      await this.redirectLogin(); this.busy = false;
    }
  }
  private async saveProfile(profile: UserProfile): Promise<void> {
    await this.run(async () => {
      const error = ProfileDomain.validate(profile); if (error) throw new Error(error);
      this.profile = await ApiClient.saveProfile(profile);
      await this.repository.setSetting('profile', JSON.stringify(this.profile));
      this.screen = 'main'; this.tab = 2;
    }, '个人资料与偏好已保存到账号', false);
  }
  private async checkServer(): Promise<void> {
    await this.run(async () => { await ApiClient.health(); }, '当前接口与数据库连接正常', false);
  }
  private async backup(): Promise<void> {
    await this.run(async () => {
      if (!this.accountName || !ApiClient.token) throw new Error('请先登录');
      const payload = JSON.stringify(await this.repository.exportBackup());
      if (payload.length > 500000) throw new Error('当前备份超过 50 万字符限制');
      const revision = Number(await this.repository.getSetting('backup_revision', '0'));
      const saved = await ApiClient.backup(payload, revision);
      await this.repository.setSetting('backup_revision', `${saved.revision}`);
    }, '物品、原始日期、备注、流水和补货清单已完整备份', false);
  }
  private async restore(): Promise<void> {
    await this.run(async () => {
      if (!this.accountName || !ApiClient.token) throw new Error('请先登录');
      const backup = await ApiClient.fetchBackup();
      if (!backup.revision) throw new Error('该账号尚无云端备份');
      await this.repository.restoreBackup(JSON.parse(backup.payload) as InventoryBackup, backup.revision);
    }, '已恢复完整备份，请核对库存');
  }
  private async reminders(enabled: boolean): Promise<void> {
    await this.run(async () => {
      if (enabled) { await ReminderService.enable(); await this.repository.setSetting('reminders', 'true'); this.reminderEnabled = true; }
      else { await ReminderService.clear(); await this.repository.setSetting('reminders', 'false'); this.reminderEnabled = false; this.reminderStatus = '系统提醒已关闭，应用内待办继续显示'; }
    }, '提醒偏好已保存');
  }
  private async shoppingAction(action: string, name: string = '', entry?: ShoppingEntry): Promise<void> {
    await this.run(async () => {
      if (action === 'add') await this.repository.addShopping(name);
      else if (action === 'toggle' && entry) await this.repository.toggleShopping(entry);
      else if (action === 'remove') await this.repository.removeShopping(name);
    }, action === 'add' ? '已加入补货清单，相同待购物品自动去重' : '补货清单已更新', false);
  }
  @Builder
  private nav(label: string, mark: string, index: number) {
    Column({ space: 4 }) {
      Text(mark).fontSize(23).fontColor(this.tab === index ? '#28785C' : '#9AA69D')
      Text(label).fontSize(11).fontColor(this.tab === index ? '#28785C' : '#748078')
    }.layoutWeight(1).height(55).justifyContent(FlexAlign.Center).onClick(() => { if (!this.busy) { this.tab = index; if(index===0)this.recordDecisions(); } })
  }
  build() {
    Column() {
      if (this.screen !== 'main') {
        Row() {
          Text('‹ 返回').fontSize(16).fontColor('#28785C').onClick(() => this.back())
          Blank()
          Text(this.screen === 'capture' ? '智能录入' : this.screen === 'algorithms' ? '算法调试' : this.screen === 'batches' ? '批次管理' : this.screen === 'conflicts' ? '同步冲突' : this.screen === 'profile' ? '个人资料' : this.screen === 'editor' ? '物品录入' : this.screen === 'stats' ? '使用统计' : this.screen === 'suggestions' ? '处理建议' : '物品详情').fontSize(13).fontColor('#748078')
        }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 8 })
      }
      if (this.message) {
        Row({ space: 10 }) {
          Text(this.message).fontSize(12).fontColor('#365A48').layoutWeight(1).maxLines(4)
          Text('×').fontSize(19).fontColor('#748078').onClick(() => { this.message = ''; })
        }.padding(12).width('100%').backgroundColor('#E1EDDE')
      }
      if (this.undoAvailable) {
        Row() {
          Text('最近一次今日操作').fontSize(12).fontColor('#365A48').layoutWeight(1)
          Button('撤销').fontSize(12).height(32).backgroundColor('#28785C').enabled(!this.busy).onClick(() => { this.undoToday(); })
        }.width('100%').padding(12).backgroundColor('#E1EDDE')
      }
      if (!this.ready) {
        Column({ space: 20 }) {
          Text(this.busy ? '正在打开你的好物清单…' : '暂时无法读取本地数据').fontColor('#63766D')
          if (!this.busy) { Button('重试').onClick(() => this.initialize()) }
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.screen === 'capture') {
        CapturePanel({drafts:this.drafts,busy:this.busy,onDiscard:(id:string)=>{this.discardDraft(id);},onCreate:(mode:string,text:string)=>{this.createDraft(mode,text);},onConfirm:(draft:CaptureDraft)=>{this.confirmDraft(draft);},onManual:()=>this.add()})
      } else if (this.screen === 'algorithms') {
        AlgorithmDemoPanel({items:this.items,profile:this.profile,today:this.today,records:this.records,decisions:this.decisions,reminderHour:this.reminderHour,onApplyHour:(hour:number)=>{this.setReminderHour(hour);}})
      } else if (this.screen === 'profile') {
        ProfileEditor({ profile: this.profile, busy: this.busy, onSave: (profile: UserProfile) => { this.saveProfile(profile); } })
      } else if (this.screen === 'editor') {
        ItemEditor({ item: this.editorItem, busy: this.busy, textMode: this.textMode, onSave: (item: Item) => { this.requestSave(item); } })
      } else if (this.screen === 'detail') {
        ItemDetail({ item: this.selected(), records: this.records, today: this.today, busy: this.busy,
          onEdit: () => this.edit(), onTransition: (status: string) => { this.changeLifecycle(status); }, onDelete: () => { this.remove(); },
          onSnooze: () => { this.snooze(); }, onShopping: () => { this.shoppingAction('add', this.selected().name); }, onBatches: () => { this.openBatches(); } })
      } else if (this.screen === 'batches') {
        BatchPanel({item:this.selected(),batches:this.batches,busy:this.busy,undoAvailable:this.undoBatchAvailable,
          onAdd:(batch:InventoryBatch)=>{this.addBatch(batch);},onUpdate:(id:string,batch:InventoryBatch)=>{this.updateBatch(id,batch);},onConsume:(id:string,quantity:number,discarded:boolean)=>{this.consumeBatch(id,quantity,discarded);},onUndo:()=>{this.undoBatch();}})
      } else if (this.screen === 'conflicts') {
        SyncConflictPanel({conflicts:this.conflicts,busy:this.busy,onResolve:(conflict:SyncConflict,keepLocal:boolean)=>{this.resolveConflict(conflict,keepLocal);}})
      } else if (this.screen === 'stats') {
        StatisticsPanel({ items: this.items, records: this.records, today: this.today })
      } else if (this.screen === 'suggestions') {
        SuggestionsPanel({ profile: this.profile, items: this.items, shopping: this.shopping, today: this.today, busy: this.busy, onOpen: (item: Item) => this.open(item),
          onAdd: (name: string) => { this.shoppingAction('add', name); }, onToggle: (entry: ShoppingEntry) => { this.shoppingAction('toggle', '', entry); }, onRemove: (id: string) => { this.shoppingAction('remove', id); } })
      } else {
        if (this.tab === 0) {
          HomePanel({ items: this.items, cards: this.todayViewModel.cards(this.items, this.today, this.profile), records: this.records, today: this.today, busy: this.busy,
            onFeedback:(item:Item)=>{this.run(async()=>{await this.recordFeedback(item.id,'NOT_HELPFUL',true);},'已记录反馈，后续评测会参考；当前规则不自动改变',false);},onOpen: (item: Item) => this.open(item), onAction: (item: Item, action: string) => { this.todayAction(item, action); },
            onBrowse: (status: string, category: string) => this.browse(status, category), onAdd: () => this.add(), onText: () => this.add(true),
            onStats: () => { this.screen = 'stats'; }, onSuggestions: () => { this.screen = 'suggestions'; } })
        } else if (this.tab === 1) {
          InventoryPanel({ items: this.items, today: this.today, initialCategory: this.category, initialStatus: this.status,
            initialQuery: this.inventoryQuery, initialOrder: this.inventoryOrder,
            onFilter: (query: string, category: string, status: string, order: number) => { this.inventoryQuery = query; this.category = category; this.status = status; this.inventoryOrder = order; },
            onOpen: (item: Item) => this.open(item), onAdd: () => this.add() })
        } else {
          ProfilePanel({ server: this.server, pending: this.pending, busy: this.busy, reminderEnabled: this.reminderEnabled, reminderStatus: this.reminderStatus,
            conflictCount:this.conflicts.length,onConflicts:()=>{this.screen='conflicts';},onAlgorithms:()=>{this.screen='algorithms';},
            accountName: this.accountName, profile: this.profile, onEditProfile: () => { this.screen = 'profile'; },
            onLogout: () => { this.logout(); }, onCheckServer: () => { this.checkServer(); },
            onBackup: () => { this.backup(); }, onRestore: () => { this.restore(); },
            lastSync: this.lastSync, onSaveServer: (url: string) => { this.saveServer(url); }, onSync: (url: string) => { this.sync(url); },
            onStats: () => { this.screen = 'stats'; }, onReminder: (enabled: boolean) => { this.reminders(enabled); } })
        }
        Row() {
          this.nav('今天', '⌂', 0)
          this.nav('物品', '▤', 1)
          Button('＋').width(48).height(48).fontSize(25).backgroundColor('#28785C').enabled(!this.busy).onClick(() => { this.screen='capture'; })
          this.nav('我的', '◉', 2)
        }.width('100%').padding({ left: 8, right: 8, top: 6, bottom: 12 }).backgroundColor('#FFFFFF')
      }
    }.width('100%').height('100%').padding({ top: 28 }).backgroundColor('#F4F6F0')
  }
}
