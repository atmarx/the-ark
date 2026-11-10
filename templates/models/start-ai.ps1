# start-ai.ps1 - run a language model from this drive with llama.cpp
# Usage: start-ai.bat [model-id | --list]
# Env:   ARK_AI_PORT (default 8081), ARK_AI_CPU=1 (skip the GPU build),
#        ARK_AI_CTX (context length, default 16384)

param([string]$Choice = "")

$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = if ($env:ARK_AI_PORT) { $env:ARK_AI_PORT } else { "8081" }
$Ctx = if ($env:ARK_AI_CTX) { $env:ARK_AI_CTX } else { "16384" }
$Release = (Get-Content (Join-Path $Here "llama.cpp\RELEASE") -TotalCount 1).Trim()

$Models = Get-Content (Join-Path $Here "models.tsv") | Where-Object { $_ } | ForEach-Object {
    $f = $_ -split "`t"
    [pscustomobject]@{ Id = $f[0]; Ram = [int]$f[1]; Auto = $f[2]; Model = $f[3]; Mmproj = $f[4]; Name = $f[5] }
}

function Show-Models {
    "{0,-18} {1,6}  {2}" -f "ID", "MEMORY", "MODEL"
    foreach ($m in $Models) {
        $extra = ""
        if ($m.Mmproj -ne "-") { $extra += ", reads images" }
        if ($m.Auto -eq "no") { $extra += ", pick by name" }
        "{0,-18} {1,3} GB  {2}{3}" -f $m.Id, $m.Ram, $m.Name, $extra
    }
}

if ($Choice -eq "--list" -or $Choice -eq "-l") { Show-Models; exit 0 }

# -- What are we running on? ------------------------------------
$Ram = [int][math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1e9)
$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
$Platform = "windows-$Arch"
if ($Arch -eq "x64" -and -not $env:ARK_AI_CPU -and (Test-Path "$env:SystemRoot\System32\vulkan-1.dll")) {
    # The Vulkan build uses most graphics cards
    $Platform = "windows-x64-vulkan"
}

$Archive = $null
foreach ($line in Get-Content (Join-Path $Here "llama.cpp\platforms.tsv")) {
    $f = $line -split "`t"
    if ($f[0] -eq $Platform) { $Archive = $f[1] }
}
if (-not $Archive -or -not (Test-Path (Join-Path $Here "llama.cpp\$Archive"))) {
    Write-Host "Sorry, I don't have llama.cpp for $Platform."
    exit 1
}

# -- Pick a model -----------------------------------------------
if ($Choice) {
    $Pick = $Models | Where-Object { $_.Id -eq $Choice } | Select-Object -First 1
    if (-not $Pick) {
        Write-Host "I don't have a model called '$Choice'.  Here's what I have:"
        Write-Host ""
        Show-Models
        exit 1
    }
} else {
    # Largest automatic model that fits in memory; the smallest if none do
    $Pick = $Models | Where-Object { $_.Auto -eq "yes" -and $_.Ram -le $Ram } | Select-Object -Last 1
    if (-not $Pick) {
        $Pick = $Models | Select-Object -First 1
        Write-Host "This computer has about $Ram GB of memory, which is tight.  I'll try the smallest model."
    }
}

if ($Pick.Ram -gt $Ram) {
    Write-Host "Warning: $($Pick.Name) wants about $($Pick.Ram) GB of memory and this computer has about $Ram GB."
    Write-Host "It may be very slow, or fail to start."
    Write-Host ""
}

# -- Unpack llama.cpp to this computer (once) -------------------
$Cache = Join-Path $env:LOCALAPPDATA "the-ark\llama.cpp-$Release-$Platform"
$Server = Get-ChildItem $Cache -Recurse -Filter "llama-server.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $Server) {
    Write-Host "Unpacking llama.cpp to $Cache ..."
    New-Item -ItemType Directory -Force -Path $Cache | Out-Null
    Expand-Archive -Path (Join-Path $Here "llama.cpp\$Archive") -DestinationPath $Cache -Force
    $Server = Get-ChildItem $Cache -Recurse -Filter "llama-server.exe" | Select-Object -First 1
    if (-not $Server) { Write-Host "Couldn't find llama-server.exe in $Archive."; exit 1 }
}

# -- Start it ---------------------------------------------------
Write-Host "Starting $($Pick.Name) ($($Pick.Id)) on $Platform, with about $Ram GB of memory."
Write-Host ""
Write-Host "When it says `"listening on`", open this in a web browser:"
Write-Host ""
Write-Host "    http://127.0.0.1:$Port"
Write-Host ""
Write-Host "Close this window to stop."
Write-Host ""

$ServerArgs = @("-m", (Join-Path $Here ($Pick.Model -replace "/", "\")),
                "--host", "127.0.0.1", "--port", $Port, "-c", $Ctx)
if ($Pick.Mmproj -ne "-") {
    $ServerArgs += @("--mmproj", (Join-Path $Here ($Pick.Mmproj -replace "/", "\")))
}

& $Server.FullName @ServerArgs
