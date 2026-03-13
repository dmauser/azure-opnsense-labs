#!/usr/bin/env bash
set -euo pipefail

# Parameters
rg="lab-vng-opn"
vmsize="Standard_B2s" # Burstable 2 vCPU / 4 GB — affordable for lab VMs
max_wait_minutes=60       # Maximum minutes to wait for deployment to complete

# Verify Azure CLI is available
if ! command -v az &>/dev/null; then
    echo "Error: Azure CLI (az) is not installed or not in PATH." >&2
    exit 1
fi

# Prompt for location
read -p "Enter the location (default: westus3): " location
location=${location:-westus3}

# Prompt for username
read -p "Enter your username (default: azureuser): " username
username=${username:-azureuser}

# Prompt for password with confirmation
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

# Record script start time
start_time=$(date +%s)
echo "Script started at $(date)"

# Print deployment summary
echo ""
echo "=== Deployment Summary ==="
echo "  Resource group : $rg"
echo "  Location       : $location"
echo "  VM size        : $vmsize"
echo "  Admin user     : $username"
echo "=========================="
echo ""

# Deploy Hub and Spoke
echo "Deploying Hub and Spoke..."
az group create --name "$rg" --location "$location" -o none
az deployment group create --name "Hub1-$location" --resource-group "$rg" \
    --template-uri "https://raw.githubusercontent.com/dmauser/azure-hub-spoke-base-lab/main/azuredeployv6.json" \
    --parameters "https://raw.githubusercontent.com/dmauser/azure-hub-spoke-base-lab/refs/heads/main/parameters.json" \
    --parameters virtualMachineSize="$vmsize" virtualMachinePublicIP=false deployBastion=true deployOnpremisesVPNGateway=false \
    --parameters VmAdminUsername="$username" VmAdminPassword="$password" \
    --no-wait -o none

# Monitor deployment status (with timeout)
echo "Monitoring deployment status..."
deadline=$(( $(date +%s) + max_wait_minutes * 60 ))
while true; do
    status=$(az deployment group show --name "Hub1-$location" --resource-group "$rg" \
        --query properties.provisioningState -o tsv)
    echo "  Deployment status: $status"
    if [ "$status" = "Succeeded" ]; then
        echo "Deployment succeeded."
        break
    elif [ "$status" = "Failed" ] || [ "$status" = "Canceled" ]; then
        echo "Error: Deployment ended with status '$status'." >&2
        exit 1
    elif (( $(date +%s) > deadline )); then
        echo "Error: Deployment did not complete within $max_wait_minutes minutes." >&2
        exit 1
    fi
    sleep 15
done
echo "Deployment has finished."

# Print total elapsed time
end=$(date +%s)
runtime=$(( end - start_time ))
echo ""
echo "Script finished at $(date)"
echo "Total execution time: $(( runtime / 3600 )) hours $(( (runtime / 60) % 60 )) minutes and $(( runtime % 60 )) seconds."