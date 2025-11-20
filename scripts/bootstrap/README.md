# Bootstrap Script Structure

This directory contains the Kalypso Scheduler bootstrapping script and its supporting libraries.

## Directory Structure

```
scripts/bootstrap/
├── bootstrap.sh              # Main entry point
├── lib/                      # Library modules
│   ├── utils.sh             # Utility functions (logging, JSON processing)
│   ├── prerequisites.sh     # Prerequisites and authentication validation
│   ├── config.sh            # Configuration management and CLI parsing
│   ├── cluster.sh           # AKS cluster operations
│   ├── repositories.sh      # GitHub repository management
│   └── install.sh           # Kalypso installation and verification
├── templates/               # Configuration templates
│   └── config.yaml          # Sample configuration file
├── tests/                   # Test scripts
│   └── smoke-test.sh        # Basic functionality tests
└── .shellcheckrc            # ShellCheck linting configuration
```

## Quick Start

Run the script in interactive mode:

```bash
./bootstrap.sh
```

Or use a configuration file:

```bash
./bootstrap.sh --config templates/config.yaml
```

For detailed usage, see [../../docs/bootstrap/README.md](../../docs/bootstrap/README.md)

## Development

### Running Tests

```bash
./tests/smoke-test.sh
```

### Linting

```bash
shellcheck bootstrap.sh lib/*.sh
```

### Adding New Features

1. Add new functions to appropriate library file in `lib/`
2. Follow existing patterns (logging, error handling)
3. Document functions with header comments
4. Add tests to `tests/smoke-test.sh`
5. Run shellcheck and tests before committing

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

- Required tool checking (kubectl, az, git, helm)
- Optional tool checking (jq, yq, python3)
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

- Repository creation via GitHub API
- Repository initialization with minimal structure
- Control-plane repository setup
- GitOps repository setup
- Repository validation

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

- `CLUSTER_NAME` - AKS cluster name
- `RESOURCE_GROUP` - Azure resource group
- `LOCATION` - Azure region
- `NODE_COUNT` - Number of cluster nodes
- `NODE_SIZE` - VM size for nodes
- `CONTROL_PLANE_REPO` - Control-plane repository URL
- `GITOPS_REPO` - GitOps repository URL
- `GITHUB_ORG` - GitHub organization (optional)
- `CREATE_CLUSTER` - Boolean flag for cluster creation
- `CREATE_REPOS` - Boolean flag for repository creation

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
