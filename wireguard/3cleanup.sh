!#!/bin/bash
nvarg="lab-wg-nva" # Define your resource group
clientrg="lab-wg-client" # Define your client resource group

# Delete NVA resource group
echo "Deleting NVA resource group $nvarg..."
az group delete --name $nvarg --yes --no-wait -o none
# Delete Client resource group
echo "Deleting Client resource group $clientrg..."
az group delete --name $clientrg --yes --no-wait -o none

