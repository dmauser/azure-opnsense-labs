#!/bin/bash

rg="lab-vng-opn" # Define your resource group

# Get the First and Second Public IPs associated with the VNG
vngpip1=$(az network public-ip list -g $rg --query "[?contains(name, 'vpn')].{Name:name, IP:ipAddress}" -o tsv | awk 'NR==1{print $2}')
vngpip2=$(az network public-ip list -g $rg --query "[?contains(name, 'vpn')].{Name:name, IP:ipAddress}" -o tsv | awk 'NR==2{print $2}')

# Get Public IP of the OPNSense NVA
opnpip=$(az network public-ip show -g $rg --name branch1-opnnva-PublicIP --query ipAddress -o tsv)



