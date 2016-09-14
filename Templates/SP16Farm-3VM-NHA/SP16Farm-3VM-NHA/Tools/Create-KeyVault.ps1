#Requires -Module AzureRM.Profile
#Requires -Module AzureRM.KeyVault

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'dvsspfarm-pla',
    [string] $VaultName = "dvsspfarmplavlt"
)

New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -EnabledForTemplateDeployment