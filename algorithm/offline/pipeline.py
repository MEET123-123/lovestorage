"""Standard-library reference data pipeline. No network, no online model serving.

Decision features are frozen at exposure time. Feedback labels mature after seven
days; future arrivals and immature examples are excluded. Mock samples stay Mock.
"""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import argparse
import hashlib
import hmac
import json
import uuid

WINDOW=timedelta(days=7)

def instant(value):
    parsed=datetime.fromisoformat(value.replace('Z','+00:00'))
    if parsed.tzinfo is None: raise ValueError('Timestamps must include a timezone')
    return parsed.astimezone(timezone.utc)

def write_json(path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def read_events(paths):
    events=[]
    for path in paths:
        text=path.read_text(encoding='utf-8-sig')
        try: document=json.loads(text)
        except json.JSONDecodeError: events.extend(json.loads(line) for line in text.splitlines() if line.strip());continue
        if isinstance(document,list): events.extend(document)
        elif 'data' in document: events.extend(document['data']['events'])
        elif 'events' in document: events.extend(document['events'])
        else: events.append(document)
    unique={}
    for event in events:
        key=event['eventId']
        if key in unique and event!=unique[key]: raise ValueError('Conflicting duplicate eventId')
        unique[key]=event
    return list(unique.values())

def build_dataset(events, as_of, subject, salt):
    if len(salt)<16: raise ValueError('Use at least 16 bytes of private pseudonymization salt')
    subject_hash=hmac.new(salt,subject.encode(),hashlib.sha256).hexdigest()
    visible=[e for e in events if instant(e['recordedAt'])<=as_of and instant(e['occurredAt'])<=as_of]
    shown={};feedback={}
    for event in sorted(visible,key=lambda e:(instant(e['occurredAt']),e['eventId'])):
        props=event['properties'];decision=props.get('decisionId')
        if event['eventType']=='DECISION_SHOWN':
            if decision in shown and shown[decision]['properties']!=props: raise ValueError('Conflicting decision feature snapshot')
            shown.setdefault(decision,event)
        elif event['eventType']=='DECISION_FEEDBACK':feedback.setdefault(decision,[]).append(event)
    rows=[]
    for decision,event in shown.items():
        start=instant(event['occurredAt']);end=start+WINDOW
        if end>as_of: continue
        props=event['properties']
        history=[e for e in feedback.get(decision,[]) if start<=instant(e['occurredAt'])<=end and e['properties'].get('itemId')==props.get('itemId')]
        # UNDO invalidates the preceding handled label; later explicit handling can restore it.
        action=history[-1]['properties']['action'] if history else None
        if action not in (None,'CONSUMED','DISCARDED','UNDO','SNOOZE','NOT_HELPFUL'): raise ValueError('Unsupported feedback')
        score=props.get('score');remaining=props.get('remainingDays')
        if not isinstance(score,(int,float)) or isinstance(score,bool) or not 0<=score<=4000000: raise ValueError('Invalid score')
        if remaining is not None and (not isinstance(remaining,int) or isinstance(remaining,bool)):raise ValueError('Invalid remainingDays')
        rows.append({'decision_id':decision,'subject_hash':subject_hash,'occurred_at':start.isoformat(),
            'label_end':end.isoformat(),'score':score,'remaining_days':remaining,'opened':bool(props.get('opened',False)),
            'rule_version':props['algorithmVersion'],'handled_within_7d':int(action in ('CONSUMED','DISCARDED')),
            'label_source':action or 'NO_RESPONSE_OBSERVED','mock':bool(event.get('mock',False) or props.get('mock',False))})
    rows.sort(key=lambda r:(r['occurred_at'],r['decision_id']))
    dates=sorted({r['occurred_at'] for r in rows})
    if len(dates)<3: raise ValueError('At least three mature decision times are required for temporal splitting')
    train_cut=dates[max(1,int(len(dates)*0.7))];validation_cut=dates[min(len(dates)-1,max(2,int(len(dates)*0.85)))]
    # Purge overlapping outcome windows to avoid labels leaking across split boundaries.
    kept=[]
    for row in rows:
        row['split']='train' if row['occurred_at']<train_cut else 'validation' if row['occurred_at']<validation_cut else 'test'
        boundary=train_cut if row['split']=='train' else validation_cut if row['split']=='validation' else None
        if boundary and row['label_end']>=boundary: continue
        kept.append(row)
    return {'schemaVersion':1,'target':'handled_within_7d','asOf':as_of.isoformat(),'mock':any(r['mock'] for r in kept),
            'splitPolicy':'chronological_with_7_day_label_purge','rows':kept}

def evaluate(dataset):
    train=[r for r in dataset['rows'] if r['split']=='train']
    if not train: raise ValueError('Training split is empty after label-window purge')
    probability=sum(r['handled_within_7d'] for r in train)/len(train)
    metrics={}
    for split in ('train','validation','test'):
        rows=[r for r in dataset['rows'] if r['split']==split]
        metrics[split]={'count':len(rows),'brier':sum((probability-r['handled_within_7d'])**2 for r in rows)/len(rows) if rows else None}
    return {'model':'constant-action-rate-baseline-v1','mode':'OFFLINE_ONLY','mock':dataset['mock'],
            'promotable':False,'probability':probability,'metrics':metrics,
            'note':'Reference baseline only. Missing feedback is not proof of no action; report is not an OCR or safety benchmark.'}

def validate_registry(document):
    entries=document['models'];ids=[m['id'] for m in entries]
    if len(ids)!=len(set(ids)) or document['active'] not in ids: raise ValueError('Registry IDs must be unique and active must exist')
    for model in entries:
        if model['mode'] not in ('ACTIVE','SHADOW','DISABLED','CANARY'): raise ValueError('Unknown mode')
        if model.get('mock') and (model['mode'] in ('ACTIVE','CANARY') or model['id']==document['active'] or model.get('trafficPercent',0)!=0):raise ValueError('Mock models cannot serve active/canary traffic')
    active=[m for m in entries if m['mode']=='ACTIVE']
    if len(active)!=1 or active[0]['id']!=document['active']: raise ValueError('Registry must have exactly one active model')

def mock_events():
    rows=[];start=datetime(2026,1,1,tzinfo=timezone.utc)
    for index in range(100):
        time=start+timedelta(days=index);decision=str(uuid.uuid5(uuid.NAMESPACE_URL,f'mock-decision-{index}'))
        def event(kind,at,props):return {'eventId':str(uuid.uuid5(uuid.NAMESPACE_URL,f'mock-{index}-{kind}')),'eventType':kind,'eventVersion':'1.0','occurredAt':at.isoformat(),'recordedAt':(at+timedelta(minutes=2)).isoformat(),'properties':props,'mock':True}
        props={'itemId':str(uuid.uuid5(uuid.NAMESPACE_URL,f'mock-item-{index}')),'decisionId':decision,'algorithmVersion':'attention-rule-v1','score':40+(index%6)*10,'remainingDays':index%7,'opened':index%2==0,'reasonCodes':['EXPIRES_THIS_WEEK']}
        rows.append(event('DECISION_SHOWN',time,props))
        if index%3!=0: rows.append(event('DECISION_FEEDBACK',time+timedelta(days=1),{'itemId':props['itemId'],'decisionId':decision,'algorithmVersion':'attention-rule-v1','action':'CONSUMED' if index%2 else 'DISCARDED'}))
    return rows

def main():
    parser=argparse.ArgumentParser();sub=parser.add_subparsers(dest='command',required=True)
    mock=sub.add_parser('mock-events');mock.add_argument('--output',type=Path,required=True)
    build=sub.add_parser('build-dataset');build.add_argument('--events',type=Path,nargs='+',required=True);build.add_argument('--as-of',required=True);build.add_argument('--subject',required=True);build.add_argument('--salt-file',type=Path,required=True);build.add_argument('--output',type=Path,required=True)
    check=sub.add_parser('evaluate');check.add_argument('--dataset',type=Path,required=True);check.add_argument('--output',type=Path,required=True)
    reg=sub.add_parser('check-registry');reg.add_argument('--registry',type=Path,default=Path(__file__).resolve().parents[1]/'model-registry.json')
    args=parser.parse_args()
    if args.command=='mock-events':write_json(args.output,mock_events())
    elif args.command=='build-dataset':write_json(args.output,build_dataset(read_events(args.events),instant(args.as_of),args.subject,args.salt_file.read_bytes()))
    elif args.command=='evaluate':write_json(args.output,evaluate(json.loads(args.dataset.read_text(encoding='utf-8'))))
    else:validate_registry(json.loads(args.registry.read_text(encoding='utf-8')))
    print('PASS',args.command)

if __name__=='__main__':main()
