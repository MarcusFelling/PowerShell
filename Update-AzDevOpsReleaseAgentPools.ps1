<#
.Description
   Script used to bulk update Azure Pipeline release definition's and set agent pools to Default
#>

$PAT = "6up2qi26kkrcetyqruudggvbqwj75f7t4jw2bcjbkcno3yiisceq"
$AzureDevOpsOrgURL = "https://dev.azure.com/MSFT-MarcusFelling" # https://dev.azure.com/{organization}
$AzureDevOpsVSRMURL = $AzureDevOpsOrgURL -replace "dev.azure.com", "vsrm.dev.azure.com" # Add vsrm (visual studio release management) to URI 

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# Get all projects in organization
[uri] $script:GetProjectsUri = "$AzureDevOpsOrgURL/_apis/projects`?api-version=5.1"
$GetProjectsResponse = Invoke-RestMethod -Uri $GetProjectsUri -Method Get -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}

# Get name of projects from response object
$Projects = $GetProjectsResponse.value.name

# Loop through each project and update it's build and release definitions
ForEach($Project in $Projects){
    "Updating definitions in Project: $Project"

    # Get Queue ID for project 
    [uri] $script:GetQueueURI = "$AzureDevOpsOrgURL/$Project/_apis/distributedtask/queues"
    $GetQueueResponse = Invoke-RestMethod -Uri $GetQueueURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
    
    $QueueID = $GetQueueResponse.value | Where-Object {$_.name -eq "Default"}
    $QueueID = $QueueID.id

    If($QueueID){

        # Get all release definitions in project
        [uri] $script:GetReleaseDefinitionsUri = "$AzureDevOpsVSRMURL/$Project/_apis/Release/definitions"
        
        Try{
            $GetReleaseDefinitionsResponse = Invoke-RestMethod -Uri $GetReleaseDefinitionsUri -Method Get -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
        }
        Catch{
            "Did not find releases in project: $Project"
            Continue
        }
        # Get definition ID's from response object
        $DefinitionIDs = $GetReleaseDefinitionsResponse.value.id

        # Loop through and request each definition
        ForEach($DefinitionID in $DefinitionIDs){
            
            [uri] $script:GetDefinitionURI = "$AzureDevOpsVSRMURL/$Project/_apis/release/definitions/$DefinitionID`?`$expand=Environments"
            $GetDefinitionResponse = Invoke-RestMethod -Uri $GetDefinitionURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
            
            # Convert response to JSON to be used in Put below
            $Definition = $GetDefinitionResponse | ConvertTo-Json -Depth 100
           
            # Set Agent Pool to Default if 0
            $Definition = $Definition -replace "`"queueId`":  \d+", "`"queueId`":  $QueueID"

            # Use updated response to update definition
            # Note: Release Definition ID is not needed in URI for PUT
            $script:UpdateDefinitionURI = "$AzureDevOpsVSRMURL/$Project/_apis/release/definitions`?api-version=5.0"
            Invoke-RestMethod -Uri $UpdateDefinitionURI -Method Put -ContentType application/json -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} -Body $Definition
        }
    }
    Else{
        "Did not find Default queue in project: $Project"
    }
}    


