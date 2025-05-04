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

# Function to check service health
check_service_health() {
    local service_name="$1"
    local pid="${SERVICE_PIDS[$service_name]}"
    
    if [ -z "$pid" ]; then
        echo -e "${RED}Service $service_name is not running.${NC}"
        return 1
    fi
    
    if ! ps -p $pid > /dev/null; then
        echo -e "${RED}Service $service_name (PID: $pid) has stopped unexpectedly.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Service $service_name (PID: $pid) is running.${NC}"
    return 0
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
            # Wait for service to stop
            local attempts=0
            while ps -p $pid > /dev/null && [ $attempts -lt 10 ]; do
                sleep 1
                attempts=$((attempts + 1))
            done
            # Force kill if still running
            if ps -p $pid > /dev/null; then
                echo -e "${YELLOW}Service $service_name did not stop gracefully, forcing...${NC}"
                kill -9 $pid
            fi
        fi
    done
    
    echo -e "\n${GREEN}All services stopped.${NC}"
    exit 0
}

# Function to show service status
show_service_status() {
    print_header "Service Status"
    
    # Check Docker services
    if [ -d "$BASE_DIR/ctrlplane" ]; then
        echo -e "ctrlplane Docker services:"
        cd "$BASE_DIR/ctrlplane"
        docker compose -f docker-compose.dev.yaml ps
    fi
    
    # Check background services
    echo -e "\nBackground services:"
    if [ ${#SERVICE_PIDS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No background services are running.${NC}"
    else
        for service_name in "${!SERVICE_PIDS[@]}"; do
            check_service_health "$service_name"
        done
    fi
}

# Function to show help
show_help() {
    echo -e "Zeeeepa Stack Management Script"
    echo -e "\nUsage: $0 [options]"
    echo -e "\nOptions:"
    echo -e "  --help, -h             Show this help message"
    echo -e "  --start, -s            Start all services (default if no option provided)"
    echo -e "  --stop                 Stop all services"
    echo -e "  --restart, -r          Restart all services"
    echo -e "  --status               Show service status"
    echo -e "  --logs [service]       Show logs for a specific service or all services"
    echo -e "  --non-interactive, -y  Start services without prompting"
    echo -e "\nExamples:"
    echo -e "  $0                     Start services with prompt"
    echo -e "  $0 --non-interactive   Start services without prompt"
    echo -e "  $0 --stop              Stop all services"
    echo -e "  $0 --logs ctrlplane    Show logs for ctrlplane"
}

# Function to show logs
show_logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        # Show all logs
        print_header "All Service Logs"
        echo -e "${YELLOW}Press Ctrl+C to exit logs view${NC}\n"
        tail -f "$BASE_DIR/logs"/*.log
    else
        # Show logs for specific service
        local log_file="$BASE_DIR/logs/${service}.log"
        
        if [ -f "$log_file" ]; then
            print_header "Logs for $service"
            echo -e "${YELLOW}Press Ctrl+C to exit logs view${NC}\n"
            tail -f "$log_file"
        elif [ "$service" = "ctrlplane" ] && [ -d "$BASE_DIR/ctrlplane" ]; then
            print_header "Logs for ctrlplane Docker services"
            echo -e "${YELLOW}Press Ctrl+C to exit logs view${NC}\n"
            cd "$BASE_DIR/ctrlplane"
            docker compose -f docker-compose.dev.yaml logs -f
        else
            echo -e "${RED}No logs found for service: $service${NC}"
            echo -e "Available log files:"
            ls -1 "$BASE_DIR/logs" | sed 's/\.log$//'
        fi
    fi
}

# Handle Ctrl+C
trap stop_all_services INT

# Parse command line arguments
COMMAND="start"
NON_INTERACTIVE=false
LOG_SERVICE=""

if [ $# -gt 0 ]; then
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --start|-s)
            COMMAND="start"
            ;;
        --stop)
            stop_all_services
            ;;
        --restart|-r)
            COMMAND="restart"
            ;;
        --status)
            show_service_status
            exit 0
            ;;
        --logs)
            COMMAND="logs"
            if [ $# -gt 1 ]; then
                LOG_SERVICE="$2"
            fi
            ;;
        --non-interactive|-y)
            NON_INTERACTIVE=true
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
fi

# Handle logs command
if [ "$COMMAND" = "logs" ]; then
    show_logs "$LOG_SERVICE"
    exit 0
fi

# Handle restart command
if [ "$COMMAND" = "restart" ]; then
    stop_all_services
    # Continue to start services
fi

# Prompt user to start the stack if not in non-interactive mode
if [ "$NON_INTERACTIVE" = false ]; then
    read -p "Do You Want To Run CtrlPlane Stack? Y/N: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Stack startup cancelled."
        exit 0
    fi
fi

# Start ctrlplane
if [ -d "$BASE_DIR/ctrlplane" ]; then
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
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Continue anyway? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Startup cancelled."
                exit 1
            fi
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
    echo -e "${YELLOW}ctrlplane not found, skipping startup.${NC}"
fi

# Start other services as needed
print_header "Starting additional services"

# Start co-reviewer
if [ -d "$BASE_DIR/co-reviewer" ]; then
    cd "$BASE_DIR/co-reviewer"
    start_service "co-reviewer" "pnpm dev"
    
    # Wait for co-reviewer to be ready
    wait_for_service "co-reviewer" 3001 || echo -e "${YELLOW}Warning: co-reviewer service may not be fully ready.${NC}"
fi

# Add any other service startup commands here

echo -e "\n${GREEN}All services started successfully!${NC}"
echo -e "${YELLOW}To stop all services, press Ctrl+C or run: $0 --stop${NC}"
echo -e "${YELLOW}To view service status, run: $0 --status${NC}"
echo -e "${YELLOW}To view service logs, run: $0 --logs [service]${NC}"
echo -e "${YELLOW}Service logs are available in the $BASE_DIR/logs directory${NC}"

# Keep script running to allow Ctrl+C to stop services
echo -e "\nPress Ctrl+C to stop all services..."
while true; do
    # Check service health every 30 seconds
    sleep 30
    
    # Check Docker services
    if [ -d "$BASE_DIR/ctrlplane" ]; then
        if ! docker ps | grep -q "ctrlplane"; then
            echo -e "${RED}Warning: ctrlplane Docker services are not running.${NC}"
        fi
    fi
    
    # Check background services
    for service_name in "${!SERVICE_PIDS[@]}"; do
        if ! check_service_health "$service_name" > /dev/null; then
            echo -e "${RED}Warning: Service $service_name has stopped unexpectedly.${NC}"
            echo -e "${YELLOW}Check logs with: $0 --logs $service_name${NC}"
        fi
    done
done

