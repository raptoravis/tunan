---
name: align
description: "AI-initiated alignment protocol that minimizes the sponsor's cognitive load. When any yunxing skill reaches a decision point, the agent raises the question with at least 3 ranked recommendations and pre-selects the best one as the default, so the sponsor accepts the optimal choice with a single tap or one 'accept all'. Use whenever a yunxing skill needs the sponsor to choose between options -- never hand an open-ended question back to the sponsor. Triggers -- /yunxing:align, or indirect invocation from any other yunxing skill at a decision point."
---

# align — AI-initiated alignment with pre-selected defaults

The sponsor decides better by selecting than by composing. The agent does the thinking — frames the question, enumerates the realistic options, ranks them, and pre-selects the best — so the sponsor only has to confirm. Every yunxing skill routes its decision points through this single protocol instead of inventing its own way to ask.

## When this runs

- **Direct**: the sponsor types `/yunxing:align <topic>`.
- **Indirect (primary)**: any other yunxing skill hits a decision point, builds the question per this protocol, collects the sponsor's choice, then returns to its own flow.

## Core rule

The agent never hands an open-ended question back to the sponsor. Every decision point becomes: a one-line question plus **at least 3 ranked recommendations**, with the single best one pre-selected as the default. "Up to you" / "either works" / "what do you prefer" are forbidden — surfacing options without a recommendation defeats the purpose.

## Interaction Method

Default to the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to a numbered list in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.

## Building each question

- State the question in one line.
- **用中文呈现**对齐内容——问题文本、选项 label、tradeoff 描述都用中文;代码、命令、文件名、标识符、API/库名保持原文不译。仅当 sponsor 全程使用英文交流时,才改用英文提问。
- Offer **at least 3** candidate options, ranked best-first. The platform option cap is 4 (`AskUserQuestion`), so the practical range is 3–4 candidates.
- **Pre-select the best**: place it first and append `(推荐)` to its label (use `(Recommended)` when asking in English). This is what lets the sponsor take the default and land on the optimal choice.
- The platform's free-form / "Other" choice is always available to the sponsor — do not spend a candidate slot re-creating it.
- Each option label is self-contained: some harnesses render only the label, not the description, so the label alone must convey the choice. Put the one-line tradeoff (edge / risk / fit) in the description.
- The Recommended option must stand alone: taking it blindly via "accept all" must be a safe, sensible outcome on its own.
- Refer to the agent in the third person in labels and stems; phrase each label from the sponsor's intent, not internal mode names.
- Batch at most 4 questions at once. If more decisions are pending, split into batches ordered by downstream impact — ask the highest-impact batch first, then the next after it is answered.

## Picking the default

- The default is the lowest-risk / most-common / best-fit option — not the flashiest or the one that took the most effort to design.
- If the best option is genuinely ambiguous, still pick one and say why in its description. Never default to the riskiest option while phrasing it to look safe.

## Sponsor responses to support

| Sponsor input | Interpretation |
|---|---|
| Picks one option per question | Apply those; everything else takes its default |
| `accept all` / `全部默认` / `默认` | Apply the Recommended default for every open question (see below) |
| Free-form text on a question | Treat as a custom answer to that question |
| Silence / no response | Keep waiting. Do **not** apply defaults or claim they were applied |

Surfacing a Recommended option and the sponsor accepting it are two different states. Do not write artifacts or report "default applied" until the sponsor actually responds — silence means keep waiting, not consent.

## `accept all` is session state

Once the sponsor says `accept all` (or equivalent), every later alignment point automatically takes its Recommended default until the flow ends or the sponsor revokes it. Announce once when the state activates and once when it ends.

## Autonomous / headless runs

In autonomous or non-interactive flows (e.g., `/lfg`, or any headless invocation), do not block: auto-take the Recommended default at each alignment point, record the source as `autonomous-default`, and continue. This covers only these option-level defaults — it does **not** pre-authorize irreversible actions (destructive operations, force pushes, publishing). Those always need explicit sponsor sign-off regardless of `accept all` or autonomous mode.

## Recording decisions

When the host skill produces an artifact, write each resolved decision into its Decisions / Open Questions table with a Source column so a later reader can tell how it was decided:

```
| Q  | Question        | Decision | Source            |
| Q1 | Priority?       | P2       | accept all        |
| Q2 | Include retries | Yes      | explicit          |
```

`Source` values: `explicit` / `accept all` / `free-form` / `autonomous-default`.

## When NOT to align

- Pure information display where no sponsor decision is needed.
- More than 4 realistic candidates: converge to the top 3–4 first; do not list 5+ and dilute the default.
- A fully open question with no enumerable candidates: first decompose it into concrete candidates, then run alignment on those.

## Anti-patterns (self-check)

- Padding to 3 with filler options nobody would pick.
- Marking the riskiest option as the Recommended default.
- "Up to you" / "either works" — pushing the decision back to the sponsor.
- Re-asking a point already decided — read the upstream Decisions table first.
- Stacking 5+ questions into one batch instead of splitting into batches of 4.
- In Claude Code, dumping a markdown table instead of calling `AskUserQuestion`.
- Claiming "default applied" or writing an artifact before the sponsor has responded.

## Example / 示例

> **Q1 — 限流器应该放在哪一层?**
>
> - `边缘中间件(推荐)` — 单一入口收口,无需改动各路由;会多一跳开销
> - `各服务拦截器` — 控制更细;需在每个服务里接线
> - `API 网关配置` — 零代码;只能用网关粗粒度的限流桶
>
> **Q2 — 限流窗口粒度?**
>
> - `按分钟(推荐)` — 匹配常见滥用模式;易于推理
> - `按秒` — 能挡突发,记账开销更大
> - `按小时` — 对滥用太粗,做配额还行

## Returning

When invoked by another skill: write the resolved decisions back, then return to the calling skill to continue — do not emit a "next steps" section here. When invoked directly via `/yunxing:align`, give a brief confirmation of what was recorded and one suggested next step.
