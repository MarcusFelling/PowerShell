<#
.SYNOPSIS
    Uses the VSTS REST API to create pull request    
.DESCRIPTION
    This script uses the VSTS REST API to create a Pull Request in the specified
    repository, source and target branches. Intended to run via VSTS Build using a build step for each repository.
    https://www.visualstudio.com/en-us/docs/integrate/api/git/pull-requests/pull-requests
.NOTES
    -Existing branch policies are automatically applied.
#>
Param(
    $script:Repository, # Repository to create PR in
    $script:SourceRefName, # The name of the source branch without ref.
    $script:TargetRefName, # The name of the target branch without ref.
    $script:APIVersion, # API Version (currently api-version=3.0)
    $script:ReviewerGUID, # Reviewer GUID. Find in existing PR by using GET https://{instance}/DefaultCollection/{project}/_apis/git/repositories/{repository}/pullRequests/{pullrequestid}?api-version=3.0
    $script:PAT # Personal Access token passed via encrypted build definition variable. It's recommended to use a service account.
)

Function CreatePullRequest     
{       
    # Contruct Uri for Pull Requests: https://{instance}/DefaultCollection/{project}/_apis/git/repositories/{repository}/pullRequests?api-version={version}
    # Note: /DefaultCollection/ is required for all VSTS accounts
    # Environment variables are populated when running via VSTS build
    [uri] $PRUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + "/DefaultCollection/" + $env:SYSTEM_TEAMPROJECT + "/_apis/git/repositories/$Repository/pullRequests?api-version=$APIVersion"

    # Base64-encodes the Personal Access Token (PAT) appropriately
    # This is required to pass PAT through HTTP header in Invoke-RestMethod bellow
    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$PAT)))     

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

    # Use URI and JSON above to invoke the REST call and capture the response.
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
    Write-Host $responseBody
    exit 1 # Fail build if errors
}

