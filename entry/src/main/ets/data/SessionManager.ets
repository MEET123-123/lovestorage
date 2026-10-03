import { ApiClient, AuthSession } from './remote/ApiClient';
import { AppDatabase } from './local/AppDatabase';
import { ItemLocalRepository } from './local/ItemLocalRepository';
import { ReminderService } from '../reminder/ReminderService';

export class SessionManager {
  static current?: AuthSession;
  static server: string = '';
  static active(): boolean {
    return SessionManager.current !== undefined && ApiClient.token === SessionManager.current.accessToken && ApiClient.token !== '' &&
      ApiClient.baseUrl === SessionManager.server && Date.parse(SessionManager.current.expiresAt) > Date.now();
  }
  static address(url: string): string {
    const value = url.trim().replace(/\/+$/, '');
    if (!/^https?:\/\/[^\s/?#]+$/.test(value)) throw new Error('请输入后端地址，如 http://192.168.1.10:18081');
    return value;
  }
  static async enter(session: AuthSession, url: string): Promise<void> {
    const repo = new ItemLocalRepository();
    await repo.setSetting('server', url);
    // Reminder permission must never prevent authentication or sign-out.
    try { await ReminderService.clear(); } catch (ignored) {}
    await AppDatabase.switchAccount(session.user.id);
    await repo.setServer(url);
    SessionManager.current = session; SessionManager.server = url;
    ApiClient.baseUrl = url; ApiClient.token = session.accessToken;
  }
  static async clear(): Promise<void> {
    SessionManager.current = undefined; SessionManager.server = ''; ApiClient.token = '';
    try { await ReminderService.clear(); } catch (ignored) {}
    await AppDatabase.switchAccount();
  }
}
