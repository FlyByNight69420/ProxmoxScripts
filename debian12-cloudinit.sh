#!/bin/bash

# Script to create a Proxmox VM with the latest Debian cloud image
# and interactive cloud-init configuration

set -e

# Terminal colors and formatting
readonly RED='\e[31m'
readonly GREEN='\e[32m'
readonly YELLOW='\e[33m'
readonly BLUE='\e[34m'
readonly MAGENTA='\e[35m'
readonly CYAN='\e[36m'
readonly BOLD='\e[1m'
readonly DIM='\e[2m'
readonly UNDERLINE='\e[4m'
readonly RESET='\e[0m'

# Script mode flags
DRY_RUN=false
NON_INTERACTIVE=false

# Function to display error messages
error() {
  echo -e "${RED}${BOLD}[ERROR]${RESET} ${RED}$1${RESET}" >&2
  exit 1
}

# Function to display information messages
info() {
  echo -e "${GREEN}${BOLD}[INFO]${RESET} ${GREEN}$1${RESET}"
}

# Function to display warning messages
warn() {
  echo -e "${YELLOW}${BOLD}[WARN]${RESET} ${YELLOW}$1${RESET}"
}

# Function to display dry run messages
dry_run_info() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}${BOLD}[DRY RUN]${RESET} ${CYAN}$1${RESET}"
  fi
}

# Function to execute or simulate a command
execute_cmd() {
  local cmd="$1"
  local description="$2"
  
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would execute: $cmd"
    sleep 1  # Simulate command execution time
    return 0
  else
    eval "$cmd"
    return $?
  fi
}

# Function to display title
print_title() {
  local title="$1"
  local padding=$(( (60 - ${#title}) / 2 ))
  local line=$(printf '%*s' 60 | tr ' ' '═')
  
  echo -e "\n${CYAN}${BOLD}$line${RESET}"
  printf "${CYAN}${BOLD}%*s%s%*s${RESET}\n" $padding "" "$title" $padding ""
  echo -e "${CYAN}${BOLD}$line${RESET}\n"
}

# Function to display section header
print_section() {
  local section="$1"
  echo -e "\n${BLUE}${BOLD}┌─ $section ─${"─"$(( 58 - ${#section} ))}┐${RESET}"
}

# Function to display section footer
print_section_end() {
  echo -e "${BLUE}${BOLD}└${"─"60}┘${RESET}"
}

# Function to print a progress spinner
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  
  echo -n "  "
  
  if [[ "$DRY_RUN" == true ]]; then
    # Simulate a spinner for dry runs
    for i in {1..10}; do
      for j in {0..3}; do
        echo -ne "\r${YELLOW}[${spinstr:$j:1}]${RESET} "
        sleep $delay
      done
    done
    echo -ne "\r${GREEN}[✓]${RESET} "
    echo
    return 0
  fi
  
  # Real spinner for actual operations
  while ps -p $pid > /dev/null; do
    for i in $(seq 0 3); do
      echo -ne "\r${YELLOW}[${spinstr:$i:1}]${RESET} "
      sleep $delay
    done
  done
  echo -ne "\r${GREEN}[✓]${RESET} "
  echo
}

# Function to simulate a background process for dry runs
fake_background_process() {
  sleep 2
  return 0
}

# Function to display script logo
print_logo() {
  echo -e "${MAGENTA}${BOLD}"
  echo '  ____                                     ____            _       _       '
  echo ' |  _ \ _ __ _____  ___ __ ___   _____  __/ ___|  ___ _ __(_)_ __ | |_ ___ '
  echo ' | |_) | '"'"'_ ` _ \ \/ / '"'"'_ ` _ \ / _ \ \/ /\___ \ / __| '"'"'__| | '"'"'_ \| __/ __|'
  echo ' |  __/| | | | | |>  <| | | | | | (_) >  <  ___) | (__| |  | | |_) | |_\__ \'
  echo ' |_|   |_| |_| |_/_/\_\_| |_| |_|\___/_/\_\|____/ \___|_|  |_| .__/ \__|___/'
  echo '                                                              |_|            '
  echo -e "${RESET}"
  echo -e "${CYAN}${BOLD} Debian 12 Cloud Image VM Creator${RESET}"
  echo -e "${DIM} Version 1.1.0${RESET}\n"
  
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}${BOLD}╔══════════════════════ DRY RUN MODE ═══════════════════════╗${RESET}"
    echo -e "${YELLOW}${BOLD}║ No actual changes will be made to your system.            ║${RESET}"
    echo -e "${YELLOW}${BOLD}║ This mode is for UI testing and workflow validation only. ║${RESET}"
    echo -e "${YELLOW}${BOLD}╚═════════════════════════════════════════════════════════════╝${RESET}\n"
  fi
}

# Function to display usage information
usage() {
  print_logo
  echo -e "${BOLD}Usage:${RESET} $0 [options]"
  echo -e "${DIM}Creates a Proxmox VM with the latest Debian 12 cloud image.${RESET}"
  echo
  echo -e "${BOLD}Options:${RESET}"
  echo -e "  ${BOLD}-h, --help${RESET}              Display this help message"
  echo -e "  ${BOLD}-n, --non-interactive${RESET}   Run in non-interactive mode (requires environment variables)"
  echo -e "  ${BOLD}-d, --dry-run${RESET}           Run in dry-run mode (no actual changes will be made)"
  echo
  echo -e "${DIM}When running in interactive mode, you will be prompted for all required information.${RESET}"
  echo
  exit 0
}

# Function to delete a VM by ID
delete_vm() {
  local vm_id=$1
  
  print_section "VM Deletion"
  info "Preparing to delete VM with ID $vm_id"
  
  echo -ne "  ${BOLD}Checking if VM exists...${RESET} "
  if execute_cmd "qm status $vm_id &>/dev/null" "check if VM exists"; then
    echo -e "${GREEN}Found${RESET}"
    
    info "Stopping VM if running"
    execute_cmd "qm stop $vm_id &" "stop VM"
    if [[ "$DRY_RUN" == true ]]; then
      fake_background_process &
      spinner $!
    else
      spinner $!
    fi
    
    info "Destroying VM and purging all data"
    execute_cmd "qm destroy $vm_id --purge &" "destroy VM"
    if [[ "$DRY_RUN" == true ]]; then
      fake_background_process &
      spinner $!
    else
      spinner $!
    fi
    
    echo -e "  ${GREEN}VM $vm_id successfully deleted!${RESET}"
  else
    echo -e "${RED}Not Found${RESET}"
    warn "VM with ID $vm_id does not exist or cannot be accessed"
  fi
  print_section_end
}

# Function to display a summary of settings
print_summary() {
  print_section "Configuration Summary"
  echo -e "  ${BOLD}VM ID:${RESET}              ${CYAN}$VM_ID${RESET}"
  echo -e "  ${BOLD}VM Name:${RESET}            ${CYAN}$VM_NAME${RESET}"
  echo -e "  ${BOLD}CPU Cores:${RESET}          ${CYAN}$VM_CORES${RESET}"
  echo -e "  ${BOLD}RAM:${RESET}                ${CYAN}$VM_RAM MB${RESET}"
  echo -e "  ${BOLD}Disk Size:${RESET}          ${CYAN}$VM_DISK_SIZE GB${RESET}"
  echo -e "  ${BOLD}Storage:${RESET}            ${CYAN}$VM_STORAGE${RESET}"
  echo -e "  ${BOLD}Network Bridge:${RESET}     ${CYAN}$VM_BRIDGE${RESET}"
  echo
  echo -e "  ${BOLD}Cloud-init User:${RESET}    ${CYAN}$CI_USER${RESET}"
  echo -e "  ${BOLD}SSH Key:${RESET}            ${CYAN}$([ -n "$CI_SSH_KEY" ] && echo "Provided" || echo "None")${RESET}"
  
  if [[ "$CI_IP" == "dhcp" ]]; then
    echo -e "  ${BOLD}Network:${RESET}            ${CYAN}DHCP${RESET}"
  else
    echo -e "  ${BOLD}IP Address:${RESET}         ${CYAN}$CI_IP${RESET}"
    echo -e "  ${BOLD}Gateway:${RESET}            ${CYAN}$CI_GATEWAY${RESET}"
    echo -e "  ${BOLD}DNS Servers:${RESET}        ${CYAN}$CI_DNS${RESET}"
  fi
  print_section_end
}

# Function to read input with default value
read_with_default() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  local hide_input="$4"
  
  if [[ -n "$default" ]]; then
    prompt="${prompt} (default: ${CYAN}${default}${RESET})"
  fi
  
  prompt="${prompt}: "
  
  if [[ "$hide_input" == "true" ]]; then
    read -p "$(echo -e "$prompt")" -s $var_name
    echo
  else
    read -p "$(echo -e "$prompt")" $var_name
  fi
  
  # Set default if empty
  if [[ -z "${!var_name}" && -n "$default" ]]; then
    eval "$var_name='$default'"
  fi
}

# Function to validate numeric input
validate_number() {
  local value="$1"
  local name="$2"
  local min="$3"
  
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    error "$name must be a number"
  fi
  
  if [[ -n "$min" && "$value" -lt "$min" ]]; then
    error "$name must be at least $min"
  fi
}

# Function to validate IP in CIDR format
validate_ip_cidr() {
  local ip_cidr="$1"
  
  if [[ "$ip_cidr" == "dhcp" ]]; then
    return 0
  fi
  
  # Simple CIDR validation (could be improved)
  if ! [[ "$ip_cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    error "Invalid IP/CIDR format. Example: 192.168.1.100/24"
  fi
}

# Function to cleanup temporary files
cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
  fi
}

# Set trap for cleanup
trap cleanup EXIT

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
    -h|--help)
      usage
      ;;
    -n|--non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      # Unknown option
      ;;
  esac
done

# Clear screen and show logo
clear
print_logo

# Check for required dependencies
print_section "System Check"
echo -e "  ${BOLD}Checking dependencies...${RESET}"

missing_deps=()
for cmd in qm wget curl; do
  echo -ne "    ${cmd}... "
  if command -v $cmd &> /dev/null || [[ "$DRY_RUN" == true ]]; then
    echo -e "${GREEN}OK${RESET}"
  else
    echo -e "${RED}Missing${RESET}"
    missing_deps+=($cmd)
  fi
done

if [[ ${#missing_deps[@]} -gt 0 && "$DRY_RUN" == false ]]; then
  print_section_end
  error "Required commands not found: ${missing_deps[*]}"
fi

# Check if script is run as root
echo -ne "  ${BOLD}Checking permissions...${RESET} "
if [[ $EUID -eq 0 || "$DRY_RUN" == true ]]; then
  echo -e "${GREEN}OK${RESET}"
else
  echo -e "${RED}Failed${RESET}"
  print_section_end
  error "This script must be run as root"
fi
print_section_end

# VM configuration parameters
print_section "VM Configuration"

read_with_default "${BOLD}Enter VM ID${RESET}" "" "VM_ID"
[[ -z "$VM_ID" ]] && error "VM ID cannot be empty"
validate_number "$VM_ID" "VM ID" 100

# Check if VM ID already exists
echo -ne "  ${BOLD}Checking VM ID availability...${RESET} "
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${GREEN}Available${RESET}"
else
  if qm status $VM_ID &>/dev/null; then
    echo -e "${RED}Failed${RESET}"
    print_section_end
    error "VM with ID $VM_ID already exists"
  else
    echo -e "${GREEN}Available${RESET}"
  fi
fi

read_with_default "${BOLD}Enter VM Name${RESET}" "" "VM_NAME"
[[ -z "$VM_NAME" ]] && error "VM Name cannot be empty"

read_with_default "${BOLD}Enter number of cores${RESET}" "2" "VM_CORES"
validate_number "$VM_CORES" "Number of cores" 1

read_with_default "${BOLD}Enter RAM in MB${RESET}" "2048" "VM_RAM"
validate_number "$VM_RAM" "RAM" 512

read_with_default "${BOLD}Enter disk size in GB${RESET}" "20" "VM_DISK_SIZE"
validate_number "$VM_DISK_SIZE" "Disk size" 5

read_with_default "${BOLD}Storage location${RESET}" "local-lvm" "VM_STORAGE"

read_with_default "${BOLD}Network bridge${RESET}" "vmbr0" "VM_BRIDGE"
print_section_end

# Cloud-init configuration
print_section "Cloud-Init Configuration"

read_with_default "${BOLD}Username${RESET}" "debian" "CI_USER"

read_with_default "${BOLD}Password${RESET}" "" "CI_PASSWORD" "true"
[[ -z "$CI_PASSWORD" ]] && error "Password cannot be empty"

# Check password strength (simple check)
if [[ ${#CI_PASSWORD} -lt 8 ]]; then
  warn "Password is less than 8 characters. Consider using a stronger password."
fi

read_with_default "${BOLD}SSH public key${RESET} (or press enter to skip)" "" "CI_SSH_KEY"

read_with_default "${BOLD}IP address with CIDR${RESET} (e.g., 192.168.1.100/24 or dhcp)" "dhcp" "CI_IP"
validate_ip_cidr "$CI_IP"

if [[ "$CI_IP" != "dhcp" ]]; then
  read_with_default "${BOLD}Gateway IP${RESET}" "" "CI_GATEWAY"
  [[ -z "$CI_GATEWAY" ]] && error "Gateway IP cannot be empty when using static IP"

  read_with_default "${BOLD}DNS servers${RESET} (comma-separated)" "1.1.1.1,8.8.8.8" "CI_DNS"
fi
print_section_end

# Show a summary and ask for confirmation
print_summary

echo -ne "${YELLOW}${BOLD}Do you want to proceed with this configuration? (y/n):${RESET} "
read CONFIRM
if [[ ! "${CONFIRM,,}" =~ ^(y|yes)$ ]]; then
  echo -e "\n${YELLOW}Installation aborted by user.${RESET}"
  exit 0
fi

# Temporary file locations
TEMP_DIR=$(mktemp -d -p /tmp vm-${VM_ID}-XXXXXX)
[[ ! -d "$TEMP_DIR" ]] && error "Failed to create temporary directory"

# Create VM
print_title "Creating Debian 12 Cloud VM"

print_section "Image Preparation"
info "Finding latest Debian cloud image..."

# Check for cached image
CACHE_DIR="/var/cache/proxmox-scripts"
CACHE_IMAGE="$CACHE_DIR/debian-12-genericcloud-amd64.qcow2"
CACHE_EXPIRY=604800  # 7 days in seconds

# Create cache directory if it doesn't exist
if [[ ! -d "$CACHE_DIR" && "$DRY_RUN" == false ]]; then
  info "Creating cache directory..."
  mkdir -p "$CACHE_DIR" || warn "Cannot create cache directory, proceeding without caching"
elif [[ "$DRY_RUN" == true ]]; then
  info "Creating cache directory... (simulated)"
fi

# Check if cached image exists and is recent
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Checking for cached image (simulated)"
  DOWNLOAD_NEW=true
elif [[ -f "$CACHE_IMAGE" && -d "$CACHE_DIR" ]]; then
  CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_IMAGE")))
  if [[ $CACHE_AGE -lt $CACHE_EXPIRY ]]; then
    info "Using cached Debian cloud image (age: $(($CACHE_AGE / 86400)) days)"
    CLOUD_IMAGE_PATH="$CACHE_IMAGE"
  else
    info "Cached image is too old, downloading fresh copy"
    DOWNLOAD_NEW=true
  fi
else
  DOWNLOAD_NEW=true
fi

# Download fresh image if needed
if [[ "$DOWNLOAD_NEW" == true ]]; then
  # Get the specific amd64 genericcloud image
  echo -ne "  ${BOLD}Finding latest image URL...${RESET} "
  
  if [[ "$DRY_RUN" == true ]]; then
    sleep 1
    echo -e "${GREEN}Found${RESET}"
    LATEST_URL="debian-12-genericcloud-amd64.qcow2"
    CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/$LATEST_URL"
  else
    LATEST_URL=$(curl -s https://cloud.debian.org/images/cloud/bookworm/latest/ | grep -o 'href="debian-12-genericcloud-amd64.qcow2"' | head -1 | cut -d'"' -f2)
    if [[ -z "$LATEST_URL" ]]; then
      echo -e "${RED}Failed${RESET}"
      error "Could not find Debian cloud image"
    else
      echo -e "${GREEN}Found${RESET}"
    fi
    CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/$LATEST_URL"
  fi
  
  CLOUD_IMAGE_PATH="$TEMP_DIR/debian-cloud.qcow2"

  info "Downloading latest Debian cloud image:"
  echo -e "  ${DIM}$CLOUD_IMAGE_URL${RESET}"
  
  # Run wget in the background and show a spinner
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would download: $CLOUD_IMAGE_URL"
    fake_background_process &
    spinner $!
  else
    wget -q --show-progress -O $CLOUD_IMAGE_PATH $CLOUD_IMAGE_URL &
    wget_pid=$!
    spinner $wget_pid
    
    # Check if download was successful
    if [[ $? -ne 0 ]]; then
      error "Failed to download cloud image"
    fi
  fi
  
  # Cache the image if cache directory exists
  if [[ -d "$CACHE_DIR" && "$DRY_RUN" == false ]]; then
    info "Caching image for future use..."
    cp "$CLOUD_IMAGE_PATH" "$CACHE_IMAGE" || warn "Could not cache the image, continuing anyway"
  elif [[ "$DRY_RUN" == true ]]; then
    info "Caching image for future use... (simulated)"
  fi
fi
print_section_end

# VM Creation
print_section "VM Creation"

# Create VM
info "Creating VM $VM_ID with name $VM_NAME"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm create $VM_ID --name $VM_NAME --memory $VM_RAM --cores $VM_CORES --net0 virtio,bridge=$VM_BRIDGE"
  fake_background_process &
  spinner $!
else
  qm create $VM_ID --name $VM_NAME --memory $VM_RAM --cores $VM_CORES --net0 virtio,bridge=$VM_BRIDGE &
  qm_pid=$!
  spinner $qm_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to create VM"
  fi
fi

# Import disk
info "Importing cloud disk image"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm importdisk $VM_ID $CLOUD_IMAGE_PATH $VM_STORAGE"
  fake_background_process &
  spinner $!
else
  qm importdisk $VM_ID $CLOUD_IMAGE_PATH $VM_STORAGE &
  import_pid=$!
  spinner $import_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to import disk"
  fi
fi

# Attach imported disk to VM
info "Attaching disk to VM"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $VM_STORAGE:vm-$VM_ID-disk-0"
  fake_background_process &
  spinner $!
else
  qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $VM_STORAGE:vm-$VM_ID-disk-0 &
  attach_pid=$!
  spinner $attach_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to attach disk"
  fi
fi

# Resize disk
info "Resizing disk to $VM_DISK_SIZE GB"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm resize $VM_ID scsi0 ${VM_DISK_SIZE}G"
  fake_background_process &
  spinner $!
else
  qm resize $VM_ID scsi0 ${VM_DISK_SIZE}G &
  resize_pid=$!
  spinner $resize_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to resize disk"
  fi
fi

# Set boot order and display 
info "Configuring VM boot and display settings"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm set $VM_ID --boot c --bootdisk scsi0"
  fake_background_process &
  spinner $!
  
  dry_run_info "Would run: qm set $VM_ID --serial0 socket --vga serial0"
  fake_background_process &
  spinner $!
else
  qm set $VM_ID --boot c --bootdisk scsi0 &
  boot_pid=$!
  spinner $boot_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to set boot order"
  fi

  qm set $VM_ID --serial0 socket --vga serial0 &
  display_pid=$!
  spinner $display_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to set display settings"
  fi
fi
print_section_end

# Configure cloud-init
print_section "Cloud-Init Setup"

info "Setting up cloud-init drive"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm set $VM_ID --ide2 $VM_STORAGE:cloudinit"
  fake_background_process &
  spinner $!
else
  qm set $VM_ID --ide2 $VM_STORAGE:cloudinit &
  ci_pid=$!
  spinner $ci_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to configure cloud-init"
  fi
fi

# Set cloud-init parameters
info "Configuring cloud-init user credentials"
if [[ "$DRY_RUN" == true ]]; then
  dry_run_info "Would run: qm set $VM_ID --ciuser $CI_USER"
  fake_background_process &
  spinner $!
  
  dry_run_info "Would run: qm set $VM_ID --cipassword [PROTECTED]"
  fake_background_process &
  spinner $!
else
  qm set $VM_ID --ciuser $CI_USER &
  user_pid=$!
  spinner $user_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to set cloud-init user"
  fi

  qm set $VM_ID --cipassword $CI_PASSWORD &
  pass_pid=$!
  spinner $pass_pid

  if [[ $? -ne 0 ]]; then
    error "Failed to set cloud-init password"
  fi
fi

if [[ -n "$CI_SSH_KEY" ]]; then
  info "Adding SSH key to cloud-init"
  echo "$CI_SSH_KEY" > $TEMP_DIR/ssh_key.pub
  
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would run: qm set $VM_ID --sshkeys $TEMP_DIR/ssh_key.pub"
    fake_background_process &
    spinner $!
  else
    qm set $VM_ID --sshkeys $TEMP_DIR/ssh_key.pub &
    ssh_pid=$!
    spinner $ssh_pid
    
    if [[ $? -ne 0 ]]; then
      error "Failed to set SSH key"
    fi
  fi
fi

# Set network configuration
info "Configuring network settings"
if [[ "$CI_IP" == "dhcp" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would run: qm set $VM_ID --ipconfig0 ip=dhcp"
    fake_background_process &
    spinner $!
  else
    qm set $VM_ID --ipconfig0 ip=dhcp &
    net_pid=$!
    spinner $net_pid
    
    if [[ $? -ne 0 ]]; then
      error "Failed to set DHCP configuration"
    fi
  fi
else
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would run: qm set $VM_ID --ipconfig0 ip=$CI_IP,gw=$CI_GATEWAY"
    fake_background_process &
    spinner $!
  else
    qm set $VM_ID --ipconfig0 ip=$CI_IP,gw=$CI_GATEWAY &
    net_pid=$!
    spinner $net_pid
    
    if [[ $? -ne 0 ]]; then
      error "Failed to set IP configuration"
    fi
  fi

  # Set DNS servers
  info "Configuring DNS servers"
  IFS=',' read -ra DNS_SERVERS <<< "$CI_DNS"
  DNS_CONFIG=""
  for server in "${DNS_SERVERS[@]}"; do
    DNS_CONFIG+="nameserver $server"$'\n'
  done

  echo "$DNS_CONFIG" > $TEMP_DIR/resolv.conf
  
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would run: qm set $VM_ID --cicustom dns=raw:$TEMP_DIR/resolv.conf"
    fake_background_process &
    spinner $!
  else
    qm set $VM_ID --cicustom "dns=raw:$TEMP_DIR/resolv.conf" &
    dns_pid=$!
    spinner $dns_pid
    
    if [[ $? -ne 0 ]]; then
      error "Failed to set DNS configuration"
    fi
  fi
fi
print_section_end

# Start VM
print_section "VM Startup"
read_with_default "${BOLD}Start VM now?${RESET}" "y" "START_VM"

if [[ "${START_VM,,}" =~ ^(y|yes)$ ]]; then
  info "Starting VM $VM_ID"
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_info "Would run: qm start $VM_ID"
    fake_background_process &
    spinner $!
    echo -e "  ${GREEN}VM successfully started! (simulated)${RESET}"
  else
    qm start $VM_ID &
    start_pid=$!
    spinner $start_pid
    
    if [[ $? -ne 0 ]]; then
      error "Failed to start VM"
    else
      echo -e "  ${GREEN}VM successfully started!${RESET}"
    fi
  fi
else
  info "VM created but not started"
fi
print_section_end

# VM Delete Option
if [[ "$DRY_RUN" == false ]]; then
  echo -ne "${YELLOW}${BOLD}Do you want to delete this VM? (y/n):${RESET} "
  read DELETE_VM
  if [[ "${DELETE_VM,,}" =~ ^(y|yes)$ ]]; then
    delete_vm $VM_ID
  fi
fi

# Final success message
print_title "VM Setup Complete"

echo -e "  ${BOLD}VM ID:${RESET}              ${CYAN}$VM_ID${RESET}"
echo -e "  ${BOLD}VM Name:${RESET}            ${CYAN}$VM_NAME${RESET}"
echo -e "  ${BOLD}Cloud-init username:${RESET} ${CYAN}$CI_USER${RESET}"

if [[ "$CI_IP" == "dhcp" ]]; then
  echo -e "  ${BOLD}Network:${RESET}            ${CYAN}DHCP${RESET}"
else
  echo -e "  ${BOLD}IP Address:${RESET}         ${CYAN}$CI_IP${RESET}"
  echo -e "  ${BOLD}Gateway:${RESET}            ${CYAN}$CI_GATEWAY${RESET}"
  echo -e "  ${BOLD}DNS:${RESET}                ${CYAN}$CI_DNS${RESET}"
fi

if [[ "$DRY_RUN" == true ]]; then
  echo -e "\n${YELLOW}${BOLD}This was a dry run. No actual VM was created.${RESET}"
  echo -e "${YELLOW}Run without the --dry-run option to create a real VM.${RESET}\n"
else
  echo -e "\n${GREEN}${BOLD}You can access your new VM from the Proxmox web interface or via SSH.${RESET}\n"
fi
