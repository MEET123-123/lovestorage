# 2026-10-04 算法目录与云部署补全验证

- Java Maven verify：16 项测试通过，涵盖算法共享样例、认证/账号隔离、库存同步、事件分页导出与生产配置限制。
- 前端领域/存储适配器：104 项检查通过；登录与契约检查通过。
- 实际 HTTP 联调：当前打包 JAR 在 127.0.0.1:19091、local profile、隔离 H2 内存数据库运行，前端真实 ApiClient 经 fetch 适配器完成注册登录、库存 CRUD/重试、备份冲突、识别、多批次同步/版本冲突、事件发布/导出/重试去重及退出撤销。此项不替代 PostgreSQL 与真机验收。
- Python 离线流程：6 项测试通过；真实运行 Mock 事件 → Dataset → 评测报告 → Registry 校验。
- 部署配置检查：2 项 Python 测试通过，Shell 脚本语法检查与 YAML 解析通过。
- 应用与测试 HAP 构建通过，未签名，未执行真机 UI / 通知验收。
- 发布包包含 JAR、Dockerfile、Compose、操作文档，排除实际 secrets、证书与开发数据库。
- 云服务器及其数据库尚未连接；本文不宣称容器已在云端启动或已完成真实 PostgreSQL 部署验收。

源码及规则目录见 [algorithm](../algorithm/README.md)，部署步骤见 [CLOUD_DEPLOYMENT.md](CLOUD_DEPLOYMENT.md)。下面保留较早轮次记录。

# 2026-10-04 V2 本地主机验证

- Maven verify：14 项测试，0 失败、0 错误；打包成功。
- 前端领域/SQLite 适配器：90 项检查通过。
- OpenAPI 快照、9 个日期样例、2 个自然月/年边界与登录流程检查通过。
- 应用 HAP 与测试 HAP 构建成功，均未签名；原生 ArkData、UI 和系统通知未在真机执行。
- 数据升级：本地 schema v3，后端 Flyway V5；完整备份 schemaVersion 2 兼容旧版。
- Mock 拍照、语音、条码与预测数据只用于业务链路调试，未进行真实 OCR 或模型效果评测。
- 具体功能与操作入口见 [V2_IMPLEMENTATION.md](V2_IMPLEMENTATION.md)。

下面保留历史验证记录，旧轮次统计不代表当前功能集。

## 2026-10-03 V2.0 Today / Attention（工作区）

后端 Maven verify：12 个测试，0 失败；前端 76 项领域/存储检查、登录检查与共享契约检查通过。应用及测试 HAP 构建成功，未签名、未真机执行。OpenAPI YAML / Postman JSON 已解析，JAR 内 Attention 规则资源已核对。完整范围与剩余差距见 [V2 实施附录](V2_IMPLEMENTATION.md)。

# 0.3.0 本地候选版验证（2026-10-03）

# 0.4.0 个人资料与本地登录方式验证（2026-10-03）

- Maven verify：10 个 JUnit 测试方法，0 失败/错误；涵盖本地验证码冷却、尝试上限、过期/重放拒绝、资料字段验证与账号隔离。
- 登录方式 API 默认报告手机号不可用、华为未启用；`local-sms` 只作本机调试，不发送短信，也不证明号码所有权。Profile GET/PUT 需要当前 Bearer 会话。
- 当前工作区 HTTP 服务未运行，本轮没有真实 Postman/API 联调；启动步骤见 `LOCAL_CANDIDATE.md`。H2 本地 profile 不需要 Docker；PostgreSQL 联调须先保证外部数据库服务可连接。

以下为 0.3.0 历史记录。

---

- Maven verify：8 个 JUnit 方法，0 失败/错误。账号间 GET/PUT/PATCH/DELETE 与幂等重试隔离、密码散列/令牌散列、过期/退出/改密撤销、备份隔离及 409 冲突、请求验证、12 组算法样例均通过。
- 前端主机：41 项业务与 SQLite 检查，包括账号/访客切换后的数据隔离、完整备份恢复、拒绝非空覆盖、无效流水导致事务回滚。
- 保质期：9 组 fixture 与 2 个日历边界；OpenAPI 快照一致。
- 真实 PostgreSQL：独立 smart_expiry_candidate，Flyway V1/V2/V3 与 Hibernate 校验通过；实际 ArkTS ApiClient 注册/登录、CRUD/重试、快照写入/读取/冲突、识别及退出撤销联调通过。联调仅使用生成的测试账号；测试物品已软删除，测试账号和快照保留在联调库。
- 前端应用与 ohosTest HAP 编译通过。未连接设备，未执行原生 ArkData/Hypium、签名安装、实际提醒、UI 或性能容量验收。主机适配器不等同设备测试。
- 运行说明与上线缺口：[LOCAL_CANDIDATE](LOCAL_CANDIDATE.md)。以下为历史版本记录。

---

# 验证记录 — 2026-10-03

Windows / JDK 21.0.12.1 / Spring Boot 4.1.1。

`mvnw.cmd verify`：BUILD SUCCESS，4 个 JUnit 测试方法，0 失败、0 错误。
- 1 个共享规则测试覆盖 9 条日期 fixture。
- 3 个真实随机端口 HTTP 集成测试覆盖健康、分类、CRUD、PATCH、PUT 兼容更新、日期重算、生命周期、创建重试、软删除、无效日期/请求、失败事务回滚。
- 测试实际执行 Flyway V1 迁移，Hibernate validate 校验 H2 PostgreSQL 模式数据库；不再通过 create-drop 绕过迁移。

可执行 JAR 已生成并在 local profile 的 8080 端口实际运行。
创建持久化记录、停止服务、重新启动后查询仍成功；测试记录已软删除。
前端 ApiClient 源码经主机传输适配器完成实际 HTTP 联调，含创建重试和删除重试。

修复：损坏的 ItemApplicationService、Spring Boot 4 测试依赖/导入、Jackson 3 测试兼容、服务构造器注入、Flyway 自动配置、expiryStatus 契约字段、非法请求返回 500、日期校验。
新增：客户端幂等创建 ID、生命周期修改、API 20 的 PUT 兼容入口、本地持久数据库配置及 Windows 构建/运行脚本。

追加 Docker 验证（2026-10-03）：Java 21 后端镜像构建成功，后端与 PostgreSQL 17.11 容器运行正常。
PostgreSQL 健康检查、Flyway V1 迁移、Hibernate schema validate 及实际 ApiClient HTTP CRUD/重试联调均通过。
容器内查询确认系统分类和测试记录已入库，测试记录已软删除；使用命名卷 `lovestorage_smart_expiry_pgdata`。
详见 `DOCKER_DEBUG.md`。

未验证：真机 UI/ArkData、签名安装、多设备并发同步、提醒/OCR/语音/AI、生产部署验收。
当前服务没有认证隔离，不应公开部署。
