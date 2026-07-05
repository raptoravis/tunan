---
name: worktree
description: Create an isolated git worktree for parallel feature work or PR review. Use when starting work that should not disturb the current checkout, or when `work` or `code-review` offers a worktree option.
allowed-tools: Bash(bash *worktree-manager.sh), Bash(powershell.exe *worktree-manager.ps1)
---

# Worktree Isolation

Ensure the current work happens in an isolated workspace, without disturbing the user's main checkout. Most coding harnesses now create a worktree by default at session start, so the common case is that **isolation already exists** — detect that first and do not create a redundant one.

Order of operations: **detect existing isolation -> prefer a native worktree tool -> fall back to the worktree-manager script.** Never create a worktree the harness cannot see.

**Two modes, set by the caller's need:**

- **New work (default).** No specific ref named — create a fresh branch from a base (trunk). This is what `work` uses.
- **Isolate an existing ref.** The caller names a ref to work on in isolation — a PR head, an existing branch, or a commit. Attach the worktree to that ref instead of creating a new branch. One hard git rule governs this mode: **a branch can be checked out in only one worktree at a time.** If the named ref is already checked out somewhere (most commonly because it is the current branch in the primary checkout), do **not** create a second worktree for it — report that it is already checked out at `<path>` and let the caller act (work there in place; or, only if a clean separate tree is essential, create a *detached* worktree at the same commit). Never put one branch in two worktrees.

The steps below (detect -> native tool -> script fallback) apply to both modes; the mode only changes what gets checked out and is reported back to the caller.

## Step 0: Detect existing isolation

Before creating anything, check whether the current directory is already a linked worktree. Compare the **resolved absolute** git dir against the **resolved absolute** common git dir — resolve each to an absolute path first and compare those, not the raw `git rev-parse` output:

```bash
git rev-parse --absolute-git-dir                     # absolute git dir for this worktree
(cd "$(git rev-parse --git-common-dir)" && pwd -P)   # absolute shared (common) git dir
```

If the two absolute paths are **equal**, this is a normal checkout — continue to Step 1.

If they **differ**, you are in a linked worktree *or* a submodule. Distinguish them:

```bash
git rev-parse --show-superproject-working-tree
```

- **Non-empty** output -> you are in a submodule; treat it as a normal checkout and continue to Step 1.
- **Empty** output -> you are **already in an isolated worktree**. Report the worktree path (`git rev-parse --show-toplevel`) and current branch. Do not create another worktree — a worktree-from-worktree lands in the wrong tree and is invisible to the harness that made the current one. Then **work in place**: in new-work mode, continue here; in isolate-an-existing-ref mode, check that ref out here (unless it is already the current branch) rather than nesting a worktree.

## Step 1: Prefer the harness's native worktree tool

If the harness provides a native worktree primitive — for example an `EnterWorktree` / `WorktreeCreate` tool, a `/worktree` command, or a `--worktree` flag — use it and stop. Native tools place, track, and clean up the worktree so the harness can manage it. A behind-the-back `git worktree add` creates phantom state the harness cannot see, navigate to, or clean up.

## Step 2: Script fallback

### Creating a worktree

Invoke the bundled script via the runtime Bash tool, picking the variant for the current OS — PowerShell (`.ps1`) on Windows, bash (`.sh`) on macOS/Linux. On Claude Code, `${CLAUDE_SKILL_DIR}` resolves to the skill's own directory across both marketplace-cached installs and `claude --plugin-dir` local development; the runtime Bash tool's CWD is the user's project, not the skill directory, so a bare relative path fails. On other targets (Codex, Gemini, Pi, etc.) `${CLAUDE_SKILL_DIR}` is unset and the `:-.` fallback yields the bare relative path those harnesses expect. The Bash tool (Git Bash on Windows) expands `${CLAUDE_SKILL_DIR:-.}` and forward slashes, which `powershell.exe -File` accepts.

Windows (PowerShell):
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR:-.}/scripts/worktree-manager.ps1" create <branch-name> [from-branch]
```

macOS / Linux (bash):
```bash
bash "${CLAUDE_SKILL_DIR:-.}/scripts/worktree-manager.sh" create <branch-name> [from-branch]
```

Defaults:
- `from-branch` defaults to origin's default branch (or `main` if that cannot be resolved)
- The new branch is created at `origin/<from-branch>` (or the local ref if the remote is unavailable)

Examples (bash form shown; on Windows swap to the PowerShell variant above):
```bash
bash "${CLAUDE_SKILL_DIR:-.}/scripts/worktree-manager.sh" create feat/login
bash "${CLAUDE_SKILL_DIR:-.}/scripts/worktree-manager.sh" create fix/email-validation develop
```

After creation, switch to the worktree with `cd .worktrees/<branch-name>`.

## Other worktree operations

Use `git` directly — no wrapper is needed and none is provided:

```bash
git worktree list                          # list worktrees
git worktree remove .worktrees/<branch>    # remove a worktree
cd .worktrees/<branch>                     # switch to a worktree
cd "$(git rev-parse --show-toplevel)"      # return to main checkout
```

To copy `.env*` files into an existing worktree created without them, run this from the main repo (not from inside the worktree, since branch names often contain slashes like `feat/login`):
```bash
cp .env* .worktrees/<branch>/
```

## Dev tool trust behavior

When mise or direnv configs are present, the script attempts to trust them so hooks and scripts do not block on interactive prompts. Trust is baseline-checked against a reference branch:

- **Trusted base branches** (`main`, `develop`, `dev`, `trunk`, `staging`, `release/*`): the new worktree's configs are compared against that branch; unchanged configs are auto-trusted. `direnv allow` is permitted.
- **Other branches** (feature branches, PR review branches): configs are compared against the default branch; `direnv allow` is skipped regardless, because `.envrc` can source files that direnv does not validate.

Modified configs are never auto-trusted. The script prints the manual trust command to run after review.

## When to create a worktree

Create a worktree when:
- Reviewing a PR while keeping the main checkout free for other work
- Running multiple features in parallel without branch-switching overhead
- Keeping the default branch free of in-progress state

Do not create a worktree for single-task work that can happen on a branch in the main checkout.

## Integration

`work` and `code-review` offer this skill as an option. When the user selects "worktree" in those flows, invoke the worktree-manager `create <branch>` command (the PowerShell `.ps1` variant on Windows, the bash `.sh` variant elsewhere — see "Creating a worktree" above) with a meaningful branch name derived from the work description (e.g., `feat/crowd-sniff`, `fix/email-validation`). Avoid auto-generated names like `worktree-jolly-beaming-raven` that obscure the work.

## Troubleshooting

**"Worktree already exists"**: the path is already in use. Either switch to it (`cd .worktrees/<branch>`) or remove it (`git worktree remove .worktrees/<branch>`) before recreating.

**"Cannot remove worktree: it is the current worktree"**: `cd` out of the worktree first, then `git worktree remove`.

**Dev tool trust was skipped**: the script prints the manual command. Review the config diff (`git diff <base-ref> -- .envrc`), then run the printed command from the worktree directory.
