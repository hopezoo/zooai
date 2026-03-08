#!/usr/bin/env bash
# ZooAI 一键安装/部署脚本（可单独放在 GitHub 仓库供服务器 curl 下载运行）
# 用法:
#   curl -sSfL https://raw.githubusercontent.com/hopezoo/zooai/master/quick-install.sh | bash
#   或下载后: ./quick-install.sh [VERSION]
#
# 逻辑:
#   0. 检测并自动安装缺失依赖：Git、Docker、Docker Compose（缺则按当前系统自动安装）；
#   1. 若当前目录已有 docker-compose.yml 和 deploy.sh，则在本目录执行部署；
#   2. 若缺少其一，则从 GitHub 克隆部署仓库到当前目录下的 zooai-deploy/，在该目录执行部署；
#   3. 若没有 .env，则从 .env.example 复制一份；
#   4. 最后执行 deploy.sh 完成拉镜像与启动。

set -e

# ===================== 环境依赖：检测 + 自动安装 =====================
# 检测是否为 root（部分安装需要 sudo）
can_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi
  sudo -n true 2>/dev/null
}

run_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# 检测操作系统（仅读 /etc/os-release 或 uname，输出 ID）
detect_os_id() {
  if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    echo "${ID:-unknown}"
  elif [ "$(uname -s)" = "Darwin" ]; then
    echo "darwin"
  else
    echo "unknown"
  fi
}

# 先判断系统类型：darwin | apt | rpm | unknown
# apt 系：Debian、Ubuntu 及衍生版；rpm 系：RHEL、CentOS、Fedora、Rocky、Alma 等（dnf/yum）
detect_os_family() {
  local id
  id=$(detect_os_id)
  case "$id" in
    darwin)                  echo "darwin" ;;
    debian|ubuntu|linuxmint|raspbian|kali|pop|elementary|mx)
                             echo "apt" ;;
    centos|rhel|fedora|rocky|almalinux|ol)
                             echo "rpm" ;;
    *)                       echo "unknown" ;;
  esac
}

# 依赖安装前统一检测一次系统，供后续安装逻辑使用
OS_ID=""
OS_FAMILY=""
setup_os_detect() {
  OS_ID=$(detect_os_id)
  OS_FAMILY=$(detect_os_family)
  echo "🔍 检测到系统: $OS_ID (类型: $OS_FAMILY)"
  if [ "$OS_FAMILY" = "unknown" ]; then
    echo "⚠️ 未识别的系统，仅支持: macOS(darwin)、Debian/Ubuntu(apt)、CentOS/RHEL/Fedora(rpm)。"
  fi
}

# ----- Git -----
has_git() {
  command -v git &>/dev/null
}

install_git() {
  echo "📦 正在安装 Git ..."
  if [ "$OS_FAMILY" = "darwin" ]; then
    if command -v brew &>/dev/null; then
      brew install git
    else
      echo "❌ 未检测到 Homebrew，请先安装: https://brew.sh"
      exit 1
    fi
  elif [ "$OS_FAMILY" = "apt" ]; then
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Git"; exit 1; }
    run_sudo apt-get update -qq
    run_sudo apt-get install -y git
  elif [ "$OS_FAMILY" = "rpm" ]; then
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Git"; exit 1; }
    if command -v dnf &>/dev/null; then
      run_sudo dnf install -y git
    else
      run_sudo yum install -y git
    fi
  else
    echo "❌ 当前系统 ($OS_ID) 暂不支持自动安装 Git，请手动安装。"
    exit 1
  fi
  echo "✅ Git 安装完成。"
}

# ----- Docker -----
has_docker() {
  command -v docker &>/dev/null
}

install_docker() {
  echo "📦 正在安装 Docker ..."
  if [ "$OS_FAMILY" = "darwin" ]; then
    if command -v brew &>/dev/null; then
      brew install --cask docker
      echo "⚠️ 请打开「Docker Desktop」并等待其就绪后，重新运行本脚本。"
      exit 0
    else
      echo "❌ 未检测到 Homebrew，请先安装: https://brew.sh"
      exit 1
    fi
  elif [ "$OS_FAMILY" = "apt" ]; then
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Docker"; exit 1; }
    if ! has_docker; then
      export DEBIAN_FRONTEND=noninteractive
      run_sudo apt-get update -qq
      run_sudo apt-get install -y ca-certificates curl
      if [ -x /usr/bin/curl ]; then
        curl -fsSL https://get.docker.com | run_sudo sh
      else
        run_sudo apt-get install -y docker.io
      fi
      run_sudo usermod -aG docker "$USER" 2>/dev/null || true
    fi
    echo "💡 若当前用户需直接运行 docker（免 sudo），请执行: newgrp docker  或重新登录。"
  elif [ "$OS_FAMILY" = "rpm" ]; then
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Docker"; exit 1; }
    if ! has_docker; then
      if [ -x /usr/bin/curl ]; then
        curl -fsSL https://get.docker.com | run_sudo sh
      else
        if command -v dnf &>/dev/null; then
          run_sudo dnf install -y dnf-plugins-core
          run_sudo dnf config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
          run_sudo dnf install -y docker-ce docker-ce-cli containerd.io
        else
          run_sudo yum install -y yum-utils
          run_sudo yum-config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
          run_sudo yum install -y docker-ce docker-ce-cli containerd.io
        fi
      fi
      run_sudo systemctl enable --now docker 2>/dev/null || run_sudo service docker start 2>/dev/null || true
      run_sudo usermod -aG docker "$USER" 2>/dev/null || true
    fi
    echo "💡 若当前用户需直接运行 docker（免 sudo），请执行: newgrp docker  或重新登录。"
  else
    echo "❌ 当前系统 ($OS_ID) 暂不支持自动安装 Docker，请参考 https://docs.docker.com/engine/install/ 手动安装。"
    exit 1
  fi
  echo "✅ Docker 安装完成。"
}

# ----- Docker Compose（优先识别 docker compose 插件 v2，其次 docker-compose 独立命令） -----
has_docker_compose() {
  docker compose version &>/dev/null || docker-compose --version &>/dev/null
}

install_docker_compose() {
  echo "📦 正在安装 Docker Compose ..."
  if [ "$OS_FAMILY" = "darwin" ]; then
    if command -v brew &>/dev/null; then
      brew install docker-compose
    else
      echo "❌ 未检测到 Homebrew；或请安装 Docker Desktop（已含 Compose）。"
      exit 1
    fi
  elif [ "$OS_FAMILY" = "apt" ]; then
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Docker Compose"; exit 1; }
    run_sudo apt-get update -qq
    run_sudo apt-get install -y docker-compose-plugin
    echo "✅ Docker Compose 插件已安装（使用方式: docker compose）。"
    return 0
  elif [ "$OS_FAMILY" = "rpm" ]; then
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Docker Compose"; exit 1; }
    if command -v dnf &>/dev/null; then
      run_sudo dnf install -y docker-compose-plugin 2>/dev/null || {
        COMPOSE_VER="v2.24.0"
        run_sudo curl -sSL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        run_sudo chmod +x /usr/local/bin/docker-compose
      }
    else
      run_sudo yum install -y docker-compose-plugin 2>/dev/null || {
        COMPOSE_VER="v2.24.0"
        run_sudo curl -sSL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        run_sudo chmod +x /usr/local/bin/docker-compose
      }
    fi
  else
    # 未知系统：通用回退，下载 standalone docker-compose
    COMPOSE_VER="v2.24.0"
    echo "📥 下载 Docker Compose ${COMPOSE_VER} ..."
    can_sudo || { echo "❌ 需要 sudo 权限以安装 Docker Compose"; exit 1; }
    run_sudo curl -sSL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    run_sudo chmod +x /usr/local/bin/docker-compose
  fi
  echo "✅ Docker Compose 安装完成。"
}

# 按顺序确保所有依赖存在，缺则安装（先判断系统，再按系统类型安装）
ensure_dependencies() {
  setup_os_detect

  if ! has_git; then
    install_git
  else
    echo "✅ Git 已安装。"
  fi

  if ! has_docker; then
    install_docker
  else
    echo "✅ Docker 已安装。"
  fi

  if ! has_docker_compose; then
    install_docker_compose
  else
    echo "✅ Docker Compose 已就绪。"
  fi
}

# 执行依赖检查与自动安装
ensure_dependencies

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