#NoEnv
#SingleInstance Force
SetTitleMatchMode, 2
DetectHiddenWindows, On

; ==============================================================================
; Everything Assistance - Launcher
; Version: 0.09
; ==============================================================================
script_version := "0.09"
assistant_path := getAssistantPath()
settings_path := getSharedSettingsPath()
migrateLegacySettings(settings_path, assistant_path)
origin_window := WinExist("A")

visible_window := getVisibleEverythingWindow()
if (visible_window)
{
    if !rememberEverythingExecutablePath(visible_window)
    {
        MsgBox, 48, Everything Assistance, The Everything.exe path could not be saved and verified in:`n%settings_path%
    }

    WinGet, window_state, MinMax, ahk_id %visible_window%
    if (window_state = -1)
    {
        if !updateAssistantOrigin(assistant_path, origin_window, visible_window)
        {
            MsgBox, 16, Everything Assistance, The assistant could not capture the original window.
            ExitApp
        }

        WinRestore, ahk_id %visible_window%
        WinActivate, ahk_id %visible_window%
    }
    else
    {
        rememberEverythingWindow(visible_window)
        WinHide, ahk_id %visible_window%
    }

    ExitApp
}

hidden_window := getRememberedEverythingWindow()
if (hidden_window)
{
    if !rememberEverythingExecutablePath(hidden_window)
    {
        MsgBox, 48, Everything Assistance, The Everything.exe path could not be saved and verified in:`n%settings_path%
    }
    if !updateAssistantOrigin(assistant_path, origin_window, hidden_window)
    {
        MsgBox, 16, Everything Assistance, The assistant could not capture the original window.
        ExitApp
    }

    showRememberedEverythingWindow(hidden_window)
    ExitApp
}

if !FileExist(assistant_path)
{
    MsgBox, 16, Everything Assistance, A versioned Everything-Assistance_0.xx.ahk file was not found in:`n%A_ScriptDir%
    ExitApp
}

if !triggerAssistant(assistant_path)
{
    MsgBox, 16, Everything Assistance, The main Everything Assistance script could not be started.
}

ExitApp

/**
Find the largest visible Everything search window.
*/
getVisibleEverythingWindow()
{
    DetectHiddenWindows, Off
    WinGet, window_list, List, ahk_exe Everything.exe

    largest_window := 0
    largest_area := 0

    Loop, %window_list%
    {
        window_id := window_list%A_Index%
        WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_id%

        if (window_width < 250 || window_height < 150)
        {
            WinHide, ahk_id %window_id%
            continue
        }

        window_area := window_width * window_height
        if (window_area > largest_area)
        {
            largest_area := window_area
            largest_window := window_id
        }
    }

    DetectHiddenWindows, On
    return largest_window
}

/**
Remember the exact Everything window hidden by this launcher.
*/
rememberEverythingWindow(window_id)
{
    global settings_path

    WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_id%
    WinGet, window_state, MinMax, ahk_id %window_id%

    IniWrite, %window_id%, %settings_path%, HiddenWindow, Hwnd
    IniWrite, %window_x%, %settings_path%, HiddenWindow, X
    IniWrite, %window_y%, %settings_path%, HiddenWindow, Y
    IniWrite, %window_width%, %settings_path%, HiddenWindow, Width
    IniWrite, %window_height%, %settings_path%, HiddenWindow, Height
    IniWrite, %window_state%, %settings_path%, HiddenWindow, State
}

/**
Return only the exact Everything window previously hidden by this launcher.
*/
getRememberedEverythingWindow()
{
    global settings_path

    IniRead, window_id, %settings_path%, HiddenWindow, Hwnd, 0
    if (window_id = 0 || !WinExist("ahk_id " . window_id))
    {
        clearRememberedEverythingWindow()
        window_id := getHiddenEverythingWindow()
        if (window_id)
        {
            rememberEverythingWindow(window_id)
        }

        return window_id
    }

    WinGet, process_name, ProcessName, ahk_id %window_id%
    if (process_name != "Everything.exe")
    {
        clearRememberedEverythingWindow()
        window_id := getHiddenEverythingWindow()
        if (window_id)
        {
            rememberEverythingWindow(window_id)
        }

        return window_id
    }

    if DllCall("IsWindowVisible", "Ptr", window_id)
    {
        return 0
    }

    return window_id
}

/**
Find a large hidden Everything window while ignoring small helper windows.
*/
getHiddenEverythingWindow()
{
    DetectHiddenWindows, On
    WinGet, window_list, List, ahk_exe Everything.exe

    largest_window := 0
    largest_area := 0

    Loop, %window_list%
    {
        window_id := window_list%A_Index%
        if DllCall("IsWindowVisible", "Ptr", window_id)
        {
            continue
        }

        WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_id%
        if (window_width < 250 || window_height < 150)
        {
            continue
        }

        window_area := window_width * window_height
        if (window_area > largest_area)
        {
            largest_area := window_area
            largest_window := window_id
        }
    }

    return largest_window
}

/**
Restore the remembered Everything window and its previous placement.
*/
showRememberedEverythingWindow(window_id)
{
    global settings_path

    IniRead, window_x, %settings_path%, HiddenWindow, X, 0
    IniRead, window_y, %settings_path%, HiddenWindow, Y, 0
    IniRead, window_width, %settings_path%, HiddenWindow, Width, 900
    IniRead, window_height, %settings_path%, HiddenWindow, Height, 600
    IniRead, window_state, %settings_path%, HiddenWindow, State, 0

    WinShow, ahk_id %window_id%
    if (window_state = 1)
    {
        WinMaximize, ahk_id %window_id%
    }
    else
    {
        WinRestore, ahk_id %window_id%
        WinMove, ahk_id %window_id%,, %window_x%, %window_y%, %window_width%, %window_height%
    }

    WinActivate, ahk_id %window_id%
    clearRememberedEverythingWindow()
}

/**
Clear the stored Everything window handle and placement.
*/
clearRememberedEverythingWindow()
{
    global settings_path

    IniDelete, %settings_path%, HiddenWindow
}

/**
Remember the actual Everything.exe path used by the toggled search window.
*/
rememberEverythingExecutablePath(window_id)
{
    global settings_path

    WinGet, executable_path, ProcessPath, ahk_id %window_id%
    if (executable_path = "" || !FileExist(executable_path))
    {
        return false
    }

    SplitPath, executable_path, executable_name
    if (executable_name != "Everything.exe")
    {
        return false
    }

    IniWrite, %executable_path%, %settings_path%, Settings, EverythingPath
    if ErrorLevel
    {
        return false
    }

    IniRead, saved_path, %settings_path%, Settings, EverythingPath, ERROR
    if (saved_path != executable_path)
    {
        return false
    }

    return true
}

/**
Return the version-independent shared settings file path.
*/
getSharedSettingsPath()
{
    if (A_AppData = "")
    {
        return A_ScriptDir . "\Everything-Assistance.ini"
    }

    settings_directory := A_AppData . "\Everything-Assistance"
    FileCreateDir, %settings_directory%
    if ErrorLevel
    {
        return A_ScriptDir . "\Everything-Assistance.ini"
    }

    return settings_directory . "\Everything-Assistance.ini"
}

/**
Import EverythingPath from a legacy INI beside the assistant or launcher.
*/
migrateLegacySettings(settings_path, assistant_path)
{
    IniRead, shared_path, %settings_path%, Settings, EverythingPath, ERROR
    if (shared_path != "ERROR" && shared_path != "")
    {
        return true
    }

    legacy_paths := []
    if (assistant_path != "")
    {
        SplitPath, assistant_path,, assistant_directory
        legacy_paths.Push(assistant_directory . "\Everything-Assistance.ini")
    }
    legacy_paths.Push(A_ScriptDir . "\Everything-Assistance.ini")

    for _, legacy_path in legacy_paths
    {
        if (legacy_path = settings_path || !FileExist(legacy_path))
        {
            continue
        }

        IniRead, legacy_everything_path, %legacy_path%, Settings, EverythingPath, ERROR
        if (legacy_everything_path = "ERROR" || legacy_everything_path = "")
        {
            continue
        }

        IniWrite, %legacy_everything_path%, %settings_path%, Settings, EverythingPath
        return !ErrorLevel
    }

    return false
}

/**
Start the assistant when needed and request manual Everything mode.
*/
triggerAssistant(assistant_path)
{
    assistant_window := getAssistantWindow(assistant_path)

    if !assistant_window
    {
        return false
    }

    PostMessage, 0x5555, 0, 0,, ahk_id %assistant_window%
    return true
}

/**
Update the assistant origin before restoring an existing Everything window.
*/
updateAssistantOrigin(assistant_path, origin_window, everything_window)
{
    assistant_window := getAssistantWindow(assistant_path)
    if (!assistant_window || !origin_window)
    {
        return false
    }

    PostMessage, 0x5556, %origin_window%, %everything_window%,, ahk_id %assistant_window%
    return (ErrorLevel != "FAIL")
}

/**
Return the running assistant window, starting the selected version if needed.
*/
getAssistantWindow(assistant_path)
{
    if !FileExist(assistant_path)
    {
        return 0
    }

    assistant_window := WinExist(assistant_path . " ahk_class AutoHotkey")
    if assistant_window
    {
        return assistant_window
    }

    if !runAssistantScript(assistant_path)
    {
        return 0
    }

    WinWait, %assistant_path% ahk_class AutoHotkey,, 5
    if ErrorLevel
    {
        return 0
    }

    Sleep, 500
    return WinExist(assistant_path . " ahk_class AutoHotkey")
}

/**
Start the assistant from either the AHK launcher or the compiled launcher.
*/
runAssistantScript(assistant_path)
{
    if !A_IsCompiled
    {
        Run, "%A_AhkPath%" "%assistant_path%",, UseErrorLevel
        return !ErrorLevel
    }

    Run, "%assistant_path%",, UseErrorLevel
    return !ErrorLevel
}

/**
Find the highest numbered versioned assistant.
*/
getAssistantPath()
{
    newest_path := ""
    newest_major := -1
    newest_minor := -1
    newest_patch := -1

    Loop, Files, % A_ScriptDir . "\Everything-Assistance_*.ahk", F
    {
        if RegExMatch(A_LoopFileName, "i)_([0-9]+)\.([0-9]+)(?:\.([0-9]+))?\.ahk$", version_match)
        {
            version_major := version_match1 + 0
            version_minor := version_match2 + 0
            version_patch := version_match3 + 0

            if isNewerVersion(version_major, version_minor, version_patch
                , newest_major, newest_minor, newest_patch)
            {
                newest_major := version_major
                newest_minor := version_minor
                newest_patch := version_patch
                newest_path := A_LoopFileFullPath
            }
        }
    }

    if (newest_path != "")
    {
        return newest_path
    }

    return ""
}

/**
Compare three numeric version components without decimal-number ambiguity.
*/
isNewerVersion(candidate_major, candidate_minor, candidate_patch
    , current_major, current_minor, current_patch)
{
    if (candidate_major != current_major)
    {
        return candidate_major > current_major
    }

    if (candidate_minor != current_minor)
    {
        return candidate_minor > current_minor
    }

    return candidate_patch > current_patch
}
