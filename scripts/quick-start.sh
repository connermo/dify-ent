#!/bin/bash

# Quick Start Script for Dify Local Development
# This script sets up the complete Dify development environment with SSO patches

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}🚀 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Quick start script for Dify local development with SSO"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  --skip-build            Skip building local images (use existing ones)"
    echo "  --skip-keycloak         Skip starting Keycloak"
    echo "  --parallel              Build images in parallel"
    echo "  --cleanup               Stop and cleanup existing containers first"
    echo ""
    echo "Examples:"
    echo "  $0                      # Full setup (build images + start services)"
    echo "  $0 --skip-build         # Use existing images, just start services"
    echo "  $0 --cleanup            # Cleanup first, then full setup"
}

# Parse command line arguments
SKIP_BUILD=false
SKIP_KEYCLOAK=false
PARALLEL_BUILD=false
CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-keycloak)
            SKIP_KEYCLOAK=true
            shift
            ;;
        --parallel)
            PARALLEL_BUILD=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main script starts here
echo "🌟 Dify Local Development Quick Start"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -d "dify/api" ] || [ ! -d "dify/web" ]; then
    print_error "dify/api or dify/web directory not found. Please run this script from the project root."
    exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to cleanup existing containers
cleanup_containers() {
    print_step "Cleaning up existing containers..."
    
    # Stop local images services
    docker-compose -f docker-compose.local-images.yml down 2>/dev/null || true
    
    # Stop Keycloak
    if [ -d "keycloak" ]; then
        cd keycloak
        docker-compose down 2>/dev/null || true
        cd ..
    fi
    
    print_success "Cleanup completed"
}

# Function to build local images
build_local_images() {
    print_step "Building local Docker images with SSO patches..."
    
    local build_args=""
    if [ "$PARALLEL_BUILD" = true ]; then
        build_args="--parallel"
    fi
    
    if ! ./scripts/build-local-images.sh $build_args; then
        print_error "Failed to build local images"
        exit 1
    fi
    
    print_success "Local images built successfully"
}

# Function to start Keycloak
start_keycloak() {
    print_step "Starting Keycloak SSO server..."
    
    if [ ! -d "keycloak" ]; then
        print_error "Keycloak directory not found"
        exit 1
    fi
    
    cd keycloak
    docker-compose up -d
    cd ..
    
    # Wait for Keycloak to be ready
    print_info "Waiting for Keycloak to start..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f http://localhost:8280/realms/dify/.well-known/openid-configuration > /dev/null 2>&1; then
            print_success "Keycloak is ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Keycloak failed to start within expected time"
            exit 1
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
}

# Function to setup environment
setup_environment() {
    print_step "Setting up environment configuration..."
    
    if [ ! -f ".env.local" ]; then
        if [ -f "env.local.example" ]; then
            cp env.local.example .env.local
            print_success "Created .env.local from template"
        else
            print_warning ".env.local template not found, creating basic configuration"
            cat > .env.local << 'EOF'
# Basic configuration for local development
POSTGRES_PASSWORD=difyai123456
REDIS_PASSWORD=difyai123456
SECRET_KEY=your-secret-key-here-change-in-production
DEBUG=true
FLASK_DEBUG=true
ENABLE_SOCIAL_OAUTH_LOGIN=true
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
CONSOLE_WEB_URL=http://localhost:3000
CONSOLE_API_URL=http://localhost:5001
SERVICE_API_URL=http://localhost:5001
APP_WEB_URL=http://localhost:3000
EOF
        fi
    else
        print_info ".env.local already exists, skipping creation"
    fi
}

# Function to start Dify services
start_dify_services() {
    print_step "Starting Dify services with local images..."
    
    # Create volumes directory if it doesn't exist
    mkdir -p volumes/{db/data,redis/data,weaviate,app/storage}
    
    # Start services
    docker-compose -f docker-compose.local-images.yml up -d
    
    print_success "Dify services started"
}

# Function to wait for services
wait_for_services() {
    print_step "Waiting for services to be ready..."
    
    local services=("db:5432" "redis:6379" "api:5001" "web:3000")
    
    for service_port in "${services[@]}"; do
        local service=${service_port%:*}
        local port=${service_port#*:}
        
        print_info "Waiting for $service on port $port..."
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if docker-compose -f docker-compose.local-images.yml exec -T $service echo "ready" > /dev/null 2>&1; then
                print_success "$service is ready"
                break
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                print_warning "$service may not be fully ready yet"
                break
            fi
            
            echo -n "."
            sleep 2
            ((attempt++))
        done
    done
}

# Function to show status and next steps
show_status() {
    echo ""
    print_success "🎉 Dify Local Development Environment is Ready!"
    echo ""
    
    print_step "📋 Service Status:"
    docker-compose -f docker-compose.local-images.yml ps
    
    echo ""
    print_step "🌐 Access URLs:"
    echo "  • Dify Web Interface:   http://localhost:3000"
    echo "  • Dify API:             http://localhost:5001"
    echo "  • Keycloak Admin:       http://localhost:8280/admin"
    echo "  • Keycloak Realm:       http://localhost:8280/realms/dify"
    
    echo ""
    print_step "🔐 Default Credentials:"
    echo "  • Keycloak Admin:       admin / admin"
    echo "  • Test User:            alice / alice1234"
    
    echo ""
    print_step "📚 Useful Commands:"
    echo "  • View logs:            docker-compose -f docker-compose.local-images.yml logs -f"
    echo "  • Stop services:        docker-compose -f docker-compose.local-images.yml down"
    echo "  • Restart service:      docker-compose -f docker-compose.local-images.yml restart <service>"
    echo "  • Rebuild images:       ./scripts/build-local-images.sh"
    
    echo ""
    print_info "💡 To get started, visit http://localhost:3000 and set up your first application!"
}

# Main execution flow
main() {
    check_prerequisites
    
    if [ "$CLEANUP" = true ]; then
        cleanup_containers
    fi
    
    setup_environment
    
    if [ "$SKIP_KEYCLOAK" = false ]; then
        start_keycloak
    fi
    
    if [ "$SKIP_BUILD" = false ]; then
        build_local_images
    fi
    
    start_dify_services
    wait_for_services
    show_status
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main

