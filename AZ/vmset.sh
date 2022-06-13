# Source: https://docs.microsoft.com/en-us/azure/load-balancer/quickstart-load-balancer-standard-public-cli
# Variables for VM resources
uniqueId=sonlh98ba
resourceGroup="group$uniqueId"
location='australiaeast'
myVNet="myVNet" 
myBackendSubnet="myBackendSubnet"
myPublicIP="myPublicIP"
myLoadBalancer="myLoadBalancer"
myFrontEnd="myFrontEnd"
myBackEndPool="myBackEndPool"
myHealthProbe="myHealthProbe"
myHTTPRule="myHTTPRule"
myNSG="myNSG"
myNSGRuleHTTP="myNSGRuleHTTP"
myBastionIP="myBastionIP"
myBastionHost="myBastionHost"

# Create resource group
az group create \
--name $resourceGroup \
--location $location \
--verbose

# Create a Virtual Network
az network vnet create \
--resource-group $resourceGroup \
--location $location \
--name $myVNet \
--address-prefixes 10.1.0.0/16 \
--subnet-name $myBackendSubnet \
--subnet-prefixes 10.1.0.0/24

# --Create a public IP address
az network public-ip create \
--resource-group $resourceGroup \
--name $myPublicIP \
--sku Standard \
--zone 1 2 3

# Create a load balancer
# --Create the load balancer resource
az network lb create \
--resource-group $resourceGroup \
--name $myLoadBalancer \
--sku Standard \
--public-ip-address $myPublicIP \
--frontend-ip-name $myFrontEnd \
--backend-pool-name $myBackEndPool

# --Create the health probe
az network lb probe create \
--resource-group $resourceGroup \
--lb-name $myLoadBalancer \
--name $myHealthProbe \
--protocol tcp \
--port 80

# --Create the load balancer rule
az network lb rule create \
--resource-group $resourceGroup \
--lb-name $myLoadBalancer \
--name $myHTTPRule \
--protocol tcp \
--frontend-port 80 \
--backend-port 80 \
--frontend-ip-name $myFrontEnd \
--backend-pool-name $myBackEndPool \
--probe-name $myHealthProbe \
--disable-outbound-snat true \
--idle-timeout 15 \
--enable-tcp-reset true

# --Create a network security group
az network nsg create \
--resource-group $resourceGroup \
--name $myNSG

# --Create a network security group rule
az network nsg rule create \
--resource-group $resourceGroup \
--nsg-name $myNSG \
--name $myNSGRuleHTTP \
--protocol '*' \
--direction inbound \
--source-address-prefix '*' \
--source-port-range '*' \
--destination-address-prefix '*' \
--destination-port-range 80 \
--access allow \
--priority 200

# Create a bastion host
# --Create a public IP address
az network public-ip create \
--resource-group $resourceGroup \
--name $myBastionIP \
--sku Standard \
--zone 1 2 3

# --Create a bastion subnet
az network vnet subnet create \
--resource-group $resourceGroup \
--name AzureBastionSubnet \
--vnet-name $myVNet \
--address-prefixes 10.1.1.0/27

# --Create bastion host
az network bastion create \
--resource-group $resourceGroup \
--name $myBastionHost \
--public-ip-address $myBastionIP \
--vnet-name $myVNet \
--location $location

# Create backend servers
# --Create network interfaces for the virtual machines
array=(myNicVM1 myNicVM2)
for vmnic in "${array[@]}"
do
az network nic create \
    --resource-group $resourceGroup \
    --name $vmnic \
    --vnet-name $myVNet \
    --subnet myBackEndSubnet \
    --network-security-group $myNSG
done

# --Create virtual machines
az vm create \
--resource-group $resourceGroup \
--name myVM1 \
--nics myNicVM1 \
--image Win2019Datacenter \
--admin-username iisadmin \
--admin-password 11041998SonSon \
--zone 1 \
--no-wait

az vm create \
--resource-group $resourceGroup \
--name myVM2 \
--nics myNicVM2 \
--image Win2019Datacenter \
--admin-username iisadmin \
--admin-password 11041998SonSon \
--zone 2 \
--no-wait

# --Add virtual machines to load balancer backend pool
array=(myNicVM1 myNicVM2)
for vmnic in "${array[@]}"
do
az network nic ip-config address-pool add \
    --address-pool myBackendPool \
    --ip-config-name ipconfig1 \
    --nic-name $vmnic \
    --resource-group $resourceGroup \
    --lb-name $myLoadBalancer
done

# Create NAT gateway
# --Create public IP
az network public-ip create \
--resource-group $resourceGroup \
--name myNATgatewayIP \
--sku Standard \
--zone 1 2 3

# --Create NAT gateway resource
az network nat gateway create \
--resource-group $resourceGroup \
--name myNATgateway \
--public-ip-addresses myNATgatewayIP \
--idle-timeout 10

# --Associate NAT gateway with subnet
az network vnet subnet update \
--resource-group $resourceGroup \
--vnet-name $myVNet \
--name $myBackendSubnet \
--nat-gateway myNATgateway

# Install IIS
array=(myVM1 myVM2)
for vm in "${array[@]}"
do
    az vm extension set \
    --publisher Microsoft.Compute \
    --version 1.8 \
    --name CustomScriptExtension \
    --vm-name $vm \
    --resource-group $resourceGroup \
    --settings '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'
done

# Test the load balancer
az network public-ip show \
--resource-group $resourceGroup \
--name $myPublicIP \
--query ipAddress \
--output tsv