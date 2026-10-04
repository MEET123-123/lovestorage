"""Read-only deployment checks. Never displays database credentials."""
from pathlib import Path
from urllib.parse import urlparse, parse_qs
import argparse

def validate(directory: Path):
    problems=[]; config={}
    env=directory/'.env'
    if not env.is_file(): return ['Copy deploy/.env.example to deploy/.env and fill in actual values.']
    for line in env.read_text(encoding='utf-8-sig').splitlines():
        line=line.strip()
        if not line or line.startswith('#'): continue
        key,sep,value=line.partition('=')
        if not sep: problems.append('Invalid environment assignment.');continue
        config[key.strip()]=value.strip().strip('"').strip("'")
    url=config.get('DB_URL','')
    parsed=urlparse(url.removeprefix('jdbc:'))
    if not url.startswith('jdbc:postgresql://') or not parsed.hostname or 'YOUR_' in url or not parsed.path.strip('/'):
        problems.append('DB_URL must identify the actual PostgreSQL host and database.')
    if parsed.hostname in ('localhost','127.0.0.1','::1'):
        problems.append('Inside Docker, localhost is the application container. Use the private DB host or host.docker.internal.')
    if parsed.username or parsed.password:
        problems.append('Keep credentials out of DB_URL.')
    if not config.get('DB_USERNAME') or config['DB_USERNAME']=='YOUR_DB_USER': problems.append('Set DB_USERNAME.')
    ssl=parse_qs(parsed.query).get('sslmode',[''])[0]
    if ssl not in ('verify-full','verify-ca','require','disable'): problems.append('Choose an explicit sslmode based on the database configuration.')
    if ssl in ('verify-full','verify-ca') and not (directory/'certs/root.crt').is_file(): problems.append('Install the database CA certificate as deploy/certs/root.crt.')
    secret=directory/'secrets/db_password.txt'
    if not secret.is_file(): problems.append('Create deploy/secrets/db_password.txt without adding it to Git.')
    elif secret.read_text(encoding='utf-8').strip() in ('','smart_expiry','CHANGE_ME'): problems.append('Use the actual non-default database password.')
    return problems

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--directory',type=Path,default=Path(__file__).resolve().parent)
    issues=validate(parser.parse_args().directory)
    for issue in issues: print('CHECK:',issue)
    if not issues: print('PASS local deployment settings. This does not verify database reachability or TLS trust.')
    raise SystemExit(bool(issues))
