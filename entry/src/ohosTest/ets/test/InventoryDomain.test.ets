import { describe, expect, it } from '@ohos/hypium';
import { Item } from '../../../main/ets/domain/Item';
import { InventoryDomain } from '../../../main/ets/algorithm/InventoryDomain';
import { ReminderPlan } from '../../../main/ets/algorithm/ReminderPlan';

export default function inventoryDomainTest(): void {
  describe('Inventory domain', () => {
    it('calendar-validation', 0, () => {
      expect(InventoryDomain.validDate('2026-02-30')).assertFalse();
      expect(InventoryDomain.validDate('2024-02-29')).assertTrue();
    });
    it('opened-expiry-and-filter', 0, () => {
      const item: Item = { id: '1', name: '面霜', categoryId: 'cosmetics', lifecycleStatus: 'ACTIVE',
        expiryDate: '2026-12-31', openedDate: '2026-01-31', afterOpenValue: 1, afterOpenUnit: 'MONTH', createdAt: 1, updatedAt: 1 };
      expect(InventoryDomain.evaluate(item, '2026-02-28').effectiveExpiryDate).assertEqual('2026-02-28');
      expect(InventoryDomain.filter([item], '', 'all', 'EXPIRED', 0, '2026-03-01').length).assertEqual(1);
      item.lifecycleStatus = 'CONSUMED';
      expect(InventoryDomain.filter([item], '', 'all', 'EXPIRED', 0, '2026-03-01').length).assertEqual(0);
    });
    it('labelled-text-only', 0, () => {
      expect(InventoryDomain.parseText('牛奶 2026-10-03').expiry).assertEqual('');
      expect(InventoryDomain.parseText('牛奶\n到期：2026/10/3').expiry).assertEqual('2026-10-03');
    });
    it('reminder-plan', 0, () => {
      const item: Item = { id: '1', name: '牛奶', categoryId: 'food', lifecycleStatus: 'ACTIVE', expiryDate: '2030-10-30', createdAt: 1, updatedAt: 1 };
      const plans = ReminderPlan.create([item], new Date('2030-10-22T12:00:00').getTime());
      expect(plans.length).assertEqual(1);
      expect(new Date(plans[0].at).getHours()).assertEqual(9);
      expect(new Date(plans[0].at).getDate()).assertEqual(23);
    });
  });
}
