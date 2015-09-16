Function Import-BuildInstanceVariables
{
    param
    (
        [Parameter(Mandatory=$true)]
		[ValidateNotNull()]
		[Int]$BuildInstanceID
    )

    if (-not $global:BuildVariables -or $global:BuildVariables.Count -eq 0)
    {
        $global:BuildVariables = @{}
        Get-PSSQLRecords -SQL "select *,'BuildInstanceVariable' as PSTypeName from BuildInstanceVariable where BuildInstanceID = @BuildInstanceID" `
		    -Parameters @{ BuildInstanceID = $BuildInstanceID} | `
            select BuildInstanceVariableID, VariableName, TypeName, @{N = "Value"; E = {
                if (-not $_.Value -or $_.TypeName -in @("String", "Char")) { $_.Value }
                else { Invoke-Expression -Command "[$($_.TypeName)]'$_.Value'" }}} | `
            foreach {
                $global:BuildVariables.Add($_.VariableName,$_)
            }
    }
}

Function Get-BuildInstanceVariable
{
    param
    (
        [Parameter(Mandatory=$true)]
		[ValidateLength(2,32)]
		[String]$Name,
        [Parameter(Mandatory=$false)]
        [Object]$BuildInstance = $global:CurrentBuildInstance
    )

    #Do it every time since the Import function checks if they already have been imported.
    Import-BuildInstanceVariables -BuildInstanceID $BuildInstance.BuildInstanceID

    return $global:BuildVariables[$Name].Value
}

Function Set-BuildInstanceVariable
{
    param
    (
        [Parameter(Mandatory=$true)]
		[ValidateLength(2,32)]
		[String]$Name,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
		[Object]$Value,
        [Parameter(Mandatory=$false)]
        [Object]$BuildInstance = $global:CurrentBuildInstance
    )

    Import-BuildInstanceVariables -BuildInstanceID $BuildInstance.BuildInstanceID
    
    $type = Test-VariableType -Value $Value -ErrorAction Stop

    if ($global:BuildVariables.ContainsKey($Name))
    {
        $global:BuildVariables[$Name].TypeName = $type
        $global:BuildVariables[$Name].Value = $Value
		Invoke-PSSQLNonQuery -SQL "update BuildInstanceVariable set TypeName = @TypeName, Value = @Value where BuildInstanceID = @BuildInstanceID and VariableName = @VariableName" `
            -Parameters @{BuildInstanceID = $BuildInstance.BuildInstanceID; VariableName = $Name; TypeName = $type; Value = "$Value" } | Out-Null
    }
    else
    {
        $props = @{VariableName = $Name; TypeName = $type; Value = "$Value"; BuildInstanceID = $BuildInstance.BuildInstanceID }
        $id = New-PSSQLRecord -TableName BuildInstanceVariable -ReturnIdentity -Parameters $props
        $props.Add("BuildInstanceVariableID", $id)
        $props["Value"] = $Value #We updated the DB with a string, so we need to set it back to the actual type.
        $global:BuildVariables[$Name] = New-Object PSObject -Property $props
    }
}

Function Import-BuildSystemVariables
{
    if (-not $global:BuildSystemVariables)
    {
        $global:BuildSystemVariables = @{}
        Get-PSSQLRecords -SQL "select * from BuildSystemVariable" | `
            select BuildSystemVariableName, @{N = "Value"; E = {
                if (-not $_.Value -or $_.TypeName -eq "String") { $_.Value }
                else { Invoke-Expression -Command "[$($_.TypeName)]'$_.Value'" }}} | `
            foreach {
                $global:BuildSystemVariables.Add($_.BuildSystemVariableName,$_.Value)
            }
    }
}

Function Get-BuildSystemVariable
{
    param
    (
        [Parameter(Mandatory=$true)]
		[ValidateLength(2,32)]
		[String]$Name
    )

    #Do it every time since the Import function checks if they already have been imported.
    Import-BuildSystemVariables

    return $global:BuildSystemVariables[$Name]
}

Function New-BuildSystemVariable
{
    param
    (
        [Parameter(Mandatory=$true)]
		[ValidateLength(2,32)]
		[String]$Name,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
		[Object]$Value
    )

    $type = Test-VariableType -Value $Value -ErrorAction Stop
    New-PSSQLRecord -TableName BuildSystemVariable `
        -Parameters @{ BuildSystemVariableName = $Name; TypeName = $type; Value = "$Value" } | Out-Null
}

Function Set-BuildSystemVariable
{
    param
    (
        [Parameter(Mandatory=$true)]
		[ValidateLength(2,32)]
		[String]$Name,
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
		[Object]$Value
    )

    $type = Test-VariableType -Value $Value -ErrorAction Stop
    Set-PSSQLRecord -TableName BuildSystemVariable -KeyColumn BuildSystemVariableName `
        -Parameters @{ BuildSystemVariableName = $Name; TypeName = $type; Value = "$Value"} | Out-Null
}

Function Test-VariableType
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        $Value
    )

    $supportedTypes = @("Char","String","Byte","Int16","Int32","Int64","Guid","Uri")
    $type = $Value.GetType().Name
    if ($type -notin $supportedTypes)
    {
        throw "$type is not a persistable type. Only types $($supportedTypes -join ',') can be persisted."
    }
    return $type
}