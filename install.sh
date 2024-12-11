#!/bin/bash
# This script initates sync with a github repo and deploys the helm charts there.

# Deploy specific variables:
git_repo_url=https://github.com/ABB-PAEN/ei-raspberryk3s-test.git
acr_user=534e86a1-7035-4c51-b829-63b0af4f70db
edgeinsight_acr="edgeinsight.azurecr.io"
clusterrole_telegraf="edge-telegraf"

read -r -p "Enter you github username: " git_user
read -r -p "Enter you github password: " git_pwd
sleep 2
echo "The ACR password can be located in Azure Key Vault: https://portal.azure.com/#@ABB.onmicrosoft.com/asset/Microsoft_Azure_KeyVault/Secret/https://deploy-edgeinsight.vault.azure.net/secrets/edgeinsight-acr-pull--password/f509657c48054d00aeffe01e4ac29dd7"
read -r -p "Enter you acr password: " acr_pwd

# Get the port argocd is running on
echo "Getting the port argocd is running on..."
PORT=$(kubectl get svc -n argocd -o go-template='{{range .items}}{{range .spec.ports}}{{if eq .port 80}}{{.nodePort}}{{"\n"}}{{end}}{{end}}{{end}}')
echo "The port is $PORT"

sleep 1
# Kubeconfig as env
echo "Setting kubeconfig as an environment variable..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Add secret to pull from EdgeInsight container registry
secret_name="edgeinsight"
# Check if the secret already exists
if kubectl get secret "$secret_name" >/dev/null 2>&1; then
    echo "Secret '$secret_name' already exists. Skipping creation."
else
echo "Adding secret to pull from EdgeInsight container registry..."
kubectl create secret docker-registry $secret_name --docker-server=edgeinsight.azurecr.io --docker-username=$acr_user --docker-password=$acr_pwd
fi
sleep 1
# Get password to access argocd
echo "Getting password to access argocd..."
sleep 3
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "The password is $PASSWORD"

sleep 1
# Login to argocd
echo "Logging in to argocd..."
argocd login localhost:$PORT --username admin --password $PASSWORD

sleep 1
echo "Add edgeinsight acr to argocd"
if argocd repo list | grep "$edgeinsight_acr"; then
    echo "EdgeInsight ACR repo already added to Argo CD. Skipping..."
else
argocd repo add $edgeinsight_acr --username=$acr_user --password=$acr_pwd --type helm --name edgeinsight --enable-oci
fi
sleep 1
# Add your new repo to argo:
echo "Check if the repository exists"
tmp_url="${git_repo_url#https://}"

if git ls-remote "https://$git_pwd@$tmp_url" -q >/dev/null 2>&1; then
    echo "Git repository found!"
    # Continue with the rest of your script...
    # ...
else
    echo "Git repository not found. Exiting..."
    exit 1
fi
echo "Add $git_repo_url repo to argo for deployment"
if argocd repo list | grep "$git_repo_url"; then
    echo "Git repo already added to Argo CD. Skipping..."
else
argocd repo add $git_repo_url --username=$git_user --password=$git_pwd
fi
# Establish argocd project
kubectl apply -f project.yaml -n argocd
sleep 3
# Deploy the apps from your repository and start sync
echo "Add default context to argo"
argocd cluster add default --in-cluster
echo
echo
echo "Deploy apps and setup sync to github repo"
sleep 2
kubectl apply -f applicationset.yaml -n argocd
sleep 6
# To allow Telegraf to pull metrics from kubernetes, run the following command:
echo "Add clusterrolebinding to allow Telegraf to pull metrics from kubernetes"
if kubectl get clusterrolebinding "$clusterrole_telegraf" >/dev/null 2>&1; then
    echo "ClusterRoleBinding '$clusterrole_telegraf' already exists."
else
kubectl create clusterrolebinding $clusterrole_telegraf --clusterrole=cluster-admin --serviceaccount=default:telegraf 
sleep 2
fi
# Give the default user edgeadmin rights to connect to the data & monitoring rabbitmq vhosts:
echo "Give the default user edgeadmin rights to connect to the data & monitoring rabbitmq vhosts"
sleep 2
echo "Wait until the rabbitmq pod is ready"
kubectl get po -A | grep rabbitmq
sleep 2
kubectl wait --for=condition=Ready pod rabbitmq-0 --timeout=150s
echo
sleep 5
# Execute the command after the pod is ready
echo "Rabbitmq pod is now ready!"
sleep 2
echo
echo "Preparing rabbitmq permissions for edgeadmin user...."
kubectl exec rabbitmq-0 -- rabbitmqctl set_permissions -p data "edgeadmin" ".*" ".*" ".*" 
sleep 3
kubectl exec rabbitmq-0 -- rabbitmqctl set_permissions -p monitoring "edgeadmin" ".*" ".*" ".*" 
echo "Print the rabbitmq password for info:"
sleep 2
# To retreive the password for the default rabbitmq user edgeadmin, this command can be used:
kubectl get secret --namespace default rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 -d
echo ""
echo "To get password again run this command:"
echo "kubectl get secret --namespace default rabbitmq -o jsonpath="{.data.rabbitmq-password}" | base64 -d"
sleep 3
echo
echo
echo "To get the password for accessing argocd, run this command:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.passwd}" | base64 -d"
sleep 4
echo "List all pods deployed:"
echo
echo
kubectl get po
echo
sleep 3
echo "Happy datastreaming!! :)"
echo
sleep 2
