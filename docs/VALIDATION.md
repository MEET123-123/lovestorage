# 验证记录 — 2026-10-03

实际环境：Windows、Oracle JDK 21.0.12.1、Spring Boot 4.1.1、DevEco Studio SDK/Hvigor 26。

已通过：
- HarmonyOS `entry@default assembleHap`：真实 ArkTS 编译与未签名 HAP 打包成功。
- HarmonyOS `entry@ohosTest assembleHap`：测试包编译、资源校验与打包成功。
- 前端 ExpiryService：9 条共享 fixture、月末和闰年 2 条推导边界通过。
- 前后端 OpenAPI 和 JSON fixture 快照一致。
- 实际 ApiClient 源码通过主机 HTTP 适配器连接运行中的 Spring Boot：健康、创建、重复重试、编辑、用完状态、详情、删除、重复删除和删除后查询通过。

修复：ArkTS 不支持的解构声明、测试模块缺少启动窗资源、Oracle javapath 打包失败、API 20 不支持 PATCH 枚举。
新增：本地数据库迁移与同步标记、持久客户端 ID、失败重试、实际录入界面、错误提示、构建脚本。

限制：hdc 未发现设备；未执行真机 ArkData/UI/NetworkKit 操作，也未在设备运行 Hypium。产物未签名。
SDK 的可能抛异常提示与 AlertDialog 弃用警告仍存在；存储/网络异常由页面入口捕获并展示。
同期后端报告见 `../lovestorage/docs/VALIDATION.md`（相对仓库根目录）。
