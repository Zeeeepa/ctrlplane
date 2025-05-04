#!/bin/bash

# Zeeeepa Stack Configuration File
# Edit this file to customize your deployment

# Base directory for all projects
export ZEEEEPA_BASE_DIR="$HOME/zeeeepa-stack"

# Repository URLs
export CTRLPLANE_REPO="https://github.com/ctrlplanedev/ctrlplane.git"
export CTRLC_CLI_REPO="https://github.com/Zeeeepa/ctrlc-cli"
export WEAVE_REPO="https://github.com/Zeeeepa/weave"
export PROBOT_REPO="https://github.com/Zeeeepa/probot"
export PKG_PR_NEW_REPO="https://github.com/Zeeeepa/pkg.pr.new"
export TLDR_REPO="https://github.com/Zeeeepa/tldr"
export CO_REVIEWER_REPO="https://github.com/Zeeeepa/co-reviewer"

# Deployment options
export AUTO_START_SERVICES="true"  # Automatically start services after deployment
export INSTALL_DEPENDENCIES="false"  # Attempt to install missing dependencies
export VERBOSE_LOGGING="false"  # Enable verbose logging
export NON_INTERACTIVE="false"  # Run in non-interactive mode

# Docker options
export DOCKER_COMPOSE_FILE="docker-compose.dev.yaml"  # Docker compose file to use

# WSL2 options
export WSL2_AUTOSTART="true"  # Add stack.sh to .bashrc for WSL2 startup

# Version requirements
export NODE_MIN_VERSION="22.10.0"
export PNPM_MIN_VERSION="10.2.0"
export GO_MIN_VERSION="1.20.0"
export PYTHON_MIN_VERSION="3.8.0"

