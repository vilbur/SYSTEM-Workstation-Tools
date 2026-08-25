# Everything Assistance

Everything Assistance connects Everything Search with Windows dialogs, File Explorer, and Total Commander.

**Index**

- [Overview and purpose](#overview-and-purpose)
- [Usage](#usage)
- [Installation](#installation)
- [Troubleshooting](#troubleshooting)
- [Development notes](#development-notes)

---

## Overview and purpose

Use Everything to find a file or folder, then send the selected result back to:

- an Open, Save, Browse, or Select dialog;
- the original File Explorer window;
- the active panel of the original Total Commander window.

Everything can open automatically for supported dialogs or manually through the launcher.

---

## Usage

### How to run the tool

Start `Everything-Assistance.ahk` once and leave it running in the background.

#### Automatic dialog mode

1. Open a Windows Open, Save, Browse, or Select dialog.
2. Everything opens automatically below the dialog.
3. Select a file or folder.
4. Press `Shift + Enter`.
5. The selected full path is inserted into the dialog.

#### Manual launcher mode

1. Activate the File Explorer window or Total Commander panel that should receive the result.
2. Run `Everything-Assistance-Launcher.ahk`.
3. Select a file or folder in Everything.
4. Press `Shift + Enter`.
5. The original window navigates to the selected folder.

Running the launcher again toggles the Everything search window:

| Everything state | Launcher action |
| --- | --- |
| Not open | Opens Everything |
| Visible | Hides Everything |
| Hidden | Shows and activates Everything |
| Minimized | Restores and activates Everything |

### Shortcuts

| Shortcut or action | Usage |
| --- | --- |
| Run `Everything-Assistance-Launcher.ahk` | Toggle manual Everything mode |
| `Shift + Enter` inside Everything | Send the selected result to the original window |

The launcher does not define its own keyboard shortcut. Assign it to the desired keyboard key, mouse button, or external-device action.

### Result behavior

| Original window | Result |
| --- | --- |
| Open, Save, Browse, or Select dialog | Insert the selected full path |
| File Explorer | Open the selected folder, or the parent folder of a selected file |
| Total Commander | Open the selected folder, or the parent folder of a selected file, in the original active panel |

### Tray controls

The persistent assistant tray menu provides:

- `Change Everything.exe Path`
- `Test Everything.exe Path`
- `Everything-Assistance.ico` as the tray icon when the ICO file exists beside the assistant

---

## Installation

### Requirements

- Microsoft Windows
- AutoHotkey v1.1
- Everything Search
- Total Commander only when Total Commander integration is required

No external `go_to_path.ahk` helper is required.

### Files

| File | Purpose |
| --- | --- |
| `Everything-Assistance.ahk` | Persistent background assistant |
| `Everything-Assistance-Launcher.ahk` | Manual show/hide launcher |
| `Everything-Assistance.ico` | Assistant tray icon |
| `Everything-Assistance.ini` | Shared settings and hidden-window state |

### Installation steps

1. Put both AHK scripts and `Everything-Assistance.ico` in the same directory.
2. For the first launch, place the scripts beside the old `Everything-Assistance.ini` so its saved `EverythingPath` can be migrated.
3. Run `Everything-Assistance.ahk`.
4. Select the correct `Everything.exe` if requested.
5. Assign `Everything-Assistance-Launcher.ahk` to the desired keyboard, mouse, or external-device action.

The launcher locates `Everything-Assistance.ahk` in its directory.

### Shared Everything.exe path

Both scripts use this settings file:

```text
%APPDATA%\Everything-Assistance\Everything-Assistance.ini
```

The executable path is stored as:

```ini
[Settings]
EverythingPath=C:\Path\To\Everything.exe
```

On first launch, `EverythingPath` is imported from a legacy INI beside the assistant or launcher when the shared INI does not contain a path. The legacy file is left untouched as a backup.

The assistant reloads the shared value before every Everything launch. The launcher also records the real executable path when it finds a running Everything window.

The default fallback path is:

```text
%GoogleDrive%\TotalComander\_Utilities\Everything Portable\Everything.exe
```

If the `GoogleDrive` environment variable is unavailable, the fallback root is `D:\GoogleDrive`.

---

## Troubleshooting

### EverythingPath is requested again

1. Confirm that this file exists:

   ```text
   %APPDATA%\Everything-Assistance\Everything-Assistance.ini
   ```

2. Confirm that it contains:

   ```ini
   [Settings]
   EverythingPath=C:\Actual\Path\To\Everything.exe
   ```

3. Confirm that the stored executable still exists.
4. Run `Everything-Assistance.ahk` beside the old local INI once if migration has not occurred.
5. Exit any other assistant instance and start `Everything-Assistance.ahk`.

The path-selection error message displays the exact INI file being read.

### Everything does not open

Use the assistant tray menu:

1. Select `Change Everything.exe Path`.
2. Choose the real `Everything.exe`.
3. Select `Test Everything.exe Path`.

### A small Everything title bar appears

Use `Everything-Assistance-Launcher.ahk`. It ignores helper windows smaller than 250 × 150 pixels and restores only the remembered search window.

### Total Commander does not navigate

Check that:

- the launcher was invoked while the intended Total Commander panel was active;
- a valid file or folder was selected in Everything;
- `Shift + Enter` copied a full path;
- Total Commander and AutoHotkey run at the same Windows privilege level.

When Total Commander rejects the handoff, Everything remains open and an error is displayed.

### Automatic dialog mode stops after manual use

If a manual Everything session was closed without completing `Shift + Enter`, restart `Everything-Assistance.ahk`.

---

## Development notes

### Instance handling

- Only one assistant instance should remain active.
- The launcher locates the assistant in its directory.
- Settings are independent of the script filename and directory.

### Automatic dialog implementation

The assistant checks every 250 ms for windows with class `#32770` whose title contains:

```text
open
save
browse
select
```

When detected, the assistant remembers the dialog and focused edit control, starts Everything, and keeps it aligned below the dialog.

Positioning values:

```ahk
global eHeight := 400
global padding := 0
```

The primary monitor work area is used to prevent overlap with the taskbar.

### Manual launcher implementation

The launcher:

- ignores small Everything helper windows;
- remembers the real search-window handle, placement, and state;
- stores hidden-window information in the shared INI;
- sends message `0x5555` to begin a new manual session;
- sends message `0x5556` to refresh the original window when restoring an existing session.

Stored window state:

```ini
[HiddenWindow]
Hwnd=
X=
Y=
Width=
Height=
State=
```

### Result handoff implementation

Everything's `Ctrl + Shift + C` command is used internally to copy the selected full path.

- File Explorer is navigated through `ComObjCreate("Shell.Application")`.
- Total Commander receives a direct `WM_COPYDATA` change-directory message.
- The exact original Total Commander window is targeted.
- The Total Commander payload contains a UTF-8 byte-order marker and source-panel selector.
- Standard dialogs receive the selected full path through the remembered edit control, with `Edit1` as fallback.

### Clipboard behavior

- Manual opening temporarily copies selected text for the initial Everything query, then restores the previous clipboard.
- Result handoff copies the selected full path. That path remains in the clipboard.

### Settings behavior

Both scripts use one file:

```text
%APPDATA%\Everything-Assistance\Everything-Assistance.ini
```

Every saved `EverythingPath` is read back for verification. The assistant reloads it before each launch.

### Test code

This test starts manual mode while Total Commander remains active:

```ahk
#NoEnv
#SingleInstance Force
DetectHiddenWindows, On

assistant_path := A_ScriptDir . "\Everything-Assistance.ahk"
assistant_window := WinExist(assistant_path . " ahk_class AutoHotkey")

if !assistant_window
{
    Run, "%A_AhkPath%" "%assistant_path%"
    WinWait, %assistant_path% ahk_class AutoHotkey,, 5
    assistant_window := WinExist(assistant_path . " ahk_class AutoHotkey")
}

if !assistant_window
{
    MsgBox, 16, Test Failed, Everything Assistance did not start.
    ExitApp
}

PostMessage, 0x5555, 0, 0,, ahk_id %assistant_window%
ExitApp
```

Test procedure:

1. Save the test beside `Everything-Assistance.ahk`.
2. Activate the required Total Commander panel.
3. Run the test without activating another window.
4. Select a result in Everything.
5. Press `Shift + Enter`.
6. Confirm that the original panel opens the destination folder.

### Current limitations

- Automatic alignment uses the primary monitor work area only.
- Automatic dialog detection depends on English title keywords.
- Manual selected-text capture can wait up to one second.
- Result transfer depends on Everything's `Ctrl + Shift + C` full-path command.
- The launcher identifies the real Everything window by process name and minimum size.
- Closing a manual Everything session without `Shift + Enter` can leave automatic dialog detection paused until the assistant restarts.
