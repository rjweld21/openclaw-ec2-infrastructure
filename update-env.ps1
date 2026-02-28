# Helper script to update .env with available credentials

param(
    [Parameter(Mandatory=$false)]
    [string]$AnthropicApiKey
)

Write-Host "🔧 Updating .env file with available credentials..." -ForegroundColor Blue

# Get current AWS credentials
$AwsAccessKey = aws configure get aws_access_key_id
$AwsSecretKey = aws configure get aws_secret_access_key  
$AwsRegion = aws configure get region

# Get GitHub token
$GitHubToken = gh auth token

# Read current .env file
$envContent = Get-Content ".env"

# Update .env file
$updatedContent = $envContent | ForEach-Object {
    if ($_ -match "^AWS_ACCESS_KEY_ID=") {
        "AWS_ACCESS_KEY_ID=$AwsAccessKey"
    }
    elseif ($_ -match "^AWS_SECRET_ACCESS_KEY=") {
        "AWS_SECRET_ACCESS_KEY=$AwsSecretKey"
    }
    elseif ($_ -match "^AWS_REGION=") {
        "AWS_REGION=$AwsRegion"
    }
    elseif ($_ -match "^GITHUB_TOKEN=") {
        "GITHUB_TOKEN=$GitHubToken"
    }
    elseif ($_ -match "^ANTHROPIC_API_KEY=" -and $AnthropicApiKey) {
        "ANTHROPIC_API_KEY=$AnthropicApiKey"
    }
    elseif ($_ -match "^ALERT_EMAIL=" -and $_ -match "your-email") {
        "ALERT_EMAIL=rjweld21@gmail.com"
    }
    else {
        $_
    }
}

# Write updated content
$updatedContent | Out-File ".env" -Encoding UTF8

Write-Host "✅ Updated .env file!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Current status:" -ForegroundColor Blue
Write-Host "✅ AWS credentials: Configured" -ForegroundColor Green
Write-Host "✅ GitHub token: Configured" -ForegroundColor Green
Write-Host "✅ Email: Set to rjweld21@gmail.com" -ForegroundColor Green

if ($AnthropicApiKey) {
    Write-Host "✅ Anthropic API key: Configured" -ForegroundColor Green
} else {
    Write-Host "⏳ Anthropic API key: Waiting for input" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Once you have your Anthropic API key, run:" -ForegroundColor Cyan
    Write-Host ".\update-env.ps1 -AnthropicApiKey 'sk-ant-your_key_here'"
}

Write-Host ""
Write-Host "🚀 Once Anthropic key is added, deploy with:" -ForegroundColor Blue
Write-Host ".\scripts\deploy-from-env.ps1"