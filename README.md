# OSAC Installer

This repository contains Kubernetes/OpenShift deployment configurations for the OSAC
platform, providing a fulfillment service framework for clusters and virtual machines.

> **Note:** Throughout this guide, `<namespace>` refers to the namespace where OSAC
> is deployed (typically innabox). Replace it according to your environment.

## Overview

The primary requirement is a streamlined, self-service pathway for provisioning clusters
and virtual machines subject to administrative policies. By leveraging OpenShift
Advanced Cluster Management and OpenShift Virtualization, we can fulfill this
operational need, delivering the necessary capabilities in a secure and automated
manner.

To support this, this solution integrates with an organization's Identity Management
(IDM) provider to authenticate users and map their identities to specific tenants. Since
a tenant acts as a secure boundary for resources, users are assigned roles within that
boundary that strictly define their permissions (e.g., read-only or admin access). This
model supports multi-tenancy, allowing a single user to hold distinct permissions across
multiple tenants if necessary.

**User Workflow:** Users initiate a request through the fulfillment API. The API forwards
this request to a Hub cluster, where the OSAC operator interprets the requirement and
coordinates with the automation backend to provision the resource.

**Administrator Workflow:** Administrators define the templates that drive this automation.
These templates are packaged as Ansible roles and executed by the Red Hat Ansible
Automation Platform (AAP). When a template is registered with AAP, the system
automatically updates the fulfillment service, allowing authorized users to list and
deploy that specific configuration within their tenant.

Ultimately, this architecture empowers end users to manage the full lifecycle of their
infrastructure securely and autonomously. The system is designed for scale, allowing
multiple Hubs to be registered to a single fulfillment service.

The service exposes both gRPC and REST interfaces, allowing administrators to easily
integrate these capabilities into custom UIs or tools. API definitions are available in
the [fulfillment-api](https://github.com/innabox/fulfillment-api) repository.
Additionally, a reference CLI implementation is provided in the
[fulfillment-cli](https://github.com/innabox/fulfillment-cli) repository. Designed to
follow the conventions of oc, this CLI offers a familiar experience for OpenShift users.

## OSAC Components

The OSAC platform relies on three core components to deliver governed self-service:

1. **Fulfillment Service:**
   The API and frontend entry point used to manage user requests and map them to specific
   templates.

2. **OSAC Operator:**
   An OpenShift operator residing on the Hub cluster (ACM/OCP-Virt). It orchestrates the
   lifecycle of clusters and VMs by coordinating between the Fulfillment Service and the
   automation backend.

3. **Automation Backend (AAP):**
   Leverages the **Red Hat Ansible Automation Platform** to store and execute the custom
   template logic required for provisioning.

### Prerequisites & Setup

> **System Requirements** This solution requires the following platforms to be installed
> and operational:
> * Red Hat OpenShift Advanced Cluster Management (RHACM)
> * Red Hat OpenShift Virtualization (OCP-Virt)
> * Red Hat Ansible Automation Platform (AAP)

**Configuration Manifests**

The `/prerequisites` directory contains additional manifests required to configure the
target Hub cluster.

> **⚠️ Important: Cluster-Wide Impact** If you are using a shared cluster or are not the
> primary administrator, **do not apply these manifests without consultation.** These
> files modify cluster-wide settings. Please coordinate with the appropriate cluster
> administrators before proceeding.


### 📋 Prerequisites Summary

| **Category** | **Requirement** | **Notes / Details** |
|---------------|-----------------|----------------------|
| **Platform** | Red Hat OpenShift Container Platform (OCP) 4.17 or later | Must have cluster admin access to the hub cluster. |
| **Operators** | Red Hat Advanced Cluster Management (RHACM) 2.18+<br>Red Hat OpenShift Virtualization (OCP-Virt) 4.17+<br>Red Hat Ansible Automation Platform (AAP) 2.5+ | These must be installed and running prior to OSAC installation. |
| **CLI Tools** | `oc` (OpenShift CLI) v4.17+<br>`kubectl` (optional)<br>`kustomize` v5.x<br>`git` | Ensure all CLIs are available in your `PATH`. |
| **Container Registry Access** | `registry.redhat.io` and `quay.io` | Verify credentials and pull secrets are valid in the target cluster namespace. |
| **Network / DNS** | Ingress route configured for OSAC services | Required for external access to fulfillment API and AAP UI. |
| **Authentication / IDM** | Organization Identity Provider (e.g., Keycloak, LDAP, RH-SSO) | Used for tenant and user identity mapping. |
| **Storage** | Dynamic storage class available (e.g., `ocs-storagecluster-cephfs`, `lvms-storage`) | Required for persistence of operator and AAP components. |
| **Permissions** | Cluster-admin access to deploy operators and create CRDs | Limited access users can only deploy into namespaces configured by the admin. |
| **License Files** | `license.zip` (AAP subscription) | Must be placed under `overlays/<your-overlay>/files/license.zip`. |
| **Internet Access** | Outbound access to GitHub (for fetching submodules, releases) | Required during installation and updates. |


## Installation Strategy

OSAC uses Kustomize for installation. This approach allows you to easily override and
customize your deployment to meet specific needs.

To manage dependencies, the OSAC-installer repository uses Git submodules to import the
required manifests from each component. This ensures component versions are pinned and
compatible with the installer.

### Customizing Your Installation

Use Kustomize to manage your environment-specific configurations.

1. Initialize the Overlay:
   Run the following to duplicate the development template:

   ```
   $ cp -r overlays/development overlays/<your-overlay-name>
   ```

2. Populate Required Files:
   Ensure your new directory structure matches the following, paying close attention to
   the license.zip requirement:

   ```
   overlays/<your-overlay-name>/
   ├── kustomization.yaml      # Edit this to apply patches/changes
   └── files/
       └── license.zip         # REQUIRED: Your AAP license file
   ```

3. Customize:
   Modify the manifests in your new overlay folder to suit your deployment needs.


> For more information on structuring overlays and patches, please consult the [official
> Kustomize documentation.](https://kubectl.docs.kubernetes.io/references/kustomize/)


### Obtaining an AAP License

Download AAP license manifest from [Red Hat Customer
Portal](https://access.redhat.com/downloads/content/480/ver=2.5/rhel---9/2.5/x86_64/product-software)

## Deploying OSAC components

The development overlay should work out of the box.

### Install and monitor progress

```
$ oc apply -k overlays/development

# Verify all the objects are applied.
$ watch oc get -n <namespace> pods
```

Several pods restart during initialization.  The OpenShift job named `aap-bootstrap` restarts several times before
completing.  This is expected behavior.

Once the `aap-bootstrap` job completes, OSAC is ready for use.

**Alternative:**

### Install with the wait option
```
# Wait for deployments to be ready.
$ oc wait --for=condition=Available deployment --all -n <namespace> --timeout=600s
```

In this new overlay, different images can be used and patches applied to suit your
needs.

## Fulfillment CLI: Setup & Usage

To install the CLI and register a hub follow these steps:

1. Install the Binary
   Download the latest release and make it executable.

   ```bash
   # Adjust URL for the latest version as needed
   $ curl -L -o fulfillment-cli \
       https://github.com/innabox/fulfillment-cli/releases/latest/download/fulfillment-cli-linux-amd64
   $ chmod +x fulfillment-cli

   # Optional: Move to your path
   $ sudo mv fulfillment-cli /usr/local/bin/
   ```

2. Log in to the Service
   Authenticate with the fulfillment API. You will need the route address and a valid
   token generation script.

   ```
   $ fulfillment-cli login \
       --address <your-fulfillment-route-url> \
       --token-script "oc create token fulfillment-controller -n <namespace> \
       --duration 1h --as system:admin" \
       --insecure
   ```

   > Tip: Retrieve your route URL using: oc get routes -n <namespace>

3. Register the Hub
   To allow the OSAC operator to communicate with the fulfillment service, you must
   obtain the kubeconfig and register the hub.  The script located at
   `scripts/create-kubeconfig-hub-access.sh` demonstrates how to generate the kubeconfig
   for a hub.

   ```
   # Generate the kubeconfig
   $ ./scripts/create-kubeconfig-hub-access.sh

   # Register the Hub
   $ fulfillment-cli create hub \
       --kubeconfig=kubeconfig.hub-access \
       --id <hub-name> \
       --namespace <namespace>
   ```

   > Refer to `base/fulfillment-service/hub-access/README.md` for more information

## Accessing Ansible Automation Platform

After deployment, you can access the AAP web interface to monitor jobs and manage automation:

### Get the AAP URL

```bash
$ oc get route -n <namespace> | grep innabox-aap
```

AAP routes will contain 'innabox-aap' in the name.

> **Note:**
> The main AAP URL will be something like: https://innabox-aap-<namespace>.apps.your-cluster.com

### Get the AAP admin password

```bash
# Find the AAP admin password secret
$ oc get secrets -n <namespace> | grep admin-password

# Extract the password (typically named innabox-aap-admin-password)
$ oc get secret innabox-aap-admin-password -n <namespace> -o jsonpath='{.data.password}' | base64 -d
```

### Login to AAP
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

## Troubleshooting

### Common Issues

1. **cert-manager not ready**: Ensure cert-manager operator is installed and running
2. **Certificate issues**: Check cert-manager logs and certificate status
3. **ImagePullBackOff errors**: Verify registry credentials in `files/quay-pull-secret.json` and image string

### Debug Commands

```bash
# Check certificate status
$ oc describe certificate -n <namespace>

# Check certificate issuer status
$ oc describe issuer -n <namespace>

# Check pod events
$ oc describe pod -n <namespace> <pod-name>

# Check service endpoints
$ oc get endpoints -n <namespace>

# Check secrets
$ oc get secrets -n <namespace>

# View component logs
$ oc logs -n <namespace> deployment/fulfillment-service -c server --tail=100
$ oc logs -n <namespace> deployment/OSAC-operator-controller-manager --tail=100

# Get all events in namespace
$ oc get events -n <namespace> --sort-by=.metadata.creationTimestamp
```



## Support

For issues and questions:
- Check the troubleshooting section above
- Review component logs for error messages
- Verify prerequisites are properly installed
- Open issues in the respective component repositories

## License

This project is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
