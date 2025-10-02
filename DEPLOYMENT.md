# User Management Microservice - Deployment Guide

This guide provides step-by-step instructions for deploying the user management microservice infrastructure using Terraform.

## Prerequisites

### Required Tools
1. **AWS Account**: You need an AWS account with appropriate permissions
2. **AWS CLI**: Version 2.x installed and configured
3. **Terraform**: Version >= 1.0 installed
4. **Docker**: For local development and container operations
5. **Git**: For version control (if cloning from repository)

### Important: Region Configuration
**Default Region**: This infrastructure is configured for **us-east-1** by default.

**If you need to use a different region:**
- Update `provider "aws"` region in `terraform/main.tf`
- Update ECR region references in `terraform/modules/ecs/main.tf`
- Update all CloudWatch logs regions
- Update the build script region when prompted
- Ensure all components use the same region consistently

**Note**: Using different regions requires careful coordination across all components.

### Installation Guide

#### AWS CLI Installation
```bash
# macOS (using Homebrew)
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Windows
# Download and run the MSI installer from AWS documentation

# Verify installation
aws --version
```

#### Terraform Installation
```bash
# macOS (using Homebrew)
brew install terraform

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform --version
```

#### Docker Installation
```bash
# Follow official Docker installation guide for your OS
# https://docs.docker.com/get-docker/

# Verify installation
docker --version
```

### AWS Permissions Required

#### For Infrastructure Deployment
Your AWS user/role needs these permissions for deploying the infrastructure:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "ecs:*",
        "rds:*",
        "iam:*",
        "logs:*",
        "route53:*",
        "servicediscovery:*",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Note**: In production, use more restrictive policies following the principle of least privilege.

## Infrastructure Overview

The infrastructure includes:

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **Application Load Balancer (ALB)**: Public-facing load balancer for external access
- **NAT Gateway**: Provides internet access for private subnet resources
- **ECS Fargate**: Runs the containerized microservice in private subnets
- **ECR Repository**: Private container registry for storing Docker images
- **RDS PostgreSQL**: Multi-AZ database for resilience
- **Service Discovery**: AWS Cloud Map integration with Route53
- **Security Groups**: Layered security with ALB, ECS, and RDS isolation

## Architecture Flow

```
Internet → ALB (Public Subnets) → ECS Fargate (Private Subnets) → RDS (Private Subnets)
                                       ↓
                                ECR (Container Images)
```

### Network Segmentation

- **Public Subnets**: ALB only (2 subnets across different AZs for high availability)
- **Private Subnets**: ECS services and RDS database (no direct internet access)
- **Security**: Services communicate through security groups, not IP addresses
- **Container Registry**: ECR stores Docker images securely in AWS


## Local Development

1. **Start the application locally**:
   ```bash
   docker-compose up --build
   ```

2. **Test the API**:
   ```bash
   # Create a user
   curl -X POST http://localhost:3000/users \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "email": "john@example.com"}'

   # Get a user
   curl http://localhost:3000/users/1

   # Health check
   curl http://localhost:3000/health
   ```

## AWS Deployment

### Quick Start Summary

**Complete deployment in just 4 steps:**

1. **Configure AWS credentials**: Have your AWS Access Key ID and Secret Key ready
2. **Deploy infrastructure FIRST**: `cd terraform && terraform init && terraform apply`
3. **Build and push Docker image**: `cd .. && ./build-and-push.sh` 
4. **Test your API**: Use ALB DNS name from outputs

**Important**: Infrastructure must be created first to set up the ECR repository before building the Docker image.

**Total time**: ~10-15 minutes (including AWS resource creation)

---

### Detailed Setup Guide

#### Initial Setup

#### Step 1: Clone and Prepare Repository

```bash
# Clone the repository (if from Git)
git clone <repository-url>
cd user-management-microservice

# Or if you have the files locally, navigate to the project directory
cd /path/to/your/project
```

#### Step 2: Configure AWS CLI

```bash
# Configure AWS CLI with your credentials
aws configure

# You'll be prompted for:
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

#### Step 3: Configure Infrastructure Variables

1. **Navigate to terraform directory**:
   ```bash
   cd terraform/
   ```

2. **Edit the variables file**:
   ```bash
   # The terraform.tfvars file already exists, edit it:
   nano terraform.tfvars
   # or
   vi terraform.tfvars
   ```

3. **Add your AWS credentials**:
   ```hcl
   # AWS Credentials - Replace with your actual values
   dev_user = "AKIA........................"
   dev_passw = "abcd1234........................"
   ```

4. **Secure the variables file**:
   ```bash
   chmod 600 terraform.tfvars  # Restrict access to owner only
   ```

### Step 4: Deploy Infrastructure (MUST BE DONE FIRST)

**⚠️ CRITICAL: This step must be completed before building/pushing Docker images!**

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Plan the deployment**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

   Type `yes` when prompted to confirm the deployment.

4. **Note the important outputs**:
   ```bash
   # After successful deployment, you'll see:
   alb_dns_name = "user-management-alb-123456789.us-east-1.elb.amazonaws.com"
   ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/user-management-microservice"
   vpc_id = "vpc-0123456789abcdef0"
   ecs_cluster_name = "user-management-cluster"
   ```

   **Important**: 
   - Save the `alb_dns_name` - this is your **public endpoint** for accessing the microservice!
   - The ECR repository is now created and ready for Docker image pushes
   
   **✅ Infrastructure deployment complete! Now proceed to Step 5 for Docker image deployment.**

### Step 5: Build and Deploy Your Microservice

**⚠️ IMPORTANT: Complete Steps 1-4 (Infrastructure Deployment) BEFORE proceeding with this step!**

The ECR repository must exist before you can push Docker images to it.

#### Automated Build and Push Script

1. **Navigate to project root**:
   ```bash
   cd ../  # From terraform/ back to project root
   ```

2. **Run the automated build script**:
   ```bash
   ./build-and-push.sh
   ```
   
   The script will:
   - Ask for AWS credentials manually (Access Key ID + Secret Key)
   - Prompt for AWS region (defaults to us-east-1)
   - **Show region warning** if you choose a region other than us-east-1
   - Build your Docker image
   - Login to ECR (repository created by Terraform in previous steps)
   - Push the image to ECR
   - Trigger ECS service update

3. **Region Selection Important Notes**:
   - **Default**: us-east-1 (recommended - no changes needed)
   - **Other regions**: Script will warn you about required infrastructure changes:
     - Update `terraform/main.tf` provider region
     - Update ECR region in `terraform/modules/ecs/main.tf`
     - Update CloudWatch logs region
     - Ensure consistency across all components

4. **Wait for deployment** (2-3 minutes):
   ```bash
   # Check deployment status
   aws ecs describe-services \
     --cluster user-management-cluster \
     --services user-management-service \
     --region us-east-1 \
     --query 'services[0].deployments[0].status'
   ```

#### Verify Deployment

1. **Check ECS service status**:
   ```bash
   aws ecs describe-services \
     --cluster user-management-cluster \
     --services user-management-service \
     --region us-east-1
   ```

2. **Check container health**:
   ```bash
   # Get running tasks
   aws ecs list-tasks \
     --cluster user-management-cluster \
     --service-name user-management-service \
     --desired-status RUNNING
   ```

3. **View application logs**:
   ```bash
   aws logs describe-log-streams \
     --log-group-name /ecs/user-management \
     --order-by LastEventTime \
     --descending \
     --max-items 1
   ```

## Infrastructure Components

### Network Architecture

- **VPC**: 10.0.0.0/16
- **Public Subnet 1**: 10.0.1.0/24 (AZ: us-east-1a) - ALB only
- **Public Subnet 2**: 10.0.4.0/24 (AZ: us-east-1b) - ALB only
- **Private Subnet 1**: 10.0.2.0/24 (AZ: us-east-1a) - ECS & RDS
- **Private Subnet 2**: 10.0.3.0/24 (AZ: us-east-1b) - ECS & RDS

### Security Groups

- **ALB Security Group**: Allows HTTP (80) and HTTPS (443) from internet (0.0.0.0/0)
- **ECS Security Group**: Allows port 3000 only from ALB security group
- **RDS Security Group**: Allows port 5432 only from ECS security group
- **Zero Trust**: Each layer only communicates with the layer it needs

### High Availability & Resilience

- **Multi-AZ Deployment**: Resources distributed across us-east-1a and us-east-1b
- **ALB**: Automatically distributes traffic across healthy ECS tasks
- **ECS Fargate**: Auto-healing - failed tasks are automatically replaced
- **RDS Multi-AZ**: Automatic failover to standby instance in case of primary failure
- **NAT Gateway**: Provides outbound internet access for private subnet resources

### Container Management

- **ECR Repository**: Private, secure container registry with vulnerability scanning
- **Automated Image Builds**: Build script handles authentication and deployment
- **Image Lifecycle**: Automatic cleanup of old/untagged images
- **Zero Downtime Deployments**: ECS rolling deployments ensure continuous service

### Database

- **Engine**: PostgreSQL 15.7
- **Instance Class**: db.t3.micro (smallest/cheapest)
- **Multi-AZ**: Enabled for resilience
- **Storage**: 20GB with auto-scaling up to 100GB
- **Encryption**: Enabled
- **Password**: Simple password (no Secrets Manager for development simplicity)

### Service Discovery

- **Namespace**: devops.test
- **Service Name**: user-management.devops.test
- **Database DNS**: database.devops.test

## API Endpoints

Once deployed, the microservice provides the following endpoints:

- `GET /health` - Health check
- `POST /users` - Create a new user
- `GET /users/:id` - Get user by ID
- `PUT /users/:id` - Update user (optional)
- `DELETE /users/:id` - Delete user (optional)

## Monitoring and Observability

### CloudWatch Integration

- **Application Logs**: `/ecs/user-management` log group
- **Log Retention**: 7 days (configurable)
- **Container Insights**: Enabled on ECS cluster for detailed metrics
- **ALB Access Logs**: HTTP request/response logging (optional)

### Health Monitoring

- **ALB Health Checks**: HTTP GET `/health` endpoint
  - **Healthy Threshold**: 2 consecutive successful checks
  - **Unhealthy Threshold**: 2 consecutive failed checks
  - **Check Interval**: 30 seconds
  - **Timeout**: 5 seconds

- **ECS Service Monitoring**: 
  - Task health status
  - Service deployment status
  - Resource utilization (CPU/Memory)

### Alerting & Metrics

Key metrics automatically collected:
- **Request Count**: Number of HTTP requests
- **Response Time**: Average response latency  
- **Error Rate**: 4xx/5xx error percentage
- **Task Count**: Running vs desired tasks
- **Database Connections**: Active RDS connections

### Log Analysis Commands

```bash
# View recent application logs
aws logs filter-log-events \
  --log-group-name /ecs/user-management \
  --start-time $(date -d '1 hour ago' +%s)000

# Monitor ECS service events
aws ecs describe-services \
  --cluster user-management-cluster \
  --services user-management-service \
  --query 'services[0].events[0:5]'

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names user-management-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
```

## Simplified State Management

### Local State Files

**For development and testing**:
- **Local Storage**: State files stored locally in `terraform.tfstate`
- **Simple Deployment**: No S3 setup required
- **Single Developer**: Perfect for individual development and testing
- **Quick Start**: Just run `terraform init && terraform apply`

### For Production Teams

If you need team collaboration later, you can migrate to remote state:

1. **Create S3 bucket** for remote state storage
2. **Add backend configuration** to main.tf:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "your-terraform-state-bucket"
       key    = "dev/terraform.tfstate"
       region = "us-east-1"
     }
   }
   ```
3. **Migrate state**: `terraform init` will offer to migrate existing state

### Best Practices

1. **Backup state files** before major changes
2. **Use consistent Terraform versions**
3. **Never edit state files manually**
4. **Run `terraform plan` first** to preview changes

## Cost Optimization & Scaling

### Current Resource Sizing (Development)

**Optimized for cost-effective development and testing:**

- **ECS Fargate**: 0.25 vCPU, 512 MB RAM per task
- **RDS**: db.t3.micro (1 vCPU, 1 GB RAM)
- **ALB**: Standard Application Load Balancer
- **NAT Gateway**: Single NAT Gateway for cost savings

**Estimated Monthly Cost**: ~$25-40 USD/month

### Production Scaling Recommendations

For production workloads, consider these adjustments:

```hcl
# In terraform/modules/ecs/main.tf
resource "aws_ecs_task_definition" "main" {
  cpu    = 512    # Scale up from 256
  memory = 1024   # Scale up from 512
}

# In terraform/modules/rds/main.tf  
resource "aws_db_instance" "main" {
  instance_class = "db.t3.small"  # Scale up from db.t3.micro
  multi_az       = true           # Already enabled
}
```

### Auto Scaling Configuration

**ECS Service Auto Scaling** (add to ECS module):
```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

### Cost Monitoring

**Track your AWS spending:**
```bash
# Get current month costs by service
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Set up billing alerts (one-time setup)
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget-config.json
```

## Cleanup

### Option 1: Standard Terraform Destroy

```bash
cd terraform/
terraform destroy -auto-approve
```

### Option 2: Complete Cleanup (Recommended)

For complete resource cleanup including any orphaned resources:

```bash
# Run the comprehensive cleanup script
./cleanup.sh
```

This script will:
- Run `terraform destroy`
- Clean up ECR repository and images
- Remove CloudWatch log groups
- Delete orphaned network interfaces
- Stop any remaining ECS tasks
- Force delete RDS instances if needed

### Manual Verification

After cleanup, verify all resources are deleted:

```bash
# Check for remaining VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=user-management-vpc" --region us-east-1

# Check for ECR repository
aws ecr describe-repositories --repository-names user-management-microservice --region us-east-1

# Check for log groups
aws logs describe-log-groups --log-group-name-prefix /ecs/user-management --region us-east-1
```

**Note**: The cleanup script ensures 100% resource deletion, preventing any unexpected charges.

## Security Best Practices

### Network Security

- **Private Subnet Isolation**: ECS and RDS have no direct internet access
- **Security Group Rules**: Restrictive ingress rules (principle of least privilege)
- **VPC Flow Logs**: Enable for network traffic monitoring (optional)
- **NAT Gateway**: Controlled outbound access for private resources

### Application Security

- **Container Scanning**: ECR automatically scans images for vulnerabilities
- **IAM Roles**: ECS tasks use temporary credentials, no hardcoded keys
- **Encryption**: RDS encryption at rest enabled
- **HTTPS Ready**: ALB configured for SSL/TLS termination (add certificate as needed)

### Data Protection

- **Database Backups**: Automated RDS backups with 7-day retention
- **Multi-AZ**: Database failover capability for high availability
- **Log Encryption**: CloudWatch logs encrypted in transit and at rest
- **Parameter Validation**: Application should validate all user inputs

### Access Control

- **API Authentication**: Implement JWT/OAuth in application layer
- **Rate Limiting**: Consider adding to ALB or application level
- **IP Whitelisting**: Restrict ALB access to specific IPs if needed
- **Audit Logging**: CloudTrail enabled for API call tracking

### Production Hardening Checklist

```bash
# Enable VPC Flow Logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxxxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name VPCFlowLogs

# Enable CloudTrail (if not already enabled)
aws cloudtrail create-trail \
  --name user-management-audit \
  --s3-bucket-name your-cloudtrail-bucket

# Add SSL certificate to ALB (replace with your domain)
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS
```

## Important Notes

1. **Security**: The microservice runs in private subnets with no direct internet access
2. **Database Password**: Simple password for development (use Secrets Manager in production)
3. **Service Discovery**: Automatic DNS registration when containers restart
4. **Cost Optimization**: Uses smallest instances (t3.micro for RDS, minimal Fargate resources)
5. **Resilience**: Multi-AZ RDS and Fargate deployment across multiple subnets
6. **Container Security**: ECR repository with vulnerability scanning enabled
7. **Simplified Architecture**: Local state management for development ease

## Validation and Testing

### Additional Verification Steps

1. **Check ECS Task Health**:
   ```bash
   # Get running tasks
   aws ecs list-tasks \
     --cluster user-management-cluster \
     --service-name user-management-service \
     --desired-status RUNNING
   
   # Check task definition
   aws ecs describe-tasks \
     --cluster user-management-cluster \
     --tasks <task-arn-from-above>
   ```

2. **Check CloudWatch Logs**:
   ```bash
   # View application logs
   aws logs describe-log-streams \
     --log-group-name /ecs/user-management \
     --order-by LastEventTime \
     --descending
   
   # Get latest logs
   aws logs get-log-events \
     --log-group-name /ecs/user-management \
     --log-stream-name <log-stream-name>
   ```

3. **Test Database Connectivity**:
   ```bash
   # Check RDS instance status
   aws rds describe-db-instances \
     --db-instance-identifier user-management-db
   
   # Verify secrets manager
   aws secretsmanager get-secret-value \
     --secret-id user-management-db-password \
     --query SecretString --output text
   ```

### Step 6: API Testing (Public Access via ALB)

**Great news!** The microservice is now publicly accessible via the Application Load Balancer. Use the ALB DNS name from the Terraform outputs:

```bash
# Set your ALB DNS name (replace with actual output from terraform apply)
export ALB_DNS="user-management-alb-123456789.us-east-1.elb.amazonaws.com"

# Test root endpoint (API documentation)
curl -X GET http://$ALB_DNS/

# Health check
curl -X GET http://$ALB_DNS/health

# List all users (initially empty)
curl -X GET http://$ALB_DNS/users

# Create a user
curl -X POST http://$ALB_DNS/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# Create another user
curl -X POST http://$ALB_DNS/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Jane Smith", "email": "jane@example.com"}'

# List all users again (should show 2 users)
curl -X GET http://$ALB_DNS/users

# Get specific user by ID
curl -X GET http://$ALB_DNS/users/1

# Update user
curl -X PUT http://$ALB_DNS/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "John Updated", "email": "john.updated@example.com"}'

# Delete user
curl -X DELETE http://$ALB_DNS/users/2
```

**Browser Testing:**
- **API Documentation**: Visit `http://your-alb-dns-name/` to see available endpoints
- **Health Check**: Visit `http://your-alb-dns-name/health` 
- **User List**: Visit `http://your-alb-dns-name/users` to see all users

### After Rebuilding the Application

Since we updated the application code to fix the root route issue, you need to rebuild and redeploy:

```bash
# Rebuild and deploy the updated application
./build-and-push.sh

# Wait 2-3 minutes for ECS to deploy the new version
# Then test the root endpoint
curl http://your-alb-dns-name/
```

## Troubleshooting

### Common Issues and Solutions

#### Bootstrap Phase Issues

**Error**: `AccessDenied: User is not authorized to perform: s3:CreateBucket`
```bash
# Solution: Ensure your AWS user has the required permissions listed in prerequisites
aws iam get-user-policy --user-name <your-username> --policy-name <policy-name>
```

**Error**: `BucketAlreadyExists: The requested bucket name is not available`
```bash
# Solution: S3 bucket names must be globally unique
# Edit terraform/bootstrap/main.tf and change the bucket name:
bucket = "user-management-terraform-state-<your-initials>-$(date +%s)"
```

#### Infrastructure Deployment Issues

**Error**: `InvalidVpcID.NotFound`
```bash
# Solution: Ensure VPC module deployed successfully
terraform state show module.vpc.aws_vpc.main
```

**Error**: `TaskDefinition does not exist`
```bash
# Solution: Check ECS task definition and ECR image
aws ecs describe-task-definition --task-definition user-management
aws ecr describe-images --repository-name user-management-microservice
```

#### Application Issues

**Error**: `Cannot GET /` when accessing ALB DNS name
```bash
# Solution: The application was updated to include a root route
# Rebuild and redeploy the application:
./build-and-push.sh

# Wait 2-3 minutes and test again:
curl http://your-alb-dns-name/
```

**Error**: ALB returns 503 Service Unavailable
```bash
# Check ECS service health
aws ecs describe-services \
  --cluster user-management-cluster \
  --services user-management-service \
  --query 'services[0].deployments[0]'

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names user-management-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
```

**Error**: Database connection issues
```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier user-management-db

# Check ECS task logs
aws logs filter-log-events \
  --log-group-name /ecs/user-management \
  --start-time $(date -d '10 minutes ago' +%s)000
```

#### Docker/ECR Issues

**Error**: `no basic auth credentials`
```bash
# Solution: Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

**Error**: `repository does not exist`
```bash
# Solution: Create ECR repository first
aws ecr create-repository --repository-name user-management-microservice
```

#### ECS Service Issues

**Error**: ECS tasks keep stopping
```bash
# Check logs for errors
aws logs filter-log-events \
  --log-group-name /ecs/user-management \
  --start-time $(date -d '1 hour ago' +%s)000
```

**Error**: Database connection timeout
```bash
# Verify security groups and RDS status
aws rds describe-db-instances --db-instance-identifier user-management-db
aws ec2 describe-security-groups --group-ids <security-group-id>
```

#### State Management Issues

**Error**: `Error acquiring the state lock`
```bash
# Check who has the lock
terraform force-unlock <lock-id>
# Only use if you're certain no one else is running Terraform
```

**Error**: `Backend initialization required`
```bash
# Re-initialize backend
terraform init -reconfigure
```

### Getting Help

1. **AWS CLI Debug Mode**:
   ```bash
   aws --debug <command>
   ```

2. **Terraform Debug Mode**:
   ```bash
   TF_LOG=DEBUG terraform <command>
   ```

3. **Check Resource Status in AWS Console**:
   - ECS: https://console.aws.amazon.com/ecs/
   - RDS: https://console.aws.amazon.com/rds/
   - CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups

4. **Useful AWS CLI Commands**:
   ```bash
   # List all ECS clusters
   aws ecs list-clusters
   
   # List all RDS instances
   aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier'
   
   # List all S3 buckets
   aws s3 ls
   
   # Check current AWS configuration
   aws configure list
   ```

For additional support, check the AWS documentation for ECS, RDS, and VPC services.

---

## Summary

### What You've Deployed

**A production-ready, highly available microservice architecture featuring:**

✅ **Public Access**: Application Load Balancer with internet-facing endpoint  
✅ **Container Security**: Private ECR registry with vulnerability scanning  
✅ **Zero Trust Network**: Multi-layered security groups, private subnets  
✅ **High Availability**: Multi-AZ deployment across 2 availability zones  
✅ **Auto Healing**: ECS Fargate automatically replaces failed containers  
✅ **Database Resilience**: RDS Multi-AZ with automatic failover  
✅ **Observability**: CloudWatch logs, metrics, and Container Insights  
✅ **Cost Optimized**: Right-sized resources for development workloads  

### Architecture Highlights

- **🌐 Internet Access**: Public ALB endpoint for external API access
- **🔒 Security**: Private subnets with controlled outbound access via NAT Gateway  
- **📦 Container Management**: ECR repository with automated build/deploy pipeline
- **📊 Monitoring**: Comprehensive logging and metrics collection
- **💰 Cost Effective**: ~$25-40/month for development environment
- **🚀 Scalable**: Ready for production scaling with minimal changes

### Next Steps

1. **Custom Domain**: Add Route53 hosted zone and SSL certificate
2. **CI/CD Pipeline**: Integrate with GitHub Actions or AWS CodePipeline  
3. **Application Security**: Implement authentication/authorization
4. **Monitoring**: Set up CloudWatch alarms and dashboards
5. **Backup Strategy**: Configure automated RDS snapshots
6. **Performance Testing**: Load test your API endpoints

**🎉 Your microservice is now running on enterprise-grade AWS infrastructure!**

Use the ALB DNS name from Terraform outputs to access your API:
```bash
curl http://your-alb-dns-name/health
```