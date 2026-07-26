#NoEnv
#Persistent
#SingleInstance Off
SetBatchLines, -1
ListLines, Off
SendMode, Input
SetWorkingDir, %A_ScriptDir%

; Gallery-Slideshow-Manager-Bridge.ahk
; AutoHotkey v1.1.36 native bridge for the HTML tile interface.
; Handles IrfanView, VLC, global navigation, dynamic lists, and background preparation.

SCRIPT_VERSION := "0.52"
APP_NAME := "Gallery-Slideshow-Manager"
DATA_DIR := A_Temp . "\" . APP_NAME
SETTINGS_INI := DATA_DIR . "\" . APP_NAME . ".ini"
SCRIPT_ICON := A_ScriptDir . "\" . APP_NAME . ".ico"
COMMAND_FILE := DATA_DIR . "\" . APP_NAME . "-command.ini"
SESSION_INI := DATA_DIR . "\" . APP_NAME . "-session.ini"
FILTERED_NAVIGATION_INI := DATA_DIR . "\" . APP_NAME . "-filtered-navigation.ini"
MANAGER_AWARE_ASSISTANT := DATA_DIR . "\slideshow-assistant-manager-aware.ahk"
RESIDENT_PID_FILE := DATA_DIR . "\" . APP_NAME . "-bridge.pid"
CURRENT_PREFIX := DATA_DIR . "\" . APP_NAME . "-current"
NEXT_GALLERY_PREFIX := DATA_DIR . "\" . APP_NAME . "-next-gallery"
NEXT_PARENT_PREFIX := DATA_DIR . "\" . APP_NAME . "-next-parent"
PREVIOUS_PARENT_PREFIX := DATA_DIR . "\" . APP_NAME . "-previous-parent"
PARENT_PREVIEW_PREFIX := DATA_DIR . "\" . APP_NAME . "-parent-preview"

IMAGE_EXTENSIONS := "jpg,jpeg,png,gif,bmp,tif,tiff,webp,heic,jfif"
EXCLUDED_FOLDER_NAMES := "_DELETE|_CROP|_DUPLICATES|_SMALL"
LIST_ENCODING := "CP0"

root_folder := ""
irfanview_exe := ""
vlc_exe := ""
auto_vlc_enabled := true
current_parent := ""
current_gallery := ""
current_irfan_pid := ""
current_video := ""
last_command_id := ""
script_is_exiting := false
switching_slideshow := false
automatic_enter_in_progress := false
irfan_keyword_menu_map := {}
manager_window_id := ""
manager_monitor_index := 0
manager_monitor_signature := ""
parent_preview_active := false
parent_preview_gallery := ""
parent_preview_parent := ""
parent_preview_window_id := ""
parent_preview_bitmap_handle := 0
parent_preview_timeout_ms := 4000
temporary_vlc_mute_active := false
temporary_vlc_mute_window_id := ""
temporary_vlc_mute_pid := ""
temporary_vlc_mute_duration_ms := 10000
random_navigation_active := false
random_unique_active := false
random_unique_seen := []
random_unique_parent_seen := []
random_gallery_history := []
random_gallery_history_limit := 12
takeover_existing_bridge := false
open_manager_on_start := A_Args.Length() < 1

if (A_Args.Length() >= 1)
{
    first_arg := A_Args[1]

    if (InStr(first_arg, "--claim-manager=") = 1)
    {
        manager_claim_token := SubStr(first_arg, StrLen("--claim-manager=") + 1)
        claimSingleManagerWindow(manager_claim_token)
        ExitApp
    }
    else if (first_arg = "--resident")
    {
        open_manager_on_start := false
        takeover_existing_bridge := A_Args.Length() >= 2 && A_Args[2] = "--takeover"
    }
    else if (first_arg = "--prepare")
    {
        slot_prefix := A_Args.Length() >= 2 ? A_Args[2] : ""
        gallery_path := A_Args.Length() >= 3 ? A_Args[3] : ""
        prepareGallerySlot(slot_prefix, gallery_path)
        ExitApp
    }
    else if (first_arg = "--thumbnails")
    {
        thumbnail_queue_path := A_Args.Length() >= 2 ? A_Args[2] : ""
        thumbnail_done_path := A_Args.Length() >= 3 ? A_Args[3] : ""
        runThumbnailBatch(thumbnail_queue_path, thumbnail_done_path)
        ExitApp
    }
    else if (first_arg = "--self-test")
    {
        runSelfTest()
        ExitApp
    }
}

initializeResidentBridge()
return

#If isGalleryNavigationActive()
$^0::
    assignCurrentParentRating(0)
    KeyWait, 0
return

$^1::
    assignCurrentParentRating(1)
    KeyWait, 1
return

$^2::
    assignCurrentParentRating(2)
    KeyWait, 2
return

$^3::
    assignCurrentParentRating(3)
    KeyWait, 3
return

$^4::
    assignCurrentParentRating(4)
    KeyWait, 4
return

$^5::
    assignCurrentParentRating(5)
    KeyWait, 5
return

$^6::
    assignCurrentParentRating(6)
    KeyWait, 6
return

$^7::
    assignCurrentParentRating(7)
    KeyWait, 7
return

$^8::
    assignCurrentParentRating(8)
    KeyWait, 8
return

$^9::
    assignCurrentParentRating(9)
    KeyWait, 9
return

$+Tab::
    requestPreparedSwitch("previousparent")
    KeyWait, Tab
return

$Tab::
    if (parent_preview_active)
    {
        advanceParentPreview()
    }
    else
    {
        requestPreparedSwitch("gallery")
    }
    KeyWait, Tab
return

$^Tab::
    if (parent_preview_active)
    {
        commitParentPreview("confirmed")
    }
    else
    {
        beginParentPreview()
    }
    KeyWait, Tab
return
#If

#If isGalleryNavigationActive() && parent_preview_active
$Esc::
    stopParentPreview(true)
    KeyWait, Esc
return
#If

#If isIrfanViewActive()
$Enter::
    if (!automatic_enter_in_progress)
    {
        closeCurrentSlideshowOnEnter()
    }
    KeyWait, Enter
return

$RButton::
    KeyWait, RButton
    showCurrentParentKeywordMenu()
return

$Esc::
    KeyWait, Esc
    confirmExitBridge()
return
#If

pollCommandTimer:
    pollCommandFile()
return

monitorIrfanViewTimer:
    monitorManagedIrfanView()
return

monitorManagerWindowTimer:
    monitorManagerWindowPlacement()
return

parentPreviewTimeoutTimer:
    commitParentPreview("timeout")
return

vlcAutoUnmuteTimer:
    restoreTemporaryVlcSound()
return

trayShowManager:
    launchHtmlManager()
return

trayNextGallery:
    requestPreparedSwitch("gallery")
return

trayNextParent:
    requestPreparedSwitch("parent")
return

trayExit:
    confirmExitBridge()
return

irfanKeywordMenuHandler:
    handleCurrentParentKeywordMenuItem(A_ThisMenuItem)
return

irfanKeywordMenuNoOp:
return

handleBridgeExit:
    script_is_exiting := true
    SetTimer, pollCommandTimer, Off
    SetTimer, monitorIrfanViewTimer, Off
    SetTimer, monitorManagerWindowTimer, Off
    SetTimer, parentPreviewTimeoutTimer, Off
    SetTimer, vlcAutoUnmuteTimer, Off

    restoreTemporaryVlcSound()
    stopParentPreview(true)
    closeManagedIrfanView()
    clearRunningSessionState()

    FileDelete, %RESIDENT_PID_FILE%
    FileDelete, %COMMAND_FILE%
    FileDelete, %MANAGER_AWARE_ASSISTANT%
ExitApp


/*
Keep exactly one Gallery Slideshow Manager HTA window.
Every claim selects one survivor, closes all duplicates, restores the
normal title, and activates the surviving manager.
*/
claimSingleManagerWindow(manager_claim_token)
{
    global SCRIPT_VERSION

    manager_claim_token := Trim(manager_claim_token)

    if (manager_claim_token = "")
    {
        return false
    }

    claim_fragment := "[" . manager_claim_token . "]"
    claimant_window_id := ""
    deadline_tick := A_TickCount + 4000

    Loop
    {
        WinGet, manager_window_list, List, Gallery Slideshow Manager ahk_exe mshta.exe

        Loop, %manager_window_list%
        {
            candidate_window_id := manager_window_list%A_Index%
            WinGetTitle, candidate_title, ahk_id %candidate_window_id%

            if (InStr(candidate_title, claim_fragment))
            {
                claimant_window_id := candidate_window_id
                break
            }
        }

        if (claimant_window_id != "" || A_TickCount >= deadline_tick)
        {
            break
        }

        Sleep, 100
    }

    if (claimant_window_id = "")
    {
        return false
    }

    WinGet, manager_window_list, List, Gallery Slideshow Manager ahk_exe mshta.exe

    Loop, %manager_window_list%
    {
        manager_window_id := manager_window_list%A_Index%

        if (manager_window_id != claimant_window_id)
        {
            WinClose, ahk_id %manager_window_id%
        }
    }

    final_title := "Gallery Slideshow Manager " . SCRIPT_VERSION
    WinSetTitle, ahk_id %claimant_window_id%,, %final_title%
    WinShow, ahk_id %claimant_window_id%
    WinActivate, ahk_id %claimant_window_id%
    return true
}

/*
Create shared temporary storage and migrate the newest legacy settings INI.
*/
initializeSharedDataStorage()
{
    global DATA_DIR, SETTINGS_INI

    if (!InStr(FileExist(DATA_DIR), "D"))
    {
        FileCreateDir, %DATA_DIR%
    }

    if (!InStr(FileExist(DATA_DIR), "D"))
    {
        return false
    }

    if (!FileExist(SETTINGS_INI))
    {
        legacy_settings_path := findNewestLegacySettingsFile()

        if (legacy_settings_path != "")
        {
            FileCopy, %legacy_settings_path%, %SETTINGS_INI%, 0
        }
    }

    return true
}

/*
Find the newest settings INI in the current or sibling version directory.
*/
findNewestLegacySettingsFile()
{
    global APP_NAME, SETTINGS_INI

    newest_path := ""
    newest_modified := ""

    direct_path := A_ScriptDir . "\" . APP_NAME . ".ini"
    considerLegacySettingsFile(direct_path, newest_path, newest_modified)

    SplitPath, A_ScriptDir,, versions_parent

    if (versions_parent != "" && InStr(FileExist(versions_parent), "D"))
    {
        Loop, Files, % versions_parent . "\Gallery-Slideshow-Manager-HTML_*", D
        {
            candidate_path := A_LoopFileFullPath . "\" . APP_NAME . ".ini"
            considerLegacySettingsFile(candidate_path, newest_path, newest_modified)
        }

        Loop, Files, % versions_parent . "\Gallery-Slideshow-Manager-HTML-*", D
        {
            candidate_path := A_LoopFileFullPath . "\" . APP_NAME . ".ini"
            considerLegacySettingsFile(candidate_path, newest_path, newest_modified)
        }
    }

    if (toLowerText(newest_path) = toLowerText(SETTINGS_INI))
    {
        return ""
    }

    return newest_path
}

/*
Update the newest legacy settings candidate.
*/
considerLegacySettingsFile(candidate_path, ByRef newest_path, ByRef newest_modified)
{
    if (!FileExist(candidate_path))
    {
        return false
    }

    FileGetTime, candidate_modified, %candidate_path%, M

    if (newest_path = "" || candidate_modified > newest_modified)
    {
        newest_path := candidate_path
        newest_modified := candidate_modified
    }

    return true
}

/*
Generate cached JPEG previews through one PowerShell batch process.
System.Drawing handles common formats; IrfanView is the fallback converter.
*/
runThumbnailBatch(queue_path, done_path)
{
    global irfanview_exe

    if (!initializeSharedDataStorage())
    {
        writeThumbnailDoneFile(done_path, 0, 0, 0, "Shared data directory unavailable.")
        return false
    }

    loadSettings()
    ensureIrfanViewPathSilent()

    worker_script := A_ScriptDir . "\Gallery-Slideshow-Manager-Thumbnails.ps1"

    if (queue_path = "" || done_path = "" || !FileExist(queue_path))
    {
        writeThumbnailDoneFile(done_path, 0, 0, 0, "Thumbnail queue is missing.")
        return false
    }

    if (!FileExist(worker_script))
    {
        writeThumbnailDoneFile(done_path, 0, 0, 0, "Thumbnail PowerShell worker is missing.")
        return false
    }

    powershell_exe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"

    if (!FileExist(powershell_exe))
    {
        powershell_exe := "powershell.exe"
    }

    command_line := quotePath(powershell_exe)
    command_line .= " -NoProfile -NonInteractive -ExecutionPolicy Bypass"
    command_line .= " -File " . quotePath(worker_script)
    command_line .= " -QueuePath " . quotePath(queue_path)
    command_line .= " -DonePath " . quotePath(done_path)
    command_line .= " -IrfanViewPath " . quotePath(irfanview_exe)

    RunWait, %command_line%, %A_ScriptDir%, Hide UseErrorLevel

    if (!FileExist(done_path))
    {
        writeThumbnailDoneFile(done_path, 0, 0, 0, "Thumbnail worker did not create a result file.")
        return false
    }

    return !ErrorLevel
}

/*
Locate IrfanView without showing a file-selection dialog.
*/
ensureIrfanViewPathSilent()
{
    global irfanview_exe, SETTINGS_INI

    if (irfanview_exe != "" && FileExist(irfanview_exe))
    {
        return true
    }

    candidates := []
    candidates.Push(A_ProgramFiles . "\IrfanView\i_view64.exe")
    candidates.Push(A_ProgramFiles . "\IrfanView\i_view32.exe")

    EnvGet, program_files_x86, ProgramFiles(x86)

    if (program_files_x86 != "")
    {
        candidates.Push(program_files_x86 . "\IrfanView\i_view32.exe")
        candidates.Push(program_files_x86 . "\IrfanView\i_view64.exe")
    }

    candidates.Push(A_ScriptDir . "\i_view64.exe")
    candidates.Push(A_ScriptDir . "\i_view32.exe")

    for candidate_index, candidate_path in candidates
    {
        if (FileExist(candidate_path))
        {
            irfanview_exe := candidate_path
            IniWrite, %irfanview_exe%, %SETTINGS_INI%, IrfanView, ExePath
            return true
        }
    }

    irfanview_exe := ""
    return false
}

/*
Write a minimal result INI if the external worker cannot start.
*/
writeThumbnailDoneFile(done_path, created_count, skipped_count, failed_count, error_text := "")
{
    if (done_path = "")
    {
        return false
    }

    FileDelete, %done_path%

    IniWrite, %created_count%, %done_path%, Thumbnails, Created
    IniWrite, %skipped_count%, %done_path%, Thumbnails, Skipped
    IniWrite, %failed_count%, %done_path%, Thumbnails, Failed
    writeIniValueOrDelete(error_text, done_path, "Thumbnails", "Error")
    return true
}

/*
Initialize the resident bridge and shared command channel.
The HTA starts this source file with --resident --takeover, so an older
resident bridge from any prior package is terminated before 0.51 runs.
*/
initializeResidentBridge()
{
    global RESIDENT_PID_FILE, SCRIPT_ICON
    global open_manager_on_start
    global takeover_existing_bridge

    if (!initializeSharedDataStorage())
    {
        MsgBox, 16, Gallery Slideshow Manager, The shared temporary-data folder could not be created.
        ExitApp
    }

    current_pid := DllCall("GetCurrentProcessId")
    random_seed := A_TickCount ^ current_pid
    Random,, %random_seed%

    if (FileExist(RESIDENT_PID_FILE))
    {
        FileRead, old_pid_text, %RESIDENT_PID_FILE%
        old_pid := Trim(old_pid_text)

        if (old_pid != "" && old_pid != current_pid && processExists(old_pid))
        {
            if (takeover_existing_bridge)
            {
                Process, Close, %old_pid%
                Process, WaitClose, %old_pid%, 4
                Sleep, 150

                if (processExists(old_pid))
                {
                    MsgBox, 16, Gallery Slideshow Manager, The older Gallery Slideshow Manager bridge could not be replaced.`n`nClose it from the system tray and start version %SCRIPT_VERSION% again.
                    ExitApp
                }
            }
            else
            {
                if (open_manager_on_start)
                {
                    launchHtmlManager()
                }

                ExitApp
            }
        }
    }

    FileDelete, %RESIDENT_PID_FILE%
    FileAppend, %current_pid%, %RESIDENT_PID_FILE%

    OnExit, handleBridgeExit
    loadSettings()
    readSessionState()
    setupTrayMenu()

    SetTimer, pollCommandTimer, 250
    SetTimer, monitorIrfanViewTimer, 500
    SetTimer, monitorManagerWindowTimer, 500

    if (open_manager_on_start)
    {
        launchHtmlManager()
    }
}

/*
Configure tray commands and the shared application icon.
*/
setupTrayMenu()
{
    global SCRIPT_VERSION, SCRIPT_ICON

    Menu, Tray, NoStandard

    if (FileExist(SCRIPT_ICON))
    {
        Menu, Tray, Icon, %SCRIPT_ICON%, 1, 1
    }

    Menu, Tray, Tip, % "Gallery Slideshow Manager HTML Bridge " . SCRIPT_VERSION
    Menu, Tray, Add, Show manager, trayShowManager
    Menu, Tray, Add
    Menu, Tray, Add, Next gallery, trayNextGallery
    Menu, Tray, Add, Next parent, trayNextParent
    Menu, Tray, Add
    Menu, Tray, Add, Exit, trayExit
    Menu, Tray, Default, Show manager
}

/*
Assign a zero-to-nine star rating to the current slideshow parent.
Ctrl+0 clears the rating.
*/
assignCurrentParentRating(rating_value)
{
    global root_folder, current_parent, current_gallery, SESSION_INI

    loadSettings()

    if (current_parent = "" && current_gallery != "")
    {
        SplitPath, current_gallery,, derived_parent
        current_parent := normalizeFolderPath(derived_parent)
    }

    if (root_folder = "" || current_parent = "")
    {
        showTrayTip("Rating", "No current parent gallery is available.", 2)
        return false
    }

    rating_value += 0

    if (rating_value < 0)
    {
        rating_value := 0
    }
    else if (rating_value > 9)
    {
        rating_value := 9
    }

    rating_ini := root_folder . "\gallery-ratings.ini"
    parent_section := encodeParentKeywordSection(current_parent)

    if (rating_value = 0)
    {
        IniDelete, %rating_ini%, %parent_section%, Rating
    }
    else
    {
        IniWrite, %rating_value%, %rating_ini%, %parent_section%, Rating
    }

    if (ErrorLevel)
    {
        showTrayTip("Rating error", "The parent rating could not be saved.", 3)
        return false
    }

    rating_revision := A_NowUTC . "-" . A_TickCount
    IniWrite, %rating_revision%, %SESSION_INI%, Session, RatingRevision
    writeIniValueOrDelete(rating_value . "", SESSION_INI, "Session", "CurrentParentRating")

    SplitPath, current_parent, parent_name

    if (rating_value = 0)
    {
        rating_message := "Rating cleared"
    }
    else if (rating_value = 1)
    {
        rating_message := "1 star"
    }
    else
    {
        rating_message := rating_value . " stars"
    }

    showTrayTip("Parent rating", rating_message . "`n" . parent_name, 1)
    return true
}

/*
Read the saved zero-to-nine star rating for one parent gallery.
*/
getSavedParentRating(parent_folder)
{
    global root_folder

    if (root_folder = "")
    {
        loadSettings()
    }

    if (root_folder = "" || parent_folder = "")
    {
        return 0
    }

    rating_ini := root_folder . "\gallery-ratings.ini"
    parent_section := encodeParentKeywordSection(parent_folder)
    IniRead, rating_value, %rating_ini%, %parent_section%, Rating, 0
    rating_value += 0

    if (rating_value < 0 || rating_value > 9)
    {
        rating_value := 0
    }

    return rating_value
}

/*
Build only the number of filled stars assigned to the parent.
*/
buildParentRatingStars(rating_value)
{
    rating_value += 0

    if (rating_value < 0)
    {
        rating_value := 0
    }
    else if (rating_value > 9)
    {
        rating_value := 9
    }

    star_text := ""

    Loop, %rating_value%
    {
        star_text .= "★"
    }

    return star_text
}

/*
Show the same parent-keyword assignment menu while IrfanView is active.
Checked words are already assigned to the current slideshow parent.
*/
showCurrentParentKeywordMenu()
{
    global root_folder, current_parent, current_gallery
    global irfan_keyword_menu_map

    loadSettings()

    if (current_parent = "" && current_gallery != "")
    {
        SplitPath, current_gallery,, derived_parent
        current_parent := normalizeFolderPath(derived_parent)
    }

    if (root_folder = "" || !InStr(FileExist(root_folder), "D"))
    {
        showTrayTip("Keyword menu", "The galleries root folder is unavailable.", 3)
        return false
    }

    if (current_parent = "" || !InStr(FileExist(current_parent), "D"))
    {
        showTrayTip("Keyword menu", "No current slideshow parent is available.", 3)
        return false
    }

    keyword_ini := root_folder . "\gallery-keywords.ini"
    IniRead, keyword_text, %keyword_ini%, Keywords, List,
    keyword_list := parsePipeKeywordList(keyword_text)

    parent_section := encodeParentKeywordSection(current_parent)
    IniRead, assigned_text, %keyword_ini%, %parent_section%, Keywords,
    assigned_keywords := parsePipeKeywordList(assigned_text)
    assigned_map := buildKeywordMap(assigned_keywords)

    Menu, IrfanKeywordMenu, UseErrorLevel
    Menu, IrfanKeywordMenu, DeleteAll
    irfan_keyword_menu_map := {}

    parent_rating := getSavedParentRating(current_parent)
    rating_stars := buildParentRatingStars(parent_rating)
    rating_item := parent_rating > 0 ? "Rating: " . rating_stars : "Rating: 0★"

    Menu, IrfanKeywordMenu, Add, %rating_item%, irfanKeywordMenuNoOp
    Menu, IrfanKeywordMenu, Disable, %rating_item%
    Menu, IrfanKeywordMenu, Add

    if (keyword_list.Length() < 1)
    {
        empty_item := "No keywords defined"
        Menu, IrfanKeywordMenu, Add, %empty_item%, irfanKeywordMenuNoOp
        Menu, IrfanKeywordMenu, Disable, %empty_item%
    }
    else
    {
        keyword_groups := groupKeywordsByPatternNative(keyword_list)
        added_group_count := 0

        for group_index, keyword_group in keyword_groups
        {
            if (keyword_group.Length() < 1)
            {
                continue
            }

            if (added_group_count > 0)
            {
                Menu, IrfanKeywordMenu, Add
            }

            for keyword_index, keyword_name in keyword_group
            {
                menu_item_name := escapeMenuItemText(keyword_name)

                ; A_ThisMenuItem can contain either form.
                irfan_keyword_menu_map[menu_item_name] := keyword_name
                irfan_keyword_menu_map[keyword_name] := keyword_name

                Menu, IrfanKeywordMenu, Add, %menu_item_name%, irfanKeywordMenuHandler

                if (assigned_map.HasKey(toLowerText(keyword_name)))
                {
                    Menu, IrfanKeywordMenu, Check, %menu_item_name%
                }
            }

            added_group_count++
        }
    }

    Menu, IrfanKeywordMenu, Show
    return true
}

/*
Resolve the clicked menu item and toggle its parent assignment.
*/
handleCurrentParentKeywordMenuItem(menu_item_name)
{
    global irfan_keyword_menu_map

    if (!irfan_keyword_menu_map.HasKey(menu_item_name))
    {
        return false
    }

    keyword_name := irfan_keyword_menu_map[menu_item_name]
    return toggleKeywordForCurrentParent(keyword_name)
}

/*
Toggle one keyword on the current slideshow parent.
The revision value tells an open HTML UI to refresh its badges and cache.
*/
toggleKeywordForCurrentParent(keyword_name)
{
    global root_folder, current_parent, SESSION_INI

    keyword_name := Trim(keyword_name)

    if (keyword_name = "" || root_folder = "" || current_parent = "")
    {
        return false
    }

    keyword_ini := root_folder . "\gallery-keywords.ini"
    parent_section := encodeParentKeywordSection(current_parent)

    IniRead, assigned_text, %keyword_ini%, %parent_section%, Keywords,
    assigned_keywords := parsePipeKeywordList(assigned_text)
    keyword_key := toLowerText(keyword_name)
    updated_keywords := []
    keyword_was_assigned := false

    for assigned_index, assigned_keyword_name in assigned_keywords
    {
        if (toLowerText(assigned_keyword_name) = keyword_key)
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

    if (updated_keywords.Length() < 1)
    {
        IniDelete, %keyword_ini%, %parent_section%
    }
    else
    {
        updated_text := joinPipeKeywordList(updated_keywords)
        IniWrite, %updated_text%, %keyword_ini%, %parent_section%, Keywords
    }

    if (ErrorLevel)
    {
        showTrayTip("Keyword error", "The parent assignment could not be saved.", 3)
        return false
    }

    keyword_revision := A_NowUTC . "-" . A_TickCount
    IniWrite, %keyword_revision%, %SESSION_INI%, Session, KeywordRevision

    SplitPath, current_parent, parent_name
    action_text := keyword_was_assigned ? "Removed" : "Assigned"
    showTrayTip(action_text . " keyword", keyword_name . "`n" . parent_name, 1)
    return true
}

/*
Read, de-duplicate, and alphabetically sort a pipe-delimited keyword list.
*/
parsePipeKeywordList(keyword_text)
{
    parsed_keywords := []
    seen_keywords := {}

    Loop, Parse, keyword_text, |
    {
        keyword_name := Trim(A_LoopField)
        keyword_key := toLowerText(keyword_name)

        if (keyword_name = "" || seen_keywords.HasKey(keyword_key))
        {
            continue
        }

        seen_keywords[keyword_key] := true
        parsed_keywords.Push(keyword_name)
    }

    return parsed_keywords
}

/*
Return true when one character has uppercase/lowercase forms.
*/
isCasedKeywordCharacterNative(character)
{
    if (character = "")
    {
        return false
    }

    StringUpper, upper_character, character
    StringLower, lower_character, character
    return upper_character != lower_character
}

/*
Return true when text contains at least one cased character.
*/
keywordHasCasedCharacterNative(keyword_text)
{
    Loop, Parse, keyword_text
    {
        if (isCasedKeywordCharacterNative(A_LoopField))
        {
            return true
        }
    }

    return false
}

/*
Return the first cased character in text.
*/
firstCasedKeywordCharacterNative(keyword_text)
{
    Loop, Parse, keyword_text
    {
        if (isCasedKeywordCharacterNative(A_LoopField))
        {
            return A_LoopField
        }
    }

    return ""
}

/*
Classify text as uppercase, capital, lowercase, or other.
*/
getKeywordCasePatternNative(keyword_text)
{
    if (keywordHasCasedCharacterNative(keyword_text))
    {
        StringUpper, upper_text, keyword_text
        StringLower, lower_text, keyword_text

        if (keyword_text = upper_text)
        {
            return "uppercase"
        }

        if (keyword_text = lower_text)
        {
            return "lowercase"
        }
    }

    first_letter := firstCasedKeywordCharacterNative(keyword_text)

    if (first_letter != "")
    {
        StringUpper, upper_first_letter, first_letter

        if (first_letter = upper_first_letter)
        {
            return "capital"
        }
    }

    return "other"
}

/*
Classify one keyword by special prefix and capitalization.
*/
getKeywordFormattingNative(keyword_name, ByRef is_special, ByRef special_character, ByRef case_pattern)
{
    first_character := SubStr(keyword_name, 1, 1)
    is_special := first_character != "" && !isCasedKeywordCharacterNative(first_character) && !RegExMatch(first_character, "^\d$")

    if (is_special)
    {
        special_character := first_character
        case_text := SubStr(keyword_name, 2)
    }
    else
    {
        special_character := ""
        case_text := keyword_name
    }

    case_pattern := getKeywordCasePatternNative(case_text)
    return true
}

/*
Build groups in pattern order while preserving source order inside each group.
*/
groupKeywordsByPatternNative(keyword_list)
{
    pattern_order := ["uppercase", "capital", "lowercase", "other"]
    special_groups := {}
    special_character_order := {}
    plain_groups := {}

    for pattern_index, pattern_name in pattern_order
    {
        special_groups[pattern_name] := {}
        special_character_order[pattern_name] := []
        plain_groups[pattern_name] := []
    }

    for keyword_index, keyword_name in keyword_list
    {
        getKeywordFormattingNative(keyword_name, is_special, special_character, case_pattern)

        if (is_special)
        {
            pattern_groups := special_groups[case_pattern]
            character_order := special_character_order[case_pattern]

            if (!pattern_groups.HasKey(special_character))
            {
                pattern_groups[special_character] := []
                character_order.Push(special_character)
            }

            pattern_groups[special_character].Push(keyword_name)
        }
        else
        {
            plain_groups[case_pattern].Push(keyword_name)
        }
    }

    grouped_keywords := []

    ; Special-prefix UPPERCASE, Capital, lowercase, Other.
    for pattern_index, pattern_name in pattern_order
    {
        pattern_groups := special_groups[pattern_name]
        character_order := special_character_order[pattern_name]

        for character_index, special_character in character_order
        {
            keyword_group := pattern_groups[special_character]
            sortKeywordArray(keyword_group)
            grouped_keywords.Push(keyword_group)
        }
    }

    ; Plain UPPERCASE, Capital, lowercase, Other.
    for pattern_index, pattern_name in pattern_order
    {
        if (plain_groups[pattern_name].Length() > 0)
        {
            keyword_group := plain_groups[pattern_name]
            sortKeywordArray(keyword_group)
            grouped_keywords.Push(keyword_group)
        }
    }

    return grouped_keywords
}

/*
Join one keyword array for gallery-keywords.ini.
*/
joinPipeKeywordList(keyword_list)
{
    keyword_text := ""

    for keyword_index, keyword_name in keyword_list
    {
        if (keyword_text != "")
        {
            keyword_text .= "|"
        }

        keyword_text .= keyword_name
    }

    return keyword_text
}

/*
Build a lowercase lookup map from one keyword array.
*/
buildKeywordMap(keyword_list)
{
    keyword_map := {}

    for keyword_index, keyword_name in keyword_list
    {
        keyword_map[toLowerText(keyword_name)] := true
    }

    return keyword_map
}

/*
Sort an AutoHotkey v1 array alphabetically, case-insensitively.
*/
sortKeywordArray(ByRef keyword_list)
{
    keyword_count := keyword_list.Length()

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
            left_index := A_Index
            right_index := left_index + 1
            left_keyword := keyword_list[left_index]
            right_keyword := keyword_list[right_index]

            left_key := toLowerText(left_keyword)
            right_key := toLowerText(right_keyword)
            should_swap := left_key > right_key
            should_swap := should_swap || (left_key = right_key && left_keyword > right_keyword)

            if (should_swap)
            {
                keyword_list[left_index] := right_keyword
                keyword_list[right_index] := left_keyword
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

/*
Encode the parent section exactly like the HTML interface.
*/
encodeParentKeywordSection(parent_folder)
{
    global root_folder

    normalized_root := normalizeFolderPath(root_folder)
    normalized_parent := normalizeFolderPath(parent_folder)
    relative_parent := normalized_parent
    root_prefix := normalized_root . "\"

    if (normalized_root != ""
        && SubStr(toLowerText(normalized_parent), 1, StrLen(root_prefix)) = toLowerText(root_prefix))
    {
        relative_parent := SubStr(normalized_parent, StrLen(root_prefix) + 1)
    }

    encoded_parent := StrReplace(relative_parent, "%", "%25")
    encoded_parent := StrReplace(encoded_parent, "\", "%5C")
    encoded_parent := StrReplace(encoded_parent, "/", "%2F")
    encoded_parent := StrReplace(encoded_parent, "[", "%5B")
    encoded_parent := StrReplace(encoded_parent, "]", "%5D")
    return "Parent." . encoded_parent
}

/*
Escape ampersands so Windows menus show literal keyword text.
*/
escapeMenuItemText(keyword_name)
{
    return StrReplace(keyword_name, "&", "&&")
}

/*
Open the HTML tile manager beside this bridge script.
*/
launchHtmlManager()
{
    existing_manager_id := findGalleryManagerWindow()

    if (existing_manager_id != "")
    {
        WinShow, ahk_id %existing_manager_id%
        WinActivate, ahk_id %existing_manager_id%
        return true
    }

    manager_path := A_ScriptDir . "\Gallery-Slideshow-Manager.hta"

    if (!FileExist(manager_path))
    {
        MsgBox, 16, Gallery Slideshow Manager, % "Missing HTML manager:`n`n" . manager_path
        return false
    }

    Run, % quotePath(manager_path), %A_ScriptDir%, UseErrorLevel
    return !ErrorLevel
}

/*
Read executable paths, root folder, and Auto VLC state.
*/
loadSettings()
{
    global SETTINGS_INI, root_folder, irfanview_exe, vlc_exe, auto_vlc_enabled

    IniRead, root_folder, %SETTINGS_INI%, Galleries, RootPath,
    IniRead, irfanview_exe, %SETTINGS_INI%, IrfanView, ExePath,
    IniRead, vlc_exe, %SETTINGS_INI%, VLC, ExePath,
    IniRead, auto_vlc_value, %SETTINGS_INI%, Options, AutoVlc, 1

    root_folder := normalizeFolderPath(root_folder)
    irfanview_exe := Trim(irfanview_exe, " `t`r`n""")
    vlc_exe := Trim(vlc_exe, " `t`r`n""")
    auto_vlc_enabled := auto_vlc_value ? true : false
}

/*
Poll the atomic command file written by the HTML application.
*/
pollCommandFile()
{
    global COMMAND_FILE, last_command_id, script_is_exiting

    if (script_is_exiting || !FileExist(COMMAND_FILE))
    {
        return
    }

    IniRead, command_id, %COMMAND_FILE%, Command, Id,
    IniRead, command_action, %COMMAND_FILE%, Command, Action,
    IniRead, command_path, %COMMAND_FILE%, Command, Path,

    if (command_id = "ERROR" || command_id = "" || command_id = last_command_id)
    {
        return
    }

    last_command_id := command_id
    command_action := toLowerText(Trim(command_action))
    command_path := normalizeFolderPath(command_path)

    if (command_action = "startrandomunique")
    {
        setRandomNavigationMode(true, true)
        startGallery(command_path)
    }
    else if (command_action = "startrandom")
    {
        setRandomNavigationMode(true, false)
        startGallery(command_path)
    }
    else if (command_action = "start")
    {
        setRandomNavigationMode(false, false)
        startGallery(command_path)
    }
    else if (command_action = "uniqueon")
    {
        setRandomUniqueMode(true)
    }
    else if (command_action = "uniqueoff")
    {
        setRandomUniqueMode(false)
    }
    else if (command_action = "nextgallery")
    {
        requestPreparedSwitch("gallery")
    }
    else if (command_action = "nextparent")
    {
        requestPreparedSwitch("parent")
    }
    else if (command_action = "previousparent")
    {
        requestPreparedSwitch("previousparent")
    }
    else if (command_action = "refreshnavigation")
    {
        refreshPreparedNavigationSlots()
    }
    else if (command_action = "exit")
    {
        confirmExitBridge()
    }
}

/*
Start one gallery, creating only its direct image list.
*/
startGallery(gallery_path)
{
    global switching_slideshow, CURRENT_PREFIX

    gallery_path := normalizeFolderPath(gallery_path)

    if (gallery_path = "" || !InStr(FileExist(gallery_path), "D"))
    {
        showTrayTip("Gallery error", "Gallery folder does not exist.", 3)
        return false
    }

    switching_slideshow := true
    saveAndCloseCurrentIrfanView()

    if (!prepareGallerySlot(CURRENT_PREFIX, gallery_path))
    {
        switching_slideshow := false
        showTrayTip("Gallery error", "No supported images were found.", 3)
        return false
    }

    launch_result := launchPreparedSlot(CURRENT_PREFIX)
    switching_slideshow := false
    return launch_result
}

/*
Build a file list and metadata for one gallery slot.
*/
prepareGallerySlot(slot_prefix, gallery_path)
{
    global IMAGE_EXTENSIONS, LIST_ENCODING

    slot_prefix := Trim(slot_prefix)
    gallery_path := normalizeFolderPath(gallery_path)

    if (slot_prefix = "" || gallery_path = "" || !InStr(FileExist(gallery_path), "D"))
    {
        return false
    }

    cleanupSlot(slot_prefix)

    image_paths := getDirectImagePaths(gallery_path)

    if (image_paths.Length() < 1)
    {
        return false
    }

    list_path := slot_prefix . ".list.txt"
    list_file := FileOpen(list_path, "w", LIST_ENCODING)

    if (!IsObject(list_file))
    {
        return false
    }

    for image_index, image_path in image_paths
    {
        list_file.WriteLine(image_path)
    }

    list_file.Close()

    SplitPath, gallery_path,, parent_folder
    video_path := findPairedVideo(parent_folder, gallery_path)
    meta_path := slot_prefix . ".meta.ini"

    image_count := image_paths.Length()

    IniWrite, %gallery_path%, %meta_path%, Gallery, Path
    IniWrite, %parent_folder%, %meta_path%, Gallery, Parent
    IniWrite, %image_count%, %meta_path%, Gallery, Count
    writeIniValueOrDelete(video_path, meta_path, "Gallery", "Video")

    FileAppend,, % slot_prefix . ".ready"
    return true
}

/*
Launch one prepared slot and prepare the two following navigation slots.
*/
launchPreparedSlot(slot_prefix)
{
    global root_folder, current_parent, current_gallery
    global current_video, switching_slideshow, auto_vlc_enabled

    ready_path := slot_prefix . ".ready"
    list_path := slot_prefix . ".list.txt"
    meta_path := slot_prefix . ".meta.ini"

    if (!FileExist(ready_path) || !FileExist(list_path) || !FileExist(meta_path))
    {
        return false
    }

    IniRead, gallery_path, %meta_path%, Gallery, Path,
    IniRead, parent_folder, %meta_path%, Gallery, Parent,
    IniRead, image_count, %meta_path%, Gallery, Count, 0
    IniRead, video_path, %meta_path%, Gallery, Video,

    loadSettings()

    if (!ensureIrfanViewPath())
    {
        return false
    }

    saveAndCloseCurrentIrfanView()

    if (!launchIrfanViewList(list_path))
    {
        return false
    }

    current_gallery := normalizeFolderPath(gallery_path)
    current_parent := normalizeFolderPath(parent_folder)
    current_video := video_path
    recordRandomGalleryVisit(current_gallery)

    if (auto_vlc_enabled && video_path != "" && FileExist(video_path))
    {
        sendVideoToVlc(video_path)
        activateCurrentIrfanView()
    }

    writeSessionState(image_count)
    prepareNextNavigationSlots()

    showTrayTip("Gallery opened", image_count . " images`n" . current_gallery, 1)
    return true
}

/*
Launch the current list in IrfanView and enter fullscreen.
*/
launchIrfanViewList(list_path)
{
    global irfanview_exe, current_irfan_pid, root_folder
    global automatic_enter_in_progress

    command_line := quotePath(irfanview_exe) . " /filelist=" . quotePath(list_path)
    working_folder := root_folder != "" ? root_folder : A_ScriptDir

    Run, %command_line%, %working_folder%, UseErrorLevel, new_pid

    if (ErrorLevel || new_pid = "")
    {
        return false
    }

    current_irfan_pid := new_pid
    irfanview_query := "ahk_pid " . current_irfan_pid

    WinWait, %irfanview_query%,, 6

    if (ErrorLevel)
    {
        return false
    }

    WinGet, irfanview_window_id, ID, %irfanview_query%

    if (irfanview_window_id = "")
    {
        return false
    }

    launchSlideshowAssistant(current_irfan_pid)
    restoreWindowPlacement(irfanview_window_id, "IrfanViewWindow")
    WinActivate, ahk_id %irfanview_window_id%
    WinWaitActive, ahk_id %irfanview_window_id%,, 3
    Sleep, 250

    automatic_enter_in_progress := true
    SendInput, {Enter}
    automatic_enter_in_progress := false
    return true
}

/*
Return true when one slideshow assistant contains the parent-preview
navigation functions required by the manager random-mode patch.
*/
isManagerPatchableSlideshowAssistant(script_path)
{
    if (script_path = "" || !FileExist(script_path))
    {
        return false
    }

    script_file := FileOpen(script_path, "r", "UTF-8")

    if (!IsObject(script_file))
    {
        return false
    }

    script_text := script_file.Read()
    script_file.Close()

    return InStr(script_text, "/*  PREVIEW OR CONFIRM THE NEXT PARENT GALLERY") && InStr(script_text, "/*  RATE THE CURRENT OR PREVIEWED PARENT GALLERY") && InStr(script_text, "$^Tab::")
}

/*
Locate the real patchable slideshow assistant.
*/
findSlideshowAssistantPath()
{
    exact_path := A_ScriptDir . "\slideshow-assistant.ahk"
    newest_patchable_path := ""
    newest_patchable_modified := ""
    newest_any_path := ""
    newest_any_modified := ""

    if (FileExist(exact_path) && isManagerPatchableSlideshowAssistant(exact_path))
    {
        return exact_path
    }

    Loop, Files, % A_ScriptDir . "\slideshow-assistant_*.ahk", F
    {
        candidate_path := A_LoopFileFullPath
        FileGetTime, candidate_modified, %candidate_path%, M

        if (newest_any_path = "" || candidate_modified > newest_any_modified)
        {
            newest_any_path := candidate_path
            newest_any_modified := candidate_modified
        }

        if (isManagerPatchableSlideshowAssistant(candidate_path) && (newest_patchable_path = "" || candidate_modified > newest_patchable_modified))
        {
            newest_patchable_path := candidate_path
            newest_patchable_modified := candidate_modified
        }
    }

    if (newest_patchable_path != "")
    {
        return newest_patchable_path
    }

    if (FileExist(exact_path))
    {
        return exact_path
    }

    return newest_any_path
}

/*
Create a temporary manager-aware copy of slideshow-assistant.
Random mode rebuilds and reshuffles parent-preview candidates for
every preview activation. The original assistant is never modified.
*/
prepareManagerAwareSlideshowAssistant(source_path)
{
    global MANAGER_AWARE_ASSISTANT

    if (source_path = "" || !FileExist(source_path) || !isManagerPatchableSlideshowAssistant(source_path))
    {
        return source_path
    }

    source_file := FileOpen(source_path, "r", "UTF-8")

    if (!IsObject(source_file))
    {
        return source_path
    }

    source_text := source_file.Read()
    source_file.Close()
    source_text := StrReplace(source_text, "`r`n", "`n")
    source_text := StrReplace(source_text, "`r", "`n")

    hotkey_start_marker := "/*  PREVIEW OR CONFIRM THE NEXT PARENT GALLERY"
    hotkey_end_marker := "/*  RATE THE CURRENT OR PREVIEWED PARENT GALLERY"
    hotkey_start := InStr(source_text, hotkey_start_marker)
    hotkey_end := InStr(source_text, hotkey_end_marker, false, hotkey_start)

    if (hotkey_start < 1 || hotkey_end <= hotkey_start)
    {
        return source_path
    }

    replacement_text := "; GALLERY MANAGER BRIDGE OWNS TAB / CTRL+TAB NAVIGATION`n`n"
    source_text := SubStr(source_text, 1, hotkey_start - 1) . replacement_text . SubStr(source_text, hotkey_end)
    source_text := StrReplace(source_text, "gallery_preview_timeout_ms := 3000", "gallery_preview_timeout_ms := 4000", timeout_count, 1)
    source_text := StrReplace(source_text, "Auto-open in 3 seconds", "Auto-open in 4 seconds", footer_count, 1)

    FileDelete, %MANAGER_AWARE_ASSISTANT%
    output_file := FileOpen(MANAGER_AWARE_ASSISTANT, "w", "UTF-8")

    if (!IsObject(output_file))
    {
        return source_path
    }

    output_file.Write(source_text)
    output_file.Close()

    return FileExist(MANAGER_AWARE_ASSISTANT) ? MANAGER_AWARE_ASSISTANT : source_path
}

/*
Execute slideshow-assistant after the IrfanView window exists.
It is elevated directly so --bind-pid survives elevation.
*/
launchSlideshowAssistant(irfanview_process_id)
{
    assistant_path := findSlideshowAssistantPath()

    if (assistant_path = "")
    {
        showTrayTip("Slideshow assistant", "slideshow-assistant.ahk was not found beside the manager.", 3)
        return false
    }

    launch_path := prepareManagerAwareSlideshowAssistant(assistant_path)
    SplitPath, launch_path,, assistant_folder

    if (FileExist(A_AhkPath))
    {
        assistant_command := quotePath(A_AhkPath) . " " . quotePath(launch_path)
    }
    else
    {
        assistant_command := quotePath(launch_path)
    }

    if (irfanview_process_id != "")
    {
        assistant_command .= " --bind-pid=" . irfanview_process_id
    }

    Run, *RunAs %assistant_command%, %assistant_folder%, UseErrorLevel

    if (ErrorLevel)
    {
        showTrayTip("Slideshow assistant", "Could not execute:`n" . launch_path, 3)
        return false
    }

    return true
}

/*
Read the authoritative gallery queue created from the active HTML filters.
*/
getFilteredNavigationQueue(ByRef queue_is_valid)
{
    global FILTERED_NAVIGATION_INI

    queue_is_valid := false
    gallery_queue := []

    if (!FileExist(FILTERED_NAVIGATION_INI))
    {
        return gallery_queue
    }

    IniRead, valid_value, %FILTERED_NAVIGATION_INI%, Queue, Valid, 0

    if (valid_value != 1)
    {
        return gallery_queue
    }

    queue_is_valid := true
    IniRead, gallery_count, %FILTERED_NAVIGATION_INI%, Queue, Count, 0
    gallery_count += 0

    Loop, %gallery_count%
    {
        item_key := "Item" . A_Index
        IniRead, gallery_path, %FILTERED_NAVIGATION_INI%, Queue, %item_key%,
        gallery_path := normalizeFolderPath(gallery_path)

        if (gallery_path != "" && InStr(FileExist(gallery_path), "D"))
        {
            gallery_queue.Push(gallery_path)
        }
    }

    return gallery_queue
}

/*
Return the first allowed gallery for every unique allowed parent.
*/
getFilteredParentEntries(ByRef queue_is_valid)
{
    global FILTERED_NAVIGATION_INI

    gallery_queue := getFilteredNavigationQueue(queue_is_valid)
    parent_entries := []
    seen_parents := {}

    if (!queue_is_valid)
    {
        return parent_entries
    }

    IniRead, parent_count, %FILTERED_NAVIGATION_INI%, Queue, ParentCount, 0
    parent_count += 0

    if (parent_count > 0)
    {
        Loop, %parent_count%
        {
            parent_item_key := "ParentItem" . A_Index
            IniRead, parent_folder, %FILTERED_NAVIGATION_INI%, Queue, %parent_item_key%,
            parent_folder := normalizeFolderPath(parent_folder)

            if (parent_folder = "" || !InStr(FileExist(parent_folder), "D"))
            {
                continue
            }

            parent_key := toLowerText(parent_folder)

            if (seen_parents.HasKey(parent_key))
            {
                continue
            }

            first_gallery := ""

            for gallery_index, gallery_path in gallery_queue
            {
                SplitPath, gallery_path,, gallery_parent
                gallery_parent := normalizeFolderPath(gallery_parent)

                if (toLowerText(gallery_parent) = parent_key)
                {
                    first_gallery := gallery_path
                    break
                }
            }

            if (first_gallery != "")
            {
                seen_parents[parent_key] := true
                parent_entry := {parent: parent_folder, gallery: first_gallery}
                parent_entries.Push(parent_entry)
            }
        }

        if (parent_entries.Length() > 0)
        {
            return parent_entries
        }
    }

    for gallery_index, gallery_path in gallery_queue
    {
        SplitPath, gallery_path,, parent_folder
        parent_folder := normalizeFolderPath(parent_folder)
        parent_key := toLowerText(parent_folder)

        if (parent_folder != "" && !seen_parents.HasKey(parent_key))
        {
            seen_parents[parent_key] := true
            parent_entry := {parent: parent_folder, gallery: gallery_path}
            parent_entries.Push(parent_entry)
        }
    }

    return parent_entries
}

/*
Discard prepared destinations after the HTML filters change.
*/
refreshPreparedNavigationSlots()
{
    global current_gallery
    global NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX, PREVIOUS_PARENT_PREFIX

    stopParentPreview(true)
    cleanupSlot(NEXT_GALLERY_PREFIX)
    cleanupSlot(NEXT_PARENT_PREFIX)
    cleanupSlot(PREVIOUS_PARENT_PREFIX)

    if (current_gallery != "")
    {
        prepareNextNavigationSlots()
    }

    return true
}

/*
Validate a prepared worker result against the current filtered destination.
*/
preparedSlotMatchesGallery(slot_prefix, expected_gallery)
{
    expected_gallery := normalizeFolderPath(expected_gallery)

    if (expected_gallery = "" || !FileExist(slot_prefix . ".ready"))
    {
        return false
    }

    meta_path := slot_prefix . ".meta.ini"

    if (!FileExist(meta_path))
    {
        return false
    }

    IniRead, prepared_gallery, %meta_path%, Gallery, Path,
    prepared_gallery := normalizeFolderPath(prepared_gallery)
    return toLowerText(prepared_gallery) = toLowerText(expected_gallery)
}

/*
Prepare the next gallery plus adjacent parent galleries in hidden workers.
*/
prepareNextNavigationSlots()
{
    global current_parent, current_gallery
    global NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX, PREVIOUS_PARENT_PREFIX

    if (isRandomNavigationMode())
    {
        random_next_gallery := getRandomDifferentParentGalleryPath(current_parent)
        startPreparationWorker(NEXT_GALLERY_PREFIX, random_next_gallery)
        startPreparationWorker(NEXT_PARENT_PREFIX, random_next_gallery)
        startPreparationWorker(PREVIOUS_PARENT_PREFIX, random_next_gallery)
        return true
    }

    next_gallery := getNextGalleryPath(current_parent, current_gallery)
    next_parent_gallery := getNextParentGalleryPath(current_parent)
    previous_parent_gallery := getPreviousParentGalleryPath(current_parent)

    startPreparationWorker(NEXT_GALLERY_PREFIX, next_gallery)
    startPreparationWorker(NEXT_PARENT_PREFIX, next_parent_gallery)
    startPreparationWorker(PREVIOUS_PARENT_PREFIX, previous_parent_gallery)
    return true
}

/*
Start a hidden worker which writes one prepared list and metadata slot.
*/
startPreparationWorker(slot_prefix, gallery_path)
{
    cleanupSlot(slot_prefix)

    if (gallery_path = "")
    {
        return false
    }

    if (A_IsCompiled)
    {
        command_line := quotePath(A_ScriptFullPath)
    }
    else
    {
        command_line := quotePath(A_AhkPath) . " " . quotePath(A_ScriptFullPath)
    }

    command_line .= " --prepare " . quotePath(slot_prefix)
    command_line .= " " . quotePath(gallery_path)

    Run, %command_line%,, Hide UseErrorLevel
    return !ErrorLevel
}

/*
Start a three-second preview of the next parent gallery.
The preview is AlwaysOnTop but uses NoActivate, so IrfanView or VLC keeps focus.
*/
beginParentPreview()
{
    global current_parent

    if (current_parent = "")
    {
        showTrayTip("Parent preview", "No current parent gallery is available.", 2)
        return false
    }

    next_gallery := getNextParentGalleryPath(current_parent)

    if (next_gallery = "")
    {
        showTrayTip("Parent preview", "No next parent gallery was found.", 2)
        return false
    }

    return showParentPreview(next_gallery)
}

/*
While the preview is open, plain Tab skips the offered parent and previews
the next parent in the sorted A-Z queue. The timeout restarts each time.
*/
advanceParentPreview()
{
    global parent_preview_active, parent_preview_parent

    if (!parent_preview_active)
    {
        return beginParentPreview()
    }

    next_gallery := getNextParentGalleryPath(parent_preview_parent)

    if (next_gallery = "")
    {
        return false
    }

    return showParentPreview(next_gallery)
}

/*
Display one parent candidate and prepare its first gallery in the background.
*/
showParentPreview(gallery_path)
{
    global parent_preview_active, parent_preview_gallery, parent_preview_parent
    global parent_preview_timeout_ms, PARENT_PREVIEW_PREFIX

    gallery_path := normalizeFolderPath(gallery_path)

    if (gallery_path = "" || !InStr(FileExist(gallery_path), "D"))
    {
        return false
    }

    SplitPath, gallery_path,, parent_folder
    parent_folder := normalizeFolderPath(parent_folder)

    if (parent_folder = "")
    {
        return false
    }

    SetTimer, parentPreviewTimeoutTimer, Off
    cleanupSlot(PARENT_PREVIEW_PREFIX)

    parent_preview_active := true
    parent_preview_gallery := gallery_path
    parent_preview_parent := parent_folder

    startPreparationWorker(PARENT_PREVIEW_PREFIX, gallery_path)
    showParentPreviewWindow(parent_folder, gallery_path)

    SetTimer, parentPreviewTimeoutTimer, % -parent_preview_timeout_ms
    return true
}

/*
Open the currently offered parent immediately, or automatically after timeout.
*/
commitParentPreview(commit_reason := "")
{
    global parent_preview_active, parent_preview_gallery
    global PARENT_PREVIEW_PREFIX, switching_slideshow

    if (!parent_preview_active || parent_preview_gallery = "")
    {
        return false
    }

    gallery_path := parent_preview_gallery
    stopParentPreview(false)

    if (preparedSlotMatchesGallery(PARENT_PREVIEW_PREFIX, gallery_path))
    {
        switching_slideshow := true
        launch_result := launchPreparedSlot(PARENT_PREVIEW_PREFIX)
        switching_slideshow := false
        return launch_result
    }

    return startGallery(gallery_path)
}

/*
Close the preview UI and optionally delete its prepared slot.
*/
stopParentPreview(cleanup_prepared_slot := true)
{
    global parent_preview_active, parent_preview_gallery, parent_preview_parent
    global PARENT_PREVIEW_PREFIX

    SetTimer, parentPreviewTimeoutTimer, Off
    destroyParentPreviewWindow()

    parent_preview_active := false
    parent_preview_gallery := ""
    parent_preview_parent := ""

    if (cleanup_prepared_slot)
    {
        cleanupSlot(PARENT_PREVIEW_PREFIX)
    }

    return true
}

/*
Create a centered preview canvas on the monitor containing the active
IrfanView or VLC window. Missing folder.jpg produces a blank placeholder.
*/
showParentPreviewWindow(parent_folder, gallery_path)
{
    global parent_preview_window_id, parent_preview_bitmap_handle

    destroyParentPreviewWindow()

    active_window_id := WinExist("A")
    monitor_index := getWindowMonitorIndex(active_window_id)

    SysGet, preview_work_area, MonitorWorkArea, %monitor_index%

    work_width := preview_work_areaRight - preview_work_areaLeft
    work_height := preview_work_areaBottom - preview_work_areaTop

    preview_width := work_width - 100
    preview_height := work_height - 100

    if (preview_width > 860)
    {
        preview_width := 860
    }

    if (preview_height > 620)
    {
        preview_height := 620
    }

    if (preview_width < 420)
    {
        preview_width := work_width
    }

    if (preview_height < 320)
    {
        preview_height := work_height
    }

    SplitPath, parent_folder, parent_name
    SplitPath, gallery_path, gallery_name
    parent_rating := getSavedParentRating(parent_folder)
    rating_stars := buildParentRatingStars(parent_rating)

    parent_header_height := 44
    gallery_name_height := 32
    rating_height := parent_rating > 0 ? 38 : 0
    footer_height := 46
    canvas_left := 18
    canvas_top := parent_header_height + gallery_name_height + rating_height
    canvas_width := preview_width - 36
    canvas_height := preview_height - canvas_top - footer_height

    Gui, ParentPreview:New, +AlwaysOnTop -Caption +ToolWindow +Border +Hwndparent_preview_window_id
    Gui, ParentPreview:Color, 101216
    Gui, ParentPreview:Margin, 0, 0

    Gui, ParentPreview:Font, s17 cFFFFFF Bold, Segoe UI
    parent_header_options := "x0 y0 w" . preview_width . " h" . parent_header_height . " Center 0x200"
    Gui, ParentPreview:Add, Text, %parent_header_options%, %parent_name%

    Gui, ParentPreview:Font, s12 cD5DCE8 Norm, Segoe UI
    gallery_name_y := parent_header_height
    gallery_name_options := "x18 y" . gallery_name_y . " w" . (preview_width - 36) . " h" . gallery_name_height . " Center 0x200"
    Gui, ParentPreview:Add, Text, %gallery_name_options%, %gallery_name%

    if (parent_rating > 0)
    {
        Gui, ParentPreview:Font, s21 cFFD34D Bold, Segoe UI Symbol
        rating_y := parent_header_height + gallery_name_height
        rating_options := "x18 y" . rating_y . " w" . (preview_width - 36) . " h" . rating_height . " Center 0x200"
        Gui, ParentPreview:Add, Text, %rating_options%, %rating_stars%
    }

    folder_image := parent_folder . "\folder.jpg"
    image_loaded := false

    if (FileExist(folder_image))
    {
        parent_preview_bitmap_handle := loadScaledPreviewBitmap(folder_image, canvas_width, canvas_height, bitmap_width, bitmap_height)

        if (parent_preview_bitmap_handle)
        {
            image_x := canvas_left + Floor((canvas_width - bitmap_width) / 2)
            image_y := canvas_top + Floor((canvas_height - bitmap_height) / 2)
            picture_options := "x" . image_x . " y" . image_y . " w" . bitmap_width . " h" . bitmap_height . " 0xE hwndpreview_picture_id"
            Gui, ParentPreview:Add, Picture, %picture_options%
            bitmap_value := "HBITMAP:*" . parent_preview_bitmap_handle
            GuiControl, ParentPreview:, %preview_picture_id%, %bitmap_value%
            image_loaded := true
        }
    }

    if (!image_loaded)
    {
        Gui, ParentPreview:Font, s20 c7F8A99 Bold, Segoe UI
        placeholder_options := "x" . canvas_left . " y" . canvas_top . " w" . canvas_width . " h" . canvas_height . " Center 0x200 +Border"
        placeholder_text := gallery_name
        Gui, ParentPreview:Add, Text, %placeholder_options%, %placeholder_text%
    }

    Gui, ParentPreview:Font, s11 cD5DCE8 Norm, Segoe UI
    footer_y := preview_height - footer_height
    footer_options := "x0 y" . footer_y . " w" . preview_width . " h" . footer_height . " Center 0x200"
    footer_text := "Tab: next parent     Ctrl+Tab: open now     Esc: cancel     Auto-open in 4 seconds"
    Gui, ParentPreview:Add, Text, %footer_options%, %footer_text%

    preview_x := preview_work_areaLeft + Floor((work_width - preview_width) / 2)
    preview_y := preview_work_areaTop + Floor((work_height - preview_height) / 2)
    show_options := "x" . preview_x . " y" . preview_y . " w" . preview_width . " h" . preview_height . " NoActivate"
    Gui, ParentPreview:Show, %show_options%, Next parent gallery
    return true
}

/*
Load folder.jpg as a bitmap fitted inside the preview canvas without distortion.
*/
loadScaledPreviewBitmap(image_path, maximum_width, maximum_height, ByRef bitmap_width, ByRef bitmap_height)
{
    bitmap_width := 0
    bitmap_height := 0
    image_type := 0
    load_options := "GDI+ w" . maximum_width . " h-1"
    bitmap_handle := LoadPicture(image_path, load_options, image_type)

    if (!bitmap_handle)
    {
        return 0
    }

    if (!getBitmapDimensions(bitmap_handle, bitmap_width, bitmap_height))
    {
        DllCall("DeleteObject", "Ptr", bitmap_handle)
        return 0
    }

    if (bitmap_height > maximum_height)
    {
        DllCall("DeleteObject", "Ptr", bitmap_handle)
        load_options := "GDI+ w-1 h" . maximum_height
        bitmap_handle := LoadPicture(image_path, load_options, image_type)

        if (!bitmap_handle || !getBitmapDimensions(bitmap_handle, bitmap_width, bitmap_height))
        {
            if (bitmap_handle)
            {
                DllCall("DeleteObject", "Ptr", bitmap_handle)
            }

            return 0
        }
    }

    return bitmap_handle
}

/*
Read width and height from one HBITMAP.
*/
getBitmapDimensions(bitmap_handle, ByRef bitmap_width, ByRef bitmap_height)
{
    bitmap_structure_size := A_PtrSize = 8 ? 32 : 24
    VarSetCapacity(bitmap_structure, bitmap_structure_size, 0)

    if (!DllCall("GetObject", "Ptr", bitmap_handle, "Int", bitmap_structure_size, "Ptr", &bitmap_structure))
    {
        return false
    }

    bitmap_width := NumGet(bitmap_structure, 4, "Int")
    bitmap_height := Abs(NumGet(bitmap_structure, 8, "Int"))
    return bitmap_width > 0 && bitmap_height > 0
}

/*
Destroy the non-activating preview window and release its bitmap.
*/
destroyParentPreviewWindow()
{
    global parent_preview_window_id, parent_preview_bitmap_handle

    Gui, ParentPreview:Destroy
    parent_preview_window_id := ""

    if (parent_preview_bitmap_handle)
    {
        DllCall("DeleteObject", "Ptr", parent_preview_bitmap_handle)
        parent_preview_bitmap_handle := 0
    }

    return true
}

/*
Use a prepared slot, falling back to fresh dynamic preparation when needed.
*/
requestPreparedSwitch(switch_type)
{
    global current_gallery, current_parent, switching_slideshow
    global NEXT_GALLERY_PREFIX, NEXT_PARENT_PREFIX, PREVIOUS_PARENT_PREFIX
    global parent_preview_active

    if (parent_preview_active)
    {
        stopParentPreview(true)
    }

    if (current_gallery = "")
    {
        return false
    }

    if (switch_type = "gallery")
    {
        slot_prefix := NEXT_GALLERY_PREFIX
        fallback_gallery := getNextGalleryPath(current_parent, current_gallery)
    }
    else if (switch_type = "parent")
    {
        slot_prefix := NEXT_PARENT_PREFIX
        fallback_gallery := getNextParentGalleryPath(current_parent)
    }
    else if (switch_type = "previousparent")
    {
        slot_prefix := PREVIOUS_PARENT_PREFIX
        fallback_gallery := getPreviousParentGalleryPath(current_parent)
    }
    else
    {
        return false
    }

    if (isRandomNavigationMode())
    {
        prepared_random_gallery := getPreparedSlotGalleryPath(slot_prefix)

        if (prepared_random_gallery != "")
        {
            fallback_gallery := prepared_random_gallery
        }
    }

    saveAndCloseCurrentIrfanView()

    if (preparedSlotMatchesGallery(slot_prefix, fallback_gallery))
    {
        switching_slideshow := true
        launch_result := launchPreparedSlot(slot_prefix)
        switching_slideshow := false
        return launch_result
    }

    return startGallery(fallback_gallery)
}

/*
Set the authoritative resident-bridge navigation mode.
*/
setRandomNavigationMode(is_active, unique_active := false)
{
    global random_navigation_active
    global random_unique_active
    global random_unique_seen
    global random_unique_parent_seen
    global random_gallery_history

    random_navigation_active := is_active ? true : false
    random_unique_active := random_navigation_active && unique_active
    random_unique_seen := []
    random_unique_parent_seen := []
    random_gallery_history := []
    return true
}

/*
Change Unique mode during an active random slideshow.
The current gallery becomes the first processed item of the new cycle.
*/
setRandomUniqueMode(is_active)
{
    global SESSION_INI
    global random_navigation_active
    global random_unique_active
    global random_unique_seen
    global random_unique_parent_seen
    global current_gallery
    global current_parent

    random_unique_active := random_navigation_active && is_active
    random_unique_seen := []
    random_unique_parent_seen := []

    if (random_unique_active)
    {
        if (current_gallery != "")
        {
            markUniqueRandomGallerySeen(current_gallery)
        }

        if (current_parent != "")
        {
            markUniqueRandomParentSeen(current_parent)
        }
    }

    unique_value := random_unique_active ? 1 : 0
    IniWrite, %unique_value%, %SESSION_INI%, Session, RandomUnique

    unique_seen_text := joinRandomUniquePaths(random_unique_seen)
    writeIniValueOrDelete(unique_seen_text, SESSION_INI, "Session", "RandomUniqueSeen")

    unique_parent_seen_text := joinRandomUniquePaths(random_unique_parent_seen)
    writeIniValueOrDelete(unique_parent_seen_text, SESSION_INI, "Session", "RandomUniqueParentSeen")

    if (current_gallery != "")
    {
        prepareNextNavigationSlots()
    }

    return true
}

/*
Return true when Unique mode is active for the random slideshow.
*/
isUniqueRandomMode()
{
    global random_navigation_active
    global random_unique_active

    return random_navigation_active && random_unique_active
}

/*
Mark one actually opened gallery as processed in the current Unique cycle.
*/
markUniqueRandomGallerySeen(gallery_path)
{
    global random_unique_seen

    gallery_path := normalizeFolderPath(gallery_path)

    if (gallery_path = "")
    {
        return false
    }

    gallery_key := toLowerText(gallery_path)

    for seen_index, seen_path in random_unique_seen
    {
        if (toLowerText(seen_path) = gallery_key)
        {
            return true
        }
    }

    random_unique_seen.Push(gallery_path)
    return true
}

/*
Check whether one gallery was already processed in the Unique cycle.
*/
isUniqueRandomGallerySeen(gallery_path)
{
    global random_unique_seen

    gallery_key := toLowerText(normalizeFolderPath(gallery_path))

    if (gallery_key = "")
    {
        return false
    }

    for seen_index, seen_path in random_unique_seen
    {
        if (toLowerText(seen_path) = gallery_key)
        {
            return true
        }
    }

    return false
}

/*
Start a new Unique cycle while keeping the current gallery processed,
so the next transition cannot immediately reopen it.
*/
/*
Mark one parent as processed in the current UNIQUE parent round.
*/
markUniqueRandomParentSeen(parent_path)
{
    global random_unique_parent_seen

    parent_path := normalizeFolderPath(parent_path)

    if (parent_path = "")
    {
        return false
    }

    parent_key := toLowerText(parent_path)

    for seen_index, seen_path in random_unique_parent_seen
    {
        if (toLowerText(seen_path) = parent_key)
        {
            return true
        }
    }

    random_unique_parent_seen.Push(parent_path)
    return true
}

/*
Return true when a parent has already been used in the current
UNIQUE parent round.
*/
isUniqueRandomParentSeen(parent_path)
{
    global random_unique_parent_seen

    parent_key := toLowerText(normalizeFolderPath(parent_path))

    if (parent_key = "")
    {
        return false
    }

    for seen_index, seen_path in random_unique_parent_seen
    {
        if (toLowerText(seen_path) = parent_key)
        {
            return true
        }
    }

    return false
}

/*
Start a new parent round without resetting child-gallery progress.
*/
resetUniqueRandomParentRound(current_parent)
{
    global random_unique_parent_seen

    random_unique_parent_seen := []

    if (current_parent != "")
    {
        markUniqueRandomParentSeen(current_parent)
    }

    return true
}

resetUniqueRandomCycle(current_gallery)
{
    global random_unique_seen
    global random_unique_parent_seen

    random_unique_seen := []
    random_unique_parent_seen := []

    if (current_gallery != "")
    {
        markUniqueRandomGallerySeen(current_gallery)

        SplitPath, current_gallery,, current_parent
        current_parent := normalizeFolderPath(current_parent)

        if (current_parent != "")
        {
            markUniqueRandomParentSeen(current_parent)
        }
    }

    return true
}

/*
Serialize Unique processed paths. The vertical bar is invalid in Windows
file names, so it is safe as the list separator.
*/
joinRandomUniquePaths(path_list)
{
    output_text := ""

    for path_index, gallery_path in path_list
    {
        if (output_text != "")
        {
            output_text .= "|"
        }

        output_text .= gallery_path
    }

    return output_text
}

/*
Restore Unique processed paths from the session INI.
*/
parseRandomUniquePaths(path_text)
{
    path_list := []

    Loop, Parse, path_text, |
    {
        gallery_path := normalizeFolderPath(A_LoopField)

        if (gallery_path != "")
        {
            path_list.Push(gallery_path)
        }
    }

    return path_list
}


/*
Remember a gallery only after it actually opens.
*/
recordRandomGalleryVisit(gallery_path)
{
    global random_navigation_active
    global random_gallery_history
    global random_gallery_history_limit

    if (!random_navigation_active)
    {
        return false
    }

    gallery_path := normalizeFolderPath(gallery_path)

    if (gallery_path = "")
    {
        return false
    }

    gallery_key := toLowerText(gallery_path)
    updated_history := []

    for history_index, history_path in random_gallery_history
    {
        if (toLowerText(history_path) != gallery_key)
        {
            updated_history.Push(history_path)
        }
    }

    updated_history.Push(gallery_path)

    while (updated_history.Length() > random_gallery_history_limit)
    {
        updated_history.RemoveAt(1)
    }

    random_gallery_history := updated_history

    if (isUniqueRandomMode())
    {
        markUniqueRandomGallerySeen(gallery_path)

        SplitPath, gallery_path,, parent_path
        parent_path := normalizeFolderPath(parent_path)

        if (parent_path != "")
        {
            markUniqueRandomParentSeen(parent_path)
        }
    }

    return true
}

/*
Check the recent random-history window.
*/
isRecentRandomGallery(gallery_path)
{
    global random_gallery_history

    gallery_key := toLowerText(normalizeFolderPath(gallery_path))

    if (gallery_key = "")
    {
        return false
    }

    for history_index, history_path in random_gallery_history
    {
        if (toLowerText(history_path) = gallery_key)
        {
            return true
        }
    }

    return false
}

/*
Return the authoritative resident-bridge random mode.
*/
isRandomNavigationMode()
{
    global random_navigation_active

    return random_navigation_active
}

/*
Return the ordinary next item, wrapping at the end.
*/
getSequentialNextPath(path_list, current_path)
{
    if (!IsObject(path_list) || path_list.Length() < 1)
    {
        return ""
    }

    current_index := findPathIndex(path_list, current_path)
    next_index := current_index < 1 || current_index >= path_list.Length() ? 1 : current_index + 1
    return path_list[next_index]
}

/*
Choose a genuinely random path.
The current path is always excluded. When another option exists,
the ordinary sequential next item is excluded too.
*/
chooseRandomPath(path_list, current_path := "", sequential_path := "", allow_unique_cycle_reset := true)
{
    all_candidates := []
    non_sequential_candidates := []
    preferred_candidates := []
    unique_candidates := []
    unique_non_sequential_candidates := []
    current_key := toLowerText(normalizeFolderPath(current_path))
    sequential_key := toLowerText(normalizeFolderPath(sequential_path))
    unique_mode := isUniqueRandomMode()

    if (!IsObject(path_list))
    {
        return ""
    }

    for path_index, candidate_path in path_list
    {
        candidate_path := normalizeFolderPath(candidate_path)
        candidate_key := toLowerText(candidate_path)

        if (candidate_path = "" || candidate_key = current_key || !InStr(FileExist(candidate_path), "D"))
        {
            continue
        }

        all_candidates.Push(candidate_path)

        if (!isUniqueRandomGallerySeen(candidate_path))
        {
            unique_candidates.Push(candidate_path)
        }

        if (sequential_key = "" || candidate_key != sequential_key)
        {
            non_sequential_candidates.Push(candidate_path)

            if (!isUniqueRandomGallerySeen(candidate_path))
            {
                unique_non_sequential_candidates.Push(candidate_path)
            }

            if !isRecentRandomGallery(candidate_path)
            {
                preferred_candidates.Push(candidate_path)
            }
        }
    }

    if (unique_mode)
    {
        if (unique_non_sequential_candidates.Length() > 0)
        {
            candidates := unique_non_sequential_candidates
        }
        else if (unique_candidates.Length() > 0)
        {
            candidates := unique_candidates
        }
        else
        {
            if (!allow_unique_cycle_reset)
            {
                return ""
            }

            resetUniqueRandomCycle(current_path)

            if (preferred_candidates.Length() > 0)
            {
                candidates := preferred_candidates
            }
            else if (non_sequential_candidates.Length() > 0)
            {
                candidates := non_sequential_candidates
            }
            else
            {
                candidates := all_candidates
            }
        }
    }
    else if (preferred_candidates.Length() > 0)
    {
        candidates := preferred_candidates
    }
    else if (non_sequential_candidates.Length() > 0)
    {
        candidates := non_sequential_candidates
    }
    else
    {
        candidates := all_candidates
    }

    candidate_count := candidates.Length()

    if (candidate_count < 1)
    {
        return ""
    }

    Random, random_index, 1, %candidate_count%
    return candidates[random_index]
}

/*
Choose a random eligible gallery from the entire filtered queue.
*/
getRandomGalleryPath(filtered_queue, current_gallery)
{
    global current_parent

    return getRandomDifferentParentGalleryPath(current_parent)
}

/*
Choose a random parent different from the current one, then choose
a random eligible gallery inside it.
*/
/*
Build parent groups from the filtered queue written by the HTML UI.
The queue already reflects keyword, rating, and search filters.
*/
getFilteredParentGalleryGroups(ByRef queue_is_valid)
{
    gallery_queue := getFilteredNavigationQueue(queue_is_valid)
    parent_groups := []
    parent_index_map := {}

    if (!queue_is_valid)
    {
        return parent_groups
    }

    for gallery_index, gallery_path in gallery_queue
    {
        SplitPath, gallery_path,, parent_folder
        parent_folder := normalizeFolderPath(parent_folder)
        parent_key := toLowerText(parent_folder)

        if (parent_folder = "")
        {
            continue
        }

        if (!parent_index_map.HasKey(parent_key))
        {
            parent_group := {parent: parent_folder, galleries: []}
            parent_groups.Push(parent_group)
            parent_index_map[parent_key] := parent_groups.Length()
        }

        group_index := parent_index_map[parent_key]
        parent_groups[group_index].galleries.Push(gallery_path)
    }

    return parent_groups
}

/*
Return one uniformly random item from an AutoHotkey array.
*/
chooseUniformRandomItem(item_list)
{
    if (!IsObject(item_list) || item_list.Length() < 1)
    {
        return ""
    }

    item_count := item_list.Length()
    Random, random_index, 1, %item_count%
    return item_list[random_index]
}

/*
Return galleries that are still allowed in the current Unique cycle.
*/
getAllowedRandomGalleries(gallery_list)
{
    allowed_galleries := []
    unique_mode := isUniqueRandomMode()

    for gallery_index, gallery_path in gallery_list
    {
        if (!unique_mode || !isUniqueRandomGallerySeen(gallery_path))
        {
            allowed_galleries.Push(gallery_path)
        }
    }

    return allowed_galleries
}

/*
Return the alphabetically next parent only so it can be excluded when
another random parent is available.
*/
getAlphabeticallyNextParentPath(parent_groups, current_parent)
{
    parent_paths := []

    for parent_index, parent_group in parent_groups
    {
        parent_paths.Push(parent_group.parent)
    }

    if (parent_paths.Length() < 1)
    {
        return ""
    }

    sortPathArray(parent_paths)
    return getSequentialNextPath(parent_paths, current_parent)
}

getRandomDifferentParentGalleryPath(current_parent, allow_unique_reset := true)
{
    global current_gallery

    parent_groups := getFilteredParentGalleryGroups(queue_is_valid)

    if (!queue_is_valid || parent_groups.Length() < 1)
    {
        return ""
    }

    unique_mode := isUniqueRandomMode()
    current_parent := normalizeFolderPath(current_parent)
    current_parent_key := toLowerText(current_parent)
    all_groups := []
    different_groups := []

    for parent_index, parent_group in parent_groups
    {
        allowed_galleries := getAllowedRandomGalleries(parent_group.galleries)

        if (allowed_galleries.Length() < 1)
        {
            continue
        }

        candidate_group := {}
        candidate_group.parent := parent_group.parent
        candidate_group.galleries := allowed_galleries

        all_groups.Push(candidate_group)

        if (toLowerText(parent_group.parent) != current_parent_key)
        {
            different_groups.Push(candidate_group)
        }
    }

    if (all_groups.Length() < 1 && unique_mode && allow_unique_reset)
    {
        resetUniqueRandomCycle(current_gallery)
        return getRandomDifferentParentGalleryPath(current_parent, false)
    }

    candidate_groups := different_groups.Length() > 0 ? different_groups : all_groups

    if (candidate_groups.Length() < 1)
    {
        return current_gallery
    }

    if (unique_mode)
    {
        unseen_parent_groups := []

        for candidate_index, candidate_group in candidate_groups
        {
            if !isUniqueRandomParentSeen(candidate_group.parent)
            {
                unseen_parent_groups.Push(candidate_group)
            }
        }

        if (unseen_parent_groups.Length() > 0)
        {
            candidate_groups := unseen_parent_groups
        }
        else
        {
            resetUniqueRandomParentRound(current_parent)
            unseen_parent_groups := []

            for candidate_index, candidate_group in candidate_groups
            {
                if !isUniqueRandomParentSeen(candidate_group.parent)
                {
                    unseen_parent_groups.Push(candidate_group)
                }
            }

            if (unseen_parent_groups.Length() > 0)
            {
                candidate_groups := unseen_parent_groups
            }
        }
    }

    forbidden_parent := getAlphabeticallyNextParentPath(parent_groups, current_parent)
    non_sequential_groups := []

    if (candidate_groups.Length() > 1 && forbidden_parent != "")
    {
        forbidden_key := toLowerText(forbidden_parent)

        for candidate_index, candidate_group in candidate_groups
        {
            if (toLowerText(candidate_group.parent) != forbidden_key)
            {
                non_sequential_groups.Push(candidate_group)
            }
        }
    }

    if (non_sequential_groups.Length() > 0)
    {
        candidate_groups := non_sequential_groups
    }

    selected_group := chooseUniformRandomItem(candidate_groups)

    if (!IsObject(selected_group))
    {
        return ""
    }

    return chooseUniformRandomItem(selected_group.galleries)
}

/*
Read the exact random destination already prepared for one action.
*/
getPreparedSlotGalleryPath(slot_prefix)
{
    if (!FileExist(slot_prefix . ".ready"))
    {
        return ""
    }

    meta_path := slot_prefix . ".meta.ini"

    if (!FileExist(meta_path))
    {
        return ""
    }

    IniRead, prepared_gallery, %meta_path%, Gallery, Path,
    prepared_gallery := normalizeFolderPath(prepared_gallery)

    if (prepared_gallery = "" || !InStr(FileExist(prepared_gallery), "D"))
    {
        return ""
    }

    return prepared_gallery
}

/*
Return the next gallery path.
*/
getNextGalleryPath(parent_folder, gallery_folder)
{
    filtered_queue := getFilteredNavigationQueue(queue_is_valid)

    if (queue_is_valid)
    {
        if (filtered_queue.Length() < 1)
        {
            return ""
        }

        if (isRandomNavigationMode())
        {
            return getRandomDifferentParentGalleryPath(parent_folder)
        }

        current_parent_galleries := []

        for gallery_index, filtered_gallery in filtered_queue
        {
            SplitPath, filtered_gallery,, filtered_parent
            filtered_parent := normalizeFolderPath(filtered_parent)

            if (toLowerText(filtered_parent) = toLowerText(parent_folder))
            {
                current_parent_galleries.Push(filtered_gallery)
            }
        }

        if (current_parent_galleries.Length() < 1)
        {
            return filtered_queue[1]
        }

        current_index := findPathIndex(current_parent_galleries, gallery_folder)
        next_index := current_index < 1 || current_index >= current_parent_galleries.Length() ? 1 : current_index + 1
        return current_parent_galleries[next_index]
    }

    gallery_folders := getGalleryFolders(parent_folder)

    if (gallery_folders.Length() < 1)
    {
        return ""
    }

    current_index := findPathIndex(gallery_folders, gallery_folder)
    next_index := current_index < 1 || current_index >= gallery_folders.Length() ? 1 : current_index + 1
    return gallery_folders[next_index]
}

/*
Return the first gallery in the next parent across the A-Z hierarchy.
*/
getNextParentGalleryPath(parent_folder)
{
    global root_folder

    parent_entries := getFilteredParentEntries(queue_is_valid)

    if (queue_is_valid)
    {
        if (parent_entries.Length() < 1)
        {
            return ""
        }

        if (isRandomNavigationMode())
        {
            return getRandomDifferentParentGalleryPath(parent_folder)
        }

        current_index := 0

        for parent_index, parent_entry in parent_entries
        {
            if (toLowerText(parent_entry.parent) = toLowerText(parent_folder))
            {
                current_index := parent_index
                break
            }
        }

        next_index := current_index < 1 || current_index >= parent_entries.Length() ? 1 : current_index + 1
        return parent_entries[next_index].gallery
    }

    parent_folders := getParentFolders(root_folder)

    if (parent_folders.Length() < 1)
    {
        return ""
    }

    current_index := findPathIndex(parent_folders, parent_folder)
    next_index := current_index < 1 || current_index >= parent_folders.Length() ? 1 : current_index + 1
    next_parent := parent_folders[next_index]
    gallery_folders := getGalleryFolders(next_parent)
    return gallery_folders.Length() > 0 ? gallery_folders[1] : ""
}

/*
Return the first gallery in the previous parent across the A-Z hierarchy.
The first parent wraps to the final parent.
*/
getPreviousParentGalleryPath(parent_folder)
{
    global root_folder

    parent_entries := getFilteredParentEntries(queue_is_valid)

    if (queue_is_valid)
    {
        if (parent_entries.Length() < 1)
        {
            return ""
        }

        if (isRandomNavigationMode())
        {
            return getRandomDifferentParentGalleryPath(parent_folder)
        }

        current_index := 0

        for parent_index, parent_entry in parent_entries
        {
            if (toLowerText(parent_entry.parent) = toLowerText(parent_folder))
            {
                current_index := parent_index
                break
            }
        }

        previous_index := current_index <= 1 ? parent_entries.Length() : current_index - 1
        return parent_entries[previous_index].gallery
    }

    parent_folders := getParentFolders(root_folder)

    if (parent_folders.Length() < 1)
    {
        return ""
    }

    current_index := findPathIndex(parent_folders, parent_folder)

    if (current_index < 1)
    {
        previous_index := parent_folders.Length()
    }
    else if (current_index <= 1)
    {
        previous_index := parent_folders.Length()
    }
    else
    {
        previous_index := current_index - 1
    }

    previous_parent := parent_folders[previous_index]
    gallery_folders := getGalleryFolders(previous_parent)
    return gallery_folders.Length() > 0 ? gallery_folders[1] : ""
}

/*
Return valid parent folders sorted by letter and name.
*/
getParentFolders(galleries_root)
{
    parent_folders := []
    galleries_root := normalizeFolderPath(galleries_root)

    if (galleries_root = "" || !InStr(FileExist(galleries_root), "D"))
    {
        return parent_folders
    }

    letter_folders := getDirectSubfolders(galleries_root)

    for letter_index, letter_folder in letter_folders
    {
        SplitPath, letter_folder, letter_name

        if (!RegExMatch(letter_name, "i)^[A-Z]$"))
        {
            continue
        }

        candidate_parents := getDirectSubfolders(letter_folder)

        for parent_index, parent_folder in candidate_parents
        {
            if (getGalleryFolders(parent_folder).Length() > 0)
            {
                parent_folders.Push(parent_folder)
            }
        }
    }

    return parent_folders
}

/*
Return direct gallery folders containing at least one supported image.
*/
getGalleryFolders(parent_folder)
{
    global EXCLUDED_FOLDER_NAMES

    gallery_folders := []
    excluded_map := buildExcludedNameMap(EXCLUDED_FOLDER_NAMES)
    candidate_folders := getDirectSubfolders(parent_folder)

    for candidate_index, candidate_folder in candidate_folders
    {
        SplitPath, candidate_folder, candidate_name

        if (excluded_map.HasKey(toLowerText(candidate_name)))
        {
            continue
        }

        if (getDirectImagePaths(candidate_folder).Length() > 0)
        {
            gallery_folders.Push(candidate_folder)
        }
    }

    return gallery_folders
}

/*
Return immediate child folders sorted alphabetically.
*/
getDirectSubfolders(parent_folder)
{
    folder_paths := []

    if (parent_folder = "" || !InStr(FileExist(parent_folder), "D"))
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

/*
Return direct supported image files sorted alphabetically.
*/
getDirectImagePaths(gallery_folder)
{
    global IMAGE_EXTENSIONS

    image_paths := []
    extension_map := buildExtensionMap(IMAGE_EXTENSIONS)

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
    return image_paths
}

/*
Find a parent-level WMV or MP4 whose first integer matches the gallery name.
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
        SplitPath, A_LoopFileFullPath,,, file_extension
        file_extension := toLowerText(file_extension)

        if (file_extension != "mp4" && file_extension != "wmv")
        {
            continue
        }

        video_number := getFirstIntegerFromName(A_LoopFileFullPath)

        if (video_number = gallery_number)
        {
            matched_videos.Push(A_LoopFileFullPath)
        }
    }

    sortPathArray(matched_videos)
    return matched_videos.Length() > 0 ? matched_videos[1] : ""
}

/*
Extract only the first integer from the final file or folder name.
*/
getFirstIntegerFromName(path_or_name)
{
    comparable_path := RTrim(Trim(path_or_name, " `t`r`n"""), "\/")

    if (comparable_path = "")
    {
        return ""
    }

    SplitPath, comparable_path, leaf_name,, leaf_extension, leaf_name_without_extension

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

/*
Send VLC's M shortcut directly to one VLC window without activating it.
*/
sendVlcMuteKey(vlc_window_id)
{
    if (vlc_window_id = "" || !WinExist("ahk_id " . vlc_window_id))
    {
        return false
    }

    ControlSend,, m, ahk_id %vlc_window_id%
    return !ErrorLevel
}

/*
Mute one newly started VLC instance and schedule an automatic unmute.
*/
startTemporaryVlcMute(vlc_window_id, vlc_pid)
{
    global temporary_vlc_mute_active
    global temporary_vlc_mute_window_id
    global temporary_vlc_mute_pid
    global temporary_vlc_mute_duration_ms

    SetTimer, vlcAutoUnmuteTimer, Off

    temporary_vlc_mute_active := false
    temporary_vlc_mute_window_id := ""
    temporary_vlc_mute_pid := ""

    if (vlc_window_id = "" || vlc_pid = "" || !processExists(vlc_pid))
    {
        return false
    }

    if (!sendVlcMuteKey(vlc_window_id))
    {
        return false
    }

    temporary_vlc_mute_active := true
    temporary_vlc_mute_window_id := vlc_window_id
    temporary_vlc_mute_pid := vlc_pid

    timer_period := -1 * temporary_vlc_mute_duration_ms
    SetTimer, vlcAutoUnmuteTimer, %timer_period%
    return true
}

/*
Undo only the temporary mute applied by this bridge.
The PID check prevents an old timer from toggling a newer VLC instance.
*/
restoreTemporaryVlcSound()
{
    global temporary_vlc_mute_active
    global temporary_vlc_mute_window_id
    global temporary_vlc_mute_pid

    SetTimer, vlcAutoUnmuteTimer, Off

    was_active := temporary_vlc_mute_active
    target_window_id := temporary_vlc_mute_window_id
    target_pid := temporary_vlc_mute_pid

    temporary_vlc_mute_active := false
    temporary_vlc_mute_window_id := ""
    temporary_vlc_mute_pid := ""

    if (!was_active || target_window_id = "" || target_pid = "" || !WinExist("ahk_id " . target_window_id))
    {
        return false
    }

    WinGet, actual_pid, PID, ahk_id %target_window_id%

    if (actual_pid != target_pid)
    {
        return false
    }

    return sendVlcMuteKey(target_window_id)
}

/*
Open a matched video in a new VLC instance, fullscreen it, mute it for
ten seconds, and close the old instance.
*/
sendVideoToVlc(video_path)
{
    global vlc_exe

    restoreTemporaryVlcSound()

    if (!ensureVlcPath())
    {
        return false
    }

    WinGet, old_vlc_window_id, ID, ahk_exe vlc.exe
    old_vlc_pid := ""
    old_x := ""
    old_y := ""
    old_width := ""
    old_height := ""

    if (old_vlc_window_id != "")
    {
        WinGet, old_vlc_pid, PID, ahk_id %old_vlc_window_id%
        WinGetPos, old_x, old_y, old_width, old_height, ahk_id %old_vlc_window_id%
    }

    command_line := quotePath(vlc_exe) . " --no-one-instance --no-fullscreen " . quotePath(video_path)
    Run, %command_line%,, UseErrorLevel, new_vlc_pid

    if (ErrorLevel || new_vlc_pid = "")
    {
        return false
    }

    new_vlc_window_id := waitForWindowByPid(new_vlc_pid, 8000)

    if (new_vlc_window_id = "")
    {
        return false
    }

    WinShow, ahk_id %new_vlc_window_id%
    Sleep, 500

    target_monitor_index := getVlcTargetMonitorIndex()
    moved_to_secondary_monitor := moveWindowToMonitorWithRetries(new_vlc_window_id, target_monitor_index, 5)

    if (!moved_to_secondary_monitor
        && old_vlc_window_id != ""
        && old_width > 0
        && old_height > 0)
    {
        WinMove, ahk_id %new_vlc_window_id%,, %old_x%, %old_y%, %old_width%, %old_height%
    }

    enterVlcFullscreenOnMonitor(new_vlc_window_id, target_monitor_index, 3)
    startTemporaryVlcMute(new_vlc_window_id, new_vlc_pid)

    if (old_vlc_window_id != "" && old_vlc_pid != new_vlc_pid)
    {
        WinClose, ahk_id %old_vlc_window_id%
        Process, WaitClose, %old_vlc_pid%, 2
    }

    return true
}

/*
Find the active or first visible Gallery Slideshow Manager HTA window.
*/
findGalleryManagerWindow()
{
    active_window_id := WinActive("Gallery Slideshow Manager ahk_exe mshta.exe")

    if (active_window_id != "")
    {
        return active_window_id
    }

    WinGet, manager_window_list, List, Gallery Slideshow Manager ahk_exe mshta.exe

    Loop, %manager_window_list%
    {
        manager_window_id_candidate := manager_window_list%A_Index%

        if (manager_window_id_candidate = "")
        {
            continue
        }

        WinGetTitle, manager_window_title, ahk_id %manager_window_id_candidate%

        if (InStr(manager_window_title, "Gallery Slideshow Manager") = 1)
        {
            return manager_window_id_candidate
        }
    }

    return ""
}

/*
Create a signature that also changes when one monitor is rotated or its
work area changes while retaining the same monitor index.
*/
getMonitorLayoutSignature(monitor_index)
{
    if (monitor_index < 1)
    {
        return ""
    }

    SysGet, monitor_bounds, Monitor, %monitor_index%
    SysGet, monitor_work, MonitorWorkArea, %monitor_index%

    monitor_width := monitor_boundsRight - monitor_boundsLeft
    monitor_height := monitor_boundsBottom - monitor_boundsTop
    work_width := monitor_workRight - monitor_workLeft
    work_height := monitor_workBottom - monitor_workTop

    return monitor_index
        . "|" . monitor_width . "x" . monitor_height
        . "|" . work_width . "x" . work_height
}

/*
Refit only while the manager is active and in its normal window state.
Moving it to another monitor or rotating that monitor triggers refitting.
Minimized, maximized, and unrelated windows are never restored or moved.
*/
monitorManagerWindowPlacement()
{
    global manager_window_id, manager_monitor_index, manager_monitor_signature

    detected_window_id := WinActive("Gallery Slideshow Manager ahk_exe mshta.exe")

    if (detected_window_id = "")
    {
        return false
    }

    WinGet, detected_window_state, MinMax, ahk_id %detected_window_id%

    if (detected_window_state != 0)
    {
        return false
    }

    detected_monitor_index := getWindowMonitorIndex(detected_window_id)
    detected_signature := getMonitorLayoutSignature(detected_monitor_index)

    if (detected_window_id != manager_window_id
        || detected_monitor_index != manager_monitor_index
        || detected_signature != manager_monitor_signature)
    {
        if (!fitManagerWindowToMonitor(detected_window_id, detected_monitor_index))
        {
            return false
        }

        manager_window_id := detected_window_id
        manager_monitor_index := detected_monitor_index
        manager_monitor_signature := detected_signature
        return true
    }

    return false
}

/*
Preserve the current manager-window aspect ratio.

Landscape monitor:
- occupy the complete work-area height;
- center horizontally.

Portrait monitor:
- occupy the complete work-area width;
- center vertically.
*/
fitManagerWindowToMonitor(window_id, monitor_index)
{
    if (window_id = "" || monitor_index < 1)
    {
        return false
    }

    SysGet, monitor_bounds, Monitor, %monitor_index%
    SysGet, work_area, MonitorWorkArea, %monitor_index%

    monitor_width := monitor_boundsRight - monitor_boundsLeft
    monitor_height := monitor_boundsBottom - monitor_boundsTop
    work_width := work_areaRight - work_areaLeft
    work_height := work_areaBottom - work_areaTop

    if (monitor_width <= 0
        || monitor_height <= 0
        || work_width <= 0
        || work_height <= 0)
    {
        return false
    }

    WinGet, window_min_max, MinMax, ahk_id %window_id%

    if (window_min_max != 0)
    {
        return false
    }

    WinGetPos, current_x, current_y, current_width, current_height, ahk_id %window_id%

    if (current_width < 320 || current_height < 240)
    {
        current_width := 1200
        current_height := 800
    }

    aspect_ratio := current_width / current_height

    if (aspect_ratio < 0.50 || aspect_ratio > 4.00)
    {
        aspect_ratio := 1.50
    }

    if (monitor_width >= monitor_height)
    {
        target_height := work_height
        target_width := Round(target_height * aspect_ratio)

        if (target_width > work_width)
        {
            target_width := work_width
        }

        target_x := work_areaLeft + Floor((work_width - target_width) / 2)
        target_y := work_areaTop
    }
    else
    {
        target_width := work_width
        target_height := Round(target_width / aspect_ratio)

        if (target_height > work_height)
        {
            target_height := work_height
        }

        target_x := work_areaLeft
        target_y := work_areaTop + Floor((work_height - target_height) / 2)
    }

    WinMove, ahk_id %window_id%,, %target_x%, %target_y%, %target_width%, %target_height%
    return true
}

/*
Choose a VLC target monitor different from the one containing IrfanView.
Monitor 2 is preferred when IrfanView is not already on monitor 2.
*/
getVlcTargetMonitorIndex()
{
    global current_irfan_pid

    SysGet, monitor_count, MonitorCount

    if (monitor_count < 2)
    {
        return 0
    }

    irfanview_window_id := ""

    if (current_irfan_pid != "")
    {
        irfanview_window_id := WinExist("ahk_pid " . current_irfan_pid)
    }

    irfan_monitor_index := getWindowMonitorIndex(irfanview_window_id)

    if (irfan_monitor_index != 2)
    {
        return 2
    }

    Loop, %monitor_count%
    {
        if (A_Index != irfan_monitor_index)
        {
            return A_Index
        }
    }

    return 0
}

/*
Move VLC repeatedly until its center is verified on the target monitor.
VLC can reposition itself while its interface is still initialising.
*/
moveWindowToMonitorWithRetries(window_id, monitor_index, retry_count := 4)
{
    if (window_id = "" || monitor_index < 1 || retry_count < 1)
    {
        return false
    }

    Loop, %retry_count%
    {
        if (!WinExist("ahk_id " . window_id))
        {
            return false
        }

        moveWindowCenteredToMonitor(window_id, monitor_index)
        Sleep, 350

        if (getWindowMonitorIndex(window_id) = monitor_index)
        {
            return true
        }
    }

    return false
}

/*
Enter VLC fullscreen and verify that fullscreen stayed on the target.
When VLC jumps back to another monitor, leave fullscreen, reposition,
and retry fullscreen on the target monitor.
*/
enterVlcFullscreenOnMonitor(window_id, monitor_index, retry_count := 3)
{
    if (window_id = "" || !WinExist("ahk_id " . window_id))
    {
        return false
    }

    attempts := retry_count + 1

    Loop, %attempts%
    {
        if (monitor_index > 0)
        {
            moveWindowToMonitorWithRetries(window_id, monitor_index, 3)
        }

        WinActivate, ahk_id %window_id%
        WinWaitActive, ahk_id %window_id%,, 3
        Sleep, 250
        SendInput, f
        Sleep, 750

        if (monitor_index < 1 || getWindowMonitorIndex(window_id) = monitor_index)
        {
            return true
        }

        SendInput, f
        Sleep, 450
    }

    return false
}

/*
Compatibility wrapper used by older callers.
*/
moveVlcToMonitorDifferentFromIrfanView(vlc_window_id)
{
    target_monitor_index := getVlcTargetMonitorIndex()
    return moveWindowToMonitorWithRetries(vlc_window_id, target_monitor_index, 4)
}

/*
Return the monitor containing the center of one window.
*/
getWindowMonitorIndex(window_id)
{
    if (window_id = "" || !WinExist("ahk_id " . window_id))
    {
        return 1
    }

    WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_id%

    if (window_width <= 0 || window_height <= 0)
    {
        return 1
    }

    window_center_x := window_x + Floor(window_width / 2)
    window_center_y := window_y + Floor(window_height / 2)

    SysGet, monitor_count, MonitorCount

    Loop, %monitor_count%
    {
        monitor_index := A_Index
        SysGet, monitor_area, Monitor, %monitor_index%

        if (window_center_x >= monitor_areaLeft
            && window_center_x < monitor_areaRight
            && window_center_y >= monitor_areaTop
            && window_center_y < monitor_areaBottom)
        {
            return monitor_index
        }
    }

    return 1
}

/*
Place a normal window in the center of a monitor work area.
VLC enters fullscreen only after this move, so fullscreen stays on that monitor.
*/
moveWindowCenteredToMonitor(window_id, monitor_index)
{
    if (window_id = "" || monitor_index < 1)
    {
        return false
    }

    SysGet, target_area, MonitorWorkArea, %monitor_index%

    target_width := target_areaRight - target_areaLeft
    target_height := target_areaBottom - target_areaTop

    if (target_width <= 0 || target_height <= 0)
    {
        return false
    }

    WinRestore, ahk_id %window_id%
    WinGetPos, current_x, current_y, current_width, current_height, ahk_id %window_id%

    if (current_width < 320 || current_height < 240)
    {
        current_width := Floor(target_width * 0.72)
        current_height := Floor(target_height * 0.72)
    }

    maximum_width := Floor(target_width * 0.90)
    maximum_height := Floor(target_height * 0.90)

    if (current_width > maximum_width)
    {
        current_width := maximum_width
    }

    if (current_height > maximum_height)
    {
        current_height := maximum_height
    }

    target_x := target_areaLeft + Floor((target_width - current_width) / 2)
    target_y := target_areaTop + Floor((target_height - current_height) / 2)

    WinMove, ahk_id %window_id%,, %target_x%, %target_y%, %current_width%, %current_height%
    return true
}

/*
Locate or browse for the IrfanView executable.
*/
ensureIrfanViewPath()
{
    global irfanview_exe, SETTINGS_INI

    if (irfanview_exe != "" && FileExist(irfanview_exe))
    {
        return true
    }

    candidates := []
    candidates.Push(A_ProgramFiles . "\IrfanView\i_view64.exe")
    candidates.Push(A_ProgramFiles . "\IrfanView\i_view32.exe")
    candidates.Push(A_ScriptDir . "\i_view64.exe")
    candidates.Push(A_ScriptDir . "\i_view32.exe")

    for candidate_index, candidate_path in candidates
    {
        if (FileExist(candidate_path))
        {
            irfanview_exe := candidate_path
            IniWrite, %irfanview_exe%, %SETTINGS_INI%, IrfanView, ExePath
            return true
        }
    }

    FileSelectFile, selected_path, 3,, Select IrfanView executable, IrfanView (i_view*.exe)

    if (ErrorLevel || selected_path = "")
    {
        return false
    }

    irfanview_exe := selected_path
    IniWrite, %irfanview_exe%, %SETTINGS_INI%, IrfanView, ExePath
    return true
}

/*
Locate or browse for the VLC executable.
*/
ensureVlcPath()
{
    global vlc_exe, SETTINGS_INI

    if (vlc_exe != "" && FileExist(vlc_exe))
    {
        return true
    }

    candidates := []
    candidates.Push(A_ProgramFiles . "\VideoLAN\VLC\vlc.exe")

    EnvGet, program_files_x86, ProgramFiles(x86)
    if (program_files_x86 != "")
    {
        candidates.Push(program_files_x86 . "\VideoLAN\VLC\vlc.exe")
    }

    candidates.Push(A_ScriptDir . "\vlc.exe")

    for candidate_index, candidate_path in candidates
    {
        if (FileExist(candidate_path))
        {
            vlc_exe := candidate_path
            IniWrite, %vlc_exe%, %SETTINGS_INI%, VLC, ExePath
            return true
        }
    }

    FileSelectFile, selected_path, 3,, Select VLC executable, VLC (vlc.exe)

    if (ErrorLevel || selected_path = "")
    {
        return false
    }

    vlc_exe := selected_path
    IniWrite, %vlc_exe%, %SETTINGS_INI%, VLC, ExePath
    return true
}

/*
Close the managed IrfanView slideshow on the first user Enter press.
The bridge remains alive until the monitor confirms that IrfanView has exited.
*/
closeCurrentSlideshowOnEnter()
{
    global current_irfan_pid, switching_slideshow

    if (switching_slideshow)
    {
        return false
    }

    if (current_irfan_pid = "" || !processExists(current_irfan_pid))
    {
        WinGet, active_process_name, ProcessName, A
        active_process_name := toLowerText(active_process_name)

        if (active_process_name != "i_view64.exe"
            && active_process_name != "i_view32.exe")
        {
            return false
        }

        WinGet, active_process_id, PID, A
        current_irfan_pid := active_process_id
    }

    irfanview_window_id := WinExist("ahk_pid " . current_irfan_pid)

    if (irfanview_window_id = "")
    {
        return false
    }

    saveWindowPlacement(irfanview_window_id, "IrfanViewWindow")
    WinClose, ahk_id %irfanview_window_id%
    return true
}

/*
Clear the running slideshow data used by the HTML RUNNING badge.
*/
clearRunningSessionState()
{
    global SESSION_INI
    global current_parent, current_gallery
    global current_video, current_irfan_pid
    global random_navigation_active
    global random_unique_active
    global random_unique_seen
    global random_unique_parent_seen
    global random_gallery_history

    current_parent := ""
    current_gallery := ""
    current_video := ""
    current_irfan_pid := ""
    random_navigation_active := false
    random_unique_active := false
    random_unique_seen := []
    random_unique_parent_seen := []
    random_gallery_history := []

    IniDelete, %SESSION_INI%, Session, CurrentParent
    IniDelete, %SESSION_INI%, Session, CurrentGallery
    IniDelete, %SESSION_INI%, Session, CurrentVideo
    IniDelete, %SESSION_INI%, Session, CurrentParentRating
    IniDelete, %SESSION_INI%, Session, ImageCount
    IniDelete, %SESSION_INI%, Session, IrfanViewPid
    IniDelete, %SESSION_INI%, Session, NavigationMode
    IniDelete, %SESSION_INI%, Session, RandomUnique
    IniDelete, %SESSION_INI%, Session, RandomUniqueSeen
    IniDelete, %SESSION_INI%, Session, RandomUniqueParentSeen
    return true
}

/*
Save current IrfanView geometry and close the managed process.
*/
saveAndCloseCurrentIrfanView()
{
    global current_irfan_pid

    if (current_irfan_pid = "" || !processExists(current_irfan_pid))
    {
        current_irfan_pid := ""
        return
    }

    window_id := WinExist("ahk_pid " . current_irfan_pid)

    if (window_id != "")
    {
        saveWindowPlacement(window_id, "IrfanViewWindow")
        WinClose, ahk_id %window_id%
    }

    Process, WaitClose, %current_irfan_pid%, 1

    if (processExists(current_irfan_pid))
    {
        Process, Close, %current_irfan_pid%
    }

    current_irfan_pid := ""
}

/*
Close the current managed IrfanView without changing the stored session path.
*/
closeManagedIrfanView()
{
    saveAndCloseCurrentIrfanView()
}

/*
Save a normal window rectangle in the settings INI.
*/
saveWindowPlacement(window_id, section_name)
{
    global SETTINGS_INI

    if (window_id = "" || !WinExist("ahk_id " . window_id))
    {
        return false
    }

    WinRestore, ahk_id %window_id%
    WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_id%

    if (window_width < 100 || window_height < 100)
    {
        return false
    }

    IniWrite, %window_x%, %SETTINGS_INI%, %section_name%, X
    IniWrite, %window_y%, %SETTINGS_INI%, %section_name%, Y
    IniWrite, %window_width%, %SETTINGS_INI%, %section_name%, Width
    IniWrite, %window_height%, %SETTINGS_INI%, %section_name%, Height
    return true
}

/*
Restore a saved window rectangle when it is still visible on a monitor.
*/
restoreWindowPlacement(window_id, section_name)
{
    global SETTINGS_INI

    IniRead, window_x, %SETTINGS_INI%, %section_name%, X,
    IniRead, window_y, %SETTINGS_INI%, %section_name%, Y,
    IniRead, window_width, %SETTINGS_INI%, %section_name%, Width,
    IniRead, window_height, %SETTINGS_INI%, %section_name%, Height,

    if (!isIntegerValue(window_x)
        || !isIntegerValue(window_y)
        || !isPositiveIntegerValue(window_width)
        || !isPositiveIntegerValue(window_height))
    {
        return false
    }

    if (!doesRectangleTouchAnyMonitor(window_x, window_y, window_width, window_height))
    {
        return false
    }

    WinMove, ahk_id %window_id%,, %window_x%, %window_y%, %window_width%, %window_height%
    return true
}

/*
Write one INI value, or delete the key when the value is blank.
AHK v1 IniWrite rejects a blank first parameter.
*/
writeIniValueOrDelete(value_text, ini_path, section_name, key_name)
{
    if (value_text = "")
    {
        IniDelete, %ini_path%, %section_name%, %key_name%
        return !ErrorLevel
    }

    IniWrite, %value_text%, %ini_path%, %section_name%, %key_name%
    return !ErrorLevel
}

/*
Write the current bridge session for HTML status and highlighting.
*/
writeSessionState(image_count)
{
    global SESSION_INI
    global current_parent, current_gallery
    global current_video, current_irfan_pid
    global random_navigation_active
    global random_unique_active
    global random_unique_seen
    global random_unique_parent_seen

    navigation_mode := random_navigation_active ? "random" : "normal"
    unique_value := random_navigation_active && random_unique_active ? 1 : 0
    unique_seen_text := joinRandomUniquePaths(random_unique_seen)
    unique_parent_seen_text := joinRandomUniquePaths(random_unique_parent_seen)

    IniWrite, %current_parent%, %SESSION_INI%, Session, CurrentParent
    IniWrite, %current_gallery%, %SESSION_INI%, Session, CurrentGallery
    writeIniValueOrDelete(current_video, SESSION_INI, "Session", "CurrentVideo")
    IniWrite, %image_count%, %SESSION_INI%, Session, ImageCount
    IniWrite, %current_irfan_pid%, %SESSION_INI%, Session, IrfanViewPid
    IniWrite, %navigation_mode%, %SESSION_INI%, Session, NavigationMode
    IniWrite, %unique_value%, %SESSION_INI%, Session, RandomUnique
    writeIniValueOrDelete(unique_seen_text, SESSION_INI, "Session", "RandomUniqueSeen")
    writeIniValueOrDelete(unique_parent_seen_text, SESSION_INI, "Session", "RandomUniqueParentSeen")
}

/*
Read previous session paths after the bridge restarts.
*/
readSessionState()
{
    global SESSION_INI
    global current_parent, current_gallery, current_video
    global random_navigation_active
    global random_unique_active
    global random_unique_seen
    global random_unique_parent_seen

    IniRead, current_parent, %SESSION_INI%, Session, CurrentParent,
    IniRead, current_gallery, %SESSION_INI%, Session, CurrentGallery,
    IniRead, current_video, %SESSION_INI%, Session, CurrentVideo,
    IniRead, navigation_mode, %SESSION_INI%, Session, NavigationMode, normal
    IniRead, unique_value, %SESSION_INI%, Session, RandomUnique, 0
    IniRead, unique_seen_text, %SESSION_INI%, Session, RandomUniqueSeen,
    IniRead, unique_parent_seen_text, %SESSION_INI%, Session, RandomUniqueParentSeen,

    current_parent := normalizeFolderPath(current_parent)
    current_gallery := normalizeFolderPath(current_gallery)
    navigation_mode := toLowerText(Trim(navigation_mode))
    random_navigation_active := navigation_mode = "random"
    random_unique_active := random_navigation_active && unique_value = 1
    random_unique_seen := random_unique_active ? parseRandomUniquePaths(unique_seen_text) : []
    random_unique_parent_seen := random_unique_active ? parseRandomUniquePaths(unique_parent_seen_text) : []

    if (random_unique_active)
    {
        if (current_gallery != "" && !isUniqueRandomGallerySeen(current_gallery))
        {
            markUniqueRandomGallerySeen(current_gallery)
        }

        if (current_parent != "" && !isUniqueRandomParentSeen(current_parent))
        {
            markUniqueRandomParentSeen(current_parent)
        }
    }
}

/*
Exit the resident tray bridge only after the managed IrfanView process is closed.
A gallery-to-gallery replacement is excluded by switching_slideshow.
*/
monitorManagedIrfanView()
{
    global current_irfan_pid, switching_slideshow, script_is_exiting

    if (current_irfan_pid = "" || switching_slideshow || script_is_exiting)
    {
        return
    }

    if (!processExists(current_irfan_pid))
    {
        stopParentPreview(true)
        clearRunningSessionState()
        ExitApp
    }
}

/*
Activate the current managed IrfanView window.
*/
activateCurrentIrfanView()
{
    global current_irfan_pid

    if (current_irfan_pid = "")
    {
        return false
    }

    WinActivate, % "ahk_pid " . current_irfan_pid
    return true
}

/*
Return true while either IrfanView or VLC is the active process.
*/
isGalleryNavigationActive()
{
    WinGet, process_name, ProcessName, A
    process_name := toLowerText(process_name)

    return (process_name = "i_view64.exe"
        || process_name = "i_view32.exe"
        || process_name = "vlc.exe")
}

/*
Return true only while IrfanView is active.
*/
isIrfanViewActive()
{
    WinGet, process_name, ProcessName, A
    process_name := toLowerText(process_name)
    return process_name = "i_view64.exe" || process_name = "i_view32.exe"
}

/*
Ask before closing the resident bridge and managed IrfanView.
*/
confirmExitBridge()
{
    MsgBox, 262180, Gallery Slideshow Manager, Exit the HTML bridge and close the current IrfanView slideshow?

    IfMsgBox, Yes
    {
        saveAndCloseCurrentIrfanView()
        ExitApp
    }

    return false
}

/*
Wait for a top-level window belonging to one process.
*/
waitForWindowByPid(process_id, timeout_ms)
{
    started_at := A_TickCount

    while (A_TickCount - started_at < timeout_ms)
    {
        window_id := WinExist("ahk_pid " . process_id)

        if (window_id != "")
        {
            return window_id
        }

        Sleep, 100
    }

    return ""
}

/*
Return an object's path index with case-insensitive normalization.
*/
findPathIndex(path_array, target_path)
{
    target_key := toLowerText(normalizeFolderPath(target_path))

    for path_index, candidate_path in path_array
    {
        if (toLowerText(normalizeFolderPath(candidate_path)) = target_key)
        {
            return path_index
        }
    }

    return 0
}

/*
Sort an array of paths alphabetically.
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

    Sort, path_text

    sorted_paths := []

    Loop, Parse, path_text, `n, `r
    {
        if (A_LoopField != "")
        {
            sorted_paths.Push(A_LoopField)
        }
    }

    path_array := sorted_paths
}

/*
Build a lowercase extension lookup map.
*/
buildExtensionMap(extension_text)
{
    extension_map := {}

    Loop, Parse, extension_text, `,
    {
        extension_name := toLowerText(Trim(A_LoopField))

        if (extension_name != "")
        {
            extension_map[extension_name] := true
        }
    }

    return extension_map
}

/*
Build a lowercase excluded-folder lookup map.
*/
buildExcludedNameMap(excluded_text)
{
    excluded_map := {}

    Loop, Parse, excluded_text, |
    {
        excluded_name := toLowerText(Trim(A_LoopField))

        if (excluded_name != "")
        {
            excluded_map[excluded_name] := true
        }
    }

    return excluded_map
}

/*
Delete files belonging to one preparation slot.
*/
cleanupSlot(slot_prefix)
{
    if (slot_prefix = "")
    {
        return
    }

    FileDelete, % slot_prefix . ".list.txt"
    FileDelete, % slot_prefix . ".meta.ini"
    FileDelete, % slot_prefix . ".ready"
}

/*
Normalize trailing separators without changing drive roots.
*/
normalizeFolderPath(folder_path)
{
    folder_path := Trim(folder_path, " `t`r`n""")

    if (RegExMatch(folder_path, "i)^[A-Z]:\\$"))
    {
        return folder_path
    }

    return RTrim(folder_path, "\/")
}

/*
Return lowercase text without using unavailable StrLower().
*/
toLowerText(source_text)
{
    StringLower, lower_text, source_text
    return lower_text
}

/*
Quote one command-line path.
*/
quotePath(path_text)
{
    return """" . path_text . """"
}

/*
Return true when a process exists.
*/
processExists(process_id)
{
    Process, Exist, %process_id%
    return ErrorLevel = process_id
}

/*
Return true when a value is a signed integer.
*/
isIntegerValue(test_value)
{
    return RegExMatch(test_value, "^-?\d+$")
}

/*
Return true when a value is a positive integer.
*/
isPositiveIntegerValue(test_value)
{
    return RegExMatch(test_value, "^\d+$") && test_value > 0
}

/*
Test whether part of a rectangle is visible on any monitor.
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

/*
Show one tray notification.
*/
showTrayTip(title_text, body_text, icon_number := 1)
{
    TrayTip, %title_text%, %body_text%, 4, %icon_number%
}

/*
Run a temporary structure and pairing test.
*/
runSelfTest()
{
    test_root := A_Temp . "\Gallery-Slideshow-Manager-Bridge-Test-" . A_TickCount
    gallery_one := test_root . "\A\Parent A\1 Gallery 1080"
    gallery_two := test_root . "\A\Parent A\2 Gallery 2160"

    FileCreateDir, %gallery_one%
    FileCreateDir, %gallery_two%
    FileAppend, test, % gallery_one . "\a.jpg"
    FileAppend, test, % gallery_two . "\b.png"
    FileAppend, test, % test_root . "\A\Parent A\1 video 2160.mp4"
    FileAppend, test, % test_root . "\A\Parent A\2 video 1080.wmv"

    test_failures := []

    if (getFirstIntegerFromName(gallery_one) != 1)
    {
        test_failures.Push("Gallery first integer")
    }

    paired_video := findPairedVideo(test_root . "\A\Parent A", gallery_one)

    if (!InStr(toLowerText(paired_video), "1 video 2160.mp4"))
    {
        test_failures.Push("Video pairing")
    }

    test_images := getDirectImagePaths(gallery_one)

    if (test_images.Length() != 1)
    {
        test_failures.Push("Direct image scan")
    }

    test_next_gallery := getNextGalleryPath(test_root . "\A\Parent A", gallery_one)

    if (toLowerText(test_next_gallery) != toLowerText(gallery_two))
    {
        test_failures.Push("Next gallery")
    }

    test_prefix := test_root . "\prepared"

    if (!prepareGallerySlot(test_prefix, gallery_one) || !FileExist(test_prefix . ".ready"))
    {
        test_failures.Push("Prepared list")
    }

    FileRemoveDir, %test_root%, 1

    if (test_failures.Length() < 1)
    {
        MsgBox, 64, Gallery Slideshow Manager Bridge Test, PASS
        return true
    }

    failure_text := ""

    for failure_index, failure_name in test_failures
    {
        failure_text .= failure_name . "`n"
    }

    MsgBox, 16, Gallery Slideshow Manager Bridge Test, % "FAIL:`n`n" . failure_text
    return false
}
