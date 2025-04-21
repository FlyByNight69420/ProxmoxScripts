#!/bin/bash

# Script to create a Proxmox VM with the latest Debian cloud image
# and interactive cloud-init configuration

set -e

# Function to display error messages
error() {
  echo -e "\e[91m[ERROR] $1\e[0m" >&2
  exit 1
}

# Function to display information messages
info() {
  echo -e "\e[92m[INFO] $1\e[0m"
}

# Check if script is run as root
[[ $EUID -ne 0 ]] && error "This script must be run as root"

# VM configuration parameters
read -p "Enter VM ID: " VM_ID
[[ -z "$VM_ID" ]] && error "VM ID cannot be empty"

# Check if VM ID already exists
qm status $VM_ID &>/dev/null && error "VM with ID $VM_ID already exists"

read -p "Enter VM Name: " VM_NAME
[[ -z "$VM_NAME" ]] && error "VM Name cannot be empty"

read -p "Enter number of cores (default: 2): " VM_CORES
VM_CORES=${VM_CORES:-2}

read -p "Enter RAM in MB (default: 2048): " VM_RAM
VM_RAM=${VM_RAM:-2048}

read -p "Enter disk size in GB (default: 20): " VM_DISK_SIZE
VM_DISK_SIZE=${VM_DISK_SIZE:-20}

read -p "Storage location (default: local-lvm): " VM_STORAGE
VM_STORAGE=${VM_STORAGE:-local-lvm}

# Cloud-init configuration
echo -e "\n--- Cloud-Init Configuration ---"
read -p "Username (default: debian): " CI_USER
CI_USER=${CI_USER:-debian}

read -p "Password: " -s CI_PASSWORD
echo
[[ -z "$CI_PASSWORD" ]] && error "Password cannot be empty"

read -p "SSH public key (or press enter to skip): " CI_SSH_KEY

read -p "IP address with CIDR (e.g., 192.168.1.100/24) or 'dhcp': " CI_IP
[[ -z "$CI_IP" ]] && CI_IP="dhcp"

if [[ "$CI_IP" != "dhcp" ]]; then
  read -p "Gateway IP: " CI_GATEWAY
  [[ -z "$CI_GATEWAY" ]] && error "Gateway IP cannot be empty when using static IP"

  read -p "DNS servers (comma-separated, default: 1.1.1.1,8.8.8.8): " CI_DNS
  CI_DNS=${CI_DNS:-"1.1.1.1,8.8.8.8"}
fi

# Temporary file locations
TEMP_DIR="/tmp/vm-$VM_ID"
mkdir -p $TEMP_DIR

# Get latest Debian cloud image
info "Finding latest Debian cloud image..."
LATEST_URL=$(curl -s https://cloud.debian.org/images/cloud/bookworm/latest/ | grep -o 'href=".*\.qcow2"' | grep generic | cut -d'"' -f2)
CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/$LATEST_URL"
CLOUD_IMAGE_PATH="$TEMP_DIR/debian-cloud.qcow2"

info "Downloading latest Debian cloud image: $CLOUD_IMAGE_URL"
wget -q --show-progress -O $CLOUD_IMAGE_PATH $CLOUD_IMAGE_URL || error "Failed to download cloud image"

# Create VM
info "Creating VM $VM_ID with name $VM_NAME"
qm create $VM_ID --name $VM_NAME --memory $VM_RAM --cores $VM_CORES --net0 virtio,bridge=vmbr0

# Import disk
info "Importing cloud disk image"
qm importdisk $VM_ID $CLOUD_IMAGE_PATH $VM_STORAGE

# Attach imported disk to VM
info "Attaching disk to VM"
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $VM_STORAGE:vm-$VM_ID-disk-0

# Resize disk
info "Resizing disk to $VM_DISK_SIZE GB"
qm resize $VM_ID scsi0 ${VM_DISK_SIZE}G

# Set boot order and display 
qm set $VM_ID --boot c --bootdisk scsi0
qm set $VM_ID --serial0 socket --vga serial0

# Configure cloud-init
info "Configuring cloud-init"
qm set $VM_ID --ide2 $VM_STORAGE:cloudinit

# Set cloud-init parameters
qm set $VM_ID --ciuser $CI_USER
qm set $VM_ID --cipassword $CI_PASSWORD

if [[ -n "$CI_SSH_KEY" ]]; then
  echo "$CI_SSH_KEY" > $TEMP_DIR/ssh_key.pub
  qm set $VM_ID --sshkeys $TEMP_DIR/ssh_key.pub
fi

if [[ "$CI_IP" == "dhcp" ]]; then
  qm set $VM_ID --ipconfig0 ip=dhcp
else
  qm set $VM_ID --ipconfig0 ip=$CI_IP,gw=$CI_GATEWAY

  # Set DNS servers
  IFS=',' read -ra DNS_SERVERS <<< "$CI_DNS"
  DNS_CONFIG=""
  for server in "${DNS_SERVERS[@]}"; do
    DNS_CONFIG+="nameserver $server"$'\n'
  done

  echo "$DNS_CONFIG" > $TEMP_DIR/resolv.conf
  qm set $VM_ID --cicustom "dns=raw:$TEMP_DIR/resolv.conf"
fi

# Start VM
read -p "Start VM now? (y/n, default: y): " START_VM
START_VM=${START_VM:-y}
if [[ "${START_VM,,}" == "y" ]]; then
  info "Starting VM $VM_ID"
  qm start $VM_ID
else
  info "VM created but not started"
fi

# Cleanup
info "Cleaning up temporary files"
rm -rf $TEMP_DIR

info "VM setup complete!"
echo "VM ID: $VM_ID"
echo "VM Name: $VM_NAME"
echo "Cloud-init username: $CI_USER"
if [[ "$CI_IP" == "dhcp" ]]; then
  echo "Network: DHCP"
else
  echo "IP Address: $CI_IP"
  echo "Gateway: $CI_GATEWAY"
  echo "DNS: $CI_DNS"
fi
