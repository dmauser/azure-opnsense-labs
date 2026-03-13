#!/usr/bin/env bash
set -euo pipefail

# Parameters
rg="lab-vng-opn"
max_wait_minutes=90   # Maximum minutes to wait for the hub/VPN gateway deployment
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$script_dir/config-vpn-template.xml"
output="$script_dir/config-OPNsense.xml"

# Verify Azure CLI is available
if ! command -v az &>/dev/null; then
    echo "Error: Azure CLI (az) is not installed or not in PATH." >&2
    exit 1
fi

# Verify the template file exists
if [[ ! -f "$template" ]]; then
    echo "Error: Template file not found: $template" >&2
    exit 1
fi

# Derive location from the resource group
location=$(az group show -n "$rg" --query location -o tsv)

# Record script start time
start_time=$(date +%s)
echo "Script started at $(date)"

# Wait for the hub deployment (VPN gateway included) to complete
echo "Waiting for hub deployment 'Hub1-$location' to complete..."
deadline=$(( $(date +%s) + max_wait_minutes * 60 ))
while true; do
    status=$(az deployment group show --name "Hub1-$location" --resource-group "$rg" \
        --query properties.provisioningState -o tsv 2>/dev/null || echo "NotFound")
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

# Retrieve Azure VPN Gateway public IPs (active-active: primary then secondary, sorted by name)
echo "Retrieving VPN Gateway public IPs..."
mapfile -t vng_ips < <(az network public-ip list -g "$rg" \
    --query "sort_by([?contains(name, 'vpn')], &name)[].ipAddress" -o tsv)

if [[ ${#vng_ips[@]} -lt 2 ]]; then
    echo "Error: Expected 2 VPN gateway public IPs, found ${#vng_ips[@]}." >&2
    exit 1
fi

vngpip1="${vng_ips[0]}"   # a.a.a.a — primary tunnel peer
vngpip2="${vng_ips[1]}"   # b.b.b.b — secondary tunnel peer

# Retrieve OPNsense NVA public IP (untrusted interface)
echo "Retrieving OPNsense public IP..."
opnpip=$(az network public-ip show -g "$rg" --name "branch1-opnnva-PublicIP" \
    --query ipAddress -o tsv)

if [[ -z "$opnpip" ]]; then
    echo "Error: Could not retrieve OPNsense public IP 'branch1-opnnva-PublicIP'." >&2
    exit 1
fi

echo ""
echo "=== Substitution Values ==="
echo "  VPN GW Primary IP   (a.a.a.a) : $vngpip1"
echo "  VPN GW Secondary IP (b.b.b.b) : $vngpip2"
echo "  OPNsense Public IP  (c.c.c.c) : $opnpip"
echo "==========================="
echo ""

# Generate config-OPNsense.xml by substituting placeholders in the template
echo "Generating: $output"
sed \
    -e "s/a\.a\.a\.a/${vngpip1}/g" \
    -e "s/b\.b\.b\.b/${vngpip2}/g" \
    -e "s/c\.c\.c\.c/${opnpip}/g" \
    "$template" > "$output"

echo "Done. Import the generated file into OPNsense:"
echo "  System > Configuration > Backup & Restore > Restore"
echo "  File: $output"

# Print total elapsed time
end=$(date +%s)
runtime=$(( end - start_time ))
echo ""
echo "Script finished at $(date)"
echo "Total execution time: $(( runtime / 3600 )) hours $(( (runtime / 60) % 60 )) minutes and $(( runtime % 60 )) seconds."

