import { relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { AppDatabase } from './AppDatabase';
export interface EventProperties { itemId: string; batchId?: string; quantity?: number; decisionId?: string; algorithmVersion?: string; action?: string; score?: number; remainingDays?: number; opened?: boolean; reasonCodes?: string[]; mock?: boolean; }
export interface PendingEvent { eventId: string; eventType: string; eventVersion: string; occurredAt: string; properties: EventProperties; }
export class LocalEvents {
  static async append(store: relationalStore.RdbStore, type: string, itemId: string, batchId?: string, quantity?: number): Promise<void> {
    const properties: EventProperties = { itemId, batchId, quantity };
    await LocalEvents.appendProperties(store,type,properties);
  }
  static async appendProperties(store: relationalStore.RdbStore,type: string,properties: EventProperties): Promise<void> {
    await store.executeSql('INSERT INTO local_event_outbox(event_id,event_type,occurred_at,properties) VALUES (?,?,?,?)',
      [util.generateRandomUUID(),type,Date.now(),JSON.stringify(properties)]);
  }
  static async pending(): Promise<PendingEvent[]> {
    const store = await AppDatabase.getStore();
    const rs = await store.querySql('SELECT event_id,event_type,occurred_at,properties FROM local_event_outbox WHERE pending=1 ORDER BY occurred_at LIMIT 100');
    const events: PendingEvent[] = [];
    try { while (rs.goToNextRow()) events.push({ eventId: rs.getString(0), eventType: rs.getString(1), eventVersion: '1.0',
      occurredAt: new Date(rs.getLong(2)).toISOString(), properties: JSON.parse(rs.getString(3)) as EventProperties }); }
    finally { rs.close(); }
    return events;
  }
  static async acknowledge(events: PendingEvent[]): Promise<void> {
    const store = await AppDatabase.getStore();
    for (const event of events) await store.executeSql('UPDATE local_event_outbox SET pending=0 WHERE event_id=?',[event.eventId]);
  }
}
