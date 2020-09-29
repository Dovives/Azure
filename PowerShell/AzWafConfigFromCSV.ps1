PARAM
(
$WAFName = 'xxxx',
$WafRG ='xxxxx',
$csv = 'Waf-Configuration.csv',
[switch]$forcecleanup,
[ValidateSet('AppGwSslPolicy20150501','AppGwSslPolicy20170401','AppGwSslPolicy20170401S')][String]$SSLPolicyName = "AppGwSslPolicy20170401S"

)


Start-Transcript -Path .\log.txt

#Folder with certificates and scripts
$path = Split-Path -Parent $PSCommandPath

$WAFconfig = import-csv -Path "$path\$csv" -Delimiter ";"

#Get the WAF
$Waf = Get-AzureRmApplicationGateway -Name $WAFName -ResourceGroupName $WafRG

#SSLPolicy
$waf = Set-AzureRmApplicationGatewaySslPolicy -ApplicationGateway $waf -PolicyType Predefined -PolicyName $SSLPolicyName


#region CleanUp Waf Config

if ($forcecleanup)
{
    
    # FrontEndPort
    $y = $waf.FrontendPorts.count
    for($i = $y; $i -gt 0; $i--)
    {
       $waf = Remove-AzureRmApplicationGatewayFrontendPort -Name $waf.FrontendPorts[$i-1].Name -ApplicationGateway $Waf  
    }
    

    #HttpListener
    $y = $waf.HttpListeners.count
    for ($i = $y; $i -gt 0; $i--)
    {
       $Waf = Remove-AzureRmApplicationGatewayHttpListener -ApplicationGateway $Waf -Name $waf.HttpListeners[$i-1].Name
    }

    #Backendhttpsetting
    $y = $waf.BackendHttpSettingsCollection.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $Waf = Remove-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $Waf -Name $waf.BackendHttpSettingsCollection[$i-1].Name
    }

    #Rules
    $y = $waf.RequestRoutingRules.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $Waf = remove-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $Waf -Name $waf.RequestRoutingRules[$i-1].name
    }

    #Probe
    $y = $waf.probes.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $waf = Remove-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $waf -Name $waf.probes[$i-1].name
    }

    #BackendAddressPools
    $y = $waf.BackendAddressPools.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $waf = Remove-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $waf -Name $waf.BackendAddressPools[$i-1].name
    }

    #Certificate
    $y = $Waf.SslCertificates.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $waf = Remove-AzureRmApplicationGatewaySslCertificate -ApplicationGateway $waf -Name $waf.SslCertificates[$i-1].name
    }

    #Certificate
    $y = $Waf.AuthenticationCertificates.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $waf = Remove-AzureRmApplicationGatewayAuthenticationCertificate -ApplicationGateway $waf -Name $waf.AuthenticationCertificates[$i-1].name 
    }

    #urlpathmap
    $y = $waf.UrlPathMaps.count
    for ($i = $y; $i -gt 0; $i--)
    {
        $waf = Remove-AzureRmApplicationGatewayUrlPathMapConfig -ApplicationGateway $waf -Name $waf.UrlPathMaps[$i-1].name 
    }
}

#endregion

#region Commun
$FrontEndPortSSLName = "AppGatewayFrontEndPortSSL"
$porthttps = 443
$FrontendPort = $waf.FrontendPorts | where name -eq $FrontEndPortSSLName
if (!$FrontendPort)
{
    $Waf = Add-AzureRmApplicationGatewayFrontendPort -Name $FrontEndPortSSLName -ApplicationGateway $Waf -Port $porthttps
    $FrontendPort = $waf.FrontendPorts | where name -eq $FrontEndPortSSLName
}

foreach ($item in $WAFconfig)
{
    
#Pool
$BackendPoolName = $item.BackendName
$BackendPool =  $waf.BackendAddressPools | where Name -eq $BackendPoolName
if (!$BackendPool)
{
    $BackendPoolIPAddress = $item.BackendIP
    $waf = Add-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $waf -Name $BackendPoolName -BackendIPAddresses $BackendPoolIPAddress
    $BackendPool =  $waf.BackendAddressPools | where Name -eq $BackendPoolName
}
 

$Hostname = $item.FQDNListener
$BackendPort = $item.BackendPort
$BackendProtocol = $item.BackendProtocol



#Certificate
$CertificateName = $item.FrontCertificateName
$Certificate = $Waf.SslCertificates | where name -eq  $CertificateName

if (!$Certificate)
{
    $CertificatePath = "$path\$($item.FrontCertificateFileNamePFX)"
    $password = Read-Host -Prompt "Enter password for certificate $CertificateName" -AsSecureString
    $Waf = Add-AzureRmApplicationGatewaySslCertificate -ApplicationGateway $Waf -Name $CertificateName -CertificateFile $CertificatePath -Password $password
    $Certificate = $Waf.SslCertificates | where name -eq  $CertificateName
 
}

#AuthentificationCertificate
if ($item.AuthentificationCertificateName -ne "")
{
  $AuthCertificate = $waf.AuthenticationCertificates | where name -eq  $item.AuthentificationCertificateName
    if (!$AuthCertificate)
    {
        $CertificatePath = "$path\$($item.AuthentificationCertificateFileNameCER)"
        $Waf = Add-AzureRmApplicationGatewayAuthenticationCertificate -ApplicationGateway $Waf -Name $item.AuthentificationCertificateName -CertificateFile $CertificatePath
        $AuthCertificate = $waf.AuthenticationCertificates | where name -eq  $item.AuthentificationCertificateName
    }  
}



#Probe
$BackendProbeName =  "healthprobe_$Hostname"
$probe = $waf.Probes | where name -eq $BackendProbeName
if (!$probe)
{
    $waf = Add-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $waf -Name $BackendProbeName -Protocol $BackendProtocol -PickHostNameFromBackendHttpSettings  -Path $item.ProbePath -Interval 30 -Timeout 120 -UnhealthyThreshold 8
    $probe = $waf.Probes | where name -eq $BackendProbeName
}

#BackendHttp
$BackendHttpSettingsName ="HttpSetting_$Hostname"
$BackendFQDN = $item.BackendFQDN
$BackendHttpSettings = $waf.BackendHttpSettingsCollection | where name -eq $BackendHttpSettingsName
if (!$BackendHttpSettings)
{
    if ($item.AuthentificationCertificateName -ne "")
    {
        $Waf = Add-AzureRmApplicationGatewayBackendHttpSettings -Name $BackendHttpSettingsName -ApplicationGateway $Waf -Port $BackendPort -Protocol $BackendProtocol -HostName $BackendFQDN -CookieBasedAffinity Disabled -probe $probe -AuthenticationCertificates $AuthCertificate -RequestTimeout 180  
    }
    else
    {
        $Waf = Add-AzureRmApplicationGatewayBackendHttpSettings -Name $BackendHttpSettingsName -ApplicationGateway $Waf -Port $BackendPort -Protocol $BackendProtocol -HostName $BackendFQDN -CookieBasedAffinity Disabled -probe $probe -RequestTimeout 180
    }
    
    $BackendHttpSettings = $waf.BackendHttpSettingsCollection | where name -eq $BackendHttpSettingsName
}

#Listener
$HttpListenerName = "Listener_$Hostname"
$HttpListener = $waf.HttpListeners | where name -eq $HttpListenerName
if (!$HttpListener)
{
    $waf = Add-AzureRmApplicationGatewayHttpListener -ApplicationGateway $waf -Name $HttpListenerName -FrontendIPConfiguration $waf.FrontendIPConfigurations[0] -FrontendPort $FrontendPort -hostname $Hostname -Protocol Https -SslCertificate $Certificate -RequireServerNameIndication true
    $HttpListener = $waf.HttpListeners | where name -eq $HttpListenerName
}

#Rule
$RuleName = "Rule_$Hostname"

if ($item.routing.tolower() -eq 'basic')
{
    $Rule = $waf.RequestRoutingRules | where name -eq $RuleName
    if (!$Rule)
    {
        $Waf = Add-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $Waf -Name $RuleName -RuleType Basic -BackendHttpSettings $BackendHttpSettings -HttpListener $HttpListener -BackendAddressPool $BackendPool
        $Rule = $waf.RequestRoutingRules | where name -eq $RuleName
    }
}
else
{
   $Pathconfig = import-csv -Path "$path\$($item.Routing)" -Delimiter ";"

   $rules = @()
   

   for ($i = 1; $i -lt $pathconfig.count; $i++)
   { 
             
       $rules += New-AzureRmApplicationGatewayPathRuleConfig -Name $pathconfig[$i].RuleName -Paths $pathconfig[$i].path -BackendAddressPool $BackendPool -BackendHttpSettings $BackendHttpSettings

   }

   #DefaultPool
   $DefaultPoolName = $Pathconfig[0].BackendPoolName
   $DefaultPool =  $waf.BackendAddressPools | where Name -eq $DefaultPoolName
   if (!$DefaultPool)
   {
        $DefaultPoolIPAddress = $Pathconfig[0].BackendIP
        $waf = Add-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $waf -Name $DefaultPoolName -BackendIPAddresses $DefaultPoolIPAddress
        $DefaultPool =  $waf.BackendAddressPools | where Name -eq $DefaultPoolName
   }

   $waf = Add-AzureRmApplicationGatewayUrlPathMapConfig -ApplicationGateway $waf -Name $item.Routing -PathRules $rules -DefaultBackendAddressPool $DefaultPool -DefaultBackendHttpSettings $BackendHttpSettings
   $pathMap = $waf.UrlPathMaps | where name -eq $item.Routing

   $waf = Add-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $waf -Name $RuleName -RuleType PathBasedRouting -HttpListener $HttpListener -UrlPathMap $PathMap

}



}

Stop-Transcript 

Set-AzureRmApplicationGateway -ApplicationGateway $Waf
