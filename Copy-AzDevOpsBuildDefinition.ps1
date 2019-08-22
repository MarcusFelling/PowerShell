[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]
    $PAT, # Personal Access Token
    [Parameter(Mandatory=$true)]
    $DefinitionToCloneID, # ID of "Golden" build definition to clone.
    [Parameter(Mandatory=$true)]
    $LOB, # Line of business name. Used to reference Git repo source of build definition.
    [Parameter(Mandatory=$true)]
    $AzureDevOpsProjectURL # https://vsrm.dev.azure.com/{organization}/{project}
)

# Base64-encodes the Personal Access Token (PAT) appropriately
# This is required to pass PAT through HTTP header
$script:User = "" # Not needed when using PAT, can be set to anything
$script:Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$PAT)))

# Get Definition URI https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/get?view=azure-devops-rest-5.1
[uri] $script:GetDefinitionUri = "$AzureDevOpsProjectURL/_apis/build/definitions/$DefinitionToCloneID`?api-version=5.0"
$GetDefinitionResponse = Invoke-RestMethod -Uri $GetDefinitionUri -Method GET -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}

# Use response to form requst body for new definition
$GetDefinitionResponse.name = "$LOB" # Set new definition name to name of LOB
$GetDefinitionResponse.repository.name = "$LOB" # Set repo name and URL to LOB repo
$GetDefinitionResponse.repository.url = "$AzureDevOpsProjectURL/_git/$LOB"

# Convert response to JSON to be used in POST body below
$ConvertResponseToRequestBody = $GetDefinitionResponse | ConvertTo-Json -Depth 10

# Create Definition URI https://docs.microsoft.com/en-us/rest/api/azure/devops/build/definitions/create?view=azure-devops-server-rest-5.0
[uri] $script:CreateDefinitionUri = "$AzureDevOpsProjectURL/_apis/build/definitions?definitionToCloneId=$DefinitionToCloneID&api-version=5.0"

# Invoke the Create REST call and capture the response
Invoke-RestMethod -Uri $CreateDefinitionUri -Method POST -Body $ConvertResponseToRequestBody -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $Base64AuthInfo)}
