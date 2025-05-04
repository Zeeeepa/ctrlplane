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

