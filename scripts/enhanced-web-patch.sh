#!/bin/bash

# Enhanced Web Image Patching
# This demonstrates a more comprehensive approach to patching the web image

set -e

# Enhanced Web image patching function
patch_web_image_enhanced() {
    print_step "Enhanced patching of Web image: $OFFICIAL_WEB_IMAGE"
    
    local temp_container="dify-web-patch-$$"
    local target_image="${LOCAL_REGISTRY}/dify-web:${VERSION}"
    local latest_image="${LOCAL_REGISTRY}/dify-web:latest"
    
    # Create temporary container from official image
    docker create --name $temp_container $OFFICIAL_WEB_IMAGE
    
    print_info "Applying enhanced configurations for SSO support..."
    
    # 1. Check if we need to add any custom configuration files
    if [ -f "web-sso-config.json" ]; then
        print_info "Copying custom SSO configuration..."
        docker cp web-sso-config.json $temp_container:/app/web-sso-config.json
    fi
    
    # 2. Add environment variables for better SSO integration
    print_info "Setting up SSO-optimized environment..."
    
    # Create a startup script that sets SSO-specific environment variables
    cat > /tmp/sso-env-setup.sh << 'EOF'
#!/bin/bash

# SSO Environment Setup for Dify Web
export NEXT_PUBLIC_ENABLE_SOCIAL_OAUTH_LOGIN=${ENABLE_SOCIAL_OAUTH_LOGIN:-true}
export NEXT_PUBLIC_SSO_PROVIDERS="github,google,keycloak"
export NEXT_PUBLIC_KEYCLOAK_ENABLED=${ENABLE_SOCIAL_OAUTH_LOGIN:-true}

# Execute the original command
exec "$@"
EOF
    
    docker cp /tmp/sso-env-setup.sh $temp_container:/app/sso-env-setup.sh
    docker exec $temp_container chmod +x /app/sso-env-setup.sh
    
    # 3. Modify the startup to use our environment setup
    docker exec $temp_container sh -c 'echo "/app/sso-env-setup.sh" > /tmp/new-entrypoint.sh && cat /docker-entrypoint.sh >> /tmp/new-entrypoint.sh && mv /tmp/new-entrypoint.sh /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh'
    
    # 4. Add metadata to track the patch
    print_info "Adding patch metadata..."
    
    # Commit changes with metadata
    docker commit \
        --change='LABEL sso.patched="true"' \
        --change='LABEL sso.version="'${VERSION}'"' \
        --change='LABEL sso.patch-date="'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
        --change='LABEL sso.providers="github,google,keycloak"' \
        $temp_container $target_image
    
    docker tag $target_image $latest_image
    
    # Cleanup
    docker rm $temp_container
    rm -f /tmp/sso-env-setup.sh
    
    print_success "Enhanced Web image created: $target_image"
    
    # Verify the patch
    print_info "Verifying enhanced patch..."
    if docker run --rm $target_image ls -la /app/sso-env-setup.sh > /dev/null 2>&1; then
        print_success "SSO environment setup script installed"
    else
        print_warning "SSO environment setup script not found"
    fi
}

# Alternative: Minimal but meaningful patch
patch_web_image_minimal() {
    print_step "Minimal meaningful patching of Web image: $OFFICIAL_WEB_IMAGE"
    
    local temp_container="dify-web-patch-$$"
    local target_image="${LOCAL_REGISTRY}/dify-web:${VERSION}"
    local latest_image="${LOCAL_REGISTRY}/dify-web:latest"
    
    # Create temporary container from official image
    docker create --name $temp_container $OFFICIAL_WEB_IMAGE
    
    # Add a simple marker file to indicate SSO readiness
    print_info "Adding SSO readiness marker..."
    docker exec $temp_container sh -c 'echo "SSO_ENABLED=true" > /app/.sso-ready'
    docker exec $temp_container sh -c 'echo "SUPPORTED_PROVIDERS=github,google,keycloak" >> /app/.sso-ready'
    docker exec $temp_container sh -c 'echo "PATCH_DATE='$(date -u +%Y-%m-%dT%H:%M:%SZ)'" >> /app/.sso-ready'
    
    # Commit with metadata
    docker commit \
        --change='LABEL sso.ready="true"' \
        --change='LABEL sso.providers="github,google,keycloak"' \
        --change='ENV SSO_READY=true' \
        $temp_container $target_image
    
    docker tag $target_image $latest_image
    
    # Cleanup
    docker rm $temp_container
    
    print_success "Minimal Web patch applied: $target_image"
}

echo "Enhanced Web patching strategies:"
echo "1. patch_web_image_enhanced - Comprehensive SSO optimization"
echo "2. patch_web_image_minimal - Simple but meaningful patch"

