# Quick EC2 Test Deployment for OpenClaw + Claude Code CLI
# Usage: .\quick-test-ec2.ps1 -KeyPairName "your-key"

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyPairName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$InstanceType = "t3.medium"
)

Write-Host "🧪 Quick Test: OpenClaw + Claude Code CLI on EC2" -ForegroundColor Green
Write-Host ""
Write-Host "Testing approach: Replicate your local setup on EC2" -ForegroundColor Yellow
Write-Host "Expected savings: $500+/month vs API approach" -ForegroundColor Green
Write-Host ""

# Create user data script for initial setup
$UserDataScript = @"
#!/bin/bash
set -e

# Update system
sudo apt-get update -y

# Install Node.js (for OpenClaw)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude Code CLI
# Note: This will need manual authentication step
curl -L https://claude.ai/claude-code/install.sh | sudo bash

# Create setup log
echo "=== EC2 Setup Complete ===" > /home/ubuntu/setup.log
echo "Node.js version: \$(node --version)" >> /home/ubuntu/setup.log
echo "NPM version: \$(npm --version)" >> /home/ubuntu/setup.log
echo "Claude Code CLI status:" >> /home/ubuntu/setup.log
claude --version >> /home/ubuntu/setup.log 2>&1 || echo "Claude CLI needs authentication" >> /home/ubuntu/setup.log
echo "Next: SSH in and run authentication" >> /home/ubuntu/setup.log
echo "Setup completed at: \$(date)" >> /home/ubuntu/setup.log

# Install OpenClaw (we'll configure this after Claude Code auth works)
# npm install -g openclaw

echo "Ready for manual Claude Code authentication"
"@

# Encode user data
$UserDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserDataScript))

Write-Host "🚀 Deploying test EC2 instance..." -ForegroundColor Blue

# Launch EC2 instance
$InstanceResult = aws ec2 run-instances `
    --image-id "ami-0c7217cdde317cfec" `
    --count 1 `
    --instance-type $InstanceType `
    --key-name $KeyPairName `
    --security-groups "default" `
    --user-data $UserDataEncoded `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=OpenClaw-Claude-Test},{Key=Purpose,Value=Testing}]" `
    --region $Region | ConvertFrom-Json

if (-not $InstanceResult) {
    Write-Host "❌ Failed to launch EC2 instance" -ForegroundColor Red
    exit 1
}

$InstanceId = $InstanceResult.Instances[0].InstanceId
Write-Host "✅ EC2 Instance launched: $InstanceId" -ForegroundColor Green

# Wait for instance to be running
Write-Host "⏳ Waiting for instance to be running..." -ForegroundColor Yellow
aws ec2 wait instance-running --instance-ids $InstanceId --region $Region

# Get public IP
$InstanceDetails = aws ec2 describe-instances --instance-ids $InstanceId --region $Region | ConvertFrom-Json
$PublicIP = $InstanceDetails.Reservations[0].Instances[0].PublicIpAddress

Write-Host ""
Write-Host "🎉 Test Instance Ready!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Connection Details:" -ForegroundColor Blue
Write-Host "Instance ID: $InstanceId"
Write-Host "Public IP: $PublicIP"
Write-Host "SSH Command: ssh -i $KeyPairName.pem ubuntu@$PublicIP"
Write-Host ""
Write-Host "🧪 Testing Steps:" -ForegroundColor Yellow
Write-Host "1. SSH into the instance using the command above"
Write-Host "2. Check setup log: cat /home/ubuntu/setup.log"
Write-Host "3. Authenticate Claude Code CLI: claude auth login"
Write-Host "4. Test Claude access: claude chat 'Hello, can you respond?'"
Write-Host "5. If successful, install OpenClaw: npm install -g openclaw"
Write-Host "6. Configure OpenClaw to use Claude Code backend"
Write-Host ""
Write-Host "💰 Expected Result:" -ForegroundColor Green
Write-Host "Claude Code CLI should authenticate with your \$200/month subscription"
Write-Host "No additional per-token API costs!"
Write-Host ""
Write-Host "📞 Next: SSH in and test Claude Code authentication" -ForegroundColor Cyan

# Save instance info
$TestInfo = @"
OpenClaw + Claude Code CLI Test Instance

Instance ID: $InstanceId
Public IP: $PublicIP
SSH Command: ssh -i $KeyPairName.pem ubuntu@$PublicIP

Testing Goal:
- Authenticate Claude Code CLI with your \$200/month subscription
- Install OpenClaw and configure for Claude Code backend
- Verify no per-token API costs

Manual Steps:
1. SSH into instance
2. Run: claude auth login
3. Follow authentication prompts
4. Test: claude chat 'Hello world'
5. Install OpenClaw: npm install -g openclaw
6. Configure environment: export CLAUDECODE=1

Created: $(Get-Date)
"@

$TestInfo | Out-File -FilePath "claude-code-test-info.txt" -Encoding UTF8

Write-Host "Instance info saved to: claude-code-test-info.txt" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Ready to test? SSH in and authenticate Claude Code CLI!" -ForegroundColor Blue