#!/bin/bash

# Build Local Dify Images with SSO Patches
# This script builds local Docker images with Keycloak SSO integration patches applied

set -e

# Configuration
REGISTRY_PREFIX="langgenius"  # 使用官方镜像的 registry
VERSION="latest"
BUILD_PLATFORMS="linux/amd64"  # Change to "linux/amd64,linux/arm64" for multi-arch
PARALLEL_BUILD=false
CURRENT_RELEASE_VERSION="1.7.2"  # 当前docker-compose中使用的版本

# Cache configuration
ENABLE_SMART_CACHE=true
CACHE_STRATEGY="auto"  # auto, aggressive, conservative

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}📦 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker buildx version &> /dev/null; then
        print_error "Docker Buildx is not available"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to setup smart caching
setup_smart_cache() {
    if [ "$ENABLE_SMART_CACHE" = false ]; then
        return
    fi
    
    print_step "Setting up smart caching strategy..."
    
    case $CACHE_STRATEGY in
        "aggressive")
            # 使用官方镜像作为缓存源
            if [ -z "$CACHE_FROM" ]; then
                CACHE_FROM="langgenius/dify-api:latest,langgenius/dify-web:latest"
                print_info "Aggressive cache: Using official images as cache source"
            fi
            # 导出缓存到本地
            if [ -z "$CACHE_TO" ]; then
                CACHE_TO="type=local,dest=./.docker-cache"
                print_info "Aggressive cache: Exporting cache to local directory"
            fi
            ;;
        "conservative")
            # 只使用本地缓存
            if [ -z "$CACHE_FROM" ]; then
                CACHE_FROM="type=local,src=./.docker-cache"
                print_info "Conservative cache: Using local cache only"
            fi
            ;;
        "auto"|*)
            # 自动策略：优先使用官方镜像，然后本地缓存
            if [ -z "$CACHE_FROM" ]; then
                CACHE_FROM="langgenius/dify-api:latest,langgenius/dify-web:latest"
                print_info "Auto cache: Using official images as primary cache source"
            fi
            if [ -z "$CACHE_TO" ]; then
                CACHE_TO="type=local,dest=./.docker-cache"
                print_info "Auto cache: Exporting cache to local directory"
            fi
            ;;
    esac
    
    # 创建缓存目录
    if [[ "$CACHE_TO" == *"type=local"* ]]; then
        local cache_dir=$(echo "$CACHE_TO" | grep -o 'dest=[^,]*' | cut -d'=' -f2)
        if [ -n "$cache_dir" ]; then
            mkdir -p "$cache_dir"
            print_info "Cache directory created: $cache_dir"
        fi
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [COMPONENT...]"
    echo ""
    echo "Build local Dify Docker images with SSO patches"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version VERSION   Set image version (default: latest)"
    echo "  -r, --registry PREFIX   Set registry prefix (default: langgenius)"
    echo "  -p, --platforms PLATFORMS Set build platforms (default: linux/amd64)"
    echo "  --parallel              Build components in parallel"
    echo "  --force-patch           Force re-apply SSO patches"
    echo "  --no-cache              Build without Docker cache"
    echo "  --yes                   Skip confirmation prompt for overwriting official images (default: true)"
echo "  --confirm               Enable confirmation prompt for overwriting official images"
    echo "  --cache-from IMAGE      Use image as cache source"
    echo "  --cache-to TYPE         Export cache to TYPE (inline, local, registry)"
    echo ""
    echo "Components (build all if none specified):"
    echo "  api                     Build API service image"
    echo "  web                     Build Web service image"
    echo "  worker                  Build Worker service image"
    echo ""
    echo "Examples:"
    echo "  $0                      # Build all components"
    echo "  $0 api web              # Build only API and Web"
    echo "  $0 -v v1.0.0 api        # Build API with specific version"
    echo "  $0 --parallel           # Build all components in parallel"
}

# Parse command line arguments
COMPONENTS=()
FORCE_PATCH=false
NO_CACHE=false
SKIP_CONFIRM=true  # 默认跳过确认提示
CACHE_FROM=""
CACHE_TO=""

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
            REGISTRY_PREFIX="$2"
            shift 2
            ;;
        -p|--platforms)
            BUILD_PLATFORMS="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL_BUILD=true
            shift
            ;;
        --force-patch)
            FORCE_PATCH=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        --confirm)
            SKIP_CONFIRM=false
            shift
            ;;
        --cache-from)
            CACHE_FROM="$2"
            shift 2
            ;;
        --cache-to)
            CACHE_TO="$2"
            shift 2
            ;;
        api|web|worker)
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
    COMPONENTS=("api" "web" "worker")
fi

# Main script starts here
print_step "Starting Dify Local Image Build"
echo "Registry: ${REGISTRY_PREFIX}"
echo "Version: ${VERSION}"
echo "Platforms: ${BUILD_PLATFORMS}"
echo "Components: ${COMPONENTS[*]}"
echo "Parallel Build: ${PARALLEL_BUILD}"
echo ""

# 安全提示：如果构建最新版本，会覆盖官方镜像
if [ "$VERSION" = "latest" ] && [ "$SKIP_CONFIRM" = false ]; then
    print_warning "⚠️  重要提示：构建最新版本将覆盖官方镜像标签！"
    echo "   这将影响所有使用 langgenius/dify-*:latest 的容器"
    echo ""
    read -p "确认继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "构建已取消"
        exit 1
    fi
    print_success "确认继续构建..."
    echo ""
elif [ "$VERSION" = "latest" ] && [ "$SKIP_CONFIRM" = true ]; then
    print_warning "⚠️  跳过确认提示，将直接覆盖官方镜像标签"
    echo ""
fi

# Check if we're in the right directory
if [ ! -d "dify/api" ] || [ ! -d "dify/web" ]; then
    print_error "dify/api or dify/web directory not found. Please run this script from the project root."
    exit 1
fi

check_prerequisites

# Setup smart caching
setup_smart_cache

# Apply SSO patches if needed
if [ "$FORCE_PATCH" = true ] || ! grep -q "KEYCLOAK_CLIENT_ID" dify/api/configs/feature/__init__.py; then
    print_step "Applying SSO integration patches..."
    ./scripts/apply-sso-integration.sh
    print_success "SSO patches applied"
else
    print_warning "SSO patches already applied (use --force-patch to re-apply)"
fi

# Set up Docker Buildx
print_step "Setting up Docker Buildx..."
docker buildx create --name dify-builder --use --driver docker-container --platform $BUILD_PLATFORMS 2>/dev/null || \
docker buildx use dify-builder
print_success "Docker Buildx ready"

# Function to build a single component
build_component() {
    local component=$1
    local context_dir
    local dockerfile_path
    local service_type=""
    
    case $component in
        api)
            context_dir="dify/api"
            dockerfile_path="dify/api/Dockerfile"
            ;;
        web)
            context_dir="dify/web"
            dockerfile_path="dify/web/Dockerfile"
            ;;
        worker)
            context_dir="dify/api"
            dockerfile_path="dify/api/Dockerfile"
            service_type="worker"
            ;;
        *)
            print_error "Unknown component: $component"
            return 1
            ;;
    esac
    
    local image_name="${REGISTRY_PREFIX}/dify-${component}:${VERSION}"
    local latest_name="${REGISTRY_PREFIX}/dify-${component}:latest"
    local release_name="${REGISTRY_PREFIX}/dify-${component}:${CURRENT_RELEASE_VERSION}"
    
    # 如果构建的是最新版本，同时覆盖官方镜像的 latest 和 release 标签
    if [ "$VERSION" = "latest" ]; then
        local official_latest="langgenius/dify-${component}:latest"
        local official_release="langgenius/dify-${component}:${CURRENT_RELEASE_VERSION}"
        print_warning "⚠️  这将覆盖官方镜像: $official_latest 和 $official_release"
    fi
    
    print_step "Building $component image: $image_name"
    
    # Build arguments
    local build_args=""
    if [ "$NO_CACHE" = true ]; then
        build_args="--no-cache"
    fi
    
    # Cache optimization - following official Dify approach
    if [ -n "$CACHE_FROM" ]; then
        # Handle comma-separated cache sources
        for cache in $(echo $CACHE_FROM | tr ',' ' '); do
            # Skip non-existent images to avoid errors
            if [[ "$cache" == *"dify-worker"* ]]; then
                print_warning "Skipping non-existent cache source: $cache"
                continue
            fi
            build_args="$build_args --cache-from type=registry,ref=$cache"
        done
        print_info "Using registry cache from: $CACHE_FROM"
    fi
    
    # Always use local cache for performance
    build_args="$build_args --cache-from type=local,src=./.docker-cache"
    
    if [ -n "$CACHE_TO" ]; then
        build_args="$build_args --cache-to $CACHE_TO"
        print_info "Exporting cache to: $CACHE_TO"
    fi
    
    if [ -n "$service_type" ]; then
        build_args="$build_args --build-arg SERVICE_TYPE=$service_type"
    fi
    
    # Build the image - following official Dify approach
    docker buildx build \
        --platform $BUILD_PLATFORMS \
        --load \
        -t "$image_name" \
        -t "$latest_name" \
        -t "$release_name" \
        --provenance=false \
        $build_args \
        -f "$dockerfile_path" \
        "$context_dir"
    
    # 如果构建的是最新版本，强制覆盖官方镜像的 latest 和 release 标签
    if [ "$VERSION" = "latest" ]; then
        print_step "强制覆盖官方镜像标签..."
        docker tag "$latest_name" "langgenius/dify-${component}:latest"
        docker tag "$release_name" "langgenius/dify-${component}:${CURRENT_RELEASE_VERSION}"
        print_success "已覆盖官方镜像: langgenius/dify-${component}:latest"
        print_success "已覆盖官方镜像: langgenius/dify-${component}:${CURRENT_RELEASE_VERSION}"
    fi
    
    print_success "Built $component image: $image_name"
}

# Build components
if [ "$PARALLEL_BUILD" = true ] && [ ${#COMPONENTS[@]} -gt 1 ]; then
    print_step "Building components in parallel..."
    
    # Start builds in background
    pids=()
    for component in "${COMPONENTS[@]}"; do
        build_component "$component" &
        pids+=($!)
    done
    
    # Wait for all builds to complete
    for pid in "${pids[@]}"; do
        wait $pid
        if [ $? -ne 0 ]; then
            print_error "One or more builds failed"
            exit 1
        fi
    done
else
    # Sequential build
    for component in "${COMPONENTS[@]}"; do
        build_component "$component"
    done
fi

# Clean up builder if it was created
docker buildx rm dify-builder 2>/dev/null || true

print_success "All components built successfully!"
echo ""
print_step "Built images:"
for component in "${COMPONENTS[@]}"; do
    echo "  📦 ${REGISTRY_PREFIX}/dify-${component}:${VERSION}"
    echo "  📦 ${REGISTRY_PREFIX}/dify-${component}:latest"
    echo "  📦 ${REGISTRY_PREFIX}/dify-${component}:${CURRENT_RELEASE_VERSION}"
    if [ "$VERSION" = "latest" ]; then
        echo "  ⚠️  已覆盖官方镜像: langgenius/dify-${component}:latest"
        echo "  ⚠️  已覆盖官方镜像: langgenius/dify-${component}:${CURRENT_RELEASE_VERSION}"
    fi
done

echo ""
print_step "Next steps:"
if [ "$VERSION" = "latest" ]; then
    echo "1. 🎯 镜像已覆盖官方镜像，可以直接使用官方镜像名称:"
    echo "   image: langgenius/dify-api:latest (或 :${CURRENT_RELEASE_VERSION})"
    echo "   image: langgenius/dify-web:latest (或 :${CURRENT_RELEASE_VERSION})"
    echo "   image: langgenius/dify-worker:latest (或 :${CURRENT_RELEASE_VERSION})"
else
    echo "1. 📝 Update your docker-compose.yml to use these images:"
    echo "   image: ${REGISTRY_PREFIX}/dify-api:${VERSION}"
    echo "   image: ${REGISTRY_PREFIX}/dify-web:${VERSION}"
    echo "   image: ${REGISTRY_PREFIX}/dify-worker:${VERSION}"
fi
echo ""
echo "2. 🚀 Start your services:"
echo "   docker-compose -f docker-compose.local.yml up -d"
echo ""
echo "3. 🔧 For Keycloak SSO, ensure you have:"
echo "   cd keycloak && docker-compose up -d"
echo ""
print_success "Build completed! 🎉"

