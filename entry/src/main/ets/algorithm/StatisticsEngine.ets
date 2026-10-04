import { ConsumptionRecord } from '../domain/Item';
export interface HandlingSummary { consumed: number; partial: number; discarded: number; useRate: number; }
export class StatisticsEngine {
  static records(records: ConsumptionRecord[], today: string, period: number): ConsumptionRecord[] {
    const start=new Date(`${today}T00:00:00`);start.setDate(start.getDate()-Math.max(1,period)+1);
    const end=new Date(`${today}T00:00:00`);end.setDate(end.getDate()+1);
    return records.filter((r:ConsumptionRecord)=>r.revoked===0 && ['CONSUMED','PARTIAL_CONSUMED','DISCARDED'].includes(r.action) && r.createdAt<end.getTime() && (period===0 || r.createdAt>=start.getTime()))
      .sort((a:ConsumptionRecord,b:ConsumptionRecord)=>b.createdAt-a.createdAt);
  }
  static summary(records: ConsumptionRecord[]): HandlingSummary {
    const consumed=records.filter((r:ConsumptionRecord)=>r.action==='CONSUMED').length;
    const partial=records.filter((r:ConsumptionRecord)=>r.action==='PARTIAL_CONSUMED').length;
    const discarded=records.filter((r:ConsumptionRecord)=>r.action==='DISCARDED').length;
    return {consumed,partial,discarded,useRate:consumed+partial+discarded===0?0:Math.round((consumed+partial)*100/(consumed+partial+discarded))};
  }
}
