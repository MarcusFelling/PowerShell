#region IIS functions

Function Install-DotNetCoreHostingBundle {
    <#
    .Synopsis
    Install dotnet core hosting bundle (if not already installed)

    .Description
    Checks if dotnet core hosting bundle is already installed. If it is, do nothing. 
    If it is not, use dotnet-hosting-2.1.6-win.exe to install the bundle quietly.

    After the install, resets IIS to pick up changes made to system PATH en variable

    .Example
    Install-DotNetCoreHostingBundle
    #>    
    $vm_dotnet_core_hosting_module = Get-WebGlobalModule | where-object { $_.name.ToLower() -eq "aspnetcoremodule" }
    If (!$vm_dotnet_core_hosting_module){
        ".Net core hosting module is not installed."
        "Starting install of dotnet-hosting-2.1.6..."        
        .\dotnet-hosting-2.1.6-win.exe /install /quiet /norestart 
    
        # Restarting IIS picks up a change to the system PATH, which is an environment variable, made by the installer.
        "Restarting IIS to pick up changes to system PATH..."
        cmd.exe /c "net stop was /y"
        cmd.exe /c "net start w3svc"
    }
    Else{
        ".Net core hosting bundle already installed."
    }
}

Function Install-IISURLRewrite {
    <#
    .Synopsis
    Install IIS URL Rewrite module (if not already installed)

    .Description
    Checks if IIS URL Rewrite module is already installed, if it is, do nothing. 
    If it is not, use WebPlatformInstaller_amd64_en-US.msi to install the quietly.

    .Example
    Install-IISURLRewrite 
    #>       
    $vm_URL_Rewrite_module = Get-WebGlobalModule | where-object { $_.name.ToLower() -eq "RewriteModule" }
    If (!$vm_URL_Rewrite_module){
        "URL Rewrite module is not installed."
        "Starting install of urlrewrite2.exe..."        
        Start-Process './WebPlatformInstaller_amd64_en-US.msi' '/qn' -PassThru | Wait-Process
        Set-Location 'C:/Program Files/Microsoft/Web Platform Installer'; .\WebpiCmd.exe /Install /Products:'UrlRewrite2' /AcceptEULA     
    }
    Else{
        "URL Rewrite module already installed."
    }
}

Function New-AppPool {
<#
 .Synopsis
  Creates new IIS Application Pool (if it does not exist)

 .Description
  Checks if app pool exists, if it does do nothing.
  If it does not, create it.

 .Example
 New-AppPool -iisAppPoolName "TestAppPoolName" -iisIdentity "DOMAIN\FakeUser"
#>    
[CmdletBinding()]
Param
(
    [Parameter(Mandatory)]
    $iisAppPoolName,    
    [Parameter(Mandatory)]        
    $iisIdentity,
    [Parameter(Mandatory=$false)]
    $iisAppPoolDotNetVersion = "",
    [Parameter(Mandatory=$false)]
    $iisAppPoolManagedPipelineMode = ""
)

    # WebAdministration Module Required
    Import-Module WebAdministration
    
    # Navigate to the app pools root
    Set-Location IIS:\AppPools

    # Check if the app pool exists
    If (!(Test-Path $iisAppPoolName -pathType container)) {
        # Create the app pool
        "App pool does not exist."
        "Creating $iisAppPoolName app pool..."
        $appPool = New-Item $iisAppPoolName 
        $appPoolPath = "IIS:\AppPools\"+ $appPool.name
        "Resetting IIS to avoid locks on applicationHost.config"
        iisreset /restart
        Set-ItemProperty $appPoolPath -Name managedRuntimeVersion -Value $iisAppPoolDotNetVersion
        "Set managedRuntimeVersion"
        "Resetting IIS to avoid locks on applicationHost.config..."
        iisreset /restart
        Set-ItemProperty $appPoolPath -Name processModel -Value @{userName="$iisIdentity";password="$iisIdentityPassword";identitytype=3} -Force    
        "Set app pool to run as: $iisIdentity "

        # Default Managed Pipeline Mode is Integrated. 
        # If param $iisAppPoolManagedPipelineMode is set to Classic, set it.
        If($iisAppPoolManagedPipelineMode -eq "Classic"){
            "Setting Managed Pipeline Mode to Classic..."
            $iisAppPool = Get-Item IIS:\AppPools\$iisAppPoolName
            $iisAppPool.managedPipelineMode="Classic"
            $iisAppPool | set-item
        }
        "App pool created."
    }
    Else{
        "App pool already exists."
    }
}

Function New-WindowsAuthWebApp {
<#
 .Synopsis
  Creates new IIS Application that uses Windows Auth (if it does not exist)

 .Description
  Checks if app exists, if it does, do nothing.
  If it does not, create it and enable Windows auth.

 .Example
 New-WindowsAuthWebApp -iisAppPoolName "TestAppPoolName" -iisAppName "TestAppName" -directoryPath "C:\Inetpub"
#>    
[CmdletBinding()]
Param
(
    [Parameter(Mandatory)]
    $iisAppPoolName,
    [Parameter(Mandatory)]
    $iisAppName,      
    [Parameter(Mandatory)]
    $directoryPath
)
    # WebAdministration Module Required
    Import-Module WebAdministration

    # Navigate to the sites root
    Set-Location "IIS:\Sites\Default Web Site"

    # Check if the app exists
    If ( -Not (Get-WebApplication $iisAppName) ) {
       # Create the app
       "App does not exist."
       "Creating $iisAppName..."   
       "Resetting IIS to avoid locks on applicationHost.config..."
        iisreset /restart
        New-WebApplication $iisAppName -ApplicationPool $iisAppPoolName -PhysicalPath $directoryPath -Force
        "App created."
        "Disabling anonymous authentication..."
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value false -PSPath IIS:\\ -location "Default Web Site/$iisAppName"
        "Enabling Windows Auth.."
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value true -PSPath IIS:\\ -location "Default Web Site/$iisAppName"        
    }
    Else{
        "App already exists."
    }
}

Function New-AnonAuthWebApp {
<#
 .Synopsis
  Creates new IIS Application that uses Anonymous Auth (if it does not exist)

 .Description
  Checks if app exists, if it does, do nothing.
  If it does not, create it and enable Anonymous auth.

 .Example
 New-AnonAuthWebApp -iisAppPoolName "TestAppPoolName" -iisAppName "TestAppName" -directoryPath "C:\Inetpub\TestAppName"

#>    
Param
(
    [Parameter(Mandatory)]
    $iisAppPoolName,
    [Parameter(Mandatory)]
    $iisAppName,      
    [Parameter(Mandatory)]
    $directoryPath
)
    # WebAdministration Module Required
    Import-Module WebAdministration

    # Navigate to the sites root
    Set-Location "IIS:\Sites\Default Web Site"

    # Check if the app exists
    If ( -Not (Get-WebApplication $iisAppName) ) {
       # Create the app
       "App does not exist."
       "Creating $iisAppName..."   
       "Resetting IIS to avoid locks on applicationHost.config..."
        iisreset /restart
        New-WebApplication $iisAppName -ApplicationPool $iisAppPoolName -PhysicalPath $directoryPath -Force
        "App created."
        "Enabling anonymous authentication..."
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value true -PSPath IIS:\\ -location "Default Web Site/$iisAppName"
        "Disabling Windows Auth.."
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value false -PSPath IIS:\\ -location "Default Web Site/$iisAppName"        
    }
    Else{
        "App already exists."
    }
}

Function New-Website {
<#
 .Synopsis
  Creates new IIS Website that uses Anonymous Auth (if it does not exist)

 .Description
  Checks if website exists, if it does, do nothing.
  If it does not, create it and enable Anonymous auth.

.Example
 New-Website -iisAppPoolName "TestAppPoolName" -iisAppName "TestAppName" -directoryPath "C:\Inetpub\TestAppName" -iisPort "80" -iisPortSSL "443"

#>    
[CmdletBinding()]
Param
(
    [Parameter(Mandatory)]
    $iisAppPoolName,
    [Parameter(Mandatory)]
    $iisAppName,
    [Parameter(Mandatory)]
    $directoryPath,
    [Parameter(Mandatory)]
    $iisPort,
    [Parameter(Mandatory)]
    $iisPortSSL
)
    # WebAdministration Module Required
    Import-Module WebAdministration

    # Navigate to the sites root
    Set-Location "IIS:\Sites"

    # Check if the app exists
    If ( -Not (Get-Website $iisAppName) ) {
       # Create the app
       "Website does not exist."
       "Creating $iisAppName..." 
       "Resetting IIS to avoid locks on applicationHost.config..."
        iisreset /restart

        # Create Website
        New-Website -Name $iisAppName -ApplicationPool $iisAppPoolName -PhysicalPath $directoryPath 
        
        # Add http and https bindings if port for https is passed
        If($iisPortSSL -ne "False"){
            "Getting IP address for binding..."
            $iisIPAddress=((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
            "IP is: $iisIPAddress"
            "Adding https binding..."
            New-WebBinding -Name $iisAppName -Protocol https -Port $iisPortSSL -IPAddress $iisIPAddress -SslFlags 0
            "Adding cert to https binding..."
            $CertCN = "$env:ComputerName"
            $Thumbprint = (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject  -like "*$CertCN*"}).Thumbprint;
            $httpsBinding = Get-WebBinding -Name $iisAppName -Protocol "https"
            $httpsBinding.AddSslCertificate($Thumbprint, "my")
            "Removing default http binding that's added when creating site..."
            Get-WebBinding -Name $iisAppName -Protocol http | Remove-WebBinding
            "Adding new http binding..."
            New-WebBinding -Name $iisAppName -Protocol http -Port $iisPort -IPAddress $iisIPAddress -SslFlags 0       
        }
        Else{
            "Adding http binding..."
            New-WebBinding -Name $iisAppName -Protocol http -Port $iisPort -IPAddress $iisIPAddress -SslFlags 0
        }
        "App created."
        
        "Disabling anonymous authentication..."
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value false -PSPath IIS:\\ -location "$iisAppName"
        "Enabling Windows Auth.."
        Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value true -PSPath IIS:\\ -location "$iisAppName"        
    }
    Else{
        "Website already exists."
    }
}
 #endregion IIS functions