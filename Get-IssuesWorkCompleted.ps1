<#
.Description
   Script used to gather all Issues with linked tasks, then sum the amount of completed work in the linked tasks by A and B Teams.

   Gets list of Issues with tasks with shared query.

.Outputs
   "C:\Temp\IssuesWorkCompleted.html" that is sent via email in release definition
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]
    $PAT, # Personal Access Token
    [Parameter(Mandatory=$false)]
    $AzureDevOpsBaseURL 
)

# https://docs.microsoft.com/en-us/azure/devops/integrate/concepts/rest-api-versioning?view=azure-devops
# Specify api version to prevent breaking changes after upgrdades
$apiVersion = "3.0"

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# Create custom object to store output in, that can be used to build HTML report.
$objTemplateObject = New-Object psobject
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WIID -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WIName -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WICreatedDate -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WICreatedBy -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WIClosedDate -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WITeam -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name WIAreaPath -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name PercentA -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name PercentB -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name ATeam -Value $null
$objTemplateObject | Add-Member -MemberType NoteProperty -Name BTeam -Value $null           

# Create empty array which will become the output object
$objResult = @()

# Get all work items using shared query "All Issues with Closed Tasks"
[uri] $GetWorkItemQueryURI = "$AzureDevOpsBaseURL/_apis/wit/wiql/d32f77bd-2ed5-4c23-aac8-002294f34074" + "?api-version=$apiVersion"
$GetWorkItemQueryResponse = Invoke-RestMethod -Uri $GetWorkItemQueryURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} 

# Get Issues
$Issues = $GetWorkItemQueryResponse.workItemRelations.source.url

# Get rid of dupes
$Issues = $Issues | Select-Object -Unique

# Use AzureDevOps Team "A" to identify A team members
[uri] $GetTeamURI = "$AzureDevOpsBaseURL/_apis/projects/PROJECTNAME/teams/A/members" + "?api-version=$apiVersion"
$GetTeamURIResponse = Invoke-RestMethod -Uri $GetTeamURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)} 
$BTeamMembers = $GetTeamURIResponse.value.uniquename -replace "DOMAINNAME\\", ""

ForEach($Issue in $Issues){   
    $GetIssueWorkItemResponse = Invoke-RestMethod -Uri "$Issue`?api-version=$apiVersion`&`$expand=relations" -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}     

    # Create an instance of new object to prepare it with data and later add it to the result array for report          
    $objTemp = $objTemplateObject | Select-Object *    

    # Get related tasks 
    $relatedWorkItems = $GetIssueWorkItemResponse.relations | Where-Object {$_.rel -like "System.LinkTypes*" -OR $_.rel -like "Microsoft.VSTS*"}
    $relatedWorkItems =  $relatedWorkItems.url
    If($relatedWorkItems){
        ForEach($workItem in $relatedWorkItems){
            $GetRelatedWorkItemResponseURI = $workItem + "?api-version=$apiVersion"
            $GetRelatedWorkItemResponse = Invoke-RestMethod -Uri $GetRelatedWorkItemResponseURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}                        
            If($GetRelatedWorkItemResponse.Fields.'System.WorkItemType' -eq "Task"){                
                $relatedTask = $workItem
                $GetRelatedTaskURI = $relatedTask + "?api-version=$apiVersion"
                $GetRelatedTaskResponse = Invoke-RestMethod -Uri $GetRelatedTaskURI -Method GET -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}

                # Figure out which team is assigned the task, then add completed hours
                $AssignedTo = $GetRelatedTaskResponse.fields.'System.AssignedTo'

                If(!($AssignedTo)){
                    "Task not assigned"
                }
                Else{
                    # Remove First, Last, and Domain name from AssignedTo, we only want username
                    $AssignedTo = ($AssignedTo -split "\", 2, "simplematch")[1]
                    $AssignedTo = $AssignedTo.TrimEnd(">")          
            
                    "Assigned To: " + $AssignedTo
                    If($AssignedTo -in $BTeamMembers){            
                        $objTemp.BTeam += $GetRelatedTaskResponse.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
                        "A Team Hours: " + $objTemp.BTeam
                    }
                    Else{
                        $objTemp.ATeam += $GetRelatedTaskResponse.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
                        "B Team Hours: " + $objTemp.ATeam
                    }
                }                            
            }
        }
        # Only populate object if there is completed work > 0
        If($objTemp.ATeam -gt 0 -OR $objTemp.BTeam -gt 0){
            $objTemp.WIID = $GetIssueWorkItemResponse.id
            $objTemp.WIName = $GetIssueWorkItemResponse.fields.'System.Title'
            $objTemp.WIName = $objTemp.WIName | Select-Object -First 50
            
            $WICreatedDate = $GetIssueWorkItemResponse.fields.'System.CreatedDate'
            $objTemp.WICreatedDate = ($WICreatedDate -split "T", 2, "simplematch")[0]
            $objTemp.WICreatedBy = $GetIssueWorkItemResponse.fields.'System.CreatedBy'           
            $WIClosedDate = $GetIssueWorkItemResponse.fields.'Microsoft.VSTS.Common.ClosedDate'
            $objTemp.WIClosedDate = ($WIClosedDate -split "T", 2, "simplematch")[0]
            $objTemp.WIAreaPath = $GetIssueWorkItemResponse.fields.'System.AreaPath'
            $objTemp.WITeam = $GetIssueWorkItemResponse.fields.'Custom.Team'
            
            # Find percentages between A and B
            $Total = $objTemp.ATeam + $objTemp.BTeam
            $objTemp.PercentA = ($objTemp.ATeam/$Total * 100)
            $objTemp.PercentB = ($objTemp.BTeam/$Total * 100)
        }
    }
    Else{
        "No related work items"
        continue # Move to next iteration in ForEach of Issues
    }    
    # All report fields populated for Issue, add temp object to output array and get ready to loop back around
    $objResult += $objTemp
}

# Output Work Item ID, Work Item Name, Team, and Completed Work to 2nd fragment of HTML file
$Fragment1 = $objResult | 
Select-Object -Property @{n="Issue Work Item ID";e={$_.WIID}},@{n="Issue Work Item Name";e={$_.WIName}},@{n="Created Date";e={$_.WICreatedDate}},@{n="Created By";e={$_.WICreatedBy}},@{n="Closed Date";e={$_.WIClosedDate}},@{n="Area Path";e={$_.WIAreaPath}},@{n="Team";e={$_.WITeam}},@{n="% A";e={$_.PercentA}},@{n="% B";e={$_.PercentB}},@{n="Total Hours A Team";e={$_.ATeam}},@{n="Total Hours B Team";e={$_.BTeam}} |
Sort-Object -Property WIID -Descending |
ConvertTo-Html -Fragment

# Insert boostrap classes and required thead and tbody for sort
$Fragment1 = $Fragment1 -replace '<table>','<table id="IssuesWorkCompleted" class="table tablesorter table-sm table-striped table-bordered table-hover"><thead>'
$Fragment1 = $Fragment1 -replace '</th></tr>','</th></tr></thead><tbody>'
$Fragment1 = $Fragment1 -replace '</table>','</tbody></table>'
$Fragment1 = $Fragment1 -replace '<colgroup>',''
$Fragment1 = $Fragment1 -replace '</colgroup>',''
$Fragment1 = $Fragment1 -replace '<col/>',''

# Add Bootstrap and Bootstrap tables
$Precontent='<title>Issue Work Completed by Team</title><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"><!-- Bootstrap CSS --><link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.2.1/css/bootstrap.min.css">'
$Postcontent='<script src="https://code.jquery.com/jquery-3.3.1.min.js"></script><script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.1/js/jquery.tablesorter.min.js" type="text/javascript" charset="UTF-8"></script><script src="https://stackpath.bootstrapcdn.com/bootstrap/4.2.1/js/bootstrap.min.js"></script><script>$(function() {$("#IssuesWorkCompleted").tablesorter();});</script>'

$ConvertedHTML = ConvertTo-HTML -Body "$Fragment1" -Head $Precontent -PostContent $Postcontent 

# Find and replace necessary elements in converted HTML that are outside of fragments
$ConvertedHTML = $ConvertedHTML -replace '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">', '<!doctype html>'
$ConvertedHTML = $ConvertedHTML -replace '<html xmlns="http://www.w3.org/1999/xhtml">', '<html lang="en">'
$ConvertedHTML = $ConvertedHTML -replace '<tr><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td></tr>', '' # remove empty rows

$ConvertedHTML |
Out-File "C:\Temp\IssuesWorkCompleted.html"