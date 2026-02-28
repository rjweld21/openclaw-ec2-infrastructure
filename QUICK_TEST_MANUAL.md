# 🧪 Quick Manual Test - OpenClaw + Claude Code CLI on EC2

## 🎯 Goal: Prove the $500/month savings concept!

**Your Approach:** Use existing $200/month subscription instead of per-token API costs

---

## 🚀 **5-Minute Manual Test (While Sub-Agents Work)**

### **Step 1: Launch EC2 via AWS Console (2 minutes)**
1. Go to [AWS Console → EC2 → Launch Instance](https://console.aws.amazon.com/ec2/)
2. **AMI:** Ubuntu 22.04 LTS (search "ubuntu 22.04")
3. **Instance Type:** t3.medium  
4. **Key Pair:** Create new "openclaw-test" (download .pem file)
5. **Security Group:** Default (ensure SSH port 22 allowed)
6. **Tags:** Name = "OpenClaw-Claude-Test"
7. **Launch!**

### **Step 2: SSH and Basic Setup (2 minutes)**
```bash
# SSH into your instance (replace with your .pem file and IP)
ssh -i openclaw-test.pem ubuntu@YOUR_PUBLIC_IP

# Update and install Node.js
sudo apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs git curl

# Verify
node --version
npm --version
```

### **Step 3: Install Claude Code CLI (1 minute)**
```bash
# Try official install
npm install -g @anthropic-ai/claude-cli

# Or try alternative
curl -L https://claude.ai/claude-code/install.sh | bash

# Check installation
claude --version
```

### **Step 4: Authentication Test (CRITICAL)**
```bash
# Authenticate with your $200/month subscription
claude auth login

# Follow the prompts - this is the KEY test!
# If this works with your subscription → HUGE WIN!

# Test basic chat
claude chat "Hello, can you respond?"
```

---

## 💡 **Expected Results:**

### **✅ SUCCESS Case:**
- Claude Code CLI authenticates with your subscription
- Can chat without API charges
- **Savings: $500+/month confirmed!** 🎉

### **❌ CHALLENGE Case:**
- Authentication issues on headless server
- Need SSH port forwarding or alternative method
- **Sub-agents will solve this!** 🤖

---

## 🎯 **While You Test:**

The **Opus sub-agents** are building:
- **CloudFormation template** for full automation
- **Authentication procedures** for reliable setup
- **OpenClaw integration** with all features

---

## 📞 **Next Steps Based on Test:**

### **If Manual Test Works:**
- Install OpenClaw: `npm install -g openclaw`
- Set environment: `export CLAUDECODE=1`
- Configure WhatsApp/GitHub integration
- **Deploy production version!**

### **If Authentication Fails:**
- Wait for **Authentication Expert** sub-agent
- They're working on advanced auth transfer methods
- Alternative approaches for server deployment

---

**🚀 Ready to start the 5-minute test?** This will prove whether your brilliant $500/month savings idea works!