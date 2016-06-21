<#

.SYNOPSIS

This script uses a web request to determine if Lorem Ipsum Application is functioning properly, 
if not, it restarts the Windows Service, waits 15 seconds, 
then attempts the web request again until successful.

.PARAMETER uri 

Resource to validate Lorem Ipsum Application is functioning

.PARAMETER serviceName
 
Display Name of the Lorem Ipsum Application service

.NOTES

This script is run via Task Scheduler and is scheduled to run at startup.

Trigger
Begin the task: At startup

Actions
Action: Start a program
Program/Script: PowerShell
Add arg: .\LoremIpsumApplicationHealthCheck.ps1

#>
Function LoremIpsumApplicationHealthCheck([string]$uri, [string]$serviceName)
{
    Do
    {
        Try
        {
            $webRequest = ""
            $webRequest = Invoke-WebRequest -Uri $uri

        }
        Catch
        {            
            write-host "Health check failed"            
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
            Write-Host "Exception Message: $($_.Exception.Message)"
            $ErrorActionPreference = "Continue"

        }  
        
        If($webRequest.StatusCode -eq "200")
        {
            write-host "Lorem Ipsum Application Passed Health Check"
            $healthCheckResult = "Pass"
        }
        Else
        {
            write-host "Restarting service: $serviceName ...."
            Get-Service -DisplayName $serviceName | Restart-Service          

            # Wait 15 seconds while service starts up before retrying
            Start-Sleep -Seconds 30
                        
            # Increment max retries variable, stop script after 5 attempts 
            $maxRetries += 1
        }        
    }
    # End script once health check passes OR if max retries is hit
    Until($healthCheckResult -eq "Pass" -Or $maxRetries -ge 5)        
}

# Required variables that are passed as arguments to Lorem Ipsum Application HealthCheck function
$uri = ""
$serviceName = ""

Try
{
    LoremIpsumApplicationHealthCheck $uri $serviceName
}
Catch
{
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
}
