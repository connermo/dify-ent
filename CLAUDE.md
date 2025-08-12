# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Dify Enterprise SSO**, a complete solution that integrates the open-source Dify AI platform with Keycloak for Single Sign-On (SSO) authentication using OAuth2/OpenID Connect. The project automatically syncs with upstream Dify releases and applies enterprise authentication patches.

## Key Architecture

- **Base Platform**: Official Dify repository (langgenius/dify) with integrated SSO patches
- **Authentication**: Keycloak OAuth2/OIDC integration for enterprise SSO
- **Deployment**: Docker Compose setup using official Dify configuration
- **Development**: Direct integration into dify/ directory for easy upstream sync

## Common Development Commands

### Development Workflow
```bash
# Start Keycloak first for SSO setup
cd keycloak && docker compose up -d

# Start the complete Dify environment with SSO integration
cd dify && docker compose up -d

# Restart API service after code changes
cd dify && docker compose restart api

# View logs
cd dify && docker compose logs -f api
cd keycloak && docker compose logs -f keycloak
```

### Building and Testing
```bash
# Build and restart services
cd dify && docker compose build api && docker compose restart api

# Test Keycloak configuration
curl -f http://localhost:8280/realms/dify/.well-known/openid-configuration

# Test Dify API health
curl -f http://localhost:5001/health
```

### Database Management
```bash
# Database migrations
cd dify && docker compose exec api python -m flask db upgrade

# Access database
cd dify && docker compose exec db psql -U postgres -d dify
```

## Architecture & Structure

### Core Components
1. **dify/**: Official Dify repository with integrated SSO modifications
   - `api/libs/oauth.py`: OAuth providers including KeycloakOAuth class
   - `api/configs/feature/__init__.py`: Keycloak configuration fields
   - `api/controllers/console/auth/oauth.py`: OAuth endpoint handlers
   - `docker/docker-compose.yaml`: Complete service orchestration
   
2. **keycloak/**: Keycloak identity provider setup
   - `realm-dify.json`: Pre-configured realm with test users
   - `docker-compose.yml`: Keycloak service configuration

### Key Integration Points
- **OAuth Flow**: `dify/api/controllers/console/auth/oauth.py:103-115`
- **Config Management**: `dify/api/configs/feature/__init__.py:606-618`
- **KeycloakOAuth Class**: `dify/api/libs/oauth.py:140-214`
- **Docker Services**: `dify/docker/docker-compose.yaml`

### Environment Configuration
The system uses a hybrid configuration approach:
- **Base Config**: `.env` file with Dify standard settings
- **SSO Config**: Keycloak-specific variables in docker-compose
- **Runtime Config**: Auto-generated from environment templates

Key SSO environment variables:
```bash
ENABLE_SOCIAL_OAUTH_LOGIN=true
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify
```

## Automated Upstream Sync

The project automatically maintains compatibility with upstream Dify through GitHub Actions:

### GitHub Actions Workflow Features
1. **Automatic Release Detection**: Monitors langgenius/dify for new releases daily
2. **Smart SSO Integration**: Applies Keycloak patches automatically using `scripts/apply-sso-integration.sh`
3. **Multi-Architecture Builds**: Creates Docker images for linux/amd64 and linux/arm64
4. **Automated Releases**: Creates GitHub releases with Docker images

### Manual Sync Process
```bash
# Test SSO integration after manual changes
./scripts/test-sso-integration.sh

# Apply SSO integration to fresh Dify checkout
./scripts/apply-sso-integration.sh

# Manual sync workflow
cd dify && git fetch origin && git checkout <version-tag>
cd .. && ./scripts/apply-sso-integration.sh
```

### Workflow Triggers
- **Automatic**: Daily check for upstream releases
- **Manual**: Workflow dispatch with options for force sync and multi-arch builds
- **Push**: Changes to workflow file or dify/ directory

## Development Guidelines

### Working with OAuth Integration
- OAuth providers are dynamically loaded based on environment config
- Test users: `alice/alice1234` in Keycloak realm
- Keycloak admin: `admin/admin` at `http://localhost:8280/admin`

### Code Modifications
- **API Changes**: Edit files directly in `dify/api/` directory
- **Web Changes**: Modify files in `dify/web/` directory
- **Configuration**: Update environment variables and docker-compose settings

### Testing SSO Integration
1. Start Keycloak: `cd keycloak && docker compose up -d`
2. Start Dify services: `cd dify && docker compose up -d`
3. Access Dify Console: `http://localhost:3000`
4. Click "Login with Keycloak" button
5. Authenticate with test user credentials

### Troubleshooting Common Issues
- **OAuth not visible**: Check `ENABLE_SOCIAL_OAUTH_LOGIN=true` in environment
- **Keycloak connection**: Verify `KEYCLOAK_ISSUER_URL` matches running instance
- **User creation fails**: Check Keycloak realm configuration and user settings
- **Build failures**: Ensure patches apply cleanly to current upstream version

## File Structure Context

- `dify/`: Official Dify repository with integrated SSO modifications
- `keycloak/`: Keycloak identity provider configuration and data
- `nginx/`: Reverse proxy configuration templates (legacy)
- `ssrf_proxy/`: SSRF protection proxy configuration (legacy)
- `volumes/`: Persistent data storage for services
- `CLAUDE.md`: Project documentation and development guidelines

## Enterprise Features

This build includes enterprise-ready features:
- **Multi-tenant SSO**: Keycloak realm-based organization separation
- **HTTPS Support**: Nginx SSL termination with Let's Encrypt integration
- **High Availability**: Redis clustering and PostgreSQL optimization
- **Monitoring**: Built-in logging and health check endpoints
- **Security**: SSRF protection proxy and secure defaults