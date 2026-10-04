import expiryServiceTest from './ExpiryService.test';
import inventoryDomainTest from './InventoryDomain.test';
import attentionTest from './Attention.test';

export default function testsuite(): void {
  expiryServiceTest();
  inventoryDomainTest();
  attentionTest();
}
