# Manual AWS EC2 Deployment Script  
# NOW WITH AUTOMATED CLAUDE TOKEN TRANSFER! 🎯

Write-Host "🚀 OpenClaw + Claude Code CLI - IMPROVED Deployment" -ForegroundColor Green
Write-Host ""
Write-Host "💰 Expected Savings: $500+/month vs API approach" -ForegroundColor Yellow
Write-Host "🎯 Goal: Transfer your local Claude subscription to EC2" -ForegroundColor Cyan
Write-Host "✨ NEW: Automatic Claude authentication transfer!" -ForegroundColor Magenta
Write-Host ""

# Extract Claude token from local system
$claudeConfigPath = "$env:APPDATA\claude\config.json"
Write-Host "🔍 Extracting Claude token from local system..." -ForegroundColor Blue

if (Test-Path $claudeConfigPath) {
    try {
        $claudeConfig = Get-Content $claudeConfigPath | ConvertFrom-Json
        $claudeToken = $claudeConfig.'oauth:tokenCache'
        
        if ($claudeToken) {
            Write-Host "✅ Claude token found: $($claudeToken.Substring(0,20))..." -ForegroundColor Green
            Write-Host "💾 Token will be transferred to EC2 automatically" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Claude token not found in config" -ForegroundColor Yellow
            Write-Host "🔑 Will fall back to manual login on EC2" -ForegroundColor Yellow
            $claudeToken = $null
        }
    } catch {
        Write-Host "❌ Error reading Claude config: $($_.Exception.Message)" -ForegroundColor Red
        $claudeToken = $null
    }
} else {
    Write-Host "⚠️  Claude config not found at: $claudeConfigPath" -ForegroundColor Yellow
    Write-Host "🔑 Will use manual authentication" -ForegroundColor Yellow
    $claudeToken = $null
}

Write-Host ""
Write-Host "📋 Deployment Steps:" -ForegroundColor Blue
Write-Host ""

Write-Host "Step 1: Launch EC2 Instance via AWS Console" -ForegroundColor Yellow
Write-Host "• Go to AWS Console → EC2 → Launch Instance"
Write-Host "• AMI: Ubuntu 22.04 LTS (ami-0c7217cdde317cfec)"
Write-Host "• Instance Type: t3.medium"
Write-Host "• Key Pair: Create new 'openclaw-test'"
Write-Host "• Security Group: Default (allow SSH)"
Write-Host "• Tags: Name=OpenClaw-Claude-Test"
Write-Host ""

Write-Host "Step 2: SSH Setup Commands" -ForegroundColor Yellow
Write-Host "Once instance is running, SSH in and run:"
Write-Host ""

# Generate the setup script dynamically
$setupScript = @'
#!/bin/bash
echo "🚀 OpenClaw + Claude Code CLI Setup Starting..."

# Update system
sudo apt-get update -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs git curl

# Verify installations
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-cli

# Install OpenClaw  
npm install -g openclaw

# Create Claude config directory
mkdir -p ~/.config/claude

echo "✅ Base installation complete!"
'@

if ($claudeToken) {
    # Add Claude token transfer to the script
    $setupScript += @"

echo "🔐 Setting up Claude authentication..."

# Create Claude config with your token
cat > ~/.config/claude/config.json << 'EOF'
{
    "locale": "en-US", 
    "userThemeMode": "system",
    "oauth:tokenCache": "$claudeToken"
}
EOF

echo "✅ Claude authentication configured!"
echo "🧪 Testing Claude connection..."

# Test Claude authentication
if claude chat "Hello! Please respond with just 'Authentication successful'"; then
    echo "✅ Claude authentication working!"
else
    echo "❌ Claude authentication failed - may need manual login"
fi
"@
} else {
    # Add manual authentication steps
    $setupScript += @'

echo "🔑 Manual Claude authentication required..."
echo "Run: claude auth login"
echo "Then test with: claude chat 'Hello world'"
'@
}

$setupScript += @'

# Set up OpenClaw environment
echo "⚙️ Configuring OpenClaw..."
echo 'export CLAUDECODE=1' >> ~/.bashrc
echo 'export CLAUDE_CODE_ENTRYPOINT=cli' >> ~/.bashrc

# Apply environment for current session
export CLAUDECODE=1
export CLAUDE_CODE_ENTRYPOINT=cli

echo "🎉 Setup complete!"
echo ""
echo "🧪 Test OpenClaw with:"
echo "openclaw status"
echo ""
echo "💰 You're now using your $200/month Claude subscription on EC2!"
echo "🚀 Expected savings: $500+/month vs API approach"
'@

Write-Host $setupScript
Write-Host ""

if ($claudeToken) {
    Write-Host "✨ AUTOMATED AUTHENTICATION ENABLED!" -ForegroundColor Magenta
    Write-Host "• Your local Claude token will be transferred automatically" -ForegroundColor Green
    Write-Host "• No manual login required on EC2!" -ForegroundColor Green
} else {
    Write-Host "🔑 Manual authentication required:" -ForegroundColor Yellow
    Write-Host "• Run 'claude auth login' on EC2 after setup" -ForegroundColor Yellow
    Write-Host "• Use your normal Claude web account credentials" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📊 Total Monthly Cost: ~$35 (just EC2)" -ForegroundColor Cyan
Write-Host "💡 vs $700+/month with API approach" -ForegroundColor Yellow
Write-Host ""
Write-Host "🎯 Next: Launch EC2 and run the setup script above!" -ForegroundColor Green