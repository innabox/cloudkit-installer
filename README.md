# OSAC Installer

This repository contains Kubernetes/OpenShift deployment configurations for the OSAC
platform, providing a fulfillment service framework for clusters and virtual machines.

## Overview

There is a general need for OpenShift Advanced Cluster Management and OpenShift
Virtualization to provide an easier/self-service mechanism to provision clusters and
virtual machines in a controlled manner defined by the admin/service provider.

Self-service means providing an end user the ability to request a cluster/VM using a
fulfillment service which manages these requests and maintains security and privacy
through multi-tenancy.  The technical details of executing these requests are handled by
the definition of templates by the admin/service provider, giving the end user the ease
of submitting a request for one of these curated clusters/VMs simply by selecting the
template ID.

This fulfillment service integrates with an organization's IDM (Identity Management
Provider) for authentication and mapping them to a tenant.  Users within a tenant are
assigned different permissions and belong to one or more tenants.  Permissions are
grant through the use of roles typically defining either an admin or user's access to
resources and resource verbs. Individuals/machines can belong to one or more organizations if
needed.

A typical user workflow has them creating a fulfillment request through the fulfillment
API which takes this request and passes it on to a hub cluster.  Hubs contain the OSAC
operator which is responsible for managing the life cycle of a resource and
communicating with an automated back end to fulfill the requests.

Administrators/service providers setup the 'hub' and configure/create the definitions of
available templates. Templates contain the automation to execute life cycle events when
requested by the OSAC operator.  A template and its automation is published as an
Ansible role.  OSAC uses the Red Hat Ansible Automation Platform (AAP) to manage and
execute these scripts when requested by the OSAC operator. Templates registered with AAP
are automatically published back to the fulfillment service linking the ability to list
and apply available templates associated to a tenant.

This architecture allows an organization to empower the end user to provision and
de-provision infrastructure on their own in a secure and automated manner.  Multiple
hubs can be registered to a fulfillment service enabling the ability to scale up.

The fulfillment service is API based (gRPC/REST) allowing admins/service providers to
integrate its functionality into their own UI or CLI functions.  A sample CLI interface
is found in the [fulfillment-cli](https://innabox/fulfillment-cli) repository. Use of
this CLI will feel familiar to OpenShift users in its style and use being it
works similarly to the conventions of the oc/kubectl command.

The API interface for the fulfillment service can be found at
[fulfillment-api](https://innabox/fulfillment-api).

## OSAC Components

OSAC is a comprehensive platform leveraging:

1. **Fulfillment Service** - API/Front end used to manage requests for resources using
   templates.
2. **OSAC Operator** - OpenShift operator running in an ACM/OCP-Virt cluster managing
   the lifecycle of clusters/vms.
3. **OSAC AAP (Ansible Automation Platform)** - Back end system for storing and
   executing custom template logic.

>** NOTE ** Red Hat OpenShift Advanced Cluster Management (RHACM), Red Hat OpenShift
>Virtualization (OCP-Virt), and Red Hat Ansible Automation Platform must be installed


Additional manifests found in /prerequisites can be applied if the
target hub cluster does not have them.  If you are using a shared cluster or you are not
the admin of the cluster then you should sync with the appropriate people before
applying any of these manifests as they have cluster wide effects.

### 📋 Prerequisites Summary

| **Category** | **Requirement** | **Notes / Details** |
|---------------|-----------------|----------------------|
| **Platform** | Red Hat OpenShift Container Platform (OCP) 4.17 or later | Must have cluster admin access to the hub cluster. |
| **Operators** | Red Hat Advanced Cluster Management (RHACM) 2.18+<br>Red Hat OpenShift Virtualization (OCP-Virt) 4.17+<br>Red Hat Ansible Automation Platform (AAP) 2.5+ | These must be installed and running prior to OSAC installation. |
| **CLI Tools** | `oc` (OpenShift CLI) v4.17+<br>`kubectl` (optional)<br>`kustomize` v5.x<br>`git` | Ensure all CLIs are available in your `$PATH`. |
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
required manifests from each component. This method pins specific component versions to
the main installer, ensuring version compatibility.

### Customizing Your Installation
To apply your custom configuration, you'll create a new Kustomize overlay based on the
provided development example.

1. Copy the Base Overlay
  Start by copying the development overlay directory to create your
own:
  ```
  cp -r overlays/development overlays/<your-overlay-name>

  # Place your environment-specific files here
  # overlays/<your-overlay-name>/files/
  ```

2. Add Required Files
  Place your environment-specific files into the new files/ subdirectory (overlays/<your-overlay-name>/files/).

  Save the downloaded file as `overlays/<your overlay>/files/license.zip` (filename must
  be exactly `license.zip`) The license.zip file is required for the AAP back
  end to function correctly.

3. Apply Custom Changes Modify the Kustomize manifests within your new overlay directory
   (overlays/<your-overlay-name>/) to apply your desired configuration changes.

For more information on how to structure your customizations, you can consult the
official Kustomize documentation. The OSAC solution currently uses kustomizations and

### Obtaining an AAP Licence

Download AAP license manifest from [Red Hat Customer
Portal](https://access.redhat.com/downloads/content/480/ver=2.4/rhel---9/2.4/x86_64/product-software)

## Applying manifest files

The development overlay should work out of the box.

### Fig 1 - Install and monitor
```
> oc apply -k overlays/development
> # Verify all the objects are applied.
> watch oc get -n innabox pods
```

You will notice a number of pods coming and going while the individual components
install.  At the top, a pod label 'aap-bootstrap' will have a number of attempts before
it will complete.  This is normal and the job will keep restarting until it successfully
finishes.  Once the aap-bootstrap shows as complete then the solution is ready for use.

Alternatively the install will be ready with the command:

### Install wait command
```
> # Wait for deployments to be ready (replace 'user1' with your chosen namespace)
> oc wait --for=condition=Available deployment --all -n user1 --timeout=600s
```

In this new overlay, different images can be used and patches applied to suit your
needs.

## Fulfillment CLI Workflow

Follow this workflow to use the fulfillment-cli with your deployed OSAC instance:

### 1. Obtain the fulfillment-cli Binary

Get the binary from the [fulfillment-cli repository](https://github.com/innabox/fulfillment-cli):

```bash
# Download from GitHub releases (adjust URL for latest version)
curl -L -o fulfillment-cli https://github.com/innabox/fulfillment-cli/releases/latest/download/fulfillment-cli-linux-amd64
chmod +x fulfillment-cli
```

### 2. Deploy Using Kustomize

See the section above for how to create customized overlays.

```bash
oc apply -k overlays/user1
```

### 3. Login to Fulfillment Service

```bash
./fulfillment-cli login \
  --address fulfillment-api-user1.apps.your-cluster.com \
  --token-script "oc create token fulfillment-controller -n user1 --duration 1h --as system:admin" \
  --insecure
```

*Note: Replace the address with your actual route URL. You can find it with `oc get routes -n user1`*

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
  --namespace user1
```

## Creating a Cluster

### Cluster creation requests
```bash
./fulfillment-cli create cluster --template cloudkit.templates.ocp_4_17_small
```

### Check Cluster Status

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

## Creating Virtual Machines

```bash
./fulfillment-cli create virtualmachine \
    --template cloudkit.templates.ocp_virt_vm \
    -p name='VM1' \
    -p public_ssh_keys=`cat $HOME/.ssh/id_rsa.pub`
```

### Check VM Status

```bash
./fulfillment-cli get virtualmachines
```

### Additional Useful Commands

- **Get available VM templates:**
  ```bash
  ./fulfillment-cli get virtualmachinetemplates
  ```

- **Get detailed VM information:**
  ```bash
  ./fulfillment-cli get virtualmachine VM1 -o yaml
  ```

- **Delete a VM:**
  ```bash
  ./fulfillment-cli delete VM <vm-id>
  ```

## Accessing Ansible Automation Platform

After deployment, you can access the AAP web interface to monitor jobs and manage automation:

### Getting AAP URL and Admin Password

### **Get the AAP URL:**
   ```bash
   oc get route -n user1 | grep innabox-aap
   # Look for routes containing 'innabox-aap' in the name
   # The main AAP URL will be something like: https://innabox-aap-user1.apps.your-cluster.com
   ```

### **Get the admin password:**
   ```bash
   # Find the AAP admin password secret
   oc get secrets -n user1 | grep admin-password

   # Extract the password (typically named innabox-aap-admin-password)
   oc get secret innabox-aap-admin-password -n user1 -o jsonpath='{.data.password}' | base64 -d
   ```

### **Login to AAP:**
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
oc describe certificate -n user1

# Check certificate issuer status
oc describe issuer -n user1

# Check pod events
oc describe pod -n user1 <pod-name>

# Check service endpoints
oc get endpoints -n user1

# Check secrets
oc get secrets -n user1

# View component logs
oc logs -n user1 deployment/fulfillment-service -c server --tail=100
oc logs -n user1 deployment/OSAC-operator-controller-manager --tail=100

# Get all events in namespace
oc get events -n user1 --sort-by=.metadata.creationTimestamp
```



## Support

For issues and questions:
- Check the troubleshooting section above
- Review component logs for error messages
- Verify prerequisites are properly installed
- Open issues in the respective component repositories

## License

This project is licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
