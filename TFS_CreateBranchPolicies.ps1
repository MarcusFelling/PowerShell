<#
.SYNOPSIS
    Uses the TFS REST API to apply branch policies to specified branch
.DESCRIPTION
    This script uses the TFS REST API for configurations to set branch policies for: 
    -approver group
    -Minimum approvers (2)
    -Required build 
    -Work Item required
.NOTES
    -Branch is set via build definition variable at queue time
#>
param(
[string]$global:branch, # Branch to set policies on passed via build definition when queueing build
[string]$global:user, # Service account user name passed via build definition
[string]$global:passwd # Encrypted password passed via build definition
)

# Use TFS REST API for configurations: https://www.visualstudio.com/en-us/docs/integrate/api/policy/configurations#create-a-policy-configuration
[uri] $global:PolicyUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $env:SYSTEM_TEAMPROJECT + "/_apis/policy/configurations?api-version=2.0-preview"
write-host $PolicyUri

# Create secure credential
$global:secpasswd = ConvertTo-SecureString $passwd -AsPlainText -Force
$global:credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

Function ApplyApproverPolicy     
{       
        
# JSON for setting appovers
$JSONBody= @"
{
    "isEnabled": true,
    "isBlocking": true,
    "type": {
    "id": ""
    },
    "settings": {
    "requiredReviewerIds": [
        ""
    ],
    "filenamePatterns": [
        "/ExamplePath"
    ],
    "addedFilesOnly": false,
    "scope": [
        {
        "repositoryId": null,
        "refName": "refs/heads/$Branch",
        "matchKind": "exact"
        },
        {
        "repositoryId": null,
        "refName": "refs/heads/$Branch/",
        "matchKind": "prefix"
        }
    ]
    }
}
"@

# Use URI and JSON above to apply approver policy to specified branch
Invoke-RestMethod -Uri $PolicyUri -Method Post -ContentType application/json -Body $JSONBody -Credential $credential

}

Function ApplyMinimumApproverPolicy
{

# JSON for setting minimum approval count policy
$JSONBody= @"
{
    "isEnabled": true,
    "isBlocking": true,
    "type": {
    "id": ""
    },
    "settings": {
    "minimumApproverCount": 2,
    "scope": [
        {
        "repositoryId": null,
        "refName": "refs/heads/$branch",
        "matchKind": "exact"
        }
        ]
    }
}
"@

# Use URI and JSON above to apply minimum approver policy to specified branch
Invoke-RestMethod -Uri $PolicyUri -Method Post -ContentType application/json -Body $JSONBody -Credential $credential

}

Function ApplyBuildPolicy
{

# JSON for setting required build policy
$JSONBody= @"
{
    "isEnabled": true,
    "isBlocking": true,
    "type": {
    "id": ""
    },
    "settings": {
    "buildDefinitionId": buildID,
    "scope": [
        {
        "repositoryId": null,
        "refName": "refs/heads/$branch",
        "matchKind": "exact"
        }
        ]
    }
}
"@

# Use URI and JSON above to apply build policy to specified branch
Invoke-RestMethod -Uri $PolicyUri -Method Post -ContentType application/json -Body $JSONBody -Credential $credential

}

Function ApplyWorkItemPolicy
{

# JSON for setting work item required policy
$JSONBody= @"
{
    "isEnabled": true,
    "isBlocking": true,
    "type": {
    "id": ""
    },
    "settings": {
    "scope": [
        {
        "repositoryId": null,
        "refName": "refs/heads/$branch",
        "matchKind": "exact"
        }
        ]
    }
}
"@

# Use URI and JSON above to apply work item required to specified branch
Invoke-RestMethod -Uri $PolicyUri -Method Post -ContentType application/json -Body $JSONBody -Credential $credential

}

Try
{
    ApplyApproverPolicy
    write-host "Approver Policy set on branch: $branch"
    ApplyMinimumApproverPolicy
    write-host "Minimum Approver Policy set on branch: $branch"
    ApplyBuildPolicy
    write-host "Build Policy set on branch: $branch"
    ApplyWorkItemPolicy
    write-host "Work Item required Policy set on branch: $branch"

}
Catch
{
    $result = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($result)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    write-host $responseBody
}
Finally
{
    # Clear global variable to cleanup 
    Clear-Variable user -Scope Global
    Clear-Variable pwd -Scope Global
    Clear-Variable branch -Scope Global
    Clear-Variable PolicyUri -Scope Global
}
