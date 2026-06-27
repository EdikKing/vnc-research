# Dockerfile for vnc-research
#
# ===========================================================================
# 用法 (Usage)
# ===========================================================================
# 构建镜像:
#   docker build -t vnc-research:0.2.0 .
#
# 启动容器(最小):
#   docker run -d --name vnc-research \
#     -p 6080:6080 -p 9222:9222 \
#     vnc-research:0.2.0
#
# 启动容器(推荐,带 VNC 密码 + 自定义分辨率):
#   docker run -d --name vnc-research \
#     -p 6080:6080 -p 9222:9222 \
#     -e VNC_PASSWORD=你的密码 \
#     -e DISPLAY_RESOLUTION=1920x1080x24 \
#     vnc-research:0.2.0
#
# 查看 noVNC:
#   浏览器打开 http://<host>:6080/vnc.html
#
# 注意:
#   - 本镜像不含 ngrok(ngrok 在宿主机跑,见 docs/06-外网访问.md 第 5 节)
#   - VNC 端口 5900 默认不暴露,如需直连 VNC 客户端请自行映射 -p 5900:5900
#   - Chromium DevTools 9222 用于 Playwright/CDP 远程调试
# ===========================================================================

FROM debian:13-slim

LABEL maintainer="Edik <hermes@edik.cn>" \
      version="0.2.0" \
      description="vnc-research: VNC + noVNC + Chromium 一体化研究环境(debian:13-slim)"

# ---------- 1. 系统依赖 ----------
# xvfb        虚拟 X server
# x11vnc      把 Xvfb 暴露成 VNC
# novnc       noVNC 的 noVNC 服务(HTML5 客户端)
# websockify  VNC → WebSocket 桥
# chromium    浏览器(CDP 远程调试端口 9222)
# x11-apps    xdpyinfo 等 X 工具
# python3-venv 创建 venv 隔离 playwright
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        x11vnc \
        novnc \
        websockify \
        chromium \
        ca-certificates \
        curl \
        sudo \
        python3 \
        python3-pip \
        python3-venv \
        x11-apps \
    && rm -rf /var/lib/apt/lists/*

# ---------- 2. 非 root 用户 ----------
RUN useradd -m -s /bin/bash vncuser \
    && echo "vncuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vncuser \
    && chmod 0440 /etc/sudoers.d/vncuser

# ---------- 3. Python venv + Playwright ----------
RUN python3 -m venv /opt/vnc-research-venv \
    && /opt/vnc-research-venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/vnc-research-venv/bin/pip install --no-cache-dir playwright \
    && /opt/vnc-research-venv/bin/playwright install chromium

# ---------- 4. 启动脚本 ----------
COPY --chown=root:root scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh \
    && chown vncuser:vncuser /usr/local/bin/*.sh

# ---------- 5. 工作目录 ----------
WORKDIR /home/vncuser/app
RUN chown vncuser:vncuser /home/vncuser/app

# ---------- 6. 切非 root ----------
USER vncuser

# ---------- 分辨率配置(可被 -e 覆盖)----------
# 默认 1280x800x24(笔记本友好,省内存);用户可改:
#   docker run -e DISPLAY_RESOLUTION=1920x1080x24 vnc-research
# start-all.sh 自动同步 chromium 窗口 size(无需单独配置)
ENV DISPLAY_RESOLUTION=1280x800x24

# ---------- 7. 暴露端口 ----------
# 6080  noVNC Web UI(浏览器访问)
# 9222  Chromium DevTools(Playwright/CDP 远程调试)
EXPOSE 6080 9222

# ---------- 8. 入口 ----------
ENTRYPOINT ["/usr/local/bin/start-all.sh"]