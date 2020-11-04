variable "credentials_file" {
    type        = string
    description = "Path to Google Service Account key in JSON format"
}

variable "project_id" {
    type        = string
    description = "The Google Project ID to deploy the BinderHub into"
}

variable "region" {
    type = string
    description = "The region within which to deploy the BinderHub"
}
