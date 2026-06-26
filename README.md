# vnc-research · 远程桌面 + AI Agent 调研框架

> **用 VNC 把一台 Linux 服务器变成共享浏览器,让 AI Agent 接管所有网页调研,人类只在登录/验证码时介入。**

**核心思路**: 不依赖付费云服务(零成本),不暴露公网(零安全风险),agent 和人类共享同一个 chromium 实例,登录态复用,数据本地落盘。

**核心协作原则**(🔴 最重要):
- agent 默认自动操作任何网页任务(调研/抓取/操作/监控)
- 遇到 **登录墙 / 滑块 / 验证码 / 扫码 / 支付** 等 agent 处理不了的情况 → **立即暂停**
- 暂停时输出**带 VNC 链接** 的标准通知:
  ```
  🛑 暂停: 需要操作员介入
  任务: 登录小红书
  原因: 搜索页显示 '登录后查看'
  
  👉 VNC 浏览器: http://你的服务器IP:6080/vnc.html
  ```
- 操作员在 VNC 操作完说 "搞定了" → agent reload + 继续

完整协议见 `skills/SKILL.md` 的 **"🔴 操作员介入协议"** 章节。

---

## 适合谁用

- 需要做大量**中文平台调研**(小红书/抖音/知乎/B站/公众号/微博...) 的人
- 经常被**登录墙/滑块验证码**阻挡的 AI Agent 用户
- 想把网页调研**完全自动化**但不想花钱买 BrowserAct/Browserbase 的人
- 有一台 Linux 服务器(VPS/旧电脑/树莓派都行)可以装 Xvfb 的人
- 需要**自动化操作网页**(发内容、填表、监控价格、跨平台聚合)的人
- 想**复用自己登录态**做个人数据查询(微信/邮箱/订单)的人

---

## 目录结构

```
vnc-research/
├── README.md                # 你正在看
├── LICENSE                  # MIT 协议
├── CHANGELOG.md             # 版本历史
├── docs/                    # 6 篇教程文档
├── skills/SKILL.md          # 🔴 操作员介入协议(协议核心)
├── scripts/                 # 一键启动 / 健康检查 / playwright 连接
└── examples/                # 实战案例(小红书搜索 / use-cases)
```

## 30 秒看懂架构

```
[你的浏览器] → http://你的服务器IP:6080/vnc.html
                    ↓ WebSocket
              [服务器 noVNC :6080] ──→ [x11vnc :5900] ──→ [Xvfb :99 虚拟显示]
                                                                       ↑
                                                            [chromium :9222]
                                                                       ↑
                                              [AI Agent: playwright CDP 控制]
```

**关键点**:
1. 一台 Linux 机器就够了(已经有现成的 Xvfb :99 也能直接用)
2. chromium 启动时开 `--remote-debugging-port=9222`,AI 用 playwright 连过去
3. 你的 VNC 浏览器和 AI agent 操作**同一个 chromium 实例**,登录态/cookie/标签页全共享
4. 你**只在登录墙或滑块时介入**(在 VNC 端手动操作),agent 自动接管其他一切
5. **完全内网**,不需要公网 IP,不需要 ngrok/cloudflared

---

## 这个项目里有什么

```
vnc-research/
├── README.md          ← 你现在看的
├── docs/
│   ├── 00-快速开始.md     ← 5 分钟跑起来
│   ├── 01-架构详解.md     ← 组件详解 + 数据流
│   ├── 02-部署指南.md     ← 一步步教你装
│   ├── 03-使用指南.md     ← agent + 你 怎么配合
│   ├── 04-踩坑记录.md     ← 我踩过的所有坑(省你时间)
│   └── 05-安全考量.md     ← 内网/隐私/账号风险
├── scripts/
│   ├── start-all.sh       ← 一键启动所有服务
│   ├── stop-all.sh        ← 一键关闭
│   ├── health-check.sh    ← 检查服务状态
│   └── playwright-connect.py  ← 演示怎么用 playwright 连
├── skills/
- `skills/SKILL.md` — AI agent 用的标准 skill(每次调研任务都加载这个)
├── examples/
│   ├── xiaohongshu-search.md  ← 端到端实测样例(调研类)
│   └── use-cases.md           ← 15 个应用场景(调研/抓取/操作/监控/聚合)
└── assets/
    └── architecture-diagram.svg  ← 架构图(可选)
```

---

## 快速开始

**5 分钟内跑起来**:

```bash
# 1. 装依赖
sudo apt install -y x11vnc novnc websockify

# 2. 启动虚拟显示 + VNC + 浏览器(脚本方式,见 docs/02-部署指南.md)
cd /root/project/docs/vnc-research/scripts
chmod +x *.sh
./start-all.sh

# 3. 浏览器打开 VNC
# http://你的服务器IP:6080/vnc.html

# 4. 让你的 AI agent 跑调研任务(加载 skills/SKILL.md)
```

**详细步骤**见 [docs/00-快速开始.md](docs/00-快速开始.md)

---

## 跟其他方案对比

| 方案 | 月成本 | 内网友好 | 登录态持久 | 拦截能力 | 上手难度 |
|------|-------|---------|----------|---------|---------|
| **vnc-research(本项目)** | **0 元** | ✅ 完全内网 | ✅ 永久 | ✅ 完整 Chromium | ⭐⭐ 中等 |
| BrowserAct remote-assist | 50K credits/月 | ✅ 内网 | ❌ 单次 | 🟡 部分 | ⭐ 简单 |
| Browserless / Browserbase | $50-300/月 | ⚠️ 第三方 | ❌ 单次 | ✅ 完整 | ⭐ 简单 |
| 本地 Playwright(自己跑) | 0 元 | ✅ | ❌ 单次 | ⚠️ 看代理 | ⭐⭐⭐ 较难 |
| undetected-chromedriver | 0 元 | ✅ | ❌ 单次 | 🟡 部分 | ⭐⭐⭐⭐ 难 |

**vnc-research 的独特价值**:**完全内网** + **零成本** + **登录态永久** + **人类 AI 共享同一浏览器**

---

## 实测验证(2026-06-26)

- ✅ 小红书"AI 编程"搜索 → 20 条笔记详情,45 秒完成
- ✅ 0 人类介入 / 0 credit 消耗 / 0 拦截
- ✅ 数据落 `/tmp/xhs_details.json`,Markdown 报告可读
- ✅ VNC 浏览器正常显示,agent 用 playwright 操作同一实例

详见 [examples/xiaohongshu-search.md](examples/xiaohongshu-search.md)

---

## 风险与限制

- **需要 Linux 服务器**(macOS/Windows 也行但本项目以 Linux 为主)
- **需要 root 权限**(装包 + 启动 Xvfb)
- **一台服务器 = 一个人用**(多用户需要每人一组端口,或者改用 Kasm/Selenium Grid)
- **agent 操作 chromium 时会触发同样的 IP 风控**(没有 stealth 优势,适合"已登录账号 + 国内平台"的场景)
- **不解决 datacenter IP 拦截**(小红书 datacenter IP 还是会被拦,但你的 cookie 在就没问题)

---

## 贡献

发现新坑 / 有改进建议 → 提 issue 或直接改 docs/

## 快速使用

1. **克隆仓库**:`git clone git@git.edik.cn:edik-project/vnc-research.git && cd vnc-research`
2. **看 5 分钟快速开始**:[docs/00-快速开始.md](docs/00-快速开始.md)
3. **部署到服务器**:[docs/02-部署指南.md](docs/02-部署指南.md)
4. **遇到坑了**?[docs/04-踩坑记录.md](docs/04-踩坑记录.md)

完整目录见下,有问题提 issue。

---

## License

MIT