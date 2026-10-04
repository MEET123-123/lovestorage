import { Item, ConsumptionRecord } from '../domain/Item';
import { InventoryDomain } from '../algorithm/InventoryDomain';

@Component
export struct ItemDetail {
  @Prop item: Item = { id: '', name: '', categoryId: 'food', lifecycleStatus: 'ACTIVE', createdAt: 0, updatedAt: 0 };
  @Prop records: ConsumptionRecord[] = [];
  @Prop today: string = '';
  @Prop busy: boolean = false;
  onEdit: () => void = () => {};
  onTransition: (status: string) => void = () => {};
  onDelete: () => void = () => {};
  onSnooze: () => void = () => {};
  onShopping: () => void = () => {};
  onBatches: () => void = () => {};
  @Builder
  private row(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label).fontSize(13).fontColor('#748078').width(94)
      Text(value).fontSize(14).fontColor('#223D31').layoutWeight(1).textAlign(TextAlign.End)
    }.width('100%').padding({ top: 9, bottom: 9 })
  }
  private duration(value: number | undefined, unit: string | undefined): string {
    return value === undefined ? '未设置' : `${value} ${unit === 'MONTH' ? '月' : unit === 'YEAR' ? '年' : '天'}`;
  }
  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 10 }) {
          Text(InventoryDomain.category(this.item.categoryId).mark).fontSize(38).fontColor(InventoryDomain.category(this.item.categoryId).color)
          Text(this.item.name).fontSize(27).fontWeight(FontWeight.Bold).fontColor('#173C32').textAlign(TextAlign.Center)
          Text(`${this.item.brand || InventoryDomain.category(this.item.categoryId).name}  ·  ${this.item.quantity ?? 1} ${this.item.unit ?? '件'}`).fontSize(14).fontColor('#748078')
          Text(InventoryDomain.statusLabel(this.item, this.today)).fontSize(17).fontColor(InventoryDomain.statusColor(this.item, this.today)).padding(10).backgroundColor('#F0F4EE').borderRadius(12)
        }.width('100%').padding(24).backgroundColor('#FFFFFF').borderRadius(24)
        Column() {
          this.row('有效到期日', InventoryDomain.evaluate(this.item, this.today).effectiveExpiryDate ?? '待补充')
          this.row('包装到期日', this.item.expiryDate ?? '待补充')
          this.row('生产日期', this.item.productionDate ?? '未填写')
          this.row('保质期', this.duration(this.item.shelfLifeValue, this.item.shelfLifeUnit))
          this.row('开封日期', this.item.openedDate ?? '未记录开封')
          this.row('开封后期限', this.duration(this.item.afterOpenValue, this.item.afterOpenUnit))
          this.row('存放位置', this.item.location || '未填写')
          this.row('提前提醒', `${this.item.reminderDays ?? InventoryDomain.category(this.item.categoryId).days} 天`)
          if (this.item.snoozeUntil) { this.row('稍后处理至', this.item.snoozeUntil ?? '') }
          this.row('云端备份', this.item.pending === 1 ? '等待上传' : '核心字段已上传')
        }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(18)
        Column({ space: 10 }) {
          Text('处理建议').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#365A48').width('100%')
          Text(InventoryDomain.advice(this.item, this.today)).fontSize(14).fontColor('#53695B').lineHeight(23).width('100%')
          if (this.item.notes) { Text(`备注：${this.item.notes}`).fontSize(13).fontColor('#748078').width('100%') }
        }.padding(18).backgroundColor('#EAF0E2').borderRadius(18)
        Row({ space: 10 }) {
          Button('编辑资料').layoutWeight(1).onClick(this.onEdit).enabled(!this.busy)
          Button('加入补货').layoutWeight(1).backgroundColor('#FFFFFF').fontColor('#28785C').onClick(this.onShopping).enabled(!this.busy)
        }.width('100%')
        Button('管理批次 / 记录部分消耗').width('100%').backgroundColor('#E5EEDD').fontColor('#28785C').enabled(!this.busy).onClick(this.onBatches)
        if (this.item.lifecycleStatus === 'ACTIVE') {
          Row({ space: 10 }) {
            Button('已用完').layoutWeight(1).backgroundColor('#28785C').onClick(() => this.onTransition('CONSUMED')).enabled(!this.busy)
            Button('丢弃').layoutWeight(1).backgroundColor('#F3E6DF').fontColor('#A25B44').onClick(() => {
              AlertDialog.show({ title: '确认丢弃', message: '将记录本批物品的丢弃操作，之后可以恢复在库。', primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '确认', action: () => this.onTransition('DISCARDED') } });
            }).enabled(!this.busy)
          }.width('100%')
          Row({ space: 10 }) {
            Button('明天再处理').layoutWeight(1).backgroundColor('#FFFFFF').fontColor('#63766D').onClick(this.onSnooze).enabled(!this.busy)
            Button('归档').layoutWeight(1).backgroundColor('#FFFFFF').fontColor('#63766D').onClick(() => this.onTransition('ARCHIVED')).enabled(!this.busy)
          }.width('100%')
        } else {
          Button('恢复在库').width('100%').backgroundColor('#28785C').onClick(() => this.onTransition('ACTIVE')).enabled(!this.busy)
        }
        if (this.records.filter((r: ConsumptionRecord) => r.itemId === this.item.id).length > 0) {
          Column({ space: 10 }) {
            Text('处理记录').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#365A48').width('100%')
            ForEach(this.records.filter((r: ConsumptionRecord) => r.itemId === this.item.id), (r: ConsumptionRecord) => {
              Text(`${InventoryDomain.dateText(new Date(r.createdAt))}  ${r.action === 'CONSUMED' ? '已用完' : r.action === 'PARTIAL_CONSUMED' ? '部分消耗' : '已丢弃'} ${r.quantity}${r.revoked === 1 ? ' · 已撤销' : ''}`).fontSize(13).fontColor('#748078').width('100%')
            }, (r: ConsumptionRecord) => `${r.id}-${r.revoked}`)
          }.padding(16).backgroundColor('#FFFFFF').borderRadius(18)
        }
        Text('删除物品').fontSize(14).fontColor('#B84A46').padding(12).onClick(() => {
          if (!this.busy) AlertDialog.show({ title: '删除物品', message: '将从清单移除本物品，已有处理记录会保留。', primaryButton: { value: '取消', action: () => {} }, secondaryButton: { value: '删除', action: this.onDelete } });
        })
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
