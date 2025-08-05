
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

1. Configure Static Routes

System:Routes:Configuration

Add RFC 1918 routes ensure they use LAN_GW as next hop as shown:

![System:Routes:Configuration](./media/system-routes-configuration.png)

> ⚡ **Make sure to click "Apply" to commit the changes.**

2. Configure WireGuard

VPN:WireGuard:Configuration

![VPN:WireGuard:Configuration](./media/vpn-wireguard-configuration.png)

3. Assign WireGuard Interface

Interfaces:Assignments



![Interfaces:Assignments](./media/interfaces-assignments.png)

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

