#!/data/data/com.termux/files/usr/bin/bash
#
# colors.sh - Terminal Color Definitions
# Ubuntu 26.04 Resolute on Termux Project
#
# Source this file to enable colored output in scripts
# Usage: source ~/ubuntu/lib/colors.sh
#

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

# Check if terminal supports colors
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && command -v tput &>/dev/null; then
    COLORS_SUPPORTED=$(tput colors 2>/dev/null || echo 0)
else
    COLORS_SUPPORTED=0
fi

if [[ ${COLORS_SUPPORTED} -ge 8 ]]; then
    # Basic Colors
    COLOR_BLACK=$'\e[0;30m'
    COLOR_RED=$'\e[0;31m'
    COLOR_GREEN=$'\e[0;32m'
    COLOR_YELLOW=$'\e[0;33m'
    COLOR_BLUE=$'\e[0;34m'
    COLOR_MAGENTA=$'\e[0;35m'
    COLOR_CYAN=$'\e[0;36m'
    COLOR_WHITE=$'\e[0;37m'
    
    # Bold Colors
    COLOR_BOLD_BLACK=$'\e[1;30m'
    COLOR_BOLD_RED=$'\e[1;31m'
    COLOR_BOLD_GREEN=$'\e[1;32m'
    COLOR_BOLD_YELLOW=$'\e[1;33m'
    COLOR_BOLD_BLUE=$'\e[1;34m'
    COLOR_BOLD_MAGENTA=$'\e[1;35m'
    COLOR_BOLD_CYAN=$'\e[1;36m'
    COLOR_BOLD_WHITE=$'\e[1;37m'
    
    # Background Colors
    COLOR_BG_BLACK=$'\e[40m'
    COLOR_BG_RED=$'\e[41m'
    COLOR_BG_GREEN=$'\e[42m'
    COLOR_BG_YELLOW=$'\e[43m'
    COLOR_BG_BLUE=$'\e[44m'
    COLOR_BG_MAGENTA=$'\e[45m'
    COLOR_BG_CYAN=$'\e[46m'
    COLOR_BG_WHITE=$'\e[47m'
    
    # Text Styles
    COLOR_BOLD=$'\e[1m'
    COLOR_DIM=$'\e[2m'
    COLOR_ITALIC=$'\e[3m'
    COLOR_UNDERLINE=$'\e[4m'
    COLOR_BLINK=$'\e[5m'
    COLOR_REVERSE=$'\e[7m'
    COLOR_HIDDEN=$'\e[8m'
    COLOR_STRIKETHROUGH=$'\e[9m'
    
    # Reset
    COLOR_RESET=$'\e[0m'
    
    # Semantic Colors (for consistent meaning across scripts)
    COLOR_SUCCESS="${COLOR_GREEN}"
    COLOR_ERROR="${COLOR_RED}"
    COLOR_WARNING="${COLOR_YELLOW}"
    COLOR_INFO="${COLOR_CYAN}"
    COLOR_DEBUG="${COLOR_MAGENTA}"
    COLOR_HEADER="${COLOR_BOLD_CYAN}"
    COLOR_PROMPT="${COLOR_BOLD_GREEN}"
else
    # No color support - define empty variables
    COLOR_BLACK=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_WHITE=''
    COLOR_BOLD_BLACK=''
    COLOR_BOLD_RED=''
    COLOR_BOLD_GREEN=''
    COLOR_BOLD_YELLOW=''
    COLOR_BOLD_BLUE=''
    COLOR_BOLD_MAGENTA=''
    COLOR_BOLD_CYAN=''
    COLOR_BOLD_WHITE=''
    COLOR_BG_BLACK=''
    COLOR_BG_RED=''
    COLOR_BG_GREEN=''
    COLOR_BG_YELLOW=''
    COLOR_BG_BLUE=''
    COLOR_BG_MAGENTA=''
    COLOR_BG_CYAN=''
    COLOR_BG_WHITE=''
    COLOR_BOLD=''
    COLOR_DIM=''
    COLOR_ITALIC=''
    COLOR_UNDERLINE=''
    COLOR_BLINK=''
    COLOR_REVERSE=''
    COLOR_HIDDEN=''
    COLOR_STRIKETHROUGH=''
    COLOR_RESET=''
    COLOR_SUCCESS=''
    COLOR_ERROR=''
    COLOR_WARNING=''
    COLOR_INFO=''
    COLOR_DEBUG=''
    COLOR_HEADER=''
    COLOR_PROMPT=''
fi

# ============================================================================
# ICON DEFINITIONS (Unicode)
# ============================================================================

ICON_CHECK="✓"
ICON_CROSS="✗"
ICON_ARROW="→"
ICON_BULLET="•"
ICON_STAR="★"
ICON_WARNING="⚠"
ICON_INFO="ℹ"
ICON_GEAR="⚙"
ICON_FOLDER="📁"
ICON_FILE="📄"
ICON_DOWNLOAD="⬇"
ICON_UPLOAD="⬆"
ICON_LOCK="🔒"
ICON_UNLOCK="🔓"
ICON_CLOCK="⏱"
ICON_ROCKET="🚀"
ICON_PHONE="📱"
ICON_DISPLAY="🖥"
ICON_KEYBOARD="⌨"
ICON_MOUSE="🖱"

# ============================================================================
# EXPORT ALL VARIABLES
# ============================================================================

export COLORS_SUPPORTED
export COLOR_BLACK COLOR_RED COLOR_GREEN COLOR_YELLOW
export COLOR_BLUE COLOR_MAGENTA COLOR_CYAN COLOR_WHITE
export COLOR_BOLD_BLACK COLOR_BOLD_RED COLOR_BOLD_GREEN COLOR_BOLD_YELLOW
export COLOR_BOLD_BLUE COLOR_BOLD_MAGENTA COLOR_BOLD_CYAN COLOR_BOLD_WHITE
export COLOR_BG_BLACK COLOR_BG_RED COLOR_BG_GREEN COLOR_BG_YELLOW
export COLOR_BG_BLUE COLOR_BG_MAGENTA COLOR_BG_CYAN COLOR_BG_WHITE
export COLOR_BOLD COLOR_DIM COLOR_ITALIC COLOR_UNDERLINE
export COLOR_BLINK COLOR_REVERSE COLOR_HIDDEN COLOR_STRIKETHROUGH
export COLOR_RESET
export COLOR_SUCCESS COLOR_ERROR COLOR_WARNING COLOR_INFO
export COLOR_DEBUG COLOR_HEADER COLOR_PROMPT
export ICON_CHECK ICON_CROSS ICON_ARROW ICON_BULLET ICON_STAR
export ICON_WARNING ICON_INFO ICON_GEAR ICON_FOLDER ICON_FILE
export ICON_DOWNLOAD ICON_UPLOAD ICON_LOCK ICON_UNLOCK ICON_CLOCK
export ICON_ROCKET ICON_PHONE ICON_DISPLAY ICON_KEYBOARD ICON_MOUSE
