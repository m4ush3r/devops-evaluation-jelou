#!/bin/bash

# Simple Infrastructure Cleanup Script
# This script asks for AWS credentials and runs terraform destroy

set -e

echo "🧹 Starting infrastructure cleanup..."

# Function to prompt for AWS credentials
setup_aws_credentials() {
    echo "🔐 AWS Credentials Setup"
    echo "Please provide your AWS credentials:"
    
    while true; do
        read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
        if [ -n "$AWS_ACCESS_KEY_ID" ]; then
            break
        fi
        echo "❌ Access Key ID cannot be empty. Please try again."
    done
    
    while true; do
        echo -n "AWS Secret Access Key: "
        stty -echo 2>/dev/null || true
        read AWS_SECRET_ACCESS_KEY
        stty echo 2>/dev/null || true
        echo
        if [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ $(echo $AWS_SECRET_ACCESS_KEY | wc -c) -gt 10 ]; then
            break
        fi
        echo "❌ Secret Access Key cannot be empty and must be valid. Please try again."
    done
    
    read -p "AWS Region (default: us-east-1): " AWS_REGION
    
    # Set default region if not provided
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="us-east-1"
    fi
    
    # Export credentials for this session
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION=$AWS_REGION
    
    echo "📝 Credentials entered:"
    echo "   Access Key: $(echo $AWS_ACCESS_KEY_ID | cut -c1-10)..."
    echo "   Secret Key: $(echo $AWS_SECRET_ACCESS_KEY | cut -c1-6)..."
    echo "   Region: $AWS_REGION"
    
    echo "✅ AWS credentials configured for region: $AWS_REGION"
    
    # Test credentials
    echo "🔍 Testing AWS credentials..."
    CRED_TEST=$(aws sts get-caller-identity 2>&1)
    if [ $? -eq 0 ]; then
        echo "✅ AWS credentials are valid"
        echo "   Account: $(echo $CRED_TEST | grep -o '"Account":"[^"]*"' | cut -d'"' -f4)"
    else
        echo "❌ Invalid AWS credentials. Error:"
        echo "$CRED_TEST"
        exit 1
    fi
}

# Always prompt for AWS credentials
setup_aws_credentials

echo "🚀 Pre-destroy: Scaling down ECS service..."
# Scale down ECS service to 0 to allow clean deletion
aws ecs update-service \
    --cluster user-management-cluster \
    --service user-management-service \
    --desired-count 0 \
    --region $AWS_REGION || echo "⚠️ ECS service not found or already scaled down"

echo "⏳ Waiting for tasks to stop..."
sleep 30

echo "🚀 Running Terraform destroy..."
cd terraform/
terraform destroy -auto-approve

echo ""
echo "🎉 Infrastructure cleanup completed!"
echo "✅ All resources have been destroyed via Terraform"