# Run Books

This collection of run books provides general guidelines for executing common use cases against the Kalypso control plane and application repositories.

## Assumptions

> TODO: verify these restrictions before merging.

- AKS Clusters or Arc-enabled AKS Clusters (required for k8s extensions)
- Using the Azure Flux GitOps operator
- Applications use 3 repositories (source, config, gitops)

## Run Books

| Team        | Run Book                                                                                              |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| Platform    | [Onboard a New Cluster](./platform-team-onboards-a-new-cluster.md)                                    |
| Platform    | [Create a New Environment](./platform-team-creates-a-new-environment.md)                              |
| Platform    | [Schedule Applications for Deployment](./platform-team-schedules-applications-for-deployment.md)      |
| Platform    | [Manage Platform Configuration](./platform-team-manages-platform-configuration.md)                    |
| Application | [Onboard a New Application](./application-team-onboards-a-new-application.md)                         |
| Application | [Create a New Application Ring](./application-team-creates-a-new-application-ring.md)                 |
| Application | [Promote a Change Through Environments](./application-team-promotes-a-change-through-environments.md) |
| Application | [Manage Application Configuration](./application-team-manages-application-configuration.md)           |

> TODO: all runbooks need screenshots & examples
