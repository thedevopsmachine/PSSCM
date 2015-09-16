Import-Module Pester
Import-Module C:\Users\justin.yancey\Documents\PSSCM\PSSCM\Modules\PSSCM.psd1

Describe "Open-PSSQLConnection" 
{
	AfterEach 
	{
		if ($global:PSSCMSqlConnection) { Close-PSSQLConnection }
	}

	It "OpensANewSQLConnectionUsingModuleFile" 
	{
		Open-PSSQLConnection -FromModuleConfig -Default
		($global:PSSCMSqlConnection -is [System.Data.SqlClient.SqlConnection]) | Should Be $true
	}
	It "OpensANewSQLConnectionUsingWindowsAuth" 
	{
		throw "Not Implemented"
	}
	It "OpensANewSQLConnectionUsingSQLAuth" 
	{
		throw "Not Implemented"
	}
}

Describe "Close-PSSQLConnection"
{
	Open-PSSQLConnection -FromModuleConfig -Default

	It "ClosesAnExistingPSSQLConnection"
	{
		Close-PSSQLConnection
		($global:PSSCMSqlConnection -eq $null) | Should Be $true
	}
}

Describe "Get-PSSQLRecords"
{
	Open-PSSQLConnection -FromModuleConfig -Default
	Invoke-PSSQLNonQuery -SQL

	It "RetrievesSQLRecordsFromDB"
	{
		throw "Not Implemented"
	}

	Close-PSSQLConnection
}

Describe "Set-PSSQLRecord"
{
	It "UpdatesAnExistingRow"
	{
		throw "Not Implemented"
	}
}

Describe "New-PSSQLRecord"
{
	It "CreatesANewRow"
	{
		throw "Not Implemented"
	}
	It "CreatesANewRowAndReturnIdentity"
	{
		throw "Not Implemented"
	}
}

Describe "Invoke-PSSQLNonQuery"
{
	It "ShouldWork"
	{
		throw "Not Implemented"
	}
}

Describe "Invoke-PSSQLScalar"
{
	It "ShouldWork"
	{
		throw "Not Implemented"
	}
}