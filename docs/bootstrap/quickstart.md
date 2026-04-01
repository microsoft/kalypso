# Kalypso Bootstrap Quickstart Guide

Get up and running with Kalypso Scheduler in under 15 minutes.

## Prerequisites Check

Before starting, verify you have:

- [x] kubectl (>= 1.20.0)
- [x] Azure CLI (>= 2.30.0)
- [x] git (>= 2.0.0)
- [x] Helm (>= 3.0.0)
- [x] Azure account with subscription access
- [x] GitHub personal access token

See [prerequisites.md](prerequisites.md) for detailed installation instructions.

## Quick Setup (5 Minutes)

### 1. Authenticate

Login to Azure:

```bash
az login
az account set --subscription "your-subscription-id"
```

Set GitHub token:

```bash
export GITHUB_TOKEN="your-github-personal-access-token"
```

### 2. Run Bootstrap Script

Create everything new (interactive mode):

```bash
cd scripts/bootstrap
./bootstrap.sh
```

The script will:

1. ✓ Check prerequisites
2. ✓ Prompt for configuration
3. ✓ Create AKS cluster (~10 minutes)
4. ✓ Create GitHub repositories
5. ✓ Install Kalypso Scheduler
6. ✓ Verify installation

### 3. Verify Installation

Check that everything is running:

```bash
# Get cluster credentials (if not already done)
az aks get-credentials \
  --resource-group kalypso-rg \
  --name kalypso-cluster

# Check Kalypso pods
kubectl get pods -n kalypso-system

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# kalypso-scheduler-controller-manager-xxxxx-xxxxx    2/2     Running   0          2m

# Check CRDs
kubectl get crd | grep kalypso

# Expected output:
# deploymenttargets.scheduler.kalypso.io
# workloads.scheduler.kalypso.io
# schedulingpolicies.scheduler.kalypso.io
# ... (and more)
```

## Deploy Your First Workload

### 1. Clone Control Plane Repository

```bash
cd ~
git clone https://github.com/YOUR_USER/kalypso-control-plane
cd kalypso-control-plane
```

### 2. Create a Simple Workload

Create a file `workloads/hello-world.yaml`:

```yaml
apiVersion: scheduler.kalypso.io/v1alpha1
kind: WorkloadRegistration
metadata:
  name: helloworld
  labels:
    type: application
    why: sample
spec:
  workload:
    repo: https://github.com/YOUR_USER/hello-world-app
    branch: main
    path: ./workload
  workspace: hello-world
```

### 3. Commit and Push

```bash
git add workloads/hello-world.yaml
git commit -m "Add hello-world workload"
git push origin main
```

### 4. Check GitOps Repository

Kalypso will create a PR with the new clusters and assignments in the GitOps repository.

```bash
cd ~/kalypso-gitops
git pull origin main

# You should see new directories for cluster types and deployment targets
ls -R clusters/
```

## Common Workflows

### Using Existing AKS Cluster

```bash
./bootstrap.sh \
  --cluster-name my-existing-cluster \
  --resource-group my-existing-rg \
  --create-repos
```

### Using Existing Repositories

```bash
./bootstrap.sh \
  --create-cluster \
  --control-plane-repo https://github.com/myorg/control-plane \
  --gitops-repo https://github.com/myorg/gitops
```

### Automated Setup (CI/CD)

Create a config file `kalypso-config.yaml`:

```yaml
cluster:
  create: true
  name: kalypso-prod
  resourceGroup: kalypso-prod-rg
  location: westus2
  nodeCount: 5
  nodeSize: Standard_DS3_v2

repositories:
  create: true
  controlPlane: my-control-plane
  gitops: my-gitops

github:
  org: my-organization
```

Run non-interactively:

```bash
export AZURE_SUBSCRIPTION_ID="xxx"
export GITHUB_TOKEN="xxx"

./bootstrap.sh --config kalypso-config.yaml --non-interactive
```

## Troubleshooting

### Bootstrap fails during cluster creation

Check Azure quotas:

```bash
az vm list-usage --location eastus --output table
```

### Kalypso pods not starting

Check pod logs:

```bash
kubectl logs -n kalypso-system -l app=kalypso-scheduler
```

### Workload not being scheduled

Check Kalypso logs and scheduling policies:

```bash
kubectl logs -n kalypso-system deployment/kalypso-scheduler-controller-manager
kubectl get schedulingpolicies -n kalypso-system
```

For more troubleshooting, see [troubleshooting.md](troubleshooting.md).

## Cleanup

To remove everything created by the bootstrap script, use the automatic cleanup option:

```bash
# Automatic cleanup (interactive - will prompt for confirmation)
cd scripts/bootstrap
./bootstrap.sh --cleanup

# Non-interactive cleanup
./bootstrap.sh --cleanup --non-interactive
```

This will delete:

- Kalypso Scheduler installation (Helm release)
- Namespace: kalypso-system
- AKS cluster
- Resource group (with confirmation)
- GitHub repositories (if created by script)

## Getting Help

- **Documentation**: [README.md](README.md)
- **Issues**: <https://github.com/microsoft/kalypso/issues>
- **Discussions**: <https://github.com/microsoft/kalypso/discussions>

## Success Metrics

After completing this quickstart, you should be able to:

- [x] Bootstrap Kalypso infrastructure in under 15 minutes
- [x] Deploy a workload using WorkloadRegistration
- [x] See Kalypso schedule workloads to clusters
- [x] View generated manifests in GitOps repository
- [x] Understand the basic Kalypso workflow

Congratulations! You now have a working Kalypso Scheduler environment. 🎉
