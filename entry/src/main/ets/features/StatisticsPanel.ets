import { Item, ConsumptionRecord } from '../domain/Item';
import { InventoryDomain, CategoryView } from '../domain/InventoryDomain';
import { SectionTitle, EmptyState } from '../components/InventoryComponents';

@Component
export struct StatisticsPanel {
  @Prop items: Item[] = [];
  @Prop records: ConsumptionRecord[] = [];
  @Prop today: string = '';
  @State private period: number = 30;
  private filtered(): ConsumptionRecord[] {
    const start = new Date(`${this.today}T00:00:00`); start.setDate(start.getDate() - this.period + 1);
    return this.records.filter((r: ConsumptionRecord) => r.revoked === 0 && (this.period === 0 || r.createdAt >= start.getTime()));
  }
  private count(action: string): number { return this.filtered().filter((r: ConsumptionRecord) => r.action === action).length; }
  private rate(): number { return this.filtered().length === 0 ? 0 : Math.round(this.count('CONSUMED') * 100 / this.filtered().length); }
  private categoryCount(id: string): number { return this.items.filter((i: Item) => i.categoryId === id && i.lifecycleStatus === 'ACTIVE').length; }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        SectionTitle({ title: '每一次用完，都值得记录', subtitle: '当前库存与实际处理流水' })
        Row({ space: 8 }) {
          Button('近 30 天').layoutWeight(1).backgroundColor(this.period === 30 ? '#28785C' : '#FFFFFF').fontColor(this.period === 30 ? '#FFFFFF' : '#63766D').onClick(() => { this.period = 30; })
          Button('近 90 天').layoutWeight(1).backgroundColor(this.period === 90 ? '#28785C' : '#FFFFFF').fontColor(this.period === 90 ? '#FFFFFF' : '#63766D').onClick(() => { this.period = 90; })
          Button('全部').layoutWeight(1).backgroundColor(this.period === 0 ? '#28785C' : '#FFFFFF').fontColor(this.period === 0 ? '#FFFFFF' : '#63766D').onClick(() => { this.period = 0; })
        }
        Column({ space: 10 }) {
          Text(`${this.rate()}%`).fontSize(52).fontWeight(FontWeight.Bold).fontColor('#28785C')
          Text('用完占比').fontSize(15).fontColor('#365A48')
          Text('用完次数 ÷（用完次数 + 丢弃次数）').fontSize(11).fontColor('#748078')
          Progress({ value: this.rate(), total: 100, type: ProgressType.Linear }).color('#28785C').backgroundColor('#E7EDE5').width('90%')
          Row({ space: 24 }) {
            Text(`用完 ${this.count('CONSUMED')} 次`).fontColor('#28785C')
            Text(`丢弃 ${this.count('DISCARDED')} 次`).fontColor('#B17849')
          }.padding({ top: 8 })
        }.width('100%').padding(22).backgroundColor('#FFFFFF').borderRadius(22)
        Column({ space: 12 }) {
          Text('当前在库分布').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
          ForEach(InventoryDomain.categories, (c: CategoryView) => {
            Row({ space: 12 }) {
              Text(c.name).fontSize(13).fontColor('#63766D').width(74)
              Progress({ value: this.categoryCount(c.id), total: Math.max(1, this.items.filter((i: Item) => i.lifecycleStatus === 'ACTIVE').length), type: ProgressType.Linear }).color(c.color).layoutWeight(1)
              Text(`${this.categoryCount(c.id)}`).fontSize(14).fontColor('#223D31').width(24)
            }.width('100%')
          }, (c: CategoryView) => c.id)
          Text('库存数量按条目计，不混合相加不同计量单位。').fontSize(11).fontColor('#748078').width('100%')
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Text('最近处理记录').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
        if (this.filtered().length === 0) { EmptyState({ title: '还没有处理记录', message: '将物品标记为用完或丢弃后，这里会展示记录。' }) }
        ForEach(this.filtered().slice(0, 50), (r: ConsumptionRecord) => {
          Row() {
            Column({ space: 6 }) {
              Text(r.name).fontSize(15).fontColor('#223D31')
              Text(InventoryDomain.dateText(new Date(r.createdAt))).fontSize(12).fontColor('#748078')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text(r.action === 'CONSUMED' ? '已用完' : '已丢弃').fontSize(13).fontColor(r.action === 'CONSUMED' ? '#28785C' : '#B17849')
          }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(14)
        }, (r: ConsumptionRecord) => r.id)
        Text('恢复在库会撤销对应处理统计；旧版本中未记录时间的操作不计入本页。').fontSize(11).fontColor('#748078')
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
