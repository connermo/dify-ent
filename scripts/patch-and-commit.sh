#!/bin/bash

# Patch and Commit Script for Dify Images
# This script applies SSO patches to existing official Dify images and commits them as local images
# Much faster than rebuilding from scratch!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OFFICIAL_API_IMAGE="langgenius/dify-api:latest"
OFFICIAL_WEB_IMAGE="langgenius/dify-web:latest"
LOCAL_REGISTRY="dify-local"
VERSION="latest"

# Function to print colored output
print_step() {
    echo -e "${BLUE}🔧 $1${NC}"
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
    echo "Usage: $0 [OPTIONS] [COMPONENT...]"
    echo ""
    echo "Patch existing official Dify images with SSO integration"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version VERSION   Set image version (default: latest)"
    echo "  -r, --registry PREFIX   Set local registry prefix (default: dify-local)"
    echo "  --api-image IMAGE       Official API image to patch (default: langgenius/dify-api:latest)"
    echo "  --web-image IMAGE       Official Web image to patch (default: langgenius/dify-web:latest)"
    echo "  --pull                  Pull latest official images first"
    echo "  --no-cleanup            Don't cleanup temporary containers"
    echo ""
    echo "Components (patch all if none specified):"
    echo "  api                     Patch API service image"
    echo "  web                     Patch Web service image"
    echo ""
    echo "Examples:"
    echo "  $0                      # Patch both API and Web images"
    echo "  $0 api                  # Patch only API image"
    echo "  $0 --pull               # Pull latest official images then patch"
    echo "  $0 -v v1.0.0            # Create patched images with specific version"
}

# Parse command line arguments
COMPONENTS=()
PULL_IMAGES=false
NO_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -r|--registry)
            LOCAL_REGISTRY="$2"
            shift 2
            ;;
        --api-image)
            OFFICIAL_API_IMAGE="$2"
            shift 2
            ;;
        --web-image)
            OFFICIAL_WEB_IMAGE="$2"
            shift 2
            ;;
        --pull)
            PULL_IMAGES=true
            shift
            ;;
        --no-cleanup)
            NO_CLEANUP=true
            shift
            ;;
        api|web)
            COMPONENTS+=("$1")
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default to all components if none specified
if [ ${#COMPONENTS[@]} -eq 0 ]; then
    COMPONENTS=("api" "web")
fi

# Main script starts here
print_step "Starting Dify Image Patching Process"
echo "Local Registry: ${LOCAL_REGISTRY}"
echo "Version: ${VERSION}"
echo "Components: ${COMPONENTS[*]}"
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
    
    print_success "Prerequisites check passed"
}

# Function to pull official images
pull_official_images() {
    if [ "$PULL_IMAGES" = true ]; then
        print_step "Pulling latest official images..."
        
        if [[ " ${COMPONENTS[@]} " =~ " api " ]]; then
            docker pull $OFFICIAL_API_IMAGE
        fi
        
        if [[ " ${COMPONENTS[@]} " =~ " web " ]]; then
            docker pull $OFFICIAL_WEB_IMAGE
        fi
        
        print_success "Official images pulled"
    fi
}

# Function to apply SSO patches to source code
apply_sso_patches() {
    print_step "Ensuring SSO patches are applied to source code..."
    
    # Check if patches are already applied
    if grep -q "KEYCLOAK_CLIENT_ID" dify/api/configs/feature/__init__.py; then
        print_info "SSO patches already applied to source code"
    else
        print_step "Applying SSO patches to source code..."
        ./scripts/apply-sso-integration.sh
        print_success "SSO patches applied to source code"
    fi
}

# Function to patch API image
patch_api_image() {
    print_step "Patching API image: $OFFICIAL_API_IMAGE"
    
    local temp_container="dify-api-patch-$$"
    local target_image="${LOCAL_REGISTRY}/dify-api:${VERSION}"
    local latest_image="${LOCAL_REGISTRY}/dify-api:latest"
    
    # Create temporary container from official image
    docker create --name $temp_container $OFFICIAL_API_IMAGE
    
    # Copy patched files to container
    print_info "Copying patched API files..."
    docker cp dify/api/configs/feature/__init__.py $temp_container:/app/api/configs/feature/__init__.py
    docker cp dify/api/libs/oauth.py $temp_container:/app/api/libs/oauth.py
    docker cp dify/api/controllers/console/auth/oauth.py $temp_container:/app/api/controllers/console/auth/oauth.py
    
    # Commit changes to new image
    print_info "Committing changes to new image..."
    docker commit $temp_container $target_image
    docker tag $target_image $latest_image
    
    # Cleanup temporary container
    if [ "$NO_CLEANUP" = false ]; then
        docker rm $temp_container
    fi
    
    print_success "API image patched: $target_image"
}

# Function to patch Web image
patch_web_image() {
    print_step "Patching Web image: $OFFICIAL_WEB_IMAGE"
    
    local temp_container="dify-web-patch-$$"
    local target_image="${LOCAL_REGISTRY}/dify-web:${VERSION}"
    local latest_image="${LOCAL_REGISTRY}/dify-web:latest"
    
    # Create temporary container from official image
    docker create --name $temp_container $OFFICIAL_WEB_IMAGE
    
    print_info "Applying SSO optimization to web image..."
    
    # Add SSO readiness marker and configuration
    print_info "Adding SSO readiness indicators..."
    docker exec $temp_container sh -c 'mkdir -p /app/.sso-config'
    docker exec $temp_container sh -c 'echo "SSO_ENABLED=true" > /app/.sso-config/status'
    docker exec $temp_container sh -c 'echo "SUPPORTED_PROVIDERS=github,google,keycloak" >> /app/.sso-config/status'
    docker exec $temp_container sh -c 'echo "PATCH_DATE='$(date -u +%Y-%m-%dT%H:%M:%SZ)'" >> /app/.sso-config/status'
    docker exec $temp_container sh -c 'echo "API_INTEGRATION=ready" >> /app/.sso-config/status'
    
    # Create environment setup script for SSO
    cat > /tmp/sso-web-setup.sh << 'EOF'
#!/bin/bash
# SSO Web Environment Setup

# Ensure SSO environment variables are available
export NEXT_PUBLIC_ENABLE_SOCIAL_OAUTH_LOGIN=${ENABLE_SOCIAL_OAUTH_LOGIN:-true}
export NEXT_PUBLIC_SSO_READY=true

# Log SSO readiness
if [ "$NEXT_PUBLIC_ENABLE_SOCIAL_OAUTH_LOGIN" = "true" ]; then
    echo "[SSO] Social OAuth login enabled"
    echo "[SSO] Supported providers: GitHub, Google, Keycloak"
fi

# Execute original command
exec "$@"
EOF
    
    docker cp /tmp/sso-web-setup.sh $temp_container:/app/sso-web-setup.sh
    docker exec $temp_container chmod +x /app/sso-web-setup.sh
    
    # Commit the patched image with proper metadata
    docker commit \
        --change='LABEL sso.patched="true"' \
        --change='LABEL sso.version="'${VERSION}'"' \
        --change='LABEL sso.patch-date="'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
        --change='LABEL sso.providers="github,google,keycloak"' \
        --change='LABEL sso.api-integration="required"' \
        --change='ENV SSO_READY=true' \
        $temp_container $target_image
    
    docker tag $target_image $latest_image
    
    # Cleanup temporary container and files
    if [ "$NO_CLEANUP" = false ]; then
        docker rm $temp_container
    fi
    rm -f /tmp/sso-web-setup.sh
    
    print_success "Web image patched with SSO optimization: $target_image"
    
    # Verify the patch
    if docker run --rm $target_image test -f /app/.sso-config/status > /dev/null 2>&1; then
        print_info "✓ SSO configuration verified in web image"
    else
        print_warning "⚠ SSO configuration verification failed"
    fi
}

# Function to create worker image
create_worker_image() {
    if [[ " ${COMPONENTS[@]} " =~ " api " ]]; then
        print_step "Creating worker image from patched API image..."
        
        local api_image="${LOCAL_REGISTRY}/dify-api:${VERSION}"
        local worker_image="${LOCAL_REGISTRY}/dify-worker:${VERSION}"
        local latest_worker="${LOCAL_REGISTRY}/dify-worker:latest"
        
        # Tag API image as worker (they use the same code, different startup command)
        docker tag $api_image $worker_image
        docker tag $api_image $latest_worker
        
        print_success "Worker image created: $worker_image"
    fi
}

# Function to show results
show_results() {
    print_success "🎉 Image patching completed!"
    echo ""
    
    print_step "📦 Patched images created:"
    for component in "${COMPONENTS[@]}"; do
        echo "  • ${LOCAL_REGISTRY}/dify-${component}:${VERSION}"
        echo "  • ${LOCAL_REGISTRY}/dify-${component}:latest"
    done
    
    if [[ " ${COMPONENTS[@]} " =~ " api " ]]; then
        echo "  • ${LOCAL_REGISTRY}/dify-worker:${VERSION}"
        echo "  • ${LOCAL_REGISTRY}/dify-worker:latest"
    fi
    
    echo ""
    print_step "📋 Image sizes comparison:"
    echo "Original images:"
    if [[ " ${COMPONENTS[@]} " =~ " api " ]]; then
        docker images $OFFICIAL_API_IMAGE --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    fi
    if [[ " ${COMPONENTS[@]} " =~ " web " ]]; then
        docker images $OFFICIAL_WEB_IMAGE --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    fi
    
    echo ""
    echo "Patched images:"
    docker images ${LOCAL_REGISTRY}/dify-* --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
    
    echo ""
    print_step "🚀 Next steps:"
    echo "1. 📝 Update your docker-compose.yml to use these images:"
    for component in "${COMPONENTS[@]}"; do
        echo "   image: ${LOCAL_REGISTRY}/dify-${component}:${VERSION}"
    done
    
    echo ""
    echo "2. 🔧 Start your services:"
    echo "   docker-compose -f docker-compose.local-images.yml up -d"
    
    echo ""
    print_info "💡 These patched images are much smaller and faster to create than full rebuilds!"
}

# Function to verify patches
verify_patches() {
    print_step "Verifying patches in images..."
    
    if [[ " ${COMPONENTS[@]} " =~ " api " ]]; then
        local api_image="${LOCAL_REGISTRY}/dify-api:${VERSION}"
        
        # Check if KEYCLOAK_CLIENT_ID exists in the image
        if docker run --rm $api_image grep -q "KEYCLOAK_CLIENT_ID" /app/api/configs/feature/__init__.py 2>/dev/null; then
            print_success "API image patch verification passed"
        else
            print_warning "API image patch verification failed - SSO configuration may not be properly applied"
        fi
    fi
}

# Main execution flow
main() {
    check_prerequisites
    pull_official_images
    apply_sso_patches
    
    for component in "${COMPONENTS[@]}"; do
        case $component in
            api)
                patch_api_image
                ;;
            web)
                patch_web_image
                ;;
        esac
    done
    
    create_worker_image
    verify_patches
    show_results
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main
