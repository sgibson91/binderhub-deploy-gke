#!/bin/bash

# Get this script's path. Specifically the project root: /binderhub-deploy-gke/
DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" >/dev/null 2>&1 && pwd)"

cd "${DIR}"/terraform ||
	find . -name terraform.tfstate || {
	echo >&2 "--> terraform state file not found. Please download and place terraform.tfstate in the terraform directory and re-run this script."
	exit 1
}
terraform destroy -auto-approve
