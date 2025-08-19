# CloudKit Installer

This repository contains Kubernetes/OpenShift deployment configurations for the CloudKit platform, providing comprehensive cluster lifecycle management through multiple integrated components.

## Overview

CloudKit is a comprehensive platform that provides:

- **Cluster Lifecycle Management** - Automated cluster provisioning, scaling, and decommissioning
- **Event Driven Automation** - Responds to cluster events and webhook notifications
- **Service Management** - Fulfillment services for cluster operations
- **Configuration as Code** - Manages cluster configurations through Ansible playbooks and Kubernetes manifests

## Architecture

The CloudKit platform consists of three main components:

1. **CloudKit AAP (Ansible Automation Platform)** - Automated cluster provisioning and lifecycle management
2. **CloudKit Operator** - Kubernetes operator for cluster order management and HyperShift integration
3. **Fulfillment Service** - Backend service for cluster fulfillment operations with PostgreSQL database

## Component Repositories

The CloudKit platform is built from the following source repositories:

- **[cloudkit-operator](https://github.com/innabox/cloudkit-operator)** - Kubernetes operator for managing cluster orders and HyperShift integration
- **[cloudkit-aap](https://github.com/innabox/cloudkit-aap)** - Ansible Automation Platform playbooks and collections for cluster provisioning
- **[fulfillment-service](https://github.com/innabox/fulfillment-service)** - Backend gRPC service with PostgreSQL database for cluster fulfillment operations

## Prerequisites

Before deploying CloudKit, ensure you have:

### Core Requirements
- OpenShift cluster with admin access (version 4.17+ recommended)
- `oc` CLI configured with cluster admin privileges
- `kustomize` CLI tool (optional, can use `oc apply -k`)

### Certificate Management
- **cert-manager** operator installed and configured
- Certificate issuers configured for TLS certificate management
- Required for secure communication between components

### HyperShift Integration
- **MultiCluster Engine (MCE)** installed with HyperShift support
- HyperShift operator deployed and configured
- Required for hosted cluster management capabilities

### Component-Specific Prerequisites

#### CloudKit AAP
- **Red Hat Ansible Automation Platform Operator** installed
- **Red Hat Advanced Cluster Management (ACM)** installed (for cluster provisioning)
- **Valid AAP license manifest** - Download from [Red Hat Customer Portal](https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software) as `License.zip`
- Container registry credentials for execution environments

#### CloudKit Operator
- **HyperShift CRDs** (`HostedCluster`, `NodePool`) available
- **ClusterOrder CRDs** deployed
- Proper RBAC permissions for cluster-wide operations

#### Fulfillment Service
- **PostgreSQL** for database storage
- **TLS certificates** for secure database connections
- **Private registry access** for container images

## Creating Your Personal Overlay (Recommended)

**Best Practice:** Create your own overlay directory instead of using the provided overlays directly. This allows you to deploy a development instance that won't conflict with other developers.

```bash
# Create your own overlay directory using the development template
cp -r overlays/development overlays/user1

# Edit the namespace in your overlay to avoid conflicts with others
# Choose a unique namespace name for your deployment
sed -i 's/namespace: innabox-devel/namespace: foobar/' overlays/user1/kustomization.yaml
```

Here's what your `overlays/user1/kustomization.yaml` file should look like:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: foobar

# This applies a name prefix to cluster-scoped resources (ClusterRoles,
# ClusterRoleBindings) but does not modify namespaced resources.
transformers:
- prefixTransformer.yaml

labels:
- includeSelectors: true
  pairs:
    app.kubernetes.io/managed-by: kustomize
    environment: development

resources:
- ../../base

generatorOptions:
  disableNameSuffixHash: true

secretGenerator:

# This expects to find quay credentials in
# files/quay-pull-secret.json.
- name: quay-pull-secret
  files:
  - .dockerconfigjson=files/quay-pull-secret.json
  type: kubernetes.io/dockerconfigjson

# This expects to find an AAP license manifest
# in files/license.zip.
- name: config-as-code-manifest-ig
  options:
    labels:
      cloudkit.openshift.io/project: cloudkit-aap
  files:
  - license.zip=files/license.zip

# Optional: Uncomment to use custom images
# images:
# - name: fulfillment-service
#   newName: quay.io/your-username/fulfillment-service
#   newTag: latest

patches:
  - patch: |
      apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      metadata:
        name: clusterorders.cloudkit.openshift.io
      $patch: delete
  - patch: |
      apiVersion: apps/v1
      metadata:
        name: cloudkit-operator-controller-manager
      kind: Deployment
      name: manager
      spec:
        template:
          spec:
            containers:
              - name: manager
                env:
                - name: CLOUDKIT_CLUSTER_CREATE_WEBHOOK
                  value: http://cloudkit-aap-eda-foobar/create-hosted-cluster
                - name: CLOUDKIT_CLUSTER_DELETE_WEBHOOK
                  value: http://cloudkit-aap-eda-foobar/delete-hosted-cluster
```

Your personal overlay structure will look like:
```
overlays/user1/
├── kustomization.yaml          # Main kustomization file
├── prefixTransformer.yaml      # Adds prefix to cluster resources
└── files/
    ├── license.zip            # AAP license (you need to provide)
    └── quay-pull-secret.json  # Registry credentials (you need to provide)
```

## Configuration Files Setup

Before deploying, you need to set up configuration files in your overlay's `files/` directory:

### 1. Container Registry Credentials

Create `overlays/user1/files/quay-pull-secret.json`:

```json
{
  "auths": {
    "quay.io": {
      "auth": "base64-encoded-username:password"
    },
    "registry.redhat.io": {
      "auth": "base64-encoded-username:password"
    }
  }
}
```

To generate the base64 auth string:
```bash
echo -n "username:password" | base64
```

### 2. AAP License File

1. Download AAP license manifest from [Red Hat Customer Portal](https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software)
2. Save the downloaded file as `overlays/user1/files/license.zip` (filename must be exactly `license.zip`)

## Deployment

Deploy all CloudKit components using kustomize:

```bash
# Deploy all components using your personal overlay
oc apply -k overlays/user1

# Wait for deployments to be ready (replace 'foobar' with your chosen namespace)
oc wait --for=condition=Available deployment --all -n foobar --timeout=600s

# Check deployment status
oc get pods -n foobar
```

## Fulfillment Service Interface

The CloudKit platform provides APIs through two main interfaces:

- **[fulfillment-cli](https://github.com/innabox/fulfillment-cli)** - Command-line interface for interacting with the fulfillment service
- **[fulfillment-api](https://github.com/innabox/fulfillment-api)** - REST/gRPC API documentation and specifications

## Fulfillment CLI Workflow

Follow this workflow to use the fulfillment-cli with your deployed CloudKit instance:

### 1. Obtain the fulfillment-cli Binary

Get the binary from the [fulfillment-cli repository](https://github.com/innabox/fulfillment-cli):

```bash
# Download from GitHub releases (adjust URL for latest version)
curl -L -o fulfillment-cli https://github.com/innabox/fulfillment-cli/releases/latest/download/fulfillment-cli-linux-amd64
chmod +x fulfillment-cli
```

### 2. Deploy Using Kustomize

```bash
oc apply -k overlays/user1
```

### 3. Login to Fulfillment Service

```bash
./fulfillment-cli login \
  --address fulfillment-api-foobar.apps.your-cluster.com \
  --token-script "oc create token fulfillment-controller -n foobar --duration 1h --as system:admin" \
  --insecure
```

*Note: Replace the address with your actual route URL. You can find it with `oc get routes -n foobar`*

### 4. Create a kubeconfig.hub-access

Follow the instructions in `base/fulfillment-service/hub-access/README.md` to generate a `kubeconfig.hub-access` file:

```bash
# Use the script from the hub-access README to generate kubeconfig
# This creates a service account with appropriate permissions
./create-kubeconfig-hub-access.sh
```

### 5. Create a Hub

```bash
./fulfillment-cli create hub \
  --kubeconfig=kubeconfig.hub-access \
  --id hub1 \
  --namespace foobar
```

### 6. Create a Cluster

```bash
./fulfillment-cli create cluster --template ocp_4_17_small
```

### 7. Check Cluster Status

```bash
./fulfillment-cli get cluster
```

### Additional Useful Commands

- **Get available cluster templates:**
  ```bash
  ./fulfillment-cli get clustertemplates
  ```

- **Get detailed cluster information:**
  ```bash
  ./fulfillment-cli get cluster -o yaml
  ```

- **Delete a cluster:**
  ```bash
  ./fulfillment-cli delete cluster <cluster-id>
  ```

## Accessing Ansible Automation Platform

After deployment, you can access the AAP web interface to monitor jobs and manage automation:

### Getting AAP URL and Admin Password

1. **Get the AAP URL:**
   ```bash
   oc get route -n foobar | grep innabox-aap
   # Look for routes containing 'innabox-aap' in the name
   # The main AAP URL will be something like: https://innabox-aap-foobar.apps.your-cluster.com
   ```

2. **Get the admin password:**
   ```bash
   # Find the AAP admin password secret
   oc get secrets -n foobar | grep admin-password
   
   # Extract the password (typically named innabox-aap-admin-password)
   oc get secret innabox-aap-admin-password -n foobar -o jsonpath='{.data.password}' | base64 -d
   ```

3. **Login to AAP:**
   - Open the AAP controller URL in your browser
   - Username: `admin`
   - Password: (from step 2)

### Using AAP Interface

From the AAP web interface, you can:
- Monitor cluster provisioning jobs and their status
- View automation execution logs and troubleshoot failures
- Manage job templates and automation workflows
- Configure additional automation tasks
- View inventory and host information

## Repository Structure

```
cloudkit-installer/
├── base/                           # Base Kustomize configurations
│   ├── shared/                     # Shared namespace and common resources
│   ├── cloudkit-aap/              # Ansible Automation Platform base config
│   ├── cloudkit-operator/         # CloudKit Operator base config
│   └── fulfillment-service/       # Fulfillment Service base config
│       ├── ca/                    # Certificate Authority setup
│       ├── database/              # PostgreSQL database
│       ├── service/               # Main service deployment with Envoy proxy
│       ├── controller/            # Controller component
│       ├── admin/                 # Admin service account
│       ├── client/                # Client service account
│       └── hub-access/            # Hub access service account and README
├── overlays/                      # Environment-specific overlays
│   ├── development/               # Development environment template
│   └── user1/                     # Your personal overlay (create this)
└── components/                    # Git submodules for actual source code
    ├── cloudkit-aap/             # Ansible playbooks and collections
    ├── cloudkit-operator/        # Go-based operator source
    └── fulfillment-service/      # Go-based service with gRPC API
```

## Troubleshooting

### Common Issues

1. **cert-manager not ready**: Ensure cert-manager operator is installed and running
2. **HyperShift CRDs missing**: Verify MultiCluster Engine is deployed with HyperShift enabled
3. **Certificate issues**: Check cert-manager logs and certificate status
4. **Database connection failures**: Verify database certificates and connectivity
5. **cloudkit-operator CrashLoopBackOff**: Usually indicates missing HyperShift permissions or CRDs not available
6. **ImagePullBackOff errors**: Verify registry credentials in `files/quay-pull-secret.json`
7. **namePrefix conflicts**: Certificate and secret names may not match due to kustomize namePrefix application

### Debug Commands

```bash
# Check certificate status
oc describe certificate -n foobar

# Check certificate issuer status
oc describe issuer -n foobar

# Check pod events
oc describe pod -n foobar <pod-name>

# Check service endpoints
oc get endpoints -n foobar

# Check secrets
oc get secrets -n foobar

# View component logs
oc logs -n foobar deployment/fulfillment-service -c server --tail=100
oc logs -n foobar deployment/cloudkit-operator-controller-manager --tail=100

# Get all events in namespace
oc get events -n foobar --sort-by=.metadata.creationTimestamp
```

## Development

For development work on the individual components:

1. Fork/clone the component repositories (cloudkit-operator, cloudkit-aap, fulfillment-service)
2. Make your changes in the component repository
3. Build and push images to your registry
4. Update your overlay's `kustomization.yaml` to reference your custom images:
   ```yaml
   images:
   - name: fulfillment-service
     newName: quay.io/your-username/fulfillment-service
     newTag: your-tag
   ```
5. Deploy using `oc apply -k overlays/your-overlay`

## Support

For issues and questions:
- Check the troubleshooting section above
- Review component logs for error messages
- Verify prerequisites are properly installed
- Open issues in the respective component repositories

## License

This project is licensed under the Apache License, Version 2.0.