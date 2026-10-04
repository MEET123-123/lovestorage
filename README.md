> 算法整理与云部署：参见 [algorithm](algorithm/README.md) 和 [云服务器/已有数据库部署步骤](docs/CLOUD_DEPLOYMENT.md)。

> 2026-10-04 更新：已接入多批次/部分消耗、完整库存双向同步与冲突选择、持久化识别草稿和 Mock 调试入口。入口和本地测试步骤见 [V2 实施说明](docs/V2_IMPLEMENTATION.md)。Mock 不代表真实 OCR/语音或模型训练能力；当前为本地可构建候选版。

> 主设计现统一为 [V2.0 收敛版](docs/SmartExpiry_Technical_Design_V2.0.md)。本轮 Today / Attention 工作区实现、测试与剩余差距见 [V2 实施附录](docs/V2_IMPLEMENTATION.md)。

# Smart Expiry HarmonyOS 客户端

HarmonyOS 客户端（ArkTS + ArkUI），支持离线库存管理、到期日期规则、提醒适配、账号登录及按账号隔离的本地数据。当前候选版本为 0.4.0。

## 构建与测试

```powershell
.\scripts\build.ps1
.\scripts\build.ps1 -TestHap
node .\scripts\test-contracts.cjs
node .\scripts\test-frontend.cjs
node .\scripts\test-login.cjs
```

使用 DevEco Studio 打开仓库根目录，配置 HarmonyOS SDK 和设备签名后运行 `entry`。命令行构建产物未签名，不能直接安装到设备。

## 登录与本地联调

应用启动时进入独立登录页；账号密码可注册/登录。手机号仅支持后端显式启用 `local-sms` 时的本地调试验证码，不会发送真实短信；华为账号登录尚未配置开发者应用、签名和服务端校验。

后端和 Postman 操作步骤见 [本地候选版说明](docs/LOCAL_CANDIDATE.md)。API 契约镜像位于 `contract/`，真源由后端仓维护。当前支持编辑头像、昵称、简介、忌口与个人偏好；关键词提示不能代替包装配料及过敏原检查。

## 目录

- `entry/`：HarmonyOS 应用模块
- `contract/`：后端 OpenAPI 与共享保质期规则快照
- `scripts/`：构建、契约和客户端领域测试
- `docs/`：设计、版本记录、集成与验证说明
