import { http } from '@kit.NetworkKit';
import { Item } from '../../domain/Item';
import { ExpiryService, ShelfLifeUnit } from '../../algorithm/ExpiryService';
import { UserProfile } from '../../domain/UserProfile';
import { SyncWrite, RemoteSnapshot } from '../../domain/Sync';
import { PendingEvent } from '../local/LocalEvents';
interface SnapshotEnvelope { data: RemoteSnapshot; }
interface SnapshotsEnvelope { data: RemoteSnapshot[]; }
interface EventBatch { events: PendingEvent[]; }
export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) { super(message); this.status = status; }
}

interface Envelope { code: number; message: string; }
export interface Account { id: string; username: string; }
export interface AuthSession { accessToken: string; expiresAt: string; user: Account; }
interface AuthEnvelope { data: AuthSession; }
interface Credentials { username: string; password: string; }
interface PasswordChange { currentPassword: string; newPassword: string; }
interface BackupPayload { expectedRevision: number; payload: string; }
export interface CloudBackup { revision: number; payload: string; updatedAt: string; }
interface BackupEnvelope { data: CloudBackup; }
export interface LoginMethods { phoneMode: string; huaweiEnabled: boolean; huaweiMessage: string; }
export interface PhoneCode { mode: string; debugCode: string; expiresIn: number; retryAfter: number; }
interface PhonePayload { phone: string; code?: string; }
interface PhoneEnvelope { data: PhoneCode; }
interface MethodsEnvelope { data: LoginMethods; }
interface ProfileEnvelope { data: UserProfile; }
interface ItemPayload {
  clientId: string;
  name: string;
  categoryId: string;
  expiryDate?: string;
  lifecycleStatus: string;
  quantity: number;
  unit: string;
}

export class ApiClient {
  static baseUrl: string = '';
  static token: string = '';

  static async request(path: string, method: http.RequestMethod, payload?: ItemPayload | Credentials | PasswordChange | BackupPayload | PhonePayload | UserProfile | SyncWrite | EventBatch): Promise<string> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${ApiClient.baseUrl}/api/v1${path}`, {
        method, header: { 'Content-Type': 'application/json', 'Authorization': ApiClient.token ? `Bearer ${ApiClient.token}` : '' },
        extraData: payload === undefined ? '' : JSON.stringify(payload),
        connectTimeout: 5000, readTimeout: 10000
      });
      if (method === http.RequestMethod.DELETE && response.responseCode === 404) return '';
      const text = String(response.result);
      const envelope = JSON.parse(text) as Envelope;
      if (response.responseCode === 401) { ApiClient.token = ''; throw new Error(envelope.message || '登录已失效，请重新登录'); }
      if (response.responseCode < 200 || response.responseCode >= 300 || envelope.code !== 0) {
        throw new ApiError(envelope.message ?? `HTTP ${response.responseCode}`, response.responseCode);
      }
      return text;
    } finally { client.destroy(); }
  }

  static async health(): Promise<string> { return ApiClient.request('/health', http.RequestMethod.GET); }
  static async syncList(): Promise<RemoteSnapshot[]> { return (JSON.parse(await ApiClient.request('/sync/inventory', http.RequestMethod.GET)) as SnapshotsEnvelope).data; }
  static async syncGet(id: string): Promise<RemoteSnapshot> { return (JSON.parse(await ApiClient.request(`/sync/inventory/${id}`, http.RequestMethod.GET)) as SnapshotEnvelope).data; }
  static async syncPut(id: string, value: SyncWrite): Promise<RemoteSnapshot> { return (JSON.parse(await ApiClient.request(`/sync/inventory/${id}`, http.RequestMethod.PUT, value)) as SnapshotEnvelope).data; }
  static async sendEvents(events: PendingEvent[]): Promise<void> { const body: EventBatch = { events }; await ApiClient.request('/events', http.RequestMethod.POST, body); }
  static async loginMethods(): Promise<LoginMethods> {
    return (JSON.parse(await ApiClient.request('/auth/methods', http.RequestMethod.GET)) as MethodsEnvelope).data;
  }
  static async sendPhoneCode(phone: string): Promise<PhoneCode> {
    const payload: PhonePayload = { phone };
    return (JSON.parse(await ApiClient.request('/auth/phone/code', http.RequestMethod.POST, payload)) as PhoneEnvelope).data;
  }
  static async phoneLogin(phone: string, code: string): Promise<AuthSession> {
    const payload: PhonePayload = { phone, code };
    return (JSON.parse(await ApiClient.request('/auth/phone/login', http.RequestMethod.POST, payload)) as AuthEnvelope).data;
  }
  static async getProfile(): Promise<UserProfile> {
    return (JSON.parse(await ApiClient.request('/profile', http.RequestMethod.GET)) as ProfileEnvelope).data;
  }
  static async saveProfile(profile: UserProfile): Promise<UserProfile> {
    return (JSON.parse(await ApiClient.request('/profile', http.RequestMethod.PUT, profile)) as ProfileEnvelope).data;
  }

  static async authenticate(username: string, password: string, register: boolean): Promise<AuthSession> {
    const payload: Credentials = { username, password };
    const response = JSON.parse(await ApiClient.request(register ? '/auth/register' : '/auth/login', http.RequestMethod.POST, payload)) as AuthEnvelope;
    return response.data;
  }
  static async logout(): Promise<void> {
    try { if (ApiClient.token) await ApiClient.request('/auth/logout', http.RequestMethod.POST); }
    finally { ApiClient.token = ''; }
  }
  static async changePassword(currentPassword: string, newPassword: string): Promise<void> {
    const payload: PasswordChange = { currentPassword, newPassword };
    await ApiClient.request('/auth/password', http.RequestMethod.POST, payload);
    ApiClient.token = '';
  }
  static async backup(payload: string, expectedRevision: number): Promise<CloudBackup> {
    const body: BackupPayload = { payload, expectedRevision };
    return (JSON.parse(await ApiClient.request('/backup', http.RequestMethod.PUT, body)) as BackupEnvelope).data;
  }
  static async fetchBackup(): Promise<CloudBackup> {
    return (JSON.parse(await ApiClient.request('/backup', http.RequestMethod.GET)) as BackupEnvelope).data;
  }

  static async upload(item: Item, remoteId: string): Promise<void> {
    if (item.deletedAt !== undefined) {
      await ApiClient.request(`/items/${remoteId}`, http.RequestMethod.DELETE);
      return;
    }
    const payload: ItemPayload = {
      clientId: remoteId, name: item.name, categoryId: item.categoryId,
      expiryDate: new ExpiryService().effectiveExpiryDate(item.expiryDate, item.openedDate, item.afterOpenValue, item.afterOpenUnit as ShelfLifeUnit | undefined),
      lifecycleStatus: item.lifecycleStatus, quantity: item.quantity ?? 1, unit: item.unit ?? '件'
    };
    // Stable client ID makes retry safe. PUT alias works on HarmonyOS API 20.
    await ApiClient.request('/items', http.RequestMethod.POST, payload);
    await ApiClient.request(`/items/${remoteId}`, http.RequestMethod.PUT, payload);
    await ApiClient.request(`/items/${remoteId}`, http.RequestMethod.GET);
  }
}
