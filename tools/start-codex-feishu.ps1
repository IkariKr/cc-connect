$ErrorActionPreference = "Stop"

$ccConnectExe = "D:\App\01_Ai\CodeX\cc-connect\cc-connect.exe"
$ccWorkDir = "D:\App\01_Ai\CodeX"
$ccLogDir = Join-Path $env:USERPROFILE ".cc-connect\logs"
$ccStdOutFile = Join-Path $ccLogDir "cc-connect-autostart.out.log"
$ccStdErrFile = Join-Path $ccLogDir "cc-connect-autostart.err.log"

$cliProxyExe = "D:\App\01_Ai\CLIProxyAPI_6.9.7_windows_amd64\cli-proxy-api.exe"

function Get-MatchingProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path
    )

    Get-CimInstance Win32_Process -Filter "Name = '$Name'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -eq $Path } |
        Select-Object -First 1
}

function Resolve-CodexCliDirectory {
    $candidates = New-Object System.Collections.Generic.List[string]

    try {
        $pkg = Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $appCodex = Join-Path $pkg.InstallLocation "app\resources\codex.exe"
            if (Test-Path -LiteralPath $appCodex) {
                $candidates.Add((Split-Path -Parent $appCodex))
            }
        }
    } catch {
    }

    $vscodeCodex = Get-ChildItem "C:\Users\41382\.vscode\extensions\openai.chatgpt-*\bin\windows-x86_64\codex.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($vscodeCodex) {
        $candidates.Add((Split-Path -Parent $vscodeCodex.FullName))
    }

    foreach ($dir in $candidates) {
        if ([string]::IsNullOrWhiteSpace($dir)) {
            continue
        }
        $exe = Join-Path $dir "codex.exe"
        if (Test-Path -LiteralPath $exe) {
            return $dir
        }
    }

    return $null
}

New-Item -ItemType Directory -Force -Path $ccLogDir | Out-Null

$codexCliDir = Resolve-CodexCliDirectory
if (-not $codexCliDir) {
    throw "codex CLI not found in stable locations"
}

$pathEntries = @($codexCliDir) + (($env:PATH -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$env:PATH = ($pathEntries | Select-Object -Unique) -join ';'

if (-not (Test-Path -LiteralPath $cliProxyExe)) {
    throw "cli-proxy-api not found: $cliProxyExe"
}

if (-not (Get-MatchingProcess -Name "cli-proxy-api.exe" -Path $cliProxyExe)) {
    Start-Process -FilePath $cliProxyExe -WorkingDirectory (Split-Path -Parent $cliProxyExe) -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 2
}

if (-not (Test-Path -LiteralPath $ccConnectExe)) {
    throw "cc-connect not found: $ccConnectExe"
}

if (-not (Get-MatchingProcess -Name "cc-connect.exe" -Path $ccConnectExe)) {
    Start-Process `
        -FilePath $ccConnectExe `
        -WorkingDirectory $ccWorkDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $ccStdOutFile `
        -RedirectStandardError $ccStdErrFile | Out-Null
}
