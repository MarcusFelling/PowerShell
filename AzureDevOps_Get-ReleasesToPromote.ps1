<#
.Description
   Script used to gather all releases that have been successfully deployed to QA,
   but not yet promoted to Pre-Prod or Prod environments.

.Outputs
   "C:\Temp\LatestReleases.html"
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

# Create custom object to store output in, that can be used to build HTML report.
$objTemplateObject = New-Object psobject
$objTemplateObject | Add-Member -MemberType NoteProperty -Name DefinitionName -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name Link -Value $null

# Create empty array which will become the output object
$objResult = @()

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
        # Write output to Azure Pipeline log
        $NoDeploymentReleaseDefinitionName | Select-Object -first 1
        $LatestDeployment.release.webAccessUri

        # Create an instance of new object to prepare it with data and later add it to the result array for report          
        $objTemp = $objTemplateObject | Select-Object *

        # Populate the custom object properties
        $objTemp.DefinitionName = $NoDeploymentReleaseDefinitionName | Select-Object -first 1
        $objTemp.Link = $LatestDeployment.release.webAccessUri 

        # Add temp object to output array and get ready to loop back around
        $objResult += $objTemp
    }
}

# Set CSS properties for HTML report 
$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

# Output to HTML file that is sent via email in release definition
$objResult = $objResult | 
ConvertTo-Html @{Label="DefinitionName";Expression={$_.DefinitionName}},@{Label="Link";Expression={ "<a href='$($_.Link)'>$($_.Link)</a>" }} -Head $Header
Add-Type -AssemblyName System.Web
[System.Web.HttpUtility]::HtmlDecode($objResult) | Out-File "C:\Temp\LatestReleases.html"
