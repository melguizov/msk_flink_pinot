#!/bin/bash

# Development Environment Deployment Script
# Enhanced resources for active development workloads
# Estimated cost: ~$580/month

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
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

echo -e "${BLUE}🚀 MSK-Flink-Pinot Development Environment Deployment${NC}"
echo -e "${BLUE}===================================================${NC}"
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

# Check if running from correct directory
if [ ! -d "$ENV_DIR" ]; then
    print_error "Environment directory not found: $ENV_DIR"
    print_error "Please run this script from the project root or ensure the path is correct"
    exit 1
fi

# Pre-deployment checks
echo -e "${BLUE}📋 Pre-deployment Checks${NC}"
echo "================================"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi
print_status "AWS CLI found"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid."
    print_error "Please run: aws configure"
    exit 1
fi
print_status "AWS credentials valid"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform not found. Please install Terraform first."
    exit 1
fi
print_status "Terraform found"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl not found. You'll need it to manage the EKS cluster after deployment."
fi

# Check Helm
if ! command -v helm &> /dev/null; then
    print_warning "Helm not found. It's recommended for managing Pinot deployments."
fi

echo ""

# Display cost estimation
echo -e "${YELLOW}💰 Development Environment Cost Estimation${NC}"
echo "=============================================="
echo -e "Monthly Cost: ${YELLOW}~\$580/month${NC}"
echo -e "Daily Cost:   ${YELLOW}~\$19.30/day${NC}"
echo -e "Hourly Cost:  ${YELLOW}~\$0.80/hour${NC}"
echo ""
echo "Resources:"
echo "• MSK: 3 × kafka.m5.large + 300GB storage"
echo "• EKS: 2 × t3.medium nodes + control plane"
echo "• Flink: 1-2 KPU Kinesis Analytics"
echo "• VPC: Multi-AZ with NAT gateways"
echo "• Pinot: Enhanced configuration with HA"
echo ""

# Confirm deployment
echo -e "${YELLOW}⚠️  This will create AWS resources that incur costs!${NC}"
echo -e "${YELLOW}⚠️  Development environment is more expensive than POC${NC}"
echo ""
read -p "Do you want to proceed with the deployment? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deployment cancelled by user"
    exit 0
fi

# Change to environment directory
cd "$ENV_DIR"
print_status "Changed to environment directory: $ENV_DIR"

# Initialize Terraform
echo -e "${BLUE}🔧 Initializing Terraform${NC}"
echo "=========================="
if terraform init; then
    print_status "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi
echo ""

# Validate Terraform configuration
echo -e "${BLUE}✅ Validating Configuration${NC}"
echo "============================"
if terraform validate; then
    print_status "Terraform configuration is valid"
else
    print_error "Terraform configuration validation failed"
    exit 1
fi
echo ""

# Plan deployment
echo -e "${BLUE}📋 Planning Deployment${NC}"
echo "======================"
if terraform plan -out=dev.tfplan; then
    print_status "Terraform plan created successfully"
else
    print_error "Terraform planning failed"
    exit 1
fi
echo ""

# Final confirmation
echo -e "${YELLOW}🚨 Final Confirmation${NC}"
echo "====================="
echo "This will deploy the development environment with:"
echo "• Multi-AZ VPC with enhanced networking"
echo "• 3-broker MSK cluster (kafka.m5.large)"
echo "• 2-node EKS cluster (t3.medium)"
echo "• Managed Flink application"
echo "• Pinot with high availability configuration"
echo ""
echo -e "${YELLOW}Estimated deployment time: 15-20 minutes${NC}"
echo ""
read -p "Are you sure you want to apply this plan? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deployment cancelled by user"
    rm -f dev.tfplan
    exit 0
fi

# Apply deployment
echo -e "${BLUE}🚀 Deploying Infrastructure${NC}"
echo "============================"
echo -e "${YELLOW}Starting deployment at: $(date)${NC}"
echo ""

if terraform apply dev.tfplan; then
    print_status "Infrastructure deployed successfully!"
else
    print_error "Deployment failed"
    exit 1
fi

# Clean up plan file
rm -f dev.tfplan

echo ""
echo -e "${GREEN}🎉 Development Environment Deployed Successfully!${NC}"
echo "================================================="
echo ""

# Display important outputs
echo -e "${BLUE}📊 Important Information${NC}"
echo "========================"

# Get Terraform outputs
if terraform output > /dev/null 2>&1; then
    echo "EKS Cluster Name: $(terraform output -raw eks_cluster_name 2>/dev/null || echo 'N/A')"
    echo "MSK Cluster ARN: $(terraform output -raw kafka_cluster_arn 2>/dev/null || echo 'N/A')"
    echo "Flink Application: $(terraform output -raw flink_application_name 2>/dev/null || echo 'N/A')"
    echo "VPC ID: $(terraform output -raw vpc_id 2>/dev/null || echo 'N/A')"
fi

echo ""
echo -e "${BLUE}🔧 Next Steps${NC}"
echo "============="
echo "1. Configure kubectl for EKS:"
echo "   aws eks update-kubeconfig --region us-east-1 --name dev-pinot-cluster"
echo ""
echo "2. Verify EKS nodes:"
echo "   kubectl get nodes"
echo ""
echo "3. Check Pinot pods:"
echo "   kubectl get pods -n pinot-dev"
echo ""
echo "4. Access Pinot Controller:"
echo "   kubectl port-forward -n pinot-dev svc/pinot-controller 9000:9000"
echo "   Open: http://localhost:9000"
echo ""
echo "5. Get MSK bootstrap servers:"
echo "   aws kafka describe-cluster --cluster-arn \$(terraform output -raw kafka_cluster_arn) --query 'ClusterInfo.BrokerNodeGroupInfo.BrokerAZDistribution[0].BrokerEndpoints' --output text"
echo ""

# Post-deployment validation
echo -e "${BLUE}🔍 Post-deployment Validation${NC}"
echo "=============================="

# Check if EKS cluster is accessible
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null)
if [ ! -z "$EKS_CLUSTER_NAME" ]; then
    print_status "Configuring kubectl..."
    if aws eks update-kubeconfig --region us-east-1 --name "$EKS_CLUSTER_NAME" &> /dev/null; then
        print_status "kubectl configured for EKS cluster"
        
        # Wait a bit for nodes to be ready
        echo "Waiting for EKS nodes to be ready..."
        sleep 30
        
        if kubectl get nodes &> /dev/null; then
            NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
            print_status "EKS cluster has $NODE_COUNT nodes ready"
        else
            print_warning "EKS nodes not ready yet. This is normal for a new cluster."
        fi
    else
        print_warning "Could not configure kubectl automatically"
    fi
fi

echo ""
echo -e "${GREEN}✨ Development Environment Ready!${NC}"
echo "================================="
echo -e "Deployment completed at: ${GREEN}$(date)${NC}"
echo -e "Environment: ${GREEN}Development${NC}"
echo -e "Monthly cost: ${YELLOW}~\$580${NC}"
echo ""
echo -e "${BLUE}📚 Documentation:${NC}"
echo "• README: $ENV_DIR/README.md"
echo "• Cleanup: $SCRIPTS_DIR/cleanup-dev.sh"
echo ""
echo -e "${YELLOW}⚠️  Remember to destroy resources when not in use to avoid unnecessary costs!${NC}"
echo ""

# Optional: Create a reminder file
cat > "$ENV_DIR/.deployment_info" << EOF
Deployment Date: $(date)
Environment: Development
Estimated Monthly Cost: $580
Cleanup Script: $SCRIPTS_DIR/cleanup-dev.sh

To destroy this environment:
cd $ENV_DIR && terraform destroy
EOF

print_status "Deployment information saved to .deployment_info"
echo ""
echo -e "${GREEN}🚀 Happy developing!${NC}"
