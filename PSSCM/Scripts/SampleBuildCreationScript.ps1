#Setup

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Open-PSSQLConnection -FromModuleConfig -Default -Verbose

$unattendXml = Get-Content -Path "SampleUnattendDomain.xml" -Raw

$pkgsource = New-PackageSource -SourceName "Default" `
    -OSInstallRootUNC "\\DC1.devopsmachine.com\Share\OSSource" `
    -PackageInstallRootUNC "\\DC1.devopsmachine.com\Share\Packages" `
    -Default

$os = New-OperatingSystem -OSName "Windows Server 2012 R2"

$buildname = "DomainBuild"
$build = New-Build -BuildName $buildname `
    -Version "1.0" `
    -OperatingSystem $os `
    -UnattendXmlTemplate $unattendXml `
    -ImageIndex 2

New-BuildParameter -ParameterName SystemLocale -BuildName $buildname -DotNetDataType String -ValidateLength @(2,16) -DefaultValue "en-US"
New-BuildParameter -ParameterName InputLocale -BuildName $buildname -DotNetDataType String -ValidateLength 2,16 -DefaultValue "en-US"
New-BuildParameter -ParameterName UILanguage -BuildName $buildname -DotNetDataType String -ValidateLength 2,16 -DefaultValue "en-US"
New-BuildParameter -ParameterName ProductKey -BuildName $buildname -DotNetDataType String -ValidateLength 29,29 -Mandatory
New-BuildParameter -ParameterName InitialAdminPassword -BuildName $buildname -DotNetDataType String -ValidateLength 8,32 -Mandatory
New-BuildParameter -ParameterName TimezoneName  -BuildName $buildname -DotNetDataType String -ValidateLength 2,32 -Mandatory
New-BuildParameter -ParameterName FullyQualifiedDomainName  -BuildName $buildname -DotNetDataType String -ValidateLength 2,64 -Mandatory
$domainJoinCredential = Get-Credential -Message "Please enter the credentials of a low privileged user that can join the domain. Use DOMAIN\Username format."
$cred = $domainJoinCredential.GetNetworkCredential()
New-BuildParameter -ParameterName DJUserDomainName  -BuildName $buildname -DotNetDataType String -ValidateLength 2,15 -Default $cred.Domain
New-BuildParameter -ParameterName DJUserName -BuildName $buildname -DotNetDataType String -ValidateLength 2,15 -Default $cred.UserName
New-BuildParameter -ParameterName DJPassword -BuildName $buildname -DotNetDataType String -ValidateLength 2,15 -Default $cred.Password
New-BuildSystemVariable -Name DomainUserName -Value ("{0}\{1}" -f $cred.Domain, $cred.UserName)
New-BuildSystemVariable -Name DomainUserPassword -Value $cred.Password


$formatDisksScript = @'
@"
select disk 0
clean
"@ | diskpart.exe

$diskCount = $global:CurrentBuildInstance.DiskCount
$disks = Get-WmiObject -Class Win32_LogicalDisk -Property DeviceID,DriveType
$usedLetters = $disks | foreach { $_.DeviceID.TrimEnd(':') }
$driveLetters = "CEFGHIJKLMNOPQRSTUV".ToCharArray() | where { $usedLetters -notcontains $_ } | select -First $diskCount
$systemLetter = $driveLetters[0]
Set-BuildInstanceVariable -Name SystemDriveLetter -Value $systemLetter

$sb = New-Object System.Text.StringBuilder
[Void]$sb.AppendLine(@"
select disk 0
clean
create partition primary size=500
format quick fs=ntfs label="System"
active
create partition primary
format quick fs=ntfs label="C_System"
assign letter="$systemLetter"
"@)
if ($diskCount -gt 1)
{
    for ($i = 1;$i -lt $diskCount; $i++)
    {
        [Void]$sb.AppendLine(@"
select disk $i
clean
convert gpt
create partition primary
format quick fs=ntfs
assign letter="$($driveLetters[$i])"
"@)
    }
}
[Void]$sb.AppendLine("exit")

$diskPartScript = $sb.ToString()
Write-Verbose $diskPartScript
$diskPartScript | diskpart.exe

'@

$bs1 = New-BuildStep -BuildName $buildname `
    -StepName FormatDisks `
    -ExecutionOrder 1 `
    -ScriptText ([ScriptBlock]::Create($formatDisksScript)) `
    -ErrorActionPreference Stop `
    -BuildStage WinPE

$applyImageScript = @'
$output = @()
$output += "Retrieving PackageSource details ($($global:CurrentBuildInstance.PackageSourceID))"
$pkgsource = Get-PackageSource -PackageSourceID $global:CurrentBuildInstance.PackageSourceID
$username = Get-BuildSystemVariable -Name DomainUserName
$password = Get-BuildSystemVariable -Name DomainUserPassword

$output += "Mapping Drive letter 'Z' to '$($pkgsource.OSInstallRootUNC)'"
$output += & net.exe use Z: $pkgsource.OSInstallRootUNC /USER:$username $password

$installWim = "Z:\sources\install.wim"
$index = $global:CurrentBuild.ImageIndex
$sysdriveletter = Get-BuildInstanceVariable -Name SystemDriveLetter
if (-not $sysdriveletter) { throw "Failed to retreive BuildInstanceVariable 'SystemDriveLetter'" }
$driveRoot = '{0}:\' -f $sysdriveletter

$output += "Applying Image $index to $driveRoot"
$output += "Executing: & Dism.exe /Apply-Image /ImageFile:$installWim /Index:$index /ApplyDir:$driveRoot"
$output += & Dism.exe /Apply-Image /ImageFile:$installWim /Index:$index /ApplyDir:$driveRoot
& net.exe use Z: /delete
if ($LastExitCode -gt 0)
{
	throw "Failed to apply image => $([String]::Join([Environment]::NewLine,$output))"
}
elseif (-not (Test-Path -Path $driveRoot) -and -not (Test-Path -Path "C:\"))
{
	throw "Image was applied, but drive was not readable => $([String]::Join([Environment]::NewLine,$output))"
}

$winDir = "{0}Windows" -f $driveRoot
$output += "Configuring boot partition"
$output += & bcdboot.exe $winDir /l en-us
if ($LastExitCode -gt 0)
{
	throw "Failed to configure boot partition => $([String]::Join([Environment]::NewLine,$output))"
}

$output
'@

$bs2 = New-BuildStep -BuildName $buildname `
    -StepName InstallImage `
    -ExecutionOrder 2 `
	-ScriptText ([ScriptBlock]::Create($applyImageScript)) `
    -ErrorActionPreference Stop `
    -BuildStage WinPE

$copyUnattendScript = @'
$output = @()
#$sysdriveLetter = Get-BuildInstanceVariable -Name SystemDriveLetter
#$unattendPath = '{0}:\Unattend.xml' -f $sysdriveLetter
$unattendPath = 'C:\Unattend.xml'
$output += "Saving UnattendXml to $unattendPath"
$global:CurrentBuildInstance.UnattendXml | Set-Content -Path $unattendPath

$output += "Copying PSSCM module to new image"
$psscmModuleDir = Split-Path -Path ((Get-Module PSSCM).Path)
#$systemModulePath = '{0}:\Windows\System32\WindowsPowershell\v1.0\Modules\PSSCM' -f $sysdriveLetter
$systemModulePath = 'C:\Windows\System32\WindowsPowershell\v1.0\Modules\PSSCM'
robocopy.exe $psscmModuleDir $systemModulePath /MIR

#$buildscriptLocation = '{0}:\BuildScript.ps1' -f $sysdriveLetter
$buildscriptLocation = 'C:\BuildScript.ps1'
$output += "Copying BuildScript.ps1 to $buildscriptLocation"
Copy-Item -Path X:\BuildScript.ps1 -Destination $buildscriptLocation

$output
'@

$bs3 = New-BuildStep -BuildName $buildname `
    -StepName CopyUnattendXml `
    -ExecutionOrder 3 `
	-ScriptText ([ScriptBlock]::Create($copyUnattendScript)) `
    -ErrorActionPreference Stop `
    -BuildStage WinPE

$copyDSCScript = @'
$dscPath = 'C:\DSC\ConfigureDSC.ps1'
New-Item -ItemType File -Path $dscPath -Force | select -Expand FullName
if (-not [String]::IsNullOrEmpty($global:CurrentBuildInstance.DSCConfigurationData))
{
    '$ConfigurationData = {0}' -f $global:CurrentBuildInstance.DSCConfigurationData |`
        Out-File -FilePath $dscPath -Append -Encoding ascii
}
$global:CurrentBuildInstance.DSCScript | Out-File -FilePath $dscPath -Append -Encoding ascii
& $dscPath
'@

$bs4 = New-BuildStep -BuildName $buildname `
    -StepName CopyDSCScript `
    -ExecutionOrder 4 `
	-ScriptText ([ScriptBlock]::Create($copyDSCScript)) `
    -ErrorActionPreference Stop `
    -BuildStage Windows `
    -ExecuteIfScript ([ScriptBlock]::Create('(-not [String]::IsNullOrWhitespace($global:CurrentBuildInstance.DSCScript))'))

$configDSCPullScript = @'
Configuration pullconfig 
{ 
	LocalConfigurationManager
	{
		ConfigurationID = $global:CurrentBuildInstance.DSCConfigurationID.ToString()
		RefreshMode = 'Pull'
		DownloadManagerName = 'WebDownloadManager'
		RebootNodeIfNeeded = $true
		RefreshFrequencyMins = 15
		ConfigurationModeFrequencyMins = 30
		ConfigurationMode = 'ApplyAndAutoCorrect'
		DownloadManagerCustomData = @{ServerUrl = $global:CurrentBuildInstance.DSCPullServerURI; AllowUnsecureConnection = 'True'}
	}
}
pullconfig
Set-DscLocalConfigurationManager -Path pullconfig -Verbose
'@

$bs5 = New-BuildStep -BuildName $buildname `
    -StepName ConfigureDSCPullAgentScript `
    -ExecutionOrder 5 `
	-ScriptText ([ScriptBlock]::Create($configDSCPullScript)) `
    -ErrorActionPreference Stop `
    -BuildStage Windows `
    -ExecuteIfScript ([ScriptBlock]::Create('(-not [String]::IsNullOrWhitespace($global:CurrentBuildInstance.DSCPullServerURI) -and $global:CurrentBuildInstance.DSCConfigurationID -is [Guid])'))

New-BuildInstance -BuildName $buildname -ComputerName JYDEMO2 -PackageSource $pkgsource -UserLocale "en-US" -RequestedBy "Justin" `
	-MACAddresses "00155D2C7604" -DSCConfigurationID ([Guid]::NewGuid()) -DSCPullServerURI "http://SQL1.devopsmachine.com:8080/PSDSCPullServer.svc" `
	-SystemLocale "en-US" -InputLocale "en-US" -UILanguage "en-US" -ProductKey 9J8XN-F6X49-B3PRY-4CKWQ-C36PM `
	-InitialAdminPassword $cred.Password -TimezoneName "Pacific Standard Time" `
	-FullyQualifiedDomainName "devopsmachine.com" -DJUserDomainName $cred.Domain -DJUsername $cred.UserName -DJPassword $cred.Password -Verbose