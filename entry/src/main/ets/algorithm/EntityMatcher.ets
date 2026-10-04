import { Item } from '../domain/Item';
export interface EntityMatch { item: Item; score: number; reason: string; }
export class EntityMatcher {
  static normalize(value: string): string { return value.toLowerCase().replace(/[\s·・,，。;；:：()（）\-_/]/g,''); }
  static candidates(incoming: Item, items: Item[]): EntityMatch[] {
    const name=EntityMatcher.normalize(incoming.name); if (!name) return [];
    const matches: EntityMatch[]=[];
    for (const item of items) {
      if((item.sourceMode??'').startsWith('MOCK')!==(incoming.sourceMode??'').startsWith('MOCK'))continue;
      if (item.deletedAt!==undefined || item.id===incoming.id || item.categoryId!==incoming.categoryId || EntityMatcher.normalize(item.name)!==name) continue;
      if ((item.unit ?? '件')!==(incoming.unit ?? '件')) continue;
      const a=EntityMatcher.normalize(incoming.brand ?? ''),b=EntityMatcher.normalize(item.brand ?? '');
      if (a && b && a!==b) continue;
      matches.push({item,score:a && b?100:90,reason:a && b?'名称、品牌、分类、单位相同':'名称、分类、单位相同，品牌信息仍需核对'});
    }
    return matches.sort((a:EntityMatch,b:EntityMatch)=>b.score-a.score || a.item.id.localeCompare(b.item.id)).slice(0,5);
  }
}
