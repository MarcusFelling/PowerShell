<#
.Description
   Script to determine which app should be built. 
.Outputs
   "App*Updated" variable set that can be used in subsequent build task conditions.
   e.g. and(succeeded(), eq(variables['App1Updated'], 'True'))
#>

# Get all files that changed
# https://git-scm.com/docs/git-diff
$EditedFiles = git diff HEAD HEAD~ --name-only

# Check each file that was changed and set variable 
$EditedFiles | ForEach-Object { 
    Switch -Wildcard ($_ ) {        
        "App1/*" { 
            Write-Host "App 1 changed"
            Write-Host "##vso[task.setvariable variable=App1Updated]True"
        }
        "App2/*" { 
            Write-Host "App 2 changed" 
            Write-Host "##vso[task.setvariable variable=App2Updated]True"
        }
        "App3/*" { 
            Write-Host "App 3 changed" 
            Write-Host "##vso[task.setvariable variable=App3Updated]True"
        }
        # Add the rest of the App path filters here
    }
}