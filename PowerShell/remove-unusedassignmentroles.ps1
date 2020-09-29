
Login-AzAccount

foreach ($ObjectId in  (Get-AzRoleAssignment | group ObjectId | ? Count -gt 1))
{
    $User_name = $ObjectId.group.DisplayName | sort -Unique
    foreach ($scope in ($ObjectId.Group | group Scope | ? Count -gt 1 ))
    {
        $scope_name = $rolelist = $listremove = $null
        $scope_name = $scope.group.Scope | sort -Unique
        $rolelist  = $scope.Group.RoleDefinitionName
        

        if ('Owner' -in $rolelist)
        {
            foreach ($RoleAssignment in $($scope.Group.where{$_.RoleDefinitionName -ne 'Owner'}))
            {
                Remove-AzRoleAssignment -InputObject $RoleAssignment
            }
            
            $listremove = $scope.Group.where{$_.RoleDefinitionName -ne 'Owner'}.RoleDefinitionName
        }
     


        $result = [PSCustomObject]@{
            User           = $User_name
            scope          = $scope_name
            existingrole   = $rolelist
            toremoverole   = $listremove
        }
        $result
        

    }
}

