import expiryServiceTest from './ExpiryService.test';
import inventoryDomainTest from './InventoryDomain.test';

export default function testsuite(): void {
  expiryServiceTest();
  inventoryDomainTest();
}
