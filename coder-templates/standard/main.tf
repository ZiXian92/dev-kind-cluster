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
data "coder_parameter" "cpu_limit" {
  name         = "cpu_limit"
  display_name = "CPU Limit"
  description  = "CPU limit for code-server container (in millicores)"
  mutable      = true
  type         = "string"
  default      = "2000m"
}

data "coder_parameter" "memory_limit" {
  name         = "memory_limit"
  display_name = "Memory Limit"
  description  = "Memory limit for code-server container"
  mutable      = true
  type         = "string"
  default      = "1Gi"
}

data "coder_parameter" "custom_ca_certificates" {
  name         = "custom_ca_certificates"
  display_name = "Custom CA Certificates"
  description  = "List of Base64-encoded custom CA certificates to trust in the workspace, 1 per line."
  mutable      = true
  type         = "string"
  form_type    = "textarea"
  default      = ""
}

data "coder_parameter" "install_tools" {
  name         = "install_tools"
  display_name = "Install Tools"
  description  = "List of tools to install in the workspace."
  mutable      = true
  type         = "list(string)"
  form_type    = "multi-select"
  default      = "[]"
  dynamic "option" {
    for_each = local.tools
    content {
      value = option.key
      name  = local.tools[option.key].display_name
    }
  }
}

data "coder_parameter" "vscode_extensions" {
  name         = "vscode_extensions"
  display_name = "VSCode Extensions"
  description  = "List of extensions to install in code-server (comma-separated)."
  mutable      = true
  type         = "string"
  default      = "mhutchie.git-graph"
}

data "coder_parameter" "vscode_settings" {
  name         = "vscode_settings"
  display_name = "VSCode Settings"
  description  = "VSCode settings to be applied in code-server."
  mutable      = true
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
  compulsory_ca      = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURERENDQWZTZ0F3SUJBZ0lRWGZPLzl3RThlZ1lLc0pkUWRsY1l5REFOQmdrcWhraUc5dzBCQVFzRkFEQVoKTVJjd0ZRWURWUVFEREE0cUxteHZZMkZzZEdWemRDNXRaVEFlRncweU5qQXlNVFl4TWpBNU1UZGFGdzB5TnpBeQpNVFl4TWpBNU1UZGFNQmt4RnpBVkJnTlZCQU1NRGlvdWJHOWpZV3gwWlhOMExtMWxNSUlCSWpBTkJna3Foa2lHCjl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF4Vk1nNnM5dlNySjlld0o4V3o0ZnVyaXJYVWYzandSUStpZ3UKazA0MjZRSDV0RVZnOXZpKzJVWEJwZTdRSDlKMitoT0VLVytaeUdJWnFiVDZaNHdaWkY1ZXlYRXpzd1pha0lWKwp6RkRCdFJjL1l2TWgvVmFXWmRib1RPSHVmTmtuem5OeWVVWWpFMFFMbDgvcWluUmRYOUV2UVRBb3JENENPWGo5CjJNZ3dzbDR6Q2c5bHdtaGNWaDluMFB6RG5UK1ZKajF1UnRKYmppeURiRGwyOHBCWTFnSkVCZ2NWY25HWXBtRHMKR0xLMG1QSXQrblFuS3ZjRnloQ2FDQTJDL0xRS2szMlJVa1NNdjdqalNFSVZPa0gzdUVEdkZ1WFdoRm9yelNpZwpBamliamYzRHV1dDd1ZWw3VWxBcTJncEZONmlsZ2F0ZlNFd2xmUWVvYzBRZ1FmTkhLd0lEQVFBQm8xQXdUakFPCkJnTlZIUThCQWY4RUJBTUNCYUF3RXdZRFZSMGxCQXd3Q2dZSUt3WUJCUVVIQXdFd0RBWURWUjBUQVFIL0JBSXcKQURBWkJnTlZIUkVFRWpBUWdnNHFMbXh2WTJGc2RHVnpkQzV0WlRBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQVFFQQpoc0lxZ3YyUllDWW5POHJzbGUza3EzNTZDY2djeXVucjZPc1FEUzBjRzIxRUx1TTdtSFNsaSt4TzBLSVZmTnJSCkJmNHVYb1Q4dGRId05tSHpJNHppbFRmMnoxMUFtUkcrVk9wdlU0bEEwYlgxZ0tDSTR3dm83VHM4V0wzUFpUeXEKc2hodFEwZUpWZy9Jc0R0cmVQVEhCZWp5YnZ6d24wc3YyYkRiL2pHU2lNYXBwdHJMYzlRTEZ5d2pLK3hPRUM0SApqc1gxZ201alA1TDAwQjZFMXpNV1BRVVFtbGlZQmp3UXVpN2FuamdkTzhqNnI4OE9mNllVWDFLZzlDNnAvKzdCCjg1UTNoZk9RVDltTDBSUEMzdHpoaWs5aldlTlhkWnBSVW5hL2xrcDNOY1JVQjJYZTlEaEV1RUVmeTNFRVhpencKNmVWdkwxNytIb1JQNUFraVd0ZHVaZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
  tools = {
    kubectl = {
      display_name   = "Kubectl"
      install        = true
      version        = "1.35.1"
      install_script = <<-EOT
        if ! command -v kubectl &> /dev/null || [ "$(kubectl version --client --short | awk '{print $3}' | sed 's/v//')" != "<VERSION>" ]; then
          echo Installing Kubectl <VERSION>... && \
        curl -L -o $HOME/.local/bin/kubectl "https://dl.k8s.io/release/v<VERSION>/bin/linux/amd64/kubectl" && \
        chmod +x $HOME/.local/bin/kubectl
        else
          echo "Kubectl <VERSION> is already installed."
        fi
      EOT
    }
    helm = {
      display_name   = "Helm"
      install        = true
      version        = "4.1.1"
      install_script = <<-EOT
        if ! command -v helm &> /dev/null || [ "$(helm version --short | sed 's/v//')" != "<VERSION>" ]; then
          echo Installing Helm <VERSION>... && \
        curl -L -o /tmp/helm.tar.gz "https://get.helm.sh/helm-v<VERSION>-linux-amd64.tar.gz" && \
        tar -xzvf /tmp/helm.tar.gz -C /tmp && \
        mv /tmp/linux-amd64/helm $HOME/.local/bin/helm && \
        chmod +x $HOME/.local/bin/helm && \
        rm -rf /tmp/helm.tar.gz /tmp/linux-amd64
        else
          echo "Helm <VERSION> is already installed."
        fi
      EOT
    }
    golang = {
      display_name   = "Golang"
      install        = true
      version        = "1.26.0"
      install_script = <<-EOT
        if ! command -v go &> /dev/null || [ "$(go version | awk '{print $3}' | sed 's/go//')" != "<VERSION>" ]; then
          echo Installing Go <VERSION>... && \
          rm -rf $HOME/.local/go && \
        curl -L -o /tmp/go.tar.gz "https://go.dev/dl/go<VERSION>.linux-amd64.tar.gz" && \
        tar -xzvf /tmp/go.tar.gz -C /tmp && \
        mv /tmp/go $HOME/.local/go && \
        rm -rf /tmp/go.tar.gz
        grep -qxF 'export PATH=$HOME/.local/go/bin:$PATH' $HOME/.bash_profile || \
        echo 'export PATH=$HOME/.local/go/bin:$PATH' >> $HOME/.bash_profile
        else
          echo "Go <VERSION> is already installed."
        fi
      EOT
    }
    terraform = {
      display_name   = "Terraform"
      install        = true
      version        = "1.14.5"
      install_script = <<-EOT
        if ! command -v terraform &> /dev/null || [ "$(terraform version | head -n1 | awk '{print $2}' | sed 's/v//')" != "<VERSION>" ]; then
          echo Installing Terraform <VERSION>... && \
        curl -L -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/<VERSION>/terraform_<VERSION>_linux_amd64.zip" && \
          unzip -o /tmp/terraform.zip -d $HOME/.local/bin && \
        chmod +x $HOME/.local/bin/terraform && \
        rm -rf /tmp/terraform.zip
        else
          echo "Terraform <VERSION> is already installed."
        fi
      EOT
    }
  }
  preagent_script = <<-EOT
    #!/bin/bash
    set -e

    # Install custom CA certificates if provided
    echo "${local.compulsory_ca}" | base64 -d > /usr/local/share/ca-certificates/localtest-me.crt
    %{for i, cert in split("\n", data.coder_parameter.custom_ca_certificates.value)}
      echo "${cert}" | base64 -d > /usr/local/share/ca-certificates/custom-${i}.crt
    %{endfor}
    update-ca-certificates

    # Start Docker daemon in the background
    /usr/bin/dockerd &

    # Set up and run code-server
    gosu coder /bin/bash <<'EOC'
      set -e
      # Install additional tools
      mkdir -p $HOME/.local/bin
      grep -qxF 'export PATH=$HOME/.local/bin:$PATH' $HOME/.bash_profile || \
      echo 'export PATH=$HOME/.local/bin:$PATH' >> $HOME/.bash_profile

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

resource "coder_script" "install_tools" {
  agent_id     = coder_agent.main.id
  display_name = "Install Tools"
  run_on_start = true
  run_on_stop  = false
  script       = <<-EOT
    set -e

    %{for tool_key in jsondecode(data.coder_parameter.install_tools.value)}
      ${replace(local.tools[tool_key].install_script, "<VERSION>", local.tools[tool_key].version)}
    %{endfor}
  EOT
}

# Coder App for code-server web access
resource "coder_app" "code_server" {
  agent_id     = coder_agent.main.id
  slug         = "code"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  open_in      = "tab"
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
              cpu    = "100m"
              memory = "128Mi"
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
