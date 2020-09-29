

$GroupType = @(
    'CONTRIBUTOR',
    'OWNER',
    'READER'
)


$AzADGroup = Get-AzADGroup

foreach ($type in $GroupType)
{
    foreach ($ADgroup in ($AzADGroup | where {$_.DisplayName -like "*-RG-$type"}))
    {
        
        foreach ($rg in (Get-AzResourceGroup "$('RG-DC-'+($ADgroup.DisplayName -split '-DC-')[-1].replace("-RG-$type",''))*"))
        {           
            if ($ADgroup.DisplayName -notin (Get-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName).DisplayName)
            {
                New-AzRoleAssignment -ResourceGroupName $rg.ResourceGroupName -ObjectId $ADgroup.Id -RoleDefinitionName $type
            }
        }
    }
}


