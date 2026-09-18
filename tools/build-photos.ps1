<#
  Rebuilds js/photos.js from whatever is sitting in the photos/ folder.

  Run this after adding or changing a game folder. It only ever writes
  js/photos.js — your photos and js/albums.js are never touched.
#>

$ErrorActionPreference = 'Stop'

$root      = Split-Path -Parent $PSScriptRoot
$photosDir = Join-Path $root 'photos'
$albumsJs  = Join-Path $root 'js\albums.js'
$outFile   = Join-Path $root 'js\photos.js'

if (-not (Test-Path $photosDir)) {
  throw "No photos folder found at $photosDir"
}

$extensions = @('.jpg', '.jpeg', '.png', '.webp')

function ConvertTo-JsString([string]$value) {
  '"' + ($value -replace '\\', '\\' -replace '"', '\"') + '"'
}

Write-Host ""
Write-Host "Reading photos/ ..."

$folders = Get-ChildItem -Path $photosDir -Directory | Sort-Object Name
$entries = @()
$total = 0

foreach ($folder in $folders) {
  $files = Get-ChildItem -Path $folder.FullName -File |
    Where-Object { $extensions -contains $_.Extension.ToLower() } |
    Sort-Object Name

  $total += $files.Count
  Write-Host ("  {0,-44} {1,4} frames" -f $folder.Name, $files.Count)

  $key = ConvertTo-JsString ("photos/" + $folder.Name)

  if ($files.Count -eq 0) {
    $entries += "  ${key}: []"
  }
  else {
    $names = $files | ForEach-Object { "    " + (ConvertTo-JsString $_.Name) }
    $entries += "  ${key}: [`r`n" + ($names -join ",`r`n") + "`r`n  ]"
  }
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

$out = @()
$out += "/* GENERATED FILE - do not edit by hand."
$out += "   Rebuilt from the photos/ folder by tools/build-photos.ps1, or by"
$out += "   double-clicking build-photos.bat in the site folder."
$out += "   Last run: $stamp"
$out += ""
$out += '   Each key below matches an album''s `dir` in js/albums.js. */'
$out += ""
$out += "window.ALBUM_PHOTOS = {"
$out += ""
$out += ($entries -join ",`r`n`r`n")
$out += ""
$out += "};"

Set-Content -Path $outFile -Value ($out -join "`r`n") -Encoding UTF8

Write-Host ""
Write-Host ("Wrote js/photos.js - {0} folders, {1} frames total." -f $folders.Count, $total)

# Cross-check against albums.js so mismatches surface here rather than as an
# empty page later. This only reads albums.js; it never rewrites it.
if (Test-Path $albumsJs) {
  $source = Get-Content $albumsJs -Raw
  $declared = [regex]::Matches($source, 'dir:\s*"([^"]*)"') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -ne '' }

  $found = $folders | ForEach-Object { "photos/" + $_.Name }

  $missingEntry = $found | Where-Object { $declared -notcontains $_ }
  $missingFolder = $declared | Where-Object { $found -notcontains $_ }

  if ($missingEntry) {
    Write-Host ""
    Write-Host "These folders have no entry in js/albums.js, so they won't appear:" -ForegroundColor Yellow
    $missingEntry | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  }

  if ($missingFolder) {
    Write-Host ""
    Write-Host "These albums point at a folder that isn't there:" -ForegroundColor Yellow
    $missingFolder | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
  }

  if (-not $missingEntry -and -not $missingFolder) {
    Write-Host "Every folder matches an album entry."
  }
}

Write-Host ""
