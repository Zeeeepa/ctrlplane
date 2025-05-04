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

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Base directory for all projects
BASE_DIR="$HOME/zeeeepa-stack"

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is required but not installed.${NC}"
        exit 1
    fi
}

# Function to print section header
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

# Check prerequisites
print_header "Checking Prerequisites"

check_command git
check_command node
check_command pnpm
check_command go
check_command python3
check_command pip
check_command docker

# Check Node.js version
NODE_VERSION=$(node -v | cut -d 'v' -f 2)
if [[ $(echo "$NODE_VERSION 22.10.0" | awk '{print ($1 < $2)}') -eq 1 ]]; then
    echo -e "${YELLOW}Warning: Node.js version $NODE_VERSION is less than the recommended version (22.10.0).${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check pnpm version
PNPM_VERSION=$(pnpm --version)
if [[ $(echo "$PNPM_VERSION 10.2.0" | awk '{print ($1 < $2)}') -eq 1 ]]; then
    echo -e "${YELLOW}Warning: pnpm version $PNPM_VERSION is less than the recommended version (10.2.0).${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create base directory
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# Deploy ctrlplane
print_header "Deploying ctrlplane"
if [ -d "ctrlplane" ]; then
    echo "ctrlplane directory already exists. Updating..."
    cd ctrlplane
    git pull
else
    echo "Cloning ctrlplane repository..."
    git clone https://github.com/ctrlplanedev/ctrlplane.git
    cd ctrlplane
fi

echo "Setting up ctrlplane..."
cp .env.example .env
pnpm install
pnpm build
docker compose -f docker-compose.dev.yaml up -d
cd packages/db && pnpm migrate && cd ../..

cd "$BASE_DIR"

# Deploy ctrlc-cli
print_header "Deploying ctrlc-cli"
if [ -d "ctrlc-cli" ]; then
    echo "ctrlc-cli directory already exists. Updating..."
    cd ctrlc-cli
    git pull
else
    echo "Cloning ctrlc-cli repository..."
    git clone https://github.com/Zeeeepa/ctrlc-cli
    cd ctrlc-cli
fi

echo "Building ctrlc-cli..."
make build
make install

cd "$BASE_DIR"

# Deploy weave
print_header "Deploying weave"
if [ -d "weave" ]; then
    echo "weave directory already exists. Updating..."
    cd weave
    git pull
else
    echo "Cloning weave repository..."
    git clone https://github.com/Zeeeepa/weave
    cd weave
fi

echo "Installing weave..."
pip install -e .

cd "$BASE_DIR"

# Deploy probot
print_header "Deploying probot"
if [ -d "probot" ]; then
    echo "probot directory already exists. Updating..."
    cd probot
    git pull
else
    echo "Cloning probot repository..."
    git clone https://github.com/Zeeeepa/probot
    cd probot
fi

echo "Building probot..."
npm install
npm run build

cd "$BASE_DIR"

# Deploy pkg.pr.new
print_header "Deploying pkg.pr.new"
if [ -d "pkg.pr.new" ]; then
    echo "pkg.pr.new directory already exists. Updating..."
    cd pkg.pr.new
    git pull
else
    echo "Cloning pkg.pr.new repository..."
    git clone https://github.com/Zeeeepa/pkg.pr.new
    cd pkg.pr.new
fi

echo "Building pkg.pr.new..."
pnpm install
pnpm build

cd "$BASE_DIR"

# Deploy tldr
print_header "Deploying tldr"
if [ -d "tldr" ]; then
    echo "tldr directory already exists. Updating..."
    cd tldr
    git pull
else
    echo "Cloning tldr repository..."
    git clone https://github.com/Zeeeepa/tldr
    cd tldr
fi

echo "Installing tldr..."
pip install -e .

cd "$BASE_DIR"

# Deploy co-reviewer
print_header "Deploying co-reviewer"
if [ -d "co-reviewer" ]; then
    echo "co-reviewer directory already exists. Updating..."
    cd co-reviewer
    git pull
else
    echo "Cloning co-reviewer repository..."
    git clone https://github.com/Zeeeepa/co-reviewer
    cd co-reviewer
fi

echo "Building co-reviewer..."
if [ -f ".env.example" ]; then
    cp .env.example .env
fi
pnpm install
pnpm build

cd "$BASE_DIR"

# Create stack.sh script
print_header "Creating stack.sh script"
cat > "$BASE_DIR/stack.sh" << 'EOF'
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

# Prompt user to start the stack
read -p "Do You Want To Run CtrlPlane Stack? Y/N: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Stack startup cancelled."
    exit 0
fi

# Start ctrlplane
print_header "Starting ctrlplane"
cd "$BASE_DIR/ctrlplane"
docker compose -f docker-compose.dev.yaml up -d
echo -e "${GREEN}ctrlplane services started.${NC}"

# Start other services as needed
print_header "Starting additional services"

# Start co-reviewer
cd "$BASE_DIR/co-reviewer"
echo -e "${GREEN}Starting co-reviewer...${NC}"
pnpm dev &

# Add any other service startup commands here

echo -e "\n${GREEN}All services started successfully!${NC}"
echo -e "${YELLOW}To stop the services, run: docker compose -f $BASE_DIR/ctrlplane/docker-compose.dev.yaml down${NC}"
EOF

chmod +x "$BASE_DIR/stack.sh"

# Add stack.sh to .bashrc for WSL2
if grep -q Microsoft /proc/version; then
    print_header "Setting up WSL2 auto-start"
    if ! grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
        echo -e "\n# Zeeeepa Stack Startup Prompt" >> "$HOME/.bashrc"
        echo "if [ -f \"$BASE_DIR/stack.sh\" ]; then" >> "$HOME/.bashrc"
        echo "    \"$BASE_DIR/stack.sh\"" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
        echo -e "${GREEN}Added stack.sh to .bashrc for WSL2 startup.${NC}"
    else
        echo -e "${YELLOW}stack.sh already in .bashrc, skipping.${NC}"
    fi
fi

print_header "Deployment Summary"
echo -e "${GREEN}The Zeeeepa stack has been successfully deployed to $BASE_DIR${NC}"
echo -e "Components installed:"
echo -e "  - ${BLUE}ctrlplane${NC}: A deployment orchestration tool"
echo -e "  - ${BLUE}ctrlc-cli${NC}: CLI for ctrlplane"
echo -e "  - ${BLUE}weave${NC}: AI toolkit for developing applications"
echo -e "  - ${BLUE}probot${NC}: Framework for building GitHub Apps"
echo -e "  - ${BLUE}pkg.pr.new${NC}: Continuous preview releases for libraries"
echo -e "  - ${BLUE}tldr${NC}: PR summarizer tool"
echo -e "  - ${BLUE}co-reviewer${NC}: Code review tool"
echo -e "\nTo start all services, run:"
echo -e "  ${YELLOW}$BASE_DIR/stack.sh${NC}"
echo -e "\nFor more information, see the DEPLOYMENT.md and OVERVIEW.md files."

