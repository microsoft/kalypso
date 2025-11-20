# Prerequisites for Kalypso Bootstrap Script

This document outlines the prerequisites needed to run the Kalypso Scheduler bootstrap script.

## Operating System

The bootstrap script supports:
- **macOS** (10.15 Catalina or later)
- **Linux** (Ubuntu 18.04+, RHEL/CentOS 7+, or equivalent)

Windows users should use WSL2 (Windows Subsystem for Linux).

## Required Tools

### kubectl

Kubernetes command-line tool for cluster management.

**Minimum Version**: 1.20.0

**Installation**:

macOS:
```bash
brew install kubectl
```

Linux:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Verify**:
```bash
kubectl version --client
```

### Azure CLI (az)

Command-line interface for managing Azure resources.

**Minimum Version**: 2.30.0

**Installation**:

macOS:
```bash
brew install azure-cli
```

Linux:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Verify**:
```bash
az version
```

### git

Version control system for repository management.

**Minimum Version**: 2.0.0

**Installation**:

macOS:
```bash
brew install git
```

Ubuntu/Debian:
```bash
sudo apt-get install git
```

RHEL/CentOS:
```bash
sudo yum install git
```

**Verify**:
```bash
git --version
```

### Helm

Kubernetes package manager for installing Kalypso.

**Minimum Version**: 3.0.0

**Installation**:

macOS:
```bash
brew install helm
```

Linux:
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Verify**:
```bash
helm version
```

## Optional Tools (Recommended)

### jq

Command-line JSON processor for enhanced configuration handling.

**Minimum Version**: 1.6

**Installation**:

macOS:
```bash
brew install jq
```

Ubuntu/Debian:
```bash
sudo apt-get install jq
```

RHEL/CentOS:
```bash
sudo yum install jq
```

### yq

Command-line YAML processor for configuration files.

**Minimum Version**: 4.0

**Installation**:

macOS:
```bash
brew install yq
```

Linux:
```bash
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```

## Azure Prerequisites

### Azure Account

You need an Azure account with:
- Active subscription
- Permissions to create resource groups
- Permissions to create AKS clusters
- Permissions to assign roles (for AKS managed identity)

### Azure Authentication

Before running the script, authenticate with Azure:

```bash
az login
```

For non-interactive scenarios (CI/CD), use service principal:

```bash
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

### Azure Subscription

Set your default subscription:

```bash
az account set --subscription "your-subscription-id"
```

Or provide it via environment variable:

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
```

## GitHub Prerequisites

### GitHub Account

You need a GitHub account with:
- Permissions to create repositories (in your account or organization)
- Repository admin access for existing repositories
- Organization admin access (if using `--github-org`)

### GitHub Personal Access Token

Create a personal access token with these scopes:
- `repo` - Full control of private repositories
- `workflow` - Update GitHub Action workflows
- `admin:org` - Full control of organizations (if creating in an org)

**To create a token**:
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Generate new token"
3. Select required scopes
4. Generate and copy the token

**Provide the token to the script**:

```bash
export GITHUB_TOKEN="your-github-token"
```

Or the script will prompt you interactively.

## Resource Requirements

### For New AKS Cluster

**Minimum**:
- 2 CPU cores
- 4 GiB memory per node
- 3 nodes (default)

**Recommended**:
- 4 CPU cores
- 8 GiB memory per node
- 3-5 nodes

**Default Configuration**:
- VM Size: Standard_DS2_v2 (2 vCPUs, 7 GiB memory)
- Node Count: 3
- Total: 6 vCPUs, 21 GiB memory

### Azure Quotas

Ensure your subscription has sufficient quota for:
- Compute cores (Standard DSv2 Family or your chosen VM family)
- Public IP addresses
- Load balancers
- Virtual networks

Check quotas:
```bash
az vm list-usage --location eastus --output table
```

## Network Requirements

The bootstrap script needs internet access to:
- Azure APIs (`*.azure.com`)
- GitHub APIs (`api.github.com`, `github.com`)
- Kubernetes APIs (`dl.k8s.io`)
- Helm repositories
- Docker registries (for Kalypso images)

## Validation Script

Run this script to check if all prerequisites are met:

```bash
cd scripts/bootstrap
./bootstrap.sh --help
```

The bootstrap script includes built-in prerequisite checking that will:
- Verify all required tools are installed
- Check tool versions meet minimum requirements
- Validate Azure authentication
- Validate GitHub authentication
- Display missing tools with installation instructions

## Troubleshooting Prerequisites

### kubectl not found

Ensure kubectl is in your PATH:
```bash
export PATH=$PATH:/usr/local/bin
```

### Azure CLI login fails

Clear cached credentials:
```bash
az account clear
az login
```

### GitHub token invalid

Verify your token has correct scopes and hasn't expired:
```bash
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

### Insufficient Azure permissions

Contact your Azure administrator to grant:
- Contributor role on the subscription or resource group
- User Access Administrator role (for AKS managed identity)

## Next Steps

Once all prerequisites are satisfied, proceed to:
- [README.md](README.md) - Main documentation and usage
- [quickstart.md](quickstart.md) - Quick start guide
