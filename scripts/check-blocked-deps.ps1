Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$blockedPackages = @{
  'axios'            = @('1.14.1', '0.30.4')
  'plain-crypto-js'  = @('4.2.1')
}

$iocPatterns = @(
  'sfrclak\.com',
  '142\.11\.206\.73'
)

$manifestNames = @(
  'package.json',
  'package-lock.json',
  'npm-shrinkwrap.json',
  'pnpm-lock.yaml',
  'yarn.lock'
)

function Add-Finding {
  param(
    [System.Collections.Generic.List[string]] $Findings,
    [string] $Message
  )

  $Findings.Add($Message)
}

function Test-BlockedVersion {
  param(
    [string] $PackageName,
    [string] $Version
  )

  if (-not $Version) {
    return $false
  }

  return $blockedPackages.ContainsKey($PackageName) -and $blockedPackages[$PackageName] -contains $Version
}

function Test-PackageJsonSection {
  param(
    [string] $FilePath,
    [string] $SectionName,
    $SectionValue,
    [System.Collections.Generic.List[string]] $Findings
  )

  if (-not $SectionValue) {
    return
  }

  foreach ($item in $SectionValue.PSObject.Properties) {
    if (Test-BlockedVersion -PackageName $item.Name -Version ([string] $item.Value)) {
      Add-Finding $Findings "$FilePath :: $SectionName declares blocked version $($item.Name)@$($item.Value)"
    }
  }
}

function Test-PackageLockDependencies {
  param(
    [string] $FilePath,
    $Dependencies,
    [string] $Prefix,
    [System.Collections.Generic.List[string]] $Findings
  )

  if (-not $Dependencies) {
    return
  }

  foreach ($dep in $Dependencies.PSObject.Properties) {
    $name = $dep.Name
    $value = $dep.Value
    if (-not $value) {
      continue
    }

    if (Test-BlockedVersion -PackageName $name -Version ([string] $value.version)) {
      $label = if ($Prefix) { "$Prefix > $name" } else { $name }
      Add-Finding $Findings "$FilePath :: lockfile resolves blocked version $label@$($value.version)"
    }

    Test-PackageLockDependencies -FilePath $FilePath -Dependencies $value.dependencies -Prefix ($(if ($Prefix) { "$Prefix > $name" } else { $name })) -Findings $Findings
  }
}

function Test-PnpmLock {
  param(
    [string] $FilePath,
    [string] $Content,
    [System.Collections.Generic.List[string]] $Findings
  )

  foreach ($packageName in $blockedPackages.Keys) {
    foreach ($version in $blockedPackages[$packageName]) {
      $escapedName = [regex]::Escape($packageName)
      $escapedVersion = [regex]::Escape($version)
      $pattern = "(?m)^[\s/]*$escapedName@$escapedVersion(?:\(|:)"
      if ([regex]::IsMatch($Content, $pattern)) {
        Add-Finding $Findings "$FilePath :: pnpm lockfile resolves blocked version $packageName@$version"
      }
    }
  }
}

function Test-YarnLock {
  param(
    [string] $FilePath,
    [string] $Content,
    [System.Collections.Generic.List[string]] $Findings
  )

  $blocks = [regex]::Split($Content.Trim(), "(?m)^\s*$")
  foreach ($block in $blocks) {
    foreach ($packageName in $blockedPackages.Keys) {
      if ($block -notmatch "(?m)^""?$([regex]::Escape($packageName))@") {
        continue
      }

      if ($block -match '(?m)^\s*version\s+"([^"]+)"') {
        $version = $Matches[1]
        if (Test-BlockedVersion -PackageName $packageName -Version $version) {
          Add-Finding $Findings "$FilePath :: yarn lockfile resolves blocked version $packageName@$version"
        }
      }
    }
  }
}

$files = Get-ChildItem -Path $repoRoot -Recurse -File -Force |
  Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and
    $_.FullName -notmatch '[\\/]node_modules[\\/]' -and
    $_.Name -in $manifestNames
  }

$findings = [System.Collections.Generic.List[string]]::new()

foreach ($file in $files) {
  $relativePath = Resolve-Path -Relative $file.FullName
  $content = Get-Content -LiteralPath $file.FullName -Raw

  foreach ($pattern in $iocPatterns) {
    if ($content -match $pattern) {
      Add-Finding $findings "$relativePath :: contains reported IOC pattern /$pattern/"
    }
  }

  switch ($file.Name) {
    'package.json' {
      $json = $content | ConvertFrom-Json
      foreach ($sectionName in @('dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies', 'overrides', 'resolutions')) {
        Test-PackageJsonSection -FilePath $relativePath -SectionName $sectionName -SectionValue $json.$sectionName -Findings $findings
      }
    }
    'package-lock.json' {
      $json = $content | ConvertFrom-Json
      if ($json.packages) {
        foreach ($pkg in $json.packages.PSObject.Properties) {
          $pathKey = $pkg.Name
          $pkgValue = $pkg.Value
          if (-not $pkgValue.name -or -not $pkgValue.version) {
            continue
          }

          if (Test-BlockedVersion -PackageName ([string] $pkgValue.name) -Version ([string] $pkgValue.version)) {
            Add-Finding $findings "$relativePath :: package-lock resolves blocked version $($pkgValue.name)@$($pkgValue.version) at $pathKey"
          }
        }
      }

      Test-PackageLockDependencies -FilePath $relativePath -Dependencies $json.dependencies -Prefix '' -Findings $findings
    }
    'npm-shrinkwrap.json' {
      $json = $content | ConvertFrom-Json
      if ($json.packages) {
        foreach ($pkg in $json.packages.PSObject.Properties) {
          $pathKey = $pkg.Name
          $pkgValue = $pkg.Value
          if (-not $pkgValue.name -or -not $pkgValue.version) {
            continue
          }

          if (Test-BlockedVersion -PackageName ([string] $pkgValue.name) -Version ([string] $pkgValue.version)) {
            Add-Finding $findings "$relativePath :: shrinkwrap resolves blocked version $($pkgValue.name)@$($pkgValue.version) at $pathKey"
          }
        }
      }

      Test-PackageLockDependencies -FilePath $relativePath -Dependencies $json.dependencies -Prefix '' -Findings $findings
    }
    'pnpm-lock.yaml' {
      Test-PnpmLock -FilePath $relativePath -Content $content -Findings $findings
    }
    'yarn.lock' {
      Test-YarnLock -FilePath $relativePath -Content $content -Findings $findings
    }
  }
}

if ($findings.Count -gt 0) {
  Write-Host 'Blocked dependency or IOC findings detected:' -ForegroundColor Red
  $findings | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host 'No blocked dependency versions or IOC patterns found.' -ForegroundColor Green
