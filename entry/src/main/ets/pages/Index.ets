import { util } from '@kit.ArkTS';
import { Item } from '../domain/Item';
import { ExpiryService, ExpiryStatus } from '../domain/ExpiryService';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';
import { ApiClient } from '../data/remote/ApiClient';

@Entry
@Component
struct Index {
  @State private items: Item[] = [];
  @State private message: string = '正在读取本地库存…';
  @State private name: string = '';
  @State private expiry: string = '';
  @State private category: number = 0;
  @State private editingId: string = '';
  @State private search: string = '';
  @State private server: string = '';
  @State private busy: boolean = false;
  @State private showForm: boolean = false;
  @State private showSettings: boolean = false;
  @State private pending: number = 0;
  private readonly repository: ItemLocalRepository = new ItemLocalRepository();
  private readonly expiryService: ExpiryService = new ExpiryService();
  private readonly categoryIds: string[] = ['food', 'cosmetics', 'pet_food', 'other'];
  private readonly categoryNames: string[] = ['食品', '化妆品', '宠物粮', '其他'];

  aboutToAppear(): void { this.initialize(); }

  private async initialize(): Promise<void> {
    try {
      this.server = await this.repository.getServer();
      await this.reload();
      this.message = '本地优先 · 无网络也可管理库存';
    } catch (error) { this.message = `初始化失败：${String(error)}`; }
  }

  private async reload(): Promise<void> {
    this.items = await this.repository.listActive();
    this.pending = (await this.repository.listPending()).length;
  }

  private todayIso(): string {
    const date = new Date();
    return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}-${`${date.getDate()}`.padStart(2, '0')}`;
  }

  private validDate(text: string): boolean {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;
    const parts = text.split('-').map((v: string) => Number(v));
    if (parts[0] < 1900 || parts[0] > 9999) return false;
    const date = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
    return date.getUTCFullYear() === parts[0] && date.getUTCMonth() === parts[1] - 1 && date.getUTCDate() === parts[2];
  }

  private startAdd(): void {
    this.editingId = ''; this.name = ''; this.expiry = ''; this.category = 0; this.showForm = true;
  }

  private edit(item: Item): void {
    this.editingId = item.id; this.name = item.name; this.expiry = item.expiryDate ?? '';
    this.category = Math.max(0, this.categoryIds.indexOf(item.categoryId)); this.showForm = true;
  }

  private async save(): Promise<void> {
    if (this.busy) return;
    if (this.name.trim().length === 0 || this.name.trim().length > 80) {
      this.message = '请输入 1–80 字的物品名称'; return;
    }
    if (!this.validDate(this.expiry.trim())) {
      this.message = '请输入真实到期日期，例如 2026-10-09'; return;
    }
    this.busy = true;
    try {
      const existing = this.items.find((row: Item) => row.id === this.editingId);
      const now = Date.now();
      const item: Item = {
        id: existing === undefined ? util.generateRandomUUID() : existing.id,
        name: this.name.trim(), categoryId: this.categoryIds[this.category], expiryDate: this.expiry.trim(),
        lifecycleStatus: existing === undefined ? 'ACTIVE' : existing.lifecycleStatus,
        createdAt: existing === undefined ? now : existing.createdAt, updatedAt: now
      };
      if (existing === undefined) await this.repository.create(item);
      else await this.repository.update(item);
      await this.reload(); this.showForm = false;
      this.message = '已保存到本机，可点击同步上传到后端';
    } catch (error) { this.message = `保存失败：${String(error)}`; }
    finally { this.busy = false; }
  }

  private async changeStatus(item: Item, status: string): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      const updated: Item = {
        id: item.id, name: item.name, categoryId: item.categoryId, expiryDate: item.expiryDate,
        lifecycleStatus: status, createdAt: item.createdAt, updatedAt: Date.now()
      };
      await this.repository.update(updated); await this.reload(); this.message = '处理状态已保存';
    } catch (error) { this.message = `操作失败：${String(error)}`; }
    finally { this.busy = false; }
  }

  private async remove(item: Item): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    try {
      await this.repository.softDelete(item.id); await this.reload(); this.message = '已删除，等待同步';
    } catch (error) { this.message = `删除失败：${String(error)}`; }
    finally { this.busy = false; }
  }

  private async sync(): Promise<void> {
    if (this.busy) return;
    const url = this.server.trim().replace(/\/+$/, '');
    if (!/^https?:\/\/[^\s/]+(:\d+)?$/.test(url)) {
      this.message = '请填写服务地址，例如 http://192.168.1.10:8080'; this.showSettings = true; return;
    }
    this.busy = true;
    try {
      ApiClient.baseUrl = url;
      await ApiClient.health();
      await this.repository.setServer(url);
      this.server = url;
      const queue = await this.repository.listPending();
      let completed = 0;
      for (const item of queue) {
        const remoteId = await this.repository.ensureRemoteId(item);
        await ApiClient.upload(item, remoteId);
        await this.repository.acknowledge(item);
        completed++;
      }
      await this.reload(); this.message = `后端连接正常，已同步 ${completed} 条本机修改`;
    } catch (error) {
      this.message = `同步未完成，本地数据已保留：${String(error)}`;
      try { await this.reload(); } catch (reloadError) { this.message += `；${String(reloadError)}`; }
    } finally { this.busy = false; }
  }

  private expiryLabel(item: Item): string {
    if (item.lifecycleStatus === 'CONSUMED') return '已用完';
    if (item.lifecycleStatus === 'DISCARDED') return '已丢弃';
    if (item.lifecycleStatus === 'ARCHIVED') return '已归档';
    const result = this.expiryService.evaluate(item.expiryDate, undefined, undefined, undefined, 7, this.todayIso());
    if (result.status === ExpiryStatus.UNKNOWN) return '待补充日期';
    if (result.status === ExpiryStatus.EXPIRED) return `已过期 ${Math.abs(result.remainingDays ?? 0)} 天`;
    if (result.remainingDays === 0) return '今天到期';
    if (result.status === ExpiryStatus.NEAR_EXPIRY) return `临期 · 剩余 ${result.remainingDays} 天`;
    return `剩余 ${result.remainingDays} 天`;
  }

  private count(status: string): number {
    return this.items.filter((item: Item) => item.lifecycleStatus === status).length;
  }

  private urgentCount(): number {
    return this.items.filter((item: Item) => {
      if (item.lifecycleStatus !== 'ACTIVE') return false;
      const result = this.expiryService.evaluate(item.expiryDate, undefined, undefined, undefined, 7, this.todayIso());
      return result.status === ExpiryStatus.NEAR_EXPIRY || result.status === ExpiryStatus.EXPIRED;
    }).length;
  }

  private visibleItems(): Item[] {
    return this.items.filter((item: Item) => item.name.toLowerCase().includes(this.search.toLowerCase()));
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('智能保质期').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#173C32')
          Text(`${this.todayIso()} · 珍惜每一份好物`).fontSize(12).fontColor('#63766D')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button('连接').onClick(() => { this.showSettings = !this.showSettings; }).enabled(!this.busy)
      }.width('100%')
      Row({ space: 12 }) {
        Text(`在库 ${this.count('ACTIVE')}`).fontColor('#173C32')
        Text(`待处理 ${this.urgentCount()}`).fontColor('#B55525')
        Text(`用完 ${this.count('CONSUMED')} / 丢弃 ${this.count('DISCARDED')}`).fontSize(12)
      }.width('100%').padding(12).backgroundColor('#E7F1EB').borderRadius(12)
      Text(this.message).fontSize(13).fontColor('#53665E').width('100%')
      if (this.showSettings) {
        TextInput({ text: this.server, placeholder: 'http://开发机局域网IP:8080' })
          .onChange((value: string) => { this.server = value; }).enabled(!this.busy)
        Text('真机不能使用电脑的 localhost。同步仅上传本机修改，当前为单设备开发模式。')
          .fontSize(12).fontColor('#63766D')
      }
      Row({ space: 10 }) {
        Button('＋ 手动录入').layoutWeight(1).backgroundColor('#28785C').onClick(() => this.startAdd()).enabled(!this.busy)
        Button(this.busy ? '处理中…' : `同步 (${this.pending})`).layoutWeight(1).onClick(() => this.sync()).enabled(!this.busy)
      }
      if (this.showForm) {
        Column({ space: 8 }) {
          Text(this.editingId === '' ? '新增物品' : '编辑物品').fontWeight(FontWeight.Bold)
          TextInput({ text: this.name, placeholder: '名称（必填）' }).maxLength(80)
            .onChange((value: string) => { this.name = value; })
          Select([{ value: '食品' }, { value: '化妆品' }, { value: '宠物粮' }, { value: '其他' }])
            .selected(this.category).value(this.categoryNames[this.category])
            .onSelect((index: number) => { this.category = index; })
          TextInput({ text: this.expiry, placeholder: '到期日期 YYYY-MM-DD' })
            .onChange((value: string) => { this.expiry = value; })
          Row({ space: 12 }) {
            Button('取消').onClick(() => { this.showForm = false; }).enabled(!this.busy)
            Button('保存到本机').onClick(() => this.save()).enabled(!this.busy)
          }
        }.width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(12)
      } else {
        TextInput({ text: this.search, placeholder: '搜索物品名称' })
          .onChange((value: string) => { this.search = value; })
        if (this.visibleItems().length === 0) {
          Text(this.items.length === 0 ? '还没有物品，点击手动录入开始。' : '没有匹配的物品')
            .fontColor('#63766D').padding(20)
        }
        List({ space: 10 }) {
          ForEach(this.visibleItems(), (item: Item) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Text(item.name).fontSize(19).fontWeight(FontWeight.Medium).layoutWeight(1)
                  Text(this.expiryLabel(item)).fontSize(12).fontColor('#28785C')
                }.width('100%')
                Text(`${this.categoryNames[Math.max(0, this.categoryIds.indexOf(item.categoryId))]} · 到期 ${item.expiryDate ?? '未填写'}${item.pending === 1 ? ' · 待同步' : ''}`)
                  .fontSize(12).fontColor('#63766D').width('100%')
                Row({ space: 6 }) {
                  Button('编辑').fontSize(12).onClick(() => this.edit(item)).enabled(!this.busy)
                  if (item.lifecycleStatus === 'ACTIVE') {
                    Button('用完').fontSize(12).onClick(() => this.changeStatus(item, 'CONSUMED')).enabled(!this.busy)
                    Button('丢弃').fontSize(12).onClick(() => this.changeStatus(item, 'DISCARDED')).enabled(!this.busy)
                  } else {
                    Button('恢复在库').fontSize(12).onClick(() => this.changeStatus(item, 'ACTIVE')).enabled(!this.busy)
                  }
                  Button('删除').fontSize(12).fontColor('#A33F3F').onClick(() => {
                    AlertDialog.show({ title: '删除物品', message: `确定删除「${item.name}」？`,
                      primaryButton: { value: '取消', action: () => {} },
                      secondaryButton: { value: '删除', action: () => { this.remove(item); } } });
                  }).enabled(!this.busy)
                }
              }.padding(14).width('100%').backgroundColor('#FFFFFF').borderRadius(14)
            }
          }, (item: Item) => `${item.id}-${item.updatedAt}-${item.pending}`)
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').padding({ top: 36, left: 18, right: 18, bottom: 24 }).backgroundColor('#F4F7F3')
  }
}
