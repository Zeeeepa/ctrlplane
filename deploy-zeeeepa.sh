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
# curl -sSL https://raw.githubusercontent.com/Zeeeepa/ctrlplane/main/deploy-zeeeepa.sh | bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Base directory for all projects
ZEEEEPA_BASE_DIR="$HOME/zeeeepa-stack"

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

# Version requirements
NODE_MIN_VERSION="22.10.0"
PNPM_MIN_VERSION="10.2.0"
GO_MIN_VERSION="1.20.0"
PYTHON_MIN_VERSION="3.8.0"
REQUIRED_SPACE="5" # Required space in GB

# Deployment status tracking
DEPLOYED_COMPONENTS=()
FAILED_COMPONENTS=()

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

# Function to check if a command exists and install it if missing
check_command() {
    if ! command_exists "$1"; then
        echo -e "${YELLOW}Warning: $1 is required but not installed.${NC}"
        
        # Detect OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command_exists apt-get; then
                echo -e "${BLUE}Attempting to install $1 using apt-get...${NC}"
                sudo apt-get update && sudo apt-get install -y "$1"
            elif command_exists yum; then
                echo -e "${BLUE}Attempting to install $1 using yum...${NC}"
                sudo yum install -y "$1"
            elif command_exists dnf; then
                echo -e "${BLUE}Attempting to install $1 using dnf...${NC}"
                sudo dnf install -y "$1"
            else
                echo -e "${RED}Error: Could not determine package manager. Please install $1 manually.${NC}"
                return 1
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                echo -e "${BLUE}Attempting to install $1 using brew...${NC}"
                brew install "$1"
            else
                echo -e "${RED}Error: Homebrew not found. Please install $1 manually.${NC}"
                return 1
            fi
        else
            echo -e "${RED}Error: Unsupported OS. Please install $1 manually.${NC}"
            return 1
        fi
        
        # Check if installation was successful
        if ! command_exists "$1"; then
            echo -e "${RED}Error: Failed to install $1. Please install it manually.${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Successfully installed $1.${NC}"
    fi
    return 0
}

# Function to check if user wants to continue after a warning
confirm_continue() {
    read -p "$1 (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

# Version comparison function
version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

# Function to check version requirements
check_version() {
    local command_name="$1"
    local current_version="$2"
    local required_version="$3"
    
    if version_lt "$current_version" "$required_version"; then
        echo -e "${YELLOW}Warning: $command_name version $current_version is less than the required version $required_version.${NC}"
        if ! confirm_continue "Continue anyway?"; then
            return 1
        fi
    else
        log "$command_name version $current_version meets requirements (>= $required_version)"
    fi
    return 0
}

# Function to check disk space
check_disk_space() {
    local required_gb="$1"
    local available_space=$(df -BG "$HOME" | awk 'NR==2 {gsub("G", "", $4); print $4}')
    
    log "Available space: ${available_space}GB, Required: ${required_gb}GB"
    
    if (( available_space < required_gb )); then
        echo -e "${RED}Error: Not enough disk space. At least ${required_gb}GB is required, but only ${available_space}GB is available.${NC}"
        if ! confirm_continue "Continue anyway?"; then
            return 1
        fi
    fi
    return 0
}

# Function to check if a port is in use
check_port() {
    local port="$1"
    if command_exists netstat; then
        if netstat -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command_exists ss; then
        if ss -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command_exists lsof; then
        if lsof -i ":$port" &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to wait for a service to be ready
wait_for_service() {
    local service_name="$1"
    local port="$2"
    local max_attempts="${3:-30}"
    local wait_seconds="${4:-2}"
    
    echo -e "Waiting for $service_name to be ready..."
    local attempts=0
    
    while (( attempts < max_attempts )); do
        attempts=$((attempts + 1))
        
        if check_port "$port"; then
            echo -e "\n${GREEN}$service_name is ready!${NC}"
            return 0
        fi
        
        if (( attempts == max_attempts )); then
            echo -e "${RED}Error: $service_name did not start within the expected time.${NC}"
            # Capture and display the error message
            if docker logs $service_name &> /tmp/docker_log.txt; then
              echo "Last lines of docker log:"
              tail /tmp/docker_log.txt
            fi
            return 1
        fi
        
        echo -n "."
        sleep "$wait_seconds"
    done
    
    return 1
}
# Function to deploy a repository
deploy_repo() {
    local repo_name="$1"
    local repo_url="$2"
    
    print_header "Deploying $repo_name"
    
    # Create directory if it doesn't exist
    mkdir -p "$ZEEEEPA_BASE_DIR"
    cd "$ZEEEEPA_BASE_DIR" || { 
        echo -e "${RED}Error: Failed to change directory to $ZEEEEPA_BASE_DIR.${NC}"
        return 1
    }
    
    # Clone or update repository
    if [ -d "$repo_name" ]; then
        echo "Repository $repo_name already exists. Updating..."
        cd "$repo_name" || {
            echo -e "${RED}Error: Failed to change directory to $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        }
        
        # Fetch updates
        if ! git fetch origin; then
            echo -e "${RED}Error: Failed to fetch updates for $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        fi
        
        # Pull latest changes
        if ! git pull origin; then
            echo -e "${RED}Error: Failed to pull latest changes for $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        fi
    else
        echo "Cloning repository $repo_name from $repo_url..."
        if ! git clone "$repo_url" "$repo_name"; then
            echo -e "${RED}Error: Failed to clone repository $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        fi
        cd "$repo_name" || {
            echo -e "${RED}Error: Failed to change directory to $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        }
    fi
    
    DEPLOYED_COMPONENTS+=("$repo_name")
    return 0
}

# Function to add WSL2 startup entry
add_wsl_startup() {
    local startup_script="$ZEEEEPA_BASE_DIR/stack.sh"
    
    # Create stack.sh script
    cat > "$startup_script" << 'EOFINNER'
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
    # Check if running in interactive mode
    if [ "$1" = "--non-interactive" ]; then
        # Non-interactive mode, start all services
        start_all_services
        return
    fi
    
    # Interactive mode, ask user what to do
    echo -e "${GREEN}=======================================================${NC}"
    echo -e "${GREEN}       Zeeeepa Stack Management Script                 ${NC}"
    echo -e "${GREEN}=======================================================${NC}"
    
    # Ask user if they want to start the stack
    read -p "Do You Want To Run CtrlPlane Stack? (Y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_all_services
    else
        echo -e "${YELLOW}Stack startup cancelled.${NC}"
    fi
}

# Run main function with all arguments
main "$@"
EOFINNER
    
    # Make the script executable
    chmod +x "$startup_script"
    
    # Add to WSL2 startup if running in WSL
    if grep -q Microsoft /proc/version || grep -q microsoft /proc/version; then
        # Running in WSL
        echo "Detected WSL environment. Adding startup entry..."
        
        # Create .bashrc entry if it doesn't exist
        if ! grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
            echo -e "\n# Zeeeepa Stack Startup" >> "$HOME/.bashrc"
            echo "$ZEEEEPA_BASE_DIR/stack.sh" >> "$HOME/.bashrc"
            echo "Added startup entry to .bashrc"
        fi
    else
        echo "Not running in WSL. Skipping automatic startup configuration."
    fi
    
    echo -e "${GREEN}Created stack management script at $startup_script${NC}"
    echo -e "${YELLOW}You can start the stack manually by running:${NC}"
    echo -e "  $startup_script"
}

# Function to install/update Node.js
install_node() {
    if command_exists node; then
        local node_version=$(node -v | cut -d 'v' -f 2)
        if ! check_version "Node.js" "$node_version" "$NODE_MIN_VERSION"; then
            echo -e "${YELLOW}Attempting to update Node.js...${NC}"
            
            # Install/update using nvm if available
            if command_exists nvm; then
                nvm install --lts
                nvm use --lts
            else
                # Install nvm and then Node.js
                echo -e "${BLUE}Installing nvm to manage Node.js versions...${NC}"
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
                
                # Source nvm
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
                
                # Install and use latest LTS version
                nvm install --lts
                nvm use --lts
            fi
            
            # Verify installation
            if ! command_exists node; then
                echo -e "${RED}Failed to install Node.js.${NC}"
                return 1
            fi
            
            node_version=$(node -v | cut -d 'v' -f 2)
            if ! check_version "Node.js" "$node_version" "$NODE_MIN_VERSION"; then
                echo -e "${RED}Failed to install a compatible version of Node.js.${NC}"
                return 1
            fi
        fi
    else
        echo -e "${YELLOW}Node.js not found. Installing...${NC}"
        
        # Install nvm and then Node.js
        echo -e "${BLUE}Installing nvm to manage Node.js versions...${NC}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        
        # Source nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # Install and use latest LTS version
        nvm install --lts
        nvm use --lts
        
        # Verify installation
        if ! command_exists node; then
            echo -e "${RED}Failed to install Node.js.${NC}"
            return 1
        fi
        
        node_version=$(node -v | cut -d 'v' -f 2)
        if ! check_version "Node.js" "$node_version" "$NODE_MIN_VERSION"; then
            echo -e "${RED}Failed to install a compatible version of Node.js.${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}Node.js $(node -v) is installed and ready.${NC}"
    return 0
}

# Function to install/update pnpm
install_pnpm() {
    if command_exists pnpm; then
        local pnpm_version=$(pnpm --version)
        if ! check_version "pnpm" "$pnpm_version" "$PNPM_MIN_VERSION"; then
            echo -e "${YELLOW}Attempting to update pnpm...${NC}"
            
            # Update pnpm
            npm install -g pnpm@latest
            
            # Verify installation
            if ! command_exists pnpm; then
                echo -e "${RED}Failed to install pnpm.${NC}"
                return 1
            fi
            
            pnpm_version=$(pnpm --version)
            if ! check_version "pnpm" "$pnpm_version" "$PNPM_MIN_VERSION"; then
                echo -e "${RED}Failed to install a compatible version of pnpm.${NC}"
                return 1
            fi
        fi
    else
        echo -e "${YELLOW}pnpm not found. Installing...${NC}"
        
        # Install pnpm
        npm install -g pnpm@latest
        
        # Verify installation
        if ! command_exists pnpm; then
            echo -e "${RED}Failed to install pnpm.${NC}"
            return 1
        fi
        
        pnpm_version=$(pnpm --version)
        if ! check_version "pnpm" "$pnpm_version" "$PNPM_MIN_VERSION"; then
            echo -e "${RED}Failed to install a compatible version of pnpm.${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}pnpm $(pnpm --version) is installed and ready.${NC}"
    return 0
}

# Function to install/check Go
install_go() {
    if command_exists go; then
        local go_version=$(go version | awk '{print $3}' | cut -c 3-)
        if ! check_version "Go" "$go_version" "$GO_MIN_VERSION"; then
            echo -e "${YELLOW}Warning: Go version $go_version is less than the required version $GO_MIN_VERSION.${NC}"
            echo -e "${YELLOW}Please update Go manually from https://golang.org/dl/${NC}"
            if ! confirm_continue "Continue anyway?"; then
                return 1
            fi
        fi
    else
        echo -e "${YELLOW}Go not found. Installing...${NC}"
        
        # Detect OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Install Go on Linux
            local go_download_url="https://golang.org/dl/go1.21.0.linux-amd64.tar.gz"
            
            # Download and extract
            curl -L -o /tmp/go.tar.gz "$go_download_url"
            sudo tar -C /usr/local -xzf /tmp/go.tar.gz
            rm /tmp/go.tar.gz
            
            # Add to PATH if not already there
            if ! grep -q "/usr/local/go/bin" "$HOME/.bashrc"; then
                echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.bashrc"
                export PATH=$PATH:/usr/local/go/bin
            fi
            
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # Install Go on macOS using Homebrew
            if command_exists brew; then
                brew install go
            else
                echo -e "${RED}Homebrew not found. Please install Go manually from https://golang.org/dl/${NC}"
                if ! confirm_continue "Continue anyway?"; then
                    return 1
                fi
            fi
        else
            echo -e "${RED}Unsupported OS. Please install Go manually from https://golang.org/dl/${NC}"
            if ! confirm_continue "Continue anyway?"; then
                return 1
            fi
        fi
        
        # Verify installation
        if ! command_exists go; then
            echo -e "${RED}Failed to install Go.${NC}"
            if ! confirm_continue "Continue anyway?"; then
                return 1
            fi
        else
            local go_version=$(go version | awk '{print $3}' | cut -c 3-)
            if ! check_version "Go" "$go_version" "$GO_MIN_VERSION"; then
                echo -e "${RED}Failed to install a compatible version of Go.${NC}"
                if ! confirm_continue "Continue anyway?"; then
                    return 1
                fi
            fi
        fi
    fi
    
    if command_exists go; then
        echo -e "${GREEN}Go $(go version | awk '{print $3}') is installed and ready.${NC}"
    fi
    return 0
}

# Function to install/update Python
install_python() {
    local python_cmd=""
    
    # Determine which Python command to use
    if command_exists python3; then
        python_cmd="python3"
    elif command_exists python; then
        if [[ $(python --version 2>&1) == *"Python 3"* ]]; then
            python_cmd="python"
        else
            echo -e "${YELLOW}Python 2 detected. Python 3 is required.${NC}"
            python_cmd=""
        fi
    fi
    
    if [ -n "$python_cmd" ]; then
        local python_version=$($python_cmd --version 2>&1 | awk '{print $2}')
        if ! check_version "Python" "$python_version" "$PYTHON_MIN_VERSION"; then
            echo -e "${YELLOW}Warning: Python version $python_version is less than the required version $PYTHON_MIN_VERSION.${NC}"
            echo -e "${YELLOW}Please update Python manually.${NC}"
            if ! confirm_continue "Continue anyway?"; then
                return 1
            fi
        fi
    else
        echo -e "${YELLOW}Python 3 not found. Installing...${NC}"
        
        # Detect OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv
            elif command_exists yum; then
                sudo yum install -y python3 python3-pip
            elif command_exists dnf; then
                sudo dnf install -y python3 python3-pip
            else
                echo -e "${RED}Could not determine package manager. Please install Python 3 manually.${NC}"
                if ! confirm_continue "Continue anyway?"; then
                    return 1
                fi
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            if command_exists brew; then
                brew install python
            else
                echo -e "${RED}Homebrew not found. Please install Python 3 manually.${NC}"
                if ! confirm_continue "Continue anyway?"; then
                    return 1
                fi
            fi
        else
            echo -e "${RED}Unsupported OS. Please install Python 3 manually.${NC}"
            if ! confirm_continue "Continue anyway?"; then
                return 1
            fi
        fi
        
        # Verify installation
        if command_exists python3; then
            python_cmd="python3"
        elif command_exists python; then
            if [[ $(python --version 2>&1) == *"Python 3"* ]]; then
                python_cmd="python"
            fi
        fi
        
        if [ -z "$python_cmd" ]; then
            echo -e "${RED}Failed to install Python 3.${NC}"
            if ! confirm_continue "Continue anyway?"; then
                return 1
            fi
        else
            local python_version=$($python_cmd --version 2>&1 | awk '{print $2}')
            if ! check_version "Python" "$python_version" "$PYTHON_MIN_VERSION"; then
                echo -e "${RED}Failed to install a compatible version of Python.${NC}"
                if ! confirm_continue "Continue anyway?"; then
                    return 1
                fi
            fi
        fi
    fi
    
    if [ -n "$python_cmd" ]; then
        echo -e "${GREEN}Python $($python_cmd --version 2>&1 | awk '{print $2}') is installed and ready.${NC}"
    fi
    return 0
}

# Function to install Docker
install_docker() {
    if ! command_exists docker; then
        echo -e "${YELLOW}Docker not found. Installing...${NC}"
        
        # Detect OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            
            # Install Docker Compose if not already installed
            if ! command_exists docker-compose; then
                sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
            fi
            
            echo -e "${YELLOW}Docker has been installed. You may need to log out and log back in for group changes to take effect.${NC}"
            echo -e "${YELLOW}Alternatively, run 'newgrp docker' to update group membership without logging out.${NC}"
            
            # Try to update group membership without logging out
            if command_exists newgrp; then
                newgrp docker
            fi
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}Please install Docker Desktop for Mac from https://www.docker.com/products/docker-desktop${NC}"
            return 1
        else
            echo -e "${RED}Unsupported OS. Please install Docker manually.${NC}"
            return 1
        fi
        
        # Verify installation
        if ! command_exists docker; then
            echo -e "${RED}Failed to install Docker.${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Successfully installed Docker.${NC}"
    fi
    return 0
}

# Function to display deployment summary
deployment_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Successfully deployed components:${NC}"
    for component in "${DEPLOYED_COMPONENTS[@]}"; do
        echo -e "  - ${GREEN}$component${NC}"
    done
    
    if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed components:${NC}"
        for component in "${FAILED_COMPONENTS[@]}"; do
            echo -e "  - ${RED}$component${NC}"
        done
        echo -e "\n${YELLOW}Please check the log file for more details: $DEPLOYMENT_LOG${NC}"
    fi
    
    echo -e "\n${BLUE}Zeeeepa Stack has been deployed to: $ZEEEEPA_BASE_DIR${NC}"
    echo -e "${BLUE}You can start the stack by running: $ZEEEEPA_BASE_DIR/stack.sh${NC}"
    
    if grep -q Microsoft /proc/version || grep -q microsoft /proc/version; then
        echo -e "${BLUE}The stack will also start automatically when you start your WSL instance.${NC}"
    fi
}

# Main function
main() {
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
    if ! confirm_continue "Do you want to proceed with the deployment?"; then
        echo -e "${YELLOW}Deployment cancelled.${NC}"
        exit 0
    fi
    
    # Check and install prerequisites
    print_header "Checking and Installing Prerequisites"
    
    # Install essential tools
    check_command git || exit 1
    check_command curl || exit 1
    
    # Install/update Node.js
    install_node || exit 1
    
    # Install/update pnpm
    install_pnpm || exit 1
    
    # Install/check Go
    install_go || exit 1
    
    # Install/update Python
    install_python || exit 1
    
    # Install pip if not already installed
    check_command pip || check_command pip3 || exit 1
    
    # Install Docker
    install_docker || exit 1
    
    # Check disk space
    print_header "Checking Disk Space"
    if ! check_disk_space "$REQUIRED_SPACE"; then
        exit 1
    fi
    
    # Create base directory
    mkdir -p "$ZEEEEPA_BASE_DIR"
    cd "$ZEEEEPA_BASE_DIR" || {
        echo -e "${RED}Error: Failed to create or access $ZEEEEPA_BASE_DIR.${NC}"
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
        if ! pnpm install; then
            echo -e "${RED}Error: Failed to install dependencies for ctrlplane.${NC}"
            FAILED_COMPONENTS+=("ctrlplane-setup")
        else
            # Build the project
            echo "Building ctrlplane..."
            if ! pnpm build; then
                echo -e "${RED}Error: Failed to build ctrlplane.${NC}"
                FAILED_COMPONENTS+=("ctrlplane-build")
            else
                # Start Docker services
                echo "Starting Docker services..."
                if ! docker compose -f docker-compose.dev.yaml up -d; then
                    docker_error=$?
                    echo -e "${RED}Error: Failed to start Docker services for ctrlplane. Docker compose exited with code $docker_error.${NC}"
                    FAILED_COMPONENTS+=("ctrlplane-docker")
                else
                    # Run database migrations
                    echo "Running database migrations..."
                    cd packages/db && pnpm migrate && cd ../..
                    echo -e "${GREEN}ctrlplane setup completed successfully${NC}"
                fi
            fi
        fi
    fi
    
    # Deploy ctrlc-cli
    if deploy_repo "ctrlc-cli" "$CTRLC_CLI_REPO"; then
        print_header "Setting up ctrlc-cli"
        cd "$ZEEEEPA_BASE_DIR/ctrlc-cli" || exit 1
        
        # Build and install
        echo "Building ctrlc-cli..."
        if ! make build; then
            echo -e "${RED}Error: Failed to build ctrlc-cli.${NC}"
            FAILED_COMPONENTS+=("ctrlc-cli-build")
        else
            echo "Installing ctrlc-cli..."
            if ! make install; then
                echo -e "${RED}Error: Failed to install ctrlc-cli.${NC}"
                FAILED_COMPONENTS+=("ctrlc-cli-install")
            else
                echo -e "${GREEN}ctrlc-cli setup completed successfully${NC}"
            fi
        fi
    fi
    
    # Deploy weave
    if deploy_repo "weave" "$WEAVE_REPO"; then
        print_header "Setting up weave"
        cd "$ZEEEEPA_BASE_DIR/weave" || exit 1
        
        # Install in development mode
        echo "Installing weave..."
        if ! pip install -e .; then
            echo -e "${RED}Error: Failed to install weave.${NC}"
            FAILED_COMPONENTS+=("weave-install")
        else
            echo -e "${GREEN}weave setup completed successfully${NC}"
        fi
    fi
    
    # Deploy probot
    if deploy_repo "probot" "$PROBOT_REPO"; then
        print_header "Setting up probot"
        cd "$ZEEEEPA_BASE_DIR/probot" || exit 1
        
        # Install dependencies
        echo "Installing dependencies..."
        if ! npm install; then
            echo -e "${RED}Error: Failed to install dependencies for probot.${NC}"
            FAILED_COMPONENTS+=("probot-deps")
        else
            # Build the project
            echo "Building probot..."
            if ! npm run build; then
                echo -e "${RED}Error: Failed to build probot.${NC}"
                FAILED_COMPONENTS+=("probot-build")
            else
                echo -e "${GREEN}probot setup completed successfully${NC}"
            fi
        fi
    fi
    
    # Deploy pkg.pr.new
    if deploy_repo "pkg.pr.new" "$PKG_PR_NEW_REPO"; then
        print_header "Setting up pkg.pr.new"
        cd "$ZEEEEPA_BASE_DIR/pkg.pr.new" || exit 1
        
        # Install dependencies
        echo "Installing dependencies..."
        if ! pnpm install; then
            echo -e "${RED}Error: Failed to install dependencies for pkg.pr.new.${NC}"
            FAILED_COMPONENTS+=("pkg.pr.new-deps")
        else
            # Build the project
            echo "Building pkg.pr.new..."
            if ! pnpm build; then
                echo -e "${RED}Error: Failed to build pkg.pr.new.${NC}"
                FAILED_COMPONENTS+=("pkg.pr.new-build")
            else
                echo -e "${GREEN}pkg.pr.new setup completed successfully${NC}"
            fi
        fi
    fi
    
    # Deploy tldr
    if deploy_repo "tldr" "$TLDR_REPO"; then
        print_header "Setting up tldr"
        cd "$ZEEEEPA_BASE_DIR/tldr" || exit 1
        
        # Install in development mode
        echo "Installing tldr..."
        if ! pip install -e .; then
            echo -e "${RED}Error: Failed to install tldr.${NC}"
            FAILED_COMPONENTS+=("tldr-install")
        else
            echo -e "${GREEN}tldr setup completed successfully${NC}"
        fi
    fi
    
    # Deploy co-reviewer
    if deploy_repo "co-reviewer" "$CO_REVIEWER_REPO"; then
        print_header "Setting up co-reviewer"
        cd "$ZEEEEPA_BASE_DIR/co-reviewer" || exit 1
        
        # Copy environment file if it doesn't exist
        if [ ! -f ".env" ]; then
            cp .env.example .env
            echo "Created .env file from example"
        fi
        
        # Install dependencies
        echo "Installing dependencies..."
        if ! pnpm install; then
            echo -e "${RED}Error: Failed to install dependencies for co-reviewer.${NC}"
            FAILED_COMPONENTS+=("co-reviewer-deps")
        else
            # Build the project
            echo "Building co-reviewer..."
            if ! pnpm build; then
                echo -e "${RED}Error: Failed to build co-reviewer.${NC}"
                FAILED_COMPONENTS+=("co-reviewer-build")
            else
                echo -e "${GREEN}co-reviewer setup completed successfully${NC}"
            fi
        fi
    fi
    
    # Add WSL2 startup entry
    add_wsl_startup
    
    # Display deployment summary
    deployment_summary
}

# Check if script is being run directly or sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run main function
    main
fi
