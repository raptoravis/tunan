---
name: dispatching-parallel-agents
description: 'Dispatch one subagent per independent problem domain for parallel investigation or implementation. Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies -- multiple test files failing with different root causes, independent subsystems broken simultaneously, or any work where each problem can be understood without context from the others.'
---

# Dispatching Parallel Agents

Delegate tasks to specialized subagents with isolated context. By precisely crafting their instructions, you ensure they stay focused and succeed at their task. They should never inherit your session's context or history — construct exactly what they need. This also preserves your own context for coordination work.

**Core principle:** Dispatch one agent per independent problem domain. Let them work concurrently.

## When to Use

**Use when:**
- 3+ test files failing with different root causes
- Multiple subsystems broken independently
- Each problem can be understood without context from others
- No shared state between investigations
- Implementation plan has units that pass the Parallel Safety Check (see `work`)

See [When NOT to Use](#when-not-to-use) below for counter-conditions.

## Decision Flow

```
Multiple failures? → Are they independent?
  ├─ No (related) → Single agent investigates all
  └─ Yes → Can they work in parallel?
           ├─ No (shared state) → Sequential agents
           └─ Yes → Parallel dispatch
```

## The Pattern

### 1. Identify Independent Domains

Group failures by what's broken:
- File A tests: Tool approval flow
- File B tests: Batch completion behavior
- File C tests: Abort functionality

Each domain is independent — fixing tool approval doesn't affect abort tests.

### 2. Create Focused Agent Tasks

Each agent gets:
- **Specific scope:** One test file or subsystem
- **Clear goal:** Make these tests pass, or implement this unit
- **Constraints:** Don't change other code
- **Expected output:** Summary of what was found and fixed

### 3. Dispatch in Parallel

Issue all subagent dispatches in the same response — they run concurrently. Use the platform's subagent primitive (`Agent` in Claude Code with `run_in_background: true`, `spawn_agent` in Codex, `subagent` in Pi). Multiple dispatch calls in one response = parallel execution. One per response = sequential.

### 4. Review and Integrate

When agents return:
- Read each summary
- Verify fixes don't conflict (check for overlapping files)
- Run full test suite
- Integrate all changes

## Agent Prompt Structure

Good agent prompts are:
1. **Focused** — One clear problem domain
2. **Self-contained** — All context needed to understand the problem
3. **Specific about output** — What should the agent return?

```markdown
Fix the 3 failing tests in src/agents/agent-tool-abort.test.ts:

1. "should abort tool with partial output capture" - expects 'interrupted at' in message
2. "should handle mixed completed and aborted tools" - fast tool aborted instead of completed
3. "should properly track pendingToolCount" - expects 3 results but gets 0

These are timing/race condition issues. Your task:

1. Read the test file and understand what each test verifies
2. Identify root cause - timing issues or actual bugs?
3. Fix by:
   - Replacing arbitrary timeouts with event-based waiting
   - Fixing bugs in abort implementation if found
   - Adjusting test expectations if testing changed behavior

Do NOT just increase timeouts - find the real issue.

Return: Summary of what you found and what you fixed.
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| **Too broad:** "Fix all the tests" — agent gets lost | **Specific:** "Fix agent-tool-abort.test.ts" — focused scope |
| **No context:** "Fix the race condition" — agent doesn't know where | **Context:** Paste the error messages and test names |
| **No constraints:** Agent might refactor everything | **Constraints:** "Do NOT change production code" or "Fix tests only" |
| **Vague output:** "Fix it" — you don't know what changed | **Specific:** "Return summary of root cause and changes" |

## Parallel Safety Check

Before dispatching a batch in parallel, verify:

1. **Map files to agents** — what will each agent touch?
2. **File overlap is necessary but not sufficient.** Also serialize agents that contend on: shared types/APIs/interfaces, DB migrations, generated artifacts, lockfiles, snapshots, shared config/schema, or environment singletons (dev server, shared database, browser sessions).
3. **No contention:** dispatch in parallel.
4. **Contention with harness-native isolation:** parallel is recoverable but not automatically safe — overlapping edits still need a real merge. Serialize contending units by default; run parallel-isolated only when the expected merge is trivial.
5. **Contention without isolation (shared workspace):** serialize — in a shared directory only the last writer survives.
6. **Cap concurrency** at ~3-5 workers even when more units are independent.

## When NOT to Use

- **Related failures:** Fixing one might fix others — investigate together first
- **Need full context:** Understanding requires seeing entire system
- **Exploratory debugging:** You don't know what's broken yet
- **Shared state:** Agents would interfere (editing same files, using same resources)

## Verification

After agents return:
1. **Review each summary** — Understand what changed
2. **Check for conflicts** — Did agents edit same code?
3. **Run full suite** — Verify all fixes work together
4. **Spot check** — Agents can make systematic errors

## Key Benefits

1. **Parallelization** — Multiple investigations happen simultaneously
2. **Focus** — Each agent has narrow scope, less context to track
3. **Independence** — Agents don't interfere with each other
4. **Speed** — N problems solved in time of 1

## Related Skills

- `debug` — For systematic root cause investigation before parallel fix dispatch
- `work` — For parallel implementation of plan units with isolation
- `code-review` — For final review after integrating parallel changes
