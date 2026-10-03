# Terminal Notes

A blazingly fast, highly-aesthetic terminal-based notebook for browsing, writing, and organizing Markdown notes. It bridges the speed and workflow of the command line with the rich formatting and organizational power of modern note-taking apps like Obsidian.

![Terminal Notes Main UI](docs/main-ui.png)


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
   Set-Alias -Name note -Value "C:\path\to\TerminalNotes\note.ps1"
   ```

---

## ⌨️ Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `W/S` or `Up/Dn` | Move selection up or down |
| `A/D` or `L/R` | Expand or collapse folders |
| `J/K` or `PgUp/PgDn` | Scroll through long file previews |
| `Enter` | Expand Folders |
| `V` | Open Note in Fullscreen Reader |
| `E` | Edit Note (Split-Pane Editor) |
| `O` | Open Note in Obsidian Desktop |
| `N` | Create a New Note |
| `F` | Create a New Folder |
| `R` | Rename Item |
| `X` or `Del` | Delete Item |
| `U` | View App Updates / Release Notes |
| `T` | Toggle Sorting (A-Z vs Date Modified) |
| `Q` or `Esc` | Exit |

---

## 📄 License
MIT License
