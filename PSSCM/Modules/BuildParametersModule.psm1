Function Get-BuildParameter
{
	[CmdletBinding()]
	param
    (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNull()]
		[String]$BuildName
	)

	if (-not $global:PSSCMSqlConnection) 
	{  
		Open-PSSQLConnection -FromModuleConfig -Default
	}

	Get-PSSQLRecords -SQL "select *,'BuildParameter' as PSTypeName from BuildParameter where BuildName = @BuildName" -Parameters @{BuildName = $BuildName}
}

Function New-BuildParameter
{
	[CmdletBinding(DefaultParameterSetName = "NoValidation")]
	param
    (
		[Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNull()]
		[String]$BuildName,
        [Parameter(Mandatory=$true)]
        [ValidateLength(2,32)]
        [String]$ParameterName,
		[Parameter(Mandatory=$true)]
        [ValidateSet("String","Int16","Int32","Int64","Guid")]
        [String]$DotNetDataType,
		[Parameter(Mandatory=$true, ParameterSetName = "ValidateSet")]
		[ValidateNotNullOrEmpty()]
		[String[]]$ValidateSet,
		[Parameter(Mandatory=$true, ParameterSetName = "ValidateRange")]
		[ValidateCount(2,2)] #({if ($_.Count -ne 2){throw "ValidateRange requires an array of 2 Int32 values (only got $($_.Count), $_)"} else { $true }})]
		[Int[]]$ValidateRange,
		[Parameter(Mandatory=$true, ParameterSetName = "ValidateLength")]
		[ValidateCount(2,2)]#({if ($_.Count -ne 2){throw "ValidateLength requires an array of 2 Int32 values (only got $($_.Count)), $_"} else { $true }})]
		[Int[]]$ValidateLength,
		[Parameter(Mandatory=$true, ParameterSetName = "ValidatePattern")]
		[ValidateNotNullOrEmpty()]
		[String]$ValidatePattern,
		[Parameter(Mandatory=$true, ParameterSetName = "ValidateScript")]
		[ValidateNotNullOrEmpty()]
		[ScriptBlock]$ValidateScript,
		[Parameter(Mandatory=$true, ParameterSetName = "ValidateNotNullOrEmpty")]
		[Switch]$ValidateNotNullOrEmpty,
		[Parameter(Mandatory=$false)]
		[Switch]$Mandatory,
		[Parameter(Mandatory=$false)]
		[String]$DefaultValue
    )

	$params = @{
		BuildName = $BuildName
		ParameterName = $ParameterName
		DotNetDataType = $DotNetDataType
		Mandatory = $Mandatory.IsPresent
		DefaultValue = $DefaultValue
		ValidationType = $PSCmdlet.ParameterSetName
	}
	
	$params["ValidationValue"] = switch($PSCmdlet.ParameterSetName)
	{
		"ValidateSet" { $ValidateSet -join ',' }
		"ValidateRange" { $ValidateRange -join ',' }
		"ValidateLength" { $ValidateLength -join ',' }
		"ValidatePattern" { $ValidatePattern }
		"ValidateNotNullOrEmpty" { "" }
		"ValidateScript" { $ValidateScript.ToString() }
	}

	New-PSSQLRecord -TableName BuildParameter -Parameters $params -ReturnIdentity
}