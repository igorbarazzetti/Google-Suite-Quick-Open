param(
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$AppDisplayName = "Google Suite Quick Open"
$AppRegistryName = "GoogleSuiteQuickOpen"
$InstallDir = Join-Path $env:LOCALAPPDATA "GoogleDriveQuickOpen"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

function Test-PythonCommand {
    param([Parameter(Mandatory)][string]$Path)

    if ($Path -like "*WindowsApps*") {
        return $false
    }

    try {
        $info = & "$Path" --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        return ($info -match "Python 3\.")
    } catch {
        return $false
    }
}

function Resolve-RealPython {
    $candidates = @()

    foreach ($cmd in @("pythonw", "python", "python3")) {
        $resolved = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($resolved) {
            $candidates += $resolved.Source
        }
    }

    $roots = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python"),
        (Join-Path $env:PROGRAMFILES "Python"),
        (Join-Path ${env:ProgramFiles(x86)} "Python")
    )

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -Path $root -Recurse -File -Filter "python*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -in @("python.exe", "pythonw.exe") } |
            ForEach-Object { $candidates += $_.FullName }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-PythonCommand -Path $candidate) {
            return $candidate
        }
    }

    throw "Python 3.x nao encontrado. Instale Python 3.12+ e adicione ao PATH."
}

function Save-OfficialIcon {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Url
    )

    Add-Type -AssemblyName System.Drawing
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        $downloaded = $response.Content
        if ($downloaded -is [string]) {
            $downloaded = [System.Text.Encoding]::UTF8.GetBytes($downloaded)
        }
        if (-not $downloaded -or $downloaded.Length -lt 32) {
            return $false
        }

        $srcStream = [System.IO.MemoryStream]::new($downloaded)
        $sourceImage = [System.Drawing.Image]::FromStream($srcStream)
        $pngBuffer = $null
        try {
            $iconBitmap = New-Object System.Drawing.Bitmap 256, 256
            $g = [System.Drawing.Graphics]::FromImage($iconBitmap)
            try {
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.Clear([System.Drawing.Color]::Transparent)

                $scale = [Math]::Min(256.0 / $sourceImage.Width, 256.0 / $sourceImage.Height)
                $drawWidth = [int][Math]::Max(1, [Math]::Round($sourceImage.Width * $scale))
                $drawHeight = [int][Math]::Max(1, [Math]::Round($sourceImage.Height * $scale))
                $offsetX = [int][Math]::Round((256 - $drawWidth) / 2.0)
                $offsetY = [int][Math]::Round((256 - $drawHeight) / 2.0)
                $g.DrawImage($sourceImage, $offsetX, $offsetY, $drawWidth, $drawHeight)

                $pngStream = New-Object System.IO.MemoryStream
                $iconBitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
                $pngBuffer = $pngStream.ToArray()
            }
            finally {
                $g.Dispose()
                $iconBitmap.Dispose()
                $pngStream.Dispose()
            }

            if (-not $pngBuffer -or $pngBuffer.Length -lt 8) {
                return $false
            }

            $iconStream = New-Object System.IO.MemoryStream
            $writer = New-Object System.IO.BinaryWriter($iconStream)
            try {
                # 0-1: reserved, 2-3: type (1=icon), 4-5: image count
                $writer.Write([UInt16]0)
                $writer.Write([UInt16]1)
                $writer.Write([UInt16]1)

                # icon dir entry
                $writer.Write([byte]0)                   # width 0 = 256
                $writer.Write([byte]0)                   # height 0 = 256
                $writer.Write([byte]0)                   # color count
                $writer.Write([byte]0)                   # reserved
                $writer.Write([UInt16]1)                 # planes
                $writer.Write([UInt16]32)                # bit count
                $writer.Write([UInt32]$pngBuffer.Length) # image bytes
                $writer.Write([UInt32]22)                # image offset

                $writer.Write($pngBuffer, 0, $pngBuffer.Length)
                [System.IO.File]::WriteAllBytes($Path, $iconStream.ToArray())

                return $true
            }
            finally {
                $writer.Dispose()
                $iconStream.Dispose()
            }
        }
        finally {
            $sourceImage.Dispose()
            $srcStream.Dispose()
        }
    }
    catch {
        return $false
    }
}

function New-FileIcon {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet("doc", "sheet")][string]$Kind
    )

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $bmp = New-Object System.Drawing.Bitmap 256, 256
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)

            $pageX = 52
            $pageY = 20
            $pageW = 152
            $pageH = 208
            $fold = 38

            $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(36, 0, 0, 0))
            $pageBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255))
            $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(214, 220, 229)), 3
            $foldBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(238, 242, 247))
            $foldPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(205, 212, 224)), 3

            $g.FillRectangle($shadowBrush, $pageX + 8, $pageY + 10, $pageW, $pageH)
            $g.FillRectangle($pageBrush, $pageX, $pageY, $pageW, $pageH)
            $g.DrawRectangle($borderPen, $pageX, $pageY, $pageW, $pageH)

            $foldPoints = @(
                (New-Object System.Drawing.Point ($pageX + $pageW - $fold), $pageY),
                (New-Object System.Drawing.Point ($pageX + $pageW), ($pageY + $fold)),
                (New-Object System.Drawing.Point ($pageX + $pageW), $pageY)
            )
            $g.FillPolygon($foldBrush, $foldPoints)
            $g.DrawLine($foldPen, $pageX + $pageW - $fold, $pageY, $pageX + $pageW - $fold, $pageY + $fold)
            $g.DrawLine($foldPen, $pageX + $pageW - $fold, $pageY + $fold, $pageX + $pageW, $pageY + $fold)

            if ($Kind -eq "sheet") {
                $accent = [System.Drawing.Color]::FromArgb(15, 157, 88)
                $soft = [System.Drawing.Color]::FromArgb(229, 246, 236)
                $line = [System.Drawing.Color]::FromArgb(181, 225, 199)
                $headerBrush = New-Object System.Drawing.SolidBrush $accent
                $softBrush = New-Object System.Drawing.SolidBrush $soft
                $linePen = New-Object System.Drawing.Pen $line, 3

                $g.FillRectangle($headerBrush, $pageX + 24, $pageY + 26, 88, 18)
                $g.FillRectangle($softBrush, $pageX + 24, $pageY + 70, 28, 108)

                foreach ($x in 0..3) {
                    $xPos = $pageX + 24 + ($x * 28)
                    $g.DrawLine($linePen, $xPos, $pageY + 70, $xPos, $pageY + 178)
                }
                foreach ($y in 0..4) {
                    $yPos = $pageY + 70 + ($y * 27)
                    $g.DrawLine($linePen, $pageX + 24, $yPos, $pageX + 124, $yPos)
                }
            }
            else {
                $accent = [System.Drawing.Color]::FromArgb(66, 133, 244)
                $soft = [System.Drawing.Color]::FromArgb(226, 237, 253)
                $headerBrush = New-Object System.Drawing.SolidBrush $accent
                $lineBrush = New-Object System.Drawing.SolidBrush $soft

                $g.FillRectangle($headerBrush, $pageX + 24, $pageY + 26, 82, 18)
                foreach ($i in 0..5) {
                    $width = if ($i -in 1, 4) { 92 } else { 108 }
                    $g.FillRectangle($lineBrush, $pageX + 24, $pageY + 72 + ($i * 22), $width, 10)
                }
            }

            $dotBrushes = @(
                (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(66, 133, 244))),
                (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(234, 67, 53))),
                (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(251, 188, 5))),
                (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(52, 168, 83)))
            )
            $dotX = $pageX + 22
            foreach ($brush in $dotBrushes) {
                $g.FillEllipse($brush, $dotX, $pageY + 188, 12, 12)
                $dotX += 16
            }

            $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Icon)
            return $true
        }
        finally {
            $g.Dispose()
            $bmp.Dispose()
        }
    }
    catch {
        return $false
    }
}

$Python = Resolve-RealPython

Copy-Item -Force -Path (Join-Path $ProjectDir "open_in_google.py") -Destination (Join-Path $InstallDir "open_in_google.py")
Copy-Item -Force -Path (Join-Path $ProjectDir "uninstall.ps1") -Destination (Join-Path $InstallDir "uninstall.ps1")

$sourceSecret = Join-Path $ProjectDir "client_secret.json"
if (Test-Path $sourceSecret) {
    Copy-Item -Force -Path $sourceSecret -Destination (Join-Path $InstallDir "client_secret.json")
}

$scriptPath = Join-Path $InstallDir "open_in_google.py"
$script = '"' + $scriptPath + '"'
$py = '"' + $Python + '"'
$sheetCommand = ('{0} {1} --kind sheet "%1"' -f $py, $script)
$docCommand = ('{0} {1} --kind doc "%1"' -f $py, $script)
$slideCommand = ('{0} {1} --kind slide "%1"' -f $py, $script)
$sheetIconPath = Join-Path $InstallDir "google_sheets.ico"
$docIconPath = Join-Path $InstallDir "google_docs.ico"
$slideIconPath = Join-Path $InstallDir "google_slides.ico"
if (
    -not (Save-OfficialIcon -Path $sheetIconPath -Url "https://www.gstatic.com/images/branding/product/2x/sheets_2020q4_96dp.png") `
    -and -not (New-FileIcon -Path $sheetIconPath -Kind sheet) `
    -and -not (Test-Path $sheetIconPath)
) {
    $sheetIconPath = ""
}
if (
    -not (Save-OfficialIcon -Path $docIconPath -Url "https://www.gstatic.com/images/branding/product/2x/docs_2020q4_96dp.png") `
    -and -not (New-FileIcon -Path $docIconPath -Kind doc) `
    -and -not (Test-Path $docIconPath)
) {
    $docIconPath = ""
}
if (-not (Save-OfficialIcon -Path $slideIconPath -Url "https://www.gstatic.com/images/branding/product/2x/slides_2020q4_96dp.png")) {
    $slideIconPath = ""
}

$classes = "HKCU:\Software\Classes"
$backups = @{}
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
    foreach ($entry in $extMap.GetEnumerator()) {
        $ext = $entry.Key
        $key = Join-Path $classes $ext
        try {
            $current = (Get-ItemProperty -Path $key -ErrorAction Stop)."(default)"
            $backups[$ext] = $current
        } catch {
            $backups[$ext] = $null
        }
    }
    $backups | ConvertTo-Json -Depth 3 | Set-Content -Path $backupPath -Encoding utf8
}

New-Item -Path "$classes\OpenInGoogleDocFile\shell\open" -ItemType Directory -Force | Out-Null
New-Item -Path "$classes\OpenInGoogleDocFile\shell\open\command" -ItemType Directory -Force | Out-Null
New-Item -Path "$classes\OpenInGoogleSheetFile\shell\open" -ItemType Directory -Force | Out-Null
New-Item -Path "$classes\OpenInGoogleSheetFile\shell\open\command" -ItemType Directory -Force | Out-Null
New-Item -Path "$classes\OpenInGoogleSlideFile\shell\open" -ItemType Directory -Force | Out-Null
New-Item -Path "$classes\OpenInGoogleSlideFile\shell\open\command" -ItemType Directory -Force | Out-Null

New-ItemProperty -Path "$classes\OpenInGoogleDocFile\shell\open" -Name "(default)" -Value "Abrir no Google Docs" -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleSheetFile\shell\open" -Name "(default)" -Value "Abrir no Google Sheets" -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleSlideFile\shell\open" -Name "(default)" -Value "Abrir no Google Slides" -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleDocFile\shell\open\command" -Name "(default)" -Value $docCommand -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleSheetFile\shell\open\command" -Name "(default)" -Value $sheetCommand -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleSlideFile\shell\open\command" -Name "(default)" -Value $slideCommand -PropertyType String -Force | Out-Null

# Also remap known legacy/proprietary ProgIDs that may be bound by UserChoice in Windows 11.
$legacySheetProgIds = @("OpenOffice.Xls", "OpenOffice.Xlsx", "Excel.Sheet.8", "Excel.Sheet.12")
foreach ($legacy in $legacySheetProgIds) {
    New-Item -Path "$classes\$legacy\shell\open\command" -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path "$classes\$legacy\shell\open" -Name "(default)" -Value "Abrir no Google Sheets" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$classes\$legacy\shell\open\command" -Name "(default)" -Value $sheetCommand -PropertyType String -Force | Out-Null
    New-Item -Path "$classes\$legacy\DefaultIcon" -ItemType Directory -Force | Out-Null
    if ($sheetIconPath) {
        New-ItemProperty -Path "$classes\$legacy\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $sheetIconPath) -PropertyType String -Force | Out-Null
    }
}

foreach ($legacy in @("OpenOffice.Doc", "OpenOffice.Docx", "Word.Document.8", "Word.Document.12")) {
    New-Item -Path "$classes\$legacy\shell\open\command" -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path "$classes\$legacy\shell\open" -Name "(default)" -Value "Abrir no Google Docs" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$classes\$legacy\shell\open\command" -Name "(default)" -Value $docCommand -PropertyType String -Force | Out-Null
    New-Item -Path "$classes\$legacy\DefaultIcon" -ItemType Directory -Force | Out-Null
    if ($docIconPath) {
        New-ItemProperty -Path "$classes\$legacy\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $docIconPath) -PropertyType String -Force | Out-Null
    }
}

$legacySlideProgIds = @("PowerPoint.Show", "PowerPoint.Show.8", "PowerPoint.Show.12", "PowerPoint.Application")
foreach ($legacy in $legacySlideProgIds) {
    New-Item -Path "$classes\$legacy\shell\open\command" -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path "$classes\$legacy\shell\open" -Name "(default)" -Value "Abrir no Google Slides" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path "$classes\$legacy\shell\open\command" -Name "(default)" -Value $slideCommand -PropertyType String -Force | Out-Null
    New-Item -Path "$classes\$legacy\DefaultIcon" -ItemType Directory -Force | Out-Null
    if ($slideIconPath) {
        New-ItemProperty -Path "$classes\$legacy\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $slideIconPath) -PropertyType String -Force | Out-Null
    }
}

if ($docIconPath) {
    New-Item -Path "$classes\OpenInGoogleDocFile\DefaultIcon" -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path "$classes\OpenInGoogleDocFile\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $docIconPath) -PropertyType String -Force | Out-Null
}
if ($sheetIconPath) {
    New-Item -Path "$classes\OpenInGoogleSheetFile\DefaultIcon" -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path "$classes\OpenInGoogleSheetFile\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $sheetIconPath) -PropertyType String -Force | Out-Null
}
if ($slideIconPath) {
    New-Item -Path "$classes\OpenInGoogleSlideFile\DefaultIcon" -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path "$classes\OpenInGoogleSlideFile\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $slideIconPath) -PropertyType String -Force | Out-Null
}

foreach ($entry in @(".xls",".xlsx",".csv",".ods")) {
    New-Item -Path "$classes\$entry\DefaultIcon" -ItemType Directory -Force | Out-Null
    if ($sheetIconPath) {
        New-ItemProperty -Path "$classes\$entry\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $sheetIconPath) -PropertyType String -Force | Out-Null
    }
}

foreach ($entry in @(".doc",".docx",".rtf",".odt")) {
    New-Item -Path "$classes\$entry\DefaultIcon" -ItemType Directory -Force | Out-Null
    if ($docIconPath) {
        New-ItemProperty -Path "$classes\$entry\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $docIconPath) -PropertyType String -Force | Out-Null
    }
}

foreach ($entry in @(".ppt",".pptx")) {
    New-Item -Path "$classes\$entry\DefaultIcon" -ItemType Directory -Force | Out-Null
    if ($slideIconPath) {
        New-ItemProperty -Path "$classes\$entry\DefaultIcon" -Name "(default)" -Value ('"{0}",0' -f $slideIconPath) -PropertyType String -Force | Out-Null
    }
}


foreach ($entry in $extMap.GetEnumerator()) {
    $ext = $entry.Key
    $progId = $entry.Value
    New-Item -Path "$classes\$ext" -ItemType Directory -Force | Out-Null
    Set-ItemProperty -Path "$classes\$ext" -Name "(default)" -Value $progId
}

New-ItemProperty -Path "$classes\OpenInGoogleDocFile" -Name "FriendlyAppName" -Value $AppDisplayName -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleSheetFile" -Name "FriendlyAppName" -Value $AppDisplayName -PropertyType String -Force | Out-Null
New-ItemProperty -Path "$classes\OpenInGoogleSlideFile" -Name "FriendlyAppName" -Value $AppDisplayName -PropertyType String -Force | Out-Null

$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppRegistryName"
New-Item -Path $uninstallKey -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value $AppDisplayName -PropertyType String -Force | Out-Null
if ($slideIconPath) {
    New-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value ('"{0}",0' -f $slideIconPath) -PropertyType String -Force | Out-Null
}
elseif ($docIconPath) {
    New-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value ('"{0}",0' -f $docIconPath) -PropertyType String -Force | Out-Null
}
elseif ($sheetIconPath) {
    New-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value ('"{0}",0' -f $sheetIconPath) -PropertyType String -Force | Out-Null
}
New-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.0.0" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "Google" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $InstallDir -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value ('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $InstallDir "uninstall.ps1")) -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "QuietUninstallString" -Value ('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f (Join-Path $InstallDir "uninstall.ps1")) -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1 -PropertyType DWord -Force | Out-Null

Write-Host "Instalado em: $InstallDir"
Write-Host "Python usado: $Python"
Write-Host "Nome do app: $AppDisplayName"
Write-Host "Associacoes:"
foreach ($entry in $extMap.GetEnumerator()) {
    Write-Host "  $($entry.Key) -> $($entry.Value)"
}
