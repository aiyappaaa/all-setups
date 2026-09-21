cat << 'EOF' > setup-minikube.sh
#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
if [ "$TARGET_USER" = "root" ] && id "ubuntu" &>/dev/null; then
  TARGET_USER="ubuntu"
fi

echo "==> Setting up environment for user: ${TARGET_USER}"

echo "==> 1. Updating packages and installing prerequisites..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl wget apt-transport-https ca-certificates gnupg conntrack

echo "==> 2. Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm -f get-docker.sh
sudo systemctl enable --now docker

echo "==> 3. Adding ${TARGET_USER} to the docker group..."
sudo usermod -aG docker "$TARGET_USER"

echo "==> 4. Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64

echo "==> 5. Installing kubectl..."
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

echo "==> 6. Starting Minikube cluster as ${TARGET_USER}..."
sudo -u "$TARGET_USER" sg docker -c "minikube start --driver=docker"

echo "==> Setup complete! Verifying cluster nodes:"
sudo -u "$TARGET_USER" kubectl get nodes
EOF

chmod +x setup-minikube.sh
./setup-minikube.sh
