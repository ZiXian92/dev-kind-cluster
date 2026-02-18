terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
  required_version = "~> 1.14"
}

provider "coder" {
  url = "https://coder.localtest.me:30443"
}

provider "kubernetes" {
  host                   = "https://kubernetes.default.svc"
  cluster_ca_certificate = file("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
  token                  = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
}
# Data sources
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Variables
variable "workspace_namespace" {
  description = "Kubernetes namespace for the workspace"
  type        = string
  default     = "dev-ws"
}

variable "coder_agent_image" {
  description = "Docker image for code-server with Coder agent"
  type        = string
  default     = "localhost/coder-ws:latest"
}

variable "dockerd_image" {
  description = "Docker image for the privileged Docker daemon"
  type        = string
  default     = "localhost/dockerd:latest"
}

variable "cpu_request" {
  description = "CPU request for code-server container (in millicores)"
  type        = string
  default     = "1000m"
}

variable "cpu_limit" {
  description = "CPU limit for code-server container (in millicores)"
  type        = string
  default     = "2000m"
}

variable "memory_request" {
  description = "Memory request for code-server container"
  type        = string
  default     = "512Mi"
}

variable "memory_limit" {
  description = "Memory limit for code-server container"
  type        = string
  default     = "1Gi"
}

variable "dockerd_cpu_request" {
  description = "CPU request for dockerd container (in millicores)"
  type        = string
  default     = "200m"
}

variable "dockerd_memory_request" {
  description = "Memory request for dockerd container"
  type        = string
  default     = "500Mi"
}

variable "dockerd_cpu_limits" {
  description = "CPU limits for Docker daemon"
  type        = string
  default     = "500m"
}

variable "dockerd_memory_limits" {
  description = "Memory limits for Docker daemon"
  type        = string
  default     = "1Gi"
}

variable "coder_ws_port" {
  description = "Port for code-server"
  type        = number
  default     = 8080
}

# Coder Agent
resource "coder_agent" "main" {
  arch               = "amd64"
  os                 = "linux"
  api_key_scope      = "all"
  auth               = "token"
  connection_timeout = 60

  display_apps {
    port_forwarding_helper = true
    ssh_helper             = false
    vscode                 = true
    vscode_insiders        = false
    web_terminal           = true
  }

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
  }

  # Displays CPU usage in Coder UI
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  # Displays Memory usage in Coder UI
  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  # Enable monitoring and alerts when memory usage crosses 90%
  resources_monitoring {
    memory {
      enabled   = true
      threshold = 90
    }
  }
}

# Coder App for code-server web access
resource "coder_app" "code_server" {
  agent_id     = coder_agent.main.id
  slug         = "code"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:${var.coder_ws_port}"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:${var.coder_ws_port}/healthz"
    interval  = 10
    threshold = 3
  }
}

# Kubernetes Deployment with code-server and dockerd containers
resource "kubernetes_deployment_v1" "coder_workspace" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = lower(data.coder_workspace.me.name)
    namespace = var.workspace_namespace
    labels = {
      "app.kubernetes.io/name"      = "coder-workspace"
      "app.kubernetes.io/instance"  = lower(data.coder_workspace.me.name)
      "coder.io/workspace-id"       = data.coder_workspace.me.id
      "coder.io/workspace-name"     = data.coder_workspace.me.name
      "coder.io/workspace-owner"    = data.coder_workspace_owner.me.name
      "coder.io/workspace-owner-id" = data.coder_workspace_owner.me.id
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = lower(data.coder_workspace.me.name)
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "coder-workspace"
          "app.kubernetes.io/instance" = lower(data.coder_workspace.me.name)
        }
      }

      spec {
        # Shared volume for Docker socket
        volume {
          name = "docker-run"
          empty_dir {
            size_limit = "1Gi"
          }
        }

        volume {
          name = "home"
          empty_dir {
            size_limit = "2Gi"
          }
        }

        # code-server container (runs Coder agent)
        container {
          name              = "code-server"
          image             = var.coder_agent_image
          image_pull_policy = "IfNotPresent"
          command           = ["/sbin/tini", "--", "/bin/bash", "-c", "(/usr/local/bin/code-server --bind-addr 0.0.0.0:8080 --auth none >/tmp/code-server.log 2>&1 &) && ${coder_agent.main.init_script}"]

          port {
            name           = "http"
            container_port = var.coder_ws_port
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          # Mount shared Docker socket volume
          volume_mount {
            name       = "docker-run"
            mount_path = "/var/run"
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/coder"
          }

          # Coder agent environment variables
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          env {
            name  = "CODER_AGENT_URL"
            value = "https://coder.localtest.me:30443"
          }

          env {
            name  = "CODER_AGENT_SUBSYSTEM"
            value = "envbox"
          }

          env {
            name  = "GIT_AUTHOR_NAME"
            value = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
          }

          env {
            name  = "GIT_AUTHOR_EMAIL"
            value = data.coder_workspace_owner.me.email
          }

          env {
            name  = "GIT_COMMITTER_NAME"
            value = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
          }

          env {
            name  = "GIT_COMMITTER_EMAIL"
            value = data.coder_workspace_owner.me.email
          }

          security_context {
            run_as_user                = 2001 # coder user from Dockerfile
            allow_privilege_escalation = false
            privileged                 = false
            capabilities {
              drop = ["ALL"]
              add  = ["NET_BIND_SERVICE"]
            }
          }
        }

        # dockerd container (privileged sidecar)
        container {
          name  = "dockerd"
          image = var.dockerd_image

          image_pull_policy = "IfNotPresent"

          resources {
            requests = {
              cpu    = var.dockerd_cpu_request
              memory = var.dockerd_memory_request
            }
            limits = {
              cpu    = var.dockerd_cpu_limits
              memory = var.dockerd_memory_limits
            }
          }

          # Mount shared Docker socket volume
          volume_mount {
            name       = "docker-run"
            mount_path = "/var/run"
          }

          security_context {
            privileged = true
          }
        }
      }
    }
  }
}
