#Sets IIS properties for faster load times

#Load IIS Module if not loaded already
Function WebAdministration-VerifyModule
{
    If ( ! (Get-module WebAdministration )) 
    {
        Try
        {
            Import-Module WebAdministration
        }
        Catch
        {
            Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
            Write-Host "Exception Message: $($_.Exception.Message)"  
        }
    }
    $message = "The module WebAdministration verified at (" + (Get-Date).ToString('yyyy.MM[MMM].dd HH:mm:ss zzz') + ")."
    Write-Host $message
    return $true
}

Function SetIISProperties-AppPools
{
    Try
    {
        #Loop through each app pool
        dir IIS:\Sites | ForEach-Object { $appPool = $_.applicationPool     
        #set start mode to always running
        Set-ItemProperty IIS:\AppPools\$appPool -name startMode -value "alwaysrunning"
        #set idle timeout to 0 seconds
        Set-ItemProperty IIS:\AppPools\$appPool -name processModel.idleTimeout -value "0"
        write-output "$appPool app pool set to startMode:always running, idle timeout: 0 seconds"
        }
    }
    Catch
    {
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
        Write-Host "Exception Message: $($_.Exception.Message)"
    }
}

Function SetIISProperties-Sites
{
    Try
    {
        #Loop through each site
        dir IIS:\Sites | ForEach-Object { $siteName = $_.Name  
        #set preLoadEnabled to true
        Set-WebConfigurationProperty "`/system.applicationHost`/sites`/site[@name=`"$siteName`"]/application" -Name "preloadEnabled" -Value "true" -PSPath IIS:\
        write-output "$siteName site set to preloadEnabled:True"
        }
    }
    Catch
    {
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
        Write-Host "Exception Message: $($_.Exception.Message)"
    }
}

#Verify module then run functions
Try
{
  If (WebAdministration-VerifyModule)
  {
    SetIISProperties-AppPools
    SetIISProperties-Sites
  }
  Else
  {
    Write-Error "Module: WebAdministration did not load!"
  }
}
Catch
{
  Write-Error "Something wrong with Module: WebAdministration"
}

Exit 0
