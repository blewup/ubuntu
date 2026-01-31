#!/data/data/com.termux/files/usr/bin/bash
#
# 02-setup-shizuku.sh
# Shizuku integration for enhanced proot capabilities
#
# Shizuku provides elevated permissions without root, allowing:
# - Better /dev access for GPU
# - Enhanced process management
# - System property access
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
SCRIPT_NAME="Shizuku Integration Setup"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/02-setup-shizuku.log"

# Shizuku configuration
SHIZUKU_PKG="moe.shizuku.privileged.api"
RISH_DIR="${HOME}/.shizuku"
RISH_SCRIPT="${RISH_DIR}/rish"
RISH_DEX="${RISH_DIR}/rish_shizuku.dex"

# ============================================================================
# SHIZUKU FUNCTIONS
# ============================================================================

check_shizuku_installed() {
    log_section "Checking Shizuku Installation"
    
    log_step 1 3 "Checking if Shizuku app is installed..."
    
    if pm list packages 2>/dev/null | grep -q "${SHIZUKU_PKG}"; then
        log_success "Shizuku app is installed"
        
        # Get version
        local version
        version=$(dumpsys package "${SHIZUKU_PKG}" 2>/dev/null | grep "versionName" | head -1 | cut -d'=' -f2 || echo "Unknown")
        log_info "Shizuku version: ${version}"
        return 0
    else
        log_warn "Shizuku app is not installed"
        return 1
    fi
}

check_shizuku_running() {
    log_step 2 3 "Checking if Shizuku service is running..."
    
    # Try multiple methods to check Shizuku status
    if [[ -f "${RISH_SCRIPT}" ]] && "${RISH_SCRIPT}" -c "id" &>/dev/null; then
        log_success "Shizuku service is running and accessible"
        return 0
    fi
    
    # Check via service
    if dumpsys activity services 2>/dev/null | grep -q "shizuku\|Shizuku"; then
        log_info "Shizuku service detected (may need rish setup)"
        return 0
    fi
    
    log_warn "Shizuku service is not running"
    return 1
}

setup_rish() {
    log_section "Setting Up Rish (Shizuku Shell)"
    
    ensure_dir "${RISH_DIR}"
    
    log_step 1 4 "Creating rish launcher script..."
    
    # Create the rish script that communicates with Shizuku
    cat > "${RISH_SCRIPT}" << 'RISHEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# rish - Shizuku Remote Shell
# Executes commands with Shizuku's elevated privileges
#

SHIZUKU_PKG="moe.shizuku.privileged.api"
SHIZUKU_SERVICE="moe.shizuku.privileged.api.IShizukuService"

# Check if Shizuku is available
check_shizuku() {
    if ! pm list packages 2>/dev/null | grep -q "${SHIZUKU_PKG}"; then
        echo "Error: Shizuku is not installed" >&2
        return 1
    fi
    
    # Try to connect to Shizuku service
    if ! app_process -Djava.class.path=/data/local/tmp/rish_shizuku.dex /system/bin \
        --nice-name=rish moe.shizuku.rish.ShizukuShellLoader 2>/dev/null; then
        return 1
    fi
    return 0
}

# Parse arguments
if [[ "$1" == "-c" ]]; then
    shift
    CMD="$*"
else
    CMD="$*"
fi

if [[ -z "${CMD}" ]]; then
    echo "Usage: rish -c 'command'" >&2
    echo "       rish command args..." >&2
    exit 1
fi

# Execute via Shizuku
# This uses Android's app_process to run with Shizuku permissions
exec app_process -Djava.class.path="${HOME}/.shizuku/rish_shizuku.dex" \
    /system/bin --nice-name=rish \
    moe.shizuku.rish.ShizukuShellLoader \
    "${CMD}"
RISHEOF

    chmod +x "${RISH_SCRIPT}"
    log_success "Rish script created"
    
    log_step 2 4 "Creating Shizuku helper dex..."
    
    # Create a minimal Java helper for Shizuku communication
    # This is a placeholder - the actual dex would come from Shizuku
    cat > "${RISH_DIR}/ShizukuHelper.java" << 'JAVAEOF'
// ShizukuHelper.java - Placeholder
// In production, this would be replaced by the actual Shizuku rish dex
// Available from: https://github.com/AyanKarkhanis/rish/releases
package moe.shizuku.rish;

public class ShizukuShellLoader {
    public static void main(String[] args) {
        try {
            ProcessBuilder pb = new ProcessBuilder(args);
            pb.inheritIO();
            Process p = pb.start();
            System.exit(p.waitFor());
        } catch (Exception e) {
            System.err.println("Shizuku shell error: " + e.getMessage());
            System.exit(1);
        }
    }
}
JAVAEOF

    log_info "Note: For full Shizuku rish support, download rish dex from:"
    log_info "  https://github.com/AyanKarkhanis/rish/releases"
    log_info "  Place rish_shizuku.dex in ${RISH_DIR}/"
    
    log_step 3 4 "Creating Shizuku wrapper functions..."
    
    # Create wrapper script for common Shizuku operations
    cat > "${RISH_DIR}/shizuku-utils.sh" << 'UTILSEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# shizuku-utils.sh - Utility functions for Shizuku integration
#

RISH="${HOME}/.shizuku/rish"

# Check if Shizuku is available
shizuku_available() {
    [[ -x "${RISH}" ]] && "${RISH}" -c "id" &>/dev/null
}

# Execute command with Shizuku
shizuku_exec() {
    if shizuku_available; then
        "${RISH}" -c "$*"
    else
        echo "Shizuku not available, falling back to normal execution" >&2
        eval "$*"
    fi
}

# Get system property via Shizuku
shizuku_getprop() {
    local prop="$1"
    if shizuku_available; then
        "${RISH}" -c "getprop ${prop}"
    else
        getprop "${prop}" 2>/dev/null
    fi
}

# Read protected file via Shizuku
shizuku_cat() {
    local file="$1"
    if shizuku_available; then
        "${RISH}" -c "cat '${file}'"
    else
        cat "${file}" 2>/dev/null
    fi
}

# List protected directory via Shizuku
shizuku_ls() {
    local dir="$1"
    if shizuku_available; then
        "${RISH}" -c "ls -la '${dir}'"
    else
        ls -la "${dir}" 2>/dev/null
    fi
}

# Copy file with elevated permissions
shizuku_cp() {
    local src="$1"
    local dst="$2"
    if shizuku_available; then
        "${RISH}" -c "cp -a '${src}' '${dst}'"
    else
        cp -a "${src}" "${dst}" 2>/dev/null
    fi
}

# Export functions
export -f shizuku_available shizuku_exec shizuku_getprop
export -f shizuku_cat shizuku_ls shizuku_cp
UTILSEOF

    chmod +x "${RISH_DIR}/shizuku-utils.sh"
    log_success "Shizuku utilities created"
    
    log_step 4 4 "Adding Shizuku to shell environment..."
    
    local bashrc="${HOME}/.bashrc"
    local marker="# Shizuku Integration"
    
    if ! grep -q "${marker}" "${bashrc}" 2>/dev/null; then
        cat >> "${bashrc}" << 'BASHEOF'

# Shizuku Integration
# Added by 02-setup-shizuku.sh

# Shizuku paths
export SHIZUKU_HOME="${HOME}/.shizuku"
export PATH="${SHIZUKU_HOME}:${PATH}"

# Source Shizuku utilities
if [[ -f "${SHIZUKU_HOME}/shizuku-utils.sh" ]]; then
    source "${SHIZUKU_HOME}/shizuku-utils.sh"
fi

# Shizuku aliases
alias shizuku-status='rish -c "id" && echo "Shizuku is active" || echo "Shizuku is not running"'
alias shizuku-shell='rish'
BASHEOF
        log_success "Shell environment updated"
    else
        log_info "Shizuku already in shell environment"
    fi
}

create_shizuku_proot_enhancer() {
    log_section "Creating Shizuku-Enhanced PRoot Configuration"
    
    local enhancer="${UBUNTU_CONFIG}/proot-shizuku.conf"
    ensure_dir "${UBUNTU_CONFIG}"
    
    cat > "${enhancer}" << 'ENHANCEREOF'
# proot-shizuku.conf
# Enhanced PRoot configuration when Shizuku is available
#
# This configuration provides additional bind mounts and
# capabilities when Shizuku is running.

# Check if Shizuku is available
SHIZUKU_AVAILABLE=false
if [[ -x "${HOME}/.shizuku/rish" ]]; then
    if "${HOME}/.shizuku/rish" -c "id" &>/dev/null; then
        SHIZUKU_AVAILABLE=true
    fi
fi

# Base PRoot arguments
PROOT_ARGS=(
    "--link2symlink"
    "--kill-on-exit"
    "--root-id"
)

# Standard bind mounts
PROOT_BINDS=(
    "/dev"
    "/dev/urandom:/dev/random"
    "/proc"
    "/sys"
    "/data/data/com.termux/files/usr/tmp:/tmp"
)

# Enhanced binds when Shizuku is available
if ${SHIZUKU_AVAILABLE}; then
    # GPU device access (Adreno)
    if [[ -e "/dev/kgsl-3d0" ]]; then
        PROOT_BINDS+=("/dev/kgsl-3d0")
    fi
    
    # DRI devices
    for dri in /dev/dri/*; do
        [[ -e "${dri}" ]] && PROOT_BINDS+=("${dri}")
    done
    
    # Ion memory allocator (Android)
    if [[ -e "/dev/ion" ]]; then
        PROOT_BINDS+=("/dev/ion")
    fi
    
    # DMA heap (newer Android)
    for heap in /dev/dma_heap/*; do
        [[ -e "${heap}" ]] && PROOT_BINDS+=("${heap}")
    done
    
    # Ashmem (Android shared memory)
    if [[ -e "/dev/ashmem" ]]; then
        PROOT_BINDS+=("/dev/ashmem")
    fi
fi

# User data binds
PROOT_BINDS+=(
    "/sdcard:/home/droid"
    "/sdcard"
    "/storage"
)

# Build the bind arguments
PROOT_BIND_ARGS=""
for bind in "${PROOT_BINDS[@]}"; do
    PROOT_BIND_ARGS+=" --bind=${bind}"
done

# Environment variables for proot
PROOT_ENV=(
    "HOME=/home/droid"
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    "TERM=${TERM:-xterm-256color}"
    "LANG=C.UTF-8"
    "TMPDIR=/tmp"
    "DISPLAY=${DISPLAY:-:1}"
    "PULSE_SERVER=tcp:127.0.0.1:4713"
)

if ${SHIZUKU_AVAILABLE}; then
    PROOT_ENV+=(
        "SHIZUKU_AVAILABLE=1"
        "LIBGL_ALWAYS_SOFTWARE=0"
    )
else
    PROOT_ENV+=(
        "SHIZUKU_AVAILABLE=0"
    )
fi

# Build environment arguments
PROOT_ENV_ARGS=""
for env in "${PROOT_ENV[@]}"; do
    PROOT_ENV_ARGS+=" ${env}"
done

# Export for use by launch scripts
export PROOT_ARGS PROOT_BIND_ARGS PROOT_ENV_ARGS SHIZUKU_AVAILABLE
ENHANCEREOF

    log_success "Shizuku-enhanced PRoot configuration created"
}

create_gpu_access_helper() {
    log_section "Creating GPU Access Helper"
    
    local gpu_helper="${UBUNTU_PROJECT_ROOT}/scripts/gpu-access.sh"
    
    cat > "${gpu_helper}" << 'GPUEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# gpu-access.sh - GPU device access helper
# Uses Shizuku when available for enhanced GPU access
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh" 2>/dev/null || true
source "${HOME}/.shizuku/shizuku-utils.sh" 2>/dev/null || true

echo "GPU Access Helper"
echo "================="
echo ""

# Check Shizuku status
echo "Shizuku Status:"
if shizuku_available 2>/dev/null; then
    echo "  ✓ Shizuku is active"
    ELEVATED=true
else
    echo "  ✗ Shizuku not available (limited GPU access)"
    ELEVATED=false
fi
echo ""

# Check GPU devices
echo "GPU Devices:"

# Adreno KGSL
if [[ -e "/dev/kgsl-3d0" ]]; then
    if [[ -r "/dev/kgsl-3d0" ]] || ${ELEVATED}; then
        echo "  ✓ /dev/kgsl-3d0 (Adreno GPU) - accessible"
    else
        echo "  ⚠ /dev/kgsl-3d0 (Adreno GPU) - permission denied"
    fi
else
    echo "  ✗ /dev/kgsl-3d0 not found"
fi

# DRI devices
if [[ -d "/dev/dri" ]]; then
    for dev in /dev/dri/*; do
        if [[ -e "${dev}" ]]; then
            if [[ -r "${dev}" ]] || ${ELEVATED}; then
                echo "  ✓ ${dev} - accessible"
            else
                echo "  ⚠ ${dev} - permission denied"
            fi
        fi
    done
else
    echo "  ✗ /dev/dri not found"
fi

echo ""

# GPU info via Shizuku if available
if ${ELEVATED}; then
    echo "GPU Information (via Shizuku):"
    
    # Try to get GPU info
    gpu_info=$(shizuku_exec "cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null" || echo "Unknown")
    echo "  Model: ${gpu_info}"
    
    gpu_freq=$(shizuku_exec "cat /sys/class/kgsl/kgsl-3d0/max_gpuclk 2>/dev/null" || echo "Unknown")
    echo "  Max Clock: ${gpu_freq}"
fi

echo ""
echo "Vulkan Check:"
if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>/dev/null | grep -E "(GPU|deviceName|apiVersion)" | head -5 || echo "  Could not query Vulkan"
else
    echo "  vulkaninfo not installed"
fi
GPUEOF

    chmod +x "${gpu_helper}"
    log_success "GPU access helper created"
}

print_shizuku_instructions() {
    log_section "Shizuku Setup Instructions"
    
    echo ""
    echo "${COLOR_BOLD}To complete Shizuku setup:${COLOR_RESET}"
    echo ""
    echo "1. ${COLOR_CYAN}Install Shizuku${COLOR_RESET} (if not already installed):"
    echo "   - Download from: https://shizuku.rikka.app/"
    echo "   - Or: Play Store / GitHub releases"
    echo ""
    echo "2. ${COLOR_CYAN}Start Shizuku${COLOR_RESET}:"
    echo "   ${COLOR_YELLOW}Option A - Wireless Debugging (Android 11+):${COLOR_RESET}"
    echo "   - Enable Developer Options"
    echo "   - Enable Wireless Debugging"
    echo "   - Open Shizuku app → Start via Wireless Debugging"
    echo ""
    echo "   ${COLOR_YELLOW}Option B - ADB (requires PC):${COLOR_RESET}"
    echo "   - Connect phone to PC with ADB"
    echo "   - Run: adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh"
    echo ""
    echo "3. ${COLOR_CYAN}Authorize Termux${COLOR_RESET}:"
    echo "   - Open Shizuku app"
    echo "   - Grant permission to Termux when prompted"
    echo ""
    echo "4. ${COLOR_CYAN}Download rish${COLOR_RESET} (optional but recommended):"
    echo "   - URL: https://github.com/AyanKarkhanis/rish/releases"
    echo "   - Place rish_shizuku.dex in: ${RISH_DIR}/"
    echo ""
    echo "5. ${COLOR_CYAN}Test Shizuku${COLOR_RESET}:"
    echo "   - Run: ${COLOR_GREEN}rish -c 'id'${COLOR_RESET}"
    echo "   - Should show: uid=2000(shell)"
    echo ""
    echo "${COLOR_YELLOW}Note:${COLOR_RESET} Shizuku is optional. The Ubuntu installation will work"
    echo "without it, but GPU access may be limited."
    echo ""
}

verify_shizuku_setup() {
    log_section "Verifying Shizuku Setup"
    
    local status=0
    
    # Check script exists
    if [[ -x "${RISH_SCRIPT}" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Rish script installed\n"
    else
        printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} Rish script not found\n"
        ((status++)) || true
    fi
    
    # Check utilities
    if [[ -f "${RISH_DIR}/shizuku-utils.sh" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Shizuku utilities installed\n"
    else
        printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} Shizuku utilities not found\n"
        ((status++)) || true
    fi
    
    # Check proot config
    if [[ -f "${UBUNTU_CONFIG}/proot-shizuku.conf" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} PRoot Shizuku config created\n"
    else
        printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} PRoot Shizuku config not found\n"
        ((status++)) || true
    fi
    
    # Check if Shizuku is actually running
    echo ""
    if check_shizuku_installed 2>/dev/null; then
        if check_shizuku_running 2>/dev/null; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} Shizuku service is active\n"
        else
            printf "  ${COLOR_INFO}${ICON_INFO}${COLOR_RESET} Shizuku installed but not running\n"
            ((status++)) || true
        fi
    else
        printf "  ${COLOR_INFO}${ICON_INFO}${COLOR_RESET} Shizuku app not installed\n"
        ((status++)) || true
    fi
    
    return ${status}
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Setting up Shizuku integration..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Check if running in Termux
    if ! is_termux; then
        die "This script must be run in Termux"
    fi
    
    # Check if Shizuku is installed
    local shizuku_installed=false
    if check_shizuku_installed; then
        shizuku_installed=true
    fi
    
    # Always set up the scripts (they handle fallback gracefully)
    setup_rish
    create_shizuku_proot_enhancer
    create_gpu_access_helper
    
    # Verify setup
    echo ""
    if verify_shizuku_setup; then
        print_footer "success" "Shizuku integration setup completed"
    else
        print_footer "success" "Shizuku scripts installed (service not yet active)"
    fi
    
    # Show instructions if Shizuku not running
    if ! ${shizuku_installed} || ! check_shizuku_running 2>/dev/null; then
        print_shizuku_instructions
    fi
    
    echo ""
    echo "Next steps:"
    echo "  1. (Optional) Follow Shizuku instructions above"
    echo "  2. Run: ${COLOR_CYAN}bash ~/ubuntu/scripts/03-extract-rootfs.sh${COLOR_RESET}"
    echo ""
    
    return 0
}

# Run main function
main "$@"
