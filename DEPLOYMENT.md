# Zeeeepa Stack Deployment Guide

This guide provides comprehensive instructions for deploying the complete Zeeeepa stack, which includes:

- **ctrlplane**: A deployment orchestration tool
- **ctrlc-cli**: CLI for ctrlplane
- **weave**: AI toolkit for developing applications by Weights & Biases
- **probot**: Framework for building GitHub Apps
- **pkg.pr.new**: Continuous preview releases for libraries
- **tldr**: PR summarizer tool
- **co-reviewer**: Code review assistant

## Prerequisites

Before starting the deployment, ensure you have the following prerequisites installed:

- **Git**: For cloning repositories
- **Docker and Docker Compose**: For containerized deployment
- **Node.js (v22+) and pnpm**: For JavaScript-based services
- **Python 3.9+ and pip**: For Python-based services
- **Go**: For building ctrlc-cli

## Deployment Options

### Option 1: Full Stack Deployment

If you're starting from scratch and want to deploy the entire stack:

1. Clone the ctrlplane repository:
   ```bash
   git clone https://github.com/Zeeeepa/ctrlplane.git
   cd ctrlplane
   ```

2. Make the deployment script executable:
   ```bash
   chmod +x deploy-stack.sh
   ```

3. Run the deployment script:
   ```bash
   ./deploy-stack.sh
   ```

4. Start the stack using Docker Compose:
   ```bash
   docker-compose -f docker-compose.stack.yaml up -d
   ```

### Option 2: Essential Components Deployment

If you've already deployed ctrlplane and ctrlc-cli and only want to deploy the remaining components:

1. Clone the ctrlplane repository:
   ```bash
   git clone https://github.com/Zeeeepa/ctrlplane.git
   cd ctrlplane
   ```

2. Make the essential deployment script executable:
   ```bash
   chmod +x deploy-essential.sh
   ```

3. Run the essential deployment script:
   ```bash
   ./deploy-essential.sh
   ```

4. Start the essential components using Docker Compose:
   ```bash
   docker-compose -f docker-compose.essential.yaml up -d
   ```

5. Integrate with your existing ctrlplane installation:
   ```bash
   ./integrate-with-ctrlplane.sh
   ```

## Configuration Options

Both deployment scripts accept the following command-line options:

- `--workspace <directory>`: Specify a custom workspace directory
  ```bash
  ./deploy-stack.sh --workspace /path/to/custom/workspace
  ```

- `--skip-existing`: Skip setup for components that already exist
  ```bash
  ./deploy-stack.sh --skip-existing
  ```

## Component Details

### ctrlplane

A deployment orchestration tool that simplifies multi-cloud, multi-region, and multi-service deployments.

- **Port**: 3000
- **Dependencies**: PostgreSQL, Redis
- **Configuration**: Copy `.env.example` to `.env` and update with your settings

### ctrlc-cli

Command-line interface for ctrlplane, built with Go.

- **Installation**: The deployment script builds and installs ctrlc-cli
- **Usage**: Run `ctrlc --help` for available commands

### weave

A toolkit for developing AI-powered applications, built by Weights & Biases.

- **Port**: 3005
- **Dependencies**: Python 3.9+
- **Configuration**: No additional configuration required for basic usage

### probot

A framework for building GitHub Apps to automate and improve your workflow.

- **Port**: 3002
- **Dependencies**: Node.js
- **Configuration**: Requires GitHub App credentials for production use

### pkg.pr.new

Continuous preview releases for libraries.

- **Port**: 3003
- **Dependencies**: Node.js, pnpm
- **Configuration**: No additional configuration required for basic usage

### tldr

PR summarizer tool.

- **Port**: 3004
- **Dependencies**: Python 3.8+
- **Configuration**: Requires OpenAI API key for production use

### co-reviewer

Code review assistant.

- **Port**: 3001
- **Dependencies**: Node.js, pnpm
- **Configuration**: Copy `.env.example` to `.env` and update with your GitHub credentials

## Docker Compose Configuration

The deployment scripts generate Docker Compose configurations:

- `docker-compose.stack.yaml`: Configuration for the entire stack
- `docker-compose.essential.yaml`: Configuration for the essential components (excluding ctrlplane and ctrlc-cli)

### Network Configuration

All services are connected to a shared Docker network called `zeeeepa-network`, allowing them to communicate with each other.

### Volume Configuration

Persistent data is stored in Docker volumes:

- `postgres-data`: For PostgreSQL database
- `redis-data`: For Redis cache

## Troubleshooting

### Common Issues

1. **Docker Compose not found**:
   ```bash
   sudo apt-get install docker-compose-plugin
   ```

2. **Permission denied when running scripts**:
   ```bash
   chmod +x script-name.sh
   ```

3. **Port conflicts**:
   Edit the Docker Compose files to change the port mappings if you have services already running on the specified ports.

4. **Database connection issues**:
   Ensure PostgreSQL is running and accessible. Check the connection string in the environment variables.

### Viewing Logs

To view logs for a specific service:

```bash
docker-compose -f docker-compose.stack.yaml logs -f service-name
```

Replace `service-name` with one of: ctrlplane-api, ctrlplane-worker, co-reviewer, probot, pkg-pr-new, tldr, weave.

## Maintenance

### Updating Components

To update a component to the latest version:

1. Navigate to the component's directory:
   ```bash
   cd component-name
   ```

2. Pull the latest changes:
   ```bash
   git pull
   ```

3. Rebuild and restart the service:
   ```bash
   docker-compose -f ../docker-compose.stack.yaml build service-name
   docker-compose -f ../docker-compose.stack.yaml up -d service-name
   ```

### Backup and Restore

To backup the PostgreSQL and Redis data:

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

## Security Considerations

1. **Environment Variables**: Never commit sensitive environment variables to version control. Use `.env` files and add them to `.gitignore`.

2. **Network Security**: By default, the Docker Compose configuration exposes ports to the host machine. In production, consider using a reverse proxy like Nginx or Traefik with HTTPS.

3. **Database Security**: Change the default PostgreSQL credentials in production environments.

4. **API Keys**: Secure all API keys and access tokens. Consider using a secrets management solution for production deployments.

## Production Deployment Recommendations

For production deployments, consider the following additional steps:

1. **High Availability**: Set up multiple instances of critical services with load balancing.

2. **Monitoring**: Implement monitoring and alerting using tools like Prometheus and Grafana.

3. **Backups**: Schedule regular automated backups of all persistent data.

4. **CI/CD**: Set up continuous integration and deployment pipelines for automated updates.

5. **Scaling**: Configure resource limits and scaling policies based on your workload requirements.

## Support and Resources

- **ctrlplane**: [GitHub Repository](https://github.com/Zeeeepa/ctrlplane)
- **ctrlc-cli**: [GitHub Repository](https://github.com/Zeeeepa/ctrlc-cli)
- **weave**: [GitHub Repository](https://github.com/Zeeeepa/weave)
- **probot**: [GitHub Repository](https://github.com/Zeeeepa/probot)
- **pkg.pr.new**: [GitHub Repository](https://github.com/Zeeeepa/pkg.pr.new)
- **tldr**: [GitHub Repository](https://github.com/Zeeeepa/tldr)
- **co-reviewer**: [GitHub Repository](https://github.com/Zeeeepa/co-reviewer)

For additional support, please open an issue in the respective repository.

