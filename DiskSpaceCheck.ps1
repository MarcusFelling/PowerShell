# Sends email if drive has less than 5 GB free space. 

Function checkDiskSpace
{
    # Set e-mail properties
    $smtpServer  = "";
    $smtpFrom = "";
    $smtpTo = ""

    # Create an Array to store the destination hosts to check
    [Array] $machines = ""

    # Execute the Get-WmiObject win32_logicaldisk class against the array of machines
    Get-WmiObject Win32_LogicalDisk -computername $machines -Authentication PacketPrivacy -Impersonation Impersonate | 
    Where-Object { $_.DriveType -eq 3 } | 
    Select-Object SystemName,VolumeName,FreeSpace,Size | 
    
    foreach 
    {
        # If FreeSpace is greater than 5GB then do nothing
        If ($_.FreeSpace -gt 5000000000)
            {
                #do nothing
            }
        # Else, if FreeSpace is less than 5GB then send email
        Else
            {
                # Set e-mail subject and body using disk volume and machine name info
                $subject = “Attention: Disk space is running low on ” + $_.SystemName + “”;
                $body = $_.VolumeName + ” drive has less than 5GB.`n”

                # Send e-mail
                $smtpClient = New-Object Net.Mail.SmtpClient($smtpServer);
                $emailFrom  = New-Object Net.Mail.MailAddress $smtpFrom, $smtpFrom;
                $emailTo    = New-Object Net.Mail.MailAddress $smtpTo, $smtpTo;
                $mailMsg    = New-Object Net.Mail.MailMessage($emailFrom, $emailTo, $subject, $body);
                $smtpClient.Send($mailMsg)

            }
    }   
}
Try
{
    checkDiskSpace
}
Catch
{
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
}   
