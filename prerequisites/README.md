# Prerequisites for OSAC Installation

## Overview

The OSAC solution requires several components to be installed on the cluster before deployment.
Your administrator may have set up some of these components already. Check with them first
before installing.

The manifests in this directory are examples for development and testing environments.

## Required Components

| Component | Purpose | Manifest |
|-----------|---------|----------|
| Cert Manager | TLS certificate management | `cert-manager.yaml` |
| Trust Manager | CA certificate distribution | `trust-manager.yaml` |
| CA Issuer | ClusterIssuer for signing certificates | `ca-issuer.yaml` |
| Authorino Operator | API authorization | `authorino-operator.yaml` |
| Keycloak | Identity provider (OIDC) | `keycloak/` |
| Red Hat AAP Operator | Ansible Automation Platform | `aap-installation.yaml` |
| OpenShift Virtualization | VM as a Service support | `vmaas-components.yaml` |
| NFS Subdir Provisioner | Dynamic storage for VM migration | `nfs-subdir-provisioner/` |

**Note:** Red Hat Advanced Cluster Management (ACM) is assumed to be already installed.

## Installation Order

Components must be installed in the following order due to dependencies.

**Important:** Some manifests may need to be applied multiple times. When new CRDs are created,
dependent resources may fail on the first apply. Simply re-run the `oc apply` command.

### Step 1: Cert Manager

```bash
oc apply -f prerequisites/cert-manager.yaml

# Wait for the operator to be ready
oc wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s
oc wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s
```

### Step 2: Trust Manager

Requires cert-manager to be running.

```bash
oc apply -f prerequisites/trust-manager.yaml

# Verify installation
oc get pods -n cert-manager -l app.kubernetes.io/name=trust-manager
oc get crd bundles.trust.cert-manager.io
```

### Step 3: CA Issuer

Creates a self-signed ClusterIssuer for signing certificates.

```bash
oc apply -f prerequisites/ca-issuer.yaml

# Verify the ClusterIssuer is ready
oc get clusterissuer default-ca
```

### Step 4: Authorino Operator

Provides API authorization capabilities.

```bash
oc apply -f prerequisites/authorino-operator.yaml

# Wait for the operator to be installed
oc get csv -n openshift-operators | grep authorino
```

### Step 5: Keycloak (Optional)

Identity provider for OIDC authentication. Skip if using an external identity provider.

```bash
oc apply -k prerequisites/keycloak/

# Wait for Keycloak to be ready
oc get pods -n keycloak
```

### Step 6: Red Hat AAP Operator

Ansible Automation Platform for cluster provisioning workflows.

```bash
oc apply -f prerequisites/aap-installation.yaml

# Wait for the operator to be installed
oc get csv -n ansible-aap | grep ansible-automation-platform
```

### Step 7: OpenShift Virtualization (Optional)

Required for VM as a Service (VMaaS) functionality.

```bash
oc apply -f prerequisites/vmaas-components.yaml

# Wait for the HyperConverged operator to be ready
oc wait --for=condition=Available hco kubevirt-hyperconverged -n openshift-cnv --timeout=600s
```

### Step 8: NFS Subdir Provisioner (Optional)

Required for VM live migration with shared storage.

Before applying, configure your NFS server settings in the overlay's `nfs-patch.yaml`:

```yaml
# Edit prerequisites/nfs-subdir-provisioner/overlays/<environment>/nfs-patch.yaml
env:
  - name: NFS_SERVER
    value: "your-nfs-server.example.com"  # Your NFS server address
  - name: NFS_PATH
    value: "/exported/path"               # Your NFS exported path
volumes:
  - name: nfs-client-root
    nfs:
      server: "your-nfs-server.example.com"
      path: "/exported/path"
```

Then apply the configuration:

```bash
oc apply -k prerequisites/nfs-subdir-provisioner/overlays/<environment>/

# Verify the storage class is created
oc get storageclass | grep nfs
```

## Verification

After installing all prerequisites, verify the components are running:

```bash
# Cert Manager
oc get pods -n cert-manager

# Authorino
oc get pods -n openshift-operators -l app=authorino-operator

# AAP
oc get pods -n ansible-aap

# OpenShift Virtualization (if installed)
oc get pods -n openshift-cnv
```

## Notes

- These manifests are provided as examples for development environments
- Production deployments may require additional configuration
- Consult your cluster administrator before installing operators
- Some resources depend on CRDs that are created by operators; if an apply fails, wait for the operator to finish installing and try again
