# RJ's Setup Progress Checker

Write-Host "🦞 RJ's OpenClaw Setup Progress" -ForegroundColor Blue
Write-Host "==============================" -ForegroundColor Blue
Write-Host ""

$Steps = @()

# Step 1: AWS CLI
Write-Host "Step 1: AWS CLI Installation..." -NoNewline
try {
    $null = Get-Command aws -ErrorAction Stop
    Write-Host " ✅ DONE" -ForegroundColor Green
    $Steps += "✅ AWS CLI installed"
} catch {
    Write-Host " ❌ TODO" -ForegroundColor Red
    $Steps += "❌ Install AWS CLI: winget install Amazon.AWSCLI"
}

# Step 2 & 3: AWS Configuration
Write-Host "Step 2-3: AWS Configuration..." -NoNewline
try {
    $Identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    if ($Identity.Account) {
        Write-Host " ✅ DONE" -ForegroundColor Green
        $Steps += "✅ AWS credentials configured (Account: $($Identity.Account))"
        
        $Region = aws configure get region 2>$null
        if ($Region) {
            $Steps += "✅ Default region: $Region"
        }
    } else {
        Write-Host " ❌ TODO" -ForegroundColor Red
        $Steps += "❌ Run: aws configure (need Access Key ID, Secret Key, region)"
    }
} catch {
    Write-Host " ❌ TODO" -ForegroundColor Red
    $Steps += "❌ Install AWS CLI first"
}

# Step 4: EC2 Key Pair
Write-Host "Step 4: EC2 Key Pair..." -NoNewline
try {
    $KeyPairs = aws ec2 describe-key-pairs --region us-east-1 --query 'KeyPairs[].KeyName' --output text 2>$null
    if ($KeyPairs -match "openclaw-key") {
        Write-Host " ✅ DONE" -ForegroundColor Green
        $Steps += "✅ EC2 key pair 'openclaw-key' exists"
    } else {
        Write-Host " ❌ TODO" -ForegroundColor Yellow
        $Steps += "❌ Create key pair: aws ec2 create-key-pair --key-name openclaw-key --region us-east-1"
    }
} catch {
    Write-Host " ❌ TODO" -ForegroundColor Red
    $Steps += "❌ Configure AWS CLI first"
}

# Step 5: Anthropic API Key (can't check, but remind)
Write-Host "Step 5: Anthropic API Key..." -ForegroundColor Yellow -NoNewline
Write-Host " ❓ GET READY" -ForegroundColor Yellow
$Steps += "❓ Get Anthropic API key from https://console.anthropic.com/"

# Step 6: Deployment Status
Write-Host "Step 6: Deployment Status..." -NoNewline
try {
    $StackStatus = aws cloudformation describe-stacks --stack-name "openclaw-personal" --region us-east-1 --query 'Stacks[0].StackStatus' --output text 2>$null
    if ($StackStatus -eq "CREATE_COMPLETE" -or $StackStatus -eq "UPDATE_COMPLETE") {
        Write-Host " ✅ DEPLOYED!" -ForegroundColor Green
        $Steps += "✅ OpenClaw deployed successfully"
        
        # Get outputs
        $Outputs = aws cloudformation describe-stacks --stack-name "openclaw-personal" --region us-east-1 --query 'Stacks[0].Outputs' 2>$null | ConvertFrom-Json
        $ControlPanelUrl = ($Outputs | Where-Object { $_.OutputKey -eq "StartStopPageURL" }).OutputValue
        if ($ControlPanelUrl) {
            $Steps += "Control Panel: $ControlPanelUrl"
        }
        
        $SSMCommand = ($Outputs | Where-Object { $_.OutputKey -eq "SSMPortForwardCommand" }).OutputValue
        if ($SSMCommand) {
            $Steps += "Port Forward Command: Ready"
        }
        
        $InstanceId = ($Outputs | Where-Object { $_.OutputKey -eq "InstanceId" }).OutputValue
        if ($InstanceId) {
            # Check instance status
            $InstanceState = aws ec2 describe-instances --instance-ids $InstanceId --region us-east-1 --query 'Reservations[0].Instances[0].State.Name' --output text 2>$null
            $Steps += "Instance Status: $InstanceState ($InstanceId)"
        }
        
    } elseif ($StackStatus) {
        Write-Host " ⚠️  IN PROGRESS ($StackStatus)" -ForegroundColor Yellow
        $Steps += "⚠️ Deployment in progress: $StackStatus"
    } else {
        Write-Host " ❌ NOT DEPLOYED" -ForegroundColor Red
        $Steps += "❌ Run deployment when ready"
    }
} catch {
    Write-Host " ❌ NOT DEPLOYED" -ForegroundColor Red
    $Steps += "❌ Ready to deploy when AWS is configured"
}

Write-Host ""
Write-Host "==============================" -ForegroundColor Blue
Write-Host "PROGRESS SUMMARY:" -ForegroundColor Blue
Write-Host ""

foreach ($Step in $Steps) {
    Write-Host $Step
}

Write-Host ""

# Check if ready to deploy
$CanDeploy = $true
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { $CanDeploy = $false }
try {
    $null = aws sts get-caller-identity 2>$null
    if ($LASTEXITCODE -ne 0) { $CanDeploy = $false }
} catch {
    $CanDeploy = $false
}

if ($CanDeploy) {
    # Check if already deployed
    try {
        $StackStatus = aws cloudformation describe-stacks --stack-name "openclaw-personal" --region us-east-1 --query 'Stacks[0].StackStatus' --output text 2>$null
        if ($StackStatus -eq "CREATE_COMPLETE" -or $StackStatus -eq "UPDATE_COMPLETE") {
            Write-Host "🎉 SETUP COMPLETE! OpenClaw is deployed and ready." -ForegroundColor Green
            Write-Host ""
            Write-Host "NEXT STEPS:" -ForegroundColor Blue
            Write-Host "1. Open your Control Panel URL (above) to start instance" -ForegroundColor Gray
            Write-Host "2. Run port forward command to connect" -ForegroundColor Gray
            Write-Host "3. Open http://localhost:18789 in browser" -ForegroundColor Gray
            Write-Host "4. Connect WhatsApp in OpenClaw interface" -ForegroundColor Gray
        } else {
            Write-Host "⚠️ DEPLOYMENT IN PROGRESS..." -ForegroundColor Yellow
            Write-Host "Check again in a few minutes: .\check-my-setup.ps1" -ForegroundColor Gray
        }
    } catch {
        Write-Host "🚀 READY TO DEPLOY!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You have everything needed. Run:" -ForegroundColor Blue
        Write-Host ".\deploy.ps1 -StackName 'openclaw-personal' -Region 'us-east-1' -KeyPairName 'openclaw-key' -AnthropicApiKey 'sk-ant-YOUR-KEY'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Replace 'sk-ant-YOUR-KEY' with your actual Anthropic API key" -ForegroundColor Yellow
    }
} else {
    Write-Host "📋 FOLLOW THE SETUP GUIDE:" -ForegroundColor Yellow
    Write-Host "Open RJ_SETUP_GUIDE.md and complete the missing steps above." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Run this script anytime to check progress: .\check-my-setup.ps1" -ForegroundColor Blue