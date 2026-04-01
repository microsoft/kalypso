#!/usr/bin/env bash
# Cluster operations for Kalypso bootstrapping script
# Handles AKS cluster creation, validation, and configuration

#######################################
# Create a new AKS cluster
# Globals:
#   CLUSTER_NAME, RESOURCE_GROUP, LOCATION, NODE_COUNT, NODE_SIZE
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
create_aks_cluster() {
    log_info "Creating AKS cluster: $CLUSTER_NAME" "cluster"
    
    # Check if resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Creating resource group: $RESOURCE_GROUP" "cluster"
        if ! az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --output none; then
            log_error "Failed to create resource group" "cluster"
            return 1
        fi
        track_created_resource "resource-group:$RESOURCE_GROUP"
    else
        log_info "Resource group already exists: $RESOURCE_GROUP" "cluster"
    fi
    
    # Check if cluster already exists
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" &> /dev/null; then
        log_warning "Cluster already exists: $CLUSTER_NAME" "cluster"
        log_info "Skipping cluster creation (idempotent)" "cluster"
        return 0
    fi
    
    # Create AKS cluster
    log_info "Creating cluster with $NODE_COUNT nodes of size $NODE_SIZE..." "cluster"
    log_info "This may take several minutes..." "cluster"
    
    if ! az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --node-count "$NODE_COUNT" \
        --node-vm-size "$NODE_SIZE" \
        --enable-managed-identity \
        --generate-ssh-keys \
        --output none; then
        log_error "Failed to create AKS cluster" "cluster"
        return 1
    fi
    
    track_created_resource "aks-cluster:$RESOURCE_GROUP/$CLUSTER_NAME"
    log_success "AKS cluster created successfully"
    
    return 0
}

#######################################
# Validate existing AKS cluster
# Globals:
#   CLUSTER_NAME, RESOURCE_GROUP
# Arguments:
#   None
# Returns:
#   0 if cluster exists and is accessible, 1 otherwise
#######################################
validate_existing_cluster() {
    log_info "Validating existing cluster: $CLUSTER_NAME" "cluster"
    
    # Check if cluster exists
    if ! az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --output none 2>/dev/null; then
        log_error "Cluster not found: $CLUSTER_NAME in resource group $RESOURCE_GROUP" "cluster"
        return 1
    fi
    
    # Check cluster state
    local provisioning_state
    provisioning_state=$(az aks show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --query provisioningState \
        --output tsv 2>/dev/null)
    
    if [[ "$provisioning_state" != "Succeeded" ]]; then
        log_error "Cluster is not in Succeeded state: $provisioning_state" "cluster"
        return 1
    fi
    
    log_success "Cluster validated successfully"
    return 0
}

#######################################
# Get credentials for AKS cluster
# Globals:
#   CLUSTER_NAME, RESOURCE_GROUP
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
get_cluster_credentials() {
    log_info "Getting cluster credentials..." "cluster"
    
    if ! az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --overwrite-existing \
        --output none; then
        log_error "Failed to get cluster credentials" "cluster"
        return 1
    fi
    
    log_success "Cluster credentials configured"
    return 0
}

#######################################
# Check if cluster is ready
# Arguments:
#   None
# Returns:
#   0 if ready, 1 otherwise
#######################################
check_cluster_ready() {
    log_info "Checking cluster readiness..." "cluster"
    
    # Check if kubectl can connect
    if ! kubectl cluster-info &> /dev/null; then
        log_debug "kubectl cluster-info failed" "cluster"
        return 1
    fi
    
    # Check if nodes are ready
    local not_ready_nodes
    not_ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || echo "0")
    not_ready_nodes=$(echo "$not_ready_nodes" | tr -d '[:space:]')
    
    if [[ "$not_ready_nodes" -gt 0 ]]; then
        log_debug "$not_ready_nodes nodes are not ready" "cluster"
        return 1
    fi
    
    # Check if system pods are running
    local pending_pods
    pending_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -cE "Pending|ContainerCreating" || echo "0")
    pending_pods=$(echo "$pending_pods" | tr -d '[:space:]')
    
    if [[ "$pending_pods" -gt 0 ]]; then
        log_debug "$pending_pods system pods are still starting" "cluster"
        return 1
    fi
    
    return 0
}

#######################################
# Wait for cluster to be ready
# Arguments:
#   None
# Returns:
#   0 on success, 1 on timeout
#######################################
wait_for_cluster_ready() {
    log_info "Waiting for cluster to be ready..." "cluster"
    
    if wait_for_condition 300 10 check_cluster_ready; then
        log_success "Cluster is ready"
        return 0
    else
        log_error "Cluster failed to become ready" "cluster"
        return 1
    fi
}

#######################################
# Validate cluster has required resources
# Arguments:
#   None
# Returns:
#   0 if cluster meets requirements, 1 otherwise
#######################################
validate_cluster_resources() {
    log_info "Validating cluster resources..." "cluster"
    
    # Check number of nodes
    local node_count
    node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
    
    if [[ "$node_count" -lt 1 ]]; then
        log_error "Cluster has no nodes" "cluster"
        return 1
    fi
    
    log_info "Cluster has $node_count node(s)" "cluster"
    
    # Check node resources (CPU and memory)
    local total_cpu total_memory
    total_cpu=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.cpu}' 2>/dev/null | awk '{s=0; for(i=1;i<=NF;i++)s+=$i; print s}')
    total_memory=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.memory}' 2>/dev/null | head -1)
    
    log_info "Total CPU: ${total_cpu:-unknown} cores" "cluster"
    log_info "Total memory: ${total_memory:-unknown}" "cluster"
    
    # Minimum requirements: 2 CPU cores and 4Gi memory
    if [[ -n "$total_cpu" ]] && [[ "$total_cpu" -lt 2 ]]; then
        log_warning "Cluster has less than 2 CPU cores. Kalypso may not run properly." "cluster"
    fi
    
    return 0
}

#######################################
# Create namespace for Kalypso
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
create_kalypso_namespace() {
    local namespace="kalypso-system"
    
    log_info "Creating namespace: $namespace" "cluster"
    
    if kubectl get namespace "$namespace" &> /dev/null; then
        log_info "Namespace already exists: $namespace" "cluster"
        return 0
    fi
    
    if ! kubectl create namespace "$namespace"; then
        log_error "Failed to create namespace: $namespace" "cluster"
        return 1
    fi
    
    log_success "Namespace created: $namespace"
    return 0
}

#######################################
# Install Flux on the cluster
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
install_flux() {
    log_info "Installing Flux..." "cluster"
    
    # Check if Flux is already installed on the cluster
    if kubectl get namespace flux-system &> /dev/null; then
        log_info "Flux already installed on cluster" "cluster"
        return 0
    fi
    
    # Install Flux using the official installer
    log_info "Downloading and installing Flux..." "cluster"
    if ! kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml; then
        log_error "Failed to install Flux" "cluster"
        return 1
    fi
    
    log_success "Flux installed on cluster"
    return 0
}

#######################################
# Setup cluster (create or validate existing)
# Globals:
#   CREATE_CLUSTER
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
setup_cluster() {
    if [[ "$CREATE_CLUSTER" == "true" ]]; then
        # Create new cluster
        if ! create_aks_cluster; then
            return 1
        fi
    else
        # Validate existing cluster
        if ! validate_existing_cluster; then
            return 1
        fi
    fi
    
    # Get cluster credentials
    if ! get_cluster_credentials; then
        return 1
    fi
    
    # Wait for cluster to be ready
    if ! wait_for_cluster_ready; then
        return 1
    fi
    
    # Validate cluster resources
    if ! validate_cluster_resources; then
        log_warning "Cluster resource validation had warnings" "cluster"
    fi
    
    # Install Flux
    if ! install_flux; then
        return 1
    fi
    
    # Create Kalypso namespace
    if ! create_kalypso_namespace; then
        return 1
    fi
    
    return 0
}

#######################################
# Rollback cluster creation
# Globals:
#   CREATED_RESOURCES
# Arguments:
#   None
# Returns:
#   None
#######################################
rollback_cluster() {
    log_warning "Rolling back cluster resources..." "cluster"
    
    for resource in "${CREATED_RESOURCES[@]}"; do
        if [[ "$resource" == aks-cluster:* ]]; then
            local rg_cluster="${resource#aks-cluster:}"
            local rg="${rg_cluster%/*}"
            local cluster="${rg_cluster#*/}"
            
            log_info "Deleting AKS cluster: $cluster" "cluster"
            az aks delete --resource-group "$rg" --name "$cluster" --yes --no-wait || true
        elif [[ "$resource" == resource-group:* ]]; then
            local rg="${resource#resource-group:}"
            
            log_info "Deleting resource group: $rg" "cluster"
            az group delete --name "$rg" --yes --no-wait || true
        fi
    done
}

# Export functions
export -f create_aks_cluster validate_existing_cluster get_cluster_credentials
export -f check_cluster_ready wait_for_cluster_ready validate_cluster_resources
export -f create_kalypso_namespace install_flux setup_cluster rollback_cluster
