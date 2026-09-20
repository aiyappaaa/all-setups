# 1. Update packages and install prerequisites
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg

# 2. Install Docker using official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm -f get-docker.sh

# 3. Add ubuntu user to docker group (avoids running minikube as root)
sudo usermod -aG docker $USER
newgrp docker <<EONG

# 4. Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64

# 5. Install kubectl (with fixed URL)
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256

# 6. Start Minikube as regular user
minikube start --driver=docker
EONG
