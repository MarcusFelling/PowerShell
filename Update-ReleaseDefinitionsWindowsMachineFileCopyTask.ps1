$TFSBaseURL = ""
$Project = ""

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# Get list of all release definitions
[uri] $script:GetDefinitionsURI = "$TFSBaseURL/$Project/_apis/release/definitions"

# Invoke the REST call and capture the response
$GetDefinitionsUriResponse = Invoke-RestMethod -Uri $GetDefinitionsURI -Method Get -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
$DefinitionIDs = $GetDefinitionsUriResponse.value.id

ForEach($DefinitionID in $DefinitionIDs){
    [uri] $script:GetDefinitionsURI = "$TFSBaseURL/$Project/_apis/release/definitions/$DefinitionID"
    $GetDefinitionsUriResponse = Invoke-RestMethod -Uri $GetDefinitionsURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
    $FileCopyTasks = $GetDefinitionsUriResponse.environments.deployPhases.workflowTasks | Where-Object refName -like "WindowsMachineFileCopy*"
    ForEach($Task in $FileCopyTasks){        
        # Update task to v2
        $Task.version = '2.*'

        # Bug #1 MachineName was lost in upgrade, add it back using EnvironmentName
        $Task.inputs.MachineNames = $Task.inputs.EnvironmentName
        }
    } 

    # Convert response to JSON to be used in Put below
    $Definition = $GetDefinitionsUriResponse | ConvertTo-Json -Depth 100

    # Use updated response to update definition
    $script:UpdateDefinitionURI = "$TFSBaseURL/$Project/_apis/release/definitions?api-version=5.0"
    $UpdatedDefinition = Invoke-RestMethod -Uri $UpdateDefinitionURI -Method Put -ContentType application/json -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} -Body $Definition
