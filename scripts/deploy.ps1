# OpenClaw Personal Edition - PowerShell Deployment Script
# Usage: .\deploy.ps1 -StackName "openclaw-personal" -Region "us-east-1" -KeyPairName "my-keypair" -AnthropicApiKey "sk-ant-..."

param(
    [Parameter(Mandatory=$true)]
    [string]$StackName,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyPairName,
    
    [Parameter(Mandatory=$true)]
    [string]$AnthropicApiKey
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

# Validate Anthropic API key format
if (-not $AnthropicApiKey.StartsWith("sk-ant-")) {
    Write-Error "Invalid Anthropic API key format. Must start with 'sk-ant-'"
    exit 1
}

Write-Status "Starting OpenClaw Personal Edition deployment..."
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Stack Name: $StackName"
Write-Host "  Region: $Region" 
Write-Host "  Key Pair: $KeyPairName"
Write-Host "  API Key: $($AnthropicApiKey.Substring(0, 15))..."
Write-Host ""

# Check if AWS CLI is configured
Write-Status "Checking AWS CLI configuration..."
try {
    $null = aws sts get-caller-identity --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Error "AWS CLI not configured or no access to region $Region"
    Write-Warning "Run 'aws configure' to set up your credentials"
    exit 1
}

# Validate key pair exists
Write-Status "Validating EC2 key pair..."
try {
    $null = aws ec2 describe-key-pairs --key-names $KeyPairName --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Error "Key pair '$KeyPairName' not found in region $Region"
    Write-Warning "Create a key pair first: aws ec2 create-key-pair --key-name $KeyPairName --region $Region"
    exit 1
}

# Check if stack already exists
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

# Deploy CloudFormation stack
Write-Status "Deploying CloudFormation stack..."
aws cloudformation $Action `
    --stack-name $StackName `
    --template-body "file://openclaw-personal.yaml" `
    --parameters "ParameterKey=KeyPairName,ParameterValue=$KeyPairName" "ParameterKey=AnthropicApiKey,ParameterValue=$AnthropicApiKey" `
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
    --region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start CloudFormation deployment"
    exit 1
}

# Wait for deployment to complete
Write-Status "Waiting for deployment to complete (this takes ~8-10 minutes)..."
Write-Host "You can monitor progress in the AWS Console:"
Write-Host "https://console.aws.amazon.com/cloudformation/home?region=$Region#/stacks/stackinfo?stackId=$StackName"
Write-Host ""

# Show progress dots
$ProgressJob = Start-Job -ScriptBlock {
    param($StackName, $Region)
    while ($true) {
        try {
            $status = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].StackStatus' --output text 2>$null
            if ($status -notmatch "(IN_PROGRESS|PENDING)") { break }
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 30
        } catch {
            break
        }
    }
} -ArgumentList $StackName, $Region

# Wait for stack completion
$WaitResult = aws cloudformation wait $WaitCommand --stack-name $StackName --region $Region
Stop-Job -Job $ProgressJob -Force
Remove-Job -Job $ProgressJob -Force

if ($LASTEXITCODE -ne 0) {
    Write-Host ""  # New line after progress dots
    Write-Error "Stack deployment failed!"
    
    # Show recent stack events for debugging
    Write-Host ""
    Write-Status "Recent stack events:"
    aws cloudformation describe-stack-events `
        --stack-name $StackName `
        --region $Region `
        --max-items 10 `
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' `
        --output table
    
    exit 1
}

Write-Host ""  # New line after progress dots
Write-Success "Stack deployment completed!"

# Get stack outputs
Write-Status "Retrieving stack outputs..."
$OutputsJson = aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query 'Stacks[0].Outputs'

$Outputs = $OutputsJson | ConvertFrom-Json

# Extract function URLs
$StartUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StartFunctionURL" }).OutputValue
$StopUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StopFunctionURL" }).OutputValue  
$StatusUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StatusFunctionURL" }).OutputValue
$StartStopPageUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StartStopPageURL" }).OutputValue
$S3Bucket = $StartStopPageUrl -replace 'https://([^.]+)\..*', '$1'
$InstanceId = ($Outputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue
$SSMCommand = ($Outputs | Where-Object { $_.OutputKey -eq "SSMPortForwardCommand" }).OutputValue

Write-Status "Configuring web interface..."

# Create temporary HTML file with replaced URLs
$HtmlContent = Get-Content "web/index.html" -Raw
$HtmlContent = $HtmlContent -replace "REPLACE_WITH_START_FUNCTION_URL", $StartUrl
$HtmlContent = $HtmlContent -replace "REPLACE_WITH_STOP_FUNCTION_URL", $StopUrl  
$HtmlContent = $HtmlContent -replace "REPLACE_WITH_STATUS_FUNCTION_URL", $StatusUrl
$HtmlContent | Out-File -FilePath "web/index.html.tmp" -Encoding UTF8

# Upload to S3
Write-Status "Uploading web interface to S3..."
aws s3 cp "web/index.html.tmp" "s3://$S3Bucket/index.html" `
    --content-type "text/html" `
    --region $Region

# Clean up temporary file
Remove-Item "web/index.html.tmp" -ErrorAction SilentlyContinue

# Display success message and instructions
Write-Host ""
Write-Success "🎉 OpenClaw Personal Edition deployed successfully!"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "📋 QUICK ACCESS:"
Write-Host ""
Write-Host "1️⃣  Control Panel (Start/Stop): $StartStopPageUrl"
Write-Host ""
Write-Host "2️⃣  Instance Management:"
Write-Host "    • Instance ID: $InstanceId"
Write-Host "    • Status: Use the control panel above"
Write-Host ""
Write-Host "3️⃣  OpenClaw Access (when instance is running):"
Write-Host "    Step 1: Start port forwarding:"
Write-Host "    $SSMCommand"
Write-Host ""
Write-Host "    Step 2: Open OpenClaw:"
Write-Host "    http://localhost:18789"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "💰 COST ESTIMATE:"
Write-Host "   • Current schedule: 8am-8pm weekdays (12 hrs/day)"
Write-Host "   • Monthly AWS cost: ~`$15.50"
Write-Host "   • Anthropic API: Your existing usage rates"
Write-Host ""
Write-Host "⏰ AUTOMATIC SCHEDULE:"
Write-Host "   • Starts: Monday-Friday at 8:00 AM EST"
Write-Host "   • Stops: Monday-Friday at 8:00 PM EST" 
Write-Host "   • Manual override: Use the control panel anytime"
Write-Host ""
Write-Host "🔧 NEXT STEPS:"
Write-Host "   1. Bookmark the control panel URL"
Write-Host "   2. Start the instance using the control panel"
Write-Host "   3. Set up port forwarding when you want to use OpenClaw"
Write-Host "   4. Connect your messaging apps (WhatsApp, Telegram, etc.)"
Write-Host ""
Write-Host "📚 DOCUMENTATION:"
Write-Host "   • OpenClaw docs: https://docs.openclaw.ai"
Write-Host "   • This repo: $(Get-Location)\README.md"
Write-Host ""
Write-Host "🆘 TROUBLESHOOTING:"
Write-Host "   • Check CloudWatch logs: AWS Console → CloudWatch → Log Groups"
Write-Host "   • Instance not starting? Check the control panel status"
Write-Host "   • Port forwarding issues? Ensure SSM Session Manager plugin is installed"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save deployment info to file
$DeploymentInfo = @"
OpenClaw Personal Edition - Deployment Info
Generated: $(Get-Date)

Stack Name: $StackName
Region: $Region  
Instance ID: $InstanceId

Control Panel: $StartStopPageUrl
SSM Port Forward: $SSMCommand
OpenClaw URL: http://localhost:18789 (after port forwarding)

Lambda Function URLs:
- Start: $StartUrl
- Stop: $StopUrl
- Status: $StatusUrl

Monthly Cost Estimate: ~`$15.50
Schedule: 8am-8pm weekdays (EST)
"@

$DeploymentInfo | Out-File -FilePath "deployment-info.txt" -Encoding UTF8

Write-Success "Deployment info saved to: deployment-info.txt"
Write-Host ""
Write-Status "Happy OpenClaw-ing! 🦞"