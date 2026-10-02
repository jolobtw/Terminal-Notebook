<#
.SYNOPSIS
    Terminal Notes & Notebook Browser with Folder & Nerd Font Support
.DESCRIPTION
    A terminal-based notebook for browsing, writing, and organizing Markdown notes.
    Features collapsible folder hierarchy, Nerd Font icons, and Obsidian integration.
#>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$ArgsList
)

$AppVersion = "1.8"

# Refresh PATH from registry so newly installed winget packages (like micro) work immediately
try {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
} catch {}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($null -eq $IsWindows) { $IsWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT' }
if ($null -eq $IsMacOS) { $IsMacOS = [System.Environment]::OSVersion.Platform -eq 'Unix' -and (uname -s) -match 'Darwin' }

$NotesDir = Join-Path $HOME "Notes"
if (-not (Test-Path $NotesDir)) {
    New-Item -ItemType Directory -Path $NotesDir -Force | Out-Null
}

# --- Glyph Definitions (Hex-escaped for encoding safety) ---
$bTopLeft      = [string][char]0x250C # Top Left
$bTopRight     = [string][char]0x2510 # Top Right
$bBotLeft      = [string][char]0x2514 # Bot Left
$bBotRight     = [string][char]0x2518 # Bot Right
$bHoriz        = [string][char]0x2500 # Horiz
$bVert         = [string][char]0x2502 # Vert
$bTopT         = [string][char]0x252C # Top T
$bBotT         = [string][char]0x2534 # Bot T
$dTopLeft      = [string][char]0x2554 # Double Top Left
$dTopRight     = [string][char]0x2557 # Double Top Right
$dBotLeft      = [string][char]0x255A # Double Bot Left
$dBotRight     = [string][char]0x255D # Double Bot Right
$dHoriz        = [string][char]0x2550 # Double Horiz
$dVert         = [string][char]0x2551 # Double Vert

# Nerd Font & Tree Glyphs
$gFolderClosed = [string][char]0xF07B # Nerd Font folder
$gFolderOpen   = [string][char]0xF07C # Nerd Font folder open
$gFileIcon     = [string][char]0xF15C # Nerd Font file
$gArrowRight   = [string][char]0x25B6 # Collapsed indicator
$gArrowDown    = [string][char]0x25BC # Expanded indicator

# Markdown & Callout Glyphs
$uRoundTL      = [string][char]0x256D # ╭
$uRoundTR      = [string][char]0x256E # ╮
$uRoundBL      = [string][char]0x2570 # ╰
$uRoundBR      = [string][char]0x256F # ╯
$uHoriz        = [string][char]0x2500 # ─
$uVert         = [string][char]0x2502 # │
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
$cDeepChar   = fg 60 62 75                   # Deep Charcoal
$cCodeBg     = bg 48 50 62                   # Subtle Dark Slate for Inline Code Badges
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

function Render-GradientText([string]$text, $c1, $c2) {
    $len = [Math]::Max(1, $text.Length)
    $out = ""
    for ($i = 0; $i -lt $len; $i++) {
        $ratio = if ($len -gt 1) { $i / ($len - 1.0) } else { 0.0 }
        $rgb = Get-GradientColor $c1 $c2 $ratio
        $out += (fg $rgb[0] $rgb[1] $rgb[2]) + $text[$i]
    }
    return $out + $rst
}

function Render-AuroraWave([int]$width, $c1, $c2, $c3, [string]$char) {
    $out = ""
    for ($i = 0; $i -lt $width; $i++) {
        $t = if ($width -gt 1) { $i / ($width - 1.0) } else { 0.0 }
        $col = if ($t -lt 0.5) { 
            Get-GradientColor $c1 $c2 ($t * 2.0) 
        } else { 
            Get-GradientColor $c2 $c3 (($t - 0.5) * 2.0) 
        }
        $out += (fg $col[0] $col[1] $col[2]) + $char
    }
    return $out + $rst
}

function Make-CardLine($label, $val, $valCol, $miniWidth) {
    $bVertChar = [string][char]0x2502
    $content = "  " + $label.PadRight(10) + ": " + $val
    $spaceNeeded = [Math]::Max(0, ($miniWidth - 2 - $content.Length))
    $pad = " " * $spaceNeeded
    $cCardBorder = fg 110 115 130
    $cCardLabel  = fg 155 160 175
    return ($cCardBorder + "  $bVertChar" + $cCardLabel + "  " + $label.PadRight(10) + ": " + $valCol + $val + $rst + $pad + $cCardBorder + "$bVertChar" + $rst)
}

# Folder expansion state table & Preferences
if (-not $script:ExpandedFolders) {
    $script:ExpandedFolders = @{}
    Get-ChildItem -Path $NotesDir -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\\.(obsidian|git)($|\\)' } | ForEach-Object {
        $script:ExpandedFolders[$_.FullName] = $true
    }
}

$notesConfigFile = Join-Path $NotesDir ".config.json"
if (-not $script:SortMode) {
    $script:SortMode = "date"
    if (Test-Path $notesConfigFile) {
        try {
            $cfg = Get-Content $notesConfigFile -Raw | ConvertFrom-Json
            if ($cfg.SortMode) { $script:SortMode = $cfg.SortMode }
        } catch {}
    }
}

function Get-PreferredTerminalEditor {
    if (Get-Command micro -ErrorAction SilentlyContinue) {
        return "micro"
    }
    if ($IsWindows) {
        $microWinGet = Resolve-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\zyedidia.micro*\*\micro.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($microWinGet) {
            return $microWinGet.Path
        }
    }
    if (Get-Command nvim -ErrorAction SilentlyContinue) {
        return "nvim"
    }
    if ($IsWindows -and (Test-Path "C:\Program Files\Neovim\bin\nvim.exe")) {
        return "C:\Program Files\Neovim\bin\nvim.exe"
    }
    if (Get-Command nano -ErrorAction SilentlyContinue) {
        return "nano"
    }
    if (Get-Command vim -ErrorAction SilentlyContinue) {
        return "vim"
    }
    return $null
}

function Register-ObsidianVault {
    $obsidianConfig = if ($IsMacOS) { "$HOME/Library/Application Support/obsidian/obsidian.json" } else { "$env:APPDATA\obsidian\obsidian.json" }
    if (-not (Test-Path $obsidianConfig)) { return "Notes" }

    try {
        $json = Get-Content $obsidianConfig -Raw | ConvertFrom-Json
        $foundId = $null
        foreach ($prop in $json.vaults.PSObject.Properties) {
            if ($prop.Value.path -eq $NotesDir) {
                $foundId = $prop.Name
                break
            }
        }

        if (-not $foundId) {
            $vaultId = [System.Guid]::NewGuid().ToString("N").Substring(0, 16)
            $epochNow = [int64]([System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
            $newVaultObj = [PSCustomObject]@{
                path = $NotesDir
                ts = $epochNow
            }
            $json.vaults | Add-Member -MemberType NoteProperty -Name $vaultId -Value $newVaultObj
            $json | ConvertTo-Json -Depth 5 | Set-Content $obsidianConfig -Encoding UTF8
            $foundId = $vaultId
        }

        $obsidianDir = Join-Path $NotesDir ".obsidian"
        if (-not (Test-Path $obsidianDir)) {
            New-Item -ItemType Directory -Path $obsidianDir -Force | Out-Null
        }

        return $foundId
    } catch {
        return "Notes"
    }
}

function Open-InObsidian {
    param([System.IO.FileInfo]$File)
    if (-not $File -or -not (Test-Path $File.FullName)) { return }

    $vaultId = Register-ObsidianVault
    $targetVault = if ($vaultId) { $vaultId } else { "Notes" }

    # Compute vault-relative path using forward slashes
    $relPath = $File.FullName.Substring($NotesDir.Length).TrimStart('\', '/').Replace('\', '/')
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

function Invoke-TerminalEditor {
    param(
        [string]$EditorPath,
        [string]$FilePath,
        [switch]$GoToEnd
    )
    if (-not (Test-Path $FilePath)) { return }

    $edLeaf = Split-Path $EditorPath -Leaf

    if ($GoToEnd) {
        $lines = Get-Content -Path $FilePath
        $lastLine = if ($lines) { [Math]::Max(1, $lines.Count) } else { 1 }

        if ($edLeaf -match 'micro') {
            & $EditorPath -softwrap true -wordwrap true "$FilePath" "+$lastLine"
        } elseif ($edLeaf -match 'nvim|vim|nano') {
            & $EditorPath "+$lastLine" "$FilePath"
        } else {
            & $EditorPath "$FilePath"
        }
    } else {
        if ($edLeaf -match 'micro') {
            & $EditorPath -softwrap true -wordwrap true "$FilePath"
        } else {
            & $EditorPath "$FilePath"
        }
    }
}

function Get-AllNotes {
    $raw = Get-ChildItem -Path $NotesDir -Filter "*.md" -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.(obsidian|git)($|\\)' }
    if ($script:SortMode -eq "alpha") {
        return $raw | Sort-Object { Format-NoteTitle $_ }
    } else {
        return $raw | Sort-Object { 
            if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})') { 
                $matches[1] + " " + $_.CreationTime.ToString("HH:mm:ss")
            } else { 
                $_.CreationTime.ToString("yyyy-MM-dd HH:mm:ss") 
            } 
        } -Descending
    }
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
    if ([string]::IsNullOrEmpty($Str)) { return "" }
    if ($Str.Length -le $MaxLen) { return $Str }
    if ($MaxLen -le 3) { return $Str.Substring(0, $MaxLen) }
    return $Str.Substring(0, $MaxLen - 3) + "..."
}

function Format-WordWrap {
    param(
        [string]$Text,
        [int]$Width = 80
    )

    if ([string]::IsNullOrEmpty($Text)) { return @("") }
    if ($Text.Length -le $Width) { return @($Text) }

    $wrappedLines = @()
    $words = $Text -split '\s+'
    $currentLine = ""

    foreach ($w in $words) {
        if ([string]::IsNullOrEmpty($w)) { continue }
        if ([string]::IsNullOrEmpty($currentLine)) {
            $currentLine = $w
        } elseif (($currentLine.Length + 1 + $w.Length) -le $Width) {
            $currentLine += " " + $w
        } else {
            $wrappedLines += $currentLine
            while ($w.Length -gt $Width) {
                $wrappedLines += $w.Substring(0, $Width)
                $w = $w.Substring($Width)
            }
            $currentLine = $w
        }
    }

    if (-not [string]::IsNullOrEmpty($currentLine)) {
        $wrappedLines += $currentLine
    }

    return $wrappedLines
}

# --- Obsidian-Style Terminal Markdown Engine ---
function Format-MarkdownInline {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return "" }

    $res = $Text

    # 1. Obsidian WikiLinks: [[Target]] or [[Target|Label]]
    $res = [regex]::Replace($res, '\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]', {
        param($m)
        $label = if ($m.Groups[2].Success -and -not [string]::IsNullOrEmpty($m.Groups[2].Value)) { $m.Groups[2].Value } else { $m.Groups[1].Value }
        return "$cAmber[[$cOrange$label$cAmber]]$rst$cSilver"
    })

    # 2. Standard Markdown Links: [Label](url)
    $res = [regex]::Replace($res, '\[([^\]]+)\]\(([^)]+)\)', {
        param($m)
        $label = $m.Groups[1].Value
        return "$cOrange$label$cDarkGray$uArrowUpR$rst$cSilver"
    })

    # 3. Inline code: `code`
    $res = [regex]::Replace($res, '`([^`]+)`', {
        param($m)
        $c = $m.Groups[1].Value
        return "$cCodeBg$cAmber $c $rst$cSilver"
    })

    # 4. Bold: **text** or __text__
    $res = [regex]::Replace($res, '(?:\*\*|__)(.*?)(?:\*\*|__)', {
        param($m)
        $b = $m.Groups[1].Value
        return "$cWhite$sBold$b$sNoBold$cSilver"
    })

    # 5. Obsidian Highlight: ==text==
    $res = [regex]::Replace($res, '==(.*?)==', {
        param($m)
        $h = $m.Groups[1].Value
        return "$esc[48;2;85;60;10m$cOrange $h $rst$cSilver"
    })

    # 6. Italic: *text*
    $res = [regex]::Replace($res, '(?<!\*)\*([^\*]+)\*(?!\*)', {
        param($m)
        $it = $m.Groups[1].Value
        return "$sItalic$it$sNoItalic"
    })

    # 7. Strikethrough: ~~text~~
    $res = [regex]::Replace($res, '~~(.*?)~~', {
        param($m)
        $st = $m.Groups[1].Value
        return "$cGray$sStrike$st$sNoStrike$cSilver"
    })

    return $res
}

function Convert-MarkdownToTerminalLines {
    param(
        [string[]]$RawLines,
        [int]$Width = 80
    )

    if (-not $RawLines -or $RawLines.Count -eq 0) { return @() }

    $out = @()
    $inCodeBlock = $false
    $codeLang = ""
    $inFrontmatter = $false
    $frontmatterLines = @()
    $lineIdx = 0

    # 1. Parse YAML Frontmatter / Obsidian Properties Card
    if ($RawLines.Count -gt 0 -and $RawLines[0].Trim() -eq "---") {
        $inFrontmatter = $true
        $lineIdx = 1
        while ($lineIdx -lt $RawLines.Count) {
            $fLine = $RawLines[$lineIdx]
            if ($fLine.Trim() -eq "---") {
                $lineIdx++
                $inFrontmatter = $false
                break
            }
            $frontmatterLines += $fLine
            $lineIdx++
        }

        if ($frontmatterLines.Count -gt 0) {
            $titleStr = " Properties "
            $dashes = [Math]::Max(2, $Width - 17)
            $out += ($cDarkGray + " " + $uRoundTL + $uHoriz + $cOrange + $titleStr + $cDarkGray + ($uHoriz * $dashes) + $uRoundTR + $rst)
            foreach ($fl in $frontmatterLines) {
                if ($fl -match '^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)') {
                    $key = $matches[1]
                    $val = $matches[2].Trim('"', "'", ' ')
                    $valDisp = if ($val) { $val } else { "" }
                    if ($valDisp.Length -gt ($Width - 16)) { $valDisp = $valDisp.Substring(0, $Width - 19) + "..." }
                    $keyPad = "{0,-8}" -f $key
                    $contentLen = 13 + $valDisp.Length
                    $padLen = [Math]::Max(0, $Width - 2 - $contentLen)
                    $pad = " " * $padLen
                    $out += ($cDarkGray + " " + $uVert + " " + $cGray + $keyPad + $cDarkGray + ": " + $cWhite + (Format-MarkdownInline $valDisp) + $pad + $cDarkGray + $uVert + $rst)
                } elseif ($fl -match '^\s*-\s+(.*)') {
                    $itemText = $matches[1]
                    if ($itemText.Length -gt ($Width - 13)) { $itemText = $itemText.Substring(0, $Width - 16) + "..." }
                    $contentLen = 7 + $itemText.Length
                    $padLen = [Math]::Max(0, $Width - 2 - $contentLen)
                    $pad = " " * $padLen
                    $out += ($cDarkGray + " " + $uVert + "   " + $cAmber + "$uBullet " + $cSilver + (Format-MarkdownInline $itemText) + $pad + $cDarkGray + $uVert + $rst)
                }
            }
            $out += ($cDarkGray + " " + $uRoundBL + ($uHoriz * [Math]::Max(2, $Width - 4)) + $uRoundBR + $rst)
            $out += ""
        }
    }

    $activeCalloutType = $null
    $activeCalloutColor = $null

    for ($i = $lineIdx; $i -lt $RawLines.Count; $i++) {
        $line = $RawLines[$i]

        # Fenced Code Blocks (```powershell)
        if ($line -match '^\s*```([A-Za-z0-9_-]*)') {
            if (-not $inCodeBlock) {
                $inCodeBlock = $true
                $codeLang = $matches[1]
                $tag = if ($codeLang) { " $codeLang " } else { " Code " }
                $dashes = [Math]::Max(2, $Width - 5 - $tag.Length)
                $out += ($cDarkGray + " " + $uRoundTL + $uHoriz + $cOrange + $tag + $cDarkGray + ($uHoriz * $dashes) + $uRoundTR + $rst)
            } else {
                $inCodeBlock = $false
                $out += ($cDarkGray + " " + $uRoundBL + ($uHoriz * [Math]::Max(2, $Width - 4)) + $uRoundBR + $rst)
            }
            continue
        }

        if ($inCodeBlock) {
            $codeStr = $line
            if ($codeStr.Length -gt ($Width - 6)) {
                $codeStr = $codeStr.Substring(0, $Width - 6)
            }
            $contentLen = 3 + $codeStr.Length
            $padLen = [Math]::Max(0, $Width - 2 - $contentLen)
            $pad = " " * $padLen
            $out += ($cDarkGray + " " + $uVert + " " + $cAmber + $codeStr + $pad + $cDarkGray + $uVert + $rst)
            continue
        }

        # Obsidian Callouts: > [!NOTE] or > [!TIP]
        if ($line -match '^\s*>\s*\[!([A-Za-z0-9_-]+)\]\s*(.*)') {
            $cType = $matches[1].ToUpper()
            $cTitle = $matches[2]
            $color = $cOrange
            switch ($cType) {
                { $_ -in @("TIP", "HINT", "SUCCESS", "DONE") } { $color = $cAmber }
                { $_ -in @("WARNING", "CAUTION", "DANGER", "BUG") } { $color = fg 255 100 30 }
                { $_ -in @("TODO", "QUESTION", "HELP") } { $color = $cSilver }
            }
            $activeCalloutType = $cType
            $activeCalloutColor = $color
            $hdr = if ($cTitle) { "$cType - $cTitle" } else { $cType }
            $out += (" " + $color + "$uBar " + $cWhite + $sBold + $hdr + $sNoBold + $rst)
            continue
        }

        if ($activeCalloutType -and $line -match '^\s*>\s*(.*)') {
            $cBody = $matches[1]
            $wrapped = @(Format-WordWrap -Text $cBody -Width ($Width - 5))
            foreach ($wb in $wrapped) {
                $out += (" " + $activeCalloutColor + "$uBar " + $cSilver + (Format-MarkdownInline $wb) + $rst)
            }
            continue
        } else {
            $activeCalloutType = $null
            $activeCalloutColor = $null
        }

        # Standard Blockquotes
        if ($line -match '^\s*>\s*(.*)') {
            $qBody = $matches[1]
            $wrapped = @(Format-WordWrap -Text $qBody -Width ($Width - 5))
            foreach ($wb in $wrapped) {
                $out += (" " + $cDarkGray + "$uVert " + $sItalic + $cSilver + (Format-MarkdownInline $wb) + $sNoItalic + $rst)
            }
            continue
        }

        # Checklists / Tasks
        if ($line -match '^\s*-\s+\[\s\]\s+(.*)') {
            $taskText = $matches[1]
            $wrapped = @(Format-WordWrap -Text $taskText -Width ($Width - 6))
            if ($wrapped.Count -gt 0) {
                $out += ("  " + $cOrange + "$uBoxUncheck " + $cWhite + (Format-MarkdownInline $wrapped[0]) + $rst)
                for ($k = 1; $k -lt $wrapped.Count; $k++) {
                    $out += ("    " + $cSilver + (Format-MarkdownInline $wrapped[$k]) + $rst)
                }
            }
            continue
        }

        if ($line -match '^\s*-\s+\[[xX]\]\s+(.*)') {
            $taskText = $matches[1]
            $wrapped = @(Format-WordWrap -Text $taskText -Width ($Width - 6))
            if ($wrapped.Count -gt 0) {
                $out += ("  " + $cAmber + "$uCheckMark " + $cGray + $sStrike + (Format-MarkdownInline $wrapped[0]) + $sNoStrike + $rst)
                for ($k = 1; $k -lt $wrapped.Count; $k++) {
                    $out += ("    " + $cGray + $sStrike + (Format-MarkdownInline $wrapped[$k]) + $sNoStrike + $rst)
                }
            }
            continue
        }

        # Headings
        if ($line -match '^#\s+(.*)') {
            $hText = $matches[1]
            if ($out.Count -gt 0 -and -not [string]::IsNullOrEmpty($out[-1])) { $out += "" }
            $out += (" " + $cOrange + "# " + $cWhite + $sBold + (Format-MarkdownInline $hText) + $sNoBold + $rst)
            $divLen = [Math]::Min($Width - 2, [Math]::Max(12, $hText.Length + 4))
            $out += (" " + $cDarkGray + ($uHoriz * $divLen) + $rst)
            continue
        }
        if ($line -match '^##\s+(.*)') {
            $hText = $matches[1]
            if ($out.Count -gt 0 -and -not [string]::IsNullOrEmpty($out[-1])) { $out += "" }
            $out += (" " + $cOrange + "## " + $cWhite + $sBold + (Format-MarkdownInline $hText) + $sNoBold + $rst)
            continue
        }
        if ($line -match '^###\s+(.*)') {
            $hText = $matches[1]
            if ($out.Count -gt 0 -and -not [string]::IsNullOrEmpty($out[-1])) { $out += "" }
            $out += (" " + $cAmber + "### " + $cSilver + $sBold + (Format-MarkdownInline $hText) + $sNoBold + $rst)
            continue
        }
        if ($line -match '^####\s+(.*)') {
            $hText = $matches[1]
            $out += (" " + $cGray + "#### " + $cSilver + (Format-MarkdownInline $hText) + $rst)
            continue
        }

        # Markdown Tables: | Col1 | Col2 |
        if ($line -match '^\s*\|(.+)\|\s*$') {
            $inner = $matches[1]
            if ($inner -match '^[\s\-:|]+$') {
                $out += ($cDarkGray + " " + $uMidLeft + ($uHoriz * [Math]::Min($Width - 4, 45)) + $uMidRight + $rst)
            } else {
                $cells = $inner -split '\|' | ForEach-Object { (Format-MarkdownInline $_.Trim()) }
                $out += ($cDarkGray + " " + $uVert + " " + ($cells -join ($cDarkGray + " " + $uVert + " " + $rst)) + " " + $cDarkGray + $uVert + $rst)
            }
            continue
        }

        # Horizontal Rules
        if ($line -match '^(---|\*\*\*|___)\s*$') {
            $out += (" " + $cDarkGray + ($uHoriz * [Math]::Min(50, $Width - 2)) + $rst)
            continue
        }

        # Bullet Lists
        if ($line -match '^\s*[-*+]\s+(.*)') {
            $bText = $matches[1]
            $wrapped = @(Format-WordWrap -Text $bText -Width ($Width - 5))
            if ($wrapped.Count -gt 0) {
                $out += ("  " + $cAmber + "$uBullet " + $cSilver + (Format-MarkdownInline $wrapped[0]) + $rst)
                for ($k = 1; $k -lt $wrapped.Count; $k++) {
                    $out += ("    " + $cSilver + (Format-MarkdownInline $wrapped[$k]) + $rst)
                }
            }
            continue
        }

        # Numbered Lists
        if ($line -match '^\s*(\d+\.)\s+(.*)') {
            $nNum = $matches[1]
            $nText = $matches[2]
            $wrapped = @(Format-WordWrap -Text $nText -Width ($Width - 6))
            if ($wrapped.Count -gt 0) {
                $out += ("  " + $cOrange + $nNum + " " + $cSilver + (Format-MarkdownInline $wrapped[0]) + $rst)
                for ($k = 1; $k -lt $wrapped.Count; $k++) {
                    $out += ("     " + $cSilver + (Format-MarkdownInline $wrapped[$k]) + $rst)
                }
            }
            continue
        }

        # Empty line
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($out.Count -gt 0 -and -not [string]::IsNullOrEmpty($out[-1])) {
                $out += ""
            }
            continue
        }

        # Regular Paragraph
        $wrapped = @(Format-WordWrap -Text $line -Width ($Width - 2))
        foreach ($wl in $wrapped) {
            $out += (" " + $cSilver + (Format-MarkdownInline $wl) + $rst)
        }
    }

    return $out
}

# --- Recursive Tree Builder ---
function Build-NotebookTreeItems {
    param(
        [string]$CurrentPath,
        [int]$Level = 0
    )

    $items = @()

    # 1. Subfolders first (sorted by SortMode: date or alpha)
    $rawSubDirs = Get-ChildItem -Path $CurrentPath -Directory -ErrorAction SilentlyContinue | 
                  Where-Object { $_.Name -notmatch '^\.(obsidian|git)$' }

    if ($script:SortMode -eq "alpha") {
        $subDirs = $rawSubDirs | Sort-Object Name
    } else {
        # Default: date (creation date descending)
        $subDirs = $rawSubDirs | Sort-Object CreationTime -Descending
    }

    foreach ($d in $subDirs) {
        $isExpanded = $script:ExpandedFolders.ContainsKey($d.FullName) -and $script:ExpandedFolders[$d.FullName]
        $noteCount = (Get-ChildItem -Path $d.FullName -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue | Measure-Object).Count

        $folderItem = [PSCustomObject]@{
            Type        = "Folder"
            Name        = $d.Name
            FullName    = $d.FullName
            Level       = $Level
            IsExpanded  = $isExpanded
            ItemCount   = $noteCount
        }
        $items += $folderItem

        if ($isExpanded) {
            $items += Build-NotebookTreeItems -CurrentPath $d.FullName -Level ($Level + 1)
        }
    }

    # 2. Markdown files in this directory (sorted by SortMode: date or alpha)
    $rawFiles = Get-ChildItem -Path $CurrentPath -File -Filter "*.md" -ErrorAction SilentlyContinue
    if ($script:SortMode -eq "alpha") {
        $files = $rawFiles | Sort-Object { Format-NoteTitle $_ }
    } else {
        # Default: date (creation date extracted from filename or file creation time, descending)
        $files = $rawFiles | Sort-Object { 
            if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})') { 
                $matches[1] + " " + $_.CreationTime.ToString("HH:mm:ss")
            } else { 
                $_.CreationTime.ToString("yyyy-MM-dd HH:mm:ss") 
            } 
        } -Descending
    }
    foreach ($f in $files) {
        $noteItem = [PSCustomObject]@{
            Type        = "Note"
            Name        = (Format-NoteTitle $f)
            FileName    = $f.Name
            FullName    = $f.FullName
            FileInfo    = $f
            Level       = $Level
        }
        $items += $noteItem
    }

    return $items
}

# --- Folder Creation Prompt ---
function New-FolderPrompt {
    param([string]$ParentDir = "")

    $targetParent = $NotesDir
    $skipPrompt = $false

    if (-not [string]::IsNullOrWhiteSpace($ParentDir) -and (Test-Path $ParentDir)) {
        $targetParent = $ParentDir
        $skipPrompt = $true
    }

    Clear-Host
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host ($cOrange + "                 CREATE NEW FOLDER                " + $rst)
    Write-Host "==================================================" -ForegroundColor DarkGray
    $relParent = if ($targetParent -eq $NotesDir) { "/" } else { $targetParent.Substring($NotesDir.Length).TrimStart('\', '/') }
    Write-Host " Parent: ~/Notes/$relParent" -ForegroundColor Gray
    Write-Host " Tip: Press Enter without a name or 'c' to cancel`n" -ForegroundColor DarkGray

    if (-not $skipPrompt) {
        $allDirs = Get-ChildItem -Path $NotesDir -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\\.(obsidian|git)($|\\)' }
        if ($allDirs -and $allDirs.Count -gt 0) {
            Write-Host "Where would you like to create this folder?" -ForegroundColor DarkGray
            Write-Host "  [1] / (Root ~/Notes)" -ForegroundColor White
            $i = 2
            foreach ($d in $allDirs) {
                $rel = $d.FullName.Substring($NotesDir.Length).TrimStart('\', '/')
                Write-Host ("  [{0}] {1}" -f $i, $rel) -ForegroundColor White
                $i++
            }
            Write-Host "Choice (press Enter for 1): " -ForegroundColor White -NoNewline
            $pChoice = Read-Host
            if ($pChoice -match '^\d+$') {
                $pIdx = [int]$pChoice - 2
                if ($pIdx -ge 0 -and $pIdx -lt $allDirs.Count) {
                    $targetParent = $allDirs[$pIdx].FullName
                }
            }
        }
    }

    Write-Host "`nEnter Folder Name: " -ForegroundColor White -NoNewline
    $folderName = Read-Host

    if ([string]::IsNullOrWhiteSpace($folderName) -or $folderName.Trim().ToLower() -in @("c", "cancel", ":q", "exit", "quit")) {
        Write-Host "Folder creation cancelled." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 600
        return $null
    }

    $safeName = ($folderName.Trim() -replace '[^\w\s-]', '' -replace '\s+', '-').Trim()
    $newFolderPath = Join-Path $targetParent $safeName

    if (Test-Path $newFolderPath) {
        Write-Host "Folder already exists: $safeName" -ForegroundColor Red
        Start-Sleep -Milliseconds 800
        return $null
    }

    New-Item -ItemType Directory -Path $newFolderPath -Force | Out-Null
    $script:ExpandedFolders[$newFolderPath] = $true
    Write-Host "`nCreated folder: $safeName" -ForegroundColor Green
    Start-Sleep -Milliseconds 700
    return $newFolderPath
}

# --- Rename Prompt (Folder or Note) ---
function Rename-ItemPrompt {
    param($Item)
    if (-not $Item -or -not (Test-Path $Item.FullName)) { return }

    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "                    RENAME                        " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Current: $($Item.Name)`n" -ForegroundColor Yellow

    if ($Item.Type -eq "Folder") {
        Write-Host "Enter new folder name (or 'c' to cancel): " -ForegroundColor Yellow -NoNewline
        $newName = Read-Host
        if ([string]::IsNullOrWhiteSpace($newName) -or $newName.Trim().ToLower() -in @("c", "cancel", ":q", "exit", "quit")) {
            Write-Host "Rename cancelled." -ForegroundColor DarkYellow
            Start-Sleep -Milliseconds 500
            return
        }

        $safeName = ($newName.Trim() -replace '[^\w\s-]', '' -replace '\s+', '-').Trim()
        $parent = Split-Path $Item.FullName -Parent
        $newPath = Join-Path $parent $safeName

        if (Test-Path $newPath) {
            Write-Host "A folder with that name already exists." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            return
        }

        Rename-Item -Path $Item.FullName -NewName $safeName
        if ($script:ExpandedFolders.ContainsKey($Item.FullName)) {
            $script:ExpandedFolders.Remove($Item.FullName)
            $script:ExpandedFolders[$newPath] = $true
        }
        Write-Host "`nRenamed folder to: $safeName" -ForegroundColor Green
        Start-Sleep -Milliseconds 600
    } else {
        Write-Host "Enter new note title (or 'c' to cancel): " -ForegroundColor Yellow -NoNewline
        $newName = Read-Host
        if ([string]::IsNullOrWhiteSpace($newName) -or $newName.Trim().ToLower() -in @("c", "cancel", ":q", "exit", "quit")) {
            Write-Host "Rename cancelled." -ForegroundColor DarkYellow
            Start-Sleep -Milliseconds 500
            return
        }

        $safeName = ($newName.Trim() -replace '[^\w\s-]', '' -replace '\s+', '-').ToLower()
        if (-not $safeName.EndsWith(".md")) { $safeName += ".md" }

        $parent = Split-Path $Item.FullName -Parent
        $newPath = Join-Path $parent $safeName

        if (Test-Path $newPath) {
            Write-Host "A note with that name already exists." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
            return
        }

        Rename-Item -Path $Item.FullName -NewName $safeName
        Write-Host "`nRenamed note to: $safeName" -ForegroundColor Green
        Start-Sleep -Milliseconds 600
    }
}

# --- Delete Prompt (Folder or Note) ---
function Delete-ItemPrompt {
    param($Item)
    if (-not $Item -or -not (Test-Path $Item.FullName)) { return }

    Clear-Host
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "                   DELETE ITEM                    " -ForegroundColor Red
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host ""

    if ($Item.Type -eq "Folder") {
        $childFiles = Get-ChildItem -Path $Item.FullName -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue
        if ($childFiles -and $childFiles.Count -gt 0) {
            Write-Host " [!] WARNING: Folder '$($Item.Name)' contains $($childFiles.Count) note(s)!" -ForegroundColor Yellow -BackgroundColor DarkRed
            Write-Host "`n Are you SURE you want to delete this folder and ALL its notes? (y/N): " -ForegroundColor Red -NoNewline
        } else {
            Write-Host " [!] DELETE EMPTY FOLDER: '$($Item.Name)'" -ForegroundColor Yellow -BackgroundColor DarkRed
            Write-Host "`n Are you sure you want to delete this empty folder? (y/N): " -ForegroundColor Red -NoNewline
        }

        $confirm = Read-Host
        if ($confirm.Trim().ToLower() -in @("y", "yes")) {
            Remove-Item -Path $Item.FullName -Recurse -Force
            if ($script:ExpandedFolders.ContainsKey($Item.FullName)) {
                $script:ExpandedFolders.Remove($Item.FullName)
            }
            Write-Host "`n Folder deleted: $($Item.Name)" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 600
        } else {
            Write-Host "`n Deletion cancelled." -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 400
        }
    } else {
        Write-Host " [!] DELETE NOTE: '$($Item.FileName)'" -ForegroundColor Yellow -BackgroundColor DarkRed
        Write-Host "`n Are you sure you want to delete this note? (y/N): " -ForegroundColor Red -NoNewline
        $confirm = Read-Host
        if ($confirm.Trim().ToLower() -in @("y", "yes")) {
            Remove-Item -Path $Item.FullName -Force
            Write-Host "`n Note deleted: $($Item.FileName)" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 600
        } else {
            Write-Host "`n Deletion cancelled." -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 400
        }
    }
}

function New-InteractiveNote {
    param(
        [string]$InitialTitle = "",
        [string]$DestinationDir = ""
    )

    $targetDir = $NotesDir
    $skipFolderPrompt = $false
    if (-not [string]::IsNullOrWhiteSpace($DestinationDir) -and (Test-Path $DestinationDir)) {
        $targetDir = $DestinationDir
        $skipFolderPrompt = $true
    }

    Clear-Host
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host ($cOrange + "                CREATE A NEW NOTE                 " + $rst)
    Write-Host "==================================================" -ForegroundColor DarkGray
    $relTarget = if ($targetDir -eq $NotesDir) { "/" } else { $targetDir.Substring($NotesDir.Length).TrimStart('\', '/') }
    Write-Host " Folder: ~/Notes/$relTarget" -ForegroundColor Gray
    Write-Host " Tip: Press Enter with an empty title or type 'c' to cancel`n" -ForegroundColor DarkGray

    $title = $InitialTitle
    if ([string]::IsNullOrWhiteSpace($title)) {
        Write-Host "Enter Note Title: " -ForegroundColor White -NoNewline
        $title = Read-Host
    }

    if ([string]::IsNullOrWhiteSpace($title) -or $title.Trim().ToLower() -in @("c", "cancel", ":q", "exit", "quit")) {
        Write-Host "Note creation cancelled." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 600
        return $null
    }

    # Only ask for destination folder if not already predetermined/contextual
    if (-not $skipFolderPrompt) {
        $subDirs = Get-ChildItem -Path $NotesDir -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\\.(obsidian|git)($|\\)' }
        if ($subDirs -and $subDirs.Count -gt 0) {
            Write-Host "`nWhere would you like to save this note?" -ForegroundColor DarkGray
            Write-Host "  [1] / (Root ~/Notes)" -ForegroundColor White
            $di = 2
            foreach ($sd in $subDirs) {
                $rel = $sd.FullName.Substring($NotesDir.Length).TrimStart('\', '/')
                Write-Host ("  [{0}] {1}/" -f $di, $rel) -ForegroundColor White
                $di++
            }
            Write-Host "Choice (press Enter for 1): " -ForegroundColor White -NoNewline
            $dirChoice = Read-Host
            if ($dirChoice -match '^\d+$') {
                $idx = [int]$dirChoice - 2
                if ($idx -ge 0 -and $idx -lt $subDirs.Count) {
                    $targetDir = $subDirs[$idx].FullName
                }
            }
        }
    }

    $safeTitle = ($title.Trim() -replace '[^\w\s-]', '' -replace '\s+', '-').ToLower()
    $datePrefix = (Get-Date).ToString("yyyy-MM-dd")
    $fileName = "$datePrefix-$safeTitle.md"
    $filePath = Join-Path $targetDir $fileName

    $count = 1
    while (Test-Path $filePath) {
        $fileName = "$datePrefix-$safeTitle-$count.md"
        $filePath = Join-Path $targetDir $fileName
        $count++
    }

    $ed = Get-PreferredTerminalEditor
    $edName = if ($ed) { Split-Path $ed -Leaf } else { $null }

    Write-Host "`nWhere would you like to write?" -ForegroundColor DarkGray
    if ($ed) {
        Write-Host "  [1] Inside Terminal (using $edName)" -ForegroundColor White
        Write-Host "  [2] Open in Obsidian" -ForegroundColor White
        Write-Host "  [3] Quick text entry in terminal" -ForegroundColor White
        Write-Host "  [4] Open in Windows Notepad" -ForegroundColor DarkGray
    } else {
        Write-Host "  [1] Open in Obsidian" -ForegroundColor White
        Write-Host "  [2] Quick text entry in terminal" -ForegroundColor White
        Write-Host "  [3] Open in Windows Notepad" -ForegroundColor DarkGray
    }
    Write-Host "  [C] Cancel" -ForegroundColor DarkGray
    Write-Host "Choice (press Enter for 1, or 'c' to cancel): " -ForegroundColor White -NoNewline
    $inputChoice = Read-Host

    if ($inputChoice.Trim().ToLower() -in @("c", "cancel", "q", "exit", "quit")) {
        Write-Host "Note creation cancelled." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 600
        return $null
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $initialContent = "---`r`ntitle: `"$title`"`r`ndate: $timestamp`r`ntags:`r`n  - note`r`n---`r`n`r`n# $title`r`n`r`n"

    $selectedAction = "terminal"
    if ($ed) {
        switch ($inputChoice.Trim()) {
            "2" { $selectedAction = "obsidian" }
            "3" { $selectedAction = "quicktext" }
            "4" { $selectedAction = "notepad" }
            default { $selectedAction = "terminal" }
        }
    } else {
        switch ($inputChoice.Trim()) {
            "2" { $selectedAction = "quicktext" }
            "3" { $selectedAction = "notepad" }
            default { $selectedAction = "obsidian" }
        }
    }

    switch ($selectedAction) {
        "obsidian" {
            Set-Content -Path $filePath -Value $initialContent -Encoding UTF8
            Open-InObsidian -File (Get-Item $filePath)
            Write-Host "Created note in Obsidian: $fileName" -ForegroundColor Green
            Start-Sleep -Milliseconds 700
        }
        "notepad" {
            Set-Content -Path $filePath -Value $initialContent -Encoding UTF8
            if ($IsWindows) {
                Start-Process notepad.exe -ArgumentList "`"$filePath`"" -Wait
            } else {
                Start-Process open -ArgumentList "-W", "`"$filePath`"" -Wait
            }
            Write-Host "Saved note: $fileName" -ForegroundColor Green
            Start-Sleep -Milliseconds 700
        }
        "quicktext" {
            Write-Host "`nEnter note text below." -ForegroundColor DarkCyan
            Write-Host "(Press Enter on an empty line to save, or type ':cancel' to abort)" -ForegroundColor DarkGray
            Write-Host ""
            $lines = @()
            $wasCancelled = $false
            while ($true) {
                $line = Read-Host
                if ($line.Trim().ToLower() -in @(":c", ":cancel", ":q", ":abort")) {
                    $wasCancelled = $true
                    break
                }
                if ([string]::IsNullOrEmpty($line)) {
                    break
                }
                $lines += $line
            }

            if ($wasCancelled) {
                Write-Host "`nNote creation cancelled. Nothing was saved." -ForegroundColor DarkYellow
                Start-Sleep -Milliseconds 700
                return $null
            }

            $body = if ($lines.Count -gt 0) { $lines -join "`r`n" } else { "*(No content)*" }
            $fullContent = $initialContent + $body + "`r`n"
            Set-Content -Path $filePath -Value $fullContent -Encoding UTF8
            Write-Host "`nSaved: $fileName" -ForegroundColor Green
            Start-Sleep -Milliseconds 800
        }
        default {
            Set-Content -Path $filePath -Value $initialContent -Encoding UTF8
            Invoke-TerminalEditor -EditorPath $ed -FilePath $filePath -GoToEnd
            Write-Host "Saved note: $fileName" -ForegroundColor Green
            Start-Sleep -Milliseconds 700
        }
    }

    return $filePath
}

function Quick-Log {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Host "`nEnter quick thought (or press Enter to cancel): " -ForegroundColor Yellow -NoNewline
        $Text = Read-Host
    }
    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.Trim().ToLower() -in @("c", "cancel", ":q", "exit", "quit")) {
        Write-Host "Cancelled." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 500
        return
    }

    $today = (Get-Date).ToString("yyyy-MM-dd")
    $fileName = "$today-quick-log.md"
    $filePath = Join-Path $NotesDir $fileName

    $time = (Get-Date).ToString("HH:mm")
    if (-not (Test-Path $filePath)) {
        $header = "# Daily Quick Log ($today)`r`n`r`n"
        Set-Content -Path $filePath -Value $header -Encoding UTF8
    }

    $entry = "- **[$time]** $Text"
    Add-Content -Path $filePath -Value $entry -Encoding UTF8
    Write-Host "Added to: $fileName" -ForegroundColor Green
    Start-Sleep -Milliseconds 800
}

function Append-ToNote {
    param([System.IO.FileInfo]$File)
    if (-not $File -or -not (Test-Path $File.FullName)) { return }

    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "             APPEND TO: $($File.Name)             " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Type your new lines below." -ForegroundColor DarkCyan
    Write-Host " (Press Enter on an empty line to finish, or ':cancel' to abort)`n" -ForegroundColor DarkGray

    $lines = @()
    $wasCancelled = $false
    while ($true) {
        $line = Read-Host
        if ($line.Trim().ToLower() -in @(":c", ":cancel", ":q", ":abort")) {
            $wasCancelled = $true
            break
        }
        if ([string]::IsNullOrEmpty($line)) {
            break
        }
        $lines += $line
    }

    if ($wasCancelled) {
        Write-Host "`nCancelled. Note unchanged." -ForegroundColor DarkYellow
        Start-Sleep -Milliseconds 600
        return
    }

    if ($lines.Count -gt 0) {
        $toAppend = "`r`n" + ($lines -join "`r`n")
        Add-Content -Path $File.FullName -Value $toAppend -Encoding UTF8
        Write-Host "`nAdded $($lines.Count) line(s) to $($File.Name)" -ForegroundColor Green
        Start-Sleep -Milliseconds 700
    }
}

function Edit-NoteFile {
    param([System.IO.FileInfo]$File)
    if (-not $File -or -not (Test-Path $File.FullName)) { return }

    $terminalEditor = Get-PreferredTerminalEditor

    Clear-Host
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host ($cOrange + "                  EDIT NOTE                       " + $rst)
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host " Note: $($File.Name)`n" -ForegroundColor White

    Write-Host "How would you like to edit?" -ForegroundColor DarkGray
    if ($terminalEditor) {
        $edName = Split-Path $terminalEditor -Leaf
        Write-Host "  [1] Inside Terminal (using $edName)" -ForegroundColor White
        Write-Host "  [2] Open in Obsidian" -ForegroundColor White
        Write-Host "  [3] Append lines in Terminal (no editor needed)" -ForegroundColor White
        Write-Host "  [4] Open in Windows Notepad" -ForegroundColor DarkGray
    } else {
        Write-Host "  [1] Open in Obsidian" -ForegroundColor White
        Write-Host "  [2] Append lines in Terminal (no editor needed)" -ForegroundColor White
        Write-Host "  [3] Open in Windows Notepad" -ForegroundColor DarkGray
    }
    Write-Host "  [C] Cancel" -ForegroundColor DarkGray
    Write-Host "`nChoice (press Enter for 1, or 'c' to cancel): " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host

    if ($choice.Trim().ToLower() -in @("c", "cancel", "q", "exit", "quit")) {
        return
    }

    if ($terminalEditor) {
        switch ($choice.Trim()) {
            "2" {
                Open-InObsidian -File $File
            }
            "3" {
                Append-ToNote -File $File
            }
            "4" {
                if ($IsWindows) {
                    Start-Process notepad.exe -ArgumentList "`"$($File.FullName)`"" -Wait
                } else {
                    Start-Process open -ArgumentList "-W", "`"$($File.FullName)`"" -Wait
                }
            }
            default {
                Invoke-TerminalEditor -EditorPath $terminalEditor -FilePath $File.FullName -GoToEnd
            }
        }
    } else {
        switch ($choice.Trim()) {
            "2" {
                Append-ToNote -File $File
            }
            "3" {
                if ($IsWindows) {
                    Start-Process notepad.exe -ArgumentList "`"$($File.FullName)`"" -Wait
                } else {
                    Start-Process open -ArgumentList "-W", "`"$($File.FullName)`"" -Wait
                }
            }
            default {
                Open-InObsidian -File $File
            }
        }
    }
}

function View-FullscreenNote {
    param(
        [System.IO.FileInfo]$File,
        [switch]$ReadOnly
    )
    if (-not $File -or -not (Test-Path $File.FullName)) { return }

    $termW = 80
    try {
        if ([Console]::WindowWidth -gt 20) { $termW = [Console]::WindowWidth - 2 }
    } catch {}

    $borderLine = "=" * [Math]::Min(120, $termW)
    $divLine    = "-" * [Math]::Min(120, $termW)

    Clear-Host
    Write-Host $borderLine -ForegroundColor DarkGray
    $modeTag = if ($ReadOnly) { $cGray + " [Read-Only]" } else { "" }
    Write-Host ($cOrange + " Fullscreen Reader: " + $rst + $cWhite + $File.Name + $modeTag + $rst)
    Write-Host (" Path: " + $cGray + $File.FullName + $rst)
    Write-Host $borderLine -ForegroundColor DarkGray
    Write-Host ""

    $lines = Get-Content -Path $File.FullName
    $textWidth = [Math]::Max(30, $termW - 2)
    $renderedLines = Convert-MarkdownToTerminalLines -RawLines $lines -Width $textWidth

    foreach ($rl in $renderedLines) {
        [Console]::WriteLine($rl)
    }

    Write-Host "`n$borderLine" -ForegroundColor DarkGray
    if ($ReadOnly) {
        Write-Host ($cGray + " [Any key]" + $cSilver + " Return..." + $rst)
        try {
            [Console]::ReadKey($true) | Out-Null
        } catch {}
    } else {
        Write-Host ($cOrange + " [E]" + $cSilver + " Edit  " + $cOrange + "[O]" + $cSilver + " Obsidian  " + $cOrange + "[P]" + $cSilver + " Append  " + $cGray + "[Any other key]" + $cSilver + " Return..." + $rst)
        try {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq "E") {
                Edit-NoteFile -File $File
            } elseif ($k.Key -eq "O") {
                Open-InObsidian -File $File
            } elseif ($k.Key -in @("A", "P")) {
                Append-ToNote -File $File
            }
        } catch {}
    }
}

function Search-NotesPrompt {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host ($cOrange + "                SEARCH IN NOTES                   " + $rst)
    Write-Host "==================================================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Enter search query: " -ForegroundColor White -NoNewline
    $Query = Read-Host
    if ([string]::IsNullOrWhiteSpace($Query)) { return }

    $allNotes = Get-AllNotes
    $matches = $allNotes | Select-String -Pattern $Query

    if (-not $matches) {
        Write-Host "`nNo notes found matching '$Query'." -ForegroundColor DarkGray
    } else {
        Write-Host "`nMatches found for '$Query':" -ForegroundColor White
        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
        $grouped = $matches | Group-Object -Property Path
        foreach ($g in $grouped) {
            $f = Get-Item $g.Name
            $rel = $f.FullName.Substring($NotesDir.Length).TrimStart('\', '/')
            Write-Host ("`n" + $cOrange + "* " + $rel + $rst)
            foreach ($m in $g.Group) {
                Write-Host ("   Line {0}: {1}" -f $m.LineNumber, $m.Line.Trim()) -ForegroundColor White
            }
        }
    }
    Write-Host "`nPress Enter to return to notebook..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

function Start-NotebookBrowser {
    $selectedIndex = 0
    $pendingSelectPath = $null
    $script:needsFullClear = $true

    function Invoke-Modal([scriptblock]$action) {
        try { [Console]::CursorVisible = $true } catch {}
        [Console]::Write("$esc[?25h")
        & $action
        $script:needsFullClear = $true
        try { [Console]::CursorVisible = $false } catch {}
        [Console]::Write("$esc[?25l")
    }

    $previewScrollOffset = 0
    $lastSelectedIndex = -1
    $script:lastBoxHeight = 0
    $script:lastTermWidth = 0

    try {
        while ($true) {
            # Build visible hierarchical tree items
            $treeItems = Build-NotebookTreeItems -CurrentPath $NotesDir -Level 0

        if (-not $treeItems) { $treeItems = @() }

        if ($pendingSelectPath) {
            for ($ti = 0; $ti -lt $treeItems.Count; $ti++) {
                if ($treeItems[$ti].FullName -eq $pendingSelectPath) {
                    $selectedIndex = $ti
                    break
                }
            }
            $pendingSelectPath = $null
        }

        if ($selectedIndex -ge $treeItems.Count) {
            $selectedIndex = [Math]::Max(0, $treeItems.Count - 1)
        }

        # Terminal dimensions
        $termWidth = 100
        $termHeight = 26
        try {
            if ([Console]::WindowWidth -gt 50) { $termWidth = [Console]::WindowWidth }
            if ([Console]::WindowHeight -gt 15) { $termHeight = [Console]::WindowHeight }
        } catch {}

        # Geometry calculations (Total box width = termWidth = 1 + leftWidth + 1 + rightWidth + 1)
        $leftWidth = [Math]::Max(30, [Math]::Min(38, [Math]::Floor($termWidth * 0.35)))
        $rightWidth = $termWidth - $leftWidth - 3
        if ($rightWidth -lt 25) { $rightWidth = 25 }
        $usableWidth = [Math]::Max(20, $rightWidth - 3)

        # Active item preview content
        $previewLines = @()
        $currentRightTitle = "No selection"
        $activeItem = if ($treeItems.Count -gt 0 -and $selectedIndex -lt $treeItems.Count) { $treeItems[$selectedIndex] } else { $null }

        if ($activeItem) {
            if ($activeItem.Type -eq "Folder") {
                $currentRightTitle = "Folder: " + $activeItem.Name

                $miniWidth = [Math]::Min(46, $rightWidth - 6)
                if ($miniWidth -lt 24) { $miniWidth = 24 }

                $folderTitle = ".  *  +    FOLDER TELEMETRY    +  *  ."
                $titlePad = " " * [Math]::Max(0, [int](($miniWidth - $folderTitle.Length) / 2))
                $previewLines += ("  " + $titlePad + (Render-GradientText $folderTitle $gWaveDark $gWaveOrange))

                $waveTopMini = "  " + (Render-AuroraWave $miniWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2584))
                $waveMidMini = "  " + (Render-AuroraWave $miniWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2588))
                $waveBotMini = "  " + (Render-AuroraWave $miniWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2580))
                $previewLines += $waveTopMini
                $previewLines += $waveMidMini
                $previewLines += $waveBotMini
                $previewLines += ""

                $statusStr = if ($activeItem.IsExpanded) { "Open [v]" } else { "Closed [>]" }
                $shortName = Truncate-String -Str $activeItem.Name -MaxLen ($miniWidth - 18)
                $noteCountStr = if ($activeItem.ItemCount -gt 0) { "$($activeItem.ItemCount) note(s)" } else { "0 notes (empty)" }
                $relPath = $activeItem.FullName.Substring($NotesDir.Length).TrimStart('\', '/')
                if ([string]::IsNullOrEmpty($relPath)) { $relPath = "/" }
                $shortRelPath = Truncate-String -Str ("~/Notes/" + $relPath) -MaxLen ($miniWidth - 18)

                $cardBorder = fg 110 115 130
                $cardTop = $cardBorder + "  $bTopLeft" + ($bHoriz * ($miniWidth - 2)) + "$bTopRight" + $rst
                $cardBot = $cardBorder + "  $bBotLeft" + ($bHoriz * ($miniWidth - 2)) + "$bBotRight" + $rst

                $previewLines += $cardTop
                $previewLines += (Make-CardLine "Folder" $shortName $cWhite $miniWidth)
                $previewLines += (Make-CardLine "Status" $statusStr $cOrange $miniWidth)
                $previewLines += (Make-CardLine "Contents" $noteCountStr $cWhite $miniWidth)
                $previewLines += (Make-CardLine "Path" $shortRelPath $cGray $miniWidth)
                $previewLines += $cardBot
                $previewLines += ""

                $folderFiles = Get-ChildItem -Path $activeItem.FullName -File -Filter "*.md" -ErrorAction SilentlyContinue
                $previewLines += ("  " + $cOrange + "Notes Inside:" + $rst)
                if ($folderFiles -and $folderFiles.Count -gt 0) {
                    foreach ($ff in $folderFiles) {
                        $cleanTitle = Format-NoteTitle $ff
                        $previewLines += ("    " + $cWhite + "* " + $cleanTitle + $rst)
                    }
                } else {
                    $previewLines += ("    " + $cGray + "*(No notes yet in this folder)*" + $rst)
                }
                $previewLines += ""
                $previewLines += ("  " + $cOrange + "Folder Actions:" + $rst)
                $previewLines += ("    " + $cOrange + "[W/S] " + $cSilver + "Move  " + $cOrange + "[A/D] " + $cSilver + "Folders  " + $cOrange + "[R] " + $cSilver + "Rename  " + $cOrange + "[X] " + $cSilver + "Delete" + $rst)
            } else {
                # Note
                $currentRightTitle = $activeItem.FileName
                if (Test-Path $activeItem.FullName) {
                    $rawLines = Get-Content -Path $activeItem.FullName -TotalCount 500
                    $previewLines = @(Convert-MarkdownToTerminalLines -RawLines $rawLines -Width $usableWidth)
                }
            }
        }

        # Fixed full-terminal layout: expands to fill full window height so interface never jumps
        $boxHeight = [Math]::Max(10, $termHeight - 8)

        if ($boxHeight -ne $script:lastBoxHeight -or $termWidth -ne $script:lastTermWidth) {
            $script:needsFullClear = $true
            $script:lastBoxHeight = $boxHeight
            $script:lastTermWidth = $termWidth
        }

        # Reset preview scroll when selecting a new item
        if ($selectedIndex -ne $lastSelectedIndex) {
            $previewScrollOffset = 0
            $lastSelectedIndex = $selectedIndex
        }

        $maxPreviewScroll = [Math]::Max(0, $previewLines.Count - $boxHeight)
        if ($previewScrollOffset -gt $maxPreviewScroll) {
            $previewScrollOffset = $maxPreviewScroll
        }

        # Scrolling window for items list
        $scrollOffset = 0
        if ($selectedIndex -ge $boxHeight) {
            $scrollOffset = $selectedIndex - $boxHeight + 1
        }

        # Assemble Frame in Memory (Flicker-Free Double-Buffering)
        $sb = New-Object System.Text.StringBuilder

        # 1. Header Banner (Graphite to Flame Orange Horizon)
        $starTitle = ".  *  +     TERMINAL NOTEBOOK v$AppVersion     +  *  ."
        $starPad = " " * [Math]::Max(0, [int](($termWidth - $starTitle.Length) / 2))
        [void]$sb.AppendLine($starPad + (Render-GradientText $starTitle $gWaveDark $gWaveOrange))

        $barWidth = [Math]::Max(10, $termWidth - 2)
        [void]$sb.AppendLine(" " + (Render-AuroraWave $barWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2584)))
        [void]$sb.AppendLine(" " + (Render-AuroraWave $barWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2588)))
        [void]$sb.AppendLine(" " + (Render-AuroraWave $barWidth $gWaveDark $gWaveOrange $gWaveAmber ([string][char]0x2580)))

        # 2. Box Header (100% Aligned Math)
        $sortTag = if ($script:SortMode -eq "alpha") { "A-Z" } else { "Date" }
        $leftTitle = " Notes ($sortTag) "
        $leftDashes = $leftWidth - $leftTitle.Length - 1
        if ($leftDashes -lt 0) {
            $leftTitle = Truncate-String -Str $leftTitle -MaxLen ($leftWidth - 1)
            $leftDashes = 0
        }

        $scrollNotice = ""
        if ($previewLines.Count -gt $boxHeight) {
            $visEnd = [Math]::Min($previewLines.Count, $previewScrollOffset + $boxHeight)
            $scrollNotice = " [$($previewScrollOffset + 1)-$visEnd of $($previewLines.Count)] "
        }

        $maxRightTitleLen = [Math]::Max(10, $rightWidth - 14 - $scrollNotice.Length)
        $cleanRightTitle = Truncate-String -Str $currentRightTitle -MaxLen $maxRightTitleLen
        $rightTitle = " Preview: " + $cleanRightTitle + $scrollNotice + " "
        $rightDashes = $rightWidth - $rightTitle.Length - 1
        if ($rightDashes -lt 0) {
            $rightTitle = Truncate-String -Str $rightTitle -MaxLen ($rightWidth - 1)
            $rightDashes = 0
        }

        [void]$sb.Append($cDarkGray + $bTopLeft + $bHoriz + $cOrange + $leftTitle + $cDarkGray + ($bHoriz * $leftDashes) + $bTopT + $bHoriz + $cWhite + $rightTitle + $cDarkGray + ($bHoriz * $rightDashes) + $bTopRight + $rst + "`r`n")

        # 3. Render Rows
        for ($r = 0; $r -lt $boxHeight; $r++) {
            $itemIdx = $scrollOffset + $r
            $isRowSelected = ($itemIdx -eq $selectedIndex) -and ($treeItems.Count -gt 0)

            # Left column formatting
            $leftStr = ""
            $isFolderRow = $false
            if ($itemIdx -lt $treeItems.Count) {
                $cur = $treeItems[$itemIdx]
                if ($cur.Type -eq "Folder") {
                    $isFolderRow = $true
                    $indent = "  " * $cur.Level
                    $arrow = if ($cur.IsExpanded) { "$gArrowDown " } else { "$gArrowRight " }
                    $icon = if ($cur.IsExpanded) { "$gFolderOpen " } else { "$gFolderClosed " }
                    $countLabel = " ($($cur.ItemCount))"
                    $maxNameLen = $leftWidth - $indent.Length - 7 - $countLabel.Length
                    $dispName = Truncate-String -Str $cur.Name -MaxLen $maxNameLen
                    $leftStr = "$indent$arrow$icon$dispName$countLabel"
                } else {
                    $indent = "  " * ($cur.Level + 1)
                    $icon = "$gFileIcon "
                    $maxNameLen = $leftWidth - $indent.Length - 5
                    $dispName = Truncate-String -Str $cur.Name -MaxLen $maxNameLen
                    $leftStr = "$indent$icon$dispName"
                }
                $leftStr = $leftStr.PadRight($leftWidth)
                if ($leftStr.Length -gt $leftWidth) { $leftStr = $leftStr.Substring(0, $leftWidth) }
            } else {
                $leftStr = "".PadRight($leftWidth)
            }

            # Right column formatting
            $rightStr = ""
            $isAnsi = $false
            $isHeader = $false
            $isBullet = $false
            $isDivider = $false
            $isMeta = $false
            $isArt = $false

            $pIndex = $previewScrollOffset + $r
            if ($pIndex -lt $previewLines.Count -and $previewLines[$pIndex] -ne $null) {
                $pLine = $previewLines[$pIndex]
                if ($pLine.Contains([char]27)) {
                    $isAnsi = $true
                    $plain = $pLine -replace "\x1b\[[0-9;]*m", ""
                    if ($plain.Length -gt $rightWidth) {
                        $plain = $plain.Substring(0, $rightWidth)
                    }
                    $padCount = [Math]::Max(0, $rightWidth - $plain.Length)
                    $rightStr = $pLine + $rst + (" " * $padCount)
                } else {
                    if ($pLine -match '^#+\s+(.*)' -or $pLine -match '^[=]+$') {
                        $isHeader = $true
                        $rightStr = " " + $pLine.Trim()
                    } elseif ($pLine -match '^---') {
                        $isDivider = $true
                        $rightStr = " " + ($bHoriz * ($rightWidth - 4))
                    } elseif ($pLine -match '^\s*-\s+(.*)') {
                        $isBullet = $true
                        $rightStr = " * " + ($pLine -replace '^\s*-\s+', '').Trim()
                    } elseif ($pLine -match '^(title|date|tags|Location):') {
                        $isMeta = $true
                        $rightStr = "   " + $pLine.Trim()
                    } elseif ($pLine -match '^\s*(\.T\.|\s*\[[o\^_\-][o\^_\-][o\^_\-]\]|/\|\[_\]\|\\|\s*\|\s{3}\|\s*\\|\s*d\s+b|\.----|''----)') {
                        $isArt = $true
                        $rightStr = " " + $pLine.TrimEnd()
                    } else {
                        $rightStr = " " + $pLine.TrimEnd()
                    }
                    $rightStr = Truncate-String -Str $rightStr -MaxLen ($rightWidth - 1)
                    $rightStr = $rightStr.PadRight($rightWidth)
                }
            } else {
                $rightStr = "".PadRight($rightWidth)
            }

            # Draw row into buffer
            [void]$sb.Append($cDarkGray + $bVert + $rst)

            if ($isRowSelected) {
                [void]$sb.Append($cSelected + $leftStr + $rst)
            } elseif ($isFolderRow) {
                [void]$sb.Append($cFolder + $leftStr + $rst)
            } else {
                [void]$sb.Append($cSilver + $leftStr + $rst)
            }

            [void]$sb.Append($cDarkGray + $bVert + $rst)

            if ($isAnsi) {
                [void]$sb.Append($rightStr)
            } elseif ($isHeader) {
                [void]$sb.Append($cOrange + $rightStr + $rst)
            } elseif ($isArt) {
                [void]$sb.Append($cAmber + $rightStr + $rst)
            } elseif ($isDivider) {
                [void]$sb.Append($cDarkGray + $rightStr + $rst)
            } elseif ($isBullet) {
                [void]$sb.Append($cAmber + $rightStr + $rst)
            } elseif ($isMeta) {
                [void]$sb.Append($cGray + $rightStr + $rst)
            } else {
                [void]$sb.Append($cWhite + $rightStr + $rst)
            }

            [void]$sb.Append($cDarkGray + $bVert + $rst + "`r`n")
        }

        # 4. Box Footer
        [void]$sb.AppendLine($cDarkGray + $bBotLeft + ($bHoriz * $leftWidth) + $bBotT + ($bHoriz * $rightWidth) + $bBotRight + $rst)

        # 5. Navigation Bar with Bright Orange Key Accents
        $scrollBadge = ""
        if ($previewLines.Count -gt $boxHeight) {
            $scrollBadge = $cOrange + "[J/K]" + $cSilver + " Scroll  "
        }
        $navBar = " " + $cOrange + "[W/S]" + $cSilver + " Move  " + 
                  $cOrange + "[A/D]" + $cSilver + " Folders  " + 
                  $scrollBadge + 
                  $cOrange + "[T]" + $cSilver + " Sort  " + 
                  $cOrange + "[Enter]" + $cSilver + " View  " + 
                  $cOrange + "[E]" + $cSilver + " Edit  " + 
                  $cOrange + "[O]" + $cSilver + " Obsidian`r`n" + 
                  " " + $cOrange + "[N]" + $cSilver + " Note  " + 
                  $cOrange + "[F]" + $cSilver + " Folder  " + 
                  $cOrange + "[V]" + $cSilver + " What's New  " + 
                  $cOrange + "[R]" + $cSilver + " Rename  " + 
                  $cOrange + "[X]" + $cSilver + " Del  " + 
                  $cOrange + "[Q]" + $cSilver + " Exit" + $rst + "$esc[J"
        [void]$sb.Append($navBar)

        # 6. Atomic Write to Terminal (Zero-Flicker)
        if ($script:needsFullClear) {
            Clear-Host
            $script:needsFullClear = $false
        } else {
            try { [Console]::SetCursorPosition(0, 0) } catch {}
            [Console]::Write("$esc[H")
        }
        [Console]::Write($sb.ToString())

        # Read Keystroke
        try {
            $key = [Console]::ReadKey($true)
        } catch {
            break
        }

        switch ($key.Key) {
            { $_ -in @("UpArrow", "W") } {
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            }
            { $_ -in @("DownArrow", "S") } {
                if ($selectedIndex -lt ($treeItems.Count - 1)) { $selectedIndex++ }
            }
            "PageUp" {
                if ($previewLines.Count -gt $boxHeight) {
                    $previewScrollOffset = [Math]::Max(0, $previewScrollOffset - [Math]::Max(1, $boxHeight - 3))
                } else {
                    $selectedIndex = [Math]::Max(0, $selectedIndex - 6)
                }
            }
            "PageDown" {
                if ($previewLines.Count -gt $boxHeight) {
                    $previewScrollOffset = [Math]::Min($maxPreviewScroll, $previewScrollOffset + [Math]::Max(1, $boxHeight - 3))
                } else {
                    $selectedIndex = [Math]::Min([Math]::Max(0, $treeItems.Count - 1), $selectedIndex + 6)
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
            { $_ -in @("RightArrow", "D") } {
                if ($activeItem -and $activeItem.Type -eq "Folder") {
                    $script:ExpandedFolders[$activeItem.FullName] = $true
                }
            }
            { $_ -in @("LeftArrow", "A") } {
                if ($activeItem) {
                    if ($activeItem.Type -eq "Folder" -and $activeItem.IsExpanded) {
                        $script:ExpandedFolders[$activeItem.FullName] = $false
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
                if ($activeItem) {
                    if ($activeItem.Type -eq "Folder") {
                        # Toggle expand/collapse
                        $newState = -not ($script:ExpandedFolders.ContainsKey($activeItem.FullName) -and $script:ExpandedFolders[$activeItem.FullName])
                        $script:ExpandedFolders[$activeItem.FullName] = $newState
                    } else {
                        Invoke-Modal { View-FullscreenNote (Get-Item $activeItem.FullName) }
                    }
                }
            }
            "V" {
                $releaseNotesPath = Join-Path $PSScriptRoot "RELEASE_NOTES.md"
                if (Test-Path $releaseNotesPath) {
                    Invoke-Modal { View-FullscreenNote -File (Get-Item $releaseNotesPath) -ReadOnly }
                }
            }
            "E" {
                if ($activeItem -and $activeItem.Type -eq "Note") {
                    Invoke-Modal { Edit-NoteFile -File (Get-Item $activeItem.FullName) }
                }
            }
            "O" {
                if ($activeItem -and $activeItem.Type -eq "Note") {
                    Open-InObsidian -File (Get-Item $activeItem.FullName)
                }
            }
            "P" {
                if ($activeItem -and $activeItem.Type -eq "Note") {
                    Invoke-Modal { Append-ToNote -File (Get-Item $activeItem.FullName) }
                }
            }
            "T" {
                if ($script:SortMode -eq "date") {
                    $script:SortMode = "alpha"
                } else {
                    $script:SortMode = "date"
                }
                try {
                    @{ SortMode = $script:SortMode } | ConvertTo-Json | Set-Content -Path $notesConfigFile -Encoding UTF8
                } catch {}
            }
            "N" {
                $targetFolder = $NotesDir
                if ($activeItem) {
                    if ($activeItem.Type -eq "Folder") {
                        $targetFolder = $activeItem.FullName
                    } elseif ($activeItem.Type -eq "Note") {
                        $targetFolder = Split-Path -Parent $activeItem.FullName
                    }
                }
                if ($targetFolder -and (Test-Path $targetFolder)) {
                    $script:ExpandedFolders[$targetFolder] = $true
                }
                $createdPath = $null
                Invoke-Modal { $script:createdPath = New-InteractiveNote -DestinationDir $targetFolder }
                if ($script:createdPath) {
                    $pendingSelectPath = $script:createdPath
                }
            }
            "F" {
                $targetParent = $NotesDir
                if ($activeItem) {
                    if ($activeItem.Type -eq "Folder") {
                        $targetParent = $activeItem.FullName
                    } elseif ($activeItem.Type -eq "Note") {
                        $targetParent = Split-Path -Parent $activeItem.FullName
                    }
                }
                if ($targetParent -and (Test-Path $targetParent)) {
                    $script:ExpandedFolders[$targetParent] = $true
                }
                $createdFolder = $null
                Invoke-Modal { $script:createdFolder = New-FolderPrompt -ParentDir $targetParent }
                if ($script:createdFolder) {
                    $pendingSelectPath = $script:createdFolder
                }
            }
            "R" {
                if ($activeItem) {
                    Invoke-Modal { Rename-ItemPrompt -Item $activeItem }
                }
            }
            { $_ -in @("X", "Delete") } {
                if ($activeItem) {
                    Invoke-Modal { Delete-ItemPrompt -Item $activeItem }
                }
            }
            "L" {
                Invoke-Modal { Quick-Log }
            }
            "Oem2" { # '/' key
                Invoke-Modal { Search-NotesPrompt }
            }
            { $_ -in @("V", "B") } { # Open Notes folder in File Explorer (Vault / Browse)
                Invoke-Item $NotesDir
            }
            "Escape" {
                return
            }
            "Q" {
                return
            }
            default {
                # Ignore unrecognized keys
            }
        }
    }
    } finally {
        try { [Console]::CursorVisible = $true } catch {}
        [Console]::Write("$esc[?25h")
        Clear-Host
    }
}

# --- CLI Argument Processing ---
$allArgs = if ($ArgsList) { ($ArgsList -join " ") } else { "" }

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
        "log" {
            Quick-Log -Text $allArgs
            return
        }
        "quick" {
            Quick-Log -Text $allArgs
            return
        }
        "obsidian" {
            $notes = Get-AllNotes
            $target = $allArgs
            if ([string]::IsNullOrWhiteSpace($target)) {
                if ($notes -and $notes.Count -gt 0) { Open-InObsidian -File $notes[0] }
            } else {
                $match = $notes | Where-Object { $_.BaseName -like "*$target*" -or $_.FullName -like "*$target*" } | Select-Object -First 1
                if ($match) { Open-InObsidian -File $match }
            }
            return
        }
        "list" {
            $notes = Get-AllNotes
            if (-not $notes) {
                Write-Host "No notes found in $NotesDir" -ForegroundColor DarkYellow
                return
            }
            Write-Host ("{0,-4}  {1,-36}  {2,-18}" -f "#", "Path & Title", "Last Modified") -ForegroundColor Cyan
            Write-Host ("{0,-4}  {1,-36}  {2,-18}" -f "-", "------------", "-------------") -ForegroundColor DarkGray
            $i = 1
            foreach ($n in $notes) {
                $rel = $n.FullName.Substring($NotesDir.Length).TrimStart('\', '/')
                $display = Truncate-String -Str $rel -MaxLen 36
                $mod = $n.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                Write-Host ("{0,-4}  {1,-36}  {2,-18}" -f "[$i]", $display, $mod) -ForegroundColor White
                $i++
            }
            return
        }
        "view" {
            $notes = Get-AllNotes
            $target = $allArgs
            $selectedFile = $null
            if ($target -match '^\d+$') {
                $idx = [int]$target - 1
                if ($idx -ge 0 -and $idx -lt $notes.Count) { $selectedFile = $notes[$idx] }
            } else {
                $selectedFile = $notes | Where-Object { $_.BaseName -like "*$target*" -or $_.FullName -like "*$target*" } | Select-Object -First 1
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
            Invoke-Item $NotesDir
            return
        }
        "help" {
            Write-Host "Terminal Notes & Notebook Usage:" -ForegroundColor Cyan
            Write-Host "  note                      Open Notebook Browser (interactive tree view)"
            Write-Host "  note `"quick thought`"      Instantly append a thought to today's log"
            Write-Host "  note new [title]          Create a new markdown note"
            Write-Host "  note folder               Create a new folder"
            Write-Host "  note list                 List all notes and subfolders"
            Write-Host "  note view <#>             View note in fullscreen reader"
            Write-Host "  note obsidian [name]      Open note in Obsidian"
            Write-Host "  note search               Search inside notes"
            Write-Host "  note open                 Open Notes folder in File Explorer"
            return
        }
        default {
            $fullNote = "$Command $allArgs".Trim()
            Quick-Log -Text $fullNote
            return
        }
    }
}

# Default action when typing `note` or `notes`: Open the Notebook Browser!
Start-NotebookBrowser
