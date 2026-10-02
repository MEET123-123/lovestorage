from pathlib import Path
import hashlib
import subprocess
import tempfile
import shutil

ROOT = Path(__file__).resolve().parents[1]
target = ROOT / 'harmonyos' / 'entry' / 'src' / 'ohosTest' / 'ets' / 'test' / 'fixtures' / 'ExpiryFixtures.ets'

before = target.read_bytes() if target.exists() else b''
subprocess.run(['python3', str(ROOT / 'scripts' / 'sync_shared_fixtures.py')], check=True)
after = target.read_bytes()

if before != after:
    print('Shared fixture was stale; it has been regenerated. Commit the updated ExpiryFixtures.ets.')
    raise SystemExit(1)

print('shared fixture is in sync:', hashlib.sha256(after).hexdigest()[:16])
