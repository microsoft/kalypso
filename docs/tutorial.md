---
title: 'Tutorial: Workload management in a multi-cluster environment with GitOps'
description: This tutorial walks through a typical use-cases that Platform and Application teams face on a daily basis working with K8s workloads in a multi-cluster envrironemnt.
keywords: "GitOps, Flux, Kubernetes, K8s, Azure, Arc, AKS, ci/cd, devops"
author: eedorenko
ms.author: iefedore
ms.service: azure-arc
ms.topic: tutorial
ms.date: 02/08/2023
ms.custom: template-tutorial, devx-track-azurecli
---

# Tutorial: Workload management in a multi-cluster environment with GitOps

This tutorial will walk you through typical scenarios of the workload deployment and configuration in a multi-cluster Kubernetes environment. It will show how to use [Kalypso](https://github.com/microsoft/kalypso) GitHub repositories setup and toolings from the perspective of the `Platform Team` and `Application Dev Team` personas in their daily activities. 

## Installation options and requirements
 
The tutorial is built in the way that you first deploy a starting point sample infrastructure, with a few GitHub repositories and AKS clusters, and then it guides you through a set of use-cases where you act as different personas. 

### Prerequisites

In order to successfully deploy the sample, you need the following:

- [Azure CLI](/cli/azure/install-azure-cli).
- An Azure account with an active subscription. [Create one for free](https://azure.microsoft.com/free).
- [gh cli](https://cli.github.com)
- [Helm](https://helm.sh/docs/helm/helm_install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

### Deployment

To deploy the sample run the following script:

```azurecli-interactive
mkdir kalypso && cd kalypso
curl -fsSL -o deploy.sh https://raw.githubusercontent.com/microsoft/kalypso/main/deploy/deploy.sh
chmod 700 deploy.sh
./deploy.sh -c -p <preix. e.g. kalypso> -o <github org. e.g. eedorenko> -t <github token> -l <azure-location. e.g. westus2> 
```

Since AKS clusters provisioning is not the fastest process in the world, the script will really take it time. Once it's done, it will report the execution result in an output like this:

```azurecli-interactive
Depoyment is complete!
---------------------------------
Created repositories:
  - https://github.com/eedorenko/kalypso-control-plane
  - https://github.com/eedorenko/kalypso-gitops
  - https://github.com/eedorenko/kalypso-app-src
  - https://github.com/eedorenko/kalypso-app-gitops
---------------------------------
Created AKS clusters in kalypso-rg resource group:
  - control-plane
  - drone (Azure Arc Flux based workload cluster)
  - large (ArgoCD based workload cluster)
---------------------------------  
```

> [!NOTE]
> If something goes wrong with the deployment, you can always delete created resources with the following command:
> ```azurecli-interactive
> ./deploy.sh -d -p <preix. e.g. kalypso> -o <github org. e.g. eedorenko> -t <github token> -l <azure-location. e.g. westus2> 
> ```

## Sample overview

First of all, let's explore what we have deployed. The deployment script created an infrastructure shown on the following diagram:

![diagram]

There are a few `Platform Team` repositories:

- [Control Plane](https://github.com/microsoft/kalypso-control-plane) - Contains a platform model defined with high level abstractions, such as environments, cluster types, applications and services, mapping rules and configurations, promotion workflows.
- [Platform GitOps](https://github.com/microsoft/kalypso-gitops) - Contains final manifests representing the topology of the fleet - what cluster types are available in each environment, what workloads are scheduled on them and what platform configuration values are set.
- [Services Source](https://github.com/microsoft/kalypso-svc-src) - Contains high level manifest templates of sample dial-tone platform services.
- [Services GitOps](https://github.com/microsoft/kalypso-svc-gitops) - Contains final manifests of sample dial-tone platform services to be deployed across the clusters.

And a couple of the `Application Dev Team` repositories:

- [Application Source](https://github.com/microsoft/kalypso-app-src) - Contains a sample application source code including Docker files, manifest templates and CI/CD workflows.
- [Application GitOps](https://github.com/microsoft/kalypso-app-gitops) - Contains final sample application manifests to be deployed to the deployment targets.

The script created three AKS clusters:

- `control-plane` - This cluster doesn't run any workloads. It's a management cluster. It hosts [Kalypso Scheduler] operator that transforms high level abstractions from the [Control Plane](https://github.com/microsoft/kalypso-control-plane) repository to the raw Kubernetes manifests in the [Platform GitOps](https://github.com/microsoft/kalypso-gitops) repository.
- `drone` - This is a sample workload cluster. It's Azure Arc enabled and it uses `Flux` to reconcile manifests from the [Platform GitOps](https://github.com/microsoft/kalypso-gitops) repository.
- `large` - This is a sample workload cluster. It has `ArgoCD` installed which reconciles manifests from the [Platform GitOps](https://github.com/microsoft/kalypso-gitops) repository.


<!-- - [Platform team onboards a workload](./docs/use-cases/platform-team-onboards-workload.md)
- [Platform team defines a cluster type](./docs/images/under-construction.png)
- [Platform team provides a configuration value for a cluster type](./docs/images/under-construction.png)
- [Platform team schedules an application on cluster types](./docs/images/under-construction.png)
- [Application team defines application deployment targets](./docs/images/under-construction.png)
- [Application team provides a configuration value for a deployment target](./docs/images/under-construction.png)
- [Application team updates the application](./docs/images/under-construction.png)
- [Platform team defines service deployment targets](./docs/images/under-construction.png)
- [Platform team provides a configuration value for a service deployment target](./docs/images/under-construction.png)
- [Platform team updates a platform service](./docs/images/under-construction.png) -->


## Platform Team: Onboard a new application



### Define application scheduling policy on Dev

### Promote application to Stage

## Application Team: Build and Deploy application 

## Platform Team: Provide Platform Configurations

## Platform Team: Add cluster type to environment

## Platform Team: Analyze CLusters

### Look at Flux enabled cluster

### Look at ArgoCD enabled cluster





