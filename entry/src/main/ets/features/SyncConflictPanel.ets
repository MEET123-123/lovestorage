import { SyncConflict, SyncDocument } from '../domain/Sync';
import { SectionTitle, EmptyState } from '../components/InventoryComponents';
@Component
export struct SyncConflictPanel {
  @Prop conflicts: SyncConflict[] = [];
  @Prop busy: boolean = false;
  onResolve: (conflict: SyncConflict, keepLocal: boolean) => void = () => {};
  private describe(conflict: SyncConflict): string {
    const doc=JSON.parse(conflict.payload) as SyncDocument;
    return `云端：${doc.item.name} · ${doc.batches.length} 个批次 · 版本 ${conflict.remoteVersion}${doc.item.deletedAt?' · 已删除':''}`;
  }
  build() {
    Scroll() {
      Column({space:16}) {
        SectionTitle({title:'同步冲突',subtitle:'不会自动覆盖另一端的数据。请核对后选择保留哪一端的库存。'})
        if (!this.conflicts.length) { EmptyState({title:'没有待解决的冲突',message:'已有冲突在同步时会保留在这里。'}) }
        ForEach(this.conflicts,(conflict:SyncConflict)=>{
          Column({space:12}) {
            Text(`本机：${conflict.name}`).fontSize(18).fontColor('#223D31').width('100%')
            Text(this.describe(conflict)).fontSize(13).fontColor('#63766D').width('100%')
            Button('保留本机，写入云端').width('100%').enabled(!this.busy).onClick(()=>this.onResolve(conflict,true))
            Button('采用云端库存').width('100%').backgroundColor('#E7EEE4').fontColor('#365A48').enabled(!this.busy).onClick(()=>{
              AlertDialog.show({title:'采用云端库存？',message:'将用此云端版本替换该物品的本机库存和批次，本机处理流水会保留。',
                primaryButton:{value:'取消',action:()=>{}},secondaryButton:{value:'采用云端',action:()=>this.onResolve(conflict,false)}});
            })
          }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(18)
        },(conflict:SyncConflict)=>`${conflict.itemId}-${conflict.remoteVersion}`)
      }.padding(20).width('100%')
    }.layoutWeight(1)
  }
}
