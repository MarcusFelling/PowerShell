# Script to deploy SSIS package (ISPAC) 
# ISPAC is built using devenv.exe 
# Use computer name to get IP then store in $server variable for connection string below
$server = $env:computername
$ips = [System.Net.Dns]::GetHostAddresses($server)[0].IPAddressToString;
$server = $ips
write-host "Server IP:" $server

# Load the IntegrationServices Assembly  
$loadStatus = [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices,Culture=neutral")                     
             
# Create a connection to the server            
$constr = "Data Source=$server;Initial Catalog=master;Integrated Security=SSPI;"           
$con = New-Object System.Data.SqlClient.SqlConnection $constr
 
# Store the IntegrationServices Assembly namespace to avoid typing it every time  
$ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"    
Write-Host "Connecting to server ..."   

# Create the Integration Services object        
$ssis = New-Object $ISNamespace".IntegrationServices" $con
 
# Check if catalog exists
if ($ssis.Catalogs.Count -eq 0)
{
    Write-Error "SSISDB doesn't exist"
    throw "SSISDB doesn't exist"
}

# Set catalog to SSISDB 
$cat = $ssis.Catalogs["SSISDB"]

# If $ProjectName folder in SSISDB doesn't exist, create it
$folderName = "$ProjectName"
if ($cat.Folders[$folderName] -eq $null)
{
    Write-Host "Creating new folder" $folderName
    $newfolder = New-Object $ISNamespace".CatalogFolder" ($cat, $folderName, "Description")     
    $newfolder.Create()
}

# Set folder to catalog folder ($ProjectName)
$folder = $cat.Folders[$folderName]

# Set dir of ISPAC file 
$localToLocalETLFullPath = "$PSScriptRoot\bin\$ProjectName.$DatabaseName.ispac"

# Read the project file, and deploy it to the folder
Write-Host "Deploying SSIS project ..."           
[byte[]] $projectFile = [System.IO.File]::ReadAllBytes($localToLocalETLFullPath)            
$folder.DeployProject("$ProjectName.$DatabaseName.ETL", $projectFile)
