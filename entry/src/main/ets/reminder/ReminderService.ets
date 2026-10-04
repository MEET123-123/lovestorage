import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { Item } from '../domain/Item';
import { ReminderPlan } from '../algorithm/ReminderPlan';

export class ReminderService {
  private static context?: common.UIAbilityContext;
  static initialize(context: common.UIAbilityContext): void { ReminderService.context = context; }
  static async enable(): Promise<void> {
    if (!ReminderService.context) throw new Error('应用尚未初始化');
    await notificationManager.requestEnableNotification(ReminderService.context);
  }
  static async clear(): Promise<void> { await reminderAgentManager.cancelAllReminders(); }
  static async rebuild(items: Item[], hour: number = 9): Promise<string> {
    const plans = ReminderPlan.create(items, Date.now(),hour);
    await reminderAgentManager.cancelAllReminders();
    let count = 0;
    for (const plan of plans.slice(0, 20)) {
      const date = new Date(plan.at);
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(), hour: date.getHours(), minute: date.getMinutes() },
        title: '好物有期 · 到期提醒', content: `${plan.name} 的有效到期日为 ${plan.expiry}，记得查看并处理。`,
        notificationId: 1000 + count, ringDuration: 0,
        wantAgent: { pkgName: 'com.smartexpiry.app', abilityName: 'EntryAbility' }
      };
      try { await reminderAgentManager.publishReminder(request); count++; }
      catch (error) { throw new Error(`仅注册 ${count} 条，剩余未完成：${String(error)}`); }
    }
    return `已注册 ${count} 条未来提醒${plans.length > 20 ? '（优先最近 20 条，打开应用时更新）' : ''}；已错过时刻的物品请查看首页。`;
  }
}
