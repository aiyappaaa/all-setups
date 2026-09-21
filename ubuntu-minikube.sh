cat << 'EOF' > /root/minikube-lab.sh
#!/usr/bin/env bash

# ==============================================================================
# SCRIPT CONFIGURATION & ERROR HANDLING
# ==============================================================================
# -e: Exit immediately if any command returns a non-zero exit code.
# -u: Treat unset or uninitialized variables as an error and exit.
# -o pipefail: Pipeline fails if any command in the pipe fails (not just the last).
set -euo pipefail

# ==============================================================================
# PRIVILEGE VALIDATION
# ==============================================================================
# $EUID holds the Effective User ID. Root always has a User ID of 0.
# If EUID is not equal (-ne) to 0, stop execution to prevent permission failures.
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be executed as the root user." >&2
  exit 1
fi

# ==============================================================================
# FUNCTION: install_dependencies
# Idempotent check: Verifies if packages exist before downloading or installing.
# ==============================================================================
install_dependencies() {
  echo "==> [1/4] Checking and installing prerequisites..."
  # -qq: Quiet mode (suppresses standard progress bars to keep logs clean)
  # >/dev/null: Discards stdout so only actual errors are printed to screen
  apt-get update -y -qq >/dev/null
  apt-get install -y -qq curl wget apt-transport-https ca-certificates gnupg conntrack >/dev/null

  # Check if Docker is installed. 'command -v' exits with 0 if found, non-zero if missing.
  if ! command -v docker &>/dev/null; then
    echo "==> Docker not found. Installing via official convenience script..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
  fi

  # Ensure the Docker daemon is enabled on system boot and currently running
  systemctl enable --now docker

  # Check if Minikube binary exists in $PATH
  if ! command -v minikube &>/dev/null; then
    echo "==> Minikube not found. Downloading latest Linux AMD64 binary..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    # 'install' copies the file, sets ownership to root:root, and grants execute permissions (0755)
    install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
  fi

  # Check if kubectl binary exists in $PATH
  if ! command -v kubectl &>/dev/null; then
    echo "==> kubectl not found. Fetching stable release..."
    local k8s_version
    # Query the stable Kubernetes API to retrieve the current recommended version string (e.g., v1.31.0)
    k8s_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
  fi
}

# ==============================================================================
# FUNCTION: start_cluster
# Ensures dependencies exist, then boots or joins the Minikube cluster.
# ==============================================================================
start_cluster() {
  # Run dependency check first
  install_dependencies

  echo "==> [2/4] Checking Minikube status..."
  # If 'minikube status' succeeds (exit code 0), the cluster is already healthy
  if minikube status &>/dev/null; then
    echo "==> Minikube is already up and running."
  else
    echo "==> [3/4] Starting Minikube control plane..."
    # --driver=docker: Runs Kubernetes inside a Docker container
    # --force: Bypasses Minikube's built-in block that prevents running as root
    minikube start --driver=docker --force
  fi

  echo "==> [4/4] Verifying cluster nodes via kubectl:"
  kubectl get nodes
}

# ==============================================================================
# FUNCTION: reset_cluster
# Deletes the active cluster and recreates it from scratch for a clean lab.
# ==============================================================================
reset_cluster() {
  echo "==> Deleting current Minikube environment..."
  # '|| true' ensures that even if no cluster exists to delete, the script won't abort
  minikube delete || true
  echo "==> Initializing fresh cluster..."
  start_cluster
}

# ==============================================================================
# FUNCTION: stop_cluster
# Pauses container runtime to free up CPU and RAM on your EC2 instance.
# ==============================================================================
stop_cluster() {
  echo "==> Halting Minikube containers..."
  minikube stop
}

# ==============================================================================
# FUNCTION: status_cluster
# Shows component status (kubelet, apiserver, kubeconfig) and node status.
# ==============================================================================
status_cluster() {
  echo "==> Checking Minikube component health:"
  minikube status || true
  echo ""
  echo "==> Querying Kubernetes API for node readiness:"
  kubectl get nodes || true
}

# ==============================================================================
# SCRIPT ROUTER / CLI ARGUMENT PARSER
# ==============================================================================
# ${1:-start}: Reads the first argument passed in the terminal ($1).
# If no argument is provided, it defaults to "start".
case "${1:-start}" in
  start)
    start_cluster
    ;;
  reset)
    reset_cluster
    ;;
  stop)
    stop_cluster
    ;;
  status)
    status_cluster
    ;;
  *)
    # Display usage instructions if an unknown flag or parameter is supplied
    echo "Usage: $0 {start|reset|stop|status}"
    exit 1
    ;;
esac
EOF

# Grant execute permissions to the script file
chmod +x /root/minikube-lab.sh
