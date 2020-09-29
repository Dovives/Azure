#Region help

<#
----------------------Get-AzureRGAndOwners--------------------------
Creation Date: 2019/06/20

product by: Cloud Solution Architects (Patrice Manach & Dominique VIVES)
---------------------------------------------------------------------
#>

<#
.SYNOPSIS
  This script deletes empty Rresource Groups in an Azure subscription.

.DESCRIPTION
  The subscription name is given in parameter. If that parameter if not explicitly set, the script will 
  fail as it would work on the active subscrition.
  Then, for each RG, a basic test is performed on its name. If that parameter is not set, all empty RGs will be deleted.

.PARAMETER SubscriptionName
  Specify the Azure Subscription

.PARAMETER ResourceGroupNameFilter
  Specify the filter for the Azure Resource Groups name.
  Test is performed only on the prefix of the name.

.PARAMETER Force
  Force deletion if set

.EXAMPLE
  PS C:\> DeleteEmptyRGs.ps1 -SubscriptionName "DEV" -Filer "RH-"

#>
#endRegion help

#Region parameters
########################################################
#    PARAMETERS
########################################################

Param(
  [Parameter(Mandatory=$true)][string]$SubscriptionName,

  [Parameter(Mandatory=$false)][string]$ResourceGroupNameFilter="RG-",

  [Parameter(Mandatory=$false, HelpMessage = 'Force deletion')][switch]$Force
)
#endRegion parameters

#Region debug
########################################################
#    DEBUG
#	 Used when manually debugging the script
########################################################

#Import-Module AzureRM
#Connect-AzureRmAccount
#Get-AzureRmSubscription

#Get-AzureRmSubscription -SubscriptionId "xxxxxx-xxxxxxxxx-xxxxxxxxxxx"

#endRegion debug


#Region main
########################################################
#    MAIN
########################################################

try 
{
    Select-AzureRmSubscription -SubscriptionName $SubscriptionName  | Out-Null 
} 
catch 
{
    Write-Output "Impossible to select the Azure Subscription [$SubscriptionName]."
}

$SubscriptionId = (Get-AzureRmSubscription -SubscriptionName $SubscriptionName).SubscriptionId

Write-Output "Connected to Subscription: [$SubscriptionName] with ID [$SubscriptionId]."

$resourceGroups = Get-AzureRmResourceGroup

$rglist = @()
$scope = "/subscriptions/"+$SubscriptionId        


foreach($resourceGroup in $resourceGroups)
{
    if($resourceGroup.ResourceGroupName.StartsWith($ResourceGroupNameFilter))
    {
        Write-Output "Parsing RG: [$($resourceGroup.ResourceGroupName)]."

        #Get-AzureRmResource is avaialable in my module version 
        $resources = Get-AzureRmResource -ResourceGroupName $resourceGroup.ResourceGroupName
        if($resources.Count -eq 0)
        {
                "Empty Resource group " + $resourceGroup.ResourceGroupName
                #Use the $force switch to really delete the RG - otherwise it only list the empty RG 
                
                foreach($rgowner in (Get-AzureRmRoleAssignment -ResourceGroupName $($resourceGroup.ResourceGroupName) | ? {($_.RoleDefinitionName -eq "Owner") -and ($_.ObjectType -eq "User")})){  
                  $PSObject = [PSCustomObject]@{
                    ResourceGroupName = $resourceGroup.ResourceGroupName
                    OwnerDisplayName = $rgowner.DisplayName
                    OwnerSignInName = $rgowner.SignInName
                    Inherited  = $false           
                    }
                  #check if user perm has been inherited from subscription.   
                  if($rgowner.Scope -eq $scope){$PSObject.Inherited = $true}

                  $rglist += $PSObject
                }
                if($Force)
                {
                  $r = Remove-AzureRmResourceGroup -Name $resourceGroup.ResourceGroupName -Force
                  "`t $($resourceGroup.ResourceGroupName) has been deleted"
                }
        }
    }
}
if($rglist) { $rglist | Export-Csv -Delimiter ';' -Encoding UTF8 -NoTypeInformation -Path '.\rgListToDelete.csv'}


#endRegion main