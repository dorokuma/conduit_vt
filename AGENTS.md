# Agent Collaboration Guide
档位：L1

Flutter/Dart 终端模拟器库（fork 自 xterm.dart，仅供 Conduit / Conduit-feat 作为 git 依赖引用）。

## 铁律
1. **测试与静态检查**：统一入口 `make check`（内部调用 `flutter analyze` 与 `flutter test`，无 Flutter SDK 主机显式非零退出、由 CI/开发机执行）；`flutter pub get` 安装依赖；`dart format` 仅约束本次改动涉及的文件（存量差异另记笔记），不得因存量全仓格式化差异阻塞；若 shell 找不到 `flutter` 命令，先 `export PATH=/opt/flutter/bin:$PATH`。
2. **提交规范**：提交规范、门禁与合并推送按 /root/.pig/agent/SYSTEM.md §4 执行。
3. **决策留痕**：关键技术决策、架构变更或踩坑须记于 `.agents/notes/`（按 `YYYYMMDD-slug.md` 命名，满足任一触发即写）；`.agents/notes/` 按既有白名单入库（`INDEX.md` 本机留存不入 git）。
4. **上游分歧保护**：与上游的故意分歧登记于 fork-delta.md，禁止未经指示向上游对齐。

## 索引
- 现状与说明文档：[README.md](README.md)
- 决策与踩坑笔记：[.agents/notes/](.agents/notes/README.md) | 上游分歧：[fork-delta.md](.agents/notes/fork-delta.md)
- 写完笔记刷新索引：`scripts/notes-index.sh`（本地生成 INDEX.md，不入 git）

## 关联仓库
- `Conduit`：主消费端
- `Conduit-feat`：特性消费端

## Release Policy / 发布规范

本节是本仓库发版的强制规则。仓库已有的更具体版本、构建或发布渠道规则优先，但不得降低以下底线。

1. **版本与变更记录**：遵循 Semantic Versioning，正式版本使用 `vX.Y.Z`。破坏性变更升 MAJOR，新功能升 MINOR，兼容修复升 PATCH。任何用户可见行为、运行时/API/包接口、依赖、安全性或分发产物变化，都必须在同一发版提交中更新版本元数据并写入 CHANGELOG/Release Notes；纯文档且不产生可分发产物时可免升版，但须在规则或 Release Notes 中明确说明。
2. **发布门禁**：发版前工作树必须干净，版本号、CHANGELOG 与发布说明必须一致；必须运行仓库规定的测试、构建、lint、类型检查及必要的安全检查，且全部通过。若仓库提供 `release-check`、`make release-check`、版本检查脚本或同等门禁，必须原样通过，不得绕过。
3. **发布顺序**：先提交并推送发布提交到目标分支 → 在该发布提交上创建 Tag（默认使用带注解的 `git tag -a vX.Y.Z -m "vX.Y.Z"`；仅当现有发布工具明确要求轻量 Tag 时可例外）→ 推送 Tag → 创建**非草稿** GitHub Release → 再发布 npm、PyPI、容器镜像等关联分发渠道。不得只推分支或只打 Tag 就宣称发版完成。
4. **GitHub Release 产物**：标题使用 `vX.Y.Z`，正文必须包含实质性变更摘要、升级/破坏性变更说明及验证结果；二进制、安装包、插件包等适用产物必须作为 Release assets 上传，并提供校验和（如适用）。**Tag 本身不等于完整发版，必须同时存在可访问的 GitHub Release。**
5. **发布后验收**：至少执行并确认 `git ls-remote --tags origin refs/tags/vX.Y.Z`、Tag 指向发布提交、`gh release view vX.Y.Z` 可访问且不是 draft；若发布到包仓库/镜像仓库，还必须核验对应版本、摘要或安装链接可用。
6. **不可变性**：已发布 Tag 不得复用、移动或删除，不得 force push 发布分支或 Tag，不得从未提交、未经测试或未通过门禁的树发布。发布后发现问题须通过新的 patch 版本修复，禁止覆盖历史 Release。
7. **例外必须显式化**：归档、已停用、被替代、仅文档或无可分发产物的仓库，必须在项目规则中明确写出“不发新版本”及历史 Tag/Release 的处置方式；例外不能用于绕过上述发布闭环。

### Repository-specific release contract

- 本仓作为 Git 依赖库发布；版本 Tag 必须与依赖清单/包元数据一致，并在 GitHub Release 附可复现的构建或校验信息。
