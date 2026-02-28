# Troubleshooting Guide

This guide helps you diagnose and fix common issues with OpenClaw Personal Edition.

## Quick Diagnostic Commands

```bash
# Check stack status
aws cloudformation describe-stacks --stack-name openclaw-personal --query 'Stacks[0].StackStatus'

# Check instance status
INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name openclaw-personal --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text)
aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name'

# Check OpenClaw service status (when instance is running)
aws ssm start-session --target $INSTANCE_ID
sudo systemctl status openclaw
```

## Common Issues

### 1. Deployment Problems

#### 1.1 "Key pair not found"

**Error:**
```
The key pair 'my-keypair' does not exist
```

**Solution:**
```bash
# List existing key pairs
aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName'

# Create new key pair if needed
aws ec2 create-key-pair --key-name openclaw-personal-key --query 'KeyMaterial' --output text > ~/.ssh/openclaw-personal-key.pem
chmod 400 ~/.ssh/openclaw-personal-key.pem

# Redeploy with correct key name
./deploy.sh openclaw-personal us-east-1 openclaw-personal-key sk-ant-...
```

#### 1.2 "Invalid Anthropic API key"

**Error:**
```
Parameter validation failed: Invalid Anthropic API key format
```

**Solution:**
1. Verify your API key starts with `sk-ant-`
2. Check for extra spaces or characters
3. Get a fresh key from [Anthropic Console](https://console.anthropic.com/)

#### 1.3 "Stack creation failed" 

**Error:**
```
CREATE_FAILED: Resource creation cancelled
```

**Diagnosis:**
```bash
# Check detailed error messages
aws cloudformation describe-stack-events --stack-name openclaw-personal --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' --output table
```

**Common causes and solutions:**

| Error | Solution |
|-------|----------|
| "Insufficient permissions" | Add required IAM permissions to your AWS user |
| "Subnet has no available IP addresses" | Use different availability zone |
| "Instance type not available" | Change instance type in template |
| "Service limit exceeded" | Request limit increase in AWS console |

#### 1.4 "Lambda deployment package too large"

**Error:**
```
Unzipped size must be smaller than 262144000 bytes
```

**Solution:**
The Lambda functions in the CloudFormation template are inline and should be small. This usually indicates a template corruption:

```bash
# Re-download the template
git pull origin main
# Or download fresh copy from GitHub
```

### 2. Instance Won't Start

#### 2.1 Instance starts but immediately stops

**Check CloudWatch logs:**
```bash
# View system logs
aws logs get-log-events --log-group-name "/aws/ec2/openclaw/openclaw-personal" --log-stream-name "system" --limit 50
```

**Common causes:**
- **Out of disk space**: Increase EBS volume size
- **Invalid API key**: Check Parameter Store value
- **Missing dependencies**: User data script failed

**Fix disk space:**
```bash
# Connect to instance
aws ssm start-session --target $INSTANCE_ID

# Check disk usage  
df -h

# Clean up if needed
sudo apt autoremove -y
sudo apt autoclean
docker system prune -f
```

#### 2.2 Instance stuck in "pending" state

**Check instance status:**
```bash
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID
```

**Solutions:**
1. **Wait longer**: Initial boot takes 3-5 minutes
2. **Stop and start** (not reboot):
   ```bash
   aws ec2 stop-instances --instance-ids $INSTANCE_ID
   aws ec2 start-instances --instance-ids $INSTANCE_ID
   ```
3. **Check availability zone capacity**: Try different AZ

#### 2.3 SSM Session Manager fails

**Error:**
```
TargetNotConnected: i-1234567890abcdef0 is not connected
```

**Solutions:**
1. **Wait for SSM agent**: Takes 2-3 minutes after boot
2. **Check IAM role**: Instance must have `AmazonSSMManagedInstanceCore` policy
3. **Install SSM plugin locally**:
   ```bash
   # macOS
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac_arm64/session-manager-plugin.pkg" -o "session-manager-plugin.pkg"
   sudo installer -pkg session-manager-plugin.pkg -target /
   
   # Linux
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
   sudo dpkg -i session-manager-plugin.deb
   ```

### 3. OpenClaw Service Issues

#### 3.1 OpenClaw won't start

**Connect to instance and check:**
```bash
aws ssm start-session --target $INSTANCE_ID
sudo su - openclaw

# Check service status
systemctl status openclaw --no-pager -l

# View recent logs
journalctl -u openclaw --no-pager -l -n 50

# Check config file
cat ~/.openclaw/openclaw.json
```

**Common issues:**

| Error | Solution |
|-------|---------|
| "ENOENT: no such file" | Reinstall OpenClaw: `npm install -g openclaw@latest` |
| "Invalid API key" | Update API key in Parameter Store |
| "Port already in use" | Kill existing process: `pkill -f openclaw` |
| "Permission denied" | Fix ownership: `sudo chown -R openclaw:openclaw /home/openclaw` |

#### 3.2 Config file corrupted

**Regenerate config:**
```bash
# Backup existing
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# Get API key from Parameter Store
API_KEY=$(aws ssm get-parameter --name '/openclaw-personal/anthropic-api-key' --with-decryption --query 'Parameter.Value' --output text)

# Create new config
cat > ~/.openclaw/openclaw.json << EOF
{
  "gateway": {
    "port": 18789,
    "bind": "0.0.0.0",
    "auth": {
      "token": "$(openssl rand -hex 32)"
    }
  },
  "models": {
    "default": "anthropic/claude-sonnet-4-20250514",
    "providers": {
      "anthropic": {
        "apiKey": "$API_KEY"
      }
    }
  }
}
EOF

# Restart service
sudo systemctl restart openclaw
```

### 4. Web Interface Issues

#### 4.1 "Function URLs not working"

**Error in browser:**
```
Failed to fetch
```

**Check Lambda function URLs:**
```bash
# List function URLs
aws lambda list-function-url-configs --query 'FunctionUrlConfigs[*].[FunctionName,FunctionUrl]' --output table

# Test directly
curl -X POST "https://your-function-url.lambda-url.us-east-1.on.aws/"
```

**Solutions:**
1. **CORS issue**: Function URLs have CORS enabled, but check browser dev tools
2. **Function not deployed**: Redeploy stack
3. **Wrong URLs in HTML**: Re-run deployment script to update HTML

#### 4.2 "Control panel shows wrong status"

**The web page shows "running" but instance is stopped**

**Cause**: Browser caching old status

**Solutions:**
1. **Hard refresh**: Ctrl+Shift+R (or Cmd+Shift+R on Mac)
2. **Clear cache**: Browser settings → Clear data
3. **Use incognito/private window**

#### 4.3 "Can't access control panel"

**Error:**
```
This site can't be reached
```

**Check S3 website:**
```bash
# Get S3 bucket name
BUCKET=$(aws cloudformation describe-stacks --stack-name openclaw-personal --query 'Stacks[0].Outputs[?OutputKey==`StartStopPageURL`].OutputValue' --output text | sed 's|https://\([^.]*\)\..*|\1|')

# Check website configuration  
aws s3api get-bucket-website --bucket $BUCKET

# Re-upload HTML if needed
aws s3 cp web/index.html s3://$BUCKET/index.html --content-type "text/html"
```

### 5. Port Forwarding Issues

#### 5.1 "Connection refused" on localhost:18789

**Possible causes:**
1. **Instance not running**: Check control panel
2. **OpenClaw service stopped**: Connect via SSM and restart
3. **Port forwarding not started**: Check your terminal

**Check port forwarding:**
```bash
# In separate terminal, check if forwarding is active
lsof -i :18789

# You should see:
# ssh     12345  user   10u  IPv4  0x...  0t0  TCP localhost:18789 (LISTEN)
```

**Restart port forwarding:**
```bash
# Kill existing connections
pkill -f "18789"

# Start fresh
aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
```

#### 5.2 "Session terminated" during port forwarding

**Common causes:**
- **Instance stopped**: Use control panel to start
- **Network timeout**: Restart session
- **SSM limits**: AWS limits concurrent sessions

**Solutions:**
```bash
# Check active sessions
aws ssm describe-sessions --state Active

# Terminate old sessions if needed
aws ssm terminate-session --session-id ses-1234567890abcdef0

# Start new session
aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
```

### 6. Cost Issues

#### 6.1 "Unexpected high bills"

**Investigate costs:**
```bash
# Get cost breakdown for last 30 days  
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-02-01 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' \
  --output table
```

**Common cost drivers:**

| Service | Cause | Solution |
|---------|--------|----------|
| EC2-Instance | Instance not stopping | Check scheduled stop rules |
| EC2-EBS | Large volume | Reduce volume size or use snapshots |
| VPC-NatGateway | NAT gateway created | This template doesn't use NAT |
| Lambda | Too many invocations | Check Lambda logs for errors |

#### 6.2 "Instance won't stop on schedule" 

**Check EventBridge rules:**
```bash
# List rules
aws events list-rules --name-prefix "openclaw"

# Check rule details
aws events describe-rule --name "openclaw-personal-stop-schedule"

# Check targets
aws events list-targets-by-rule --rule "openclaw-personal-stop-schedule"
```

**Test stop function manually:**
```bash
# Get stop function URL from outputs
STOP_URL=$(aws cloudformation describe-stacks --stack-name openclaw-personal --query 'Stacks[0].Outputs[?OutputKey==`StopFunctionURL`].OutputValue' --output text)

# Test it
curl -X POST "$STOP_URL"
```

### 7. OpenClaw Configuration Issues

#### 7.1 "Can't connect messaging platforms"

**WhatsApp won't connect:**
1. **QR code expired**: Refresh the OpenClaw web page
2. **Phone not on internet**: Check WhatsApp on phone
3. **Already linked to 5 devices**: Unlink an old device
4. **Wrong number**: Use WhatsApp Business for dedicated number

**Telegram bot not responding:**
```bash
# Check bot configuration
curl -X GET "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getMe"

# Check webhook (should be empty for long polling)
curl -X GET "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getWebhookInfo"
```

#### 7.2 "OpenClaw responds but API errors"

**Check Anthropic API key:**
```bash
# Test API key directly
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"claude-3-sonnet-20240229","messages":[{"role":"user","content":"Hello"}]}' \
     https://api.anthropic.com/v1/messages
```

**Update API key in Parameter Store:**
```bash
aws ssm put-parameter \
  --name "/openclaw-personal/anthropic-api-key" \
  --value "sk-ant-new-key-here" \
  --type SecureString \
  --overwrite

# Restart OpenClaw service
aws ssm start-session --target $INSTANCE_ID
sudo systemctl restart openclaw
```

## Diagnostic Scripts

### Health Check Script

Save as `health-check.sh`:
```bash
#!/bin/bash
STACK_NAME=${1:-openclaw-personal}

echo "🔍 OpenClaw Health Check"
echo "========================"

# Check stack
echo -n "Stack status: "
aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "❌ NOT FOUND"

# Check instance
INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text 2>/dev/null)
if [ -n "$INSTANCE_ID" ]; then
    echo -n "Instance status: "
    aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null
    
    echo -n "SSM connectivity: "
    aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "❌ NOT CONNECTED"
fi

# Check Lambda functions
echo -n "Lambda functions: "
FUNCTIONS=$(aws lambda list-functions --query "Functions[?starts_with(FunctionName, \`$STACK_NAME\`)].FunctionName" --output text | wc -w)
echo "$FUNCTIONS/3 deployed"

echo "========================"
echo "Run with: ./health-check.sh [stack-name]"
```

### Log Analyzer

Save as `analyze-logs.sh`:
```bash
#!/bin/bash
STACK_NAME=${1:-openclaw-personal}
INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text)

echo "📋 Recent OpenClaw Logs"
echo "======================="

# System logs
echo "System logs:"
aws logs get-log-events \
  --log-group-name "/aws/ec2/openclaw/$STACK_NAME" \
  --log-stream-name "system" \
  --limit 20 \
  --query 'events[*].[timestamp,message]' \
  --output table 2>/dev/null || echo "No system logs found"

echo -e "\nLambda logs:"
for func in start-instance stop-instance check-status; do
    echo "- $func:"
    aws logs get-log-events \
      --log-group-name "/aws/lambda/$STACK_NAME-$func" \
      --log-stream-name "$(aws logs describe-log-streams --log-group-name "/aws/lambda/$STACK_NAME-$func" --query 'logStreams[0].logStreamName' --output text)" \
      --limit 5 \
      --query 'events[-1].message' \
      --output text 2>/dev/null || echo "  No logs"
done
```

## Getting Help

### Self-Service Options

1. **Check logs first**: Most issues show up in CloudWatch logs
2. **Use health-check script**: Quick overview of system status
3. **Test components individually**: Lambda functions, instance, OpenClaw service
4. **Compare with working config**: Use the default template values

### Escalation

If you can't resolve the issue:

1. **Gather information**:
   ```bash
   # Create support bundle
   ./health-check.sh > support-bundle.txt
   ./analyze-logs.sh >> support-bundle.txt
   aws cloudformation describe-stacks --stack-name openclaw-personal >> support-bundle.txt
   ```

2. **GitHub Issues**: [Create an issue](../../issues) with:
   - Error message (exact text)
   - Steps to reproduce  
   - Support bundle (redact sensitive info)
   - Your AWS region and instance type

3. **OpenClaw Community**: 
   - [OpenClaw Discord](https://discord.gg/clawd)
   - [OpenClaw GitHub](https://github.com/openclaw/openclaw/issues)

### Emergency Reset

If everything is broken and you need to start fresh:

```bash
# Delete the entire stack
aws cloudformation delete-stack --stack-name openclaw-personal

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name openclaw-personal

# Redeploy from scratch
./deploy.sh openclaw-personal us-east-1 your-key your-api-key
```

⚠️ **Warning**: This deletes all data and configuration. Only use as last resort.