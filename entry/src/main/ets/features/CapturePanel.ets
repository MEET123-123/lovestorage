import { CaptureDraft } from '../data/local/DraftLocalRepository';
import { InventoryDomain } from '../algorithm/InventoryDomain';
import { DateCandidate } from '../algorithm/RecognitionEngine';
@Component
export struct CapturePanel {
  @Prop drafts: CaptureDraft[]=[];
  @Prop busy: boolean=false;
  @State private text: string='';
  onCreate: (mode:string,text:string)=>void=()=>{};
  onConfirm: (draft:CaptureDraft)=>void=()=>{};
  onManual: ()=>void=()=>{};
  onDiscard: (id:string)=>void=()=>{};
  private sample(mode: string): void {
    const date=new Date(); date.setDate(date.getDate()+14);
    this.onCreate(mode,`品名：${mode==='MOCK_ASR'?'语音样例酸奶':mode==='MOCK_BARCODE'?'条码样例牛奶':'拍照样例牛奶'}\n到期日期：${InventoryDomain.dateText(date)}`);
  }
  build() {
    Scroll() {
      Column({space:14}) {
        Text('智能录入与待确认草稿').fontSize(22).fontWeight(FontWeight.Bold)
        Text('Mock 调试：拍照、语音、条码使用固定样例文字，不调用真实硬件或外部算法。草稿不会直接加入库存。').fontSize(13).fontColor('#9B5C25')
        Row({space:6}) {
          Button('拍照 Mock').fontSize(12).onClick(()=>this.sample('MOCK_OCR')).enabled(!this.busy)
          Button('语音 Mock').fontSize(12).onClick(()=>this.sample('MOCK_ASR')).enabled(!this.busy)
          Button('条码 Mock').fontSize(12).onClick(()=>this.sample('MOCK_BARCODE')).enabled(!this.busy)
        }
        TextArea({text:this.text,placeholder:'粘贴包装文字，例如：品名：牛奶；到期日期：2027-01-01'}).height(100).onChange((v:string)=>{this.text=v;})
        Button('生成文字识别草稿').enabled(!this.busy).onClick(()=>this.onCreate('TEXT_RULES',this.text))
        Button('手动录入').onClick(()=>this.onManual()).enabled(!this.busy)
        Text(`待确认 ${this.drafts.length} 条 · 可连续生成样例`).fontSize(14)
        ForEach(this.drafts,(draft:CaptureDraft)=>{
          Column({space:8}) {
            Text(`${draft.mode.startsWith('MOCK')?'[Mock] ':''}${draft.result.name||'待补充名称'}`).fontWeight(FontWeight.Bold)
            Text(`到期 ${draft.result.expiry||'待核对'} · ${draft.result.engineVersion}`).fontSize(13)
            ForEach(draft.result.candidates,(c:DateCandidate)=>{Text(`${c.evidence} → ${c.value} · 规则强度 ${c.confidence}（非准确率）`).fontSize(12)},(c:DateCandidate)=>`${c.field}:${c.value}:${c.evidence}`)
            Text(draft.result.warnings.join('；')||'仍需对照包装核对名称、日期与数量').fontSize(12).fontColor('#9B5C25')
            Button('核对并进入编辑').enabled(!this.busy).onClick(()=>this.onConfirm(draft))
            Button('删除此草稿').enabled(!this.busy).backgroundColor('#EEEEEE').fontColor('#63766D').onClick(()=>{
              AlertDialog.show({title:'删除识别草稿？',message:'仅移除这条待确认草稿，不影响已保存库存。',primaryButton:{value:'保留',action:()=>{}},secondaryButton:{value:'删除',action:()=>this.onDiscard(draft.id)}});
            })
          }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(16)
        },(d:CaptureDraft)=>d.id)
      }.width('100%').padding(20)
    }.layoutWeight(1)
  }
}
