Import-Module PSSCM

$ErrorActionPreference = "Stop"

trap
{
	$now = [DateTimeOffset]::Now
	if ($global:CurrentBuildStepInstance -is [Object])
    {
        Set-PSSQLRecord -TableName BuildStepInstance -KeyColumn BuildStepInstanceID `
			-Parameters @{
				BuildStepInstanceID = $global:CurrentBuildStepInstance.BuildStepInstanceID
				Status = "Failed"
				ErrorDetails = (Format-Exception -Exception $_.Exception -LineNumber $_.InvocationInfo.ScriptLineNumber)
				FinishedAtDTO = $now
			}| Out-Null
    }
    if ($global:CurrentBuildInstance -is [Object])
    {
        Set-PSSQLRecord -TableName BuildInstance -KeyColumn BuildInstanceID `
			-Parameters @{
				BuildInstanceID = $global:CurrentBuildInstance.BuildInstanceID
				Status = "Failed"
				FinishedAtDTO = $now
			} | Out-Null
    }
    
	Write-Error -Exception $_.Exception -ErrorAction Continue

    if ((Read-Host -Prompt "Press R then Enter to reboot, otherwise just hit Enter to exit") -eq "R")
	{
        Restart-Computer -Force
    }
    exit $_.InvocationInfo.ScriptLineNumber
}

Open-PSSQLConnection -FromModuleConfig -Default

Import-BuildSystemVariables

Find-BuildInstance -Verbose #This sets the $Global:CurrentBuild and $Global:CurrentBuildInstance variables

Import-BuildInstanceVariables -BuildInstanceID $Global:CurrentBuildInstance.BuildInstanceID

Invoke-Build -Build $Global:CurrentBuild -BuildInstance $Global:CurrentBuildInstance -Verbose

Close-PSSQLConnection

if ($Global:CurrentBuildInstance.Status -ne "Failed")
{
	Restart-Computer -Force
}
