#!/data/data/com.termux/files/usr/bin/bash
#
# display.sh - Display Management Functions
# Ubuntu 26.04 Resolute on Termux Project
#

# Prevent double-sourcing
[[ -n "${_DISPLAY_SH_LOADED:-}" ]] && return 0
_DISPLAY_SH_LOADED=1

# Source dependencies
UBUNTU_LIB_DIR="${UBUNTU_LIB_DIR:-${HOME}/ubuntu/lib}"
source "${UBUNTU_LIB_DIR}/colors.sh" 2>/dev/null || true

# ============================================================================
# DISPLAY CONFIGURATION
# ============================================================================

# Default display settings
DEFAULT_VNC_DISPLAY=1
DEFAULT_VNC_GEOMETRY="1920x1080"
DEFAULT_VNC_DEPTH=24
DEFAULT_VNC_PORT_BASE=5900

# ============================================================================
# VNC FUNCTIONS
# ============================================================================

# Get VNC port from display number
vnc_port_from_display() {
    local display="${1:-1}"
    echo $((DEFAULT_VNC_PORT_BASE + display))
}

# Check if VNC is running on a display
vnc_is_running() {
    local display="${1:-1}"
    pgrep -f "Xvnc.*:${display}" &>/dev/null
}

# Get VNC PID for a display
vnc_get_pid() {
    local display="${1:-1}"
    pgrep -f "Xvnc.*:${display}" | head -1
}

# Start VNC server
vnc_start() {
    local display="${1:-${DEFAULT_VNC_DISPLAY}}"
    local geometry="${2:-${DEFAULT_VNC_GEOMETRY}}"
    local depth="${3:-${DEFAULT_VNC_DEPTH}}"
    
    # Stop existing if running
    vnc_stop "${display}" 2>/dev/null || true
    
    # Clean stale locks
    rm -f "/tmp/.X${display}-lock" 2>/dev/null || true
    rm -f "/tmp/.X11-unix/X${display}" 2>/dev/null || true
    
    # Start VNC
    if vncserver -localhost no -geometry "${geometry}" -depth "${depth}" ":${display}" 2>/dev/null; then
        sleep 1
        if vnc_is_running "${display}"; then
            return 0
        fi
    fi
    return 1
}

# Stop VNC server
vnc_stop() {
    local display="${1:-${DEFAULT_VNC_DISPLAY}}"
    
    if vnc_is_running "${display}"; then
        vncserver -kill ":${display}" 2>/dev/null || true
        sleep 1
    fi
    
    # Force kill if still running
    if vnc_is_running "${display}"; then
        kill "$(vnc_get_pid "${display}")" 2>/dev/null || true
    fi
}

# Get VNC connection info
vnc_get_info() {
    local display="${1:-1}"
    local ip
    ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "localhost")
    local port
    port=$(vnc_port_from_display "${display}")
    
    echo "Display: :${display}"
    echo "Address: ${ip}:${port}"
    echo "Running: $(vnc_is_running "${display}" && echo "Yes" || echo "No")"
}

# ============================================================================
# RESOLUTION FUNCTIONS
# ============================================================================

# Common resolutions
declare -A RESOLUTIONS=(
    ["720p"]="1280x720"
    ["1080p"]="1920x1080"
    ["1440p"]="2560x1440"
    ["4k"]="3840x2160"
    ["phone"]="1080x2340"
    ["tablet"]="1600x2560"
)

# Get resolution by name or return as-is
resolve_resolution() {
    local input="$1"
    local lower="${input,,}"
    
    if [[ -n "${RESOLUTIONS[${lower}]:-}" ]]; then
        echo "${RESOLUTIONS[${lower}]}"
    else
        echo "${input}"
    fi
}

# Get optimal resolution for screen
get_optimal_resolution() {
    local target="${1:-tv}"
    
    case "${target}" in
        tv|chromecast)
            echo "1920x1080"
            ;;
        monitor)
            echo "2560x1440"
            ;;
        phone|portable)
            echo "1280x720"
            ;;
        4k)
            echo "3840x2160"
            ;;
        *)
            echo "1920x1080"
            ;;
    esac
}

# ============================================================================
# DISPLAY ENVIRONMENT
# ============================================================================

# Set up display environment variables
setup_display_env() {
    local display="${1:-1}"
    
    export DISPLAY=":${display}"
    export XDG_SESSION_TYPE="x11"
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
    
    mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null || true
    chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true
}

# ============================================================================
# MIRACAST/CAST FUNCTIONS
# ============================================================================

# Check if casting is possible
can_cast() {
    # Check for required tools
    command -v termux-info &>/dev/null
}

# Get local IP for casting
get_cast_ip() {
    ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "127.0.0.1"
}

# ============================================================================
# EXPORT
# ============================================================================

export DEFAULT_VNC_DISPLAY DEFAULT_VNC_GEOMETRY DEFAULT_VNC_DEPTH DEFAULT_VNC_PORT_BASE
export -f vnc_port_from_display vnc_is_running vnc_get_pid vnc_start vnc_stop vnc_get_info
export -f resolve_resolution get_optimal_resolution
export -f setup_display_env
export -f can_cast get_cast_ip
