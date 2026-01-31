#!/data/data/com.termux/files/usr/bin/bash
#
# services.sh - Service Management Functions
# Ubuntu 26.04 Resolute on Termux Project
#

# Prevent double-sourcing
[[ -n "${_SERVICES_SH_LOADED:-}" ]] && return 0
_SERVICES_SH_LOADED=1

# ============================================================================
# SERVICE STATE
# ============================================================================

SERVICES_STATE_DIR="${HOME}/.local/state/ubuntu-services"
mkdir -p "${SERVICES_STATE_DIR}" 2>/dev/null || true

# ============================================================================
# PULSEAUDIO
# ============================================================================

pulseaudio_is_running() {
    pgrep -x pulseaudio &>/dev/null
}

pulseaudio_start() {
    if pulseaudio_is_running; then
        return 0
    fi
    
    pulseaudio --start \
        --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
        --exit-idle-time=-1 2>/dev/null
    
    sleep 1
    pulseaudio_is_running
}

pulseaudio_stop() {
    if pulseaudio_is_running; then
        pulseaudio --kill 2>/dev/null || pkill pulseaudio 2>/dev/null || true
    fi
}

pulseaudio_restart() {
    pulseaudio_stop
    sleep 1
    pulseaudio_start
}

# ============================================================================
# DBUS (for proot)
# ============================================================================

dbus_session_start() {
    local runtime_dir="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
    mkdir -p "${runtime_dir}" 2>/dev/null || true
    
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime_dir}/bus"
    
    if [[ ! -S "${runtime_dir}/bus" ]]; then
        dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --fork 2>/dev/null || true
    fi
}

# ============================================================================
# SERVICE GROUPS
# ============================================================================

# Start all services needed for desktop
start_desktop_services() {
    pulseaudio_start
    source "${UBUNTU_LIB_DIR}/display.sh" 2>/dev/null || true
    vnc_start "${1:-1}" "${2:-1920x1080}"
}

# Stop all services
stop_all_services() {
    source "${UBUNTU_LIB_DIR}/display.sh" 2>/dev/null || true
    vnc_stop "${1:-1}"
    pulseaudio_stop
}

# Get status of all services
get_services_status() {
    echo "Service Status"
    echo "=============="
    
    echo -n "PulseAudio: "
    pulseaudio_is_running && echo "Running" || echo "Stopped"
    
    echo -n "VNC :1: "
    source "${UBUNTU_LIB_DIR}/display.sh" 2>/dev/null || true
    vnc_is_running 1 && echo "Running" || echo "Stopped"
}

# ============================================================================
# EXPORT
# ============================================================================

export -f pulseaudio_is_running pulseaudio_start pulseaudio_stop pulseaudio_restart
export -f dbus_session_start
export -f start_desktop_services stop_all_services get_services_status
