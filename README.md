# Automatically deploy a BinderHub to Google Cloud

![mit_license_badge](https://img.shields.io/badge/License-MIT-yellow.svg)

[BinderHub](https://binderhub.readthedocs.io/en/latest/index.html) is a cloud-based, multi-server technology used for hosting repoducible computing environments and interactive Jupyter Notebooks built from code repositories.

This repo contains a set of scripts to automatically deploy a BinderHub onto [Google Cloud](https://cloud.google.com/), and connect a [DockerHub](https://hub.docker.com/) container registry, so that you can host your own [Binder](https://mybinder.readthedocs.io/en/latest/) service.

This repo is based on the following set of deployment scripts for Google Cloud: [nicain/binder-deploy](https://github.com/nicain/binder-deploy)

## Table of Contents

- [Usage](#usage)
  - [`setup.sh`](#setupsh)
  - [`deploy.sh`](#deploysh)
  - [`logs.sh`](#logssh)
  - [`info.sh`](#infosh)
  - [`upgrade.sh`](#upgradesh)
  - [`teardown.sh`](#teardownsh)
- [Running the Container Locally](#Running-the-Container-Locally)
- [Customising your BinderHub Deployment](#customising-your-binderhub-deployment)
- [Contributors](#contributors)

---

## Usage

This repo can be run locally, by pulling and executing the container image, or as "Platform as a Service" through the "Cloud Run" button in the ["Cloud Run" Button](#cloud-run-button) section.

To use these scripts locally, clone this repo and change into the directory.

```
git clone https://github.com/alan-turing-institute/binderhub-deploy-gke.git
cd binderhub-deploy-gke
```

To make the scripts executable and then run them, do the following:

```
chmod 700 <script-name>.sh
./<script-name>.sh
```

[**NOTE:** The above command is UNIX specific. If you are running Windows 10, [this blog post](https://www.windowscentral.com/how-install-bash-shell-command-line-windows-10) discusses using a bash shell in Windows.]

To build the BinderHub, you should run `setup.sh` first (to install the required command line tools), then `deploy.sh` (which will build the BinderHub).
Once the BinderHub is deployed, you can run `logs.sh` and `info.sh` to get the JupyterHub logs and IP addresses respectively.
`teardown.sh` should _only_ be used to delete your BinderHub deployment.

You need to create a file called `config.json` which has the format described in the code block below.
Fill the quotation marks with your desired namespaces, etc.
`config.json` is git-ignored so sensitive information, such as passwords, cannot not be pushed to GitHub.

* For a list of available data centre zones, [see here]().
* For a list of available Linux Virtual Machines, [see here]().
* The versions of the BinderHub Helm Chart can be found [here](https://jupyterhub.github.io/helm-chart/#development-releases-binderhub) and are of the form `0.2.0-<commit-hash>`.
  It is advised to select the most recent version unless you specifically require an older one.

```
{
  "gcloud": {
    "project": "",            // Google Cloud project
    "zone": "",               // Zone to deploy resources to
    "node_count": 1,          // Number of nodes to deploy
    "machine_type": "",       // Type of machine to deploy
    "service_account": null,  // Google Cloud Service Account
    "key_file": null          // Path to key file for Service log in
  },
  "binderhub": {
    "name": "",               // Name of your BinderHub
    "version": "",            // Helm chart version to deploy, should be 0.2.0-<commit-hash>
    "contact_email": ""       // Email for letsencrypt https certificate. CANNOT be left blank.
  },
  "docker": {
    "username": null,         // Docker username (can be supplied at runtime)
    "password": null,         // Docker password (can be supplied at runtime)
    "org": null,              // A DockerHub organisation to push images to (optional)
    "image_prefix": ""        // The prefix to preprend to Docker images (e.g. "binder-prod")
  }
}
```

You can copy [`template-config.json`](./template-config.json) should you require.

**Please note that all entries in `template-config.json` must be surrounded by double quotation marks (`"`), with the exception of `node_count`.**

### `setup.sh`

This script checks whether the required command line tools are already installed.
If any are missing, the script uses the system package manager or [`curl`](https://curl.haxx.se/docs/) to install the command line interfaces (CLIs).
The CLIs to be installed are:

* [Google Cloud (`gcloud`)](https://cloud.google.com/sdk/docs/quickstarts)
* [Kubernetes (`kubectl`)](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-using-curl)
* [Helm (`helm`)](https://helm.sh/docs/using_helm/#from-script)

Any dependencies that are not automatically installed by these packages will also be installed.

### `deploy.sh`

This script reads in values from `config.json` and deploys a Kubernetes cluster.
It then creates `config.yaml` and `secret.yaml` files, respectively, using [`config-template.yaml`](./config-template.yaml) and [`secret-template.yaml`](./secret-template.yaml).

The script will ask for your Docker ID and password if you haven't supplied them in the config file.
The ID is your Docker username, **NOT** the associated email.
If you have provided a Docker organisation in `config.json`, then Docker ID **MUST** be a member of this organisation.

Both a JupyterHub and BinderHub are installed via a Helm Chart onto the deployed Kubernetes cluster and the `config.yaml` file is updated with the JupyterHub IP address.
The BinderHub is then linked to the provided DockerHub account to store the created images.

`config.yaml` and `secret.yaml` are both git-ignored so that secrets cannot be pushed back to GitHub.

The script also outputs log files (`<file-name>.log`) for each stage of the deployment.
These files are also git-ignored.

### `logs.sh`

This script will print the JupyterHub logs to the terminal to assist with debugging issues with the BinderHub.
It reads from `config.json` in order to get the BinderHub name.

### `info.sh`

This script will print the pod status of the Kubernetes cluster and the IP addresses of both the JupyterHub and BinderHub to the terminal.
It reads the BinderHub name from `config.json`.

### `upgrade.sh`

This script will automatically upgrade the Helm Chart deployment configuring the BinderHub and then prints the Kubernetes pods.
It reads the BinderHub name and Helm Chart version from `config.json`.

### `teardown.sh`

This script will purge the Helm Chart release, delete the Kubernetes namespace and then delete the Google Cloud cluster.
It will read the namespaces from `config.json`.
The user should check the [Google Cloud Console](https://console.cloud.google.com/) to verify the resources have been deleted.

## Customising your BinderHub Deployment

Customising your BinderHub deployment is as simple as editing `config.yaml` and/or `secret.yaml` and then upgrading the BinderHub Helm Chart.
The Helm Chart can be upgraded by running [`upgrade.sh`](./upgrade.sh) (make sure you have the CLIs installed by running [`setup.sh`](./setup.sh) first).

The Jupyter guide to customising the underlying JupyterHub can be found [here](https://zero-to-jupyterhub.readthedocs.io/en/latest/extending-jupyterhub.html).

The BinderHub guide for changing the landing page logo can be found [here](https://binderhub.readthedocs.io/en/latest/customizing.html#template-customization).

## Contributors

We would like to acknowledge and thank the following people for their contributions to this project:

* Tim Greaves ([@tmbgreaves](https://github.com/tmbgreaves))
* Gerard Gorman ([@ggorman](https://github.com/ggorman))
* Tania Allard ([@trallard](https://github.com/trallard))
* Diego Alonso Alvarez ([@dalonsoa](https://github.com/dalonsoa))
* Min Ragan-Kelley ([@minrk](https://github.com/minrk))
