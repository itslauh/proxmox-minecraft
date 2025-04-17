#!/bin/bash

# Prompt for VM details
echo "Enter the VM name (e.g., ubuntu-vm):"
read VM_NAME

echo "Enter the root username (e.g., ubuntu-admin):"
read ROOT_USER

echo "Enter the root password:"
read -s ROOT_PASS

echo "Enter the disk size for the VM (in GB):"
read DISK_SIZE

# Set VM ID (incremental approach based on highest ID)
VMID=$(pvesh get /nodes/$(hostname)/qemu | jq '.[].vmid' | sort -n | tail -n 1)
VMID=$((VMID + 1))

# Define VM configuration variables
ISO_PATH="/var/lib/vz/template/iso/ubuntu-20.04.3-live-server-amd64.iso"  # Replace with your actual ISO path
STORAGE_NAME="local-lvm"  # Adjust for your storage setup

# Create the VM
echo "Creating VM with ID: $VMID"
qm create $VMID --name $VM_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --ide2 $STORAGE_NAME:cloudinit

# Set the disk size for the VM
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE_NAME:32,format=qcow2
qm set $VMID --ide0 $ISO_PATH,media=cdrom

# Set up the root user and password via cloud-init
echo "Setting up Cloud-Init for user $ROOT_USER"
qm set $VMID --ciuser $ROOT_USER --cipassword $ROOT_PASS --ipconfig0 ip=dhcp

# Setup additional disk size if needed (this sets a disk size for the VM)
qm set $VMID --scsi1 $STORAGE_NAME:$DISK_SIZE,format=qcow2

# Start the VM
echo "Starting the VM..."
qm start $VMID

# Final information
echo "VM setup is complete!"
echo "VM ID: $VMID"
echo "Root user: $ROOT_USER"
echo "Disk size: ${DISK_SIZE}GB"
echo "Ubuntu ISO: $ISO_PATH"
echo "You can access your VM using SSH once it's up and running."
