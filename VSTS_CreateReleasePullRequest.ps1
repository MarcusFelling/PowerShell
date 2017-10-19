<#
.SYNOPSIS
    Uses the VSTS REST API to create pull request
    https://www.visualstudio.com/en-us/docs/integrate/api/git/pull-requests/pull-requests
.DESCRIPTION
    This script uses the VSTS REST API to create a Pull Request in the specified
    repository, source and target branches.
.NOTES
    Build definition that is triggered at the end of the sprint runs this script for each repository 
    to create PR's using source branch: develop target branch: Release
#>
param(
    $script:Repository, # Repository to create PR in
    $script:SourceRefName, # The name of the source branch. 
    $script:TargetRefName, # The name of the target branch.
    $script:APIVersion, # API Version (currently api-version=3.0)
    $script:ReviewerGUID, # Reviewer GUID. Find in existing PR by using GET https://outselldev.visualstudio.com/DefaultCollection/DEP/_apis/git/repositories/DEP/pullRequests/$PullRequestID?api-version=3.0
    $script:User, # Null when using PAT 
    $script:PAT # Encrypted token passed via build definition
)

Function CreatePullRequest     
{       
    # Use VSTS REST API: POST https://{instance}/DefaultCollection/{project}/_apis/git/repositories/{repository}/pullRequests?api-version={version}
    [uri] $global:PRUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + "/DefaultCollection/" + $env:SYSTEM_TEAMPROJECT + "/_apis/git/repositories/$Repository/pullRequests?api-version=$APIVersion"

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))     

    # Prepend refs/heads/ to branches so shortened version can be used in title
    $Ref = "refs/heads/"
    $SourceBranch = "$Ref" + "$SourceRefName"
    $TargetBranch = "$Ref" + "$TargetRefName"

    # JSON for creating PR
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

    # Use URI and JSON above to apply approver policy to specified branch
    $Response = Invoke-RestMethod -Uri $PRUri -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} -Body $JSONBody

    # Get new PR info from response
    $script:NewPRID = $Response.pullRequestId
    $script:NewPRURL = $Response.url
}

Try
{
    write-host "Creating PR in $Repository repository: Source branch $SourceRefName Target Branch: $TargetRefName"
    CreatePullRequest
    write-host "Created PR $NewPRID`: $NewPRURL"
}
Catch
{
    $result = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($result)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    write-host $responseBody
    exit 1
}

