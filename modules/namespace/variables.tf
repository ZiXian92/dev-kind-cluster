variable "name" {
  type        = string
  description = "Name of the Kubernetes namespace"
}

variable "unprivileged" {
  description = "Whether to enforce restricted Pod Security Admission."
  type        = bool
  default     = true
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the namespace"
  default     = {}
}

variable "resource_quota" {
  type = object({
    requests_cpu    = optional(string, "2")
    requests_memory = optional(string, "2Gi")
    limits_cpu      = optional(string, "3")
    limits_memory   = optional(string, "3Gi")
    pods            = optional(string, "100")
    pvcs            = optional(string, "10")
  })
  description = "Resource quota limits for the namespace"
  default     = {}
}
