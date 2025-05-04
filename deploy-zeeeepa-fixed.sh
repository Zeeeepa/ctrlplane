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
# curl -sSL https://raw.githubusercontent.com/Zeeeepa/ctrlplane/main/deploy-zeeeepa-fixed.sh | bash

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
    read -p "$1 (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
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
            return 1
        }
        
        # Fetch updates
        if ! git fetch origin; then
            echo -e "${RED}Error: Failed to fetch updates for $repo_name.${NC}"
            return 1
        fi
        
        # Pull latest changes
        if ! git pull origin; then
            echo -e "${RED}Error: Failed to pull latest changes for $repo_name.${NC}"
            return 1
        fi
    else
        echo "Cloning repository $repo_name from $repo_url..."
        if ! git clone "$repo_url" "$repo_name"; then
            echo -e "${RED}Error: Failed to clone repository $repo_name.${NC}"
            return 1
        fi
        cd "$repo_name" || {
            echo -e "${RED}Error: Failed to change directory to $repo_name.${NC}"
            return 1
        }
    fi
    
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
    if ! confirm_continue "Do you want to proceed with the deployment?"; then
        echo -e "${YELLOW}Deployment cancelled.${NC}"
        exit 0
    fi
    
    # Check prerequisites
    print_header "Checking Prerequisites"
    
    # Check for git
    if ! command_exists git; then
        echo -e "${RED}Error: git is required but not installed.${NC}"
        exit 1
    fi
    
    # Check for curl
    if ! command_exists curl; then
        echo -e "${RED}Error: curl is required but not installed.${NC}"
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
        if command_exists pnpm; then
            pnpm install
            pnpm build
            
            # Start Docker services
            if command_exists docker && command_exists docker-compose; then
                docker compose -f docker-compose.dev.yaml up -d
                
                # Run database migrations
                cd packages/db && pnpm migrate && cd ../..
                echo -e "${GREEN}ctrlplane setup completed successfully${NC}"
            else
                echo -e "${YELLOW}Warning: Docker or docker-compose not found. Skipping Docker setup.${NC}"
            fi
        else
            echo -e "${YELLOW}Warning: pnpm not found. Skipping ctrlplane setup.${NC}"
        fi
    fi
    
    # Deploy ctrlc-cli
    if deploy_repo "ctrlc-cli" "$CTRLC_CLI_REPO"; then
        print_header "Setting up ctrlc-cli"
        cd "$ZEEEEPA_BASE_DIR/ctrlc-cli" || exit 1
        
        # Build and install
        echo "Building ctrlc-cli..."
        if command_exists make && command_exists go; then
            make build
            make install
            echo -e "${GREEN}ctrlc-cli setup completed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: make or go not found. Skipping ctrlc-cli setup.${NC}"
        fi
    fi
    
    # Deploy weave
    if deploy_repo "weave" "$WEAVE_REPO"; then
        print_header "Setting up weave"
        cd "$ZEEEEPA_BASE_DIR/weave" || exit 1
        
        # Install in development mode
        echo "Installing weave..."
        if command_exists pip || command_exists pip3; then
            pip install -e . || pip3 install -e .
            echo -e "${GREEN}weave setup completed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: pip not found. Skipping weave setup.${NC}"
        fi
    fi
    
    # Deploy probot
    if deploy_repo "probot" "$PROBOT_REPO"; then
        print_header "Setting up probot"
        cd "$ZEEEEPA_BASE_DIR/probot" || exit 1
        
        # Install dependencies
        echo "Installing dependencies..."
        if command_exists npm; then
            npm install
            npm run build
            echo -e "${GREEN}probot setup completed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: npm not found. Skipping probot setup.${NC}"
        fi
    fi
    
    # Deploy pkg.pr.new
    if deploy_repo "pkg.pr.new" "$PKG_PR_NEW_REPO"; then
        print_header "Setting up pkg.pr.new"
        cd "$ZEEEEPA_BASE_DIR/pkg.pr.new" || exit 1
        
        # Install dependencies
        echo "Installing dependencies..."
        if command_exists pnpm; then
            pnpm install
            pnpm build
            echo -e "${GREEN}pkg.pr.new setup completed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: pnpm not found. Skipping pkg.pr.new setup.${NC}"
        fi
    fi
    
    # Deploy tldr
    if deploy_repo "tldr" "$TLDR_REPO"; then
        print_header "Setting up tldr"
        cd "$ZEEEEPA_BASE_DIR/tldr" || exit 1
        
        # Install in development mode
        echo "Installing tldr..."
        if command_exists pip || command_exists pip3; then
            pip install -e . || pip3 install -e .
            echo -e "${GREEN}tldr setup completed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: pip not found. Skipping tldr setup.${NC}"
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
            pnpm install
            pnpm build
            echo -e "${GREEN}co-reviewer setup completed successfully${NC}"
        else
            echo -e "${YELLOW}Warning: pnpm not found. Skipping co-reviewer setup.${NC}"
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
}

# Run the deployment
deploy_stack

