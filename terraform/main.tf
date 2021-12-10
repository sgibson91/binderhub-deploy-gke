terraform {
    required_version = ">= 0.13"

    required_providers {
        google = {
            source  = "hashicorp/google"
            version = "4.3.0"
        }
    }
}

provider "google" {
    credentials = file(var.credentials_file)
    project     = var.project_id
    region      = var.region
}

# Kubernetes cluster
resource "google_container_cluster" "primary" {
    name                     = var.cluster_name
    location                 = var.zone

    remove_default_node_pool = true
    initial_node_count       = 1

    network                  = google_compute_network.vpc.name
    subnetwork               = google_compute_subnetwork.subnet.name

    master_auth {
        username = ""
        password = ""

        client_certificate_config {
            issue_client_certificate = true
        }
    }
}

# Kubernetes default node
resource "google_container_node_pool" "primary_node_pool" {
    name       = "${google_container_cluster.primary.name}-default"
    location   = var.zone
    cluster    = google_container_cluster.primary.name
    node_count = var.node_count

    node_config {
        preemptible  = true
        machine_type = var.machine_type

        metadata = {
            disable-legacy-endpoints = "true"
        }

        oauth_scopes = [
            "https://www.googleapis.com/auth/logging.write",
            "https://www.googleapis.com/auth/monitoring",
        ]
    }

    management {
        auto_upgrade = true
    }
}
