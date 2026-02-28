# Changelog

All notable changes from the original [sample-OpenClaw-on-AWS-with-Bedrock](https://github.com/aws-samples/sample-OpenClaw-on-AWS-with-Bedrock) project.

## Personal Edition vs Original Bedrock Version

### Major Changes

#### ✅ Removed - Bedrock Dependencies
- **Removed**: Amazon Bedrock API integration
- **Removed**: Bedrock IAM policies and permissions
- **Removed**: Bedrock model configuration
- **Added**: Direct Anthropic API key support via Parameter Store
- **Added**: Standard OpenClaw npm installation (not Bedrock-specific)

#### ✅ Added - Cost Optimization Features
- **Added**: Automated start/stop scheduling (8am-8pm weekdays by default)
- **Added**: Auto-idle shutdown after 30 minutes of low CPU
- **Added**: t4g instance types (Graviton ARM) for better price/performance
- **Added**: Configurable instance types (t4g.small/medium/large)
- **Added**: Optional spot instance support (in documentation)
- **Removed**: VPC endpoints (saves $22/month)
- **Removed**: NAT Gateway (saves $32/month)

#### ✅ Added - Manual Control Interface
- **Added**: S3-hosted static website for start/stop controls
- **Added**: Lambda Function URLs (free alternative to API Gateway)
- **Added**: Real-time instance status checking
- **Added**: One-click start/stop buttons
- **Added**: Mobile-responsive control interface

#### ✅ Added - Automation & Scheduling
- **Added**: EventBridge rules for automated start/stop
- **Added**: CloudWatch alarms for idle detection
- **Added**: Lambda functions for instance control
- **Added**: Configurable schedules via CloudFormation parameters

#### ✅ Added - Deployment & Management Tools
- **Added**: Bash deployment script (`deploy.sh`)
- **Added**: PowerShell deployment script (`deploy.ps1`)
- **Added**: Comprehensive uninstall script (`uninstall.sh`)
- **Added**: Health check diagnostic script
- **Added**: Automated web interface configuration
- **Added**: Deployment info logging

#### ✅ Added - Documentation
- **Added**: Cost optimization guide (COST_OPTIMIZATION.md)
- **Added**: Troubleshooting guide (TROUBLESHOOTING.md)
- **Added**: Quick start guide (QUICKSTART.md)
- **Added**: This changelog (CHANGELOG.md)
- **Enhanced**: README with personal edition specifics

### Technical Changes

#### CloudFormation Template (`openclaw-personal.yaml`)

**Infrastructure Changes:**
- Simplified VPC setup (no VPC endpoints)
- Removed Bedrock IAM policies
- Added Parameter Store for API key
- Added Lambda functions for control
- Added S3 bucket for web interface
- Added EventBridge rules for scheduling
- Added CloudWatch alarms for monitoring

**Instance Configuration:**
- Default to Graviton ARM instances (t4g.medium)
- Configurable instance types
- Smaller EBS volume (30GB vs default)
- Modified user data script for standard OpenClaw
- Added CloudWatch agent configuration
- Added systemd service configuration

**Security:**
- Removed Bedrock permissions
- Added Parameter Store read permissions
- Lambda execution role for EC2 control
- CORS-enabled function URLs

#### Web Interface (`web/index.html`)

**Features:**
- Modern responsive design
- Real-time status updates
- Start/Stop buttons with loading states
- Instance information display
- Error handling and user feedback
- Keyboard shortcuts
- Auto-refresh every 30 seconds

**Technical:**
- Pure JavaScript (no dependencies)
- Calls Lambda Function URLs directly
- CORS support
- Mobile-optimized
- Graceful error handling

#### Deployment Scripts

**`deploy.sh` (Bash):**
- Parameter validation
- AWS CLI checks
- Key pair validation
- Progress monitoring
- Web interface configuration
- Comprehensive output

**`deploy.ps1` (PowerShell):**
- Windows compatibility
- Same feature set as Bash version
- PowerShell-native error handling
- Cross-platform JSON parsing

**`uninstall.sh`:**
- Complete resource cleanup
- Safety confirmations
- Orphaned resource detection
- Final cost verification

### Cost Comparison

| Feature | Original | Personal Edition | Savings |
|---------|----------|------------------|---------|
| **Instance Runtime** | 24/7 | 12hrs/day | 50% |
| **VPC Endpoints** | 3x ($22/mo) | None | $22/mo |
| **Instance Type** | x86 | Graviton ARM | 20% |
| **API Costs** | Bedrock markup | Direct Anthropic | Variable |
| **Automation** | Manual | Automated | Operational |

**Total Savings: ~$35-40/month**

### Usage Pattern Changes

#### Original Bedrock Version
- Always-on EC2 instance
- Enterprise-focused
- Multiple model providers via Bedrock
- Complex VPC setup
- Manual infrastructure management
- Higher cost ($50-60/month)

#### Personal Edition
- Scheduled operation (12hrs/day default)
- Individual/small team focused  
- Single API key (your own Anthropic)
- Simplified networking
- Automated management via web interface
- Lower cost (~$15/month)

### Migration Path

To migrate from Bedrock version to Personal edition:

1. **Backup existing config:**
   ```bash
   aws ssm start-session --target <old-instance-id>
   tar -czf ~/openclaw-backup.tar.gz ~/.openclaw
   ```

2. **Deploy Personal edition:**
   ```bash
   ./deploy.sh openclaw-personal us-east-1 my-key sk-ant-...
   ```

3. **Restore config:**
   ```bash
   # On new instance
   tar -xzf openclaw-backup.tar.gz
   # Update config to use Anthropic API key
   ```

4. **Delete old stack:**
   ```bash
   aws cloudformation delete-stack --stack-name old-bedrock-stack
   ```

### Breaking Changes

⚠️ **Not backward compatible with Bedrock version**

- Different CloudFormation template structure
- Different IAM permissions
- Different environment configuration
- Different API provider setup

### Future Enhancements

**Planned:**
- [ ] Spot instance automation
- [ ] Multi-region deployment
- [ ] Container-based deployment option
- [ ] Advanced cost analytics
- [ ] Backup/restore automation

**Community Requests:**
- [ ] Azure deployment version
- [ ] Google Cloud deployment version
- [ ] Docker Compose local version
- [ ] Terraform alternative

### Version History

#### v1.0.0 (2026-02-17)
- Initial Personal Edition release
- Complete rewrite from Bedrock version
- Cost-optimized architecture
- Automated deployment and management
- Comprehensive documentation

---

**Migration from Bedrock version is a complete replacement, not an upgrade.**

**Save your data before switching!**