CREATE TABLE category (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  type VARCHAR(32) NOT NULL,
  is_system BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE item (
  id VARCHAR(36) PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  category_id VARCHAR(64) NOT NULL REFERENCES category(id),
  brand VARCHAR(120),
  lifecycle_status VARCHAR(32) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE,
  version BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE inventory_batch (
  id VARCHAR(36) PRIMARY KEY,
  item_id VARCHAR(36) NOT NULL REFERENCES item(id),
  quantity NUMERIC(12, 3) NOT NULL DEFAULT 1,
  unit VARCHAR(32),
  production_date DATE,
  expiry_date DATE,
  shelf_life_value INTEGER,
  shelf_life_unit VARCHAR(16),
  opened_date DATE,
  after_open_value INTEGER,
  after_open_unit VARCHAR(16),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX idx_item_category ON item(category_id);
CREATE INDEX idx_item_updated ON item(updated_at DESC);
CREATE INDEX idx_item_deleted ON item(deleted_at);
CREATE INDEX idx_batch_expiry ON inventory_batch(expiry_date);
CREATE INDEX idx_batch_item ON inventory_batch(item_id);

INSERT INTO category(id, name, type, is_system) VALUES
  ('food', '食品', 'FOOD', TRUE),
  ('cosmetics', '化妆品', 'COSMETICS', TRUE),
  ('pet_food', '宠物粮', 'PET_FOOD', TRUE),
  ('other', '其他', 'OTHER', TRUE);
