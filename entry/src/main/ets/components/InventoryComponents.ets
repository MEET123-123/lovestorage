import { Item } from '../domain/Item';
import { InventoryDomain } from '../domain/InventoryDomain';

@Component
export struct SectionTitle {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  build() {
    Column({ space: 5 }) {
      Text(this.title).fontSize(25).fontWeight(FontWeight.Bold).fontColor('#173C32').width('100%')
      if (this.subtitle !== '') { Text(this.subtitle).fontSize(13).fontColor('#748078').width('100%') }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ bottom: 8 })
  }
}

@Component
export struct EmptyState {
  @Prop title: string = '这里还没有物品';
  @Prop message: string = '从记录第一件好物开始。';
  build() {
    Column({ space: 10 }) {
      Text('○').fontSize(42).fontColor('#9CB7A7')
      Text(this.title).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#365A48')
      Text(this.message).fontSize(13).fontColor('#748078').textAlign(TextAlign.Center)
    }.width('100%').padding(28).backgroundColor('#FFFFFF').borderRadius(20)
  }
}

@Component
export struct ItemCard {
  @Prop item: Item = { id: '', name: '', categoryId: 'food', lifecycleStatus: 'ACTIVE', createdAt: 0, updatedAt: 0 };
  @Prop today: string = '';
  onOpen: (item: Item) => void = () => {};
  build() {
    Row({ space: 12 }) {
      Text(InventoryDomain.category(this.item.categoryId).mark).fontSize(22).fontWeight(FontWeight.Medium)
        .fontColor(InventoryDomain.category(this.item.categoryId).color).width(48).height(52).textAlign(TextAlign.Center)
        .backgroundColor('#F0F4EE').borderRadius(15)
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text(this.item.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#223D31').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.item.pending === 1) { Text('待上传').fontSize(10).fontColor('#8A968E') }
        }.width('100%')
        Text(`${this.item.quantity ?? 1} ${this.item.unit ?? '件'}  ·  ${this.item.location || InventoryDomain.category(this.item.categoryId).name}`)
          .fontSize(12).fontColor('#748078').maxLines(1).width('100%')
        Text(InventoryDomain.statusLabel(this.item, this.today)).fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(InventoryDomain.statusColor(this.item, this.today)).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(25).fontColor('#9AA69D')
    }.width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(18).onClick(() => this.onOpen(this.item))
      .accessibilityText(`${this.item.name}，${InventoryDomain.statusLabel(this.item, this.today)}，查看详情`)
  }
}
