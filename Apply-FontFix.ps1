#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$expectedSourceHash = '8A6CBC98292B1A239BDDC8A298DD2B5EEA541D77AB8331A240D1599C1DA12882'
$expectedFixedHash  = '344007CAC0042AB2D1EEF831426419C423151B6C7FD4566045D7F2FA9F853F54'

$metricOffset = 0x2AB278
$metricBefore = [byte[]](0x10,0x00,0x00,0x00, 0x18,0x00,0x00,0x00, 0x15,0x00,0x00,0x00, 0x04,0x00,0x00,0x00, 0x0C,0x00,0x00,0x00, 0x18,0x00,0x00,0x00)
$metricAfter  = [byte[]](0x1A,0x00,0x00,0x00, 0x24,0x00,0x00,0x00, 0x1E,0x00,0x00,0x00, 0x06,0x00,0x00,0x00, 0x11,0x00,0x00,0x00, 0x24,0x00,0x00,0x00)

$fontDataOffset = 0x2AB4D8
$fontDataBefore = [byte[]](0x70,0x00,0x00,0x00, 0x70,0x00,0x00,0x00, 0x62,0x00,0x00,0x00, 0x04,0x00,0x00,0x00, 0x24,0x00,0x00,0x00, 0x80,0x00,0x00,0x00, 0x10,0x00,0x00,0x00, 0x20,0x00,0x00,0x00, 0x06,0x00,0x00,0x00)
$fontDataAfter  = [byte[]](0x24,0x00,0x00,0x00, 0x30,0x00,0x00,0x00, 0x30,0x00,0x00,0x00, 0x08,0x00,0x00,0x00, 0x18,0x00,0x00,0x00, 0x30,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00)

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Test-BytesAtOffset([byte[]]$Data, [int]$Offset, [byte[]]$Expected) {
    for ($i = 0; $i -lt $Expected.Length; $i++) {
        if ($Data[$Offset + $i] -ne $Expected[$i]) { return $false }
    }
    return $true
}

function Set-BytesAtOffset([byte[]]$Data, [int]$Offset, [byte[]]$Replacement) {
    [Array]::Copy($Replacement, 0, $Data, $Offset, $Replacement.Length)
}

Add-Type -AssemblyName System.Windows.Forms
$picker = New-Object System.Windows.Forms.FolderBrowserDialog
$picker.Description = 'Select the Exanima folder containing Exanima.exe'
$picker.ShowNewFolderButton = $false
if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host 'Cancelled. No files were changed.'
    exit 0
}

$exePath = Join-Path $picker.SelectedPath 'Exanima.exe'
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw 'Exanima.exe was not found in the selected folder. No files were changed.'
}

if (Get-Process -Name Exanima -ErrorAction SilentlyContinue) {
    throw 'Close Exanima before running this patch.'
}

$currentHash = Get-Sha256 $exePath
if ($currentHash -eq $expectedFixedHash) {
    Write-Host 'The font fix is already installed. No files were changed.'
    exit 0
}
if ($currentHash -ne $expectedSourceHash) {
    throw 'This is not the verified Exanima 0.9.5.2 plus ZoG 1.5.6 executable. No files were changed.'
}

$data = [IO.File]::ReadAllBytes($exePath)
if (-not (Test-BytesAtOffset $data $metricOffset $metricBefore) -or
    -not (Test-BytesAtOffset $data $fontDataOffset $fontDataBefore)) {
    throw 'The executable data does not match the expected version. No files were changed.'
}

Set-BytesAtOffset $data $metricOffset $metricAfter
Set-BytesAtOffset $data $fontDataOffset $fontDataAfter

$stamp = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), (Get-Random -Minimum 1000 -Maximum 9999)
$backupPath = "$exePath.before-font-fix-$stamp.bak"
$tempPath = "$exePath.font-fix.tmp"
if (Test-Path -LiteralPath $tempPath) {
    throw 'A temporary file from an earlier run already exists. Check the game folder before trying again.'
}

try {
    [IO.File]::WriteAllBytes($tempPath, $data)
    if ((Get-Sha256 $tempPath) -ne $expectedFixedHash) {
        throw 'The prepared file failed its checksum check. The original executable was not replaced.'
    }
    [IO.File]::Replace($tempPath, $exePath, $backupPath)
    if ((Get-Sha256 $exePath) -ne $expectedFixedHash) {
        Copy-Item -LiteralPath $backupPath -Destination $exePath -Force
        throw 'The replaced file failed verification. The original executable has been restored.'
    }
}
finally {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}

Write-Host 'Done. The font fix was applied and verified.'
Write-Host "Backup: $backupPath"
Write-Host 'Launch the game through Steam and check the text in fullscreen mode.'


