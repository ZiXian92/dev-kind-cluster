module "coder_namespace" {
  source = "./modules/namespace"
  name   = "coder"

  # Postgres (200m) + Coder (500m)
  # Postgres (128Mi) + Coder (512Mi)
  resource_quota = {
    limits_cpu    = "1.5"
    limits_memory = "1.5Gi"
  }
}

module "coder_workspace_namespace" {
  source       = "./modules/namespace"
  name         = "dev-ws"
  unprivileged = false

  # This namespace is for Coder workspaces, so we set a resource quota to avoid users creating too many or too heavy workspaces
  resource_quota = {
    limits_cpu    = "4"
    limits_memory = "4Gi"
  }
}

# Since only Coder server needs access to Postgres via password
# Let's try to not store password in Terraform state
ephemeral "random_password" "coder_postgres_password" {
  length      = 16
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

resource "helm_release" "coder_postgres" {
  name            = "postgres"
  namespace       = module.coder_namespace.name
  repository      = "oci://registry-1.docker.io/bitnamicharts"
  chart           = "postgresql"
  version         = "16.3.0"
  recreate_pods   = true
  cleanup_on_fail = true
  values = [
    file("${path.module}/helm/coder/postgres-values.yaml"),
  ]

  set_wo = [
    {
      name  = "auth.password"
      value = ephemeral.random_password.coder_postgres_password.result
    },
  ]

  set_wo_revision = kubernetes_secret_v1.coder.data_wo_revision
}

# For environment variables setting in Coder
resource "kubernetes_config_map_v1" "coder" {
  metadata {
    name      = "coder" # This is referenced in Coder's values file
    namespace = module.coder_namespace.name
  }
  data = {
    CODER_ACCESS_URL                            = "https://coder.localtest.me:30443"
    CODER_OAUTH2_GITHUB_DEFAULT_PROVIDER_ENABLE = "false"
  }
}

# For environment variables setting in Coder, but we don't want to store password in Terraform state
resource "kubernetes_secret_v1" "coder" {
  metadata {
    name      = "coder" # This name is referenced in Coder's values file
    namespace = module.coder_namespace.name
  }
  data_wo = {
    CODER_PG_CONNECTION_URL = "postgres://coder:${ephemeral.random_password.coder_postgres_password.result}@postgres-postgresql.coder.svc.cluster.local:5432/coder?sslmode=disable"
  }
  data_wo_revision = 1
}

resource "kubernetes_secret_v1" "localtest_ca_bundle" {
  metadata {
    name      = "localtest-ca-bundle"
    namespace = module.coder_namespace.name
  }
  data = {
    "ca-bundle.crt" = tls_self_signed_cert.localtest_me.cert_pem
  }
}

resource "helm_release" "coder" {
  depends_on = [
    module.coder_workspace_namespace,
    kubernetes_config_map_v1.coder,
    kubernetes_secret_v1.coder,
    kubernetes_secret_v1.localtest_ca_bundle,
    helm_release.coder_postgres,
  ]
  name       = "coder"
  namespace  = module.coder_namespace.name
  repository = "oci://ghcr.io/coder/chart"
  chart      = "coder"
  version    = "2.30.1"
  values = [
    file("${path.module}/helm/coder/values.yaml"),
  ]
}

resource "kubectl_manifest" "coder_route" {
  depends_on = [
    kubectl_manifest.gateway,
    helm_release.coder,
  ]
  yaml_body = file("${path.module}/manifests/coder/route.yaml")
}
