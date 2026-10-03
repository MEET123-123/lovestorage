import { Item } from './Item';
import { InventoryDomain } from './InventoryDomain';

export interface PlannedReminder { itemId: string; name: string; expiry: string; at: number; }
export class ReminderPlan {
  static create(items: Item[], now: number): PlannedReminder[] {
    const plans: PlannedReminder[] = [];
    for (const item of items) {
      if (item.lifecycleStatus !== 'ACTIVE' || item.deletedAt !== undefined) continue;
      const effective = InventoryDomain.evaluate(item).effectiveExpiryDate;
      if (effective === undefined || !InventoryDomain.validDate(effective)) continue;
      const date = new Date(`${effective}T09:00:00`);
      date.setDate(date.getDate() - (item.reminderDays ?? InventoryDomain.category(item.categoryId).days));
      if (item.snoozeUntil && InventoryDomain.validDate(item.snoozeUntil)) {
        const snooze = new Date(`${item.snoozeUntil}T09:00:00`);
        if (snooze.getTime() > date.getTime()) date.setTime(snooze.getTime());
      }
      // Past reminders stay in the in-app list; do not repeatedly notify on every launch.
      if (date.getTime() > now) plans.push({ itemId: item.id, name: item.name, expiry: effective, at: date.getTime() });
    }
    return plans.sort((a: PlannedReminder, b: PlannedReminder) => a.at - b.at);
  }
}
