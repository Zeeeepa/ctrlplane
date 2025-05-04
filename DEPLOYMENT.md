# Zeeeepa Stack Deployment Guide

This guide provides comprehensive instructions for deploying the complete Zeeeepa stack, which includes the following components:

- **ctrlplane**: A deployment orchestration tool
- **ctrlc-cli**: CLI for ctrlplane
- **weave**: AI toolkit for developing applications by Weights & Biases
- **probot**: Framework for building GitHub Apps
- **pkg.pr.new**: Continuous preview releases for libraries
- **tldr**: PR summarizer tool
- **co-reviewer**: Code review tool

## Prerequisites

Before you begin, ensure you have the following installed:

- **Git**: For cloning repositories
- **Node.js**: v22.10.0 or later
- **pnpm**: v10.2.0 or later
- **Go**: v1.20 or later (for ctrlc-cli)
- **Python**: v3.8 or later (for weave and tldr)
- **Docker**: For running containerized services
- **WSL2**: If deploying on Windows
- **Disk Space**: At least 5GB of free disk space

## Deployment Options

There are two deployment scripts provided:

1. **deploy-stack.sh**: Deploys the complete stack including all components
2. **deploy-essential.sh**: Deploys only the remaining components if you've already deployed ctrlplane and ctrlc-cli

## Configuration

You can customize the deployment by creating a `zeeeepa-config.sh` file in the same directory as the deployment scripts. This file allows you to configure:

- Base directory for all projects
- Repository URLs
- Deployment options
- Docker options
- WSL2 options
- Version requirements

Example configuration:

```bash
#!/bin/bash

# Base directory for all projects
export ZEEEEPA_BASE_DIR="$HOME/zeeeepa-stack"

# Repository URLs
export CTRLPLANE_REPO="https://github.com/ctrlplanedev/ctrlplane.git"
export CTRLC_CLI_REPO="https://github.com/Zeeeepa/ctrlc-cli"

# Deployment options
export AUTO_START_SERVICES="true"
export INSTALL_DEPENDENCIES="false"
export VERBOSE_LOGGING="false"
export NON_INTERACTIVE="false"
```

If no configuration file is found, the scripts will use default values.

## Detailed Deployment Steps

### Option 1: Full Stack Deployment

To deploy the entire stack, run:

```bash
./deploy-stack.sh
```

This script will:
1. Check for all required dependencies
2. Verify sufficient disk space
3. Clone all repositories into a central directory
4. Build and configure each component
5. Set up the necessary environment variables
6. Start all services

### Option 2: Essential Components Deployment

If you've already deployed ctrlplane and ctrlc-cli, you can deploy the remaining components with:

```bash
./deploy-essential.sh
```

### Manual Deployment Steps

If you prefer to deploy components manually, follow these steps:

#### 1. ctrlplane

```bash
git clone https://github.com/ctrlplanedev/ctrlplane.git
cd ctrlplane
cp .env.example .env
pnpm install
pnpm build
docker compose -f docker-compose.dev.yaml up -d
cd packages/db && pnpm migrate && cd ../..
```

#### 2. ctrlc-cli

```bash
git clone https://github.com/Zeeeepa/ctrlc-cli/
cd ctrlc-cli
make build
make install
```

#### 3. weave

```bash
git clone https://github.com/Zeeeepa/weave
cd weave
pip install -e .
```

#### 4. probot

```bash
git clone https://github.com/Zeeeepa/probot
cd probot
npm install
npm run build
```

#### 5. pkg.pr.new

```bash
git clone https://github.com/Zeeeepa/pkg.pr.new
cd pkg.pr.new
pnpm install
pnpm build
```

#### 6. tldr

```bash
git clone https://github.com/Zeeeepa/tldr
cd tldr
pip install -e .
```

#### 7. co-reviewer

```bash
git clone https://github.com/Zeeeepa/co-reviewer
cd co-reviewer
cp .env.example .env
pnpm install
pnpm build
```

## Starting the Stack

After deployment, you can start all services by running:

```bash
./stack.sh
```

This script will prompt you with "Do You Want To Run CtrlPlane Stack? Y/N" when starting up your WSL2 instance. Pressing Y will start all services.

You can also run the script in non-interactive mode:

```bash
NON_INTERACTIVE=true ./stack.sh
```

## Troubleshooting

### Common Issues

1. **Docker services not starting**: 
   - Ensure Docker is running and you have sufficient permissions
   - Check Docker logs: `docker logs <container_name>`
   - Verify port availability: `netstat -tuln | grep <port_number>`

2. **Dependency conflicts**: 
   - Make sure you have the correct versions of Node.js, pnpm, Go, and Python
   - Use nvm, pyenv, or similar tools to manage multiple versions

3. **Port conflicts**: 
   - Check if any of the required ports are already in use
   - Modify the Docker Compose files to use different ports

4. **Disk space issues**:
   - Ensure you have at least 5GB of free disk space
   - Run `df -h` to check available space

### Logs

To view logs for the ctrlplane services:

```bash
docker compose -f docker-compose.dev.yaml logs -f
```

For more verbose logging during deployment, edit the `zeeeepa-config.sh` file and set:

```bash
export VERBOSE_LOGGING="true"
```

## Maintenance

### Updating Components

To update individual components:

1. Navigate to the component directory
2. Pull the latest changes: `git pull`
3. Rebuild the component following the installation steps above

### Backing Up Data

The ctrlplane database is stored in a Docker volume. To back it up:

```bash
docker volume inspect ctrlplane_db-data
# Note the Mountpoint
sudo cp -r /path/to/mountpoint /backup/location
```

## Uninstallation

To remove the Zeeeepa stack from your system, run:

```bash
./uninstall.sh
```

This script will:
1. Stop all running services
2. Remove the stack directory
3. Remove the WSL2 autostart entry (if applicable)

**Warning**: This will remove all data and configurations. Make sure to back up any important data before uninstalling.

## Security Considerations

- The default `.env.example` file contains development credentials. For production, use strong, unique passwords
- Consider setting up proper authentication for all services
- Restrict network access to the services as appropriate for your environment
- Set appropriate file permissions for sensitive files

## Support

If you encounter any issues with the deployment, please open an issue in the respective repository or contact the Zeeeepa team for assistance.
