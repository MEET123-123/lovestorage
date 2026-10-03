import { Item } from '../domain/Item';
import { InventoryDomain } from '../domain/InventoryDomain';
import { ExpiryService, ShelfLifeUnit } from '../domain/ExpiryService';
import { SectionTitle } from '../components/InventoryComponents';

@Component
export struct ItemEditor {
  @Prop item: Item = { id: '', name: '', categoryId: 'food', lifecycleStatus: 'ACTIVE', createdAt: 0, updatedAt: 0 };
  @Prop busy: boolean = false;
  @Prop textMode: boolean = false;
  @State private name: string = '';
  @State private brand: string = '';
  @State private quantity: string = '1';
  @State private unit: string = '件';
  @State private category: number = 0;
  @State private expiry: string = '';
  @State private production: string = '';
  @State private shelfLife: string = '';
  @State private shelfUnit: number = 0;
  @State private opened: string = '';
  @State private afterOpen: string = '';
  @State private afterUnit: number = 1;
  @State private location: string = '';
  @State private notes: string = '';
  @State private reminder: string = '7';
  @State private derive: boolean = false;
  @State private error: string = '';
  @State private pasted: string = '';
  @State private evidence: string = '';
  onSave: (item: Item) => void = () => {};
  private readonly units: string[] = ['DAY', 'MONTH', 'YEAR'];

  aboutToAppear(): void {
    this.name = this.item.name; this.brand = this.item.brand ?? ''; this.quantity = `${this.item.quantity ?? 1}`;
    this.unit = this.item.unit ?? '件'; this.category = Math.max(0, InventoryDomain.categories.findIndex((c) => c.id === this.item.categoryId));
    this.expiry = this.item.expiryDate ?? ''; this.production = this.item.productionDate ?? '';
    this.shelfLife = this.item.shelfLifeValue === undefined ? '' : `${this.item.shelfLifeValue}`;
    this.derive = this.item.shelfLifeValue !== undefined && this.item.productionDate !== undefined;
    this.shelfUnit = Math.max(0, this.units.indexOf(this.item.shelfLifeUnit ?? 'DAY'));
    this.opened = this.item.openedDate ?? ''; this.afterOpen = this.item.afterOpenValue === undefined ? '' : `${this.item.afterOpenValue}`;
    this.afterUnit = Math.max(0, this.units.indexOf(this.item.afterOpenUnit ?? 'MONTH'));
    this.location = this.item.location ?? ''; this.notes = this.item.notes ?? '';
    this.reminder = `${this.item.reminderDays ?? InventoryDomain.category(this.item.categoryId).days}`;
  }
  private proposed(): Item {
    let expiry: string | undefined = this.expiry.trim() || undefined;
    if (this.derive) {
      expiry = undefined;
      if (InventoryDomain.validDate(this.production) && Number.isInteger(Number(this.shelfLife)) && Number(this.shelfLife) > 0 && Number(this.shelfLife) <= 1200) {
        expiry = new ExpiryService().deriveExpiryDate(this.production, Number(this.shelfLife), this.units[this.shelfUnit] as ShelfLifeUnit);
      }
    }
    return {
      id: this.item.id, name: this.name.trim(), categoryId: InventoryDomain.categories[this.category].id,
      lifecycleStatus: this.item.lifecycleStatus, createdAt: this.item.createdAt, updatedAt: this.item.updatedAt,
      remoteId: this.item.remoteId, expiryDate: expiry, brand: this.brand.trim(), quantity: Number(this.quantity), unit: this.unit.trim() || '件',
      productionDate: this.production.trim() || undefined, shelfLifeValue: this.derive ? Number(this.shelfLife) : undefined,
      shelfLifeUnit: this.derive ? this.units[this.shelfUnit] : undefined,
      openedDate: this.opened.trim() || undefined, afterOpenValue: this.afterOpen.trim() === '' ? undefined : Number(this.afterOpen),
      afterOpenUnit: this.afterOpen.trim() === '' ? undefined : this.units[this.afterUnit], location: this.location.trim(), notes: this.notes.trim(),
      reminderDays: Number(this.reminder), snoozeUntil: this.item.snoozeUntil
    };
  }
  private preview(): string {
    const candidate = this.proposed();
    if (InventoryDomain.validate(candidate) !== '') return '填写有效日期后，这里将显示最终到期日';
    return `有效到期日 ${InventoryDomain.evaluate(candidate).effectiveExpiryDate} · ${InventoryDomain.statusLabel(candidate)}`;
  }
  private submit(): void {
    const candidate = this.proposed();
    this.error = InventoryDomain.validate(candidate);
    if (!this.error) this.onSave(candidate);
  }
  private fillText(): void {
    if (!this.pasted.trim()) { this.error = '请先粘贴包装上的文字'; return; }
    const draft = InventoryDomain.parseText(this.pasted);
    this.name = draft.name; this.expiry = draft.expiry; this.production = draft.production;
    this.shelfLife = draft.shelfLife; this.shelfUnit = draft.unit;
    this.derive = draft.expiry === '' && draft.production !== '' && draft.shelfLife !== '';
    this.evidence = draft.evidence; this.error = '';
  }
  private pickDate(field: string): void {
    const text = field === 'expiry' ? this.expiry : field === 'production' ? this.production : this.opened;
    DatePickerDialog.show({
      start: new Date(1900, 0, 1), end: new Date(2100, 11, 31), selected: InventoryDomain.validDate(text) ? new Date(`${text}T12:00:00`) : new Date(),
      onAccept: (value: DatePickerResult) => {
        const date = new Date(value.year ?? 2026, value.month ?? 0, value.day ?? 1);
        const result = InventoryDomain.dateText(date);
        if (field === 'expiry') this.expiry = result;
        else if (field === 'production') this.production = result;
        else this.opened = result;
      }
    });
  }
  @Builder
  private caption(title: string) { Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#365A48').width('100%').margin({ top: 8 }) }
  @Builder
  private field(label: string, value: string, hint: string, change: (text: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(12).fontColor('#63766D').width('100%')
      TextInput({ text: value, placeholder: hint }).height(44).backgroundColor('#F4F6F1').onChange(change).enabled(!this.busy)
    }.width('100%')
  }
  build() {
    Column() {
      Scroll() {
        Column({ space: 14 }) {
          SectionTitle({ title: this.item.id === '' ? '记录一件好物' : '编辑物品', subtitle: '保存到本机，离线也能查看与管理' })
          if (this.textMode) {
            Column({ space: 10 }) {
              Text('包装文字辅助录入').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#365A48').width('100%')
              TextArea({ text: this.pasted, placeholder: '名称：纯牛奶\n生产日期：2026-10-03\n保质期：30天' }).height(115).maxLength(2000).onChange((v: string) => { this.pasted = v; })
              Button('提取到表单').fontSize(14).onClick(() => this.fillText()).enabled(!this.busy)
              Text(this.evidence || '支持粘贴已识别的文字，规则提取后仍需你核对；不会自动保存。').fontSize(12).fontColor('#748078')
            }.padding(16).backgroundColor('#E7F0E4').borderRadius(18)
          }
          Column({ space: 12 }) {
            this.caption('01  基本信息')
            this.field('物品名称 *', this.name, '例如：鲜牛奶、面霜', (v: string) => { this.name = v; })
            Select([{ value: '食品' }, { value: '美妆个护' }, { value: '宠物粮' }, { value: '日用其他' }])
              .selected(this.category).value(InventoryDomain.categories[this.category].name).width('100%')
              .onSelect((index: number) => { this.category = index; this.reminder = `${InventoryDomain.categories[index].days}`; }).enabled(!this.busy)
            this.field('品牌（选填）', this.brand, '品牌名称', (v: string) => { this.brand = v; })
            this.field('数量 *', this.quantity, '例如 1 或 0.5', (v: string) => { this.quantity = v; })
            this.field('单位', this.unit, '件 / 盒 / 瓶 / kg', (v: string) => { this.unit = v; })
          }.padding(16).backgroundColor('#FFFFFF').borderRadius(18)
          Column({ space: 12 }) {
            this.caption('02  日期与保质期')
            Row({ space: 8 }) {
              Button('直接填到期日').layoutWeight(1).fontSize(12).backgroundColor(this.derive ? '#F0F4EE' : '#28785C').fontColor(this.derive ? '#63766D' : '#FFFFFF').onClick(() => { this.derive = false; })
              Button('按保质期计算').layoutWeight(1).fontSize(12).backgroundColor(this.derive ? '#28785C' : '#F0F4EE').fontColor(this.derive ? '#FFFFFF' : '#63766D').onClick(() => { this.derive = true; })
            }
            if (!this.derive) {
              this.field('包装到期日期 *', this.expiry, 'YYYY-MM-DD', (v: string) => { this.expiry = v; })
              Text('选择到期日期 ›').fontSize(13).fontColor('#28785C').onClick(() => this.pickDate('expiry'))
            }
            this.field(this.derive ? '生产日期 *' : '生产日期（选填）', this.production, 'YYYY-MM-DD', (v: string) => { this.production = v; })
            Text('选择生产日期 ›').fontSize(13).fontColor('#28785C').onClick(() => this.pickDate('production'))
            if (this.derive) {
              this.field('保质期 *', this.shelfLife, '填写整数', (v: string) => { this.shelfLife = v; })
              Select([{ value: '天' }, { value: '月' }, { value: '年' }]).selected(this.shelfUnit).value(['天', '月', '年'][this.shelfUnit]).onSelect((i: number) => { this.shelfUnit = i; })
            }
            this.field('开封日期（选填）', this.opened, '未开封请留空', (v: string) => { this.opened = v; })
            Text('选择开封日期 ›').fontSize(13).fontColor('#28785C').onClick(() => this.pickDate('opened'))
            this.field('开封后使用期限（选填）', this.afterOpen, '例如面霜开封后 6 个月', (v: string) => { this.afterOpen = v; })
            Select([{ value: '天' }, { value: '月' }, { value: '年' }]).selected(this.afterUnit).value(['天', '月', '年'][this.afterUnit]).onSelect((i: number) => { this.afterUnit = i; })
            Text(this.preview()).fontSize(13).fontColor('#28785C').padding(12).width('100%').backgroundColor('#EAF2E6').borderRadius(12)
            Text('开封期限与包装日期取较早值；月份按自然月计算。').fontSize(11).fontColor('#748078')
          }.padding(16).backgroundColor('#FFFFFF').borderRadius(18)
          Column({ space: 12 }) {
            this.caption('03  收纳与提醒')
            this.field('存放位置', this.location, '冰箱冷藏 / 橱柜 / 梳妆台', (v: string) => { this.location = v; })
            this.field('提前几天提醒', this.reminder, '0–365 天', (v: string) => { this.reminder = v; })
            Text('首页会显示到期待办；系统通知需在“我的”中单独开启。').fontSize(11).fontColor('#748078')
            TextArea({ text: this.notes, placeholder: '备注、储存要求等' }).height(90).maxLength(500).onChange((v: string) => { this.notes = v; })
          }.padding(16).backgroundColor('#FFFFFF').borderRadius(18)
          if (this.error !== '') { Text(this.error).fontSize(13).fontColor('#B84A46').width('100%') }
        }.padding(20).width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
      Button(this.busy ? '正在保存…' : '保存物品').width('90%').height(48).backgroundColor('#28785C').margin({ top: 8, bottom: 16 })
        .enabled(!this.busy).onClick(() => this.submit())
    }.layoutWeight(1).width('100%')
  }
}
