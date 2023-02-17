# Platform team schedules an application on cluster types

*Preconditions*:

- Control Plane and Platform GitOps repositories exist and have environment branches  

*Postconditions*:

- Scheduling policy is configured in the control plane
- Application deployment targets are assigned to the cluster types in the Platform GitOps repo 

Platform Team submits a PR to the control plane environment branch (e.g. *dev* or *stage*) with a scheduling policy, that defines rules of how deployment targets should be scheduled to cluster types. The rules might be trivial, based on label matching, or they can include score-based configurations defined by OCM Placement API. Once the PR is reviewed and merged, the scheduler analyzes what deployment targets should be assigned to what cluster types in the environment. It generates assignment manifests and creates a PR to the environment branch of the Platform GitOps repository. 



