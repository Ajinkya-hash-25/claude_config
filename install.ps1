param(
    [switch]$Git,
    [switch]$All,
    [switch]$Copy
)

$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $HOME ".claude"

function Ensure-Dir($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Link-Or-Copy($Source, $Target, [switch]$Directory) {
    if (Test-Path -LiteralPath $Target) {
        $item = Get-Item -LiteralPath $Target -Force
        if ($item.LinkType) {
            Remove-Item -LiteralPath $Target -Force
        } else {
            Write-Host "WARN: exists, skipping $Target"
            return
        }
    }

    if ($Copy) {
        if ($Directory) {
            Copy-Item -LiteralPath $Source -Destination $Target -Recurse
        } else {
            Copy-Item -LiteralPath $Source -Destination $Target
        }
        Write-Host "OK copy $Target"
        return
    }

    try {
        $type = if ($Directory) { "Directory" } else { "SymbolicLink" }
        if ($Directory) {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
        } else {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
        }
        Write-Host "OK link $Target"
    } catch {
        Write-Host "WARN: symlink failed; copying $Target"
        if ($Directory) {
            Copy-Item -LiteralPath $Source -Destination $Target -Recurse
        } else {
            Copy-Item -LiteralPath $Source -Destination $Target
        }
    }
}

function Install-ClaudeConfig {
    Ensure-Dir $ClaudeDir
    Ensure-Dir (Join-Path $ClaudeDir "skills")
    Ensure-Dir (Join-Path $ClaudeDir "agents")
    Ensure-Dir (Join-Path $ClaudeDir "commands")

    Get-ChildItem -LiteralPath (Join-Path $RepoDir "skills") -Directory | ForEach-Object {
        Link-Or-Copy $_.FullName (Join-Path $ClaudeDir "skills\$($_.Name)") -Directory
    }
    Get-ChildItem -LiteralPath (Join-Path $RepoDir "agents") -Filter "*.md" | ForEach-Object {
        Link-Or-Copy $_.FullName (Join-Path $ClaudeDir "agents\$($_.Name)")
    }
    Get-ChildItem -LiteralPath (Join-Path $RepoDir "commands") -Filter "*.md" | ForEach-Object {
        Link-Or-Copy $_.FullName (Join-Path $ClaudeDir "commands\$($_.Name)")
    }

    foreach ($file in @("CLAUDE.md", "settings.json")) {
        $target = Join-Path $ClaudeDir $file
        if (-not (Test-Path -LiteralPath $target)) {
            Copy-Item -LiteralPath (Join-Path $RepoDir $file) -Destination $target
            Write-Host "OK copy $target"
        } else {
            Write-Host "WARN: exists, manually merge $target"
        }
    }
}

function Install-GitHooks {
    $gitDir = git rev-parse --git-dir 2>$null
    if (-not $gitDir) {
        throw "Not inside git repo"
    }
    $hooksDir = Join-Path $gitDir "hooks"
    Ensure-Dir $hooksDir
    foreach ($hook in @("pre-push", "commit-msg")) {
        Link-Or-Copy (Join-Path $RepoDir "scripts\$hook") (Join-Path $hooksDir $hook)
    }
}

if ($Git -and -not $All) {
    Install-GitHooks
} else {
    Install-ClaudeConfig
    if ($All) {
        Install-GitHooks
    }
}

Write-Host "Done."
