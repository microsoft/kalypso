# Application team updates the application

*Preconditions*:

- Application Source repo exists
- Application Manifest Storage exists

*Postconditions*:

- Application is rebuilt
- Manifests for the deployment targets are generated and put in the corresponding storage places

Application Team submits a PR with the source code change to the *main* branch in the Application Source repository. Once the PR is merged to *main*, it starts a CI/CD workflow. The workflow performs standard code quality and security checks, builds application Docker images and pushes them to the container registry. Then, it generates manifests for the deployment targets defined for the first environment in the rollout chain (e.g. *dev*) and places them to the Manifest Storage. Once the Application Team is satisfied with the deployment to the first environment, they promote the change to the next environment, so the CD workflow goes ahead and generates manifests for the deployment targets in that environment.
