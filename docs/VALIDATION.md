# 前端增强版验证记录（2026-10-03）

## 实现

应用版本 0.2.0 / versionCode 2，最低兼容 API 20，本机以 DevEco SDK/Hvigor 26 编译。
新增四个一级入口、独立录入/详情/统计、数量和日期扩展字段、筛选排序、处理流水、补货清单、规则建议、包装文字辅助提取和系统提醒适配。
详细规格：`FRONTEND_V1_1.md`；工作区原技术设计的第 17 章已同步扩展。

## 主机实际通过

- `node scripts/test-frontend.cjs`：22 项检查通过。
- 覆盖自然日期校验、开封后有效日期、数量和提醒边界、状态筛选、稍后处理、文本标签提取、09:00 提醒计划和过去时刻过滤。
- 使用 Node SQLite 执行实际 Repository 和迁移 SQL：空库与 v1 升级、字段回读、身份/批次事务回滚、版本确认保护、流水去重、恢复撤销、补货勾选/去重、软删除保留历史。
- `node scripts/test-contracts.cjs http://localhost:8080`：9 条共享日期 fixture、2 条自然月/闰年推导边界、契约快照一致性通过。
- ApiClient 实际 HTTP 联调：创建、重复创建重试、名称和生命周期更新、数量单位、开封后更早到期日投影、查询、删除、重复删除通过。测试记录已软删除。
- 真实 ArkTS 应用编译及 `entry@ohosTest` 测试包构建通过；设备测试包新增 4 个领域测试，原 9 个共享规则用例保留。

## 测试方式与限制

主机 SQLite 适配器覆盖真实业务代码和 SQL，不是 HarmonyOS ArkData 驱动实测。HTTP 适配器执行实际 ApiClient 源码，但传输层为主机 fetch。
`hdc list targets` 返回 Empty，本次未执行设备 UI、原生 ArkData 和 Hypium，也未验证系统提醒的权限、到时触发、后台行为和配额。
HAP 未签名；DevEco 需配置自动签名后在手机/模拟器上覆盖安装。覆盖安装保留旧数据库用于升级验证，卸载会清除应用数据。
SDK 仍报告部分 API 可能抛异常和兼容性弃用提示。页面操作入口统一捕获异步错误，提醒失败单独展示，不阻断本地保存。
视觉与交互尚需在真实设备按规格 17.9 检查，包括大字体、键盘、长文本和小屏布局。

## 当前边界

- 本地物品/批次已分表，当前 UI 每物品一批次；多批次编辑、部分消耗、自定义分类仍待实现。
- 同步仅上传核心投影；品牌、原始开封数据、位置、备注、流水、购物清单仅本地保存。
- 文本提取来自明确标签的规则，不是相机 OCR/语音或 AI。
- 系统提醒最多注册最近 20 条未来计划；无权限或部分失败均提示，应用内待办继续工作。

## 重复验证

```powershell
cd D:\Src\append
node scripts/test-frontend.cjs
node scripts/test-contracts.cjs http://localhost:8080
.\scripts\build.ps1
.\scripts\build.ps1 -TestHap
```

主机存储检查使用 Node 24 的 node:sqlite；可通过 DEVECO_HOME 指定 DevEco 安装目录。
