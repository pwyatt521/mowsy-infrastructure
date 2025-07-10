#!/bin/bash

set -e

ENVIRONMENT=""
DAYS=7

usage() {
    echo "Usage: $0 [-e ENVIRONMENT] [-d DAYS]"
    echo "  -e ENVIRONMENT  Filter by environment (dev, stage, prod) [optional]"
    echo "  -d DAYS         Number of days to look back [default: 7]"
    echo ""
    echo "Examples:"
    echo "  $0                    # All environments, last 7 days"
    echo "  $0 -e prod           # Production only, last 7 days"
    echo "  $0 -d 30             # All environments, last 30 days"
    exit 1
}

while getopts "e:d:" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        d)
            DAYS="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done

if [ -n "$ENVIRONMENT" ] && [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, stage, prod"
    exit 1
fi

echo "=== Mowsy Infrastructure Cost Report ==="
echo "Period: Last $DAYS days"
if [ -n "$ENVIRONMENT" ]; then
    echo "Environment: $ENVIRONMENT"
else
    echo "Environment: All"
fi
echo ""

START_DATE=$(date -d "$DAYS days ago" +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

echo "Date Range: $START_DATE to $END_DATE"
echo ""

if command -v aws &> /dev/null; then
    echo "📊 AWS Cost and Usage Report"
    echo "================================"
    
    DIMENSION_FILTER=""
    if [ -n "$ENVIRONMENT" ]; then
        DIMENSION_FILTER="--group-by Type=DIMENSION,Key=TAG:Environment --filter '{\"Tags\":{\"Key\":\"Environment\",\"Values\":[\"$ENVIRONMENT\"]}}'"
    else
        DIMENSION_FILTER="--group-by Type=DIMENSION,Key=TAG:Environment"
    fi
    
    echo "💰 Total Cost by Environment:"
    eval "aws ce get-cost-and-usage \
        --time-period Start=$START_DATE,End=$END_DATE \
        --granularity DAILY \
        --metrics BlendedCost \
        $DIMENSION_FILTER \
        --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' \
        --output table" 2>/dev/null || echo "Unable to fetch cost data. Ensure you have Cost Explorer permissions."

    echo ""
    echo "🔧 Cost by Service (Top 10):"
    eval "aws ce get-cost-and-usage \
        --time-period Start=$START_DATE,End=$END_DATE \
        --granularity DAILY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --query 'ResultsByTime[0].Groups[:10].[Keys[0],Metrics.BlendedCost.Amount]' \
        --output table" 2>/dev/null || echo "Unable to fetch service cost data."

    echo ""
    echo "📈 Daily Cost Trend:"
    eval "aws ce get-cost-and-usage \
        --time-period Start=$START_DATE,End=$END_DATE \
        --granularity DAILY \
        --metrics BlendedCost \
        --query 'ResultsByTime[*].[TimePeriod.Start,Total.BlendedCost.Amount]' \
        --output table" 2>/dev/null || echo "Unable to fetch daily cost trend."

else
    echo "AWS CLI not found. Please install AWS CLI to get cost reports."
fi

echo ""
echo "🎯 Cost Optimization Tips"
echo "=========================="
echo "• Monitor RDS usage - stop non-prod instances when not needed"
echo "• Review Lambda memory allocation - right-size for performance vs cost"
echo "• Check S3 lifecycle policies - transition old data to cheaper storage"
echo "• Monitor API Gateway usage - implement caching for frequently accessed data"
echo "• Set up billing alerts for unexpected cost increases"
echo ""

echo "📋 Resource Summary"
echo "==================="

for env in dev stage prod; do
    if [ -n "$ENVIRONMENT" ] && [ "$ENVIRONMENT" != "$env" ]; then
        continue
    fi
    
    ENV_DIR="../environments/$env"
    if [ -d "$ENV_DIR" ]; then
        echo ""
        echo "Environment: $env"
        echo "-------------------"
        
        if [ -f "$ENV_DIR/terraform.tfstate" ]; then
            echo "Status: ✅ Deployed"
        elif [ -f "$ENV_DIR/.terraform/terraform.tfstate" ]; then
            echo "Status: ✅ Deployed (remote state)"
        else
            echo "Status: ❌ Not deployed"
            continue
        fi
        
        # Try to get resource counts from Terraform
        cd "$ENV_DIR" 2>/dev/null && {
            echo "Resources:"
            terraform state list 2>/dev/null | grep -E "aws_lambda_function|aws_db_instance|aws_s3_bucket|aws_api_gateway" | \
            sed 's/module\./  • /' | sed 's/\[.*\]//' | sort || echo "  • Unable to fetch resource list"
            cd - > /dev/null
        }
    fi
done

echo ""
echo "💡 Free Tier Monitoring"
echo "======================="
echo "• RDS: 750 hours/month of db.t3.micro (shared across all environments)"
echo "• Lambda: 1M requests + 400,000 GB-seconds/month"
echo "• API Gateway: 1M API calls/month"
echo "• S3: 5GB storage, 20K GET, 2K PUT requests/month"
echo "• CloudWatch: 10 custom metrics and alarms"
echo ""
echo "Check AWS Free Tier usage: https://console.aws.amazon.com/billing/home#/freetier"
echo ""

echo "=== End of Cost Report ==="