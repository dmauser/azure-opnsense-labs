# Parameters
rg="lab-wg-nva" # Define your resource group
mypip=$(curl -4 ifconfig.io -s) # Captures your local Public IP for NSG rules
branchname="azwg

# Prompt for location
read -p "Enter the location (default: westus3): " location
location=${location:-westus3} # Default to westus3 if not provided

# Prompt for username and password
read -p "Enter your username (default: azureuser): " username
username=${username:-azureuser} # Default to azureuser if not provided


# Deploy OPNsense NVA
ShellScriptName="configureopnsense.sh"
scenarioOption="TwoNics"
virtualMachineSize="Standard_DS1_v2"
virtualMachineName="$branchname-opnnva"
virtualNetworkName="$branchname-vnet"
VNETAddress="192.168.100.0/24"
UntrustedSubnetCIDR="192.168.100.64/28"
TrustedSubnetCIDR="192.168.100.80/28"
existingUntrustedSubnetName="untrusted"
existingTrustedSubnetName="trusted"

# Record script start time
start_time=$(date +%s)
echo "Script started at $(date)"

# Wait for the resource group to exist
while true; do
  if [ "$(az group exists --name $rg)" = "true" ]; then
    echo "Resource group $rg exists."
    break
  else
    echo "Resource group $rg does not exist. Waiting for 15 seconds..."
    sleep 15
  fi
done

# Create NVA VNET and subnet
az network vnet create --name "$branchname-vnet" --resource-group $rg --location $location \
  --address-prefix "192.168.100.0/24" --subnet-name "vm-subnet" --subnet-prefix "192.168.100.0/28" -o none

# Assign NSG to the subnet
az network vnet subnet update -g $rg -n "vm-subnet" --vnet-name "$branchname-vnet" \
  --network-security-group "$location-default-nsg" -o none

# Create Ubuntu VM on vm-subnet
az vm create -n "$branchname-vm1" -g $rg --image "Ubuntu2204" \
  --size "Standard_DS1_v2" -l $location --subnet "vm-subnet" --vnet-name "$branchname-vnet" \
  --admin-username "$username" --admin-password "$password" --nsg "" --no-wait --only-show-errors \
  --public-ip-address ""

# Create untrusted and trusted subnets
az network vnet subnet create -g $rg --vnet-name $virtualNetworkName --name $existingUntrustedSubnetName \
  --address-prefixes $UntrustedSubnetCIDR --output none
az network vnet subnet create -g $rg --vnet-name $virtualNetworkName --name $existingTrustedSubnetName \
  --address-prefixes $TrustedSubnetCIDR --output none

# Deploy OPNsense VM
echo "Deploying OPNsense NVA on $branchname"
az vm image terms accept --urn thefreebsdfoundation:freebsd-14_1:14_1-release-amd64-gen2-zfs:14.1.0 -o none
az deployment group create --name "$branchname-nva-$RANDOM" --resource-group $rg \
  --template-uri "https://raw.githubusercontent.com/dmauser/opnazure/master/ARM/main.json" \
  --parameters scenarioOption=$scenarioOption virtualMachineName=$virtualMachineName \
  virtualMachineSize=$virtualMachineSize existingvirtualNetwork="existing" \
  VNETAddress="[\"$VNETAddress\"]" virtualNetworkName=$virtualNetworkName \
  UntrustedSubnetCIDR=$UntrustedSubnetCIDR TrustedSubnetCIDR=$TrustedSubnetCIDR \
  existingUntrustedSubnetName=$existingUntrustedSubnetName existingTrustedSubnetName=$existingTrustedSubnetName \
  Location=$location --no-wait

# Wait for Trusted NIC to exist
echo "Waiting for OPNSense trusted NIC to exist..."
az network nic wait --name "$branchname-opnnva-Trusted-NIC" --resource-group $rg --created

# Create and configure NSG for NVA subnet
echo "Creating NSG and associating it to NVA Subnet"

az network nsg create \
  --resource-group $rg \
  --name $branchname-nva-nsg \
  --location $location \
  -o none

az network nsg rule create \
  -g $rg \
  --nsg-name $branchname-nva-nsg \
  -n 'allow-https' \
  --direction Inbound \
  --priority 300 \
  --source-address-prefixes $mypip \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 443 \
  --access Allow \
  --protocol Tcp \
  --description "Allow inbound HTTPs" \
  --output none

az network nsg rule create \
  -g $rg \
  --nsg-name $branchname-nva-nsg \
  -n 'allow-rfc1918-in' \
  --direction Inbound \
  --priority 310 \
  --source-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
  --destination-port-ranges '*' \
  --access Allow \
  --protocol '*' \
  --description "allow-rfc1918-in" \
  --output none

az network nsg rule create \
  -g $rg \
  --nsg-name $branchname-nva-nsg \
  -n 'allow-rfc1918-out' \
  --direction outbound \
  --priority 320 \
  --source-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
  --source-port-ranges '*' \
  --destination-address-prefixes 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 \
  --destination-port-ranges '*' \
  --access Allow \
  --protocol '*' \
  --description "allow-rfc1918-out" \
  --output none

az network vnet subnet update \
  -g $rg \
  --name trusted \
  --vnet-name $branchname-vnet \
  --network-security-group $branchname-nva-nsg \
  -o none

# Add UDP 500 and 4500 rules to the default NSG
az network nsg rule create \
  -g $rg \
  --nsg-name "$branchname-nva-nsg" \
  -n "allow-udp500" \
  --priority 330 \
  --destination-port-ranges 500 \
  --direction Inbound \
  --access Allow \
  --protocol Udp \
  -o none

az network nsg rule create \
  -g $rg \
  --nsg-name "$branchname-nva-nsg" \
  -n "allow-udp4500" \
  --priority 340 \
  --destination-port-ranges 4500 \
  --direction Inbound \
  --access Allow \
  --protocol Udp \
  -o none

# Create UDR and associate it with the subnet
fs1nvaip=$(az network nic show --name "$branchname-opnnva-Trusted-NIC" --resource-group $rg \
  --query "ipConfigurations[0].privateIPAddress" -o tsv)
az network route-table create -g $rg --name "$branchname-UDR" -l $location -o none
az network route-table route create -g $rg --route-table-name "$branchname-UDR" --name "$branchname-UDR" \
  --address-prefix "0.0.0.0/0" --next-hop-type VirtualAppliance --next-hop-ip-address $fs1nvaip -o none
az network vnet subnet update -g $rg -n "vm-subnet" --vnet-name "$branchname-vnet" \
  --route-table "$branchname-UDR" -o none

# Remove NSG from OPNsense NICs and reassign default NSG
az network nic update -g $rg -n "$virtualMachineName-Trusted-NIC" --network-security-group null --output none
az network nic update -g $rg -n "$virtualMachineName-Untrusted-NIC" --network-security-group null --output none
az network vnet subnet update --name $existingTrustedSubnetName --resource-group $rg \
  --vnet-name $virtualNetworkName --network-security-group "$branchname-nva-nsg" -o none
az network vnet subnet update --name $existingUntrustedSubnetName --resource-group $rg \
  --vnet-name $virtualNetworkName --network-security-group "$branchname-nva-nsg" -o none

# Install networking tools on all VMs
echo "Installing networking tools on VMs"
nettoolsuri="https://raw.githubusercontent.com/dmauser/azure-vm-net-tools/main/script/nettools.sh"
for vm in $(az vm list -g $rg --query "[?contains(storageProfile.imageReference.publisher,'Canonical')].name" -o tsv); do
  az vm extension set --force-update --resource-group $rg --vm-name $vm --name "customScript" \
    --publisher "Microsoft.Azure.Extensions" \
    --protected-settings "{\"fileUris\": [\"$nettoolsuri\"],\"commandToExecute\": \"./nettools.sh\"}" --no-wait
done

# Enable boot diagnostics for all VMs
echo "Enabling boot diagnostics for all VMs"
az vm boot-diagnostics enable --ids $(az vm list -g $rg --query "[?contains(name, '$branchname')].id" -o tsv) -o none

echo "Deployment has finished."

# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start_time))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."