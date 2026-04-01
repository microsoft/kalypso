#!/usr/bin/env bash
# Kalypso Scheduler Bootstrapping Script
# Main entry point for bootstrapping Kalypso Scheduler infrastructure
#
# Usage: ./bootstrap.sh [OPTIONS]
#
# This script helps platform engineers set up Kalypso Scheduler by:
# - Creating or using existing AKS clusters
# - Creating or using existing control-plane repositories
# - Creating or using existing gitops repositories
# - Installing Kalypso Scheduler on the target cluster
#
# For detailed usage information, run: ./bootstrap.sh --help

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AZURE_HTTP_USER_AGENT="acce1e78-01E3-4354-9356-B033C290E069"

# Source library files
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/lib/utils.sh"

# shellcheck source=lib/prerequisites.sh
source "${SCRIPT_DIR}/lib/prerequisites.sh"

# shellcheck source=lib/config.sh
source "${SCRIPT_DIR}/lib/config.sh"

# shellcheck source=lib/cluster.sh
source "${SCRIPT_DIR}/lib/cluster.sh"

# shellcheck source=lib/repositories.sh
source "${SCRIPT_DIR}/lib/repositories.sh"

# shellcheck source=lib/install.sh
source "${SCRIPT_DIR}/lib/install.sh"

#######################################
# Display usage information
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#######################################
show_usage() {
    cat <<EOF
Kalypso Scheduler Bootstrapping Script

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Bootstrap Kalypso Scheduler infrastructure by creating or using existing:
    - AKS cluster where Kalypso Scheduler will be installed
    - Control-plane repository with configuration resources
    - GitOps repository for continuous delivery

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose logging
    -q, --quiet             Suppress non-error output
    --config FILE           Load configuration from FILE
    --non-interactive       Run in non-interactive mode (requires config file or env vars)
    --cleanup               Clean up all resources created by bootstrap script
    
CLUSTER OPTIONS:
    --create-cluster        Create a new AKS cluster (default: false, use existing)
    --cluster-name NAME     Cluster name (required)
    --resource-group NAME   Azure resource group (required)
    --location LOCATION     Azure location (default: westus2, for new clusters)
    --node-count COUNT      Number of nodes (default: 1, for new clusters)
    --node-size SIZE        VM size (default: Standard_DS2_v2, for new clusters)
    
REPOSITORY OPTIONS:
    --create-repos          Create new control-plane and gitops repositories
    --control-plane-repo NAME|URL  Repository name (when creating) or URL (when using existing)
    --gitops-repo NAME|URL  Repository name (when creating) or URL (when using existing)
    --github-org ORG        GitHub organization (default: user's account)
    
AUTHENTICATION:
    Environment variables:
        AZURE_SUBSCRIPTION_ID   Azure subscription ID
        GITHUB_TOKEN           GitHub personal access token
        
EXAMPLES:
    # Interactive mode (recommended for first-time users)
    ./$(basename "$0")
    
    # Create everything new
    ./$(basename "$0") --create-cluster --create-repos --non-interactive
    
    # Use existing cluster, create repositories
    ./$(basename "$0") --cluster-name my-cluster --resource-group my-rg --create-repos --non-interactive
    
    # Use configuration file
    ./$(basename "$0") --config bootstrap-config.yaml

For detailed documentation, see: docs/bootstrap/README.md
EOF
}

#######################################
# Cleanup all resources created by bootstrap script
# Globals:
#   CLUSTER_NAME, RESOURCE_GROUP, GITHUB_TOKEN, GITHUB_USER, GITHUB_ORG
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
cleanup_all_resources() {
    # Disable strict error handling for cleanup
    set +e
    
    log_info "=== Kalypso Scheduler Cleanup ===" "cleanup"
    log_warning "This will delete all resources created by the bootstrap script" "cleanup"
    
    # Load configuration from file if specified
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        log_info "Loading configuration from file: $CONFIG_FILE" "cleanup"
        load_config_file || log_warning "Failed to load config file, using environment variables" "cleanup"
    fi
    
    # Use environment variables if set, otherwise use defaults
    # These variables should be passed as environment variables or loaded from config file
    local cluster_name="${CLUSTER_NAME:-}"
    local resource_group="${RESOURCE_GROUP:-}"
    local github_token="${GITHUB_TOKEN:-}"
    local github_user="${GITHUB_USER:-}"
    local github_org="${GITHUB_ORG:-}"
    local control_plane_repo="${CONTROL_PLANE_REPO:-kalypso-control-plane}"
    local gitops_repo="${GITOPS_REPO:-kalypso-gitops}"
    
    # Show what will be deleted
    cat <<EOF

The following resources will be deleted:
- Kalypso Scheduler installation (Helm release)
- Namespace: kalypso-system
- AKS Cluster: ${cluster_name:-N/A}
- Resource Group: ${resource_group:-N/A}
- GitHub Repositories:
  - Control-plane: ${control_plane_repo}
  - GitOps: ${gitops_repo}

EOF
    
    # Confirm deletion
    if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
        if ! confirm "Are you sure you want to delete all these resources?" "n"; then
            log_info "Cleanup cancelled" "cleanup"
            return 0
        fi
    fi
    
    # Delete Kalypso installation
    log_step "Uninstalling Kalypso Scheduler"
    if helm list -n kalypso-system 2>/dev/null | grep -q kalypso-scheduler; then
        log_info "Uninstalling Helm release..." "cleanup"
        helm uninstall kalypso-scheduler -n kalypso-system || log_warning "Failed to uninstall Helm release" "cleanup"
    else
        log_info "Helm release not found, skipping" "cleanup"
    fi
    
    # Delete namespace
    if kubectl get namespace kalypso-system &> /dev/null; then
        log_info "Deleting namespace kalypso-system..." "cleanup"
        kubectl delete namespace kalypso-system --timeout=60s || log_warning "Failed to delete namespace" "cleanup"
    else
        log_info "Namespace not found, skipping" "cleanup"
    fi
    
    # Delete AKS cluster
    if [[ -n "${cluster_name}" ]] && [[ -n "${resource_group}" ]]; then
        log_step "Deleting AKS cluster"
        if az aks show --resource-group "$resource_group" --name "$cluster_name" &> /dev/null; then
            log_info "Deleting AKS cluster: $cluster_name..." "cleanup"
            az aks delete --resource-group "$resource_group" --name "$cluster_name" --yes --no-wait || log_warning "Failed to delete AKS cluster" "cleanup"
        else
            log_info "AKS cluster not found, skipping" "cleanup"
        fi
    fi
    
    # Delete resource group if it was created by the script
    if [[ -n "${resource_group}" ]]; then
        log_step "Deleting resource group"
        if az group show --name "$resource_group" &> /dev/null; then
            log_info "Deleting resource group: $resource_group..." "cleanup"
            log_warning "This will delete ALL resources in the resource group" "cleanup"
            if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
                if confirm "Delete resource group $resource_group?" "n"; then
                    az group delete --name "$resource_group" --yes --no-wait || log_warning "Failed to delete resource group" "cleanup"
                else
                    log_info "Skipping resource group deletion" "cleanup"
                fi
            else
                az group delete --name "$resource_group" --yes --no-wait || log_warning "Failed to delete resource group" "cleanup"
            fi
        else
            log_info "Resource group not found, skipping" "cleanup"
        fi
    fi
    
    # Delete GitHub repositories
    if [[ -n "${github_token}" ]]; then
        log_step "Deleting GitHub repositories"
        
        # Ensure github_user is set
        if [[ -z "${github_user}" ]]; then
            local user_response
            user_response=$(curl -s -H "Authorization: token $github_token" https://api.github.com/user)
            if command_exists jq; then
                github_user=$(echo "$user_response" | jq -r '.login')
            else
                github_user=$(echo "$user_response" | grep -o '"login"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            fi
        fi
        
        local owner="${github_org:-$github_user}"
        
        for repo_name in "$control_plane_repo" "$gitops_repo"; do
            local response
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                "https://api.github.com/repos/$owner/$repo_name" \
                -H "Authorization: token $github_token")
            
            if [[ "$response" == "200" ]]; then
                log_info "Deleting repository: $owner/$repo_name..." "cleanup"
                if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
                    if confirm "Delete GitHub repository $owner/$repo_name?" "n"; then
                        curl -s -X DELETE \
                            -H "Authorization: token $github_token" \
                            "https://api.github.com/repos/$owner/$repo_name" > /dev/null || log_warning "Failed to delete repository" "cleanup"
                    else
                        log_info "Skipping repository deletion" "cleanup"
                    fi
                else
                    curl -s -X DELETE \
                        -H "Authorization: token $github_token" \
                        "https://api.github.com/repos/$owner/$repo_name" > /dev/null || log_warning "Failed to delete repository" "cleanup"
                fi
            else
                log_info "Repository $repo_name not found, skipping" "cleanup"
            fi
        done
    fi
    
    log_success "Cleanup completed!"
    cat <<EOF

Note: Some resources may take time to fully delete:
- AKS cluster deletion continues in the background
- Resource group deletion continues in the background

You can check the status with:
  az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
  az group show --name $RESOURCE_GROUP

EOF
    
    # Restore strict error handling
    set -e
    return 0
}

#######################################
# Main execution flow
# Globals:
#   LOG_LEVEL
# Arguments:
#   Command line arguments
# Returns:
#   0 on success, 1 on failure
#######################################
main() {
    # Initialize logging
    init_logging
    
    log_info "=== Kalypso Scheduler Bootstrap ===" "main"
    log_info "Starting bootstrap process..." "main"
    
    # Parse command line arguments
    if ! parse_arguments "$@"; then
        log_error "Failed to parse arguments" "main"
        show_usage
        return 1
    fi
    
    # Check if help was requested
    if [[ "${SHOW_HELP:-false}" == "true" ]]; then
        show_usage
        return 0
    fi
    
    # Check if cleanup was requested
    if [[ "${CLEANUP_MODE:-false}" == "true" ]]; then
        cleanup_all_resources
        return $?
    fi
    
    # Step 1: Validate prerequisites
    log_step "Checking prerequisites"
    if ! check_all_prerequisites; then
        log_error "Prerequisites check failed" "main"
        log_error "Please install required tools and try again" "main"
        return 1
    fi
    log_success "All prerequisites satisfied"
    
    # Step 2: Load and validate configuration
    log_step "Loading configuration"
    if ! load_configuration; then
        log_error "Configuration loading failed" "main"
        return 1
    fi
    
    if ! validate_configuration; then
        log_error "Configuration validation failed" "main"
        return 1
    fi
    log_success "Configuration validated"
    
    # Step 3: Show configuration and get confirmation (if interactive)
    if [[ "${INTERACTIVE_MODE:-true}" == "true" ]]; then
        display_configuration
        if ! confirm_proceed; then
            log_info "Bootstrap cancelled by user" "main"
            return 0
        fi
    fi
    
    # Step 4: Authenticate with Azure and GitHub
    log_step "Validating authentication"
    if ! validate_authentication; then
        log_error "Authentication validation failed" "main"
        return 1
    fi
    log_success "Authentication validated"
    
    # Step 5: Cluster setup
    log_step "Setting up Kubernetes cluster"
    if ! setup_cluster; then
        log_error "Cluster setup failed" "main"
        handle_error "cluster_setup"
        return 1
    fi
    log_success "Cluster ready"
    
    # Step 6: Repository setup
    log_step "Setting up repositories"
    if ! setup_repositories; then
        log_error "Repository setup failed" "main"
        handle_error "repository_setup"
        return 1
    fi
    log_success "Repositories ready"
    
    # Step 7: Install Kalypso Scheduler
    log_step "Installing Kalypso Scheduler"
    if ! install_kalypso; then
        log_error "Kalypso installation failed" "main"
        handle_error "kalypso_install"
        return 1
    fi
    log_success "Kalypso Scheduler installed"
    
    # Step 8: Verify installation
    log_step "Verifying installation"
    if ! verify_installation; then
        log_warning "Installation verification had warnings" "main"
        log_info "Kalypso may still be starting up. Check status with: kubectl get pods -n kalypso-system" "main"
    else
        log_success "Installation verified"
    fi
    
    # Step 9: Display success message and next steps
    display_success_message
    
    log_success "Bootstrap completed successfully!"
    return 0
}

#######################################
# Handle errors and optionally trigger rollback
# Globals:
#   CREATED_RESOURCES
# Arguments:
#   $1 - Error context
# Returns:
#   None
#######################################
handle_error() {
    local context="$1"
    
    log_error "Error during: $context" "error_handler"
    
    # Check if we should attempt rollback
    if [[ "${AUTO_ROLLBACK:-false}" == "true" ]]; then
        log_warning "Attempting rollback of created resources..." "error_handler"
        rollback_resources
    else
        log_info "To clean up manually, review created resources:" "error_handler"
        display_created_resources
        log_info "Run with --auto-rollback to automatically clean up on failure" "error_handler"
    fi
}

#######################################
# Display success message and next steps
# Globals:
#   CLUSTER_NAME
#   CONTROL_PLANE_REPO
#   GITOPS_REPO
# Arguments:
#   None
# Returns:
#   None
#######################################
display_success_message() {
    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║                   KALYPSO SCHEDULER BOOTSTRAP SUCCESS                      ║
╚════════════════════════════════════════════════════════════════════════════╝

Your Kalypso Scheduler environment is ready!

CLUSTER:
  Name: ${CLUSTER_NAME:-N/A}
  Resource Group: ${RESOURCE_GROUP:-N/A}
  
REPOSITORIES:
  Control Plane: ${CONTROL_PLANE_REPO:-N/A}
  GitOps: ${GITOPS_REPO:-N/A}

NEXT STEPS:
  1. Review the generated documentation in docs/bootstrap/
  2. Configure kubectl context:
     $ az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}
  
  3. Verify Kalypso is running:
     $ kubectl get pods -n kalypso-system
  
  4. Deploy your first workload:
     - See example workloads in: ${CONTROL_PLANE_REPO:-your-control-plane-repo}
     - Follow the quickstart guide: docs/bootstrap/quickstart.md

For troubleshooting and additional configuration:
  - Documentation: docs/bootstrap/README.md
  - Support: ${SUPPORT_URL:-https://github.com/microsoft/kalypso-scheduler/issues}

EOF
}

# Run main function if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
