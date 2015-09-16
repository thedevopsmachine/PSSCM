#########################################################################################################
# Configuration Variables
#########################################################################################################

$global:PSSCMConfigData = @{
	SQLServerName = 'SQL1.devopsmachine.com'
    SQLInstancePortNumber = 1433
    SQLDatabaseName = 'PSSCMDB'
    SQLUsername = 'SQLUser'
    SQLPassword = '$QLPassword!'
	DomainUserName = "dj"
	DomainUserPassword = "Password1!"
	DomainName = "DOM"
}

#########################################################################################################
# Common functions
#########################################################################################################

Function ConvertTo-Dictionary
{
	param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Object]$Object,
		[Parameter(Mandatory = $false)]
		[Switch]$Ordered,
		[Parameter(Mandatory = $false)]
		[Switch]$ExcludeNulls
	)
	
	begin
	{
		if ($Ordered -and $PSVersionTable.PSVersion.Major -ge 3) 
		{ 
			#Need to use Invoke-Expression, otherwise the module won't load when running in PSv2
			$dict = Invoke-Expression '[Ordered]@{}'
		}
		else { $dict = @{} }
	}
	process
	{
		$dict.Clear()
		foreach ($prop in $Object.PSObject.Properties)
		{
			if (-not $ExcludeNulls -or $prop.Value -is [Object]) 
			{
				$dict.Add($prop.Name,$prop.Value)
			}
		}
		Write-Output $dict
	}
}


Function Format-Exception
{
	param
	(
		[Parameter(Mandatory=$true)]
		[Exception]$Exception,
        [Parameter(Mandatory=$false)]
        [Int]$LineNumber
	)
	
	##TODO: Make this loop through all of the inner exceptions and reformat to get the entire story.
	"$Exception"
}