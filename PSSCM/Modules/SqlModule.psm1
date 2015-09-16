Function Open-PSSQLConnection
{
	[CmdletBinding(DefaultParameterSetName = "FromModuleConfig")]
	[OutputType([System.Data.SqlClient.SqlConnection])]
	param
    (
		[Parameter(Mandatory = $true, ParameterSetName = "FromModuleConfig")]
		[Switch]$FromModuleConfig,
        [Parameter(Mandatory = $true, ParameterSetName = "SQL", Position = 0)]
		[ValidateNotNullOrEmpty()]
        [String]$ServerName,
		[Parameter(Mandatory = $true, ParameterSetName = "SQL", Position = 1)]
		[ValidateNotNull()]
        [UInt16]$InstancePort,
		[Parameter(Mandatory = $true, ParameterSetName = "Windows", Position = 0)]
		[ValidateNotNullOrEmpty()]
        [String]$Instance,
		[Parameter(Mandatory = $true, ParameterSetName = "Windows", Position = 1)]
		[Parameter(Mandatory = $true, ParameterSetName = "SQL", Position = 2)]
		[ValidateNotNullOrEmpty()]
        [String]$Database,
        [Parameter(Mandatory = $true, ParameterSetName = "SQL", Position = 3)]
		[ValidateNotNullOrEmpty()]
        [String]$Username,
        [Parameter(Mandatory = $true, ParameterSetName = "SQL", Position = 4)]
		[ValidateNotNullOrEmpty()]
        [String]$Password,
		[Parameter(Mandatory = $false)]
		[Switch]$Default
    )
	$ErrorActionPreference = "Stop"
	$sqlCs = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

	if ($FromModuleConfig.IsPresent)
	{
		#Powershell bug feedback ID 400528 - Unable to directly set properties on SqlConnectionStringBuilder
		#Need to use workaround where we use the set_ methods to set the values.
		$sqlCs.set_InitialCatalog($PSSCMConfigData.SQLDatabaseName)
		$sqlCs.set_DataSource([String]::Format("{0},{1}", $PSSCMConfigData.SQLServerName, $PSSCMConfigData.SQLInstancePortNumber))
		$sqlCs.set_NetworkLibrary("DBMSSOCN")
		$sqlCs.set_UserID($PSSCMConfigData.SQLUsername)
		$sqlCs.set_Password($PSSCMConfigData.SQLPassword)
		$sqlCs.set_IntegratedSecurity($false)
	}
	elseif ($PSCmdlet.ParameterSetName -eq "SQL")
	{
		$sqlCs.set_InitialCatalog($Database)
		$sqlCs.set_DataSource("$ServerName,$InstancePort")
		$sqlCs.set_NetworkLibrary("DBMSSOCN")
		$sqlCs.set_UserID($Username)
		$sqlCs.set_Password($Password)
		$sqlCs.set_IntegratedSecurity($false)
	}
	else
	{
		$sqlCs.set_InitialCatalog($Database)
		$sqlCs.set_DataSource($Instance)
		$sqlCs.set_IntegratedSecurity($true)
	}

	Write-Verbose "Connection String -> $($sqlCs.ToString())"
	$sqlCon = New-Object System.Data.SqlClient.SqlConnection($sqlCs.ToString())
	$sqlCon.Open()
	if ($Default) { $global:PSSCMSqlConnection = $sqlCon }
	else { return $sqlCon }
}

Function Close-PSSQLConnection
{
	param
	(
		[Parameter(Mandatory = $false)]
		[Data.SqlClient.SqlConnection]$SqlConnection = $global:PSSCMSqlConnection
	)
	if ($SqlConnection) { $SqlConnection.Dispose() }
	if ($global:PSSCMSqlConnection) { Remove-Variable -Scope Global -Name PSSCMSqlConnection -ErrorAction SilentlyContinue }
}

Function Get-PSSQLRecords
{
    param
    (
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [String]$SQL,
        [Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
        [Collections.IDictionary]$Parameters,
		[Parameter(Mandatory = $false)]
		[Data.SqlClient.SqlConnection]$SqlConnection = $global:PSSCMSqlConnection
    )
    
	if (-not $SqlConnection -or $SqlConnection.State -ne "Open") { throw "You need to open a connection to the database first" }
	
    $cmd = $SqlConnection.CreateCommand()
    if ([Regex]::IsMatch($SQL, '^\w+?\.\w+$')){ $cmd.CommandType = "StoredProcedure" }
    $cmd.CommandText = $SQL
    if ($Parameters)
    {
        foreach ($k in $Parameters.Keys)
        {
            [Void]$cmd.Parameters.AddWithValue('@' + $k,$Parameters[$k])
        }
    }
    $r = $cmd.ExecuteReader()
    while ($r.Read())
    {
        $o = @{}
        for ($i = 0; $i -lt $r.VisibleFieldCount; $i++)
        {
			$value = $r.GetValue($i)
			if ($value -isnot [System.DBNull]) { $o.Add($r.GetName($i), $value) }
			else { $o.Add($r.GetName($i), $null) }
        }
        New-Object PSObject -Property $o
    }
    $r.Dispose()
    $cmd.Dispose()
}

Function Invoke-PSSQLNonQuery
{
    param
    (
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [String]$SQL,
        [Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
        [Collections.IDictionary]$Parameters,
		[Parameter(Mandatory = $false)]
		[Data.SqlClient.SqlConnection]$SqlConnection = $global:PSSCMSqlConnection
    )
    
	if (-not $SqlConnection -or $SqlConnection.State -ne "Open") { throw "You need to open a connection to the database first" }
	
    $cmd = $SqlConnection.CreateCommand()
    if ([Regex]::IsMatch($SQL, '^\w+?\.\w+$')){ $cmd.CommandType = "StoredProcedure" }
    $cmd.CommandText = $SQL
    if ($Parameters)
    {
        foreach ($k in $Parameters.Keys)
        {
            [Void]$cmd.Parameters.AddWithValue('@' + $k,$Parameters[$k])
        }
    }
    $cmd.ExecuteNonQuery()
    $cmd.Dispose()
}

Function Invoke-PSSQLScalar
{
    param
    (
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [String]$SQL,
        [Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
        [Collections.IDictionary]$Parameters,
		[Parameter(Mandatory = $false)]
		[Data.SqlClient.SqlConnection]$SqlConnection = $global:PSSCMSqlConnection
    )
    
	if (-not $SqlConnection -or $SqlConnection.State -ne "Open") { throw "You need to open a connection to the database first" }
	
    $cmd = $SqlConnection.CreateCommand()
    if ([Regex]::IsMatch($SQL, '^\w+?\.\w+$')){ $cmd.CommandType = "StoredProcedure" }
    $cmd.CommandText = $SQL
    if ($Parameters)
    {
        foreach ($k in $Parameters.Keys)
        {
            [Void]$cmd.Parameters.AddWithValue('@' + $k,$Parameters[$k])
        }
    }
    $cmd.ExecuteScalar()
    $cmd.Dispose()
}

Function New-PSSQLRecord
{
    param
    (
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [String]$TableName,
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [Collections.IDictionary]$Parameters,
        [Parameter(Mandatory = $false)]
        [Switch]$ReturnIdentity,
		[Parameter(Mandatory = $false)]
		[Data.SqlClient.SqlConnection]$SqlConnection = $global:PSSCMSqlConnection
    )
    
	if (-not $SqlConnection -or $SqlConnection.State -ne "Open") { throw "You need to open a connection to the database first" }
	
    $cmd = $SqlConnection.CreateCommand()
    $colNames = @()
    foreach ($k in $Parameters.Keys)
    {
        [Void]$cmd.Parameters.AddWithValue('@' + $k,$Parameters[$k])
        $colNames += $k
    }
    
	$insertString = "insert into {0} ({1}) values(@{2})" -f $TableName, [String]::Join(",", $colNames), [String]::Join(",@", $colNames)
	Write-Verbose "Created query '$insertString'"
    $cmd.CommandText = $insertString
    if ($ReturnIdentity)
	{
		$cmd.CommandText += ';select @@identity'
		$cmd.ExecuteScalar()
	}
	else
    {
		$cmd.ExecuteNonQuery()
	}
    $cmd.Dispose()
}

Function Set-PSSQLRecord
{
    param
    (
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [String]$TableName,
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [Collections.IDictionary]$Parameters,
        [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
        [String]$KeyColumn,
		[Parameter(Mandatory = $false)]
		[Data.SqlClient.SqlConnection]$SqlConnection = $global:PSSCMSqlConnection
    )
    
	if (-not $SqlConnection -or $SqlConnection.State -ne "Open") { throw "You need to open a connection to the database first" }
	
    $cmd = $SqlConnection.CreateCommand()
    $updateCols = @()
    foreach ($k in $Parameters.Keys)
    {
        [Void]$cmd.Parameters.AddWithValue('@' + $k,$Parameters[$k])
		if ($k -ne $KeyColumn){ $updateCols += ("{0} = @{0}" -f $k) }
    }
    
	$setString = "update {0} set {1} where {2} = @{2}" -f $TableName,($updateCols -join ","),$KeyColumn
	Write-Verbose "Created query '$setString'"
    $cmd.CommandText = $setString
    $cmd.ExecuteNonQuery()
    $cmd.Dispose()
}
