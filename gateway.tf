module "gateway_namespace" {
  source = "./modules/namespace"
  name   = "envoy"

  # Controller (200m) + Certgen (100m) + ShutdownManager (500m) + Gateway (200m)
  # Controller (1Gi) + Certgen (128Mi) + ShutdownManager (64Mi) + Gateway (768Mi)
  resource_quota = {
    limits_cpu    = "1"
    limits_memory = "2Gi"
  }
}

resource "helm_release" "envoy_gateway" {
  name          = "envoy-gateway"
  repository    = "oci://docker.io/envoyproxy"
  chart         = "gateway-helm"
  namespace     = module.gateway_namespace.name
  values        = [file("${path.module}/helm/envoy-gateway/values.yaml")]
  version       = "v1.6.1"
  recreate_pods = true
}

# Self-signed certificate to serve *.localtest.me domain
resource "tls_private_key" "localtest_me" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "localtest_me" {
  private_key_pem = tls_private_key.localtest_me.private_key_pem

  subject {
    common_name = "*.localtest.me"
  }

  validity_period_hours = 8760
  early_renewal_hours   = 168

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["*.localtest.me"]
}

resource "kubernetes_secret" "localtest_me_tls" {
  metadata {
    name      = "localtest-me-tls"
    namespace = module.gateway_namespace.name
  }

  data = {
    "tls.crt" = tls_self_signed_cert.localtest_me.cert_pem
    "tls.key" = tls_private_key.localtest_me.private_key_pem
  }

  type = "kubernetes.io/tls"
}
# End of self-signed certificate for *.localtest.me

# Proxy config to fix Service type for
# the Gateway resource being created
resource "kubectl_manifest" "envoy_proxy_config" {
  depends_on = [helm_release.envoy_gateway]
  yaml_body  = file("${path.module}/manifests/envoy-gateway/common-gateway-proxy.yaml")
}

# Deploy Gateway Class so that the common Gateway can use
resource "kubectl_manifest" "gateway_class" {
  depends_on = [helm_release.envoy_gateway]
  yaml_body  = file("${path.module}/manifests/envoy-gateway/gateway-class.yaml")
}

# 1 common gateway to serve all ingresses in the cluster on HTTP and HTTPS
# More traffic types to be added as needed, e.g. gRPC, TCP, etc.
resource "kubectl_manifest" "gateway" {
  depends_on = [
    kubectl_manifest.gateway_class,
    kubectl_manifest.envoy_proxy_config,
    kubernetes_secret.localtest_me_tls,
  ]
  yaml_body = file("${path.module}/manifests/envoy-gateway/common-gateway.yaml")
}

# Default healthcheck route with hardcoded HTTP 200 response on /healthz path, used to verify that the Gateway is up and running
# For use by external API Gateways or reverse proxies
resource "kubectl_manifest" "healthcheck_route_filter" {
  depends_on = [helm_release.envoy_gateway]
  yaml_body  = file("${path.module}/manifests/envoy-gateway/healthcheck-route-filter.yaml")
}

resource "kubectl_manifest" "healthcheck_route" {
  depends_on = [
    kubectl_manifest.gateway,
    kubectl_manifest.healthcheck_route_filter,
  ]
  yaml_body = file("${path.module}/manifests/envoy-gateway/healthcheck-route.yaml")
}
# End of healthcheck route
