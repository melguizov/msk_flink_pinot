#!/bin/bash

echo "=== EKS Node Status Check ==="
echo "Checking if nodes are actually running..."
echo

# Update kubeconfig using the cluster name from terraform
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null)
if [ -z "$CLUSTER_NAME" ]; then
    echo "❌ Could not get cluster name from terraform output"
    exit 1
fi

echo "🔍 Cluster Name: $CLUSTER_NAME"
echo "🔧 Updating kubeconfig..."

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name "$CLUSTER_NAME" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Kubeconfig updated successfully"
    echo
    
    echo "📊 Checking nodes with kubectl..."
    kubectl get nodes -o wide
    
    echo
    echo "📊 Node count:"
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo "Total nodes: $NODE_COUNT"
    
    if [ "$NODE_COUNT" -eq 0 ]; then
        echo "❌ No nodes found in the cluster"
        echo
        echo "🔍 Checking node status details..."
        kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, status: .status.conditions[-1].type, ready: .status.conditions[-1].status}' 2>/dev/null || echo "jq not available"
    else
        echo "✅ Found $NODE_COUNT nodes"
        echo
        echo "📋 Node details:"
        kubectl describe nodes
    fi
else
    echo "❌ Failed to update kubeconfig - AWS credentials may not be configured"
    echo "💡 The nodes might be launching but kubectl access is not available"
fi

echo
echo "=== Check Complete ==="
