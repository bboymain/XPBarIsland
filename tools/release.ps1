# Builds XPBarIsland-<version>.zip from the addon source and publishes it as a
# GitHub release. Bump "## Version:" in XPBarIsland.toc and add a CHANGELOG.md
# section first, then run:
#   powershell -ExecutionPolicy Bypass -File tools\release.ps1
param(
    [string]$Repo = "bboymain/XPBarIsland"
)
$ErrorActionPreference = "Stop"

$root    = Split-Path -Parent $PSScriptRoot
$toc     = Join-Path $root "XPBarIsland.toc"
$chg     = Join-Path $root "CHANGELOG.md"
$owner   = $Repo -split "/" | Select-Object -First 1

$version = ((Select-String -Path $toc -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value).Trim()
$tag     = "v$version"
Write-Host "Releasing $tag"

# gh and git both use the active gh account; make the repo owner active.
gh auth switch -u $owner 2>$null | Out-Null

# Release notes: the CHANGELOG.md section for this version.
$notes   = New-Object System.Collections.Generic.List[string]
$inSec   = $false
foreach ($line in Get-Content -LiteralPath $chg) {
    if ($line -match "^##\s+$([regex]::Escape($version))") { $inSec = $true; continue }
    if ($inSec -and $line -match '^##\s') { break }
    if ($inSec -and $line.Trim() -ne "") { $notes.Add($line) }
}
$notesText = if ($notes.Count -gt 0) { $notes -join "`n" } else { "XPBar Island $version" }

# Build the zip with forward-slash entry names and XPBarIsland/ at the top.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = Join-Path ([Environment]::GetFolderPath("Desktop")) "XPBarIsland-$version.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
$files   = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($d in @("Core", "Data", "Locale", "Media", "Settings", "UI")) {
    Get-ChildItem -LiteralPath (Join-Path $root $d) -File -Recurse | ForEach-Object { $files.Add($_) }
}
foreach ($f in @("XPBarIsland.toc", "README.md", "CHANGELOG.md", "logo.png")) {
    $files.Add((Get-Item -LiteralPath (Join-Path $root $f)))
}
foreach ($file in $files) {
    $rel = $file.FullName.Substring($root.Length + 1).Replace("\", "/")
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $file.FullName, "XPBarIsland/$rel",
        [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
$archive.Dispose()
Write-Host "Built $zip"

# Commit, tag, push, then create (or update) the release with the zip asset.
Push-Location $root
try {
    git add -A
    if (-not (git diff --cached --quiet)) { git commit -m "Release $tag" }
    if (-not (git tag -l $tag)) { git tag $tag }
    git push
    git push origin $tag

    gh release view $tag --repo $Repo *> $null
    if ($LASTEXITCODE -eq 0) {
        gh release upload $tag $zip --repo $Repo --clobber
    } else {
        $notesFile = Join-Path ([System.IO.Path]::GetTempPath()) "xpbar-release-notes.md"
        Set-Content -LiteralPath $notesFile -Value $notesText
        gh release create $tag $zip --repo $Repo --title "XPBar Island $version" --notes-file $notesFile
    }
} finally {
    Pop-Location
}
Write-Host "Done: https://github.com/$Repo/releases/tag/$tag"
