#!/data/data/com.termux/files/usr/bin/bash
#
# tasker.sh - Termux:Tasker Integration Functions
# Ubuntu 26.04 Resolute on Termux Project
#

# Prevent double-sourcing
[[ -n "${_TASKER_SH_LOADED:-}" ]] && return 0
_TASKER_SH_LOADED=1

# ============================================================================
# CONFIGURATION
# ============================================================================

TASKER_SCRIPTS_DIR="${HOME}/.termux/tasker"
TASKER_LOG_DIR="${HOME}/ubuntu/logs/tasker"

# ============================================================================
# NOTIFICATION FUNCTIONS
# ============================================================================

# Send notification via Termux:API
tasker_notify() {
    local title="${1:-Ubuntu}"
    local content="${2:-}"
    local id="${3:-ubuntu-notification}"
    
    if command -v termux-notification &>/dev/null; then
        termux-notification \
            --title "${title}" \
            --content "${content}" \
            --id "${id}" \
            2>/dev/null || true
    fi
}

# Send notification with action
tasker_notify_action() {
    local title="$1"
    local content="$2"
    local action="$3"
    local id="${4:-ubuntu-action}"
    
    if command -v termux-notification &>/dev/null; then
        termux-notification \
            --title "${title}" \
            --content "${content}" \
            --id "${id}" \
            --action "${action}" \
            2>/dev/null || true
    fi
}

# Remove notification
tasker_notify_remove() {
    local id="${1:-ubuntu-notification}"
    
    if command -v termux-notification-remove &>/dev/null; then
        termux-notification-remove "${id}" 2>/dev/null || true
    fi
}

# ============================================================================
# MODE FUNCTIONS
# ============================================================================

# Get current mode
tasker_get_mode() {
    local mode_file="${TASKER_LOG_DIR}/.current_mode"
    
    if [[ -f "${mode_file}" ]]; then
        cat "${mode_file}"
    else
        echo "portable"
    fi
}

# Set current mode
tasker_set_mode() {
    local mode="$1"
    local mode_file="${TASKER_LOG_DIR}/.current_mode"
    
    mkdir -p "${TASKER_LOG_DIR}" 2>/dev/null || true
    echo "${mode}" > "${mode_file}"
    
    # Log mode change
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mode changed to: ${mode}" >> "${TASKER_LOG_DIR}/mode-changes.log"
}

# ============================================================================
# TASKER SCRIPT HELPERS
# ============================================================================

# Log tasker action
tasker_log() {
    local message="$1"
    local log_file="${TASKER_LOG_DIR}/tasker.log"
    
    mkdir -p "${TASKER_LOG_DIR}" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> "${log_file}"
}

# Check if Tasker is available
tasker_available() {
    [[ -d "${TASKER_SCRIPTS_DIR}" ]] && command -v termux-notification &>/dev/null
}

# ============================================================================
# EXPORT
# ============================================================================

export TASKER_SCRIPTS_DIR TASKER_LOG_DIR
export -f tasker_notify tasker_notify_action tasker_notify_remove
export -f tasker_get_mode tasker_set_mode
export -f tasker_log tasker_available
