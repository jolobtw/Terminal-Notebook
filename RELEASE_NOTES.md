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
