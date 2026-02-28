# OpenClaw GitOps - Setup with .env File

## 🔐 Secure Credential Management

This setup uses a `.env` file to store your credentials securely, separate from the git repository.

## 📋 Quick Setup Steps

### 1. Create Your .env File
```powershell
# Copy the example file
copy .env.example .env
```

### 2. Edit .env File
Open `.env` in any text editor and fill in your credentials:

```bash
# AWS Configuration (get from AWS Console)
AWS_ACCESS_KEY_ID=AKIA...your_actual_key
AWS_SECRET_ACCESS_KEY=your_actual_secret_key
AWS_REGION=us-east-1

# OpenClaw Configuration
ANTHROPIC_API_KEY=sk-ant-...your_actual_key
GITHUB_TOKEN=ghp_...your_actual_token

# Deployment Settings
STACK_NAME=openclaw-gitops
KEY_PAIR_NAME=openclaw-key
ALERT_EMAIL=your-email@example.com
```

### 3. Deploy
```powershell
# Simple deployment - reads everything from .env
.\deploy-from-env.ps1
```

That's it! 🚀

---

## 🔑 How to Get Your Credentials

### AWS Credentials
1. Go to [AWS Console](https://console.aws.amazon.com)
2. Click your name (top right) → Security credentials
3. Scroll to "Access keys" → Create access key
4. Choose "Command Line Interface (CLI)"
5. Copy the **Access Key ID** and **Secret Access Key**

### Anthropic API Key
1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign up/login
3. Go to API Keys section
4. Create a new key
5. Copy the key (starts with `sk-ant-`)

### GitHub Personal Access Token
1. Go to [GitHub Settings](https://github.com/settings/tokens)
2. Generate new token → "Classic"
3. Select scopes:
   - `repo` (Full repository access)
   - `workflow` (GitHub Actions)
4. Copy the token (starts with `ghp_`)

---

## 🛡️ Security Features

### What's Protected:
- ✅ `.env` file is **git-ignored** (never committed)
- ✅ Credentials stored locally only
- ✅ PowerShell script validates all values
- ✅ AWS keys only used during deployment

### What Gets Created:
- ✅ **Key pair auto-created** if it doesn't exist
- ✅ **Minimal EC2 permissions** (can't create expensive resources)
- ✅ **GitHub token stored** in AWS Parameter Store (encrypted)

---

## 📊 Deployment Process

When you run `.\deploy-from-env.ps1`:

1. **Validates .env file** - Checks all required values
2. **Tests AWS credentials** - Confirms access to your account
3. **Checks key pair** - Creates one if needed
4. **Tests GitHub token** - Verifies repo access
5. **Deploys CloudFormation** - Creates all AWS resources
6. **Saves info** - Creates deployment-info.txt with details

---

## 🎯 Example .env File (Filled Out)

```bash
# AWS Configuration
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY
AWS_REGION=us-east-1

# OpenClaw Configuration  
ANTHROPIC_API_KEY=sk-ant-api03-1234567890abcdef1234567890abcdef1234567890abcdef12
GITHUB_TOKEN=ghp_1234567890abcdef1234567890abcdef12345678

# Deployment Settings
STACK_NAME=my-openclaw-gitops
KEY_PAIR_NAME=my-openclaw-key
ALERT_EMAIL=john@example.com

# Optional (uncomment to customize)
# INSTANCE_TYPE=t4g.small
# SCHEDULE_START=09:00
# SCHEDULE_STOP=18:00
```

---

## 🔧 Deployment Commands

### Standard Deployment
```powershell
# Uses .env file in current directory
.\deploy-from-env.ps1
```

### Custom .env Location
```powershell
# Use a different .env file
.\deploy-from-env.ps1 -EnvFile "my-custom.env"
```

---

## ✅ Validation Checklist

The script validates:
- ✅ `.env` file exists
- ✅ All required variables present
- ✅ API keys have correct format
- ✅ AWS credentials work
- ✅ GitHub token has proper permissions

---

## 🚨 Troubleshooting

### "Environment file not found"
```powershell
# Make sure you copied the example
copy .env.example .env
# Then edit .env with your actual values
```

### "Invalid API key format"
```bash
# Anthropic keys must start with sk-ant-
ANTHROPIC_API_KEY=sk-ant-your_actual_key_here

# GitHub tokens must start with ghp_
GITHUB_TOKEN=ghp_your_actual_token_here
```

### "AWS credentials invalid"
- Double-check your Access Key ID and Secret Key
- Make sure they're from the same AWS account
- Try running: `aws sts get-caller-identity`

---

## 🎉 After Deployment

Once successful, you'll see:
- ✅ **Control Panel URL** - Start/stop your instance
- ✅ **Instance ID** - Your EC2 instance
- ✅ **SSM Command** - Secure connection method
- ✅ **Cost estimate** - $14.75/month base

**Your credentials stay secure locally, never committed to git!** 🔐

---

## 📁 File Structure

```
openclaw-aws-personal/
├── .env                 # Your secrets (git-ignored) ✋
├── .env.example         # Template file ✅
├── deploy-from-env.ps1  # New deployment script ✅
├── .gitignore           # Protects your .env ✅
└── deployment-info.txt  # Created after deploy ✅
```

**Ready to deploy your secure GitOps OpenClaw!** 🦞🚀