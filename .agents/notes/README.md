# 决策与踩坑笔记（Architecture & Decision Records）

本目录用于记录项目生命周期中的关键技术决策、踩坑教训以及与上游的故意分歧。

## 触发条件（满足任一即写）

1. **对外契约变动**：SQLite schema、索引格式、配置格式、对外 API / 协议契约变更。
2. **跨模块/跨仓库影响**：改动跨两个以上模块，或影响下游消费方（Conduit / Conduit-feat）。
3. **否决看似更优方案**：放弃了表面上更直接/直觉更优但存在隐患的方案。
4. **临时降级/workaround/特判**：因依赖缺陷、平台兼容性等引入的临时逻辑或特判。
5. **与 upstream 的故意分歧**：针对移动端/Mosh 场景对 xterm.dart 的定制改动（须同步在 [fork-delta.md](fork-delta.md) 登记）。
6. **关键性能取值**：缓冲大小、节流阈值、缓存策略等性能参数选型原因。

## 豁免清单

以下情况可豁免记录（**注意：触发优先于豁免，单文件 workaround 仍必须记录**）：
- 版本号 bump
- 纯文案/注释修正
- 行为不变的单文件 bug 修复
- 小版本依赖升级
- 纯补测试用例

## 规范与流程

1. **命名规范**：`YYYYMMDD-slug.md`（例如：`20260917-mosh-predictive-echo.md`）。
2. **模板规范**：参考 [_template.md](_template.md) 结构起草。
3. **不可篡改性**：旧笔记废弃时不改写原文，通过 frontmatter 中的 `status: superseded` 与 `superseded_by` 字段建立链向新笔记的链接。
4. **索引更新**：写完笔记后运行 `scripts/notes-index.sh` 生成或刷新本地 `INDEX.md`（不纳入 git 跟踪）。
