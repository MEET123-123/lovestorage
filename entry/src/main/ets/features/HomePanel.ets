import { Item, ConsumptionRecord } from '../domain/Item';
import { InventoryDomain } from '../algorithm/InventoryDomain';
import { AttentionEngine } from '../algorithm/AttentionEngine';
import { TodayCard } from '../viewmodel/TodayViewModel';
import { ItemCard, EmptyState } from '../components/InventoryComponents';

@Component
export struct HomePanel {
  @Prop items: Item[] = [];
  @Prop cards: TodayCard[] = [];
  @Prop records: ConsumptionRecord[] = [];
  @Prop today: string = '';
  @Prop busy: boolean = false;
  onOpen: (item: Item) => void = () => {};
  onAction: (item: Item, action: string) => void = () => {};
  onBrowse: (status: string, category: string) => void = () => {};
  onAdd: () => void = () => {};
  onStats: () => void = () => {};
  onText: () => void = () => {};
  onSuggestions: () => void = () => {};
  onFeedback: (item:Item)=>void=()=>{};
  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text('今天').fontSize(29).fontWeight(FontWeight.Bold).fontColor('#173C32')
            Text(`${this.today}  /  从最值得关注的一件开始`).fontSize(12).fontColor('#748078')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('◷').fontSize(29).fontColor('#28785C').onClick(() => this.onStats()).accessibilityText('查看使用统计')
        }.width('100%')
        Column({ space: 12 }) {
          Text(`今天有 ${this.cards.length} 件物品需要关注`).fontSize(21).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').width('100%')
          Text(this.cards.length ? '根据到期时间、开封期限和余量，给你一个处理顺序。' : '可以从录入一件物品开始，也可以查看已有库存。')
            .fontSize(13).fontColor('#E4EFE6').width('100%')
          Row({ space: 12 }) {
            Button(`临期 ${InventoryDomain.overview(this.items, this.records, this.today).near}`)
              .layoutWeight(1).backgroundColor('#FFFFFF').fontColor('#28785C').onClick(() => this.onBrowse('NEAR_EXPIRY', 'all'))
            Button(`过期 ${InventoryDomain.overview(this.items, this.records, this.today).expired}`)
              .layoutWeight(1).backgroundColor('#467B5F').fontColor('#FFFFFF').onClick(() => this.onBrowse('EXPIRED', 'all'))
          }
        }.width('100%').padding(22).backgroundColor('#245F48').borderRadius(24)
        if (this.cards.length === 0) {
          EmptyState({ title: this.items.length === 0 ? '欢迎建立你的好物清单' : '暂时没有待处理物品',
            message: this.items.length === 0 ? '录入包装日期，就能在这里安排处理。' : '稍后提醒的物品仍在库存中；到时间后会重新出现。' })
        } else {
          ForEach(this.cards.slice(0, 10), (card: TodayCard, index: number) => {
            Column({ space: 12 }) {
              Row() {
                Text(index === 0 ? '最先关注' : `关注 ${index + 1}`).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#28785C').layoutWeight(1)
                Text(`优先级 ${card.decision.priority === 'HIGH' ? '高' : card.decision.priority === 'MEDIUM' ? '中' : '低'}`)
                  .fontSize(12).fontColor('#748078')
              }.width('100%')
              ItemCard({ item: card.item, today: this.today, onOpen: this.onOpen })
              Text(card.decision.reasonCodes.map((code: string) => AttentionEngine.reason(code)).join(' · '))
                .fontSize(12).fontColor('#AC6A27').width('100%')
              Text(card.advice).fontSize(12).fontColor('#63766D').width('100%')
              Row({ space: 10 }) {
                if (card.decision.remainingDays === undefined) {
                  Button('补充日期').layoutWeight(1).backgroundColor('#28785C').onClick(() => this.onOpen(card.item))
                } else if (card.decision.remainingDays < 0) {
                  Button('记录丢弃').layoutWeight(1).backgroundColor('#B84A46').enabled(!this.busy).onClick(() => this.onAction(card.item, 'DISCARDED'))
                } else if (card.safety.blocked) {
                  Button('核对忌口与详情').layoutWeight(1).backgroundColor('#AC6A27').enabled(!this.busy).onClick(()=>this.onOpen(card.item))
                } else {
                  Button('已用完').layoutWeight(1).backgroundColor('#28785C').enabled(!this.busy).onClick(() => this.onAction(card.item, 'CONSUMED'))
                }
                Button('稍后提醒').layoutWeight(1).backgroundColor('#E7EEE4').fontColor('#365A48').enabled(!this.busy).onClick(() => this.onAction(card.item, 'SNOOZE'))
              }.width('100%')
              Text('这条排序对我没有帮助').fontSize(11).fontColor('#748078').onClick(()=>{if(!this.busy)this.onFeedback(card.item);})
            }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(20)
          }, (card: TodayCard) => `${card.item.id}-${card.item.updatedAt}-${card.decision.score}`)
          if (this.cards.length > 10) {
            Button('查看全部库存').backgroundColor('#DCEBDF').fontColor('#245F48').onClick(() => this.onBrowse('ACTIVE', 'all'))
          }
        }
        Text('优先级表示关注顺序，不表示食品安全等级；实际使用前请核对包装、储存条件和忌口。')
          .fontSize(11).fontColor('#8A968E').width('100%')
        Row({ space: 10 }) {
          Button('＋ 手动录入').layoutWeight(1).height(48).backgroundColor('#DCEBDF').fontColor('#245F48').onClick(this.onAdd)
          Button('文本辅助录入').layoutWeight(1).height(48).backgroundColor('#FFFFFF').fontColor('#365A48').onClick(this.onText)
        }.width('100%')
        Button('处理建议与补货清单 ›').width('100%').backgroundColor('#FFFFFF').fontColor('#28785C').onClick(this.onSuggestions)
        Text('今日排序在本机完成，服务异常不会阻止查看库存和处理物品。').fontSize(11).fontColor('#8A968E').padding({ bottom: 12 })
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
