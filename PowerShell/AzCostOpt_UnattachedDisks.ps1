#############################################################################
#                                     			 		                    #
#   This script scans a given subscription for unattached disks.            #
#                                     			 		                    #
#   Version 1.0                              			 	                #
#   Last Revision Date: 13 Feb 2018                                         #
#   Author: Gajendra Barachha (gabarach)                      	            #
#                                     			 		                    #
#############################################################################

#Requires -version 5
#Requires -module AzureRM.Profile, AzureRM.Compute, AzureRM.Storage

Login-AzureRmAccount -ErrorVariable loginerror

If ($loginerror -ne $null)
{
   Throw {"Error: An error occured during the login process, please correct the error and try again."}
}

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
$SubscriptionSelection = Select-Subs
Select-AzureRmSubscription -SubscriptionName $SubscriptionSelection.Name -ErrorAction Stop


Write-Host "Scanning subscription $($SubscriptionSelection.Name) for all unattached managed disks..." -ForegroundColor Green

$ManagedDisks=@()
Get-AzureRmDisk | Where-Object {$_.ManagedBy -eq $Null } | ForEach-Object {
$ManagedDisks+= [PSCustomObject]@{ResourceGroupName = $_.ResourceGroupName
                                    Name = $_.Name
                                    DiskSizeGB = $_.DiskSizeGB
                                    SkuName = $_.Sku.Name
                                    SkuTier = $_.Sku.Tier
                                    Id = $_.Id
                                    }
                       
                  

            }

$ManagedDisksHtml = $ManagedDisks | select -Property "ResourceGroupName","Name","DiskSizeGB","SkuName", "SkuTier","Id" | ConvertTo-Html -Fragment

Write-Host "Preparing report..." -ForegroundColor Green


$HTML = ConvertTo-Html -Body "<H2> $($SubscriptionSelection.Name) - Unused Managed Disk Resources Report - $(Get-Date -Format 'dd MMMM yyyy' )</H2>", "$ManagedDisksHtml" -Head "<style> body {background-color: lightblue; } table {background-color: white; margin 5px; float: left; top: 0px; display: inline-block; padding: 5px; border: 1px solid black} tr:nth-child(odd) {background-color: lightgray} </style>"

$HTML | Out-File ".\$($SubscriptionSelection.Name)_UnusedManagedDisks.html"

Invoke-Item ".\$($SubscriptionSelection.Name)_UnusedManagedDisks.html"


