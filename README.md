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
