# OpenClaw GitOps Edition

Deploy your personal AI development assistant to AWS with professional GitOps workflow.

## 🚀 Quick Start

1. **Set up credentials:**
   ```bash
   cp .env.example .env
   # Edit .env with your AWS/Anthropic/GitHub credentials
   ```

2. **Deploy:**
   ```bash
   ./scripts/deploy-from-env.ps1
   ```

3. **Start coding via WhatsApp!**

## 💰 Cost: $14.75/month base + pay-per-app

## 📁 Repository Structure

```
├── 📄 README.md                 # You are here
├── 📄 .env.example              # Credential template  
├── 📁 scripts/                  # Deployment & setup scripts
├── 📁 templates/                # CloudFormation templates
├── 📁 docs/                     # All documentation
│   ├── 📁 setup/                # Setup guides
│   ├── 📁 architecture/         # Technical details  
│   └── 📁 cost/                 # Cost analysis
└── 📁 web/                      # Control panel
```

## 📋 Essential Files

| File | Purpose |
|------|---------|
| `.env.example` | Template for your secrets (copy to `.env`) |
| `scripts/deploy-from-env.ps1` | **Main deployment script** |
| `docs/setup/SETUP_WITH_ENV.md` | **Complete setup guide** |
| `docs/architecture/GITOPS_ARCHITECTURE.md` | Technical architecture |
| `docs/cost/GITOPS_COST_BREAKDOWN.md` | Detailed cost analysis |

## 🏗️ Architecture: GitOps (Secure!)

- **OpenClaw generates code** via WhatsApp/Telegram
- **GitHub Actions deploy** to AWS (no direct AWS access from EC2)
- **Pay-per-app model** - only pay for what you deploy
- **Industry-standard security** practices

## 🎯 What You Get

- 24/7 AI development assistant via messaging
- Unlimited project generation and deployment  
- Professional CI/CD workflows
- Cost monitoring and alerts
- Bulletproof security controls

## 📚 Documentation

- **New here?** Start with `docs/setup/SETUP_WITH_ENV.md`
- **Want details?** See `docs/architecture/GITOPS_ARCHITECTURE.md`  
- **Curious about costs?** Check `docs/cost/GITOPS_COST_BREAKDOWN.md`
- **Having issues?** Read `docs/TROUBLESHOOTING.md`

## 🔐 Security

Your `.env` file contains secrets and is **git-ignored**. All AWS deployments happen via GitHub Actions with audit trails.

---

**Ready to deploy your AI development assistant?** Follow the Quick Start above! 🦞💪