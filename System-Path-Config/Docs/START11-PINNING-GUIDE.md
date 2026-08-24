# Start11 Shortcut Pinning Guide

This guide preserves the confirmed Start11 pinning mechanism so another GPT chat or developer can extend it without rediscovering the registry layout.

## Confirmed behavior

Start11 pins require both a Windows shortcut and registry entries. Creating the shortcut alone is not enough. Path-Config accepts either an executable or an existing `.lnk`; configured shortcuts are copied into the pinned directory with their target and arguments preserved.

Shortcut location:

```text
%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu\<name>.lnk
```

Register the same shortcut path in both Start11 groups:

```text
HKCU\Software\Stardock\Start8\Start8.ini\GroupContents\$PINNEDDEF$
HKCU\Software\Stardock\Start8\Start8.ini\GroupContents11\$$APPS$$
```

Use the next available numeric registry value name independently in each group:

```text
$PINNEDDEF$: <shortcut path>|-1|1|-1|-1
$$APPS$$:    <shortcut path>|-1|0|-1|-1
```

Direct registry writes have been confirmed to appear in Start11 without restarting Explorer.

## Required algorithm

For each requested executable:

1. Expand environment variables and normalize the executable path.
2. Require an existing `.exe` file.
3. Query both Start11 registry groups with a hidden process.
4. Parse numeric `REG_SZ` or `REG_EXPAND_SZ` values.
5. Take the text before the first `|` as the shortcut path.
6. Open each existing `.lnk` and compare its normalized target with the requested executable.
7. Reuse an existing matching shortcut.
8. Otherwise create a shortcut in the pinned Start Menu directory.
9. Avoid filename collisions by adding ` (2)`, ` (3)`, and so on when a same-named shortcut targets another executable.
10. Ensure each registry group contains a shortcut targeting the executable. Do not add duplicates.
11. For a missing entry, use `maximum numeric value + 1` and that group's suffix.
12. Clear cached pin data and query again to verify the completed pin.
13. Log success or failure beside the calling script or application.

Compare pins by resolved shortcut target, not merely by shortcut filename or raw registry data.

## Shortcut properties

```text
TargetPath       = full executable path
WorkingDirectory = executable's containing folder
IconLocation     = executable path + ",0"
Description      = identifies the creating tool
WindowStyle      = normal window
```

When Admin is enabled, set and verify the executable's per-user `RUNASADMIN` compatibility property first:

```text
HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
```

Add only the `RUNASADMIN` token and preserve unrelated compatibility tokens. Launching the Start11 shortcut will then request elevation.

## Safety rules

- Work only under `HKCU`.
- Never delete unrelated Start11 values.
- Never overwrite a shortcut targeting a different executable.
- Never assume the two Start11 groups use the same suffix or next numeric value.
- Treat missing Start11 keys as a reported operational failure.
- Use hidden status commands so no console flashes.
- Quote all registry keys and paths safely.
- In Path-Config's declarative MENU sync, an unchecked option removes only exact target-and-arguments matches; standalone callers should remove pins only when that behavior was explicitly requested.
- Back up or log registry changes in a standalone tool.

## Verification checklist

- The `.lnk` exists in the pinned Start Menu directory.
- Its target is the requested executable.
- `$PINNEDDEF$` contains `|-1|1|-1|-1`.
- `$$APPS$$` contains `|-1|0|-1|-1`.
- Applying twice creates no duplicates.
- Start11 displays the pin without restarting Explorer.
- An Admin-enabled target requests elevation from the pin.
- Logs distinguish verified pins, new shortcuts, repaired entries, and failures.

## Path-Config reference implementation

The implementation is embedded in `Path-Config.hta` v0.60:

```text
START11_PIN_GROUPS
START11_PIN_ROOTS
START11_PIN_DIRECTORY
readStart11PinValues
readStart11PinTreeValues
start11ShortcutDetails
start11MenuSourceInfo
getStart11PinRecords
isStart11MenuSourcePinned
removeStart11MenuPin
availableStart11ShortcutPath
createStart11Shortcut
copyStart11Shortcut
start11GroupContainsSignature
nextStart11ValueName
ensureStart11MenuPin
```

It supports fixed and Programs-tab Paths. The saved field is `<row>_Menu`. Apply mode uses the full words `YES` and `NO`; never abbreviate, clip, or ellipsize them.

## Ready-to-paste handoff prompt

```text
Implement Start11 shortcut pinning using this confirmed mechanism. Do not replace it with standard Windows Start pin APIs.

Create or reuse a .lnk under:
%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\StartMenu

When the configured source is an existing .lnk, copy it collision-safely into this folder and preserve its target and arguments. Compare existing pins by normalized target plus arguments.

Register it in both keys using each key's next numeric value:
HKCU\Software\Stardock\Start8\Start8.ini\GroupContents\$PINNEDDEF$
  Data: <shortcut path>|-1|1|-1|-1
HKCU\Software\Stardock\Start8\Start8.ini\GroupContents11\$$APPS$$
  Data: <shortcut path>|-1|0|-1|-1

Detect existing pins by resolving registered .lnk targets and comparing normalized executable paths. Reuse matches, repair a missing group entry, avoid duplicates and filename collisions, and verify by querying again. No Explorer restart is required.

If Admin is enabled, set and verify RUNASADMIN under:
HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
Preserve unrelated compatibility tokens.

Treat checked/unchecked as desired present/absent state. Remove only exact target-and-arguments matches across Start11 group trees; do not delete or overwrite unrelated shortcuts or values. Refresh live state before every operation, run queries hidden, quote all paths, log beside the script, and test add/remove idempotency by applying twice.
```
