CREATE TABLE app_user (
  id VARCHAR(36) PRIMARY KEY,
  username VARCHAR(32) NOT NULL UNIQUE,
  password_hash VARCHAR(256) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE auth_session (
  token_hash VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL REFERENCES app_user(id),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_session_user ON auth_session(user_id);
CREATE INDEX idx_session_expiry ON auth_session(expires_at);
-- Legacy rows stay unassigned: never give old shared data to the first registrant.
ALTER TABLE item ADD COLUMN owner_id VARCHAR(36) REFERENCES app_user(id);
CREATE INDEX idx_item_owner_updated ON item(owner_id, updated_at DESC);
