#!/usr/bin/env bash

# Get this script's path
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Read config.json and get BinderHub name
configFile="${DIR}/config.json"
BINDERHUB_NAME=`jq -r '.binderhub .name' ${configFile}`

echo "--> Fetching JupyterHub logs"

# Get pod name of the JupyterHub
HUB_POD=`kubectl get pods -n ${BINDERHUB_NAME} -o=jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep "^hub-"`

# Print the JupyterHub logs to the terminal
kubectl logs ${HUB_POD} -n ${BINDERHUB_NAME}
