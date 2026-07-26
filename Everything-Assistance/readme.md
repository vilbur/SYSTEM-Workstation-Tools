# Everything Assistance - Help

## Overview

`Everything-Assistance.ahk` is an AutoHotkey v1 utility which integrates:

- Windows Open / Save dialogs
- File Explorer
- Total Commander
- Everything Search (`Everything.exe`)

The script automatically opens the Everything search window near file dialogs or manually near the mouse cursor.

Selected search results are returned back into the original application.

---

# Main Features

## Automatic Dialog Detection

The script continuously watches for standard Windows dialogs:

- Open
- Save
- Browse
- Select

When detected:

1. Everything is launched.
2. Everything window is aligned below the dialog.
3. The Everything window stays attached while the dialog moves.
4. The dialog is automatically repositioned if it would overlap the taskbar.

---

## Manual Trigger Mode

The script supports manual activation by launching the script with any parameter.

Example:

```bat
Everything-Assistance.ahk -manual
```

Behavior:

- If the script is already running, the new instance sends a message to the original instance.
- Everything opens near the mouse cursor.
- Running the command again toggles the Everything window closed.

---

## Smart Result Handling

When selecting a result from Everything:

### If target window is File Explorer

The current Explorer window navigates directly to the selected folder.

### If target window is Total Commander

External helper script is executed:

```text
D:\GoogleDrive\TotalComander\_TC-commands\file\go_to_path.ahk
```

### If target window is Open/Save dialog

The selected path is inserted into the dialog edit control.

---

# Hotkeys

## Shift + Enter

Inside Everything window:

```text
Shift + Enter
```

Actions:

1. Copies selected path from Everything.
2. Detects original window type.
3. Transfers selected path.
4. Returns focus to original window.

---

# Requirements

## AutoHotkey

Required:

- AutoHotkey v1

---

## Everything Search

Tested with:

```text
C:\Program Files\Everything 1.5a\Everything.exe
```

You may need to edit the script if Everything is installed elsewhere.

Locations to modify:

```ahk
Run, "C:\Program Files\Everything 1.5a\Everything.exe"
```

---

# Script Architecture

## 1. Parameter Detection

At startup:

- Detects whether parameters were passed.
- Sends custom message `0x5555` to already running instance.
- Exits trigger instance.

Main message handler:

```ahk
OnMessage(0x5555, "TriggerManualMode")
```

---

## 2. Dialog Watcher

Timer:

```ahk
SetTimer, DialogWatcher, 250
```

Responsibilities:

- Detect standard dialogs.
- Store original window.
- Store focused control.
- Launch Everything.
- Start alignment tracker.

---

## 3. Auto Alignment Tracker

Timer:

```ahk
SetTimer, AutoAlignTracker, 10
```

Responsibilities:

- Keep Everything aligned below dialog.
- Prevent overlap with taskbar.
- Move original dialog upward if needed.
- Close Everything when original dialog closes.

---

## 4. Manual Trigger Mode

Function:

```ahk
TriggerManualMode()
```

Responsibilities:

- Toggle Everything visibility.
- Open Everything near mouse cursor.
- Track original active window.
- Preserve focused control.

---

## 5. Selection Transfer

Hotkey block:

```ahk
#IfWinActive ahk_exe Everything.exe
```

Responsibilities:

- Copy selected result.
- Detect whether selection is file or directory.
- Navigate Explorer.
- Trigger Total Commander integration.
- Insert path into dialogs.

---

# Workflow Examples

## Open File Dialog

1. Application opens Open dialog.
2. Script detects dialog.
3. Everything appears below dialog.
4. Search file.
5. Press `Shift + Enter`.
6. Path is inserted into dialog.

---

## File Explorer Navigation

1. Activate Explorer.
2. Trigger manual mode.
3. Search folder.
4. Press `Shift + Enter`.
5. Explorer navigates to selected folder.

---

## Total Commander Navigation

1. Activate Total Commander.
2. Trigger manual mode.
3. Search folder.
4. Press `Shift + Enter`.
5. Helper script navigates Total Commander.

---

# Customization

## Everything Window Height

Variable:

```ahk
global eHeight := 400
```

Controls Everything window height.

---

## Window Padding

Variable:

```ahk
global padding := 0
```

Controls spacing between dialog and Everything window.

---

## Dialog Detection

Current detection pattern:

```ahk
if (wTitle ~= "i)(open|save|browse|select)")
```

You can extend this expression with additional keywords.

---

# Notes

## Clipboard Usage

The script temporarily uses clipboard during result transfer.

Selection copy command:

```ahk
Send, ^+c
```

This relies on Everything supporting:

```text
Ctrl + Shift + C
```

for copying full path.

---

## Folder vs File Handling

Behavior:

- If selection is folder:
  - use folder path directly

- If selection is file:
  - extract parent directory path

Implementation:

```ahk
if InStr(FileExist(Clipboard), "D")
```

---

## Explorer Navigation Method

Explorer navigation uses COM:

```ahk
ComObjCreate("Shell.Application")
```

This allows reusing the same Explorer window instead of opening a new one.

---

# Possible Improvements

## Suggestions

- Add configurable hotkeys.
- Add multi-monitor support.
- Add Everything IPC integration.
- Preserve clipboard contents.
- Add configurable executable paths.
- Add tray menu.
- Add exclusion rules.
- Add fuzzy search presets.
- Add configurable alignment side.
- Add support for Directory Opus.

---

# Troubleshooting

## Everything Does Not Open

Check:

- Everything installation path.
- Whether Everything.exe exists.
- Whether Everything can be started manually.

---

## Shift + Enter Does Nothing

Check:

- Everything window is active.
- Result is selected.
- Everything supports `Ctrl + Shift + C`.

---

## Total Commander Integration Does Not Work

Check helper script path:

```text
D:\GoogleDrive\TotalComander\_TC-commands\file\go_to_path.ahk
```

---

## Wrong Edit Control Is Filled

Current fallback:

```ahk
origCtrl := InStr(focusedCtrl, "Edit") ? focusedCtrl : "Edit1"
```

Some dialogs may use non-standard controls.

---

# Summary

This script provides:

- Fast filesystem navigation
- Everything integration into dialogs
- Explorer integration
- Total Commander integration
- Automatic dialog positioning
- Manual popup mode
- Lightweight workflow enhancement

