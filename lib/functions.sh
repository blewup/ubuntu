#!/data/data/com.termux/files/usr/bin/bash
#
# functions.sh - Shared Functions Library
# Ubuntu 26.04 Resolute on Termux Project
#
# Source this file to access common functions across all scripts
# Usage: source ~/ubuntu/lib/functions.sh
#

# ============================================================================
# INITIALIZATION
# ============================================================================

# Prevent double-sourcing
[[ -n "${_FUNCTIONS_SH_LOADED:-}" ]] && return 0
_FUNCTIONS_SH_LOADED=1

# Get the directory where this script lives
UBUNTU_PROJECT_ROOT="${UBUNTU_PROJECT_ROOT:-${HOME}/ubuntu}"
UBUNTU_LIB_DIR="${UBUNTU_PROJECT_ROOT}/lib"

# Source colors if not already loaded
if [[ -z "${COLOR_RESET:-}" ]]; then
    if [[ -f "${UBUNTU_LIB_DIR}/colors.sh" ]]; then
        source "${UBUNTU_LIB_DIR}/colors.sh"
    fi
fi

# ============================================================================
# PROJECT PATHS
# ============================================================================

UBUNTU_ROOT="${UBUNTU_PROJECT_ROOT}/rootfs"
UBUNTU_SCRIPTS="${UBUNTU_PROJECT_ROOT}/scripts"
UBUNTU_CACHE="${UBUNTU_PROJECT_ROOT}/cache"
UBUNTU_LOGS="${UBUNTU_PROJECT_ROOT}/logs"
UBUNTU_CONFIG="${UBUNTU_PROJECT_ROOT}/config"
UBUNTU_MESA="${UBUNTU_PROJECT_ROOT}/mesa-zink"
UBUNTU_BACKUP="/sdcard/ubuntu-backup"
UBUNTU_HOME_BIND="/sdcard"
UBUNTU_HOME_TARGET="/home/droid"

export UBUNTU_PROJECT_ROOT UBUNTU_ROOT UBUNTU_SCRIPTS UBUNTU_CACHE
export UBUNTU_LOGS UBUNTU_CONFIG UBUNTU_MESA UBUNTU_BACKUP
export UBUNTU_HOME_BIND UBUNTU_HOME_TARGET

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

# Current log file (can be overridden by scripts)
CURRENT_LOG_FILE="${CURRENT_LOG_FILE:-${UBUNTU_LOGS}/ubuntu-setup.log}"

# Ensure log directory exists
_ensure_log_dir() {
    mkdir -p "$(dirname "${CURRENT_LOG_FILE}")" 2>/dev/null || true
}

# Internal logging function
_log() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    _ensure_log_dir
    
    # Console output (with color)
    echo -e "${color}[${level}]${COLOR_RESET} ${message}"
    
    # File output (without color codes)
    echo "[${timestamp}] [${level}] ${message}" | sed 's/\x1b\[[0-9;]*m//g' >> "${CURRENT_LOG_FILE}" 2>/dev/null || true
}

# Public logging functions
log_info()    { _log "INFO" "${COLOR_INFO}" "$@"; }
log_success() { _log " OK " "${COLOR_SUCCESS}" "$@"; }
log_warn()    { _log "WARN" "${COLOR_WARNING}" "$@"; }
log_error()   { _log "ERR " "${COLOR_ERROR}" "$@"; }
log_debug()   { [[ -n "${DEBUG:-}" ]] && _log "DBG " "${COLOR_DEBUG}" "$@"; }

# Section header
log_section() {
    local title="$*"
    local line="${COLOR_HEADER}════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    echo "${line}"
    echo "${COLOR_HEADER}${COLOR_BOLD}  ${title}${COLOR_RESET}"
    echo "${line}"
    echo ""
    
    _ensure_log_dir
    echo "" >> "${CURRENT_LOG_FILE}" 2>/dev/null || true
    echo "======== ${title} ========" >> "${CURRENT_LOG_FILE}" 2>/dev/null || true
}

# Step indicator
log_step() {
    local step_num="$1"
    local total="$2"
    shift 2
    local description="$*"
    echo -e "${COLOR_BOLD_CYAN}[${step_num}/${total}]${COLOR_RESET} ${description}"
}

# ============================================================================
# PROGRESS INDICATORS
# ============================================================================

# Spinner for long operations
spinner() {
    local pid=$1
    local message="${2:-Processing...}"
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % ${#spin_chars} ))
        printf "\r${COLOR_CYAN}%s${COLOR_RESET} %s" "${spin_chars:$i:1}" "${message}"
        sleep 0.1
    done
    printf "\r"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-50}
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${COLOR_CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${COLOR_RESET} %3d%%" "${percentage}"
    
    [[ ${current} -eq ${total} ]] && echo ""
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Check if running in Termux
is_termux() {
    [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if package is installed (Termux)
pkg_installed() {
    local pkg="$1"
    dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"
}

# Check if file exists and is readable
file_readable() {
    [[ -f "$1" ]] && [[ -r "$1" ]]
}

# Check if directory exists and is writable
dir_writable() {
    [[ -d "$1" ]] && [[ -w "$1" ]]
}

# Get human-readable file size
# Uses stat (works on Android FUSE storage) with fallback to du
# This is more reliable than du -h on Android's FUSE/sdcardfs filesystems
get_file_size_human() {
    local file="$1"
    local size_bytes

    # Try stat first (more reliable on Android storage)
    size_bytes=$(stat -c%s "${file}" 2>/dev/null || stat -f%z "${file}" 2>/dev/null)

    # Fallback to wc if stat fails
    if [[ -z "${size_bytes}" ]] || [[ "${size_bytes}" == "0" ]]; then
        size_bytes=$(wc -c < "${file}" 2>/dev/null)
    fi

    # If still empty or 0, try du as last resort
    if [[ -z "${size_bytes}" ]] || [[ "${size_bytes}" == "0" ]]; then
        du -h "${file}" 2>/dev/null | cut -f1
        return
    fi

    # Convert bytes to human-readable format
    if [[ ${size_bytes} -ge 1073741824 ]]; then
        # GB
        echo "$(awk "BEGIN {printf \"%.1fG\", ${size_bytes}/1073741824}")"
    elif [[ ${size_bytes} -ge 1048576 ]]; then
        # MB
        echo "$(awk "BEGIN {printf \"%.1fM\", ${size_bytes}/1048576}")"
    elif [[ ${size_bytes} -ge 1024 ]]; then
        # KB
        echo "$(awk "BEGIN {printf \"%.1fK\", ${size_bytes}/1024}")"
    else
        echo "${size_bytes}B"
    fi
}

# Check available storage (in MB)
available_storage_mb() {
    local path="${1:-${HOME}}"
    df -m "${path}" 2>/dev/null | awk 'NR==2 {print $4}'
}

# Check if network is available
network_available() {
    ping -c 1 -W 2 8.8.8.8 &>/dev/null || ping -c 1 -W 2 1.1.1.1 &>/dev/null
}

# Validate URL is reachable
url_reachable() {
    local url="$1"
    local timeout="${2:-5}"
    curl --head --silent --fail --max-time "${timeout}" "${url}" &>/dev/null
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Safe download with retry
download_file() {
    local url="$1"
    local output="$2"
    local retries="${3:-3}"
    local retry_delay="${4:-5}"
    
    local attempt=1
    while [[ ${attempt} -le ${retries} ]]; do
        log_info "Downloading: $(basename "${output}") (attempt ${attempt}/${retries})"
        
        if wget -c -q --show-progress -O "${output}" "${url}"; then
            log_success "Downloaded: $(basename "${output}")"
            return 0
        fi
        
        log_warn "Download failed, retrying in ${retry_delay}s..."
        sleep "${retry_delay}"
        ((attempt++))
    done
    
    log_error "Failed to download after ${retries} attempts: ${url}"
    return 1
}

# Safe file copy with verification
safe_copy() {
    local src="$1"
    local dst="$2"
    
    if [[ ! -e "${src}" ]]; then
        log_error "Source does not exist: ${src}"
        return 1
    fi
    
    if cp -a "${src}" "${dst}"; then
        log_success "Copied: ${src} → ${dst}"
        return 0
    else
        log_error "Failed to copy: ${src} → ${dst}"
        return 1
    fi
}

# Create directory with parents
ensure_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        if mkdir -p "${dir}"; then
            log_debug "Created directory: ${dir}"
        else
            log_error "Failed to create directory: ${dir}"
            return 1
        fi
    fi
    return 0
}

# Backup file before modification
backup_file() {
    local file="$1"
    local backup_dir="${2:-${UBUNTU_BACKUP}}"
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    
    if [[ -f "${file}" ]]; then
        ensure_dir "${backup_dir}"
        local backup_path="${backup_dir}/$(basename "${file}").${timestamp}.bak"
        if cp -a "${file}" "${backup_path}"; then
            log_debug "Backed up: ${file} → ${backup_path}"
            echo "${backup_path}"
            return 0
        fi
    fi
    return 1
}

# ============================================================================
# TERMUX PACKAGE MANAGEMENT
# ============================================================================

# Update package lists
pkg_update() {
    log_info "Updating package lists..."
    if apt-get update -qq; then
        log_success "Package lists updated"
        return 0
    else
        log_error "Failed to update package lists"
        return 1
    fi
}

# Install packages (idempotent)
pkg_install() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! pkg_installed "${pkg}"; then
            to_install+=("${pkg}")
        else
            log_debug "Already installed: ${pkg}"
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        log_info "All requested packages already installed"
        return 0
    fi
    
    log_info "Installing: ${to_install[*]}"
    if apt-get install -y -qq "${to_install[@]}"; then
        log_success "Installed: ${to_install[*]}"
        return 0
    else
        log_error "Failed to install packages"
        return 1
    fi
}

# ============================================================================
# PROOT HELPERS
# ============================================================================

# Generate proot launch command
proot_cmd() {
    local rootfs="${1:-${UBUNTU_ROOT}}"
    
    echo "proot" \
        "--link2symlink" \
        "--kill-on-exit" \
        "--root-id" \
        "--rootfs=${rootfs}" \
        "--bind=/dev" \
        "--bind=/dev/urandom:/dev/random" \
        "--bind=/proc" \
        "--bind=/sys" \
        "--bind=/data/data/com.termux/files/usr/tmp:/tmp" \
        "--bind=${UBUNTU_HOME_BIND}:${UBUNTU_HOME_TARGET}" \
        "--bind=/sdcard" \
        "--bind=/storage" \
        "--cwd=${UBUNTU_HOME_TARGET}" \
        "--pwd=${UBUNTU_HOME_TARGET}" \
        "/usr/bin/env" \
        "-i" \
        "HOME=${UBUNTU_HOME_TARGET}" \
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        "TERM=${TERM}" \
        "LANG=C.UTF-8" \
        "TMPDIR=/tmp"
}

# Execute command inside proot
proot_exec() {
    local rootfs="${1:-${UBUNTU_ROOT}}"
    shift
    local cmd=("$@")
    
    $(proot_cmd "${rootfs}") /bin/bash -c "${cmd[*]}"
}

# ============================================================================
# SHIZUKU HELPERS
# ============================================================================

# Check if Shizuku is running
shizuku_running() {
    if command_exists rish; then
        rish -c "id" &>/dev/null
        return $?
    fi
    return 1
}

# Execute command via Shizuku
shizuku_exec() {
    if shizuku_running; then
        rish -c "$*"
    else
        log_error "Shizuku is not running"
        return 1
    fi
}

# ============================================================================
# SYSTEM INFORMATION
# ============================================================================

# Get device info
get_device_info() {
    local info=""
    info+="Device: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')\n"
    info+="Android: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')\n"
    info+="SDK: $(getprop ro.build.version.sdk 2>/dev/null || echo 'Unknown')\n"
    info+="ABI: $(getprop ro.product.cpu.abi 2>/dev/null || echo 'Unknown')\n"
    info+="Termux: ${TERMUX_VERSION:-Unknown}\n"
    echo -e "${info}"
}

# Get memory info (in MB)
get_memory_info() {
    local mem_total mem_free
    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}')
    mem_free=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}')
    echo "Total: ${mem_total}MB, Available: ${mem_free}MB"
}

# ============================================================================
# USER INTERACTION
# ============================================================================

# Prompt for yes/no confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"
    
    local yn_prompt
    if [[ "${default}" == "y" ]]; then
        yn_prompt="[Y/n]"
    else
        yn_prompt="[y/N]"
    fi
    
    while true; do
        read -r -p "${COLOR_PROMPT}${prompt} ${yn_prompt}: ${COLOR_RESET}" response
        response="${response:-${default}}"
        case "${response}" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Prompt for input with default
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result
    
    if [[ -n "${default}" ]]; then
        read -r -p "${COLOR_PROMPT}${prompt} [${default}]: ${COLOR_RESET}" result
        echo "${result:-${default}}"
    else
        read -r -p "${COLOR_PROMPT}${prompt}: ${COLOR_RESET}" result
        echo "${result}"
    fi
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

# Exit with error
die() {
    log_error "$@"
    exit 1
}

# Trap handler for cleanup
cleanup_trap() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log_error "Script failed with exit code: ${exit_code}"
        log_error "Check log file: ${CURRENT_LOG_FILE}"
    fi
    # Add custom cleanup here if needed
    exit ${exit_code}
}

# ============================================================================
# SCRIPT UTILITIES
# ============================================================================

# Mark script as requiring root/Shizuku
require_elevated() {
    if [[ $(id -u) -eq 0 ]] || shizuku_running; then
        return 0
    else
        die "This script requires elevated privileges (root or Shizuku)"
    fi
}

# Check minimum required storage
require_storage() {
    local required_mb="$1"
    local path="${2:-${HOME}}"
    local available
    available=$(available_storage_mb "${path}")
    
    if [[ ${available} -lt ${required_mb} ]]; then
        die "Insufficient storage. Required: ${required_mb}MB, Available: ${available}MB"
    fi
    log_info "Storage check passed: ${available}MB available (${required_mb}MB required)"
}

# Script header
print_header() {
    local script_name="$1"
    local version="${2:-1.0.0}"
    
    echo ""
    echo "${COLOR_HEADER}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo "${COLOR_HEADER}║${COLOR_RESET}  ${COLOR_BOLD}Ubuntu 26.04 Resolute on Termux${COLOR_RESET}                            ${COLOR_HEADER}║${COLOR_RESET}"
    echo "${COLOR_HEADER}║${COLOR_RESET}  ${script_name} v${version}$(printf '%*s' $((40 - ${#script_name} - ${#version})) '')${COLOR_HEADER}║${COLOR_RESET}"
    echo "${COLOR_HEADER}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

# Script footer
print_footer() {
    local status="${1:-success}"
    local message="${2:-Script completed}"
    
    echo ""
    if [[ "${status}" == "success" ]]; then
        echo "${COLOR_SUCCESS}════════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo "${COLOR_SUCCESS}${ICON_CHECK} ${message}${COLOR_RESET}"
        echo "${COLOR_SUCCESS}════════════════════════════════════════════════════════════════${COLOR_RESET}"
    else
        echo "${COLOR_ERROR}════════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo "${COLOR_ERROR}${ICON_CROSS} ${message}${COLOR_RESET}"
        echo "${COLOR_ERROR}════════════════════════════════════════════════════════════════${COLOR_RESET}"
    fi
    echo ""
}

# ============================================================================
# EXPORT ALL FUNCTIONS
# ============================================================================

export -f log_info log_success log_warn log_error log_debug log_section log_step
export -f spinner progress_bar
export -f is_termux command_exists pkg_installed file_readable dir_writable
export -f get_file_size_human available_storage_mb network_available url_reachable
export -f download_file safe_copy ensure_dir backup_file
export -f pkg_update pkg_install
export -f proot_cmd proot_exec
export -f shizuku_running shizuku_exec
export -f get_device_info get_memory_info
export -f confirm prompt_input
export -f die cleanup_trap
export -f require_elevated require_storage
export -f print_header print_footer
