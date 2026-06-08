# Resolution Templates

Choose the template matching the problem_type track (see `references/schema.yaml`).

A learning is a `tunan:solution` **comment** on its feature issue `#N` (the feature issue is labeled `tunan:solution` for cross-feature discovery). Each template below maps onto a comment body: the **first line is the marker** `<!-- tunan:solution -->`, then the frontmatter YAML inside a fenced ```yaml block (the `--- ... ---` delimiters shown in the templates become the opening/closing of that fence), then the markdown sections form the rest of the comment. The `title:` field names the learning (the host feature issue keeps its own `[req]` title); the `<slug>` used for overlap matching is the sanitized problem slug (no date suffix; the `date:` field is the canonical creation date). `source_issue: #N` records the feature issue the comment lives on. See `references/comment-chain-storage.md` for the write/update recipes.

---

## Bug Track Template

Use for: `build_error`, `test_failure`, `runtime_error`, `performance_issue`, `database_issue`, `security_issue`, `ui_bug`, `integration_issue`, `logic_error`

<!-- YAML safety: array items (symptoms, applies_when, tags, related_components) starting with ` [ * & ! | > % @ ? or containing ": " must be wrapped in double quotes. See references/yaml-schema.md > "YAML Safety Rules". -->

```markdown
<!-- tunan:solution -->
---
title: [Clear problem title]
date: [YYYY-MM-DD]
source_issue: "#[N]"   # the feature issue this comment lives on — quote it; a bare #N reads as a YAML comment
category: [category slug from references/yaml-schema.md]
module: [Module or area]
problem_type: [schema enum]
component: [schema enum]
symptoms:
  - [Observable symptom 1]
root_cause: [schema enum]
resolution_type: [schema enum]
severity: [schema enum]
tags: [keyword-one, keyword-two]
---

# [Clear problem title]

## Problem
[1-2 sentence description of the issue and user-visible impact]

## Symptoms
- [Observable symptom or error]

## What Didn't Work
- [Attempted fix and why it failed]

## Solution
[The fix that worked, including code snippets when useful]

## Why This Works
[Root cause explanation and why the fix addresses it]

## Prevention
- [Concrete practice, test, or guardrail]

## Related Issues
- [Originating requirement / plan on the same feature issue, e.g. #N/req, #N/plan]
- [Other related feature issues or solution comments, by #N, if any]
```

---

## Knowledge Track Template

Use for: `best_practice`, `documentation_gap`, `workflow_issue`, `developer_experience`

<!-- YAML safety: array items (symptoms, applies_when, tags, related_components) starting with ` [ * & ! | > % @ ? or containing ": " must be wrapped in double quotes. See references/yaml-schema.md > "YAML Safety Rules". -->

```markdown
<!-- tunan:solution -->
---
title: [Clear, descriptive title]
date: [YYYY-MM-DD]
source_issue: "#[N]"   # the feature issue this comment lives on — quote it; a bare #N reads as a YAML comment
category: [category slug from references/yaml-schema.md]
module: [Module or area]
problem_type: [schema enum]
component: [schema enum]
severity: [schema enum]
applies_when:
  - [Condition where this applies]
tags: [keyword-one, keyword-two]
---

# [Clear, descriptive title]

## Context
[What situation, gap, or friction prompted this guidance]

## Guidance
[The practice, pattern, or recommendation with code examples when useful]

## Why This Matters
[Rationale and impact of following or not following this guidance]

## When to Apply
- [Conditions or situations where this applies]

## Examples
[Concrete before/after or usage examples showing the practice in action]

## Related
- [Originating requirement / plan on the same feature issue, e.g. #N/req, #N/plan]
- [Other related feature issues or solution comments, by #N, if any]
```
