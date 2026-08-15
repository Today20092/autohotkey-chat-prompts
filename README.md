# ChatGPT Prompt Quick Menu (AutoHotkey)

![Windows](https://img.shields.io/badge/Windows-11_compatible-0078D7?style=for-the-badge&logo=windows11&logoColor=white)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2-334455?style=for-the-badge&logo=autohotkey&logoColor=white)](https://www.autohotkey.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-install--ready-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![GitHub](https://img.shields.io/badge/GitHub-Public_Repo-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/)
[![MIT License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

> **Work in progress:** Core prompt workflow is working, and it’s intentionally compact. Clone it, fork it, and adapt it to your own Windows prompt workflow.

## Why I made this

I built this because I kept doing the same thing manually: copy text into a chat prompt, tweak wording, paste, and repeat.  
This tool gives Windows users a fast, local shortcut menu for the prompts you actually use every day.

I also call it *abhorrent* because this was built with pragmatic shortcuts and zero patience for ceremony:

- It lives as `.txt` files on disk for easy editing.
- It uses one global menu entry instead of a full app framework.
- It stays intentionally tiny and transparent so people can modify it in minutes.

## What it does

- Saves and edits prompt templates as local `.txt` files.
- Replaces `<clipboard>` placeholders with current clipboard content before pasting.
- Shows a quick system-tray menu (default shortcut: `Ctrl + Alt + P`).
- Lets you add, rename, edit, and delete prompts from a GUI manager.
- Lets you rebind the menu shortcut at any time.
- Stores all prompts + settings under your user profile (no sync or cloud dependency).

## Repository contents

- `src/ChatGPT_Prompts.ahk`  
  Core prompt manager logic (menus, editing, storage helpers).
- `src/ChatGPTPrompts.ahk`  
  Minimal launcher that initializes the tray app and shortcut.
- `scripts/install.ps1`  
  Install script that sets up files in a writable user folder, creates a startup shortcut, and can launch on first install.
- `scripts/build-exe.ps1`  
  Single-command helper to compile the script into an `.exe` with AutoHotkey.
- `Prompts/*.txt`  
  Optional starter prompt templates.
- `.github/workflows/release.yml`  
  Optional GitHub Actions workflow for building an `.exe` artifact.

## Quick install

### Option A — run from source with AutoHotkey installed

1. Install AutoHotkey v2.x.
2. Open PowerShell and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
./scripts/install.ps1 -RunNow
```

### Option B — one-shot remote install (once repository is public)

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Today20092/autohotkey-chat-prompts/main/scripts/install.ps1 | iex
```

## Manual usage

```text
ChatGPTPrompt menu shortcut (default): Ctrl+Alt+P
Tray menu:
  - Run prompt
  - Add New Prompt
  - Manage Prompts
  - Open Prompts Folder
  - Change Shortcut
```

On first run, prompts are created in:

`%APPDATA%\ChatGPTPrompts`

and initialized with two templates:

- `Grammar Rewrite.txt`
- `Compact Conversation.txt`

## Build `.exe` (AutoHotkey compiled)

With AutoHotkey v2 and `Ahk2Exe` on PATH:

```powershell
./scripts/build-exe.ps1
```

Output:

`dist\ChatGPTPrompts.exe`

If you prefer to keep it uncompiled, `install.ps1` can launch the script directly with `AutoHotkey.exe`.

## Privacy / public-repo safety

This repository is intended for public use and should not contain personal credentials.
Your actual prompts, clipboard content, and local settings are stored only under `%APPDATA%\ChatGPTPrompts`.

## License

MIT License. See [LICENSE](LICENSE).
