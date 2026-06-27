#!/bin/bash
# start-all.sh - 启动 vnc-research 整套服务
#
# 用法: sudo ./start-all.sh
# 停止: sudo ./stop-all.sh
# 健康: ./health-check.sh

set -e

# ---------- 0. 环境自检 ----------
echo "[0/4] 环境自检 ..."
missing=()

# 必须有的命令
for cmd in Xvfb x11vnc websockify python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
    fi
done

# chromium:不同系统路径不一样
if ! command -v chromium >/dev/null 2>&1 \
   && ! command -v chromium-browser >/dev/null 2>&1 \
   && [ ! -x /usr/bin/chromium ] \
   && [ ! -x /snap/bin/chromium ]; then
    missing+=("chromium")
fi

# python3 还要看 playwright 是否装了
if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import playwright" 2>/dev/null; then
        missing+=("python3-playwright (pip install playwright && playwright install chromium)")
    fi
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    echo "❌ 环境缺以下依赖,无法启动:"
    printf '   - %s\n' "${missing[@]}"
    echo ""
    echo "安装命令(以 Debian/Ubuntu 为例):"
    echo "  sudo apt update && sudo apt install -y xvfb x11vnc websockify chromium python3-pip"
    echo "  pip install playwright && playwright install chromium"
    echo ""
    exit 1
fi

echo "    环境自检通过"

# ---------- 配置 ----------
XVFB_DISPLAY=:99
# Xvfb 分辨率(env 覆盖,默认 1280x800x24)
XVFB_RESOLUTION="${DISPLAY_RESOLUTION:-1280x800x24}"
VNC_PORT=5900
NOVNC_PORT=6080
DEVTOOLS_PORT=9222
# 同步联动:chromium 窗口 size 从 Xvfb 分辨率拆出来
# 例如 "1920x1080x24" → "1920,1080"
XVFB_W_H="${XVFB_RESOLUTION%x*}"   # "1280x800"
CHROMIUM_WINDOW_SIZE="${XVFB_W_H/x/,}"   # "1280,800"
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
    # ---------- VNC 密码 ----------
    # 默认自动生成 8 位数字密码(每次启动随机,启动时日志打印)
    # 用户可用 env 覆盖:export VNC_PASSWORD=mypass
    # 密码生成失败时 fallback 到文件方式,不 exit
    mkdir -p "$HOME/.vnc"
    if [ -z "$VNC_PASSWORD" ]; then
        if VNC_PASSWORD=$(shuf -i 10000000-99999999 -n 1 2>/dev/null) && [ -n "$VNC_PASSWORD" ]; then
            :
        else
            # fallback:用日期+随机数拼一个
            VNC_PASSWORD="$(date +%s | tail -c 8)$(shuf -i 100-999 -n 1 2>/dev/null || echo 000)"
            echo "[!] shuf 失败,fallback 密码:$VNC_PASSWORD (8 位内数字)"
        fi
        echo ""
        echo "=========================================================="
        echo "🔐 VNC 密码(本次启动自动生成):$VNC_PASSWORD"
        echo "   ⚠️  这是 VNC 密码,外网访问必须配 VNC 密码 + 推荐加 basic-auth"
        echo "   用户自设密码:export VNC_PASSWORD=你的密码  再启动"
        echo "=========================================================="
        echo ""
    else
        echo "    使用环境变量 VNC_PASSWORD(自定义密码)"
    fi

    # 写密码文件:优先 x11vncpasswd 生成加密格式,fallback 明文
    if command -v x11vncpasswd >/dev/null 2>&1; then
        echo "$VNC_PASSWORD" | x11vncpasswd -f > "$HOME/.vnc/passwd" 2>/dev/null || \
            { echo "$VNC_PASSWORD" > "$HOME/.vnc/passwd"; echo "[!] x11vncpasswd 失败,用明文 fallback"; }
    else
        echo "$VNC_PASSWORD" > "$HOME/.vnc/passwd"
    fi
    chmod 600 "$HOME/.vnc/passwd"

    x11vnc -display $XVFB_DISPLAY -forever -shared -rfbport $VNC_PORT \
        -rfbauth "$HOME/.vnc/passwd" \
        -o "$LOG_DIR/x11vnc.log" \
        >> "$LOG_DIR/x11vnc.out" 2>&1 &
    sleep 1
fi
echo "    x11vnc :$VNC_PORT OK(已启用密码)"

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
if [ -n "$VNC_PASSWORD" ]; then
    echo "🔐 VNC 密码: $VNC_PASSWORD"
    echo "   (密码也在上方启动日志和本次启动的 x11vnc.out 里)"
else
    echo "🔐 VNC 密码: 见上方启动日志"
fi
echo ""
echo "外网访问: ./scripts/start-ngrok.sh"
echo "运行健康检查: ./health-check.sh"
