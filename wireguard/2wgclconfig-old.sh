# !/bin/bash
# WireGuard Client Configuration Script
# Prompt for OPNSENSE_PUBLIC_KEY if not set
if [ -z "$OPNSENSE_PUBLIC_KEY" ]; then
    read -p "Enter OPNSENSE_PUBLIC_KEY: " OPNSENSE_PUBLIC_KEY
fi

# Prompt for OPNSENSE_ENDPOINT if not set
if [ -z "$OPNSENSE_ENDPOINT" ]; then
    read -p "Enter OPNSENSE_ENDPOINT (e.g., public_ip:51820): " OPNSENSE_ENDPOINT
fi

# Prompt for CLIENT_ADDRESS if not set
if [ -z "$CLIENT_ADDRESS" ]; then
    echo "Note: Make sure CLIENT_ADDRESS does not conflict with any other client."
    read -p "Enter CLIENT_ADDRESS (e.g., 10.10.10.2/24): " CLIENT_ADDRESS
fi

# Run az commmand to run wfconfig.sh
az vm run-command invoke --resource-group "$rg" --name "$vm_name" \
  --command-id RunShellScript --scripts "bash -s" --parameters "$OPNSENSE_PUBLIC_KEY" "$OPNSENSE_ENDPOINT" "$CLIENT_ADDRESS"

