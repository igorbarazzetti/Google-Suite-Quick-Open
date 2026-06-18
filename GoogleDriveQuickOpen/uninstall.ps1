param([switch]$NoBackup)

$ErrorActionPreference = "Stop"

$AppDisplayName = "Google Suite Quick Open"
$AppRegistryName = "GoogleSuiteQuickOpen"
$InstallDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$classes = "HKCU:\Software\Classes"

$extMap = @{
    ".doc" = "OpenInGoogleDocFile"
    ".docx" = "OpenInGoogleDocFile"
    ".rtf" = "OpenInGoogleDocFile"
    ".odt" = "OpenInGoogleDocFile"
    ".xls" = "OpenInGoogleSheetFile"
    ".xlsx" = "OpenInGoogleSheetFile"
    ".csv" = "OpenInGoogleSheetFile"
    ".ods" = "OpenInGoogleSheetFile"
    ".ppt" = "OpenInGoogleSlideFile"
    ".pptx" = "OpenInGoogleSlideFile"
}

if (-not $NoBackup) {
    $backupPath = Join-Path $InstallDir "extension-association-backup.json"
    if (Test-Path $backupPath) {
        try {
            $backupObj = Get-Content -Path $backupPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $backup = @{}
            foreach ($prop in $backupObj.PSObject.Properties) {
                $backup[$prop.Name] = $prop.Value
            }

            foreach ($entry in $extMap.Keys) {
                $ext = $entry
                $target = Join-Path $classes $ext
                if (-not (Test-Path $target)) {
                    continue
                }
                if ($backup.ContainsKey($ext)) {
                    $value = $backup[$ext]
                    if ($null -ne $value) {
                        New-Item -Path $target -Force | Out-Null
                        Set-ItemProperty -Path $target -Name "(default)" -Value $value -Force
                    }
                    else {
                        Remove-ItemProperty -Path $target -Name "(default)" -ErrorAction SilentlyContinue
                    }
                }
            }
        }
        catch {
        }
    }
}

$docProgIds = @(
    "OpenInGoogleDocFile",
    "OpenOffice.Doc",
    "OpenOffice.Docx",
    "Word.Document.8",
    "Word.Document.12"
)

$sheetProgIds = @(
    "OpenInGoogleSheetFile",
    "OpenOffice.Xls",
    "OpenOffice.Xlsx",
    "Excel.Sheet.8",
    "Excel.Sheet.12"
)

$slideProgIds = @(
    "OpenInGoogleSlideFile",
    "PowerPoint.Show",
    "PowerPoint.Show.8",
    "PowerPoint.Show.12",
    "PowerPoint.Application"
)

foreach ($ext in $extMap.Keys) {
    $extKey = Join-Path $classes $ext
    Remove-Item -Path (Join-Path $extKey "shell") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $extKey "DefaultIcon") -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($id in @($docProgIds + $sheetProgIds + $slideProgIds)) {
    Remove-Item -Path (Join-Path $classes $id) -Recurse -Force -ErrorAction SilentlyContinue
}

$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppRegistryName"
Remove-Item -Path $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "$AppDisplayName removido."
ie4uinit.exe -show
