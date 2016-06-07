# Uploads desired logs to FTP site
# Requires PowerShell V 3.0, 7-Zip

#UI Settings
$a = (Get-Host).UI.RawUI
$b = $a.WindowSize
$b.Width = 60
$b.Height = 30
$a.WindowSize = $b

[int]$serverNumber = read-host "Upload logs to FTP`n1-Grp-Test`n2-iGrp-Test`n3-Grp-Stage`n4-iGrp-Stage`n5-Grp-Production`n6-iGrp-Production`nSelect number"

switch($serverNumber){
        
        #Grp-Test
     1 {$Dir0 = "\\$machineName\$drive\$JBossDir\server\$node\log\*"
        $Dir1 = "\\$machineName\$drive\$JBossDir\server\$node\log\*"
        $Dir2 = "\\$machineName\$drive\logs\*"
        $Environment = "Test"
        $indOrGroup = "Grp"}
        #Ind-Test
     2 {$Dir0 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir1 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir2 = "\\$machineName\$drive\logs\*" 
        $Environment = "Test"
        $indOrGroup = "Ind"}
        #Note-Express logs from stage/prod include both environments
        #Grp-Stage
     3 {$Dir0 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir1 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir2 = "\\$machineName\$drive\logs\*"
        $Dir3 = "\\$machineName\$drive\logs\*" 
        $Environment = "Stage"
        $indOrGroup = "Grp"}
        #Ind-Stage
     4 {$Dir0 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir1 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir2 = "\\$machineName\$drive\logs\*"
        $Dir3 = "\\$machineName\$drive\logs\*" 
        $Environment = "Stage"
        $indOrGroup = "Ind"}
        #Grp-Production
     5 {$Dir0 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir1 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir2 = "\\$machineName\$drive\$JBossDir\server\$node\log\*"  
        $Dir3 = "\\$machineName\$drive\$JBossDir\server\$node\log\*"
        $Dir4 = "\\$machineName\$drive\logs\*"
        $Dir5 = "\\$machineName\$drive\logs\*" 
        $Environment = "Production"
        $indOrGroup = "Grp"}
        #Ind Production
     6 {$Dir0 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir1 = "\\$machineName\$drive\$JBossDir\server\$node\log\*" 
        $Dir2 = "\\$machineName\$drive\$JBossDir\server\$node\log\*"  
        $Dir3 = "\\$machineName\$drive\$JBossDir\server\$node\log\*"
        $Dir4 = "\\$machineName\$drive\logs\*"
        $Dir5 = "\\$machineName\$drive\logs\*" 
        $Environment = "Production"
        $indOrGroup = "Ind"}
     default {"Directory could not be determined."}
     }

# Copy log files to network drive and zip before upload.
# Delete and recreate folders so previously uploaded files are not included
Remove-Item \\example\Logs\Dir* -Recurse -Force
New-Item -ItemType Directory\example\Logs\Dir0
New-Item -ItemType Directory\example\Logs\Dir1
New-Item -ItemType Directory\example\Logs\Dir2
if($Environment -eq "Production" -OR $Environment -eq "Stage"){
New-Item -ItemType Directory\example\Logs\Dir3}
if($Environment -eq "Production"){
New-Item -ItemType Directory\example\Logs\Dir4
New-Item -ItemType Directory\example\Logs\Dir5}

# Mulitple folders required because copy-item forced to overwrite files (no dupes allowed)
Copy-Item $Dir0 \\example\Logs\Dir0 -Force -Recurse
Copy-Item $Dir1 \\example\Logs\Dir1 -Force -Recurse
Copy-Item $Dir2 \\example\Logs\Dir2 -Force -Recurse

# Staging has 2 JBoss nodes 2 express/ Production has 4 JBoss Nodes and 2 express
If($Environment -eq "Production" -or $Environment -eq "Stage"){
        Copy-Item $Dir3 \\example\Logs\Dir3 -Force -Recurse
 }
If($Environment -eq "Production"){
        Copy-Item $Dir4 \\example\Logs\Dir4 -Force -Recurse
        Copy-Item $Dir5 \\example\Logs\Dir5 -Force -Recurse
 }

# 7-Zip required to zip logs, make sure it's installed
if(-not (test-path "$env:ProgramFiles\7-Zip\7z.exe")) 
{
    throw "$env:ProgramFiles\7-Zip\7z.exe needed"
} 
# Set Alias for 7-zip to sz
set-alias sz "$env:ProgramFiles\7-Zip\7z.exe" 

# Directory of logs to zip
$filePath = "\\example\Repository\logs" 
$logs = Get-ChildItem -Recurse -Path $filePath | 
Where-Object { $_.Extension -eq ".log" } 

# Place new logs.zip in \example\Logs\
foreach ($file in $logs) 
        { 
          sz a -t7z "\example\Repository\Logs" "\example\Logs"      
        }

# ftp server info
$ftp = ""
$user = "" 
$pass = "" 
 
$webclient = New-Object System.Net.WebClient 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)  

# Uploads logs.zip to FTP
foreach($item in (dir "\example\" "*.7z")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 }

[int]$sendEmail = Read-Host "Send email to Bob? (1) Yes (2) No"

if($sendEmail -eq 1)
{
   Send-MailMessage -To "Bob@Bob.com" -SmtpServer mail.bob.com -Subject "$indOrGroup - $Environment logs have been uploaded to FTP"
}
