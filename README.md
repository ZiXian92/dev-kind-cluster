# KinD Kubernetes Terraform Project

This project uses Terraform to provision and manage resources in a Kubernetes (KinD) cluster.

## Project Structure

```
.
├── INSTRUCTIONS.md              # Project guidelines and best practices
├── kind.yaml                    # KinD cluster configuration
├── versions.tf                  # Terraform and provider versions
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars             # Variable values (example)
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
│
├── modules/                     # Reusable Terraform modules
│   └── namespace/               # Module for creating namespaces with resource quotas
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── manifests/                   # Custom Kubernetes resource manifests
    └── crd-example.yaml         # Example Custom Resource Definition
```

## Quick Start

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review Configuration

Examine the following files:
- `variables.tf` - Define your variables with sensible defaults
- `terraform.tfvars` - Set variable values for your environment
- `main.tf` - Configure which modules to deploy

### 3. Plan Changes

```bash
terraform plan
```

Review the output carefully before applying.

### 4. Apply Configuration

```bash
terraform apply
```

### 5. Validate and Format

```bash
terraform validate
terraform fmt -recursive
```

## Working with Modules

### Namespace Module

Creates a Kubernetes namespace with resource quotas.

```hcl
module "my_namespace" {
  source = "./modules/namespace"

  namespace_name = "my-app"
  
  resource_quota = {
    requests_cpu    = "10"
    requests_memory = "20Gi"
    limits_cpu      = "20"
    limits_memory   = "40Gi"
    pods            = "100"
    pvcs            = "10"
  }
  
  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }
}
```

## Helm Values Files

### Standard Values (values.yaml)

Use for static configuration that doesn't change based on variables.

### Templated Values (values.tpl.yaml)

Use the `templatefile()` function to inject Terraform variables:

```hcl
values = yamldecode(templatefile("${path.module}/helm/example-chart/values.tpl.yaml", {
  replicas = var.replicas
}))
```

Template syntax in YAML files: `${variable_name}`

## Custom Manifests

Place YAML manifest files in the `manifests/` directory. These can include:

- Custom Resource Definitions (CRDs)
- Custom Resources instances
- NetworkPolicies
- PodSecurityPolicies
- ServiceMonitors
- Any other Kubernetes resources not covered by Helm

Apply them using the custom-resources module.

## Security Best Practices

This project enforces:

1. **Resource Quotas**: Every namespace has defined resource requests and limits
2. **Pod Security**: All workloads specify resource requests and limits
3. **Security Context**: Containers run as non-root with minimal privileges
4. **RBAC**: Use principle of least privilege

For detailed guidelines, see [INSTRUCTIONS.md](INSTRUCTIONS.md).

## Managing State

By default, Terraform state is stored locally (`terraform.tfstate`). For production:

1. Use remote state storage (S3, Terraform Cloud, etc.)
2. Enable state locking to prevent concurrent modifications
3. Never commit `terraform.tfstate` to version control

Uncomment the backend configuration in `versions.tf` to enable remote state.

## Troubleshooting

### Kubeconfig Issues

Ensure your kubeconfig is configured:

```bash
# Check kubeconfig
kubectl config current-context

# Should output: kind-kind
```

### Provider Issues

If providers fail to initialize:

```bash
terraform init -upgrade
```

### Debugging

Enable debug logging:

```bash
export TF_LOG=DEBUG
terraform apply
```

## Useful Commands

```bash
# Initialize
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan changes
terraform plan -out=tfplan

# Apply specific module
terraform apply -target=module.my_namespace

# Destroy specific resources
terraform destroy -target=module.my_app

# Destroy everything
terraform destroy
```

## Contributing

When adding new modules:

1. Create a directory under `modules/`
2. Include `main.tf`, `variables.tf`, and `outputs.tf`
3. Document module inputs and outputs
4. Include examples in comments

---

For comprehensive guidelines on Terraform and Kubernetes best practices, refer to [INSTRUCTIONS.md](INSTRUCTIONS.md).
