# Installing tunan for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add tunan to the `plugin` array in your `opencode.json` (global at `~/.config/opencode/opencode.json` or project-level):

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and registers all tunan skills.

Verify by asking: "List available skills" or "Use the brainstorm skill"

If you also use Claude Code, Codex, or another harness, install tunan separately for each one.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load brainstorm
```

Or invoke a tunan command: `/tunan:brainstorm`, `/tunan:plan`, `/tunan:code-review`, `/tunan:work`, etc.

## Updating

OpenCode installs tunan through a git-backed package spec. Some OpenCode and Bun versions pin the resolved git dependency, so a restart may not pick up the newest commit. If updates do not appear, clear OpenCode's package cache or reinstall the plugin.

To pin a specific version:

```json
{
  "plugin": ["tunan@git+https://github.com/raptoravis/tunan.git#v3.37.0"]
}
```

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i tunan`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Windows install issues

Some Windows OpenCode builds have upstream issues with git-backed plugin specs, including cache paths for `git+https` URLs and Bun not finding `git.exe`. If OpenCode cannot install the plugin, try installing with system npm and pointing OpenCode at the local package:

```powershell
npm install tunan@git+https://github.com/raptoravis/tunan.git --prefix "$HOME\.config\opencode"
```

Then use the installed package path in `opencode.json`:

```json
{
  "plugin": ["~/.config/opencode/node_modules/tunan"]
}
```

### Skills not found

1. Use the `skill` tool to list discovered skills
2. Check that the plugin is loading (see above)

## Getting Help

- Report issues: https://github.com/raptoravis/tunan/issues
- Full documentation: https://github.com/raptoravis/tunan
