from pathlib import Path
from urllib.request import urlopen
import hashlib

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/MEET123-123/lovestorage-server/main"
FILES = {
    "openapi/smart-expiry-v1.yaml": ROOT / "contract" / "smart-expiry-v1.yaml",
    "shared/expiry-test-cases.json": ROOT / "contract" / "expiry-test-cases.json",
}

for remote, target in FILES.items():
    with urlopen(f"{BASE}/{remote}", timeout=20) as response:
        data = response.read()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"updated {target.relative_to(ROOT)} sha256={hashlib.sha256(data).hexdigest()[:16]}")
