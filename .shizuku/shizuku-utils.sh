#!/data/data/com.termux/files/usr/bin/bash
#
# shizuku-utils.sh - Shizuku helper utilities for Termux
#
SHIZUKU_DIR="${HOME}/.shizuku"
RISH="${SHIZUKU_DIR}/rish"

# Check if Shizuku is running
shizuku_running() {
    if [[ -x "${RISH}" ]]; then
        if "${RISH}" -c "id" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Run command via Shizuku
shizuku_exec() {
    if shizuku_running; then
        "${RISH}" -c "$*"
    else
        echo "Error: Shizuku not running"
        return 1
    fi
}

# Get Shizuku status
shizuku_status() {
    echo "Shizuku Status"
    echo "=============="
    
    if [[ -f "${RISH}" ]]; then
        echo "rish: Found"
    else
        echo "rish: Not found"
    fi
    
    if [[ -f "${SHIZUKU_DIR}/rish_shizuku.dex" ]]; then
        echo "dex: Found"
    else
        echo "dex: Not found"
    fi
    
    if shizuku_running; then
        echo "Status: Running"
        echo ""
        echo "Shell UID: $(shizuku_exec id -u)"
    else
        echo "Status: Not running"
        echo ""
        echo "To start Shizuku:"
        echo "  1. Open Shizuku app"
        echo "  2. Start via Wireless debugging or ADB"
    fi
}

# Show help
shizuku_help() {
    cat << 'EOF'
Shizuku Utilities

Commands:
  shizuku_status    Check Shizuku status
  shizuku_running   Test if Shizuku is active (for scripts)
  shizuku_exec      Run command via Shizuku shell

Examples:
  shizuku_status
  shizuku_exec pm list packages
  shizuku_exec settings get system screen_brightness

EOF
}

# If run directly
case "${1:-}" in
    status) shizuku_status ;; 
    running) shizuku_running && echo "Running" || echo "Not running" ;;
    exec) shift; shizuku_exec "$@" ;;
    help|--help|-h) shizuku_help ;; 
    *) shizuku_status ;;
esac
