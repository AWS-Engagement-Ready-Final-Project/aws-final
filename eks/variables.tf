variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "cohort"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "cluster-tw"
}
