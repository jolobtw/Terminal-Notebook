# Terminal Notes

A terminal-based notebook for browsing, writing, and organizing Markdown notes. It combines the speed of the command line with the rich formatting of modern note-taking apps like Obsidian.

## Features

* **Terminal Markdown Rendering**: Natively parses and renders Markdown including Obsidian property cards, headers, blockquotes, Obsidian callouts (`> [!NOTE]`), checklists, fenced code blocks, tables, WikiLinks, and inline markdown (bold, italics, highlights, strikethroughs).
* **Collapsible Folder Hierarchy**: Navigate through your `~/Notes` folder seamlessly with an interactive terminal tree view.
* **Cross-Platform Compatibility**: Works identically on Windows and macOS via PowerShell Core (`pwsh`).
* **Seamless Split-Pane Editing**: When running within modern Windows Terminal, editing or creating a note automatically splits your current tab side-by-side, allowing you to edit in your preferred tool (`micro`, `nvim`, etc.) without losing context of your folder tree!
* **Obsidian Integration**: Deeply integrates with Obsidian. Create or open notes directly in Obsidian from the terminal, or edit them using terminal editors like `micro`, `nvim`, or `nano`.
* **Dynamic Layout**: The terminal interface dynamically resizes to fill your terminal window without flickering or artifacting. Long notes support `[J/K]` or `PageUp/PageDown` scrolling right in the preview pane.
* **Quick Logs & Appending**: Quickly append thoughts or daily logs without needing to open a full text editor.

## Prerequisites

* **PowerShell**: 
  * Windows: Included by default (PowerShell 5.1+ supported).
  * macOS: Requires PowerShell Core (`brew install --cask powershell`).
* **Nerd Fonts** (Optional but recommended): Ensure your terminal uses a Nerd Font for folder and file icons to render correctly.
* **Git** (Optional): For tracking and backing up notes.

## Installation

Simply clone this repository or download the `note.ps1` script to your system.

```bash
git clone https://github.com/josephdieringer-lang/TerminalNotes.git
cd TerminalNotes
```

## Usage

Run the script from your terminal:

```powershell
./note.ps1
```

Or map it to an alias in your PowerShell profile (`$PROFILE`):
```powershell
Set-Alias -Name note -Value "C:\path\to\TerminalNotes\note.ps1"
```

### Keyboard Navigation

* `[W/S]` or `Up/Down` - Move selection
* `[A/D]` - Expand/Collapse folders
* `[J/K]` or `PageUp/PageDown` - Scroll through long previews
* `[N]` - Create a new Note
* `[F]` - Create a new Folder
* `[R]` - Rename item
* `[X]` - Delete item
* `[E]` - Edit Note in Terminal
* `[O]` - Open in Obsidian
* `[Enter]` - Fullscreen Reader

## License
MIT License
