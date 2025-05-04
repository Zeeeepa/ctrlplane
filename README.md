# Zeeeepa Stack Deployment Scripts

This repository contains scripts and configurations to seamlessly deploy the Zeeeepa stack, which includes:

- **ctrlplane**: A deployment orchestration tool
- **ctrlc-cli**: CLI for ctrlplane
- **weave**: AI toolkit for developing applications by Weights & Biases
- **probot**: Framework for building GitHub Apps
- **pkg.pr.new**: Continuous preview releases for libraries
- **tldr**: PR summarizer tool
- **co-reviewer**: Code review assistant

## Prerequisites

The deployment scripts will check for and help install most dependencies, but it's recommended to have the following installed:

- Git
- Docker and Docker Compose
- Node.js (v22+) and pnpm
- Python 3.9+ and pip
- Go (for ctrlc-cli)

## Deployment Options

### Option 1: Full Stack Deployment

If you haven't deployed any components yet, use the full stack deployment script:

```bash
# Make the script executable
chmod +x deploy-stack.sh

# Run the deployment script
./deploy-stack.sh
```

This will:
1. Clone all repositories
2. Set up each component
3. Create Docker Compose configuration
4. Provide instructions for starting the stack

### Option 2: Essential Components Deployment

If you've already deployed ctrlplane and ctrlc-cli, use the essential components deployment script:

```bash
# Make the script executable
chmod +x deploy-essential.sh

# Run the deployment script
./deploy-essential.sh
```

This will:
1. Clone the remaining repositories (weave, probot, pkg.pr.new, tldr, co-reviewer)
2. Set up each component
3. Create Docker Compose configuration for the essential components
4. Provide an integration script to register services with ctrlplane

## Configuration Options

Both scripts accept the following command-line options:

- `--workspace <directory>`: Specify the workspace directory (default: ./zeeeepa-stack or ./zeeeepa-essential)
- `--skip-existing`: Skip setup for existing components

Example:
```bash
./deploy-stack.sh --workspace /path/to/workspace --skip-existing
```

## Docker Compose Configuration

The deployment scripts generate Docker Compose configurations:

- `docker-compose.stack.yaml`: Configuration for the entire stack
- `docker-compose.essential.yaml`: Configuration for the essential components

To start the stack using Docker Compose:

```bash
# For the full stack
docker-compose -f docker-compose.stack.yaml up -d

# For the essential components
docker-compose -f docker-compose.essential.yaml up -d
```

## Integration with Existing ctrlplane

If you've already deployed ctrlplane and ctrlc-cli, you can integrate the essential components with your existing ctrlplane installation using the provided integration script:

```bash
# Make the script executable
chmod +x integrate-with-ctrlplane.sh

# Run the integration script
./integrate-with-ctrlplane.sh
```

## Component Details

### ctrlplane

A deployment orchestration tool that simplifies multi-cloud, multi-region, and multi-service deployments.

- **Port**: 3000
- **Dependencies**: PostgreSQL, Redis

### ctrlc-cli

CLI for ctrlplane, built with Go.

### weave

A toolkit for developing AI-powered applications, built by Weights & Biases.

- **Port**: 3005
- **Dependencies**: Python 3.9+

### probot

A framework for building GitHub Apps to automate and improve your workflow.

- **Port**: 3002
- **Dependencies**: Node.js

### pkg.pr.new

Continuous preview releases for libraries.

- **Port**: 3003
- **Dependencies**: Node.js, pnpm

### tldr

PR summarizer tool.

- **Port**: 3004
- **Dependencies**: Python 3.8+

### co-reviewer

Code review assistant.

- **Port**: 3001
- **Dependencies**: Node.js, pnpm

## Troubleshooting

### Common Issues

1. **Docker Compose not found**: Install Docker Compose using your package manager or follow the [official installation guide](https://docs.docker.com/compose/install/).

2. **Permission denied when running scripts**: Make the scripts executable with `chmod +x script-name.sh`.

3. **Port conflicts**: If you have services already running on the specified ports, edit the Docker Compose files to use different ports.

4. **Database connection issues**: Ensure PostgreSQL is running and accessible. Check the connection string in the environment variables.

### Logs

To view logs for a specific service:

```bash
docker-compose -f docker-compose.stack.yaml logs -f service-name
```

Replace `service-name` with one of: ctrlplane-api, ctrlplane-worker, co-reviewer, probot, pkg-pr-new, tldr, weave.

## Maintenance

### Updating Components

To update a component to the latest version:

1. Navigate to the component's directory
2. Pull the latest changes: `git pull`
3. Rebuild the Docker image: `docker-compose -f ../docker-compose.stack.yaml build service-name`
4. Restart the service: `docker-compose -f ../docker-compose.stack.yaml up -d service-name`

### Backup and Restore

The PostgreSQL and Redis data are stored in Docker volumes. To backup these volumes:

```bash
# Backup PostgreSQL data
docker run --rm -v zeeeepa-stack_postgres-data:/data -v $(pwd):/backup alpine tar -czf /backup/postgres-backup.tar.gz /data

# Backup Redis data
docker run --rm -v zeeeepa-stack_redis-data:/data -v $(pwd):/backup alpine tar -czf /backup/redis-backup.tar.gz /data
```

To restore from backups:

```bash
# Restore PostgreSQL data
docker run --rm -v zeeeepa-stack_postgres-data:/data -v $(pwd):/backup alpine sh -c "rm -rf /data/* && tar -xzf /backup/postgres-backup.tar.gz -C /"

# Restore Redis data
docker run --rm -v zeeeepa-stack_redis-data:/data -v $(pwd):/backup alpine sh -c "rm -rf /data/* && tar -xzf /backup/redis-backup.tar.gz -C /"
```

## License

Each component is subject to its own license. Please refer to the LICENSE file in each component's repository.

