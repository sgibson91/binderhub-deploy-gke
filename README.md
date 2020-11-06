# Automatically deploy a BinderHub to Google Cloud

[![mit_license_badge](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/sgibson91/binderhub-setup-gke)](https://hub.docker.com/repository/docker/sgibson91/binderhub-setup-gke) ![Check Setup](https://github.com/alan-turing-institute/binderhub-deploy-gke/workflows/Check%20Setup/badge.svg?branch=main) ![Run shellcheck and shfmt](https://github.com/alan-turing-institute/binderhub-deploy-gke/workflows/Run%20shellcheck%20and%20shfmt/badge.svg?branch=main) ![Lint YAML templates](https://github.com/alan-turing-institute/binderhub-deploy-gke/workflows/Lint%20YAML%20templates/badge.svg?branch=main) ![Validate terraform files](https://github.com/alan-turing-institute/binderhub-deploy-gke/workflows/Validate%20terraform%20files/badge.svg?branch=main) <!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

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
- [:house_with_garden: Running the Container Locally](#house_with_garden-running-the-container-locally)
  - [:arrow_up: Updating your Service Account](#arrow_up-updating-your-service-account)
  - [:whale: Running the Container](#whale-running-the-container)
  - [:package: Retrieving Deployment Output](#package-retrieving-deployment-output)
  - [:unlock: Accessing your BinderHub after Deployment](#unlock-accessing-your-binderhub-after-deployment)
- [:art: Customising your BinderHub Deployment](#art-customising-your-binderhub-deployment)
- [:sparkles: Contributors](#sparkles-contributors)

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

## :house_with_garden: Running the Container Locally

Another way to deploy BinderHub to Google Cloud would be to pull the Docker image and run it directly, parsing the values you would have entered in `config.json` as environment variables.

You will need the Docker CLI installed.
Installation instructions can be found [here](https://docs.docker.com/v17.12/install/).

### :arrow_up: Updating your Service Account

To deploy the BinderHub without your local authentication details, we need to grant an extra role to the Service Account you created in ["Create a Service Account key"](#key-create-a-service-account-key).

1. On the [IAM page](https://console.cloud.google.com/iam-admin/iam) of the Google Cloud console, edit the Service Account you created.
   Do this by selecting the pencil icon to the right of the account.
2. Select "+ Add Another Role"
3. Search for and add the "Kubernetes Engine Admin" role
4. Click "Save"

### :whale: Running the Container

First, pull the `binderhub-setup-gke` image.

```bash
docker pull sgibson91/binderhub-setup-gke:<TAG>
```

where `<TAG>` is your chosen image tag.

A list of availabe tags can be found [here](https://cloud.docker.com/repository/docker/sgibson91/binderhub-setup-gke/tags).
It is recommended to use the most recent version number.
The `latest` tag is the most recent build from the default branch and may be subject fluctuations.

Then, run the container with the following arguments, replacing the `<>` fields as necessary:

```bash
docker run \
-e "CONTAINER_MODE=true" \  # Required
-e "BINDERHUB_NAME=<Chosen BinderHub Name>" \  # Required
-e "BINDERHUB_VERSION=<Chosen BinderHub Version>" \  # Required
-d "DOCKER_ORG=<Docker Hub Organisation>" \  # Optional
-e "DOCKER_USERNAME=<DOCKER ID>" \  # Required
-e "DOCKER_PASSWORD=<Docker Password>" \  # Required
-e "GCP_ACCOUNT_EMAIL=<Google Email Account>" \  # Required
-e "GCP_PROJECT_ID=<Google Project ID>" \  # Required
-e "GCP_REGION=<Google Cloud Region>" \  # Required
-e "GCP_ZONE=<Google Cloud Zone>" \  # Required
-e "GKE_NODE_COUNT=3" \  # Required
-e "GKE_MACHINE_TYPE=n1-standard-2" \  # Required
-e "IMAGE_PREFIX=binder-dev" \  # Required
-v <Path to Service Account key file>:/app/key_file.json \  # Required
-it sgibson91/binderhub-setup-gke:<TAG>
```

The output will be printed to your terminal and the files will be pushed to a storage bucket.
See the [Retrieving Deployment Output](#package-retrieving-deployment-output) section for how to return these files.

### :package: Retrieving Deployment Output

When BinderHub is deployed using a local container, output logs, YAML files, and the terraform state file are pushed to a Google storage bucket to preserve them once the container exits.
The storage bucket is created in the same project as the Kubernetes cluster.

The storage bucket name is derived from the name you gave to your BinderHub instance, but may be modified and/or have a random seed appended.
The Google Cloud CLI can be used to find the bucket and download it's contents.
It can be installed by running the [`setup.sh`](./src/setup.sh) script.

To find the storage bucket name, run the following command.

```bash
gsutil ls
```

To download all files from the bucket:

```bash
gsutil -m cp -r gs://${STORAGE_BUCKET_NAME} ./
```

**Make sure the terraform state file is moved to the terraform folder!**

```bash
mv ${STORAGE_BUCKET_NAME}/terraform.tfstate ./terraform
```

> For full documentation, see ["Cloud Storage: Downloading Objects"](https://cloud.google.com/storage/docs/downloading-objects#gsutil).

### :unlock: Accessing your BinderHub after Deployment

Once the deployment has succeeded and you've downloaded the log files, visit the IP address of your Binder page to test it's working.

The Binder IP address can be found by running the following:

```bash
cat binder-ip.log
```

A good repository to test your BinderHub with is [binder-examples/requirements](https://github.com/binder-examples/requirements)

## :art: Customising your BinderHub Deployment

Customising your BinderHub deployment is as simple as editing `config.yaml` and/or `secret.yaml` and then upgrading the BinderHub Helm Chart.
The Helm Chart can be upgraded by running [`upgrade.sh`](./upgrade.sh) (make sure you have the CLIs installed by running [`setup.sh`](./setup.sh) first).

The Jupyter guide to customising the underlying JupyterHub can be found [here](https://zero-to-jupyterhub.readthedocs.io/en/latest/extending-jupyterhub.html).

The BinderHub guide for changing the landing page logo can be found [here](https://binderhub.readthedocs.io/en/latest/customizing.html#template-customization).

## :sparkles: Contributors

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://sgibson91.github.io/"><img src="https://avatars2.githubusercontent.com/u/44771837?v=4?s=70" width="70px;" alt=""/><br /><sub><b>Sarah Gibson</b></sub></a><br /><a href="https://github.com/alan-turing-institute/binderhub-deploy-gke/issues?q=author%3Asgibson91" title="Bug reports">🐛</a> <a href="https://github.com/alan-turing-institute/binderhub-deploy-gke/commits?author=sgibson91" title="Code">💻</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
