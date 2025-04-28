# Parameters
rg="lab-vng-opn"
vmsize="Standard_D2d_v4" # Specify the VM size you want to use

# Prompt for location
read -p "Enter the location (default: westus3): " location
location=${location:-westus3} # Default to westus3 if not provided

# Prompt for username and password
read -p "Enter your username (default: azureuser): " username
username=${username:-azureuser} # Default to azureuser if not provided

while true; do
    read -s -p "Enter your password: " password
    echo
    read -s -p "Confirm your password: " password_confirm
    echo
    if [ "$password" = "$password_confirm" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Record script start time
start_time=$(date +%s)
echo "Script started at $(date)"

# Check if the resource group exists
echo "Checking if resource group '$rg' exists..."
if [ "$(az group exists --name $rg)" = "true" ]; then
    read -p "Resource group '$rg' already exists. Do you want to delete it? (y/n): " delete_rg
    if [ "$delete_rg" = "y" ]; then
        echo "Deleting resource group '$rg'..."
        az group delete --name $rg --yes --no-wait
        az group wait --name $rg --deleted
    else
        echo "Exiting script..."
        exit 1
    fi
fi

# Deploy Hub and Spoke
echo "Deploying Hub and Spoke..."
az group create --name $rg --location $location -o none
az deployment group create --name "Hub1-$location" --resource-group $rg \
    --template-uri "https://raw.githubusercontent.com/dmauser/azure-hub-spoke-base-lab/main/azuredeployv6.json" \
    --parameters "https://raw.githubusercontent.com/dmauser/azure-hub-spoke-base-lab/refs/heads/main/parameters.json" \
    --parameters virtualMachineSize=$vmsize virtualMachinePublicIP=false deployBastion=true deployOnpremisesVPNGateway=false \
    --parameters VmAdminUsername=$username VmAdminPassword=$password \
    --no-wait

# Check if the deployment command succeeded
if [ $? -ne 0 ]; then
    echo "Error deploying Hub and Spoke. Exiting script..."
    exit 1
fi

# Monitor deployment status
echo "Monitoring deployment status..."
while true; do
    status=$(az deployment group show --name "Hub1-$location" --resource-group $rg --query properties.provisioningState -o tsv)
    echo "Deployment status: $status"
    if [ "$status" = "Succeeded" ]; then
        echo "Deployment succeeded."
        break
    elif [ "$status" = "Failed" ]; then
        echo "Deployment failed."
        exit 1
    fi
    sleep 15 # Wait for 15 seconds before checking again
done
echo "Deployment has finished."

# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start_time))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."