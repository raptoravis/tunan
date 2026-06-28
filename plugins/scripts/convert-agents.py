#!/usr/bin/env python3
"""Convert tunan agent files from Claude Code frontmatter format to OpenCode format.
Also prefixes names with 'tunan-' since OpenCode has no plugin namespace.

Usage:
    python3 convert-agents.py <source-dir> <target-dir> [--skip-prefix]

Claude Code format:
    ---
    name: agent-name
    description: "..."
    model: inherit
    tools: Read, Grep, Glob, Bash, Write
    color: red
    ---

OpenCode format:
    ---
    name: tunan-agent-name
    description: "..."
    model: inherit
    mode: subagent
    tools:
      read: true
      grep: true
      glob: true
      bash: true
      write: true
    color: "error"
    ---
"""

import os
import re
import sys

# Map Claude Code color names to OpenCode enum values
COLOR_MAP = {
    "red": "error",
    "blue": "info",
    "cyan": "info",
    "yellow": "warning",
    "purple": "accent",
    "violet": "accent",
    "green": "success",
}

# Map Claude Code tool names to OpenCode permission keys
TOOL_MAP = {
    "Read": "read",
    "Write": "write",
    "Edit": "edit",
    "Bash": "bash",
    "Glob": "glob",
    "Grep": "grep",
    "WebFetch": "fetch",
    "WebSearch": "search",
}


def convert_agent(source_path: str, target_path: str, skip_prefix: bool = False) -> bool:
    """Read a Claude Code agent file, convert frontmatter, write OpenCode format."""
    with open(source_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Extract YAML frontmatter between --- markers
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n?(.*)", content, re.DOTALL)
    if not m:
        return False  # No frontmatter found, skip

    raw_frontmatter = m.group(1)
    body = m.group(2)

    # Parse key-value pairs from frontmatter
    fields = {}
    for line in raw_frontmatter.split("\n"):
        line = line.strip()
        if not line:
            continue
        # Handle description with possible quoted value
        match = re.match(r"^(\w[\w-]*):\s*(.*)", line)
        if match:
            key = match.group(1)
            val = match.group(2).strip()
            # Strip surrounding quotes if present
            if len(val) >= 2 and val[0] == val[-1] and val[0] in ('"', "'"):
                val = val[1:-1]
            fields[key] = val

    # Build new OpenCode-compatible frontmatter
    lines = ["---"]

    # name (prepend tunan- for OpenCode namespace)
    if "name" in fields:
        raw_name = fields["name"]
        if skip_prefix:
            lines.append(f"name: {raw_name}")
        else:
            lines.append(f"name: tunan-{raw_name}")

    # description (pass through)
    if "description" in fields:
        desc = fields["description"]
        if any(c in desc for c in (":", "#", "{", "}", "[", "]", "&", "*")):
            lines.append(f'description: "{desc}"')
        else:
            lines.append(f"description: {desc}")

    # model (pass through)
    if "model" in fields:
        lines.append(f"model: {fields['model']}")

    # mode (always "subagent" for tunan agents)
    lines.append("mode: subagent")

    # tools (convert from comma-separated string to YAML object)
    if "tools" in fields:
        tools_str = fields["tools"]
        tool_names = [t.strip() for t in tools_str.split(",") if t.strip()]
        if tool_names:
            lines.append("tools:")
            added_mcp = False
            for name in tool_names:
                oc_key = TOOL_MAP.get(name)
                if oc_key:
                    lines.append(f'  {oc_key}: true')
                elif name.startswith("mcp__"):
                    if not added_mcp:
                        lines.append(f'  mcp: true')
                        added_mcp = True
                elif name:
                    safe_key = name.lower().replace(" ", "_").replace("*", "")
                    lines.append(f'  {safe_key}: true')

    # color (convert to OpenCode enum)
    if "color" in fields:
        cc_color = fields["color"].lower()
        oc_color = COLOR_MAP.get(cc_color, cc_color)
        lines.append(f'color: "{oc_color}"')

    lines.append("---")

    # Write output file
    new_content = "\n".join(lines) + "\n\n" + body.lstrip("\n")

    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    with open(target_path, "w", encoding="utf-8") as f:
        f.write(new_content)

    return True


def convert_skill(skill_dir: str, target_dir: str) -> bool:
    """Copy a skill directory to OpenCode with tunan- prefix and updated name frontmatter.

    Source: skills/cpm/SKILL.md (name: cpm)
    Target: skills/tunan-cpm/SKILL.md (name: tunan-cpm)
    """
    skill_name = os.path.basename(skill_dir)
    prefixed = f"tunan-{skill_name}"
    target_path = os.path.join(target_dir, prefixed)

    # Copy entire directory tree
    import shutil
    if os.path.exists(target_path):
        shutil.rmtree(target_path)
    shutil.copytree(skill_dir, target_path)

    # Update name: frontmatter in SKILL.md
    skill_md = os.path.join(target_path, "SKILL.md")
    if os.path.exists(skill_md):
        with open(skill_md, "r", encoding="utf-8") as f:
            content = f.read()
        # Replace first occurrence of 'name: <skill_name>' with 'name: tunan-<skill_name>'
        updated = re.sub(
            rf'^name:\s*{re.escape(skill_name)}\s*$',
            f"name: {prefixed}",
            content,
            count=1,
            flags=re.MULTILINE,
        )
        if updated != content:
            with open(skill_md, "w", encoding="utf-8") as f:
                f.write(updated)
            return True
    return False


def convert_skills(source_dir: str, target_dir: str) -> int:
    """Convert all skills from source_dir to target_dir, prefixing with tunan-."""
    if not os.path.isdir(source_dir):
        print(f"Skills source directory not found: {source_dir}", file=sys.stderr)
        return 0

    count = 0
    for entry in sorted(os.listdir(source_dir)):
        entry_path = os.path.join(source_dir, entry)
        if os.path.isdir(entry_path):
            if convert_skill(entry_path, target_dir):
                count += 1
    return count


def update_config(config_path: str, mcp_src_path: str, skills_dir: str) -> list:
    """Update OpenCode config: remove wrong plugin entry, register skills path,
    merge MCP servers, register skills as commands. Returns list of added MCP names."""
    import subprocess as _sp

    # Read existing config
    try:
        with open(config_path, encoding="utf-8") as f:
            cfg = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        cfg = {"$schema": "https://opencode.ai/config.json"}

    # Remove wrong plugin entry
    if "plugin" in cfg:
        plugins = cfg["plugin"]
        if isinstance(plugins, list):
            filtered = [p for p in plugins if p != "plugins/tunan"]
            if len(filtered) == 0:
                del cfg["plugin"]
            elif len(filtered) != len(plugins):
                cfg["plugin"] = filtered

    # Ensure skills path registered
    if "skills" not in cfg:
        cfg["skills"] = {"paths": [skills_dir]}

    # Merge MCP (never overwrite existing)
    added_mcp = []
    if os.path.exists(mcp_src_path):
        try:
            with open(mcp_src_path, encoding="utf-8") as f:
                mcp_data = json.load(f)
            existing = cfg.get("mcp", {})
            if not isinstance(existing, dict):
                existing = {}
            for name, entry in mcp_data.get("mcpServers", {}).items():
                if name in existing:
                    continue
                if "command" not in entry:
                    continue
                cmd = [entry["command"]] + entry.get("args", [])
                if name == "codegraph":
                    try:
                        _sp.run(["codegraph", "--version"], capture_output=True, timeout=5)
                        cmd = ["codegraph", "serve", "--mcp"]
                    except (FileNotFoundError, _sp.TimeoutExpired):
                        pass
                existing[name] = {"type": "local", "command": cmd, "enabled": True}
                added_mcp.append(name)
            if added_mcp:
                cfg["mcp"] = existing
        except Exception:
            pass

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")

    return added_mcp


def main():
    if len(sys.argv) < 3:
        print("Usage:", file=sys.stderr)
        print("  convert-agents.py agents <source-dir> <target-dir>", file=sys.stderr)
        print("  convert-agents.py skills <source-dir> <target-dir>", file=sys.stderr)
        print("  convert-agents.py config <config-path> [mcp-src-path] [skills-dir]", file=sys.stderr)
        sys.exit(1)

    mode = sys.argv[1]

    if mode == "agents":
        if len(sys.argv) < 4:
            print("Usage: convert-agents.py agents <source-dir> <target-dir>", file=sys.stderr)
            sys.exit(1)
        source_dir = sys.argv[2]
        target_dir = sys.argv[3]
        if not os.path.isdir(source_dir):
            print(f"Source directory not found: {source_dir}", file=sys.stderr)
            sys.exit(1)
        count = 0
        errors = 0
        for entry in sorted(os.listdir(source_dir)):
            if not entry.endswith(".md"):
                continue
            src = os.path.join(source_dir, entry)
            dst = os.path.join(target_dir, f"tunan-{entry}")
            if convert_agent(src, dst):
                count += 1
            else:
                errors += 1
                print(f"Warning: Could not convert {entry} (no frontmatter)", file=sys.stderr)
        print(f"Converted {count} agent file(s)", end="")
        if errors:
            print(f", {errors} skipped", end="")
        print()
    elif mode == "skills":
        if len(sys.argv) < 4:
            print("Usage: convert-agents.py skills <source-dir> <target-dir>", file=sys.stderr)
            sys.exit(1)
        source_dir = sys.argv[2]
        target_dir = sys.argv[3]
        count = convert_skills(source_dir, target_dir)
        print(f"Installed {count} skill(s) with tunan- prefix")
    elif mode == "config":
        config_path = sys.argv[2]
        mcp_src = sys.argv[3] if len(sys.argv) > 3 else ""
        skills_dir = sys.argv[4] if len(sys.argv) > 4 else ""
        added = update_config(config_path, mcp_src, skills_dir)
        if added:
            print(f"MCP servers added: {','.join(added)}")
    else:
        print(f"Unknown mode: {mode} (use 'agents', 'skills', or 'config')", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
