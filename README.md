# lovestorage-app

HarmonyOS 前端独立仓库。基于 ArkTS + ArkUI + Stage 模型，M1 采用 Local-First，支持 ArkData 本地物品 CRUD 与跨端一致的保质期规则。

## 仓库职责

- 负责 HarmonyOS UI、交互、ArkData、本地提醒、相机/OCR/语音等端侧能力。
- 通过 `contract/` 消费后端 API 契约，不在前端自行发明接口字段。
- `contract/smart-expiry-v1.yaml` 与 `contract/expiry-test-cases.json` 是后端仓契约的快照。
- 契约真源位于公开仓库 `MEET123-123/lovestorage-server`。

## 目录

```text
AppScope/
entry/
hvigor/
contract/
  smart-expiry-v1.yaml
  expiry-test-cases.json
scripts/
  sync_contracts.py
  sync_expiry_fixture.py
docs/
  INTEGRATION.md
.github/workflows/
```

## 本地开发

1. 使用 DevEco Studio 打开仓库根目录。
2. 配置 HarmonyOS SDK 与自动签名。
3. 运行 `entry` 模块。
4. M1 默认使用 ArkData，本地无后端也可开发页面和业务规则。

## 同步后端契约

```bash
python3 scripts/sync_contracts.py
python3 scripts/sync_expiry_fixture.py
```

第一条命令从 `lovestorage-server/main` 更新 OpenAPI 和共享 expiry 用例；第二条命令重新生成 ArkTS 测试 fixture。

## 联调约定

- 本地 Mock / ArkData 开发：后端不必启动。
- REST 联调：修改 `entry/src/main/ets/data/remote/ApiClient.ets` 的 `baseUrl`。
- 接口变更：后端先更新 OpenAPI，前端同步 contract 后再改调用代码。
- 禁止前端仅根据口头约定新增/修改 API 字段。

## 分支

- `main`：稳定可运行。
- `feature/<topic>`：功能开发。
- `fix/<topic>`：缺陷修复。
- 联调版本使用 tag，例如 `integration-v0.2.0`。
