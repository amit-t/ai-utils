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
alias efc.info='echo "Epic Fitness Check - AI-Driven Assessment\n\nAvailable commands:\n  efc              - Run with Claude Code (default)\n  efc.cly          - Run with Claude Code YOLO mode\n  efc.dev          - Run with Devin YOLO mode\n  efc.here         - Run on current directory with Claude\n  efc.here.dev     - Run on current directory with Devin\n  efc.engage       - Run on ./Engage directory with Claude\n  efc.transact     - Run on ./Transact directory with Claude\n  efc.core         - Run on ./Core directory with Claude\n  efc.platform     - Run on ./Platform directory with Claude\n  efc.pwd          - Run on current working directory\n  efc.help         - Show script help\n  efc.version      - Show script version\n  efc.output       - List output files\n  efc.open         - Open output directory\n  efc.clean        - Clean output directory\n  efc.prompt       - Show assessment prompt\n  efc.log          - View log files\n\nPortfolio-specific (Devin):\n  efc.engage.dev   - Run on ./Engage with Devin\n  efc.transact.dev - Run on ./Transact with Devin\n  efc.core.dev     - Run on ./Core with Devin\n  efc.platform.dev - Run on ./Platform with Devin\n\nUsage examples:\n  efc.here                    # Run on current directory\n  efc.run /path/to/epics MyPortfolio  # Custom path and name\n  efc.engage                   # Run on ./Engage directory\n  efc.transact.dev             # Run on ./Transact with Devin"'

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
