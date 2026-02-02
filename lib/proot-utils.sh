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
    local rootfs="${1:-${PROOT_UBUNTU_ROOT}}"
    local binds=""
    
    # Essential system mounts
    binds+=" -b /dev"
    binds+=" -b /dev/urandom:/dev/random"
    binds+=" -b /proc"
    binds+=" -b /sys"
    
    # Termux tmp
    binds+=" -b /data/data/com.termux/files/usr/tmp:/tmp"
    
    # User data - only bind /sdcard:/home/droid if /home/droid exists in rootfs
    if [[ -d "${rootfs}${PROOT_HOME_TARGET}" ]]; then
        binds+=" -b ${PROOT_HOME_BIND}:${PROOT_HOME_TARGET}"
    fi
    binds+=" -b /sdcard"
    binds+=" -b /storage"
    
    # GPU devices (if accessible)
    [[ -e "/dev/kgsl-3d0" ]] && binds+=" -b /dev/kgsl-3d0"
    [[ -d "/dev/dri" ]] && binds+=" -b /dev/dri"
    [[ -e "/dev/ion" ]] && binds+=" -b /dev/ion"
    
    # Android system paths (needed on some devices)
    [[ -d "/system" ]] && binds+=" -b /system"
    [[ -d "/apex" ]] && binds+=" -b /apex"
    
    echo "${binds}"
}

# Build environment variables using proot's native -e flags
proot_build_env() {
    local display="${1:-:1}"
    local home_dir="${2:-${PROOT_HOME_TARGET}}"
    
    local env=""
    env+=" -e HOME=${home_dir}"
    env+=" -e USER=droid"
    env+=" -e LOGNAME=droid"
    env+=" -e PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    env+=" -e TERM=${TERM:-xterm-256color}"
    env+=" -e LANG=C.UTF-8"
    env+=" -e LC_ALL=C.UTF-8"
    env+=" -e TMPDIR=/tmp"
    env+=" -e SHELL=/bin/bash"
    env+=" -e DISPLAY=${display}"
    env+=" -e PULSE_SERVER=tcp:127.0.0.1:4713"
    env+=" -e XDG_RUNTIME_DIR=/tmp/runtime-droid"
    
    echo "${env}"
}

# Determine working directory based on what exists in rootfs
proot_get_working_dir() {
    local rootfs="${1:-${PROOT_UBUNTU_ROOT}}"
    
    # Prefer /home/droid if it exists in rootfs
    if [[ -d "${rootfs}${PROOT_HOME_TARGET}" ]]; then
        echo "${PROOT_HOME_TARGET}"
    # Fallback to /root
    elif [[ -d "${rootfs}/root" ]]; then
        echo "/root"
    # Ultimate fallback
    else
        echo "/"
    fi
}

# Build complete proot command
proot_build_command() {
    local rootfs="${1:-${PROOT_UBUNTU_ROOT}}"
    local display="${2:-:1}"
    
    # Get the working directory that exists in rootfs
    local work_dir
    work_dir=$(proot_get_working_dir "${rootfs}")
    
    local cmd="proot"
    cmd+=" --link2symlink"
    cmd+=" --kill-on-exit"
    cmd+=" -0"
    cmd+=" -r ${rootfs}"
    cmd+=" -w ${work_dir}"
    cmd+="$(proot_build_binds "${rootfs}")"
    cmd+="$(proot_build_env "${display}" "${work_dir}")"
    
    echo "${cmd}"
}

# ============================================================================
# PROOT EXECUTION
# ============================================================================

# Prepare proot environment (called before running proot commands)
proot_prepare_env() {
    # Workaround for "Function not implemented" error on some Android kernels
    # PROOT_NO_SECCOMP disables seccomp filtering that can cause syscall failures
    export PROOT_NO_SECCOMP=1
    
    # Unset LD_PRELOAD to avoid conflicts with Termux-exec hook
    unset LD_PRELOAD
}

# Run a command in proot
proot_run() {
    local cmd="$*"
    local proot_cmd
    proot_cmd=$(proot_build_command)
    
    proot_prepare_env
    eval "${proot_cmd} /bin/bash -c '${cmd}'"
}

# Start interactive shell
proot_shell() {
    local proot_cmd
    proot_cmd=$(proot_build_command)
    
    proot_prepare_env
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
export -f proot_prepare_env proot_run proot_shell proot_check
export -f proot_build_binds proot_build_env proot_get_working_dir proot_build_command
export -f proot_run proot_shell proot_check
export -f proot_kill_all proot_is_running proot_get_pids
