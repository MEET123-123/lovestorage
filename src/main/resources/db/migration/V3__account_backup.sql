CREATE TABLE account_backup (
  user_id VARCHAR(36) PRIMARY KEY REFERENCES app_user(id),
  revision BIGINT NOT NULL,
  payload TEXT NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
