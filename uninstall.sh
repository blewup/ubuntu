#!/data/data/com.termux/files/usr/bin/bash
#
# uninstall.sh - Complete Ubuntu on Termux Uninstaller
#
# Removes all components:
# - Ubuntu rootfs and project files
# - Tasker automation scripts
# - Home screen widgets
# - Bash integration
# - pKVM/QEMU images (optional)
#
# Version: 1.0.0
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

UBUNTU_HOME="${HOME}/ubuntu"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                                                                  ${RED}║${NC}"
    echo -e "${RED}║${NC}   ${BOLD}Ubuntu on Termux - Uninstaller${NC}                                 ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                                  ${RED}║${NC}"
    echo -e "${RED}║${NC}   ${DIM}This will remove Ubuntu and all related components${NC}             ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                                  ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_info() {
    echo -e "  ${CYAN}ℹ${NC}  $*"
}

log_success() {
    echo -e "  ${GREEN}✓${NC}  $*"
}

log_warn() {
    echo -e "  ${YELLOW}⚠${NC}  $*"
}

log_error() {
    echo -e "  ${RED}✗${NC}  $*"
}

confirm() {
    local prompt="${1:-Are you sure?}"
    echo ""
    read -p "  ${prompt} [y/N] " response
    [[ "${response}" == "y" || "${response}" == "Y" ]]
}

# ============================================================================
# STOP SERVICES
# ============================================================================

stop_services() {
    echo ""
    echo -e "  ${BOLD}Stopping Services${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Stop PRoot processes
    if pgrep -f "proot.*ubuntu" &>/dev/null; then
        log_info "Stopping PRoot processes..."
        pkill -f "proot.*ubuntu" 2>/dev/null || true
        sleep 1
        pkill -9 -f "proot.*ubuntu" 2>/dev/null || true
        log_success "PRoot stopped"
    else
        log_info "PRoot not running"
    fi
    
    # Stop VNC
    if pgrep -f "Xvnc" &>/dev/null; then
        log_info "Stopping VNC server..."
        vncserver -kill :1 2>/dev/null || true
        pkill -f "Xvnc" 2>/dev/null || true
        log_success "VNC stopped"
    else
        log_info "VNC not running"
    fi
    
    # Stop PulseAudio (optional - might be used by other apps)
    if pgrep -x pulseaudio &>/dev/null; then
        log_info "PulseAudio is running (not stopping - may be used by other apps)"
    fi
    
    # Clean up VNC lock files
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
}

# ============================================================================
# REMOVE TASKER SCRIPTS
# ============================================================================

remove_tasker_scripts() {
    echo ""
    echo -e "  ${BOLD}Removing Tasker Scripts${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    local tasker_dir="${HOME}/.termux/tasker"
    local count=0
    
    if [[ -d "${tasker_dir}" ]]; then
        # List of scripts to remove
        local scripts=(
            "docked-mode.sh"
            "tv-mode.sh"
            "portable-mode.sh"
            "start-ubuntu.sh"
            "start-ubuntu-kde.sh"
            "stop-ubuntu.sh"
            "update-ubuntu.sh"
            "status-ubuntu.sh"
            "wifi-connected.sh"
            "usb-connected.sh"
            "usb-disconnected.sh"
            "boot-complete.sh"
            "battery-low.sh"
            "charging.sh"
            "screen-off.sh"
            "screen-on.sh"
            "toggle-mode.sh"
            "set-mode.sh"
            "get-mode.sh"
            "ubuntu-notify.sh"
            "vnc-start.sh"
            "vnc-stop.sh"
            "vnc-status.sh"
            "audio-start.sh"
            "audio-stop.sh"
            "autostart-enable.sh"
            "autostart-disable.sh"
        )
        
        for script in "${scripts[@]}"; do
            if [[ -f "${tasker_dir}/${script}" ]]; then
                rm -f "${tasker_dir}/${script}"
                ((count++))
            fi
        done
        
        if [[ ${count} -gt 0 ]]; then
            log_success "Removed ${count} Tasker scripts"
        else
            log_info "No Tasker scripts found"
        fi
    else
        log_info "Tasker directory not found"
    fi
}

# ============================================================================
# REMOVE WIDGETS
# ============================================================================

remove_widgets() {
    echo ""
    echo -e "  ${BOLD}Removing Widget Scripts${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    local shortcuts_dir="${HOME}/.shortcuts"
    local count=0
    
    if [[ -d "${shortcuts_dir}" ]]; then
        # List of widgets to remove
        local widgets=(
            "🐧 Ubuntu Shell"
            "🖥️ Ubuntu KDE"
            "📺 Cast to TV"
            "⏹️ Stop Ubuntu"
            "ℹ️ Ubuntu Status"
            "🔄 Update Ubuntu"
            "🔌 Docked Mode"
            "🔋 Portable Mode"
            "🔄 Toggle Mode"
            "▶️ Start VNC"
            "⏹️ Stop VNC"
        )
        
        for widget in "${widgets[@]}"; do
            if [[ -f "${shortcuts_dir}/${widget}" ]]; then
                rm -f "${shortcuts_dir}/${widget}"
                ((count++))
            fi
        done
        
        if [[ ${count} -gt 0 ]]; then
            log_success "Removed ${count} widget scripts"
        else
            log_info "No widget scripts found"
        fi
    else
        log_info "Shortcuts directory not found"
    fi
}

# ============================================================================
# REMOVE BASH INTEGRATION
# ============================================================================

remove_bash_integration() {
    echo ""
    echo -e "  ${BOLD}Removing Bash Integration${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    local bashrc="${HOME}/.bashrc"
    
    if [[ -f "${bashrc}" ]]; then
        # Create backup
        cp "${bashrc}" "${bashrc}.uninstall.bak"
        
        # Remove Ubuntu on Termux integration block
        if grep -q "# Ubuntu on Termux Integration" "${bashrc}"; then
            sed -i '/# Ubuntu on Termux Integration/,/^fi$/d' "${bashrc}" 2>/dev/null || true
            log_success "Removed Ubuntu integration from .bashrc"
        else
            log_info "Ubuntu integration not found in .bashrc"
        fi
        
        # Remove Tasker Automation Aliases block
        if grep -q "# Tasker Automation Aliases" "${bashrc}"; then
            sed -i '/# Tasker Automation Aliases/,/^fi$/d' "${bashrc}" 2>/dev/null || true
            log_success "Removed Tasker aliases from .bashrc"
        else
            log_info "Tasker aliases not found in .bashrc"
        fi
        
        log_info "Backup saved: ${bashrc}.uninstall.bak"
    else
        log_info ".bashrc not found"
    fi
}

# ============================================================================
# REMOVE UBUNTU DIRECTORY
# ============================================================================

remove_ubuntu_directory() {
    echo ""
    echo -e "  ${BOLD}Removing Ubuntu Directory${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    if [[ -d "${UBUNTU_HOME}" ]]; then
        # Show size
        local size=$(du -sh "${UBUNTU_HOME}" 2>/dev/null | cut -f1)
        log_info "Ubuntu directory size: ${size}"
        
        # Check for VM images
        if [[ -d "${UBUNTU_HOME}/pkvm/images" ]]; then
            local vm_count=$(find "${UBUNTU_HOME}/pkvm/images" -type f \( -name "*.qcow2" -o -name "*.img" \) 2>/dev/null | wc -l)
            if [[ ${vm_count} -gt 0 ]]; then
                log_warn "Found ${vm_count} VM image(s) in pkvm/images/"
                echo ""
                if confirm "Delete VM images too?"; then
                    log_info "VM images will be deleted"
                else
                    log_info "Backing up VM images..."
                    mkdir -p "${HOME}/ubuntu-vm-backup"
                    cp -r "${UBUNTU_HOME}/pkvm/images"/* "${HOME}/ubuntu-vm-backup/" 2>/dev/null || true
                    log_success "VM images backed up to ~/ubuntu-vm-backup/"
                fi
            fi
        fi
        
        echo ""
        echo -e "  ${RED}${BOLD}WARNING: This will permanently delete:${NC}"
        echo -e "  ${DIM}  - Ubuntu rootfs (entire Linux filesystem)${NC}"
        echo -e "  ${DIM}  - All configuration and logs${NC}"
        echo -e "  ${DIM}  - All scripts and documentation${NC}"
        echo -e "  ${DIM}  - VM images (unless backed up)${NC}"
        echo ""
        
        if confirm "Delete ${UBUNTU_HOME} and all contents? (${size})"; then
            log_info "Removing Ubuntu directory..."
            rm -rf "${UBUNTU_HOME}"
            
            if [[ ! -d "${UBUNTU_HOME}" ]]; then
                log_success "Ubuntu directory removed"
            else
                log_error "Failed to remove Ubuntu directory"
                log_info "Try: rm -rf ${UBUNTU_HOME}"
            fi
        else
            log_warn "Ubuntu directory preserved at ${UBUNTU_HOME}"
        fi
    else
        log_info "Ubuntu directory not found"
    fi
}

# ============================================================================
# SHOW SUMMARY
# ============================================================================

show_summary() {
    echo ""
    echo -e "  ${BOLD}${GREEN}Uninstallation Complete${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Check what's left
    local remaining=0
    
    if [[ -d "${UBUNTU_HOME}" ]]; then
        log_warn "Ubuntu directory still exists: ${UBUNTU_HOME}"
        ((remaining++))
    fi
    
    if ls ~/.termux/tasker/*ubuntu* &>/dev/null 2>&1 || \
       ls ~/.termux/tasker/*mode*.sh &>/dev/null 2>&1; then
        log_warn "Some Tasker scripts may remain in ~/.termux/tasker/"
        ((remaining++))
    fi
    
    if [[ ${remaining} -eq 0 ]]; then
        echo -e "  ${GREEN}All Ubuntu components have been removed.${NC}"
    fi
    
    echo ""
    echo -e "  ${BOLD}Optional Cleanup:${NC}"
    echo -e "  ${DIM}You may also want to remove these packages if no longer needed:${NC}"
    echo ""
    echo "    pkg uninstall proot proot-distro"
    echo "    pkg uninstall tigervnc"
    echo "    pkg uninstall pulseaudio"
    echo "    pkg uninstall qemu-system-aarch64 qemu-utils"
    echo ""
    echo -e "  ${DIM}To free up more space:${NC}"
    echo ""
    echo "    pkg autoclean"
    echo "    pkg clean"
    echo ""
    echo -e "  ${BOLD}Reinstall:${NC}"
    echo -e "  ${DIM}To reinstall Ubuntu on Termux:${NC}"
    echo ""
    echo "    git clone https://github.com/blewup/ubuntu.git ~/ubuntu"
    echo "    bash ~/ubuntu/scripts/00-preflight-check.sh"
    echo ""
}

# ============================================================================
# QUICK UNINSTALL (non-interactive)
# ============================================================================

quick_uninstall() {
    echo ""
    log_info "Quick uninstall mode"
    echo ""
    
    stop_services
    remove_tasker_scripts
    remove_widgets
    remove_bash_integration
    
    if [[ -d "${UBUNTU_HOME}" ]]; then
        log_info "Removing Ubuntu directory..."
        rm -rf "${UBUNTU_HOME}"
        log_success "Ubuntu directory removed"
    fi
    
    echo ""
    log_success "Uninstallation complete"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_header
    
    # Check if Ubuntu is installed
    if [[ ! -d "${UBUNTU_HOME}" ]]; then
        log_warn "Ubuntu directory not found at ${UBUNTU_HOME}"
        echo ""
        
        # Still offer to clean up other components
        if confirm "Clean up Tasker scripts, widgets, and bash integration anyway?"; then
            remove_tasker_scripts
            remove_widgets
            remove_bash_integration
            show_summary
        else
            echo ""
            echo "  Nothing to do. Exiting."
            echo ""
        fi
        exit 0
    fi
    
    # Show what will be removed
    echo -e "  ${BOLD}The following will be removed:${NC}"
    echo ""
    echo -e "  ${CYAN}•${NC} Ubuntu rootfs and all files in ~/ubuntu/"
    echo -e "  ${CYAN}•${NC} 27 Tasker automation scripts"
    echo -e "  ${CYAN}•${NC} 11 home screen widget scripts"
    echo -e "  ${CYAN}•${NC} Bash aliases and integration"
    echo -e "  ${CYAN}•${NC} VM images (with confirmation)"
    echo ""
    
    # Calculate total size
    local total_size=$(du -sh "${UBUNTU_HOME}" 2>/dev/null | cut -f1)
    echo -e "  ${BOLD}Total size:${NC} ${total_size}"
    echo ""
    
    if ! confirm "Proceed with uninstallation?"; then
        echo ""
        echo "  Cancelled. No changes made."
        echo ""
        exit 0
    fi
    
    # Run uninstallation steps
    stop_services
    remove_tasker_scripts
    remove_widgets
    remove_bash_integration
    remove_ubuntu_directory
    show_summary
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "Ubuntu on Termux - Uninstaller"
        echo ""
        echo "Usage: uninstall.sh [option]"
        echo ""
        echo "Options:"
        echo "  (none)      Interactive uninstallation"
        echo "  --quick     Non-interactive (removes everything)"
        echo "  --help      Show this help"
        echo ""
        echo "This script removes:"
        echo "  - Ubuntu rootfs (~3-10GB)"
        echo "  - Tasker automation scripts (27)"
        echo "  - Home screen widgets (11)"
        echo "  - Bash aliases and integration"
        echo "  - VM images (optional)"
        echo ""
        exit 0
        ;;
    --quick|-q|--yes|-y)
        print_header
        echo -e "  ${YELLOW}${BOLD}Quick uninstall mode - no confirmations${NC}"
        quick_uninstall
        ;; 
    *)
        main
        ;;
 esac
