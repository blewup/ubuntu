#!/data/data/com.termux/files/usr/bin/bash
#
# termux-hub.sh - Central Control Panel for Ubuntu on Termux
#
# A unified interface to manage all Ubuntu services, VMs, and settings
#

set -euo pipefail

UBUNTU_HOME="${HOME}/ubuntu"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

clear_screen() {
    printf "\033c"
}

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}████████╗███████╗██████╗ ███╗   ███╗██╗   ██╗██╗  ██╗${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║   ██║╚██╗██╔╝${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}   ██║   █████╗  ██████╔╝██╔████╔██║██║   ██║ ╚███╔╝${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║ ██╔██╗${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}   ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}              ${DIM}Ubuntu 26.04 LTS Control Hub v${VERSION}${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_status_bar() {
    local vnc_status="${RED}●${NC}"
    local audio_status="${RED}●${NC}"
    local proot_status="${RED}●${NC}"
    local mode="none"
    
    pgrep -f "Xvnc" &>/dev/null && vnc_status="${GREEN}●${NC}"
    pgrep -x pulseaudio &>/dev/null && audio_status="${GREEN}●${NC}"
    pgrep -f "proot.*ubuntu" &>/dev/null && proot_status="${GREEN}●${NC}"
    
    local mode_file="${UBUNTU_HOME}/logs/tasker/.current_mode"
    [[ -f "${mode_file}" ]] && mode=$(cat "${mode_file}")
    
    local ip=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "N/A")
    
    echo -e "  ${DIM}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "  ${DIM}│${NC} VNC: ${vnc_status}  Audio: ${audio_status}  PRoot: ${proot_status}  ${DIM}│${NC} Mode: ${CYAN}${mode}${NC} ${DIM}│${NC} IP: ${YELLOW}${ip}${NC} ${DIM}│${NC}"
    echo -e "  ${DIM}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

wait_key() {
    echo ""
    read -n 1 -s -r -p "  Press any key to continue..."
    echo ""
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_main_menu() {
    clear_screen
    print_header
    print_status_bar
    
    echo -e "  ${BOLD}${BLUE}MAIN MENU${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${BOLD}Launch Ubuntu${NC}"
    echo -e "  ${GREEN}1${NC})  🐧  Ubuntu Shell"
    echo -e "       ${DIM}Open a terminal inside Ubuntu. Run commands, install${NC}"
    echo -e "       ${DIM}packages, edit files. Type 'exit' to return to Termux.${NC}"
    echo ""
    echo -e "  ${GREEN}2${NC})  🖥️   KDE Plasma Desktop"
    echo -e "       ${DIM}Start the full KDE Plasma desktop environment. Connect${NC}"
    echo -e "       ${DIM}with a VNC viewer to see the graphical interface.${NC}"
    echo ""
    echo -e "  ${GREEN}3${NC})  🪟  XFCE Desktop"
    echo -e "       ${DIM}Start lightweight XFCE desktop. Uses less resources than${NC}"
    echo -e "       ${DIM}KDE, good for older devices or battery saving.${NC}"
    echo ""
    echo -e "  ${GREEN}4${NC})  📺  Cast to TV"
    echo -e "       ${DIM}Setup TV mode (1080p) and start KDE. Cast your Android${NC}"
    echo -e "       ${DIM}screen to Chromecast/TV, then connect VNC to localhost.${NC}"
    echo ""
    echo -e "  ${BOLD}Settings & Tools${NC}"
    echo -e "  ${YELLOW}5${NC})  ⚙️   Display Mode Settings"
    echo -e "       ${DIM}Switch between docked (1440p), TV (1080p), and portable${NC}"
    echo -e "       ${DIM}(720p) display modes for different use cases.${NC}"
    echo ""
    echo -e "  ${YELLOW}6${NC})  🔧  Service Control"
    echo -e "       ${DIM}Start/stop VNC server, PulseAudio, update packages,${NC}"
    echo -e "       ${DIM}and manage all Ubuntu background services.${NC}"
    echo ""
    echo -e "  ${YELLOW}7${NC})  💻  Virtual Machines"
    echo -e "       ${DIM}Create and run QEMU virtual machines for isolated${NC}"
    echo -e "       ${DIM}workloads, testing, or running other Linux distros.${NC}"
    echo ""
    echo -e "  ${YELLOW}8${NC})  📊  System Status"
    echo -e "       ${DIM}View detailed system information: device specs, running${NC}"
    echo -e "       ${DIM}services, network, storage, and memory usage.${NC}"
    echo ""
    echo -e "  ${BOLD}Help & Info${NC}"
    echo -e "  ${CYAN}9${NC})  📚  Documentation"
    echo -e "       ${DIM}Read setup guides, Tasker automation docs, and${NC}"
    echo -e "       ${DIM}virtualization documentation.${NC}"
    echo ""
    echo -e "  ${CYAN}0${NC})  ❓  Quick Help"
    echo -e "       ${DIM}Show quick reference of terminal commands, aliases,${NC}"
    echo -e "       ${DIM}and how to connect to the desktop.${NC}"
    echo ""
    echo -e "  ${RED}q${NC})  Exit Hub"
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -n "  Select option: "
}

# ============================================================================
# DISPLAY MODE MENU
# ============================================================================

show_mode_menu() {
    clear_screen
    print_header
    print_status_bar
    
    echo -e "  ${BOLD}${BLUE}DISPLAY MODE SETTINGS${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${DIM}Display modes adjust VNC resolution for different scenarios.${NC}"
    echo -e "  ${DIM}Higher resolutions need more resources but look sharper.${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC})  🔌  Docked Mode ${CYAN}(2560x1440)${NC}"
    echo -e "       ${DIM}High resolution for external monitors. Best when${NC}"
    echo -e "       ${DIM}connected to USB-C dock with power supply.${NC}"
    echo ""
    echo -e "  ${GREEN}2${NC})  📺  TV Mode ${CYAN}(1920x1080)${NC}"
    echo -e "       ${DIM}Full HD for Chromecast and smart TVs. Optimal for${NC}"
    echo -e "       ${DIM}screen casting while using phone as touchpad.${NC}"
    echo ""
    echo -e "  ${GREEN}3${NC})  🔋  Portable Mode ${CYAN}(1280x720)${NC}"
    echo -e "       ${DIM}Lower resolution to save battery and resources.${NC}"
    echo -e "       ${DIM}Best for on-the-go use on phone screen.${NC}"
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${YELLOW}4${NC})  🔄  Toggle Mode"
    echo -e "       ${DIM}Cycle through modes: portable → TV → docked → portable${NC}"
    echo ""
    echo -e "  ${YELLOW}5${NC})  📋  Show Current Mode"
    echo -e "       ${DIM}Display which mode is currently active${NC}"
    echo ""
    echo -e "  ${RED}b${NC})  Back to Main Menu"
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -n "  Select option: "
}

handle_mode_menu() {
    while true; do
        show_mode_menu
        read -r choice
        
        case "${choice}" in
            1)
                echo ""
                echo "  Switching to Docked Mode (2560x1440)..."
                ~/.termux/tasker/docked-mode.sh
                wait_key
                ;; 
            2)
                echo ""
                echo "  Switching to TV Mode (1920x1080)..."
                ~/.termux/tasker/tv-mode.sh
                wait_key
                ;;
            3)
                echo ""
                echo "  Switching to Portable Mode (1280x720)..."
                ~/.termux/tasker/portable-mode.sh
                wait_key
                ;;
            4)
                echo ""
                echo "  Toggling to next mode..."
                ~/.termux/tasker/toggle-mode.sh
                wait_key
                ;;
            5)
                echo ""
                echo -n "  Current Mode: "
                ~/.termux/tasker/get-mode.sh
                wait_key
                ;;
            b|B)
                return
                ;;
            *)
                echo "  Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# SERVICE CONTROL MENU
# ============================================================================

show_service_menu() {
    clear_screen
    print_header
    print_status_bar
    
    echo -e "  ${BOLD}${BLUE}SERVICE CONTROL${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${DIM}Manage background services that power the Ubuntu desktop.${NC}"
    echo ""
    echo -e "  ${BOLD}VNC Server${NC} ${DIM}(Remote Desktop)${NC}"
    echo -e "  ${GREEN}1${NC})  ▶️   Start VNC"
    echo -e "       ${DIM}Start the VNC server to enable remote desktop access.${NC}"
    echo -e "       ${DIM}Required for KDE/XFCE. Connect with any VNC viewer.${NC}"
    echo ""
    echo -e "  ${GREEN}2${NC})  ⏹️   Stop VNC"
    echo -e "       ${DIM}Stop the VNC server. Desktop will no longer be accessible.${NC}"
    echo ""
    echo -e "  ${GREEN}3${NC})  🔄  Restart VNC"
    echo -e "       ${DIM}Stop and restart VNC. Useful if display is frozen.${NC}"
    echo ""
    echo -e "  ${BOLD}PulseAudio${NC} ${DIM}(Sound System)${NC}"
    echo -e "  ${YELLOW}4${NC})  🔊  Start Audio"
    echo -e "       ${DIM}Start PulseAudio server for sound support in Ubuntu.${NC}"
    echo -e "       ${DIM}Required for audio playback in desktop apps.${NC}"
    echo ""
    echo -e "  ${YELLOW}5${NC})  🔇  Stop Audio"
    echo -e "       ${DIM}Stop PulseAudio to free resources. Disables Ubuntu audio.${NC}"
    echo ""
    echo -e "  ${BOLD}System${NC}"
    echo -e "  ${RED}6${NC})  ⏹️   Stop All Services"
    echo -e "       ${DIM}Stop VNC, PulseAudio, and all Ubuntu processes.${NC}"
    echo -e "       ${DIM}Frees all resources used by Ubuntu.${NC}"
    echo ""
    echo -e "  ${CYAN}7${NC})  🔄  Update Ubuntu"
    echo -e "       ${DIM}Run apt update && apt upgrade to install latest${NC}"
    echo -e "       ${DIM}security patches and package updates.${NC}"
    echo ""
    echo -e "  ${RED}b${NC})  Back to Main Menu"
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -n "  Select option: "
}

handle_service_menu() {
    while true; do
        show_service_menu
        read -r choice
        
        case "${choice}" in
            1)
                echo ""
                ~/.termux/tasker/vnc-start.sh
                wait_key
                ;; 
            2)
                echo ""
                ~/.termux/tasker/vnc-stop.sh
                wait_key
                ;;
            3)
                echo ""
                echo "  Restarting VNC..."
                ~/.termux/tasker/vnc-stop.sh
                sleep 1
                ~/.termux/tasker/vnc-start.sh
                wait_key
                ;;
            4)
                echo ""
                ~/.termux/tasker/audio-start.sh
                wait_key
                ;;
            5)
                echo ""
                ~/.termux/tasker/audio-stop.sh
                wait_key
                ;;
            6)
                echo ""
                echo "  Stopping all Ubuntu services..."
                ~/.termux/tasker/stop-ubuntu.sh
                wait_key
                ;;
            7)
                echo ""
                echo "  Updating Ubuntu packages..."
                ~/.termux/tasker/update-ubuntu.sh
                wait_key
                ;;
            b|B)
                return
                ;;
            *)
                echo "  Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# VM MENU
# ============================================================================

show_vm_menu() {
    clear_screen
    print_header
    
    echo -e "  ${BOLD}${BLUE}VIRTUAL MACHINES (QEMU)${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${DIM}Run isolated virtual machines using QEMU emulation.${NC}"
    echo -e "  ${DIM}VMs are separate from proot Ubuntu - fully sandboxed.${NC}"
    echo ""
    echo -e "  ${BOLD}VM Management${NC}"
    echo -e "  ${GREEN}1${NC})  📊  Virtualization Status"
    echo -e "       ${DIM}Check if your device supports hardware virtualization${NC}"
    echo -e "       ${DIM}(AVF/pKVM) and show QEMU installation status.${NC}"
    echo ""
    echo -e "  ${GREEN}2${NC})  📋  List VM Images"
    echo -e "       ${DIM}Show all virtual disk images in ~/ubuntu/pkvm/images/${NC}"
    echo -e "       ${DIM}with their sizes and formats.${NC}"
    echo ""
    echo -e "  ${GREEN}3${NC})  ➕  Create New VM"
    echo -e "       ${DIM}Create a new virtual disk image (qcow2 format).${NC}"
    echo -e "       ${DIM}You'll need to install an OS from ISO or cloud image.${NC}"
    echo ""
    echo -e "  ${GREEN}4${NC})  ▶️   Run VM"
    echo -e "       ${DIM}Start a virtual machine. SSH via localhost:2222,${NC}"
    echo -e "       ${DIM}VNC via localhost:5900. Ctrl+A,X to exit QEMU.${NC}"
    echo ""
    echo -e "  ${BOLD}Setup${NC}"
    echo -e "  ${YELLOW}5${NC})  📥  Install QEMU"
    echo -e "       ${DIM}Install QEMU emulator packages. Required to run VMs.${NC}"
    echo -e "       ${DIM}Uses software emulation (slower than native).${NC}"
    echo ""
    echo -e "  ${YELLOW}6${NC})  ℹ️   AVF/pKVM Info"
    echo -e "       ${DIM}Show Android Virtualization Framework status.${NC}"
    echo -e "       ${DIM}Pixel 6+ devices may have hardware acceleration.${NC}"
    echo ""
    echo -e "  ${RED}b${NC})  Back to Main Menu"
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -n "  Select option: "
}

handle_vm_menu() {
    while true; do
        show_vm_menu
        read -r choice
        
        case "${choice}" in
            1)
                echo ""
                "${UBUNTU_HOME}/scripts/pkvm-bridge.sh" status
                wait_key
                ;; 
            2)
                echo ""
                "${UBUNTU_HOME}/scripts/pkvm-bridge.sh" list
                wait_key
                ;;
            3)
                echo ""
                echo -e "  ${BOLD}Create New VM Image${NC}"
                echo ""
                echo -n "  Enter VM name: "
                read -r vm_name
                if [[ -z "${vm_name}" ]]; then
                    echo "  Cancelled"
                else
                    echo -n "  Enter size (e.g., 20G) [20G]: "
                    read -r vm_size
                    "${UBUNTU_HOME}/scripts/pkvm-bridge.sh" create "${vm_name}" "${vm_size:-20G}"
                fi
                wait_key
                ;;
            4)
                echo ""
                echo -e "  ${BOLD}Available Images:${NC}"
                "${UBUNTU_HOME}/scripts/pkvm-bridge.sh" list
                echo ""
                echo -n "  Enter image name (or path): "
                read -r vm_image
                if [[ -z "${vm_image}" ]]; then
                    echo "  Cancelled"
                else
                    echo -n "  Memory [2G]: "
                    read -r vm_mem
                    echo -n "  CPU cores [2]: "
                    read -r vm_cpu
                    echo ""
                    echo "  Starting VM... (Ctrl+A, X to exit)"
                    "${UBUNTU_HOME}/scripts/pkvm-bridge.sh" run "${vm_image}" "${vm_mem:-2G}" "${vm_cpu:-2}"
                fi
                ;;
            5)
                echo ""
                echo "  Installing QEMU..."
                "${UBUNTU_HOME}/scripts/pkvm-bridge.sh" qemu
                wait_key
                ;;
            6)
                echo ""
                if [[ -f "${UBUNTU_HOME}/pkvm/avf-info.sh" ]]; then
                    "${UBUNTU_HOME}/pkvm/avf-info.sh"
                else
                    echo "  AVF info script not found"
                    echo "  Quick check:"
                    echo "    AVF: $(getprop ro.boot.hypervisor.vm.supported 2>/dev/null || echo 'not set')"
                    echo "    pVM: $(getprop ro.boot.hypervisor.protected_vm.supported 2>/dev/null || echo 'not set')"
                fi
                wait_key
                ;;
            b|B)
                return
                ;;
            *)
                echo "  Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# STATUS
# ============================================================================

show_status() {
    clear_screen
    print_header
    
    echo -e "  ${BOLD}${BLUE}SYSTEM STATUS${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Device info
    echo -e "  ${BOLD}📱 Device Information${NC}"
    echo -e "  ${DIM}Hardware and OS details${NC}"
    echo ""
    echo "    Model:     $(getprop ro.product.model 2>/dev/null || echo 'Unknown')"
    echo "    Device:    $(getprop ro.product.device 2>/dev/null || echo 'Unknown')"
    echo "    Android:   $(getprop ro.build.version.release 2>/dev/null || echo 'Unknown') (SDK $(getprop ro.build.version.sdk 2>/dev/null || echo '?'))"
    echo "    Kernel:    $(uname -r)"
    echo "    Arch:      $(uname -m)"
    echo ""
    
    # Services
    echo -e "  ${BOLD}⚙️  Running Services${NC}"
    echo -e "  ${DIM}Background processes status${NC}"
    echo ""
    local vnc_stat="${RED}Stopped${NC}"; pgrep -f "Xvnc" &>/dev/null && vnc_stat="${GREEN}Running${NC}"
    local audio_stat="${RED}Stopped${NC}"; pgrep -x pulseaudio &>/dev/null && audio_stat="${GREEN}Running${NC}"
    local proot_stat="${RED}Stopped${NC}"; pgrep -f "proot.*ubuntu" &>/dev/null && proot_stat="${GREEN}Running${NC}"
    echo -e "    VNC Server:   ${vnc_stat}"
    echo -e "    PulseAudio:   ${audio_stat}"
    echo -e "    PRoot:        ${proot_stat}"
    echo ""
    
    # Display Mode
    local mode="none"
    local mode_file="${UBUNTU_HOME}/logs/tasker/.current_mode"
    [[ -f "${mode_file}" ]] && mode=$(cat "${mode_file}")
    echo -e "  ${BOLD}🖥️  Display Mode${NC}"
    echo -e "  ${DIM}Current VNC resolution setting${NC}"
    echo ""
    echo -e "    Mode:      ${CYAN}${mode}${NC}"
    case "${mode}" in
        docked)  echo "    Resolution: 2560x1440" ;;
        tv)      echo "    Resolution: 1920x1080" ;;
        portable) echo "    Resolution: 1280x720" ;;
    esac
    echo ""
    
    # Network
    local ip=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++)if($i=="src")print $(i+1)}' || echo "N/A")
    echo -e "  ${BOLD}🌐 Network${NC}"
    echo -e "  ${DIM}Connection information${NC}"
    echo ""
    echo "    IP Address: ${ip}"
    echo "    VNC Port:   5901"
    echo "    VNC URL:    ${ip}:5901"
    echo ""
    
    # Storage
    echo -e "  ${BOLD}💾 Storage${NC}"
    echo -e "  ${DIM}Disk usage information${NC}"
    echo ""
    du -sh "${UBUNTU_HOME}" 2>/dev/null | awk '{print "    Ubuntu:     " $1}'
    du -sh "${UBUNTU_HOME}/rootfs" 2>/dev/null | awk '{print "    Rootfs:     " $1}'
    df -h "${HOME}" 2>/dev/null | tail -1 | awk '{print "    Available:  " $4 " of " $2}'
    echo ""
    
    # Memory
    echo -e "  ${BOLD}🧠 Memory${NC}"
    echo -e "  ${DIM}RAM usage${NC}"
    echo ""
    free -h 2>/dev/null | grep "Mem:" | awk '{print "    Total:      " $2 "\n    Used:       " $3 "\n    Free:       " $4}'
    echo ""
    
    wait_key
}

# ============================================================================
# DOCUMENTATION MENU
# ============================================================================

show_docs_menu() {
    clear_screen
    print_header
    
    echo -e "  ${BOLD}${BLUE}DOCUMENTATION${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${DIM}Read guides and documentation for Ubuntu on Termux.${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC})  📖  Main README"
    echo -e "       ${DIM}Overview, quick start, available commands, and${NC}"
    echo -e "       ${DIM}general information about the installation.${NC}"
    echo ""
    echo -e "  ${GREEN}2${NC})  🤖  Tasker Setup Guide"
    echo -e "       ${DIM}How to configure Tasker for automatic mode switching.${NC}"
    echo -e "       ${DIM}USB detection, WiFi triggers, battery events.${NC}"
    echo ""
    echo -e "  ${GREEN}3${NC})  💻  Virtualization Guide"
    echo -e "       ${DIM}pKVM/AVF and QEMU documentation. How to create and${NC}"
    echo -e "       ${DIM}run virtual machines for isolated workloads.${NC}"
    echo ""
    echo -e "  ${YELLOW}4${NC})  📂  List All Docs"
    echo -e "       ${DIM}Show all files in the documentation folder.${NC}"
    echo ""
    echo -e "  ${RED}b${NC})  Back to Main Menu"
    echo ""
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -n "  Select option: "
}

handle_docs_menu() {
    while true; do
        show_docs_menu
        read -r choice
        
        case "${choice}" in
            1)
                if [[ -f "${UBUNTU_HOME}/docs/README.md" ]]; then
                    less "${UBUNTU_HOME}/docs/README.md"
                else
                    echo ""
                    echo "  README.md not found"
                    echo "  Run 99-finalize.sh to create documentation"
                    wait_key
                fi
                ;;
            2)
                if [[ -f "${UBUNTU_HOME}/docs/TASKER_SETUP.md" ]]; then
                    less "${UBUNTU_HOME}/docs/TASKER_SETUP.md"
                else
                    echo ""
                    echo "  TASKER_SETUP.md not found"
                    echo "  Run 10-tasker-automation.sh to create it"
                    wait_key
                fi
                ;;
            3)
                if [[ -f "${UBUNTU_HOME}/docs/PKVM_GUIDE.md" ]]; then
                    less "${UBUNTU_HOME}/docs/PKVM_GUIDE.md"
                else
                    echo ""
                    echo "  PKVM_GUIDE.md not found"
                    echo "  Run 11-pkvm-integration.sh to create it"
                    wait_key
                fi
                ;;
            4)
                echo ""
                echo -e "  ${BOLD}Documentation Files:${NC}"
                echo ""
                if [[ -d "${UBUNTU_HOME}/docs" ]]; then
                    ls -lah "${UBUNTU_HOME}/docs/" 2>/dev/null
                else
                    echo "  Docs folder not found"
                fi
                wait_key
                ;;
            b|B)
                return
                ;;
            *)
                echo "  Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    clear_screen
    print_header
    
    echo -e "  ${BOLD}${BLUE}QUICK HELP${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${BOLD}🚀 Getting Started${NC}"
    echo -e "  ${DIM}Basic workflow to use Ubuntu desktop${NC}"
    echo ""
    echo "    1. Run 'ubuntu-kde' or select option 2 from main menu"
    echo "    2. Note the VNC address shown (e.g., 192.168.1.100:5901)"
    echo "    3. Open any VNC viewer app on your phone"
    echo "    4. Connect to the address shown"
    echo "    5. Use the full KDE Plasma desktop!"
    echo ""
    echo -e "  ${BOLD}⌨️  Terminal Commands${NC}"
    echo -e "  ${DIM}Quick commands you can type in Termux${NC}"
    echo ""
    echo "    ubuntu              Start Ubuntu shell"
    echo "    ubuntu-kde          Start KDE desktop"
    echo "    ubuntu-xfce         Start XFCE desktop"
    echo "    ubuntu-status       Show system status"
    echo "    ubuntu-stop         Stop all services"
    echo "    ubuntu-help         Show command help"
    echo "    termux-hub          Open this control panel"
    echo ""
    echo -e "  ${BOLD}🖥️  Display Mode Commands${NC}"
    echo -e "  ${DIM}Switch VNC resolution${NC}"
    echo ""
    echo "    mode-docked         2560x1440 (external monitor)"
    echo "    mode-tv             1920x1080 (Chromecast/TV)"
    echo "    mode-portable       1280x720 (battery saving)"
    echo "    mode-toggle         Cycle through modes"
    echo "    mode-get            Show current mode"
    echo ""
    echo -e "  ${BOLD}🔧 Service Commands${NC}"
    echo -e "  ${DIM}Control background services${NC}"
    echo ""
    echo "    vnc-start           Start VNC server"
    echo "    vnc-stop            Stop VNC server"
    echo "    vnc-status          Check if VNC is running"
    echo "    audio-start         Start PulseAudio"
    echo "    audio-stop          Stop PulseAudio"
    echo ""
    echo -e "  ${BOLD}📺 Casting to TV${NC}"
    echo -e "  ${DIM}How to display Ubuntu on your TV${NC}"
    echo ""
    echo "    1. Run 'mode-tv' to set 1080p resolution"
    echo "    2. Start 'ubuntu-kde'"
    echo "    3. Open Android Quick Settings (swipe down)"
    echo "    4. Tap 'Screen Cast' or 'Smart View'"
    echo "    5. Select your Chromecast or TV"
    echo "    6. Open VNC viewer, connect to localhost:5901"
    echo "    7. Ubuntu appears on your TV!"
    echo ""
    echo -e "  ${BOLD}❌ Troubleshooting${NC}"
    echo -e "  ${DIM}Common fixes${NC}"
    echo ""
    echo "    VNC frozen:     vnc-stop && vnc-start"
    echo "    No audio:       audio-start"
    echo "    Reset mode:     rm ~/ubuntu/logs/tasker/.current_mode"
    echo "    View logs:      tail -f ~/ubuntu/logs/tasker/*.log"
    echo ""
    
    wait_key
}

# ============================================================================
# MAIN LOOP
# ============================================================================

main() {
    # Check if Ubuntu is installed
    if [[ ! -d "${UBUNTU_HOME}" ]]; then
        echo "Error: Ubuntu not found at ${UBUNTU_HOME}"
        echo "Please run the installation scripts first."
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -r choice
        
        case "${choice}" in
            1)
                clear_screen
                echo ""
                echo -e "  ${BOLD}Starting Ubuntu Shell...${NC}"
                echo -e "  ${DIM}Type 'exit' to return to Termux${NC}"
                echo ""
                sleep 1
                "${UBUNTU_HOME}/scripts/launch-ubuntu.sh" --shell
                ;; 
            2)
                clear_screen
                echo ""
                "${UBUNTU_HOME}/scripts/launch-ubuntu.sh" --kde
                wait_key
                ;;
            3)
                clear_screen
                echo ""
                "${UBUNTU_HOME}/scripts/launch-ubuntu.sh" --xfce
                wait_key
                ;;
            4)
                clear_screen
                echo ""
                echo -e "  ${BOLD}Setting up TV Mode (1920x1080)...${NC}"
                echo ""
                ~/.termux/tasker/tv-mode.sh 2>/dev/null || echo "  Mode script not found. Run 10-tasker-automation.sh first."
                echo ""
                read -p "  Start KDE desktop now? [Y/n] " start_kde
                if [[ "${start_kde}" != "n" && "${start_kde}" != "N" ]]; then
                    "${UBUNTU_HOME}/scripts/launch-ubuntu.sh" --kde
                fi
                wait_key
                ;;
            5)
                handle_mode_menu
                ;;
            6)
                handle_service_menu
                ;;
            7)
                handle_vm_menu
                ;;
            8)
                show_status
                ;;
            9)
                handle_docs_menu
                ;;
            0)
                show_help
                ;;
            q|Q)
                clear_screen
                echo ""
                echo -e "  ${GREEN}Goodbye!${NC}"
                echo ""
                exit 0
                ;; 
            *)
                echo "  Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Termux Hub - Ubuntu Control Panel"
        echo ""
        echo "Usage: termux-hub [option]"
        echo ""
        echo "Options:"
        echo "  (none)      Open interactive menu"
        echo "  --help      Show this help"
        echo "  --status    Quick status bar"
        echo "  --version   Show version"
        echo ""
        exit 0
        ;; 
    --status)
        print_status_bar
        exit 0
        ;;
    --version)
        echo "Termux Hub v${VERSION}"
        exit 0
        ;; 
    *)
        main
        ;;
esac