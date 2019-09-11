<#
.Description
   Script used to bulk update Azure Pipeline build definition's agent pools to Default
#>

$PAT = ""
$AzureDevOpsOrgURL = "" # https://dev.azure.com/{organization}

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# Get all projects in organization
[uri] $script:GetProjectsUri = "$AzureDevOpsOrgURL/_apis/projects`?api-version=5.1"
$GetProjectsResponse = Invoke-RestMethod -Uri $GetProjectsUri -Method Get -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}

# Get name of projects from response object
$Projects = $GetProjectsResponse.value.name

# Loop through each project and update it's build and Build definitions
ForEach($Project in $Projects){
    "Updating definitions in Project: $Project"

    # Get Queue ID for project 
    [uri] $script:GetQueueURI = "$AzureDevOpsOrgURL/$Project/_apis/distributedtask/queues"
    $GetQueueResponse = Invoke-RestMethod -Uri $GetQueueURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
    
    $QueueID = $GetQueueResponse.value | Where-Object {$_.name -eq "Default"}
    $QueueID = $QueueID.id

    If($QueueID){

        # Get all Build definitions in project
        [uri] $script:GetBuildDefinitionsUri = "$AzureDevOpsOrgURL/$Project/_apis/build/definitions"
        
        Try{
            $GetBuildDefinitionsResponse = Invoke-RestMethod -Uri $GetBuildDefinitionsUri -Method Get -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
        }
        Catch{
            "Did not find Builds in project: $Project"
            Continue
        }
        # Get definition ID's from response object
        $DefinitionIDs = $GetBuildDefinitionsResponse.value.id

        # Loop through and request each definition
        ForEach($DefinitionID in $DefinitionIDs){
            
            [uri] $script:GetDefinitionURI = "$AzureDevOpsOrgURL/$Project/_apis/build/Definitions/$DefinitionID"
            $GetDefinitionResponse = Invoke-RestMethod -Uri $GetDefinitionURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
            
            # Set Agent pool and all properties to default
            $GetDefinitionResponse.queue | Add-Member -MemberType NoteProperty -Name 'id' -Value $QueueID -Force
            $GetDefinitionResponse.queue | Add-Member -MemberType NoteProperty -Name 'name' -Value "Default" -Force
            $GetDefinitionResponse.queue | Add-Member -MemberType NoteProperty -Name 'url' -Value "$AzureDevOpsOrgURL/_apis/build/Queues/$QueueID" -Force
            If($GetDefinitionResponse.process.phases.target.queue){$GetDefinitionResponse.process.phases.target.queue | Add-Member -MemberType NoteProperty -Name 'id' -Value $QueueID -Force}
            If($GetDefinitionResponse.process.phases.target.queue){$GetDefinitionResponse.process.phases.target.queue | Add-Member -MemberType NoteProperty -Name 'url' -Value "$AzureDevOpsOrgURL/_apis/build/Queues/$QueueID" -Force}
            $GetDefinitionResponse.queue | Add-Member -MemberType NoteProperty -Name 'pool' -Value "" -Force
            $GetDefinitionResponse.queue.pool  | Add-Member -MemberType NoteProperty -Name 'id' -Value 1 -Force
            $GetDefinitionResponse.queue.pool  | Add-Member -MemberType NoteProperty -Name 'name' -Value "Default" -Force
            If($GetDefinitionResponse.queue.pool.isHosted){$GetDefinitionResponse.queue.pool.isHosted = $false}
            If($GetDefinitionResponse.queue.pool.isHosted){$GetDefinitionResponse.process.target.agentSpecification = ""}
             
            # Convert response to JSON to be used in Put below
            $Definition = $GetDefinitionResponse | ConvertTo-Json -Depth 100

            $Definition = $Definition -replace "build/Queues/\d+", "build/Queues/$QueueID"

            # Use updated response to update definition
            # Note: Build Definition ID is not needed in URI for PUT
            $script:UpdateDefinitionURI = "$AzureDevOpsOrgURL/$Project/_apis/Build/definitions/$DefinitionID`?api-version=5.1"
            Invoke-RestMethod -Uri $UpdateDefinitionURI -Method Put -ContentType application/json -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} -Body $Definition
        }
    }
    Else{
        "Did not find Default queue in project: $Project"
    }
}    


