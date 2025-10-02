#!/bin/bash

# User Management Microservice - Build and Push Script
# This script builds the Docker image and pushes it to ECR
# Default region: us-east-1

set -e

echo "🚀 Building and pushing user-management microservice to ECR..."

# Always prompt for AWS credentials
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

echo "📝 Credentials entered:"
echo "   Access Key: $(echo $AWS_ACCESS_KEY_ID | cut -c1-10)..."
echo "   Secret Key: $(echo $AWS_SECRET_ACCESS_KEY | cut -c1-6)..."
echo "   Region: $AWS_REGION"

# Export credentials for this session
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_REGION

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

# Validate region configuration
if [ "$AWS_REGION" != "us-east-1" ]; then
    echo "⚠️  WARNING: You selected region '$AWS_REGION' instead of 'us-east-1'"
    echo "⚠️  This will require updates to the Terraform infrastructure:"
    echo "   - Update provider region in terraform/main.tf"
    echo "   - Update ECR region references in ECS task definition"
    echo "   - Update ALB region in outputs"
    echo "   - Update CloudWatch logs region"
    echo ""
    read -p "Do you want to continue with '$AWS_REGION'? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Please use us-east-1 or update your infrastructure configuration."
        exit 1
    fi
fi

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="user-management-microservice"

echo "📝 AWS Account ID: $AWS_ACCOUNT_ID"
echo "📝 AWS Region: $AWS_REGION"
echo "📝 ECR Repository: $ECR_REPO"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build Docker image
echo "🔨 Building Docker image..."
docker build -t $ECR_REPO:latest .

# Tag image for ECR
echo "🏷️  Tagging image for ECR..."
docker tag $ECR_REPO:latest \
    $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest

# Push image to ECR
echo "📤 Pushing image to ECR..."
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest

echo "✅ Successfully pushed image to ECR!"
echo "📋 Image URI: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest"

# Update ECS service to use new image (force new deployment)
echo "🔄 Forcing ECS service update..."
aws ecs update-service \
    --cluster user-management-cluster \
    --service user-management-service \
    --force-new-deployment \
    --region $AWS_REGION

echo "🎉 Build and deployment complete!"
echo "🌐 Your microservice will be available at the ALB DNS name in a few minutes."
echo ""
echo "💡 Region Note: This script uses region '$AWS_REGION'"
echo "   If you used a different region for infrastructure deployment,"
echo "   make sure your Terraform configuration matches this region."