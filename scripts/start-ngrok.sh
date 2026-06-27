#!/bin/bash
# start-ngrok.sh - 启动 ngrok 隧道,把 vnc-research 的 noVNC 暴露到外网
#
# ⚠️ 安全提示:外网访问有风险,务必先看 docs/06-外网访问.md 的"风险提示"
#
# 用法:
#   # 默认(free anonymous,HTTP 隧道,6080 端口)
#   ./scripts/start-ngrok.sh
#
#   # 带 basic-auth(推荐)
#   export NGROK_USER="edik"
#   export NGROK_PASS="$(openssl rand -base64 16)"
#   ./scripts/start-ngrok.sh
#
#   # 带 authtoken(注册 ngrok 账号后获得,配置后 tunnel 更稳定)
#   export NGROK_AUTHTOKEN="2abc...xyz"
#   ./scripts/start-ngrok.sh
#
#   # TCP 隧道(给 VNC 客户端用,不走浏览器)
#   export NGROK_TCP=1
#   ./scripts/start-ngrok.sh

set -e

# ---------- 配置 ----------
NOVNC_PORT=6080
VNC_PORT=5900
NGROK_REGION="${NGROK_REGION:-us}"
NGROK_DOMAIN="${NGROK_DOMAIN:-}"  # 付费 plan 才能用

# ---------- 0. 自检 ----------
if ! command -v ngrok >/dev/null 2>&1; then
    echo "❌ ngrok 未安装"
    echo "安装:"
    echo "  # Debian/Ubuntu"
    echo "  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null 2>&1"
    echo "  echo 'deb https://ngrok-agent.s3.amazonaws.com buster main' | sudo tee /etc/apt/sources.list.d/ngrok.list"
    echo "  sudo apt update && sudo apt install ngrok"
    echo "  # 或 snap"
    echo "  sudo snap install ngrok"
    echo "  # 或 macOS"
    echo "  brew install ngrok/ngrok/ngrok"
    exit 1
fi

# ---------- 1. authtoken(可选) ----------
if [ -n "$NGROK_AUTHTOKEN" ]; then
    echo "[1/3] 配置 ngrok authtoken ..."
    ngrok config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1
    echo "    authtoken 配置完成"
fi

# ---------- 2. 隧道启动 ----------
echo "[2/3] 启动 ngrok 隧道 ..."

NGROK_CMD=(ngrok)

# authtoken 已设 → 走用户配置;否则 free anonymous
if [ -n "$NGROK_AUTHTOKEN" ]; then
    # 用 --region 和 (可选) --domain
    [ -n "$NGROK_DOMAIN" ] && NGROK_CMD+=("--domain=$NGROK_DOMAIN")
fi

NGROK_CMD+=("--region=$NGROK_REGION")

# TCP 还是 HTTP
if [ "${NGROK_TCP:-0}" = "1" ]; then
    # TCP 隧道(给 VNC 客户端用)
    NGROK_CMD+=("tcp" "$VNC_PORT")
    echo "    模式:TCP(直连 VNC,端口 $VNC_PORT)"
else
    # HTTP 隧道(给浏览器用,noVNC 走 6080)
    NGROK_CMD+=("http" "$NOVNC_PORT")
    echo "    模式:HTTP(浏览器 noVNC,端口 $NOVNC_PORT)"
fi

# basic-auth(可选)
if [ -n "$NGROK_USER" ] && [ -n "$NGROK_PASS" ]; then
    NGROK_CMD+=("--basic-auth" "$NGROK_USER:$NGROK_PASS")
    echo "    basic-auth:已启用(用户名=$NGROK_USER)"
else
    echo "    basic-auth:未启用(⚠️ 强烈建议设 NGROK_USER + NGROK_PASS)"
fi

# ---------- 3. 启动 ----------
echo "[3/3] 启动中 ..."
echo ""
echo "📌 提示:启动后会输出 ngrok URL,复制那个 URL 给外网用户即可"
echo "   Ctrl+C 退出隧道"
echo ""

exec "${NGROK_CMD[@]}"