# Deployment Checklist

## Prerequisites Required

### 1. AWS CLI Installation & Configuration
**Status: ❌ Not Installed**

**Install AWS CLI:**
```powershell
# Option 1: Using winget (Windows 10+)
winget install Amazon.AWSCLI

# Option 2: Download installer
# Visit: https://aws.amazon.com/cli/
# Download AWSCLIV2.msi and install
```

**Configure AWS CLI:**
```powershell
aws configure
# You'll need:
# - AWS Access Key ID
# - AWS Secret Access Key  
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### 2. Anthropic API Key
**Required:** Your Anthropic API key starting with `sk-ant-`

**Get your API key:**
1. Go to https://console.anthropic.com/
2. Sign in or create account
3. Navigate to API Keys
4. Create a new key
5. Copy the key (starts with `sk-ant-`)

### 3. EC2 Key Pair
**Required:** An EC2 key pair in your target AWS region

**Create key pair:**
```bash
# List existing key pairs
aws ec2 describe-key-pairs --region us-east-1

# Create new key pair if needed
aws ec2 create-key-pair --key-name openclaw-personal-key --region us-east-1
```

### 4. SSM Session Manager Plugin (Optional but Recommended)
**For connecting to EC2 instance**

**Install:**
- Download from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
- Or use the direct links in QUICKSTART.md

## Deployment Command

Once prerequisites are met:

```powershell
# PowerShell (Windows)
.\deploy.ps1 -StackName "openclaw-personal" -Region "us-east-1" -KeyPairName "your-key-name" -AnthropicApiKey "sk-ant-your-key"

# Or Bash (if available)
./deploy.sh openclaw-personal us-east-1 your-key-name sk-ant-your-key
```

## What You Need to Provide

### Required Parameters:
1. **Stack Name**: `openclaw-personal` (suggested)
2. **AWS Region**: `us-east-1` or `us-west-2` (recommended)
3. **EC2 Key Pair Name**: Name of your existing EC2 key pair
4. **Anthropic API Key**: Your `sk-ant-...` key

### Example:
```powershell
.\deploy.ps1 -StackName "openclaw-personal" -Region "us-east-1" -KeyPairName "my-keypair" -AnthropicApiKey "sk-ant-api03-ABC123..."
```

## Estimated Setup Time

- **If AWS CLI already configured**: 10 minutes
- **If starting from scratch**: 20 minutes
  - Install AWS CLI: 5 minutes
  - Configure credentials: 5 minutes
  - Deploy stack: 8-10 minutes

## Cost Estimate

**Monthly AWS costs:**
- **With default schedule** (8am-8pm weekdays): ~$15.50/month
- **Always-on**: ~$27.50/month
- **8 hours/day only**: ~$11/month

**Plus your existing Anthropic API usage**

## Post-Deployment

You'll receive:
1. **Control Panel URL** - Web interface to start/stop instance
2. **SSM Port Forward Command** - To connect to OpenClaw
3. **OpenClaw URL** - http://localhost:18789 (after port forwarding)

## Need Help?

- **Quick Start**: See QUICKSTART.md
- **Troubleshooting**: See TROUBLESHOOTING.md  
- **Cost Optimization**: See COST_OPTIMIZATION.md

---

**Ready to deploy?** Ensure all prerequisites above are met, then run the deployment command.