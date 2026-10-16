--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2 = Base.ImVec2
local ImMax = Base.ImMax
local ImFloor, ImTrunc = Base.ImFloor, Base.ImTrunc
local ImHashStr = Base.ImHashStr
local ImTruncToInt = Base.ImTruncToInt
local FLT_MAX = Base.FLT_MAX
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiDragDropFlags = Enums.ImGuiDragDropFlags
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiCond = Enums.ImGuiCond
local ImGuiCol = Enums.ImGuiCol
local ImGuiLogFlags = Enums.ImGuiLogFlags
local ImGuiViewportFlags = Enums.ImGuiViewportFlags
local ImGuiPlatformIO = Structs.ImGuiPlatformIO

local IM_NEWLINE = "\n"

function ImGui.IsDragDropActive()
	local g = ImGui.GImGui
	return g.DragDropActive
end

function ImGui.ClearDragDrop()
	local g = ImGui.GImGui
	if g.DragDropActive then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventActiveId) then
			ImGui.DebugLog("[dragdrop] ClearDragDrop()\n")
		end
	end
	g.DragDropActive = false
	g.DragDropPayload:Clear()
	g.DragDropAcceptFlagsCurr = ImGuiDragDropFlags.None
	g.DragDropAcceptIdPrev = 0
	g.DragDropAcceptIdCurr = 0
	g.DragDropAcceptIdCurrRectSurface = FLT_MAX
	g.DragDropAcceptFrameCount = -1

	g.DragDropPayloadBufHeap:clear()
end

function ImGui.BeginTooltipHidden()
	local g = ImGui.GImGui
	local ret = ImGui.Begin(
		"##Tooltip_Hidden",
		nil,
		bit32.bor(
			ImGuiWindowFlags.Tooltip,
			ImGuiWindowFlags.NoInputs,
			ImGuiWindowFlags.NoTitleBar,
			ImGuiWindowFlags.NoMove,
			ImGuiWindowFlags.NoResize,
			ImGuiWindowFlags.NoSavedSettings,
			ImGuiWindowFlags.AlwaysAutoResize
		)
	)
	ImGui.SetWindowHiddenAndSkipItemsForCurrentFrame(g.CurrentWindow)
	return ret
end

function ImGui.BeginDragDropSource(flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local mouse_button = ImGuiMouseButton.Left

	local source_drag_active = false
	local source_id = 0
	local source_parent_id = 0
	if bit32.band(flags, ImGuiDragDropFlags.SourceExtern) == 0 then
		source_id = g.LastItemData.ID
		if source_id ~= 0 then
			if g.ActiveId ~= source_id then
				return false
			end
			if g.ActiveIdMouseButton ~= -1 then
				mouse_button = g.ActiveIdMouseButton
			end
			if g.IO.MouseDown[mouse_button + 1] == false or window.SkipItems then
				return false
			end
			g.ActiveIdAllowOverlap = false
		else
			if g.IO.MouseDown[mouse_button + 1] == false or window.SkipItems then
				return false
			end
			if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) == 0 and (g.ActiveId == 0 or g.ActiveIdWindow ~= window) then
				return false
			end

			if not bit32.btest(flags, ImGuiDragDropFlags.SourceAllowNullID) then
				assert(false)
				return false
			end

			source_id = window:GetIDFromRectangle(g.LastItemData.Rect)
			g.LastItemData.ID = source_id
			ImGui.KeepAliveID(source_id)
			local is_hovered = ImGui.ItemHoverable(g.LastItemData.Rect, source_id, g.LastItemData.ItemFlags)
			if is_hovered and g.IO.MouseClicked[mouse_button + 1] then
				ImGui.SetActiveID(source_id, window)
				ImGui.FocusWindow(window)
			end
			if g.ActiveId == source_id then
				g.ActiveIdAllowOverlap = is_hovered
			end
		end
		if g.ActiveId ~= source_id then
			return false
		end
		source_parent_id = window.IDStack:back()
		source_drag_active = ImGui.IsMouseDragging(mouse_button)

		ImGui.SetActiveIdUsingAllKeyboardKeys()
	else
		window = nil
		source_id = ImHashStr("#SourceExtern")
		source_drag_active = true
		mouse_button = g.IO.MouseDown[1] and 0 or -1
		ImGui.KeepAliveID(source_id)
		ImGui.SetActiveID(source_id, nil)
	end

	assert(g.DragDropWithinTarget == false)
	if not source_drag_active then
		return false
	end

	if not g.DragDropActive then
		assert(source_id ~= 0)
		ImGui.ClearDragDrop()
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventActiveId) then
			ImGui.DebugLog(
				"[dragdrop] BeginDragDropSource() DragDropActive = true, source_id = 0x%08X%s\n",
				source_id,
				bit32.btest(flags, ImGuiDragDropFlags.SourceExtern) and " (EXTERN)" or ""
			)
		end
		local payload = g.DragDropPayload
		payload.SourceId = source_id
		payload.SourceParentId = source_parent_id
		g.DragDropActive = true
		g.DragDropSourceFlags = flags
		g.DragDropMouseButton = mouse_button
		if payload.SourceId == g.ActiveId then
			g.ActiveIdNoClearOnFocusLoss = true
		end
	end
	g.DragDropSourceFrameCount = g.FrameCount
	g.DragDropWithinSource = true

	if not bit32.btest(flags, ImGuiDragDropFlags.SourceNoPreviewTooltip) then
		local ret
		if g.DragDropAcceptIdPrev ~= 0 and bit32.btest(g.DragDropAcceptFlagsPrev, ImGuiDragDropFlags.AcceptNoPreviewTooltip) then
			ret = ImGui.BeginTooltipHidden()
		else
			ret = ImGui.BeginTooltip()
		end
		assert(ret)
	end

	if not bit32.btest(flags, ImGuiDragDropFlags.SourceNoDisableHover) and not bit32.btest(flags, ImGuiDragDropFlags.SourceExtern) then
		g.LastItemData.StatusFlags = bit32.band(g.LastItemData.StatusFlags, bit32.bnot(ImGuiItemStatusFlags.HoveredRect))
	end

	return true
end

function ImGui.EndDragDropSource()
	local g = ImGui.GImGui
	assert(g.DragDropActive)
	assert(g.DragDropWithinSource, "Not after a BeginDragDropSource()?")

	if not bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceNoPreviewTooltip) then
		ImGui.EndTooltip()
	end

	if g.DragDropPayload.DataFrameCount == -1 then
		ImGui.ClearDragDrop()
	end
	g.DragDropWithinSource = false
end

function ImGui.SetDragDropPayload(type_str, data, data_size, cond)
	if cond == nil then
		cond = 0
	end
	if data_size == nil then
		data_size = if type(data) == "string" then #data else 0
	end
	local g = ImGui.GImGui
	local payload = g.DragDropPayload
	if cond == 0 then
		cond = ImGuiCond.Always
	end

	assert(type_str ~= nil)
	assert(#type_str < 33, "Payload type can be at most 32 characters long")
	assert(data ~= nil or data_size == 0)
	assert(cond == ImGuiCond.Always or cond == ImGuiCond.Once)
	assert(payload.SourceId ~= 0)

	if cond == ImGuiCond.Always or payload.DataFrameCount == -1 then
		payload.DataType = string.sub(type_str, 1, 32)
		g.DragDropPayloadBufHeap:resize(0)
		payload.Data = data
		payload.DataSize = data_size
	end
	payload.DataFrameCount = g.FrameCount

	return (g.DragDropAcceptFrameCount == g.FrameCount) or (g.DragDropAcceptFrameCount == g.FrameCount - 1)
end

function ImGui.BeginDragDropTargetCustom(bb, id)
	local g = ImGui.GImGui
	if not g.DragDropActive then
		return false
	end

	local window = g.CurrentWindow
	local hovered_window = g.HoveredWindowUnderMovingWindow
	if hovered_window == nil or window.RootWindow ~= hovered_window.RootWindow then
		return false
	end
	assert(id ~= 0)
	if not ImGui.IsMouseHoveringRect(bb.Min, bb.Max) or (id == g.DragDropPayload.SourceId) then
		return false
	end
	if window.SkipItems then
		return false
	end

	assert(g.DragDropWithinTarget == false and g.DragDropWithinSource == false)
	g.DragDropTargetRect = bb
	g.DragDropTargetClipRect = window.ClipRect
	g.DragDropTargetId = id
	g.DragDropTargetFullViewport = 0
	g.DragDropWithinTarget = true
	return true
end

function ImGui.BeginDragDropTargetViewport(viewport, p_bb)
	local g = ImGui.GImGui
	if not g.DragDropActive then
		return false
	end

	local bb = if p_bb then p_bb else viewport:GetWorkRect()
	local id = viewport.ID
	if not ImGui.IsMouseHoveringRect(bb.Min, bb.Max, false) or (id == g.DragDropPayload.SourceId) then
		return false
	end

	assert(g.DragDropWithinTarget == false and g.DragDropWithinSource == false)
	g.DragDropTargetRect = bb
	g.DragDropTargetClipRect = bb
	g.DragDropTargetId = id
	g.DragDropTargetFullViewport = id
	g.DragDropWithinTarget = true
	return true
end

function ImGui.BeginDragDropTarget()
	local g = ImGui.GImGui
	if not g.DragDropActive then
		return false
	end

	local window = g.CurrentWindow
	if not bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) then
		return false
	end
	local hovered_window = g.HoveredWindowUnderMovingWindow
	if hovered_window == nil or window.RootWindow ~= hovered_window.RootWindow or window.SkipItems then
		return false
	end

	local display_rect = if bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasDisplayRect)
		then g.LastItemData.DisplayRect
		else g.LastItemData.Rect
	local id = g.LastItemData.ID
	if id == 0 then
		id = window:GetIDFromRectangle(display_rect)
		ImGui.KeepAliveID(id)
	end
	if g.DragDropPayload.SourceId == id then
		return false
	end

	assert(g.DragDropWithinTarget == false and g.DragDropWithinSource == false)
	g.DragDropTargetRect = display_rect
	g.DragDropTargetClipRect = if bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasClipRect)
		then g.LastItemData.ClipRect
		else window.ClipRect
	g.DragDropTargetId = id
	g.DragDropWithinTarget = true
	return true
end

function ImGui.IsDragDropPayloadBeingAccepted()
	local g = ImGui.GImGui
	return g.DragDropActive and g.DragDropAcceptIdPrev ~= 0
end

function ImGui.AcceptDragDropPayload(type, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local payload = g.DragDropPayload
	assert(g.DragDropActive)
	assert(payload.DataFrameCount ~= -1)
	if type ~= nil and not payload:IsDataType(type) then
		return nil
	end

	local was_accepted_previously = (g.DragDropAcceptIdPrev == g.DragDropTargetId)
	local r = g.DragDropTargetRect
	local r_surface = r:GetWidth() * r:GetHeight()
	if r_surface > g.DragDropAcceptIdCurrRectSurface then
		return nil
	end

	g.DragDropAcceptFlagsCurr = flags
	g.DragDropAcceptIdCurr = g.DragDropTargetId
	g.DragDropAcceptIdCurrRectSurface = r_surface

	payload.Preview = was_accepted_previously
	flags = bit32.bor(flags, bit32.band(g.DragDropSourceFlags, ImGuiDragDropFlags.AcceptNoDrawDefaultRect))
	local draw_target_rect = payload.Preview and not bit32.btest(flags, ImGuiDragDropFlags.AcceptNoDrawDefaultRect)
	if draw_target_rect and g.DragDropTargetFullViewport ~= 0 then
		ImGui.RenderDragDropTargetRectForViewport(g.DragDropTargetFullViewport, g.DragDropTargetRect)
	elseif draw_target_rect then
		ImGui.RenderDragDropTargetRectForItem(r)
	end

	g.DragDropAcceptFrameCount = g.FrameCount
	if bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceExtern) and g.DragDropMouseButton == -1 then
		payload.Delivery = was_accepted_previously and (g.DragDropSourceFrameCount < g.FrameCount)
	else
		payload.Delivery = was_accepted_previously and not ImGui.IsMouseDown(g.DragDropMouseButton)
	end
	if not payload.Delivery and not bit32.btest(flags, ImGuiDragDropFlags.AcceptBeforeDelivery) then
		return nil
	end

	if payload.Delivery then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventActiveId) then
			ImGui.DebugLog("[dragdrop] AcceptDragDropPayload(): 0x%08X: payload delivery\n", g.DragDropTargetId)
		end
	end
	return payload
end

function ImGui.RenderDragDropTargetRectForItem(bb)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local bb_display = bb:ClippedWith(g.DragDropTargetClipRect)
	bb_display = bb_display:Expanded(g.Style.DragDropTargetPadding)
	local push_clip_rect = not window.ClipRect:Contains(bb_display)
	if push_clip_rect then
		window.DrawList:PushClipRectFullScreen()
	end
	ImGui.RenderDragDropTargetRectEx(window.DrawList, bb_display, g.Style.DragDropTargetRounding)
	if push_clip_rect then
		window.DrawList:PopClipRect()
	end
end

function ImGui.RenderDragDropTargetRectForViewport(viewport_id, bb)
	assert(viewport_id ~= 0)
	local g = ImGui.GImGui
	local viewport = g.Viewports[1]
	local bb_padded = bb:Expanded(-g.Style.DragDropTargetPadding)
	ImGui.RenderDragDropTargetRectEx(ImGui.GetForegroundDrawList(viewport), bb_padded, g.Style.DragDropTargetRounding)
end

function ImGui.RenderDragDropTargetRectEx(draw_list, bb, rounding)
	local g = ImGui.GImGui
	draw_list:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.DragDropTargetBg), rounding, 0)
	draw_list:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.DragDropTarget), rounding, g.Style.DragDropTargetBorderSize)
end

function ImGui.GetDragDropPayload()
	local g = ImGui.GImGui
	return if g.DragDropActive and g.DragDropPayload.DataFrameCount ~= -1 then g.DragDropPayload else nil
end

function ImGui.EndDragDropTarget()
	local g = ImGui.GImGui
	assert(g.DragDropActive)
	assert(g.DragDropWithinTarget)
	g.DragDropWithinTarget = false

	if g.DragDropPayload.Delivery then
		ImGui.ClearDragDrop()
	end
end

local LogStdout = {}
local TTYPending = ""

local function TTYWrite(s)
	local pending = TTYPending .. s
	local start = 1
	while true do
		local nl = string.find(pending, "\n", start, true)
		if nl == nil then
			break
		end
		print(string.sub(pending, start, nl - 1))
		start = nl + 1
	end
	TTYPending = string.sub(pending, start)
end

local function TTYFlush()
	if TTYPending ~= "" then
		print(TTYPending)
		TTYPending = ""
	end
end

local function LogTextV(g, fmt, ...)
	local s = if select("#", ...) == 0 then fmt else Base.ImFormatString(fmt, ...)
	if g.LogFile then
		g.LogBuffer:clear()
		g.LogBuffer:append(s)
		if g.LogFile == LogStdout then
			TTYWrite(s)
		else
			Base.ImFileWrite(s, 1, #s, g.LogFile)
		end
	else
		g.LogBuffer:append(s)
	end
end

function ImGui.LogText(fmt, ...)
	local g = ImGui.GImGui
	if not g.LogEnabled then
		return
	end

	LogTextV(g, fmt, ...)
end

function ImGui.LogTextV(fmt, ...)
	local g = ImGui.GImGui
	if not g.LogEnabled then
		return
	end

	LogTextV(g, fmt, ...)
end

function ImGui.LogRenderedText(ref_pos, text, text_end)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local prefix = g.LogNextPrefix
	local suffix = g.LogNextSuffix
	g.LogNextPrefix = nil
	g.LogNextSuffix = nil

	if text_end == nil then
		text_end = ImGui.FindRenderedTextEnd(text, text_end)
	end

	local log_new_line = ref_pos ~= nil and (ref_pos.y > g.LogLinePosY + ImMax(g.Style.FramePadding.y, g.Style.ItemSpacing.y) + 1)
	if ref_pos ~= nil then
		g.LogLinePosY = ref_pos.y
	end
	if log_new_line then
		ImGui.LogText(IM_NEWLINE)
		g.LogLineFirstItem = true
	end

	if prefix then
		ImGui.LogRenderedText(ref_pos, prefix, #prefix + 1)
	end

	if g.LogDepthRef > window.DC.TreeDepth then
		g.LogDepthRef = window.DC.TreeDepth
	end
	local tree_depth = window.DC.TreeDepth - g.LogDepthRef

	local text_remaining = 1
	while true do
		local line_start = text_remaining
		local line_end = Base.ImStreolRange(text, line_start, text_end)
		local is_last_line = (line_end == text_end)
		if line_start ~= line_end or not is_last_line then
			local indentation = if g.LogLineFirstItem then tree_depth * 4 else 1
			ImGui.LogText(string.rep(" ", indentation) .. string.sub(text, line_start, line_end - 1))
			g.LogLineFirstItem = false
			if string.byte(text, line_end) == 10 then
				ImGui.LogText(IM_NEWLINE)
				g.LogLineFirstItem = true
			end
		end
		if is_last_line then
			break
		end
		text_remaining = line_end + 1
	end

	if suffix then
		ImGui.LogRenderedText(ref_pos, suffix, #suffix + 1)
	end
end

function ImGui.LogBegin(flags, auto_open_depth)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(g.LogEnabled == false)
	assert(g.LogFile == nil and g.LogBuffer:empty())
	assert(Base.ImIsPowerOfTwo(bit32.band(flags, ImGuiLogFlags.OutputMask_)))

	g.LogEnabled = true
	g.ItemUnclipByLog = true
	g.LogFlags = flags
	g.LogWindow = window
	g.LogNextPrefix = nil
	g.LogNextSuffix = nil
	g.LogDepthRef = window.DC.TreeDepth
	g.LogDepthToExpand = if auto_open_depth >= 0 then auto_open_depth else g.LogDepthToExpandDefault
	g.LogLinePosY = FLT_MAX
	g.LogLineFirstItem = true
end

function ImGui.LogSetNextTextDecoration(prefix, suffix)
	local g = ImGui.GImGui
	g.LogNextPrefix = prefix
	g.LogNextSuffix = suffix
end

function ImGui.LogToTTY(auto_open_depth)
	if auto_open_depth == nil then
		auto_open_depth = -1
	end
	local g = ImGui.GImGui
	if g.LogEnabled then
		return
	end
	ImGui.LogBegin(ImGuiLogFlags.OutputTTY, auto_open_depth)
	g.LogFile = LogStdout
end

function ImGui.LogToFile(auto_open_depth, filename)
	if auto_open_depth == nil then
		auto_open_depth = -1
	end
	local g = ImGui.GImGui
	if g.LogEnabled then
		return
	end

	if not filename then
		filename = g.IO.LogFilename
	end
	if not filename or filename == "" then
		return
	end
	local f = Base.ImFileOpen(filename, "ab")
	if not f then
		assert(false)
		return
	end

	ImGui.LogBegin(ImGuiLogFlags.OutputFile, auto_open_depth)
	g.LogFile = f
end

function ImGui.LogToClipboard(auto_open_depth)
	if auto_open_depth == nil then
		auto_open_depth = -1
	end
	local g = ImGui.GImGui
	if g.LogEnabled then
		return
	end
	ImGui.LogBegin(ImGuiLogFlags.OutputClipboard, auto_open_depth)
end

function ImGui.LogToBuffer(auto_open_depth)
	if auto_open_depth == nil then
		auto_open_depth = -1
	end
	local g = ImGui.GImGui
	if g.LogEnabled then
		return
	end
	ImGui.LogBegin(ImGuiLogFlags.OutputBuffer, auto_open_depth)
end

function ImGui.LogFinish()
	local g = ImGui.GImGui
	if not g.LogEnabled then
		return
	end

	ImGui.LogText(IM_NEWLINE)
	local output = bit32.band(g.LogFlags, ImGuiLogFlags.OutputMask_)
	if output == ImGuiLogFlags.OutputTTY then
		TTYFlush()
	elseif output == ImGuiLogFlags.OutputFile then
		Base.ImFileClose(g.LogFile)
	elseif output == ImGuiLogFlags.OutputBuffer then
	elseif output == ImGuiLogFlags.OutputClipboard then
		if not g.LogBuffer:empty() then
			ImGui.SetClipboardText(g.LogBuffer:c_str())
		end
	else
		assert(false)
	end

	g.LogEnabled = false
	g.ItemUnclipByLog = false
	g.LogFlags = ImGuiLogFlags.None
	g.LogFile = nil
	g.LogBuffer:clear()
end

function ImGui.LogButtons()
	local g = ImGui.GImGui

	ImGui.PushID("LogButtons")
	local log_to_tty = ImGui.Button("Log To TTY")
	ImGui.SameLine()
	local log_to_file = ImGui.Button("Log To File")
	ImGui.SameLine()
	local log_to_clipboard = ImGui.Button("Log To Clipboard")
	ImGui.SameLine()
	ImGui.PushItemFlag(ImGuiItemFlags.NoTabStop, true)
	ImGui.SetNextItemWidth(ImGui.CalcTextSize("999").x)
	local _
	_, g.LogDepthToExpandDefault = ImGui.SliderInt("Default Depth", g.LogDepthToExpandDefault, 0, 9, nil)
	ImGui.PopItemFlag()
	ImGui.PopID()

	if log_to_tty then
		ImGui.LogToTTY()
	end
	if log_to_file then
		ImGui.LogToFile()
	end
	if log_to_clipboard then
		ImGui.LogToClipboard()
	end
end

function ImGui.UpdateSettings()
	local g = ImGui.GImGui
	if not g.SettingsLoaded then
		assert(g.SettingsWindows:empty())
		if g.IO.IniFilename then
			ImGui.LoadIniSettingsFromDisk(g.IO.IniFilename)
		end
		g.SettingsLoaded = true
	end

	if g.SettingsDirtyTimer > 0.0 then
		g.SettingsDirtyTimer -= g.IO.DeltaTime
		if g.SettingsDirtyTimer <= 0.0 then
			if g.IO.IniFilename ~= nil then
				ImGui.SaveIniSettingsToDisk(g.IO.IniFilename)
			else
				g.IO.WantSaveIniSettings = true
			end
			g.SettingsDirtyTimer = 0.0
		end
	end
end

function ImGui.MarkIniSettingsDirty(window)
	local g = ImGui.GImGui
	if window == nil then
		if g.SettingsDirtyTimer <= 0.0 then
			g.SettingsDirtyTimer = g.IO.IniSavingRate
		end
		return
	end
	if not bit32.btest(window.Flags, ImGuiWindowFlags.NoSavedSettings) then
		if g.SettingsDirtyTimer <= 0.0 then
			g.SettingsDirtyTimer = g.IO.IniSavingRate
		end
	end
end

function ImGui.AddSettingsHandler(handler)
	local g = ImGui.GImGui
	assert(ImGui.FindSettingsHandler(handler.TypeName) == nil)
	g.SettingsHandlers:push_back(table.clone(handler))
end

function ImGui.RemoveSettingsHandler(type_name)
	local g = ImGui.GImGui
	local handler = ImGui.FindSettingsHandler(type_name)
	if handler then
		g.SettingsHandlers:find_erase(handler)
	end
end

function ImGui.FindSettingsHandler(type_name)
	local g = ImGui.GImGui
	local type_hash = ImHashStr(type_name)
	for n = 1, g.SettingsHandlers.Size do
		local handler = g.SettingsHandlers[n]
		if handler.TypeHash == type_hash then
			return handler
		end
	end
	return nil
end

function ImGui.ClearIniSettings()
	local g = ImGui.GImGui
	g.SettingsIniData:clear()
	for n = 1, g.SettingsHandlers.Size do
		local handler = g.SettingsHandlers[n]
		if handler.ClearAllFn ~= nil then
			handler.ClearAllFn(g, handler)
		end
	end
end

function ImGui.CleanupIniSettings(args)
	local g = ImGui.GImGui
	if args.DiscardAll then
		for n = 1, g.SettingsHandlers.Size do
			local handler = g.SettingsHandlers[n]
			if args.TypeHashFilter == 0 or handler.TypeHash == args.TypeHashFilter then
				if handler.ClearAllFn ~= nil then
					handler.ClearAllFn(g, handler)
				end
			end
		end
	end
	if g.PlatformIO.Platform_SessionDate ~= 0 and args.DiscardOlderThanMonths ~= 0 then
		local discard_older_than_date_p = Structs.ImGuiPackedDate.new(g.PlatformIO.Platform_SessionDate)
		discard_older_than_date_p:SubtractMonths(args.DiscardOlderThanMonths)
		args._DiscardOlderThanDate = discard_older_than_date_p:Unpack()
	end
	for n = 1, g.SettingsHandlers.Size do
		local handler = g.SettingsHandlers[n]
		if args.TypeHashFilter == 0 or handler.TypeHash == args.TypeHashFilter then
			if handler.CleanupFn ~= nil then
				handler.CleanupFn(g, handler, args)
			end
		end
	end
end

function ImGui.LoadIniSettingsFromDisk(ini_filename)
	local file_data, file_data_size = Base.ImFileLoadToMemory(ini_filename, "rb", nil)
	if not file_data then
		return
	end
	if file_data_size > 0 then
		ImGui.LoadIniSettingsFromMemory(file_data, file_data_size)
	end
end

function ImGui.LoadIniSettingsFromMemory(ini_data, ini_size)
	if ini_size == nil then
		ini_size = 0
	end
	local g = ImGui.GImGui
	assert(g.Initialized)

	if ini_size == 0 then
		ini_size = #ini_data
	end
	local buf = string.sub(ini_data, 1, ini_size)
	local buf_end = ini_size + 1
	g.SettingsIniData:clear()
	g.SettingsIniData:append(buf)

	for n = 1, g.SettingsHandlers.Size do
		local handler = g.SettingsHandlers[n]
		if handler.ReadInitFn ~= nil then
			handler.ReadInitFn(g, handler)
		end
	end

	local entry_data = nil
	local entry_handler = nil

	local line = 1
	while line < buf_end do
		local c = string.byte(buf, line)
		while c == 10 or c == 13 do
			line += 1
			c = string.byte(buf, line)
		end
		local line_end = line
		while line_end < buf_end do
			local ce = string.byte(buf, line_end)
			if ce == 10 or ce == 13 then
				break
			end
			line_end += 1
		end
		if c == 59 then
			line = line_end + 1
			continue
		end
		if c == 91 and line_end > line and string.byte(buf, line_end - 1) == 93 then
			local name_end = line_end - 1
			local type_start = line + 1
			local type_end = Base.ImStrchrRange(buf, type_start, name_end, 93)
			local name_start = if type_end then Base.ImStrchrRange(buf, type_end + 1, name_end, 91) else nil
			if type_end and name_start then
				name_start += 1
				entry_handler = ImGui.FindSettingsHandler(string.sub(buf, type_start, type_end - 1))
				if entry_handler then
					entry_data = entry_handler.ReadOpenFn(g, entry_handler, string.sub(buf, name_start, name_end - 1))
				else
					entry_data = nil
				end
			end
		elseif entry_handler ~= nil and entry_data ~= nil then
			entry_handler.ReadLineFn(g, entry_handler, entry_data, string.sub(buf, line, line_end - 1))
		end
		line = line_end + 1
	end
	g.SettingsLoaded = true

	local cleanup_args = Structs.ImGuiSettingsCleanupArgs.new()
	if g.IO.ConfigIniSettingsAutoDiscardMonths > 0 then
		cleanup_args.DiscardOlderThanMonths = g.IO.ConfigIniSettingsAutoDiscardMonths
		ImGui.CleanupIniSettings(cleanup_args)
	end
	for n = 1, g.SettingsHandlers.Size do
		local handler = g.SettingsHandlers[n]
		if handler.ApplyAllFn ~= nil then
			handler.ApplyAllFn(g, handler)
		end
	end
end

function ImGui.SaveIniSettingsToDisk(ini_filename)
	local g = ImGui.GImGui
	g.SettingsDirtyTimer = 0.0
	if not ini_filename then
		return
	end

	local ini_data, ini_data_size = ImGui.SaveIniSettingsToMemory(nil)
	local f = Base.ImFileOpen(ini_filename, "wt")
	if not f then
		return
	end
	Base.ImFileWrite(ini_data, 1, ini_data_size, f)
	Base.ImFileClose(f)
end

function ImGui.SaveIniSettingsToMemory(out_size)
	local g = ImGui.GImGui
	g.SettingsDirtyTimer = 0.0
	g.SettingsIniData:clear()
	for n = 1, g.SettingsHandlers.Size do
		local handler = g.SettingsHandlers[n]
		handler.WriteAllFn(g, handler, g.SettingsIniData)
	end
	return g.SettingsIniData:c_str(), g.SettingsIniData:size()
end

function ImGui.CreateNewWindowSettings(name)
	local g = ImGui.GImGui

	if g.IO.ConfigDebugIniSettings == false then
		name = string.sub(name, Base.ImHashSkipUncontributingPrefix(name))
	end
	local name_len = #name

	local settings = g.SettingsWindows:alloc_chunk(Structs.ImGuiWindowSettings.new())
	settings.ID = ImHashStr(name, name_len)
	settings.Name = name

	return settings
end

function ImGui.FindWindowSettingsByID(id)
	local g = ImGui.GImGui
	local settings = g.SettingsWindows:begin()
	while settings ~= nil do
		if settings.ID == id and not settings.WantDelete then
			return settings
		end
		settings = g.SettingsWindows:next_chunk(settings)
	end
	return nil
end

function ImGui.FindWindowSettingsByWindow(window)
	local g = ImGui.GImGui
	if window.SettingsOffset ~= -1 then
		return g.SettingsWindows:ptr_from_offset(window.SettingsOffset)
	end
	return ImGui.FindWindowSettingsByID(window.ID)
end

function ImGui.ClearWindowSettings(name)
	local window = ImGui.FindWindowByName(name)
	if window ~= nil then
		window.Flags = bit32.bor(window.Flags, ImGuiWindowFlags.NoSavedSettings)
		ImGui.InitOrLoadWindowSettings(window, nil)
	end
	local settings = if window then ImGui.FindWindowSettingsByWindow(window) else ImGui.FindWindowSettingsByID(ImHashStr(name))
	if settings then
		settings.WantDelete = true
	end
end

function ImGui.WindowSettingsHandler_ClearAll(ctx, _handler)
	local g = ctx
	for n = 1, g.Windows.Size do
		g.Windows[n].SettingsOffset = -1
	end
	g.SettingsWindows:clear()
end

function ImGui.WindowSettingsHandler_Cleanup(ctx, _handler, args)
	local g = ctx
	local settings = g.SettingsWindows:begin()
	while settings ~= nil do
		local is_valid = settings.LastUsedDate:IsValid()
		if (args._DiscardOlderThanDate ~= 0 and settings.LastUsedDate:Unpack() < args._DiscardOlderThanDate) or (args.DiscardWhenMissingDate and not is_valid) then
			settings.WantDelete = true
		end
		if args.SetCurrentSessionDateToAll or (args.SetCurrentSessionDateWhenMissingDate and not is_valid) then
			settings.LastUsedDate = g.SessionDate:Copy()
		end
		settings = g.SettingsWindows:next_chunk(settings)
	end
end

function ImGui.WindowSettingsHandler_ReadOpen(_ctx, _handler, name)
	local id = ImHashStr(name)
	local settings = ImGui.FindWindowSettingsByID(id)
	if settings then
		local saved_name = settings.Name
		for k, v in Structs.ImGuiWindowSettings.new() do
			settings[k] = v
		end
		settings.Name = saved_name
	else
		settings = ImGui.CreateNewWindowSettings(name)
	end
	settings.ID = id
	settings.WantApply = true
	return settings
end

local function ToShort(v)
	return (ImTruncToInt(v) + 32768) % 65536 - 32768
end

function ImGui.WindowSettingsHandler_ReadLine(_ctx, _handler, entry, line)
	local settings = entry
	local x, y = Base.ImSscanf(line, "Pos=%i,%i")
	if x ~= nil and y ~= nil then
		settings.Pos = ImVec2(ToShort(x), ToShort(y))
		return
	end
	x, y = Base.ImSscanf(line, "Size=%i,%i")
	if x ~= nil and y ~= nil then
		settings.Size = ImVec2(ToShort(x), ToShort(y))
		return
	end
	local i = Base.ImSscanf(line, "Collapsed=%d")
	if i ~= nil then
		settings.Collapsed = (i ~= 0)
		return
	end
	i = Base.ImSscanf(line, "IsChild=%d")
	if i ~= nil then
		settings.IsChild = (i ~= 0)
		return
	end
	i = Base.ImSscanf(line, "LastUsed=%d")
	if i ~= nil then
		settings.LastUsedDate = Structs.ImGuiPackedDate.new(i)
		return
	end
end

function ImGui.WindowSettingsHandler_ApplyAll(ctx, _handler)
	local g = ctx
	local settings = g.SettingsWindows:begin()
	while settings ~= nil do
		if settings.WantApply then
			local window = ImGui.FindWindowByID(settings.ID)
			if window then
				ImGui.ApplyWindowSettings(window, settings)
			end
			settings.WantApply = false
		end
		settings = g.SettingsWindows:next_chunk(settings)
	end
end

function ImGui.WindowSettingsHandler_WriteAll(ctx, handler, buf)
	local g = ctx
	for n = 1, g.Windows.Size do
		local window = g.Windows[n]
		if bit32.btest(window.Flags, ImGuiWindowFlags.NoSavedSettings) then
			continue
		end

		local settings = ImGui.FindWindowSettingsByWindow(window)
		if not settings then
			settings = ImGui.CreateNewWindowSettings(window.Name)
			settings.LastUsedDate = g.SessionDate:Copy()
			window.SettingsOffset = g.SettingsWindows:offset_from_ptr(settings)
		end
		assert(settings.ID == window.ID)
		settings.Pos = ImVec2(ToShort(window.Pos.x), ToShort(window.Pos.y))
		settings.Size = ImVec2(ToShort(window.SizeFull.x), ToShort(window.SizeFull.y))
		settings.IsChild = bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow)
		settings.Collapsed = window.Collapsed
		settings.WantDelete = false
		settings.LastUsedDate = g.SessionDate:Copy()
	end

	buf:reserve(buf:size() + g.SettingsWindows:size() * 6)
	local settings = g.SettingsWindows:begin()
	while settings ~= nil do
		if not settings.WantDelete then
			local settings_name = settings:GetName()
			buf:appendf("[%s][%s]\n", handler.TypeName, settings_name)
			if settings.IsChild then
				buf:appendf("IsChild=1\n")
				buf:appendf("Size=%d,%d\n", settings.Size.x, settings.Size.y)
			else
				buf:appendf("Pos=%d,%d\n", settings.Pos.x, settings.Pos.y)
				buf:appendf("Size=%d,%d\n", settings.Size.x, settings.Size.y)
				if settings.Collapsed then
					buf:appendf("Collapsed=1\n")
				end
			end
			if g.IO.ConfigIniSettingsSaveLastUsedDate then
				local last_used_date = settings.LastUsedDate:Unpack()
				if last_used_date ~= 0 then
					buf:appendf("LastUsed=%08d\n", last_used_date)
				end
			end
			buf:append("\n")
		end
		settings = g.SettingsWindows:next_chunk(settings)
	end
end

function ImGui.LocalizeRegisterEntries(entries, count)
	local g = ImGui.GImGui
	for n = 0, count - 1 do
		local entry = entries[n + 1]
		g.LocalizationTable[entry.Key + 1] = entry.Text
	end
end

function ImGuiPlatformIO:ClearPlatformHandlers()
	self.Platform_GetClipboardTextFn = nil
	self.Platform_SetClipboardTextFn = nil
	self.Platform_ClipboardUserData = nil
	self.Platform_OpenInShellFn = nil
	self.Platform_OpenInShellUserData = nil
	self.Platform_SetImeDataFn = nil
	self.Platform_ImeUserData = nil
	ImGui.InitializeDefaultPlatformHandlers(self)
end

function ImGuiPlatformIO:ClearRendererHandlers()
	self.Renderer_TextureMaxWidth = 0
	self.Renderer_TextureMaxHeight = 0
	self.Renderer_RenderState = nil
	self.DrawCallback_ResetRenderState = nil
	self.DrawCallback_SetSamplerLinear = nil
	self.DrawCallback_SetSamplerNearest = nil
	self.DrawCallback_SetSamplerFromTex = nil
end

function ImGui.GetMainViewport()
	local g = ImGui.GImGui
	return g.Viewports[1]
end

function ImGui.SetWindowViewport(window, viewport)
	window.Viewport = viewport
end

function ImGui.ScaleWindow(window, scale)
	local origin = window.Viewport.Pos
	window.Pos = ImFloor((window.Pos - origin) * scale + origin)
	window.Size = ImTrunc(window.Size * scale)
	window.SizeFull = ImTrunc(window.SizeFull * scale)
	window.ContentSize = ImTrunc(window.ContentSize * scale)
end

function ImGui.ScaleWindowsInViewport(viewport, scale)
	local g = ImGui.GImGui
	for n = 1, g.Windows.Size do
		local window = g.Windows[n]
		if window.Viewport == viewport then
			ImGui.ScaleWindow(window, scale)
		end
	end
end

function ImGui.UpdateViewportsNewFrame()
	local g = ImGui.GImGui
	assert(g.Viewports.Size == 1)

	local main_viewport = g.Viewports[1]
	main_viewport.Flags = bit32.bor(ImGuiViewportFlags.IsPlatformWindow, ImGuiViewportFlags.OwnedByApp)
	main_viewport.Pos = ImVec2(0.0, 0.0)
	main_viewport.Size = g.IO.DisplaySize
	main_viewport.FramebufferScale = g.IO.DisplayFramebufferScale
	assert(main_viewport.FramebufferScale.x > 0.0 and main_viewport.FramebufferScale.y > 0.0)

	local memory_compact_start_time = if g.GcCompactAll or g.IO.ConfigMemoryCompactTimer < 0.0
		then FLT_MAX
		else g.Time - g.IO.ConfigMemoryCompactTimer
	for v = 1, g.Viewports.Size do
		local viewport = g.Viewports[v]
		viewport.WorkInsetMin = viewport.BuildWorkInsetMin
		viewport.WorkInsetMax = viewport.BuildWorkInsetMax
		viewport.BuildWorkInsetMin = ImVec2(0.0, 0.0)
		viewport.BuildWorkInsetMax = ImVec2(0.0, 0.0)
		viewport:UpdateWorkRect()

		for n = 0, 1 do
			if viewport.BgFgDrawListsLastTimeActive[n + 1] < memory_compact_start_time and viewport.BgFgDrawLists[n + 1] ~= nil then
				viewport.BgFgDrawLists[n + 1] = nil
			end
		end
	end
end

function ImGui.Platform_GetClipboardTextFn_DefaultImpl(ctx)
	local g = ctx
	return if g.ClipboardHandlerData:empty() then nil else g.ClipboardHandlerData[1]
end

function ImGui.Platform_SetClipboardTextFn_DefaultImpl(ctx, text)
	local g = ctx
	g.ClipboardHandlerData:clear()
	g.ClipboardHandlerData:push_back(text)
end

function ImGui.Platform_OpenInShellFn_DefaultImpl(_ctx, path)
	print(path)
	return true
end

function ImGui.Platform_SetImeDataFn_DefaultImpl(_ctx, _viewport, _data) end

function ImGui.InitializeDefaultPlatformHandlers(platform_io)
	platform_io.Platform_GetClipboardTextFn = ImGui.Platform_GetClipboardTextFn_DefaultImpl
	platform_io.Platform_SetClipboardTextFn = ImGui.Platform_SetClipboardTextFn_DefaultImpl
	platform_io.Platform_OpenInShellFn = ImGui.Platform_OpenInShellFn_DefaultImpl
	platform_io.Platform_SetImeDataFn = ImGui.Platform_SetImeDataFn_DefaultImpl
end

return true
