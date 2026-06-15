# Handoff issue body template

The handoff lives in the body of a GitHub issue labeled `tunan:handoff` — there
is no local `HANDOFF.md`. Build the body as a `yaml` metadata block followed by
the handoff sections below.

Omit empty sections, but **NEVER omit Failed Approaches if anything was tried
and abandoned** (write "None" only if truly nothing failed).

````markdown
```yaml
kind: handoff
branch: <git branch>
status: <In Progress | Blocked | Ready for Review>
created: <YYYY-MM-DD>
```

# Handoff: <Brief Task Title>

## Goal

<1-2 sentences: what the user wants to achieve>

## Completed

- [x] <Specific completed item>
- [x] <Another completed item>

## Not Yet Done

- [ ] <Remaining task — be specific>
- [ ] <Another remaining task>

## Failed Approaches (Don't Repeat These)

<Always include this if anything was tried and abandoned. Be specific:>
- What was attempted
- Why it failed (error message, performance issue, design flaw)
- Why the current approach is better

Example:
> Tried passport.js for OAuth but it conflicted with existing Express
> middleware (req.user was undefined). Switched to oauth4webapi, which works
> directly with fetch.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| <Choice made> | <Why this approach> |

## Current State

**Working**: <What's functional right now>

**Broken**: <What's not working, error messages if relevant>

**Uncommitted Changes**: <Summary of unstaged/staged changes>

## Files to Know

| File | Why It Matters |
|------|----------------|
| `path/to/key/file.ts` | <Brief description> |

## Code Context

<Include actual code the next agent needs. Don't describe — show:>

**Key interfaces/signatures** (so the agent knows how to call/modify them):

```ts
function useAuth(): { user: User | null; login: (creds: Credentials) => Promise<void> }
```

**API request/response shapes** (if backend work):

```json
{ "id": 123, "status": "created" }
```

**Non-obvious logic** (anything tricky that isn't self-documenting)

## Resume Instructions

<Be extremely specific. Not "test the feature" but step-by-step with expected
outcomes:>

1. <Setup step if needed — migrations, env vars, etc.>
2. <First action with exact command or file to edit>
3. <Verification step with expected outcome>
   - Expected: <what should happen>
   - If it fails: <what to check>

## Setup Required

<Only if there are prerequisites the next agent needs — env vars, test accounts,
required services.>

## Edge Cases & Error Handling

<Known edge cases and how they're handled — or should be.>

## Warnings

<Gotchas, things that look wrong but are intentional, or traps to avoid.>
````

## Guidelines

- **Failed approaches are mandatory** when anything was abandoned — document it.
- **Show code, don't describe** — include actual signatures, interfaces, shapes.
- **Testing steps need expected outcomes** — "verify it works" is useless.
- Be brutally concise — every word should earn its place.
- Include error messages verbatim when relevant.
- Use file paths relative to repo root.
- If there's a blocker, say so prominently (and set `status: Blocked`).
- Write the body to an OS-appropriate temp file and pass it via `--body-file`;
  never paste a long body inline on the command line. Use `mktemp` on
  macOS/Linux (or Git Bash); `Join-Path $env:TEMP ([guid]::NewGuid())` on Windows
  PowerShell — never hardcode `/tmp`.
