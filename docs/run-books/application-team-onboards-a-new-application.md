# Application Team Onboards a New Application

- [Application Team Onboards a New Application](#application-team-onboards-a-new-application)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
    - [1. Identify Git Repository](#1-identify-git-repository)
  - [Steps](#steps)
    - [1. Setup a GitOps CI/CD flow](#1-setup-a-gitops-cicd-flow)
  - [Next Steps](#next-steps)

## Overview

This run book describes how to onboard a new workload to an existing Kalypso system. This workload will include 3 repositories containing source code, configuration, and gitops manifests respectively and will follow the GitOps CI/CD flow using GitHub as described in [GitOps CI/CD with GitHub](https://github.com/microsoft/kalypso/blob/main/cicd/readme.md).

## Prerequisites

### 1. Identify Git Repository

A workload consists of 3 git repositories:

- a **source** repository for application source code and deployment templates
- a **config** repository for application configurations in branches organized by rings and environments
- a **gitops** repository for application manifests that are deployed into clusters

Create or identify the **source** repository for your workload and make sure you have admin access as this run book will require managing the GitHub environments and other configurations.

The **config** and **gitops** repositories will be automatically created using scripts in this run book.

## Steps

### 1. Setup a GitOps CI/CD flow

The guide for setting up a new application is documented in [setup.md](../../cicd/setup.md). Follow those instructions for your workload using the source repository identified in [prerequisite 1](#1-identify-git-repository).

## Next Steps

To add more rings to the application deployment, see [Application Team Creates a New Application Ring](./application-team-creates-a-new-application-ring.md).

To provide configuration for different rings and environments to your application, see [Application Team Manages Application Configuration](./application-team-manages-application-configuration.md) and [Platform Team Manages Platform Configuration](./platform-team-manages-platform-configuration.md).

To deploy the application through environments and rings, see [Application Team Promotes a Change Through Environments](./application-team-promotes-a-change-through-environments.md).
