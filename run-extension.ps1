param(
  [string]$ExtensionPath = (Join-Path $PSScriptRoot "Sm_Chrome_Extension"),
  [string]$StartUrl = "https://example.com",
  [string]$ProfileDir = "",
  [switch]$FreshProfile,
  [switch]$DryRun,
  [switch]$UseFlags
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ChromePath {
  $candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
      return $candidate
    }
  }

  $regPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
  )

  foreach ($regPath in $regPaths) {
    try {
      $value = (Get-ItemProperty -Path $regPath -ErrorAction Stop)."(default)"
      if ($value -and (Test-Path -LiteralPath $value)) {
        return $value
      }
    } catch {
    }
  }

  return $null
}

$resolvedExtensionPath = (Resolve-Path -LiteralPath $ExtensionPath).Path
if (-not $ProfileDir) {
  $ProfileDir = Join-Path $resolvedExtensionPath ".chrome-test-profile"
}

Write-Host "Step 1/4: Resolve extension path"
Write-Host "Extension path: $resolvedExtensionPath"

$chromePath = Get-ChromePath
if (-not $chromePath) {
  throw "Chrome executable not found."
}

$productName = (Get-Item -LiteralPath $chromePath).VersionInfo.ProductName
$isGoogleChrome = $false
if ($productName -match "Google Chrome") {
  $isGoogleChrome = $true
}

Write-Host "Step 2/4: Locate Chrome executable"
Write-Host "Chrome path: $chromePath"
Write-Host "Product: $productName"

if ($FreshProfile -and (Test-Path -LiteralPath $ProfileDir)) {
  Remove-Item -LiteralPath $ProfileDir -Recurse -Force
}

if (-not (Test-Path -LiteralPath $ProfileDir)) {
  New-Item -ItemType Directory -Path $ProfileDir | Out-Null
}

Write-Host "Step 3/4: Prepare test profile"
Write-Host "Profile dir: $ProfileDir"

$args = @(
  "--user-data-dir=$ProfileDir",
  "--no-first-run",
  "--no-default-browser-check",
  "chrome://extensions/",
  $StartUrl
)

$usingLoadFlags = $false
if ($UseFlags -or (-not $isGoogleChrome)) {
  $args += "--disable-extensions-except=$resolvedExtensionPath"
  $args += "--load-extension=$resolvedExtensionPath"
  $usingLoadFlags = $true
}

Write-Host "Step 4/4: Build launch arguments"
Write-Host "Start URL: $StartUrl"
if ($usingLoadFlags) {
  Write-Host "Mode: Try command-line extension load flags"
} else {
  Write-Host "Mode: Guided manual load (recommended for Google Chrome)"
}

if ($DryRun) {
  Write-Host ""
  Write-Host "[DryRun] Launch skipped. Command preview:"
  Write-Host "`"$chromePath`" $($args -join ' ')"
  exit 0
}

Start-Process -FilePath $chromePath -ArgumentList $args | Out-Null
Write-Host ""
if ($usingLoadFlags) {
  Write-Host "Chrome launched. If extension card is missing, load it manually from chrome://extensions."
} else {
  Write-Host "Chrome launched."
  Write-Host "Manual steps:"
  Write-Host "1) Open chrome://extensions"
  Write-Host "2) Enable Developer mode"
  Write-Host "3) Click 'Load unpacked'"
  Write-Host "4) Select: $resolvedExtensionPath"
}
Write-Host "Then click extension icon and test the popup toggle button."


