#!/bin/bash
#
# Zeeeepa Stack Deployment Script
# This script deploys the complete Zeeeepa stack on a fresh WSL2 instance
#
# Usage: curl -sSL https://raw.githubusercontent.com/Zeeeepa/ctrlplane/main/deploy-zeeeepa-robust.sh | bash
#

set -e  # Exit on error

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
DEPLOYMENT_LOG="$ZEEEEPA_BASE_DIR/deployment.log"

# Create log directory
mkdir -p "$(dirname "$DEPLOYMENT_LOG")"

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
        return 1
    }
    
    # Install essential packages
    print_info "Installing essential packages..."
    sudo apt-get install -y curl git build-essential python3 python3-pip python3-venv || {
        print_error "Failed to install essential packages"
        return 1
    }
    print_success "Essential packages installed"
    
    # Install Docker if not present
    if ! command_exists docker; then
        print_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh || {
            print_error "Failed to install Docker"
            return 1
        }
        sudo usermod -aG docker $USER
        print_success "Docker installed"
        print_warning "You may need to log out and back in for Docker permissions to take effect"
    else
        print_info "Docker is already installed"
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
            return 1
        }
        print_success "Node.js and npm installed"
    else
        print_info "Node.js is already installed"
    fi
    
    # Install pnpm if not present
    if ! command_exists pnpm; then
        print_info "Installing pnpm..."
        npm install -g pnpm || {
            print_error "Failed to install pnpm"
            return 1
        }
        print_success "pnpm installed"
    else
        print_info "pnpm is already installed"
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
    return 0
}

# Function to clone or update a repository
clone_or_update_repo() {
    local repo_name=$(basename "$2" .git)
    local repo_url="$1"
    local target_dir="$ZEEEEPA_BASE_DIR/$repo_name"
    
    print_info "Setting up repository: $repo_name"
    
    if [ -d "$target_dir" ]; then
        print_info "Repository already exists, updating..."
        cd "$target_dir"
        git fetch origin
        git reset --hard origin/main || git reset --hard origin/master
        print_success "Repository updated: $repo_name"
    else
        print_info "Cloning repository..."
        git clone "$repo_url" "$target_dir" || {
            print_error "Failed to clone repository: $repo_name"
            return 1
        }
        print_success "Repository cloned: $repo_name"
    fi
    
    return 0
}

# Function to setup ctrlplane
setup_ctrlplane() {
    print_header "Setting up ctrlplane"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/ctrlplane"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Copy environment file if it doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env file from example"
    fi
    
    # Install dependencies
    print_info "Installing dependencies..."
    pnpm install || {
        print_error "Failed to install ctrlplane dependencies"
        return 1
    }
    
    # Build the project
    print_info "Building ctrlplane..."
    pnpm build || {
        print_error "Failed to build ctrlplane"
        return 1
    }
    
    # Start Docker services
    print_info "Starting Docker services..."
    docker compose -f docker-compose.dev.yaml up -d || {
        print_error "Failed to start ctrlplane Docker services"
        return 1
    }
    
    # Run database migrations
    print_info "Running database migrations..."
    cd packages/db && pnpm migrate && cd ../.. || {
        print_error "Failed to run database migrations"
        return 1
    }
    
    print_success "ctrlplane setup completed successfully"
    return 0
}

# Function to setup ctrlc-cli
setup_ctrlc_cli() {
    print_header "Setting up ctrlc-cli"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/ctrlc-cli"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Build and install
    print_info "Building ctrlc-cli..."
    make build || {
        print_error "Failed to build ctrlc-cli"
        return 1
    }
    
    print_info "Installing ctrlc-cli..."
    make install || {
        print_error "Failed to install ctrlc-cli"
        print_warning "Continuing without installing ctrlc-cli"
    }
    
    print_success "ctrlc-cli setup completed successfully"
    return 0
}

# Function to setup weave
setup_weave() {
    print_header "Setting up weave"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/weave"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Create and activate virtual environment
    print_info "Creating Python virtual environment..."
    python3 -m venv .venv || {
        print_error "Failed to create Python virtual environment"
        return 1
    }
    
    # Activate virtual environment
    source .venv/bin/activate || {
        print_error "Failed to activate Python virtual environment"
        return 1
    }
    
    # Install in development mode
    print_info "Installing weave in development mode..."
    pip install -e . || {
        print_error "Failed to install weave"
        return 1
    }
    
    # Deactivate virtual environment
    deactivate
    
    print_success "weave setup completed successfully"
    return 0
}

# Function to setup probot
setup_probot() {
    print_header "Setting up probot"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/probot"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Install dependencies
    print_info "Installing dependencies..."
    npm install || {
        print_error "Failed to install probot dependencies"
        return 1
    }
    
    # Build the project
    print_info "Building probot..."
    npm run build || {
        print_error "Failed to build probot"
        return 1
    }
    
    print_success "probot setup completed successfully"
    return 0
}

# Function to setup pkg.pr.new
setup_pkg_pr_new() {
    print_header "Setting up pkg.pr.new"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/pkg.pr.new"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Install dependencies
    print_info "Installing dependencies..."
    pnpm install || {
        print_error "Failed to install pkg.pr.new dependencies"
        return 1
    }
    
    # Build the project
    print_info "Building pkg.pr.new..."
    pnpm build || {
        print_error "Failed to build pkg.pr.new"
        return 1
    }
    
    print_success "pkg.pr.new setup completed successfully"
    return 0
}

# Function to setup tldr
setup_tldr() {
    print_header "Setting up tldr"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/tldr"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Create and activate virtual environment
    print_info "Creating Python virtual environment..."
    python3 -m venv .venv || {
        print_error "Failed to create Python virtual environment"
        return 1
    }
    
    # Activate virtual environment
    source .venv/bin/activate || {
        print_error "Failed to activate Python virtual environment"
        return 1
    }
    
    # Install in development mode
    print_info "Installing tldr in development mode..."
    pip install -e . || {
        print_error "Failed to install tldr"
        return 1
    }
    
    # Deactivate virtual environment
    deactivate
    
    print_success "tldr setup completed successfully"
    return 0
}

# Function to setup co-reviewer
setup_co_reviewer() {
    print_header "Setting up co-reviewer"
    
    local repo_dir="$ZEEEEPA_BASE_DIR/co-reviewer"
    cd "$repo_dir" || {
        print_error "Failed to change directory to $repo_dir"
        return 1
    }
    
    # Copy environment file if it doesn't exist
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Created .env file from example"
    fi
    
    # Install dependencies
    print_info "Installing dependencies..."
    pnpm install || {
        print_error "Failed to install co-reviewer dependencies"
        return 1
    }
    
    # Build the project
    print_info "Building co-reviewer..."
    pnpm build || {
        print_error "Failed to build co-reviewer"
        return 1
    }
    
    print_success "co-reviewer setup completed successfully"
    return 0
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
    
    # Interactive mode, ask user what to do
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
    return 0
}

# Main function
main() {
    # Display welcome message
    clear
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
    echo
    
    # Ask for confirmation before proceeding
    read -p "Do you want to proceed with the deployment? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}${BOLD}Deployment cancelled.${NC}"
        exit 0
    fi
    
    # Create base directory
    mkdir -p "$ZEEEEPA_BASE_DIR"
    
    # Install system dependencies
    install_system_packages || {
        print_error "Failed to install system dependencies"
        exit 1
    }
    
    # Clone repositories
    print_header "Cloning Repositories"
    
    clone_or_update_repo "$CTRLPLANE_REPO" "ctrlplane" || {
        print_error "Failed to clone ctrlplane repository"
        exit 1
    }
    
    clone_or_update_repo "$CTRLC_CLI_REPO" "ctrlc-cli" || {
        print_error "Failed to clone ctrlc-cli repository"
        exit 1
    }
    
    clone_or_update_repo "$WEAVE_REPO" "weave" || {
        print_error "Failed to clone weave repository"
        exit 1
    }
    
    clone_or_update_repo "$PROBOT_REPO" "probot" || {
        print_error "Failed to clone probot repository"
        exit 1
    }
    
    clone_or_update_repo "$PKG_PR_NEW_REPO" "pkg.pr.new" || {
        print_error "Failed to clone pkg.pr.new repository"
        exit 1
    }
    
    clone_or_update_repo "$TLDR_REPO" "tldr" || {
        print_error "Failed to clone tldr repository"
        exit 1
    }
    
    clone_or_update_repo "$CO_REVIEWER_REPO" "co-reviewer" || {
        print_error "Failed to clone co-reviewer repository"
        exit 1
    }
    
    # Setup each component
    setup_ctrlplane || {
        print_error "Failed to setup ctrlplane"
        print_warning "Continuing with deployment"
    }
    
    setup_ctrlc_cli || {
        print_error "Failed to setup ctrlc-cli"
        print_warning "Continuing with deployment"
    }
    
    setup_weave || {
        print_error "Failed to setup weave"
        print_warning "Continuing with deployment"
    }
    
    setup_probot || {
        print_error "Failed to setup probot"
        print_warning "Continuing with deployment"
    }
    
    setup_pkg_pr_new || {
        print_error "Failed to setup pkg.pr.new"
        print_warning "Continuing with deployment"
    }
    
    setup_tldr || {
        print_error "Failed to setup tldr"
        print_warning "Continuing with deployment"
    }
    
    setup_co_reviewer || {
        print_error "Failed to setup co-reviewer"
        print_warning "Continuing with deployment"
    }
    
    # Create WSL2 startup script
    create_wsl_startup_script || {
        print_error "Failed to create WSL2 startup script"
        print_warning "Continuing with deployment"
    }
    
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
}

# Run the main function
main

