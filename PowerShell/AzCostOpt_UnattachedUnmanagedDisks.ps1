#############################################################################
#                                     			 		                    #
#   This script scans a given subscription for unattached unamanged disks.  #
#                                     			 		                    #
#   Version 1.0                              			 	                #
#   Last Revision Date: 18 Feb 2018                                         #
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



Write-Host "Scanning subscription $($SubscriptionSelection.Name) for all unattached unmanaged disks..." -ForegroundColor Green

$storageAccounts = Get-AzureRmStorageAccount

Write-Host "Total number of storage accounts : " $storageAccounts.Count

WorkFlow ScanUnmanagedDisks {
param([string] $subscriptionName, [System.Object[]] $storageAccounts)


$UnmanagedDisks=@{}

foreach -parallel ($storageAccount in $storageAccounts){

    $storageKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName)[0].Value
    $storageAccountName = $storageAccount.StorageAccountName 
    $skuName = $storageAccount.Sku.Name
    $skuTier = $storageAccount.Sku.Tier

    $WORKFLOW:UnmanagedDisks += InlineScript {
    $UnmanagedDisksInternal=@{}

    $context = New-AzureStorageContext -StorageAccountName $using:storageAccountName -StorageAccountKey $using:storageKey
   
    $StorageAccountContainerLoopCount = 0

    $containers = Get-AzureStorageContainer -Context $context

    foreach($container in $containers){

        $StorageAccountContainerLoopCount++
        $StorageAccountContainerPercentComplete = $StorageAccountContainerLoopCount/$containers.Count*100
        Write-Progress -Activity "StorageAccount Container Progress ($($StorageAccountContainerLoopCount)/$($containers.Count)):" -Status "StorageAccount Container: $($container.Name)" -PercentComplete $StorageAccountContainerPercentComplete -Id 2 -ParentId 1
       
        
        $blobs = Get-AzureStorageBlob -Container $container.Name -Context $context

        #Fetch all the Page blobs with extension .vhd as only Page blobs can be attached as disk to Azure VMs
        $blobs | Where-Object {$_.BlobType -eq 'PageBlob' -and $_.Name.EndsWith('.vhd')} | ForEach-Object { 

            #If a Page blob is not attached as disk then LeaseStatus will be unlocked
            if($_.ICloudBlob.Properties.LeaseStatus -eq 'Unlocked'){

                        $UnmanagedDisksInternal."$($_.Name)" = [PSCustomObject]@{Container = $container.Name
                                          StorageAccount = $using:storageAccountName 
                                          VMName = '' 
                                          vhd = $_.Name
                                          'Size(GB)' = [Math]::Round($_.Length/1GB,0)
                                          SkuName = $($using:skuName)
                                          SkuTier = $($using:skuTier)
                                          Uri = $_.ICloudBlob.Uri.AbsoluteUri
                                          LastModified = $_.LastModified.ToString()}
                       
                  

            }

            }

        }
        return $UnmanagedDisksInternal

        }
        }
  
InlineScript {
  $CSS = @"
<Title> Unused Unmanaged Disks :$(Get-Date -Format 'dd MMMM yyyy' )</Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	border-top: 1px solid #C1DAD7;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #6D929B;
}
</Style>
"@

($using:UnmanagedDisks.Keys | %{($using:UnmanagedDisks).$_ } | Sort-Object -Property VMName,LastModified | `
Select @{Name='VMName';E={IF ($_.VMName -eq ''){'Not Attached'}Else{$_.VMName}}},StorageAccount,Container,vhd,Size*,SkuName,SkuTier,Uri,LastModified |`
ConvertTo-Html -Body "<H2> $($using:subscriptionName) - Unused Unmanaged Disk Resources Report - $(Get-Date -Format 'dd MMMM yyyy' )</H2>" -Head $CSS ).replace('Not Attached','<font color=red>Not Attached</font>').replace('Premium','<font color=black><b>Premium</b></font>')| Out-File ".\$($using:subscriptionName)_UnusedUnmanagedDisks.html"

Invoke-Item ".\$($using:subscriptionName)_UnusedUnmanagedDisks.html"
}
}

ScanUnmanagedDisks -subscriptionName $SubscriptionSelection.Name -storageAccounts $storageAccounts


