#!/bin/bash
# start-all.sh - 启动 vnc-research 整套服务
#
# 用法: sudo ./start-all.sh
# 停止: sudo ./stop-all.sh
# 健康: ./health-check.sh

set -e

# ---------- 配置 ----------
XVFB_DISPLAY=:99
XVFB_RESOLUTION="1280x800x24"
VNC_PORT=5900
NOVNC_PORT=6080
DEVTOOLS_PORT=9222
CHROMIUM_WINDOW_SIZE="1280,800"
CHROMIUM_USER_DATA_DIR="$HOME/.config/chromium"
CHROMIUM_START_URL="about:blank"
LOG_DIR="/var/log/vnc-research"
mkdir -p "$LOG_DIR" 2>/dev/null || { LOG_DIR="/tmp/vnc-research-logs"; mkdir -p "$LOG_DIR"; }

echo "Log dir: $LOG_DIR"

# ---------- 1. Xvfb ----------
echo "[1/4] 启动 Xvfb ..."
if pgrep -f "Xvfb $XVFB_DISPLAY" >/dev/null; then
    echo "    Xvfb 已在运行"
else
    Xvfb $XVFB_DISPLAY -screen 0 $XVFB_RESOLUTION -ac +extension GLX +render -noreset \
        >> "$LOG_DIR/xvfb.log" 2>&1 &
    sleep 2
fi
echo "    Xvfb $XVFB_DISPLAY OK"

# ---------- 2. x11vnc ----------
echo "[2/4] 启动 x11vnc ..."
if pgrep -f "x11vnc.*$XVFB_DISPLAY" >/dev/null; then
    echo "    x11vnc 已在运行"
else
    x11vnc -display $XVFB_DISPLAY -forever -shared -rfbport $VNC_PORT -nopw \
        -o "$LOG_DIR/x11vnc.log" \
        >> "$LOG_DIR/x11vnc.out" 2>&1 &
    sleep 1
fi
echo "    x11vnc :$VNC_PORT OK"

# ---------- 3. websockify + noVNC ----------
echo "[3/4] 启动 noVNC ..."
if pgrep -f "websockify.*$NOVNC_PORT" >/dev/null; then
    echo "    noVNC 已在运行"
else
    websockify --web=/usr/share/novnc $NOVNC_PORT localhost:$VNC_PORT \
        >> "$LOG_DIR/novnc.log" 2>&1 &
    sleep 1
fi
echo "    noVNC :$NOVNC_PORT OK"

# ---------- 4. chromium ----------
echo "[4/4] 启动 chromium ..."
if pgrep -f "chromium.*remote-debugging-port=$DEVTOOLS_PORT" >/dev/null; then
    echo "    chromium 已在运行"
else
    DISPLAY=$XVFB_DISPLAY \
    /usr/lib/chromium/chromium \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --no-first-run \
        --remote-debugging-port=$DEVTOOLS_PORT \
        --remote-debugging-address=127.0.0.1 \
        --user-data-dir=$CHROMIUM_USER_DATA_DIR \
        --window-size=$CHROMIUM_WINDOW_SIZE \
        --window-position=0,0 \
        $CHROMIUM_START_URL \
        >> "$LOG_DIR/chromium.log" 2>&1 &
    sleep 4
fi
echo "    chromium :$DEVTOOLS_PORT OK"

# ---------- 完成 ----------
echo ""
echo "=== vnc-research 启动完成 ==="
echo ""
echo "VNC 浏览器:  http://你的服务器IP:$NOVNC_PORT/vnc.html"
echo "DevTools:    http://127.0.0.1:$DEVTOOLS_PORT  (仅本机)"
echo ""
echo "运行健康检查: ./health-check.sh"