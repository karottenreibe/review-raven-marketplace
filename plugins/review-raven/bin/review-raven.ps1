# Ensure the review raven binary for this platform is cached, then run it.
#
# The PowerShell twin of lib/fetch.sh and bin/review-raven together. Windows
# must work without Git for Windows installed, so this path cannot delegate to
# bash and reimplements the download instead.
#
# Keep it in step with lib/fetch.sh: the cache layout, the asset names and the
# checksum rule are a shared contract, and a change to one is a change to both.
[CmdletBinding()]
# Not $Args: that is an automatic variable and cannot be declared a parameter.
param([Parameter(ValueFromRemainingArguments = $true)] [string[]] $Passthrough)

$ErrorActionPreference = 'Stop'
$repo = 'karottenreibe/review-raven-marketplace'
$root = Split-Path -Parent $PSScriptRoot

# Writes straight to stderr rather than through Write-Error, which under
# $ErrorActionPreference = 'Stop' raises a terminating error and never reaches
# the exit below, losing the status the caller reads.
function Die($message) { [Console]::Error.WriteLine("review-raven: $message"); exit 1 }

$versionFile = Join-Path $root 'VERSION.txt'
if (-not (Test-Path $versionFile)) { Die 'VERSION.txt is missing from the plugin; the installation is incomplete' }
$version = (Get-Content $versionFile -Raw).Trim()
if (-not $version) { Die 'VERSION.txt is empty; the installation is incomplete' }

# Only 64-bit x86 is built for Windows. ARM64 machines run x64 code under
# emulation, so the x64 binary is the right answer there too rather than an
# error; PROCESSOR_ARCHITECTURE reports ARM64 on those.
switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { $triple = 'x86_64-pc-windows-msvc' }
    'ARM64' { $triple = 'x86_64-pc-windows-msvc' }
    default { Die "no binary for Windows $($env:PROCESSOR_ARCHITECTURE); supported: x64" }
}

$asset = "review-raven-$triple.exe"
# Deliberately the same location lib/fetch.sh computes, so the two Windows
# launchers share one cache: under Git Bash, $HOME is the user profile, making
# its $HOME/.cache the profile's .cache directory. Whichever launcher runs
# first spares the other a download.
$cacheHome = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $env:USERPROFILE '.cache' }
$cache = Join-Path (Join-Path $cacheHome 'review-raven') $version
$bin = Join-Path $cache 'review-raven.exe'

# The common case: already cached, nothing to do but run it.
if (-not (Test-Path $bin)) {
    $sums = Join-Path $root 'checksums.txt'
    if (-not (Test-Path $sums)) { Die 'checksums.txt is missing from the plugin; the installation is incomplete' }

    # The expected digest ships with the plugin over git rather than being
    # fetched beside the binary, so a tampered download cannot also supply the
    # hash that would clear it.
    $want = $null
    foreach ($line in Get-Content $sums) {
        $parts = $line -split '\s+', 2
        if ($parts.Count -eq 2 -and $parts[1].TrimStart('*').Trim() -eq $asset) { $want = $parts[0].Trim(); break }
    }
    if (-not $want) { Die "checksums.txt has no entry for $asset; this plugin build does not support your platform" }

    New-Item -ItemType Directory -Force -Path $cache | Out-Null

    # A directory is created atomically, which makes it a lock that several
    # sessions starting at once cannot all take. One older than five minutes is
    # assumed abandoned by a killed process rather than held.
    $lock = Join-Path $cache '.lock'
    $held = $false
    try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null; $held = $true } catch {
        $age = (Get-Date) - (Get-Item $lock).LastWriteTime
        if ($age.TotalMinutes -gt 5) {
            Remove-Item $lock -Force -Recurse -ErrorAction SilentlyContinue
            try { New-Item -ItemType Directory -Path $lock -ErrorAction Stop | Out-Null; $held = $true } catch { }
        }
    }

    if (-not $held) {
        # Wait out the holder and use whatever it produced.
        $waited = 0
        while ((Test-Path $lock) -and $waited -lt 120) { Start-Sleep -Seconds 1; $waited++ }
        if (-not (Test-Path $bin)) { Die 'another process is downloading the binary; try again shortly' }
    } else {
        try {
            $url = "https://github.com/$repo/releases/download/v$version/$asset"
            $tmp = Join-Path $cache ".download.$PID"
            [Console]::Error.WriteLine("review-raven: fetching $version for $triple")

            try {
                # Progress rendering makes Invoke-WebRequest dramatically slower
                # on large files, and this runs where nobody is watching it.
                $prev = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
                $ProgressPreference = $prev
            } catch {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                Die "download failed: $url"
            }

            $got = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash.ToLower()
            if ($got -ne $want.ToLower()) {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                Die "checksum mismatch for $asset (expected $want, got $got); refusing to run it"
            }

            # The binary appears under its final name only once it is complete
            # and verified, so an interrupted download is never a cache hit.
            Move-Item -Path $tmp -Destination $bin -Force
        } finally {
            Remove-Item $lock -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

& $bin @Passthrough
exit $LASTEXITCODE
