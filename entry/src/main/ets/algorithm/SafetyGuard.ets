import { Item } from '../domain/Item';
import { InventoryDomain } from './InventoryDomain';
export interface SafetyDecision { blocked: boolean; reasonCodes: string[]; matches: string[]; }
export class SafetyGuard {
  static evaluate(item: Item, today: string, allergies: string[] = [], dislikes: string[] = []): SafetyDecision {
    const codes: string[]=[]; const matches: string[]=[];
    if (item.deletedAt !== undefined || item.lifecycleStatus !== 'ACTIVE' || (item.quantity ?? 1)<=0) codes.push('NOT_AVAILABLE');
    const days=InventoryDomain.evaluate(item,today).remainingDays;
    if (days === undefined) codes.push('MISSING_EXPIRY'); else if (days<0) codes.push('EXPIRED');
    if (item.categoryId==='food') {
      const text=`${item.name} ${item.notes ?? ''}`.toLowerCase();
      for (const tag of allergies) if (tag.trim() && text.includes(tag.toLowerCase())) { matches.push(tag); if (!codes.includes('ALLERGY_MATCH')) codes.push('ALLERGY_MATCH'); }
      for (const tag of dislikes) if (tag.trim() && text.includes(tag.toLowerCase())) { if (!matches.includes(tag)) matches.push(tag); if (!codes.includes('DISLIKE_MATCH')) codes.push('DISLIKE_MATCH'); }
    }
    return {blocked:codes.length>0,reasonCodes:codes,matches};
  }
}
