import { describe, expect, it } from '@ohos/hypium';
import { ExpiryService, ShelfLifeUnit } from '../../../main/ets/domain/ExpiryService';
import { EXPIRY_FIXTURES } from './fixtures/ExpiryFixtures';

export default function expiryServiceTest(): void {
  describe('ExpiryService shared contract', () => {
    const service = new ExpiryService();
    EXPIRY_FIXTURES.forEach((fixture) => {
      it(fixture.id, 0, () => {
        const unit = fixture.afterOpenUnit === undefined
          ? undefined
          : fixture.afterOpenUnit as ShelfLifeUnit;
        const result = service.evaluate(
          fixture.expiryDate,
          fixture.openedDate,
          fixture.afterOpenValue,
          unit,
          fixture.reminderDays,
          fixture.today
        );
        expect(result.effectiveExpiryDate).assertEqual(fixture.expectedEffectiveExpiryDate);
        expect(result.remainingDays).assertEqual(fixture.expectedRemainingDays);
        expect(result.status).assertEqual(fixture.expectedStatus);
      });
    });
  });
}
