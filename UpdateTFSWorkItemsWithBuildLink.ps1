# Adds build link to associate work items
# Runs as the last step in build definitions   

param(
[string]$passwd
)

Function UpdateWorkItemsWithBuildLink      
{      
    $tfsUrl = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI" 
    $user = ""
    # Encrypted password passed via build definition
	$secpasswd = ConvertTo-SecureString $passwd -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
 
    # Uri to get associated work items: https://www.visualstudio.com/en-us/integrate/api/build/builds#GetbuilddetailsWorkitems
    [uri] $BuildWorkItemsUri = $tfsUrl + $env:SYSTEM_TEAMPROJECT + "/_apis/build/builds/" + $env:BUILD_BUILDID +"/workitems?api-version=2.0"
    write-host $BuildWorkItemsUri
	
    try
    {
        # Get build details: Workitems
        $results = Invoke-RestMethod -Uri $BuildWorkItemsUri -Method Get -Credential $credential
        write-host $results
    }
    catch
    {
        # Catch 404 and move on
        $_.Exception.Response.StatusCode.Value__
    }

    $WorkitemIDs = $results.value.id

    # List array of associated work items
    write-host "Associated Work Item IDs:"$WorkitemIDs
     
    # Loop through each work item and update with link to build
    ForEach($WorkItemID in $WorkitemIDs)
        {
        # Uri to add hyperlink to work items: https://www.visualstudio.com/integrate/api/wit/work-items#UpdateworkitemsAddalink
        [uri] $WorkItemLinkUri = $tfsUrl + "_apis/wit/workitems/" + $WorkItemID +"?api-version=1.0"
        write-host $WorkItemLinkUri
        
$JSONBody= @"
    [{
    "op": "add",
    "path": "/relations/-",
    "value": {
        "rel": "Hyperlink",
        "url": " $tfsUrl$env:SYSTEM_TEAMPROJECT/_build#buildId=$env:BUILD_BUILDID&_a=summary"
    }
    }]
"@
        # Add a link to each work item with build link
        Invoke-RestMethod -Uri $WorkItemLinkUri -Method Patch -ContentType application/json-patch+json -Body $JSONBody -Credential $credential        
        }
}

Try
{
    UpdateWorkItemsWithBuildLink
}
Catch
{
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
}