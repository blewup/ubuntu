#!/data/data/com.termux/files/usr/bin/bash
#
# 11-pkvm-integration.sh
# pKVM (Protected KVM) / AVF Integration for Hybrid Virtualization
#
# Sets up bridge between proot Ubuntu and Android's pKVM/AVF
# for running isolated workloads in protected VMs.
#
# Version: 1.0.0
#

set -euo pipefail

# ============================================================================
# INITIALIZATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${UBUNTU_PROJECT_ROOT}/lib/colors.sh" 2>/dev/null || {
    COLOR_RESET=""
    COLOR_GREEN=""
    COLOR_CYAN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_BOLD=""
}

source "${UBUNTU_PROJECT_ROOT}/lib/functions.sh" 2>/dev/null || {
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[OK] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_section() { echo ""; echo "=== $* ==="; echo ""; }
    ensure_dir() { mkdir -p "$1" 2>/dev/null || true; }
}

SCRIPT_NAME="pKVM/AVF Integration"
SCRIPT_VERSION="1.0.0"

UBUNTU_LOGS="${UBUNTU_PROJECT_ROOT}/logs"
PKVM_DIR="${UBUNTU_PROJECT_ROOT}/pkvm"
PKVM_IMAGES="${PKVM_DIR}/images"
PKVM_CONFIG="${PKVM_DIR}/config"
PKVM_SHARED="${PKVM_DIR}/shared"
PKVM_LOGS="${PKVM_DIR}/logs"
DOCS_DIR="${UBUNTU_PROJECT_ROOT}/docs"

# ============================================================================
# DEVICE INFORMATION
# ============================================================================

check_device_info() {
    log_section "Device Information"
    
    local model=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    local device=$(getprop ro.product.device 2>/dev/null || echo "Unknown")
    local android=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    local sdk=$(getprop ro.build.version.sdk 2>/dev/null || echo "Unknown")
    local kernel=$(uname -r)
    local arch=$(uname -m)
    
    echo ""
    printf "  %-16s %s\n" "Device:" "${model}"
    printf "  %-16s %s\n" "Codename:" "${device}"
    printf "  %-16s %s\n" "Android:" "${android}"
    printf "  %-16s %s\n" "SDK:" "${sdk}"
    printf "  %-16s %s\n" "Kernel:" "${kernel}"
    printf "  %-16s %s\n" "Architecture:" "${arch}"
    echo ""
}

# ============================================================================
# PKVM SUPPORT DETECTION
# ============================================================================

check_pkvm_support() {
    log_section "Checking Virtualization Support"
    
    local score=0
    local max_score=5
    
    # Check 1: Android version (13+ for AVF)
    echo "  [1/5] Checking Android version..."
    local sdk=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
    if [[ ${sdk} -ge 33 ]]; then
        echo "        ${COLOR_GREEN:-}✓${COLOR_RESET:-} Android 13+ (SDK ${sdk}) - AVF supported"
        ((score++))
    elif [[ ${sdk} -ge 30 ]]; then
        echo "        ${COLOR_YELLOW:-}⚠${COLOR_RESET:-} Android 11-12 (SDK ${sdk}) - Limited support"
    else
        echo "        ${COLOR_RED:-}✗${COLOR_RESET:-} Android too old (SDK ${sdk})"
    fi
    
    # Check 2: AVF system property
    echo "  [2/5] Checking AVF framework..."
    local avf_supported=$(getprop ro.boot.hypervisor.vm.supported 2>/dev/null || echo "")
    if [[ "${avf_supported}" == "1" ]]; then
        echo "        ${COLOR_GREEN:-}✓${COLOR_RESET:-} AVF (Android Virtualization Framework) enabled"
        ((score++))
    else
        echo "        ${COLOR_YELLOW:-}○${COLOR_RESET:-} AVF property not set"
    fi
    
    # Check 3: Protected VM support
    echo "  [3/5] Checking Protected VM support..."
    local pvm_supported=$(getprop ro.boot.hypervisor.protected_vm.supported 2>/dev/null || echo "")
    if [[ "${pvm_supported}" == "1" ]]; then
        echo "        ${COLOR_GREEN:-}✓${COLOR_RESET:-} Protected VM (pVM) supported"
        ((score++))
    else
        echo "        ${COLOR_YELLOW:-}○${COLOR_RESET:-} Protected VM not explicitly enabled"
    fi
    
    # Check 4: KVM device
    echo "  [4/5] Checking KVM device..."
    if [[ -c "/dev/kvm" ]]; then
        echo "        ${COLOR_GREEN:-}✓${COLOR_RESET:-} /dev/kvm available"
        ((score++))
    else
        echo "        ${COLOR_YELLOW:-}○${COLOR_RESET:-} /dev/kvm not accessible (requires root)"
    fi
    
    # Check 5: Pixel device detection
    echo "  [5/5] Checking device type..."
    local device=$(getprop ro.product.device 2>/dev/null || echo "unknown")
    local pixel_devices="oriole raven bluejay panther cheetah lynx tangorpro felix shiba husky akita caiman komodo tokay comet"
    
    if echo "${pixel_devices}" | grep -qw "${device}"; then
        echo "        ${COLOR_GREEN:-}✓${COLOR_RESET:-} Pixel device (${device}) - Enhanced pKVM"
        ((score++))
    else
        echo "        ${COLOR_YELLOW:-}○${COLOR_RESET:-} Non-Pixel device (${device})"
    fi
    
    # Summary
    echo ""
    echo "  Virtualization score: ${score}/${max_score}"
    echo ""
    
    if [[ ${score} -ge 3 ]]; then
        log_success "Good virtualization support detected"
        return 0
    elif [[ ${score} -ge 1 ]]; then
        log_warn "Limited virtualization support - QEMU fallback recommended"
        return 0
    else
        log_warn "Minimal virtualization support - QEMU fallback required"
        return 1
    fi
}

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

setup_pkvm_directories() {
    log_section "Setting Up pKVM Directories"
    
    ensure_dir "${PKVM_DIR}"
    ensure_dir "${PKVM_IMAGES}"
    ensure_dir "${PKVM_CONFIG}"
    ensure_dir "${PKVM_SHARED}"
    ensure_dir "${PKVM_LOGS}"
    
    log_success "Directories created"
    log_info "  Base:   ${PKVM_DIR}"
    log_info "  Images: ${PKVM_IMAGES}"
    log_info "  Config: ${PKVM_CONFIG}"
    log_info "  Shared: ${PKVM_SHARED}"
    log_info "  Logs:   ${PKVM_LOGS}"
}

# ============================================================================
# PKVM BRIDGE SCRIPT
# ============================================================================

create_pkvm_bridge() {
    log_section "Creating pKVM Bridge Script"
    
    cat > "${UBUNTU_PROJECT_ROOT}/scripts/pkvm-bridge.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# pkvm-bridge.sh - pKVM/AVF Bridge Controller
#
# Provides interface between proot Ubuntu and Android virtualization
#
# Usage:
#   pkvm-bridge.sh status      Show virtualization status
#   pkvm-bridge.sh info        Detailed system info
#   pkvm-bridge.sh qemu        Setup QEMU fallback
#   pkvm-bridge.sh run <img>   Run VM image
#   pkvm-bridge.sh create      Create new VM image
#   pkvm-bridge.sh list        List available images
#

set -euo pipefail

PKVM_DIR="${HOME}/ubuntu/pkvm"
PKVM_IMAGES="${PKVM_DIR}/images"
PKVM_LOGS="${PKVM_DIR}/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${BOLD}pKVM / AVF Bridge Controller${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# STATUS COMMAND
# ============================================================================

cmd_status() {
    echo -e "${BOLD}Virtualization Status${NC}"
    echo "====================="
    echo ""
    
    # Device info
    echo "Device: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
    echo "Android: $(getprop ro.build.version.release 2>/dev/null) (SDK $(getprop ro.build.version.sdk 2>/dev/null))"
    echo "Kernel: $(uname -r)"
    echo ""
    
    # Virtualization support
    echo -e "${BOLD}Virtualization:${NC}"
    
    local avf=$(getprop ro.boot.hypervisor.vm.supported 2>/dev/null || echo "0")
    local pvm=$(getprop ro.boot.hypervisor.protected_vm.supported 2>/dev/null || echo "0")
    
    if [[ "${avf}" == "1" ]]; then
        echo -e "  AVF:          ${GREEN}Enabled${NC}"
    else
        echo -e "  AVF:          ${YELLOW}Not detected${NC}"
    fi
    
    if [[ "${pvm}" == "1" ]]; then
        echo -e "  Protected VM: ${GREEN}Enabled${NC}"
    else
        echo -e "  Protected VM: ${YELLOW}Not detected${NC}"
    fi
    
    if [[ -c "/dev/kvm" ]]; then
        echo -e "  /dev/kvm:     ${GREEN}Available${NC}"
    else
        echo -e "  /dev/kvm:     ${YELLOW}Not accessible${NC}"
    fi
    
    # QEMU availability
    echo ""
    echo -e "${BOLD}QEMU (Fallback):${NC}"
    if command -v qemu-system-aarch64 &>/dev/null; then
        local qemu_ver=$(qemu-system-aarch64 --version | head -1)
        echo -e "  Status:  ${GREEN}Installed${NC}"
        echo "  Version: ${qemu_ver}"
    else
        echo -e "  Status:  ${YELLOW}Not installed${NC}"
        echo "  Install: pkg install qemu-system-aarch64"
    fi
    
    # VM Images
    echo ""
    echo -e "${BOLD}VM Images:${NC}"
    if [[ -d "${PKVM_IMAGES}" ]]; then
        local count=$(find "${PKVM_IMAGES}" -name "*.qcow2" -o -name "*.img" 2>/dev/null | wc -l)
        echo "  Location: ${PKVM_IMAGES}"
        echo "  Count:    ${count} image(s)"
    else
        echo "  No images directory"
    fi
    
    echo ""
}

# ============================================================================
# INFO COMMAND
# ============================================================================

cmd_info() {
    echo -e "${BOLD}Detailed System Information${NC}"
    echo "============================"
    echo ""
    
    echo -e "${CYAN}CPU Information:${NC}"
    if [[ -f /proc/cpuinfo ]]; then
        grep -E "^(processor|Hardware|Features|CPU implementer|CPU architecture)" /proc/cpuinfo 2>/dev/null | head -10 || echo "  Unable to read"
    fi
    echo ""
    
    echo -e "${CYAN}Memory:${NC}"
    free -h 2>/dev/null || cat /proc/meminfo | head -3
    echo ""
    
    echo -e "${CYAN}Storage:${NC}"
    df -h "${HOME}" 2>/dev/null | tail -1
    echo ""
    
    echo -e "${CYAN}Hypervisor Properties:${NC}"
    getprop 2>/dev/null | grep -iE "hypervisor|kvm|vm\.supported|virt" | head -10 || echo "  None found"
    echo ""
    
    echo -e "${CYAN}Kernel Config (if available):${NC}"
    if [[ -f "/proc/config.gz" ]]; then
        zcat /proc/config.gz 2>/dev/null | grep -E "^CONFIG_(KVM|VIRT|HYP)" | head -10 || echo "  Unable to read"
    else
        echo "  Kernel config not available"
    fi
    echo ""
}

# ============================================================================
# QEMU SETUP COMMAND
# ============================================================================

cmd_setup_qemu() {
    echo -e "${BOLD}Setting Up QEMU Fallback${NC}"
    echo "========================="
    echo ""
    
    # Check if already installed
    if command -v qemu-system-aarch64 &>/dev/null; then
        echo -e "${GREEN}QEMU is already installed${NC}"
        qemu-system-aarch64 --version | head -1
    else
        echo "Installing QEMU..."
        pkg update -y
        pkg install -y qemu-system-aarch64 qemu-utils
        
        if command -v qemu-system-aarch64 &>/dev/null; then
            echo -e "${GREEN}QEMU installed successfully${NC}"
        else
            echo -e "${RED}Failed to install QEMU${NC}"
            return 1
        fi
    fi
    
    echo ""
    echo -e "${GREEN}QEMU setup complete!${NC}"
    echo ""
    echo "Usage:"
    echo "  Create image: pkvm-bridge.sh create myvm 20G"
    echo "  Run VM:       pkvm-bridge.sh run myvm.qcow2"
    echo ""
}

# ============================================================================
# CREATE VM IMAGE COMMAND
# ============================================================================

cmd_create() {
    local name="${1:-}"
    local size="${2:-20G}"
    
    if [[ -z "${name}" ]]; then
        echo "Usage: pkvm-bridge.sh create <name> [size]"
        echo ""
        echo "Examples:"
        echo "  pkvm-bridge.sh create ubuntu 20G"
        echo "  pkvm-bridge.sh create alpine 8G"
        return 1
    fi
    
    # Check for qemu-img
    if ! command -v qemu-img &>/dev/null; then
        echo "qemu-img not found. Installing QEMU tools..."
        pkg install -y qemu-utils
    fi
    
    mkdir -p "${PKVM_IMAGES}"
    local output="${PKVM_IMAGES}/${name}.qcow2"
    
    if [[ -f "${output}" ]]; then
        echo "Image already exists: ${output}"
        read -p "Overwrite? [y/N] " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            echo "Cancelled"
            return 1
        fi
    fi
    
    echo "Creating VM image..."
    echo "  Name: ${name}"
    echo "  Size: ${size}"
    echo "  Path: ${output}"
    echo ""
    
    qemu-img create -f qcow2 "${output}" "${size}"
    
    echo ""
    echo -e "${GREEN}Image created: ${output}${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Download an ISO or rootfs"
    echo "  2. Boot with: pkvm-bridge.sh run ${name}.qcow2"
    echo ""
}

# ============================================================================
# LIST IMAGES COMMAND
# ============================================================================

cmd_list() {
    echo -e "${BOLD}Available VM Images${NC}"
    echo "==================="
    echo ""
    echo "Location: ${PKVM_IMAGES}"
    echo ""
    
    if [[ ! -d "${PKVM_IMAGES}" ]]; then
        echo "No images directory found"
        return 0
    fi
    
    local found=0
    while IFS= read -r -d '' img; do
        ((found++))
        local name=$(basename "${img}")
        local size=$(du -h "${img}" | cut -f1)
        local vsize=$(qemu-img info "${img}" 2>/dev/null | grep "virtual size" | awk '{print $3}')
        printf "  %-30s %8s (virtual: %s)\n" "${name}" "${size}" "${vsize:-unknown}"
    done < <(find "${PKVM_IMAGES}" -type f \( -name "*.qcow2" -o -name "*.img" -o -name "*.raw" \) -print0 2>/dev/null)
    
    if [[ ${found} -eq 0 ]]; then
        echo "  No images found"
        echo ""
        echo "Create one with: pkvm-bridge.sh create <name> <size>"
    fi
    
    echo ""
}

# ============================================================================
# RUN VM COMMAND
# ============================================================================

cmd_run() {
    local image="${1:-}"
    local memory="${2:-2G}"
    local cpus="${3:-2}"
    
    if [[ -z "${image}" ]]; then
        echo "Usage: pkvm-bridge.sh run <image> [memory] [cpus]"
        echo ""
        echo "Examples:"
        echo "  pkvm-bridge.sh run ubuntu.qcow2"
        echo "  pkvm-bridge.sh run ubuntu.qcow2 4G 4"
        echo ""
        cmd_list
        return 1
    fi
    
    # Check if image exists
    if [[ ! -f "${image}" ]]; then
        if [[ -f "${PKVM_IMAGES}/${image}" ]]; then
            image="${PKVM_IMAGES}/${image}"
        else
            echo "Error: Image not found: ${image}"
            return 1
        fi
    fi
    
    # Check for QEMU
    if ! command -v qemu-system-aarch64 &>/dev/null; then
        echo "QEMU not installed. Run: pkvm-bridge.sh qemu"
        return 1
    fi
    
    echo "Starting QEMU VM..."
    echo "  Image:  ${image}"
    echo "  Memory: ${memory}"
    echo "  CPUs:   ${cpus}"
    echo ""
    echo "Network forwards:"
    echo "  SSH: localhost:2222 -> VM:22"
    echo "  VNC: localhost:5900 -> VM:5900"
    echo ""
    echo "Press Ctrl+A then X to exit"
    echo ""
    
    mkdir -p "${PKVM_LOGS}"
    
    exec qemu-system-aarch64 \
        -M virt \
        -cpu max \
        -smp "${cpus}" \
        -m "${memory}" \
        -drive "file=${image},format=qcow2,if=virtio" \
        -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::5900-:5900 \
        -device virtio-net-pci,netdev=net0 \
        -device virtio-gpu-pci \
        -device virtio-keyboard-pci \
        -device virtio-mouse-pci \
        -serial mon:stdio \
        -nographic
}

# ============================================================================
# HELP COMMAND
# ============================================================================

cmd_help() {
    echo "pKVM/AVF Bridge Controller"
    echo ""
    echo "Usage: $(basename "$0") <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status          Show virtualization status"
    echo "  info            Detailed system information"
    echo "  qemu            Setup QEMU fallback"
    echo "  create <n> [s]  Create VM image (name, size)"
    echo "  list            List available VM images"
    echo "  run <img> [m c] Run VM (image, memory, cpus)"
    echo "  help            Show this help"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") status"
    echo "  $(basename "$0") create ubuntu 20G"
    echo "  $(basename "$0") run ubuntu.qcow2 4G 4"
    echo ""
    echo "Notes:"
    echo "  - Full pKVM requires root access"
    echo "  - QEMU provides software virtualization fallback"
    echo "  - AVF is available on Pixel devices with Android 13+"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    case "${1:-}" in
        status)
            print_banner
            cmd_status
            ;;
        info)
            print_banner
            cmd_info
            ;;
        qemu|setup-qemu)
            print_banner
            cmd_setup_qemu
            ;;
        create)
            cmd_create "${2:-}" "${3:-20G}"
            ;;
        list|ls)
            cmd_list
            ;;
        run)
            cmd_run "${2:-}" "${3:-2G}" "${4:-2}"
            ;;
        help|--help|-h)
            print_banner
            cmd_help
            ;;
        "")
            print_banner
            cmd_help
            ;;
        *)
            echo "Unknown command: $1"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
SCRIPTEOF

    chmod +x "${UBUNTU_PROJECT_ROOT}/scripts/pkvm-bridge.sh"
    log_success "Created: pkvm-bridge.sh"
}

# ============================================================================
# AVF INFO SCRIPT
# ============================================================================

create_avf_info() {
    log_info "Creating avf-info.sh..."
    
    cat > "${PKVM_DIR}/avf-info.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# avf-info.sh - Android Virtualization Framework Information
#

echo "Android Virtualization Framework (AVF) Status"
echo "=============================================="
echo ""

echo "System Properties:"
echo "------------------"
props=(
    "ro.boot.hypervisor.vm.supported"
    "ro.boot.hypervisor.protected_vm.supported"
    "ro.boot.hypervisor.version"
    "dalvik.vm.isa.arm64.features"
    "ro.crypto.state"
    "ro.hardware.vulkan"
)

for prop in "${props[@]}"; do
    value=$(getprop "${prop}" 2>/dev/null || echo "not set")
    printf "  %-45s %s\n" "${prop}:" "${value}"
done

echo ""
echo "Kernel Support:"
echo "---------------"
if [[ -c "/dev/kvm" ]]; then
    echo "  /dev/kvm: Present"
    ls -la /dev/kvm 2>/dev/null || true
else
    echo "  /dev/kvm: Not accessible (requires root)"
fi

echo ""
echo "CPU Features:"
echo "-------------"
grep -E "^Features" /proc/cpuinfo 2>/dev/null | head -1 | sed 's/Features\s*:/  /'

echo ""
echo "Notes:"
echo "------"
echo "  - AVF requires Android 13+ (API 33+)"
echo "  - Full pKVM requires Pixel 6 or newer"
echo "  - Third-party apps need special permissions"
echo "  - QEMU can be used as software fallback"
echo ""
SCRIPTEOF

    chmod +x "${PKVM_DIR}/avf-info.sh"
}

# ============================================================================
# HYBRID CONTROLLER SCRIPT
# ============================================================================

create_hybrid_controller() {
    log_info "Creating hybrid-controller.sh..."
    
    cat > "${PKVM_DIR}/hybrid-controller.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# hybrid-controller.sh - Hybrid proot + VM Controller
#
# Manages the hybrid setup where:
# - Main Ubuntu runs in proot (fast, integrated)
# - Isolated workloads can run in QEMU VMs (secure, sandboxed)
#

UBUNTU_HOME="${HOME}/ubuntu"
PKVM_DIR="${UBUNTU_HOME}/pkvm"

echo "Hybrid Virtualization Controller"
echo "================================="
echo ""
echo "Current Setup:"
echo "  PRoot Ubuntu:   Main desktop environment (fast, integrated)"
echo "  QEMU VMs:       Isolated workloads (secure, sandboxed)"
echo ""
echo "Use Cases for VMs:"
echo "  - Running untrusted software"
echo "  - Testing different Linux distributions"
echo "  - Development sandbox environments"
echo "  - Security research and malware analysis"
echo "  - Reproducible build environments"
echo ""
echo "Commands:"
echo "  Start Ubuntu:   ubuntu (or ubuntu-kde)"
echo "  VM Status:      ~/ubuntu/scripts/pkvm-bridge.sh status"
echo "  Create VM:      ~/ubuntu/scripts/pkvm-bridge.sh create name 20G"
echo "  List VMs:       ~/ubuntu/scripts/pkvm-bridge.sh list"
echo "  Run VM:         ~/ubuntu/scripts/pkvm-bridge.sh run image.qcow2"
echo ""
echo "Performance Notes:"
echo "  - PRoot: Near-native speed, shares Android resources"
echo "  - QEMU:  Slower (emulation), but fully isolated"
echo "  - Use PRoot for daily tasks, QEMU for isolation"
echo ""
SCRIPTEOF

    chmod +x "${PKVM_DIR}/hybrid-controller.sh"
}

# ============================================================================
# QEMU LAUNCHER SCRIPT
# ============================================================================

create_qemu_launcher() {
    log_info "Creating run-qemu-vm.sh..."
    
    cat > "${PKVM_DIR}/run-qemu-vm.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# run-qemu-vm.sh - Run VM with QEMU
#
# Usage: run-qemu-vm.sh <image> [memory] [cpus]
#

set -euo pipefail

IMAGE="${1:-}"
MEMORY="${2:-2G}"
CPUS="${3:-2}"
PKVM_DIR="${HOME}/ubuntu/pkvm"
PKVM_IMAGES="${PKVM_DIR}/images"

if [[ -z "${IMAGE}" ]]; then
    echo "Usage: $(basename "$0") <disk-image> [memory] [cpus]"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") ubuntu.qcow2"
    echo "  $(basename "$0") ubuntu.qcow2 4G 4"
    echo ""
    echo "Available images:"
    ls -1 "${PKVM_IMAGES}"/*.qcow2 2>/dev/null || echo "  No images found"
    exit 1
fi

# Resolve image path
if [[ ! -f "${IMAGE}" ]]; then
    if [[ -f "${PKVM_IMAGES}/${IMAGE}" ]]; then
        IMAGE="${PKVM_IMAGES}/${IMAGE}"
    else
        echo "Error: Image not found: ${IMAGE}"
        exit 1
    fi
fi

# Check QEMU
if ! command -v qemu-system-aarch64 &>/dev/null; then
    echo "Error: QEMU not installed"
    echo "Install with: pkg install qemu-system-aarch64"
    exit 1
fi

echo "Starting QEMU VM..."
echo "  Image:  ${IMAGE}"
echo "  Memory: ${MEMORY}"
echo "  CPUs:   ${CPUS}"
echo ""
echo "Network:"
echo "  SSH: localhost:2222 -> VM:22"
echo "  VNC: localhost:5900 -> VM:5900"
echo ""
echo "Controls:"
echo "  Ctrl+A, X    Exit QEMU"
echo "  Ctrl+A, C    QEMU monitor"
echo ""

exec qemu-system-aarch64 \
    -M virt \
    -cpu max \
    -smp "${CPUS}" \
    -m "${MEMORY}" \
    -drive "file=${IMAGE},format=qcow2,if=virtio" \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::5900-:5900 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-gpu-pci \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -serial mon:stdio \
    -nographic
SCRIPTEOF

    chmod +x "${PKVM_DIR}/run-qemu-vm.sh"
}

# ============================================================================
# IMAGE CREATOR SCRIPT
# ============================================================================

create_image_creator() {
    log_info "Creating create-vm-image.sh..."
    
    cat > "${PKVM_DIR}/create-vm-image.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# create-vm-image.sh - Create a new VM disk image
#

set -euo pipefail

NAME="${1:-}"
SIZE="${2:-20G}"
PKVM_IMAGES="${HOME}/ubuntu/pkvm/images"

if [[ -z "${NAME}" ]]; then
    echo "Usage: $(basename "$0") <name> [size]"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") ubuntu 20G"
    echo "  $(basename "$0") alpine 8G"
    echo "  $(basename "$0") debian 15G"
    exit 1
fi

# Check for qemu-img
if ! command -v qemu-img &>/dev/null; then
    echo "Installing qemu-utils..."
    pkg install -y qemu-utils
fi

mkdir -p "${PKVM_IMAGES}"
OUTPUT="${PKVM_IMAGES}/${NAME}.qcow2"

if [[ -f "${OUTPUT}" ]]; then
    echo "Warning: Image already exists: ${OUTPUT}"
    read -p "Overwrite? [y/N] " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        echo "Cancelled"
        exit 1
    fi
fi

echo ""
echo "Creating VM image..."
echo "  Name: ${NAME}"
echo "  Size: ${SIZE}"
echo "  Path: ${OUTPUT}"
echo ""

qemu-img create -f qcow2 "${OUTPUT}" "${SIZE}"

echo ""
echo "Image created successfully!"
echo ""
echo "To use this image:"
echo "  ~/ubuntu/pkvm/run-qemu-vm.sh ${OUTPUT}"
echo ""
echo "Or with custom resources:"
echo "  ~/ubuntu/pkvm/run-qemu-vm.sh ${OUTPUT} 4G 4"
echo ""
SCRIPTEOF

    chmod +x "${PKVM_DIR}/create-vm-image.sh"
}

# ============================================================================
# DOCUMENTATION
# ============================================================================

create_pkvm_documentation() {
    log_section "Creating Documentation"
    
    cat > "${DOCS_DIR}/PKVM_GUIDE.md" << 'DOCEOF'
# pKVM / AVF Integration Guide

## Overview

This guide covers the hybrid virtualization setup:

- PRoot Ubuntu: Main desktop environment (fast, integrated)
- QEMU VMs: Isolated workloads (secure, sandboxed)

## Virtualization on Android

### Android Virtualization Framework (AVF)

Available on:
- Pixel 6 and newer with Android 13+
- Some other Android 13+ devices with manufacturer support

Features:
- Protected Virtual Machines (pVM)
- Hardware-backed isolation
- Secure enclave capabilities

### Checking Support

    ~/ubuntu/scripts/pkvm-bridge.sh status

Or manually:

    getprop ro.boot.hypervisor.vm.supported
    getprop ro.boot.hypervisor.protected_vm.supported

## QEMU Fallback

For devices without AVF or when root is unavailable, QEMU provides software virtualization.

### Setup QEMU

    ~/ubuntu/scripts/pkvm-bridge.sh qemu

Or manually:

    pkg install qemu-system-aarch64 qemu-utils

### Create VM Image

    ~/ubuntu/scripts/pkvm-bridge.sh create myvm 20G

Or:

    ~/ubuntu/pkvm/create-vm-image.sh myvm 20G

### List Images

    ~/ubuntu/scripts/pkvm-bridge.sh list

### Run VM

    ~/ubuntu/scripts/pkvm-bridge.sh run myvm.qcow2 4G 4

Arguments:
- Argument 1: Disk image path
- Argument 2: Memory (default: 2G)
- Argument 3: CPU cores (default: 2)

### VM Networking

Default port forwards:
- SSH: localhost:2222 -> VM:22
- VNC: localhost:5900 -> VM:5900

Connect via SSH:

    ssh -p 2222 user@localhost

## Hybrid Workflow

1. Use PRoot Ubuntu for daily tasks (fast, integrated)
2. Spin up QEMU VMs for:
   - Testing untrusted software
   - Different Linux distributions
   - Development sandboxes
   - Security research

## Installing an OS in QEMU

### Alpine Linux (lightweight)

1. Download Alpine:

    wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/alpine-virt-3.19.0-aarch64.iso

2. Create image and boot:

    pkvm-bridge.sh create alpine 8G
    qemu-system-aarch64 -M virt -cpu max -m 2G \
      -drive file=~/ubuntu/pkvm/images/alpine.qcow2,format=qcow2,if=virtio \
      -cdrom alpine-virt-3.19.0-aarch64.iso \
      -boot d -nographic

### Ubuntu Server

1. Download Ubuntu cloud image:

    wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64.img

2. Resize and run:

    qemu-img resize jammy-server-cloudimg-arm64.img 20G
    pkvm-bridge.sh run jammy-server-cloudimg-arm64.img 4G 2

## Performance Tips

- Allocate at least 2GB RAM to VMs
- Use 2-4 CPU cores for reasonable performance
- Use qcow2 format for disk images (sparse allocation)
- virtio drivers provide best I/O performance
- Consider -enable-kvm if /dev/kvm is available (root)

## Limitations

- QEMU is software emulation (slower than native)
- Full pKVM requires root access
- AVF is limited to system apps on most devices
- Memory is shared with Android system
- No GPU passthrough in QEMU

## QEMU Controls

While running a VM:
- Ctrl+A, X    Exit QEMU
- Ctrl+A, C    QEMU monitor console
- Ctrl+A, H    Help

## File Locations

    ~/ubuntu/pkvm/
    ├── images/              # VM disk images
    ├── config/              # VM configurations
    ├── shared/              # Shared folder with VMs
    ├── logs/                # VM logs
    ├── avf-info.sh          # AVF status script
    ├── hybrid-controller.sh # Hybrid mode info
    ├── run-qemu-vm.sh       # QEMU launcher
    └── create-vm-image.sh   # Image creator

    ~/ubuntu/scripts/
    └── pkvm-bridge.sh       # Main bridge controller

## Troubleshooting

### QEMU not starting

Check installation:

    pkg install qemu-system-aarch64 qemu-utils

### VM runs slowly

- Increase memory: -m 4G
- Reduce resolution in guest OS
- Use lightweight distro (Alpine)

### Network not working

Check port forwards:

    netstat -tlnp | grep 2222

### Disk full

Check available space:

    df -h ~/ubuntu/pkvm/images/

---

Documentation version: 1.0.0
DOCEOF

    log_success "Documentation created: ${DOCS_DIR}/PKVM_GUIDE.md"
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    log_section "Verifying Installation"
    
    local total=0
    local passed=0
    
    check_item() {
        local name="$1"
        local path="$2"
        ((total++))
        
        if [[ -x "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        elif [[ -f "${path}" ]] || [[ -d "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} %s\n" "${name}"
        fi
    }
    
    echo ""
    echo "Directories:"
    echo "────────────"
    check_item "pkvm/" "${PKVM_DIR}"
    check_item "pkvm/images/" "${PKVM_IMAGES}"
    check_item "pkvm/config/" "${PKVM_CONFIG}"
    check_item "pkvm/shared/" "${PKVM_SHARED}"
    check_item "pkvm/logs/" "${PKVM_LOGS}"
    
    echo ""
    echo "Scripts:"
    echo "────────"
    check_item "pkvm-bridge.sh" "${UBUNTU_PROJECT_ROOT}/scripts/pkvm-bridge.sh"
    check_item "avf-info.sh" "${PKVM_DIR}/avf-info.sh"
    check_item "hybrid-controller.sh" "${PKVM_DIR}/hybrid-controller.sh"
    check_item "run-qemu-vm.sh" "${PKVM_DIR}/run-qemu-vm.sh"
    check_item "create-vm-image.sh" "${PKVM_DIR}/create-vm-image.sh"
    
    echo ""
    echo "Documentation:"
    echo "──────────────"
    check_item "PKVM_GUIDE.md" "${DOCS_DIR}/PKVM_GUIDE.md"
    
    echo ""
    echo "Optional Dependencies:"
    echo "──────────────────────"
    ((total++))
    if command -v qemu-system-aarch64 &>/dev/null; then
        printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} qemu-system-aarch64\n"
        ((passed++))
    else
        printf "  ${COLOR_YELLOW:-}○${COLOR_RESET:-} qemu-system-aarch64 (install with: pkg install qemu-system-aarch64)\n"
        ((passed++))  # Optional, so count as passed
    fi
    
    ((total++))
    if command -v qemu-img &>/dev/null; then
        printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} qemu-img\n"
        ((passed++))
    else
        printf "  ${COLOR_YELLOW:-}○${COLOR_RESET:-} qemu-img (install with: pkg install qemu-utils)\n"
        ((passed++))  # Optional
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  Results: ${passed}/${total} passed"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    return 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  pKVM/AVF Integration Setup v${SCRIPT_VERSION}"
    echo "  Ubuntu 26.04 Resolute on Termux"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Check device info
    check_device_info
    
    # Check pKVM support
    check_pkvm_support || true  # Continue even if limited support
    
    # Setup directories
    setup_pkvm_directories
    
    # Create scripts
    log_section "Creating pKVM Scripts"
    create_pkvm_bridge
    create_avf_info
    log_info "  Created: avf-info.sh"
    create_hybrid_controller
    log_info "  Created: hybrid-controller.sh"
    create_qemu_launcher
    log_info "  Created: run-qemu-vm.sh"
    create_image_creator
    log_info "  Created: create-vm-image.sh"
    log_success "pKVM scripts complete"
    
    # Create documentation
    create_pkvm_documentation
    
    # Verify installation
    verify_installation
    
    # Print summary
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Installation Complete"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Bridge Controller: ~/ubuntu/scripts/pkvm-bridge.sh"
    echo "  VM Images:         ~/ubuntu/pkvm/images/"
    echo "  Documentation:     ~/ubuntu/docs/PKVM_GUIDE.md"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Quick Start"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  1. Check virtualization status:"
    echo "     ${COLOR_CYAN:-}~/ubuntu/scripts/pkvm-bridge.sh status${COLOR_RESET:-}"
    echo ""
    echo "  2. Setup QEMU (if needed):"
    echo "     ${COLOR_CYAN:-}~/ubuntu/scripts/pkvm-bridge.sh qemu${COLOR_RESET:-}"
    echo ""
    echo "  3. Create a VM image:"
    echo "     ${COLOR_CYAN:-}~/ubuntu/scripts/pkvm-bridge.sh create myvm 20G${COLOR_RESET:-}"
    echo ""
    echo "  4. Run a VM:"
    echo "     ${COLOR_CYAN:-}~/ubuntu/scripts/pkvm-bridge.sh run myvm.qcow2${COLOR_RESET:-}"
    echo ""
    echo "  5. Read documentation:"
    echo "     ${COLOR_CYAN:-}less ~/ubuntu/docs/PKVM_GUIDE.md${COLOR_RESET:-}"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Next Step"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "  ${COLOR_CYAN:-}bash ~/ubuntu/scripts/99-finalize.sh${COLOR_RESET:-}"
    echo ""
    
    return 0
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

main "$@"
