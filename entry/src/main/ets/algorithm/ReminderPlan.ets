import { Item } from '../domain/Item';
import { InventoryDomain } from './InventoryDomain';

export interface PlannedReminder { itemId: string; name: string; expiry: string; at: number; }
export class ReminderPlan {
  static create(items: Item[], now: number, hour: number = 9): PlannedReminder[] {
    if(!Number.isInteger(hour) || hour<8 || hour>21) throw new Error('提醒时段需为 08:00–21:00');
    const plans: PlannedReminder[] = [];
    for (const item of items) {
      if (item.lifecycleStatus !== 'ACTIVE' || item.deletedAt !== undefined) continue;
      const effective = InventoryDomain.evaluate(item).effectiveExpiryDate;
      if (effective === undefined || !InventoryDomain.validDate(effective)) continue;
      const offsets: number[] = item.reminderDays !== undefined ? [item.reminderDays] : item.categoryId === 'cosmetics' ? [30,7,1] : item.categoryId === 'pet_food' ? [14,7,3] : [7,3,1];
      const scheduled: number[]=[];
      for (const offset of offsets) {
      const date = new Date(`${effective}T${`${hour}`.padStart(2,'0')}:00:00`);
      date.setDate(date.getDate() - offset);
      if (item.snoozeUntil && InventoryDomain.validDate(item.snoozeUntil)) {
        const snooze = new Date(`${item.snoozeUntil}T${`${hour}`.padStart(2,'0')}:00:00`);
        if (snooze.getTime() > date.getTime()) date.setTime(snooze.getTime());
      }
      // Past reminders stay in the in-app list; do not repeatedly notify on every launch.
      if (date.getTime() > now && !scheduled.includes(date.getTime())) { scheduled.push(date.getTime()); plans.push({ itemId: item.id, name: item.name, expiry: effective, at: date.getTime() }); }
      }
    }
    return plans.sort((a: PlannedReminder, b: PlannedReminder) => a.at - b.at);
  }
}
