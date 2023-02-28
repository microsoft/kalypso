# Application team defines application deployment targets

*Preconditions*:

- Application Source repo exists  

*Postconditions*:

- Application deployment targets are defined in the Application Source repo

Application Team creates a file in their source repository containing a list of deployment targets where the application might be deployed during its lifecycle. Each deployment target references a rollout environment (e.g. *dev*, *stage*) and a place where the manifests for this deployment target are stored. It can be plain K8s manifests, Helm charts, or any other deployment descriptors, stored in a repo or OCI storage or any other storage that a reconciler on the clusters can understand. Each deployment target is marked with a set of custom labels that the Platform Team uses to schedule the deployment target on the clusters in the fleet.
