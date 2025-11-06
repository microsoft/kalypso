# Introduction

[![PR Quality Check](https://github.com/microsoft/kalypso/actions/workflows/pr.yaml/badge.svg)](https://github.com/microsoft/kalypso/actions/workflows/pr.yaml)

Kalypso is a collection of repositories, that back up the following Microsoft Learning resources:

- [Concept: Workload management in a multi-cluster environment with GitOps](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-workload-management)
- [How-to: Explore workload management in a multi-cluster environment with GitOps](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/workload-management)

It provides a composable reference architecture of the workload management in a multi-cluster and multi-tenant environment with GitOps.

This is an umbrella repository that contains requirements, use cases, architecture and code. The overall solution is composable so that every single component is handled in [its own repository](#referenced-repositories).

## Motivation

There is an organization developing cloud-native applications. Any application needs a compute resource to work on. In the cloud-native world, this compute resource is a Kubernetes cluster. An organization may have a single cluster or, more commonly, multiple clusters. So the organization must decide which applications should work on which clusters. In other words, they must schedule the applications across clusters. The result of this decision, or scheduling, is a model of the desired state of the clusters in their environment. Having that in place, they need somehow to deliver applications to the assigned clusters so that they can turn the desired state into the reality, or, in other words, reconcile it.

Every application goes through a software development lifecycle that promotes it to the production environment. For example, an application is built, deployed to Dev environment, tested and promoted to Stage environment, tested, and finally delivered to production. For a cloud-native application, the application requires and targets different Kubernetes cluster resources throughout its lifecycle. In addition, applications normally require clusters to provide some platform services, such as Prometheus and Fluentbit, and infrastructure configurations, such as networking policy.

Depending on the application, there may be a great diversity of cluster types to which the application is deployed. The same application with different configurations could be hosted on a managed cluster in the cloud, on a connected cluster in an on-premises environment, on a group of clusters on semi-connected edge devices on factory lines or military drones, and on an air-gapped cluster on a starship. Another complexity is that clusters in early lifecycle stages such as Dev and QA are normally managed by the developer, while reconciliation to actual production clusters may be managed by the organization's customers. In the latter case, the developer may be responsible only for promoting and scheduling the application across different rings.  

In a small organization with a single application and only a few operations, most of these processes can be handled manually with a handful of scripts and pipelines. But for enterprise organizations operating on a larger scale, it can be a real challenge. These organizations often produce hundreds of applications that target hundreds of cluster types, backed up by thousands of physical clusters. In these cases, handling such operations manually with scripts isn't feasible.

The following capabilities are required to perform this type of workload management at scale in a multi-cluster environment:

- Separation of concerns on scheduling and reconciling
- Promotion of the multi-cluster state through a chain of environments
- Sophisticated, extensible and replaceable scheduler
- Flexibility to use different reconcilers for different cluster types depending on their nature and connectivity
- Abstracting Application Team away from the details of the clusters in the fleet

### Existing projects

It's worth mentioning that there is a variety of existing projects targeting to address some of the described challenges. Most of them are built on the *Hub/Spoke* concept where there is a *Hub* cluster that controls workload placement across connected *Spoke* clusters. Examples of such tools are [Kubefed](https://github.com/kubernetes-sigs/kubefed), [Karmada](https://karmada.io/), [KubeVela](https://kubevela.io/), [OCM](https://open-cluster-management.io/), [Azure Kubernetes Fleet](https://learn.microsoft.com/en-us/azure/kubernetes-fleet/overview), [Rancher Fleet](https://fleet.rancher.io) etc. By definition, solutions like that expect a connection between *Hub* and *Spoke* clusters, at least an occasional one. They commonly provide a monolithic functionality, meaning they implement both workload scheduling and reconciling to the spoke clusters, so that scheduling and reconciling are tightly coupled to each other.

Historically, most of such tools have been designed to federate applications across multiple clusters. They are supposed to provide scalability, availability and security capabilities for a single application instance by breaking through Kubernetes limit of 5k nodes and placing an application across multiple regions and security zones. A solution like that is a perfect fit for a group or a fleet of connected clusters of the same or similar type with simple workload placement, based on labels and cluster performance metrics. From the perspective of this project, a cluster fleet like that is considered as a single deployment target, as a cluster of clusters with its own mechanics to load and balance the underlying compute.

## Roles

### Platform Team

The platform team is responsible for managing the clusters that host applications produced by application teams.

*Key responsibilities*:

- Define staging environments (Dev, QA, UAT, Prod)
- Define cluster types (group of clusters sharing the same configurations) and their distribution across environments
- Provision New clusters (CAPI/Crossplane/Bicep/Terraform/…)
- Manage infrastructure configurations and platform services (e.g. RBAC, Istio, Service Accounts, Prometheus, Flux, etc.) across cluster types
- Schedule applications and platform services on cluster types

### Application Team

The application team is responsible for the software development lifecycle (SDLC) of their applications. They provide Kubernetes manifests that describe how to deploy the application to different targets. They're responsible for owning CI/CD pipelines that create container images and Kubernetes manifests and promote deployment artifacts across environment stages.

The application team is responsible for the software development lifecycle (SDLC) of their applications. They provide Kubernetes manifests that describe how to deploy the application to different targets. They're responsible for owning CI/CD pipelines that create container images and Kubernetes manifests and promote deployment artifacts across environment stages.

*Key responsibilities*:

- Run full SDLC of their applications: Develop, build, deploy, test, promote, release, and support their applications.
- Maintain and contribute to source and manifests repositories of their applications.
- Define and configure application deployment targets.
- Communicate to platform team, requesting desired compute resources for successful SDLC operations.

### Application Operators

Application (Line/Store/Host) Operators work with the applications on the clusters on the edge. They are normally in charge of application instances working on a single or a small group of clusters. They decide when to rollout and rollback a specific application instance on a specific cluster.

Application Operators act on the reconciling/deployment part of the story, on the other hand, Kalypso is focused on the scheduling part, being reconciler agnostic. Kalypso doesn't deploy. With that said, while Application Operators still need a tool to perform their actions effectively, this functionality is out of Kalypso's scope.

## High Level Flow

![kalypso-high-level](./docs/images/kalypso-highlevel.png)

The diagram above describes interaction between the roles and the major components of the solution. The primary concept of the whole process is separation of concerns. There are workloads, such as applications and platform services, and there is a platform where these workloads are working on. Application team takes care of the workloads (*what*), while the platform team is focused on the platform (*where*).

Application Team runs SDLC of their applications and promotes changes across environments. Application Team doesn't operate with the notion of the cluster. They have no idea on which clusters their application will be deployed in each environments. Application Team operates with the concept of *Deployment Target*, which is just an abstraction within an environment. Examples of deployment targets could be: *Integration* on Dev, *functional tests* and *performance tests* on QA, *early adopters* and *external users* on Prod and so on. Application Team defines deployment targets for each environment and they know how to configure their application and how to generate manifests for each deployment target. This process is owned by Application Team, it is automated and exists in the application repositories space. The outcome of the Application Team is generated manifests for each deployment target, stored in a manifests storage, such as a Git repository, Helm Repository, OCI storage, etc.

Platform team has a very limited knowledge about the applications and therefore is not involved in the application configuration and deployment process. Platform team is in charge of platform clusters, that are grouped in *Cluster Types*. They describe *Cluster Types* with configuration values, such as DNS names, endpoints of external services and so on. Platform team assigns (*schedules*) application deployment targets to various cluster types. With that in place, the application behavior will be determined by the combination of *Deployment Target* configuration values, provided by Application Team, and *Cluster Type* configuration values, provided by the Platform Team. The key point is that Platform team doesn't configure applications, they configure environments for applications. Essentially, they provide environment variable values. They look at what variables are requested by a collection of applications for each *Cluster Type*, group of cluster types, region, etc. and provide those values in the control plane.

Platform Team defines and configures *Cluster Types* and assigns *Deployment Targets* in the *Control Plane*. This is the place where they model their Platform. It's like a source repository for the Application Team. It's important to say, that the platform team doesn't manually schedule *Deployment Targets* on *Cluster Types* one by one. Instead of that they define scheduling rules in the *Control Plane*. Those rules along with configuration values are processed by an automated process that saves the result to the *Platform GitOps repo*. This repository contains folders for each *Cluster Type* with the information on what workloads should work on it and what configuration values should be applied. Clusters can grab that information from the corresponding folder with their preferred reconciler and apply the manifests.

Clusters report their compliance state with GitOps repositories to the *Deployment Observability Hub*. Platform and Application teams query this information to analyze workload deployment across the clusters historically. It can be used in the dashboards, alerts and in the deployment pipelines to implement progressive rollout.

## Primary Use Cases

- [Platform team onboards a workload](./docs/use-cases/platform-team-onboards-workload.md)
- [Platform team defines a cluster type](./docs/use-cases/platform-team-defines-cluster-type.md)
- [Platform team provides configuration values for a cluster type](./docs/use-cases/platform-team-config-values.md)
- [Platform team schedules an application on cluster types](./docs/use-cases/platform-team-scheduled-application.md)
- [Application team defines application deployment targets](./docs/use-cases/application-team-defines-deployment-targets.md)
- [Application team provides a configuration value for a deployment target](./docs/use-cases/application-team-provides-configuration-value.md)
- [Application team updates the application](./docs/use-cases/application-team-updates-application.md)
- [Platform team defines service deployment targets](./docs/use-cases/platform-team-defines-deployment-targets.md)
- [Platform team provides a configuration value for a service deployment target](./docs/use-cases/platform-team-provides-configuration-value.md)
- [Platform team adds a platform service](./docs/use-cases/platform-team-adds-platform-service.md)

## Design Details

![kalypso-detailed](./docs/images/kalypso-detailed.png)

### Control Plane

The platform team models the multi-cluster environment in the control plane. It's designed to be human-oriented and easy to understand, update, and review. The control plane operates with abstractions such as Cluster Types, Environments, Workloads, Scheduling Policies, Configs and Templates. See full list of abstractions in [Kalypso Scheduler](https://github.com/microsoft/kalypso-scheduler#kalypso-control-plane-abstractions) repository. These abstractions are handled by an automated process that assigns deployment targets and configuration values to the cluster types, then saves the result to the platform GitOps repository. Although there may be thousands of physical clusters, the platform repository operates at a higher level, grouping the clusters into cluster types.

There are various visions of how the control plane storage may be implemented. Following the GitOps concepts, it can be a Git repo, following the classic architecture it might me a database service with some API exposed.

The main requirement for the control plane storage is to provide a reliable and secure transaction processing functionality, rather than being hit with complex queries against a large amount of data. Various technologies may be used to store the control plane data.

This architecture design suggests a Git repository with a set of pipelines to store and promote platform abstractions across environments. This design provides a number of benefits:

- All advantages of GitOps principles, such as version control, change approvals, automation, pull-based reconciliation.
- Git repositories such as GitHub provide out of the box branching, security and PR review functionality.
- Easy implementation of the promotional flows with GitHub Actions Workflows or similar orchestrators.
- No need to maintain and expose a separate control plane service.  

Overall, the *Kalypso Control Plane* consists of the following components:

- GitHub repository along with a set of GH Actions workflows to store and promote abstractions
- Control plane K8s cluster with [Kalypso Scheduler](https://github.com/microsoft/kalypso-scheduler) performing all the scheduling and transformations

### Promotion and scheduling

The control plane repository contains two types of data:

- Data that gets promoted across environments, such as a list of onboarded workloads and various templates.
- Environment-specific configurations, such as included into an environment cluster types, config values, and scheduling policies. This data isn't promoted, as it's specific to each environment.

The data to be promoted lives in *main* branch while environment specific data is stored in the corresponding environment branches (e.g. dev, qa, prod). Transforming data from the *Control Plane* to the *GitOps repo* is a combination of the promotion and scheduling flows. The promotion flow moves the change across the environments horizontally and the scheduling flow does the scheduling and generates manifests vertically for each environment.

A commit to the *main* branch starts the promotion flow that triggers the scheduling/transforming flow for each environment one by one. The scheduling/transforming flow takes the base manifests from *main*, applies configs from a corresponding to this environment branch (Dev, QA,..Prod) and PRs the resulting manifests to the *Platform GitOps repo* in the corresponding to the environment branch. Once the rollout on this environment is complete and successful, the promotion flow goes ahead and performs the same procedure on the next environment. On every environment the flow promotes the same commitid of the main branch, making sure that the content from *main* is getting to the next environment only after success on the previous environment.

![promotion-flow](./docs/images/promotion-flow.png)

A commit to the environment branch (Dev, Qa, …Prod) in the *Control repo* will just start the scheduling/transforming flow for this environment. E.g. we have changed cosmo-db endpoint for QA, we just need to make updates to the QA branch of the GitOps repo, we don’t want to touch anything else. The scheduling will take the *main* content corresponding to the latest commit id promoted to this environment, apply configurations and PR the resulting manifests to the GitOps branch.

The scheduling/transformation flow is implemented with a K8s operator [Kalypso Scheduler](https://github.com/microsoft/kalypso-scheduler) hosted on a *Control Plane* K8s cluster. It watches changes in the *Control Plane* environment branches, performs necessary scheduling, transformations, generates manifests and PR's them to the *Platform  GitOps repository*.

There are a few points to highlight here:

- The promotion flow doesn’t generate anything. It’s just a vehicle to orchestrate the flow. It provides approvals, gates, state tracking. Performs post and pre-deployment activities.
- The *Kalypso Scheduler* pulls the changes from the control plane repo with Flux. It knows exactly what has changed, and regenerates only related manifests. It doesn't rebuild the entire fleet.
- This approach gives advantages of the both worlds - GH Actions and K8s:
  - Powerful promotion flow orchestrator
  - Precise event driven scheduling and transformation. We don’t reboil the ocean while reacting on a change in the *Control Plane*. There is neither a bottleneck, nor a butterfly effect.

### Workload assignment

In the platform GitOps repository, each workload assignment to a cluster type is represented by a folder that contains the following items:

- A dedicated namespace for this workload in this environment on a cluster of this type.
- Platform policies restricting workload permissions.
- Consolidated platform config maps and secrets that the workload can use.
- Reconciler resources pointing to a *Workload Manifests Storage* where the actual workload manifests or Helm charts live. E.g. Flux GitRepository and Flux Kustomization, ArgoCD Application, Zarf descriptors, nd so on.

### Platform services

Platform services are workloads (such as Prometheus, NGINX, Fluentbit, and so on) maintained by the platform team. Just like any workloads, they have their source repositories and manifests storage. The source repositories may contain pointers to external Helm charts. CI/CD pipelines pull the charts with containers and perform necessary security scans before submitting them to the manifests storage, from where they're reconciled to the clusters.

Considering platform services as regular workflows, gives the following advantages:

- Clean separation of “what is running” (applications and services) from “where it is running” (platform). These two things have completely different lifecycles.
- Clean and simple functionality of the control plane. There is no workload manifest generation at all, only promotion, scheduling and configurations.
- Their might be multiple control planes that can consume same platform services.  

### Cluster types and reconcilers

Every cluster type can use a different reconciler (such as Flux, ArgoCD, Zarf, Rancher Fleet, and so on) to deliver manifests from the Workload Manifests Storages. Cluster type definition refers to a reconciler, which defines a collection of manifest templates. The scheduler uses these templates to produce reconciler resources, such as Flux GitRepository and Flux Kustomization, ArgoCD Application, Zarf descriptors, and so on. The same workload may be scheduled to the cluster types, managed by different reconcilers, for example Flux and ArgoCD. The scheduler generates Flux GitRepository and Flux Kustomization for one cluster and ArgoCD Application for another cluster, but both of them point to the same Workload Manifests Storage containing the workload manifests.

### Extensible Scheduler

Kalypso scheduler operates with the [Control Plane abstractions](https://github.com/microsoft/kalypso-scheduler#kalypso-control-plane-abstractions), understands *Control Plane* and *Platform GitOps* repo structures and implements label based scheduling logic.

### Deployment Observability Hub

Deployment Observability Hub is a central storage that is easy to query with complex queries against a large amount of data. It contains deployment data with historical information on workload versions and their deployment state across clusters. Clusters register themselves in the storage and update their compliance status with the GitOps repositories. Clusters operate at the level of Git commits only. High-level information, such as application versions, environments, and cluster type data, is transferred to the central storage from the GitOps repositories. This high-level information gets correlated in the central storage with the commit compliance data sent from the clusters. See the details in the [Kalypso Observability Hub](https://github.com/microsoft/kalypso-observability-hub) repo.

### UI

Kalypso implements "Platform as Code" paradigm. Platform team defines the state of the platform with abstractions/resources and stores them as yaml files in a Git repository. There is a tool that takes this "code" and converts it into the platform.

This is very similar to the "Infrastructure as Code" concept when the infrastructure is defined with a set of Terraform or Bicep resources that are stored in a repo and there is a tool (Terraform/Bicep) that provisions and updates the infra resources. Yes, there is UI, such as Azure Portal, where you can create the infra resources as well, but no-one does it scale for a number of good reasons. The best practice is to go with the "as code" approach.

However, it is recognized that UI and CLI tools might still be helpful to analyze the output, visualize created platform resources and see if any adjustments should be done to the "code".

Currently, Kalypso CLI and UI tools are being under design.  

## Referenced Repositories

|Repository|Description|
|--------|----------|
|[Application Source](https://github.com/microsoft/kalypso-app-src)|Contains a sample application source code including Docker files, manifest templates and CI/CD workflows|
|[Application GitOps](https://github.com/microsoft/kalypso-app-gitops)|Contains final sample application manifests to be deployed to the deployment targets|
|[Services Source](https://github.com/microsoft/kalypso-svc-src)|Contains high level manifest templates of sample dial-tone platform services and CI/CD workflows|
|[Services GitOps](https://github.com/microsoft/kalypso-svc-gitops)|Contains final manifests of sample dial-tone platform services to be deployed across clusters fleet|
|[Control Plane](https://github.com/microsoft/kalypso-control-plane)|Contains a platform model including environments, cluster types, applications and services, mapping rules and configurations, Promotion Flow workflows|
|[Platform GitOps](https://github.com/microsoft/kalypso-gitops)|Contains final manifests representing the topology of the fleet - what cluster types are available, how they are distributed across environments and what is supposed to deployed where|
|[Kalypso Scheduler](https://github.com/microsoft/kalypso-scheduler)|Contains detailed design and source code of the scheduler operator, responsible for scheduling applications and services on cluster types and uploading the result to the GitOps repo|
|[Kalypso Observability Hub](https://github.com/microsoft/kalypso-observability-hub)|Contains detailed design and source code of the deployment observability service|

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Data Collection
The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkID=824704. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

Currently, telemetry on tutorial usage is collected only. See the details on how to opt out in the [tutorial instructions](./cicd/tutorial/cicd-tutorial.md#opt-out-telemetry).


## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
