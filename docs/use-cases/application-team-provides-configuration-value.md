# Application team provides a configuration value for a deployment target

*Preconditions*:

- Application Source repo exists

*Postconditions*:

- Configuration value for the deployment target is set in the Application Source repo

Application Source repo contains configuration branches with configuration values for each environment. Each configuration branch contain folders representing deployment targets. Application Team creates a file in a corresponding folder of the configuration branch with the config values. These values are used by the application CI/CD pipeline to generate manifests for this deployment target.

Alternatively, Application Team may prefer to use an external storage (e.g. variable groups, key vault, configuration tools, etc.) for the configuration values rather than Git repository.





