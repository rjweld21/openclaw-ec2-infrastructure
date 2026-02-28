# RJ's OpenClaw Setup Guide

**Goal:** Get your personal OpenClaw running on AWS for ~$15/month in 30 minutes.

**Your Environment:** Windows 11, PowerShell, Eastern Time

---

## Step 1: Install AWS CLI (5 minutes)

**Open PowerShell as Administrator and run:**

```powershell
# Install AWS CLI via winget (Windows 10/11)
winget install Amazon.AWSCLI

# Close and reopen PowerShell (or restart terminal)
# Verify installation
aws --version
```

**Alternative if winget fails:**
1. Go to https://aws.amazon.com/cli/
2. Download "AWS CLI MSI installer for Windows (64-bit)"
3. Run the installer
4. Restart PowerShell

---

## Step 2: Get Your AWS Credentials (5 minutes)

**You need two things from AWS Console:**

### A. Get Access Keys
1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click your username (top right) → "Security credentials"
3. Scroll to "Access keys" → "Create access key"
4. Choose "Command Line Interface (CLI)"
5. Add description: "OpenClaw CLI access"
6. **Copy both keys** (you'll need them in Step 3)

### B. Choose Region
**Recommended:** `us-east-1` (cheapest) or `us-west-2` (if you're West Coast)

---

## Step 3: Configure AWS CLI (2 minutes)

**In PowerShell, run:**

```powershell
aws configure
```

**Enter when prompted:**
- **AWS Access Key ID:** `[paste from Step 2A]`
- **AWS Secret Access Key:** `[paste from Step 2A]`
- **Default region:** `us-east-1`
- **Default output format:** `json`

**Verify it works:**
```powershell
aws sts get-caller-identity
# Should show your account info
```

---

## Step 4: Create EC2 Key Pair (2 minutes)

**Run this command:**
```powershell
# Create key pair (saves .pem file to your home directory)
aws ec2 create-key-pair --key-name "openclaw-key" --region us-east-1 --query 'KeyMaterial' --output text | Out-File -FilePath "$env:USERPROFILE\.ssh\openclaw-key.pem" -Encoding ascii

# Create .ssh directory if it doesn't exist
New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force
```

**Your key pair name is:** `openclaw-key`

---

## Step 5: Get Anthropic API Key (3 minutes)

1. Go to https://console.anthropic.com/
2. Sign in (or create account if you don't have one)
3. Click "API Keys" in the sidebar
4. Click "Create Key"
5. Name it "OpenClaw Personal"
6. **Copy the key** - it starts with `sk-ant-api03-...`

⚠️ **Important:** This key gives access to your Anthropic account. Keep it secure!

---

## Step 6: Deploy OpenClaw (8 minutes)

**Navigate to your repository:**
```powershell
cd C:\Users\rjwel\.openclaw\workspace\openclaw-aws-personal
```

**Deploy with your values:**
```powershell
.\deploy.ps1 -StackName "openclaw-personal" -Region "us-east-1" -KeyPairName "openclaw-key" -AnthropicApiKey "sk-ant-YOUR-KEY-HERE"
```

**Replace `sk-ant-YOUR-KEY-HERE` with your actual Anthropic API key from Step 5.**

**What happens:**
- Takes ~8 minutes to complete
- Shows progress dots while building
- Creates all AWS resources
- Configures OpenClaw with your API key
- Sets up automated scheduling (8am-8pm weekdays)

---

## Step 7: Access Your OpenClaw (5 minutes)

**After deployment completes, you'll get:**

### A. Control Panel URL
- Bookmark this URL - it's your start/stop interface
- Example: `https://openclaw-personal-startstop-123456.s3.amazonaws.com/index.html`

### B. Start Your Instance
1. Open the Control Panel URL
2. Click "🚀 Start" button  
3. Wait 2-3 minutes for boot

### C. Connect to OpenClaw
1. **Copy the port forward command** from deployment output
2. **Paste and run in PowerShell** (keep this window open):
   ```powershell
   aws ssm start-session --target i-1234567890abcdef0 --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
   ```
3. **Open browser:** http://localhost:18789
4. **You should see OpenClaw interface!**

---

## Step 8: Connect WhatsApp (5 minutes)

**In OpenClaw web interface:**
1. Click "Channels" → "Add Channel" → "WhatsApp"
2. QR code appears
3. **On your phone:** WhatsApp → Settings → Linked Devices → "Link a Device"
4. **Scan QR code**
5. **Test:** Send message to your WhatsApp number - OpenClaw should respond!

---

## Your Daily Workflow

### Starting OpenClaw
- **Automatic:** Runs 8am-8pm Eastern, weekdays
- **Manual:** Use your Control Panel URL anytime

### Using OpenClaw  
1. **Check status:** Open Control Panel URL
2. **If running:** Run port forward command → Open http://localhost:18789
3. **Chat:** WhatsApp, or web interface, or add Telegram/Discord

### Stopping (Saves Money)
- **Automatic:** Stops 8pm Eastern weekdays
- **Manual:** Control Panel → "⏹️ Stop" button

---

## Cost Summary

**Your monthly AWS bill:** ~$15.50
- EC2 (12 hrs/day): $12.10
- Storage: $2.40  
- Other: $1.00

**Plus:** Your normal Anthropic API usage (same as local)

**vs. ChatGPT Plus:** $20/month, but this is unlimited usage + full automation

---

## Bookmarks to Save

**After deployment, bookmark these:**
1. **Control Panel:** Your S3 URL for start/stop
2. **OpenClaw:** http://localhost:18789 (when port forwarding)
3. **AWS Console:** https://console.aws.amazon.com/cloudformation/ (to monitor)

---

## Need Help?

**Common issues:**
- **Can't access localhost:18789?** Restart the port forward command
- **Instance won't start?** Check Control Panel status, might take 3-4 minutes
- **High costs?** Check instance is stopping on schedule in Control Panel

**Docs in this repo:**
- `TROUBLESHOOTING.md` - Fix common problems
- `COST_OPTIMIZATION.md` - Reduce costs further
- `README.md` - Full documentation

**Get support:**
- [OpenClaw Discord](https://discord.gg/clawd)
- [GitHub Issues](https://github.com/openclaw/openclaw/issues)

---

## Quick Commands Reference

```powershell
# Check AWS connection
aws sts get-caller-identity

# Check instance status  
aws ec2 describe-instances --region us-east-1 --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

# Emergency stop instance
aws ec2 stop-instances --instance-ids i-YOUR-INSTANCE-ID --region us-east-1

# Delete everything (if you want to uninstall)
.\uninstall.sh openclaw-personal us-east-1
```

---

## Success Checklist

- [ ] AWS CLI installed and configured
- [ ] EC2 key pair created (`openclaw-key`)
- [ ] Anthropic API key obtained
- [ ] OpenClaw deployed successfully 
- [ ] Control Panel bookmarked
- [ ] WhatsApp connected and responding
- [ ] Port forwarding working (localhost:18789)

---

**🎉 You're done! Welcome to your personal cloud AI assistant for $15/month!**

**Questions?** Everything you need is in this repository's documentation. The setup is production-ready and will auto-manage itself.

---

*Total setup time: ~30 minutes*  
*Monthly cost: ~$15*  
*Coolness factor: 🦞🦞🦞*