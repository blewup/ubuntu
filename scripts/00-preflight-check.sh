#!/data/data/com.termux/files/usr/bin/bash
#
# 00-preflight-check.sh
# Pre-flight validation for Ubuntu 26.04 Termux installation
#
# This script validates that all prerequisites are met before
# starting the installation process.
#

set -euo pipefail

# ============================================================================
# INITIALIZATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Source libraries
source "${UBUNTU_PROJECT_ROOT}/lib/colors.sh" 2>/dev/null || {
    echo "Warning: colors.sh not found, continuing without colors"
    COLOR_RESET="" COLOR_GREEN="" COLOR_RED="" COLOR_YELLOW="" COLOR_CYAN=""
}
source "${UBUNTU_PROJECT_ROOT}/lib/functions.sh" 2>/dev/null || {
    echo "Error: functions.sh not found. Please ensure lib/ directory exists."
    exit 1
}

# Script configuration
SCRIPT_NAME="Pre-flight Check"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/00-preflight-check.log"

# Minimum requirements
MIN_STORAGE_MB=10000  # 10GB minimum
MIN_RAM_MB=2048       # 2GB minimum
REQUIRED_ANDROID_SDK=35  # Android 16

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

check_termux_environment() {
    log_section "Checking Termux Environment"
    
    local passed=true
    
    # Check if running in Termux
    log_step 1 5 "Verifying Termux environment..."
    if is_termux; then
        log_success "Running in Termux"
    else
        log_error "Not running in Termux"
        passed=false
    fi
    
    # Check Termux version
    log_step 2 5 "Checking Termux version..."
    if [[ -n "${TERMUX_VERSION:-}" ]]; then
        log_success "Termux version: ${TERMUX_VERSION}"
    else
        log_warn "Could not determine Termux version"
    fi
    
    # Check if installed from F-Droid (not Play Store)
    log_step 3 5 "Verifying Termux source..."
    local termux_apk
    termux_apk=$(pm path com.termux 2>/dev/null | head -1 || echo "")
    if [[ "${termux_apk}" == *"fdroid"* ]] || [[ -f "${PREFIX}/etc/apt/sources.list.d/termux.list" ]]; then
        log_success "Termux appears to be from F-Droid (recommended)"
    else
        log_warn "Could not verify Termux source - ensure it's from F-Droid"
    fi
    
    # Check architecture
    log_step 4 5 "Checking CPU architecture..."
    local arch
    arch=$(uname -m)
    if [[ "${arch}" == "aarch64" ]]; then
        log_success "Architecture: ${arch} (ARM64)"
    else
        log_error "Unsupported architecture: ${arch} (need aarch64)"
        passed=false
    fi
    
    # Check Android version
    log_step 5 5 "Checking Android version..."
    local sdk_version
    sdk_version=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
    local android_version
    android_version=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    
    if [[ ${sdk_version} -ge ${REQUIRED_ANDROID_SDK} ]]; then
        log_success "Android ${android_version} (SDK ${sdk_version})"
    else
        log_warn "Android ${android_version} (SDK ${sdk_version}) - SDK ${REQUIRED_ANDROID_SDK}+ recommended"
    fi
    
    ${passed}
}

check_storage() {
    log_section "Checking Storage"
    
    local passed=true
    
    # Internal storage
    log_step 1 2 "Checking internal storage..."
    local internal_free
    internal_free=$(available_storage_mb "${HOME}")
    
    if [[ ${internal_free} -ge ${MIN_STORAGE_MB} ]]; then
        log_success "Internal storage: ${internal_free}MB available (${MIN_STORAGE_MB}MB required)"
    else
        log_error "Insufficient internal storage: ${internal_free}MB (${MIN_STORAGE_MB}MB required)"
        passed=false
    fi
    
    # External storage (sdcard)
    log_step 2 2 "Checking external storage access..."
    if [[ -d "/sdcard" ]] && [[ -r "/sdcard" ]]; then
        local sdcard_free
        sdcard_free=$(available_storage_mb "/sdcard")
        log_success "External storage accessible: ${sdcard_free}MB available"
    else
        log_warn "Cannot access /sdcard - run 'termux-setup-storage' first"
        passed=false
    fi
    
    ${passed}
}

check_memory() {
    log_section "Checking Memory"
    
    local passed=true
    
    log_step 1 1 "Checking available RAM..."
    local mem_info
    mem_info=$(get_memory_info)
    
    local mem_available
    mem_available=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}')
    
    if [[ ${mem_available} -ge ${MIN_RAM_MB} ]]; then
        log_success "Memory: ${mem_info}"
    else
        log_warn "Low memory: ${mem_info} (${MIN_RAM_MB}MB+ recommended)"
    fi
    
    ${passed}
}

check_network() {
    log_section "Checking Network Connectivity"
    
    local passed=true
    
    log_step 1 3 "Testing internet connectivity..."
    if network_available; then
        log_success "Internet connection available"
    else
        log_error "No internet connection detected"
        passed=false
    fi
    
    log_step 2 3 "Testing Ubuntu mirrors..."
    if url_reachable "https://ports.ubuntu.com" 10; then
        log_success "Ubuntu ports mirror reachable"
    else
        log_warn "Ubuntu ports mirror not reachable (may affect package installation)"
    fi
    
    log_step 3 3 "Testing Termux packages..."
    if url_reachable "https://packages.termux.dev" 10; then
        log_success "Termux packages reachable"
    else
        log_warn "Termux packages not reachable"
    fi
    
    ${passed}
}

check_required_files() {
    log_section "Checking Required Files"
    
    local passed=true
    
    # Check for Ubuntu rootfs tarball
    log_step 1 2 "Checking for Ubuntu rootfs tarball..."
    
    local tarball_locations=(
        "${HOME}/resolute-base-arm64.tar.gz"
        "${HOME}/ubuntu-base-26.04-base-arm64.tar.gz"
        "${HOME}/ubuntu/resolute-base-arm64.tar.gz"
        "/sdcard/Download/resolute-base-arm64.tar.gz"
    )
    
    local tarball_found=""
    for location in "${tarball_locations[@]}"; do
        if [[ -f "${location}" ]]; then
            tarball_found="${location}"
            break
        fi
    done
    
    if [[ -n "${tarball_found}" ]]; then
        local tarball_size
        tarball_size=$(du -h "${tarball_found}" | cut -f1)
        log_success "Ubuntu tarball found: ${tarball_found} (${tarball_size})"
    else
        log_warn "Ubuntu rootfs tarball not found in expected locations:"
        for location in "${tarball_locations[@]}"; do
            log_warn "  - ${location}"
        done
        log_info "Please download ubuntu-base-26.04-base-arm64.tar.gz and place it in ${HOME}/"
        passed=false
    fi
    
    # Check project structure
    log_step 2 2 "Checking project structure..."
    local required_dirs=(
        "${UBUNTU_PROJECT_ROOT}"
        "${UBUNTU_PROJECT_ROOT}/scripts"
        "${UBUNTU_PROJECT_ROOT}/lib"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "${dir}" ]]; then
            log_success "Directory exists: ${dir}"
        else
            log_warn "Missing directory: ${dir}"
        fi
    done
    
    ${passed}
}

check_termux_packages() {
    log_section "Checking Termux Base Packages"
    
    local essential_packages=(
        "coreutils"
        "findutils"
        "wget"
        "curl"
        "tar"
        "gzip"
    )
    
    local optional_packages=(
        "proot"
        "termux-api"
        "git"
    )
    
    log_step 1 2 "Checking essential packages..."
    local missing_essential=()
    for pkg in "${essential_packages[@]}"; do
        if command_exists "${pkg}" 2>/dev/null || pkg_installed "${pkg}"; then
            log_debug "Found: ${pkg}"
        else
            missing_essential+=("${pkg}")
        fi
    done
    
    if [[ ${#missing_essential[@]} -eq 0 ]]; then
        log_success "All essential packages present"
    else
        log_warn "Missing essential packages: ${missing_essential[*]}"
        log_info "These will be installed by 01-setup-termux.sh"
    fi
    
    log_step 2 2 "Checking optional packages..."
    local missing_optional=()
    for pkg in "${optional_packages[@]}"; do
        if command_exists "${pkg}" 2>/dev/null || pkg_installed "${pkg}"; then
            log_success "Found optional: ${pkg}"
        else
            missing_optional+=("${pkg}")
            log_info "Optional package not installed: ${pkg}"
        fi
    done
    
    true
}

check_permissions() {
    log_section "Checking Permissions"
    
    local passed=true
    
    # Storage permission
    log_step 1 3 "Checking storage permission..."
    if [[ -d "${HOME}/storage" ]] || [[ -w "/sdcard" ]]; then
        log_success "Storage permission granted"
    else
        log_warn "Storage permission may not be granted"
        log_info "Run 'termux-setup-storage' to grant access"
        passed=false
    fi
    
    # Termux:API permission check
    log_step 2 3 "Checking Termux:API..."
    if command_exists termux-battery-status; then
        if termux-battery-status &>/dev/null; then
            log_success "Termux:API is functional"
        else
            log_warn "Termux:API installed but may need permissions"
        fi
    else
        log_info "Termux:API not installed (optional, but recommended)"
    fi
    
    # Check for Shizuku
    log_step 3 3 "Checking for Shizuku..."
    if command_exists rish; then
        if shizuku_running; then
            log_success "Shizuku is installed and running"
        else
            log_info "Shizuku installed but not running (start it for enhanced features)"
        fi
    else
        log_info "Shizuku not configured (optional, for enhanced proot capabilities)"
    fi
    
    ${passed}
}

check_device_info() {
    log_section "Device Information"
    
    echo ""
    echo "${COLOR_CYAN}Device Details:${COLOR_RESET}"
    echo "───────────────────────────────────────"
    printf "  Model:       %s\n" "$(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
    printf "  Device:      %s\n" "$(getprop ro.product.device 2>/dev/null || echo 'Unknown')"
    printf "  Android:     %s\n" "$(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
    printf "  SDK Level:   %s\n" "$(getprop ro.build.version.sdk 2>/dev/null || echo 'Unknown')"
    printf "  Build:       %s\n" "$(getprop ro.build.display.id 2>/dev/null || echo 'Unknown')"
    printf "  ABI:         %s\n" "$(getprop ro.product.cpu.abi 2>/dev/null || echo 'Unknown')"
    printf "  SOC:         %s\n" "$(getprop ro.soc.model 2>/dev/null || echo 'Unknown')"
    printf "  Kernel:      %s\n" "$(uname -r)"
    echo "───────────────────────────────────────"
    echo ""
    
    true
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Starting pre-flight checks..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Track overall status
    local all_passed=true
    local warnings=0
    local errors=0
    
    # Run all checks
    check_device_info
    
    if ! check_termux_environment; then
        ((errors++)) || true
        all_passed=false
    fi
    
    if ! check_storage; then
        ((errors++)) || true
        all_passed=false
    fi
    
    check_memory || ((warnings++)) || true
    
    if ! check_network; then
        ((errors++)) || true
        all_passed=false
    fi
    
    if ! check_required_files; then
        ((warnings++)) || true
    fi
    
    check_termux_packages || ((warnings++)) || true
    
    if ! check_permissions; then
        ((warnings++)) || true
    fi
    
    # Summary
    log_section "Pre-flight Check Summary"
    
    if ${all_passed} && [[ ${warnings} -eq 0 ]]; then
        echo ""
        echo "${COLOR_SUCCESS}${ICON_CHECK} All checks passed!${COLOR_RESET}"
        echo ""
        echo "Your system is ready for Ubuntu 26.04 installation."
        echo ""
        echo "Next steps:"
        echo "  1. Ensure Ubuntu rootfs tarball is in ${HOME}/"
        echo "  2. Run: ${COLOR_CYAN}bash ~/ubuntu/scripts/01-setup-termux.sh${COLOR_RESET}"
        echo ""
        print_footer "success" "Pre-flight checks completed successfully"
        return 0
        
    elif ${all_passed}; then
        echo ""
        echo "${COLOR_YELLOW}${ICON_WARNING} Checks passed with ${warnings} warning(s)${COLOR_RESET}"
        echo ""
        echo "Your system can proceed with installation, but review warnings above."
        echo ""
        echo "Next steps:"
        echo "  1. Address any warnings if possible"
        echo "  2. Run: ${COLOR_CYAN}bash ~/ubuntu/scripts/01-setup-termux.sh${COLOR_RESET}"
        echo ""
        print_footer "success" "Pre-flight checks completed with warnings"
        return 0
        
    else
        echo ""
        echo "${COLOR_RED}${ICON_CROSS} Pre-flight checks failed with ${errors} error(s)${COLOR_RESET}"
        echo ""
        echo "Please resolve the errors above before proceeding."
        echo ""
        print_footer "error" "Pre-flight checks failed"
        return 1
    fi
}

# Run main function
main "$@"
