# LAB: Hub and Spoke with VNG and Branch using OPNsense

This lab demonstrates how to set up a hub-and-spoke network topology using Azure Virtual Network Gateway (VNG) and OPNsense firewall as a branch device.

## Lab Overview

In this lab, you will deploy and configure a secure, scalable, and manageable hub-and-spoke network topology suitable for hybrid cloud scenarios. The lab consists of three main scripts:

1. **`1hub-deploy.sh`**: Deploys Azure resources for the hub network, including the Virtual Network (VNet), subnets, and Virtual Network Gateway (VNG).

2. **`2branch-deploy.sh`**: Deploys Azure resources for the branch network, including the VNet, subnets, and an OPNsense firewall appliance.

3. **`3configurevpn.sh`**: Configures the VPN connection between the Azure VNG in the hub and the OPNsense firewall in the branch, establishing secure connectivity between the two networks.

By following these scripts, you will create a fully functional hub-and-spoke topology connecting Azure infrastructure with branch locations using OPNsense.
