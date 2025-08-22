#!/bin/bash

echo "=== EKS Node Group Debug Script ==="
echo "Checking EKS cluster and node group status..."
echo

# Set AWS region
export AWS_DEFAULT_REGION=us-east-1
echo "🌍 Using AWS Region: $AWS_DEFAULT_REGION"
echo

# Get cluster name from terraform output
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null)
if [ -z "$CLUSTER_NAME" ]; then
    echo "❌ Could not get cluster name from terraform output"
    exit 1
fi

echo "🔍 Cluster Name: $CLUSTER_NAME"
echo

# Check cluster status
echo "📊 Checking EKS cluster status..."
aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' --output table
echo

# Check node groups
echo "📊 Checking EKS node groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups' --output text)
if [ -z "$NODE_GROUPS" ]; then
    echo "❌ No node groups found!"
    exit 1
fi

echo "Found node groups: $NODE_GROUPS"
echo

# Check each node group status
for NODE_GROUP in $NODE_GROUPS; do
    echo "🔍 Node Group: $NODE_GROUP"
    aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP" \
        --query 'nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize,MinSize:scalingConfig.minSize,MaxSize:scalingConfig.maxSize,InstanceTypes:instanceTypes,CapacityType:capacityType}' \
        --output table
    echo
    
    # Check for any issues
    echo "📋 Node Group Health:"
    aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP" \
        --query 'nodegroup.health.issues' --output table
    echo
done

# Check actual nodes using kubectl
echo "🔍 Checking nodes with kubectl..."
if command -v kubectl &> /dev/null; then
    # Update kubeconfig
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1
    
    echo "📊 Current nodes:"
    kubectl get nodes -o wide
    echo
    
    echo "📊 Node status details:"
    kubectl describe nodes
    echo
else
    echo "⚠️  kubectl not found, skipping node check"
fi

# Check for any recent events
echo "📊 Recent EKS events (CloudTrail)..."
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/$CLUSTER_NAME" --query 'logGroups[*].logGroupName' --output table

echo
echo "=== Debug Complete ==="
