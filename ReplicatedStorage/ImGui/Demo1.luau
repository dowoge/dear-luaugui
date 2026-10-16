local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local Demo = ImGui._Demo
local _

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local ImTruncToInt = Base.ImTruncToInt
local IM_COL32 = Base.IM_COL32
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiCol = Enums.ImGuiCol
local ImGuiCond = Enums.ImGuiCond
local ImGuiDir = Enums.ImGuiDir
local ImGuiDataType = Enums.ImGuiDataType
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiSliderFlags = Enums.ImGuiSliderFlags
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiComboFlags = Enums.ImGuiComboFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiDragDropFlags = Enums.ImGuiDragDropFlags
local ImGuiMouseCursor = Enums.ImGuiMouseCursor

function Demo.HelpMarker(desc)
	ImGui.TextDisabled("(?)")
	if ImGui.BeginItemTooltip() then
		ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
		ImGui.TextUnformatted(desc)
		ImGui.PopTextWrapPos()
		ImGui.EndTooltip()
	end
end

local S_ShowDemoWindow = {
	demo_data = {
		ShowMainMenuBar = false,
		ShowAppAssetsBrowser = false,
		ShowAppConsole = false,
		ShowAppCustomRendering = false,
		ShowAppDocuments = false,
		ShowAppImageViewer = false,
		ShowAppLog = false,
		ShowAppLayout = false,
		ShowAppPropertyEditor = false,
		ShowAppSimpleOverlay = false,
		ShowAppAutoResize = false,
		ShowAppConstrainedResize = false,
		ShowAppFullscreen = false,
		ShowAppLongText = false,
		ShowAppWindowTitles = false,
		ShowMetrics = false,
		ShowDebugLog = false,
		ShowIDStackTool = false,
		ShowStyleEditor = false,
		ShowAbout = false,
		DisableSections = false,
		LiveEditOverride = false,
		LiveEditFlags = ImGuiItemFlags.LiveEditOnInputText,
		DemoTree = nil,
	},
	no_titlebar = false,
	no_scrollbar = false,
	no_menu = false,
	no_move = false,
	no_resize = false,
	no_collapse = false,
	no_close = false,
	no_nav = false,
	no_background = false,
	no_bring_to_front = false,
	unsaved_document = false,
}

function ImGui.ShowDemoWindow(p_open)
	assert(ImGui.GetCurrentContext() ~= nil, "Missing Dear ImGui context. Refer to examples app!")

	local S = S_ShowDemoWindow
	local demo_data = S.demo_data

	if demo_data.ShowMainMenuBar then Demo.ShowExampleAppMainMenuBar() end
	if demo_data.ShowAppDocuments then demo_data.ShowAppDocuments = Demo.ShowExampleAppDocuments(demo_data.ShowAppDocuments) end
	if demo_data.ShowAppAssetsBrowser then demo_data.ShowAppAssetsBrowser = Demo.ShowExampleAppAssetsBrowser(demo_data.ShowAppAssetsBrowser) end
	if demo_data.ShowAppConsole then demo_data.ShowAppConsole = Demo.ShowExampleAppConsole(demo_data.ShowAppConsole) end
	if demo_data.ShowAppCustomRendering then demo_data.ShowAppCustomRendering = Demo.ShowExampleAppCustomRendering(demo_data.ShowAppCustomRendering) end
	if demo_data.ShowAppImageViewer then demo_data.ShowAppImageViewer = Demo.ShowExampleAppImageViewer(demo_data.ShowAppImageViewer) end
	if demo_data.ShowAppLog then demo_data.ShowAppLog = Demo.ShowExampleAppLog(demo_data.ShowAppLog) end
	if demo_data.ShowAppLayout then demo_data.ShowAppLayout = Demo.ShowExampleAppLayout(demo_data.ShowAppLayout) end
	if demo_data.ShowAppPropertyEditor then demo_data.ShowAppPropertyEditor = Demo.ShowExampleAppPropertyEditor(demo_data.ShowAppPropertyEditor, demo_data) end
	if demo_data.ShowAppSimpleOverlay then demo_data.ShowAppSimpleOverlay = Demo.ShowExampleAppSimpleOverlay(demo_data.ShowAppSimpleOverlay) end
	if demo_data.ShowAppAutoResize then demo_data.ShowAppAutoResize = Demo.ShowExampleAppAutoResize(demo_data.ShowAppAutoResize) end
	if demo_data.ShowAppConstrainedResize then demo_data.ShowAppConstrainedResize = Demo.ShowExampleAppConstrainedResize(demo_data.ShowAppConstrainedResize) end
	if demo_data.ShowAppFullscreen then demo_data.ShowAppFullscreen = Demo.ShowExampleAppFullscreen(demo_data.ShowAppFullscreen) end
	if demo_data.ShowAppLongText then demo_data.ShowAppLongText = Demo.ShowExampleAppLongText(demo_data.ShowAppLongText) end
	if demo_data.ShowAppWindowTitles then demo_data.ShowAppWindowTitles = Demo.ShowExampleAppWindowTitles(demo_data.ShowAppWindowTitles) end

	if demo_data.ShowMetrics then demo_data.ShowMetrics = ImGui.ShowMetricsWindow(demo_data.ShowMetrics) end
	if demo_data.ShowDebugLog then demo_data.ShowDebugLog = ImGui.ShowDebugLogWindow(demo_data.ShowDebugLog) end
	if demo_data.ShowIDStackTool then demo_data.ShowIDStackTool = ImGui.ShowIDStackToolWindow(demo_data.ShowIDStackTool) end
	if demo_data.ShowAbout then demo_data.ShowAbout = ImGui.ShowAboutWindow(demo_data.ShowAbout) end
	if demo_data.ShowStyleEditor then
		_, demo_data.ShowStyleEditor = ImGui.Begin("Dear ImGui Style Editor", demo_data.ShowStyleEditor)
		ImGui.ShowStyleEditor()
		ImGui.End()
	end

	local window_flags = 0
	if S.no_titlebar then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoTitleBar) end
	if S.no_scrollbar then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollbar) end
	if not S.no_menu then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.MenuBar) end
	if S.no_move then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoMove) end
	if S.no_resize then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoResize) end
	if S.no_collapse then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoCollapse) end
	if S.no_nav then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoNav) end
	if S.no_background then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBackground) end
	if S.no_bring_to_front then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBringToFrontOnFocus) end
	if S.unsaved_document then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.UnsavedDocument) end

	local begin_open = p_open
	if S.no_close then begin_open = nil end

	local main_viewport = ImGui.GetMainViewport()
	ImGui.SetNextWindowPos(ImVec2(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20), ImGuiCond.FirstUseEver)
	ImGui.SetNextWindowSize(ImVec2(550, 680), ImGuiCond.FirstUseEver)

	local visible
	visible, begin_open = ImGui.Begin("Dear ImGui Demo", begin_open, window_flags)
	if not S.no_close then p_open = begin_open end
	if not visible then
		ImGui.End()
		return p_open
	end

	local label_width_base = ImGui.GetFontSize() * 12
	local label_width_max = ImGui.GetContentRegionAvail().x * 0.40
	local label_width = math.min(label_width_base, label_width_max)
	ImGui.PushItemWidth(-label_width)

	Demo.DemoWindowMenuBar(demo_data)

	ImGui.Text("dear imgui says hello! (%s) (%d)", Base.IMGUI_VERSION, Base.IMGUI_VERSION_NUM)
	ImGui.Spacing()

	if ImGui.CollapsingHeader("Help") then
		ImGui.SeparatorText("ABOUT THIS DEMO:")
		ImGui.BulletText("Sections below are demonstrating many aspects of the library.")
		ImGui.BulletText("The \"Examples\" menu above leads to more demo contents.")
		ImGui.BulletText("The \"Tools\" menu above gives access to: About Box, Style Editor,\nand Metrics/Debugger (general purpose Dear ImGui debugging tool).")
		ImGui.BulletText("Web demo (w/ source code browser): ")
		ImGui.SameLine(0, 0)
		ImGui.TextLinkOpenURL("https://pthom.github.io/imgui_explorer")

		ImGui.SeparatorText("PROGRAMMER GUIDE:")
		ImGui.BulletText("See the ShowDemoWindow() code in imgui_demo.cpp. <- you are here!")
		ImGui.BulletText("See comments in imgui.cpp.")
		ImGui.BulletText("See example applications in the examples/ folder.")
		ImGui.BulletText("Read the FAQ at ")
		ImGui.SameLine(0, 0)
		ImGui.TextLinkOpenURL("https://www.dearimgui.com/faq/")
		ImGui.BulletText("Set 'io.ConfigFlags |= NavEnableKeyboard' for keyboard controls.")
		ImGui.BulletText("Set 'io.ConfigFlags |= NavEnableGamepad' for gamepad controls.")

		ImGui.SeparatorText("USER GUIDE:")
		ImGui.ShowUserGuide()
	end

	if ImGui.CollapsingHeader("Configuration") then
		local io = ImGui.GetIO()

		if ImGui.TreeNode("Configuration##2") then
			ImGui.SeparatorText("General")
			_, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NavEnableKeyboard", io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard)
			ImGui.SameLine(); Demo.HelpMarker("Enable keyboard controls.")
			_, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NavEnableGamepad", io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad)
			ImGui.SameLine(); Demo.HelpMarker("Enable gamepad controls. Require backend to set io.BackendFlags |= ImGuiBackendFlags_HasGamepad.\n\nRead instructions in imgui.cpp for details.")
			_, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NoMouse", io.ConfigFlags, ImGuiConfigFlags.NoMouse)
			ImGui.SameLine(); Demo.HelpMarker("Instruct dear imgui to disable mouse inputs and interactions.")

			if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoMouse) then
				if math.fmod(ImGui.GetTime(), 0.40) < 0.20 then
					ImGui.SameLine()
					ImGui.Text("<<PRESS SPACE TO DISABLE>>")
				end
				if ImGui.IsKeyPressed(ImGuiKey.Space) or bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) then
					io.ConfigFlags = bit32.band(io.ConfigFlags, bit32.bnot(ImGuiConfigFlags.NoMouse))
				end
			end

			_, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NoMouseCursorChange", io.ConfigFlags, ImGuiConfigFlags.NoMouseCursorChange)
			ImGui.SameLine(); Demo.HelpMarker("Instruct backend to not alter mouse cursor shape and visibility.")
			_, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NoKeyboard", io.ConfigFlags, ImGuiConfigFlags.NoKeyboard)
			ImGui.SameLine(); Demo.HelpMarker("Instruct dear imgui to disable keyboard inputs and interactions.")

			_, io.ConfigInputTrickleEventQueue = ImGui.Checkbox("io.ConfigInputTrickleEventQueue", io.ConfigInputTrickleEventQueue)
			ImGui.SameLine(); Demo.HelpMarker("Enable input queue trickling: some types of events submitted during the same frame (e.g. button down + up) will be spread over multiple frames, improving interactions with low framerates.")
			_, io.MouseDrawCursor = ImGui.Checkbox("io.MouseDrawCursor", io.MouseDrawCursor)
			ImGui.SameLine(); Demo.HelpMarker("Instruct Dear ImGui to render a mouse cursor itself. Note that a mouse cursor rendered via your application GPU rendering path will feel more laggy than hardware cursor, but will be more in sync with your other visuals.\n\nSome desktop applications may use both kinds of cursors (e.g. enable software cursor only when resizing/dragging something).")

			ImGui.SeparatorText("Keyboard/Gamepad Navigation")
			_, io.ConfigNavSwapGamepadButtons = ImGui.Checkbox("io.ConfigNavSwapGamepadButtons", io.ConfigNavSwapGamepadButtons)
			_, io.ConfigNavMoveSetMousePos = ImGui.Checkbox("io.ConfigNavMoveSetMousePos", io.ConfigNavMoveSetMousePos)
			ImGui.SameLine(); Demo.HelpMarker("Directional/tabbing navigation teleports the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is difficult")
			_, io.ConfigNavCaptureKeyboard = ImGui.Checkbox("io.ConfigNavCaptureKeyboard", io.ConfigNavCaptureKeyboard)
			_, io.ConfigNavEscapeClearFocusItem = ImGui.Checkbox("io.ConfigNavEscapeClearFocusItem", io.ConfigNavEscapeClearFocusItem)
			ImGui.SameLine(); Demo.HelpMarker("Pressing Escape clears focused item.")
			_, io.ConfigNavEscapeClearFocusWindow = ImGui.Checkbox("io.ConfigNavEscapeClearFocusWindow", io.ConfigNavEscapeClearFocusWindow)
			ImGui.SameLine(); Demo.HelpMarker("Pressing Escape clears focused window.")
			_, io.ConfigNavCursorVisibleAuto = ImGui.Checkbox("io.ConfigNavCursorVisibleAuto", io.ConfigNavCursorVisibleAuto)
			ImGui.SameLine(); Demo.HelpMarker("Using directional navigation key makes the cursor visible. Mouse click hides the cursor.")
			_, io.ConfigNavCursorVisibleAlways = ImGui.Checkbox("io.ConfigNavCursorVisibleAlways", io.ConfigNavCursorVisibleAlways)
			ImGui.SameLine(); Demo.HelpMarker("Navigation cursor is always visible.")

			ImGui.SeparatorText("Windows")
			_, io.ConfigWindowsResizeFromEdges = ImGui.Checkbox("io.ConfigWindowsResizeFromEdges", io.ConfigWindowsResizeFromEdges)
			ImGui.SameLine(); Demo.HelpMarker("Enable resizing of windows from their edges and from the lower-left corner.\nThis requires ImGuiBackendFlags_HasMouseCursors for better mouse cursor feedback.")
			_, io.ConfigWindowsMoveFromTitleBarOnly = ImGui.Checkbox("io.ConfigWindowsMoveFromTitleBarOnly", io.ConfigWindowsMoveFromTitleBarOnly)
			_, io.ConfigWindowsCopyContentsWithCtrlC = ImGui.Checkbox("io.ConfigWindowsCopyContentsWithCtrlC", io.ConfigWindowsCopyContentsWithCtrlC)
			ImGui.SameLine(); Demo.HelpMarker("*EXPERIMENTAL* Ctrl+C copy the contents of focused window into the clipboard.\n\nExperimental because:\n- (1) has known issues with nested Begin/End pairs.\n- (2) text output quality varies.\n- (3) text output is in submission order rather than spatial order.")
			_, io.ConfigScrollbarScrollByPage = ImGui.Checkbox("io.ConfigScrollbarScrollByPage", io.ConfigScrollbarScrollByPage)
			ImGui.SameLine(); Demo.HelpMarker("Enable scrolling page by page when clicking outside the scrollbar grab.\nWhen disabled, always scroll to clicked location.\nWhen enabled, Shift+Click scrolls to clicked location.")

			ImGui.SeparatorText("Widgets")
			_, io.ConfigInputTextCursorBlink = ImGui.Checkbox("io.ConfigInputTextCursorBlink", io.ConfigInputTextCursorBlink)
			ImGui.SameLine(); Demo.HelpMarker("Enable blinking cursor (optional as some users consider it to be distracting).")
			_, io.ConfigInputTextEnterKeepActive = ImGui.Checkbox("io.ConfigInputTextEnterKeepActive", io.ConfigInputTextEnterKeepActive)
			ImGui.SameLine(); Demo.HelpMarker("Pressing Enter will reactivate item and select all text (single-line only).")
			_, io.ConfigDragClickToInputText = ImGui.Checkbox("io.ConfigDragClickToInputText", io.ConfigDragClickToInputText)
			ImGui.SameLine(); Demo.HelpMarker("Enable turning DragXXX widgets into text input with a simple mouse click-release (without moving).")
			_, io.ConfigMacOSXBehaviors = ImGui.Checkbox("io.ConfigMacOSXBehaviors", io.ConfigMacOSXBehaviors)
			ImGui.SameLine(); Demo.HelpMarker("Swap Cmd<>Ctrl keys, enable various MacOS style behaviors.")
			ImGui.Text("Also see Style->Rendering for rendering options.")

			ImGui.SeparatorText("Settings")
			_, io.ConfigIniSettingsSaveLastUsedDate = ImGui.Checkbox("io.ConfigIniSettingsSaveLastUsedDate", io.ConfigIniSettingsSaveLastUsedDate)

			ImGui.SeparatorText("Error Handling")

			_, io.ConfigErrorRecovery = ImGui.Checkbox("io.ConfigErrorRecovery", io.ConfigErrorRecovery)
			ImGui.SameLine(); Demo.HelpMarker(
				"Options to configure how we handle recoverable errors.\n" ..
				"- Error recovery is not perfect nor guaranteed! It is a feature to ease development.\n" ..
				"- You not are not supposed to rely on it in the course of a normal application run.\n" ..
				"- Possible usage: facilitate recovery from errors triggered from a scripting language or after specific exceptions handlers.\n" ..
				"- Always ensure that on programmers seat you have at minimum Asserts or Tooltips enabled when making direct imgui API call! " ..
				"Otherwise it would severely hinder your ability to catch and correct mistakes!")
			_, io.ConfigErrorRecoveryEnableAssert = ImGui.Checkbox("io.ConfigErrorRecoveryEnableAssert", io.ConfigErrorRecoveryEnableAssert)
			_, io.ConfigErrorRecoveryEnableDebugLog = ImGui.Checkbox("io.ConfigErrorRecoveryEnableDebugLog", io.ConfigErrorRecoveryEnableDebugLog)
			_, io.ConfigErrorRecoveryEnableTooltip = ImGui.Checkbox("io.ConfigErrorRecoveryEnableTooltip", io.ConfigErrorRecoveryEnableTooltip)
			if not io.ConfigErrorRecoveryEnableAssert and not io.ConfigErrorRecoveryEnableDebugLog and not io.ConfigErrorRecoveryEnableTooltip then
				io.ConfigErrorRecoveryEnableAssert = true
				io.ConfigErrorRecoveryEnableDebugLog = true
				io.ConfigErrorRecoveryEnableTooltip = true
			end

			ImGui.SeparatorText("Debug")
			_, io.ConfigDebugIsDebuggerPresent = ImGui.Checkbox("io.ConfigDebugIsDebuggerPresent", io.ConfigDebugIsDebuggerPresent)
			ImGui.SameLine(); Demo.HelpMarker("Enable various tools calling IM_DEBUG_BREAK().\n\nRequires a debugger being attached, otherwise IM_DEBUG_BREAK() options will appear to crash your application.")
			_, io.ConfigDebugHighlightIdConflicts = ImGui.Checkbox("io.ConfigDebugHighlightIdConflicts", io.ConfigDebugHighlightIdConflicts)
			ImGui.SameLine(); Demo.HelpMarker("Highlight and show an error message when multiple items have conflicting identifiers.")
			ImGui.BeginDisabled()
			_, io.ConfigDebugBeginReturnValueOnce = ImGui.Checkbox("io.ConfigDebugBeginReturnValueOnce", io.ConfigDebugBeginReturnValueOnce)
			ImGui.EndDisabled()
			ImGui.SameLine(); Demo.HelpMarker("First calls to Begin()/BeginChild() will return false.\n\nTHIS OPTION IS DISABLED because it needs to be set at application boot-time to make sense. Showing the disabled option is a way to make this feature easier to discover.")
			_, io.ConfigDebugBeginReturnValueLoop = ImGui.Checkbox("io.ConfigDebugBeginReturnValueLoop", io.ConfigDebugBeginReturnValueLoop)
			ImGui.SameLine(); Demo.HelpMarker("Some calls to Begin()/BeginChild() will return false.\n\nWill cycle through window depths then repeat. Windows should be flickering while running.")
			_, io.ConfigDebugIgnoreFocusLoss = ImGui.Checkbox("io.ConfigDebugIgnoreFocusLoss", io.ConfigDebugIgnoreFocusLoss)
			ImGui.SameLine(); Demo.HelpMarker("Option to deactivate io.AddFocusEvent(false) handling. May facilitate interactions with a debugger when focus loss leads to clearing inputs data.")
			_, io.ConfigDebugDrawListDefaultsToStrokeLegacy = ImGui.Checkbox("io.ConfigDebugDrawListDefaultsToStrokeLegacy", io.ConfigDebugDrawListDefaultsToStrokeLegacy)
			ImGui.SameLine(); Demo.HelpMarker("Option to default all ImDrawList to ImDrawFlags_StrokeLegacy mode, mimicking pre-1.93.0 rendering.")
			_, io.ConfigDebugIniSettings = ImGui.Checkbox("io.ConfigDebugIniSettings", io.ConfigDebugIniSettings)
			ImGui.SameLine(); Demo.HelpMarker("Option to save .ini data with extra comments (particularly helpful for Docking, but makes saving slower).")

			ImGui.TreePop()
			ImGui.Spacing()
		end

		if ImGui.TreeNode("Backend Flags") then
			Demo.HelpMarker(
				"Those flags are set by the backends (imgui_impl_xxx files) to specify their capabilities.\n" ..
				"Here we expose them as read-only fields to avoid breaking interactions with your backend.")

			ImGui.BeginDisabled()
			_, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasGamepad", io.BackendFlags, ImGuiBackendFlags.HasGamepad)
			_, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseCursors", io.BackendFlags, ImGuiBackendFlags.HasMouseCursors)
			_, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasSetMousePos", io.BackendFlags, ImGuiBackendFlags.HasSetMousePos)
			_, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasVtxOffset", io.BackendFlags, ImGuiBackendFlags.RendererHasVtxOffset)
			_, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasTextures", io.BackendFlags, ImGuiBackendFlags.RendererHasTextures)
			ImGui.EndDisabled()

			ImGui.TreePop()
			ImGui.Spacing()
		end

		if ImGui.TreeNode("Style, Fonts") then
			_, demo_data.ShowStyleEditor = ImGui.Checkbox("Style Editor", demo_data.ShowStyleEditor)
			ImGui.SameLine()
			Demo.HelpMarker("The same contents can be accessed in 'Tools->Style Editor' or by calling the ShowStyleEditor() function.")
			ImGui.TreePop()
			ImGui.Spacing()
		end

		if ImGui.TreeNode("Capture/Logging") then
			Demo.HelpMarker(
				"The logging API redirects all text output so you can easily capture the content of " ..
				"a window or a block. Tree nodes can be automatically expanded.\n" ..
				"Try opening any of the contents below in this window and then click one of the \"Log To\" button.")
			ImGui.LogButtons()

			Demo.HelpMarker("You can also call ImGui::LogText() to output directly to the log without a visual output.")
			if ImGui.Button("Copy \"Hello, world!\" to clipboard") then
				ImGui.LogToClipboard()
				ImGui.LogText("Hello, world!")
				ImGui.LogFinish()
			end
			ImGui.TreePop()
		end
	end

	if ImGui.CollapsingHeader("Window options") then
		if ImGui.BeginTable("split", 3) then
			ImGui.TableNextColumn(); _, S.no_titlebar = ImGui.Checkbox("No titlebar", S.no_titlebar)
			ImGui.TableNextColumn(); _, S.no_scrollbar = ImGui.Checkbox("No scrollbar", S.no_scrollbar)
			ImGui.TableNextColumn(); _, S.no_menu = ImGui.Checkbox("No menu", S.no_menu)
			ImGui.TableNextColumn(); _, S.no_move = ImGui.Checkbox("No move", S.no_move)
			ImGui.TableNextColumn(); _, S.no_resize = ImGui.Checkbox("No resize", S.no_resize)
			ImGui.TableNextColumn(); _, S.no_collapse = ImGui.Checkbox("No collapse", S.no_collapse)
			ImGui.TableNextColumn(); _, S.no_close = ImGui.Checkbox("No close", S.no_close)
			ImGui.TableNextColumn(); _, S.no_nav = ImGui.Checkbox("No nav", S.no_nav)
			ImGui.TableNextColumn(); _, S.no_background = ImGui.Checkbox("No background", S.no_background)
			ImGui.TableNextColumn(); _, S.no_bring_to_front = ImGui.Checkbox("No bring to front", S.no_bring_to_front)
			ImGui.TableNextColumn(); _, S.unsaved_document = ImGui.Checkbox("Unsaved document", S.unsaved_document)
			ImGui.EndTable()
		end
	end

	Demo.DemoWindowWidgets(demo_data)
	Demo.DemoWindowLayout()
	Demo.DemoWindowPopups()
	Demo.DemoWindowTables()
	Demo.DemoWindowInputs()

	ImGui.PopItemWidth()
	ImGui.End()
	return p_open
end

function Demo.DemoWindowMenuBar(demo_data)
	if ImGui.BeginMenuBar() then
		if ImGui.BeginMenu("Menu") then
			Demo.ShowExampleMenuFile()
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Examples") then
			_, demo_data.ShowMainMenuBar = ImGui.MenuItem("Main menu bar", nil, demo_data.ShowMainMenuBar)

			ImGui.SeparatorText("Mini apps")
			_, demo_data.ShowAppAssetsBrowser = ImGui.MenuItem("Assets Browser", nil, demo_data.ShowAppAssetsBrowser)
			_, demo_data.ShowAppConsole = ImGui.MenuItem("Console", nil, demo_data.ShowAppConsole)
			_, demo_data.ShowAppCustomRendering = ImGui.MenuItem("Custom rendering", nil, demo_data.ShowAppCustomRendering)
			_, demo_data.ShowAppDocuments = ImGui.MenuItem("Documents", nil, demo_data.ShowAppDocuments)
			_, demo_data.ShowAppImageViewer = ImGui.MenuItem("Image Viewer", nil, demo_data.ShowAppImageViewer)
			_, demo_data.ShowAppLog = ImGui.MenuItem("Log", nil, demo_data.ShowAppLog)
			_, demo_data.ShowAppPropertyEditor = ImGui.MenuItem("Property editor", nil, demo_data.ShowAppPropertyEditor)
			_, demo_data.ShowAppLayout = ImGui.MenuItem("Simple layout", nil, demo_data.ShowAppLayout)
			_, demo_data.ShowAppSimpleOverlay = ImGui.MenuItem("Simple overlay", nil, demo_data.ShowAppSimpleOverlay)

			ImGui.SeparatorText("Concepts")
			_, demo_data.ShowAppAutoResize = ImGui.MenuItem("Auto-resizing window", nil, demo_data.ShowAppAutoResize)
			_, demo_data.ShowAppConstrainedResize = ImGui.MenuItem("Constrained-resizing window", nil, demo_data.ShowAppConstrainedResize)
			_, demo_data.ShowAppFullscreen = ImGui.MenuItem("Fullscreen window", nil, demo_data.ShowAppFullscreen)
			_, demo_data.ShowAppLongText = ImGui.MenuItem("Long text display", nil, demo_data.ShowAppLongText)
			_, demo_data.ShowAppWindowTitles = ImGui.MenuItem("Manipulating window titles", nil, demo_data.ShowAppWindowTitles)

			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Tools") then
			local io = ImGui.GetIO()
			local has_debug_tools = true
			_, demo_data.ShowMetrics = ImGui.MenuItem("Metrics/Debugger", nil, demo_data.ShowMetrics, has_debug_tools)
			if ImGui.BeginMenu("Debug Options") then
				ImGui.BeginDisabled(not has_debug_tools)
				_, io.ConfigDebugHighlightIdConflicts = ImGui.Checkbox("Highlight ID Conflicts", io.ConfigDebugHighlightIdConflicts)
				ImGui.EndDisabled()
				_, io.ConfigErrorRecoveryEnableAssert = ImGui.Checkbox("Assert on error recovery", io.ConfigErrorRecoveryEnableAssert)
				ImGui.TextDisabled("(see Demo->Configuration for more)")
				ImGui.EndMenu()
			end
			_, demo_data.ShowDebugLog = ImGui.MenuItem("Debug Log", nil, demo_data.ShowDebugLog, has_debug_tools)
			_, demo_data.ShowIDStackTool = ImGui.MenuItem("ID Stack Tool", nil, demo_data.ShowIDStackTool, has_debug_tools)
			local is_debugger_present = io.ConfigDebugIsDebuggerPresent
			if ImGui.MenuItem("Item Picker", nil, false, has_debug_tools) then
				ImGui.DebugStartItemPicker()
			end
			if not is_debugger_present then
				ImGui.SetItemTooltip("Requires io.ConfigDebugIsDebuggerPresent=true to be set.\n\nWe otherwise disable some extra features to avoid casual users crashing the application.")
			end
			_, demo_data.ShowStyleEditor = ImGui.MenuItem("Style Editor", nil, demo_data.ShowStyleEditor)
			_, demo_data.ShowAbout = ImGui.MenuItem("About Dear ImGui", nil, demo_data.ShowAbout)

			ImGui.EndMenu()
		end
		ImGui.EndMenuBar()
	end
end

local ExampleTreeNode = {}
ExampleTreeNode.__index = ExampleTreeNode

function ExampleTreeNode.new()
	return setmetatable({
		Name = "",
		UID = 0,
		Parent = nil,
		Childs = Base.ImVector.new(),
		IndexInParent = 0,
		HasData = false,
		DataMyBool = true,
		DataMyInt = 128,
		DataMyVec2 = ImVec2(0.0, 3.141592),
	}, ExampleTreeNode)
end

Demo.ExampleTreeNode = ExampleTreeNode

Demo.ExampleTreeNodeMemberInfos = {
	{ Name = "MyName", DataType = ImGuiDataType.String, DataCount = 1, Field = "Name" },
	{ Name = "MyBool", DataType = ImGuiDataType.Bool, DataCount = 1, Field = "DataMyBool" },
	{ Name = "MyInt", DataType = ImGuiDataType.S32, DataCount = 1, Field = "DataMyInt" },
	{ Name = "MyVec2", DataType = ImGuiDataType.Float, DataCount = 2, Field = "DataMyVec2" },
}

function Demo.ExampleTree_CreateNode(name, uid, parent)
	local node = ExampleTreeNode.new()
	node.Name = string.sub(name, 1, 27)
	node.UID = uid
	node.Parent = parent
	node.IndexInParent = parent and parent.Childs.Size or 0
	if parent then
		parent.Childs:push_back(node)
	end
	return node
end

function Demo.ExampleTree_CreateDemoTree()
	local ROOT_ITEMS_COUNT = 20
	local category_names = { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pear", "Pineapple", "Strawberry", "Watermelon" }
	local category_count = #category_names
	local uid = 1
	local node_L0 = Demo.ExampleTree_CreateNode("<ROOT>", uid, nil)
	for idx_L0 = 0, ROOT_ITEMS_COUNT - 1 do
		local name_buf = Base.ImFormatString("%s %d", category_names[idx_L0 // (ROOT_ITEMS_COUNT // category_count) + 1], idx_L0 % (ROOT_ITEMS_COUNT // category_count))
		uid = uid + 1
		local node_L1 = Demo.ExampleTree_CreateNode(name_buf, uid, node_L0)
		local number_of_childs = #node_L1.Name
		for idx_L1 = 0, number_of_childs - 1 do
			uid = uid + 1
			local node_L2 = Demo.ExampleTree_CreateNode(Base.ImFormatString("Child %d", idx_L1), uid, node_L1)
			node_L2.HasData = true
			if idx_L1 == 0 then
				uid = uid + 1
				local node_L3 = Demo.ExampleTree_CreateNode(Base.ImFormatString("Sub-child %d", 0), uid, node_L2)
				node_L3.HasData = true
			end
		end
	end
	return node_L0
end

local ExampleImageViewerData = {}
ExampleImageViewerData.__index = ExampleImageViewerData

function ExampleImageViewerData.new()
	return setmetatable({
		ImageBgColor = IM_COL32(100, 100, 100, 255),
		GridColor = IM_COL32(255, 255, 255, 100),
		GridEnabled = true,
		ViewReset = true,
		ViewOffset = ImVec2(0, 0),
		Zoom = 10.0,
		ZoomMin = 1.0,
		ZoomMax = 10000.0,
	}, ExampleImageViewerData)
end

Demo.ExampleImageViewerData = ExampleImageViewerData

function Demo.ExampleImageViewer_DrawOptions(data)
	ImGui.SetNextItemShortcut(ImGuiKey.G, ImGuiInputFlags.Tooltip)
	_, data.GridEnabled = ImGui.Checkbox("Grid", data.GridEnabled)
	ImGui.SameLine()
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 10.0)
	local zoom_100 = data.Zoom * 100.0
	local changed
	changed, zoom_100 = ImGui.DragFloat("##Zoom", zoom_100, 5.0, data.ZoomMin * 100.0, data.ZoomMax * 100.0, "%.0f%%", ImGuiSliderFlags.AlwaysClamp)
	if changed then
		data.Zoom = zoom_100 / 100.0
	end
end

function Demo.ExampleImageViewer_DrawCanvas(data, canvas_size, image_tex_ref, image_w, image_h)
	local io = ImGui.GetIO()
	local platform_io = ImGui.GetPlatformIO()
	local draw_list = ImGui.GetWindowDrawList()
	assert(canvas_size.x >= 0.0 and canvas_size.y >= 0.0)

	ImGui.InvisibleButton("##Canvas", canvas_size)
	local canvas_min = ImGui.GetItemRectMin()
	local canvas_max = ImGui.GetItemRectMax()

	if data.ViewReset then
		data.ViewOffset = ImVec2((canvas_size.x * 0.5 / data.Zoom) - 0.5, (canvas_size.y * 0.5 / data.Zoom) - 0.5)
	end
	data.ViewReset = false

	if ImGui.SetItemKeyOwner(ImGuiKey.MouseWheelY) then
		if io.MouseWheel ~= 0.0 then
			data.Zoom = math.clamp(data.Zoom * (1.0 + io.MouseWheel * 0.10), data.ZoomMin, data.ZoomMax)
		end
	end
	local zoom = data.Zoom
	if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) then
		data.ViewOffset = ImVec2(data.ViewOffset.x - io.MouseDelta.x / zoom, data.ViewOffset.y - io.MouseDelta.y / zoom)
	end

	local image_min = ImVec2(
		ImTruncToInt((canvas_min.x - (data.ViewOffset.x * zoom)) + (canvas_size.x * 0.5)),
		ImTruncToInt((canvas_min.y - (data.ViewOffset.y * zoom)) + (canvas_size.y * 0.5)))
	local image_max = ImVec2(
		ImTruncToInt(image_min.x + image_w * zoom),
		ImTruncToInt(image_min.y + image_h * zoom))
	draw_list:AddRect(ImVec2(canvas_min.x - 1.0, canvas_min.y - 1.0), ImVec2(canvas_max.x + 1.0, canvas_max.y + 1.0), IM_COL32(255, 255, 255, 255))
	draw_list:PushClipRect(canvas_min, canvas_max, true)
	draw_list:AddRectFilled(image_min, image_max, data.ImageBgColor)
	if platform_io.DrawCallback_SetSamplerNearest then
		draw_list:AddCallback(platform_io.DrawCallback_SetSamplerNearest)
	end
	if image_tex_ref then
		draw_list:AddImage(image_tex_ref, image_min, image_max)
	end
	if ImGui.GetPlatformIO().DrawCallback_SetSamplerLinear then
		draw_list:AddCallback(ImGui.GetPlatformIO().DrawCallback_SetSamplerLinear)
	end

	if data.GridEnabled and zoom > 6.0 then
		local step = zoom
		for px = ImTruncToInt((canvas_min.x - image_min.x) / step), ImTruncToInt((canvas_max.x - image_min.x) / step) do
			draw_list:AddLineV(image_min.x + px * step, canvas_min.y, canvas_max.y, data.GridColor, 1.0)
		end
		for py = ImTruncToInt((canvas_min.y - image_min.y) / step), ImTruncToInt((canvas_max.y - image_min.y) / step) do
			draw_list:AddLineH(canvas_min.x, canvas_max.x, image_min.y + py * step, data.GridColor, 1.0)
		end
	end
	draw_list:PopClipRect()
end

local S_DemoWindowWidgetsBasic = {
	clicked = 0,
	check = true,
	e = 0,
	counter = 0,
	str0 = "Hello, world!",
	str1 = "",
	i0 = 123,
	f0 = 0.001,
	d0 = 999999.00000001,
	in_f1 = 1.e10,
	vec4a = { 0.10, 0.20, 0.30, 0.44 },
	drag_i1 = 50,
	drag_i2 = 42,
	drag_i3 = 128,
	drag_f1 = 1.00,
	drag_f2 = 0.0067,
	sl_i1 = 0,
	sl_f1 = 0.123,
	sl_f2 = 0.0,
	angle = 0.0,
	elem = 0,
	col1 = { 1.0, 0.0, 0.2 },
	col2 = { 0.4, 0.7, 0.0, 0.5 },
	combo_current = 0,
	listbox_current = 1,
}

function Demo.DemoWindowWidgetsBasic()
	if ImGui.TreeNode("Basic") then
		local S = S_DemoWindowWidgetsBasic
		ImGui.SeparatorText("General")

		if ImGui.Button("Button") then
			S.clicked = S.clicked + 1
		end
		if bit32.btest(S.clicked, 1) then
			ImGui.SameLine()
			ImGui.Text("Thanks for clicking me!")
		end

		_, S.check = ImGui.Checkbox("checkbox", S.check)

		_, S.e = ImGui.RadioButton("radio a", S.e, 0); ImGui.SameLine()
		_, S.e = ImGui.RadioButton("radio b", S.e, 1); ImGui.SameLine()
		_, S.e = ImGui.RadioButton("radio c", S.e, 2)

		ImGui.AlignTextToFramePadding()
		ImGui.TextLinkOpenURL("Hyperlink", "https://github.com/ocornut/imgui/wiki/Error-Handling")

		for i = 0, 6 do
			if i > 0 then
				ImGui.SameLine()
			end
			ImGui.PushID(i)
			ImGui.PushStyleColor(ImGuiCol.Button, Structs.ImColor.HSV(i / 7.0, 0.6, 0.6).Value)
			ImGui.PushStyleColor(ImGuiCol.ButtonHovered, Structs.ImColor.HSV(i / 7.0, 0.7, 0.7).Value)
			ImGui.PushStyleColor(ImGuiCol.ButtonActive, Structs.ImColor.HSV(i / 7.0, 0.8, 0.8).Value)
			ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.0, 1.0, 1.0, 1.0))
			ImGui.Button("Click")
			ImGui.PopStyleColor(4)
			ImGui.PopID()
		end

		ImGui.AlignTextToFramePadding()
		ImGui.Text("Hold to repeat:")
		ImGui.SameLine()

		local spacing = ImGui.GetStyle().ItemInnerSpacing.x
		ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true)
		if ImGui.ArrowButton("##left", ImGuiDir.Left) then
			S.counter = S.counter - 1
		end
		ImGui.SameLine(0.0, spacing)
		if ImGui.ArrowButton("##right", ImGuiDir.Right) then
			S.counter = S.counter + 1
		end
		ImGui.PopItemFlag()
		ImGui.SameLine()
		ImGui.Text("%d", S.counter)

		ImGui.Button("Tooltip")
		ImGui.SetItemTooltip("I am a tooltip")

		ImGui.LabelText("label", "Value")

		ImGui.SeparatorText("Inputs")

		do
			_, S.str0 = ImGui.InputText("input text", S.str0)
			ImGui.SameLine(); Demo.HelpMarker(
				"USER:\n" ..
				"Hold Shift or use mouse to select text.\n" ..
				"Ctrl+Left/Right to word jump.\n" ..
				"Ctrl+A or Double-Click to select all.\n" ..
				"Ctrl+X,Ctrl+C,Ctrl+V for clipboard.\n" ..
				"Ctrl+Z to undo, Ctrl+Y/Ctrl+Shift+Z to redo.\n" ..
				"Escape to revert.\n\n" ..
				"PROGRAMMER:\n" ..
				"You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputText() " ..
				"to a dynamic string type. See misc/cpp/imgui_stdlib.h for an example (this is not demonstrated " ..
				"in imgui_demo.cpp).")

			_, S.str1 = ImGui.InputTextWithHint("input text (w/ hint)", "enter text here", S.str1)

			_, S.i0 = ImGui.InputInt("input int", S.i0)

			_, S.f0 = ImGui.InputFloat("input float", S.f0, 0.01, 1.0, "%.3f")

			_, S.d0 = ImGui.InputDouble("input double", S.d0, 0.01, 1.0, "%.8f")

			_, S.in_f1 = ImGui.InputFloat("input scientific", S.in_f1, 0.0, 0.0, "%e")
			ImGui.SameLine(); Demo.HelpMarker(
				"You can input value using the scientific notation,\n" ..
				"  e.g. \"1e+8\" becomes \"100000000\".")

			ImGui.InputFloat3("input float3", S.vec4a)
		end

		ImGui.SeparatorText("Drags")

		do
			_, S.drag_i1 = ImGui.DragInt("drag int", S.drag_i1, 1)
			ImGui.SameLine(); Demo.HelpMarker(
				"Click and drag to edit value.\n" ..
				"Hold Shift/Alt for faster/slower edit.\n" ..
				"Double-Click or Ctrl+Click to input value.")
			_, S.drag_i2 = ImGui.DragInt("drag int 0..100", S.drag_i2, 1, 0, 100, "%d%%", ImGuiSliderFlags.AlwaysClamp)
			_, S.drag_i3 = ImGui.DragInt("drag int wrap 100..200", S.drag_i3, 1, 100, 200, "%d", ImGuiSliderFlags.WrapAround)

			_, S.drag_f1 = ImGui.DragFloat("drag float", S.drag_f1, 0.005)
			_, S.drag_f2 = ImGui.DragFloat("drag small float", S.drag_f2, 0.0001, 0.0, 0.0, "%.06f ns")
		end

		ImGui.SeparatorText("Sliders")

		do
			_, S.sl_i1 = ImGui.SliderInt("slider int", S.sl_i1, -1, 3)
			ImGui.SameLine(); Demo.HelpMarker("Ctrl+Click to input value.")

			_, S.sl_f1 = ImGui.SliderFloat("slider float", S.sl_f1, 0.0, 1.0, "ratio = %.3f")
			_, S.sl_f2 = ImGui.SliderFloat("slider float (log)", S.sl_f2, -10.0, 10.0, "%.4f", ImGuiSliderFlags.Logarithmic)

			_, S.angle = ImGui.SliderAngle("slider angle", S.angle)

			local Element_COUNT = 4
			local elems_names = { "Fire", "Earth", "Air", "Water" }
			local elem_name = (S.elem >= 0 and S.elem < Element_COUNT) and elems_names[S.elem + 1] or "Unknown"
			_, S.elem = ImGui.SliderInt("slider enum", S.elem, 0, Element_COUNT - 1, elem_name)
			ImGui.SameLine(); Demo.HelpMarker("Using the format string parameter to display a name instead of the underlying integer.")
		end

		ImGui.SeparatorText("Selectors/Pickers")

		do
			ImGui.ColorEdit3("color 1", S.col1)
			ImGui.SameLine(); Demo.HelpMarker(
				"Click on the color square to open a color picker.\n" ..
				"Click and hold to use drag and drop.\n" ..
				"Right-Click on the color square to show options.\n" ..
				"Ctrl+Click on individual component to input value.\n")

			ImGui.ColorEdit4("color 2", S.col2)
		end

		do
			local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIIIIII", "JJJJ", "KKKKKKK" }
			_, S.combo_current = ImGui.Combo("combo", S.combo_current, items, #items)
			ImGui.SameLine(); Demo.HelpMarker(
				"Using the simplified one-liner Combo API here.\n" ..
				"Refer to the \"Combo\" section below for an explanation of how to use the more flexible and general BeginCombo/EndCombo API.")
		end

		do
			local items = { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pineapple", "Strawberry", "Watermelon" }
			_, S.listbox_current = ImGui.ListBox("listbox", S.listbox_current, items, #items, 4)
			ImGui.SameLine(); Demo.HelpMarker(
				"Using the simplified one-liner ListBox API here.\n" ..
				"Refer to the \"List boxes\" section below for an explanation of how to use the more flexible and general BeginListBox/EndListBox API.")
		end

		ImGui.TreePop()
	end
end

function Demo.DemoWindowWidgetsBullets()
	if ImGui.TreeNode("Bullets") then
		ImGui.BulletText("Bullet point 1")
		ImGui.BulletText("Bullet point 2\nOn multiple lines")
		if ImGui.TreeNode("Tree node") then
			ImGui.BulletText("Another bullet point")
			ImGui.TreePop()
		end
		ImGui.Bullet(); ImGui.Text("Bullet point 3 (two calls)")
		ImGui.Bullet(); ImGui.SmallButton("Button")
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsCollapsingHeaders = {
	closable_group = true,
}

function Demo.DemoWindowWidgetsCollapsingHeaders()
	if ImGui.TreeNode("Collapsing Headers") then
		local S = S_DemoWindowWidgetsCollapsingHeaders
		_, S.closable_group = ImGui.Checkbox("Show 2nd header", S.closable_group)
		if ImGui.CollapsingHeader("Header", ImGuiTreeNodeFlags.None) then
			ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
			for i = 0, 4 do
				ImGui.Text("Some content %d", i)
			end
		end
		local open
		open, S.closable_group = ImGui.CollapsingHeader("Header with a close button", S.closable_group)
		if open then
			ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
			for i = 0, 4 do
				ImGui.Text("More content %d", i)
			end
		end
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsColorAndPickers = {
	color = { 114.0 / 255.0, 144.0 / 255.0, 154.0 / 255.0, 200.0 / 255.0 },
	base_flags = ImGuiColorEditFlags.None,
	saved_palette_init = true,
	saved_palette = {},
	backup_color = { 0.0, 0.0, 0.0, 0.0 },
	no_border = false,
	ref_color = false,
	ref_color_v = { 1.0, 0.0, 1.0, 0.5 },
	picker_mode = 0,
	display_mode = 0,
	color_picker_flags = ImGuiColorEditFlags.AlphaBar,
	color_hsv = { 0.23, 1.0, 1.0, 1.0 },
}

function Demo.DemoWindowWidgetsColorAndPickers()
	if ImGui.TreeNode("Color/Picker Widgets") then
		local S = S_DemoWindowWidgetsColorAndPickers

		ImGui.SeparatorText("Options")
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", S.base_flags, ImGuiColorEditFlags.NoAlpha)
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaOpaque", S.base_flags, ImGuiColorEditFlags.AlphaOpaque)
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaNoBg", S.base_flags, ImGuiColorEditFlags.AlphaNoBg)
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaPreviewHalf", S.base_flags, ImGuiColorEditFlags.AlphaPreviewHalf)
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoOptions", S.base_flags, ImGuiColorEditFlags.NoOptions); ImGui.SameLine(); Demo.HelpMarker("Right-click on the individual color widget to show options.")
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoDragDrop", S.base_flags, ImGuiColorEditFlags.NoDragDrop)
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoColorMarkers", S.base_flags, ImGuiColorEditFlags.NoColorMarkers)
		_, S.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_HDR", S.base_flags, ImGuiColorEditFlags.HDR); ImGui.SameLine(); Demo.HelpMarker("Currently all this does is to lift the 0..1 limits on dragging widgets.")

		ImGui.SeparatorText("Inline color editor")
		ImGui.Text("Color widget:")
		ImGui.SameLine(); Demo.HelpMarker(
			"Click on the color square to open a color picker.\n" ..
			"Ctrl+Click on individual component to input value.\n")
		ImGui.ColorEdit3("MyColor##1", S.color, S.base_flags)

		ImGui.Text("Color widget HSV with Alpha:")
		ImGui.ColorEdit4("MyColor##2", S.color, bit32.bor(ImGuiColorEditFlags.DisplayHSV, S.base_flags))

		ImGui.Text("Color widget with Float Display:")
		ImGui.ColorEdit4("MyColor##2f", S.color, bit32.bor(ImGuiColorEditFlags.Float, S.base_flags))

		ImGui.Text("Color button with Picker:")
		ImGui.SameLine(); Demo.HelpMarker(
			"With the ImGuiColorEditFlags_NoInputs flag you can hide all the slider/text inputs.\n" ..
			"With the ImGuiColorEditFlags_NoLabel flag you can pass a non-empty label which will only " ..
			"be used for the tooltip and picker popup.")
		ImGui.ColorEdit4("MyColor##3", S.color, bit32.bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoLabel, S.base_flags))

		ImGui.Text("Color button with Custom Picker Popup:")

		if S.saved_palette_init then
			for n = 0, 31 do
				local r, g, b = ImGui.ColorConvertHSVtoRGB(n / 31.0, 0.8, 0.8)
				S.saved_palette[n + 1] = { r, g, b, 1.0 }
			end
			S.saved_palette_init = false
		end

		local open_popup = ImGui.ColorButton("MyColor##3b", ImVec4(table.unpack(S.color, 1, 4)), S.base_flags)
		ImGui.SameLine(0, ImGui.GetStyle().ItemInnerSpacing.x)
		local palette_pressed = ImGui.Button("Palette")
		open_popup = open_popup or palette_pressed
		if open_popup then
			ImGui.OpenPopup("mypicker")
			S.backup_color = { table.unpack(S.color, 1, 4) }
		end
		local ref_sz = ImGui.GetFrameHeight()
		if ImGui.BeginPopup("mypicker") then
			ImGui.Text("MY CUSTOM COLOR PICKER WITH AN AMAZING PALETTE!")
			ImGui.Separator()
			ImGui.ColorPicker4("##picker", S.color, bit32.bor(S.base_flags, ImGuiColorEditFlags.NoSidePreview, ImGuiColorEditFlags.NoSmallPreview))
			ImGui.SameLine()

			local color_button_sz = ImVec2(ref_sz * 3.0, ref_sz * 2.0)
			ImGui.BeginGroup()
			ImGui.Text("Current")
			ImGui.ColorButton("##current", ImVec4(table.unpack(S.color, 1, 4)), bit32.bor(ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.AlphaPreviewHalf), color_button_sz)
			ImGui.Text("Previous")
			if ImGui.ColorButton("##previous", ImVec4(table.unpack(S.backup_color, 1, 4)), bit32.bor(ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.AlphaPreviewHalf), color_button_sz) then
				S.color = { table.unpack(S.backup_color, 1, 4) }
			end
			ImGui.Separator()
			ImGui.Text("Palette")
			for n = 0, 31 do
				ImGui.PushID(n)
				if n % 8 ~= 0 then
					ImGui.SameLine(0.0, ImGui.GetStyle().ItemSpacing.y)
				end

				local palette_button_flags = bit32.bor(ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.NoTooltip)
				local p = S.saved_palette[n + 1]
				if ImGui.ColorButton("##palette", ImVec4(table.unpack(p, 1, 4)), palette_button_flags) then
					S.color[1], S.color[2], S.color[3] = p[1], p[2], p[3]
				end

				if ImGui.BeginDragDropTarget() then
					local payload = ImGui.AcceptDragDropPayload("_COL3F")
					if payload then
						local d = payload.Data
						p[1], p[2], p[3] = d[1], d[2], d[3]
					end
					payload = ImGui.AcceptDragDropPayload("_COL4F")
					if payload then
						local d = payload.Data
						p[1], p[2], p[3], p[4] = d[1], d[2], d[3], d[4]
					end
					ImGui.EndDragDropTarget()
				end

				ImGui.PopID()
			end
			ImGui.EndGroup()
			ImGui.EndPopup()
		end

		ImGui.Text("Color button only:")
		local color_button_sz = ImVec2(ref_sz * 2.0, ref_sz * 2.0)
		_, S.no_border = ImGui.Checkbox("ImGuiColorEditFlags_NoBorder", S.no_border)
		ImGui.ColorButton("MyColor##3c", ImVec4(table.unpack(S.color, 1, 4)), bit32.bor(S.base_flags, S.no_border and ImGuiColorEditFlags.NoBorder or 0), color_button_sz)

		ImGui.SeparatorText("Color picker")

		ImGui.PushID("Color picker")
		_, S.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", S.color_picker_flags, ImGuiColorEditFlags.NoAlpha)
		_, S.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaBar", S.color_picker_flags, ImGuiColorEditFlags.AlphaBar)
		_, S.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoSidePreview", S.color_picker_flags, ImGuiColorEditFlags.NoSidePreview)
		if bit32.btest(S.color_picker_flags, ImGuiColorEditFlags.NoSidePreview) then
			ImGui.SameLine()
			_, S.ref_color = ImGui.Checkbox("With Ref Color", S.ref_color)
			if S.ref_color then
				ImGui.SameLine()
				ImGui.ColorEdit4("##RefColor", S.ref_color_v, bit32.bor(ImGuiColorEditFlags.NoInputs, S.base_flags))
			end
		end
		_, S.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_PickerNoRotate", S.color_picker_flags, ImGuiColorEditFlags.PickerNoRotate)

		_, S.picker_mode = ImGui.Combo("Picker Mode", S.picker_mode, "Auto/Current\0ImGuiColorEditFlags_PickerHueBar\0ImGuiColorEditFlags_PickerHueWheel\0")
		ImGui.SameLine(); Demo.HelpMarker("When not specified explicitly, user can right-click the picker to change mode.")

		_, S.display_mode = ImGui.Combo("Display Mode", S.display_mode, "Auto/Current\0ImGuiColorEditFlags_NoInputs\0ImGuiColorEditFlags_DisplayRGB\0ImGuiColorEditFlags_DisplayHSV\0ImGuiColorEditFlags_DisplayHex\0")
		ImGui.SameLine(); Demo.HelpMarker(
			"ColorEdit defaults to displaying RGB inputs if you don't specify a display mode, " ..
			"but the user can change it with a right-click on those inputs.\n\nColorPicker defaults to displaying RGB+HSV+Hex " ..
			"if you don't specify a display mode.\n\nYou can change the defaults using io.ConfigColorEditFlags.")

		local flags = bit32.bor(S.base_flags, S.color_picker_flags)
		if S.picker_mode == 1 then flags = bit32.bor(flags, ImGuiColorEditFlags.PickerHueBar) end
		if S.picker_mode == 2 then flags = bit32.bor(flags, ImGuiColorEditFlags.PickerHueWheel) end
		if S.display_mode == 1 then flags = bit32.bor(flags, ImGuiColorEditFlags.NoInputs) end
		if S.display_mode == 2 then flags = bit32.bor(flags, ImGuiColorEditFlags.DisplayRGB) end
		if S.display_mode == 3 then flags = bit32.bor(flags, ImGuiColorEditFlags.DisplayHSV) end
		if S.display_mode == 4 then flags = bit32.bor(flags, ImGuiColorEditFlags.DisplayHex) end
		ImGui.ColorPicker4("MyColor##4", S.color, flags, S.ref_color and S.ref_color_v or nil)

		ImGui.Text("Set defaults in code:")
		ImGui.SameLine(); Demo.HelpMarker(
			"io.ConfigColorEditFlags is designed to allow you to set boot-time default.\n" ..
			"We don't have Push/Pop functions because you can force options on a per-widget basis if needed, " ..
			"and the user can change non-forced ones with the options menu.\nWe don't have a getter to avoid " ..
			"encouraging you to persistently save values that aren't forward-compatible.")
		if ImGui.Button("Overwrite default: Uint8 + HSV + Hue Bar") then
			ImGui.GetIO().ConfigColorEditFlags = bit32.bor(ImGuiColorEditFlags.Uint8, ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.PickerHueBar, ImGuiColorEditFlags.InputRGB)
		end
		if ImGui.Button("Overwrite default: Float + HDR + Hue Wheel") then
			ImGui.GetIO().ConfigColorEditFlags = bit32.bor(ImGuiColorEditFlags.Float, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.PickerHueWheel, ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.InputRGB)
		end

		ImGui.Text("Both types:")
		local w = (ImGui.GetContentRegionAvail().x - ImGui.GetStyle().ItemSpacing.y) * 0.40
		ImGui.SetNextItemWidth(w)
		ImGui.ColorPicker3("##MyColor##5", S.color, bit32.bor(ImGuiColorEditFlags.PickerHueBar, ImGuiColorEditFlags.NoSidePreview, ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoAlpha))
		ImGui.SameLine()
		ImGui.SetNextItemWidth(w)
		ImGui.ColorPicker3("##MyColor##6", S.color, bit32.bor(ImGuiColorEditFlags.PickerHueWheel, ImGuiColorEditFlags.NoSidePreview, ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoAlpha))
		ImGui.PopID()

		ImGui.Spacing()
		ImGui.Text("HSV encoded colors")
		ImGui.SameLine(); Demo.HelpMarker(
			"By default, colors are given to ColorEdit and ColorPicker in RGB, but ImGuiColorEditFlags_InputHSV " ..
			"allows you to store colors as HSV and pass them to ColorEdit and ColorPicker as HSV. This comes with the " ..
			"added benefit that you can manipulate hue values with the picker even when saturation or value are zero.")
		ImGui.Text("Color widget with InputHSV:")
		ImGui.ColorEdit4("HSV shown as RGB##1", S.color_hsv, bit32.bor(ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.InputHSV, ImGuiColorEditFlags.Float))
		ImGui.ColorEdit4("HSV shown as HSV##1", S.color_hsv, bit32.bor(ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.InputHSV, ImGuiColorEditFlags.Float))
		ImGui.DragFloat4("Raw HSV values", S.color_hsv, 0.01, 0.0, 1.0)

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsComboBoxes = {
	flags = ImGuiComboFlags.None,
	item_selected_idx = 0,
	filter = Base.ImGuiTextFilter.new(),
	item_current_2 = 0,
	item_current_3 = -1,
	item_current_4 = 0,
}

function Demo.DemoWindowWidgetsComboBoxes()
	if ImGui.TreeNode("Combo") then
		local S = S_DemoWindowWidgetsComboBoxes

		_, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_PopupAlignLeft", S.flags, ImGuiComboFlags.PopupAlignLeft)
		ImGui.SameLine(); Demo.HelpMarker("Only makes a difference if the popup is larger than the combo")
		local pressed
		pressed, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoArrowButton", S.flags, ImGuiComboFlags.NoArrowButton)
		if pressed then
			S.flags = bit32.band(S.flags, bit32.bnot(ImGuiComboFlags.NoPreview))
		end
		pressed, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoPreview", S.flags, ImGuiComboFlags.NoPreview)
		if pressed then
			S.flags = bit32.band(S.flags, bit32.bnot(bit32.bor(ImGuiComboFlags.NoArrowButton, ImGuiComboFlags.WidthFitPreview)))
		end
		pressed, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_WidthFitPreview", S.flags, ImGuiComboFlags.WidthFitPreview)
		if pressed then
			S.flags = bit32.band(S.flags, bit32.bnot(ImGuiComboFlags.NoPreview))
		end

		pressed, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_HeightSmall", S.flags, ImGuiComboFlags.HeightSmall)
		if pressed then
			S.flags = bit32.band(S.flags, bit32.bnot(bit32.band(ImGuiComboFlags.HeightMask_, bit32.bnot(ImGuiComboFlags.HeightSmall))))
		end
		pressed, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_HeightRegular", S.flags, ImGuiComboFlags.HeightRegular)
		if pressed then
			S.flags = bit32.band(S.flags, bit32.bnot(bit32.band(ImGuiComboFlags.HeightMask_, bit32.bnot(ImGuiComboFlags.HeightRegular))))
		end
		pressed, S.flags = ImGui.CheckboxFlags("ImGuiComboFlags_HeightLargest", S.flags, ImGuiComboFlags.HeightLargest)
		if pressed then
			S.flags = bit32.band(S.flags, bit32.bnot(bit32.band(ImGuiComboFlags.HeightMask_, bit32.bnot(ImGuiComboFlags.HeightLargest))))
		end

		local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }

		local combo_preview_value = items[S.item_selected_idx + 1]
		if ImGui.BeginCombo("combo 1", combo_preview_value, S.flags) then
			for n = 0, #items - 1 do
				local is_selected = (S.item_selected_idx == n)
				if ImGui.Selectable(items[n + 1], is_selected) then
					S.item_selected_idx = n
				end

				if is_selected then
					ImGui.SetItemDefaultFocus()
				end
			end
			ImGui.EndCombo()
		end

		if ImGui.BeginCombo("combo 2 (w/ filter)", combo_preview_value, S.flags) then
			if ImGui.IsWindowAppearing() then
				ImGui.SetKeyboardFocusHere()
				S.filter:Clear()
			end
			ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.F))
			ImGui.SetNextItemWidth(-Base.FLT_MIN)
			S.filter:DrawWithHint("##Filter", "Filter (incl -excl)")

			for n = 0, #items - 1 do
				local is_selected = (S.item_selected_idx == n)
				if S.filter:PassFilter(items[n + 1]) then
					if ImGui.Selectable(items[n + 1], is_selected) then
						S.item_selected_idx = n
					end
				end
			end
			ImGui.EndCombo()
		end

		ImGui.Spacing()
		ImGui.SeparatorText("One-liner variants")
		Demo.HelpMarker("The Combo() function is not greatly useful apart from cases were you want to embed all options in a single strings.\nFlags above don't apply to this section.")

		_, S.item_current_2 = ImGui.Combo("combo 3 (one-liner)", S.item_current_2, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")

		_, S.item_current_3 = ImGui.Combo("combo 4 (array)", S.item_current_3, items, #items)

		_, S.item_current_4 = ImGui.Combo("combo 5 (function)", S.item_current_4, function(data, n) return data[n + 1] end, items, #items)

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsDataTypes = {
	s8_v = 127,
	u8_v = 255,
	s16_v = 32767,
	u16_v = 65535,
	s32_v = -1,
	u32_v = 4294967295,
	s64_v = -1,
	u64_v = 18446744073709551615,
	f32_v = 0.123,
	f64_v = 90000.01234567890123456789,
	drag_clamp = false,
	inputs_step = true,
	flags = ImGuiInputTextFlags.None,
}

function Demo.DemoWindowWidgetsDataTypes()
	if ImGui.TreeNode("Data Types") then
		local S = S_DemoWindowWidgetsDataTypes

		local s8_zero, s8_one, s8_fifty, s8_min, s8_max = 0, 1, 50, -128, 127
		local u8_zero, u8_one, u8_fifty, u8_min, u8_max = 0, 1, 50, 0, 255
		local s16_zero, s16_one, s16_fifty, s16_min, s16_max = 0, 1, 50, -32768, 32767
		local u16_zero, u16_one, u16_fifty, u16_min, u16_max = 0, 1, 50, 0, 65535
		local s32_zero, s32_one, s32_fifty, s32_min, s32_max, s32_hi_a, s32_hi_b = 0, 1, 50, -1073741824, 1073741823, 1073741723, 1073741823
		local u32_zero, u32_one, u32_fifty, u32_min, u32_max, u32_hi_a, u32_hi_b = 0, 1, 50, 0, 2147483647, 2147483547, 2147483647
		local s64_zero, s64_one, s64_fifty, s64_min, s64_max, s64_hi_a, s64_hi_b = 0, 1, 50, -4611686018427387904, 4611686018427387903, 4611686018427387803, 4611686018427387903
		local u64_zero, u64_one, u64_fifty, u64_min, u64_max, u64_hi_a, u64_hi_b = 0, 1, 50, 0, 9223372036854775807, 9223372036854775707, 9223372036854775807
		local f32_zero, f32_one, f32_lo_a, f32_hi_a = 0.0, 1.0, -10000000000.0, 10000000000.0
		local f64_zero, f64_one, f64_lo_a, f64_hi_a = 0.0, 1.0, -1000000000000000.0, 1000000000000000.0

		local drag_speed = 0.2
		ImGui.SeparatorText("Drags")
		_, S.drag_clamp = ImGui.Checkbox("Clamp integers to 0..50", S.drag_clamp)
		ImGui.SameLine(); Demo.HelpMarker(
			"As with every widget in dear imgui, we never modify values unless there is a user interaction.\n" ..
			"You can override the clamping limits by using Ctrl+Click to input a value.")
		_, S.s8_v = ImGui.DragScalar("drag s8", ImGuiDataType.S8, S.s8_v, drag_speed, S.drag_clamp and s8_zero or nil, S.drag_clamp and s8_fifty or nil)
		_, S.u8_v = ImGui.DragScalar("drag u8", ImGuiDataType.U8, S.u8_v, drag_speed, S.drag_clamp and u8_zero or nil, S.drag_clamp and u8_fifty or nil, "%u ms")
		_, S.s16_v = ImGui.DragScalar("drag s16", ImGuiDataType.S16, S.s16_v, drag_speed, S.drag_clamp and s16_zero or nil, S.drag_clamp and s16_fifty or nil)
		_, S.u16_v = ImGui.DragScalar("drag u16", ImGuiDataType.U16, S.u16_v, drag_speed, S.drag_clamp and u16_zero or nil, S.drag_clamp and u16_fifty or nil, "%u ms")
		_, S.s32_v = ImGui.DragScalar("drag s32", ImGuiDataType.S32, S.s32_v, drag_speed, S.drag_clamp and s32_zero or nil, S.drag_clamp and s32_fifty or nil)
		_, S.s32_v = ImGui.DragScalar("drag s32 hex", ImGuiDataType.S32, S.s32_v, drag_speed, S.drag_clamp and s32_zero or nil, S.drag_clamp and s32_fifty or nil, "0x%08X")
		_, S.u32_v = ImGui.DragScalar("drag u32", ImGuiDataType.U32, S.u32_v, drag_speed, S.drag_clamp and u32_zero or nil, S.drag_clamp and u32_fifty or nil, "%u ms")
		_, S.s64_v = ImGui.DragScalar("drag s64", ImGuiDataType.S64, S.s64_v, drag_speed, S.drag_clamp and s64_zero or nil, S.drag_clamp and s64_fifty or nil)
		_, S.u64_v = ImGui.DragScalar("drag u64", ImGuiDataType.U64, S.u64_v, drag_speed, S.drag_clamp and u64_zero or nil, S.drag_clamp and u64_fifty or nil)
		_, S.f32_v = ImGui.DragScalar("drag float", ImGuiDataType.Float, S.f32_v, 0.005, f32_zero, f32_one, "%f")
		_, S.f32_v = ImGui.DragScalar("drag float log", ImGuiDataType.Float, S.f32_v, 0.005, f32_zero, f32_one, "%f", ImGuiSliderFlags.Logarithmic)
		_, S.f64_v = ImGui.DragScalar("drag double", ImGuiDataType.Double, S.f64_v, 0.0005, f64_zero, nil, "%.10f grams")
		_, S.f64_v = ImGui.DragScalar("drag double log", ImGuiDataType.Double, S.f64_v, 0.0005, f64_zero, f64_one, "0 < %.10f < 1", ImGuiSliderFlags.Logarithmic)

		ImGui.SeparatorText("Sliders")
		_, S.s8_v = ImGui.SliderScalar("slider s8 full", ImGuiDataType.S8, S.s8_v, s8_min, s8_max, "%d")
		_, S.u8_v = ImGui.SliderScalar("slider u8 full", ImGuiDataType.U8, S.u8_v, u8_min, u8_max, "%u")
		_, S.s16_v = ImGui.SliderScalar("slider s16 full", ImGuiDataType.S16, S.s16_v, s16_min, s16_max, "%d")
		_, S.u16_v = ImGui.SliderScalar("slider u16 full", ImGuiDataType.U16, S.u16_v, u16_min, u16_max, "%u")
		_, S.s32_v = ImGui.SliderScalar("slider s32 low", ImGuiDataType.S32, S.s32_v, s32_zero, s32_fifty, "%d")
		_, S.s32_v = ImGui.SliderScalar("slider s32 high", ImGuiDataType.S32, S.s32_v, s32_hi_a, s32_hi_b, "%d")
		_, S.s32_v = ImGui.SliderScalar("slider s32 full", ImGuiDataType.S32, S.s32_v, s32_min, s32_max, "%d")
		_, S.s32_v = ImGui.SliderScalar("slider s32 hex", ImGuiDataType.S32, S.s32_v, s32_zero, s32_fifty, "0x%04X")
		_, S.u32_v = ImGui.SliderScalar("slider u32 low", ImGuiDataType.U32, S.u32_v, u32_zero, u32_fifty, "%u")
		_, S.u32_v = ImGui.SliderScalar("slider u32 high", ImGuiDataType.U32, S.u32_v, u32_hi_a, u32_hi_b, "%u")
		_, S.u32_v = ImGui.SliderScalar("slider u32 full", ImGuiDataType.U32, S.u32_v, u32_min, u32_max, "%u")
		_, S.s64_v = ImGui.SliderScalar("slider s64 low", ImGuiDataType.S64, S.s64_v, s64_zero, s64_fifty, "%lld")
		_, S.s64_v = ImGui.SliderScalar("slider s64 high", ImGuiDataType.S64, S.s64_v, s64_hi_a, s64_hi_b, "%lld")
		_, S.s64_v = ImGui.SliderScalar("slider s64 full", ImGuiDataType.S64, S.s64_v, s64_min, s64_max, "%lld")
		_, S.u64_v = ImGui.SliderScalar("slider u64 low", ImGuiDataType.U64, S.u64_v, u64_zero, u64_fifty, "%llu ms")
		_, S.u64_v = ImGui.SliderScalar("slider u64 high", ImGuiDataType.U64, S.u64_v, u64_hi_a, u64_hi_b, "%llu ms")
		_, S.u64_v = ImGui.SliderScalar("slider u64 full", ImGuiDataType.U64, S.u64_v, u64_min, u64_max, "%llu ms")
		_, S.f32_v = ImGui.SliderScalar("slider float low", ImGuiDataType.Float, S.f32_v, f32_zero, f32_one)
		_, S.f32_v = ImGui.SliderScalar("slider float low log", ImGuiDataType.Float, S.f32_v, f32_zero, f32_one, "%.10f", ImGuiSliderFlags.Logarithmic)
		_, S.f32_v = ImGui.SliderScalar("slider float high", ImGuiDataType.Float, S.f32_v, f32_lo_a, f32_hi_a, "%e")
		_, S.f64_v = ImGui.SliderScalar("slider double low", ImGuiDataType.Double, S.f64_v, f64_zero, f64_one, "%.10f grams")
		_, S.f64_v = ImGui.SliderScalar("slider double low log", ImGuiDataType.Double, S.f64_v, f64_zero, f64_one, "%.10f", ImGuiSliderFlags.Logarithmic)
		_, S.f64_v = ImGui.SliderScalar("slider double high", ImGuiDataType.Double, S.f64_v, f64_lo_a, f64_hi_a, "%e grams")

		ImGui.SeparatorText("Sliders (reverse)")
		_, S.s8_v = ImGui.SliderScalar("slider s8 reverse", ImGuiDataType.S8, S.s8_v, s8_max, s8_min, "%d")
		_, S.u8_v = ImGui.SliderScalar("slider u8 reverse", ImGuiDataType.U8, S.u8_v, u8_max, u8_min, "%u")
		_, S.s32_v = ImGui.SliderScalar("slider s32 reverse", ImGuiDataType.S32, S.s32_v, s32_fifty, s32_zero, "%d")
		_, S.u32_v = ImGui.SliderScalar("slider u32 reverse", ImGuiDataType.U32, S.u32_v, u32_fifty, u32_zero, "%u")
		_, S.s64_v = ImGui.SliderScalar("slider s64 reverse", ImGuiDataType.S64, S.s64_v, s64_fifty, s64_zero, "%lld")
		_, S.u64_v = ImGui.SliderScalar("slider u64 reverse", ImGuiDataType.U64, S.u64_v, u64_fifty, u64_zero, "%llu ms")

		ImGui.SeparatorText("Inputs")
		_, S.inputs_step = ImGui.Checkbox("Show step buttons", S.inputs_step)
		_, S.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", S.flags, ImGuiInputTextFlags.ReadOnly)
		_, S.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ParseEmptyRefVal", S.flags, ImGuiInputTextFlags.ParseEmptyRefVal)
		_, S.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_DisplayEmptyRefVal", S.flags, ImGuiInputTextFlags.DisplayEmptyRefVal)
		_, S.s8_v = ImGui.InputScalar("input s8", ImGuiDataType.S8, S.s8_v, S.inputs_step and s8_one or nil, nil, "%d", S.flags)
		_, S.u8_v = ImGui.InputScalar("input u8", ImGuiDataType.U8, S.u8_v, S.inputs_step and u8_one or nil, nil, "%u", S.flags)
		_, S.s16_v = ImGui.InputScalar("input s16", ImGuiDataType.S16, S.s16_v, S.inputs_step and s16_one or nil, nil, "%d", S.flags)
		_, S.u16_v = ImGui.InputScalar("input u16", ImGuiDataType.U16, S.u16_v, S.inputs_step and u16_one or nil, nil, "%u", S.flags)
		_, S.s32_v = ImGui.InputScalar("input s32", ImGuiDataType.S32, S.s32_v, S.inputs_step and s32_one or nil, nil, "%d", S.flags)
		_, S.s32_v = ImGui.InputScalar("input s32 hex", ImGuiDataType.S32, S.s32_v, S.inputs_step and s32_one or nil, nil, "%04X", S.flags)
		_, S.u32_v = ImGui.InputScalar("input u32", ImGuiDataType.U32, S.u32_v, S.inputs_step and u32_one or nil, nil, "%u", S.flags)
		_, S.u32_v = ImGui.InputScalar("input u32 hex", ImGuiDataType.U32, S.u32_v, S.inputs_step and u32_one or nil, nil, "%08X", S.flags)
		_, S.s64_v = ImGui.InputScalar("input s64", ImGuiDataType.S64, S.s64_v, S.inputs_step and s64_one or nil, nil, nil, S.flags)
		_, S.u64_v = ImGui.InputScalar("input u64", ImGuiDataType.U64, S.u64_v, S.inputs_step and u64_one or nil, nil, nil, S.flags)
		_, S.f32_v = ImGui.InputScalar("input float", ImGuiDataType.Float, S.f32_v, S.inputs_step and f32_one or nil, nil, nil, S.flags)
		_, S.f64_v = ImGui.InputScalar("input double", ImGuiDataType.Double, S.f64_v, S.inputs_step and f64_one or nil, nil, nil, S.flags)

		ImGui.TreePop()
	end
end

function Demo.DemoWindowWidgetsDisableBlocks(demo_data)
	if ImGui.TreeNode("Disable Blocks") then
		_, demo_data.DisableSections = ImGui.Checkbox("Disable entire section above", demo_data.DisableSections)
		ImGui.SameLine(); Demo.HelpMarker("Demonstrate using BeginDisabled()/EndDisabled() across other sections.")
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsDragAndDrop = {
	col1 = { 1.0, 0.0, 0.2 },
	col2 = { 0.4, 0.7, 0.0, 0.5 },
	mode = 0,
	names = { "Bobby", "Beatrice", "Betty", "Brianna", "Barry", "Bernard", "Bibi", "Blaine", "Bryn" },
	item_names = { "Item One", "Item Two", "Item Three", "Item Four", "Item Five" },
	col4 = { 1.0, 0.0, 0.2, 1.0 },
}

function Demo.DemoWindowWidgetsDragAndDrop()
	if ImGui.TreeNode("Drag and Drop") then
		local S = S_DemoWindowWidgetsDragAndDrop

		if ImGui.TreeNode("Drag and drop in standard widgets") then
			Demo.HelpMarker("You can drag from the color squares.")
			ImGui.ColorEdit3("color 1", S.col1)
			ImGui.ColorEdit4("color 2", S.col2)
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Drag and drop to copy/swap items") then
			local Mode_Copy, Mode_Move, Mode_Swap = 0, 1, 2
			if ImGui.RadioButton("Copy", S.mode == Mode_Copy) then S.mode = Mode_Copy end; ImGui.SameLine()
			if ImGui.RadioButton("Move", S.mode == Mode_Move) then S.mode = Mode_Move end; ImGui.SameLine()
			if ImGui.RadioButton("Swap", S.mode == Mode_Swap) then S.mode = Mode_Swap end

			local names = S.names
			local sz = ImGui.GetFrameHeight() * 3.0
			for n = 0, #names - 1 do
				ImGui.PushID(n)
				if n % 3 ~= 0 then
					ImGui.SameLine()
				end
				ImGui.Button(names[n + 1], ImVec2(sz, sz))

				if ImGui.BeginDragDropSource(ImGuiDragDropFlags.None) then
					ImGui.SetDragDropPayload("DND_DEMO_CELL", n, 4)

					if S.mode == Mode_Copy then ImGui.Text("Copy %s", names[n + 1]) end
					if S.mode == Mode_Move then ImGui.Text("Move %s", names[n + 1]) end
					if S.mode == Mode_Swap then ImGui.Text("Swap %s", names[n + 1]) end
					ImGui.EndDragDropSource()
				end
				if ImGui.BeginDragDropTarget() then
					local payload = ImGui.AcceptDragDropPayload("DND_DEMO_CELL")
					if payload then
						assert(payload.DataSize == 4)
						local payload_n = payload.Data
						if S.mode == Mode_Copy then
							names[n + 1] = names[payload_n + 1]
						end
						if S.mode == Mode_Move then
							names[n + 1] = names[payload_n + 1]
							names[payload_n + 1] = ""
						end
						if S.mode == Mode_Swap then
							local tmp = names[n + 1]
							names[n + 1] = names[payload_n + 1]
							names[payload_n + 1] = tmp
						end
					end
					ImGui.EndDragDropTarget()
				end
				ImGui.PopID()
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Drag to reorder items (simple)") then
			ImGui.PushItemFlag(ImGuiItemFlags.AllowDuplicateId, true)

			Demo.HelpMarker(
				"We don't use the drag and drop api at all here! " ..
				"Instead we query when the item is held but not hovered, and order items accordingly.")
			local item_names = S.item_names
			for n = 0, #item_names - 1 do
				local item = item_names[n + 1]
				ImGui.Selectable(item)

				if ImGui.IsItemActive() and not ImGui.IsItemHovered() then
					local n_next = n + (ImGui.GetMouseDragDelta(0).y < 0.0 and -1 or 1)
					if n_next >= 0 and n_next < #item_names then
						item_names[n + 1] = item_names[n_next + 1]
						item_names[n_next + 1] = item
						ImGui.ResetMouseDragDelta()
					end
				end
			end

			ImGui.PopItemFlag()
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Tooltip at target location") then
			for n = 0, 1 do
				ImGui.Button(n == 1 and "drop here##1" or "drop here##0")
				if ImGui.BeginDragDropTarget() then
					local drop_target_flags = bit32.bor(ImGuiDragDropFlags.AcceptBeforeDelivery, ImGuiDragDropFlags.AcceptNoPreviewTooltip)
					if ImGui.AcceptDragDropPayload("_COL4F", drop_target_flags) then
						ImGui.SetMouseCursor(ImGuiMouseCursor.NotAllowed)
						ImGui.SetTooltip("Cannot drop here!")
					end
					ImGui.EndDragDropTarget()
				end

				if n == 0 then
					ImGui.ColorButton("drag me", ImVec4(table.unpack(S.col4, 1, 4)))
				end
			end
			ImGui.TreePop()
		end

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsDragsAndSliders = {
	flags = ImGuiSliderFlags.None,
	drag_f = 0.5,
	drag_f4 = { 0.0, 0.0, 0.0, 0.0 },
	drag_i = 50,
	slider_f = 0.5,
	slider_f4 = { 0.0, 0.0, 0.0, 0.0 },
	slider_i = 50,
}

function Demo.DemoWindowWidgetsDragsAndSliders()
	if ImGui.TreeNode("Drag/Slider Flags") then
		local S = S_DemoWindowWidgetsDragsAndSliders

		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_AlwaysClamp", S.flags, ImGuiSliderFlags.AlwaysClamp)
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ClampOnInput", S.flags, ImGuiSliderFlags.ClampOnInput)
		ImGui.SameLine(); Demo.HelpMarker("Clamp value to min/max bounds when input manually with Ctrl+Click. By default Ctrl+Click allows going out of bounds.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ClampZeroRange", S.flags, ImGuiSliderFlags.ClampZeroRange)
		ImGui.SameLine(); Demo.HelpMarker("Clamp even if min==max==0.0f. Otherwise DragXXX functions don't clamp.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_Logarithmic", S.flags, ImGuiSliderFlags.Logarithmic)
		ImGui.SameLine(); Demo.HelpMarker("Enable logarithmic editing (more precision for small values).")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_NoRoundToFormat", S.flags, ImGuiSliderFlags.NoRoundToFormat)
		ImGui.SameLine(); Demo.HelpMarker("Disable rounding underlying value to match precision of the format string (e.g. %.3f values are rounded to those 3 digits).")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_NoInput", S.flags, ImGuiSliderFlags.NoInput)
		ImGui.SameLine(); Demo.HelpMarker("Disable Ctrl+Click or Enter key allowing to input text directly into the widget.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_NoSpeedTweaks", S.flags, ImGuiSliderFlags.NoSpeedTweaks)
		ImGui.SameLine(); Demo.HelpMarker("Disable keyboard modifiers altering tweak speed. Useful if you want to alter tweak speed yourself based on your own logic.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_WrapAround", S.flags, ImGuiSliderFlags.WrapAround)
		ImGui.SameLine(); Demo.HelpMarker("Enable wrapping around from max to min and from min to max (only supported by DragXXX() functions)")
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ColorMarkers", S.flags, ImGuiSliderFlags.ColorMarkers)

		ImGui.Text("Underlying float value: %f", S.drag_f)
		_, S.drag_f = ImGui.DragFloat("DragFloat (0 -> 1)", S.drag_f, 0.005, 0.0, 1.0, "%.3f", S.flags)
		_, S.drag_f = ImGui.DragFloat("DragFloat (0 -> +inf)", S.drag_f, 0.005, 0.0, Base.FLT_MAX, "%.3f", S.flags)
		_, S.drag_f = ImGui.DragFloat("DragFloat (-inf -> 1)", S.drag_f, 0.005, -Base.FLT_MAX, 1.0, "%.3f", S.flags)
		_, S.drag_f = ImGui.DragFloat("DragFloat (-inf -> +inf)", S.drag_f, 0.005, -Base.FLT_MAX, Base.FLT_MAX, "%.3f", S.flags)
		_, S.drag_i = ImGui.DragInt("DragInt (0 -> 100)", S.drag_i, 0.5, 0, 100, "%d", S.flags)
		ImGui.DragFloat4("DragFloat4 (0 -> 1)", S.drag_f4, 0.005, 0.0, 1.0, "%.3f", S.flags)

		local flags_for_sliders = bit32.band(S.flags, bit32.bnot(ImGuiSliderFlags.WrapAround))
		ImGui.Text("Underlying float value: %f", S.slider_f)
		_, S.slider_f = ImGui.SliderFloat("SliderFloat (0 -> 1)", S.slider_f, 0.0, 1.0, "%.3f", flags_for_sliders)
		_, S.slider_i = ImGui.SliderInt("SliderInt (0 -> 100)", S.slider_i, 0, 100, "%d", flags_for_sliders)
		ImGui.SliderFloat4("SliderFloat4 (0 -> 1)", S.slider_f4, 0.0, 1.0, "%.3f", flags_for_sliders)

		ImGui.TreePop()
	end
end

return true
