# Platform team defines service deployment targets

*Preconditions*:

- Platform Service Source repo exists  

*Postconditions*:

- Service deployment targets are defined in the Platform Service Source repo

Platform Team creates a file in their service source repository containing a list of deployment targets where the service might be deployed in the fleet. Each deployment target references a rollout environment (e.g. *dev*, *stage*) and a place where the manifests for this deployment target are stored. It can be plain K8s manifests, Helm charts, or any other deployment descriptors, stored in a repo or OCI storage or any other storage that a reconciler on the clusters can understand. Each deployment target is marked with a set of custom labels to automatically schedule the deployment target on the clusters in the fleet.




