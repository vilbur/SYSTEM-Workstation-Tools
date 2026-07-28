/* -------------------------
    Path Configurator v0.04
    Persistent paths plus dynamic environments, executables and links
-------------------------
*/ 

#NoEnv
#SingleInstance Force
#Persistent
global log_file := A_ScriptDir . "\\Path-Config-Apply-Log.md"

writeLog(msg, color="") {
    global log_file
    if (color == "red")
        FileAppend, <span style="color:red">%msg%</span>`n`n, %log_file%
    else
        FileAppend, %msg%`n`n, %log_file%
}

resetLog() {
    global log_file
    FileDelete, %log_file%
    FileAppend, # Apply Execution Log - %A_Now%`n`n, %log_file%
}

SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

if FileExist("Path-Config.ico")
    Menu, Tray, Icon, Path-Config.ico
else if FileExist("System-Config.ico")
    Menu, Tray, Icon, System-Config.ico

global g_script_version   := "0.04"
global g_ini_file         := A_ScriptDir "\Path-Config.ini"
global g_legacy_ini_file  := A_ScriptDir "\System-Config.ini"
global g_tab_names        := []
global g_tab_data         := {}
global g_persistent_paths := []
global g_current_tab      := 1
global g_current_ui_tab   := 1
global g_current_mode     := "Config"
global g_tab_menu         := "TabMenu"
global g_startup_prefix   := "PathConfig_Path_"

global dark_background := "1E1E1E"
global border_color := "2D2D2D"
global font_color := "D6D6D6"

; State tracking for bug-free path redraws
global g_path_states := {}


; Right Click event for Tab Menu
global g_dark_brush := DllCall("CreateSolidBrush", "UInt", 0x1E1E1E, "Ptr")
OnMessage(0x204, "WM_RBUTTONDOWN")
OnMessage(0x0133, "onDarkControlColor")
OnMessage(0x0138, "onDarkControlColor") 

; ==========================================
;         INIT & DATA LOADING
; ==========================================
loadState()

Menu, %g_tab_menu%, Add, Add New Program Tab, onAddProgram
Menu, %g_tab_menu%, Add, Rename Current Tab, onRenameTab
Menu, %g_tab_menu%, Add, Delete Current Tab, onDeleteTab

global mode_color := (g_current_mode == "Config") ? "FF9900" : "5599FF"

; ==========================================
;         GUI CONSTRUCTION
; ==========================================
Gui, +hwndh_main_gui +LastFound
Gui, Color, %dark_background%, %dark_background%
Gui, Margin, 14, 14
Gui, Font, s12 c%font_color%, Segoe UI

setDarkTitleBar(h_main_gui)

; Mode Selection & Save State at TOP
Gui, Add, GroupBox, x20 y10 w1160 h80 c%mode_color%, Execution Mode
Gui, Font, s12 Bold
Gui, Add, Button, vmode_btn gtoggleMode x40 y35 w250 h40 hwndh_mode -Theme +Border, MODE: %g_current_mode%

if (g_current_mode == "Config") {
    Gui, Add, Button, gonManualSave x300 y35 w250 h40 hwndh_save -Theme +Border, SAVE STATE
    setDarkControl(h_save)
} else {
    Gui, Add, Button, x300 y35 w250 h40 gonApplyConfigs hwndh_apply -Theme +Border, APPLY ALL
    setDarkControl(h_apply)
}
setDarkControl(h_mode)
Gui, Font, s12 Norm

tab_str := "Paths|"
For tab_idx, tab_name in g_tab_names
    tab_str .= tab_name "|"

Gui, Add, Tab3, vmain_tab gonTabChanged x20 y110 w1160 h670 hwndh_tab AltSubmit Choose%g_current_ui_tab%, %tab_str%
DllCall("uxtheme\SetWindowTheme", "Ptr", h_tab, "Str", "DarkMode_Explorer", "Ptr", 0)
GuiControl, +cDDDDDD, main_tab

; Fixed, non-dynamic Paths tab (UI tab 1).
Gui, Tab, 1
y_pos := 160
Gui, Font, Bold s14 c%mode_color%
if (g_current_mode == "Config")
    Gui, Add, Text, gonAddPersistentPath x40 y%y_pos% BackgroundTrans, + ADD FILE PATH
else
    Gui, Add, Text, x40 y%y_pos% BackgroundTrans, Persistent Paths
Gui, Font, Norm s10 c888888
header_y := y_pos + 38
Gui, Add, Text, x40 y%header_y% w500, File Path
Gui, Add, Text, x630 y%header_y% w190, Environment Variable
Gui, Add, Text, x830 y%header_y% w110, Run as Admin
Gui, Add, Text, x960 y%header_y% w120, Run on Startup
Gui, Font, Norm s11 c%font_color%
y_pos += 65
For i, row in g_persistent_paths {
    var_path := "persistent_path_" i
    var_env := "persistent_env_" i
    var_admin := "persistent_admin_" i
    var_startup := "persistent_startup_" i
    if (g_current_mode == "Config") {
        var_browse := "btn_persistent_browse_" i
        var_delete := "btn_persistent_delete_" i
        Gui, Add, Edit, v%var_path% x40 y%y_pos% w500 h28 -E0x200 -Theme +Border, % row.path
        Gui, Add, Button, v%var_browse% gonBrowsePersistentPath hwndh_pb x550 y%y_pos% w70 h28 -Theme +Border, Browse
        Gui, Add, Edit, v%var_env% x630 y%y_pos% w190 h28 -E0x200 -Theme +Border, % row.env_var
        admin_options := row.run_as_admin ? "Checked" : ""
        startup_options := row.run_on_startup ? "Checked" : ""
        Gui, Add, Checkbox, v%var_admin% x850 y%y_pos% w70 h28 %admin_options%, Yes
        Gui, Add, Checkbox, v%var_startup% x985 y%y_pos% w70 h28 %startup_options%, Yes
        if (i > 1) {
            Gui, Add, Button, v%var_delete% gonDeletePersistentPath hwndh_pd x1090 y%y_pos% w30 h28 -Theme +Border, X
            setDarkControl(h_pd)
        }
        setDarkControl(h_pb)
    } else {
        admin_text := row.run_as_admin ? "Yes" : "No"
        startup_text := row.run_on_startup ? "Yes" : "No"
        Gui, Add, Text, v%var_path% x40 y%y_pos% w570 h28 c%font_color%, % row.path
        Gui, Add, Text, v%var_env% x630 y%y_pos% w190 h28 c%font_color%, % row.env_var
        Gui, Add, Text, x850 y%y_pos% w70 h28 c%font_color%, %admin_text%
        Gui, Add, Text, x985 y%y_pos% w70 h28 c%font_color%, %startup_text%
    }
    y_pos += 36
}
if (g_current_mode == "Apply") {
    Gui, Font, Bold s12 cFFFFFF
    Gui, Add, Button, gonApplyPaths hwndh_apply_paths x920 y720 w240 h40 -Theme +Border, APPLY PATHS
    setDarkControl(h_apply_paths)
    Gui, Font, Norm s12 c%font_color%
}

For tab_idx, tab_name in g_tab_names 
{
    ui_tab_idx := tab_idx + 1
    Gui, Tab, %ui_tab_idx% 
        data := g_tab_data[tab_name]
        y_pos := 155
        
        ; SECTION BUILDER LOGIC
        sections := ["Paths", "Envs", "Execs", "Links"]
        For sec_idx, sec_name in sections {
            Gui, Font, Bold s15 c%mode_color%
            if (g_current_mode == "Config") {
                if (sec_name == "Paths")
                    Gui, Add, Text, gonAddPath x40 y%y_pos% BackgroundTrans, + ADD %sec_name%
                else if (sec_name == "Envs")
                    Gui, Add, Text, gonAddEnv x40 y%y_pos% BackgroundTrans, + ADD Env
                else if (sec_name == "Execs")
                    Gui, Add, Text, gonAddExec x40 y%y_pos% BackgroundTrans, + ADD Exec
                else if (sec_name == "Links")
                    Gui, Add, Text, gonAddLink x40 y%y_pos% BackgroundTrans, + ADD Link
            } else {
                Gui, Add, Text, x40 y%y_pos% BackgroundTrans, %sec_idx%. %sec_name%
            }
            Gui, Font, Norm s12 c%font_color%
            y_pos += 38
            
            if (sec_name == "Paths") {
                For i, path_item in data.paths {
                    path_name := path_item.name
                    path_value := path_item.val
                    var_n := "edit_path_name_" tab_idx "_" i
                    var_edit := "edit_path_" tab_idx "_" i
                    
                    if (g_current_mode == "Config") {
                        var_d := "btn_path_d_" tab_idx "_" i
                        var_f := "btn_path_f_" tab_idx "_" i
                        var_del := "btn_del_path_" tab_idx "_" i
                        Gui, Add, Edit, v%var_n% x40 y%y_pos% w180 h28 -E0x200 -Theme +Border, %path_name%
                        Gui, Add, Edit, v%var_edit% x230 y%y_pos% w780 h28 -E0x200 -Theme +Border, %path_value%
                        Gui, Add, Button, v%var_d% gonBrowsePathDir hwndh_d x1020 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f% gonBrowsePathFile hwndh_f x1055 y%y_pos% w30 h28 -Theme +Border, F
                        if (i > 1) {
                            Gui, Add, Button, v%var_del% gonDeletePath hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d), setDarkControl(h_f)
                    } else {
                        Gui, Add, Text, v%var_n% x40 y%y_pos% w180 h28 c%font_color%, %path_name%
                        Gui, Add, Text, v%var_edit% x230 y%y_pos% w800 h28 c%font_color%, %path_value%
                    }
                    y_pos += 33
                }
                y_pos += 15
                
            } else if (sec_name == "Envs") {
                For i, e in data.envs {
                    var_n := "edit_env_name_" tab_idx "_" i
                    var_v := "edit_env_val_" tab_idx "_" i
                    
                    if (g_current_mode == "Config") {
                        var_d := "btn_env_d_" tab_idx "_" i
                        var_f := "btn_env_f_" tab_idx "_" i
                        var_del := "btn_del_env_" tab_idx "_" i
                        Gui, Add, Edit, v%var_n% x40 y%y_pos% w200 h28 -E0x200 -Theme +Border, % e.name
                        Gui, Add, Edit, v%var_v% x250 y%y_pos% w760 h28 -E0x200 -Theme +Border, % e.val
                        Gui, Add, Button, v%var_d% gonBrowseEnvDir hwndh_d x1020 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f% gonBrowseEnvFile hwndh_f x1055 y%y_pos% w30 h28 -Theme +Border, F
                        if (i > 0) {
                            Gui, Add, Button, v%var_del% gonDeleteEnv hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d), setDarkControl(h_f)
                    } else {
                        Gui, Font, Bold
                        Gui, Add, Text, v%var_n% x40 y%y_pos% w200 h28 c%font_color%, % e.name
                        Gui, Font, Norm
                        Gui, Add, Text, v%var_v% x250 y%y_pos% w780 h28 c%font_color%, % e.val
                    }
                    y_pos += 33
                }
                y_pos += 15
                
            } else if (sec_name == "Execs") {
                For i, x in data.execs {
                    var_edit := "edit_exec_" tab_idx "_" i
                    if (g_current_mode == "Config") {
                        var_d := "btn_exec_d_" tab_idx "_" i
                        var_f := "btn_exec_f_" tab_idx "_" i
                        var_del := "btn_del_exec_" tab_idx "_" i
                        Gui, Add, Edit, v%var_edit% x40 y%y_pos% w970 h28 -E0x200 -Theme +Border, %x%
                        Gui, Add, Button, v%var_d% gonBrowseExecDir hwndh_d x1020 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f% gonBrowseExecFile hwndh_f x1055 y%y_pos% w30 h28 -Theme +Border, F
                        if (i > 0) {
                            Gui, Add, Button, v%var_del% gonDeleteExec hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d), setDarkControl(h_f)
                    } else {
                        Gui, Add, Text, v%var_edit% x40 y%y_pos% w990 h28 c%font_color%, %x%
                    }
                    y_pos += 33
                }
                y_pos += 15
                
            } else if (sec_name == "Links") {
                if (data.links.Length() > 0) {
                    label_y := y_pos + 5
                    Gui, Font, Bold s12 c888888
                    if (g_current_mode == "Config") {
                        Gui, Add, Text, x40 y%label_y%, Source
                        Gui, Add, Text, x400 y%label_y%, Target Folder
                        Gui, Add, Text, x790 y%label_y%, Target Name
                        Gui, Add, Text, x980 y%label_y%, Type
                    } else {
                        Gui, Add, Text, x40 y%label_y%, Source
                        Gui, Add, Text, x420 y%label_y%, Deployed Link Path
                        Gui, Add, Text, x935 y%label_y%, Type
                    }
                    Gui, Font, Norm s12 c%font_color%
                    y_pos += 33
                }
                
                For i, l in data.links {
                    var_e_s := "edit_link_s_" tab_idx "_" i
                    var_e_td := "edit_link_tdir_" tab_idx "_" i
                    var_e_type := "edit_link_type_" tab_idx "_" i
                    
                    if (g_current_mode == "Config") {
                        var_e_tn := "edit_link_tname_" tab_idx "_" i
                        var_d_s := "btn_link_d_s_" tab_idx "_" i
                        var_f_s := "btn_link_f_s_" tab_idx "_" i
                        var_d_t := "btn_link_d_t_" tab_idx "_" i
                        var_del := "btn_del_link_" tab_idx "_" i
                        
                        type_str := "Shortcut|Symlink|Hardlink"
                        
                        Gui, Add, Edit, v%var_e_s% x40 y%y_pos% w280 h28 -E0x200 -Theme +Border, % l.src
                        Gui, Add, Button, v%var_d_s% gonBrowseLinkSD hwndh_d_s x325 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Button, v%var_f_s% gonBrowseLinkSF hwndh_f_s x360 y%y_pos% w30 h28 -Theme +Border, F
                        Gui, Add, Edit, v%var_e_td% x400 y%y_pos% w350 h28 -E0x200 -Theme +Border, % l.tgt_dir
                        Gui, Add, Button, v%var_d_t% gonBrowseLinkTD hwndh_d_t x755 y%y_pos% w30 h28 -Theme +Border, D
                        Gui, Add, Edit, v%var_e_tn% x790 y%y_pos% w180 h28 -E0x200 -Theme +Border, % l.tgt_name
                        
                        Gui, Add, DropDownList, v%var_e_type% hwndh_type x980 y%y_pos% w100 r3 -Theme +Background%dark_background% c%font_color%, %type_str%
                        if (l.type != "")
                            GuiControl, ChooseString, %var_e_type%, % l.type
                        else
                            GuiControl, Choose, %var_e_type%, 1
                        
                        if (i > 0) {
                            Gui, Add, Button, v%var_del% gonDeleteLink hwndh_del x1090 y%y_pos% w30 h28 -Theme +Border, X
                            setDarkControl(h_del)
                        }
                        setDarkControl(h_d_s), setDarkControl(h_f_s), setDarkControl(h_d_t)
                    } else {
                        if (l.tgt_dir != "")
                            full_tgt := l.tgt_dir . (SubStr(l.tgt_dir, 0) == "\" ? "" : "\") . l.tgt_name
                        else
                            full_tgt := l.tgt_name
                        if (l.type == "Shortcut" && !InStr(full_tgt, ".lnk"))
                            full_tgt .= ".lnk"
                        
                        Gui, Add, Text, v%var_e_s% x40 y%y_pos% w360 h28 c%font_color%, % l.src
                        Gui, Add, Text, v%var_e_td% x420 y%y_pos% w500 h28 c%font_color%, % full_tgt
                        Gui, Add, Text, v%var_e_type% x935 y%y_pos% w100 h28 c%font_color%, % l.type
                    }
                    y_pos += 33
                }
                y_pos += 15
            }
        }
        
        if (g_current_mode == "Apply") {
            Gui, Font, Bold s12 cFFFFFF
            hwnd_var := "h_app_" tab_idx
            Gui, Add, Button, hwnd%hwnd_var% gonApplyCurrentTab x920 y720 w240 h40 -Theme +Border, Apply %tab_name%
            handle := %hwnd_var%
            setDarkControl(handle)
            Gui, Font, Norm s12 c%font_color%
        }
    }
Gui, Tab 
Gui, Show, w1200 h800, Path-Config v%g_script_version%

SetTimer, pathTimer, 500
return

; ==========================================
;         RIGHT-CLICK & TAB MENU LOGIC
; ==========================================
toLower(value) {
    StringLower, lowered, value
    return lowered
}

WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global h_tab, g_tab_menu, g_current_ui_tab
    if (hwnd == h_tab && g_current_ui_tab > 1)
        Menu, %g_tab_menu%, Show
}

onTabChanged:
    captureAllRows()
    Gui, Submit, NoHide
    g_current_ui_tab := main_tab
    if (g_current_ui_tab > 1)
        g_current_tab := g_current_ui_tab - 1
    saveState()
return

toggleMode:
    Gui, Submit, NoHide
    captureAllRows()
    saveState()
    g_current_mode := (g_current_mode == "Config") ? "Apply" : "Config"
    IniWrite, %g_current_mode%, %g_ini_file%, Settings, Mode
    Reload
return

onAddProgram:
    FileSelectFile, exe_path, 3,, Browse for Main Executable (Sets Tab Name), Executables (*.exe)
    if (exe_path == "")
        return
    captureAllRows()
    SplitPath, exe_path, out_file_name, out_dir, out_ext, out_name_no_ext
    SplitPath, out_dir, out_folder_name
    tab_name := out_folder_name
    if (tab_name == "")
        tab_name := out_name_no_ext
    if (toLower(tab_name) == "paths")
        tab_name := tab_name . "_Program"
    Loop {
        is_dup := false
        For k, v in g_tab_names {
            if (toLower(v) == toLower(tab_name)) {
                is_dup := true
                tab_name := tab_name "_2"
                break
            }
        }
        if (!is_dup)
            break
    }
    g_tab_names.Push(tab_name)
    g_tab_data[tab_name] := {"paths": [{"name": out_name_no_ext, "val": exe_path}], "envs": [], "execs": [], "links": []}
    g_current_tab := g_tab_names.Length()
    g_current_ui_tab := g_current_tab + 1
    saveState()
    Reload
return

onRenameTab:
    if (g_current_ui_tab == 1)
        return
    captureAllRows()
    old_name := g_tab_names[g_current_tab]
    InputBox, new_name, Rename Tab, Enter new name for tab "%old_name%":,, 300, 150
    new_name := Trim(new_name)
    if (ErrorLevel || new_name == "" || new_name == old_name)
        return
    if (toLower(new_name) == "paths" || InStr(new_name, "|") || InStr(new_name, "[") || InStr(new_name, "]")) {
        MsgBox, 48, Invalid Name, Paths is reserved and tab names cannot contain | [ or ].
        return
    }
    For tab_index, existing_name in g_tab_names {
        if (tab_index != g_current_tab && toLower(existing_name) == toLower(new_name)) {
            MsgBox, 48, Invalid Name, A program tab with that name already exists.
            return
        }
    }
    g_tab_names[g_current_tab] := new_name
    g_tab_data[new_name] := g_tab_data[old_name]
    g_tab_data.Delete(old_name)
    captureAllRows()
    saveState()
    Reload
return

onDeleteTab:
    if (g_current_ui_tab == 1)
        return
    if (g_tab_names.Length() <= 1) {
        MsgBox, 48, Denied, At least one program tab must remain.
        return
    }
    target_name := g_tab_names[g_current_tab]
    MsgBox, 52, Confirm Delete, Are you sure you want to completely delete "%target_name%"?
    IfMsgBox, No
        return
    g_tab_data.Delete(target_name)
    g_tab_names.RemoveAt(g_current_tab)
    g_current_tab := 1
    g_current_ui_tab := 2
    saveState()
    Reload
return


; ==========================================
;         ROW ADD/DELETE/BROWSE EVENTS
; ==========================================
onAddPersistentPath:
    captureAllRows()
    g_persistent_paths.Push({"path":"", "env_var":"", "run_as_admin":0, "run_on_startup":0})
    g_current_ui_tab := 1
    saveState()
    Reload
return

onDeletePersistentPath:
    parts := StrSplit(A_GuiControl, "_")
    row_idx := parts[4]
    if (row_idx <= 1)
        return
    captureAllRows()
    g_persistent_paths.RemoveAt(row_idx)
    g_current_ui_tab := 1
    saveState()
    Reload
return

onBrowsePersistentPath:
    parts := StrSplit(A_GuiControl, "_")
    row_idx := parts[4]
    var_path := "persistent_path_" row_idx
    GuiControlGet, current_val,, %var_path%
    FileSelectFile, selected, 3, %current_val%, Select File
    if (selected != "")
        GuiControl,, %var_path%, %selected%
return

onAddPath:
    captureAllRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].paths))
        g_tab_data[g_tab_names[g_current_tab]].paths := []
    g_tab_data[g_tab_names[g_current_tab]].paths.Push({"name":"", "val":""})
    saveState()
    Reload
return

onAddEnv:
    captureAllRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].envs))
        g_tab_data[g_tab_names[g_current_tab]].envs := []
    g_tab_data[g_tab_names[g_current_tab]].envs.Push({"name":"", "val":""})
    saveState()
    Reload
return

onAddExec:
    captureAllRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].execs))
        g_tab_data[g_tab_names[g_current_tab]].execs := []
    g_tab_data[g_tab_names[g_current_tab]].execs.Push("")
    saveState()
    Reload
return

onAddLink:
    captureAllRows()
    if (!IsObject(g_tab_data[g_tab_names[g_current_tab]].links))
        g_tab_data[g_tab_names[g_current_tab]].links := []
    g_tab_data[g_tab_names[g_current_tab]].links.Push({"src":"", "tgt_dir":"", "tgt_name":"", "type":"Shortcut"})
    saveState()
    Reload
return

onDeletePath:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureAllRows()
    g_tab_data[g_tab_names[tab_idx]].paths.RemoveAt(row_idx)
    saveState()
    Reload
return

onDeleteEnv:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureAllRows()
    g_tab_data[g_tab_names[tab_idx]].envs.RemoveAt(row_idx)
    saveState()
    Reload
return

onDeleteExec:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureAllRows()
    g_tab_data[g_tab_names[tab_idx]].execs.RemoveAt(row_idx)
    saveState()
    Reload
return

onDeleteLink:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    captureAllRows()
    g_tab_data[g_tab_names[tab_idx]].links.RemoveAt(row_idx)
    saveState()
    Reload
return

; --- BROWSE ---
onBrowsePathDir:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_path_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseExecDir:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_exec_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseEnvDir:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_env_val_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseLinkSD:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[5], row_idx := parts[6]
    var_edit := "edit_link_s_" tab_idx "_" row_idx
    var_tname := "edit_link_tname_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Source Folder
    if (selected != "") {
        GuiControl,, %var_edit%, %selected%
        SplitPath, selected, out_name
        GuiControl,, %var_tname%, %out_name%
    }
return

onBrowseLinkTD:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[5], row_idx := parts[6]
    var_edit := "edit_link_tdir_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFolder, selected, *%current_val%, 3, Select Target Folder
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowsePathFile:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_path_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select File
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseExecFile:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_exec_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select File, Executables (*.exe)
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseEnvFile:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[4], row_idx := parts[5]
    var_edit := "edit_env_val_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select File
    if (selected != "")
        GuiControl,, %var_edit%, %selected%
return

onBrowseLinkSF:
    parts := StrSplit(A_GuiControl, "_"), tab_idx := parts[5], row_idx := parts[6]
    var_edit := "edit_link_s_" tab_idx "_" row_idx
    var_tname := "edit_link_tname_" tab_idx "_" row_idx
    GuiControlGet, current_val,, %var_edit%
    FileSelectFile, selected, 3, %current_val%, Select Source File
    if (selected != "") {
        GuiControl,, %var_edit%, %selected%
        SplitPath, selected, out_name
        GuiControl,, %var_tname%, %out_name%
    }
return

; ==========================================
;         LIVE VERIFICATION
; ==========================================
pathTimer:
    checkPaths()
return

updateControlColor(var, path, is_env_name := false) {
    global g_path_states
    if (is_env_name) {
        state := (path == "") ? -1 : 0
        if (path != "") {
            EnvGet, env_check, %path%
            if (env_check != "")
                state := 1
        }
    } else {
        state := (path == "") ? -1 : (FileExist(path) ? 1 : 0)
    }
    
    if (g_path_states[var] != state) {
        g_path_states[var] := state
        if (state == 1)
            GuiControl, +c55FF55, %var%
        else if (state == 0)
            GuiControl, +cFF4444, %var%
        else
            GuiControl, +cD6D6D6, %var%
        GuiControl, +Redraw, %var%
    }
}

checkPaths() {
    global g_current_tab, g_current_mode, g_persistent_paths
    For i, row in g_persistent_paths {
        persistent_var := "persistent_path_" i
        GuiControlGet, persistent_value,, %persistent_var%
        if (!ErrorLevel)
            updateControlColor(persistent_var, persistent_value)
    }

    Loop, 50 {
        edit_var := "edit_path_" g_current_tab "_" A_Index
        GuiControlGet, path_val,, %edit_var%
        if (ErrorLevel) 
            break
        updateControlColor(edit_var, path_val)
    }
    
    Loop, 50 {
        edit_var := "edit_exec_" g_current_tab "_" A_Index
        GuiControlGet, path_val,, %edit_var%
        if (ErrorLevel) 
            break
        updateControlColor(edit_var, path_val)
    }
    
    Loop, 50 {
        name_var := "edit_env_name_" g_current_tab "_" A_Index
        GuiControlGet, name_val,, %name_var%
        if (ErrorLevel) 
            break
        if (g_current_mode == "Apply")
            updateControlColor(name_var, name_val, true)
            
        edit_var := "edit_env_val_" g_current_tab "_" A_Index
        GuiControlGet, path_val,, %edit_var%
        if (InStr(path_val, ":\") || InStr(path_val, "\\"))
            updateControlColor(edit_var, path_val)
    }
    
    Loop, 50 {
        edit_src := "edit_link_s_" g_current_tab "_" A_Index
        edit_tdir := "edit_link_tdir_" g_current_tab "_" A_Index
        GuiControlGet, src_val,, %edit_src%
        if (ErrorLevel) 
            break
        updateControlColor(edit_src, src_val)
        
        GuiControlGet, tgt_val,, %edit_tdir%
        updateControlColor(edit_tdir, tgt_val)
    }
}

; ==========================================
;         STATE MANAGEMENT CORE
; ==========================================
onManualSave:
    captureAllRows()
    saveState()
    MsgBox, 64, Saved, Persistent paths and dynamic configurations have been written to Path-Config.ini.
return

onApplyPaths:
    captureAllRows()
    saveState()
    resetLog()
    result := applyPersistentPaths()
    if (result.env_changed)
        SendMessage, 0x1A, 0, "Environment",, ahk_id 0xFFFF
    showPersistentApplyResult("Apply Paths", result)
return

onApplyConfigs:
    captureAllRows()
    saveState()
    resetLog()
    persistent_result := applyPersistentPaths()
    env_updated := persistent_result.env_changed
    dynamic_tabs_applied := 0
    For k, tab_name in g_tab_names {
        if (applyTabConfig(tab_name))
            env_updated := true
        dynamic_tabs_applied++
    }
    if (env_updated)
        SendMessage, 0x1A, 0, "Environment",, ahk_id 0xFFFF
    message := "Persistent actions completed: " . persistent_result.success_count
    message .= "`nPersistent errors: " . persistent_result.error_count
    message .= "`nDynamic program tabs applied: " . dynamic_tabs_applied
    if (persistent_result.error_count > 0)
        MsgBox, 48, Apply All, %message%
    else
        MsgBox, 64, Apply All, %message%
return

onApplyCurrentTab:
    if (g_current_ui_tab == 1) {
        Gosub, onApplyPaths
        return
    }
    captureAllRows()
    saveState()
    current_tab_name := g_tab_names[g_current_tab]
    if (applyTabConfig(current_tab_name))
        SendMessage, 0x1A, 0, "Environment",, ahk_id 0xFFFF
    MsgBox, 64, Apply Tab, Applied configurations for %current_tab_name%.
return

GuiClose:
    captureAllRows()
    saveState()
ExitApp

captureAllRows() {
    capturePersistentRows()
    captureDynamicRows()
}

capturePersistentRows() {
    global
    if (g_current_mode == "Apply")
        return
    Gui, Submit, NoHide
    For i, row in g_persistent_paths {
        var_path := "persistent_path_" i
        var_env := "persistent_env_" i
        var_admin := "persistent_admin_" i
        var_startup := "persistent_startup_" i
        g_persistent_paths[i].path := %var_path%
        g_persistent_paths[i].env_var := %var_env%
        g_persistent_paths[i].run_as_admin := %var_admin% ? 1 : 0
        g_persistent_paths[i].run_on_startup := %var_startup% ? 1 : 0
    }
}

captureDynamicRows() {
    global
    if (g_current_mode == "Apply")
        return
        
    Gui, Submit, NoHide
    For tab_idx, tab_name in g_tab_names {
        data := g_tab_data[tab_name]
        For i, p in data.paths {
            var_n := "edit_path_name_" tab_idx "_" i
            var_edit := "edit_path_" tab_idx "_" i
            data.paths[i].name := %var_n%
            data.paths[i].val := %var_edit%
        }
        For i, e in data.envs {
            var_name := "edit_env_name_" tab_idx "_" i
            var_val := "edit_env_val_" tab_idx "_" i
            data.envs[i].name := %var_name%
            data.envs[i].val := %var_val%
        }
        For i, x in data.execs {
            var_edit := "edit_exec_" tab_idx "_" i
            data.execs[i] := %var_edit%
        }
        For i, l in data.links {
            var_src := "edit_link_s_" tab_idx "_" i
            var_tdir := "edit_link_tdir_" tab_idx "_" i
            var_tname := "edit_link_tname_" tab_idx "_" i
            var_type := "edit_link_type_" tab_idx "_" i
            data.links[i].src := %var_src%
            data.links[i].tgt_dir := %var_tdir%
            data.links[i].tgt_name := %var_tname%
            data.links[i].type := %var_type%
        }
    }
}

saveState() {
    global
    FileDelete, %g_ini_file% 
    tab_str := ""
    For k, v in g_tab_names
        tab_str .= (A_Index=1 ? "" : "|") . v
    IniWrite, %tab_str%, %g_ini_file%, Settings, Tabs
    IniWrite, %g_script_version%, %g_ini_file%, Settings, SchemaVersion
    IniWrite, %g_current_ui_tab%, %g_ini_file%, Settings, ActiveTab
    IniWrite, %g_current_tab%, %g_ini_file%, Settings, ActiveProgramTab
    IniWrite, %g_current_mode%, %g_ini_file%, Settings, Mode

    For i, row in g_persistent_paths {
        IniWrite, % row.path, %g_ini_file%, PersistentPaths, %i%_Path
        IniWrite, % row.env_var, %g_ini_file%, PersistentPaths, %i%_EnvVar
        IniWrite, % row.run_as_admin, %g_ini_file%, PersistentPaths, %i%_RunAsAdmin
        IniWrite, % row.run_on_startup, %g_ini_file%, PersistentPaths, %i%_RunOnStartup
    }
    
    For k, tab_name in g_tab_names {
        data := g_tab_data[tab_name]
        For i, p in data.paths {
            IniWrite, % p.name, %g_ini_file%, %tab_name%_Paths, %i%_Name
            IniWrite, % p.val,  %g_ini_file%, %tab_name%_Paths, %i%_Val
        }
        For i, e in data.envs {
            IniWrite, % e.name, %g_ini_file%, %tab_name%_Envs, %i%_Name
            IniWrite, % e.val,  %g_ini_file%, %tab_name%_Envs, %i%_Val
        }
        For i, x in data.execs
            IniWrite, %x%, %g_ini_file%, %tab_name%_Execs, %i%
        For i, l in data.links {
            IniWrite, % l.src, %g_ini_file%, %tab_name%_Links, %i%_Src
            IniWrite, % l.tgt_dir, %g_ini_file%, %tab_name%_Links, %i%_TgtDir
            IniWrite, % l.tgt_name, %g_ini_file%, %tab_name%_Links, %i%_TgtName
            IniWrite, % l.type, %g_ini_file%, %tab_name%_Links, %i%_Type
        }
    }
}

loadPersistentPaths(source_ini) {
    global g_persistent_paths
    g_persistent_paths := []
    Loop {
        row_index := A_Index
        IniRead, path_value, %source_ini%, PersistentPaths, %row_index%_Path, ||END||
        IniRead, legacy_path, %source_ini%, PersistentPaths, %row_index%, ||END||
        if (path_value == "||END||" && legacy_path == "||END||")
            break
        if (path_value == "||END||")
            path_value := legacy_path
        IniRead, env_var, %source_ini%, PersistentPaths, %row_index%_EnvVar, %A_Space%
        IniRead, run_as_admin, %source_ini%, PersistentPaths, %row_index%_RunAsAdmin, 0
        IniRead, run_on_startup, %source_ini%, PersistentPaths, %row_index%_RunOnStartup, 0
        g_persistent_paths.Push({"path":path_value, "env_var":env_var
            , "run_as_admin":run_as_admin ? 1 : 0, "run_on_startup":run_on_startup ? 1 : 0})
    }
    if (g_persistent_paths.Length() == 0)
        g_persistent_paths.Push({"path":"", "env_var":"", "run_as_admin":0, "run_on_startup":0})
}

loadState() {
    global
    source_ini := FileExist(g_ini_file) ? g_ini_file : g_legacy_ini_file
    if !FileExist(source_ini) {
        g_tab_names := ["PROGRAMS"]
        g_tab_data := {"PROGRAMS": {"paths": [{"name": "", "val": ""}], "envs": [], "execs": [], "links": []}}
        g_persistent_paths := [{"path":"", "env_var":"", "run_as_admin":0, "run_on_startup":0}]
        g_current_tab := 1
        g_current_ui_tab := 1
        g_current_mode := "Config"
        return
    }
    loadPersistentPaths(source_ini)
    IniRead, tabs, %source_ini%, Settings, Tabs, %A_Space%
    source_tabs := StrSplit(tabs, "|")
    g_tab_names := []
    For _, source_tab_name in source_tabs {
        if (source_tab_name != "" && source_tab_name != "WINDOWS" && toLower(source_tab_name) != "paths")
            g_tab_names.Push(source_tab_name)
    }
    if (g_tab_names.Length() == 0)
        g_tab_names.Push("PROGRAMS")

    IniRead, saved_active_tab, %source_ini%, Settings, ActiveTab, 1
    IniRead, schema_version, %source_ini%, Settings, SchemaVersion, %A_Space%
    IniRead, saved_program_tab, %source_ini%, Settings, ActiveProgramTab, 1
    IniRead, persistent_probe, %source_ini%, PersistentPaths, 1_Path, ||END||
    if (persistent_probe == "||END||")
        IniRead, persistent_probe, %source_ini%, PersistentPaths, 1, ||END||

    if (schema_version == "0.04" || persistent_probe != "||END||")
        g_current_ui_tab := saved_active_tab
    else {
        legacy_program_tab := (source_ini == g_legacy_ini_file) ? saved_active_tab - 1 : saved_active_tab
        g_current_ui_tab := legacy_program_tab + 1
    }
    if (g_current_ui_tab < 1 || g_current_ui_tab > g_tab_names.Length() + 1)
        g_current_ui_tab := 1
    g_current_tab := (g_current_ui_tab > 1) ? g_current_ui_tab - 1 : saved_program_tab
    if (g_current_tab < 1 || g_current_tab > g_tab_names.Length())
        g_current_tab := 1
    IniRead, g_current_mode, %source_ini%, Settings, Mode, Config
    g_tab_data := {}
    For k, tab_name in g_tab_names {
        g_tab_data[tab_name] := {"paths":[], "envs":[], "execs":[], "links":[]}
        Loop {
            IniRead, n, %source_ini%, %tab_name%_Paths, %A_Index%_Name, ||END||
            if (n == "||END||") {
                IniRead, val, %source_ini%, %tab_name%_Paths, %A_Index%, ||END||
                if (val == "||END||")
                    break
                g_tab_data[tab_name].paths.Push({"name": "", "val": val})
            } else {
                IniRead, v, %source_ini%, %tab_name%_Paths, %A_Index%_Val, %A_Space%
                g_tab_data[tab_name].paths.Push({"name": n, "val": v})
            }
        }
        if (g_tab_data[tab_name].paths.Length() == 0)
            g_tab_data[tab_name].paths.Push({"name": "", "val": ""})
            
        Loop {
            IniRead, n, %source_ini%, %tab_name%_Envs, %A_Index%_Name, ||END||
            if (n == "||END||")
                break
            IniRead, v, %source_ini%, %tab_name%_Envs, %A_Index%_Val, %A_Space%
            g_tab_data[tab_name].envs.Push({"name": n, "val": v})
        }
        Loop {
            IniRead, x, %source_ini%, %tab_name%_Execs, %A_Index%, ||END||
            if (x == "||END||")
                break
            g_tab_data[tab_name].execs.Push(x)
        }
        Loop {
            IniRead, src, %source_ini%, %tab_name%_Links, %A_Index%_Src, ||END||
            if (src == "||END||") {
                IniRead, l, %source_ini%, %tab_name%_Links, %A_Index%, ||END||
                if (l != "||END||") {
                    g_tab_data[tab_name].links.Push({"src": l, "tgt_dir": "", "tgt_name": "", "type": "Shortcut"})
                    continue
                }
                break
            }
            IniRead, tgt_dir, %source_ini%, %tab_name%_Links, %A_Index%_TgtDir, %A_Space%
            IniRead, tgt_name, %source_ini%, %tab_name%_Links, %A_Index%_TgtName, %A_Space%
            IniRead, type, %source_ini%, %tab_name%_Links, %A_Index%_Type, Shortcut
            
            if (tgt_dir == "" && tgt_name == "") {
                IniRead, old_tgt, %source_ini%, %tab_name%_Links, %A_Index%_Tgt, ||END||
                if (old_tgt != "||END||" && old_tgt != "") {
                    SplitPath, old_tgt, out_name, out_dir
                    tgt_dir := out_dir
                    tgt_name := out_name
                }
            }
            g_tab_data[tab_name].links.Push({"src": src, "tgt_dir": tgt_dir, "tgt_name": tgt_name, "type": type})
        }
    }
    if (source_ini != g_ini_file)
        saveState()
}

; ==========================================
;         THEMING & EXECUTION UTILITIES
; ==========================================
onDarkControlColor(w_param, l_param) {
    global g_dark_brush
    DllCall("SetTextColor", "Ptr", w_param, "UInt", 0xD6D6D6)
    DllCall("SetBkColor", "Ptr", w_param, "UInt", 0x1E1E1E)
    return g_dark_brush
}

setDarkControl(hwnd) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}

setDarkTitleBar(window_hwnd) {
    use_dark_mode := 1
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window_hwnd, "Int", 20, "Int*", use_dark_mode, "Int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", window_hwnd, "Int", 19, "Int*", use_dark_mode, "Int", 4)
}

newPersistentApplyResult() {
    return {"env_changed":false, "launched_count":0, "startup_count":0
        , "success_count":0, "error_count":0}
}

recordPersistentError(result, message) {
    result.error_count++
    writeLog("- FAILED: " . message, "red")
}

recordPersistentSuccess(result, message) {
    result.success_count++
    writeLog("- OK: " . message)
}

applyPersistentPaths() {
    global g_persistent_paths, g_startup_prefix
    result := newPersistentApplyResult()
    writeLog("## Persistent Paths")

    owned_values := []
    Loop, Reg, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, V
    {
        if (SubStr(A_LoopRegName, 1, StrLen(g_startup_prefix)) == g_startup_prefix)
            owned_values.Push(A_LoopRegName)
    }
    For _, value_name in owned_values {
        RegDelete, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, %value_name%
        if (ErrorLevel)
            recordPersistentError(result, "Could not remove owned startup entry: " . value_name)
    }

    For row_index, row in g_persistent_paths {
        path_value := Trim(row.path)
        env_var := Trim(row.env_var)
        run_as_admin := row.run_as_admin ? 1 : 0
        run_on_startup := row.run_on_startup ? 1 : 0

        if (env_var != "" && path_value != "") {
            RegWrite, REG_SZ, HKCU\Environment, %env_var%, %path_value%
            if (ErrorLevel)
                recordPersistentError(result, "Row " . row_index . " environment variable write failed: " . env_var)
            else {
                result.env_changed := true
                recordPersistentSuccess(result, "Environment variable " . env_var . " = " . path_value)
            }
        }

        if (run_on_startup) {
            if (path_value == "" || !FileExist(path_value)) {
                recordPersistentError(result, "Row " . row_index . " startup target is missing: " . path_value)
            } else {
                value_name := g_startup_prefix . row_index
                startup_command := buildStartupCommand(path_value, run_as_admin)
                RegWrite, REG_SZ, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, %value_name%, %startup_command%
                if (ErrorLevel)
                    recordPersistentError(result, "Row " . row_index . " startup entry could not be written.")
                else {
                    result.startup_count++
                    recordPersistentSuccess(result, "Startup entry " . value_name . " configured.")
                }
            }
        }

        if (run_as_admin) {
            if (path_value == "" || !FileExist(path_value)) {
                recordPersistentError(result, "Row " . row_index . " elevated launch target is missing: " . path_value)
            } else {
                SplitPath, path_value, , work_dir
                run_target := "*RunAs " . Chr(34) . path_value . Chr(34)
                Run, %run_target%, %work_dir%, UseErrorLevel
                if (ErrorLevel == "ERROR")
                    recordPersistentError(result, "Row " . row_index . " elevated launch failed: " . path_value)
                else {
                    result.launched_count++
                    recordPersistentSuccess(result, "Elevated launch requested: " . path_value)
                }
            }
        }
    }
    return result
}

buildStartupCommand(path_value, elevate) {
    quote := Chr(34)
    if (!elevate)
        return quote . path_value . quote
    escaped_path := StrReplace(path_value, "'", "''")
    return "powershell.exe -NoProfile -WindowStyle Hidden -Command " . quote
        . "Start-Process -FilePath '" . escaped_path . "' -Verb RunAs" . quote
}

showPersistentApplyResult(title, result) {
    message := "Completed: " . result.success_count
    message .= "`nEnvironment updates: " . (result.env_changed ? "Yes" : "No")
    message .= "`nElevated launches: " . result.launched_count
    message .= "`nStartup entries: " . result.startup_count
    message .= "`nErrors: " . result.error_count
    if (result.error_count > 0)
        MsgBox, 48, %title%, %message%
    else
        MsgBox, 64, %title%, %message%
}

applyTabConfig(tab_name) {
    global g_tab_data
    data := g_tab_data[tab_name]
    env_changed := false
    
    For i, p in data.paths {
        if (p.name != "" && p.val != "") {
            RegWrite, REG_SZ, HKCU\Environment, % p.name, % p.val
            env_changed := true
        }
    }
    For i, e in data.envs {
        if (e.name != "" && e.val != "") {
            RegWrite, REG_SZ, HKCU\Environment, % e.name, % e.val
            env_changed := true
        }
    }
    For i, x in data.execs {
        if (x == "")
            continue
        attr := FileExist(x)
        if (attr) {
            if (InStr(attr, "D")) {
                Loop, Files, %x%\*.exe
                    Run, "%A_LoopFileFullPath%", %x%
                Loop, Files, %x%\*.bat
                    Run, "%A_LoopFileFullPath%", %x%
            } else {
                SplitPath, x, , out_dir
                Run, "%x%", %out_dir%
            }
        }
    }
    For i, l in data.links {
        if (l.src != "" && l.tgt_dir != "" && l.tgt_name != "") {
            shortcut_name := l.tgt_name
            if (l.type == "Shortcut" && !InStr(shortcut_name, ".lnk"))
                shortcut_name .= ".lnk"
                
            shortcut_path := l.tgt_dir "\" shortcut_name
            
            src_path := l.src
            
            if (l.type == "Shortcut") {
                if (FileExist(shortcut_path))
                    FileDelete, %shortcut_path%
                FileCreateShortcut, %src_path%, %shortcut_path%
            } else {
                ; Handling Symlink/Hardlink
                if (FileExist(shortcut_path)) {
                    ; Check if it's already a link
                    FileGetAttrib, attr, %shortcut_path%
                    if (InStr(attr, "L")) {
                        FileDelete, %shortcut_path%
                    } else {
                        ; Rename original target
                        FileMove, %shortcut_path%, %shortcut_path% . default
                    }
                }
                
                if (l.type == "Symlink") {
                    attr := FileExist(src_path)
                    cmd := (InStr(attr, "D")) ? "/c mklink /D" : "/c mklink"
                    RunWait, %ComSpec% %cmd% "%shortcut_path%" "%src_path%",, Hide
                } else if (l.type == "Hardlink") {
                    RunWait, %ComSpec% /c mklink /H "%shortcut_path%" "%src_path%",, Hide
                }
            }
        }
    }
    return env_changed
}
