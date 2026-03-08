# ZooAI 部署仓库

本仓库仅包含部署所需文件，用于在服务器上一键安装/更新 ZooAI 服务。

## 文件说明

| 文件 | 说明 |
|------|------|
| `.gitignore` | 忽略 `.env`，避免提交敏感配置 |
| `README.md` | 本说明 |
| `deploy.sh` | 拉取镜像并启动 docker-compose |
| `docker-compose.yml` | 服务编排（MySQL、Redis、迁移、业务服务、网关、前端） |
| `quick-install.sh` | 一键安装脚本：缺文件时从 GitHub 克隆本仓库，缺 `.env` 时从 `.env.example` 复制，再执行 `deploy.sh` |
| `.env.example` | 环境变量示例，复制为 `.env` 后按需修改 |

## 一键安装（服务器执行）

```bash
curl -sSfL https://raw.githubusercontent.com/hopezoo/zooai/master/quick-install.sh | bash
```

或先克隆再执行：

```bash
git clone https://github.com/hopezoo/zooai.git
cd <本仓库名>
./quick-install.sh
./quick-install.sh v1.0.0   # 可选：指定镜像版本
```

## 首次部署前

1. 复制环境变量：`cp .env.example .env`
2. 编辑 `.env`，填写 `REGISTRY`、`VERSION`、`MYSQL_*`、`REDIS_*`、`JWT_*` 等
3. 若需自动创建超级管理员：设 `BOOTSTRAP_ADMIN_ENABLED=true`、`BOOTSTRAP_ADMIN_USERNAME`、`BOOTSTRAP_ADMIN_PASSWORD`，部署完成后建议改回 `false`

## 访问地址

- 前端：http://&lt;服务器IP&gt;/
- Admin 后台：http://&lt;服务器IP&gt;/aishop/admin
