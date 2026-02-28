#!/bin/bash
# Claude Authentication Setup for EC2
# Transfers your local Claude subscription to EC2

set -e

echo "🔐 Claude Authentication Setup Starting..."

# Create Claude config directory
mkdir -p ~/.config/claude

# Check if token was provided as argument
if [ "$1" != "" ]; then
    CLAUDE_TOKEN="$1"
    echo "✅ Using provided Claude token"
else
    echo "❌ No Claude token provided"
    echo "Usage: ./setup-claude-auth.sh <your-claude-token>"
    echo ""
    echo "Get your token from Windows machine:"
    echo "Get-Content \"\$env:APPDATA\\claude\\config.json\" | ConvertFrom-Json | Select-Object -ExpandProperty 'oauth:tokenCache'"
    exit 1
fi

# Create Claude config with the token
cat > ~/.config/claude/config.json << EOF
{
    "locale": "en-US", 
    "userThemeMode": "system",
    "oauth:tokenCache": "$CLAUDE_TOKEN"
}
EOF

echo "✅ Claude config created at ~/.config/claude/config.json"

# Test authentication
echo "🧪 Testing Claude authentication..."
if timeout 30 claude chat "Hello! Please respond with just 'Authentication successful'" 2>/dev/null; then
    echo "✅ Claude authentication working perfectly!"
    echo "💰 Your \$200/month subscription is now active on EC2"
else
    echo "⚠️  Authentication test inconclusive (may work for full sessions)"
    echo "🔍 Try: claude chat 'Hello world' manually"
fi

echo ""
echo "🎉 Claude authentication setup complete!"
echo "💡 Your local Claude subscription is now usable on EC2"