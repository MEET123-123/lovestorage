import { UserProfile, ProfileDomain, AvatarChoice } from '../domain/UserProfile';
import { SectionTitle } from '../components/InventoryComponents';

@Component
export struct ProfileEditor {
  @Prop profile: UserProfile = ProfileDomain.empty();
  @Prop busy: boolean = false;
  @State private nickname: string = '';
  @State private avatar: string = 'leaf';
  @State private bio: string = '';
  @State private allergies: string = '';
  @State private dislikes: string = '';
  @State private preferences: string = '';
  @State private error: string = '';
  onSave: (profile: UserProfile) => void = () => {};
  aboutToAppear(): void {
    this.nickname = this.profile.displayName; this.avatar = this.profile.avatarKey; this.bio = this.profile.bio;
    this.allergies = this.profile.allergies.join('、'); this.dislikes = this.profile.dislikes.join('、'); this.preferences = this.profile.preferences.join('、');
  }
  private toggle(value: string, tag: string): string {
    const tags = ProfileDomain.tags(value);
    return (tags.includes(tag) ? tags.filter((t: string) => t !== tag) : tags.concat(tag)).join('、');
  }
  private submit(): void {
    const value: UserProfile = { displayName: this.nickname.trim(), avatarKey: this.avatar, bio: this.bio.trim(),
      allergies: ProfileDomain.tags(this.allergies), dislikes: ProfileDomain.tags(this.dislikes), preferences: ProfileDomain.tags(this.preferences) };
    this.error = ProfileDomain.validate(value);
    if (!this.error) this.onSave(value);
  }
  @Builder
  private chips(options: string[], selected: string, change: (value: string) => void) {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(options, (tag: string) => {
        Button(tag).fontSize(12).height(32).margin({ right: 8, bottom: 8 }).backgroundColor(ProfileDomain.tags(selected).includes(tag) ? '#28785C' : '#EDF2E9')
          .fontColor(ProfileDomain.tags(selected).includes(tag) ? '#FFFFFF' : '#63766D').enabled(!this.busy).onClick(() => change(this.toggle(selected, tag)))
      })
    }.width('100%')
  }
  build() {
    Column() {
      Scroll() {
        Column({ space: 18 }) {
          SectionTitle({ title: '编辑个人资料', subtitle: '头像、昵称和饮食偏好会保存到你的账号' })
          Column({ space: 16 }) {
            Text('选择头像').fontSize(17).fontColor('#223D31').width('100%')
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              ForEach(ProfileDomain.avatars, (choice: AvatarChoice) => {
                Column({ space: 5 }) {
                  Text(choice.symbol).fontSize(30).width(54).height(54).textAlign(TextAlign.Center).backgroundColor(choice.color).borderRadius(19)
                    .border({ width: this.avatar === choice.key ? 2 : 0, color: '#28785C' })
                  Text(choice.label).fontSize(11).fontColor(this.avatar === choice.key ? '#28785C' : '#748078')
                }.width('23%').margin({ bottom: 14 }).onClick(() => { if (!this.busy) this.avatar = choice.key; })
              })
            }.width('100%')
            TextInput({ text: this.nickname, placeholder: '昵称（1–40 个字符）' }).maxLength(40).enabled(!this.busy).onChange((v: string) => { this.nickname = v; })
            TextArea({ text: this.bio, placeholder: '个性签名，介绍一下自己' }).height(88).maxLength(120).enabled(!this.busy).onChange((v: string) => { this.bio = v; })
          }.padding(18).backgroundColor('#FFFFFF').borderRadius(20)
          Column({ space: 12 }) {
            Text('需要避开的食材 / 过敏原').fontSize(17).fontColor('#223D31').width('100%')
            this.chips(['花生', '牛奶', '鸡蛋', '小麦', '大豆', '鱼', '虾蟹'], this.allergies, (v: string) => { this.allergies = v; })
            TextArea({ text: this.allergies, placeholder: '用逗号或顿号分隔，例如：花生、芝麻' }).height(80).maxLength(500).enabled(!this.busy).onChange((v: string) => { this.allergies = v; })
            Text('仅用于关键词提醒，不能识别全部配料或判断食用安全。').fontSize(11).fontColor('#9B6B31')
          }.padding(18).backgroundColor('#FFFFFF').borderRadius(20)
          Column({ space: 12 }) {
            Text('不喜欢的食材与口味').fontSize(17).fontColor('#223D31').width('100%')
            this.chips(['香菜', '葱', '蒜', '辣椒', '苦瓜'], this.dislikes, (v: string) => { this.dislikes = v; })
            TextArea({ text: this.dislikes, placeholder: '例如：香菜、榴莲、太辣' }).height(80).maxLength(500).enabled(!this.busy).onChange((v: string) => { this.dislikes = v; })
          }.padding(18).backgroundColor('#FFFFFF').borderRadius(20)
          Column({ space: 12 }) {
            Text('我的日常偏好').fontSize(17).fontColor('#223D31').width('100%')
            this.chips(['清淡', '低糖', '少盐', '素食', '高蛋白', '小份量'], this.preferences, (v: string) => { this.preferences = v; })
            TextArea({ text: this.preferences, placeholder: '可补充饮食或购物习惯，以逗号分隔' }).height(80).maxLength(500).enabled(!this.busy).onChange((v: string) => { this.preferences = v; })
          }.padding(18).backgroundColor('#FFFFFF').borderRadius(20)
          if (this.error) { Text(this.error).fontSize(13).fontColor('#A35F48') }
        }.padding(20).width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
      Button(this.busy ? '正在保存…' : '保存个人资料').width('90%').height(48).backgroundColor('#28785C').margin({ top: 8, bottom: 16 }).enabled(!this.busy).onClick(() => this.submit())
    }.layoutWeight(1).width('100%')
  }
}
