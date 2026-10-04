import { Item, ConsumptionRecord } from '../domain/Item';
import { UserProfile, ProfileDomain } from '../domain/UserProfile';
import { AttentionEngine, AttentionDecision } from '../algorithm/AttentionEngine';
import { SafetyGuard } from '../algorithm/SafetyGuard';
import { ReminderTiming } from '../algorithm/ReminderTiming';
import { MockForecast } from '../algorithm/MockForecast';
import { DecisionLog } from '../data/local/DecisionLocalRepository';
@Component
export struct AlgorithmDemoPanel {
  @Prop items: Item[]=[];
  @Prop profile: UserProfile=ProfileDomain.empty();
  @Prop today: string='';
  @Prop records: ConsumptionRecord[]=[];
  @Prop decisions: DecisionLog[]=[];
  @Prop reminderHour: number=9;
  onApplyHour: (hour:number)=>void=()=>{};
  build() {
    Scroll() {
      Column({space:16}) {
        Text('算法调试').fontSize(24).fontWeight(FontWeight.Bold)
        Text('线上基线：attention-rule-v1 · 日期与开封期限规则').fontSize(14)
        Text('Mock 模型：forecast-mock-v1 · SHADOW（仅展示）\n按固定每日 0.25 单位模拟余量，不是学习到的消耗速度，不改变库存、日期或线上排序。').fontSize(14).fontColor('#9B5C25')
        Text(`当前提醒时段 ${this.reminderHour}:00`).fontSize(16)
        Text(ReminderTiming.recommend(this.records,Date.now()).explanation).fontSize(13)
        Button('采用历史规则推荐时段').onClick(()=>this.onApplyHour(ReminderTiming.recommend(this.records,Date.now()).hour))
        Row({space:6}) {
          Button('09:00').onClick(()=>this.onApplyHour(9))
          Button('12:00').onClick(()=>this.onApplyHour(12))
          Button('18:00').onClick(()=>this.onApplyHour(18))
        }
        Text('当前真实规则结果与忌口检查').fontSize(17).fontWeight(FontWeight.Bold)
        ForEach(new AttentionEngine().rank(this.items,this.today,10),(decision:AttentionDecision)=>{
          Column({space:6}) {
            Text(this.items.find((i:Item)=>i.id===decision.itemId)?.name??decision.itemId).fontWeight(FontWeight.Bold)
            Text(`优先分 ${decision.score} · ${decision.reasonCodes.join(' / ')}`).fontSize(12)
            Text(ProfileDomain.advice(this.items.find((i:Item)=>i.id===decision.itemId)!,this.today,this.profile)).fontSize(13)
            Text(`建议检查：${SafetyGuard.evaluate(this.items.find((i:Item)=>i.id===decision.itemId)!,this.today,this.profile.allergies,this.profile.dislikes).reasonCodes.join(' / ')||'未命中拦截规则（不代表安全保证）'}`).fontSize(12).fontColor('#9B5C25')
            Text(`Mock 预测余量：${MockForecast.predict(this.items.find((i:Item)=>i.id===decision.itemId)!,this.today).projectedRemaining}，仅用于展示`).fontSize(12)
          }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(16)
        },(decision:AttentionDecision)=>decision.itemId)
        Text('最近的本机决策与反馈').fontSize(17).fontWeight(FontWeight.Bold)
        ForEach(this.decisions,(log:DecisionLog)=>{
          Text(`${log.version} · ${log.score} 分 · ${log.blocked?'拦截使用建议':'规则提示'}\n${log.reasons.join(' / ')}\n反馈：${log.feedback??'尚未处理'} · ${new Date(log.createdAt).toLocaleString()}`).fontSize(12).width('100%').padding(12).backgroundColor('#FFFFFF')
        },(log:DecisionLog)=>`${log.id}:${log.feedback??''}`)
      }.padding(20).width('100%')
    }.layoutWeight(1)
  }
}
