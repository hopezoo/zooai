#!/usr/bin/env bash
# ZooAI 一键安装/部署脚本（可单独放在 GitHub 仓库供服务器 curl 下载运行）
# 用法:
#   curl -sSfL https://raw.githubusercontent.com/<your-org>/<deploy-repo>/master/quick-install.sh | bash
#   或下载后: ./quick-install.sh [VERSION]
#
# 逻辑:
#   1. 若当前目录已有 docker-compose.yml 和 deploy.sh，则在本目录执行部署；
#   2. 若缺少其一，则从 GitHub 克隆部署仓库到当前目录下的 zooai-deploy/，在该目录执行部署；
#   3. 若没有 .env，则从 .env.example 复制一份；
#   4. 最后执行 deploy.sh 完成拉镜像与启动。

set -e

# 部署仓库地址（放到 GitHub 时请改成你的仓库 URL）
REPO_URL="${ZOOAI_DEPLOY_REPO:-git@github.com:hopezoo/zooai.git}"
DEPLOY_DIR="${ZOOAI_DEPLOY_DIR:-zooai-deploy}"

WORK_DIR=""
need_clone=false

if [ -f "docker-compose.yml" ] && [ -f "deploy.sh" ]; then
  WORK_DIR="."
  echo "Using current directory (docker-compose.yml and deploy.sh found)."
else
  need_clone=true
  echo "docker-compose.yml or deploy.sh not found in current directory."
fi

if [ "$need_clone" = true ]; then
  if [ ! -d "$DEPLOY_DIR" ] || [ ! -f "$DEPLOY_DIR/deploy.sh" ]; then
    echo "Cloning deploy repo from $REPO_URL into $DEPLOY_DIR ..."
    if [ -d "$DEPLOY_DIR" ]; then
      rm -rf "$DEPLOY_DIR"
    fi
    git clone --depth=1 "$REPO_URL" "$DEPLOY_DIR"
  else
    echo "Using existing $DEPLOY_DIR/."
  fi
  WORK_DIR="$DEPLOY_DIR"
fi

cd "$WORK_DIR"

if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "Created .env from .env.example. You can edit .env before starting."
  else
    echo "Warning: .env.example not found. Create .env manually with REGISTRY, VERSION, MYSQL_*, REDIS_*, JWT_* etc."
    read -p "Continue without .env? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[yY]$ ]]; then
      exit 1
    fi
  fi
fi

chmod +x deploy.sh
exec ./deploy.sh "$@"
