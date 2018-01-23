$bodyLoop = @()
$StackExAPIResponse = $Null
$Servers = Get-content .\serverslist.txt

Foreach($Server in $Servers){
	Write-host "Processing URL $Server." -foreground "Cyan"
	$StackExAPIResponse = Invoke-WebRequest -URI $Server -TimeoutSec 3 -ErrorAction Stop
	$servicePoint = [System.Net.ServicePointManager]::FindServicePoint("$Server")
	$URL = $servicePoint.address.tostring()
	$URL = $URL.trimend('/')
	$Expirdate = $servicePoint.Certificate.GetExpirationDateString()
	$EXDateObj = Get-date $Expirdate
	IF($EXDateObj -ne $Null){
	$Daystillexpire = $EXDateObj - ($Today = Get-Date) | select-object  -expandproperty Days
	IF($Daystillexpire -le 30){
	Write-host "$URL will expire on $EXDateObj which is $Daystillexpire days from today." -foreground "Yellow"
	$bodyLoop += "<b><span style='color:#fe030e'>$URL will expire on $EXDateObj which is $Daystillexpire days from today!</span></b><br>"
	$bodyLoop += "<br>"
	$CertExpireWarnFound = $True
	}
	}

}

IF($CertExpireWarnFound -eq $True){
# Change $smtp to a valid SMTP mail server for you to use.
$smtp = "enteryourmailserver.com" 
$maildate = get-date
$maildate = $maildate.ToShortDateString()
$subject = "SSL certificates found that will expire in within 30 days or less from $maildate!"
$body = "<b><span style='color:#5B9BD5'>The following SSL certificates are set to expire in 30 days or less!,</span></b><br>"
$body += "<br>"
$body += $bodyLoop

# You must at least change the to entires to valid email addresses for you.
Send-MailMessage -SmtpServer $smtp -To 'tech1@example.tech', 'tech2@example.tech' -From 'ADReporter@hbo.com' -Subject $subject -Body $body -BodyAsHtml -Priority "high"
}