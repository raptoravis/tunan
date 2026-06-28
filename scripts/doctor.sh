#!/usr/bin/env bash
# doctor.sh — Check environment for tunan plugin requirements.
#
# Usage: ./scripts/doctor.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check results
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Logging functions
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((CHECKS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((CHECKS_FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((CHECKS_WARNING++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if a command exists
check_command() {
    local cmd="$1"
    local name="${2:-$1}"
    
    if command -v "$cmd" &> /dev/null; then
        log_pass "$name is installed"
        return 0
    else
        log_fail "$name is not installed"
        return 1
    fi
}

# Check if a command is authenticated (for gh)
check_gh_auth() {
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            log_pass "GitHub CLI is authenticated"
            return 0
        else
            log_warn "GitHub CLI is installed but not authenticated"
            return 1
        fi
    fi
    return 1
}

# Check Node.js version
check_node_version() {
    if command -v node &> /dev/null; then
        local version
        version=$(node --version | sed 's/v//')
        local major
        major=$(echo "$version" | cut -d. -f1)
        
        if [ "$major" -ge 18 ]; then
            log_pass "Node.js version $version (>= 18)"
            return 0
        else
            log_fail "Node.js version $version (< 18 required)"
            return 1
        fi
    fi
    return 1
}

# Check if plugin directory exists
check_plugin_dirs() {
    local claude_dir="$HOME/.claude/plugins/tunan"
    local codex_dir="$HOME/.codex/plugins/tunan"
    local opencode_dir="$HOME/.opencode/plugins/tunan"
    
    if [ -d "$claude_dir" ]; then
        log_pass "Claude Code plugin directory exists"
    else
        log_info "Claude Code plugin directory not found (install with --target claude)"
    fi
    
    if [ -d "$codex_dir" ]; then
        log_pass "Codex plugin directory exists"
    else
        log_info "Codex plugin directory not found (install with --target codex)"
    fi
    
    if [ -d "$opencode_dir" ]; then
        log_pass "OpenCode plugin directory exists"
    else
        log_info "OpenCode plugin directory not found (install with --target opencode)"
    fi
}

# Main function
main() {
    echo -e "${BLUE}tunan plugin doctor${NC}"
    echo "=================="
    echo ""
    
    # Check required commands
    log_info "Checking required commands..."
    check_command "git" "Git"
    check_command "node" "Node.js"
    check_node_version
    check_command "npm" "npm"
    
    # Check optional commands
    log_info "Checking optional commands..."
    check_command "gh" "GitHub CLI"
    check_gh_auth
    
    # Check plugin directories
    log_info "Checking plugin directories..."
    check_plugin_dirs
    
    # Summary
    echo ""
    echo "=================="
    echo -e "${BLUE}Summary${NC}"
    echo "=================="
    echo ""
    echo -e "${GREEN}Passed: $CHECKS_PASSED${NC}"
    echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
    echo -e "${RED}Failed: $CHECKS_FAILED${NC}"
    echo ""
    
    if [ $CHECKS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All checks passed!${NC}"
        return 0
    else
        echo -e "${RED}Some checks failed. Please fix the issues above.${NC}"
        return 1
    fi
}

# Run main function
main