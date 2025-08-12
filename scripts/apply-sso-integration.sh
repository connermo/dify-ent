#!/bin/bash

# Apply SSO Integration to Fresh Dify Installation
# This script applies Keycloak OAuth integration to a fresh Dify codebase

set -e

echo "🚀 Applying SSO Integration to Dify..."

# Check if we're in the right directory
if [ ! -d "dify/api" ]; then
    echo "❌ Error: dify/api directory not found. Please run this script from the project root."
    exit 1
fi

cd dify

echo "📝 Step 1: Adding Keycloak configuration to api/configs/feature/__init__.py..."

# Add Keycloak configuration after Google OAuth settings
if ! grep -q "KEYCLOAK_CLIENT_ID" api/configs/feature/__init__.py; then
    # Find the line with GOOGLE_CLIENT_SECRET and add Keycloak config after it
    sed -i '/GOOGLE_CLIENT_SECRET.*default=None/a\
\
    # Keycloak (OIDC/OAuth2) optional settings for console social login\
    KEYCLOAK_CLIENT_ID: Optional[str] = Field(\
        description="Keycloak OAuth client ID",\
        default=None,\
    )\
    KEYCLOAK_CLIENT_SECRET: Optional[str] = Field(\
        description="Keycloak OAuth client secret",\
        default=None,\
    )\
    KEYCLOAK_ISSUER_URL: Optional[str] = Field(\
        description="Keycloak issuer url, e.g. http://localhost:8080/realms/dify",\
        default=None,\
    )' api/configs/feature/__init__.py
    echo "✅ Added Keycloak configuration"
else
    echo "✅ Keycloak configuration already exists"
fi

echo "📝 Step 2: Adding KeycloakOAuth class to api/libs/oauth.py..."

# Add imports if not present
if ! grep -q "import hashlib" api/libs/oauth.py; then
    sed -i '1a import hashlib\nimport base64\nimport secrets\nimport json' api/libs/oauth.py
    echo "✅ Added required imports"
fi

# Add KeycloakOAuth class if not present
if ! grep -q "class KeycloakOAuth" api/libs/oauth.py; then
    cat >> api/libs/oauth.py << 'EOF'


class KeycloakOAuth(OAuth):
    """
    Minimal OAuth2/OIDC client for Keycloak with PKCE support.

    issuer_url should be like: http://localhost:8080/realms/dify
    which yields standard endpoints under:
      - {issuer_url}/protocol/openid-connect/auth
      - {issuer_url}/protocol/openid-connect/token
      - {issuer_url}/protocol/openid-connect/userinfo
    """

    def __init__(self, client_id: str, client_secret: str, redirect_uri: str, issuer_url: str):
        super().__init__(client_id, client_secret, redirect_uri)
        self.issuer_url = issuer_url.rstrip("/")
        self._AUTH_URL = f"{self.issuer_url}/protocol/openid-connect/auth"
        self._TOKEN_URL = f"{self.issuer_url}/protocol/openid-connect/token"
        self._USER_INFO_URL = f"{self.issuer_url}/protocol/openid-connect/userinfo"

        # Generate PKCE parameters
        self.code_verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).decode('utf-8').rstrip('=')
        self.code_challenge = base64.urlsafe_b64encode(
            hashlib.sha256(self.code_verifier.encode('utf-8')).digest()
        ).decode('utf-8').rstrip('=')

    def get_authorization_url(self, invite_token: str = None):
        params = {
            "client_id": self.client_id,
            "response_type": "code",
            "redirect_uri": self.redirect_uri,
            # request minimal scopes to retrieve email
            "scope": "openid email profile",
            # PKCE parameters
            "code_challenge": self.code_challenge,
            "code_challenge_method": "S256",
        }
        # Encode code_verifier in state to persist it across the OAuth flow
        state_data = {"code_verifier": self.code_verifier}
        if invite_token:
            state_data["invite_token"] = invite_token
        params["state"] = base64.urlsafe_b64encode(json.dumps(state_data).encode()).decode()
        return f"{self._AUTH_URL}?{urllib.parse.urlencode(params)}"

    def set_code_verifier(self, code_verifier: str):
        """Set the code verifier from state parameter during callback"""
        self.code_verifier = code_verifier

    def get_access_token(self, code: str):
        data = {
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": self.redirect_uri,
            "code_verifier": self.code_verifier,
        }
        headers = {"Accept": "application/json"}
        response = requests.post(self._TOKEN_URL, data=data, headers=headers, verify=False)
        response.raise_for_status()
        response_json = response.json()
        access_token = response_json.get("access_token")
        if not access_token:
            raise ValueError(f"Error in Keycloak OAuth: {response_json}")
        return access_token

    def get_raw_user_info(self, token: str):
        headers = {"Authorization": f"Bearer {token}"}
        response = requests.get(self._USER_INFO_URL, headers=headers, verify=False)
        response.raise_for_status()
        return response.json()

    def _transform_user_info(self, raw_info: dict) -> OAuthUserInfo:
        # Keycloak OIDC userinfo contains 'sub' and may include 'email' and 'name'
        email = raw_info.get("email") or ""
        name = raw_info.get("name") or raw_info.get("preferred_username") or ""
        return OAuthUserInfo(id=str(raw_info.get("sub", "")), name=name, email=email)
EOF
    echo "✅ Added KeycloakOAuth class"
else
    echo "✅ KeycloakOAuth class already exists"
fi

echo "📝 Step 3: Updating OAuth controller api/controllers/console/auth/oauth.py..."

# Add imports for Keycloak and required modules
if ! grep -q "KeycloakOAuth" api/controllers/console/auth/oauth.py; then
    sed -i 's/from libs.oauth import GitHubOAuth, GoogleOAuth, OAuthUserInfo/from libs.oauth import GitHubOAuth, GoogleOAuth, OAuthUserInfo, KeycloakOAuth/' api/controllers/console/auth/oauth.py
    echo "✅ Added KeycloakOAuth import"
fi

if ! grep -q "import base64" api/controllers/console/auth/oauth.py; then
    sed -i '1a import base64\nimport json' api/controllers/console/auth/oauth.py
    echo "✅ Added required imports to OAuth controller"
fi

# Add Keycloak provider to get_oauth_providers function
if ! grep -q "keycloak_oauth" api/controllers/console/auth/oauth.py; then
    # Find the line with github/google providers and add keycloak after it
    sed -i '/OAUTH_PROVIDERS = {"github": github_oauth, "google": google_oauth}/c\
        # Keycloak settings are optional; present only when fully configured\
        if (\
            getattr(dify_config, "KEYCLOAK_CLIENT_ID", None)\
            and getattr(dify_config, "KEYCLOAK_CLIENT_SECRET", None)\
            and getattr(dify_config, "KEYCLOAK_ISSUER_URL", None)\
        ):\
            keycloak_oauth = KeycloakOAuth(\
                client_id=dify_config.KEYCLOAK_CLIENT_ID,\
                client_secret=dify_config.KEYCLOAK_CLIENT_SECRET,\
                redirect_uri=dify_config.CONSOLE_API_URL + "/console/api/oauth/authorize/keycloak",\
                issuer_url=dify_config.KEYCLOAK_ISSUER_URL,\
            )\
        else:\
            keycloak_oauth = None\
\
        OAUTH_PROVIDERS = {"github": github_oauth, "google": google_oauth, "keycloak": keycloak_oauth}' api/controllers/console/auth/oauth.py
    echo "✅ Added Keycloak OAuth provider"
fi

# Add OAuth providers API endpoint
if ! grep -q "OAuthProvidersApi" api/controllers/console/auth/oauth.py; then
    # Find the OAuthCallback class and add OAuthProvidersApi before it
    sed -i '/class OAuthCallback(Resource):/i\
class OAuthProvidersApi(Resource):\
    """Resource for listing available OAuth providers."""\
\
    def get(self):\
        """Get the list of available OAuth providers."""\
        OAUTH_PROVIDERS = get_oauth_providers()\
        available_providers = {k: v is not None for k, v in OAUTH_PROVIDERS.items()}\
        return {"providers": available_providers}\
\
\
' api/controllers/console/auth/oauth.py
    echo "✅ Added OAuthProvidersApi class"
fi

# Add PKCE support in callback handling
if ! grep -q "code_verifier" api/controllers/console/auth/oauth.py; then
    # Add PKCE handling in OAuthCallback
    sed -i '/state = request.args.get("state")/a\
        invite_token = None\
\
        # Parse state parameter for Keycloak PKCE support\
        if state and provider == "keycloak":\
            try:\
                state_data = json.loads(base64.urlsafe_b64decode(state).decode())\
                code_verifier = state_data.get("code_verifier")\
                invite_token = state_data.get("invite_token")\
                if code_verifier:\
                    oauth_provider.set_code_verifier(code_verifier)\
            except Exception:\
                # Fallback to treating state as invite_token\
                invite_token = state\
        elif state:\
            invite_token = state' api/controllers/console/auth/oauth.py
    echo "✅ Added PKCE support in OAuth callback"
fi

# Register OAuth providers API endpoint
if ! grep -q 'api.add_resource(OAuthProvidersApi, "/oauth/providers")' api/controllers/console/auth/oauth.py; then
    sed -i '/api\.add_resource(OAuthLogin, "\/oauth\/login\/<provider>")/i\
api.add_resource(OAuthProvidersApi, "/oauth/providers")' api/controllers/console/auth/oauth.py
    echo "✅ Registered OAuth providers API endpoint"
fi

echo "📝 Step 4: Adding SSO environment variables to docker/docker-compose.yaml..."

# Add SSO environment variables to docker-compose.yaml
if ! grep -q "KEYCLOAK_CLIENT_ID" docker/docker-compose.yaml; then
    sed -i '/NOTION_INTERNAL_SECRET: \${NOTION_INTERNAL_SECRET:-}/a\
  # SSO & OAuth Settings\
  ENABLE_SOCIAL_OAUTH_LOGIN: ${ENABLE_SOCIAL_OAUTH_LOGIN:-false}\
  GITHUB_CLIENT_ID: ${GITHUB_CLIENT_ID:-}\
  GITHUB_CLIENT_SECRET: ${GITHUB_CLIENT_SECRET:-}\
  GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID:-}\
  GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET:-}\
  KEYCLOAK_CLIENT_ID: ${KEYCLOAK_CLIENT_ID:-}\
  KEYCLOAK_CLIENT_SECRET: ${KEYCLOAK_CLIENT_SECRET:-}\
  KEYCLOAK_ISSUER_URL: ${KEYCLOAK_ISSUER_URL:-}' docker/docker-compose.yaml
    echo "✅ Added SSO environment variables to docker-compose.yaml"
else
    echo "✅ SSO environment variables already exist in docker-compose.yaml"
fi

echo "📝 Step 5: Updating frontend SSO display text..."

# Update frontend to show "SSO" instead of "Keycloak" 
if [ -f "web/app/signin/components/social-auth.tsx" ]; then
    # Only attempt replacements if the original content exists
    if grep -q "withKeycloak\|bg-blue-600.*KC" web/app/signin/components/social-auth.tsx; then
        # Change the button text from Keycloak to SSO
        sed -i 's/withKeycloak/withSSO/g' web/app/signin/components/social-auth.tsx
        
        # Change the icon color and text (escape special characters properly)
        sed -i 's/bg-blue-600 text-white text-xs font-bold rounded/bg-indigo-600 text-white text-xs font-bold rounded/g' web/app/signin/components/social-auth.tsx
        sed -i 's/KC/SSO/g' web/app/signin/components/social-auth.tsx
        echo "✅ Updated frontend SSO display text"
    else
        echo "✅ Frontend SSO display already updated or no Keycloak content found"
    fi
else
    echo "⚠️  Frontend component not found, skipping display text update"
fi

echo "📝 Step 6: Creating .env file with SSO configuration..."

cat > .env << 'EOF'
# SSO Configuration for Dify Enterprise
ENABLE_SOCIAL_OAUTH_LOGIN=true

# Keycloak OAuth Settings
KEYCLOAK_CLIENT_ID=dify-console
KEYCLOAK_CLIENT_SECRET=dify-console-secret
KEYCLOAK_ISSUER_URL=http://localhost:8280/realms/dify

# Console and API URLs
CONSOLE_API_URL=http://localhost:5001
CONSOLE_WEB_URL=http://localhost:3000
EOF

echo "✅ Created .env file with SSO configuration"

cd ..

echo ""
echo "🎉 SSO Integration Applied Successfully!"
echo ""
echo "📋 Summary of changes:"
echo "  ✅ Added Keycloak configuration fields"
echo "  ✅ Added KeycloakOAuth class with PKCE support"
echo "  ✅ Updated OAuth controller with Keycloak integration"
echo "  ✅ Added OAuth providers API endpoint"
echo "  ✅ Updated docker-compose.yaml with SSO environment variables"
echo "  ✅ Updated frontend to display 'SSO' instead of 'Keycloak'"
echo "  ✅ Created .env file with default SSO configuration"
echo ""
echo "🚀 Ready to build Docker images!"