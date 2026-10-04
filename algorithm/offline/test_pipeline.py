import unittest
from datetime import timedelta
from copy import deepcopy
from pipeline import build_dataset, evaluate, instant, mock_events, validate_registry

class PipelineTest(unittest.TestCase):
    def build(self,events=None):
        return build_dataset(events if events is not None else mock_events(),instant('2026-06-01T00:00:00Z'),'local-test-account',b'private-testing-salt-123')
    def test_mock_temporal_split_and_pseudonymization(self):
        dataset=self.build();rows=dataset['rows'];self.assertTrue(dataset['mock'])
        train=[r for r in rows if r['split']=='train'];valid=[r for r in rows if r['split']=='validation'];test=[r for r in rows if r['split']=='test']
        self.assertLess(max(r['label_end'] for r in train),min(r['occurred_at'] for r in valid))
        self.assertLess(max(r['label_end'] for r in valid),min(r['occurred_at'] for r in test))
        self.assertNotIn('local-test-account',str(dataset));self.assertNotIn('itemId',str(dataset))
        report=evaluate(dataset);self.assertFalse(report['promotable']);self.assertTrue(report['mock'])
    def test_late_arrival_excluded(self):
        events=mock_events();feedback=next(e for e in events if e['eventType']=='DECISION_FEEDBACK')
        decision=feedback['properties']['decisionId'];feedback['recordedAt']='2030-01-01T00:00:00Z'
        row=next(r for r in self.build(events)['rows'] if r['decision_id']==decision)
        self.assertEqual(row['handled_within_7d'],0)
    def test_undo_invalidates_label(self):
        events=mock_events();feedback=deepcopy(next(e for e in events if e['eventType']=='DECISION_FEEDBACK'))
        feedback['eventId']='undo-event';feedback['properties']['action']='UNDO'
        feedback['occurredAt']=(instant(feedback['occurredAt'])+timedelta(hours=1)).isoformat();feedback['recordedAt']=feedback['occurredAt'];events.append(feedback)
        row=next(r for r in self.build(events)['rows'] if r['decision_id']==feedback['properties']['decisionId'])
        self.assertEqual(row['handled_within_7d'],0)
    def test_feature_snapshot_does_not_use_feedback_features(self):
        events=mock_events();feedback=next(e for e in events if e['eventType']=='DECISION_FEEDBACK');feedback['properties']['score']=99999
        self.assertTrue(all(r['score']<100 for r in self.build(events)['rows']))
    def test_timezone_and_salt_are_required(self):
        with self.assertRaises(ValueError):instant('2026-01-01')
        with self.assertRaises(ValueError):build_dataset(mock_events(),instant('2026-06-01T00:00:00Z'),'subject',b'short')
    def test_mock_cannot_be_promoted(self):
        registry={'active':'real','models':[{'id':'real','mock':False,'mode':'ACTIVE'},{'id':'mock','mock':True,'mode':'SHADOW','trafficPercent':0}]}
        validate_registry(registry)
        registry['models'][1]['mode']='CANARY'
        with self.assertRaises(ValueError):validate_registry(registry)

if __name__=='__main__':unittest.main()
