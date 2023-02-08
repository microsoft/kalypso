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

```

## Sample overview

What we have deployed ...

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





