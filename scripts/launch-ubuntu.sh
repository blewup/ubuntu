#!/data/data/com.termux/files/usr/bin/bash
#
# launch-ubuntu.sh - Main Ubuntu launcher
#
# Usage:
#   launch-ubuntu.sh              Start shell (default)
#   launch-ubuntu.sh --shell      Start shell
#   launch-ubuntu.sh --kde        Start KDE Plasma
#   launch-ubuntu.sh --xfce       Start XFCE
#   launch-ubuntu.sh -c "cmd"     Run command
#
set -euo pipefail

UBUNTU_HOME="${HOME}/ubuntu"
ROOTFS="${UBUNTU_HOME}/rootfs"
LOG_DIR="${UBUNTU_HOME}/logs"

mkdir -p "${LOG_DIR}"

# ============================================================================
# CONFIGURATION
# ============================================================================

# Workaround for "Function not implemented" error on some Android kernels
# PROOT_NO_SECCOMP disables seccomp filtering that can cause syscall failures
export PROOT_NO_SECCOMP=1

# Unset LD_PRELOAD to avoid conflicts with Termux-exec hook
unset LD_PRELOAD

PROOT_ARGS=(
    --link2symlink
    --kill-on-exit
    -0
    -r "${ROOTFS}"
    -b /dev
    -b /proc
    -b /sys
    -b "${UBUNTU_HOME}:/ubuntu"
    -b /data/data/com.termux/files/usr/tmp:/tmp
    -w /root
)

# Add Android system paths if available (needed on some devices)
[[ -d "/system" ]] && PROOT_ARGS+=(-b /system)
[[ -d "/apex" ]] && PROOT_ARGS+=(-b /apex)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

check_rootfs() {
    if [[ ! -d "${ROOTFS}" ]]; then
        echo "Error: Ubuntu rootfs not found at ${ROOTFS}"
        echo "Run: bash ~/ubuntu/scripts/03-extract-rootfs.sh"
        exit 1
    fi
    
    # Check essential binaries exist
    local essential_bins=(
        "/bin/bash"
        "/bin/sh"
    )
    local missing=()
    
    for bin in "${essential_bins[@]}"; do
        if [[ ! -f "${ROOTFS}${bin}" ]]; then
            missing+=("${bin}")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Ubuntu rootfs appears incomplete or corrupted"
        echo "Missing essential binaries:"
        for bin in "${missing[@]}"; do
            echo "  - ${bin}"
        done
        echo ""
        echo "The rootfs extraction may have failed. Please:"
        echo "  1. Remove incomplete rootfs: rm -rf ${ROOTFS}"
        echo "  2. Re-run extraction: bash ~/ubuntu/scripts/03-extract-rootfs.sh"
        exit 1
    fi
}

start_vnc() {
    local resolution="${1:-1920x1080}"
    local display="${2:-1}"
    
    # Kill existing
    vncserver -kill ":${display}" 2>/dev/null || true
    pkill -f "Xvnc.*:${display}" 2>/dev/null || true
    rm -f "/tmp/.X${display}-lock" "/tmp/.X11-unix/X${display}" 2>/dev/null || true
    sleep 1
    
    log "Starting VNC at ${resolution}..."
    vncserver -localhost no -geometry "${resolution}" -depth 24 ":${display}"
    
    local ip=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}')
    local port=$((5900 + display))
    log "VNC ready: ${ip:-localhost}:${port}"
}

start_audio() {
    if ! pgrep -x pulseaudio &>/dev/null; then
        log "Starting PulseAudio..."
        pulseaudio --start \
            --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
            --exit-idle-time=-1 2>/dev/null || true
    fi
}

# ============================================================================
# LAUNCH MODES
# ============================================================================

launch_shell() {
    log "Starting Ubuntu shell..."
    exec proot "${PROOT_ARGS[@]}" /bin/bash --login
}

launch_command() {
    local cmd="$1"
    exec proot "${PROOT_ARGS[@]}" /bin/bash -c "${cmd}"
}

launch_kde() {
    local resolution="${1:-1920x1080}"
    
    log "Starting KDE Plasma..."
    start_audio
    start_vnc "${resolution}"
    
    # Start KDE inside proot
    proot "${PROOT_ARGS[@]}" /bin/bash -c "
        export DISPLAY=:1
        export XDG_RUNTIME_DIR=/tmp/runtime-root
        mkdir -p \$XDG_RUNTIME_DIR
        chmod 700 \$XDG_RUNTIME_DIR
        
        # Start D-Bus
        if ! pgrep -x dbus-daemon &>/dev/null; then
            dbus-daemon --system --fork 2>/dev/null || true
            dbus-daemon --session --fork 2>/dev/null || true
        fi
        
        # Start KDE
        exec startplasma-x11
    " &
    
    local ip=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}')
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  KDE Plasma Started"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  Connect with VNC viewer to: ${ip:-localhost}:5901"
    echo ""
    echo "  To stop: ubuntu-stop or ~/.termux/tasker/stop-ubuntu.sh"
    echo ""
}

launch_xfce() {
    local resolution="${1:-1920x1080}"
    
    log "Starting XFCE..."
    start_audio
    start_vnc "${resolution}"
    
    # Start XFCE inside proot
    proot "${PROOT_ARGS[@]}" /bin/bash -c "
        export DISPLAY=:1
        export XDG_RUNTIME_DIR=/tmp/runtime-root
        mkdir -p \$XDG_RUNTIME_DIR
        chmod 700 \$XDG_RUNTIME_DIR
        
        # Start D-Bus
        if ! pgrep -x dbus-daemon &>/dev/null; then
            dbus-daemon --session --fork 2>/dev/null || true
        fi
        
        # Start XFCE
        exec startxfce4
    " &
    
    local ip=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}')
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  XFCE Started"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "  Connect with VNC viewer to: ${ip:-localhost}:5901"
    echo ""
}

# ============================================================================
# USAGE
# ============================================================================

show_usage() {
    cat << 'EOF'
Ubuntu Launcher

Usage: launch-ubuntu.sh [option]

Options:
  --shell, -s       Start Ubuntu shell (default)
  --kde             Start KDE Plasma desktop
  --xfce            Start XFCE desktop
  -c "command"      Run a command in Ubuntu
  --help, -h        Show this help

Resolution options (with --kde or --xfce):
  --720p            1280x720
  --1080p           1920x1080 (default)
  --1440p           2560x1440

Examples:
  launch-ubuntu.sh
  launch-ubuntu.sh --kde
  launch-ubuntu.sh --kde --1440p
  launch-ubuntu.sh -c "apt update"
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local mode="shell"
    local resolution="1920x1080"
    local command=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --shell|-s)
                mode="shell"
                shift
                ;;
            --kde)
                mode="kde"
                shift
                ;;
            --xfce)
                mode="xfce"
                shift
                ;;
            -c)
                mode="command"
                command="${2:-}"
                shift 2
                ;;
            --720p)
                resolution="1280x720"
                shift
                ;;
            --1080p)
                resolution="1920x1080"
                shift
                ;;
            --1440p)
                resolution="2560x1440"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check rootfs
    check_rootfs
    
    # Launch
    case "${mode}" in
        shell)
            launch_shell
            ;;
        kde)
            launch_kde "${resolution}"
            ;;
        xfce)
            launch_xfce "${resolution}"
            ;;
        command)
            if [[ -z "${command}" ]]; then
                echo "Error: No command specified"
                exit 1
            fi
            launch_command "${command}"
            ;; 
    esac
}

main "$@"
