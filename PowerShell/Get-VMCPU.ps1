Select-AzSubscription -Subscription "xxx-xx-xxx"
$vmlist = Get-AzVM
foreach($vm in $vmlist)
{
    $vmdetails = Get-AzVM -Name $vm.Name -Status
    $avr = (Get-AzMetric -ResourceId $vm.Id -TimeGrain "01:00:00" -MetricName "Percentage CPU" -ResultType Data  -WarningAction SilentlyContinue).Data[0].Average
    if(!$avr)
    {
        $avr = 0
    }
    Write-Host "$($vm.Name) is $($vmdetails.PowerState) with average CPU $($avr)"
}