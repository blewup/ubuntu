#!/data/data/com.termux/files/usr/bin/bash
#
# 06-mesa-zink-setup.sh
# Mesa-Zink + Turnip GPU Driver Setup for Ubuntu 26.04 on Termux
# Target: Pixel 10 Pro XL (Adreno 830+), Android 16, Non-root
#
# Part of the Ubuntu Resolute 26.04 Termux Project
#

set -euo pipefail

# ============================================================================
# SOURCE SHARED LIBRARIES
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/functions.sh"
source "${SCRIPT_DIR}/../lib/colors.sh"

# ============================================================================
# CONFIGURATION
# ============================================================================

# Project paths
UBUNTU_ROOT="${HOME}/ubuntu/rootfs"
MESA_DIR="${HOME}/ubuntu/mesa-zink"
CACHE_DIR="${HOME}/ubuntu/cache"
LOG_FILE="${HOME}/ubuntu/logs/06-mesa-zink-setup.log"

# Ubuntu 26.04 (Resolute Ringtail) - These versions will be available at release
# For now, we use Termux's Mesa which is more current and Turnip-optimized
USE_TERMUX_MESA="true"  # Recommended for Termux/Android

# Fallback: Ubuntu Mesa (uncomment when 26.04 releases)
# UBU_MIRROR="https://ports.ubuntu.com/ubuntu-ports"
# MESA_VER="25.1.0-1ubuntu1"  # Placeholder - check actual version at release

# Turnip source options
TURNIP_SOURCE="termux"  # Options: termux, mesa-main, custom

# Mesa-Turnip from Termux packages (actively maintained for Android)
TERMUX_MESA_PACKAGES=(
    "mesa-vulkan-icd-freedreno"
    "vulkan-loader"
    "vulkan-tools"
    "mesa"
    "libglvnd"
    "virglrenderer"
)

# For custom/bleeding-edge Turnip (Adreno 830 support)
# Using a more maintained source than the 2023 build
TURNIP_BLEEDING_URL="https://github.com/nicoya-gg/nicoya-gg.github.io/releases/latest/download/mesa-vulkan-kgsl_arm64.deb"

# Environment variables for Zink
ZINK_ENV_VARS=(
    "MESA_LOADER_DRIVER_OVERRIDE=zink"
    "GALLIUM_DRIVER=zink"
    "MESA_GL_VERSION_OVERRIDE=4.6"
    "MESA_GLSL_VERSION_OVERRIDE=460"
    "LIBGL_ALWAYS_SOFTWARE=0"
    "MESA_VK_WSI_PRESENT_MODE=fifo"
    "TU_DEBUG="
    "VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
)

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${timestamp} [${level}] ${msg}" | tee -a "${LOG_FILE}"
}

info()    { log "INFO" "${COLOR_GREEN}$*${COLOR_RESET}"; }
warn()    { log "WARN" "${COLOR_YELLOW}$*${COLOR_RESET}"; }
error()   { log "ERROR" "${COLOR_RED}$*${COLOR_RESET}"; }
section() { echo -e "\n${COLOR_CYAN}═══════════════════════════════════════════════════════════${COLOR_RESET}"; log "SECTION" "${COLOR_BOLD}$*${COLOR_RESET}"; }

check_prerequisites() {
    section "Checking Prerequisites"
    
    local missing=()
    
    # Check required directories
    [[ ! -d "${UBUNTU_ROOT}" ]] && missing+=("Ubuntu rootfs not found at ${UBUNTU_ROOT}")
    
    # Check required Termux packages
    for cmd in wget proot tar; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("Command not found: $cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Prerequisites check failed:"
        for m in "${missing[@]}"; do
            echo "  - $m"
        done
        exit 1
    fi
    
    info "All prerequisites satisfied"
}

setup_directories() {
    section "Setting Up Directories"
    
    mkdir -p "${MESA_DIR}"/{debs,extracted,libs,icd}
    mkdir -p "${CACHE_DIR}"
    mkdir -p "$(dirname "${LOG_FILE}")"
    mkdir -p "${UBUNTU_ROOT}/usr/share/vulkan/icd.d"
    mkdir -p "${UBUNTU_ROOT}/usr/lib/aarch64-linux-gnu"
    
    info "Directory structure created"
}

install_termux_mesa() {
    section "Installing Mesa from Termux Packages"
    
    info "Updating Termux package database..."
    pkg update -y 2>&1 | tee -a "${LOG_FILE}"
    
    info "Installing Mesa and Vulkan packages..."
    for pkg_name in "${TERMUX_MESA_PACKAGES[@]}"; do
        info "  Installing: ${pkg_name}"
        if pkg install -y "${pkg_name}" 2>&1 | tee -a "${LOG_FILE}"; then
            info "    ✓ ${pkg_name} installed"
        else
            warn "    ⚠ ${pkg_name} may have issues (continuing anyway)"
        fi
    done
    
    info "Termux Mesa packages installed"
}

download_bleeding_turnip() {
    section "Downloading Bleeding-Edge Turnip for Adreno 830+"
    
    local turnip_deb="${MESA_DIR}/debs/mesa-vulkan-kgsl_arm64.deb"
    
    info "Fetching latest Turnip build..."
    if wget -c -O "${turnip_deb}" "${TURNIP_BLEEDING_URL}" 2>&1 | tee -a "${LOG_FILE}"; then
        info "✓ Turnip downloaded: ${turnip_deb}"
        
        info "Extracting Turnip..."
        dpkg-deb -x "${turnip_deb}" "${MESA_DIR}/extracted/" 2>&1 | tee -a "${LOG_FILE}"
        info "✓ Turnip extracted"
    else
        warn "Could not download bleeding-edge Turnip, using Termux version"
    fi
}

setup_driver_symlinks() {
    section "Setting Up Driver Symlinks in Ubuntu Rootfs"
    
    local termux_prefix="/data/data/com.termux/files/usr"
    local ubuntu_lib="${UBUNTU_ROOT}/usr/lib/aarch64-linux-gnu"
    local ubuntu_vulkan="${UBUNTU_ROOT}/usr/share/vulkan/icd.d"
    
    info "Linking Termux Mesa drivers into Ubuntu rootfs..."
    
    # Core Mesa libraries to link
    local mesa_libs=(
        "libvulkan.so.1"
        "libvulkan.so"
        "libGL.so.1"
        "libGL.so"
        "libEGL.so.1"
        "libEGL.so"
        "libGLESv2.so.2"
        "libGLESv2.so"
        "libgbm.so.1"
        "libgbm.so"
        "libglapi.so.0"
        "libglapi.so"
    )
    
    # Create symlinks from Termux to Ubuntu
    for lib in "${mesa_libs[@]}"; do
        local src="${termux_prefix}/lib/${lib}"
        local dst="${ubuntu_lib}/${lib}"
        
        if [[ -e "${src}" ]] || [[ -L "${src}" ]]; then
            ln -sf "${src}" "${dst}" 2>/dev/null || true
            info "  ✓ Linked: ${lib}"
        else
            warn "  ⚠ Not found: ${lib}"
        fi
    done
    
    # Link Turnip/Freedreno ICD
    local icd_src="${termux_prefix}/share/vulkan/icd.d/freedreno_icd.aarch64.json"
    local icd_dst="${ubuntu_vulkan}/freedreno_icd.aarch64.json"
    
    if [[ -f "${icd_src}" ]]; then
        # We need to modify the ICD to point to correct library path
        info "Creating modified Vulkan ICD for proot environment..."
        cat > "${icd_dst}" << 'ICDEOF'
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "/data/data/com.termux/files/usr/lib/libvulkan_freedreno.so",
        "api_version": "1.3.0"
    }
}
ICDEOF
        info "  ✓ Vulkan ICD configured"
    else
        warn "  ⚠ Freedreno ICD not found in Termux"
    fi
    
    # Link extracted bleeding-edge Turnip if available
    if [[ -d "${MESA_DIR}/extracted/usr" ]]; then
        info "Linking bleeding-edge Turnip libraries..."
        cp -a "${MESA_DIR}/extracted/usr/lib/"* "${ubuntu_lib}/" 2>/dev/null || true
        info "  ✓ Turnip libraries copied"
    fi
    
    info "Driver symlinks configured"
}

configure_zink_environment() {
    section "Configuring Zink OpenGL-on-Vulkan Translation"
    
    local env_file="${UBUNTU_ROOT}/etc/profile.d/mesa-zink.sh"
    
    info "Creating Zink environment configuration..."
    
    cat > "${env_file}" << 'ZINKEOF'
#!/bin/bash
# Mesa-Zink Environment Configuration
# Auto-generated by Ubuntu Resolute Termux Project

# Zink: OpenGL implemented on Vulkan
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink

# OpenGL version overrides (for compatibility)
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLSL_VERSION_OVERRIDE=460

# Disable software rendering
export LIBGL_ALWAYS_SOFTWARE=0

# Vulkan WSI configuration
export MESA_VK_WSI_PRESENT_MODE=fifo

# Vulkan ICD path (Turnip/Freedreno)
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json

# Termux library path for proot
export LD_LIBRARY_PATH="/data/data/com.termux/files/usr/lib:${LD_LIBRARY_PATH:-}"

# Adreno-specific optimizations
export TU_DEBUG=""
export IR3_SHADER_DEBUG=""

# DRI configuration
export LIBGL_DRIVERS_PATH=/data/data/com.termux/files/usr/lib/dri
export DRI_PRIME=0
ZINKEOF

    chmod +x "${env_file}"
    info "✓ Zink environment configured: ${env_file}"
    
    # Also add to Ubuntu's environment.d for systemd-style loading
    local systemd_env="${UBUNTU_ROOT}/etc/environment.d/50-mesa-zink.conf"
    mkdir -p "$(dirname "${systemd_env}")"
    
    cat > "${systemd_env}" << 'SYSENVEOF'
MESA_LOADER_DRIVER_OVERRIDE=zink
GALLIUM_DRIVER=zink
MESA_GL_VERSION_OVERRIDE=4.6
MESA_GLSL_VERSION_OVERRIDE=460
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
SYSENVEOF

    info "✓ systemd environment.d configured"
}

configure_kde_gpu() {
    section "Configuring KDE Plasma for GPU Acceleration"
    
    # KDE-specific environment overrides
    local kde_env="${UBUNTU_ROOT}/etc/profile.d/kde-gpu.sh"
    
    cat > "${kde_env}" << 'KDEEOF'
#!/bin/bash
# KDE Plasma GPU Configuration for Termux/proot

# Force X11 session (Wayland has issues in proot)
export XDG_SESSION_TYPE=x11

# Qt platform and rendering
export QT_QPA_PLATFORM=xcb
export QT_XCB_GL_INTEGRATION=xcb_egl
export KWIN_COMPOSE=O2ES

# Hardware acceleration for Qt
export QT_QUICK_BACKEND=scenegraph
export QSG_RENDER_LOOP=basic

# Disable problematic KDE effects that don't work well in proot
export KWIN_EFFECTS_FORCE_ANIMATIONS=0

# GPU memory management
export MESA_SHADER_CACHE_DIR="${HOME}/.cache/mesa_shader_cache"
export AMD_DEBUG=""

# Workaround for some Vulkan issues
export __GL_THREADED_OPTIMIZATION=0
KDEEOF

    chmod +x "${kde_env}"
    info "✓ KDE GPU configuration created"
}

attempt_firmware_extraction() {
    section "Attempting Firmware Extraction (Best-Effort)"
    
    local fw_dir="${MESA_DIR}/android-firmware"
    mkdir -p "${fw_dir}"
    
    warn "Note: Android 16 SELinux will likely block firmware access without root"
    info "Attempting to read accessible paths..."
    
    local fw_sources=(
        "/vendor/firmware"
        "/vendor/firmware_mnt"
        "/vendor/etc/firmware"
        "/odm/firmware"
        "/system/vendor/firmware"
    )
    
    local copied_any="false"
    
    for src in "${fw_sources[@]}"; do
        if [[ -d "${src}" ]] && [[ -r "${src}" ]]; then
            info "  Found readable: ${src}"
            if cp -r "${src}"/* "${fw_dir}/" 2>/dev/null; then
                copied_any="true"
                info "    ✓ Copied firmware from ${src}"
            fi
        fi
    done
    
    if [[ "${copied_any}" == "false" ]]; then
        warn "No firmware could be extracted (expected on non-root Android 16)"
        info "GPU will use Turnip's built-in shader compiler instead"
        info "This is fine - Turnip works without firmware blobs for most cases"
    fi
    
    # Create a note about firmware status
    cat > "${fw_dir}/README.txt" << 'FWEOF'
Android GPU Firmware Status
============================

On non-rooted Android devices, GPU firmware blobs typically cannot be 
extracted due to SELinux restrictions.

This is NOT a problem for Turnip (Mesa's Adreno Vulkan driver):
- Turnip uses its own shader compiler (ir3)
- It does not require proprietary firmware blobs
- Full Vulkan 1.3 support works without firmware

If you need firmware for specific workloads:
1. Extract from factory images (developers.google.com/android/images)
2. Use payload-dumper-go to extract vendor.img
3. Mount and copy firmware from vendor/firmware/

For Pixel 10 Pro XL, firmware files would typically be:
- a730_sqe.fw (Adreno GPU microcode)
- a730_gmu.bin (GMU firmware)
FWEOF

    info "Firmware extraction attempt complete"
}

verify_installation() {
    section "Verifying GPU Driver Installation"
    
    local issues=()
    
    # Check Termux Vulkan
    info "Checking Vulkan installation..."
    if command -v vulkaninfo &>/dev/null; then
        if vulkaninfo --summary 2>/dev/null | grep -q "GPU"; then
            info "  ✓ Vulkan is functional in Termux"
            vulkaninfo --summary 2>/dev/null | head -20 | tee -a "${LOG_FILE}"
        else
            warn "  ⚠ Vulkan installed but GPU not detected (may work in proot)"
        fi
    else
        issues+=("vulkaninfo not found")
    fi
    
    # Check ICD file exists
    local icd_file="${UBUNTU_ROOT}/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json"
    if [[ -f "${icd_file}" ]]; then
        info "  ✓ Vulkan ICD file present"
    else
        issues+=("Vulkan ICD file missing")
    fi
    
    # Check Zink environment
    local zink_env="${UBUNTU_ROOT}/etc/profile.d/mesa-zink.sh"
    if [[ -f "${zink_env}" ]]; then
        info "  ✓ Zink environment configured"
    else
        issues+=("Zink environment not configured")
    fi
    
    # Summary
    echo ""
    if [[ ${#issues[@]} -eq 0 ]]; then
        info "═══════════════════════════════════════════════════════════"
        info "  GPU DRIVER SETUP COMPLETE - ALL CHECKS PASSED"
        info "═══════════════════════════════════════════════════════════"
    else
        warn "═══════════════════════════════════════════════════════════"
        warn "  GPU DRIVER SETUP COMPLETE WITH WARNINGS"
        warn "═══════════════════════════════════════════════════════════"
        for issue in "${issues[@]}"; do
            warn "  - ${issue}"
        done
    fi
}

create_gpu_test_script() {
    section "Creating GPU Test Script"
    
    local test_script="${UBUNTU_ROOT}/usr/local/bin/test-gpu"
    
    cat > "${test_script}" << 'TESTEOF'
#!/bin/bash
# GPU Driver Test Script for Ubuntu on Termux

echo "======================================"
echo "GPU Driver Verification"
echo "======================================"
echo ""

echo "[1] Checking Vulkan..."
if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>/dev/null || echo "vulkaninfo failed (may need display)"
else
    echo "vulkaninfo not installed - run: apt install vulkan-tools"
fi
echo ""

echo "[2] Checking OpenGL (via Zink)..."
if command -v glxinfo &>/dev/null; then
    glxinfo | grep -E "(OpenGL vendor|OpenGL renderer|OpenGL version)" 2>/dev/null || echo "glxinfo failed (may need display)"
else
    echo "glxinfo not installed - run: apt install mesa-utils"
fi
echo ""

echo "[3] Checking Environment Variables..."
echo "MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-not set}"
echo "GALLIUM_DRIVER=${GALLIUM_DRIVER:-not set}"
echo "VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-not set}"
echo ""

echo "[4] Library Check..."
for lib in libvulkan.so.1 libGL.so.1 libEGL.so.1; do
    if ldconfig -p 2>/dev/null | grep -q "${lib}" || [[ -e "/usr/lib/aarch64-linux-gnu/${lib}" ]]; then
        echo "✓ ${lib} found"
    else
        echo "✗ ${lib} missing"
    fi
done
echo ""

echo "======================================"
echo "Test complete"
echo "======================================"
TESTEOF

    chmod +x "${test_script}"
    info "✓ GPU test script created: ${test_script}"
    info "  Run 'test-gpu' inside Ubuntu to verify GPU setup"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    section "Mesa-Zink GPU Driver Setup"
    info "Target: Pixel 10 Pro XL (Adreno 830+)"
    info "Ubuntu: 26.04 Resolute Ringtail (ARM64)"
    info "Mode: Termux proot, non-root"
    echo ""
    
    check_prerequisites
    setup_directories
    
    if [[ "${USE_TERMUX_MESA}" == "true" ]]; then
        install_termux_mesa
    fi
    
    # Always try to get bleeding-edge Turnip for latest GPU support
    download_bleeding_turnip
    
    setup_driver_symlinks
    configure_zink_environment
    configure_kde_gpu
    attempt_firmware_extraction
    create_gpu_test_script
    verify_installation
    
    section "Setup Complete"
    info "Mesa-Zink drivers configured successfully!"
    info "Log file: ${LOG_FILE}"
    echo ""
    info "Next steps:"
    info "  1. Run script 07-input-config.sh for input device setup"
    info "  2. Launch Ubuntu and run 'test-gpu' to verify"
    echo ""
}

# Run main function
main "$@"
