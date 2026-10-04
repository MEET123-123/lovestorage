# SmartExpiry 智能保质期管理

## 技术设计 V2.0 — 收敛版

**HarmonyOS + Spring Boot + Smart Intelligence**

---

# 1. 文档定位

本文件是 SmartExpiry 项目的主技术设计文档。

它统一替代此前分散的：

```text
Technical Design V1.2
UI / UX Design V1.3
HarmonyOS UI Design V1.4
Smart Intelligence V1.5
V1.5.1 ~ V1.5.6
```

后续原则：

```text
一个主设计
+
少量接口 / Schema / Test Case 附录
```

而不是继续：

```text
V1.5.7
V1.5.8
V1.5.9
...
```

---

# 2. 产品目标

SmartExpiry 是面向个人与家庭的：

> 智能物品生命周期与保质期管理应用。

核心对象包括：

- 食品
- 化妆品
- 宠物粮
- 自定义物品

核心能力：

```text
快速录入
→
自动识别
→
库存管理
→
到期计算
→
临期提醒
→
优先级排序
→
处理建议
→
消费 / 丢弃反馈
→
持续学习
```

产品最终希望解决：

> 用户不需要自己记住“家里有什么、什么时候过期、今天应该先处理什么”。

---

# 3. 核心产品原则

整个系统遵循六个原则。

## 3.1 Local-First

本地负责：

```text
库存 CRUD
状态计算
基础排序
基础提醒
```

即使：

```text
断网
服务器异常
AI 不可用
```

核心库存管理仍然能够使用。

---

## 3.2 Deterministic First

确定性业务规则必须由代码完成：

```text
到期日期计算
PAO
ExpiryStatus
库存数量
生命周期
提醒合法性
日期冲突
安全规则
```

禁止交给 LLM 决定。

---

## 3.3 AI Removes Work

AI 的目标不是：

> 增加一个 AI 页面。

而是：

> 减少用户输入与判断。

因此：

```text
识别结果
→
ItemDraft
→
异常确认
→
正式 Item
```

而不是 AI 直接写正式库存。

---

## 3.4 Action First

用户进入 App 最重要的不是：

```text
查看很多数据
```

而是：

```text
知道今天该处理什么
并且立即行动
```

因此首页设计成：

> Today / 今日中心。

---

## 3.5 Safety First

优先级：

```text
Safety Rule
>
Business Rule
>
Prediction / Ranking
>
LLM
```

LLM 不允许覆盖安全规则。

---

## 3.6 Graceful Degradation

所有智能能力必须存在：

```text
Primary
↓
Fallback
↓
Basic Function
```

保证 AI 不是单点故障。

---

# 4. 总体架构

```text
┌──────────────────────────────┐
│       HarmonyOS Client       │
│                              │
│ ArkUI                        │
│ ViewModel                    │
│ UseCase                      │
│ Domain                       │
│ Repository                   │
│ ArkData                      │
│ Reminder                     │
└──────────────┬───────────────┘
               │
               │ REST / Sync
               ↓
┌──────────────────────────────┐
│       Spring Boot Backend    │
│                              │
│ Controller                   │
│ Application                  │
│ Domain                       │
│ Repository                   │
│ Intelligence                 │
│ Sync                         │
│ Notification                 │
└──────┬────────┬──────────────┘
       │        │
       ↓        ↓
 PostgreSQL   Redis
       │
       ↓
 Object Storage

               +

┌──────────────────────────────┐
│   Smart Intelligence Layer   │
│                              │
│ Recognition                  │
│ Entity Resolution            │
│ Attention                    │
│ Reminder                     │
│ Suggestion                   │
│ Forecast                     │
└──────────────┬───────────────┘
               │
               ↓
       Rule / ONNX / AI API
```

当前阶段不拆复杂微服务。

后端继续：

```text
Modular Monolith
```

智能算法也是后端模块的一部分。

---

# 5. 技术栈

## HarmonyOS

```text
ArkTS
ArkUI
ArkData
Ability
Notification
Camera
Local Storage
```

## Backend

```text
Java 21
Spring Boot
Spring MVC
Spring Security
Spring Data
Flyway
PostgreSQL
Redis
Object Storage
```

## Intelligence

```text
Python
Pydantic
Pandas
Scikit-learn
ONNX
OCR / LLM Provider
```

## Testing

```text
JUnit
Pytest
Contract Test
Golden Test
E2E
Benchmark
```

---

# 6. 客户端架构

统一采用：

```text
Page
↓
Component
↓
ViewModel
↓
UseCase
↓
Domain
↓
Repository
↓
ArkData / Remote
```

禁止：

```text
ArkUI Page
→
直接访问数据库 / API
```

---

# 7. HarmonyOS 页面结构

主导航只保留：

```text
今天
物品
我的
```

中央：

```text
+
```

负责录入。

核心页面：

```text
TodayPage

InventoryPage

SmartCapturePage

DraftConfirmPage

ManualEntryPage

ItemDetailPage

BatchCapturePage

ProfilePage
```

---

# 8. Today 首页

Today 回答三个问题：

```text
今天有什么要处理？

最重要的是哪一个？

我现在应该做什么？
```

第一屏：

```text
今天有 4 件物品需要关注

鲜牛奶
明天到期

建议今天优先处理

[已用完] [稍后提醒]
```

常用操作：

```text
Today
→
直接完成
```

不要求：

```text
Today
→
详情
→
编辑
→
操作
```

---

# 9. UI 状态原则

每一个核心页面至少设计：

```text
Loading
Success
Empty
Error
Offline
Partial Success
```

低风险动作采用：

```text
Optimistic UI
+
Undo
```

例如：

```text
已用完
```

直接更新，

随后：

```text
已标记为用完    撤销
```

删除等不可逆操作才需要确认。

---

# 10. 录入架构

录入优先级：

```text
拍照
>
语音
>
手动
>
扫码
```

中央 +：

```text
拍照识别

语音添加

手动添加

扫码

连续录入
```

AI 是默认路径，

不是隐藏在二级菜单中的辅助功能。

---

# 11. Recognition Pipeline

统一识别流程：

```text
Image / Voice
↓
Quality Check
↓
OCR / ASR
↓
Candidate Extraction
↓
Date Parser
↓
Semantic Parse
↓
Confidence Fusion
↓
Business Validation
↓
ItemDraft
↓
User Confirmation
↓
Item / InventoryBatch
```

---

# 12. ItemDraft

任何智能识别结果：

禁止直接：

```text
CREATE Item
```

必须：

```text
AI Result
↓
ItemDraft
↓
Confirm
↓
Formal Item
```

Draft 字段至少包含：

```text
value

confidence

source

evidence

validationIssue
```

---

# 13. Confidence

统一：

```text
HIGH
MEDIUM
LOW
```

算法内部保留：

```text
0 ~ 1
```

UI 不显示：

```text
0.7823
```

而显示：

```text
HIGH
→ 默认接受

MEDIUM
→ 请确认

LOW
→ 需要补充
```

推荐基线：

```text
>= 0.90    HIGH

0.60~0.90  MEDIUM

< 0.60     LOW
```

---

# 14. 核心领域模型

核心模型：

```text
Item
InventoryBatch
ItemDraft
Reminder
ConsumptionRecord
Suggestion
RecognitionRecord
```

关系：

```text
Item
1
│
N
InventoryBatch
```

Item 表示：

> 商品/物品本体。

InventoryBatch 表示：

> 实际库存批次。

---

# 15. 为什么必须有 Batch

例如：

```text
纯牛奶
```

同时有：

```text
Batch A
2盒
10月5日到期

Batch B
1盒
10月12日到期
```

不能只用一个：

```text
Item.expiryDate
```

否则无法正确处理：

```text
多批次
不同到期日期
部分消耗
```

---

# 16. 生命周期

库存生命周期至少：

```text
ACTIVE

CONSUMED

DISCARDED

DELETED
```

其中：

```text
CONSUMED
```

表示现实中已经用完。

```text
DISCARDED
```

表示现实中丢弃。

```text
DELETED
```

表示记录错误。

三者不可混淆。

---

# 17. 到期状态

统一：

```text
UNKNOWN
NORMAL
NEAR_EXPIRY
EXPIRED
```

有效到期日：

```text
effectiveExpiry =
min(
  originalExpiry,
  openedDate + afterOpenDuration
)
```

适用于存在开封有效期的物品。

---

# 18. 日期计算

统一使用自然日期语义。

例如：

```text
1 MONTH
```

必须：

```text
plusMonths(1)
```

而不是：

```text
plusDays(30)
```

所有：

```text
ExpiryService
```

逻辑前后端必须共享：

```text
expiry-test-cases.json
```

---

# 19. Local-First 数据流

新增 Item：

```text
User
↓
UseCase
↓
ArkData
↓
UI immediately updated
↓
Sync Queue
↓
Backend
```

不能：

```text
User
↓
Backend
↓
等待
↓
UI
```

---

# 20. Sync

同步实体统一包含：

```text
id

version

updatedAt

deletedAt
```

客户端保存：

```text
dirty state
```

或独立：

```text
sync_queue
```

冲突：

```text
version conflict
```

需要明确：

```text
server / local reconciliation
```

---

# 21. 智能化总体结构

```text
Inventory
+
User Context
+
Behavior
       ↓
FeatureService
       ↓
Rule / Model
       ↓
Safety Guard
       ↓
Decision
       ↓
ReasonCode
       ↓
UI
       ↓
User Action
       ↓
Behavior Event
```

V1.5 重点只有：

```text
Recognition

Entity Resolution

Attention

Reminder

Suggestion
```

消费预测和补货预测属于增强能力。

---

# 22. Entity Resolution

解决：

> 这个新识别出来的商品是否已经存在？

输入：

```text
barcode
name
brand
packageSize
```

第一阶段：

```text
barcode
+
normalized text similarity
```

即可。

即使是同商品：

新的日期：

```text
→ new InventoryBatch
```

不能覆盖旧 Batch。

---

# 23. Attention Engine

Attention 决定：

> Today 页先展示什么。

注意：

```text
Attention Priority
≠
Food Safety Level
```

第一阶段：

```text
AttentionScore =
ExpiryUrgency
+
OpenedWeight
+
PAOWeight
+
SnoozeWeight
+
QuantityWeight
```

例如：

```text
EXPIRED       100
TODAY          90
1 DAY          80
2 DAYS         70
3 DAYS         60
4~7 DAYS       40
```

附加：

```text
Opened       +10
PAO near     +15
Snoozed      +5~10
```

权重必须配置化。

---

# 24. Attention 输出

统一：

```json
{
  "itemId": "...",

  "score": 87,

  "priority": "HIGH",

  "reasonCodes": [
    "EXPIRES_TOMORROW",
    "OPENED"
  ]
}
```

任何重要智能决策：

都应能回答：

```text
为什么？
```

---

# 25. Attention 演进

按顺序：

```text
Rule
↓
Logistic Regression
↓
GBDT
↓
Learning-to-Rank
```

不要第一版直接上复杂模型。

目标标签：

```text
handledWithin24h
```

---

# 26. Reminder Engine

保留类别默认策略：

```text
食品
7 / 3 / 1 天

化妆品
30 / 7 / 1 天

宠物粮
14 / 7 / 3 天
```

智能层主要学习：

> 用户什么时候最可能处理提醒。

而不是一开始动态改变所有提醒规则。

---

# 27. Reminder 个性化

使用：

```text
Action Hour Distribution

App Open Hour Distribution

Reminder Open Distribution
```

基线：

```text
score(hour) =
0.5 × action
+
0.3 × appOpen
+
0.2 × reminderOpen
```

如果历史不足：

```text
使用默认时间
```

用户显式设置：

```text
永远优先
```

---

# 28. Suggestion Engine

统一：

```text
Candidate Generation
↓
Safety Filter
↓
Ranking
↓
LLM / Template
```

LLM 不直接读取所有库存决定一切。

---

# 29. Suggestion Candidate

使用：

```text
Top K Attention Items
```

形成候选：

```text
单品优先处理

组合处理

检查

补货
```

---

# 30. Safety Filter

必须阻断：

```text
危险过期食品建议

明确过敏冲突

非法生命周期组合

已知禁止行为
```

Safety BLOCK：

后续模型不得恢复该候选。

---

# 31. Suggestion Ranking

第一阶段：

```text
Urgency

ItemsResolved

Preference

Simplicity

HistoricalAcceptance

Diversity
```

使用规则权重即可。

LLM 只负责：

```text
把结构化 Decision
→
变成自然语言
```

---

# 32. LLM 使用范围

适合：

```text
OCR 文本语义理解

Voice Intent

Suggestion Text

Explanation Text
```

禁止：

```text
Expiry Calculation

Inventory Accounting

Lifecycle Decision

Safety Decision
```

所有 LLM：

```text
Structured Output
↓
Schema Validate
↓
Business Validate
↓
Safety Validate
```

---

# 33. LLM Fallback

LLM 故障：

```text
Template
```

例如：

```text
{itemName} 将在 {remainingDays} 天后到期，
建议优先处理。
```

因此：

```text
LLM failure
≠
Suggestion failure
```

---

# 34. 数据事件体系

统一四种事件：

```text
UI Analytics

Business Event

Algorithm Decision

Feedback / Exposure
```

重点：

```text
Click
≠
Business Fact
```

---

# 35. 关键 Business Event

```text
ITEM_CREATED

ITEM_UPDATED

ITEM_CONSUMED

ITEM_PARTIAL_CONSUMED

ITEM_DISCARDED

ITEM_SNOOZED

DRAFT_SAVED

REMINDER_DELIVERED

REMINDER_ACTION

SUGGESTION_ACCEPTED
```

算法训练优先使用：

```text
Business Event
```

而不是按钮点击。

---

# 36. Event Envelope

统一：

```json
{
  "eventId": "...",

  "eventType": "ITEM_CONSUMED",

  "eventVersion": "1.0",

  "occurredAt": "...",

  "recordedAt": "...",

  "userId": "...",

  "sessionId": "...",

  "properties": {}
}
```

必须区分：

```text
occurredAt
```

真实行为时间。

```text
recordedAt
```

服务端收到时间。

Local-First 必须支持：

```text
late arrival
```

---

# 37. Transactional Outbox

服务端业务事件：

```text
Business Transaction
↓
Update Domain Table
+
Insert Outbox
↓
Commit
```

后台：

```text
Outbox
↓
Behavior Event
```

采用：

```text
At-Least-Once
+
Idempotent Consumer
```

---

# 38. 核心 Correlation ID

场景中保留：

```text
recognitionId

draftId

decisionId

reminderId

suggestionId

sessionId
```

从而建立：

```text
Decision
→
Exposure
→
Action
→
Outcome
```

---

# 39. 数据闭环

```text
Behavior Event
↓
Clean Data
↓
Feature Snapshot
↓
Label
↓
Dataset
↓
Train
↓
Evaluation
↓
Model
↓
Decision
↓
User
↓
Behavior Event
```

当前阶段：

```text
PostgreSQL
+
Python Batch
```

即可。

不建设复杂实时数据平台。

---

# 40. 核心 Dataset

只维护：

```text
Recognition

Entity Resolution

Attention

Reminder

Suggestion

Safety
```

每个 Dataset：

```text
datasetVersion

featureVersion

labelVersion

builderVersion
```

---

# 41. Label

Recognition：

```text
Draft Correction

Post-Save Correction
```

Attention：

```text
Handled Within 24h
```

Reminder：

```text
Action Within 2h
```

Suggestion：

```text
Accepted

Resolved Item Count
```

---

# 42. 数据切分

行为模型：

必须：

```text
Time-Based Split
```

优先于：

```text
Random Split
```

任何 Feature：

```text
featureTime
<=
predictionTime
```

禁止未来信息泄漏。

---

# 43. Benchmark

Recognition 第一阶段：

```text
500~1000+
真实包装图片
```

覆盖：

```text
模糊
反光
低光
喷码
小字体
多日期
曲面包装
多语言
```

评测不仅看总体 Accuracy，

还要：

```text
Slice
+
Hard Set
```

---

# 44. Offline Metrics

Recognition：

```text
E2E Draft Accuracy
Date Exact Match
Calibration
```

Attention：

```text
NDCG@K
Precision@K
Recall@K
```

Reminder：

```text
Expected Action Rate
```

Suggestion：

```text
Safety
Relevance
Actionability
Pairwise Preference
```

Forecast：

```text
MAE
```

---

# 45. Online Metrics

核心：

```text
ZeroEditRate

TodayActionRate

ReminderActionRate

SuggestionActionRate

TimelyHandlingRate

DiscardRate
```

北极星：

```text
TimelyHandlingRate
```

---

# 46. Guardrail

必须同时监控：

```text
HighConfidenceWrongRate

PostSaveCorrectionRate

NotificationDisableRate

DiscardRate

SafetyViolation

Latency

FallbackRate
```

不能为了一个指标提升损害整体体验。

---

# 47. Model Runtime

生产支持三种：

```text
Rule

Java / ONNX

Remote AI
```

默认优先：

```text
最便宜
+
最稳定
+
满足体验
```

的实现。

---

# 48. Model Registry

需要：

```text
modelName

modelVersion

featureVersion

schemaVersion

artifactUri

checksum

status

metrics
```

模型文件：

```text
Object Storage
```

数据库只保存 Metadata。

---

# 49. 生命周期

```text
DRAFT

OFFLINE_PASSED

SHADOW

CANARY

EXPERIMENT

ACTIVE

RETIRED

DISABLED
```

禁止：

```text
train
→
直接 active
```

---

# 50. Shadow

Candidate Model：

```text
计算
+
记录
```

但：

```text
不影响用户
```

用于和当前 Production Decision 对比。

---

# 51. Canary

推荐：

```text
1%
→
5%
→
20%
→
50%
```

稳定用户分桶。

观察：

```text
Error

Latency

Fallback

Safety

Business KPI
```

---

# 52. A/B

Canary：

验证：

```text
技术稳定
```

A/B：

验证：

```text
产品价值
```

例如 Attention：

```text
Primary:
TodayActionRate

Guardrail:
DiscardRate
Latency
```

---

# 53. Fallback

Attention：

```text
ML
→
Rule
→
Expiry Sort
```

Reminder：

```text
Personalized
→
User Setting
→
Default
```

Suggestion：

```text
ML
→
Rule
→
Template
```

Recognition：

```text
Cloud
→
Local
→
Manual
```

---

# 54. Reliability

Remote AI 必须：

```text
Timeout

Circuit Breaker

Bulkhead

Rate Limit

Limited Retry
```

AI Thread Pool：

与：

```text
Inventory CRUD
```

隔离。

AI Provider 故障不能拖垮：

```text
CRUD
Reminder
Sync
```

---

# 55. Kill Switch

至少：

```text
recognition_cloud

attention_ml

reminder_personalized

suggestion_ranker

suggestion_llm
```

可以独立关闭。

关闭后：

自动 fallback。

---

# 56. Observability

统一三层。

System：

```text
RPS
Latency
Error
CPU
Memory
DB
Redis
```

Algorithm：

```text
Model Version
Confidence
Decision Distribution
Fallback
Schema Failure
Feature Missing
```

Business：

```text
ZeroEditRate
TodayActionRate
ReminderActionRate
SuggestionActionRate
TimelyHandlingRate
```

---

# 57. 隐私

默认不进入行为日志 / Dataset：

```text
原始语音

完整用户备注

不必要完整 OCR

不必要原始家庭照片
```

优先保存：

```text
结构化字段

匿名行为

Decision

Correction

Outcome
```

---

# 58. 核心数据库

在现有业务表基础上，

智能层只增加必要表：

```text
algorithm_decision

model_registry

rule_registry

experiment_assignment

behavior_event

event_outbox

suggestion_feedback

user_feature_snapshot
```

不要为每一个小算法创建大量独立数据表。

---

# 59. Repository 结构

推荐最终仓库：

```text
smart-expiry-harmony/
```

负责：

```text
HarmonyOS
UI
Local Database
Local Rule
Sync
```

```text
smart-expiry-server/
```

负责：

```text
Spring Boot
Domain
REST
Sync
Reminder
Intelligence Runtime
```

```text
smart-expiry-ai/
```

负责：

```text
Python
Training
Evaluation
Dataset Builder
Model Export
```

可选第四仓：

```text
smart-expiry-contracts/
```

维护：

```text
OpenAPI

JSON Schema

Golden Cases

Shared Test Cases
```

如果团队规模较小：

contracts 可以放 Server Repo。

---

# 60. Shared Contracts

重点共享：

```text
expiry-test-cases.json

attention-test-cases.json

recognition-schema.json

event-schema.json

OpenAPI
```

避免：

```text
HarmonyOS 一套规则

Java 一套规则

Python 再一套规则
```

---

# 61. 测试体系

至少分：

```text
Unit Test

Contract Test

Integration Test

Golden Test

E2E

Offline Benchmark

Load Test

Failure Test
```

重点 E2E：

```text
离线创建
→
本地可见
→
联网
→
同步成功
```

以及：

```text
AI Failure
→
Fallback
→
用户仍可完成操作
```

---

# 62. 监控与告警

P0：

```text
Safety Violation
```

P1：

```text
核心智能模块完全不可用

High Confidence Wrong 异常升高
```

P2：

```text
FallbackRate 升高

Latency 升高

Feature Stale
```

Safety 严重异常：

```text
自动 Kill Switch
```

---

# 63. 开发阶段划分

## Phase 1 — Product Foundation

```text
Item / Batch
Local-First
Expiry
Reminder
Today
Inventory
Manual Entry
```

## Phase 2 — Smart Capture

```text
OCR
Date Parser
ItemDraft
Confidence
DraftConfirm
```

## Phase 3 — Action Intelligence

```text
Attention
ReasonCode
Reminder Statistics
Suggestion
```

## Phase 4 — Data Loop

```text
Event
Outbox
Decision Log
Label Builder
Benchmark
```

## Phase 5 — ML Evolution

```text
Attention ML
ONNX
Shadow
Canary
A/B
```

## Phase 6 — Prediction

```text
Consumption
Replenishment
Waste Insight
```

---

# 64. P0 / P1 / P2

## P0

必须做：

```text
Local-First

Item / Batch

Expiry

Reminder

Smart Capture

ItemDraft

Today

Attention Rule

Safety Rule

Event

Outbox

Benchmark

Fallback
```

## P1

```text
Voice

Batch Capture

Suggestion

Entity Resolution

Reminder Personalization

Consumption Velocity

Shadow / Canary
```

## P2

```text
Learning-to-Rank

Multi-Product Vision

Replenishment Prediction

Family Personalization

Advanced Waste Intelligence
```

---

# 65. 当前阶段不要建设

避免：

```text
Kafka

Flink

Kubeflow

复杂 Feature Store

复杂微服务

实时训练

强化学习

大型 Agent 系统

独立在线 Python Serving 集群
```

除非未来规模证明必要。

---

# 66. 系统成功指标

工程成功不是：

```text
模型数量
LLM 调用量
服务数量
```

核心看：

```text
常见录入耗时下降

ZeroEditRate 提升

TodayActionRate 提升

ReminderActionRate 提升

TimelyHandlingRate 提升

DiscardRate 合理下降
```

---

# 67. 最终 Definition of Done

任何新能力上线前统一检查：

```text
业务定义
✓

Input / Output
✓

Domain Boundary
✓

Fallback
✓

Offline
✓

Error State
✓

Test
✓

Metrics
✓

Privacy
✓
```

算法能力额外：

```text
Dataset
✓

Benchmark
✓

Safety
✓

Decision Log
✓

Version
✓

Rollback
✓
```

不再为每一个版本维护重复的 DoD。

---

# 68. 文档体系最终收敛

项目以后只维护三类文档：

## A. 主设计

```text
SmartExpiry Technical Design V2.0
```

即本文档。

负责回答：

> 系统整体怎么设计？

---

## B. Contract

```text
OpenAPI

JSON Schema

DB Migration

Event Schema

Shared Test Cases
```

负责回答：

> 系统之间如何准确对接？

---

## C. ADR / 专项附录

只有发生重要架构决策时新增：

```text
ADR-001 Local-First

ADR-002 Item / Batch

ADR-003 AI Draft Boundary

ADR-004 Attention Ranking

ADR-005 Transactional Outbox
```

负责回答：

> 为什么做这个重要技术选择？

不再编写：

```text
V1.5.7
V1.5.8
V1.5.9
```

形式的超长连续文档。

---

# 69. 最终技术架构

```text
                         SmartExpiry

                              │
               ┌──────────────┴──────────────┐
               │                             │
          HarmonyOS                     Spring Boot
               │                             │
        ┌──────┼───────┐            ┌────────┼────────┐
        ↓      ↓       ↓            ↓        ↓        ↓
       UI    Domain  ArkData      Domain    Sync   Intelligence
        │              │            │                  │
        │              ↓            ↓          ┌───────┼───────┐
        │          Local First   PostgreSQL     ↓       ↓       ↓
        │                                     Rule    ONNX   AI API
        │                                       │       │       │
        └──────────────────┬────────────────────┴───────┴───────┘
                           ↓
                      User Decision
                           ↓
                      User Action
                           ↓
                     Behavior Event
                           ↓
                  Dataset / Evaluation
                           ↓
                      New Algorithm
```

---

# 70. 最终原则

SmartExpiry 后续所有研发决策都围绕五句话：

> **本地能力保证 App 随时能用。**

> **确定性规则保证业务正确。**

> **AI 减少用户操作，而不是增加复杂度。**

> **智能决策必须可解释、可评测、可降级、可回滚。**

> **用户真实行为，而不是模型自身输出，才是下一轮智能化最重要的学习信号。**

最终系统不是一个：

> “塞了很多 AI 功能的库存 App”。

而应该成为：

> **一个可靠的家庭物品管理系统，在不打扰用户的前提下，逐渐学会什么时候提醒、什么应该优先处理，以及怎样减少家庭物品浪费。**
