# Introduction

Kalypso provides a composable reference architecture of the workload management in a multi-cluster and multi-tenant environment with GitOps. 

This is an umbrella repository that contains requirements, use cases, high level architecture and design decisions. The overall solution is composable so that every single component is handled in [its own repository](#referenced-repositories).

## Motivation
<!--  
  - Item
  - Word Doc
  - Knowledge Sharing
  Scheduling!!!
-->


## Roles

### Platform Team

### Application Team

### Application Operators

  Out of scope

## High Level Flow
![kalypso-high-level](./docs/images/kalypso-high-level.png)

## Primary Use Cases

## Design Details
![kalypso-detailed](./docs/images/kalypso-detailed.png)

## Referenced Repositories

|Repository|Description|
|--------|----------|
|[Application Source]()|Contains a sample application source code including Docker files, manifest templates and CI/CD workflows|
|[Application GitOps]()|Contains final sample application manifests to de be deployed to the deployment targets|
|[Services Source]()|Contains high level manifest templates of sample dial-tone platform services and CI/CD workflows|
|[Services GitOps]()|Contains final manifests of sample dial-tone platform services to be deployed across clusters fleet|
|[Control Plane]()|Contains a platform model including environments, cluster types, applications and services, mapping rules and configurations, Promotion Flow workflows|
|[Platform GitOps]()|Contains final manifests representing the topology of the fleet - what cluster types are available, how they are distributed across environments and what is supposed to deployed where|
|[Kalypso Scheduler]()|Contains detailed design and source code of the scheduler operator, responsible for scheduling applications and services on cluster types and uploading the result to the GitOps repo|   
|[Kalypso Observability Hub]()|Contains detailed design and source code of the deployment observability service|

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
