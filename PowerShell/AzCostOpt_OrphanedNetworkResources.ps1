#############################################################################
#                                     			 		                    #
#   This script scans a given subscription for unused network components.   #
#                                     			 		                    #
#   Version 1.0.0                              			 	                #  
#   Last Revision Date 2/22/2018                              			 	#  
#   Author: Pratik Bhattacharya                      	                    #
#                                     			 		                    #
#############################################################################

#Requires -version 5
#Requires -module AzureRM.Profile, AzureRM.Compute, AzureRM.Storage

#Global
$VMNICArray = New-Object System.Collections.ArrayList
$SubnetArray = New-Object System.Collections.ArrayList
$SubnetIDArray = New-Object System.Collections.ArrayList
$NSGToBeVerified = New-Object System.Collections.ArrayList
$GatewayArray = New-Object System.Collections.ArrayList
$UnusedPIPs = New-Object System.Collections.ArrayList
$UnusedNics = New-Object System.Collections.ArrayList
$UnusedVnets = New-Object System.Collections.ArrayList
$htmlHead = @"
<title>Orphaned Network Resources</title>
<style>
body { background-color:#dddddd;
font-family:Tahoma;
font-size:12pt; }
td, th { border:1px solid black;
border-collapse:collapse; }
th { color:white;
background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px }
table { margin-left:50px; }
</style>
"@

Function Select-Subs
{
    $ErrorActionPreference = 'SilentlyContinue'
    $MenuItem = 0
    $Subs = @(Get-AzureRmSubscription | select Name,Id,TenantId)

    Write-Host "Please select the subscription you wish to scan" -ForegroundColor Green;
    $Subs |%{Write-Host "[$($MenuItem)]" -ForegroundColor Cyan -NoNewline ;Write-host ". $($_.Name)";$MenuItem++;
    }
    $selection = Read-Host "Please select the Subscription Number - Valid numbers are 0 - $($Subs.count -1)"
    If ($Subs.item($selection) -ne $null)
    {
        Write-Host $subs[$selection].Name;
        Return @{name = $subs[$selection].Name;}
    }

}

Function GetAllActiveVMsAndProperties {
	$AllVMs = Get-AzureRmVM
	ForEach($vm in $AllVMs) {
		$networkInterfaces = $vm.NetworkProfile.NetworkInterfaces
		ForEach($nic in $networkInterfaces) {
			$VMNICArray.Add($nic.Id) > $null
		}
	}
}

Function GetUnusedPIPs {
    Write-Host("Scanning Publib IP Addresses");
    $unsedPipCounter = 0
	$AllPublicIPAddresses = Get-AzureRmPublicIpAddress
	ForEach($ipAddress in $AllPublicIPAddresses) {
		#IP Addresses with no IP Configuration are not in use
		If ($ipAddress.Ipconfiguration.id.count -eq 0) {  
			Write-Host (" " + $ipAddress.name + " is not in use") -ForegroundColor Yellow
            $unsedPipCounter++
            $UnusedPIPs.Add($ipAddress)
		}
		Else { #TODO - Take a deeper look
			#Get the $ipAddress.Ipconfiguration.id and split it on /.. [4] should be resource group, [7] is virtualNetworkGateways [8] is GW name.
			$ipConfigId = $ipAddress.Ipconfiguration.id;
			$ipConfigIdSplit = $ipConfigId.Split("/")
			if ($ipConfigIdSplit[7] -eq 'virtualNetworkGateways') {
				$GatewayArray.add($ipConfigIdSplit[8] + "/" + $ipConfigIdSplit[4])
				Write-Host (" Added to Gateway array = " + $ipConfigIdSplit[8] + "/" + $ipConfigIdSplit[4])
			}
		}
	}
    If ($unsedPipCounter -eq 0) {
        Write-Host("No Unsed Public IP Address Found")
    }
}

Function GetUnusedNICs {
    Write-Host("Scanning all Network Cards");
	$AllNICs = Get-AzureRmNetworkInterface
    $unsedNICCounter = 0
	ForEach($nic in $AllNICs) {
		If ($VMNICArray -notcontains $nic.id) {
			Write-Host (" " + $nic.Name + " is not in use")	 -ForegroundColor Yellow
            $UnusedNics.Add($nic)
			#Get all PIPs in NIC
			If ($nic.IpConfigurations.PublicIPAddress.id) {
				$attachedPIPAddressSplit = $nic.IpConfigurations.PublicIPAddress.id.Split("/")
				$attachedPIP = Get-AzureRmPublicIpAddress -Name $attachedPIPAddressSplit[$attachedPIPAddressSplit.count - 1] -ResourceGroupName $attachedPIPAddressSplit[4]
				Write-Host (" " + $attachedPIP.name + " is not in use") -ForegroundColor Yellow
                $UnusedPIPs.Add($attachedPIP)
			}
        }
		Else { #Add the Subnet ID if NIC is in use
		    Write-Debug (" " + $nic.name + " is in use")
			$SubnetIDArray.Add($nic.IpConfigurations.subnet.id) > $null
        }
        $NSGToBeVerified.Add($nic.Id)
        $unsedNICCounter++
	}
    If ($unsedNICCounter -eq 0) {
        Write-Host("No Unused NIC found");
    }
}

Function GetUnusedVNets {
    Write-Host "Scanning all Virtual Networks"
	$AllVNETS = Get-AzureRMVirtualNetwork
    $unusedVNETCounter = 0
    $unusedSubnetCounter = 0
	$ResourceGroups=Get-AzureRMResourceGroup

	ForEach($resourceGroup in $ResourceGroups) {
		$NetGateways = Get-AzureRmVirtualNetworkGateway -ResourceGroupName $resourceGroup.ResourceGroupName
		ForEach($netGateway in $NetGateways) { #TODO: Take a closer look
			$subnetID=($netGateway.IpConfigurationsText | convertFrom-Json).subnet.id
			$subnetIDsplit=$subnetID.split("/")
			$comparesubnetIDtoIP=($NetGateway.name + "/" + $subnetIDsplit[4])
			If ($GatewayArray -contains  $comparesubnetIDtoIP) {
				Write-host (" Public IP address assigned to subnet (Azure Gateway) " + $netGateway.name)  -ForegroundColor Gray
				$GatewaySubnetArray.add($subnetID) >null
				WriteDebug (" found: " + $comparesubnetIDtoIP + " in GatewayArray")
			}
		}
	}

	ForEach($vnet in $AllVNETS) {
		If ($vnet.subnets.id) {
			ForEach($subnet in $vnet.subnets.id) {
				If ($SubnetIDArray -notcontains $subnet) {
					If ($GatewaySubnetArray -notcontains $subnet) {
						Write-Host (" Subnet " + $subnet.split("/")[10] + " in " + $subnet.split("/")[8] + " is not being used") -ForegroundColor Yellow
                        $unusedSubnetCounter++;
                        $subnetDetails = Get-AzureRmVirtualNetwork -ResourceGroupName $subnet.split("/")[4] -Name $subnet.split("/")[8]
                        $UnusedVnets.Add($subnetDetails)
					}
				}
			}
		}
		Else {
			Write-Host(" VNET " + $vnet.name +" does not contain any subnets")
		}
	}
    If ($unusedSubnetCounter -eq 0) {
        Write-Host("No unused subnet found")
    }
}

Function GenerateReport {
    $unusedPipHtmlFragment = $UnusedPIPs | ConvertTo-Html -As Table -Fragment -PreContent '<h2>Orphaned Public IP Addresses</h2>' | Out-String
    $unusedNicHtmlFragment = $UnusedNics | select -Property Name,Id,ResourceGroupName,Location,ResourceGuid,ProvisioningState,VirtualMachine | ConvertTo-Html -As Table -Fragment -PreContent '<h2>Orphaned Public Network Interface Cards</h2>' | Out-String
    $unusedVNetHtmlFragment = $UnusedVnets | select -Property Name,Id,ResourceGroupName,Location,ResourceGuid,ProvisioningState,AddressSpaceText | ConvertTo-Html -As Table -Fragment -PreContent '<h2>Orphaned Subnets</h2>' | Out-String
    
    ConvertTo-HTML -Head $htmlHead -PostContent $unusedPipHtmlFragment,$unusedNicHtmlFragment,$unusedVNetHtmlFragment -PreContent "<h1>Orphaned Network Resources - $($SubscriptionSelection.name)</h1>" | Out-File ".\$($SubscriptionSelection.name)_OrphanedNetworkResources.html"
    Invoke-Item ".\$($SubscriptionSelection.name)_OrphanedNetworkResources.html"
}

#Entry
Login-AzureRmAccount

If ($loginerror -ne $null)
{
    Throw {"Error: An error occured during the login process, please correct the error and try again."}
}

$SubscriptionSelection = Select-Subs
Select-AzureRmSubscription -SubscriptionName $SubscriptionSelection.Name -ErrorAction Stop
Write-Host "Scanning subscription $($SubscriptionSelection.Name) for all orphan PIPs, NICs and VNETs..." -ForegroundColor Green

GetAllActiveVMsAndProperties
GetUnusedPIPs
GetUnusedNICs
GetUnusedVNets
GenerateReport