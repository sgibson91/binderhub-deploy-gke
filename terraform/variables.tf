variable "project_id" {
    type        = string
    description = "The Google Project ID to deploy the BinderHub into"
}

variable "credentials_file" {
    type        = string
    description = "Path to Google Service Account key in JSON format"
}
