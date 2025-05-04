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
check_command() {
    echo -e "${RED}Error: $1 is required but not installed. Please install it using your system's package manager (e.g., apt, yum, brew).${NC}"
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
    
    read -p "$1 (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[YyNn]$ ]]; then
        echo "Invalid input. Please answer 'y' or 'n'."
        confirm_continue "$1"
        return 1
    fi
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            return 0
        fi
    elif command -v lsof &> /dev/null; then
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
    while ! check_port "$port"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge "$max_attempts" ]; then
            echo -e "${RED}Error: $service_name did not start within the expected time.${NC}"
            return 1
        fi
        echo -n "."
        sleep "$wait_seconds"
    done
    echo -e "\n${GREEN}$service_name is ready!${NC}"
    return 0
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
    # Check if running in interactive mode
    if [ "$1" = "--non-interactive" ]; then
        start_all_services
        return
    fi
    
    # Check if running with specific command
    if [ "$1" = "--start" ]; then
        start_all_services
        return
    fi
    
    if [ "$1" = "--stop" ]; then
        stop_all_services
        return
    fi
    
    # Interactive prompt
    read -p "Do You Want To Run CtrlPlane Stack? Y/N " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_all_services
    fi
}

# Run main function with all arguments
main "$@"
EOF

    chmod +x "$startup_script"
    
    # Add to WSL startup if on Windows
    if grep -q Microsoft /proc/version; then
        print_header "Setting up WSL2 startup"
        
        # Create .bashrc entry if it doesn't exist
        if ! grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
            echo -e "\n# Zeeeepa Stack Startup" >> "$HOME/.bashrc"
            echo "$startup_script" >> "$HOME/.bashrc"
            echo -e "${GREEN}Added Zeeeepa Stack startup to .bashrc${NC}"
        else
            echo -e "${YELLOW}Zeeeepa Stack startup already in .bashrc${NC}"
        fi
    else
        echo -e "${YELLOW}Not running in WSL2, skipping startup configuration${NC}"
    fi
}

# Function to display deployment summary
deployment_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Successfully deployed components:${NC}"
    for component in "${DEPLOYED_COMPONENTS[@]}"; do
        echo -e "  - $component"
    done
    
    if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed to deploy components:${NC}"
        for component in "${FAILED_COMPONENTS[@]}"; do
            echo -e "  - $component"
        done
        echo -e "\nCheck the deployment log at $DEPLOYMENT_LOG for details."
    fi
    
    echo -e "\n${BLUE}To start the stack:${NC}"
    echo -e "  $ZEEEEPA_BASE_DIR/stack.sh"
    
    echo -e "\n${BLUE}To stop the stack:${NC}"
    echo -e "  $ZEEEEPA_BASE_DIR/stack.sh --stop"
}

# Main function
main() {
    print_header "Zeeeepa Stack Deployment"
    
    # Check prerequisites
    print_header "Checking Prerequisites"
    
    # Check required commands
    required_commands=("git" "node" "pnpm" "go" "python3" "pip" "docker")
    missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        echo -e "${RED}Error: The following required commands are missing:${NC}"
        for cmd in "${missing_commands[@]}"; do
            echo -e "  - $cmd"
        done
        echo -e "\n${YELLOW}Please install these dependencies and try again.${NC}"
        exit 1
    fi
    
    # Check Node.js version
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    if ! check_version "Node.js" "$NODE_VERSION" "$NODE_MIN_VERSION"; then
        exit 1
    fi
    
    # Check pnpm version
    PNPM_VERSION=$(pnpm --version)
    if ! check_version "pnpm" "$PNPM_VERSION" "$PNPM_MIN_VERSION"; then
        exit 1
    fi
    
    # Check Go version
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    if ! check_version "Go" "$GO_VERSION" "$GO_MIN_VERSION"; then
        exit 1
    fi
    
    # Check Python version
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    if ! check_version "Python" "$PYTHON_VERSION" "$PYTHON_MIN_VERSION"; then
        exit 1
    fi
    
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
                    echo -e "${RED}Error: Failed to start Docker services for ctrlplane.${NC}"
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

# Run main function
main

