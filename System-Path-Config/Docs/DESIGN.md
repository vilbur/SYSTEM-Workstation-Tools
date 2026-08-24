# Path-Config Design Specification

## User-facing modes

### CONFIG

Purpose: edit structure and values.

Expected capabilities:

- add persistent Paths rows
- browse for files
- edit Env var names
- enable or disable Run as Admin
- enable or disable Run on startup
- enable or disable Start11 Menu pinning
- delete persistent rows after the first
- manage dynamic program tabs
- edit dynamic tab configuration rows
- save changes manually while edits are pending; the available state uses the original v0.39 base class, hover, white font, pointer cursor, and direct save action; the clean state is a separate frozen button with grey font, default cursor, resting v0.39 surface, no hover response, and no click handler
- detect value changes immediately in IE9-mode HTA through input, keyup, propertychange, and change events so typing or pasting into a path field unfreezes Save State without waiting for focus loss; ignore non-value property events
- automatically save pending changes before switching from Config to Apply; remain in Config if saving fails

### APPLY

Purpose: execute stored configuration.

Expected capabilities:

- inspect configured values
- apply fixed Paths rows
- apply current dynamic program tab
- apply all configurations

Structural editing controls should be hidden or disabled in Apply mode.

## Source-update restart

Path-Config maintains heartbeat and relaunch-request files used by the cooperative `Path-Config.exe` launcher. A launcher invocation against a running instance writes a relaunch request, which the HTA consumes and handles through its restart path. Stable source updates use the same restart logic. If UI edits are unsaved, restart remains pending until they can be saved; the controlled restart then reloads the running HTA while preserving restart-aware unload handling.

## Fixed Common tab

The first visible tab is always:

```text
Paths
```

It is a system tab rather than a user-created program tab.

Constraints:

- first position is permanent
- name is reserved
- right-click rename/delete menu must not operate on it
- switching to it must not overwrite the last dynamic tab index
- saving selected UI tab must distinguish it from dynamic tab selection

## Program tab ordering

`Common` is permanently first and cannot move. In Config mode, every program tab can move left or right within the program-tab sequence from the selected-tab toolbar or its right-click menu. Boundary actions are disabled. Reordering moves the tab name and its complete keyed configuration together, retains the moved tab as active, marks state unsaved, and persists through the existing `Tabs` sequence without resizing the window.

## Persistent row layout

Required left-to-right control order:

1. fixed-size burger menu containing Move to New Tab and Delete Row
2. Run as Admin checkbox
3. Run on startup checkbox
4. Menu checkbox
5. Browse button
6. file path edit
7. Env var edit
8. one rightmost ordering button (left-click moves down; right-click moves up)

The file-path edit receives the largest available share of the row and has a 560 px minimum width. Environment Variable uses its restored 20% column while Links Link Name keeps its earlier 15% column. Path tables retain a 1270 px minimum canvas and the application window is capped at half the available display width; narrower windows scroll horizontally instead of compressing File Path below its minimum. Compact fixed-width columns fit the 30 px edge buttons, 64 px Browse button, and 20 px checkboxes without unused column space in fixed Paths and Programs Paths; 10 px padding on each adjacent cell therefore produces an exact visible 20 px horizontal gap. Shared button styles must not add extra margins. The first and last controls align flush with the left and right row edges, and section Add buttons sit beside their labels on the left. Config-mode checkboxes are larger and icon-only, without a `Yes` caption. The ADMIN, STARTUP, and MENU labels use orange, green, and blue respectively, with 8 px padding on each side producing 16 px between adjacent labels. Each checkbox provides an action-specific tooltip. Apply-mode Boolean statuses are icon-only: a matching YES displays a green `✔`, a mismatching YES displays a red `✘`, and every NO or N/A state displays a blank cell. Existing status colors and explanatory tooltips remain authoritative. Every row remains aligned with its column headers. Tab selection rerenders content without resizing or recentering the outer HTA window; repeated tab changes must preserve its exact current dimensions.

## Path browsing

File Browse actions use Windows Forms `OpenFileDialog`. Folder Browse actions use the native Windows `IFileOpenDialog` Common Item Dialog in folder-selection mode. Both provide access to the full PC. A populated path field opens Browse at that field path (or its containing directory for a file). An empty field opens at the last successfully selected directory; before any selection it starts at `C:\`. Every selected path passes through one sanitizer before reaching application state: direct drive letters are capitalized, forward separators are normalized, and folder results end with exactly one trailing backslash, including UNC shares. In Config mode, typed path-like values also capitalize direct drive letters and gain a trailing backslash when their expanded value is an existing directory, while preserving raw `%NAME%` references. Cancelling a dialog leaves the remembered directory unchanged.

Every file/folder Browse button, including compact D/F controls, opens a shared right-click menu with `Find in Explorer`. The menu reads the live adjacent input rather than stale saved state, disables its action for an empty value, resolves `%NAME%` references, validates that the target exists, and launches visible Windows Explorer with the file or folder selected. Missing paths report an error without changing configuration.

## Programs-tab path rows

Every dynamic Programs tab uses the same minimum-560-px file path, compact 64 px Browse button, restored 20% Env var, larger icon-only Run as Admin, larger icon-only Run on startup, and compact 30 px Delete controls with the same exact visible 20 px horizontal spacing and flush outer alignment. Environment Variables, Executables, and Links also use compact fixed-width D/F/Browse/Delete action columns; paired D/F buttons are separated by exactly 20 px, first fields are flush left, and Delete buttons are flush right. Links keeps Link Name at 15% in Config mode; Apply mode combines Link folder and Link name into one Link path column, so the visible labels are Source, Link path, and Type. Rows are saved inside that tab's `_Paths` section. Legacy `_Name` and `_Val` keys migrate to the new Env var and file path fields.

New Link rows inherit the immediately previous row's non-empty Link folder. Source and Link name remain empty and Type starts as Symlink; if the previous Link folder is blank, the new row stays blank.

Path-Config compares the Source item's containing directory with Link folder after %NAME% expansion, slash normalization, trailing-separator cleanup, and case folding. When they match, Config mode colors both Source and Link folder orange; Apply mode colors Source and the combined Link path orange. Empty or different directories keep their normal validation colors.

Program startup registry values use the dedicated `PathConfig_Program_` namespace so applying a program tab does not remove fixed Paths startup entries.

## Persistent row ordering

In Config mode, one rightmost ordering control appears on every persistent row. Left-click moves the complete row down; right-click moves it up and suppresses the context menu. The file path, environment variable, Run as Admin flag, Run on startup flag, and Menu flag must move together. The reordered array is saved in its visible order. The ordering control is not shown in Apply mode. After a successful move, the mouse cursor follows the merged control on the moved row.

## Persistent row menu

Every fixed Paths row has a fixed-size burger menu on the left. Either left-click or right-click opens the same menu with two actions:

1. `Move to New Tab` creates a uniquely named Programs tab containing the complete row data, removes the source row, and activates the new tab.
2. `Delete Row` uses the existing deletion rule and remains disabled for the first row.

Moving the only fixed row must leave one empty persistent row behind. The new Programs tab starts with the moved path row and empty Environment Variables, Executables, and Links collections.

## Persistent row actions

### Environment-variable action

Condition:

```text
Env var is not empty AND path is not empty
```

Action:

```text
Write HKCU\Environment\<Env var> = <path>
```

An empty Env var does nothing. It must not create a blank registry value name.

Path-like values accept native `%NAME%` references. Resolution is case-insensitive and recursive. Variables configured anywhere in the Path-Config dialog take priority over the existing Windows environment; later Path-Config definitions in Apply All order win. Windows variables such as `%username%` are used as fallback. Unknown and cyclic references remain unresolved instead of being discarded or looping. Raw values remain persisted, and environment registry values containing references use `REG_EXPAND_SZ`.

### Windows administrator compatibility property

Condition:

```text
A persistent row has a non-empty executable path
```

Validation when Run as Admin is enabled:

- target exists
- target is an `.exe` file

Action:

- add the `RUNASADMIN` token when enabled
- remove only the `RUNASADMIN` token when disabled
- preserve all other compatibility flags
- query status without displaying a helper console window
- keep the Apply-mode column label as `Admin`
- display a green `✔` for a matching checked Run as Admin value, a red `✘` for a mismatching checked value, and a blank cell for every unchecked value
- color the value green when the Windows property matches and red when it differs
- show a blank neutral status when the path is empty

Failure increases the persistent apply error count.

### Startup action

For every configured path, resolve current-user Run commands to executable targets and compare normalized paths exactly.

When exactly one non-PathConfig Run value matches:

- preserve its Run value name, type, command, and arguments
- synchronize only its `StartupApproved\Run` value
- checked writes the 12-byte enabled state beginning with `02`
- unchecked writes the disabled state beginning with `03` followed by a current FILETIME

When multiple non-PathConfig values match, report an ambiguity and modify none. When none match, checked rows use the existing PathConfig-owned Run value and enabled approval state; unchecked rows leave no owned entry after scoped cleanup. Enabling still requires a non-empty existing target. Apply mode reads the matching Run and StartupApproved values so STARTUP mirrors Windows Settings > Apps > Startup.

When Run as Admin is also checked and an owned fallback is created, store an elevation-capable startup command rather than a plain quoted path.

### Start11 Menu action

Menu is a declarative live synchronization. Checked rows accept an existing `.exe` or an existing `.lnk` whose target exists, create or reuse a collision-safe pinned-directory shortcut, and ensure Start11 registration without duplicating items moved to custom groups. Unchecked rows remove matching registrations recursively and delete only shortcuts with the exact resolved target-and-arguments signature. Apply mode shows the real current pin state: a green `✔` when registered and a blank red-class status when absent, independent of cached or saved checkbox state. Admin-enabled shortcuts must resolve to an `.exe`; RUNASADMIN is set and verified on that resolved executable before the shortcut is accepted as ready.
## Startup reconciliation

Startup state is declarative.

The desired state comes from the current checked rows, not from incremental button presses.

Apply algorithm:

```text
collect and remove PathConfig-owned Run and StartupApproved values in the selected scope
for each configured row
    find non-PathConfig current-user Run values with the exact resolved executable target
    if exactly one matches, preserve its Run value and write only its desired On/Off approval state
    if multiple match, report ambiguity and modify none
    if none match and startup is checked, recreate one owned Run value and enabled approval state
```

This removes stale owned entries while reusing a pre-existing Windows Startup Apps identity. Non-PathConfig Run commands are never rewritten or deleted, and unrelated approval values remain untouched.

## Apply result

Persistent apply should return structured information equivalent to:

```text
{
    env_changed: true or false,
    admin_property_count: integer,
    admin_removed_count: integer,
    startup_count: integer,
    error_count: integer
}
```

The GUI may summarize this result in a message box.

Do not stop processing all rows because one row fails.

## INI format

Example conceptual section:

```ini
[PersistentPaths]
1_Path=C:\Tools\Tool.exe
1_EnvVar=TOOL_EXE
1_RunAsAdmin=1
1_RunOnStartup=1
1_Menu=1

2_Path=C:\Tools\Other.exe
2_EnvVar=
2_RunAsAdmin=0
2_RunOnStartup=1
2_Menu=0
```

The section must be independent from dynamic program-tab sections.

## Reserved names

At minimum, `Paths` is reserved for the fixed tab and must not be accepted as a dynamic program-tab name.

Case-insensitive comparison is preferred for reserved-name validation.

## Error handling

Apply should report an error when an enabled action requires a target but the target is missing.

An empty row with no enabled action is not an error.

An environment variable with an empty name is skipped.

Registry operations must check `ErrorLevel` where supported.

Run operations must use `UseErrorLevel`.

## Non-goals unless explicitly requested

- system-wide environment variables under HKLM
- scheduled tasks
- Windows services
- startup entries for other user accounts
- deleting unrelated startup values
- automatic elevation of the entire manager
- changing dynamic program-tab persistence as part of fixed Paths work
