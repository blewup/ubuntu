#!/data/data/com.termux/files/usr/bin/bash
#
# 08-display-miracast.sh
# Configure Miracast/WiFi-Direct display streaming
#
# Enables wireless display to Chromecast TVs and Miracast dongles
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
SCRIPT_NAME="Miracast Display Setup"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/08-display-miracast.log"

# ============================================================================
# MIRACAST CONFIGURATION
# ============================================================================

install_miracast_dependencies() {
    log_section "Installing Miracast Dependencies"
    
    log_info "Installing required Termux packages..."
    
    local packages=(
        "ffmpeg"
        "scrcpy"
        "x11-repo"
    )
    
    for pkg in "${packages[@]}"; do
        if pkg_installed "${pkg}"; then
            log_info "Already installed: ${pkg}"
        else
            log_info "Installing: ${pkg}"
            pkg install -y "${pkg}" 2>&1 | tee -a "${CURRENT_LOG_FILE}" || true
        fi
    done
    
    log_success "Dependencies installed"
}

create_miracast_scripts() {
    log_section "Creating Miracast Control Scripts"
    
    # Main Miracast launcher
    local miracast_launcher="${UBUNTU_SCRIPTS}/miracast-display.sh"
    
    cat > "${miracast_launcher}" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# miracast-display.sh - Miracast/Chromecast Display Manager
#
# Usage:
#   miracast-display.sh start [device]   # Start casting
#   miracast-display.sh stop             # Stop casting
#   miracast-display.sh scan             # Scan for devices
#   miracast-display.sh status           # Show status
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh" 2>/dev/null || true

# Configuration
MIRACAST_STATE_FILE="/tmp/miracast-state"
DEFAULT_RESOLUTION="1920x1080"
DEFAULT_BITRATE="8M"
DEFAULT_FPS="30"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_banner() {
    echo ""
    echo "${COLOR_BOLD_CYAN:-}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET:-}"
    echo "${COLOR_BOLD_CYAN:-}║${COLOR_RESET:-}           Miracast / Chromecast Display Manager              ${COLOR_BOLD_CYAN:-}║${COLOR_RESET:-}"
    echo "${COLOR_BOLD_CYAN:-}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET:-}"
    echo ""
}

check_requirements() {
    local missing=()
    
    command -v termux-info &>/dev/null || missing+=("termux-api")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${COLOR_ERROR:-}Missing requirements: ${missing[*]}${COLOR_RESET:-}"
        echo "Install with: pkg install ${missing[*]}"
        return 1
    fi
    return 0
}

scan_devices() {
    echo "Scanning for wireless displays..."
    echo ""
    echo "${COLOR_YELLOW:-}Note: Miracast discovery requires Android's built-in casting.${COLOR_RESET:-}"
    echo ""
    echo "To cast your screen:"
    echo ""
    echo "  ${COLOR_CYAN:-}Method 1: Android Quick Settings${COLOR_RESET:-}"
    echo "  1. Swipe down for Quick Settings"
    echo "  2. Tap 'Screen Cast' or 'Smart View'"
    echo "  3. Select your Chromecast/TV"
    echo ""
    echo "  ${COLOR_CYAN:-}Method 2: Google Home App${COLOR_RESET:-}"
    echo "  1. Open Google Home"
    echo "  2. Select your Chromecast"
    echo "  3. Tap 'Cast my screen'"
    echo ""
    echo "${COLOR_INFO:-}Available Chromecast devices on network:${COLOR_RESET:-}"
    echo ""
    
    # Try to discover Chromecast devices via mDNS
    if command -v avahi-browse &>/dev/null; then
        timeout 5 avahi-browse -t _googlecast._tcp 2>/dev/null || echo "  (mDNS scan unavailable)"
    else
        # Simple network scan for common Chromecast ports
        echo "  Scanning local network..."
        local gateway
        gateway=$(ip route | grep default | awk '{print $3}' | head -1)
        local subnet="${gateway%.*}"
        
        for i in {1..254}; do
            (ping -c 1 -W 1 "${subnet}.${i}" &>/dev/null && 
             nc -z -w 1 "${subnet}.${i}" 8008 2>/dev/null && 
             echo "  Found: ${subnet}.${i} (possible Chromecast)") &
        done
        wait 2>/dev/null
    fi
    echo ""
}

start_android_cast() {
    echo "Starting Android Screen Cast..."
    echo ""
    
    # Method 1: Try via Termux:API (if available)
    if command -v termux-open &>/dev/null; then
        echo "Opening Android cast settings..."
        termux-open "android.settings.CAST_SETTINGS" 2>/dev/null || \
        am start -a android.settings.CAST_SETTINGS 2>/dev/null || true
    fi
    
    echo ""
    echo "${COLOR_INFO:-}Instructions:${COLOR_RESET:-}"
    echo "1. Select your Chromecast/TV from the list"
    echo "2. Your entire screen will be mirrored"
    echo "3. Start Ubuntu with VNC: ubuntu-kde"
    echo "4. Open VNC Viewer to see Ubuntu on TV"
    echo ""
    echo "${COLOR_SUCCESS:-}The VNC desktop will appear on your TV!${COLOR_RESET:-}"
    echo ""
    
    # Save state
    echo "casting" > "${MIRACAST_STATE_FILE}"
}

start_vnc_for_cast() {
    local resolution="${1:-${DEFAULT_RESOLUTION}}"
    
    echo "Starting VNC for Miracast display..."
    
    # Kill existing VNC
    vncserver -kill :1 2>/dev/null || true
    sleep 1
    
    # Start VNC with appropriate resolution
    vncserver -localhost no -geometry "${resolution}" -depth 24 :1
    
    echo ""
    echo "${COLOR_SUCCESS:-}VNC started at resolution: ${resolution}${COLOR_RESET:-}"
    echo ""
    echo "Connect your VNC viewer to see the desktop on TV."
    echo "Local IP: $(ip route get 1 2>/dev/null | awk '{print $7; exit}')"
    echo "Port: 5901"
}

stop_casting() {
    echo "Stopping screen cast..."
    
    # Note: Can't programmatically stop Android cast
    echo ""
    echo "${COLOR_INFO:-}To stop casting:${COLOR_RESET:-}"
    echo "1. Swipe down for Quick Settings"
    echo "2. Tap the active cast notification"
    echo "3. Tap 'Disconnect'"
    echo ""
    
    # Clean up state
    rm -f "${MIRACAST_STATE_FILE}"
}

show_status() {
    echo "Miracast Status"
    echo "==============="
    echo ""
    
    # VNC status
    if pgrep -f "Xvnc" &>/dev/null; then
        local vnc_display
        vnc_display=$(pgrep -a -f "Xvnc" | grep -o ":[0-9]*" | head -1)
        echo "VNC Server: ${COLOR_SUCCESS:-}Running${COLOR_RESET:-} on ${vnc_display}"
    else
        echo "VNC Server: ${COLOR_DIM:-}Not running${COLOR_RESET:-}"
    fi
    
    # Network
    local ip
    ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "Unknown")
    echo "Local IP: ${ip}"
    
    # Cast state
    if [[ -f "${MIRACAST_STATE_FILE}" ]]; then
        echo "Cast Status: ${COLOR_SUCCESS:-}Active${COLOR_RESET:-}"
    else
        echo "Cast Status: ${COLOR_DIM:-}Inactive${COLOR_RESET:-}"
    fi
    
    echo ""
}

show_help() {
    echo "Miracast Display Manager"
    echo ""
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start [resolution]   Start screen casting"
    echo "  stop                 Stop screen casting"
    echo "  scan                 Scan for Chromecast devices"
    echo "  status               Show casting status"
    echo "  vnc [resolution]     Start VNC for casting"
    echo "  help                 Show this help"
    echo ""
    echo "Resolutions:"
    echo "  1920x1080  (default, Full HD)"
    echo "  1280x720   (HD, lower bandwidth)"
    echo "  2560x1440  (QHD, high bandwidth)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") start"
    echo "  $(basename "$0") vnc 1280x720"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    case "${1:-}" in
        start)
            print_banner
            check_requirements || exit 1
            start_android_cast
            start_vnc_for_cast "${2:-${DEFAULT_RESOLUTION}}"
            ;;
        stop)
            stop_casting
            ;;
        scan)
            print_banner
            scan_devices
            ;;
        status)
            print_banner
            show_status
            ;;
        vnc)
            start_vnc_for_cast "${2:-${DEFAULT_RESOLUTION}}"
            ;;
        help|--help|-h)
            print_banner
            show_help
            ;;
        *)
            print_banner
            show_help
            ;;
    esac
}

main "$@"
EOF

    chmod +x "${miracast_launcher}"
    log_success "Miracast launcher created"
    
    # Create Chromecast-specific script
    local chromecast_script="${UBUNTU_SCRIPTS}/chromecast-helper.sh"
    
    cat > "${chromecast_script}" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# chromecast-helper.sh - Chromecast-specific utilities
#

echo "Chromecast Helper"
echo "================="
echo ""
echo "Your Pixel 10 Pro XL can cast to Chromecast in several ways:"
echo ""
echo "1. ${COLOR_CYAN:-}Full Screen Mirror:${COLOR_RESET:-}"
echo "   - Quick Settings → Cast"
echo "   - Mirrors everything including Ubuntu VNC"
echo ""
echo "2. ${COLOR_CYAN:-}App-Specific Cast:${COLOR_RESET:-}"
echo "   - Some VNC apps support direct Chromecast"
echo "   - Look for Cast icon in the VNC viewer"
echo ""
echo "3. ${COLOR_CYAN:-}Google Home App:${COLOR_RESET:-}"
echo "   - Open Google Home → Select Chromecast → Cast Screen"
echo ""
echo "For best experience with Ubuntu on TV:"
echo "  1. Start: ubuntu-kde"
echo "  2. Cast screen to Chromecast"
echo "  3. Connect VNC viewer to localhost:5901"
echo "  4. The KDE desktop appears on TV!"
echo ""
echo "Tips for Chromecast:"
echo "  • Use 1080p resolution for best compatibility"
echo "  • Ensure phone and Chromecast on same WiFi"
echo "  • For gaming, use 720p at 60fps"
echo ""
EOF

    chmod +x "${chromecast_script}"
    log_success "Chromecast helper created"
}

create_display_profiles() {
    log_section "Creating Display Profiles"
    
    local profiles_dir="${UBUNTU_CONFIG}/display-profiles"
    ensure_dir "${profiles_dir}"
    
    # TV Profile (1080p)
    cat > "${profiles_dir}/tv-1080p.conf" << 'EOF'
# TV Display Profile - 1080p
DISPLAY_NAME="TV 1080p"
RESOLUTION="1920x1080"
REFRESH_RATE="60"
BITRATE="8M"
DPI="96"
SCALE="1.0"
EOF

    # TV Profile (4K)
    cat > "${profiles_dir}/tv-4k.conf" << 'EOF'
# TV Display Profile - 4K
DISPLAY_NAME="TV 4K"
RESOLUTION="3840x2160"
REFRESH_RATE="30"
BITRATE="20M"
DPI="192"
SCALE="2.0"
EOF

    # Portable (720p - low bandwidth)
    cat > "${profiles_dir}/portable-720p.conf" << 'EOF'
# Portable Display Profile - 720p
DISPLAY_NAME="Portable 720p"
RESOLUTION="1280x720"
REFRESH_RATE="60"
BITRATE="4M"
DPI="96"
SCALE="1.0"
EOF

    # Monitor Profile
    cat > "${profiles_dir}/monitor-1440p.conf" << 'EOF'
# Monitor Display Profile - 1440p
DISPLAY_NAME="Monitor 1440p"
RESOLUTION="2560x1440"
REFRESH_RATE="60"
BITRATE="12M"
DPI="120"
SCALE="1.25"
EOF

    log_success "Display profiles created in ${profiles_dir}"
}

create_quick_cast_shortcut() {
    log_section "Creating Quick Cast Shortcuts"
    
    local shortcuts_dir="${HOME}/.shortcuts"
    ensure_dir "${shortcuts_dir}"
    
    # Quick cast to TV
    cat > "${shortcuts_dir}/Cast to TV" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
~/ubuntu/scripts/miracast-display.sh start 1920x1080
~/ubuntu/scripts/launch-ubuntu.sh --kde
EOF
    chmod +x "${shortcuts_dir}/Cast to TV"
    
    log_success "Quick cast shortcut created"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Setting up Miracast display streaming..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Run setup steps
    install_miracast_dependencies
    create_miracast_scripts
    create_display_profiles
    create_quick_cast_shortcut
    
    print_footer "success" "Miracast setup completed"
    
    echo ""
    echo "To cast Ubuntu to your Chromecast TV:"
    echo ""
    echo "  ${COLOR_CYAN}Option 1: Quick Cast${COLOR_RESET}"
    echo "    ~/ubuntu/scripts/miracast-display.sh start"
    echo "    ubuntu-kde"
    echo ""
    echo "  ${COLOR_CYAN}Option 2: Manual${COLOR_RESET}"
    echo "    1. ubuntu-kde  (start Ubuntu)"
    echo "    2. Use Android Quick Settings → Cast"
    echo "    3. Connect VNC viewer to see on TV"
    echo ""
    echo "Next steps:"
    echo "  ${COLOR_CYAN}bash ~/ubuntu/scripts/09-display-scrcpy-x11.sh${COLOR_RESET}"
    echo ""
    
    return 0
}

# Run main function
main "$@"
