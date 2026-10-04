import { Item } from '../domain/Item';
import { UserProfile } from '../domain/UserProfile';
import { InventoryDomain } from './InventoryDomain';
import { SafetyGuard } from './SafetyGuard';
export class AdviceEngine {
  static describe(item: Item, today: string, profile: UserProfile): string {
    const safety=SafetyGuard.evaluate(item,today,profile.allergies,profile.dislikes);
    const base=InventoryDomain.advice(item,today);
    if (safety.matches.length) {
      const expired=safety.reasonCodes.includes('EXPIRED');
      return `名称或备注命中你的忌口：${safety.matches.join('、')}。请先核对包装配料，不据此推荐食用。${expired ? base : '请勿据此安排食用，先核对完整包装配料与过敏原。'}`;
    }
    if (safety.blocked || item.categoryId!=='food') return base;
    return profile.preferences.length ? `${base} 你的偏好：${profile.preferences.join('、')}，选用前请核对包装信息。` : base;
  }
}
