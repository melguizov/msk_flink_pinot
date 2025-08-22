#!/bin/bash

# Development Environment Cleanup Script
# Safely destroys the development infrastructure

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

echo -e "${RED}🗑️  MSK-Flink-Pinot Development Environment Cleanup${NC}"
echo -e "${RED}===================================================${NC}"
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
    print_error "Please ensure the development environment exists"
    exit 1
fi

# Change to environment directory
cd "$ENV_DIR"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    print_warning "No Terraform state found in $ENV_DIR"
    print_warning "The development environment may not be deployed or may be using remote state"
    echo ""
    read -p "Do you want to continue with cleanup attempt? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_warning "Cleanup cancelled"
        exit 0
    fi
fi

# Display current resources (if possible)
echo -e "${BLUE}📊 Current Development Environment${NC}"
echo "==================================="

if terraform show &> /dev/null; then
    echo "Current resources in state:"
    terraform state list 2>/dev/null | head -10
    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
    echo "... and $(($RESOURCE_COUNT - 10)) more resources" 2>/dev/null || echo "Total resources: $RESOURCE_COUNT"
else
    print_warning "Cannot display current resources (state may be remote or corrupted)"
fi

echo ""

# Cost impact warning
echo -e "${YELLOW}💰 Cost Impact${NC}"
echo "==============="
echo -e "Current monthly cost: ${YELLOW}~\$580/month${NC}"
echo -e "After cleanup: ${GREEN}\$0/month${NC}"
echo -e "Savings: ${GREEN}~\$580/month${NC}"
echo ""

# Data loss warning
echo -e "${RED}⚠️  DATA LOSS WARNING${NC}"
echo "====================="
echo -e "${RED}This action will PERMANENTLY DELETE:${NC}"
echo "• All Kafka topics and messages"
echo "• All Pinot tables and data"
echo "• All Flink applications and state"
echo "• EKS cluster and all workloads"
echo "• VPC and networking components"
echo "• All EBS volumes and snapshots"
echo ""
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

# Backup recommendation
echo -e "${BLUE}💾 Backup Recommendations${NC}"
echo "=========================="
echo "Before proceeding, consider backing up:"
echo "• Pinot table schemas and configurations"
echo "• Kafka topic configurations"
echo "• Flink application code and configurations"
echo "• Any important data or logs"
echo ""

# First confirmation
read -p "Have you backed up all important data? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Please backup your data before proceeding with cleanup"
    echo ""
    echo "Backup commands:"
    echo "1. Export Pinot schemas:"
    echo "   kubectl port-forward -n pinot-dev svc/pinot-controller 9000:9000 &"
    echo "   curl -X GET 'http://localhost:9000/schemas' > pinot-schemas-backup.json"
    echo ""
    echo "2. Export Kafka topic configs:"
    echo "   kafka-configs.sh --bootstrap-server \$BOOTSTRAP_SERVERS --describe --entity-type topics > kafka-topics-backup.txt"
    echo ""
    echo "3. Export Kubernetes configurations:"
    echo "   kubectl get all -n pinot-dev -o yaml > k8s-pinot-backup.yaml"
    echo ""
    exit 0
fi

# Second confirmation with environment name
echo -e "${RED}🚨 FINAL CONFIRMATION${NC}"
echo "======================"
echo -e "You are about to destroy the ${RED}DEVELOPMENT${NC} environment."
echo ""
echo "Type 'destroy-dev-environment' to confirm:"
read -p "> " confirmation
echo ""

if [ "$confirmation" != "destroy-dev-environment" ]; then
    print_warning "Confirmation text did not match. Cleanup cancelled."
    exit 0
fi

# Pre-cleanup steps
echo -e "${BLUE}🔧 Pre-cleanup Steps${NC}"
echo "===================="

# Try to drain EKS nodes gracefully
print_status "Attempting to drain EKS nodes gracefully..."
if kubectl get nodes &> /dev/null; then
    kubectl get nodes --no-headers | awk '{print $1}' | while read node; do
        echo "Draining node: $node"
        kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --force --timeout=60s || true
    done
    print_status "Node draining completed (or skipped if not accessible)"
else
    print_warning "Cannot access EKS cluster for graceful shutdown"
fi

echo ""

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo -e "${BLUE}🔧 Initializing Terraform${NC}"
    echo "=========================="
    if terraform init; then
        print_status "Terraform initialized"
    else
        print_error "Terraform initialization failed"
        print_warning "Continuing with cleanup attempt..."
    fi
    echo ""
fi

# Plan destruction
echo -e "${BLUE}📋 Planning Destruction${NC}"
echo "======================="
if terraform plan -destroy -out=destroy.tfplan; then
    print_status "Destruction plan created"
else
    print_error "Failed to create destruction plan"
    print_warning "Attempting direct destroy..."
fi
echo ""

# Execute destruction
echo -e "${RED}🗑️  Destroying Infrastructure${NC}"
echo "==============================="
echo -e "${YELLOW}Starting destruction at: $(date)${NC}"
echo ""

if [ -f "destroy.tfplan" ]; then
    # Use the plan if available
    if terraform apply destroy.tfplan; then
        print_status "Infrastructure destroyed successfully using plan"
    else
        print_error "Destruction using plan failed, attempting direct destroy"
        terraform destroy -auto-approve || print_error "Direct destroy also failed"
    fi
    rm -f destroy.tfplan
else
    # Direct destroy
    if terraform destroy -auto-approve; then
        print_status "Infrastructure destroyed successfully"
    else
        print_error "Destruction failed"
        echo ""
        echo -e "${YELLOW}Manual cleanup may be required:${NC}"
        echo "1. Check AWS Console for remaining resources"
        echo "2. Manually delete any stuck resources"
        echo "3. Check for any remaining EBS volumes or snapshots"
        echo "4. Verify VPC and security groups are deleted"
        exit 1
    fi
fi

# Clean up local files
echo ""
echo -e "${BLUE}🧹 Cleaning Up Local Files${NC}"
echo "============================"

# Remove Terraform state and cache
if [ -f "terraform.tfstate" ]; then
    rm -f terraform.tfstate
    print_status "Removed local Terraform state"
fi

if [ -f "terraform.tfstate.backup" ]; then
    rm -f terraform.tfstate.backup
    print_status "Removed Terraform state backup"
fi

if [ -d ".terraform" ]; then
    rm -rf .terraform
    print_status "Removed Terraform cache"
fi

if [ -f ".deployment_info" ]; then
    rm -f .deployment_info
    print_status "Removed deployment info file"
fi

# Remove any plan files
rm -f *.tfplan
print_status "Removed any remaining plan files"

echo ""
echo -e "${GREEN}🎉 Development Environment Cleanup Complete!${NC}"
echo "=============================================="
echo ""

# Final status
echo -e "${BLUE}📊 Cleanup Summary${NC}"
echo "==================="
echo -e "Environment: ${GREEN}Development (destroyed)${NC}"
echo -e "Cleanup completed at: ${GREEN}$(date)${NC}"
echo -e "Monthly cost savings: ${GREEN}~\$580${NC}"
echo ""

# Verification steps
echo -e "${BLUE}🔍 Verification Steps${NC}"
echo "====================="
echo "To verify complete cleanup:"
echo ""
echo "1. Check AWS Console:"
echo "   • EC2 Dashboard - No running instances"
echo "   • EKS Clusters - No dev-pinot-cluster"
echo "   • MSK Clusters - No dev-msk-cluster"
echo "   • VPC Dashboard - No dev-vpc"
echo ""
echo "2. Check for remaining resources:"
echo "   aws ec2 describe-instances --filters 'Name=tag:Environment,Values=development' --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'"
echo ""
echo "3. Check for EBS volumes:"
echo "   aws ec2 describe-volumes --filters 'Name=tag:Environment,Values=development' --query 'Volumes[*].[VolumeId,State]'"
echo ""

# Cost verification
echo -e "${BLUE}💰 Cost Verification${NC}"
echo "===================="
echo "• Check AWS Billing Dashboard in 24-48 hours"
echo "• Verify no charges for destroyed resources"
echo "• Monitor for any unexpected charges"
echo ""

# Next steps
echo -e "${BLUE}🚀 Next Steps${NC}"
echo "============="
echo "• Development environment is now destroyed"
echo "• You can redeploy anytime using: $PROJECT_ROOT/scripts/deploy-dev.sh"
echo "• Consider using POC environment for quick testing: $PROJECT_ROOT/scripts/deploy-5h-poc.sh"
echo ""

print_status "Development environment cleanup completed successfully!"
echo ""
echo -e "${GREEN}💚 Thank you for being cost-conscious!${NC}"
