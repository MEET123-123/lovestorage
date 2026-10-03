import { Item } from '../domain/Item';
import { InventoryDomain, CategoryView } from '../domain/InventoryDomain';
import { ItemCard, SectionTitle, EmptyState } from '../components/InventoryComponents';

@Component
export struct InventoryPanel {
  @Prop items: Item[] = [];
  @Prop today: string = '';
  @Prop initialCategory: string = 'all';
  @Prop initialStatus: string = 'ACTIVE';
  @Prop initialQuery: string = '';
  @Prop initialOrder: number = 0;
  @State private query: string = '';
  @State private category: string = 'all';
  @State private status: string = 'ACTIVE';
  @State private order: number = 0;
  onOpen: (item: Item) => void = () => {};
  onAdd: () => void = () => {};
  onFilter: (query: string, category: string, status: string, order: number) => void = () => {};
  aboutToAppear(): void { this.category = this.initialCategory; this.status = this.initialStatus; this.query = this.initialQuery; this.order = this.initialOrder; }
  private changed(): void { this.onFilter(this.query, this.category, this.status, this.order); }
  private rows(): Item[] { return InventoryDomain.filter(this.items, this.query, this.category, this.status, this.order, this.today); }
  private statusIndex(): number { return ['ACTIVE', 'NEAR_EXPIRY', 'EXPIRED', 'CONSUMED', 'DISCARDED', 'ARCHIVED', 'all'].indexOf(this.status); }
  build() {
    Column({ space: 12 }) {
      SectionTitle({ title: '物品清单', subtitle: '按分类、日期与位置，找到每一件好物' })
      TextInput({ text: this.query, placeholder: '搜索名称、品牌、存放位置' }).height(46).backgroundColor('#FFFFFF')
        .onChange((value: string) => { this.query = value; this.changed(); })
      Scroll() {
        Row({ space: 8 }) {
          Button('全部分类').fontSize(12).backgroundColor(this.category === 'all' ? '#28785C' : '#FFFFFF').fontColor(this.category === 'all' ? '#FFFFFF' : '#63766D').onClick(() => { this.category = 'all'; this.changed(); })
          ForEach(InventoryDomain.categories, (c: CategoryView) => {
            Button(c.name).fontSize(12).backgroundColor(this.category === c.id ? '#28785C' : '#FFFFFF').fontColor(this.category === c.id ? '#FFFFFF' : '#63766D').onClick(() => { this.category = c.id; this.changed(); })
          }, (c: CategoryView) => c.id)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      Row() {
        Select([{ value: '在库' }, { value: '临期' }, { value: '过期' }, { value: '已用完' }, { value: '已丢弃' }, { value: '已归档' }, { value: '所有状态' }])
          .selected(this.statusIndex()).value(['在库', '临期', '过期', '已用完', '已丢弃', '已归档', '所有状态'][this.statusIndex()])
          .onSelect((index: number) => { this.status = ['ACTIVE', 'NEAR_EXPIRY', 'EXPIRED', 'CONSUMED', 'DISCARDED', 'ARCHIVED', 'all'][index]; this.changed(); })
        Blank()
        Select([{ value: '到期优先' }, { value: '最近更新' }, { value: '名称排序' }]).selected(this.order).value(['到期优先', '最近更新', '名称排序'][this.order])
          .onSelect((index: number) => { this.order = index; this.changed(); })
      }.width('100%')
      Row() {
        Text(`${this.rows().length} 条记录`).fontSize(12).fontColor('#748078').layoutWeight(1)
        Text('＋ 新增').fontSize(14).fontColor('#28785C').onClick(this.onAdd)
      }.width('100%')
      List({ space: 10 }) {
        if (this.rows().length === 0) {
          ListItem() { EmptyState({ title: '没有符合条件的物品', message: '试试其他分类或状态，也可以新增一件物品。' }) }
        }
        ForEach(this.rows(), (item: Item) => {
          ListItem() { ItemCard({ item, today: this.today, onOpen: this.onOpen }) }
        }, (item: Item) => `${item.id}-${item.updatedAt}-${item.pending}`)
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.padding(20).width('100%').layoutWeight(1)
  }
}
