Function New-Build
{
	param
	(
		[Parameter(Mandatory=$true)]
		[ValidateLength(1,32)]
		[String]$BuildName,
		[Parameter(Mandatory=$true)]
		[ValidateLength(1,32)]
		[String]$Version,
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$OperatingSystem,
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$UnattendXmlTemplate,
		[Parameter(Mandatory=$true)]
		[Byte]$ImageIndex
	)
	
	$OSID = $OperatingSystem.OperatingSystemID
	[Void]$PSBoundParameters.Remove("OperatingSystem")
	[Void]$PSBoundParameters.Add("OperatingSystemID",$OSID)
	
	New-PSSQLRecord -TableName Build -Parameters $PSBoundParameters | Out-Null
	Get-Build -BuildName $BuildName
}

Function Get-Build
{
	[CmdletBinding(DefaultParameterSetName = "All")]
	param
	(
		[Parameter(Mandatory=$true, ParameterSetName = "ByName")]
		[ValidateLength(1,32)]
		[String]$BuildName
	)
	
	switch($PSCmdlet.ParameterSetName) 
	{
		"ByName" {
			Get-PSSQLRecords -SQL "select top 1 *,'Build' as PSTypeName from Build where BuildName = @BuildName" `
			-Parameters @{BuildName = $BuildName}
			}
		default {
			Get-PSSQLRecords -SQL "select *,'Build' as PSTypeName from Build"
			}
	}
}

Function New-BuildStep
{
	param
	(
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNull()]
		[String]$BuildName,
		[Parameter(Mandatory=$true)]
		[ValidateLength(1,32)]
		[String]$StepName,
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Byte]$ExecutionOrder,
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[ScriptBlock]$ScriptText,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[ScriptBlock]$ExecuteIfScript,
		[Parameter(Mandatory=$true)]
		[ValidateSet("Stop","Continue")]
		[String]$ErrorActionPreference,
		[Parameter(Mandatory=$true)]
		[ValidateSet("WinPE","Windows")]
		[String]$BuildStage
	)
	
	$params = @{
		BuildName = $BuildName
		StepName = $StepName
		ExecutionOrder = $ExecutionOrder
		ScriptText = $ScriptText.ToString()
		ErrorAction = $ErrorActionPreference
        BuildStage = $BuildStage
	}
	if ($ExecuteIfScript) { $params.Add("ExecuteIfScript",$ExecuteIfScript.ToString()) }
	
	$id = New-PSSQLRecord -TableName BuildStep -Parameters $params -ReturnIdentity
	Get-BuildStep -BuildStepID $id
}

Function Get-BuildStep
{
	[CmdletBinding(DefaultParameterSetName = "All")]
	param
	(
		[Parameter(Mandatory=$true, ParameterSetName = "ByBuild", ValueFromPipelineByPropertyName = $true)]
		[Parameter(Mandatory=$true, ParameterSetName = "ByName", ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNull()]
		[String]$BuildName,
		[Parameter(Mandatory=$true, ParameterSetName = "ByName")]
		[ValidateLength(1,32)]
		[String]$BuildStepName,
		[Parameter(Mandatory=$true, ParameterSetName = "ByID")]
		[ValidateNotNull()]
		[Int]$BuildStepID,
        [Parameter(Mandatory=$false, ParameterSetName = "ByBuild")]
        [Switch]$EnabledOnly
	)
	
	switch($PSCmdlet.ParameterSetName) 
	{
		"ByName" {
			$steps = @(Get-PSSQLRecords -SQL "select top 1 *,'BuildStep' as PSTypeName from BuildStep where BuildName = @BuildName and BuildStepName = @BuildStepName" `
				-Parameters @{ BuildName = $BuildName; BuildStepName = $BuildStepName})
			}
		"ByID" {
			$steps = @(Get-PSSQLRecords -SQL "select top 1 *,'BuildStep' as PSTypeName from BuildStep where BuildStepID = @BuildStepID" `
				-Parameters @{BuildStepID = $BuildStepID})
			}
		"ByBuild" {
			$steps = @(Get-PSSQLRecords -SQL "select *,'BuildStep' as PSTypeName from BuildStep where BuildName = @BuildName and IsEnabled = @IsEnabled order by ExecutionOrder" `
				-Parameters @{BuildName = $BuildName; IsEnabled = $EnabledOnly.IsPresent})
			}
		default {
			$steps = @(Get-PSSQLRecords -SQL "select *,'BuildStep' as PSTypeName from BuildStep")
			}
	}
	$steps | select BuildStepID,BuildName,StepName,ExecutionOrder,BuildStage,IsEnabled,ErrorAction,`
		@{N="Script";E={[ScriptBlock]::Create($_.ScriptText)}},`
		@{N="ExecuteIfScript";E={if ($_.ExecuteIfScript) {[ScriptBlock]::Create($_.ExecuteIfScript)} else {$null}}}
}

Function New-BuildInstance
{
    [CmdletBinding(DefaultParameterSetName = "NoDSC")]
	param
	(
		[Parameter(Mandatory=$true)]
		[ValidateLength(2,64)]
		[String]$ComputerName,
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNull()]
		[String]$BuildName,
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$PackageSource,
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$UserLocale,
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$RequestedBy,
		[Parameter(Mandatory=$false)]
        [ValidateLength(1,256)]
		[String[]]$MACAddresses,
		[Parameter(Mandatory=$true, ParameterSetName = "DSCPull")]
		[Guid]$DSCConfigurationID,
		[Parameter(Mandatory=$true, ParameterSetName = "DSCPull")]
		[Uri]$DSCPullServerURI,
        [Parameter(Mandatory=$true, ParameterSetName = "DSCPush")]
        [String]$DSCScript
	)
	DynamicParam {
		$buildParams = Get-BuildParameter -BuildName $BuildName
		Write-Verbose "Retrieved $($buildParams.Count) params"
		if ($buildParams.Count -gt 0)
		{
			$paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
			foreach ($bp in $buildParams)
			{
				$paramAttr = New-Object System.Management.Automation.ParameterAttribute
				$paramAttr.Mandatory = $bp.Mandatory
				$valAttr = switch ($bp.ValidationType)
				{
					"ValidateSet" { 
						New-Object System.Management.Automation.ValidateSetAttribute(@($bp.ValidationValue -split ','))
						}
					"ValidateRange" { 
						[Int32[]]$vals = $bp.ValidationValue -split ','
						([System.Management.Automation.ValidateRangeAttribute]).GetConstructors().Invoke($vals) 
						}
					"ValidateLength" { 
						[Int32[]]$vals = $bp.ValidationValue -split ','
						([System.Management.Automation.ValidateLengthAttribute]).GetConstructors().Invoke($vals)  
						}
					"ValidatePattern" { 
						New-Object System.Management.Automation.ValidatePatternAttribute($bp.ValidationValue)
						}
					"ValidateNotNullOrEmpty" { 
						New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute 
						}
					"ValidateScript" { 
						New-Object System.Management.Automation.ValidateScriptAttribute([ScriptBlock]::Create($bp.ValidationValue))
						}
					default { $null }
				}
				$attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
				
				$attributeCollection.Add($paramAttr)
				if ($valAttr) { $attributeCollection.Add($valAttr) }
				$bParam = New-Object System.Management.Automation.RuntimeDefinedParameter($bp.ParameterName, $bp.DotNetDataType, $attributeCollection)
				$paramDictionary.Add($bp.ParameterName,$bParam)
			}
			return $paramDictionary
		}
	}
	process
	{
		$params = @{
			ComputerName = $ComputerName
			BuildName = $BuildName
			PackageSourceID = $PackageSource.PackageSourceID
			RequestedBy = $RequestedBy
			UserLocale = $UserLocale
			Status = "InstallPending"
		}
		if ($MACAddresses) { $params.Add("MACAddresses",($MACAddresses -join ",")) }

		if ($PSCmdlet.ParameterSetName -eq "DSCPull")
		{ 
			$params.Add("DSCPullServerURI",$DSCPullServerURI.ToString())
			$params.Add("DSCConfigurationID",$DSCConfigurationID)
		}
		elseif ($PSCmdlet.ParameterSetName -eq "DSCPush")
		{
			$params.Add("DSCScript",$DSCScript)
		}

		$build = Get-Build -BuildName $BuildName
		$newUnattend = $build.UnattendXmlTemplate -replace "\{ComputerName\}",$ComputerName `
			-replace "\{UserLocale\}",$UserLocale `
			-replace "\{RequesterUsername\}",$RequestedBy
	
		$buildParams = Get-BuildParameter -BuildName $BuildName
		if ($buildParams.Count -gt 0)
		{
			foreach ($bp in $buildParams)
			{
				if ($PSBoundParameters.ContainsKey($bp.ParameterName))
				{
					$val = $PSBoundParameters[$bp.ParameterName]
					if (-not $val) { $val = "" }
					$newUnattend = $newUnattend -replace "\{$($bp.ParameterName)\}",$val.ToString()
				}
				elseif (-not $bp.Mandatory -and $bp.DefaultValue)
				{
					$newUnattend = $newUnattend -replace "\{$($bp.ParameterName)\}","$($bp.DefaultValue)"
				}
			}
		}

		$params.Add("UnattendXml",$newUnattend)
		Write-Verbose "Unattend => $newUnattend"

		$id = New-PSSQLRecord -TableName BuildInstance -Parameters $params -ReturnIdentity

		Get-BuildInstance -BuildInstanceID $id
	}
}

Function Get-BuildInstance
{
	[CmdletBinding(DefaultParameterSetName = "All")]
	param
	(
		[Parameter(Mandatory=$true, ParameterSetName = "ByID")]
		[ValidateNotNull()]
		[Int]$BuildInstanceID,
		[Parameter(Mandatory=$true, ParameterSetName = "ByStatus")]
        [ValidateSet("InstallPending","InstallRunning","ConfigurationPending","ConfigurationRunning","Requested","Failed","Completed","CompletedWithErrors")]
		[String]$Status
	)
	
	switch($PSCmdlet.ParameterSetName) 
	{
		"ByStatus" {
			Get-PSSQLRecords -SQL "select top 1 *,'BuildInstance' as PSTypeName from BuildInstance where Status = @Status" `
                -Parameters @{ Status = $Status }
			}
		"ByID" {
			Get-PSSQLRecords -SQL "select top 1 *,'BuildInstance' as PSTypeName from BuildInstance where BuildInstanceID = @BuildInstanceID" `
			-Parameters @{ BuildInstanceID = $BuildInstanceID}
			}
		default {
			Get-PSSQLRecords -SQL "select *,'BuildInstance' as PSTypeName from BuildInstance"
			}
	}
}

Function New-BuildStepInstance
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$BuildInstance,
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$BuildStep
	)
	
	$params = @{
        BuildInstanceID = $BuildInstance.BuildInstanceID
	    BuildStepID = $BuildStep.BuildStepID
	    StartedAtDTO = [DateTimeOffset]::Now
    }

    try
	{
		$id = New-PSSQLRecord -TableName BuildStepInstance -Parameters $params -ReturnIdentity
	}
	catch
	{
		throw "An error occurred creating a new BuildStepInstance => $_"
	}
    Get-PSSQLRecords -SQL "select *,'ObjectInstance' as PSTypeName from BuildStepInstance where BuildStepInstanceID = @BuildStepInstanceID" `
        -Parameters @{ BuildStepInstanceID = $id }
}

Function Get-BuildStepInstance
{
    param
    (
        [Parameter(Mandatory = $true)]
		[ValidateNotNull()]
        [Int]$BuildStepID,
        [Parameter(Mandatory = $true)]
		[ValidateNotNull()]
        [Int]$BuildInstanceID
    )

    Get-PSSQLRecords -SQL "select top 1 *,'BuildStepInstance' as PSTypeName from BuildStepInstance where BuildStepID = @BuildStepID and BuildInstanceID = @BuildInstanceID order by BuildStepInstanceID desc" `
        -Parameters @{ BuildStepID = $BuildStepID; BuildInstanceID = $BuildInstanceID }
}

Function Find-BuildInstance
{
    $ErrorActionPreference = "Stop"

    $netInterfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | where NetworkInterfaceType -eq "Ethernet"
    if (-not $netInterfaces) { throw "No Network Adapters were found, did you inject the correct drivers into the ISO?" }
	Write-Verbose "Found $($netInterfaces.Count) Ethernet interfaces. Retrieving MAC addresses..."

    foreach ($nic in $netInterfaces)
    {
		$mac = $nic.GetPhysicalAddress().ToString()
		Write-Verbose "Searching database for record with MAC address $mac"
        $rec = Get-PSSQLRecords -SQL "select top 1 *,'Object' as PSTypeName from BuildInstance where MACAddresses like @MACAddress order by BuildInstanceID desc" -Parameters @{MACAddress = "%$mac%"}
        if ($rec) 
        {
			Write-Verbose "Found a record for MAC address $mac"
            $global:CurrentBuildInstance = $rec
            $global:CurrentBuild = Get-Build -BuildName $rec.BuildName
            return $rec 
        }
    }

    Write-Output "No pre-staged BuildInstance was found for MAC addresses $($macAddresses -join ',')"
    $pendingBuilds = @(Get-BuildInstance -Status InstallPending)
    $pendingBuilds += Get-BuildInstance -Status ConfigurationPending

    if ($pendingBuilds)
    {
        $pendingBuilds | select BuildInstanceID,ComputerName | Format-Table -AutoSize
        $id = Read-Host -Prompt "Please enter the BuildInstanceID that you want to run"
        if ($id) 
        { 
            $rec = $pendingBuilds | where { $_.BuildInstanceID -eq ([Int]$id) }
            if ($rec) 
            { 
                $global:CurrentBuildInstance = $rec
                $global:CurrentBuild = Get-Build -BuildName $rec.BuildName
                return $rec 
            }
        }
    }

    throw "No pending BuildInstances were found in the database"
}

Function Invoke-Build
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		[Object]$Build,
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$BuildInstance
	)
	
	Write-Verbose "Invoking build for build instance $($BuildInstance.BuildInstanceID)"
    Import-BuildInstanceVariables -BuildInstanceID $BuildInstance.BuildInstanceID

	$buildStage = switch ($BuildInstance.Status) { "InstallPending" { "WinPE" } "ConfigurationPending" { "Windows" } }
	$buildSteps = @(Get-BuildStep -BuildName $Build.BuildName -EnabledOnly)
	Write-Verbose "Found $($buildSteps.Count) build steps for build $($Build.BuildName)"
	$BuildInstance.StartedAtDTO = [DateTimeOffset]::Now
    $BuildInstance.Status = switch ($BuildInstance.Status) { "InstallPending" { "InstallRunning" } "ConfigurationPending" { "ConfigurationRunning" } default { "InstallRunning" } }
	try
	{
		Set-PSSQLRecord -TableName BuildInstance -Parameters @{
			BuildInstanceID = $BuildInstance.BuildInstanceID
			StartedAtDTO = $BuildInstance.StartedAtDTO
			Status = $BuildInstance.Status} -KeyColumn BuildInstanceID | Out-Null
	}
	catch
	{
		throw "An error occurred updating the status to $($BuildInstance.Status) => $_"
	}

	$stepsFailed = 0
	$lastStepStage = ""
	foreach ($bs in $buildSteps)
	{
        #Here we check to see if the build step has been run before (this facilitates the "Rerun" capability)
        $exists = Get-BuildStepInstance -BuildStepID $bs.BuildStepID -BuildInstanceID $BuildInstance.BuildInstanceID
        if ($exists -and $exists.Status -like "Completed*") 
        { 
            Write-Verbose "Build Step $($bs.StepName) has already been executed"
            continue 
        }
		elseif (-not [String]::IsNullOrWhiteSpace($lastStepStage) -and $bs.BuildStage -ne $lastStepStage)
		{
			Write-Verbose "Finished all steps for this stage"
			break
		}
		else
		{
			$lastStepStage = $bs.BuildStage
			Write-Verbose "Invoking BuildStep '$($bs.StepName)' in stage '$($bs.BuildStage)' ($($bs.BuildStepID))"
		}

        $bsi = Invoke-BuildStep -BuildStep $bs -BuildInstance $BuildInstance
        $bsi.FinishedAtDTO = [DateTimeOffset]::Now
		Write-Verbose "Converting result object to Dictionary"
		$props = ConvertTo-Dictionary -Object $bsi -ExcludeNulls
	    Set-PSSQLRecord -TableName BuildStepInstance -Parameters $props -KeyColumn BuildStepInstanceID

		Remove-Variable -Scope Global -Name CurrentBuildStepInstance -EA SilentlyContinue

	    if ($bsi.Status -like "Failed*")
        { 
            if ($bs.ErrorAction -eq "Stop")
            {
                $BuildInstance.Status = "Failed"
                break 
            }
            else { $stepsFailed++ }
        }
	}
	$BuildInstance.FinishedAtDTO = [DateTimeOffset]::Now
	$BuildInstance.Status = switch ($BuildInstance.Status) 
	{ 
		"InstallRunning" { "ConfigurationPending" } 
		"ConfigurationRunning" { 
			if ($stepsFailed -gt 0) { "Completed ($stepsFailed non-terminal errors)" } 
			else { "Completed" } 
		}
		default { $BuildInstance.Status }
	}
	$props = ConvertTo-Dictionary -Object $BuildInstance -ExcludeNulls
    Set-PSSQLRecord -TableName BuildInstance -Parameters $props -KeyColumn BuildInstanceID | Out-Null
    return $BuildInstance
}

Function Invoke-BuildStep
{
	[CmdletBinding()]
	param
	(
        [Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$BuildInstance,
		[Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Object]$BuildStep
	)
	
	$ErrorActionPreference = "Stop"
    $global:CurrentBuildStepInstance = New-BuildStepInstance -BuildInstance $BuildInstance -BuildStep $BuildStep
	
	if ($BuildStep.ExecuteIfScript)
	{
		try
		{
			$shouldExecute = Invoke-Command -ScriptBlock $BuildStep.ExecuteIfScript
		}
		catch
		{
			$msg = Format-Exception -Exception $_.Exception -LineNumber $_.InvocationInfo.ScriptLineNumber
			Write-Warning $msg
			$global:CurrentBuildStepInstance.ErrorDetails = $msg
			$global:CurrentBuildStepInstance.Status = "Failed (ExecuteIf)"
			return $global:CurrentBuildStepInstance
		}
		
		if ($shouldExecute -isnot [Boolean] -and @("true","false") -notcontains $shouldExecute)
		{
			$msg = "Return type from ExecuteIf must be boolean True or False"
			Write-Verbose $msg
			$global:CurrentBuildStepInstance.ErrorDetails = $msg
			$global:CurrentBuildStepInstance.Status = "Failed (ExecuteIf)"
			return $global:CurrentBuildStepInstance
		}
		elseif (-not $shouldExecute)
		{
            $msg = "ExecuteIf returned False, skipping BuildStep '$($BuildStep.StepName)'"
			Write-Verbose $msg
			$global:CurrentBuildStepInstance.Status = "Skipped"
            $global:CurrentBuildStepInstance.BuildStepOutput = $msg
			return $global:CurrentBuildStepInstance
		}
        else
        {
            Write-Verbose "ExecuteIf returned True, executing BuildStep '$($BuildStep.StepName)'"
        }
	}
	
	try
	{
		$result = Invoke-Command -ScriptBlock $BuildStep.Script
		if ($result -is [Array])
		{
			$global:CurrentBuildStepInstance.BuildStepOutput = [String]::Join([Environment]::NewLine, $result)
		}
		elseif ($result -is [Object]) 
		{ 
			$global:CurrentBuildStepInstance.BuildStepOutput = [Convert]::ToString($result) 
		}
		$global:CurrentBuildStepInstance.Status = "Completed"
	}
	catch
	{
		$msg = "An error occurred while invoking buildstep $($BuildStep.StepName) => {0}" -f (Format-Exception -Exception $_.Exception -LineNumber $_.InvocationInfo.ScriptLineNumber)
		Write-Warning $msg
		$global:CurrentBuildStepInstance.ErrorDetails = $msg
		$global:CurrentBuildStepInstance.Status = "Failed (ScriptBlock)"
	}
    
    return $global:CurrentBuildStepInstance
}
