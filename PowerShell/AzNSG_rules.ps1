Connect-AzureRmAccount

# make all errors raise an exception
$ErrorActionPreference = "stop"

# retrieve the nsg
$nsg = Get-AzureRmNetworkSecurityGroup -Name "west-nsg-v1.2" -ResourceGroupName "xxxx"

# add the new outbound rule
Add-AzureRmNetworkSecurityRuleConfig `
    -Name IntraApimProdOut `
    -NetworkSecurityGroup $nsg  `
    -Access Allow  `
    -Description "Intra Apim Prod traffic OUT"  `
    -DestinationAddressPrefix  X.X.X.X,X.X.X.X `
    -DestinationPortRange *  `
    -Direction Outbound  `
    -Protocol TCP  `
    -SourceAddressPrefix X.X.X.X,X.X.X.X  `
    -SourcePortRange *   `
    -Priority 161
	

Add-AzureRmNetworkSecurityRuleConfig `
    -Name IntraApimProdIn `
    -NetworkSecurityGroup $nsg  `
    -Access Allow  `
    -Description "Intra Apim Prod traffic IN"  `
    -DestinationAddressPrefix  X.X.X.X,X.X.X.X `
    -DestinationPortRange *  `
    -Direction Inbound  `
    -Protocol TCP  `
    -SourceAddressPrefix X.X.X.X,X.X.X.X  `
    -SourcePortRange *   `
    -Priority 161
	

Add-AzureRmNetworkSecurityRuleConfig `
    -Name Deny-APIMTEST2-any `
    -NetworkSecurityGroup $nsg  `
    -Access Deny  `
    -Description "Block traffic to APIMTest"  `
    -DestinationAddressPrefix  X.X.X.X,X.X.X.X `
    -DestinationPortRange *  `
    -Direction Inbound  `
    -Protocol TCP  `
    -SourceAddressPrefix *  `
    -SourcePortRange *   `
    -Priority 173
	
Add-AzureRmNetworkSecurityRuleConfig `
    -Name Deny-APIMPROD3-any `
    -NetworkSecurityGroup $nsg  `
    -Access Deny  `
    -Description "Block traffic to APIMProd"  `
    -DestinationAddressPrefix  X.X.X.X,X.X.X.X `
    -DestinationPortRange *  `
    -Direction Inbound  `
    -Protocol TCP  `
    -SourceAddressPrefix *  `
    -SourcePortRange *   `
    -Priority 174
	
# save the new rule
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg