#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# EC2 deployment script — Self-hosted LLM stack
# Author: Harishmaran Subbaiah Thirumaran
#
# Usage:
#   export HF_TOKEN=your_huggingface_token
#   ./scripts/deploy-ec2.sh [instance-type] [region]
#
# Recommended instance types:
#   GPU:  g4dn.xlarge (T4 — 16 GB VRAM)  ~$0.526/hr
#   GPU:  g5.xlarge   (A10G — 24 GB VRAM) ~$1.006/hr
#   CPU:  c5.2xlarge  (for small models)  ~$0.34/hr
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

INSTANCE_TYPE=${1:-"g4dn.xlarge"}
REGION=${2:-"eu-west-1"}
KEY_NAME="llm-demo-key"
SG_NAME="llm-demo-sg"
AMI="ami-0c7bdd1ecada8e24c"   # Amazon Linux 2023 (eu-west-1) — update per region

echo "🚀 Deploying LLM stack to EC2..."
echo "   Instance : $INSTANCE_TYPE"
echo "   Region   : $REGION"

# ── Key pair ──────────────────────────────────────────────────────────────────
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &>/dev/null; then
  echo "Creating key pair..."
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query "KeyMaterial" \
    --output text > "${KEY_NAME}.pem"
  chmod 400 "${KEY_NAME}.pem"
  echo "Key saved to ${KEY_NAME}.pem"
fi

# ── Security group ────────────────────────────────────────────────────────────
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --region "$REGION" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || echo "None")

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
  echo "Creating security group..."
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "LLM demo — Streamlit + vLLM" \
    --region "$REGION" \
    --query "GroupId" \
    --output text)

  # Streamlit UI
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port 8501 --cidr 0.0.0.0/0 --region "$REGION"

  # vLLM API (restrict to your IP in production)
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port 8000 --cidr 0.0.0.0/0 --region "$REGION"

  # SSH
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION"
fi

# ── User data ─────────────────────────────────────────────────────────────────
USER_DATA=$(cat << EOF
#!/bin/bash
yum update -y
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Docker Compose v2
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Clone and start
cd /home/ec2-user
git clone https://github.com/Harishmaranthirumaran/llm-deployment-demo.git
cd llm-deployment-demo
echo "HF_TOKEN=${HF_TOKEN:-}" > .env
docker compose --profile gpu up -d
EOF
)

# ── Launch instance ───────────────────────────────────────────────────────────
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --region "$REGION" \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=llm-demo},{Key=Owner,Value=harishmaran}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "✅ Instance launched: $INSTANCE_ID"
echo "   Waiting for public IP..."

sleep 10
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo ""
echo "═══════════════════════════════════════════"
echo "  Deployment complete"
echo "  Instance ID : $INSTANCE_ID"
echo "  Public IP   : $PUBLIC_IP"
echo "  Chat UI     : http://$PUBLIC_IP:8501  (ready in ~5 min)"
echo "  vLLM API    : http://$PUBLIC_IP:8000"
echo "  SSH         : ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo "═══════════════════════════════════════════"
