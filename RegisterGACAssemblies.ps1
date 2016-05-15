# List of assmemblies to be GAC'd
$assemblyDll = @('example.dll')

# method for adding new assemblies to the GAC
function Add-GacItem([string]$file) {
    Begin
    {
        # see if the Enterprise Services Namespace is registered
        if ($null -eq ([AppDomain]::CurrentDomain.GetAssemblies() |? { $_.FullName -eq "System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=$publicKeyToken" }) ) {
            # register the Enterprise Service .NET library
            [System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=$publicKeyToken") | Out-Null
        }
 
        # create a reference to the publish class
        $publish = New-Object System.EnterpriseServices.Internal.Publish
    }
    Process
    {
        # ensure the file that was provided exists
        if ( -not (Test-Path $file -type Leaf) ) {
            throw "The assembly '$file' does not exist."
        }
 
        # ensure the file is strongly signed before installing in the GAC
        if ( [System.Reflection.Assembly]::LoadFile( $file ).GetName().GetPublicKey().Length -eq 0) {
            throw "The assembly '$file' must be strongly signed."
        }
 
        # install the assembly in the GAC
        Write-Output "Installing: $assembly"
        $publish.GacInstall( $file )
    }
}
 
# method for removing assemblies from the GAC
function Remove-GacItem([string]$file) {
    Begin
    {
        # see if the Enterprise Services Namespace is registered
        if ($null -eq ([AppDomain]::CurrentDomain.GetAssemblies() |? { $_.FullName -eq "System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=$publicKeyToken" }) ) {
            # register the Enterprise Service .NET library
            [System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=$publicKeyToken") | Out-Null
        }
 
        # create a reference to the publish class
        $publish = New-Object System.EnterpriseServices.Internal.Publish
    }
    Process
    {
        # ensure the file that was provided exists
        if ( -not (Test-Path $file -type Leaf) ) {
            throw "The assembly '$file' does not exist."
        }
 
        # ensure the file is strongly signed before installing in the GAC
        if ( [System.Reflection.Assembly]::LoadFile( $file ).GetName().GetPublicKey().Length -eq 0) {
            throw "The assembly '$file' must be strongly signed."
        }
 
        # install the assembly in the GAC
        Write-Output "UnInstalling: $file"
        $publish.GacRemove( $file )
    }
}
 
foreach($file in $assemblyDll)
{

Write-Host $file
$currentDirectory = Get-Location
$file = $currentDirectory.Path + "\" + $file
 
Write-Host "UnRegistering the Assembly: '$file'" 
Remove-GacItem $file

Write-Host "Registering the Assembly: '$file'"
Add-GacItem $file
 

}



