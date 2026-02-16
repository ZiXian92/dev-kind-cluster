resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.name
    labels = merge(
      var.labels,
      var.unprivileged ? {
        "pod-security.kubernetes.io/enforce"         = "restricted"
        "pod-security.kubernetes.io/audit"           = "restricted"
        "pod-security.kubernetes.io/warn"            = "restricted"
        "pod-security.kubernetes.io/enforce-version" = "latest"
      } : {}
    )
  }
}

resource "kubernetes_resource_quota" "namespace_quota" {
  metadata {
    name      = "${var.name}-quota"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"           = var.resource_quota.requests_cpu
      "requests.memory"        = var.resource_quota.requests_memory
      "limits.cpu"             = var.resource_quota.limits_cpu
      "limits.memory"          = var.resource_quota.limits_memory
      "pods"                   = var.resource_quota.pods
      "persistentvolumeclaims" = var.resource_quota.pvcs
    }
  }
}
