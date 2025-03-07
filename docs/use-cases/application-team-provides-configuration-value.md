# Application team provides a configuration value for a deployment target

*Preconditions*:

- Application Config repo exists

*Postconditions*:

- Configuration value for the deployment target is set in the Application Config repo

Application Config repo contains configuration branches with configuration values for each environment. Each configuration branch contain folders representing deployment targets. Application Team creates a file in a corresponding folder of the configuration branch with the config values. These values are used by the application CI/CD pipeline to generate manifests for this deployment target.

> Refer to the runbook [Application Team Manages Application Configuration](../run-books/application-team-manages-application-configuration.md).
