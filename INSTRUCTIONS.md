# Terraform Provisioning for KinD Kubernetes Cluster

## Project Overview
This project uses Terraform to provision systems and resources in an already-provisioned Kubernetes (KinD) cluster. All infrastructure-as-code is managed through Terraform configurations.

---

## Prerequisites
- Kubernetes (KinD) cluster already provisioned and running
- Terraform >= 1.0
- kubectl configured to access the KinD cluster
- Appropriate credentials/kubeconfig in place

---

## Terraform Best Practices

### State Management
- **Avoid Committing**: Never commit `terraform.tfstate` or `terraform.tfstate.backup` to version control
- **Secrets Management**: Use environment variables or secret management tools for sensitive data (API keys, credentials)

### Code Organization
- **Modularization**: Organize code into modules for reusability and maintainability
- **Naming Conventions**: Use consistent, descriptive naming for resources and variables
- **DRY Principle**: Avoid duplication; use variables, locals, and modules to prevent code repetition
- **Input/Output Files**: Maintain clear separation between `variables.tf`, `outputs.tf`, and main configuration files

### Configuration Management
- **Variable Defaults**: Provide sensible defaults where appropriate
- **Validation**: Use validation rules in variable blocks to catch errors early
- **Documentation**: Add descriptions to all variables, outputs, and modules
- **Testing**: Plan changes before applying (`terraform plan`) and review carefully

### Versioning
- **Provider Versions**: Specify provider version constraints in `required_providers`
- **Terraform Version**: Specify minimum Terraform version in `required_version`
- **Dependency Management**: Use `depends_on` explicitly when implicit dependencies are unclear

---

## Kubernetes Security Best Practices

### Namespace Resource Quotas
- **Always Define Quotas**: Implement `ResourceQuota` for every namespace to prevent resource exhaustion
- **Quota Scope**: Set limits on:
  - CPU requests and limits
  - Memory requests and limits
  - Number of pods
  - Storage requests
  - PersistentVolumeClaims

### Resource Requests and Limits
- **All Containers Must Specify**:
  - CPU requests (e.g., `100m`, `500m`)
  - Memory requests (e.g., `128Mi`, `512Mi`)
  - CPU limits (e.g., `200m`, `1000m`)
  - Memory limits (e.g., `256Mi`, `1Gi`)
- **Conservative Estimates**: Set requests based on actual application needs; set limits slightly above requests to allow bursting
- **Monitor and Adjust**: Regularly review metrics to validate request/limit accuracy

### Pod Security Admission Standards
- **Use Restricted Policy**: Apply restricted Pod Security Admission standards where applicable
- **Policy Modes**:
  - `enforce`: Blocks pods that violate the policy
  - `audit`: Logs violations but allows pods
  - `warn`: Warns users about violations
- **Restrictions Include**:
  - Disallow privileged containers
  - Disallow host network/IPC/PID access
  - Require non-root users
  - Disallow Linux capabilities (except NET_BIND_SERVICE)
  - Restrict SELinux contexts

### Additional Security Practices
- **RBAC**: Implement least-privilege Role-Based Access Control
- **Network Policies**: Define network policies to control traffic between pods
- **ImagePullPolicy**: Set to `IfNotPresent` or `Always` (avoid `Never`)
- **Image Registries**: Use only trusted container registries
- **Secrets Management**: Use Kubernetes Secrets or encrypted secret management solutions (avoid hardcoding credentials)

---

## Project Structure
```
.
├── INSTRUCTIONS.md          # This file
├── kind.yaml                # KinD cluster configuration
├── main.tf                  # Primary Terraform configuration
├── variables.tf             # Variable definitions
├── outputs.tf               # Output definitions
├── terraform.tfvars         # Variable values (keep secure, consider using environment variables)
├── modules/                 # Reusable Terraform modules
│   ├── namespace/           # Namespace with ResourceQuota
│   ├── deployment/          # Deployment with resource specs
│   └── ...
└── .gitignore               # Exclude sensitive files
```

---

## Common Workflows

### Initialize Terraform
```bash
terraform init
```

### Plan Changes
```bash
terraform plan -out=tfplan
```

### Review and Apply
```bash
terraform apply tfplan
```

### Destroy Resources
```bash
terraform destroy
```

### Validate Configuration
```bash
terraform validate
terraform fmt -check
```

---

## Important Notes
1. Always run `terraform plan` before `terraform apply` to review changes
2. Keep sensitive data (credentials, keys) in environment variables or secure vaults
3. Use `.gitignore` to exclude `*.tfstate`, `*.tfvars` (for secrets), and `.terraform/` directory
4. Document any manual Kubernetes configurations outside of Terraform
5. Regular validate and format checks to maintain code quality

---

## References
- [Terraform Documentation](https://www.terraform.io/docs)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Kubernetes Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
