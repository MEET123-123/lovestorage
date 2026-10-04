from pathlib import Path
from urllib.request import urlopen
import hashlib
import argparse
import json
import runpy

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/MEET123-123/lovestorage/split-server"
FILES = {
    "openapi/smart-expiry-v1.yaml": ROOT / "contract" / "smart-expiry-v1.yaml",
    "algorithm/contracts/expiry-test-cases.json": ROOT / "algorithm" / "contracts" / "expiry-test-cases.json",
    "algorithm/contracts/recognition-test-cases.json": ROOT / "algorithm" / "contracts" / "recognition-test-cases.json",
    "algorithm/contracts/attention-rules.json": ROOT / "algorithm" / "contracts" / "attention-rules.json",
    "algorithm/contracts/attention-test-cases.json": ROOT / "algorithm" / "contracts" / "attention-test-cases.json",
}

parser = argparse.ArgumentParser()
parser.add_argument('--server-dir', type=Path, help='Use a local backend checkout without network access')
args = parser.parse_args()
pending = {}
for remote, target in FILES.items():
    if args.server_dir:
        data = (args.server_dir / remote).read_bytes()
    else:
        with urlopen(f"{BASE}/{remote}", timeout=20) as response:
            data = response.read()
    if remote.endswith('.json'):
        json.loads(data)
    pending[target] = data

for target, data in pending.items():
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"updated {target.relative_to(ROOT)} sha256={hashlib.sha256(data).hexdigest()[:16]}")
runpy.run_path(str(ROOT / 'scripts/sync_attention_fixture.py'))
