import { SectionTitle } from '../components/InventoryComponents';

@Component
export struct ProfilePanel {
  @Prop server: string = '';
  @Prop pending: number = 0;
  @Prop busy: boolean = false;
  @Prop reminderEnabled: boolean = false;
  @Prop reminderStatus: string = '';
  @Prop lastSync: string = '';
  @State private address: string = '';
  onSaveServer: (url: string) => void = () => {};
  onSync: (url: string) => void = () => {};
  onStats: () => void = () => {};
  onReminder: (enable: boolean) => void = () => {};
  aboutToAppear(): void { this.address = this.server; }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        SectionTitle({ title: '我的好物管家', subtitle: '记录留在本机，连接让备份更方便' })
        Row({ space: 14 }) {
          Text('好').fontSize(28).fontColor('#28785C').width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#DFECDC').borderRadius(20)
          Column({ space: 6 }) {
            Text('本地使用模式').fontSize(20).fontWeight(FontWeight.Medium).fontColor('#223D31')
            Text('无需登录，核心功能离线可用').fontSize(12).fontColor('#748078')
          }.alignItems(HorizontalAlign.Start)
        }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(20)
        Button('查看库存与使用统计 ›').width('100%').height(50).backgroundColor('#E5EEDD').fontColor('#28785C').onClick(this.onStats)
        Column({ space: 12 }) {
          Row() {
            Text('系统到期提醒').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#223D31').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled }).selectedColor('#28785C').enabled(!this.busy)
              .onChange((enabled: boolean) => { if (enabled !== this.reminderEnabled) this.onReminder(enabled); })
          }.width('100%')
          Text('在到期前指定天数的上午 09:00 提醒。设备授权和代理提醒能力可用后才会注册。').fontSize(12).fontColor('#748078').width('100%')
          Text(this.reminderStatus || '未启用系统提醒；首页的到期待办仍可使用。').fontSize(12).fontColor('#28785C').width('100%')
          if (this.reminderEnabled) { Button('重新检查并注册').fontSize(12).backgroundColor('#E5EEDD').fontColor('#28785C').enabled(!this.busy).onClick(() => this.onReminder(true)) }
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Column({ space: 12 }) {
          Row() {
            Text('连接与备份').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#223D31').layoutWeight(1)
            Text(`${this.pending} 条待上传`).fontSize(12).fontColor('#AC6A27')
          }.width('100%')
          TextInput({ text: this.address, placeholder: 'http://电脑局域网IP:18080' }).height(46).onChange((v: string) => { this.address = v; }).enabled(!this.busy)
          Row({ space: 10 }) {
            Button('保存地址').layoutWeight(1).backgroundColor('#F0F4EE').fontColor('#28785C').enabled(!this.busy).onClick(() => this.onSaveServer(this.address))
            Button(this.busy ? '处理中…' : '同步上传').layoutWeight(1).backgroundColor('#28785C').enabled(!this.busy).onClick(() => this.onSync(this.address))
          }
          Text(this.lastSync ? `最近成功上传：${this.lastSync}` : '尚未完成上传').fontSize(11).fontColor('#748078').width('100%')
          Text('真机请填电脑的局域网地址。当前上传名称、分类、数量、单位、有效到期日和状态；备注、开封原始信息、流水和补货清单仅保存在本机。暂不支持多设备合并。')
            .fontSize(11).fontColor('#748078').lineHeight(18).width('100%')
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Column({ space: 10 }) {
          Text('录入能力').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
          Text('已提供：手动录入、包装文字辅助提取。').fontSize(13).fontColor('#28785C').width('100%')
          Text('相机 OCR、语音识别、条码和云端 AI 尚未接入。当前建议由本地规则产生。').fontSize(12).fontColor('#748078').width('100%')
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Text('好物有期 · 本地数据增强版').fontSize(11).fontColor('#9AA69D').padding({ bottom: 12 })
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
