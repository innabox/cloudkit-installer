# NFS Storage Setup for VM Live Migration with OpenShift Data Foundation

## Overview
This setup provides NFS-based shared storage for OpenShift Virtualization VMs to enable live migration capabilities through OpenShift Data Foundation (ODF). VMs using this storage can be migrated between cluster nodes without downtime.

## NFS Server Configuration

### Server Details
- **NFS Server IP**: 192.168.12.126
- **Export Path**: /home/nfs
- **Network Access**: 172.16.0.0/18 (HCP cluster network)
- **VM Storage Size**: 25GiB per VM

### Server Setup Commands
```bash
# Install NFS server
sudo dnf install -y nfs-utils

# Create and configure NFS directory
sudo mkdir -p /home/nfs
sudo chown -R nobody:nobody /home/nfs
sudo chmod -R 777 /home/nfs

# Configure exports for HCP cluster
sudo tee /etc/exports << 'EOF'
/home/nfs 172.16.0.0/18(rw,sync,no_subtree_check,no_root_squash)
EOF

# Start NFS services
sudo systemctl enable --now nfs-server
sudo exportfs -ra
```

## OpenShift Configuration with ODF

### Deployment Order
Apply the Kubernetes manifests in this order:

1. **Install ODF Operator**:
   ```bash
   oc apply -f odf-operator.yaml
   ```

2. **Configure NFS Backend**:
   ```bash
   oc apply -f odf-nfs-config.yaml
   oc apply -f nfs-storageclass.yaml
   ```

3. **Verify Deployment**:
   ```bash
   oc get csv -n openshift-storage
   oc get storageclass | grep nfs
   ```

### Storage Classes Available
- **nfs-vm-migration**: Direct NFS storage class for VM migration (25GiB)
- **odf-nfs-vm-storage**: ODF-managed NFS storage class

Both storage classes support:
- **Access Mode**: ReadWriteMany (required for live migration)  
- **Reclaim Policy**: Retain (data persists after PVC deletion)
- **Volume Binding**: WaitForFirstConsumer
- **NFS Version**: 4.1 with optimized mount options

## VM Configuration

### Using NFS Storage in VMs
When creating VMs, specify the NFS storage class in DataVolume templates:

```yaml
dataVolumeTemplates:
- metadata:
    name: vm-disk
  spec:
    pvc:
      accessModes:
      - ReadWriteMany                    # Critical for live migration
      resources:
        requests:
          storage: 25Gi                  # 25GiB storage per VM
      storageClassName: nfs-vm-migration # Use NFS storage class
      volumeMode: Filesystem
```

### Key Configuration Points
- **storageClassName**: Use `nfs-vm-migration` or `odf-nfs-vm-storage`
- **accessModes**: Must include `ReadWriteMany` for live migration
- **storage**: Set to `25Gi` for 25GiB VM disks
- **volumeMode**: Should be `Filesystem` for most use cases

### Creating PersistentVolumes
For each VM, create a dedicated PV:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: vm-pv-001
spec:
  capacity:
    storage: 25Gi
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-vm-migration
  nfs:
    server: 192.168.12.126
    path: /home/nfs/vm-001  # Unique path per VM
```

## Live Migration Benefits
- VMs can migrate between cluster nodes without downtime
- Shared NFS storage ensures disk data is accessible from any node
- Enables maintenance, load balancing, and high availability scenarios
- ODF provides additional management and monitoring capabilities

## Troubleshooting

### Common Issues
1. **NFS Mount Failures**: Check network connectivity between cluster nodes and NFS server
2. **Permission Errors**: Verify NFS exports and directory permissions  
3. **ODF Installation**: Check operator logs in openshift-storage namespace
4. **PV Binding**: Ensure PV paths exist on NFS server before creating PVCs

### Verification Commands
```bash
# Test NFS connectivity from cluster nodes
showmount -e 192.168.12.126

# Check storage classes
oc get storageclass | grep nfs

# Verify ODF operator
oc get csv -n openshift-storage

# Test PVC creation
oc create -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 25Gi
  storageClassName: nfs-vm-migration
EOF
```

### Creating VM Storage Directories
```bash
# Create individual directories for each VM on NFS server
sudo mkdir -p /home/nfs/vm-001 /home/nfs/vm-002 /home/nfs/vm-003
sudo chown -R nobody:nobody /home/nfs/vm-*
sudo chmod -R 755 /home/nfs/vm-*
```

## Security Considerations
- NFS exports are configured with `no_root_squash` for VM compatibility
- Network access is restricted to HCP cluster subnet (172.16.0.0/18)
- Each VM gets its own subdirectory for isolation
- Consider implementing NFS security features like Kerberos for production use