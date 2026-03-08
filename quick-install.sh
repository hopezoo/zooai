#!/usr/bin/env bash
# ZooAI 一键安装/部署脚本（可单独放在 GitHub 仓库供服务器 curl 下载运行）
# 用法:
#   curl -sSfL https://raw.githubusercontent.com/hopezoo/zooai/master/quick-install.sh | bash
#   或下载后: ./quick-install.sh [VERSION]
#
# 逻辑:
#   1. 若当前目录已有 docker-compose.yml 和 deploy.sh，则在本目录执行部署；
#   2. 若缺少其一，则从 GitHub 克隆部署仓库到当前目录下的 zooai-deploy/，在该目录执行部署；
#   3. 若没有 .env，则从 .env.example 复制一份；
#   4. 最后执行 deploy.sh 完成拉镜像与启动。

set -e

# ===================== 新增：依赖检查 =====================
check_dependency() {
  local cmd=$1
  local name=$2
  if ! command -v "$cmd" &> /dev/null; then
    echo "错误：未找到 $name，请先安装！"
    exit 1
  fi
}

# 检查核心依赖
check_dependency "git" "Git"
check_dependency "docker" "Docker"
check_dependency "docker-compose" "Docker Compose"

# ===================== 核心配置 =====================
# 部署仓库地址（HTTPS 方式，无需 SSH 密钥，公开仓库可直接克隆）
REPO_URL="${ZOOAI_DEPLOY_REPO:-https://github.com/hopezoo/zooai.git}"
DEPLOY_DIR="${ZOOAI_DEPLOY_DIR:-zooai-deploy}"

WORK_DIR=""
need_clone=false

# ===================== 目录判断逻辑 =====================
if [ -f "docker-compose.yml" ] && [ -f "deploy.sh" ]; then
  WORK_DIR="."
  echo "✅ 使用当前目录（已找到 docker-compose.yml 和 deploy.sh）。"
else
  need_clone=true
  echo "⚠️ 当前目录未找到 docker-compose.yml 或 deploy.sh，准备克隆部署仓库..."
fi

# ===================== 克隆仓库逻辑 =====================
if [ "$need_clone" = true ]; then
  # 检查目标目录是否有效（存在且有 deploy.sh 才复用）
  if [ ! -d "$DEPLOY_DIR" ] || [ ! -f "$DEPLOY_DIR/deploy.sh" ]; then
    echo "🔄 从 $REPO_URL 克隆部署仓库到 $DEPLOY_DIR ..."
    # 先清理无效目录，避免克隆失败
    if [ -d "$DEPLOY_DIR" ]; then
      rm -rf "$DEPLOY_DIR"
    fi
    # --depth=1 只克隆最新版本，加快速度
    git clone --depth=1 "$REPO_URL" "$DEPLOY_DIR"
    if [ $? -ne 0 ]; then
      echo "❌ 克隆仓库失败！请检查网络或仓库地址是否正确。"
      exit 1
    fi
  else
    echo "✅ 使用已存在的 $DEPLOY_DIR/ 目录。"
  fi
  WORK_DIR="$DEPLOY_DIR"
fi

# ===================== 进入工作目录并处理 .env =====================
cd "$WORK_DIR" || { echo "❌ 进入目录 $WORK_DIR 失败！"; exit 1; }

if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "✅ 从 .env.example 生成 .env 文件，你可以先编辑该文件配置参数。"
  else
    echo "⚠️ 未找到 .env.example 文件！需要手动创建 .env 并配置 REGISTRY、VERSION、MYSQL 等参数。"
    read -p "是否继续（无 .env 可能导致部署失败）？ [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[yY]$ ]]; then
      echo "🚫 用户取消操作，退出。"
      exit 1
    fi
  fi
fi

# ===================== 执行部署脚本 =====================
chmod +x deploy.sh || { echo "❌ 给 deploy.sh 添加执行权限失败！"; exit 1; }
echo "🚀 开始执行部署脚本 deploy.sh ..."
exec ./deploy.sh "$@"