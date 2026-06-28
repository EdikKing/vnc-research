# vnc-research · 远程桌面 + AI Agent 调研框架

> **核心思路**:不依赖付费云服务(零成本),不暴露公网(零安全风险),agent 和人类共享同一个 chromium 实例,登录态复用。

**标准部署**:Docker Hub 官方镜像 [`edik/vnc-research`](https://hub.docker.com/r/edik/vnc-research)(镜像构建在独立仓库 [vnc-research-docker](git@git.edik.cn:edik-project/vnc-research-docker.git) 维护)。

**用 VNC 把一台 Linux 服务器变成共享浏览器,让 AI Agent 接管所有网页调研,人类只在登录/验证码时介入。**

---

## 一键启动

```bash
docker run -d --name vnc-research \
  -p 6080:6080 -p 9222:9222 \
  --restart unless-stopped \
  edik/vnc-research
```

浏览器打开 http://localhost:6080/vnc.html,看到 VNC 桌面 = 成功。

> 详细参数(自定义分辨率 / 持久化数据等)见 [docs/02-部署指南.md](docs/02-部署指南.md)。

---

## 核心协作原则(🔴 最重要)

- agent 默认自动操作任何网页任务(调研/抓取/操作/监控)
- 遇到 **登录墙 / 滑块 / 验证码 / 扫码 / 支付** 等 agent 处理不了的情况 → **立即暂停**
- 暂停时输出**带 VNC 链接** 的标准通知:

```text
🛑 暂停:需要操作员介入
任务:登录小红书
原因:搜索页显示 '登录后查看'

👉 VNC 浏览器:http://你的服务器IP:6080/vnc.html
```

- 操作员在 VNC 操作完说 "搞定了" → agent reload + 继续

完整协议见 [skills/SKILL.md](skills/SKILL.md) 的 **"🔴 操作员介入协议"** 章节。

完整使用指南和场景化协作流程见 [docs/03-使用指南.md](docs/03-使用指南.md)。

---

## 30 秒看懂架构

```text
[你的浏览器] → http://<host>:6080/vnc.html
                     ↓ WebSocket
              [容器 noVNC :6080] ──→ [x11vnc :5900] ──→ [Xvfb :99 虚拟显示]
                                                                       ↑
                                                            [chromium :9222]
                                                                       ↑
                                              [AI Agent:playwright CDP 控制]
```

**关键点**:
1. 一台 Linux + Docker 引擎就够了
2. chromium 启动时开 `--remote-debugging-port=9222`,AI 用 playwright 连过去
3. 你的 VNC 浏览器和 AI agent 操作**同一个 chromium 实例**,登录态/cookie/标签页全共享
4. 你**只在登录墙或滑块时介入**(在 VNC 端手动操作),agent 自动接管其他一切
5. **默认内网**,不需要公网 IP;如需从公网访问,见 [docs/06-外网访问.md](docs/06-外网访问.md)(ngrok 隧道 + 双层鉴权)

---

## 适合谁用

- 需要做大量**中文平台调研**(小红书/抖音/知乎/B站/公众号/微博...) 的人
- 经常被**登录墙/滑块验证码**阻挡的 AI Agent 用户
- 想把网页调研**完全自动化**但不想花钱买 BrowserAct/Browserbase 的人
- 有一台 Linux 服务器(VPS/旧电脑/树莓派都行)能跑 Docker 的人
- 需要**自动化操作网页**(发内容、填表、监控价格、跨平台聚合)的人
- 想**复用自己登录态**做个人数据查询(微信/邮箱/订单)的人

---

## 详细文档

- [docs/00-快速开始.md](docs/00-快速开始.md) · 5 分钟跑起来
- [docs/02-部署指南.md](docs/02-部署指南.md) · Docker 部署 + 自定义参数
- [docs/06-外网访问.md](docs/06-外网访问.md) · ngrok 外网访问 + 鉴权与安全
- [docs/03-使用指南.md](docs/03-使用指南.md) · 怎么用(操作员协议)
- [docs/01-架构详解.md](docs/01-架构详解.md) · 组件详解 + 数据流
- [skills/SKILL.md](skills/SKILL.md) · AI agent 用的协议

---

## 目录结构

```text
vnc-research/
├── README.md           # 你正在看
├── LICENSE             # MIT
├── CHANGELOG.md        # 版本历史
├── docs/               # 6 篇教程文档
├── examples/           # 实战案例(小红书搜索 / use-cases)
├── skills/SKILL.md     # AI agent 协议(操作员介入)
└── assets/             # 截图
```

> ⚠️ v0.3.0 起:Dockerfile + scripts/ 已迁出到独立仓库 [vnc-research-docker](git@git.edik.cn:edik-project/vnc-research-docker.git),本仓库**纯文档化**。
> 用户用 `docker run edik/vnc-research` 启动,**不再** `git clone` + 跑脚本。

---

## 跟其他方案对比

| 方案 | 月成本 | 内网友好 | 登录态持久 | 拦截能力 | 上手难度 |
|------|-------|---------|----------|---------|---------|
| **vnc-research(本项目)** | **0 元** | ✅ 完全内网 | ✅ 永久 | ✅ 完整 Chromium | ⭐⭐ 中等 |
| BrowserAct remote-assist | 50K credits/月 | ✅ 内网 | ❌ 单次 | 🟡 部分 | ⭐ 简单 |
| Browserless / Browserbase | $50-300/月 | ⚠️ 第三方 | ❌ 单次 | ✅ 完整 | ⭐ 简单 |
| 本地 Playwright(自己跑) | 0 元 | ✅ | ❌ 单次 | ⚠️ 看代理 | ⭐⭐⭐ 较难 |
| undetected-chromedriver | 0 元 | ✅ | ❌ 单次 | 🟡 部分 | ⭐⭐⭐⭐ 难 |

**vnc-research 的独特价值**:**完全内网** + **零成本** + **登录态永久** + **人类 AI 共享同一浏览器**。

---

## 实测验证(2026-06-26)

- ✅ 小红书"AI 编程"搜索 → 20 条笔记详情,45 秒完成
- ✅ 0 人类介入 / 0 credit 消耗 / 0 拦截
- ✅ 数据落 `/tmp/xhs_details.json`,Markdown 报告可读
- ✅ VNC 浏览器正常显示,agent 用 playwright 操作同一实例

详见 [examples/xiaohongshu-search.md](examples/xiaohongshu-search.md)。

---

## 安全与鉴权

默认 Docker 镜像:
- **ngrok basic-auth**(外网访问时用,见 [06-外网访问](docs/06-外网访问.md))
- **单层鉴权**:ngrok basic-auth 防扫描(基础防护足够)

⚠️ **不鉴权 = 灾难**:任何扫到 ngrok 链接的人都能操控你的浏览器 → 用你的 cookie 登录的账号写评论 / 发消息 / 改密码 / 转账。

详细鉴权与安全配置见 [docs/06-外网访问.md](docs/06-外网访问.md)。

---

## 风险与限制

- **镜像只支持 Linux 部署**(macOS/Windows 需要 WSL 或 Linux VM)
- **一台服务器 = 一个用户**(多用户需要每人一组端口)
- **需要 Docker 引擎** ≥ 20.10
- 不解决 datacenter IP 拦截(但已登录 cookie 不受影响)

---

## 快速使用

1. **部署**:`docker run -d --name vnc-research -p 6080:6080 -p 9222:9222 edik/vnc-research`(详见 [docs/02-部署指南.md](docs/02-部署指南.md))
2. **浏览器打开 VNC**:http://你的服务器IP:6080/vnc.html
3. **让 AI agent 跑调研任务**:加载 [skills/SKILL.md](skills/SKILL.md)
4. **更多场景**:[examples/use-cases.md](examples/use-cases.md)(15 个实战场景:调研/抓取/操作/监控/聚合)

有问题提 issue。

---

## 贡献

发现新坑 / 有改进建议 → 提 issue 或直接改 docs/。

---

## License

MIT
