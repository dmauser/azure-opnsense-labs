!#!/bin/bash

# Parameters
rg="lab-wg-client"
vmsize="Standard_B1s" # Specify the VM size you want to use

# Prompt for location
read -p "Enter the location (default: westus3): " location
location=${location:-westus3} # Default to westus3 if not provided

# Prompt for username and password
read -p "Enter your username (default: azureuser): " username
username=${username:-azureuser} # Default to azureuser if not provided

# Number of virtual machines to create
read -p "Enter the number of virtual machines to create (default: 1): " vm_count
vm_count=${vm_count:-1} # Default to 1 if not provided

# Prompt for password
while true; do
    read -s -p "Enter your password: " password
    echo
    read -s -p "Confirm your password: " password_confirm
    echo
    if [ "$password" = "$password_confirm" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Check if resource group exists
if az group show --name $rg --query "name" --output tsv 2>/dev/null; then
  echo "Resource group $rg already exists. Skipping creation..."
else
  echo "Creating resource group $rg in location $location..."
  az group create --name $rg --location $location -o none
fi

# Create Virutual Network and Subnet
echo "Creating Virtual Network and Subnet..."
az network vnet create --name "wg-client-vnet" --resource-group $rg --location $location \
  --address-prefix "192.168.10.0/24" --subnet-name "main" --subnet-prefix "192.168.10.0/28" -o none

# Create default Network Security Group
echo "Creating default Network Security Group..."
az network nsg create --resource-group $rg --name "$location-default-nsg" -o none
# Assign NSG to the subnet
echo "Assigning Network Security Group to the subnet..."
az network vnet subnet update -g $rg -n "main" --vnet-name "wg-client-vnet" \
  --network-security-group "$location-default-nsg" -o none

# Create Ubuntu VMs on main subnet and no public IP, incrementing VM name if existing
for ((i=1; i<=vm_count; i++)); do
  vm_name="wgclient-vm$i"
  # Check if VM already exists
  if az vm show -g $rg -n "$vm_name" --query "name" --output tsv 2>/dev/null; then
    echo "VM $vm_name already exists. Skipping..."
    continue
  fi

  echo "Creating Ubuntu VM $vm_name on main subnet..."
  az vm create -n "$vm_name" -g $rg --image "Ubuntu2204" \
    --size $vmsize -l $location --subnet "main" --vnet-name "wg-client-vnet" \
    --admin-username "$username" --admin-password "$password" --nsg "" --no-wait --only-show-errors \
    --public-ip-address "" \
    --output none

  # Wait for the VM to be created
  az vm wait --name "$vm_name" --resource-group $rg --created -o none
  echo "VM $vm_name created successfully."

  # Enable boot diagnostics
  echo "Enabling boot diagnostics for the VM $vm_name..."
  az vm boot-diagnostics enable --name "$vm_name" --resource-group $rg -o none
done

