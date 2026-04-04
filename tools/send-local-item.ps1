[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RawArgs
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$MaxAttachmentBytes = 25MB

function Resolve-InputPath {
    param(
        [string]$InputText
    )

    $trimmed = $InputText.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    try {
        return @(Resolve-Path -LiteralPath $trimmed -ErrorAction Stop | Select-Object -ExpandProperty Path)
    } catch {
    }

    try {
        return @(Resolve-Path -Path $trimmed -ErrorAction Stop | Select-Object -ExpandProperty Path)
    } catch {
        return @()
    }
}

function Get-OutboxDir {
    $outDir = Join-Path $env:USERPROFILE ".cc-connect\outbox"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    return $outDir
}

function Test-ImageFile {
    param(
        [string]$Path
    )

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    return $ext -in @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")
}

function New-ZipFromFolder {
    param(
        [string]$FolderPath
    )

    $outDir = Get-OutboxDir
    $folderName = Split-Path -Path $FolderPath -Leaf
    $safeName = ($folderName -replace '[\\/:*?"<>|]', "_")
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $zipPath = Join-Path $outDir ($safeName + "-" + $stamp + ".zip")

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    $entries = @(Get-ChildItem -LiteralPath $FolderPath -Force -ErrorAction Stop)
    if ($entries.Count -eq 0) {
        throw ("Folder is empty and cannot be packaged: " + $FolderPath)
    }

    Compress-Archive -LiteralPath ($entries | Select-Object -ExpandProperty FullName) -DestinationPath $zipPath -Force
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw ("Zip archive was not created successfully: " + $zipPath)
    }

    return $zipPath
}

function Split-FileForFeishu {
    param(
        [string]$FilePath
    )

    $outDir = Get-OutboxDir
    $baseName = [System.IO.Path]::GetFileName($FilePath)
    $partsDir = Join-Path $outDir (($baseName -replace '[\\/:*?"<>|]', "_") + "-parts")
    New-Item -ItemType Directory -Force -Path $partsDir | Out-Null

    Get-ChildItem -LiteralPath $partsDir -ErrorAction SilentlyContinue | Remove-Item -Force

    $stream = [System.IO.File]::OpenRead($FilePath)
    try {
        $buffer = New-Object byte[] $MaxAttachmentBytes
        $partIndex = 1
        $parts = @()
        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $partName = "{0}.part{1:d3}" -f $baseName, $partIndex
            $partPath = Join-Path $partsDir $partName
            $outStream = [System.IO.File]::Create($partPath)
            try {
                $outStream.Write($buffer, 0, $bytesRead)
            } finally {
                $outStream.Dispose()
            }
            $parts += $partPath
            $partIndex++
        }
    } finally {
        $stream.Dispose()
    }

    $mergeBat = Join-Path $partsDir ("merge-" + ($baseName -replace '[^A-Za-z0-9._-]', "_") + ".bat")
    $mergeLines = @(
        "@echo off",
        "copy /b " + (($parts | ForEach-Object { '"' + [System.IO.Path]::GetFileName($_) + '"' }) -join "+") + ' "' + $baseName + '"',
        "echo Rebuilt " + $baseName,
        "pause"
    )
    Set-Content -LiteralPath $mergeBat -Value $mergeLines -Encoding ASCII

    return @{
        Parts    = $parts
        MergeBat = $mergeBat
        PartsDir = $partsDir
    }
}

function Send-ViaCcConnect {
    param(
        [string]$Message,
        [string[]]$Files = @(),
        [string[]]$Images = @()
    )

    $sendExe = (Get-Command "cc-connect" -ErrorAction Stop).Source
    $args = @("send")
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $args += @("--message", $Message)
    }
    foreach ($file in $Files) {
        $args += @("--file", $file)
    }
    foreach ($image in $Images) {
        $args += @("--image", $image)
    }

    & $sendExe @args
    if ($LASTEXITCODE -ne 0) {
        throw "cc-connect send failed."
    }
}

$inputText = ($RawArgs -join " ").Trim()
$resolvedPaths = @(Resolve-InputPath -InputText $inputText)

if ($resolvedPaths.Count -eq 0) {
    Write-Output "Usage: /sendlocal <file-or-folder-path>"
    Write-Output "Path not found."
    exit 0
}

if ($resolvedPaths.Count -gt 1) {
    Write-Output "Multiple matches found:"
    $resolvedPaths | Select-Object -First 20
    exit 0
}

$targetPath = $resolvedPaths[0]

if (Test-Path -LiteralPath $targetPath -PathType Container) {
    $targetPath = New-ZipFromFolder -FolderPath $targetPath
}

$targetInfo = Get-Item -LiteralPath $targetPath
$targetName = $targetInfo.Name

if ((Test-ImageFile -Path $targetPath) -and $targetInfo.Length -le $MaxAttachmentBytes) {
    Send-ViaCcConnect -Message ("Image sent: " + $targetName) -Images @($targetPath)
    Write-Output ("Image sent: " + $targetPath)
    exit 0
}

if ($targetInfo.Length -le $MaxAttachmentBytes) {
    Send-ViaCcConnect -Message ("File sent: " + $targetName) -Files @($targetPath)
    Write-Output ("File sent: " + $targetPath)
    exit 0
}

$split = Split-FileForFeishu -FilePath $targetPath
$parts = @($split.Parts)
$mergeBat = $split.MergeBat

Send-ViaCcConnect -Message ("File too large for a single Feishu attachment. Sending " + $parts.Count + " parts plus a merge script.") -Files @($mergeBat)
foreach ($part in $parts) {
    Send-ViaCcConnect -Files @($part)
}

Write-Output ("Large file split and sent in " + $parts.Count + " parts: " + $targetPath)
Write-Output ("Merge helper: " + $mergeBat)
