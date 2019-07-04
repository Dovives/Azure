Start-Transcript
function Find-OrphanedObjects {

    Param(
	    # Optional. Azure Subscription Name, if you want to Scan or Update a single subscription use this parameter
        [parameter(position=1)]
        [string]$SubscriptionName = "Subscription Name",
        [parameter(position=0)]
        [string]$SimulateMode = "True"
	)

    # Variables
    $ErrorActionPreference = "Stop"
    # Setup counters for Extension installation results

    # If $SubscriptionName Parameter has not been passed as an argument or edited in the script Params.
    if($SubscriptionName -eq "Subscription Name") {

        # Get all Subscriptions
        [array]$AzureSubscriptions = Get-AzSubscription -ErrorAction $ErrorActionPreference

    } else {
        # Use the subscription that has been selected from the 'Get-AzurePSConnection' function
        [array]$AzureSubscriptions = (Get-AzContext).Subscription
    }

    $SubscriptionCount = 0

    # Loop Subscriptions
    ForEach($AzureSubscription in $AzureSubscriptions) {

        $SubscriptionCount++

        Write-Host "Processing Azure Subscription: " -NoNewLine
        Write-Host "$SubscriptionCount of $($AzureSubscriptions.Count)" -ForegroundColor Yellow

        Write-Host "Subscription Name = " -NoNewLine
        Write-Host "$($AzureSubscription.Name)" -ForegroundColor Yellow

        $Script:ActiveSubscriptionName = $AzureSubscription.Name
        $Script:ActiveSubscriptionID = $AzureSubscription.Id

        if($SimulateMode -eq 'True') {
            # Simulate Mode: True
            Write-Host "INFO: " -ForegroundColor Cyan
            Write-Host "Simulate Mode Enabled" -ForegroundColor Green
            Write-Host " - No updates will be performed."
            Write-Host " "
            
            $UserConfirmation = Read-Host -Prompt "Do you want to SIMULATE orphaned items search `n`nType 'yes' to confirm...."

        } else {
            # Simulate Mode: False
            Write-Host "INFO: " -ForegroundColor Cyan
            Write-Host "Simulate Mode DISABLED" -ForegroundColor Red
            Write-Host " - Updates will be performed."
            Write-Host " "
                  
            $UserConfirmation = Read-Host -Prompt "Are you sure you want to remove ALL orphaned items in the Subscription above? `n`nType 'yes' to confirm...."

        }

        If($UserConfirmation.ToLower() -ne 'yes')
        {
            Write-Host "`nUser typed ""$($UserConfirmation)"", skipping this Subscription...."
            Write-Host " "
            # use 'Continue' statement to skip this item in the ForEach Loop
            Continue
        } else {
            Write-Host "`nUser typed 'yes' to confirm...."
            Write-Host " "
        }
        
        # Set AzContext as we are in a ForEach Loop
        Write-Host "Set-AzContext" -NoNewline
        Write-Host "-SubscriptionId " -NoNewLine
        Write-Host $($AzureSubscription.Id) -ForegroundColor Cyan

        Set-AzContext -SubscriptionId $AzureSubscription.Id

        Write-Host "`nFind and enable Azure Hybrid Benefit:" -ForegroundColor Cyan
        [array]$AzVMs = Get-AzVM #-ErrorAction $ErrorActionPreference -WarningAction $WarningPreference

        if($AzVMs) {
      
            # Loop through each VM in this Resource Group
            ForEach($AzVM in $AzVMs) {
      
                # Create New Ordered Hash Table to store VM details
                $VMOutput = [ordered]@{}
                #$VMOutput.Add("Resource Group",$ResourceGroup)
                $VMOutput.Add("VM Name",$AzVM.Name)
                $VMOutput.Add("Resource Group Name",$AzVM.ResourceGroupName)
                $VMOutput.Add("VM Size",$AzVM.HardwareProfile.VmSize)
                $VMOutput.Add("VM Location",$AzVM.Location)
                $VMOutput.Add("OS Type",$AzVM.StorageProfile.OsDisk.OsType)
      
                # If the VM is a Windows VM
                if($AzVM.StorageProfile.OsDisk.OsType -eq "Windows") {
      
                    # If AHUB is NOT enabled
                    if(($AzVM.LicenseType -ne "Windows_Server") -and ($AzVM.LicenseType -ne "Windows_Client")) {
      
                        if($SimulateMode -eq "True") {
                            
                            # $SimulateMode set to $True (default), No Updates will be performed
                            Write-Host "INFO: " -ForegroundColor Cyan -NoNewline
                            Write-Host "$($AzVM.Name)"
      
                        } else {
      
                            # $SimulateMode set to $False, updates will be performed
                            Write-Host "`tUpdating $($AzVM.Name)..."
      
                            $AzVM.LicenseType = "Windows_Server"                      
                            Update-AzVM -ResourceGroupName $AzVM.ResourceGroupName -VM $AzVM
              }
      
          }
      }
            }
      
       }

        Write-Host "`nFind and delete unattached network interfaces:" -ForegroundColor Cyan
        $networkInterfaces = Get-AzNetworkInterface
        foreach ($nic in $networkInterfaces) {
        # ManagedBy property stores the Id of the VM to which Managed Disk is attached to
        # If ManagedBy property is $null then it means that the Managed Disk is not attached to a VM
            if($nic.VirtualMachine -eq $null){

                if($SimulateMode -eq "False"){

                    Write-Host "Deleting unattached network interface with Id: $($nic.Name)"

                    $nic | Remove-AzNetworkInterface -Force

                    Write-Host "Deleted unattached network interface with Id: $($nic.Name)"

                }else{

                    $nic.Name

                }
            }
         }

        Write-Host "`nUnmanaged disks: Find and delete unattached disks:" -ForegroundColor Cyan

        $storageAccounts = Get-AzStorageAccount
        foreach($storageAccount in $storageAccounts){
        $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.StorageAccountName)[0].Value
        $context = New-AzStorageContext -StorageAccountName $storageAccount.StorageAccountName -StorageAccountKey $storageKey
        $containers = Get-AzStorageContainer -Context $context

        foreach($container in $containers){
        $blobs = Get-AzStorageBlob -Container $container.Name -Context $context

        #Fetch all the Page blobs with extension .vhd as only Page blobs can be attached as disk to Azure VMs
        $blobs | Where-Object {$_.BlobType -eq 'PageBlob' -and $_.Name.EndsWith('.vhd')} | ForEach-Object { 
        
            #If a Page blob is not attached as disk then LeaseStatus will be unlocked
            if($_.ICloudBlob.Properties.LeaseStatus -eq 'Unlocked'){
                    if($SimulateMode -eq "False"){
                        Write-Host "Deleting unattached VHD with Uri: $($_.ICloudBlob.Uri.AbsoluteUri)"
                        $_ | Remove-AzStorageBlob -Force
                        Write-Host "Deleted unattached VHD with Uri: $($_.ICloudBlob.Uri.AbsoluteUri)"
                    }
                    else{
                        $_.ICloudBlob.Uri.AbsoluteUri
                    }
                        }
                    }
                }
            }

        Write-Host "`nManaged disks: Find and delete unattached disks:" -ForegroundColor Cyan

        $managedDisks = Get-AzDisk
        foreach ($md in $managedDisks) {
            # ManagedBy property stores the Id of the VM to which Managed Disk is attached to
            # If ManagedBy property is $null then it means that the Managed Disk is not attached to a VM
            if($md.ManagedBy -eq $null){
                if($SimulateMode -eq "False"){
                    Write-Host "Deleting unattached Managed Disk with Id: $($md.Id)"
                    $md | Remove-AzDisk -Force
                    Write-Host "Deleted unattached Managed Disk with Id: $($md.Id)"
                }else{
                    $md | select Id, DiskSizeGB, ResourceGroupName

                }
            }
         }

         Write-Host "`nFind and delete unattached Public IPs" -ForegroundColor Cyan

         $publicIPs = Get-AzPublicIpAddress
         foreach ($pip in $publicIPs) {

            if($pip.IpConfiguration -eq $null)
            {
                if($SimulateMode -eq "False"){
                    Write-Host "Deleting unattached Public IPs with Id: $($pip.Id)"
                    $pip | Remove-AzPublicIpAddress -Force
                    Write-Host "Deleted unattached Public IPs with Id: $($pip.Id)"

                }else{
                    $pip | select Name, PublicIpAllocationMethod, IpAddress

                }
            }
         }
     } 
}
Stop-Transcript