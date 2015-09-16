Function New-PackageSource
{
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateLength(1,32)]
		[String]$SourceName,
		[Parameter(Mandatory = $true)]
		[ValidateScript({if (Test-Path -Path $_){ $true } else { throw "OSInstallRoot directory does not exist"}})]
		[String]$OSInstallRootUNC,
		[Parameter(Mandatory = $false)]
		[ValidateScript({if (Test-Path -Path $_){ $true } else { throw "PackageInstallRoot directory does not exist"}})]
		[String]$PackageInstallRootUNC,
		[Parameter(Mandatory = $false)]
		[Switch]$Default
	)
	
	[Void]$PSBoundParameters.Add("IsDefault",$Default.IsPresent)
    if ($Default) { [Void]$PSBoundParameters.Remove("Default") }
	$id = New-PSSQLRecord -TableName PackageSource -Parameters $PSBoundParameters -ReturnIdentity
	Get-PackageSource -PackageSourceID $id
}

Function Get-PackageSource
{
	[CmdletBinding(DefaultParameterSetName = "All")]
	param
	(
		[Parameter(Mandatory=$true,ParameterSetName = "ByName")]
		[ValidateNotNullOrEmpty()]
		[String]$SourceName,
		[Parameter(Mandatory=$true,ParameterSetName = "ByID")]
		[ValidateNotNull()]
		[Int]$PackageSourceID
	)
	
	switch($PSCmdlet.ParameterSetName) 
	{
		"ByName" {
			Get-PSSQLRecords -SQL "select top 1 *,'PackageSource' as PSTypeName from PackageSource where SourceName = @SourceName" `
				-Parameters @{SourceName = $SourceName}
			}
		"ByID" {
			Get-PSSQLRecords -SQL "select top 1 *,'PackageSource' as PSTypeName from PackageSource where PackageSourceID = @PackageSourceID" `
				-Parameters @{PackageSourceID = $PackageSourceID}
			}
		default {
			Get-PSSQLRecords -SQL "select *,'PackageSource' as PSTypeName from PackageSource"
			}
	}
}

Function New-OperatingSystem
{
	param
	(
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$OSName
	)
	
	$id = New-PSSQLRecord -TableName OperatingSystem -Parameters @{OSName = $OSName} -ReturnIdentity
	Get-OperatingSystem -OperatingSystemID $id
}

Function Get-OperatingSystem
{
	[CmdletBinding(DefaultParameterSetName = "All")]
	param
	(
		[Parameter(Mandatory=$true, ParameterSetName = "ByName")]
		[ValidateNotNullOrEmpty()]
		[String]$OSName,
		[Parameter(Mandatory=$true, ParameterSetName = "ByID")]
		[ValidateNotNull()]
		[Byte]$OperatingSystemID
	)
	
	switch($PSCmdlet.ParameterSetName) 
	{
		"ByName" {
			Get-PSSQLRecords -SQL "select top 1 *,'OperatingSystem' as PSTypeName from OperatingSystem where OSName = @OSName" `
				-Parameters @{OSName = $OSName}
			}
		"ByID" {
			Get-PSSQLRecords -SQL "select top 1 *,'OperatingSystem' as PSTypeName from OperatingSystem where OperatingSystemID = @OperatingSystemID" `
				-Parameters @{OperatingSystemID = $OperatingSystemID}
			}
		default {
			Get-PSSQLRecords -SQL "select *,'OperatingSystem' as PSTypeName from OperatingSystem"
			}
	}
}
