import { Item, InventoryBatch, BatchRecord } from '../domain/Item';
import { BatchLocalRepository } from '../data/local/BatchLocalRepository';
import { SectionTitle, EmptyState } from '../components/InventoryComponents';
@Component
export struct BatchPanel {
  @Prop item: Item = {id:'',name:'',categoryId:'food',lifecycleStatus:'ACTIVE',createdAt:0,updatedAt:0};
  @Prop batches: BatchRecord[] = [];
  @Prop busy: boolean = false;
  @Prop undoAvailable: boolean = false;
  @State private quantity: string = '1';
  @State private expiry: string = '';
  @State private opened: string = '';
  @State private afterOpen: string = '';
  @State private location: string = '';
  @State private amount: string = '1';
  @State private editingId: string = '';
  @State private afterUnit: string = 'DAY';
  private readonly units: string[]=['DAY','MONTH','YEAR'];
  onAdd: (batch: InventoryBatch) => void = () => {};
  onUpdate: (id:string,batch:InventoryBatch)=>void=()=>{};
  onConsume: (id: string, quantity: number, discarded: boolean) => void = () => {};
  onUndo: () => void = () => {};
  private edit(batch:BatchRecord):void {
    this.editingId=batch.id;this.quantity=`${batch.quantity}`;this.expiry=batch.expiryDate??'';
    this.opened=batch.openedDate??'';this.afterOpen=batch.afterOpenValue===undefined?'':`${batch.afterOpenValue}`;
    this.afterUnit=batch.afterOpenUnit??'DAY';this.location=batch.location??'';
  }
  private reset():void {this.editingId='';this.quantity='1';this.expiry='';this.opened='';this.afterOpen='';this.afterUnit='DAY';this.location='';}
  build() {
    Scroll() {
      Column({space:14}) {
        SectionTitle({title:`${this.item.name} · 批次`,subtitle:'不同日期分别保存；消耗按指定批次扣减，不覆盖其他库存。'})
        Text(`在库合计 ${this.item.quantity ?? 0} ${this.item.unit ?? '件'}`).fontColor('#28785C').fontSize(17).width('100%')
        TextInput({text:this.amount,placeholder:'本次处理数量（最多 3 位小数）'}).onChange((v:string)=>{this.amount=v;}).enabled(!this.busy)
        if (this.undoAvailable) { Button('撤销最近一次批次处理').enabled(!this.busy).onClick(this.onUndo) }
        if (!this.batches.length) { EmptyState({title:'暂无批次',message:'添加一个真实库存批次。'}) }
        ForEach(this.batches,(batch:BatchRecord)=>{
          Column({space:10}) {
            Text(`${batch.quantity} ${batch.unit ?? '件'} · ${batch.lifecycleStatus === 'ACTIVE' ? '在库' : batch.lifecycleStatus === 'CONSUMED' ? '已用完' : '已处理'}`)
              .fontSize(18).fontColor('#223D31').width('100%')
            Text(`有效期限 ${BatchLocalRepository.expiry(batch)} · ${batch.location || '未设置位置'}`).fontSize(13).fontColor('#63766D').width('100%')
            if (batch.openedDate) { Text(`开封 ${batch.openedDate} · 开封后 ${batch.afterOpenValue ?? '未设置'} ${batch.afterOpenUnit ?? ''}`).fontSize(12).fontColor('#748078') }
            if (batch.lifecycleStatus === 'ACTIVE' && this.item.lifecycleStatus==='ACTIVE') {
              Row({space:8}) {
                Button('记录消耗').layoutWeight(1).enabled(!this.busy).onClick(()=>this.onConsume(batch.id,Number(this.amount),false))
                Button('记录丢弃').layoutWeight(1).backgroundColor('#F3E6DF').fontColor('#A25B44').enabled(!this.busy).onClick(()=>this.onConsume(batch.id,Number(this.amount),true))
              }.width('100%')
              Button('编辑日期、开封与余量').enabled(!this.busy).backgroundColor('#E5EEDD').fontColor('#28785C').onClick(()=>this.edit(batch))
            }
          }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        },(batch:BatchRecord)=>`${batch.id}-${batch.updatedAt}`)
        Column({space:10}) {
          Text(this.editingId?'编辑在库批次':'添加新批次').fontSize(18).fontColor('#223D31').width('100%')
          if(this.editingId) {Button('取消编辑，改为新增').onClick(()=>this.reset()).enabled(!this.busy)}
          TextInput({text:this.quantity,placeholder:`数量，单位 ${this.item.unit ?? '件'}`}).onChange((v:string)=>{this.quantity=v;})
          TextInput({text:this.expiry,placeholder:'包装到期日 YYYY-MM-DD'}).onChange((v:string)=>{this.expiry=v;})
          TextInput({text:this.opened,placeholder:'开封日期（可选）YYYY-MM-DD'}).onChange((v:string)=>{this.opened=v;})
          TextInput({text:this.afterOpen,placeholder:'开封后期限数值（可选）'}).onChange((v:string)=>{this.afterOpen=v;})
          Select([{value:'天'},{value:'月'},{value:'年'}]).selected(Math.max(0,this.units.indexOf(this.afterUnit))).value(this.afterUnit==='MONTH'?'月':this.afterUnit==='YEAR'?'年':'天').onSelect((i:number)=>{this.afterUnit=this.units[i];})
          TextInput({text:this.location,placeholder:'存放位置'}).onChange((v:string)=>{this.location=v;})
          Text('调整余量用于纠正录入；实际使用请点上方“记录消耗”，以保留处理流水。').fontSize(11).fontColor('#748078')
          Button(this.editingId?'保存批次修改':'保存新批次').enabled(!this.busy).onClick(()=>{
            const original=this.batches.find((b:BatchRecord)=>b.id===this.editingId);
            const batch:InventoryBatch={quantity:Number(this.quantity),unit:this.item.unit ?? '件',expiryDate:this.expiry.trim(),location:this.location.trim(),
              productionDate:original?.productionDate,shelfLifeValue:original?.shelfLifeValue,shelfLifeUnit:original?.shelfLifeUnit,
              openedDate:this.opened.trim() || undefined,afterOpenValue:this.afterOpen.trim()?Number(this.afterOpen):undefined,afterOpenUnit:this.afterOpen.trim()?this.afterUnit:undefined};
            if(this.editingId)this.onUpdate(this.editingId,batch);else this.onAdd(batch);
          })
        }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(18)
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
