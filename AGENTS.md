# Agent Collaboration Guide

Flutter/Dart 终端模拟器库（fork 自 xterm.dart，仅供 Conduit / Conduit-feat 作为 git 依赖引用）。

## 铁律
1. **测试与静态检查**：`flutter pub get` 安装依赖；`flutter test` 运行测试；`flutter analyze` 静态分析；`dart format` 仅约束本次改动涉及的文件（存量差异另记笔记），不得因存量全仓格式化差异阻塞；若 shell 找不到 `flutter` 命令，先 `export PATH=/opt/flutter/bin:$PATH`。
2. **提交规范**：提交规范——commit message 须过全局 commit-msg hook：Conventional Commits 类型白名单、≤72 字、冒号后一空格、禁噪声词与密钥。
3. **决策留痕**：关键技术决策、架构变更或踩坑须记于 `.agents/notes/`（按 `YYYYMMDD-slug.md` 命名，满足任一触发即写）。
4. **上游分歧保护**：与上游的故意分歧登记于 fork-delta.md，禁止未经指示向上游对齐。

## 索引
- 现状与说明文档：[README.md](README.md)
- 决策与踩坑笔记：[.agents/notes/](.agents/notes/README.md) | 上游分歧：[fork-delta.md](.agents/notes/fork-delta.md)
- 写完笔记刷新索引：`scripts/notes-index.sh`（本地生成 INDEX.md，不入 git）

## 关联仓库
- `Conduit`：主消费端
- `Conduit-feat`：特性消费端
