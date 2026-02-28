# OpenClaw Hybrid DevOps Edition - PowerShell Deployment Script
# Usage: .\deploy-hybrid.ps1 -StackName "openclaw-devops" -Region "us-east-1" -KeyPairName "my-key" -AnthropicApiKey "sk-ant-..." -GitHubToken "ghp_..." -Email "you@example.com"

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
    [string]$Email,
    
    [Parameter(Mandatory=$false)]
    [string]$PhoneNumber = "",
    
    [Parameter(Mandatory=$false)]
    [int]$DailyBudget = 10,
    
    [Parameter(Mandatory=$false)]
    [int]$MonthlyBudget = 100
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

Write-Status "🦞 OpenClaw Hybrid DevOps Edition - Deployment Starting"
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Stack Name: $StackName"
Write-Host "  Region: $Region"
Write-Host "  Key Pair: $KeyPairName"
Write-Host "  API Key: $($AnthropicApiKey.Substring(0, 15))..."
Write-Host "  GitHub Token: $($GitHubToken.Substring(0, 10))..."
Write-Host "  Email: $Email"
Write-Host "  Daily Budget: $DailyBudget USD"
Write-Host "  Monthly Budget: $MonthlyBudget USD"
Write-Host ""

# Check prerequisites
Write-Status "Checking prerequisites..."

# Validate AWS CLI
try {
    $null = aws sts get-caller-identity --region $Region
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Error "AWS CLI not configured or no access to region $Region"
    exit 1
}

# Validate key pair
try {
    $null = aws ec2 describe-key-pairs --key-names $KeyPairName --region $Region
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Error "Key pair '$KeyPairName' not found in region $Region"
    exit 1
}

# Check if stack exists
$StackExists = $false
try {
    $null = aws cloudformation describe-stacks --stack-name $StackName --region $Region
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

# Deploy CloudFormation stack
Write-Status "Deploying enhanced CloudFormation stack..."
aws cloudformation $Action `
    --stack-name $StackName `
    --template-body "file://openclaw-hybrid.yaml" `
    --parameters `
        "ParameterKey=KeyPairName,ParameterValue=$KeyPairName" `
        "ParameterKey=AnthropicApiKey,ParameterValue=$AnthropicApiKey" `
        "ParameterKey=GitHubToken,ParameterValue=$GitHubToken" `
        "ParameterKey=AlertEmail,ParameterValue=$Email" `
        "ParameterKey=DailyBudgetLimit,ParameterValue=$DailyBudget" `
        "ParameterKey=MonthlyBudgetLimit,ParameterValue=$MonthlyBudget" `
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
    --region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start CloudFormation deployment"
    exit 1
}

Write-Status "Waiting for deployment to complete (10-15 minutes)..."
Write-Host "Enhanced version takes longer due to additional security setup."
Write-Host ""

# Wait for completion
$WaitResult = aws cloudformation wait $WaitCommand --stack-name $StackName --region $Region
if ($LASTEXITCODE -ne 0) {
    Write-Error "Stack deployment failed!"
    exit 1
}

Write-Success "🎉 OpenClaw Hybrid DevOps Edition deployed!"

# Get stack outputs
Write-Status "Configuring monitoring and alerts..."
$OutputsJson = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs'

$Outputs = $OutputsJson | ConvertFrom-Json

$ControlPanelUrl = ($Outputs | Where-Object { $_.OutputKey -eq "ControlPanelURL" }).OutputValue
$InstanceId = ($Outputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue
$SSMCommand = ($Outputs | Where-Object { $_.OutputKey -eq "SSMPortForwardCommand" }).OutputValue

# Set up cost monitoring
Write-Status "Setting up cost monitoring..."
$BudgetName = "$StackName-monthly-budget"
aws budgets create-budget `
    --account-id (aws sts get-caller-identity --query 'Account' --output text) `
    --budget "{
        \"BudgetName\": \"$BudgetName\",
        \"BudgetLimit\": {
            \"Amount\": \"$MonthlyBudget\",
            \"Unit\": \"USD\"
        },
        \"TimeUnit\": \"MONTHLY\",
        \"BudgetType\": \"COST\",
        \"CostFilters\": {
            \"TagKey\": [\"CreatedBy\"],
            \"TagValue\": [\"openclaw\"]
        }
    }" 2>$null || Write-Warning "Budget may already exist"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Success "🎉 OpenClaw Hybrid DevOps Edition Ready!"
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
Write-Host "🚀 HYBRID CAPABILITIES:" -ForegroundColor Blue
Write-Host "✅ AWS Resource Management (with limits)"
Write-Host "✅ GitHub Integration"
Write-Host "✅ Code Generation & Deployment"
Write-Host "✅ Cost Monitoring & Alerts"
Write-Host "✅ WhatsApp, Telegram, Discord"
Write-Host ""
Write-Host "💰 COST CONTROLS:" -ForegroundColor Blue
Write-Host "• Daily Limit: $DailyBudget USD (email alerts)"
Write-Host "• Monthly Budget: $MonthlyBudget USD (hard stop)"
Write-Host "• Max EC2 Instances: 2"
Write-Host "• Allowed Instance Types: t4g.small, t4g.medium, t3.small, t3.medium"
Write-Host ""
Write-Host "📧 MONITORING:" -ForegroundColor Blue
Write-Host "• Email alerts: $Email"
Write-Host "• Instance start/stop notifications"
Write-Host "• Daily cost summaries"
Write-Host "• Resource creation alerts"
Write-Host ""
Write-Host "🛠️  NEXT STEPS:" -ForegroundColor Blue
Write-Host "1. Start instance via Control Panel"
Write-Host "2. Connect via SSM port forwarding"
Write-Host "3. Set up WhatsApp/Telegram in OpenClaw"
Write-Host "4. Test: 'Create a simple Node.js app and deploy it'"
Write-Host ""
Write-Host "📚 DOCUMENTATION:" -ForegroundColor Blue
Write-Host "• Architecture: HYBRID_ARCHITECTURE.md"
Write-Host "• Examples: Try 'Create a React app called todo-list'"
Write-Host "• Troubleshooting: TROUBLESHOOTING.md"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save deployment info
$DeploymentInfo = @"
OpenClaw Hybrid DevOps Edition - Deployment Info
Generated: $(Get-Date)

Stack Name: $StackName
Region: $Region
Instance ID: $InstanceId
Control Panel: $ControlPanelUrl

Capabilities:
- AWS Resource Management (limited)
- GitHub Integration  
- Code Generation & Deployment
- Cost Monitoring & Alerts

Limits:
- Daily Budget: $DailyBudget USD
- Monthly Budget: $MonthlyBudget USD
- Max EC2 Instances: 2
- Instance Types: t4g.small, t4g.medium, t3.small, t3.medium

Monitoring:
- Email: $Email
- Instance lifecycle alerts
- Cost threshold notifications
- Daily spend summaries

Example Commands:
- "Create a React app called 'my-project'"
- "Deploy the app to AWS with SSL certificate"
- "Show me this month's AWS costs"
- "List all my running instances"
"@

$DeploymentInfo | Out-File -FilePath "hybrid-deployment-info.txt" -Encoding UTF8

Write-Success "Deployment info saved to: hybrid-deployment-info.txt"
Write-Host ""
Write-Status "Your DevOps assistant is ready! 🦞💪"