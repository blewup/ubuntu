#!/data/data/com.termux/files/usr/bin/bash
#
# 09-display-scrcpy-x11.sh
# Configure Scrcpy + X11 forwarding for display
#
# Alternative display method using scrcpy reverse mode
#

set -euo pipefail

# ============================================================================
# INITIALIZATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Source libraries
source "${UBUNTU_PROJECT_ROOT}/lib/colors.sh"
source "${UBUNTU_PROJECT_ROOT}/lib/functions.sh"

# Script configuration
SCRIPT_NAME="Scrcpy X11 Display Setup"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/09-display-scrcpy-x11.log"

# ============================================================================
# SCRCPY CONFIGURATION
# ============================================================================

install_scrcpy_dependencies() {
    log_section "Installing Scrcpy Dependencies"
    
    local packages=(
        "scrcpy"
        "adb"
        "x11-repo"
        "xorg-server-xvfb"
        "tigervnc"
    )
    
    for pkg in "${packages[@]}"; do
        if pkg_installed "${pkg}"; then
            log_info "Already installed: ${pkg}"
        else
            log_info "Installing: ${pkg}"
            pkg install -y "${pkg}" 2>&1 | tee -a "${CURRENT_LOG_FILE}" || true
        fi
    done
    
    log_success "Scrcpy dependencies installed"
}

create_scrcpy_scripts() {
    log_section "Creating Scrcpy Control Scripts"
    
    # Main scrcpy display script
    local scrcpy_launcher="${UBUNTU_SCRIPTS}/scrcpy-display.sh"
    
    cat > "${scrcpy_launcher}" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# scrcpy-display.sh - Scrcpy Display Manager
#
# Uses scrcpy to create a virtual display or mirror
# with X11 forwarding capabilities
#
# Usage:
#   scrcpy-display.sh start    # Start scrcpy display
#   scrcpy-display.sh stop     # Stop display
#   scrcpy-display.sh window   # Windowed mode
#   scrcpy-display.sh cast     # Cast to external display
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh" 2>/dev/null || true

# Configuration
SCRCPY_PID_FILE="/tmp/scrcpy.pid"
DEFAULT_BITRATE="8M"
DEFAULT_MAX_SIZE="1920"
DEFAULT_FPS="30"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_banner() {
    echo ""
    echo "${COLOR_BOLD_CYAN:-}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET:-}"
    echo "${COLOR_BOLD_CYAN:-}║${COLOR_RESET:-}              Scrcpy + X11 Display Manager                    ${COLOR_BOLD_CYAN:-}║${COLOR_RESET:-}"
    echo "${COLOR_BOLD_CYAN:-}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET:-}"
    echo ""
}

check_scrcpy() {
    if ! command -v scrcpy &>/dev/null; then
        echo "${COLOR_ERROR:-}Scrcpy not found!${COLOR_RESET:-}"
        echo "Install with: pkg install scrcpy"
        return 1
    fi
    return 0
}

start_scrcpy_vnc() {
    local max_size="${1:-${DEFAULT_MAX_SIZE}}"
    local bitrate="${2:-${DEFAULT_BITRATE}}"
    
    echo "Starting Scrcpy display..."
    
    # First, start VNC for Ubuntu
    echo "  → Starting VNC server..."
    vncserver -kill :1 2>/dev/null || true
    sleep 1
    vncserver -localhost no -geometry 1920x1080 -depth 24 :1
    
    # Configure for use with external display
    echo "  → Configuring display..."
    export DISPLAY=:1
    
    echo ""
    echo "${COLOR_SUCCESS:-}Display ready!${COLOR_RESET:-}"
    echo ""
    echo "VNC is running on :1"
    echo "Connect with a VNC client to see Ubuntu."
    echo ""
    echo "To mirror to an external display:"
    echo "  1. Connect display via USB-C"
    echo "  2. Or use wireless casting"
    echo ""
}

start_scrcpy_wireless() {
    local target_ip="${1:-}"
    
    if [[ -z "${target_ip}" ]]; then
        echo "Scanning for wireless displays..."
        echo ""
        
        # Get local network
        local gateway
        gateway=$(ip route | grep default | awk '{print $3}' | head -1)
        echo "Gateway: ${gateway}"
        echo ""
        
        echo "For wireless scrcpy, you need:"
        echo "1. ADB over WiFi enabled on target device"
        echo "2. Or use --tcpip flag with scrcpy"
        echo ""
        return 1
    fi
    
    echo "Connecting to ${target_ip}..."
    
    # Connect via ADB
    adb connect "${target_ip}:5555" 2>/dev/null || {
        echo "Failed to connect. Ensure ADB over WiFi is enabled."
        return 1
    }
    
    # Start scrcpy
    scrcpy -s "${target_ip}:5555" \
        --bit-rate "${DEFAULT_BITRATE}" \
        --max-size "${DEFAULT_MAX_SIZE}" \
        --max-fps "${DEFAULT_FPS}" &
    
    echo $! > "${SCRCPY_PID_FILE}"
    echo "Scrcpy started (PID: $(cat "${SCRCPY_PID_FILE}"))"
}

start_scrcpy_record() {
    local output_file="${1:-/sdcard/ubuntu-recording.mp4}"
    
    echo "Starting Scrcpy with recording..."
    echo "Output: ${output_file}"
    
    # Start VNC first
    start_scrcpy_vnc
    
    # Record screen
    echo ""
    echo "Recording will save to: ${output_file}"
    echo "Press Ctrl+C to stop recording."
    
    scrcpy --record "${output_file}" \
        --bit-rate "${DEFAULT_BITRATE}" \
        --max-size "${DEFAULT_MAX_SIZE}" \
        --no-display &
    
    echo $! > "${SCRCPY_PID_FILE}"
}

stop_scrcpy() {
    echo "Stopping Scrcpy..."
    
    if [[ -f "${SCRCPY_PID_FILE}" ]]; then
        kill "$(cat "${SCRCPY_PID_FILE}")" 2>/dev/null || true
        rm -f "${SCRCPY_PID_FILE}"
    fi
    
    pkill -f scrcpy 2>/dev/null || true
    
    echo "Scrcpy stopped."
}

show_status() {
    echo "Scrcpy Status"
    echo "============="
    echo ""
    
    # Scrcpy running?
    if pgrep -f scrcpy &>/dev/null; then
        echo "Scrcpy: ${COLOR_SUCCESS:-}Running${COLOR_RESET:-}"
        pgrep -a -f scrcpy | head -3
    else
        echo "Scrcpy: ${COLOR_DIM:-}Not running${COLOR_RESET:-}"
    fi
    
    echo ""
    
    # VNC status
    if pgrep -f "Xvnc" &>/dev/null; then
        echo "VNC: ${COLOR_SUCCESS:-}Running${COLOR_RESET:-}"
    else
        echo "VNC: ${COLOR_DIM:-}Not running${COLOR_RESET:-}"
    fi
    
    # Display
    echo ""
    echo "DISPLAY: ${DISPLAY:-not set}"
}

show_help() {
    echo "Scrcpy Display Manager"
    echo ""
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [size] [bitrate]   Start VNC display"
    echo "  wireless <ip>            Connect to wireless display"
    echo "  record [file]            Record screen to file"
    echo "  stop                     Stop scrcpy"
    echo "  status                   Show status"
    echo "  help                     Show this help"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") start"
    echo "  $(basename "$0") start 1280 4M"
    echo "  $(basename "$0") wireless 192.168.1.100"
    echo "  $(basename "$0") record ~/video.mp4"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    case "${1:-}" in
        start)
            print_banner
            check_scrcpy || exit 1
            start_scrcpy_vnc "${2:-}" "${3:-}"
            ;;
        wireless)
            print_banner
            check_scrcpy || exit 1
            start_scrcpy_wireless "${2:-}"
            ;;
        record)
            print_banner
            check_scrcpy || exit 1
            start_scrcpy_record "${2:-}"
            ;;
        stop)
            stop_scrcpy
            ;;
        status)
            print_banner
            show_status
            ;;
        help|--help|-h|"")
            print_banner
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "${scrcpy_launcher}"
    log_success "Scrcpy launcher created"
}

create_x11_forwarding_config() {
    log_section "Configuring X11 Forwarding"
    
    # X11 environment script
    local x11_env="${UBUNTU_ROOT}/etc/profile.d/x11-forward.sh"
    
    cat > "${x11_env}" << 'EOF'
#!/bin/bash
# X11 Forwarding Configuration

# Set DISPLAY if not already set
export DISPLAY="${DISPLAY:-:1}"

# XDG directories
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null
chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null

# X11 authentication
export XAUTHORITY="${HOME}/.Xauthority"

# Disable access control for local connections (proot workaround)
xhost +local: 2>/dev/null || true
EOF

    chmod +x "${x11_env}"
    log_success "X11 forwarding configuration created"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Setting up Scrcpy + X11 display..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Run setup steps
    install_scrcpy_dependencies
    create_scrcpy_scripts
    create_x11_forwarding_config
    
    print_footer "success" "Scrcpy X11 setup completed"
    
    echo ""
    echo "Scrcpy Display Options:"
    echo ""
    echo "  ${COLOR_CYAN}Start Display:${COLOR_RESET}"
    echo "    ~/ubuntu/scripts/scrcpy-display.sh start"
    echo ""
    echo "  ${COLOR_CYAN}Record Session:${COLOR_RESET}"
    echo "    ~/ubuntu/scripts/scrcpy-display.sh record"
    echo ""
    echo "Next steps:"
    echo "  ${COLOR_CYAN}bash ~/ubuntu/scripts/10-tasker-automation.sh${COLOR_RESET}"
    echo ""
    
    return 0
}

# Run main function
main "$@"
