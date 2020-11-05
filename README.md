# Automatically deploy a BinderHub to Google Cloud

[![mit_license_badge](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[BinderHub](https://binderhub.readthedocs.io/en/latest/index.html) is a cloud-based, multi-server technology used for hosting repoducible computing environments and interactive Jupyter Notebooks built from code repositories.

This repository contains a set of scripts to automatically deploy a BinderHub onto [Google Cloud](https://cloud.google.com/) and connect a [Docker Hub](https://hub.docker.com/) account/organisation, so that you can host your own [Binder](https://mybinder.readthedocs.io/en/latest/) service.

This repository is based on the following set of deployment scripts for Google Cloud: [nicain/binder-deploy](https://github.com/nicain/binder-deploy) and the "Deploy to Azure" rpo [alan-turing-institute/binderhub-deploy](https://github.com/alan-turing-institute/binderhub-deploy).

You will require a Google Cloud account and project.
A Free Trial project can be obtained [here](https://cloud.google.com/free/).
You will be asked to provide a credit card for verification purposes.
**You will not be charged.**
Your resources will be frozen once your trial expires, then deleted if you do not reactivate your account within a given time period.
If you are building a BinderHub as a service for an organisation, your institution may already have a Google Cloud account.

**Table of Contents:**

- [:children_crossing: Usage](#children_crossing-usage)
  - [:key: Create a Service Account key](#key-create-a-service-account-key)
  - [:vertical_traffic_light: `setup.sh`](#vertical_traffic_light-setupsh)
  - [:rocket: `deploy.sh`](#rocket-deploysh)
  - [:bar_chart: `logs.sh`](#bar_chart-logssh)
  - [:information_source: `info.sh`](#ℹinformation_source-infosh)
  - [:arrow_up: `upgrade.sh`](#️arrow_up-upgradesh)
  - [:boom: `teardown.sh`](#boom-teardownsh)
- [:art: Customising your BinderHub Deployment](#art-customising-your-binderhub-deployment)

---

## :children_crossing: Usage

To use these scripts locally, clone this repo and change into the directory.

```bash
git clone https://github.com/alan-turing-institute/binderhub-deploy-gke.git
cd binderhub-deploy-gke
```

To run a script, do the following:

```bash
./src/<script-name>.sh
```

To build the BinderHub, you should run `setup.sh` first (to install the required command line tools), then `deploy.sh` (which will build the BinderHub).
Once the BinderHub is deployed, you can run `logs.sh` and `info.sh` to get the JupyterHub logs and service IP addresses respectively.
`teardown.sh` should _only_ be used to delete your BinderHub deployment.

You need to create a file called `config.json` which has the format described in the code block below.
Fill the quotation marks with your desired namespaces, etc.
`config.json` is git-ignored so sensitive information, such as passwords and Service Accounts, cannot not be pushed to GitHub.

- For a list of available data centre regions and zones, [see here](https://cloud.google.com/compute/docs/regions-zones).
  This should be something like `us-central1` for a region and `us-central1-a` for a zone.
- For a list of available Linux Virtual Machines, [see here](https://cloud.google.com/compute/docs/machine-types).
  This should be something like, for example `n1-standard-2`.
- The versions of the BinderHub Helm Chart can be found [here](https://jupyterhub.github.io/helm-chart/#development-releases-binderhub) and are of the form `0.2.0-<commit-hash>`.
  It is advised to select the most recent version unless you specifically require an older one.

```json
{
  "binderhub": {
    "name": "",              // Name of your BinderHub
    "version": "",           // Helm chart version to deploy, should be 0.2.0-<commit-hash>
    "image_prefix": ""       // The prefix to preppend to Docker images (e.g. "binder-prod")
  },
  "docker": {
    "username": null,        // Docker username (can be supplied at runtime)
    "password": null,        // Docker password (can be supplied at runtime)
    "org": null              // A Docker Hub organisation to push images to (optional)
  },
  "gcp": {
    "email_account": "",     // Your Google Account Email address
    "project_id": "",        // The numerical ID of your Google Cloud project
    "credentials_file": "",  // Path to your Google Cloud Service Account credentials in JSON format
    "region": "",            // The region to deploy your BinderHub to
    "zone": ""               // The zone (within above region) to deploy your BinderHub to
  },
  "gke": {
      "node_count": 1,       // The number of nodes to deploy in the Kubernetes cluster (3 is recommended)
      "machine_type": ""     // The VM type to deploy in the Kubernetes cluster
  }
}
```

You can copy [`template-config.json`](./template-config.json) should you require.

**Please note that all entries in `template-config.json` must be surrounded by double quotation marks (`"`), with the exception of `node_count` or if the value is `null`.**

### :key: Create a Service Account key

This script will access your Google Cloud account using a [Service Account key](https://cloud.google.com/iam/docs/creating-managing-service-account-keys).
[Create one now](https://console.cloud.google.com/apis/credentials/serviceaccountkey) in the console using the following settings:

1. Select the project you are going to use (in the blue bar along the top of the browser window).
2. Under "Service account", select "New service account".
3. Give it any name you like!
4. For the Role, choose "Project -> Editor".
5. Leave the "Key Type" as JSON.
6. Click "Create" to create the key and save the key file to your system.

You will provide the path to this file under `credentials_file` in `config.json` described above.

> :rotating_light: The service account key file provides access to your Google cloud project.
> It should be treated like any other secret credential.
> Specifically, it should **never** be checked into source control. :rotating_light:

### :vertical_traffic_light: `setup.sh`

This script checks whether the required command line tools are already installed.
If any are missing, the script uses the system package manager or [`curl`](https://curl.haxx.se/docs/) to install the command line interfaces (CLIs).
The CLIs to be installed are:

- [Hashicorp Terraform](https://www.terraform.io/)
- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk)
- [Kubernetes (`kubectl`)](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-using-curl)
- [Helm (`helm`)](https://helm.sh/docs/using_helm/#from-script)

Any dependencies that are not automatically installed by these packages will also be installed.

### :rocket: `deploy.sh`

This script reads in values from `config.json` and deploys a Kubernetes cluster.
It then creates `config.yaml` and `secret.yaml` files which are used to install the BinderHub using the templates in the [`templates` folder](./templates/).

The script will ask for your Docker ID and password if you haven't supplied them in the config file.
The ID is your Docker username, **NOT** the associated email.
If you have provided a Docker organisation in `config.json`, then Docker ID **MUST** be a member of this organisation.

Both a JupyterHub and BinderHub are installed via a Helm Chart onto the deployed Kubernetes cluster and the `config.yaml` file is updated with the JupyterHub IP address.

`config.yaml` and `secret.yaml` are both git-ignored so that secrets cannot be pushed back to GitHub.

The script also outputs log files (`<file-name>.log`) for each stage of the deployment.
These files are also git-ignored.

### :bar_chart: `logs.sh`

This script will print the JupyterHub logs to the terminal to assist with debugging issues with the BinderHub.
It reads from `config.json` in order to get the BinderHub name.

### :information_source: `info.sh`

This script will print the pod status of the Kubernetes cluster and the IP addresses of both the JupyterHub and BinderHub to the terminal.
It reads the BinderHub name from `config.json`.

### :arrow_up: `upgrade.sh`

This script will automatically upgrade the Helm Chart deployment configuring the BinderHub and then prints the Kubernetes pods.
It reads the BinderHub name and Helm Chart version from `config.json`.

### :boom: `teardown.sh`

This script will run the `terraform destroy -auto-approve` command to destroy all deployed resources.
It will read the `terraform.tfstate` (which will be git-ignored) file under `terraform` directory.
The user should check the [Google Cloud Console](https://console.cloud.google.com/home/dashboard) to verify the resources have been deleted.

## :art: Customising your BinderHub Deployment

Customising your BinderHub deployment is as simple as editing `config.yaml` and/or `secret.yaml` and then upgrading the BinderHub Helm Chart.
The Helm Chart can be upgraded by running [`upgrade.sh`](./upgrade.sh) (make sure you have the CLIs installed by running [`setup.sh`](./setup.sh) first).

The Jupyter guide to customising the underlying JupyterHub can be found [here](https://zero-to-jupyterhub.readthedocs.io/en/latest/extending-jupyterhub.html).

The BinderHub guide for changing the landing page logo can be found [here](https://binderhub.readthedocs.io/en/latest/customizing.html#template-customization).
