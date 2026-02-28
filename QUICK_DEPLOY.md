# Quick Deploy Guide

## 🚀 Deploy in 3 Steps

### 1. Set up credentials
```bash
cp .env.example .env
# Edit .env with your actual credentials
```

### 2. Run deployment
```bash
./scripts/deploy-from-env.ps1
```

### 3. Start your OpenClaw instance
- Visit the Control Panel URL provided after deployment
- Click "Start Instance" 
- Connect via WhatsApp/Telegram

## 📋 What You Need

- **AWS credentials** (Access Key + Secret)
- **Anthropic API key** (`sk-ant-...`)
- **GitHub token** (`ghp_...`)
- **Your email** (for alerts)

## 💰 Cost: $14.75/month base

## 📚 Need Help?

- **Complete setup:** `docs/setup/SETUP_WITH_ENV.md`
- **Architecture details:** `docs/architecture/GITOPS_ARCHITECTURE.md`
- **Cost breakdown:** `docs/cost/GITOPS_COST_BREAKDOWN.md`
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`

## 🎯 What Happens

Your deployment creates:
- AWS EC2 instance (cost-optimized, scheduled)
- GitHub Actions deployment pipeline
- WhatsApp/Telegram integration
- Cost monitoring and alerts

**Result:** 24/7 AI development assistant via messaging! 🦞💪