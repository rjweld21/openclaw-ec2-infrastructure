# OpenClaw Personal Edition - Prerequisites Checker (PowerShell)

Write-Host "🦞 OpenClaw Personal Edition - Prerequisites Check" -ForegroundColor Blue
Write-Host "=================================================" -ForegroundColor Blue
Write-Host ""

$AllGood = $true

# Check AWS CLI
Write-Host "1. AWS CLI..." -NoNewline
try {
    $null = Get-Command aws -ErrorAction Stop
    $AwsVersion = (aws --version 2>$null).Split()[0]
    Write-Host " ✅ Installed ($AwsVersion)" -ForegroundColor Green
    
    # Check AWS credentials
    Write-Host "2. AWS Credentials..." -NoNewline
    $Identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($Identity.Account) {
        Write-Host " ✅ Valid (Account: $($Identity.Account))" -ForegroundColor Green
        $CurrentRegion = aws configure get region 2>$null
        if ($CurrentRegion) {
            Write-Host "   Default region: $CurrentRegion" -ForegroundColor Gray
        }
    } else {
        Write-Host " ❌ Not configured" -ForegroundColor Red
        Write-Host "   Run: aws configure" -ForegroundColor Yellow
        $AllGood = $false
    }
} catch {
    Write-Host " ❌ Not installed" -ForegroundColor Red
    Write-Host "   Install: winget install Amazon.AWSCLI" -ForegroundColor Yellow
    Write-Host "   Or visit: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    $AllGood = $false
}

# Check SSM Session Manager Plugin
Write-Host "3. SSM Session Manager Plugin..." -NoNewline
try {
    $null = session-manager-plugin --version 2>$null
    Write-Host " ✅ Installed" -ForegroundColor Green
} catch {
    Write-Host " ⚠️  Not installed (optional)" -ForegroundColor Yellow
    Write-Host "   Install from AWS docs" -ForegroundColor Gray
}

# Check for jq (helpful for JSON parsing)
Write-Host "4. JSON parsing..." -NoNewline
try {
    $null = Get-Command jq -ErrorAction Stop
    Write-Host " ✅ jq found" -ForegroundColor Green
} catch {
    # Check if we have PowerShell 3.0+ for ConvertFrom-Json
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        Write-Host " ✅ PowerShell JSON support" -ForegroundColor Green
    } else {
        Write-Host " ⚠️  Limited JSON support" -ForegroundColor Yellow
    }
}

# Check CloudFormation template
Write-Host "5. CloudFormation template..." -NoNewline
if (Test-Path "openclaw-personal.yaml") {
    Write-Host " ✅ Found" -ForegroundColor Green
} else {
    Write-Host " ❌ Not found" -ForegroundColor Red
    $AllGood = $false
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Blue

if ($AllGood) {
    Write-Host "🎉 All prerequisites met! Ready to deploy." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Blue
    Write-Host "1. Get your Anthropic API key from: https://console.anthropic.com/" -ForegroundColor Gray
    Write-Host "2. Create/verify EC2 key pair in AWS Console" -ForegroundColor Gray
    Write-Host "3. Run deployment:" -ForegroundColor Gray
    Write-Host "   .\deploy.ps1 -StackName 'openclaw-personal' -Region 'us-east-1' -KeyPairName 'your-key' -AnthropicApiKey 'sk-ant-...'" -ForegroundColor Cyan
} else {
    Write-Host "❌ Some prerequisites need attention." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install missing components above, then run this script again." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Documentation:" -ForegroundColor Blue
Write-Host "   Quick Start: QUICKSTART.md" -ForegroundColor Gray
Write-Host "   Full Setup: DEPLOYMENT_CHECKLIST.md" -ForegroundColor Gray
Write-Host "   Troubleshooting: TROUBLESHOOTING.md" -ForegroundColor Gray