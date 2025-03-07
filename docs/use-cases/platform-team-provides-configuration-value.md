# Platform team provides a configuration value for a service deployment target

*Preconditions*:

- Platform Service Config repo exists

*Postconditions*:

- Configuration value for the deployment target is set in the Platform Service Config repo

Platform Service Config repo contains configuration branches with configuration values for each environment. Each configuration branch contain folders representing deployment targets. Platform Team creates a file in a corresponding folder of the configuration branch with the config values. These values are used by the service CI/CD pipeline to generate manifests for this deployment target.
