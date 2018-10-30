#############################################################################
#                                     			 		                    #
#   This script scans a given subscription for app service plans with       #
#   CPU Utlization less than 5% for the past 1 month                                  			 		                    #
#   Version 1.0                              			 	                #
#   Last Revision Date: 15 Feb 2018                                         #
#   Author: Prachi Jain (prajai)                      	                    #
#                                     			 		                    #
#############################################################################


Login-AzureRmAccount -ErrorVariable loginerror

If ($loginerror -ne $null)
{
   Throw {"Error: An error occured during the login process, please correct the error and try again."}
}

Function Select-Subs
{
$ErrorActionPreference = 'SilentlyContinue'
$MenuItem = 0
$Subs = @(Get-AzureRmSubscription | select Name,Id,TenantId)

Write-Host "Please select the subscription you wish to use" -ForegroundColor Green;
$Subs |%{Write-Host "[$($MenuItem)]" -ForegroundColor Cyan -NoNewline ;Write-host ". $($_.Name)";$MenuItem++;
}
$selection = Read-Host "Please select the Subscription Number - Valid numbers are 0 - $($Subs.count -1)"
If ($Subs.item($selection) -ne $null)
{
Write-Host $subs[$selection].Name;
Return @{name = $subs[$selection].Name;}
}

}
$SubscriptionSelection = Select-Subs
Select-AzureRmSubscription -SubscriptionName $SubscriptionSelection.Name -ErrorAction Stop


Write-Host "Scanning subscription $($SubscriptionSelection.Name) for all app service plans with less than 5% average CPU utilization..." -ForegroundColor Green

$ListOfAppServicePlans=Get-AzureRmResource | Where-Object {$_.ResourceType -eq "Microsoft.web/serverFarms"} | Select -Property "Name","ResourceId","ResourceGroupName","Location","Sku"


$Results=foreach ( $AppServicePlan in $ListOfAppServicePlans)
{
    $metricobj=Get-AzureRmMetric -ResourceId $AppServicePlan.ResourceId -TimeGrain "12:00:00"  -MetricName "CpuPercentage" -StartTime (get-date).date.AddMonths(-1)
    $cpuutilization=$metricobj.Data|  Measure-Object -Property "Average" -Average | Select -ExpandProperty "Average"
    if($cpuutilization -lt 5)
    {
       $property=[ordered]@{       
       ResourceName=$AppServicePlan.Name
       ResourceId=$AppServicePlan.ResourceId
       ResourceGroupName=$AppServicePlan.ResourceGroupName
       Location=$AppServicePlan.Location
       CPUUtilization=$cpuutilization
       PricingTier=$AppServicePlan.Sku.name+" "+$AppServicePlan.Sku.tier
       

       }
       New-Object -TypeName PSObject -Property $property
       
    }

   
}

$Results | Export-Csv -Path ".\$($SubscriptionSelection.Name)_Underutilizedappserviceplans.csv"




