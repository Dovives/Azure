param ($json)

$j = Get-Content $json | ConvertFrom-Json
$export = @()
foreach ($line in $j) {$export  += $line.Tags | Select-Object @{n='ResourceGroupName';e={($line).ResourceGroupName}},*}
$export | Export-Csv -Delimiter ';' -Encoding UTF8 -NoTypeInformation -Path '.\export.csv'