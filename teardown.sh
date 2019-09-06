#!/usr/bin/env bash

# Read in config.json
configFile='config.json'
BINDERHUB_NAME=`jq -r '.binderhub .name' ${configFile}`
GCP_PROJECT=`jq -r '.gcloud .project' ${configFile}`
ZONE=`jq -r '.gcloud .zone' ${configFile}`
CLUSTER_NAME=`echo ${BINDERHUB_NAME} | tr -cd '[:alnum:]-' | cut -c 1-59`-gke

# Purge the Helm release and delete the Kubernetes namespace
echo "--> Purging the helm chart"
helm delete ${BINDERHUB_NAME} --purge

echo "--> Deleting the namespace: ${BINDERHUB_NAME}"
kubectl delete namespace ${BINDERHUB_NAME}

# Delete Google Cloud Cluster
gcloud container clusters delete ${CLUSTER_NAME} --zone=${ZONE}

# Delete the Google Cloud project
gcloud projects delete ${GCP_PROJECT}

# TODO:
# - Manage kubectl config clusters and contexts
# - Print links to resources to check
