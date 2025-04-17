#!/usr/bin/env bash
set -e

# Generate MAC address
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
echo "Generated MAC Address: $GEN_MAC"

# Get next VM ID
NEXTID=$(pvesh get /cluster/nextid)
echo "Next VM ID: $NEXTID"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Temporary Directory: $TEMP_DIR"
pushd $TEMP_DIR >/dev/null

# Download Ubuntu image
URL=https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
echo "Downloading image from: $URL"
wget -q $URL
FILE=$(basename $URL)
echo "Downloaded File: $FILE"

# Get storage
STORAGE=$(pvesm status -content images | awk 'NR==2 {print $1}')
if [ -z "$STORAGE" ]; then
    echo "Error: STORAGE is not set."
    exit 1
fi
echo "Using Storage: $STORAGE"

# Set VM ID
VMID=$NEXTID
echo "VM ID: $VMID"

# Set storage type
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
if [ -z "$STORAGE_TYPE" ]; then
    echo "Error: STORAGE_TYPE is not set."
    exit 1
fi
echo "Storage Type: $STORAGE_TYPE"

# Set disk variables
DISK_EXT=".img"
DISK_IMPORT="-format raw"
DISK0=vm-${VMID}-disk-0${DISK_EXT}
DISK0_REF=${STORAGE}:${DISK0}
echo "Disk Reference: $DISK0_REF"

# Create VM
qm create $VMID -agent 1 -tablet 0 -localtime 1 -bios ovmf -cores 2 -memory 8192 -name ubuntu -net0 virtio,bridge=vmbr0,macaddr=$GEN_MAC -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
echo "Created VM with ID: $VMID"

# Allocate storage
pvesm alloc $STORAGE $VMID $DISK0 40G
echo "Allocated storage for disk: $DISK0"

# Import disk
qm importdisk $VMID ${FILE} $STORAGE ${DISK_IMPORT}
echo "Imported disk: $FILE"

# Attach cloud-init drive
qm set $VMID --ide2 $STORAGE:cloudinit

# Prompt for required inputs if not set
if [ -z "$CI_USER" ]; then
    read -p "Enter cloud-init username (CI_USER): " CI_USER
fi

if [ -z "$CI_PASSWORD" ]; then
    read -s -p "Enter cloud-init password (CI_PASSWORD): " CI_PASSWORD
    echo
fi

# Set cloud-init options
qm set $VMID --ciuser $CI_USER --cipassword $CI_PASSWORD
qm set $VMID --ipconfig0 ip=dhcp

# Attach the imported disk to the VM as scsi0
qm set $VMID -scsi0 ${STORAGE}:${DISK0},discard=on
echo "Attached disk to VM as scsi0"

# Set VM disk and boot options
qm set $VMID -efidisk0 ${STORAGE}:${DISK0},efitype=4m -boot order=scsi0 -serial0 socket
echo "Configured VM disk and boot options."

# Start VM
qm start $VMID
echo "Started VM with ID: $VMID"
