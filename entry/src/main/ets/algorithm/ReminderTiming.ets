import { ConsumptionRecord } from '../domain/Item';
export interface TimingRecommendation { hour: number; sampleCount: number; activeDays: number; source: string; explanation: string; }
export class ReminderTiming {
  static recommend(records: ConsumptionRecord[], now: number): TimingRecommendation {
    const bins: number[]=new Array<number>(24).fill(0); const days: string[]=[];let count=0;
    for (const record of records) {
      if (record.revoked!==0 || !['CONSUMED','PARTIAL_CONSUMED'].includes(record.action) || record.createdAt>now || record.createdAt<now-90*86400000) continue;
      const date=new Date(record.createdAt),hour=date.getHours(); if(hour<8 || hour>21) continue;
      bins[hour]++;count++;const day=date.toDateString();if(!days.includes(day)) days.push(day);
    }
    if(count<5 || days.length<3) return {hour:9,sampleCount:count,activeDays:days.length,source:'FALLBACK',explanation:'近 90 天可用处理记录不足 5 次或不足 3 天，使用默认 09:00'};
    let best=9;for(let hour=8;hour<=21;hour++) if(bins[hour]>bins[best] || bins[hour]===bins[best] && Math.abs(hour-9)<Math.abs(best-9)) best=hour;
    return {hour:best,sampleCount:count,activeDays:days.length,source:'HISTORY_RULE',explanation:`根据 ${days.length} 天内 ${count} 条有效处理记录，推荐 ${best}:00；只在你确认后应用`};
  }
}
