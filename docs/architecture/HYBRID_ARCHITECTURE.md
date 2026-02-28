# OpenClaw Hybrid DevOps Architecture

## Overview
This document outlines the hybrid approach for OpenClaw with controlled AWS DevOps capabilities.

## Resource Limits & Budgets

### Compute Resources
- **EC2 Instances**: Max 2 total
- **Instance Types**: t4g.small, t4g.medium, t3.small, t3.medium only
- **EBS Volumes**: Max 4 volumes, 100GB each
- **Elastic IPs**: Max 2

### Cost Controls
- **Daily Budget**: $10/day (email alert)
- **Monthly Budget**: $100/month (hard stop)
- **Cost Per Resource**: Tagged and tracked

## Enhanced IAM Permissions

### Allowed Services
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RunInstances",
        "ec2:TerminateInstances", 
        "ec2:DescribeInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:CreateTags"
      ],
      "Resource": "*",
      "Condition": {
        "ForAllValues:StringEquals": {
          "ec2:InstanceType": [
            "t4g.small",
            "t4g.medium", 
            "t3.small",
            "t3.medium"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:ListStacks"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    },
    {
      "Effect": "Allow", 
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::openclaw-*",
        "arn:aws:s3:::openclaw-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:DeleteFunction", 
        "lambda:InvokeFunction",
        "lambda:UpdateFunctionCode",
        "lambda:ListFunctions"
      ],
      "Resource": "*"
    }
  ]
}
```

### Denied Services
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "billing:*",
        "route53:*",
        "rds:CreateDBCluster",
        "elasticache:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "ForAnyValue:StringNotEquals": {
          "ec2:InstanceType": [
            "t4g.small",
            "t4g.medium",
            "t3.small", 
            "t3.medium"
          ]
        }
      }
    }
  ]
}
```

## Monitoring & Alerting

### CloudWatch Alarms
- Daily cost > $5: Warning email
- Daily cost > $10: Urgent email + SMS
- New EC2 instance created: Notification
- Instance terminated: Notification with cost summary

### SNS Topics
- **openclaw-cost-alerts**: Budget notifications
- **openclaw-resource-alerts**: Resource lifecycle
- **openclaw-security-alerts**: Security events

### Budget Actions
- 80% of monthly budget: Email warning
- 90% of monthly budget: Email + SMS
- 100% of monthly budget: Deny new resource creation

## GitHub Integration

### Personal Access Token Permissions
- **repo**: Full repository access
- **workflow**: GitHub Actions workflows
- **read:user**: Read user profile info
- **user:email**: Access email addresses

### Security Measures
- Token stored in AWS Parameter Store (encrypted)
- All commits signed with GPG key
- Branch protection on main branches
- Automatic backup of important repos

## OpenClaw Skills Configuration

### Enabled Skills
- **aws-ec2**: Basic EC2 management
- **aws-cloudformation**: Stack deployment 
- **github-integration**: Repo management
- **docker**: Container management
- **code-generation**: Multi-language coding
- **monitoring**: Cost and resource tracking

### Skill Restrictions
- No direct billing access
- No IAM user management
- Require confirmation for >$20 operations
- Auto-tag all created resources

## Development Workflow

### Typical Interaction
```
You: "Create a React app called 'todo-app' and deploy it to AWS"

OpenClaw:
1. Creates GitHub repo 'todo-app'  
2. Generates React boilerplate code
3. Commits initial code
4. Creates CloudFormation stack
5. Deploys to S3 + CloudFront
6. Returns live URL
7. Sends cost estimate ($2.50/month)
```

### Cost Tracking
- Every action includes cost estimate
- Daily summary of spend by service
- Monthly report with optimization suggestions
- Automatic cleanup of unused resources

## Security Best Practices

### Resource Tagging
All resources tagged with:
- **CreatedBy**: openclaw
- **Project**: project-name
- **Environment**: development
- **CostCenter**: personal
- **DeleteAfter**: optional auto-cleanup date

### Backup Strategy  
- Daily snapshots of EBS volumes
- GitHub repos backed up to S3
- Configuration exported weekly
- Disaster recovery procedures documented

### Access Controls
- OpenClaw instance in private subnet
- SSM Session Manager for secure access
- No direct SSH keys required
- All API calls logged in CloudTrail

## Cost Optimization

### Automatic Actions
- Stop idle instances after 2 hours
- Delete old snapshots after 7 days
- Clean up failed CloudFormation stacks
- Archive old S3 objects to IA storage

### Manual Reviews
- Weekly cost review via email
- Monthly optimization recommendations
- Quarterly architecture review
- Annual budget planning

## Deployment Commands

### Initial Setup
```powershell
# Deploy hybrid version
.\deploy-hybrid.ps1 -StackName "openclaw-devops" -Region "us-east-1" -KeyPairName "openclaw-key" -AnthropicApiKey "sk-ant-..." -GitHubToken "ghp_..."
```

### Monitoring Setup
```powershell
# Configure alerts
.\setup-monitoring.ps1 -Email "your-email@example.com" -PhoneNumber "+1234567890"
```

### Skills Installation
```bash
# On OpenClaw instance
openclaw skills install aws-ec2
openclaw skills install github-integration  
openclaw skills install cost-monitoring
```