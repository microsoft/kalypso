#!/usr/bin/env bash
# Installation functions for Kalypso Scheduler
# Handles Helm chart installation and verification

#######################################
# Install Kalypso Scheduler using Helm
# Globals:
#   CONTROL_PLANE_REPO, KALYPSO_NAMESPACE, GH_REPO_TOKEN
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
install_kalypso() {
    local namespace="${KALYPSO_NAMESPACE:-kalypso-system}"
    local release_name="kalypso-scheduler"
    
    log_info "Installing Kalypso Scheduler..." "install"
    
    # Get read-only GitHub token for Kalypso
    local gh_repo_token="${GH_REPO_TOKEN:-}"
    if [[ -z "$gh_repo_token" ]]; then
        log_info "GH_REPO_TOKEN not set, using GITHUB_TOKEN (ensure it has read-only repo permissions)" "install"
        gh_repo_token="${GITHUB_TOKEN}"
    fi
    
    if [[ -z "$gh_repo_token" ]]; then
        log_error "GitHub token required for Kalypso installation" "install"
        log_error "Set GH_REPO_TOKEN (read-only repo) or GITHUB_TOKEN" "install"
        return 1
    fi
    
    # Extract control plane repo URL from full GitHub URL
    local control_plane_url="${CONTROL_PLANE_REPO}"
    # Remove trailing .git if present
    control_plane_url="${control_plane_url%.git}"
    
    # Use Kalypso Helm chart from GitHub Pages
    local chart_repo="https://microsoft.github.io/kalypso-scheduler"
    local chart_name="kalypso-scheduler"
    
    # Add Helm repository
    log_info "Adding Kalypso Helm repository..." "install"
    if ! helm repo add kalypso "$chart_repo" 2>/dev/null; then
        log_warning "Helm repository may already exist, continuing..." "install"
    fi
    
    # Update Helm repositories (don't fail if some repos are unavailable)
    log_info "Updating Helm repositories..." "install"
    helm repo update 2>/dev/null || log_warning "Some Helm repositories failed to update, continuing..." "install"
    
    # Install or upgrade Kalypso
    log_info "Installing Helm chart from $chart_repo..." "install"
    log_info "Control Plane URL: $control_plane_url" "install"
    log_info "Control Plane Branch: main" "install"
    
    if ! helm upgrade --devel --install "$release_name" "kalypso/$chart_name" \
        --namespace "$namespace" \
        --create-namespace \
        --set controlPlaneURL="$control_plane_url" \
        --set controlPlaneBranch="main" \
        --set ghRepoToken="$gh_repo_token"; then
        log_error "Helm installation failed" "install"
        return 1
    fi
    
    log_success "Kalypso Scheduler installation initiated"
    log_info "Note: Pods may take a few minutes to become ready" "install"
    return 0
}

#######################################
# Verify Kalypso installation
# Arguments:
#   None
# Returns:
#   0 if verification passes, 1 otherwise
#######################################
verify_installation() {
    local namespace="kalypso-system"
    
    log_info "Verifying Kalypso installation..." "install"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace not found" "install"
        return 1
    fi
    
    # Check if deployment exists
    local deployment_name="kalypso-scheduler-controller-manager"
    if ! kubectl get deployment "$deployment_name" -n "$namespace" &> /dev/null; then
        log_warning "Deployment $deployment_name not found" "install"
        return 1
    fi
    
    # Check if pods are running
    local ready_replicas
    ready_replicas=$(kubectl get deployment "$deployment_name" -n "$namespace" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    
    if [[ "$ready_replicas" -lt 1 ]]; then
        log_warning "No ready replicas for $deployment_name" "install"
        return 1
    fi
    
    log_success "Kalypso Scheduler is running ($ready_replicas replicas ready)"
    
    # Check CRDs
    log_info "Checking CRDs..." "install"
    local crds_found=0
    local expected_crds=(
        "workloads.scheduler.kalypso.io"
        "deploymenttargets.scheduler.kalypso.io"
        "schedulingpolicies.scheduler.kalypso.io"
    )
    
    for crd in "${expected_crds[@]}"; do
        if kubectl get crd "$crd" &> /dev/null; then
            log_success "CRD found: $crd"
            crds_found=$((crds_found + 1))
        else
            log_warning "CRD not found: $crd" "install"
        fi
    done
    
    if [[ $crds_found -eq 0 ]]; then
        log_error "No Kalypso CRDs found" "install"
        return 1
    fi
    
    return 0
}

#######################################
# Rollback Kalypso installation
# Arguments:
#   None
# Returns:
#   None
#######################################
rollback_kalypso() {
    local namespace="kalypso-system"
    local release_name="kalypso-scheduler"
    
    log_warning "Rolling back Kalypso installation..." "install"
    
    # Uninstall Helm release
    if helm list -n "$namespace" | grep -q "$release_name"; then
        log_info "Uninstalling Helm release: $release_name" "install"
        helm uninstall "$release_name" -n "$namespace" || true
    fi
    
    # Delete namespace
    if kubectl get namespace "$namespace" &> /dev/null; then
        log_info "Deleting namespace: $namespace" "install"
        kubectl delete namespace "$namespace" --timeout=60s || true
    fi
}

#######################################
# Main rollback function for all resources
# Globals:
#   CREATED_RESOURCES
# Arguments:
#   None
# Returns:
#   None
#######################################
rollback_resources() {
    log_warning "Starting rollback of created resources..." "rollback"
    
    # Rollback in reverse order: install -> repos -> cluster
    rollback_kalypso
    
    if declare -f rollback_repositories &> /dev/null; then
        rollback_repositories
    fi
    
    if declare -f rollback_cluster &> /dev/null; then
        rollback_cluster
    fi
    
    log_info "Rollback completed" "rollback"
}

# Export functions
export -f install_kalypso verify_installation rollback_kalypso rollback_resources
