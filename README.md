# Dify Enterprise SSO (Local Keycloak Integration)

This repository provides a complete solution for integrating Dify Console with a local Keycloak OAuth2/OpenID Connect (OIDC) server for Single Sign-On (SSO) authentication.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Dify Console │    │   Dify API      │    │   Keycloak     │
│   (Frontend)   │    │   (Backend)     │    │   (OIDC IdP)   │
│                 │    │                 │    │                 │
│ - Login Button │───▶│ - OAuth Routes  │───▶│ - Auth Server  │
│ - OAuth Flow   │    │ - Token Exchange│    │ - User Mgmt    │
│ - Callback     │    │ - User Creation │    │ - Realm Config │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### 1. Start Keycloak Server

```bash
cd keycloak
docker compose up -d
```

Wait for Keycloak to be ready (check logs):
```bash
docker compose logs -f keycloak
```

**Expected URLs:**
- Keycloak Admin: http://localhost:8280/admin
- Dify Realm: http://localhost:8280/realms/dify
- OpenID Config: http://localhost:8280/realms/dify/.well-known/openid-configuration

**Default Credentials:**
- Admin: `admin` / `admin`
- Test User: `alice` / `alice1234`

### 2. Configure Dify Environment Variables

Add these to your Dify `api` service `.env` file:

```bash
# OAuth Configuration
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak OAuth Settings
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# Dify URLs (adjust ports as needed)
CONSOLE_API_URL=http://localhost:5001
CONSOLE_WEB_URL=http://localhost:3000
```

### 3. Apply Code Changes

#### Option A: Use the Patch File (Recommended)
```bash
cd /path/to/your/dify
git apply /path/to/dify-ent/dify-keycloak.diff
```

#### Option B: Manual Code Changes
Apply the changes manually to these files:
- `api/configs/feature/__init__.py` - Add Keycloak config fields
- `api/libs/oauth.py` - Add KeycloakOAuth class
- `api/controllers/console/auth/oauth.py` - Register Keycloak provider
- `web/app/signin/components/social-auth.tsx` - Add login button

### 4. Restart Dify Services

```bash
# Restart API service
docker compose restart api

# Restart Web service  
docker compose restart web
```

## 🔧 Configuration Details

### Keycloak Realm Configuration

The `keycloak/realm-dify.json` file pre-configures:

- **Realm**: `dify` - Security domain for Dify applications
- **Client**: `dify-console` - OAuth client for Dify Console
- **User**: `alice` - Test user with email `alice@example.com`
- **Redirect URIs**: Configured for localhost development
- **Scopes**: OpenID Connect standard scopes enabled

### OAuth Flow

1. **User clicks "Login with Keycloak"** on Dify sign-in page
2. **Redirect to Keycloak** with OAuth2 authorization request
3. **User authenticates** on Keycloak (username/password or SSO)
4. **Keycloak redirects back** to Dify with authorization code
5. **Dify exchanges code** for access token and user info
6. **User is logged in** to Dify with Keycloak identity

### Security Features

- **HTTPS Required**: Configured for production use
- **Client Secret**: Secure client authentication
- **Standard Flow**: OAuth2 Authorization Code flow
- **Scope Control**: Configurable user permissions
- **Session Management**: Integrated with Dify's session system

## 🛠️ Development & Customization

### Adding New Users

```bash
# Access Keycloak Admin Console
open http://localhost:8280/admin

# Login with admin/admin
# Navigate to Users → Add User
# Set username, email, and credentials
```

### Customizing the Realm

```bash
# Export current realm configuration
docker exec keycloak /opt/keycloak/bin/kc.sh export --realm dify --file custom-realm.json

# Modify the JSON file
# Import back to Keycloak
docker exec keycloak /opt/keycloak/bin/kc.sh import --file custom-realm.json
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KEYCLOAK_ADMIN` | Admin username | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Admin password | `admin` |
| `KC_HTTP_PORT` | Keycloak port | `8080` |
| `KC_DB` | Database type | `dev-file` |

## 🔍 Troubleshooting

### Common Issues

#### 1. Keycloak Won't Start
```bash
# Check if port 8280 is available
netstat -tlnp | grep 8280

# Check Docker logs
docker compose logs keycloak

# Restart with clean volumes
docker compose down -v
docker compose up -d
```

#### 2. OAuth Login Button Not Visible
- Verify `ENABLE_SOCIAL_OAUTH_LOGIN=true`
- Check browser console for JavaScript errors
- Ensure all environment variables are set

#### 3. Authentication Fails
- Verify `KEYCLOAK_ISSUER_URL` is correct
- Check Keycloak client configuration
- Ensure redirect URIs match exactly

#### 4. User Creation Issues
- Check if user exists in Keycloak realm
- Verify email verification settings
- Check Dify logs for error messages

### Debug Mode

Enable debug logging in Keycloak:
```bash
# Add to docker-compose.yml environment
KC_LOG_LEVEL: DEBUG
```

### Health Checks

```bash
# Check Keycloak health
curl -f http://localhost:8280/realms/dify/.well-known/openid-configuration

# Check Dify API health
curl -f http://localhost:5001/health
```

## 📚 Additional Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect Specification](https://openid.net/connect/)
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [Dify Documentation](https://docs.dify.ai/)

## 🤝 Contributing

To contribute to this integration:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review Keycloak and Dify logs
3. Verify all configuration steps
4. Open an issue with detailed error information

---

**Note**: This integration is designed for development and testing. For production use, ensure proper security measures including HTTPS, strong passwords, and regular security updates.

