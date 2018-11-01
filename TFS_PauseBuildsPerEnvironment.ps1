
<#      
    .DESCRIPTION
        Gets all build definitions for specified environment name,
        enables or disables the CI triggers in order to prevent builds from
        being queued during demo's.

    .PARAMETER Action
        Enable or Disable  build definition CI triggers

    .PARAMETER EnvironmentName
        Name of environment to disable/enable builds for

    .PARAMETER PAT
        Personal Access token. It's recommended to use a service account and pass via encrypted build definition variable.

    .Notes
        -These parameters are outside of functions in order to be passed by TFS build definition variables
        -Triggers aren't actually "disabled", just flipped Include/Exclude on path filter
#>
[CmdletBinding()]
Param(
[Parameter(Position=0,Mandatory)]
[ValidateSet("Enable","Disable")]
[string]$script:Action,
[Parameter(Position=1,Mandatory)]
[ValidateSet("Environment1","Environment2","Environment3")] # Case is ignored by default
[string]$script:EnvironmentName,
[Parameter(Position=2,Mandatory)]
[ValidateNotNullOrEmpty()]
[string]$script:PAT
)

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

Function Get-BuildDefinitionsByEnvironment {
<#      
    .OUTPUT
        DefinitionIDs
#>   
    [cmdletbinding()]
    Param(
    )                  
    Try{        
        # https://docs.microsoft.com/en-us/rest/api/vsts/build/definitions/get
        [uri] $script:Uri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $env:SYSTEM_TEAMPROJECT + "/_apis/build/definitions?type=build&name=*$EnvironmentName*"
                
        # Invoke the REST call and capture the response
        $Response = Invoke-RestMethod -Uri $Uri `
                                        -Method Get `
                                        -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} `
        
        "Get-BuildDefinitionsByEnvironment returned response: $Response"
        "Found build definitions:"
        $Response.value.name
        $script:DefinitionIDs = $Response.value.id # Scope variable to "script" to be used in other functions       
    }
    Catch{
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        $responseBody
        Exit 1 
    }                                                         
}

Function Update-BuildDefinitionTriggerPath {   
    [cmdletbinding()]
    Param(
    )    
    Try{        
        # https://docs.microsoft.com/en-us/rest/api/vsts/build/definitions/update
        [uri] $script:Uri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $env:SYSTEM_TEAMPROJECT + "/_apis/build/definitions/$DefinitionID" + "?api-version=3.0"
    
        # Get definition to update, use response for json body to update definition                
        $Definition = Invoke-RestMethod -Uri $Uri `
                                        -Method Get `
                                        -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} 
             
        If($Definition.triggers.pathFilters){
            $DefinitionTriggerPaths = $Definition.triggers.pathFilters
        }
        Else{
            "No path filter, moving on to next definition"
            continue # move to next definition in foreach loop
        }
        # Convert response to JSON to be used in Put below
        $Definition = $Definition | ConvertTo-Json -Depth 100
        
        ForEach($Path in $DefinitionTriggerPaths){
            # Replace first character in path filter: + include, - exclude
            # Example: +$/ED/SCM
            Switch($Action.ToLower()){
                "enable" {
                   $PathAfter = $Path.Replace("-$/","+$/")
                }
                "disable" {
                   $PathAfter = $Path.Replace("+$/","-$/")
                }
                default { 
                    Write-Error "Not a valid action. Actions available: Enable, Disable"
                }
            }   

            # replace old trigger path with new            
            $Definition = $Definition.Replace("$Path","$PathAfter")

        }

        # Use updated response to update definition
        $UpdatedDefinition = Invoke-RestMethod -Uri $Uri `
                                    -Method Put `
                                    -ContentType application/json `
                                    -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} `
                                    -Body $Definition

        "Trigger updated:"
        $UpdatedDefinition.triggers
    }
    Catch{
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($result)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        $responseBody
        Exit 1 
    }                                                                                                                   
}

Try
{
    "Getting build definitions for environment: $EnvironmentName..."
    Get-BuildDefinitionsByEnvironment
    
    "$Action build definition triggers..."
    ForEach($DefinitionID in $DefinitionIDs){
        "$Action trigger for $DefinitionID"
        Update-BuildDefinitionTriggerPath
    }        
}
Catch
{
    Write-Error  $_
    Exit 1
}