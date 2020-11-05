# Google Project variables
variable "credentials_file" {
    type        = string
    description = "Path to Google Service Account key in JSON format"
}

variable "project_id" {
    type        = string
    description = "The Google Project ID to deploy the BinderHub into"
}

variable "region" {
    type        = string
    description = "The region within which to deploy the BinderHub"
}

variable "zone" {
    type = string
    description = "Zone (within region) to deploy the BinderHub into"
}

# Kubernetes variables
variable "cluster_name" {
    type        = string
    description = "Name to assign your Kubernetes cluster"
}

variable "node_count" {
    type        = number
    description = "Number of nodes to deploy in the Kubernetes cluster"
}

variable "machine_type" {
    type        = string
    description = "The type of VM to deploy in the Kubernetes cluster"
}
