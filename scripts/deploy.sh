#!/bin/bash

# OpenClaw Personal Edition - Deployment Script
# Usage: ./deploy.sh <stack-name> <region> <key-pair-name> <anthropic-api-key>

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check arguments
if [ $# -ne 4 ]; then
    print_error "Usage: $0 <stack-name> <region> <key-pair-name> <anthropic-api-key>"
    echo
    echo "Example:"
    echo "  $0 openclaw-personal us-east-1 my-keypair sk-ant-api03-..."
    echo
    echo "Parameters:"
    echo "  stack-name: CloudFormation stack name (e.g., openclaw-personal)"
    echo "  region: AWS region (e.g., us-east-1, us-west-2)"
    echo "  key-pair-name: Existing EC2 key pair name"
    echo "  anthropic-api-key: Your Anthropic API key (sk-ant-...)"
    exit 1
fi

STACK_NAME=$1
REGION=$2
KEY_PAIR_NAME=$3
ANTHROPIC_API_KEY=$4

# Validate Anthropic API key format
if [[ ! $ANTHROPIC_API_KEY =~ ^sk-ant- ]]; then
    print_error "Invalid Anthropic API key format. Must start with 'sk-ant-'"
    exit 1
fi

print_status "Starting OpenClaw Personal Edition deployment..."
echo
echo "Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Key Pair: $KEY_PAIR_NAME"
echo "  API Key: ${ANTHROPIC_API_KEY:0:15}..."
echo

# Check if AWS CLI is configured
if ! aws sts get-caller-identity --region $REGION &>/dev/null; then
    print_error "AWS CLI not configured or no access to region $REGION"
    print_warning "Run 'aws configure' to set up your credentials"
    exit 1
fi

# Validate key pair exists
print_status "Validating EC2 key pair..."
if ! aws ec2 describe-key-pairs --key-names $KEY_PAIR_NAME --region $REGION &>/dev/null; then
    print_error "Key pair '$KEY_PAIR_NAME' not found in region $REGION"
    print_warning "Create a key pair first: aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --region $REGION"
    exit 1
fi

# Check if stack already exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
    print_warning "Stack '$STACK_NAME' already exists"
    read -p "Do you want to update it? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
    ACTION="update-stack"
    WAIT_COMMAND="stack-update-complete"
else
    ACTION="create-stack"
    WAIT_COMMAND="stack-create-complete"
fi

# Deploy CloudFormation stack
print_status "Deploying CloudFormation stack..."
aws cloudformation $ACTION \
    --stack-name $STACK_NAME \
    --template-body file://openclaw-personal.yaml \
    --parameters \
        ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME \
        ParameterKey=AnthropicApiKey,ParameterValue=$ANTHROPIC_API_KEY \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region $REGION

# Wait for deployment to complete
print_status "Waiting for deployment to complete (this takes ~8-10 minutes)..."
echo "You can monitor progress in the AWS Console:"
echo "https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks/stackinfo?stackId=$STACK_NAME"
echo

# Show progress dots
(
    while aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null | grep -E "(IN_PROGRESS|PENDING)" > /dev/null; do
        echo -n "."
        sleep 30
    done
) &
PROGRESS_PID=$!

# Wait for stack completion
if ! aws cloudformation wait $WAIT_COMMAND --stack-name $STACK_NAME --region $REGION; then
    kill $PROGRESS_PID 2>/dev/null || true
    print_error "Stack deployment failed!"
    
    # Show recent stack events for debugging
    echo
    print_status "Recent stack events:"
    aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --region $REGION \
        --max-items 10 \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
        --output table
    
    exit 1
fi

kill $PROGRESS_PID 2>/dev/null || true
echo  # New line after progress dots
print_success "Stack deployment completed!"

# Get stack outputs
print_status "Retrieving stack outputs..."
OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs')

# Extract function URLs
START_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="StartFunctionURL") | .OutputValue')
STOP_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="StopFunctionURL") | .OutputValue')
STATUS_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="StatusFunctionURL") | .OutputValue')
S3_BUCKET=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="StartStopPageURL") | .OutputValue' | sed 's|https://\([^.]*\)\..*|\1|')
INSTANCE_ID=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="InstanceId") | .OutputValue')

print_status "Configuring web interface..."

# Create temporary HTML file with replaced URLs
cp web/index.html web/index.html.tmp
sed -i.bak \
    -e "s|REPLACE_WITH_START_FUNCTION_URL|$START_URL|g" \
    -e "s|REPLACE_WITH_STOP_FUNCTION_URL|$STOP_URL|g" \
    -e "s|REPLACE_WITH_STATUS_FUNCTION_URL|$STATUS_URL|g" \
    web/index.html.tmp

# Upload to S3
print_status "Uploading web interface to S3..."
aws s3 cp web/index.html.tmp s3://$S3_BUCKET/index.html \
    --content-type "text/html" \
    --region $REGION

# Clean up temporary file
rm web/index.html.tmp web/index.html.tmp.bak 2>/dev/null || true

# Get final URLs
START_STOP_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="StartStopPageURL") | .OutputValue')
SSM_COMMAND=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="SSMPortForwardCommand") | .OutputValue')

# Display success message and instructions
echo
print_success "🎉 OpenClaw Personal Edition deployed successfully!"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "📋 QUICK ACCESS:"
echo
echo "1️⃣  Control Panel (Start/Stop): $START_STOP_URL"
echo
echo "2️⃣  Instance Management:"
echo "    • Instance ID: $INSTANCE_ID"
echo "    • Status: Use the control panel above"
echo
echo "3️⃣  OpenClaw Access (when instance is running):"
echo "    Step 1: Start port forwarding:"
echo "    $SSM_COMMAND"
echo
echo "    Step 2: Open OpenClaw:"
echo "    http://localhost:18789"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "💰 COST ESTIMATE:"
echo "   • Current schedule: 8am-8pm weekdays (12 hrs/day)"
echo "   • Monthly AWS cost: ~\$15.50"
echo "   • Anthropic API: Your existing usage rates"
echo
echo "⏰ AUTOMATIC SCHEDULE:"
echo "   • Starts: Monday-Friday at 8:00 AM EST"
echo "   • Stops: Monday-Friday at 8:00 PM EST"
echo "   • Manual override: Use the control panel anytime"
echo
echo "🔧 NEXT STEPS:"
echo "   1. Bookmark the control panel URL"
echo "   2. Start the instance using the control panel"
echo "   3. Set up port forwarding when you want to use OpenClaw"
echo "   4. Connect your messaging apps (WhatsApp, Telegram, etc.)"
echo
echo "📚 DOCUMENTATION:"
echo "   • OpenClaw docs: https://docs.openclaw.ai"
echo "   • This repo: $(pwd)/README.md"
echo
echo "🆘 TROUBLESHOOTING:"
echo "   • Check CloudWatch logs: AWS Console → CloudWatch → Log Groups"
echo "   • Instance not starting? Check the control panel status"
echo "   • Port forwarding issues? Ensure SSM Session Manager plugin is installed"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save deployment info to file
cat > deployment-info.txt << EOF
OpenClaw Personal Edition - Deployment Info
Generated: $(date)

Stack Name: $STACK_NAME
Region: $REGION
Instance ID: $INSTANCE_ID

Control Panel: $START_STOP_URL
SSM Port Forward: $SSM_COMMAND
OpenClaw URL: http://localhost:18789 (after port forwarding)

Lambda Function URLs:
- Start: $START_URL
- Stop: $STOP_URL  
- Status: $STATUS_URL

Monthly Cost Estimate: ~$15.50
Schedule: 8am-8pm weekdays (EST)
EOF

print_success "Deployment info saved to: deployment-info.txt"
echo
print_status "Happy OpenClaw-ing! 🦞"