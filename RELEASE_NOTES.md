# Terminal Notes Release Notes

## Version 2.6.7
**Date:** 2026-10-02

### Keybindings
- **Release Notes Hotkey Fix:** Fixed a hotkey collision where mapping Release Notes to `W` interfered with `W/A/S/D` arrow-key navigation. "What's New" has been renamed to "Updates" and remapped to `U`.

## Version 2.6.6
**Date:** 2026-10-02

### Keybindings
- **Fullscreen Note:** Remapped `V` to open the currently selected Note in the Fullscreen Reader (adding a fast explicit alternative to `Enter`).
- **Release Notes:** Shifted the release notes hotkey from `V` to `W` (Reverted in 2.6.7).

## Version 2.6.5
**Date:** 2026-10-02

### UI Tweaks
- **File Tree Connectors:** Re-engineered the Notebook Browser rendering logic to dynamically draw structural tree connecting branches (`├─` and `└─`) for notes inside folders, significantly improving visual hierarchy and making it much easier to distinguish between root-level notes and nested notes.
- **Root Spacing:** The UI now intelligently inserts a blank "Spacer" item between the bottom of your folders and the beginning of your root-level notes, creating a clean visual break.

## Version 2.6.4
**Date:** 2026-10-02

### UI Tweaks
- **Header Spacing:** Added an empty line buffer beneath the main application header banner to prevent the sleek accent line from feeling too cramped against the UI elements below it.

## Version 2.6.3
**Date:** 2026-10-02

### UI Tweaks
- **Sleeker Header Banner:** Redesigned the main "Terminal Notebook" title banner. The text has been spaced out for a cleaner, modern look, and its gradient now shifts brightly from Flame Orange to Radiant Amber so it stands out. The thick 3-line horizontal gradient bar beneath it has been shrunk to a single sleek accent line (using lower-half terminal blocks) to reduce visual clutter without losing the signature aesthetic.

## Version 2.6.2
**Date:** 2026-10-02

### Bug Fixes
- **Editor Stale PATH Errors:** Fixed a major bug where Windows Terminal would fail to find the newly installed `hx` (or `micro`) executable and throw `error 2147942402 (0x80070002)`. Because the background `wt.exe` process evaluates commands using a stale `PATH` cache, the `Start-Process` launch command has been refactored to always pass the *absolute* path of the resolved terminal editor.
- **Start-Process Quoting:** Fixed an issue where editor paths and file paths containing spaces were not safely quoted when passed as a raw string to the Windows Terminal CLI.

## Version 2.6.1
**Date:** 2026-10-02

### Bug Fixes
- **Helix Path Parsing:** Fixed a bug where creating a new note or jumping to the end of an existing note caused a crash or error message. The script previously appended the line number to the file path using the `file:line` syntax, which caused Helix's internal parser to critically fail when trying to read Windows absolute paths containing drive letter colons (e.g., `C:\...`). The app now safely passes the line number using Helix's `+N` CLI flag.

## Version 2.6.0
**Date:** 2026-10-02

### Features & Tweaks
- **Helix Editor Support:** Replaced `micro` as the primary default terminal editor with the much faster and modern `hx` (Helix). The editor is fully integrated and instantly launches with soft-wrapping enabled, alongside a custom `.toml` colorscheme that perfectly perfectly mirrors the Terminal Notes UI for completely seamless side-by-side editing.

## Version 2.5.3
**Date:** 2026-10-02

### Bug Fixes
- **Split-Pane UI Jumbling:** Fixed a critical regression where opening the seamless split-pane editor (e.g., pressing `[N]` or `[E]` in Windows Terminal) caused the left-hand Notebook Browser to become completely jumbled. The UI layout engine previously ignored any terminal width smaller than 50 columns. When the pane split in half (often resulting in ~45-49 columns), the app forcefully rendered the UI at 100 columns, causing catastrophic text wrapping. The minimum width constraints have been drastically relaxed to cleanly support extremely narrow terminal panes.

## Version 2.5.2
**Date:** 2026-10-02

### Bug Fixes
- **Fullscreen Header Alignment:** Fixed a bug where entering the Fullscreen Reader caused the "TERMINAL NOTEBOOK" header text to subtly shift to the left. The Fullscreen Reader now calculates its viewport width identically to the main browser view, ensuring the top banner remains perfectly static and pixel-aligned across all views.

## Version 2.5.1
**Date:** 2026-10-02

### Bug Fixes
- **Fullscreen Reader Scroll Bleed:** Fixed a bug where entering the interactive Fullscreen Reader would still print an implicit trailing newline, causing the terminal window to scroll down by one line and hiding the top "Terminal Notebook" banner. The viewport now perfectly fits the screen height and anchors cleanly to the top without jumping.

## Version 2.5.0
**Date:** 2026-10-02

### Features & Tweaks
- **Interactive Fullscreen Reader:** Completely refactored the Fullscreen Reader (and in-app Release Notes viewer) to act as an interactive, scrollable pager. Long notes now cleanly start from the very top and can be freely navigated using `Up/Down` or `PageUp/PageDown`, rather than simply dumping text and forcing the console to scroll to the bottom.
- **Reverse Chronological Release Notes:** Reversed the order of `RELEASE_NOTES.md` so that the newest updates are always presented first at the top of the file.

## Version 2.4.0
**Date:** 2026-10-02

### Bug Fixes
- **UI Consistency:** Aligned the width and padding of the Folder Telemetry section with the Note Properties section, ensuring the right and left borders remain perfectly static and don't jump around when navigating between notes and folders.## Version 2.3.0
**Date:** 2026-10-02

### Bug Fixes
- **Terminal Flickering:** Fixed an issue where the entire terminal (mostly noticeable in the title bar) would flicker continuously. This was caused by the 25ms `Start-Sleep` polling loop triggering PowerShell's default progress bar rendering. The polling loop now explicitly silences progress bars to run invisibly.

## Version 2.2.0
**Date:** 2026-10-02

### Features & Tweaks
- **UI Consistency:** Applied the sleek, rounded gradient borders (previously only seen on the Folder Telemetry card) to all bordered elements throughout the note viewer! This includes Properties blocks, Fenced Code blocks, Markdown Tables, Blockquotes, and Horizontal Rules. The `Flame Orange -> Graphite` gradient now themes the entire application for a perfectly unified aesthetic.

## Version 2.1.1
**Date:** 2026-10-02

### Bug Fixes
- **Editor Cursor Placement:** Fixed an annoying bug where opening an existing note in a terminal editor (`micro`, `vim`, `nano`) would place the cursor on the last line containing text (the "last line -1"), rather than on the empty trailing newline. The script now parses the file natively, perfectly preserving trailing newlines and dropping your cursor at the absolute bottom of the file every time.

## Version 2.1.0
**Date:** 2026-10-02

### Features & Tweaks
- **Streamlined Workflow:** Removed the interstitial prompt when creating or editing a note. The application now seamlessly defaults to opening your preferred terminal editor (like `micro`). If no terminal editor is installed, it intelligently falls back to launching the note in Obsidian.
- **Native Theming:** When the application launches `micro`, it now automatically applies the `simple` color scheme to natively match the colors of your terminal environment.

## Version 2.0.1
**Date:** 2026-10-02

### Bug Fixes
- **Pane Split Tearing:** Fixed a race condition where launching the side-by-side terminal editor caused the Notebook Browser to redraw with its original full-width dimensions before the window could finish resizing, leading to catastrophic line wrapping.
- **Responsive Redraws:** Overhauled the navigation event loop. The app no longer completely halts while waiting for keystrokes; it now actively polls at 40hz, instantly detecting window size changes (such as when your right-hand split pane closes) and seamlessly repainting the UI back to full-screen.
- **ANSI Truncation Overflow:** Fixed a bug where colored text strings (like empty folder warnings or dynamic menus) bypassed the right boundary length constraints, shoving the UI border out of alignment on smaller windows.

## Version 2.0.0
**Date:** 2026-10-02

### Major Features
- **Seamless Split-Pane Editor (Windows Terminal Integration):** Completely revolutionized the editing workflow! When running the app inside Windows Terminal, pressing [E] to edit or [N] to create a new note will no longer hijack your screen. Instead, the app seamlessly signals Windows Terminal to split your current tab down the middle. Your Terminal Notebook remains fully active, scrollable, and usable on the left, while your deep-work text editor (micro, 
ano, 
vim) opens natively on the right. When you exit your editor, the split-pane vanishes and the tab intelligently merges back to full-screen. This is a massive quality-of-life buff for maintaining context, referencing file names, and reading old notes while writing new ones!

## Version 1.15
**Date:** 2026-10-02

### Features & Tweaks
- **Folder Telemetry Redesign:** Completely redesigned the Folder Telemetry card to visually match the sleek Properties box styling used in the Note Reader. The thick 3-line Aurora block graphic was replaced with a thin, gorgeous bounding box that spans the full width of the preview pane. To add visual contrast against the main application header, the telemetry box's gradient is rendered in reverse (Flame Orange to Graphite). 

## Version 1.14
**Date:** 2026-10-02

### Features & Tweaks
- **UI Consistency:** The top "Terminal Notebook" Aurora gradient banner is now preserved and displayed when diving into the Fullscreen Reader mode (including the Release Notes viewer). The hotkey formatting in the reader mode has also been restyled to exactly match the look of the main application menu.

## Version 1.13
**Date:** 2026-10-02

### Bug Fixes
- **Conflicting Keybinds:** Fixed a bug where returning from the Release Notes screen would automatically open File Explorer. The V key was originally bound to open the "Vault" in File Explorer, and when we re-assigned it to "What's New" (Release Notes), the old binding was never removed. Since PowerShell evaluates all matching conditions in a switch block, it was triggering both actions sequentially! Removed the old binding.

## Version 1.12
**Date:** 2026-10-02

### Bug Fixes
- **The Aurora Banner Overflow:** Discovered the actual root cause of the persistent terminal scrolling and clipping issues. When dynamically calculating the maximum terminal height for the main reading box, the logic completely forgot to subtract the physical height of the beautiful 4-line Aurora gradient banner introduced in 1.0. The UI bounding box was mathematically 4 lines too tall for the terminal, which forced it to constantly scroll and shove the top title bar completely off the screen! Fixed the box height subtraction engine to properly account for the banner.

## Version 1.11
**Date:** 2026-10-02

### Bug Fixes
- **Console Word-Wrap Clipping:** Discovered an ultra-specific boundary edge case: if the dynamic navigation bar happened to calculate a length that perfectly matched your exact terminal width, the Windows Console would implicitly wrap the cursor to a phantom new line *before* our code explicitly wrapped it. This injected an invisible blank line into the UI, throwing off the pixel-perfect layout math, causing the terminal to scroll down by 1 line, which shoved the top title bar off the screen. Refactored the math to wrap at Width - 1 to strictly forbid implicit console wrapping.

## Version 1.10
**Date:** 2026-10-02

### Bug Fixes
- **Garbled Array Flattening:** Fixed a bug where PowerShell's array-flattening behavior caused single-item menu additions (like the folder Expand key) to be split into individual characters, drastically expanding the menu.
- **Title Bar Overflow:** Re-tuned the height constraints (Max(5)) to prevent aggressive window resizing from causing the header to clip off the screen.
- **Flicker-Free Navigation:** Implemented a static "worst-case" menu padder. The application now perfectly anticipates the maximum height the responsive menu *could* take and locks the UI box to that height. This completely eradicates all layout bouncing and flickering when navigating between folders and notes.

## Version 1.9
**Date:** 2026-10-02

### Features & Tweaks
- **Context-Aware Navigation Bar:** The bottom navigation bar is now context-aware! Actions like [O] Obsidian, [E] Edit, and [Enter] View will only appear when you actually have a Note highlighted. When highlighting a Folder, the menu slims down and switches [Enter] to expand/collapse.
- **Dynamic Responsive Layout:** Re-wrote the terminal height and UI rendering logic. The navigation bar now perfectly wraps and dynamically scales the height of the main interface based on your terminal's width, preventing any lingering ghost menus or scroll-tearing on narrower terminal windows.

## Version 1.8
**Date:** 2026-10-02

### Bug Fixes
- **Electron Log Bleed (Absolute Fix):** Fixed the persistent Obsidian text bleed issue by passing the command through a hidden cmd.exe /c start sub-process with fully trapped standard I/O streams. The Electron auto-updater logs can no longer reach the host terminal under any circumstances.

## Version 1.7
**Date:** 2026-10-02

### Bug Fixes
- **Electron Log Bleed:** Fixed an issue where the Obsidian Electron app would inherit the terminal's standard output handles and dump its startup logs (e.g., auto-updater checks) directly into the Terminal Notes interface. We now explicitly use System.Diagnostics.ProcessStartInfo with ShellExecute to enforce complete background detachment.

## Version 1.6
**Date:** 2026-10-02

### Bug Fixes
- **UI Overflow:** Fixed a persistent issue where opening a note in Obsidian without a properly registered protocol handler caused a native PowerShell error stream to dump into the console, breaking the UI layout and leaving duplicate ghost menus. The launch command now properly swallows non-terminating errors.

## Version 1.5
**Date:** 2026-10-02

### Bug Fixes
- **UI Overflow:** Fixed an issue where opening a note in Obsidian directly from the navigation browser would print a success message to the bottom of the screen, causing the terminal window to shift upward and creating duplicate rows of the navigation bar. The Obsidian integration now launches silently in the background to prevent interface layout breaks.

## Version 1.4
**Date:** 2026-10-02

### Features & Tweaks
- **Read-Only Mode:** Added a -ReadOnly flag to the Fullscreen Reader.
- **Release Notes Protection:** The in-app release notes viewer now correctly launches in Read-Only mode to prevent accidental edits.

## Version 1.3
**Date:** 2026-10-02

### Bug Fixes
- **UI Overflow:** Fixed an issue where the delete confirmation prompt didn't clear the screen before appearing, causing the main browser UI to be pushed upward and off the screen. The delete prompt now launches cleanly in a fullscreen modal view matching the rest of the application's style.

## Version 1.2
**Date:** 2026-10-02

### Bug Fixes
- **UI Flickering:** Fixed an issue where the new navigation hotkeys caused the footer bar to exceed standard terminal widths, wrapping to a new line and triggering a scrolling flicker. The hotkeys are now cleanly organized across two lines, and the layout engine perfectly compensates for the height.

## Version 1.1
**Date:** 2026-10-02

### Bug Fixes
- **UI Rendering:** Fixed a visual bug where the right-hand border was missing from Markdown Properties blocks and Fenced Code blocks. They now dynamically scale and draw their right borders correctly based on terminal width.

## Version 1.0
**Date:** 2026-10-02

### Initial Release
- **Terminal Markdown Engine:** Built-in engine to natively render Obsidian-style markdown, including callouts, wikilinks, checklists, and property cards directly in the terminal.
- **Cross-Platform:** Full compatibility across Windows and macOS via PowerShell Core (`pwsh`).
- **Interactive UI:** Dynamically resizing dual-pane interface with folder navigation and note previewing.
- **Obsidian Integration:** Launch and edit notes directly inside Obsidian or preferred terminal editors (`micro`, `nvim`, `nano`).
- **Quick Logging:** Rapid text entry mode directly inside the terminal without needing to boot up a full editor.
- **Flicker-Free Rendering:** Optimized double-buffered screen rendering to prevent UI flashing during navigation.


