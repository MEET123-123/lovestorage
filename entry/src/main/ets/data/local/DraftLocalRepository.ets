import { util } from '@kit.ArkTS';
import { AppDatabase } from './AppDatabase';
import { RecognitionEngine, RecognitionDraft } from '../../algorithm/RecognitionEngine';
export interface CaptureDraft { id: string; mode: string; text: string; createdAt: number; result: RecognitionDraft; }
export class DraftLocalRepository {
  async discard(id: string): Promise<void> {
    await (await AppDatabase.getStore()).executeSql("DELETE FROM item_draft WHERE id=? AND state='DRAFT'",[id]);
  }
  async create(mode: string, text: string): Promise<CaptureDraft> {
    if (!text.trim() || text.length>2000) throw new Error('请输入 1–2000 字的包装文字');
    const draft: CaptureDraft={id:util.generateRandomUUID(),mode,text,createdAt:Date.now(),result:RecognitionEngine.parse(text)};
    await (await AppDatabase.getStore()).executeSql('INSERT INTO item_draft(id,payload,state,created_at) VALUES (?,?,?,?)',[draft.id,JSON.stringify(draft),'DRAFT',draft.createdAt]);
    return draft;
  }
  async list(): Promise<CaptureDraft[]> {
    const rs=await (await AppDatabase.getStore()).querySql("SELECT payload FROM item_draft WHERE state='DRAFT' ORDER BY created_at DESC");
    const drafts: CaptureDraft[]=[];
    try { while(rs.goToNextRow()) drafts.push(JSON.parse(rs.getString(0)) as CaptureDraft); } finally { rs.close(); }
    return drafts;
  }
}
