#!/usr/bin/env bash
set -euo pipefail

# Parameters
rg="lab-vng-opn"
branchname="branch1"
max_wait_minutes=60   # Maximum minutes to wait for resource group

# OPNsense NVA deployment parameters
scenarioOption="TwoNics"
virtualMachineSize="Standard_B2s"  # Burstable 2 vCPU / 4 GB — handles IPsec + BGP
branchVmSize="Standard_B1ms"       # Burstable 1 vCPU / 2 GB — sufficient for test VM
virtualMachineName="$branchname-opnnva"
virtualNetworkName="$branchname-vnet"
VNETAddress="192.168.100.0/24"
UntrustedSubnetCIDR="192.168.100.64/28"
TrustedSubnetCIDR="192.168.100.80/28"
existingUntrustedSubnetName="untrusted"
existingTrustedSubnetName="trusted"
nva_nsg="$branchname-nva-nsg"

# Verify Azure CLI is available
if ! command -v az &>/dev/null; then
    echo "Error: Azure CLI (az) is not installed or not in PATH." >&2
    exit 1
fi

# Capture local public IP for NSG rules
mypip=$(curl -4 -s --max-time 10 ifconfig.io) || true
if [[ -z "$mypip" ]]; then
    echo "Warning: Could not determine local public IP. HTTPS NSG rule will allow any source." >&2
    mypip="*"
fi

# Prompt for credentials if not already set (allows sourcing from 1hub-deploy.sh)
if [ -z "${username:-}" ]; then
    read -p "Enter your username (default: azureuser): " username
    username=${username:-azureuser}
fi

if [ -z "${password:-}" ]; then
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
fi

# Record script start time
start_time=$(date +%s)
echo "Script started at $(date)"

# Wait for the resource group to exist (with timeout)
echo "Waiting for resource group '$rg' to exist..."
deadline=$(( $(date +%s) + max_wait_minutes * 60 ))
while true; do
    if [ "$(az group exists --name "$rg")" = "true" ]; then
        echo "Resource group '$rg' found."
        break
    fi
    if (( $(date +%s) > deadline )); then
        echo "Error: Resource group '$rg' did not appear within $max_wait_minutes minutes." >&2
        exit 1
    fi
    echo "  Resource group '$rg' not found yet. Retrying in 15 seconds..."
    sleep 15
done

# Derive location from the existing resource group
location=$(az group show -n "$rg" --query location -o tsv)

# Print deployment summary
echo ""
echo "=== Deployment Summary ==="
echo "  Resource group : $rg"
echo "  Location       : $location"
echo "  Branch name    : $branchname"
echo "  NVA VM size    : $virtualMachineSize"
echo "  Branch VM size : $branchVmSize"
echo "  Admin user     : $username"
echo "  My public IP   : $mypip"
echo "=========================="
echo ""

# Create VNet and vm-subnet
echo "Creating VNet and subnets..."
az network vnet create --name "$branchname-vnet" --resource-group "$rg" --location "$location" \
    --address-prefix "192.168.100.0/24" --subnet-name "vm-subnet" --subnet-prefix "192.168.100.0/28" -o none

# Assign default NSG to vm-subnet
az network vnet subnet update -g "$rg" -n "vm-subnet" --vnet-name "$branchname-vnet" \
    --network-security-group "$location-default-nsg" -o none

# Create Ubuntu VM on vm-subnet
az vm create -n "$branchname-vm1" -g "$rg" --image "Ubuntu2204" \
    --size "$branchVmSize" -l "$location" --subnet "vm-subnet" --vnet-name "$branchname-vnet" \
    --admin-username "$username" --admin-password "$password" --nsg "" --no-wait --only-show-errors \
    --public-ip-address ""

# Create untrusted and trusted subnets
az network vnet subnet create -g "$rg" --vnet-name "$virtualNetworkName" --name "$existingUntrustedSubnetName" \
    --address-prefixes "$UntrustedSubnetCIDR" -o none
az network vnet subnet create -g "$rg" --vnet-name "$virtualNetworkName" --name "$existingTrustedSubnetName" \
    --address-prefixes "$TrustedSubnetCIDR" -o none

# Deploy OPNsense VM
echo "Deploying OPNsense NVA on $branchname..."
az vm image terms accept --urn thefreebsdfoundation:freebsd-14_1:14_1-release-amd64-gen2-zfs:14.1.0 -o none
az deployment group create --name "$branchname-nva-$RANDOM" --resource-group "$rg" \
    --template-uri "https://raw.githubusercontent.com/dmauser/opnazure/master/ARM/main.json" \
    --parameters scenarioOption="$scenarioOption" virtualMachineName="$virtualMachineName" \
    virtualMachineSize="$virtualMachineSize" existingvirtualNetwork="existing" \
    VNETAddress="[\"$VNETAddress\"]" virtualNetworkName="$virtualNetworkName" \
    UntrustedSubnetCIDR="$UntrustedSubnetCIDR" TrustedSubnetCIDR="$TrustedSubnetCIDR" \
    existingUntrustedSubnetName="$existingUntrustedSubnetName" existingTrustedSubnetName="$existingTrustedSubnetName" \
    Location="$location" --no-wait -o none

# Wait for Trusted NIC to be created
echo "Waiting for OPNsense trusted NIC to be created..."
az network nic wait --name "$branchname-opnnva-Trusted-NIC" --resource-group "$rg" --created

# Create NSG for NVA subnets
echo "Creating NSG and rules..."
az network nsg create --resource-group "$rg" --name "$nva_nsg" --location "$location" -o none

az network nsg rule create -g "$rg" --nsg-name "$nva_nsg" -n "allow-https" \
    --direction Inbound --priority 300 \
    --source-address-prefixes "$mypip" --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 443 \
    --access Allow --protocol Tcp \
    --description "Allow inbound HTTPS" -o none

az network nsg rule create -g "$rg" --nsg-name "$nva_nsg" -n "allow-rfc1918-in" \
    --direction Inbound --priority 310 \
    --source-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
    --source-port-ranges '*' \
    --destination-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
    --destination-port-ranges '*' \
    --access Allow --protocol '*' \
    --description "allow-rfc1918-in" -o none

az network nsg rule create -g "$rg" --nsg-name "$nva_nsg" -n "allow-rfc1918-out" \
    --direction Outbound --priority 320 \
    --source-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
    --source-port-ranges '*' \
    --destination-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
    --destination-port-ranges '*' \
    --access Allow --protocol '*' \
    --description "allow-rfc1918-out" -o none

# IKE/IPsec rules for VPN
az network nsg rule create -g "$rg" --nsg-name "$nva_nsg" -n "allow-udp500" \
    --direction Inbound --priority 330 \
    --destination-port-ranges 500 --access Allow --protocol Udp -o none

az network nsg rule create -g "$rg" --nsg-name "$nva_nsg" -n "allow-udp4500" \
    --direction Inbound --priority 340 \
    --destination-port-ranges 4500 --access Allow --protocol Udp -o none

# Associate NSG to trusted subnet
az network vnet subnet update -g "$rg" --name trusted --vnet-name "$branchname-vnet" \
    --network-security-group "$nva_nsg" -o none

# Create UDR pointing default traffic to NVA trusted NIC
echo "Creating UDR for vm-subnet..."
fs1nvaip=$(az network nic show --name "$branchname-opnnva-Trusted-NIC" --resource-group "$rg" \
    --query "ipConfigurations[0].privateIPAddress" -o tsv)

if [[ -z "$fs1nvaip" ]]; then
    echo "Error: Could not retrieve trusted NIC IP address for UDR next-hop." >&2
    exit 1
fi

az network route-table create -g "$rg" --name "$branchname-UDR" -l "$location" -o none
az network route-table route create -g "$rg" --route-table-name "$branchname-UDR" \
    --name "default-via-nva" --address-prefix "0.0.0.0/0" \
    --next-hop-type VirtualAppliance --next-hop-ip-address "$fs1nvaip" -o none
az network vnet subnet update -g "$rg" -n "vm-subnet" --vnet-name "$branchname-vnet" \
    --route-table "$branchname-UDR" -o none

# Move NSG from OPNsense NICs to subnet level
echo "Reassigning NSGs from NICs to subnets..."
az network nic update -g "$rg" -n "$virtualMachineName-Trusted-NIC" --network-security-group null -o none
az network nic update -g "$rg" -n "$virtualMachineName-Untrusted-NIC" --network-security-group null -o none
az network vnet subnet update --name "$existingTrustedSubnetName" --resource-group "$rg" \
    --vnet-name "$virtualNetworkName" --network-security-group "$nva_nsg" -o none
az network vnet subnet update --name "$existingUntrustedSubnetName" --resource-group "$rg" \
    --vnet-name "$virtualNetworkName" --network-security-group "$nva_nsg" -o none

# Install networking tools on Ubuntu VMs
echo "Installing networking tools on VMs..."
nettoolsuri="https://raw.githubusercontent.com/dmauser/azure-vm-net-tools/main/script/nettools.sh"
while IFS= read -r vm; do
    [[ -z "$vm" ]] && continue
    az vm extension set --force-update --resource-group "$rg" --vm-name "$vm" \
        --name "customScript" --publisher "Microsoft.Azure.Extensions" \
        --protected-settings "{\"fileUris\": [\"$nettoolsuri\"],\"commandToExecute\": \"./nettools.sh\"}" \
        --no-wait -o none
done < <(az vm list -g "$rg" --query "[?contains(storageProfile.imageReference.publisher,'Canonical')].name" -o tsv)

# Enable boot diagnostics for branch VMs
echo "Enabling boot diagnostics for branch VMs..."
vm_ids=$(az vm list -g "$rg" --query "[?contains(name, '$branchname')].id" -o tsv | tr '\n' ' ')
if [[ -n "$vm_ids" ]]; then
    # shellcheck disable=SC2086
    az vm boot-diagnostics enable --ids $vm_ids -o none &>/dev/null &
fi

echo "Deployment has finished."

# Print total elapsed time
end=$(date +%s)
runtime=$(( end - start_time ))
echo ""
echo "Script finished at $(date)"
echo "Total execution time: $(( runtime / 3600 )) hours $(( (runtime / 60) % 60 )) minutes and $(( runtime % 60 )) seconds."