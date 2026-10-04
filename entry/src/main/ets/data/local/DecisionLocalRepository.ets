import { util } from '@kit.ArkTS';
import { AppDatabase } from './AppDatabase';
import { LocalEvents, EventProperties } from './LocalEvents';
import { TodayCard } from '../../viewmodel/TodayViewModel';
export interface DecisionLog { id: string; itemId: string; version: string; score: number; reasons: string[]; blocked: boolean; createdAt: number; feedback?: string; }
export class DecisionLocalRepository {
  async record(cards: TodayCard[], today: string): Promise<void> {
    const store=await AppDatabase.getStore();
    store.beginTransaction();
    try {
      for (const card of cards.slice(0,10)) {
        const reasons=card.decision.reasonCodes.concat(card.safety.reasonCodes);
        const key=`${card.item.id}:${card.item.updatedAt}:${today}:${card.decision.ruleVersion}:${card.decision.score}:${reasons.join(',')}`;
        const found=await store.querySql('SELECT id FROM algorithm_decision WHERE decision_key=?',[key]);
        let exists=false;try { exists=found.goToFirstRow(); } finally { found.close(); }
        if(exists) continue;
        const log: DecisionLog={id:util.generateRandomUUID(),itemId:card.item.id,version:card.decision.ruleVersion,score:card.decision.score,reasons,blocked:card.safety.blocked,createdAt:Date.now()};
        await store.executeSql('INSERT INTO algorithm_decision(id,decision_key,item_id,payload,created_at) VALUES (?,?,?,?,?)',[log.id,key,log.itemId,JSON.stringify(log),log.createdAt]);
        const properties: EventProperties={itemId:log.itemId,decisionId:log.id,algorithmVersion:log.version,score:log.score,remainingDays:card.decision.remainingDays,opened:card.item.openedDate!==undefined,reasonCodes:log.reasons,mock:(card.item.sourceMode??'').startsWith('MOCK')};
        await LocalEvents.appendProperties(store,'DECISION_SHOWN',properties);
      }
      store.commit();
    } catch(error) { store.rollBack(); throw new Error(String(error)); }
  }
  async feedback(itemId: string, action: string): Promise<void> {
    if(!['CONSUMED','DISCARDED','SNOOZE','UNDO','NOT_HELPFUL'].includes(action)) throw new Error('反馈类型无效');
    const store=await AppDatabase.getStore();
    store.beginTransaction();
    try {
      const rs=await store.querySql('SELECT id,payload FROM algorithm_decision WHERE item_id=? ORDER BY created_at DESC,rowid DESC LIMIT 1',[itemId]);
      let log: DecisionLog|undefined;
      try { if(rs.goToFirstRow()) log=JSON.parse(rs.getString(1)) as DecisionLog; } finally { rs.close(); }
      if(log) {
        await store.executeSql('UPDATE algorithm_decision SET feedback=?,feedback_at=? WHERE id=?',[action,Date.now(),log.id]);
        await LocalEvents.appendProperties(store,'DECISION_FEEDBACK',{itemId,decisionId:log.id,algorithmVersion:log.version,action});
      }
      store.commit();
    } catch(error) { store.rollBack(); throw new Error(String(error)); }
  }
  async list(): Promise<DecisionLog[]> {
    const rs=await (await AppDatabase.getStore()).querySql('SELECT payload,feedback FROM algorithm_decision ORDER BY created_at DESC,rowid DESC LIMIT 20');
    const rows: DecisionLog[]=[];
    try { while(rs.goToNextRow()) { const log=JSON.parse(rs.getString(0)) as DecisionLog;log.feedback=rs.isColumnNull(1)?undefined:rs.getString(1); rows.push(log); } } finally { rs.close(); }
    return rows;
  }
}
