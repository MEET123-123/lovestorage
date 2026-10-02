import { Item } from '../domain/Item';
import { ExpiryService, ExpiryStatus } from '../domain/ExpiryService';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';

@Entry
@Component
struct Index {
  @State private items: Item[] = [];
  @State private message: string = 'M1 Local-First baseline';
  private readonly repository: ItemLocalRepository = new ItemLocalRepository();
  private readonly expiryService: ExpiryService = new ExpiryService();

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    try {
      this.items = await this.repository.listActive();
      this.message = `本地库存 ${this.items.length} 件`;
    } catch (error) {
      this.message = `初始化失败: ${String(error)}`;
    }
  }

  private async addDemo(): Promise<void> {
    const now = Date.now();
    const id = `${now}-${Math.floor(Math.random() * 100000)}`;
    await this.repository.create({
      id,
      name: '示例牛奶',
      categoryId: 'food',
      expiryDate: '2026-10-09',
      lifecycleStatus: 'ACTIVE',
      createdAt: now,
      updatedAt: now
    });
    await this.reload();
  }

  private async remove(id: string): Promise<void> {
    await this.repository.softDelete(id);
    await this.reload();
  }

  private expiryLabel(item: Item): string {
    if (item.expiryDate === undefined) return '未知';
    const today = this.todayIso();
    const result = this.expiryService.evaluate(item.expiryDate, undefined, undefined, undefined, 7, today);
    if (result.status === ExpiryStatus.EXPIRED) return `已过期 ${Math.abs(result.remainingDays ?? 0)} 天`;
    if (result.status === ExpiryStatus.NEAR_EXPIRY) return `临期 ${result.remainingDays} 天`;
    return `正常 ${result.remainingDays} 天`;
  }

  private todayIso(): string {
    const date = new Date();
    const y = date.getFullYear();
    const m = `${date.getMonth() + 1}`.padStart(2, '0');
    const d = `${date.getDate()}`.padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  build() {
    Column({ space: 12 }) {
      Text('智能保质期 · M1')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Text(this.message)
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')

      Button('添加示例物品')
        .width('100%')
        .onClick(() => this.addDemo())

      if (this.items.length === 0) {
        Text('暂旰物品，点击上方按钮验证 ArkData CRUD。')
          .fontColor('#888888')
          .margin({ top: 24 })
      } else {
        List({ space: 8 }) {
          ForEach(this.items, (item: Item) => {
            ListItem() {
              Row() {
                Column({ space: 4 }) {
                  Text(item.name).fontSize(18).fontWeight(FontWeight.Medium)
                  Text(`${item.categoryId} · ${this.expiryLabel(item)}`)
                    .fontSize(13)
                    .fontColor('#666666')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button('删除')
                  .type(ButtonType.Normal)
                  .onClick(() => this.remove(item.id))
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
            }
          }, (item: Item) => item.id)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F7F7F7')
  }
}
