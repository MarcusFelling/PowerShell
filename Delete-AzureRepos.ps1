<#
    .Description
        Nukes all Git repos in an Azure DevOps Org.  
#>

$PAT = "" # Personal Access Token
$AzureDevOpsOrgURL = "" 

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# URI to get list of all Projects in Org
[uri] $script:GetProjectsURI = "$AzureDevOpsOrgURL/_apis/projects"

# Get list of all Projects in Org
$GetProjectsResponse = Invoke-RestMethod -Uri $GetProjectsURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
$Projects = $GetProjectsResponse.value.name

# Loop through each project and get repo ID
ForEach($Project in $Projects){ 
    # URI to get project repos
    [uri] $script:GetProjectReposURI = "$AzureDevOpsOrgURL/$Project/_apis/git/repositories?api-version=5.0"
    $GetProjectReposResponse = Invoke-RestMethod -Uri $GetProjectReposURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
    $RepoIDs = $GetProjectReposResponse.value.id

    # Loop through each repo ID in project and DELETE
    ForEach($RepoID in $RepoIDs){ 
        If($RepoID){
            "Deleting repo from $Project"
            [uri] $script:DeleteRepoURI = "$AzureDevOpsOrgURL/$Project/_apis/git/repositories/$RepoID`?api-version=5.0"
            $DeleteRepoResponse = Invoke-RestMethod -Uri $DeleteRepoURI -Method DELETE -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
        }
    }
}
