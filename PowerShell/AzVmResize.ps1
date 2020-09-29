#Region help
<#
.SYNOPSIS
  This script resizes Azure VM.

.DESCRIPTION
  The mew VM size is defined by a CSV correlation table provided in parameters.
  A check is performed to validate that the new Azure VM size is available.

.PARAMETER FilePath
  Path of the CSV file correlation table containing the following format : 
    <old size>,<new size>
    <old size2>,<new size2>
    <old size3>,<new size3>

.PARAMETER SubscriptionName
  Specify the Azure Subscription

.PARAMETER ResourceGroupName
  Specify the Azure target Azure Resource Group
  wildcard (*) accepted.

.PARAMETER VirtualMachineName
  Specify a Azure VM name
  wildcard (*) accepted.

.PARAMETER Yes
  Disable all confirmations by using implicit "Yes" to questions

.PARAMETER v
  Activate Debug/Verbose Mode for more informations

.PARAMETER Cold
  Force "cold" resize of the VM (stop-resize-start)

.EXAMPLE
  PS C:\> AzVmResize.ps1 -SubscriptionName "DEV" -FilePath .\input.csv

#>
#endRegion help


#Region parameters
########################################################
#    PARAMETERS
########################################################

Param(
  [ValidateScript({
    if( -Not ($_ | Test-Path -PathType Leaf) ){
      throw "The file specified in the path argument does not exist"
    }
    if($_ -notmatch "(\.csv)"){
      throw "The file specified in the path argument must be either of type CSV"
    }
    return $true
  })]$FilePath = "$global:PSScriptRoot\input.csv",
  
  [Parameter(Mandatory=$false)][string]$LogFile,

  [string]$SubscriptionName = "MSDN Visual Studio Professional",

  [Parameter(Mandatory=$false)][string]$ResourceGroupName,

  [Parameter(Mandatory=$false)][string]$VirtualMachineName,

  [Parameter(Mandatory=$false, HelpMessage = 'Disable confirmation')][switch]$Yes,

  [Parameter(Mandatory=$false, HelpMessage = 'Debug Mode')][switch]$v,

  [Parameter(Mandatory=$false)][switch]$Cold
)
#endRegion parameters
Write-Host $LogFile

#Region Variables
########################################################
#    VARIABLES
########################################################

$outputtable = @()
if([string]::IsNullOrEmpty($LogFile))
{
  $script:LogFile = "$PSScriptRoot\output_$(get-date -Format 'dd-MM-yyyy').log"
}
#endRegion Variables

#Region functions
########################################################
#    FUNCTIONS
########################################################

# LOGGER function for a fancy output ;)
function LOGGER
{
  param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("DEBUG", "debug", "INFO", "info", "WARN", "warn", "ERROR", "error", "FATAL", "fatal")]
    [string] $Level,
    [Parameter(Mandatory=$true)][string] $Msg,
    [Parameter(Mandatory=$false)][switch] $Exit
  )
  $DATE=(get-date -Format "[dd-MM-yyyy][HH:mm:ss]")
  
  if([string]::IsNullOrEmpty($script:LogFile))
  {
    $script:LogFile = "$PSScriptRoot\output_$(get-date -Format 'dd-MM-yyyy').log"
  }

  switch ( $Level.ToUpper() )
  {
    "DEBUG" { $txtcolor = 'green'    }
    "INFO" { $txtcolor = 'blue'    }
    "WARN" { $txtcolor = 'yellow'   }
    "ERROR" { $txtcolor = 'red' }
    "FATAL" { $txtcolor = 'red' ; $Exit=$true  }
    default { throw "ERROR : Level incorrect [$Level] for LOGGER function !"   }
  }

  if (($($Level.ToUpper()) -eq "FATAL") -or ($($Level.ToUpper()) -eq "DEBUG"))
  {
    if (($($Level.ToUpper()) -eq "DEBUG") -and ($script:v -eq $false)){Out-Null}
    else
    {
      Write-Output "$DATE[$($Level.ToUpper().PadRight(5))] $Msg" | Tee-Object -FilePath $LogFile -Append | Out-Null 
      Write-Host -f $txtcolor "$DATE[$($Level.ToUpper().PadRight(5))] $Msg"
    }
  }
  else
  {
    Write-Output "$DATE[$($Level.ToUpper().PadRight(5))] $Msg" | Tee-Object -FilePath $LogFile -Append | Out-Null 
    Write-host "$DATE[" -NoNewline
    Write-Host  -f $txtcolor "$($Level.ToUpper().PadRight(5))" -NoNewline
    Write-Host "] $Msg"
  }
  
  if ($Exit) {break}

}

# Validate if the selected size is currently available for the VM
function CheckAvailableVMSize([string] $VmName, [string] $RGName, [string] $NewVmSize)
{
  try
  {
    $VM = get-azvm -name $VmName -ResourceGroupName $RGName
  }
  catch
  {
    LOGGER -Level ERROR -Msg "$($_.Exception.Message)"
    LOGGER -Level FATAL -Msg "$($VM.Name) : Impossible to retrieve infos for VM"
  }
  LOGGER -Level INFO -Msg "$($VM.Name) : Checking if the wanted size [$NewVmSize] is available"
  if ($NewVmSize -in (Get-AzVMSize -ResourceGroupName $VM.ResourceGroupName -VMName $VM.Name).Name)
  {
    LOGGER -Level INFO -Msg "$($VM.Name) : $NewVmSize is available"
  }
  else
  {
    LOGGER -Level FATAL -Msg "$($VM.Name) : $NewVmSize is not available"
  }
}

# resize function
function ResizeVM
{
  param(
    [Parameter(Mandatory=$true)][string] $VmName,
    [Parameter(Mandatory=$true)][string] $RGName,
    [Parameter(Mandatory=$false)][switch] $Cold
  )
  $vmobject = New-Object -TypeName PSObject
  $vmobject |Add-Member -Name 'Name' -MemberType Noteproperty -Value "$VmName"
  $vmobject |Add-Member -Name 'ResourceGroupName' -MemberType Noteproperty -Value "$RGName"
  $ResizeStatus = "NOK !"
  
  # retrieve the current size
  try
  {
    $VM = get-azvm -name $VmName -ResourceGroupName $RGName
    $OldVmSize = $VM.HardwareProfile.VmSize
  }
  catch
  {
    LOGGER -Level ERROR -Msg "$($_.Exception.Message)"
    LOGGER -Level FATAL -Msg "$($VM.Name) : Impossible to get VM size."
  }
  $vmobject |Add-Member -Name 'OldVMSize' -MemberType Noteproperty -Value "$OldVmSize"

  # parse the csv file looking for the new size according to the current size
  $csvContent = Import-Csv $FilePath -Header OLD,NEW -Delimiter "," | where-object OLD -eq $OldVmSize | Foreach-Object{
    LOGGER -Level DEBUG -Msg "$($VM.Name) : OLD : $($_.OLD) - NEW : $($_.NEW)"
    $NewVmSize = $($_.NEW)
  }
  $vmobject |Add-Member -Name 'NewVMSize' -MemberType Noteproperty -Value "$NewVmSize"
  $vmobject |Add-Member -Name 'Location' -MemberType Noteproperty -Value "$($VM.Location)"
  if ([string]::IsNullOrEmpty($NewVmSize))
  {
    LOGGER -Level ERROR -Msg "$($VM.Name) : $($OldVmSize) is not defined in $($FilePath). Skipping ..."
    $vmobject |Add-Member -Name 'ResizeStatus' -MemberType Noteproperty -Value "$($ResizeStatus)"
    $script:outputtable += $vmobject
    return
  }

  CheckAvailableVMSize -VmName $($VM.Name) -NewVmSize $NewVmSize -RGName $RGName
  LOGGER -Level DEBUG -Msg "$($VM.Name) : Cold Resize ? $Cold"
  LOGGER -Level DEBUG -Msg "$($VM.Name) : old size [$OldVmSize]"

  if ($NewVmSize -ne $OldVmSize)
  {
    # if Cold resize : stop the VM first
    if ($Cold)
    {
      LOGGER -Level WARN -Msg "$($VM.Name) : COLD MODE ON - Stopping VM..."
      try {
        Stop-AzVM -ResourceGroupName $RGName -Name $VmName -Force  | Out-Null
      } catch {
        $vmobject |Add-Member -Name 'ResizeStatus' -MemberType Noteproperty -Value "$($ResizeStatus)"
        $script:outputtable += $vmobject
        LOGGER -Level FATAL -Msg "$($VM.Name) : Impossible to stop the VM."
      }
    }
    
    # set the new VM size
    LOGGER -Level INFO -Msg "$($VM.Name) : resizing to [$NewVmSize]..."
    $VM.HardwareProfile.VmSize = $NewVmSize
    try {
      Update-AzVM -VM $VM -ResourceGroupName $RGName -Confirm:$false | Out-Null
    } catch {
      # rollback to the old size if failed 
      LOGGER -Level ERROR -Msg "$($_.Exception.Message)"
      LOGGER -Level ERROR -Msg "$($VM.Name) : Impossible to resize to [$NewVmSize]. Rollback in progress"
      $VM.HardwareProfile.VmSize = $OldVmSize
      Update-AzVM -VM $VM -ResourceGroupName $RGName -Confirm:$false | Out-Null
      $vmobject |Add-Member -Name 'ResizeStatus' -MemberType Noteproperty -Value "$($ResizeStatus)"
      $script:outputtable += $vmobject
      LOGGER -Level FATAL -Msg "$($VM.Name) : Impossible to resize to [$NewVmSize]. Rollback finished"
    }
    LOGGER -Level DEBUG -Msg "$($VM.Name) : new size [$($VM.HardwareProfile.VmSize)]"
    
    # if Cold resize : start the VM at last
    if ($Cold)
    {
      LOGGER -Level WARN -Msg "$($VM.Name) : COLD MODE ON - Starting VM..."
      try {
        Start-AzVM -ResourceGroupName $RGName -Name $VmName  | Out-Null
      } catch {
        $vmobject |Add-Member -Name 'ResizeStatus' -MemberType Noteproperty -Value "$($ResizeStatus)"
        $script:outputtable += $vmobject
        LOGGER -Level FATAL -Msg "$($VM.Name) : Impossible to start the VM."
      }
    }
  }
  else {
    LOGGER -Level ERROR -Msg "$($VM.Name) : already at good size [$OldVmSize] = [$NewVmSize]. Skipping ..."
  }
  $ResizeStatus = "OK"
  $vmobject |Add-Member -Name 'ResizeStatus' -MemberType Noteproperty -Value "$($ResizeStatus)"
  $script:outputtable += $vmobject
}
#endRegion functions


#Region main
########################################################
#    MAIN
########################################################

LOGGER -Level DEBUG -Msg "Debug Mode [ON]"
LOGGER -Level INFO -Msg "Selecting subscribtion [$SubscriptionName]"
try {
  Set-AzContext -subscription $SubscriptionName  | Out-Null
  
} catch {
  LOGGER -Level FATAL -Msg "Impossible to select the Azure Subscription [$SubscriptionName]."
}

# set filters if ResourceGroupName and/or VirtualMachineName are provided
$filters = @{}
if (-Not([string]::IsNullOrEmpty($ResourceGroupName)))
{
  $filters.add("ResourceGroupName",$ResourceGroupName)
}
if (-Not([string]::IsNullOrEmpty($VirtualMachineName)))
{
  $filters.add("Name",$VirtualMachineName)
}

# list impacted VMs (using the previous filters)
$RES=(Get-AzVM @filters | Select Name,ResourceGroupName,@{n='HardwareProfile.VmSize';e={$_.HardwareProfile.VmSize}},Location)
LOGGER -Level INFO -Msg "===================== [IMPACTED VMs] ====================="
$RES | ft | Tee-Object -FilePath $LogFile -Append
LOGGER -Level INFO -Msg "=========================================================="
LOGGER -Level WARN -Msg "Resizing a VM will cause a reboot."
LOGGER -Level WARN -Msg "Are you sure you want to proceed (yes/[no]) ? "
if ($Yes -eq $False) {
  $confirmation = Read-Host
  if ($confirmation -ne 'yes') {
    LOGGER -Level FATAL -Msg "Cancelled by the user. Exiting..."
  }
  else
  {
    LOGGER -Level INFO -Msg "Force Mode : yes"
  }
}
else
{
  LOGGER -Level DEBUG -Msg "'Yes' mode ON : Skipping confirmation..."
}

# resize selected VMs
for ($vmindex = 0; $vmindex -lt $RES.Length; $vmindex++) {
  $index=($vmindex + 1 )
  LOGGER -Level INFO -Msg "===================== $index / $($RES.Length) : $($RES[$vmindex].Name) ====================="
  if ($Cold){
    ResizeVM -VmName $RES[$vmindex].Name -RGName $RES[$vmindex].ResourceGroupName -Cold
  }
  else {
    ResizeVM -VmName $RES[$vmindex].Name -RGName $RES[$vmindex].ResourceGroupName
  }
}

# output a summary result
LOGGER -Level INFO -Msg "===================== [RESULTS] ====================="
$outputtable | ft | Tee-Object -FilePath $LogFile -Append
LOGGER -Level INFO -Msg "===================================================="
#endRegion main