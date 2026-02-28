# Extract Claude Token for EC2 Transfer
# Run this on your Windows machine to get the exact EC2 setup command

Write-Host "Extracting Claude authentication token..." -ForegroundColor Blue
Write-Host ""

$claudeConfigPath = "$env:APPDATA\claude\config.json"

if (Test-Path $claudeConfigPath) {
    try {
        $claudeConfig = Get-Content $claudeConfigPath | ConvertFrom-Json
        $claudeToken = $claudeConfig.'oauth:tokenCache'
        
        if ($claudeToken) {
            Write-Host "Claude token found successfully!" -ForegroundColor Green
            Write-Host "Token preview: $($claudeToken.Substring(0,20))..." -ForegroundColor Gray
            Write-Host ""
            
            Write-Host "STEP 1: Copy this command to run on EC2:" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "mkdir -p ~/.config/claude" -ForegroundColor Cyan
            $configCommand = @"
cat > ~/.config/claude/config.json << 'EOF'
{
    "locale": "en-US",
    "userThemeMode": "system",
    "oauth:tokenCache": "$claudeToken"
}
EOF
"@
            Write-Host $configCommand -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "STEP 2: Test authentication on EC2:" -ForegroundColor Yellow
            Write-Host "claude chat 'Hello world'" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Host "This transfers your 200/month Claude subscription to EC2!" -ForegroundColor Green
            Write-Host "No API costs, no additional charges!" -ForegroundColor Green
            
        } else {
            Write-Host "No OAuth token found in Claude config" -ForegroundColor Red
            Write-Host "You may need to login to Claude Desktop first" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error reading Claude config: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Claude config not found at: $claudeConfigPath" -ForegroundColor Red
    Write-Host "Make sure Claude Desktop is installed and you have logged in" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next: Run the generated command on your EC2 instance!" -ForegroundColor Cyan