#!/usr/bin/env bash

# Get this script's path
DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" >/dev/null 2>&1 && pwd)"

# Read in config.json and get variables
echo "--> Reading in config.json"
configFile="${DIR}/config.json"
BINDERHUB_VERSION=$(jq -r '.binderhub .version' "${configFile}")
BINDERHUB_NAME=$(jq -r '.binderhub .name' "${configFile}")
BINDERHUB_NAME=$(echo "${BINDERHUB_NAME}" | tr -cd '[:alnum:]-.' | tr '[:upper:]' '[:lower:]' | sed -E -e 's/^([.-]+)//' -e 's/([.-]+)$//')

# Check helm version
helm=$(command -v helm3 || command -v helm)
HELM_VERSION=$($helm version -c --short | cut -f1 -d".")

if [ "${HELM_VERSION}" != 'v3' ]; then
	echo >&2 "--> You do not have helm3 installed; please install manually and re-run this script."
	exit 1
fi

# Pull and update helm chart repo
echo "--> Updating helm chart repo"
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo update

# Upgrade helm chart
echo "--> Upgrading ${BINDERHUB_NAME}'s helm chart with version ${BINDERHUB_VERSION}"
helm upgrade "${BINDERHUB_NAME}" jupyterhub/binderhub \
	--namespace "${BINDERHUB_NAME}" \
	--version="${BINDERHUB_VERSION}" \
	-f "${DIR}"/secret.yaml \
	-f "${DIR}"/config.yaml \
	--cleanup-on-fail \
	--timeout 10m0s \
	--wait

# Print Kubernetes pods
echo "--> Getting pods"
kubectl --namespace "${BINDERHUB_NAME}" get pods
