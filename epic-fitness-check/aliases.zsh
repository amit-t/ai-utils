#!/usr/bin/env zsh
# =============================================================================
#  aliases.zsh
#  Epic Fitness Check - Convenient Aliases
# =============================================================================

# Script path - use absolute path for global access
EPIC_FITNESS_SCRIPT="/Users/amittiwari/Projects/Tools-Utilities/ai-utils/epic-fitness-check/epic_fitness_check.zsh"
EPIC_FITNESS_DIR="/Users/amittiwari/Projects/Tools-Utilities/ai-utils/epic-fitness-check"

# Basic aliases - run from any directory
alias efc='$EPIC_FITNESS_SCRIPT --cly'
alias efc.cly='$EPIC_FITNESS_SCRIPT --cly'
alias efc.dev='$EPIC_FITNESS_SCRIPT --dev'

# Current directory aliases - run on current working directory
alias efc.here='$EPIC_FITNESS_SCRIPT --cly "$(pwd)" "$(basename "$(pwd)")"'
alias efc.here.dev='$EPIC_FITNESS_SCRIPT --dev "$(pwd)" "$(basename "$(pwd)")"'

# Portfolio-specific aliases - run from any directory
alias efc.engage='$EPIC_FITNESS_SCRIPT --cly ./Engage "Engage"'
alias efc.transact='$EPIC_FITNESS_SCRIPT --cly ./Transact "Transact"'
alias efc.core='$EPIC_FITNESS_SCRIPT --cly ./Core "Core"'
alias efc.platform='$EPIC_FITNESS_SCRIPT --cly ./Platform "Platform"'

# Portfolio-specific aliases (Devin) - run from any directory
alias efc.engage.dev='$EPIC_FITNESS_SCRIPT --dev ./Engage "Engage"'
alias efc.transact.dev='$EPIC_FITNESS_SCRIPT --dev ./Transact "Transact"'
alias efc.core.dev='$EPIC_FITNESS_SCRIPT --dev ./Core "Core"'
alias efc.platform.dev='$EPIC_FITNESS_SCRIPT --dev ./Platform "Platform"'

# Quick aliases for any directory
alias efc.pwd='$EPIC_FITNESS_SCRIPT --cly "$(pwd)" "$(basename "$(pwd)")"'
alias efc.pwd.dev='$EPIC_FITNESS_SCRIPT --dev "$(pwd)" "$(basename "$(pwd)")"'

# Help and info aliases
alias efc.help='$EPIC_FITNESS_SCRIPT --help'
alias efc.version='$EPIC_FITNESS_SCRIPT --version'
alias efc.info='echo "Epic Fitness Check - AI-Driven Assessment\n\nFILE MODE (reads .doc/.docx from a directory):\n  efc              - Run with Claude Code (default)\n  efc.cly          - Run with Claude Code YOLO mode\n  efc.dev          - Run with Devin YOLO mode\n  efc.here         - Run on current directory with Claude\n  efc.here.dev     - Run on current directory with Devin\n  efc.pwd          - Run on current working directory\n  efc.run <dir> <portfolio> [cly|dev]\n\nMCP MODE (pulls epics live from Jira via MCP):\n  efc.mcp.cly <PORTFOLIO> EPIC-1 EPIC-2 ...\n  efc.mcp.dev <PORTFOLIO> EPIC-1 EPIC-2 ...\n  efc.mcp <cly|dev> <PORTFOLIO> EPIC-1 EPIC-2 ...\n\nPortfolio aliases (FILE mode — Claude):\n  efc.engage       - ./Engage directory\n  efc.transact     - ./Transact directory\n  efc.core         - ./Core directory\n  efc.platform     - ./Platform directory\n\nPortfolio aliases (FILE mode — Devin):\n  efc.engage.dev   - ./Engage with Devin\n  efc.transact.dev - ./Transact with Devin\n  efc.core.dev     - ./Core with Devin\n  efc.platform.dev - ./Platform with Devin\n\nUtilities:\n  efc.help         - Show script help\n  efc.version      - Show script version\n  efc.output       - List output files\n  efc.open         - Open output directory\n  efc.clean        - Clean output directory\n  efc.prompt       - Show assessment prompt\n  efc.log          - View log files\n\nExamples:\n  efc.here                                    # FILE mode, current dir\n  efc.engage                                   # FILE mode, ./Engage\n  efc.mcp.cly Engage ICS-21226 ICS-21799       # MCP mode, Claude\n  efc.mcp.dev Core REQ-7318 ICS-23947          # MCP mode, Devin"'

# Output directory aliases - check current dir first, then script dir
alias efc.output='ls -la fitness_output/ 2>/dev/null || ls -la "$EPIC_FITNESS_DIR/fitness_output/" 2>/dev/null || echo "No output directory found"'
alias efc.open='open fitness_output/ 2>/dev/null || open "$EPIC_FITNESS_DIR/fitness_output/" 2>/dev/null || echo "No output directory found"'

# Utility aliases
alias efc.clean='rm -rf fitness_output/ 2>/dev/null && echo "Cleaned local fitness output directory" || (cd "$EPIC_FITNESS_DIR" && rm -rf fitness_output/ && echo "Cleaned script fitness output directory")'
alias efc.prompt='cat "$EPIC_FITNESS_DIR/PROMPT.md"'
alias efc.log='tail -f fitness_output/*.log 2>/dev/null || tail -f "$EPIC_FITNESS_DIR/fitness_output"/*.log 2>/dev/null || echo "No log files found"'

# Function-based aliases for dynamic usage - works from any directory
efc.run() {
    local dir="$1"
    local portfolio="$2"
    local tool="$3"
    
    if [[ -z "$tool" ]]; then
        tool="cly"
    fi
    
    if [[ -z "$dir" ]]; then
        dir="."
    fi
    
    if [[ -z "$portfolio" ]]; then
        portfolio="$(basename "$dir")"
    fi
    
    "$EPIC_FITNESS_SCRIPT" "--$tool" "$dir" "$portfolio"
}

# MCP mode function - pull epics from Jira MCP
efc.mcp() {
    local tool="$1"
    local portfolio="$2"
    shift 2 2>/dev/null || { echo "Usage: efc.mcp <cly|dev> <PORTFOLIO> EPIC-1 EPIC-2 ..."; return 1; }
    
    if [[ -z "$tool" || -z "$portfolio" || $# -eq 0 ]]; then
        echo "Usage: efc.mcp <cly|dev> <PORTFOLIO> EPIC-1 EPIC-2 ..."
        return 1
    fi
    
    "$EPIC_FITNESS_SCRIPT" "--$tool" --mcp --jira "$portfolio" "$@"
}

# MCP convenience aliases
efc.mcp.cly() {
    local portfolio="$1"
    shift 2>/dev/null || { echo "Usage: efc.mcp.cly <PORTFOLIO> EPIC-1 EPIC-2 ..."; return 1; }
    efc.mcp cly "$portfolio" "$@"
}

efc.mcp.dev() {
    local portfolio="$1"
    shift 2>/dev/null || { echo "Usage: efc.mcp.dev <PORTFOLIO> EPIC-1 EPIC-2 ..."; return 1; }
    efc.mcp dev "$portfolio" "$@"
}

# Convenience functions
alias efc.run.cly='efc.run "$1" "$2" "cly"'
alias efc.run.dev='efc.run "$1" "$2" "dev"'

# Completion helper
_efc_complete() {
    local -a commands
    commands=(
        'cly:Run with Claude Code YOLO mode'
        'dev:Run with Devin YOLO mode'
        'help:Show help information'
        'version:Show version information'
        'clean:Clean output directory'
        'output:List output files'
        'open:Open output directory'
        'prompt:Show assessment prompt'
    )
    
    _describe 'command' commands
}

compdef _efc_complete efc
compdef _efc_complete efc.cly
compdef _efc_complete efc.dev

# Export variables for use in other scripts
export EPIC_FITNESS_SCRIPT
export EPIC_FITNESS_DIR
export EPIC_FITNESS_PROMPT="$EPIC_FITNESS_DIR/PROMPT.md"

echo "Epic Fitness Check aliases loaded. Use 'efc.help' for usage information."
