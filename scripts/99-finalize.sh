#!/data/data/com.termux/files/usr/bin/bash
#
# 99-finalize.sh
# Final Setup and System Verification
#
# Completes the Ubuntu on Termux installation:
# - Verifies all components
# - Creates final convenience scripts
# - Generates system report
# - Sets up bash integration
# - Creates uninstaller
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

SCRIPT_NAME="Final Setup"
SCRIPT_VERSION="1.0.0"

DOCS_DIR="${UBUNTU_PROJECT_ROOT}/docs"
CONFIG_DIR="${UBUNTU_PROJECT_ROOT}/config"
LOGS_DIR="${UBUNTU_PROJECT_ROOT}/logs"
BIN_DIR="${UBUNTU_PROJECT_ROOT}/bin"

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

setup_directories() {
    log_section "Finalizing Directories"
    
    ensure_dir "${DOCS_DIR}"
    ensure_dir "${CONFIG_DIR}"
    ensure_dir "${LOGS_DIR}"
    ensure_dir "${BIN_DIR}"
    
    log_success "Directories verified"
}

# ============================================================================
# QUICK LAUNCH SCRIPTS
# ============================================================================

create_quick_launchers() {
    log_section "Creating Quick Launch Scripts"
    
    # ubuntu command
    cat > "${BIN_DIR}/ubuntu" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --shell "$@"
SCRIPTEOF
    chmod +x "${BIN_DIR}/ubuntu"
    log_info "  Created: ubuntu"
    
    # ubuntu-kde command
    cat > "${BIN_DIR}/ubuntu-kde" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --kde "$@"
SCRIPTEOF
    chmod +x "${BIN_DIR}/ubuntu-kde"
    log_info "  Created: ubuntu-kde"
    
    # ubuntu-xfce command
    cat > "${BIN_DIR}/ubuntu-xfce" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
exec "${HOME}/ubuntu/scripts/launch-ubuntu.sh" --xfce "$@"
SCRIPTEOF
    chmod +x "${BIN_DIR}/ubuntu-xfce"
    log_info "  Created: ubuntu-xfce"
    
    # ubuntu-status command
    cat > "${BIN_DIR}/ubuntu-status" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "Ubuntu on Termux - Status"
echo "=========================="
echo ""

# Mode
MODE_FILE="${HOME}/ubuntu/logs/tasker/.current_mode"
if [[ -f "${MODE_FILE}" ]]; then
    echo "Display Mode: $(cat "${MODE_FILE}")"
else
    echo "Display Mode: not set"
fi

# VNC
if pgrep -f "Xvnc" &>/dev/null; then
    echo "VNC Server:   Running"
    IP=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "localhost")
    echo "VNC Address:  ${IP}:5901"
else
    echo "VNC Server:   Stopped"
fi

# PulseAudio
if pgrep -x pulseaudio &>/dev/null; then
    echo "Audio:        Running"
else
    echo "Audio:        Stopped"
fi

# PRoot
if pgrep -f "proot.*ubuntu" &>/dev/null; then
    echo "PRoot:        Running"
else
    echo "PRoot:        Stopped"
fi

# Disk usage
echo ""
echo "Disk Usage:"
du -sh "${HOME}/ubuntu" 2>/dev/null || echo "  Unable to determine"
echo ""
SCRIPTEOF
    chmod +x "${BIN_DIR}/ubuntu-status"
    log_info "  Created: ubuntu-status"
    
    # ubuntu-help command
    cat > "${BIN_DIR}/ubuntu-help" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
cat << 'HELPEOF'

Ubuntu on Termux - Quick Reference
===================================

BASIC COMMANDS
  ubuntu              Start Ubuntu shell
  ubuntu-kde          Start KDE Plasma desktop
  ubuntu-xfce         Start XFCE desktop
  ubuntu-status       Show system status
  ubuntu-help         Show this help

MODE SWITCHING
  mode-docked         Switch to docked mode (2560x1440)
  mode-tv             Switch to TV mode (1920x1080)
  mode-portable       Switch to portable mode (1280x720)
  mode-toggle         Cycle through modes
  mode-get            Show current mode

VNC CONTROL
  vnc-start           Start VNC server
  vnc-stop            Stop VNC server
  vnc-status          Check VNC status

SERVICE CONTROL
  ubuntu-stop         Stop all Ubuntu services
  ubuntu-update       Update Ubuntu packages

PKVM / VIRTUALIZATION
  ~/ubuntu/scripts/pkvm-bridge.sh status    Check VM support
  ~/ubuntu/scripts/pkvm-bridge.sh qemu      Setup QEMU
  ~/ubuntu/scripts/pkvm-bridge.sh create    Create VM image
  ~/ubuntu/scripts/pkvm-bridge.sh run       Run VM

DOCUMENTATION
  ~/ubuntu/docs/README.md           Main documentation
  ~/ubuntu/docs/TASKER_SETUP.md     Tasker integration guide
  ~/ubuntu/docs/PKVM_GUIDE.md       Virtualization guide

DIRECTORIES
  ~/ubuntu/                         Project root
  ~/ubuntu/scripts/                 All scripts
  ~/ubuntu/rootfs/                  Ubuntu filesystem
  ~/ubuntu/pkvm/images/             VM images
  ~/ubuntu/logs/                    Log files
  ~/ubuntu/docs/                    Documentation

CONFIGURATION
  ~/ubuntu/config/                  Configuration files
  ~/.termux/tasker/                 Tasker scripts
  ~/.shortcuts/                     Widget scripts

TROUBLESHOOTING
  Check logs:     tail -f ~/ubuntu/logs/*.log
  VNC issues:     vncserver -kill :1 && vnc-start
  Reset mode:     rm ~/ubuntu/logs/tasker/.current_mode

For detailed help, see: ~/ubuntu/docs/

HELPEOF
SCRIPTEOF
    chmod +x "${BIN_DIR}/ubuntu-help"
    log_info "  Created: ubuntu-help"
    
    log_success "Quick launch scripts created"
}

# ============================================================================
# BASH INTEGRATION
# ============================================================================

setup_bash_integration() {
    log_section "Setting Up Bash Integration"
    
    local bashrc="${HOME}/.bashrc"
    local marker="# Ubuntu on Termux Integration"
    
    # Check if already integrated
    if grep -q "${marker}" "${bashrc}" 2>/dev/null; then
        log_info "Bash integration already present"
        return 0
    fi
    
    # Add integration
    cat >> "${bashrc}" << 'BASHEOF'

# Ubuntu on Termux Integration
export UBUNTU_HOME="${HOME}/ubuntu"
export PATH="${UBUNTU_HOME}/bin:${PATH}"

# Quick aliases
alias ubuntu='${UBUNTU_HOME}/bin/ubuntu'
alias ubuntu-kde='${UBUNTU_HOME}/bin/ubuntu-kde'
alias ubuntu-xfce='${UBUNTU_HOME}/bin/ubuntu-xfce'
alias ubuntu-status='${UBUNTU_HOME}/bin/ubuntu-status'
alias ubuntu-help='${UBUNTU_HOME}/bin/ubuntu-help'
alias ubuntu-stop='~/.termux/tasker/stop-ubuntu.sh'
alias ubuntu-update='~/.termux/tasker/update-ubuntu.sh'

# Startup message
if [[ -d "${UBUNTU_HOME}" ]]; then
    echo ""
    echo "Ubuntu on Termux ready. Type 'ubuntu-help' for commands."
fi
BASHEOF
    
    log_success "Bash integration added to .bashrc"
}

# ============================================================================
# UNINSTALLER
# ============================================================================

create_uninstaller() {
    log_section "Creating Uninstaller"
    
    cat > "${UBUNTU_PROJECT_ROOT}/uninstall.sh" << 'SCRIPTEOF'
#!/data/data/com.termux/files/usr/bin/bash
#
# uninstall.sh - Remove Ubuntu on Termux
#

set -euo pipefail

UBUNTU_HOME="${HOME}/ubuntu"

echo ""
echo "╔═══════════════���══════════════════════════════════════════════╗"
echo "║           Ubuntu on Termux - Uninstaller                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "This will remove:"
echo "  - Ubuntu rootfs and all data in ~/ubuntu/"
echo "  - Tasker scripts in ~/.termux/tasker/"
echo "  - Widget scripts in ~/.shortcuts/"
echo "  - Bash integration in ~/.bashrc"
echo ""

read -p "Are you sure you want to uninstall? [y/N] " confirm
if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "Stopping services..."
pkill -f "proot.*ubuntu" 2>/dev/null || true
vncserver -kill :1 2>/dev/null || true
pkill -f "Xvnc" 2>/dev/null || true

echo "Removing Tasker scripts..."
rm -f ~/.termux/tasker/docked-mode.sh
rm -f ~/.termux/tasker/tv-mode.sh
rm -f ~/.termux/tasker/portable-mode.sh
rm -f ~/.termux/tasker/start-ubuntu.sh
rm -f ~/.termux/tasker/start-ubuntu-kde.sh
rm -f ~/.termux/tasker/stop-ubuntu.sh
rm -f ~/.termux/tasker/update-ubuntu.sh
rm -f ~/.termux/tasker/status-ubuntu.sh
rm -f ~/.termux/tasker/wifi-connected.sh
rm -f ~/.termux/tasker/usb-connected.sh
rm -f ~/.termux/tasker/usb-disconnected.sh
rm -f ~/.termux/tasker/boot-complete.sh
rm -f ~/.termux/tasker/battery-low.sh
rm -f ~/.termux/tasker/charging.sh
rm -f ~/.termux/tasker/screen-off.sh
rm -f ~/.termux/tasker/screen-on.sh
rm -f ~/.termux/tasker/toggle-mode.sh
rm -f ~/.termux/tasker/set-mode.sh
rm -f ~/.termux/tasker/get-mode.sh
rm -f ~/.termux/tasker/ubuntu-notify.sh
rm -f ~/.termux/tasker/vnc-start.sh
rm -f ~/.termux/tasker/vnc-stop.sh
rm -f ~/.termux/tasker/vnc-status.sh
rm -f ~/.termux/tasker/audio-start.sh
rm -f ~/.termux/tasker/audio-stop.sh
rm -f ~/.termux/tasker/autostart-enable.sh
rm -f ~/.termux/tasker/autostart-disable.sh

echo "Removing widget scripts..."
rm -f ~/.shortcuts/"🐧 Ubuntu Shell"
rm -f ~/.shortcuts/"🖥️ Ubuntu KDE"
rm -f ~/.shortcuts/"📺 Cast to TV"
rm -f ~/.shortcuts/"⏹️ Stop Ubuntu"
rm -f ~/.shortcuts/"ℹ️ Ubuntu Status"
rm -f ~/.shortcuts/"🔄 Update Ubuntu"
rm -f ~/.shortcuts/"🔌 Docked Mode"
rm -f ~/.shortcuts/"🔋 Portable Mode"
rm -f ~/.shortcuts/"🔄 Toggle Mode"
rm -f ~/.shortcuts/"▶️ Start VNC"
rm -f ~/.shortcuts/"⏹️ Stop VNC"

echo "Removing bash integration..."
if [[ -f ~/.bashrc ]]; then
    sed -i '/# Ubuntu on Termux Integration/,/^fi$/d' ~/.bashrc 2>/dev/null || true
    sed -i '/# Tasker Automation Aliases/,/^fi$/d' ~/.bashrc 2>/dev/null || true
fi

echo "Removing Ubuntu directory..."
read -p "Remove all Ubuntu data including rootfs? [y/N] " confirm_data
if [[ "${confirm_data}" == "y" || "${confirm_data}" == "Y" ]]; then
    rm -rf "${UBUNTU_HOME}"
    echo "Ubuntu directory removed"
else
    echo "Ubuntu directory preserved at ${UBUNTU_HOME}"
fi

echo ""
echo "Uninstallation complete!"
echo ""
echo "You may also want to remove these packages:"
echo "  pkg uninstall proot proot-distro tigervnc pulseaudio"
echo ""
SCRIPTEOF

    chmod +x "${UBUNTU_PROJECT_ROOT}/uninstall.sh"
    log_success "Created: uninstall.sh"
}

# ============================================================================
# SYSTEM REPORT
# ============================================================================

generate_system_report() {
    log_section "Generating System Report"
    
    local report_file="${LOGS_DIR}/system-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Ubuntu on Termux - System Report"
        echo "================================="
        echo "Generated: $(date)"
        echo ""
        
        echo "== Device Information =="
        echo "Model: $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
        echo "Device: $(getprop ro.product.device 2>/dev/null || echo 'Unknown')"
        echo "Android: $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
        echo "SDK: $(getprop ro.build.version.sdk 2>/dev/null || echo 'Unknown')"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo ""
        
        echo "== Storage =="
        df -h "${HOME}" 2>/dev/null || echo "Unable to determine"
        echo ""
        du -sh "${UBUNTU_PROJECT_ROOT}" 2>/dev/null || echo "Unable to determine"
        echo ""
        
        echo "== Memory =="
        free -h 2>/dev/null || cat /proc/meminfo | head -5
        echo ""
        
        echo "== Virtualization =="
        echo "AVF: $(getprop ro.boot.hypervisor.vm.supported 2>/dev/null || echo 'not set')"
        echo "pVM: $(getprop ro.boot.hypervisor.protected_vm.supported 2>/dev/null || echo 'not set')"
        echo "KVM: $(test -c /dev/kvm && echo 'available' || echo 'not accessible')"
        echo ""
        
        echo "== Installed Components =="
        echo "Scripts:"
        ls -1 "${UBUNTU_PROJECT_ROOT}/scripts/"*.sh 2>/dev/null | wc -l | xargs echo "  Count:"
        echo ""
        echo "Tasker Scripts:"
        ls -1 ~/.termux/tasker/*.sh 2>/dev/null | wc -l | xargs echo "  Count:"
        echo ""
        echo "Widgets:"
        ls -1 ~/.shortcuts/ 2>/dev/null | wc -l | xargs echo "  Count:"
        echo ""
        
        echo "== Dependencies =="
        for cmd in proot vncserver pulseaudio qemu-system-aarch64; do
            if command -v "${cmd}" &>/dev/null; then
                echo "  ${cmd}: installed"
            else
                echo "  ${cmd}: not installed"
            fi
        done
        echo ""
        
        echo "== End of Report =="
    } > "${report_file}"
    
    log_success "Report saved: ${report_file}"
}

# ============================================================================
# MAIN README
# ============================================================================

create_main_readme() {
    log_section "Creating Main README"
    
    cat > "${DOCS_DIR}/README.md" << 'DOCEOF'
# Ubuntu on Termux

Full Ubuntu 26.04 LTS (Resolute) desktop environment running on Android via Termux.

## Quick Start

    ubuntu              # Start Ubuntu shell
    ubuntu-kde          # Start KDE Plasma desktop
    ubuntu-help         # Show all commands

## Features

- Full Ubuntu 26.04 LTS userspace
- KDE Plasma and XFCE desktop options
- VNC server with automatic mode switching
- Tasker automation integration
- QEMU virtualization support
- Home screen widgets

## Commands

### Basic

| Command | Description |
|---------|-------------|
| ubuntu | Start Ubuntu shell |
| ubuntu-kde | Start KDE desktop |
| ubuntu-xfce | Start XFCE desktop |
| ubuntu-status | Show system status |
| ubuntu-stop | Stop all services |
| ubuntu-help | Show help |

### Display Modes

| Command | Resolution | Use Case |
|---------|------------|----------|
| mode-docked | 2560x1440 | External monitor |
| mode-tv | 1920x1080 | Chromecast/TV |
| mode-portable | 1280x720 | Battery saving |
| mode-toggle | Cycle | Switch modes |

### VNC Control

| Command | Description |
|---------|-------------|
| vnc-start | Start VNC server |
| vnc-stop | Stop VNC server |
| vnc-status | Check VNC status |

## Connecting

1. Start Ubuntu with desired desktop
2. Note the VNC address shown
3. Connect with any VNC viewer app
4. Default VNC port: 5901

## Tasker Automation

Automatic mode switching based on:
- USB connection (docked mode)
- WiFi network (TV mode)
- Battery level (portable mode)

See: ~/ubuntu/docs/TASKER_SETUP.md

## Virtualization

For isolated workloads using QEMU:

    ~/ubuntu/scripts/pkvm-bridge.sh status
    ~/ubuntu/scripts/pkvm-bridge.sh qemu
    ~/ubuntu/scripts/pkvm-bridge.sh create myvm 20G
    ~/ubuntu/scripts/pkvm-bridge.sh run myvm.qcow2

See: ~/ubuntu/docs/PKVM_GUIDE.md

## Directory Structure

    ~/ubuntu/
    ├── bin/                 Quick launch scripts
    ├── config/              Configuration files
    ├── docs/                Documentation
    ├── lib/                 Shared libraries
    ├── logs/                Log files
    ├── pkvm/                Virtualization
    │   └── images/          VM disk images
    ├── rootfs/              Ubuntu filesystem
    └── scripts/             All scripts

## Widgets

Add home screen widgets via Termux:Widget app:
- Ubuntu Shell
- Ubuntu KDE
- Cast to TV
- Stop Ubuntu
- Ubuntu Status
- Mode switching widgets

## Troubleshooting

### VNC not connecting

    vncserver -kill :1
    vnc-start

### Services not stopping

    pkill -9 -f proot
    pkill -9 -f Xvnc

### Check logs

    tail -f ~/ubuntu/logs/*.log
    tail -f ~/ubuntu/logs/tasker/*.log

### Reset display mode

    rm ~/ubuntu/logs/tasker/.current_mode

## Uninstall

    ~/ubuntu/uninstall.sh

## Documentation

- README.md - This file
- TASKER_SETUP.md - Tasker integration guide
- PKVM_GUIDE.md - Virtualization guide

## Version

Ubuntu 26.04 LTS (Resolute) on Termux
Project version: 1.0.0
DOCEOF

    log_success "Created: README.md"
}

# ============================================================================
# COMPREHENSIVE VERIFICATION
# ============================================================================

comprehensive_verification() {
    log_section "Comprehensive System Verification"
    
    local total=0
    local passed=0
    local warnings=0
    
    check_dir() {
        local name="$1"
        local path="$2"
        ((total++))
        if [[ -d "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} %s\n" "${name}"
        fi
    }
    
    check_file() {
        local name="$1"
        local path="$2"
        ((total++))
        if [[ -f "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} %s\n" "${name}"
        fi
    }
    
    check_exec() {
        local name="$1"
        local path="$2"
        ((total++))
        if [[ -x "${path}" ]]; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        elif [[ -f "${path}" ]]; then
            chmod +x "${path}" 2>/dev/null
            printf "  ${COLOR_YELLOW:-}⚡${COLOR_RESET:-} %s (fixed)\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} %s\n" "${name}"
        fi
    }
    
    check_cmd() {
        local name="$1"
        local cmd="$2"
        ((total++))
        if command -v "${cmd}" &>/dev/null; then
            printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %s\n" "${name}"
            ((passed++))
        else
            printf "  ${COLOR_YELLOW:-}○${COLOR_RESET:-} %s (optional)\n" "${name}"
            ((warnings++))
            ((passed++))
        fi
    }
    
    # Core Directories
    echo ""
    echo "Core Directories:"
    echo "─────────────────"
    check_dir "ubuntu/" "${UBUNTU_PROJECT_ROOT}"
    check_dir "ubuntu/bin/" "${BIN_DIR}"
    check_dir "ubuntu/config/" "${CONFIG_DIR}"
    check_dir "ubuntu/docs/" "${DOCS_DIR}"
    check_dir "ubuntu/lib/" "${UBUNTU_PROJECT_ROOT}/lib"
    check_dir "ubuntu/logs/" "${LOGS_DIR}"
    check_dir "ubuntu/scripts/" "${UBUNTU_PROJECT_ROOT}/scripts"
    check_dir "ubuntu/rootfs/" "${UBUNTU_PROJECT_ROOT}/rootfs"
    check_dir "ubuntu/pkvm/" "${UBUNTU_PROJECT_ROOT}/pkvm"
    check_dir "ubuntu/pkvm/images/" "${UBUNTU_PROJECT_ROOT}/pkvm/images"
    
    # Core Scripts
    echo ""
    echo "Core Scripts:"
    echo "─────────────"
    check_exec "launch-ubuntu.sh" "${UBUNTU_PROJECT_ROOT}/scripts/launch-ubuntu.sh"
    check_exec "pkvm-bridge.sh" "${UBUNTU_PROJECT_ROOT}/scripts/pkvm-bridge.sh"
    
    # Quick Launch Commands
    echo ""
    echo "Quick Launch Commands:"
    echo "──────────────────────"
    check_exec "ubuntu" "${BIN_DIR}/ubuntu"
    check_exec "ubuntu-kde" "${BIN_DIR}/ubuntu-kde"
    check_exec "ubuntu-xfce" "${BIN_DIR}/ubuntu-xfce"
    check_exec "ubuntu-status" "${BIN_DIR}/ubuntu-status"
    check_exec "ubuntu-help" "${BIN_DIR}/ubuntu-help"
    
    # Tasker Scripts (count)
    echo ""
    echo "Tasker Scripts:"
    echo "───────────────"
    local tasker_count=$(ls -1 ~/.termux/tasker/*.sh 2>/dev/null | wc -l)
    ((total++))
    if [[ ${tasker_count} -ge 27 ]]; then
        printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %d scripts installed\n" "${tasker_count}"
        ((passed++))
    elif [[ ${tasker_count} -gt 0 ]]; then
        printf "  ${COLOR_YELLOW:-}⚠${COLOR_RESET:-} %d scripts (expected 27)\n" "${tasker_count}"
        ((passed++))
        ((warnings++))
    else
        printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} No tasker scripts found\n"
    fi
    
    # Widgets (count)
    echo ""
    echo "Widget Scripts:"
    echo "───────────────"
    local widget_count=$(ls -1 ~/.shortcuts/ 2>/dev/null | wc -l)
    ((total++))
    if [[ ${widget_count} -ge 11 ]]; then
        printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} %d widgets installed\n" "${widget_count}"
        ((passed++))
    elif [[ ${widget_count} -gt 0 ]]; then
        printf "  ${COLOR_YELLOW:-}⚠${COLOR_RESET:-} %d widgets (expected 11)\n" "${widget_count}"
        ((passed++))
        ((warnings++))
    else
        printf "  ${COLOR_RED:-}✗${COLOR_RESET:-} No widgets found\n"
    fi
    
    # Documentation
    echo ""
    echo "Documentation:"
    echo "──────────────"
    check_file "README.md" "${DOCS_DIR}/README.md"
    check_file "TASKER_SETUP.md" "${DOCS_DIR}/TASKER_SETUP.md"
    check_file "PKVM_GUIDE.md" "${DOCS_DIR}/PKVM_GUIDE.md"
    
    # Configuration
    echo ""
    echo "Configuration:"
    echo "──────────────"
    check_file "tasker-aliases.sh" "${CONFIG_DIR}/tasker-aliases.sh"
    check_file ".auto_start" "${CONFIG_DIR}/.auto_start"
    check_file "uninstall.sh" "${UBUNTU_PROJECT_ROOT}/uninstall.sh"
    
    # Bash Integration
    echo ""
    echo "Bash Integration:"
    echo "─────────────────"
    ((total++))
    if grep -q "Ubuntu on Termux Integration" "${HOME}/.bashrc" 2>/dev/null; then
        printf "  ${COLOR_GREEN:-}✓${COLOR_RESET:-} .bashrc integration\n"
        ((passed++))
    else
        printf "  ${COLOR_YELLOW:-}○${COLOR_RESET:-} .bashrc integration (run: source ~/.bashrc)\n"
        ((warnings++))
        ((passed++))
    fi
    
    # Dependencies
    echo ""
    echo "Dependencies:"
    echo "─────────────"
    check_cmd "proot" "proot"
    check_cmd "vncserver" "vncserver"
    check_cmd "pulseaudio" "pulseaudio"
    check_cmd "qemu-system-aarch64" "qemu-system-aarch64"
    check_cmd "termux-notification" "termux-notification"
    
    # Summary
    local failed=$((total - passed))
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    printf "  Passed: ${COLOR_GREEN:-}%d${COLOR_RESET:-}" "${passed}"
    if [[ ${warnings} -gt 0 ]]; then
        printf " | Warnings: ${COLOR_YELLOW:-}%d${COLOR_RESET:-}" "${warnings}"
    fi
    if [[ ${failed} -gt 0 ]]; then
        printf " | Failed: ${COLOR_RED:-}%d${COLOR_RESET:-}" "${failed}"
    fi
    printf " | Total: %d\n" "${total}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    if [[ ${failed} -eq 0 ]]; then
        echo "  ${COLOR_GREEN:-}✓ INSTALLATION COMPLETE${COLOR_RESET:-}"
        return 0
    else
        echo "  ${COLOR_YELLOW:-}⚠ INSTALLATION INCOMPLETE${COLOR_RESET:-}"
        return 1
    fi
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

print_final_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     ${COLOR_GREEN:-}Ubuntu on Termux - Installation Complete!${COLOR_RESET:-}                   ║"
    echo "║                                                                  ║"
    echo "║     Ubuntu 26.04 LTS (Resolute)                                  ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  ${COLOR_BOLD:-}What was installed:${COLOR_RESET:-}"
    echo "  ─────────────────────────────────────────────────────────────────"
    echo "  • Ubuntu 26.04 LTS rootfs with KDE Plasma and XFCE"
    echo "  • 27 Tasker automation scripts"
    echo "  • 11 Home screen widgets"
    echo "  • pKVM/QEMU virtualization support"
    echo "  • VNC server with automatic mode switching"
    echo "  • Complete documentation"
    echo ""
    echo "  ${COLOR_BOLD:-}Quick Start:${COLOR_RESET:-}"
    echo "  ─────────────────────────────────────────────────────────────────"
    echo ""
    echo "  1. Reload your shell:"
    echo "     ${COLOR_CYAN:-}source ~/.bashrc${COLOR_RESET:-}"
    echo ""
    echo "  2. Start Ubuntu shell:"
    echo "     ${COLOR_CYAN:-}ubuntu${COLOR_RESET:-}"
    echo ""
    echo "  3. Or start KDE desktop:"
    echo "     ${COLOR_CYAN:-}ubuntu-kde${COLOR_RESET:-}"
    echo ""
    echo "  4. Connect with VNC viewer to the address shown"
    echo ""
    echo "  ${COLOR_BOLD:-}Get Help:${COLOR_RESET:-}"
    echo "  ─────────────────────────────────────────────────────────────────"
    echo "     ${COLOR_CYAN:-}ubuntu-help${COLOR_RESET:-}"
    echo ""
    echo "  ${COLOR_BOLD:-}Documentation:${COLOR_RESET:-}"
    echo "  ─────────────────────────────────────────────────────────────────"
    echo "     ${COLOR_CYAN:-}~/ubuntu/docs/README.md${COLOR_RESET:-}"
    echo "     ${COLOR_CYAN:-}~/ubuntu/docs/TASKER_SETUP.md${COLOR_RESET:-}"
    echo "     ${COLOR_CYAN:-}~/ubuntu/docs/PKVM_GUIDE.md${COLOR_RESET:-}"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Enjoy your Ubuntu desktop on Android!"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Final Setup v${SCRIPT_VERSION}"
    echo "  Ubuntu 26.04 Resolute on Termux"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Setup directories
    setup_directories
    
    # Create quick launchers
    create_quick_launchers
    
    # Setup bash integration
    setup_bash_integration
    
    # Create uninstaller
    create_uninstaller
    
    # Create main readme
    create_main_readme
    
    # Generate system report
    generate_system_report
    
    # Comprehensive verification
    comprehensive_verification
    
    # Print final summary
    print_final_summary
    
    return 0
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

main "$@"
