<#
.SYNOPSIS
    Terminal Notebook Browser with Folder & Nerd Font Support
.DESCRIPTION
    A terminal-based notebook for browsing, writing, and organizing Markdown notes.
    Features collapsible folder hierarchy, Nerd Font icons, and Obsidian integration.
#>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$SubCommand,

    [Parameter(Position=2, ValueFromRemainingArguments=$true)]
    [string[]]$ArgsList,

    [Alias("Path", "n")]
    [string]$Notebook
)

$AppVersion = "3.2.2"

# Disable progress bar rendering to prevent terminal title bar flickering from Start-Sleep
$ProgressPreference = 'SilentlyContinue'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($null -eq $IsWindows) { $IsWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT' }
if ($null -eq $IsMacOS) { $IsMacOS = [System.Environment]::OSVersion.Platform -eq 'Unix' -and (uname -s) -match 'Darwin' }

# Pick up PATH entries from newly installed winget packages (like micro) without restarting the shell.
# Entries are only appended, so session-specific PATH changes (venvs, profile additions) are preserved.
if ($IsWindows) {
    try {
        $sessionPaths = @($env:Path -split ';' | Where-Object { $_ })
        $newPaths = foreach ($scope in 'Machine', 'User') {
            [System.Environment]::GetEnvironmentVariable('Path', $scope) -split ';' |
                Where-Object { $_ -and $sessionPaths -notcontains $_ }
        }
        if ($newPaths) { $env:Path = (@($sessionPaths) + @($newPaths | Select-Object -Unique)) -join ';' }
    } catch {}
}

# --- Multi-Notebook Global Configuration Management ---
$GlobalConfigFile = Join-Path $HOME ".terminal_notebook.json"

function Get-GlobalNotebookConfig {
    $defaultPath = Join-Path $HOME "Notes"
    $defaultLeaf = Split-Path $defaultPath -Leaf
    $defaultObj = @{
        ActiveNotebook = $defaultPath
        Notebooks = @(
            @{ Name = $defaultLeaf; Path = $defaultPath }
        )
    }

    if (Test-Path -LiteralPath $GlobalConfigFile) {
        try {
            $json = Get-Content -LiteralPath $GlobalConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $active = if ($json.ActiveNotebook) { [string]$json.ActiveNotebook } else { $defaultPath }
            $list = [System.Collections.Generic.List[object]]::new()
            if ($json.Notebooks) {
                foreach ($nb in $json.Notebooks) {
                    if ($nb.Path) {
                        $nbPath = [string]$nb.Path
                        $rawName = [string]$nb.Name
                        $cleanName = if ([string]::IsNullOrWhiteSpace($rawName) -or $rawName -eq "Default") {
                            Split-Path $nbPath -Leaf
                        } else {
                            $rawName
                        }
                        $list.Add(@{ Name = $cleanName; Path = $nbPath })
                    }
                }
            }
            if ($list.Count -eq 0) {
                $list.Add(@{ Name = $defaultLeaf; Path = $defaultPath })
            }
            return @{
                ActiveNotebook = $active
                Notebooks = $list.ToArray()
            }
        } catch {}
    }
    return $defaultObj
}

function Save-GlobalNotebookConfig($config) {
    try {
        $jsonStr = $config | ConvertTo-Json -Depth 5
        Write-Utf8File -Path $GlobalConfigFile -Text ($jsonStr + [Environment]::NewLine)
    } catch {}
}

function Get-ActiveNotebookName {
    $cfg = Get-GlobalNotebookConfig
    foreach ($nb in $cfg.Notebooks) {
        if ($nb.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/')) {
            $name = $nb.Name
            if ([string]::IsNullOrWhiteSpace($name) -or $name -eq "Default") {
                $name = Split-Path $nb.Path -Leaf
            }
            return $name
        }
    }
    return (Split-Path $script:NotesDir -Leaf)
}

function Set-ActiveNotebook([string]$Target) {
    if ([string]::IsNullOrWhiteSpace($Target)) { return }

    $cfg = Get-GlobalNotebookConfig
    $resolvedPath = $null
    $matchedName = $null

    # 1. Check if Target matches a registered Notebook Name
    foreach ($nb in $cfg.Notebooks) {
        if ($nb.Name -eq $Target -or $nb.Name.ToLower() -eq $Target.ToLower()) {
            $resolvedPath = $nb.Path
            $matchedName = $nb.Name
            break
        }
    }

    # 2. If not a named notebook, treat as path
    if (-not $resolvedPath) {
        if (Test-Path -LiteralPath $Target) {
            $resolvedPath = (Get-Item -LiteralPath $Target).FullName
        } else {
            $homeCheck = Join-Path $HOME $Target
            if (Test-Path -LiteralPath $homeCheck) {
                $resolvedPath = (Get-Item -LiteralPath $homeCheck).FullName
            } else {
                $resolvedPath = [System.IO.Path]::GetFullPath($Target)
            }
        }
        $matchedName = Split-Path $resolvedPath -Leaf
    }

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        New-Item -ItemType Directory -Path $resolvedPath -Force | Out-Null
    }

    $script:NotesDir = $resolvedPath

    # Update notebooks list in global config if not already registered
    $existsInConfig = $false
    $updatedList = [System.Collections.Generic.List[object]]::new()
    foreach ($nb in $cfg.Notebooks) {
        if ($nb.Path.TrimEnd('\', '/') -eq $resolvedPath.TrimEnd('\', '/')) {
            $existsInConfig = $true
        }
        $updatedList.Add($nb)
    }

    if (-not $existsInConfig) {
        $updatedList.Add(@{ Name = $matchedName; Path = $resolvedPath })
    }

    $cfg.ActiveNotebook = $resolvedPath
    $cfg.Notebooks = $updatedList.ToArray()
    Save-GlobalNotebookConfig $cfg

    Load-NotebookPreferences
}

function Load-NotebookPreferences {
    $script:CollapsedFolders = @{}
    $script:BannerCache     = @{}
    $script:ObsidianVaultId = $null
    $script:LastActionPath  = $null
    $script:SortMode        = "date"

    $cfgFile = Join-Path $script:NotesDir ".config.json"
    if (Test-Path -LiteralPath $cfgFile) {
        try {
            $cfg = Get-Content -LiteralPath $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.SortMode -in @("date", "alpha")) { $script:SortMode = $cfg.SortMode }
        } catch {}
    }
}

# --- Resolve Startup Notebook ---
$envNotebook = if ($env:TERMINAL_NOTEBOOK_DIR) { $env:TERMINAL_NOTEBOOK_DIR } else { $env:NOTEBOOK_DIR }
$targetStartup = if ($Notebook) { $Notebook } elseif ($envNotebook) { $envNotebook } else { $null }

if ($targetStartup) {
    Set-ActiveNotebook -Target $targetStartup
} else {
    $globalCfg = Get-GlobalNotebookConfig
    $script:NotesDir = $globalCfg.ActiveNotebook
    if (-not (Test-Path -LiteralPath $script:NotesDir)) {
        New-Item -ItemType Directory -Path $script:NotesDir -Force | Out-Null
    }
    Load-NotebookPreferences
}

# --- Shared Constants ---
$ExcludedDirPattern = '[\\/]\.(obsidian|git)([\\/]|$)'   # Matches .obsidian / .git path segments on Windows & macOS
$CancelWords        = @("c", "cancel", ":q", "exit", "quit")
$Utf8NoBom          = New-Object System.Text.UTF8Encoding($false)
$AnsiRegex          = [regex]'\x1b\[[0-9;]*m'
$AnsiTokenRegex     = [regex]'\G\x1b\[[0-9;]*m'

# --- Glyph Definitions (Hex-escaped for encoding safety) ---
$bTopLeft      = [string][char]0x250C # Top Left
$bTopRight     = [string][char]0x2510 # Top Right
$bBotLeft      = [string][char]0x2514 # Bot Left
$bBotRight     = [string][char]0x2518 # Bot Right
$bHoriz        = [string][char]0x2500 # Horiz
$bVert         = [string][char]0x2502 # Vert
$bTopT         = [string][char]0x252C # Top T
$bBotT         = [string][char]0x2534 # Bot T

# Nerd Font & Tree Glyphs
$gFolderClosed = [string][char]0xF07B # Nerd Font folder
$gFolderOpen   = [string][char]0xF07C # Nerd Font folder open
$gFileIcon     = [string][char]0xF15C # Nerd Font file
$gArrowRight   = [string][char]0x25B6 # Collapsed indicator
$gArrowDown    = [string][char]0x25BC # Expanded indicator
$gBranchMid    = [string][char]0x251C + [string][char]0x2500 # ├─
$gBranchEnd    = [string][char]0x2514 + [string][char]0x2500 # └─
$gSortIcon     = [string][char]0xF0DC #  Sort icon
$gSortAlpha    = [string][char]0xF160 #  Sort alpha
$gSortDate     = [string][char]0xF073 #  Sort date

# Markdown & Callout Glyphs
$uRoundTL      = [string][char]0x256D # ╭
$uRoundTR      = [string][char]0x256E # ╮
$uRoundBL      = [string][char]0x2570 # ╰
$uRoundBR      = [string][char]0x256F # ╯
$uBar          = [string][char]0x258C # ▌
$uBullet       = [string][char]0x2022 # •
$uBoxUncheck   = [string][char]0x2610 # ☐
$uCheckMark    = [string][char]0x2714 # ✔
$uArrowUpR     = [string][char]0x2197 # ↗
$uMidLeft      = [string][char]0x251C # ├
$uMidRight     = [string][char]0x2524 # ┤

# --- Gray & Bright Orange Theme Palette ---
$esc = [string][char]27
$rst = "$esc[0m"

# ANSI text style codes
$sBold         = "$esc[1m"
$sNoBold       = "$esc[22m"
$sItalic       = "$esc[3m"
$sNoItalic     = "$esc[23m"
$sStrike       = "$esc[9m"
$sNoStrike     = "$esc[29m"

function fg($r, $g, $b) { return "$esc[38;2;$r;$g;${b}m" }
function bg($r, $g, $b) { return "$esc[48;2;$r;$g;${b}m" }

# Core Colors
$cOrange     = fg 255 130 0                  # Vivid Flame Orange (Primary Visual Accent)
$cAmber      = fg 255 185 35                 # Radiant Warm Amber (Secondary Accent / Bullets)
$cWhite      = fg 255 255 255                # Crisp Pure White (Max Legibility)
$cSilver     = fg 220 224 235                # Soft Silver (High Legibility Body Text)
$cGray       = fg 155 160 175                # Neutral Slate Gray (Metadata & Secondary Text)
$cDarkGray   = fg 95 100 115                 # Graphite Border Gray (Structural Borders)
$cWarn       = fg 255 100 30                 # Hot Orange-Red (Warning Callouts)
$cCodeBg     = bg 48 50 62                   # Subtle Dark Slate for Inline Code Badges
$cHighlightBg = bg 85 60 10                  # Burnt Amber for ==highlights==
$cSelected   = (bg 255 130 0) + (fg 0 0 0)   # High-Contrast Black on Flame Orange
$cFolder     = fg 255 145 10                 # Warm Orange for Folders

# Gradient stops for Horizon Wave (Graphite -> Flame Orange -> Amber)
$gWaveDark   = @(65, 68, 80)                 # Slate Graphite
$gWaveOrange = @(255, 125, 0)                # Vivid Flame Orange
$gWaveAmber  = @(255, 185, 35)               # Radiant Amber Gold

function Get-GradientColor($c1, $c2, [double]$ratio) {
    $r = [int]($c1[0] * (1.0 - $ratio) + $c2[0] * $ratio)
    $g = [int]($c1[1] * (1.0 - $ratio) + $c2[1] * $ratio)
    $b = [int]($c1[2] * (1.0 - $ratio) + $c2[2] * $ratio)
    return @($r, $g, $b)
}

# Borders and dividers repeat constantly, so gradient strings are memoized (case-sensitive keys)
$script:GradientCache = [System.Collections.Generic.Dictionary[string, string]]::new()

function Render-GradientText([string]$text, $c1, $c2) {
    $cacheKey = "$c1|$c2|$text"
    $cached = $null
    if ($script:GradientCache.TryGetValue($cacheKey, [ref]$cached)) { return $cached }

    $len = $text.Length
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $len; $i++) {
        $ratio = if ($len -gt 1) { $i / ($len - 1.0) } else { 0.0 }
        $rgb = Get-GradientColor $c1 $c2 $ratio
        [void]$sb.Append("$esc[38;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m").Append($text[$i])
    }
    $result = $sb.Append($rst).ToString()
    $script:GradientCache[$cacheKey] = $result
    return $result
}

function Render-AuroraWave([int]$width, $c1, $c2, $c3, [string]$char) {
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $width; $i++) {
        $t = if ($width -gt 1) { $i / ($width - 1.0) } else { 0.0 }
        $col = if ($t -lt 0.5) {
            Get-GradientColor $c1 $c2 ($t * 2.0)
        } else {
            Get-GradientColor $c2 $c3 (($t - 0.5) * 2.0)
        }
        [void]$sb.Append("$esc[38;2;$($col[0]);$($col[1]);$($col[2])m").Append($char)
    }
    return $sb.Append($rst).ToString()
}

# Single-character gradient bars always resolve to their first color, so render them once.
$barLeft  = Render-GradientText $bVert $gWaveOrange $gWaveDark
$barRight = Render-GradientText $bVert $gWaveDark $gWaveOrange

# Rounded "card" borders used by frontmatter, code blocks and the folder telemetry panel
function New-BoxTop([string]$Title, [int]$Width) {
    $dashesRight = [Math]::Max(2, $Width - $Title.Length - 3)
    return " " + (Render-GradientText ($uRoundTL + $bHoriz + $Title + ($bHoriz * $dashesRight) + $uRoundTR) $gWaveOrange $gWaveDark)
}

function New-BoxBottom([int]$Width) {
    return " " + (Render-GradientText ($uRoundBL + ($bHoriz * ($Width - 2)) + $uRoundBR) $gWaveOrange $gWaveDark)
}

# --- Shared Helpers ---
function Test-CancelInput([string]$Text) {
    return ([string]::IsNullOrWhiteSpace($Text) -or $Text.Trim().ToLower() -in $CancelWords)
}

function ConvertTo-Slug([string]$Text, [switch]$Lower) {
    $slug = ($Text.Trim() -replace '[^\w\s-]', '' -replace '\s+', '-').Trim()
    if ($Lower) { $slug = $slug.ToLower() }
    return $slug
}

function Get-RelativeNotePath([string]$Path) {
    return $Path.Substring($NotesDir.Length).TrimStart('\', '/')
}

function Write-Utf8File {
    # BOM-less UTF-8 on every PowerShell version (Set-Content -Encoding UTF8 adds a BOM on 5.1)
    param([string]$Path, [string]$Text, [switch]$Append)
    if ($Append) { [System.IO.File]::AppendAllText($Path, $Text, $Utf8NoBom) }
    else { [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom) }
}

function Set-CursorVisible([bool]$Visible) {
    try { [Console]::CursorVisible = $Visible } catch {}
    if ($Visible) { [Console]::Write("$esc[?25h") } else { [Console]::Write("$esc[?25l") }
}

function Read-KeyOrResize {
    # Blocks until a key is pressed (returns ConsoleKeyInfo) or the window is resized (returns $null)
    $w = [Console]::WindowWidth
    $h = [Console]::WindowHeight
    while ($true) {
        if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
        if ([Console]::WindowWidth -ne $w -or [Console]::WindowHeight -ne $h) { return $null }
        Start-Sleep -Milliseconds 25
    }
}

function Write-ModalHeader {
    # Default style: DarkGray rules with an orange title. -Color applies one console color to everything.
    param([string]$Title, [string]$Color = "")
    $rule = "=" * 50
    $pad = " " * [Math]::Max(0, [int]((50 - $Title.Length) / 2))
    Clear-Host
    if ($Color) {
        Write-Host $rule -ForegroundColor $Color
        Write-Host ($pad + $Title) -ForegroundColor $Color
        Write-Host $rule -ForegroundColor $Color
    } else {
        Write-Host $rule -ForegroundColor DarkGray
        Write-Host ($cOrange + $pad + $Title + $rst)
        Write-Host $rule -ForegroundColor DarkGray
    }
}

# --- Inline Floating Popup Modal Engine ---
function Get-PlainSubstring([string]$Text, [int]$StartCol, [int]$Length) {
    if ([string]::IsNullOrEmpty($Text) -or $Length -le 0) { return "" }
    $plain = $AnsiRegex.Replace($Text, '')
    if ($StartCol -ge $plain.Length) { return "" }
    $actualLen = [Math]::Min($Length, $plain.Length - $StartCol)
    return $plain.Substring($StartCol, $actualLen)
}

function Get-RightBorderANSI([string]$Line, [int]$TermWidth) {
    if ([string]::IsNullOrEmpty($Line)) { return "" }
    $trimmed = $Line.TrimEnd("`r", "`n")
    if ($trimmed.EndsWith($rst)) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - $rst.Length)
    }
    $activeColor = ""
    $lastChar = ""
    $i = 0
    while ($i -lt $trimmed.Length) {
        $m = $AnsiTokenRegex.Match($trimmed, $i)
        if ($m.Success) {
            if ($m.Value -ne $rst) {
                $activeColor = $m.Value
            }
            $i += $m.Length
        } else {
            $lastChar = $trimmed[$i]
            $i++
        }
    }
    if ($lastChar) {
        return $activeColor + $lastChar + $rst
    }
    return ""
}

function Overlay-ModalOnFrame($FrameLines, $ModalLines, [int]$TermWidth) {
    $mh = $ModalLines.Count
    $mw = $AnsiRegex.Replace($ModalLines[0], '').Length
    $topRow = [Math]::Max(2, [int](($FrameLines.Count - $mh) / 2))
    $leftCol = [Math]::Max(1, [int](($TermWidth - $mw) / 2))

    $outLines = [System.Collections.Generic.List[string]]::new()

    for ($i = 0; $i -lt $FrameLines.Count; $i++) {
        if ($i -ge $topRow -and ($i - $topRow) -lt $mh) {
            $mIdx = $i - $topRow
            $leftBgRaw = Limit-AnsiText $FrameLines[$i] $leftCol
            $leftVisLen = ($AnsiRegex.Replace($leftBgRaw, '')).Length
            if ($leftVisLen -lt $leftCol) {
                $leftBgRaw += (" " * ($leftCol - $leftVisLen))
            }
            $leftBg = $leftBgRaw + $rst

            $modalStr = $ModalLines[$mIdx]
            $modalVisLen = ($AnsiRegex.Replace($modalStr, '')).Length
            if ($modalVisLen -lt $mw) {
                $padSpace = " " * ($mw - $modalVisLen)
                if ($modalStr.EndsWith($rst)) {
                    $modalStr = $modalStr.Substring(0, $modalStr.Length - $rst.Length) + $padSpace + $rst
                } else {
                    $modalStr += $padSpace
                }
            } elseif ($modalVisLen -gt $mw) {
                $modalStr = Limit-AnsiText $modalStr $mw
            }

            $rightCol = $leftCol + $mw

            $rightPreviewLen = ($TermWidth - 1) - $rightCol
            $rightPreview = ""
            if ($rightPreviewLen -gt 0) {
                $plainRight = Get-PlainSubstring $FrameLines[$i] $rightCol $rightPreviewLen
                if ($plainRight.Length -lt $rightPreviewLen) {
                    $plainRight = $plainRight.PadRight($rightPreviewLen)
                }
                $rightPreview = $cSilver + $plainRight + $rst
            }

            $rightBorder = Get-RightBorderANSI $FrameLines[$i] $TermWidth

            $outLines.Add($leftBg + $modalStr + $rightPreview + $rightBorder)
        } else {
            $outLines.Add($FrameLines[$i])
        }
    }
    return $outLines
}

function Show-InlineInputModal {
    param(
        [string]$Title,
        [string]$Subtitle = "",
        [string]$PromptLabel = "Name:",
        [string]$InitialValue = "",
        [string]$ConfirmActionLabel = "Submit",
        [scriptblock]$RenderBgBlock
    )

    $inputVal = $InitialValue

    Set-CursorVisible $false

    while ($true) {
        $bgLines = & $RenderBgBlock
        $termW = 99
        try { if ([Console]::WindowWidth -gt 20) { $termW = [Console]::WindowWidth - 1 } } catch {}

        $cardW = [Math]::Min(60, [Math]::Max(44, $termW - 10))
        $innerW = $cardW - 10

        $subDisp = Truncate-String -Str $Subtitle -MaxLen ($cardW - 4)

        $dispInput = $inputVal
        if ($dispInput.Length -gt ($innerW - 2)) {
            $dispInput = "..." + $dispInput.Substring($dispInput.Length - ($innerW - 5))
        }

        $cCardBg = bg 34 37 48
        $cInputBg = bg 20 22 30

        $titleDisp = Truncate-String -Str $Title -MaxLen ($cardW - 6)
        $headerTitle = " $titleDisp "
        $dashRight = [Math]::Max(2, $cardW - 3 - $headerTitle.Length)
        $topBorderColor = fg 255 140 30
        $botBorderColor = fg 255 140 30
        $cardVBar = (fg 255 140 30) + $bVert
        $innerVBar = (fg 95 100 115) + $bVert

        $modalLines = [System.Collections.Generic.List[string]]::new()
        $modalLines.Add($cCardBg + $topBorderColor + $uRoundTL + $bHoriz + $cOrange + $headerTitle + $topBorderColor + ($bHoriz * $dashRight) + $uRoundTR + $rst)

        if ($subDisp) {
            $subPad = " " * [Math]::Max(0, $cardW - 4 - $subDisp.Length)
            $modalLines.Add($cCardBg + $cardVBar + " " + $cGray + $subDisp + $subPad + " " + $cardVBar + $rst)
        } else {
            $modalLines.Add($cCardBg + $cardVBar + (" " * ($cardW - 2)) + $cardVBar + $rst)
        }

        $lblDisp = Truncate-String -Str $PromptLabel -MaxLen ($cardW - 4)
        $lblPad = " " * [Math]::Max(0, $cardW - 4 - $lblDisp.Length)
        $modalLines.Add($cCardBg + $cardVBar + " " + $cWhite + $sBold + $lblDisp + $sNoBold + $lblPad + " " + $cardVBar + $rst)

        $modalLines.Add($cCardBg + $cardVBar + "  " + $cDarkGray + $uRoundTL + ($bHoriz * ($innerW + 2)) + $uRoundTR + $cCardBg + "  " + $cardVBar + $rst)

        $inputVisibleLen = $dispInput.Length + 1
        $inputPad = " " * [Math]::Max(0, $innerW - $inputVisibleLen)
        $modalLines.Add($cCardBg + $cardVBar + "  " + $innerVBar + $cInputBg + " " + $cWhite + $dispInput + $cOrange + "_" + $cInputBg + $inputPad + " " + $cCardBg + $innerVBar + $cCardBg + "  " + $cardVBar + $rst)

        $modalLines.Add($cCardBg + $cardVBar + "  " + $cDarkGray + $uRoundBL + ($bHoriz * ($innerW + 2)) + $uRoundBR + $cCardBg + "  " + $cardVBar + $rst)

        $modalLines.Add($cCardBg + $cardVBar + (" " * ($cardW - 2)) + $cardVBar + $rst)

        $footerKeys = "$cAmber[Enter]$cSilver $ConfirmActionLabel   $cAmber[Esc]$cSilver Cancel"
        $footerVisibleLen = ($AnsiRegex.Replace($footerKeys, '')).Length
        $footDashRight = [Math]::Max(2, $cardW - 6 - $footerVisibleLen)
        $modalLines.Add($cCardBg + $botBorderColor + $uRoundBL + ($bHoriz * 2) + " " + $footerKeys + $cCardBg + " " + $botBorderColor + ($bHoriz * $footDashRight) + $uRoundBR + $rst)

        $compositeFrame = Overlay-ModalOnFrame -FrameLines $bgLines -ModalLines $modalLines -TermWidth $termW

        $sb = [System.Text.StringBuilder]::new()
        foreach ($line in $compositeFrame) {
            [void]$sb.AppendLine($line)
        }
        try { [Console]::SetCursorPosition(0, 0) } catch {}
        [Console]::Write("$esc[H")
        [Console]::Write($sb.ToString().Replace("`r`n", "$esc[K`r`n") + "$esc[K$esc[J")

        try { $k = Read-KeyOrResize } catch { return $null }
        if ($null -eq $k) { continue }

        switch ($k.Key) {
            "Enter" {
                return $inputVal.Trim()
            }
            "Escape" {
                return $null
            }
            "Backspace" {
                if ($inputVal.Length -gt 0) {
                    $inputVal = $inputVal.Substring(0, $inputVal.Length - 1)
                }
            }
            default {
                $char = $k.KeyChar
                if (-not [char]::IsControl($char) -and [int]$char -ne 0) {
                    $inputVal += $char
                }
            }
        }
    }
}

function Show-InlineConfirmModal {
    param(
        [string]$Title = "CONFIRM ACTION",
        [string]$Message,
        [string]$SubMessage = "",
        [string]$ConfirmLabel = "Delete",
        [scriptblock]$RenderBgBlock
    )

    Set-CursorVisible $false

    while ($true) {
        $bgLines = & $RenderBgBlock
        $termW = 99
        try { if ([Console]::WindowWidth -gt 20) { $termW = [Console]::WindowWidth - 1 } } catch {}

        $cardW = [Math]::Min(60, [Math]::Max(44, $termW - 10))
        $msgDisp = Truncate-String -Str $Message -MaxLen ($cardW - 4)
        $subDisp = Truncate-String -Str $SubMessage -MaxLen ($cardW - 4)

        $cCardBg = bg 44 32 34

        $titleDisp = Truncate-String -Str $Title -MaxLen ($cardW - 6)
        $headerTitle = " $titleDisp "
        $dashRight = [Math]::Max(2, $cardW - 3 - $headerTitle.Length)
        $topBorderColor = fg 255 90 90
        $botBorderColor = fg 255 120 40
        $cardVBar = (fg 255 100 30) + $bVert

        $modalLines = [System.Collections.Generic.List[string]]::new()
        $modalLines.Add($cCardBg + $topBorderColor + $uRoundTL + $bHoriz + $cWarn + $headerTitle + $topBorderColor + ($bHoriz * $dashRight) + $uRoundTR + $rst)

        $modalLines.Add($cCardBg + $cardVBar + (" " * ($cardW - 2)) + $cardVBar + $rst)

        $msgPad = " " * [Math]::Max(0, $cardW - 4 - $msgDisp.Length)
        $modalLines.Add($cCardBg + $cardVBar + " " + $cWhite + $sBold + $msgDisp + $sNoBold + $msgPad + " " + $cardVBar + $rst)

        if ($subDisp) {
            $subPad = " " * [Math]::Max(0, $cardW - 4 - $subDisp.Length)
            $modalLines.Add($cCardBg + $cardVBar + " " + $cWarn + $subDisp + $subPad + " " + $cardVBar + $rst)
        } else {
            $modalLines.Add($cCardBg + $cardVBar + (" " * ($cardW - 2)) + $cardVBar + $rst)
        }

        $modalLines.Add($cCardBg + $cardVBar + (" " * ($cardW - 2)) + $cardVBar + $rst)

        $footerKeys = "$cWarn[Y]$cSilver $ConfirmLabel   $cAmber[Esc/N]$cSilver Cancel"
        $footerVisibleLen = ($AnsiRegex.Replace($footerKeys, '')).Length
        $footDashRight = [Math]::Max(2, $cardW - 6 - $footerVisibleLen)
        $modalLines.Add($cCardBg + $botBorderColor + $uRoundBL + ($bHoriz * 2) + " " + $footerKeys + $cCardBg + " " + $botBorderColor + ($bHoriz * $footDashRight) + $uRoundBR + $rst)

        $compositeFrame = Overlay-ModalOnFrame -FrameLines $bgLines -ModalLines $modalLines -TermWidth $termW

        $sb = [System.Text.StringBuilder]::new()
        foreach ($line in $compositeFrame) {
            [void]$sb.AppendLine($line)
        }
        try { [Console]::SetCursorPosition(0, 0) } catch {}
        [Console]::Write("$esc[H")
        [Console]::Write($sb.ToString().Replace("`r`n", "$esc[K`r`n") + "$esc[K$esc[J")

        try { $k = Read-KeyOrResize } catch { return $false }
        if ($null -eq $k) { continue }

        if ($k.Key -eq "Y") { return $true }
        if ($k.Key -in @("N", "Escape", "Q")) { return $false }
    }
}

# Folder collapse state & Preferences (folders are expanded unless explicitly collapsed)
if ($null -eq $script:CollapsedFolders) { $script:CollapsedFolders = @{} }

$notesConfigFile = Join-Path $NotesDir ".config.json"
if (-not $script:SortMode) {
    $script:SortMode = "date"
    if (Test-Path -LiteralPath $notesConfigFile) {
        try {
            $cfg = Get-Content -LiteralPath $notesConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.SortMode -in @("date", "alpha")) { $script:SortMode = $cfg.SortMode }
        } catch {}
    }
}

# Per-run caches
$script:BannerCache     = @{}
$script:EditorResolved  = $false
$script:EditorPath      = $null
$script:ObsidianVaultId = $null
$script:LastActionPath  = $null   # Set by create/rename prompts so the browser can re-select the item

function Get-PreferredTerminalEditor {
    if ($script:EditorResolved) { return $script:EditorPath }

    $candidates = @(
        @{ Name = "hx";    Fallback = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Helix.Helix*\*\hx.exe" },
        @{ Name = "micro"; Fallback = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\zyedidia.micro*\*\micro.exe" },
        @{ Name = "nvim";  Fallback = "C:\Program Files\Neovim\bin\nvim.exe" },
        @{ Name = "nano";  Fallback = $null },
        @{ Name = "vim";   Fallback = $null }
    )

    $script:EditorPath = $null
    foreach ($c in $candidates) {
        $cmd = Get-Command $c.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Definition) { $script:EditorPath = $cmd.Definition; break }
        if ($IsWindows -and $c.Fallback) {
            $found = Resolve-Path $c.Fallback -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $script:EditorPath = $found.Path; break }
        }
    }

    $script:EditorResolved = $true
    return $script:EditorPath
}

function Register-ObsidianVault {
    if ($script:ObsidianVaultId) { return $script:ObsidianVaultId }

    $vaultId = "Notes"
    $obsidianConfig = if ($IsMacOS) { "$HOME/Library/Application Support/obsidian/obsidian.json" } else { "$env:APPDATA\obsidian\obsidian.json" }

    if (Test-Path -LiteralPath $obsidianConfig) {
        try {
            $json = Get-Content -LiteralPath $obsidianConfig -Raw -Encoding UTF8 | ConvertFrom-Json
            $foundId = $null
            foreach ($prop in $json.vaults.PSObject.Properties) {
                if ("$($prop.Value.path)".TrimEnd('\', '/') -eq $NotesDir) {
                    $foundId = $prop.Name
                    break
                }
            }

            if (-not $foundId) {
                $foundId = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
                $newVaultObj = [PSCustomObject]@{
                    path = $NotesDir
                    ts   = [int64]([System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
                }
                $json.vaults | Add-Member -MemberType NoteProperty -Name $foundId -Value $newVaultObj
                Write-Utf8File -Path $obsidianConfig -Text ($json | ConvertTo-Json -Depth 10)
            }

            $obsidianDir = Join-Path $NotesDir ".obsidian"
            if (-not (Test-Path -LiteralPath $obsidianDir)) {
                New-Item -ItemType Directory -Path $obsidianDir -Force | Out-Null
            }

            $vaultId = $foundId
        } catch {
            $vaultId = "Notes"
        }
    }

    $script:ObsidianVaultId = $vaultId
    return $vaultId
}

function Render-HeaderBanner([int]$width) {
    if (-not $script:BannerCache.ContainsKey($width)) {
        $sb = New-Object System.Text.StringBuilder
        $titleText = " T E R M I N A L   N O T E B O O K "
        $pad = " " * [Math]::Max(0, [int](($width - $titleText.Length) / 2))
        [void]$sb.AppendLine($pad + (Render-GradientText $titleText $gWaveOrange $gWaveAmber))

        $barWidth = [Math]::Max(10, $width - 2)
        [void]$sb.AppendLine(" " + (Render-AuroraWave $barWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2584)))
        $script:BannerCache[$width] = $sb.ToString().TrimEnd() + "`r`n"
    }
    return $script:BannerCache[$width]
}

function Switch-NotebookModal {
    Write-ModalHeader "NOTEBOOK WORKSPACES" -Color Cyan
    $cfg = Get-GlobalNotebookConfig
    $notebooks = @($cfg.Notebooks)

    Write-Host " Select a notebook workspace to switch to:`n" -ForegroundColor DarkGray

    for ($i = 0; $i -lt $notebooks.Count; $i++) {
        $nb = $notebooks[$i]
        $name = if ($nb.Name -and $nb.Name -ne "Default") { $nb.Name } else { Split-Path $nb.Path -Leaf }
        $friendlyPath = if ($nb.Path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
            "~" + $nb.Path.Substring($HOME.Length)
        } else {
            $nb.Path
        }
        $isActive = ($nb.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/'))
        $activeBadge = if ($isActive) { "$cOrange* (Active)$rst" } else { "" }
        $num = "[$($i + 1)]"
        Write-Host ("  $cOrange{0,-4}$rst $cFolder$gFolderClosed $cWhite{1,-16}$rst $cGray{2,-35}$rst $activeBadge" -f $num, $name, $friendlyPath)
    }

    Write-Host "`n  $cAmber[A]$rst Add new notebook path" -ForegroundColor White
    Write-Host "  $cWarn[R]$rst Remove notebook from list" -ForegroundColor White
    Write-Host "  $cGray[Q/Esc]$rst Cancel`n" -ForegroundColor White

    Write-Host "Choice (number/letter): " -ForegroundColor Yellow -NoNewline
    $inputChoice = Read-Host

    if (Test-CancelInput $inputChoice) { return }

    if ($inputChoice.Trim().ToUpper() -eq "A") {
        Write-Host "`nEnter Notebook Name (e.g., Work): " -ForegroundColor Yellow -NoNewline
        $name = Read-Host
        if (Test-CancelInput $name) { return }

        Write-Host "Enter Folder Path (e.g., C:\WorkNotes): " -ForegroundColor Yellow -NoNewline
        $path = Read-Host
        if (Test-CancelInput $path) { return }

        Set-ActiveNotebook -Target $path
        $cfg = Get-GlobalNotebookConfig
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $cfg.Notebooks) {
            if ($item.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/')) {
                $list.Add(@{ Name = $name.Trim(); Path = $script:NotesDir })
            } else {
                $list.Add($item)
            }
        }
        $cfg.Notebooks = $list.ToArray()
        Save-GlobalNotebookConfig $cfg
        Write-Host "`nSwitched to notebook: $name ($script:NotesDir)" -ForegroundColor Green
        Start-Sleep -Milliseconds 700
        return
    }

    if ($inputChoice.Trim().ToUpper() -eq "R") {
        if ($notebooks.Count -le 1) {
            Write-Host "`nCannot remove the only remaining notebook." -ForegroundColor Red
            Start-Sleep -Milliseconds 900
            return
        }
        Write-Host "`nEnter number of notebook to remove: " -ForegroundColor Yellow -NoNewline
        $remIdxStr = Read-Host
        if ($remIdxStr -match '^\d+$') {
            $remIdx = [int]$remIdxStr - 1
            if ($remIdx -ge 0 -and $remIdx -lt $notebooks.Count) {
                $targetRem = $notebooks[$remIdx]
                if ($targetRem.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/')) {
                    Write-Host "`nCannot remove the currently active notebook. Switch to another notebook first." -ForegroundColor Red
                    Start-Sleep -Milliseconds 1200
                    return
                }
                $list = [System.Collections.Generic.List[object]]::new()
                for ($k = 0; $k -lt $notebooks.Count; $k++) {
                    if ($k -ne $remIdx) { $list.Add($notebooks[$k]) }
                }
                $cfg.Notebooks = $list.ToArray()
                Save-GlobalNotebookConfig $cfg
                Write-Host "`nRemoved notebook: $($targetRem.Name)" -ForegroundColor Green
                Start-Sleep -Milliseconds 700
                return
            }
        }
        return
    }

    if ($inputChoice.Trim() -match '^\d+$') {
        $idx = [int]($inputChoice.Trim()) - 1
        if ($idx -ge 0 -and $idx -lt $notebooks.Count) {
            $selected = $notebooks[$idx]
            Set-ActiveNotebook -Target $selected.Path
            Write-Host "`nSwitched to notebook: $($selected.Name)" -ForegroundColor Green
            Start-Sleep -Milliseconds 600
        }
    }
}

# --- Notebook Browser ---

# Every hotkey shown in the nav bar. "When" limits an entry to Note/Folder selections or scrollable previews.
$NavSpec = @(
    @{ Key = "[W/S]";   Label = " Move " },
    @{ Key = "[A/D]";   Label = " Folders " },
    @{ Key = "[J/K]";   Label = " Scroll ";     When = "Scroll" },
    @{ Key = "[T]";     Label = " Sort " },
    @{ Key = "[B]";     Label = " Workspaces " },
    @{ Key = "[Enter]"; Label = " Expand ";     When = "Folder" },
    @{ Key = "[Enter]"; Label = " View ";       When = "Note" },
    @{ Key = "[V]";     Label = " Fullscreen "; When = "Note" },
    @{ Key = "[E]";     Label = " Edit ";       When = "Note" },
    @{ Key = "[O]";     Label = " Obsidian ";   When = "Note" },
    @{ Key = "[N]";     Label = " Note " },
    @{ Key = "[F]";     Label = " Folder " },
    @{ Key = "[U]";     Label = " Updates " },
    @{ Key = "[R]";     Label = " Rename " },
    @{ Key = "[X]";     Label = " Del " },
    @{ Key = "[Q]";     Label = " Exit" }
)

function Open-InObsidian {
    param([System.IO.FileInfo]$File)
    if (-not $File -or -not (Test-Path -LiteralPath $File.FullName)) { return }

    $targetVault = Register-ObsidianVault

    # Compute vault-relative path using forward slashes
    $relPath = (Get-RelativeNotePath $File.FullName).Replace('\', '/')
    $encodedFile = [System.Uri]::EscapeDataString($relPath)
    $uri = "obsidian://open?vault=$targetVault&file=$encodedFile"
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        if ($IsWindows) {
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c start `"`" `"$uri`""
        } else {
            $psi.FileName = "open"
            $psi.Arguments = "`"$uri`""
        }
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {}
}

function ConvertTo-WtArg([string]$Arg, [switch]$AlwaysQuote) {
    # wt.exe treats ';' as a command separator, so it must be escaped even inside quotes
    $a = $Arg -replace ';', '\;'
    if ($AlwaysQuote -or $a -match '\s') { return "`"$a`"" }
    return $a
}

function Invoke-TerminalEditor {
    param(
        [string]$EditorPath,
        [string]$FilePath,
        [switch]$GoToEnd
    )
    if (-not (Test-Path -LiteralPath $FilePath)) { return }

    $edLeaf = Split-Path $EditorPath -Leaf

    $lastLine = 1
    if ($GoToEnd) {
        $lastLine = [Math]::Max(1, [System.IO.File]::ReadAllText($FilePath).Split([char]10).Count)
    }

    $edArgs = @()
    if ($edLeaf -match 'micro') {
        $edArgs += @("-colorscheme", "simple", "-softwrap", "true", "-wordwrap", "true", $FilePath)
        if ($GoToEnd) { $edArgs += "+$lastLine" }
    } else {
        if ($GoToEnd -and $edLeaf -match 'hx|vim|nano') { $edArgs += "+$lastLine" }
        $edArgs += $FilePath
    }

    # Version 2.0: Windows Terminal Seamless Split-Pane Editing
    if ($env:WT_SESSION) {
        # We are inside modern Windows Terminal. Split the pane vertically so the user keeps the tree visible!
        $wtArgsString = "-w 0 split-pane -V " + (ConvertTo-WtArg $EditorPath -AlwaysQuote) + " " +
                        (($edArgs | ForEach-Object { ConvertTo-WtArg $_ }) -join " ")
        Start-Process -FilePath "wt.exe" -ArgumentList $wtArgsString

        # Sleep to allow Windows Terminal to complete the PTY split and resize event.
        # This prevents the Notebook Browser from re-rendering the UI with the old full width,
        # which would cause catastrophic line wrapping as the window shrinks!
        Start-Sleep -Milliseconds 800

        # Return instantly. The left pane (Terminal Notebook) stays fully interactive while the right pane edits!
        return
    }

    # Fallback for old consolehost / macOS: block and run in-place.
    # NOTE: callers must never capture this function's output (e.g. $x = ...), or the editor loses its TTY.
    & $EditorPath @edArgs
}

# --- Note Discovery & Sorting ---
$DateSortKey = {
    if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})') {
        $matches[1] + " " + $_.CreationTime.ToString("HH:mm:ss")
    } else {
        $_.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Sort-NoteFiles($Files) {
    if ($script:SortMode -eq "alpha") { return $Files | Sort-Object { Format-NoteTitle $_ } }
    return $Files | Sort-Object $DateSortKey -Descending
}

function Sort-NoteFolders($Dirs) {
    if ($script:SortMode -eq "alpha") { return $Dirs | Sort-Object Name }
    return $Dirs | Sort-Object CreationTime -Descending
}

function Get-NoteFolders {
    return @(Get-ChildItem -LiteralPath $script:NotesDir -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludedDirPattern })
}

function Get-AllNotes {
    $raw = Get-ChildItem -LiteralPath $script:NotesDir -Filter "*.md" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludedDirPattern }
    return @(Sort-NoteFiles $raw)
}

function Format-NoteTitle {
    param([System.IO.FileInfo]$File)
    $name = $File.BaseName
    if ($name -match '^\d{4}-\d{2}-\d{2}-(.+)$') {
        return ($matches[1] -replace '-', ' ')
    }
    return ($name -replace '-', ' ')
}

function Truncate-String {
    param([string]$Str, [int]$MaxLen)
    if ([string]::IsNullOrEmpty($Str) -or $MaxLen -le 0) { return "" }
    if ($Str.Length -le $MaxLen) { return $Str }
    if ($MaxLen -le 3) { return $Str.Substring(0, $MaxLen) }
    return $Str.Substring(0, $MaxLen - 3) + "..."
}

function Limit-AnsiText([string]$Text, [int]$Width) {
    # Truncates to $Width visible characters while keeping ANSI color sequences intact
    $sb = [System.Text.StringBuilder]::new()
    $visible = 0
    $i = 0
    while ($i -lt $Text.Length -and $visible -lt $Width) {
        $m = $AnsiTokenRegex.Match($Text, $i)
        if ($m.Success) {
            [void]$sb.Append($m.Value)
            $i += $m.Length
        } else {
            [void]$sb.Append($Text[$i])
            $visible++
            $i++
        }
    }
    return $sb.ToString()
}

function Format-AnsiCell([string]$Text, [int]$Width) {
    # Fits an ANSI-colored line into exactly $Width visible columns (truncating or padding)
    if ([string]::IsNullOrEmpty($Text)) { return " " * $Width }
    $visible = $AnsiRegex.Replace($Text, '').Length
    if ($visible -gt $Width) { return (Limit-AnsiText $Text $Width) + $rst }
    return $Text + $rst + (" " * ($Width - $visible))
}

function Format-WordWrap {
    param(
        [string]$Text,
        [int]$Width = 80
    )

    if ([string]::IsNullOrEmpty($Text)) { return @("") }
    if ($Text.Length -le $Width) { return @($Text) }

    $wrappedLines = [System.Collections.Generic.List[string]]::new()
    $currentLine = ""

    foreach ($w in ($Text -split '\s+')) {
        if ([string]::IsNullOrEmpty($w)) { continue }
        if ([string]::IsNullOrEmpty($currentLine)) {
            $currentLine = $w
        } elseif (($currentLine.Length + 1 + $w.Length) -le $Width) {
            $currentLine += " " + $w
        } else {
            $wrappedLines.Add($currentLine)
            while ($w.Length -gt $Width) {
                $wrappedLines.Add($w.Substring(0, $Width))
                $w = $w.Substring($Width)
            }
            $currentLine = $w
        }
    }

    if (-not [string]::IsNullOrEmpty($currentLine)) {
        $wrappedLines.Add($currentLine)
    }

    return $wrappedLines.ToArray()
}

# --- Obsidian-Style Terminal Markdown Engine ---
function Format-MarkdownInline {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return "" }

    # 1. Inline code: `code` - swapped for placeholders first so no other rule touches code contents
    $codeSpans = [System.Collections.Generic.List[string]]::new()
    $res = [regex]::Replace($Text, '`([^`]+)`', {
        param($m)
        $codeSpans.Add("$cCodeBg$cAmber $($m.Groups[1].Value) $rst$cSilver")
        return "$([char]1)$($codeSpans.Count - 1)$([char]1)"
    })

    # 2. Obsidian WikiLinks: [[Target]] or [[Target|Label]]
    $res = [regex]::Replace($res, '\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]', {
        param($m)
        $label = if ($m.Groups[2].Success -and -not [string]::IsNullOrEmpty($m.Groups[2].Value)) { $m.Groups[2].Value } else { $m.Groups[1].Value }
        return "$cAmber[[$cOrange$label$cAmber]]$rst$cSilver"
    })

    # 3. Standard Markdown Links: [Label](url)
    $res = [regex]::Replace($res, '\[([^\]]+)\]\(([^)]+)\)', {
        param($m)
        return "$cOrange$($m.Groups[1].Value)$cDarkGray$uArrowUpR$rst$cSilver"
    })

    # 4. Bold: **text** or __text__ (underscores must not be inside a word, e.g. snake__case)
    $res = [regex]::Replace($res, '\*\*(?<b>.+?)\*\*|(?<!\w)__(?<b>.+?)__(?!\w)', {
        param($m)
        return "$cWhite$sBold$($m.Groups['b'].Value)$sNoBold$cSilver"
    })

    # 5. Obsidian Highlight: ==text==
    $res = [regex]::Replace($res, '==(.*?)==', {
        param($m)
        return "$cHighlightBg$cOrange $($m.Groups[1].Value) $rst$cSilver"
    })

    # 6. Italic: *text*
    $res = [regex]::Replace($res, '(?<!\*)\*([^\*]+)\*(?!\*)', {
        param($m)
        return "$sItalic$($m.Groups[1].Value)$sNoItalic"
    })

    # 7. Strikethrough: ~~text~~
    $res = [regex]::Replace($res, '~~(.*?)~~', {
        param($m)
        return "$cGray$sStrike$($m.Groups[1].Value)$sNoStrike$cSilver"
    })

    # Restore protected code spans
    if ($codeSpans.Count -gt 0) {
        $res = [regex]::Replace($res, '\x01(\d+)\x01', {
            param($m)
            return $codeSpans[[int]$m.Groups[1].Value]
        })
    }

    return $res
}

function Convert-MarkdownToTerminalLines {
    param(
        [string[]]$RawLines,
        [int]$Width = 80
    )

    if (-not $RawLines -or $RawLines.Count -eq 0) { return @() }

    $out = [System.Collections.Generic.List[string]]::new()
    $boxW = [Math]::Max(20, $Width - 2)
    $inCodeBlock = $false
    $activeCalloutColor = $null
    $lineIdx = 0

    function Add-BlankLine {
        if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne "") { $out.Add("") }
    }

    # Word-wraps $Text and emits it with a first-line prefix and a continuation prefix
    function Add-Wrapped([string]$Text, [int]$WrapWidth, [string]$FirstPrefix, [string]$ContPrefix, [string]$Style = "", [string]$StyleEnd = "") {
        $wrapped = @(Format-WordWrap -Text $Text -Width $WrapWidth)
        for ($k = 0; $k -lt $wrapped.Count; $k++) {
            $prefix = if ($k -eq 0) { $FirstPrefix } else { $ContPrefix }
            $out.Add($prefix + $Style + (Format-MarkdownInline $wrapped[$k]) + $StyleEnd + $rst)
        }
    }

    # 1. Parse YAML Frontmatter / Obsidian Properties Card
    if ($RawLines[0].Trim() -eq "---") {
        $frontmatter = [System.Collections.Generic.List[string]]::new()
        $lineIdx = 1
        while ($lineIdx -lt $RawLines.Count) {
            $fLine = $RawLines[$lineIdx]
            $lineIdx++
            if ($fLine.Trim() -eq "---") { break }
            $frontmatter.Add($fLine)
        }

        if ($frontmatter.Count -gt 0) {
            $out.Add((New-BoxTop " Properties " $boxW))

            foreach ($fl in $frontmatter) {
                if ($fl -match '^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)') {
                    $keyPad = "{0,-8}" -f $matches[1]
                    $valDisp = $matches[2].Trim('"', "'", ' ')
                    if ($valDisp.Length -gt ($boxW - 14)) { $valDisp = $valDisp.Substring(0, $boxW - 17) + "..." }
                    $pad = " " * [Math]::Max(0, $boxW - 2 - (11 + $valDisp.Length))
                    $out.Add(" " + $barLeft + " " + $cGray + $keyPad + $cDarkGray + ": " + $cWhite + (Format-MarkdownInline $valDisp) + $pad + $barRight)
                } elseif ($fl -match '^\s*-\s+(.*)') {
                    $itemText = $matches[1]
                    if ($itemText.Length -gt ($boxW - 11)) { $itemText = $itemText.Substring(0, $boxW - 14) + "..." }
                    $pad = " " * [Math]::Max(0, $boxW - 2 - (5 + $itemText.Length))
                    $out.Add(" " + $barLeft + "   " + $cAmber + "$uBullet " + $cSilver + (Format-MarkdownInline $itemText) + $pad + $barRight)
                }
            }

            $out.Add((New-BoxBottom $boxW))
            $out.Add("")
        }
    }

    for ($i = $lineIdx; $i -lt $RawLines.Count; $i++) {
        $line = $RawLines[$i]

        # Fenced Code Blocks (```powershell)
        if ($line -match '^\s*```([A-Za-z0-9_-]*)') {
            if (-not $inCodeBlock) {
                $inCodeBlock = $true
                $tag = if ($matches[1]) { " $($matches[1]) " } else { " Code " }
                $out.Add((New-BoxTop $tag $boxW))
            } else {
                $inCodeBlock = $false
                $out.Add((New-BoxBottom $boxW))
            }
            continue
        }

        if ($inCodeBlock) {
            $codeStr = $line
            if ($codeStr.Length -gt ($boxW - 4)) { $codeStr = $codeStr.Substring(0, $boxW - 4) }
            $pad = " " * [Math]::Max(0, $boxW - 4 - $codeStr.Length)
            $out.Add(" " + $barLeft + " " + $cAmber + $codeStr + $pad + " " + $barRight)
            continue
        }

        # Obsidian Callouts: > [!NOTE] or > [!TIP]
        if ($line -match '^\s*>\s*\[!([A-Za-z0-9_-]+)\]\s*(.*)') {
            $cType = $matches[1].ToUpper()
            $cTitle = $matches[2]
            $activeCalloutColor = switch ($cType) {
                { $_ -in @("TIP", "HINT", "SUCCESS", "DONE") }      { $cAmber }
                { $_ -in @("WARNING", "CAUTION", "DANGER", "BUG") } { $cWarn }
                { $_ -in @("TODO", "QUESTION", "HELP") }            { $cSilver }
                default                                             { $cOrange }
            }
            $hdr = if ($cTitle) { "$cType - $cTitle" } else { $cType }
            $out.Add(" " + $activeCalloutColor + "$uBar " + $cWhite + $sBold + $hdr + $sNoBold + $rst)
            continue
        }

        if ($activeCalloutColor -and $line -match '^\s*>\s*(.*)') {
            Add-Wrapped $matches[1] ($Width - 5) (" " + $activeCalloutColor + "$uBar " + $cSilver) (" " + $activeCalloutColor + "$uBar " + $cSilver)
            continue
        }
        $activeCalloutColor = $null

        # Standard Blockquotes
        if ($line -match '^\s*>\s*(.*)') {
            $quotePrefix = " " + $barLeft + " " + $sItalic + $cSilver
            Add-Wrapped $matches[1] ($Width - 5) $quotePrefix $quotePrefix "" $sNoItalic
            continue
        }

        # Checklists / Tasks
        if ($line -match '^\s*-\s+\[\s\]\s+(.*)') {
            Add-Wrapped $matches[1] ($Width - 6) ("  " + $cOrange + "$uBoxUncheck " + $cWhite) ("    " + $cSilver)
            continue
        }

        if ($line -match '^\s*-\s+\[[xX]\]\s+(.*)') {
            Add-Wrapped $matches[1] ($Width - 6) ("  " + $cAmber + "$uCheckMark " + $cGray) ("    " + $cGray) $sStrike $sNoStrike
            continue
        }

        # Headings (# through ####)
        if ($line -match '^(#{1,4})\s+(.*)') {
            $hLevel = $matches[1].Length
            $hText = Format-MarkdownInline $matches[2]
            switch ($hLevel) {
                1 {
                    Add-BlankLine
                    $out.Add(" " + $cOrange + "# " + $cWhite + $sBold + $hText + $sNoBold + $rst)
                    $divLen = [Math]::Min($Width - 2, [Math]::Max(12, $matches[2].Length + 4))
                    $out.Add(" " + (Render-GradientText ($bHoriz * $divLen) $gWaveOrange $gWaveDark))
                }
                2 {
                    Add-BlankLine
                    $out.Add(" " + $cOrange + "## " + $cWhite + $sBold + $hText + $sNoBold + $rst)
                }
                3 {
                    Add-BlankLine
                    $out.Add(" " + $cAmber + "### " + $cSilver + $sBold + $hText + $sNoBold + $rst)
                }
                4 {
                    $out.Add(" " + $cGray + "#### " + $cSilver + $hText + $rst)
                }
            }
            continue
        }

        # Markdown Tables: | Col1 | Col2 |
        if ($line -match '^\s*\|(.+)\|\s*$') {
            $inner = $matches[1]
            if ($inner -match '^[\s\-:|]+$') {
                $midLen = [Math]::Min($Width - 4, 45)
                $out.Add(" " + (Render-GradientText ($uMidLeft + ($bHoriz * $midLen) + $uMidRight) $gWaveOrange $gWaveDark))
            } else {
                $cells = foreach ($cell in ($inner -split '\|')) { Format-MarkdownInline $cell.Trim() }
                $out.Add(" " + $barLeft + " " + ($cells -join (" " + $barLeft + " ")) + " " + $barRight)
            }
            continue
        }

        # Horizontal Rules
        if ($line -match '^(---|\*\*\*|___)\s*$') {
            $hrLen = [Math]::Min(50, $Width - 2)
            $out.Add(" " + (Render-GradientText ($bHoriz * $hrLen) $gWaveOrange $gWaveDark))
            continue
        }

        # Bullet Lists
        if ($line -match '^\s*[-*+]\s+(.*)') {
            Add-Wrapped $matches[1] ($Width - 5) ("  " + $cAmber + "$uBullet " + $cSilver) ("    " + $cSilver)
            continue
        }

        # Numbered Lists
        if ($line -match '^\s*(\d+\.)\s+(.*)') {
            Add-Wrapped $matches[2] ($Width - 6) ("  " + $cOrange + $matches[1] + " " + $cSilver) ("     " + $cSilver)
            continue
        }

        # Empty line
        if ([string]::IsNullOrWhiteSpace($line)) {
            Add-BlankLine
            continue
        }

        # Regular Paragraph
        Add-Wrapped $line ($Width - 2) (" " + $cSilver) (" " + $cSilver)
    }

    return $out.ToArray()
}

# --- Notebook Index (single disk scan) & Tree Builder ---
function Get-NotebookIndex {
    # One recursive pass collects every folder and note, then aggregates recursive note counts per folder.
    $root = (Get-Item -LiteralPath $NotesDir).FullName
    $childDirs  = @{}   # parent path -> List of DirectoryInfo
    $childFiles = @{}   # parent path -> List of FileInfo
    $noteCounts = @{}   # folder path -> recursive .md count

    foreach ($d in (Get-NoteFolders)) {
        $parent = $d.Parent.FullName
        if (-not $childDirs.ContainsKey($parent)) { $childDirs[$parent] = [System.Collections.Generic.List[object]]::new() }
        $childDirs[$parent].Add($d)
    }

    $files = Get-ChildItem -LiteralPath $root -Filter "*.md" -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $ExcludedDirPattern }
    foreach ($f in $files) {
        $dir = $f.DirectoryName
        if (-not $childFiles.ContainsKey($dir)) { $childFiles[$dir] = [System.Collections.Generic.List[object]]::new() }
        $childFiles[$dir].Add($f)

        while ($dir -and $dir.Length -gt $root.Length) {
            $noteCounts[$dir] = [int]$noteCounts[$dir] + 1
            $dir = [System.IO.Path]::GetDirectoryName($dir)
        }
    }

    return @{ Root = $root; ChildDirs = $childDirs; ChildFiles = $childFiles; NoteCounts = $noteCounts }
}

function Add-TreeItems {
    # Appends the visible (expanded) hierarchy under $Path to the $Items list
    param(
        [hashtable]$Index,
        [string]$Path,
        [int]$Level,
        $Items,
        [bool[]]$AncestorsHasNext = @()
    )

    # 1. Direct Markdown files in this directory (sorted by SortMode: date or alpha)
    $files = @(Sort-NoteFiles $Index.ChildFiles[$Path])

    # 2. Direct Subfolders in this directory (sorted by SortMode: date or alpha)
    $subDirs = @(Sort-NoteFolders $Index.ChildDirs[$Path])

    # Add Spacer at root (Level 0) if we have both root notes and root subfolders
    if ($Level -eq 0 -and $subDirs.Count -gt 0 -and $files.Count -gt 0) {
        for ($i = 0; $i -lt $files.Count; $i++) {
            $f = $files[$i]
            $Items.Add([PSCustomObject]@{
                Type             = "Note"
                Name             = (Format-NoteTitle $f)
                FileName         = $f.Name
                FullName         = $f.FullName
                Level            = 0
                IsLastSibling    = ($i -eq $files.Count - 1)
                AncestorsHasNext = @()
            })
        }

        $Items.Add([PSCustomObject]@{
            Type             = "Spacer"
            Name             = ""
            FullName         = ""
            Level            = 0
            IsExpanded       = $false
            ItemCount        = 0
            IsLastSibling    = $false
            AncestorsHasNext = @()
        })

        for ($dIdx = 0; $dIdx -lt $subDirs.Count; $dIdx++) {
            $d = $subDirs[$dIdx]
            $isExpanded = -not $script:CollapsedFolders.ContainsKey($d.FullName)
            $isLast = ($dIdx -eq $subDirs.Count - 1)
            $Items.Add([PSCustomObject]@{
                Type             = "Folder"
                Name             = $d.Name
                FullName         = $d.FullName
                Level            = 0
                IsExpanded       = $isExpanded
                ItemCount        = [int]$Index.NoteCounts[$d.FullName]
                IsLastSibling    = $isLast
                AncestorsHasNext = @()
            })

            if ($isExpanded) {
                $nextAncestors = @(-not $isLast)
                Add-TreeItems -Index $Index -Path $d.FullName -Level 1 -Items $Items -AncestorsHasNext $nextAncestors
            }
        }
        return
    }

    $totalChildren = $files.Count + $subDirs.Count
    $childIdx = 0

    # Direct Notes first (displayed indented right after folder that contains them)
    for ($i = 0; $i -lt $files.Count; $i++) {
        $f = $files[$i]
        $isLast = ($childIdx -eq ($totalChildren - 1))
        $Items.Add([PSCustomObject]@{
            Type             = "Note"
            Name             = (Format-NoteTitle $f)
            FileName         = $f.Name
            FullName         = $f.FullName
            Level            = $Level
            IsLastSibling    = $isLast
            AncestorsHasNext = $AncestorsHasNext
        })
        $childIdx++
    }

    # Direct Subfolders
    for ($dIdx = 0; $dIdx -lt $subDirs.Count; $dIdx++) {
        $d = $subDirs[$dIdx]
        $isExpanded = -not $script:CollapsedFolders.ContainsKey($d.FullName)
        $isLast = ($childIdx -eq ($totalChildren - 1))
        $Items.Add([PSCustomObject]@{
            Type             = "Folder"
            Name             = $d.Name
            FullName         = $d.FullName
            Level            = $Level
            IsExpanded       = $isExpanded
            ItemCount        = [int]$Index.NoteCounts[$d.FullName]
            IsLastSibling    = $isLast
            AncestorsHasNext = $AncestorsHasNext
        })
        $childIdx++

        if ($isExpanded) {
            $nextAncestors = $AncestorsHasNext + (-not $isLast)
            Add-TreeItems -Index $Index -Path $d.FullName -Level ($Level + 1) -Items $Items -AncestorsHasNext $nextAncestors
        }
    }
}

function Get-FolderPreviewLines {
    param($Item, [hashtable]$Index, [int]$UsableWidth)

    $lines = [System.Collections.Generic.List[string]]::new()
    $telemetryWidth = [Math]::Max(20, $UsableWidth - 2)

    # Reverse gradient: Orange to DarkGray
    $lines.Add((New-BoxTop " Folder Telemetry " $telemetryWidth))

    $statusStr = if ($Item.IsExpanded) { "Open [v]" } else { "Closed [>]" }
    $noteCountStr = if ($Item.ItemCount -gt 0) { "$($Item.ItemCount) note(s)" } else { "0 notes (empty)" }
    $relPath = Get-RelativeNotePath $Item.FullName
    if ([string]::IsNullOrEmpty($relPath)) { $relPath = "/" }

    $rows = @(
        @("Folder",   (Truncate-String $Item.Name ($telemetryWidth - 15)),                $cWhite),
        @("Status",   $statusStr,                                                         $cOrange),
        @("Contents", $noteCountStr,                                                      $cWhite),
        @("Path",     (Truncate-String ("~/Notes/" + $relPath) ($telemetryWidth - 15)),   $cGray)
    )
    foreach ($row in $rows) {
        $lbl = $row[0].PadRight(10)
        $val = $row[1]
        $pad = " " * [Math]::Max(0, $telemetryWidth - 2 - (" " + $lbl + ": " + $val).Length)
        $lines.Add(" " + $barLeft + $cGray + " " + $lbl + ": " + $row[2] + $val + $rst + $pad + $barRight)
    }

    $lines.Add((New-BoxBottom $telemetryWidth))
    $lines.Add("")

    $lines.Add(" " + $cOrange + "Notes Inside:" + $rst)
    $folderFiles = $Index.ChildFiles[$Item.FullName]
    if ($folderFiles -and $folderFiles.Count -gt 0) {
        foreach ($ff in $folderFiles) {
            $lines.Add("   " + $cWhite + "* " + (Format-NoteTitle $ff) + $rst)
        }
    } else {
        $lines.Add("   " + $cGray + "*(No notes yet in this folder)*" + $rst)
    }

    $lines.Add("")
    $lines.Add("  " + $cOrange + "Folder Actions:" + $rst)
    if ($UsableWidth -lt 55) {
        $lines.Add("    " + $cOrange + "[W/S] " + $cSilver + "Move  " + $cOrange + "[A/D] " + $cSilver + "Folders" + $rst)
        $lines.Add("    " + $cOrange + "[R] " + $cSilver + "Rename  " + $cOrange + "[X] " + $cSilver + "Delete" + $rst)
    } else {
        $lines.Add("    " + $cOrange + "[W/S] " + $cSilver + "Move  " + $cOrange + "[A/D] " + $cSilver + "Folders  " + $cOrange + "[R] " + $cSilver + "Rename  " + $cOrange + "[X] " + $cSilver + "Delete" + $rst)
    }

    return $lines.ToArray()
}

# --- Interactive Prompts ---
function Select-NotesFolder {
    # Numbered folder picker. Returns the chosen folder path (defaults to the notebook root).
    param([string]$Prompt)

    $dirs = @(Get-NoteFolders)
    if ($dirs.Count -eq 0) { return $NotesDir }

    Write-Host $Prompt -ForegroundColor DarkGray
    Write-Host "  [1] / (Root ~/Notes)" -ForegroundColor White
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        Write-Host ("  [{0}] {1}/" -f ($i + 2), (Get-RelativeNotePath $dirs[$i].FullName)) -ForegroundColor White
    }
    Write-Host "Choice (press Enter for 1): " -ForegroundColor White -NoNewline
    $choice = Read-Host
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 2
        if ($idx -ge 0 -and $idx -lt $dirs.Count) { return $dirs[$idx].FullName }
    }
    return $NotesDir
}

function Write-InvalidNameMessage {
    Write-Host "That name has no usable letters or numbers." -ForegroundColor Red
    Start-Sleep -Milliseconds 800
}

# --- Folder Creation Prompt ---
function New-FolderPrompt {
    param(
        [string]$ParentDir = "",
        [scriptblock]$RenderBgBlock = $null
    )

    $script:LastActionPath = $null
    $targetParent = $NotesDir

    if (-not [string]::IsNullOrWhiteSpace($ParentDir) -and (Test-Path -LiteralPath $ParentDir)) {
        $targetParent = $ParentDir
    }

    if ($RenderBgBlock) {
        $relPath = Get-RelativeNotePath $targetParent
        $sub = if ($relPath) { "Location: ~/Notes/$relPath" } else { "Location: ~/Notes" }
        $folderName = Show-InlineInputModal -Title "CREATE NEW FOLDER" -Subtitle $sub -PromptLabel "Folder Name:" -ConfirmActionLabel "Create" -RenderBgBlock $RenderBgBlock

        if ([string]::IsNullOrWhiteSpace($folderName)) { return }

        $safeName = ConvertTo-Slug $folderName
        if (-not $safeName) { return }
        $newFolderPath = Join-Path $targetParent $safeName

        if (Test-Path -LiteralPath $newFolderPath) { return }

        [void][System.IO.Directory]::CreateDirectory($newFolderPath)
        $script:LastActionPath = $newFolderPath
        return
    }

    Write-ModalHeader "CREATE NEW FOLDER"
    Write-Host " Parent: ~/Notes/$(Get-RelativeNotePath $targetParent)" -ForegroundColor Gray
    Write-Host " Tip: Press Enter without a name or 'c' to cancel`n" -ForegroundColor DarkGray

    if ([string]::IsNullOrWhiteSpace($ParentDir)) {
        $targetParent = Select-NotesFolder "Where would you like to create this folder?"
    }

    Write-Host "`nEnter Folder Name: " -ForegroundColor White -NoNewline
    $folderName = Read-Host

    if (Test-CancelInput $folderName) {
        Write-Host "Folder creation cancelled." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 600
        return
    }

    $safeName = ConvertTo-Slug $folderName
    if (-not $safeName) { Write-InvalidNameMessage; return }
    $newFolderPath = Join-Path $targetParent $safeName

    if (Test-Path -LiteralPath $newFolderPath) {
        Write-Host "Folder already exists: $safeName" -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        return
    }

    [void][System.IO.Directory]::CreateDirectory($newFolderPath)
    $script:LastActionPath = $newFolderPath
    Write-Host "`nCreated folder: $safeName" -ForegroundColor Green
    Start-Sleep -Milliseconds 700
}

# --- Rename Prompt (Folder or Note) ---
function Rename-ItemPrompt {
    param(
        $Item,
        [scriptblock]$RenderBgBlock = $null
    )
    if (-not $Item -or -not (Test-Path -LiteralPath $Item.FullName)) { return }

    $script:LastActionPath = $null
    $isFolder = $Item.Type -eq "Folder"
    $noun = if ($isFolder) { "folder" } else { "note" }

    if ($RenderBgBlock) {
        $initName = if ($isFolder) { $Item.Name } else { $Item.BaseName }
        $newName = Show-InlineInputModal -Title "RENAME ITEM" -Subtitle "Current: $($Item.Name)" -PromptLabel "New Name:" -InitialValue $initName -ConfirmActionLabel "Rename" -RenderBgBlock $RenderBgBlock

        if ([string]::IsNullOrWhiteSpace($newName)) { return }

        $safeName = if ($isFolder) { ConvertTo-Slug $newName } else { ConvertTo-Slug $newName -Lower }
        if (-not $safeName) { return }
        if (-not $isFolder) { $safeName += ".md" }

        $newPath = Join-Path (Split-Path $Item.FullName -Parent) $safeName
        if (Test-Path -LiteralPath $newPath) { return }

        Rename-Item -LiteralPath $Item.FullName -NewName $safeName
        if ($isFolder -and $script:CollapsedFolders.ContainsKey($Item.FullName)) {
            $script:CollapsedFolders.Remove($Item.FullName)
            $script:CollapsedFolders[$newPath] = $true
        }
        $script:LastActionPath = $newPath
        return
    }

    Write-ModalHeader "RENAME" -Color Cyan
    Write-Host " Current: $($Item.Name)`n" -ForegroundColor Yellow

    $prompt = if ($isFolder) { "Enter new folder name (or 'c' to cancel): " } else { "Enter new note title (or 'c' to cancel): " }
    Write-Host $prompt -ForegroundColor Yellow -NoNewline
    $newName = Read-Host
    if (Test-CancelInput $newName) {
        Write-Host "Rename cancelled." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 500
        return
    }

    $safeName = if ($isFolder) { ConvertTo-Slug $newName } else { ConvertTo-Slug $newName -Lower }
    if (-not $safeName) { Write-InvalidNameMessage; return }
    if (-not $isFolder) { $safeName += ".md" }

    $newPath = Join-Path (Split-Path $Item.FullName -Parent) $safeName
    if (Test-Path -LiteralPath $newPath) {
        Write-Host "A $noun with that name already exists." -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        return
    }

    Rename-Item -LiteralPath $Item.FullName -NewName $safeName
    if ($isFolder -and $script:CollapsedFolders.ContainsKey($Item.FullName)) {
        $script:CollapsedFolders.Remove($Item.FullName)
        $script:CollapsedFolders[$newPath] = $true
    }
    $script:LastActionPath = $newPath
    Write-Host "`nRenamed $noun to: $safeName" -ForegroundColor Green
    Start-Sleep -Milliseconds 600
}

# --- Delete Prompt (Folder or Note) ---
function Delete-ItemPrompt {
    param(
        $Item,
        [scriptblock]$RenderBgBlock = $null
    )
    if (-not $Item -or -not (Test-Path -LiteralPath $Item.FullName)) { return }

    if ($RenderBgBlock) {
        $warnSub = ""
        if ($Item.Type -eq "Folder") {
            $childCount = @(Get-ChildItem -LiteralPath $Item.FullName -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue).Count
            if ($childCount -gt 0) { $warnSub = "[!] WARNING: Contains $childCount note(s)!" }
        }

        $confirmed = Show-InlineConfirmModal -Title "DELETE ITEM" -Message "Delete $($Item.Type.ToLower()) '$($Item.Name)'?" -SubMessage $warnSub -ConfirmLabel "Delete" -RenderBgBlock $RenderBgBlock

        if ($confirmed) {
            Remove-Item -LiteralPath $Item.FullName -Recurse -Force
            $script:CollapsedFolders.Remove($Item.FullName)
        }
        return
    }

    Write-ModalHeader "DELETE ITEM" -Color Red
    Write-Host ""

    if ($Item.Type -eq "Folder") {
        $childCount = @(Get-ChildItem -LiteralPath $Item.FullName -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue).Count
        if ($childCount -gt 0) {
            Write-Host " [!] WARNING: Folder '$($Item.Name)' contains $childCount note(s)!" -ForegroundColor Yellow -BackgroundColor DarkRed
            Write-Host "`n Are you SURE you want to delete this folder and ALL its notes? (y/N): " -ForegroundColor Red -NoNewline
        } else {
            Write-Host " [!] DELETE EMPTY FOLDER: '$($Item.Name)'" -ForegroundColor Yellow -BackgroundColor DarkRed
            Write-Host "`n Are you sure you want to delete this empty folder? (y/N): " -ForegroundColor Red -NoNewline
        }
        $label = "Folder deleted: $($Item.Name)"
    } else {
        Write-Host " [!] DELETE NOTE: '$($Item.FileName)'" -ForegroundColor Yellow -BackgroundColor DarkRed
        Write-Host "`n Are you sure you want to delete this note? (y/N): " -ForegroundColor Red -NoNewline
        $label = "Note deleted: $($Item.FileName)"
    }

    $confirm = Read-Host
    if ($confirm.Trim().ToLower() -in @("y", "yes")) {
        Remove-Item -LiteralPath $Item.FullName -Recurse -Force
        $script:CollapsedFolders.Remove($Item.FullName)
        Write-Host "`n $label" -ForegroundColor Yellow
        Start-Sleep -Milliseconds 600
    } else {
        Write-Host "`n Deletion cancelled." -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 400
    }
}

function New-InteractiveNote {
    param(
        [string]$InitialTitle = "",
        [string]$DestinationDir = "",
        [scriptblock]$RenderBgBlock = $null
    )

    $script:LastActionPath = $null
    $targetDir = $NotesDir
    $skipFolderPrompt = $false
    if (-not [string]::IsNullOrWhiteSpace($DestinationDir) -and (Test-Path -LiteralPath $DestinationDir)) {
        $targetDir = $DestinationDir
        $skipFolderPrompt = $true
    }

    $title = $InitialTitle
    if ([string]::IsNullOrWhiteSpace($title) -and $RenderBgBlock) {
        $relPath = Get-RelativeNotePath $targetDir
        $sub = if ($relPath) { "Location: ~/Notes/$relPath" } else { "Location: ~/Notes" }
        $title = Show-InlineInputModal -Title "CREATE NEW NOTE" -Subtitle $sub -PromptLabel "Note Title:" -ConfirmActionLabel "Create & Edit" -RenderBgBlock $RenderBgBlock
    }

    if ([string]::IsNullOrWhiteSpace($title)) {
        if (-not $RenderBgBlock) {
            Write-ModalHeader "CREATE A NEW NOTE"
            Write-Host " Folder: ~/Notes/$(Get-RelativeNotePath $targetDir)" -ForegroundColor Gray
            Write-Host " Tip: Press Enter with an empty title or type 'c' to cancel`n" -ForegroundColor DarkGray

            Write-Host "Enter Note Title: " -ForegroundColor White -NoNewline
            $title = Read-Host
        }
    }

    if (Test-CancelInput $title) { return }

    $title = $title.Trim()
    $safeTitle = ConvertTo-Slug $title -Lower
    if (-not $safeTitle) { if (-not $RenderBgBlock) { Write-InvalidNameMessage }; return }

    # Only ask for destination folder if not already predetermined/contextual
    if (-not $skipFolderPrompt -and -not $RenderBgBlock) {
        $targetDir = Select-NotesFolder "`nWhere would you like to save this note?"
    }

    $datePrefix = (Get-Date).ToString("yyyy-MM-dd")
    $fileName = "$datePrefix-$safeTitle.md"
    $filePath = Join-Path $targetDir $fileName

    $count = 1
    while (Test-Path -LiteralPath $filePath) {
        $fileName = "$datePrefix-$safeTitle-$count.md"
        $filePath = Join-Path $targetDir $fileName
        $count++
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $yamlTitle = $title.Replace('\', '\\').Replace('"', '\"')
    $initialContent = "---`r`ntitle: `"$yamlTitle`"`r`ndate: $timestamp`r`ntags:`r`n  - note`r`n---`r`n`r`n# $title`r`n`r`n"
    Write-Utf8File -Path $filePath -Text ($initialContent + [Environment]::NewLine)
    $script:LastActionPath = $filePath

    $ed = Get-PreferredTerminalEditor
    if ($ed) {
        Invoke-TerminalEditor -EditorPath $ed -FilePath $filePath -GoToEnd
    } else {
        Open-InObsidian -File (Get-Item -LiteralPath $filePath)
    }
}

function Quick-Log {
    param(
        [string]$Text,
        [scriptblock]$RenderBgBlock = $null
    )

    if ([string]::IsNullOrWhiteSpace($Text) -and $RenderBgBlock) {
        $today = (Get-Date).ToString("yyyy-MM-dd")
        $fileName = "$today-quick-log.md"
        $Text = Show-InlineInputModal -Title "QUICK DAILY LOG" -Subtitle "Log File: $fileName" -PromptLabel "Quick Thought:" -ConfirmActionLabel "Save Log" -RenderBgBlock $RenderBgBlock
    }

    if ([string]::IsNullOrWhiteSpace($Text) -and -not $RenderBgBlock) {
        Write-Host "`nEnter quick thought (or press Enter to cancel): " -ForegroundColor Yellow -NoNewline
        $Text = Read-Host
    }

    if (Test-CancelInput $Text) { return }

    $today = (Get-Date).ToString("yyyy-MM-dd")
    $fileName = "$today-quick-log.md"
    $filePath = Join-Path $NotesDir $fileName
    $nl = [Environment]::NewLine

    if (-not (Test-Path -LiteralPath $filePath)) {
        Write-Utf8File -Path $filePath -Text ("# Daily Quick Log ($today)`r`n`r`n" + $nl)
    }

    $time = (Get-Date).ToString("HH:mm")
    Write-Utf8File -Path $filePath -Text ("- **[$time]** $Text" + $nl) -Append
    $script:LastActionPath = $filePath
    if (-not $RenderBgBlock) {
        Write-Host "Added to: $fileName" -ForegroundColor Green
        Start-Sleep -Milliseconds 800
    }
}

function Append-ToNote {
    param([System.IO.FileInfo]$File)
    if (-not $File -or -not (Test-Path -LiteralPath $File.FullName)) { return }

    Write-ModalHeader "APPEND TO: $($File.Name)" -Color Cyan
    Write-Host " Type your new lines below." -ForegroundColor DarkCyan
    Write-Host " (Press Enter on an empty line to finish, or ':cancel' to abort)`n" -ForegroundColor DarkGray

    $lines = [System.Collections.Generic.List[string]]::new()
    while ($true) {
        $line = Read-Host
        if ($line.Trim().ToLower() -in @(":c", ":cancel", ":q", ":abort")) {
            Write-Host "`nCancelled. Note unchanged." -ForegroundColor DarkYellow
            Start-Sleep -Milliseconds 600
            return
        }
        if ([string]::IsNullOrEmpty($line)) { break }
        $lines.Add($line)
    }

    if ($lines.Count -gt 0) {
        Write-Utf8File -Path $File.FullName -Text ("`r`n" + ($lines -join "`r`n") + [Environment]::NewLine) -Append
        Write-Host "`nAdded $($lines.Count) line(s) to $($File.Name)" -ForegroundColor Green
        Start-Sleep -Milliseconds 700
    }
}

function Edit-NoteFile {
    param([System.IO.FileInfo]$File)
    if (-not $File -or -not (Test-Path -LiteralPath $File.FullName)) { return }

    $terminalEditor = Get-PreferredTerminalEditor
    if ($terminalEditor) {
        Invoke-TerminalEditor -EditorPath $terminalEditor -FilePath $File.FullName -GoToEnd
    } else {
        Open-InObsidian -File $File
    }
}

function View-FullscreenNote {
    param(
        [System.IO.FileInfo]$File,
        [switch]$ReadOnly
    )
    if (-not $File -or -not (Test-Path -LiteralPath $File.FullName)) { return }

    $rawLines = @(Get-Content -LiteralPath $File.FullName -Encoding UTF8)
    $renderWidth = -1
    $scrollOffset = 0
    $needsClear = $true

    $footerKeys = $cOrange + "[Up/Dn/PgUp/PgDn]" + $cSilver + " Scroll  "
    if (-not $ReadOnly) {
        $footerKeys += $cOrange + "[E]" + $cSilver + " Edit  " +
                       $cOrange + "[O]" + $cSilver + " Obsidian  " +
                       $cOrange + "[P]" + $cSilver + " Append  "
    }
    $footerKeys += $cOrange + "[Q/Esc]" + $cSilver + " Return..."
    $modeTag = if ($ReadOnly) { " [Read-Only]" } else { "" }

    while ($true) {
        $termWidth = 99
        $termHeight = 26
        try {
            if ([Console]::WindowWidth -gt 50) { $termWidth = [Console]::WindowWidth - 1 }
            if ([Console]::WindowHeight -gt 15) { $termHeight = [Console]::WindowHeight }
        } catch {}

        # Reserved rows: Banner (2) + spacing (1) + Box Header (1) + Box Footer (1) + spacing (1) + Nav Legend (1) = 7 rows
        $boxHeight = [Math]::Max(5, $termHeight - 7)
        $viewHeight = [Math]::Max(1, $boxHeight - 2)

        # Re-wrap the document whenever the terminal width changes
        if ($termWidth -ne $renderWidth) {
            $textWidth = [Math]::Max(20, $termWidth - 4)
            $renderedLines = @(Convert-MarkdownToTerminalLines -RawLines $rawLines -Width $textWidth)
            $renderWidth = $termWidth
            $needsClear = $true
        }

        $maxScroll = [Math]::Max(0, $renderedLines.Count - $viewHeight)
        if ($scrollOffset -gt $maxScroll) { $scrollOffset = $maxScroll }
        $visEnd = [Math]::Min($renderedLines.Count, $scrollOffset + $viewHeight)

        # Assemble the whole frame in memory, then write it in one go (no flicker)
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine((Render-HeaderBanner $termWidth))

        # Outer Box Gradient Colors (Slate Gray -> Vivid Flame Orange)
        $cBorderStart = @(95, 100, 115)
        $cBorderEnd   = @(255, 130, 0)
        $topBorderColor = fg $cBorderStart[0] $cBorderStart[1] $cBorderStart[2]
        $botBorderColor = fg $cBorderEnd[0] $cBorderEnd[1] $cBorderEnd[2]

        $leftTitle = " FULLSCREEN READER: " + (Truncate-String $File.Name 40) + $modeTag
        $scrollNotice = ""
        if ($renderedLines.Count -gt $viewHeight) {
            $scrollNotice = " [$($scrollOffset + 1)-$visEnd of $($renderedLines.Count)] "
        }

        $availWidth = $termWidth - 2
        if ($leftTitle.Length + $scrollNotice.Length -gt $availWidth - 2) {
            $maxTitleLen = [Math]::Max(10, $availWidth - $scrollNotice.Length - 4)
            $leftTitle = Truncate-String -Str $leftTitle -MaxLen $maxTitleLen
        }
        $headerDashes = [Math]::Max(0, $availWidth - $leftTitle.Length - $scrollNotice.Length)

        [void]$sb.Append($topBorderColor + $uRoundTL + $bHoriz + $cOrange + $leftTitle + $topBorderColor + ($bHoriz * $headerDashes) + $cAmber + $scrollNotice + $topBorderColor + $uRoundTR + $rst + "`r`n")

        for ($r = 0; $r -lt $boxHeight; $r++) {
            $tRatio = ($r + 1) / ($boxHeight + 1.0)
            $rowRgb = Get-GradientColor $cBorderStart $cBorderEnd $tRatio
            $vBar = (fg $rowRgb[0] $rowRgb[1] $rowRgb[2]) + $bVert + $rst

            if ($r -eq 0 -or $r -eq ($boxHeight - 1)) {
                # Top & bottom padding rows inside box for visual breathing room
                [void]$sb.Append($vBar).Append(" " * ($termWidth - 2)).Append($vBar + "`r`n")
                continue
            }

            $idx = $scrollOffset + ($r - 1)
            $pLine = if ($idx -lt $renderedLines.Count) { $renderedLines[$idx] } else { "" }
            $cellStr = Format-AnsiCell $pLine ($termWidth - 4)
            [void]$sb.Append($vBar).Append(" ").Append($cellStr).Append(" ").Append($vBar + "`r`n")
        }

        # Box Footer Line
        [void]$sb.AppendLine($botBorderColor + $uRoundBL + ($bHoriz * ($termWidth - 2)) + $uRoundBR + $rst)

        # Nav Legend
        [void]$sb.Append(" " + $footerKeys + $rst + "$esc[J")

        if ($needsClear) {
            Clear-Host
            $needsClear = $false
        } else {
            try { [Console]::SetCursorPosition(0, 0) } catch {}
            [Console]::Write("$esc[H")
        }
        # Clear each line's tail so shorter lines don't leave remnants of the previous frame
        [Console]::Write($sb.ToString().Replace("`r`n", "$esc[K`r`n"))

        try { $k = Read-KeyOrResize } catch { break }
        if ($null -eq $k) { $needsClear = $true; continue }

        $key = $k.Key
        if ($key -in @("UpArrow", "W", "K")) { $scrollOffset = [Math]::Max(0, $scrollOffset - 1) }
        elseif ($key -in @("DownArrow", "S", "J")) { $scrollOffset = [Math]::Min($maxScroll, $scrollOffset + 1) }
        elseif ($key -eq "PageUp") { $scrollOffset = [Math]::Max(0, $scrollOffset - $viewHeight) }
        elseif ($key -in @("PageDown", "Spacebar")) { $scrollOffset = [Math]::Min($maxScroll, $scrollOffset + $viewHeight) }
        elseif ($key -in @("Escape", "Q", "Enter", "Backspace")) { break }
        elseif (-not $ReadOnly) {
            if ($key -eq "E") { Edit-NoteFile -File $File; break }
            elseif ($key -eq "O") { Open-InObsidian -File $File; break }
            elseif ($key -in @("A", "P")) { Append-ToNote -File $File; break }
        }
    }
}

function Search-NotesPrompt {
    Write-ModalHeader "SEARCH IN NOTES"
    Write-Host ""
    Write-Host "Enter search query: " -ForegroundColor White -NoNewline
    $query = Read-Host
    if ([string]::IsNullOrWhiteSpace($query)) { return }

    # -SimpleMatch: treat the query as plain text so characters like ( [ * don't throw regex errors
    $hits = @(Get-AllNotes | Select-String -Pattern $query -SimpleMatch -Encoding UTF8)

    if ($hits.Count -eq 0) {
        Write-Host "`nNo notes found matching '$query'." -ForegroundColor DarkGray
    } else {
        Write-Host "`nMatches found for '$query':" -ForegroundColor White
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        foreach ($g in ($hits | Group-Object -Property Path)) {
            Write-Host ("`n" + $cOrange + "* " + (Get-RelativeNotePath $g.Name) + $rst)
            foreach ($m in $g.Group) {
                Write-Host ("   Line {0}: {1}" -f $m.LineNumber, $m.Line.Trim()) -ForegroundColor White
            }
        }
    }
    Write-Host "`nPress Enter to return to notebook..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

# --- Notebook Browser ---

# Every hotkey shown in the nav bar. "When" limits an entry to Note/Folder selections or scrollable previews.
$NavSpec = @(
    @{ Key = "[W/S]";   Label = " Move " },
    @{ Key = "[A/D]";   Label = " Folders " },
    @{ Key = "[C]";     Label = " All Folders " },
    @{ Key = "[J/K]";   Label = " Scroll ";     When = "Scroll" },
    @{ Key = "[T]";     Label = " Sort " },
    @{ Key = "[Enter]"; Label = " Expand ";     When = "Folder" },
    @{ Key = "[Enter]"; Label = " View ";       When = "Note" },
    @{ Key = "[V]";     Label = " Fullscreen "; When = "Note" },
    @{ Key = "[E]";     Label = " Edit ";       When = "Note" },
    @{ Key = "[O]";     Label = " Obsidian ";   When = "Note" },
    @{ Key = "[N]";     Label = " Note " },
    @{ Key = "[F]";     Label = " Folder " },
    @{ Key = "[U]";     Label = " Updates " },
    @{ Key = "[R]";     Label = " Rename " },
    @{ Key = "[X]";     Label = " Del " },
    @{ Key = "[Q]";     Label = " Exit" }
)

function Format-NavBar($Items, [int]$Width) {
    $sb = [System.Text.StringBuilder]::new(" ")
    $curLen = 1
    $lines = 1
    foreach ($item in $Items) {
        $itemLen = $item.Key.Length + $item.Label.Length + 1
        if ($curLen + $itemLen -ge $Width) {
            [void]$sb.Append("`r`n ")
            $curLen = 1
            $lines++
        }
        [void]$sb.Append($cOrange + $item.Key + $cSilver + $item.Label + " ")
        $curLen += $itemLen
    }
    return @{ Text = $sb.ToString(); Lines = $lines }
}

function Get-ContextFolder($Item) {
    # The folder new items should go into, based on the current selection
    if ($Item -and $Item.Type -eq "Folder") { return $Item.FullName }
    if ($Item -and $Item.Type -eq "Note") { return (Split-Path -Parent $Item.FullName) }
    return $NotesDir
}

function Start-NotebookBrowser {
    # Mutable UI state shared with the nested Invoke-Modal helper
    $ui = @{
        NeedsFullClear    = $true
        IndexDirty        = $true
        PendingSelectPath = $null
    }

    function Invoke-Modal([scriptblock]$Action) {
        Set-CursorVisible $true
        $script:LastActionPath = $null
        & $Action
        if ($script:LastActionPath) { $ui.PendingSelectPath = $script:LastActionPath }
        $ui.NeedsFullClear = $true
        $ui.IndexDirty = $true
        Set-CursorVisible $false
    }

    function Get-ActiveNoteFile {
        if ($activeItem -and $activeItem.Type -eq "Note" -and [System.IO.File]::Exists($activeItem.FullName)) {
            return (Get-Item -LiteralPath $activeItem.FullName)
        }
        return $null
    }

    function Expand-AllFolders {
        $script:CollapsedFolders.Clear()
    }

    function Collapse-AllFolders {
        $script:CollapsedFolders.Clear()
        foreach ($d in (Get-NoteFolders)) {
            $script:CollapsedFolders[$d.FullName] = $true
        }
    }

    $selectedIndex = 0
    $treeItems = @()
    $itemsDirty = $true
    $index = $null
    $indexStamp = [DateTime]::MinValue
    $indexVersion = 0
    $previewKey = $null
    $previewLines = @()
    $previewScrollOffset = 0
    $lastSelectedIndex = -1
    $lastBoxHeight = 0
    $lastTermWidth = 0
    $navWidth = -1
    $worstNavLines = 1
    $vBar = $cDarkGray + $bVert + $rst

    Set-CursorVisible $false
    try {
        while ($true) {
            # --- Data refresh: one disk scan after any modal action, or when the index is >2s old ---
            if ($ui.IndexDirty -or ((Get-Date) - $indexStamp).TotalSeconds -gt 2) {
                $index = Get-NotebookIndex
                $indexStamp = Get-Date
                $indexVersion++
                $ui.IndexDirty = $false
                $itemsDirty = $true
            }

            # --- Visible tree: rebuilt from the cached index only when structure/expansion/sort changes ---
            if ($itemsDirty) {
                $prevPath = if ($selectedIndex -lt $treeItems.Count) { $treeItems[$selectedIndex].FullName } else { $null }
                $list = [System.Collections.Generic.List[object]]::new()
                Add-TreeItems -Index $index -Path $index.Root -Level 0 -Items $list
                $treeItems = $list.ToArray()
                $itemsDirty = $false

                # Keep the cursor on the same item (or jump to a newly created/renamed one)
                $targetPath = if ($ui.PendingSelectPath) { $ui.PendingSelectPath } else { $prevPath }
                $ui.PendingSelectPath = $null
                if ($targetPath) {
                    for ($ti = 0; $ti -lt $treeItems.Count; $ti++) {
                        if ($treeItems[$ti].FullName -eq $targetPath) {
                            $selectedIndex = $ti
                            break
                        }
                    }
                }
            }

            if ($selectedIndex -ge $treeItems.Count) {
                $selectedIndex = [Math]::Max(0, $treeItems.Count - 1)
            }

            # Terminal dimensions (reserve 1 col right margin to prevent autowrap clipping)
            $termWidth = 99
            $termHeight = 26
            try {
                if ([Console]::WindowWidth -gt 20) { $termWidth = [Console]::WindowWidth - 1 }
                if ([Console]::WindowHeight -gt 10) { $termHeight = [Console]::WindowHeight }
            } catch {}

            # Geometry calculations (Total box width = termWidth = 1 + leftWidth + 1 + rightWidth + 1)
            $leftWidth = [Math]::Max(15, [Math]::Min(38, [Math]::Floor($termWidth * 0.35)))
            $rightWidth = $termWidth - $leftWidth - 3

            if ($rightWidth -lt 25) {
                $rightWidth = 25
                $leftWidth = $termWidth - $rightWidth - 3
                if ($leftWidth -lt 5) { $leftWidth = 5 }
            }

            $usableWidth = [Math]::Max(20, $rightWidth - 3)

            # --- Active item preview (cached; notes re-render only when the file changes on disk) ---
            $activeItem = if ($selectedIndex -lt $treeItems.Count) { $treeItems[$selectedIndex] } else { $null }
            $currentRightTitle = "No selection"
            $newPreviewKey = $null

            if ($activeItem -and $activeItem.Type -eq "Folder") {
                $currentRightTitle = "Folder: " + $activeItem.Name
                $newPreviewKey = "F|$($activeItem.FullName)|$($activeItem.IsExpanded)|$indexVersion|$usableWidth"
            } elseif ($activeItem -and $activeItem.Type -eq "Note") {
                $currentRightTitle = $activeItem.FileName
                $stamp = if ([System.IO.File]::Exists($activeItem.FullName)) { [System.IO.File]::GetLastWriteTimeUtc($activeItem.FullName).Ticks } else { 0 }
                $newPreviewKey = "N|$($activeItem.FullName)|$stamp|$usableWidth"
            }

            if ($newPreviewKey -ne $previewKey) {
                $previewLines = @()
                if ($activeItem -and $activeItem.Type -eq "Folder") {
                    $previewLines = @(Get-FolderPreviewLines -Item $activeItem -Index $index -UsableWidth $usableWidth)
                } elseif ($activeItem -and $activeItem.Type -eq "Note" -and $stamp) {
                    $rawLines = Get-Content -LiteralPath $activeItem.FullName -TotalCount 500 -Encoding UTF8 -ErrorAction SilentlyContinue
                    $previewLines = @(Convert-MarkdownToTerminalLines -RawLines $rawLines -Width $usableWidth)
                }
                $previewKey = $newPreviewKey
            }

            # --- Layout: the nav bar always reserves its worst-case height to prevent UI bouncing ---
            if ($termWidth -ne $navWidth) {
                $worstNavLines = (Format-NavBar $NavSpec $termWidth).Lines
                $navWidth = $termWidth
            }

            # Fixed full-terminal layout: box height = terminal minus banner, box borders and nav bar
            $boxHeight = [Math]::Max(2, $termHeight - 9 - $worstNavLines)
            $usableHeight = [Math]::Max(1, $boxHeight - 1)
            $needsScrollBadge = $previewLines.Count -gt $usableHeight

            $navItems = @($NavSpec | Where-Object {
                -not $_.When -or
                ($_.When -eq "Scroll" -and $needsScrollBadge) -or
                ($activeItem -and $_.When -eq $activeItem.Type)
            })
            $nav = Format-NavBar $navItems $termWidth
            $navBar = $nav.Text + $rst + "$esc[J"
            if ($nav.Lines -lt $worstNavLines) {
                $navBar += ("`r`n" * ($worstNavLines - $nav.Lines))
            }

            if ($boxHeight -ne $lastBoxHeight -or $termWidth -ne $lastTermWidth) {
                $ui.NeedsFullClear = $true
                $lastBoxHeight = $boxHeight
                $lastTermWidth = $termWidth
            }

            # Reset preview scroll when selecting a new item
            if ($selectedIndex -ne $lastSelectedIndex) {
                $previewScrollOffset = 0
                $lastSelectedIndex = $selectedIndex
            }

            $maxPreviewScroll = [Math]::Max(0, $previewLines.Count - $usableHeight)
            if ($previewScrollOffset -gt $maxPreviewScroll) {
                $previewScrollOffset = $maxPreviewScroll
            }

            # Scrolling window for items list
            $scrollOffset = 0
            if ($selectedIndex -ge $usableHeight) {
                $scrollOffset = $selectedIndex - $usableHeight + 1
            }

            # Assemble Frame in Memory (Flicker-Free Double-Buffering)
            $renderFrameLines = {
                $sb = [System.Text.StringBuilder]::new()

                # 1. Header Banner (Graphite to Flame Orange Horizon)
                [void]$sb.AppendLine((Render-HeaderBanner $termWidth))

                # 2. Box Header (100% Aligned Math)
                $activeNbName = Get-ActiveNotebookName
                $leftTitle = " WORKSPACE: $activeNbName "
                $sortIcon = if ($script:SortMode -eq "alpha") { $gSortAlpha } else { $gSortDate }
                $sortText = if ($script:SortMode -eq "alpha") { "A-Z" } else { "Date" }
                $sortBadge = " $sortIcon $sortText "

                $sortBufferLen = 2
                $availLeft = $leftWidth - 1
                if ($leftTitle.Length + $sortBadge.Length + $sortBufferLen -gt $availLeft) {
                    $maxT = $availLeft - $sortBadge.Length - $sortBufferLen - 1
                    if ($maxT -gt 5) {
                        $leftTitle = Truncate-String -Str $leftTitle -MaxLen $maxT
                    } else {
                        $leftTitle = " NOTES "
                    }
                }
                $leftDashes = [Math]::Max(0, $availLeft - $leftTitle.Length - $sortBadge.Length - $sortBufferLen)

                $scrollNotice = ""
                if ($previewLines.Count -gt $usableHeight) {
                    $visEnd = [Math]::Min($previewLines.Count, $previewScrollOffset + $usableHeight)
                    $scrollNotice = " [$($previewScrollOffset + 1)-$visEnd of $($previewLines.Count)] "
                }

                $rightTitle = " PREVIEW " + $scrollNotice
                $rightDashes = $rightWidth - $rightTitle.Length - 1
                if ($rightDashes -lt 0) {
                    $rightTitle = " PREVIEW "
                    $rightDashes = [Math]::Max(0, $rightWidth - $rightTitle.Length - 1)
                }

                # Outer Box Gradient Colors (Slate Graphite / Gray -> Vivid Flame Orange)
                $cBorderStart = @(95, 100, 115)
                $cBorderEnd   = @(255, 130, 0)
                $topBorderColor = fg $cBorderStart[0] $cBorderStart[1] $cBorderStart[2]
                $botBorderColor = fg $cBorderEnd[0] $cBorderEnd[1] $cBorderEnd[2]

                [void]$sb.Append($topBorderColor + $uRoundTL + $bHoriz + $cOrange + $leftTitle + $topBorderColor + ($bHoriz * $leftDashes) + $cAmber + $sortBadge + $topBorderColor + ($bHoriz * $sortBufferLen) + $bTopT + $bHoriz + $cOrange + $rightTitle + $topBorderColor + ($bHoriz * $rightDashes) + $uRoundTR + $rst + "`r`n")

                # 3. Render Rows
                for ($r = 0; $r -lt $boxHeight; $r++) {
                    $tRatio = ($r + 1) / ($boxHeight + 1.0)
                    $rowRgb = Get-GradientColor $cBorderStart $cBorderEnd $tRatio
                    $vBar = (fg $rowRgb[0] $rowRgb[1] $rowRgb[2]) + $bVert + $rst

                    if ($r -eq 0) {
                        # Top padding row to give breathing room beneath headers
                        $blankLeft = $vBar + (" " * $leftWidth) + $rst
                        $blankRight = $vBar + (" " * $rightWidth) + $rst
                        [void]$sb.Append($blankLeft).Append($blankRight).Append($vBar + "`r`n")
                        continue
                    }

                    $itemIdx = $scrollOffset + ($r - 1)

                    # Left column formatting
                    $leftStr = ""
                    $rowColor = $cSilver
                    $branchGlyph = $null
                    $cur = $null
                    if ($itemIdx -lt $treeItems.Count) {
                        $cur = $treeItems[$itemIdx]
                        $treePrefix = ""
                        if ($cur.Level -eq 1) {
                            $treePrefix = "  "
                        } elseif ($cur.Level -ge 2) {
                            $treePrefix = "  "
                            if ($cur.AncestorsHasNext -and $cur.AncestorsHasNext.Count -gt 1) {
                                for ($a = 1; $a -lt $cur.AncestorsHasNext.Count; $a++) {
                                    if ($cur.AncestorsHasNext[$a]) {
                                        $treePrefix += "$bVert  "
                                    } else {
                                        $treePrefix += "   "
                                    }
                                }
                            }
                            $branchGlyph = if ($cur.IsLastSibling) { $gBranchEnd } else { $gBranchMid }
                            $treePrefix += "$branchGlyph "
                        }

                        if ($cur.Type -eq "Folder") {
                            $rowColor = $cFolder
                            $arrow = if ($cur.IsExpanded) { "$gArrowDown " } else { "$gArrowRight " }
                            $icon = if ($cur.IsExpanded) { "$gFolderOpen " } else { "$gFolderClosed " }
                            $countLabel = " ($($cur.ItemCount))"
                            $maxNameLen = [Math]::Max(1, $leftWidth - $treePrefix.Length - 4 - $countLabel.Length)
                            $dispName = Truncate-String -Str $cur.Name -MaxLen $maxNameLen
                            $leftStr = "$treePrefix$arrow$icon$dispName$countLabel"
                        } elseif ($cur.Type -eq "Note") {
                            $maxNameLen = [Math]::Max(1, $leftWidth - $treePrefix.Length - 3)
                            $dispName = Truncate-String -Str $cur.Name -MaxLen $maxNameLen
                            $leftStr = "$treePrefix$gFileIcon $dispName"
                        }
                        # Spacers render blank and can never be highlighted
                        if ($itemIdx -eq $selectedIndex -and $cur.Type -ne "Spacer") { $rowColor = $cSelected }
                    }
                    $leftStr = $leftStr.PadRight($leftWidth)
                    if ($leftStr.Length -gt $leftWidth) { $leftStr = $leftStr.Substring(0, $leftWidth) }

                    $coloredLeftStr = $rowColor + $leftStr + $rst
                    # Subtly color the tree branches DarkGray
                    if ($cur -and $cur.Level -gt 0) {
                        if ($bVert) {
                            $coloredLeftStr = $coloredLeftStr.Replace($bVert, $cDarkGray + $bVert + $rowColor)
                        }
                        if ($branchGlyph) {
                            $coloredLeftStr = $coloredLeftStr.Replace($branchGlyph, $cDarkGray + $branchGlyph + $rowColor)
                        }
                    }

                    # Right column formatting (preview lines are pre-styled ANSI, or empty)
                    $pIndex = $previewScrollOffset + ($r - 1)
                    $pLine = if ($pIndex -lt $previewLines.Count) { $previewLines[$pIndex] } else { "" }
                    $rightStr = Format-AnsiCell $pLine $rightWidth

                    # Draw row into buffer
                    [void]$sb.Append($vBar).Append($coloredLeftStr).Append($vBar).Append($rightStr).Append($vBar + "`r`n")
                }

                # 4. Box Footer
                $verTag = " v$AppVersion "
                $footLeftDashes = [Math]::Max(0, $rightWidth - $verTag.Length)
                [void]$sb.AppendLine($botBorderColor + $uRoundBL + ($bHoriz * $leftWidth) + $bBotT + ($bHoriz * $footLeftDashes) + $cGray + $verTag + $botBorderColor + $uRoundBR + $rst)

                # 5. Navigation Bar
                [void]$sb.Append($navBar)

                $linesList = [System.Collections.Generic.List[string]]::new()
                foreach ($l in ($sb.ToString() -split "`r`n")) {
                    $linesList.Add($l)
                }
                return $linesList
            }

            $bgLines = & $renderFrameLines
            $sb = [System.Text.StringBuilder]::new()
            foreach ($line in $bgLines) { [void]$sb.AppendLine($line) }

            # 6. Atomic Write to Terminal (Zero-Flicker)
            if ($ui.NeedsFullClear) {
                Clear-Host
                $ui.NeedsFullClear = $false
            } else {
                try { [Console]::SetCursorPosition(0, 0) } catch {}
                [Console]::Write("$esc[H")
            }
            [Console]::Write($sb.ToString().Replace("`r`n", "$esc[K`r`n") + "$esc[K$esc[J")

            # Responsive Read Keystroke & Resize Polling
            try { $key = Read-KeyOrResize } catch { break }
            if ($null -eq $key) {
                $ui.NeedsFullClear = $true
                continue
            }

            switch ($key.Key) {
                { $_ -in @("UpArrow", "W") } {
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                        if ($treeItems[$selectedIndex].Type -eq "Spacer" -and $selectedIndex -gt 0) {
                            $selectedIndex--
                        }
                    }
                }
                { $_ -in @("DownArrow", "S") } {
                    if ($selectedIndex -lt ($treeItems.Count - 1)) {
                        $selectedIndex++
                        if ($treeItems[$selectedIndex].Type -eq "Spacer" -and $selectedIndex -lt ($treeItems.Count - 1)) {
                            $selectedIndex++
                        }
                    }
                }
                "PageUp" {
                    if ($previewLines.Count -gt $boxHeight) {
                        $previewScrollOffset = [Math]::Max(0, $previewScrollOffset - [Math]::Max(1, $boxHeight - 3))
                    } else {
                        $selectedIndex = [Math]::Max(0, $selectedIndex - 6)
                        if ($treeItems[$selectedIndex].Type -eq "Spacer") {
                            if ($selectedIndex -gt 0) { $selectedIndex-- } else { $selectedIndex++ }
                        }
                    }
                }
                "PageDown" {
                    if ($previewLines.Count -gt $boxHeight) {
                        $previewScrollOffset = [Math]::Min($maxPreviewScroll, $previewScrollOffset + [Math]::Max(1, $boxHeight - 3))
                    } else {
                        $selectedIndex = [Math]::Min([Math]::Max(0, $treeItems.Count - 1), $selectedIndex + 6)
                        if ($treeItems[$selectedIndex].Type -eq "Spacer") {
                            if ($selectedIndex -lt ($treeItems.Count - 1)) { $selectedIndex++ } else { $selectedIndex-- }
                        }
                    }
                }
                "J" {
                    if ($previewLines.Count -gt $boxHeight) {
                        $previewScrollOffset = [Math]::Min($maxPreviewScroll, $previewScrollOffset + 3)
                    }
                }
                "K" {
                    if ($previewLines.Count -gt $boxHeight) {
                        $previewScrollOffset = [Math]::Max(0, $previewScrollOffset - 3)
                    }
                }
                "C" {
                    $hasShift = ($key.Modifiers -band [System.ConsoleModifiers]::Shift)
                    if ($hasShift) {
                        Expand-AllFolders
                    } else {
                        $allFolders = @(Get-NoteFolders)
                        if ($script:CollapsedFolders.Count -ge $allFolders.Count -and $allFolders.Count -gt 0) {
                            Expand-AllFolders
                        } else {
                            Collapse-AllFolders
                        }
                    }
                    $itemsDirty = $true
                }
                { $_ -in @("RightArrow", "D") } {
                    $hasShift = ($key.Modifiers -band [System.ConsoleModifiers]::Shift)
                    if ($hasShift) {
                        Expand-AllFolders
                        $itemsDirty = $true
                    } elseif ($activeItem -and $activeItem.Type -eq "Folder" -and -not $activeItem.IsExpanded) {
                        $script:CollapsedFolders.Remove($activeItem.FullName)
                        $itemsDirty = $true
                    }
                }
                { $_ -in @("LeftArrow", "A") } {
                    $hasShift = ($key.Modifiers -band [System.ConsoleModifiers]::Shift)
                    if ($hasShift) {
                        Collapse-AllFolders
                        $itemsDirty = $true
                    } elseif ($activeItem) {
                        if ($activeItem.Type -eq "Folder" -and $activeItem.IsExpanded) {
                            $script:CollapsedFolders[$activeItem.FullName] = $true
                            $itemsDirty = $true
                        } elseif ($activeItem.Level -gt 0) {
                            # Move cursor up to parent folder
                            $parentDir = Split-Path $activeItem.FullName -Parent
                            for ($i = $selectedIndex; $i -ge 0; $i--) {
                                if ($treeItems[$i].FullName -eq $parentDir) {
                                    $selectedIndex = $i
                                    break
                                }
                            }
                        }
                    }
                }
                { $_ -in @("Enter", "Spacebar") } {
                    if ($activeItem -and $activeItem.Type -eq "Folder") {
                        # Toggle expand/collapse
                        if ($activeItem.IsExpanded) { $script:CollapsedFolders[$activeItem.FullName] = $true }
                        else { $script:CollapsedFolders.Remove($activeItem.FullName) }
                        $itemsDirty = $true
                    } else {
                        $note = Get-ActiveNoteFile
                        if ($note) { Invoke-Modal { View-FullscreenNote $note } }
                    }
                }
                "V" {
                    $note = Get-ActiveNoteFile
                    if ($note) { Invoke-Modal { View-FullscreenNote $note } }
                }
                "U" {
                    $releaseNotesPath = Join-Path $PSScriptRoot "RELEASE_NOTES.md"
                    if (Test-Path -LiteralPath $releaseNotesPath) {
                        Invoke-Modal { View-FullscreenNote -File (Get-Item -LiteralPath $releaseNotesPath) -ReadOnly }
                    }
                }
                "E" {
                    $note = Get-ActiveNoteFile
                    if ($note) { Invoke-Modal { Edit-NoteFile -File $note } }
                }
                "O" {
                    $note = Get-ActiveNoteFile
                    if ($note) { Open-InObsidian -File $note }
                }
                "P" {
                    $note = Get-ActiveNoteFile
                    if ($note) { Invoke-Modal { Append-ToNote -File $note } }
                }
                "T" {
                    $script:SortMode = if ($script:SortMode -eq "date") { "alpha" } else { "date" }
                    $itemsDirty = $true
                    try {
                        Write-Utf8File -Path (Join-Path $script:NotesDir ".config.json") -Text ((@{ SortMode = $script:SortMode } | ConvertTo-Json) + [Environment]::NewLine)
                    } catch {}
                }
                "B" {
                    Invoke-Modal { Switch-NotebookModal }
                }
                "N" {
                    $targetFolder = Get-ContextFolder $activeItem
                    $script:CollapsedFolders.Remove($targetFolder)
                    New-InteractiveNote -DestinationDir $targetFolder -RenderBgBlock $renderFrameLines
                    $ui.NeedsFullClear = $true
                    $ui.IndexDirty = $true
                }
                "F" {
                    $targetParent = Get-ContextFolder $activeItem
                    $script:CollapsedFolders.Remove($targetParent)
                    New-FolderPrompt -ParentDir $targetParent -RenderBgBlock $renderFrameLines
                    $ui.NeedsFullClear = $true
                    $ui.IndexDirty = $true
                }
                "R" {
                    if ($activeItem -and $activeItem.Type -ne "Spacer") {
                        Rename-ItemPrompt -Item $activeItem -RenderBgBlock $renderFrameLines
                        $ui.NeedsFullClear = $true
                        $ui.IndexDirty = $true
                    }
                }
                { $_ -in @("X", "Delete") } {
                    if ($activeItem -and $activeItem.Type -ne "Spacer") {
                        Delete-ItemPrompt -Item $activeItem -RenderBgBlock $renderFrameLines
                        $ui.NeedsFullClear = $true
                        $ui.IndexDirty = $true
                    }
                }
                "L" {
                    Quick-Log -RenderBgBlock $renderFrameLines
                    $ui.NeedsFullClear = $true
                    $ui.IndexDirty = $true
                }
                "Oem2" { # '/' key
                    Invoke-Modal { Search-NotesPrompt }
                }
                { $_ -in @("Escape", "Q") } {
                    return
                }
                default {
                    # Ignore unrecognized keys
                }
            }
        }
    } finally {
        Set-CursorVisible $true
        Clear-Host
    }
}

# --- CLI Argument Processing ---
$allArgs = if ($SubCommand -and $ArgsList) { "$SubCommand " + ($ArgsList -join " ") } elseif ($SubCommand) { $SubCommand } elseif ($ArgsList) { ($ArgsList -join " ") } else { "" }

function Find-NoteByName([string]$Target) {
    $pattern = "*" + [WildcardPattern]::Escape($Target) + "*"
    return Get-AllNotes | Where-Object { $_.BaseName -like $pattern -or $_.FullName -like $pattern } | Select-Object -First 1
}

if (-not [string]::IsNullOrWhiteSpace($Command)) {
    switch ($Command.ToLower()) {
        "browse" {
            Start-NotebookBrowser
            return
        }
        "new" {
            New-InteractiveNote -InitialTitle $allArgs
            return
        }
        "folder" {
            New-FolderPrompt
            return
        }
        { $_ -in @("log", "quick") } {
            Quick-Log -Text $allArgs
            return
        }
        "obsidian" {
            $match = if ([string]::IsNullOrWhiteSpace($allArgs)) { Get-AllNotes | Select-Object -First 1 } else { Find-NoteByName $allArgs }
            if ($match) { Open-InObsidian -File $match }
            return
        }
        "list" {
            $notes = @(Get-AllNotes)
            if ($notes.Count -eq 0) {
                Write-Host "No notes found in $script:NotesDir" -ForegroundColor DarkYellow
                return
            }
            Write-Host ("{0,-4}  {1,-36}  {2,-18}" -f "#", "Path & Title", "Last Modified") -ForegroundColor Cyan
            Write-Host ("{0,-4}  {1,-36}  {2,-18}" -f "-", "------------", "-------------") -ForegroundColor DarkGray
            for ($i = 0; $i -lt $notes.Count; $i++) {
                $display = Truncate-String -Str (Get-RelativeNotePath $notes[$i].FullName) -MaxLen 36
                $mod = $notes[$i].LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                Write-Host ("{0,-4}  {1,-36}  {2,-18}" -f "[$($i + 1)]", $display, $mod) -ForegroundColor White
            }
            return
        }
        "view" {
            $target = $allArgs
            $selectedFile = $null
            if ($target -match '^\d+$') {
                $notes = @(Get-AllNotes)
                $idx = [int]$target - 1
                if ($idx -ge 0 -and $idx -lt $notes.Count) { $selectedFile = $notes[$idx] }
            } else {
                $selectedFile = Find-NoteByName $target
            }
            if ($selectedFile) {
                View-FullscreenNote $selectedFile
            } else {
                Write-Host "Note not found: $target" -ForegroundColor Red
            }
            return
        }
        "search" {
            Search-NotesPrompt
            return
        }
        "open" {
            Invoke-Item $script:NotesDir
            return
        }
        { $_ -in @("notebook", "notebooks", "workspace", "workspaces") } {
            $subAction = if ($SubCommand) { $SubCommand.ToLower() } else { "list" }
            $cfg = Get-GlobalNotebookConfig
            switch ($subAction) {
                "list" {
                    Write-Host "`nConfigured Notebook Workspaces:" -ForegroundColor Cyan
                    Write-Host ("{0,-16}  {1,-45}  {2}" -f "Name", "Path", "Status") -ForegroundColor Cyan
                    Write-Host ("{0,-16}  {1,-45}  {2}" -f "----", "----", "------") -ForegroundColor DarkGray
                    foreach ($nb in $cfg.Notebooks) {
                        $isActive = ($nb.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/'))
                        $statusTag = if ($isActive) { "* Active" } else { "" }
                        Write-Host ("{0,-16}  {1,-45}  {2}" -f $nb.Name, $nb.Path, $statusTag) -ForegroundColor White
                    }
                    return
                }
                "switch" {
                    $targetNb = if ($ArgsList) { $ArgsList[0] } else { "" }
                    if ($targetNb) {
                        Set-ActiveNotebook -Target $targetNb
                        Write-Host "Active notebook switched to: $(Get-ActiveNotebookName) ($script:NotesDir)" -ForegroundColor Green
                    } else {
                        Write-Host "Usage: note notebook switch <name|path>" -ForegroundColor Red
                    }
                    return
                }
                "add" {
                    if ($ArgsList.Count -ge 2) {
                        $nbName = $ArgsList[0]
                        $nbPath = $ArgsList[1]
                        Set-ActiveNotebook -Target $nbPath
                        $updatedCfg = Get-GlobalNotebookConfig
                        $newList = [System.Collections.Generic.List[object]]::new()
                        foreach ($item in $updatedCfg.Notebooks) {
                            if ($item.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/')) {
                                $newList.Add(@{ Name = $nbName; Path = $script:NotesDir })
                            } else {
                                $newList.Add($item)
                            }
                        }
                        $updatedCfg.Notebooks = $newList.ToArray()
                        Save-GlobalNotebookConfig $updatedCfg
                        Write-Host "Added notebook: $nbName -> $script:NotesDir" -ForegroundColor Green
                    } else {
                        Write-Host "Usage: note notebook add <name> <path>" -ForegroundColor Red
                    }
                    return
                }
                "remove" {
                    $targetName = if ($ArgsList) { $ArgsList[0] } else { "" }
                    if ($targetName) {
                        $newList = [System.Collections.Generic.List[object]]::new()
                        $removed = $false
                        foreach ($nb in $cfg.Notebooks) {
                            if ($nb.Name.ToLower() -eq $targetName.ToLower()) {
                                if ($nb.Path.TrimEnd('\', '/') -eq $script:NotesDir.TrimEnd('\', '/')) {
                                    Write-Host "Cannot remove the currently active notebook. Switch to another notebook first." -ForegroundColor Red
                                    return
                                }
                                $removed = $true
                            } else {
                                $newList.Add($nb)
                            }
                        }
                        if ($removed) {
                            $cfg.Notebooks = $newList.ToArray()
                            Save-GlobalNotebookConfig $cfg
                            Write-Host "Removed notebook '$targetName'" -ForegroundColor Green
                        } else {
                            Write-Host "Notebook '$targetName' not found." -ForegroundColor Red
                        }
                    } else {
                        Write-Host "Usage: note notebook remove <name>" -ForegroundColor Red
                    }
                    return
                }
                default {
                    Start-NotebookBrowser
                    return
                }
            }
        }
        "help" {
            Write-Host "Terminal Notebook Usage:" -ForegroundColor Cyan
            Write-Host "  note                      Open Notebook Browser (interactive tree view)"
            Write-Host "  note browse               Open Notebook Browser"
            Write-Host "  note <name|path>          Switch to named notebook (e.g. note work) & open browser"
            Write-Host "  note -Notebook <path>     Open specific notebook folder"
            Write-Host "  note notebook list        List all configured notebook workspaces"
            Write-Host "  note notebook switch <n>  Switch active notebook workspace"
            Write-Host "  note notebook add <n> <p> Register a new notebook workspace"
            Write-Host "  note `"quick thought`"      Instantly append a thought to today's log"
            Write-Host "  note log <text>           Append a thought to today's log (alias: quick)"
            Write-Host "  note new [title]          Create a new markdown note"
            Write-Host "  note folder               Create a new folder"
            Write-Host "  note list                 List all notes with their numbers"
            Write-Host "  note view <#|name>        View note in fullscreen reader"
            Write-Host "  note obsidian [name]      Open note in Obsidian"
            Write-Host "  note search               Search inside notes"
            Write-Host "  note open                 Open Notes folder in File Explorer"
            return
        }
        default {
            # Check if Command matches a registered notebook profile name or directory
            $cfg = Get-GlobalNotebookConfig
            $matched = $false
            foreach ($nb in $cfg.Notebooks) {
                if ($nb.Name.ToLower() -eq $Command.ToLower()) {
                    Set-ActiveNotebook -Target $nb.Path
                    $matched = $true
                    break
                }
            }
            if (-not $matched -and (Test-Path -LiteralPath $Command -PathType Container)) {
                Set-ActiveNotebook -Target $Command
                $matched = $true
            }

            if ($matched) {
                Start-NotebookBrowser
                return
            }

            $fullNote = "$Command $allArgs".Trim()
            Quick-Log -Text $fullNote
            return
        }
    }
}

# Default action when typing `note` or `notes`: Open the Notebook Browser!
Start-NotebookBrowser
