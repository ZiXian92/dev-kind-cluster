output "name" {
  value       = kubernetes_namespace.namespace.metadata[0].name
  description = "Name of the created namespace"
}
