# 前端联调说明

前端仓库：`MEET123-123/lovestorage-app`

## 契约真源

- HTTP：`openapi/smart-expiry-v1.yaml`
- Expiry 规则：`algorithm/contracts/expiry-test-cases.json`

后端合并契约变更后，前端通过其 `scripts/sync_contracts.py` 更新快照。

## M1 REST

- `GET /api/v1/health`
- `GET /api/v1/categories`
- `POST /api/v1/items`
- `GET /api/v1/items`
- `GET /api/v1/items/{itemId}`
- `PATCH /api/v1/items/{itemId}`
- `PUT /api/v1/items/{itemId}`：PATCH 的部分更新兼容入口，用于 HarmonyOS API 20。
- `DELETE /api/v1/items/{itemId}`

后续 M2 的 Reminder 接口同样遵循 OpenAPI-first。

创建时可传 `clientId`（UUID），重试返回已存在物品；已软删除 ID 返回 404，不会复活。
更新可传 `lifecycleStatus`。未传或 null 字段保持原值。
到期状态响应字段为 `expiryStatus`；生产日期和保质期变化时会重算到期日期。
当前前端同步为显式单设备上传，不提供拉取与冲突合并。仅建议用于本地开发联调。
