# V2.0 实施状态与 Attention 契约附录

日期：2026-10-04。当前变更为工作区实现，应用版本仍为 0.4.0 本地候选版，未发布。

主设计统一使用 [SmartExpiry Technical Design V2.0](SmartExpiry_Technical_Design_V2.0.md)。旧设计留在 ChangeLog 目录作为历史资料，不再扩展连续版本的大型设计文档。本附录记录实现状态和本轮接口规则。

## 本轮实现

- 主导航收敛为“今天 / 物品 / 我的”，中央加号保留录入；建议和补货清单从今天页进入。
- Today 使用本地库存计算可解释的 Attention 排序，优先卡片展示具体原因和处理操作；处理后可撤销最近一次动作。
- 今日动作通过 ViewModel → UseCase → Repository 保存，先更新界面，再写本地事务；写入失败重新加载本地数据。
- 用完/丢弃写入既有处理流水，撤销恢复在库并撤销有效流水。稍后提醒只修改本地 snooze，不改变数量或有效期限。
- 本地写入与撤销均检查更新时间；再次编辑后不能用旧撤销覆盖新数据。规则异常退回到本地日期排序。
- Java 提供认证接口 `GET /api/v1/attention?limit=10`；只访问当前用户未删除库存。客户端 Today 不依赖此接口，离线仍可排序和处理。
- 两端共用 `attention-rules.json` 的基线权重与 19 个 Golden 样例；保留原 expiry / recognition 样例。
- 过期卡片提示停止使用并提供记录丢弃操作；忌口命中后不再追加食用建议。优先级不等于安全等级。

## Attention 规则

`algorithm/contracts/attention-rules.json` 是基线配置真源。前端同步到 `algorithm/contracts/` 后生成 `AttentionRules.ets`，不要手工修改生成文件。Java 打包相同 JSON；可用 `smart-expiry.attention.rules-location` 指定外部 `file:` 配置，需与客户端协同版本、测试后发布。配置无效时服务端启动失败，避免静默使用未知规则。

| 条件 | 基线分数 / 加分 |
|---|---:|
| 已过期 / 今天 / 明天 / 2 天 / 3 天 | 100 / 90 / 80 / 70 / 60 |
| 4–7 天 | 40 |
| 超过 7 天但进入分类提醒窗口 | 10 |
| 日期未知 | 20，要求补日期，不视为安全 |
| 已开封 | +10 |
| 开封后期限 0–7 天内到期 | +15 |
| 稍后提醒到期重新出现 | +5 |
| 数量至少 3（使用用户记录的单位） | +5 |

HIGH ≥80，MEDIUM ≥40，其他 LOW。分数是可加和的关注权重，不是概率；UI 显示原因与等级。已删除、非 ACTIVE、非正数量、未来 snooze 的记录不进入 Today。相同分数按有效到期日期、ID 稳定排序。分类窗口：食品 7 天、个护 30 天、宠物粮 14 天、其他 7 天；用户显式设置提醒天数优先。

服务端与客户端均选择 ACTIVE 批次的最早有效到期日，并累计在库余量。完整库存同步携带 snooze 与提醒设置；未同步编辑仍以本地 Today 为准。

## 本地验证与联调

后端：`scripts/build.ps1` 执行 Maven verify；前端：`scripts/test-contracts.cjs`、`scripts/test-frontend.cjs`、`scripts/test-login.cjs` 以及 `scripts/build.ps1` / `-TestHap`。

前端更新工作区契约时执行：

```powershell
python scripts/sync_contracts.py --server-dir ../lovestorage
python scripts/sync_expiry_fixture.py
```

默认联网同步指向 `MEET123-123/lovestorage` 的 `split-server` 分支。尚未推送的服务端契约使用 `--server-dir`，避免读到旧远程版本。

Postman 重新导入服务端集合，选择实际运行的 IDEA / Docker 环境，先注册或登录，再运行 `14 今日关注排序`。`limit` 合法范围为 1–50。测试账号库存为空时响应为空数组；401 要重新登录，400 要检查 limit。健康检查仍为 `/api/v1/health`。

本轮增加本地数据库 v3 迁移与服务端 Flyway V5，备份升级为 schemaVersion 2 并兼容旧版恢复。升级前请备份数据库。HAP 为未签名构建产物，界面、原生 ArkData 和系统提醒触发仍需 DevEco 真机验收。

### 本轮实际验证

- Maven verify：14 个测试方法，0 失败 / 0 错误；含 19 个 Attention Golden 样例、稳定排序、账号隔离、处理后排除、参数边界、宠物粮默认窗口一致性。
- 前端领域/存储：90 项检查通过，覆盖共享样例、写入失败回滚、旧版本拒绝覆盖、处理流水撤销、稍后提醒撤销和规则异常降级。
- 契约检查：9 个 expiry 样例、2 个自然月/年边界，OpenAPI / recognition / Attention 快照及生成权重一致。
- 登录与账号切换检查通过；应用 HAP 与测试 HAP 构建成功。新增原生 Attention 测试已编译，未在设备执行。
- OpenAPI YAML 已解析；Postman JSON 有效；打包 JAR 中的规则资源与共享配置完全相同。

以上是主机测试与构建证据，不代表真机提醒、真实 OCR Benchmark 或生产验收已经完成。

## 与 V2.0 的剩余差距

| 阶段 | 已有基础 | 下一步 |
|---|---|---|
| Product Foundation | 本地库存、自然日期与 PAO、今天、基础提醒、处理流水 | 已实现 Item 1:N Batch、部分消耗、撤销和多节点提醒；登录离线重入仍待设计 |
| Smart Capture | 文本解析、候选及人工确认 | 已有独立草稿列表、候选证据、人工编辑确认和 Mock OCR/ASR/条码入口；真实 Provider、图片质量检查待接入 |
| Action Intelligence | Attention Rule 与原因码、本地模板及忌口提示 | 已补齐结构化拦截、精确实体匹配与历史提醒时段；语义匹配和真实模型仍待数据 |
| Sync / Data Loop | 完整多批次双向同步、版本冲突选择、事件 Envelope、事务 Outbox / 幂等消费 | 已有决策与反馈关联及事件积压查询；生产容量、告警和跨设备流水同步待完善 |
| Benchmark / ML | 固定共享规则样例 | 已有离线 Dataset Builder、时间切分与 Mock Registry 校验；真实包装评测、ONNX 和线上灰度需实际数据与服务 |

既有 Index / Login 的其他流程仍有页面直接调用 Repository / API，需要逐步迁入 ViewModel / UseCase；本轮仅将新增的今日动作按 V2 边界实现。

固定 Golden 用例不是 500–1000 张真实包装 Benchmark，也不能证明真实 OCR 准确率。当前没有引入 Redis、对象存储、在线 Python Serving 或复杂消息平台。

## 2026-10-04：多批次、同步与 Mock 调试

- 物品详情 → 批次管理：新增同单位批次、按批次部分消耗/丢弃、撤销；多批次物品的合计数量在详情编辑页不可直接改写。
- 底部 ＋ → 智能录入：Mock 拍照/语音/条码或真实文字解析生成持久化草稿；人工核对并在编辑页保存后才加入库存。Mock 不调用硬件，不表示真实识别准确率。
- 我的 → 算法调试：显示真实 Attention 规则结果与忌口提示；预测和模型时段为明确标记的固定 Mock 样例，不参与正式决策。
- 我的 → 同步冲突：选择保留本机或采用云端，双方再次修改时需重新同步；同步包括全部批次、备注、提醒、开封、删除状态。处理流水与补货清单仍走完整备份，不声称已经增量同步。
- 默认食品提醒 7/3/1 天、个护 30/7/1 天、宠物粮 14/7/3 天；手动提前天数覆盖为单节点。系统最多注册最近 20 条，真机触发待验收。
- 新接口 `/api/v1/sync/inventory`、`/{id}` 与 `/api/v1/events` 均使用登录 Bearer。重新导入 Postman 集合，在登录后测试 15–18 项；IDEA 环境 baseUrl 填 `http://localhost:18081`。
- 事件队列与库存写入同事务，上传重复 eventId 不重复生成事实；原始 OCR、语音、备注不会进入事件属性。尚未接真实模型训练、Model Registry、灰度发布和真实包装 Benchmark。

最终主机验证：Maven verify 14 项测试、0 失败；前端领域与存储 90 项检查；契约与登录检查通过；应用 HAP 与测试 HAP 均构建成功。新增同步测试覆盖多批次数量、版本冲突、重复重试、跨账号回滚；事件测试覆盖重复投递与迟到事件时间。未运行真机 UI / 通知触发测试。

## 2026-10-04 后续补全：算法目录与云部署

- 算法运行时代码分别位于前端 `entry/src/main/ets/algorithm` 与后端 `src/main/java/com/smartexpiry/algorithm`；共享规则/样例统一为 `algorithm/contracts`。后台根目录 `algorithm/offline` 包含可运行的 Dataset Builder 和 Mock 评测，`algorithm/model-registry.json` 显式阻止 Mock 进入 ACTIVE/CANARY。
- 新增结构化 SafetyGuard，忌口或过期等条件先拦截使用建议；首页不再给忌口命中卡片显示快捷“已用完”按钮，可进入详情核对。
- 名称/品牌/分类/单位匹配后由用户确认追加批次；支持草稿删除与独立批次编辑；修正统计页部分消耗误显示为丢弃及占比计算。
- 近 90 天处理记录可推荐提醒时段，最低 5 次并覆盖 3 天；用户选择后才应用。Mock 库存保留标记，不匹配到真实库存，决策事件也保留 Mock 标记。
- 本地数据库新增 v4 决策日志；首页前 10 条的展示按物品版本、日期与规则去重，反馈通过事件 Outbox 上传。事件状态与分页导出接口支持当前账号的离线评测，原始识别内容、名称、备注不会作为事件字段导出。
- 部署提供生产 profile 检查、仅后端的云 Compose、可选 Caddy HTTPS、数据库连接检查、备份与发布打包脚本。完整步骤见 CLOUD_DEPLOYMENT.md；实际服务器类型/数据库版本待确认，未执行远程部署。

仍需真实环境完成：OCR/ASR 与华为/短信服务配置、HarmonyOS 签名和真机通知/权限验收、真实 PostgreSQL 容量与并发验收、真实包装 Benchmark、模型训练和线上灰度平台。离线评测和模型清单已可运行，但不把 Mock 报告当作真实准确率或上线认证。
