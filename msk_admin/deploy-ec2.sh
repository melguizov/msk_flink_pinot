#!/bin/bash
# MSK Admin EC2 Deployment Script
# Usage: ./deploy-ec2.sh

set -e

echo "🚀 Starting MSK Admin deployment on EC2..."

# Check if running on EC2
if ! curl -s -m 5 http://169.254.169.254/latest/meta-data/instance-id > /dev/null; then
    echo "❌ This script should be run on an EC2 instance"
    exit 1
fi

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "📍 Instance: $INSTANCE_ID in region: $REGION"

# Update system packages
echo "📦 Updating system packages..."
if command -v yum &> /dev/null; then
    sudo yum update -y
    sudo yum install python3.11 python3.11-pip git -y
elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install python3.11 python3.11-venv python3.11-dev git -y
fi

# Create application directory
APP_DIR="/opt/msk-admin"
echo "📁 Creating application directory: $APP_DIR"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Clone repository (if not already present)
if [ ! -d "$APP_DIR/.git" ]; then
    echo "📥 Cloning MSK Admin repository..."
    git clone https://github.com/your-repo/msk-admin.git $APP_DIR
else
    echo "📥 Updating existing repository..."
    cd $APP_DIR && git pull
fi

cd $APP_DIR

# Create virtual environment
echo "🐍 Setting up Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Install application
echo "📦 Installing MSK Admin..."
pip install --upgrade pip
pip install -e .

# Setup configuration
echo "⚙️ Setting up configuration..."
if [ ! -f .env ]; then
    cp .env.production .env
    echo "📝 Created .env from production template"
    echo "⚠️  Please edit .env with your MSK cluster details:"
    echo "   - MSK_CLUSTER_ARN"
    echo "   - KAFKA_BOOTSTRAP"
    echo "   - GLUE_REGISTRY_NAME"
fi

# Create systemd service
echo "🔧 Creating systemd service..."
sudo tee /etc/systemd/system/msk-admin.service > /dev/null <<EOF
[Unit]
Description=MSK Admin Service
After=network.target

[Service]
Type=oneshot
User=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/msk-admin health
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable msk-admin

# Create log directory
sudo mkdir -p /var/log/msk-admin
sudo chown $USER:$USER /var/log/msk-admin

# Test installation
echo "🧪 Testing installation..."
source venv/bin/activate
if msk-admin --version; then
    echo "✅ MSK Admin installed successfully!"
else
    echo "❌ Installation test failed"
    exit 1
fi

echo ""
echo "🎉 Deployment completed!"
echo ""
echo "Next steps:"
echo "1. Edit configuration: nano $APP_DIR/.env"
echo "2. Test connection: cd $APP_DIR && source venv/bin/activate && msk-admin health"
echo "3. List topics: msk-admin topics list"
echo ""
echo "Service management:"
echo "- Start: sudo systemctl start msk-admin"
echo "- Status: sudo systemctl status msk-admin"
echo "- Logs: journalctl -u msk-admin"
