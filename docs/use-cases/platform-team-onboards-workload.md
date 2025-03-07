# Platform Team Onboards a workload

*Preconditions*:

- Control Plane and Platform GitOps repositories exist
- Workload GitOps repository exists

*Postconditions*:

- Information on the new workload is stored in the control plane
- Promotion flow has started promoting the workload across environments

Platform Team submits a PR to the control plane *main* branch with the information on the workload. Once the PR is reviewed and merged, the promotional flow starts promoting the application across environment branches in the GitOps repo.

> Refer to the runbook [Platform Team Schedules Applications for Deployment](../run-books/platform-team-schedules-applications-for-deployment.md).
