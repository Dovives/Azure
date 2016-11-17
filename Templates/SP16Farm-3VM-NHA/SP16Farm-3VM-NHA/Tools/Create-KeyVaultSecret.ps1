#Requires -Module AzureRM.Profile
#Requires -Module AzureRM.KeyVault

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'dvsspfarm-pla',
    [string] $VaultName = "dvsspfarmplavlt",
    [string] $SecretKey = "spsetup",
    [string] $SecretValue = ""
)

$vault = Get-AzureRmKeyVault -VaultName $VaultName
$pass = ConvertTo-SecureString $SecretValue -AsPlainText -Force

if ($vault -ne $null)
{
    $secret = Set-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretKey -SecretValue $pass 
}