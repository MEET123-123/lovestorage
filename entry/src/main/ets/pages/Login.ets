import { ApiClient, AuthSession } from '../data/remote/ApiClient';
import { SessionManager } from '../data/SessionManager';
import { ItemLocalRepository } from '../data/local/ItemLocalRepository';

@Entry
@Component
struct Login {
  @State private method: number = 0;
  @State private register: boolean = false;
  @State private username: string = '';
  @State private password: string = '';
  @State private confirm: string = '';
  @State private phone: string = '';
  @State private code: string = '';
  @State private address: string = '';
  @State private message: string = '';
  @State private debugCode: string = '';
  @State private debug: boolean = false;
  @State private busy: boolean = true;
  @State private initialized: boolean = false;
  @State private countdown: number = 0;
  private timer: number = -1;
  aboutToAppear(): void { this.initialize(); }
  aboutToDisappear(): void { if (this.timer >= 0) clearInterval(this.timer); this.password = ''; this.confirm = ''; this.code = ''; }
  private async initialize(): Promise<void> {
    this.busy = true;
    try {
      if (SessionManager.active()) { await this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }); return; }
      await SessionManager.clear();
      const saved = await new ItemLocalRepository().getServer();
      this.address = saved || 'http://localhost:18081'; this.debug = !saved;
      this.initialized = true;
    } catch (error) { this.message = `初始化失败：${String(error)}`; }
    finally { this.busy = false; }
  }
  private async request(action: () => Promise<void>): Promise<void> {
    if (this.busy) return;
    this.busy = true; this.message = '';
    try {
      ApiClient.baseUrl = SessionManager.address(this.address); ApiClient.token = '';
      await action();
    } catch (error) { this.message = String(error); }
    finally { this.busy = false; }
  }
  private async finish(session: AuthSession): Promise<void> {
    await SessionManager.enter(session, ApiClient.baseUrl);
    this.password = ''; this.confirm = ''; this.code = ''; this.debugCode = '';
    await this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
  }
  private async login(): Promise<void> {
    await this.request(async () => {
      if (this.method === 0) {
        if (!/^[A-Za-z0-9_]{3,32}$/.test(this.username.trim())) throw new Error('用户名需为 3–32 位字母、数字或下划线');
        if (!this.password.trim() || this.password.length < 12 || this.password.length > 64) throw new Error('密码需为 12–64 个字符');
        if (this.register && this.password !== this.confirm) throw new Error('两次输入的密码不一致');
        await this.finish(await ApiClient.authenticate(this.username.trim(), this.password, this.register));
      } else if (this.method === 1) {
        if (!/^1[3-9]\d{9}$/.test(this.phone) || !/^\d{6}$/.test(this.code)) throw new Error('请输入有效手机号和 6 位验证码');
        await this.finish(await ApiClient.phoneLogin(this.phone, this.code));
      } else {
        const methods = await ApiClient.loginMethods();
        throw new Error(methods.huaweiMessage);
      }
    });
  }
  private async sendCode(): Promise<void> {
    await this.request(async () => {
      if (!/^1[3-9]\d{9}$/.test(this.phone)) throw new Error('请输入 11 位手机号');
      const result = await ApiClient.sendPhoneCode(this.phone);
      this.debugCode = result.mode === 'LOCAL_DEBUG' ? result.debugCode : '';
      this.message = result.mode === 'LOCAL_DEBUG' ? '本地调试验证码已生成，不会发送短信；手机号不代表已验证的真实身份。' : '验证码已发送';
      this.countdown = result.retryAfter;
      if (this.timer >= 0) clearInterval(this.timer);
      this.timer = setInterval(() => { if (this.countdown > 0) this.countdown--; else { clearInterval(this.timer); this.timer = -1; } }, 1000);
    });
  }
  private async checkServer(): Promise<void> {
    await this.request(async () => {
      await ApiClient.health();
      await new ItemLocalRepository().setSetting('server', ApiClient.baseUrl);
      const methods = await ApiClient.loginMethods();
      this.message = `连接成功。手机号：${methods.phoneMode === 'LOCAL_DEBUG' ? '本地验证码调试' : '未配置短信服务'}；华为登录：${methods.huaweiEnabled ? '可用' : '待配置'}`;
    });
  }
  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 12 }) {
          Text('🌿').fontSize(48).width(90).height(90).textAlign(TextAlign.Center).backgroundColor('#DFECDC').borderRadius(30)
          Text('好物有期').fontSize(34).fontWeight(FontWeight.Bold).fontColor('#223D31')
          Text('登录，开启你的好物管理生活').fontSize(14).fontColor('#748078')
        }.width('100%').margin({ top: 36, bottom: 12 })
        Row({ space: 8 }) {
          ForEach(['账号密码', '手机号', '华为账号'], (label: string, index: number) => {
            Button(label).fontSize(13).layoutWeight(1).backgroundColor(this.method === index ? '#28785C' : '#FFFFFF').fontColor(this.method === index ? '#FFFFFF' : '#63766D')
              .enabled(!this.busy).onClick(() => { this.method = index; this.message = ''; this.password = ''; this.confirm = ''; })
          })
        }.width('100%')
        Column({ space: 16 }) {
          if (this.method === 0) {
            Text(this.register ? '创建新账号' : '欢迎回来').fontSize(23).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
            TextInput({ text: this.username, placeholder: '用户名（3–32 位字母、数字、下划线）' }).height(50).maxLength(32).enabled(!this.busy).onChange((v: string) => { this.username = v; })
            TextInput({ text: this.password, placeholder: '密码（12–64 个字符）' }).height(50).type(InputType.Password).maxLength(64).enabled(!this.busy).onChange((v: string) => { this.password = v; })
            if (this.register) {
              TextInput({ text: this.confirm, placeholder: '再次输入密码' }).height(50).type(InputType.Password).maxLength(64).enabled(!this.busy).onChange((v: string) => { this.confirm = v; })
            }
          } else if (this.method === 1) {
            Text('手机号登录').fontSize(23).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
            Text('当前支持本地验证码调试，不发送真实短信。首次登录会创建独立调试账号。').fontSize(12).fontColor('#9B6B31')
            TextInput({ text: this.phone, placeholder: '11 位手机号' }).height(50).maxLength(11).type(InputType.PhoneNumber).enabled(!this.busy).onChange((v: string) => { this.phone = v; this.debugCode = ''; this.code = ''; })
            Row({ space: 8 }) {
              TextInput({ text: this.code, placeholder: '6 位验证码' }).layoutWeight(1).maxLength(6).type(InputType.Number).enabled(!this.busy).onChange((v: string) => { this.code = v; })
              Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码').fontSize(12).enabled(!this.busy && this.countdown === 0 && this.initialized).onClick(() => this.sendCode())
            }
            if (this.debugCode) { Text(`本地调试验证码：${this.debugCode}（5 分钟内有效）`).fontSize(13).fontColor('#9B6B31') }
          } else {
            Text('华为账号登录').fontSize(23).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
            Text('使用华为账号授权登录').fontSize(15).fontColor('#63766D')
            Text('当前未配置华为开发者应用与签名，暂不能完成真实授权。可先使用账号密码或手机号本地调试。').fontSize(13).fontColor('#9B6B31').lineHeight(22)
          }
          Button(this.busy ? '处理中…' : this.method === 2 ? '检查华为登录配置' : this.register && this.method === 0 ? '注册并进入首页' : '登录并进入首页')
            .width('100%').height(50).backgroundColor('#28785C').enabled(!this.busy && this.initialized).onClick(() => this.login())
          if (this.method === 0) {
            Text(this.register ? '已有账号？去登录' : '还没有账号？立即注册').fontSize(14).fontColor('#28785C').onClick(() => { if (!this.busy) { this.register = !this.register; this.confirm = ''; this.message = ''; } })
          }
        }.padding(22).width('100%').backgroundColor('#FFFFFF').borderRadius(24)
        if (this.message) { Text(this.message).fontSize(13).fontColor('#9B5931').width('100%').lineHeight(21) }
        if (!this.initialized && !this.busy) { Button('重新初始化').onClick(() => this.initialize()) }
        Text(this.debug ? '收起本地接口调试 ⌃' : '本地接口调试 ⌄').fontSize(13).fontColor('#748078').onClick(() => { this.debug = !this.debug; })
        if (this.debug) {
          Column({ space: 10 }) {
            TextInput({ text: this.address, placeholder: 'http://电脑局域网IP:18081' }).enabled(!this.busy).onChange((v: string) => { this.address = v; })
            Text('模拟器和真机需填写可访问的电脑地址。切换后端会使用该服务的账号数据。').fontSize(11).fontColor('#748078')
            Button('保存地址并测试连接').enabled(!this.busy && this.initialized).onClick(() => this.checkServer())
          }.padding(16).backgroundColor('#E7EEE4').borderRadius(18)
        }
      }.padding({ left: 24, right: 24, top: 28, bottom: 40 }).width('100%')
    }.height('100%').width('100%').backgroundColor('#F4F6F0').scrollBar(BarState.Off)
  }
}
