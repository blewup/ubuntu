#!/data/data/com.termux/files/usr/bin/bash
#
# validators.sh - Input Validation Functions
# Ubuntu 26.04 Resolute on Termux Project
#

# Prevent double-sourcing
[[ -n "${_VALIDATORS_SH_LOADED:-}" ]] && return 0
_VALIDATORS_SH_LOADED=1

# ============================================================================
# STRING VALIDATORS
# ============================================================================

# Check if string is empty
is_empty() {
    [[ -z "${1:-}" ]]
}

# Check if string is not empty
is_not_empty() {
    [[ -n "${1:-}" ]]
}

# Check if string contains only alphanumeric characters
is_alphanumeric() {
    [[ "${1:-}" =~ ^[a-zA-Z0-9]+$ ]]
}

# Check if string is a valid identifier (letters, numbers, underscore)
is_valid_identifier() {
    [[ "${1:-}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

# Check if string matches a pattern
matches_pattern() {
    local string="$1"
    local pattern="$2"
    [[ "${string}" =~ ${pattern} ]]
}

# ============================================================================
# NUMERIC VALIDATORS
# ============================================================================

# Check if value is an integer
is_integer() {
    [[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

# Check if value is a positive integer
is_positive_integer() {
    [[ "${1:-}" =~ ^[0-9]+$ ]] && [[ "${1}" -gt 0 ]]
}

# Check if value is a non-negative integer
is_non_negative_integer() {
    [[ "${1:-}" =~ ^[0-9]+$ ]]
}

# Check if value is within range
is_in_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    
    is_integer "${value}" && [[ "${value}" -ge "${min}" ]] && [[ "${value}" -le "${max}" ]]
}

# Check if value is a valid port number
is_valid_port() {
    is_in_range "${1:-}" 1 65535
}

# ============================================================================
# PATH VALIDATORS
# ============================================================================

# Check if path is absolute
is_absolute_path() {
    [[ "${1:-}" == /* ]]
}

# Check if path exists
path_exists() {
    [[ -e "${1:-}" ]]
}

# Check if path is a file
is_file() {
    [[ -f "${1:-}" ]]
}

# Check if path is a directory
is_directory() {
    [[ -d "${1:-}" ]]
}

# Check if path is readable
is_readable() {
    [[ -r "${1:-}" ]]
}

# Check if path is writable
is_writable() {
    [[ -w "${1:-}" ]]
}

# Check if path is executable
is_executable() {
    [[ -x "${1:-}" ]]
}

# Check if file is a symlink
is_symlink() {
    [[ -L "${1:-}" ]]
}

# Validate path doesn't contain dangerous characters
is_safe_path() {
    local path="$1"
    # No null bytes, no ".." traversal at start
    [[ "${path}" != *$'\0'* ]] && [[ "${path}" != ../* ]] && [[ "${path}" != */../* ]]
}

# ============================================================================
# NETWORK VALIDATORS
# ============================================================================

# Check if string is a valid IPv4 address
is_valid_ipv4() {
    local ip="$1"
    local IFS='.'
    local -a octets
    read -ra octets <<< "${ip}"
    
    [[ ${#octets[@]} -eq 4 ]] || return 1
    
    for octet in "${octets[@]}"; do
        is_non_negative_integer "${octet}" || return 1
        [[ "${octet}" -le 255 ]] || return 1
    done
    
    return 0
}

# Check if string is a valid hostname
is_valid_hostname() {
    local hostname="$1"
    [[ "${hostname}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

# Check if URL is valid (basic check)
is_valid_url() {
    local url="$1"
    [[ "${url}" =~ ^https?://[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*(/.*)?$ ]]
}

# ============================================================================
# RESOLUTION VALIDATORS
# ============================================================================

# Check if string is a valid resolution (WxH format)
is_valid_resolution() {
    local res="$1"
    [[ "${res}" =~ ^[0-9]+x[0-9]+$ ]]
}

# Parse resolution into width and height
parse_resolution() {
    local res="$1"
    local var_prefix="${2:-RES}"
    
    if is_valid_resolution "${res}"; then
        local width="${res%x*}"
        local height="${res#*x}"
        eval "${var_prefix}_WIDTH=${width}"
        eval "${var_prefix}_HEIGHT=${height}"
        return 0
    fi
    return 1
}

# ============================================================================
# VERSION VALIDATORS
# ============================================================================

# Check if string is a valid semantic version
is_valid_semver() {
    local version="$1"
    [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]
}

# Compare versions (returns 0 if v1 >= v2)
version_gte() {
    local v1="$1"
    local v2="$2"
    
    printf '%s\n%s' "${v1}" "${v2}" | sort -V | head -1 | grep -q "^${v2}$"
}

# ============================================================================
# ANDROID/TERMUX VALIDATORS
# ============================================================================

# Check if running as expected user
is_termux_user() {
    [[ "$(id -u)" -ge 10000 ]]
}

# Check Android SDK version meets minimum
android_sdk_gte() {
    local required="$1"
    local current
    current=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
    [[ "${current}" -ge "${required}" ]]
}

# Check if package is installed on Android
is_android_package_installed() {
    local package="$1"
    pm list packages 2>/dev/null | grep -q "^package:${package}$"
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

export -f is_empty is_not_empty is_alphanumeric is_valid_identifier matches_pattern
export -f is_integer is_positive_integer is_non_negative_integer is_in_range is_valid_port
export -f is_absolute_path path_exists is_file is_directory
export -f is_readable is_writable is_executable is_symlink is_safe_path
export -f is_valid_ipv4 is_valid_hostname is_valid_url
export -f is_valid_resolution parse_resolution
export -f is_valid_semver version_gte
export -f is_termux_user android_sdk_gte is_android_package_installed
