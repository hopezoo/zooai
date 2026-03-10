#!/usr/bin/env bash
# 服务器端一键部署脚本：根据当前系统拉取镜像，使用 docker-compose 启动
# 用法: ./deploy.sh [VERSION]
#        VERSION=v1.0.0 ./deploy.sh
# 需在脚本同目录下存在 docker-compose.yml、.env（可自 .env.example 复制）、configs/（手动复制）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查 configs/app.yaml 是否存在
if [ ! -f configs/app.yaml ]; then
  echo "❌ 未找到 configs/app.yaml，请将项目的 configs/ 目录复制到当前目录（与 docker-compose.yml 同级）"
  exit 1
fi

# 检测系统（仅用于提示）
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Detected: $OS / $ARCH (Docker will pull the matching image arch automatically)."

# 读取配置（镜像：hopezoo/gateway:linux-<版本>；hopezoo/<产品>:backend-<端>-linux-<版本>；hopezoo/aishop:frontend-<端>-linux-<版本>；hopezoo/zooai:migrate-linux-<版本>）
export REGISTRY="${REGISTRY:-hopezoo}"
export VERSION="${VERSION:-latest}"
if [ -n "$1" ]; then
  export VERSION="$1"
fi
echo "Using REGISTRY=$REGISTRY VERSION=$VERSION"

# 检查 .env
if [ ! -f .env ]; then
  echo "Warning: .env not found. Copy from .env.example and fill in: cp .env.example .env"
  read -p "Continue without .env? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[yY]$ ]]; then
    exit 1
  fi
fi
# 加载 .env 以便读取 SKIP_MIGRATE 等开关
[ -f .env ] && set -a && source .env && set +a

# 选择 docker compose 命令
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Error: docker compose or docker-compose not found. Please install Docker and Docker Compose."
  exit 1
fi

# 首次部署：先启动 MySQL/Redis，等待就绪后执行迁移（含 Bootstrap 管理员创建，若 .env 中 BOOTSTRAP_ADMIN_ENABLED=true）
echo "Starting MySQL and Redis..."
$COMPOSE up -d mysql redis
echo "Waiting for MySQL to be ready..."
sleep 15
# 迁移开关：.env 中 SKIP_MIGRATE=1 时跳过
if [ "${SKIP_MIGRATE:-0}" = "1" ]; then
  echo "Skipping database migration (SKIP_MIGRATE=1)"
else
  echo "Running database migration..."
  $COMPOSE run --rm migrate || true
fi

echo "Pulling images..."
$COMPOSE pull

echo "Starting all services..."
$COMPOSE up -d

echo "Done. Frontend client: http://<this-server>/ (port 80). Frontend admin: http://<this-server>:8080/ . Admin API: http://<this-server>/aishop/admin"
