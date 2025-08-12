#!/bin/bash

# Hot Fix Script for Running Dify Containers
# This script applies patches directly to running containers and commits them
# Perfect for quick development iterations!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COMPOSE_FILE="docker-compose.local-images.yml"
LOCAL_REGISTRY="dify-local"

print_step() {
    echo -e "${BLUE}🔥 $1${NC}"
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

show_usage() {
    echo "Usage: $0 [OPTIONS] [SERVICE...]"
    echo ""
    echo "Apply hot fixes to running Dify containers"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -f, --file FILE         Docker compose file (default: docker-compose.local-images.yml)"
    echo "  --commit                Commit changes to new image after applying fixes"
    echo "  --restart               Restart services after applying fixes"
    echo ""
    echo "Services (fix all if none specified):"
    echo "  api                     Hot fix API service"
    echo "  worker                  Hot fix Worker service"
    echo ""
    echo "Examples:"
    echo "  $0                      # Hot fix API and Worker services"
    echo "  $0 api                  # Hot fix only API service"
    echo "  $0 --commit --restart   # Fix, commit and restart services"
}

# Parse arguments
SERVICES=()
COMMIT_CHANGES=false
RESTART_SERVICES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        --commit)
            COMMIT_CHANGES=true
            shift
            ;;
        --restart)
            RESTART_SERVICES=true
            shift
            ;;
        api|worker)
            SERVICES+=("$1")
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default to API and Worker if none specified
if [ ${#SERVICES[@]} -eq 0 ]; then
    SERVICES=("api" "worker")
fi

print_step "Hot Fix for Running Dify Containers"
echo "Compose File: ${COMPOSE_FILE}"
echo "Services: ${SERVICES[*]}"
echo "Commit Changes: ${COMMIT_CHANGES}"
echo "Restart Services: ${RESTART_SERVICES}"
echo ""

# Check prerequisites
check_prerequisites() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Compose file not found: $COMPOSE_FILE"
        exit 1
    fi
    
    if [ ! -d "dify/api" ]; then
        print_error "dify/api directory not found. Please run from project root."
        exit 1
    fi
}

# Apply SSO patches to source if not already done
ensure_patches_applied() {
    print_step "Ensuring SSO patches are applied to source code..."
    
    if ! grep -q "KEYCLOAK_CLIENT_ID" dify/api/configs/feature/__init__.py; then
        print_step "Applying SSO patches..."
        ./scripts/apply-sso-integration.sh
        print_success "SSO patches applied"
    else
        print_success "SSO patches already applied"
    fi
}

# Hot fix a specific service
hotfix_service() {
    local service=$1
    print_step "Applying hot fix to $service service..."
    
    # Check if container is running
    if ! docker-compose -f $COMPOSE_FILE ps | grep -q "$service.*Up"; then
        print_warning "$service service is not running. Starting it first..."
        docker-compose -f $COMPOSE_FILE up -d $service
        sleep 5
    fi
    
    local container_name=$(docker-compose -f $COMPOSE_FILE ps -q $service)
    if [ -z "$container_name" ]; then
        print_error "Could not find container for $service service"
        return 1
    fi
    
    print_step "Copying patched files to $service container..."
    
    # Copy patched files based on service type
    if [ "$service" = "api" ] || [ "$service" = "worker" ]; then
        # API/Worker service patches
        docker cp dify/api/configs/feature/__init__.py $container_name:/app/api/configs/feature/__init__.py
        docker cp dify/api/libs/oauth.py $container_name:/app/api/libs/oauth.py
        docker cp dify/api/controllers/console/auth/oauth.py $container_name:/app/api/controllers/console/auth/oauth.py
        
        print_success "Patched files copied to $service container"
        
        # Restart the application process inside container (if needed)
        print_step "Sending reload signal to $service..."
        docker-compose -f $COMPOSE_FILE exec -T $service pkill -HUP -f "flask\|celery" 2>/dev/null || true
    fi
    
    # Commit changes if requested
    if [ "$COMMIT_CHANGES" = true ]; then
        print_step "Committing changes to new image..."
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local new_image="${LOCAL_REGISTRY}/dify-${service}:hotfix_${timestamp}"
        local latest_image="${LOCAL_REGISTRY}/dify-${service}:latest"
        
        docker commit $container_name $new_image
        docker tag $new_image $latest_image
        
        print_success "Changes committed to: $new_image"
        print_info "Also tagged as: $latest_image"
    fi
}

# Restart services if requested
restart_services() {
    if [ "$RESTART_SERVICES" = true ]; then
        print_step "Restarting services..."
        for service in "${SERVICES[@]}"; do
            docker-compose -f $COMPOSE_FILE restart $service
            print_success "$service service restarted"
        done
    fi
}

# Verify hot fix
verify_hotfix() {
    print_step "Verifying hot fixes..."
    
    for service in "${SERVICES[@]}"; do
        if [ "$service" = "api" ] || [ "$service" = "worker" ]; then
            local container_name=$(docker-compose -f $COMPOSE_FILE ps -q $service)
            
            if docker exec $container_name grep -q "KEYCLOAK_CLIENT_ID" /app/api/configs/feature/__init__.py 2>/dev/null; then
                print_success "$service hot fix verification passed"
            else
                print_warning "$service hot fix verification failed"
            fi
        fi
    done
}

# Show hot fix status
show_status() {
    echo ""
    print_success "🔥 Hot Fix Applied Successfully!"
    echo ""
    
    print_step "📋 Service Status:"
    docker-compose -f $COMPOSE_FILE ps
    
    echo ""
    print_step "🔍 Recent Container Logs:"
    for service in "${SERVICES[@]}"; do
        echo "--- $service logs (last 10 lines) ---"
        docker-compose -f $COMPOSE_FILE logs --tail=10 $service || true
        echo ""
    done
    
    if [ "$COMMIT_CHANGES" = true ]; then
        echo ""
        print_step "📦 Committed Images:"
        docker images ${LOCAL_REGISTRY}/dify-* --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | head -10
    fi
    
    echo ""
    print_step "💡 Tips:"
    echo "  • Changes are applied directly to running containers"
    echo "  • Use --commit to save changes as new images"
    echo "  • Use --restart to restart services after changes"
    echo "  • Monitor logs: docker-compose -f $COMPOSE_FILE logs -f $service"
}

# Main execution
main() {
    check_prerequisites
    ensure_patches_applied
    
    for service in "${SERVICES[@]}"; do
        hotfix_service $service
    done
    
    restart_services
    verify_hotfix
    show_status
}

# Handle interruption
trap 'print_error "Hot fix interrupted"; exit 1' INT TERM

# Run main function
main

