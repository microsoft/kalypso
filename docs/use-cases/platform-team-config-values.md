# Platform team provides configuration values for a cluster type

*Preconditions*:

- Control Plane and Platform GitOps repositories exist and have environment branches  

*Postconditions*:

- Configuration values are stored in the control plane
- Deployment target subfolders in the Platform GitOps repository contain consolidated config maps with all platform config values available on the cluster type

Platform Team submits a PR to the control plane environment branch (e.g. *dev* or *stage*) with the a config map containing platform config values. The config map is marked with a set of custom labels. Once the PR is reviewed and merged, the scheduler scans all config maps in the environment and collects values for each cluster type basing on the label matching. Then, it creates a PR to the Platform GitOps repository with a consolidated config map in every deployment target folder. The config map contains all platform configuration values, that the workload can use on this cluster type in this environment.

> Refer to the runbook [Platform Team Manages Platform Configuration](../run-books/platform-team-manages-platform-configuration.md).
