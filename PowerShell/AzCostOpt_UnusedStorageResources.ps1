function Get-BlobBytes
{
    param(
        [Parameter(Mandatory=$true)]
        $Blob)

    # Base + blobname
    $blobSizeInBytes = 124 + $Blob.Name.Length * 2

    # Get size of metadata
    $metadataEnumerator=$Blob.ICloudBlob.Metadata.GetEnumerator()
    while($metadataEnumerator.MoveNext())
    {
        $blobSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + $metadataEnumerator.Current.Value.Length
    }

    if($Blob.BlobType -eq [Microsoft.WindowsAzure.Storage.Blob.BlobType]::BlockBlob)
    {
        $blobSizeInBytes += 8
        # Default is Microsoft.WindowsAzure.Storage.Blob.BlockListingFilter.Committed. Need All
        $Blob.ICloudBlob.DownloadBlockList([Microsoft.WindowsAzure.Storage.Blob.BlockListingFilter]::All) |
            ForEach-Object { $blobSizeInBytes += $_.Length + $_.Name.Length }
    }
    else
    {
        $Blob.ICloudBlob.GetPageRanges() |
            ForEach-Object { $blobSizeInBytes += 12 + $_.EndOffset - $_.StartOffset }
    }

    return $blobSizeInBytes
}

# function Get-ContainerBytes

function Get-ContainerBytes
{
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.WindowsAzure.Storage.Blob.CloudBlobContainer]$Container)

    # Base + name of container
    $containerSizeInBytes = 48 + $Container.Name.Length*2

    # Get size of metadata
    $metadataEnumerator = $Container.Metadata.GetEnumerator()
    while($metadataEnumerator.MoveNext())
    {
        $containerSizeInBytes += 3 + $metadataEnumerator.Current.Key.Length + $metadataEnumerator.Current.Value.Length
    }

    # Get size for SharedAccessPolicies
    $containerSizeInBytes += $Container.GetPermissions().SharedAccessPolicies.Count * 512

    # Calculate size of all blobs.
    $blobCount = 0
    $Token = $Null
    $MaxReturn = 5000

    do {
        $Blobs = Get-AzureStorageBlob -Context $storageContext -Container $Container.Name -MaxCount $MaxReturn -ContinuationToken $Token
        if($Blobs -eq $Null) { break }

        #Set-StrictMode will cause Get-AzureStorageBlob returns result in different data types when there is only one blob
        if($Blobs.GetType().Name -eq "AzureStorageBlob")
        {
            $Token = $Null
        }
        else
        {
            $Token = $Blobs[$Blobs.Count - 1].ContinuationToken;
        }

        $Blobs | ForEach-Object {
                $blobSize = Get-BlobBytes $_
                $containerSizeInBytes += $blobSize
                $blobCount++

                if(($blobCount % 1000) -eq 0)
                {
                    Write-Verbose("Counting {0} Sizing {1} " -f $blobCount, $containerSizeInBytes)
                }
            }
    }
    While ($Token -ne $Null)

    return @{ "containerSize" = $containerSizeInBytes; "blobCount" = $blobCount }
}


$i = 1
$j = 1 
$Count = 0
$ToDelete = 0
$ResourceGroups = Get-AzureRmResourceGroup


$fileName = [string]::Concat("AuditStorage",".CSV")
$AuditSA = "ResourceGroup, StorageAccountName, ContainerName, Size, FileNumber, LastAccessed, leasedstatus"
$AuditSA | Out-File $fileName -Encoding ascii


foreach ($RG in $ResourceGroups)
{
    Write-Progress -Activity "ResourceGroup : $($RG.ResourceGroupName)" -Status "$i/$($ResourceGroups.count)" -PercentComplete ($i*100/$($ResourceGroups.count))
    $StorageAccounts = Get-AzureRmStorageAccount -ResourceGroupName $RG.ResourceGroupName
    $j = 1 
    foreach ($SA in $StorageAccounts)
    {
        $count ++
        Write-Progress -Id 1 -Activity "StorageAccount : $($sa.StorageAccountName)" -Status "$j/$($StorageAccounts.count)" -PercentComplete ($j*100/$($StorageAccounts.count))
        $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $sa.ResourceGroupName -Name $sa.StorageAccountName
        $key = $StorageAccountKey.value[0]
        $ctx = New-AzureStorageContext -StorageAccountName $sa.StorageAccountName -StorageAccountKey $key

        $sizeInBytes = 0
        $container = Get-AzureStorageContainer -Context $ctx
        
        if($containers.Count -gt 0)
            {
                $containers | ForEach-Object {
                    Write-Output("Calculating container {0} ..." -f $_.CloudBlobContainer.Name)
                    $result = Get-ContainerBytes $_.CloudBlobContainer
                    $sizeInBytes += $result.containerSize

                    Write-Output("Container '{0}' with {1} blobs has a sizeof {2:F2} MB." -f $_.CloudBlobContainer.Name,$result.blobCount,($result.containerSize/1MB))
                }
            }
            else
            {
                Write-Warning "No containers found to process in storage account '$StorageAccountName'."
            }
        
        
        
        
        if($sa.sku.tier -eq "Premium")
        {
            if($container -eq $null)
            {
            Write-Host "Premium Storage Account $($sa.StorageAccountName) in RG  $($sa.ResourceGroupName) is Empty !!!!" -ForegroundColor Green
            $ToDelete++
            }
        }
        else
        {
            if ($sa.AccessTier -ne "Cool" -and $sa.AccessTier -ne "Hot" -and $sa.sku.Name -ne "StandardZRS" )
            {
                $share = Get-AzureStorageShare -Context $ctx
                $table = Get-AzureStorageTable -Context $ctx
                $queue = Get-AzureStorageQueue -Context $ctx

                if($container -eq $null -and $share -eq $null -and $table -eq $null -and $queue -eq $null)
                {
                Write-Host "Storage Account $($sa.StorageAccountName) in RG  $($sa.ResourceGroupName) is Empty !!!!"
                $ToDelete++
                $AuditSA = [string]::Concat($sa.ResourceGroupName,",",$sa.StorageAccountName,",")
                $AuditSA | Out-File $fileName -Encoding ascii -Append
                }
                
            }
        
        }
        if ($container.count -eq 1 -and $share -eq $null -and $table -eq $null -and $queue -eq $null)
        {
            if ($container.name -eq "vhds" -or $container.name -match 'bootdiag') 
            {
            

            $Blob = Get-AzureStorageBlob -Container $container.name -Context $ctx
            $lastmodified = ($blob | Sort-Object -Property LastModified -Descending)[0].lastmodified.datetime.ToShortDateString()
            $leasestatus = ($blob | Sort-Object -Property LastModified -Descending)[0].ICloudBlob.Properties.LeaseStatus

            $AuditSA = [string]::Concat($sa.ResourceGroupName,",",$sa.StorageAccountName,",", $container.name,",", $sizeInBytes.containerSize /1MB , ",", $blob.count, ",", $lastmodified, ",", $leasestatus)
            $AuditSA | Out-File $fileName -Encoding ascii -Append
            }
        }
        
        
    $j++
    }
    Write-Progress -Id 1 -Activity "StorageAccount" -Completed
    $i++
    Start-Sleep -s 2
}
Write-Progress -Activity "ResourceGroup" -Completed
Write-Host "Total Storage account $count" -ForegroundColor White
Write-Host "Storage Account that could be deleted $ToDelete" -ForegroundColor Yellow
