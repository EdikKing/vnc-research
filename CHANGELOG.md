# Changelog

All notable changes to vnc-research will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- 加 CONTRIBUTING.md(贡献指南)
- 加 ROADMAP.md(路线图)
- 加 GitLab CI(Markdown lint / shellcheck)

## [0.2.0] - 2026-06-27

### Added
- `docs/deployment-comparison.md`:三种部署方式横向对比(本机直装 / Docker / systemd),8 维度对比表 + 优缺点 + 条件分支选择建议
- `docs/deployment-comparison.md`:新增"## 推荐"章节(明确推荐方式一本机直装)
- `docs/06-外网访问.md`:ngrok HTTP/TCP 隧道 + 双层鉴权(VNC 密码 + basic-auth)+ Docker 配置示例 + 安全 checklist + 故障排查
- `scripts/start-all.sh`:VNC 密码机制(默认自动生成 8 位数字,env 可覆盖,替代 `-nopw`)
- `scripts/start-ngrok.sh`:ngrok 一键启动脚本(free anonymous 默认 + basic-auth / TCP / region 可选)

### Changed
- `README.md`:章节数描述从"6 篇教程"更新为"7 篇教程 + 1 篇部署方式对比"
- `README.md` / `docs/01-架构详解.md`:URL 引用统一改为 GitHub(`git@github.com:EdikKing/vnc-research.git`),策略 A
- `docs/01-架构详解.md`:架构图里 10.1.1.52 → `<你的服务器IP>` 占位符(私人内网 IP 不进开源文档)

[0.2.0]: https://github.com/EdikKing/vnc-research/releases/tag/v0.2.0

## [0.1.0] - 2026-06-27

### Added
- 首次发布 vnc-research 远程桌面+AI Agent 调研框架
- README 框架总览 + 快速使用入口
- 6 篇教程文档(快速开始 / 架构详解 / 部署指南 / 使用指南 / 踩坑记录 / 安全考量)
- `skills/SKILL.md` 完整协议(🔴 操作员介入协议)
- 4 个脚本:`start-all.sh` / `stop-all.sh` / `health-check.sh` / `playwright-connect.py`
- 2 个实战案例:小红书搜索 + use-cases
- 把文档中的 "Edik" 人称代词抽象为 "操作员/Operator"(可分发给任何人)
- .gitignore 清理(仅保留 OS/editor 临时文件 + secrets/runtime)

### Notes
- 已知限制:不适合 macOS / Windows(以 Linux 为主);一台服务器 = 一个人用
- 不解决 datacenter IP 拦截问题

[Unreleased]: https://github.com/EdikKing/vnc-research/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/EdikKing/vnc-research/releases/tag/v0.1.0
