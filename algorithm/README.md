# Algorithm

算法与业务接口分开维护，部署仍使用同一个 Spring Boot JAR，不需要单独的 Python 在线服务。

| 位置 | 内容 |
|---|---|
| `src/main/java/com/smartexpiry/algorithm/expiry/` | 自然日期、月末截断、开封后期限 |
| `src/main/java/com/smartexpiry/algorithm/attention/` | 可解释的关注排序 |
| `src/main/java/com/smartexpiry/algorithm/recognition/` | 带证据的文本候选解析 |
| `algorithm/contracts/` | 算法规则、跨语言 Golden 样例，替代旧 `shared/` |
| `algorithm/offline/` | 标准库 Dataset Builder、按时间划分的评测基线 |
| `algorithm/model-registry.json` | 当前规则与 Mock 模型清单；Mock 不允许 ACTIVE/CANARY |
| `src/test/java/com/smartexpiry/algorithm/` | Java 算法回归测试 |

前端运行时代码位于前端分支的 `entry/src/main/ets/algorithm/`，包括 SafetyGuard、EntityMatcher、ReminderTiming、MockForecast。接口控制器、登录、库存事务、数据库访问仍留在业务包，算法包不负责调用网络或提交库存。

## 离线闭环演示

在后端项目根目录执行，Python 3.10+，无需安装第三方包：

```powershell
python algorithm/offline/pipeline.py mock-events --output algorithm/output/mock-events.json
python -c "from pathlib import Path; import secrets; p=Path('algorithm/output/mock-salt.bin'); p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(secrets.token_bytes(32))"
python algorithm/offline/pipeline.py build-dataset --events algorithm/output/mock-events.json --as-of 2026-06-01T00:00:00Z --subject mock-account --salt-file algorithm/output/mock-salt.bin --output algorithm/output/dataset.json
python algorithm/offline/pipeline.py evaluate --dataset algorithm/output/dataset.json --output algorithm/output/report.json
python algorithm/offline/pipeline.py check-registry
python -m unittest discover -s algorithm/offline -p 'test_*.py'
```

`output/` 不提交 Git。示例事件、评测报告始终标记 `mock=true`，报告标记 `promotable=false`，不会自动部署模型。当前仅有基线评测和 Registry 校验，并未连接 ONNX、真实训练或服务端灰度流量控制。

## 真实事件导出

登录后 `GET /api/v1/events/status` 查看自己的积压与发布数。`GET /api/v1/events/export?limit=500` 分页导出自己的已发布事件；收到非空 `nextCursor` 时传 `after=<nextCursor>` 获取下一页，直到为空。Postman 将各页响应保存为 JSON，再把这些文件同时传给 `--events page1.json page2.json`。数据集应在记录采集完成后使用固定 `as-of`，不同账号分别导出与使用稳定 subject 标识，不共享其他账号的令牌。

Dataset Builder 会：

- 用 HMAC 隐去 subject，不保留名称、备注、原始识别内容和 itemId。真实 salt 应独立安全保存，不放到数据集旁对外共享。
- 按 `eventId` 去重，冲突重复报错；只有 `occurredAt` 与 `recordedAt` 均不晚于 as-of 的事件可进入数据集。
- 只用决策展示时的特征；观察窗口为 7 天，未成熟样本不参与评测，撤销会使相应处理标签失效。
- 按时间划分训练、验证、测试，并清除标签观察窗口跨越切分边界的样本，避免未来信息泄漏。
- 报告常数行为率基线的 Brier 分数与各组样本数。未收到反馈仅表示未观察到处理，不代表用户没有处理。

算法目录调整不改变 REST 路径。变更规则后先跑共享样例，前端执行 `scripts/sync_contracts.py --server-dir ../lovestorage` 同步，再同时发布兼容版本。
