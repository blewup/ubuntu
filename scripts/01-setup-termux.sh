#!/data/data/com.termux/files/usr/bin/bash
#
# 01-setup-termux.sh
# Termux environment setup for Ubuntu 26.04 installation
#
# This script installs all required Termux packages and configures
# the environment for running Ubuntu in proot.
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
SCRIPT_NAME="Termux Environment Setup"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/01-setup-termux.log"

# ============================================================================
# PACKAGE DEFINITIONS
# ============================================================================

# Essential packages for proot and basic operations
ESSENTIAL_PACKAGES=(
    "proot"
    "proot-distro"
    "wget"
    "curl"
    "git"
    "tar"
    "gzip"
    "xz-utils"
    "zip"
    "unzip"
    "coreutils"
    "findutils"
    "grep"
    "sed"
    "gawk"
    "file"
    "tree"
    "ncurses-utils"
    "util-linux"
    "procps"
    "psmisc"
    "net-tools"
    "iproute2"
    "dnsutils"
    "openssh"
    "openssl"
)

# Termux API and automation packages
API_PACKAGES=(
    "termux-api"
    "termux-tools"
    "termux-services"
)

# X11 and display packages
DISPLAY_PACKAGES=(
    "x11-repo"
    "xorg-server-xvfb"
    "tigervnc"
    "xterm"
    "aterm"
    "fluxbox"
    "openbox"
    "xorg-xauth"
    "xorg-xhost"
    "xorg-xrandr"
    "xorg-xsetroot"
)

# Audio packages
AUDIO_PACKAGES=(
    "pulseaudio"
    "pavucontrol"
)

# GPU and graphics packages
GPU_PACKAGES=(
    "mesa"
    "mesa-vulkan-icd-freedreno"
    "vulkan-loader"
    "vulkan-tools"
    "libglvnd"
    "virglrenderer"
)

# Development tools
DEV_PACKAGES=(
    "build-essential"
    "clang"
    "cmake"
    "make"
    "pkg-config"
    "python"
    "python-pip"
    "nodejs"
)

# Networking and streaming packages
NETWORK_PACKAGES=(
    "scrcpy"
    "nmap"
    "netcat-openbsd"
    "socat"
)

# ============================================================================
# SETUP FUNCTIONS
# ============================================================================

setup_storage() {
    log_section "Setting Up Storage Access"
    
    if [[ -d "${HOME}/storage" ]]; then
        log_success "Storage already configured"
        return 0
    fi
    
    log_info "Requesting storage permission..."
    log_info "Please grant storage access when prompted"
    
    termux-setup-storage
    
    # Wait for user to grant permission
    sleep 2
    
    if [[ -d "${HOME}/storage" ]]; then
        log_success "Storage permission granted"
        
        # Create convenient symlinks
        log_info "Creating storage symlinks..."
        ln -sf "${HOME}/storage/shared" "${HOME}/sdcard" 2>/dev/null || true
        
        return 0
    else
        log_warn "Storage permission may not be granted"
        log_info "You can run 'termux-setup-storage' manually later"
        return 1
    fi
}

setup_repos() {
    log_section "Configuring Package Repositories"
    
    log_step 1 3 "Updating package lists..."
    if apt-get update -y 2>&1 | tee -a "${CURRENT_LOG_FILE}"; then
        log_success "Package lists updated"
    else
        log_warn "Some repositories may have issues (continuing anyway)"
    fi
    
    log_step 2 3 "Upgrading existing packages..."
    if apt-get upgrade -y 2>&1 | tee -a "${CURRENT_LOG_FILE}"; then
        log_success "Packages upgraded"
    else
        log_warn "Some packages may have upgrade issues"
    fi
    
    log_step 3 3 "Enabling X11 repository..."
    if pkg_installed "x11-repo"; then
        log_success "X11 repository already enabled"
    else
        if apt-get install -y x11-repo 2>&1 | tee -a "${CURRENT_LOG_FILE}"; then
            apt-get update -y 2>&1 | tee -a "${CURRENT_LOG_FILE}"
            log_success "X11 repository enabled"
        else
            log_warn "Could not enable X11 repository"
        fi
    fi
}

install_package_group() {
    local group_name="$1"
    shift
    local packages=("$@")
    
    log_info "Installing ${group_name}..."
    
    local installed=0
    local failed=0
    
    for pkg in "${packages[@]}"; do
        if pkg_installed "${pkg}"; then
            log_debug "Already installed: ${pkg}"
            ((installed++))
            continue
        fi
        
        printf "  ${COLOR_CYAN}Installing:${COLOR_RESET} %s..." "${pkg}"
        if apt-get install -y "${pkg}" >> "${CURRENT_LOG_FILE}" 2>&1; then
            printf " ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET}\n"
            ((installed++))
        else
            printf " ${COLOR_WARNING}${ICON_CROSS}${COLOR_RESET}\n"
            ((failed++))
        fi
    done
    
    log_info "${group_name}: ${installed} installed, ${failed} failed"
}

install_all_packages() {
    log_section "Installing Termux Packages"
    
    log_info "This may take several minutes depending on your connection..."
    echo ""
    
    install_package_group "Essential packages" "${ESSENTIAL_PACKAGES[@]}"
    install_package_group "API packages" "${API_PACKAGES[@]}"
    install_package_group "Display packages" "${DISPLAY_PACKAGES[@]}"
    install_package_group "Audio packages" "${AUDIO_PACKAGES[@]}"
    install_package_group "GPU packages" "${GPU_PACKAGES[@]}"
    install_package_group "Development tools" "${DEV_PACKAGES[@]}"
    install_package_group "Network packages" "${NETWORK_PACKAGES[@]}"
    
    log_success "Package installation complete"
}

configure_termux() {
    log_section "Configuring Termux Environment"
    
    # Create termux.properties if not exists
    log_step 1 5 "Configuring Termux properties..."
    local properties_file="${HOME}/.termux/termux.properties"
    ensure_dir "${HOME}/.termux"
    
    if [[ ! -f "${properties_file}" ]]; then
        cat > "${properties_file}" << 'EOF'
# Termux properties for Ubuntu 26.04 project
# Allow external apps to execute Termux commands
allow-external-apps = true

# Extra keys for terminal (useful for KDE/desktop usage)
extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]

# Bell behavior
bell-character = vibrate

# Fullscreen mode
fullscreen = false

# Terminal margin
terminal-margin-horizontal = 3
terminal-margin-vertical = 3

# Use black color for drawer and dialogs
use-black-ui = true
EOF
        log_success "Termux properties created"
    else
        log_info "Termux properties already exists"
    fi
    
    # Configure bash profile for Ubuntu project
    log_step 2 5 "Configuring shell environment..."
    local bashrc="${HOME}/.bashrc"
    local marker="# Ubuntu 26.04 Resolute Project"
    
    if ! grep -q "${marker}" "${bashrc}" 2>/dev/null; then
        cat >> "${bashrc}" << 'EOF'

# Ubuntu 26.04 Resolute Project
# Added by 01-setup-termux.sh

# Project paths
export UBUNTU_PROJECT_ROOT="${HOME}/ubuntu"
export UBUNTU_ROOT="${UBUNTU_PROJECT_ROOT}/rootfs"

# Source Ubuntu project functions
if [[ -f "${UBUNTU_PROJECT_ROOT}/lib/functions.sh" ]]; then
    source "${UBUNTU_PROJECT_ROOT}/lib/functions.sh"
fi

# Ubuntu launch aliases
alias ubuntu='${UBUNTU_PROJECT_ROOT}/scripts/launch-ubuntu.sh'
alias ubuntu-kde='${UBUNTU_PROJECT_ROOT}/scripts/launch-ubuntu.sh --kde'
alias ubuntu-shell='${UBUNTU_PROJECT_ROOT}/scripts/launch-ubuntu.sh --shell'
alias ubuntu-update='${UBUNTU_PROJECT_ROOT}/scripts/launch-ubuntu.sh --update'
alias ubuntu-stop='pkill -f "proot.*ubuntu"'

# Quick access
alias cdubuntu='cd ${UBUNTU_PROJECT_ROOT}'
alias cdroot='cd ${UBUNTU_ROOT}'
alias logs='tail -f ${UBUNTU_PROJECT_ROOT}/logs/*.log'

# Display shortcuts
alias vnc-start='vncserver -localhost no -geometry 1920x1080 :1'
alias vnc-stop='vncserver -kill :1'
alias vnc-list='vncserver -list'

# Helpful functions
ubuntu-logs() {
    local log="${UBUNTU_PROJECT_ROOT}/logs/${1:-ubuntu-setup}.log"
    if [[ -f "${log}" ]]; then
        less +G "${log}"
    else
        echo "Available logs:"
        ls -la "${UBUNTU_PROJECT_ROOT}/logs/"
    fi
}
EOF
        log_success "Shell environment configured"
    else
        log_info "Shell environment already configured"
    fi
    
    # Configure PulseAudio for Termux
    log_step 3 5 "Configuring PulseAudio..."
    local pulse_config="${HOME}/.config/pulse/default.pa"
    ensure_dir "${HOME}/.config/pulse"
    
    if [[ ! -f "${pulse_config}" ]]; then
        cat > "${pulse_config}" << 'EOF'
#!/data/data/com.termux/files/usr/bin/pulseaudio -nF

# PulseAudio configuration for Ubuntu proot
.include /data/data/com.termux/files/usr/etc/pulse/default.pa

# Load TCP module for proot access
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Load null sink for apps that require audio
load-module module-null-sink sink_name=dummy
load-module module-null-source source_name=dummy_mic

# Set default output
set-default-sink dummy
EOF
        log_success "PulseAudio configured"
    else
        log_info "PulseAudio already configured"
    fi
    
    # Create project directory structure
    log_step 4 5 "Creating project directories..."
    local dirs=(
        "${UBUNTU_PROJECT_ROOT}"
        "${UBUNTU_PROJECT_ROOT}/rootfs"
        "${UBUNTU_PROJECT_ROOT}/scripts"
        "${UBUNTU_PROJECT_ROOT}/lib"
        "${UBUNTU_PROJECT_ROOT}/config"
        "${UBUNTU_PROJECT_ROOT}/cache"
        "${UBUNTU_PROJECT_ROOT}/logs"
        "${UBUNTU_PROJECT_ROOT}/mesa-zink"
        "${UBUNTU_PROJECT_ROOT}/backup"
    )
    
    for dir in "${dirs[@]}"; do
        ensure_dir "${dir}"
    done
    log_success "Project directories created"
    
    # Configure VNC
    log_step 5 5 "Configuring VNC..."
    local vnc_dir="${HOME}/.vnc"
    ensure_dir "${vnc_dir}"
    
    if [[ ! -f "${vnc_dir}/xstartup" ]]; then
        cat > "${vnc_dir}/xstartup" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# VNC startup script for Ubuntu proot

# Unset session manager to avoid warnings
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Set display
export DISPLAY=:1

# Start window manager (lightweight for VNC)
openbox-session &

# Start a terminal
xterm &
EOF
        chmod +x "${vnc_dir}/xstartup"
        log_success "VNC configured"
    else
        log_info "VNC already configured"
    fi
}

setup_sdcard_structure() {
    log_section "Setting Up /sdcard Structure for /home/droid"
    
    local sdcard="/sdcard"
    
    if [[ ! -d "${sdcard}" ]] || [[ ! -w "${sdcard}" ]]; then
        log_warn "Cannot access /sdcard - skipping structure setup"
        log_info "Run 'termux-setup-storage' and retry"
        return 1
    fi
    
    # Create standard home directories on sdcard
    local home_dirs=(
        "Documents"
        "Downloads"
        "Projects"
        "Pictures"
        "Music"
        "Videos"
        ".config"
        ".local"
        ".cache"
    )
    
    log_info "Creating home directory structure on /sdcard..."
    for dir in "${home_dirs[@]}"; do
        local full_path="${sdcard}/${dir}"
        if [[ ! -d "${full_path}" ]]; then
            mkdir -p "${full_path}" 2>/dev/null && log_debug "Created: ${full_path}" || true
        fi
    done
    
    # Create a marker file
    cat > "${sdcard}/.ubuntu-home-marker" << EOF
# This directory is bind-mounted as /home/droid in Ubuntu proot
# Created: $(date)
# Project: Ubuntu 26.04 Resolute on Termux
EOF
    
    log_success "Home directory structure created on /sdcard"
    
    # Create backup directory
    ensure_dir "/sdcard/ubuntu-backup"
    log_success "Backup directory created: /sdcard/ubuntu-backup"
}

verify_installation() {
    log_section "Verifying Installation"
    
    local checks_passed=0
    local checks_failed=0
    
    # Check critical commands
    local critical_commands=(
        "proot:PRoot container"
        "wget:Download utility"
        "vncserver:VNC server"
        "pulseaudio:Audio server"
        "Xvfb:Virtual framebuffer"
    )
    
    log_info "Checking critical components..."
    for item in "${critical_commands[@]}"; do
        local cmd="${item%%:*}"
        local desc="${item#*:}"
        
        if command_exists "${cmd}"; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} %s (%s)\n" "${desc}" "${cmd}"
            ((checks_passed++))
        else
            printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} %s (%s) - NOT FOUND\n" "${desc}" "${cmd}"
            ((checks_failed++))
        fi
    done
    
    # Check GPU/Vulkan
    echo ""
    log_info "Checking GPU support..."
    if command_exists vulkaninfo; then
        if vulkaninfo --summary 2>/dev/null | grep -qi "gpu\|adreno"; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Vulkan GPU detected\n"
            ((checks_passed++))
        else
            printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} Vulkan available but GPU not detected (may work in proot)\n"
            ((checks_passed++))
        fi
    else
        printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} vulkaninfo not available\n"
    fi
    
    # Check storage
    echo ""
    log_info "Checking storage access..."
    if [[ -w "/sdcard" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} /sdcard is writable\n"
        ((checks_passed++))
    else
        printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} /sdcard is not writable\n"
        ((checks_failed++))
    fi
    
    # Summary
    echo ""
    log_info "Verification: ${checks_passed} passed, ${checks_failed} failed"
    
    [[ ${checks_failed} -eq 0 ]]
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Starting Termux environment setup..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Check if running in Termux
    if ! is_termux; then
        die "This script must be run in Termux"
    fi
    
    # Run setup steps
    setup_storage || true  # Non-fatal if fails
    setup_repos
    install_all_packages
    configure_termux
    setup_sdcard_structure || true  # Non-fatal if fails
    
    if verify_installation; then
        print_footer "success" "Termux environment setup completed successfully"
        
        echo ""
        echo "Next steps:"
        echo "  1. Restart Termux to load new shell configuration"
        echo "  2. Run: ${COLOR_CYAN}bash ~/ubuntu/scripts/02-setup-shizuku.sh${COLOR_RESET}"
        echo ""
        echo "Or if you don't need Shizuku enhanced features:"
        echo "  2. Run: ${COLOR_CYAN}bash ~/ubuntu/scripts/03-extract-rootfs.sh${COLOR_RESET}"
        echo ""
        
        return 0
    else
        print_footer "error" "Setup completed with errors"
        return 1
    fi
}

# Run main function
main "$@"
