-- IDEA: attach this file to the PostgreSQL data source (127.0.0.1:5432/smart_expiry).
SELECT 1 AS connection_ok;
SELECT current_database(), current_user, version();
SELECT version, description, success FROM flyway_schema_history ORDER BY installed_rank;
SELECT id, name, type FROM category ORDER BY id;

-- Run after Postman request 03 / 07. Request 09 soft-deletes only the test item.
SELECT i.id, i.name, i.lifecycle_status, i.deleted_at,
       b.quantity, b.unit, b.production_date, b.expiry_date
FROM item i
JOIN inventory_batch b ON b.item_id = i.id
WHERE i.name LIKE 'Postman%'
ORDER BY i.created_at DESC;

-- API list excludes rows whose deleted_at is not NULL.
SELECT id, name, lifecycle_status FROM item
WHERE deleted_at IS NULL ORDER BY updated_at DESC;
