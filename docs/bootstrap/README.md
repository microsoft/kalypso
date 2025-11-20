# Kalypso Scheduler Bootstrap Script

The Kalypso Scheduler Bootstrap Script is a comprehensive tool that helps platform engineers quickly set up Kalypso Scheduler infrastructure.

## Overview

This script automates the setup of:
- **AKS Cluster**: Create new or use existing Azure Kubernetes Service clusters
- **Control-Plane Repository**: GitHub repository containing Kalypso configuration resources
- **GitOps Repository**: GitHub repository watched by GitOps operators on Kubernetes clusters
- **Kalypso Scheduler**: Installation and verification of the Kalypso Scheduler operator

## Quick Start

### Prerequisites

Before running the bootstrap script, ensure you have:

1. **Required Tools**:
   - `kubectl` (>= 1.20.0)
   - `az` (Azure CLI >= 2.30.0)
   - `git` (>= 2.0.0)
   - `helm` (>= 3.0.0)

2. **Optional Tools** (recommended):
   - `jq` (>= 1.6) - for JSON processing
   - `yq` (>= 4.0) - for YAML processing
   - `python3` (>= 3.6) - enhanced JSON parsing

3. **Authentication**:
   - Azure account with permissions to create AKS clusters
   - GitHub personal access token with `repo`, `workflow`, and `admin:org` scopes

For detailed installation instructions, see [prerequisites.md](prerequisites.md).

### Running the Script

#### Interactive Mode (Recommended)

The easiest way to get started:

```bash
cd scripts/bootstrap
./bootstrap.sh
```

The script will guide you through all configuration options interactively.

#### Non-Interactive Mode

For automation or CI/CD pipelines:

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export GITHUB_TOKEN="your-github-token"

./bootstrap.sh \
  --create-cluster \
  --cluster-name my-kalypso-cluster \
  --resource-group my-rg \
  --location eastus \
  --create-repos \
  --non-interactive
```

#### Using Configuration File

Create a configuration file (YAML, JSON, or ENV format):

```yaml
# kalypso-config.yaml
cluster:
  name: kalypso-cluster
  resourceGroup: kalypso-rg
  location: eastus
  nodeCount: 3
  nodeSize: Standard_DS2_v2

repositories:
  controlPlane: ""  # Leave empty to create new
  gitops: ""        # Leave empty to create new

github:
  org: ""  # Leave empty for personal account
```

Then run:

```bash
./bootstrap.sh --config kalypso-config.yaml
```

## Usage Examples

### Example 1: Create Everything New

Create a new AKS cluster and GitHub repositories:

```bash
./bootstrap.sh \
  --create-cluster \
  --cluster-name production-kalypso \
  --resource-group kalypso-prod-rg \
  --location westus2 \
  --node-count 5 \
  --node-size Standard_DS3_v2 \
  --create-repos \
  --github-org my-org \
  --non-interactive
```

### Example 2: Use Existing Cluster

Install Kalypso on an existing AKS cluster:

```bash
./bootstrap.sh \
  --use-cluster existing-cluster \
  --resource-group existing-rg \
  --create-repos \
  --non-interactive
```

### Example 3: Use Existing Repositories

Use existing control-plane and gitops repositories:

```bash
./bootstrap.sh \
  --create-cluster \
  --cluster-name my-cluster \
  --control-plane-repo https://github.com/myorg/kalypso-control-plane \
  --gitops-repo https://github.com/myorg/kalypso-gitops \
  --non-interactive
```

## Command Line Options

### General Options

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose logging
- `-q, --quiet` - Suppress non-error output
- `--config FILE` - Load configuration from FILE
- `--non-interactive` - Run without user prompts
- `--auto-rollback` - Automatically rollback on failure

### Cluster Options

- `--create-cluster` - Create a new AKS cluster
- `--use-cluster NAME` - Use existing cluster NAME
- `--cluster-name NAME` - Cluster name (default: kalypso-cluster)
- `--resource-group NAME` - Resource group (default: kalypso-rg)
- `--location LOCATION` - Azure region (default: eastus)
- `--node-count COUNT` - Number of nodes (default: 3)
- `--node-size SIZE` - VM size (default: Standard_DS2_v2)

### Repository Options

- `--create-repos` - Create new repositories
- `--control-plane-repo URL` - Use existing control-plane repo
- `--gitops-repo URL` - Use existing gitops repo
- `--github-org ORG` - GitHub organization (default: user account)

## What Gets Created

### New AKS Cluster Mode

When creating a new cluster, the script:

1. Creates Azure resource group (if it doesn't exist)
2. Creates AKS cluster with specified configuration
3. Configures kubectl credentials
4. Creates `kalypso-system` namespace
5. Validates cluster readiness

### New Repositories Mode

When creating new repositories, the script:

1. Creates `kalypso-control-plane` repository with:
   - Minimal environment structure (dev environment)
   - Placeholder cluster types, scheduling policies, and config maps
   - README with repository structure

2. Creates `kalypso-gitops` repository with:
   - GitHub Actions workflow templates
   - README with usage instructions
   - Placeholder cluster configurations

### Kalypso Installation

The script installs Kalypso using Helm with:
- Namespace: `kalypso-system`
- Release name: `kalypso-scheduler`
- Configuration pointing to your control-plane and gitops repositories

## Post-Installation

After successful bootstrap, the script displays:

- Cluster information and access instructions
- Repository URLs and configuration
- Next steps for deploying workloads
- Troubleshooting resources

### Verify Installation

Check that Kalypso is running:

```bash
kubectl get pods -n kalypso-system
kubectl get crd | grep kalypso
```

### Deploy Your First Workload

1. Clone your control-plane repository
2. Follow the quickstart guide: [quickstart.md](quickstart.md)
3. Create a WorkloadRegistration resource
4. Watch Kalypso schedule your workload

## Error Handling and Rollback

### Automatic Rollback

Use `--auto-rollback` to automatically clean up resources on failure:

```bash
./bootstrap.sh --create-cluster --create-repos --auto-rollback
```

### Automatic Cleanup

To remove all resources created by the bootstrap script:

```bash
# Interactive cleanup (with confirmation prompts)
./bootstrap.sh --cleanup

# Non-interactive cleanup
./bootstrap.sh --cleanup --non-interactive
```

This will delete:
- Kalypso Scheduler installation (Helm release)
- Namespace: kalypso-system
- AKS cluster (if created by script)
- Resource group (with confirmation)
- GitHub repositories (if created by script)

### Manual Cleanup

If needed, you can also manually clean up resources:

```bash
# Delete AKS cluster
az aks delete --resource-group kalypso-rg --name kalypso-cluster

# Delete resource group (if created by script)
az group delete --name kalypso-rg

# Delete GitHub repositories
# Via GitHub web UI or using gh CLI
```

## Configuration File Formats

### YAML Format

```yaml
cluster:
  name: kalypso-cluster
  resourceGroup: kalypso-rg
  location: eastus
  nodeCount: 3
  nodeSize: Standard_DS2_v2

repositories:
  controlPlane: https://github.com/org/control-plane
  gitops: https://github.com/org/gitops

github:
  org: my-organization
```

### JSON Format

```json
{
  "cluster": {
    "name": "kalypso-cluster",
    "resourceGroup": "kalypso-rg",
    "location": "eastus",
    "nodeCount": 3,
    "nodeSize": "Standard_DS2_v2"
  },
  "repositories": {
    "controlPlane": "https://github.com/org/control-plane",
    "gitops": "https://github.com/org/gitops"
  },
  "github": {
    "org": "my-organization"
  }
}
```

### ENV Format

```bash
CLUSTER_NAME=kalypso-cluster
RESOURCE_GROUP=kalypso-rg
LOCATION=eastus
NODE_COUNT=3
NODE_SIZE=Standard_DS2_v2
CONTROL_PLANE_REPO=https://github.com/org/control-plane
GITOPS_REPO=https://github.com/org/gitops
GITHUB_ORG=my-organization
```

## Environment Variables

The script respects the following environment variables:

- `AZURE_SUBSCRIPTION_ID` - Azure subscription to use
- `GITHUB_TOKEN` - GitHub personal access token
- `LOG_LEVEL` - Logging verbosity (0-3)
- `INTERACTIVE_MODE` - Set to "false" for non-interactive mode

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

## Support

For issues and questions:
- GitHub Issues: https://github.com/microsoft/kalypso-scheduler/issues
- Documentation: https://github.com/microsoft/kalypso-scheduler/docs

## License

This script is part of the Kalypso Scheduler project and is licensed under the same terms.
