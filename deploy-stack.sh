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

set -e

# Load configuration if available
CONFIG_FILE="./zeeeepa-config.sh"
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "No configuration file found, using defaults"
fi

# Load common utilities
UTILS_FILE="./zeeeepa-utils.sh"
if [ -f "$UTILS_FILE" ]; then
    source "$UTILS_FILE"
else
    echo "Error: Utilities file not found at $UTILS_FILE"
    exit 1
fi

# Set trap for cleanup on exit
trap cleanup EXIT

# Initialize deployment log
init_deployment_log

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
cd "$ZEEEEPA_BASE_DIR"

# Deploy ctrlplane
if deploy_repo "ctrlplane" "$CTRLPLANE_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/ctrlplane"
    
    echo "Setting up ctrlplane..."
    if ! copy_env_file ".env.example" ".env"; then
        echo -e "${YELLOW}Warning: Environment setup for ctrlplane may be incomplete.${NC}"
    fi
    
    if ! pnpm install; then
        echo -e "${RED}Error: Failed to install dependencies for ctrlplane.${NC}"
        FAILED_COMPONENTS+=("ctrlplane")
    elif ! pnpm build; then
        echo -e "${RED}Error: Failed to build ctrlplane.${NC}"
        FAILED_COMPONENTS+=("ctrlplane")
    else
        # Check if Docker is running
        if ! docker info &>/dev/null; then
            echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
            FAILED_COMPONENTS+=("ctrlplane-docker")
        else
            # Check for port conflicts
            if check_port 3000 || check_port 5432; then
                echo -e "${YELLOW}Warning: Ports 3000 or 5432 are already in use. This may cause conflicts with ctrlplane services.${NC}"
                if ! confirm_continue "Continue with Docker deployment?"; then
                    echo -e "${RED}Docker deployment cancelled.${NC}"
                    FAILED_COMPONENTS+=("ctrlplane-docker")
                fi
            fi
            
            # Start Docker services
            if ! docker compose -f docker-compose.dev.yaml up -d; then
                echo -e "${RED}Error: Failed to start Docker services for ctrlplane.${NC}"
                FAILED_COMPONENTS+=("ctrlplane-docker")
            else
                echo -e "${GREEN}Docker services started successfully.${NC}"
                
                # Wait for database to be ready
                if wait_for_service "PostgreSQL" 5432; then
                    # Run database migrations
                    cd packages/db
                    if ! pnpm migrate; then
                        echo -e "${RED}Error: Failed to run database migrations.${NC}"
                        FAILED_COMPONENTS+=("ctrlplane-db-migrate")
                    else
                        echo -e "${GREEN}Database migrations completed successfully.${NC}"
                    fi
                    cd ../..
                else
                    echo -e "${RED}Error: Database service did not start properly.${NC}"
                    FAILED_COMPONENTS+=("ctrlplane-db")
                fi
            fi
        fi
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Deploy ctrlc-cli
if deploy_repo "ctrlc-cli" "$CTRLC_CLI_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/ctrlc-cli"
    
    echo "Building ctrlc-cli..."
    if ! make build; then
        echo -e "${RED}Error: Failed to build ctrlc-cli.${NC}"
        FAILED_COMPONENTS+=("ctrlc-cli-build")
    elif ! make install; then
        echo -e "${RED}Error: Failed to install ctrlc-cli.${NC}"
        FAILED_COMPONENTS+=("ctrlc-cli-install")
    else
        echo -e "${GREEN}ctrlc-cli built and installed successfully.${NC}"
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Deploy weave
if deploy_repo "weave" "$WEAVE_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/weave"
    
    echo "Installing weave..."
    if ! pip install -e .; then
        echo -e "${RED}Error: Failed to install weave.${NC}"
        FAILED_COMPONENTS+=("weave")
    else
        echo -e "${GREEN}weave installed successfully.${NC}"
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Deploy probot
if deploy_repo "probot" "$PROBOT_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/probot"
    
    echo "Building probot..."
    if ! npm install; then
        echo -e "${RED}Error: Failed to install dependencies for probot.${NC}"
        FAILED_COMPONENTS+=("probot-install")
    elif ! npm run build; then
        echo -e "${RED}Error: Failed to build probot.${NC}"
        FAILED_COMPONENTS+=("probot-build")
    else
        echo -e "${GREEN}probot built successfully.${NC}"
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Deploy pkg.pr.new
if deploy_repo "pkg.pr.new" "$PKG_PR_NEW_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/pkg.pr.new"
    
    echo "Building pkg.pr.new..."
    if ! pnpm install; then
        echo -e "${RED}Error: Failed to install dependencies for pkg.pr.new.${NC}"
        FAILED_COMPONENTS+=("pkg.pr.new-install")
    elif ! pnpm build; then
        echo -e "${RED}Error: Failed to build pkg.pr.new.${NC}"
        FAILED_COMPONENTS+=("pkg.pr.new-build")
    else
        echo -e "${GREEN}pkg.pr.new built successfully.${NC}"
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Deploy tldr
if deploy_repo "tldr" "$TLDR_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/tldr"
    
    echo "Installing tldr..."
    if ! pip install -e .; then
        echo -e "${RED}Error: Failed to install tldr.${NC}"
        FAILED_COMPONENTS+=("tldr")
    else
        echo -e "${GREEN}tldr installed successfully.${NC}"
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Deploy co-reviewer
if deploy_repo "co-reviewer" "$CO_REVIEWER_REPO"; then
    cd "$ZEEEEPA_BASE_DIR/co-reviewer"
    
    echo "Building co-reviewer..."
    if ! copy_env_file ".env.example" ".env"; then
        echo -e "${YELLOW}Warning: Environment setup for co-reviewer may be incomplete.${NC}"
    fi
    
    if ! pnpm install; then
        echo -e "${RED}Error: Failed to install dependencies for co-reviewer.${NC}"
        FAILED_COMPONENTS+=("co-reviewer-install")
    elif ! pnpm build; then
        echo -e "${RED}Error: Failed to build co-reviewer.${NC}"
        FAILED_COMPONENTS+=("co-reviewer-build")
    else
        echo -e "${GREEN}co-reviewer built successfully.${NC}"
    fi
fi

cd "$ZEEEEPA_BASE_DIR"

# Create stack.sh script
print_header "Creating stack.sh script"

cat > "$ZEEEEPA_BASE_DIR/stack.sh" << 'EOF'
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

# Process IDs for background services
declare -A SERVICE_PIDS

# Function to print section header
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
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

# Function to start a service
start_service() {
    local service_name="$1"
    local command="$2"
    local log_file="$BASE_DIR/logs/${service_name}.log"
    
    mkdir -p "$BASE_DIR/logs"
    
    echo -e "${GREEN}Starting ${service_name}...${NC}"
    eval "$command" > "$log_file" 2>&1 &
    local pid=$!
    SERVICE_PIDS["$service_name"]=$pid
    echo -e "${GREEN}${service_name} started with PID ${pid}. Logs at ${log_file}${NC}"
}

# Function to stop all services
stop_all_services() {
    print_header "Stopping all services"
    
    # Stop Docker services
    if [ -d "$BASE_DIR/ctrlplane" ]; then
        echo -e "Stopping ctrlplane Docker services..."
        cd "$BASE_DIR/ctrlplane"
        docker compose -f docker-compose.dev.yaml down
    fi
    
    # Stop background services
    for service_name in "${!SERVICE_PIDS[@]}"; do
        local pid=${SERVICE_PIDS[$service_name]}
        if ps -p $pid > /dev/null; then
            echo -e "Stopping $service_name (PID: $pid)..."
            kill $pid
        fi
    done
    
    echo -e "\n${GREEN}All services stopped.${NC}"
}

# Handle Ctrl+C
trap stop_all_services INT

# Check if running in non-interactive mode
if [ "$1" = "--non-interactive" ] || [ "$1" = "-y" ]; then
    AUTO_START=true
else
    # Prompt user to start the stack
    read -p "Do You Want To Run CtrlPlane Stack? Y/N: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Stack startup cancelled."
        exit 0
    fi
    AUTO_START=true
fi

# Start ctrlplane
if [ -d "$BASE_DIR/ctrlplane" ] && [ "$AUTO_START" = true ]; then
    print_header "Starting ctrlplane"
    cd "$BASE_DIR/ctrlplane"
    
    # Check if Docker is running
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
    
    # Check for port conflicts
    if check_port 3000 || check_port 5432; then
        echo -e "${YELLOW}Warning: Ports 3000 or 5432 are already in use. This may cause conflicts with ctrlplane services.${NC}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Startup cancelled."
            exit 1
        fi
    fi
    
    # Start Docker services
    if ! docker compose -f docker-compose.dev.yaml up -d; then
        echo -e "${RED}Error: Failed to start Docker services for ctrlplane.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}ctrlplane services started.${NC}"
    
    # Wait for database to be ready
    wait_for_service "PostgreSQL" 5432
    wait_for_service "ctrlplane API" 3000
else
    echo -e "${YELLOW}ctrlplane not found or auto-start disabled, skipping startup.${NC}"
fi

# Start other services as needed
print_header "Starting additional services"

# Start co-reviewer
if [ -d "$BASE_DIR/co-reviewer" ] && [ "$AUTO_START" = true ]; then
    cd "$BASE_DIR/co-reviewer"
    start_service "co-reviewer" "pnpm dev"
fi

# Add any other service startup commands here

echo -e "\n${GREEN}All services started successfully!${NC}"
echo -e "${YELLOW}To stop all services, press Ctrl+C or run: $BASE_DIR/stack.sh --stop${NC}"
echo -e "${YELLOW}Service logs are available in the $BASE_DIR/logs directory${NC}"

# Keep script running to allow Ctrl+C to stop services
if [ "$1" != "--stop" ]; then
    echo -e "\nPress Ctrl+C to stop all services..."
    while true; do
        sleep 1
    done
fi
EOF

chmod +x "$ZEEEEPA_BASE_DIR/stack.sh"

# Create uninstall.sh script
print_header "Creating uninstall.sh script"

cat > "$ZEEEEPA_BASE_DIR/uninstall.sh" << 'EOF'
#!/bin/bash

# Zeeeepa Stack Uninstallation Script
# This script removes the Zeeeepa stack from your system

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

# Confirm uninstallation
print_header "Zeeeepa Stack Uninstallation"
echo -e "${RED}Warning: This will remove all Zeeeepa stack components and data.${NC}"
echo -e "${RED}Make sure to back up any important data before continuing.${NC}"
read -p "Are you sure you want to uninstall the Zeeeepa stack? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop all services
print_header "Stopping all services"

# Stop Docker services
if [ -d "$BASE_DIR/ctrlplane" ]; then
    echo "Stopping ctrlplane Docker services..."
    cd "$BASE_DIR/ctrlplane"
    docker compose -f docker-compose.dev.yaml down
fi

# Kill any running processes
echo "Stopping any running processes..."
pkill -f "$BASE_DIR" || true

# Remove WSL2 autostart entry
if grep -q Microsoft /proc/version; then
    print_header "Removing WSL2 auto-start"
    if grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
        echo "Removing stack.sh from .bashrc..."
        sed -i '/zeeeepa-stack\/stack.sh/,+2d' "$HOME/.bashrc"
        echo -e "${GREEN}Removed stack.sh from .bashrc.${NC}"
    else
        echo -e "${YELLOW}stack.sh not found in .bashrc, skipping.${NC}"
    fi
fi

# Remove the stack directory
print_header "Removing stack directory"
echo "Removing $BASE_DIR..."
rm -rf "$BASE_DIR"

print_header "Uninstallation Complete"
echo -e "${GREEN}The Zeeeepa stack has been successfully uninstalled.${NC}"
echo -e "${YELLOW}Note: This script does not uninstall system dependencies like Node.js, Go, Python, etc.${NC}"
EOF

chmod +x "$ZEEEEPA_BASE_DIR/uninstall.sh"

# Add stack.sh to .bashrc for WSL2
if grep -q Microsoft /proc/version; then
    print_header "Setting up WSL2 auto-start"
    if ! grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
        echo -e "\n# Zeeeepa Stack Startup Prompt" >> "$HOME/.bashrc"
        echo "if [ -f \"$ZEEEEPA_BASE_DIR/stack.sh\" ]; then" >> "$HOME/.bashrc"
        echo "    \"$ZEEEEPA_BASE_DIR/stack.sh\"" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
        echo -e "${GREEN}Added stack.sh to .bashrc for WSL2 startup.${NC}"
    else
        echo -e "${YELLOW}stack.sh already in .bashrc, skipping.${NC}"
    fi
fi

# Create logs directory
mkdir -p "$ZEEEEPA_BASE_DIR/logs"

# Print deployment summary
print_deployment_summary

echo -e "\nTo start all services, run:"
echo -e "  ${YELLOW}$ZEEEEPA_BASE_DIR/stack.sh${NC}"
echo -e "\nFor more information, see the DEPLOYMENT.md and OVERVIEW.md files."

