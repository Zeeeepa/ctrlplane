#!/bin/bash

# Zeeeepa Stack Utilities
# Common functions and variables for Zeeeepa stack deployment scripts

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default configuration values
: ${ZEEEEPA_BASE_DIR:="$HOME/zeeeepa-stack"}
: ${CTRLPLANE_REPO:="https://github.com/ctrlplanedev/ctrlplane.git"}
: ${CTRLC_CLI_REPO:="https://github.com/Zeeeepa/ctrlc-cli"}
: ${WEAVE_REPO:="https://github.com/Zeeeepa/weave"}
: ${PROBOT_REPO:="https://github.com/Zeeeepa/probot"}
: ${PKG_PR_NEW_REPO:="https://github.com/Zeeeepa/pkg.pr.new"}
: ${TLDR_REPO:="https://github.com/Zeeeepa/tldr"}
: ${CO_REVIEWER_REPO:="https://github.com/Zeeeepa/co-reviewer"}
: ${VERBOSE_LOGGING:="false"}
: ${NON_INTERACTIVE:="false"}
: ${AUTO_START_SERVICES:="true"}
: ${INSTALL_DEPENDENCIES:="true"}
: ${REQUIRED_SPACE:="5"} # Required space in GB
: ${NODE_MIN_VERSION:="22.10.0"}
: ${PNPM_MIN_VERSION:="10.2.0"}
: ${GO_MIN_VERSION:="1.20.0"}
: ${PYTHON_MIN_VERSION:="3.8.0"}

# Deployment status tracking
DEPLOYED_COMPONENTS=()
FAILED_COMPONENTS=()
DEPLOYMENT_LOG="$ZEEEEPA_BASE_DIR/deployment.log"

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is required but not installed.${NC}"
        return 1
    fi
    return 0
}

# Function to print section header
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

# Function for verbose logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] $1"
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        echo -e "[${timestamp}] $1" >> "$DEPLOYMENT_LOG"
    fi
}

# Function to check if user wants to continue after a warning
confirm_continue() {
    if [ "$NON_INTERACTIVE" = "true" ]; then
        if [ "$2" = "critical" ]; then
            return 1
        else
            return 0
        fi
    fi
    
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
    local version_flag="$4"
    
    if version_lt "$current_version" "$required_version"; then
        echo -e "${YELLOW}Warning: $command_name version $current_version is less than the recommended version ($required_version).${NC}"
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
        if ! confirm_continue "Continue anyway?" "critical"; then
            return 1
        fi
    fi
    return 0
}

# Function to deploy a repository
deploy_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local branch="${3:-main}"
    
    print_header "Deploying $repo_name"
    
    # Create directory if it doesn't exist
    mkdir -p "$ZEEEEPA_BASE_DIR"
    cd "$ZEEEEPA_BASE_DIR"
    
    # Clone or update repository
    if [ -d "$repo_name" ]; then
        echo "Repository $repo_name already exists. Updating..."
        cd "$repo_name"
        
        # Save current branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD)
        
        # Fetch updates
        if ! git fetch origin; then
            echo -e "${RED}Error: Failed to fetch updates for $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        fi
        
        # Check if branch exists
        if git branch -r | grep -q "origin/$branch"; then
            # If not on the desired branch, check it out
            if [ "$current_branch" != "$branch" ]; then
                if ! git checkout "$branch"; then
                    echo -e "${RED}Error: Failed to checkout branch $branch for $repo_name.${NC}"
                    FAILED_COMPONENTS+=("$repo_name")
                    return 1
                fi
            fi
            
            # Pull latest changes
            if ! git pull origin "$branch"; then
                echo -e "${RED}Error: Failed to pull latest changes for $repo_name.${NC}"
                FAILED_COMPONENTS+=("$repo_name")
                return 1
            fi
        else
            echo -e "${YELLOW}Warning: Branch $branch does not exist in repository $repo_name. Staying on current branch $current_branch.${NC}"
        fi
    else
        echo "Cloning repository $repo_name from $repo_url..."
        if ! git clone --branch "$branch" "$repo_url" "$repo_name" 2>/dev/null; then
            # If branch doesn't exist, clone default branch
            if ! git clone "$repo_url" "$repo_name"; then
                echo -e "${RED}Error: Failed to clone repository $repo_name.${NC}"
                FAILED_COMPONENTS+=("$repo_name")
                return 1
            fi
            echo -e "${YELLOW}Warning: Branch $branch does not exist in repository $repo_name. Cloned default branch instead.${NC}"
        fi
        cd "$repo_name"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to change directory to $repo_name.${NC}"
            FAILED_COMPONENTS+=("$repo_name")
            return 1
        fi
    fi
    
    # Verify repository integrity
    if [ ! -d ".git" ]; then
        echo -e "${RED}Error: Repository $repo_name does not appear to be a valid git repository.${NC}"
        FAILED_COMPONENTS+=("$repo_name")
        return 1
    fi
    
    # Add to deployed components list
    DEPLOYED_COMPONENTS+=("$repo_name")
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

# Function to copy environment file with warning
copy_env_file() {
    local source_file="$1"
    local dest_file="$2"
    
    if [ -f "$source_file" ] && [ ! -f "$dest_file" ]; then
        echo -e "${YELLOW}Warning: Copying $source_file to $dest_file${NC}"
        echo -e "${YELLOW}This file may contain example credentials. Make sure to update it with secure values before using in production.${NC}"
        if confirm_continue "Continue with copying the example environment file?"; then
            cp "$source_file" "$dest_file"
            echo -e "${GREEN}Environment file created. Please review and update it with appropriate values.${NC}"
            return 0
        else
            echo -e "${RED}Environment file copy cancelled. You will need to create this file manually.${NC}"
            return 1
        fi
    elif [ -f "$dest_file" ]; then
        echo -e "${GREEN}Environment file $dest_file already exists. Keeping existing file.${NC}"
        return 0
    else
        echo -e "${RED}Error: Source environment file $source_file does not exist.${NC}"
        return 1
    fi
}

# Function to print deployment summary
print_deployment_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}Deployed components:${NC}"
    for component in "${DEPLOYED_COMPONENTS[@]}"; do
        echo -e "  - ${BLUE}$component${NC}: Successfully deployed"
    done
    
    if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
        echo -e "\n${RED}Failed components:${NC}"
        for component in "${FAILED_COMPONENTS[@]}"; do
            echo -e "  - ${RED}$component${NC}: Deployment failed"
        done
        echo -e "\n${YELLOW}Please check the logs for more information on failed components.${NC}"
    fi
    
    echo -e "\n${GREEN}Deployment completed at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    
    if [ "$VERBOSE_LOGGING" = "true" ]; then
        echo -e "\n${BLUE}Detailed logs are available at:${NC} $DEPLOYMENT_LOG"
    fi
}

# Function to create a backup of a file
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        echo "Created backup of $file at $backup"
        return 0
    fi
    return 1
}

# Function to handle errors and cleanup
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n${RED}Error occurred during deployment. Cleaning up...${NC}"
        # Add cleanup code here if needed
        echo -e "${YELLOW}If any services were started, you may need to stop them manually.${NC}"
    fi
    
    # Print deployment summary
    print_deployment_summary
    
    exit $exit_code
}

# Initialize deployment log
init_deployment_log() {
    mkdir -p "$(dirname "$DEPLOYMENT_LOG")"
    echo "=== Zeeeepa Stack Deployment Log - $(date '+%Y-%m-%d %H:%M:%S') ===" > "$DEPLOYMENT_LOG"
    echo "Base directory: $ZEEEEPA_BASE_DIR" >> "$DEPLOYMENT_LOG"
    echo "Verbose logging: $VERBOSE_LOGGING" >> "$DEPLOYMENT_LOG"
    echo "Non-interactive: $NON_INTERACTIVE" >> "$DEPLOYMENT_LOG"
    echo "===================================================" >> "$DEPLOYMENT_LOG"
}

