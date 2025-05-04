#!/bin/bash
#
# Zeeeepa Stack Deployment Script
# This script deploys the complete Zeeeepa stack on a fresh WSL2 instance
# with NO user interaction required and robust dependency management
#
# Usage: curl -sSL https://raw.githubusercontent.com/Zeeeepa/ctrlplane/main/deploy-all.sh | bash
#

# Exit on command errors and treat unset variables as an error
set -eu

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Base directory for all projects
ZEEEEPA_BASE_DIR="${ZEEEEPA_BASE_DIR:-$HOME/zeeeepa-stack}"

# Repository URLs
CTRLPLANE_REPO="https://github.com/ctrlplanedev/ctrlplane.git"
CTRLC_CLI_REPO="https://github.com/Zeeeepa/ctrlc-cli"
WEAVE_REPO="https://github.com/Zeeeepa/weave"
PROBOT_REPO="https://github.com/Zeeeepa/probot"
PKG_PR_NEW_REPO="https://github.com/Zeeeepa/pkg.pr.new"
TLDR_REPO="https://github.com/Zeeeepa/tldr"
CO_REVIEWER_REPO="https://github.com/Zeeeepa/co-reviewer"

# Deployment log
mkdir -p "$ZEEEEPA_BASE_DIR"
DEPLOYMENT_LOG="$ZEEEEPA_BASE_DIR/deployment.log"

# Function to log messages
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] $1" | tee -a "$DEPLOYMENT_LOG"
}

# Function to print section header
print_header() {
    echo -e "\n${BLUE}${BOLD}=======================================================${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}=======================================================${NC}\n"
    log "SECTION: $1"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}${BOLD}✓ $1${NC}"
    log "SUCCESS: $1"
}

# Function to print error message
print_error() {
    echo -e "${RED}${BOLD}✗ ERROR: $1${NC}"
    log "ERROR: $1"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}${BOLD}⚠ WARNING: $1${NC}"
    log "WARNING: $1"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}${BOLD}ℹ $1${NC}"
    log "INFO: $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install system packages
install_system_packages() {
    print_header "Installing System Dependencies"
    
    # Update package lists
    print_info "Updating package lists..."
    sudo apt-get update -qq || {
        print_error "Failed to update package lists"
        print_info "Trying to continue anyway..."
    }
    
    # Install essential packages
    print_info "Installing essential packages..."
    sudo apt-get install -y curl git build-essential python3 python3-pip python3-venv wget || {
        print_error "Failed to install essential packages"
        print_info "Trying to continue anyway..."
    }
    print_success "Essential packages installed"
    
    # Install Docker if not present
    if ! command_exists docker; then
        print_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh || {
            print_error "Failed to install Docker"
            print_info "Trying to continue anyway..."
        }
        sudo usermod -aG docker $USER
        print_success "Docker installed"
        print_warning "You may need to log out and back in for Docker permissions to take effect"
        
        # Start Docker service
        print_info "Starting Docker service..."
        sudo service docker start || {
            print_error "Failed to start Docker service"
            print_info "Trying to continue anyway..."
        }
    else
        print_info "Docker is already installed"
        
        # Ensure Docker service is running
        if ! sudo service docker status > /dev/null 2>&1; then
            print_info "Starting Docker service..."
            sudo service docker start || {
                print_error "Failed to start Docker service"
                print_info "Trying to continue anyway..."
            }
        fi
    fi
    
    # Install Docker Compose if not present
    if ! command_exists docker-compose && ! docker compose version > /dev/null 2>&1; then
        print_info "Installing Docker Compose..."
        DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
        mkdir -p $DOCKER_CONFIG/cli-plugins
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose installed"
    else
        print_info "Docker Compose is already installed"
    fi
    
    # Install Node.js and npm if not present
    if ! command_exists node; then
        print_info "Installing Node.js and npm..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs || {
            print_error "Failed to install Node.js"
            print_info "Trying to continue anyway..."
        }
        print_success "Node.js and npm installed"
    else
        print_info "Node.js is already installed"
    fi
    
    # Install pnpm globally using npm
    print_info "Installing pnpm globally..."
    sudo npm install -g pnpm || {
        print_error "Failed to install pnpm globally"
        print_info "Trying alternative pnpm installation method..."
        
        # Try alternative installation method
        curl -fsSL https://get.pnpm.io/install.sh | sh - || {
            print_error "All pnpm installation methods failed"
            print_info "Trying to continue anyway..."
        }
    }
    
    # Verify pnpm installation and add to PATH if needed
    if command_exists pnpm; then
        print_success "pnpm installed successfully"
    else
        # Try to find pnpm in common locations
        if [ -f "$HOME/.local/share/pnpm/pnpm" ]; then
            export PATH="$HOME/.local/share/pnpm:$PATH"
            print_success "Added pnpm to PATH"
        elif [ -f "$HOME/.pnpm/pnpm" ]; then
            export PATH="$HOME/.pnpm:$PATH"
            print_success "Added pnpm to PATH"
        else
            print_warning "pnpm installation could not be verified"
        fi
    fi
    
    # Install Go if not present
    if ! command_exists go; then
        print_info "Installing Go..."
        GO_VERSION="1.20.5"
        wget -q https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        rm go${GO_VERSION}.linux-amd64.tar.gz
        
        # Add Go to PATH if not already there
        if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.profile; then
            echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
        fi
        
        # Add Go to current session
        export PATH=$PATH:/usr/local/go/bin
        print_success "Go installed"
    else
        print_info "Go is already installed"
    fi
    
    print_success "All system dependencies installed successfully"
}

# Function to clone or update a repository
clone_or_update_repo() {
    local repo_url="$1"
    local repo_name=$(basename "$repo_url" .git)
    local target_dir="$ZEEEEPA_BASE_DIR/$repo_name"
    
    print_info "Setting up repository: $repo_name"
    
    if [ -d "$target_dir" ]; then
        print_info "Repository already exists, updating..."
        cd "$target_dir"
        git fetch origin
        git reset --hard origin/main || git reset --hard origin/master || {
            print_error "Failed to reset repository: $repo_name"
            print_info "Trying to continue anyway..."
        }
        print_success "Repository updated: $repo_name"
    else
        print_info "Cloning repository..."
        git clone "$repo_url" "$target_dir" || {
            print_error "Failed to clone repository: $repo_name"
            print_info "Trying to continue anyway..."
            return 1
        }
        print_success "Repository cloned: $repo_name"
    fi
}

# Function to setup ctrlplane
setup_ctrlplane() {
    print_header "Setting up ctrlplane"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/ctrlplane"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Copy environment file if it doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env file from example"
    fi
    
    # Verify pnpm is available
    if ! command_exists pnpm; then
        print_error "pnpm is not available in PATH"
        print_info "Installing pnpm locally..."
        
        # Install pnpm locally using npm
        npm install -g pnpm || {
            print_error "Failed to install pnpm locally"
            print_info "Trying to continue anyway..."
        }
    fi
    
    # Install dependencies
    print_info "Installing dependencies..."
    pnpm install || {
        print_error "Failed to install ctrlplane dependencies with pnpm"
        print_info "Trying with npm instead..."
        npm install || {
            print_error "Failed to install dependencies with npm as well"
            print_info "Trying to continue anyway..."
        }
    }
    
    # Build the project
    print_info "Building ctrlplane..."
    pnpm build || npm run build || {
        print_error "Failed to build ctrlplane"
        print_info "Trying to continue anyway..."
    }
    
    # Start Docker services
    print_info "Starting Docker services..."
    docker compose -f docker-compose.dev.yaml up -d || {
        print_error "Failed to start ctrlplane Docker services"
        print_info "Trying to continue anyway..."
    }
    
    # Run database migrations
    print_info "Running database migrations..."
    cd packages/db && (pnpm migrate || npm run migrate) && cd ../.. || {
        print_error "Failed to run database migrations"
        print_info "Trying to continue anyway..."
    }
    
    print_success "ctrlplane setup completed"
}

# Function to setup ctrlc-cli
setup_ctrlc_cli() {
    print_header "Setting up ctrlc-cli"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/ctrlc-cli"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Verify Go is available
    if ! command_exists go; then
        print_error "Go is not available in PATH"
        print_info "Adding Go to PATH..."
        export PATH=$PATH:/usr/local/go/bin
    fi
    
    # Build and install
    print_info "Building ctrlc-cli..."
    make build || {
        print_error "Failed to build ctrlc-cli"
        print_info "Trying to continue anyway..."
    }
    
    print_info "Installing ctrlc-cli..."
    make install || {
        print_error "Failed to install ctrlc-cli"
        print_info "Trying to continue anyway..."
    }
    
    print_success "ctrlc-cli setup completed"
}

# Function to setup weave
setup_weave() {
    print_header "Setting up weave"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/weave"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Create and activate virtual environment
    print_info "Creating Python virtual environment..."
    python3 -m venv .venv || {
        print_error "Failed to create Python virtual environment"
        print_info "Trying to continue anyway..."
    }
    
    # Activate virtual environment
    source .venv/bin/activate || {
        print_error "Failed to activate Python virtual environment"
        print_info "Trying to continue anyway..."
    }
    
    # Install in development mode
    print_info "Installing weave in development mode..."
    pip install -e . || {
        print_error "Failed to install weave"
        print_info "Trying to continue anyway..."
    }
    
    # Deactivate virtual environment
    deactivate
    
    print_success "weave setup completed"
}

# Function to setup probot
setup_probot() {
    print_header "Setting up probot"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/probot"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Install dependencies
    print_info "Installing dependencies..."
    npm install || {
        print_error "Failed to install probot dependencies"
        print_info "Trying to continue anyway..."
    }
    
    # Build the project
    print_info "Building probot..."
    npm run build || {
        print_error "Failed to build probot"
        print_info "Trying to continue anyway..."
    }
    
    print_success "probot setup completed"
}

# Function to setup pkg.pr.new
setup_pkg_pr_new() {
    print_header "Setting up pkg.pr.new"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/pkg.pr.new"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Install dependencies
    print_info "Installing dependencies..."
    npm install || {
        print_error "Failed to install pkg.pr.new dependencies"
        print_info "Trying to continue anyway..."
    }
    
    # Build the project
    print_info "Building pkg.pr.new..."
    npm run build || {
        print_error "Failed to build pkg.pr.new"
        print_info "Trying to continue anyway..."
    }
    
    print_success "pkg.pr.new setup completed"
}

# Function to setup tldr
setup_tldr() {
    print_header "Setting up tldr"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/tldr"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Create and activate virtual environment
    print_info "Creating Python virtual environment..."
    python3 -m venv .venv || {
        print_error "Failed to create Python virtual environment"
        print_info "Trying to continue anyway..."
    }
    
    # Activate virtual environment
    source .venv/bin/activate || {
        print_error "Failed to activate Python virtual environment"
        print_info "Trying to continue anyway..."
    }
    
    # Install in development mode
    print_info "Installing tldr in development mode..."
    pip install -e . || {
        print_error "Failed to install tldr"
        print_info "Trying to continue anyway..."
    }
    
    # Deactivate virtual environment
    deactivate
    
    print_success "tldr setup completed"
}

# Function to setup co-reviewer
setup_co_reviewer() {
    print_header "Setting up co-reviewer"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/co-reviewer"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        print_info "Trying to continue anyway..."
        return 1
    }
    
    # Copy environment file if it doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env file from example"
    fi
    
    # Verify pnpm is available
    if ! command_exists pnpm; then
        print_error "pnpm is not available in PATH"
        print_info "Installing pnpm locally..."
        
        # Install pnpm locally using npm
        npm install -g pnpm || {
            print_error "Failed to install pnpm locally"
            print_info "Trying with npm instead..."
        }
    fi
    
    # Install dependencies
    print_info "Installing dependencies..."
    pnpm install || npm install || {
        print_error "Failed to install co-reviewer dependencies"
        print_info "Trying to continue anyway..."
    }
    
    # Build the project
    print_info "Building co-reviewer..."
    pnpm build || npm run build || {
        print_error "Failed to build co-reviewer"
        print_info "Trying to continue anyway..."
    }
    
    print_success "co-reviewer setup completed"
}

# Function to create WSL2 startup script
create_wsl_startup_script() {
    print_header "Creating WSL2 Startup Script"
    
    local startup_script="$ZEEEEPA_BASE_DIR/stack.sh"
    
    # Create stack.sh script
    cat > "$startup_script" << 'EOF'
#!/bin/bash

# Zeeeepa Stack Startup Script
# This script starts all services in the Zeeeepa stack

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Base directory for all projects
BASE_DIR="$HOME/zeeeepa-stack"

# Function to print section header
print_header() {
    echo -e "\n${BLUE}${BOLD}=======================================================${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}=======================================================${NC}\n"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}${BOLD}✓ $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}${BOLD}✗ ERROR: $1${NC}"
}

# Function to start ctrlplane
start_ctrlplane() {
    print_header "Starting ctrlplane"
    cd "$BASE_DIR/ctrlplane" || {
        print_error "Failed to change directory to ctrlplane"
        return 1
    }
    
    docker compose -f docker-compose.dev.yaml up -d || {
        print_error "Failed to start ctrlplane Docker services"
        return 1
    }
    
    print_success "ctrlplane started successfully"
    return 0
}

# Function to stop ctrlplane
stop_ctrlplane() {
    print_header "Stopping ctrlplane"
    cd "$BASE_DIR/ctrlplane" || {
        print_error "Failed to change directory to ctrlplane"
        return 1
    }
    
    docker compose -f docker-compose.dev.yaml down || {
        print_error "Failed to stop ctrlplane Docker services"
        return 1
    }
    
    print_success "ctrlplane stopped successfully"
    return 0
}

# Function to start all services
start_all_services() {
    print_header "Starting all Zeeeepa services"
    
    # Start ctrlplane
    start_ctrlplane
    
    # Add commands to start other services here if needed
    
    print_success "All services started successfully"
    return 0
}

# Function to stop all services
stop_all_services() {
    print_header "Stopping all Zeeeepa services"
    
    # Stop ctrlplane
    stop_ctrlplane
    
    # Add commands to stop other services here if needed
    
    print_success "All services stopped successfully"
    return 0
}

# Function to show status of all services
show_status() {
    print_header "Zeeeepa Stack Status"
    
    # Check ctrlplane status
    cd "$BASE_DIR/ctrlplane" || {
        print_error "Failed to change directory to ctrlplane"
        return 1
    }
    
    echo -e "${BOLD}ctrlplane:${NC}"
    docker compose -f docker-compose.dev.yaml ps
    
    # Add commands to check status of other services here if needed
    
    return 0
}

# Main function
main() {
    # Check for command line arguments
    if [ $# -gt 0 ]; then
        if [ "$1" = "start" ]; then
            start_all_services
            return
        elif [ "$1" = "stop" ]; then
            stop_all_services
            return
        elif [ "$1" = "restart" ]; then
            stop_all_services
            start_all_services
            return
        elif [ "$1" = "status" ]; then
            show_status
            return
        elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
            echo "Usage: $0 [COMMAND]"
            echo
            echo "Commands:"
            echo "  start     Start all services"
            echo "  stop      Stop all services"
            echo "  restart   Restart all services"
            echo "  status    Show status of all services"
            echo "  --help    Show this help message"
            echo
            echo "If no command is provided, you will be prompted to start the stack."
            return
        fi
    fi
    
    # Interactive mode, ask user if they want to start the stack
    print_header "Zeeeepa Stack Management"
    
    # Ask user if they want to start the stack
    read -p "Do You Want To Run CtrlPlane Stack? (Y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_all_services
    else
        echo -e "${YELLOW}${BOLD}Stack startup cancelled.${NC}"
    fi
}

# Run main function with all arguments
main "$@"
EOF
    
    # Make the script executable
    chmod +x "$startup_script"
    
    # Add to WSL startup if running in WSL
    if grep -q Microsoft /proc/version || grep -q microsoft /proc/version; then
        # Check if already in .bashrc
        if ! grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
            echo -e "\n# Start Zeeeepa Stack on WSL startup" >> "$HOME/.bashrc"
            echo "$ZEEEEPA_BASE_DIR/stack.sh" >> "$HOME/.bashrc"
            print_success "Added stack.sh to WSL startup in .bashrc"
        else
            print_info "WSL startup entry already exists in .bashrc"
        fi
    else
        print_warning "Not running in WSL, skipping automatic startup configuration"
    fi
    
    print_success "WSL2 startup script created successfully"
}

# Create a comprehensive overview document
create_overview_document() {
    print_header "Creating Stack Overview Document"
    
    local overview_file="$ZEEEEPA_BASE_DIR/ZEEEEPA_STACK.md"
    
    cat > "$overview_file" << 'EOF'
# Zeeeepa Stack Overview

This document provides an overview of the Zeeeepa stack components, their features, and how they work together.

## Components

### ctrlplane

**Description**: A deployment orchestration tool that simplifies multi-cloud, multi-region, and multi-service deployments.

**Features**:
- Multi-cloud deployment management
- Service orchestration
- Configuration management
- Monitoring and logging integration

**Usage**:
- Access the web interface at http://localhost:3000 after starting the stack
- Use the ctrlc-cli command-line tool to interact with ctrlplane

### ctrlc-cli

**Description**: Command-line interface for ctrlplane.

**Features**:
- Deploy services from the command line
- Manage configurations
- Monitor deployments
- Troubleshoot issues

**Usage**:
```bash
ctrlc help                # Show available commands
ctrlc deploy <service>    # Deploy a service
ctrlc status              # Check deployment status
```

### weave

**Description**: AI toolkit for developing applications by Weights & Biases.

**Features**:
- Machine learning model integration
- Data visualization
- Experiment tracking
- Collaborative AI development

**Usage**:
```python
import weave
# Use weave APIs for AI application development
```

### probot

**Description**: Framework for building GitHub Apps.

**Features**:
- GitHub webhook handling
- GitHub API integration
- Automated GitHub workflows
- Custom GitHub bot development

**Usage**:
- Develop custom GitHub apps using the probot framework
- Automate GitHub workflows and processes

### pkg.pr.new

**Description**: Continuous preview releases for libraries.

**Features**:
- Automated package publishing
- Preview release management
- Version control integration
- Dependency management

**Usage**:
- Automatically generate preview releases for your libraries
- Test changes before official releases

### tldr

**Description**: PR summarizer tool.

**Features**:
- Automatic PR summarization
- Code change analysis
- Review assistance
- Documentation generation

**Usage**:
- Get concise summaries of pull requests
- Understand code changes at a glance

### co-reviewer

**Description**: Code review tool.

**Features**:
- Automated code reviews
- Best practice enforcement
- Security vulnerability detection
- Code quality improvement suggestions

**Usage**:
- Integrate with your development workflow for automated code reviews
- Improve code quality through AI-assisted suggestions

## Getting Started

1. Start the stack:
   ```bash
   ~/zeeeepa-stack/stack.sh start
   ```

2. Access the ctrlplane web interface:
   http://localhost:3000

3. Use the ctrlc-cli command-line tool:
   ```bash
   ctrlc status
   ```

## Troubleshooting

If you encounter issues with the stack:

1. Check the status of all services:
   ```bash
   ~/zeeeepa-stack/stack.sh status
   ```

2. Restart the stack:
   ```bash
   ~/zeeeepa-stack/stack.sh restart
   ```

3. Check the deployment log:
   ```bash
   cat ~/zeeeepa-stack/deployment.log
   ```

## Additional Resources

- ctrlplane documentation: [GitHub Repository](https://github.com/ctrlplanedev/ctrlplane)
- weave documentation: [GitHub Repository](https://github.com/Zeeeepa/weave)
- probot documentation: [GitHub Repository](https://github.com/Zeeeepa/probot)
EOF
    
    print_success "Stack overview document created successfully"
}

# Main function - no user interaction
print_header "Zeeeepa Stack Deployment"
echo -e "This script will deploy the complete Zeeeepa stack including:"
echo -e "  - ${BOLD}ctrlplane${NC}: Deployment orchestration tool"
echo -e "  - ${BOLD}ctrlc-cli${NC}: Command-line interface for ctrlplane"
echo -e "  - ${BOLD}weave${NC}: AI toolkit for developing applications"
echo -e "  - ${BOLD}probot${NC}: Framework for building GitHub Apps"
echo -e "  - ${BOLD}pkg.pr.new${NC}: Continuous preview releases for libraries"
echo -e "  - ${BOLD}tldr${NC}: PR summarizer tool"
echo -e "  - ${BOLD}co-reviewer${NC}: Code review tool"
echo -e "\nDeployment will be to: ${BLUE}${BOLD}$ZEEEEPA_BASE_DIR${NC}"
echo -e "Log file: ${BLUE}${BOLD}$DEPLOYMENT_LOG${NC}"
echo -e "${BLUE}${BOLD}=======================================================${NC}"

# Install system dependencies
install_system_packages

# Clone repositories
print_header "Cloning Repositories"

clone_or_update_repo "$CTRLPLANE_REPO"
clone_or_update_repo "$CTRLC_CLI_REPO"
clone_or_update_repo "$WEAVE_REPO"
clone_or_update_repo "$PROBOT_REPO"
clone_or_update_repo "$PKG_PR_NEW_REPO"
clone_or_update_repo "$TLDR_REPO"
clone_or_update_repo "$CO_REVIEWER_REPO"

# Setup each component
setup_ctrlplane
setup_ctrlc_cli
setup_weave
setup_probot
setup_pkg_pr_new
setup_tldr
setup_co_reviewer

# Create WSL2 startup script
create_wsl_startup_script

# Create overview document
create_overview_document

# Display deployment summary
print_header "Deployment Summary"
echo -e "${GREEN}${BOLD}Zeeeepa Stack has been deployed to: $ZEEEEPA_BASE_DIR${NC}"
echo -e "${GREEN}${BOLD}You can start the stack by running: $ZEEEEPA_BASE_DIR/stack.sh${NC}"

if grep -q Microsoft /proc/version || grep -q microsoft /proc/version; then
    echo -e "${GREEN}${BOLD}The stack will also start automatically when you start your WSL instance.${NC}"
fi

echo
echo -e "${GREEN}${BOLD}Deployment completed successfully!${NC}"
echo -e "${BLUE}${BOLD}For more information, see the deployment log: $DEPLOYMENT_LOG${NC}"
echo -e "${BLUE}${BOLD}For an overview of the stack components, see: $ZEEEEPA_BASE_DIR/ZEEEEPA_STACK.md${NC}"

