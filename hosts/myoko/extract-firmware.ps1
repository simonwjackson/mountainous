<#
.SYNOPSIS
    Copy the Qualcomm firmware that Linux needs off this Windows install.

.DESCRIPTION
    The ASUS Zenbook A16 (UX3607OA) devicetree asks the kernel for firmware
    under qcom/glymur/ASUSTeK/UX3607OA/. Those files are not in
    linux-firmware. The only copy you own sits in the Windows driver store,
    so take it before the disk is wiped.

    Run this from the OOBE command prompt (Shift+F10) if you do not want a
    Windows account. C:\Windows is already in place at that point.

    The script writes:
      <Destination>\myoko-firmware\qcom\glymur\ASUSTeK\UX3607OA\  the blobs
      <Destination>\myoko-firmware\manifest.csv                   name, source, size, SHA256
      <Destination>\myoko-firmware\system-info.txt                BIOS, disks, build
      <Destination>\myoko-firmware\driver-store\                  only with -Full

.PARAMETER Destination
    Drive or folder to copy into. Omit it and the script picks the only
    removable volume it can find.

.PARAMETER Full
    Also copy every Qualcomm driver package folder whole. Slow, several GB,
    and the way to catch files this script does not know to ask for, such as
    Wi-Fi board data.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\extract-firmware.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\extract-firmware.ps1 -Destination E: -Full
#>
[CmdletBinding()]
param(
    [string] $Destination,
    [switch] $Full,
    [string] $WindowsRoot = $env:SystemRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Named by the board devicetree. Missing any of these means no audio and no
# compute DSP on the installed system.
$Required = @(
    'qcadsp8480.mbn',
    'adsp_dtbs.elf',
    'qccdsp8480.mbn',
    'cdsp_dtbs.elf',
    'soccp.mbn',
    'soccp_dtb.mbn'
)

# Useful, but the system boots without them.
$Optional = @(
    'adspr.jsn',
    'adsps.jsn',
    'adspua.jsn',
    'cdspr.jsn',
    'battmgr.jsn',
    'qcdxkmsuc8380.mbn',
    'qcdxkmsucpurwa.mbn'
)

function Resolve-Destination {
    param([string] $Requested)

    if ($Requested) {
        if (-not (Test-Path -LiteralPath $Requested)) {
            throw "Destination '$Requested' does not exist."
        }
        return (Resolve-Path -LiteralPath $Requested).Path
    }

    $removable = @(Get-Volume |
        Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter })

    if ($removable.Count -eq 0) {
        throw 'No removable drive found. Pass -Destination explicitly.'
    }
    if ($removable.Count -gt 1) {
        $letters = ($removable | ForEach-Object { $_.DriveLetter }) -join ', '
        throw "More than one removable drive ($letters). Pass -Destination explicitly."
    }

    return ('{0}:\' -f $removable[0].DriveLetter)
}

function Get-FirmwareCandidates {
    param([string] $Repository, [string[]] $Names)

    $wanted = New-Object 'System.Collections.Generic.HashSet[string]' (
        [string[]] $Names, [System.StringComparer]::OrdinalIgnoreCase)

    Write-Host "Scanning $Repository ..."
    $matches = Get-ChildItem -LiteralPath $Repository -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $wanted.Contains($_.Name) }

    # The driver store keeps one folder per driver version. Newest wins, and
    # the manifest records which copy that was.
    $matches | Group-Object -Property Name | ForEach-Object {
        $_.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
}

function Write-SystemInfo {
    param([string] $Path)

    $lines = New-Object System.Collections.ArrayList
    [void] $lines.Add("Captured: $(Get-Date -Format s)")

    foreach ($probe in @(
            @{ Label = 'BIOS'; Script = { Get-CimInstance Win32_BIOS | Format-List Manufacturer, Name, SMBIOSBIOSVersion, ReleaseDate } },
            @{ Label = 'Model'; Script = { Get-CimInstance Win32_ComputerSystem | Format-List Manufacturer, Model, SystemSKUNumber } },
            @{ Label = 'Windows'; Script = { Get-CimInstance Win32_OperatingSystem | Format-List Caption, Version, BuildNumber, OSArchitecture } },
            @{ Label = 'Disks'; Script = { Get-Disk | Format-Table -AutoSize Number, FriendlyName, SerialNumber, Size, PartitionStyle } },
            @{ Label = 'Partitions'; Script = { Get-Partition | Format-Table -AutoSize DiskNumber, PartitionNumber, DriveLetter, Size, Type } },
            @{ Label = 'BitLocker'; Script = { Get-BitLockerVolume | Format-Table -AutoSize MountPoint, VolumeStatus, ProtectionStatus } }
        )) {
        [void] $lines.Add('')
        [void] $lines.Add("== $($probe.Label) ==")
        try {
            [void] $lines.AddRange(@(& $probe.Script | Out-String -Width 200))
        } catch {
            [void] $lines.Add("unavailable: $($_.Exception.Message)")
        }
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}

$repository = Join-Path $WindowsRoot 'System32\DriverStore\FileRepository'
if (-not (Test-Path -LiteralPath $repository)) {
    throw "Driver store not found at $repository. Pass -WindowsRoot for an offline install."
}

$root = Join-Path (Resolve-Destination -Requested $Destination) 'myoko-firmware'
$firmwareDir = Join-Path $root 'qcom\glymur\ASUSTeK\UX3607OA'
New-Item -ItemType Directory -Force -Path $firmwareDir | Out-Null

$found = @(Get-FirmwareCandidates -Repository $repository -Names ($Required + $Optional))

$manifest = foreach ($file in $found) {
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $firmwareDir $file.Name) -Force
    [PSCustomObject] @{
        Name     = $file.Name
        Bytes    = $file.Length
        Modified = $file.LastWriteTime.ToString('s')
        SHA256   = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        Source   = $file.FullName
    }
}

if ($manifest) {
    $manifest | Sort-Object Name | Export-Csv -LiteralPath (Join-Path $root 'manifest.csv') -NoTypeInformation
}

Write-SystemInfo -Path (Join-Path $root 'system-info.txt')

if ($Full) {
    $packageDir = Join-Path $root 'driver-store'
    New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

    $packages = @(Get-ChildItem -LiteralPath $repository -Directory |
        Where-Object { $_.Name -like 'qc*' -or $_.Name -like 'qual*' })

    Write-Host "Copying $($packages.Count) Qualcomm driver packages. This takes a while."
    foreach ($package in $packages) {
        Copy-Item -LiteralPath $package.FullName -Destination $packageDir -Recurse -Force -ErrorAction Continue
    }
}

$copied = @($manifest | ForEach-Object { $_.Name })
$missingRequired = @($Required | Where-Object { $copied -notcontains $_ })
$missingOptional = @($Optional | Where-Object { $copied -notcontains $_ })

Write-Host ''
Write-Host "Wrote $root"
Write-Host "Copied $($copied.Count) files."

if ($missingOptional.Count -gt 0) {
    Write-Host "Optional files not found: $($missingOptional -join ', ')"
}

if ($missingRequired.Count -gt 0) {
    Write-Host ''
    Write-Warning "Required firmware missing: $($missingRequired -join ', ')"
    Write-Warning 'Re-run with -Full and search the copy by hand before wiping this disk.'
    exit 1
}

Write-Host 'All required firmware copied. Verify the files exist on the drive before wiping.'
exit 0
