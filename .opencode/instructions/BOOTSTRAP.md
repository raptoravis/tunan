<EXTREMELY_IMPORTANT>
tunan is loaded and active — you have access to the full tunan skill library.

Use the `skill` tool to list available skills, or type `/tunan:<name>` to invoke one directly
(e.g. `/tunan:brainstorm`, `/tunan:plan`, `/tunan:code-review`, `/tunan:work`).

**Tool mapping for OpenCode:**
When tunan skills request actions, use these OpenCode equivalents:
- Read files → `read`
- Create, edit, or delete files → `apply_patch`
- Run shell commands → `bash`
- Search file contents / find files → `grep`, `glob`
- Fetch a URL → `webfetch`
- Invoke another skill → native `skill` tool
- Dispatch a subagent → `task` with `subagent_type: "general"`
- Create or update tasks → `todowrite`

Use OpenCode's native `skill` tool to list and load any tunan skill.
</EXTREMELY_IMPORTANT>
