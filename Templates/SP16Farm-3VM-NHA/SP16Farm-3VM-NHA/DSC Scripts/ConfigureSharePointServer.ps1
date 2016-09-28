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

		#[parameter(Mandatory)] [String]$Configuration,

        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPServicesCredential,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPWebCredential,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPContentCredential,
        [Parameter(Mandatory)] [string]$SPSuperReaderUsername,
        [Parameter(Mandatory)] [string]$SPSuperUserUsername,
        [Parameter(Mandatory)] [string]$SPPrefix="spfarm",
        [Parameter(Mandatory)] [string]$SPWebAppUrl,
        [Parameter(Mandatory)] [string]$SPMySiteUrl,    

        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$FarmCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointFarmAccountcreds.UserName)", $SharePointFarmAccountcreds.Password)
    [System.Management.Automation.PSCredential ]$SPsetupCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)
	[System.Management.Automation.PSCredential ]$SPServicesCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SPServicesCredential.UserName)", $SPServicesCredential.Password)
	[System.Management.Automation.PSCredential ]$SPWebCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SPWebCredential.UserName)", $SPWebCredential.Password)
	[System.Management.Automation.PSCredential ]$SPCntCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SPContentCredential.UserName)", $SPContentCredential.Password)


    Enable-CredSSPNTLM -DomainName $DomainName

	
    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xCredSSP #cConfigureSharepoint

    # Added for SP2016
	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion "1.2.0.0"
    Import-DscResource -ModuleName xWebAdministration -ModuleVersion "1.13.0.0"


    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ActionAfterReboot = 'ContinueConfiguration'
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


		xADUser CreateSpServicesAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SPServicesCredential.UserName
            Password =$SPServicesCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

		xADUser CreateSPWebAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SPWebCredential.UserName
            Password =$SPWebCreds
            Ensure = "Present"
            DependsOn = "[xComputer]DomainJoin"
        }

        Registry DisableLoopBackCheck {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
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

		$ServiceAppPoolName = "SharePoint_Service_Application_Pool"
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
            FarmAccount = $FarmCreds
            Passphrase = $SharePointFarmPassphrasecreds
            AdminContentDatabaseName = $SPPrefix + "_AdminContent"
            CentralAdministrationPort = 8080
            CentralAdministrationAuth = 'NTLM'
            ServerRole = 'Application'
            PsDscRunAsCredential = $SPsetupCreds
            DependsOn = @("[xComputer]DomainJoin","[xWebSite]RemoveDefaultWebSite","[xADUser]CreateFarmAccount","[xADUser]CreateSetupAccount","[Group]AddSetupUserAccountToLocalAdminsGroup")
           
        }

        #Not Yet Modified for SP2016
        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $SPServicesCredential.UserName
            Account              = $SPServicesCreds
            PsDscRunAsCredential = $SPsetupCreds
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }

        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $SPWebCredential.UserName
            Account              = $SPWebCreds
            PsDscRunAsCredential = $SPsetupCreds
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
            PsDscRunAsCredential                        = $SPsetupCreds
            DependsOn                                   = "[SPCreateFarm]CreateSPFarm"
        }
		 
		SPServiceAppPool MainServiceAppPool
        {
            Name                 = $ServiceAppPoolName
            ServiceAccount       = $SPServicesCredential.UserName
            PsDscRunAsCredential = $SPsetupCreds
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = $SPPrefix + "_State"
            DatabaseServer       = $DatabaseServer
            PsDscRunAsCredential = $SPsetupCreds
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
            PsDscRunAsCredential  = $SPsetupCreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {  
            Name                 = "Managed Metadata Service Application"
            ApplicationPool      = $ServiceAppPoolName
            DatabaseName         = $SPPrefix + "_ManagedMetada"
            DatabaseServer       = $DatabaseServer
            PsDscRunAsCredential = $SPsetupCreds
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPAppManagementServiceApp AppManagementServiceApp
        {
            Name                  = "Application Management Service Application"
            DatabaseName          = $SPPrefix + "_AppManagement"
            DatabaseServer        = $DatabaseServer
            ApplicationPool       = $ServiceAppPoolName
            PsDscRunAsCredential  = $SPsetupCreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPSubscriptionSettingsServiceApp SubscriptionSettingsServiceApp
        {
            Name                  = "Subscription Settings Service Application"
            DatabaseName          = $SPPrefix + "_SubscriptionSettings"
            DatabaseServer        = $DatabaseServer
            ApplicationPool       = $ServiceAppPoolName
            PsDscRunAsCredential  = $SPsetupCreds
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }



		
		#**********************************************************
        # Web applications
        #
        # This section creates the web applications in the 
        # SharePoint farm, as well as managed paths and other web
        # application settings
        #**********************************************************
        $useSSL = $SPWebAppUrl.ToLower().Contains('https://')
        SPWebApplication HostWebApplication
        {
            Name                   = "SharePoint Site"
            ApplicationPool        = $ServiceAppPoolName
            ApplicationPoolAccount = $SPWebCreds.UserName
            AllowAnonymous         = $false
            UseSSL                 = $useSSL
            AuthenticationMethod   = 'NTLM'
            DatabaseName           = $SPPrefix + "_SitesContent"
            DatabaseServer         = $DatabaseServer
            Url                    = $SPWebAppUrl
            Port                   = [Uri]::new($SPWebAppUrl).Port
            PsDscRunAsCredential   = $SPsetupCreds
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }   
        
        #Web Application Settings
        SPWebAppGeneralSettings SiteGeneralSettings
        {
            Url = $SPWebAppUrl
            MaximumUploadSize = 250
            PsDscRunAsCredential = $SPsetupCreds
            DependsOn = "[SPWebApplication]HostWebApplication"
        }

        #Root Site Collections
        SPSite HostSiteCollection
        {
            Url                      = $SPWebAppUrl
            OwnerAlias               = $SPsetupCreds.UserName
            Name                     = "Root site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPsetupCreds
            DependsOn                = "[SPWebApplication]HostWebApplication"
        }
		
		#Set the CachAccounts for the web application
        SPCacheAccounts AddCacheAccounts
        {
            WebAppUrl              = $SPWebAppUrl
            SuperUserAlias         = $SPSuperUserUsername
            SuperReaderAlias       = $SPSuperReaderUsername
            PsDscRunAsCredential   = $SPsetupCreds
            DependsOn              = "[SPWebApplication]HostWebApplication"
        }

		#Configure Managed Path and My Site Host

		SPManagedPath ManagedPathPersonal
        {
            WebAppUrl            = $SPWebAppUrl
            PsDscRunAsCredential = $SPsetupCreds
            RelativeUrl          = "personal"
            Explicit             = $false
            HostHeader           = $false 
            DependsOn            = "[SPWebApplication]HostWebApplication"
        }

        SPSite MySiteSiteCollection
        {
            Url                      = $SPMySiteUrl
            OwnerAlias               = $SPsetupCreds.UserName
            HostHeaderWebApplication = $SPWebAppUrl
            Name                     = "My Sites"
            Template                 = "SPSMSITEHOST#0"
            PsDscRunAsCredential     = $SPsetupCreds
            DependsOn              = "[SPManagedPath]ManagedPathPersonal"
        }

		SPUserProfileServiceApp UserProfileServiceApp
        {
            Name                 = "User Profile Service Application"
            ApplicationPool      = $ServiceAppPoolName
            MySiteHostLocation   = $SPMySiteUrl
            ProfileDBName        = $SPPrefix + "_ProfileDB"
            ProfileDBServer      = $DatabaseServer
            SocialDBName         = $SPPrefix + "_SocialDB"
            SocialDBServer       = $DatabaseServer
            SyncDBName           = $SPPrefix + "_SyncDB"
            SyncDBServer         = $DatabaseServer
            FarmAccount          = $FarmCreds
            PsDscRunAsCredential = $SPsetupCreds
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

