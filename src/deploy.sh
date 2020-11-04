#!/bin/bash

# Exit imeediately if a pipeline returns a non-zero status
set -eo pipefail

# Get this script's path. Specifically the project root: /binderhub-deploy-gke/
DIR="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" >/dev/null 2>&1 && pwd )"

# Read in config file and assign variables
configFile="${DIR}/config.json"

echo "--> Reading configuration from ${configFile}"

BINDERHUB_NAME=$(jq -r '.binderhub .name' "${configFile}")
BINDERHUB_VERSION=$(jq -r '.binderhub .version' "${configFile}")
DOCKER_ORG=$(jq -r '.docker .org' "${configFile}")
DOCKER_USERNAME=$(jq -r '.docker .username' "${configFile}")
DOCKER_PASSWORD=$(jq -r '.docker .password' "${configFile}")
GCP_ACCOUNT_EMAIL=$(jq -r '.gcp .email_account' "${configFile}")
GCP_PROJECT_ID=$(jq -r '.gcp .project_id' "${configFile}")
GCP_PROJECT_CREDS=$(jq -r '.gcp .credentials_file' "${configFile}")
GCP_REGION=$(jq -r '.gcp .region' "${configFile}")
GCP_ZONE=$(jq -r '.gcp .zone' "${configFile}")
GKE_NODE_COUNT=$(jq -r '.gke .node_count' "${configFile}")
GKE_MACHINE_TYPE=$(jq -r '.gke .machine_type' "${configFile}")
IMAGE_PREFIX=$(jq -r '.binderhub .image_prefix' "${configFile}")

# Check that all variables are set non-zero, non-null
REQUIRED_VARS=" \
  BINDERHUB_NAME \
  BINDERHUB_VERSION \
  GCP_ACCOUNT_EMAIL \
  GCP_PROJECT_ID \
  GCP_PROJECT_CREDS \
  GCP_REGION \
  GCP_ZONE \
  GKE_NODE_COUNT \
  GKE_MACHINE_TYPE \
  IMAGE_PREFIX \
  "
for required_var in $REQUIRED_VARS ; do
  if [ -z "${!required_var}" ] || [ "x${!required_var}" == 'xnull' ] ; then
    echo "--> ${required_var} must be set for deployment" >&2
    exit 1
  fi
done

# Generate valid name for GKE cluster
GKE_CLUSTER_NAME=$(echo "${BINDERHUB_NAME}" | tr -cd '[:alnum:]-' | tr '[:upper:]' '[:lower:]' | cut -c 1-59)
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME}-gke"

# Check if any optional variables are set null; if so, reset them to a
# zero-length string for later checks. If they failed to read at all,
# possibly due to an invalid JSON file, they will be returned as a
# zero-length string -- this is attempting to make the 'not set'
# value the same in either case.
if [ "x${DOCKER_ORG}" == 'xnull' ] ; then DOCKER_ORG='' ; fi
if [ "x${DOCKER_USERNAME}" == 'xnull' ] ; then DOCKER_USERNAME='' ; fi
if [ "x${DOCKER_PASSWORD}" == 'xnull' ] ; then DOCKER_PASSWORD='' ; fi

# Normalise region, zone and machine_type to remove spaces and have lowercase
GCP_REGION=$(echo "${GCP_REGION//[[:blank:]]/}" | tr "[:upper:]" "[:lower:]")
GCP_ZONE=$(echo "${GCP_ZONE//[[:blank:]]/}" | tr "[:upper:]" "[:lower:]")
GKE_MACHINE_TYPE=$(echo "${GKE_MACHINE_TYPE//[[:blank:]]/}" | tr "[:upper:]" "[:lower:]")

# Check/get user's Docker credentials
if [ -z "${DOCKER_USERNAME}" ] ; then
  if [ -n "${DOCKER_ORG}" ] ; then
    echo "--> Your Docker ID must be a member of the ${DOCKER_ORG} organisation"
  fi
  read -rp "Docker Hub ID: " DOCKER_USERNAME
  read -rsp "Docker Hub password: " DOCKER_PASSWORD
  echo
else
  if [ -z "${DOCKER_PASSWORD}" ] ; then
    read -rsp "Docker Hub password for ${DOCKER_USERNAME}: " DOCKER_PASSWORD
    echo
  fi
fi

# Print configuration
echo "--> Configuration to deploy:
  BINDERHUB_NAME: ${BINDERHUB_NAME}
  BINDERHUB_VERSION: ${BINDERHUB_VERSION}
  DOCKER_ORG: ${DOCKER_ORG}
  DOCKER_USERNAME: ${DOCKER_USERNAME}
  GCP_ACCOUNT_EMAIL: ${GCP_ACCOUNT_EMAIL}
  GCP_PROJECT_ID: ${GCP_PROJECT_ID}
  GCP_PROJECT_CREDS: ${GCP_PROJECT_CREDS}
  GCP_REGION: ${GCP_REGION}
  GCP_ZONE: ${GCP_ZONE}
  GKE_CLUSTER_NAME: ${GKE_CLUSTER_NAME}
  GKE_MACHINE_TYPE: ${GKE_MACHINE_TYPE}
  GKE_NODE_COUNT: ${GKE_NODE_COUNT}
  IMAGE_PREFIX: ${IMAGE_PREFIX}
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
HELM_VERSION=$($helm version -c --short | cut -f1 -d".")

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

# Setup helm repositories
$helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
$helm repo update

# Generate tokens for secrets file
apiToken=$(openssl rand -hex 32)
secretToken=$(openssl rand -hex 32)

# Generate initial config files for deployment
#
# Generate secrets file
echo "--> Generating secrets file"
sed -e "s/{apiToken}/${apiToken}/" \
  -e "s/{secretToken}/${secretToken}/" \
  -e "s/{dockerId}/${DOCKER_USERNAME}/" \
  -e "s/{dockerPassword}/${DOCKER_PASSWORD}/" \
  "${DIR}"/templates/secret-template.yaml > "${DIR}"/secret.yaml

# Generate initial config file
echo "--> Generating initial configuration file"
if [ -z "${DOCKER_ORG}" ] ; then
  sed -e "s/{imagePrefix}/${IMAGE_PREFIX}/" \
    -e "s/{dockerId}/${DOCKER_ORG}/" \
    "${DIR}"/templates/config-template.yaml > "${DIR}"/config.yaml
else
  sed -e "s/{imagePrefix}/${IMAGE_PREFIX}/" \
    -e "s/{dockerId}/${DOCKER_USERNAME}/" \
    "${DIR}"/templates/config-template.yaml > "${DIR}"/config.yaml
fi
