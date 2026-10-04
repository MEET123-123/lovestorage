import { SectionTitle } from '../components/InventoryComponents';
import { UserProfile, ProfileDomain } from '../domain/UserProfile';

@Component
export struct ProfilePanel {
  @Prop profile: UserProfile = ProfileDomain.empty();
  onEditProfile: () => void = () => {};
  onCheckServer: () => void = () => {};
  @Prop server: string = '';
  @Prop pending: number = 0;
  @Prop busy: boolean = false;
  @Prop reminderEnabled: boolean = false;
  @Prop reminderStatus: string = '';
  @Prop lastSync: string = '';
  @Prop accountName: string = '';
  @State private address: string = '';
  onSaveServer: (url: string) => void = () => {};
  onSync: (url: string) => void = () => {};
  onStats: () => void = () => {};
  onReminder: (enable: boolean) => void = () => {};
  onLogout: () => void = () => {};
  onBackup: () => void = () => {};
  onRestore: () => void = () => {};
  onConflicts: () => void = () => {};
  onAlgorithms: () => void = () => {};
  @Prop conflictCount: number = 0;
  aboutToAppear(): void { this.address = this.server; }
  build() {
    Scroll() {
      Column({ space: 18 }) {
        SectionTitle({ title: '我的', subtitle: '让好物管理更符合你的日常习惯' })
        Row({ space: 14 }) {
          Text(ProfileDomain.avatar(this.profile.avatarKey).symbol).fontSize(32).fontColor('#28785C').width(58).height(58).textAlign(TextAlign.Center).backgroundColor('#DFECDC').borderRadius(20)
          Column({ space: 6 }) {
            Text(this.profile.displayName || this.accountName).fontSize(20).fontWeight(FontWeight.Medium).fontColor('#223D31')
            Text(this.profile.bio || '记录好物，让喜爱不被浪费').fontSize(12).fontColor('#748078')
          }.alignItems(HorizontalAlign.Start)
        }.padding(18).width('100%').backgroundColor('#FFFFFF').borderRadius(20)
        Button('编辑头像、昵称与个人资料 ›').width('100%').height(46).backgroundColor('#28785C').enabled(!this.busy).onClick(this.onEditProfile)
        Column({ space: 14 }) {
          Text('我的饮食档案').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#223D31').width('100%')
          Text('需要避开：' + (this.profile.allergies.join('、') || '尚未设置')).fontSize(14).fontColor('#63766D').width('100%')
          Text('不喜欢的：' + (this.profile.dislikes.join('、') || '尚未设置')).fontSize(14).fontColor('#63766D').width('100%')
          Text('日常偏好：' + (this.profile.preferences.join('、') || '尚未设置')).fontSize(14).fontColor('#63766D').width('100%')
          Text('建议按名称与备注匹配忌口，未命中不代表不含相关配料。').fontSize(11).fontColor('#9B6B31')
          Button('设置忌口与偏好').backgroundColor('#E5EEDD').fontColor('#28785C').enabled(!this.busy).onClick(this.onEditProfile)
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Column({ space: 12 }) {
          Text('数据备份').fontSize(17).fontColor('#223D31').width('100%')
          Button('备份全部库存与记录').width('100%').enabled(!this.busy).onClick(this.onBackup)
          Button('从云端恢复到空库存').width('100%').enabled(!this.busy).onClick(this.onRestore)
          Text('个人资料单独保存到账号，库存快照包含物品、原始日期、备注、流水与补货清单。').fontSize(11).fontColor('#748078')
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Button('查看库存与使用统计 ›').width('100%').height(50).backgroundColor('#E5EEDD').fontColor('#28785C').onClick(this.onStats)
        Column({ space: 12 }) {
          Row() {
            Text('系统到期提醒').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#223D31').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled }).selectedColor('#28785C').enabled(!this.busy)
              .onChange((enabled: boolean) => { if (enabled !== this.reminderEnabled) this.onReminder(enabled); })
          }.width('100%')
          Text('按分类多节点策略在上午 09:00 提醒；自定义提前天数优先。设备授权后才会注册。').fontSize(12).fontColor('#748078').width('100%')
          Text(this.reminderStatus || '未启用系统提醒；首页的到期待办仍可使用。').fontSize(12).fontColor('#28785C').width('100%')
          if (this.reminderEnabled) { Button('重新检查并注册').fontSize(12).backgroundColor('#E5EEDD').fontColor('#28785C').enabled(!this.busy).onClick(() => this.onReminder(true)) }
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Column({ space: 12 }) {
          Row() {
            Text('本地接口调试').fontSize(17).fontWeight(FontWeight.Medium).fontColor('#223D31').layoutWeight(1)
            Text(`${this.pending} 条待上传`).fontSize(12).fontColor('#AC6A27')
          }.width('100%')
          TextInput({ text: this.address, placeholder: 'http://电脑局域网IP:18081' }).height(46).onChange((v: string) => { this.address = v; }).enabled(!this.busy)
          Row({ space: 10 }) {
            Button('保存地址').layoutWeight(1).backgroundColor('#F0F4EE').fontColor('#28785C').enabled(!this.busy).onClick(() => this.onSaveServer(this.address))
            Button(this.busy ? '处理中…' : '同步上传').layoutWeight(1).backgroundColor('#28785C').enabled(!this.busy).onClick(() => this.onSync(this.address))
          }
          Button('测试当前接口连接').enabled(!this.busy).onClick(this.onCheckServer)
          Button(`处理同步冲突（${this.conflictCount}）`).enabled(!this.busy).onClick(this.onConflicts)
          Button('算法调试（Mock）').enabled(!this.busy).onClick(this.onAlgorithms)
          Text(this.lastSync ? `最近成功上传：${this.lastSync}` : '尚未完成上传').fontSize(11).fontColor('#748078').width('100%')
          Text('真机填写电脑局域网地址。库存与全部批次双向同步；冲突须确认。历史流水与补货清单仍可用完整备份恢复。')
            .fontSize(11).fontColor('#748078').lineHeight(18).width('100%')
        }.padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        Button('退出登录').width('100%').backgroundColor('#F1E7E2').fontColor('#A35F48').enabled(!this.busy).onClick(this.onLogout)
        Text('好物有期 · 本地数据增强版').fontSize(11).fontColor('#9AA69D').padding({ bottom: 12 })
      }.padding(20).width('100%')
    }.layoutWeight(1).scrollBar(BarState.Off)
  }
}
