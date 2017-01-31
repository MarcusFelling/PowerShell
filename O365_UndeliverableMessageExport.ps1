<#
.Synopsis
   X Mailbox Undeliverable message export and filter
.DESCRIPTION
   This script uses ExportOSCEXOEmailMessage PowerShell module (in addition to the Exchange Web API) to connect to the O365 X mailbox, 
   search for emails according to X criteria during the last week, exports them, 
   filters the emails for email addresses and saves them to undeliverableEmailList.txt, then sends email with attachment
.OUTPUTS
   undeliverableEmailList.txt
.NOTES
    Prerequisites: 
    Exchange Web API https://www.microsoft.com/en-us/download/details.aspx?id=35371
    Export-OSCEXOEmailMessage module https://gallery.technet.microsoft.com/office/Export-Email-Messages-from-1419bbe9
#>

Import-Module "ExportOSCEXOEmailMessage.psm1"

# Set directory to store emails and save output
$emailDir = "C:\temp\emails"

# Start WinRM service for remoting (not running by default)
Get-Service "Winrm" | Start-Service

# Connect to O365
# Create secure string for credentials so prompt for get-credential isn't required
$username = "x@x.com"
$password = ''
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $cred -Authentication Basic -AllowRedirection
Import-PSSession $Session

# Connect to OSCEXO
Connect-OSCEXOWebService -Credential $cred

# Create a new search folder using start and end dates; range of last 5 days. 
$EndDate = Get-Date -format G
$StartDateNoFormat = (Get-Date).AddDays(-5)
$StartDate = Get-Date $StartDateNoFormat -Format G

# New search folder includes inbox messages
New-OSCEXOSearchFolder -DisplayName "X.Inbox $EndDate" -Traversal Deep -WellKnownFolderName Inbox -StartDate $StartDate -EndDate $EndDate
Start-Sleep -Seconds 5 # Sleep required: export fails before the search folder creation is complete
# Export search folder results
Get-OSCEXOSearchFolder "Operations.Response.Inbox $EndDate" |
Export-OSCEXOEmailMessage -Path $emailDir -KeepSearchFolder 

# Copy emails with body content matches to valid email folder
$bodyContentMatches = "example"
(Get-ChildItem "$emailDir\*eml" | 
Select-String -SimpleMatch -Pattern $bodyContentMatches |
Select-Object -ExpandProperty path -Unique) |
ForEach-Object{Copy-Item -LiteralPath $_ $emailDir\validEmails}

# Search for all email addresses using regex
$input_path = "$emailDir\validEmails\*eml"
$regex = ‘(\b[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}\b)|(^\..*)’ # Filter valid emails, include lines starting with periods
select-string -SimpleMatch -Path $input_path -Pattern "MsoNormal" -context 1,3 | 
ForEach {$_ -Replace "@", ""}

select-string -Path $input_path -Pattern $regex -AllMatches | 
# Exclude X addresses, postmaster, addresses with more than 8 digits, misc.
Where-Object {$_ -NotLike "*X*" -and $_ -NotLike "*X*" |
% { $_.Matches } | 
% { $_.Value } > $emailDir\validEmails\undeliverableEmailListDupes.txt

# Remove duplicates
$date = Get-Date -Format D # File timestamp for output
Get-Content $emailDir\validEmails\undeliverableEmailListDupes.txt | 
Where-Object {$_ -notmatch "(.*\d.*){6}" -and $_ -notmatch '^[\.].*'} | # Remove lines starting with periods
sort | 
select -unique > "$emailDir\validEmails\undeliverableEmailList_$date.txt"

# Send email to x with attachment
$un = "domain\x@x.com"
$pw = ''
$secstring = New-Object -TypeName System.Security.SecureString
$pw.ToCharArray() | ForEach-Object {$secstring.AppendChar($_)}
$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $un, $secstring
Send-MailMessage -To X@X.com -cc X@X.com -Subject "Undeliverable Email List $StartDate - $EndDate" -Attachments "$emailDir\validEmails\undeliverableEmailList_$date.txt" -From "X@X.com" -SmtpServer smtp.office365.com -Port 587 -Credential $credential -UseSsl 

# Cleanup
Get-Item $emailDir\*.eml | Remove-Item
Get-Item $emailDir\validEmails\*.eml | Remove-Item
Get-Item $emailDir\validEmails\undeliverableEmailListDupes.txt | Remove-Item
