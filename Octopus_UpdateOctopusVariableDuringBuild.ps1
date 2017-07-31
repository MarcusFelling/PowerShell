<#
.DESCRIPTION
   Script to update Octopus variable via Octopus API.
   Can be run manually or automated through an Orchestration tool/build system
   such as TFS/VSTS, Jenkins, TeamCity, etc.
   
.EXAMPLE
   Example build step using TFS/VSTS to update BuildID Octopus variable with build ID system variable value
   1. Add VSTS/TFS PowerShell script build step
   2. Add APIKey as secret build definition variable
   3. Pass as arguments in build step: BuildID $(Build.BuildID) $(APIKey) OctopusProjectName "http://MyOctopusInstance/octopus/"
#>

Param
(
    # Variable name to update
    [string(Mandatory=$true)]$VarName,
    
    # New value for variable
    [string(Mandatory=$true)]$Newvalue,
    
    # Octopus APIKey (should be encrypted build variable)
    [string(Mandatory=$true)]$APIKey,
    
    # Octopus Project Name
    [string(Mandatory=$true)]$ProjectName,
    
    # URL to your Octopus server instance
    [string(Mandatory=$true)]$OctopusURL
)

Function UpdateOctopusVariable
{
    Begin
    {
        <# 
        Load required assemblies. They can be found in the Octopus Tentacle MSI: https://octopus.com/downloads
        These should be copied to your build server(s) if running via TFS/VSTS build.
        #>
        Add-Type -Path "$env:PROGRAMFILES\Octopus\Newtonsoft.Json.dll"
        Add-Type -Path "$env:PROGRAMFILES\Octopus\Octopus.Client.dll"    

        # Connection data
        $endpoint = new-object Octopus.Client.OctopusServerEndpoint ($OctopusURL, $APIKey)
        $repository = new-object Octopus.Client.OctopusRepository $endpoint
    }
    
    Process
    {
        # Get project
        $project = $repository.Projects.FindByName($ProjectName)

        # Get project's variable set
        $variableset = $repository.VariableSets.Get($project.links.variables)

        # Get variable to update    
        $variable = $variableset.Variables | ?{$_.name -eq $VarName}

        # Update variable
        $variable.Value = $newvalue
    }
    
    End
    {
        # Save variable set
        $repository.VariableSets.Modify($variableset)
    }
}
Try
{
    write-host "Begin updating variable: $VarName value:$Newvalue "
    UpdateOctopusVariable
    write-host "Done updating variable: $VarName value:$Newvalue "

}
Catch
{
    $result += $actionFailed
    $result += "`r`n   Exception Type: $($_.Exception.GetType().FullName)"
    $result += "`r`n   Exception Message: $($_.Exception.Message)"
    Exit 1
}
