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
