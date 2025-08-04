#!/bin/bash

# Install WireGuard
echo "[+] Installing WireGuard..."
sudo apt update && sudo apt install -y wireguard
sudo apt install -y resolvconf
sudo apt install -y net-tools
clear

OUTPUT_FILE="/etc/wireguard/wg0.conf"

# Check if run as root
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root to write to /etc/wireguard/"
  exit 1
fi

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

# Write config to file
echo -n "$CONFIG_CONTENT" > "$OUTPUT_FILE"
sudo chmod 600 "$OUTPUT_FILE"

echo "✅ WireGuard config saved to $OUTPUT_FILE"

# Bring up interface
echo "[+] Starting WireGuard interface..."
sudo wg-quick up "$WG_INTERFACE"

# Enable at boot
echo "[+] Enabling $WG_INTERFACE to start on boot..."
sudo systemctl enable "wg-quick@$WG_INTERFACE"