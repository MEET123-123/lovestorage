# SmartExpiry

SmartExpiry 是一套 HarmonyOS 食品与日用品保质期管理项目，包含 ArkTS/ArkUI 客户端、Java REST 服务、保质期与日期识别算法，以及前后端共享的 API 契约。用户可以建立库存、跟踪到期时间、维护个人饮食忌口与偏好，并在登录后按账号使用服务端能力。

> 当前代码适合本地开发和联调，尚未完成公网生产部署验收。短信登录目前是明确标注的本地验证码调试模式；华为账号登录需要后续配置华为开发者应用与服务端授权。

## 项目组成

本项目在 GitHub 仓库中按分支拆分前后端：

| 模块 | 代码位置 | 技术与职责 |
| --- | --- | --- |
| HarmonyOS 客户端 | [`split-app` 分支](https://github.com/MEET123-123/lovestorage/tree/split-app)（当前 `main` 也包含客户端代码） | ArkTS、ArkUI、Stage；登录与个人资料、库存界面、ArkData 本地存储、提醒和后端 API 调用 |
| Java 后端 | [`split-server` 分支](https://github.com/MEET123-123/lovestorage/tree/split-server) | Java 21、Spring Boot、Spring Security、JPA、Flyway；认证、账号隔离、物品与分类 API、个人资料、备份、文本日期识别 |
| API 契约 | 前端 [`contract/`](contract/)；后端 [`openapi/`](https://github.com/MEET123-123/lovestorage/tree/split-server/openapi) | OpenAPI 是 HTTP 接口字段和行为的权威来源；前端目录保存供客户端开发使用的契约快照 |
| 共享算法样例 | 后端 [`shared/`](https://github.com/MEET123-123/lovestorage/tree/split-server/shared) | 保质期计算与文本日期识别的跨端测试用例，供 Java 与 ArkTS 对照验证 |

客户端在本地保存数据并提供 Local-First 使用基础；登录后服务端为数据实施账号隔离。保质期日期计算和文本识别均基于可测试规则，不等同于 OCR/语音识别服务。识别结果应由用户核对后再保存。

## 当前功能

- 用户名与密码注册、登录、会话认证和账号隔离；登录后按账号区分客户端本地数据。
- 本地验证码调试入口、个人资料编辑（昵称、头像、简介、忌口及偏好）。本地验证码不会发送短信。
- 库存物品、分类、生命周期状态、到期规则与提醒相关功能。
- 完整数据备份与受版本校验保护的恢复流程。
- 从用户输入的文本提取日期候选、标签依据与冲突提示；不自动调用云端大模型、OCR 或 ASR。
- Postman 集合和测试环境，支持检查健康状态、登录、资料与库存接口。

实际范围和已知限制见后端的[本地候选版说明](https://github.com/MEET123-123/lovestorage/blob/split-server/docs/LOCAL_CANDIDATE.md)与[验证记录](https://github.com/MEET123-123/lovestorage/blob/split-server/docs/VALIDATION.md)。

## 快速开始

### 运行 HarmonyOS 客户端

1. 检出 `split-app` 分支，并用 DevEco Studio 打开仓库根目录。
2. 配置 HarmonyOS SDK、设备或模拟器和应用签名。
3. 构建并运行 `entry` 模块。应用启动后进入登录界面。
4. 在登录页的“本地接口调试”中配置后端地址并测试连接，然后注册或登录。

真机访问电脑上的服务时，请填写电脑的局域网 IP，不能填写 `localhost` 或 `127.0.0.1`。登录方法的配置边界见上方本地候选版说明。

### 运行后端（无需 Docker）

后端代码在 `split-server` 分支。使用 JDK 21，在该分支仓库根目录执行：

```powershell
.\scripts\build.ps1
.\scripts\run.ps1 -Profile local -Port 18081
```

这会使用持久化 H2 文件数据库，数据位于 `data/`，默认不依赖 Docker。启动后检查：

```powershell
Invoke-RestMethod http://localhost:18081/api/v1/health
```

若需要调试手机号本地验证码，可在可信的本机环境使用 `-LocalSms` 参数。该模式仅返回调试验证码，不发送短信，不能用于公网部署。

### 使用 PostgreSQL / Docker 联调

在 `split-server` 分支仓库目录执行：

```powershell
docker compose up -d postgres
```

之后可在 IDEA 运行 `SmartExpiryApplication`，使用 `default` profile，并将数据库连接配置为 `jdbc:postgresql://localhost:5432/smart_expiry`。如希望后端也由 Docker 启动，执行：

```powershell
docker compose --profile server up -d --build
```

Docker 后端默认端口为 `18080`；IDEA 中运行的后端可以使用 `18081`，两者都连接本地 PostgreSQL。关闭容器时执行 `docker compose --profile server down`；普通 `down` 会保留数据库卷。详细配置见[Docker 调试指南](https://github.com/MEET123-123/lovestorage/blob/split-server/docs/DOCKER_DEBUG.md)。

### 使用 Postman 联调

导入后端分支中的 [`postman/`](https://github.com/MEET123-123/lovestorage/tree/split-server/postman) 文件：`LoveStorage.postman_collection.json` 和 `IDEA.postman_environment.json`。选择 `LoveStorage IDEA` 环境，并确认 `baseUrl` 指向正在运行的后端，例如 `http://localhost:18081`。首次测试先运行注册并登录请求，获取 Bearer token 后再调用需认证的接口。

健康检查 `GET /api/v1/health` 无需登录；物品、个人资料、完整备份和文本识别等接口需要登录令牌。完整步骤和断点调试方式见 [IDEA / Postman 联调指南](https://github.com/MEET123-123/lovestorage/blob/split-server/docs/IDEA_POSTMAN.md)。

## 契约与算法协作

后端分支中的 `openapi/smart-expiry-v1.yaml` 是 API 契约真源，`shared/` 中的 JSON 文件是跨端算法样例真源。接口或算法规则变更时：

1. 先更新后端契约或共享样例，并完成服务端实现和测试。
2. 前端运行仓库脚本同步契约快照：

   ```bash
   python scripts/sync_contracts.py
   python scripts/sync_expiry_fixture.py
   ```

3. 更新 ArkTS API 调用或算法实现，并使用同一组样例验证前后端结果。

更多联调约定见[前后端集成说明](docs/INTEGRATION.md)。

## 目录结构

```text
AppScope/                 HarmonyOS 应用级配置
entry/                    ArkTS/ArkUI 客户端模块
contract/                 后端 OpenAPI 与共享算法样例快照
scripts/                  契约和测试夹具同步脚本
docs/                     前端集成及项目文档
split-server 分支：
  src/                    Spring Boot 后端源码
  openapi/                API 契约真源
  shared/                 跨端算法测试样例
  postman/                Postman 集合、环境与数据库检查脚本
  docker-compose.yml      PostgreSQL 和可选后端服务
```

## 发布前检查

本项目目前定位于本地开发和前后端联调。对外发布前还需要完成短信/华为认证服务配置、真机与数据迁移验收、账号恢复和删除流程、隐私与数据保留策略、HTTPS 与生产密钥、数据库备份恢复演练、监控告警和并发测试。未接入设备 OCR/ASR 前，产品说明应称为文本辅助录入，不应描述为已实现拍照或语音识别。

## 相关文档

- [前后端联调协议](docs/INTEGRATION.md)
- [技术设计文档与变更记录](https://github.com/MEET123-123/lovestorage/tree/split-server/docs/ChangeLog)
- [后端完整说明](https://github.com/MEET123-123/lovestorage/blob/split-server/README.md)
- [后端版本变更记录](https://github.com/MEET123-123/lovestorage/blob/split-server/docs/ChangeLog/CHANGELOG.md)
