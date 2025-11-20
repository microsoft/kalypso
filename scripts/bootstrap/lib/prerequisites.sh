#!/usr/bin/env bash
# Prerequisites validation for Kalypso bootstrapping script
# Checks for required tools and validates authentication

# Required tools with their version requirements (Bash 3.2 compatible)
# Format: "tool:version tool:version ..."
REQUIRED_TOOLS="kubectl:1.20.0 az:2.30.0 git:2.0.0 helm:3.0.0 gh:2.0.0"

# Optional tools that improve functionality
OPTIONAL_TOOLS="jq:1.6 yq:4.0"

#######################################
# Get version requirement for a tool
# Arguments:
#   $1 - Tool name
#   $2 - Tools list string
# Returns:
#   Version string or empty
#######################################
get_tool_version() {
    local tool="$1"
    local tools_list="$2"
    
    for entry in $tools_list; do
        local name="${entry%:*}"
        local version="${entry#*:}"
        if [[ "$name" == "$tool" ]]; then
            echo "$version"
            return 0
        fi
    done
    echo ""
}

#######################################
# Check if a tool is installed and meets version requirements
# Arguments:
#   $1 - Tool name
#   $2 - Minimum version (optional)
# Returns:
#   0 if tool exists and meets version, 1 otherwise
#######################################
check_tool() {
    local tool="$1"
    local min_version="${2:-}"
    
    if ! command_exists "$tool"; then
        log_debug "Tool not found: $tool" "prereq"
        return 1
    fi
    
    # If no version requirement, just check existence
    if [[ -z "$min_version" ]]; then
        return 0
    fi
    
    # Get tool version (this is tool-specific)
    local version
    case "$tool" in
        kubectl)
            version=$(kubectl version --client -o json 2>/dev/null | json_get_value "clientVersion.gitVersion" | sed 's/^v//')
            ;;
        az)
            version=$(az version -o json 2>/dev/null | json_get_value "azure-cli" || az version 2>/dev/null | sed -n 's/.*azure-cli[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)
            ;;
        git)
            version=$(git --version 2>/dev/null | sed 's/git version //g' | awk '{print $1}')
            ;;
        helm)
            version=$(helm version --short 2>/dev/null | sed 's/v//g' | awk -F'+' '{print $1}')
            ;;
        jq)
            version=$(jq --version 2>/dev/null | sed 's/jq-//g')
            ;;
        yq)
            version=$(yq --version 2>/dev/null | awk '{print $NF}')
            ;;
        *)
            log_debug "Unknown tool for version check: $tool" "prereq"
            return 0
            ;;
    esac
    
    if [[ -z "$version" ]]; then
        log_warning "Could not determine version for $tool" "prereq"
        return 0  # Assume OK if we can't check version
    fi
    
    # Simple version comparison (works for semver)
    if version_compare "$version" "$min_version"; then
        return 0
    else
        log_debug "Tool $tool version $version is older than required $min_version" "prereq"
        return 1
    fi
}

#######################################
# Compare two version strings
# Arguments:
#   $1 - Current version
#   $2 - Required version
# Returns:
#   0 if current >= required, 1 otherwise
#######################################
version_compare() {
    local current="$1"
    local required="$2"
    
    # Simple comparison: split by . and compare each part
    IFS='.' read -ra current_parts <<< "$current"
    IFS='.' read -ra required_parts <<< "$required"
    
    local max_parts=${#current_parts[@]}
    if [[ ${#required_parts[@]} -gt $max_parts ]]; then
        max_parts=${#required_parts[@]}
    fi
    
    for ((i=0; i<max_parts; i++)); do
        local current_part=${current_parts[i]:-0}
        local required_part=${required_parts[i]:-0}
        
        # Remove non-numeric suffixes
        current_part=$(echo "$current_part" | sed 's/[^0-9].*$//')
        required_part=$(echo "$required_part" | sed 's/[^0-9].*$//')
        
        if [[ $current_part -gt $required_part ]]; then
            return 0
        elif [[ $current_part -lt $required_part ]]; then
            return 1
        fi
    done
    
    return 0  # Equal versions
}

#######################################
# Check all required tools
# Globals:
#   REQUIRED_TOOLS
# Arguments:
#   None
# Returns:
#   0 if all tools are present, 1 otherwise
#######################################
check_required_tools() {
    local all_ok=true
    
    log_info "Checking required tools..." "prereq"
    
    for entry in $REQUIRED_TOOLS; do
        local tool="${entry%:*}"
        local min_version="${entry#*:}"
        
        if check_tool "$tool" "$min_version"; then
            log_success "$tool is installed"
        else
            log_error "$tool is not installed or version is too old (required: $min_version)" "prereq"
            all_ok=false
        fi
    done
    
    if [[ "$all_ok" == "false" ]]; then
        return 1
    fi
    
    return 0
}

#######################################
# Check optional tools
# Globals:
#   OPTIONAL_TOOLS
# Arguments:
#   None
# Returns:
#   None (always succeeds, just warns)
#######################################
check_optional_tools() {
    log_info "Checking optional tools..." "prereq"
    
    for entry in $OPTIONAL_TOOLS; do
        local tool="${entry%:*}"
        if check_tool "$tool"; then
            log_success "$tool is installed (optional)"
        else
            log_warning "$tool is not installed (optional, but recommended)" "prereq"
        fi
    done
}

#######################################
# Display installation instructions for missing tools
# Arguments:
#   None
# Returns:
#   None
#######################################
show_installation_instructions() {
    cat <<EOF

INSTALLATION INSTRUCTIONS:

kubectl:
  macOS:  brew install kubectl
  Linux:  curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

Azure CLI (az):
  macOS:  brew install azure-cli
  Linux:  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

git:
  macOS:  brew install git
  Linux:  sudo apt-get install git (Debian/Ubuntu) or sudo yum install git (RHEL/CentOS)

Helm:
  macOS:  brew install helm
  Linux:  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

jq (optional):
  macOS:  brew install jq
  Linux:  sudo apt-get install jq (Debian/Ubuntu) or sudo yum install jq (RHEL/CentOS)

For more details, see: docs/bootstrap/prerequisites.md

EOF
}

#######################################
# Validate Azure authentication
# Globals:
#   AZURE_SUBSCRIPTION_ID
# Arguments:
#   None
# Returns:
#   0 if authenticated, 1 otherwise
#######################################
validate_azure_auth() {
    log_info "Validating Azure authentication..." "prereq"
    
    # Check if already logged in
    if ! az account show &> /dev/null; then
        log_warning "Not logged in to Azure" "prereq"
        
        if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
            log_info "Please log in to Azure..." "prereq"
            if ! az login; then
                log_error "Azure login failed" "prereq"
                return 1
            fi
        else
            log_error "Azure authentication required. Please run 'az login' first." "prereq"
            return 1
        fi
    fi
    
    # Check subscription
    local current_sub
    current_sub=$(az account show --query id -o tsv 2>/dev/null)
    
    if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        if [[ "$current_sub" != "$AZURE_SUBSCRIPTION_ID" ]]; then
            log_info "Setting Azure subscription to: $AZURE_SUBSCRIPTION_ID" "prereq"
            if ! az account set --subscription "$AZURE_SUBSCRIPTION_ID"; then
                log_error "Failed to set Azure subscription" "prereq"
                return 1
            fi
        fi
    else
        log_info "Using current Azure subscription: $current_sub" "prereq"
        export AZURE_SUBSCRIPTION_ID="$current_sub"
    fi
    
    log_success "Azure authentication validated"
    return 0
}

#######################################
# Validate GitHub authentication
# Globals:
#   GITHUB_TOKEN
# Arguments:
#   None
# Returns:
#   0 if authenticated, 1 otherwise
#######################################
validate_github_auth() {
    log_info "Validating GitHub authentication..." "prereq"
    
    # Check for GitHub token
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
            log_warning "GitHub token not found in environment" "prereq"
            
            if ! prompt_input "Enter GitHub personal access token" "GITHUB_TOKEN" "" ".*"; then
                log_error "GitHub token is required" "prereq"
                return 1
            fi
            
            export GITHUB_TOKEN
        else
            log_error "GITHUB_TOKEN environment variable is required" "prereq"
            log_error "Create a token at: https://github.com/settings/tokens" "prereq"
            log_error "Required scopes: repo, workflow, admin:org" "prereq"
            return 1
        fi
    fi
    
    # Validate token by making an API call
    log_debug "Testing GitHub token..." "prereq"
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user)
    
    if [[ -z "$response" ]] || echo "$response" | grep -q "Bad credentials"; then
        log_error "Invalid GitHub token" "prereq"
        return 1
    fi
    
    # Get username
    local github_user
    github_user=$(echo "$response" | json_get_value "login")
    
    if [[ -z "$github_user" ]]; then
        log_warning "Could not determine GitHub username" "prereq"
    else
        log_success "GitHub authentication validated (user: $github_user)"
        export GITHUB_USER="$github_user"
    fi
    
    return 0
}

#######################################
# Validate all authentication
# Arguments:
#   None
# Returns:
#   0 if all auth valid, 1 otherwise
#######################################
validate_authentication() {
    local auth_ok=true
    
    if ! validate_azure_auth; then
        auth_ok=false
    fi
    
    if ! validate_github_auth; then
        auth_ok=false
    fi
    
    if [[ "$auth_ok" == "false" ]]; then
        return 1
    fi
    
    return 0
}

#######################################
# Check all prerequisites
# Arguments:
#   None
# Returns:
#   0 if all prerequisites met, 1 otherwise
#######################################
check_all_prerequisites() {
    # Check OS support
    if ! check_os_support; then
        return 1
    fi
    
    # Check required tools
    if ! check_required_tools; then
        show_installation_instructions
        return 1
    fi
    
    # Check optional tools
    check_optional_tools
    
    log_success "All required prerequisites are satisfied"
    return 0
}

# Export functions
export -f check_tool version_compare check_required_tools check_optional_tools
export -f validate_azure_auth validate_github_auth validate_authentication
export -f check_all_prerequisites
