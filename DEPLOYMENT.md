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

### Installing Prerequisites

#### Ubuntu/Debian

```bash
# Update package lists
sudo apt update

# Install Git
sudo apt install -y git

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Install pnpm
npm install -g pnpm

# Install Go
sudo apt install -y golang-go

# Install Python
sudo apt install -y python3 python3-pip python3-venv

# Install Docker
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# Log out and log back in for group changes to take effect
```

#### macOS

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Git
brew install git

# Install Node.js
brew install node@22

# Install pnpm
npm install -g pnpm

# Install Go
brew install go

# Install Python
brew install python

# Install Docker
brew install --cask docker
# Open Docker Desktop to complete setup
```

#### Windows (with WSL2)

1. Install WSL2 following [Microsoft's instructions](https://docs.microsoft.com/en-us/windows/wsl/install)
2. Install Ubuntu from the Microsoft Store
3. Open Ubuntu and follow the Ubuntu/Debian instructions above
4. Install Docker Desktop for Windows with WSL2 integration enabled

## Configuration

You can customize the deployment by creating a `zeeeepa-config.sh` file in the same directory as the deployment scripts. This file allows you to configure:

- Base directory for all projects
- Repository URLs
- Deployment options
- Docker options
- WSL2 options
- Version requirements

A sample configuration file is provided as `zeeeepa-config.sh.example`. Copy this file to `zeeeepa-config.sh` and customize as needed:

```bash
cp zeeeepa-config.sh.example zeeeepa-config.sh
# Edit zeeeepa-config.sh with your preferred text editor
```

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
export INSTALL_DEPENDENCIES="true"
export VERBOSE_LOGGING="true"
export NON_INTERACTIVE="false"
```

If no configuration file is found, the scripts will use default values.

## Deployment Options

There are two deployment scripts provided:

1. **deploy-stack.sh**: Deploys the complete stack including all components
2. **deploy-essential.sh**: Deploys only the remaining components if you've already deployed ctrlplane and ctrlc-cli

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

### Non-Interactive Deployment

For automated deployments, you can run the scripts in non-interactive mode:

```bash
NON_INTERACTIVE=true ./deploy-stack.sh
```

Or set this in your configuration file:

```bash
export NON_INTERACTIVE="true"
```

### Verbose Logging

To enable detailed logging during deployment, set:

```bash
VERBOSE_LOGGING=true ./deploy-stack.sh
```

Or in your configuration file:

```bash
export VERBOSE_LOGGING="true"
```

Logs will be written to `$ZEEEEPA_BASE_DIR/deployment.log`.

## Detailed Deployment Steps

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
./stack.sh --non-interactive
```

Or to stop all services:

```bash
./stack.sh --stop
```

## Service Management

### Viewing Service Logs

All service logs are stored in the `$ZEEEEPA_BASE_DIR/logs` directory. To view logs for a specific service:

```bash
cat $ZEEEEPA_BASE_DIR/logs/co-reviewer.log
```

Or to follow logs in real-time:

```bash
tail -f $ZEEEEPA_BASE_DIR/logs/co-reviewer.log
```

For Docker services (like ctrlplane), you can view logs with:

```bash
cd $ZEEEEPA_BASE_DIR/ctrlplane
docker compose -f docker-compose.dev.yaml logs -f
```

### Restarting Services

To restart all services:

```bash
./stack.sh --stop
./stack.sh
```

To restart a specific Docker service:

```bash
cd $ZEEEEPA_BASE_DIR/ctrlplane
docker compose -f docker-compose.dev.yaml restart <service-name>
```

## Troubleshooting

### Common Issues

1. **Docker services not starting**: 
   - Ensure Docker is running and you have sufficient permissions
   - Check Docker logs: `docker logs <container_name>`
   - Verify port availability: `netstat -tuln | grep <port_number>`
   - Try restarting Docker: `sudo systemctl restart docker`

2. **Dependency conflicts**: 
   - Make sure you have the correct versions of Node.js, pnpm, Go, and Python
   - Use nvm, pyenv, or similar tools to manage multiple versions
   - Check the error logs in `$ZEEEEPA_BASE_DIR/deployment.log`

3. **Port conflicts**: 
   - Check if any of the required ports are already in use
   - Modify the Docker Compose files to use different ports
   - Stop conflicting services before starting the stack

4. **Disk space issues**:
   - Ensure you have at least 5GB of free disk space
   - Run `df -h` to check available space
   - Clean up Docker resources: `docker system prune -a`

5. **Permission issues**:
   - Ensure you have write permissions to the installation directory
   - For Docker issues, make sure your user is in the docker group
   - Check file permissions with `ls -la`

### Diagnostic Commands

Here are some useful commands for diagnosing issues:

```bash
# Check Docker status
docker info
docker ps

# Check port usage
netstat -tuln
ss -tuln

# Check disk space
df -h

# Check service logs
tail -f $ZEEEEPA_BASE_DIR/logs/*.log

# Check Docker logs
docker logs $(docker ps -q --filter "name=ctrlplane")
```

## Maintenance

### Updating Components

To update individual components:

1. Navigate to the component directory
2. Pull the latest changes: `git pull`
3. Rebuild the component following the installation steps above

Or use the deployment scripts with the `--update` flag:

```bash
./deploy-stack.sh --update
```

### Backing Up Data

The ctrlplane database is stored in a Docker volume. To back it up:

```bash
# Find the volume
docker volume inspect ctrlplane_db-data

# Note the Mountpoint
sudo cp -r /path/to/mountpoint /backup/location
```

For a more comprehensive backup:

```bash
# Create a backup directory
mkdir -p ~/zeeeepa-backups/$(date +%Y%m%d)

# Backup Docker volumes
docker run --rm -v ctrlplane_db-data:/source -v ~/zeeeepa-backups/$(date +%Y%m%d):/backup alpine tar -czf /backup/db-data.tar.gz -C /source .

# Backup configuration files
cp $ZEEEEPA_BASE_DIR/ctrlplane/.env ~/zeeeepa-backups/$(date +%Y%m%d)/ctrlplane.env
cp $ZEEEEPA_BASE_DIR/co-reviewer/.env ~/zeeeepa-backups/$(date +%Y%m%d)/co-reviewer.env
```

### Restoring from Backup

To restore from a backup:

```bash
# Restore Docker volumes
docker run --rm -v ctrlplane_db-data:/target -v ~/zeeeepa-backups/20250504:/backup alpine sh -c "rm -rf /target/* && tar -xzf /backup/db-data.tar.gz -C /target"

# Restore configuration files
cp ~/zeeeepa-backups/20250504/ctrlplane.env $ZEEEEPA_BASE_DIR/ctrlplane/.env
cp ~/zeeeepa-backups/20250504/co-reviewer.env $ZEEEEPA_BASE_DIR/co-reviewer/.env
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

### Environment Variables

The default `.env.example` files contain development credentials. For production:
- Use strong, unique passwords
- Store sensitive credentials securely
- Consider using a secrets management solution

### Network Security

- Restrict network access to the services as appropriate for your environment
- Use firewalls to limit access to required ports only
- Consider using a reverse proxy with TLS for public-facing services

### File Permissions

- Set appropriate file permissions for sensitive files
- Ensure configuration files are not world-readable
- Use proper ownership for service directories

### Docker Security

- Keep Docker and all images updated
- Use non-root users in containers where possible
- Limit container capabilities and resources

### Authentication

- Implement proper authentication for all services
- Use OAuth or similar for GitHub integrations
- Rotate credentials regularly

## Production Deployment

For production deployments, additional considerations are recommended:

1. **High Availability**:
   - Deploy critical services with redundancy
   - Use container orchestration like Kubernetes
   - Implement proper health checks and auto-recovery

2. **Monitoring**:
   - Set up monitoring for all services
   - Implement alerting for critical issues
   - Track resource usage and performance metrics

3. **Backup Strategy**:
   - Implement regular automated backups
   - Test backup restoration procedures
   - Store backups securely off-site

4. **CI/CD Integration**:
   - Automate deployment with CI/CD pipelines
   - Implement proper testing before deployment
   - Use infrastructure as code for consistency

## Support

If you encounter any issues with the deployment, please:

1. Check the troubleshooting section above
2. Review the logs in `$ZEEEEPA_BASE_DIR/logs`
3. Open an issue in the respective repository
4. Contact the Zeeeepa team for assistance

## Additional Resources

- [ctrlplane Documentation](https://github.com/Zeeeepa/ctrlplane)
- [ctrlc-cli Documentation](https://github.com/Zeeeepa/ctrlc-cli)
- [weave Documentation](https://github.com/Zeeeepa/weave)
- [probot Documentation](https://github.com/Zeeeepa/probot)
- [pkg.pr.new Documentation](https://github.com/Zeeeepa/pkg.pr.new)
- [tldr Documentation](https://github.com/Zeeeepa/tldr)
- [co-reviewer Documentation](https://github.com/Zeeeepa/co-reviewer)

