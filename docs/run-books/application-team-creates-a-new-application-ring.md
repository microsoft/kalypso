# Application Team Creates a New Application Ring

- [Application Team Creates a New Application Ring](#application-team-creates-a-new-application-ring)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
    - [1. Admin Access to Application Repositories](#1-admin-access-to-application-repositories)
    - [2. Admin Access to Deployment Observability Dashboards](#2-admin-access-to-deployment-observability-dashboards)
  - [Steps](#steps)
    - [1. Create a new GitOps Branch](#1-create-a-new-gitops-branch)
    - [2. Create a new Config Branch](#2-create-a-new-config-branch)
    - [3. Merge GitOps PR](#3-merge-gitops-pr)
    - [4. Link Environment in Promotion Sequence](#4-link-environment-in-promotion-sequence)
    - [5. Update Deployment Observability Dashboards](#5-update-deployment-observability-dashboards)
  - [Next Steps](#next-steps)

## Overview

This ron book describes how to manage deployment rings for applications. Rings can be used to create separate scopes and stages for deploying applications out to clusters. This creates an additional promotion flow within the platform environments.

Rings and their promotion flow are unique to each application. In this run book, we will walk through the process for including a new ring for a single application.

For information on managing environments, see [Platform Team Creates a New Environment](./platform-team-creates-a-new-environment.md).

## Prerequisites

### 1. Admin Access to Application Repositories

Each application constists of 3 git repositories. A source repository, a configuration repository, and a GitOps repository. Identify all 3 repositories and make sure you have admin access to all 3. Admin access is required to create and modify GitHub workflows and variables.

### 2. Admin Access to Deployment Observability Dashboards

The deployment observability dashboards for the [Kalypso Observability Hub](https://github.com/microsoft/kalypso-observability-hub) show the deployment status for applications across environments, rings, and clusters. In this runbook, we will exapand this dashboard to include new rings.

> TODO: screenshot

## Steps

### 1. Create a new GitOps Branch

First, create a branch in the application's GitOps repository. This repo has a branch for every ring & environment combination that holds relevant GitOps manifest files.

Inside the GitOps repository create a new git branch based off of the latest ring. In this run book, we will create `dev-newring` based off `dev-prevring`.

```sh
# switch to the existing base branch
git checkout dev-prevring

# create a new branch based on the existing branch
git checkout -b dev-newring
```

Remove all of the generated GitOps manifests files from the previous branch. The exact command will depend on the config repository structure.

Finally, push the new branch to GitHub.

```sh
git add .
git commit -m "Prepare new ring branch"
git push -u origin dev-newring
```

Once complete, there should be a new branch in GitHub named `dev-newring`. This branch will only contain the `.github/*` files and the `README.md`.

> TODO: screenshot

### 2. Create a new Config Branch

Next, create a branch in the config repository. This repo has a branch for each environment and ring combination that holds configuration values for the environment & ring.

Inside the config repository, create a new git branch based off the previous ring. In this runbook, we will create `dev-newring` based off `dev-prevring`.

```sh
# switch to the existing base branch
git checkout dev-prevring

# create a new branch based on the existing branch
git checkout -b dev-newring
```

In the new branch, update any values files to fit the new ring. The specific files and values will depend on the application. See [Application Team Manages Application Configuration](./application-team-manages-application-configuration.md) for more information on managing configuration files.

When you are happy with the values, commit and push the changes to GitHub.

```sh
git add .
git commit -m "Prepare dev-newring config"
git push -u origin dev-newring
```

### 3. Merge GitOps PR

After pushing the config branch to GitHub, a PR will automatically be generated against the new GitOps branch for this ring. This PR includes all generated GitOps manifests based on the configuration values in the config branch.

Merge this PR, and the new ring is ready to use.

> TODO: screenshot

### 4. Link Environment in Promotion Sequence

Now that our git branches for the new ring are set up, we need to declare where this ring lives in the promotional sequence. This is defined by GitHub environments inside the application source repository.

Each GitHub environment optionally contains a variable called `NEXT_ENVIRONMENT` that points to the next ring in the sequence. This creates a linked list that dictates how application changes are promoted through rings.

We will update `dev-prevring` to include a new `NEXT_ENVIRONMENT` variable that points to the new `dev-newring` ring.

> TODO: ring list diagram

Update the previous GitHub Environment, `dev-prevring`, to point to the new `NEXT_ENVIRONMENT`, `dev-newring`.

> TODO: screenshot

### 5. Update Deployment Observability Dashboards

In the Deployment Observability Dashboards, edit the Environment State table Ring column to show the new ring.

> TODO: screenshot

Update the value mappings to include a new value and color for the new ring.

> TODO: screenshot

Finally, save the dashboard changes. The dashboard JSON can be exported and persisted as configuration for the Observability Hub.

> TODO: screenshot

## Next Steps

This run book provides instructions for creating a new ring for an application. Rings allow applications to be promoted within platform environments. To create a new environment, see [Platform Team Creates a New Environment](./platform-team-creates-a-new-environment.md).

After creating a new ring, only the GitOps manifest files are generated. To actually deploy this ring to a cluster and configure what clusters host applications in this ring, see [Platform Team Onboards a New Cluster](./platform-team-onboards-a-new-cluster.md) and [Platform Team Schedules Applications for Deployment](./platform-team-schedules-applications-for-deployment.md).

Once the ring exists within the promotional sequence, the application will be promoted through this ring. To learn how to promote an application through rings and environments, see [Application Team Promotes a Change Through Environments](./application-team-promotes-a-change-through-environments.md).

