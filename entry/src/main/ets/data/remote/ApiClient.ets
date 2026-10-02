import { http } from '@kit.NetworkKit';

export class ApiClient {
  // 真机联调时请改成开发机局域网地址；模拟器场景按团队网络环境配置。
  static baseUrl: string = 'http://127.0.0.1:8080';

  static async health(): Promise<string> {
    const client = http.createHttp();
    try {
      const response = await client.request(`${ApiClient.baseUrl}/api/v1/health`, {
        method: http.RequestMethod.GET,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      return String(response.result);
    } finally {
      client.destroy();
    }
  }
}
