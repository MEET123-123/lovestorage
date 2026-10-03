export interface DateCandidate { field: string; value: string; evidence: string; confidence: number; }
export interface RecognitionDraft {
  name: string;
  expiry: string;
  production: string;
  shelfLife: string;
  unit: number;
  candidates: DateCandidate[];
  warnings: string[];
  requiresConfirmation: boolean;
  engineVersion: string;
}

// Scores describe rule strength, not statistical probability of correctness.
export class RecognitionEngine {
  static parse(input: string): RecognitionDraft {
    const draft: RecognitionDraft = { name: '', expiry: '', production: '', shelfLife: '', unit: 0,
      candidates: [], warnings: [], requiresConfirmation: true, engineVersion: 'rules-1.0' };
    let text = '';
    for (let i = 0; i < Math.min(input.length, 2000); i++) {
      const code = input.charCodeAt(i);
      text += code >= 0xFF01 && code <= 0xFF5E ? String.fromCharCode(code - 0xFEE0) : input[i] === '\u3000' ? ' ' : input[i];
    }
    const name = /(?:名称|品名|产品名称)\s*[:：]\s*([^\n;；]+)/.exec(text);
    if (name) draft.name = name[1].trim().slice(0, 80);
    const dates = /(生产日期|生产|制造日期|MFG|到期日期|到期|有效期至|保质期至|EXP)\s*[:：]?\s*(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?(?!\d)/gi;
    let match: RegExpExecArray | null = dates.exec(text);
    while (match !== null) {
      const value = `${match[2]}-${match[3].padStart(2, '0')}-${match[4].padStart(2, '0')}`;
      const year = Number(match[2]), month = Number(match[3]), day = Number(match[4]);
      const date = new Date(year, month - 1, day);
      if (year >= 1900 && date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day) {
        const field = /^(生产|制造|MFG)/i.test(match[1]) ? 'production' : 'expiry';
        draft.candidates.push({ field, value, evidence: match[0], confidence: 0.95 });
      } else draft.warnings.push(`无效日期：${match[0]}`);
      match = dates.exec(text);
    }
    for (const field of ['production', 'expiry']) {
      const values: string[] = [];
      for (const candidate of draft.candidates) if (candidate.field === field && !values.includes(candidate.value)) values.push(candidate.value);
      if (values.length === 1) { if (field === 'production') draft.production = values[0]; else draft.expiry = values[0]; }
      if (values.length > 1) draft.warnings.push(`${field === 'production' ? '生产' : '到期'}日期存在多个候选，请手动选择`);
    }
    const lifePattern = /保质期\s*[:：]?\s*(\d+)\s*(天|个月|月|年)/g;
    let life: RegExpExecArray | null = lifePattern.exec(text);
    const lifeValues: string[] = [];
    while (life !== null) {
      const unit = life[2] === '天' ? 0 : life[2] === '年' ? 2 : 1;
      const key = `${Number(life[1])}:${unit}`;
      if (Number(life[1]) >= 1 && Number(life[1]) <= 1200) {
        if (!lifeValues.includes(key)) lifeValues.push(key);
      } else draft.warnings.push('保质期超出 1–1200 的范围');
      life = lifePattern.exec(text);
    }
    if (lifeValues.length === 1) { draft.shelfLife = lifeValues[0].split(':')[0]; draft.unit = Number(lifeValues[0].split(':')[1]); }
    if (lifeValues.length > 1) draft.warnings.push('保质期存在多个候选，请手动选择');
    if (draft.production && draft.expiry && draft.expiry < draft.production) {
      draft.expiry = ''; draft.warnings.push('到期早于生产日期，请对照包装核对');
    }
    if (!draft.expiry && !(draft.production && draft.shelfLife)) draft.warnings.push('未获得完整日期，不推测缺失年份或无标签日期');
    if (!draft.name) draft.warnings.push('未识别明确品名，请填写物品名称');
    if (input.length > 2000) draft.warnings.push('仅处理前 2000 个字符');
    return draft;
  }
}
