#NoEnv
#SingleInstance Force  ; Standard behavior: don't allow multiple copies
SetBatchLines, -1
SetTitleMatchMode, 2
DetectHiddenWindows, On
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

global eHeight := 400
global padding := 0
global currentMode := "None"
global origWin := ""
global origCtrl := ""
global eWin := ""
global everythingPath := "%GoogleDrive%\TotalComander\_Utilities\Everything Portable\everything.exe"

#Persistent
SetTimer, DialogWatcher, 250
return

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

            ; Removed the "Min" flag so the window is allowed to draw properly
            Run, % everythingPath

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

    ; --- PATH VALIDATION & BROWSER ---
    if !FileExist(everythingPath) {
        MsgBox, 48, Path Not Found, Everything.exe was not found at:`n%everythingPath%`n`nPlease locate it.
        FileSelectFile, selectedPath, 3, %A_ProgramFiles%, Locate Everything.exe, Executables (*.exe)
        if (selectedPath = "") {
            return ; Abort if the user cancels the file dialog
        }
        everythingPath := selectedPath
    }
    ; ---------------------------------

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
        if (searchQuery != "") {
            Run, "%everythingPath%" -s "%searchQuery%"
        } else {
            Run, "%everythingPath%"
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
; ==============================================================================
; 5. SELECTION & HAND-OFF
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
		;msgBox, Total commander
	    Run, "D:\GoogleDrive\TotalComander\_TC-commands\file\go_to_path.ahk",,Min
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