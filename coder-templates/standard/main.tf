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
data "coder_parameter" "cpu_request" {
  name         = "cpu_request"
  display_name = "CPU Request"
  description  = "CPU request for code-server container (in millicores)"
  type         = "string"
  default      = "1000m"
}

data "coder_parameter" "cpu_limit" {
  name         = "cpu_limit"
  display_name = "CPU Limit"
  description  = "CPU limit for code-server container (in millicores)"
  type         = "string"
  default      = "2000m"
}

data "coder_parameter" "memory_request" {
  name         = "memory_request"
  display_name = "Memory Request"
  description  = "Memory request for code-server container"
  type         = "string"
  default      = "512Mi"
}

data "coder_parameter" "memory_limit" {
  name         = "memory_limit"
  display_name = "Memory Limit"
  description  = "Memory limit for code-server container"
  type         = "string"
  default      = "1Gi"
}

data "coder_parameter" "vscode_extensions" {
  name         = "vscode_extensions"
  display_name = "VSCode Extensions"
  description  = "List of extensions to install in code-server (comma-separated)."
  type         = "string"
  default      = "mhutchie.git-graph"
}

data "coder_parameter" "vscode_settings" {
  name         = "vscode_settings"
  display_name = "VSCode Settings"
  description  = "VSCode settings to be applied in code-server."
  type         = "string"
  form_type    = "textarea"
  default      = <<-EOT
  {
    // Use 2 spaces for indentation
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    
    // Format files automatically on save
    "editor.formatOnSave": true,
    
    // Ensure a final newline at the end of files
    "files.insertFinalNewline": true
  }
  EOT
}

locals {
  workspace_namepace = "dev-ws"
  coder_ws_port      = 8080
  preagent_script    = <<-EOT
    #!/bin/bash
    set -e

    # Start Docker daemon in the background
    /usr/bin/dockerd &

    # To-Do: Install other configured tools like Golang, kubectl, helm, etc. here

    # Set up and run code-server
    gosu coder /bin/bash <<'EOC'
      set -e
      # Install code-server extensions
      %{for extension in split(",", data.coder_parameter.vscode_extensions.value)}
      /usr/local/bin/code-server --install-extension ${trimspace(extension)}
      %{endfor}

      cat <<'EOF' > /home/coder/.local/share/code-server/User/settings.json
${data.coder_parameter.vscode_settings.value}
EOF

      # Start code-server in the background
      /usr/local/bin/code-server --bind-addr 0.0.0.0:${local.coder_ws_port} --auth none &

      # Start coder agent
      ${coder_agent.main.init_script}
    EOC
  EOT
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
    vscode                 = false
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
  url          = "http://localhost:${local.coder_ws_port}?workspace=/home/coder"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:${local.coder_ws_port}/healthz"
    interval  = 10
    threshold = 3
  }
}

resource "kubernetes_persistent_volume_claim_v1" "workspace_home" {
  metadata {
    name      = "${lower(data.coder_workspace.me.name)}-home"
    namespace = local.workspace_namepace
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "64Mi"
      }
      limits = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "workspace_docker_data" {
  metadata {
    name      = "${lower(data.coder_workspace.me.name)}-docker-data"
    namespace = local.workspace_namepace
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
      limits = {
        storage = "5Gi"
      }
    }
  }

}

# Kubernetes Deployment with code-server and dockerd containers
resource "kubernetes_deployment_v1" "coder_workspace" {
  count = data.coder_workspace.me.start_count > 0 ? 1 : 0
  metadata {
    name      = lower(data.coder_workspace.me.name)
    namespace = local.workspace_namepace
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

    strategy {
      type = "Recreate"
    }

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
        security_context {
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.workspace_home.metadata.0.name
          }
        }

        volume {
          name = "docker-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.workspace_docker_data.metadata.0.name
          }
        }

        # code-server container (runs Coder agent)
        container {
          name              = "code-server"
          image             = "localhost/coder-ws:latest"
          image_pull_policy = "IfNotPresent"
          command           = ["/usr/bin/tini", "--", "/bin/bash", "-c"]
          args = [
            local.preagent_script,
          ]

          port {
            name           = "http"
            container_port = local.coder_ws_port
          }

          resources {
            requests = {
              cpu    = data.coder_parameter.cpu_request.value
              memory = data.coder_parameter.memory_request.value
            }
            limits = {
              cpu    = data.coder_parameter.cpu_limit.value
              memory = data.coder_parameter.memory_limit.value
            }
          }

          volume_mount {
            name       = "home"
            mount_path = "/home/coder"
          }

          volume_mount {
            name       = "docker-data"
            mount_path = "/var/lib/docker"
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
            privileged = true # Required for Docker
          }
        }
      }
    }
  }
}
