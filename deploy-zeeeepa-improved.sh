#!/bin/bash

# Zeeeepa Stack Deployment Script
# This script deploys the complete Zeeeepa stack including:
# - ctrlplane
# - ctrlc-cli
# - weave
# - probot
# - pkg.pr.new
# - tldr
# - co-reviewer
#
# This script can be run directly from GitHub with:
# curl -sSL https://raw.githubusercontent.com/Zeeeepa/ctrlplane/main/deploy-zeeeepa-improved.sh | bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Check for non-interactive mode
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"
if [[ "$1" == "--non-interactive" ]]; then
    NON_INTERACTIVE=true
fi

# Check for auto-yes mode
AUTO_YES="${AUTO_YES:-false}"
if [[ "$1" == "--yes" || "$1" == "-y" ]]; then
    AUTO_YES=true
fi

# Function to print section header
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

# Function for logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] $1"
    mkdir -p "$(dirname "$DEPLOYMENT_LOG")"
    echo -e "[${timestamp}] $1" >> "$DEPLOYMENT_LOG"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to confirm continue
confirm_continue() {
    if [[ "$NON_INTERACTIVE" == "true" || "$AUTO_YES" == "true" ]]; then
        return 0
    fi
    
    read -p "$1 (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# Function to handle errors
handle_error() {
    echo -e "${RED}ERROR: $1${NC}"
    log "ERROR: $1"
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo
        echo -e "${YELLOW}Do you want to continue despite this error? (y/n)${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Deployment cancelled due to error.${NC}"
            exit 1
        fi
    else
        # In non-interactive mode, exit on errors unless IGNORE_ERRORS is set
        if [[ "${IGNORE_ERRORS:-false}" != "true" ]]; then
            echo -e "${YELLOW}Deployment cancelled due to error.${NC}"
            exit 1
        fi
    fi
}

# Function to deploy a repository
deploy_repo() {
    local repo_name="$1"
    local repo_url="$2"
    
    print_header "Deploying $repo_name"
    
    # Create directory if it doesn't exist
    mkdir -p "$ZEEEEPA_BASE_DIR"
    cd "$ZEEEEPA_BASE_DIR" || { 
        handle_error "Failed to change directory to $ZEEEEPA_BASE_DIR."
        return 1
    }
    
    # Clone or update repository
    if [ -d "$repo_name" ]; then
        echo "Repository $repo_name already exists. Updating..."
        cd "$repo_name" || {
            handle_error "Failed to change directory to $repo_name."
            return 1
        }
        
        # Fetch updates
        if ! git fetch origin; then
            handle_error "Failed to fetch updates for $repo_name."
            return 1
        fi
        
        # Pull latest changes
        if ! git pull origin; then
            handle_error "Failed to pull latest changes for $repo_name."
            return 1
        fi
    else
        echo "Cloning repository $repo_name from $repo_url..."
        if ! git clone "$repo_url" "$repo_name"; then
            handle_error "Failed to clone repository $repo_name."
            return 1
        fi
        cd "$repo_name" || {
            handle_error "Failed to change directory to $repo_name."
            return 1
        }
    fi
    
    echo -e "${GREEN}Successfully deployed $repo_name${NC}"
    return 0
}

# Function to add WSL2 startup entry
add_wsl_startup() {
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

# Base directory for all projects
BASE_DIR="$HOME/zeeeepa-stack"

# Function to print section header
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

# Function to start ctrlplane
start_ctrlplane() {
    print_header "Starting ctrlplane"
    cd "$BASE_DIR/ctrlplane" || return 1
    docker compose -f docker-compose.dev.yaml up -d
    echo -e "${GREEN}ctrlplane started successfully${NC}"
}

# Function to stop ctrlplane
stop_ctrlplane() {
    print_header "Stopping ctrlplane"
    cd "$BASE_DIR/ctrlplane" || return 1
    docker compose -f docker-compose.dev.yaml down
    echo -e "${GREEN}ctrlplane stopped successfully${NC}"
}

# Function to start all services
start_all_services() {
    print_header "Starting all Zeeeepa services"
    
    # Start ctrlplane
    start_ctrlplane
    
    # Start other services if needed
    # Add commands to start other services here
    
    echo -e "${GREEN}All services started successfully${NC}"
}

# Function to stop all services
stop_all_services() {
    print_header "Stopping all Zeeeepa services"
    
    # Stop ctrlplane
    stop_ctrlplane
    
    # Stop other services if needed
    # Add commands to stop other services here
    
    echo -e "${GREEN}All services stopped successfully${NC}"
}

# Main function
main() {
    # Check for command line arguments
    if [ "$1" = "--start" ]; then
        start_all_services
        return
    elif [ "$1" = "--stop" ]; then
        stop_all_services
        return
    elif [ "$1" = "--restart" ]; then
        stop_all_services
        start_all_services
        return
    elif [ "$1" = "--non-interactive" ]; then
        # Non-interactive mode, just start all services
        start_all_services
        return
    fi
    
    # Interactive mode, ask user what to do
    echo -e "${GREEN}=======================================================${NC}"
    echo -e "${GREEN}       Zeeeepa Stack Management                        ${NC}"
    echo -e "${GREEN}=======================================================${NC}"
    
    # Ask user if they want to start the stack
    read -p "Do You Want To Run CtrlPlane Stack? (Y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_all_services
    else
        echo -e "${YELLOW}Stack startup cancelled.${NC}"
    fi
}

# Run main function
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
            echo "Added stack.sh to WSL startup in .bashrc"
        fi
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check for git
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    # Check for curl
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    # Check for Docker
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    # Check for docker-compose
    if ! command_exists docker-compose && ! command_exists "docker compose"; then
        missing_deps+=("docker-compose")
    fi
    
    # Check for Node.js
    if ! command_exists node; then
        missing_deps+=("nodejs")
    fi
    
    # Check for pnpm
    if ! command_exists pnpm; then
        missing_deps+=("pnpm")
    fi
    
    # Check for Go
    if ! command_exists go; then
        missing_deps+=("golang")
    fi
    
    # Check for Python
    if ! command_exists python3 && ! command_exists python; then
        missing_deps+=("python")
    fi
    
    # Check for pip
    if ! command_exists pip3 && ! command_exists pip; then
        missing_deps+=("pip")
    fi
    
    # If there are missing dependencies, offer to install them
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}The following dependencies are missing:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        
        if [[ "$NON_INTERACTIVE" != "true" && "$AUTO_YES" != "true" ]]; then
            echo
            echo -e "${YELLOW}Would you like to attempt to install these dependencies? (y/n)${NC}"
            read -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_dependencies "${missing_deps[@]}"
            else
                echo -e "${YELLOW}Please install the missing dependencies manually and run this script again.${NC}"
                exit 1
            fi
        else
            # In non-interactive mode, try to install dependencies automatically
            install_dependencies "${missing_deps[@]}"
        fi
    else
        echo -e "${GREEN}All required dependencies are installed.${NC}"
    fi
}

# Function to install dependencies
install_dependencies() {
    local deps=("$@")
    
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    
    echo "Detected OS: $OS"
    
    case $OS in
        ubuntu|debian)
            echo "Installing dependencies for Ubuntu/Debian..."
            sudo apt update
            
            for dep in "${deps[@]}"; do
                case $dep in
                    git)
                        sudo apt install -y git
                        ;;
                    curl)
                        sudo apt install -y curl
                        ;;
                    docker)
                        sudo apt install -y docker.io
                        sudo systemctl enable --now docker
                        sudo usermod -aG docker $USER
                        echo "NOTE: You may need to log out and log back in for docker group changes to take effect."
                        ;;
                    docker-compose)
                        sudo apt install -y docker-compose
                        ;;
                    nodejs)
                        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
                        sudo apt install -y nodejs
                        ;;
                    pnpm)
                        npm install -g pnpm
                        ;;
                    golang)
                        sudo apt install -y golang-go
                        ;;
                    python)
                        sudo apt install -y python3 python3-venv
                        ;;
                    pip)
                        sudo apt install -y python3-pip
                        ;;
                esac
            done
            ;;
            
        fedora|rhel|centos)
            echo "Installing dependencies for Fedora/RHEL/CentOS..."
            sudo dnf -y update
            
            for dep in "${deps[@]}"; do
                case $dep in
                    git)
                        sudo dnf install -y git
                        ;;
                    curl)
                        sudo dnf install -y curl
                        ;;
                    docker)
                        sudo dnf install -y docker
                        sudo systemctl enable --now docker
                        sudo usermod -aG docker $USER
                        echo "NOTE: You may need to log out and log back in for docker group changes to take effect."
                        ;;
                    docker-compose)
                        sudo dnf install -y docker-compose
                        ;;
                    nodejs)
                        sudo dnf install -y nodejs
                        ;;
                    pnpm)
                        npm install -g pnpm
                        ;;
                    golang)
                        sudo dnf install -y golang
                        ;;
                    python)
                        sudo dnf install -y python3
                        ;;
                    pip)
                        sudo dnf install -y python3-pip
                        ;;
                esac
            done
            ;;
            
        macos)
            echo "Installing dependencies for macOS..."
            if ! command_exists brew; then
                echo "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            for dep in "${deps[@]}"; do
                case $dep in
                    git)
                        brew install git
                        ;;
                    curl)
                        brew install curl
                        ;;
                    docker)
                        brew install --cask docker
                        echo "Please open Docker Desktop to complete the setup."
                        ;;
                    nodejs)
                        brew install node
                        ;;
                    pnpm)
                        npm install -g pnpm
                        ;;
                    golang)
                        brew install go
                        ;;
                    python)
                        brew install python
                        ;;
                    pip)
                        # pip comes with Python on macOS
                        echo "pip is included with Python installation"
                        ;;
                esac
            done
            ;;
            
        *)
            echo -e "${RED}Unsupported OS. Please install dependencies manually:${NC}"
            for dep in "${deps[@]}"; do
                echo "  - $dep"
            done
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
}

# Main deployment function
deploy_stack() {
    # Display welcome message
    clear
    echo -e "${GREEN}=======================================================${NC}"
    echo -e "${GREEN}       Zeeeepa Stack Deployment Script                 ${NC}"
    echo -e "${GREEN}=======================================================${NC}"
    echo -e "This script will deploy the complete Zeeeepa stack including:"
    echo -e "  - ctrlplane: Deployment orchestration tool"
    echo -e "  - ctrlc-cli: Command-line interface for ctrlplane"
    echo -e "  - weave: AI toolkit for developing applications"
    echo -e "  - probot: Framework for building GitHub Apps"
    echo -e "  - pkg.pr.new: Continuous preview releases for libraries"
    echo -e "  - tldr: PR summarizer tool"
    echo -e "  - co-reviewer: Code review tool"
    echo -e "${GREEN}=======================================================${NC}"
    echo -e "Deployment will be to: ${BLUE}$ZEEEEPA_BASE_DIR${NC}"
    echo -e "Log file: ${BLUE}$DEPLOYMENT_LOG${NC}"
    echo -e "${GREEN}=======================================================${NC}"
    echo
    
    # Ask for confirmation before proceeding
    if [[ "$NON_INTERACTIVE" != "true" && "$AUTO_YES" != "true" ]]; then
        if ! confirm_continue "Do you want to proceed with the deployment?"; then
            echo -e "${YELLOW}Deployment cancelled.${NC}"
            exit 0
        fi
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Create base directory
    mkdir -p "$ZEEEEPA_BASE_DIR"
    cd "$ZEEEEPA_BASE_DIR" || {
        handle_error "Failed to create or access $ZEEEEPA_BASE_DIR."
        exit 1
    }
    
    # Deploy ctrlplane
    if deploy_repo "ctrlplane" "$CTRLPLANE_REPO"; then
        print_header "Setting up ctrlplane"
        cd "$ZEEEEPA_BASE_DIR/ctrlplane" || exit 1
        
        # Copy environment file if it doesn't exist
        if [ ! -f ".env" ]; then
            cp .env.example .env
            echo "Created .env file from example"
        fi
        
        # Install dependencies
        echo "Installing dependencies..."
        if command_exists pnpm; then
            pnpm install || handle_error "Failed to install ctrlplane dependencies."
            pnpm build || handle_error "Failed to build ctrlplane."
            
            # Start Docker services
            if command_exists docker && (command_exists docker-compose || command_exists "docker compose"); then
                docker compose -f docker-compose.dev.yaml up -d || docker-compose -f docker-compose.dev.yaml up -d || handle_error "Failed to start ctrlplane Docker services."
                
                # Run database migrations
                cd packages/db && pnpm migrate && cd ../.. || handle_error "Failed to run database migrations."
                echo -e "${GREEN}ctrlplane setup completed successfully${NC}"
            else
                handle_error "Docker or docker-compose not found. Skipping Docker setup."
            fi
        else
            handle_error "pnpm not found. Skipping ctrlplane setup."
        fi
    fi
    
    # Deploy ctrlc-cli
    if deploy_repo "ctrlc-cli" "$CTRLC_CLI_REPO"; then
        print_header "Setting up ctrlc-cli"
        cd "$ZEEEEPA_BASE_DIR/ctrlc-cli" || exit 1
        
        # Build and install
        echo "Building ctrlc-cli..."
        if command_exists make && command_exists go; then
            make build || handle_error "Failed to build ctrlc-cli."
            make install || handle_error "Failed to install ctrlc-cli."
            echo -e "${GREEN}ctrlc-cli setup completed successfully${NC}"
        else
            handle_error "make or go not found. Skipping ctrlc-cli setup."
        fi
    fi
    
    # Deploy weave
    if deploy_repo "weave" "$WEAVE_REPO"; then
        print_header "Setting up weave"
        cd "$ZEEEEPA_BASE_DIR/weave" || exit 1
        
        # Install in development mode
        echo "Installing weave..."
        if command_exists pip || command_exists pip3; then
            pip install -e . || pip3 install -e . || handle_error "Failed to install weave."
            echo -e "${GREEN}weave setup completed successfully${NC}"
        else
            handle_error "pip not found. Skipping weave setup."
        fi
    fi
    
    # Deploy probot
    if deploy_repo "probot" "$PROBOT_REPO"; then
        print_header "Setting up probot"
        cd "$ZEEEEPA_BASE_DIR/probot" || exit 1
        
        # Install dependencies
        echo "Installing dependencies..."
        if command_exists npm; then
            npm install || handle_error "Failed to install probot dependencies."
            npm run build || handle_error "Failed to build probot."
            echo -e "${GREEN}probot setup completed successfully${NC}"
        else
            handle_error "npm not found. Skipping probot setup."
        fi
    fi
    
    # Deploy pkg.pr.new
    if deploy_repo "pkg.pr.new" "$PKG_PR_NEW_REPO"; then
        print_header "Setting up pkg.pr.new"
        cd "$ZEEEEPA_BASE_DIR/pkg.pr.new" || exit 1
        
        # Install dependencies
        echo "Installing dependencies..."
        if command_exists pnpm; then
            pnpm install || handle_error "Failed to install pkg.pr.new dependencies."
            pnpm build || handle_error "Failed to build pkg.pr.new."
            echo -e "${GREEN}pkg.pr.new setup completed successfully${NC}"
        else
            handle_error "pnpm not found. Skipping pkg.pr.new setup."
        fi
    fi
    
    # Deploy tldr
    if deploy_repo "tldr" "$TLDR_REPO"; then
        print_header "Setting up tldr"
        cd "$ZEEEEPA_BASE_DIR/tldr" || exit 1
        
        # Install in development mode
        echo "Installing tldr..."
        if command_exists pip || command_exists pip3; then
            pip install -e . || pip3 install -e . || handle_error "Failed to install tldr."
            echo -e "${GREEN}tldr setup completed successfully${NC}"
        else
            handle_error "pip not found. Skipping tldr setup."
        fi
    fi
    
    # Deploy co-reviewer
    if deploy_repo "co-reviewer" "$CO_REVIEWER_REPO"; then
        print_header "Setting up co-reviewer"
        cd "$ZEEEEPA_BASE_DIR/co-reviewer" || exit 1
        
        # Copy environment file if it doesn't exist
        if [ ! -f ".env" ] && [ -f ".env.example" ]; then
            cp .env.example .env
            echo "Created .env file from example"
        fi
        
        # Install dependencies
        echo "Installing dependencies..."
        if command_exists pnpm; then
            pnpm install || handle_error "Failed to install co-reviewer dependencies."
            pnpm build || handle_error "Failed to build co-reviewer."
            echo -e "${GREEN}co-reviewer setup completed successfully${NC}"
        else
            handle_error "pnpm not found. Skipping co-reviewer setup."
        fi
    fi
    
    # Add WSL2 startup entry
    add_wsl_startup
    
    # Display deployment summary
    print_header "Deployment Summary"
    echo -e "${GREEN}Zeeeepa Stack has been deployed to: $ZEEEEPA_BASE_DIR${NC}"
    echo -e "${GREEN}You can start the stack by running: $ZEEEEPA_BASE_DIR/stack.sh${NC}"
    
    if grep -q Microsoft /proc/version || grep -q microsoft /proc/version; then
        echo -e "${GREEN}The stack will also start automatically when you start your WSL instance.${NC}"
    fi
    
    echo
    echo -e "${GREEN}Deployment completed successfully!${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --yes|-y)
            AUTO_YES=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --non-interactive    Run in non-interactive mode (no prompts)"
            echo "  --yes, -y            Automatically answer yes to all prompts"
            echo "  --help, -h           Show this help message"
            echo
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run the deployment
deploy_stack

