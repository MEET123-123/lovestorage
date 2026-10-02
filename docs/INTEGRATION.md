# 前后端联调协议

## 契约所有权

`lovestorage-server` 是 API 契约与跨端 expiry 规则的 Source of Truth：

- `openapi/smart-expiry-v1.yaml`
- `shared/expiry-test-cases.json`

本仓 `contract/` 为只读快照，正常情况下通过 `scripts/sync_contracts.py` 更新。

## 联调流程

1. 后端在 feature branch 修改 OpenAPI，并完成实现与测试。
2. 后端合并 `main`，必要时创建 `contract-vX.Y.Z` tag。
3. 前端执行 `python3 scripts/sync_contracts.py`。
4. 前端提交 contract snapshot 更新及 API Client 适配。
5. 双方针对同一后端 commit/tag 进行联调。

## 环境建议

- local: 开发者机器 Spring Boot，端侧通过局域网 IP 访问。
- dev: 团队共享开发环境。
- staging: 发布前联调/回归。

客户端禁止将 `127.0.0.1` 作为真机访问后端地址；真机联调应配置开发机局域网 IP 或共享 dev URL。
