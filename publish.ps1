<#
    publish.ps1 - update the live Pioneer School site.

    Copies the study-note files from "Theo Library\Pioneer School" into this
    folder under their published (clean, lowercase-hyphenated) names, then
    commits and pushes to GitHub. GitHub Pages redeploys in about a minute.

    Usage:
        .\publish.ps1
        .\publish.ps1 -Message "Fix citation on Unit 7b"
        .\publish.ps1 -WhatIf          # show what would change, push nothing

    Live site: https://theoscholar.github.io/pioneer-school/
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $Message = "Update study notes"
)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'Pioneer School'
$mapFile = Join-Path $PSScriptRoot 'name-map.tsv'

if (-not (Test-Path -LiteralPath $source))  { throw "Source folder not found: $source" }
if (-not (Test-Path -LiteralPath $mapFile)) { throw "Name map not found: $mapFile" }

# ---- 0. Clear stale Git lock files ------------------------------------------
# Git leaves *.lock behind if a process is interrupted or lacks permission to
# clean up. If no git process is actually running, they are safe to remove.
if (-not (Get-Process -Name git -ErrorAction SilentlyContinue)) {
    $locks = @(
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '.git') -Filter '*.lock' -Recurse -Force -ErrorAction SilentlyContinue
    )
    if ($locks.Count -gt 0) {
        Write-Host "Clearing $($locks.Count) stale Git lock file(s)." -ForegroundColor DarkGray
        $locks | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $tmpObjects = @(
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '.git\objects') -Filter 'tmp_obj_*' -Recurse -Force -ErrorAction SilentlyContinue
    )
    if ($tmpObjects.Count -gt 0) {
        Write-Host "Clearing $($tmpObjects.Count) orphaned temp object(s)." -ForegroundColor DarkGray
        $tmpObjects | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# ---- 1. Load the original -> published filename map -------------------------
$map = @{}
foreach ($line in (Get-Content -LiteralPath $mapFile -Encoding UTF8)) {
    if ($line -match '^\s*(#|$)') { continue }
    $parts = $line -split "`t"
    if ($parts.Count -ne 2) { throw "Malformed line in name-map.tsv: $line" }
    $map[$parts[0].Trim()] = $parts[1].Trim()
}
Write-Host "Loaded $($map.Count) filename mappings." -ForegroundColor DarkGray

# ---- 2. Warn about originals that have no mapping ---------------------------
# The "0 ... START HERE ..." local index is deliberately not published;
# the site has its own index.html. Match on the leading "0 " to stay ASCII-safe.
$originals = Get-ChildItem -LiteralPath $source -Filter *.html
$missing = $originals |
    Where-Object { -not $map.ContainsKey($_.Name) } |
    Where-Object { $_.Name -notlike '0 *START HERE*' }

if ($missing) {
    Write-Host ""
    Write-Warning "These files in 'Pioneer School' have no entry in name-map.tsv and will NOT be published:"
    $missing | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor Yellow }
    Write-Host "  Add a line to name-map.tsv (original<TAB>published-name.html) to include them," -ForegroundColor Yellow
    Write-Host "  and remember to add a link on index.html too." -ForegroundColor Yellow
    Write-Host ""
}

# ---- 3. Copy changed files into the working copy ----------------------------
$copied = 0
foreach ($entry in $map.GetEnumerator()) {
    $from = Join-Path $source $entry.Key
    $to   = Join-Path $PSScriptRoot $entry.Value

    if (-not (Test-Path -LiteralPath $from)) {
        Write-Warning "Missing original, skipped: $($entry.Key)"
        continue
    }

    $same = (Test-Path -LiteralPath $to) -and
            ((Get-FileHash -LiteralPath $from).Hash -eq (Get-FileHash -LiteralPath $to).Hash)

    if (-not $same) {
        Copy-Item -LiteralPath $from -Destination $to -Force
        Write-Host "  updated  $($entry.Value)" -ForegroundColor Cyan
        $copied++
    }
}
Write-Host "$copied file(s) refreshed from the originals." -ForegroundColor DarkGray

# ---- 4. Commit and push -----------------------------------------------------
$dirty = git status --porcelain
if (-not $dirty) {
    Write-Host "`nNothing to publish - the live site already matches your files." -ForegroundColor Green
    exit 0
}

Write-Host "`nPending changes:" -ForegroundColor White
git status --short

if ($WhatIfPreference) {
    Write-Host "`n-WhatIf specified. Nothing was committed or pushed." -ForegroundColor Yellow
    exit 0
}

git add -A
git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw "git commit failed." }

git push origin main
if ($LASTEXITCODE -ne 0) { throw "git push failed. If this is an auth error, see README-publishing.md." }

Write-Host "`nPushed. GitHub Pages usually redeploys within a minute:" -ForegroundColor Green
Write-Host "  https://theoscholar.github.io/pioneer-school/" -ForegroundColor Green
