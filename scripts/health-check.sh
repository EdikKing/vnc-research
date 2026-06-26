#!/bin/bash
# health-check.sh - 检查 vnc-research 整套服务状态
#
# 用法: ./health-check.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_ok() { echo -e "${GREEN}✓${NC} $1"; }
check_fail() { echo -e "${RED}✗${NC} $1"; }
check_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "=== vnc-research Health Check ==="
echo ""

# Xvfb
echo "[Xvfb :99]"
if pgrep -f "Xvfb :99" >/dev/null; then
    PID=$(pgrep -f "Xvfb :99")
    check_ok "Running (PID $PID)"
else
    check_fail "NOT running. Run: ./start-all.sh"
fi

# x11vnc
echo ""
echo "[x11vnc :5900]"
if ss -tln 2>/dev/null | grep -q ':5900 '; then
    check_ok "Listening on 0.0.0.0:5900"
else
    check_fail "NOT listening"
fi

# noVNC
echo ""
echo "[noVNC :6080]"
if ss -tln 2>/dev/null | grep -q ':6080 '; then
    check_ok "Listening on 0.0.0.0:6080"
    HTTP=$(curl -s --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:6080/vnc.html)
    if [ "$HTTP" = "200" ]; then
        check_ok "HTTP /vnc.html returns 200"
    else
        check_warn "HTTP /vnc.html returns $HTTP"
    fi
else
    check_fail "NOT listening"
fi

# chromium DevTools
echo ""
echo "[chromium DevTools :9222]"
if ss -tln 2>/dev/null | grep -q ':9222 '; then
    check_ok "Listening on 127.0.0.1:9222"
    VERSION=$(curl -s --max-time 3 http://127.0.0.1:9222/json/version 2>/dev/null)
    if [ -n "$VERSION" ]; then
        BROWSER=$(echo "$VERSION" | grep -o '"Browser": "[^"]*"' | head -1)
        check_ok "DevTools accessible - $BROWSER"

        # 抓页面数
        PAGES=$(curl -s --max-time 3 http://127.0.0.1:9222/json/list 2>/dev/null | grep -o '"type":' | wc -l)
        check_ok "Open pages: $PAGES"
    else
        check_warn "DevTools port 9222 listening but no response"
    fi
else
    check_fail "NOT listening on 9222"
fi

# chromium profile
echo ""
echo "[chromium profile]"
if [ -d "$HOME/.config/chromium/Default" ]; then
    SIZE=$(du -sh "$HOME/.config/chromium/Default" 2>/dev/null | cut -f1)
    check_ok "Profile at $HOME/.config/chromium/Default ($SIZE)"
else
    check_warn "No profile yet - first run will create it"
fi

# 总结
echo ""
echo "=== Summary ==="
SERVICES_UP=$(( $(pgrep -f "Xvfb :99" >/dev/null && echo 1 || echo 0) + $(ss -tln 2>/dev/null | grep -q ':5900 ' && echo 1 || echo 0) + $(ss -tln 2>/dev/null | grep -q ':6080 ' && echo 1 || echo 0) + $(ss -tln 2>/dev/null | grep -q ':9222 ' && echo 1 || echo 0) ))
if [ "$SERVICES_UP" = "4" ]; then
    echo -e "${GREEN}All 4 services operational${NC}"
elif [ "$SERVICES_UP" -ge "2" ]; then
    echo -e "${YELLOW}Partial ($SERVICES_UP/4) - check failed items${NC}"
else
    echo -e "${RED}Most services down - run ./start-all.sh${NC}"
fi