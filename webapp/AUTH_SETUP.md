# MySQL 账户服务配置

## 1. 准备数据库

使用 MySQL 管理员账户执行：

```sql
CREATE DATABASE IF NOT EXISTS research_platform
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'research_platform'@'127.0.0.1'
  IDENTIFIED BY '请替换为强密码';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES
  ON research_platform.*
  TO 'research_platform'@'127.0.0.1';

FLUSH PRIVILEGES;
```

也可以使用 `webapp/db/mysql_schema.sql` 手动创建表。服务启动时会再次执行
`CREATE TABLE IF NOT EXISTS`，不会删除已有用户数据。

## 2. 配置连接信息

复制 `webapp/.env.example` 为 `webapp/.env`，填写真实的 MySQL 用户名和密码：

```env
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=research_platform
MYSQL_PASSWORD=请填写真实密码
MYSQL_DATABASE=research_platform
AUTH_SESSION_DAYS=7
AUTH_COOKIE_SECURE=0
```

`.env` 已被 `.gitignore` 排除，不要把数据库密码提交到 GitHub。

## 3. 生产环境

生产网站必须使用 HTTPS，并设置：

```env
AUTH_COOKIE_SECURE=1
```

修改配置后重启 `webapp/server.py`。访问 `/api/auth/status`，返回 `ok: true`
表示 MySQL 账户服务已连接。
