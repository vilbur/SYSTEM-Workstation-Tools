# Everything Assistance

Everything Assistance connects Everything Search with Windows dialogs, File Explorer, and Total Commander.

## Index

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

`Everything-Assistance.exe` starts the background methods script when required and toggles the Everything search window.

---

## Usage

### How to run the tool

Run `Everything-Assistance.exe` from the project root.

#### Automatic dialog mode

1. Run `Everything-Assistance.exe` once to start the background methods script.
2. Open a Windows Open, Save, Browse, or Select dialog.
3. Everything opens automatically below the dialog.
4. Select a file or folder.
5. Press `Shift + Enter`.

The selected full path is inserted into the dialog.

#### Manual mode

1. Activate the File Explorer window or Total Commander panel that should receive the result.
2. Run `Everything-Assistance.exe`.
3. Select a file or folder in Everything.
4. Press `Shift + Enter`.

The original window navigates to the selected folder. If a file is selected, its parent folder is used.
When opened, shown, or restored in manual mode, a non-maximized Everything window places its upper-left corner at the current mouse cursor position.


### Shortcuts

| Shortcut or action | Usage |
| --- | --- |
| Run `Everything-Assistance.exe` | Toggle manual Everything mode |
| `Shift + Enter` inside Everything | Send the selected result to the original window |

The executable does not register a global shortcut. Assign it to the desired keyboard key, mouse button, or external-device action.

### Toggle behavior

| Everything state | Executable action |
| --- | --- |
| Not open | Opens Everything |
| Visible | Hides Everything |
| Hidden | Shows and activates Everything |
| Minimized | Restores and activates Everything |

### Tray controls

The background methods script provides:

- `Change Everything.exe Path`
- `Test Everything.exe Path`
- the `Everything-Assistance.ico` tray icon

---

## Installation

### Requirements

- Microsoft Windows
- AutoHotkey v1.1
- AutoHotkey v1 compiler component for rebuilding the EXE
- Everything Search
- Total Commander only when Total Commander integration is required

No external `go_to_path.ahk` helper is required.

### File tree

```text
\dev\Everything-Assistance.ico
\dev\Everything-Assistance-compiler.ahk
\dev\lib\Everything-Assistance.ahk
\dev\lib\Everything-Assistance-methods.ahk
\Everything-Assistance.ini
\Everything-Assistance.exe
\readme.md
```

| File | Purpose |
| --- | --- |
| `dev\Everything-Assistance.ico` | Tray and compiled executable icon |
| `dev\Everything-Assistance-compiler.ahk` | Builds the root executable |
| `dev\lib\Everything-Assistance.ahk` | Launcher source compiled into the EXE |
| `dev\lib\Everything-Assistance-methods.ahk` | Persistent dialog and result-handoff methods |
| `Everything-Assistance.ini` | Shared root settings and hidden-window state |
| `Everything-Assistance.exe` | Tool entry point and Everything show/hide toggle |

### Compile the executable

1. Keep the files in the structure shown above.
2. Run `dev\Everything-Assistance-compiler.ahk`.
3. If requested, select the AutoHotkey v1 `Ahk2Exe.exe` compiler.
4. The compiler creates or replaces `Everything-Assistance.exe` in the project root.

Run the compiler with `-test` to verify the source, icon, compiler, and output paths without compiling.

### Everything.exe path

Both scripts use only the root settings file:

```text
\Everything-Assistance.ini
```

The executable path is stored as:

```ini
[Settings]
EverythingPath=C:\Path\To\Everything.exe
```

The methods script reloads this value before every Everything launch. The launcher also records the real executable path when it finds a running Everything window.

---

## Troubleshooting

### Everything.exe path is requested again

Confirm that the project-root `Everything-Assistance.ini` contains a valid path:

```ini
[Settings]
EverythingPath=C:\Actual\Path\To\Everything.exe
```

Use the tray commands `Change Everything.exe Path` and `Test Everything.exe Path` if the executable was moved.

### A third-party button starts the launcher but Everything does not appear

The background methods script accepts the launcher's private messages across
Windows integrity levels. This supports application launch actions from software
such as Logi Options when Everything Assistance is already running elevated.

If the problem continues, confirm that the third-party software actually starts
`Everything-Assistance.exe` and that all programs are running in the same signed-in
Windows desktop session. Windows services running in session 0 cannot control the
interactive Everything window.


### Compilation fails

Confirm that:

- the complete file tree is preserved;
- `dev\Everything-Assistance.ico` exists;
- both AHK source files exist under `dev\lib`;
- the AutoHotkey v1 compiler component is installed;
- `Everything-Assistance.exe` is not running while it is being replaced.

Run this command to validate the compiler inputs without building:

```cmd
AutoHotkey.exe "dev\Everything-Assistance-compiler.ahk" -test
```

### A small Everything title bar appears

Run `Everything-Assistance.exe` again. The launcher ignores helper windows smaller than 250 × 150 pixels and restores only the remembered search window.

### Total Commander does not navigate

Check that:

- `Everything-Assistance.exe` was invoked while the intended Total Commander panel was active;
- a valid file or folder was selected in Everything;
- `Shift + Enter` copied a full path;
- Total Commander and AutoHotkey run at the same Windows privilege level.

When Total Commander rejects the handoff, Everything remains open and an error is displayed.

---

## Development notes

### Runtime paths

- The compiled `Everything-Assistance.exe` runs from the project root.
- The source launcher runs from `dev\lib`.
- Both modes resolve `dev\lib\Everything-Assistance-methods.ahk` explicitly.
- The methods script resolves the tray icon from `dev\Everything-Assistance.ico`.
- Both scripts read and write only the root `Everything-Assistance.ini`.

### Instance messages

- Message `0x5555` begins a manual session and carries the original window handle.
- Message `0x5556` refreshes the original window when an existing Everything window is restored.
- Message `0x5557` delegates hide, show, and restore actions across Windows integrity levels.

### Result handoff

Everything's `Ctrl + Shift + C` command copies the selected full path.

- File Explorer is navigated through `Shell.Application`.
- Total Commander receives a direct `WM_COPYDATA` change-directory message.
- Standard dialogs receive the path through the remembered edit control, with `Edit1` as fallback.

### Current limitations

- Automatic alignment uses the primary monitor work area only.
- Automatic dialog detection depends on English title keywords.
- Result transfer depends on Everything's `Ctrl + Shift + C` full-path command.
- Closing a manual Everything session without `Shift + Enter` can leave automatic dialog detection paused until the methods script restarts.
