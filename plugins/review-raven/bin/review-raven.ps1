# Ensure the review raven binary for this platform is cached, then run it.
#
# The PowerShell twin of lib/fetch.sh and bin/review-raven together. Windows
# must work without Git for Windows installed, so this path cannot delegate to
# bash and reimplements the download instead.
#
# THIS FILE HAS A TWIN: lib/fetch.sh and bin/review-raven do all of the below
# in POSIX shell. A change here is a change there. What the two must agree on:
#
#   - the cache directory, which on Windows is the user profile's .cache
#   - the asset name, its archive format, the binary's name inside it, and the
#     checksum file's format
#   - the rule that a binary is only run once its digest matches
#   - the lock's name, its location, and when it is considered stale
#
# Changing one alone does not fail any test; it splits users across two caches
# or, worse, leaves one platform verifying nothing.
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

$asset = "review-raven-$triple.zip"
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
            # Windows PowerShell's Expand-Archive refuses a path that does not
            # end in .zip, hence the extension on the scratch file.
            $tmp = Join-Path $cache ".download.$PID.zip"
            $unpacked = Join-Path $cache ".download.$PID"
            [Console]::Error.WriteLine("review-raven: fetching $version for $triple")

            try {
                # Progress rendering makes Invoke-WebRequest and Expand-Archive
                # dramatically slower, and this runs where nobody is watching it.
                $prev = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
            } catch {
                Die "download failed: $url"
            }

            $got = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash.ToLower()
            if ($got -ne $want.ToLower()) {
                Die "checksum mismatch for $asset (expected $want, got $got); refusing to run it"
            }

            # Extraction happens only after the digest matched, so no
            # unverified archive is ever unpacked.
            try {
                Expand-Archive -LiteralPath $tmp -DestinationPath $unpacked -Force
            } catch {
                Die "cannot extract $asset"
            }
            $ProgressPreference = $prev
            $extracted = Join-Path $unpacked 'review-raven.exe'
            if (-not (Test-Path $extracted)) { Die "$asset does not contain review-raven.exe" }

            # The binary appears under its final name only once it is complete
            # and verified, so an interrupted download is never a cache hit.
            Move-Item -Path $extracted -Destination $bin -Force
        } finally {
            # The archive and its extracted contents are scratch space; only the
            # verified binary moved to $bin outlives this block.
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            Remove-Item $unpacked -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item $lock -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}

& $bin @Passthrough
exit $LASTEXITCODE
