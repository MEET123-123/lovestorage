# Algorithm

App 的全部日期、排序、解析、匹配和建议算法集中在 `entry/src/main/ets/algorithm/`。采用 HarmonyOS 模块内目录，使 ArkTS 编译与离线运行不依赖项目外文件。

| 文件 | 用途 |
|---|---|
| `ExpiryService.ets` | 日期与开封期限 |
| `AttentionEngine.ets` / `AttentionRules.ets` | 可解释关注排序 / 生成权重 |
| `RecognitionEngine.ets` | 文字候选、证据与冲突检查 |
| `InventoryDomain.ets` | 库存校验、分类、过滤与统计规则 |
| `SafetyGuard.ets` / `AdviceEngine.ets` | 过期、缺日期、忌口等建议拦截与文案 |
| `EntityMatcher.ets` | 名称、品牌、分类与单位匹配，用户确认后新增批次 |
| `ReminderPlan.ets` / `ReminderTiming.ets` | 多节点提醒与历史时段推荐 |
| `MockForecast.ets` | 明确标记的固定速率 Mock 预测 |

共享权重和 Golden 样例放在本目录 `contracts/`，来源为后端分支 `algorithm/contracts/`；OpenAPI 仍放在 `contract/`。不要手改生成的 AttentionRules。

```powershell
python scripts/sync_contracts.py --server-dir ../lovestorage
python scripts/sync_expiry_fixture.py
node scripts/test-contracts.cjs
node scripts/test-frontend.cjs
```

提醒时段来自近 90 天有效处理记录，至少 5 次、覆盖 3 天才采用历史规则，否则推荐 09:00；只在用户确认后修改提醒时段。Mock 余量不会更改库存或有效期限。

首页展示与处理反馈保存到账号本地 `algorithm_decision` 表，通过事务事件队列同步；“我的 → 算法调试”可查看最近决策、原因和反馈。离线数据集与模型清单在后端 `algorithm/`，无需在手机安装 Python。
