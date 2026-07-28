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
- delete persistent rows after the first
- manage dynamic program tabs
- edit dynamic tab configuration rows
- save changes

### APPLY

Purpose: execute stored configuration.

Expected capabilities:

- inspect configured values
- apply fixed Paths rows
- apply current dynamic program tab
- apply all configurations

Structural editing controls should be hidden or disabled in Apply mode.

## Fixed Paths tab

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

## Persistent row layout

Recommended left-to-right control order:

1. file path edit
2. Browse button
3. Env var edit
4. Run as Admin checkbox
5. Run on startup checkbox
6. delete button for additional rows

The exact widths may change to fit the window, but every row must remain aligned with its column headers.

## Programs-tab path rows

Every dynamic Programs tab uses the same file path, Browse, Env var, Run as Admin, Run on startup, and Delete controls. Rows are saved inside that tab's `_Paths` section. Legacy `_Name` and `_Val` keys migrate to the new Env var and file path fields.

Program startup registry values use the dedicated `PathConfig_Program_` namespace so applying a program tab does not remove fixed Paths startup entries.

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
- keep the Apply-mode column label as `Run as admin`
- display `Yes` or `No` from the configured Run as Admin checkbox
- color the value green when the Windows property matches and red when it differs
- show a neutral `N/A` status when the path is empty

Failure increases the persistent apply error count.

### Startup action

Condition:

```text
Run on startup is checked
```

Validation:

- path is non-empty
- target exists

Action:

- create current-user Run value owned by Path-Config

When Run as Admin is also checked, store an elevation-capable startup command rather than a plain quoted path.

## Startup reconciliation

Startup state is declarative.

The desired state comes from the current checked rows, not from incremental button presses.

Apply algorithm:

```text
collect PathConfig-owned Run values
remove collected values
for each enabled startup row
    validate target
    recreate one owned value
```

This ensures unchecked, deleted, or reordered rows do not leave stale startup entries.

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

2_Path=C:\Tools\Other.exe
2_EnvVar=
2_RunAsAdmin=0
2_RunOnStartup=1
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
