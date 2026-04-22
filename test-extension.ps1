param(
  [string]$ExtensionPath = (Join-Path $PSScriptRoot "Sm_Chrome_Extension"),
  [switch]$LaunchChrome,
  [string]$StartUrl = "https://example.com"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
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

function Write-Fail {
  param([string]$Message)
  Write-Host "[FAIL] $Message" -ForegroundColor Red
}

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

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

try {
  $resolvedExtensionPath = (Resolve-Path -LiteralPath $ExtensionPath).Path
} catch {
  Write-Fail "Extension path not found: $ExtensionPath"
  exit 1
}

Write-Section "Extension Validation"
Write-Host "Target: $resolvedExtensionPath"

$requiredFiles = @(
  "manifest.json",
  "background.js",
  "popup/popup.html",
  "popup/popup.js",
  "content/content.js",
  "options/options.html",
  "options/options.js"
)

foreach ($file in $requiredFiles) {
  $fullPath = Join-Path $resolvedExtensionPath $file
  if (Test-Path -LiteralPath $fullPath) {
    Write-Ok "Found $file"
  } else {
    $failures.Add("Missing required file: $file")
    Write-Fail "Missing $file"
  }
}

$manifestPath = Join-Path $resolvedExtensionPath "manifest.json"
if (Test-Path -LiteralPath $manifestPath) {
  try {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    Write-Ok "manifest.json parse success"
  } catch {
    $failures.Add("manifest.json is invalid JSON")
    Write-Fail "manifest.json parse failed"
  }
}

if ($null -ne $manifest) {
  if ($manifest.manifest_version -ne 3) {
    $failures.Add("manifest_version must be 3 (current: $($manifest.manifest_version))")
    Write-Fail "manifest_version is not 3"
  } else {
    Write-Ok "manifest_version is 3"
  }

  if (-not $manifest.name) {
    $failures.Add("manifest name is missing")
    Write-Fail "manifest name missing"
  } else {
    Write-Ok "manifest name: $($manifest.name)"
  }

  if (-not $manifest.version) {
    $failures.Add("manifest version is missing")
    Write-Fail "manifest version missing"
  } else {
    Write-Ok "manifest version: $($manifest.version)"
  }

  $sw = $manifest.background.service_worker
  if (-not $sw) {
    $failures.Add("background.service_worker is missing")
    Write-Fail "service_worker missing"
  } else {
    $swPath = Join-Path $resolvedExtensionPath $sw
    if (Test-Path -LiteralPath $swPath) {
      Write-Ok "service_worker file exists: $sw"
    } else {
      $failures.Add("service_worker file not found: $sw")
      Write-Fail "service_worker file missing: $sw"
    }
  }

  if (-not $manifest.content_scripts -or $manifest.content_scripts.Count -eq 0) {
    $warnings.Add("No content_scripts configured")
    Write-Warn "content_scripts not configured"
  } else {
    foreach ($cs in $manifest.content_scripts) {
      foreach ($jsFile in $cs.js) {
        $csPath = Join-Path $resolvedExtensionPath $jsFile
        if (Test-Path -LiteralPath $csPath) {
          Write-Ok "content script exists: $jsFile"
        } else {
          $failures.Add("content script file missing: $jsFile")
          Write-Fail "content script file missing: $jsFile"
        }
      }
    }
  }

  if ($manifest.host_permissions -and ($manifest.host_permissions -contains "<all_urls>")) {
    $warnings.Add("host_permissions includes <all_urls>. Narrow scope before release.")
    Write-Warn "host_permissions has <all_urls>"
  }
}

Write-Section "Summary"
if ($warnings.Count -gt 0) {
  foreach ($warning in $warnings) {
    Write-Warn $warning
  }
} else {
  Write-Ok "No warnings"
}

if ($failures.Count -gt 0) {
  foreach ($failure in $failures) {
    Write-Fail $failure
  }
  Write-Host ""
  Write-Host "Validation failed: $($failures.Count) issue(s)." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Validation passed." -ForegroundColor Green

if ($LaunchChrome) {
  Write-Section "Launch Chrome Test Session"
  $chromePath = Get-ChromePath
  if (-not $chromePath) {
    Write-Fail "Chrome executable not found."
    exit 1
  }

  $testProfile = Join-Path $env:TEMP ("chrome-ext-test-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $testProfile | Out-Null

  $args = @(
    "--user-data-dir=$testProfile",
    "--disable-extensions-except=$resolvedExtensionPath",
    "--load-extension=$resolvedExtensionPath",
    $StartUrl
  )

  Start-Process -FilePath $chromePath -ArgumentList $args | Out-Null
  Write-Ok "Chrome launched with extension"
  Write-Host "Profile: $testProfile"
  Write-Host "URL: $StartUrl"
  Write-Host ""
  Write-Host "Manual check:"
  Write-Host "1. Click extension icon"
  Write-Host "2. Toggle highlight button in popup"
  Write-Host "3. Open options page and change color"
}

exit 0


