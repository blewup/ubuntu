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

# ============================================================================
# PROOT BASE ARGUMENTS (short form)
# ============================================================================

# Core proot options using short flags
PROOT_CORE_ARGS=(
    "-0"                           # Fake root user (uid 0)
    "-r" "${UBUNTU_ROOTFS}"        # Root filesystem
    "-w" "/root"                   # Working directory
)

# ============================================================================
# BIND MOUNTS (short form)
# ============================================================================

# Essential system mounts
PROOT_SYSTEM_BINDS=(
    "-b" "/dev"
    "-b" "/proc"
    "-b" "/sys"
)

# Termux integration
PROOT_TERMUX_BINDS=(
    "-b" "/data/data/com.termux/files/usr/tmp:/tmp"
)

# User data mounts
PROOT_USER_BINDS=(
    "-b" "/sdcard"
    "-b" "/storage"
)

# GPU device mounts (added if accessible)
PROOT_GPU_BINDS=()

# Check for Adreno GPU device
if [[ -e "/dev/kgsl-3d0" ]]; then
    PROOT_GPU_BINDS+=("-b" "/dev/kgsl-3d0")
fi

# Check for DRI devices
if [[ -d "/dev/dri" ]]; then
    PROOT_GPU_BINDS+=("-b" "/dev/dri")
fi

# Check for ion/dma-heap (memory allocators)
[[ -e "/dev/ion" ]] && PROOT_GPU_BINDS+=("-b" "/dev/ion")

# Android system paths (needed on some devices)
[[ -d "/system" ]] && PROOT_SYSTEM_BINDS+=("-b" "/system")
[[ -d "/apex" ]] && PROOT_SYSTEM_BINDS+=("-b" "/apex")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Build complete bind arguments
build_bind_args() {
    echo "${PROOT_SYSTEM_BINDS[*]} ${PROOT_TERMUX_BINDS[*]} ${PROOT_USER_BINDS[*]} ${PROOT_GPU_BINDS[*]}"
}

# Build complete proot command
build_proot_command() {
    local shell="${1:-/bin/bash}"
    
    echo "proot ${PROOT_CORE_ARGS[*]} $(build_bind_args) ${shell}"
}
EOF

    log_success "PRoot configuration created: ${config_file}"
}

create_launch_script() {
    log_section "Creating Main Launch Script"
    
    local launch_script="${UBUNTU_SCRIPTS}/launch-ubuntu.sh"
    
    cat > "${launch_script}" << 'LAUNCHEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# launch-ubuntu.sh - Ubuntu 26.04 Launcher for Termux
#
# Usage:
#   launch-ubuntu.sh              # Start shell
#   launch-ubuntu.sh --kde        # Start with KDE
#   launch-ubuntu.sh --vnc        # Start VNC server
#   launch-ubuntu.sh --shell      # Start shell only
#   launch-ubuntu.sh --update     # Update Ubuntu packages
#   launch-ubuntu.sh --miracast   # Start with Miracast display
#   launch-ubuntu.sh --scrcpy     # Start with Scrcpy display
#   launch-ubuntu.sh -c "command" # Run single command
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
UBUNTU_ROOTFS="${UBUNTU_PROJECT_ROOT}/rootfs"
UBUNTU_CONFIG="${UBUNTU_PROJECT_ROOT}/config"
UBUNTU_LOGS="${UBUNTU_PROJECT_ROOT}/logs"

# Source libraries
source "${UBUNTU_PROJECT_ROOT}/lib/colors.sh" 2>/dev/null || true
source "${UBUNTU_PROJECT_ROOT}/lib/functions.sh" 2>/dev/null || true

# Source proot configuration
if [[ -f "${UBUNTU_CONFIG}/proot.conf" ]]; then
    source "${UBUNTU_CONFIG}/proot.conf"
else
    echo "Error: proot.conf not found. Run 04-configure-proot.sh first."
    exit 1
fi

# Runtime state
VNC_DISPLAY="${VNC_DISPLAY:-1}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
MIRACAST_ACTIVE=false
SCRCPY_ACTIVE=false

# ============================================================================
# PRE-LAUNCH CHECKS
# ============================================================================

pre_launch_checks() {
    # Check rootfs exists
    if [[ ! -d "${UBUNTU_ROOTFS}/usr" ]]; then
        echo "${COLOR_ERROR}Error: Ubuntu rootfs not found at ${UBUNTU_ROOTFS}${COLOR_RESET}"
        echo "Run 03-extract-rootfs.sh first."
        exit 1
    fi
    
    # Check essential binaries exist in rootfs
    local essential_bins=(
        "/bin/bash"
        "/bin/sh"
    )
    local missing_bins=()
    
    for bin in "${essential_bins[@]}"; do
        # Check both regular file and symlink cases
        if [[ ! -e "${UBUNTU_ROOTFS}${bin}" ]]; then
            # Also check usr-merged paths (Ubuntu uses merged /usr)
            local alt_path="${bin}"
            if [[ "${bin}" == "/bin/"* ]]; then
                alt_path="/usr${bin}"
            fi
            if [[ ! -e "${UBUNTU_ROOTFS}${alt_path}" ]]; then
                missing_bins+=("${bin}")
            fi
        fi
    done
    
    if [[ ${#missing_bins[@]} -gt 0 ]]; then
        echo "${COLOR_ERROR}Error: Ubuntu rootfs appears incomplete or corrupted${COLOR_RESET}"
        echo "Missing essential binaries:"
        for bin in "${missing_bins[@]}"; do
            echo "  - ${bin}"
        done
        echo ""
        echo "The rootfs extraction may have failed. Please:"
        echo "  1. Remove the incomplete rootfs: rm -rf ${UBUNTU_ROOTFS}"
        echo "  2. Re-run the extraction: bash ~/ubuntu/scripts/03-extract-rootfs.sh"
        exit 1
    fi
    
    # Check proot is available
    if ! command -v proot &>/dev/null; then
        echo "${COLOR_ERROR}Error: proot not found. Install with: pkg install proot${COLOR_RESET}"
        exit 1
    fi
    
    # Create and set up Termux tmp directory for proot
    local termux_tmp="/data/data/com.termux/files/usr/tmp"
    mkdir -p "${termux_tmp}" 2>/dev/null || true
    chmod 1777 "${termux_tmp}" 2>/dev/null || true
    
    # Create XDG runtime directory in Termux tmp
    mkdir -p "${termux_tmp}/runtime-droid" 2>/dev/null || true
    chmod 700 "${termux_tmp}/runtime-droid" 2>/dev/null || true
    
    # Clean up stale proot temp files that may cause "Function not implemented" errors
    # These files are created by proot and can become stale after crashes or improper shutdowns
    # Stale threshold in minutes - files older than this are considered safe to remove
    local stale_threshold_minutes=60
    find "${termux_tmp}" -maxdepth 1 -name "proot-*" \( -type f -o -type d \) -mmin +${stale_threshold_minutes} -exec rm -rf {} \; 2>/dev/null || true
    
    # Ensure /home/droid exists in rootfs with proper setup
    local rootfs_home="${UBUNTU_ROOTFS}/home/droid"
    if [[ ! -d "${rootfs_home}" ]]; then
        echo "  ${COLOR_CYAN}→${COLOR_RESET} Creating /home/droid in rootfs..."
        mkdir -p "${rootfs_home}"
        mkdir -p "${rootfs_home}/.config"
        mkdir -p "${rootfs_home}/.local/share"
        mkdir -p "${rootfs_home}/.cache"
        chmod 755 "${rootfs_home}"
        chown -R 1000:1000 "${rootfs_home}" 2>/dev/null || true
    fi
    
    # Ensure home directory structure exists on sdcard (for bind mount)
    local home_dirs=("Documents" "Downloads" "Projects" "Pictures" "Music" "Videos" ".config" ".local" ".cache")
    for dir in "${home_dirs[@]}"; do
        mkdir -p "/sdcard/${dir}" 2>/dev/null || true
    done
    
    # Ensure tmp directory exists in rootfs
    mkdir -p "${UBUNTU_ROOTFS}/tmp" 2>/dev/null || true
    chmod 1777 "${UBUNTU_ROOTFS}/tmp" 2>/dev/null || true
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

start_pulseaudio() {
    if ! pgrep -x pulseaudio &>/dev/null; then
        echo "  ${COLOR_CYAN}→${COLOR_RESET} Starting PulseAudio..."
        pulseaudio --start \
            --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
            --exit-idle-time=-1 2>/dev/null || true
        sleep 1
        if pgrep -x pulseaudio &>/dev/null; then
            echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} PulseAudio started"
        else
            echo "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} PulseAudio may have issues"
        fi
    else
        echo "  ${COLOR_SUCCESS}•${COLOR_RESET} PulseAudio already running"
    fi
}

start_vnc() {
    local geometry="${1:-${VNC_GEOMETRY}}"
    local display="${2:-${VNC_DISPLAY}}"
    
    if pgrep -f "Xvnc.*:${display}" &>/dev/null; then
        echo "  ${COLOR_SUCCESS}•${COLOR_RESET} VNC already running on :${display}"
        return 0
    fi
    
    echo "  ${COLOR_CYAN}→${COLOR_RESET} Starting VNC server..."
    
    # Kill any stale locks
    rm -f "/tmp/.X${display}-lock" 2>/dev/null || true
    rm -f "/tmp/.X11-unix/X${display}" 2>/dev/null || true
    
    # Start VNC
    if vncserver -localhost no -geometry "${geometry}" -depth 24 ":${display}" 2>/dev/null; then
        sleep 2
        if pgrep -f "Xvnc.*:${display}" &>/dev/null; then
            local ip
            ip=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "localhost")
            echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} VNC started on :${display}"
            echo "  ${COLOR_INFO}${ICON_INFO}${COLOR_RESET} Connect to: ${ip}:590${display}"
            return 0
        fi
    fi
    
    echo "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} VNC may have issues starting"
    return 1
}

stop_vnc() {
    local display="${1:-${VNC_DISPLAY}}"
    
    if pgrep -f "Xvnc.*:${display}" &>/dev/null; then
        echo "  ${COLOR_CYAN}→${COLOR_RESET} Stopping VNC on :${display}..."
        vncserver -kill ":${display}" 2>/dev/null || true
        echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} VNC stopped"
    fi
}

start_services() {
    echo ""
    echo "${COLOR_HEADER}Starting services...${COLOR_RESET}"
    start_pulseaudio
}

stop_services() {
    echo ""
    echo "${COLOR_HEADER}Stopping services...${COLOR_RESET}"
    stop_vnc
}

# ============================================================================
# LAUNCH FUNCTIONS
# ============================================================================

print_banner() {
    echo ""
    echo "${COLOR_BOLD_CYAN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo "${COLOR_BOLD_CYAN}║${COLOR_RESET}     ${COLOR_BOLD}Ubuntu 26.04 Resolute${COLOR_RESET} on ${COLOR_GREEN}Termux${COLOR_RESET}                       ${COLOR_BOLD_CYAN}║${COLOR_RESET}"
    echo "${COLOR_BOLD_CYAN}║${COLOR_RESET}     ${COLOR_DIM}ARM64 · KDE Plasma · GPU Accelerated${COLOR_RESET}                  ${COLOR_BOLD_CYAN}║${COLOR_RESET}"
    echo "${COLOR_BOLD_CYAN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

launch_shell() {
    local cmd="${1:-}"
    
    print_banner
    pre_launch_checks
    start_services
    
    echo ""
    if [[ -z "${cmd}" ]]; then
        echo "${COLOR_INFO}Entering Ubuntu environment...${COLOR_RESET}"
        echo "${COLOR_DIM}Type 'exit' to return to Termux${COLOR_RESET}"
    fi
    echo ""
    
    # Workaround for "Function not implemented" error on some Android kernels
    # PROOT_NO_SECCOMP disables seccomp filtering that can cause syscall failures
    export PROOT_NO_SECCOMP=1
    
    # Unset LD_PRELOAD to avoid conflicts with Termux-exec hook
    unset LD_PRELOAD
    # Determine working directory - use /home/droid if it exists, otherwise /root
    local work_dir="/root"
    local home_dir="/root"
    if [[ -d "${UBUNTU_ROOTFS}/home/droid" ]]; then
        work_dir="/home/droid"
        home_dir="/home/droid"
    fi
    
    # Build and execute proot command
    local proot_args=(
        "proot"
        "--link2symlink"
        "--kill-on-exit"
        "--root-id"
        "--rootfs=${UBUNTU_ROOTFS}"
        "--cwd=${work_dir}"
        "--pwd=${work_dir}"
        "--bind=/dev"
        "--bind=/dev/urandom:/dev/random"
        "--bind=/proc"
        "--bind=/sys"
        "--bind=/data/data/com.termux/files/usr/tmp:/tmp"
        "--bind=/sdcard"
        "--bind=/storage"
        "--env=HOME=${home_dir}"
        "--env=USER=droid"
        "--env=LOGNAME=droid"
        "--env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        "--env=TERM=${TERM:-xterm-256color}"
        "--env=LANG=C.UTF-8"
        "--env=LC_ALL=C.UTF-8"
        "--env=TMPDIR=/tmp"
        "--env=SHELL=/bin/bash"
        "--env=DISPLAY=:${VNC_DISPLAY}"
        "--env=PULSE_SERVER=tcp:127.0.0.1:4713"
        "--env=XDG_RUNTIME_DIR=/tmp/runtime-droid"
    )
    
    # Add /home/droid bind only if directory exists
    [[ -d "${UBUNTU_ROOTFS}/home/droid" ]] && proot_args+=("--bind=/sdcard:/home/droid")
    
    # Add GPU binds if available
    [[ -e "/dev/kgsl-3d0" ]] && proot_args+=("--bind=/dev/kgsl-3d0")
    [[ -d "/dev/dri" ]] && proot_args+=("--bind=/dev/dri")
    
    # Add Android system paths if available (needed on some devices)
    [[ -d "/system" ]] && proot_args+=("--bind=/system")
    [[ -d "/apex" ]] && proot_args+=("--bind=/apex")
    
    # Environment setup
    # Environment setup using proot's native --env= flags
    local env_args=(
        "--env=HOME=/home/droid"
        "--env=USER=droid"
        "--env=LOGNAME=droid"
        "--env=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        "--env=TERM=${TERM:-xterm-256color}"
        "--env=LANG=C.UTF-8"
        "--env=LC_ALL=C.UTF-8"
        "--env=TMPDIR=/tmp"
        "--env=SHELL=/bin/bash"
        "--env=DISPLAY=:${VNC_DISPLAY}"
        "--env=PULSE_SERVER=tcp:127.0.0.1:4713"
        "--env=XDG_RUNTIME_DIR=/tmp/runtime-droid"
    )
    
    if [[ -n "${cmd}" ]]; then
        # Run single command
        "${proot_args[@]}" /bin/bash -c "${cmd}"
    else
        # Interactive shell
        "${proot_args[@]}" /bin/bash --login
    fi
    
    local exit_code=$?
    
    echo ""
    echo "${COLOR_INFO}Returned to Termux${COLOR_RESET}"
    
    return ${exit_code}
}

launch_vnc_session() {
    local geometry="${1:-1920x1080}"
    local display="${2:-1}"
    
    VNC_GEOMETRY="${geometry}"
    VNC_DISPLAY="${display}"
    
    print_banner
    pre_launch_checks
    start_services
    start_vnc "${geometry}" "${display}"
    
    export DISPLAY=":${display}"
    
    echo ""
    echo "${COLOR_INFO}VNC session ready. Launching Ubuntu shell...${COLOR_RESET}"
    echo ""
    
    launch_shell
}

launch_kde() {
    print_banner
    echo "${COLOR_HEADER}Starting KDE Plasma Desktop...${COLOR_RESET}"
    echo ""
    
    pre_launch_checks
    start_services
    start_vnc "${VNC_GEOMETRY}" "${VNC_DISPLAY}"
    
    export DISPLAY=":${VNC_DISPLAY}"
    
    # Launch KDE inside proot
    local kde_startup='
        export DISPLAY=:'"${VNC_DISPLAY}"'
        export XDG_SESSION_TYPE=x11
        export XDG_CURRENT_DESKTOP=KDE
        export KDE_SESSION_VERSION=6
        export XDG_RUNTIME_DIR=/tmp/runtime-droid
        mkdir -p "${XDG_RUNTIME_DIR}"
        chmod 700 "${XDG_RUNTIME_DIR}"
        
        # Start D-Bus session
        if command -v dbus-daemon &>/dev/null; then
            if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
                export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
                dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --fork 2>/dev/null || true
            fi
        fi
        
        # Start KDE
        if command -v startplasma-x11 &>/dev/null; then
            echo "Starting KDE Plasma 6..."
            exec startplasma-x11
        elif command -v startkde &>/dev/null; then
            echo "Starting KDE Plasma (legacy)..."
            exec startkde
        else
            echo ""
            echo "KDE Plasma is not installed!"
            echo "Install with: sudo apt install kde-plasma-desktop"
            echo ""
            echo "Starting shell instead..."
            exec /bin/bash --login
        fi
    '
    
    launch_shell "${kde_startup}"
}

launch_miracast() {
    print_banner
    echo "${COLOR_HEADER}Starting Miracast Display Mode...${COLOR_RESET}"
    echo ""
    
    pre_launch_checks
    start_services
    
    # Check for Miracast script
    local miracast_script="${UBUNTU_SCRIPTS}/08-display-miracast.sh"
    if [[ -x "${miracast_script}" ]]; then
        source "${miracast_script}"
        start_miracast_display
    else
        echo "${COLOR_WARNING}Miracast script not found. Using VNC fallback...${COLOR_RESET}"
    fi
    
    launch_kde
}

launch_scrcpy() {
    print_banner
    echo "${COLOR_HEADER}Starting Scrcpy + X11 Display Mode...${COLOR_RESET}"
    echo ""
    
    pre_launch_checks
    start_services
    
    # Check for Scrcpy script
    local scrcpy_script="${UBUNTU_SCRIPTS}/09-display-scrcpy-x11.sh"
    if [[ -x "${scrcpy_script}" ]]; then
        source "${scrcpy_script}"
        start_scrcpy_display
    else
        echo "${COLOR_WARNING}Scrcpy script not found. Using VNC fallback...${COLOR_RESET}"
        start_vnc
    fi
    
    launch_kde
}

update_ubuntu() {
    print_banner
    echo "${COLOR_HEADER}Updating Ubuntu System...${COLOR_RESET}"
    echo ""
    
    pre_launch_checks
    
    local update_cmd='
        echo "Updating package lists..."
        apt-get update -y
        
        echo ""
        echo "Upgrading packages..."
        apt-get upgrade -y
        
        echo ""
        echo "Removing unused packages..."
        apt-get autoremove -y
        
        echo ""
        echo "Cleaning package cache..."
        apt-get clean
        
        echo ""
        echo "Update complete!"
    '
    
    launch_shell "${update_cmd}"
}

run_first_boot() {
    print_banner
    echo "${COLOR_HEADER}Running First Boot Setup...${COLOR_RESET}"
    echo ""
    
    pre_launch_checks
    
    local first_boot_cmd='
        if [[ -x /usr/local/bin/first-boot-setup ]]; then
            /usr/local/bin/first-boot-setup
        else
            echo "First boot script not found."
            echo "Running manual setup..."
            apt-get update -y
            apt-get install -y sudo nano curl wget git ca-certificates locales
            locale-gen en_US.UTF-8
            update-locale LANG=en_US.UTF-8
            
            if id droid &>/dev/null; then
                echo "droid ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/droid
                chmod 440 /etc/sudoers.d/droid
            fi
            
            echo "Basic setup complete!"
        fi
    '
    
    launch_shell "${first_boot_cmd}"
}

show_status() {
    print_banner
    echo "${COLOR_HEADER}System Status${COLOR_RESET}"
    echo ""
    
    # Rootfs status
    if [[ -d "${UBUNTU_ROOTFS}/usr" ]]; then
        local size
        size=$(du -sh "${UBUNTU_ROOTFS}" 2>/dev/null | cut -f1)
        echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Ubuntu rootfs: ${UBUNTU_ROOTFS} (${size})"
    else
        echo "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} Ubuntu rootfs not found"
    fi
    
    # VNC status
    if pgrep -f "Xvnc" &>/dev/null; then
        local vnc_pids
        vnc_pids=$(pgrep -f "Xvnc" | tr '\n' ' ')
        echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} VNC server running (PID: ${vnc_pids})"
    else
        echo "  ${COLOR_DIM}•${COLOR_RESET} VNC server not running"
    fi
    
    # PulseAudio status
    if pgrep -x pulseaudio &>/dev/null; then
        echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} PulseAudio running"
    else
        echo "  ${COLOR_DIM}•${COLOR_RESET} PulseAudio not running"
    fi
    
    # GPU status
    echo ""
    echo "${COLOR_HEADER}GPU Status${COLOR_RESET}"
    if [[ -e "/dev/kgsl-3d0" ]]; then
        echo "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Adreno GPU device available"
    else
        echo "  ${COLOR_DIM}•${COLOR_RESET} Adreno GPU device not found"
    fi
    
    if command -v vulkaninfo &>/dev/null; then
        local gpu_name
        gpu_name=$(vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1 | cut -d'=' -f2 | xargs || echo "Unknown")
        echo "  ${COLOR_INFO}${ICON_INFO}${COLOR_RESET} Vulkan GPU: ${gpu_name}"
    fi
    
    # Memory
    echo ""
    echo "${COLOR_HEADER}Memory${COLOR_RESET}"
    echo "  $(get_memory_info)"
    
    # Storage
    echo ""
    echo "${COLOR_HEADER}Storage${COLOR_RESET}"
    local home_free
    home_free=$(available_storage_mb "${HOME}")
    local sdcard_free
    sdcard_free=$(available_storage_mb "/sdcard" 2>/dev/null || echo "N/A")
    echo "  Internal: ${home_free}MB free"
    echo "  SD Card:  ${sdcard_free}MB free"
    
    echo ""
}

show_help() {
    echo "${COLOR_BOLD}Ubuntu 26.04 Resolute Launcher${COLOR_RESET}"
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS] [COMMAND]"
    echo ""
    echo "${COLOR_HEADER}Options:${COLOR_RESET}"
    echo "  ${COLOR_CYAN}--shell, -s${COLOR_RESET}           Start interactive shell (default)"
    echo "  ${COLOR_CYAN}--kde${COLOR_RESET}                 Start with KDE Plasma desktop"
    echo "  ${COLOR_CYAN}--vnc [WxH] [N]${COLOR_RESET}       Start VNC server (geometry, display)"
    echo "  ${COLOR_CYAN}--miracast${COLOR_RESET}            Start with Miracast wireless display"
    echo "  ${COLOR_CYAN}--scrcpy${COLOR_RESET}              Start with Scrcpy + X11 display"
    echo "  ${COLOR_CYAN}--update${COLOR_RESET}              Update Ubuntu packages"
    echo "  ${COLOR_CYAN}--first-boot${COLOR_RESET}          Run first boot setup"
    echo "  ${COLOR_CYAN}--status${COLOR_RESET}              Show system status"
    echo "  ${COLOR_CYAN}-c 'command'${COLOR_RESET}          Run a single command in Ubuntu"
    echo "  ${COLOR_CYAN}--stop${COLOR_RESET}                Stop all services (VNC, etc.)"
    echo "  ${COLOR_CYAN}--help, -h${COLOR_RESET}            Show this help message"
    echo ""
    echo "${COLOR_HEADER}Examples:${COLOR_RESET}"
    echo "  $(basename "$0")                      # Start Ubuntu shell"
    echo "  $(basename "$0") --kde                # Start KDE desktop"
    echo "  $(basename "$0") --vnc 1280x720 2     # VNC on :2 at 720p"
    echo "  $(basename "$0") --miracast           # Cast to TV via Miracast"
    echo "  $(basename "$0") -c 'apt update'      # Run apt update"
    echo "  $(basename "$0") -c 'neofetch'        # Show system info"
    echo ""
    echo "${COLOR_HEADER}Aliases (add to .bashrc):${COLOR_RESET}"
    echo "  alias ubuntu='~/ubuntu/scripts/launch-ubuntu.sh'"
    echo "  alias ubuntu-kde='~/ubuntu/scripts/launch-ubuntu.sh --kde'"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    case "${1:-}" in
        --shell|-s|"")
            launch_shell
            ;;
        --kde)
            launch_kde
            ;;
        --vnc)
            local geom="${2:-1920x1080}"
            local disp="${3:-1}"
            launch_vnc_session "${geom}" "${disp}"
            ;;
        --miracast)
            launch_miracast
            ;;
        --scrcpy)
            launch_scrcpy
            ;;
        --update)
            update_ubuntu
            ;;
        --first-boot)
            run_first_boot
            ;;
        --status)
            show_status
            ;;
        --stop)
            stop_services
            ;;
        -c)
            shift
            launch_shell "$*"
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Trap for cleanup
trap 'echo ""; echo "Interrupted. Cleaning up..."; stop_services 2>/dev/null || true; exit 130' INT TERM

main "$@"
LAUNCHEOF

    chmod +x "${launch_script}"
    log_success "Launch script created: ${launch_script}"
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
    
    # ubuntu-update - Update Ubuntu
    cat > "${UBUNTU_SCRIPTS}/ubuntu-update" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "$(dirname "$0")/launch-ubuntu.sh" --update
EOF
    chmod +x "${UBUNTU_SCRIPTS}/ubuntu-update"
    
    # ubuntu-status - Show status
    cat > "${UBUNTU_SCRIPTS}/ubuntu-status" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "$(dirname "$0")/launch-ubuntu.sh" --status
EOF
    chmod +x "${UBUNTU_SCRIPTS}/ubuntu-status"
    
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
    
    # Ubuntu Update shortcut
    cat > "${shortcuts_dir}/Ubuntu Update" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
~/ubuntu/scripts/launch-ubuntu.sh --update
read -p "Press Enter to close..."
EOF
    chmod +x "${shortcuts_dir}/Ubuntu Update"
    
    log_success "Termux shortcuts created in ~/.shortcuts/"
    log_info "Use Termux:Widget to access these shortcuts from home screen"
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
alias ubuntu-vnc='~/ubuntu/scripts/launch-ubuntu.sh --vnc'
alias ubuntu-miracast='~/ubuntu/scripts/launch-ubuntu.sh --miracast'
alias ubuntu-update='~/ubuntu/scripts/launch-ubuntu.sh --update'
alias ubuntu-status='~/ubuntu/scripts/launch-ubuntu.sh --status'
alias ubuntu-stop='~/ubuntu/scripts/launch-ubuntu.sh --stop'

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
alias ubuntu-log='tail -f ~/ubuntu/logs/launch.log'

# VNC helpers
alias vnc-start='vncserver -localhost no -geometry 1920x1080 :1'
alias vnc-stop='vncserver -kill :1 2>/dev/null || pkill -f Xvnc'
alias vnc-list='vncserver -list'

# Service helpers
alias pulse-start='pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1"'
alias pulse-stop='pulseaudio --kill'

# Display current Ubuntu status on shell start (optional)
# Uncomment to enable:
# ~/ubuntu/scripts/launch-ubuntu.sh --status 2>/dev/null
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
    create_launch_script
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
