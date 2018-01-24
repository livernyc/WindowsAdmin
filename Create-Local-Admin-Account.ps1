Function Get-LocalUsers ([String]$Machine)
{

if(Test-Connection -ComputerName $Machine -count 1 -Quiet) {
$adsi = [ADSI]("WinNT://$Machine")
$Users = $adsi.Children  | where {$_.SchemaClassName  -eq 'user'} | sort name
return $Users 
}

}

Function Create-LocalAdmin ([String]$Machine, [string]$ObjectType, [String]$ObjectName, [String]$PlainPassword, [String]$Action)
{
   if(Test-Connection -ComputerName $Machine -count 1 -Quiet) {
        try {
            $CompObject = [ADSI]"WinNT://$Machine"
			$NewObj = $CompObject.Create("$ObjectType",$ObjectName)
            
			if($ObjectType -eq "User" -and $Action -eq "Create") {
				Write-Host "User account creation being attempted!" -foregroundColor green
                $NewObj.SetPassword($PlainPassword)
				$NewObj.SetInfo()
				$AdminGroup = [ADSI]"WinNT://$Machine/Administrators,group"
				$LocUser = [ADSI]"WinNT://$Machine/$ObjectName,user"
				$AdminGroup.Add($LocUser.Path)
            
				$LocUser.description = "Loacl Admin account for consultant"
				$LocUser.SetInfo()
				Write-Host "$ObjectTYpe with the name $ObjectName created successfully" -ForegroundColor Green
			}
			
			if($ObjectType -eq "User" -and $Action -eq "AddToAdmin") {
            $AdminGroup = [ADSI]"WinNT://$Machine/Administrators,group"
			$LocUser = [ADSI]"WinNT://$Machine/$ObjectName,user"
			$AdminGroup.Add($LocUser.Path)
            $LocUser.description = "Loacl Admin account for consultant"
			$LocUser.SetInfo()
			Write-Host "$ObjectName was add to the Local Admin group successfully." -ForegroundColor Green
			}
			 
		} catch {
			If($_ -Match "The specified account name is already a member of the group"){
			$LocUser = [ADSI]"WinNT://$Machine/$ObjectName,user"
			$LocUser.description = "Loacl Admin account for consultant"
			$LocUser.SetInfo()
			Write-Host "$ObjectName is already in the Local Administrator group on $Machine." -ForegroundColor DarkCyan
			}
			ELSE{
            Write-Warning "Error occurred while creating the local Object"
            Write-Warning "More details : $_"
			}
        }
	}	
    else {
        Write-Warning "$Machine is not online"
   }
}

# Script main body starts.
$Computers = @()
$AllComputers = @()
$NewLocAdmin = "ConsultAdmin" # This will set the name of the account that gets created.

$filename = "LocalAdminAccountCreated-report.xlsx"

If(test-path $filename){
remove-item $filename
}

# Load Export-Excel module
iex (new-object System.Net.WebClient).DownloadString('https://raw.github.com/dfinke/ImportExcel/master/Install.ps1')

$Computers = get-content ServersList.txt

Write-host "Make sure you check your targets in the ServersList.txt file." -foregroundColor yellow
Write-host "If it has have fully qualified server names it will cauase the script to fail on those servers." -foregroundColor yellow 
Write-host "Once you hit the enter key the targeted servers will be listed for you." -foregroundColor yellow
Write-host "If you see names that are FQDN cancel the script and fix the ServersList.txt file." -foregroundColor yellow
Read-Host -Prompt "Hit enter to bring up the target list"

Write-host ""
$Computers
Write-host ""

Read-Host -Prompt "Hit enter start the script"

# Get password to use for new local Admin account.
$PasswordForUser = Read-Host -Prompt "Enter a password for local Admin account setup" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordForUser)
$Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 


Foreach ($Computer in $Computers){

$Found = "No"

$LocalUsers = Get-LocalUsers -Machine $Computer
If($LocalUsers -ne $null){
Write-host "Processing $Computer-----------------------------------------------" -foreground "Green"
Write-host "$Computer has the following local users on it:" -foreground "DarkCyan"
# Loop through each user checking is account already exist.
Foreach ($Luser in $LocalUsers){
$ShowName = $Luser.name
Write-host "Found user $ShowName" -foreground "Cyan"
IF($Luser.name -eq $NewLocAdmin){
$Found = "Yes"
}
}

If ($Found -ne "Yes"){
Write-host "The Local User account you are creating does not already exist on $Computer it will be created!!" -foreground "Yellow"
Create-LocalAdmin -Machine $Computer -ObjectType "User" -ObjectName $NewLocAdmin -Plainpassword $Password -Action "Create"
}
ELSE{
Write-host "That local User account already exist on $Computer." -foreground "DarkCyan"
Write-host "Attempting to add account to Admin group on $Computer." -foreground "DarkCyan"
Create-LocalAdmin -Machine $Computer -ObjectType "User" -ObjectName $NewLocAdmin -Plainpassword $Password -Action "AddToAdmin"
} # End IF\ELSE for account check creation.

$LocalUsers = Get-LocalUsers -Machine $Computer

# Convert users list arry into ; deliminated string.
$LocalUsers = $LocalUsers | % {$_.name.tostring()} 
$LocalUsers = $LocalUsers -join ";"

Write-host "Final list of Local users:" -foreground "White"
Write-host "$LocalUsers" -foreground "White"
Write-host "$Computer Completed------------------------------------------------" -foreground "Green"
Write-host ""
}

if ($LocalUsers -eq $null){
Write-Host "Machine $Computer could not be processed!!" -foregroundColor red
Write-Host ""
$Found = "Error Machine not processed"
}


# Create custom object to be used for Excel output file.
	$SnapProperties = @{

    Server = $Computer

    Users =  $LocalUsers
	
	AccountWasPresent = $Found			
    }

$object = New-Object PSObject -Property $SnapProperties

# Add curent object to output object array.		
$AllComputers += $object

}

# Post script results output to screen.
$AllComputers | select Server, Users, AccountWasPresent
Write-host ""
# Excel report export to current directory.
$AllComputers | sort-object Server | select Server, Users,  AccountWasPresent |  Export-Excel -path $filename
