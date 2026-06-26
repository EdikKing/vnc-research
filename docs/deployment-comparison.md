# 部署方式对比 · vnc-research

> 本文档横向对比 3 种部署方式:**本机直装 / Docker 容器化 / systemd 服务化**。本文档**不下结论**,Edik 和朋友根据自己场景挑。

---

## 3 种部署方式概述

### 方式一 · 本机直装(bare-metal)

直接在 Linux 服务器上 `apt install` 一堆包,然后跑 [`scripts/start-all.sh`](../scripts/start-all.sh)。

**典型路径**:开发机 / 测试机 / 个人 VPS 上,想 5 分钟看到画面就用这个。

参考 [docs/02-部署指南.md · 方案 A](02-部署指南.md#方案-a快速测试5-分钟)。

### 方式二 · Docker 容器化

把整套环境(Xvfb + x11vnc + noVNC + chromium)打包成镜像,容器内运行。

**典型路径**:在 CI 跑、在多台机器批量铺、想跟宿主机其他服务完全隔离。

参考 [docs/02-部署指南.md · 方案 C](02-部署指南.md#方案-cdocker-部署隔离干净)。

### 方式三 · systemd 服务化

把 `start-all.sh` 拆成 4 个 systemd unit(Xvfb / x11vnc / noVNC / chromium),实现**开机自启 + 进程守护 + journald 日志**。

**典型路径**:生产服务器,要长期稳定跑,崩了自动拉起。

参考 [docs/02-部署指南.md · 方案 B](02-部署指南.md#方案-b生产部署systemd-服务化)。

---

## 横向对比表

| 维度 | 本机直装 | Docker | systemd |
|------|---------|--------|---------|
| **启动难度** | ⭐ 最简单。`apt install` + 跑脚本,5 分钟看到画面 | ⭐⭐⭐ 较难。要先装 Docker 引擎 + 写 Dockerfile + 处理 X11 socket 转发 + 构建镜像 | ⭐⭐ 中等。要写 4 份 `.service` 文件 + `daemon-reload` + `enable`,但有现成模板可抄 |
| **隔离性** | ❌ 跟宿主机所有包混在一起。chromium / Xvfb / python 依赖直接装到系统 | ✅ 容器内独立文件系统,主机包管理器看不到镜像里的东西 | 🟡 介于两者之间。包装在系统里,但进程被 systemd 隔离(独立 cgroup / 环境变量) |
| **卸载难度** | ❌ 比较烦。`apt purge` 之后还得手动清 `/var/log/vnc-research/`、`~/.config/chromium/`、profile 残留 | ✅ 最干净。`docker rm -f vnc-research && docker image rm vnc-research` 完事,主文件系统零残留 | 🟡 中等。`systemctl disable --now` + `apt purge` + 手动清 unit 文件和用户配置 |
| **调试难度** | ✅ 最容易。所有进程就在前台 / 后台,日志在 `/var/log/vnc-research/` 或直接 stderr,`pgrep` / `ss` 一眼看到 | ❌ 最难。要 `docker exec -it vnc-research bash` 进容器,日志要 `docker logs`,X11 转发排查链路长 | ✅ 容易。`systemctl status` + `journalctl -u` 看日志,跟普通进程调试没区别 |
| **性能** | ✅ 最优。原生进程,无虚拟化开销,X11 socket 直接走 `/tmp/.X11-unix` | 🟡 略损耗。CPU / 内存差异很小(< 3%),但 chromium 启动比裸机慢 1-2 秒(容器初始化) | ✅ 等同本机直装。systemd 只是拉起进程的管家,自己不开销性能 |
| **端口冲突** | 🟡 中等。5900 / 6080 / 9222 跟宿主机其他服务可能撞,要手动改 `start-all.sh` 里的端口变量 | ✅ 低。`-p 6080:6080` 映射可控,要改也只改 `docker run` 一行 | 🟡 中等。端口写死在 unit 文件里,要改得 `systemctl edit` 覆盖 |
| **跨平台** | ❌ 仅 Linux。macOS 装 Xvfb 要折腾 XQuartz,Windows 完全不支持 | ✅ 强。镜像里装啥版本就啥版本,Debian 13 / Ubuntu 24 / Alpine 随便挑,CI 流水线一次构建到处跑 | ❌ 仅 Linux。要 systemd,macOS 用 launchd,Windows 用服务管理器,得重写 |
| **适合谁** | 个人开发者 / 一次性测试 / 学习原理用 | CI / 批量部署 / 想跟主机环境隔离的人 | 生产服务器 / 长期运行 / 要崩了自动拉起的人 |

---

## 每种方式展开说明

### 方式一 · 本机直装

**做法**:`apt install xvfb x11vnc websockify chromium` → `./scripts/start-all.sh` → 浏览器打开 `http://服务器IP:6080/vnc.html`。

#### 优缺点

- ✅ 0 额外抽象层,所有进程 `pgrep -af` 一眼看到,新手最容易理解
- ✅ 性能最优,chromium 直接吃所有 CPU / 内存(虽然本项目禁用了 GPU)
- ✅ 调试最直接:chromium 崩了直接看 `/var/log/vnc-research/chromium.log`,不用 `docker logs`
- ✅ 改配置最快:vim 改 `start-all.sh` 立刻生效,不用 rebuild 镜像
- ✅ 不需要懂 Docker / systemd,门槛最低
- ❌ 跟宿主机包管理器耦合,`apt upgrade` 可能把 chromium 升到不兼容版本
- ❌ 没法在 macOS / Windows 上跑(Windows 要 WSL,体验差)
- ❌ 服务器重启后**不会自动起**,得 SSH 进去手动跑脚本
- ❌ 多用户共享一台机器时,端口冲突 / profile 串号要手动协调
- ❌ 卸载残留多:deb 包、Python pip 包、`~/.config/chromium/`、`/var/log/vnc-research/` 都要分别清理

#### 典型场景

- 本地开发机想试一下 vnc-research 能不能跑通
- 临时给一台测试 VPS 装一下,跑完就销毁
- 教学场景:讲解 Xvfb / x11vnc / noVNC / chromium 四件套如何串联
- 只想用一两次,懒得写 Dockerfile / unit 文件

#### 相关参考

- [docs/00-快速开始.md](00-快速开始.md) · 5 分钟跑起来
- [docs/02-部署指南.md · 方案 A](02-部署指南.md#方案-a快速测试5-分钟)
- [scripts/start-all.sh](../scripts/start-all.sh) · 一键启动脚本

---

### 方式二 · Docker

**做法**:写一个 `Dockerfile`(基于 `debian:13-slim`,装包 + 复制脚本 + 设 entrypoint),`docker build` 出镜像,然后 `docker run -d -p 6080:6080 -p 9222:9222 ...` 起容器。

#### 优缺点

- ✅ 一次构建到处跑:本地 build 的镜像可以推到 registry,在 CI / 生产 / 同事机器上行为完全一致
- ✅ 隔离最强:chromium 跑飞了不会污染宿主机文件系统,清掉容器一切归零
- ✅ 卸载最干净:`docker rm -f` + `docker image rm` 完事,主机零残留
- ✅ 跨主机迁移简单:`docker save` / `docker load`,或者推 registry pull
- ✅ 适合 CI:流水线拉镜像 → 起容器跑测试 → 销毁,完全可复现
- ❌ 启动门槛高:要先装 Docker 引擎 + 理解 volume 挂载 + 处理 X11 socket 转发(`/tmp/.X11-unix` 要 `-v` 进去或者用 `$DISPLAY` 环境变量)
- ❌ 调试链路长:chromium 崩了要 `docker exec -it vnc-research bash` 进容器看日志,新人不熟 Docker 会懵
- ❌ 网络模式坑多:容器默认网络可能跟宿主机的 iptables / ufw 规则冲突,`-p` 端口映射的语义跟裸机监听不一样
- ❌ 镜像体积不小:`debian:13-slim` + chromium + x11vnc 等依赖,几百 MB 起,CI 拉镜像慢
- ❌ X11 转发在容器里有时会有奇怪的权限问题(虽然 `--no-sandbox` 能绕一部分)

#### 典型场景

- CI 流水线里跑端到端测试,需要可复现的 chromium 环境
- 在一台服务器上跑多个隔离实例(每个用户一个容器,不同端口)
- 想把整套环境打包给团队成员,他们 `docker run` 就能用,不用各自装包
- 频繁换机器 / 换云厂商,镜像 push 上去哪里都能 pull

#### 相关参考

- [docs/02-部署指南.md · 方案 C](02-部署指南.md#方案-cdocker-部署隔离干净)
- [docs/01-架构详解.md](01-架构详解.md) · 理解四件套的数据流

---

### 方式三 · systemd 服务化

**做法**:把 `start-all.sh` 拆成 4 份 `.service` 文件(`xvfb.service` / `x11vnc.service` / `novnc.service` / `vnc-chromium.service`),用 `After=` 控制启动顺序,用 `Restart=on-failure` 实现进程守护,`systemctl enable` 实现开机自启。

#### 优缺点

- ✅ **开机自启**:服务器重启后整套架构自动拉起,不用 SSH 进去手动跑脚本
- ✅ **进程守护**:chromium 崩了 5 秒后自动重启(`RestartSec=5`),X 挂了 systemd 也会拉起
- ✅ **日志统一收**:`journalctl -u vnc-chromium -f` 看实时日志,带时间戳和优先级,不用自己造轮子
- ✅ **资源控制**:可以在 unit 里加 `MemoryMax=2G` / `CPUQuota=80%`,防止 chromium 吃光资源
- ✅ **依赖管理**:`After=xvfb.service` 保证 Xvfb 起来再启 x11vnc,启动顺序明确
- ❌ **配置量大**:要写 4 份 service 文件(虽然可以复制粘贴改),比 `start-all.sh` 一个脚本复杂
- ❌ **单元调试绕**:进程崩了 systemd 自动拉起,你想看崩溃现场得 `systemctl edit` 加 `Restart=no` 临时关掉
- ❌ **环境变量坑**:unit 里 `Environment=DISPLAY=:99` 跟 shell 里的不太一样,`$HOME` 之类的变量在 unit 里要写绝对路径
- ❌ **仅 Linux**:macOS 用 launchd,Windows 用 SCM,跨平台要重写
- ❌ **隔离性弱**:进程直接跑在宿主机,跟系统其他服务共享文件系统,cgroup 隔离是唯一屏障

#### 典型场景

- 生产环境长期运行,要崩了自动拉起
- 服务器经常重启(发布 / 维护 / 弹性扩缩容)
- 想要结构化日志(方便接 ELK / Loki / 监控告警)
- 需要限制资源(`MemoryMax` / `CPUQuota`),防止 chromium 拖垮整台机器
- 想要标准化的服务管理方式(跟系统其他 systemd 服务一致)

#### 相关参考

- [docs/02-部署指南.md · 方案 B](02-部署指南.md#方案-b生产部署systemd-服务化)
- [docs/04-踩坑记录.md · 坑 10](04-踩坑记录.md#坑-10重启服务器后整套架构没自动起) · 重启服务器后整套架构没自动起的解法

---

## 选择建议(条件分支,不替读者做决定)

> 下面只给场景匹配的指引,具体选哪个还是看你自己。

- **如果你只是想试一下能不能跑通 / 学原理 / 用一两次** → 方式一本机直装最省事,5 分钟看到画面
- **如果你的服务器经常重启 / 要长期稳定跑 / 要崩了自动拉起** → 方式三 systemd,生产标配
- **如果你要在 CI 里跑 / 要批量铺到多台机器 / 想跟宿主机完全隔离** → 方式二 Docker,镜像一次构建到处跑
- **如果你的开发机是 macOS / 想给团队成员分发** → 方式二 Docker(macOS 装 Xvfb 折腾,Windows 更别说)
- **如果你想加资源限制(`MemoryMax` / `CPUQuota`)** → 方式三 systemd 最直接
- **如果你想随时 `docker rm` 就干净卸载,不留残留** → 方式二 Docker
- **如果你不想学新东西,只想 vim 改配置立刻生效** → 方式一本机直装

> 方式之间**不是互斥的**:开发时用方式一测,部署时用方式三跑,CI 用方式二铺。三种可以共存,挑最贴你当前场景的就行。