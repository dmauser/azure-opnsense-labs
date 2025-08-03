#!/bin/bash

# ========================
# WireGuard Client Setup Script (Parameterized)
# ========================

# Input Parameters (can be overridden via command line or environment)
OPNSENSE_PUBLIC_KEY="${1:-$OPNSENSE_PUBLIC_KEY}"
OPNSENSE_ENDPOINT="${2:-$OPNSENSE_ENDPOINT}"     # e.g., "vpn.example.com:51820"
CLIENT_ADDRESS="${3:-$CLIENT_ADDRESS}"           # e.g., "10.10.10.2/24"
DNS_SERVER="${4:-$DNS_SERVER:-8.8.8.8}"           # Optional (default: 8.8.8.8)
WG_INTERFACE="${5:-$WG_INTERFACE:-wg0}"
WG_CONF="/etc/wireguard/${WG_INTERFACE}.conf"

# Check required parameters
if [[ -z "$OPNSENSE_PUBLIC_KEY" || -z "$OPNSENSE_ENDPOINT" || -z "$CLIENT_ADDRESS" ]]; then
  echo "Usage: $0 <opnsense_public_key> <opnsense_endpoint> <client_address> [dns_server] [wg_interface]"
  echo "Or set as environment variables:"
  echo "  OPNSENSE_PUBLIC_KEY, OPNSENSE_ENDPOINT, CLIENT_ADDRESS, DNS_SERVER (optional), WG_INTERFACE (optional)"
  exit 1
fi

# Install WireGuard
echo "[+] Installing WireGuard..."
sudo apt update && sudo apt install -y wireguard
sudo apt install -y resolvconf
sudo apt install -y net-tools

# Generate Key Pair
echo "[+] Generating WireGuard keys..."
KEY_DIR="$HOME/wg-keys-${WG_INTERFACE}"
mkdir -p "$KEY_DIR"
wg genkey | tee "$KEY_DIR/privatekey" | wg pubkey > "$KEY_DIR/publickey"
PRIVATE_KEY=$(cat "$KEY_DIR/privatekey")
PUBLIC_KEY=$(cat "$KEY_DIR/publickey")

# Output public key for server config
echo "=== Your WireGuard Client Public Key ==="
echo "$PUBLIC_KEY"
echo "Paste this into your OPNsense Peer config."
echo "========================================="

# Create WireGuard config file
echo "[+] Creating WireGuard config at $WG_CONF..."
sudo mkdir -p /etc/wireguard
sudo bash -c "cat > $WG_CONF" <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $CLIENT_ADDRESS
DNS = $DNS_SERVER

[Peer]
PublicKey = $OPNSENSE_PUBLIC_KEY
Endpoint = $OPNSENSE_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Set permissions
sudo chmod 600 "$WG_CONF"

# Bring up interface
echo "[+] Starting WireGuard interface..."
sudo wg-quick up "$WG_INTERFACE"

# Enable at boot
echo "[+] Enabling $WG_INTERFACE to start on boot..."
sudo systemctl enable "wg-quick@$WG_INTERFACE"

echo "[✔] WireGuard client setup complete!"
echo "Use the public key below in your OPNsense WireGuard Peer configuration:"
echo "$PUBLIC_KEY"