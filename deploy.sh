#!/bin/bash

# Exit immediately if a pipeline returns a non-zero status
set -eo pipefail

# Get this script's path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

## Detection of the deploy mode
#
# This script should handle both interactive deployment when run by a user
# on their local system, and also running as a container entrypoint when
# used either for a container-based local deployment or when deployed via an
# Azure blue button setup.
#
# Check whether BINDERHUB_CONTAINER_MODE is set, and if so assume running
# as a container-based install, checking that all required input is present
# in the form of environment variables

if [ ! -z $BINDERHUB_CONTAINER_MODE ] ; then
  echo "--> Deployment operating in container mode"
  echo "--> Checking required environment variables"
  # Set out a list of required variables for this script
  REQUIREDVARS=" \
          SERVICE_ACCOUNT \
          SERVICE_ACCOUNT_KEYFILE \
          GCP_PROJECT \
          BINDERHUB_NAME \
          BINDERHUB_VERSION \
          NODE_COUNT \
          NODE_MACHINE_TYPE \
          CONTACT_EMAIL \
          DOCKER_USERNAME \
          DOCKER_PASSWORD \
          DOCKER_IMAGE_PREFIX \
          DOCKER_ORGANISATION \
          "
  for required_var in $REQUIREDVARS ; do
    if [ -z "${!required_var}" ] ; then
      echo "--> ${required_var} must be set for container-based setup" >&2
      exit 1
    fi
  done

  echo "--> Configuration parsed from blue button:
    GCP_PROJECT: ${GCP_PROJECT}
    BINDERHUB_NAME: ${BINDERHUB_NAME}
    BINDERHUB_VERSION: ${BINDERHUB_VERSION}
    CONTACT_EMAIL: ${CONTACT_EMAIL}
    GCP_ZONE: ${GCP_ZONE}
    RESOURCE_GROUP_NAME: ${RESOURCE_GROUP_NAME}
    NODE_COUNT: ${NODE_COUNT}
    MACHINE_TYPE: ${MACHINE_TYPE}
    SERVICE_ACCOUNT: ${SERVICE_ACCOUNT}
    SERVICE_ACCOUNT_KEYFILE: ${SERVICE_ACCOUNT_KEYFILE}
    DOCKER_USERNAME: ${DOCKER_USERNAME}
    DOCKER_IMAGE_PREFIX: ${DOCKER_IMAGE_PREFIX}
    DOCKER_ORGANISATION: ${DOCKER_ORGANISATION}
    " | tee read-config.log

  # Check if DOCKER_ORGANISATION is set to null. Return empty string if true.
  if [ x${DOCKER_ORGANISATION} == 'xnull' ] ; then DOCKER_ORGANISATION='' ; fi

else

  # Read in config file and assign variables for the non-container case
  configFile="${DIR}/config.json"

  echo "--> Reading configuration from ${configFile}"

  BINDERHUB_NAME=`jq -r '.binderhub .name' ${configFile}`
  BINDERHUB_VERSION=`jq -r '.binderhub .version' ${configFile}`
  CONTACT_EMAIL=`jq -r '.binderhub .contact_email' ${configFile}`
  GCP_PROJECT=`jq -r '.gcloud .project' ${configFile}`
  GCP_ZONE=`jq -r '.gcloud .zone' ${configFile}`
  NODE_COUNT=`jq -r '.gcloud .node_count' ${configFile}`
  MACHINE_TYPE=`jq -r '.gcloud .machine_type' ${configFile}`
  SERVICE_ACCOUNT=`jq -r '.gcloud .service_account' ${configFile}`
  SERVICE_ACCOUNT_KEYFILE=`jq -r '.gcloud .key_file' ${configFile}`
  DOCKER_USERNAME=`jq -r '.docker .username' ${configFile}`
  DOCKER_PASSWORD=`jq -r '.docker .password' ${configFile}`
  DOCKER_IMAGE_PREFIX=`jq -r '.docker .image_prefix' ${configFile}`
  DOCKER_ORGANISATION=`jq -r '.docker .org' ${configFile}`

  # Check that the variables are all set non-zero, non-null
  REQUIREDVARS=" \
          GCP_ZONE \
          GCP_PROJECT \
          BINDERHUB_NAME \
          BINDERHUB_VERSION \
          NODE_COUNT \
          MACHINE_TYPE \
          CONTACT_EMAIL \
          DOCKER_IMAGE_PREFIX \
          "
  for required_var in $REQUIREDVARS ; do
    if [ -z "${!required_var}" ] || [ x${!required_var} == 'xnull' ] ; then
      echo "--> ${required_var} must be set for deployment" >&2
      exit 1
    fi
  done

  # Check if any optional variables are set null; if so, reset them to a
  # zero-length string for later checks. If they failed to read at all,
  # possibly due to an invalid json file, they will be returned as a
  # zero-length string -- this is attempting to make the 'not set'
  # value the same in either case.
  if [ x${SERVICE_ACCOUNT} == 'xnull' ] ; then SERVICE_ACCOUNT='' ; fi
  if [ x${SERVICE_ACCOUNT_KEYFILE} == 'xnull' ] ; then SERVICE_ACCOUNT_KEYFILE='' ; fi
  if [ x${DOCKER_USERNAME} == 'xnull' ] ; then DOCKER_USERNAME='' ; fi
  if [ x${DOCKER_PASSWORD} == 'xnull' ] ; then DOCKER_PASSWORD='' ; fi
  if [ x${DOCKER_ORGANISATION} == 'xnull' ] ; then DOCKER_ORGANISATION='' ; fi

  # Normalise resource group location to remove spaces and have lowercase
  GCP_ZONE=`echo ${GCP_ZONE//[[:blank:]]/} | tr '[:upper:]' '[:lower:]'`

  echo "--> Configuration read in:
    GCP_PROJECT: ${GCP_PROJECT}
    BINDERHUB_NAME: ${BINDERHUB_NAME}
    BINDERHUB_VERSION: ${BINDERHUB_VERSION}
    CONTACT_EMAIL: ${CONTACT_EMAIL}
    GCP_ZONE: ${GCP_ZONE}
    NODE_COUNT: ${NODE_COUNT}
    MACHINE_TYPE: ${MACHINE_TYPE}
    SERVICE_ACCOUNT: ${SERVICE_ACCOUNT}
    SERVICE_ACCOUNT_KEYFILE: ${SERVICE_ACCOUNT_KEYFILE}
    DOCKER_USERNAME: ${DOCKER_USERNAME}
    DOCKER_IMAGE_PREFIX: ${DOCKER_IMAGE_PREFIX}
    DOCKER_ORGANISATION: ${DOCKER_ORGANISATION}
    " | tee read-config.log

  # Check/get the user's Docker credentials
  if [ -z $DOCKER_USERNAME ] ; then
    if [ ! -z "$DOCKER_ORGANISATION" ]; then
      echo "--> Your docker ID must be a member of the ${DOCKER_ORGANISATION} organisation"
    fi
    read -p "DockerHub ID: " DOCKER_USERNAME
    read -sp "DockerHub password: " DOCKER_PASSWORD
    echo
  else
    if [ -z $DOCKER_PASSWORD ] ; then
      read -sp "DockerHub password for ${DOCKER_USERNAME}: " DOCKER_PASSWORD
      echo
    fi
  fi
fi

set -eo pipefail

# Generate a valid name for the GKE cluster
CLUSTER_NAME=`echo ${BINDERHUB_NAME} | tr -cd '[:alnum:]-' | tr '[:upper:]' '[:lower:]' | cut -c 1-59`-gke

# Azure login will be different depending on whether this script is running
# with or without service principal details supplied.
#
# If all the SP environments are set, use those. Otherwise, fall back to an
# interactive login.

GCLOUD="gcloud --project=${GCP_PROJECT}"

if [ -z $SERVICE_ACCOUNT_KEYFILE ] || [ -z $SERVICE_ACCOUNT ] ; then

  an_account_exists=$(gcloud auth list --format json | jq '.[0].account')
  if [ "x${an_account_exists}" = "xnull" ]; then
    echo "--> Attempting to log in to Google Cloud"
    if ! gcloud auth login; then
        echo "--> Unable to connect to Google Cloud" >&2
        exit 1
    else
        echo "--> Logged in to Google Cloud"
    fi
  fi
else
  echo "--> Attempting to log in to Google Cloud with service account ${SERVICE_ACCOUNT} (${SERVICE_ACCOUNT_KEYFILE})"
  if ! gcloud auth activate-service-account --key-file "${SERVICE_ACCOUNT_KEYFILE}"; then
    echo "--> Unable to connect to Google" >&2
    exit 1
  else
      echo "--> Logged in to Google Cloud"
      # Use this service principal for AKS creation
      SA="--account ${SERVICE_ACCOUNT}"
  fi
fi

# Activate chosen subscription
if [ ! -z "${SERVICE_ACCOUNT}" ]; then
  echo "--> Activating Service Account: ${SERVICE_ACCOUNT}"
  GCLOUD="${GCLOUD} ${SA}"
fi

# Create an AKS cluster
echo "--> Creating AKS cluster; this may take a few minutes to complete
Cluster name:   ${CLUSTER_NAME}
Node count:     ${NODE_COUNT}
Node VM size:   ${MACHINE_TYPE}"
$GCLOUD container clusters create \
  --machine-type ${MACHINE_TYPE} \
  --num-nodes ${NODE_COUNT} \
  --zone ${GCP_ZONE} \
  --cluster-version latest \
  "${CLUSTER_NAME}"

# Check nodes are ready
nodecount="$(kubectl get node | awk '{print $2}' | grep Ready | wc -l)"
while [[ ${nodecount} -ne ${NODE_COUNT} ]] ; do echo -n $(date) ; echo " : ${nodecount} of ${NODE_COUNT} nodes ready" ; sleep 15 ; nodecount="$(kubectl get node | awk '{print $2}' | grep Ready | wc -l)" ; done
echo
echo "--> Cluster node status:"
kubectl get node | tee kubectl-status.log
echo

# Setup ServiceAccount for tiller
echo "--> Setting up tiller service account"
kubectl --namespace kube-system create serviceaccount tiller | tee tiller-service-account.log

# Give the ServiceAccount full permissions to manage the cluster
echo "--> Giving the ServiceAccount full permissions to manage the cluster"
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller | tee cluster-role-bindings.log

# Initialise helm and tiller
echo "--> Initialising helm and tiller"
helm init --service-account tiller --wait | tee helm-init.log

# Secure tiller against attacks from within the cluster
echo "--> Securing tiller against attacks from within the cluster"
kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]' | tee tiller-securing.log

# Waiting until tiller pod is ready
tillerStatus="$(kubectl get pods --namespace kube-system | grep ^tiller | awk '{print $3}')"
while [[ ! x${tillerStatus} == xRunning ]] ; do echo -n $(date) ; echo " : tiller pod status : ${tillerStatus} " ; sleep 30 ; tillerStatus="$(kubectl get pods --namespace kube-system | grep ^tiller | awk '{print $3}')" ; done
echo
echo "--> AKS system pods status:"
kubectl get pods --namespace kube-system | tee kubectl-get-pods.log
echo

# Check helm has been configured correctly
echo "--> Verify Client and Server are running the same version number:"
# Be error tolerant for this step
set +e
helmVersionAttempts=0
while ! helm version ; do
  ((helmVersionAttempts++))
  echo "--> helm version attempt ${helmVersionAttempts} of 3 failed"
  if (( helmVersionAttempts > 2 )) ; then
    echo "--> Please check helm versions manually later"
    break
  fi
  echo "--> Waiting 30 seconds before attempting helm version check again"
  sleep 30
done
# Revert to error-intolerance
set -eo pipefail

# Create tokens for the secrets file:
apiToken=`openssl rand -hex 32`
secretToken=`openssl rand -hex 32`

# Get the latest helm chart for BinderHub:
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo update

# Install the Helm Chart using the configuration files, to deploy both a BinderHub and a JupyterHub:
echo "--> Generating initial configuration file"
if [ -z "${DOCKER_ORGANISATION}" ] ; then
  sed -e "s/<docker-id>/$DOCKER_USERNAME/" \
  -e "s/<prefix>/$DOCKER_IMAGE_PREFIX/" \
  ${DIR}/config-template.yaml > ${DIR}/config.yaml
else
  sed -e "s/<docker-id>/$DOCKER_ORGANISATION/" \
  -e "s/<prefix>/$DOCKER_IMAGE_PREFIX/" \
  ${DIR}/config-template.yaml > ${DIR}/config.yaml
fi

echo "--> Generating initial secrets file"

sed -e "s/<apiToken>/$apiToken/" \
-e "s/<secretToken>/$secretToken/" \
-e "s/<docker-id>/$DOCKER_USERNAME/" \
-e "s/<password>/$DOCKER_PASSWORD/" \
${DIR}/secret-template.yaml > ${DIR}/secret.yaml

# Format name for kubernetes
HELM_BINDERHUB_NAME=$(echo ${BINDERHUB_NAME} | tr -cd '[:alnum:]-.' | tr '[:upper:]' '[:lower:]' | sed -E -e 's/^([.-]+)//' -e 's/([.-]+)$//' )

echo "--> Installing Helm chart"
helm install jupyterhub/binderhub \
--version=$BINDERHUB_VERSION \
--name=$HELM_BINDERHUB_NAME \
--namespace=$HELM_BINDERHUB_NAME \
-f ${DIR}/secret.yaml \
-f ${DIR}/config.yaml \
--timeout=3600 | tee helm-chart-install.log

# Wait for  JupyterHub, grab its IP address, and update BinderHub to link together:
echo "--> Retrieving JupyterHub IP"
JUPYTERHUB_IP=`kubectl --namespace=$HELM_BINDERHUB_NAME get svc proxy-public | awk '{ print $4}' | tail -n 1`
while [ "${JUPYTERHUB_IP}" = '<pending>' ] || [ "${JUPYTERHUB_IP}" = "" ]
do
    echo "Sleeping 30s before checking again"
    sleep 30
    JUPYTERHUB_IP=`kubectl --namespace=$HELM_BINDERHUB_NAME get svc proxy-public | awk '{ print $4}' | tail -n 1`
    echo "JupyterHub IP: ${JUPYTERHUB_IP}" | tee jupyterhub-ip.log
done

echo "--> Finalising configurations"
if [ -z "$DOCKER_ORGANISATION" ] ; then
  sed -e "s/<docker-id>/$DOCKER_USERNAME/" \
  -e "s/<prefix>/$DOCKER_IMAGE_PREFIX/" \
  -e "s/<jupyterhub-ip>/$JUPYTERHUB_IP/" \
  ${DIR}/config-template.yaml > ${DIR}/config.yaml
else
  sed -e "s/<docker-id>/$DOCKER_ORGANISATION/" \
  -e "s/<prefix>/$DOCKER_IMAGE_PREFIX/" \
  -e "s/<jupyterhub-ip>/$JUPYTERHUB_IP/" \
  ${DIR}/config-template.yaml > ${DIR}/config.yaml
fi

echo "--> Updating Helm chart"
helm upgrade $HELM_BINDERHUB_NAME jupyterhub/binderhub \
--version=$BINDERHUB_VERSION \
-f ${DIR}/secret.yaml \
-f ${DIR}/config.yaml | tee helm-upgrade.log

# Print Binder IP address
echo "--> Retrieving Binder IP"
BINDER_IP=`kubectl --namespace=$HELM_BINDERHUB_NAME get svc binder | awk '{ print $4}' | tail -n 1`
echo "Binder IP: ${BINDER_IP}" | tee binder-ip.log
while [ "${BINDER_IP}" = '<pending>' ] || [ "${BINDER_IP}" = "" ]
do
    echo "Sleeping 30s before checking again"
    sleep 30
    BINDER_IP=`kubectl --namespace=$HELM_BINDERHUB_NAME get svc binder | awk '{ print $4}' | tail -n 1`
    echo "Binder IP: ${BINDER_IP}" | tee binder-ip.log
done
