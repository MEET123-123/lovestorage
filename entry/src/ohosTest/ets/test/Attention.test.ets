import { describe, expect, it } from '@ohos/hypium';
import { Item } from '../../../main/ets/domain/Item';
import { AttentionEngine } from '../../../main/ets/algorithm/AttentionEngine';

export default function attentionTest(): void {
  describe('Attention rules', () => {
    it('pao-reasons-and-snooze', 0, () => {
      const item: Item = { id: 'milk', name: '牛奶', categoryId: 'food', lifecycleStatus: 'ACTIVE',
        expiryDate: '2026-12-01', openedDate: '2026-10-01', afterOpenValue: 3, afterOpenUnit: 'DAY', createdAt: 1, updatedAt: 1 };
      const engine = new AttentionEngine();
      const decisions = engine.rank([item], '2026-10-03');
      expect(decisions.length).assertEqual(1);
      expect(decisions[0].score).assertEqual(105);
      expect(decisions[0].effectiveExpiryDate).assertEqual('2026-10-04');
      expect(decisions[0].reasonCodes.join(',')).assertEqual('EXPIRES_TOMORROW,OPENED,PAO_NEAR');
      item.snoozeUntil = '2026-10-04';
      expect(engine.rank([item], '2026-10-03').length).assertEqual(0);
    });
    it('handled-inventory-excluded', 0, () => {
      const item: Item = { id: 'old', name: '已处理物品', categoryId: 'food', lifecycleStatus: 'CONSUMED',
        expiryDate: '2026-01-01', createdAt: 1, updatedAt: 1 };
      expect(new AttentionEngine().rank([item], '2026-10-03').length).assertEqual(0);
    });
  });
}
