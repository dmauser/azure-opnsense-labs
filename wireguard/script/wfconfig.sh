#!/bin/bash

# Install WireGuard
echo "[+] Installing WireGuard..."
sudo apt update && sudo apt install -y wireguard
sudo apt install -y resolvconf
sudo apt install -y net-tools
clear

OUTPUT_FILE="/etc/wireguard/wg0.conf"

echo "Paste your WireGuard configuration below."
echo "End your input with a line containing only: EOF"
echo

# Read multiline input
CONFIG_CONTENT=""
while IFS= read -r line; do
    if [[ "$line" == "EOF" ]]; then
        break
    fi
    CONFIG_CONTENT+="$line"$'\n'
done

# Write config to file with sudo
echo -n "$CONFIG_CONTENT" | sudo tee "$OUTPUT_FILE" > /dev/null
sudo chmod 600 "$OUTPUT_FILE"

echo "✅ WireGuard config saved to $OUTPUT_FILE"

# Set permissions
sudo chmod 600 /etc/wireguard/wg0.conf

# Bring up interface
echo "[+] Starting WireGuard interface..."
sudo wg-quick up wg0

# Enable at boot
echo "[+] Enabling wg0 to start on boot..."
sudo systemctl enable "wg-quick@wg0"

echo "✅ WireGuard client setup complete!"
