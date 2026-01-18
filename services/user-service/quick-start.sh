#!/bin/bash

# Product Service Quick Start Script
# Helps you get started with the Product Service quickly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main menu
show_menu() {
    clear
    print_header "PRODUCT SERVICE QUICK START"
    echo ""
    echo "Choose how to run the Product Service:"
    echo ""
    echo "1) Standalone (No dependencies - fastest)"
    echo "   - Uses in-memory mock database"
    echo "   - Perfect for quick testing"
    echo ""
    echo "2) With Docker Compose (Full stack - recommended)"
    echo "   - PostgreSQL + Redis + RabbitMQ"
    echo "   - All features enabled"
    echo ""
    echo "3) With PostgreSQL only"
    echo "   - Persistent database"
    echo "   - No caching or queue"
    echo ""
    echo "4) Test the running service"
    echo ""
    echo "5) View logs (Docker Compose)"
    echo ""
    echo "6) Stop all services"
    echo ""
    echo "0) Exit"
    echo ""
    read -p "Enter choice [0-6]: " choice
    echo ""
}

# Option 1: Standalone
run_standalone() {
    print_header "STARTING STANDALONE MODE"
    
    # Check Python
    if ! command_exists python3; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    print_info "Installing minimal dependencies..."
    pip install fastapi uvicorn pydantic pydantic-settings prometheus-client python-json-logger
    
    print_success "Dependencies installed"
    echo ""
    
    print_info "Starting service on port 8081..."
    print_info "Press Ctrl+C to stop"
    echo ""
    
    python3 -m uvicorn app.main:app --reload --port 8081
}

# Option 2: Docker Compose
run_docker_compose() {
    print_header "STARTING WITH DOCKER COMPOSE"
    
    # Check Docker
    if ! command_exists docker; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    print_info "Starting all services..."
    docker-compose up -d
    
    echo ""
    print_success "Services started!"
    echo ""
    
    print_info "Waiting for services to be ready..."
    sleep 5
    
    echo ""
    print_success "Services are running:"
    echo ""
    echo "  Product Service: http://localhost:8081"
    echo "  RabbitMQ UI:     http://localhost:15672 (guest/guest)"
    echo ""
    
    print_info "View logs:"
    echo "  docker-compose logs -f product-service"
    echo ""
    
    print_info "Stop services:"
    echo "  docker-compose down"
}

# Option 3: PostgreSQL only
run_with_postgres() {
    print_header "STARTING WITH POSTGRESQL"
    
    # Check Docker
    if ! command_exists docker; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check if PostgreSQL container exists
    if docker ps -a --format '{{.Names}}' | grep -q '^postgres-local$'; then
        print_info "PostgreSQL container already exists"
        docker start postgres-local
    else
        print_info "Starting PostgreSQL..."
        docker run -d \
            --name postgres-local \
            -e POSTGRES_PASSWORD=postgres \
            -e POSTGRES_DB=products_db \
            -p 5432:5432 \
            postgres:15
    fi
    
    print_success "PostgreSQL started"
    echo ""
    
    print_info "Installing Python dependencies..."
    pip install -r requirements.txt
    
    print_success "Dependencies installed"
    echo ""
    
    print_info "Starting service on port 8081..."
    print_info "Press Ctrl+C to stop"
    echo ""
    
    export DB_HOST=localhost
    python3 -m uvicorn app.main:app --reload --port 8081
}

# Option 4: Test service
test_service() {
    print_header "TESTING SERVICE"
    
    if ! command_exists python3; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check if requests is installed
    if ! python3 -c "import requests" 2>/dev/null; then
        print_info "Installing requests library..."
        pip install requests
    fi
    
    print_info "Running tests..."
    echo ""
    
    python3 test_service.py
    
    echo ""
    read -p "Press Enter to continue..."
}

# Option 5: View logs
view_logs() {
    print_header "VIEWING LOGS"
    
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    print_info "Showing logs (Ctrl+C to stop)..."
    echo ""
    
    docker-compose logs -f product-service
}

# Option 6: Stop services
stop_services() {
    print_header "STOPPING SERVICES"
    
    # Stop Docker Compose
    if [ -f "docker-compose.yml" ]; then
        print_info "Stopping Docker Compose services..."
        docker-compose down
        print_success "Docker Compose services stopped"
    fi
    
    # Stop standalone PostgreSQL
    if docker ps --format '{{.Names}}' | grep -q '^postgres-local$'; then
        print_info "Stopping PostgreSQL container..."
        docker stop postgres-local
        print_success "PostgreSQL stopped"
    fi
    
    echo ""
    print_success "All services stopped"
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    
    case $choice in
        1)
            run_standalone
            break
            ;;
        2)
            run_docker_compose
            read -p "Press Enter to continue..."
            ;;
        3)
            run_with_postgres
            break
            ;;
        4)
            test_service
            ;;
        5)
            view_logs
            ;;
        6)
            stop_services
            ;;
        0)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            sleep 2
            ;;
    esac
done