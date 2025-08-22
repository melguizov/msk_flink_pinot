#!/bin/bash

# Development Environment Validation Script
# Validates environment dependencies and configuration before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="dev"
PROJECT_ROOT="/Users/daniel.melguizo/Documents/repositories/msk_flink_pinot/terraform"
ENV_DIR="$PROJECT_ROOT/envs/$ENVIRONMENT"

echo -e "${BLUE}🔍 MSK-Flink-Pinot Development Environment Validation${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Validation counters
CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

# Function to increment counters
pass_check() {
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
    print_status "$1"
}

fail_check() {
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
    print_error "$1"
}

warn_check() {
    WARNINGS=$((WARNINGS + 1))
    print_warning "$1"
}

# Check if environment directory exists
if [ ! -d "$ENV_DIR" ]; then
    fail_check "Environment directory not found: $ENV_DIR"
    exit 1
fi

cd "$ENV_DIR"

echo -e "${BLUE}🔧 System Dependencies${NC}"
echo "======================"

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    pass_check "AWS CLI found (version: $AWS_VERSION)"
else
    fail_check "AWS CLI not found - Required for deployment"
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | cut -d' ' -f2)
    pass_check "Terraform found (version: $TF_VERSION)"
else
    fail_check "Terraform not found - Required for deployment"
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || kubectl version --client --short 2>/dev/null | cut -d' ' -f3)
    pass_check "kubectl found (version: $KUBECTL_VERSION)"
else
    warn_check "kubectl not found - Recommended for EKS management"
fi

# Check Helm
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --template='{{.Version}}' 2>/dev/null)
    pass_check "Helm found (version: $HELM_VERSION)"
else
    warn_check "Helm not found - Recommended for Pinot management"
fi

# Check jq
if command -v jq &> /dev/null; then
    pass_check "jq found - JSON processing available"
else
    warn_check "jq not found - Recommended for JSON processing"
fi

echo ""

# AWS Configuration Checks
echo -e "${BLUE}☁️  AWS Configuration${NC}"
echo "====================="

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null | cut -d'/' -f2)
    pass_check "AWS credentials valid (Account: $AWS_ACCOUNT, User: $AWS_USER)"
else
    fail_check "AWS credentials not configured or invalid"
fi

# Check AWS region
AWS_REGION=$(aws configure get region 2>/dev/null || echo "")
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
    warn_check "AWS region not configured, using default: $AWS_REGION"
else
    pass_check "AWS region configured: $AWS_REGION"
fi

# Check AWS permissions (basic check)
if aws ec2 describe-regions --region $AWS_REGION &> /dev/null; then
    pass_check "Basic AWS permissions verified"
else
    fail_check "Insufficient AWS permissions for EC2 operations"
fi

# Check for existing resources that might conflict
echo ""
echo -e "${BLUE}🔍 Resource Conflict Check${NC}"
echo "=========================="

# Check for existing VPC with same name
EXISTING_VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=dev-vpc" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION 2>/dev/null)
if [ "$EXISTING_VPC" != "None" ] && [ "$EXISTING_VPC" != "" ]; then
    warn_check "Existing VPC found with name 'dev-vpc': $EXISTING_VPC"
    echo "   This may cause conflicts during deployment"
else
    pass_check "No conflicting VPC found"
fi

# Check for existing EKS cluster
EXISTING_EKS=$(aws eks describe-cluster --name dev-pinot-cluster --region $AWS_REGION --query 'cluster.name' --output text 2>/dev/null)
if [ "$EXISTING_EKS" == "dev-pinot-cluster" ]; then
    warn_check "Existing EKS cluster found: dev-pinot-cluster"
    echo "   This may cause conflicts during deployment"
else
    pass_check "No conflicting EKS cluster found"
fi

# Check for existing MSK cluster
EXISTING_MSK=$(aws kafka list-clusters --cluster-name-filter dev-msk-cluster --region $AWS_REGION --query 'ClusterInfoList[0].ClusterName' --output text 2>/dev/null)
if [ "$EXISTING_MSK" == "dev-msk-cluster" ]; then
    warn_check "Existing MSK cluster found: dev-msk-cluster"
    echo "   This may cause conflicts during deployment"
else
    pass_check "No conflicting MSK cluster found"
fi

echo ""

# Terraform Configuration Validation
echo -e "${BLUE}📋 Terraform Configuration${NC}"
echo "=========================="

# Check if Terraform files exist
if [ -f "main.tf" ]; then
    pass_check "main.tf found"
else
    fail_check "main.tf not found in environment directory"
fi

if [ -f "variables.tf" ]; then
    pass_check "variables.tf found"
else
    warn_check "variables.tf not found (using defaults)"
fi

# Initialize and validate Terraform
if terraform init -backend=false &> /dev/null; then
    pass_check "Terraform configuration syntax valid"
else
    fail_check "Terraform configuration has syntax errors"
fi

if terraform validate &> /dev/null; then
    pass_check "Terraform configuration validation passed"
else
    fail_check "Terraform configuration validation failed"
fi

echo ""

# Cost and Resource Analysis
echo -e "${BLUE}💰 Cost and Resource Analysis${NC}"
echo "=============================="

echo "Development Environment Resources:"
echo "• VPC: Multi-AZ (us-east-1a, us-east-1b)"
echo "• MSK: 3 × kafka.m5.large + 300GB storage"
echo "• EKS: 2 × t3.medium nodes + control plane"
echo "• Flink: 1-2 KPU Kinesis Analytics"
echo "• Pinot: Enhanced HA configuration"
echo ""

echo "Estimated Costs:"
echo "• Monthly: ~\$580"
echo "• Daily: ~\$19.30"
echo "• Hourly: ~\$0.80"
echo ""

echo "Resource Limits Check:"
# Check EC2 limits
EC2_LIMIT=$(aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A --region $AWS_REGION --query 'Quota.Value' --output text 2>/dev/null || echo "Unknown")
if [ "$EC2_LIMIT" != "Unknown" ] && [ "$EC2_LIMIT" != "None" ]; then
    if (( $(echo "$EC2_LIMIT >= 5" | bc -l) )); then
        pass_check "EC2 instance limit sufficient: $EC2_LIMIT"
    else
        warn_check "EC2 instance limit may be insufficient: $EC2_LIMIT (need at least 5)"
    fi
else
    warn_check "Could not check EC2 instance limits"
fi

echo ""

# Network Configuration Check
echo -e "${BLUE}🌐 Network Configuration${NC}"
echo "========================"

# Check available AZs
AVAILABLE_AZS=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[?State==`available`].ZoneName' --output text | wc -w)
if [ "$AVAILABLE_AZS" -ge 2 ]; then
    pass_check "Sufficient availability zones: $AVAILABLE_AZS"
else
    fail_check "Insufficient availability zones: $AVAILABLE_AZS (need at least 2)"
fi

# Check for default VPC (might cause conflicts)
DEFAULT_VPC=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION 2>/dev/null)
if [ "$DEFAULT_VPC" != "None" ] && [ "$DEFAULT_VPC" != "" ]; then
    pass_check "Default VPC exists: $DEFAULT_VPC"
else
    warn_check "No default VPC found (this is usually fine)"
fi

echo ""

# Security Check
echo -e "${BLUE}🔒 Security Configuration${NC}"
echo "========================="

# Check for existing key pairs
KEY_PAIRS=$(aws ec2 describe-key-pairs --region $AWS_REGION --query 'KeyPairs[].KeyName' --output text 2>/dev/null | wc -w)
if [ "$KEY_PAIRS" -gt 0 ]; then
    pass_check "EC2 key pairs available: $KEY_PAIRS"
else
    warn_check "No EC2 key pairs found (EKS nodes will use managed keys)"
fi

# Check IAM permissions for EKS
if aws iam list-roles --query 'Roles[?RoleName==`eksServiceRole`]' --output text &> /dev/null; then
    pass_check "EKS service role permissions available"
else
    warn_check "EKS service role not pre-created (will be created during deployment)"
fi

echo ""

# Final Summary
echo -e "${BLUE}📊 Validation Summary${NC}"
echo "===================="
echo -e "Checks passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks failed: ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

# Recommendations
if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}❌ Validation Failed${NC}"
    echo "Please fix the failed checks before proceeding with deployment."
    echo ""
    echo "Common fixes:"
    echo "• Install missing dependencies (AWS CLI, Terraform)"
    echo "• Configure AWS credentials: aws configure"
    echo "• Fix Terraform configuration syntax errors"
    echo "• Resolve resource conflicts"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Validation Passed with Warnings${NC}"
    echo "You can proceed with deployment, but consider addressing the warnings."
    echo ""
    echo "Recommended actions:"
    echo "• Install kubectl and Helm for better cluster management"
    echo "• Review resource conflicts and existing resources"
    echo "• Verify AWS service limits"
    echo ""
    echo -e "${GREEN}✅ Ready for deployment!${NC}"
    echo "Run: $PROJECT_ROOT/scripts/deploy-dev.sh"
else
    echo -e "${GREEN}✅ All Validations Passed!${NC}"
    echo "Your environment is ready for development deployment."
    echo ""
    echo -e "${GREEN}🚀 Ready to deploy!${NC}"
    echo "Run: $PROJECT_ROOT/scripts/deploy-dev.sh"
fi

echo ""

# Next steps
echo -e "${BLUE}🚀 Next Steps${NC}"
echo "============="
echo "1. Review the validation results above"
echo "2. Address any failed checks or warnings"
echo "3. Run the deployment script:"
echo "   $PROJECT_ROOT/scripts/deploy-dev.sh"
echo ""
echo "4. After deployment, access your resources:"
echo "   • Pinot UI: kubectl port-forward -n pinot-dev svc/pinot-controller 9000:9000"
echo "   • EKS cluster: aws eks update-kubeconfig --name dev-pinot-cluster"
echo ""

# Cost reminder
echo -e "${YELLOW}💰 Cost Reminder${NC}"
echo "================"
echo "Development environment costs ~\$580/month"
echo "Remember to destroy when not in use: $PROJECT_ROOT/scripts/cleanup-dev.sh"
echo ""

exit 0
