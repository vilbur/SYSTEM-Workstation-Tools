/* -------------------------
	PresetManager_0.14.ahk
	AUTOHOTKEY version 1.1.36.02
	Dark IrfanView configuration manager driven by the current image path.

	Preset behavior:
	- Starts hidden in the system tray and checks IrfanView immediately.
	- Detects normal, fullscreen, minimized and portable IrfanView windows.
	- Specific include rules are checked before an empty Default fallback.
	- Every apply restores a captured Default INI, then writes all selected options.
	- Left-click a tab to select it. Right-click its caption to rename the preset.
	- A configured post-apply script runs after all IrfanView options are applied.
	- Version 0.14 runs the manager, IrfanView and post-apply scripts as administrator.
-------------------------
*/

#NoEnv
#SingleInstance Off
#Persistent
SetBatchLines, -1
SendMode, Input
SetTitleMatchMode, 2
SetWorkingDir, %A_ScriptDir%

; -- Administrator and single-instance startup

g_single_instance_mutex := 0
if isAnotherManagerInstanceRunning()
{
	ExitApp
}

if !ensureAdministrator()
{
	ExitApp
}

g_single_instance_mutex := createManagerInstanceMutex()
if !g_single_instance_mutex
{
	ExitApp
}

; -- Application

g_version := "0.14"
g_application_name := "IrfanView Preset Manager"
g_settings_path := A_ScriptDir "\PresetManager.ini"
g_preset_count := 3
g_current_page := 1
g_monitor_running := false
g_apply_in_progress := false
g_last_image_path := ""
g_last_applied_preset := 0
g_last_irfan_hwnd := 0
g_exit_requested := false
g_startup_check_complete := false
g_monitor_interval := 650
g_schema_version := 3

; -- Theme colors copied from the supplied dark control template

g_theme_bg := "202020"
g_theme_panel := "2A2A2A"
g_theme_control := "2A2A2A"
g_theme_button := "4A4A4A"
g_theme_button_hover := "5A5A5A"
g_theme_line := "3A3A3A"
g_theme_text := "E0E0E0"
g_theme_muted := "B0B0B0"
g_theme_accent := "6AA9FF"
g_theme_warning := "E8B45A"
g_theme_font := "Segoe UI"
g_theme_control_brush := 0
g_theme_background_brush := 0

; -- Control maps

g_main_hwnd := 0
g_text_controls := []
g_dark_controls := []
g_edit_controls := []
g_list_controls := []
g_combo_controls := []
g_page_controls := {}
g_tab_button_controls := {}
g_tab_hwnds := {}
g_button_contexts := {}
g_fake_button_actions := {}
g_preset_controls := {}
g_presets := {}
g_post_apply_processes := {}

; -- Main control HWNDs

g_irfan_exe_hwnd := 0
g_irfan_ini_hwnd := 0
g_monitor_checkbox_hwnd := 0
g_current_image_hwnd := 0
g_status_text_hwnd := 0
g_active_preset_text_hwnd := 0
g_monitor_button_hwnd := 0

OnMessage( 0x0133, "onCtlColor" ) ; WM_CTLCOLOREDIT
OnMessage( 0x0134, "onCtlColor" ) ; WM_CTLCOLORLISTBOX
OnMessage( 0x0135, "onCtlColor" ) ; WM_CTLCOLORBTN
OnMessage( 0x0136, "onCtlColor" ) ; WM_CTLCOLORDLG
OnMessage( 0x0138, "onCtlColor" ) ; WM_CTLCOLORSTATIC
OnMessage( 0x0111, "onCommandMessage" ) ; WM_COMMAND
OnMessage( 0x0205, "onRightButtonUp" ) ; WM_RBUTTONUP

loadSettings()
createTrayMenu()
createManagerDialog()
startMonitoring( false )
return


/*	Returns true when another manager instance already owns the session mutex.
	This check happens before elevation so repeated DisplayFusion launches do not show UAC again.
*/
isAnotherManagerInstanceRunning()
{
	mutex_name := "Local\PresetManager_vilbur"
	mutex_handle := DllCall( "OpenMutexW"
		, "UInt", 0x00100000
		, "Int", 0
		, "WStr", mutex_name
		, "Ptr" )

	if !mutex_handle
	{
		return false
	}

	DllCall( "CloseHandle", "Ptr", mutex_handle )
	return true
}

/*	Creates the session mutex held for the lifetime of the elevated manager.
	Windows releases the handle automatically when the manager exits.
*/
createManagerInstanceMutex()
{
	mutex_name := "Local\PresetManager_vilbur"
	return DllCall( "CreateMutexW"
		, "Ptr", 0
		, "Int", 0
		, "WStr", mutex_name
		, "Ptr" )
}

/*	Relaunches the manager with administrator rights when required.
	The unelevated launcher exits immediately after creating the elevated process.
*/
ensureAdministrator()
{
	if A_IsAdmin
	{
		return true
	}

	if A_IsCompiled
	{
		elevated_command := "*RunAs " quoteCommandArgument( A_ScriptFullPath )
	}
	else
	{
		elevated_command := "*RunAs " quoteCommandArgument( A_AhkPath ) " /restart " quoteCommandArgument( A_ScriptFullPath )
	}

	Run, %elevated_command%, %A_ScriptDir%, UseErrorLevel
	if ErrorLevel
	{
		MsgBox, 16, IrfanView Preset Manager, Administrator rights are required. The manager was not started.
	}

	return false
}


/*	Loads manager settings and all preset records.
	Version 0.02 settings are migrated to Default, Slideshow and References.
*/
loadSettings()
{
	global g_settings_path
	global g_preset_count
	global g_presets
	global g_monitor_interval
	global g_schema_version
	global g_last_image_path
	global g_last_applied_preset

	default_exe_path := detectIrfanViewExecutable()
	default_ini_path := detectIrfanViewIni( default_exe_path )

	IniRead, saved_exe_path, %g_settings_path%, General, IrfanViewExe, %default_exe_path%
	IniRead, saved_ini_path, %g_settings_path%, General, IrfanViewIni, %default_ini_path%
	IniRead, saved_monitor, %g_settings_path%, General, MonitorEnabled, 0
	IniRead, saved_interval, %g_settings_path%, General, MonitorInterval, 650
	IniRead, saved_schema_version, %g_settings_path%, General, SchemaVersion, 0
	IniRead, saved_last_image_path, %g_settings_path%, General, LastImagePath,
	IniRead, saved_last_applied_preset, %g_settings_path%, General, LastAppliedPreset, 0

	saved_exe_path := cleanIniReadText( saved_exe_path, default_exe_path )
	saved_ini_path := cleanIniReadText( saved_ini_path, default_ini_path )
	saved_last_image_path := cleanIniReadText( saved_last_image_path )

	g_monitor_interval := saved_interval + 0
	if ( g_monitor_interval < 250 )
	{
		g_monitor_interval := 250
	}

	g_presets := {}
	Loop, %g_preset_count%
	{
		preset_index := A_Index
		default_preset := getDefaultPreset( preset_index )

		if ( saved_schema_version + 0 < g_schema_version )
		{
			if ( preset_index = 1 )
			{
				source_section_name := "Preset4"
			}
			else if ( preset_index = 2 )
			{
				source_section_name := "Preset3"
			}
			else
			{
				source_section_name := "Preset2"
			}

			IniRead, include_rules_stored, %g_settings_path%, %source_section_name%, IncludeRules, % encodeStoredText( default_preset.include_rules )
			IniRead, script_path, %g_settings_path%, %source_section_name%, ScriptPath, % default_preset.script_path
			preset_name := default_preset.name
			window_mode := default_preset.window_mode
			fullscreen_mode := default_preset.fullscreen_mode
			window_position_mode := default_preset.window_position_mode
			title_mode := default_preset.title_mode
			wheel_mode := default_preset.wheel_mode
			keyboard_mode := default_preset.keyboard_mode
		}
		else
		{
			section_name := "Preset" preset_index
			IniRead, preset_name, %g_settings_path%, %section_name%, Name, % default_preset.name
			IniRead, include_rules_stored, %g_settings_path%, %section_name%, IncludeRules, % encodeStoredText( default_preset.include_rules )
			IniRead, script_path, %g_settings_path%, %section_name%, ScriptPath, % default_preset.script_path
			IniRead, window_mode, %g_settings_path%, %section_name%, WindowMode, % default_preset.window_mode
			IniRead, fullscreen_mode, %g_settings_path%, %section_name%, FullscreenMode, % default_preset.fullscreen_mode
			IniRead, window_position_mode, %g_settings_path%, %section_name%, WindowPositionMode, % default_preset.window_position_mode
			IniRead, title_mode, %g_settings_path%, %section_name%, TitleMode, % default_preset.title_mode
			IniRead, wheel_mode, %g_settings_path%, %section_name%, WheelMode, % default_preset.wheel_mode
			IniRead, keyboard_mode, %g_settings_path%, %section_name%, KeyboardMode, % default_preset.keyboard_mode
		}

		preset_name := cleanIniReadText( preset_name, default_preset.name )
		include_rules_stored := cleanIniReadText( include_rules_stored, encodeStoredText( default_preset.include_rules ) )
		script_path := cleanIniReadText( script_path, default_preset.script_path )
		window_mode := cleanIniReadText( window_mode, default_preset.window_mode )
		fullscreen_mode := cleanIniReadText( fullscreen_mode, default_preset.fullscreen_mode )
		window_position_mode := cleanIniReadText( window_position_mode, default_preset.window_position_mode )
		title_mode := cleanIniReadText( title_mode, default_preset.title_mode )
		wheel_mode := cleanIniReadText( wheel_mode, default_preset.wheel_mode )
		keyboard_mode := cleanIniReadText( keyboard_mode, default_preset.keyboard_mode )

		g_presets[ preset_index ] := { name: preset_name
			, enabled: 1
			, include_rules: decodeStoredText( include_rules_stored )
			, exclude_rules: ""
			, source_ini: ""
			, ini_overrides: ""
			, restart_viewer: 1
			, run_script: Trim( script_path ) != ""
			, script_path: script_path
			, script_arguments: quoteCommandArgument( "{image_path}" )
			, window_mode: normalizePresetOption( "window", window_mode )
			, fullscreen_mode: normalizePresetOption( "fullscreen", fullscreen_mode )
			, window_position_mode: normalizePresetOption( "window_position", window_position_mode )
			, title_mode: normalizePresetOption( "title", title_mode )
			, wheel_mode: normalizePresetOption( "wheel", wheel_mode )
			, keyboard_mode: normalizePresetOption( "keyboard", keyboard_mode ) }
	}

	g_last_image_path := saved_last_image_path
	g_last_applied_preset := saved_last_applied_preset + 0

	g_presets.general := { irfan_exe: saved_exe_path
		, irfan_ini: saved_ini_path
		, monitor_enabled: 1 }
}

/*	Converts AutoHotkey IniRead's missing-value marker to a real fallback.
	This prevents empty GUI controls from displaying the literal text ERROR.
*/
cleanIniReadText( input_value, fallback_value := "" )
{
	if ( input_value = "ERROR" )
	{
		return fallback_value
	}

	return input_value
}

/*	Returns one of the three requested preset defaults.
	Option value "default" means the captured Default INI value is retained.
	Slideshow and References enable native arrow-key panning by default.
*/
getDefaultPreset( preset_index )
{
	if ( preset_index = 1 )
	{
		return { name: "Default"
			, enabled: 1
			, include_rules: ""
			, exclude_rules: ""
			, source_ini: ""
			, ini_overrides: ""
			, restart_viewer: 1
			, run_script: 0
			, script_path: ""
			, script_arguments: quoteCommandArgument( "{image_path}" )
			, window_mode: "default"
			, fullscreen_mode: "default"
			, window_position_mode: "default"
			, title_mode: "default"
			, wheel_mode: "default"
			, keyboard_mode: "default" }
	}
	else if ( preset_index = 2 )
	{
		return { name: "Slideshow"
			, enabled: 1
			, include_rules: "*\Slideshow\*"
			, exclude_rules: ""
			, source_ini: ""
			, ini_overrides: ""
			, restart_viewer: 1
			, run_script: 0
			, script_path: ""
			, script_arguments: quoteCommandArgument( "{image_path}" )
			, window_mode: "default"
			, fullscreen_mode: "fit_height"
			, window_position_mode: "default"
			, title_mode: "full_path"
			, wheel_mode: "change_images"
			, keyboard_mode: "pan_image" }
	}

	return { name: "References"
		, enabled: 1
		, include_rules: "*\Reference\*`n*\References\*"
		, exclude_rules: ""
		, source_ini: ""
		, ini_overrides: ""
		, restart_viewer: 1
		, run_script: 0
		, script_path: ""
		, script_arguments: quoteCommandArgument( "{image_path}" )
		, window_mode: "fit_window"
		, fullscreen_mode: "default"
		, window_position_mode: "keep"
		, title_mode: "filename"
		, wheel_mode: "never_change_images"
		, keyboard_mode: "pan_image" }
}

/*	Normalizes one saved option and rejects obsolete or invalid values.
	Unknown values fall back to the captured Default INI behavior.
*/
normalizePresetOption( option_type, option_value )
{
	option_value := toLowerText( Trim( option_value ) )

	if ( option_type = "window" )
	{
		return ( option_value = "fit_window" ) ? option_value : "default"
	}
	else if ( option_type = "fullscreen" )
	{
		return ( option_value = "fit_height" ) ? option_value : "default"
	}
	else if ( option_type = "window_position" )
	{
		return ( option_value = "keep" ) ? option_value : "default"
	}
	else if ( option_type = "title" )
	{
		if ( option_value = "full_path" || option_value = "filename" )
		{
			return option_value
		}
		return "default"
	}
	else if ( option_type = "wheel" )
	{
		if ( option_value = "change_images" || option_value = "never_change_images" )
		{
			return option_value
		}
		return "default"
	}
	else if ( option_type = "keyboard" )
	{
		return ( option_value = "pan_image" ) ? option_value : "default"
	}

	return "default"
}

/*	Creates the dark manager dialog.
	Uses fake tab buttons and registered dark controls from the supplied template.
*/
createManagerDialog()
{
	global g_application_name
	global g_version
	global g_main_hwnd
	global g_theme_bg
	global g_theme_text
	global g_theme_muted
	global g_theme_font
	global g_theme_panel
	global g_presets
	global g_preset_count
	global g_irfan_exe_hwnd
	global g_irfan_ini_hwnd
	global g_monitor_checkbox_hwnd
	global g_current_image_hwnd
	global g_status_text_hwnd
	global g_active_preset_text_hwnd
	global g_monitor_button_hwnd

	Gui, Manager:New, +Resize +MinSize1040x760 +Hwndg_main_hwnd +LabelManagerGui
	Gui, Manager:Default
	Gui, Color, %g_theme_bg%, %g_theme_bg%

	Gui, Font, s14 Bold c%g_theme_text%, %g_theme_font%
	Gui, Add, Text, x16 y12 w520 h30 BackgroundTrans hwndtitle_hwnd, %g_application_name% %g_version%
	registerTextControl( title_hwnd )

	Gui, Font, s9 Norm c%g_theme_muted%, %g_theme_font%
	Gui, Add, Text, x16 y44 w900 h20 BackgroundTrans hwndsubtitle_hwnd, Applies presets by image path. Left-click a tab to select it; right-click its caption to rename it.
	registerTextControl( subtitle_hwnd )

	addDarkLabel( 16, 76, 170, 22, "IrfanView executable" )
	Gui, Font, s9 Norm c%g_theme_text%, %g_theme_font%
	Gui, Add, Edit, x190 y72 w660 h28 -Theme +Background2A2A2A hwndg_irfan_exe_hwnd, % g_presets.general.irfan_exe
	registerEditControl( g_irfan_exe_hwnd )
	browse_exe_hwnd := addFakeButton( 860, 72, 78, 28, "Browse", "OnBrowseIrfanExe" )
	detect_exe_hwnd := addFakeButton( 946, 72, 78, 28, "Detect", "OnDetectPaths" )

	addDarkLabel( 16, 110, 170, 22, "Active IrfanView INI" )
	Gui, Add, Edit, x190 y106 w660 h28 -Theme +Background2A2A2A hwndg_irfan_ini_hwnd, % g_presets.general.irfan_ini
	registerEditControl( g_irfan_ini_hwnd )
	browse_ini_hwnd := addFakeButton( 860, 106, 78, 28, "Browse", "OnBrowseIrfanIni" )
	open_ini_hwnd := addFakeButton( 946, 106, 78, 28, "Open", "OnOpenIrfanIni" )

	Gui, Font, s9 Norm c%g_theme_text%, %g_theme_font%
	monitor_checked := "Checked Disabled"
	Gui, Add, Checkbox, x16 y144 w340 h26 hwndg_monitor_checkbox_hwnd %monitor_checked%, Automatic preset monitoring is always enabled
	registerDarkControl( g_monitor_checkbox_hwnd )
	Gui, Add, Text, x310 y150 w714 h1 Border Background3A3A3A hwndheader_line_hwnd,
	registerDarkControl( header_line_hwnd )

	tab_x := 16
	Loop, %g_preset_count%
	{
		preset_index := A_Index
		preset_name := g_presets[ preset_index ].name
		addFakeTabButton( tab_x, 178, 188, 32, preset_name, preset_index )
		tab_x += 194
	}

	BuildPresetPages()
	showPage( 1 )

	Gui, Add, Text, x16 y664 w1008 h1 Border Background3A3A3A hwndfooter_line_hwnd,
	registerDarkControl( footer_line_hwnd )

	addDarkLabel( 16, 676, 112, 22, "Current image" )
	Gui, Font, s9 Norm c%g_theme_text%, %g_theme_font%
	Gui, Add, Edit, x132 y672 w892 h27 ReadOnly -Theme +Background2A2A2A hwndg_current_image_hwnd,
	registerEditControl( g_current_image_hwnd )
	setCurrentImagePath( "" )

	Gui, Font, s9 Bold c%g_theme_text%, %g_theme_font%
	Gui, Add, Text, x16 y708 w330 h24 BackgroundTrans hwndg_active_preset_text_hwnd, Active preset: none
	registerTextControl( g_active_preset_text_hwnd )
	Gui, Font, s9 Norm c%g_theme_muted%, %g_theme_font%
	Gui, Add, Text, x350 y708 w674 h24 BackgroundTrans Right hwndg_status_text_hwnd, Ready
	registerTextControl( g_status_text_hwnd )

	g_monitor_button_hwnd := addFakeButton( 16, 724, 150, 30, "Check Current", "OnTrayCheckPreset" )
	addFakeButton( 174, 724, 126, 30, "Save All", "OnSaveAll" )
	addFakeButton( 308, 724, 152, 30, "Apply Current", "OnApplyCurrentPreset" )
	addFakeButton( 468, 724, 126, 30, "Run Tests", "OnRunTests" )
	addFakeButton( 602, 724, 126, 30, "Hide", "OnHideManager" )
	addFakeButton( 898, 724, 126, 30, "Exit", "OnExitManager" )

	Gui, Manager:Show, Hide NA w1040 h770, %g_application_name% %g_version%
	applyDarkTheme()
	redrawAllEditControls()
	setDarkTitleBar( g_main_hwnd )
	updateMonitorButton()
	updateCurrentPageSummary()
}

/*	Shows and fully redraws the preferences dialog from the tray.
	The window is restored, moved onto a visible monitor and raised above IrfanView.
*/
showManagerDialog()
{
	global g_application_name
	global g_version
	global g_main_hwnd
	global g_current_page

	if ( !g_main_hwnd || !DllCall( "IsWindow", "Ptr", g_main_hwnd ) )
	{
		createManagerDialog()
	}

	manager_width := 1040
	manager_height := 770
	manager_position := getManagerVisiblePosition( manager_width, manager_height )
	manager_x := manager_position.x
	manager_y := manager_position.y

	Gui, Manager:Default
	Gui, Manager:+AlwaysOnTop
	Gui, Manager:Show, x%manager_x% y%manager_y% w%manager_width% h%manager_height%, %g_application_name% %g_version%

	DllCall( "ShowWindow", "Ptr", g_main_hwnd, "Int", 9 )
	DllCall( "SetWindowPos"
		, "Ptr", g_main_hwnd
		, "Ptr", -1
		, "Int", manager_x
		, "Int", manager_y
		, "Int", manager_width
		, "Int", manager_height
		, "UInt", 0x0040 )

	showPage( g_current_page )
	applyDarkTheme()
	redrawAllEditControls()
	setDarkTitleBar( g_main_hwnd )
	DllCall( "RedrawWindow"
		, "Ptr", g_main_hwnd
		, "Ptr", 0
		, "Ptr", 0
		, "UInt", 0x0185 )
	DllCall( "UpdateWindow", "Ptr", g_main_hwnd )
	DllCall( "BringWindowToTop", "Ptr", g_main_hwnd )
	DllCall( "SetForegroundWindow", "Ptr", g_main_hwnd )
	WinActivate, ahk_id %g_main_hwnd%

	SetTimer, RemoveManagerAlwaysOnTopTimer, -300
	Sleep, 30
	return DllCall( "IsWindowVisible", "Ptr", g_main_hwnd )
}

/*	Returns a visible manager position on the monitor containing the mouse pointer.
	The complete window is clamped inside that monitor's work area.
*/
getManagerVisiblePosition( manager_width, manager_height )
{
	MouseGetPos, mouse_x, mouse_y
	SysGet, monitor_count, MonitorCount
	selected_monitor := 1

	Loop, %monitor_count%
	{
		monitor_index := A_Index
		SysGet, monitor_area, MonitorWorkArea, %monitor_index%
		if ( mouse_x >= monitor_areaLeft && mouse_x < monitor_areaRight
			&& mouse_y >= monitor_areaTop && mouse_y < monitor_areaBottom )
		{
			selected_monitor := monitor_index
			break
		}
	}

	SysGet, monitor_area, MonitorWorkArea, %selected_monitor%
	work_width := monitor_areaRight - monitor_areaLeft
	work_height := monitor_areaBottom - monitor_areaTop
	window_x := monitor_areaLeft + Floor( ( work_width - manager_width ) / 2 )
	window_y := monitor_areaTop + Floor( ( work_height - manager_height ) / 2 )

	if ( window_x < monitor_areaLeft )
	{
		window_x := monitor_areaLeft
	}
	if ( window_y < monitor_areaTop )
	{
		window_y := monitor_areaTop
	}

	return { x: window_x, y: window_y }
}

/*	Builds path rules, IrfanView options, post script and Apply Preset.
	Every visible option is written together after restoring the Default INI.
*/
BuildPresetPages()
{
	global g_preset_count
	global g_presets
	global g_preset_controls
	global g_theme_text
	global g_theme_font
	global g_theme_line

	Loop, %g_preset_count%
	{
		preset_index := A_Index
		preset_data := g_presets[ preset_index ]
		control_map := {}

		addPagePanel( preset_index )

		addPageLabel( preset_index, 36, 238, 430, 22, "Include Path Rules — one wildcard per line" )
		Gui, Add, Text, x34 y260 w972 h86 Border Background%g_theme_line% hwndinclude_rules_border_hwnd,
		registerPageControl( preset_index, include_rules_border_hwnd )
		registerDarkControl( include_rules_border_hwnd )
		Gui, Font, s9 Norm c%g_theme_text%, %g_theme_font%
		Gui, Add, Edit, x36 y262 w968 h82 Multi WantTab +Border -Theme +Background2A2A2A hwndinclude_rules_hwnd, % preset_data.include_rules
		registerPageControl( preset_index, include_rules_hwnd )
		registerEditControl( include_rules_hwnd )
		control_map.include_rules := include_rules_hwnd

		addPageLabel( preset_index, 36, 358, 350, 22, "Preset Options — applied together" )

		addPageLabel( preset_index, 36, 386, 220, 20, "Window display" )
		window_choice := getPresetOptionChoice( "window", preset_data.window_mode )
		Gui, Font, s9 Norm c%g_theme_text%, %g_theme_font%
		Gui, Add, DropDownList, x36 y408 w226 r3 AltSubmit Choose%window_choice% -Theme hwndwindow_mode_hwnd, Use captured display mode|Fit image to window
		registerPageControl( preset_index, window_mode_hwnd )
		registerComboControl( window_mode_hwnd )
		control_map.window_mode := window_mode_hwnd

		addPageLabel( preset_index, 278, 386, 220, 20, "Fullscreen display" )
		fullscreen_choice := getPresetOptionChoice( "fullscreen", preset_data.fullscreen_mode )
		Gui, Add, DropDownList, x278 y408 w226 r3 AltSubmit Choose%fullscreen_choice% -Theme hwndfullscreen_mode_hwnd, Use captured fullscreen mode|Fit screen height
		registerPageControl( preset_index, fullscreen_mode_hwnd )
		registerComboControl( fullscreen_mode_hwnd )
		control_map.fullscreen_mode := fullscreen_mode_hwnd

		addPageLabel( preset_index, 520, 386, 220, 20, "Title bar" )
		title_choice := getPresetOptionChoice( "title", preset_data.title_mode )
		Gui, Add, DropDownList, x520 y408 w226 r4 AltSubmit Choose%title_choice% -Theme hwndtitle_mode_hwnd, Use captured title format|Full image path|Filename only
		registerPageControl( preset_index, title_mode_hwnd )
		registerComboControl( title_mode_hwnd )
		control_map.title_mode := title_mode_hwnd

		addPageLabel( preset_index, 762, 386, 220, 20, "Mouse wheel" )
		wheel_choice := getPresetOptionChoice( "wheel", preset_data.wheel_mode )
		Gui, Add, DropDownList, x762 y408 w242 r4 AltSubmit Choose%wheel_choice% -Theme hwndwheel_mode_hwnd, Use captured wheel action|Change images|Do not change images
		registerPageControl( preset_index, wheel_mode_hwnd )
		registerComboControl( wheel_mode_hwnd )
		control_map.wheel_mode := wheel_mode_hwnd

		addPageLabel( preset_index, 36, 454, 280, 20, "Window size and position" )
		window_position_choice := getPresetOptionChoice( "window_position", preset_data.window_position_mode )
		Gui, Add, DropDownList, x36 y476 w300 r3 AltSubmit Choose%window_position_choice% -Theme hwndwindow_position_mode_hwnd, Use captured window placement|Keep current size and position
		registerPageControl( preset_index, window_position_mode_hwnd )
		registerComboControl( window_position_mode_hwnd )
		control_map.window_position_mode := window_position_mode_hwnd

		addPageLabel( preset_index, 352, 454, 300, 20, "Keyboard navigation" )
		keyboard_choice := getPresetOptionChoice( "keyboard", preset_data.keyboard_mode )
		Gui, Add, DropDownList, x352 y476 w300 r3 AltSubmit Choose%keyboard_choice% -Theme hwndkeyboard_mode_hwnd, Use captured key behavior|Pan arrows + disable Page Up/Down
		registerPageControl( preset_index, keyboard_mode_hwnd )
		registerComboControl( keyboard_mode_hwnd )
		control_map.keyboard_mode := keyboard_mode_hwnd

		if ( preset_index = 1 )
		{
			capture_default_hwnd := addFakeButton( 668, 476, 218, 28, "Capture Current as Default", "OnContextButton" )
			registerPageControl( preset_index, capture_default_hwnd )
			registerButtonContext( capture_default_hwnd, "captureDefault", preset_index )
		}
		else
		{
			default_note_hwnd := addPageLabel( preset_index, 668, 480, 330, 22, "Base configuration: captured Default INI" )
		}

		addPageLabel( preset_index, 36, 516, 220, 22, "Post Apply Script" )
		Gui, Add, Edit, x36 y540 w828 h28 -Theme +Background2A2A2A hwndscript_path_hwnd, % preset_data.script_path
		registerPageControl( preset_index, script_path_hwnd )
		registerEditControl( script_path_hwnd )
		control_map.script_path := script_path_hwnd

		browse_script_hwnd := addFakeButton( 874, 540, 130, 28, "Browse Script", "OnContextButton" )
		registerPageControl( preset_index, browse_script_hwnd )
		registerButtonContext( browse_script_hwnd, "browseScript", preset_index )

		apply_preset_hwnd := addFakeButton( 36, 596, 160, 32, "Apply Preset", "OnContextButton" )
		registerPageControl( preset_index, apply_preset_hwnd )
		registerButtonContext( apply_preset_hwnd, "applyPreset", preset_index )

		g_preset_controls[ preset_index ] := control_map
	}
}

/*	Returns the dropdown index for one stored option value.
	All dropdowns use AltSubmit so the numeric choice is read reliably.
*/
getPresetOptionChoice( option_type, option_value )
{
	option_value := normalizePresetOption( option_type, option_value )

	if ( option_type = "window" )
	{
		return ( option_value = "fit_window" ) ? 2 : 1
	}
	else if ( option_type = "fullscreen" )
	{
		return ( option_value = "fit_height" ) ? 2 : 1
	}
	else if ( option_type = "window_position" )
	{
		return ( option_value = "keep" ) ? 2 : 1
	}
	else if ( option_type = "title" )
	{
		if ( option_value = "full_path" )
		{
			return 2
		}
		else if ( option_value = "filename" )
		{
			return 3
		}
		return 1
	}
	else if ( option_type = "wheel" )
	{
		if ( option_value = "change_images" )
		{
			return 2
		}
		else if ( option_value = "never_change_images" )
		{
			return 3
		}
		return 1
	}
	else if ( option_type = "keyboard" )
	{
		return ( option_value = "pan_image" ) ? 2 : 1
	}

	return 1
}

/*	Converts one AltSubmit dropdown index into its persisted option value.
	Invalid choices safely retain the captured IrfanView setting.
*/
getPresetOptionFromChoice( option_type, choice_index )
{
	choice_index += 0

	if ( option_type = "window" )
	{
		return ( choice_index = 2 ) ? "fit_window" : "default"
	}
	else if ( option_type = "fullscreen" )
	{
		return ( choice_index = 2 ) ? "fit_height" : "default"
	}
	else if ( option_type = "window_position" )
	{
		return ( choice_index = 2 ) ? "keep" : "default"
	}
	else if ( option_type = "title" )
	{
		if ( choice_index = 2 )
		{
			return "full_path"
		}
		else if ( choice_index = 3 )
		{
			return "filename"
		}
		return "default"
	}
	else if ( option_type = "wheel" )
	{
		if ( choice_index = 2 )
		{
			return "change_images"
		}
		else if ( choice_index = 3 )
		{
			return "never_change_images"
		}
		return "default"
	}
	else if ( option_type = "keyboard" )
	{
		return ( choice_index = 2 ) ? "pan_image" : "default"
	}

	return "default"
}

/*	Registers a normal static text control.
	Static text uses the dark transparent background handling.
*/
registerTextControl( control_hwnd )
{
	global g_text_controls
	g_text_controls.Push( control_hwnd )
}

/*	Registers a control handled by the common color callback.
	Used for native checkboxes, panels, lines and related controls.
*/
registerDarkControl( control_hwnd )
{
	global g_dark_controls
	g_dark_controls.Push( control_hwnd )
}

/*	Registers a dark edit control.
	The control is also added to the common dark control map.
*/
registerEditControl( control_hwnd )
{
	global g_edit_controls
	g_edit_controls.Push( control_hwnd )
	registerDarkControl( control_hwnd )
}


/*	Returns true while an editable manager Edit control owns keyboard focus.
	The context-sensitive Backspace hotkey is active only in this situation.
*/
managerEditHotkeyContext()
{
	global g_main_hwnd

	if !g_main_hwnd
	{
		return false
	}

	if !WinActive( "ahk_id " g_main_hwnd )
	{
		return false
	}

	focused_hwnd := DllCall( "GetFocus", "Ptr" )
	if !isApplicationEditControl( focused_hwnd )
	{
		return false
	}

	control_style := DllCall( "GetWindowLongW", "Ptr", focused_hwnd, "Int", -16, "UInt" )
	return !( control_style & 0x0800 )
}

/*	Sends native WM_CHAR Backspace directly to the focused Edit control.
	Windows then deletes the selection or previous character normally.
*/
handleManagerEditBackspace()
{
	focused_hwnd := DllCall( "GetFocus", "Ptr" )
	if !isApplicationEditControl( focused_hwnd )
	{
		return false
	}

	DllCall( "SendMessageW"
		, "Ptr", focused_hwnd
		, "UInt", 0x0102
		, "UPtr", 0x08
		, "Ptr", 1
		, "Ptr" )

	return true
}

/*	Returns true for Edit controls owned by this AutoHotkey process.
	Registered manager fields and temporary InputBox fields are supported.
*/
isApplicationEditControl( control_hwnd )
{
	global g_edit_controls

	if !control_hwnd
	{
		return false
	}

	for control_index, registered_hwnd in g_edit_controls
	{
		if ( registered_hwnd = control_hwnd )
		{
			return true
		}
	}

	control_process_id := 0
	DllCall( "GetWindowThreadProcessId", "Ptr", control_hwnd, "UIntP", control_process_id )
	if ( control_process_id != DllCall( "GetCurrentProcessId", "UInt" ) )
	{
		return false
	}

	VarSetCapacity( class_name_buffer, 128 * 2, 0 )
	class_name_length := DllCall( "GetClassNameW"
		, "Ptr", control_hwnd
		, "Ptr", &class_name_buffer
		, "Int", 128 )
	if !class_name_length
	{
		return false
	}

	class_name := StrGet( &class_name_buffer, class_name_length, "UTF-16" )
	return ( class_name = "Edit" )
}

/*	Deletes text in a native Edit control through its own Backspace handler.
	This is also used by the internal regression test.
*/
deleteEditSelectionOrPreviousCharacter( control_hwnd )
{
	if !control_hwnd
	{
		return false
	}

	DllCall( "SendMessageW"
		, "Ptr", control_hwnd
		, "UInt", 0x0102
		, "UPtr", 0x08
		, "Ptr", 1
		, "Ptr" )

	return true
}

/*	Finds the previous deletion boundary in a Windows Edit control.
	A CRLF line break is deleted as one Backspace operation.
*/
getPreviousEditCharacterPosition( control_hwnd, caret_position )
{
	if ( caret_position <= 0 )
	{
		return 0
	}

	text_length := DllCall( "GetWindowTextLengthW", "Ptr", control_hwnd, "Int" )
	VarSetCapacity( edit_text_buffer, ( text_length + 1 ) * 2, 0 )
	DllCall( "GetWindowTextW"
		, "Ptr", control_hwnd
		, "Ptr", &edit_text_buffer
		, "Int", text_length + 1 )
	edit_text := StrGet( &edit_text_buffer, text_length, "UTF-16" )

	if ( caret_position >= 2 && SubStr( edit_text, caret_position - 1, 2 ) = "`r`n" )
	{
		return caret_position - 2
	}

	return caret_position - 1
}

/*	Tests native Edit text assignment and readback through the repaint helper.
*/
testNativeEditTextUpdate()
{
	global g_main_hwnd

	test_module_hwnd := DllCall( "GetModuleHandleW", "Ptr", 0, "Ptr" )
	test_edit_hwnd := DllCall( "CreateWindowExW"
		, "UInt", 0
		, "WStr", "Edit"
		, "WStr", ""
		, "UInt", 0x40000080
		, "Int", 0
		, "Int", 0
		, "Int", 180
		, "Int", 24
		, "Ptr", g_main_hwnd
		, "Ptr", 0
		, "Ptr", test_module_hwnd
		, "Ptr", 0
		, "Ptr" )

	if !test_edit_hwnd
	{
		return false
	}

	test_text := "D:\Images\Reference\Chair 01.jpg"
	setNativeControlText( test_edit_hwnd, test_text )
	readback_text := getEditControlText( test_edit_hwnd )
	DllCall( "DestroyWindow", "Ptr", test_edit_hwnd )
	return ( readback_text = test_text )
}

/*	Tests the corrected Backspace behavior using a hidden native Edit control.
	The test verifies both one-character and selected-text deletion.
*/
testEditBackspaceDeletion()
{
	global g_main_hwnd

	test_module_hwnd := DllCall( "GetModuleHandleW", "Ptr", 0, "Ptr" )
	test_edit_hwnd := DllCall( "CreateWindowExW"
		, "UInt", 0
		, "WStr", "Edit"
		, "WStr", "ABC"
		, "UInt", 0x40000080
		, "Int", 0
		, "Int", 0
		, "Int", 100
		, "Int", 24
		, "Ptr", g_main_hwnd
		, "Ptr", 0
		, "Ptr", test_module_hwnd
		, "Ptr", 0
		, "Ptr" )

	if !test_edit_hwnd
	{
		return false
	}

	DllCall( "SendMessageW", "Ptr", test_edit_hwnd, "UInt", 0x00B1, "Ptr", 3, "Ptr", 3, "Ptr" )
	deleteEditSelectionOrPreviousCharacter( test_edit_hwnd )
	first_result := getEditControlText( test_edit_hwnd )

	DllCall( "SendMessageW", "Ptr", test_edit_hwnd, "UInt", 0x000C, "Ptr", 0, "WStr", "ABCDE", "Ptr" )
	DllCall( "SendMessageW", "Ptr", test_edit_hwnd, "UInt", 0x00B1, "Ptr", 1, "Ptr", 4, "Ptr" )
	deleteEditSelectionOrPreviousCharacter( test_edit_hwnd )
	second_result := getEditControlText( test_edit_hwnd )

	DllCall( "DestroyWindow", "Ptr", test_edit_hwnd )
	return ( first_result = "AB" && second_result = "AE" )
}

/*	Reads the complete text from one native Edit control.
	This helper is used by the Backspace regression test.
*/
getEditControlText( control_hwnd )
{
	text_length := DllCall( "GetWindowTextLengthW", "Ptr", control_hwnd, "Int" )
	VarSetCapacity( edit_text_buffer, ( text_length + 1 ) * 2, 0 )
	DllCall( "GetWindowTextW"
		, "Ptr", control_hwnd
		, "Ptr", &edit_text_buffer
		, "Int", text_length + 1 )
	return StrGet( &edit_text_buffer, text_length, "UTF-16" )
}

/*	Registers a dark list control.
	Reserved for future preset list extensions.
*/
registerListControl( control_hwnd )
{
	global g_list_controls
	g_list_controls.Push( control_hwnd )
	registerDarkControl( control_hwnd )
}

/*	Registers a dark combo control.
	Reserved for future manager options.
*/
registerComboControl( control_hwnd )
{
	global g_combo_controls
	g_combo_controls.Push( control_hwnd )
	registerDarkControl( control_hwnd )
}

/*	Creates one fake dark text button.
	This reproduces the reliable button styling from the supplied template.
*/
addFakeButton( x_pos, y_pos, width_value, height_value, button_text, action_name )
{
	global g_theme_button
	global g_fake_button_actions

	Gui, Add, Text, x%x_pos% y%y_pos% w%width_value% h%height_value% 0x301 Border Background%g_theme_button% hwndbutton_hwnd, %button_text%
	registerDarkControl( button_hwnd )
	g_fake_button_actions[ button_hwnd ] := action_name

	return button_hwnd
}

/*	Creates one fake dark preset tab.
	The selected tab uses the template hover background as its active state.
*/
addFakeTabButton( x_pos, y_pos, width_value, height_value, tab_text, page_index )
{
	global g_theme_button
	global g_tab_button_controls
	global g_tab_hwnds

	Gui, Add, Text, x%x_pos% y%y_pos% w%width_value% h%height_value% 0x301 Border Background%g_theme_button% hwndtab_hwnd, %tab_text%
	g_tab_button_controls[ tab_hwnd ] := page_index
	g_tab_hwnds[ page_index ] := tab_hwnd
	registerDarkControl( tab_hwnd )

	return tab_hwnd
}

/*	Creates a normal dark label.
	The text stays transparent over the dark panel.
*/
addDarkLabel( x_pos, y_pos, width_value, height_value, label_text )
{
	global g_theme_text
	global g_theme_font

	Gui, Font, s9 Bold c%g_theme_text%, %g_theme_font%
	Gui, Add, Text, x%x_pos% y%y_pos% w%width_value% h%height_value% BackgroundTrans hwndlabel_hwnd, %label_text%
	registerTextControl( label_hwnd )

	return label_hwnd
}

/*	Creates the shared dark panel behind one preset page.
	Every page uses exactly the same position and dimensions.
*/
addPagePanel( page_index )
{
	global g_theme_panel

	Gui, Add, Text, x16 y220 w1008 h430 Border Background%g_theme_panel% hwndpanel_hwnd,
	registerPageControl( page_index, panel_hwnd )
	registerDarkControl( panel_hwnd )

	return panel_hwnd
}

/*	Creates a page label and adds it to the page visibility map.
	This keeps label visibility synchronized with its preset tab.
*/
addPageLabel( page_index, x_pos, y_pos, width_value, height_value, label_text )
{
	control_hwnd := addDarkLabel( x_pos, y_pos, width_value, height_value, label_text )
	registerPageControl( page_index, control_hwnd )

	return control_hwnd
}

/*	Adds a control HWND to one preset page.
	Controls are hidden or shown together by showPage().
*/
registerPageControl( page_index, control_hwnd )
{
	global g_page_controls

	if !g_page_controls.HasKey( page_index )
	{
		g_page_controls[ page_index ] := []
	}

	g_page_controls[ page_index ].Push( control_hwnd )
}

/*	Stores an action and preset index for a shared context button label.
	This avoids creating separate labels for every preset page.
*/
registerButtonContext( button_hwnd, action_name, preset_index )
{
	global g_button_contexts
	g_button_contexts[ button_hwnd ] := { action: action_name, preset_index: preset_index }
}

/*	Shows one preset page and hides the other pages.
	The active fake tab receives the highlighted background.
*/
showPage( page_index )
{
	global g_main_hwnd
	global g_page_controls
	global g_tab_button_controls
	global g_theme_button
	global g_theme_button_hover
	global g_current_page

	g_current_page := page_index

	for stored_page_index, control_list in g_page_controls
	{
		for index, control_hwnd in control_list
		{
			if ( stored_page_index = page_index )
			{
				DllCall( "ShowWindow", "Ptr", control_hwnd, "Int", 5 )
			}
			else
			{
				DllCall( "ShowWindow", "Ptr", control_hwnd, "Int", 0 )
			}
		}
	}

	for tab_hwnd, stored_page_index in g_tab_button_controls
	{
		if ( stored_page_index = page_index )
		{
			GuiControl, +Background%g_theme_button_hover%, %tab_hwnd%
		}
		else
		{
			GuiControl, +Background%g_theme_button%, %tab_hwnd%
		}

		DllCall( "RedrawWindow", "Ptr", tab_hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x85 )
	}

	WinSet, Redraw,, ahk_id %g_main_hwnd%
	redrawAllEditControls()
	updateCurrentPageSummary()
}

/*	Applies the supplied dark theme to registered native controls.
	The implementation follows the uploaded template control sequence.
*/
applyDarkTheme()
{
	global g_theme_bg
	global g_theme_control
	global g_edit_controls
	global g_list_controls
	global g_combo_controls

	Gui, Color, %g_theme_bg%, %g_theme_bg%

	for index, control_hwnd in g_edit_controls
	{
		GuiControl, +Background%g_theme_control%, %control_hwnd%
		DllCall( "UxTheme.dll\SetWindowTheme", "Ptr", control_hwnd, "WStr", "", "WStr", "" )
	}

	for index, control_hwnd in g_list_controls
	{
		GuiControl, +Background%g_theme_control%, %control_hwnd%
		DllCall( "UxTheme.dll\SetWindowTheme", "Ptr", control_hwnd, "WStr", "", "WStr", "" )
	}

	for index, control_hwnd in g_combo_controls
	{
		GuiControl, +Background%g_theme_control%, %control_hwnd%
		DllCall( "UxTheme.dll\SetWindowTheme", "Ptr", control_hwnd, "WStr", "", "WStr", "" )
	}
}

/*	Forces every visible Edit control to render its stored text immediately.
	The text is reassigned once the hidden page becomes visible, then the frame is repainted.
*/
redrawAllEditControls()
{
	global g_edit_controls

	for control_index, control_hwnd in g_edit_controls
	{
		if !control_hwnd
		{
			continue
		}

		if DllCall( "IsWindowVisible", "Ptr", control_hwnd )
		{
			refreshEditControlDisplay( control_hwnd )
		}
		else
		{
			DllCall( "InvalidateRect", "Ptr", control_hwnd, "Ptr", 0, "Int", 1 )
		}
	}
}

/*	Reassigns one Edit control's current text and repaints its client area and border.
	Selection is preserved so showing a page does not disturb the user's caret position.
*/
refreshEditControlDisplay( control_hwnd )
{
	if !control_hwnd
	{
		return false
	}

	control_text := getEditControlText( control_hwnd )
	selection_start := 0
	selection_end := 0
	DllCall( "SendMessageW"
		, "Ptr", control_hwnd
		, "UInt", 0x00B0
		, "UInt*", selection_start
		, "UInt*", selection_end
		, "Ptr" )

	DllCall( "SendMessageW", "Ptr", control_hwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0, "Ptr" )
	DllCall( "SetWindowTextW", "Ptr", control_hwnd, "WStr", control_text )
	DllCall( "SendMessageW", "Ptr", control_hwnd, "UInt", 0x00B1, "Ptr", selection_start, "Ptr", selection_end, "Ptr" )
	DllCall( "SendMessageW", "Ptr", control_hwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0, "Ptr" )

	DllCall( "SetWindowPos"
		, "Ptr", control_hwnd
		, "Ptr", 0
		, "Int", 0
		, "Int", 0
		, "Int", 0
		, "Int", 0
		, "UInt", 0x0037 )
	DllCall( "RedrawWindow", "Ptr", control_hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0585 )
	DllCall( "UpdateWindow", "Ptr", control_hwnd )
	return true
}

/*	Enables the Windows dark title bar where supported.
	Failure is harmless on older Windows builds.
*/
setDarkTitleBar( window_hwnd )
{
	use_dark_mode := 1
	DllCall( "dwmapi\DwmSetWindowAttribute", "Ptr", window_hwnd, "Int", 20, "Int*", use_dark_mode, "Int", 4 )
	DllCall( "dwmapi\DwmSetWindowAttribute", "Ptr", window_hwnd, "Int", 19, "Int*", use_dark_mode, "Int", 4 )
}


/*	Converts text to lowercase using AutoHotkey v1 syntax.
	This avoids the AutoHotkey v2-only StrLower() function.
*/
toLowerText( input_text )
{
	StringLower, output_text, input_text
	return output_text
}

/*	Converts an RGB hexadecimal color to a Windows COLORREF.
	Used by the WM_CTLCOLOR message handler.
*/
hexToColorRef( hex_color )
{
	StringReplace, hex_color, hex_color, #,, All
	red_value := "0x" SubStr( hex_color, 1, 2 )
	green_value := "0x" SubStr( hex_color, 3, 2 )
	blue_value := "0x" SubStr( hex_color, 5, 2 )

	return ( red_value | ( green_value << 8 ) | ( blue_value << 16 ) )
}

/*	Paints static, edit, list and checkbox controls.
	This is the supplied template color callback adapted to the manager.
*/
onCtlColor( w_param, l_param, msg, hwnd_value )
{
	global g_theme_text
	global g_theme_bg
	global g_theme_control
	global g_theme_control_brush
	global g_theme_background_brush

	text_color := hexToColorRef( g_theme_text )
	control_bg_color := hexToColorRef( g_theme_control )
	window_bg_color := hexToColorRef( g_theme_bg )
	control_class := getWindowClassName( l_param )
	is_edit_control := ( control_class = "Edit" )

	DllCall( "SetTextColor", "Ptr", w_param, "UInt", text_color )

	if ( is_edit_control || msg = 0x0133 || msg = 0x0134 )
	{
		DllCall( "SetBkColor", "Ptr", w_param, "UInt", control_bg_color )
		DllCall( "SetBkMode", "Ptr", w_param, "Int", 2 )

		if !g_theme_control_brush
		{
			g_theme_control_brush := DllCall( "CreateSolidBrush", "UInt", control_bg_color, "Ptr" )
		}

		return g_theme_control_brush
	}

	DllCall( "SetBkColor", "Ptr", w_param, "UInt", window_bg_color )
	DllCall( "SetBkMode", "Ptr", w_param, "Int", 1 )

	if !g_theme_background_brush
	{
		g_theme_background_brush := DllCall( "CreateSolidBrush", "UInt", window_bg_color, "Ptr" )
	}

	return g_theme_background_brush
}

/*	Returns the native class name for one HWND.
	An empty string is returned for an invalid or destroyed control.
*/
getWindowClassName( control_hwnd )
{
	if !control_hwnd
	{
		return ""
	}

	VarSetCapacity( class_name_buffer, 256 * 2, 0 )
	class_name_length := DllCall( "GetClassNameW"
		, "Ptr", control_hwnd
		, "Ptr", &class_name_buffer
		, "Int", 256 )

	if !class_name_length
	{
		return ""
	}

	return StrGet( &class_name_buffer, class_name_length, "UTF-16" )
}

/*	Handles native WM_COMMAND notifications from fake tabs and buttons.
	The template buttons use Static controls with SS_NOTIFY enabled.
*/
onCommandMessage( w_param, l_param, msg, hwnd_value )
{
	global g_tab_button_controls
	global g_fake_button_actions

	control_hwnd := l_param
	if !control_hwnd
	{
		return
	}

	notification_code := ( w_param >> 16 ) & 0xFFFF
	if ( notification_code != 0 )
	{
		return
	}

	if g_tab_button_controls.HasKey( control_hwnd )
	{
		showPage( g_tab_button_controls[ control_hwnd ] )
		return 0
	}

	if g_fake_button_actions.HasKey( control_hwnd )
	{
		dispatchFakeButtonAction( control_hwnd, g_fake_button_actions[ control_hwnd ] )
		return 0
	}
}

/*	Executes one fake-button action by its registered name.
	All Browse actions use manager-owned dialogs and update controls by HWND.
*/
dispatchFakeButtonAction( control_hwnd, action_name )
{
	if ( action_name = "OnBrowseIrfanExe" )
	{
		return browseIrfanViewExecutable()
	}
	else if ( action_name = "OnBrowseIrfanIni" )
	{
		return browseIrfanViewIni()
	}
	else if ( action_name = "OnDetectPaths" )
	{
		return detectAndDisplayIrfanViewPaths()
	}
	else if ( action_name = "OnOpenIrfanIni" )
	{
		return openConfiguredIrfanViewIni()
	}
	else if ( action_name = "OnContextButton" )
	{
		return handleContextButtonAction( control_hwnd )
	}
	else if ( action_name = "OnTrayCheckPreset" )
	{
		monitorIrfanView( true, true )
		return true
	}
	else if ( action_name = "OnSaveAll" )
	{
		saveSettings()
		return true
	}
	else if ( action_name = "OnApplyCurrentPreset" )
	{
		return applySelectedPresetFromUi()
	}
	else if ( action_name = "OnRunTests" )
	{
		return runInternalTests()
	}
	else if ( action_name = "OnHideManager" )
	{
		saveSettings()
		Gui, Manager:Hide
		return true
	}
	else if ( action_name = "OnExitManager" )
	{
		exitManagerApplication()
		return true
	}

	return false
}

/*	Opens a manager-owned executable picker and updates the IrfanView field.
	The selected path is saved through the normal Save All workflow.
*/
browseIrfanViewExecutable()
{
	global g_irfan_exe_hwnd

	current_path := getGlobalControlValue( g_irfan_exe_hwnd )
	SplitPath, current_path,, initial_directory
	Gui, Manager:+OwnDialogs
	FileSelectFile, selected_path, 3, %initial_directory%, Select IrfanView executable, Executables (*.exe)
	if ErrorLevel
	{
		return false
	}

	setNativeControlText( g_irfan_exe_hwnd, selected_path )
	setStatus( "Selected IrfanView executable." )
	return true
}

/*	Opens a manager-owned INI picker and updates the active INI field.
	The dialog starts in the currently configured INI directory.
*/
browseIrfanViewIni()
{
	global g_irfan_ini_hwnd

	current_path := getGlobalControlValue( g_irfan_ini_hwnd )
	SplitPath, current_path,, initial_directory
	Gui, Manager:+OwnDialogs
	FileSelectFile, selected_path, 3, %initial_directory%, Select active IrfanView INI, INI files (*.ini)
	if ErrorLevel
	{
		return false
	}

	setNativeControlText( g_irfan_ini_hwnd, selected_path )
	setStatus( "Selected active IrfanView INI." )
	return true
}

/*	Handles the context-specific buttons inside one preset page.
	Browse Script, Capture Default and Apply Preset are routed here.
*/
handleContextButtonAction( control_hwnd )
{
	global g_button_contexts
	global g_preset_controls

	if !g_button_contexts.HasKey( control_hwnd )
	{
		return false
	}

	button_context := g_button_contexts[ control_hwnd ]
	preset_index := button_context.preset_index
	action_name := button_context.action
	control_map := g_preset_controls[ preset_index ]

	if ( action_name = "browseScript" )
	{
		current_path := getGlobalControlValue( control_map.script_path )
		SplitPath, current_path,, initial_directory
		Gui, Manager:+OwnDialogs
		FileSelectFile, selected_path, 3, %initial_directory%, Select post-apply script, Scripts (*.ahk; *.exe; *.bat; *.cmd; *.ps1; *.vbs; *.js; *.py)
		if ErrorLevel
		{
			return false
		}

		setNativeControlText( control_map.script_path, selected_path )
		setStatus( "Selected post-apply script." )
		return true
	}
	else if ( action_name = "captureDefault" )
	{
		saveSettings()
		return captureCurrentAsDefault()
	}
	else if ( action_name = "applyPreset" )
	{
		saveSettings()
		irfan_hwnd := findIrfanViewWindow()
		image_path := irfan_hwnd ? getIrfanViewImagePath( irfan_hwnd ) : ""
		return applyPreset( preset_index, image_path, irfan_hwnd, false )
	}

	return false
}

/*	Detects and displays the standard IrfanView executable and INI paths.
	Both fields are updated through native HWND text messages.
*/
detectAndDisplayIrfanViewPaths()
{
	global g_irfan_exe_hwnd
	global g_irfan_ini_hwnd

	detected_exe := detectIrfanViewExecutable()
	detected_ini := detectIrfanViewIni( detected_exe )
	setNativeControlText( g_irfan_exe_hwnd, detected_exe )
	setNativeControlText( g_irfan_ini_hwnd, detected_ini )
	setStatus( detected_exe = "" ? "IrfanView was not found in standard folders." : "Detected IrfanView paths." )
	return ( detected_exe != "" )
}

/*	Opens the currently configured IrfanView INI in its default editor.
*/
openConfiguredIrfanViewIni()
{
	global g_irfan_ini_hwnd
	irfan_ini_path := getGlobalControlValue( g_irfan_ini_hwnd )
	return openFileInDefaultEditor( irfan_ini_path )
}

/*	Applies the currently selected preset from the preferences window.
*/
applySelectedPresetFromUi()
{
	global g_current_page

	saveSettings()
	irfan_hwnd := findIrfanViewWindow()
	image_path := irfan_hwnd ? getIrfanViewImagePath( irfan_hwnd ) : ""
	return applyPreset( g_current_page, image_path, irfan_hwnd, false )
}

/*	Closes the manager after saving all current preferences.
*/
exitManagerApplication()
{
	global g_exit_requested
	g_exit_requested := true
	saveSettings()
	ExitApp
}

/*	Renames a preset directly from its tab caption.
	Right-clicking a fake tab opens the rename dialog.
*/
onRightButtonUp( w_param, l_param, msg, hwnd_value )
{
	global g_tab_button_controls

	MouseGetPos,,,, control_hwnd, 2
	if g_tab_button_controls.HasKey( control_hwnd )
	{
		renamePresetTab( g_tab_button_controls[ control_hwnd ] )
		return 0
	}
}

/*	Stores a new preset name and refreshes its tab caption.
	The tab caption is the authoritative preset name.
*/
renamePresetTab( preset_index )
{
	global g_presets
	global g_tab_hwnds

	if !g_presets.HasKey( preset_index )
	{
		return false
	}

	current_name := g_presets[ preset_index ].name
	InputBox, new_name, Rename Preset, Enter the new preset name.,, 360, 150,,,,, %current_name%
	if ErrorLevel
	{
		return false
	}

	new_name := Trim( new_name )
	if ( new_name = "" )
	{
		showError( "Preset name cannot be empty." )
		return false
	}

	g_presets[ preset_index ].name := new_name
	tab_hwnd := g_tab_hwnds[ preset_index ]
	GuiControl,, %tab_hwnd%, %new_name%
	saveSettings()
	setStatus( "Renamed preset: " new_name )
	return true
}

/*	Reads text or state directly from one native control HWND.
	This remains reliable while the named preferences GUI is hidden.
*/
getGlobalControlValue( control_hwnd )
{
	if !control_hwnd
	{
		return ""
	}

	control_class := getWindowClassName( control_hwnd )
	if ( control_class = "ComboBox" )
	{
		selected_index := DllCall( "SendMessageW"
			, "Ptr", control_hwnd
			, "UInt", 0x0147
			, "Ptr", 0
			, "Ptr", 0
			, "Int" )
		return selected_index < 0 ? 0 : selected_index + 1
	}

	if ( control_class = "Button" )
	{
		return DllCall( "SendMessageW"
			, "Ptr", control_hwnd
			, "UInt", 0x00F0
			, "Ptr", 0
			, "Ptr", 0
			, "Int" )
	}

	text_length := DllCall( "GetWindowTextLengthW", "Ptr", control_hwnd, "Int" )
	VarSetCapacity( control_text_buffer, ( text_length + 1 ) * 2, 0 )
	DllCall( "GetWindowTextW"
		, "Ptr", control_hwnd
		, "Ptr", &control_text_buffer
		, "Int", text_length + 1 )
	return StrGet( &control_text_buffer, text_length, "UTF-16" )
}

/*	Copies all tab values into the in-memory preset records.
	The stored tab caption remains the authoritative preset name.
*/
readControlsIntoSettings()
{
	global g_presets
	global g_preset_count
	global g_preset_controls
	global g_tab_hwnds
	global g_irfan_exe_hwnd
	global g_irfan_ini_hwnd
	global g_monitor_checkbox_hwnd

	g_presets.general.irfan_exe := getGlobalControlValue( g_irfan_exe_hwnd )
	g_presets.general.irfan_ini := getGlobalControlValue( g_irfan_ini_hwnd )
	g_presets.general.monitor_enabled := getGlobalControlValue( g_monitor_checkbox_hwnd ) + 0

	Loop, %g_preset_count%
	{
		preset_index := A_Index
		control_map := g_preset_controls[ preset_index ]
		preset_data := g_presets[ preset_index ]

		if ( Trim( preset_data.name ) = "" )
		{
			preset_data.name := "Preset " preset_index
		}

		preset_data.enabled := 1
		preset_data.include_rules := normalizeLineBreaks( getGlobalControlValue( control_map.include_rules ) )
		preset_data.exclude_rules := ""
		preset_data.restart_viewer := 1
		preset_data.run_script := Trim( getGlobalControlValue( control_map.script_path ) ) != ""
		preset_data.script_path := Trim( getGlobalControlValue( control_map.script_path ) )
		preset_data.window_mode := getPresetOptionFromChoice( "window", getGlobalControlValue( control_map.window_mode ) )
		preset_data.fullscreen_mode := getPresetOptionFromChoice( "fullscreen", getGlobalControlValue( control_map.fullscreen_mode ) )
		preset_data.window_position_mode := getPresetOptionFromChoice( "window_position", getGlobalControlValue( control_map.window_position_mode ) )
		preset_data.title_mode := getPresetOptionFromChoice( "title", getGlobalControlValue( control_map.title_mode ) )
		preset_data.wheel_mode := getPresetOptionFromChoice( "wheel", getGlobalControlValue( control_map.wheel_mode ) )
		preset_data.keyboard_mode := getPresetOptionFromChoice( "keyboard", getGlobalControlValue( control_map.keyboard_mode ) )

		g_presets[ preset_index ] := preset_data
		tab_hwnd := g_tab_hwnds[ preset_index ]
		GuiControl,, %tab_hwnd%, % preset_data.name
	}
}

/*	Writes all manager, preset and visible option settings.
	Multi-line path rules use a reversible token encoding.
*/
saveSettings()
{
	global g_settings_path
	global g_presets
	global g_preset_count
	global g_monitor_interval
	global g_schema_version
	global g_last_image_path
	global g_last_applied_preset

	readControlsIntoSettings()

	IniWrite, % g_presets.general.irfan_exe, %g_settings_path%, General, IrfanViewExe
	IniWrite, % g_presets.general.irfan_ini, %g_settings_path%, General, IrfanViewIni
	IniWrite, % g_presets.general.monitor_enabled, %g_settings_path%, General, MonitorEnabled
	IniWrite, %g_monitor_interval%, %g_settings_path%, General, MonitorInterval
	IniWrite, %g_schema_version%, %g_settings_path%, General, SchemaVersion
	IniWrite, %g_last_image_path%, %g_settings_path%, General, LastImagePath
	IniWrite, %g_last_applied_preset%, %g_settings_path%, General, LastAppliedPreset

	Loop, %g_preset_count%
	{
		preset_index := A_Index
		section_name := "Preset" preset_index
		preset_data := g_presets[ preset_index ]

		IniWrite, % preset_data.name, %g_settings_path%, %section_name%, Name
		IniWrite, % preset_data.enabled, %g_settings_path%, %section_name%, Enabled
		IniWrite, % encodeStoredText( preset_data.include_rules ), %g_settings_path%, %section_name%, IncludeRules
		IniWrite, % preset_data.restart_viewer, %g_settings_path%, %section_name%, RestartViewer
		IniWrite, % preset_data.run_script, %g_settings_path%, %section_name%, RunScript
		IniWrite, % preset_data.script_path, %g_settings_path%, %section_name%, ScriptPath
		IniWrite, % preset_data.script_arguments, %g_settings_path%, %section_name%, ScriptArguments
		IniWrite, % preset_data.window_mode, %g_settings_path%, %section_name%, WindowMode
		IniWrite, % preset_data.fullscreen_mode, %g_settings_path%, %section_name%, FullscreenMode
		IniWrite, % preset_data.window_position_mode, %g_settings_path%, %section_name%, WindowPositionMode
		IniWrite, % preset_data.title_mode, %g_settings_path%, %section_name%, TitleMode
		IniWrite, % preset_data.wheel_mode, %g_settings_path%, %section_name%, WheelMode
		IniWrite, % preset_data.keyboard_mode, %g_settings_path%, %section_name%, KeyboardMode
	}

	setStatus( "Settings saved." )
	updateCurrentPageSummary()
}

/*	Encodes newlines so multi-line controls fit safely in one INI value.
	Literal token text is escaped before line breaks are converted.
*/
encodeStoredText( input_text )
{
	input_text := normalizeLineBreaks( input_text )
	StringReplace, input_text, input_text, <IVPM_NL>, <IVPM_NL_ESC>, All
	StringReplace, input_text, input_text, `n, <IVPM_NL>, All
	return input_text
}

/*	Decodes a stored multi-line manager value.
	This reverses encodeStoredText() without changing Windows paths.
*/
decodeStoredText( input_text )
{
	StringReplace, input_text, input_text, <IVPM_NL>, `n, All
	StringReplace, input_text, input_text, <IVPM_NL_ESC>, <IVPM_NL>, All
	return input_text
}

/*	Normalizes text to line-feed separators internally.
	GUI controls and parsers then use one predictable newline style.
*/
normalizeLineBreaks( input_text )
{
	StringReplace, input_text, input_text, `r`n, `n, All
	StringReplace, input_text, input_text, `r, `n, All
	return input_text
}

/*	Creates the tray-only menu used by DisplayFusion launches.
	The preferences dialog remains hidden until opened from this menu.
*/
createTrayMenu()
{
	global g_application_name

	tray_icon_path := A_WinDir "\System32\shell32.dll"
	Menu, Tray, Icon, %tray_icon_path%, 2, 1
	Menu, Tray, NoStandard
	Menu, Tray, Tip, %g_application_name%
	Menu, Tray, Add, Open Preferences, OnTrayShow
	Menu, Tray, Add, Check Current Preset, OnTrayCheckPreset
	Menu, Tray, Add, Apply Selected Preset, OnApplyCurrentPreset
	Menu, Tray, Add
	Menu, Tray, Add, Exit, OnExitManager
	Menu, Tray, Default, Open Preferences
	Menu, Tray, Click, 1
}

/*	Updates tray and GUI labels for the monitoring state.
	The state itself is controlled by startMonitoring() and stopMonitoring().
*/
updateMonitorButton()
{
	global g_monitor_button_hwnd

	GuiControl,, %g_monitor_button_hwnd%, Check Current
}

/*	Starts periodic IrfanView path monitoring.
	The optional notification is used only for direct user actions.
*/
startMonitoring( show_notification := true )
{
	global g_monitor_running
	global g_monitor_interval
	global g_monitor_checkbox_hwnd

	if ( g_monitor_running )
	{
		return
	}

	g_monitor_running := true
	GuiControl,, %g_monitor_checkbox_hwnd%, 1
	SetTimer, MonitorIrfanViewTimer, %g_monitor_interval%
	updateMonitorButton()
	setStatus( "Monitoring IrfanView image paths." )

	if ( show_notification )
	{
		TrayTip, IrfanView Preset Manager, Monitoring started., 2, 1
	}

	monitorIrfanView()
}

/*	Stops periodic IrfanView path monitoring.
	Manual preset application remains available.
*/
stopMonitoring( show_notification := true )
{
	global g_monitor_running
	global g_monitor_checkbox_hwnd

	if !g_monitor_running
	{
		return
	}

	g_monitor_running := false
	GuiControl,, %g_monitor_checkbox_hwnd%, 0
	SetTimer, MonitorIrfanViewTimer, Off
	updateMonitorButton()
	setStatus( "Monitoring stopped." )

	if ( show_notification )
	{
		TrayTip, IrfanView Preset Manager, Monitoring stopped., 2, 1
	}
}

/*	Polls the best IrfanView window and validates the preset for its image path.
	The first startup check compares managed INI values instead of trusting session memory.
*/
monitorIrfanView( force_check := false, show_active_notification := false )
{
	global g_apply_in_progress
	global g_last_image_path
	global g_last_applied_preset
	global g_last_irfan_hwnd
	global g_current_image_hwnd
	global g_presets
	global g_startup_check_complete

	if ( g_apply_in_progress )
	{
		return
	}

	irfan_hwnd := findIrfanViewWindow()
	if !irfan_hwnd
	{
		g_last_irfan_hwnd := 0
		setCurrentImagePath( "" )
		setStatus( "No IrfanView image window detected." )
		if ( show_active_notification )
		{
			TrayTip, IrfanView Preset Manager, No IrfanView image window detected., 3, 2
		}
		return
	}

	g_last_irfan_hwnd := irfan_hwnd
	image_path := getIrfanViewImagePath( irfan_hwnd )
	if ( image_path = "" )
	{
		setCurrentImagePath( "" )
		setStatus( "Could not resolve the current IrfanView image path." )
		if ( show_active_notification )
		{
			notification_text := "IrfanView was detected, but its current image path could not be resolved."
			TrayTip, IrfanView Preset Manager, %notification_text%, 4, 2
		}
		return
	}

	setCurrentImagePath( image_path )
	preset_index := findMatchingPreset( image_path )

	if !preset_index
	{
		g_last_image_path := image_path
		g_last_applied_preset := 0
		persistRuntimeState()
		setActivePresetText( 0 )
		setStatus( "No preset matches the current image path." )
		g_startup_check_complete := true
		return
	}

	path_changed := ( image_path != g_last_image_path )
	g_last_image_path := image_path
	setActivePresetText( preset_index )

	if ( !force_check && g_startup_check_complete && !path_changed && preset_index = g_last_applied_preset )
	{
		return
	}

	irfan_ini := Trim( g_presets.general.irfan_ini )
	preset_identity_matches := ( g_last_applied_preset = 0 || g_last_applied_preset = preset_index )
	if ( preset_identity_matches && isPresetCurrentlyApplied( preset_index, irfan_ini ) )
	{
		g_last_applied_preset := preset_index
		persistRuntimeState()
		setStatus( "Correct preset is already active: " g_presets[ preset_index ].name )
		if ( !g_startup_check_complete || show_active_notification )
		{
			showPresetTrayNotification( g_presets[ preset_index ].name, false )
		}
		g_startup_check_complete := true
		return
	}

	apply_result := applyPreset( preset_index, image_path, irfan_hwnd, true )
	g_startup_check_complete := true
	if !apply_result
	{
		persistRuntimeState()
	}
}

/*	Returns true when the active IrfanView INI already matches one preset.
	Only keys managed by the preset manager are compared.
*/
isPresetCurrentlyApplied( preset_index, target_ini_path )
{
	global g_presets

	if ( !g_presets.HasKey( preset_index ) || target_ini_path = "" || !FileExist( target_ini_path ) )
	{
		return false
	}

	snapshot_path := getDefaultIniSnapshotPath( target_ini_path )
	baseline_path := FileExist( snapshot_path ) ? snapshot_path : target_ini_path
	preset_data := g_presets[ preset_index ]
	managed_keys := getManagedPresetIniKeys()

	for key_index, key_data in managed_keys
	{
		actual_value := readIrfanIniValue( target_ini_path, key_data.section, key_data.key )
		baseline_value := readIrfanIniValue( baseline_path, key_data.section, key_data.key )
		expected_value := getExpectedPresetIniValue( preset_data, key_data.section, key_data.key, baseline_value )

		if ( actual_value != expected_value )
		{
			return false
		}
	}

	return true
}

/*	Returns the complete list of IrfanView INI values controlled by presets.
	The same list is used for startup detection and tests.
*/
getManagedPresetIniKeys()
{
	return [ { section: "Viewing", key: "FitWindowOption" }
		, { section: "Viewing", key: "ShowFullScreen" }
		, { section: "Others", key: "CenterWindow" }
		, { section: "Others", key: "RememberWinPos" }
		, { section: "Others", key: "ShowFullPath" }
		, { section: "Others", key: "JumpOnPageKey" }
		, { section: "Viewing", key: "MultipageScroll" } ]
}

/*	Reads one INI value while preserving the difference between empty and missing.
	A private marker is returned when the key does not exist.
*/
readIrfanIniValue( ini_path, section_name, key_name )
{
	missing_marker := "<IVPM_MISSING_VALUE>"
	IniRead, output_value, %ini_path%, %section_name%, %key_name%, %missing_marker%
	return output_value
}

/*	Calculates one managed INI value for a preset without changing any files.
	Unmodified options inherit the value captured by the Default snapshot.
*/
getExpectedPresetIniValue( preset_data, section_name, key_name, baseline_value )
{
	if ( section_name = "Viewing" && key_name = "FitWindowOption" && preset_data.window_mode = "fit_window" )
	{
		return "3"
	}

	if ( section_name = "Viewing" && key_name = "ShowFullScreen" && preset_data.fullscreen_mode = "fit_height" )
	{
		return "5"
	}

	if ( section_name = "Others" && key_name = "CenterWindow" && preset_data.window_position_mode = "keep" )
	{
		return "0"
	}

	if ( section_name = "Others" && key_name = "RememberWinPos" && preset_data.window_position_mode = "keep" )
	{
		return "1"
	}

	if ( section_name = "Others" && key_name = "ShowFullPath" )
	{
		if ( preset_data.title_mode = "full_path" )
		{
			return "1"
		}
		else if ( preset_data.title_mode = "filename" )
		{
			return "0"
		}
	}

	if ( section_name = "Others" && key_name = "JumpOnPageKey" )
	{
		if ( preset_data.keyboard_mode = "pan_image" )
		{
			return ( preset_data.wheel_mode = "never_change_images" ) ? "2" : "0"
		}
		if ( preset_data.wheel_mode = "change_images" )
		{
			return "1"
		}
		else if ( preset_data.wheel_mode = "never_change_images" )
		{
			return "2"
		}
	}

	if ( section_name = "Viewing" && key_name = "MultipageScroll" && preset_data.keyboard_mode = "pan_image" )
	{
		return "0"
	}

	return baseline_value
}

/*	Shows the Windows notification used for automatic and manual preset checks.
	The preset name is always included in the visible message.
*/
showPresetTrayNotification( preset_name, was_loaded := true )
{
	global g_application_name

	message_text := was_loaded ? "Loaded preset: " preset_name : "Active preset: " preset_name
	TrayTip, %g_application_name%, %message_text%, 3, 1
}

/*	Persists only runtime state without reading or rewriting hidden GUI controls.
	This is important when DisplayFusion replaces an existing manager instance.
*/
persistRuntimeState()
{
	global g_settings_path
	global g_last_image_path
	global g_last_applied_preset

	IniWrite, %g_last_image_path%, %g_settings_path%, General, LastImagePath
	IniWrite, %g_last_applied_preset%, %g_settings_path%, General, LastAppliedPreset
}

/*	Finds the best IrfanView top-level window without requiring a title.
	The active window wins; class, configured executable and visibility add priority.
*/
findIrfanViewWindow()
{
	global g_presets

	configured_exe_name := ""
	configured_exe_path := ""
	if ( IsObject( g_presets ) && g_presets.HasKey( "general" ) )
	{
		configured_exe_path := Trim( g_presets.general.irfan_exe )
		SplitPath, configured_exe_path, configured_exe_name
	}

	WinGet, active_hwnd, ID, A
	previous_detect_hidden := A_DetectHiddenWindows
	DetectHiddenWindows, On
	WinGet, all_window_list, List

	best_hwnd := 0
	best_score := -1
	Loop, %all_window_list%
	{
		window_hwnd := all_window_list%A_Index%
		if !isIrfanViewWindowCandidate( window_hwnd, configured_exe_name, configured_exe_path )
		{
			continue
		}

		window_score := getIrfanViewWindowScore( window_hwnd, active_hwnd )
		if ( window_score > best_score )
		{
			best_score := window_score
			best_hwnd := window_hwnd
		}
	}

	if ( previous_detect_hidden = "Off" )
	{
		DetectHiddenWindows, Off
	}

	return best_hwnd
}

/*	Returns true when a top-level window belongs to IrfanView.
	Class matching also supports renamed or portable IrfanView executables.
*/
isIrfanViewWindowCandidate( window_hwnd, configured_exe_name := "", configured_exe_path := "" )
{
	if !window_hwnd
	{
		return false
	}

	WinGetClass, window_class, ahk_id %window_hwnd%
	WinGetTitle, window_title, ahk_id %window_hwnd%
	WinGet, process_name, ProcessName, ahk_id %window_hwnd%
	WinGet, process_path, ProcessPath, ahk_id %window_hwnd%

	window_class_lower := toLowerText( window_class )
	window_title_lower := toLowerText( window_title )
	if ( window_class_lower = "#32770" )
	{
		return false
	}

	if ( InStr( window_class_lower, "thumbnail" ) || InStr( window_title_lower, "irfanview thumbnails" ) )
	{
		return false
	}

	process_name_lower := toLowerText( process_name )
	process_path_lower := toLowerText( process_path )
	configured_name_lower := toLowerText( configured_exe_name )
	configured_path_lower := toLowerText( configured_exe_path )

	process_matches := ( process_name_lower = "i_view64.exe" || process_name_lower = "i_view32.exe" )
	if ( configured_name_lower != "" && process_name_lower = configured_name_lower )
	{
		process_matches := true
	}
	if ( configured_path_lower != "" && process_path_lower = configured_path_lower )
	{
		process_matches := true
	}

	class_matches := InStr( window_class_lower, "irfanview" ) = 1
	if ( !process_matches && !class_matches )
	{
		return false
	}

	return true
}

/*	Scores IrfanView candidates so the actual image window is selected.
	Active, visible, main-class and unowned windows receive higher priority.
*/
getIrfanViewWindowScore( window_hwnd, active_hwnd )
{
	window_score := 0
	WinGetClass, window_class, ahk_id %window_hwnd%
	WinGetTitle, window_title, ahk_id %window_hwnd%
	WinGet, window_style, Style, ahk_id %window_hwnd%
	window_owner := DllCall( "GetWindow", "Ptr", window_hwnd, "UInt", 4, "Ptr" )

	if ( window_hwnd = active_hwnd )
	{
		window_score += 1000
	}
	if ( window_style & 0x10000000 )
	{
		window_score += 200
	}
	if ( toLowerText( window_class ) = "irfanview" )
	{
		window_score += 100
	}
	if ( window_owner = 0 )
	{
		window_score += 50
	}
	if ( Trim( window_title ) != "" )
	{
		window_score += 20
	}

	return window_score
}

/*	Extracts the current image path from the IrfanView title bar.
	Filename-only titles are resolved against the previously known image folder.
*/
getIrfanViewImagePath( irfan_hwnd )
{
	global g_last_image_path

	WinGetTitle, window_title, ahk_id %irfan_hwnd%
	window_title := Trim( window_title )

	if ( window_title != "" )
	{
		window_title := RegExReplace( window_title, "i)\s+-\s+IrfanView(?:\s+64-bit)?(?:.*)?$", "" )
		window_title := RegExReplace( window_title, "i)\s+:\s+Page\s+\d+\s+of\s+\d+\s*$", "" )
		window_title := Trim( window_title, " `t" Chr(34) )

		title_path := findExistingImagePathInTitle( window_title )
		if ( title_path != "" )
		{
			return title_path
		}

		if ( g_last_image_path != "" && !RegExMatch( window_title, "i)^[A-Z]:\\|^\\\\" ) )
		{
			SplitPath, g_last_image_path,, previous_directory
			cached_candidate := previous_directory "\" window_title
			if isExistingFilePath( cached_candidate )
			{
				return cached_candidate
			}
		}
	}

	clipboard_path := getIrfanViewClipboardPath( irfan_hwnd )
	if ( clipboard_path != "" )
	{
		return clipboard_path
	}

	return ""
}

/*	Finds an existing file path inside a cleaned IrfanView title.
	Trailing IrfanView status groups are removed one at a time.
*/
findExistingImagePathInTitle( window_title )
{
	candidate_path := Trim( window_title, " `t" Chr(34) )
	Loop, 12
	{
		if isExistingFilePath( candidate_path )
		{
			return candidate_path
		}

		separator_position := InStr( candidate_path, " - ", false, 0 )
		if !separator_position
		{
			break
		}

		candidate_path := RTrim( SubStr( candidate_path, 1, separator_position - 1 ) )
	}

	return ""
}

/*	Returns true only for an existing non-directory path.
*/
isExistingFilePath( file_path )
{
	file_attributes := FileExist( file_path )
	return ( file_attributes != "" && !InStr( file_attributes, "D" ) )
}

/*	Asks IrfanView to copy its current filename using the native Shift+P hotkey.
	The user's clipboard is restored immediately after the path is read.
*/
getIrfanViewClipboardPath( irfan_hwnd )
{
	global g_last_image_path

	if !irfan_hwnd
	{
		return ""
	}

	clipboard_saved := ClipboardAll
	Clipboard :=
	ControlSend,, +p, ahk_id %irfan_hwnd%
	ClipWait, 0.4
	copied_path := Trim( Clipboard, " `t`r`n" Chr(34) )
	Clipboard := clipboard_saved
	VarSetCapacity( clipboard_saved, 0 )

	if ( copied_path = "" )
	{
		return ""
	}

	if isExistingFilePath( copied_path )
	{
		return copied_path
	}

	if ( g_last_image_path != "" )
	{
		SplitPath, g_last_image_path,, previous_directory
		cached_candidate := previous_directory "\" copied_path
		if isExistingFilePath( cached_candidate )
		{
			return cached_candidate
		}
	}

	return ""
}

/*	Finds the winning preset for one full image path.
	Specific include rules win before an empty Default fallback, regardless of tab order.
*/
findMatchingPreset( image_path )
{
	global g_preset_count
	global g_presets

	readControlsIntoSettings()
	return findMatchingPresetInCollection( g_presets, g_preset_count, image_path )
}

/*	Resolves a preset collection with specific rules before empty fallback rules.
	The separate helper allows the same priority behavior to be tested safely.
*/
findMatchingPresetInCollection( preset_collection, preset_count, image_path )
{
	fallback_preset_index := 0

	Loop, %preset_count%
	{
		preset_index := A_Index
		preset_data := preset_collection[ preset_index ]
		if !preset_data.enabled
		{
			continue
		}

		include_rules := parseRuleLines( preset_data.include_rules )
		if ( include_rules.MaxIndex() = "" )
		{
			if !fallback_preset_index
			{
				fallback_preset_index := preset_index
			}
			continue
		}

		if presetMatchesPath( preset_data, image_path )
		{
			return preset_index
		}
	}

	if ( fallback_preset_index && presetMatchesPath( preset_collection[ fallback_preset_index ], image_path ) )
	{
		return fallback_preset_index
	}

	return 0
}

/*	Tests include and exclude wildcard lists for one preset.
	Empty include rules match all paths; any matching exclude rule rejects the path.
*/
presetMatchesPath( preset_data, image_path )
{
	include_rules := parseRuleLines( preset_data.include_rules )
	exclude_rules := parseRuleLines( preset_data.exclude_rules )

	include_match := ( include_rules.MaxIndex() = "" )
	for index, rule_text in include_rules
	{
		if wildcardMatch( image_path, rule_text )
		{
			include_match := true
			break
		}
	}

	if !include_match
	{
		return false
	}

	for index, rule_text in exclude_rules
	{
		if wildcardMatch( image_path, rule_text )
		{
			return false
		}
	}

	return true
}

/*	Parses wildcard lines while ignoring blanks and semicolon comments.
	Rules stay in their original text form for case-insensitive matching.
*/
parseRuleLines( rules_text )
{
	rule_list := []
	rules_text := normalizeLineBreaks( rules_text )

	Loop, Parse, rules_text, `n
	{
		rule_text := Trim( A_LoopField )
		if ( rule_text = "" || SubStr( rule_text, 1, 1 ) = ";" )
		{
			continue
		}
		rule_list.Push( rule_text )
	}

	return rule_list
}

/*	Matches one Windows path against one simple wildcard pattern.
	Asterisk and question mark are supported and matching ignores case.
*/
wildcardMatch( input_text, wildcard_pattern )
{
	regex_pattern := wildcardToRegex( wildcard_pattern )
	return RegExMatch( input_text, "i)^" regex_pattern "$" ) ? true : false
}

/*	Converts a wildcard pattern into a safely escaped regular expression.
	Only asterisk and question mark retain wildcard meaning.
*/
wildcardToRegex( wildcard_pattern )
{
	regex_text := ""
	Loop, Parse, wildcard_pattern
	{
		character := A_LoopField
		if ( character = "*" )
		{
			regex_text .= ".*"
		}
		else if ( character = "?" )
		{
			regex_text .= "."
		}
		else if InStr( "\\.^$+()[]{}|", character )
		{
			regex_text .= "\" character
		}
		else
		{
			regex_text .= character
		}
	}

	return regex_text
}

/*	Applies one preset configuration and then its optional script.
	When restart is enabled, the same image and window rectangle are restored.
*/
applyPreset( preset_index, image_path := "", irfan_hwnd := 0, automatic_apply := false )
{
	global g_presets
	global g_apply_in_progress
	global g_last_applied_preset
	global g_last_image_path
	global g_last_irfan_hwnd
	global g_monitor_running
	global g_monitor_interval

	if ( g_apply_in_progress )
	{
		return false
	}

	readControlsIntoSettings()
	preset_data := g_presets[ preset_index ]
	irfan_exe := Trim( g_presets.general.irfan_exe )
	irfan_ini := Trim( g_presets.general.irfan_ini )

	if ( irfan_ini = "" )
	{
		showError( "Set the active IrfanView INI path first." )
		return false
	}

	if ( irfan_exe = "" && preset_data.restart_viewer && image_path != "" )
	{
		showError( "Set the IrfanView executable path before using viewer restart." )
		return false
	}

	if ( irfan_hwnd && image_path = "" )
	{
		showError( "The current image path could not be resolved. Enable full-path titles once, or reopen the manager after a known image was stored." )
		return false
	}

	if ( preset_data.source_ini != "" && !FileExist( preset_data.source_ini ) )
	{
		showError( "Preset INI does not exist:`n" preset_data.source_ini )
		return false
	}

	if ( preset_data.run_script && preset_data.script_path != "" && !FileExist( preset_data.script_path ) )
	{
		showError( "Preset script does not exist:`n" preset_data.script_path )
		return false
	}

	g_apply_in_progress := true
	was_monitoring := g_monitor_running
	if ( was_monitoring )
	{
		SetTimer, MonitorIrfanViewTimer, Off
	}

	window_state := captureWindowState( irfan_hwnd )
	if ( preset_data.window_position_mode = "keep" )
	{
		reopen_window_state := window_state
	}
	else
	{
		reopen_window_state := { valid: false }
	}
	viewer_closed := false

	if ( preset_data.restart_viewer && irfan_hwnd )
	{
		setStatus( "Closing IrfanView before changing its configuration..." )
		viewer_closed := closeIrfanViewWindow( irfan_hwnd, irfan_exe )
		if !viewer_closed
		{
			g_apply_in_progress := false
			if ( was_monitoring )
			{
				SetTimer, MonitorIrfanViewTimer, %g_monitor_interval%
			}
			showError( "IrfanView did not close, so its INI was not changed." )
			return false
		}
	}

	apply_result := applyPresetConfiguration( preset_data, irfan_ini )
	if !apply_result.success
	{
		if ( viewer_closed && image_path != "" )
		{
			reopenIrfanViewImage( irfan_exe, image_path, window_state )
		}

		g_apply_in_progress := false
		if ( was_monitoring )
		{
			SetTimer, MonitorIrfanViewTimer, %g_monitor_interval%
		}
		showError( apply_result.message )
		return false
	}

	new_irfan_hwnd := irfan_hwnd
	if ( viewer_closed && image_path != "" )
	{
		setStatus( "Reopening the current image with the new preset..." )
		new_irfan_hwnd := reopenIrfanViewImage( irfan_exe, image_path, reopen_window_state )
	}

	post_apply_status := ""
	if ( preset_data.run_script && preset_data.script_path != "" )
	{
		script_result := executePresetScript( preset_data, image_path, new_irfan_hwnd, irfan_exe, irfan_ini )
		if !script_result.success
		{
			setStatus( "Preset applied, but the post-apply script failed." )
			showError( script_result.message )
		}
		else if ( script_result.skipped )
		{
			post_apply_status := " — post-apply script already running"
		}
		else
		{
			post_apply_status := " — post-apply script started as administrator"
		}
	}

	g_last_applied_preset := preset_index
	g_last_image_path := image_path
	g_last_irfan_hwnd := new_irfan_hwnd
	persistRuntimeState()
	setActivePresetText( preset_index )
	setStatus( "Applied preset: " preset_data.name post_apply_status )
	showPresetTrayNotification( preset_data.name, true )

	g_apply_in_progress := false
	if ( was_monitoring )
	{
		SetTimer, MonitorIrfanViewTimer, %g_monitor_interval%
	}

	return true
}

/*	Builds a complete preset INI beside the target and replaces it once.
	The working file starts from the captured Default INI for deterministic presets.
*/
applyPresetConfiguration( preset_data, target_ini_path )
{
	if ( target_ini_path = "" )
	{
		return { success: false, message: "The active IrfanView INI path is empty." }
	}

	SplitPath, target_ini_path, target_ini_name, target_ini_dir
	if ( target_ini_dir = "" )
	{
		return { success: false, message: "The active IrfanView INI path is invalid:`n" target_ini_path }
	}

	if !FileExist( target_ini_dir )
	{
		FileCreateDir, %target_ini_dir%
		if ErrorLevel
		{
			return { success: false, message: "Could not create the IrfanView INI directory:`n" target_ini_dir }
		}
	}

	snapshot_result := ensureDefaultIniSnapshot( target_ini_path )
	if !snapshot_result.success
	{
		return snapshot_result
	}

	if FileExist( target_ini_path )
	{
		backup_path := target_ini_path ".ivpm-backup"
		FileCopy, %target_ini_path%, %backup_path%, 1
		if ErrorLevel
		{
			return { success: false, message: "Could not create the IrfanView INI backup:`n" backup_path }
		}
	}

	working_ini_path := target_ini_path ".ivpm-working"
	FileDelete, %working_ini_path%
	FileCopy, % snapshot_result.path, %working_ini_path%, 1
	if ErrorLevel
	{
		return { success: false, message: "Could not prepare the preset INI from Default:`n" snapshot_result.path }
	}

	option_result := applyPresetOptionsToIni( preset_data, working_ini_path )
	if !option_result.success
	{
		FileDelete, %working_ini_path%
		return option_result
	}

	FileMove, %working_ini_path%, %target_ini_path%, 1
	if ErrorLevel
	{
		FileDelete, %working_ini_path%
		return { success: false, message: "Could not replace the active IrfanView INI:`n" target_ini_path }
	}

	return { success: true, message: "Default INI restored and all preset options applied." }
}

/*	Returns the Default snapshot path belonging to one IrfanView INI.
	Separate i_view32.ini and i_view64.ini installations receive separate snapshots.
*/
getDefaultIniSnapshotPath( target_ini_path )
{
	SplitPath, target_ini_path, target_ini_name
	if ( target_ini_name = "" )
	{
		target_ini_name := "i_view64.ini"
	}

	return A_ScriptDir "\PresetManager.Default." target_ini_name
}

/*	Captures the active INI once when no Default snapshot exists.
	The first preset application therefore preserves the user's original setup.
*/
ensureDefaultIniSnapshot( target_ini_path )
{
	snapshot_path := getDefaultIniSnapshotPath( target_ini_path )
	if FileExist( snapshot_path )
	{
		return { success: true, path: snapshot_path, created: false }
	}

	if !FileExist( target_ini_path )
	{
		return { success: false, message: "The active IrfanView INI does not exist, so Default cannot be captured:`n" target_ini_path }
	}

	FileCopy, %target_ini_path%, %snapshot_path%, 0
	if ErrorLevel
	{
		return { success: false, message: "Could not capture the Default IrfanView INI:`n" snapshot_path }
	}

	return { success: true, path: snapshot_path, created: true }
}

/*	Overwrites the captured Default snapshot with the active IrfanView INI.
	A running viewer is closed first so its latest settings are written safely.
*/
captureCurrentAsDefault()
{
	global g_presets
	global g_monitor_running
	global g_monitor_interval

	readControlsIntoSettings()
	target_ini_path := Trim( g_presets.general.irfan_ini )
	irfan_exe := Trim( g_presets.general.irfan_exe )

	if ( target_ini_path = "" || !FileExist( target_ini_path ) )
	{
		showError( "Set an existing active IrfanView INI before capturing Default." )
		return false
	}

	irfan_hwnd := findIrfanViewWindow()
	image_path := irfan_hwnd ? getIrfanViewImagePath( irfan_hwnd ) : ""
	window_state := captureWindowState( irfan_hwnd )
	was_monitoring := g_monitor_running

	if ( irfan_hwnd && image_path = "" )
	{
		showError( "The current IrfanView image path could not be resolved. Close IrfanView, then capture Default again." )
		return false
	}

	if ( irfan_hwnd && irfan_exe = "" )
	{
		showError( "Set the IrfanView executable path before capturing Default from a running viewer." )
		return false
	}

	if ( was_monitoring )
	{
		SetTimer, MonitorIrfanViewTimer, Off
	}

	if ( irfan_hwnd && !closeIrfanViewWindow( irfan_hwnd, irfan_exe ) )
	{
		if ( was_monitoring )
		{
			SetTimer, MonitorIrfanViewTimer, %g_monitor_interval%
		}
		showError( "IrfanView did not close, so Default was not captured." )
		return false
	}

	snapshot_path := getDefaultIniSnapshotPath( target_ini_path )
	FileCopy, %target_ini_path%, %snapshot_path%, 1
	capture_failed := ErrorLevel

	if ( irfan_hwnd && image_path != "" )
	{
		reopenIrfanViewImage( irfan_exe, image_path, window_state )
	}

	if ( was_monitoring )
	{
		SetTimer, MonitorIrfanViewTimer, %g_monitor_interval%
	}

	if ( capture_failed )
	{
		showError( "Could not capture the Default IrfanView INI:`n" snapshot_path )
		return false
	}

	setStatus( "Captured current IrfanView configuration as Default." )
	return true
}

/*	Writes every selected preset option into the prepared working INI.
	Options left on their captured-setting choice retain values from the Default snapshot.
*/
applyPresetOptionsToIni( preset_data, target_ini_path )
{
	if ( preset_data.window_mode = "fit_window" )
	{
		if !writeIrfanIniValue( target_ini_path, "Viewing", "FitWindowOption", 3 )
		{
			return { success: false, message: "Could not write Window display option." }
		}
	}

	if ( preset_data.fullscreen_mode = "fit_height" )
	{
		if !writeIrfanIniValue( target_ini_path, "Viewing", "ShowFullScreen", 5 )
		{
			return { success: false, message: "Could not write Fullscreen display option." }
		}
	}

	if ( preset_data.window_position_mode = "keep" )
	{
		if !writeIrfanIniValue( target_ini_path, "Others", "CenterWindow", 0 )
		{
			return { success: false, message: "Could not disable window centering." }
		}
		if !writeIrfanIniValue( target_ini_path, "Others", "RememberWinPos", 1 )
		{
			return { success: false, message: "Could not enable remembered window position." }
		}
	}

	if ( preset_data.title_mode = "full_path" )
	{
		if !writeIrfanIniValue( target_ini_path, "Others", "ShowFullPath", 1 )
		{
			return { success: false, message: "Could not enable the full image path in the title." }
		}
	}
	else if ( preset_data.title_mode = "filename" )
	{
		if !writeIrfanIniValue( target_ini_path, "Others", "ShowFullPath", 0 )
		{
			return { success: false, message: "Could not select filename-only title display." }
		}
	}

	if ( preset_data.wheel_mode = "change_images" )
	{
		if !writeIrfanIniValue( target_ini_path, "Others", "JumpOnPageKey", 1 )
		{
			return { success: false, message: "Could not enable mouse-wheel image changes." }
		}
	}
	else if ( preset_data.wheel_mode = "never_change_images" )
	{
		if !writeIrfanIniValue( target_ini_path, "Others", "JumpOnPageKey", 2 )
		{
			return { success: false, message: "Could not disable mouse-wheel image changes." }
		}
	}

	if ( preset_data.keyboard_mode = "pan_image" )
	{
		page_key_value := ( preset_data.wheel_mode = "never_change_images" ) ? 2 : 0
		if !writeIrfanIniValue( target_ini_path, "Others", "JumpOnPageKey", page_key_value )
		{
			return { success: false, message: "Could not disable next/previous file loading with Page keys." }
		}
		if !writeIrfanIniValue( target_ini_path, "Viewing", "MultipageScroll", 0 )
		{
			return { success: false, message: "Could not disable multipage Page Up/Down navigation." }
		}
	}

	return { success: true, message: "Preset options written." }
}

/*	Writes one IrfanView INI key and returns its success state.
	This helper keeps option error handling consistent.
*/
writeIrfanIniValue( target_ini_path, section_name, key_name, key_value )
{
	IniWrite, %key_value%, %target_ini_path%, %section_name%, %key_name%
	return ErrorLevel ? false : true
}

/*	Parses and writes a standard INI fragment into the target INI.
	Comments, blank lines and section headers are supported.
*/
applyIniFragment( target_ini_path, fragment_text )
{
	fragment_text := normalizeLineBreaks( fragment_text )
	current_section := ""
	line_number := 0
	write_count := 0

	Loop, Parse, fragment_text, `n
	{
		line_number += 1
		line_text := Trim( A_LoopField )

		if ( line_text = "" || SubStr( line_text, 1, 1 ) = ";" || SubStr( line_text, 1, 1 ) = "#" )
		{
			continue
		}

		if RegExMatch( line_text, "^\[([^\]]+)\]$", section_match )
		{
			current_section := Trim( section_match1 )
			continue
		}

		separator_pos := InStr( line_text, "=" )
		if ( separator_pos <= 1 )
		{
			return { success: false, message: "Invalid INI override line " line_number ":`n" line_text }
		}

		if ( current_section = "" )
		{
			return { success: false, message: "INI override key appears before a [Section] on line " line_number "." }
		}

		key_name := Trim( SubStr( line_text, 1, separator_pos - 1 ) )
		key_value := SubStr( line_text, separator_pos + 1 )
		IniWrite, %key_value%, %target_ini_path%, %current_section%, %key_name%
		if ErrorLevel
		{
			return { success: false, message: "Could not write INI value:`n[" current_section "]`n" key_name "=" key_value }
		}
		write_count += 1
	}

	return { success: true, message: write_count " INI values written." }
}

/*	Captures one IrfanView window rectangle and display state.
	The data is used to restore the replacement window after restart.
*/
captureWindowState( window_hwnd )
{
	if !window_hwnd
	{
		return { valid: false }
	}

	WinGetPos, window_x, window_y, window_width, window_height, ahk_id %window_hwnd%
	WinGet, min_max_state, MinMax, ahk_id %window_hwnd%

	return { valid: true
		, x: window_x
		, y: window_y
		, width: window_width
		, height: window_height
		, min_max: min_max_state }
}

/*	Closes IrfanView safely before the active INI is replaced.
	Normal WM_CLOSE is followed by IrfanView /killmesoftly and a final process fallback.
*/
closeIrfanViewWindow( window_hwnd, configured_exe := "" )
{
	if !window_hwnd
	{
		return true
	}

	WinGet, viewer_process_id, PID, ahk_id %window_hwnd%
	WinGet, viewer_process_path, ProcessPath, ahk_id %window_hwnd%
	viewer_exe := Trim( viewer_process_path )
	if ( viewer_exe = "" || !FileExist( viewer_exe ) )
	{
		viewer_exe := Trim( configured_exe )
	}

	WinClose, ahk_id %window_hwnd%
	if waitForWindowClose( window_hwnd, 1800 )
	{
		return true
	}

	PostMessage, 0x0010, 0, 0,, ahk_id %window_hwnd%
	if waitForWindowClose( window_hwnd, 1200 )
	{
		return true
	}

	if ( viewer_exe != "" && FileExist( viewer_exe ) )
	{
		soft_close_command := buildElevatedCommand( buildIrfanViewSoftCloseCommand( viewer_exe ) )
		RunWait, %soft_close_command%,, Hide UseErrorLevel
		if waitForWindowClose( window_hwnd, 3500 )
		{
			return true
		}
	}

	if ( viewer_process_id )
	{
		Process, Close, %viewer_process_id%
		Process, WaitClose, %viewer_process_id%, 3
	}

	return waitForWindowClose( window_hwnd, 1200 )
}

/*	Builds IrfanView's supported graceful all-instance close command.
	The separate helper keeps quoting testable and safe for paths containing spaces.
*/
buildIrfanViewSoftCloseCommand( irfan_exe )
{
	return quoteCommandArgument( irfan_exe ) " /killmesoftly /silent"
}

/*	Waits for one HWND to disappear without depending on the active title-match mode.
	Milliseconds are used so the close sequence can react faster than WinWaitClose.
*/
waitForWindowClose( window_hwnd, timeout_ms )
{
	if !window_hwnd
	{
		return true
	}

	start_tick := A_TickCount
	while ( A_TickCount - start_tick < timeout_ms )
	{
		if !DllCall( "IsWindow", "Ptr", window_hwnd )
		{
			return true
		}

		Sleep, 50
	}

	return !DllCall( "IsWindow", "Ptr", window_hwnd )
}

/*	Reopens one image and restores the previous window rectangle.
	The returned HWND is used by post-apply script placeholders.
*/
reopenIrfanViewImage( irfan_exe, image_path, window_state )
{
	if ( irfan_exe = "" || image_path = "" )
	{
		return 0
	}

	command_line := buildElevatedCommand( quoteCommandArgument( irfan_exe ) " " quoteCommandArgument( image_path ) )
	SplitPath, irfan_exe,, irfan_directory
	Run, %command_line%, %irfan_directory%, UseErrorLevel, new_process_id
	if ErrorLevel
	{
		return 0
	}

	new_window_hwnd := 0
	if ( new_process_id )
	{
		WinWait, ahk_pid %new_process_id%,, 5
		WinGet, new_window_hwnd, ID, ahk_pid %new_process_id%
	}

	if !new_window_hwnd
	{
		start_tick := A_TickCount
		while ( A_TickCount - start_tick < 5000 )
		{
			new_window_hwnd := findIrfanWindowByImagePath( image_path )
			if ( new_window_hwnd )
			{
				break
			}
			Sleep, 100
		}
	}

	if ( new_window_hwnd && IsObject( window_state ) && window_state.valid )
	{
		WinRestore, ahk_id %new_window_hwnd%
		WinMove, ahk_id %new_window_hwnd%,, % window_state.x, % window_state.y, % window_state.width, % window_state.height
		if ( window_state.min_max = 1 )
		{
			WinMaximize, ahk_id %new_window_hwnd%
		}
	}

	return new_window_hwnd
}

/*	Finds an IrfanView window already displaying one exact image path.
	This supports IrfanView's optional single-instance behavior.
*/
findIrfanWindowByImagePath( image_path )
{
	for index, process_name in [ "i_view64.exe", "i_view32.exe" ]
	{
		WinGet, window_list, List, ahk_exe %process_name%
		Loop, %window_list%
		{
			window_hwnd := window_list%A_Index%
			window_image_path := getIrfanViewImagePath( window_hwnd )
			if ( toLowerText( window_image_path ) = toLowerText( image_path ) )
			{
				return window_hwnd
			}
		}
	}

	return 0
}

/*	Prefixes one external command with AutoHotkey's administrator launch verb.
	The helper keeps elevated command construction consistent and testable.
*/
buildElevatedCommand( command_line )
{
	return "*RunAs " command_line
}

/*	Returns the post-apply script's own directory as its working directory.
	Relative files used by the post-apply script therefore resolve beside that script.
*/
getPostApplyWorkingDirectory( script_path )
{
	SplitPath, script_path,, script_directory
	if ( script_directory = "" )
	{
		return A_ScriptDir
	}

	return script_directory
}

/*	Executes the preset script only when the same script is not already running.
	AutoHotkey, PowerShell and command scripts receive suitable launchers.
*/
executePresetScript( preset_data, image_path, irfan_hwnd, irfan_exe, irfan_ini )
{
	global g_post_apply_processes

	script_path := getFullPath( Trim( preset_data.script_path ) )
	running_process_id := findRunningPostApplyProcess( script_path )
	if ( running_process_id )
	{
		return { success: true
			, skipped: true
			, process_id: running_process_id
			, message: "Post-apply script is already running." }
	}

	arguments_text := expandScriptArguments( preset_data.script_arguments, preset_data.name, image_path, irfan_hwnd, irfan_exe, irfan_ini )
	SplitPath, script_path,,, script_extension
	script_extension := toLowerText( script_extension )

	if ( script_extension = "ahk" )
	{
		command_line := quoteCommandArgument( A_AhkPath ) " " quoteCommandArgument( script_path )
	}
	else if ( script_extension = "ps1" )
	{
		command_line := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " quoteCommandArgument( script_path )
	}
	else if ( script_extension = "bat" || script_extension = "cmd" )
	{
		EnvGet, command_processor, ComSpec
		if ( command_processor = "" )
		{
			command_processor := A_WinDir "\System32\cmd.exe"
		}
		command_line := quoteCommandArgument( command_processor ) " /c " quoteCommandArgument( script_path )
	}
	else
	{
		command_line := quoteCommandArgument( script_path )
	}

	if ( Trim( arguments_text ) != "" )
	{
		command_line .= " " arguments_text
	}

	script_directory := getPostApplyWorkingDirectory( script_path )
	elevated_command_line := buildElevatedCommand( command_line )
	Run, %elevated_command_line%, %script_directory%, UseErrorLevel, script_process_id
	if ErrorLevel
	{
		return { success: false
			, skipped: false
			, message: "Could not execute the post-apply script as administrator.`n`nScript:`n" script_path "`n`nWorking directory:`n" script_directory }
	}

	script_key := getPostApplyScriptKey( script_path )
	if ( script_key != "" && script_process_id )
	{
		trackPostApplyProcess( script_key, script_process_id )
	}

	return { success: true
		, skipped: false
		, process_id: script_process_id
		, message: "Post-apply script started as administrator." }
}

/*	Returns a normalized dictionary key for one post-apply script path.
	The same file configured in multiple presets shares one running-instance guard.
*/
getPostApplyScriptKey( script_path )
{
	script_path := Trim( script_path )
	if ( script_path = "" )
	{
		return ""
	}

	normalized_path := StrReplace( getFullPath( script_path ), "/", "\" )
	return toLowerText( normalized_path )
}

/*	Finds an already-running process whose command line belongs to the script path.
	A tracked PID is checked first; WMI then catches scripts started before this manager.
*/
findRunningPostApplyProcess( script_path )
{
	global g_post_apply_processes

	script_key := getPostApplyScriptKey( script_path )
	if ( script_key = "" )
	{
		return 0
	}

	if g_post_apply_processes.HasKey( script_key )
	{
		process_record := g_post_apply_processes[ script_key ]
		if isTrackedPostApplyProcessRunning( process_record )
		{
			return process_record.pid + 0
		}
		releasePostApplyProcessRecord( script_key )
	}

	try
	{
		process_service := ComObjGet( "winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2" )
		process_query := process_service.ExecQuery( "SELECT ProcessId, CommandLine, ExecutablePath FROM Win32_Process" )
		for process_item in process_query
		{
			try
			{
				process_id := process_item.ProcessId + 0
				process_command_line := process_item.CommandLine ""
				process_executable_path := process_item.ExecutablePath ""
			}
			catch process_item_error
			{
				continue
			}

			if processCommandReferencesScript( process_command_line, process_executable_path, script_path )
			{
				trackPostApplyProcess( script_key, process_id )
				return process_id
			}
		}
	}
	catch process_query_error
	{
	}

	return 0
}

/*	Stores an exact Windows process handle for one post-apply script.
	The handle prevents PID reuse from being mistaken for the original script process.
*/
trackPostApplyProcess( script_key, process_id )
{
	global g_post_apply_processes

	if ( script_key = "" || process_id <= 0 )
	{
		return false
	}

	if g_post_apply_processes.HasKey( script_key )
	{
		releasePostApplyProcessRecord( script_key )
	}

	process_handle := DllCall( "OpenProcess"
		, "UInt", 0x00100000
		, "Int", 0
		, "UInt", process_id
		, "Ptr" )

	g_post_apply_processes[ script_key ] := { pid: process_id, handle: process_handle }
	return true
}

/*	Returns true while the exact tracked process is still active.
	A synchronization handle is preferred, with a PID check as fallback.
*/
isTrackedPostApplyProcessRunning( process_record )
{
	if !IsObject( process_record )
	{
		return false
	}

	if ( process_record.handle )
	{
		wait_result := DllCall( "WaitForSingleObject"
			, "Ptr", process_record.handle
			, "UInt", 0
			, "UInt" )
		return ( wait_result = 0x00000102 )
	}

	return isProcessIdRunning( process_record.pid + 0 )
}

/*	Closes and removes one tracked post-apply process record.
	This keeps long-running tray sessions from leaking process handles.
*/
releasePostApplyProcessRecord( script_key )
{
	global g_post_apply_processes

	if !g_post_apply_processes.HasKey( script_key )
	{
		return false
	}

	process_record := g_post_apply_processes[ script_key ]
	if ( IsObject( process_record ) && process_record.handle )
	{
		DllCall( "CloseHandle", "Ptr", process_record.handle )
	}

	g_post_apply_processes.Delete( script_key )
	return true
}

/*	Returns true when a process executable or command line references the script path.
	Path separators and letter case are normalized before comparison.
*/
processCommandReferencesScript( process_command_line, process_executable_path, script_path )
{
	script_key := getPostApplyScriptKey( script_path )
	if ( script_key = "" )
	{
		return false
	}

	command_text := toLowerText( StrReplace( process_command_line, "/", "\" ) )
	executable_key := getPostApplyScriptKey( process_executable_path )

	if ( executable_key != "" && executable_key = script_key )
	{
		return true
	}

	quote_character := Chr(34)
	if InStr( command_text, quote_character script_key quote_character )
	{
		return true
	}

	padded_command_text := " " command_text " "
	return InStr( padded_command_text, " " script_key " " ) ? true : false
}

/*	Returns true while one Windows process ID still exists.
	A zero or recycled missing PID is rejected.
*/
isProcessIdRunning( process_id )
{
	if ( process_id <= 0 )
	{
		return false
	}

	Process, Exist, %process_id%
	return ( ErrorLevel = process_id )
}

/*	Expands all supported placeholders in a script argument line.
	Values are inserted verbatim so the user controls their own quoting.
*/
expandScriptArguments( arguments_text, preset_name, image_path, irfan_hwnd, irfan_exe, irfan_ini )
{
	SplitPath, image_path, image_name, image_dir
	StringReplace, arguments_text, arguments_text, {image_path}, %image_path%, All
	StringReplace, arguments_text, arguments_text, {image_dir}, %image_dir%, All
	StringReplace, arguments_text, arguments_text, {image_name}, %image_name%, All
	StringReplace, arguments_text, arguments_text, {preset_name}, %preset_name%, All
	StringReplace, arguments_text, arguments_text, {irfan_hwnd}, %irfan_hwnd%, All
	StringReplace, arguments_text, arguments_text, {irfan_exe}, %irfan_exe%, All
	StringReplace, arguments_text, arguments_text, {irfan_ini}, %irfan_ini%, All
	return arguments_text
}

/*	Quotes one command-line argument for Windows CreateProcess parsing.
	Embedded quotes are escaped conservatively.
*/
quoteCommandArgument( argument_text )
{
	quote_character := Chr(34)
	backslash_character := Chr(92)
	argument_text := StrReplace( argument_text, quote_character, backslash_character quote_character )
	return quote_character argument_text quote_character
}

/*	Returns an absolute normalized path where possible.
	The Windows API handles relative paths without requiring the target to exist.
*/
getFullPath( input_path )
{
	VarSetCapacity( output_buffer, 65536, 0 )
	result_length := DllCall( "GetFullPathNameW", "WStr", input_path, "UInt", 32768, "Ptr", &output_buffer, "Ptr", 0, "UInt" )
	if !result_length
	{
		return input_path
	}
	return StrGet( &output_buffer, result_length, "UTF-16" )
}

/*	Attempts to detect a standard IrfanView executable location.
	64-bit is preferred when both installations are present.
*/
detectIrfanViewExecutable()
{
	candidate_list := []
	candidate_list.Push( A_ProgramFiles "\IrfanView\i_view64.exe" )
	candidate_list.Push( A_ProgramFiles "\IrfanView\i_view32.exe" )

	EnvGet, program_files_x86, ProgramFiles(x86)
	if ( program_files_x86 != "" )
	{
		candidate_list.Push( program_files_x86 "\IrfanView\i_view32.exe" )
		candidate_list.Push( program_files_x86 "\IrfanView\i_view64.exe" )
	}

	for index, candidate_path in candidate_list
	{
		if FileExist( candidate_path )
		{
			return candidate_path
		}
	}

	return ""
}

/*	Attempts to detect the active IrfanView INI for one executable.
	AppData is checked before the executable directory.
*/
detectIrfanViewIni( irfan_exe := "" )
{
	ini_name := InStr( toLowerText( irfan_exe ), "i_view32.exe" ) ? "i_view32.ini" : "i_view64.ini"
	candidate_list := []
	candidate_list.Push( A_AppData "\IrfanView\" ini_name )

	if ( irfan_exe != "" )
	{
		SplitPath, irfan_exe,, irfan_directory
		candidate_list.Push( irfan_directory "\" ini_name )
	}

	candidate_list.Push( A_WinDir "\" ini_name )

	for index, candidate_path in candidate_list
	{
		if FileExist( candidate_path )
		{
			return candidate_path
		}
	}

	return candidate_list[ 1 ]
}

/*	Writes text directly to a native control and forces an immediate repaint.
	This avoids stale glyphs caused by delayed GuiControl redraws.
*/
setNativeControlText( control_hwnd, control_text )
{
	if !control_hwnd
	{
		return false
	}

	if ( control_text = "ERROR" )
	{
		control_text := ""
	}

	DllCall( "SetWindowTextW", "Ptr", control_hwnd, "WStr", control_text )
	DllCall( "InvalidateRect", "Ptr", control_hwnd, "Ptr", 0, "Int", 1 )
	DllCall( "UpdateWindow", "Ptr", control_hwnd )
	return true
}

/*	Displays only a validated existing image path in Current image.
	Invalid, missing or unresolved values always clear the read-only field.
*/
setCurrentImagePath( image_path )
{
	global g_current_image_hwnd

	image_path := Trim( image_path, " `t`r`n" Chr(34) )
	if ( image_path = "" || !isExistingFilePath( image_path ) )
	{
		image_path := ""
	}

	return setNativeControlText( g_current_image_hwnd, image_path )
}

/*	Updates the active-preset text in the manager footer.
	Zero clears the current preset state.
*/
setActivePresetText( preset_index )
{
	global g_presets
	global g_active_preset_text_hwnd

	if ( preset_index && g_presets.HasKey( preset_index ) )
	{
		preset_text := "Active preset: " g_presets[ preset_index ].name
	}
	else
	{
		preset_text := "Active preset: none"
	}

	setNativeControlText( g_active_preset_text_hwnd, preset_text )
}

/*	Writes one concise status string into the manager footer.
	The same state remains visible after switching preset tabs.
*/
setStatus( status_text )
{
	global g_status_text_hwnd
	setNativeControlText( g_status_text_hwnd, status_text )
}

/*	Shows the current preset's matching role in the status line.
	The note reminds users that tab order defines priority.
*/
updateCurrentPageSummary()
{
	global g_current_page
	global g_presets

	if !g_presets.HasKey( g_current_page )
	{
		return
	}

	setStatus( "Selected preset: " g_presets[ g_current_page ].name ". Right-click its tab to rename it." )
}

/*	Opens one file in the associated editor.
	A missing file is reported instead of silently failing.
*/
openFileInDefaultEditor( file_path )
{
	if ( file_path = "" )
	{
		showError( "No file path is configured." )
		return false
	}

	if !FileExist( file_path )
	{
		showError( "File does not exist:`n" file_path )
		return false
	}

	Run, % quoteCommandArgument( file_path )
	return true
}

/*	Displays a manager error message.
	Errors are kept modal because configuration writes can be destructive.
*/
showError( message_text )
{
	global g_application_name
	MsgBox, 16, %g_application_name%, %message_text%
}

/*	Tests preset detection with explicit preset and baseline files.
	This avoids changing global manager paths during the internal test suite.
*/
isPresetCurrentlyAppliedFromDataForTest( preset_data, target_ini_path, baseline_path )
{
	managed_keys := getManagedPresetIniKeys()
	for key_index, key_data in managed_keys
	{
		actual_value := readIrfanIniValue( target_ini_path, key_data.section, key_data.key )
		baseline_value := readIrfanIniValue( baseline_path, key_data.section, key_data.key )
		expected_value := getExpectedPresetIniValue( preset_data, key_data.section, key_data.key, baseline_value )
		if ( actual_value != expected_value )
		{
			return false
		}
	}
	return true
}

/*	Runs non-destructive tests for matching, option mapping and INI writes.
	Temporary test INIs are deleted after verification.
*/
runInternalTests()
{
	test_failures := []

	default_preset := getDefaultPreset( 1 )
	slideshow_preset := getDefaultPreset( 2 )
	references_preset := getDefaultPreset( 3 )

	if ( default_preset.name != "Default" || slideshow_preset.name != "Slideshow" || references_preset.name != "References" )
	{
		test_failures.Push( "Main preset names are incorrect." )
	}

	if ( slideshow_preset.fullscreen_mode != "fit_height" || slideshow_preset.title_mode != "full_path" || slideshow_preset.wheel_mode != "change_images" || slideshow_preset.keyboard_mode != "pan_image" )
	{
		test_failures.Push( "Slideshow default options are incorrect." )
	}

	if ( references_preset.window_mode != "fit_window" || references_preset.window_position_mode != "keep" || references_preset.title_mode != "filename" || references_preset.wheel_mode != "never_change_images" || references_preset.keyboard_mode != "pan_image" )
	{
		test_failures.Push( "References default options are incorrect." )
	}

	if !wildcardMatch( "D:\Images\Slideshow\001.jpg", "*\Slideshow\*" )
	{
		test_failures.Push( "Wildcard include test failed." )
	}

	if wildcardMatch( "D:\Images\Reference\Chair.jpg", "*\Slideshow\*" )
	{
		test_failures.Push( "Wildcard rejection test failed." )
	}

	test_collection := {}
	test_collection[ 1 ] := { enabled: 1, include_rules: "", exclude_rules: "" }
	test_collection[ 2 ] := { enabled: 1, include_rules: "*\Slideshow\*", exclude_rules: "" }
	test_collection[ 3 ] := { enabled: 1, include_rules: "*\Reference\*", exclude_rules: "" }

	if ( findMatchingPresetInCollection( test_collection, 3, "D:\Images\Slideshow\001.jpg" ) != 2 )
	{
		test_failures.Push( "Specific preset did not win before Default fallback." )
	}

	if ( findMatchingPresetInCollection( test_collection, 3, "D:\Images\Other\001.jpg" ) != 1 )
	{
		test_failures.Push( "Default fallback matching failed." )
	}

	if ( getPresetOptionFromChoice( "title", 3 ) != "filename" || getPresetOptionChoice( "wheel", "never_change_images" ) != 3 || getPresetOptionFromChoice( "keyboard", 2 ) != "pan_image" )
	{
		test_failures.Push( "Preset option dropdown mapping failed." )
	}

	test_script_path := "D:\Tools\PostApply.ahk"
	test_script_command := quoteCommandArgument( A_AhkPath ) " " quoteCommandArgument( test_script_path )
	if !processCommandReferencesScript( test_script_command, A_AhkPath, test_script_path )
	{
		test_failures.Push( "Post-apply process matching failed." )
	}
	if processCommandReferencesScript( test_script_command, A_AhkPath, "D:\Tools\OtherScript.ahk" )
	{
		test_failures.Push( "Post-apply process matching accepted the wrong script." )
	}
	if processCommandReferencesScript( quoteCommandArgument( "D:\Tools\PostApply.ahk.backup" ), "", test_script_path )
	{
		test_failures.Push( "Post-apply process matching accepted a partial path match." )
	}

	if ( buildElevatedCommand( test_script_command ) != "*RunAs " test_script_command )
	{
		test_failures.Push( "Administrator command construction failed." )
	}

	if ( getPostApplyWorkingDirectory( test_script_path ) != "D:\Tools" )
	{
		test_failures.Push( "Post-apply working-directory resolution failed." )
	}

	if !A_IsAdmin
	{
		test_failures.Push( "The manager is not running as administrator." )
	}

	test_soft_close_command := buildIrfanViewSoftCloseCommand( "C:\Program Files\IrfanView\i_view64.exe" )
	if ( test_soft_close_command != """C:\Program Files\IrfanView\i_view64.exe"" /killmesoftly /silent" )
	{
		test_failures.Push( "IrfanView soft-close command quoting failed." )
	}

	test_detection_ini := A_Temp "\PresetManager_detection_test.ini"
	test_detection_baseline_ini := A_Temp "\PresetManager_detection_baseline_test.ini"
	FileDelete, %test_detection_ini%
	FileDelete, %test_detection_baseline_ini%
	FileAppend, [Viewing]`nFitWindowOption=3`nShowFullScreen=1`nMultipageScroll=0`n[Others]`nCenterWindow=0`nRememberWinPos=1`nShowFullPath=0`nJumpOnPageKey=2`n, %test_detection_ini%
	FileAppend, [Viewing]`nFitWindowOption=5`nShowFullScreen=1`nMultipageScroll=1`n[Others]`nCenterWindow=1`nRememberWinPos=0`nShowFullPath=1`nJumpOnPageKey=0`n, %test_detection_baseline_ini%
	if !isPresetCurrentlyAppliedFromDataForTest( references_preset, test_detection_ini, test_detection_baseline_ini )
	{
		test_failures.Push( "Current preset INI detection failed." )
	}
	if isPresetCurrentlyAppliedFromDataForTest( slideshow_preset, test_detection_ini, test_detection_baseline_ini )
	{
		test_failures.Push( "Incorrect preset was accepted by INI detection." )
	}
	FileDelete, %test_detection_ini%
	FileDelete, %test_detection_baseline_ini%

	if !testNativeEditTextUpdate()
	{
		test_failures.Push( "Native Edit text update failed." )
	}

	if !testEditBackspaceDeletion()
	{
		test_failures.Push( "Edit-control Backspace deletion failed." )
	}

	test_slideshow_ini := A_Temp "\PresetManager_slideshow_test.ini"
	FileDelete, %test_slideshow_ini%
	FileAppend, [Viewing]`nFitWindowOption=5`nShowFullScreen=1`nMultipageScroll=1`n[Others]`nShowFullPath=0`nJumpOnPageKey=0`n, %test_slideshow_ini%

	slideshow_result := applyPresetOptionsToIni( slideshow_preset, test_slideshow_ini )
	if !slideshow_result.success
	{
		test_failures.Push( "Slideshow INI option write failed." )
	}
	else
	{
		IniRead, test_fullscreen_mode, %test_slideshow_ini%, Viewing, ShowFullScreen, ERROR
		IniRead, test_show_full_path, %test_slideshow_ini%, Others, ShowFullPath, ERROR
		IniRead, test_wheel_mode, %test_slideshow_ini%, Others, JumpOnPageKey, ERROR
		IniRead, test_slideshow_multipage, %test_slideshow_ini%, Viewing, MultipageScroll, ERROR

		if ( test_fullscreen_mode != "5" || test_show_full_path != "1" || test_wheel_mode != "0" || test_slideshow_multipage != "0" )
		{
			test_failures.Push( "Slideshow INI values are incorrect." )
		}
	}
	FileDelete, %test_slideshow_ini%

	test_references_ini := A_Temp "\PresetManager_references_test.ini"
	FileDelete, %test_references_ini%
	FileAppend, [Viewing]`nFitWindowOption=5`nMultipageScroll=1`n[Others]`nCenterWindow=1`nRememberWinPos=0`nShowFullPath=1`nJumpOnPageKey=0`n, %test_references_ini%

	references_result := applyPresetOptionsToIni( references_preset, test_references_ini )
	if !references_result.success
	{
		test_failures.Push( "References INI option write failed." )
	}
	else
	{
		IniRead, test_fit_window, %test_references_ini%, Viewing, FitWindowOption, ERROR
		IniRead, test_center_window, %test_references_ini%, Others, CenterWindow, ERROR
		IniRead, test_remember_position, %test_references_ini%, Others, RememberWinPos, ERROR
		IniRead, test_reference_title, %test_references_ini%, Others, ShowFullPath, ERROR
		IniRead, test_reference_wheel, %test_references_ini%, Others, JumpOnPageKey, ERROR
		IniRead, test_reference_multipage, %test_references_ini%, Viewing, MultipageScroll, ERROR

		if ( test_fit_window != "3" || test_center_window != "0" || test_remember_position != "1" || test_reference_title != "0" || test_reference_wheel != "2" || test_reference_multipage != "0" )
		{
			test_failures.Push( "References INI values are incorrect." )
		}
	}
	FileDelete, %test_references_ini%

	test_fragment_ini := A_Temp "\PresetManager_fragment_test.ini"
	FileDelete, %test_fragment_ini%
	test_fragment := "[Viewing]`nFitWindowOption=3`n[Menu]`nActive=0"
	test_result := applyIniFragment( test_fragment_ini, test_fragment )
	if !test_result.success
	{
		test_failures.Push( "INI fragment parser failed: " test_result.message )
	}
	else
	{
		IniRead, test_fragment_fit, %test_fragment_ini%, Viewing, FitWindowOption, ERROR
		IniRead, test_menu_active, %test_fragment_ini%, Menu, Active, ERROR
		if ( test_fragment_fit != "3" || test_menu_active != "0" )
		{
			test_failures.Push( "INI fragment write verification failed." )
		}
	}
	FileDelete, %test_fragment_ini%

	if ( test_failures.MaxIndex() = "" )
	{
		MsgBox, 64, IrfanView Preset Manager Tests, All internal tests passed.
		return true
	}

	failure_text := ""
	for index, failure_message in test_failures
	{
		failure_text .= index ". " failure_message "`n"
	}
	MsgBox, 16, IrfanView Preset Manager Tests, %failure_text%
	return false
}


OnTabButton:
{
	if g_tab_button_controls.HasKey( A_GuiControlHwnd )
	{
		showPage( g_tab_button_controls[ A_GuiControlHwnd ] )
	}
}
return

OnContextButton:
{
	handleContextButtonAction( A_GuiControlHwnd )
}
return

OnBrowseIrfanExe:
{
	browseIrfanViewExecutable()
}
return

OnBrowseIrfanIni:
{
	browseIrfanViewIni()
}
return

OnDetectPaths:
{
	detectAndDisplayIrfanViewPaths()
}
return

OnOpenIrfanIni:
{
	openConfiguredIrfanViewIni()
}
return

OnSaveAll:
{
	saveSettings()
}
return

OnApplyCurrentPreset:
{
	applySelectedPresetFromUi()
}
return

OnToggleMonitoring:
{
	if ( g_monitor_running )
	{
		stopMonitoring()
	}
	else
	{
		startMonitoring()
	}
	saveSettings()
}
return

OnRunTests:
{
	runInternalTests()
}
return

OnHideManager:
{
	saveSettings()
	Gui, Manager:Hide
}
return

OnTrayShow:
{
	if !showManagerDialog()
	{
		notification_text := "The preferences window could not be shown."
		TrayTip, IrfanView Preset Manager, %notification_text%, 4, 2
	}
}
return

OnTrayCheckPreset:
{
	monitorIrfanView( true, true )
}
return

OnTrayToggleMonitoring:
{
	Gosub, OnToggleMonitoring
}
return

OnExitManager:
{
	exitManagerApplication()
}
return

RemoveManagerAlwaysOnTopTimer:
{
	Gui, Manager:-AlwaysOnTop
}
return

MonitorIrfanViewTimer:
{
	monitorIrfanView()
}
return

ManagerGuiClose:
{
	if ( g_exit_requested )
	{
		ExitApp
	}

	saveSettings()
	Gui, Manager:Hide
}
return

ManagerGuiEscape:
{
	Gosub, ManagerGuiClose
}
return
