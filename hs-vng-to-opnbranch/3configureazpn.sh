# Parameters
rg="lab-vng-opn"
branchname="branch1"
branchasn="65100"
sharedkey="abc123"

# Create $branchname local network gateway
nvapip=$(az network public-ip show -g $rg --name branch1-opnnva-PublicIP --query ipAddress -o tsv)
az network local-gateway create --name $branchname-lgw \
--resource-group $rg --gateway-ip-address $nvapip \
--bgp-peering-address 169.254.0.1 \
--asn $branchasn \
--output none

# Create VPN connection to OPNSense trusted interface private IP
vngvpn=$(az network vnet-gateway list -g $rg --query "[?contains(name, 'vpn')].{Name:name}" -o tsv)
az network vpn-connection create --name azure-to-$branchname-conn \
--resource-group $rg --vnet-gateway1 $vngvpn \
--shared-key $sharedkey \
--local-gateway2 $branchname-lgw \
--enable-bgp \
--output none &>/dev/null &

sleep 5
echo "Waiting for VPN connection to be in provisioningState..."
while [ $(az network vpn-connection show --name azure-to-$branchname-conn --resource-group $rg --query "provisioningState" -o tsv) != "Succeeded" ]
do
    echo "Waiting for VPN connection current status: $(az network vpn-connection show --name azure-to-$branchname-conn --resource-group $rg --query "provisioningState" -o tsv)"
    sleep 10
done