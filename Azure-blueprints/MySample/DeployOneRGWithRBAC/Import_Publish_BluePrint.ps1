Import-AzBlueprintWithArtifact -Name RG-DC-RBAC -ManagementGroupId "MG_Dovives_Root" -InputPath ".\"


# Get the blueprint we just created
$bp = Get-AzBlueprint -Name RG-DC-RBAC -ManagementGroupId "MG_Dovives_Root"
# Publish version 1.0
Publish-AzBlueprint -Blueprint $bp -Version 1.3


# Get the version of the blueprint you want to assign, which we will pas to New-AzBlueprintAssignment
$publishedBp = Get-AzBlueprint -ManagementGroupId "MG_Dovives_Root" -Name "RG-DC-RBAC" -LatestPublished

# Each resource group artifact in the blueprint will need a hashtable for the actual RG name and location
$rgHash = @{ name="RG-DC-GEM"}

# all other (non-rg) parameters are listed in a single hashtable, with a key/value pair for each parameter
$parameters = @{
    RGOwners="26ed65c4-5a3c-4a1d-a99d-256f26e8bf7a"
    costCenter="DSI"
    blueprintAllowedLocations=@("northeurope","westeurope")
    blueprintAllowedResourceTypes=@("Microsoft.Compute","Microsoft.Network")
    genericBlueprintParameter="test"
}

# All of the resource group artifact hashtables are themselves grouped into a parent hashtable
# the 'key' for each item in the table should match the RG placeholder name in the blueprint
$rgArray = @{ "DC-RG-Name" = $rgHash }

# Assign the new blueprint to the specified subscription (Assignment updates should use Set-AzBlueprintAssignment
New-AzBlueprintAssignment -Name "GEM-DEMO" -Blueprint $publishedBp -Location 'West Europe' -SubscriptionId "1619bfac-1484-4da0-95cc-dec25338e962" -ResourceGroupParameter $rgArray -Parameter $parameters