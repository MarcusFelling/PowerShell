# Script to aggregate TFS 2015 build code coverage results for specified build definition
# SSRS reports do not work with new build system (Non XAML) to provide this info as of Update 2 

param(
[string]$passwd
)

Function AggregateCodeCoverageResults       
{         
    $definitionId = ""
    $user = "" 
    # Encrypted password passed via build definition variable
    $secpasswd = ConvertTo-SecureString $passwd -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
    
    # Use build api to get build IDs and build dates.
    [uri] $buildUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $env:SYSTEM_TEAMPROJECT + "/_apis/build/builds?definitions=" + $definitionId +"&statusFilter=completed&reasonfilter=scheduled&api-version=2.0"
    $getBuilds = Invoke-RestMethod -Uri $buildUri -Method Get -Credential $credential   

    # Create object from results containing build date and build number
    $buildList = $getBuilds | 
    select @{Name="BuildDate"; Expression={$_.value.finishtime}},@{Name="BuildNumber"; Expression={$_.value.buildNumber}}

    # Build number will be used in code coverage Uri
    $buildNumbers = $buildList.BuildNumber
    
    # Build dates will be added to results array at line 70
    $buildDates = $buildList.BuildDate    
    
    # Trim anything past xxxx-xx-xx
    $buildDatesArray = $buildDates.Substring(0,10)

    # Initialize array that will contain results
    $coverageResultsArray = @()

    # Loop through every build ID to get code coverage results
    ForEach($buildNumber in $buildNumbers)
    {
        # Use code coverege api to get results of build
        [uri] $codeCoverageUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $env:SYSTEM_TEAMPROJECT + "/_apis/test/codecoverage?api-version=2.0-preview.1&buildid=" + $buildNumber +"&flags=7"             
        $coverageResults = Invoke-RestMethod -Uri $codeCoverageUri -Method Get -Credential $credential
        
        # Get total blocks covered and blocks NOT covered, sum them up to get toal blocks, then divide blocks covered by total blocks
        $blocksCovered = $coverageResults.value.modules.statistics.blocksCovered
        $blocksNotCovered = $coverageResults.value.modules.statistics.blocksNotCovered
        $blocksCoveredSum = $blockscovered | measure-object -sum
        $blocksNotCoveredSum = $blocksNotCovered | measure-object -sum            
        $totalBlocks = $blocksCoveredSum.sum+$blocksNotCoveredSum.sum
        $dividedBlocks = $blocksCoveredSum.sum/$totalBlocks
        
        # move decimal over 2, add percent symbol
        $coveragePercent = "{00:P2}" -f $dividedBlocks                                   

        # Failed builds return NaN for coverage result
        if($coveragePercent -eq "NaN")
        {
            # Add "build failed" to results array
            $coverageResultsArray += "Build Failed"
        }
        else
        {                        
            # Add coverage percent to results array
            $coverageResultsArray += $coveragePercent
        }
        
    }
     
    # Loop through and add build dates to coverage results output to CSV
    $(for ($i=0; $i -le $coverageResultsArray.Count;$i++)
    {
    'Build Date: {0} Coverage: {1}' -f $buildDatesArray[$i],$coverageResultsArray[$i]
    }) | set-content C:\codecoverage.csv

}    
Try
{
    AggregateCodeCoverageResults
}
Catch
{
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
}
