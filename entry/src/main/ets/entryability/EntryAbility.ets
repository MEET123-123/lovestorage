import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppDatabase } from '../data/local/AppDatabase';
import { ReminderService } from '../reminder/ReminderService';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    AppDatabase.initialize(this.context);
    ReminderService.initialize(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Login');
  }
}
