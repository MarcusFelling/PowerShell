# Script to update Octopus Variable via Octopus API
param(
[string]$global:VarName, # Variable name to update. Passed via Build definition
[string]$global:newvalue, # New value for variable. Passed via Build definition
[string]$global:APIKey # Octopus APIKey passed as encrypted build variable
)

Function UpdateOctopusVariable
{
    # Load required assemblies
    Add-Type -Path "C:\Program Files (x86)\Octopus\Newtonsoft.Json.dll"
    Add-Type -Path "C:\Program Files (x86)\Octopus\Octopus.Client.dll"    

    #Connection data
    $OctopusURL = ""
    $projectName = ""
    $endpoint = new-object Octopus.Client.OctopusServerEndpoint ($OctopusURL, $APIKey)
    $repository = new-object Octopus.Client.OctopusRepository $endpoint

    #Get Project
    $project = $repository.Projects.FindByName($projectName)

    #Get Project's variable set
    $variableset = $repository.VariableSets.Get($project.links.variables)

    #Get variable to update    
    $variable = $variableset.Variables | ?{$_.name -eq $Varname}

    #Update variable
    $variable.Value = $newvalue

    #Save variable set
    $repository.VariableSets.Modify($variableset)
}
Try
{
    write-host "Updating variable: $VarName value:$newvalue "
    UpdateOctopusVariable

}
Catch
{
    $result += $actionFailed
    $result += "`r`n   Exception Type: $($_.Exception.GetType().FullName)"
    $result += "`r`n   Exception Message: $($_.Exception.Message)"
    Exit 1
}
Finally
{
    # Clear global variables to cleanup 
    Clear-Variable newvalue -Scope Global
    Clear-Variable APIKey -Scope Global
    Clear-Variable VarName -Scope Global
}
