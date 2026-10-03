# Terminal Notebook

A blazingly fast, highly-aesthetic terminal-based notebook for browsing, writing, and organizing Markdown notes. It bridges the speed and workflow of the command line with the rich formatting and organizational power of modern note-taking apps like Obsidian.

![Terminal Notebook Main UI](docs/main-ui.png)


## 🌟 Key Features

### 🖥️ Immersive Terminal UI
* **Notebook Browser:** An interactive, zero-flicker TUI (Text User Interface) that reacts instantly to keystrokes.
* **Sleek Aesthetics:** Features beautifully styled Flame Orange to Radiant Amber gradient UIs, subtle Dark Gray tree connectors (`├─`, `└─`), and intelligent layout spacing for a clean, modern look.
* **Frictionless Navigation:** Use `W/A/S/D` or Arrow Keys to fluidly navigate your folder hierarchy. The layout engine intelligently bypasses visual spacers to save you keystrokes.
* **Dynamic Reflow:** The interface dynamically resizes to perfectly fill your terminal window without artifacting or line-wrapping destruction.

### 📝 Rich Markdown Engine
* **Native Terminal Rendering:** Renders raw Markdown directly into colorful terminal output.
* **Advanced Element Support:** Perfectly parses and renders YAML Property Cards (Frontmatter), Obsidian-style Callouts (`> [!NOTE]`), checklists (`- [x]`), blockquotes, tables, and fenced code blocks.
* **Inline Styling:** Supports Bold, Italics, Highlights (`==text==`), Strikethroughs, standard Markdown links, and Obsidian WikiLinks.
* **Fullscreen Reader:** Press `V` or `Enter` to drop into a distraction-free fullscreen reading environment with built-in scrolling.

![Fullscreen Reader](docs/fullscreen-reader.png)


### ⚡ Seamless Editing Workflows
* **Split-Pane Editing (Windows Terminal):** When running within modern Windows Terminal, creating or editing a note instantly splits your terminal side-by-side! Edit in your preferred tool without losing sight of your folder tree.
* **Editor Auto-Discovery:** Automatically detects and launches powerful terminal editors like `hx` (Helix), `micro`, `nvim`, `vim`, or `nano`.
* **Quick Logging:** Quickly append passing thoughts to your daily log straight from the command line (`note "My quick thought"`).

### 📚 Multi-Notebook Workspaces
* **Instant Workspace Switching:** Seamlessly switch between separate notebook folders (e.g., Work vs. Personal) with press of a key (`B`) or straight from the command line (`note work`).
* **Profile Aliases & Path Launching:** Launch directly into specific notebooks via CLI parameters (`note -Path ~/WorkNotes`) or named profile aliases.
* **Persistent Configuration:** Saved notebook profiles and your active workspace persist automatically in `~/.terminal_notebook.json`.

### 🌌 Deep Obsidian Integration
* **Vault Detection:** Automatically reads your macOS or Windows Obsidian configurations to perfectly sync with your Vault.
* **Direct Launching:** Press `O` on any note to instantly open it inside the native Obsidian desktop application.

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
| `Enter` | Expand Folders |
| `V` | Open Note in Fullscreen Reader |
| `E` | Edit Note (Split-Pane Editor) |
| `O` | Open Note in Obsidian Desktop |
| `N` | Create a New Note |
| `F` | Create a New Folder |
| `B` | Switch Notebook Workspace (Work, Personal, etc.) |
| `R` | Rename Item |
| `X` or `Del` | Delete Item |
| `U` | View App Updates / Release Notes |
| `T` | Toggle Sorting (A-Z vs Date Modified) |
| `Q` or `Esc` | Exit |



