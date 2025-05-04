#!/bin/bash

# Zeeeepa Stack Uninstallation Script
# This script removes the Zeeeepa stack components

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load configuration if available
CONFIG_FILE="./zeeeepa-config.sh"
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "No configuration file found, using defaults"
fi

# Set default values if not defined in config
: ${ZEEEEPA_BASE_DIR:="$HOME/zeeeepa-stack"}

# Base directory for all projects
BASE_DIR="$ZEEEEPA_BASE_DIR"

# Function to print section header
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

# Confirm uninstallation
echo -e "${RED}WARNING: This will remove all Zeeeepa stack components from your system.${NC}"
echo -e "${RED}All data and configurations will be lost.${NC}"
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop all services
print_header "Stopping Services"
if [ -d "$BASE_DIR/ctrlplane" ]; then
    echo "Stopping ctrlplane services..."
    cd "$BASE_DIR/ctrlplane"
    docker compose -f docker-compose.dev.yaml down || true
fi

# Kill any running processes
echo "Stopping any running processes..."
pkill -f "pnpm dev" || true

# Remove stack directory
print_header "Removing Stack Directory"
echo "Removing $BASE_DIR..."
rm -rf "$BASE_DIR"

# Remove WSL2 autostart entry
if grep -q Microsoft /proc/version; then
    print_header "Removing WSL2 auto-start"
    if grep -q "zeeeepa-stack/stack.sh" "$HOME/.bashrc"; then
        echo "Removing stack.sh from .bashrc..."
        sed -i '/# Zeeeepa Stack Startup Prompt/,+3d' "$HOME/.bashrc"
        echo -e "${GREEN}Removed stack.sh from .bashrc.${NC}"
    fi
fi

print_header "Uninstallation Complete"
echo -e "${GREEN}The Zeeeepa stack has been successfully uninstalled.${NC}"
echo -e "${YELLOW}Note: Some global dependencies may still remain on your system.${NC}"
echo -e "${YELLOW}You may want to manually uninstall Node.js, Go, Python, Docker, etc. if they are no longer needed.${NC}"

