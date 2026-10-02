# Team Collaboration Baseline

## Branch

- `main`: 可运行主干。
- `feature/<scope>-<topic>`: 功能分支。
- `fix/<scope>-<topic>`: 缺陷修复。

## Contract-first

接口修改顺序：

1. 修改 `openapi/smart-expiry-v1.yaml`。
2. 评审 request / response / error code。
3. 后端实现。
4. HarmonyOS 联调。
5. 更新契约测试。

禁止客户端和服务端私自增加同名字段的不同语义。

## Shared expiry rules

保质期状态属于跨端规则：

```text
shared/expiry-test-cases.json
```

任何规则变化必须同时满足：

- Java `ExpiryServiceContractTest` 通过。
- 重新生成 ArkTS `ExpiryFixtures.ets`。
- HarmonyOS ExpiryService 测试通过。

## Commit scope

推荐：

```text
feat(app): ...
feat(server): ...
feat(contract): ...
fix(app): ...
fix(server): ...
test(shared): ...
chore(build): ...
```
