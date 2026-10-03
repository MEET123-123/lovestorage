import { Item, ConsumptionRecord } from '../domain/Item';
import { InventoryDomain, CategoryView } from '../domain/InventoryDomain';
import { ItemCard, EmptyState } from '../components/InventoryComponents';

@Component
export struct HomePanel {
  @Prop items: Item[] = [];
  @Prop records: ConsumptionRecord[] = [];
  @Prop today: string = '';
  onOpen: (item: Item) => void = () => {};
  onBrowse: (status: string, category: string) => void = () => {};
  onAdd: () => void = () => {};
  onStats: () => void = () => {};
  onText: () => void = () => {};
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('好物有期').fontSize(29).fontWeight(FontWeight.Bold).fontColor('#173C32')
            Text(`${this.today}  /  把日子过得新鲜一点`).fontSize(12).fontColor('#748078')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('◷').fontSize(29).fontColor('#28785C').onClick(() => this.onStats()).accessibilityText('查看使用统计')
        }.width('100%')
        Column({ space: 14 }) {
          Text('今天，照顾好这些物品').fontSize(15).fontColor('#E4EFE6').width('100%')
          Row({ space: 8 }) {
            Text(`${InventoryDomain.urgent(this.items, this.today).length}`).fontSize(56).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            Text('件待处理').fontSize(17).fontColor('#E4EFE6').padding({ top: 22 })
            Blank()
            Text('↗').fontSize(36).fontColor('#D2E9CA')
          }.width('100%')
          Text('及时查看，少一点遗忘，多一点珍惜。').fontSize(12).fontColor('#DBE8DE').width('100%')
          Row({ space: 12 }) {
            Button(`临期 ${InventoryDomain.overview(this.items, this.records, this.today).near}`)
              .layoutWeight(1).backgroundColor('#FFFFFF').fontColor('#28785C').onClick(() => this.onBrowse('NEAR_EXPIRY', 'all'))
            Button(`过期 ${InventoryDomain.overview(this.items, this.records, this.today).expired}`)
              .layoutWeight(1).backgroundColor('#467B5F').fontColor('#FFFFFF').onClick(() => this.onBrowse('EXPIRED', 'all'))
          }
        }.width('100%').padding(22).backgroundColor('#245F48').borderRadius(24)
        Row({ space: 10 }) {
          Button('＋ 手动录入').layoutWeight(1).height(48).backgroundColor('#DCEBDF').fontColor('#245F48').onClick(this.onAdd)
          Button('文本辅助录入').layoutWeight(1).height(48).backgroundColor('#FFFFFF').fontColor('#365A48').onClick(this.onText)
        }.width('100%')
        Row() {
          Text('我的库存').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#223D31').layoutWeight(1)
          Text(`共 ${InventoryDomain.overview(this.items, this.records, this.today).active} 件在库 ›`).fontSize(12).fontColor('#748078').onClick(() => this.onBrowse('ACTIVE', 'all'))
        }.width('100%')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(InventoryDomain.categories, (category: CategoryView) => {
            Row({ space: 8 }) {
              Text(category.mark).fontSize(20).fontColor(category.color)
              Column({ space: 4 }) {
                Text(category.name).fontSize(13).fontColor('#365A48')
                Text(`${this.items.filter((i: Item) => i.categoryId === category.id && i.lifecycleStatus === 'ACTIVE').length} 件`).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#223D31')
              }.alignItems(HorizontalAlign.Start)
            }.width('48%').padding(14).backgroundColor('#FFFFFF').borderRadius(16).margin({ bottom: 10 })
              .onClick(() => this.onBrowse('ACTIVE', category.id))
          }, (category: CategoryView) => category.id)
        }.width('100%')
        Row() {
          Text('优先处理').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#223D31').layoutWeight(1)
          Text('按有效到期日排序').fontSize(12).fontColor('#748078')
        }.width('100%')
        if (InventoryDomain.urgent(this.items, this.today).length === 0) {
          EmptyState({ title: this.items.length === 0 ? '欢迎建立你的好物清单' : '暂时没有待处理物品', message: this.items.length === 0 ? '录入日期后，会在这里看到临期提醒。' : '已稍后处理的物品仍可在库存中查看。' })
        } else {
          ForEach(InventoryDomain.urgent(this.items, this.today).slice(0, 10), (item: Item) => {
            ItemCard({ item, today: this.today, onOpen: this.onOpen })
          }, (item: Item) => `${item.id}-${item.updatedAt}-${item.pending}`)
        }
        Text('日期会随每一天更新，核心记录离线也能使用。').fontSize(11).fontColor('#8A968E').padding({ bottom: 12 })
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
