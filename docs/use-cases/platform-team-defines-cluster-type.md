# Platform team defines a cluster type

*Preconditions*:

- Control Plane and Platform GitOps repositories exist and have environment branches  

*Postconditions*:

- Information on the new cluster type is stored in the control plane environment branches
- Platform GitOps repository environment branches contain folders representing the cluster type with the subfolders representing deployment targets scheduled on the cluster type

Platform Team submits a PR to the control plane environment branch (e.g. *dev* or *stage*) with the information on the cluster type. Once the PR is reviewed and merged, the scheduler analyzes what deployment targets should be assigned to this cluster type. It generates assignment manifests and creates a PR to the environment branch of the Platform GitOps repository.  

> Refer to the runbook [Platform Team Onboards a New Cluster](../run-books/platform-team-onboards-a-new-cluster.md).
