#NoEnv
#SingleInstance Force  ; Standard behavior: don't allow multiple copies
; ==============================================================================
; Everything Assistance
; Filename: Everything-Assistance_0.07.ahk
; Version: 0.07
; ==============================================================================
SetBatchLines, -1
SetTitleMatchMode, 2
DetectHiddenWindows, On
closeOtherAssistantVersions()
; ==============================================================================
; 1. PARAMETER CHECK (The "Re-Run" Trigger)
; ==============================================================================
; A_Args is an array of parameters passed to the script
if (A_Args.Length() > 0) {
    ; If any parameter is passed (like -manual), tell the running script to trigger
    ; We use a hidden HWND check to find the main instance and send the message
    DetectHiddenWindows, On
    WinGet, hwnds, List, %A_ScriptFullPath% ahk_class AutoHotkey
    Loop, %hwnds% {
        id := hwnds%A_Index%
        if (id != A_ScriptHwnd) {
            PostMessage, 0x5555, 0, 0,, ahk_id %id%
            ExitApp ; Close this "trigger" instance immediately
        }
    }
}

; ==============================================================================
; 2. GLOBAL SETUP & SETTINGS
; ==============================================================================
OnMessage(0x5555, "TriggerManualMode")
OnMessage(0x5556, "captureManualOrigin")

global scriptVersion := "0.07"
global settingsPath := A_ScriptDir . "\Everything-Assistance.ini" ; Shared with Everything-Assistance-Launcher.ahk
global trayIconPath := A_ScriptDir . "\Everything-Assistance.ico"

EnvGet, googleDrivePath, GoogleDrive
if (googleDrivePath = "")
{
    googleDrivePath := "D:\GoogleDrive"
}

global defaultEverythingPath := googleDrivePath . "\TotalComander\_Utilities\Everything Portable\Everything.exe"
global everythingPath := LoadEverythingPath()

global eHeight := 400
global padding := 0
global currentMode := "None"
global origWin := ""
global origCtrl := ""
global eWin := ""

if FileExist(trayIconPath)
{
    Menu, Tray, Icon, %trayIconPath%
}

Menu, Tray, Tip, Everything Assistance v%scriptVersion%
Menu, Tray, Add
Menu, Tray, Add, Change Everything.exe Path, ChangeEverythingPath
Menu, Tray, Add, Test Everything.exe Path, TestEverythingPath

#Persistent
SetTimer, DialogWatcher, 250
return

/**
Close older versioned or legacy assistant instances from this directory.
*/
closeOtherAssistantVersions()
{
    WinGet, instance_list, List, ahk_class AutoHotkey

    Loop, %instance_list%
    {
        instance_id := instance_list%A_Index%
        if (instance_id = A_ScriptHwnd)
        {
            continue
        }

        WinGetTitle, instance_title, ahk_id %instance_id%
        if !InStr(instance_title, A_ScriptDir . "\Everything-Assistance")
        {
            continue
        }

        if !RegExMatch(instance_title, "i)\\Everything-Assistance(?:_[0-9]+\.[0-9]+)?\.ahk - AutoHotkey")
        {
            continue
        }

        WinClose, ahk_id %instance_id%
        WinWaitClose, ahk_id %instance_id%,, 2
    }
}

; ==============================================================================
; 3. BEHAVIOR: AUTO-DIALOG WATCHER (Class #32770)
; ==============================================================================
DialogWatcher:
    if (currentMode != "None")
        return

    WinGet, winList, List, ahk_class #32770
    Loop, %winList% {
        wid := winList%A_Index%
        WinGetTitle, wTitle, ahk_id %wid%
        
        if (wTitle ~= "i)(open|save|browse|select)") {
            currentMode := "Auto"
            origWin := wid
            
            ; Stabilization delay for Windows animations
            WinWaitActive, ahk_id %origWin%,, 2
            Sleep, 200 
            
            ControlGetFocus, focusedCtrl, ahk_id %origWin%
            origCtrl := InStr(focusedCtrl, "Edit") ? focusedCtrl : "Edit1" 

            if !EnsureEverythingPath()
            {
                currentMode := "None"
                return
            }

            ; Removed the "Min" flag so the window is allowed to draw properly
            Run, % Chr(34) . everythingPath . Chr(34),, UseErrorLevel
            if ErrorLevel
            {
                MsgBox, 16, Everything Assistance, Everything.exe could not be started from:`n%everythingPath%
                currentMode := "None"
                return
            }

            WinWaitActive, ahk_exe Everything.exe,, 5
            
            if !ErrorLevel
            {
                eWin := WinExist("A")
                
                ; Correct syntax to force AlwaysOnTop to ON for this specific window ID
                WinSet, AlwaysOnTop, On, ahk_id %eWin%
                
                SetTimer, AutoAlignTracker, 10 
                
            } else {
                currentMode := "None" 
            }
            return 
        }
    }
return

/** 
	KEEP EVERYTHING WINDOW ALIGNE BELOW DIALOG
  */
AutoAlignTracker:
    if !WinExist("ahk_id " . origWin) || !WinExist("ahk_id " . eWin) {
        if WinExist("ahk_id " . eWin)
            WinClose, ahk_id %eWin%
        SetTimer, AutoAlignTracker, Off
        currentMode := "None"
        return
    }

    WinGetPos, ox, oy, ow, oh, ahk_id %origWin%
    
    ; --- SMART SCREEN BOUNDARY CHECK ---
    ; Get the boundaries of the primary monitor's work area (excludes taskbar)
    SysGet, MonitorWorkArea, MonitorWorkArea
    
    totalNeededHeight := oh + padding + eHeight
    
    ; Check if the bottom of Everything would go past the taskbar
    if ((oy + totalNeededHeight) > MonitorWorkAreaBottom) {
        
        ; Calculate exactly how high we need to push the original dialog
        newY := MonitorWorkAreaBottom - totalNeededHeight
        
        ; Safety Net: Ensure we don't push the dialog's title bar off the top of the screen
        if (newY < MonitorWorkAreaTop)
            newY := MonitorWorkAreaTop
            
        ; If the dialog isn't already at the new Y position, move it
        if (oy != newY) {
            WinMove, ahk_id %origWin%,, %ox%, %newY%
            
            ; Update 'oy' so the Everything window knows the new position
            oy := newY 
        }
    }
    ; -----------------------------------

    ; Finally, snap the Everything window exactly to the bottom of the dialog
    WinMove, ahk_id %eWin%,, %ox%, % oy + oh + padding, %ow%, %eHeight%
return

; ==============================================================================
; 4. BEHAVIOR: MANUAL CURSOR TRIGGER (Fired by Parameter)
; ==============================================================================
TriggerManualMode() {
    global currentMode, origWin, origCtrl, eWin, eHeight, everythingPath

    ; --- PATH VALIDATION & PERSISTENT SETTINGS ---
    if !EnsureEverythingPath()
    {
        return
    }
    ; ---------------------------------------------

    ; Reset any existing Auto-session
    if (currentMode == "Auto") {
        SetTimer, AutoAlignTracker, Off
        if WinExist("ahk_id " . eWin)
            WinClose, ahk_id %eWin%
    }

    currentMode := "Manual"
    origWin := WinExist("A")
    ControlGetFocus, origCtrl, ahk_id %origWin%

    if !WinExist("ahk_id " . eWin)
    {
		
        ; --- GRAB SELECTED TEXT ---
        savedClip := ClipboardAll   ; Backup current clipboard
        Clipboard := ""             ; Clear clipboard to test for new data
        Send, ^c                    ; Send Ctrl+C
        ;ClipWait, 0.2               ; Wait up to 0.2 seconds for text to copy
        ClipWait, 1               ; Wait up to 0.2 seconds for text to copy
        searchQuery := Clipboard    ; Store the grabbed text
        Clipboard := savedClip      ; Restore the original clipboard silently
        ; --------------------------

        CoordMode, Mouse, Screen
        MouseGetPos, mX, mY
		
		;msgBox % searchQuery

        ; --- LAUNCH EVERYTHING ---
        ; If text was highlighted, pass it via the '-s' search parameter
        if (searchQuery != "")
        {
            launch_command := Chr(34) . everythingPath . Chr(34) . " -s " . Chr(34) . searchQuery . Chr(34)
        }
        else
        {
            launch_command := Chr(34) . everythingPath . Chr(34)
        }

        Run, %launch_command%,, UseErrorLevel
        if ErrorLevel
        {
            MsgBox, 16, Everything Assistance, Everything.exe could not be started from:`n%everythingPath%
            currentMode := "None"
            eWin := ""
            return
        }
        
        WinWaitActive, ahk_exe Everything.exe,, 5
    
        if !ErrorLevel
        {
            eWin := WinExist("A")
            WinSet, AlwaysOnTop, On, ahk_id %eWin%
            WinMove, ahk_id %eWin%,, %mX%, %mY%
        }
    }
    /* CLOSE EVERYTHING WINDOW IF OPENED ( TOGGLE SHOW\HIDE on manual mode )
    */ 
    else
    {
        WinClose, ahk_id %eWin%
    }
}

/**
Refresh the window that receives a manual Everything result.
*/
captureManualOrigin(origin_window, everything_window)
{
    global currentMode, origWin, origCtrl, eWin

    if (!origin_window || !WinExist("ahk_id " . origin_window))
    {
        return false
    }

    origWin := origin_window
    ControlGetFocus, focused_control, ahk_id %origWin%
    origCtrl := InStr(focused_control, "Edit") ? focused_control : "Edit1"
    currentMode := "Manual"

    if (everything_window && WinExist("ahk_id " . everything_window))
    {
        eWin := everything_window
    }

    return true
}
; ==============================================================================
; 5. EVERYTHING.EXE PATH SETTINGS
; ==============================================================================
ChangeEverythingPath:
    if SelectEverythingPath()
    {
        TrayTip, Everything Assistance, Everything.exe path saved:`n%everythingPath%, 3, 1
    }
return

TestEverythingPath:
    if !EnsureEverythingPath()
    {
        return
    }

    Run, % Chr(34) . everythingPath . Chr(34),, UseErrorLevel
    if ErrorLevel
    {
        MsgBox, 16, Launch Test Failed, Everything.exe could not be started from:`n%everythingPath%
    }
    else
    {
        TrayTip, Everything Assistance, Everything.exe started successfully., 3, 1
    }
return

/**
Load the remembered Everything.exe path from the script INI file.
*/
LoadEverythingPath()
{
    global settingsPath, defaultEverythingPath

    IniRead, saved_path, %settingsPath%, Settings, EverythingPath, ERROR
    if (saved_path = "ERROR" || saved_path = "")
    {
        return defaultEverythingPath
    }

    saved_path := Trim(saved_path)
    if (SubStr(saved_path, 1, 1) = Chr(34) && SubStr(saved_path, 0) = Chr(34))
    {
        saved_path := SubStr(saved_path, 2, -1)
    }

    return saved_path
}

/**
Validate the configured path and request a new path when necessary.
*/
EnsureEverythingPath()
{
    global everythingPath

    ; Reload every time so changes saved by the launcher are used immediately.
    everythingPath := LoadEverythingPath()

    if isEverythingExecutablePath(everythingPath)
    {
        return true
    }

    MsgBox, 48, Path Not Found, Everything.exe was not found at:`n%everythingPath%`n`nPlease locate it. The selected path will be remembered.
    return SelectEverythingPath()
}

/**
Select Everything.exe and save its path beside the script.
*/
SelectEverythingPath()
{
    global everythingPath, settingsPath

    initial_directory := A_ProgramFiles
    if isEverythingExecutablePath(everythingPath)
    {
        SplitPath, everythingPath,, initial_directory
    }

    FileSelectFile, selected_path, 3, %initial_directory%, Locate Everything.exe, Executables (*.exe)
    if (selected_path = "")
    {
        return false
    }

    if !isEverythingExecutablePath(selected_path)
    {
        MsgBox, 48, Invalid File, Please select Everything.exe.
        return false
    }

    everythingPath := selected_path
    IniWrite, %everythingPath%, %settingsPath%, Settings, EverythingPath
    if ErrorLevel
    {
        MsgBox, 16, Settings Error, The Everything.exe path could not be saved to:`n%settingsPath%
        return false
    }

    IniRead, saved_path, %settingsPath%, Settings, EverythingPath, ERROR
    if (saved_path != everythingPath)
    {
        MsgBox, 16, Settings Error, The Everything.exe path was written but could not be read back from:`n%settingsPath%
        return false
    }

    return true
}

/**
Return true only for an existing file named Everything.exe.
*/
isEverythingExecutablePath(file_path)
{
    if (file_path = "" || !FileExist(file_path))
    {
        return false
    }

    SplitPath, file_path, file_name
    return (file_name = "Everything.exe")
}

/**
Navigate the active panel of the original Total Commander window.
*/
navigateTotalCommander(window_id, target_path)
{
    if (!window_id || target_path = "" || !WinExist("ahk_id " . window_id))
    {
        return false
    }

    WinGetClass, window_class, ahk_id %window_id%
    if (window_class != "TTOTAL_CMD")
    {
        return false
    }

    ; UTF-8 BOM + source path + CR + empty target path + NUL + source-panel flag.
    path_byte_count := StrPut(target_path, "UTF-8") - 1
    command_size := 3 + path_byte_count + 3

    VarSetCapacity(command_buffer, command_size, 0)
    NumPut(0xEF, command_buffer, 0, "UChar")
    NumPut(0xBB, command_buffer, 1, "UChar")
    NumPut(0xBF, command_buffer, 2, "UChar")
    StrPut(target_path, &command_buffer + 3, path_byte_count + 1, "UTF-8")
    NumPut(0x0D, command_buffer, 3 + path_byte_count, "UChar")
    NumPut(0x00, command_buffer, 4 + path_byte_count, "UChar")
    NumPut(Asc("S"), command_buffer, 5 + path_byte_count, "UChar")

    VarSetCapacity(copy_data, A_PtrSize * 3, 0)
    NumPut(Asc("C") + 256 * Asc("D"), copy_data, 0, "UPtr")
    NumPut(command_size, copy_data, A_PtrSize, "UInt")
    NumPut(&command_buffer, copy_data, A_PtrSize * 2, "Ptr")

    SendMessage, 0x4A, %A_ScriptHwnd%, &copy_data,, ahk_id %window_id%
    return (ErrorLevel != "FAIL")
}

; ==============================================================================
; 6. SELECTION & HAND-OFF
; ==============================================================================
#IfWinActive ahk_exe Everything.exe

+Enter::
    Clipboard := ""
    Send, ^+c 
    ClipWait, 1.2 
    if ErrorLevel 
        return 

    ; Get the window class of the original window
    WinGetClass, origClass, ahk_id %origWin%


	; Check if the Everything result is a Folder ("D" = Directory) or a File
	if InStr(FileExist(Clipboard), "D")
		targetPath := Clipboard
	else
		SplitPath, Clipboard,, targetPath ; If it's a file, extract its parent folder path



    ; Check if the original window is File Explorer
    if (origClass = "CabinetWClass" || origClass = "ExploreWClass") {
        

        ; Use COM to cleanly navigate the existing Explorer window to the new path
        for window in ComObjCreate("Shell.Application").Windows {
            if (window.hwnd == origWin) {
                window.Navigate(targetPath)
                break
            }
        }
        
    }
	
	else if ( origClass = "TTOTAL_CMD") 
	{
		if !navigateTotalCommander(origWin, targetPath)
		{
			MsgBox, 16, Everything Assistance, Total Commander did not accept the selected path.`n`nCheck that Total Commander and Everything Assistance use the same Windows privilege level.
			return
		}
	}
	else {
        ; Standard behavior for Open/Save/Browse dialogs
        ControlSetText, %origCtrl%, %Clipboard%, ahk_id %origWin%
    }
	
	
    
    ; Cleanup and window activation
    if (currentMode == "Manual") {
        WinClose, ahk_id %eWin% 
        currentMode := "None"
        WinActivate, ahk_id %origWin% ; Focus the window so you see the result
    } else {
        WinActivate, ahk_id %origWin%
    }
return

#IfWinActive
