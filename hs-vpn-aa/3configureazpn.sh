#!/usr/bin/env bash
set -euo pipefail

# Parameters
rg="lab-vng-opn"
branchname="branch1"
branchasn="65100"
sharedkey="abc123"   # WARNING: change this to a strong secret before using in production
max_wait_minutes=30  # Maximum minutes to wait for each polling loop

# Verify Azure CLI is available
if ! command -v az &>/dev/null; then
    echo "Error: Azure CLI (az) is not installed or not in PATH." >&2
    exit 1
fi

if [[ "$sharedkey" == "abc123" ]]; then
    echo "Warning: Using default shared key 'abc123'. Set a strong shared key before deploying." >&2
fi

# Derive location from the resource group
location=$(az group show -n "$rg" --query location -o tsv)

# Record script start time
start_time=$(date +%s)
echo "Script started at $(date)"

# Wait for hub deployment to complete
echo "Monitoring hub deployment status..."
deadline=$(( $(date +%s) + max_wait_minutes * 60 ))
while true; do
    status=$(az deployment group show --name "Hub1-$location" --resource-group "$rg" \
        --query properties.provisioningState -o tsv)
    echo "  Deployment status: $status"
    if [ "$status" = "Succeeded" ]; then
        echo "Hub deployment succeeded."
        break
    elif [ "$status" = "Failed" ] || [ "$status" = "Canceled" ]; then
        echo "Error: Hub deployment ended with status '$status'." >&2
        exit 1
    elif (( $(date +%s) > deadline )); then
        echo "Error: Hub deployment did not complete within $max_wait_minutes minutes." >&2
        exit 1
    fi
    sleep 15
done

# Create branch local network gateway
echo "Creating local network gateway for $branchname..."
nvapip=$(az network public-ip show -g "$rg" --name "$branchname-opnnva-PublicIP" --query ipAddress -o tsv)

if [[ -z "$nvapip" ]]; then
    echo "Error: Could not retrieve public IP for '$branchname-opnnva-PublicIP'." >&2
    exit 1
fi

az network local-gateway create --name "$branchname-lgw" \
    --resource-group "$rg" --gateway-ip-address "$nvapip" \
    --bgp-peering-address 169.254.0.1 \
    --asn "$branchasn" \
    -o none

# Look up the VPN gateway name
vngvpn=$(az network vnet-gateway list -g "$rg" \
    --query "[?contains(name, 'vpn')].name" -o tsv | head -1)

if [[ -z "$vngvpn" ]]; then
    echo "Error: No VPN virtual network gateway found in resource group '$rg'." >&2
    exit 1
fi

# Create VPN connection
echo "Creating VPN connection: azure-to-$branchname-conn..."
az network vpn-connection create --name "azure-to-$branchname-conn" \
    --resource-group "$rg" --vnet-gateway1 "$vngvpn" \
    --shared-key "$sharedkey" \
    --local-gateway2 "$branchname-lgw" \
    --enable-bgp \
    -o none

# Wait for VPN connection provisioning to complete
echo "Waiting for VPN connection to complete provisioning..."
deadline=$(( $(date +%s) + max_wait_minutes * 60 ))
while true; do
    conn_status=$(az network vpn-connection show \
        --name "azure-to-$branchname-conn" --resource-group "$rg" \
        --query provisioningState -o tsv)
    echo "  VPN connection status: $conn_status"
    if [ "$conn_status" = "Succeeded" ]; then
        echo "VPN connection provisioned successfully."
        break
    elif [ "$conn_status" = "Failed" ] || [ "$conn_status" = "Canceled" ]; then
        echo "Error: VPN connection provisioning ended with status '$conn_status'." >&2
        exit 1
    elif (( $(date +%s) > deadline )); then
        echo "Error: VPN connection did not provision within $max_wait_minutes minutes." >&2
        exit 1
    fi
    sleep 10
done

echo "Configuration complete."

# Print total elapsed time
end=$(date +%s)
runtime=$(( end - start_time ))
echo ""
echo "Script finished at $(date)"
echo "Total execution time: $(( runtime / 3600 )) hours $(( (runtime / 60) % 60 )) minutes and $(( runtime % 60 )) seconds."