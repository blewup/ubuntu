🔢 Installation Order & Steps
Pre-Installation Requirements
Step	Action	Command/Location
1	Install Termux from F-Droid	F-Droid app store
2	Install Termux:API from F-Droid	F-Droid app store
3	Install Termux:Tasker from F-Droid	F-Droid app store
4	Install Termux:Widget from F-Droid	F-Droid app store
5	Install Shizuku (optional)	Play Store or GitHub
6	Download Ubuntu rootfs tarball	Place in ~/
7	Grant Termux storage permission	termux-setup-storage

Installation Phases
Phase	Script	Description	Dependencies
0	00-preflight-check.sh	Validate environment	None
1	01-setup-termux.sh	Install Termux packages	Phase 0
1	02-setup-shizuku.sh	Configure Shizuku (optional)	Phase 0
2	03-extract-rootfs.sh	Extract Ubuntu rootfs	Phase 1, tarball
2	04-configure-proot.sh	Configure PRoot	Phase 2 (03)
3	05-install-kde-plasma.sh	Install KDE Plasma	Phase 2
3	06-mesa-zink-setup.sh	Configure GPU drivers	Phase 2
4	07-input-config.sh	Configure input devices	Phase 2
5	08-display-miracast.sh	Setup Miracast	Phase 2
5	09-display-scrcpy-x11.sh	Setup Scrcpy	Phase 2
6	10-tasker-automation.sh	Setup Tasker automation	Phase 1
6	11-pkvm-integration.sh	Setup pKVM bridge	Phase 2
7	99-finalize.sh	Final configuration	All phases

Post-Installation Steps
Step	Action	Command
1	Reload shell	source ~/.bashrc or restart Termux
2	Run first boot setup	ubuntu --first-boot
3	Start Ubuntu shell	ubuntu
4	Start KDE desktop	ubuntu-kde

📁 Full Project Structure
Code
~/ubuntu/
├── lib/                              # Shared Libraries
│   ├── colors.sh                     # ✅ Complete - Terminal colors
│   ├── functions.sh                  # ✅ Complete - Core functions
│   ├── validators.sh                 # ✅ Complete - Input validation
│   ├── display.sh                    # ✅ Complete - Display management
│   ├── services.sh                   # ✅ Complete - Service management
│   ├── proot-utils.sh                # ✅ Complete - PRoot utilities
│   └── tasker.sh                     # ✅ Complete - Tasker integration
│
├── scripts/                          # Installation & Runtime Scripts
│   ├── 00-preflight-check.sh         # ✅ Complete - Pre-installation checks
│   ├── 01-setup-termux.sh            # ✅ Complete - Termux environment
│   ├── 02-setup-shizuku.sh           # ✅ Complete - Shizuku integration
│   ├── 03-extract-rootfs.sh          # ✅ Complete - Ubuntu extraction
│   ├── 04-configure-proot.sh         # ✅ Complete - PRoot configuration
│   ├── 05-install-kde-plasma.sh      # ✅ Complete - KDE installation
│   ├── 06-mesa-zink-setup.sh         # ✅ Complete - GPU drivers
│   ├── 07-input-config.sh            # ✅ Complete - Input devices
│   ├── 08-display-miracast.sh        # ✅ Complete - Miracast streaming
│   ├── 09-display-scrcpy-x11.sh      # ✅ Complete - Scrcpy display
│   ├── 10-tasker-automation.sh       # 🔄 Completing now
│   ├── 11-pkvm-integration.sh        # 📝 To complete
│   ├── 99-finalize.sh                # 📝 To complete
│   ├── launch-ubuntu.sh              # ✅ Complete - Main launcher
│   ├── ubuntu-shell                  # ✅ Complete - Quick shell
│   ├── ubuntu-kde                    # ✅ Complete - Quick KDE
│   ├── ubuntu-run                    # ✅ Complete - Run command
│   ├── ubuntu-update                 # ✅ Complete - Update system
│   ├── ubuntu-status                 # ✅ Complete - Show status
│   ├── miracast-display.sh           # ✅ Complete - Miracast control
│   ├── scrcpy-display.sh             # ✅ Complete - Scrcpy control
│   ├── pkvm-bridge.sh                # 📝 To complete
│   ├── input-bridge.sh               # ✅ Complete - Input bridge
│   ├── gpu-access.sh                 # ✅ Complete - GPU helper
│   └── optimize-proot.sh             # ✅ Complete - Optimizations
│
├── config/                           # Configuration Files
│   ├──.auto_start
│   ├──tasker-aliases.sh
│   ├── proot.conf                    # ✅ Created by 04
│   ├── proot-shizuku.conf            # ✅ Created by 02
│   └── display-profiles/             # ✅ Created by 08
│       ├── tv-1080p.conf
│       ├── tv-4k.conf
│       ├── portable-720p.conf
│       └── monitor-1440p.conf
│
├── rootfs/                           # Ubuntu 26.04 System (extracted)
│
├── mesa-zink/                        # GPU Drivers
│   ├── debs/
│   ├── extracted/
│   └── libs/
│
├── pkvm/                             # pKVM Integration
│   ├── images/
│   ├── config/
│   └── shared/
│
├── cache/                            # Build cache
├── logs/                             # Installation logs
├── backup/                           # Backup files
│
└── docs/                             # Documentation
    ├── TASKER_SETUP.md
    ├── README.md
    └── TROUBLESHOOTING.md

~/.termux/tasker/                     # Tasker Scripts
├── docked-mode.sh
├── tv-mode.sh
├── portable-mode.sh
├── start-ubuntu.sh
├── start-ubuntu-kde.sh
├── stop-ubuntu.sh
├── update-ubuntu.sh
├── status-ubuntu.sh
├── wifi-connected.sh
├── usb-connected.sh
├── usb-disconnected.sh
├── boot-complete.sh
├── battery-low.sh
├── charging.sh
├── screen-off.sh
├── screen-on.sh
├── toggle-mode.sh
├── set-mode.sh
├── get-mode.sh
├── ubuntu-notify.sh
├── vnc-start.sh
├── vnc-stop.sh
├── vnc-status.sh
├── audio-start.sh
├── audio-stop.sh
├── autostart-enable.sh
└── autostart-disable.sh

~/.shortcuts/                   # Widget scripts (11 files)
├── 🐧 Ubuntu Shell
├── 🖥️ Ubuntu KDE
├── 📺 Cast to TV
├── ⏹️ Stop Ubuntu
├── ℹ️ Ubuntu Status
├── 🔄 Update Ubuntu
├── 🔌 Docked Mode
├── 🔋 Portable Mode
├── 🔄 Toggle Mode
├── ▶️ Start VNC
└── ⏹️ Stop VNC

~/ubuntu/logs/tasker/           # Log files
├── docked-mode.log
├── tv-mode.log
├── portable-mode.log
├── stop-ubuntu.log
├── update-ubuntu.log
├── boot.log
├── wifi.log
├── usb.log
├── battery.log
├── screen.log
└── .current_mode               # Current mode state file

~/ubuntu/config/                # Configuration
├── .auto_start                 # Auto-start setting (true/false)
└── tasker-aliases.sh           # Bash aliases

~/.shortcuts/                         # Home Screen Widgets
├── 🐧 Ubuntu Shell
├── 🖥️ Ubuntu KDE
├── 📺 Cast to TV
└── ⏹️ Stop Ubuntu

~/.shizuku/                           # Shizuku Integration
├── rish
├── shizuku-utils.sh
└── ShizukuHelper.java


