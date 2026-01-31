#!/data/data/com.termux/files/usr/bin/bash
#
# 10-tasker-automation.sh
# Complete Termux:Tasker Automation Setup for Ubuntu on Termux
#
# This script creates:
# - 27 Tasker scripts
# - 11 Home screen widgets
# - Complete documentation
# - Bash aliases
#
# Version: 1.0.0
#

set -euo pipefail

# ============================================================================
# INITIALIZATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${UBUNTU_PROJECT_ROOT}/lib/colors.sh" 2>/dev/null || {
    COLOR_RESET=""
    COLOR_GREEN=""
    COLOR_CYAN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_BOLD=""
}

source "${UBUNTU_PROJECT_ROOT}/lib/functions.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[OK] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_section() { echo ""; echo "=== $* ==="; echo ""; }
    ensure_dir() { mkdir -p "$1" 2>/dev/null || true; }
    print_header() { echo ""; echo "=== $1 v$2 ==="; echo ""; }
    print_footer() { echo ""; echo "=== $2 ==="; echo ""; }
}

SCRIPT_NAME="Tasker Automation Setup"
SCRIPT_VERSION="1.0.0"

UBUNTU_LOGS="${UBUNTU_PROJECT_ROOT}/logs"
TASKER_DIR="${HOME}/.termux/tasker"
SHORTCUTS_DIR="${HOME}/.shortcuts"
TASKER_LOG_DIR="${UBUNTU_PROJECT_ROOT}/logs/tasker"
DOCS_DIR="${UBUNTU_PROJECT_ROOT}/docs"
CONFIG_DIR="${UBUNTU_PROJECT_ROOT}/config"

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

setup_directories() {
    log_section "Setting Up Directories"
    
    ensure_dir "${TASKER_DIR}"
    ensure_dir "${SHORTCUTS_DIR}"
    ensure_dir "${TASKER_LOG_DIR}"
    ensure_dir "${DOCS_DIR}"
    ensure_dir "${CONFIG_DIR}"
    ensure_dir "${UBUNTU_LOGS}"
    
    log_success "Directories created"
    log_info "  Tasker: ${TASKER_DIR}"
    log_info "  Widgets: ${SHORTCUTS_DIR}"
    log_info "  Logs: ${TASKER_LOG_DIR}"
}

# ============================================================================
# MODE SCRIPT: DOCKED (2560x1440)
# ============================================================================

create_docked_mode() {
    cat > "${TASKER_DIR}/docked-mode.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Configuration
UBUNTU_HOME="${HOME}/ubuntu"
LOG_DIR="${UBUNTU_HOME}/logs/tasker"
LOG_FILE="${LOG_DIR}/docked-mode.log"
MODE_FILE="${LOG_DIR}/.current_mode"
PREV_MODE_FILE="${LOG_DIR}/.previous_mode"
RESOLUTION="2560x1440"
COLOR_DEPTH=24
VNC_DISPLAY=1
VNC_NAME="Ubuntu-Docked"

# Initialize
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DOCKED] $*"
}

notify() {
    local title="${1:-Ubuntu}"
    local message="${2:-}"
    local priority="${3:-high}"
    termux-notification \
        --title "${title}" \
        --content "${message}" \
        --id "ubuntu-mode" \
        --priority "${priority}" \
        --led-color "00FF00" \
        2>/dev/null || true
}

get_ip() {
    ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "localhost"
}

vnc_kill() {
    log "Stopping existing VNC..."
    vncserver -kill ":${VNC_DISPLAY}" 2>/dev/null || true
    sleep 1
    pkill -f "Xvnc.*:${VNC_DISPLAY}" 2>/dev/null || true
    rm -f "/tmp/.X${VNC_DISPLAY}-lock" 2>/dev/null || true
    rm -f "/tmp/.X11-unix/X${VNC_DISPLAY}" 2>/dev/null || true
}

vnc_start() {
    log "Starting VNC at ${RESOLUTION}..."
    if vncserver -localhost no -geometry "${RESOLUTION}" -depth "${COLOR_DEPTH}" -name "${VNC_NAME}" ":${VNC_DISPLAY}" 2>&1; then
        sleep 2
        if pgrep -f "Xvnc.*:${VNC_DISPLAY}" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

start_audio() {
    if ! pgrep -x pulseaudio &>/dev/null; then
        log "Starting PulseAudio..."
        pulseaudio --start \
            --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
            --exit-idle-time=-1 2>/dev/null || true
    fi
}

# Main
log "========================================"
log "DOCKED MODE ACTIVATION"
log "========================================"
log "Device: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"

notify "Ubuntu Docked Mode" "Initializing high-resolution display..."

# Save previous mode
if [[ -f "${MODE_FILE}" ]]; then
    cp "${MODE_FILE}" "${PREV_MODE_FILE}" 2>/dev/null || true
fi
echo "docked" > "${MODE_FILE}"

vnc_kill
start_audio

if vnc_start; then
    IP=$(get_ip)
    PORT=$((5900 + VNC_DISPLAY))
    log "========================================"
    log "DOCKED MODE READY"
    log "Resolution: ${RESOLUTION}"
    log "VNC: ${IP}:${PORT}"
    log "========================================"
    notify "Ubuntu Docked Mode" "Ready! VNC: ${IP}:${PORT}"
    exit 0
else
    log "ERROR: VNC failed to start"
    notify "Ubuntu Docked Mode" "ERROR: VNC failed"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/docked-mode.sh"
}

# ============================================================================
# MODE SCRIPT: TV (1920x1080)
# ============================================================================

create_tv_mode() {
    cat > "${TASKER_DIR}/tv-mode.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Configuration
UBUNTU_HOME="${HOME}/ubuntu"
LOG_DIR="${UBUNTU_HOME}/logs/tasker"
LOG_FILE="${LOG_DIR}/tv-mode.log"
MODE_FILE="${LOG_DIR}/.current_mode"
PREV_MODE_FILE="${LOG_DIR}/.previous_mode"
RESOLUTION="1920x1080"
COLOR_DEPTH=24
VNC_DISPLAY=1
VNC_NAME="Ubuntu-TV"

# Initialize
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TV] $*"
}

notify() {
    local title="${1:-Ubuntu}"
    local message="${2:-}"
    local priority="${3:-high}"
    termux-notification \
        --title "${title}" \
        --content "${message}" \
        --id "ubuntu-mode" \
        --priority "${priority}" \
        --led-color "0000FF" \
        2>/dev/null || true
}

get_ip() {
    ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "localhost"
}

vnc_kill() {
    log "Stopping existing VNC..."
    vncserver -kill ":${VNC_DISPLAY}" 2>/dev/null || true
    sleep 1
    pkill -f "Xvnc.*:${VNC_DISPLAY}" 2>/dev/null || true
    rm -f "/tmp/.X${VNC_DISPLAY}-lock" 2>/dev/null || true
    rm -f "/tmp/.X11-unix/X${VNC_DISPLAY}" 2>/dev/null || true
}

vnc_start() {
    log "Starting VNC at ${RESOLUTION}..."
    if vncserver -localhost no -geometry "${RESOLUTION}" -depth "${COLOR_DEPTH}" -name "${VNC_NAME}" ":${VNC_DISPLAY}" 2>&1; then
        sleep 2
        if pgrep -f "Xvnc.*:${VNC_DISPLAY}" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

start_audio() {
    if ! pgrep -x pulseaudio &>/dev/null; then
        log "Starting PulseAudio..."
        pulseaudio --start \
            --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
            --exit-idle-time=-1 2>/dev/null || true
    fi
}

show_instructions() {
    cat << 'INSTRUCTIONS'

╔══════════════════════════════════════════════════════════════════╗
║                        TV MODE ACTIVE                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  To display Ubuntu on your TV:                                   ║
║                                                                  ║
║  STEP 1: Cast your screen                                        ║
║    • Swipe down for Quick Settings                               ║
║    • Tap "Screen Cast" or "Smart View"                           ║
║    • Select your Chromecast or TV                                ║
║                                                                  ║
║  STEP 2: Connect VNC viewer                                      ║
║    • Open any VNC viewer app on your phone                       ║
║    • Connect to: localhost:5901                                  ║
║                                                                  ║
║  STEP 3: Enjoy!                                                  ║
║    • The Ubuntu desktop will appear on your TV                   ║
║    • Use your phone as a touchpad                                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

INSTRUCTIONS
}

# Main
log "========================================"
log "TV MODE ACTIVATION"
log "========================================"
log "Device: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"

notify "Ubuntu TV Mode" "Preparing for TV display..."

# Save previous mode
if [[ -f "${MODE_FILE}" ]]; then
    cp "${MODE_FILE}" "${PREV_MODE_FILE}" 2>/dev/null || true
fi
echo "tv" > "${MODE_FILE}"

vnc_kill
start_audio

if vnc_start; then
    IP=$(get_ip)
    PORT=$((5900 + VNC_DISPLAY))
    log "========================================"
    log "TV MODE READY"
    log "Resolution: ${RESOLUTION}"
    log "VNC: ${IP}:${PORT}"
    log "========================================"
    notify "Ubuntu TV Mode" "Ready! Cast screen, then VNC to localhost:${PORT}"
    show_instructions
    exit 0
else
    log "ERROR: VNC failed to start"
    notify "Ubuntu TV Mode" "ERROR: VNC failed"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/tv-mode.sh"
}

# ============================================================================
# MODE SCRIPT: PORTABLE (1280x720)
# ============================================================================

create_portable_mode() {
    cat > "${TASKER_DIR}/portable-mode.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Configuration
UBUNTU_HOME="${HOME}/ubuntu"
LOG_DIR="${UBUNTU_HOME}/logs/tasker"
LOG_FILE="${LOG_DIR}/portable-mode.log"
MODE_FILE="${LOG_DIR}/.current_mode"
PREV_MODE_FILE="${LOG_DIR}/.previous_mode"
RESOLUTION="1280x720"
COLOR_DEPTH=24
VNC_DISPLAY=1
VNC_NAME="Ubuntu-Portable"

# Initialize
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PORTABLE] $*"
}

notify() {
    local title="${1:-Ubuntu}"
    local message="${2:-}"
    termux-notification \
        --title "${title}" \
        --content "${message}" \
        --id "ubuntu-mode" \
        --priority "default" \
        --led-color "FFFF00" \
        2>/dev/null || true
}

vnc_kill() {
    log "Stopping existing VNC..."
    vncserver -kill ":${VNC_DISPLAY}" 2>/dev/null || true
    sleep 1
    pkill -f "Xvnc.*:${VNC_DISPLAY}" 2>/dev/null || true
    rm -f "/tmp/.X${VNC_DISPLAY}-lock" 2>/dev/null || true
    rm -f "/tmp/.X11-unix/X${VNC_DISPLAY}" 2>/dev/null || true
}

vnc_start() {
    log "Starting VNC at ${RESOLUTION} (battery-saving)..."
    if vncserver -localhost no -geometry "${RESOLUTION}" -depth "${COLOR_DEPTH}" -name "${VNC_NAME}" ":${VNC_DISPLAY}" 2>&1; then
        sleep 2
        if pgrep -f "Xvnc.*:${VNC_DISPLAY}" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Main
log "========================================"
log "PORTABLE MODE ACTIVATION"
log "========================================"

notify "Ubuntu Portable Mode" "Switching to battery-saving mode..."

# Save previous mode
if [[ -f "${MODE_FILE}" ]]; then
    cp "${MODE_FILE}" "${PREV_MODE_FILE}" 2>/dev/null || true
fi
echo "portable" > "${MODE_FILE}"

vnc_kill

if vnc_start; then
    log "========================================"
    log "PORTABLE MODE READY"
    log "Resolution: ${RESOLUTION}"
    log "========================================"
    notify "Ubuntu Portable Mode" "Ready at ${RESOLUTION}"
    exit 0
else
    log "ERROR: VNC failed to start"
    notify "Ubuntu Portable Mode" "ERROR: VNC failed"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/portable-mode.sh"
}

# ============================================================================
# ACTION SCRIPT: START UBUNTU SHELL
# ============================================================================

create_start_ubuntu() {
    cat > "${TASKER_DIR}/start-ubuntu.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# start-ubuntu.sh - Quick start Ubuntu shell
#

termux-notification \
    --title "Ubuntu" \
    --content "Starting Ubuntu shell..." \
    --id "ubuntu-start" \
    2>/dev/null || true

exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --shell
SCRIPTEOF
    chmod +x "${TASKER_DIR}/start-ubuntu.sh"
}

# ============================================================================
# ACTION SCRIPT: START KDE
# ============================================================================

create_start_kde() {
    cat > "${TASKER_DIR}/start-ubuntu-kde.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# start-ubuntu-kde.sh - Quick start KDE Plasma desktop
#

termux-notification \
    --title "Ubuntu" \
    --content "Starting KDE Plasma desktop..." \
    --id "ubuntu-start" \
    2>/dev/null || true

exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --kde
SCRIPTEOF
    chmod +x "${TASKER_DIR}/start-ubuntu-kde.sh"
}

# ============================================================================
# ACTION SCRIPT: STOP UBUNTU
# ============================================================================

create_stop_ubuntu() {
    cat > "${TASKER_DIR}/stop-ubuntu.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Configuration
LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/stop-ubuntu.log"
MODE_FILE="${LOG_DIR}/.current_mode"

mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

notify() {
    termux-notification \
        --title "Ubuntu" \
        --content "$1" \
        --id "ubuntu-stop" \
        2>/dev/null || true
}

log "========================================"
log "STOPPING UBUNTU SERVICES"
log "========================================"

notify "Stopping Ubuntu services..."

# Stop PRoot processes
if pgrep -f "proot.*ubuntu" &>/dev/null; then
    log "Stopping PRoot processes..."
    pkill -f "proot.*ubuntu" 2>/dev/null || true
    sleep 1
    pkill -9 -f "proot.*ubuntu" 2>/dev/null || true
    log "PRoot stopped"
else
    log "No PRoot processes running"
fi

# Stop VNC
if pgrep -f "Xvnc" &>/dev/null; then
    log "Stopping VNC server..."
    vncserver -kill :1 2>/dev/null || true
    sleep 1
    pkill -f "Xvnc" 2>/dev/null || true
    log "VNC stopped"
else
    log "VNC not running"
fi

# Clear mode file
rm -f "${MODE_FILE}" 2>/dev/null || true

log "All services stopped"
log "========================================"

notify "All Ubuntu services stopped"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/stop-ubuntu.sh"
}

# ============================================================================
# ACTION SCRIPT: UPDATE UBUNTU
# ============================================================================

create_update_ubuntu() {
    cat > "${TASKER_DIR}/update-ubuntu.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/update-ubuntu.log"
mkdir -p "${LOG_DIR}"

notify() {
    termux-notification \
        --title "Ubuntu Update" \
        --content "$1" \
        --id "ubuntu-update" \
        2>/dev/null || true
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

log "========================================"
log "UBUNTU UPDATE STARTED"
log "========================================"

notify "Updating Ubuntu packages..."

"${HOME}/ubuntu/scripts/launch-ubuntu.sh" -c "
    echo 'Updating package lists...'
    apt-get update -y
    
    echo ''
    echo 'Upgrading packages...'
    apt-get upgrade -y
    
    echo ''
    echo 'Removing unused packages...'
    apt-get autoremove -y
    
    echo ''
    echo 'Cleaning package cache...'
    apt-get clean
    
    echo ''
    echo 'Update complete!'
" 2>&1 | tee -a "${LOG_FILE}"

log "========================================"
log "UPDATE COMPLETE"
log "========================================"

notify "Update complete!"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/update-ubuntu.sh"
}

# ============================================================================
# ACTION SCRIPT: STATUS
# ============================================================================

create_status_ubuntu() {
    cat > "${TASKER_DIR}/status-ubuntu.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# status-ubuntu.sh - Show Ubuntu status
#

# Check services
VNC_STATUS="⏹ Stopped"
pgrep -f "Xvnc" &>/dev/null && VNC_STATUS="▶ Running"

PULSE_STATUS="⏹ Stopped"
pgrep -x pulseaudio &>/dev/null && PULSE_STATUS="▶ Running"

PROOT_STATUS="⏹ Stopped"
pgrep -f "proot.*ubuntu" &>/dev/null && PROOT_STATUS="▶ Running"

# Get current mode
MODE_FILE="${HOME}/ubuntu/logs/tasker/.current_mode"
if [[ -f "${MODE_FILE}" ]]; then
    CURRENT_MODE=$(cat "${MODE_FILE}")
else
    CURRENT_MODE="none"
fi

# Get IP
IP_ADDR=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "N/A")

# Build status
STATUS_LINE1="Mode: ${CURRENT_MODE} | IP: ${IP_ADDR}"
STATUS_LINE2="VNC: ${VNC_STATUS}"

# Show notification
termux-notification \
    --title "Ubuntu Status" \
    --content "${STATUS_LINE1}
${STATUS_LINE2}" \
    --id "ubuntu-status" \
    --priority "low" \
    2>/dev/null || true

# Print to terminal
echo ""
echo "Ubuntu Status"
echo "============="
echo "Mode:   ${CURRENT_MODE}"
echo "IP:     ${IP_ADDR}"
echo ""
echo "Services:"
echo "  VNC:    ${VNC_STATUS}"
echo "  Audio:  ${PULSE_STATUS}"
echo "  PRoot:  ${PROOT_STATUS}"
echo ""
SCRIPTEOF
    chmod +x "${TASKER_DIR}/status-ubuntu.sh"
}

# ============================================================================
# EVENT HANDLER: WIFI CONNECTED
# ============================================================================

create_wifi_handler() {
    cat > "${TASKER_DIR}/wifi-connected.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

#
# wifi-connected.sh - Handle WiFi connection events
#
# Usage from Tasker:
#   Script: wifi-connected.sh
#   Arguments: %WIFII
#

SSID="${1:-}"
LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/wifi.log"
mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WIFI] $*" >> "${LOG_FILE}"
}

log "WiFi connected: ${SSID}"

# ============================================================================
# CONFIGURE YOUR TV NETWORKS HERE
# ============================================================================
TV_NETWORKS=(
    "Living Room"
    "TV_Network"
    "Chromecast"
    "Home_5G"
    "SmartTV"
    "Family Room"
)
# ============================================================================

for network in "${TV_NETWORKS[@]}"; do
    if [[ "${SSID}" == *"${network}"* ]]; then
        log "TV network detected: ${network}"
        log "Switching to TV mode..."
        exec "${HOME}/.termux/tasker/tv-mode.sh"
    fi
done

log "Regular network, no mode change"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/wifi-connected.sh"
}

# ============================================================================
# EVENT HANDLER: USB CONNECTED
# ============================================================================

create_usb_connected() {
    cat > "${TASKER_DIR}/usb-connected.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# usb-connected.sh - Handle USB connection events
#
# Triggered by Tasker when USB device is connected
# Switches to docked mode for high-resolution display
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/usb.log"
mkdir -p "${LOG_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [USB] Connected" >> "${LOG_FILE}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [USB] Switching to docked mode" >> "${LOG_FILE}"

exec "${HOME}/.termux/tasker/docked-mode.sh"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/usb-connected.sh"
}

# ============================================================================
# EVENT HANDLER: USB DISCONNECTED
# ============================================================================

create_usb_disconnected() {
    cat > "${TASKER_DIR}/usb-disconnected.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# usb-disconnected.sh - Handle USB disconnection events
#
# Triggered by Tasker when USB device is disconnected
# Switches back to portable (battery-saving) mode
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/usb.log"
mkdir -p "${LOG_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [USB] Disconnected" >> "${LOG_FILE}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [USB] Switching to portable mode" >> "${LOG_FILE}"

exec "${HOME}/.termux/tasker/portable-mode.sh"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/usb-disconnected.sh"
}

# ============================================================================
# EVENT HANDLER: BOOT COMPLETE
# ============================================================================

create_boot_handler() {
    cat > "${TASKER_DIR}/boot-complete.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

#
# boot-complete.sh - Handle device boot completion
#
# Triggered by Tasker after device boots
# Initializes Ubuntu services if auto-start is enabled
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/boot.log"
mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BOOT] $*" | tee -a "${LOG_FILE}"
}

notify() {
    termux-notification \
        --title "Ubuntu" \
        --content "$1" \
        --id "ubuntu-boot" \
        --priority "low" \
        2>/dev/null || true
}

log "========================================"
log "DEVICE BOOT DETECTED"
log "========================================"
log "Device: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
log "Android: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"

# Wait for system to stabilize
log "Waiting for system to stabilize..."
sleep 5

# Check auto-start setting
AUTO_START_FILE="${HOME}/ubuntu/config/.auto_start"
if [[ -f "${AUTO_START_FILE}" ]] && [[ "$(cat "${AUTO_START_FILE}")" == "true" ]]; then
    log "Auto-start enabled, initializing portable mode..."
    notify "Ubuntu starting in portable mode..."
    exec "${HOME}/.termux/tasker/portable-mode.sh"
else
    log "Auto-start disabled"
    notify "Ubuntu ready (auto-start disabled)"
fi

log "Boot handler complete"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/boot-complete.sh"
}

# ============================================================================
# EVENT HANDLER: BATTERY LOW
# ============================================================================

create_battery_low_handler() {
    cat > "${TASKER_DIR}/battery-low.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

#
# battery-low.sh - Handle low battery event
#
# Triggered by Tasker when battery falls below threshold
# Switches to portable mode to save battery
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/battery.log"
MODE_FILE="${LOG_DIR}/.current_mode"
PREV_MODE_FILE="${LOG_DIR}/.previous_mode"
mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BATTERY] $*" | tee -a "${LOG_FILE}"
}

notify() {
    termux-notification \
        --title "Ubuntu - Low Battery" \
        --content "$1" \
        --id "ubuntu-battery" \
        --priority "high" \
        2>/dev/null || true
}

log "Low battery detected"

# Save current mode before switching
if [[ -f "${MODE_FILE}" ]]; then
    CURRENT=$(cat "${MODE_FILE}")
    cp "${MODE_FILE}" "${PREV_MODE_FILE}"
    log "Saved current mode: ${CURRENT}"
else
    CURRENT="none"
fi

# Switch to portable if not already
if [[ "${CURRENT}" != "portable" ]]; then
    notify "Switching to battery-saving mode..."
    log "Switching to portable mode"
    exec "${HOME}/.termux/tasker/portable-mode.sh"
else
    log "Already in portable mode"
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/battery-low.sh"
}

# ============================================================================
# EVENT HANDLER: CHARGING
# ============================================================================

create_charging_handler() {
    cat > "${TASKER_DIR}/charging.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

#
# charging.sh - Handle charging start event
#
# Triggered by Tasker when charging begins
# Restores previous mode if it was saved
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/battery.log"
PREV_MODE_FILE="${LOG_DIR}/.previous_mode"
mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CHARGING] $*" | tee -a "${LOG_FILE}"
}

log "Charging started"

# Restore previous mode if saved
if [[ -f "${PREV_MODE_FILE}" ]]; then
    PREV=$(cat "${PREV_MODE_FILE}")
    log "Restoring previous mode: ${PREV}"
    rm -f "${PREV_MODE_FILE}"
    
    case "${PREV}" in
        docked)
            exec "${HOME}/.termux/tasker/docked-mode.sh"
            ;;
        tv)
            exec "${HOME}/.termux/tasker/tv-mode.sh"
            ;;
        *)
            log "Previous mode was portable or unknown, no change"
            ;;
    esac
else
    log "No previous mode saved"
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/charging.sh"
}

# ============================================================================
# EVENT HANDLER: SCREEN OFF
# ============================================================================

create_screen_off_handler() {
    cat > "${TASKER_DIR}/screen-off.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# screen-off.sh - Handle screen off event
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/screen.log"
mkdir -p "${LOG_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCREEN] OFF" >> "${LOG_FILE}"

# Optional: Reduce resources when screen is off
# Uncomment to switch to portable mode:
# "${HOME}/.termux/tasker/portable-mode.sh" >> "${LOG_FILE}" 2>&1
SCRIPTEOF
    chmod +x "${TASKER_DIR}/screen-off.sh"
}

# ============================================================================
# EVENT HANDLER: SCREEN ON
# ============================================================================

create_screen_on_handler() {
    cat > "${TASKER_DIR}/screen-on.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# screen-on.sh - Handle screen on event
#

LOG_DIR="${HOME}/ubuntu/logs/tasker"
LOG_FILE="${LOG_DIR}/screen.log"
PREV_MODE_FILE="${LOG_DIR}/.screen_mode"
mkdir -p "${LOG_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCREEN] ON" >> "${LOG_FILE}"

# Optional: Restore previous mode when screen turns on
# if [[ -f "${PREV_MODE_FILE}" ]]; then
#     MODE=$(cat "${PREV_MODE_FILE}")
#     "${HOME}/.termux/tasker/${MODE}-mode.sh" >> "${LOG_FILE}" 2>&1
# fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/screen-on.sh"
}

# ============================================================================
# UTILITY SCRIPT: TOGGLE MODE
# ============================================================================

create_toggle_mode() {
    cat > "${TASKER_DIR}/toggle-mode.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# toggle-mode.sh - Cycle through display modes
#
# Cycles: portable → tv → docked → portable
#

MODE_FILE="${HOME}/ubuntu/logs/tasker/.current_mode"
mkdir -p "$(dirname "${MODE_FILE}")"

# Get current mode
if [[ -f "${MODE_FILE}" ]]; then
    CURRENT=$(cat "${MODE_FILE}")
else
    CURRENT="portable"
fi

# Determine next mode
case "${CURRENT}" in
    portable) NEXT="tv" ;;
    tv) NEXT="docked" ;;
    docked) NEXT="portable" ;;
    *) NEXT="portable" ;;
esac

echo "Switching: ${CURRENT} → ${NEXT}"
exec "${HOME}/.termux/tasker/${NEXT}-mode.sh"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/toggle-mode.sh"
}

# ============================================================================
# UTILITY SCRIPT: SET MODE
# ============================================================================

create_set_mode() {
    cat > "${TASKER_DIR}/set-mode.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# set-mode.sh - Set display mode by name
#
# Usage: set-mode.sh <mode>
# Modes: portable, tv, docked
#

MODE="${1:-}"

if [[ -z "${MODE}" ]]; then
    echo "Usage: $(basename "$0") <mode>"
    echo ""
    echo "Modes:"
    echo "  portable, 720p, battery  - Battery saving (1280x720)"
    echo "  tv, 1080p, cast          - TV/Chromecast (1920x1080)"
    echo "  docked, 1440p, dock      - Docked/Monitor (2560x1440)"
    exit 1
fi

case "${MODE}" in
    portable|720p|battery)
        exec "${HOME}/.termux/tasker/portable-mode.sh"
        ;;
    tv|1080p|cast)
        exec "${HOME}/.termux/tasker/tv-mode.sh"
        ;;
    docked|1440p|dock)
        exec "${HOME}/.termux/tasker/docked-mode.sh"
        ;;
    *)
        echo "Unknown mode: ${MODE}"
        echo "Valid modes: portable, tv, docked"
        exit 1
        ;;
esac
SCRIPTEOF
    chmod +x "${TASKER_DIR}/set-mode.sh"
}

# ============================================================================
# UTILITY SCRIPT: GET MODE
# ============================================================================

create_get_mode() {
    cat > "${TASKER_DIR}/get-mode.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# get-mode.sh - Get current display mode
#

MODE_FILE="${HOME}/ubuntu/logs/tasker/.current_mode"

if [[ -f "${MODE_FILE}" ]]; then
    cat "${MODE_FILE}"
else
    echo "none"
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/get-mode.sh"
}

# ============================================================================
# UTILITY SCRIPT: NOTIFY
# ============================================================================

create_notify_helper() {
    cat > "${TASKER_DIR}/ubuntu-notify.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# ubuntu-notify.sh - Send notification
#
# Usage: ubuntu-notify.sh "Title" "Message" [priority] [id]
#
# Priority: min, low, default, high, max
#

TITLE="${1:-Ubuntu}"
MESSAGE="${2:-}"
PRIORITY="${3:-default}"
NOTIF_ID="${4:-ubuntu-notify}"

if [[ -z "${MESSAGE}" ]]; then
    echo "Usage: $(basename "$0") \"Title\" \"Message\" [priority] [id]"
    echo ""
    echo "Priority: min, low, default, high, max"
    echo "ID: Unique identifier to update existing notification"
    exit 1
fi

if command -v termux-notification &>/dev/null; then
    termux-notification \
        --title "${TITLE}" \
        --content "${MESSAGE}" \
        --id "${NOTIF_ID}" \
        --priority "${PRIORITY}" \
        2>/dev/null
    echo "Notification sent"
else
    echo "termux-notification not available"
    echo "Install with: pkg install termux-api"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/ubuntu-notify.sh"
}

# ============================================================================
# VNC CONTROL: START
# ============================================================================

create_vnc_start() {
    cat > "${TASKER_DIR}/vnc-start.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# vnc-start.sh - Start VNC server
#
# Usage: vnc-start.sh [resolution] [display]
#

RESOLUTION="${1:-1920x1080}"
DISPLAY="${2:-1}"

# Kill existing
vncserver -kill ":${DISPLAY}" 2>/dev/null || true
rm -f "/tmp/.X${DISPLAY}-lock" "/tmp/.X11-unix/X${DISPLAY}" 2>/dev/null || true
sleep 1

echo "Starting VNC on :${DISPLAY} at ${RESOLUTION}..."

if vncserver -localhost no -geometry "${RESOLUTION}" -depth 24 ":${DISPLAY}"; then
    IP=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "localhost")
    PORT=$((5900 + DISPLAY))
    
    echo ""
    echo "VNC Server Started"
    echo "  Display:    :${DISPLAY}"
    echo "  Address:    ${IP}:${PORT}"
    echo "  Resolution: ${RESOLUTION}"
else
    echo "Failed to start VNC"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/vnc-start.sh"
}

# ============================================================================
# VNC CONTROL: STOP
# ============================================================================

create_vnc_stop() {
    cat > "${TASKER_DIR}/vnc-stop.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# vnc-stop.sh - Stop VNC server
#
# Usage: vnc-stop.sh [display]
#

DISPLAY="${1:-1}"

echo "Stopping VNC on :${DISPLAY}..."

vncserver -kill ":${DISPLAY}" 2>/dev/null || true
pkill -f "Xvnc.*:${DISPLAY}" 2>/dev/null || true
rm -f "/tmp/.X${DISPLAY}-lock" "/tmp/.X11-unix/X${DISPLAY}" 2>/dev/null || true

echo "VNC stopped"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/vnc-stop.sh"
}

# ============================================================================
# VNC CONTROL: STATUS
# ============================================================================

create_vnc_status() {
    cat > "${TASKER_DIR}/vnc-status.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# vnc-status.sh - Check VNC status
#

if pgrep -f "Xvnc" &>/dev/null; then
    echo "VNC is running"
    echo ""
    pgrep -a -f "Xvnc" | head -3
    echo ""
    IP=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "localhost")
    echo "Connect to: ${IP}:5901"
    exit 0
else
    echo "VNC is not running"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/vnc-status.sh"
}

# ============================================================================
# AUDIO CONTROL: START
# ============================================================================

create_audio_start() {
    cat > "${TASKER_DIR}/audio-start.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# audio-start.sh - Start PulseAudio
#

if pgrep -x pulseaudio &>/dev/null; then
    echo "PulseAudio already running"
    exit 0
fi

echo "Starting PulseAudio..."

pulseaudio --start \
    --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
    --exit-idle-time=-1 \
    2>/dev/null

sleep 1

if pgrep -x pulseaudio &>/dev/null; then
    echo "PulseAudio started"
else
    echo "Failed to start PulseAudio"
    exit 1
fi
SCRIPTEOF
    chmod +x "${TASKER_DIR}/audio-start.sh"
}

# ============================================================================
# AUDIO CONTROL: STOP
# ============================================================================

create_audio_stop() {
    cat > "${TASKER_DIR}/audio-stop.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# audio-stop.sh - Stop PulseAudio
#

echo "Stopping PulseAudio..."
pulseaudio --kill 2>/dev/null || pkill pulseaudio 2>/dev/null || true
echo "PulseAudio stopped"
SCRIPTEOF
    chmod +x "${TASKER_DIR}/audio-stop.sh"
}

# ============================================================================
# CONFIG: AUTOSTART ENABLE
# ============================================================================

create_autostart_enable() {
    cat > "${TASKER_DIR}/autostart-enable.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# autostart-enable.sh - Enable auto-start on boot
#

CONFIG_FILE="${HOME}/ubuntu/config/.auto_start"
mkdir -p "$(dirname "${CONFIG_FILE}")"

echo "true" > "${CONFIG_FILE}"

echo "Auto-start enabled"
echo "Ubuntu will start automatically when device boots"

termux-notification \
    --title "Ubuntu" \
    --content "Auto-start enabled" \
    --id "ubuntu-config" \
    2>/dev/null || true
SCRIPTEOF
    chmod +x "${TASKER_DIR}/autostart-enable.sh"
}

# ============================================================================
# CONFIG: AUTOSTART DISABLE
# ============================================================================

create_autostart_disable() {
    cat > "${TASKER_DIR}/autostart-disable.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# autostart-disable.sh - Disable auto-start on boot
#

CONFIG_FILE="${HOME}/ubuntu/config/.auto_start"
mkdir -p "$(dirname "${CONFIG_FILE}")"

echo "false" > "${CONFIG_FILE}"

echo "Auto-start disabled"
echo "Ubuntu will not start automatically on boot"

termux-notification \
    --title "Ubuntu" \
    --content "Auto-start disabled" \
    --id "ubuntu-config" \
    2>/dev/null || true
SCRIPTEOF
    chmod +x "${TASKER_DIR}/autostart-disable.sh"
}

# ============================================================================
# WIDGETS
# ============================================================================

create_widgets() {
    log_section "Creating Widget Scripts"
    
    # Widget: Ubuntu Shell
    cat > "${SHORTCUTS_DIR}/🐧 Ubuntu Shell" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --shell
EOF
    chmod +x "${SHORTCUTS_DIR}/🐧 Ubuntu Shell"
    
    # Widget: Ubuntu KDE
    cat > "${SHORTCUTS_DIR}/🖥️ Ubuntu KDE" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --kde
EOF
    chmod +x "${SHORTCUTS_DIR}/🖥️ Ubuntu KDE"
    
    # Widget: Cast to TV
    cat > "${SHORTCUTS_DIR}/📺 Cast to TV" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/tv-mode.sh"
echo ""
read -p "Press Enter to start KDE, or Ctrl+C to cancel..."
exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --kde
EOF
    chmod +x "${SHORTCUTS_DIR}/📺 Cast to TV"
    
    # Widget: Stop Ubuntu
    cat > "${SHORTCUTS_DIR}/⏹️ Stop Ubuntu" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/stop-ubuntu.sh"
echo ""
echo "Services stopped."
sleep 2
EOF
    chmod +x "${SHORTCUTS_DIR}/⏹️ Stop Ubuntu"
    
    # Widget: Ubuntu Status
    cat > "${SHORTCUTS_DIR}/ℹ️ Ubuntu Status" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/status-ubuntu.sh"
echo ""
read -p "Press Enter to close..."
EOF
    chmod +x "${SHORTCUTS_DIR}/ℹ️ Ubuntu Status"
    
    # Widget: Update Ubuntu
    cat > "${SHORTCUTS_DIR}/🔄 Update Ubuntu" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting update..."
"${HOME}/.termux/tasker/update-ubuntu.sh"
echo ""
read -p "Press Enter to close..."
EOF
    chmod +x "${SHORTCUTS_DIR}/🔄 Update Ubuntu"
    
    # Widget: Docked Mode
    cat > "${SHORTCUTS_DIR}/🔌 Docked Mode" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/docked-mode.sh"
EOF
    chmod +x "${SHORTCUTS_DIR}/🔌 Docked Mode"
    
    # Widget: Portable Mode
    cat > "${SHORTCUTS_DIR}/🔋 Portable Mode" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/portable-mode.sh"
EOF
    chmod +x "${SHORTCUTS_DIR}/🔋 Portable Mode"
    
    # Widget: Toggle Mode
    cat > "${SHORTCUTS_DIR}/🔄 Toggle Mode" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/toggle-mode.sh"
EOF
    chmod +x "${SHORTCUTS_DIR}/🔄 Toggle Mode"
    
    # Widget: Start VNC
    cat > "${SHORTCUTS_DIR}/▶️ Start VNC" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/vnc-start.sh" 1920x1080 1
echo ""
read -p "Press Enter to close..."
EOF
    chmod +x "${SHORTCUTS_DIR}/▶️ Start VNC"
    
    # Widget: Stop VNC
    cat > "${SHORTCUTS_DIR}/⏹️ Stop VNC" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"${HOME}/.termux/tasker/vnc-stop.sh"
sleep 1
EOF
    chmod +x "${SHORTCUTS_DIR}/⏹️ Stop VNC"
    
    log_success "11 widgets created"
}

# ============================================================================
# BASH ALIASES
# ============================================================================

create_bash_aliases() {
    log_section "Creating Bash Aliases"
    
    cat > "${CONFIG_DIR}/tasker-aliases.sh" << 'ALIASEOF'
# ============================================================================
# Tasker Automation Aliases
# Source: ~/ubuntu/config/tasker-aliases.sh
# ============================================================================

# Mode switching
alias mode-docked='~/.termux/tasker/docked-mode.sh'
alias mode-tv='~/.termux/tasker/tv-mode.sh'
alias mode-portable='~/.termux/tasker/portable-mode.sh'
alias mode-toggle='~/.termux/tasker/toggle-mode.sh'
alias mode-get='~/.termux/tasker/get-mode.sh'

mode-set() {
    ~/.termux/tasker/set-mode.sh "$1"
}

# VNC control
alias vnc-start='~/.termux/tasker/vnc-start.sh'
alias vnc-stop='~/.termux/tasker/vnc-stop.sh'
alias vnc-status='~/.termux/tasker/vnc-status.sh'
alias vnc-restart='vnc-stop; sleep 1; vnc-start'

# Audio control
alias audio-start='~/.termux/tasker/audio-start.sh'
alias audio-stop='~/.termux/tasker/audio-stop.sh'

# Ubuntu control
alias ubuntu-start='~/.termux/tasker/start-ubuntu.sh'
alias ubuntu-kde='~/.termux/tasker/start-ubuntu-kde.sh'
alias ubuntu-stop='~/.termux/tasker/stop-ubuntu.sh'
alias ubuntu-update='~/.termux/tasker/update-ubuntu.sh'
alias ubuntu-status='~/.termux/tasker/status-ubuntu.sh'

# Notifications
ubuntu-notify() {
    ~/.termux/tasker/ubuntu-notify.sh "$@"
}

# Auto-start
alias autostart-on='~/.termux/tasker/autostart-enable.sh'
alias autostart-off='~/.termux/tasker/autostart-disable.sh'

# Logs
alias tasker-logs='ls -la ~/ubuntu/logs/tasker/'
alias tasker-log='tail -f ~/ubuntu/logs/tasker/*.log'
alias tasker-mode-log='tail -f ~/ubuntu/logs/tasker/*-mode.log'
ALIASEOF

    # Add to .bashrc if not present
    local bashrc="${HOME}/.bashrc"
    local marker="# Tasker Automation Aliases"
    
    if ! grep -q "${marker}" "${bashrc}" 2>/dev/null; then
        cat >> "${bashrc}" << 'BASHRCEOF'

# Tasker Automation Aliases
if [[ -f "${HOME}/ubuntu/config/tasker-aliases.sh" ]]; then
    source "${HOME}/ubuntu/config/tasker-aliases.sh"
fi
BASHRCEOF
        log_info "Added aliases to .bashrc"
    else
        log_info "Aliases already in .bashrc"
    fi
    
    # Default auto-start to disabled
    echo "false" > "${CONFIG_DIR}/.auto_start"
    
    log_success "Bash aliases created"
}

# ============================================================================
# DOCUMENTATION
# ============================================================================

create_documentation() {
    log_section "Creating Documentation"
    
    cat > "${DOCS_DIR}/TASKER_SETUP.md" << 'DOCEOF'
# Termux:Tasker Integration Guide

## Prerequisites

| App | Source | Required |
|-----|--------|----------|
| Termux | F-Droid | Yes |
| Termux:API | F-Droid | Yes |
| Termux:Tasker | F-Droid | Yes |
| Termux:Widget | F-Droid | Recommended |
| Tasker | Play Store | Yes |

### Initial Setup

    pkg install termux-api

## Script Reference

### Mode Scripts (~/.termux/tasker/)

| Script | Resolution | Use Case |
|--------|------------|----------|
| docked-mode.sh | 2560x1440 | USB-C dock/hub |
| tv-mode.sh | 1920x1080 | Chromecast/TV |
| portable-mode.sh | 1280x720 | Battery saving |

### Action Scripts

| Script | Purpose |
|--------|---------|
| start-ubuntu.sh | Launch Ubuntu shell |
| start-ubuntu-kde.sh | Launch KDE Plasma |
| stop-ubuntu.sh | Stop all services |
| update-ubuntu.sh | Update packages |
| status-ubuntu.sh | Show status |

### Event Handlers

| Script | Trigger |
|--------|---------|
| wifi-connected.sh | WiFi connection |
| usb-connected.sh | USB connected |
| usb-disconnected.sh | USB removed |
| boot-complete.sh | Device boot |
| battery-low.sh | Battery below 20% |
| charging.sh | Charging started |
| screen-off.sh | Display off |
| screen-on.sh | Display on |

### Utility Scripts

| Script | Purpose |
|--------|---------|
| toggle-mode.sh | Cycle through modes |
| set-mode.sh | Set specific mode |
| get-mode.sh | Get current mode |
| ubuntu-notify.sh | Send notification |

### VNC and Audio Control

| Script | Purpose |
|--------|---------|
| vnc-start.sh | Start VNC server |
| vnc-stop.sh | Stop VNC server |
| vnc-status.sh | Check VNC status |
| audio-start.sh | Start PulseAudio |
| audio-stop.sh | Stop PulseAudio |

### Configuration

| Script | Purpose |
|--------|---------|
| autostart-enable.sh | Enable boot start |
| autostart-disable.sh | Disable boot start |

## Tasker Profile Setup

### Profile 1: Docked Mode (USB Connected)

1. Profile - State - Hardware - USB Connected
2. Task - Plugin - Termux:Tasker - docked-mode.sh
3. Exit Task - portable-mode.sh

### Profile 2: TV Mode (WiFi Network)

1. Profile - State - Net - Wifi Connected
2. SSID: Your TV network name
3. Task - tv-mode.sh

### Profile 3: Boot Complete

1. Profile - Event - System - Device Boot
2. Task - Wait 30s - boot-complete.sh

### Profile 4: Battery Saver

1. Profile - State - Power - Battery Level - 0-20
2. Task - battery-low.sh
3. Exit Task - charging.sh

## Widget Setup

1. Long-press home - Widgets
2. Select Termux:Widget
3. Choose script from ~/.shortcuts/

### Available Widgets

| Widget | Function |
|--------|----------|
| Ubuntu Shell | Start terminal |
| Ubuntu KDE | Start desktop |
| Cast to TV | TV mode + KDE |
| Stop Ubuntu | Stop services |
| Ubuntu Status | Show status |
| Update Ubuntu | Update system |
| Docked Mode | High-res mode |
| Portable Mode | Battery mode |
| Toggle Mode | Cycle modes |
| Start VNC | Start display |
| Stop VNC | Stop display |

## Customization

### Add TV Networks

Edit ~/.termux/tasker/wifi-connected.sh and add your networks:

    TV_NETWORKS=(
        "Your_Network_Name"
        "Another_Network"
    )

### Change Resolution

Edit mode scripts and modify RESOLUTION variable:

    RESOLUTION="3840x2160"  # 4K
    RESOLUTION="1920x1080"  # 1080p
    RESOLUTION="1280x720"   # 720p

### Auto-Start KDE in Docked Mode

Add to end of docked-mode.sh before exit:

    "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --kde &

## Bash Aliases

Reload with: source ~/.bashrc

| Alias | Command |
|-------|---------|
| mode-docked | Switch to docked |
| mode-tv | Switch to TV |
| mode-portable | Switch to portable |
| mode-toggle | Cycle modes |
| mode-get | Get current mode |
| vnc-start | Start VNC |
| vnc-stop | Stop VNC |
| vnc-status | VNC status |
| vnc-restart | Restart VNC |
| audio-start | Start audio |
| audio-stop | Stop audio |
| ubuntu-start | Start shell |
| ubuntu-kde | Start KDE |
| ubuntu-stop | Stop services |
| ubuntu-update | Update packages |
| ubuntu-status | Show status |
| autostart-on | Enable auto-start |
| autostart-off | Disable auto-start |
| tasker-logs | List logs |
| tasker-log | Follow logs |

## Troubleshooting

### Scripts Not Running

    chmod +x ~/.termux/tasker/*.sh

### No Notifications

    pkg install termux-api
    termux-notification --title "Test" --content "Hello"

### VNC Issues

    vncserver -kill :1
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
    vncserver -localhost no -geometry 1920x1080 :1

### Check Logs

    tail -f ~/ubuntu/logs/tasker/*.log
    cat ~/ubuntu/logs/tasker/.current_mode

## Appendix A: Complete Script List

### All 27 Tasker Scripts

| # | Script | Category | Purpose |
|---|--------|----------|---------|
| 1 | docked-mode.sh | Mode | 2560x1440 display |
| 2 | tv-mode.sh | Mode | 1920x1080 display |
| 3 | portable-mode.sh | Mode | 1280x720 display |
| 4 | start-ubuntu.sh | Action | Launch shell |
| 5 | start-ubuntu-kde.sh | Action | Launch KDE |
| 6 | stop-ubuntu.sh | Action | Stop services |
| 7 | update-ubuntu.sh | Action | Update packages |
| 8 | status-ubuntu.sh | Action | Show status |
| 9 | wifi-connected.sh | Event | WiFi handler |
| 10 | usb-connected.sh | Event | USB connect |
| 11 | usb-disconnected.sh | Event | USB disconnect |
| 12 | boot-complete.sh | Event | Boot handler |
| 13 | battery-low.sh | Event | Low battery |
| 14 | charging.sh | Event | Charging start |
| 15 | screen-off.sh | Event | Screen off |
| 16 | screen-on.sh | Event | Screen on |
| 17 | toggle-mode.sh | Utility | Cycle modes |
| 18 | set-mode.sh | Utility | Set mode |
| 19 | get-mode.sh | Utility | Get mode |
| 20 | ubuntu-notify.sh | Utility | Send notification |
| 21 | vnc-start.sh | Control | Start VNC |
| 22 | vnc-stop.sh | Control | Stop VNC |
| 23 | vnc-status.sh | Control | VNC status |
| 24 | audio-start.sh | Control | Start audio |
| 25 | audio-stop.sh | Control | Stop audio |
| 26 | autostart-enable.sh | Config | Enable boot start |
| 27 | autostart-disable.sh | Config | Disable boot start |

### All 11 Widget Scripts

| # | Widget | Function |
|---|--------|----------|
| 1 | Ubuntu Shell | Start terminal |
| 2 | Ubuntu KDE | Start desktop |
| 3 | Cast to TV | TV mode + KDE |
| 4 | Stop Ubuntu | Stop services |
| 5 | Ubuntu Status | Show status |
| 6 | Update Ubuntu | Update system |
| 7 | Docked Mode | High-res mode |
| 8 | Portable Mode | Battery mode |
| 9 | Toggle Mode | Cycle modes |
| 10 | Start VNC | Start display |
| 11 | Stop VNC | Stop display |

## Appendix B: Tasker Variables

| Variable | Description | Example |
|----------|-------------|---------|
| %WIFII | WiFi Info | MyNetwork 5GHz |
| %WIFI | WiFi Status | on or off |
| %BATT | Battery Level | 75 |
| %POWER | Power Source | ac usb wireless |
| %SCREEN | Screen State | on or off |
| %TIME | Current Time | 14:30 |

## Appendix C: Log Files

| Log File | Contents |
|----------|----------|
| docked-mode.log | Docked mode events |
| tv-mode.log | TV mode events |
| portable-mode.log | Portable mode events |
| stop-ubuntu.log | Stop events |
| update-ubuntu.log | Update operations |
| boot.log | Boot events |
| wifi.log | WiFi events |
| usb.log | USB events |
| battery.log | Battery events |
| screen.log | Screen events |
| .current_mode | Current mode state |
| .previous_mode | Previous mode state |

## Appendix D: Resolution Reference

| Name | Resolution | Pixels | Use Case |
|------|------------|--------|----------|
| 720p | 1280x720 | 0.9M | Battery saving |
| 1080p | 1920x1080 | 2.1M | TV Standard |
| 1440p | 2560x1440 | 3.7M | Monitors |
| 4K | 3840x2160 | 8.3M | 4K displays |

## Appendix E: Notification IDs

| ID | Used By |
|----|---------|
| ubuntu-mode | Mode scripts |
| ubuntu-start | Start scripts |
| ubuntu-stop | Stop script |
| ubuntu-update | Update script |
| ubuntu-status | Status script |
| ubuntu-boot | Boot handler |
| ubuntu-battery | Battery handler |
| ubuntu-config | Config scripts |
| ubuntu-notify | Notify helper |

## Appendix F: Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 126 | Permission denied |
| 127 | Command not found |
| 130 | Interrupted |

## File Locations

    ~/.termux/tasker/           # 27 Tasker scripts
    ~/.shortcuts/               # 11 Widget scripts
    ~/ubuntu/logs/tasker/       # Log files
    ~/ubuntu/config/            # Configuration
    ~/ubuntu/docs/              # Documentation

---

Documentation version: 1.0.0
Scripts: 27 | Widgets: 11
DOCEOF

    log_success "Documentation complete"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    log_section "Verifying Installation"
    
    local total=0
    local passed=0
    local fixed=0
    
    check_script() {
        local name="$1"
        local path="$2"
        ((total++))
        
        if [[ -x "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        elif [[ -f "${path}" ]]; then
            chmod +x "${path}"
            printf "  ${COLOR_YELLOW:-}⚡${COLOR_RESET:-} %s (fixed)\n" "${name}"
            ((passed++))
            ((fixed++))
        else
            printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} %s\n" "${name}"
        fi
    }
    
    check_file() {
        local name="$1"
        local path="$2"
        ((total++))
        
        if [[ -f "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} %s\n" "${name}"
        fi
    }
    
    check_command() {
        local name="$1"
        local cmd="$2"
        ((total++))
        
        if command -v "${cmd}" &>/dev/null; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_YELLOW:-}⚠${COLOR_RESET:-} %s (optional)\n" "${name}"
        fi
    }
    
    # Mode Scripts
    echo ""
    echo "Mode Scripts (3):"
    echo "─────────────────"
    check_script "docked-mode.sh" "${TASKER_DIR}/docked-mode.sh"
    check_script "tv-mode.sh" "${TASKER_DIR}/tv-mode.sh"
    check_script "portable-mode.sh" "${TASKER_DIR}/portable-mode.sh"
    
    # Action Scripts
    echo ""
    echo "Action Scripts (5):"
    echo "───────────────────"
    check_script "start-ubuntu.sh" "${TASKER_DIR}/start-ubuntu.sh"
    check_script "start-ubuntu-kde.sh" "${TASKER_DIR}/start-ubuntu-kde.sh"
    check_script "stop-ubuntu.sh" "${TASKER_DIR}/stop-ubuntu.sh"
    check_script "update-ubuntu.sh" "${TASKER_DIR}/update-ubuntu.sh"
    check_script "status-ubuntu.sh" "${TASKER_DIR}/status-ubuntu.sh"
    
    # Event Handlers
    echo ""
    echo "Event Handlers (8):"
    echo "───────────────────"
    check_script "wifi-connected.sh" "${TASKER_DIR}/wifi-connected.sh"
    check_script "usb-connected.sh" "${TASKER_DIR}/usb-connected.sh"
    check_script "usb-disconnected.sh" "${TASKER_DIR}/usb-disconnected.sh"
    check_script "boot-complete.sh" "${TASKER_DIR}/boot-complete.sh"
    check_script "battery-low.sh" "${TASKER_DIR}/battery-low.sh"
    check_script "charging.sh" "${TASKER_DIR}/charging.sh"
    check_script "screen-off.sh" "${TASKER_DIR}/screen-off.sh"
    check_script "screen-on.sh" "${TASKER_DIR}/screen-on.sh"
    
    # Utility Scripts
    echo ""
    echo "Utility Scripts (4):"
    echo "────────────────────"
    check_script "toggle-mode.sh" "${TASKER_DIR}/toggle-mode.sh"
    check_script "set-mode.sh" "${TASKER_DIR}/set-mode.sh"
    check_script "get-mode.sh" "${TASKER_DIR}/get-mode.sh"
    check_script "ubuntu-notify.sh" "${TASKER_DIR}/ubuntu-notify.sh"
    
    # VNC & Audio Control
    echo ""
    echo "Control Scripts (5):"
    echo "────────────────────"
    check_script "vnc-start.sh" "${TASKER_DIR}/vnc-start.sh"
    check_script "vnc-stop.sh" "${TASKER_DIR}/vnc-stop.sh"
    check_script "vnc-status.sh" "${TASKER_DIR}/vnc-status.sh"
    check_script "audio-start.sh" "${TASKER_DIR}/audio-start.sh"
    check_script "audio-stop.sh" "${TASKER_DIR}/audio-stop.sh"
    
    # Config Scripts
    echo ""
    echo "Config Scripts (2):"
    echo "───────────────────"
    check_script "autostart-enable.sh" "${TASKER_DIR}/autostart-enable.sh"
    check_script "autostart-disable.sh" "${TASKER_DIR}/autostart-disable.sh"
    
    # Widgets
    echo ""
    echo "Widget Scripts (11):"
    echo "────────────────────"
    check_script "🐧 Ubuntu Shell" "${SHORTCUTS_DIR}/🐧 Ubuntu Shell"
    check_script "🖥️ Ubuntu KDE" "${SHORTCUTS_DIR}/🖥️ Ubuntu KDE"
    check_script "📺 Cast to TV" "${SHORTCUTS_DIR}/📺 Cast to TV"
    check_script "⏹️ Stop Ubuntu" "${SHORTCUTS_DIR}/⏹️ Stop Ubuntu"
    check_script "ℹ️ Ubuntu Status" "${SHORTCUTS_DIR}/ℹ️ Ubuntu Status"
    check_script "🔄 Update Ubuntu" "${SHORTCUTS_DIR}/🔄 Update Ubuntu"
    check_script "🔌 Docked Mode" "${SHORTCUTS_DIR}/🔌 Docked Mode"
    check_script "🔋 Portable Mode" "${SHORTCUTS_DIR}/🔋 Portable Mode"
    check_script "🔄 Toggle Mode" "${SHORTCUTS_DIR}/🔄 Toggle Mode"
    check_script "▶️ Start VNC" "${SHORTCUTS_DIR}/▶️ Start VNC"
    check_script "⏹️ Stop VNC" "${SHORTCUTS_DIR}/⏹️ Stop VNC"
    
    # Configuration Files
    echo ""
    echo "Configuration:"
    echo "──────────────"
    check_file "tasker-aliases.sh" "${CONFIG_DIR}/tasker-aliases.sh"
    check_file ".auto_start" "${CONFIG_DIR}/.auto_start"
    check_file "TASKER_SETUP.md" "${DOCS_DIR}/TASKER_SETUP.md"
    
    # Check if aliases in bashrc
    ((total++))
    if grep -q "tasker-aliases.sh" "${HOME}/.bashrc" 2>/dev/null; then
        printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} Aliases in .bashrc\n"
        ((passed++))
    else
        printf "  ${COLOR_YELLOW:-}⚠${COLOR_RESET:-} Aliases not in .bashrc\n"
    fi
    
    # Dependencies
    echo ""
    echo "Dependencies:"
    echo "─────────────"
    check_command "termux-notification" "termux-notification"
    check_command "vncserver" "vncserver"
    check_command "pulseaudio" "pulseaudio"
    check_command "proot" "proot"
    
    # Summary
    echo ""
    echo "════════════════════════════════════════════════════════════"
    printf "  Results: ${COLOR_GREEN:-}%d${COLOR_RESET:-} passed" "${passed}"
    if [[ ${fixed} -gt 0 ]]; then
        printf " | ${COLOR_YELLOW:-}%d${COLOR_RESET:-} fixed" "${fixed}"
    fi
    local failed=$((total - passed))
    if [[ ${failed} -gt 0 ]]; then
        printf " | ${COLOR_RED:-}%d${COLOR_RESET:-} failed" "${failed}"
    fi
    printf " | Total: %d\n" "${total}"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ ${passed} -eq ${total} ]]; then
        echo "  ${COLOR_GREEN:-}✓ ALL CHECKS PASSED${COLOR_RESET:-}"
        return 0
    elif [[ ${passed} -ge $((total - 4)) ]]; then
        echo "  ${COLOR_YELLOW:-}⚠ MOSTLY COMPLETE${COLOR_RESET:-} (optional dependencies missing)"
        return 0
    else
        echo "  ${COLOR_RED:-}✗ INCOMPLETE${COLOR_RESET:-}"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Tasker Automation Setup v${SCRIPT_VERSION}"
    echo "  Ubuntu 26.04 Resolute on Termux"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Setup directories
    setup_directories
    
    # Create mode scripts (3)
    log_section "Creating Mode Scripts (3)"
    create_docked_mode
    log_info "  Created: docked-mode.sh"
    create_tv_mode
    log_info "  Created: tv-mode.sh"
    create_portable_mode
    log_info "  Created: portable-mode.sh"
    log_success "Mode scripts complete"
    
    # Create action scripts (5)
    log_section "Creating Action Scripts (5)"
    create_start_ubuntu
    log_info "  Created: start-ubuntu.sh"
    create_start_kde
    log_info "  Created: start-ubuntu-kde.sh"
    create_stop_ubuntu
    log_info "  Created: stop-ubuntu.sh"
    create_update_ubuntu
    log_info "  Created: update-ubuntu.sh"
    create_status_ubuntu
    log_info "  Created: status-ubuntu.sh"
    log_success "Action scripts complete"
    
    # Create event handlers (8)
    log_section "Creating Event Handlers (8)"
    create_wifi_handler
    log_info "  Created: wifi-connected.sh"
    create_usb_connected
    log_info "  Created: usb-connected.sh"
    create_usb_disconnected
    log_info "  Created: usb-disconnected.sh"
    create_boot_handler
    log_info "  Created: boot-complete.sh"
    create_battery_low_handler
    log_info "  Created: battery-low.sh"
    create_charging_handler
    log_info "  Created: charging.sh"
    create_screen_off_handler
    log_info "  Created: screen-off.sh"
    create_screen_on_handler
    log_info "  Created: screen-on.sh"
    log_success "Event handlers complete"
    
    # Create utility scripts (4)
    log_section "Creating Utility Scripts (4)"
    create_toggle_mode
    log_info "  Created: toggle-mode.sh"
    create_set_mode
    log_info "  Created: set-mode.sh"
    create_get_mode
    log_info "  Created: get-mode.sh"
    create_notify_helper
    log_info "  Created: ubuntu-notify.sh"
    log_success "Utility scripts complete"
    
    # Create control scripts (5)
    log_section "Creating Control Scripts (5)"
    create_vnc_start
    log_info "  Created: vnc-start.sh"
    create_vnc_stop
    log_info "  Created: vnc-stop.sh"
    create_vnc_status
    log_info "  Created: vnc-status.sh"
    create_audio_start
    log_info "  Created: audio-start.sh"
    create_audio_stop
    log_info "  Created: audio-stop.sh"
    log_success "Control scripts complete"
    
    # Create config scripts (2)
    log_section "Creating Config Scripts (2)"
    create_autostart_enable
    log_info "  Created: autostart-enable.sh"
    create_autostart_disable
    log_info "  Created: autostart-disable.sh"
    log_success "Config scripts complete"
    
    # Create widgets (11)
    create_widgets
    
    # Create bash aliases
    create_bash_aliases
    
    # Create documentation
    create_documentation
    
    # Verify installation
    verify_installation
    
    # Print summary
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Installation Complete"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Scripts:       27 Tasker scripts in ~/.termux/tasker/"
    echo "  Widgets:       11 Widget scripts in ~/.shortcuts/"
    echo "  Documentation: ~/ubuntu/docs/TASKER_SETUP.md"
    echo "  Aliases:       ~/ubuntu/config/tasker-aliases.sh"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Quick Start"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  1. Reload bash aliases:"
    echo "     ${COLOR_CYAN:-}source ~/.bashrc${COLOR_RESET:-}"
    echo ""
    echo "  2. Test a mode switch:"
    echo "     ${COLOR_CYAN:-}~/.termux/tasker/tv-mode.sh${COLOR_RESET:-}"
    echo ""
    echo "  3. Check status:"
    echo "     ${COLOR_CYAN:-}~/.termux/tasker/status-ubuntu.sh${COLOR_RESET:-}"
    echo ""
    echo "  4. Read documentation:"
    echo "     ${COLOR_CYAN:-}less ~/ubuntu/docs/TASKER_SETUP.md${COLOR_RESET:-}"
    echo ""
    echo "  5. Configure Tasker profiles (see documentation)"
    echo ""
    echo "  6. Add widgets to home screen via Termux:Widget"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Next Step"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  ${COLOR_CYAN:-}bash ~/ubuntu/scripts/11-pkvm-integration.sh${COLOR_RESET:-}"
    echo ""
    
    return 0
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

main "$@"
