.PHONY: db-up db-down backend-test backend-run sync-fixtures verify-fixtures verify

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

backend-test:
	cd backend && ./mvnw test

backend-run:
	cd backend && ./mvnw spring-boot:run

sync-fixtures:
	python3 scripts/sync_shared_fixtures.py

verify-fixtures:
	python3 scripts/verify_shared_fixtures.py

verify: verify-fixtures backend-test
