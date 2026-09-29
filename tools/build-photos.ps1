<#
  Rebuilds js/photos.js from whatever is sitting in the photos/ folder, and
  makes the smaller copies of every photo that the site actually serves.

  Run this after adding or changing a game folder. Your originals and
  js/albums.js are never touched. It writes:

    photos/<game>/thumb/   ~800px on the short edge, for grids and covers
    photos/<game>/web/     ~2048px on the long edge, for the full-size viewer
    images/web/            ~2048px copies of the home/about page images
    js/photos.js           the frame list

  Copies that are already newer than their original are skipped, so reruns
  are quick. The originals are left out of the published site by
  .github/workflows/pages.yml.
#>

$ErrorActionPreference = 'Stop'

$root      = Split-Path -Parent $PSScriptRoot
$photosDir = Join-Path $root 'photos'
$imagesDir = Join-Path $root 'images'
$albumsJs  = Join-Path $root 'js\albums.js'
$outFile   = Join-Path $root 'js\photos.js'

if (-not (Test-Path $photosDir)) {
  throw "No photos folder found at $photosDir"
}

$extensions = @('.jpg', '.jpeg', '.png', '.webp')

function ConvertTo-JsString([string]$value) {
  '"' + ($value -replace '\\', '\\' -replace '"', '\"') + '"'
}

Add-Type -AssemblyName System.Drawing

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' }

# Writes a resized JPEG copy of $source to $dest, unless $dest is already newer.
# Short edge mode fits the smaller side to $size (so cropped grid tiles stay
# sharp); long edge mode fits the larger side. Never upscales.
# Returns $true when a copy was written.
function Save-Resized([IO.FileInfo]$source, [string]$dest, [int]$size, [switch]$ShortEdge, [int]$quality) {
  if ((Test-Path $dest) -and (Get-Item $dest).LastWriteTime -ge $source.LastWriteTime) {
    return $false
  }

  $image = [System.Drawing.Image]::FromFile($source.FullName)
  try {
    # Honour the camera's rotation flag, since the copy won't carry it over.
    if ($image.PropertyIdList -contains 0x0112) {
      $flip = switch ($image.GetPropertyItem(0x0112).Value[0]) {
        3 { 'Rotate180FlipNone' }
        6 { 'Rotate90FlipNone' }
        8 { 'Rotate270FlipNone' }
        default { $null }
      }
      if ($flip) { $image.RotateFlip($flip) }
    }

    $edge  = if ($ShortEdge) { [Math]::Min($image.Width, $image.Height) } else { [Math]::Max($image.Width, $image.Height) }
    $scale = [Math]::Min(1.0, $size / $edge)
    $w = [int][Math]::Round($image.Width * $scale)
    $h = [int][Math]::Round($image.Height * $scale)

    $bitmap = New-Object System.Drawing.Bitmap $w, $h
    try {
      $g = [System.Drawing.Graphics]::FromImage($bitmap)
      $g.InterpolationMode  = 'HighQualityBicubic'
      $g.SmoothingMode      = 'HighQuality'
      $g.PixelOffsetMode    = 'HighQuality'
      $g.CompositingQuality = 'HighQuality'
      $g.DrawImage($image, 0, 0, $w, $h)
      $g.Dispose()

      $params = New-Object System.Drawing.Imaging.EncoderParameters 1
      $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$quality)

      New-Item -ItemType Directory -Force (Split-Path -Parent $dest) | Out-Null
      $bitmap.Save($dest, $jpegCodec, $params)
    }
    finally { $bitmap.Dispose() }
  }
  finally { $image.Dispose() }

  # A file that was already small can come out bigger after re-encoding.
  # Serve the original in that case.
  if ((Get-Item $dest).Length -gt $source.Length) {
    Copy-Item $source.FullName $dest -Force
    (Get-Item $dest).LastWriteTime = Get-Date
  }

  return $true
}

Write-Host ""
Write-Host "Making web-sized copies (the first run takes a few minutes) ..."

$made = 0
foreach ($folder in Get-ChildItem -Path $photosDir -Directory | Sort-Object Name) {
  $files = Get-ChildItem -Path $folder.FullName -File |
    Where-Object { $extensions -contains $_.Extension.ToLower() }

  foreach ($file in $files) {
    $thumb = Join-Path $folder.FullName ('thumb\' + $file.Name)
    $web   = Join-Path $folder.FullName ('web\' + $file.Name)
    if (Save-Resized $file $thumb 800 -ShortEdge -quality 78) { $made++ }
    if (Save-Resized $file $web 2048 -quality 82) { $made++ }
  }
}

if (Test-Path $imagesDir) {
  Get-ChildItem -Path $imagesDir -File |
    Where-Object { @('.jpg', '.jpeg') -contains $_.Extension.ToLower() } |
    ForEach-Object {
      if (Save-Resized $_ (Join-Path $imagesDir ('web\' + $_.Name)) 2048 -quality 82) { $made++ }
    }
}

Write-Host ("  {0} new copies written." -f $made)

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
