# OpenClaw GitOps Edition - PowerShell Deployment Script
# Usage: .\deploy-gitops.ps1 -StackName "openclaw-gitops" -Region "us-east-1" -KeyPairName "my-key" -AnthropicApiKey "sk-ant-..." -GitHubToken "ghp_..." -Email "you@example.com"

param(
    [Parameter(Mandatory=$true)]
    [string]$StackName,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyPairName,
    
    [Parameter(Mandatory=$true)]
    [string]$AnthropicApiKey,
    
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$true)]
    [string]$Email
)

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Validate inputs
if (-not $AnthropicApiKey.StartsWith("sk-ant-")) {
    Write-Error "Invalid Anthropic API key format. Must start with 'sk-ant-'"
    exit 1
}

if (-not $GitHubToken.StartsWith("ghp_")) {
    Write-Error "Invalid GitHub token format. Must start with 'ghp_'"
    exit 1
}

Write-Status "🦞 OpenClaw GitOps Edition - Deployment Starting"
Write-Host ""
Write-Host "🎯 GitOps Configuration:" -ForegroundColor Blue
Write-Host "  Stack Name: $StackName"
Write-Host "  Region: $Region" 
Write-Host "  Key Pair: $KeyPairName"
Write-Host "  API Key: $($AnthropicApiKey.Substring(0, 15))..."
Write-Host "  GitHub Token: $($GitHubToken.Substring(0, 10))..."
Write-Host "  Email: $Email"
Write-Host ""
Write-Host "🚀 Architecture:" -ForegroundColor Green
Write-Host "  • Code generation via WhatsApp"
Write-Host "  • GitHub repo management" 
Write-Host "  • GitHub Actions handle AWS deployments"
Write-Host "  • Minimal EC2 permissions (secure!)"
Write-Host "  • Pay-per-app deployment model"
Write-Host ""

# Check prerequisites
Write-Status "Checking prerequisites..."

# Validate AWS CLI
try {
    $null = aws sts get-caller-identity --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Error "AWS CLI not configured or no access to region $Region"
    exit 1
}

# Validate key pair
try {
    $null = aws ec2 describe-key-pairs --key-names $KeyPairName --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Error "Key pair '$KeyPairName' not found in region $Region"
    exit 1
}

# Test GitHub token
Write-Status "Testing GitHub token..."
try {
    $GitHubUser = (curl -H "Authorization: token $GitHubToken" https://api.github.com/user 2>$null | ConvertFrom-Json).login
    Write-Success "GitHub token valid for user: $GitHubUser"
} catch {
    Write-Warning "Could not validate GitHub token (but proceeding...)"
}

# Check if stack exists
$StackExists = $false
try {
    $null = aws cloudformation describe-stacks --stack-name $StackName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) { $StackExists = $true }
} catch {}

if ($StackExists) {
    Write-Warning "Stack '$StackName' already exists"
    $response = Read-Host "Do you want to update it? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Status "Deployment cancelled"
        exit 0
    }
    $Action = "update-stack"
    $WaitCommand = "stack-update-complete"
} else {
    $Action = "create-stack"
    $WaitCommand = "stack-create-complete"
}

# Deploy CloudFormation stack (using simplified template)
Write-Status "Deploying GitOps CloudFormation stack..."
aws cloudformation $Action `
    --stack-name $StackName `
    --template-body "file://openclaw-gitops.yaml" `
    --parameters `
        "ParameterKey=KeyPairName,ParameterValue=$KeyPairName" `
        "ParameterKey=AnthropicApiKey,ParameterValue=$AnthropicApiKey" `
        "ParameterKey=GitHubToken,ParameterValue=$GitHubToken" `
        "ParameterKey=AlertEmail,ParameterValue=$Email" `
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
    --region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start CloudFormation deployment"
    exit 1
}

Write-Status "Waiting for deployment to complete (~8 minutes)..."
Write-Host "GitOps version deploys faster due to simplified permissions!" -ForegroundColor Yellow
Write-Host ""

# Wait for completion
$WaitResult = aws cloudformation wait $WaitCommand --stack-name $StackName --region $Region
if ($LASTEXITCODE -ne 0) {
    Write-Error "Stack deployment failed!"
    exit 1
}

Write-Success "🎉 OpenClaw GitOps Edition deployed successfully!"

# Get stack outputs
Write-Status "Retrieving deployment information..."
$OutputsJson = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs'

$Outputs = $OutputsJson | ConvertFrom-Json

$ControlPanelUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StartStopPageURL" }).OutputValue
$InstanceId = ($Outputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue
$SSMCommand = ($Outputs | Where-Object { $_.OutputKey -eq "SSMPortForwardCommand" }).OutputValue

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Success "🎉 OpenClaw GitOps Edition Ready!"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "📋 QUICK ACCESS:" -ForegroundColor Blue
Write-Host ""
Write-Host "🎛️  Control Panel: $ControlPanelUrl"
Write-Host "💻 Instance ID: $InstanceId"
Write-Host ""
Write-Host "🔗 Connect to OpenClaw:"
Write-Host $SSMCommand
Write-Host "Then: http://localhost:18789"
Write-Host ""
Write-Host "🚀 GITOPS CAPABILITIES:" -ForegroundColor Blue
Write-Host "✅ Code Generation (any language)"
Write-Host "✅ GitHub Repository Management"
Write-Host "✅ Automated GitHub Actions Deployment"
Write-Host "✅ Infrastructure as Code"
Write-Host "✅ WhatsApp, Telegram, Discord"
Write-Host ""
Write-Host "💰 COST STRUCTURE:" -ForegroundColor Blue
Write-Host "• Base OpenClaw: `$14.75/month"
Write-Host "• Static websites: +`$1.50/month each"
Write-Host "• APIs: +`$1-3/month each"
Write-Host "• Full-stack apps: +`$15/month each"
Write-Host "• Pay only for what you deploy!"
Write-Host ""
Write-Host "🛡️  SECURITY BENEFITS:" -ForegroundColor Blue
Write-Host "• Minimal AWS permissions on EC2"
Write-Host "• All deployments via GitHub Actions"
Write-Host "• AWS credentials in GitHub Secrets"
Write-Host "• Complete audit trail in GitHub"
Write-Host "• Code review before deployment"
Write-Host ""
Write-Host "🎯 EXAMPLE WORKFLOWS:" -ForegroundColor Blue
Write-Host "• 'Create a React portfolio site' → GitHub repo + auto-deploy"
Write-Host "• 'Add authentication to my app' → Code updates + CI/CD"
Write-Host "• 'Build a REST API' → Express.js + Lambda deployment"
Write-Host "• 'Set up monitoring' → CloudWatch integration"
Write-Host ""
Write-Host "🛠️  NEXT STEPS:" -ForegroundColor Blue
Write-Host "1. Start instance via Control Panel"
Write-Host "2. Connect via SSM port forwarding (command above)"
Write-Host "3. Set up WhatsApp/Telegram in OpenClaw"
Write-Host "4. Test: 'Create a simple landing page'"
Write-Host "5. Watch GitHub Actions automatically deploy it!"
Write-Host ""
Write-Host "📚 DOCUMENTATION:" -ForegroundColor Blue
Write-Host "• GitOps Guide: GITOPS_ARCHITECTURE.md"
Write-Host "• Cost Details: GITOPS_COST_BREAKDOWN.md"
Write-Host "• Troubleshooting: TROUBLESHOOTING.md"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save deployment info
$DeploymentInfo = @"
OpenClaw GitOps Edition - Deployment Info
Generated: $(Get-Date)

Architecture: GitOps (Code Generation + GitHub Actions Deployment)
Stack Name: $StackName
Region: $Region
Instance ID: $InstanceId
GitHub User: $GitHubUser
Control Panel: $ControlPanelUrl

Capabilities:
- Code generation via WhatsApp
- GitHub repository management
- Automated deployments via GitHub Actions
- Infrastructure as Code
- Professional CI/CD workflows

Security:
- Minimal AWS permissions on EC2
- AWS credentials in GitHub Secrets
- All deployments audited in GitHub
- Code review process available

Cost Structure:
- Base: `$14.75/month (OpenClaw instance)
- Static Sites: +`$1.50/month each
- APIs: +`$1-3/month each
- Full Apps: +`$15/month each
- Pay-per-app model

Example Usage:
- "Create a React todo app" → Generates code, creates repo, deploys via GitHub Actions
- "Add a database to my app" → Updates infrastructure, deploys new version
- "Build a REST API for mobile" → Creates Express.js API, deploys to Lambda
- "Set up SSL for my site" → Updates CloudFormation, redeploys with certificate

Next Steps:
1. Start instance: $ControlPanelUrl
2. Port forward: $SSMCommand
3. Connect WhatsApp/Telegram
4. Start building!

GitHub Setup:
Your GitHub token is configured for repository management.
GitHub Actions will handle all AWS deployments.
AWS credentials should be added to GitHub Secrets for each repo.
"@

$DeploymentInfo | Out-File -FilePath "gitops-deployment-info.txt" -Encoding UTF8

Write-Success "Deployment info saved to: gitops-deployment-info.txt"
Write-Host ""
Write-Status "🚀 Your GitOps development assistant is ready!"
Write-Host ""
Write-Host "This is the same workflow used by professional development teams." -ForegroundColor Green
Write-Host "You now have a 24/7 AI developer that follows industry best practices! 🦞💪"