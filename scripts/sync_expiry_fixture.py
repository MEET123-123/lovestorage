from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'algorithm' / 'contracts' / 'expiry-test-cases.json'
target = ROOT / 'entry' / 'src' / 'ohosTest' / 'ets' / 'test' / 'fixtures' / 'ExpiryFixtures.ets'

data = json.loads(source.read_text(encoding='utf-8'))

def q(value):
    if value is None:
        return 'undefined'
    return json.dumps(value, ensure_ascii=False)

lines = [
    '// AUTO-GENERATED. DO NOT EDIT.',
    '// Source: /algorithm/contracts/expiry-test-cases.json',
    '',
    'export interface ExpiryFixture {',
    '  id: string;',
    '  today: string;',
    '  expiryDate: string;',
    '  openedDate?: string;',
    '  afterOpenValue?: number;',
    '  afterOpenUnit?: string;',
    '  reminderDays: number;',
    '  expectedRemainingDays: number;',
    '  expectedStatus: string;',
    '  expectedEffectiveExpiryDate: string;',
    '}',
    '',
    'export const EXPIRY_FIXTURES: ExpiryFixture[] = ['
]

for row in data:
    lines += [
        '  {',
        f'    id: {q(row["id"])},',
        f'    today: {q(row["today"])},',
        f'    expiryDate: {q(row["expiryDate"])},',
    ]
    if 'openedDate' in row:
        lines.append(f'    openedDate: {q(row["openedDate"])},')
    if 'afterOpenValue' in row:
        lines.append(f'    afterOpenValue: {row["afterOpenValue"]},')
    if 'afterOpenUnit' in row:
        lines.append(f'    afterOpenUnit: {q(row["afterOpenUnit"])},')
    lines += [
        f'    reminderDays: {row["reminderDays"]},',
        f'    expectedRemainingDays: {row["expectedRemainingDays"]},',
        f'    expectedStatus: {q(row["expectedStatus"])},',
        f'    expectedEffectiveExpiryDate: {q(row["expectedEffectiveExpiryDate"])}',
        '  },'
    ]

lines.append('];')
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'generated {target.relative_to(ROOT)}')
