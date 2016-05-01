# Checks if Neuron Enterprise Service Bus is installed, cleans up adpaters folder, then copies assemblies from bin 
# Neuron ESB: http://www.neuronesb.com/

Function ValidateNeuronInstall
{
	# Check if Neuron install object exists
	$NeuronInstallObject = Get-WMIObject -Class win32_product -Filter {Name like "%Neuron%"}
	If ($NeuronInstallObject -ne $null)
	{
		Write-Host "Neuron Installed: $NeuronInstallObject"
	}
	Else
	{
		Write-Host "Neuron is not installed" exit
	}
	
	# Check Neuron install dir
	If (Test-Path 'c:\ESB\Neuron\DEFAULT\Adapters') 
	{
		Write-Host "Adapters folder exists"
	}
	Else 
	{
		Write-Host "Adapters folder does not exist." exit
	}
}
Function NeuronPreDeployCleanup    
{  	
	# Cleanup Adapters folder
	$adapterExclude = "Neuron.*","Apache.*"
	Get-ChildItem -Path 'c:\ESB\Neuron\DEFAULT\Adapters' -Recurse -exclude $adapterExclude | 
	Remove-Item -force -verbose -recurse
}

Function NeuronDeploy 
{ 
	# Copy $Company.*.Neuron dll's and SqlServerTypes from bin to adapters folder 
	Copy-Item .\bin\$Company.*.Neuron.dll C:\ESB\Neuron\DEFAULT\Adapters -verbose -Force
	Copy-Item .\bin\Debug\SqlServerTypes C:\ESB\Neuron\DEFAULT\Adapters\SqlServerTypes -Force -recurse
	
	# Assemblies to include in default instance folder
	$instanceIncludes = "$Company.*","EntityFramework.*.dll", "EntityFramework.dll", "AutoMapper*.dll", "Castle*.dll", "$Company.*.dll"
	# Assemblies to exclude from the default instance folder
	$instanceExclude = "$Company.*.Neuron*"
	
	# Copy instance assemblies from C:\Neuron to C:\ESB\Neuron\Default
	ForEach($instanceInclude in $instanceIncludes)
	{	
		Get-ChildItem -Path ".\bin\$instanceInclude" -exclude $instanceExclude | 
		Copy-Item -Destination C:\ESB\Neuron\DEFAULT -force -verbose       
	}
}

Try
{
    ValidateNeuronInstall
	NeuronPreDeployCleanup
	NeuronDeploy
}
Catch
{
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)"
    Write-Host "Exception Message: $($_.Exception.Message)"
}
