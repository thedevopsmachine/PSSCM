param
(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[String]$DeploymentShareUNCPath,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String]$WinPETargetPath = "C:\winpe",
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String]$TargetISOFilePath = "C:\PowerBoot.iso",
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String]$DriverPath = "C:\WinPEDrivers",
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String[]]$PackageFileNames = @("WinPE-WMI.cab","WinPE-NetFx.cab","WinPE-Scripting.cab","WinPE-PowerShell.cab","WinPE-SecureStartup.cab","WinPE-DismCmdlets.cab","WinPE-StorageWMI.cab"),
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String]$ADKRoot = 'C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit',
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String]$WinPEArchitecture = "amd64",
	[Parameter(Mandatory = $false)]
	[ValidateNotNull()]
	[Byte]$ImageIndex = 1
)

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
$workingDirectory = "$WinPETargetPath\$WinPEArchitecture"

$winPERoot = "$ADKRoot\Windows Preinstallation Environment\$WinPEArchitecture"
if (-not (Test-Path -Path $winPERoot)) 
{
	throw "No files were found at path $winPERoot. Have you installed the Windows ADK?"
}

$mountPath = "$workingDirectory\mount"
if (-not (Test-Path -Path $mountPath)) { New-Item -ItemType Container -Path $mountPath -Force }
Write-Verbose "Copying source files to working directory"
& robocopy.exe "$winPERoot\Media" $workingDirectory /E

$imageDest = "$workingDirectory\sources"
if (-not (Test-Path -Path $imageDest)) { New-Item -ItemType Container -Path $imageDest -Force }
Copy-Item -Path "$winPERoot\en-us\winpe.wim" -Destination "$imageDest\boot.wim" -Force

$fwFilesSource = "$ADKRoot\Deployment Tools\$WinPEArchitecture\Oscdimg"
$fwFilesDest = "$workingDirectory\fwfiles"
if (-not (Test-Path -Path $fwFilesDest)) { New-Item -ItemType Container -Path $fwFilesDest -Force }

Copy-Item -Path "$fwFilesSource\efisys.bin" -Destination $fwFilesDest
if (Test-Path -Path "$fwFilesSource\etfsboot.com") { 
	Copy-Item -Path "$fwFilesSource\etfsboot.com" -Destination $fwFilesDest 
}

Write-Verbose "Mounting Windows Image file"
Mount-WindowsImage -Path $mountPath -ImagePath "$imageDest\boot.wim" -Index $ImageIndex

if (Get-ChildItem -Path $DriverPath -EA SilentlyContinue)
{
	Write-Verbose "Importing drivers"
    Add-WindowsDriver -Path $mountPath -Driver $DriverPath -Recurse -ForceUnsigned
}

foreach ($p in $PackageFileNames)
{
	Write-Verbose "Installing package $p"
    Add-WindowsPackage -Path $mountPath -PackagePath "$WinPERoot\WinPE_OCs\$p"
}

Write-Verbose "Setting the WinPE system target path to X:\"
& dism.exe /Image:$mountPath /set-targetpath:X:\

$pscred = Get-Credential -Message "Please enter the credentials of a low privileged user that can map a drive to a network share on the domain. Use DOMAIN\Username format."
$cred = $pscred.GetNetworkCredential()

Write-Verbose "Generating and Saving startnet.cmd to Image"
@'
@echo off
echo Initializing WinPE
Wpeinit

echo Mapping network drive to {0}
net use Y: {0} /USER:{1}\{2} {3}

echo Copying PSSCM module files
robocopy.exe Y:\PSSCM X:\Windows\System32\WindowsPowershell\v1.0\Modules\PSSCM /E

echo Copying BuildScript.ps1
echo "F" | xcopy Y:\BuildScript.ps1 X:\BuildScript.ps1

echo Unmapping network drive
net use Y: /delete

echo Executing BuildScript.ps1
powershell.exe -ExecutionPolicy Bypass X:\BuildScript.ps1

'@ -f  $DeploymentShareUNCPath, $cred.Domain, $cred.UserName, $cred.Password | `
	Set-Content "$mountPath\Windows\System32\startnet.cmd" -Force

Write-Verbose "Dismounting the Windows image"
Dismount-WindowsImage -Path $mountPath -Save

Write-Verbose "Cleaning up working directory"
Remove-Item -Path $mountPath -Force -Recurse

if (Test-Path -Path $TargetISOFilePath) 
{
	Write-Verbose "Deleting existing ISO"
	Remove-Item -Path $TargetISOFilePath -Force 
}

Write-Verbose "Generating the boot data"
$bootdata = '1#pEF,e,b"{0}\efisys.bin"' -f $fwFilesDest
if (Test-Path -Path "$fwFilesDest\etfsboot.com") 
{
	$bootdata = '2#p0,e,b"{0}\etfsboot.com"#pEF,e,b"{0}\efisys.bin"' -f $fwFilesDest
}

Write-Verbose "Creating the ISO"
& "$fwFilesSource\oscdimg.exe" -bootdata:$bootdata -u1 -udfver102 "$workingDirectory" $TargetISOFilePath

Write-Verbose "ISO Created successfully"