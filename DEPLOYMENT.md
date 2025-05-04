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

## Deployment Options

There are two deployment scripts provided:

1. **deploy-stack.sh**: Deploys the complete stack including all components
2. **deploy-essential.sh**: Deploys only the remaining components if you've already deployed ctrlplane and ctrlc-cli

## Detailed Deployment Steps

### Option 1: Full Stack Deployment

To deploy the entire stack, run:

```bash
./deploy-stack.sh
```

This script will:
1. Check for all required dependencies
2. Clone all repositories into a central directory
3. Build and configure each component
4. Set up the necessary environment variables
5. Start all services

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

## Troubleshooting

### Common Issues

1. **Docker services not starting**: Ensure Docker is running and you have sufficient permissions
2. **Dependency conflicts**: Make sure you have the correct versions of Node.js, pnpm, Go, and Python
3. **Port conflicts**: Check if any of the required ports are already in use

### Logs

To view logs for the ctrlplane services:

```bash
docker compose -f docker-compose.dev.yaml logs -f
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

## Security Considerations

- The default `.env.example` file contains development credentials. For production, use strong, unique passwords
- Consider setting up proper authentication for all services
- Restrict network access to the services as appropriate for your environment

## Support

If you encounter any issues with the deployment, please open an issue in the respective repository or contact the Zeeeepa team for assistance.

