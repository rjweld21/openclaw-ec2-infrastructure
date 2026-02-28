#!/bin/bash

# OpenClaw Personal Edition - Uninstall Script
# Usage: ./uninstall.sh <stack-name> [region]

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

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <stack-name> [region]"
    echo
    echo "Example:"
    echo "  $0 openclaw-personal us-east-1"
    echo
    echo "This will:"
    echo "  ❌ Delete EC2 instance"
    echo "  ❌ Delete EBS volumes"
    echo "  ❌ Delete Lambda functions"
    echo "  ❌ Delete S3 bucket and control page"
    echo "  ❌ Delete CloudWatch logs"
    echo "  ❌ Delete all CloudFormation resources"
    echo "  ⚠️  Permanently destroy all data!"
    exit 1
fi

STACK_NAME=$1
REGION=${2:-$(aws configure get region)}

print_warning "🗑️  OpenClaw Personal Edition - UNINSTALL"
echo
echo "This will PERMANENTLY DELETE:"
echo "  • Stack: $STACK_NAME"
echo "  • Region: $REGION"
echo "  • All data, configurations, and logs"
echo "  • S3 bucket and web interface"
echo "  • EBS volumes (your OpenClaw data)"
echo
echo "💾 BACKUP REMINDER:"
echo "If you want to save your OpenClaw configuration:"
echo "1. Connect to instance: aws ssm start-session --target <instance-id>"
echo "2. Backup config: tar -czf ~/openclaw-backup.tar.gz ~/.openclaw"
echo "3. Download backup: aws s3 cp ~/openclaw-backup.tar.gz s3://your-backup-bucket/"
echo

read -p "⚠️  Are you ABSOLUTELY SURE you want to delete everything? Type 'DELETE' to confirm: " -r
echo
if [ "$REPLY" != "DELETE" ]; then
    print_status "Uninstall cancelled"
    exit 0
fi

# Check if stack exists
print_status "Checking if stack exists..."
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
    print_warning "Stack '$STACK_NAME' not found in region $REGION"
    echo
    echo "Available stacks:"
    aws cloudformation list-stacks \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query 'StackSummaries[?contains(StackName, `openclaw`)].StackName' \
        --region $REGION \
        --output table
    exit 1
fi

# Get stack outputs before deletion
print_status "Gathering stack information..."
OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs' 2>/dev/null || echo "[]")

INSTANCE_ID=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="InstanceId") | .OutputValue' 2>/dev/null || echo "")
S3_BUCKET_URL=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="StartStopPageURL") | .OutputValue' 2>/dev/null || echo "")
S3_BUCKET=$(echo $S3_BUCKET_URL | sed 's|https://\([^.]*\)\..*|\1|' 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ]; then
    print_status "Found instance: $INSTANCE_ID"
fi

if [ -n "$S3_BUCKET" ]; then
    print_status "Found S3 bucket: $S3_BUCKET"
fi

# Stop instance first (for faster deletion)
if [ -n "$INSTANCE_ID" ]; then
    print_status "Stopping EC2 instance..."
    aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION &>/dev/null || true
fi

# Empty S3 bucket (required before deletion)
if [ -n "$S3_BUCKET" ]; then
    print_status "Emptying S3 bucket..."
    aws s3 rm s3://$S3_BUCKET --recursive --region $REGION 2>/dev/null || {
        print_warning "Could not empty S3 bucket (may not exist or already empty)"
    }
fi

# Delete CloudFormation stack
print_status "Initiating stack deletion..."
aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --region $REGION

print_status "Waiting for stack deletion to complete..."
echo "This may take 5-10 minutes depending on resources..."
echo "You can monitor progress at:"
echo "https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks"
echo

# Show progress
(
    while aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null | grep -E "DELETE_IN_PROGRESS" > /dev/null; do
        echo -n "."
        sleep 30
    done
) &
PROGRESS_PID=$!

# Wait for deletion
if aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION 2>/dev/null; then
    kill $PROGRESS_PID 2>/dev/null || true
    echo  # New line after progress dots
    print_success "Stack deleted successfully!"
else
    kill $PROGRESS_PID 2>/dev/null || true
    echo  # New line after progress dots
    
    # Check if stack still exists
    if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
        print_error "Stack deletion failed!"
        echo
        print_status "Checking for deletion failures..."
        
        aws cloudformation describe-stack-events \
            --stack-name $STACK_NAME \
            --region $REGION \
            --max-items 20 \
            --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
            --output table
        
        echo
        print_warning "Common causes of deletion failure:"
        echo "• EBS volumes with DeleteOnTermination=false"
        echo "• S3 buckets that are not empty"
        echo "• Lambda functions with active event sources"
        echo "• VPC dependencies"
        echo
        print_status "Try manual cleanup:"
        echo "1. Check AWS Console for resources that failed to delete"
        echo "2. Manually delete those resources" 
        echo "3. Run this script again"
        echo
        echo "Or force delete with:"
        echo "aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION"
        exit 1
    else
        print_success "Stack deleted successfully!"
    fi
fi

# Clean up any remaining resources that might not be in CloudFormation
print_status "Checking for orphaned resources..."

# Check for remaining Lambda functions
LAMBDA_FUNCTIONS=$(aws lambda list-functions \
    --query "Functions[?starts_with(FunctionName, \`$STACK_NAME\`)].FunctionName" \
    --region $REGION \
    --output text)

if [ -n "$LAMBDA_FUNCTIONS" ]; then
    print_warning "Found orphaned Lambda functions: $LAMBDA_FUNCTIONS"
    echo "Delete manually with:"
    for func in $LAMBDA_FUNCTIONS; do
        echo "aws lambda delete-function --function-name $func --region $REGION"
    done
fi

# Check for remaining CloudWatch log groups
LOG_GROUPS=$(aws logs describe-log-groups \
    --log-group-name-prefix "/aws/lambda/$STACK_NAME" \
    --query 'logGroups[].logGroupName' \
    --region $REGION \
    --output text)

if [ -n "$LOG_GROUPS" ]; then
    print_status "Cleaning up CloudWatch log groups..."
    for group in $LOG_GROUPS; do
        aws logs delete-log-group --log-group-name $group --region $REGION 2>/dev/null || true
    done
fi

# Check for remaining Parameter Store parameters
PARAMETERS=$(aws ssm get-parameters-by-path \
    --path "/$STACK_NAME/" \
    --query 'Parameters[].Name' \
    --region $REGION \
    --output text 2>/dev/null)

if [ -n "$PARAMETERS" ]; then
    print_status "Cleaning up Parameter Store parameters..."
    for param in $PARAMETERS; do
        aws ssm delete-parameter --name "$param" --region $REGION 2>/dev/null || true
    done
fi

# Final verification
print_status "Verifying cleanup..."

REMAINING_RESOURCES=0

# Check CloudFormation
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &>/dev/null; then
    print_warning "CloudFormation stack still exists"
    ((REMAINING_RESOURCES++))
fi

# Check Lambda functions
if [ -n "$(aws lambda list-functions --query "Functions[?starts_with(FunctionName, \`$STACK_NAME\`)].FunctionName" --region $REGION --output text)" ]; then
    print_warning "Lambda functions still exist"
    ((REMAINING_RESOURCES++))
fi

# Check S3 bucket
if [ -n "$S3_BUCKET" ] && aws s3api head-bucket --bucket $S3_BUCKET --region $REGION &>/dev/null; then
    print_warning "S3 bucket still exists"
    ((REMAINING_RESOURCES++))
fi

# Summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $REMAINING_RESOURCES -eq 0 ]; then
    print_success "🎉 OpenClaw Personal Edition uninstalled successfully!"
    echo
    echo "✅ All resources have been deleted"
    echo "✅ No monthly charges will occur"
    echo "✅ All data has been permanently destroyed"
else
    print_warning "⚠️  Uninstall completed with warnings"
    echo
    echo "Some resources may still exist. Check AWS Console for:"
    echo "• CloudFormation → Stacks"
    echo "• EC2 → Instances, Volumes"  
    echo "• Lambda → Functions"
    echo "• S3 → Buckets"
    echo "• CloudWatch → Log Groups"
fi

echo
echo "💰 BILLING IMPACT:"
echo "   • All AWS resources deleted (no more charges)"
echo "   • Final charges may appear for partial month usage"
echo "   • EBS snapshots (if any) will continue to incur small charges"
echo
echo "🔄 TO REINSTALL:"
echo "   • Run: ./deploy.sh $STACK_NAME $REGION your-key-pair your-api-key"
echo "   • All configuration will need to be recreated"
echo "   • Previous backups can be restored manually"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Save uninstall log
cat > uninstall-log.txt << EOF
OpenClaw Personal Edition - Uninstall Log
Date: $(date)
Stack: $STACK_NAME
Region: $REGION
Instance ID: $INSTANCE_ID
S3 Bucket: $S3_BUCKET
Status: $([ $REMAINING_RESOURCES -eq 0 ] && echo "SUCCESS" || echo "PARTIAL")
Remaining Resources: $REMAINING_RESOURCES

Resources deleted:
- CloudFormation stack
- EC2 instance and EBS volumes
- Lambda functions
- S3 bucket and objects
- CloudWatch log groups
- Parameter Store parameters
- IAM roles and policies
- Security groups and VPC resources

Next steps:
- Check AWS billing console for final charges
- Remove any manual EBS snapshots if desired
- Remove SSH key pair if no longer needed
EOF

print_status "Uninstall log saved to: uninstall-log.txt"