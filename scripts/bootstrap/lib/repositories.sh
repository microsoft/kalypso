#!/usr/bin/env bash
# Repository management for Kalypso bootstrapping script
# Handles GitHub repository creation and configuration

#######################################
# Create control-plane repository
# Globals:
#   GITHUB_TOKEN, GITHUB_ORG, GITHUB_USER, CONTROL_PLANE_REPO
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
create_control_plane_repo() {
    # Use custom repo name if provided, otherwise use default
    local repo_name="${CONTROL_PLANE_REPO:-${DEFAULT_CONTROL_PLANE_REPO_NAME}}"
    # Strip any URL prefix if accidentally included
    repo_name="${repo_name#https://github.com/*/}"
    repo_name="${repo_name#*/}"
    
    # Ensure GITHUB_USER is set
    if [[ -z "${GITHUB_USER:-}" ]]; then
        local response
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user)
        if command_exists jq; then
            GITHUB_USER=$(echo "$response" | jq -r '.login')
        else
            GITHUB_USER=$(echo "$response" | json_get_value "login")
        fi
        if [[ -z "$GITHUB_USER" ]] || [[ "$GITHUB_USER" == "null" ]]; then
            log_error "Could not determine GitHub username" "repo"
            return 1
        fi
    fi
    
    local owner="${GITHUB_ORG:-$GITHUB_USER}"
    
    log_info "Creating control-plane repository: $owner/$repo_name" "repo"
    
    # Determine if owner is an org or user
    local api_endpoint="https://api.github.com/user/repos"
    if [[ -n "$GITHUB_ORG" ]]; then
        # Check if the org exists
        local org_check
        org_check=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/orgs/$GITHUB_ORG")
        
        if echo "$org_check" | grep -q "\"login\""; then
            # It's a valid org
            api_endpoint="https://api.github.com/orgs/$GITHUB_ORG/repos"
        else
            # Not an org, treat as user
            log_warning "GitHub org '$GITHUB_ORG' not found or not accessible, creating repo under user account" "repo"
            owner="$GITHUB_USER"
            api_endpoint="https://api.github.com/user/repos"
        fi
    fi
    
    local response
    response=$(curl -s -X POST "$api_endpoint" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"name\":\"$repo_name\",\"description\":\"Kalypso control-plane configuration\",\"private\":true}")
    
    local repo_exists=false
    if echo "$response" | grep -q "\"full_name\""; then
        local repo_url
        if command_exists jq; then
            repo_url=$(echo "$response" | jq -r '.html_url')
        else
            repo_url=$(echo "$response" | json_get_value "html_url")
        fi
        CONTROL_PLANE_REPO="$repo_url"
        track_created_resource "github-repo:$owner/$repo_name"
        log_success "Control-plane repository created: $repo_url"
    elif echo "$response" | grep -q "name already exists"; then
        # Repository already exists, use it
        log_warning "Repository $owner/$repo_name already exists, using existing repository" "repo"
        CONTROL_PLANE_REPO="https://github.com/$owner/$repo_name"
        log_info "Using existing repository: $CONTROL_PLANE_REPO" "repo"
        repo_exists=true
    else
        log_error "Failed to create repository: $response" "repo"
        return 1
    fi
    
    # Initialize repository with minimal structure only if newly created
    if [[ "$repo_exists" == "false" ]]; then
        if ! initialize_control_plane_repo "$owner" "$repo_name"; then
            log_error "Failed to initialize control-plane repository" "repo"
            return 1
        fi
    else
        log_info "Skipping initialization of existing repository" "repo"
    fi
    
    return 0
}

#######################################
# Create gitops repository
# Globals:
#   GITHUB_TOKEN, GITHUB_ORG, GITHUB_USER, GITOPS_REPO
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
create_gitops_repo() {
    # Use custom repo name if provided, otherwise use default
    local repo_name="${GITOPS_REPO:-${DEFAULT_GITOPS_REPO_NAME}}"
    # Strip any URL prefix if accidentally included
    repo_name="${repo_name#https://github.com/*/}"
    repo_name="${repo_name#*/}"
    
    # Ensure GITHUB_USER is set
    if [[ -z "${GITHUB_USER:-}" ]]; then
        local response
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user)
        if command_exists jq; then
            GITHUB_USER=$(echo "$response" | jq -r '.login')
        else
            GITHUB_USER=$(echo "$response" | json_get_value "login")
        fi
        if [[ -z "$GITHUB_USER" ]] || [[ "$GITHUB_USER" == "null" ]]; then
            log_error "Could not determine GitHub username" "repo"
            return 1
        fi
    fi
    
    local owner="${GITHUB_ORG:-$GITHUB_USER}"
    
    log_info "Creating gitops repository: $owner/$repo_name" "repo"
    
    # Determine if owner is an org or user
    local api_endpoint="https://api.github.com/user/repos"
    if [[ -n "$GITHUB_ORG" ]]; then
        # Check if the org exists
        local org_check
        org_check=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/orgs/$GITHUB_ORG")
        
        if echo "$org_check" | grep -q "\"login\""; then
            # It's a valid org
            api_endpoint="https://api.github.com/orgs/$GITHUB_ORG/repos"
        else
            # Not an org, treat as user
            log_warning "GitHub org '$GITHUB_ORG' not found or not accessible, creating repo under user account" "repo"
            owner="$GITHUB_USER"
            api_endpoint="https://api.github.com/user/repos"
        fi
    fi
    
    local response
    response=$(curl -s -X POST "$api_endpoint" \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "{\"name\":\"$repo_name\",\"description\":\"Kalypso GitOps repository\",\"private\":true}")
    
    local repo_exists=false
    if echo "$response" | grep -q "\"full_name\""; then
        local repo_url
        if command_exists jq; then
            repo_url=$(echo "$response" | jq -r '.html_url')
        else
            repo_url=$(echo "$response" | json_get_value "html_url")
        fi
        GITOPS_REPO="$repo_url"
        track_created_resource "github-repo:$owner/$repo_name"
        log_success "GitOps repository created: $repo_url"
    elif echo "$response" | grep -q "name already exists"; then
        # Repository already exists, use it
        log_warning "Repository $owner/$repo_name already exists, using existing repository" "repo"
        GITOPS_REPO="https://github.com/$owner/$repo_name"
        log_info "Using existing repository: $GITOPS_REPO" "repo"
        repo_exists=true
    else
        log_error "Failed to create repository: $response" "repo"
        return 1
    fi
    
    # Initialize repository with minimal structure only if newly created
    if [[ "$repo_exists" == "false" ]]; then
        if ! initialize_gitops_repo "$owner" "$repo_name"; then
            log_error "Failed to initialize gitops repository" "repo"
            return 1
        fi
    else
        log_info "Skipping initialization of existing repository" "repo"
    fi
    
    return 0
}

#######################################
# Initialize control-plane repository with minimal structure
# Arguments:
#   $1 - Repository owner
#   $2 - Repository name
# Returns:
#   0 on success, 1 on error
#######################################
initialize_control_plane_repo() {
    local owner="$1"
    local repo_name="$2"
    local temp_dir
    
    temp_dir=$(mktemp -d)
    trap 'rm -rf "'"$temp_dir"'"' RETURN
    
    log_info "Initializing control-plane repository structure..." "repo"
    
    cd "$temp_dir" || return 1
    
    # Initialize git repo
    git init &> /dev/null
    git config user.name "Kalypso Bootstrap" &> /dev/null
    git config user.email "bootstrap@kalypso.local" &> /dev/null
    
    # T033: Populate main branch from templates
    # SCRIPT_DIR is set in bootstrap.sh and points to scripts/bootstrap
    local templates_dir="${SCRIPT_DIR}/templates"
    local main_templates="${templates_dir}/control-plane/main"
    
    # Copy .environments
    if [[ -d "${main_templates}/.environments" ]]; then
        cp -r "${main_templates}/.environments" .
    fi
    
    # Copy .github/workflows
    if [[ -d "${main_templates}/.github/workflows" ]]; then
        mkdir -p .github
        cp -r "${main_templates}/.github/workflows" .github/
    fi
    
    # Copy templates
    if [[ -d "${main_templates}/templates" ]]; then
        cp -r "${main_templates}/templates" .
    fi
    
    # Copy workloads
    if [[ -d "${main_templates}/workloads" ]]; then
        cp -r "${main_templates}/workloads" .
    fi
    
    # Create README
    cat > README.md <<EOF
# Kalypso Control Plane

This repository models the fleet using Kalypso abstractions.

Created by Kalypso bootstrapping script.

## Structure

- \`.environments/\` - Environment definitions
- \`.github/workflows/\` - CI/CD workflows (promotion flow)
- \`templates/\` - Template definitions (arc-flux, argocd, configmap, namespace)
- \`workloads/\` - Workload registrations

For more information, see: https://github.com/microsoft/kalypso-scheduler
EOF
    
    # Substitute environment variables in all YAML files
    export CLUSTER_NAME="${CLUSTER_NAME}"
    export KALYPSO_NAMESPACE="${KALYPSO_NAMESPACE}"
    export CONTROL_PLANE_REPO_URL="https://github.com/${owner}/${repo_name}"
    export GITOPS_REPO_URL="${GITOPS_REPO_URL:-https://github.com/${owner}/${DEFAULT_GITOPS_REPO_NAME}}"
    
    # Only substitute our variables, preserve GitHub Actions variables
    find . -type f \( -name "*.yaml" -o -name "*.yml" \) -exec sh -c '
        envsubst "\$CLUSTER_NAME \$KALYPSO_NAMESPACE \$CONTROL_PLANE_REPO_URL \$GITOPS_REPO_URL" < "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    ' sh {} \;
    
    # Commit main branch
    git add . &> /dev/null
    git commit -m "Add control-plane main branch structure

- Environment definitions
- CI/CD workflows  
- Templates (arc-flux, argocd, configmap, namespace)
- Sample workload registrations" &> /dev/null
    git branch -M main &> /dev/null
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${owner}/${repo_name}.git" &> /dev/null
    
    if ! git push -u origin main &> /dev/null; then
        log_error "Failed to push to control-plane repository" "repo"
        return 1
    fi
    
    # T034: Create and populate dev branch
    git checkout -b dev main &> /dev/null
    
    # Remove main branch content (keep README.md)
    find . -mindepth 1 -maxdepth 1 ! -name 'README.md' ! -name '.git' -exec rm -rf {} +
    
    # Copy environment-specific templates
    local env_templates="${templates_dir}/control-plane/dev"
    
    # Copy cluster-types
    if [[ -d "${env_templates}/cluster-types" ]]; then
        cp -r "${env_templates}/cluster-types" .
    fi
    
    # Copy configs
    if [[ -d "${env_templates}/configs" ]]; then
        cp -r "${env_templates}/configs" .
    fi
    
    # Copy scheduling-policies
    if [[ -d "${env_templates}/scheduling-policies" ]]; then
        cp -r "${env_templates}/scheduling-policies" .
    fi
    
    # Copy base-repo.yaml and gitops-repo.yaml
    [[ -f "${env_templates}/base-repo.yaml" ]] && cp "${env_templates}/base-repo.yaml" .
    [[ -f "${env_templates}/gitops-repo.yaml" ]] && cp "${env_templates}/gitops-repo.yaml" .
    
    # Substitute environment variables
    # Only substitute our variables, preserve GitHub Actions variables
    find . -type f \( -name "*.yaml" -o -name "*.yml" \) -exec sh -c '
        export ENVIRONMENT="dev"
        export CLUSTER_NAME="${CLUSTER_NAME}"
        export KALYPSO_NAMESPACE="${KALYPSO_NAMESPACE}"
        export CONTROL_PLANE_REPO_URL="${CONTROL_PLANE_REPO_URL}"
        export GITOPS_REPO_URL="${GITOPS_REPO_URL}"
        envsubst "\$ENVIRONMENT \$CLUSTER_NAME \$KALYPSO_NAMESPACE \$CONTROL_PLANE_REPO_URL \$GITOPS_REPO_URL" < "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    ' sh {} \;
    
    # Commit dev branch
    git add . &> /dev/null
    git commit -m "Add dev environment configuration

- Cluster types
- Configuration schemas
- Scheduling policies
- Base repository tracking
- GitOps repository reference" &> /dev/null
    
    if ! git push -u origin dev &> /dev/null; then
        log_error "Failed to push dev branch to control-plane repository" "repo"
        return 1
    fi
    
    # Create secrets for the control-plane repository
    log_info "Creating secrets in control-plane repository..." "repo"
    
    if command_exists gh; then
        # Create GITOPS_REPO secret (owner/repo format without https://github.com/)
        local gitops_repo_path="${GITHUB_ORG:-$GITHUB_USER}/${DEFAULT_GITOPS_REPO_NAME}"
        if ! gh secret set GITOPS_REPO --body "$gitops_repo_path" --repo "${owner}/${repo_name}" &> /dev/null; then
            log_warning "Failed to create GITOPS_REPO secret, you may need to set it manually" "repo"
        else
            log_success "GITOPS_REPO secret created"
        fi
        
        # Create GITOPS_REPO_TOKEN secret
        if ! gh secret set GITOPS_REPO_TOKEN --body "$GITHUB_TOKEN" --repo "${owner}/${repo_name}" &> /dev/null; then
            log_warning "Failed to create GITOPS_REPO_TOKEN secret, you may need to set it manually" "repo"
        else
            log_success "GITOPS_REPO_TOKEN secret created"
        fi
    else
        log_warning "GitHub CLI not available, skipping secret creation for control-plane repository" "repo"
    fi
    
    log_success "Control-plane repository initialized with main and dev branches"
    return 0
}

#######################################
# Initialize gitops repository with minimal structure
# Arguments:
#   $1 - Repository owner
#   $2 - Repository name
# Returns:
#   0 on success, 1 on error
#######################################
initialize_gitops_repo() {
    local owner="$1"
    local repo_name="$2"
    local temp_dir
    
    temp_dir=$(mktemp -d)
    trap 'rm -rf "'"$temp_dir"'"' RETURN
    
    log_info "Initializing gitops repository structure..." "repo"
    
    cd "$temp_dir" || return 1
    
    # Initialize git repo
    git init &> /dev/null
    git config user.name "Kalypso Bootstrap" &> /dev/null
    git config user.email "bootstrap@kalypso.local" &> /dev/null
    
    # T041: Populate main branch from templates
    # SCRIPT_DIR is set in bootstrap.sh and points to scripts/bootstrap
    local templates_dir="${SCRIPT_DIR}/templates"
    local main_templates="${templates_dir}/gitops/main"
    
    # Copy README from template if exists, otherwise create default
    if [[ -f "${main_templates}/README.md" ]]; then
        cp "${main_templates}/README.md" .
    else
        cat > README.md <<EOF
# Kalypso GitOps Repository

This repository contains deployment manifests generated by Kalypso Scheduler.

## Structure

Manifests are organized by:
- **ClusterType**: Type of cluster (e.g., arc-flux, argocd)
- **DeploymentTarget**: Specific deployment target within the cluster type

## Usage

This repository is managed by Kalypso. Do not manually edit files - changes will be overwritten.

Manifests are generated from:
- Workload definitions in the control-plane repository
- Templates and scheduling policies
- Cluster-specific configurations

## Branches

- \`main\`: Source of truth for promoted changes
- \`dev\`, \`staging\`, \`prod\`: Environment-specific manifests
EOF
    fi
    
    # Commit main branch
    git add . &> /dev/null
    git commit -m "Initial commit - Kalypso GitOps structure" &> /dev/null
    git branch -M main &> /dev/null
    git remote add origin "https://${GITHUB_TOKEN}@github.com/${owner}/${repo_name}.git" &> /dev/null
    
    if ! git push -u origin main &> /dev/null; then
        log_error "Failed to push to gitops repository" "repo"
        return 1
    fi
    
    # T042: Create and populate dev branch
    git checkout -b dev main &> /dev/null
    
    # Copy environment-specific templates
    local env_templates="${templates_dir}/gitops/dev"
    
    # Copy check-promote workflow if exists
    if [[ -d "${env_templates}/.github/workflows" ]]; then
        mkdir -p .github/workflows
        cp -r "${env_templates}/.github/workflows/"* .github/workflows/
    fi
    
    # Substitute environment variables in workflow files
    # CONTROL_PLANE_REPO_URL should be just owner/repo without https://github.com/ prefix
    export CONTROL_PLANE_REPO_URL="${owner}/${DEFAULT_CONTROL_PLANE_REPO_NAME}"
    
    # Only substitute CONTROL_PLANE_REPO_URL, preserve GitHub Actions variables
    find . -type f \( -name "*.yaml" -o -name "*.yml" \) -exec sh -c '
        envsubst "\$CONTROL_PLANE_REPO_URL" < "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    ' sh {} \;
    
    # Commit dev branch
    git add . &> /dev/null
    git commit -m "Add dev environment structure

- Check-promote workflow" &> /dev/null
    
    if ! git push -u origin dev &> /dev/null; then
        log_error "Failed to push dev branch to gitops repository" "repo"
        return 1
    fi
    
    # Create CONTROL_PLANE_TOKEN secret for the GitOps repository
    log_info "Creating CONTROL_PLANE_TOKEN secret in gitops repository..." "repo"
    
    if command_exists gh; then
        if ! gh secret set CONTROL_PLANE_TOKEN --body "$GITHUB_TOKEN" --repo "${owner}/${repo_name}" &> /dev/null; then
            log_warning "Failed to create CONTROL_PLANE_TOKEN secret, you may need to set it manually" "repo"
        else
            log_success "CONTROL_PLANE_TOKEN secret created"
        fi
        
        # Create "promoted" label for PRs
        log_info "Creating 'promoted' label in gitops repository..." "repo"
        if ! gh label create promoted --description "PR has been promoted" --color "0E8A16" --repo "${owner}/${repo_name}" &> /dev/null; then
            log_warning "Failed to create 'promoted' label, it may already exist or you may need to create it manually" "repo"
        else
            log_success "'promoted' label created"
        fi
    else
        log_warning "GitHub CLI not available, skipping secret and label creation for gitops repository" "repo"
    fi
    
    log_success "GitOps repository initialized with main and dev branches"
    return 0
}

#######################################
# Validate existing control-plane repository
# Globals:
#   CONTROL_PLANE_REPO
# Arguments:
#   None
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_control_plane_repo() {
    log_info "Validating control-plane repository: $CONTROL_PLANE_REPO" "repo"
    
    # Basic validation - check if repo is accessible
    local repo_path
    repo_path="${CONTROL_PLANE_REPO#https://github.com/}"
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$repo_path")
    
    if echo "$response" | grep -q "\"full_name\""; then
        log_success "Control-plane repository validated"
        return 0
    else
        log_error "Cannot access control-plane repository" "repo"
        return 1
    fi
}

#######################################
# Validate existing gitops repository
# Globals:
#   GITOPS_REPO
# Arguments:
#   None
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_gitops_repo() {
    log_info "Validating gitops repository: $GITOPS_REPO" "repo"
    
    # Basic validation - check if repo is accessible
    local repo_path
    repo_path="${GITOPS_REPO#https://github.com/}"
    
    local response
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$repo_path")
    
    if echo "$response" | grep -q "\"full_name\""; then
        log_success "GitOps repository validated"
        return 0
    else
        log_error "Cannot access gitops repository" "repo"
        return 1
    fi
}

#######################################
# Setup repositories (create or validate existing)
# Globals:
#   CREATE_REPOS
# Arguments:
#   None
# Returns:
#   0 on success, 1 on error
#######################################
setup_repositories() {
    if [[ "$CREATE_REPOS" == "true" ]]; then
        # Create new repositories
        if ! create_control_plane_repo; then
            return 1
        fi
        
        if ! create_gitops_repo; then
            return 1
        fi
    else
        # Validate existing repositories
        if ! validate_control_plane_repo; then
            return 1
        fi
        
        if ! validate_gitops_repo; then
            return 1
        fi
    fi
    
    return 0
}

#######################################
# Rollback repository creation
# Globals:
#   CREATED_RESOURCES
# Arguments:
#   None
# Returns:
#   None
#######################################
rollback_repositories() {
    log_warning "Rolling back repository resources..." "repo"
    
    for resource in "${CREATED_RESOURCES[@]}"; do
        if [[ "$resource" == github-repo:* ]]; then
            local repo="${resource#github-repo:}"
            
            log_info "Deleting GitHub repository: $repo" "repo"
            curl -s -X DELETE "https://api.github.com/repos/$repo" \
                -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" > /dev/null || true
        fi
    done
}

# Export functions
export -f create_control_plane_repo create_gitops_repo
export -f validate_control_plane_repo validate_gitops_repo
export -f setup_repositories rollback_repositories
