#!/bin/bash

# OpenClaw Personal Edition - Setup Script
# Prepares the repository for deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🦞 OpenClaw Personal Edition - Setup"
echo "====================================="
echo

# Check if we're in the right directory
if [ ! -f "openclaw-personal.yaml" ]; then
    print_error "openclaw-personal.yaml not found"
    print_status "Please run this script from the repository root directory"
    exit 1
fi

print_status "Setting up OpenClaw Personal Edition..."

# Make scripts executable
print_status "Making scripts executable..."
chmod +x deploy.sh
chmod +x uninstall.sh
chmod +x setup.sh

# Create scripts directory if it doesn't exist
if [ ! -d "scripts" ]; then
    print_status "Creating scripts directory..."
    mkdir scripts
fi

# Create health check script
print_status "Creating health check script..."
cat > scripts/health-check.sh << 'EOF'
#!/bin/bash

# OpenClaw Personal Edition - Health Check Script

STACK_NAME=${1:-openclaw-personal}
REGION=${2:-$(aws configure get region)}

echo "🔍 OpenClaw Health Check"
echo "========================"
echo "Stack: $STACK_NAME"
echo "Region: $REGION"
echo

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed"
    exit 1
fi

# Check credentials
echo -n "AWS credentials: "
if aws sts get-caller-identity --region $REGION &>/dev/null; then
    echo "✅ Valid"
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    echo "   Account: $ACCOUNT_ID"
else
    echo "❌ Invalid or not configured"
    echo "   Run: aws configure"
    exit 1
fi

# Check SSM plugin
echo -n "SSM Session Manager Plugin: "
if session-manager-plugin --version &>/dev/null; then
    echo "✅ Installed"
else
    echo "❌ Not installed"
    echo "   Install from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
fi

# Check stack status
echo -n "CloudFormation stack: "
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")
echo "$STACK_STATUS"

if [ "$STACK_STATUS" != "NOT_FOUND" ]; then
    # Get instance info
    INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text 2>/dev/null)
    
    if [ -n "$INSTANCE_ID" ]; then
        echo -n "EC2 instance: "
        INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
        echo "$INSTANCE_STATE ($INSTANCE_ID)"
        
        if [ "$INSTANCE_STATE" = "running" ]; then
            echo -n "SSM connectivity: "
            SSM_STATUS=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --region $REGION --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "UNKNOWN")
            echo "$SSM_STATUS"
        fi
    fi
    
    # Check Lambda functions
    echo -n "Lambda functions: "
    FUNCTIONS=$(aws lambda list-functions --region $REGION --query "Functions[?starts_with(FunctionName, \`$STACK_NAME\`)].FunctionName" --output text | wc -w)
    echo "$FUNCTIONS/3 found"
    
    # Check S3 bucket
    echo -n "S3 control page: "
    S3_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`StartStopPageURL`].OutputValue' --output text 2>/dev/null)
    if [ -n "$S3_URL" ]; then
        echo "✅ Available"
        echo "   URL: $S3_URL"
    else
        echo "❌ Not found"
    fi
fi

echo
echo "========================"
echo "Use: ./health-check.sh [stack-name] [region]"
EOF

chmod +x scripts/health-check.sh

# Create log analyzer script
print_status "Creating log analyzer script..."
cat > scripts/analyze-logs.sh << 'EOF'
#!/bin/bash

# OpenClaw Personal Edition - Log Analyzer

STACK_NAME=${1:-openclaw-personal}
REGION=${2:-$(aws configure get region)}

echo "📋 OpenClaw Log Analysis"
echo "========================="
echo "Stack: $STACK_NAME"
echo "Region: $REGION"
echo

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
    echo "❌ Stack '$STACK_NAME' not found in region $REGION"
    exit 1
fi

# Get instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' --output text)

echo "Instance: $INSTANCE_ID"
echo

# System logs
echo "🖥️  System Logs (last 10 entries):"
echo "-----------------------------------"
aws logs get-log-events \
    --log-group-name "/aws/ec2/openclaw/$STACK_NAME" \
    --log-stream-name "system" \
    --limit 10 \
    --region $REGION \
    --query 'events[*].[timestamp,message]' \
    --output table 2>/dev/null || echo "No system logs found"

echo

# Lambda function logs
echo "⚡ Lambda Function Logs:"
echo "-----------------------"
for func_suffix in start-instance stop-instance check-status; do
    FUNC_NAME="$STACK_NAME-$func_suffix"
    echo "📝 $FUNC_NAME:"
    
    # Get latest log stream
    LATEST_STREAM=$(aws logs describe-log-streams \
        --log-group-name "/aws/lambda/$FUNC_NAME" \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --region $REGION \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null)
    
    if [ "$LATEST_STREAM" != "None" ] && [ -n "$LATEST_STREAM" ]; then
        aws logs get-log-events \
            --log-group-name "/aws/lambda/$FUNC_NAME" \
            --log-stream-name "$LATEST_STREAM" \
            --limit 5 \
            --region $REGION \
            --query 'events[*].message' \
            --output text 2>/dev/null | head -5 | sed 's/^/   /'
    else
        echo "   No logs found"
    fi
    echo
done

echo "========================="
echo "Use: ./analyze-logs.sh [stack-name] [region]"
EOF

chmod +x scripts/analyze-logs.sh

# Check prerequisites
print_status "Checking prerequisites..."

# Check for AWS CLI
if command -v aws &> /dev/null; then
    print_success "AWS CLI found"
    AWS_VERSION=$(aws --version 2>&1 | head -n1)
    echo "   Version: $AWS_VERSION"
else
    print_error "AWS CLI not found"
    echo "   Install from: https://aws.amazon.com/cli/"
    echo "   Run: aws configure"
fi

# Check for jq (optional but helpful)
if command -v jq &> /dev/null; then
    print_success "jq found (JSON parsing)"
else
    print_warning "jq not found (optional)"
    echo "   Install for better JSON parsing: brew install jq (macOS) or apt-get install jq (Linux)"
fi

# Check for session-manager-plugin
if session-manager-plugin --version &>/dev/null; then
    print_success "SSM Session Manager Plugin found"
else
    print_error "SSM Session Manager Plugin not found"
    echo "   Required for connecting to EC2 instance"
    echo "   Install from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
fi

# Validate CloudFormation template
print_status "Validating CloudFormation template..."
if aws cloudformation validate-template --template-body file://openclaw-personal.yaml &>/dev/null; then
    print_success "CloudFormation template is valid"
else
    print_error "CloudFormation template validation failed"
    echo "   Check template syntax"
fi

# Check web directory
if [ -d "web" ] && [ -f "web/index.html" ]; then
    print_success "Web interface files found"
else
    print_error "Web interface files missing"
    echo "   Expected: web/index.html"
fi

# Create examples directory
if [ ! -d "examples" ]; then
    print_status "Creating examples directory..."
    mkdir examples
    
    # Create example deployment command
    cat > examples/deploy-example.sh << 'EOF'
#!/bin/bash

# Example deployment - EDIT THESE VALUES
STACK_NAME="openclaw-personal"
REGION="us-east-1"
KEY_PAIR_NAME="my-keypair"  # ← Change this to your EC2 key pair
ANTHROPIC_API_KEY="sk-ant-api03-..."  # ← Change this to your Anthropic API key

# Run deployment
../deploy.sh "$STACK_NAME" "$REGION" "$KEY_PAIR_NAME" "$ANTHROPIC_API_KEY"
EOF
    
    chmod +x examples/deploy-example.sh
    
    # Create example config
    cat > examples/config-example.json << 'EOF'
{
  "stack_name": "openclaw-personal",
  "region": "us-east-1",
  "key_pair_name": "my-keypair",
  "instance_type": "t4g.medium",
  "start_schedule": "cron(0 13 ? * MON-FRI *)",
  "stop_schedule": "cron(0 1 ? * TUE-SAT *)",
  "idle_shutdown_minutes": 30,
  "timezone": "America/New_York"
}
EOF

    print_success "Created examples directory with templates"
fi

# Check Git status (if in a git repo)
if git status &>/dev/null; then
    print_status "Git repository detected"
    
    # Check if .gitignore exists
    if [ ! -f ".gitignore" ]; then
        print_warning ".gitignore missing"
    else
        print_success ".gitignore found"
    fi
    
    # Check for API keys in git history (basic check)
    if git log --all --source --grep="sk-ant-" --regexp-ignore-case &>/dev/null; then
        print_warning "Possible API keys detected in git history"
        echo "   Never commit API keys to version control"
    fi
else
    print_status "Not a git repository (optional)"
fi

# Summary
echo
echo "🎯 Setup Complete!"
echo "=================="

if aws --version &>/dev/null && session-manager-plugin --version &>/dev/null; then
    print_success "✅ All prerequisites met - ready to deploy!"
    echo
    echo "Next steps:"
    echo "1. Get your Anthropic API key from: https://console.anthropic.com/"
    echo "2. Create/verify EC2 key pair in AWS Console"
    echo "3. Run: ./deploy.sh openclaw-personal us-east-1 your-keypair sk-ant-..."
    echo "4. Or customize: examples/deploy-example.sh"
else
    print_warning "⚠️  Some prerequisites missing"
    echo
    echo "Install missing components, then run:"
    echo "./setup.sh"
fi

echo
echo "📚 Documentation:"
echo "   Quick start: QUICKSTART.md"
echo "   Full guide: README.md"
echo "   Troubleshooting: TROUBLESHOOTING.md"
echo "   Cost optimization: COST_OPTIMIZATION.md"
echo
echo "🛠️  Useful commands:"
echo "   Health check: ./scripts/health-check.sh"
echo "   View logs: ./scripts/analyze-logs.sh"
echo "   Uninstall: ./uninstall.sh openclaw-personal"
EOF

chmod +x setup.sh

# Check for Git and initialize if needed
if git status &>/dev/null 2>&1; then
    print_success "Git repository already initialized"
else
    if command -v git &> /dev/null; then
        print_status "Initializing Git repository..."
        git init
        git add .
        git commit -m "Initial commit: OpenClaw Personal Edition

- Cost-optimized OpenClaw deployment on AWS
- Automated start/stop scheduling
- Manual control web interface  
- Direct Anthropic API key support
- Comprehensive documentation and tools
- ~$15/month operating cost"
        print_success "Git repository initialized with initial commit"
    else
        print_warning "Git not found - repository not initialized"
    fi
fi

print_success "Repository setup complete!"
echo
print_status "Ready to deploy OpenClaw Personal Edition 🦞"