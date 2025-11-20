#!/usr/bin/env bash
# Configuration management for Kalypso bootstrapping script
# Handles CLI argument parsing, config file loading, and validation

# Default configuration values
DEFAULT_CLUSTER_NAME="kalypso-cluster"
DEFAULT_RESOURCE_GROUP="kalypso-rg"
DEFAULT_LOCATION="westus2"
DEFAULT_NODE_COUNT="1"
DEFAULT_NODE_SIZE="Standard_DS2_v2"
DEFAULT_KALYPSO_NAMESPACE="kalypso-system"
DEFAULT_CONTROL_PLANE_REPO_NAME="kalypso-control-plane"
DEFAULT_GITOPS_REPO_NAME="kalypso-gitops"

# Configuration variables (will be set by parsing)
SHOW_HELP=false
INTERACTIVE_MODE=true
QUIET_MODE=false
VERBOSE_MODE=false
CONFIG_FILE=""
AUTO_ROLLBACK=false
CLEANUP_MODE=false

# Cluster configuration
CREATE_CLUSTER=false
CLUSTER_NAME=""
RESOURCE_GROUP=""
LOCATION=""
NODE_COUNT=""
NODE_SIZE=""
KALYPSO_NAMESPACE=""

# Repository configuration
CREATE_REPOS=false
CONTROL_PLANE_REPO=""
GITOPS_REPO=""
GITHUB_ORG=""

# Track created resources for rollback
declare -a CREATED_RESOURCES=()

#######################################
# Parse command line arguments
# Arguments:
#   $@ - Command line arguments
# Returns:
#   0 on success, 1 on error
#######################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                SHOW_HELP=true
                return 0
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --non-interactive)
                INTERACTIVE_MODE=false
                shift
                ;;
            --auto-rollback)
                AUTO_ROLLBACK=true
                shift
                ;;
            --cleanup)
                CLEANUP_MODE=true
                shift
                ;;
            --create-cluster)
                CREATE_CLUSTER=true
                shift
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            --location)
                LOCATION="$2"
                shift 2
                ;;
            --node-count)
                NODE_COUNT="$2"
                shift 2
                ;;
            --node-size)
                NODE_SIZE="$2"
                shift 2
                ;;
            --create-repos)
                CREATE_REPOS=true
                shift
                ;;
            --control-plane-repo)
                CONTROL_PLANE_REPO="$2"
                shift 2
                ;;
            --gitops-repo)
                GITOPS_REPO="$2"
                shift 2
                ;;
            --github-org)
                GITHUB_ORG="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1" "config"
                return 1
                ;;
        esac
    done
    
    return 0
}

#######################################
# Load configuration from file
# Globals:
#   CONFIG_FILE
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
load_config_file() {
    if [[ -z "$CONFIG_FILE" ]]; then
        return 0  # No config file specified
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE" "config"
        return 1
    fi
    
    log_info "Loading configuration from: $CONFIG_FILE" "config"
    
    # Try to detect file format
    local file_ext="${CONFIG_FILE##*.}"
    
    case "$file_ext" in
        yaml|yml)
            load_yaml_config "$CONFIG_FILE"
            ;;
        json)
            load_json_config "$CONFIG_FILE"
            ;;
        env|conf)
            load_env_config "$CONFIG_FILE"
            ;;
        *)
            log_error "Unsupported config file format: $file_ext" "config"
            log_error "Supported formats: yaml, yml, json, env, conf" "config"
            return 1
            ;;
    esac
}

#######################################
# Load YAML configuration file
# Arguments:
#   $1 - Config file path
# Returns:
#   0 on success, 1 on error
#######################################
load_yaml_config() {
    local config_file="$1"
    
    if ! command_exists yq; then
        log_error "yq is required to parse YAML config files" "config"
        return 1
    fi
    
    # Read values from YAML
    CLUSTER_NAME=$(yq eval '.cluster.name // ""' "$config_file")
    RESOURCE_GROUP=$(yq eval '.cluster.resourceGroup // ""' "$config_file")
    LOCATION=$(yq eval '.cluster.location // ""' "$config_file")
    NODE_COUNT=$(yq eval '.cluster.nodeCount // ""' "$config_file")
    NODE_SIZE=$(yq eval '.cluster.nodeSize // ""' "$config_file")
    
    CONTROL_PLANE_REPO=$(yq eval '.repositories.controlPlane // ""' "$config_file")
    GITOPS_REPO=$(yq eval '.repositories.gitops // ""' "$config_file")
    GITHUB_ORG=$(yq eval '.github.org // ""' "$config_file")
    
    return 0
}

#######################################
# Load JSON configuration file
# Arguments:
#   $1 - Config file path
# Returns:
#   0 on success, 1 on error
#######################################
load_json_config() {
    local config_file="$1"
    local json_content
    
    json_content=$(cat "$config_file")
    
    CLUSTER_NAME=$(json_get_value "$json_content" "cluster.name")
    RESOURCE_GROUP=$(json_get_value "$json_content" "cluster.resourceGroup")
    LOCATION=$(json_get_value "$json_content" "cluster.location")
    NODE_COUNT=$(json_get_value "$json_content" "cluster.nodeCount")
    NODE_SIZE=$(json_get_value "$json_content" "cluster.nodeSize")
    
    CONTROL_PLANE_REPO=$(json_get_value "$json_content" "repositories.controlPlane")
    GITOPS_REPO=$(json_get_value "$json_content" "repositories.gitops")
    GITHUB_ORG=$(json_get_value "$json_content" "github.org")
    
    return 0
}

#######################################
# Load environment-style configuration file
# Arguments:
#   $1 - Config file path
# Returns:
#   0 on success, 1 on error
#######################################
load_env_config() {
    local config_file="$1"
    
    # Source the file in a subshell to avoid polluting environment
    # shellcheck disable=SC1090
    source "$config_file"
    
    return 0
}

#######################################
# Prompt for missing cluster configuration
# Globals:
#   CLUSTER_NAME, RESOURCE_GROUP, etc.
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
prompt_cluster_config() {
    log_info "Cluster configuration:" "config"
    
    # Decide if creating or using existing cluster
    if [[ "$CREATE_CLUSTER" != "true" ]]; then
        if confirm "Create a new AKS cluster?" "y"; then
            CREATE_CLUSTER=true
        fi
    fi
    
    if [[ "$CREATE_CLUSTER" == "true" ]]; then
        # Prompt for new cluster details
        if is_empty "$CLUSTER_NAME"; then
            prompt_input "Cluster name" "CLUSTER_NAME" "$DEFAULT_CLUSTER_NAME" "^[a-zA-Z0-9-]+$" || return 1
        fi
        
        if is_empty "$RESOURCE_GROUP"; then
            prompt_input "Resource group" "RESOURCE_GROUP" "$DEFAULT_RESOURCE_GROUP" "^[a-zA-Z0-9-_]+$" || return 1
        fi
        
        if is_empty "$LOCATION"; then
            prompt_input "Azure location" "LOCATION" "$DEFAULT_LOCATION" "^[a-z]+$" || return 1
        fi
        
        if is_empty "$NODE_COUNT"; then
            prompt_input "Node count" "NODE_COUNT" "$DEFAULT_NODE_COUNT" "^[0-9]+$" || return 1
        fi
        
        if is_empty "$NODE_SIZE"; then
            prompt_input "Node size" "NODE_SIZE" "$DEFAULT_NODE_SIZE" ".*" || return 1
        fi
    else
        # Using existing cluster - only prompt for name and resource group
        if is_empty "$CLUSTER_NAME"; then
            prompt_input "Existing cluster name" "CLUSTER_NAME" "" "^[a-zA-Z0-9-]+$" || return 1
        fi
        
        if is_empty "$RESOURCE_GROUP"; then
            prompt_input "Resource group" "RESOURCE_GROUP" "" "^[a-zA-Z0-9-_]+$" || return 1
        fi
    fi
    
    return 0
}

#######################################
# Prompt for missing repository configuration
# Globals:
#   CONTROL_PLANE_REPO, GITOPS_REPO, etc.
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
prompt_repo_config() {
    log_info "Repository configuration:" "config"
    
    # Decide if creating or using existing repos
    if [[ "$CREATE_REPOS" != "true" ]]; then
        if is_empty "$CONTROL_PLANE_REPO"; then
            if confirm "Create new control-plane and gitops repositories?" "y"; then
                CREATE_REPOS=true
            fi
        fi
    fi
    
    if [[ "$CREATE_REPOS" == "true" ]]; then
        if is_empty "$GITHUB_ORG"; then
            prompt_input "GitHub organization (leave empty for personal account)" "GITHUB_ORG" "" "" || true
        fi
    else
        # Prompt for existing repo URLs
        if is_empty "$CONTROL_PLANE_REPO"; then
            prompt_input "Control-plane repository URL" "CONTROL_PLANE_REPO" "" ".*" || return 1
        fi
        
        if is_empty "$GITOPS_REPO"; then
            prompt_input "GitOps repository URL" "GITOPS_REPO" "" ".*" || return 1
        fi
    fi
    
    return 0
}

#######################################
# Load configuration from all sources
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
load_configuration() {
    # Load from config file if specified
    if ! load_config_file; then
        return 1
    fi
    
    # In interactive mode, prompt for missing values
    if [[ "${INTERACTIVE_MODE}" == "true" ]]; then
        if ! prompt_cluster_config; then
            return 1
        fi
        
        if ! prompt_repo_config; then
            return 1
        fi
    fi
    
    # Apply defaults for any remaining empty values
    apply_defaults
    
    return 0
}

#######################################
# Apply default values to empty configuration
# Globals:
#   All configuration variables
# Arguments:
#   None
# Returns:
#   None
#######################################
apply_defaults() {
    [[ -z "$CLUSTER_NAME" ]] && CLUSTER_NAME="$DEFAULT_CLUSTER_NAME"
    [[ -z "$RESOURCE_GROUP" ]] && RESOURCE_GROUP="$DEFAULT_RESOURCE_GROUP"
    [[ -z "$LOCATION" ]] && LOCATION="$DEFAULT_LOCATION"
    [[ -z "$NODE_COUNT" ]] && NODE_COUNT="$DEFAULT_NODE_COUNT"
    [[ -z "$NODE_SIZE" ]] && NODE_SIZE="$DEFAULT_NODE_SIZE"
    [[ -z "$KALYPSO_NAMESPACE" ]] && KALYPSO_NAMESPACE="$DEFAULT_KALYPSO_NAMESPACE"
}

#######################################
# Validate configuration
# Globals:
#   All configuration variables
# Arguments:
#   None
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_configuration() {
    local valid=true
    
    log_info "Validating configuration..." "config"
    
    # Validate cluster name
    if is_empty "$CLUSTER_NAME"; then
        log_error "Cluster name is required" "config"
        valid=false
    fi
    
    # Validate resource group
    if is_empty "$RESOURCE_GROUP"; then
        log_error "Resource group is required" "config"
        valid=false
    fi
    
    # Validate location for new clusters
    if [[ "$CREATE_CLUSTER" == "true" ]] && is_empty "$LOCATION"; then
        log_error "Location is required when creating a new cluster" "config"
        valid=false
    fi
    
    # Validate repository configuration
    if [[ "$CREATE_REPOS" != "true" ]]; then
        if is_empty "$CONTROL_PLANE_REPO"; then
            log_error "Control-plane repository is required (use --create-repos or --control-plane-repo)" "config"
            valid=false
        fi
        
        if is_empty "$GITOPS_REPO"; then
            log_error "GitOps repository is required (use --create-repos or --gitops-repo)" "config"
            valid=false
        fi
    fi
    
    if [[ "$valid" == "false" ]]; then
        return 1
    fi
    
    return 0
}

#######################################
# Display current configuration
# Globals:
#   All configuration variables
# Arguments:
#   None
# Returns:
#   None
#######################################
display_configuration() {
    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║                        CONFIGURATION SUMMARY                               ║
╚════════════════════════════════════════════════════════════════════════════╝

CLUSTER:
  Mode: $(if [[ "$CREATE_CLUSTER" == "true" ]]; then echo "Create new cluster"; else echo "Use existing cluster"; fi)
  Name: ${CLUSTER_NAME}
  Resource Group: ${RESOURCE_GROUP}
$(if [[ "$CREATE_CLUSTER" == "true" ]]; then
cat <<CLUSTER_DETAILS
  Location: ${LOCATION}
  Node Count: ${NODE_COUNT}
  Node Size: ${NODE_SIZE}
CLUSTER_DETAILS
fi)

REPOSITORIES:
  Mode: $(if [[ "$CREATE_REPOS" == "true" ]]; then echo "Create new repositories"; else echo "Use existing repositories"; fi)
$(if [[ "$CREATE_REPOS" == "true" ]]; then
cat <<REPO_DETAILS
  GitHub Org: ${GITHUB_ORG:-Personal account}
  Control Plane: Will be created as ${DEFAULT_CONTROL_PLANE_REPO_NAME}
  GitOps: Will be created as ${DEFAULT_GITOPS_REPO_NAME}
REPO_DETAILS
else
cat <<EXISTING_REPO_DETAILS
  Control Plane: ${CONTROL_PLANE_REPO}
  GitOps: ${GITOPS_REPO}
EXISTING_REPO_DETAILS
fi)

EOF
}

#######################################
# Ask user to confirm before proceeding
# Arguments:
#   None
# Returns:
#   0 if confirmed, 1 if cancelled
#######################################
confirm_proceed() {
    if ! confirm "Proceed with this configuration?" "y"; then
        return 1
    fi
    return 0
}

#######################################
# Display resources created during bootstrap
# Globals:
#   CREATED_RESOURCES
# Arguments:
#   None
# Returns:
#   None
#######################################
display_created_resources() {
    if [[ ${#CREATED_RESOURCES[@]} -eq 0 ]]; then
        log_info "No resources were created" "config"
        return
    fi
    
    echo ""
    echo "Created resources:"
    for resource in "${CREATED_RESOURCES[@]}"; do
        echo "  - $resource"
    done
    echo ""
}

#######################################
# Add a resource to the created resources list
# Globals:
#   CREATED_RESOURCES
# Arguments:
#   $1 - Resource identifier
# Returns:
#   None
#######################################
track_created_resource() {
    local resource="$1"
    CREATED_RESOURCES+=("$resource")
    log_debug "Tracking created resource: $resource" "config"
}

# Export functions
export -f parse_arguments load_configuration validate_configuration
export -f display_configuration confirm_proceed track_created_resource
