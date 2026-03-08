#!/usr/bin/env bash
# 服务器端一键部署脚本：根据当前系统拉取镜像，使用 docker-compose 启动
# 用法: ./deploy.sh [VERSION]
#        VERSION=v1.0.0 ./deploy.sh
# 需在脚本同目录下存在 docker-compose.yml 和 .env（可自 .env.example 复制）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检测系统（仅用于提示）
OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Detected: $OS / $ARCH (Docker will pull the matching image arch automatically)."

# 读取配置
export REGISTRY="${REGISTRY:-docker.io/yourorg}"
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
echo "Running database migration..."
$COMPOSE run --rm migrate || true

echo "Pulling images..."
$COMPOSE pull

echo "Starting all services..."
$COMPOSE up -d

echo "Done. Frontend: http://<this-server>/ (port 80). Admin: http://<this-server>/aishop/admin"
