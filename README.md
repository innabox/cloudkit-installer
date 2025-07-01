# CloudKit AAP - Ansible Automation Platform Integration

This repository contains Kubernetes/OpenShift deployment configurations for CloudKit AAP (Ansible Automation Platform) integration, which provides automated cluster lifecycle management through Event Driven Automation.

## Overview

CloudKit AAP integrates with Red Hat Ansible Automation Platform to provide:

- **Automated Cluster Provisioning** - Creates OpenShift clusters through AAP job templates
- **Cluster Lifecycle Management** - Handles cluster updates, scaling, and decommissioning
- **Event Driven Automation** - Responds to cluster events and webhook notifications
- **Configuration as Code** - Manages cluster configurations through Ansible playbooks

## Architecture

The CloudKit AAP solution consists of:

1. **AnsibleAutomationPlatform** - Custom resource for AAP deployment
2. **Bootstrap Job** - Initial configuration of AAP resources
3. **Configuration Secrets** - AAP credentials and playbook settings
4. **Image Secrets** - Container registry credentials for execution environments

## Prerequisites

Before deploying CloudKit AAP, ensure you have:

- OpenShift cluster with admin access
- **Red Hat Ansible Automation Platform Operator** installed
- **Red Hat Advanced Cluster Management (ACM)** installed (for cluster provisioning)
- `oc` CLI configured
- `kustomize` CLI tool (or use `oc apply -k`)
- Valid AAP license manifest
- Container registry credentials for execution environments

## Repository Structure

```
osc-config/
├── base/cloudkit-aap/                  # Base Kustomize configurations
│   ├── aap.yaml                        # AnsibleAutomationPlatform custom resource
│   ├── aap_install.yaml                # AAP subscription and operator resources
│   ├── cloudkit_env.yaml               # Environment configuration
│   ├── job.yaml                        # Bootstrap job for initial setup
│   ├── image_secret.yaml               # Container registry credentials
│   └── kustomization.yaml              # Base kustomization
├── overlays/
│   ├── development/cloudkit-aap/       # Development environment overlay
│   │   ├── kustomization.yaml          # Development kustomization with patches
│   │   ├── fix-ansibleautomationplatform.yaml  # AAP resource fixes
│   │   ├── license-patch.yaml          # License configuration patch
│   │   ├── secret-patch.yaml           # Development credentials patch
│   │   ├── quay-pull-secret.env        # Development registry credentials
│   │   └── skip-nameprefix.yaml        # Name prefix configuration
│   └── production/cloudkit-aap/        # Production environment overlay
│       ├── kustomization.yaml          # Production kustomization with patches
│       ├── fix-ansibleautomationplatform.yaml  # Production AAP resource configuration
│       ├── license-patch.yaml          # Production license patch
│       ├── secret-patch.yaml           # Production credentials patch
│       ├── quay-pull-secret.env        # Production registry credentials
│       └── skip-nameprefix.yaml        # Production name prefix configuration
└── README.md
```

## Base Components (base/cloudkit-aap/)

### aap.yaml
AnsibleAutomationPlatform custom resource configuration:
- **Controller**: Enabled for job template management
- **EDA (Event Driven Automation)**: Enabled for webhook processing
- **Hub**: Disabled (not required for this use case)
- **Lightspeed**: Disabled (AI assistance not required)

### aap_install.yaml
AAP operator installation and subscription resources.

### cloudkit_env.yaml
Environment configuration for AAP integration including:
- OpenShift cluster connection settings
- Webhook endpoints
- Job template configurations

### job.yaml
Bootstrap job that performs initial AAP configuration:
- Creates AAP organizations and projects
- Sets up job templates for cluster operations
- Configures inventories and credentials
- Establishes EDA rulebook activations

### image_secret.yaml
Container registry pull secrets for AAP execution environments.

## Configuration

### Development Environment (overlays/development/cloudkit-aap/)

The development overlay provides:

**Environment Variables**:
- `AAP_USERNAME` - AAP administrator username
- `AAP_PASSWORD` - AAP administrator password  
- `LICENSE_MANIFEST_PATH` - Path to AAP license file

**Key Features**:
- Uses environment variable substitution for credentials
- Configured for development execution environment images
- Simplified naming without prefixes
- Debug-level logging enabled

**Configuration Files**:
```yaml
# secret-patch.yaml example
aap_hostname: aap.dev.example.com
aap_username: "{{ lookup('env', 'AAP_USERNAME') }}"
aap_password: "{{ lookup('env', 'AAP_PASSWORD') }}"
aap_organization_name: cloudkit-dev
aap_project_name: cloudkit-aap-dev
aap_project_git_uri: https://github.com/organization/cloudkit-aap.git
aap_project_git_branch: develop
aap_ee_image: quay.io/rh-ee-jkary/cloudkit-aap-ee:latest
aap_validate_certs: false
```

### Production Environment (overlays/production/cloudkit-aap/)

The production overlay provides:

**Environment Variables**:
- `AAP_USERNAME` - AAP administrator username
- `AAP_PASSWORD` - AAP administrator password
- `LICENSE_MANIFEST_PATH` - Path to AAP license file

**Key Features**:
- Production-grade AAP configuration with increased replicas
- Production execution environment images
- Resource naming with `prod-` prefix
- SSL certificate validation enabled
- Production-level logging

**Configuration Files**:
```yaml
# secret-patch.yaml example
aap_hostname: aap.prod.example.com
aap_username: "{{ lookup('env', 'AAP_USERNAME') }}"
aap_password: "{{ lookup('env', 'AAP_PASSWORD') }}"
aap_organization_name: prod-cloudkit
aap_project_name: cloudkit-aap-prod
aap_project_git_uri: https://github.com/organization/cloudkit-aap.git
aap_project_git_branch: main
aap_ee_image: quay.io/organization/cloudkit-aap-ee:latest
aap_validate_certs: true
```

## Getting Started

### Clone and Initialize

```bash
# Clone the repository
git clone https://github.com/your-org/osc-config.git
cd osc-config

# Initialize git submodules (if present)
git submodule update --init --recursive
```

### Development Deployment

```bash
# Set required environment variables
export AAP_USERNAME="admin"
export AAP_PASSWORD="your-aap-password"
export LICENSE_MANIFEST_PATH="/path/to/license.zip"

# Update registry credentials
vi overlays/development/cloudkit-aap/quay-pull-secret.env

# Deploy to development environment
oc apply -k overlays/development/cloudkit-aap
```

### Production Deployment

**Important**: Configure production credentials and settings before deploying!

```bash
# Set required environment variables
export AAP_USERNAME="admin"
export AAP_PASSWORD="your-production-aap-password"
export LICENSE_MANIFEST_PATH="/path/to/production-license.zip"

# Update production configurations
vi overlays/production/cloudkit-aap/secret-patch.yaml      # AAP connection settings
vi overlays/production/cloudkit-aap/quay-pull-secret.env   # Registry credentials

# Deploy to production environment
oc apply -k overlays/production/cloudkit-aap
```

## Verification

### Check Deployment Status

```bash
# Check AAP pods
oc get pods -n cloudkit-aap-system

# Check AAP custom resources
oc get ansibleautomationplatform -n cloudkit-aap-system

# Check bootstrap job status
oc get jobs -n cloudkit-aap-system

# Check services
oc get services -n cloudkit-aap-system
```

### Check Logs

```bash
# Bootstrap job logs
oc logs -n cloudkit-aap-system job/aap-bootstrap -f

# AAP controller logs
oc logs -n cloudkit-aap-system -l app.kubernetes.io/name=controller -f

# AAP EDA logs
oc logs -n cloudkit-aap-system -l app.kubernetes.io/name=eda -f
```

### Verify AAP Configuration

```bash
# Check if AAP is accessible
oc port-forward -n cloudkit-aap-system service/cloudkit-controller-service 8080:80

# Access AAP UI at http://localhost:8080
# Login with configured credentials
```

## Environment Differences

| Aspect | Development | Production |
|--------|-------------|------------|
| **AAP Replicas** | 1 controller, 1 EDA | 2 controllers, 2 EDA |
| **Naming** | No prefix | `prod-` prefix |
| **SSL Validation** | Disabled | Enabled |
| **Images** | Development tags | Production/latest tags |
| **Git Branch** | develop | main |
| **Logging** | Debug level | Info level |
| **Credentials** | Environment variables | Environment variables + sealed secrets |

## Security Considerations

### Credential Management

- **Development**: Use environment variables for quick setup
- **Production**: Consider using external secret management:
  - OpenShift's built-in secrets
  - External Secrets Operator
  - HashiCorp Vault integration
  - Sealed Secrets

### Network Security

- Configure network policies to restrict AAP access
- Use TLS for all AAP communications
- Implement proper RBAC for AAP service accounts

### Container Security

- Use trusted container registry
- Scan execution environment images for vulnerabilities
- Implement image pull policies appropriately

## Troubleshooting

### Common Issues

1. **AAP Operator not installing**: Check subscription and operator group
2. **Bootstrap job failing**: Verify AAP credentials and connectivity
3. **EDA not receiving webhooks**: Check service endpoints and network policies
4. **Execution environment pull failures**: Verify registry credentials

### Debug Commands

```bash
# Check AAP operator status
oc get subscription -n cloudkit-aap-system

# Check AAP custom resource status
oc describe ansibleautomationplatform cloudkit -n cloudkit-aap-system

# Check bootstrap job details
oc describe job aap-bootstrap -n cloudkit-aap-system

# Test service connectivity
oc run debug --image=nicolaka/netshoot -it --rm -- /bin/bash
```

### Log Analysis

```bash
# Get all events in namespace
oc get events -n cloudkit-aap-system --sort-by=.metadata.creationTimestamp

# Check pod resource usage
oc top pods -n cloudkit-aap-system

# Describe failing pods
oc describe pod -n cloudkit-aap-system <pod-name>
```

## Customization

### Modifying AAP Configuration

To customize AAP settings:

1. Edit base configurations in `base/cloudkit-aap/`
2. Test changes in development overlay
3. Apply changes to production overlay
4. Validate with `kustomize build` before applying

### Adding New Environments

To create a new environment overlay:

1. Create new directory under `overlays/`
2. Copy and modify kustomization.yaml
3. Create environment-specific patch files
4. Update environment variables and secrets

### Execution Environment Customization

To use custom execution environments:

1. Build custom EE with required collections
2. Push to accessible container registry
3. Update image references in overlay patches
4. Update registry credentials if needed

## Support

For issues and questions:
- Check the troubleshooting section above
- Review AAP and OpenShift logs
- Consult Red Hat Ansible Automation Platform documentation
- Open an issue in the component repository
