#!/bin/bash

# Exit imeediately if a pipeline returns a non-zero status
set -eo pipefail

# Get this script's path. Specifically the project root: /binderhub-deploy-gke/
DIR="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" >/dev/null 2>&1 && pwd )"

# Read in config file and assign variables
configFile="${DIR}/config.json"

echo "--> Reading configuration from ${configFile}"

GCP_ACCOUNT_EMAIL=$(jq -r '.gcp .email_account' "${configFile}")
GCP_PROJECT_ID=$(jq -r '.gcp .project_id' "${configFile}")
GCP_PROJECT_CREDS=$(jq -r '.gcp .credentials_file' "${configFile}")
GCP_REGION=$(jq -r '.gcp .region' "${configFile}")
GCP_ZONE=$(jq -r '.gcp .zone' "${configFile}")
GKE_CLUSTER_NAME=$(jq -r '.gke .cluster_name' "${configFile}")
GKE_NODE_COUNT=$(jq -r '.gke .node_count' "${configFile}")
GKE_MACHINE_TYPE=$(jq -r '.gke .machine_type' "${configFile}")

# Check that all variables are set non-zero, non-null
REQUIRED_VARS=" \
  GCP_ACCOUNT_EMAIL \
  GCP_PROJECT_ID \
  GCP_PROJECT_CREDS \
  GCP_REGION \
  GCP_ZONE \
  GKE_CLUSTER_NAME \
  GKE_NODE_COUNT \
  GKE_MACHINE_TYPE \
  "
for required_var in $REQUIRED_VARS ; do
  if [ -z "${!required_var}" ] || [ "x${!required_var}" == 'xnull' ] ; then
    echo "--> ${required_var} must be set for deployment" >&2
    exit 1
  fi
done

# Normalise region, zone and machine_type to remove spaces and have lowercase
GCP_REGION=$(echo "${GCP_REGION//[[:blank:]]/}" | tr "[:upper:]" "[:lower:]")
GCP_ZONE=$(echo "${GCP_ZONE//[[:blank:]]/}" | tr "[:upper:]" "[:lower:]")
GKE_MACHINE_TYPE=$(echo "${GKE_MACHINE_TYPE//[[:blank:]]/}" | tr "[:upper:]" "[:lower:]")

# Print configuration
echo "--> Configuration to deploy:
  GCP_ACCOUNT_EMAIL: ${GCP_ACCOUNT_EMAIL}
  GCP_PROJECT_ID: ${GCP_PROJECT_ID}
  GCP_PROJECT_CREDS: ${GCP_PROJECT_CREDS}
  GCP_REGION: ${GCP_REGION}
  GCP_ZONE: ${GCP_ZONE}
  GKE_CLUSTER_NAME: ${GKE_CLUSTER_NAME}
  GKE_MACHINE_TYPE: ${GKE_MACHINE_TYPE}
  GKE_NODE_COUNT: ${GKE_NODE_COUNT}
  " | tee "${DIR}"/read-config.log

# Deploy cluster using terraform
cd "${DIR}/terraform"
terraform init
terraform plan -out="gkeplan" \
  -var "credentials_file=${GCP_PROJECT_CREDS}" \
  -var "project_id=${GCP_PROJECT_ID}" \
  -var "region=${GCP_REGION}" \
  -var "zone=${GCP_ZONE}" \
  -var "cluster_name=${GKE_CLUSTER_NAME}" \
  -var "node_count=${GKE_NODE_COUNT}" \
  -var "machine_type=${GKE_MACHINE_TYPE}"
terraform apply "gkeplan"
cd "${DIR}"

# Get cluster credentials
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" --zone "${GCP_ZONE}" | tee "${DIR}"/gke-creds.log

# Check nodes are ready
nodeCount="$(kubectl get nodes | awk '{print $2}' | grep -c Ready)"
while [[ ${nodeCount} -ne ${GKE_NODE_COUNT} ]] ; do
  echo -n "$(date)"
  echo " : ${nodeCount} of ${GKE_NODE_COUNT} nodes ready"
  sleep 15
  nodeCount="$(kubectl get nodes | awk '{print $2}' | grep -c Ready)"
done

echo
echo "--> Cluster node status:"
kubectl get nodes | tee "${DIR}"/kubectl-status.log
echo

# Give Google account full permissions over the cluster
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user="${GCP_ACCOUNT_EMAIL}" | tee "${DIR}"/cluster-admin-role.log

# Check helm installation
helm=$(command -v helm3 || command -v helm)
HELM_VERSION=$($helm version --short | cut -f1 -d".")

if [ "${HELM_VERSION}" == "v3" ] ; then
  echo "--> You are running helm v3!"
elif [ "${HELM_VERSION}" == "v2" ] ; then
  echo "--> You have helm v2 installed, but we really recommend using helm v3."
  echo "    Please install helm 3 and rerun this script."
  exit 1
else
  echo "--> Helm not found. Please run setup.sh then rerun this script."
  exit 1
fi

$helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
$helm repo update
