# =====================================================================
# Preview Banners for Terminal Notes
# Run this script in PowerShell / Windows Terminal to view live in 24-bit TrueColor!
# =====================================================================

$e = [char]27
$rst = "$e[0m"

function fg($r, $g, $b) { return "$e[38;2;$r;$g;${b}m" }
function bg($r, $g, $b) { return "$e[48;2;$r;$g;${b}m" }

# Helper to interpolate between two RGB colors
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
        $ratio = $i / ($len - 1.0)
        $rgb = Get-GradientColor $c1 $c2 $ratio
        $out += (fg $rgb[0] $rgb[1] $rgb[2]) + $text[$i]
    }
    return $out + $rst
}

Clear-Host
Write-Host "`n"
Write-Host "================================================================================" -ForegroundColor DarkGray
Write-Host "               TITLE BAR GRAPHIC CONCEPTS FOR YOUR NOTES APP                    " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# OPTION 1: Glowing Retro Gradient Wordmark (DeepMind Cyberpunk Gradient)
# -----------------------------------------------------------------------------
Write-Host "--- OPTION 1: Glowing Retro Gradient Wordmark ---" -ForegroundColor Yellow
Write-Host "Vibrant 24-bit TrueColor typography shifting from Neon Violet -> Azure Blue -> Electric Cyan`n" -ForegroundColor DarkGray

$violet = @(160, 32, 240)
$cyan   = @(0, 245, 212)

$logoLines = @(
    "  ___ ___ ___ __  __ ___ _  _   _   _     _  _  ___ _____ ___ ___ ",
    " |_ _| __| _ \  \/  |_ _| \| | /_\ | |   | \| |/ _ \_   _| __/ __|",
    "  | || _||   / |\/| || || .` |/ _ \| |__ | .` | (_) || | | _|\__ \",
    " |___|___|_|_\_|  |_|___|_|\_/_/ \_\____||_|\_|\___/ |_| |___|___/"
)

foreach ($line in $logoLines) {
    Write-Host (Render-GradientText -text $line -c1 $violet -c2 $cyan)
}
Write-Host (" " * 15 + (fg 120 120 140) + "Terminal Notebook  *  Vault: ~/Notes  *  [A-Z / Date]" + $rst)
Write-Host ""
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# OPTION 2: Shaded Pixel-Art Notebook with Glowing Pages
# -----------------------------------------------------------------------------
Write-Host "--- OPTION 2: Shaded Pixel-Art Hologram Notebook ---" -ForegroundColor Yellow
Write-Host "High-density pixel art with glowing cyan pages & stats badge`n" -ForegroundColor DarkGray

$gold    = fg 255 190 11
$leather = fg 150 75 0
$neon    = fg 76 201 240
$white   = fg 240 240 255
$dim     = fg 120 120 140

Write-Host ($gold + "    .-----------------------." + $rst)
Write-Host ($gold + "   /  " + $leather + "__________________   " + $gold + "/|" + $rst + "    " + $white + "[*] TERMINAL NOTEBOOK" + $rst)
Write-Host ($gold + "  +---" + $leather + "-------------------+" + $gold + " |" + $rst + "    " + $dim + "Vault  : " + $white + "~/Notes" + $rst)
Write-Host ($leather + "  |  " + $neon + "## NOTES ARCHIVE ##  " + $leather + "|" + $gold + " |" + $rst + "    " + $dim + "Status : " + $neon + "[Online]" + $rst)
Write-Host ($leather + "  |  " + $white + "=== Obsidian Vault == " + $leather + "|" + $gold + "/ " + $rst + "    " + $dim + "Items  : " + $white + "4 Notes  *  3 Folders" + $rst)
Write-Host ($gold + "  '-----------------------' " + $rst + "     " + $dim + "Hotkeys : " + $gold + "[W/S] Move  [A/D] Folders  [T] Sort" + $rst)

Write-Host ""
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# -----------------------------------------------------------------------------
# OPTION 3: Antigravity Cosmic Aurora Horizon (Closest to agy startup graphic)
# -----------------------------------------------------------------------------
Write-Host "--- OPTION 3: Antigravity Cosmic Aurora Horizon ---" -ForegroundColor Yellow
Write-Host "Multi-band 24-bit TrueColor wave with cosmic particles (inspired by agy)`n" -ForegroundColor DarkGray

$auroraPurple = @(80, 10, 160)
$auroraPink   = @(247, 37, 133)
$auroraBlue   = @(76, 201, 240)
$barWidth = 72

# Header line with stars
$starLine = "  .  *       +          TERMINAL NOTEBOOK          +       *  .  "
$padStars = " " * [Math]::Max(0, [int](($barWidth - $starLine.Length) / 2))
Write-Host ($padStars + (Render-GradientText -text $starLine -c1 $auroraPink -c2 $auroraBlue))

# Top half-block wave
$topBar = "  "
for ($i = 0; $i -lt $barWidth; $i++) {
    $t = $i / ($barWidth - 1.0)
    $col = if ($t -lt 0.5) { Get-GradientColor $auroraPurple $auroraPink ($t * 2) } else { Get-GradientColor $auroraPink $auroraBlue (($t - 0.5) * 2) }
    $topBar += (fg $col[0] $col[1] $col[2]) + [char]0x2584 # Lower half block
}
Write-Host ($topBar + $rst)

# Middle solid block core
$midBar = "  "
for ($i = 0; $i -lt $barWidth; $i++) {
    $t = $i / ($barWidth - 1.0)
    $col = if ($t -lt 0.5) { Get-GradientColor $auroraPurple $auroraPink ($t * 2) } else { Get-GradientColor $auroraPink $auroraBlue (($t - 0.5) * 2) }
    $r = [Math]::Min(255, [int]($col[0] * 1.15))
    $g = [Math]::Min(255, [int]($col[1] * 1.15))
    $b = [Math]::Min(255, [int]($col[2] * 1.15))
    $midBar += (fg $r $g $b) + [char]0x2588 # Full block
}
Write-Host ($midBar + $rst)

# Bottom half-block glow
$botBar = "  "
for ($i = 0; $i -lt $barWidth; $i++) {
    $t = $i / ($barWidth - 1.0)
    $col = if ($t -lt 0.5) { Get-GradientColor $auroraPurple $auroraPink ($t * 2) } else { Get-GradientColor $auroraPink $auroraBlue (($t - 0.5) * 2) }
    $botBar += (fg $col[0] $col[1] $col[2]) + [char]0x2580 # Upper half block
}
Write-Host ($botBar + $rst)

Write-Host (" " * 22 + (fg 120 120 140) + "Obsidian Vault: ~/Notes  *  Sort: [T]" + $rst)
Write-Host ""
Write-Host "================================================================================" -ForegroundColor DarkGray
Write-Host "Tip: Re-run this preview in your terminal anytime with: " -ForegroundColor DarkGray -NoNewline
Write-Host "powershell C:\Users\josep\Tools\TerminalNotes\preview_banners.ps1" -ForegroundColor White
Write-Host ""
