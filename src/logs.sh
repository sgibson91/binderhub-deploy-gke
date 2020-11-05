#!/usr/bin/env bash

# Get this script's path
DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" >/dev/null 2>&1 && pwd)"

# Read config.json and get BinderHub name
configFile="${DIR}/config.json"
BINDERHUB_NAME=$(jq -r '.binderhub .name' "${configFile}")
BINDERHUB_NAME=$(echo "${BINDERHUB_NAME}" | tr -cd '[:alnum:]-.' | tr '[:upper:]' '[:lower:]' | sed -E -e 's/^([.-]+)//' -e 's/([.-]+)$//')

echo "--> Fetching JupyterHub logs"

# Get pod name of the JupyterHub
HUB_POD=$(kubectl --namespace "${BINDERHUB_NAME}" get pods -o=jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep "^hub-")

# Print the JupyterHub logs to the terminal
kubectl --namespace "${BINDERHUB_NAME}" logs "${HUB_POD}"
