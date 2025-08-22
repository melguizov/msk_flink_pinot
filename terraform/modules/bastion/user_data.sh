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
    python3 \
    python3-pip \
    docker \
    htop \
    vim \
    tmux

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_1.6.6_linux_amd64.zip

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Kafka CLI tools
cd /opt
wget https://downloads.apache.org/kafka/2.8.1/kafka_2.13-2.8.1.tgz
tar -xzf kafka_2.13-2.8.1.tgz
ln -s kafka_2.13-2.8.1 kafka
echo 'export PATH=$PATH:/opt/kafka/bin' >> /etc/profile
rm kafka_2.13-2.8.1.tgz

# Install Python packages for Kafka
pip3 install kafka-python aws-msk-iam-sasl-signer-python boto3

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

# Kafka aliases
alias kafka-topics='/opt/kafka/bin/kafka-topics.sh'
alias kafka-console-producer='/opt/kafka/bin/kafka-console-producer.sh'
alias kafka-console-consumer='/opt/kafka/bin/kafka-console-consumer.sh'

# AWS and Terraform aliases
alias tf='terraform'
alias k='kubectl'

# Environment
export PATH=$PATH:/opt/kafka/bin
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

# Create Kafka client properties template
cat > /home/ec2-user/kafka-client.properties << 'EOF'
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

chown ec2-user:ec2-user /home/ec2-user/kafka-client.properties

# Create welcome message
cat > /etc/motd << 'EOF'
================================================================================
                          MSK-Flink-Pinot Bastion Host
================================================================================

Welcome to your development bastion host!

Available tools:
  - AWS CLI v2
  - Terraform
  - kubectl
  - Kafka CLI tools
  - Git, Docker, Python3
  - Java 11 (Amazon Corretto)

Quick start:
  1. Run: ./setup-aws-profile.sh (to configure AWS credentials)
  2. Navigate to: cd workspace/msk_flink_pinot/terraform
  3. Initialize: terraform init
  4. Deploy: terraform apply

Kafka tools are available in PATH:
  - kafka-topics
  - kafka-console-producer
  - kafka-console-consumer

Configuration files:
  - ~/kafka-client.properties (MSK SASL/IAM config)

================================================================================
EOF

# Log installation completion
echo "Bastion host setup completed at $(date)" >> /var/log/user-data.log
