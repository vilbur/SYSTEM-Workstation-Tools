Gallery Slideshow Manager — HTML version 0.52

================================================



Files

-----

Gallery-Slideshow-Manager.hta

    HTML tile interface. Parent galleries are displayed as image cards using

    each parent folder's direct folder.jpg.



Gallery-Slideshow-Manager-Bridge.ahk

    AutoHotkey v1.1.36 native bridge. It controls IrfanView/VLC and provides

    Tab / Shift+Tab / Ctrl+Tab navigation while IrfanView or VLC is active.



Gallery-Slideshow-Manager.ico

    Shared app and tray icon.



How to start

------------

1. Keep all three files in the same directory.

2. Double-click Gallery-Slideshow-Manager.hta.

3. Browse to the galleries root.

4. Click a parent tile to display its gallery tiles.

5. Double-click a gallery tile to start it.



Expected structure

------------------

Root\A\Parent name\1 Gallery\*.jpg

Root\A\Parent name\2 Gallery\*.jpg

Root\A\Parent name\folder.jpg

Root\A\Parent name\1 video.mp4



Root\B\Another parent\...



Tile behavior

-------------

- Parent tiles use parent\folder.jpg.

- Clicking a parent opens gallery tiles.

- Gallery tiles use the alphabetically first direct image.

- Blue gallery border: images only.

- Green gallery border: paired MP4/WMV found.

- Right-click a parent tile to assign keywords.

- Keyword filters use OR matching.

- Random slideshow respects search and keyword filters.



Native controls

---------------

- Tab while IrfanView or VLC is active: next gallery.
- Shift+Tab while IrfanView or VLC is active: previous parent gallery.

- Ctrl+Tab while IrfanView or VLC is active: next parent.

- Escape while IrfanView is active: confirmation before bridge exit.

- IrfanView enters fullscreen after launch.

- VLC enters fullscreen, then focus returns to IrfanView.



Settings

--------

Gallery-Slideshow-Manager.ini

    Root path, Auto VLC, IrfanView path, VLC path, and HTML window placement.



<selected root>\gallery-keywords.ini

    Global keywords and per-parent assignments.



Testing

-------

Run:



AutoHotkey.exe "Gallery-Slideshow-Manager-Bridge.ahk" --self-test



The test checks:

- direct image scanning

- first-integer gallery/video pairing

- next-gallery navigation

- background prepared file lists



Notes

-----

This is a new HTML/HTA front end with an AHK bridge, not a normal browser page.

The native bridge remains necessary for unrestricted folder access, IrfanView,

VLC, and global keyboard navigation.





Version 0.02 fix

----------------

- Fixed AHK v1 error caused by using image_paths.Length() directly in IniWrite.

- Fixed CURRENT_PREFIX function scope for starting a gallery.

- Fixed Auto VLC function scope when launching a prepared gallery.





Version 0.03 fix

----------------

- Replaced blank IniWrite used to clear IrfanViewPid with IniDelete.

- Added safe handling for galleries without a paired video.

- Added safe handling for sessions with no current video.



Version 0.04
------------
- Added Gallery-Slideshow-Manager.cache for fast startup after the first scan.
- Refresh library performs a full disk rescan and replaces the cache.
- Parent and gallery thumbnails use centered background-cover rendering.
- Aspect ratio is preserved; the longer side is cropped.
- Gallery thumbnails prefer JPG, JPEG, PNG, GIF, and BMP.
- Galleries with other supported image formats remain available with a placeholder.
- Local image URLs now escape # and ? characters.


Version 0.06
------------
- Right-click in active IrfanView opens the current parent keyword assignment menu.
- Assigned keywords are checked and clicking a word toggles it.
- IrfanView changes refresh open HTML tile badges and the persistent cache.
- Added a keyword-filter preset dropdown.
- Selecting a preset replaces the active keyword-filter combination.
- The current combination automatically selects a matching saved preset.
- Save current filter is available only for an unmatched non-empty combination.
- Named filter presets are stored in Gallery-Slideshow-Manager.ini.


Version 0.07
------------
- The first user Enter press in active IrfanView closes the current slideshow.
- The automatic Enter used to enter fullscreen is protected and does not close it.
- The tray bridge exits only after the managed IrfanView process is actually closed.
- Gallery-to-gallery and parent-to-parent replacements are protected from auto-exit.
- Running-session INI values are cleared so the HTML RUNNING badge disappears.


Version 0.08
------------
- The HTA title bar displays Gallery Slideshow Manager 0.08.
- Shared data is stored in %TEMP%\Gallery-Slideshow-Manager\.
- Gallery-Slideshow-Manager.ini and Gallery-Slideshow-Manager.cache are shared across version folders.
- Command, session, PID, and prepared-list files use the same shared folder.
- On first launch, the newest local INI and cache from the current or sibling version folder are copied into shared storage.
- gallery-keywords.ini remains in the selected gallery root because those assignments belong to the library.


Version 0.09
------------
- VLC is moved to a monitor different from the monitor containing IrfanView before fullscreen.
- Monitor 2 is preferred when IrfanView is not already on monitor 2.
- With one monitor, the previous VLC placement fallback is retained.
- Escape closes the gallery-detail overlay first; Escape on the main view still asks to exit.
- Right-clicking a gallery thumbnail opens the keyword menu for its parent gallery.
- Parent-tile right-click keyword assignment remains available.


Version 0.10
------------
- Parent gallery details open only with the left mouse button.
- Right-click selects the parent and opens its keyword menu without opening details.
- Gallery-thumbnail right-click explicitly stops event bubbling.
- Added Gallery-Slideshow-Manager.exe as a native 64-bit Windows launcher.
- The launcher opens the adjacent HTA without a console window.
- The application icon is embedded directly in the launcher EXE.
- Gallery-Slideshow-Manager.ico now contains one exact 64x64 image.


Version 0.11
------------
- Added a persistent generated-thumbnail cache under %TEMP%\Gallery-Slideshow-Manager\thumbnails.
- The library cache now stores generated thumbnail paths and uses cache format version 2.
- Missing thumbnails are generated in one background batch after scanning or cache loading.
- JPEG, PNG, GIF, BMP, and TIFF are processed by Windows System.Drawing.
- IrfanView is used as fallback for WebP, HEIC, plugin formats, and files rejected by System.Drawing.
- Generated JPEG previews have a maximum dimension of 480 px and retain aspect ratio.
- CSS cover continues to crop the longer side without stretching.
- Safe hexadecimal thumbnail filenames avoid display failures caused by special source paths.


Version 0.12
------------
- Thumbnail backgrounds are now assigned only when tiles approach the visible viewport.
- Main-window scrolling, gallery-detail scrolling, and window resizing trigger thumbnail refresh.
- A 360 px preload margin loads thumbnails shortly before they become visible.
- Re-entering the viewport forces the local background to repaint in the HTA browser.
- Generated thumbnails are detected and replace temporary source-image previews without a full rescan.
- Parent letter badges are preserved while thumbnail backgrounds are refreshed.


Version 0.13
------------
- Fixed 'Could not create thumbnail queue: Invalid procedure call or argument'.
- The HTA no longer passes the entire queue through one large TextStream.Write call.
- Queue files are written line by line as UTF-16LE for full Unicode path support.
- PowerShell reads the queue using Unicode encoding.
- Large libraries are processed in batches of 250 thumbnails.
- Each completed batch automatically starts the next one.
- Status text reports completed, failed, and remaining thumbnail counts.


Version 0.14
------------
- Startup and Refresh library generate thumbnails only for the main parent-gallery list.
- Gallery-detail thumbnails are no longer queued for the whole library.
- Opening one parent detail queues thumbnails only for galleries inside that parent.
- Existing cached detail thumbnails are reused immediately.
- Main-list and detail thumbnail status messages are now identified separately.


Version 0.15
------------
- Cached parent galleries are checked for a newly created folder.jpg at startup.
- Replaced or modified folder.jpg files receive a new generated-thumbnail cache path automatically.
- Removed folder.jpg files clear the stale cached parent preview.
- All thumbnail backgrounds are aligned to the top; cropping occurs from the bottom first.
- Gallery cards in the detail modal have fixed 210 x 184 px dimensions.
- Detail cards and image panels no longer stretch to the modal height.


Version 0.16
------------
- Detects the monitor containing the Gallery Slideshow Manager UI.
- Landscape monitor: fits the UI to the complete monitor work-area height and centers it horizontally.
- Portrait monitor: fits the UI to the complete monitor work-area width and centers it vertically.
- The current window aspect ratio is preserved whenever possible.
- The work area excludes the Windows taskbar.
- Moving the UI to another monitor triggers automatic refitting.
- Rotating a monitor between landscape and portrait also triggers refitting.


Version 0.17
------------
- Fixed the AutoHotkey v1 syntax error at the monitor-fitting call.
- fitManagerWindowToMonitor() is now called on one line.
- Added a static check rejecting multiline AutoHotkey function calls.


Version 0.18
------------
- Fixed interference with restoring minimized windows in other applications.
- Monitor auto-fit runs only while the Gallery Manager is the active window.
- Auto-fit runs only when the manager is in the normal window state.
- Removed automatic WinRestore from the monitor-fitting code.
- Minimized and maximized manager windows are left untouched.
- Unrelated application windows are never restored, activated, resized, or moved by the fitting timer.


Version 0.19
------------
- The complete settings panel and action toolbar remain fixed at the top.
- Only the parent-gallery content list scrolls below the fixed controls.
- The scrolling content begins below the actual rendered controls height.
- Wrapped keyword filters automatically update the content offset.
- Window resizing recalculates the frozen controls height.
- The bottom status bar remains fixed and visible.


Version 0.20
------------
- Main parent galleries are grouped into collapsible first-letter rollouts.
- Only one expanded letter group renders thumbnail tiles at a time.
- Each rollout header shows its letter and matching parent count.
- Search and keyword filters rebuild the visible alphabet groups.
- Shift+Tab while IrfanView or VLC is active jumps to the previous parent gallery.
- Previous-parent navigation wraps from the first parent to the final parent.
- Previous, next-parent, and next-gallery destinations are prepared in background slots.


Version 0.21
------------
- Added a View selector to the fixed toolbar.
- Tile view shows every matching parent gallery in one flat thumbnail grid.
- By section shows collapsible first-letter rollouts from version 0.20.
- The selected display mode is stored in the shared INI under [Options] DisplayMode.
- Search, keyword filters, selection, right-click keywords, and lazy thumbnails work in both modes.


Version 0.22
------------
- Fixed recurring HTA script errors caused by temporary Windows file locks.
- Shared file reads retry ten times before using the last successful cached contents.
- Shared file writes retry and then continue through a deferred background write queue.
- Session polling no longer exposes OpenTextFile sharing violations to the HTA script engine.
- Command files remain synchronous so a command is never moved before its contents exist.
- Window position and size are saved with one INI write instead of four consecutive writes.
- A sharing-violation-only window.onerror handler prevents the legacy script-error popup as a final fallback.


Version 0.23
------------
- Added persistent parent-gallery ratings from zero through nine stars.
- Ctrl+0 through Ctrl+9 while IrfanView or VLC is active assigns the rating to the current parent.
- Ctrl+0 clears the saved rating and displays 0 stars.
- Ratings are stored in <gallery root>\gallery-ratings.ini.
- Parent tiles display a compact 0★ through 9★ badge in Tile view and By section view.
- RatingRevision updates an open manager immediately without rescanning the library.


Version 0.24
------------
- Ctrl+Tab now opens a non-activating three-second preview of the next parent gallery.
- The preview displays the next parent's folder.jpg and the first gallery name.
- If folder.jpg is missing or cannot be loaded, a blank canvas shows a No folder.jpg placeholder.
- Tab while previewing skips the candidate and previews the following parent; the timer restarts.
- Ctrl+Tab while previewing opens the offered parent immediately.
- If no key is pressed for three seconds, the offered parent opens automatically.
- The offered gallery is prepared in a hidden worker while its parent preview is visible.
- The preview uses AlwaysOnTop with NoActivate, so IrfanView or VLC retains keyboard focus.


Version 0.25
------------
- Added ten rating-filter star icons below the keyword filters.
- The icons represent exact ratings 0 through 9 from left to right.
- Clicking one star lights every star from the left through the selected value.
- The main list and Random slideshow then use only parent galleries with that exact rating.
- Clicking the selected rightmost star again clears the rating filter and restores all ratings.
- The selected rating filter is saved in the shared INI under [Options] RatingFilter.


Version 0.26
------------
- Escape during the three-second Ctrl+Tab parent preview cancels the preview.
- The preview timeout is stopped and the prepared candidate slot is removed.
- The current IrfanView or VLC slideshow continues unchanged.
- Escape outside parent-preview mode keeps its previous behavior.
- The preview footer now displays Esc: cancel.


Version 0.27
------------
- Keywords in the manager are grouped by formatting type.
- Group order: special prefix (#, $, @, !, etc.), UPPERCASE, Capital, lowercase, and Other.
- Special-prefix classification takes priority over capitalization, so #MAIN and @ALSO MAIN stay together.
- Replaced the small filter checkboxes with large toggle-style check buttons.
- Active keyword buttons use a large check mark and highlighted background.
- The HTML right-click parent keyword menu uses the same formatting groups and larger assignment buttons.
- The native Windows keyword menu shown inside IrfanView retains normal system-menu sizing.


Version 0.28
------------
- Single-clicking a rating star shows parent galleries rated from 0 through the clicked value.
- In cumulative mode, every star from 0 through the selected value is highlighted.
- Single-clicking 9 stars shows all possible ratings from 0 through 9.
- Double-clicking a rating star shows only parent galleries with that exact rating.
- In exact mode, only the double-clicked star is highlighted.
- A short click delay prevents double-click from first applying cumulative mode.
- RatingFilterMode and RatingFilter are both saved in the shared INI.


Version 0.29
------------
- Single-clicking a parent thumbnail tile opens its detail window.
- Double-clicking a parent thumbnail tile starts its first gallery directly.
- A short click delay prevents the detail window from opening during double-click.
- Right-click also cancels any pending single-click action.
- The detail window calculates its columns, rows, width, and height from the gallery count.
- Small parents use a compact detail window; larger parents grow until the manager-window limit.
- Oversized gallery collections scroll inside the detail window instead of enlarging beyond the viewport.
- Resizing the manager recalculates an open detail window.


Version 0.30
------------
- Special-prefix keywords are separated by their exact first character.
- #, @, $, !, and other symbol prefixes each receive their own keyword group.
- Symbol groups appear before UPPERCASE, Capital, lowercase, and Other.
- The Ctrl+Tab preview places the next gallery name above the folder image.
- The preview shows the parent rating between the gallery name and image.
- Rating display uses nine filled/empty star positions and a numeric value out of 9.


Version 0.31
------------
- Removed visible keyword group labels and counts; keyword buttons remain separated into grouped rows.
- Preserved keyword order from gallery-keywords.ini within each formatting group.
- Newly added keywords are appended instead of alphabetically re-sorted.
- HTML and IrfanView right-click keyword menus preserve the configured keyword order.
- Special-character group order follows its first occurrence in the keyword list.
- Ctrl+Tab preview now displays only the assigned number of filled stars.
- Removed empty stars and the numeric x/9 suffix from the preview.
- Zero-rated parents display no star row, giving the image additional space.


Version 0.32
------------
- Fixed mixed keyword ordering in both right-click menus.
- Pattern order is: special-prefix UPPERCASE, special-prefix Capital, special-prefix lowercase, then plain UPPERCASE, Capital, lowercase.
- Mixed/Other patterns remain last in their special or plain section.
- Keywords are still separated by their exact first special character.
- Original source order is preserved inside each resulting group.
- Native IrfanView menu separators match the HTML right-click grouping.


Version 0.33
------------
- Added Start random slideshow to the parent detail window.
- Single-clicking a gallery card selects and highlights it.
- The new button is disabled until a gallery is selected.
- Pressing the button starts the slideshow from the selected gallery.
- Double-clicking a gallery still starts it immediately.
- Opening or closing details clears the previous gallery selection.
- The detail header can wrap controls in compact detail windows.


Version 0.34
------------
- Next-gallery and next/previous-parent navigation respects active keyword, rating, and search filters.
- The HTA writes all currently allowed gallery paths to a shared filtered-navigation queue.
- Tab stays within the current parent when allowed; a filtered-out current parent advances to the first allowed gallery.
- Ctrl+Tab preview and Shift+Tab select only allowed parent galleries.
- Prepared slots are checked against the current filtered destination before launch, preventing stale filtered-out jumps.
- Filter changes rebuild prepared navigation and cancel an obsolete preview.
- Moved RANDOM SLIDESHOW to the center of the toolbar.
- Added a matching large SLIDESHOW button beside it.
- SLIDESHOW starts the selected gallery or selected parent, then falls back to the first gallery matching current filters.


Version 0.35
------------
- Removed the visible 0-star icon from the rating filter; the row now contains 1 through 9 stars.
- Unrated-only filtering is represented by all nine stars being faded.
- Single-clicking an already active 1-star filter switches to non-starred items only.
- Single-clicking 1-star again from non-starred mode restores cumulative non-starred through 1-star filtering.
- Other single-clicks continue to show non-starred items through the selected rating.
- Double-clicking a visible star still shows only that exact 1-through-9 rating.
- The non-starred-only state remains persisted as RatingFilterMode=exact and RatingFilter=0.


Version 0.36
------------
- RANDOM SLIDESHOW now creates and persists a real shuffled navigation queue.
- Matching parent galleries are shuffled.
- Gallery order inside every parent is shuffled independently.
- If a random shuffle accidentally equals the original order, the list is rotated so the result visibly differs.
- Tab follows the shuffled gallery order inside the active parent.
- Ctrl+Tab and Shift+Tab follow the shuffled parent order derived from the queue.
- Prepared next-gallery and next-parent slots use the same shuffled queue.
- The detail-window random button keeps the selected parent and gallery first, then shuffles all remaining matching parents and galleries.
- Direct gallery starts, double-click, and the normal SLIDESHOW button restore normal sorted navigation.
- Filter changes rebuild the random queue from only the newly matching parents and galleries while keeping the current gallery first when possible.


Version 0.37
------------
- Paired VLC videos are muted with VLC's M shortcut after entering fullscreen.
- The mute lasts 10 seconds, then M is sent again to restore sound.
- M is sent directly to the exact VLC window without activating it or stealing focus from IrfanView.
- The automatic unmute validates the original VLC PID, so an old timer cannot toggle a newer VLC instance.
- Starting another paired video restores any previous temporary mute before launching the new VLC instance.
- Exiting the bridge during the 10-second interval restores VLC sound first.


Version 0.38
------------
- Fixed the AutoHotkey v1 syntax error reported at line 2294.
- Replaced all standalone multiline `if (` expressions introduced by the VLC mute feature with AHK v1-safe single-line conditions.
- Added validation that rejects standalone `if (`, `while (`, and similar multiline control-expression openings.
- VLC still mutes after startup and automatically restores sound after 10 seconds.


Version 0.39
------------
- Fixed the case where the bridge started only in the system tray and no manager UI appeared.
- Directly launching Gallery-Slideshow-Manager-Bridge.ahk now opens the manager UI.
- The HTA starts its background bridge with the new --resident argument, preventing a duplicate manager window.
- When a bridge is already resident, launching the AHK file activates the existing manager or opens it if absent.
- launchHtmlManager now activates an existing manager window before creating another one.
- Preserved the AHK v1-safe VLC mute fix and 10-second automatic unmute behavior.


Version 0.40
------------
- Changed slideshow startup order to: launch IrfanView, wait for its window, then execute slideshow-assistant.ahk.
- slideshow-assistant is launched before IrfanView placement restoration, activation, and fullscreen Enter.
- The exact adjacent slideshow-assistant.ahk filename is preferred.
- If the exact file is absent, the newest modified adjacent slideshow-assistant_*.ahk file is used.
- A missing or failed assistant launch shows a tray notification but does not prevent the IrfanView slideshow from starting.


Version 0.41
------------
- Main RANDOM SLIDESHOW now starts on the currently selected gallery when that gallery matches the active filters.
- The selected parent stays first, the selected gallery stays first inside it, and all following parents and galleries are shuffled.
- VLC now waits briefly for its new window to initialise before placement.
- VLC placement is retried and verified by the window centre up to five times before fullscreen.
- Fullscreen placement is verified; if VLC jumps to another display, fullscreen is exited, the window is moved again, and fullscreen is retried.
- Monitor 2 remains preferred unless IrfanView is already on monitor 2; otherwise another monitor different from IrfanView is selected.
- The bridge exit confirmation is now always on top, so it remains visible over fullscreen IrfanView.


Version 0.42
------------
- Fixed RANDOM SLIDESHOW next-parent order reverting to alphabetical after the first gallery.
- The shared navigation INI now stores ParentCount and ParentItem1..N in the exact shuffled parent order.
- The bridge uses ParentItem order for Ctrl+Tab, Shift+Tab, parent preview, and prepared next-parent slots.
- Before launching slideshow-assistant, the bridge creates a temporary manager-aware copy when the assistant exposes getOrderedParentGalleryPaths().
- In random mode, the manager-aware assistant reads ParentItem1..N instead of rebuilding an alphabetical A-Z list.
- In normal slideshow mode, slideshow-assistant retains its original alphabetical parent behaviour.
- The original slideshow-assistant file is never modified.
- The temporary assistant copy is launched elevated with the exact IrfanView --bind-pid value and deleted when the bridge exits.


Version 0.43
------------
- Gallery image placeholders now contain only the gallery name.
- The empty next-parent preview image area also contains only the next gallery name.
- Increased the next-parent preview/change timeout from 3 seconds to 4 seconds.
- Replaced the first right-click menu item with the parent-gallery rating in both the HTML menu and the native IrfanView menu.
- Right-click menu keywords now use the same priority convention as the UI: special-prefix UPPERCASE, Capital, lowercase, Other, then plain UPPERCASE, Capital, lowercase, Other.
- Keywords are sorted case-insensitively inside each priority/exact-prefix group for deterministic matching UI and right-click menu order.
- Replaced the native VLC checkbox with a dark pressed-state checkbutton.


Version 0.44
------------
- Enforced one manager HTA window across EXE, HTA, and AHK launch paths.
- New manager windows claim a shared single-instance slot; duplicate windows are closed and the survivor is activated.
- Gallery-detail Random Slideshow now works without selecting a gallery.
- Without a selection, a random gallery from the open parent is kept first in the shuffled queue.
- SLIDESHOW and RANDOM SLIDESHOW now use the VLC dark checkbutton style.
- The executed slideshow type remains visibly active.
- Replaced the display dropdown with a left-aligned TILES checkbutton.
- Toolbar alignment is explicit: left controls, centred slideshow buttons, right folder/refresh/exit buttons.


Version 0.45
------------
- Rebuilt the toolbar as a strict three-column grid.
- Left: TILES and VLC; centre: SLIDESHOW and RANDOM SLIDESHOW; right: Open parent folder, Refresh library, and Exit.
- IrfanView is now closed immediately when a gallery switch starts, before list preparation or other slower work.
- Prepared next-gallery and next-parent switches also close the current IrfanView as soon as the request is accepted.
- The graceful IrfanView close wait was reduced from two seconds to one second before force-closing the process.
- Confirmed exit closes IrfanView before the remaining bridge cleanup begins.
- The manager automatically resolves the currently running gallery, opens its parent detail window, selects its thumbnail, focuses it, and scrolls it into view.
- Running-gallery focus occurs immediately for manager-started slideshows, on every session-reported gallery change, and once during manager startup.


Version 0.46
------------
- Parent thumbnails now use: left-click select, double-click open details, right-click open the rating/keyword menu.
- Running slideshow changes select, focus, and scroll to the parent thumbnail in the main UI without opening gallery details.
- Random mode chooses a fresh random eligible gallery for every next-gallery destination.
- The current gallery is excluded from every random choice.
- When another choice exists, the gallery immediately after the current gallery in the normal UI order is excluded too.
- Random next-parent and Shift+Tab navigation choose a random different parent and a random gallery inside it.
- Prepared random destinations are preserved so key presses launch the random item that was actually prepared.
- The manager prefers the real patchable slideshow-assistant script instead of an unversioned wrapper.
- Parent preview candidates are reshuffled on every preview activation.
- The first parent preview cannot be the alphabetically next gallery when another option exists.
- The manager-aware assistant preview timeout remains four seconds.


Version 0.47
------------
- Random starts now send an explicit startrandom command to the resident bridge.
- The bridge owns random/normal state; queue rewrites can no longer silently return random mode to ordered navigation.
- Every transition draws from the complete filtered gallery pool.
- The current gallery is excluded.
- The alphabetically next gallery is excluded whenever another gallery is available.
- The last twelve actually opened random galleries are avoided whenever possible.
- Random parent navigation excludes the current parent and the alphabetically next parent whenever another parent exists.
- The resident random generator is seeded explicitly.
- The manager-aware slideshow assistant has its Ctrl+Tab navigation block removed.
- Tab, Ctrl+Tab and Shift+Tab navigation are now controlled only by Gallery-Slideshow-Manager-Bridge.ahk, preventing the assistant's alphabetical parent list from overriding random mode.


Version 0.48
------------
- Added a persistent UNIQUE checkbutton to the random-slideshow options.
- UNIQUE prevents an eligible gallery from being shown twice until every gallery in the current filtered pool has been processed.
- After the complete pool is exhausted, a new cycle starts while keeping the current gallery marked as processed, preventing an immediate repeat.
- Unique progress is stored in the session INI and survives a resident bridge restart.
- Enabling or disabling UNIQUE during an active random slideshow immediately rebuilds the prepared navigation slots.
- Filter changes are handled dynamically: newly eligible galleries are unseen, and a cycle resets only when the currently eligible pool is exhausted.
- All toolbar controls now share the same 42-pixel height, inline-flex centring, box sizing, margin and line height.
- TILES, VLC and UNIQUE remain in the left options group; slideshow controls remain centred; folder, refresh and exit controls remain right-aligned.


Version 0.50
------------
- Rebuilt directly from the verified uploaded 0.48 ZIP; UNIQUE and toolbar alignment are preserved.
- Fixed stale-version startup: the newly launched HTA now always wins and closes every older manager window.
- The newly launched bridge uses --takeover, terminates the older resident bridge, waits for it to exit, and then becomes the only resident bridge.
- The status bar always displays the actual running version.
- Random slideshow starts on the selected child gallery when selected, otherwise on the first gallery of the selected parent tile.
- The next destination is selected parent-first: choose one eligible parent uniformly at random, then choose an eligible child gallery inside it.
- The parent pool comes only from the filtered queue, so keyword, rating, and search filters are respected.
- The current parent is excluded whenever another eligible parent exists.
- The alphabetically next parent is excluded whenever another random parent exists.
- UNIQUE mode chooses only unseen child galleries and resets only after the full filtered gallery pool is exhausted.
- Tab, Ctrl+Tab, Shift+Tab, and prepared transitions all use the same single random-next-parent destination in random mode.


Version 0.51
------------
- Replaced the stale compiled AutoHotkey executable with a new minimal launcher that always opens the adjacent packaged HTA.
- The executable no longer contains an old embedded bridge, so newer HTA/AHK changes cannot remain hidden behind the 0.46 executable.
- The status bar permanently identifies the loaded package as v0.51.
- Preserved the UNIQUE button and strict left/centre/right toolbar row.
- Every option, slideshow, folder, refresh, and exit control uses the same 42-pixel height and vertical centring.
- Random slideshow starts from the selected gallery.
- Each next transition chooses the parent first from the filtered keyword/rating/search pool, uniformly at random, then chooses one child gallery inside that parent.
- The current parent is excluded whenever another eligible parent exists.
- The alphabetically next parent is excluded whenever another random choice exists.
- UNIQUE prevents child-gallery repeats until every eligible child gallery has been processed.
- UNIQUE also prefers every eligible parent once per parent round before reusing a parent, while child-gallery progress continues across rounds.
- UNIQUE progress is persisted in the session and adapts to filter changes.


Version 0.52
------------
- Fixed the AutoHotkey v1 parser error at the parent-first random-selection block.
- Replaced the multiline object literal with explicit object creation and property assignment.
- Replaced the multiline ternary assignment with one valid AutoHotkey v1 expression line.
- Added stricter package validation that rejects multiline object literals and split ternary operators before delivery.
