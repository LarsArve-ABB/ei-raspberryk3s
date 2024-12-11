#!/bin/bash
# This script sets up k3s, installs helm3, adds a docker secret, a helm repo, and argocd, and logs in to argocd

# SETUP k3s
echo "Setting up k3s..."
sudo curl -fL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - server --cluster-init

# Helm3
echo "Installing helm3..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Kubeconfig as env
echo "Setting kubeconfig as an environment variable..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "Waiting on k3s to finish ..."
sleep 3
echo ".......be patient"
sleep 5

sleep 4

# Install argocd-cli
echo "Installing argocd-cli..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

sleep 3

# Install ArgoCd for gitops & EdgeInsight deployment
echo "Installing ArgoCd..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

sleep 2

echo "You are now ready to proceed with setting up sync to a github repo!"
echo "Please wait for argocd to be ready before proceeding."