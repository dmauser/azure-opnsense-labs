#!/bin/bash
# Install WireGuard
echo "[+] Installing WireGuard..."
sudo apt update && sudo apt install -y wireguard
sudo apt install -y resolvconf
sudo apt install -y net-tools

UUID=$(hostname)
read -p "Enter API Key: " API_KEY
read -sp "Enter API Secret: " API_SECRET
read -p "Enter OPNSENSE IP: " OPNSENSE_HOST

CONF_JSON=$(curl -s -k -u "$API_KEY:$API_SECRET" \
  "https://$OPNSENSE_HOST/api/wireguard/general/showPeer/$UUID")

PRIVATE_KEY=$(echo "$CONF_JSON" | jq -r '.peer.private_key')
TUNNEL_ADDR=$(echo "$CONF_JSON" | jq -r '.peer.tunnel_address')
SERVER_PUBKEY=$(echo "$CONF_JSON" | jq -r '.peer.server_public_key')
ENDPOINT=$(echo "$CONF_JSON" | jq -r '.peer.endpoint_address')
PORT=$(echo "$CONF_JSON" | jq -r '.peer.endpoint_port')
ALLOWED_IPS=$(echo "$CONF_JSON" | jq -r '.peer.allowed_ips')

cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $TUNNEL_ADDR

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $ENDPOINT:$PORT
AllowedIPs = $ALLOWED_IPS
EOF

# Set permissions
sudo chmod 600 /etc/wireguard/wg0.conf

# Bring up interface
echo "[+] Starting WireGuard interface..."
sudo wg-quick up wg0

# Enable at boot
echo "[+] Enabling wg0 to start on boot..."
sudo systemctl enable "wg-quick@wg0"
