#!/bin/bash

# Update system
yum update -y

# Install essential packages
yum install -y \
    git \
    wget \
    curl \
    unzip \
    java-11-amazon-corretto-headless \
    docker \
    htop \
    vim \
    tmux \
    gcc \
    openssl-devel \
    bzip2-devel \
    libffi-devel \
    zlib-devel \
    readline-devel \
    sqlite-devel \
    make

# Install Development Tools and Kafka development libraries
yum groupinstall "Development Tools" -y
yum install -y librdkafka-devel python3-devel

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Python 3.9 from source
cd /tmp
wget https://www.python.org/ftp/python/3.9.19/Python-3.9.19.tgz
tar xzf Python-3.9.19.tgz
cd Python-3.9.19
./configure --enable-optimizations --prefix=/usr/local
sudo make altinstall
cd /
rm -rf /tmp/Python-3.9.19*

# Create symlinks for python3.9
ln -sf /usr/local/bin/python3.9 /usr/local/bin/python3
ln -sf /usr/local/bin/python3.9 /usr/local/bin/python39
ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip3
ln -sf /usr/local/bin/pip3.9 /usr/local/bin/pip39

# Add Python 3.9 to PATH
echo 'export PATH=/usr/local/bin:$PATH' >> /etc/profile


# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Python packages for AWS (as ec2-user to avoid root privileges warning)
sudo -u ec2-user /usr/local/bin/pip3.9 install --user boto3

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Create workspace directory
mkdir -p /home/ec2-user/workspace
chown ec2-user:ec2-user /home/ec2-user/workspace

# Clone repository if URL provided
if [ ! -z "${git_repo_url}" ]; then
    cd /home/ec2-user/workspace
    sudo -u ec2-user git clone ${git_repo_url}
    chown -R ec2-user:ec2-user /home/ec2-user/workspace
fi

# Create useful aliases
cat >> /home/ec2-user/.bashrc << 'EOF'

# AWS and kubectl aliases
alias k='kubectl'

# Environment
export PATH=$PATH
export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
EOF

# Set up AWS credentials helper script
cat > /home/ec2-user/setup-aws-profile.sh << 'EOF'
#!/bin/bash
echo "Setting up AWS profile for MSK access..."
echo "Enter your AWS Access Key ID:"
read -r access_key
echo "Enter your AWS Secret Access Key:"
read -rs secret_key

aws configure set aws_access_key_id "$access_key" --profile wizeline_training
aws configure set aws_secret_access_key "$secret_key" --profile wizeline_training
aws configure set region us-east-1 --profile wizeline_training
aws configure set output json --profile wizeline_training

echo "AWS profile 'wizeline_training' configured successfully!"
EOF

chmod +x /home/ec2-user/setup-aws-profile.sh
chown ec2-user:ec2-user /home/ec2-user/setup-aws-profile.sh


# Create welcome message
cat > /etc/motd << 'EOF'
================================================================================
                          MSK-Flink-Pinot Bastion Host
================================================================================

Welcome to your development bastion host!

Available tools:
  - AWS CLI v2
  - kubectl
  - Git, Docker, Python 3.9
  - Java 11 (Amazon Corretto)

Quick start:
  1. Run: ./setup-aws-profile.sh (to configure AWS credentials)
  2. Navigate to: cd workspace/msk_flink_pinot
  3. Start working with Python, or other tools

================================================================================
EOF

# Log installation completion
echo "Bastion host setup completed at $(date)" >> /var/log/user-data.log
