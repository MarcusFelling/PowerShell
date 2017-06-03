$storageAccountName = ""
$storageAccountKey = ""
$container = ""

$context = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
$sas = New-AzureStorageContainerSASToken -Name $container -Permission rl -Context $context -ExpiryTime ([DateTime]::UtcNow.AddDays(7)) 
Write-Host "$($context.BlobEndPoint)$($container)$($sas)"
