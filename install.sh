#!/usr/bin/env bash
# install.sh — Cross-platform installer for tunan plugin.
#
# Supports OpenCode, MiMoCode, and ReasoniX.
# Usage:
#   ./install.sh --target opencode    # Install for OpenCode
#   ./install.sh --target mimocode    # Install for MiMoCode
#   ./install.sh --target reasonix    # Install for ReasoniX
#   ./install.sh --target all         # Install for all platforms
#   ./install.sh --dry-run            # Preview what would be installed

set -euo pipefail

SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
    link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TARGET="opencode"
DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --target TARGET    Install target: opencode, mimocode, reasonix, all (default: opencode)"
            echo "  --dry-run          Preview what would be installed without making changes"
            echo "  --verbose          Show detailed output"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --target opencode"
            echo "  $0 --target all"
            echo "  $0 --dry-run"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install for OpenCode
install_opencode() {
    log_info "Installing tunan for OpenCode..."

    OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
    OPENCODE_SKILLS_DIR="$OPENCODE_CONFIG_DIR/skills"
    OPENCODE_AGENTS_DIR="$OPENCODE_CONFIG_DIR/agents"
    OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would install skills -> $OPENCODE_SKILLS_DIR"
        log_info "[DRY RUN] Would install agents -> $OPENCODE_AGENTS_DIR"
        log_info "[DRY RUN] Would merge .mcp.json MCP servers into $OPENCODE_CONFIG_FILE"
        log_info "[DRY RUN] Would update $OPENCODE_CONFIG_FILE (MCP merge, remove wrong plugin)"
        return 0
    fi

    mkdir -p "$OPENCODE_CONFIG_DIR"

    CONV_SCRIPT="$SCRIPT_DIR/plugins/scripts/convert-agents.py"

    if command -v python3 >/dev/null 2>&1; then
        PYTHON=python3
    elif command -v python >/dev/null 2>&1; then
        PYTHON=python
    else
        PYTHON=""
    fi

    # --- 1. Install skills (with tunan- prefix) ---
    # OpenCode has no plugin namespace, so skills get a tunan- prefix
    if [ -d "$SCRIPT_DIR/plugins/skills" ]; then
        if [ -n "$PYTHON" ] && [ -f "$CONV_SCRIPT" ]; then
            rm -rf "$OPENCODE_SKILLS_DIR"
            mkdir -p "$OPENCODE_SKILLS_DIR"
            $PYTHON "$CONV_SCRIPT" "skills" "$SCRIPT_DIR/plugins/skills" "$OPENCODE_SKILLS_DIR" 2>/dev/null
            skill_count=$(ls -d "$OPENCODE_SKILLS_DIR/"*/ 2>/dev/null | wc -l)
            log_success "tunan skills installed at $OPENCODE_SKILLS_DIR ($skill_count skills, prefixed with tunan-)"
        else
            log_warning "Python not found — installing skills without tunan- prefix"
            rm -rf "$OPENCODE_SKILLS_DIR"
            mkdir -p "$OPENCODE_SKILLS_DIR"
            for skill_dir in "$SCRIPT_DIR/plugins/skills/"*/; do
                skill_name="$(basename "$skill_dir")"
                cp -R "$skill_dir" "$OPENCODE_SKILLS_DIR/$skill_name"
            done
            skill_count=$(ls -d "$OPENCODE_SKILLS_DIR/"*/ 2>/dev/null | wc -l)
            log_success "tunan skills installed at $OPENCODE_SKILLS_DIR ($skill_count skills, no prefix)"
        fi
    fi

    # --- 2. Install agents (with format conversion + tunan- prefix) ---
    if [ -d "$SCRIPT_DIR/plugins/agents" ]; then
        if [ -n "$PYTHON" ] && [ -f "$CONV_SCRIPT" ]; then
            rm -rf "$OPENCODE_AGENTS_DIR"
            mkdir -p "$OPENCODE_AGENTS_DIR"
            $PYTHON "$CONV_SCRIPT" "agents" "$SCRIPT_DIR/plugins/agents" "$OPENCODE_AGENTS_DIR" 2>/dev/null
            agent_count=$(ls "$OPENCODE_AGENTS_DIR/"*.md 2>/dev/null | wc -l)
            log_success "tunan agents installed at $OPENCODE_AGENTS_DIR ($agent_count agents, format converted for OpenCode)"
        else
            log_warning "Python not found — skipping agent installation (incompatible format)"
        fi
    fi

    # --- 3. Update global OpenCode config (removes wrong plugin, registers skills+commands+ MCP) ---
    MCP_SRC="$SCRIPT_DIR/plugins/.mcp.json"

    if command -v python3 >/dev/null 2>&1 && [ -f "$CONV_SCRIPT" ]; then
        $PYTHON "$CONV_SCRIPT" "config" \
            "$OPENCODE_CONFIG_FILE" \
            "$MCP_SRC" \
            "$OPENCODE_SKILLS_DIR" 2>/dev/null
        if [ $? -eq 0 ]; then
            log_success "Global OpenCode config updated at $OPENCODE_CONFIG_FILE"
        else
            log_warning "Could not update OpenCode config (python3 error)"
        fi
    elif command -v jq >/dev/null 2>&1; then
        if [ -f "$OPENCODE_CONFIG_FILE" ]; then
            jq 'if (.plugin | index("plugins/tunan")) then .plugin -= ["plugins/tunan"] else . end | if (.plugin | length) == 0 then del(.plugin) else . end' \
                "$OPENCODE_CONFIG_FILE" > "${OPENCODE_CONFIG_FILE}.tmp" \
                && mv "${OPENCODE_CONFIG_FILE}.tmp" "$OPENCODE_CONFIG_FILE" \
                && log_info "Removed incorrect plugin entry from config" \
                || log_warning "Could not update OpenCode config (jq error)"
        fi
        log_warning "Install the conversion script at $CONV_SCRIPT and re-run for full MCP/command registration."
    else
        log_warning "Neither python3 nor jq found — could not auto-update config"
        log_info "To complete installation, manually remove \"plugin\": [\"plugins/tunan\"] from $OPENCODE_CONFIG_FILE if present"
    fi

    log_info "Restart OpenCode to activate tunan skills"
}

# Install for MiMoCode
install_mimocode() {
    log_info "Installing tunan plugin for MiMoCode..."

    MIMOCODE_CONFIG_DIR="$HOME/.config/mimocode"
    MIMOCODE_PLUGIN_DIR="$MIMOCODE_CONFIG_DIR/plugins/tunan"
    MIMOCODE_CONFIG_FILE="$MIMOCODE_CONFIG_DIR/mimocode.json"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create: $MIMOCODE_PLUGIN_DIR"
        log_info "[DRY RUN] Would copy skills/ agents/ .mcp.json -> $MIMOCODE_PLUGIN_DIR/"
        log_info "[DRY RUN] Would update: $MIMOCODE_CONFIG_FILE"
        return 0
    fi

    # Create plugin directory
    mkdir -p "$MIMOCODE_PLUGIN_DIR"

    # Copy skills
    if [ -d "$SCRIPT_DIR/plugins/skills" ]; then
        cp -R "$SCRIPT_DIR/plugins/skills" "$MIMOCODE_PLUGIN_DIR/"
    fi

    # Copy agents
    if [ -d "$SCRIPT_DIR/plugins/agents" ]; then
        cp -R "$SCRIPT_DIR/plugins/agents" "$MIMOCODE_PLUGIN_DIR/"
    fi

    # Copy dotfiles explicitly
    if [ -f "$SCRIPT_DIR/plugins/.mcp.json" ]; then
        cp "$SCRIPT_DIR/plugins/.mcp.json" "$MIMOCODE_PLUGIN_DIR/"
    fi

    if [ -f "$SCRIPT_DIR/plugins/README.md" ]; then
        cp "$SCRIPT_DIR/plugins/README.md" "$MIMOCODE_PLUGIN_DIR/"
    fi

    # Create plugin-level mimocode.json
    cat > "$MIMOCODE_PLUGIN_DIR/mimocode.json" << 'PLUGINJSON'
{
  "skills": {
    "paths": ["./skills"]
  }
}
PLUGINJSON

    log_success "tunan plugin files installed at $MIMOCODE_PLUGIN_DIR"

    # --- Register plugin in global MiMoCode config ---
    mkdir -p "$MIMOCODE_CONFIG_DIR"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {"$schema": "https://mimocode.ai/config.json"}
plugins = cfg.get("plugin")
if not isinstance(plugins, list):
    plugins = []
if "plugins/tunan" not in plugins:
    plugins.append("plugins/tunan")
    cfg["plugin"] = plugins
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
' "$MIMOCODE_CONFIG_FILE" 2>/dev/null && log_success "tunan plugin registered in MiMoCode global config" || log_warning "Could not update MiMoCode config"
    else
        log_warning "python3 not found — could not auto-register plugin"
        log_info "To complete installation, add to $MIMOCODE_CONFIG_FILE:"
        log_info '  "plugin": ["plugins/tunan"]'
    fi

    log_info "Restart MiMoCode to activate tunan skills"
}

# Install for ReasoniX
install_reasonix() {
    log_info "Installing tunan skills for ReasoniX..."

    REASONIX_SKILLS_DIR="$HOME/.config/reasonix/skills"
    REASONIX_CONFIG_DIR="$HOME/.config/reasonix"
    REASONIX_CONFIG_FILE="$REASONIX_CONFIG_DIR/reasonix.toml"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create: $REASONIX_SKILLS_DIR"
        log_info "[DRY RUN] Would copy skills -> $REASONIX_SKILLS_DIR/"
        log_info "[DRY RUN] Would update: $REASONIX_CONFIG_FILE"
        return 0
    fi

    # Create skills directory
    mkdir -p "$REASONIX_SKILLS_DIR"

    # Copy skills (individual subdirs for auto-discovery)
    if [ -d "$SCRIPT_DIR/plugins/skills" ]; then
        for skill_dir in "$SCRIPT_DIR/plugins/skills/"*/; do
            skill_name="$(basename "$skill_dir")"
            cp -R "$skill_dir" "$REASONIX_SKILLS_DIR/$skill_name"
        done
    fi

    # Copy MCP config (ReasoniX reads .mcp.json directly)
    if [ -f "$SCRIPT_DIR/plugins/.mcp.json" ]; then
        cp "$SCRIPT_DIR/plugins/.mcp.json" "$REASONIX_CONFIG_DIR/"
    fi

    log_success "tunan skills installed at $REASONIX_SKILLS_DIR"

    # --- Register in ReasoniX config ---
    mkdir -p "$REASONIX_CONFIG_DIR"

    if [ -f "$REASONIX_CONFIG_FILE" ]; then
        # Check if [skills] section with our path already exists
        if grep -q 'tunan' "$REASONIX_CONFIG_FILE" 2>/dev/null; then
            log_info "tunan already registered in ReasoniX config"
        else
            # Append [skills] paths entry
            cat >> "$REASONIX_CONFIG_FILE" << 'TOMLEOF'

[skills]
paths = ["~/.config/reasonix/skills"]
TOMLEOF
            log_success "tunan registered in ReasoniX config"
        fi
    else
        # Create new config
        cat > "$REASONIX_CONFIG_FILE" << 'TOMLEOF'
[skills]
paths = ["~/.config/reasonix/skills"]
TOMLEOF
        log_success "tunan registered in ReasoniX config"
    fi

    log_info "Restart ReasoniX to activate tunan skills"
}

# Main installation logic
main() {
    echo -e "${BLUE}tunan plugin installer${NC}"
    echo "===================="
    echo ""

    # Validate target
    case $TARGET in
        opencode|mimocode|reasonix|all)
            ;;
        *)
            log_error "Invalid target: $TARGET"
            echo "Valid targets: opencode, mimocode, reasonix, all"
            exit 1
            ;;
    esac

    # Install based on target
    case $TARGET in
        opencode)
            install_opencode
            ;;
        mimocode)
            install_mimocode
            ;;
        reasonix)
            install_reasonix
            ;;
        all)
            install_opencode
            install_mimocode
            install_reasonix
            ;;
    esac

    echo ""
    log_success "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your AI coding assistant"
    echo "  2. Run /tunan:setup to configure your environment"
    echo ""
}

# Run main function
main