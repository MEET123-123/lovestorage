# 前后端联调协议

## 契约所有权

当前同一 GitHub 仓库的 `split-server` 分支是 API 契约与跨端规则的真源；主设计见 [V2.0](SmartExpiry_Technical_Design_V2.0.md)：

- `openapi/smart-expiry-v1.yaml`
- `algorithm/contracts/expiry-test-cases.json`
- `algorithm/contracts/recognition-test-cases.json`
- `algorithm/contracts/attention-rules.json` / `algorithm/contracts/attention-test-cases.json`

本仓 `contract/` 为只读快照，正常情况下通过 `scripts/sync_contracts.py` 更新。

## 联调流程

1. 后端在 feature branch 修改 OpenAPI，并完成实现与测试。
2. 后端更新 `split-server`，必要时创建 `contract-vX.Y.Z` tag。前端在 `split-app` 开发。
3. 前端执行 `python3 scripts/sync_contracts.py`。
4. 前端提交 contract snapshot 更新及 API Client 适配。
5. 双方针对同一后端 commit/tag 进行联调。

尚未推送的工作区契约可以执行 `python scripts/sync_contracts.py --server-dir ../lovestorage`。该脚本先读取所有契约再写快照，并自动生成 Attention 权重；随后执行 `python scripts/sync_expiry_fixture.py` 更新 expiry 测试夹具。

## 环境建议

- local: 开发者机器 Spring Boot，端侧通过局域网 IP 访问。
- dev: 团队共享开发环境。
- staging: 发布前联调/回归。

客户端禁止将 `127.0.0.1` 作为真机访问后端地址；真机联调应配置开发机局域网 IP 或共享 dev URL。
