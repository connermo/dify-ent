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

python3 << 'PYSTEP1'
import re
import sys

file_path = "api/configs/feature/__init__.py"

try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if Keycloak config already exists
    if 'KEYCLOAK_CLIENT_ID' in content:
        print("✅ Keycloak configuration already exists")
    else:
        # Find the GOOGLE_CLIENT_SECRET line and add Keycloak config after it
        pattern = r'(GOOGLE_CLIENT_SECRET: str \| None = Field\([\s\S]*?default=None,[\s\S]*?\)[\s\S]*?)'
        
        replacement = r'''    # Keycloak (OIDC/OAuth2) optional settings for console social login
    KEYCLOAK_CLIENT_ID: str | None = Field(
        description="Keycloak OAuth client ID",
        default=None,
    )
    KEYCLOAK_CLIENT_SECRET: str | None = Field(
        description="Keycloak OAuth client secret",
        default=None,
    )
    KEYCLOAK_ISSUER_URL: str | None = Field(
        description="Keycloak issuer url, e.g. http://localhost:8080/realms/dify",
        default=None,
    )

\1'''
        
        content = re.sub(pattern, replacement, content)
        
        with open(file_path, 'w') as f:
            f.write(content)
        
        print("✅ Added Keycloak configuration")
        
except Exception as e:
    print(f"⚠️  Error: {e}")
    sys.exit(1)
PYSTEP1

echo "📝 Step 2: Adding KeycloakOAuth class to api/libs/oauth.py..."

python3 << 'PYSTEP2'
import sys

file_path = "api/libs/oauth.py"

try:
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if KeycloakOAuth class already exists
    if 'class KeycloakOAuth' in content:
        print("✅ KeycloakOAuth class already exists")
    else:
        # Check if imports are needed
        imports_to_add = []
        if 'import hashlib' not in content:
            imports_to_add.append('import hashlib')
        if 'import base64' not in content:
            imports_to_add.append('import base64')
        if 'import secrets' not in content:
            imports_to_add.append('import secrets')
        if 'import json' not in content:
            imports_to_add.append('import json')
        
        if imports_to_add:
            # Add imports at the beginning
            lines = content.split('\n')
            import_end = 0
            for i, line in enumerate(lines):
                if line.strip() and not line.strip().startswith('#'):
                    if any(line.startswith(imp) for imp in ['import ', 'from ']):
                        import_end = i + 1
                    else:
                        break
            
            for imp in imports_to_add:
                if imp not in '\n'.join(lines[:import_end]):
                    lines.insert(import_end, imp)
                    import_end += 1
            
            content = '\n'.join(lines)
        
        # Add KeycloakOAuth class
        keycloak_class = '''

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
'''
        
        # Append to the end of the file
        content += keycloak_class
        
        with open(file_path, 'w') as f:
            f.write(content)
        
        print("✅ Added KeycloakOAuth class")
        
except Exception as e:
    print(f"⚠️  Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYSTEP2

echo ""
echo "✅ Script completed! Please review the changes and test the integration."
echo ""
echo "📋 What was modified:"
echo "  1. Added Keycloak configuration to api/configs/feature/__init__.py"
echo "  2. Added KeycloakOAuth class to api/libs/oauth.py"
echo ""
echo "⚠️  Note: Additional steps (updating controllers, frontend, etc.)"
echo "    need to be done manually or with a more robust script."

cd ..

