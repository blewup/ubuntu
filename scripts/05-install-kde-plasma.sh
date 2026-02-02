#!/data/data/com.termux/files/usr/bin/bash
#
# 05-install-kde-plasma.sh
# Install KDE Plasma 6 Desktop Environment
#
# This script installs and configures KDE Plasma optimized
# for the Termux proot environment.
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
source "${UBUNTU_PROJECT_ROOT}/lib/proot-utils.sh"

# Script configuration
SCRIPT_NAME="KDE Plasma Installation"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/05-install-kde-plasma.log"

# KDE package groups
KDE_CORE_PACKAGES=(
    "kde-plasma-desktop"
    "plasma-workspace"
    "plasma-desktop"
    "kwin-x11"
    "sddm"
    "breeze"
    "breeze-icon-theme"
    "breeze-cursor-theme"
)

KDE_APPS_PACKAGES=(
    "konsole"
    "dolphin"
    "kate"
    "ark"
    "gwenview"
    "okular"
    "spectacle"
    "kcalc"
    "kfind"
)

KDE_SYSTEM_PACKAGES=(
    "systemsettings"
    "kscreen"
    "powerdevil"
    "plasma-nm"
    "plasma-pa"
    "bluedevil"
    "kinfocenter"
    "kmenuedit"
)

SUPPORT_PACKAGES=(
    "dbus-x11"
    "xorg"
    "xserver-xorg-core"
    "x11-xserver-utils"
    "x11-utils"
    "xfonts-base"
    "xfonts-100dpi"
    "xfonts-75dpi"
    "fonts-dejavu"
    "fonts-liberation"
    "fonts-noto"
    "mesa-utils"
    "libgl1-mesa-dri"
    "vainfo"
    "htop"
    "neofetch"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

create_kde_install_script() {
    log_section "Creating KDE Installation Script for Ubuntu"
    
    local install_script="${UBUNTU_ROOT}/usr/local/bin/install-kde-plasma"
    
    cat > "${install_script}" << 'INSTALLEOF'
#!/bin/bash
#
# install-kde-plasma - KDE Plasma 6 Installation Script
# Run this inside Ubuntu proot environment
#

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          KDE Plasma 6 Installation for Ubuntu 26.04          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "This script needs root privileges."
    echo "Run with: sudo install-kde-plasma"
    exit 1
fi

# Use sudo if not root
SUDO=""
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
fi

# Estimated space required
REQUIRED_SPACE_MB=5000
AVAILABLE_SPACE=$(df -m /usr | tail -1 | awk '{print $4}')

echo "Space check:"
echo "  Required:  ~${REQUIRED_SPACE_MB}MB"
echo "  Available: ${AVAILABLE_SPACE}MB"
echo ""

if [[ ${AVAILABLE_SPACE} -lt ${REQUIRED_SPACE_MB} ]]; then
    echo "Warning: Low disk space. Installation may fail."
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# ============================================================================
# PHASE 1: System Update
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1/5: Updating System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

export DEBIAN_FRONTEND=noninteractive

${SUDO} apt-get update -y --allow-unauthenticated
${SUDO} apt-get upgrade -y --allow-unauthenticated

# ============================================================================
# PHASE 2: Install Dependencies
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2/5: Installing Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

DEPS=(
    apt-transport-https
    ca-certificates
    software-properties-common
    gnupg
    dbus-x11
    xorg
    x11-xserver-utils
    x11-utils
    xfonts-base
    fonts-dejavu
    fonts-liberation
    fonts-noto
    mesa-utils
    libgl1-mesa-dri
)

${SUDO} apt-get install -y --allow-unauthenticated "${DEPS[@]}"

# ============================================================================
# PHASE 3: Install KDE Plasma Core
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 3/5: Installing KDE Plasma Desktop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Install KDE Plasma desktop
${SUDO} apt-get install -y --allow-unauthenticated \
    kde-plasma-desktop \
    plasma-workspace \
    kwin-x11 \
    sddm \
    breeze \
    breeze-icon-theme

# ============================================================================
# PHASE 4: Install KDE Applications
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 4/5: Installing KDE Applications"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

KDE_APPS=(
    konsole
    dolphin
    kate
    ark
    gwenview
    okular
    spectacle
    kcalc
    systemsettings
    kscreen
    plasma-nm
    plasma-pa
    kinfocenter
)

${SUDO} apt-get install -y --allow-unauthenticated "${KDE_APPS[@]}" || {
    echo "Some KDE apps failed to install. Continuing..."
}

# ============================================================================
# PHASE 5: Configure KDE for PRoot
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 5/5: Configuring KDE for PRoot Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create KDE profile for proot
echo "Creating PRoot-optimized KDE configuration..."

# KDE startup script
cat > /usr/local/bin/start-kde << 'STARTKDE'
#!/bin/bash
# KDE Plasma Startup Script for PRoot

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE
export KDE_SESSION_VERSION=6
export QT_QPA_PLATFORM=xcb
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

# Start D-Bus
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --fork 2>/dev/null || true
fi

# GPU environment (Zink)
source /etc/profile.d/mesa-zink.sh 2>/dev/null || true
source /etc/profile.d/kde-gpu.sh 2>/dev/null || true

# Start Plasma
if command -v startplasma-x11 &>/dev/null; then
    exec startplasma-x11
else
    exec startkde
fi
STARTKDE

chmod +x /usr/local/bin/start-kde

# Disable problematic KDE services
cat > /etc/xdg/plasma-workspace/env/proot-fixes.sh << 'PROOTFIX'
#!/bin/bash
# Disable services that don't work in proot

# Disable power management (no /sys/power access)
export KDE_POWERDEVIL_NO_BACKEND=1

# Disable logout/shutdown options
export KDE_FULL_SESSION=false

# Use software cursor if hardware cursor fails
export KWIN_FORCE_SW_CURSOR=1

# Disable effects that cause issues
export KWIN_COMPOSE=O2ES

# Fix for some OpenGL issues
export QT_XCB_GL_INTEGRATION=xcb_egl
PROOTFIX

chmod +x /etc/xdg/plasma-workspace/env/proot-fixes.sh

# Create KDE configuration directory
mkdir -p /home/droid/.config/plasma-workspace/env
cp /etc/xdg/plasma-workspace/env/proot-fixes.sh /home/droid/.config/plasma-workspace/env/

# Disable baloo (file indexer - problematic in proot)
mkdir -p /home/droid/.config
cat > /home/droid/.config/baloofilerc << 'BALOO'
[Basic Settings]
Indexing-Enabled=false
BALOO

# Optimize KWin for proot
mkdir -p /home/droid/.config
cat > /home/droid/.config/kwinrc << 'KWINRC'
[Compositing]
Backend=OpenGL
GLCore=false
OpenGLIsUnsafe=false
Enabled=true
AnimationSpeed=3
HiddenPreviews=5

[Plugins]
blurEnabled=false
contrastEnabled=false
slideEnabled=false
zoomEnabled=false

[Effect-Blur]
BlurStrength=2

[Wayland]
InputMethod=
KWINRC

# Set permissions
chown -R 1000:1000 /home/droid/.config 2>/dev/null || true

# ============================================================================
# Cleanup
# ============================================================================

echo ""
echo "Cleaning up..."
${SUDO} apt-get autoremove -y --allow-unauthenticated
${SUDO} apt-get clean

# ============================================================================
# Complete
# ============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          KDE Plasma Installation Complete!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "To start KDE Plasma:"
echo "  1. Exit this shell (type 'exit')"
echo "  2. Run: ubuntu-kde"
echo ""
echo "Or from within Ubuntu:"
echo "  start-kde"
echo ""
echo "Connect via VNC to see the desktop."
echo ""
INSTALLEOF

    chmod +x "${install_script}"
    log_success "KDE installation script created: ${install_script}"
}

create_kde_config_files() {
    log_section "Creating KDE Configuration Files"
    
    local kde_config="${UBUNTU_ROOT}/home/droid/.config"
    ensure_dir "${kde_config}"
    
    # KDE globals
    cat > "${kde_config}/kdeglobals" << 'EOF'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark
TerminalApplication=konsole
TerminalService=konsole.desktop

[Icons]
Theme=breeze-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
ScrollbarLeftClickNavigatesByPage=false
ShowDeleteCommand=true

[Toolbar style]
ToolButtonStyle=TextBesideIcon
EOF

    # Konsole profile
    local konsole_dir="${kde_config}/konsole"
    ensure_dir "${konsole_dir}"
    
    cat > "${konsole_dir}/Default.profile" << 'EOF'
[Appearance]
ColorScheme=Breeze
Font=DejaVu Sans Mono,11,-1,5,50,0,0,0,0,0

[General]
Command=/bin/bash
Name=Default
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
HistorySize=10000

[Terminal Features]
BellMode=0
BlinkingCursorEnabled=true
EOF

    # Dolphin (file manager)
    cat > "${kde_config}/dolphinrc" << 'EOF'
[General]
GlobalViewProps=false
HomeUrl=file:///home/droid
RememberOpenedTabs=false
ShowFullPath=true
ShowFullPathInTitlebar=true

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
EOF

    # Set ownership
    chown -R 1000:1000 "${kde_config}" 2>/dev/null || true
    
    log_success "KDE configuration files created"
}

run_kde_installation() {
    log_section "Installing KDE Plasma in Ubuntu"
    
    log_info "This will install KDE Plasma inside the Ubuntu proot environment."
    log_info "This process may take 15-30 minutes depending on your internet speed."
    echo ""
    
    if ! confirm "Proceed with KDE installation?" "y"; then
        log_info "Installation cancelled"
        return 0
    fi
    
    # Run the installation inside proot
    log_info "Starting KDE installation..."
    log_info "You will see the installation progress inside Ubuntu."
    echo ""
    
    # Launch proot and run installation
    local launch_script="${UBUNTU_SCRIPTS}/launch-ubuntu.sh"
    
    if [[ -x "${launch_script}" ]]; then
        "${launch_script}" -c "/usr/local/bin/install-kde-plasma"
    else
        log_error "Launch script not found. Run 04-configure-proot.sh first."
        return 1
    fi
}

verify_kde_installation() {
    log_section "Verifying KDE Installation"
    
    local checks_passed=0
    local checks_failed=0
    
    # Check for KDE binaries
    local kde_bins=(
        "usr/bin/startplasma-x11:Plasma X11 Starter"
        "usr/bin/kwin_x11:KWin Window Manager"
        "usr/bin/plasmashell:Plasma Shell"
        "usr/bin/konsole:Konsole Terminal"
        "usr/bin/dolphin:Dolphin File Manager"
    )
    
    for item in "${kde_bins[@]}"; do
        local path="${item%%:*}"
        local desc="${item#*:}"
        
        if [[ -x "${UBUNTU_ROOT}/${path}" ]]; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} %s\n" "${desc}"
            ((checks_passed++))
        else
            printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} %s (not found)\n" "${desc}"
            ((checks_failed++))
        fi
    done
    
    echo ""
    
    if [[ ${checks_failed} -eq 0 ]]; then
        log_success "KDE Plasma appears to be installed correctly"
        return 0
    elif [[ ${checks_passed} -gt 0 ]]; then
        log_warn "KDE partially installed (${checks_passed} found, ${checks_failed} missing)"
        return 0
    else
        log_error "KDE does not appear to be installed"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Preparing KDE Plasma installation..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Check prerequisites
    if [[ ! -d "${UBUNTU_ROOT}/usr" ]]; then
        die "Ubuntu rootfs not found. Run 03-extract-rootfs.sh first."
    fi
    
    if [[ ! -x "${UBUNTU_SCRIPTS}/launch-ubuntu.sh" ]]; then
        die "Launch script not found. Run 04-configure-proot.sh first."
    fi
    
    # Check if proot environment is ready
    if ! proot_check "${UBUNTU_ROOT}"; then
        die "PRoot environment is not ready. Run 04-configure-proot.sh first."
    fi
    
    # Check if droid user is set up in /etc/passwd first
    if ! grep -q "^droid:" "${UBUNTU_ROOT}/etc/passwd" 2>/dev/null; then
        die "Droid user is not set in /etc/passwd. Run 03-extract-rootfs.sh to configure the rootfs properly."
    fi
    
    # Ensure droid user home directory exists
    if [[ ! -d "${UBUNTU_ROOT}/home/droid" ]]; then
        log_warn "Droid user home directory not found, creating..."
        mkdir -p "${UBUNTU_ROOT}/home/droid"
        chmod 755 "${UBUNTU_ROOT}/home/droid"
        chown 1000:1000 "${UBUNTU_ROOT}/home/droid" 2>/dev/null || true
    fi
    
    # Create installation script
    create_kde_install_script
    create_kde_config_files
    
    # Ask to run installation
    echo ""
    log_info "KDE installation script has been created inside Ubuntu."
    echo ""
    echo "You have two options:"
    echo ""
    echo "  ${COLOR_CYAN}Option 1:${COLOR_RESET} Run installation now (recommended)"
    echo "    The script will install KDE Plasma automatically."
    echo ""
    echo "  ${COLOR_CYAN}Option 2:${COLOR_RESET} Run installation manually later"
    echo "    Enter Ubuntu with: ${COLOR_GREEN}ubuntu${COLOR_RESET}"
    echo "    Then run: ${COLOR_GREEN}sudo install-kde-plasma${COLOR_RESET}"
    echo ""
    
    if confirm "Run KDE installation now?" "y"; then
        run_kde_installation
        echo ""
        verify_kde_installation
    else
        log_info "You can install KDE later by running:"
        log_info "  ubuntu -c 'sudo install-kde-plasma'"
    fi
    
    print_footer "success" "KDE Plasma setup completed"
    
    echo ""
    echo "Next steps:"
    echo "  1. ${COLOR_CYAN}bash ~/ubuntu/scripts/06-mesa-zink-setup.sh${COLOR_RESET}  (GPU acceleration)"
    echo "  2. ${COLOR_CYAN}ubuntu-kde${COLOR_RESET}  (start KDE Plasma)"
    echo ""
    
    return 0
}

# Run main function
main "$@"
