#!/bin/bash

# Zeeeepa Stack Startup Script
# This script starts all services in the Zeeeepa stack

# Exit on error
set -e

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

# Function to check if directory exists before cd
safe_cd() {
    if [ ! -d "$1" ]; then
        echo -e "${RED}Error: Directory $1 does not exist.${NC}"
        exit 1
    fi
    cd "$1"
}

# Cleanup function for trap
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    # Add cleanup code here if needed
    echo -e "${YELLOW}If any services were started, you may need to stop them manually.${NC}"
}

# Set trap for cleanup on exit
trap cleanup EXIT INT TERM

# Check if running in non-interactive mode
if [ "$NON_INTERACTIVE" = "true" ]; then
    REPLY="y"
else
    # Prompt user to start the stack
    read -p "Do You Want To Run CtrlPlane Stack? Y/N: " -n 1 -r
    echo
fi

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Stack startup cancelled."
    exit 0
fi

# Start ctrlplane
print_header "Starting ctrlplane"
if [ -d "$BASE_DIR/ctrlplane" ]; then
    safe_cd "$BASE_DIR/ctrlplane"
    docker compose -f docker-compose.dev.yaml up -d
    echo -e "${GREEN}ctrlplane services started.${NC}"
else
    echo -e "${YELLOW}Warning: ctrlplane directory not found at $BASE_DIR/ctrlplane${NC}"
    echo -e "${YELLOW}Skipping ctrlplane startup.${NC}"
fi

# Start other services as needed
print_header "Starting additional services"

# Start co-reviewer
if [ -d "$BASE_DIR/co-reviewer" ]; then
    safe_cd "$BASE_DIR/co-reviewer"
    echo -e "${GREEN}Starting co-reviewer...${NC}"
    pnpm dev &
else
    echo -e "${YELLOW}Warning: co-reviewer directory not found at $BASE_DIR/co-reviewer${NC}"
    echo -e "${YELLOW}Skipping co-reviewer startup.${NC}"
fi

# Add any other service startup commands here

echo -e "\n${GREEN}All services started successfully!${NC}"
echo -e "${YELLOW}To stop the services, run: docker compose -f $BASE_DIR/ctrlplane/docker-compose.dev.yaml down${NC}"
