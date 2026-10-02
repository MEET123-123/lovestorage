# 前端联调说明

前端仓库：`MEET123-123/lovestorage-app`

## 契约真源

- HTTP：`openapi/smart-expiry-v1.yaml`
- Expiry 规则：`shared/expiry-test-cases.json`

后端合并契约变更后，前端通过其 `scripts/sync_contracts.py` 更新快照。

## M1 REST

- `GET /api/v1/health`
- `GET /api/v1/categories`
- `POST /api/v1/items`
- `GET /api/v1/items`
- `GET /api/v1/items/{itemId}`
- `PATCH /api/v1/items/{itemId}`
- `DELETE /api/v1/items/{itemId}`

后续 M2 的 Reminder 接口同样遵循 OpenAPI-first。
