#NoEnv
#Persistent
#SingleInstance Off
SetBatchLines, -1
ListLines, Off
SendMode, Input
SetWorkingDir, %A_ScriptDir%

; Gallery-Slideshow-Manager.ahk
; AutoHotkey v1.1.36 script.
; Built from the stable 0.13 media and worker logic plus the proven UI-only window.
; Registers only Tab and Ctrl+Tab while IrfanView or VLC is active for gallery navigation.
; Sends one native Enter key after each IrfanView launch to enter fullscreen.
; Keeps the manager UI open and can open the current gallery parent in Explorer.
; Remembers the manager window and IrfanView on independent displays.
; Opens VLC even when no VLC instance is currently running.
; Puts the new VLC window in fullscreen, then returns focus to IrfanView.
; Adds a Random Slideshow action that chooses a random parent and gallery.
; Stores parent-gallery keywords in gallery-keywords.ini inside the selected root.
; Removes unused keywords and previews parent or gallery images with keyword labels.
; Colors gallery rows by exact video pairing and starts parent or gallery rows on double-click.
; Keeps all dynamic keyword controls attached to the main manager GUI.
; Browses to and selects the current parent row whenever a slideshow starts.
; Sorts keywords alphabetically and applies each new keyword to the selected parent.
; Intercepts Escape and confirms before exiting the manager.
; Uses Gallery-Slideshow-Manager.ico for the tray and manager window.
; Stores settings in Gallery-Slideshow-Manager.ini and migrates the legacy INI.

SCRIPT_VERSION := "0.40"

; =====================================================================
; USER SETTINGS
; =====================================================================

ROOT_FOLDER := ""
IRFANVIEW_EXE := ""
SCRIPT_BASE_NAME := RegExReplace(A_ScriptName, "\.[^.]+$")
SETTINGS_INI := A_ScriptDir . "\" . SCRIPT_BASE_NAME . ".ini"
LEGACY_SETTINGS_INI := A_ScriptDir . "\random-main-folder-irfanview.ini"
SCRIPT_ICON := A_ScriptDir . "\" . SCRIPT_BASE_NAME . ".ico"
IRFANVIEW_ARGUMENTS := ""
IMAGE_EXTENSIONS := "jpg,jpeg,png,gif,bmp,tif,tiff,webp,heic,jfif"
LIST_ENCODING := "CP0"
EXCLUDED_FOLDER_NAMES := "_DELETE|_CROP|_DUPLICATES|_SMALL"
AUTO_VLC_ENABLED := true
KEYWORDS_INI_FILENAME := "gallery-keywords.ini"

; =====================================================================
; INTERNAL STATE
; =====================================================================

WORK_DIR := ""
CURRENT_PREFIX := ""
NEXT_GALLERY_PREFIX := ""
NEXT_PARENT_PREFIX := ""
MAIN_PID_FILE := ""

gallery_worker_pid := ""
parent_worker_pid := ""
current_irfan_pid := ""
current_parent := ""
current_gallery := ""
current_count := 0
current_video := ""
pending_action := ""
switching_slideshow := false
irfanview_was_launched := false
script_is_exiting := false

main_gui_hwnd := ""
gallery_tree_paths := {}
gallery_tree_types := {}
gallery_tree_has_video := {}
gallery_tree_count := 0
selected_gallery_path := ""
GalleryTreeHwnd := ""

KEYWORDS_INI := ""
keyword_list := []
active_keyword_filters := {}
keyword_filter_controls := []
keyword_filter_generation := 0
keyword_filter_rows := 1
gallery_tree_top := 150
keyword_context_parent := ""
keyword_context_menu_items := []

preview_parent_folder := ""
preview_image_path := ""
preview_canvas_x := 0
preview_canvas_y := 0
preview_canvas_width := 0
preview_canvas_height := 0

if (A_Args.Length() >= 1)
{
    first_arg := A_Args[1]

    if (first_arg = "--worker")
    {
        worker_mode := A_Args[2]
        worker_root := A_Args[3]
        worker_prefix := A_Args[4]
        worker_parent := A_Args[5]
        worker_gallery := A_Args[6]
        worker_extensions := A_Args[7]
        worker_encoding := A_Args[8]
        worker_excluded_names := A_Args[9]

        workerBuildSelection(worker_mode, worker_root, worker_prefix, worker_parent, worker_gallery, worker_extensions, worker_encoding, worker_excluded_names)
        ExitApp
    }
    else if (first_arg = "--self-test")
    {
        runSelfTest()
        ExitApp
    }
    else if (first_arg = "--test-keywords")
    {
        ROOT_FOLDER := A_Args.Length() >= 2 ? A_Args[2] : ""
        test_parent_folder := A_Args.Length() >= 3 ? A_Args[3] : ""
        loadKeywordConfiguration()
        showKeywordConfigurationTest(test_parent_folder)
        ExitApp
    }
    else if (first_arg = "--test-navigation-context")
    {
        testGalleryNavigationContext()
        ExitApp
    }
    else if (first_arg = "--test-random-parent")
    {
        test_root_folder := A_Args.Length() >= 2 ? A_Args[2] : ""
        test_parent_folder := ""
        test_gallery_folder := ""

        if (getRandomParentGallerySelection(test_root_folder, "", test_parent_folder, test_gallery_folder))
        {
            test_message := "Random parent:`n" . test_parent_folder
            test_message .= "`n`nRandom gallery:`n" . test_gallery_folder
            MsgBox, 64, Random Slideshow Test, %test_message%
        }
        else
        {
            MsgBox, 16, Random Slideshow Test, % "No valid gallery was found under:`n`n" . test_root_folder
        }

        ExitApp
    }
    else if (first_arg = "--test-irfan-fullscreen")
    {
        test_image_file := A_Args.Length() >= 2 ? A_Args[2] : ""
        testIrfanViewFullscreen(test_image_file)
        ExitApp
    }
    else if (first_arg = "--test-window-memory")
    {
        showWindowMemoryTest()
        ExitApp
    }
    else if (first_arg = "--test-open-folder")
    {
        test_folder_path := A_Args.Length() >= 2 ? A_Args[2] : ""

        if (openFolderInExplorer(test_folder_path))
        {
            MsgBox, 64, Explorer Folder Test, % "Opened folder:`n`n" . test_folder_path
        }
        else
        {
            MsgBox, 16, Explorer Folder Test, % "Could not open folder:`n`n" . test_folder_path
        }

        ExitApp
    }
    else if (first_arg = "--test-vlc-video")
    {
        test_video_file := A_Args.Length() >= 2 ? A_Args[2] : ""

        if (test_video_file = "" || !FileExist(test_video_file))
        {
            MsgBox, 16, VLC Video Test, % "Video file does not exist:`n`n" . test_video_file
            ExitApp
        }

        if (sendPairedVideoToVlc(test_video_file))
        {
            MsgBox, 64, VLC Video Test, The video was opened and VLC was switched to fullscreen.
        }
        else
        {
            MsgBox, 16, VLC Video Test, VLC could not open the video.
        }

        ExitApp
    }
    else
    {
        ROOT_FOLDER := first_arg
    }
}

migrateLegacySettingsIni()
initializeManager()
loadKeywordConfiguration()

; =====================================================================
; PROVEN UI SHELL
; =====================================================================

Gui, New, +Resize +MinSize850x650 +Hwndmain_gui_hwnd
applyManagerWindowIcon(main_gui_hwnd)
Gui, Margin, 18, 16
Gui, Color, 181818, 242424
Gui, Font, s10 cF0F0F0, Segoe UI

Gui, Add, Text, x18 y18 w500 h22, Galleries root
Gui, Add, Edit, x18 y44 w610 h28 vGalleriesRootEdit cF0F0F0 Background242424, %ROOT_FOLDER%
Gui, Add, Button, x640 y43 w100 h30 vBrowseButton gBrowseButtonPressed, Browse
Gui, Add, Button, x750 y43 w90 h30 vSaveButton gSaveButtonPressed, Save

Gui, Add, Text, x18 y84 w90 h22, New keyword
Gui, Add, Edit, x112 y79 w245 h28 vNewKeywordEdit cF0F0F0 Background242424
Gui, Add, Button, x367 y78 w90 h30 vAddKeywordButton gAddKeywordButtonPressed, Add keyword
Gui, Add, Button, x467 y78 w115 h30 vClearKeywordsButton gClearKeywordsButtonPressed, Clear keywords

Gui, Add, Text, x18 y118 w60 h22, Filter
Gui, Add, Text, x82 y118 w300 h22 vKeywordFilterEmptyText c888888, No keywords defined.
rebuildKeywordFilterControls(false)

initial_tree_height := 496 - gallery_tree_top
initial_content_width := 822
initial_panel_gap := 14
initial_tree_width := Floor((initial_content_width - initial_panel_gap) / 2)
initial_preview_x := 18 + initial_tree_width + initial_panel_gap
initial_preview_width := initial_content_width - initial_panel_gap - initial_tree_width

tree_options := "x18 y" . gallery_tree_top . " w" . initial_tree_width . " h" . initial_tree_height
tree_options .= " vGalleryTree hwndGalleryTreeHwnd gGalleryTreeEvent cF0F0F0 Background202020 +Buttons +Lines +HScroll"
Gui, Add, TreeView, %tree_options%
OnMessage(0x4E, "handleTreeViewCustomDraw")

Gui, Font, s10 Bold cF0F0F0, Segoe UI
Gui, Add, Text, % "x" initial_preview_x " y" gallery_tree_top " w" initial_preview_width " h22 vParentPreviewTitle", No selection
Gui, Font, s9 Norm cB8B8B8, Segoe UI
Gui, Add, Text, % "x" initial_preview_x " y" (gallery_tree_top + 24) " w" initial_preview_width " h22 vParentPreviewKeywords",
Gui, Font, s10 Norm cF0F0F0, Segoe UI

initial_preview_canvas_y := gallery_tree_top + 50
initial_preview_canvas_height := initial_tree_height - 50
preview_canvas_options := "x" . initial_preview_x . " y" . initial_preview_canvas_y
preview_canvas_options .= " w" . initial_preview_width . " h" . initial_preview_canvas_height
preview_canvas_options .= " vParentPreviewCanvas Background202020 +Border"
Gui, Add, Text, %preview_canvas_options%

preview_placeholder_x := initial_preview_x + 14
preview_placeholder_y := initial_preview_canvas_y + 14
preview_placeholder_width := initial_preview_width - 28
preview_placeholder_height := initial_preview_canvas_height - 28
preview_placeholder_options := "x" . preview_placeholder_x . " y" . preview_placeholder_y
preview_placeholder_options .= " w" . preview_placeholder_width . " h" . preview_placeholder_height
preview_placeholder_options .= " vParentPreviewPlaceholder Center +0x200 c888888 Background202020"
Gui, Add, Text, %preview_placeholder_options%, Select a parent or gallery.

Gui, Add, Picture, x0 y0 w1 h1 vParentPreviewPicture Hidden

checkbox_options := "x18 y512 w270 h26 vAutoVlcEnabled gAutoVlcChanged cF0F0F0"
if (AUTO_VLC_ENABLED)
{
    checkbox_options .= " Checked"
}

Gui, Add, Checkbox, %checkbox_options%, Open paired video in VLC automatically
Gui, Add, Button, x587 y496 w125 h34 vOpenParentButton gOpenParentButtonPressed Disabled, Open parent folder
Gui, Add, Button, x722 y496 w110 h34 vRefreshButton gRefreshButtonPressed, Refresh tree
Gui, Add, Button, x587 y536 w125 h34 vRandomStartButton gRandomStartButtonPressed Disabled, Random Slideshow
Gui, Add, Button, x722 y536 w128 h34 vStartButton gStartButtonPressed Default, Start slideshow

Gui, Font, s9 cB8B8B8, Segoe UI
Gui, Add, Text, x18 y584 w822 h42 vManagerStatusText, Select or browse the galleries root folder.

manager_show_options := getManagerWindowShowOptions()
Gui, Show, %manager_show_options%, % "Gallery Slideshow Manager " . SCRIPT_VERSION
restoreManagerWindowState(main_gui_hwnd)

if (getManagerClientSize(initial_client_width, initial_client_height))
{
    layoutManagerControls(initial_client_width, initial_client_height)
}

WinActivate, ahk_id %main_gui_hwnd%
SetTimer, initialTreeLoadTimer, -50
return

; =====================================================================
; IRFANVIEW AND VLC NAVIGATION HOTKEYS
; =====================================================================

#If isGalleryNavigationActive()
$Tab::
    requestSwitch("gallery")
    KeyWait, Tab
return

$^Tab::
    requestSwitch("parent")
    KeyWait, Tab
return
#If

#If isIrfanViewWindowActive()
$Esc::
    KeyWait, Esc
    confirmExitSlideshowManager()
return
#If

; =====================================================================
; GUI, TIMER, AND TRAY LABELS
; =====================================================================

initialTreeLoadTimer:
    SetTimer, initialTreeLoadTimer, Off
    setManagerGuiDefault()
    refreshTreeOnInitialization()
return

parentPreviewResizeTimer:
    SetTimer, parentPreviewResizeTimer, Off
    setManagerGuiDefault()
    renderParentPreviewImage()
return

pendingSwitchTimer:
    if (pending_action = "")
    {
        SetTimer, pendingSwitchTimer, Off
        return
    }

    requested_prefix := getPrefixForAction(pending_action)

    if (slotHasError(requested_prefix))
    {
        failed_action := pending_action
        pending_action := ""
        SetTimer, pendingSwitchTimer, Off
        restartWorkerForAction(failed_action)
        return
    }

    if (slotIsReady(requested_prefix))
    {
        requested_action := pending_action
        pending_action := ""
        SetTimer, pendingSwitchTimer, Off
        switchUsingPreparedSlot(requested_action)
    }
return

monitorIrfanViewProcess:
    if (script_is_exiting || switching_slideshow || !irfanview_was_launched)
    {
        return
    }

    if (current_irfan_pid = "" || !processExists(current_irfan_pid))
    {
        ExitApp
    }
return

showManager:
    Gui, Show
    WinRestore, ahk_id %main_gui_hwnd%
    WinActivate, ahk_id %main_gui_hwnd%
return

BrowseButtonPressed:
    GuiControlGet, current_root_text,, GalleriesRootEdit
    current_root_text := normalizeFolderPath(current_root_text)

    if (current_root_text != "" && FileExist(current_root_text))
    {
        initial_folder := "*" . current_root_text
    }
    else
    {
        initial_folder := "*" . A_ScriptDir
    }

    FileSelectFolder, selected_root_folder, %initial_folder%, 3, Select galleries root folder

    if (ErrorLevel || selected_root_folder = "")
    {
        return
    }

    selected_root_folder := normalizeFolderPath(selected_root_folder)
    GuiControl,, GalleriesRootEdit, %selected_root_folder%
    saveGalleriesRootFromGui()
return

SaveButtonPressed:
    saveGalleriesRootFromGui()
return

RefreshButtonPressed:
    GuiControlGet, root_folder_text,, GalleriesRootEdit
    root_folder_text := normalizeFolderPath(root_folder_text)

    if (root_folder_text = "" || !FileExist(root_folder_text))
    {
        MsgBox, 48, Gallery Manager, Select an existing galleries root folder first.
        return
    }

    ROOT_FOLDER := root_folder_text
    loadKeywordConfiguration()
    rebuildKeywordFilterControls()
    populateGalleryTree(ROOT_FOLDER)
return

AddKeywordButtonPressed:
    addKeywordFromGui()
return

ClearKeywordsButtonPressed:
    clearUnusedKeywordsFromGui()
return

KeywordFilterChanged:
    updateActiveKeywordFiltersFromControls()
    populateGalleryTree(ROOT_FOLDER)
return

ParentKeywordMenuSelected:
    handleParentKeywordMenuSelection(A_ThisMenuItemPos)
return

GalleryTreeEvent:
    if (A_GuiEvent = "S" || A_GuiEvent = "Normal")
    {
        updateSelectedGalleryFromTree()
    }
    else if (A_GuiEvent = "DoubleClick" && A_EventInfo)
    {
        startGalleryFromDoubleClick(A_EventInfo)
    }
return

/* TreeView right-clicks are delivered through GuiContextMenu in AHK v1.
   A_EventInfo contains the clicked TreeView item ID.
*/
GuiContextMenu:
    if (A_GuiControl = "GalleryTree" && A_EventInfo)
    {
        showParentKeywordContextMenu(A_EventInfo, A_GuiX, A_GuiY)
    }
return

AutoVlcChanged:
    Gui, Submit, NoHide
    AUTO_VLC_ENABLED := AutoVlcEnabled ? true : false
    IniWrite, % (AUTO_VLC_ENABLED ? 1 : 0), %SETTINGS_INI%, Options, AutoVlc
return

OpenParentButtonPressed:
    openCurrentParentFolder()
return

RandomStartButtonPressed:
    startRandomParentGallery()
return

StartButtonPressed:
    selected_item_id := TV_GetSelection()
    selected_gallery := resolveGalleryFromTreeItem(selected_item_id)

    if (selected_gallery = "")
    {
        MsgBox, 48, Gallery Manager, Select a gallery in the tree first.
        return
    }

    startGalleryFromPath(selected_gallery)
return

trayNextGallery:
    requestSwitch("gallery")
return

trayNextParent:
    requestSwitch("parent")
return

traySelfTest:
    runSelfTest()
return

trayExit:
    confirmExitSlideshowManager()
return

GuiSize:
    if (A_EventInfo = 1)
    {
        return
    }

    layoutManagerControls(A_GuiWidth, A_GuiHeight)
return

GuiEscape:
    confirmExitSlideshowManager()
return

GuiClose:
    confirmExitSlideshowManager()
return

handleScriptExit:
    script_is_exiting := true
    SetTimer, monitorIrfanViewProcess, Off
    SetTimer, pendingSwitchTimer, Off

    saveManagerWindowPlacement()
    closeCurrentIrfanView()
    stopWorker(gallery_worker_pid)
    stopWorker(parent_worker_pid)

    if (MAIN_PID_FILE != "")
    {
        FileDelete, %MAIN_PID_FILE%
    }
ExitApp


; =====================================================================
; MAIN CONTROLLER FUNCTIONS
; =====================================================================

/* Initialize the gallery manager.
   Loads saved settings but does not scan images or start IrfanView.
*/
initializeManager()
{
    global ROOT_FOLDER, WORK_DIR, CURRENT_PREFIX, NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX
    global MAIN_PID_FILE, IRFANVIEW_EXE

    WORK_DIR := A_Temp . "\random-main-folder-irfanview"
    CURRENT_PREFIX := WORK_DIR . "\current"
    NEXT_GALLERY_PREFIX := WORK_DIR . "\next-gallery"
    NEXT_PARENT_PREFIX := WORK_DIR . "\next-parent"
    MAIN_PID_FILE := WORK_DIR . "\main.pid"

    FileCreateDir, %WORK_DIR%
    enforceSingleMainInstance()
    OnExit, handleScriptExit
    setupTrayMenu()
    loadManagerSettings()

    IRFANVIEW_EXE := readSavedIrfanViewPath()

    cleanupSlot(CURRENT_PREFIX)
    cleanupSlot(NEXT_GALLERY_PREFIX)
    cleanupSlot(NEXT_PARENT_PREFIX)
}

/* Rename the legacy settings INI to match the permanent script filename.
   Existing new-format settings take priority and are never overwritten.
*/
migrateLegacySettingsIni()
{
    global SETTINGS_INI, LEGACY_SETTINGS_INI

    if (FileExist(SETTINGS_INI) || !FileExist(LEGACY_SETTINGS_INI))
    {
        return true
    }

    FileMove, %LEGACY_SETTINGS_INI%, %SETTINGS_INI%, 0

    if (!ErrorLevel && FileExist(SETTINGS_INI))
    {
        return true
    }

    ; A copy fallback preserves settings when the old file is temporarily locked.
    FileCopy, %LEGACY_SETTINGS_INI%, %SETTINGS_INI%, 0
    return !ErrorLevel && FileExist(SETTINGS_INI)
}

/* Apply the same ICO to the manager window's small and large title icons.
   The tray icon is configured separately in setupTrayMenu().
*/
applyManagerWindowIcon(manager_window_id)
{
    global SCRIPT_ICON

    if (manager_window_id = "" || !FileExist(SCRIPT_ICON))
    {
        return false
    }

    small_icon_handle := DllCall("LoadImage", "Ptr", 0, "Str", SCRIPT_ICON, "UInt", 1, "Int", 16, "Int", 16, "UInt", 0x10, "Ptr")
    large_icon_handle := DllCall("LoadImage", "Ptr", 0, "Str", SCRIPT_ICON, "UInt", 1, "Int", 32, "Int", 32, "UInt", 0x10, "Ptr")

    if (small_icon_handle)
    {
        SendMessage, 0x80, 0, %small_icon_handle%,, ahk_id %manager_window_id%
    }

    if (large_icon_handle)
    {
        SendMessage, 0x80, 1, %large_icon_handle%,, ahk_id %manager_window_id%
    }

    return small_icon_handle || large_icon_handle
}

/* Enforce one active controller instance.
   Worker instances remain independent and are not blocked.
*/
enforceSingleMainInstance()
{
    global MAIN_PID_FILE

    current_pid := DllCall("GetCurrentProcessId")

    if (FileExist(MAIN_PID_FILE))
    {
        FileRead, old_pid_text, %MAIN_PID_FILE%
        old_pid := Trim(old_pid_text)

        if (old_pid != "" && old_pid != current_pid && processExists(old_pid))
        {
            Process, Close, %old_pid%
            Process, WaitClose, %old_pid%, 2
        }
    }

    FileDelete, %MAIN_PID_FILE%
    FileAppend, %current_pid%, %MAIN_PID_FILE%
}

/* Configure the tray menu.
   Exposes the manager and prepared navigation without keyboard hooks.
*/
setupTrayMenu()
{
    global SCRIPT_VERSION, SCRIPT_ICON

    Menu, Tray, NoStandard

    if (FileExist(SCRIPT_ICON))
    {
        Menu, Tray, Icon, %SCRIPT_ICON%, 1, 1
    }
    Menu, Tray, Tip, % "Gallery Slideshow Manager " . SCRIPT_VERSION
    Menu, Tray, Add, Show manager, showManager
    Menu, Tray, Add
    Menu, Tray, Add, Next gallery, trayNextGallery
    Menu, Tray, Add, Next parent, trayNextParent
    Menu, Tray, Add
    Menu, Tray, Add, Self test, traySelfTest
    Menu, Tray, Add, Exit, trayExit
    Menu, Tray, Default, Show manager
}

/* Start both background preparations.
   One worker prepares the next sibling gallery and one prepares the next parent.
*/
startBothWorkers()
{
    global NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX, current_parent, current_gallery

    startWorker("gallery", NEXT_GALLERY_PREFIX, current_parent, current_gallery)
    startWorker("parent", NEXT_PARENT_PREFIX, current_parent, current_gallery)
}

/* Start one worker process.
   The worker writes a list, metadata, and a ready marker for its slot.
*/
startWorker(worker_mode, slot_prefix, base_parent, base_gallery)
{
    global ROOT_FOLDER, IMAGE_EXTENSIONS, LIST_ENCODING, EXCLUDED_FOLDER_NAMES
    global gallery_worker_pid, parent_worker_pid

    if (worker_mode = "gallery")
    {
        stopWorker(gallery_worker_pid)
    }
    else
    {
        stopWorker(parent_worker_pid)
    }

    cleanupSlot(slot_prefix)

    if (A_IsCompiled)
    {
        command_line := quotePath(A_ScriptFullPath)
    }
    else
    {
        command_line := quotePath(A_AhkPath) . " " . quotePath(A_ScriptFullPath)
    }

    command_line .= " --worker " . quotePath(worker_mode)
    command_line .= " " . quotePath(ROOT_FOLDER)
    command_line .= " " . quotePath(slot_prefix)
    command_line .= " " . quotePath(base_parent)
    command_line .= " " . quotePath(base_gallery)
    command_line .= " " . quotePath(IMAGE_EXTENSIONS)
    command_line .= " " . quotePath(LIST_ENCODING)
    command_line .= " " . quotePath(EXCLUDED_FOLDER_NAMES)

    Run, %command_line%,, Hide UseErrorLevel, new_worker_pid

    if (worker_mode = "gallery")
    {
        gallery_worker_pid := new_worker_pid
    }
    else
    {
        parent_worker_pid := new_worker_pid
    }
}

/* Stop one background worker.
   Accepts the process id by reference so the stored id is cleared.
*/
stopWorker(ByRef worker_process_id)
{
    if (worker_process_id != "" && processExists(worker_process_id))
    {
        Process, Close, %worker_process_id%
        Process, WaitClose, %worker_process_id%, 1
    }

    worker_process_id := ""
}

/* Handle Tab or Ctrl+Tab navigation.
   Opens immediately when ready, otherwise opens automatically after preparation.
*/
requestSwitch(action_name)
{
    global pending_action, current_gallery

    if (current_gallery = "")
    {
        return false
    }

    requested_prefix := getPrefixForAction(action_name)

    if (slotIsReady(requested_prefix))
    {
        switchUsingPreparedSlot(action_name)
        return
    }

    if (slotHasError(requested_prefix))
    {
        restartWorkerForAction(action_name)
    }

    pending_action := action_name
    SetTimer, pendingSwitchTimer, 250

}

/* Open a prepared slot.
   Closes the old IrfanView process, promotes metadata, and starts fresh workers.
*/
switchUsingPreparedSlot(action_name)
{
    global switching_slideshow

    switching_slideshow := true
    selected_prefix := getPrefixForAction(action_name)

    closeCurrentIrfanView()
    promoteSlotToCurrent(selected_prefix)

    if (launchCurrentSlideshow())
    {
        startBothWorkers()
    }

    switching_slideshow := false
}

/* Return the preparation slot for a navigation action.
   Gallery and parent actions use independent list files.
*/
getPrefixForAction(action_name)
{
    global NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX

    if (action_name = "gallery")
    {
        return NEXT_GALLERY_PREFIX
    }

    return NEXT_PARENT_PREFIX
}

/* Restart the worker associated with an action.
   Uses the current parent and current gallery as navigation anchors.
*/
restartWorkerForAction(action_name)
{
    global NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX, current_parent, current_gallery

    if (action_name = "gallery")
    {
        startWorker("gallery", NEXT_GALLERY_PREFIX, current_parent, current_gallery)
    }
    else
    {
        startWorker("parent", NEXT_PARENT_PREFIX, current_parent, current_gallery)
    }
}

/* Promote one prepared slot to the current slot.
   IrfanView keeps using the current list while workers rebuild other slots.
*/
promoteSlotToCurrent(source_prefix)
{
    global CURRENT_PREFIX, current_parent, current_gallery, current_count, current_video

    cleanupSlot(CURRENT_PREFIX)

    FileMove, % source_prefix . ".list.txt", % CURRENT_PREFIX . ".list.txt", 1
    FileMove, % source_prefix . ".meta.ini", % CURRENT_PREFIX . ".meta.ini", 1
    FileDelete, % source_prefix . ".ready"
    FileDelete, % source_prefix . ".error.txt"

    current_parent := readMetaValue(CURRENT_PREFIX, "parent")
    current_gallery := readMetaValue(CURRENT_PREFIX, "gallery")
    current_count := readMetaValue(CURRENT_PREFIX, "count")
    current_video := readMetaValue(CURRENT_PREFIX, "video")
}

/* Launch IrfanView with one gallery file list.
   /filelist loads the files without starting IrfanView automatic slideshow playback.
*/
launchCurrentSlideshow()
{
    global CURRENT_PREFIX, IRFANVIEW_EXE, IRFANVIEW_ARGUMENTS, ROOT_FOLDER
    global current_irfan_pid, current_parent, current_gallery, current_count, current_video, irfanview_was_launched
    global AUTO_VLC_ENABLED

    list_path := CURRENT_PREFIX . ".list.txt"

    if (!FileExist(list_path))
    {
        return false
    }

    command_line := buildIrfanViewCommand(IRFANVIEW_EXE, list_path, IRFANVIEW_ARGUMENTS)

    Run, %command_line%, %ROOT_FOLDER%, UseErrorLevel, new_pid
    if (ErrorLevel)
    {
        return false
    }

    current_irfan_pid := new_pid
    enterIrfanViewFullscreen(current_irfan_pid)

    if (AUTO_VLC_ENABLED)
    {
        sendPairedVideoToVlc(current_video)
        activateIrfanViewWindow(current_irfan_pid)
    }

    irfanview_was_launched := true
    SetTimer, monitorIrfanViewProcess, 500

    browseAndSelectParentPathInTree(current_parent)
    setManagerStatus(current_count . " images opened.`n" . current_gallery)
    GuiControl, Enable, OpenParentButton

    showTrayTip("Gallery opened", current_count . " images`n" . current_gallery, 1)
    return true
}

/* Enter fullscreen in the newly launched IrfanView window.
   Waits for the process window, activates it, and sends one native Enter key.
*/
enterIrfanViewFullscreen(irfanview_pid)
{
    if (irfanview_pid = "")
    {
        return false
    }

    irfanview_window_query := "ahk_pid " . irfanview_pid

    WinWait, %irfanview_window_query%,, 5
    if (ErrorLevel)
    {
        return false
    }

    WinGet, irfanview_window_id, ID, %irfanview_window_query%
    if (irfanview_window_id = "")
    {
        return false
    }

    WinRestore, ahk_id %irfanview_window_id%
    restoreIrfanViewWindowPlacement(irfanview_window_id)
    WinActivate, ahk_id %irfanview_window_id%
    WinWaitActive, ahk_id %irfanview_window_id%,, 3

    if (ErrorLevel)
    {
        return false
    }

    Sleep, 250
    SendInput, {Enter}
    return true
}

/* Activate the current IrfanView window without changing its display mode.
   Used after VLC has entered fullscreen so image controls receive focus again.
*/
activateIrfanViewWindow(irfanview_pid)
{
    if (irfanview_pid = "")
    {
        return false
    }

    irfanview_window_query := "ahk_pid " . irfanview_pid

    WinWait, %irfanview_window_query%,, 3
    if (ErrorLevel)
    {
        return false
    }

    WinActivate, %irfanview_window_query%
    WinWaitActive, %irfanview_window_query%,, 3
    return !ErrorLevel
}

/* Test IrfanView fullscreen entry with one image.
   Launches the supplied image and applies the same Enter sequence as a gallery.
*/
testIrfanViewFullscreen(image_file)
{
    global IRFANVIEW_EXE

    if (image_file = "" || !FileExist(image_file))
    {
        MsgBox, 16, IrfanView Fullscreen Test, % "Image file does not exist:`n`n" . image_file
        return false
    }

    IRFANVIEW_EXE := readSavedIrfanViewPath()

    if (IRFANVIEW_EXE = "" || !FileExist(IRFANVIEW_EXE))
    {
        IRFANVIEW_EXE := configureIrfanViewPath()

        if (IRFANVIEW_EXE = "")
        {
            return false
        }
    }

    command_line := quotePath(IRFANVIEW_EXE) . " " . quotePath(image_file)
    Run, %command_line%,, UseErrorLevel, test_irfanview_pid

    if (ErrorLevel)
    {
        MsgBox, 16, IrfanView Fullscreen Test, IrfanView could not be started.
        return false
    }

    if (!enterIrfanViewFullscreen(test_irfanview_pid))
    {
        MsgBox, 16, IrfanView Fullscreen Test, IrfanView opened, but fullscreen activation failed.
        return false
    }

    return true
}

/* Confirm before closing the manager and its current slideshow.
*/
confirmExitSlideshowManager()
{
    MsgBox, 36, Gallery Slideshow Manager, Exit Gallery Slideshow Manager and close the current slideshow?

    IfMsgBox, Yes
    {
        exitSlideshowController()
        return true
    }

    return false
}

/* Exit the controller and current IrfanView slideshow.
   This is called only after an explicit confirmation or internal shutdown.
*/
exitSlideshowController()
{
    global script_is_exiting

    script_is_exiting := true
    closeCurrentIrfanView()
    ExitApp
}

/* Close the IrfanView process owned by this controller.
   Graceful close is attempted before forced termination.
*/
closeCurrentIrfanView()
{
    global current_irfan_pid

    if (current_irfan_pid = "")
    {
        return
    }

    if (processExists(current_irfan_pid))
    {
        current_irfan_window_id := WinExist("ahk_pid " . current_irfan_pid)

        if (current_irfan_window_id != "")
        {
            saveIrfanViewWindowPlacement(current_irfan_window_id)
        }

        WinClose, % "ahk_pid " . current_irfan_pid
        Process, WaitClose, %current_irfan_pid%, 2

        if (processExists(current_irfan_pid))
        {
            Process, Close, %current_irfan_pid%
            Process, WaitClose, %current_irfan_pid%, 1
        }
    }

    current_irfan_pid := ""
}

; =====================================================================
; WINDOW DISPLAY MEMORY FUNCTIONS
; =====================================================================

/* Build the manager GUI show options from the saved normal rectangle.
   Invalid or disconnected-monitor coordinates fall back to a centered window.
*/
getManagerWindowShowOptions()
{
    global SETTINGS_INI

    IniRead, saved_x, %SETTINGS_INI%, ManagerWindow, X,
    IniRead, saved_y, %SETTINGS_INI%, ManagerWindow, Y,
    IniRead, saved_width, %SETTINGS_INI%, ManagerWindow, Width,
    IniRead, saved_height, %SETTINGS_INI%, ManagerWindow, Height,

    if (!isIntegerValue(saved_x)
        || !isIntegerValue(saved_y)
        || !isPositiveIntegerValue(saved_width)
        || !isPositiveIntegerValue(saved_height))
    {
        return "w876 h700 Center"
    }

    if (!doesRectangleTouchAnyMonitor(saved_x, saved_y, saved_width, saved_height))
    {
        return "w876 h700 Center"
    }

    return "x" . saved_x . " y" . saved_y . " w" . saved_width . " h" . saved_height
}

/* Restore the manager maximized state after the normal rectangle is applied.
   Minimized state is intentionally not restored.
*/
restoreManagerWindowState(manager_window_id)
{
    global SETTINGS_INI

    if (manager_window_id = "" || !WinExist("ahk_id " . manager_window_id))
    {
        return false
    }

    IniRead, saved_maximized, %SETTINGS_INI%, ManagerWindow, Maximized, 0

    if (saved_maximized = 1)
    {
        WinMaximize, ahk_id %manager_window_id%
    }
    else
    {
        WinRestore, ahk_id %manager_window_id%
    }

    return true
}

/* Save the manager normal rectangle and maximized state.
   GetWindowPlacement preserves the restore rectangle even when maximized.
*/
saveManagerWindowPlacement()
{
    global main_gui_hwnd, SETTINGS_INI

    if (main_gui_hwnd = "" || !WinExist("ahk_id " . main_gui_hwnd))
    {
        return false
    }

    if (!getWindowPlacementRect(main_gui_hwnd, normal_left, normal_top, normal_right, normal_bottom))
    {
        return false
    }

    normal_width := normal_right - normal_left
    normal_height := normal_bottom - normal_top

    if (normal_width < 320 || normal_height < 240)
    {
        return false
    }

    WinGet, min_max_state, MinMax, ahk_id %main_gui_hwnd%
    manager_maximized := min_max_state = 1 ? 1 : 0

    IniWrite, %normal_left%, %SETTINGS_INI%, ManagerWindow, X
    IniWrite, %normal_top%, %SETTINGS_INI%, ManagerWindow, Y
    IniWrite, %normal_width%, %SETTINGS_INI%, ManagerWindow, Width
    IniWrite, %normal_height%, %SETTINGS_INI%, ManagerWindow, Height
    IniWrite, %manager_maximized%, %SETTINGS_INI%, ManagerWindow, Maximized
    return true
}

/* Save the monitor and relative restored rectangle of the current IrfanView window.
   IrfanView therefore remains independent from the manager GUI display.
*/
saveIrfanViewWindowPlacement(irfanview_window_id)
{
    global SETTINGS_INI

    if (irfanview_window_id = "" || !WinExist("ahk_id " . irfanview_window_id))
    {
        return false
    }

    if (!getMonitorBoundsForWindow(irfanview_window_id, monitor_left, monitor_top, monitor_right, monitor_bottom))
    {
        return false
    }

    if (!getWindowPlacementRect(irfanview_window_id, normal_left, normal_top, normal_right, normal_bottom))
    {
        WinGetPos, normal_left, normal_top, normal_width, normal_height, ahk_id %irfanview_window_id%
        normal_right := normal_left + normal_width
        normal_bottom := normal_top + normal_height
    }

    normal_width := normal_right - normal_left
    normal_height := normal_bottom - normal_top
    relative_x := normal_left - monitor_left
    relative_y := normal_top - monitor_top

    IniWrite, %monitor_left%, %SETTINGS_INI%, IrfanViewWindow, MonitorLeft
    IniWrite, %monitor_top%, %SETTINGS_INI%, IrfanViewWindow, MonitorTop
    IniWrite, %monitor_right%, %SETTINGS_INI%, IrfanViewWindow, MonitorRight
    IniWrite, %monitor_bottom%, %SETTINGS_INI%, IrfanViewWindow, MonitorBottom
    IniWrite, %relative_x%, %SETTINGS_INI%, IrfanViewWindow, RelativeX
    IniWrite, %relative_y%, %SETTINGS_INI%, IrfanViewWindow, RelativeY
    IniWrite, %normal_width%, %SETTINGS_INI%, IrfanViewWindow, Width
    IniWrite, %normal_height%, %SETTINGS_INI%, IrfanViewWindow, Height
    return true
}

/* Restore IrfanView onto its remembered display before fullscreen is entered.
   The closest current monitor is used when display coordinates have changed.
*/
restoreIrfanViewWindowPlacement(irfanview_window_id)
{
    global SETTINGS_INI

    if (irfanview_window_id = "" || !WinExist("ahk_id " . irfanview_window_id))
    {
        return false
    }

    IniRead, saved_monitor_left, %SETTINGS_INI%, IrfanViewWindow, MonitorLeft,
    IniRead, saved_monitor_top, %SETTINGS_INI%, IrfanViewWindow, MonitorTop,
    IniRead, saved_monitor_right, %SETTINGS_INI%, IrfanViewWindow, MonitorRight,
    IniRead, saved_monitor_bottom, %SETTINGS_INI%, IrfanViewWindow, MonitorBottom,

    if (!isIntegerValue(saved_monitor_left)
        || !isIntegerValue(saved_monitor_top)
        || !isIntegerValue(saved_monitor_right)
        || !isIntegerValue(saved_monitor_bottom))
    {
        return false
    }

    if (!findBestCurrentMonitor(saved_monitor_left, saved_monitor_top, saved_monitor_right, saved_monitor_bottom, current_monitor_left, current_monitor_top, current_monitor_right, current_monitor_bottom))
    {
        return false
    }

    IniRead, saved_relative_x, %SETTINGS_INI%, IrfanViewWindow, RelativeX, 80
    IniRead, saved_relative_y, %SETTINGS_INI%, IrfanViewWindow, RelativeY, 80
    IniRead, saved_width, %SETTINGS_INI%, IrfanViewWindow, Width, 1000
    IniRead, saved_height, %SETTINGS_INI%, IrfanViewWindow, Height, 700

    current_monitor_width := current_monitor_right - current_monitor_left
    current_monitor_height := current_monitor_bottom - current_monitor_top

    if (!isIntegerValue(saved_relative_x))
    {
        saved_relative_x := 80
    }

    if (!isIntegerValue(saved_relative_y))
    {
        saved_relative_y := 80
    }

    if (!isPositiveIntegerValue(saved_width))
    {
        saved_width := 1000
    }

    if (!isPositiveIntegerValue(saved_height))
    {
        saved_height := 700
    }

    restored_width := saved_width
    restored_height := saved_height

    if (restored_width > current_monitor_width - 40)
    {
        restored_width := current_monitor_width - 40
    }

    if (restored_height > current_monitor_height - 40)
    {
        restored_height := current_monitor_height - 40
    }

    if (restored_width < 320)
    {
        restored_width := 320
    }

    if (restored_height < 240)
    {
        restored_height := 240
    }

    restored_x := current_monitor_left + saved_relative_x
    restored_y := current_monitor_top + saved_relative_y

    if (restored_x < current_monitor_left)
    {
        restored_x := current_monitor_left
    }

    if (restored_y < current_monitor_top)
    {
        restored_y := current_monitor_top
    }

    if (restored_x + restored_width > current_monitor_right)
    {
        restored_x := current_monitor_right - restored_width
    }

    if (restored_y + restored_height > current_monitor_bottom)
    {
        restored_y := current_monitor_bottom - restored_height
    }

    WinMove, ahk_id %irfanview_window_id%,, %restored_x%, %restored_y%, %restored_width%, %restored_height%
    return true
}

/* Find the current monitor corresponding to saved monitor coordinates.
   Exact bounds are preferred; otherwise the nearest monitor center is used.
*/
findBestCurrentMonitor(saved_left, saved_top, saved_right, saved_bottom, ByRef selected_left, ByRef selected_top, ByRef selected_right, ByRef selected_bottom)
{
    SysGet, monitor_count, MonitorCount

    if (monitor_count < 1)
    {
        return false
    }

    saved_center_x := saved_left + ((saved_right - saved_left) / 2)
    saved_center_y := saved_top + ((saved_bottom - saved_top) / 2)
    best_distance := ""

    Loop, %monitor_count%
    {
        monitor_index := A_Index
        SysGet, monitor_area, Monitor, %monitor_index%

        if (monitor_areaLeft = saved_left
            && monitor_areaTop = saved_top
            && monitor_areaRight = saved_right
            && monitor_areaBottom = saved_bottom)
        {
            selected_left := monitor_areaLeft
            selected_top := monitor_areaTop
            selected_right := monitor_areaRight
            selected_bottom := monitor_areaBottom
            return true
        }

        monitor_center_x := monitor_areaLeft + ((monitor_areaRight - monitor_areaLeft) / 2)
        monitor_center_y := monitor_areaTop + ((monitor_areaBottom - monitor_areaTop) / 2)
        distance_x := monitor_center_x - saved_center_x
        distance_y := monitor_center_y - saved_center_y
        monitor_distance := (distance_x * distance_x) + (distance_y * distance_y)

        if (best_distance = "" || monitor_distance < best_distance)
        {
            best_distance := monitor_distance
            selected_left := monitor_areaLeft
            selected_top := monitor_areaTop
            selected_right := monitor_areaRight
            selected_bottom := monitor_areaBottom
        }
    }

    return best_distance != ""
}

/* Test whether part of a rectangle is visible on any current monitor.
   This prevents restoring the manager completely off-screen.
*/
doesRectangleTouchAnyMonitor(rectangle_x, rectangle_y, rectangle_width, rectangle_height)
{
    rectangle_right := rectangle_x + rectangle_width
    rectangle_bottom := rectangle_y + rectangle_height

    SysGet, monitor_count, MonitorCount

    Loop, %monitor_count%
    {
        monitor_index := A_Index
        SysGet, monitor_area, Monitor, %monitor_index%

        overlap_width := Min(rectangle_right, monitor_areaRight) - Max(rectangle_x, monitor_areaLeft)
        overlap_height := Min(rectangle_bottom, monitor_areaBottom) - Max(rectangle_y, monitor_areaTop)

        if (overlap_width >= 80 && overlap_height >= 80)
        {
            return true
        }
    }

    return false
}

/* Test whether a value is a signed integer.
   INI values are validated before they are used as coordinates.
*/
isIntegerValue(test_value)
{
    return RegExMatch(test_value, "^-?\d+$")
}

/* Test whether a value is a positive integer.
   Window dimensions must be greater than zero.
*/
isPositiveIntegerValue(test_value)
{
    return RegExMatch(test_value, "^\d+$") && test_value > 0
}

/* Display the currently stored manager and IrfanView placement values.
   This command-line diagnostic performs no media operations.
*/
showWindowMemoryTest()
{
    global SETTINGS_INI

    IniRead, manager_x, %SETTINGS_INI%, ManagerWindow, X, not saved
    IniRead, manager_y, %SETTINGS_INI%, ManagerWindow, Y, not saved
    IniRead, manager_width, %SETTINGS_INI%, ManagerWindow, Width, not saved
    IniRead, manager_height, %SETTINGS_INI%, ManagerWindow, Height, not saved
    IniRead, irfan_left, %SETTINGS_INI%, IrfanViewWindow, MonitorLeft, not saved
    IniRead, irfan_top, %SETTINGS_INI%, IrfanViewWindow, MonitorTop, not saved
    IniRead, irfan_right, %SETTINGS_INI%, IrfanViewWindow, MonitorRight, not saved
    IniRead, irfan_bottom, %SETTINGS_INI%, IrfanViewWindow, MonitorBottom, not saved

    message_text := "Manager window:`n"
    message_text .= "X=" . manager_x . ", Y=" . manager_y
    message_text .= ", Width=" . manager_width . ", Height=" . manager_height . "`n`n"
    message_text .= "IrfanView display bounds:`n"
    message_text .= "Left=" . irfan_left . ", Top=" . irfan_top
    message_text .= ", Right=" . irfan_right . ", Bottom=" . irfan_bottom

    MsgBox, 64, Window Display Memory, %message_text%
}

; =====================================================================
; GUI INTEGRATION FUNCTIONS
; =====================================================================

/* Load the saved galleries root and automatic VLC option.
   A command-line root path overrides only the saved root for this run.
*/
loadManagerSettings()
{
    global ROOT_FOLDER, SETTINGS_INI, AUTO_VLC_ENABLED

    ROOT_FOLDER := normalizeFolderPath(ROOT_FOLDER)

    if (ROOT_FOLDER = "")
    {
        IniRead, saved_root_folder, %SETTINGS_INI%, Galleries, RootPath,
        if (saved_root_folder != "ERROR")
        {
            ROOT_FOLDER := normalizeFolderPath(saved_root_folder)
        }
    }

    if (ROOT_FOLDER != "" && !FileExist(ROOT_FOLDER))
    {
        ROOT_FOLDER := ""
    }

    IniRead, saved_auto_vlc, %SETTINGS_INI%, Options, AutoVlc, 1
    AUTO_VLC_ENABLED := saved_auto_vlc ? true : false
}

/* Read the saved IrfanView executable without opening a startup dialog.
   The regular IrfanView browser is shown only when a gallery is started.
*/
readSavedIrfanViewPath()
{
    global SETTINGS_INI

    IniRead, saved_irfanview_path, %SETTINGS_INI%, IrfanView, ExePath,
    saved_irfanview_path := Trim(saved_irfanview_path, " `t`r`n""")

    if (saved_irfanview_path != "" && FileExist(saved_irfanview_path))
    {
        return saved_irfanview_path
    }

    return ""
}

/* Load the keyword database belonging to the current galleries root.
   Active filters are preserved only when they still exist in the same root.
*/
loadKeywordConfiguration()
{
    global ROOT_FOLDER, KEYWORDS_INI, KEYWORDS_INI_FILENAME
    global keyword_list, active_keyword_filters

    previous_keywords_ini := KEYWORDS_INI
    ROOT_FOLDER := normalizeFolderPath(ROOT_FOLDER)
    keyword_list := []

    if (ROOT_FOLDER = "" || !InStr(FileExist(ROOT_FOLDER), "D"))
    {
        KEYWORDS_INI := ""
        active_keyword_filters := {}
        return false
    }

    KEYWORDS_INI := ROOT_FOLDER . "\" . KEYWORDS_INI_FILENAME

    if (!ensureKeywordIniFile())
    {
        keyword_list := []
        active_keyword_filters := {}
        return false
    }

    IniRead, keyword_text, %KEYWORDS_INI%, Keywords, List,
    keyword_list := parseKeywordList(keyword_text)
    normalized_keyword_text := joinKeywordList(keyword_list)

    if (normalized_keyword_text != keyword_text)
    {
        IniWrite, %normalized_keyword_text%, %KEYWORDS_INI%, Keywords, List
    }

    if (toLowerText(previous_keywords_ini) != toLowerText(KEYWORDS_INI))
    {
        active_keyword_filters := {}
    }
    else
    {
        pruneActiveKeywordFilters()
    }

    return true
}

/* Create the root-level keyword INI when it does not exist.
   Parent assignments are added as separate sections when first used.
*/
ensureKeywordIniFile()
{
    global KEYWORDS_INI

    if (KEYWORDS_INI = "")
    {
        return false
    }

    if (FileExist(KEYWORDS_INI))
    {
        return true
    }

    initial_ini_text := "[Keywords]`r`nList=`r`n"
    FileAppend, %initial_ini_text%, %KEYWORDS_INI%

    return !ErrorLevel && FileExist(KEYWORDS_INI)
}

/* Parse pipe-separated keyword text into a case-insensitive unique array.
   A pipe is reserved as the storage delimiter.
*/
parseKeywordList(keyword_text)
{
    parsed_keywords := []
    seen_keywords := {}

    Loop, Parse, keyword_text, |
    {
        keyword_name := Trim(A_LoopField, " `t`r`n")

        if (keyword_name = "")
        {
            continue
        }

        keyword_key := toLowerText(keyword_name)

        if (seen_keywords.HasKey(keyword_key))
        {
            continue
        }

        seen_keywords[keyword_key] := true
        parsed_keywords.Push(keyword_name)
    }

    sortKeywordArray(parsed_keywords)
    return parsed_keywords
}

/* Sort one keyword array alphabetically, case-insensitively.
   A simple in-place sort keeps compatibility with AutoHotkey v1 arrays.
*/
sortKeywordArray(ByRef keywords)
{
    keyword_count := keywords.Length()

    if (keyword_count < 2)
    {
        return true
    }

    Loop, % keyword_count - 1
    {
        remaining_pairs := keyword_count - A_Index
        swapped_items := false

        Loop, %remaining_pairs%
        {
            keyword_index := A_Index
            left_keyword := keywords[keyword_index]
            right_keyword := keywords[keyword_index + 1]

            if (toLowerText(left_keyword) > toLowerText(right_keyword))
            {
                keywords[keyword_index] := right_keyword
                keywords[keyword_index + 1] := left_keyword
                swapped_items := true
            }
        }

        if (!swapped_items)
        {
            break
        }
    }

    return true
}

/* Join one keyword array for INI storage.
*/
joinKeywordList(keywords)
{
    keyword_text := ""

    for keyword_index, keyword_name in keywords
    {
        if (keyword_text != "")
        {
            keyword_text .= "|"
        }

        keyword_text .= keyword_name
    }

    return keyword_text
}

/* Save the global keyword list to the root keyword database.
*/
saveKeywordList()
{
    global KEYWORDS_INI, keyword_list

    if (KEYWORDS_INI = "" || !ensureKeywordIniFile())
    {
        return false
    }

    keyword_text := joinKeywordList(keyword_list)
    IniWrite, %keyword_text%, %KEYWORDS_INI%, Keywords, List
    return !ErrorLevel
}

/* Add the keyword typed above the TreeView.
   Duplicate keyword names are compared case-insensitively.
*/
addKeywordFromGui()
{
    global KEYWORDS_INI, keyword_list

    Gui, TreeView, GalleryTree
    selected_item_id := TV_GetSelection()
    selected_parent_folder := resolveParentFromTreeItem(selected_item_id)

    if (KEYWORDS_INI = "")
    {
        MsgBox, 48, Gallery Manager, Select and save an existing galleries root folder first.
        return false
    }

    GuiControlGet, new_keyword_name,, NewKeywordEdit
    new_keyword_name := Trim(new_keyword_name, " `t`r`n")

    if (new_keyword_name = "")
    {
        MsgBox, 48, Gallery Manager, Enter a keyword first.
        return false
    }

    if (InStr(new_keyword_name, "|"))
    {
        MsgBox, 48, Gallery Manager, A keyword cannot contain the | character.
        return false
    }

    if (StrLen(new_keyword_name) > 60)
    {
        MsgBox, 48, Gallery Manager, A keyword can contain at most 60 characters.
        return false
    }

    new_keyword_key := toLowerText(new_keyword_name)

    for keyword_index, existing_keyword_name in keyword_list
    {
        if (toLowerText(existing_keyword_name) = new_keyword_key)
        {
            MsgBox, 48, Gallery Manager, This keyword already exists.
            return false
        }
    }

    keyword_list.Push(new_keyword_name)
    sortKeywordArray(keyword_list)

    if (!saveKeywordList())
    {
        removeKeywordFromArray(keyword_list, new_keyword_name)
        MsgBox, 16, Gallery Manager, The keyword could not be saved to the root INI file.
        return false
    }

    keyword_was_applied := false

    if (selected_parent_folder != "")
    {
        if (!assignKeywordToParent(selected_parent_folder, new_keyword_name))
        {
            MsgBox, 48, Gallery Manager, % "The keyword was created, but could not be assigned to:`n`n" . selected_parent_folder
        }
        else
        {
            keyword_was_applied := true
        }
    }

    GuiControl,, NewKeywordEdit,
    rebuildKeywordFilterControls()

    if (selected_item_id != "")
    {
        updateParentPreviewFromTreeItem(selected_item_id)
    }

    if (keyword_was_applied)
    {
        SplitPath, selected_parent_folder, selected_parent_name
        setManagerStatus("Keyword added and applied to " . selected_parent_name . ": " . new_keyword_name)
    }
    else
    {
        setManagerStatus("Keyword added: " . new_keyword_name)
    }

    return true
}

/* Remove one keyword from an array using a case-insensitive comparison.
*/
removeKeywordFromArray(ByRef keywords, keyword_name)
{
    keyword_key := toLowerText(keyword_name)

    for keyword_index, existing_keyword_name in keywords
    {
        if (toLowerText(existing_keyword_name) = keyword_key)
        {
            keywords.RemoveAt(keyword_index)
            return true
        }
    }

    return false
}

/* Assign one keyword to a parent without toggling an existing assignment off.
*/
assignKeywordToParent(parent_folder, keyword_name)
{
    assigned_keywords := readParentKeywordList(parent_folder)
    keyword_key := toLowerText(keyword_name)

    for assigned_index, assigned_keyword_name in assigned_keywords
    {
        if (toLowerText(assigned_keyword_name) = keyword_key)
        {
            return true
        }
    }

    assigned_keywords.Push(keyword_name)
    sortKeywordArray(assigned_keywords)
    return writeParentKeywordList(parent_folder, assigned_keywords)
}

/* Remove global keywords that are not assigned to any parent section.
   Used assignments remain untouched; active filters are pruned automatically.
*/
clearUnusedKeywordsFromGui()
{
    global KEYWORDS_INI, keyword_list, ROOT_FOLDER

    if (KEYWORDS_INI = "" || !FileExist(KEYWORDS_INI))
    {
        MsgBox, 48, Gallery Manager, No root keyword database is available.
        return false
    }

    if (keyword_list.Length() < 1)
    {
        setManagerStatus("There are no keywords to clear.")
        return true
    }

    used_keyword_map := getUsedKeywordMap()
    retained_keywords := []
    removed_keywords := []

    for keyword_index, keyword_name in keyword_list
    {
        keyword_key := toLowerText(keyword_name)

        if (used_keyword_map.HasKey(keyword_key))
        {
            retained_keywords.Push(keyword_name)
        }
        else
        {
            removed_keywords.Push(keyword_name)
        }
    }

    if (removed_keywords.Length() < 1)
    {
        setManagerStatus("All keywords are assigned to at least one parent.")
        return true
    }

    previous_keyword_list := keyword_list
    keyword_list := retained_keywords

    if (!saveKeywordList())
    {
        keyword_list := previous_keyword_list
        MsgBox, 16, Gallery Manager, Unused keywords could not be removed.
        return false
    }

    pruneActiveKeywordFilters()
    rebuildKeywordFilterControls()
    populateGalleryTree(ROOT_FOLDER)

    removed_keyword_text := joinKeywordListForDisplay(removed_keywords)
    setManagerStatus(removed_keywords.Length() . " unused keyword(s) removed: " . removed_keyword_text)
    return true
}

/* Read all Parent.* INI sections and collect every assigned keyword.
*/
getUsedKeywordMap()
{
    global KEYWORDS_INI

    used_keyword_map := {}

    if (KEYWORDS_INI = "" || !FileExist(KEYWORDS_INI))
    {
        return used_keyword_map
    }

    IniRead, section_names, %KEYWORDS_INI%

    if (section_names = "ERROR")
    {
        return used_keyword_map
    }

    Loop, Parse, section_names, `n, `r
    {
        section_name := Trim(A_LoopField, " `t`r`n")

        if (SubStr(section_name, 1, 7) != "Parent.")
        {
            continue
        }

        IniRead, assigned_keyword_text, %KEYWORDS_INI%, %section_name%, Keywords,

        if (assigned_keyword_text = "ERROR" || assigned_keyword_text = "")
        {
            continue
        }

        assigned_keywords := parseKeywordList(assigned_keyword_text)

        for assigned_index, assigned_keyword_name in assigned_keywords
        {
            used_keyword_map[toLowerText(assigned_keyword_name)] := true
        }
    }

    return used_keyword_map
}

/* Join keywords for readable status text rather than INI storage.
*/
joinKeywordListForDisplay(keywords)
{
    display_text := ""

    for keyword_index, keyword_name in keywords
    {
        if (display_text != "")
        {
            display_text .= ", "
        }

        display_text .= keyword_name
    }

    return display_text
}

/* Recreate all filter checkboxes above the TreeView.
   Old generations are hidden because AHK v1 cannot delete individual GUI controls.
*/
rebuildKeywordFilterControls(apply_layout := true)
{
    global keyword_list, active_keyword_filters
    global keyword_filter_controls, keyword_filter_generation
    global keyword_filter_rows, gallery_tree_top
    global keyword_checkbox_hwnd

    if (!setManagerGuiDefault())
    {
        return false
    }

    for old_control_index, old_control_record in keyword_filter_controls
    {
        old_control_hwnd := old_control_record.hwnd

        if (old_control_hwnd != "")
        {
            GuiControl, Hide, %old_control_hwnd%
        }
    }

    keyword_filter_controls := []
    keyword_filter_generation += 1
    pruneActiveKeywordFilters()

    filter_start_x := 82
    filter_start_y := 112
    filter_row_height := 27
    filter_right_edge := 840
    current_client_width := 0
    current_client_height := 0

    if (getManagerClientSize(current_client_width, current_client_height) && current_client_width >= 850)
    {
        filter_right_edge := current_client_width - 18
    }

    filter_x := filter_start_x
    filter_y := filter_start_y
    keyword_filter_rows := 1

    if (keyword_list.Length() < 1)
    {
        GuiControl, Show, KeywordFilterEmptyText
    }
    else
    {
        GuiControl, Hide, KeywordFilterEmptyText
        Gui, Font, s9 cF0F0F0, Segoe UI

        for keyword_index, keyword_name in keyword_list
        {
            checkbox_width := 34 + (StrLen(keyword_name) * 8)

            if (checkbox_width < 82)
            {
                checkbox_width := 82
            }

            if (checkbox_width > 220)
            {
                checkbox_width := 220
            }

            if (filter_x + checkbox_width > filter_right_edge && filter_x > filter_start_x)
            {
                filter_x := filter_start_x
                filter_y += filter_row_height
                keyword_filter_rows += 1
            }

            control_options := "x" . filter_x . " y" . filter_y . " w" . checkbox_width . " h24"
            control_options .= " hwndkeyword_checkbox_hwnd gKeywordFilterChanged cF0F0F0"

            if (active_keyword_filters.HasKey(toLowerText(keyword_name)))
            {
                control_options .= " Checked"
            }

            keyword_checkbox_hwnd := ""
            keyword_control_text := escapeGuiControlText(keyword_name)
            Gui, Add, Checkbox, %control_options%, %keyword_control_text%

            if (keyword_checkbox_hwnd = "")
            {
                continue
            }

            control_record := {}
            control_record.hwnd := keyword_checkbox_hwnd
            control_record.keyword := keyword_name
            keyword_filter_controls.Push(control_record)

            filter_x += checkbox_width + 8
        }

        Gui, Font, s10 cF0F0F0, Segoe UI
    }

    gallery_tree_top := filter_start_y + (keyword_filter_rows * filter_row_height) + 8

    if (apply_layout)
    {
        Gui, Show, NA

        if (getManagerClientSize(current_client_width, current_client_height))
        {
            layoutManagerControls(current_client_width, current_client_height)
        }
    }

    return true
}

/* Read the dynamic filter checkbox values.
   Multiple selected keywords use OR matching.
*/
updateActiveKeywordFiltersFromControls()
{
    global keyword_filter_controls, active_keyword_filters

    active_keyword_filters := {}

    for control_index, control_record in keyword_filter_controls
    {
        control_hwnd := control_record.hwnd

        if (control_hwnd = "")
        {
            continue
        }

        GuiControlGet, control_state,, %control_hwnd%

        if (control_state)
        {
            active_keyword_filters[toLowerText(control_record.keyword)] := true
        }
    }
}

/* Remove filters that no longer exist in the root keyword list.
*/
pruneActiveKeywordFilters()
{
    global keyword_list, active_keyword_filters

    available_keyword_map := {}

    for keyword_index, keyword_name in keyword_list
    {
        available_keyword_map[toLowerText(keyword_name)] := true
    }

    pruned_filters := {}

    for keyword_key, filter_state in active_keyword_filters
    {
        if (filter_state && available_keyword_map.HasKey(keyword_key))
        {
            pruned_filters[keyword_key] := true
        }
    }

    active_keyword_filters := pruned_filters
}

/* Return true when at least one keyword filter is checked.
*/
hasActiveKeywordFilters()
{
    global active_keyword_filters

    for keyword_key, filter_state in active_keyword_filters
    {
        if (filter_state)
        {
            return true
        }
    }

    return false
}

/* Match a parent against the checked filter keywords.
   No checked keyword means show every parent; multiple checks use OR.
*/
parentMatchesActiveKeywordFilters(parent_folder)
{
    global active_keyword_filters

    if (!hasActiveKeywordFilters())
    {
        return true
    }

    assigned_keywords := readParentKeywordList(parent_folder)
    assigned_keyword_map := {}

    for assigned_index, assigned_keyword_name in assigned_keywords
    {
        assigned_keyword_map[toLowerText(assigned_keyword_name)] := true
    }

    for keyword_key, filter_state in active_keyword_filters
    {
        if (filter_state && assigned_keyword_map.HasKey(keyword_key))
        {
            return true
        }
    }

    return false
}

/* Build the status-line description of checked filters.
*/
getActiveKeywordFilterDescription()
{
    global keyword_list, active_keyword_filters

    filter_description := ""

    for keyword_index, keyword_name in keyword_list
    {
        if (!active_keyword_filters.HasKey(toLowerText(keyword_name)))
        {
            continue
        }

        if (filter_description != "")
        {
            filter_description .= ", "
        }

        filter_description .= keyword_name
    }

    return filter_description
}

/* Build TreeView status text with current filter information.
   The selected path is intentionally omitted from the bottom status label.
*/
buildGalleryTreeStatus(selected_gallery := "")
{
    global gallery_tree_count

    status_text := gallery_tree_count . " galleries found."
    filter_description := getActiveKeywordFilterDescription()

    if (filter_description != "")
    {
        status_text .= " Filter: " . filter_description
    }

    return status_text
}

/* Resolve a TreeView parent or gallery item to its parent-gallery folder.
*/
resolveParentFromTreeItem(item_id)
{
    global gallery_tree_paths, gallery_tree_types

    if (item_id = "")
    {
        return ""
    }

    item_type := gallery_tree_types[item_id]

    if (item_type = "parent")
    {
        return gallery_tree_paths[item_id]
    }

    if (item_type = "gallery")
    {
        gallery_path := gallery_tree_paths[item_id]
        SplitPath, gallery_path,, parent_folder
        return normalizeFolderPath(parent_folder)
    }

    return ""
}

/* Show the keyword assignment menu for one parent gallery.
   Checked menu entries are currently assigned keywords.
*/
showParentKeywordContextMenu(item_id, menu_x := "", menu_y := "")
{
    global keyword_list, keyword_context_parent, keyword_context_menu_items

    Gui, TreeView, GalleryTree
    parent_folder := resolveParentFromTreeItem(item_id)

    if (parent_folder = "")
    {
        return false
    }

    TV_Modify(item_id, "Select")
    updateParentPreviewFromTreeItem(item_id)
    keyword_context_parent := parent_folder
    keyword_context_menu_items := []

    assigned_keywords := readParentKeywordList(parent_folder)
    assigned_keyword_map := {}

    for assigned_index, assigned_keyword_name in assigned_keywords
    {
        assigned_keyword_map[toLowerText(assigned_keyword_name)] := true
    }

    ; The dynamic menu may not exist on its first use.
    ; UseErrorLevel prevents DeleteAll from raising an AHK runtime dialog.
    Menu, ParentKeywordMenu, UseErrorLevel
    Menu, ParentKeywordMenu, DeleteAll

    if (keyword_list.Length() < 1)
    {
        Menu, ParentKeywordMenu, Add, No keywords defined, ParentKeywordMenuSelected
        Menu, ParentKeywordMenu, Disable, No keywords defined

        if (menu_x != "" && menu_y != "")
        {
            Menu, ParentKeywordMenu, Show, %menu_x%, %menu_y%
        }
        else
        {
            Menu, ParentKeywordMenu, Show
        }

        return true
    }

    for keyword_index, keyword_name in keyword_list
    {
        keyword_context_menu_items.Push(keyword_name)
        menu_item_text := escapeMenuItemText(keyword_name)
        Menu, ParentKeywordMenu, Add, %menu_item_text%, ParentKeywordMenuSelected

        if (assigned_keyword_map.HasKey(toLowerText(keyword_name)))
        {
            Menu, ParentKeywordMenu, Check, %menu_item_text%
        }
    }

    if (menu_x != "" && menu_y != "")
    {
        Menu, ParentKeywordMenu, Show, %menu_x%, %menu_y%
    }
    else
    {
        Menu, ParentKeywordMenu, Show
    }

    return true
}

/* Toggle the assignment selected from the parent keyword context menu.
*/
handleParentKeywordMenuSelection(menu_item_position)
{
    global ROOT_FOLDER, keyword_context_parent, keyword_context_menu_items

    if (keyword_context_parent = "")
    {
        return false
    }

    if (menu_item_position < 1 || menu_item_position > keyword_context_menu_items.Length())
    {
        return false
    }

    selected_keyword := keyword_context_menu_items[menu_item_position]

    if (!toggleParentKeywordAssignment(keyword_context_parent, selected_keyword))
    {
        MsgBox, 16, Gallery Manager, The parent keyword assignment could not be saved.
        return false
    }

    populateGalleryTree(ROOT_FOLDER)
    return true
}

/* Toggle one keyword in a parent's assignment list.
*/
toggleParentKeywordAssignment(parent_folder, keyword_name)
{
    assigned_keywords := readParentKeywordList(parent_folder)
    selected_keyword_key := toLowerText(keyword_name)
    updated_keywords := []
    keyword_was_assigned := false

    for assigned_index, assigned_keyword_name in assigned_keywords
    {
        if (toLowerText(assigned_keyword_name) = selected_keyword_key)
        {
            keyword_was_assigned := true
            continue
        }

        updated_keywords.Push(assigned_keyword_name)
    }

    if (!keyword_was_assigned)
    {
        updated_keywords.Push(keyword_name)
    }

    return writeParentKeywordList(parent_folder, updated_keywords)
}

/* Read one parent's keyword list from its path-derived INI section.
*/
readParentKeywordList(parent_folder)
{
    global KEYWORDS_INI

    assigned_keywords := []

    if (KEYWORDS_INI = "" || !FileExist(KEYWORDS_INI))
    {
        return assigned_keywords
    }

    parent_section := getParentKeywordSection(parent_folder)

    if (parent_section = "")
    {
        return assigned_keywords
    }

    IniRead, assigned_keyword_text, %KEYWORDS_INI%, %parent_section%, Keywords,

    if (assigned_keyword_text = "ERROR")
    {
        return assigned_keywords
    }

    return parseKeywordList(assigned_keyword_text)
}

/* Save one parent's keyword list.
   Empty assignments remove the parent section.
*/
writeParentKeywordList(parent_folder, assigned_keywords)
{
    global KEYWORDS_INI

    if (KEYWORDS_INI = "" || !ensureKeywordIniFile())
    {
        return false
    }

    parent_section := getParentKeywordSection(parent_folder)

    if (parent_section = "")
    {
        return false
    }

    if (assigned_keywords.Length() < 1)
    {
        IniDelete, %KEYWORDS_INI%, %parent_section%
        return !ErrorLevel
    }

    assigned_keyword_text := joinKeywordList(assigned_keywords)
    IniWrite, %assigned_keyword_text%, %KEYWORDS_INI%, %parent_section%, Keywords
    return !ErrorLevel
}

/* Derive a stable INI section from the parent path relative to the root.
*/
getParentKeywordSection(parent_folder)
{
    global ROOT_FOLDER

    parent_folder := normalizeFolderPath(parent_folder)
    root_folder_normalized := normalizeFolderPath(ROOT_FOLDER)

    if (parent_folder = "" || root_folder_normalized = "")
    {
        return ""
    }

    root_prefix := root_folder_normalized . "\"
    parent_folder_lower := toLowerText(parent_folder)
    root_prefix_lower := toLowerText(root_prefix)

    if (SubStr(parent_folder_lower, 1, StrLen(root_prefix_lower)) = root_prefix_lower)
    {
        relative_parent_path := SubStr(parent_folder, StrLen(root_prefix) + 1)
    }
    else if (parent_folder_lower = toLowerText(root_folder_normalized))
    {
        relative_parent_path := "."
    }
    else
    {
        relative_parent_path := parent_folder
    }

    encoded_path := StrReplace(relative_parent_path, "%", "%25")
    encoded_path := StrReplace(encoded_path, "\", "%5C")
    encoded_path := StrReplace(encoded_path, "/", "%2F")
    encoded_path := StrReplace(encoded_path, "[", "%5B")
    encoded_path := StrReplace(encoded_path, "]", "%5D")

    return "Parent." . encoded_path
}

/* Escape ampersands used as GUI accelerator markers.
*/
escapeGuiControlText(control_text)
{
    return StrReplace(control_text, "&", "&&")
}

/* Escape ampersands used as menu accelerator markers.
*/
escapeMenuItemText(menu_text)
{
    return StrReplace(menu_text, "&", "&&")
}

/* Make the manager window the default GUI for the current AHK thread.
   Timer threads otherwise fall back to GUI 1 and can create a stray script-titled window.
*/
setManagerGuiDefault()
{
    global main_gui_hwnd

    if (main_gui_hwnd = "" || !WinExist("ahk_id " . main_gui_hwnd))
    {
        return false
    }

    Gui, %main_gui_hwnd%:Default
    return true
}

/* Resize controls while preserving the dynamic keyword-filter area.
*/
layoutManagerControls(gui_width, gui_height)
{
    global gallery_tree_top
    global preview_canvas_x, preview_canvas_y
    global preview_canvas_width, preview_canvas_height

    content_width := gui_width - 54
    panel_gap := 14
    tree_width := Floor((content_width - panel_gap) / 2)
    preview_width := content_width - panel_gap - tree_width
    preview_x := 18 + tree_width + panel_gap

    row_one_y := gui_height - 154
    row_two_y := gui_height - 114
    status_y := gui_height - 66
    tree_height := row_one_y - gallery_tree_top - 12

    right_edge := gui_width - 18
    refresh_x := right_edge - 110
    open_parent_x := refresh_x - 135
    start_x := right_edge - 128
    random_start_x := start_x - 135

    if (tree_height < 120)
    {
        tree_height := 120
    }

    preview_header_height := 50
    preview_canvas_x := preview_x
    preview_canvas_y := gallery_tree_top + preview_header_height
    preview_canvas_width := preview_width
    preview_canvas_height := tree_height - preview_header_height

    if (preview_canvas_height < 70)
    {
        preview_canvas_height := 70
    }

    placeholder_x := preview_x + 14
    placeholder_y := preview_canvas_y + 14
    placeholder_width := preview_width - 28
    placeholder_height := preview_canvas_height - 28

    GuiControl, Move, GalleryTree, % "x18 y" gallery_tree_top " w" tree_width " h" tree_height
    GuiControl, Move, ParentPreviewTitle, % "x" preview_x " y" gallery_tree_top " w" preview_width " h22"
    GuiControl, Move, ParentPreviewKeywords, % "x" preview_x " y" (gallery_tree_top + 24) " w" preview_width " h22"
    GuiControl, Move, ParentPreviewCanvas, % "x" preview_x " y" preview_canvas_y " w" preview_width " h" preview_canvas_height
    GuiControl, Move, ParentPreviewPlaceholder, % "x" placeholder_x " y" placeholder_y " w" placeholder_width " h" placeholder_height

    GuiControl, Move, AutoVlcEnabled, % "x18 y" (row_one_y + 4)
    GuiControl, Move, OpenParentButton, % "x" open_parent_x " y" row_one_y
    GuiControl, Move, RefreshButton, % "x" refresh_x " y" row_one_y
    GuiControl, Move, RandomStartButton, % "x" random_start_x " y" row_two_y
    GuiControl, Move, StartButton, % "x" start_x " y" row_two_y
    GuiControl, Move, ManagerStatusText, % "x18 y" status_y " w" content_width

    SetTimer, parentPreviewResizeTimer, -120
}

/* Read the manager GUI client size for dynamic filter layout.
*/
getManagerClientSize(ByRef client_width, ByRef client_height)
{
    global main_gui_hwnd

    client_width := 0
    client_height := 0

    if (main_gui_hwnd = "")
    {
        return false
    }

    VarSetCapacity(client_rectangle, 16, 0)

    if (!DllCall("GetClientRect", "Ptr", main_gui_hwnd, "Ptr", &client_rectangle))
    {
        return false
    }

    client_width := NumGet(client_rectangle, 8, "Int")
    client_height := NumGet(client_rectangle, 12, "Int")
    return client_width > 0 && client_height > 0
}

/* Display the current keyword INI and one optional parent's assignments.
   This diagnostic does not modify the database.
*/
showKeywordConfigurationTest(parent_folder)
{
    global ROOT_FOLDER, KEYWORDS_INI, keyword_list

    keyword_text := joinKeywordList(keyword_list)

    if (keyword_text = "")
    {
        keyword_text := "(none)"
    }

    message_text := "Root:`n" . ROOT_FOLDER
    message_text .= "`n`nKeyword INI:`n" . KEYWORDS_INI
    message_text .= "`n`nKeywords:`n" . keyword_text

    parent_folder := normalizeFolderPath(parent_folder)

    if (parent_folder != "")
    {
        assigned_keywords := readParentKeywordList(parent_folder)
        assigned_keyword_text := joinKeywordList(assigned_keywords)

        if (assigned_keyword_text = "")
        {
            assigned_keyword_text := "(none)"
        }

        message_text .= "`n`nParent:`n" . parent_folder
        message_text .= "`n`nAssigned:`n" . assigned_keyword_text
    }

    MsgBox, 64, Keyword Configuration Test, %message_text%
}

/* Save the galleries-root edit value and rebuild the TreeView.
   The selected path must be an existing directory.
*/
saveGalleriesRootFromGui()
{
    global ROOT_FOLDER, SETTINGS_INI

    GuiControlGet, root_folder_text,, GalleriesRootEdit
    root_folder_text := normalizeFolderPath(root_folder_text)

    if (root_folder_text = "" || !FileExist(root_folder_text))
    {
        MsgBox, 48, Gallery Manager, The galleries root folder does not exist.
        return false
    }

    ROOT_FOLDER := root_folder_text
    IniWrite, %ROOT_FOLDER%, %SETTINGS_INI%, Galleries, RootPath
    loadKeywordConfiguration()
    rebuildKeywordFilterControls()
    populateGalleryTree(ROOT_FOLDER)
    return true
}

/* Reload the root keyword database and rebuild the TreeView on startup.
   This runs even when the saved root is missing so the status is refreshed.
*/
refreshTreeOnInitialization()
{
    global ROOT_FOLDER

    ROOT_FOLDER := normalizeFolderPath(ROOT_FOLDER)

    if (ROOT_FOLDER = "" || !InStr(FileExist(ROOT_FOLDER), "D"))
    {
        setManagerStatus("Select or browse an existing galleries root folder.")
        clearPreviewHeader()
        clearParentPreview("Select a parent or gallery.")
        return false
    }

    loadKeywordConfiguration()
    rebuildKeywordFilterControls()
    return populateGalleryTree(ROOT_FOLDER)
}

/* Populate the TreeView from [A-Z]\parent\gallery directories.
   No image files are enumerated while the tree is being built.
*/
populateGalleryTree(galleries_root_path)
{
    global ROOT_FOLDER, EXCLUDED_FOLDER_NAMES
    global gallery_tree_paths, gallery_tree_types, gallery_tree_has_video, gallery_tree_count
    global selected_gallery_path

    galleries_root_path := normalizeFolderPath(galleries_root_path)

    if (galleries_root_path = "" || !FileExist(galleries_root_path))
    {
        return false
    }

    ROOT_FOLDER := galleries_root_path
    excluded_map := buildExcludedNameMap(EXCLUDED_FOLDER_NAMES)

    Gui, TreeView, GalleryTree
    GuiControl, Disable, RandomStartButton
    GuiControl, -Redraw, GalleryTree
    TV_Delete()

    gallery_tree_paths := {}
    gallery_tree_types := {}
    gallery_tree_has_video := {}
    gallery_tree_count := 0
    selected_gallery_path := ""
    clearPreviewHeader()
    clearParentPreview("Select a parent or gallery.")

    first_letter_item_id := ""
    first_parent_item_id := ""
    first_gallery_item_id := ""

    letter_folders := getDirectSubfolders(galleries_root_path)

    for letter_index, letter_folder in letter_folders
    {
        SplitPath, letter_folder, letter_name

        if (!RegExMatch(letter_name, "i)^[A-Z]$"))
        {
            continue
        }

        parent_records := []
        letter_gallery_count := 0
        parent_folders := getDirectSubfolders(letter_folder)

        for parent_index, parent_folder in parent_folders
        {
            SplitPath, parent_folder, parent_name

            if (excluded_map.HasKey(toLowerText(parent_name)))
            {
                continue
            }

            if (!parentMatchesActiveKeywordFilters(parent_folder))
            {
                continue
            }

            gallery_folders := getTreeGalleryFolders(parent_folder, excluded_map)
            if (gallery_folders.Length() < 1)
            {
                continue
            }

            parent_record := {}
            parent_record.path := parent_folder
            parent_record.galleries := gallery_folders
            parent_records.Push(parent_record)
            letter_gallery_count += gallery_folders.Length()
        }

        if (parent_records.Length() < 1)
        {
            continue
        }

        letter_item_id := TV_Add(letter_name . "  [" . letter_gallery_count . "]")
        gallery_tree_paths[letter_item_id] := letter_folder
        gallery_tree_types[letter_item_id] := "letter"

        if (first_letter_item_id = "")
        {
            first_letter_item_id := letter_item_id
        }

        for parent_record_index, parent_record in parent_records
        {
            parent_path_for_name := parent_record.path
            SplitPath, parent_path_for_name, parent_name

            parent_item_id := TV_Add(parent_name . "  [" . parent_record.galleries.Length() . "]", letter_item_id)
            gallery_tree_paths[parent_item_id] := parent_record.path
            gallery_tree_types[parent_item_id] := "parent"

            if (first_parent_item_id = "")
            {
                first_parent_item_id := parent_item_id
            }

            for gallery_index, gallery_folder in parent_record.galleries
            {
                SplitPath, gallery_folder, gallery_name

                gallery_item_id := TV_Add(gallery_name, parent_item_id)
                gallery_tree_paths[gallery_item_id] := gallery_folder
                gallery_tree_types[gallery_item_id] := "gallery"

                paired_video_path := findPairedVideo(parent_record.path, gallery_folder)
                gallery_tree_has_video[gallery_item_id] := paired_video_path != ""
                gallery_tree_count += 1

                if (first_gallery_item_id = "")
                {
                    first_gallery_item_id := gallery_item_id
                }
            }
        }

        Sleep, -1
    }

    if (first_letter_item_id != "")
    {
        TV_Modify(first_letter_item_id, "Expand")
    }

    if (first_parent_item_id != "")
    {
        TV_Modify(first_parent_item_id, "Expand")
    }

    if (first_gallery_item_id != "")
    {
        TV_Modify(first_gallery_item_id, "Select Vis")
        selected_gallery_path := gallery_tree_paths[first_gallery_item_id]
        updateParentPreviewFromTreeItem(first_gallery_item_id)
        GuiControl, Enable, RandomStartButton
        setManagerStatus(buildGalleryTreeStatus(selected_gallery_path))
    }
    else
    {
        filter_description := getActiveKeywordFilterDescription()

        if (filter_description != "")
        {
            setManagerStatus("No galleries match keyword filter: " . filter_description)
        }
        else
        {
            setManagerStatus("No galleries found. Expected: [A-Z]\gallery parent\gallery")
        }
    }

    GuiControl, +Redraw, GalleryTree
    return true
}

/* Return immediate gallery directories for one TreeView parent.
   Folder names are indexed without testing their image contents.
*/
getTreeGalleryFolders(parent_folder, excluded_map)
{
    gallery_folders := []

    if (parent_folder = "" || !FileExist(parent_folder))
    {
        return gallery_folders
    }

    Loop, Files, % parent_folder . "\*", D
    {
        if (excluded_map.HasKey(toLowerText(A_LoopFileName)))
        {
            continue
        }

        gallery_folders.Push(normalizeFolderPath(A_LoopFileFullPath))
    }

    sortPathArray(gallery_folders)
    return gallery_folders
}

/* Return immediate subfolders sorted alphabetically.
   This helper never performs recursive scanning.
*/
getDirectSubfolders(parent_folder)
{
    folder_paths := []

    if (parent_folder = "" || !FileExist(parent_folder))
    {
        return folder_paths
    }

    Loop, Files, % parent_folder . "\*", D
    {
        folder_paths.Push(normalizeFolderPath(A_LoopFileFullPath))
    }

    sortPathArray(folder_paths)
    return folder_paths
}

/* Resolve the current TreeView item to a gallery directory.
   Selecting a letter or parent resolves to its first gallery child.
*/
resolveGalleryFromTreeItem(item_id)
{
    global gallery_tree_paths, gallery_tree_types

    if (item_id = "")
    {
        return ""
    }

    item_type := gallery_tree_types[item_id]

    if (item_type = "gallery")
    {
        return gallery_tree_paths[item_id]
    }

    if (item_type = "parent")
    {
        gallery_item_id := TV_GetChild(item_id)

        if (gallery_item_id != "" && gallery_tree_types[gallery_item_id] = "gallery")
        {
            return gallery_tree_paths[gallery_item_id]
        }

        return ""
    }

    if (item_type = "letter")
    {
        parent_item_id := TV_GetChild(item_id)
        if (parent_item_id = "")
        {
            return ""
        }

        gallery_item_id := TV_GetChild(parent_item_id)

        if (gallery_item_id != "" && gallery_tree_types[gallery_item_id] = "gallery")
        {
            return gallery_tree_paths[gallery_item_id]
        }
    }

    return ""
}

/* Start a slideshow from a double-clicked gallery or parent row.
   A parent row starts its first displayed gallery; letter rows are ignored.
*/
startGalleryFromDoubleClick(item_id)
{
    global gallery_tree_paths, gallery_tree_types

    if (item_id = "")
    {
        return false
    }

    item_type := gallery_tree_types[item_id]

    if (item_type != "gallery" && item_type != "parent")
    {
        return false
    }

    gallery_folder := resolveGalleryFromTreeItem(item_id)

    if (gallery_folder = "")
    {
        return false
    }

    if (item_type = "parent")
    {
        gallery_item_id := TV_GetChild(item_id)

        if (gallery_item_id != "")
        {
            TV_Modify(gallery_item_id, "Select Vis")
        }
    }
    else
    {
        TV_Modify(item_id, "Select Vis")
    }

    updateSelectedGalleryFromTree()
    return startGalleryFromPath(gallery_folder)
}

/* Update the status text from the selected TreeView item.
   The function does not build an image list.
*/
updateSelectedGalleryFromTree()
{
    global selected_gallery_path, gallery_tree_count

    selected_item_id := TV_GetSelection()
    selected_gallery_path := resolveGalleryFromTreeItem(selected_item_id)
    updateParentPreviewFromTreeItem(selected_item_id)

    if (selected_gallery_path != "")
    {
        setManagerStatus(buildGalleryTreeStatus(selected_gallery_path))
    }
}

/* Preview folder.jpg for a parent row, or the first image for a gallery row.
   The header always displays the parent name and its assigned keywords.
*/
updateParentPreviewFromTreeItem(item_id)
{
    global gallery_tree_paths, gallery_tree_types

    if (item_id = "")
    {
        clearPreviewHeader()
        clearParentPreview("Select a parent or gallery.")
        return false
    }

    item_type := gallery_tree_types[item_id]
    parent_folder := resolveParentFromTreeItem(item_id)

    if (parent_folder = "")
    {
        clearPreviewHeader()
        clearParentPreview("Select a parent or gallery.")
        return false
    }

    selected_path := gallery_tree_paths[item_id]
    updatePreviewHeader(parent_folder, selected_path, item_type)

    if (item_type = "gallery")
    {
        return showGalleryFirstImage(selected_path)
    }

    if (item_type = "parent")
    {
        return showParentFolderPreview(parent_folder)
    }

    clearParentPreview("Select a parent or gallery.")
    return false
}

/* Update the preview title and the selected parent's assigned keywords.
*/
updatePreviewHeader(parent_folder, selected_path, item_type)
{
    parent_folder := normalizeFolderPath(parent_folder)
    SplitPath, parent_folder, parent_name

    title_text := parent_name

    if (item_type = "gallery")
    {
        SplitPath, selected_path, gallery_name
        title_text .= "  /  " . gallery_name
    }

    assigned_keywords := readParentKeywordList(parent_folder)
    assigned_keyword_text := joinKeywordListForDisplay(assigned_keywords)

    GuiControl,, ParentPreviewTitle, %title_text%
    GuiControl,, ParentPreviewKeywords, %assigned_keyword_text%
}

/* Clear both preview labels when no parent can be resolved.
*/
clearPreviewHeader()
{
    GuiControl,, ParentPreviewTitle, No selection
    GuiControl,, ParentPreviewKeywords,
}

/* Load the selected parent's direct folder.jpg into the right-side canvas.
*/
showParentFolderPreview(parent_folder)
{
    global preview_parent_folder, preview_image_path

    parent_folder := normalizeFolderPath(parent_folder)
    preview_parent_folder := parent_folder

    if (parent_folder = "")
    {
        clearParentPreview("Select a parent or gallery.")
        return false
    }

    image_path := parent_folder . "\folder.jpg"

    if (!FileExist(image_path))
    {
        clearParentPreview("No folder.jpg")
        preview_parent_folder := parent_folder
        return false
    }

    preview_image_path := image_path
    return renderParentPreviewImage()
}

/* Load the alphabetically first direct image from the selected gallery.
*/
showGalleryFirstImage(gallery_folder)
{
    global preview_parent_folder, preview_image_path

    gallery_folder := normalizeFolderPath(gallery_folder)

    if (gallery_folder = "")
    {
        clearParentPreview("No gallery selected.")
        return false
    }

    SplitPath, gallery_folder,, parent_folder
    preview_parent_folder := normalizeFolderPath(parent_folder)
    first_image_path := findFirstImageInGallery(gallery_folder)

    if (first_image_path = "")
    {
        clearParentPreview("No image found in this gallery.")
        return false
    }

    preview_image_path := first_image_path
    return renderParentPreviewImage()
}

/* Return the alphabetically first supported direct image in one gallery.
*/
findFirstImageInGallery(gallery_folder)
{
    global IMAGE_EXTENSIONS

    image_paths := []
    extension_map := buildExtensionMap(IMAGE_EXTENSIONS)

    if (gallery_folder = "" || !InStr(FileExist(gallery_folder), "D"))
    {
        return ""
    }

    Loop, Files, % gallery_folder . "\*.*", F
    {
        SplitPath, A_LoopFileFullPath,,, file_extension
        file_extension := toLowerText(file_extension)

        if (extension_map.HasKey(file_extension))
        {
            image_paths.Push(A_LoopFileFullPath)
        }
    }

    sortPathArray(image_paths)
    return image_paths.Length() > 0 ? image_paths[1] : ""
}

/* Clear the preview image and show one centered message.
*/
clearParentPreview(message_text)
{
    global preview_image_path

    preview_image_path := ""
    GuiControl, Hide, ParentPreviewPicture
    GuiControl,, ParentPreviewPicture,
    GuiControl,, ParentPreviewPlaceholder, %message_text%
    GuiControl, Show, ParentPreviewPlaceholder
    return true
}

/* Fit the current folder.jpg inside the preview canvas without distortion.
*/
renderParentPreviewImage()
{
    global preview_image_path
    global preview_canvas_x, preview_canvas_y
    global preview_canvas_width, preview_canvas_height

    if (preview_image_path = "" || !FileExist(preview_image_path))
    {
        return false
    }

    canvas_width := preview_canvas_width
    canvas_height := preview_canvas_height

    if (canvas_width < 40 || canvas_height < 40)
    {
        if (!getManagerClientSize(gui_width, gui_height))
        {
            return false
        }

        content_width := gui_width - 54
        panel_gap := 14
        tree_width := Floor((content_width - panel_gap) / 2)
        canvas_width := content_width - panel_gap - tree_width
        canvas_height := gui_height - 154 - gallery_tree_top - 12 - 50
        preview_canvas_x := 18 + tree_width + panel_gap
        preview_canvas_y := gallery_tree_top + 50
        preview_canvas_width := canvas_width
        preview_canvas_height := canvas_height
    }

    if (!getImageDimensions(preview_image_path, image_width, image_height))
    {
        clearParentPreview("folder.jpg could not be loaded.")
        return false
    }

    available_width := canvas_width - 20
    available_height := canvas_height - 20

    if (available_width < 1 || available_height < 1)
    {
        return false
    }

    width_scale := available_width / image_width
    height_scale := available_height / image_height
    image_scale := width_scale < height_scale ? width_scale : height_scale

    display_width := Floor(image_width * image_scale)
    display_height := Floor(image_height * image_scale)

    if (display_width < 1)
    {
        display_width := 1
    }

    if (display_height < 1)
    {
        display_height := 1
    }

    picture_x := preview_canvas_x + Floor((canvas_width - display_width) / 2)
    picture_y := preview_canvas_y + Floor((canvas_height - display_height) / 2)

    GuiControl, Move, ParentPreviewPicture, % "x" picture_x " y" picture_y " w" display_width " h" display_height
    picture_options := "*w" . display_width . " *h" . display_height . " " . preview_image_path
    GuiControl,, ParentPreviewPicture, %picture_options%
    GuiControl, Hide, ParentPreviewPlaceholder
    GuiControl, Show, ParentPreviewPicture
    return true
}

/* Read JPEG dimensions through a temporary HBITMAP.
*/
getImageDimensions(image_path, ByRef image_width, ByRef image_height)
{
    image_width := 0
    image_height := 0

    if (image_path = "" || !FileExist(image_path))
    {
        return false
    }

    image_handle := LoadPicture(image_path, "", image_type)

    if (!image_handle || image_type != 0)
    {
        if (image_handle)
        {
            DllCall("DeleteObject", "Ptr", image_handle)
        }

        return false
    }

    bitmap_info_size := A_PtrSize = 8 ? 32 : 24
    VarSetCapacity(bitmap_info, bitmap_info_size, 0)

    if (!DllCall("GetObject", "Ptr", image_handle, "Int", bitmap_info_size, "Ptr", &bitmap_info))
    {
        DllCall("DeleteObject", "Ptr", image_handle)
        return false
    }

    image_width := Abs(NumGet(bitmap_info, 4, "Int"))
    image_height := Abs(NumGet(bitmap_info, 8, "Int"))
    DllCall("DeleteObject", "Ptr", image_handle)

    return image_width > 0 && image_height > 0
}

/* Browse to and select one parent-gallery row in the TreeView.
   Its letter branch and parent branch are expanded before the row is scrolled into view.
*/
browseAndSelectParentPathInTree(parent_folder)
{
    global gallery_tree_paths, gallery_tree_types
    global selected_gallery_path, current_gallery

    parent_folder_lower := toLowerText(normalizeFolderPath(parent_folder))

    if (parent_folder_lower = "")
    {
        return false
    }

    Gui, TreeView, GalleryTree

    for item_id, item_path in gallery_tree_paths
    {
        if (gallery_tree_types[item_id] != "parent")
        {
            continue
        }

        if (toLowerText(normalizeFolderPath(item_path)) != parent_folder_lower)
        {
            continue
        }

        letter_item_id := TV_GetParent(item_id)

        if (letter_item_id != "")
        {
            TV_Modify(letter_item_id, "Expand")
        }

        TV_Modify(item_id, "Expand Select Vis")
        selected_gallery_path := current_gallery
        updateParentPreviewFromTreeItem(item_id)
        return true
    }

    return false
}

/* Select the current gallery in the TreeView when it is present.
   Prepared next-gallery navigation therefore remains visible in the manager.
*/
selectGalleryPathInTree(gallery_folder)
{
    global gallery_tree_paths, gallery_tree_types

    gallery_folder_lower := toLowerText(normalizeFolderPath(gallery_folder))

    for item_id, item_path in gallery_tree_paths
    {
        if (gallery_tree_types[item_id] != "gallery")
        {
            continue
        }

        if (toLowerText(normalizeFolderPath(item_path)) = gallery_folder_lower)
        {
            TV_Modify(item_id, "Select Vis")
            updateParentPreviewFromTreeItem(item_id)
            return true
        }
    }

    return false
}

/* Start a random slideshow from a random valid parent.
   Another parent is preferred when the currently running parent can be avoided.
*/
startRandomParentGallery()
{
    global ROOT_FOLDER, current_parent

    selected_parent_folder := ""
    selected_gallery_folder := ""

    if (!getRandomParentGallerySelection(ROOT_FOLDER, current_parent, selected_parent_folder, selected_gallery_folder))
    {
        MsgBox, 48, Gallery Manager, No valid parent gallery containing images was found.
        return false
    }

    selectGalleryPathInTree(selected_gallery_folder)
    setManagerStatus("Random parent selected:`n" . selected_parent_folder)
    return startGalleryFromPath(selected_gallery_folder)
}

/* Choose a random parent, then a random valid gallery inside that parent.
   The excluded parent is ignored when at least one different parent is available.
*/
getRandomParentGallerySelection(galleries_root_path, excluded_parent_path, ByRef selected_parent_folder, ByRef selected_gallery_folder)
{
    global IMAGE_EXTENSIONS, EXCLUDED_FOLDER_NAMES

    selected_parent_folder := ""
    selected_gallery_folder := ""

    galleries_root_path := normalizeFolderPath(galleries_root_path)

    if (galleries_root_path = "" || !InStr(FileExist(galleries_root_path), "D"))
    {
        return false
    }

    ext_map := buildExtensionMap(IMAGE_EXTENSIONS)
    excluded_map := buildExcludedNameMap(EXCLUDED_FOLDER_NAMES)
    parent_folders := getGalleryParentFolders(galleries_root_path, ext_map, excluded_map)
    filtered_parent_folders := []

    for filter_parent_index, filter_parent_folder in parent_folders
    {
        if (parentMatchesActiveKeywordFilters(filter_parent_folder))
        {
            filtered_parent_folders.Push(filter_parent_folder)
        }
    }

    parent_folders := filtered_parent_folders

    if (parent_folders.Length() < 1)
    {
        return false
    }

    all_parent_folders := []
    alternate_parent_folders := []
    excluded_parent_lower := toLowerText(normalizeFolderPath(excluded_parent_path))

    for parent_index, parent_folder in parent_folders
    {
        all_parent_folders.Push(parent_folder)

        if (excluded_parent_lower = ""
            || toLowerText(normalizeFolderPath(parent_folder)) != excluded_parent_lower)
        {
            alternate_parent_folders.Push(parent_folder)
        }
    }

    if (alternate_parent_folders.Length() > 0)
    {
        candidate_parent_folders := alternate_parent_folders
    }
    else
    {
        candidate_parent_folders := all_parent_folders
    }

    parent_count := candidate_parent_folders.Length()
    Random, selected_parent_index, 1, %parent_count%
    selected_parent_folder := candidate_parent_folders[selected_parent_index]

    gallery_folders := getGalleryFolders(selected_parent_folder, ext_map, excluded_map)

    if (gallery_folders.Length() < 1)
    {
        selected_parent_folder := ""
        return false
    }

    gallery_count := gallery_folders.Length()
    Random, selected_gallery_index, 1, %gallery_count%
    selected_gallery_folder := gallery_folders[selected_gallery_index]
    return selected_gallery_folder != ""
}

/* Start one explicitly selected gallery.
   The image list is generated only now, then version 0.13 workers prepare navigation.
*/
startGalleryFromPath(gallery_folder)
{
    global ROOT_FOLDER, CURRENT_PREFIX, NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX
    global IMAGE_EXTENSIONS, LIST_ENCODING, IRFANVIEW_EXE
    global gallery_worker_pid, parent_worker_pid
    global current_parent, current_gallery, current_count, current_video
    global pending_action, switching_slideshow, irfanview_was_launched

    gallery_folder := normalizeFolderPath(gallery_folder)

    if (gallery_folder = "" || !FileExist(gallery_folder))
    {
        MsgBox, 48, Gallery Manager, The selected gallery folder no longer exists.
        return false
    }

    if (IRFANVIEW_EXE = "" || !FileExist(IRFANVIEW_EXE))
    {
        IRFANVIEW_EXE := configureIrfanViewPath()

        if (IRFANVIEW_EXE = "")
        {
            return false
        }
    }

    SplitPath, gallery_folder,, parent_folder
    ext_map := buildExtensionMap(IMAGE_EXTENSIONS)

    switching_slideshow := true
    pending_action := ""
    SetTimer, pendingSwitchTimer, Off

    stopWorker(gallery_worker_pid)
    stopWorker(parent_worker_pid)
    closeCurrentIrfanView()

    cleanupSlot(CURRENT_PREFIX)
    cleanupSlot(NEXT_GALLERY_PREFIX)
    cleanupSlot(NEXT_PARENT_PREFIX)

    image_count := writeDirectImageList(gallery_folder, CURRENT_PREFIX, ext_map, LIST_ENCODING)

    if (image_count < 1)
    {
        switching_slideshow := false
        MsgBox, 48, Gallery Manager, The selected gallery contains no supported images.
        return false
    }

    paired_video := findPairedVideo(parent_folder, gallery_folder)
    writeMetaFile(CURRENT_PREFIX, parent_folder, gallery_folder, image_count, paired_video)

    current_parent := parent_folder
    current_gallery := gallery_folder
    current_count := image_count
    current_video := paired_video
    irfanview_was_launched := false

    launch_result := launchCurrentSlideshow()

    if (!launch_result)
    {
        switching_slideshow := false
        MsgBox, 16, Gallery Manager, IrfanView could not open the selected gallery.
        return false
    }

    startBothWorkers()
    switching_slideshow := false
    return true
}

/* Open the parent folder of the currently running gallery.
   The TreeView selection is ignored; only current_parent is used.
*/
openCurrentParentFolder()
{
    global current_parent

    if (current_parent = "" || !InStr(FileExist(current_parent), "D"))
    {
        MsgBox, 48, Gallery Manager, No running gallery parent folder is available.
        return false
    }

    if (!openFolderInExplorer(current_parent))
    {
        MsgBox, 16, Gallery Manager, % "Windows Explorer could not open:`n`n" . current_parent
        return false
    }

    return true
}

/* Open one existing directory in Windows Explorer.
   Returns false when the path is missing or Explorer cannot be started.
*/
openFolderInExplorer(folder_path)
{
    folder_path := normalizeFolderPath(folder_path)

    if (folder_path = "" || !InStr(FileExist(folder_path), "D"))
    {
        return false
    }

    explorer_command := "explorer.exe " . quotePath(folder_path)
    Run, %explorer_command%,, UseErrorLevel

    if (ErrorLevel)
    {
        return false
    }

    return true
}

/* Set the manager status text.
   This is persistent UI feedback and does not create tray notifications.
*/
setManagerStatus(status_text)
{
    GuiControl,, ManagerStatusText, %status_text%
}

; =====================================================================
; WORKER FUNCTIONS
; =====================================================================

/* Build one selection for the requested navigation mode.
   First chooses a random parent/gallery; later modes move in sorted order.
*/
workerBuildSelection(worker_mode, root_folder, slot_prefix, base_parent, base_gallery, extensions_text, encoding_name, excluded_names_text)
{
    root_folder := normalizeFolderPath(root_folder)
    base_parent := normalizeFolderPath(base_parent)
    base_gallery := normalizeFolderPath(base_gallery)

    cleanupSlot(slot_prefix)

    if (!FileExist(root_folder))
    {
        writeWorkerError(slot_prefix, "Root folder does not exist:`n" . root_folder)
        return false
    }

    ext_map := buildExtensionMap(extensions_text)
    excluded_map := buildExcludedNameMap(excluded_names_text)

    if (worker_mode = "gallery")
    {
        selected_parent := base_parent
        gallery_folders := getGalleryFolders(selected_parent, ext_map, excluded_map)
        selected_gallery := getNextPath(gallery_folders, base_gallery)
    }
    else
    {
        parent_folders := getGalleryParentFolders(root_folder, ext_map, excluded_map)

        if (worker_mode = "first")
        {
            selected_parent := getRandomPath(parent_folders)
            gallery_folders := getGalleryFolders(selected_parent, ext_map, excluded_map)
            selected_gallery := getRandomPath(gallery_folders)
        }
        else
        {
            selected_parent := getNextPath(parent_folders, base_parent)
            gallery_folders := getGalleryFolders(selected_parent, ext_map, excluded_map)
            selected_gallery := gallery_folders.Length() > 0 ? gallery_folders[1] : ""
        }
    }

    if (selected_parent = "" || selected_gallery = "")
    {
        writeWorkerError(slot_prefix, "No valid gallery folder was found under:`n" . root_folder)
        return false
    }

    image_count := writeDirectImageList(selected_gallery, slot_prefix, ext_map, encoding_name)
    if (image_count < 1)
    {
        writeWorkerError(slot_prefix, "Selected gallery contains no supported images:`n" . selected_gallery)
        return false
    }

    paired_video := findPairedVideo(selected_parent, selected_gallery)
    writeMetaFile(slot_prefix, selected_parent, selected_gallery, image_count, paired_video)
    FileAppend, ready, % slot_prefix . ".ready"
    return true
}

/* Find all gallery parent folders below the root.
   Files directly inside a parent are ignored; only immediate child galleries are tested.
*/
getGalleryParentFolders(root_folder, ext_map, excluded_map)
{
    parent_folders := []

    if (hasGalleryChild(root_folder, ext_map, excluded_map))
    {
        parent_folders.Push(normalizeFolderPath(root_folder))
    }

    Loop, Files, % root_folder . "\*", DR
    {
        folder_path := normalizeFolderPath(A_LoopFileFullPath)

        if (excluded_map.HasKey(toLowerText(A_LoopFileName)))
        {
            continue
        }

        if (hasGalleryChild(folder_path, ext_map, excluded_map))
        {
            parent_folders.Push(folder_path)
        }
    }

    sortPathArray(parent_folders)
    return parent_folders
}

/* Test whether a folder has an immediate child gallery.
   Gallery images must be directly inside that child folder.
*/
hasGalleryChild(parent_folder, ext_map, excluded_map)
{
    Loop, Files, % parent_folder . "\*", D
    {
        if (excluded_map.HasKey(toLowerText(A_LoopFileName)))
        {
            continue
        }

        if (folderHasDirectImages(A_LoopFileFullPath, ext_map))
        {
            return true
        }
    }

    return false
}

/* Return valid immediate gallery folders for one parent.
   No recursive image scanning is used here.
*/
getGalleryFolders(parent_folder, ext_map, excluded_map)
{
    gallery_folders := []

    if (parent_folder = "" || !FileExist(parent_folder))
    {
        return gallery_folders
    }

    Loop, Files, % parent_folder . "\*", D
    {
        if (excluded_map.HasKey(toLowerText(A_LoopFileName)))
        {
            continue
        }

        if (folderHasDirectImages(A_LoopFileFullPath, ext_map))
        {
            gallery_folders.Push(normalizeFolderPath(A_LoopFileFullPath))
        }
    }

    sortPathArray(gallery_folders)
    return gallery_folders
}

/* Test whether one folder contains supported images directly.
   Stops at the first supported image for fast parent discovery.
*/
folderHasDirectImages(folder_path, ext_map)
{
    Loop, Files, % folder_path . "\*.*", F
    {
        if (isImageFile(A_LoopFileFullPath, ext_map))
        {
            return true
        }
    }

    return false
}

/* Write a slideshow list for one gallery folder only.
   Subfolders of the selected gallery are intentionally ignored.
*/
writeDirectImageList(gallery_folder, slot_prefix, ext_map, encoding_name)
{
    list_temp := slot_prefix . ".list.tmp"
    list_final := slot_prefix . ".list.txt"
    FileDelete, %list_temp%
    FileDelete, %list_final%

    old_encoding := A_FileEncoding
    FileEncoding, %encoding_name%

    buffer := ""
    image_count := 0

    Loop, Files, % gallery_folder . "\*.*", F
    {
        if (isImageFile(A_LoopFileFullPath, ext_map))
        {
            buffer .= A_LoopFileFullPath . "`r`n"
            image_count += 1

            if (StrLen(buffer) > 65536)
            {
                FileAppend, %buffer%, %list_temp%
                buffer := ""
            }
        }
    }

    if (buffer != "")
    {
        FileAppend, %buffer%, %list_temp%
    }

    FileEncoding, %old_encoding%

    if (image_count > 0)
    {
        FileMove, %list_temp%, %list_final%, 1
    }
    else
    {
        FileDelete, %list_temp%
    }

    return image_count
}

/* Return the next sorted path after the current path.
   Navigation wraps to the first item after the last item.
*/
getNextPath(path_array, current_path)
{
    if (path_array.Length() < 1)
    {
        return ""
    }

    current_path_lower := toLowerText(normalizeFolderPath(current_path))

    for path_index, path_value in path_array
    {
        if (toLowerText(normalizeFolderPath(path_value)) = current_path_lower)
        {
            next_index := path_index + 1
            if (next_index > path_array.Length())
            {
                next_index := 1
            }

            return path_array[next_index]
        }
    }

    return path_array[1]
}

/* Return one random path from an array.
   Returns an empty string for an empty array.
*/
getRandomPath(path_array)
{
    if (path_array.Length() < 1)
    {
        return ""
    }

    Random, random_index, 1, % path_array.Length()
    return path_array[random_index]
}

/* Sort an AutoHotkey array of paths alphabetically.
   Uses a temporary newline-delimited string for AHK v1 compatibility.
*/
sortPathArray(ByRef path_array)
{
    if (path_array.Length() < 2)
    {
        return
    }

    path_text := ""
    for path_index, path_value in path_array
    {
        path_text .= path_value . "`n"
    }

    Sort, path_text, D`n
    path_array := []

    Loop, Parse, path_text, `n, `r
    {
        if (A_LoopField != "")
        {
            path_array.Push(A_LoopField)
        }
    }
}


/* Apply per-gallery text colors through TreeView custom drawing.
   Light blue means image-only; light green means a paired video exists.
*/
handleTreeViewCustomDraw(wParam, lParam, message_number, source_hwnd)
{
    global GalleryTreeHwnd, gallery_tree_types, gallery_tree_has_video

    if (!lParam || GalleryTreeHwnd = "")
    {
        return
    }

    notified_hwnd := NumGet(lParam + 0, 0, "Ptr")

    if (notified_hwnd != GalleryTreeHwnd)
    {
        return
    }

    notify_code_offset := A_PtrSize * 2
    notify_code := NumGet(lParam + 0, notify_code_offset, "Int")

    if (notify_code != -12)
    {
        return
    }

    custom_draw_header_size := A_PtrSize = 8 ? 24 : 12
    draw_stage := NumGet(lParam + 0, custom_draw_header_size, "UInt")

    if (draw_stage = 0x00000001)
    {
        return 0x00000020
    }

    if (draw_stage != 0x00010001)
    {
        return 0
    }

    item_spec_offset := A_PtrSize = 8 ? 56 : 36
    text_color_offset := A_PtrSize = 8 ? 80 : 48
    item_id := NumGet(lParam + 0, item_spec_offset, "Ptr")

    if (gallery_tree_types[item_id] != "gallery")
    {
        return 0
    }

    if (gallery_tree_has_video[item_id])
    {
        text_color := 0x96EB78
    }
    else
    {
        text_color := 0xFFC878
    }

    NumPut(text_color, lParam + 0, text_color_offset, "UInt")
    return 0x00000002
}

/* Find a parent-level video paired with the selected gallery.
   Only the first integer in each name is compared; later resolution numbers are ignored.
*/
findPairedVideo(parent_folder, gallery_folder)
{
    gallery_number := getFirstIntegerFromName(gallery_folder)
    if (gallery_number = "")
    {
        return ""
    }

    matched_videos := []

    Loop, Files, % parent_folder . "\*.*", F
    {
        SplitPath, A_LoopFileFullPath,,, file_ext
        file_ext := toLowerText(file_ext)

        if (file_ext != "mp4" && file_ext != "wmv")
        {
            continue
        }

        video_number := getFirstIntegerFromName(A_LoopFileName)
        if (video_number != "" && video_number = gallery_number)
        {
            matched_videos.Push(A_LoopFileFullPath)
        }
    }

    sortPathArray(matched_videos)
    return matched_videos.Length() > 0 ? matched_videos[1] : ""
}

/* Return the first integer from only the final file or folder name.
   Directory paths never inherit numbers from their parents, and video extensions are excluded.
*/
getFirstIntegerFromName(path_or_name)
{
    comparable_path := Trim(path_or_name, " `t`r`n""")
    comparable_path := RTrim(comparable_path, "\/")

    if (comparable_path = "")
    {
        return ""
    }

    SplitPath, comparable_path, leaf_name,, leaf_extension, leaf_name_without_extension

    if (leaf_name = "")
    {
        leaf_name := comparable_path
    }

    if (InStr(FileExist(comparable_path), "D"))
    {
        comparable_name := leaf_name
    }
    else if (leaf_extension != "")
    {
        comparable_name := leaf_name_without_extension
    }
    else
    {
        comparable_name := leaf_name
    }

    if (RegExMatch(comparable_name, "\d+", found_number))
    {
        return found_number + 0
    }

    return ""
}

/* Write metadata for one prepared gallery.
   Stores both navigation levels and the number of images.
*/
writeMetaFile(slot_prefix, parent_folder, gallery_folder, image_count, video_file := "")
{
    meta_file := slot_prefix . ".meta.ini"
    FileDelete, %meta_file%
    IniWrite, %parent_folder%, %meta_file%, slideshow, parent
    IniWrite, %gallery_folder%, %meta_file%, slideshow, gallery
    IniWrite, %image_count%, %meta_file%, slideshow, count
    IniWrite, %video_file%, %meta_file%, slideshow, video
    IniWrite, %A_Now%, %meta_file%, slideshow, created
}

/* Write a worker error marker.
   The controller reads this without blocking the active slideshow.
*/
writeWorkerError(slot_prefix, error_message)
{
    error_file := slot_prefix . ".error.txt"
    FileDelete, %error_file%
    FileAppend, %error_message%, %error_file%
}

; =====================================================================
; SLOT HELPERS
; =====================================================================

/* Delete all generated files for one preparation slot.
   Slot prefixes do not include file extensions.
*/
cleanupSlot(slot_prefix)
{
    FileDelete, % slot_prefix . ".ready"
    FileDelete, % slot_prefix . ".error.txt"
    FileDelete, % slot_prefix . ".list.txt"
    FileDelete, % slot_prefix . ".list.tmp"
    FileDelete, % slot_prefix . ".meta.ini"
}

/* Test whether a slot completed successfully.
   Ready is valid only when list and metadata files also exist.
*/
slotIsReady(slot_prefix)
{
    return FileExist(slot_prefix . ".ready") && FileExist(slot_prefix . ".list.txt") && FileExist(slot_prefix . ".meta.ini")
}

/* Test whether a worker reported an error.
   Error slots can be rebuilt without stopping the current slideshow.
*/
slotHasError(slot_prefix)
{
    return FileExist(slot_prefix . ".error.txt")
}

/* Read the text written by a failed worker.
   Returns a fallback when the error marker is missing.
*/
readErrorMessage(slot_prefix)
{
    error_file := slot_prefix . ".error.txt"
    if (!FileExist(error_file))
    {
        return "Unknown error."
    }

    FileRead, error_message, %error_file%
    return error_message
}

/* Read one metadata value from a preparation slot.
   Metadata remains human-readable for troubleshooting.
*/
readMetaValue(slot_prefix, key_name)
{
    meta_file := slot_prefix . ".meta.ini"
    IniRead, value, %meta_file%, slideshow, %key_name%,
    return value
}

; =====================================================================
; DETECTION AND UTILITY FUNCTIONS
; =====================================================================

/* Load or select the IrfanView executable.
   Browses when the INI path is missing or invalid, then saves the selection.
*/
configureIrfanViewPath()
{
    global SETTINGS_INI

    IniRead, saved_irfanview_path, %SETTINGS_INI%, IrfanView, ExePath,
    saved_irfanview_path := Trim(saved_irfanview_path, " `t`r`n""")

    if (saved_irfanview_path != "" && FileExist(saved_irfanview_path))
    {
        return saved_irfanview_path
    }

    Loop
    {
        FileSelectFile, selected_path, 3,, Select IrfanView executable, Executable files (*.exe)

        if (ErrorLevel || selected_path = "")
        {
            return ""
        }

        SplitPath, selected_path, selected_name
        selected_name_lower := toLowerText(selected_name)

        if ((selected_name_lower = "i_view64.exe" || selected_name_lower = "i_view32.exe") && FileExist(selected_path))
        {
            IniWrite, %selected_path%, %SETTINGS_INI%, IrfanView, ExePath
            return selected_path
        }

        MsgBox, 48, Random IrfanView Gallery, Select i_view64.exe or i_view32.exe.
    }
}

/* Detect the IrfanView executable.
   Checks registry and common installation or portable locations.
*/
detectIrfanView()
{
    RegRead, app_path_64, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\i_view64.exe
    if (!ErrorLevel && app_path_64 != "" && FileExist(app_path_64))
    {
        return app_path_64
    }

    RegRead, app_path_32, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\i_view32.exe
    if (!ErrorLevel && app_path_32 != "" && FileExist(app_path_32))
    {
        return app_path_32
    }

    EnvGet, program_files_x86, ProgramFiles(x86)
    candidates := []
    candidates.Push(A_ProgramFiles . "\IrfanView\i_view64.exe")
    candidates.Push(A_ProgramFiles . "\IrfanView\i_view32.exe")

    if (program_files_x86 != "")
    {
        candidates.Push(program_files_x86 . "\IrfanView\i_view64.exe")
        candidates.Push(program_files_x86 . "\IrfanView\i_view32.exe")
    }

    candidates.Push(A_ScriptDir . "\i_view64.exe")
    candidates.Push(A_ScriptDir . "\i_view32.exe")

    for candidate_index, candidate_path in candidates
    {
        if (FileExist(candidate_path))
        {
            return candidate_path
        }
    }

    return ""
}


/* Open the paired video in VLC.
   When VLC is closed a new instance is launched; when VLC exists its window state is copied to the replacement instance.
*/
sendPairedVideoToVlc(video_file)
{
    if (video_file = "" || !FileExist(video_file))
    {
        return false
    }

    WinGet, old_vlc_window_id, ID, ahk_exe vlc.exe

    if (old_vlc_window_id = "")
    {
        vlc_exe_path := configureVlcPath()

        if (vlc_exe_path = "")
        {
            return false
        }

        return launchVideoInNewVlcInstance(vlc_exe_path, video_file)
    }

    WinGet, old_vlc_pid, PID, ahk_id %old_vlc_window_id%
    WinGet, vlc_exe_path, ProcessPath, ahk_id %old_vlc_window_id%

    if (old_vlc_pid = "" || vlc_exe_path = "" || !FileExist(vlc_exe_path))
    {
        vlc_exe_path := configureVlcPath()

        if (vlc_exe_path = "")
        {
            return false
        }

        return launchVideoInNewVlcInstance(vlc_exe_path, video_file)
    }

    saveVlcExecutablePath(vlc_exe_path)

    old_vlc_state := getVlcWindowState(old_vlc_window_id)
    if (!IsObject(old_vlc_state))
    {
        return launchVideoInNewVlcInstance(vlc_exe_path, video_file)
    }

    command_line := quotePath(vlc_exe_path) . " --no-one-instance --no-fullscreen " . quotePath(video_file)
    Run, %command_line%,, UseErrorLevel, new_vlc_pid

    if (ErrorLevel || new_vlc_pid = "")
    {
        return false
    }

    if (!waitForProcessStart(new_vlc_pid, 5000))
    {
        return false
    }

    if (new_vlc_pid = old_vlc_pid)
    {
        return false
    }

    new_vlc_window_id := waitForWindowByPid(new_vlc_pid, 8000)
    if (new_vlc_window_id = "")
    {
        return false
    }

    if (!applyVlcWindowState(new_vlc_window_id, old_vlc_state))
    {
        return false
    }

    if (!closeOldVlcInstance(old_vlc_window_id, old_vlc_pid))
    {
        return false
    }

    return enterVlcFullscreen(new_vlc_window_id)
}

/* Launch a matched video when no VLC window currently exists.
   The process is forced into a separate VLC instance and confirmed before success.
*/
launchVideoInNewVlcInstance(vlc_exe_path, video_file)
{
    if (vlc_exe_path = "" || !FileExist(vlc_exe_path))
    {
        return false
    }

    if (video_file = "" || !FileExist(video_file))
    {
        return false
    }

    command_line := quotePath(vlc_exe_path) . " --no-one-instance --no-fullscreen " . quotePath(video_file)
    Run, %command_line%,, UseErrorLevel, new_vlc_pid

    if (ErrorLevel || new_vlc_pid = "")
    {
        return false
    }

    if (!waitForProcessStart(new_vlc_pid, 5000))
    {
        return false
    }

    new_vlc_window_id := waitForWindowByPid(new_vlc_pid, 8000)

    if (new_vlc_window_id = "")
    {
        return false
    }

    return enterVlcFullscreen(new_vlc_window_id)
}

/* Put one VLC window into fullscreen.
   The F key is sent only when fullscreen is not already active.
*/
enterVlcFullscreen(vlc_window_id)
{
    if (vlc_window_id = "" || !WinExist("ahk_id " . vlc_window_id))
    {
        return false
    }

    WinRestore, ahk_id %vlc_window_id%
    WinActivate, ahk_id %vlc_window_id%
    WinWaitActive, ahk_id %vlc_window_id%,, 3

    if (ErrorLevel)
    {
        return false
    }

    WinGetPos, window_x, window_y, window_width, window_height, ahk_id %vlc_window_id%
    WinGet, min_max_state, MinMax, ahk_id %vlc_window_id%

    if (!isWindowFullscreen(vlc_window_id, window_x, window_y, window_width, window_height, min_max_state))
    {
        Sleep, 200
        SendInput, f
        Sleep, 500
    }

    return true
}

/* Resolve VLC from the saved path, registry, or standard install folders.
   A file browser is shown only when VLC cannot be discovered automatically.
*/
configureVlcPath()
{
    global SETTINGS_INI

    vlc_exe_path := findInstalledVlcExecutable()

    if (vlc_exe_path != "")
    {
        saveVlcExecutablePath(vlc_exe_path)
        return vlc_exe_path
    }

    FileSelectFile, selected_vlc_path, 3,, Select VLC executable, VLC executable (vlc.exe)

    if (ErrorLevel || selected_vlc_path = "")
    {
        return ""
    }

    selected_vlc_path := Trim(selected_vlc_path, " `t`r`n""")
    SplitPath, selected_vlc_path, selected_vlc_name

    if (!FileExist(selected_vlc_path) || toLowerText(selected_vlc_name) != "vlc.exe")
    {
        MsgBox, 48, Gallery Manager, Select VLC's vlc.exe file.
        return ""
    }

    saveVlcExecutablePath(selected_vlc_path)
    return selected_vlc_path
}

/* Locate an installed VLC executable without requiring a running VLC window.
   Saved INI, registry install directories, and both Program Files roots are checked.
*/
findInstalledVlcExecutable()
{
    global SETTINGS_INI

    IniRead, saved_vlc_path, %SETTINGS_INI%, VLC, ExePath,
    saved_vlc_path := Trim(saved_vlc_path, " `t`r`n""")

    if (saved_vlc_path != "" && FileExist(saved_vlc_path))
    {
        return saved_vlc_path
    }

    registry_keys := []
    registry_keys.Push("HKEY_LOCAL_MACHINE\SOFTWARE\VideoLAN\VLC")
    registry_keys.Push("HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VideoLAN\VLC")
    registry_keys.Push("HKEY_CURRENT_USER\SOFTWARE\VideoLAN\VLC")

    for registry_index, registry_key in registry_keys
    {
        RegRead, vlc_install_directory, %registry_key%, InstallDir

        if (!ErrorLevel && vlc_install_directory != "")
        {
            candidate_path := normalizeFolderPath(vlc_install_directory) . "\vlc.exe"

            if (FileExist(candidate_path))
            {
                return candidate_path
            }
        }
    }

    candidate_paths := []
    candidate_paths.Push(A_ProgramFiles . "\VideoLAN\VLC\vlc.exe")

    EnvGet, program_files_x86, ProgramFiles(x86)
    if (program_files_x86 != "")
    {
        candidate_paths.Push(normalizeFolderPath(program_files_x86) . "\VideoLAN\VLC\vlc.exe")
    }

    EnvGet, program_files_64, ProgramW6432
    if (program_files_64 != "")
    {
        candidate_paths.Push(normalizeFolderPath(program_files_64) . "\VideoLAN\VLC\vlc.exe")
    }

    candidate_paths.Push(A_ScriptDir . "\vlc.exe")

    for candidate_index, candidate_path in candidate_paths
    {
        if (FileExist(candidate_path))
        {
            return candidate_path
        }
    }

    return ""
}

/* Persist a valid VLC executable path.
   Future video launches therefore work even when VLC is initially closed.
*/
saveVlcExecutablePath(vlc_exe_path)
{
    global SETTINGS_INI

    if (vlc_exe_path = "" || !FileExist(vlc_exe_path))
    {
        return false
    }

    IniWrite, %vlc_exe_path%, %SETTINGS_INI%, VLC, ExePath
    return true
}

/* Read VLC window geometry and presentation state.
   Fullscreen is detected against the complete monitor rectangle rather than its work area.
*/
getVlcWindowState(vlc_window_id)
{
    if (vlc_window_id = "" || !WinExist("ahk_id " . vlc_window_id))
    {
        return ""
    }

    WinGetPos, window_x, window_y, window_width, window_height, ahk_id %vlc_window_id%
    WinGet, min_max_state, MinMax, ahk_id %vlc_window_id%

    if (window_width = "" || window_height = "")
    {
        return ""
    }

    window_state := {}
    window_state.min_max := min_max_state
    window_state.is_fullscreen := isWindowFullscreen(vlc_window_id, window_x, window_y, window_width, window_height, min_max_state)

    if (getMonitorBoundsForWindow(vlc_window_id, monitor_left, monitor_top, monitor_right, monitor_bottom))
    {
        window_state.monitor_left := monitor_left
        window_state.monitor_top := monitor_top
        window_state.monitor_right := monitor_right
        window_state.monitor_bottom := monitor_bottom
    }
    else
    {
        window_state.monitor_left := window_x
        window_state.monitor_top := window_y
        window_state.monitor_right := window_x + window_width
        window_state.monitor_bottom := window_y + window_height
    }

    if (!window_state.is_fullscreen && getWindowPlacementRect(vlc_window_id, normal_left, normal_top, normal_right, normal_bottom))
    {
        window_state.x := normal_left
        window_state.y := normal_top
        window_state.width := normal_right - normal_left
        window_state.height := normal_bottom - normal_top
    }
    else
    {
        window_state.x := window_x
        window_state.y := window_y
        window_state.width := window_width
        window_state.height := window_height
    }

    return window_state
}

/* Get the normal restored window rectangle.
   This preserves useful geometry even when the old VLC window is minimized or maximized.
*/
getWindowPlacementRect(window_id, ByRef normal_left, ByRef normal_top, ByRef normal_right, ByRef normal_bottom)
{
    VarSetCapacity(window_placement, 44, 0)
    NumPut(44, window_placement, 0, "UInt")

    if (!DllCall("GetWindowPlacement", "Ptr", window_id, "Ptr", &window_placement))
    {
        return false
    }

    normal_left := NumGet(window_placement, 28, "Int")
    normal_top := NumGet(window_placement, 32, "Int")
    normal_right := NumGet(window_placement, 36, "Int")
    normal_bottom := NumGet(window_placement, 40, "Int")
    return (normal_right > normal_left && normal_bottom > normal_top)
}

/* Test whether a window covers its complete monitor.
   A small tolerance handles invisible resize borders and mixed DPI rounding.
*/
isWindowFullscreen(window_id, window_x, window_y, window_width, window_height, min_max_state)
{
    if (min_max_state != 0)
    {
        return false
    }

    if (!getMonitorBoundsForWindow(window_id, monitor_left, monitor_top, monitor_right, monitor_bottom))
    {
        return false
    }

    WinGet, window_style, Style, ahk_id %window_id%
    has_caption := (window_style & 0xC00000) != 0
    tolerance := 8
    monitor_width := monitor_right - monitor_left
    monitor_height := monitor_bottom - monitor_top

    return (!has_caption
        && Abs(window_x - monitor_left) <= tolerance
        && Abs(window_y - monitor_top) <= tolerance
        && Abs(window_width - monitor_width) <= tolerance
        && Abs(window_height - monitor_height) <= tolerance)
}

/* Get the full rectangle of the monitor containing a window.
   Uses MonitorFromWindow so multi-monitor layouts and negative coordinates are supported.
*/
getMonitorBoundsForWindow(window_id, ByRef monitor_left, ByRef monitor_top, ByRef monitor_right, ByRef monitor_bottom)
{
    monitor_handle := DllCall("MonitorFromWindow", "Ptr", window_id, "UInt", 2, "Ptr")
    if (!monitor_handle)
    {
        return false
    }

    VarSetCapacity(monitor_info, 40, 0)
    NumPut(40, monitor_info, 0, "UInt")

    if (!DllCall("GetMonitorInfo", "Ptr", monitor_handle, "Ptr", &monitor_info))
    {
        return false
    }

    monitor_left := NumGet(monitor_info, 4, "Int")
    monitor_top := NumGet(monitor_info, 8, "Int")
    monitor_right := NumGet(monitor_info, 12, "Int")
    monitor_bottom := NumGet(monitor_info, 16, "Int")
    return true
}

/* Wait for the main visible window belonging to a new VLC process.
   Process creation can complete before VLC creates its video window.
*/
waitForWindowByPid(process_id, timeout_ms)
{
    start_tick := A_TickCount

    while ((A_TickCount - start_tick) < timeout_ms)
    {
        WinGet, window_id, ID, ahk_pid %process_id%
        if (window_id != "")
        {
            return window_id
        }

        if (!processExists(process_id))
        {
            return ""
        }

        Sleep, 50
    }

    return ""
}

/* Apply a captured VLC window state to the new instance.
   Fullscreen is entered after moving the new window onto the old window's monitor.
*/
applyVlcWindowState(vlc_window_id, window_state)
{
    if (vlc_window_id = "" || !IsObject(window_state) || !WinExist("ahk_id " . vlc_window_id))
    {
        return false
    }

    if (window_state.is_fullscreen)
    {
        monitor_width := window_state.monitor_right - window_state.monitor_left
        monitor_height := window_state.monitor_bottom - window_state.monitor_top
        restore_width := monitor_width > 1000 ? 1000 : monitor_width - 100
        restore_height := monitor_height > 700 ? 700 : monitor_height - 100

        if (restore_width < 320)
        {
            restore_width := 320
        }

        if (restore_height < 240)
        {
            restore_height := 240
        }

        restore_x := window_state.monitor_left + ((monitor_width - restore_width) // 2)
        restore_y := window_state.monitor_top + ((monitor_height - restore_height) // 2)

        WinRestore, ahk_id %vlc_window_id%
        WinMove, ahk_id %vlc_window_id%,, %restore_x%, %restore_y%, %restore_width%, %restore_height%
        Sleep, 150
        ControlSend,, f, ahk_id %vlc_window_id%
        Sleep, 400
        return true
    }

    WinRestore, ahk_id %vlc_window_id%
    WinMove, ahk_id %vlc_window_id%,, % window_state.x, % window_state.y, % window_state.width, % window_state.height

    if (window_state.min_max = 1)
    {
        WinMaximize, ahk_id %vlc_window_id%
    }
    else if (window_state.min_max = -1)
    {
        WinMinimize, ahk_id %vlc_window_id%
    }

    return true
}

/* Wait until a newly launched process exists.
   Returns false when the timeout expires before the process appears.
*/
waitForProcessStart(process_id, timeout_ms)
{
    start_tick := A_TickCount

    while ((A_TickCount - start_tick) < timeout_ms)
    {
        if (processExists(process_id))
        {
            return true
        }

        Sleep, 50
    }

    return false
}

/* Close the VLC instance that existed before the replacement launch.
   Graceful window close is attempted before forced process termination.
*/
closeOldVlcInstance(vlc_window_id, vlc_process_id)
{
    if (vlc_process_id = "")
    {
        return false
    }

    if (vlc_window_id != "" && WinExist("ahk_id " . vlc_window_id))
    {
        WinClose, ahk_id %vlc_window_id%
        Process, WaitClose, %vlc_process_id%, 2
    }

    if (processExists(vlc_process_id))
    {
        Process, Close, %vlc_process_id%
        Process, WaitClose, %vlc_process_id%, 1
    }

    return !processExists(vlc_process_id)
}

/* Return true only when an IrfanView window is active.
   Escape is intercepted so IrfanView cannot close the manager indirectly.
*/
isIrfanViewWindowActive()
{
    WinGet, active_process_name, ProcessName, A
    active_process_name := toLowerText(active_process_name)

    return (active_process_name = "i_view64.exe"
        || active_process_name = "i_view32.exe")
}

/* Return true when the active window belongs to IrfanView or VLC.
   Tab navigation hotkeys remain inactive in every other application.
*/
isGalleryNavigationActive()
{
    WinGet, active_process_name, ProcessName, A
    active_process_name := toLowerText(active_process_name)

    return (active_process_name = "i_view64.exe"
        || active_process_name = "i_view32.exe"
        || active_process_name = "vlc.exe")
}

/* Test the active-window navigation condition.
   Activate IrfanView or VLC during the countdown to verify the hotkey scope.
*/
testGalleryNavigationContext()
{
    ToolTip, Activate IrfanView or VLC now.`nTesting in 3 seconds...
    Sleep, 3000
    ToolTip

    WinGet, active_process_name, ProcessName, A
    navigation_is_active := isGalleryNavigationActive()

    result_text := "Active process: " . active_process_name . "`n`n"
    result_text .= "Tab and Ctrl+Tab navigation: "
    result_text .= navigation_is_active ? "ENABLED" : "DISABLED"

    if (navigation_is_active)
    {
        MsgBox, 64, Navigation Context Test, %result_text%
    }
    else
    {
        MsgBox, 48, Navigation Context Test, %result_text%
    }

    return navigation_is_active
}

/* Test whether a process id is still running.
   Used for IrfanView, controller, and worker cleanup.
*/
processExists(process_id)
{
    if (process_id = "")
    {
        return false
    }

    Process, Exist, %process_id%
    return ErrorLevel != 0
}

/* Normalize one folder path.
   Removes trailing slashes except for a drive root.
*/
normalizeFolderPath(folder_path)
{
    folder_path := Trim(folder_path, " `t`r`n")

    while (StrLen(folder_path) > 3)
    {
        last_char := SubStr(folder_path, 0)
        if (last_char != "\" && last_char != "/")
        {
            break
        }

        folder_path := SubStr(folder_path, 1, StrLen(folder_path) - 1)
    }

    if (SubStr(folder_path, 2, 2) = ":")
    {
        if (StrLen(folder_path) = 2)
        {
            folder_path .= "\"
        }
    }

    return folder_path
}

/* Build the IrfanView command for a prepared gallery list.
   /filelist loads the list as input without starting automatic slideshow playback.
*/
buildIrfanViewCommand(irfanview_exe, list_path, additional_arguments := "")
{
    command_line := quotePath(irfanview_exe) . " /filelist=" . quotePath(list_path)

    if (additional_arguments != "")
    {
        command_line .= " " . additional_arguments
    }

    return command_line
}

/* Quote one command-line argument.
   Required for executable and folder paths containing spaces.
*/
quotePath(path_text)
{
    return """" . path_text . """"
}

/* Build a supported-extension lookup map.
   Input uses comma-delimited extensions without leading dots.
*/
buildExtensionMap(extensions_text)
{
    ext_map := {}

    Loop, Parse, extensions_text, `,
    {
        ext := toLowerText(Trim(A_LoopField))
        ext := RegExReplace(ext, "^\.")

        if (ext != "")
        {
            ext_map[ext] := true
        }
    }

    return ext_map
}

/* Build an excluded folder-name lookup map.
   Input uses a pipe character as delimiter.
*/
buildExcludedNameMap(excluded_names_text)
{
    excluded_map := {}

    Loop, Parse, excluded_names_text, |
    {
        folder_name := toLowerText(Trim(A_LoopField))
        if (folder_name != "")
        {
            excluded_map[folder_name] := true
        }
    }

    return excluded_map
}

/* Test whether a file has a supported image extension.
   File content is not opened or decoded during scanning.
*/
isImageFile(file_path, ext_map)
{
    SplitPath, file_path,,, file_ext
    file_ext := toLowerText(file_ext)
    return ext_map.HasKey(file_ext)
}

/* Convert text to lowercase.
   Wraps the AHK v1 StringLower command for expression use.
*/
toLowerText(text)
{
    StringLower, lower_text, text
    return lower_text
}

/* Show the gallery-opened tray notification.
   No other script operation creates a tray notification.
*/
showTrayTip(title, message, seconds := 1)
{
    TrayTip, %title%, %message%, %seconds%, 1
}

; =====================================================================
; TEST CODE
; =====================================================================

/* Run a temporary gallery-structure self-test.
   Verifies A-Z structure, selected-gallery lists, next-gallery, and next-parent generation.
*/
runSelfTest()
{
    global IMAGE_EXTENSIONS, LIST_ENCODING, EXCLUDED_FOLDER_NAMES

    test_root := A_Temp . "\random-main-folder-irfanview-test-" . A_Now
    FileCreateDir, % test_root . "\A\Parent A\1 Gallery 1080"
    FileCreateDir, % test_root . "\A\Parent A\2 Gallery 2160"
    FileCreateDir, % test_root . "\B\Parent B\1 Gallery"
    FileCreateDir, % test_root . "\B\Parent B\2 Gallery\nested"

    FileAppend, fake, % test_root . "\A\Parent A\folder.jpg"
    FileAppend, fake, % test_root . "\A\Parent A\1 video 2160.mp4"
    FileAppend, fake, % test_root . "\A\Parent A\2 video 1080.wmv"
    FileAppend, fake, % test_root . "\A\Parent A\0000 1080 decoy 1.mp4"
    FileAppend, fake, % test_root . "\A\Parent A\0000 2160 decoy 2.wmv"
    FileAppend, fake, % test_root . "\B\Parent B\clip 1.wmv"
    FileAppend, fake, % test_root . "\B\Parent B\clip 2.mp4"
    FileAppend, fake, % test_root . "\A\Parent A\1 Gallery 1080\a1.jpg"
    FileAppend, fake, % test_root . "\A\Parent A\2 Gallery 2160\a2.png"
    FileAppend, fake, % test_root . "\B\Parent B\1 Gallery\b1.webp"
    FileAppend, fake, % test_root . "\B\Parent B\2 Gallery\b2.jpg"
    FileAppend, fake, % test_root . "\B\Parent B\2 Gallery\nested\ignored.jpg"

    first_prefix := test_root . "\first"
    workerBuildSelection("first", test_root, first_prefix, "", "", IMAGE_EXTENSIONS, LIST_ENCODING, EXCLUDED_FOLDER_NAMES)

    if (!slotIsReady(first_prefix))
    {
        MsgBox, 16, Random IrfanView Gallery Self Test, % "FAIL: first selection`n`n" . readErrorMessage(first_prefix)
        return
    }

    first_parent := readMetaValue(first_prefix, "parent")
    first_gallery := readMetaValue(first_prefix, "gallery")
    first_video := readMetaValue(first_prefix, "video")

    FileRead, first_list_text, % first_prefix . ".list.txt"
    if (InStr(first_list_text, "\Parent A\folder.jpg") || InStr(first_list_text, "1 video 2160.mp4") || InStr(first_list_text, "2 video 1080.wmv"))
    {
        MsgBox, 16, Random IrfanView Gallery Self Test, FAIL: a file directly inside the parent folder was included.
        return
    }

    if (first_video = "")
    {
        MsgBox, 16, Random IrfanView Gallery Self Test, FAIL: paired parent-level video was not detected.
        return
    }

    pairing_test_gallery := test_root . "\A\Parent A\1 Gallery 1080"
    pairing_test_video := findPairedVideo(test_root . "\A\Parent A", pairing_test_gallery)
    SplitPath, pairing_test_video, pairing_test_name

    if (pairing_test_name != "1 video 2160.mp4")
    {
        MsgBox, 16, Random IrfanView Gallery Self Test, % "FAIL: pairing did not use only the first integer.`n`nMatched:`n" . pairing_test_video
        return
    }

    test_command := buildIrfanViewCommand("C:\Tools\IrfanView\i_view64.exe", "C:\Temp\gallery.list.txt")
    if (!InStr(test_command, " /filelist=") || InStr(test_command, "/slideshow=") || InStr(test_command, "/reloadonloop"))
    {
        MsgBox, 16, Random IrfanView Gallery Self Test, % "FAIL: IrfanView command can start automatic slideshow playback.`n`n" . test_command
        return
    }

    gallery_prefix := test_root . "\gallery"
    workerBuildSelection("gallery", test_root, gallery_prefix, first_parent, first_gallery, IMAGE_EXTENSIONS, LIST_ENCODING, EXCLUDED_FOLDER_NAMES)

    parent_prefix := test_root . "\parent"
    workerBuildSelection("parent", test_root, parent_prefix, first_parent, first_gallery, IMAGE_EXTENSIONS, LIST_ENCODING, EXCLUDED_FOLDER_NAMES)

    if (slotIsReady(gallery_prefix) && slotIsReady(parent_prefix))
    {
        result_text := "PASS"
        result_text .= "`n`nFirst parent:`n" . first_parent
        result_text .= "`n`nFirst gallery:`n" . first_gallery
        result_text .= "`n`nPaired video:`n" . first_video
        result_text .= "`n`nFirst-integer pairing test:`n" . pairing_test_video
        result_text .= "`n`nIrfanView mode:`n/filelist (automatic playback disabled)"
        result_text .= "`n`nNext gallery worker:`n" . readMetaValue(gallery_prefix, "gallery")
        result_text .= "`n`nNext parent worker:`n" . readMetaValue(parent_prefix, "parent")
        result_text .= "`n`nFirst gallery in next parent:`n" . readMetaValue(parent_prefix, "gallery")
        MsgBox, 64, Random IrfanView Gallery Self Test, %result_text%
    }
    else
    {
        MsgBox, 16, Random IrfanView Gallery Self Test, FAIL: navigation worker did not create both slots.
    }
}
