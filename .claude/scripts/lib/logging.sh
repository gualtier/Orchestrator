#!/bin/bash
# =============================================
# LOGGING - Log functions and colors
# =============================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# Timestamp
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Log functions
log_info() { echo -e "${BLUE}[$(timestamp)]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(timestamp)] ✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}[$(timestamp)] ⚠${NC} $1"; }
log_error() { echo -e "${RED}[$(timestamp)] ✗${NC} $1"; }
log_step() { echo -e "${MAGENTA}[$(timestamp)] ▶${NC} $1"; }
log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo -e "${GRAY}[$(timestamp)] DEBUG:${NC} $1"; }

# Header decorativo
log_header() {
    local title=$1
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}$title${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Separador
log_separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# JSON output (for automation)
log_json() {
    local level=$1
    local message=$2
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}"
}
