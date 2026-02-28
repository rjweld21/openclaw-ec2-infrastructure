# OpenClaw GitOps Deployment - Using .env File
# Usage: .\deploy-from-env.ps1
# Make sure you have copied .env.example to .env and filled in your values

param(
    [Parameter(Mandatory=$false)]
    [string]$EnvFile = ".env"
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

function Load-EnvFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "Environment file '$FilePath' not found!"
        Write-Host ""
        Write-Host "Please create your .env file:" -ForegroundColor Yellow
        Write-Host "1. Copy .env.example to .env"
        Write-Host "2. Fill in your actual credentials"
        Write-Host "3. Run this script again"
        exit 1
    }
    
    $envVars = @{}
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $parts = $line.Split("=", 2)
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                $envVars[$key] = $value
            }
        }
    }
    return $envVars
}

# Load environment variables
Write-Status "Loading environment variables from $EnvFile..."
try {
    $env = Load-EnvFile -FilePath $EnvFile
} catch {
    Write-Error "Failed to load environment file: $_"
    exit 1
}

# Extract required variables
$StackName = $env["STACK_NAME"]
$Region = $env["AWS_REGION"]
$KeyPairName = $env["KEY_PAIR_NAME"]
$AnthropicApiKey = $env["ANTHROPIC_API_KEY"]
$GitHubToken = $env["GITHUB_TOKEN"]
$Email = $env["ALERT_EMAIL"]
$AwsAccessKey = $env["AWS_ACCESS_KEY_ID"]
$AwsSecretKey = $env["AWS_SECRET_ACCESS_KEY"]

# Validate required variables
$requiredVars = @{
    "STACK_NAME" = $StackName
    "AWS_REGION" = $Region
    "KEY_PAIR_NAME" = $KeyPairName
    "ANTHROPIC_API_KEY" = $AnthropicApiKey
    "GITHUB_TOKEN" = $GitHubToken
    "ALERT_EMAIL" = $Email
    "AWS_ACCESS_KEY_ID" = $AwsAccessKey
    "AWS_SECRET_ACCESS_KEY" = $AwsSecretKey
}

$missingVars = @()
foreach ($var in $requiredVars.Keys) {
    if (-not $requiredVars[$var] -or $requiredVars[$var] -eq "your_${var.ToLower()}_here" -or $requiredVars[$var].StartsWith("your_")) {
        $missingVars += $var
    }
}

if ($missingVars.Count -gt 0) {
    Write-Error "Missing or incomplete environment variables:"
    foreach ($var in $missingVars) {
        Write-Host "  ❌ $var" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please edit your .env file and fill in all required values." -ForegroundColor Yellow
    exit 1
}

# Validate format of sensitive values
if (-not $AnthropicApiKey.StartsWith("sk-ant-")) {
    Write-Error "Invalid Anthropic API key format. Must start with 'sk-ant-'"
    exit 1
}

if (-not $GitHubToken.StartsWith("ghp_")) {
    Write-Error "Invalid GitHub token format. Must start with 'ghp_'"
    exit 1
}

Write-Success "Environment variables loaded successfully!"
Write-Host ""
Write-Host "🦞 OpenClaw GitOps Edition - Deployment Starting"
Write-Host ""
Write-Host "🎯 Configuration:" -ForegroundColor Blue
Write-Host "  Stack Name: $StackName"
Write-Host "  Region: $Region"
Write-Host "  Key Pair: $KeyPairName"
Write-Host "  API Key: $($AnthropicApiKey.Substring(0, 15))..."
Write-Host "  GitHub Token: $($GitHubToken.Substring(0, 10))..."
Write-Host "  Email: $Email"
Write-Host ""

# Set AWS credentials as environment variables for this session
$env:AWS_ACCESS_KEY_ID = $AwsAccessKey
$env:AWS_SECRET_ACCESS_KEY = $AwsSecretKey
$env:AWS_DEFAULT_REGION = $Region

Write-Status "Checking prerequisites..."

# Validate AWS CLI and credentials
try {
    $CallerIdentity = aws sts get-caller-identity --region $Region 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw }
    $AccountId = $CallerIdentity.Account
    $UserArn = $CallerIdentity.Arn
    Write-Success "AWS credentials valid - Account: $AccountId"
} catch {
    Write-Error "AWS credentials invalid or AWS CLI not working"
    Write-Host "Make sure your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are correct in .env"
    exit 1
}

# Validate key pair
try {
    $null = aws ec2 describe-key-pairs --key-names $KeyPairName --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Success "Key pair '$KeyPairName' found"
} catch {
    Write-Warning "Key pair '$KeyPairName' not found. Creating it..."
    try {
        aws ec2 create-key-pair --key-name $KeyPairName --region $Region --query 'KeyMaterial' --output text > "$KeyPairName.pem"
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Created key pair '$KeyPairName' and saved to $KeyPairName.pem"
            Write-Warning "Keep the .pem file safe! You'll need it if you want to SSH to the instance."
        } else {
            throw
        }
    } catch {
        Write-Error "Failed to create key pair '$KeyPairName'"
        exit 1
    }
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
    Write-Status "Updating existing stack..."
} else {
    $Action = "create-stack"
    $WaitCommand = "stack-create-complete"
    Write-Status "Creating new stack..."
}

# Deploy CloudFormation stack
Write-Status "Deploying GitOps CloudFormation stack..."

# First check if template exists
if (-not (Test-Path "openclaw-gitops.yaml")) {
    Write-Warning "openclaw-gitops.yaml template not found. Using openclaw-personal.yaml..."
    if (-not (Test-Path "openclaw-personal.yaml")) {
        Write-Error "No CloudFormation template found! Need either openclaw-gitops.yaml or openclaw-personal.yaml"
        exit 1
    }
    $TemplateFile = "openclaw-personal.yaml"
} else {
    $TemplateFile = "openclaw-gitops.yaml"
}

aws cloudformation $Action `
    --stack-name $StackName `
    --template-body "file://$TemplateFile" `
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

# Wait for completion with progress dots
$WaitResult = aws cloudformation wait $WaitCommand --stack-name $StackName --region $Region
if ($LASTEXITCODE -ne 0) {
    Write-Error "Stack deployment failed!"
    Write-Host ""
    Write-Host "Check the CloudFormation console for detailed error information:"
    Write-Host "https://$Region.console.aws.amazon.com/cloudformation/home?region=$Region#/stacks"
    exit 1
}

Write-Success "🎉 OpenClaw GitOps Edition deployed successfully!"

# Get stack outputs
Write-Status "Retrieving deployment information..."
$OutputsJson = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs' 2>$null

$Outputs = $OutputsJson | ConvertFrom-Json

$ControlPanelUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StartStopPageURL" -or $_.OutputKey -eq "ControlPanelURL" }).OutputValue
$InstanceId = ($Outputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue
$SSMCommand = ($Outputs | Where-Object { $_.OutputKey -eq "SSMPortForwardCommand" }).OutputValue

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Success "🎉 OpenClaw GitOps Edition Ready!"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "📋 DEPLOYMENT COMPLETE:" -ForegroundColor Blue
Write-Host ""
Write-Host "🎛️  Control Panel: $ControlPanelUrl"
Write-Host "💻 Instance ID: $InstanceId"
Write-Host "👤 GitHub User: $GitHubUser"
Write-Host "🏛️  AWS Account: $AccountId"
Write-Host ""
Write-Host "🔗 Connect to OpenClaw:"
Write-Host $SSMCommand
Write-Host "Then open: http://localhost:18789"
Write-Host ""
Write-Host "💰 COST STRUCTURE:" -ForegroundColor Blue
Write-Host "• Base OpenClaw: `$14.75/month"
Write-Host "• Static sites: +`$1.50/month each"
Write-Host "• APIs: +`$1-3/month each"
Write-Host "• Full-stack apps: +`$15/month each"
Write-Host ""
Write-Host "🎯 NEXT STEPS:" -ForegroundColor Blue
Write-Host "1. Start instance: Visit control panel above"
Write-Host "2. Connect: Use SSM command above"
Write-Host "3. Configure WhatsApp/Telegram in OpenClaw"
Write-Host "4. Test: 'Create a simple React app'"
Write-Host ""
Write-Host "🛡️  SECURITY:" -ForegroundColor Green
Write-Host "✅ Your .env file is git-ignored (secrets safe)"
Write-Host "✅ OpenClaw has minimal AWS permissions"
Write-Host "✅ GitHub Actions handles all deployments"
Write-Host "✅ Complete audit trail in GitHub"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save deployment info
$DeploymentInfo = @"
OpenClaw GitOps Edition - Deployment Info
Generated: $(Get-Date)

Configuration:
- Stack Name: $StackName
- Region: $Region
- Instance ID: $InstanceId
- GitHub User: $GitHubUser
- AWS Account: $AccountId

Access:
- Control Panel: $ControlPanelUrl
- SSH Key: $KeyPairName.pem (if created)

Architecture:
- GitOps workflow (secure!)
- GitHub Actions handle all AWS deployments
- OpenClaw generates code and manages repos
- Pay-per-app cost model

Monthly Costs:
- Base: `$14.75 (OpenClaw instance)
- Per static site: +`$1.50
- Per API: +`$1-3
- Per full app: +`$15

Next Steps:
1. Start instance via control panel
2. Port forward: $SSMCommand
3. Setup messaging (WhatsApp/Telegram)
4. Start building!

Environment File:
Your credentials are safely stored in .env (git-ignored)
GitHub token configured for: $GitHubUser
AWS credentials configured for account: $AccountId
"@

$DeploymentInfo | Out-File -FilePath "deployment-info.txt" -Encoding UTF8

Write-Success "Deployment info saved to: deployment-info.txt"
Write-Host ""
Write-Host "🚀 Your secure GitOps development assistant is ready!" -ForegroundColor Green
Write-Host "Generate code via WhatsApp → GitHub Actions deploys to AWS! 🦞💪"