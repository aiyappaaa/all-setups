#!/usr/bin/env bash

# ==============================================================================
# RUNTIME ENVIRONMENT & ERROR HANDLING
# ==============================================================================
# If executed via 'sh abc.sh' (which uses Dash on Ubuntu), switch immediately to Bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

# -e: Exit immediately if any command returns a non-zero exit code.
# -u: Treat unset or uninitialized variables as an error.
# -o pipefail: Catch pipeline errors if an earlier command in a pipe fails.
set -euo pipefail

# Verify root permissions using user ID (0 is always root)
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be executed as root." >&2
  exit 1
fi

# ==============================================================================
# FUNCTION: install_dependencies
# Checks if binaries exist in PATH so it never re-downloads tools on future runs.
# ==============================================================================
install_dependencies() {
  echo "==> [1/4] Checking and installing system packages..."
  apt-get update -y -qq >/dev/null
  apt-get install -y -qq curl wget apt-transport-https ca-certificates gnupg conntrack >/dev/null

  # 1. Docker Installation
  if ! command -v docker &>/dev/null; then
    echo "==> Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
  else
    echo "==> Docker is already installed."
  fi
  systemctl enable --now docker

  # 2. Minikube Installation
  if ! command -v minikube &>/dev/null; then
    echo "==> Downloading Minikube binary..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
  else
    echo "==> Minikube binary is already installed."
  fi

  # 3. kubectl Installation
  if ! command -v kubectl &>/dev/null; then
    echo "==> Downloading kubectl stable release..."
    local k8s_version
    k8s_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
  else
    echo "==> kubectl binary is already installed."
  fi
}

# ==============================================================================
# FUNCTION: start_cluster
# Checks prerequisites, launches the cluster with the root override, and checks nodes.
# ==============================================================================
start_cluster() {
  install_dependencies

  echo "==> [2/4] Checking Minikube status..."
  if minikube status &>/dev/null; then
    echo "==> Minikube cluster is already up and running."
  else
    echo "==> [3/4] Starting Minikube cluster as root..."
    # --driver=docker: runs Kubernetes control plane inside a Docker container
    # --force: bypasses Minikube's built-in block against running as root
    minikube start --driver=docker --force
  fi

  echo "==> [4/4] Minikube is Ready! Active Cluster Nodes:"
  kubectl get nodes
}

# ==============================================================================
# FUNCTION: reset_cluster
# Deletes any broken or existing cluster and builds a fresh one from scratch.
# ==============================================================================
reset_cluster() {
  echo "==> Deleting existing Minikube cluster..."
  minikube delete || true
  echo "==> Initializing fresh cluster..."
  start_cluster
}

# ==============================================================================
# FUNCTION: stop_cluster
# Pauses Minikube containers to free up EC2 CPU/RAM when taking a break.
# ==============================================================================
stop_cluster() {
  echo "==> Halting Minikube containers..."
  minikube stop
}

# ==============================================================================
# FUNCTION: status_cluster
# Shows component status (kubelet, apiserver) and node availability.
# ==============================================================================
status_cluster() {
  echo "==> Minikube Service Status:"
  minikube status || true
  echo ""
  echo "==> Cluster Nodes:"
  kubectl get nodes || true
}

# ==============================================================================
# SCRIPT ROUTER
# Defaults to 'start' when executed with no arguments (e.g. 'sh abc.sh').
# Supports: 'sh abc.sh reset', 'sh abc.sh stop', 'sh abc.sh status'
# ==============================================================================
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
    echo "Usage: $0 {start|reset|stop|status}"
    exit 1
    ;;
esac
