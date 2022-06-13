# Variables for VM resources
uniqueId=sonlh98ba
resourceGroup="group$uniqueId"
location='australiaeast'
myVM="Web01" 

# Create resource group
az group create \
--name $resourceGroup \
--location $location \
--verbose

# Create VM
az vm create \
--resource-group $resourceGroup \
--name $myVM \
--image Win2019Datacenter \
--public-ip-sku Standard \
--admin-username iisadmin \
--admin-password 11041998SonSon

# Install ISS
az vm run-command invoke -g $resourceGroup -n $myVM --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"

# Open port for tcp connection
az vm open-port --port 80 --resource-group $resourceGroup --name $myVM