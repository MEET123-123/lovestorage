CREATE TABLE user_profile (
  user_id VARCHAR(36) PRIMARY KEY REFERENCES app_user(id),
  display_name VARCHAR(40) NOT NULL,
  avatar_key VARCHAR(24) NOT NULL,
  bio VARCHAR(120) NOT NULL,
  allergies TEXT NOT NULL,
  dislikes TEXT NOT NULL,
  preferences TEXT NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE login_identity (
  provider VARCHAR(24) NOT NULL,
  subject VARCHAR(128) NOT NULL,
  user_id VARCHAR(36) NOT NULL REFERENCES app_user(id),
  PRIMARY KEY(provider, subject)
);
