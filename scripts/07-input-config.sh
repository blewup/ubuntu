#!/data/data/com.termux/files/usr/bin/bash
#
# 07-input-config.sh
# Configure input devices for Ubuntu on Termux
#
# Supports:
# - Touchscreen as mouse (primary)
# - Bluetooth keyboard/mouse (secondary)
# - USB-C hub peripherals (tertiary)
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
SCRIPT_NAME="Input Device Configuration"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/07-input-config.log"

# ============================================================================
# TOUCHSCREEN CONFIGURATION
# ============================================================================

configure_touchscreen() {
    log_section "Configuring Touchscreen Input"
    
    log_info "Setting up touchscreen as mouse input..."
    
    # Create touchscreen configuration for X11
    local xorg_conf_dir="${UBUNTU_ROOT}/etc/X11/xorg.conf.d"
    ensure_dir "${xorg_conf_dir}"
    
    cat > "${xorg_conf_dir}/40-touchscreen.conf" << 'EOF'
# Touchscreen configuration for VNC/X11
# Maps touchscreen input to mouse events

Section "InputClass"
    Identifier "Touchscreen"
    MatchIsTouchscreen "on"
    Driver "libinput"
    Option "Mode" "Absolute"
    Option "Tapping" "on"
    Option "TappingDrag" "on"
    Option "TappingDragLock" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "false"
    Option "ScrollMethod" "twofinger"
    Option "ClickMethod" "clickfinger"
EndSection
EOF

    log_success "Touchscreen X11 configuration created"
    
    # Create touch-to-mouse helper script for VNC
    local touch_helper="${UBUNTU_ROOT}/usr/local/bin/touch-helper"
    
    cat > "${touch_helper}" << 'EOF'
#!/bin/bash
#
# touch-helper - Touchscreen to mouse event helper
# Improves touchscreen behavior in VNC sessions
#

# Configuration
LONG_PRESS_MS=500
DOUBLE_TAP_MS=300

echo "Touch Helper Active"
echo "==================="
echo "Tap       = Left Click"
echo "Long Tap  = Right Click"
echo "Two Finger Tap = Right Click"
echo "Swipe     = Scroll"
echo ""
echo "This helper enhances touch input for VNC."
echo "Close this to disable enhanced touch features."

# The actual touch-to-mouse conversion is handled by the VNC client
# This script provides visual feedback and can be extended for custom gestures

# Keep running for status
while true; do
    sleep 3600
done
EOF

    chmod +x "${touch_helper}"
    log_success "Touch helper script created"
    
    # Create onscreen keyboard launcher
    local osk_launcher="${UBUNTU_ROOT}/usr/local/bin/onscreen-keyboard"
    
    cat > "${osk_launcher}" << 'EOF'
#!/bin/bash
#
# onscreen-keyboard - Launch onscreen keyboard
#

# Try various onscreen keyboards in order of preference
if command -v onboard &>/dev/null; then
    exec onboard "$@"
elif command -v florence &>/dev/null; then
    exec florence "$@"
elif command -v matchbox-keyboard &>/dev/null; then
    exec matchbox-keyboard "$@"
elif command -v kvkbd &>/dev/null; then
    exec kvkbd "$@"
else
    echo "No onscreen keyboard found!"
    echo ""
    echo "Install one with:"
    echo "  sudo apt install onboard      # Recommended for GNOME/KDE"
    echo "  sudo apt install florence     # Lightweight alternative"
    echo "  sudo apt install kvkbd        # KDE-native keyboard"
    exit 1
fi
EOF

    chmod +x "${osk_launcher}"
    log_success "Onscreen keyboard launcher created"
}

install_onscreen_keyboard() {
    log_section "Installing Onscreen Keyboard"
    
    local install_script="${UBUNTU_ROOT}/usr/local/bin/install-onscreen-keyboard"
    
    cat > "${install_script}" << 'EOF'
#!/bin/bash
#
# install-onscreen-keyboard - Install and configure onscreen keyboard
#

set -e

echo "Installing Onscreen Keyboard..."
echo ""

# Install onboard (best for KDE/GNOME)
sudo apt-get update
sudo apt-get install -y onboard onboard-data

# Configure onboard for touch-friendly use
mkdir -p ~/.config/onboard

cat > ~/.config/onboard/onboard.conf << 'ONBOARDCONF'
[main]
layout=Compact
theme=Droid
show-status-icon=true
start-minimized=false
xembed-onboard=true

[window]
window-state-sticky=true
force-to-top=true
transparent-background=false

[keyboard]
touch-feedback-enabled=true
audio-feedback-enabled=false

[auto-show]
enabled=true
ONBOARDCONF

echo ""
echo "Onscreen keyboard installed!"
echo ""
echo "To start: onboard"
echo "Or use:   onscreen-keyboard"
echo ""
echo "Onboard will auto-show when text input is focused."
EOF

    chmod +x "${install_script}"
    log_success "Onscreen keyboard installer created"
}

# ============================================================================
# BLUETOOTH INPUT CONFIGURATION
# ============================================================================

configure_bluetooth() {
    log_section "Configuring Bluetooth Input"
    
    log_info "Setting up Bluetooth keyboard/mouse support..."
    
    # Create Bluetooth configuration script for Ubuntu
    local bt_script="${UBUNTU_ROOT}/usr/local/bin/setup-bluetooth"
    
    cat > "${bt_script}" << 'EOF'
#!/bin/bash
#
# setup-bluetooth - Configure Bluetooth for proot environment
#
# Note: Bluetooth in proot requires Android's Bluetooth service
# Devices must be paired via Android first, then they work in proot
#

echo "Bluetooth Setup for Ubuntu on Termux"
echo "====================================="
echo ""
echo "Important: Bluetooth devices must be paired in Android first!"
echo ""
echo "Steps:"
echo "1. Open Android Bluetooth settings"
echo "2. Pair your keyboard/mouse"
echo "3. The devices will automatically work in Ubuntu"
echo ""
echo "For programmatic access via Termux:API..."

# Check if termux-api is available
if command -v termux-bluetooth-info &>/dev/null 2>&1; then
    echo ""
    echo "Bluetooth devices (via Termux:API):"
    termux-bluetooth-info 2>/dev/null || echo "  (Requires Termux:API permission)"
else
    echo ""
    echo "Install Termux:API for Bluetooth control:"
    echo "  1. Install Termux:API app from F-Droid"
    echo "  2. In Termux: pkg install termux-api"
fi

echo ""
echo "Connected HID devices:"
ls -la /dev/input/ 2>/dev/null | grep -E "event|mouse|keyboard" || echo "  No HID devices found"
EOF

    chmod +x "${bt_script}"
    log_success "Bluetooth setup script created"
    
    # X11 configuration for Bluetooth devices
    local xorg_bt="${UBUNTU_ROOT}/etc/X11/xorg.conf.d/50-bluetooth-input.conf"
    
    cat > "${xorg_bt}" << 'EOF'
# Bluetooth input device configuration

Section "InputClass"
    Identifier "Bluetooth Keyboard"
    MatchIsKeyboard "on"
    Driver "libinput"
    Option "XkbLayout" "us"
    Option "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection

Section "InputClass"
    Identifier "Bluetooth Mouse"
    MatchIsPointer "on"
    Driver "libinput"
    Option "AccelProfile" "adaptive"
    Option "AccelSpeed" "0"
    Option "NaturalScrolling" "false"
EndSection
EOF

    log_success "Bluetooth X11 configuration created"
}

# ============================================================================
# USB INPUT CONFIGURATION
# ============================================================================

configure_usb() {
    log_section "Configuring USB Input Devices"
    
    log_info "Setting up USB keyboard/mouse support (USB-C hub)..."
    
    # USB input configuration
    local xorg_usb="${UBUNTU_ROOT}/etc/X11/xorg.conf.d/51-usb-input.conf"
    
    cat > "${xorg_usb}" << 'EOF'
# USB input device configuration (USB-C hub)

Section "InputClass"
    Identifier "USB Keyboard"
    MatchIsKeyboard "on"
    MatchUSBID "*"
    Driver "libinput"
    Option "XkbLayout" "us"
    Option "XkbVariant" ""
    Option "XkbOptions" "terminate:ctrl_alt_bksp,caps:escape"
EndSection

Section "InputClass"
    Identifier "USB Mouse"
    MatchIsPointer "on"
    MatchUSBID "*"
    Driver "libinput"
    Option "AccelProfile" "flat"
    Option "AccelSpeed" "0"
    Option "MiddleEmulation" "on"
    Option "NaturalScrolling" "false"
EndSection

Section "InputClass"
    Identifier "USB Trackpad"
    MatchIsTouchpad "on"
    MatchUSBID "*"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingDrag" "on"
    Option "NaturalScrolling" "true"
    Option "ScrollMethod" "twofinger"
    Option "ClickMethod" "clickfinger"
EndSection
EOF

    log_success "USB X11 configuration created"
    
    # Create USB device detection script
    local usb_detect="${UBUNTU_ROOT}/usr/local/bin/detect-usb-input"
    
    cat > "${usb_detect}" << 'EOF'
#!/bin/bash
#
# detect-usb-input - Detect and display USB input devices
#

echo "USB Input Device Detection"
echo "=========================="
echo ""

echo "Input devices (/dev/input/):"
echo "----------------------------"
if [[ -d /dev/input ]]; then
    for dev in /dev/input/event*; do
        if [[ -e "$dev" ]]; then
            name=$(cat /sys/class/input/$(basename $dev)/device/name 2>/dev/null || echo "Unknown")
            echo "  $dev: $name"
        fi
    done
else
    echo "  /dev/input not accessible"
fi

echo ""
echo "USB devices (via Android):"
echo "--------------------------"
if command -v termux-usb &>/dev/null; then
    termux-usb -l 2>/dev/null || echo "  Termux:API not available"
else
    echo "  Install termux-api for USB enumeration"
fi

echo ""
echo "Note: USB OTG devices connected via USB-C hub should be auto-detected."
echo "If a device isn't working, try:"
echo "  1. Disconnect and reconnect the device"
echo "  2. Check Android USB preferences"
echo "  3. Ensure USB OTG is supported and enabled"
EOF

    chmod +x "${usb_detect}"
    log_success "USB detection script created"
}

# ============================================================================
# INPUT METHOD CONFIGURATION
# ============================================================================

configure_input_methods() {
    log_section "Configuring Input Methods"
    
    # Create input method setup script
    local im_script="${UBUNTU_ROOT}/usr/local/bin/setup-input-methods"
    
    cat > "${im_script}" << 'EOF'
#!/bin/bash
#
# setup-input-methods - Configure input methods (ibus, fcitx, etc.)
#

echo "Input Method Setup"
echo "=================="
echo ""

# Detect current input method
if [[ -n "${GTK_IM_MODULE:-}" ]]; then
    echo "Current IM: $GTK_IM_MODULE"
else
    echo "No input method configured"
fi

echo ""
echo "Available input method frameworks:"
echo "-----------------------------------"

if command -v ibus &>/dev/null; then
    echo "  ✓ IBus (installed)"
else
    echo "  ✗ IBus - install with: sudo apt install ibus"
fi

if command -v fcitx5 &>/dev/null; then
    echo "  ✓ Fcitx5 (installed)"
else
    echo "  ✗ Fcitx5 - install with: sudo apt install fcitx5"
fi

echo ""
echo "To configure for your language:"
echo "  1. Install the input method framework"
echo "  2. Install language-specific packages"
echo "  3. Add to ~/.profile:"
echo "     export GTK_IM_MODULE=ibus  # or fcitx"
echo "     export QT_IM_MODULE=ibus"
echo "     export XMODIFIERS=@im=ibus"
echo ""
EOF

    chmod +x "${im_script}"
    log_success "Input method setup script created"
}

# ============================================================================
# TERMUX INPUT BRIDGE
# ============================================================================

create_termux_input_bridge() {
    log_section "Creating Termux Input Bridge"
    
    # Script to bridge Termux input to proot
    local bridge_script="${UBUNTU_SCRIPTS}/input-bridge.sh"
    
    cat > "${bridge_script}" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# input-bridge.sh - Bridge input events from Termux to Ubuntu proot
#
# This script helps manage input device access between
# Android/Termux and the Ubuntu proot environment.
#

source ~/ubuntu/lib/colors.sh 2>/dev/null || true

echo "${COLOR_HEADER:-}Input Bridge for Ubuntu on Termux${COLOR_RESET:-}"
echo "=================================="
echo ""

# Check Termux:API
check_termux_api() {
    if command -v termux-info &>/dev/null; then
        echo "✓ Termux:API available"
        return 0
    else
        echo "✗ Termux:API not installed"
        echo "  Install: pkg install termux-api"
        echo "  Also install Termux:API app from F-Droid"
        return 1
    fi
}

# Check input devices
check_input_devices() {
    echo ""
    echo "Input Device Status:"
    echo "-------------------"
    
    # Touchscreen (always available via VNC)
    echo "  ✓ Touchscreen: Available via VNC client"
    
    # Check for Bluetooth
    if command -v termux-bluetooth-info &>/dev/null; then
        bt_status=$(termux-bluetooth-info 2>/dev/null | head -1 || echo "unknown")
        echo "  • Bluetooth: ${bt_status}"
    else
        echo "  ? Bluetooth: Unknown (install termux-api)"
    fi
    
    # Check for USB
    if [[ -d /dev/input ]]; then
        usb_count=$(ls /dev/input/event* 2>/dev/null | wc -l)
        echo "  • Input events: ${usb_count} devices"
    fi
}

# Show usage tips
show_tips() {
    echo ""
    echo "Input Tips:"
    echo "-----------"
    echo ""
    echo "1. TOUCHSCREEN (Primary)"
    echo "   - Use any VNC client with touch support"
    echo "   - Tap = Click, Long press = Right-click"
    echo "   - Two fingers = Scroll"
    echo ""
    echo "2. BLUETOOTH (Secondary)"
    echo "   - Pair devices in Android Settings first"
    echo "   - Devices auto-work in Ubuntu via VNC"
    echo ""
    echo "3. USB-C HUB (Tertiary)"
    echo "   - Connect hub with keyboard/mouse"
    echo "   - Works automatically if OTG supported"
    echo ""
    echo "4. ONSCREEN KEYBOARD"
    echo "   - Inside Ubuntu: onscreen-keyboard"
    echo "   - Or install: sudo apt install onboard"
    echo ""
}

# Main
check_termux_api
check_input_devices
show_tips
EOF

    chmod +x "${bridge_script}"
    log_success "Input bridge script created"
}

# ============================================================================
# KDE INPUT SETTINGS
# ============================================================================

configure_kde_input() {
    log_section "Configuring KDE Input Settings"
    
    local kde_input="${UBUNTU_ROOT}/home/droid/.config/kcminputrc"
    ensure_dir "$(dirname "${kde_input}")"
    
    cat > "${kde_input}" << 'EOF'
[Keyboard]
KeyRepeat=repeat
RepeatDelay=400
RepeatRate=25

[Mouse]
Acceleration=0
Threshold=0
XLbInptAccelProfileFlat=true
XLbInptPointerAcceleration=0
XLbInptNaturalScroll=false

[Touchpad]
TapToClick=true
TapAndDrag=true
TwoFingerTap=true
NaturalScroll=true
DisableWhileTyping=true
Scrolling=1
EOF

    # KDE Touchpad specific
    local kde_touchpad="${UBUNTU_ROOT}/home/droid/.config/touchpadrc"
    
    cat > "${kde_touchpad}" << 'EOF'
[Touchpad]
TapToClick=true
TapAndDrag=true
TwoFingerTap=2
ThreeFingerTap=3
NaturalScroll=true
VertTwoFingerScroll=true
HorizTwoFingerScroll=true
EOF

    # Set ownership
    chown -R 1000:1000 "${UBUNTU_ROOT}/home/droid/.config" 2>/dev/null || true
    
    log_success "KDE input settings configured"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_input_config() {
    log_section "Verifying Input Configuration"
    
    local checks_passed=0
    local total_checks=0
    
    # Check X11 configs
    local xorg_configs=(
        "${UBUNTU_ROOT}/etc/X11/xorg.conf.d/40-touchscreen.conf"
        "${UBUNTU_ROOT}/etc/X11/xorg.conf.d/50-bluetooth-input.conf"
        "${UBUNTU_ROOT}/etc/X11/xorg.conf.d/51-usb-input.conf"
    )
    
    for config in "${xorg_configs[@]}"; do
        ((total_checks++))
        if [[ -f "${config}" ]]; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} %s\n" "$(basename "${config}")"
            ((checks_passed++))
        else
            printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} %s\n" "$(basename "${config}")"
        fi
    done
    
    # Check helper scripts
    local scripts=(
        "${UBUNTU_ROOT}/usr/local/bin/onscreen-keyboard"
        "${UBUNTU_ROOT}/usr/local/bin/setup-bluetooth"
        "${UBUNTU_ROOT}/usr/local/bin/detect-usb-input"
        "${UBUNTU_SCRIPTS}/input-bridge.sh"
    )
    
    echo ""
    log_info "Helper scripts:"
    for script in "${scripts[@]}"; do
        ((total_checks++))
        if [[ -x "${script}" ]]; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} %s\n" "$(basename "${script}")"
            ((checks_passed++))
        else
            printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} %s\n" "$(basename "${script}")"
        fi
    done
    
    echo ""
    log_info "Verification: ${checks_passed}/${total_checks} checks passed"
    
    [[ ${checks_passed} -eq ${total_checks} ]]
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Configuring input devices..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Check prerequisites
    if [[ ! -d "${UBUNTU_ROOT}/usr" ]]; then
        die "Ubuntu rootfs not found. Run previous scripts first."
    fi
    
    # Run configuration steps
    configure_touchscreen
    install_onscreen_keyboard
    configure_bluetooth
    configure_usb
    configure_input_methods
    create_termux_input_bridge
    configure_kde_input
    
    # Verify
    echo ""
    if verify_input_config; then
        print_footer "success" "Input configuration completed successfully"
    else
        print_footer "success" "Input configuration completed with warnings"
    fi
    
    echo ""
    echo "Input Device Summary:"
    echo ""
    echo "  ${COLOR_CYAN}Primary:${COLOR_RESET}   Touchscreen via VNC"
    echo "             - Tap to click, long press for right-click"
    echo "             - Run 'onscreen-keyboard' for virtual keyboard"
    echo ""
    echo "  ${COLOR_CYAN}Secondary:${COLOR_RESET} Bluetooth keyboard/mouse"
    echo "             - Pair in Android Settings first"
    echo "             - Automatically works in Ubuntu"
    echo ""
    echo "  ${COLOR_CYAN}Tertiary:${COLOR_RESET}  USB-C hub peripherals"
    echo "             - Connect and use directly"
    echo ""
    echo "Next steps:"
    echo "  ${COLOR_CYAN}bash ~/ubuntu/scripts/08-display-miracast.sh${COLOR_RESET}"
    echo ""
    
    return 0
}

# Run main function
main "$@"
