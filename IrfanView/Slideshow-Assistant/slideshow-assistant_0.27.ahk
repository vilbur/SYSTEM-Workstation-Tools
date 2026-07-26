#NoEnv
#SingleInstance Off
#Persistent
#InstallKeybdHook

SetWorkingDir, %A_ScriptDir%

if not A_IsAdmin
{
    Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

; slideshow-assistant.ahk
; Version: 0.27
; Multiple instances are allowed; each instance binds to one exact IrfanView viewer session.
; Files are never deleted or overwritten; destructive actions move them to _DELETE or _CROP.

SetTitleMatchMode, 2
DetectHiddenWindows, On
SetBatchLines, -1
SetKeyDelay, -1, 10

interval := 3000
pause_duration	:= 3000

last_action_time := A_TickCount
pause_until := 0

current_image_path := ""
current_image_started := A_TickCount

learned_rename_map := {}
delete_move_queue := {}

is_ctrl_space_combo := false
crop_capture_pending := false
crop_save_in_progress := false

pending_transform_image_path := ""
pending_transform_iv_exe_path := ""
pending_transform_rotation_quarters := 0
pending_transform_flipped := false

bound_irfanview_process_id := 0
bound_irfanview_main_window_id := 0
bound_irfanview_anchor_window_id := 0
bound_irfanview_window_missing_since := 0
bound_irfanview_window_missing_grace := 500
instance_bind_deadline := A_TickCount + 15000
exit_work_started := false


SetTimer, CheckIrfanView, 100
SetTimer, DelayedLoadLearnedTime, -500

OnExit, handleExit
return


/*  AUTO SLIDESHOW HANDLER
 */
CheckIrfanView:

    if (exit_work_started)
    {
        return
    }

    if (!bound_irfanview_process_id)
    {
        if !bindToAvailableIrfanViewProcess()
        {
            if (A_TickCount >= instance_bind_deadline)
            {
                ExitApp
            }

            return
        }

        resetSlideTimer()
    }

    if !isBoundIrfanViewProcessRunning()
    {
        ExitApp
        return
    }

    if closeBlockedIrfanViewDialogs()
    {
        resetSlideTimer()
        return
    }

    if isBrowseSubdirsDialogOpen()
    {
        resetSlideTimer()
        return
    }

    main_window_id := getActiveMainIrfanViewWindow()

    if (!main_window_id)
    {
        return
    }

    if (crop_save_in_progress)
    {
        return
    }

    current_time := A_TickCount

    if (current_time < pause_until)
    {
        return
    }

    space_pressed := GetKeyState("Space", "P")
    ctrl_pressed := GetKeyState("Ctrl", "P")
    alt_pressed := isAltModifierPressed()
    shift_pressed := GetKeyState("Shift", "P")
    lwin_pressed := GetKeyState("LWin", "P")
    rwin_pressed := GetKeyState("RWin", "P")

    if shouldPauseAutomaticNavigationForKeys(space_pressed, ctrl_pressed, alt_pressed, shift_pressed, lwin_pressed, rwin_pressed)
    {
        return
    }

    if (current_time - last_action_time >= interval)
    {
        learnCurrentImageTime()

        if !savePendingImageChangesBeforeNavigation()
        {
            resetSlideTimer()
            return
        }

        if !sendKeysToMainIrfanView("{Space}", main_window_id)
        {
            resetSlideTimer()
            return
        }

        last_action_time := A_TickCount

        SetTimer, DelayedLoadLearnedTime, -50
    }

return


/*  DELAYED IMAGE LEARNING REFRESH
 */
DelayedLoadLearnedTime:
    loadLearnedImageTime()
return

/*==============================================================================
	FUNCTIONS
================================================================================
*/

/*  CHECK WHETHER A WINDOW BELONGS TO ANY IRFANVIEW PROCESS
    This helper ignores the per-script process binding and is used only while binding.
 */
isAnyIrfanViewProcessWindow(window_id)
{
    if (!window_id || !DllCall("IsWindow", "Ptr", window_id))
    {
        return false
    }

    WinGet, process_name, ProcessName, ahk_id %window_id%

    return (process_name = "i_view64.exe" || process_name = "i_view32.exe")
}


/*  BIND THIS SCRIPT INSTANCE TO ONE IRFANVIEW PROCESS
    The active viewer is preferred; otherwise the topmost visible viewer is used.
 */
bindToAvailableIrfanViewProcess()
{
    global bound_irfanview_process_id
    global bound_irfanview_main_window_id

    if (bound_irfanview_process_id)
    {
        return isBoundIrfanViewProcessRunning()
    }

    active_window_id := WinExist("A")

    if bindToIrfanViewWindow(active_window_id)
    {
        return true
    }

    candidate_window_id := findTopmostVisibleIrfanViewViewerWindow()

    if (!candidate_window_id)
    {
        return false
    }

    return bindToIrfanViewWindow(candidate_window_id)
}


/*  BIND THIS SCRIPT INSTANCE TO THE PROCESS OWNING ONE VIEWER WINDOW
    Dialogs are rejected so a new instance never binds to Save As or Browse subdirs.
 */
bindToIrfanViewWindow(window_id)
{
    global bound_irfanview_process_id
    global bound_irfanview_main_window_id
    global bound_irfanview_anchor_window_id
    global bound_irfanview_window_missing_since

    if !isAnyIrfanViewProcessWindow(window_id)
    {
        return false
    }

    WinGetClass, window_class, ahk_id %window_id%

    if (window_class != "IrfanView" && window_class != "FullScreenClass")
    {
        return false
    }

    WinGet, process_id, PID, ahk_id %window_id%

    if (!process_id)
    {
        return false
    }

    bound_irfanview_process_id := process_id

    if (window_class = "IrfanView")
    {
        bound_irfanview_main_window_id := window_id
        bound_irfanview_anchor_window_id := window_id
    }
    else
    {
        bound_irfanview_main_window_id := getMainIrfanViewWindowForProcess(process_id)
        bound_irfanview_anchor_window_id := bound_irfanview_main_window_id

        if (!bound_irfanview_anchor_window_id)
        {
            bound_irfanview_anchor_window_id := window_id
        }
    }

    bound_irfanview_window_missing_since := 0

    return isWindowOwnedByProcess(bound_irfanview_anchor_window_id, bound_irfanview_process_id)
}


/*  FIND THE TOPMOST VISIBLE IRFANVIEW VIEWER WINDOW
    This fallback lets third-party launchers start the script before IrfanView gains focus.
 */
findTopmostVisibleIrfanViewViewerWindow()
{
    WinGet, window_list, List

    Loop, %window_list%
    {
        window_id := window_list%A_Index%

        if !DllCall("IsWindowVisible", "Ptr", window_id)
        {
            continue
        }

        if !isAnyIrfanViewProcessWindow(window_id)
        {
            continue
        }

        WinGetClass, window_class, ahk_id %window_id%

        if (window_class = "IrfanView" || window_class = "FullScreenClass")
        {
            return window_id
        }
    }

    return 0
}


/*  CHECK WHETHER ONE WINDOW STILL BELONGS TO THE EXPECTED PROCESS
    This avoids treating a recycled window handle as the original IrfanView viewer.
 */
isWindowOwnedByProcess(window_id, expected_process_id)
{
    if (!window_id || !expected_process_id)
    {
        return false
    }

    if !DllCall("IsWindow", "Ptr", window_id)
    {
        return false
    }

    actual_process_id := 0
    DllCall("GetWindowThreadProcessId", "Ptr", window_id, "UInt*", actual_process_id)

    return (actual_process_id = expected_process_id)
}


/*  CHECK WHETHER THIS INSTANCE'S ORIGINAL IRFANVIEW SESSION STILL EXISTS
    A hidden leftover main window is not considered alive unless its fullscreen surface is visible.
 */
isBoundIrfanViewProcessRunning()
{
    global bound_irfanview_process_id
    global bound_irfanview_anchor_window_id
    global bound_irfanview_window_missing_since
    global bound_irfanview_window_missing_grace

    if (!bound_irfanview_process_id || !bound_irfanview_anchor_window_id)
    {
        return false
    }

    Process, Exist, %bound_irfanview_process_id%

    if (ErrorLevel != bound_irfanview_process_id)
    {
        return false
    }

    bound_viewer_is_visible := false

    if isWindowOwnedByProcess(bound_irfanview_anchor_window_id, bound_irfanview_process_id)
    {
        if DllCall("IsWindowVisible", "Ptr", bound_irfanview_anchor_window_id)
        {
            bound_viewer_is_visible := true
        }
        else if hasVisibleFullscreenWindowForBoundProcess()
        {
            bound_viewer_is_visible := true
        }
    }

    if (bound_viewer_is_visible)
    {
        bound_irfanview_window_missing_since := 0
        return true
    }

    if (!bound_irfanview_window_missing_since)
    {
        bound_irfanview_window_missing_since := A_TickCount
        return true
    }

    return (A_TickCount - bound_irfanview_window_missing_since < bound_irfanview_window_missing_grace)
}


/*  CHECK FOR THE FULLSCREEN SURFACE OF THIS INSTANCE'S BOUND IRFANVIEW PROCESS
    A different normal IrfanView window is never accepted as a replacement session.
 */
hasVisibleFullscreenWindowForBoundProcess()
{
    global bound_irfanview_process_id

    if (!bound_irfanview_process_id)
    {
        return false
    }

    WinGet, window_list, List, ahk_pid %bound_irfanview_process_id%

    Loop, %window_list%
    {
        window_id := window_list%A_Index%

        if !DllCall("IsWindowVisible", "Ptr", window_id)
        {
            continue
        }

        WinGetClass, window_class, ahk_id %window_id%

        if (window_class = "FullScreenClass")
        {
            return true
        }
    }

    return false
}


/*  TEST WINDOW-TO-PROCESS OWNERSHIP DETECTION
    The script's own hidden window must belong to the current AutoHotkey process.
 */
testBoundIrfanViewLifetimeDetection()
{
    script_process_id := DllCall("GetCurrentProcessId", "UInt")

    return (isWindowOwnedByProcess(A_ScriptHwnd, script_process_id)
        && !isWindowOwnedByProcess(0, script_process_id))
}


/*  TEST PER-INSTANCE PROCESS ISOLATION
    A bound instance accepts only windows owned by its stored IrfanView process ID.
 */
testMultiInstanceProcessIsolation()
{
    global bound_irfanview_process_id

    if (!bound_irfanview_process_id)
    {
        return true
    }

    active_window_id := WinExist("A")

    if !isAnyIrfanViewProcessWindow(active_window_id)
    {
        return true
    }

    WinGet, active_process_id, PID, ahk_id %active_window_id%

    return (isIrfanViewProcessWindow(active_window_id)
        = (active_process_id = bound_irfanview_process_id))
}


/*  CHECK WHETHER A WINDOW IS AN IRFANVIEW MAIN VIEWER
    Dialogs and auxiliary IrfanView windows are rejected by window class.
 */
isMainIrfanViewWindow(window_id)
{
    if !isIrfanViewProcessWindow(window_id)
    {
        return false
    }

    WinGetClass, window_class, ahk_id %window_id%

    return (window_class = "IrfanView")
}


/*  CHECK WHETHER A WINDOW BELONGS TO AN IRFANVIEW PROCESS
    Both the normal viewer and the fullscreen presentation context are accepted.
 */
isIrfanViewProcessWindow(window_id)
{
    global bound_irfanview_process_id

    if !isAnyIrfanViewProcessWindow(window_id)
    {
        return false
    }

    if (!bound_irfanview_process_id)
    {
        return false
    }

    WinGet, process_id, PID, ahk_id %window_id%

    return (process_id = bound_irfanview_process_id)
}


/*  CHECK WHETHER THE ACTIVE IRFANVIEW WINDOW IS A DIALOG
    Standard dialogs remain outside the script hotkey context.
 */
isIrfanViewDialogWindow(window_id)
{
    if !isIrfanViewProcessWindow(window_id)
    {
        return false
    }

    WinGetClass, window_class, ahk_id %window_id%

    if (window_class = "#32770")
    {
        return true
    }

    if (window_class = "IrfanView")
    {
        return false
    }

    WinGetTitle, window_title, ahk_id %window_id%

    return RegExMatch(window_title
        , "i)^(Open|Save|Save Picture As|Properties|Settings|Browse\s+sub(?:dir|dirs|directories)|Batch|Rename|Print|About)(?:\b|\s|$)")
}


/*  FIND THE NORMAL IRFANVIEW MAIN WINDOW FOR ONE PROCESS
    Fullscreen commands are sent to this controller window behind the presentation.
 */
getMainIrfanViewWindowForProcess(process_id)
{
    global bound_irfanview_process_id
    global bound_irfanview_main_window_id

    if (!process_id || process_id != bound_irfanview_process_id)
    {
        return 0
    }

    if isWindowOwnedByProcess(bound_irfanview_main_window_id, process_id)
    {
        return bound_irfanview_main_window_id
    }

    WinGet, window_list, List, ahk_pid %process_id%

    Loop, %window_list%
    {
        window_id := window_list%A_Index%

        if isMainIrfanViewWindow(window_id)
        {
            return window_id
        }
    }

    return 0
}


/*  GET THE MAIN IRFANVIEW CONTROLLER FOR THE ACTIVE VIEWING CONTEXT
    Fullscreen presentation is accepted; IrfanView dialogs and other apps return zero.
 */
getActiveMainIrfanViewWindow()
{
    active_window_id := WinExist("A")

    if !isIrfanViewProcessWindow(active_window_id)
    {
        return 0
    }

    if isIrfanViewDialogWindow(active_window_id)
    {
        return 0
    }

    if isMainIrfanViewWindow(active_window_id)
    {
        return active_window_id
    }

    WinGet, process_id, PID, ahk_id %active_window_id%

    return getMainIrfanViewWindowForProcess(process_id)
}


/*  CHECK WHETHER AN IRFANVIEW IMAGE VIEWER IS ACTIVE
    Only the normal IrfanView viewer or FullScreenClass enables script hotkeys.
 */
isMainIrfanViewWindowActive()
{
    global bound_irfanview_process_id
    global exit_work_started

    if (exit_work_started)
    {
        return false
    }

    if (!bound_irfanview_process_id)
    {
        bindToAvailableIrfanViewProcess()
    }

    return isIrfanViewViewerWindow(WinExist("A"))
}


/*  CHECK WHETHER EITHER ALT KEY IS PHYSICALLY PRESSED
    Alt is never used as a script hotkey; this guard protects native Alt+Tab.
 */
isAltModifierPressed()
{
    return (GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P"))
}


/*  DECIDE WHETHER AUTOMATIC NAVIGATION MUST WAIT FOR HELD KEYS
    Alt is included only to prevent scripted sends from interrupting Alt+Tab.
 */
shouldPauseAutomaticNavigationForKeys(space_pressed, ctrl_pressed, alt_pressed, shift_pressed, lwin_pressed, rwin_pressed)
{
    return (space_pressed
        || ctrl_pressed
        || alt_pressed
        || shift_pressed
        || lwin_pressed
        || rwin_pressed)
}


/*  TEST AUTOMATIC-NAVIGATION MODIFIER GUARDS
    Confirms Alt alone pauses scripted navigation while no held key does not.
 */
testAutomaticNavigationModifierGuard()
{
    return (shouldPauseAutomaticNavigationForKeys(false, false, true, false, false, false)
        && shouldPauseAutomaticNavigationForKeys(false, true, false, false, false, false)
        && !shouldPauseAutomaticNavigationForKeys(false, false, false, false, false, false))
}


/*  SEND SCRIPTED KEYS ONLY TO A CONFIRMED MAIN IRFANVIEW WINDOW
    The send is cancelled if focus moved, a dialog opened, or Alt is held.
 */
sendKeysToMainIrfanView(keys_to_send, expected_window_id := 0)
{
    if isAltModifierPressed()
    {
        return false
    }

    main_window_id := expected_window_id

    if (!main_window_id)
    {
        main_window_id := getActiveMainIrfanViewWindow()
    }

    if !isMainIrfanViewWindow(main_window_id)
    {
        return false
    }

    active_main_window_id := getActiveMainIrfanViewWindow()

    if (active_main_window_id != main_window_id)
    {
        return false
    }

    ControlSend,, %keys_to_send%, ahk_id %main_window_id%

    return !ErrorLevel
}


/*  TEST MAIN-WINDOW HOTKEY TARGET ISOLATION
    Returns true only while the exact active window is an IrfanView main viewer.
 */
testMainIrfanViewHotkeyTarget()
{
    main_window_id := getActiveMainIrfanViewWindow()

    if (!main_window_id)
    {
        return false
    }

    return (isMainIrfanViewWindow(main_window_id)
        && getActiveMainIrfanViewWindow() = main_window_id)
}


/*  TEST FULLSCREEN CONTROLLER RESOLUTION
    Returns true when the active IrfanView viewing context resolves to one main controller.
 */
testFullscreenMainWindowResolution()
{
    main_window_id := getActiveMainIrfanViewWindow()

    if (!main_window_id)
    {
        return false
    }

    WinGet, process_id, PID, ahk_id %main_window_id%

    return (main_window_id = getMainIrfanViewWindowForProcess(process_id))
}


/*  CHECK WHETHER A WINDOW IS AN IRFANVIEW IMAGE VIEWER
    Only the normal viewer and IrfanView fullscreen viewer are accepted.
 */
isIrfanViewViewerWindow(window_id)
{
    if !isIrfanViewProcessWindow(window_id)
    {
        return false
    }

    WinGetClass, window_class, ahk_id %window_id%

    return (window_class = "IrfanView" || window_class = "FullScreenClass")
}


/*  GET THE ACTIVE IRFANVIEW VIEWER WINDOW
    Normal and fullscreen viewers are accepted; every dialog is rejected.
 */
getActiveIrfanViewViewerWindow()
{
    active_window_id := WinExist("A")

    if !isIrfanViewViewerWindow(active_window_id)
    {
        return 0
    }

    return active_window_id
}


/*  GET THE STANDARD CURSOR-ARROW KEY FOR ONE WASD DIRECTION
    The returned key name is sent as a normal foreground arrow press.
 */
getWasdArrowKey(wasd_key)
{
    if (wasd_key = "w")
    {
        return "{Up}"
    }

    if (wasd_key = "a")
    {
        return "{Left}"
    }

    if (wasd_key = "s")
    {
        return "{Down}"
    }

    if (wasd_key = "d")
    {
        return "{Right}"
    }

    return ""
}


/*  SEND ONE NORMAL ARROW PRESS TO THE ACTIVE IRFANVIEW VIEWER
    SendInput is used only after the active normal or fullscreen viewer is confirmed.
 */
sendWasdArrowToActiveIrfanView(wasd_key)
{
    viewer_window_id := getActiveIrfanViewViewerWindow()
    arrow_key := getWasdArrowKey(wasd_key)

    if (!viewer_window_id || arrow_key = "")
    {
        return false
    }

    if (getActiveIrfanViewViewerWindow() != viewer_window_id)
    {
        return false
    }

    SendInput, %arrow_key%

    return (getActiveIrfanViewViewerWindow() = viewer_window_id)
}


/*  TEST THE WASD-TO-STANDARD-ARROW MAPPING
    Returns true when every WASD key maps to the expected cursor-arrow key.
 */
testWasdArrowMapping()
{
    return (getWasdArrowKey("w") = "{Up}"
        && getWasdArrowKey("a") = "{Left}"
        && getWasdArrowKey("s") = "{Down}"
        && getWasdArrowKey("d") = "{Right}"
        && getWasdArrowKey("x") = "")
}


/*  CAPTURE ONE IRFANVIEW WINDOW POSITION BEFORE A HIDDEN CONVERSION
    The snapshot is used only once and never creates a repeating monitor lock.
 */
captureIrfanViewWindowSnapshot(window_id)
{
    if !isMainIrfanViewWindow(window_id)
    {
        return false
    }

    monitor_handle := DllCall("MonitorFromWindow", "Ptr", window_id, "UInt", 2, "Ptr")

    if (!monitor_handle)
    {
        return false
    }

    VarSetCapacity(monitor_info, 40, 0)
    NumPut(40, monitor_info, 0, "UInt")

    if !DllCall("GetMonitorInfo", "Ptr", monitor_handle, "Ptr", &monitor_info)
    {
        return false
    }

    WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_id%
    WinGet, window_state, MinMax, ahk_id %window_id%
    WinGet, window_style, Style, ahk_id %window_id%

    snapshot := {monitor_handle: monitor_handle
        , monitor_left: NumGet(monitor_info, 4, "Int")
        , monitor_top: NumGet(monitor_info, 8, "Int")
        , monitor_right: NumGet(monitor_info, 12, "Int")
        , monitor_bottom: NumGet(monitor_info, 16, "Int")
        , window_x: window_x
        , window_y: window_y
        , window_width: window_width
        , window_height: window_height
        , window_state: window_state
        , has_placement: false
        , was_fullscreen: false}

    snapshot.was_fullscreen := (!(window_style & 0x00C00000)
        && Abs(window_x - snapshot.monitor_left) <= 3
        && Abs(window_y - snapshot.monitor_top) <= 3
        && Abs((window_x + window_width) - snapshot.monitor_right) <= 3
        && Abs((window_y + window_height) - snapshot.monitor_bottom) <= 3)

    VarSetCapacity(window_placement, 44, 0)
    NumPut(44, window_placement, 0, "UInt")

    if DllCall("GetWindowPlacement", "Ptr", window_id, "Ptr", &window_placement)
    {
        snapshot.has_placement := true
        snapshot.placement_flags := NumGet(window_placement, 4, "UInt")
        snapshot.show_command := NumGet(window_placement, 8, "UInt")
        snapshot.min_x := NumGet(window_placement, 12, "Int")
        snapshot.min_y := NumGet(window_placement, 16, "Int")
        snapshot.max_x := NumGet(window_placement, 20, "Int")
        snapshot.max_y := NumGet(window_placement, 24, "Int")
        snapshot.normal_left := NumGet(window_placement, 28, "Int")
        snapshot.normal_top := NumGet(window_placement, 32, "Int")
        snapshot.normal_right := NumGet(window_placement, 36, "Int")
        snapshot.normal_bottom := NumGet(window_placement, 40, "Int")
    }

    return snapshot
}


/*  RESTORE A VIEWER ONCE ONLY IF A HIDDEN CONVERSION MOVED IT
    No timer watches or repeatedly moves the IrfanView window.
 */
restoreIrfanViewWindowAfterConversion(window_id, snapshot)
{
    if !IsObject(snapshot)
    {
        return false
    }

    if (!DllCall("IsWindow", "Ptr", window_id) || !isMainIrfanViewWindow(window_id))
    {
        return false
    }

    current_monitor_handle := DllCall("MonitorFromWindow", "Ptr", window_id, "UInt", 2, "Ptr")

    if (current_monitor_handle = snapshot.monitor_handle)
    {
        return true
    }

    if !isSnapshotMonitorAvailable(snapshot)
    {
        return false
    }

    if (snapshot.was_fullscreen)
    {
        return setWindowPositionWithoutActivation(window_id
            , snapshot.monitor_left
            , snapshot.monitor_top
            , snapshot.monitor_right - snapshot.monitor_left
            , snapshot.monitor_bottom - snapshot.monitor_top)
    }

    if (snapshot.has_placement)
    {
        VarSetCapacity(window_placement, 44, 0)
        NumPut(44, window_placement, 0, "UInt")
        NumPut(snapshot.placement_flags, window_placement, 4, "UInt")
        NumPut(snapshot.show_command, window_placement, 8, "UInt")
        NumPut(snapshot.min_x, window_placement, 12, "Int")
        NumPut(snapshot.min_y, window_placement, 16, "Int")
        NumPut(snapshot.max_x, window_placement, 20, "Int")
        NumPut(snapshot.max_y, window_placement, 24, "Int")
        NumPut(snapshot.normal_left, window_placement, 28, "Int")
        NumPut(snapshot.normal_top, window_placement, 32, "Int")
        NumPut(snapshot.normal_right, window_placement, 36, "Int")
        NumPut(snapshot.normal_bottom, window_placement, 40, "Int")

        if DllCall("SetWindowPlacement", "Ptr", window_id, "Ptr", &window_placement)
        {
            return true
        }
    }

    return setWindowPositionWithoutActivation(window_id
        , snapshot.window_x
        , snapshot.window_y
        , snapshot.window_width
        , snapshot.window_height)
}


/*  CHECK THAT THE SNAPSHOT MONITOR STILL EXISTS
    Display-layout changes are respected instead of forcing stale coordinates.
 */
isSnapshotMonitorAvailable(snapshot)
{
    SysGet, monitor_count, MonitorCount

    Loop, %monitor_count%
    {
        SysGet, monitor_bounds, Monitor, %A_Index%

        if (monitor_boundsLeft = snapshot.monitor_left
            && monitor_boundsTop = snapshot.monitor_top
            && monitor_boundsRight = snapshot.monitor_right
            && monitor_boundsBottom = snapshot.monitor_bottom)
        {
            return true
        }
    }

    return false
}


/*  MOVE ONE WINDOW WITHOUT ACTIVATING IT
    This function is called at most once after one hidden conversion.
 */
setWindowPositionWithoutActivation(window_id, target_x, target_y, target_width, target_height)
{
    set_window_flags := 0x0214

    return DllCall("SetWindowPos"
        , "Ptr", window_id
        , "Ptr", 0
        , "Int", target_x
        , "Int", target_y
        , "Int", target_width
        , "Int", target_height
        , "UInt", set_window_flags)
}


/*  TEST THE SNAPSHOT MONITOR AVAILABILITY COMPARISON DATA
    Confirms that monitor coordinates remain internally consistent.
 */
testIrfanViewWindowSnapshotData()
{
    snapshot := {monitor_left: -1920
        , monitor_top: 0
        , monitor_right: 0
        , monitor_bottom: 1080
        , window_x: -1800
        , window_y: 100
        , window_width: 1200
        , window_height: 800}

    return (snapshot.monitor_right - snapshot.monitor_left = 1920
        && snapshot.monitor_bottom - snapshot.monitor_top = 1080
        && snapshot.window_x >= snapshot.monitor_left
        && snapshot.window_y >= snapshot.monitor_top)
}


/*  CHECK WHETHER IRFANVIEW'S BROWSE SUBDIRS DIALOG IS OPEN
    Automatic navigation remains paused until the visible dialog is closed.
 */
isBrowseSubdirsDialogOpen()
{
    global bound_irfanview_process_id

    return hasVisibleIrfanViewDialogTitle(bound_irfanview_process_id
        , "i)Browse\s+sub(?:dir|dirs|directories)")
}


/*  SEARCH VISIBLE WINDOWS OF THE BOUND IRFANVIEW PROCESS FOR A DIALOG TITLE
    Other concurrent IrfanView processes and their dialogs are ignored.
 */
hasVisibleIrfanViewDialogTitle(process_id, title_pattern)
{
    if (!process_id)
    {
        return false
    }

    WinGet, window_list, List, ahk_pid %process_id%

    Loop, %window_list%
    {
        window_id := window_list%A_Index%

        if !DllCall("IsWindowVisible", "Ptr", window_id)
        {
            continue
        }

        WinGetClass, window_class, ahk_id %window_id%

        if (window_class = "IrfanView")
        {
            continue
        }

        WinGetTitle, window_title, ahk_id %window_id%

        if RegExMatch(window_title, title_pattern)
        {
            return true
        }
    }

    return false
}


/*  TEST BROWSE SUBDIRS DIALOG DETECTION
    Open the dialog in IrfanView, then call this function from a temporary test hotkey.
 */
testBrowseSubdirsDialogDetection()
{
    return isBrowseSubdirsDialogOpen()
}


/*  CHECK WHETHER A DIALOG TITLE MUST BE BLOCKED
    Accidental Save As and Properties/Preferences dialogs are blocked; Browse subdirs is always allowed.
 */
isBlockedIrfanViewDialogTitle(window_title)
{
    if RegExMatch(window_title, "i)Browse\s+sub(?:dir|dirs|directories)")
    {
        return false
    }

    return RegExMatch(window_title
        , "i)(Save\s+Picture\s+As|Save\s+As|Properties(?:\s*/\s*Settings)?|Preferences|Settings)")
}


/*  CLOSE ACCIDENTAL IRFANVIEW DIALOGS WITHOUT SENDING KEYS
    Only blocked Save/Preferences-style dialogs are closed; Browse subdirs remains untouched.
 */
closeBlockedIrfanViewDialogs()
{
    global bound_irfanview_process_id

    if (!bound_irfanview_process_id)
    {
        return false
    }

    blocked_dialog_closed := false
    WinGet, window_list, List, ahk_pid %bound_irfanview_process_id%

    Loop, %window_list%
    {
        window_id := window_list%A_Index%

        if !DllCall("IsWindowVisible", "Ptr", window_id)
        {
            continue
        }

        WinGetClass, window_class, ahk_id %window_id%

        if (window_class != "#32770")
        {
            continue
        }

        WinGetTitle, window_title, ahk_id %window_id%

        if !isBlockedIrfanViewDialogTitle(window_title)
        {
            continue
        }

        PostMessage, 0x0010, 0, 0,, ahk_id %window_id%
        blocked_dialog_closed := true
    }

    return blocked_dialog_closed
}


/*  TEST BLOCKED DIALOG TITLE FILTERING
    Confirms Save/Preferences dialogs are blocked while Browse subdirs is allowed.
 */
testBlockedIrfanViewDialogTitles()
{
    return (isBlockedIrfanViewDialogTitle("Save Picture As ...")
        && isBlockedIrfanViewDialogTitle("Save As")
        && isBlockedIrfanViewDialogTitle("Properties/Settings")
        && isBlockedIrfanViewDialogTitle("Preferences")
        && !isBlockedIrfanViewDialogTitle("Browse subdirs")
        && !isBlockedIrfanViewDialogTitle("Browse subdirectories"))
}


/*  MARK CURRENT FULLSCREEN VIEW AS HAVING AN UNSAVED CROP
    No screenshot is taken until the image is about to change.
 */
markCropCapturePending()
{
    global crop_capture_pending

    crop_capture_pending := true

    ;-- return
}


/*  CLEAR THE DEFERRED L/R/H TRANSFORM STATE
    The current image path and normalized orientation are reset together.
 */
clearPendingImageTransform()
{
    global pending_transform_image_path
    global pending_transform_iv_exe_path
    global pending_transform_rotation_quarters
    global pending_transform_flipped

    pending_transform_image_path := ""
    pending_transform_iv_exe_path := ""
    pending_transform_rotation_quarters := 0
    pending_transform_flipped := false

    ;-- return
}


/*  QUEUE ONE NATIVE IRFANVIEW L/R/H TRANSFORM
    Repeated transforms are normalized to one rotation plus an optional horizontal flip.
 */
queuePendingImageTransform(transform_name)
{
    global pending_transform_image_path
    global pending_transform_iv_exe_path
    global pending_transform_rotation_quarters
    global pending_transform_flipped

    full_path := getPathFromTitle(true)
    main_window_id := getActiveMainIrfanViewWindow()

    if (full_path = "" || !FileExist(full_path) || !main_window_id)
    {
        return false
    }

    WinGet, iv_exe_path, ProcessPath, ahk_id %main_window_id%

    if (iv_exe_path = "")
    {
        return false
    }

    if (pending_transform_image_path != "" && pending_transform_image_path != full_path)
    {
        return false
    }

    pending_transform_image_path := full_path
    pending_transform_iv_exe_path := iv_exe_path

    if (transform_name = "r")
    {
        if (pending_transform_flipped)
        {
            pending_transform_rotation_quarters := Mod(pending_transform_rotation_quarters + 3, 4)
        }
        else
        {
            pending_transform_rotation_quarters := Mod(pending_transform_rotation_quarters + 1, 4)
        }

        return true
    }

    if (transform_name = "l")
    {
        if (pending_transform_flipped)
        {
            pending_transform_rotation_quarters := Mod(pending_transform_rotation_quarters + 1, 4)
        }
        else
        {
            pending_transform_rotation_quarters := Mod(pending_transform_rotation_quarters + 3, 4)
        }

        return true
    }

    if (transform_name = "h")
    {
        pending_transform_flipped := !pending_transform_flipped
        return true
    }

    return false
}


/*  BUILD THE MINIMAL IRFANVIEW COMMAND SEQUENCE FOR L/R/H
    The returned array contains zero to three command-line transform options.
 */
getPendingImageTransformOptions(rotation_quarters, is_flipped)
{
    transform_options := []
    normalized_rotation := Mod(rotation_quarters, 4)

    if (normalized_rotation = 1)
    {
        transform_options.Push("/rotate_r")
    }
    else if (normalized_rotation = 2)
    {
        transform_options.Push("/rotate_r")
        transform_options.Push("/rotate_r")
    }
    else if (normalized_rotation = 3)
    {
        transform_options.Push("/rotate_l")
    }

    if (is_flipped)
    {
        transform_options.Push("/hflip")
    }

    return transform_options
}


/*  RUN ONE HIDDEN EXTERNAL COMMAND WITH A HARD TIME LIMIT
    Exit cleanup can never remain blocked forever inside IrfanView conversion.
 */
runHiddenCommandWithTimeout(command_line, timeout_ms := 15000)
{
    Run, %command_line%,, Hide UseErrorLevel, process_id

    if (ErrorLevel || !process_id)
    {
        return false
    }

    command_started := A_TickCount

    Loop
    {
        Process, Exist, %process_id%

        if (ErrorLevel != process_id)
        {
            return true
        }

        if (A_TickCount - command_started >= timeout_ms)
        {
            return false
        }

        Sleep, 50
    }
}


/*  APPLY DEFERRED L/R/H TRANSFORMS TO THE ORIGINAL IMAGE PATH
    The untouched source is moved to _CROP before the transformed file replaces it.
 */
savePendingImageTransforms()
{
    global crop_save_in_progress
    global pending_transform_image_path
    global pending_transform_iv_exe_path
    global pending_transform_rotation_quarters
    global pending_transform_flipped

    if (pending_transform_image_path = "")
    {
        return true
    }

    source_path := pending_transform_image_path
    iv_exe_path := pending_transform_iv_exe_path
    transform_options := getPendingImageTransformOptions(pending_transform_rotation_quarters, pending_transform_flipped)

    if (transform_options.Length() = 0)
    {
        clearPendingImageTransform()
        return true
    }

    if (!FileExist(source_path) || iv_exe_path = "" || !FileExist(iv_exe_path))
    {
        return false
    }

    main_window_id := getActiveMainIrfanViewWindow()
    window_snapshot := ""

    if (main_window_id)
    {
        window_snapshot := captureIrfanViewWindowSnapshot(main_window_id)
    }

    SplitPath, source_path, source_name, source_dir, source_ext, source_name_no_ext
    current_input_path := source_path
    final_temp_path := ""
    crop_save_in_progress := true
    Critical, On

    for option_index, transform_option in transform_options
    {
        is_final_option := (option_index = transform_options.Length())
        temp_extension := is_final_option ? source_ext : "png"
        temp_name := source_name_no_ext . ".__transform_temp_" . option_index . "__"

        if (temp_extension != "")
        {
            temp_name .= "." . temp_extension
        }

        output_path := getUniqueFilePath(source_dir . "\" . temp_name)
        command_line := Chr(34) . iv_exe_path . Chr(34) . " " . Chr(34) . current_input_path . Chr(34) . " /silent " . transform_option . " /convert=" . Chr(34) . output_path . Chr(34)

        conversion_succeeded := runHiddenCommandWithTimeout(command_line, 5000)

        if (!conversion_succeeded || !FileExist(output_path))
        {
            if FileExist(output_path)
            {
                moveFileToSubdirectory(output_path, "_DELETE")
            }

            if (current_input_path != source_path && FileExist(current_input_path))
            {
                moveFileToSubdirectory(current_input_path, "_DELETE")
            }

            crop_save_in_progress := false
            Critical, Off

            if (main_window_id)
            {
                restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)
            }

            return false
        }

        FileGetSize, output_size, %output_path%

        if (output_size <= 0)
        {
            moveFileToSubdirectory(output_path, "_DELETE")

            if (current_input_path != source_path && FileExist(current_input_path))
            {
                moveFileToSubdirectory(current_input_path, "_DELETE")
            }

            crop_save_in_progress := false
            Critical, Off

            if (main_window_id)
            {
                restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)
            }

            return false
        }

        if (current_input_path != source_path && FileExist(current_input_path))
        {
            moveFileToSubdirectory(current_input_path, "_DELETE")
        }

        current_input_path := output_path
        final_temp_path := output_path
    }

    crop_backup_path := moveFileToSubdirectory(source_path, "_CROP")

    if (crop_backup_path = "")
    {
        if FileExist(final_temp_path)
        {
            moveFileToSubdirectory(final_temp_path, "_DELETE")
        }

        crop_save_in_progress := false
        Critical, Off

        if (main_window_id)
        {
            restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)
        }

        return false
    }

    FileMove, %final_temp_path%, %source_path%, 0

    if ErrorLevel
    {
        if !FileExist(source_path)
        {
            FileCopy, %crop_backup_path%, %source_path%, 0
        }

        if FileExist(final_temp_path)
        {
            moveFileToSubdirectory(final_temp_path, "_DELETE")
        }

        crop_save_in_progress := false
        Critical, Off

        if (main_window_id)
        {
            restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)
        }

        return false
    }

    clearPendingImageTransform()
    crop_save_in_progress := false
    Critical, Off

    if (main_window_id)
    {
        restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)
    }

    return true
}


/*  SAVE ALL PENDING IMAGE CHANGES BEFORE NAVIGATION
    Fullscreen pan/zoom crops take priority because their screenshot already includes L/R/H transforms.
 */
savePendingImageChangesBeforeNavigation()
{
    global crop_capture_pending

    if (crop_capture_pending && isActiveIrfanViewFullscreen())
    {
        save_succeeded := savePendingFullscreenCropBeforeNavigation()

        if (save_succeeded)
        {
            clearPendingImageTransform()
        }
        else
        {
            crop_capture_pending := true
        }

        return save_succeeded
    }

    if (crop_capture_pending)
    {
        crop_capture_pending := false
    }

    return savePendingImageTransforms()
}


/*  TEST L/R/H TRANSFORM NORMALIZATION
    Confirms inverse rotations cancel and ordered flip/rotation combinations stay distinct.
 */
testPendingTransformNormalization()
{
    rotation_quarters := 0
    is_flipped := false

    rotation_quarters := Mod(rotation_quarters + 1, 4)
    rotation_quarters := Mod(rotation_quarters + 3, 4)
    cancel_options := getPendingImageTransformOptions(rotation_quarters, is_flipped)

    first_options := getPendingImageTransformOptions(1, true)
    second_options := getPendingImageTransformOptions(3, true)

    return (cancel_options.Length() = 0
        && first_options.Length() = 2
        && first_options[1] = "/rotate_r"
        && first_options[2] = "/hflip"
        && second_options.Length() = 2
        && second_options[1] = "/rotate_l"
        && second_options[2] = "/hflip")
}


/*  SAVE ONE PENDING FULLSCREEN CROP BEFORE IRFANVIEW CHANGES IMAGE
    Screenshot is taken only when the active IrfanView image is fullscreen.
 */
savePendingFullscreenCropBeforeNavigation()
{
    global crop_capture_pending
    global crop_save_in_progress

    if (!crop_capture_pending || crop_save_in_progress)
    {
        return false
    }

    crop_capture_pending := false

    if !isActiveIrfanViewFullscreen()
    {
        return false
    }

    crop_save_in_progress := true
    Critical, On
    save_succeeded := saveCroppedImage()
    crop_save_in_progress := false
    Critical, Off

    return save_succeeded
}


/* CAPTURE AND SAVE THE CURRENT FULLSCREEN IRFANVIEW VIEW
    The active-window screenshot remains in the Windows clipboard.
*/
saveCroppedImage()
{
    if !isActiveIrfanViewFullscreen()
    {
        return false
    }

    main_window_id := getActiveMainIrfanViewWindow()

    if (!main_window_id)
    {
        return false
    }

    full_path := getPathFromTitle(true)

    if (full_path = "")
    {
        return false
    }

    WinGet, iv_exe_path, ProcessPath, ahk_id %main_window_id%

    if (iv_exe_path = "")
    {
        return false
    }

    if !captureMainIrfanViewToClipboard(main_window_id)
    {
        MsgBox, 16, Error, Failed to capture the fullscreen cropped image to the clipboard.
        return false
    }

    SplitPath, full_path, image_name, image_dir, image_ext, image_name_no_ext

    temp_crop_name := image_name_no_ext . ".__crop_temp__"

    if (image_ext != "")
    {
        temp_crop_name .= "." . image_ext
    }

    temp_crop_path := getUniqueFilePath(image_dir . "\" . temp_crop_name)
    window_snapshot := captureIrfanViewWindowSnapshot(main_window_id)

    RunWait, "%iv_exe_path%" /silent /clippaste /convert="%temp_crop_path%",, Hide UseErrorLevel

    restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)

    if !FileExist(temp_crop_path)
    {
        MsgBox, 16, Error, IrfanView did not create the cropped image.`n`nOriginal image was not changed.
        return false
    }

    FileGetSize, temp_crop_size, %temp_crop_path%

    if (temp_crop_size <= 0)
    {
        moveFileToSubdirectory(temp_crop_path, "_DELETE")
        MsgBox, 16, Error, The cropped image file is empty.`n`nOriginal image was not changed.
        return false
    }

    crop_backup_path := moveFileToSubdirectory(full_path, "_CROP")

    if (crop_backup_path = "")
    {
        moveFileToSubdirectory(temp_crop_path, "_DELETE")
        MsgBox, 16, Error, Could not move the original image into the _CROP subfolder:`n%full_path%
        return false
    }

    ; 1) Remove the duration suffix (e.g., "-3s") from the file in the _CROP directory
    SplitPath, crop_backup_path, backup_name, backup_dir, backup_ext, backup_name_no_ext
    clean_backup_name_no_ext := RegExReplace(backup_name_no_ext, "-[0-9]+s$")
    
    if (clean_backup_name_no_ext != backup_name_no_ext)
    {
        clean_backup_name_full := clean_backup_name_no_ext
        if (backup_ext != "")
        {
            clean_backup_name_full .= "." . backup_ext
        }
        
        clean_backup_path := getUniqueFilePath(backup_dir . "\" . clean_backup_name_full)
        FileMove, %crop_backup_path%, %clean_backup_path%, 0
        
        if !ErrorLevel
        {
            crop_backup_path := clean_backup_path
        }
    }

    ; 2) Add suffix "_crop" to the newly created cropped image
    final_crop_name := clean_backup_name_no_ext . "_crop"
    if (image_ext != "")
    {
        final_crop_name .= "." . image_ext
    }
    final_crop_path := getUniqueFilePath(image_dir . "\" . final_crop_name)

    ; Move the cropped temp file to the final destination
    FileMove, %temp_crop_path%, %final_crop_path%, 0

    if ErrorLevel
    {
        if !FileExist(final_crop_path)
        {
            FileCopy, %crop_backup_path%, %final_crop_path%, 0
        }

        moveFileToSubdirectory(temp_crop_path, "_DELETE")
        MsgBox, 16, Error, Could not place the cropped image.`n`nThe untouched original remains in the _CROP subfolder.
        return false
    }

    return true
}

/*  CAPTURE THE ACTIVE IRFANVIEW FULLSCREEN DISPLAY TO THE CLIPBOARD
    The normal main controller remains the target even when fullscreen is drawn separately.
 */
captureMainIrfanViewToClipboard(window_id)
{
    if !isMainIrfanViewWindow(window_id)
    {
        return false
    }

    if (getActiveMainIrfanViewWindow() != window_id)
    {
        return false
    }

    if !isActiveIrfanViewFullscreen()
    {
        return false
    }

    monitor_handle := DllCall("MonitorFromWindow", "Ptr", window_id, "UInt", 2, "Ptr")

    if (!monitor_handle)
    {
        return false
    }

    VarSetCapacity(monitor_info, 40, 0)
    NumPut(40, monitor_info, 0, "UInt")

    if !DllCall("GetMonitorInfo", "Ptr", monitor_handle, "Ptr", &monitor_info)
    {
        return false
    }

    window_left := NumGet(monitor_info, 4, "Int")
    window_top := NumGet(monitor_info, 8, "Int")
    window_right := NumGet(monitor_info, 12, "Int")
    window_bottom := NumGet(monitor_info, 16, "Int")
    window_width := window_right - window_left
    window_height := window_bottom - window_top

    if (window_width <= 0 || window_height <= 0)
    {
        return false
    }

    screen_dc := DllCall("GetDC", "Ptr", 0, "Ptr")

    if (!screen_dc)
    {
        return false
    }

    memory_dc := DllCall("gdi32\CreateCompatibleDC", "Ptr", screen_dc, "Ptr")
    bitmap_handle := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", screen_dc, "Int", window_width, "Int", window_height, "Ptr")

    if (!memory_dc || !bitmap_handle)
    {
        if (bitmap_handle)
        {
            DllCall("gdi32\DeleteObject", "Ptr", bitmap_handle)
        }

        if (memory_dc)
        {
            DllCall("gdi32\DeleteDC", "Ptr", memory_dc)
        }

        DllCall("ReleaseDC", "Ptr", 0, "Ptr", screen_dc)
        return false
    }

    previous_bitmap := DllCall("gdi32\SelectObject", "Ptr", memory_dc, "Ptr", bitmap_handle, "Ptr")
    capture_succeeded := DllCall("gdi32\BitBlt"
        , "Ptr", memory_dc
        , "Int", 0
        , "Int", 0
        , "Int", window_width
        , "Int", window_height
        , "Ptr", screen_dc
        , "Int", window_left
        , "Int", window_top
        , "UInt", 0x00CC0020)

    DllCall("gdi32\SelectObject", "Ptr", memory_dc, "Ptr", previous_bitmap)
    DllCall("gdi32\DeleteDC", "Ptr", memory_dc)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", screen_dc)

    if (!capture_succeeded)
    {
        DllCall("gdi32\DeleteObject", "Ptr", bitmap_handle)
        return false
    }

    clipboard_opened := false

    Loop, 20
    {
        if DllCall("OpenClipboard", "Ptr", window_id)
        {
            clipboard_opened := true
            break
        }

        Sleep, 10
    }

    if (!clipboard_opened)
    {
        DllCall("gdi32\DeleteObject", "Ptr", bitmap_handle)
        return false
    }

    DllCall("EmptyClipboard")
    clipboard_bitmap := DllCall("SetClipboardData", "UInt", 2, "Ptr", bitmap_handle, "Ptr")
    DllCall("CloseClipboard")

    if (!clipboard_bitmap)
    {
        DllCall("gdi32\DeleteObject", "Ptr", bitmap_handle)
        return false
    }

    return true
}


/*  CHECK WHETHER THE ACTIVE IRFANVIEW VIEWING CONTEXT IS FULLSCREEN
    Handles both a borderless main window and a separate fullscreen presentation surface.
 */
isActiveIrfanViewFullscreen()
{
    main_window_id := getActiveMainIrfanViewWindow()

    if (!main_window_id)
    {
        return false
    }

    active_window_id := WinExist("A")

    if (active_window_id != main_window_id)
    {
        return true
    }

    if !DllCall("IsWindowVisible", "Ptr", main_window_id)
    {
        return true
    }

    WinGet, window_style, Style, ahk_id %main_window_id%

    if (window_style & 0x00C00000)
    {
        return false
    }

    VarSetCapacity(window_rect, 16, 0)

    if !DllCall("GetWindowRect", "Ptr", main_window_id, "Ptr", &window_rect)
    {
        return false
    }

    window_left := NumGet(window_rect, 0, "Int")
    window_top := NumGet(window_rect, 4, "Int")
    window_right := NumGet(window_rect, 8, "Int")
    window_bottom := NumGet(window_rect, 12, "Int")

    SysGet, monitor_count, MonitorCount

    Loop, %monitor_count%
    {
        SysGet, monitor_bounds, Monitor, %A_Index%

        if (Abs(window_left - monitor_boundsLeft) <= 3
            && Abs(window_top - monitor_boundsTop) <= 3
            && Abs(window_right - monitor_boundsRight) <= 3
            && Abs(window_bottom - monitor_boundsBottom) <= 3)
        {
            return true
        }
    }

    return false
}


/*  BUILD A COLLISION-SAFE FILE PATH
    Existing files are never overwritten.
 */
getUniqueFilePath(requested_path)
{
    if !FileExist(requested_path)
    {
        return requested_path
    }

    SplitPath, requested_path, file_name, file_dir, file_ext, file_name_no_ext
    suffix_index := 1

    Loop
    {
        candidate_name := file_name_no_ext . "_" . Format("{:03}", suffix_index)

        if (file_ext != "")
        {
            candidate_name .= "." . file_ext
        }

        candidate_path := file_dir . "\" . candidate_name

        if !FileExist(candidate_path)
        {
            return candidate_path
        }

        suffix_index++
    }
}


/*  MOVE A FILE INTO A PROTECTIVE SUBDIRECTORY
    The source is never deleted and an existing destination is never overwritten.
 */
moveFileToSubdirectory(source_path, subdirectory_name)
{
    if !FileExist(source_path)
    {
        return ""
    }

    SplitPath, source_path, source_name, source_dir
    destination_dir := source_dir . "\" . subdirectory_name

    if !FileExist(destination_dir)
    {
        FileCreateDir, %destination_dir%

        if !FileExist(destination_dir)
        {
            return ""
        }
    }

    destination_path := getUniqueFilePath(destination_dir . "\" . source_name)
    FileMove, %source_path%, %destination_path%, 0

    if ErrorLevel
    {
        return ""
    }

    return destination_path
}


/*  COPY CURRENT IMAGE TO ITS PARENT DIRECTORY AS FOLDER.JPG
    The current image is converted to JPEG without passing Ctrl+Shift+F to IrfanView.
 */
copyCurrentImageAsFolderJpg()
{
    full_path := getPathFromTitle(true)

    if (full_path = "" || !FileExist(full_path))
    {
        ToolTip, Could not resolve the current IrfanView image path.
        SetTimer, RemoveToolTip, -2500
        return false
    }

    main_window_id := getActiveMainIrfanViewWindow()

    if (!main_window_id)
    {
        return false
    }

    WinGet, iv_exe_path, ProcessPath, ahk_id %main_window_id%

    if (iv_exe_path = "")
    {
        ToolTip, Could not resolve the IrfanView executable.
        SetTimer, RemoveToolTip, -2500
        return false
    }

    SplitPath, full_path, image_name, image_dir
    SplitPath, image_dir, image_dir_name, parent_dir

    if (parent_dir = "")
    {
        ToolTip, The image directory has no parent directory.
        SetTimer, RemoveToolTip, -2500
        return false
    }

    destination_path := parent_dir . "\folder.jpg"
    temp_path := getUniqueFilePath(parent_dir . "\folder.__temp__.jpg")

    window_snapshot := captureIrfanViewWindowSnapshot(main_window_id)
    RunWait, "%iv_exe_path%" "%full_path%" /silent /convert="%temp_path%",, Hide UseErrorLevel
    conversion_error := ErrorLevel
    restoreIrfanViewWindowAfterConversion(main_window_id, window_snapshot)

    if (conversion_error || !FileExist(temp_path))
    {
        if FileExist(temp_path)
        {
            moveFileToSubdirectory(temp_path, "_DELETE")
        }

        ToolTip, Could not create folder.jpg.
        SetTimer, RemoveToolTip, -2500
        return false
    }

    FileGetSize, temp_size, %temp_path%

    if (temp_size <= 0)
    {
        moveFileToSubdirectory(temp_path, "_DELETE")
        ToolTip, Created folder.jpg was empty.
        SetTimer, RemoveToolTip, -2500
        return false
    }

    if FileExist(destination_path)
    {
        previous_folder_path := moveFileToSubdirectory(destination_path, "_DELETE")

        if (previous_folder_path = "")
        {
            moveFileToSubdirectory(temp_path, "_DELETE")
            ToolTip, Existing folder.jpg could not be protected in _DELETE.
            SetTimer, RemoveToolTip, -3000
            return false
        }
    }

    FileMove, %temp_path%, %destination_path%, 0

    if ErrorLevel
    {
        moveFileToSubdirectory(temp_path, "_DELETE")
        ToolTip, Could not place folder.jpg in the parent directory.
        SetTimer, RemoveToolTip, -3000
        return false
    }

    ToolTip, Copied current image as:`n%destination_path%
    SetTimer, RemoveToolTip, -2500

    return true
}


/*  TEST FOLDER.JPG DESTINATION PATH BUILDING
    Confirms that an image directory resolves to its parent folder.jpg path.
 */
testFolderJpgDestinationPath()
{
    test_image_path := "C:\Images\Album\photo.png"
    SplitPath, test_image_path, image_name, image_dir
    SplitPath, image_dir, image_dir_name, parent_dir
    destination_path := parent_dir . "\folder.jpg"

    return (destination_path = "C:\Images\folder.jpg")
}


/*  TEST COLLISION-SAFE FILE MOVING
    Creates two files with the same name and confirms both survive in _DELETE.
 */
testSafeFileMove()
{
    test_root := A_Temp . "\slideshow_assistant_move_test_" . A_TickCount
    FileCreateDir, %test_root%

    first_path := test_root . "\sample.txt"
    FileAppend, first, %first_path%
    first_moved_path := moveFileToSubdirectory(first_path, "_DELETE")

    FileAppend, second, %first_path%
    second_moved_path := moveFileToSubdirectory(first_path, "_DELETE")

    return (first_moved_path != ""
        && second_moved_path != ""
        && first_moved_path != second_moved_path
        && FileExist(first_moved_path)
        && FileExist(second_moved_path))
}


pauseSlideShow()
{
    global pause_until
    ;pause_until := Max(pause_until, A_TickCount) + 3000
	
	resetSlideTimer()
	
    pause_until := A_TickCount + 5000
}
pauseSlideShowAdd()
{
    global pause_until
    pause_until := Max(pause_until, A_TickCount) + 3000
}

/*  RESET SLIDESHOW TIMER
 */
resetSlideTimer()
{
    global last_action_time

    last_action_time := A_TickCount

    ;-- return
}


/*  STORE LEARNED RENAME ONLY
 */
learnCurrentImageTime()
{
    global interval
    global current_image_path
    global current_image_started
    global learned_rename_map

	current_image_path := getPathFromTitle()

    if (current_image_path = "")
        return

	
    elapsed_seconds := Round((A_TickCount - current_image_started) / 1000.0)
	
    if (elapsed_seconds < 1)
        return

    if (elapsed_seconds < interval / 1000)
        elapsed_seconds := interval / 1000

    SplitPath, current_image_path, name, dir, ext, name_no_ext

    clean_name := RegExReplace(name_no_ext, "-\d+s$")

    new_name := clean_name . "-" . elapsed_seconds . "s." . ext

    new_path := dir . "\" . new_name ;"

    learned_rename_map[current_image_path] := new_path

    ;-- return
}


/*  LOAD LEARNED TIMEOUT FROM IMAGE FILENAME
 */
loadLearnedImageTime()
{
    global interval
    global current_image_path
    global current_image_started
    global crop_capture_pending

    previous_image_path := current_image_path
    full_path := ""

    Loop, 10
    {
        full_path := getPathFromTitle(false)

        if (full_path != "")
        {
            break
        }

        Sleep, 50
    }

    if (full_path = "")
    {
        return
    }

    if (previous_image_path != "" && full_path != previous_image_path)
    {
        crop_capture_pending := false
    }

    current_image_path := full_path
    current_image_started := A_TickCount

    SplitPath, full_path, name, dir, ext, name_no_ext

    interval := 3000

    if RegExMatch(name_no_ext, "-(\d+)s$", match)
    {
        interval := Round(match1) * 1000
    }

    ;-- return
}


/*  GET IMAGE PATH FROM IRFANVIEW TITLE
    Search the active IrfanView process first, then every IrfanView window.
    Background checks never display a missing-title error dialog.
 */
getPathFromTitle(allow_cached_path := true)
{
    global current_image_path
    global bound_irfanview_process_id

    if (!bound_irfanview_process_id)
    {
        bindToAvailableIrfanViewProcess()
    }

    if (bound_irfanview_process_id)
    {
        full_path := getImagePathFromIrfanViewProcess(bound_irfanview_process_id)

        if (full_path != "")
        {
            current_image_path := full_path
            return full_path
        }
    }

    if (allow_cached_path && current_image_path != "" && FileExist(current_image_path))
    {
        return current_image_path
    }

    return ""
}


/*  GET IMAGE PATH FROM ALL IRFANVIEW WINDOWS OF ONE PROCESS
 */
getImagePathFromIrfanViewProcess(process_id)
{
    if (!process_id)
    {
        return ""
    }

    WinGet, window_list, List, ahk_pid %process_id%

    Loop, %window_list%
    {
        window_id := window_list%A_Index%
        WinGetClass, window_class, ahk_id %window_id%

        if (window_class != "IrfanView")
        {
            continue
        }

        WinGetTitle, window_title, ahk_id %window_id%
        full_path := parseExistingPathFromIrfanViewTitle(window_title)

        if (full_path != "")
        {
            return full_path
        }
    }

    return ""
}


/*  GET IMAGE PATH FROM ALL WINDOWS OF ONE IRFANVIEW EXECUTABLE
 */
getImagePathFromIrfanViewExecutable(executable_name)
{
    WinGet, window_list, List, ahk_exe %executable_name%

    Loop, %window_list%
    {
        window_id := window_list%A_Index%
        WinGetTitle, window_title, ahk_id %window_id%
        full_path := parseExistingPathFromIrfanViewTitle(window_title)

        if (full_path != "")
        {
            return full_path
        }
    }

    return ""
}


/*  PARSE AN EXISTING FILE PATH FROM AN IRFANVIEW TITLE
 */
parseExistingPathFromIrfanViewTitle(window_title)
{
    path_part := Trim(window_title, " `t`r`n")

    if (path_part = "")
    {
        return ""
    }

    path_part := RegExReplace(path_part, "i)\s+-\s+IrfanView.*$")
    path_part := RegExReplace(path_part, "^\s*\d+\s*/\s*\d+\s*-\s*")
    path_part := Trim(path_part, " `t`r`n" . Chr(34))

    if FileExist(path_part)
    {
        return path_part
    }

    return ""
}


/*  TEST PATH PARSING WITHOUT REQUIRING IRFANVIEW
 */
testPathParser()
{
    test_root := A_Temp . "\slideshow_assistant_path_test_" . A_TickCount
    FileCreateDir, %test_root%
    test_path := test_root . "\sample.jpg"
    FileAppend,, %test_path%

    test_title_a := test_path . " - IrfanView"
    test_title_b := "1/10 - " . test_path . " - IrfanView 64"

    result_a := parseExistingPathFromIrfanViewTitle(test_title_a)
    result_b := parseExistingPathFromIrfanViewTitle(test_title_b)

    moveFileToSubdirectory(test_path, "_DELETE")

    return (result_a != "" && result_b != "")
}


/*  CHECK WHETHER A MODIFIER KEY WAS TAPPED WITHOUT ANOTHER KEY
    Modifier combinations remain available because only an unmodified tap is handled.
 */
shouldHandleStandaloneModifier(modifier_key, prior_key)
{
    return (modifier_key = prior_key)
}


/*  TEST STANDALONE MODIFIER DETECTION
    Confirms Ctrl and Shift taps are accepted while modifier combinations are rejected.
 */
testStandaloneModifierDetection()
{
    return (shouldHandleStandaloneModifier("LControl", "LControl")
        && shouldHandleStandaloneModifier("RControl", "RControl")
        && shouldHandleStandaloneModifier("LShift", "LShift")
        && shouldHandleStandaloneModifier("RShift", "RShift")
        && !shouldHandleStandaloneModifier("LControl", "b")
        && !shouldHandleStandaloneModifier("RControl", "Tab")
        && !shouldHandleStandaloneModifier("LShift", "Space")
        && !shouldHandleStandaloneModifier("RShift", "f"))
}


/*==============================================================================
	HOTEKYS
================================================================================
*/


#If isMainIrfanViewWindowActive()


/*  ALT+TAB IS NOT REGISTERED BY THIS SCRIPT
    Windows handles Alt+Tab and Alt+Shift+Tab natively.
 */


/*  PASS THE DISPLAY-SWITCH SHORTCUT DIRECTLY TO WINDOWS OR DISPLAYFUSION
    The script does not move or rebind the IrfanView window after this shortcut.
 */
~^!#x::
    resetSlideTimer()
return



/*  COPY CURRENT IMAGE AS PARENT FOLDER.JPG
    Ctrl+Shift+F is fully intercepted so IrfanView cannot set the image as wallpaper.
 */
$^+f::
    Critical, On
    copyCurrentImageAsFolderJpg()
    Critical, Off
    resetSlideTimer()
    KeyWait, f
return


/*  MANUAL SLIDESHOW NAVIGATION
    Suppress Space so the pending fullscreen crop is captured before navigation.
 */
$*Space::
    if GetKeyState("Shift", "P")
    {
        pauseSlideShow()
        markCropCapturePending()
        KeyWait, Space
        return
    }

    learnCurrentImageTime()

    if !savePendingImageChangesBeforeNavigation()
    {
        resetSlideTimer()
        return
    }

    resetSlideTimer()
    main_window_id := getActiveMainIrfanViewWindow()

    if sendKeysToMainIrfanView("{Space}", main_window_id)
    {
        SetTimer, DelayedLoadLearnedTime, -50
    }
    KeyWait, Space
return


/*  PREVIOUS IMAGE NAVIGATION
 */
$*Backspace::
    learnCurrentImageTime()

    if !savePendingImageChangesBeforeNavigation()
    {
        resetSlideTimer()
        return
    }

    main_window_id := getActiveMainIrfanViewWindow()
    send_succeeded := sendKeysToMainIrfanView("{Backspace}", main_window_id)
    resetSlideTimer()

    if (send_succeeded)
    {
        SetTimer, DelayedLoadLearnedTime, -50
    }
return


/*  CTRL TAP WORKS AS PREVIOUS IMAGE
    Ctrl combinations remain available because navigation runs only after Ctrl was tapped alone.
 */
~*LControl Up::
    if !shouldHandleStandaloneModifier("LControl", A_PriorKey)
    {
        return
    }

    learnCurrentImageTime()

    if !savePendingImageChangesBeforeNavigation()
    {
        resetSlideTimer()
        return
    }

    main_window_id := getActiveMainIrfanViewWindow()
    send_succeeded := sendKeysToMainIrfanView("{Backspace}", main_window_id)

    if (current_image_path != "")
    {
        delete_move_queue[current_image_path] := false
    }

    resetSlideTimer()

    if (send_succeeded)
    {
        SetTimer, DelayedLoadLearnedTime, -50
    }
return


~*RControl Up::
    if !shouldHandleStandaloneModifier("RControl", A_PriorKey)
    {
        return
    }

    learnCurrentImageTime()

    if !savePendingImageChangesBeforeNavigation()
    {
        resetSlideTimer()
        return
    }

    main_window_id := getActiveMainIrfanViewWindow()
    send_succeeded := sendKeysToMainIrfanView("{Backspace}", main_window_id)

    if (current_image_path != "")
    {
        delete_move_queue[current_image_path] := false
    }

    resetSlideTimer()

    if (send_succeeded)
    {
        SetTimer, DelayedLoadLearnedTime, -50
    }
return


/*  SHIFT TAP ADDS ONE PAUSE STEP
    Shift combinations remain available because pause runs only after Shift was tapped alone.
 */
~*LShift Up::
    if shouldHandleStandaloneModifier("LShift", A_PriorKey)
    {
        pauseSlideShowAdd()
    }
return


~*RShift Up::
    if shouldHandleStandaloneModifier("RShift", A_PriorKey)
    {
        pauseSlideShowAdd()
    }
return


/*  MOVE CURRENT IMAGE TO _DELETE AFTER SAVING ONE PENDING FULLSCREEN CROP
 */
*Del::
    learnCurrentImageTime()

    if !savePendingImageChangesBeforeNavigation()
    {
        resetSlideTimer()
        return
    }

    if (current_image_path != "")
    {
        delete_move_queue[current_image_path] := true
    }

    main_window_id := getActiveMainIrfanViewWindow()
    send_succeeded := sendKeysToMainIrfanView("{Space}", main_window_id)
    resetSlideTimer()

    if (send_succeeded)
    {
        SetTimer, DelayedLoadLearnedTime, -50
    }
return


/*  NATIVE PAN AND ZOOM KEYS MARK THE VIEW AS CROPPED
 */
~NumpadAdd::
~NumpadSub::
~*NumpadUp::
~*NumpadDown::
~*NumpadLeft::
~*NumpadRight::
~*Up::
~*Down::
~*Left::
~*Right::
    pauseSlideShow()
    markCropCapturePending()
return


/*  TRACK AND PERSIST NATIVE IRFANVIEW TRANSFORMS WITHOUT SAVE AS
    L, R and H still pass to IrfanView; the same transform is written before navigation or script exit.
 */
~l::
    pauseSlideShow()
    queuePendingImageTransform("l")
return


~r::
    pauseSlideShow()
    queuePendingImageTransform("r")
return


~h::
    pauseSlideShow()
    queuePendingImageTransform("h")
return


/*  EASY PAN CONTROLS USING NORMAL FOREGROUND ARROW PRESSES
    WASD targets the active normal or fullscreen viewer and never IrfanView dialogs.
 */
$a::
    if sendWasdArrowToActiveIrfanView("a")
    {
        pauseSlideShow()
        markCropCapturePending()
    }
return


$d::
    if sendWasdArrowToActiveIrfanView("d")
    {
        pauseSlideShow()
        markCropCapturePending()
    }
return


$w::
    if sendWasdArrowToActiveIrfanView("w")
    {
        pauseSlideShow()
        markCropCapturePending()
    }
return


$s::
    if sendWasdArrowToActiveIrfanView("s")
    {
        pauseSlideShow()
        markCropCapturePending()
    }
return


/*  EASY ZOOM CONTROLS
 */
*q::
    main_window_id := getActiveMainIrfanViewWindow()
    sendKeysToMainIrfanView("{NumpadAdd}", main_window_id)
    pauseSlideShow()
    markCropCapturePending()
return


*e::
    main_window_id := getActiveMainIrfanViewWindow()
    sendKeysToMainIrfanView("{NumpadSub}", main_window_id)
    pauseSlideShow()
    markCropCapturePending()
return


/*  TEST THAT EXIT IS REQUESTED THROUGH EXITAPP, NOT BY GOSUB
    The OnExit label must run only as an actual exit callback.
 */
testExitFlowIsolation()
{
    FileRead, script_source, %A_ScriptFullPath%

    gosub_exit_text := "Gosub" . ", handleExit"

    return (!InStr(script_source, gosub_exit_text)
        && InStr(script_source, "OnExit, handleExit")
        && InStr(script_source, "handleExit:"))
}


/*==============================================================================
	LABELS
================================================================================
*/

RemoveToolTip:
    ToolTip
return


/*  APPLY DELAYED RENAMES AND PROTECTIVE MOVES ON ACTUAL SCRIPT EXIT
    ExitApp at the end is required by AutoHotkey v1 for an OnExit label.
 */
handleExit:

    if (exit_work_started)
    {
        return
    }

    exit_work_started := true
    SetTimer, CheckIrfanView, Off
    SetTimer, DelayedLoadLearnedTime, Off

    savePendingImageTransforms()

    for delete_path, value in delete_move_queue
    {
        if value
        {
            if FileExist(delete_path)
            {
                moveFileToSubdirectory(delete_path, "_DELETE")
            }
        }
    }

    for old_path, new_path in learned_rename_map
    {
        if FileExist(old_path)
        {
            if (old_path != new_path)
            {
                safe_new_path := getUniqueFilePath(new_path)
                FileMove, %old_path%, %safe_new_path%, 0
            }
        }
    }

    /* AutoHotkey v1 OnExit labels must explicitly terminate the persistent script. */
    ExitApp
return


#If