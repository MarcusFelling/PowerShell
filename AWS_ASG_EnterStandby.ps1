# Part 1 of 2
# Part 1 Places EC2 instance into autoscaling group's standby mode.
# Part 2 Exits standby mode and waits for instance to be InService.
param (
    [Parameter(Mandatory=$true)][string]$ASGNameVariable # Passed in deploy step, example: WebASGName.
 )
# Get EC2 Instance
Try
{
	$response = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" -Method Get
	If ($response)
	{
		$instanceId = $response
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

# Get ASG Name using $instanceId and set Octopus output variable to be used in subsequent deploy step AWS_ASG_ExitStandby.ps1
Try
{
    $ASGInfo = Get-ASAutoScalingInstance -InstanceId $instanceId
    $ASGName = $ASGInfo.AutoScalingGroupName

	If ($ASGName)
	{
        # Set ASGNameVariable Octopus output variable passed as argument in deploy step (1 ASGNameVariable per server type)
        # Referenced in subsequent deploy step AWS_ASG_ExitStandby.ps1: $ASGNameVariable = $OctopusParameters["Octopus.Action[AWS_ASG_EnterStandby.ps1].Output.$ASGNameVariable"]
        Write-Host "Setting Octopus output variable $ASGNameVariable to value: $ASGName"
        Set-OctopusVariable -name "$ASGNameVariable" -value "$ASGName"
        Write-Host "Output variable set."
	}
	Else
	{
		Write-Error -Message "Returned Auto Scaling Group name does not appear to be valid"
		Exit 1
	}
}
Catch
{
	Write-Error -Message "Failed to retrieve Auto Scaling Group name from AWS." -Exception $_.Exception
	Exit 1
}

# Place instance in standby mode if InService, skip if already in standby mode.
Try
{
        $instanceState = (Get-ASAutoScalingInstance -InstanceId $instanceId).LifecycleState

        If($instanceState -eq "InService")
        {
            Write-Host "Placing instance: $instanceId into standby mode for ASG: $ASGName"
            Enter-ASStandby -InstanceId $instanceId -AutoScalingGroupName $ASGName -ShouldDecrementDesiredCapacity $true -Force
            Write-Host "Instance $instanceId is now in standby mode"
        }
        ElseIf($instanceState -eq "Standby")
        {
		Write-Host "Instance already in standby"
        }
        Else
        {
		Write-Error -Message "Error: Instance is not InService or Standby mode." -Exception $_.Exception
		Exit 1
        }
}
Catch
{
	Write-Error -Message "Failed to place instance in standby mode." -Exception $_.Exception
	Exit 1
}
