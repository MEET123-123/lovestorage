import { Item, ShoppingEntry } from '../domain/Item';
import { InventoryDomain } from '../domain/InventoryDomain';
import { SectionTitle, EmptyState } from '../components/InventoryComponents';

@Component
export struct SuggestionsPanel {
  @Prop items: Item[] = [];
  @Prop shopping: ShoppingEntry[] = [];
  @Prop today: string = '';
  @Prop busy: boolean = false;
  @State private tab: number = 0;
  @State private name: string = '';
  onOpen: (item: Item) => void = () => {};
  onAdd: (name: string) => void = () => {};
  onToggle: (entry: ShoppingEntry) => void = () => {};
  onRemove: (id: string) => void = () => {};
  build() {
    Column({ space: 12 }) {
      SectionTitle({ title: '让好物被好好使用', subtitle: '先处理已有物品，再考虑补充所需' })
      Row({ space: 10 }) {
        Button('处理建议').layoutWeight(1).backgroundColor(this.tab === 0 ? '#28785C' : '#FFFFFF').fontColor(this.tab === 0 ? '#FFFFFF' : '#63766D').onClick(() => { this.tab = 0; })
        Button(`补货清单 · ${this.shopping.filter((s: ShoppingEntry) => s.done === 0).length}`).layoutWeight(1).backgroundColor(this.tab === 1 ? '#28785C' : '#FFFFFF').fontColor(this.tab === 1 ? '#FFFFFF' : '#63766D').onClick(() => { this.tab = 1; })
      }.width('100%')
      if (this.tab === 0) {
        Text('基于记录日期的本地规则建议；并非 AI 识别，也不能替代实际状态检查。').fontSize(12).fontColor('#748078').width('100%')
        List({ space: 12 }) {
          if (InventoryDomain.urgent(this.items, this.today).length === 0) {
            ListItem() { EmptyState({ title: '暂时没有紧急事项', message: '录入物品的日期后，会按紧急程度给出处理提示。' }) }
          }
          ForEach(InventoryDomain.urgent(this.items, this.today), (item: Item) => {
            ListItem() {
              Column({ space: 12 }) {
                Row() {
                  Text(item.name).fontSize(18).fontWeight(FontWeight.Medium).fontColor('#223D31').layoutWeight(1)
                  Text(InventoryDomain.statusLabel(item, this.today)).fontSize(12).fontColor(InventoryDomain.statusColor(item, this.today))
                }.width('100%')
                Text(InventoryDomain.advice(item, this.today)).fontSize(14).fontColor('#63766D').lineHeight(23).width('100%')
                Text('查看详情与处理 ›').fontSize(13).fontColor('#28785C').width('100%').onClick(() => this.onOpen(item))
              }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
            }
          }, (i: Item) => `${i.id}-${i.updatedAt}`)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
      } else {
        Row({ space: 8 }) {
          TextInput({ text: this.name, placeholder: '需要补充什么？' }).maxLength(80).layoutWeight(1).onChange((v: string) => { this.name = v; })
          Button('添加').fontSize(13).backgroundColor('#28785C').enabled(!this.busy && this.name.trim().length > 0).onClick(() => { this.onAdd(this.name); this.name = ''; })
        }.width('100%')
        List({ space: 10 }) {
          if (this.shopping.length === 0) { ListItem() { EmptyState({ title: '按需补货，少些重复', message: '直接添加，或从物品详情加入补货清单。' }) } }
          ForEach(this.shopping, (entry: ShoppingEntry) => {
            ListItem() {
              Row({ space: 12 }) {
                Checkbox({ name: entry.id }).select(entry.done === 1).selectedColor('#28785C').enabled(!this.busy)
                  .onChange((checked: boolean) => { if (checked !== (entry.done === 1)) this.onToggle(entry); })
                Text(entry.name).fontSize(16).fontColor(entry.done === 1 ? '#9AA69D' : '#223D31').layoutWeight(1)
                Text('移除').fontSize(12).fontColor('#9AA69D').onClick(() => { if (!this.busy) this.onRemove(entry.id); })
              }.padding(14).backgroundColor('#FFFFFF').borderRadius(16)
            }
          }, (s: ShoppingEntry) => `${s.id}-${s.done}`)
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
        Text('勾选表示已买到，不会自动创建库存记录。').fontSize(11).fontColor('#748078')
      }
    }.padding(20).width('100%').layoutWeight(1)
  }
}
