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
    log_info "Installing tunan plugin for OpenCode..."

    OPENCODE_PLUGIN_DIR="$HOME/.opencode/plugins/tunan"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create: $OPENCODE_PLUGIN_DIR"
        log_info "[DRY RUN] Would copy: $SCRIPT_DIR/plugins/* -> $OPENCODE_PLUGIN_DIR/"
        return 0
    fi

    mkdir -p "$OPENCODE_PLUGIN_DIR"
    cp -R "$SCRIPT_DIR/plugins/"* "$OPENCODE_PLUGIN_DIR/"

    log_success "tunan plugin installed for OpenCode"
    log_info "Restart OpenCode to activate the plugin"
}

# Install for MiMoCode
install_mimocode() {
    log_info "Installing tunan plugin for MiMoCode..."

    MIMOCODE_PLUGIN_DIR="$HOME/.mimocode/plugins/tunan"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create: $MIMOCODE_PLUGIN_DIR"
        log_info "[DRY RUN] Would copy: $SCRIPT_DIR/plugins/* -> $MIMOCODE_PLUGIN_DIR/"
        return 0
    fi

    mkdir -p "$MIMOCODE_PLUGIN_DIR"
    cp -R "$SCRIPT_DIR/plugins/"* "$MIMOCODE_PLUGIN_DIR/"

    log_success "tunan plugin installed for MiMoCode"
    log_info "Restart MiMoCode to activate the plugin"
}

# Install for ReasoniX
install_reasonix() {
    log_info "Installing tunan plugin for ReasoniX..."

    REASONIX_SKILLS_DIR="$HOME/.reasonix/skills"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create: $REASONIX_SKILLS_DIR"
        log_info "[DRY RUN] Would copy: $SCRIPT_DIR/plugins/skills/* -> $REASONIX_SKILLS_DIR/"
        return 0
    fi

    mkdir -p "$REASONIX_SKILLS_DIR"
    cp -R "$SCRIPT_DIR/plugins/skills/"* "$REASONIX_SKILLS_DIR/"

    log_success "tunan skills installed for ReasoniX"
    log_info "Restart ReasoniX to activate the skills"
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