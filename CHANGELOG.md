# Changelog

All notable changes to vnc-research will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- 加 CONTRIBUTING.md(贡献指南)
- 加 ROADMAP.md(路线图)
- 加 GitLab CI(Markdown lint / shellcheck)

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
