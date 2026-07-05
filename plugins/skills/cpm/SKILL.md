---
name: cpm
description: commit + push 当前改动，默认允许直推 protected base（main / master / dev / test）。等价于 cp --am。代码改完、sanity check 过了、用户说"提交并推送到主干 / cpm"时用。
---

# cpm — commit & push（默认 allow-main）

> 运行环境入口约定：本仓库的 `.claude/skills` 以 Claude Code 为源，示例默认写 `/tunan:*`。若同一 skill 在 Codex 中运行，所有面向 sponsor 的可复制入口在输出前改写为 `$tunan:*`；Claude Code 中保持 `/tunan:*`。

> **何时触发**：用户说 "cpm" / "/tunan:cpm" / "提交并推送到主干" / "直接推 main"。

## 与 cp 的关系

`cpm` 的行为与 `cp` skill **完全一致**，唯一区别：**`--allow-main`（别名 `--am`）默认开启**。即：在 `main` / `master` / `dev` / `test` 等 protected base 上也直接 push，不再触发"当前分支是 protected base"的阻塞式提问。

执行时：**加载并遵循 `cp` skill 的完整流程**（调用语法、commit message 起草、敏感文件跳过、push、§自动同步重试、失败处理、不要做、输出格式），只把以下一处默认值翻转：

- 在 cp 流程第 5 步的分支硬检查里，视作**已带 `--am`**。无需就 protected base 发起 `AskUserQuestion` / `request_user_input` / `ask_user`，直接 `git push -u origin <BRANCH>`。

其余开关、红线、自动同步重试逻辑一律继承 cp，不在此重复。

## 调用语法

```
/tunan:cpm [开关] [-- <commit message>]
```

开关与 `cp` 相同（`--no-push` / `--files=<glob,...>` / `--message=<text>` / `-- <text>`），但 `--am` 已默认开启，无需再传。若要**关闭**默认的 allow-main、恢复 cp 的 protected-base 确认行为，显式传 `--no-am`（此时退化为标准 `cp`）。

**示例**：

```
/tunan:cpm                              # 自动起 message → commit + push（即便在 main 上也直推）
/tunan:cpm -- 修复登录 token 过期未刷新   # 显式 message，直推当前分支
/tunan:cpm --no-am                      # 关闭默认 allow-main，等价于标准 /tunan:cp
```

## 红线

继承 cp 的全部红线：**不 force push、不 `--amend`、不 `--no-verify`、不 `git add -A` / `.`、不顺手做清理提交**。`--am` 仅放开"推到 protected base"这一项，不放开任何危险开关。
