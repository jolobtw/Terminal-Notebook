    $termWidth = [Console]::WindowWidth
    $termHeight = [Console]::WindowHeight
    $worstLines = 3
    $boxHeight = [Math]::Max(5, $termHeight - 5 - $worstLines)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("Line 1")
    [void]$sb.AppendLine("Line 2")
    [void]$sb.AppendLine("Line 3")

    for ($r = 0; $r -lt $boxHeight; $r++) {
        [void]$sb.AppendLine("Body $r")
    }
    [void]$sb.AppendLine("Footer")
    
    $navBar = "Nav 1
Nav 2
Nav 3"
    [void]$sb.Append($navBar)

    Clear-Host
    [Console]::Write($sb.ToString())
    $pos = [Console]::CursorTop
    Write-Host "

Final cursor pos: $pos"
