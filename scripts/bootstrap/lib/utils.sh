#!/usr/bin/env bash
# Utility functions for Kalypso bootstrapping script
# Provides logging, JSON processing, and common helper functions

# Color codes for terminal output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Log levels
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

# Global log level (can be set via environment or command line)
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Step counter for progress tracking
STEP_COUNTER=0

#######################################
# Initialize logging system
# Globals:
#   LOG_LEVEL
# Arguments:
#   None
# Returns:
#   None
#######################################
init_logging() {
    # Check for quiet mode
    if [[ "${QUIET_MODE:-false}" == "true" ]]; then
        LOG_LEVEL=$LOG_LEVEL_ERROR
    fi
    
    # Check for verbose mode
    if [[ "${VERBOSE_MODE:-false}" == "true" ]]; then
        LOG_LEVEL=$LOG_LEVEL_DEBUG
    fi
}

#######################################
# Log error message
# Globals:
#   LOG_LEVEL
# Arguments:
#   $1 - Message to log
#   $2 - Component name (optional)
# Returns:
#   None
#######################################
log_error() {
    local message="$1"
    local component="${2:-}"
    
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]]; then
        local prefix="ERROR"
        if [[ -n "$component" ]]; then
            prefix="ERROR [$component]"
        fi
        echo -e "${COLOR_RED}${prefix}: ${message}${COLOR_RESET}" >&2
    fi
}

#######################################
# Log warning message
# Globals:
#   LOG_LEVEL
# Arguments:
#   $1 - Message to log
#   $2 - Component name (optional)
# Returns:
#   None
#######################################
log_warning() {
    local message="$1"
    local component="${2:-}"
    
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]]; then
        local prefix="WARNING"
        if [[ -n "$component" ]]; then
            prefix="WARNING [$component]"
        fi
        echo -e "${COLOR_YELLOW}${prefix}: ${message}${COLOR_RESET}" >&2
    fi
}

#######################################
# Log info message
# Globals:
#   LOG_LEVEL
# Arguments:
#   $1 - Message to log
#   $2 - Component name (optional)
# Returns:
#   None
#######################################
log_info() {
    local message="$1"
    local component="${2:-}"
    
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        local prefix="INFO"
        if [[ -n "$component" ]]; then
            prefix="INFO [$component]"
        fi
        echo -e "${COLOR_BLUE}${prefix}: ${message}${COLOR_RESET}"
    fi
}

#######################################
# Log debug message
# Globals:
#   LOG_LEVEL
# Arguments:
#   $1 - Message to log
#   $2 - Component name (optional)
# Returns:
#   None
#######################################
log_debug() {
    local message="$1"
    local component="${2:-}"
    
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]]; then
        local prefix="DEBUG"
        if [[ -n "$component" ]]; then
            prefix="DEBUG [$component]"
        fi
        echo -e "${COLOR_CYAN}${prefix}: ${message}${COLOR_RESET}" >&2
    fi
}

#######################################
# Log success message
# Globals:
#   None
# Arguments:
#   $1 - Message to log
# Returns:
#   None
#######################################
log_success() {
    local message="$1"
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        echo -e "${COLOR_GREEN}✓ ${message}${COLOR_RESET}"
    fi
}

#######################################
# Log step header with counter
# Globals:
#   STEP_COUNTER
# Arguments:
#   $1 - Step description
# Returns:
#   None
#######################################
log_step() {
    local description="$1"
    STEP_COUNTER=$((STEP_COUNTER + 1))
    
    if [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]]; then
        echo ""
        echo -e "${COLOR_CYAN}[Step $STEP_COUNTER] ${description}${COLOR_RESET}"
        echo "----------------------------------------"
    fi
}

#######################################
# Parse JSON value from string
# Arguments:
#   $1 - JSON string
#   $2 - Key to extract
# Returns:
#   Extracted value
#######################################
json_get_value() {
    local json="$1"
    local key="$2"
    
    # Use jq if available for robust JSON parsing
    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".$key // empty"
    else
        # Basic grep/sed fallback (not robust for complex JSON)
        echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed 's/.*"\([^"]*\)"/\1/'
    fi
}

#######################################
# Check if a value is empty or null
# Arguments:
#   $1 - Value to check
# Returns:
#   0 if empty/null, 1 otherwise
#######################################
is_empty() {
    local value="$1"
    [[ -z "$value" || "$value" == "null" || "$value" == "NULL" ]]
}

#######################################
# Trim whitespace from string
# Arguments:
#   $1 - String to trim
# Returns:
#   Trimmed string
#######################################
trim() {
    local value="$1"
    # Remove leading whitespace
    value="${value#"${value%%[![:space:]]*}"}"
    # Remove trailing whitespace
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
}

#######################################
# Convert string to lowercase
# Arguments:
#   $1 - String to convert
# Returns:
#   Lowercase string
#######################################
to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

#######################################
# Convert string to uppercase
# Arguments:
#   $1 - String to convert
# Returns:
#   Uppercase string
#######################################
to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

#######################################
# Check if command exists
# Arguments:
#   $1 - Command name
# Returns:
#   0 if command exists, 1 otherwise
#######################################
command_exists() {
    command -v "$1" &> /dev/null
}

#######################################
# Wait for condition with timeout
# Arguments:
#   $1 - Timeout in seconds
#   $2 - Check interval in seconds
#   $@ - Command to check (should return 0 when condition is met)
# Returns:
#   0 if condition met, 1 if timeout
#######################################
wait_for_condition() {
    local timeout="$1"
    local interval="$2"
    shift 2
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if "$@"; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    log_error "Timeout waiting for condition after ${timeout}s" "wait"
    return 1
}

#######################################
# Prompt user for yes/no confirmation
# Arguments:
#   $1 - Prompt message
#   $2 - Default value (y/n, optional)
# Returns:
#   0 for yes, 1 for no
#######################################
confirm() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    # In non-interactive mode, use default or return error
    if [[ "${INTERACTIVE_MODE:-true}" != "true" ]]; then
        if [[ -n "$default" ]]; then
            [[ "$default" == "y" ]] && return 0 || return 1
        else
            log_error "Confirmation required but running in non-interactive mode" "confirm"
            return 1
        fi
    fi
    
    # Show prompt with default indicator
    if [[ "$default" == "y" ]]; then
        echo -n "$prompt [Y/n]: "
    elif [[ "$default" == "n" ]]; then
        echo -n "$prompt [y/N]: "
    else
        echo -n "$prompt [y/n]: "
    fi
    
    read -r response
    response=$(to_lower "$(trim "$response")")
    
    # Handle empty response
    if [[ -z "$response" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi
    
    # Check response
    [[ "$response" == "y" || "$response" == "yes" ]] && return 0 || return 1
}

#######################################
# Prompt user for input with validation
# Arguments:
#   $1 - Prompt message
#   $2 - Variable name to store result
#   $3 - Default value (optional)
#   $4 - Validation regex (optional)
# Returns:
#   0 on success, 1 on error
#######################################
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    local validation="${4:-}"
    local response
    
    # In non-interactive mode, use default or environment variable
    if [[ "${INTERACTIVE_MODE:-true}" != "true" ]]; then
        if [[ -n "${!var_name:-}" ]]; then
            return 0
        elif [[ -n "$default" ]]; then
            eval "$var_name=\"$default\""
            return 0
        else
            log_error "Input required but running in non-interactive mode: $var_name" "prompt"
            return 1
        fi
    fi
    
    # Show prompt with default
    if [[ -n "$default" ]]; then
        echo -n "$prompt [$default]: "
    else
        echo -n "$prompt: "
    fi
    
    read -r response
    response=$(trim "$response")
    
    # Use default if empty
    if [[ -z "$response" ]]; then
        response="$default"
    fi
    
    # Validate if pattern provided
    if [[ -n "$validation" && -n "$response" ]]; then
        if [[ ! "$response" =~ $validation ]]; then
            log_error "Invalid input format" "prompt"
            return 1
        fi
    fi
    
    # Store result
    eval "$var_name=\"$response\""
    return 0
}

#######################################
# Check if running on supported OS
# Arguments:
#   None
# Returns:
#   0 if supported, 1 otherwise
#######################################
check_os_support() {
    local os_type
    os_type="$(uname -s)"
    
    case "$os_type" in
        Linux*|Darwin*)
            return 0
            ;;
        *)
            log_error "Unsupported operating system: $os_type" "os_check"
            log_error "This script supports macOS and Linux only" "os_check"
            return 1
            ;;
    esac
}

# Export functions for use in other scripts
export -f log_error log_warning log_info log_debug log_success log_step
export -f json_get_value is_empty trim to_lower to_upper
export -f command_exists wait_for_condition
export -f confirm prompt_input
