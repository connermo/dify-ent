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

# Add Keycloak configuration after Google OAuth settings using Python for reliability
python3 << 'PYTHON_SCRIPT'
import re
import sys

file_path = "api/configs/feature/__init__.py"

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if Keycloak config already exists
    if 'KEYCLOAK_CLIENT_ID' in content:
        print("✅ Keycloak configuration already exists")
        sys.exit(0)
    
    # Find the location after GOOGLE_CLIENT_SECRET
    keycloak_config = '''    # Keycloak (OIDC/OAuth2) optional settings for console social login
    KEYCLOAK_CLIENT_ID: Optional[str] = Field(
        description="Keycloak OAuth client ID",
        default=None,
    )
    KEYCLOAK_CLIENT_SECRET: Optional[str] = Field(
        description="Keycloak OAuth client secret",
        default=None,
    )
    KEYCLOAK_ISSUER_URL: Optional[str] = Field(
        description="Keycloak issuer url, e.g. http://localhost:8080/realms/dify",
        default=None,
    )'''
    
    # Find GOOGLE_CLIENT_SECRET field definition - handle multi-line Field() definitions
    # Pattern 1: Single line with Field() all on one line
    pattern1 = r'(GOOGLE_CLIENT_SECRET[^\n]*default=None[^\n]*\n)'
    
    # Pattern 2: Multi-line Field() definition
    pattern2 = r'(GOOGLE_CLIENT_SECRET[^\n]*\n[^\n]*Field\([^\)]*default=None[^\)]*\)[^\n]*\n)'
    
    # Pattern 3: Multi-line with description
    pattern3 = r'(GOOGLE_CLIENT_SECRET[^\n]*\n[^\n]*Field\([^\)]*description[^\)]*\n[^\)]*default=None[^\)]*\)[^\n]*\n)'
    
    # Find the end of GOOGLE_CLIENT_SECRET field (including closing parenthesis and newline)
    # Look for GOOGLE_CLIENT_SECRET followed by Field definition ending with default=None
    found = False
    
    # Try to find the complete GOOGLE_CLIENT_SECRET field definition
    # Handle both Optional[str] and str | None formats
    # Pattern 1: Optional[str] format
    google_secret_pattern1 = r'(GOOGLE_CLIENT_SECRET\s*:\s*Optional\[str\]\s*=\s*Field\([^\)]*default=None[^\)]*\)\s*\n)'
    # Pattern 2: str | None format (newer Python syntax)
    google_secret_pattern2 = r'(GOOGLE_CLIENT_SECRET\s*:\s*str\s*\|\s*None\s*=\s*Field\([^\)]*default=None[^\)]*\)\s*\n)'
    
    match = re.search(google_secret_pattern1, content, re.MULTILINE)
    if not match:
        match = re.search(google_secret_pattern2, content, re.MULTILINE)
    
    if match:
        # Insert after the matched field
        insert_pos = match.end()
        content = content[:insert_pos] + keycloak_config + '\n' + content[insert_pos:]
        found = True
    else:
        # Try multi-line Field() definitions with Optional[str]
        google_secret_pattern3 = r'(GOOGLE_CLIENT_SECRET\s*:\s*Optional\[str\]\s*=\s*Field\([^)]*\n[^)]*\n[^)]*default=None[^)]*\n[^)]*\)\s*\n)'
        match3 = re.search(google_secret_pattern3, content, re.MULTILINE | re.DOTALL)
        
        if not match3:
            # Try multi-line with str | None format
            google_secret_pattern4 = r'(GOOGLE_CLIENT_SECRET\s*:\s*str\s*\|\s*None\s*=\s*Field\([^)]*\n[^)]*\n[^)]*default=None[^)]*\n[^)]*\)\s*\n)'
            match3 = re.search(google_secret_pattern4, content, re.MULTILINE | re.DOTALL)
        
        if match3:
            insert_pos = match3.end()
            content = content[:insert_pos] + keycloak_config + '\n' + content[insert_pos:]
            found = True
    
    if found:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ Added Keycloak configuration")
    else:
        # Fallback: find GOOGLE_CLIENT_SECRET line and insert after the next non-indented line or class boundary
        google_lines = [i for i, line in enumerate(content.split('\n')) if 'GOOGLE_CLIENT_SECRET' in line]
        if google_lines:
            # Find the end of the Field() definition after GOOGLE_CLIENT_SECRET
            start_idx = content.find('GOOGLE_CLIENT_SECRET')
            if start_idx >= 0:
                # Look for the closing parenthesis and newline after default=None
                search_from = start_idx
                # Find the next closing parenthesis followed by newline
                paren_match = re.search(r'\)\s*\n', content[search_from:search_from+500])
                if paren_match:
                    insert_pos = search_from + paren_match.end()
                    content = content[:insert_pos] + keycloak_config + '\n' + content[insert_pos:]
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print("✅ Added Keycloak configuration (fallback method)")
                    found = True
        
        if not found:
            print("❌ Error: Could not find GOOGLE_CLIENT_SECRET to insert Keycloak config")
            print("File search context:")
            # Show context around Google OAuth settings
            if 'GOOGLE_CLIENT_SECRET' in content:
                idx = content.find('GOOGLE_CLIENT_SECRET')
                print(content[max(0, idx-100):idx+300])
            sys.exit(1)

except Exception as e:
    print(f"❌ Error adding Keycloak configuration: {e}")
    sys.exit(1)
PYTHON_SCRIPT

# Verify the configuration was added
if ! grep -q "KEYCLOAK_CLIENT_ID" api/configs/feature/__init__.py; then
    echo "❌ Error: Failed to add Keycloak configuration. Verification failed."
    exit 1
fi

echo "📝 Step 2: Adding KeycloakOAuth class to api/libs/oauth.py..."

# Add imports if not present
if ! grep -q "import hashlib" api/libs/oauth.py; then
    python3 -c "
import sys
with open('api/libs/oauth.py', 'r') as f:
    lines = f.readlines()
    imports = ['import hashlib\n', 'import base64\n', 'import secrets\n', 'import json\n']
    for imp in imports:
        if imp not in lines[0]:
            lines.insert(0, imp)
    with open('api/libs/oauth.py', 'w') as f:
        f.writelines(lines)
"
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
    sed -i.bak 's/from libs.oauth import GitHubOAuth, GoogleOAuth, OAuthUserInfo/from libs.oauth import GitHubOAuth, GoogleOAuth, OAuthUserInfo, KeycloakOAuth/' api/controllers/console/auth/oauth.py
    echo "✅ Added KeycloakOAuth import"
fi

if ! grep -q "import base64" api/controllers/console/auth/oauth.py; then
    sed -i.bak '1a import base64\nimport json' api/controllers/console/auth/oauth.py
    echo "✅ Added required imports to OAuth controller"
fi

# Add Keycloak provider to get_oauth_providers function
if ! grep -q "keycloak_oauth" api/controllers/console/auth/oauth.py; then
    # Find the line with github/google providers and add keycloak after it
    sed -i.bak '/OAUTH_PROVIDERS = {"github": github_oauth, "google": google_oauth}/c\
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
    sed -i.bak '/class OAuthCallback(Resource):/i\
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
    sed -i.bak '/state = request.args.get("state")/a\
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
    sed -i.bak '/api\.add_resource(OAuthLogin, "\/oauth\/login\/<provider>")/i\
api.add_resource(OAuthProvidersApi, "/oauth/providers")' api/controllers/console/auth/oauth.py
    echo "✅ Registered OAuth providers API endpoint"
fi

echo "📝 Step 4: Adding SSO environment variables to docker/docker-compose.yaml..."

# Add SSO environment variables to docker-compose.yaml
if ! grep -q "KEYCLOAK_CLIENT_ID" docker/docker-compose.yaml; then
    sed -i.bak '/NOTION_INTERNAL_SECRET: \${NOTION_INTERNAL_SECRET:-}/a\
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
    # Use Python to handle the file modification properly
    python3 << 'PYTHON_SCRIPT'
import re
import sys

file_path = "web/app/signin/components/social-auth.tsx"

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if SSO/Keycloak provider block already exists
    if 'providers?.keycloak' in content or 'providers.keycloak' in content:
        # Update existing Keycloak references to SSO (if needed)
        if 'RiUserLine' not in content:
            # Add RiUserLine import if not present
            if 'from "@remixicon/react"' not in content and "from '@remixicon/react'" not in content:
                content = re.sub(
                    r'(import.*from [\'"]react-i18next[\'"])',
                    r"\1\nimport { RiUserLine } from '@remixicon/react'",
                    content
                )
            # Replace old SSO icon with RiUserLine
            content = re.sub(
                r'<span className="mr-2 h-5 w-5 flex items-center justify-center bg-indigo-600 text-white text-xs font-bold rounded">\s*SSO\s*</span>',
                '<RiUserLine className="mr-2 h-5 w-5 text-indigo-600" />',
                content
            )
            print("✅ Updated SSO icon to RiUserLine")
        else:
            print("✅ SSO icon already using RiUserLine")
    else:
        # Add RiUserLine import if not present
        if 'from "@remixicon/react"' not in content and "from '@remixicon/react'" not in content:
            content = re.sub(
                r'(import.*from [\'"]react-i18next[\'"])',
                r"\1\nimport { RiUserLine } from '@remixicon/react'",
                content
            )
        
        # Add providers prop to the component type if not already present
        if 'providers?' not in content:
            content = re.sub(
                r'(type SocialAuthProps = \{[^\n]*)',
                r'\1\n  providers?: any',
                content
            )
        
        # Add SSO provider block after Google OAuth but before the closing tags
        sso_block = '''    {props.providers?.keycloak && (
      <div className='w-full'>
        <a href={getOAuthLink('/oauth/login/keycloak')}>
          <Button
            disabled={props.disabled}
            className='w-full'
          >
            <>
              <RiUserLine className="mr-2 h-5 w-5 text-indigo-600" />
              <span className="truncate leading-normal">{t('login.withSSO')}</span>
            </>
          </Button>
        </a>
      </div>
    )}
'''
        
        # Insert before the closing </> tags
        content = content.replace(
            '  </>\n}',
            '  </>\n' + sso_block + '\n}'
        )
        
        print("✅ Added SSO provider block to frontend")
    
    # Write back to file
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

except Exception as e:
    print(f"⚠️  Error updating frontend: {e}")
    sys.exit(1)
PYTHON_SCRIPT

    # Also update normal-form.tsx to pass providers to SocialAuth
    if [ -f "web/app/signin/normal-form.tsx" ]; then
        python3 << 'PYTHON_SCRIPT2'
import re
import sys

file_path = "web/app/signin/normal-form.tsx"

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Check if providers are already being fetched and passed
    if 'providers' in content and 'SocialAuth' in content:
        # Check if providers are passed to SocialAuth
        if 'providers=' in content or 'providers: ' in content:
            print("✅ Providers already being passed to SocialAuth")
        else:
            print("⚠️  Providers defined but not passed to SocialAuth - manual update may be needed")
    else:
        print("⚠️  No providers handling found in normal-form.tsx - manual update may be needed")
        
except Exception as e:
    print(f"⚠️  Error checking normal-form.tsx: {e}")

PYTHON_SCRIPT2
    fi
else
    echo "⚠️  Frontend component not found at web/app/signin/components/social-auth.tsx"
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

# User Registration and Workspace Settings
ALLOW_REGISTER=true
ALLOW_CREATE_WORKSPACE=true
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
echo "  ✅ Updated frontend to display SSO button with user icon (RiUserLine)"
echo "  ✅ Added conditional rendering for OAuth providers"
echo "  ✅ Created .env file with default SSO configuration"
echo ""
echo "🚀 Ready to build Docker images!"