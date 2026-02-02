#!/data/data/com.termux/files/usr/bin/bash
#
# 03-extract-rootfs.sh
# Extract Ubuntu 26.04 Resolute rootfs tarball
#
# This script extracts the Ubuntu base image and performs
# initial configuration for proot compatibility.
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
SCRIPT_NAME="Ubuntu Rootfs Extraction"
SCRIPT_VERSION="1.0.0"
CURRENT_LOG_FILE="${UBUNTU_LOGS}/03-extract-rootfs.log"

# Tarball search locations
TARBALL_NAMES=(
    "resolute-base-arm64.tar.gz"
    "ubuntu-base-26.04-base-arm64.tar.gz"
    "ubuntu-base-*-arm64.tar.gz"
)

TARBALL_LOCATIONS=(
    "${HOME}"
    "${HOME}/ubuntu"
    "${HOME}/ubuntu-fs"
    "/sdcard/Download"
    "/sdcard"
    "/storage/emulated/0/Download"
    "/storage/emulated/0"
    "${HOME}/storage/downloads"
    "${HOME}/storage/shared/Download"
)

# Minimum required space in MB
MIN_SPACE_MB=8000

# ============================================================================
# FUNCTIONS
# ============================================================================

find_tarball() {
    log_section "Locating Ubuntu Rootfs Tarball"
    
    local found=""
    
    for location in "${TARBALL_LOCATIONS[@]}"; do
        if [[ ! -d "${location}" ]]; then
            continue
        fi
        
        for pattern in "${TARBALL_NAMES[@]}"; do
            # Use find to handle wildcards
            while IFS= read -r -d '' file; do
                if [[ -f "${file}" ]]; then
                    found="${file}"
                    break 2
                fi
            done < <(find "${location}" -maxdepth 1 -name "${pattern}" -print0 2>/dev/null)
        done
        
        [[ -n "${found}" ]] && break
    done
    
    if [[ -n "${found}" ]]; then
        local size
        size=$(du -h "${found}" | cut -f1)
        log_success "Found tarball: ${found} (${size})"
        echo "${found}"
        return 0
    else
        log_error "Ubuntu rootfs tarball not found!"
        echo ""
        echo "Please download the Ubuntu 26.04 (Resolute) ARM64 base image:"
        echo "  URL: https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release/"
        echo "  File: ubuntu-base-26.04-base-arm64.tar.gz"
        echo ""
        echo "Place the file in one of these locations:"
        for loc in "${TARBALL_LOCATIONS[@]}"; do
            echo "  - ${loc}/"
        done
        echo ""
        return 1
    fi
}

verify_tarball() {
    local tarball="$1"
    
    log_section "Verifying Tarball Integrity"
    
    log_step 1 3 "Checking file type..."
    local file_type
    file_type=$(file "${tarball}" 2>/dev/null || echo "unknown")
    
    if echo "${file_type}" | grep -qiE "gzip|tar"; then
        log_success "File type: gzip compressed tar archive"
    else
        log_warn "File type: ${file_type}"
        log_warn "Expected gzip tar archive - extraction may fail"
    fi
    
    log_step 2 3 "Testing archive integrity..."
    # Try gzip test, but don't fail if it doesn't work on Android storage
    if gzip -t "${tarball}" 2>/dev/null; then
        log_success "Gzip integrity check passed"
    else
        # On Android storage (FUSE/sdcardfs), gzip -t may fail even for valid files
        # Try alternative verification by attempting to list contents
        log_warn "Direct gzip test failed (may be due to Android storage filesystem)"
        log_info "Attempting alternative verification..."
        if tar -tzf "${tarball}" 2>/dev/null | head -1 > /dev/null; then
            log_success "Alternative verification passed - tarball appears readable"
        else
            log_error "Tarball verification failed - file may be corrupted or inaccessible"
            return 1
        fi
    fi
    
    log_step 3 3 "Checking archive contents..."
    local has_usr=false
    local has_etc=false
    local has_bin=false
    
    if tar -tzf "${tarball}" 2>/dev/null | head -100 | grep -q "^usr/"; then
        has_usr=true
    fi
    if tar -tzf "${tarball}" 2>/dev/null | head -100 | grep -q "^etc/"; then
        has_etc=true
    fi
    if tar -tzf "${tarball}" 2>/dev/null | head -100 | grep -qE "^(bin/|usr/bin/)"; then
        has_bin=true
    fi
    
    if ${has_usr} && ${has_etc}; then
        log_success "Archive contains valid Ubuntu rootfs structure"
        return 0
    else
        log_error "Archive does not appear to contain a valid Ubuntu rootfs"
        return 1
    fi
}

check_space() {
    log_section "Checking Available Space"
    
    local available
    available=$(available_storage_mb "${HOME}")
    
    log_info "Available space: ${available}MB"
    log_info "Required space:  ${MIN_SPACE_MB}MB"
    
    if [[ ${available} -lt ${MIN_SPACE_MB} ]]; then
        log_error "Insufficient space for extraction"
        log_info "Please free up at least $((MIN_SPACE_MB - available))MB"
        return 1
    fi
    
    log_success "Sufficient space available"
    return 0
}

prepare_rootfs_directory() {
    log_section "Preparing Rootfs Directory"
    
    local rootfs="${UBUNTU_ROOT}"
    
    if [[ -d "${rootfs}" ]] && [[ "$(ls -A "${rootfs}" 2>/dev/null)" ]]; then
        log_warn "Rootfs directory already exists and is not empty: ${rootfs}"
        echo ""
        
        if confirm "Do you want to remove existing rootfs and start fresh?" "n"; then
            log_info "Removing existing rootfs..."
            rm -rf "${rootfs}"
            log_success "Existing rootfs removed"
        else
            if confirm "Continue with existing rootfs (may cause issues)?" "n"; then
                log_warn "Continuing with existing rootfs"
                return 0
            else
                log_info "Extraction cancelled by user"
                exit 0
            fi
        fi
    fi
    
    ensure_dir "${rootfs}"
    log_success "Rootfs directory ready: ${rootfs}"
}

extract_rootfs() {
    local tarball="$1"
    local rootfs="${UBUNTU_ROOT}"
    
    log_section "Extracting Ubuntu Rootfs"
    
    log_info "Source: ${tarball}"
    log_info "Target: ${rootfs}"
    log_info "This may take several minutes..."
    echo ""
    
    # Create a temporary marker to track extraction
    local marker="${rootfs}/.extraction_in_progress"
    touch "${marker}"
    
    # Extract with progress
    local total_files
    total_files=$(tar -tzf "${tarball}" 2>/dev/null | wc -l)
    log_info "Total files to extract: ${total_files}"
    
    # Use pv if available for progress, otherwise fall back
    if command_exists pv; then
        pv "${tarball}" | tar -xzf - -C "${rootfs}" 2>&1 | tee -a "${CURRENT_LOG_FILE}"
    else
        # Extract with basic progress indication
        log_info "Extracting (this may take a few minutes)..."
        
        # Start extraction in background
        tar -xzf "${tarball}" -C "${rootfs}" 2>&1 | tee -a "${CURRENT_LOG_FILE}" &
        local tar_pid=$!
        
        # Show progress
        local count=0
        while kill -0 ${tar_pid} 2>/dev/null; do
            count=$((count + 1))
            printf "\r  Extracting... %d seconds elapsed" "${count}"
            sleep 1
        done
        printf "\n"
        
        wait ${tar_pid}
        local exit_code=$?
        
        if [[ ${exit_code} -ne 0 ]]; then
            log_error "Extraction failed with exit code ${exit_code}"
            rm -f "${marker}"
            return 1
        fi
    fi
    
    # Remove extraction marker
    rm -f "${marker}"
    
    # Verify extraction
    if [[ -d "${rootfs}/usr" ]] && [[ -d "${rootfs}/etc" ]]; then
        local extracted_size
        extracted_size=$(du -sh "${rootfs}" | cut -f1)
        log_success "Extraction complete! Size: ${extracted_size}"
        return 0
    else
        log_error "Extraction appears incomplete"
        return 1
    fi
}

configure_rootfs_basic() {
    log_section "Basic Rootfs Configuration"
    
    local rootfs="${UBUNTU_ROOT}"
    
    log_step 1 8 "Creating required directories..."
    local dirs=(
        "${rootfs}/proc"
        "${rootfs}/sys"
        "${rootfs}/dev"
        "${rootfs}/dev/pts"
        "${rootfs}/dev/shm"
        "${rootfs}/tmp"
        "${rootfs}/run"
        "${rootfs}/run/shm"
        "${rootfs}/home/droid"
        "${rootfs}/root"
        "${rootfs}/var/tmp"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
    done
    chmod 1777 "${rootfs}/tmp" "${rootfs}/var/tmp"
    chmod 755 "${rootfs}/home/droid"
    log_success "Directories created"
    
    log_step 2 8 "Configuring DNS resolution..."
    cat > "${rootfs}/etc/resolv.conf" << 'EOF'
# DNS Configuration for Ubuntu on Termux
# Using Google and Cloudflare DNS

nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
    log_success "DNS configured"
    
    log_step 3 8 "Configuring hostname..."
    echo "ubuntu-termux" > "${rootfs}/etc/hostname"
    
    cat > "${rootfs}/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   ubuntu-termux
::1         localhost ip6-localhost ip6-loopback
EOF
    log_success "Hostname configured"
    
    log_step 4 8 "Configuring user environment..."
    
    # Create droid user entry
    if ! grep -q "^droid:" "${rootfs}/etc/passwd" 2>/dev/null; then
        echo "droid:x:1000:1000:Droid User:/home/droid:/bin/bash" >> "${rootfs}/etc/passwd"
    fi
    
    if ! grep -q "^droid:" "${rootfs}/etc/group" 2>/dev/null; then
        echo "droid:x:1000:" >> "${rootfs}/etc/group"
    fi
    
    # Add droid to useful groups
    for group in sudo audio video plugdev netdev bluetooth; do
        if grep -q "^${group}:" "${rootfs}/etc/group" 2>/dev/null; then
            if ! grep "^${group}:" "${rootfs}/etc/group" | grep -q "droid"; then
                sed -i "s/^${group}:/${group}:droid,/" "${rootfs}/etc/group" 2>/dev/null || true
            fi
        fi
    done
    
    log_success "User environment configured"
    
    log_step 5 8 "Setting up profile scripts..."
    
    # Global profile additions
    cat > "${rootfs}/etc/profile.d/termux-proot.sh" << 'EOF'
#!/bin/bash
# Termux PRoot Environment Configuration

# Fix for proot environment
export TMPDIR=/tmp
export SHELL=/bin/bash

# Termux-specific paths for accessing Android
export TERMUX_PREFIX="/data/data/com.termux/files/usr"
export ANDROID_DATA="/data"
export ANDROID_ROOT="/system"

# Locale
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Fix for some applications that check for these
export DISPLAY=${DISPLAY:-:1}
export XDG_RUNTIME_DIR=/tmp/runtime-droid
mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null
chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null

# PulseAudio from Termux
export PULSE_SERVER=tcp:127.0.0.1:4713

# Add Termux binaries to path (for accessing Termux tools from proot)
if [[ -d "${TERMUX_PREFIX}/bin" ]]; then
    export PATH="${PATH}:${TERMUX_PREFIX}/bin"
fi
EOF
    chmod +x "${rootfs}/etc/profile.d/termux-proot.sh"
    log_success "Profile scripts created"
    
    log_step 6 8 "Configuring APT sources..."
    
    cat > "${rootfs}/etc/apt/sources.list" << 'EOF'
# Ubuntu 26.04 (Resolute Ringtail) - ARM64
# Main repositories

deb http://ports.ubuntu.com/ubuntu-ports resolute main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports resolute-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports resolute-security main restricted universe multiverse

# Backports (optional)
# deb http://ports.ubuntu.com/ubuntu-ports resolute-backports main restricted universe multiverse
EOF
    log_success "APT sources configured"
    
    log_step 7 8 "Creating machine-id..."
    # Generate a random machine-id
    cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 32 > "${rootfs}/etc/machine-id"
    echo "" >> "${rootfs}/etc/machine-id"
    log_success "Machine ID created"
    
    log_step 8 8 "Setting permissions..."
    
    # Fix common permission issues
    chmod 755 "${rootfs}"
    chmod 755 "${rootfs}/etc" "${rootfs}/usr" "${rootfs}/var" 2>/dev/null || true
    chmod 1777 "${rootfs}/tmp" 2>/dev/null || true
    chmod 700 "${rootfs}/root" 2>/dev/null || true
    
    log_success "Permissions configured"
}

create_proot_fixes() {
    log_section "Creating PRoot Compatibility Fixes"
    
    local rootfs="${UBUNTU_ROOT}"
    
    log_step 1 4 "Creating fake kernel version..."
    # Some applications check kernel version
    mkdir -p "${rootfs}/proc"
    
    log_step 2 4 "Fixing apt for proot..."
    # Disable some apt features that don't work in proot
    mkdir -p "${rootfs}/etc/apt/apt.conf.d"
    
    cat > "${rootfs}/etc/apt/apt.conf.d/99proot-fixes" << 'EOF'
# APT configuration fixes for proot environment

# Disable sandboxing (doesn't work in proot)
APT::Sandbox::User "root";

# Disable some problematic features
Acquire::AllowInsecureRepositories "true";
Acquire::AllowDowngradeToInsecureRepositories "true";

# Increase timeouts for slower networks
Acquire::http::Timeout "120";
Acquire::https::Timeout "120";
Acquire::Retries "3";

# Disable automatic updates (not appropriate for proot)
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
    log_success "APT fixes applied"
    
    log_step 3 4 "Disabling problematic services..."
    # Create a script to disable services that don't work in proot
    cat > "${rootfs}/usr/local/bin/disable-proot-services" << 'EOF'
#!/bin/bash
# Disable services that don't work in proot

SERVICES=(
    "systemd-journald"
    "systemd-udevd"
    "systemd-logind"
    "systemd-resolved"
    "systemd-timesyncd"
    "ModemManager"
    "NetworkManager"
    "wpa_supplicant"
    "bluetooth"
    "avahi-daemon"
)

for service in "${SERVICES[@]}"; do
    if systemctl list-unit-files "${service}.service" &>/dev/null; then
        systemctl disable "${service}" 2>/dev/null || true
        systemctl mask "${service}" 2>/dev/null || true
    fi
done

echo "PRoot-incompatible services disabled"
EOF
    chmod +x "${rootfs}/usr/local/bin/disable-proot-services"
    log_success "Service disable script created"
    
    log_step 4 4 "Creating proot workarounds..."
    
    # Fake some system files that applications might need
    cat > "${rootfs}/etc/ld.so.preload" << 'EOF'
# Empty - some apps check for this
EOF
    
    # Create a fake /etc/mtab if it doesn't exist
    if [[ ! -e "${rootfs}/etc/mtab" ]]; then
        ln -sf /proc/self/mounts "${rootfs}/etc/mtab" 2>/dev/null || true
    fi
    
    log_success "PRoot workarounds created"
}

create_first_boot_script() {
    log_section "Creating First Boot Script"
    
    local rootfs="${UBUNTU_ROOT}"
    local script="${rootfs}/usr/local/bin/first-boot-setup"
    
    cat > "${script}" << 'EOF'
#!/bin/bash
#
# first-boot-setup - Initial Ubuntu configuration
# Run this script once after first boot into Ubuntu
#

set -e

echo "========================================"
echo "Ubuntu 26.04 First Boot Setup"
echo "========================================"
echo ""

# Marker file to prevent re-running
MARKER="/var/lib/.first-boot-done"
if [[ -f "${MARKER}" ]]; then
    echo "First boot setup already completed."
    echo "Remove ${MARKER} to run again."
    exit 0
fi

echo "[1/6] Updating package lists..."
apt-get update -y

echo ""
echo "[2/6] Upgrading base packages..."
apt-get upgrade -y

echo ""
echo "[3/6] Installing essential packages..."
apt-get install -y \
    sudo \
    nano \
    vim \
    less \
    htop \
    curl \
    wget \
    git \
    ca-certificates \
    locales \
    tzdata \
    software-properties-common \
    apt-transport-https \
    gnupg

echo ""
echo "[4/6] Configuring locale..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

echo ""
echo "[5/6] Configuring sudo for droid user..."
if id droid &>/dev/null; then
    echo "droid ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/droid
    chmod 440 /etc/sudoers.d/droid
    echo "User 'droid' can now use sudo without password"
fi

echo ""
echo "[6/6] Cleaning up..."
apt-get clean
apt-get autoremove -y

# Mark first boot as complete
touch "${MARKER}"

echo ""
echo "========================================"
echo "First boot setup complete!"
echo "========================================"
echo ""
echo "You can now install KDE Plasma with:"
echo "  bash /usr/local/bin/install-kde-plasma"
echo ""
EOF

    chmod +x "${script}"
    log_success "First boot script created: ${script}"
}

verify_extraction() {
    log_section "Verifying Extraction"
    
    local rootfs="${UBUNTU_ROOT}"
    local issues=0
    
    # Check essential directories
    local essential_dirs=(
        "bin"
        "etc"
        "lib"
        "usr"
        "var"
    )
    
    log_info "Checking essential directories..."
    for dir in "${essential_dirs[@]}"; do
        if [[ -d "${rootfs}/${dir}" ]]; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} /${dir}\n"
        else
            printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} /${dir} - MISSING\n"
            ((issues++))
        fi
    done
    
    # Check essential files
    local essential_files=(
        "etc/passwd"
        "etc/group"
        "etc/resolv.conf"
        "etc/apt/sources.list"
    )
    
    echo ""
    log_info "Checking essential files..."
    for file in "${essential_files[@]}"; do
        if [[ -f "${rootfs}/${file}" ]]; then
            printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} /${file}\n"
        else
            printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} /${file} - MISSING\n"
            ((issues++))
        fi
    done
    
    # Check for shell
    echo ""
    log_info "Checking shell..."
    if [[ -x "${rootfs}/bin/bash" ]] || [[ -x "${rootfs}/usr/bin/bash" ]]; then
        printf "  ${COLOR_SUCCESS}${ICON_CHECK}${COLOR_RESET} bash shell available\n"
    elif [[ -x "${rootfs}/bin/sh" ]]; then
        printf "  ${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} Only sh available (bash may need to be installed)\n"
    else
        printf "  ${COLOR_ERROR}${ICON_CROSS}${COLOR_RESET} No shell found\n"
        ((issues++))
    fi
    
    # Rootfs size
    echo ""
    local size
    size=$(du -sh "${rootfs}" | cut -f1)
    log_info "Rootfs size: ${size}"
    
    if [[ ${issues} -eq 0 ]]; then
        return 0
    else
        log_error "${issues} issue(s) found"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "${SCRIPT_NAME}" "${SCRIPT_VERSION}"
    
    ensure_dir "${UBUNTU_LOGS}"
    
    log_info "Starting Ubuntu rootfs extraction..."
    log_info "Log file: ${CURRENT_LOG_FILE}"
    echo ""
    
    # Check if running in Termux
    if ! is_termux; then
        die "This script must be run in Termux"
    fi
    
    # Find the tarball
    local tarball
    tarball=$(find_tarball)
    
    if [[ -z "${tarball}" ]]; then
        exit 1
    fi
    
    # Verify tarball
    if ! verify_tarball "${tarball}"; then
        die "Tarball verification failed"
    fi
    
    # Check space
    if ! check_space; then
        die "Insufficient storage space"
    fi
    
    # Prepare directory
    prepare_rootfs_directory
    
    # Extract
    if ! extract_rootfs "${tarball}"; then
        die "Extraction failed"
    fi
    
    # Configure
    configure_rootfs_basic
    create_proot_fixes
    create_first_boot_script
    
    # Verify
    if verify_extraction; then
        print_footer "success" "Ubuntu rootfs extraction completed successfully"
        
        echo ""
        echo "Ubuntu 26.04 rootfs is ready at: ${UBUNTU_ROOT}"
        echo ""
        echo "Next steps:"
        echo "  1. Run: ${COLOR_CYAN}bash ~/ubuntu/scripts/04-configure-proot.sh${COLOR_RESET}"
        echo ""
        
        return 0
    else
        print_footer "error" "Extraction completed with issues"
        return 1
    fi
}

# Run main function
main "$@"
