#source: https://github.com/Azure/fta-manageddisks/blob/master/azure-policies/azure-policies-for-managed-disks.md

Try {
  #create log file

  Get-AzSubscription | Out-Host

  $subscriptionIG = Read-Host "enter your subscription ID"
  Select-AzSubscription $subscriptionIG

  $policyName = "DenyUnmanagedDisks"
  $policyDescription = "This policy will deny the creation of VMs and VMSSs that do not use naged disks"

  $policyRule = '
  {
    "if": {
      "anyOf": [
        {
          "allOf": [
            {
              "field": "type",
              "equals": "Microsoft.Compute/virtualMachines"
            },
            {
              "field": "Microsoft.Compute/virtualMachines/osDisk.uri",
              "exists": "True"
            }
          ]
        },
        {
          "allOf": [
            {
              "field": "type",
              "equals": "Microsoft.Compute/VirtualMachineScaleSets"
            },
            {
              "anyOf": [
                {
                  "field": "Microsoft.Compute/VirtualMachineScaleSets/osDisk.vhdContainers",
                  "exists": "True"
                },
                {
                  "field": "Microsoft.Compute/VirtualMachineScaleSets/osdisk.imageUrl",
                  "exists": "True"
                }
              ]
            }
          ]
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }'

  New-AzureRmPolicyDefinition -Name $policyName -Description $policyDescription -Policy $policyRule

  $policyDefinition = Get-AzureRmPolicyDefinition -Name $policyName
  $sub = "/subscriptions/" + (Get-AzureRmContext).Subscription.Id
  $assignmentName = "DenyUnmanagedDisksAssignment"

  New-AzureRmPolicyAssignment -Name $assignmentName -Scope $sub -PolicyDefinition $policyDefinition -Description $policyDescription

}
Catch {
  $ErrorMessage = $_.Exception.Message
  $ErrorLine = $_.InvocationInfo.ScriptLineNumber
  Write-Error "DenyUnmanagedDisks : Error on line $ErrorLine. The error message was: $ErrorMessage" 
}







<#
-----------------------------------------------------
Version: 1.0.0.0 (X1.X2.X3.X4: X1 correspond à une montée de version significative, X2 à l'ajout d'une fonction, X3 à une correction d'anomalie, X4 à modifier les commentaires ou l'aide)
Creation Date: 
---------------------------------------------------------------------
  - Création du script
  
#>

<#
.SYNOPSIS
  
.DESCRIPTION
V1.0.0.0

.EXAMPLE
  PS C:\> .ps1
  Launch script
.INPUTS
  None
.OUTPUTS

.NOTES
  General notes
#>
