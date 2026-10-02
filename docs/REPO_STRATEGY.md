# Monorepo / 双仓策略

## M1 推荐：monorepo 为真源

M1 阶段 API 与保质期规则变化频繁，优先保持：

```text
harmonyos/ + backend/ + openapi/ + shared/
```

在一个 PR 中原子修改，最容易保证联调一致性。

## 需要双仓时

可拆成：

```text
smart-expiry-app
├── harmonyos/
├── shared/        # contract snapshot / submodule
└── scripts/

smart-expiry-server
├── backend/
├── openapi/
├── shared/        # contract source or submodule
└── docker-compose.yml
```

长期建议把 `openapi/ + shared/` 提升成独立 contract 仓或制品，而不是在 App/Server 两边手工复制。

## 规则

1. OpenAPI 是 HTTP 契约真源。
2. `shared/expiry-test-cases.json` 是跨端保质期规则真源。
3. 若双仓暂时镜像 `shared/`，合并前必须比较 SHA256。
4. 客户端和后端不得各自疰增“本地特例”而不进入共享 fixture。
