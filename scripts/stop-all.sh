#!/bin/bash
# stop-all.sh - 停止 vnc-research 整套服务
#
# 用法: sudo ./stop-all.sh
# 启动: ./start-all.sh

echo "停止 vnc-research 服务..."

# 1. chromium
echo "[1/4] 停止 chromium..."
pkill -f "chromium.*remote-debugging-port" 2>/dev/null && echo "    OK" || echo "    未运行"

# 2. websockify + noVNC
echo "[2/4] 停止 noVNC..."
pkill -f "websockify.*6080" 2>/dev/null && echo "    OK" || echo "    未运行"

# 3. x11vnc
echo "[3/4] 停止 x11vnc..."
pkill -f "x11vnc.*:99" 2>/dev/null && echo "    OK" || echo "    未运行"

# 4. Xvfb (小心:可能影响其他服务)
echo "[4/4] Xvfb :99 不自动停止(可能影响其他服务)"
echo "    如需停止: pkill -f 'Xvfb :99'"
echo ""

echo "=== 停止完成 ==="
echo ""
echo "启动: ./start-all.sh"
echo "健康检查: ./health-check.sh"