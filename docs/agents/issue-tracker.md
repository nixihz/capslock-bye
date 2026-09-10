# Issue tracker: GitHub

本仓库的问题与规格存放在 `nixihz/capslock-bye` 的 GitHub Issues，使用 `gh` CLI 操作。

仓库地址：https://github.com/nixihz/capslock-bye

## 仓库定位

当前本地未配置 Git remote；上述目标来自 README.md 与 CONTRIBUTING.md。命令显式使用 `--repo nixihz/capslock-bye`，避免依赖当前目录自动推断仓库；`gh api` 使用完整的 `repos/nixihz/capslock-bye/...` 路径。

远程仓库尚未确认可访问。如果 `gh` 无法解析仓库，报告实际错误，不要自动创建仓库或改用另一个 tracker。

## 常用操作

- 创建：`gh issue create --repo nixihz/capslock-bye --title "标题" --body-file /path/to/body.md`。
- 读取：`gh issue view <number> --repo nixihz/capslock-bye --json number,title,body,labels,comments`。
- 列表：`gh issue list --repo nixihz/capslock-bye --state open --json number,title,body,labels,comments`，按需要添加 `--label` 或调整 `--state`。
- 评论：`gh issue comment <number> --repo nixihz/capslock-bye --body-file /path/to/comment.md`。
- 添加或移除标签：`gh issue edit <number> --repo nixihz/capslock-bye --add-label "标签"` 或 `--remove-label "标签"`。
- 关闭：`gh issue close <number> --repo nixihz/capslock-bye`；需要说明时先发布评论。

多行正文先原样写入临时 Markdown 文件，再使用 `--body-file`，保留真实换行。标签角色映射见 `triage-labels.md`。

## Pull requests as a triage surface

**PRs as a request surface: no.**

仅在此标记改为 `yes` 后，外部 PR 才进入同一 triage 流程。届时使用 `gh pr view`、`gh pr diff`、`gh pr list`、`gh pr comment`、`gh pr edit` 和 `gh pr close`，均显式指定仓库。评论正文使用 `--body-file`。外部作者包括 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR` 和 `NONE`；排除 `OWNER`、`MEMBER` 和 `COLLABORATOR`。

GitHub Issues 与 PR 共用编号空间。收到裸编号时，先尝试 `gh pr view <number> --repo nixihz/capslock-bye`，再回退到 `gh issue view`；认证或网络错误不代表它一定是 Issue。

## 技能操作的含义

- “publish to the issue tracker”：创建 GitHub Issue。
- “fetch the relevant ticket”：运行 `gh issue view <number> --repo nixihz/capslock-bye --comments`，同时读取标签。

## Wayfinding operations

- **Map**：一个带 `wayfinder:map` 标签的 Issue，正文包含 Notes、Decisions-so-far、Fog。
- **Child ticket**：通过 GitHub sub-issues API 关联到 Map 的子 Issue，使用 `wayfinder:<type>` 标签，类型为 `research`、`prototype`、`grilling` 或 `task`。若 sub-issues 不可用，在 Map 正文维护任务列表，并在子 Issue 顶部写 `Part of #<map>`。
- **Blocking**：优先使用 GitHub 原生 Issue dependencies。运行 `gh api --method POST repos/nixihz/capslock-bye/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`；数据库 ID 通过 `gh api repos/nixihz/capslock-bye/issues/<number> --jq .id` 获取，不使用 Issue 编号或 node_id。`issue_dependencies_summary.blocked_by` 表示未关闭的阻塞项数量。若 dependencies 不可用，改在正文顶部记录 `Blocked by: #<number>, #<number>`；所有阻塞项关闭后才可开始。
- **Frontier**：按 Map 中顺序选择第一个未关闭、无未解决阻塞项且无人认领的子 Issue。
- **Claim**：开始工作前运行 `gh issue edit <number> --repo nixihz/capslock-bye --add-assignee @me`，完成认领后再开展工作。
- **Resolve**：先通过评论记录答案，再关闭子 Issue，最后把结论摘要和链接追加到 Map 的 Decisions-so-far。
