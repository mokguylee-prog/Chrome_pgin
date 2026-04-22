param(
  [string]$ProjectRoot = (Join-Path $PSScriptRoot "Sm_Chrome_Extension"),
  [string]$OutputDir = "",
  [string]$Version = "",
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Write-Ok {
  param([string]$Message)
  Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
  param([string]$Message)
  Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Add-UniqueString {
  param(
    [System.Collections.Generic.List[string]]$List,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return
  }

  $normalized = $Value.Replace("/", "\")
  if (-not $List.Contains($normalized)) {
    $List.Add($normalized) | Out-Null
  }
}

function Get-RelativePath {
  param(
    [string]$BasePath,
    [string]$FullPath
  )

  $base = $BasePath.TrimEnd("\", "/")
  return $FullPath.Substring($base.Length).TrimStart("\", "/")
}

function Get-OptionalProperty {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$manifestPath = Join-Path $resolvedProjectRoot "manifest.json"

if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "manifest.json not found: $manifestPath"
}

Write-Step "1/6 Parse Manifest"
$manifestRaw = Get-Content -LiteralPath $manifestPath -Raw
$manifest = $manifestRaw | ConvertFrom-Json

if ($manifest.manifest_version -ne 3) {
  throw "Only Manifest V3 is supported by this deploy script."
}

if ([string]::IsNullOrWhiteSpace($manifest.name)) {
  throw "manifest name is missing."
}

if ([string]::IsNullOrWhiteSpace($manifest.version)) {
  throw "manifest version is missing."
}

if (-not [string]::IsNullOrWhiteSpace($Version)) {
  if ($Version -notmatch '^\d+(\.\d+){2,3}$') {
    throw "Invalid version format: $Version (expected: x.y.z or x.y.z.w)"
  }

  $updatedRaw = [regex]::Replace(
    $manifestRaw,
    '("version"\s*:\s*")([^"]+)(")',
    "`$1$Version`$3",
    1
  )

  if ($updatedRaw -eq $manifestRaw) {
    throw "Failed to update version in manifest.json"
  }

  Set-Content -LiteralPath $manifestPath -Value $updatedRaw -Encoding UTF8
  $manifestRaw = $updatedRaw
  $manifest = $manifestRaw | ConvertFrom-Json
  Write-Ok "manifest version updated to $Version"
}

Write-Ok "Name: $($manifest.name)"
Write-Ok "Version: $($manifest.version)"

Write-Step "2/6 Validate Referenced Files"
$referencedPaths = New-Object System.Collections.Generic.List[string]
$background = Get-OptionalProperty -Object $manifest -Name "background"
$action = Get-OptionalProperty -Object $manifest -Name "action"
$icons = Get-OptionalProperty -Object $manifest -Name "icons"
$contentScripts = Get-OptionalProperty -Object $manifest -Name "content_scripts"
$webAccessibleResources = Get-OptionalProperty -Object $manifest -Name "web_accessible_resources"

Add-UniqueString -List $referencedPaths -Value (Get-OptionalProperty -Object $background -Name "service_worker")
Add-UniqueString -List $referencedPaths -Value (Get-OptionalProperty -Object $action -Name "default_popup")
Add-UniqueString -List $referencedPaths -Value (Get-OptionalProperty -Object $manifest -Name "options_page")
Add-UniqueString -List $referencedPaths -Value (Get-OptionalProperty -Object $manifest -Name "devtools_page")

if ($icons) {
  foreach ($prop in $icons.PSObject.Properties) {
    Add-UniqueString -List $referencedPaths -Value ([string]$prop.Value)
  }
}

if ($contentScripts) {
  foreach ($entry in $contentScripts) {
    $jsFiles = Get-OptionalProperty -Object $entry -Name "js"
    $cssFiles = Get-OptionalProperty -Object $entry -Name "css"

    foreach ($js in @($jsFiles)) {
      Add-UniqueString -List $referencedPaths -Value $js
    }
    foreach ($css in @($cssFiles)) {
      Add-UniqueString -List $referencedPaths -Value $css
    }
  }
}

if ($webAccessibleResources) {
  foreach ($entry in $webAccessibleResources) {
    $resources = Get-OptionalProperty -Object $entry -Name "resources"
    foreach ($resource in @($resources)) {
      Add-UniqueString -List $referencedPaths -Value $resource
    }
  }
}

$missing = New-Object System.Collections.Generic.List[string]

foreach ($path in $referencedPaths) {
  if ($path -match '[\*\?]') {
    $wildcardPath = Join-Path $resolvedProjectRoot $path
    $matches = @(Get-ChildItem -Path $wildcardPath -File -Recurse -ErrorAction SilentlyContinue)
    if ($matches.Count -eq 0) {
      $missing.Add($path) | Out-Null
      Write-Warn "Wildcard has no matches: $path"
    } else {
      Write-Ok "Wildcard matched: $path ($($matches.Count) file(s))"
    }
    continue
  }

  $full = Join-Path $resolvedProjectRoot $path
  if (Test-Path -LiteralPath $full) {
    Write-Ok "Found: $path"
  } else {
    $missing.Add($path) | Out-Null
    Write-Warn "Missing: $path"
  }
}

if ($missing.Count -gt 0) {
  throw "Referenced files are missing. Fix manifest references before packaging."
}

Write-Step "3/6 Collect Files For Packaging"
$excludeDirs = @(
  ".git",
  ".github",
  ".vscode",
  ".idea",
  ".chrome-test-profile",
  "node_modules",
  "release",
  "dist"
)

$excludeExtensions = @(".ps1", ".md", ".map")
$excludeFileNames = @("Thumbs.db", ".DS_Store")

$allFiles = Get-ChildItem -LiteralPath $resolvedProjectRoot -Recurse -File
$packageFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($file in $allFiles) {
  $relative = Get-RelativePath -BasePath $resolvedProjectRoot -FullPath $file.FullName
  if ([string]::IsNullOrWhiteSpace($relative)) {
    continue
  }

  $segments = $relative -split '[\\/]'
  $skip = $false
  foreach ($segment in $segments) {
    if ($excludeDirs -contains $segment) {
      $skip = $true
      break
    }
  }
  if ($skip) {
    continue
  }

  if ($excludeFileNames -contains $file.Name) {
    continue
  }

  if ($excludeExtensions -contains $file.Extension.ToLowerInvariant()) {
    continue
  }

  $packageFiles.Add($file) | Out-Null
}

if ($packageFiles.Count -eq 0) {
  throw "No files collected for packaging."
}

if (-not ($packageFiles | Where-Object { $_.Name -eq "manifest.json" })) {
  throw "manifest.json is not included in package file set."
}

Write-Ok "Files to package: $($packageFiles.Count)"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $OutputDir = Join-Path $resolvedProjectRoot "release"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$safeName = ($manifest.name -replace '[^A-Za-z0-9._-]', '_')
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zipName = "$safeName-v$($manifest.version)-$timestamp.zip"
$zipPath = Join-Path $OutputDir $zipName
$hashPath = "$zipPath.sha256.txt"

Write-Step "4/6 Build Staging Folder"
$stageDir = Join-Path $env:TEMP ("sm-chrome-ext-stage-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stageDir | Out-Null

try {
  foreach ($file in $packageFiles) {
    $relative = Get-RelativePath -BasePath $resolvedProjectRoot -FullPath $file.FullName
    $dest = Join-Path $stageDir $relative
    $destParent = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destParent)) {
      New-Item -ItemType Directory -Path $destParent | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
  }

  Write-Ok "Staging files copied"

  Write-Step "5/6 Create ZIP Package"
  if ($DryRun) {
    Write-Host "[DryRun] Packaging skipped"
    Write-Host "Would create: $zipPath"
    Write-Host "Would include $($packageFiles.Count) file(s)"
    exit 0
  }

  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }

  Compress-Archive -Path (Join-Path $stageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal
  Write-Ok "ZIP created: $zipPath"

  Write-Step "6/6 Generate SHA256"
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
  Set-Content -LiteralPath $hashPath -Value "$hash  $zipName" -Encoding UTF8
  Write-Ok "SHA256 file: $hashPath"
  Write-Host ""
  Write-Host "Done. Upload this ZIP to Chrome Web Store:"
  Write-Host $zipPath
}
finally {
  if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
  }
}


