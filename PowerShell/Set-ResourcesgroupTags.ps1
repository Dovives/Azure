<#
-------------------------Set-ResourcesgroupTags----------------------------
Creation Date: 2018/04/12
---------------------------------------------------------------------  
#>

<#
.SYNOPSIS
  
.DESCRIPTION


.EXAMPLE
  PS C:\> Set-ResourcesgroupTags.ps1
  Launch script
.INPUTS
  None
.OUTPUTS

.NOTES
  General notes
#>


[CmdletBinding()]
Param
(
  # CSV file containing RG tags
  [Parameter(Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true, 
        Position=0)]
  [ValidateNotNullOrEmpty()]
  $CSVfile,
  [switch]$force
)


#region ---modules---
#endregion ---modules---


#region ---Functions---
#endregion ---Functions---


#region ---variables---
#Requires -version 5
#Requires -module Az
$ErrorActionPreference = 'Stop'

$date = get-date -format "yyyyMMddHHmm"

[String]$Log_file = "$PSScriptRoot\logs\$date`_Set-ResourcesgroupTags.log"
#endregion ---variables---


#region ---body---
Try {
    #create log file
    [void](New-Item $Log_file -ItemType "file" -Force)
    
    $csv = import-csv $CSVfile
    
    foreach ($item in $csv) 
    {
        $RG = Get-AzureRmResourceGroup -Name $item.ResourceGroupName -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrEmpty($RG))
        {
            if ($null -eq $RG.tags)
            {
                $tags = @{}
                $($item | Select-Object * -ExcludeProperty ResourceGroupName).psobject.properties | ForEach-Object { $tags[$_.Name] = $_.Value }
                Set-AzureRmResourceGroup -Name $RG.ResourceGroupName -Tag $tags
            }
            else
            {
                $tags = $RG.tags
                $setvalue = $false
                foreach ($Property in ($item| Select-Object * -ExcludeProperty ResourceGroupName | Get-Member -MemberType NoteProperty).name)
                {
                    if ( [string]::IsNullOrEmpty($tags.$Property) -and ($tags.$Property -ne $item.$Property))
                    {
                        $tags.$Property = $item.$Property
                        $setvalue = $true
                    }
                    else {
                        if ($force -and ($tags.$Property -ne $item.$Property))
                        {
                            $tags.$Property = $item.$Property
                            $setvalue = $true
                        }
                        else {
                            Write-Output "Resource Group $($item.ResourceGroupName) have a tag with an existing value on property $Property" | Tee-Object -Append $Log_file | Write-Warning
                        }
                    }
                }
                if ($setvalue) 
                {
                    Set-AzureRmResourceGroup -Tag $tags -Name $RG.ResourceGroupName
                }
            }
        }
        else {
            Write-Output "Resource Group $($item.ResourceGroupName) not found" | Tee-Object -Append $Log_file | Write-Error
        }
    }
}
Catch {
  $ErrorMessage = $_.Exception.Message
  $ErrorLine = $_.InvocationInfo.ScriptLineNumber
  Write-Output "Set-ResourcesgroupTags : Error on line $ErrorLine. The error message was: $ErrorMessage" | Tee-Object -Append $Log_file | Write-Error
}
finally {
  Get-ChildItem *.log -Path "$PSScriptRoot\logs" | Sort-Object CreationTime | Select-Object  -Skip 10 | Remove-Item
}
#endregion ---body---