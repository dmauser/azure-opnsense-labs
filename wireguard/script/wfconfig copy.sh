#!/bin/bash

CONFIG_CONTENT="${1:-$CONFIG_CONTENT}"
WG_INTERFACE="${2:-$WG_INTERFACE:-wg0}"
WG_CONF="/etc/wireguard/${WG_INTERFACE}.conf"

# WireGuard Client Configuration Script
read -p "Enter WireGuard config content (end with CTRL+D): " CONFIG_CONTENT

# Install WireGuard
echo "[+] Installing WireGuard..."
sudo apt update && sudo apt install -y wireguard
sudo apt install -y resolvconf
sudo apt install -y net-tools

# Create WireGuard config file
echo "[+] Creating WireGuard config at $WG_CONF..."
sudo mkdir -p /etc/wireguard
sudo bash -c "cat > $WG_CONF" <<EOF
$CONFIG_CONTENT
EOF

# Set permissions
sudo chmod 600 "$WG_CONF"

