# OpenClaw + Claude Code CLI on EC2 - Test Plan

## 🎯 Goal
Replicate your local OpenClaw setup (using Claude Code CLI backend) on EC2 to leverage your $200/month subscription instead of paying per-token API costs.

## 💰 Expected Savings
- Your approach: $200 (subscription) + $15 (EC2) = **$215/month**
- API approach: $200 + $15 + $500+ (API costs) = **$715+/month**
- **Savings: $500+/month** 🎉

## 🔍 Current Local Setup Analysis
Based on your environment:
- `CLAUDE_CODE_ENTRYPOINT: cli` ✅
- `CLAUDECODE: 1` ✅ 
- OpenClaw → Claude Code CLI → Your $200/month subscription

## 📋 Test Phase Plan

### Phase 1: Quick Authentication Test (30 minutes)
1. Deploy basic Ubuntu EC2 instance
2. Install Claude Code CLI 
3. Test authentication with your subscription
4. Verify Claude access works

### Phase 2: OpenClaw Integration (1 hour)
1. Install OpenClaw on EC2
2. Configure environment variables to match your local setup
3. Test OpenClaw → Claude Code CLI pipeline
4. Verify same response quality/speed

### Phase 3: Full Integration (2 hours)
1. Add WhatsApp/Telegram messaging
2. Configure GitHub automation
3. Set up scheduled start/stop
4. Performance testing with heavy usage

## 🔧 Technical Requirements

### EC2 Instance Specs
- **Type:** t3.medium (2 vCPU, 4GB RAM)
- **OS:** Ubuntu 22.04 LTS
- **Storage:** 30GB gp3
- **Security:** SSH access, HTTP/HTTPS for messaging webhooks

### Software Stack
- Claude Code CLI (latest)
- OpenClaw (configured for Claude Code backend)
- Node.js runtime
- WhatsApp/Telegram webhook handlers
- GitHub CLI for automation

### Environment Variables (Critical)
```bash
CLAUDECODE=1
CLAUDE_CODE_ENTRYPOINT=cli
# Plus authentication tokens from your local setup
```

## 🚀 Deployment Options

### Option A: Manual Setup (Test First)
- Quick EC2 instance
- Manual software installation
- Test authentication process
- Validate concept

### Option B: CloudFormation (Production)
- Comprehensive infrastructure
- Automated software installation
- Scheduled operations
- Full monitoring

## ✅ Success Criteria
1. **Authentication works:** Can authenticate Claude Code CLI with your subscription
2. **OpenClaw integration:** OpenClaw successfully uses Claude Code backend
3. **Performance match:** Similar response speed/quality as local
4. **Cost control:** No per-token charges, only subscription
5. **Messaging works:** WhatsApp/Telegram integration functional
6. **GitHub automation:** Can create repos, commit code, etc.

## 🧪 Testing Checklist
- [ ] EC2 instance deployed and accessible
- [ ] Claude Code CLI installed and authenticated
- [ ] OpenClaw installed and configured
- [ ] Environment variables set correctly
- [ ] Test conversation works (like this one!)
- [ ] WhatsApp integration functional
- [ ] GitHub automation working
- [ ] Scheduled start/stop operational
- [ ] Cost monitoring in place

## 🔍 Troubleshooting Points
1. **Authentication:** May need SSH port forwarding for initial Claude Code login
2. **Session persistence:** Ensure authentication persists across reboots
3. **Performance:** Monitor if EC2 resources are sufficient for heavy usage
4. **Networking:** Security groups for messaging webhooks

---

**Ready to start Phase 1 testing?** 🚀