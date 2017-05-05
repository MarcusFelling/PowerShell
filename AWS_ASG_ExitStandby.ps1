# Part 2 of 2
# Part 1 Places EC2 instance into autoscaling group's standby mode.
# Part 2 Exits standby mode and waits for instance to be InService.

param (
    [Parameter(Mandatory=$true)][string]$ASGEnterStandbyDeployStep, # Deploy step name of AWS_ASG_EnterStandby.ps1
    [Parameter(Mandatory=$true)][string]$ASGNameVariable, # Variable name that is set by AWS_ASG_EnterStandby.ps1 for ASG Name
    [Parameter(Mandatory=$true)][string]$registrationCheckInterval,
    [Parameter(Mandatory=$true)][string]$maxRegistrationCheckCount
 )

# Get EC2 Instance
Try
{
	$response = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Method Get
	If ($response)
	{
		$instanceId = $response
        Write-Host "Instance ID: $instanceId"
	}
	Else
	{
		Write-Error -Message "Returned Instance ID does not appear to be valid"
		Exit 1
	}
}
Catch
{
	Write-Error -Message "Failed to load instance ID from AWS." -Exception $_.Exception
	Exit 1
}

# Get Stack name and status
# If Stack is being Updated, instances are updated via AutoScaling group policy,
# and there is no need to place instances into StandBy
Try
{

		$stackName = Get-EC2Tag -Filter @{ Name="key";Values="aws:cloudformation:stack-name"},@{ Name="resource-id";Values=$instanceID}
		$stackInfo = Get-CFNStack -StackName $stackName.Value

	if($stackInfo.StackStatus -eq "UPDATE_IN_PROGRESS"){
		Write-Host "CloudFormation stack updating, this Octopus step will now be skipped."
		Exit
	}
}
Catch
{
	Write-Error -Message "Failed to retrieve CloudFormation stack status from AWS." -Exception $_.Exception
	Exit 1
}

# Get ASG Name variable from previous deploy step (AWS_ASG_EnterStandby.ps1)
Try
{
	$ASGName = $OctopusParameters["Octopus.Action[$ASGEnterStandbyDeployStep].Output.$ASGNameVariable"]
    Write-Host "Auto Scaling Group Name: $ASGName"
	If (!$ASGName)
	{
		Write-Error -Message "Returned Auto Scaling Group Name does not appear to be valid"
		Exit 1
	}
}
Catch
{
	Write-Error -Message "Failed to get ASGNameVariable output variable from Octopus" -Exception $_.Exception
	Exit 1
}

# Exit standby mode
Try
{

    Write-Host "Exiting standby mode for instance: $instanceId in ASG: $ASGName."
    Exit-ASStandby -InstanceId $instanceId -AutoScalingGroupName $ASGName -Force
    Write-Host "Instance exited standby mode, waiting for it to go into service."

    $instanceState = (Get-ASAutoScalingInstance -InstanceId $instanceId).LifecycleState
    Write-Host "Current State: $instanceState"

    $checkCount = 0

    Write-Host "Retry Parameters:"
    Write-Host "Maximum Checks: $maxRegistrationCheckCount"
    Write-Host "Check Interval: $registrationCheckInterval"

	While ($instanceState -ne "InService" -and $checkCount -le $maxRegistrationCheckCount)
	{
		$checkCount += 1

		# Wait a bit until we check the status
		Write-Host "Waiting for $registrationCheckInterval seconds for instance to be InService"
		Start-Sleep -Seconds $registrationCheckInterval

		If ($checkCount -le $maxRegistrationCheckCount)
		{
			Write-Host "$checkCount/$maxRegistrationCheckCount Attempts"
		}

		$instanceState = (Get-ASAutoScalingInstance -InstanceId $instanceId).LifecycleState

		Write-Host "Current instance state: $instanceState"
	}

	If ($instanceState -eq "InService")
	{
		Write-Host "Instance in service!"
	}
	Else
	{
		Write-Error -Message "Instance not in service: $instanceState"
		Exit 1
	}
}
Catch
{
	Write-Error -Message "Failed to exit standby mode." -Exception $_.Exception
	Exit 1
}
