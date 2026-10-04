import { Item } from '../domain/Item';
import { AttentionDecision, AttentionEngine } from '../algorithm/AttentionEngine';
import { InventoryDomain } from '../algorithm/InventoryDomain';
import { UserProfile, ProfileDomain } from '../domain/UserProfile';
import { TodayUndo, TodayUseCase } from '../usecase/TodayUseCase';
import { SafetyGuard, SafetyDecision } from '../algorithm/SafetyGuard';

export interface TodayCard { item: Item; decision: AttentionDecision; advice: string; safety: SafetyDecision; }
export class TodayViewModel {
  private undoToken?: TodayUndo;
  private useCase: TodayUseCase;
  private engine: AttentionEngine;
  constructor(useCase: TodayUseCase = new TodayUseCase(), engine: AttentionEngine = new AttentionEngine()) {
    this.useCase = useCase; this.engine = engine;
  }
  cards(items: Item[], today: string, profile: UserProfile): TodayCard[] {
    let decisions: AttentionDecision[] = [];
    try { decisions = this.engine.rank(items, today, items.length); }
    catch (error) {
      decisions = InventoryDomain.urgent(items, today).slice(0, 50).map((item: Item): AttentionDecision => {
        const result = InventoryDomain.evaluate(item, today);
        return { itemId: item.id, score: 0, priority: 'LOW', reasonCodes: ['EXPIRY_FALLBACK'],
          effectiveExpiryDate: result.effectiveExpiryDate, remainingDays: result.remainingDays, ruleVersion: 'expiry-sort-v1' };
      });
    }
    const cards: TodayCard[] = [];
    for (const decision of decisions) {
      const item = items.find((row: Item) => row.id === decision.itemId);
      if (item) cards.push({ item, decision, advice: ProfileDomain.advice(item, today, profile), safety:SafetyGuard.evaluate(item,today,profile.allergies,profile.dislikes) });
    }
    return cards;
  }
  async act(id: string, action: string, today: string): Promise<void> { this.undoToken = await this.useCase.perform(id, action, today); }
  async undo(): Promise<void> {
    const token = this.undoToken; this.undoToken = undefined;
    if (!token) throw new Error('没有可撤销的今日操作');
    await this.useCase.undo(token);
  }
}
