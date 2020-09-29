#Répertorie contenant les certificats

$path = Split-Path -Parent $PSCommandPath

# Nom du resourceGroup
$ResourceGroupName = "xxxx"

# Nom du WAF
$WafName = "xxxx"

$Waf = Get-AzureRmApplicationGateway -Name $WafName -ResourceGroupName $ResourceGroupName

#region CleanUp Waf Config
    
    
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

#endregion



#region Commun
$FrontEndPortSSLName = "AppGatewayFrontEndPortSSL"
$porthttps = 443
$Waf = Add-AzureRmApplicationGatewayFrontendPort -Name $FrontEndPortSSLName -ApplicationGateway $Waf -Port $porthttps
$FrontendPort = $waf.FrontendPorts | where name -eq $FrontEndPortSSLName

#Pool
$BackendPoolIPAddress = "X.x.x.x"
$BackendPoolName = "apibackend"
$waf = Add-AzureRmApplicationGatewayBackendAddressPool -ApplicationGateway $waf -Name $BackendPoolName -BackendIPAddresses $BackendPoolIPAddress

$BackendPool =  $waf.BackendAddressPools | where Name -eq $BackendPoolName


#endregion

#region  x.x.io

#Backend
$Hostname = "x.x.io"
$BackendPort = "443"
$BackendProtocol = "https"

#Certificate

$CertificatePath = "$path\x.io.pfx"
$CertificateName = "x.io"
$password = Read-Host -Prompt "Enter password for certificate $CertificateName" -AsSecureString
$Waf = Add-AzureRmApplicationGatewaySslCertificate -ApplicationGateway $Waf -Name $CertificateName -CertificateFile $CertificatePath -Password $password

$Certificate = $Waf.SslCertificates | where name -eq  $CertificateName

#AuthentificationCertificate
$CertificatePath = "$path\x.io.cer"
$CertificateName = "x.io"
$Waf = Add-AzureRmApplicationGatewayAuthenticationCertificate -ApplicationGateway $Waf -Name $CertificateName -CertificateFile $CertificatePath
$AuthCertificate = $waf.AuthenticationCertificates | where name -eq  $CertificateName



#Probe
$BackendProbeName =  "healthprobe_$Hostname"
$waf = Add-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $waf -Name $BackendProbeName -Protocol $BackendProtocol -PickHostNameFromBackendHttpSettings  -Path "/status-0123456789abcdef" -Interval 30 -Timeout 120 -UnhealthyThreshold 8
$probe = $waf.Probes | where name -eq $BackendProbeName

#BackendHttp
$BackendHttpSettingsName ="HttpSetting_$Hostname"
$Waf = Add-AzureRmApplicationGatewayBackendHttpSettings -Name $BackendHttpSettingsName -ApplicationGateway $Waf -Port $BackendPort -Protocol $BackendProtocol -HostName $Hostname -CookieBasedAffinity Disabled -probe $probe -AuthenticationCertificates $AuthCertificate -RequestTimeout 180
$BackendHttpSettings = $waf.BackendHttpSettingsCollection | where name -eq $BackendHttpSettingsName


#Listener
$HttpListenerName = "Listener_$Hostname"

$waf = Add-AzureRmApplicationGatewayHttpListener -ApplicationGateway $waf -Name $HttpListenerName -FrontendIPConfiguration $waf.FrontendIPConfigurations[0] -FrontendPort $FrontendPort -hostname $Hostname -Protocol Https -SslCertificate $Certificate -RequireServerNameIndication true
$HttpListener = $waf.HttpListeners | where name -eq $HttpListenerName

#Rule
$RuleName = "Rule_$Hostname"
$Waf = Add-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $Waf -Name $RuleName -RuleType Basic -BackendHttpSettings $BackendHttpSettings -HttpListener $HttpListener -BackendAddressPool $BackendPool
#endregion

#region  x.x.io
$Hostname = "x.x.io"
$BackendHttpSettingsName ="HttpSetting_$Hostname"
$BackendPort = "443"
$BackendProtocol = "https"
$BackendProbeName =  "healthprobe_$Hostname"


#Probe
$waf = Add-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $waf -Name $BackendProbeName -Protocol $BackendProtocol -PickHostNameFromBackendHttpSettings  -Path "/status-0123456789abcdef" -Interval 30 -Timeout 120 -UnhealthyThreshold 8
$probe = $waf.Probes | where name -eq $BackendProbeName

#BackendHttp
$Waf = Add-AzureRmApplicationGatewayBackendHttpSettings -Name $BackendHttpSettingsName -ApplicationGateway $Waf -Port $BackendPort -Protocol $BackendProtocol -HostName $Hostname -CookieBasedAffinity Disabled -probe $probe -RequestTimeout 180 -AuthenticationCertificates $AuthCertificate
$BackendHttpSettings = $waf.BackendHttpSettingsCollection | where name -eq $BackendHttpSettingsName

#Frontend
$HttpListenerName = "Listener_$Hostname"
$waf = Add-AzureRmApplicationGatewayHttpListener -ApplicationGateway $waf -Name $HttpListenerName -FrontendIPConfiguration $waf.FrontendIPConfigurations[0] -FrontendPort $FrontendPort -hostname $Hostname -Protocol Https -SslCertificate $Certificate -RequireServerNameIndication true
$HttpListener = $waf.HttpListeners | where name -eq $HttpListenerName

#Rule
$RuleName = "Rule_$Hostname"
$Waf = Add-AzureRmApplicationGatewayRequestRoutingRule -ApplicationGateway $Waf -Name $RuleName -RuleType Basic -BackendHttpSettings $BackendHttpSettings -HttpListener $HttpListener -BackendAddressPool $BackendPool

#endregion



Set-AzureRmApplicationGateway -ApplicationGateway $Waf
