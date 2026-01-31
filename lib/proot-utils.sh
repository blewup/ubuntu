#!/data/data/com.termux/files/usr/bin/bash
#
# proot-utils.sh - PRoot Utility Functions
# Ubuntu 26.04 Resolute on Termux Project
#

# Prevent double-sourcing
[[ -n "${_PROOT_UTILS_SH_LOADED:-}" ]] && return 0
_PROOT_UTILS_SH_LOADED=1

# ============================================================================
# CONFIGURATION
# ============================================================================

PROOT_UBUNTU_ROOT="${UBUNTU_ROOT:-${HOME}/ubuntu/rootfs}"
PROOT_HOME_BIND="/sdcard"
PROOT_HOME_TARGET="/home/droid"

# ============================================================================
# PROOT COMMAND BUILDING
# ============================================================================

# Build bind mount arguments
proot_build_binds() {
    local binds=""
    
    # Essential system mounts
    binds+=" --bind=/dev"
    binds+=" --bind=/dev/urandom:/dev/random"
    binds+=" --bind=/proc"
    binds+=" --bind=/sys"
    
    # Termux tmp
    binds+=" --bind=/data/data/com.termux/files/usr/tmp:/tmp"
    
    # User data
    binds+=" --bind=${PROOT_HOME_BIND}:${PROOT_HOME_TARGET}"
    binds+=" --bind=/sdcard"
    binds+=" --bind=/storage"
    
    # GPU devices (if accessible)
    [[ -e "/dev/kgsl-3d0" ]] && binds+=" --bind=/dev/kgsl-3d0"
    [[ -d "/dev/dri" ]] && binds+=" --bind=/dev/dri"
    [[ -e "/dev/ion" ]] && binds+=" --bind=/dev/ion"
    
    echo "${binds}"
}

# Build environment variables
proot_build_env() {
    local display="${1:-:1}"
    
    local env=""
    env+=" HOME=${PROOT_HOME_TARGET}"
    env+=" USER=droid"
    env+=" LOGNAME=droid"
    env+=" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    env+=" TERM=${TERM:-xterm-256color}"
    env+=" LANG=C.UTF-8"
    env+=" LC_ALL=C.UTF-8"
    env+=" TMPDIR=/tmp"
    env+=" SHELL=/bin/bash"
    env+=" DISPLAY=${display}"
    env+=" PULSE_SERVER=tcp:127.0.0.1:4713"
    env+=" XDG_RUNTIME_DIR=/tmp/runtime-droid"
    
    echo "${env}"
}

# Build complete proot command
proot_build_command() {
    local rootfs="${1:-${PROOT_UBUNTU_ROOT}}"
    local display="${2:-:1}"
    
    local cmd="proot"
    cmd+=" --link2symlink"
    cmd+=" --kill-on-exit"
    cmd+=" --root-id"
    cmd+=" --rootfs=${rootfs}"
    cmd+=" --cwd=${PROOT_HOME_TARGET}"
    cmd+=" --pwd=${PROOT_HOME_TARGET}"
    cmd+="$(proot_build_binds)"
    cmd+=" /usr/bin/env -i"
    cmd+="$(proot_build_env "${display}")"
    
    echo "${cmd}"
}

# ============================================================================
# PROOT EXECUTION
# ============================================================================

# Run a command in proot
proot_run() {
    local cmd="$*"
    local proot_cmd
    proot_cmd=$(proot_build_command)
    
    eval "${proot_cmd} /bin/bash -c '${cmd}'"
}

# Start interactive shell
proot_shell() {
    local proot_cmd
    proot_cmd=$(proot_build_command)
    
    eval "${proot_cmd} /bin/bash --login"
}

# Check if proot environment is ready
proot_check() {
    local rootfs="${1:-${PROOT_UBUNTU_ROOT}}"
    
    [[ -d "${rootfs}/usr" ]] && \
    [[ -d "${rootfs}/etc" ]] && \
    [[ -x "${rootfs}/bin/bash" || -x "${rootfs}/usr/bin/bash" ]]
}

# ============================================================================
# PROOT MANAGEMENT
# ============================================================================

# Kill all proot processes for Ubuntu
proot_kill_all() {
    pkill -f "proot.*ubuntu" 2>/dev/null || true
}

# Check if proot is running
proot_is_running() {
    pgrep -f "proot.*ubuntu" &>/dev/null
}

# Get proot PIDs
proot_get_pids() {
    pgrep -f "proot.*ubuntu"
}

# ============================================================================
# EXPORT
# ============================================================================

export PROOT_UBUNTU_ROOT PROOT_HOME_BIND PROOT_HOME_TARGET
export -f proot_build_binds proot_build_env proot_build_command
export -f proot_run proot_shell proot_check
export -f proot_kill_all proot_is_running proot_get_pids
