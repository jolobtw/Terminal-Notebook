# Terminal Notes Release Notes

## Version 1.0
**Date:** 2026-10-02

### Initial Release
- **Terminal Markdown Engine:** Built-in engine to natively render Obsidian-style markdown, including callouts, wikilinks, checklists, and property cards directly in the terminal.
- **Cross-Platform:** Full compatibility across Windows and macOS via PowerShell Core (`pwsh`).
- **Interactive UI:** Dynamically resizing dual-pane interface with folder navigation and note previewing.
- **Obsidian Integration:** Launch and edit notes directly inside Obsidian or preferred terminal editors (`micro`, `nvim`, `nano`).
- **Quick Logging:** Rapid text entry mode directly inside the terminal without needing to boot up a full editor.
- **Flicker-Free Rendering:** Optimized double-buffered screen rendering to prevent UI flashing during navigation.

## Version 1.1
**Date:** 2026-10-02

### Bug Fixes
- **UI Rendering:** Fixed a visual bug where the right-hand border was missing from Markdown Properties blocks and Fenced Code blocks. They now dynamically scale and draw their right borders correctly based on terminal width.

## Version 1.2
**Date:** 2026-10-02

### Bug Fixes
- **UI Flickering:** Fixed an issue where the new navigation hotkeys caused the footer bar to exceed standard terminal widths, wrapping to a new line and triggering a scrolling flicker. The hotkeys are now cleanly organized across two lines, and the layout engine perfectly compensates for the height.

## Version 1.3
**Date:** 2026-10-02

### Bug Fixes
- **UI Overflow:** Fixed an issue where the delete confirmation prompt didn't clear the screen before appearing, causing the main browser UI to be pushed upward and off the screen. The delete prompt now launches cleanly in a fullscreen modal view matching the rest of the application's style.

## Version 1.4
**Date:** 2026-10-02

### Features & Tweaks
- **Read-Only Mode:** Added a -ReadOnly flag to the Fullscreen Reader.
- **Release Notes Protection:** The in-app release notes viewer now correctly launches in Read-Only mode to prevent accidental edits.

## Version 1.5
**Date:** 2026-10-02

### Bug Fixes
- **UI Overflow:** Fixed an issue where opening a note in Obsidian directly from the navigation browser would print a success message to the bottom of the screen, causing the terminal window to shift upward and creating duplicate rows of the navigation bar. The Obsidian integration now launches silently in the background to prevent interface layout breaks.

## Version 1.6
**Date:** 2026-10-02

### Bug Fixes
- **UI Overflow:** Fixed a persistent issue where opening a note in Obsidian without a properly registered protocol handler caused a native PowerShell error stream to dump into the console, breaking the UI layout and leaving duplicate ghost menus. The launch command now properly swallows non-terminating errors.

## Version 1.7
**Date:** 2026-10-02

### Bug Fixes
- **Electron Log Bleed:** Fixed an issue where the Obsidian Electron app would inherit the terminal's standard output handles and dump its startup logs (e.g., auto-updater checks) directly into the Terminal Notes interface. We now explicitly use System.Diagnostics.ProcessStartInfo with ShellExecute to enforce complete background detachment.

## Version 1.8
**Date:** 2026-10-02

### Bug Fixes
- **Electron Log Bleed (Absolute Fix):** Fixed the persistent Obsidian text bleed issue by passing the command through a hidden cmd.exe /c start sub-process with fully trapped standard I/O streams. The Electron auto-updater logs can no longer reach the host terminal under any circumstances.

## Version 1.9
**Date:** 2026-10-02

### Features & Tweaks
- **Context-Aware Navigation Bar:** The bottom navigation bar is now context-aware! Actions like [O] Obsidian, [E] Edit, and [Enter] View will only appear when you actually have a Note highlighted. When highlighting a Folder, the menu slims down and switches [Enter] to expand/collapse.
- **Dynamic Responsive Layout:** Re-wrote the terminal height and UI rendering logic. The navigation bar now perfectly wraps and dynamically scales the height of the main interface based on your terminal's width, preventing any lingering ghost menus or scroll-tearing on narrower terminal windows.
