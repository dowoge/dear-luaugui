--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local DrawList = require("./DrawList")

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImTrunc, ImFloor, ImCeil = Base.ImTrunc, Base.ImFloor, Base.ImCeil
local ImTruncToInt = Base.ImTruncToInt
local ColorConvertFloat4ToU32XYZW = Base.ColorConvertFloat4ToU32XYZW
local FLT_MAX = Base.FLT_MAX
local INT_MAX = 2147483647
local IMGUI_VIEWPORT_DEFAULT_ID = 0x11111111

local ImGuiCol = Enums.ImGuiCol
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiDataType = Enums.ImGuiDataType
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiInputEventType = Enums.ImGuiInputEventType
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiListClipperFlags = Enums.ImGuiListClipperFlags
local ImGuiDir = Enums.ImGuiDir
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiNavRenderCursorFlags = Enums.ImGuiNavRenderCursorFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiLocKey = Enums.ImGuiLocKey
local ImGuiContextHookType = Enums.ImGuiContextHookType
local IM_UNICODE_CODEPOINT_INVALID = Enums.Defines.IM_UNICODE_CODEPOINT_INVALID

local ImGuiStyle = Structs.ImGuiStyle
local ImGuiIO = Structs.ImGuiIO
local ImGuiListClipper = Structs.ImGuiListClipper
local ImGuiListClipperRange = Structs.ImGuiListClipperRange

ImGui.IMGUI_VIEWPORT_DEFAULT_ID = IMGUI_VIEWPORT_DEFAULT_ID

function ImGuiStyle:ScaleAllSizes(scale_factor)
	self._MainScale *= scale_factor
	self.WindowPadding = ImTrunc(self.WindowPadding * scale_factor)
	self.WindowRounding = ImTrunc(self.WindowRounding * scale_factor)
	self.WindowBorderSize = ImTrunc(self.WindowBorderSize * scale_factor)
	self.WindowMinSize = ImTrunc(self.WindowMinSize * scale_factor)
	self.WindowBorderHoverPadding = ImTrunc(self.WindowBorderHoverPadding * scale_factor)
	self.ChildRounding = ImTrunc(self.ChildRounding * scale_factor)
	self.ChildBorderSize = ImTrunc(self.ChildBorderSize * scale_factor)
	self.PopupRounding = ImTrunc(self.PopupRounding * scale_factor)
	self.PopupBorderSize = ImTrunc(self.PopupBorderSize * scale_factor)
	self.FramePadding = ImTrunc(self.FramePadding * scale_factor)
	self.FrameBorderSize = ImTrunc(self.FrameBorderSize * scale_factor)
	self.FrameRounding = ImTrunc(self.FrameRounding * scale_factor)
	self.ItemSpacing = ImTrunc(self.ItemSpacing * scale_factor)
	self.ItemInnerSpacing = ImTrunc(self.ItemInnerSpacing * scale_factor)
	self.CellPadding = ImTrunc(self.CellPadding * scale_factor)
	self.TouchExtraPadding = ImTrunc(self.TouchExtraPadding * scale_factor)
	self.IndentSpacing = ImTrunc(self.IndentSpacing * scale_factor)
	self.ColumnsMinSpacing = ImTrunc(self.ColumnsMinSpacing * scale_factor)
	self.ScrollbarSize = ImTrunc(self.ScrollbarSize * scale_factor)
	self.ScrollbarRounding = ImTrunc(self.ScrollbarRounding * scale_factor)
	self.ScrollbarPadding = ImTrunc(self.ScrollbarPadding * scale_factor)
	self.GrabMinSize = ImTrunc(self.GrabMinSize * scale_factor)
	self.GrabRounding = ImTrunc(self.GrabRounding * scale_factor)
	self.LogSliderDeadzone = ImTrunc(self.LogSliderDeadzone * scale_factor)
	self.ImageRounding = ImTrunc(self.ImageRounding * scale_factor)
	self.ImageBorderSize = ImTrunc(self.ImageBorderSize * scale_factor)
	self.TabRounding = ImTrunc(self.TabRounding * scale_factor)
	self.TabBorderSize = ImTrunc(self.TabBorderSize * scale_factor)
	self.TabMinWidthBase = ImTrunc(self.TabMinWidthBase * scale_factor)
	self.TabMinWidthShrink = ImTrunc(self.TabMinWidthShrink * scale_factor)
	if self.TabCloseButtonMinWidthSelected > 0 and self.TabCloseButtonMinWidthSelected ~= FLT_MAX then
		self.TabCloseButtonMinWidthSelected = ImTrunc(self.TabCloseButtonMinWidthSelected * scale_factor)
	end
	if self.TabCloseButtonMinWidthUnselected > 0 and self.TabCloseButtonMinWidthUnselected ~= FLT_MAX then
		self.TabCloseButtonMinWidthUnselected = ImTrunc(self.TabCloseButtonMinWidthUnselected * scale_factor)
	end
	self.TabBarBorderSize = ImTrunc(self.TabBarBorderSize * scale_factor)
	self.TabBarOverlineSize = ImTrunc(self.TabBarOverlineSize * scale_factor)
	self.TreeLinesSize = ImTrunc(self.TreeLinesSize * scale_factor)
	self.TreeLinesRounding = ImTrunc(self.TreeLinesRounding * scale_factor)
	self.MenuItemRounding = ImTrunc(self.MenuItemRounding * scale_factor)
	self.SelectableRounding = ImTrunc(self.SelectableRounding * scale_factor)
	self.DragDropTargetRounding = ImTrunc(self.DragDropTargetRounding * scale_factor)
	self.DragDropTargetBorderSize = ImTrunc(self.DragDropTargetBorderSize * scale_factor)
	self.DragDropTargetPadding = ImTrunc(self.DragDropTargetPadding * scale_factor)
	self.ColorMarkerSize = ImTrunc(self.ColorMarkerSize * scale_factor)
	self.InputTextCursorSize = ImTrunc(self.InputTextCursorSize * scale_factor)
	self.SeparatorSize = ImTrunc(self.SeparatorSize * scale_factor)
	self.SeparatorTextBorderSize = ImTrunc(self.SeparatorTextBorderSize * scale_factor)
	self.SeparatorTextPadding = ImTrunc(self.SeparatorTextPadding * scale_factor)
	self.DisplayWindowPadding = ImTrunc(self.DisplayWindowPadding * scale_factor)
	self.DisplaySafeAreaPadding = ImTrunc(self.DisplaySafeAreaPadding * scale_factor)
	self.MouseCursorScale = ImTrunc(self.MouseCursorScale * scale_factor)
end

function ImGuiIO:AddInputCharacter(c)
	assert(self.Ctx ~= nil)
	local g = self.Ctx
	if c == 0 or not self.AppAcceptingEvents then
		return
	end
	local e = Structs.ImGuiInputEvent.new()
	e.Type = ImGuiInputEventType.Text
	e.Source = ImGuiInputSource.Keyboard
	e.EventId = g.InputEventsNextEventId
	g.InputEventsNextEventId += 1
	e.Text.Char = c
	g.InputEventsQueue:push_back(e)
end

function ImGuiIO:AddInputCharacterUTF16(c)
	if (c == 0 and self.InputQueueSurrogate == 0) or not self.AppAcceptingEvents then
		return
	end
	if bit32.band(c, 0xFC00) == 0xD800 then
		if self.InputQueueSurrogate ~= 0 then
			self:AddInputCharacter(IM_UNICODE_CODEPOINT_INVALID)
		end
		self.InputQueueSurrogate = c
		return
	end
	local cp = c
	if self.InputQueueSurrogate ~= 0 then
		if bit32.band(c, 0xFC00) ~= 0xDC00 then
			self:AddInputCharacter(IM_UNICODE_CODEPOINT_INVALID)
		else
			if Enums.Defines.IM_UNICODE_CODEPOINT_MAX == 0xFFFF then
				cp = IM_UNICODE_CODEPOINT_INVALID
			else
				cp = bit32.lshift(self.InputQueueSurrogate - 0xD800, 10) + (c - 0xDC00) + 0x10000
			end
		end
		self.InputQueueSurrogate = 0
	end
	self:AddInputCharacter(cp)
end

function ImGuiIO:AddInputCharactersUTF8(str)
	if not self.AppAcceptingEvents then
		return
	end
	local str_end = #str + 1
	local i = 1
	while i < str_end and string.byte(str, i) ~= 0 do
		local bytes, c = Base.ImTextCharFromUtf8(str, i, str_end)
		i += bytes
		self:AddInputCharacter(c)
	end
end

function ImGuiIO:ClearEventsQueue()
	assert(self.Ctx ~= nil)
	local g = self.Ctx
	g.InputEventsQueue:clear()
end

function ImGuiIO:ClearInputKeys()
	local g = self.Ctx
	for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
		if ImGui.IsMouseKey(key) then
			continue
		end
		local key_data = g.IO.KeysData[key - ImGuiKey.NamedKey_BEGIN + 1]
		key_data.Down = false
		key_data.DownDuration = -1
		key_data.DownDurationPrev = -1
	end
	self.KeyCtrl = false
	self.KeyShift = false
	self.KeyAlt = false
	self.KeySuper = false
	self.KeyMods = ImGuiMod.None
	self.InputQueueCharacters:resize(0)
end

function ImGuiIO:ClearInputMouse()
	for key = ImGuiKey.Mouse_BEGIN, ImGuiKey.Mouse_END - 1 do
		local key_data = self.KeysData[key - ImGuiKey.NamedKey_BEGIN + 1]
		key_data.Down = false
		key_data.DownDuration = -1
		key_data.DownDurationPrev = -1
	end
	self.MousePos = ImVec2(-FLT_MAX, -FLT_MAX)
	for n = 1, #self.MouseDown do
		self.MouseDown[n] = false
		self.MouseDownDuration[n] = -1
		self.MouseDownDurationPrev[n] = -1
	end
	self.MouseWheel = 0
	self.MouseWheelH = 0
end

function ImGui.FindLatestInputEvent(ctx, type_, arg)
	if arg == nil then
		arg = -1
	end
	local g = ctx
	for n = g.InputEventsQueue.Size - 1, 0, -1 do
		local e = g.InputEventsQueue[n + 1]
		if e.Type ~= type_ then
			continue
		end
		if type_ == ImGuiInputEventType.Key and e.Key.Key ~= arg then
			continue
		end
		if type_ == ImGuiInputEventType.MouseButton and e.MouseButton.Button ~= arg then
			continue
		end
		return e
	end
	return nil
end

function ImGuiIO:AddKeyAnalogEvent(key, down, analog_value)
	assert(self.Ctx ~= nil)
	if key == ImGuiKey.None or not self.AppAcceptingEvents then
		return
	end
	local g = self.Ctx
	assert(ImGui.IsNamedKeyOrMod(key))
	assert(ImGui.IsAliasKey(key) == false)

	if g.IO.ConfigMacOSXBehaviors then
		if key == ImGuiMod.Super then
			key = ImGuiMod.Ctrl
		elseif key == ImGuiMod.Ctrl then
			key = ImGuiMod.Super
		elseif key == ImGuiKey.LeftSuper then
			key = ImGuiKey.LeftCtrl
		elseif key == ImGuiKey.RightSuper then
			key = ImGuiKey.RightCtrl
		elseif key == ImGuiKey.LeftCtrl then
			key = ImGuiKey.LeftSuper
		elseif key == ImGuiKey.RightCtrl then
			key = ImGuiKey.RightSuper
		end
	end

	local latest_event = ImGui.FindLatestInputEvent(g, ImGuiInputEventType.Key, key)
	local key_data = ImGui.GetKeyData(g, key)
	local latest_key_down, latest_key_analog
	if latest_event then
		latest_key_down = latest_event.Key.Down
		latest_key_analog = latest_event.Key.AnalogValue
	else
		latest_key_down = key_data.Down
		latest_key_analog = key_data.AnalogValue
	end
	if latest_key_down == down and latest_key_analog == analog_value then
		return
	end

	local e = Structs.ImGuiInputEvent.new()
	e.Type = ImGuiInputEventType.Key
	e.Source = if ImGui.IsGamepadKey(key) then ImGuiInputSource.Gamepad else ImGuiInputSource.Keyboard
	e.EventId = g.InputEventsNextEventId
	g.InputEventsNextEventId += 1
	e.Key.Key = key
	e.Key.Down = down
	e.Key.AnalogValue = analog_value
	g.InputEventsQueue:push_back(e)
end

function ImGuiIO:AddKeyEvent(key, down)
	if not self.AppAcceptingEvents then
		return
	end
	self:AddKeyAnalogEvent(key, down, if down then 1 else 0)
end

function ImGuiIO:SetKeyEventNativeData(key, native_keycode, native_scancode, native_legacy_index)
	if native_legacy_index == nil then
		native_legacy_index = -1
	end
	if key == ImGuiKey.None then
		return
	end
	assert(ImGui.IsNamedKey(key))
	assert(native_legacy_index == -1 or ImGui.IsLegacyKey(native_legacy_index))
end

function ImGuiIO:SetAppAcceptingEvents(accepting_events)
	self.AppAcceptingEvents = accepting_events
end

function ImGuiIO:AddMousePosEvent(x, y)
	assert(self.Ctx ~= nil)
	local g = self.Ctx
	if not self.AppAcceptingEvents then
		return
	end

	local pos = ImVec2(if x > -FLT_MAX then ImFloor(x) else x, if y > -FLT_MAX then ImFloor(y) else y)

	local latest_event = ImGui.FindLatestInputEvent(g, ImGuiInputEventType.MousePos)
	local latest_pos = if latest_event then ImVec2(latest_event.MousePos.PosX, latest_event.MousePos.PosY) else g.IO.MousePos
	if latest_pos.x == pos.x and latest_pos.y == pos.y then
		return
	end

	local e = Structs.ImGuiInputEvent.new()
	e.Type = ImGuiInputEventType.MousePos
	e.Source = ImGuiInputSource.Mouse
	e.EventId = g.InputEventsNextEventId
	g.InputEventsNextEventId += 1
	e.MousePos.PosX = pos.x
	e.MousePos.PosY = pos.y
	e.MousePos.MouseSource = g.InputEventsNextMouseSource
	g.InputEventsQueue:push_back(e)
end

function ImGuiIO:AddMouseButtonEvent(mouse_button, down)
	assert(self.Ctx ~= nil)
	local g = self.Ctx
	assert(mouse_button >= 0 and mouse_button < ImGuiMouseButton.COUNT)
	if not self.AppAcceptingEvents then
		return
	end

	if self.ConfigMacOSXBehaviors and mouse_button == 0 and self.MouseCtrlLeftAsRightClick then
		mouse_button = 1
		if not down then
			self.MouseCtrlLeftAsRightClick = false
		end
	end

	local latest_event = ImGui.FindLatestInputEvent(g, ImGuiInputEventType.MouseButton, mouse_button)
	local latest_button_down
	if latest_event then
		latest_button_down = latest_event.MouseButton.Down
	else
		latest_button_down = g.IO.MouseDown[mouse_button + 1]
	end
	if latest_button_down == down then
		return
	end

	if self.ConfigMacOSXBehaviors and mouse_button == 0 and down then
		local latest_super_event = ImGui.FindLatestInputEvent(g, ImGuiInputEventType.Key, ImGuiMod.Super)
		local super_down
		if latest_super_event then
			super_down = latest_super_event.Key.Down
		else
			super_down = g.IO.KeySuper
		end
		if super_down then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventIO) then
				ImGui.DebugLog("[io] Super+Left Click aliased into Right Click\n")
			end
			self.MouseCtrlLeftAsRightClick = true
			self:AddMouseButtonEvent(1, true)
			return
		end
	end

	local e = Structs.ImGuiInputEvent.new()
	e.Type = ImGuiInputEventType.MouseButton
	e.Source = ImGuiInputSource.Mouse
	e.EventId = g.InputEventsNextEventId
	g.InputEventsNextEventId += 1
	e.MouseButton.Button = mouse_button
	e.MouseButton.Down = down
	e.MouseButton.MouseSource = g.InputEventsNextMouseSource
	g.InputEventsQueue:push_back(e)
end

function ImGuiIO:AddMouseWheelEvent(wheel_x, wheel_y)
	assert(self.Ctx ~= nil)
	local g = self.Ctx

	if not self.AppAcceptingEvents or (wheel_x == 0 and wheel_y == 0) then
		return
	end

	local e = Structs.ImGuiInputEvent.new()
	e.Type = ImGuiInputEventType.MouseWheel
	e.Source = ImGuiInputSource.Mouse
	e.EventId = g.InputEventsNextEventId
	g.InputEventsNextEventId += 1
	e.MouseWheel.WheelX = wheel_x
	e.MouseWheel.WheelY = wheel_y
	e.MouseWheel.MouseSource = g.InputEventsNextMouseSource
	g.InputEventsQueue:push_back(e)
end

function ImGuiIO:AddMouseSourceEvent(source)
	assert(self.Ctx ~= nil)
	local g = self.Ctx
	g.InputEventsNextMouseSource = source
end

function ImGuiIO:AddFocusEvent(focused)
	assert(self.Ctx ~= nil)
	local g = self.Ctx

	local latest_event = ImGui.FindLatestInputEvent(g, ImGuiInputEventType.Focus)
	local latest_focused
	if latest_event then
		latest_focused = latest_event.AppFocused.Focused
	else
		latest_focused = not g.IO.AppFocusLost
	end
	if latest_focused == focused or (self.ConfigDebugIgnoreFocusLoss and not focused) then
		return
	end

	local e = Structs.ImGuiInputEvent.new()
	e.Type = ImGuiInputEventType.Focus
	e.EventId = g.InputEventsNextEventId
	g.InputEventsNextEventId += 1
	e.AppFocused.Focused = focused
	g.InputEventsQueue:push_back(e)
end

function ImGui.GetSkipItemForListClipping()
	local g = ImGui.GImGui
	return if g.CurrentTable then g.CurrentTable.HostSkipItems else g.CurrentWindow.SkipItems
end

function ImGui.ImGuiListClipper_SortAndFuseRanges(ranges, offset)
	if offset == nil then
		offset = 0
	end
	if ranges.Size - offset <= 1 then
		return
	end

	for sort_end = ranges.Size - offset - 1, 1, -1 do
		for i = offset, sort_end + offset - 1 do
			if ranges[i + 1].Min > ranges[i + 2].Min then
				ranges[i + 1], ranges[i + 2] = ranges[i + 2], ranges[i + 1]
			end
		end
	end

	local i = 1 + offset
	while i < ranges.Size do
		local cur, prev = ranges[i + 1], ranges[i]
		assert(not cur.PosToIndexConvert and not prev.PosToIndexConvert)
		if prev.Max < cur.Min then
			i += 1
			continue
		end
		prev.Min = ImMin(prev.Min, cur.Min)
		prev.Max = ImMax(prev.Max, cur.Max)
		ranges:erase(i)
	end
end

function ImGui.ImGuiListClipper_SeekCursorAndSetupPrevLine(clipper, pos_y, line_height)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local dc = window.DC
	local off_y = pos_y - dc.CursorPos.y
	dc.CursorPos = ImVec2(dc.CursorPos.x, pos_y)
	dc.CursorMaxPos = ImVec2(dc.CursorMaxPos.x, ImMax(dc.CursorMaxPos.y, pos_y - g.Style.ItemSpacing.y))
	dc.CursorPosPrevLine = ImVec2(dc.CursorPosPrevLine.x, dc.CursorPos.y - line_height)
	dc.PrevLineSize = ImVec2(dc.PrevLineSize.x, line_height - g.Style.ItemSpacing.y)
	local columns = dc.CurrentColumns
	if columns then
		columns.LineMinY = dc.CursorPos.y
	end
	local table = g.CurrentTable
	if table then
		if table.IsInsideRow then
			ImGui.TableEndRow(table)
		end
		local row_increase = ImTruncToInt((off_y / line_height) + 0.5)
		if row_increase > 0 and bit32.band(clipper.Flags, ImGuiListClipperFlags.NoSetTableRowCounters) == 0 then
			table.CurrentRow += row_increase
			table.RowBgColorCounter += row_increase
		end
		table.RowPosY2 = dc.CursorPos.y
	end
end

function ImGuiListClipper:Begin(items_count, items_height)
	if items_height == nil then
		items_height = -1
	end
	self.Ctx = ImGui.GetCurrentContext()

	local g = self.Ctx
	local window = g.CurrentWindow
	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventClipper) then
		ImGui.DebugLog("Clipper: Begin(%d,%.2f) in '%s'\n", items_count, items_height, window.Name)
	end

	local table = g.CurrentTable
	if table then
		if table.IsInsideRow then
			ImGui.TableEndRow(table)
		end
	end

	self.StartPosY = window.DC.CursorPos.y
	self.ItemsHeight = items_height
	self.ItemsCount = items_count
	self.DisplayStart = -1
	self.DisplayEnd = 0

	g.ClipperTempDataStacked += 1
	while g.ClipperTempDataStacked > g.ClipperTempData.Size do
		g.ClipperTempData:push_back(Structs.ImGuiListClipperData.new())
	end
	local data = g.ClipperTempData[g.ClipperTempDataStacked]
	data:Reset(self)
	data.LossynessOffset = window.DC.CursorStartPosLossyness.y
	self.TempData = data
	self.StartSeekOffsetY = data.LossynessOffset
end

function ImGuiListClipper:End()
	local data = self.TempData
	if data then
		local g = self.Ctx
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventClipper) then
			ImGui.DebugLog("Clipper: End() in '%s'\n", g.CurrentWindow.Name)
		end
		if self.ItemsCount >= 0 and self.ItemsCount < INT_MAX and self.DisplayStart >= 0 then
			self:SeekCursorForItem(self.ItemsCount)
		end

		assert(data.ListClipper == self)
		data.StepNo = data.Ranges.Size
		g.ClipperTempDataStacked -= 1
		if g.ClipperTempDataStacked > 0 then
			data = g.ClipperTempData[g.ClipperTempDataStacked]
			data.ListClipper.TempData = data
		end
		self.TempData = nil
	end
	self.DisplayStart = self.ItemsCount
	self.DisplayEnd = self.ItemsCount
	self.ItemsCount = -1
end

function ImGuiListClipper:IncludeItemsByIndex(item_begin, item_end)
	local data = self.TempData
	assert(self.DisplayStart < 0)
	assert(item_begin <= item_end)
	if item_begin < item_end then
		data.Ranges:push_back(ImGuiListClipperRange.FromIndices(item_begin, item_end))
	end
end

function ImGuiListClipper:SeekCursorForItem(item_n)
	local pos_y = self.StartPosY + self.StartSeekOffsetY + item_n * self.ItemsHeight
	ImGui.ImGuiListClipper_SeekCursorAndSetupPrevLine(self, pos_y, self.ItemsHeight)
end

function ImGui.ImGuiListClipper_StepInternal(clipper)
	local g = clipper.Ctx
	local window = g.CurrentWindow
	local data = clipper.TempData
	assert(data ~= nil, "Called ImGuiListClipper::Step() too many times, or before ImGuiListClipper::Begin() ?")

	local table = g.CurrentTable
	if table and table.IsInsideRow then
		ImGui.TableEndRow(table)
	end

	if clipper.ItemsCount == 0 or ImGui.GetSkipItemForListClipping() then
		return false
	end

	if data.StepNo == 0 and table ~= nil and not table.IsUnfrozenRows then
		clipper.DisplayStart = data.ItemsFrozen
		clipper.DisplayEnd = ImMin(data.ItemsFrozen + 1, clipper.ItemsCount)
		if clipper.DisplayStart < clipper.DisplayEnd then
			data.ItemsFrozen += 1
		end
		return true
	end

	local calc_clipping = false
	if data.StepNo == 0 then
		clipper.StartPosY = window.DC.CursorPos.y
		if clipper.ItemsHeight <= 0 then
			data.Ranges:push_front(ImGuiListClipperRange.FromIndices(data.ItemsFrozen, data.ItemsFrozen + 1))
			clipper.DisplayStart = ImMax(data.Ranges[1].Min, data.ItemsFrozen)
			clipper.DisplayEnd = ImMin(data.Ranges[1].Max, clipper.ItemsCount)
			data.StepNo = 1
			return true
		end
		calc_clipping = true
	end

	if clipper.ItemsHeight <= 0 then
		assert(data.StepNo == 1)
		local affected_by_floating_point_precision = Base.ImIsFloatAboveGuaranteedIntegerPrecision(clipper.StartPosY)
			or Base.ImIsFloatAboveGuaranteedIntegerPrecision(window.DC.CursorPos.y)
		if affected_by_floating_point_precision then
			clipper.ItemsHeight = window.DC.PrevLineSize.y + g.Style.ItemSpacing.y
			window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, clipper.StartPosY + clipper.ItemsHeight)
		else
			clipper.ItemsHeight = (window.DC.CursorPos.y - clipper.StartPosY) / (clipper.DisplayEnd - clipper.DisplayStart)
		end
		if clipper.ItemsHeight == 0 and clipper.ItemsCount == INT_MAX then
			return false
		end
		if clipper.ItemsHeight <= 0 then
			local msg = "ImGuiListClipper: Failed to calculate item height! First item hasn't been submitted by user code, or has not moved the cursor vertically!"
			if ImGui.ErrorLog(msg) then
				assert(false, msg)
			end
			return false
		end
		if table then
			assert(table.RowPosY1 == clipper.StartPosY and table.RowPosY2 == window.DC.CursorPos.y)
		end

		calc_clipping = true
	end

	local already_submitted = clipper.DisplayEnd
	if calc_clipping then
		clipper.StartSeekOffsetY = data.LossynessOffset - data.ItemsFrozen * clipper.ItemsHeight

		if g.LogEnabled then
			data.Ranges:push_back(ImGuiListClipperRange.FromIndices(0, clipper.ItemsCount))
		else
			local is_nav_request = (g.NavMoveScoringItems and g.NavWindow ~= nil and g.NavWindow.RootWindowForNav == window.RootWindowForNav)
			local nav_off_min = if is_nav_request and g.NavMoveClipDir == ImGuiDir.Up then -1 else 0
			local nav_off_max = if is_nav_request and g.NavMoveClipDir == ImGuiDir.Down then 1 else 0
			if is_nav_request then
				data.Ranges:push_back(ImGuiListClipperRange.FromPositions(g.NavScoringRect.Min.y, g.NavScoringRect.Max.y, nav_off_min, nav_off_max))
				if not g.NavScoringNoClipRect:IsInverted() then
					data.Ranges:push_back(ImGuiListClipperRange.FromPositions(g.NavScoringNoClipRect.Min.y, g.NavScoringNoClipRect.Max.y, nav_off_min, nav_off_max))
				end
			end
			if is_nav_request and bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) and g.NavTabbingDir == -1 then
				data.Ranges:push_back(ImGuiListClipperRange.FromIndices(clipper.ItemsCount - 1, clipper.ItemsCount))
			end

			local nav_rect_abs = ImGui.WindowRectRelToAbs(window, window.NavRectRel[1])
			if g.NavId ~= 0 and window.NavLastIds[1] == g.NavId then
				data.Ranges:push_back(ImGuiListClipperRange.FromPositions(nav_rect_abs.Min.y, nav_rect_abs.Max.y, 0, 0))
			end

			local min_y = window.ClipRect.Min.y
			local max_y = window.ClipRect.Max.y

			local bs = g.BoxSelectState
			if bs.IsActive and bs.Window == window then
				local pad_y = g.Style.ItemSpacing.y
				min_y -= pad_y
				max_y += pad_y

				if bs.UnclipMode then
					data.Ranges:push_back(ImGuiListClipperRange.FromPositions(bs.UnclipRect.Min.y - pad_y, bs.UnclipRect.Max.y + pad_y, 0, 0))
				end
			end

			data.Ranges:push_back(ImGuiListClipperRange.FromPositions(min_y, max_y, nav_off_min, nav_off_max))
		end

		for n = 1, data.Ranges.Size do
			local range = data.Ranges[n]
			if range.PosToIndexConvert then
				local m1 = ImTruncToInt((range.Min - window.DC.CursorPos.y - data.LossynessOffset) / clipper.ItemsHeight)
				local m2 = ImTruncToInt(((range.Max - window.DC.CursorPos.y - data.LossynessOffset) / clipper.ItemsHeight) + 0.999999)
				range.Min = ImClamp(already_submitted + m1 + range.PosToIndexOffsetMin, already_submitted, clipper.ItemsCount - 1)
				range.Max = ImClamp(already_submitted + m2 + range.PosToIndexOffsetMax, range.Min + 1, clipper.ItemsCount)
				range.PosToIndexConvert = false
			end
		end
		ImGui.ImGuiListClipper_SortAndFuseRanges(data.Ranges, data.StepNo)
	end

	while data.StepNo < data.Ranges.Size do
		local range = data.Ranges[data.StepNo + 1]
		clipper.DisplayStart = ImMax(range.Min, already_submitted)
		clipper.DisplayEnd = ImMin(range.Max, clipper.ItemsCount)
		data.StepNo += 1
		if clipper.DisplayStart >= clipper.DisplayEnd then
			continue
		end
		if clipper.DisplayStart > already_submitted then
			clipper:SeekCursorForItem(clipper.DisplayStart)
		end
		return true
	end

	if clipper.ItemsCount < INT_MAX then
		clipper:SeekCursorForItem(clipper.ItemsCount)
	end

	return false
end

function ImGuiListClipper:Step()
	local g = self.Ctx
	local need_items_height = (self.ItemsHeight <= 0)
	local ret = ImGui.ImGuiListClipper_StepInternal(self)
	if ret and (self.DisplayStart >= self.DisplayEnd) then
		ret = false
	end
	local log_clipper = bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventClipper)
	if g.CurrentTable and g.CurrentTable.IsUnfrozenRows == false then
		if log_clipper then
			ImGui.DebugLog("Clipper: Step(): inside frozen table row.\n")
		end
	end
	if need_items_height and self.ItemsHeight > 0 then
		if log_clipper then
			ImGui.DebugLog("Clipper: Step(): computed ItemsHeight: %.2f.\n", self.ItemsHeight)
		end
	end
	if ret then
		if log_clipper then
			ImGui.DebugLog("Clipper: Step(): display %d to %d.\n", self.DisplayStart, self.DisplayEnd)
		end
	else
		if log_clipper then
			ImGui.DebugLog("Clipper: Step(): End.\n")
		end
		self:End()
	end
	return ret
end

function ImGui.CalcClipRectVisibleItemsY(clip_rect, pos, items_height, out_visible_start, out_visible_end)
	out_visible_start = ImMax(ImTruncToInt((clip_rect.Min.y - pos.y) / items_height), 0)
	out_visible_end = ImMax(ImTruncToInt(ImCeil((clip_rect.Max.y - pos.y) / items_height)), out_visible_start)
	return out_visible_start, out_visible_end
end

function ImGui.GetStyle()
	assert(ImGui.GImGui ~= nil, "No current context. Did you call ImGui::CreateContext() and ImGui::SetCurrentContext() ?")
	return ImGui.GImGui.Style
end

function ImGui.GetColorU32(idx, alpha_mul)
	local style = ImGui.GImGui.Style
	if type(idx) == "table" then
		local c = idx
		return ColorConvertFloat4ToU32XYZW(c.x, c.y, c.z, c.w * style.Alpha)
	end
	if alpha_mul == nil then
		alpha_mul = 1
	end
	local c = style.Colors[idx + 1]
	return ColorConvertFloat4ToU32XYZW(c.x, c.y, c.z, c.w * style.Alpha * alpha_mul)
end

function ImGui.GetStyleColorVec4(idx)
	local style = ImGui.GImGui.Style
	return style.Colors[idx + 1]
end

function ImGui.GetColorU32_U32(col, alpha_mul)
	if alpha_mul == nil then
		alpha_mul = 1
	end
	local style = ImGui.GImGui.Style
	alpha_mul *= style.Alpha
	if alpha_mul >= 1 then
		return col
	end
	local a = bit32.rshift(bit32.band(col, Base.IM_COL32_A_MASK), Base.IM_COL32_A_SHIFT)
	a = math.floor(a * alpha_mul)
	return bit32.bor(bit32.band(col, bit32.bnot(Base.IM_COL32_A_MASK)), bit32.lshift(a, Base.IM_COL32_A_SHIFT))
end

function ImGui.PushStyleColor(idx, col)
	local g = ImGui.GImGui
	local backup_value = g.Style.Colors[idx + 1]
	local backup = Structs.ImGuiColorMod.new(idx, backup_value)
	backup.BackupValue = backup_value
	g.ColorStack:push_back(backup)
	if g.DebugFlashStyleColorIdx ~= idx then
		if type(col) == "number" then
			g.Style.Colors[idx + 1] = ImGui.ColorConvertU32ToFloat4(col)
		else
			g.Style.Colors[idx + 1] = col
		end
	end
end

function ImGui.PopStyleColor(count)
	if count == nil then
		count = 1
	end
	local g = ImGui.GImGui
	if g.ColorStack.Size < count then
		local msg = "Calling PopStyleColor() too many times!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		count = g.ColorStack.Size
	end
	while count > 0 do
		local backup = g.ColorStack:back()
		g.Style.Colors[backup.Col + 1] = backup.BackupValue
		g.ColorStack:pop_back()
		count -= 1
	end
end

local function StyleVarInfo(count, data_type, name)
	return table.freeze({ Count = count, DataType = data_type, Name = name })
end

local F = ImGuiDataType.Float
local GStyleVarsInfo = {
	StyleVarInfo(1, F, "Alpha"),
	StyleVarInfo(1, F, "DisabledAlpha"),
	StyleVarInfo(2, F, "WindowPadding"),
	StyleVarInfo(1, F, "WindowRounding"),
	StyleVarInfo(1, F, "WindowBorderSize"),
	StyleVarInfo(2, F, "WindowMinSize"),
	StyleVarInfo(2, F, "WindowTitleAlign"),
	StyleVarInfo(1, F, "ChildRounding"),
	StyleVarInfo(1, F, "ChildBorderSize"),
	StyleVarInfo(1, F, "PopupRounding"),
	StyleVarInfo(1, F, "PopupBorderSize"),
	StyleVarInfo(2, F, "FramePadding"),
	StyleVarInfo(1, F, "FrameRounding"),
	StyleVarInfo(1, F, "FrameBorderSize"),
	StyleVarInfo(2, F, "ItemSpacing"),
	StyleVarInfo(2, F, "ItemInnerSpacing"),
	StyleVarInfo(1, F, "IndentSpacing"),
	StyleVarInfo(2, F, "CellPadding"),
	StyleVarInfo(1, F, "ScrollbarSize"),
	StyleVarInfo(1, F, "ScrollbarRounding"),
	StyleVarInfo(1, F, "ScrollbarPadding"),
	StyleVarInfo(1, F, "GrabMinSize"),
	StyleVarInfo(1, F, "GrabRounding"),
	StyleVarInfo(1, F, "ImageRounding"),
	StyleVarInfo(1, F, "ImageBorderSize"),
	StyleVarInfo(1, F, "TabRounding"),
	StyleVarInfo(1, F, "TabBorderSize"),
	StyleVarInfo(1, F, "TabMinWidthBase"),
	StyleVarInfo(1, F, "TabMinWidthShrink"),
	StyleVarInfo(1, F, "TabBarBorderSize"),
	StyleVarInfo(1, F, "TabBarOverlineSize"),
	StyleVarInfo(1, F, "TableAngledHeadersAngle"),
	StyleVarInfo(2, F, "TableAngledHeadersTextAlign"),
	StyleVarInfo(1, F, "TreeLinesSize"),
	StyleVarInfo(1, F, "TreeLinesRounding"),
	StyleVarInfo(1, F, "MenuItemRounding"),
	StyleVarInfo(1, F, "SelectableRounding"),
	StyleVarInfo(1, F, "DragDropTargetRounding"),
	StyleVarInfo(2, F, "ButtonTextAlign"),
	StyleVarInfo(2, F, "SelectableTextAlign"),
	StyleVarInfo(1, F, "SeparatorSize"),
	StyleVarInfo(1, F, "SeparatorTextBorderSize"),
	StyleVarInfo(2, F, "SeparatorTextAlign"),
	StyleVarInfo(2, F, "SeparatorTextPadding"),
}

function ImGui.GetStyleVarInfo(idx)
	assert(idx >= 0 and idx < ImGuiStyleVar.COUNT)
	assert(#GStyleVarsInfo == ImGuiStyleVar.COUNT)
	return GStyleVarsInfo[idx + 1]
end

local function StyleVarTypeCheck(cond)
	if not cond then
		local msg = "Calling PushStyleVar() variant with wrong type!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return false
	end
	return true
end

function ImGui.PushStyleVar(idx, val)
	local g = ImGui.GImGui
	local var_info = ImGui.GetStyleVarInfo(idx)
	if type(val) == "vector" then
		if not StyleVarTypeCheck(var_info.DataType == ImGuiDataType.Float and var_info.Count == 2) then
			return
		end
	else
		if not StyleVarTypeCheck(var_info.DataType == ImGuiDataType.Float and var_info.Count == 1) then
			return
		end
	end
	g.StyleVarStack:push_back(Structs.ImGuiStyleMod.new(idx, g.Style[var_info.Name]))
	g.Style[var_info.Name] = val
end

function ImGui.PushStyleVarX(idx, val_x)
	local g = ImGui.GImGui
	local var_info = ImGui.GetStyleVarInfo(idx)
	if not StyleVarTypeCheck(var_info.DataType == ImGuiDataType.Float and var_info.Count == 2) then
		return
	end
	local pvar = g.Style[var_info.Name]
	g.StyleVarStack:push_back(Structs.ImGuiStyleMod.new(idx, pvar))
	g.Style[var_info.Name] = ImVec2(val_x, pvar.y)
end

function ImGui.PushStyleVarY(idx, val_y)
	local g = ImGui.GImGui
	local var_info = ImGui.GetStyleVarInfo(idx)
	if not StyleVarTypeCheck(var_info.DataType == ImGuiDataType.Float and var_info.Count == 2) then
		return
	end
	local pvar = g.Style[var_info.Name]
	g.StyleVarStack:push_back(Structs.ImGuiStyleMod.new(idx, pvar))
	g.Style[var_info.Name] = ImVec2(pvar.x, val_y)
end

function ImGui.PopStyleVar(count)
	if count == nil then
		count = 1
	end
	local g = ImGui.GImGui
	if g.StyleVarStack.Size < count then
		local msg = "Calling PopStyleVar() too many times!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		count = g.StyleVarStack.Size
	end
	while count > 0 do
		local backup = g.StyleVarStack:back()
		local var_info = ImGui.GetStyleVarInfo(backup.VarIdx)
		if var_info.DataType == ImGuiDataType.Float and var_info.Count == 1 then
			g.Style[var_info.Name] = backup.BackupFloat[1]
		elseif var_info.DataType == ImGuiDataType.Float and var_info.Count == 2 then
			g.Style[var_info.Name] = ImVec2(backup.BackupFloat[1], backup.BackupFloat[2])
		end
		g.StyleVarStack:pop_back()
		count -= 1
	end
end

local GStyleColorNames = {}
for name, value in ImGuiCol do
	if name ~= "COUNT" and name ~= "TextMixedValue" then
		GStyleColorNames[value] = name
	end
end

function ImGui.GetStyleColorName(idx)
	local name = GStyleColorNames[idx]
	if name then
		return name
	end
	assert(false)
	return "Unknown"
end

function ImGui.FindRenderedTextEnd(text, text_end)
	local text_display_end = text_end or (#text + 1)
	local p = string.find(text, "##", 1, true)
	if p and p < text_display_end then
		text_display_end = p
	end
	local z = string.find(text, "\0", 1, true)
	if z and z < text_display_end then
		text_display_end = z
	end
	return text_display_end
end

function ImGui.RenderText(pos, text, text_end, hide_text_after_hash)
	if hide_text_after_hash == nil then
		hide_text_after_hash = true
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local text_display_end
	if hide_text_after_hash then
		text_display_end = ImGui.FindRenderedTextEnd(text, text_end)
	else
		if not text_end then
			text_end = #text + 1
		end
		text_display_end = text_end
	end

	if text_display_end ~= 1 then
		window.DrawList:AddText(g.Font, g.FontSize, pos, ImGui.GetColorU32(ImGuiCol.Text), text, text_display_end)
		if g.LogEnabled then
			ImGui.LogRenderedText(pos, text, text_display_end)
		end
	end
end

function ImGui.RenderTextWrapped(pos, text, text_end, wrap_width)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	if not text_end then
		text_end = #text + 1
	end

	if text_end ~= 1 then
		window.DrawList:AddText(g.Font, g.FontSize, pos, ImGui.GetColorU32(ImGuiCol.Text), text, text_end, wrap_width)
		if g.LogEnabled then
			ImGui.LogRenderedText(pos, text, text_end)
		end
	end
end

function ImGui.RenderTextClippedEx(draw_list, pos_min, pos_max, text, text_display_end, text_size_if_known, align, clip_rect)
	if align == nil then
		align = ImVec2(0, 0)
	end
	local pos = pos_min
	local text_size = text_size_if_known or ImGui.CalcTextSize(text, text_display_end, false, 0)

	local clip_min = if clip_rect then clip_rect.Min else pos_min
	local clip_max = if clip_rect then clip_rect.Max else pos_max
	local need_clipping = (pos.x + text_size.x >= clip_max.x) or (pos.y + text_size.y >= clip_max.y)
	if clip_rect then
		need_clipping = need_clipping or (pos.x < clip_min.x) or (pos.y < clip_min.y)
	end

	if align.x > 0 then
		pos = ImVec2(ImMax(pos.x, pos.x + (pos_max.x - pos.x - text_size.x) * align.x), pos.y)
	end
	if align.y > 0 then
		pos = ImVec2(pos.x, ImMax(pos.y, pos.y + (pos_max.y - pos.y - text_size.y) * align.y))
	end

	if need_clipping then
		local fine_clip_rect = ImVec4(clip_min.x, clip_min.y, clip_max.x, clip_max.y)
		draw_list:AddText(nil, 0, pos, ImGui.GetColorU32(ImGuiCol.Text), text, text_display_end, 0, fine_clip_rect)
	else
		draw_list:AddText(nil, 0, pos, ImGui.GetColorU32(ImGuiCol.Text), text, text_display_end, 0, nil)
	end
end

function ImGui.RenderTextClipped(pos_min, pos_max, text, text_end, text_size_if_known, align, clip_rect)
	local text_display_end = ImGui.FindRenderedTextEnd(text, text_end)
	local text_len = text_display_end - 1
	if text_len == 0 then
		return
	end

	local g = ImGui.GImGui
	local window = g.CurrentWindow
	ImGui.RenderTextClippedEx(window.DrawList, pos_min, pos_max, text, text_display_end, text_size_if_known, align, clip_rect)
	if g.LogEnabled then
		ImGui.LogRenderedText(pos_min, text, text_display_end)
	end
end

function ImGui.RenderTextEllipsis(draw_list, pos_min, pos_max, ellipsis_max_x, text, text_end_full, text_size_if_known)
	local g = ImGui.GImGui
	if text_end_full == nil then
		text_end_full = ImGui.FindRenderedTextEnd(text)
	end
	local text_size = text_size_if_known or ImGui.CalcTextSize(text, text_end_full, false, 0)

	if text_size.x > pos_max.x - pos_min.x then
		local font = draw_list._Data.Font
		local font_size = draw_list._Data.FontSize
		local font_scale = draw_list._Data.FontScale
		local baked = font:GetFontBaked(font_size)
		local ellipsis_width = baked:GetCharAdvance(font.EllipsisChar) * font_scale

		local text_avail_width = ImMax((ImMax(pos_max.x, ellipsis_max_x) - ellipsis_width) - pos_min.x, 1)
		local text_size_clipped, text_end_ellipsis = font:CalcTextSizeA(font_size, text_avail_width, 0, text, text_end_full)
		local text_size_clipped_x = text_size_clipped.x

		ImGui.RenderTextClippedEx(draw_list, pos_min, pos_max, text, text_end_ellipsis, text_size, ImVec2(0, 0))
		local cpu_fine_clip_rect = ImVec4(pos_min.x, pos_min.y, pos_max.x, pos_max.y)
		local ellipsis_pos = ImTrunc(ImVec2(pos_min.x + text_size_clipped_x, pos_min.y))
		font:RenderChar(draw_list, font_size, ellipsis_pos, ImGui.GetColorU32(ImGuiCol.Text), font.EllipsisChar, cpu_fine_clip_rect)
	else
		ImGui.RenderTextClippedEx(draw_list, pos_min, pos_max, text, text_end_full, text_size, ImVec2(0, 0))
	end

	if g.LogEnabled then
		ImGui.LogRenderedText(pos_min, text, text_end_full)
	end
end

function ImGui.RenderFrame(p_min, p_max, fill_col, borders, rounding)
	if borders == nil then
		borders = true
	end
	if rounding == nil then
		rounding = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	window.DrawList:AddRectFilled(p_min, p_max, fill_col, rounding)
	local border_size = g.Style.FrameBorderSize
	if borders and border_size > 0 then
		window.DrawList:AddRect(p_min + ImVec2(1, 1), p_max + ImVec2(1, 1), ImGui.GetColorU32(ImGuiCol.BorderShadow), rounding, border_size)
		window.DrawList:AddRect(p_min, p_max, ImGui.GetColorU32(ImGuiCol.Border), rounding, border_size)
	end
end

function ImGui.RenderFrameBorder(p_min, p_max, rounding)
	if rounding == nil then
		rounding = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local border_size = g.Style.FrameBorderSize
	if border_size > 0 then
		window.DrawList:AddRect(p_min + ImVec2(1, 1), p_max + ImVec2(1, 1), ImGui.GetColorU32(ImGuiCol.BorderShadow), rounding, border_size)
		window.DrawList:AddRect(p_min, p_max, ImGui.GetColorU32(ImGuiCol.Border), rounding, border_size)
	end
end

function ImGui.RenderColorComponentMarker(bb, col, rounding)
	if bb.Min.x + 1 >= bb.Max.x then
		return
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	ImGui.RenderRectFilledInRangeH(window.DrawList, bb, col, bb.Min.x, ImMin(bb.Min.x + g.Style.ColorMarkerSize, bb.Max.x), rounding)
end

function ImGui.RenderNavCursor(bb, id, flags, rounding)
	if flags == nil then
		flags = ImGuiNavRenderCursorFlags.None
	end
	if rounding == nil then
		rounding = -1
	end
	local g = ImGui.GImGui
	if id ~= g.NavId then
		return
	end
	if not g.NavCursorVisible and not bit32.btest(flags, ImGuiNavRenderCursorFlags.AlwaysDraw) then
		return
	end
	if id == g.LastItemData.ID and bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.NoNav) then
		return
	end

	local window = g.CurrentWindow
	if window.DC.NavHideHighlightOneFrame then
		return
	end

	if rounding < 0 then
		rounding = g.Style.FrameRounding
	end

	local display_rect = bb:ClippedWith(window.ClipRect)
	local scale_factor = g.Style._MainScale
	local thickness = ImTruncToInt(ImMax(2, 1.5 * scale_factor))
	if bit32.btest(flags, ImGuiNavRenderCursorFlags.Compact) then
		window.DrawList:AddRect(display_rect.Min, display_rect.Max, ImGui.GetColorU32(ImGuiCol.NavCursor), rounding, thickness)
	else
		local distance = ImTruncToInt(3 + thickness * 0.5)
		display_rect = display_rect:Expanded(ImVec2(distance, distance))
		local fully_visible = window.ClipRect:Contains(display_rect)
		if not fully_visible then
			window.DrawList:PushClipRect(display_rect.Min, display_rect.Max)
		end
		window.DrawList:AddRect(display_rect.Min, display_rect.Max, ImGui.GetColorU32(ImGuiCol.NavCursor), rounding, thickness)
		if not fully_visible then
			window.DrawList:PopClipRect()
		end
	end
end

function ImGui.RenderMouseCursor(base_pos, base_scale, mouse_cursor, col_fill, col_border, col_shadow)
end

function ImGui.GetCurrentContext()
	return ImGui.GImGui
end

function ImGui.SetCurrentContext(ctx)
	ImGui.GImGui = ctx
end

local GImAllocatorAllocFunc, GImAllocatorFreeFunc, GImAllocatorUserData = nil, nil, nil

function ImGui.SetAllocatorFunctions(alloc_func, free_func, user_data)
	GImAllocatorAllocFunc = alloc_func
	GImAllocatorFreeFunc = free_func
	GImAllocatorUserData = user_data
end

function ImGui.GetAllocatorFunctions(p_alloc_func, p_free_func, p_user_data)
	return GImAllocatorAllocFunc, GImAllocatorFreeFunc, GImAllocatorUserData
end

function ImGui.CreateContext(shared_font_atlas)
	local prev_ctx = ImGui.GetCurrentContext()
	local ctx = Structs.ImGuiContext.new(shared_font_atlas)
	ImGui.SetCurrentContext(ctx)
	ImGui.Initialize()
	if prev_ctx ~= nil then
		ImGui.SetCurrentContext(prev_ctx)
	end
	return ctx
end

function ImGui.DestroyContext(ctx)
	local prev_ctx = ImGui.GetCurrentContext()
	if ctx == nil then
		ctx = prev_ctx
	end
	ImGui.SetCurrentContext(ctx)
	ImGui.Shutdown()
	ImGui.SetCurrentContext(if prev_ctx ~= ctx then prev_ctx else nil)
	assert(ctx.Initialized == false, "Forgot to call DestroyContext()?")
end

local GLocalizationEntriesEnUS = {
	{ Key = ImGuiLocKey.VersionStr, Text = "Dear ImGui " .. Base.IMGUI_VERSION .. " (" .. tostring(Base.IMGUI_VERSION_NUM) .. ")" },
	{ Key = ImGuiLocKey.TableSizeOne, Text = "Size column to fit###SizeOne" },
	{ Key = ImGuiLocKey.TableSizeAllFit, Text = "Size all columns to fit###SizeAll" },
	{ Key = ImGuiLocKey.TableSizeAllDefault, Text = "Size all columns to default###SizeAll" },
	{ Key = ImGuiLocKey.TableReset, Text = "Reset" },
	{ Key = ImGuiLocKey.TableResetOrder, Text = "Reset order###ResetOrder" },
	{ Key = ImGuiLocKey.TableResetVisibility, Text = "Reset visibility###ResetVisibility" },
	{ Key = ImGuiLocKey.WindowingMainMenuBar, Text = "(Main menu bar)" },
	{ Key = ImGuiLocKey.WindowingPopup, Text = "(Popup)" },
	{ Key = ImGuiLocKey.WindowingUntitled, Text = "(Untitled)" },
	{ Key = ImGuiLocKey.OpenLink_s, Text = "Open '%s'" },
	{ Key = ImGuiLocKey.CopyLink, Text = "Copy Link###CopyLink" },
}

function ImGui.Initialize()
	local g = ImGui.GImGui
	assert(not g.Initialized and not g.SettingsLoaded)

	do
		local ini_handler = Structs.ImGuiSettingsHandler.new()
		ini_handler.TypeName = "Window"
		ini_handler.TypeHash = Base.ImHashStr("Window")
		ini_handler.ClearAllFn = function(...)
			return ImGui.WindowSettingsHandler_ClearAll(...)
		end
		ini_handler.CleanupFn = function(...)
			return ImGui.WindowSettingsHandler_Cleanup(...)
		end
		ini_handler.ReadOpenFn = function(...)
			return ImGui.WindowSettingsHandler_ReadOpen(...)
		end
		ini_handler.ReadLineFn = function(...)
			return ImGui.WindowSettingsHandler_ReadLine(...)
		end
		ini_handler.ApplyAllFn = function(...)
			return ImGui.WindowSettingsHandler_ApplyAll(...)
		end
		ini_handler.WriteAllFn = function(...)
			return ImGui.WindowSettingsHandler_WriteAll(...)
		end
		ImGui.AddSettingsHandler(ini_handler)
	end
	ImGui.TableSettingsAddSettingsHandler()

	ImGui.LocalizeRegisterEntries(GLocalizationEntriesEnUS, #GLocalizationEntriesEnUS)

	ImGui.InitializeDefaultPlatformHandlers(g.PlatformIO)

	local session_datetime = os.date("*t")
	if session_datetime then
		g.PlatformIO.Platform_SessionDate = session_datetime.year * 10000 + session_datetime.month * 100 + session_datetime.day
	end

	local viewport = Structs.ImGuiViewportP.new()
	viewport.ID = IMGUI_VIEWPORT_DEFAULT_ID
	g.Viewports:push_back(viewport)
	g.TempBuffer:resize(1024 * 3 + 1, 0)

	for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
		if (key >= ImGuiKey["0"] and key <= ImGuiKey["9"]) or (key >= ImGuiKey.A and key <= ImGuiKey.Z) or (key >= ImGuiKey.Keypad0 and key <= ImGuiKey.Keypad9)
			or key == ImGuiKey.Tab or key == ImGuiKey.Space or key == ImGuiKey.Apostrophe or key == ImGuiKey.Comma or key == ImGuiKey.Minus or key == ImGuiKey.Period
			or key == ImGuiKey.Slash or key == ImGuiKey.Semicolon or key == ImGuiKey.Equal or key == ImGuiKey.LeftBracket or key == ImGuiKey.RightBracket or key == ImGuiKey.GraveAccent
			or key == ImGuiKey.KeypadDecimal or key == ImGuiKey.KeypadDivide or key == ImGuiKey.KeypadMultiply or key == ImGuiKey.KeypadSubtract or key == ImGuiKey.KeypadAdd or key == ImGuiKey.KeypadEqual
		then
			Base.ImBitArraySetBit(g.KeysMayBeCharInput, key - ImGuiKey.NamedKey_BEGIN)
		end
	end

	local atlas = g.IO.Fonts
	g.DrawListSharedData.Context = g
	ImGui.RegisterFontAtlas(atlas)

	g.Initialized = true
end

function ImGui.Shutdown()
	local g = ImGui.GImGui
	if g.IO.BackendPlatformUserData ~= nil then
		if ImGui.ErrorLog("Forgot to shutdown Platform backend?") then
			assert(false, "Forgot to shutdown Platform backend?")
		end
	end
	if g.IO.BackendRendererUserData ~= nil then
		if ImGui.ErrorLog("Forgot to shutdown Renderer backend?") then
			assert(false, "Forgot to shutdown Renderer backend?")
		end
	end

	local atlases = table.clone(g.FontAtlases)
	for n = 1, g.FontAtlases.Size do
		local atlas = atlases[n]
		ImGui.UnregisterFontAtlas(atlas)
		if atlas.OwnerContext == g then
			assert(atlas.RefCount == 0, "Destroying context owning a ImFontAtlas which is still used elsewhere!")
			if atlas.RefCount == 0 then
				atlas.Locked = false
			end
		end
	end
	g.DrawListSharedData.TempBuffer:clear()

	if not g.Initialized then
		return
	end

	if g.SettingsLoaded and g.IO.IniFilename ~= nil then
		ImGui.SaveIniSettingsToDisk(g.IO.IniFilename)
	end

	ImGui.CallContextHooks(g, ImGuiContextHookType.Shutdown)

	g.Windows:clear()
	g.WindowsFocusOrder:clear()
	g.WindowsTempSortBuffer:clear()
	g.CurrentWindow = nil
	g.CurrentWindowStack:clear()
	g.WindowsById:Clear()
	g.NavWindow = nil
	g.HoveredWindow = nil
	g.HoveredWindowUnderMovingWindow = nil
	g.ActiveIdWindow = nil
	g.MovingWindow = nil

	g.KeysRoutingTable:Clear()

	g.ColorStack:clear()
	g.StyleVarStack:clear()
	g.FontStack:clear()
	g.OpenPopupStack:clear()
	g.BeginPopupStack:clear()
	g.TreeNodeStack:clear()

	g.Viewports:clear()

	g.TabBars:Clear()
	g.CurrentTabBarStack:clear()
	g.ShrinkWidthBuffer:clear()

	g.ClipperTempData:clear()

	g.Tables:Clear()
	g.TablesTempData:clear()
	g.DrawChannelsTempMergeBuffer:clear()

	g.MultiSelectStorage:Clear()
	g.MultiSelectTempData:clear()

	g.ClipboardHandlerData:clear()
	g.MenusIdSubmittedThisFrame:clear()
	g.InputTextState:ClearFreeMemory()
	g.InputTextLineIndex:clear()
	g.InputTextDeactivatedState:ClearFreeMemory()

	g.SettingsWindows:clear()
	g.SettingsHandlers:clear()

	if g.LogFile then
		Base.ImFileClose(g.LogFile)
		g.LogFile = nil
	end
	g.LogBuffer:clear()
	g.DebugLogBuf:clear()
	g.DebugLogIndex:clear()

	g.Initialized = false
end

function ImGui.SetContextName(ctx, name)
	ctx.ContextName = string.sub(name, 1, 15)
end

function ImGui.AddContextHook(ctx, hook)
	local g = ctx
	assert(hook.Callback ~= nil and hook.HookId == 0 and hook.Type ~= ImGuiContextHookType.PendingRemoval_)
	local copy = Structs.ImGuiContextHook.new()
	copy.HookId = hook.HookId
	copy.Type = hook.Type
	copy.Owner = hook.Owner
	copy.Callback = hook.Callback
	copy.UserData = hook.UserData
	g.Hooks:push_back(copy)
	g.HookIdNext += 1
	g.Hooks:back().HookId = g.HookIdNext
	return g.HookIdNext
end

function ImGui.RemoveContextHook(ctx, hook_id)
	local g = ctx
	assert(hook_id ~= 0)
	for n = 1, g.Hooks.Size do
		local hook = g.Hooks[n]
		if hook.HookId == hook_id then
			hook.Type = ImGuiContextHookType.PendingRemoval_
		end
	end
end

function ImGui.CallContextHooks(ctx, hook_type)
	local g = ctx
	for n = 1, g.Hooks.Size do
		local hook = g.Hooks[n]
		if hook.Type == hook_type then
			hook.Callback(g, hook)
		end
	end
end

return true
