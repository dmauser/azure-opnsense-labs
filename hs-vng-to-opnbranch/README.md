# Lab: Active/Active Azure VPN Gateway S2S VPN with BGP and OPNSense


This lab demonstrates how to set up a hub-and-spoke network topology using Azure Virtual Network Gateway (VNG) VPN and OPNSense firewall as a branch device.

This lab uses Active/Active VPN Gateway using two IPsec tunnels to connect the Azure hub network with a branch network that uses OPNSense as a firewall appliance. In this lab we use VTI and a loopback interface on the OPNSense to instance the BGP. 

## Network Topology

![](./media/network-diagram.png)

The lab consists of three main scripts to deploy the hub and spoke and also the branch network with OPNSense:

1. **`1hub-deploy.sh`**: Deploys Azure resources for the hub network, including VNet, subnets, and Virtual Network Gateway (VNG). There are a Linux VM on each vNet (Hub, Spoke1, and Spoke2).

2. **`2branch-deploy.sh`**: Deploys Azure resources for the branch network, including the VNet, subnets, and an OPNSense firewall appliance.

3. **`3configurevpn.sh`**: Configures the VPN connection between the Azure VNG in the hub and the OPNSense firewall in the branch.

## OPNSense configuration

