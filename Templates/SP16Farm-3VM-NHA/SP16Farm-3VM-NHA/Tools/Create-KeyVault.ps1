#Requires -Module AzureRM.Profile
#Requires -Module AzureRM.KeyVault

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'dvsspseize',
    [string] $VaultName = "dvsspseizevault"
)

New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -EnabledForTemplateDeployment