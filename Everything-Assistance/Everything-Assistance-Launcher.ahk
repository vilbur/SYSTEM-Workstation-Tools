#NoEnv
#SingleInstance Force
SetTitleMatchMode, 2
DetectHiddenWindows, On

; ==============================================================================
; Everything Assistance - Launcher
; Version: 0.02
; ==============================================================================
script_version := "0.02"
settings_path := A_ScriptDir . "\Everything-Assistance-Launcher.ini"
assistant_path := getAssistantPath()

visible_window := getVisibleEverythingWindow()
if (visible_window)
{
    WinGet, window_state, MinMax, ahk_id %visible_window%
    if (window_state = -1)
    {
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
    showRememberedEverythingWindow(hidden_window)
    ExitApp
}

if !FileExist(assistant_path)
{
    MsgBox, 16, Everything Assistance, Everything-Assistance.ahk or a versioned Everything-Assistance_0.xx.ahk file was not found in:`n%A_ScriptDir%
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
Start the assistant when needed and request manual Everything mode.
*/
triggerAssistant(assistant_path)
{
    assistant_window := WinExist(assistant_path . " ahk_class AutoHotkey")
    if !assistant_window
    {
        Run, "%A_AhkPath%" "%assistant_path%",, UseErrorLevel
        if ErrorLevel
        {
            return false
        }

        WinWait, %assistant_path% ahk_class AutoHotkey,, 5
        if ErrorLevel
        {
            return false
        }

        Sleep, 500
        assistant_window := WinExist(assistant_path . " ahk_class AutoHotkey")
    }

    if !assistant_window
    {
        return false
    }

    PostMessage, 0x5555, 0, 0,, ahk_id %assistant_window%
    return true
}

/**
Find the base assistant script or its highest numbered version.
*/
getAssistantPath()
{
    base_path := A_ScriptDir . "\Everything-Assistance.ahk"
    if FileExist(base_path)
    {
        return base_path
    }

    newest_path := ""
    newest_version := -1

    Loop, Files, % A_ScriptDir . "\Everything-Assistance_*.ahk", F
    {
        if RegExMatch(A_LoopFileName, "i)_([0-9]+\.[0-9]+)\.ahk$", version_match)
        {
            version_number := version_match1 + 0
            if (version_number > newest_version)
            {
                newest_version := version_number
                newest_path := A_LoopFileFullPath
            }
        }
    }

    return newest_path
}
