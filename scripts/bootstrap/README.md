# Bootstrap Script Structure

This directory contains the Kalypso Scheduler bootstrapping script and its supporting libraries.

## Directory Structure

```text
scripts/bootstrap/
├── bootstrap.sh              # Main entry point
├── lib/                      # Library modules
│   ├── utils.sh             # Utility functions (logging, JSON processing)
│   ├── prerequisites.sh     # Prerequisites and authentication validation
│   ├── config.sh            # Configuration management and CLI parsing
│   ├── cluster.sh           # AKS cluster operations
│   ├── repositories.sh      # GitHub repository management
│   └── install.sh           # Kalypso installation and verification
├── templates/               # Repository templates
│   ├── control-plane/       # Control-plane repository templates
│   │   ├── main/           # Main branch structure
│   │   └── dev/            # Dev branch structure
│   └── gitops/             # GitOps repository templates
│       ├── main/           # Main branch structure
│       └── dev/            # Dev branch structure
└── README.md               # This file
```

## Quick Start

Run the script in interactive mode:

```bash
cd scripts/bootstrap
./bootstrap.sh
```

Or with a configuration file:

```bash
./bootstrap.sh --config kalypso-config.yaml
```

For detailed usage, see [../../docs/bootstrap/README.md](../../docs/bootstrap/README.md)

## Development

### Linting

Use shellcheck to validate all scripts:

```bash
shellcheck bootstrap.sh lib/*.sh
```

## Library Modules

### utils.sh

Core utilities used by all other modules:

- Logging functions (log_error, log_warning, log_info, log_debug, log_success)
- JSON processing (json_get_value)
- String utilities (is_empty, trim, to_lower, to_upper)
- Command utilities (command_exists, wait_for_condition)
- User interaction (confirm, prompt_input)

### prerequisites.sh

Prerequisites validation:

- Required tool checking (kubectl, az, git, helm, gh, jq)
- Optional tool checking (yq - required for YAML config files)
- Version comparison
- Azure authentication validation
- GitHub authentication validation

### config.sh

Configuration management:

- CLI argument parsing
- Configuration file loading (YAML, JSON, ENV formats)
- Interactive prompts for missing values
- Configuration validation
- Resource tracking for rollback

### cluster.sh

AKS cluster operations:

- Cluster creation with resource group
- Existing cluster validation
- Kubeconfig integration
- Cluster readiness checks
- Namespace creation
- Idempotent operations

### repositories.sh

GitHub repository management:

- Repository creation via GitHub API with custom names
- Repository initialization with structured templates
- Control-plane repository setup (main and dev branches)
- GitOps repository setup (main and dev branches)
- Repository validation
- GitHub secrets configuration (via gh CLI)

### install.sh

Kalypso installation:

- Helm chart installation
- Installation verification
- CRD checking
- Rollback functionality

## Error Handling

All library functions follow these conventions:

- Return 0 on success, 1 on error
- Log errors using log_error function
- Use log_debug for diagnostic information
- Validate inputs before processing
- Provide helpful error messages

## Configuration Variables

Key global variables (set by config.sh):

**Cluster Configuration:**

- `CREATE_CLUSTER` - Boolean flag for cluster creation (default: false, uses existing)
- `CLUSTER_NAME` - AKS cluster name (required)
- `RESOURCE_GROUP` - Azure resource group (required)
- `LOCATION` - Azure region (required for new clusters)
- `NODE_COUNT` - Number of cluster nodes (default: 1)
- `NODE_SIZE` - VM size for nodes (default: Standard_DS2_v2)

**Repository Configuration:**

- `CREATE_REPOS` - Boolean flag for repository creation
- `CONTROL_PLANE_REPO` - Repository name when creating, or full URL when using existing
- `GITOPS_REPO` - Repository name when creating, or full URL when using existing
- `GITHUB_ORG` - GitHub organization (optional, defaults to user account)

**Other:**

- `KALYPSO_NAMESPACE` - Kubernetes namespace for Kalypso (default: kalypso-system)
- `INTERACTIVE_MODE` - Boolean for interactive prompts (default: true)
- `AUTO_ROLLBACK` - Boolean for automatic rollback on failure (default: false)

## Documentation

Comprehensive documentation is available in `docs/bootstrap/`:

- [README.md](../../docs/bootstrap/README.md) - Main documentation
- [prerequisites.md](../../docs/bootstrap/prerequisites.md) - Prerequisites and setup
- [quickstart.md](../../docs/bootstrap/quickstart.md) - Quick start guide
- [troubleshooting.md](../../docs/bootstrap/troubleshooting.md) - Common issues and solutions

## Contributing

When contributing to the bootstrap script:

1. Maintain consistent coding style
2. Follow existing patterns in the codebase
3. Add logging at appropriate levels
4. Handle errors gracefully
5. Update documentation
6. Add tests for new functionality
7. Run shellcheck and fix all warnings/errors

## License

This script is part of the Kalypso Scheduler project and follows the same license.
