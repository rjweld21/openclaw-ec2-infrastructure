# Quick Start Guide

Get OpenClaw GitOps Edition running on AWS in under 15 minutes.

## 🚀 Preferred Method: Deploy with .env File

For secure credential management, use the new `.env` approach:

1. **Copy the template:**
   ```powershell
   copy .env.example .env
   ```

2. **Fill in your credentials** in `.env` file
3. **Deploy:**
   ```powershell
   .\deploy-from-env.ps1
   ```

See **[SETUP_WITH_ENV.md](SETUP_WITH_ENV.md)** for detailed instructions.

---

## 🔧 Alternative: Manual Parameter Method

## Prerequisites (5 minutes)

### 1. AWS Account Setup
- AWS account with billing enabled
- AWS CLI installed and configured
- EC2 key pair in your target region

### 2. Get Your Anthropic API Key
1. Visit [Anthropic Console](https://console.anthropic.com/)
2. Sign in or create account
3. Go to API Keys → Create Key
4. Copy the key (starts with `sk-ant-`)

### 3. Install SSM Session Manager Plugin
**macOS:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"
sudo installer -pkg session-manager-plugin.pkg -target /
```

**Windows:**
Download and install from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

**Linux:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

## Deploy (8 minutes)

### Step 1: Clone and Deploy
```bash
git clone https://github.com/YOUR_USERNAME/openclaw-aws-personal.git
cd openclaw-aws-personal

# Make scripts executable
chmod +x deploy.sh uninstall.sh

# Deploy (replace with your values)
./deploy.sh openclaw-personal us-east-1 my-key-pair sk-ant-api03-your-key-here
```

### Step 2: Wait for Deployment
- Takes ~8 minutes to complete
- Monitor in AWS CloudFormation console
- Script shows progress dots

### Step 3: Save Important URLs
At the end, you'll get:
- **Control Panel URL**: For starting/stopping instance
- **Port Forward Command**: For accessing OpenClaw
- **OpenClaw URL**: http://localhost:18789 (after port forwarding)

## First Use (2 minutes)

### Step 1: Start Your Instance
1. Open the Control Panel URL in your browser
2. Click "🚀 Start" button
3. Wait 2-3 minutes for instance to boot

### Step 2: Access OpenClaw
1. Run the port forward command in terminal:
   ```bash
   aws ssm start-session --target i-1234567890abcdef0 --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
   ```
2. Open http://localhost:18789 in browser
3. You should see the OpenClaw interface

### Step 3: Connect WhatsApp (Easiest)
1. In OpenClaw web interface, click "Channels"
2. Click "Add Channel" → "WhatsApp"
3. QR code appears
4. On your phone: WhatsApp → Settings → Linked Devices → Link Device
5. Scan the QR code
6. Send a test message to your WhatsApp number

## Daily Usage

### Starting OpenClaw
- **Automatic**: Runs 8am-8pm weekdays by default  
- **Manual**: Use the Control Panel URL anytime
- **Command line**: `aws ec2 start-instances --instance-ids i-1234567890abcdef0`

### Accessing OpenClaw
1. **Check if running**: Use Control Panel URL
2. **Start port forwarding**: Run the SSM command
3. **Open interface**: http://localhost:18789

### Stopping OpenClaw (Save Money)
- **Automatic**: Stops at 8pm weekdays by default
- **Manual**: Use the Control Panel "⏹️ Stop" button
- **Command line**: `aws ec2 stop-instances --instance-ids i-1234567890abcdef0`

## Common Tasks

### Connect Telegram
1. Message @BotFather on Telegram
2. Send `/newbot`, follow prompts
3. Copy bot token (123456:ABC-DEF...)
4. In OpenClaw: Channels → Add Channel → Telegram → Paste token

### Connect Discord
1. Visit https://discord.com/developers/applications
2. Create New Application → Bot → Add Bot
3. Copy bot token
4. Generate invite URL with Administrator permissions
5. In OpenClaw: Channels → Add Channel → Discord → Paste token

### Change Schedule
Edit the schedule in CloudFormation parameters:
```bash
aws cloudformation update-stack \
  --stack-name openclaw-personal \
  --parameters ParameterKey=StartSchedule,ParameterValue='cron(0 17 ? * MON-FRI *)' \
  --use-previous-template
```

### Check Costs
```bash
# Current month costs
aws ce get-cost-and-usage \
  --time-period Start=2024-02-01,End=2024-03-01 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## Troubleshooting

### Instance Won't Start
1. Check Control Panel status
2. Look at CloudWatch logs in AWS Console
3. Try: `aws ec2 describe-instances --instance-ids i-1234567890abcdef0`

### Can't Access OpenClaw (localhost:18789)
1. Ensure instance is running (Control Panel)
2. Restart port forwarding command
3. Check: `lsof -i :18789` (should show ssh process)

### High AWS Bills
1. Check instance is stopping on schedule
2. Verify in EC2 console
3. Consider smaller instance: `InstanceType=t4g.small`

### OpenClaw Not Responding
1. Connect via SSM: `aws ssm start-session --target i-1234567890abcdef0`
2. Check service: `sudo systemctl status openclaw`
3. Restart service: `sudo systemctl restart openclaw`

## Getting Help

- **Documentation**: README.md, TROUBLESHOOTING.md
- **Health Check**: `./health-check.sh openclaw-personal`
- **GitHub Issues**: [Create issue](../../issues)
- **OpenClaw Community**: https://discord.gg/clawd

## Cost Summary

**Monthly AWS costs (~$15 for 12hrs/day):**
- EC2 t4g.medium: $12.10
- EBS 30GB: $2.40
- Lambda/S3/etc: $1.00

**Plus your existing Anthropic API usage**

## Next Steps

Once you have the basics working:

1. **Optimize costs**: See COST_OPTIMIZATION.md
2. **Set up more platforms**: Slack, Discord, etc.
3. **Explore OpenClaw features**: Skills, automation, browser control
4. **Backup your config**: `tar -czf openclaw-backup.tar.gz ~/.openclaw`

## Uninstall

When you're done experimenting:
```bash
./uninstall.sh openclaw-personal us-east-1
```

This permanently deletes everything and stops all charges.

---

**Total time from zero to chatting with OpenClaw: ~15 minutes** ⏱️

**Monthly cost: ~$15** 💰

**Scalable to your whole team** 👥