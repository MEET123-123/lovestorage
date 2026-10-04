ALTER TABLE item ADD COLUMN sync_payload TEXT;
ALTER TABLE item ADD COLUMN sync_fingerprint VARCHAR(64);
ALTER TABLE inventory_batch ADD COLUMN lifecycle_status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE';
UPDATE inventory_batch SET lifecycle_status=(SELECT lifecycle_status FROM item WHERE item.id=inventory_batch.item_id);
CREATE TABLE event_outbox (
  event_id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL REFERENCES app_user(id),
  event_type VARCHAR(64) NOT NULL,
  event_version VARCHAR(16) NOT NULL,
  occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
  properties TEXT NOT NULL,
  published_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX idx_outbox_pending ON event_outbox(published_at,recorded_at);
CREATE TABLE behavior_event (
  event_id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL REFERENCES app_user(id),
  event_type VARCHAR(64) NOT NULL,
  event_version VARCHAR(16) NOT NULL,
  occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
  properties TEXT NOT NULL
);
