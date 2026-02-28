# Cost Optimization Guide

This guide helps you minimize AWS costs while running OpenClaw Personal Edition.

## Current Baseline

**Default Configuration (t4g.medium, 12 hrs/day):**
- EC2: $12.10/month
- EBS Storage: $2.40/month  
- Lambda + EventBridge: ~$0.10/month
- Data Transfer: ~$1.00/month
- **Total: ~$15.50/month**

## Optimization Strategies

### Level 1: Easy Wins (No Architecture Changes)

#### 1.1 Use Smaller Instance Type

Switch from t4g.medium to t4g.small:

```bash
# Update your stack
aws cloudformation update-stack \
  --stack-name openclaw-personal \
  --template-body file://openclaw-personal.yaml \
  --parameters \
    ParameterKey=InstanceType,ParameterValue=t4g.small \
  --capabilities CAPABILITY_IAM
```

**Savings: $6/month (50% reduction)**
- t4g.small: $6.05/month (vs $12.10)
- RAM: 2GB (vs 4GB) - still sufficient for personal use
- Risk: May be slower with heavy usage

#### 1.2 Reduce Runtime Hours

Modify your schedule to use OpenClaw only when needed:

**8 hours/day (work hours only):**
```yaml
StartSchedule: 'cron(0 14 ? * MON-FRI *)'  # 9am EST
StopSchedule: 'cron(0 22 ? * MON-FRI *)'   # 5pm EST
```
**Savings: $4.00/month**
- 8hrs/day = $8.06/month (vs $12.10)

**Weekends only:**
```yaml
StartSchedule: 'cron(0 13 ? * SAT-SUN *)'  # 8am EST Sat-Sun
StopSchedule: 'cron(0 1 ? * SUN-MON *)'    # 8pm EST Sun-Mon
```
**Savings: $7.80/month**
- 16hrs/weekend = $4.30/month (vs $12.10)

#### 1.3 Optimize Auto-Idle Settings

Reduce idle time before auto-shutdown:

```yaml
IdleShutdownMinutes: 10  # vs default 30 minutes
```

**Estimated savings: $1-3/month**
- Shuts down faster when you're not actively using it
- Particularly effective if you use OpenClaw in short bursts

### Level 2: Moderate Changes

#### 2.1 Spot Instances (High Savings, Some Risk)

Spot instances can save up to 90% but may be interrupted:

Add to CloudFormation template:
```yaml
InstanceMarketOptions:
  MarketType: spot
  SpotOptions:
    MaxPrice: '0.01'  # 70% savings
    SpotInstanceType: one-time
```

**Savings: $8.50/month**
- t4g.medium spot: ~$3.60/month (vs $12.10)
- Risk: AWS can reclaim with 2-minute notice
- Mitigation: Auto-save state, fallback to on-demand

#### 2.2 Reserved Instances (1-year commitment)

If you plan to use OpenClaw consistently for a year:

```bash
# Purchase 1-year reserved instance
aws ec2 purchase-reserved-instances-offering \
  --reserved-instances-offering-id <offering-id> \
  --instance-count 1
```

**Savings: $3.50/month**
- 30-40% discount on EC2 costs
- Requires 1-year commitment
- Best if you know you'll use it consistently

#### 2.3 Use EBS Snapshots Instead of Always-On Storage

For extreme cost optimization, snapshot your EBS volume and delete it when not in use:

**Warning: This is complex and has risks of data loss**

```bash
# Create snapshot before stopping
aws ec2 create-snapshot --volume-id <volume-id> --description "OpenClaw backup"

# Delete volume (saves $2.40/month)
aws ec2 delete-volume --volume-id <volume-id>

# Restore from snapshot when needed
aws ec2 create-volume --snapshot-id <snapshot-id> --availability-zone <az>
```

**Savings: $2.40/month**
- Only pay for snapshots (~$0.05/GB/month)
- Risk: Complex automation needed, potential data loss
- Only recommended for advanced users

### Level 3: Advanced Optimizations

#### 3.1 Multi-Region Cost Arbitrage

Some regions are cheaper than others:

| Region | t4g.medium/hour | 12hrs/day Monthly |
|--------|----------------|-------------------|
| us-east-1 | $0.0336 | $12.10 |
| us-west-2 | $0.0336 | $12.10 |
| eu-central-1 | $0.0378 | $13.61 |
| ap-southeast-1 | $0.042 | $15.12 |

**Minimal savings for most regions, but:**
- Consider regions with promotional credits
- Factor in your location for latency

#### 3.2 Lambda-Only Architecture (Serverless)

For very light usage, run OpenClaw in Lambda functions:

**Pros:**
- Pay per request (~$0.20/month for 1000 conversations)
- No idle costs
- Automatic scaling

**Cons:**  
- Complex setup
- 15-minute timeout per conversation
- Cold starts
- Limited to stateless operations

**Estimated cost: $0.20-2.00/month**

#### 3.3 Container Instances (AWS Fargate)

Run OpenClaw on Fargate instead of EC2:

```yaml
# Fargate task definition
TaskDefinition:
  Cpu: 256
  Memory: 512
  RequiresCompatibilities: [FARGATE]
```

**Cost comparison:**
- Fargate: ~$9.00/month (256 CPU, 512MB, 12hrs/day)
- EC2: ~$12.10/month (t4g.medium, 12hrs/day)

**Savings: $3/month**
- No OS management
- Better resource utilization
- More complex networking setup

## Cost Monitoring & Alerts

### Set Up Cost Alerts

```bash
# Create budget alert
aws budgets create-budget \
  --account-id <account-id> \
  --budget '{
    "BudgetName": "OpenClaw-Monthly",
    "BudgetLimit": {
      "Amount": "20.00",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications '[{
    "NotificationType": "ACTUAL",
    "ComparisonOperator": "GREATER_THAN",
    "Threshold": 80,
    "ThresholdType": "PERCENTAGE"
  }]' \
  --subscribers '[{
    "SubscriptionType": "EMAIL",
    "Address": "your-email@example.com"
  }]'
```

### Daily Cost Tracking

Add this to your daily cron:

```bash
#!/bin/bash
# Daily cost check script

YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

COST=$(aws ce get-cost-and-usage \
  --time-period Start=$YESTERDAY,End=$TODAY \
  --granularity DAILY \
  --metrics BlendedCost \
  --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
  --output text)

echo "OpenClaw cost yesterday: \$$COST"

# Alert if over $1/day  
if (( $(echo "$COST > 1.0" | bc -l) )); then
  echo "⚠️ High cost detected!"
  # Send notification
fi
```

## Optimization Recommendations by Usage Pattern

### Light User (< 5 conversations/day)
- **Use:** t4g.small + 4hrs/day schedule
- **Monthly cost:** ~$6
- **Optimizations:** Spot instances, auto-idle 10min

### Regular User (5-20 conversations/day)
- **Use:** t4g.medium + 8hrs/day schedule  
- **Monthly cost:** ~$10
- **Optimizations:** Auto-idle 20min, weekend-off

### Heavy User (20+ conversations/day)
- **Use:** t4g.medium + 16hrs/day schedule
- **Monthly cost:** ~$17
- **Optimizations:** Reserved instance, larger EBS volume

### Team Use (5+ people)
- **Use:** t4g.large + always-on
- **Monthly cost:** ~$25
- **Optimizations:** Reserved instance, consider c7g instance family

## Extreme Budget Mode

**Goal: Under $5/month**

Configuration:
- t4g.small spot instance (~$1.80/month at $0.005/hr)
- 6hrs/day, weekdays only
- EBS snapshot storage instead of persistent volume  
- Auto-idle after 5 minutes
- Lambda-based scheduling to minimize EventBridge costs

**Estimated monthly cost: $3-4**

**Setup complexity: High**  
**Data loss risk: Medium**
**Recommended for: Experimental use only**

## ROI Calculator

Compare with alternatives:

| Solution | Monthly Cost | Notes |
|----------|-------------|-------|
| ChatGPT Plus | $20/person | Single user, limited API access |
| Claude Pro | $20/person | Single user, no automation |
| **OpenClaw Personal** | **$15** | **Unlimited users, full automation** |
| OpenClaw + Spot | $7 | Higher complexity, interruption risk |
| OpenAI API direct | $10-50+ | No infrastructure, but pay per token |

**Break-even analysis:**
- If you use >$15 worth of API calls per month, OpenClaw saves money
- For teams of 2+ people, OpenClaw is always cheaper than individual subscriptions

## Implementation Guide

### Quick Optimization (5 minutes)

1. Change to t4g.small:
   ```bash
   ./deploy.sh openclaw-personal us-east-1 my-key sk-ant-... t4g.small
   ```

2. Reduce schedule to 8hrs:
   ```yaml
   StartSchedule: 'cron(0 14 ? * MON-FRI *)'  # 9am EST
   StopSchedule: 'cron(0 22 ? * MON-FRI *)'   # 5pm EST  
   ```

3. Set up cost alert:
   ```bash
   aws budgets create-budget --budget-name OpenClaw --budget-limit-amount 10
   ```

### Advanced Optimization (1 hour)

1. Enable spot instances
2. Set up EBS snapshot automation  
3. Implement usage-based scaling
4. Configure detailed cost monitoring

### Expert Mode (1 day)

1. Migrate to Fargate
2. Implement Lambda-based architecture
3. Set up multi-region failover
4. Custom auto-scaling policies

---

**Remember:** The goal is to balance cost with reliability and ease of use. Start with simple optimizations and gradually implement more complex ones as you get comfortable with the system.

**Need help?** Open an issue with your current costs and usage patterns for personalized recommendations.