# Terminal Notebook

A blazingly fast, highly-aesthetic terminal-based notebook for browsing, writing, and organizing Markdown notes. It bridges the speed and workflow of the command line with the rich formatting and organizational power of modern note-taking apps like Obsidian.

![Terminal Notebook Main UI](docs/main-ui.png)


## 🌟 Key Features

### 🖥️ Immersive Terminal UI
* **Notebook Browser:** An interactive, zero-flicker TUI (Text User Interface) with fluid navigation (`W/A/S/D` or Arrow Keys).
* **Sleek Aesthetics:** Features rounded outer app borders, top-to-bottom Gray-to-Orange vertical gradients, and solid dark slate floating cards.
* **Inline Floating Modals:** Actions like creating notes (`N`), creating folders (`F`), logging quick thoughts (`L`), renaming (`R`), and deleting (`X`) open floating popup cards directly over the browser interface.
* **Fullscreen Reader:** Press `V` or `Enter` to read notes in a distraction-free fullscreen view with built-in scrolling controls.

![Fullscreen Reader](docs/fullscreen-reader.png)

### 📝 Rich Markdown Engine
* **Native Markdown Rendering:** Renders raw Markdown into rich terminal output, including YAML frontmatter cards, Obsidian callouts (`> [!NOTE]`), fenced code blocks, tables, checklists (`- [x]`), wiki-links, and highlights (`==text==`).

### ⚡ Seamless Editing Workflows
* **Split-Pane Editing (Windows Terminal):** Creating or editing a note automatically splits your terminal side-by-side so your folder tree stays visible.
* **Editor Auto-Discovery:** Detects and launches your preferred terminal editor (`hx`, `micro`, `nvim`, `vim`, or `nano`).
* **Quick Logging:** Append passing thoughts directly to today's daily log straight from your terminal (`note "My quick thought"`).

### 📚 Multi-Notebook Workspaces
* **Instant Workspace Switching:** Seamlessly switch between separate notebook folders (e.g., Work vs. Personal) with `B` or straight from the command line (`note work`).

### 🌌 Deep Obsidian Integration
* **Obsidian Sync & Launching:** Auto-detects Obsidian vaults and lets you launch any note directly into Obsidian desktop with `O`.

---

## 🚀 Installation & Setup

### Prerequisites
* **PowerShell**: 
  * **Windows:** Included by default (PowerShell 5.1+ supported).
  * **macOS:** Requires PowerShell Core (`brew install --cask powershell`).
* **Nerd Fonts:** Ensure your terminal uses a Nerd Font for folder and file icons to render correctly.
* **Terminal Editor:** I highly recommend installing [Helix](https://helix-editor.com/) (`winget install helix`) or [Micro](https://micro-editor.github.io/) for the best in-terminal editing experience.

### Setup
1. Clone this repository or download the `note.ps1` script to your system.
2. Open your PowerShell profile (`notepad $PROFILE`).
3. Add the following alias so you can launch the app from anywhere:
   ```powershell
   Set-Alias -Name note -Value "C:\path\to\terminal-notebook\note.ps1"
   ```

---

## 💻 CLI Commands & Usage

| Command | Action |
|---------|--------|
| `note` | Open interactive Notebook Browser in active workspace |
| `note <name\|path>` | Switch active workspace (e.g., `note work`) & launch browser |
| `note -Path <path>` | Launch directly into specific folder path |
| `note notebook list` | List all registered notebook workspaces |
| `note notebook switch <name\|path>` | Switch default active notebook workspace |
| `note notebook add <name> <path>` | Register a new notebook workspace |
| `note notebook remove <name>` | Remove notebook workspace from list |
| `note "quick thought"` | Quick log entry to today's daily log |
| `note new [title]` | Create a new Markdown note |
| `note list` | List all notes in current notebook with index numbers |
| `note view <#\|name>` | Open note in Fullscreen Reader |
| `note open` | Open active notebook folder in File Explorer / Finder |

---

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `W/S` or `Up/Dn` | Move selection up or down |
| `A/D` or `L/R` | Expand or collapse selected folder |
| `C` or `Shift+A/D` | Expand or collapse ALL folders |
| `J/K` or `PgUp/PgDn` | Scroll through long file previews |
| `Enter` | Expand Folders / View Note |
| `V` | Open Note in Fullscreen Reader |
| `E` | Edit Note (Split-Pane Editor) |
| `O` | Open Note in Obsidian Desktop |
| `N` | Create a New Note |
| `F` | Create a New Folder |
| `L` | Quick Log Thought (Inline Modal) |
| `B` | Switch Notebook Workspace (Work, Personal, etc.) |
| `R` | Rename Item |
| `X` or `Del` | Delete Item |
| `U` | View App Updates / Release Notes |
| `T` | Toggle Sorting (A-Z vs Date Modified) |
| `Q` or `Esc` | Exit |



