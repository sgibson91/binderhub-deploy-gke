terraform {
    required_version = ">= 0.12"

    required_providers {
        google = {
            source  = "hashicorp/google"
        }
    }
}

provider "google" {
    version     = "3.46.0"
    credentials = file(var.credentials_file)
    project     = var.project_id
    region      = var.region
}
