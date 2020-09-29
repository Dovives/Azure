#Region help

<#
----------------------Get-AzureRGAndOwners--------------------------
Creation Date: 2019/06/20

product by: Cloud Solution Architect (Dominique VIVES)
---------------------------------------------------------------------
#>

<#
.SYNOPSIS
This script get all existing RG and their owners.

.DESCRIPTION
This script get all existing RG in an azure subscription with their owners.
A CSV file is generated for mailing purpose. 

.PARAMETER SubscriptionName
  Specify the Azure Subscription

.PARAMETER ResourceGroupNameFilter
  Specify the filter for the Azure Resource Groups name.
  Test is performed only on the prefix of the name.

.PARAMETER Force
  Force deletion if set

.EXAMPLE
  PS C:\> Get-azureRgOwnersToCsv.ps1 -SubscriptionName "GEM-IS-DEV" -ResourceGroupNameFilter "RG-"
  Launch the script on the DEV Subscription for exisint RG starting with "RG-"
#>
#endRegion help


#Region parameters
Param(
  [Parameter(Mandatory=$true)][string]$SubscriptionName

#   [Parameter(Mandatory=$false)][string]$ResourceGroupNameFilter="RG-",

#   [Parameter(Mandatory=$false, HelpMessage = 'Force deletion')][switch]$Force
)
#endRegion parameters



#Region main
try 
{
    Select-AzSubscription -SubscriptionName $SubscriptionName  | Out-Null 
} 
catch 
{
    Write-Output "Impossible to select the Azure Subscription [$SubscriptionName]."
}

$SubscriptionId = (Get-AzSubscription -SubscriptionName $SubscriptionName).SubscriptionId

Write-Output "Connected to Subscription: [$SubscriptionName] with ID [$SubscriptionId]."

$asps = Get-AzAppServicePlan 

$asplist = @()
$scope = "/subscriptions/"+$SubscriptionId        


foreach($asp in $asps)
{
    if($asp.HostingEnvironmentProfile.name -eq "gemcommonase")
    {

        Write-Output "Parsing RG: [$($asp.Name)]."

        #Get-AzureRmResource is avaialable in my module version 
        foreach($rgowner in (Get-AzRoleAssignment -ResourceGroupName $($asp.ResourceGroup) | ? {($_.RoleDefinitionName -eq "Owner") -and (($_.ObjectType -eq "User") -or ($_.ObjectType -eq "Group"))})){  
            $PSObject = [PSCustomObject]@{
                AppServicePlan = $asp.Name
                ResourceGroupName = $asp.ResourceGroup
                OwnerDisplayName = $rgowner.DisplayName
                OwnerSignInName = $rgowner.SignInName
                Inherited  = $false           
            }
            if($rgowner.Scope -eq $scope){$PSObject.Inherited = $true}
            $asplist += $PSObject
        }     
    }
}
if($asplist) { $asplist | Export-Csv -Delimiter ';' -Encoding UTF8 -NoTypeInformation -Path '.\ASPListWithOwner.csv'}

#endRegion main