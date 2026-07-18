---
name: batch-grill-me
description: "A relentless interview that asks every frontier question at once, round by round — map decisions as a design tree and work the frontier in batches. Use when the user wants to stress-test thinking efficiently, says 'batch grill me', 'grill me in batches', or wants structured decision-tree exploration without one-at-a-time pacing."
---

# Batch Grill Me

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled — the questions you can ask *now* without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Each round the user answers reshapes the tree — settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a *later* round, not this one.

Finding *facts* is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it — don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report — ask the rest of the frontier now. The *decisions* are the user's — put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

## Interaction Method

Present each round's frontier as a single message with numbered questions and recommended answers. Use the platform's blocking question tool for alignment checkpoints (end-of-round confirmation, "frontier empty?"): `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini/Pi/Cursor. Fall back to numbered options in chat only when no blocking tool exists or the call errors.

## Relationship to Other Skills

- `` `grill-me` `` — the one-at-a-time interview. Use when the user wants deeper, sequential questioning instead of batch rounds.
- `` `brainstorm` `` — exploratory requirements discussion before decisions are on the table. Batch-grill-me starts when there's already something to stress-test.
