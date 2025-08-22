#!/bin/bash

echo "=== EKS Node Group Scaling Script ==="
echo "Scaling EKS node group to desired size..."
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

# Get node group name (assuming it's "main" based on the configuration)
NODE_GROUP_NAME="main"

echo "🔍 Node Group Name: $NODE_GROUP_NAME"
echo

# Check current scaling configuration
echo "📊 Current node group scaling configuration:"
aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP_NAME" \
    --query 'nodegroup.scalingConfig' --output table
echo

# Scale the node group to desired size
echo "🚀 Scaling node group to desired size (2 nodes)..."
aws eks update-nodegroup-config \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODE_GROUP_NAME" \
    --scaling-config minSize=1,maxSize=3,desiredSize=2

if [ $? -eq 0 ]; then
    echo "✅ Node group scaling update initiated successfully!"
    echo "⏳ This may take 2-5 minutes to complete..."
    echo
    
    # Monitor the update
    echo "📊 Monitoring update status..."
    while true; do
        STATUS=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP_NAME" \
                --query 'nodegroup.status' --output text)
        
        echo "Current status: $STATUS"
        
        if [ "$STATUS" = "ACTIVE" ]; then
            echo "✅ Node group is now ACTIVE!"
            break
        elif [ "$STATUS" = "UPDATE_FAILED" ]; then
            echo "❌ Node group update failed!"
            break
        fi
        
        sleep 30
    done
    
    echo
    echo "📊 Final scaling configuration:"
    aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$NODE_GROUP_NAME" \
        --query 'nodegroup.scalingConfig' --output table
        
else
    echo "❌ Failed to initiate node group scaling update"
    exit 1
fi

echo
echo "=== Scaling Complete ==="
