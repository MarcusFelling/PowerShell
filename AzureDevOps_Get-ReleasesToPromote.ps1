<#
.Description
   Script used to gather all releases that have been successfully deployed to QA,
   but not yet promoted to Pre-Prod or Prod environments.

.Outputs
   "C:\Temp\LatestQADeployments.csv" 
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]
    $PAT, # Personal Access Token
    [Parameter(Mandatory=$false)]
    $TFSBaseURL
)

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# Get list of all release definitions
[uri] $script:GetDefinitionsUri = "$TFSBaseURL/_apis/Release/definitions"

# Invoke the REST call and capture the response
$GetDefinitionsUriResponse = Invoke-RestMethod -Uri $GetDefinitionsUri -Method Get -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
$DefinitionIDs = $GetDefinitionsUriResponse.value.id

# Use definition ID's to loop and get latest deployments of each definition
ForEach($DefinitionID in $DefinitionIDs){
    [uri] $GetLatestDeployments = "$TFSBaseURL/_apis/release/deployments?definitionId=" + $DefinitionID + "&api-version=4.0-preview&deploymentStatus=succeeded"
    $GetLatestDeploymentsResponse = Invoke-RestMethod -Uri $GetLatestDeployments -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
    
    # Get successful deployments to QA
    $Deployments = ""
    $Deployments =  $GetLatestDeploymentsResponse.value | 
                    Where-Object {$_.releaseEnvironment.name -like "QA*" -AND $_.deploymentStatus -eq "succeeded"}

    # Use first deployment ID in array to pick latest
    Try{
        $LatestDeployment = ""
        $LatestDeployment = $Deployments[0]
    }
    Catch{
        # Do nothing if null array
    }

    # Use Release ID to check if release is already deployed to Pre-Prod or Prod
    $ReleaseId = $LatestDeployment.release.id
    [uri] $GetRelease = "$TFSBaseURL/_apis/Release/releases/" + $ReleaseId + "?api-version=4.0-preview"
    $GetReleaseResponse = Invoke-RestMethod -Uri $GetRelease -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}    
    
    # Get active releases only (not abandoned)
    $GetReleaseResponse = $GetReleaseResponse | Where-Object {$_.status -eq "active"} 

    # Check if deployed to pre-prod or prod yet, and active (not abandoned)
    $NoDeployment = ""
    $NoDeployment = $GetReleaseResponse.environments  | Where-Object {$_.name -like "*PROD*" -AND $_.status -eq "notStarted"}
    $NoDeploymentReleaseDefinitionName = ""
    $NoDeploymentReleaseDefinitionName = $NoDeployment.releaseDefinition.name
    
    If($NoDeployment){
		$NoDeploymentReleaseDefinitionName | Select-Object -first 1
		$LatestDeployment.release.webAccessUri

		# Output to CSV file that is sent via email in release definition
		$NoDeploymentReleaseDefinitionName | Select-Object -first 1 | Out-File "C:\Temp\LatestQADeployments.csv" -Append
		$URLs += $LatestDeployment.release.webAccessUri | Out-File "C:\Temp\LatestQADeployments.csv" -Append
    }
}
