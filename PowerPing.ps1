$servers = get-content .\ServersList.txt
$collection = $()

foreach ($server in $servers)
{
$status = @{ "ServerName" = $server; "TimeStamp" = (Get-Date -f s) }
if (Test-Connection $server -Count 1 -ea 0 -Quiet)
{
$status["Results"] = "Up"
}
else
{
$status["Results"] = "Down"
}
New-Object -TypeName PSObject -Property $status -OutVariable serverStatus
$collection += $serverStatus
}
$collection | Export-Csv -LiteralPath .\ServerStatus.csv -NoTypeInformation