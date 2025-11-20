# Troubleshooting Kalypso Bootstrap Script

This guide helps you diagnose and resolve common issues with the Kalypso bootstrap script.

## General Debugging

### Enable Verbose Logging

Run the script with verbose output:

```bash
./bootstrap.sh --verbose
```

Or set log level:

```bash
export LOG_LEVEL=3  # DEBUG level
./bootstrap.sh
```

## Common Issues

### Issue: Script fails with "Prerequisites check failed"

**Symptoms**:

```text
ERROR [prereq]: kubectl is not installed or version is too old (required: 1.20.0)
```

**Solution**:

1. Check the missing tool in the error message
1. Install or upgrade the tool using instructions in [prerequisites.md](prerequisites.md)
1. Verify installation: `<tool> --version`

### Issue: "Azure authentication required"

**Symptoms**:

```text
ERROR [prereq]: Not logged in to Azure
ERROR [prereq]: Azure authentication required. Please run 'az login' first.
```

**Solution**:

Interactive:

```bash
az login
```

Service Principal:

```bash
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

Then run bootstrap again.

### Issue: "Invalid GitHub token"

**Symptoms**:

```text
ERROR [prereq]: Invalid GitHub token
```

**Solution**:

1. Check token is set:

```bash
echo $GITHUB_TOKEN
```

1. Verify token is valid:

```bash
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

1. Create new token if needed:
   - Go to <https://github.com/settings/tokens>
   - Generate token with `repo`, `workflow`, `admin:org` scopes
   - Export new token: `export GITHUB_TOKEN="new-token"`

### Issue: Cluster creation fails with quota exceeded

**Symptoms**:

```text
ERROR [cluster]: Failed to create AKS cluster
Operation failed with status: 'QuotaExceeded'
```

**Solution**:

1. Check your quota:

```bash
az vm list-usage --location eastus --output table
```

1. Request quota increase:
   - Azure Portal → Subscriptions → Usage + quotas
   - Select the VM family and region
   - Request increase

1. Or use smaller VM size:

```bash
./bootstrap.sh --node-size Standard_B2s --node-count 2
```

### Issue: Repository creation fails

**Symptoms**:

```text
ERROR [repo]: Failed to create repository
```

**Solutions**:

1. **Repository already exists**:
   - Delete existing repository via GitHub UI
   - Or use existing repo: `--control-plane-repo URL`

1. **Insufficient permissions**:
   - Verify token has `repo` scope
   - For organization: verify token has `admin:org` scope and you're an org member

1. **API rate limit**:
   - Wait for rate limit reset (check headers in verbose mode)
   - Use authenticated requests (token should be set)

### Issue: Helm installation fails

**Symptoms**:

```text
ERROR [install]: Helm installation failed
Error: timed out waiting for the condition
```

**Solutions**:

1. **Check cluster resources**:

```bash
kubectl get nodes
kubectl top nodes  # Requires metrics-server
```

1. **Increase timeout**:
Edit `lib/install.sh` and increase timeout from 5m to 10m

1. **Check pod status**:

```bash
kubectl get pods -n kalypso-system
kubectl describe pod <pod-name> -n kalypso-system
```

1. **Check events**:

```bash
kubectl get events -n kalypso-system --sort-by='.lastTimestamp'
```

### Issue: Cluster not ready timeout

**Symptoms**:

```text
ERROR [cluster]: Cluster failed to become ready
```

**Solutions**:

1. **Check node status**:

```bash
kubectl get nodes
kubectl describe node <node-name>
```

1. **Check system pods**:

```bash
kubectl get pods -n kube-system
```

1. **Check Azure status**:

```bash
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

1. **Wait longer**:

- Cluster creation can take 10-15 minutes
- System pods can take additional 5 minutes

### Issue: Non-interactive mode requires configuration

**Symptoms**:

```text
ERROR [config]: Must specify either --create-cluster or --use-cluster
```

**Solution**:

Provide all required configuration:

```bash
./bootstrap.sh \
  --create-cluster \
  --cluster-name my-cluster \
  --resource-group my-rg \
  --create-repos \
  --non-interactive
```

Or use config file:

```bash
./bootstrap.sh --config config.yaml --non-interactive
```

## Verification Steps

### Verify kubectl access

```bash
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Verify Azure resources

```bash
# List resource groups
az group list --output table

# Show AKS cluster
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# List AKS clusters
az aks list --output table
```

### Verify GitHub repositories

```bash
# Using curl
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/<owner>/<repo>

# Using gh CLI (if installed)
gh repo view <owner>/<repo>
```

### Verify Kalypso installation

```bash
# Check namespace
kubectl get namespace kalypso-system

# Check deployments
kubectl get deployments -n kalypso-system

# Check pods
kubectl get pods -n kalypso-system

# Check CRDs
kubectl get crd | grep kalypso

# Check Helm release
helm list -n kalypso-system
```

## Manual Cleanup

If automatic rollback fails or you need to clean up manually:

### Delete AKS Cluster

```bash
az aks delete \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --yes
```

### Delete Resource Group

```bash
az group delete \
  --name $RESOURCE_GROUP \
  --yes
```

### Delete GitHub Repositories

Via GitHub CLI:

```bash
gh repo delete <owner>/<repo> --yes
```

Via API:

```bash
curl -X DELETE \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/<owner>/<repo>
```

### Uninstall Helm Release

```bash
helm uninstall kalypso-scheduler -n kalypso-system
```

### Delete Namespace

```bash
kubectl delete namespace kalypso-system
```

## Advanced Debugging

### Capture full script output

```bash
./bootstrap.sh --verbose 2>&1 | tee bootstrap-$(date +%Y%m%d-%H%M%S).log
```

### Check script execution trace

```bash
bash -x ./bootstrap.sh
```

### Test individual components

```bash
# Source libraries
source lib/utils.sh
source lib/prerequisites.sh

# Run specific checks
check_all_prerequisites
validate_authentication
```

## Getting Help

If you can't resolve the issue:

1. **Check existing issues**:
   - <https://github.com/microsoft/kalypso-scheduler/issues>

2. **Create new issue**:
   - Include script version: `./bootstrap.sh --version`
   - Include error messages
   - Include relevant configuration (redact secrets)
   - Attach log file if available

3. **Community support**:
   - GitHub Discussions
   - Kalypso Slack channel (if available)

## Known Issues

### Issue: shellcheck warnings

**Status**: Cosmetic, does not affect functionality

**Details**: Some shellcheck warnings about sourced files may appear. These are expected and can be ignored.

### Issue: Slow cluster creation on certain Azure regions

**Status**: Azure-specific limitation

**Workaround**: Try a different region or use existing cluster

### Issue: GitHub rate limiting

**Status**: GitHub API limitation

**Workaround**:

- Use authenticated requests (GITHUB_TOKEN)
- Wait for rate limit reset
- Use GitHub Enterprise if available

## Performance Tips

### Speed up cluster creation

1. Use existing cluster when possible
2. Reduce node count for testing: `--node-count 1`
3. Use smaller VM size: `--node-size Standard_B2s`

### Speed up repository creation

1. Use existing repositories when possible
2. Pre-create repositories and use `--control-plane-repo` and `--gitops-repo`

### Speed up installation

1. Pre-pull container images
2. Use local Helm chart
3. Optimize cluster resources

## Diagnostic Checklist

Before reporting an issue, verify:

- [ ] All prerequisites are installed and meet version requirements
- [ ] Azure authentication is working (`az account show`)
- [ ] GitHub token is valid and has correct scopes
- [ ] Network connectivity to Azure and GitHub
- [ ] Sufficient Azure quotas for cluster creation
- [ ] Correct permissions on Azure subscription/resource group
- [ ] Correct permissions on GitHub account/organization
- [ ] Script is run from correct directory
- [ ] No typos in command-line arguments
- [ ] Configuration file is valid (if using)

## Additional Resources

- [Prerequisites](prerequisites.md)
- [Quickstart Guide](quickstart.md)
