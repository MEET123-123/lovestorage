from pathlib import Path
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
json.loads((ROOT / 'shared' / 'expiry-test-cases.json').read_text(encoding='utf-8'))
ET.parse(ROOT / 'pom.xml')
text = (ROOT / 'openapi' / 'smart-expiry-v1.yaml').read_text(encoding='utf-8')
for required in ('openapi: 3.1.0', '/api/v1/items:', '/api/v1/health:'):
    if required not in text:
        raise SystemExit(f'missing OpenAPI marker: {required}')
print('contract structure OK')
