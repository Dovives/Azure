#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration ConfigureSharePointServer
{

    param
    (
        [Parameter(Mandatory)] [String]$DomainName,

        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds,

        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SharePointFarmAccountcreds,

        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SharePointFarmPassphrasecreds,

        [parameter(Mandatory)] [String]$DatabaseName,

        [parameter(Mandatory)] [String]$AdministrationContentDatabaseName,

        [parameter(Mandatory)] [String]$DatabaseServer,

		[parameter(Mandatory)]
        [String]$Configuration,

        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPServicesCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPWebCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPContentCredential,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSuperReaderUsername,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPSuperUserUsername,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPPrefix="spfarm",
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPWebAppUrl,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $SPMySiteUrl,    

        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$FarmCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointFarmAccountcreds.UserName)", $SharePointFarmAccountcreds.Password)
    [System.Management.Automation.PSCredential ]$SPsetupCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)


    Enable-CredSSPNTLM -DomainName $DomainName

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xCredSSP #cConfigureSharepoint

    # Added for SP2016 
    Import-DscResource -ModuleName SharePointDsc
    Import-DscResource -ModuleName xWebAdministration


    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
        xCredSSP Server
        {
            Ensure = "Present"
            Role = "Server"
        }
        xCredSSP Client
        {
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*.$Domain", "localhost"
        }
        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
        }

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xADUser CreateSetupAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SharePointSetupUserAccountcreds.UserName
            Password =$SharePointSetupUserAccountcreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        Group AddSetupUserAccountToLocalAdminsGroup
        {
            GroupName = "Administrators"
            Credential = $DomainCreds
            MembersToInclude = "${DomainName}\$($SharePointSetupUserAccountcreds.UserName)"
            Ensure="Present"
            DependsOn = "[xAdUser]CreateSetupAccount"
        }

        xADUser CreateFarmAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SharePointFarmAccountcreds.UserName
            Password =$FarmCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        # Added for SP2016 
        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; DependsOn = "[xComputer]DomainJoin"}
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[xComputer]DomainJoin"}

        # Added for SP2016 - ok 
        File 1WriteDSCCompleteFile
        {
            DestinationPath = "F:\Logs\DSC1.txt"
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            Contents = "DSC First App"
            Type = 'File'
            Force = $true
            DependsOn = "[xWebSite]RemoveDefaultWebSite"
        }

		$ServiceAppPoolName = "SharePoint Service Applications"
        #**********************************************************
        # Farm Creation 
        #
        # 
        #
        #**********************************************************
        SPCreateFarm CreateSPFarm
        {
            FarmConfigDatabaseName = $SPPrefix + "_Config"
            DatabaseServer =         $DatabaseServer
            FarmAccount = $SharePointFarmAccountcreds
            Passphrase = $SharePointFarmPassphrasecreds
            AdminContentDatabaseName = $SPPrefix + "_AdminContent"
            CentralAdministrationPort = 8080
            CentralAdministrationAuth = 'NTLM'
            ServerRole = 'Application'
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            DependsOn = @("[xComputer]DomainJoin","[xWebSite]RemoveDefaultWebSite","[xADUser]CreateFarmAccount","[xADUser]CreateSetupAccount", "[Group]AddSetupUserAccountToLocalAdminsGroup")
           
        }

        #Not Yet Modified for SP2016
        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $SPServicesCredential.UserName
            Account              = $SPServicesCredential
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }

        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $SPWebCredential.UserName
            Account              = $SPWebCredential
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }

        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            LogPath                                     = "F:\Logs"
            LogSpaceInGB                                = 10
            AppAnalyticsAutomaticUploadEnabled          = $false
            CustomerExperienceImprovementProgramEnabled = $true
            DaysToKeepLogs                              = 7
            DownloadErrorReportingUpdatesEnabled        = $false
            ErrorReportingAutomaticUploadEnabled        = $false
            ErrorReportingEnabled                       = $false
            EventLogFloodProtectionEnabled              = $true
            EventLogFloodProtectionNotifyInterval       = 5
            EventLogFloodProtectionQuietPeriod          = 2
            EventLogFloodProtectionThreshold            = 5
            EventLogFloodProtectionTriggerPeriod        = 2
            LogCutInterval                              = 15
            LogMaxDiskSpaceUsageEnabled                 = $true
            ScriptErrorReportingDelay                   = 30
            ScriptErrorReportingEnabled                 = $true
            ScriptErrorReportingRequireAuth             = $true
            PsDscRunAsCredential                        = $SharePointSetupUserAccountcreds
            DependsOn                                   = "[SPCreateFarm]CreateSPFarm"
        }
		 
		SPServiceAppPool MainServiceAppPool
        {
            Name                 = $ServiceAppPoolName
            ServiceAccount       = $SPServicesCredential.UserName
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = $SPPrefix + "_State"
            DatabaseServer       = $DatabaseServer
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPSecureStoreServiceApp SecureStoreServiceApp
        {
            Name                  = "Secure Store Service Application"
            ApplicationPool       = $ServiceAppPoolName
            AuditingEnabled       = $true
            AuditlogMaxSize       = 30
            DatabaseName          = $SPPrefix + "_SecureStore"
            DatabaseServer        = $DatabaseServer
            PsDscRunAsCredential  = $SharePointSetupUserAccountcreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {  
            Name                 = "Managed Metadata Service Application"
            ApplicationPool      = $ServiceAppPoolName
            DatabaseName         = $SPPrefix + "_MMS"
            DatabaseServer       = $DatabaseServer
            PsDscRunAsCredential = $SharePointSetupUserAccountcreds
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPAppManagementServiceApp AppManagementServiceApp
        {
            Name                  = "Application Management Service Application"
            DatabaseName          = $SPPrefix + "_AppManagement"
            DatabaseServer        = $DatabaseServer
            ApplicationPool       = $ServiceAppPoolName
            PsDscRunAsCredential  = $SharePointSetupUserAccountcreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPSubscriptionSettingsServiceApp SubscriptionSettingsServiceApp
        {
            Name                  = "Subscription Settings Service Application"
            DatabaseName          = $SPPrefix + "_SubscriptionSettings"
            DatabaseServer        = $DatabaseServer
            ApplicationPool       = $ServiceAppPoolName
            PsDscRunAsCredential  = $SharePointSetupUserAccountcreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }		

	}        
}

function Enable-CredSSPNTLM
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName
    )

    # This is needed for the case where NTLM authentication is used

    Write-Verbose 'STARTED:Setting up CredSSP for NTLM'

    Enable-WSManCredSSP -Role client -DelegateComputer localhost, *.$DomainName -Force -ErrorAction SilentlyContinue
    Enable-WSManCredSSP -Role server -Force -ErrorAction SilentlyContinue

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name '\CredentialsDelegation' -ErrorAction SilentlyContinue
    }

    if( -not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -value "wsman/$env:COMPUTERNAME" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -value "wsman/localhost" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -value "wsman/*.$DomainName" -PropertyType string -ErrorAction SilentlyContinue
    }

    Write-Verbose "DONE:Setting up CredSSP for NTLM"
}

