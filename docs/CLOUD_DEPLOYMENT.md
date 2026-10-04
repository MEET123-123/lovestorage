# 云服务器与已有 PostgreSQL 部署

适用范围：Linux 云服务器（Ubuntu/Debian/RHEL 系列均可）+ 已有 PostgreSQL。当前程序与 Flyway 迁移使用 PostgreSQL SQL，不可仅替换连接地址就改接 MySQL。服务器系统、数据库类型/版本与域名尚未确认，本文的主机名均为占位符，不包含真实凭据，也尚未执行远程部署。

云服务器运行 Spring Boot 后端与 HTTPS 代理，连接你已有的数据库。HarmonyOS App 安装在手机上，通过 HTTPS 调用后端，不直接连接数据库，也不需要在云服务器运行 App。

## 1. 先确认数据库的位置

| 现有数据库位置 | App 容器中的 DB_HOST | 操作要点 |
|---|---|---|
| 云厂商托管数据库/RDS | 控制台的内网连接域名 | 服务器与数据库处于可互通的 VPC；白名单只允许服务器内网来源 |
| 同一台云服务器上安装的 PostgreSQL | `host.docker.internal` 或服务器内网 IP | 容器里的 localhost 不是宿主机；PostgreSQL 需监听可达内网接口并允许 Docker 网段 |
| 另一个 Docker 容器 | 同一个 Docker 网络中的服务名 | 两个 Compose 项目需加入同一外部网络，不能使用对方只对 localhost 发布的端口 |

准备信息：数据库类型和版本、内网域名、端口、库名、应用账号、SSL 要求与 CA 证书。密码只写到服务器本地 secret 文件，不写入仓库、截图或命令行参数。不要用现有业务库做试验；为本项目创建独立数据库。

如果云服务只提供 MySQL，先确认能否创建 PostgreSQL 实例；否则需要另做 MySQL 驱动与迁移适配，此包不能直接连接 MySQL。

## 2. 创建应用数据库与账号

通过云厂商数据库控制台，或使用数据库管理员连接 PostgreSQL。下面命令中的名称可调整；`\password` 会交互式读取新密码。`\password`、`\connect` 是 psql 专用命令；使用云控制台时，通过界面设置密码和选择数据库。

```sql
CREATE ROLE smart_expiry_app LOGIN;
\password smart_expiry_app
CREATE DATABASE smart_expiry OWNER smart_expiry_app;
\connect smart_expiry
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO smart_expiry_app;
```

已有独立数据库时不要重复 CREATE DATABASE。应用首次启动会执行 Flyway V1–V5，后续版本只追加迁移；应用账号需要在本项目 schema 中建表/改表权限。已有手建同名表但没有 `flyway_schema_history` 时，应先备份并核对迁移，不要随意开启 baseline-on-migrate 或清空表。

托管 PostgreSQL 可能限制 CREATE ROLE/DATABASE，使用控制台创建同等账号和权限。数据库公网入口保持关闭，或者仅对必要管理 IP 临时放行；应用通过内网连接。

## 3. 本地生成发布包

在 Windows PowerShell、后端项目根目录执行：

```powershell
cd D:\Src\lovestorage
.\scripts\package-cloud.ps1
```

脚本先执行 Maven verify，再生成 `target/cloud-时间-随机值.tar.gz`，包含 JAR、Dockerfile、云端 Compose、健康检查和部署文档，不包含开发数据库、真实 `.env`、密码和证书。已验证过同一份 JAR 时可用 `-SkipBuild`。

将实际生成的包上传到服务器：

```powershell
scp .\target\cloud-实际文件名.tar.gz ubuntu@SERVER_IP:/home/ubuntu/
ssh ubuntu@SERVER_IP
```

后续代码发布使用独立版本目录并保留上一版。当前工作区改动未推送时，不要直接克隆远程旧分支期待包含这些功能，应使用上述包。

## 4. 服务器准备 Docker

按服务器发行版的 [Docker 官方安装文档](https://docs.docker.com/engine/install/) 安装 Docker Engine 与 Compose 插件，然后确认：

```bash
docker version
docker compose version
sudo -i
sudo mkdir -p /opt/smart-expiry/releases/20261004
sudo tar -xzf /home/ubuntu/cloud-实际文件名.tar.gz -C /opt/smart-expiry/releases/20261004
cd /opt/smart-expiry/releases/20261004
```

`sudo -i` 后的服务器部署步骤在 root 管理会话中执行，退出用 `exit`。版本目录不要对普通用户开放写权限；不切换 root 时，要为所有需要写入 /opt 的命令使用适当的 sudo 权限。

## 5. 填写连接配置和密码

```bash
cp deploy/.env.example deploy/.env
mkdir -p deploy/secrets deploy/certs
chmod 700 deploy/secrets
nano deploy/.env
```

例如托管 PostgreSQL：

```dotenv
APP_IMAGE=smart-expiry-server:20261004
DB_URL=jdbc:postgresql://数据库内网域名:5432/smart_expiry?sslmode=verify-full&sslrootcert=/app/certs/root.crt
DB_USERNAME=smart_expiry_app
DB_POOL_SIZE=10
APP_MEMORY_LIMIT=1g
APP_DOMAIN=api.你的域名.com
ACME_EMAIL=你的证书联系邮箱
```

从数据库提供方取得根 CA，保存为 `deploy/certs/root.crt`，设置为容器用户可读。`verify-full` 同时核验 CA 与域名；不要用 IP 替换证书上的数据库域名。PostgreSQL JDBC 的 [SSL 文档](https://jdbc.postgresql.org/documentation/ssl/) 说明了各模式与证书参数。

同机、内网自管数据库如果尚未启用 TLS，可在封闭测试阶段显式使用 `sslmode=disable`；正式接云数据库应按服务商要求配置 TLS。`require` 只保证加密而不提供完整主机身份核验，不等同于 verify-full。

交互式写入密码（不会回显或进入 shell 历史），不要在文件末尾添加换行：

```bash
read -rsp 'Database password: ' db_secret
printf '%s' "$db_secret" > deploy/secrets/db_password.txt
unset db_secret
printf '\n'
sudo chown 10001:10001 deploy/secrets/db_password.txt
sudo chmod 0400 deploy/secrets/db_password.txt
chmod 600 deploy/.env
```

容器以 UID 10001 运行。Compose 的文件型 secret 是本地文件挂载，宿主机文件必须可被该 UID 读取；容器内路径为 `/run/secrets/spring.datasource.password`，由 Spring configtree 加载。不要把真实 secrets 文件随发布包覆盖，升级时将上一版的实际 `.env`、secrets 和证书复制到新版本目录并保持权限。

检查配置：

```bash
sudo python3 deploy/check-config.py
sudo docker compose --env-file deploy/.env -f deploy/compose.cloud.yml config --quiet
```

这两个命令检查本地配置与 Compose 格式，不证明数据库网络可达。

## 6. 验证已有数据库联通性

服务器安装与数据库主版本兼容的 PostgreSQL 客户端。设定连接信息后执行只读检查；输入密码时不要复制带密码的 URL：

```bash
export PGHOST='数据库内网域名'
export PGPORT='5432'
export PGDATABASE='smart_expiry'
export PGUSER='smart_expiry_app'
export PGSSLMODE='verify-full'
export PGSSLROOTCERT='/opt/smart-expiry/releases/20261004/deploy/certs/root.crt'
bash deploy/check-db.sh
```

同机数据库：这里的 PGHOST 使用宿主机真实地址或 localhost，而 App 的 DB_URL 使用 `host.docker.internal`。连接失败先检查 DNS/VPC、安全组、数据库白名单、监听地址和 pg_hba.conf，再检查账号权限与证书；不要把全部来源开放来绕过问题。

## 7. 启动后端并检查迁移

```bash
sudo docker compose --env-file deploy/.env -f deploy/compose.cloud.yml up -d --build backend
sudo docker compose --env-file deploy/.env -f deploy/compose.cloud.yml ps
sudo docker compose --env-file deploy/.env -f deploy/compose.cloud.yml logs --tail=150 backend
curl --fail http://127.0.0.1:18081/api/v1/health
```

健康接口执行数据库 `SELECT 1`；200 且 `data.status=UP` 才说明服务能连数据库。检查日志中 Flyway 成功，不能只看容器是 running。首次启动可能需要 90 秒以上，数据库不可用时健康状态会失败。

生产 profile 会拒绝 H2、本地短信调试 profile、空密码和开发默认密码。Java 容器启用只读文件系统、内存上限、日志轮转、正常退出等待和重启策略。Docker 的 restart policy 不会仅因为 unhealthy 自动重启；健康异常应接入云监控并排查数据库或应用错误。[Docker 生产部署说明](https://docs.docker.com/compose/how-tos/production/)；[健康检查与启动依赖](https://docs.docker.com/compose/how-tos/startup-order/)。

## 8. 有域名时启用 HTTPS

1. 域名 A/AAAA 指向服务器公网地址；若有错误 AAAA 记录先修正。
2. 云安全组与系统防火墙放行 80/TCP、443/TCP。SSH 仅允许管理 IP。数据库端口、18081 和 Docker 管理端口不要公开。
3. `.env` 中 APP_DOMAIN 只写真实域名（不含 `https://`），填实际 ACME_EMAIL。
4. 启动反向代理：

```bash
sudo docker compose --env-file deploy/.env -f deploy/compose.cloud.yml --profile https up -d
sudo docker compose --env-file deploy/.env -f deploy/compose.cloud.yml logs --tail=100 caddy
curl --fail https://api.你的域名.com/api/v1/health
```

Caddy 自动申请/续期证书并重定向 HTTP 到 HTTPS；证书状态保存在命名卷，升级时保留卷。若服务器已有 Nginx/Caddy 占用 80/443，使用已有代理转发到 `127.0.0.1:18081`，不要再启动本包的 caddy。[Caddy 自动 HTTPS](https://caddyserver.com/docs/automatic-https)；[反向代理文档](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)。

应用信任内部代理转发的客户端地址，默认只通过 Caddy 或服务器管理员的本地端口访问后端；不得把后端 8080/18081 直接映射到公网。使用已有代理时应覆盖来自用户的 X-Forwarded-For/X-Forwarded-Proto，不能无条件透传伪造值。

## 9. 暂无域名时先用 SSH 隧道联调

本机 PowerShell 新开终端，保持该窗口运行：

```powershell
ssh -N -L 18082:127.0.0.1:18081 ubuntu@SERVER_IP
```

Postman 创建 `Cloud-Tunnel` 环境，baseUrl 设为 `http://localhost:18082`，再依次调用健康检查、注册/登录、库存、同步和事件接口。这里的 localhost 指电脑的 SSH 隧道；手机不能直接使用这个地址。手机正式联调使用上一步的可访问 HTTPS 域名。

## 10. App / Postman 切换云环境

- App 先退出本地账号，在登录页“本地接口调试/服务地址”填 `https://api.你的域名.com`，再注册或登录云账号。
- Postman 重新导入 `postman/LoveStorage.postman_collection.json`，选择云环境，把 `baseUrl` 改为同一 HTTPS 根地址（不追加 `/api/v1`）；登录后自动更新环境中的 accessToken。
- 本地库和云库的账号不同；本地 token 不能用于云库。不要把开发机 H2 文件复制到 PostgreSQL 数据目录。
- 先用测试账号验证多批次、部分消耗、跨设备同步冲突、退出再登录和备份恢复。云端手机号/华为登录仍需真实服务配置，不能公开启用 local-sms。

## 11. 数据库备份与恢复演练

云厂商自动备份/PITR 建议开启；升级前额外做一次独立备份。安装的 pg_dump 主版本不能低于服务器主版本。使用 `~/.pgpass`（权限 600）或交互式输入密码，不在命令中暴露密码。

```bash
# 复用第 6 步 PG* 变量；给自己的备份目录设置权限
mkdir -p /var/backups/smart-expiry
chmod 700 /var/backups/smart-expiry
bash deploy/backup-db.sh /var/backups/smart-expiry/before-release-20261004.dump
```

备份脚本采用 PostgreSQL custom 格式，验证归档目录后才生成最终文件，不覆盖已有文件。复制备份到独立存储，按实际恢复目标制定保留期。[PostgreSQL pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html)。

恢复演练务必使用新库：

```bash
# 使用有建库权限的管理账号创建空恢复库，随后切回适当的恢复账号
createdb -U 数据库管理员 -O smart_expiry_app smart_expiry_restore_check
pg_restore --exit-on-error --no-owner --no-acl --dbname=smart_expiry_restore_check /var/backups/smart-expiry/before-release-20261004.dump
psql -d smart_expiry_restore_check -c 'SELECT version, success FROM flyway_schema_history ORDER BY installed_rank;'
psql -d smart_expiry_restore_check -c 'SELECT count(*) FROM item;'
```

若已设置 PGDATABASE，要确认 pg_restore 的 `--dbname` 明确指向恢复库。不要对正在提供服务的原库运行清库/覆盖恢复；正式灾难恢复需要停写、验证备份、切换连接地址再验收。

## 12. 升级、回滚与日常运维

每次保留：发布包/JAR 的 SHA256、镜像版本、数据库升级前备份和验收记录。新版本解压到新目录，复制实际配置与 secrets 后执行 `up -d --build backend`。Compose 项目名固定，命名卷会复用；不要使用 `down -v`。

回滚应用时把 APP_IMAGE 改回旧镜像标签，然后 `docker compose ... up -d --no-build backend`；如果 Flyway 已执行不兼容迁移，不能只回滚 JAR，需要使用备份恢复到新库再切换。当前迁移只追加，不提供自动降级 SQL。

监控至少覆盖健康接口、容器重启/内存、磁盘、数据库连接数、备份成功率，以及登录后 `GET /api/v1/events/status` 中持续增长的 pending。Outbox 每 5 秒处理最多 100 条，规模扩大前应做真实 PostgreSQL 并发、压力与恢复测试。当前生产认证限流在单进程内，本文按单实例部署；多副本需共享限流和完整并发验收。

本地测试、JAR/HAP 构建成功不等于完成云端验收。当前尚未连接你的服务器/数据库，没有执行线上迁移或发布；提供系统、数据库类型/版本与域名信息后，可以把模板收敛为对应环境的最终配置。
