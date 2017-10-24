<#
    .SYNOPSIS
        Uses the VSTS REST API to create pull request   
     
    .DESCRIPTION
        This script uses the VSTS REST API to create a Pull Request in the specified
        repository, source and target branches. Intended to run via VSTS Build using a build step for each repository.
        https://www.visualstudio.com/en-us/docs/integrate/api/git/pull-requests/pull-requests

    .NOTES
        Existing branch policies are automatically applied.

    .PARAMETER Repository
        Repository to create PR in
    
    .PARAMETER SourceRefName
        The name of the source branch without ref.
    
    .PARAMETER TargetRefName
        The name of the target branch without ref.
    
    .PARAMETER APIVersion
        API versions are in the format {major}.{minor}[-{stage}[.{resource-version}]] - For example, 1.0, 1.1, 1.2-preview, 2.0.
    
    .PARAMETER ReviewerGUID
        ID(s) of the initial reviewer(s). Not mandadory. 
        Can be found in existing PR by using GET https://{instance}/DefaultCollection/{project}/_apis/git/repositories/{repository}/pullRequests/{pullrequestid}?api-version=3.0

    .PARAMETER PAT
        Personal Access token. It's recommended to use a service account and pass via encrypted build definition variable.
#>
[CmdletBinding()]
Param(
    [Parameter(Position=0,Mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$script:Repository,
    [Parameter(Position=1,Mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$script:SourceRefName,
    [Parameter(Position=2,Mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$script:TargetRefName,
    [Parameter(Position=3,Mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$script:APIVersion,
    [Parameter(Position=4,Mandatory=$true,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [int]$script:ReviewerGUID, 
    [Parameter(Position=5,Mandatory=$false,ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$script:PAT 
)

Function CreatePullRequest     
{       
    # Contruct Uri for Pull Requests: https://{instance}/DefaultCollection/{project}/_apis/git/repositories/{repository}/pullRequests?api-version={version}
    # Note: /DefaultCollection/ is required for all VSTS accounts
    # Environment variables are populated when running via VSTS build
    [uri] $PRUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + "/DefaultCollection/" + $env:SYSTEM_TEAMPROJECT + "/_apis/git/repositories/$Repository/pullRequests?api-version=$APIVersion"

    # Base64-encodes the Personal Access Token (PAT) appropriately
    # This is required to pass PAT through HTTP header in Invoke-RestMethod bellow
    $User = "" # Not needed when using PAT, can be set to anything
    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))     

    # Prepend refs/heads/ to branches so shortened version can be used in title
    $Ref = "refs/heads/"
    $SourceBranch = "$Ref" + "$SourceRefName"
    $TargetBranch = "$Ref" + "$TargetRefName"

    # JSON for creating PR with Reviewer specified
    If($ReviewerGUID){
        $JSONBody= @"
        {
            "sourceRefName": "$SourceBranch",
            "targetRefName": "$TargetBranch",
            "title": "Merge $sourceRefName to $targetRefName",
            "description": "PR Created automajically via REST API ",
            "reviewers": [
            {
                "id": { $ReviewerGUID }
            }
            ]
        }
"@
    }
    Else{
        # JSON for creating PR without Reviewer specified
        $JSONBody= @"
        {
          "sourceRefName": "$SourceBranch",
          "targetRefName": "$TargetBranch",
          "title": "Merge $sourceRefName to $targetRefName",
          "description": "PR Created automajically via REST API ",
        }
"@
    }

    # Use URI and JSON above to invoke the REST call and capture the response.
    $Response = Invoke-RestMethod -Uri $PRUri `
                                  -Method Post `
                                  -ContentType "application/json" `
                                  -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} `
                                  -Body $JSONBody  

    # Get new PR info from response
    $script:NewPRID = $Response.pullRequestId
    $script:NewPRURL = $Response.url
}

Try
{
    "Creating PR in $Repository repository: Source branch $SourceRefName Target Branch: $TargetRefName"
    CreatePullRequest
    "Created PR $NewPRID`: $NewPRURL"
}
Catch
{
    $result = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($result)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    $responseBody
    Exit 1 # Fail build if errors
}
