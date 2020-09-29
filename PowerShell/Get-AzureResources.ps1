<#
----------------------Get-AzureResources--------------------------
Creation Date: 2019/05/03

---------------------------------------------------------------------
#>

<#
.SYNOPSIS
This script get all resources in an azure subscription.

.DESCRIPTION
This script get all resources in an azure subscription.
A Json files is generated on a storage blod and be ingested by splunk.

.EXAMPLE
  PS C:\> Get-AzureResources.ps1
  Launch the script
#>


Param
(
  # filename uploaded to blob storage
  [Parameter(Position=0)]
  [ValidateNotNullOrEmpty()]
  $Reportfile = 'Export-AzureResource.json',

  # Resourcegroup storageaccount
  [Parameter(Position=1)]
  [ValidateNotNullOrEmpty()]
  $RG = 'rg-dc-infra-west',

  # storageaccount name
  [Parameter(Position=2)]
  [ValidateNotNullOrEmpty()]
  $SA = 'rgdcinfrawest7730',

  # storageaccount name
  [Parameter(Position=3)]
  [ValidateNotNullOrEmpty()]
  $Container = 'splunkazuremetadata',

  # Keyindex correspond to storage account access key. Keyindex could be 0 or 1.
  [Parameter(Position=4)]
  [ValidateSet("0", "1")]
  [ValidateNotNullOrEmpty()]
  $Keyindex = 0,

  [String]$SubscriptionName = "Default Subscription Name"
)


#region ---modules---
#endregion ---modules---


#region ---Functions---
#endregion ---Functions---


#region ---variables---
#Requires -version 5
#Requires -module Az.Accounts,Az.Resources,Az.Storage
$ErrorActionPreference = 'Stop'

$TimeStamp= get-date -Format 'yyyyMMddHHmmss'
#endregion ---variables---


#region ---body---
Try {
  #region Azure connection
  # Retrieve subscription name from variable asset if not specified
  if ($SubscriptionName -eq "Default Subscription Name")
  {
    $azureSubscriptionName = Get-AutomationVariable -Name "$SubscriptionName"
  }
  else 
  {
    $azureSubscriptionName = $SubscriptionName
  }

	$azureSubscriptionID = Get-AutomationVariable -Name $azureSubscriptionName
	if ($azureSubscriptionName.length -gt 0) {
		Write-Output "Specified subscription name/ID: [$azureSubscriptionName]/$azureSubscriptionID"
	}
	else {
		throw "No subscription name was specified, and no variable asset with name 'Default Subscription Name' was found. Either specify an Azure subscription name or define the default using a variable setting"
	}

	# Retrieve ARM credential
	write-output "Specified ARM connection asset name: [$azureARMConnectionName]"
	$azureARMConnectionName = Get-AutomationVariable -Name "Default ARM Connection"
	$azureARMConnection = Get-AutomationConnection -Name $azureARMConnectionName
	if ($azureARMConnection -ne $null) {
		#AddCheckIfCertificateExists
		Write-Output "Attempting to authenticate against ARM as [$azureARMConnectionName], with AppID : $($azureARMConnection.ApplicationId)"
	}
	else {
		throw "No ARM automation credential name was specified, and no variable asset with name 'Default ARM Connection' was found. Either specify a stored credential name or define the default using a credential asset"
	}

	#Connect to environnements using ARM
	Connect-AzAccount -ServicePrincipal -TenantId $azureARMConnection.TenantId -ApplicationId $azureARMConnection.ApplicationId -CertificateThumbprint $azureARMConnection.CertificateThumbprint
	$ARMSucceededConnection = Set-AzContext -SubscriptionName $azureSubscriptionName
	if ($ARMSucceededConnection.Subscription -eq $azureSubscriptionID) {
		Write-Output "Connection with ARM failed for subscription $azureSubscriptionName. Check that name, id, service principal and certificates  are correct"
	}
	else {
		Write-Output "Connection with ARM for subscription $azureSubscriptionName successful."
	}
	#endregion Azure connection


  #region Get azure resources
  Get-AzResource  | foreach {$_ | ConvertTo-Json -Compress} | out-file -Encoding UTF8 -FilePath $($TimeStamp + '_' + $Reportfile)
  #endregion Get azure resources


  #region push result to storage account
  Select-AzSubscription XXX-XX-XXX
  $Keys = Get-AzStorageAccountKey -ResourceGroupName $rg -Name $SA
  $StorageContext = New-AzStorageContext -StorageAccountName $SA -StorageAccountKey $Keys[$Keyindex].Value
  Set-AzStorageBlobContent `
    -Context $StorageContext `
    -Container $Container `
    -File $($TimeStamp + '_' + $Reportfile) -Force
  #endregion push result to storage account


  #region Remove local file and purge Storage Account
  Remove-Item $($TimeStamp + '_' + $Reportfile) -Force
  get-AzStorageBlob -Context $StorageContext -Container $Container | Sort-Object LastModified -Descending | Select-Object  -Skip 10 | Remove-AzStorageBlob
  #endregion Remove local file and purge Storage Account
}
Catch {
  $ErrorMessage = $_.Exception.Message
  $ErrorLine = $_.InvocationInfo.ScriptLineNumber
  Write-Error "Get-ResourceResources : Error on line $ErrorLine. The error message was: $ErrorMessage"
}
#endregion ---body---