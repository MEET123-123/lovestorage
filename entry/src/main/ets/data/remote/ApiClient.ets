import { http } from '@kit.NetworkKit';
import { Item } from '../../domain/Item';

interface Envelope { code: number; message: string; }
interface ItemPayload {
  clientId: string;
  name: string;
  categoryId: string;
  expiryDate?: string;
  lifecycleStatus: string;
}

export class ApiClient {
  static baseUrl: string = '';

  static async request(path: string, method: http.RequestMethod, payload?: ItemPayload): Promise<string> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${ApiClient.baseUrl}/api/v1${path}`, {
        method, header: { 'Content-Type': 'application/json' },
        extraData: payload === undefined ? '' : JSON.stringify(payload),
        connectTimeout: 5000, readTimeout: 10000
      });
      if (method === http.RequestMethod.DELETE && response.responseCode === 404) return '';
      const text = String(response.result);
      const envelope = JSON.parse(text) as Envelope;
      if (response.responseCode < 200 || response.responseCode >= 300 || envelope.code !== 0) {
        throw new Error(envelope.message ?? `HTTP ${response.responseCode}`);
      }
      return text;
    } finally { client.destroy(); }
  }

  static async health(): Promise<string> { return ApiClient.request('/health', http.RequestMethod.GET); }

  static async upload(item: Item, remoteId: string): Promise<void> {
    if (item.deletedAt !== undefined) {
      await ApiClient.request(`/items/${remoteId}`, http.RequestMethod.DELETE);
      return;
    }
    const payload: ItemPayload = {
      clientId: remoteId, name: item.name, categoryId: item.categoryId,
      expiryDate: item.expiryDate, lifecycleStatus: item.lifecycleStatus
    };
    // Stable client ID makes retry safe. PUT alias works on HarmonyOS API 20.
    await ApiClient.request('/items', http.RequestMethod.POST, payload);
    await ApiClient.request(`/items/${remoteId}`, http.RequestMethod.PUT, payload);
    await ApiClient.request(`/items/${remoteId}`, http.RequestMethod.GET);
  }
}
