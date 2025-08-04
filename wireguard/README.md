
# LAB: WireGuard VPN with OPNsense in Azure

## Overview

This lab demonstrates how to deploy OPNsense as a Network Virtual Appliance (NVA) in Azure, configure it with WireGuard VPN, and set up client configurations for secure remote access.

### Network Diagram

![Network Diagram](./diagram.png)

### OPNsense Deployment

OPNSense will be deployed by default on the Resource Group `lab-wg-nva`.

```bash
curl -sSL -o 1nva-deploy.sh https://raw.githubusercontent.com/dmauser/azure-opnsense-labs/main/wireguard/1nva-deploy.sh
chmod +x 1nva-deploy.sh
./1nva-deploy.sh
```

### WireGuard clients deployment

WireGuard client configuration will be deployed by default on the Resource Group `lab-wg-client`.

```bash
curl -sSL -o 2client-deploy.sh https://raw.githubusercontent.com/dmauser/azure-opnsense-labs/main/wireguard/2client-deploy.sh
chmod +x 2client-deploy.sh
./2client-deploy.sh
```

### OPNsense WireGuard Configuration

Note: add screenshots of the OPNsense WireGuard configuration here.

### Client configuration

```bash
curl -sSL -o wfconfig.sh https://raw.githubusercontent.com/dmauser/azure-opnsense-labs/main/wireguard/script/wfconfig.sh
chmod +x wfconfig.sh
./wfconfig.sh
```

### Cleanup

To clean up the resources created during this lab, run the following commands:

```bash
curl -sSL -o cleanup.sh https://raw.githubusercontent.com/dmauser/azure-opnsense-labs/main/wireguard/3cleanup.sh
chmod +x cleanup.sh
./cleanup.sh
```

