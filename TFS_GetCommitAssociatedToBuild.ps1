<#
.Synopsis
   Script gets commit from last successful build.     
.Notes    
    TFS REST API documentation: https://www.visualstudio.com/integrate/api/build/builds
#>

function GetCommitAssociatedToBuild{
   Param(
    [string]$DefinitionID =  # Build Definition ID (found on variables tab)
    )
    
    # Get last completed build
    [uri] $BuildUri = $env:System_TeamFoundationCollectionUri + $env:System_TeamProject + "/_apis/build/builds?definitions=$DefinitionID&api-version=2.0&statusFilter=completed&`$top=1"                
    $BuildInfo = Invoke-RestMethod -Method Get -Uri $BuildUri -ContentType 'application/json' -UseDefaultCredentials
    
    # Fail script if no build is found
    If($BuildInfo.count -ne 1){
        write-output "No build found"
        exit -1
    }
    # Get source version from build info
    $SourceVersion = $BuildInfo.value.sourceversion   
    write-host "SourceVersion = $SourceVersion" 
    
    # Write variable to be used in subsequent build steps
    Write-Host ("##vso[task.setvariable variable=SourceVersion;]$SourceVersion")     

}

Try{
    GetCommitAssociatedToBuild    
}
Catch{
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
    exit 1
}
