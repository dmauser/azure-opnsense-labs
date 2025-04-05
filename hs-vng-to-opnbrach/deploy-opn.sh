echo "Deploying OPNsense NVA1 on the $branchname"
az vm image terms accept --urn thefreebsdfoundation:freebsd-14_1:14_1-release-amd64-gen2-zfs:14.1.0 -o none
  az deployment group create --name $branchname-nva-$RANDOM --resource-group $rg \
 --template-uri "https://raw.githubusercontent.com/dmauser/opnazure/master/ARM/main.json" \
 --parameters scenarioOption=$scenarioOption virtualMachineName=$virtualMachineName virtualMachineSize=$virtualMachineSize existingvirtualNetwork=$existingvirtualNetwork VNETAddress="[\"$VNETAddress\"]" virtualNetworkName=$virtualNetworkName UntrustedSubnetCIDR=$UntrustedSubnetCIDR TrustedSubnetCIDR=$TrustedSubnetCIDR existingUntrustedSubnetName=$existingUntrustedSubnetName existingTrustedSubnetName=$existingTrustedSubnetName Location=$location \
 --no-wait