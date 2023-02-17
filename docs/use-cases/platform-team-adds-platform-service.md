# Platform team adds a platform service

*Preconditions*:

- Platform Service Source repo exists
- Platform Service Manifest Storage exists

*Postconditions*:

- Platform Service Manifests and images are pulled and checked
- Manifests for the deployment targets are generated and put in the corresponding storage places 

Platform team submits a PR to the *main* branch in the Service Source repository with a file, that contains a reference to the external manifests storage. For example, a reference to a Grafana Helm chart in https://grafana.github.io/helm-charts. Once the PR is merged to *main*, it starts a CI/CD workflow. The workflow pulls the manifests from the external storage, pulls service images and performs standard security scanning. Then, it generates manifests for the deployment targets defined for the first environment in the rollout chain (e.g. *dev*) and places them to the Manifest Storage, such as an OCI storage or a local Helm repo, or just a Git repo. The manifests are generated with the config values provided for the deployment target in the config branch of the Service Source repository. Once the Platform Team is satisfied with the deployment to the first environment, they promote the change to the next environment, so the CD workflow goes ahead and generates manifests for the deployment targets in that environment.     
