import { Item } from '../domain/Item';
import { InventoryDomain } from './InventoryDomain';
export interface MockForecastResult { itemId: string; projectedRemaining: number; risk: string; version: string; mode: string; }
export class MockForecast {
  static predict(item: Item, today: string): MockForecastResult {
    const days=Math.max(0,Math.min(7,InventoryDomain.evaluate(item,today).remainingDays ?? 7));
    const remaining=Math.round(Math.max(0,(item.quantity ?? 1)-days*0.25)*1000)/1000;
    return {itemId:item.id,projectedRemaining:remaining,risk:remaining>0?'MOCK_SURPLUS':'MOCK_BALANCED',version:'forecast-mock-v1',mode:'MOCK_SHADOW'};
  }
}
