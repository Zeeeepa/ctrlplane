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

# Function to backup data
backup_data() {
    local backup_dir="$HOME/zeeeepa-backup-$(date +%Y%m%d%H%M%S)"
    
    print_header "Backing up data"
    echo "Creating backup directory: $backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup environment files
    echo "Backing up environment files..."
    mkdir -p "$backup_dir/env"
    if [ -f "$BASE_DIR/ctrlplane/.env" ]; then
        cp "$BASE_DIR/ctrlplane/.env" "$backup_dir/env/ctrlplane.env"
    fi
    if [ -f "$BASE_DIR/co-reviewer/.env" ]; then
        cp "$BASE_DIR/co-reviewer/.env" "$backup_dir/env/co-reviewer.env"
    fi
    
    # Backup Docker volumes
    if command -v docker &> /dev/null; then
        echo "Backing up Docker volumes..."
        # Backup Docker volumes
        if command -v docker &> /dev/null; then
            echo "Backing up Docker volumes..."
            for volume in $(docker volume ls -q); do
                mkdir -p "$backup_dir/volumes"
                docker run --rm -v "$volume:/source" -v "$backup_dir/volumes":/backup alpine tar -czf "/backup/${volume}.tar.gz" -C /source .
            done
        fi
    fi
    
    # Backup logs
    if [ -d "$BASE_DIR/logs" ]; then
        echo "Backing up logs..."
        mkdir -p "$backup_dir/logs"
        cp -r "$BASE_DIR/logs" "$backup_dir/"
    fi
    
    echo -e "${GREEN}Backup completed at: $backup_dir${NC}"
    echo -e "${YELLOW}Please keep this backup safe if you need to restore data later.${NC}"
}

# Parse command line arguments
BACKUP=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --backup)
            BACKUP=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --backup    Create a backup before uninstalling"
            echo "  --force, -f Force uninstallation without confirmation"
            echo "  --help, -h  Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Confirm uninstallation
print_header "Zeeeepa Stack Uninstallation"
echo -e "${RED}Warning: This will remove all Zeeeepa stack components and data.${NC}"
echo -e "${RED}Make sure to back up any important data before continuing.${NC}"

if [ "$FORCE" != "true" ]; then
    read -p "Are you sure you want to uninstall the Zeeeepa stack? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
    
    if [ "$BACKUP" != "true" ]; then
        read -p "Would you like to create a backup before uninstalling? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            BACKUP=true
        fi
    fi
fi

# Create backup if requested
if [ "$BACKUP" = "true" ]; then
    backup_data
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

# Remove Docker volumes
if command -v docker &> /dev/null; then
    echo "Removing Docker volumes..."
    if docker volume ls | grep -q "ctrlplane_db-data"; then
        docker volume rm ctrlplane_db-data || true
    fi
fi

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
if [ -d "$BASE_DIR" ]; then
    echo "Removing $BASE_DIR..."
    rm -rf "$BASE_DIR"
    echo -e "${GREEN}Stack directory removed.${NC}"
else
    echo -e "${YELLOW}Stack directory not found at $BASE_DIR, nothing to remove.${NC}"
fi

print_header "Uninstallation Complete"
echo -e "${GREEN}The Zeeeepa stack has been successfully uninstalled.${NC}"
echo -e "${YELLOW}Note: This script does not uninstall system dependencies like Node.js, Go, Python, etc.${NC}"

if [ "$BACKUP" = "true" ]; then
    echo -e "\n${BLUE}A backup of your data was created before uninstallation.${NC}"
    echo -e "${BLUE}You can find it in the backup directory shown above.${NC}"
fi

