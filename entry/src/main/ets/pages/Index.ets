import { util } from '@kit.ArkTS';
import { Item, ConsumptionRecord, ShoppingEntry } from '../domain/Item';
import { InventoryDomain } from '../domain/InventoryDomain';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';
import { ApiClient } from '../data/remote/ApiClient';
import { ReminderService } from '../reminder/ReminderService';
import { HomePanel } from '../features/HomePanel';
import { InventoryPanel } from '../features/InventoryPanel';
import { ItemEditor } from '../features/ItemEditor';
import { ItemDetail } from '../features/ItemDetail';
import { SuggestionsPanel } from '../features/SuggestionsPanel';
import { StatisticsPanel } from '../features/StatisticsPanel';
import { ProfilePanel } from '../features/ProfilePanel';

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
  @State private pending: number = 0;
  @State private lastSync: string = '';
  @State private reminderEnabled: boolean = false;
  @State private reminderStatus: string = '';
  private readonly repository: ItemLocalRepository = new ItemLocalRepository();
  private timer: number = -1;
  aboutToAppear(): void {
    this.initialize();
    this.timer = setInterval(() => { const date = InventoryDomain.today(); if (date !== this.today) this.today = date; }, 60000);
  }
  aboutToDisappear(): void { if (this.timer >= 0) clearInterval(this.timer); }
  onPageShow(): void { this.today = InventoryDomain.today(); }
  onBackPress(): boolean {
    if (this.screen !== 'main') { this.back(); return true; }
    if (this.tab !== 0) { this.tab = 0; return true; }
    return false;
  }
  private async initialize(): Promise<void> {
    await this.run(async () => {
      this.server = await this.repository.getServer();
      this.lastSync = await this.repository.getSetting('last_sync');
      this.reminderEnabled = (await this.repository.getSetting('reminders', 'false')) === 'true';
      await this.reload(); this.ready = true;
    }, '');
  }
  private async reload(): Promise<void> {
    this.items = await this.repository.listActive(); this.records = await this.repository.records();
    this.shopping = await this.repository.shopping(); this.pending = (await this.repository.listPending()).length;
    this.today = InventoryDomain.today();
  }
  private async refreshReminders(): Promise<void> {
    if (!this.reminderEnabled) return;
    try { this.reminderStatus = await ReminderService.rebuild(this.items); }
    catch (error) { this.reminderStatus = `系统提醒未完整注册，首页待办仍有效：${String(error)}`; }
  }
  private async run(action: () => Promise<void>, message: string, rebuild: boolean = true): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try { await action(); await this.reload(); if (rebuild) await this.refreshReminders(); this.message = message; }
    catch (error) { this.message = `操作未完成，本地已保存的数据会保留：${String(error)}`; }
    finally { this.busy = false; }
  }
  private selected(): Item { return this.items.find((i: Item) => i.id === this.selectedId) ?? this.editorItem; }
  private browse(status: string, category: string): void { this.status = status; this.category = category; this.inventoryQuery = ''; this.inventoryOrder = 0; this.tab = 1; }
  private open(item: Item): void { this.selectedId = item.id; this.editorItem = item; this.screen = 'detail'; }
  private add(textMode: boolean = false): void {
    this.editorItem = { id: '', name: '', categoryId: 'food', lifecycleStatus: 'ACTIVE', createdAt: 0, updatedAt: 0 };
    this.textMode = textMode; this.screen = 'editor';
  }
  private edit(): void { this.editorItem = this.selected(); this.textMode = false; this.screen = 'editor'; }
  private back(): void {
    if (this.busy) return;
    if (this.screen === 'editor') AlertDialog.show({ title: '离开编辑？', message: '尚未保存的修改不会保留。',
      primaryButton: { value: '继续编辑', action: () => {} }, secondaryButton: { value: '离开', action: () => { this.screen = this.editorItem.id ? 'detail' : 'main'; } } });
    else this.screen = 'main';
  }
  private async save(item: Item): Promise<void> {
    await this.run(async () => {
      const error = InventoryDomain.validate(item); if (error) throw new Error(error);
      if (!item.id) { item.id = util.generateRandomUUID(); item.createdAt = Date.now(); item.updatedAt = item.createdAt; await this.repository.create(item); }
      else await this.repository.update(item);
      this.selectedId = item.id; this.editorItem = item; this.screen = 'detail';
    }, '已保存到本机');
  }
  private async changeLifecycle(status: string): Promise<void> {
    await this.run(async () => { await this.repository.transition(this.selected(), status); }, status === 'ACTIVE' ? '已恢复在库，对应处理统计已撤销' : '状态和处理记录已保存');
  }
  private async remove(): Promise<void> {
    await this.run(async () => { await this.repository.softDelete(this.selectedId); this.screen = 'main'; }, '物品已移除');
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
    await this.run(async () => { const clean = this.address(url); await this.repository.setServer(clean); this.server = clean; }, '地址已保存，可点击同步上传', false);
  }
  private async sync(url: string): Promise<void> {
    if (this.busy) return;
    this.busy = true; let completed = 0;
    try {
      ApiClient.baseUrl = this.address(url); await ApiClient.health(); await this.repository.setServer(ApiClient.baseUrl); this.server = ApiClient.baseUrl;
      const queue = await this.repository.listPending();
      for (const item of queue) {
        const id = await this.repository.ensureRemoteId(item); await ApiClient.upload(item, id); await this.repository.acknowledge(item); completed++;
        this.message = `正在上传 ${completed}/${queue.length}`;
      }
      this.lastSync = `${InventoryDomain.today()} ${new Date().toLocaleTimeString()}`; await this.repository.setSetting('last_sync', this.lastSync);
      await this.reload(); this.message = `已上传 ${completed} 条核心记录，扩展信息保留在本机`;
    } catch (error) {
      this.message = `已上传 ${completed} 条，其余保留待重试：${String(error)}`;
      try { await this.reload(); } catch (ignored) { /* Preserve the sync error. */ }
    } finally { this.busy = false; }
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
    }.layoutWeight(1).height(55).justifyContent(FlexAlign.Center).onClick(() => { if (!this.busy) this.tab = index; })
  }
  build() {
    Column() {
      if (this.screen !== 'main') {
        Row() {
          Text('‹ 返回').fontSize(16).fontColor('#28785C').onClick(() => this.back())
          Blank()
          Text(this.screen === 'editor' ? '物品录入' : this.screen === 'stats' ? '使用统计' : '物品详情').fontSize(13).fontColor('#748078')
        }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 8 })
      }
      if (this.message) {
        Row({ space: 10 }) {
          Text(this.message).fontSize(12).fontColor('#365A48').layoutWeight(1).maxLines(4)
          Text('×').fontSize(19).fontColor('#748078').onClick(() => { this.message = ''; })
        }.padding(12).width('100%').backgroundColor('#E1EDDE')
      }
      if (!this.ready) {
        Column({ space: 20 }) {
          Text(this.busy ? '正在打开你的好物清单…' : '暂时无法读取本地数据').fontColor('#63766D')
          if (!this.busy) { Button('重试').onClick(() => this.initialize()) }
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.screen === 'editor') {
        ItemEditor({ item: this.editorItem, busy: this.busy, textMode: this.textMode, onSave: (item: Item) => { this.save(item); } })
      } else if (this.screen === 'detail') {
        ItemDetail({ item: this.selected(), records: this.records, today: this.today, busy: this.busy,
          onEdit: () => this.edit(), onTransition: (status: string) => { this.changeLifecycle(status); }, onDelete: () => { this.remove(); },
          onSnooze: () => { this.snooze(); }, onShopping: () => { this.shoppingAction('add', this.selected().name); } })
      } else if (this.screen === 'stats') {
        StatisticsPanel({ items: this.items, records: this.records, today: this.today })
      } else {
        if (this.tab === 0) {
          HomePanel({ items: this.items, records: this.records, today: this.today, onOpen: (item: Item) => this.open(item),
            onBrowse: (status: string, category: string) => this.browse(status, category), onAdd: () => this.add(), onText: () => this.add(true), onStats: () => { this.screen = 'stats'; } })
        } else if (this.tab === 1) {
          InventoryPanel({ items: this.items, today: this.today, initialCategory: this.category, initialStatus: this.status,
            initialQuery: this.inventoryQuery, initialOrder: this.inventoryOrder,
            onFilter: (query: string, category: string, status: string, order: number) => { this.inventoryQuery = query; this.category = category; this.status = status; this.inventoryOrder = order; },
            onOpen: (item: Item) => this.open(item), onAdd: () => this.add() })
        } else if (this.tab === 2) {
          SuggestionsPanel({ items: this.items, shopping: this.shopping, today: this.today, busy: this.busy, onOpen: (item: Item) => this.open(item),
            onAdd: (name: string) => { this.shoppingAction('add', name); }, onToggle: (entry: ShoppingEntry) => { this.shoppingAction('toggle', '', entry); }, onRemove: (id: string) => { this.shoppingAction('remove', id); } })
        } else {
          ProfilePanel({ server: this.server, pending: this.pending, busy: this.busy, reminderEnabled: this.reminderEnabled, reminderStatus: this.reminderStatus,
            lastSync: this.lastSync, onSaveServer: (url: string) => { this.saveServer(url); }, onSync: (url: string) => { this.sync(url); },
            onStats: () => { this.screen = 'stats'; }, onReminder: (enabled: boolean) => { this.reminders(enabled); } })
        }
        Row() {
          this.nav('首页', '⌂', 0)
          this.nav('物品', '▤', 1)
          Button('＋').width(48).height(48).fontSize(25).backgroundColor('#28785C').enabled(!this.busy).onClick(() => this.add())
          this.nav('建议', '✧', 2)
          this.nav('我的', '◉', 3)
        }.width('100%').padding({ left: 8, right: 8, top: 6, bottom: 12 }).backgroundColor('#FFFFFF')
      }
    }.width('100%').height('100%').padding({ top: 28 }).backgroundColor('#F4F6F0')
  }
}
