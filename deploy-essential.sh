#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
  log_info "Checking dependencies..."
  
  # Check for git
  if ! command_exists git; then
    log_error "Git is not installed. Please install git and try again."
    exit 1
  fi
  
  # Check for Docker and Docker Compose
  if ! command_exists docker; then
    log_warning "Docker is not installed. Some components may require Docker."
  else
    if ! docker info > /dev/null 2>&1; then
      log_warning "Docker daemon is not running. Please start Docker daemon."
    fi
    
    if ! command_exists docker-compose; then
      log_warning "Docker Compose is not installed. Some components may require Docker Compose."
    fi
  fi
  
  # Check for Node.js and pnpm
  if ! command_exists node; then
    log_warning "Node.js is not installed. Installing Node.js..."
    curl -fsSL https://fnm.vercel.app/install | bash
    export PATH="$HOME/.fnm:$PATH"
    eval "$(fnm env)"
    fnm install 22
    fnm use 22
  fi
  
  if ! command_exists pnpm; then
    log_warning "pnpm is not installed. Installing pnpm..."
    npm install -g pnpm
  fi
  
  # Check for Python
  if ! command_exists python3; then
    log_warning "Python 3 is not installed. Some components require Python."
  else
    if ! command_exists pip3; then
      log_warning "pip3 is not installed. Installing pip3..."
      curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
      python3 get-pip.py
      rm get-pip.py
    fi
  fi
  
  log_success "Dependency check completed."
}

# Create workspace directory
create_workspace() {
  log_info "Creating workspace directory..."
  
  WORKSPACE_DIR="$1"
  if [ -d "$WORKSPACE_DIR" ]; then
    log_warning "Workspace directory already exists. Using existing directory."
  else
    mkdir -p "$WORKSPACE_DIR"
    log_success "Workspace directory created at $WORKSPACE_DIR"
  fi
  
  cd "$WORKSPACE_DIR"
  log_info "Working in directory: $(pwd)"
}

# Clone repositories
clone_repositories() {
  log_info "Cloning repositories..."
  
  # Define repositories to clone (excluding ctrlplane and ctrlc-cli)
  REPOS=(
    "https://github.com/Zeeeepa/weave.git"
    "https://github.com/Zeeeepa/probot.git"
    "https://github.com/Zeeeepa/pkg.pr.new.git"
    "https://github.com/Zeeeepa/tldr.git"
    "https://github.com/Zeeeepa/co-reviewer.git"
  )
  
  for REPO in "${REPOS[@]}"; do
    REPO_NAME=$(basename "$REPO" .git)
    if [ -d "$REPO_NAME" ]; then
      log_warning "Repository $REPO_NAME already exists. Pulling latest changes..."
      (cd "$REPO_NAME" && git pull)
    else
      log_info "Cloning $REPO_NAME..."
      git clone "$REPO"
    fi
  done
  
  log_success "All repositories cloned successfully."
}

# Setup weave
setup_weave() {
  log_info "Setting up weave..."
  
  cd weave
  
  # Create Python virtual environment
  log_info "Creating Python virtual environment..."
  python3 -m venv venv
  source venv/bin/activate
  
  # Install dependencies
  log_info "Installing weave dependencies..."
  pip install -e .
  
  # Deactivate virtual environment
  deactivate
  
  cd ..
  log_success "weave setup completed."
}

# Setup probot
setup_probot() {
  log_info "Setting up probot..."
  
  cd probot
  
  # Install dependencies
  log_info "Installing probot dependencies..."
  npm install
  
  # Build the project
  log_info "Building probot..."
  npm run build
  
  cd ..
  log_success "probot setup completed."
}

# Setup pkg.pr.new
setup_pkg_pr_new() {
  log_info "Setting up pkg.pr.new..."
  
  cd pkg.pr.new
  
  # Install dependencies
  log_info "Installing pkg.pr.new dependencies..."
  pnpm install
  
  # Build the project
  log_info "Building pkg.pr.new..."
  pnpm build
  
  cd ..
  log_success "pkg.pr.new setup completed."
}

# Setup tldr
setup_tldr() {
  log_info "Setting up tldr..."
  
  cd tldr
  
  # Create Python virtual environment
  log_info "Creating Python virtual environment..."
  python3 -m venv venv
  source venv/bin/activate
  
  # Install dependencies
  log_info "Installing tldr dependencies..."
  pip install -e .
  
  # Deactivate virtual environment
  deactivate
  
  cd ..
  log_success "tldr setup completed."
}

# Setup co-reviewer
setup_co_reviewer() {
  log_info "Setting up co-reviewer..."
  
  cd co-reviewer
  
  # Copy example env file if .env doesn't exist
  if [ ! -f .env ]; then
    cp .env.example .env
    log_info "Created .env file from example. Please update with your configuration."
  fi
  
  # Install dependencies
  log_info "Installing co-reviewer dependencies..."
  pnpm install
  
  # Build the project
  log_info "Building co-reviewer..."
  pnpm build
  
  cd ..
  log_success "co-reviewer setup completed."
}

# Create Docker Compose configuration for the essential components
create_docker_compose() {
  log_info "Creating Docker Compose configuration for essential components..."
  
  cat > docker-compose.essential.yaml << 'EOL'
version: '3.8'

services:
  # co-reviewer service
  co-reviewer:
    build:
      context: ./co-reviewer
      dockerfile: Dockerfile
    ports:
      - "3001:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # probot service
  probot:
    build:
      context: ./probot
      dockerfile: Dockerfile
    ports:
      - "3002:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped

  # pkg.pr.new service
  pkg-pr-new:
    build:
      context: ./pkg.pr.new
      dockerfile: Dockerfile
    ports:
      - "3003:3000"
    environment:
      - NODE_ENV=production
    restart: unless-stopped
EOL

  # Create Dockerfiles for services that don't have them
  
  # co-reviewer Dockerfile
  if [ ! -f "co-reviewer/Dockerfile" ]; then
    cat > co-reviewer/Dockerfile << 'EOL'
FROM node:22-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN pnpm build

# Production image
FROM node:22-alpine

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy built application
COPY --from=builder /app/package.json /app/pnpm-lock.yaml* ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

# Expose port
EXPOSE 3000

# Start the application
CMD ["pnpm", "start"]
EOL
  fi

  # probot Dockerfile
  if [ ! -f "probot/Dockerfile" ]; then
    cat > probot/Dockerfile << 'EOL'
FROM node:22-alpine

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
EOL
  fi

  # pkg.pr.new Dockerfile
  if [ ! -f "pkg.pr.new/Dockerfile" ]; then
    cat > pkg.pr.new/Dockerfile << 'EOL'
FROM node:22-alpine AS builder

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy package files
COPY package.json pnpm-lock.yaml* pnpm-workspace.yaml* ./

# Copy workspace packages
COPY packages ./packages

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build the application
RUN pnpm build

# Production image
FROM node:22-alpine

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy built application
COPY --from=builder /app/package.json /app/pnpm-lock.yaml* /app/pnpm-workspace.yaml* ./
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/node_modules ./node_modules

# Expose port
EXPOSE 3000

# Start the application
CMD ["pnpm", "start"]
EOL
  fi

  log_success "Docker Compose configuration created at docker-compose.essential.yaml"
}

# Create integration script for ctrlplane
create_integration_script() {
  log_info "Creating integration script for ctrlplane..."
  
  cat > integrate-with-ctrlplane.sh << 'EOL'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if ctrlc-cli is available
if ! command -v ctrlc &> /dev/null; then
  log_error "ctrlc-cli is not installed. Please install ctrlc-cli first."
  exit 1
fi

# Register services with ctrlplane
log_info "Registering services with ctrlplane..."

# Register co-reviewer
log_info "Registering co-reviewer service..."
ctrlc service create --name co-reviewer --url http://localhost:3001

# Register probot
log_info "Registering probot service..."
ctrlc service create --name probot --url http://localhost:3002

# Register pkg.pr.new
log_info "Registering pkg.pr.new service..."
ctrlc service create --name pkg-pr-new --url http://localhost:3003

log_success "All services registered with ctrlplane."
log_info "You can view registered services with: ctrlc service list"
EOL

  chmod +x integrate-with-ctrlplane.sh
  log_success "Integration script created at integrate-with-ctrlplane.sh"
}

# Main function
main() {
  echo -e "${GREEN}=========================================${NC}"
  echo -e "${GREEN}   Essential Components Deployment       ${NC}"
  echo -e "${GREEN}=========================================${NC}"
  
  # Parse command line arguments
  WORKSPACE_DIR="./zeeeepa-essential"
  SKIP_EXISTING=false
  
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      --workspace)
        WORKSPACE_DIR="$2"
        shift
        ;;
      --skip-existing)
        SKIP_EXISTING=true
        ;;
      *)
        log_error "Unknown parameter: $1"
        exit 1
        ;;
    esac
    shift
  done
  
  # Check dependencies
  check_dependencies
  
  # Create workspace
  create_workspace "$WORKSPACE_DIR"
  
  # Clone repositories
  clone_repositories
  
  # Setup each component
  if [ "$SKIP_EXISTING" = true ]; then
    log_info "Skipping setup for existing components..."
  else
    setup_weave
    setup_probot
    setup_pkg_pr_new
    setup_tldr
    setup_co_reviewer
  fi
  
  # Create Docker Compose configuration
  create_docker_compose
  
  # Create integration script
  create_integration_script
  
  echo -e "${GREEN}=========================================${NC}"
  echo -e "${GREEN}   Deployment Completed Successfully    ${NC}"
  echo -e "${GREEN}=========================================${NC}"
  echo ""
  echo -e "To start the essential components with Docker Compose, run:"
  echo -e "${BLUE}cd $WORKSPACE_DIR && docker-compose -f docker-compose.essential.yaml up -d${NC}"
  echo ""
  echo -e "To integrate with your existing ctrlplane installation, run:"
  echo -e "${BLUE}cd $WORKSPACE_DIR && ./integrate-with-ctrlplane.sh${NC}"
  echo ""
  echo -e "Individual components can be found in their respective directories:"
  echo -e "- ${BLUE}weave${NC}: AI toolkit for developing applications"
  echo -e "- ${BLUE}probot${NC}: Framework for building GitHub Apps"
  echo -e "- ${BLUE}pkg.pr.new${NC}: Continuous preview releases for libraries"
  echo -e "- ${BLUE}tldr${NC}: PR summarizer tool"
  echo -e "- ${BLUE}co-reviewer${NC}: Code review assistant"
  echo ""
  echo -e "For more information, refer to the README.md in each component's directory."
}

# Run the main function
main "$@"

