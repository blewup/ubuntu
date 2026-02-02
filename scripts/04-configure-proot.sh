#!/data/data/com.termux/files/usr/bin/bash
#
# 04-configure-proot.sh
# Configure PRoot environment for Ubuntu 26.04
#
# This script sets up the PRoot configuration, creates launch scripts,
# and optimizes the environment for best performance.
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
SCRIPT_NAME="PRoot Configuration"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/04-configure-proot.log"

# ============================================================================
# PROOT CONFIGURATION
# ============================================================================

create_proot_config() {
    log_section "Creating PRoot Configuration"
    
    local config_file="${UBUNTU_CONFIG}/proot.conf"
    ensure_dir "${UBUNTU_CONFIG}"
    
    cat > "${config_file}" << 'EOF'
# proot.conf - PRoot Configuration for Ubuntu 26.04 on Termux
# This file is sourced by launch scripts

# ============================================================================
# PATHS
# ============================================================================

UBUNTU_ROOTFS="${HOME}/ubuntu/rootfs"
UBUNTU_HOME_BIND="/sdcard"
UBUNTU_HOME_TARGET="/home/droid"

# ============================================================================
# PROOT BASE ARGUMENTS
# ============================================================================

# Determine working directory based on what exists
proot_get_cwd() {
    if [[ -d "${UBUNTU_ROOTFS}/home/droid" ]]; then
        echo "/home/droid"
    elif [[ -d "${UBUNTU_ROOTFS}/root" ]]; then
        echo "/root"
    else
        echo "/"
    fi
}

# Core proot options with short flags
PROOT_CORE_ARGS=(
    "--link2symlink"           # Handle symlinks properly
    "--kill-on-exit"           # Clean up child processes on exit
    "-0"                       # Fake root user (uid 0) - short flag
    "-r" "${UBUNTU_ROOTFS}"    # Root filesystem - short flag
)

# ============================================================================
# BIND MOUNTS
# ============================================================================

# Essential system mounts
PROOT_SYSTEM_BINDS=(
    "/dev"
    "/dev/urandom:/dev/random"
    "/proc"
    "/sys"
)

# Termux integration
PROOT_TERMUX_BINDS=(
    "/data/data/com.termux/files/usr/tmp:/tmp"
)

# User data mounts
PROOT_USER_BINDS=(
    "${UBUNTU_HOME_BIND}:${UBUNTU_HOME_TARGET}"
    "/sdcard"
    "/storage"
)

# GPU device mounts (added if accessible)
PROOT_GPU_BINDS=()

# Check for Adreno GPU device
if [[ -e "/dev/kgsl-3d0" ]]; then
    PROOT_GPU_BINDS+=("/dev/kgsl-3d0")
fi

# Check for DRI devices
if [[ -d "/dev/dri" ]]; then
    for dri_dev in /dev/dri/*; do
        [[ -e "${dri_dev}" ]] && PROOT_GPU_BINDS+=("${dri_dev}")
    done
fi

# Check for ion/dma-heap (memory allocators)
[[ -e "/dev/ion" ]] && PROOT_GPU_BINDS+=("/dev/ion")
for heap in /dev/dma_heap/*; do
    [[ -e "${heap}" ]] && PROOT_GPU_BINDS+=("${heap}")
done

# ============================================================================
# ENVIRONMENT VARIABLES (as --env= flags for proot)
# ============================================================================

PROOT_ENV_ARGS=(
    "--env" "HOME=${UBUNTU_HOME_TARGET}"
    "--env" "USER=droid"
    "--env" "LOGNAME=droid"
    "--env" "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    "--env" "TERM=${TERM:-xterm-256color}"
    "--env" "LANG=C.UTF-8"
    "--env" "LC_ALL=C.UTF-8"
    "--env" "TMPDIR=/tmp"
    "--env" "SHELL=/bin/bash"
    "--env" "DISPLAY=${DISPLAY:-:1}"
    "--env" "PULSE_SERVER=tcp:127.0.0.1:4713"
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Build complete bind arguments using short flags
build_bind_args() {
    local args=""
    
    for bind in "${PROOT_SYSTEM_BINDS[@]}"; do
        args+=" -b ${bind}"
    done
    
    for bind in "${PROOT_TERMUX_BINDS[@]}"; do
        args+=" -b ${bind}"
    done
    
    for bind in "${PROOT_USER_BINDS[@]}"; do
        args+=" -b ${bind}"
    done
    
    for bind in "${PROOT_GPU_BINDS[@]}"; do
        args+=" -b ${bind}"
    done
    
    echo "${args}"
}

# Environment variables are now set inside rootfs via /etc/profile.d/termux.sh
# This function kept for compatibility but returns empty
build_env_args() {
    echo ""
}

# Build complete proot command using short flags
build_proot_command() {
    local shell="${1:-/bin/bash}"
    local login="${2:---login}"
    local cwd
    cwd=$(proot_get_cwd)
    
    echo "proot ${PROOT_CORE_ARGS[*]} -w ${cwd} $(build_bind_args) ${shell} ${login}"
}
EOF

    log_success "PRoot configuration created: ${config_file}"
}


create_quick_commands() {
    log_section "Creating Quick Command Scripts"
    
    # ubuntu-shell - Quick shell access
    cat > "${UBUNTU_SCRIPTS}/ubuntu-shell" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "$(dirname "$0")/launch-ubuntu.sh" --shell "$@"
EOF
    chmod +x "${UBUNTU_SCRIPTS}/ubuntu-shell"
    
    # ubuntu-kde - Quick KDE access
    cat > "${UBUNTU_SCRIPTS}/ubuntu-kde" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "$(dirname "$0")/launch-ubuntu.sh" --kde "$@"
EOF
    chmod +x "${UBUNTU_SCRIPTS}/ubuntu-kde"
    
    # ubuntu-run - Run command in Ubuntu
    cat > "${UBUNTU_SCRIPTS}/ubuntu-run" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "$(dirname "$0")/launch-ubuntu.sh" -c "$*"
EOF
    chmod +x "${UBUNTU_SCRIPTS}/ubuntu-run"
    
    log_success "Quick command scripts created"
}

create_termux_shortcuts() {
    log_section "Creating Termux Shortcuts"
    
    local shortcuts_dir="${HOME}/.shortcuts"
    ensure_dir "${shortcuts_dir}"
    
    # Ubuntu Shell shortcut
    cat > "${shortcuts_dir}/Ubuntu Shell" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
~/ubuntu/scripts/launch-ubuntu.sh --shell
EOF
    chmod +x "${shortcuts_dir}/Ubuntu Shell"
    
    # Ubuntu KDE shortcut
    cat > "${shortcuts_dir}/Ubuntu KDE" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
~/ubuntu/scripts/launch-ubuntu.sh --kde
EOF
    chmod +x "${shortcuts_dir}/Ubuntu KDE"
    
    log_success "Termux shortcuts created"
}

update_bashrc() {
    log_section "Updating Shell Configuration"
    
    local bashrc="${HOME}/.bashrc"
    local marker="# Ubuntu 26.04 PRoot Configuration"
    
    if grep -q "${marker}" "${bashrc}" 2>/dev/null; then
        log_info "Shell configuration already updated"
        return 0
    fi
    
    cat >> "${bashrc}" << 'BASHRCEOF'

# Ubuntu 26.04 PRoot Configuration
# Added by 04-configure-proot.sh

# Quick access aliases
alias ubuntu='~/ubuntu/scripts/launch-ubuntu.sh'
alias ubuntu-shell='~/ubuntu/scripts/launch-ubuntu.sh --shell'
alias ubuntu-kde='~/ubuntu/scripts/launch-ubuntu.sh --kde'

# Run command in Ubuntu
urun() {
    ~/ubuntu/scripts/launch-ubuntu.sh -c "$*"
}

# Quick navigation
alias cdubuntu='cd ~/ubuntu'
alias cdroot='cd ~/ubuntu/rootfs'
alias cdscripts='cd ~/ubuntu/scripts'

# Logs
alias ubuntu-logs='ls -la ~/ubuntu/logs/'
BASHRCEOF

    log_success "Shell configuration updated"
}

optimize_proot() {
    log_section "Optimizing PRoot Performance"
    
    # Create proot optimization script
    local optimize_script="${UBUNTU_SCRIPTS}/optimize-proot.sh"
    
    cat > "${optimize_script}" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# optimize-proot.sh - PRoot Performance Optimizations
#

echo "Applying PRoot optimizations..."

UBUNTU_ROOT="${HOME}/ubuntu/rootfs"

# 1. Disable unnecessary services in Ubuntu
echo "  → Disabling unnecessary services..."
services_to_disable=(
    "systemd-journald"
    "systemd-udevd"
    "systemd-logind"
    "systemd-resolved"
    "systemd-timesyncd"
    "snapd"
    "unattended-upgrades"
)

for service in "${services_to_disable[@]}"; do
    if [[ -f "${UBUNTU_ROOT}/etc/systemd/system/${service}.service" ]] || \
       [[ -f "${UBUNTU_ROOT}/lib/systemd/system/${service}.service" ]]; then
        # Mask the service
        ln -sf /dev/null "${UBUNTU_ROOT}/etc/systemd/system/${service}.service" 2>/dev/null || true
    fi
done

# 2. Optimize apt
echo "  → Optimizing APT..."
cat > "${UBUNTU_ROOT}/etc/apt/apt.conf.d/99performance" << 'APTEOF'
# Performance optimizations for proot
Acquire::Languages "none";
Acquire::GzipIndexes "true";
Acquire::CompressionTypes::Order:: "gz";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Get::Assume-Yes "true";
APTEOF

# 3. Disable man-db updates (slow in proot)
echo "  → Disabling man-db triggers..."
if [[ -f "${UBUNTU_ROOT}/var/lib/dpkg/triggers/File" ]]; then
    sed -i '/man-db/d' "${UBUNTU_ROOT}/var/lib/dpkg/triggers/File" 2>/dev/null || true
fi

# 4. Create RAM disk for tmp in proot (symlink to Termux tmp)
echo "  → Optimizing /tmp..."
rm -rf "${UBUNTU_ROOT}/tmp" 2>/dev/null || true
mkdir -p "${UBUNTU_ROOT}/tmp"
chmod 1777 "${UBUNTU_ROOT}/tmp"

# 5. Optimize ld.so.cache updates
echo "  → Configuring ldconfig..."
cat > "${UBUNTU_ROOT}/etc/ld.so.conf.d/proot.conf" << 'LDEOF'
# Additional library paths for proot
/data/data/com.termux/files/usr/lib
LDEOF

echo ""
echo "Optimizations applied!"
echo "These changes improve PRoot performance on Android."
EOF

    chmod +x "${optimize_script}"
    
    # Run optimizations
    bash "${optimize_script}"
    
    log_success "PRoot optimizations applied"
}

verify_configuration() {
    log_section "Verifying Configuration"
    
    local issues=0
    
    # Check config file
    if [[ -f "${UBUNTU_CONFIG}/proot.conf" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} PRoot configuration file\n"
    else
        printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} PRoot configuration file missing\n"
        ((issues++))
    fi
    
    # Check launch script
    if [[ -x "${UBUNTU_SCRIPTS}/launch-ubuntu.sh" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Launch script\n"
    else
        printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} Launch script missing or not executable\n"
        ((issues++))
    fi
    
    # Check rootfs
    if [[ -d "${UBUNTU_ROOT}/usr" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Ubuntu rootfs\n"
    else
        printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} Ubuntu rootfs not found\n"
        ((issues++))
    fi
    
    # Check proot command
    if command_exists proot; then
        local proot_version
        proot_version=$(proot --version 2>&1 | head -1 || echo "Unknown")
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} PRoot: ${proot_version}\n"
    else
        printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} PRoot not installed\n"
        ((issues++))
    fi
    
    # Check quick commands
    local quick_cmds=("ubuntu-shell" "ubuntu-kde" "ubuntu-run")
    local quick_ok=0
    for cmd in "${quick_cmds[@]}"; do
        [[ -x "${UBUNTU_SCRIPTS}/${cmd}" ]] && ((quick_ok++))
    done
    printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Quick commands: ${quick_ok}/${#quick_cmds[@]}\n"
    
    # Check shortcuts
    if [[ -d "${HOME}/.shortcuts" ]] && [[ -n "$(ls -A "${HOME}/.shortcuts" 2>/dev/null)" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Termux shortcuts\n"
    else
        printf "  ${COLOR_INFO}${ICON_INFO}${COLOR_RESET} Termux shortcuts (optional)\n"
    fi
    
    return ${issues}
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    ensure_dir "${UBUNTU_CONFIG}"
    
    log_info "Configuring PRoot environment..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Check prerequisites
    if [[ ! -d "${UBUNTU_ROOT}/usr" ]]; then
        die "Ubuntu rootfs not found. Run 03-extract-rootfs.sh first."
    fi
    
    # Run configuration steps
    create_proot_config
    create_quick_commands
    create_termux_shortcuts
    update_bashrc
    optimize_proot
    
    # Verify
    echo ""
    if verify_configuration; then
        print_footer "success" "PRoot configuration completed successfully"
    else
        print_footer "success" "PRoot configuration completed with warnings"
    fi
    
    echo ""
    echo "You can now launch Ubuntu with:"
    echo "  ${COLOR_CYAN}~/ubuntu/scripts/launch-ubuntu.sh${COLOR_RESET}"
    echo ""
    echo "Or use the aliases (after restarting shell):"
    echo "  ${COLOR_CYAN}ubuntu${COLOR_RESET}        - Start Ubuntu shell"
    echo "  ${COLOR_CYAN}ubuntu-kde${COLOR_RESET}    - Start KDE Plasma"
    echo "  ${COLOR_CYAN}ubuntu-status${COLOR_RESET} - Show system status"
    echo ""
    echo "Next steps:"
    echo "  1. ${COLOR_CYAN}source ~/.bashrc${COLOR_RESET}  (or restart Termux)"
    echo "  2. ${COLOR_CYAN}ubuntu --first-boot${COLOR_RESET}  (initial Ubuntu setup)"
    echo "  3. ${COLOR_CYAN}bash ~/ubuntu/scripts/05-install-kde-plasma.sh${COLOR_RESET}"
    echo ""
    
    return 0
}

# Run main function
main "$@"
