--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local DrawList = require("./DrawList")

local ImVec2, ImVec4, ImRect = Base.ImVec2, Base.ImVec4, Base.ImRect
local ImMin, ImMax, ImClamp, ImLerp = Base.ImMin, Base.ImMax, Base.ImClamp, Base.ImLerp
local ImTrunc, IM_TRUNC = Base.ImTrunc, Base.IM_TRUNC
local ImIsPowerOfTwo = Base.ImIsPowerOfTwo
local ImRoundPositive64 = Base.ImRoundPositive64
local IM_COL32 = Base.IM_COL32
local FLT_MAX = Base.FLT_MAX
local vcreate = vector.create

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiFocusedFlags = Enums.ImGuiFocusedFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiDir = Enums.ImGuiDir
local ImGuiCol = Enums.ImGuiCol
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiMouseSource = Enums.ImGuiMouseSource
local ImGuiCond = Enums.ImGuiCond
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiTooltipFlags = Enums.ImGuiTooltipFlags
local ImGuiLayoutType = Enums.ImGuiLayoutType
local ImGuiNextWindowDataFlags = Enums.ImGuiNextWindowDataFlags
local ImGuiNextItemDataFlags = Enums.ImGuiNextItemDataFlags
local ImGuiPopupPositionPolicy = Enums.ImGuiPopupPositionPolicy
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiScrollFlags = Enums.ImGuiScrollFlags
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiSelectionUserData = Enums.ImGuiSelectionUserData

local bor, band, bnot, btest, lshift, rshift = bit32.bor, bit32.band, bit32.bnot, bit32.btest, bit32.lshift, bit32.rshift

local TOOLTIP_DEFAULT_OFFSET_MOUSE = ImVec2(16, 10)
local TOOLTIP_DEFAULT_OFFSET_TOUCH = ImVec2(0, -20)
local TOOLTIP_DEFAULT_PIVOT_TOUCH = ImVec2(0.5, 1.0)


function ImGui.IM_ASSERT_USER_ERROR(expr, msg)
	if not expr then
		if ImGui.ErrorLog(msg) then
			assert(expr, msg)
		end
	end
end

local IM_ASSERT_USER_ERROR = ImGui.IM_ASSERT_USER_ERROR

function ImGui.DebugCheckVersionAndDataLayout(version, sz_io, sz_style, sz_vec2, sz_vec4, sz_vert, sz_idx)
	return true
end

function ImGui.ErrorCheckUsingSetCursorPosToExtendParentBoundaries()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(window.DC.IsSetPos)
	window.DC.IsSetPos = false
	if window.DC.CursorPos.x <= window.DC.CursorMaxPos.x and window.DC.CursorPos.y <= window.DC.CursorMaxPos.y then
		return
	end
	if window.SkipItems then
		return
	end
	IM_ASSERT_USER_ERROR(false, "Code uses SetCursorPos()/SetCursorScreenPos() to extend window/parent boundaries.\nPlease submit an item e.g. Dummy() afterwards in order to grow window/parent boundaries.")
end

function ImGui.ErrorCheckNewFrameSanityChecks()
	local g = ImGui.GImGui

	assert(g.Initialized)
	assert(g.IO.DeltaTime > 0.0 or g.FrameCount == 0, "Need a positive DeltaTime!")
	assert(g.FrameCount == 0 or g.FrameCountEnded == g.FrameCount, "Forgot to call Render() or EndFrame() at the end of the previous frame?")
	assert(g.IO.DisplaySize.x >= 0.0 and g.IO.DisplaySize.y >= 0.0, "Invalid DisplaySize value!")
	assert(g.Style.CurveTessellationMaxError > 0.0, "Invalid style setting!")
	assert(g.Style.CircleTessellationMaxError > 0.0, "Invalid style setting!")
	assert(g.Style.Alpha >= 0.0 and g.Style.Alpha <= 1.0, "Invalid style setting!")
	assert(g.Style.WindowMinSize.x >= 1.0 and g.Style.WindowMinSize.y >= 1.0, "Invalid style setting!")
	assert(g.Style.WindowBorderHoverPadding > 0.0, "Invalid style setting!")
	assert(g.Style.WindowMenuButtonPosition == ImGuiDir.None or g.Style.WindowMenuButtonPosition == ImGuiDir.Left or g.Style.WindowMenuButtonPosition == ImGuiDir.Right)
	assert(g.Style.ColorButtonPosition == ImGuiDir.Left or g.Style.ColorButtonPosition == ImGuiDir.Right)
	assert(ImIsPowerOfTwo(band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.DisplayMask_)))
	assert(ImIsPowerOfTwo(band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.DataTypeMask_)))
	assert(ImIsPowerOfTwo(band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.PickerMask_)))
	assert(ImIsPowerOfTwo(band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.InputMask_)))

	assert(g.Style.TreeLinesFlags == ImGuiTreeNodeFlags.DrawLinesNone or g.Style.TreeLinesFlags == ImGuiTreeNodeFlags.DrawLinesFull or g.Style.TreeLinesFlags == ImGuiTreeNodeFlags.DrawLinesToNodes)
	assert(g.IO.MouseSingleClickDelay > g.IO.MouseDoubleClickTime)

	if g.IO.ConfigErrorRecovery then
		assert(g.IO.ConfigErrorRecoveryEnableAssert or g.IO.ConfigErrorRecoveryEnableDebugLog or g.IO.ConfigErrorRecoveryEnableTooltip or g.ErrorCallback ~= nil)
	end
end

function ImGui.ErrorCheckEndFrameSanityChecks()
	local g = ImGui.GImGui
	local key_mods = ImGui.GetMergedModsFromKeys()
	assert(key_mods == 0 or g.IO.KeyMods == key_mods, "Mismatching io.KeyCtrl/io.KeyShift/io.KeyAlt/io.KeySuper vs io.KeyMods")

	assert(g.CurrentWindowStack.Size == 1)
	assert(g.CurrentWindowStack[1].Window.IsFallbackWindow)
end

function ImGui.ErrorRecoveryStoreState(state_out)
	local g = ImGui.GImGui
	state_out.SizeOfWindowStack = g.CurrentWindowStack.Size
	state_out.SizeOfIDStack = g.CurrentWindow.IDStack.Size
	state_out.SizeOfTreeStack = g.CurrentWindow.DC.TreeDepth
	state_out.SizeOfColorStack = g.ColorStack.Size
	state_out.SizeOfStyleVarStack = g.StyleVarStack.Size
	state_out.SizeOfFontStack = g.FontStack.Size
	state_out.SizeOfFocusScopeStack = g.FocusScopeStack.Size
	state_out.SizeOfGroupStack = g.GroupStack.Size
	state_out.SizeOfItemFlagsStack = g.ItemFlagsStack.Size
	state_out.SizeOfBeginPopupStack = g.BeginPopupStack.Size
	state_out.SizeOfDisabledStack = g.DisabledStackSize
end

function ImGui.ErrorRecoveryTryToRecoverState(state_in)
	local g = ImGui.GImGui
	while g.CurrentWindowStack.Size > state_in.SizeOfWindowStack do
		local window = g.CurrentWindow
		if btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
			if g.CurrentTable ~= nil and g.CurrentTable.InnerWindow == g.CurrentWindow then
				IM_ASSERT_USER_ERROR(false, "Missing EndTable()")
				ImGui.EndTable()
			else
				IM_ASSERT_USER_ERROR(false, "Missing EndChild()")
				ImGui.EndChild()
			end
		else
			IM_ASSERT_USER_ERROR(false, "Missing End()")
			ImGui.End()
		end
	end
	if g.CurrentWindowStack.Size == state_in.SizeOfWindowStack then
		ImGui.ErrorRecoveryTryToRecoverWindowState(state_in)
	end
end

function ImGui.ErrorRecoveryTryToRecoverWindowState(state_in)
	local g = ImGui.GImGui

	while g.CurrentTable ~= nil and g.CurrentTable.InnerWindow == g.CurrentWindow do
		IM_ASSERT_USER_ERROR(false, "Missing EndTable()")
		ImGui.EndTable()
	end

	local window = g.CurrentWindow

	while g.CurrentTabBar ~= nil and g.CurrentTabBar.Window == window do
		IM_ASSERT_USER_ERROR(false, "Missing EndTabBar()")
		ImGui.EndTabBar()
	end
	while g.CurrentMultiSelect ~= nil and g.CurrentMultiSelect.Storage.Window == window do
		IM_ASSERT_USER_ERROR(false, "Missing EndMultiSelect()")
		ImGui.EndMultiSelect()
	end
	if window.DC.MenuBarAppending then
		IM_ASSERT_USER_ERROR(false, "Missing EndMenuBar()")
		ImGui.EndMenuBar()
	end
	while window.DC.TreeDepth > state_in.SizeOfTreeStack do
		IM_ASSERT_USER_ERROR(false, "Missing TreePop()")
		ImGui.TreePop()
	end
	while g.GroupStack.Size > state_in.SizeOfGroupStack do
		IM_ASSERT_USER_ERROR(false, "Missing EndGroup()")
		ImGui.EndGroup()
	end
	assert(g.GroupStack.Size == state_in.SizeOfGroupStack)
	while window.IDStack.Size > state_in.SizeOfIDStack do
		IM_ASSERT_USER_ERROR(false, "Missing PopID()")
		ImGui.PopID()
	end
	while g.DisabledStackSize > state_in.SizeOfDisabledStack do
		IM_ASSERT_USER_ERROR(false, "Missing EndDisabled()")
		if btest(g.CurrentItemFlags, ImGuiItemFlags.Disabled) then
			ImGui.EndDisabled()
		else
			ImGui.EndDisabledOverrideReenable()
			g.CurrentWindowStack:back().DisabledOverrideReenable = false
		end
	end
	assert(g.DisabledStackSize == state_in.SizeOfDisabledStack)
	while g.ColorStack.Size > state_in.SizeOfColorStack do
		IM_ASSERT_USER_ERROR(false, "Missing PopStyleColor()")
		ImGui.PopStyleColor()
	end
	while g.ItemFlagsStack.Size > state_in.SizeOfItemFlagsStack do
		IM_ASSERT_USER_ERROR(false, "Missing PopItemFlag()")
		ImGui.PopItemFlag()
	end
	while g.StyleVarStack.Size > state_in.SizeOfStyleVarStack do
		IM_ASSERT_USER_ERROR(false, "Missing PopStyleVar()")
		ImGui.PopStyleVar()
	end
	while g.FontStack.Size > state_in.SizeOfFontStack do
		IM_ASSERT_USER_ERROR(false, "Missing PopFont()")
		ImGui.PopFont()
	end
	while g.FocusScopeStack.Size > state_in.SizeOfFocusScopeStack do
		IM_ASSERT_USER_ERROR(false, "Missing PopFocusScope()")
		ImGui.PopFocusScope()
	end
end

function ImGui.ErrorLog(msg)
	local g = ImGui.GImGui

	local window = g.CurrentWindow

	if g.IO.ConfigErrorRecoveryEnableDebugLog then
		if g.ErrorFirst then
			if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventError) then
				ImGui.DebugLog("[imgui-error] (current settings: Assert=%d, Log=%d, Tooltip=%d)\n",
					g.IO.ConfigErrorRecoveryEnableAssert and 1 or 0, g.IO.ConfigErrorRecoveryEnableDebugLog and 1 or 0, g.IO.ConfigErrorRecoveryEnableTooltip and 1 or 0)
			else
				g.DebugLogSkippedErrors += 1
			end
		end
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventError) then
			ImGui.DebugLog("[imgui-error] In window '%s': %s\n", window and window.Name or "NULL", msg)
		else
			g.DebugLogSkippedErrors += 1
		end
	end
	g.ErrorFirst = false

	if g.IO.ConfigErrorRecoveryEnableTooltip then
		if g.WithinFrameScope and ImGui.BeginErrorTooltip() then
			if g.ErrorCountCurrentFrame < 20 then
				ImGui.Text("In window '%s': %s", window and window.Name or "NULL", msg)
				if window and (not window.IsFallbackWindow or window.WasActive) then
					ImGui.GetForegroundDrawList(window):AddRect(window.Pos, window.Pos + window.Size, IM_COL32(255, 0, 0, 255))
				end
			end
			if g.ErrorCountCurrentFrame == 20 then
				ImGui.Text("(and more errors)")
			end
			ImGui.EndErrorTooltip()
		end
		g.ErrorCountCurrentFrame += 1
	end

	if g.ErrorCallback ~= nil then
		g.ErrorCallback(g, g.ErrorCallbackUserData, msg)
	end

	return g.IO.ConfigErrorRecoveryEnableAssert
end

function ImGui.ErrorCheckEndFrameFinalizeErrorTooltip()
	local g = ImGui.GImGui
	if g.DebugDrawIdConflictsId ~= 0 and g.IO.KeyCtrl == false then
		g.DebugDrawIdConflictsCount = g.HoveredIdPreviousFrameItemCount
	end
	if g.DebugDrawIdConflictsId ~= 0 and g.DebugItemPickerActive == false and ImGui.BeginErrorTooltip() then
		ImGui.Text("Programmer error: %d visible items with conflicting ID!", g.DebugDrawIdConflictsCount)
		ImGui.BulletText("Code should use PushID()/PopID() in loops, or append \"##xx\" to same-label identifiers!")
		ImGui.BulletText("Empty label e.g. Button(\"\") == same ID as parent widget/node. Use Button(\"##xx\") instead!")
		ImGui.BulletText("Set io.ConfigDebugHighlightIdConflicts=false to disable this warning in non-programmers builds.")
		ImGui.Separator()
		if g.IO.ConfigDebugHighlightIdConflictsShowItemPicker then
			ImGui.Text("(Hold Ctrl to: use ")
			ImGui.SameLine(0.0, 0.0)
			if ImGui.SmallButton("Item Picker") then
				ImGui.DebugStartItemPicker()
			end
			ImGui.SameLine(0.0, 0.0)
			ImGui.Text(" to break in item call-stack, or ")
		else
			ImGui.Text("(Hold Ctrl to: ")
		end
		ImGui.SameLine(0.0, 0.0)
		ImGui.TextLinkOpenURL("read FAQ \"About ID Stack System\"", "https://github.com/ocornut/imgui/blob/master/docs/FAQ.md#qa-usage")
		ImGui.SameLine(0.0, 0.0)
		ImGui.Text(")")
		ImGui.EndErrorTooltip()
	end

	if g.ErrorCountCurrentFrame > 0 and ImGui.BeginErrorTooltip() then
		ImGui.Separator()
		ImGui.Text("(Hold Ctrl to: ")
		ImGui.SameLine(0.0, 0.0)
		if ImGui.SmallButton("Enable Asserts") then
			g.IO.ConfigErrorRecoveryEnableAssert = true
		end
		ImGui.SameLine(0, 0)
		ImGui.Text(")")
		ImGui.EndErrorTooltip()
	end
end

function ImGui.BeginErrorTooltip()
	local g = ImGui.GImGui
	local window = ImGui.FindWindowByName("##Tooltip_Error")
	local use_locked_pos = (g.IO.KeyCtrl and window ~= nil and window.WasActive)
	local c = g.Style.Colors[ImGuiCol.PopupBg + 1]
	ImGui.PushStyleColor(ImGuiCol.PopupBg, ImVec4(c.x + (1.0 - c.x) * 0.15, c.y + (0.0 - c.y) * 0.15, c.z + (0.0 - c.z) * 0.15, c.w + (1.0 - c.w) * 0.15))
	if use_locked_pos then
		ImGui.SetNextWindowPos(g.ErrorTooltipLockedPos)
	end
	local is_visible = ImGui.Begin("##Tooltip_Error", nil, bor(ImGuiWindowFlags.Tooltip, ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.AlwaysAutoResize))
	ImGui.PopStyleColor()
	if is_visible and g.CurrentWindow.BeginCount == 1 then
		ImGui.SeparatorText("MESSAGE FROM DEAR IMGUI")
		ImGui.BringWindowToDisplayFront(g.CurrentWindow)
		ImGui.BringWindowToFocusFront(g.CurrentWindow)
		g.ErrorTooltipLockedPos = ImGui.GetWindowPos()
	elseif not is_visible then
		ImGui.End()
	end
	return is_visible
end

function ImGui.EndErrorTooltip()
	ImGui.End()
end

function ImGui.KeepAliveID(id)
	local g = ImGui.GImGui
	if g.ActiveId == id then
		g.ActiveIdIsAlive = id
	end
	if g.DeactivatedItemData.ID == id then
		g.DeactivatedItemData.IsAlive = true
	end
end

function ImGui.ItemAdd(bb, id, nav_bb_arg, extra_flags)
	if extra_flags == nil then extra_flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local last_item = g.LastItemData
	last_item.ID = id
	last_item.Rect = bb
	last_item.NavRect = nav_bb_arg or bb
	last_item.ItemFlags = bor(g.CurrentItemFlags, g.NextItemData.ItemFlagsSet, extra_flags)
	last_item.StatusFlags = ImGuiItemStatusFlags.None

	if id ~= 0 then
		ImGui.KeepAliveID(id)

		if not btest(last_item.ItemFlags, ImGuiItemFlags.NoNav) then
			window.DC.NavLayersActiveMaskNext = bor(window.DC.NavLayersActiveMaskNext, lshift(1, window.DC.NavLayerCurrent))
			if g.NavId == id or g.NavAnyRequest then
				if g.NavWindow.RootWindowForNav == window.RootWindowForNav then
					if window == g.NavWindow or btest(bor(window.ChildFlags, g.NavWindow.ChildFlags), ImGuiChildFlags.NavFlattened) then
						ImGui.NavProcessItem()
					end
				end
			end
		end

		if btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasShortcut) then
			ImGui.ItemHandleShortcut(id)
		end
	end

	g.NextItemData.HasFlags = ImGuiNextItemDataFlags.None
	g.NextItemData.ItemFlagsSet = ImGuiItemFlags.None

	local clip_rect, bb_min, bb_max = window.ClipRect, bb.Min, bb.Max
	local is_rect_visible = clip_rect.Min.y < bb_max.y and clip_rect.Max.y > bb_min.y and clip_rect.Min.x < bb_max.x and clip_rect.Max.x > bb_min.x
	if not is_rect_visible then
		if id == 0 or (id ~= g.ActiveId and id ~= g.ActiveIdPreviousFrame and id ~= g.NavId and id ~= g.NavActivateId) then
			if not g.ItemUnclipByLog then
				return false
			end
		end
	end

	if id ~= 0 then
		if id == g.DebugLocateId then
			ImGui.DebugLocateItemResolveWithLastItem()
		end

		assert(id ~= window.ID, "Cannot have an empty ID at the root of a window. If you need an empty label, use ## and read the FAQ about how the ID Stack works!")
	end

	if id ~= 0 and g.DeactivatedItemData.ID == id then
		g.DeactivatedItemData.ElapseFrame = g.FrameCount
	end

	if is_rect_visible then
		last_item.StatusFlags = bor(last_item.StatusFlags, ImGuiItemStatusFlags.Visible)
	end
	if ImGui.IsMouseHoveringRect(bb.Min, bb.Max) then
		last_item.StatusFlags = bor(last_item.StatusFlags, ImGuiItemStatusFlags.HoveredRect)
	end
	return true
end

function ImGui.ItemSize(size, text_baseline_y)
	if text_baseline_y == nil then text_baseline_y = -1.0 end
	if type(size) ~= "vector" then
		size = size:GetSize()
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end
	local dc = window.DC

	local offset_to_match_baseline_y = 0.0
	if text_baseline_y >= 0 then
		local d = dc.CurrLineTextBaseOffset - text_baseline_y
		offset_to_match_baseline_y = if 0.0 >= d then 0.0 else d
	end

	local line_y1 = if dc.IsSameLine then dc.CursorPosPrevLine.y else dc.CursorPos.y
	local cur_line_y, fit_y = dc.CurrLineSize.y, dc.CursorPos.y - line_y1 + size.y + offset_to_match_baseline_y
	local line_height = if cur_line_y >= fit_y then cur_line_y else fit_y

	local prev_line_pos = vcreate(dc.CursorPos.x + size.x, line_y1, 0)
	dc.CursorPosPrevLine = prev_line_pos
	local cursor_pos = vcreate(IM_TRUNC(window.Pos.x + dc.Indent.x + dc.ColumnsOffset.x), IM_TRUNC(line_y1 + line_height + g.Style.ItemSpacing.y), 0)
	dc.CursorPos = cursor_pos
	local max_pos, max_y = dc.CursorMaxPos, cursor_pos.y - g.Style.ItemSpacing.y
	dc.CursorMaxPos = vcreate(if max_pos.x >= prev_line_pos.x then max_pos.x else prev_line_pos.x, if max_pos.y >= max_y then max_pos.y else max_y, 0)

	dc.PrevLineSize = vcreate(dc.PrevLineSize.x, line_height, 0)
	dc.CurrLineSize = vcreate(dc.CurrLineSize.x, 0.0, 0)
	local cur_base = dc.CurrLineTextBaseOffset
	dc.PrevLineTextBaseOffset = if cur_base >= text_baseline_y then cur_base else text_baseline_y
	dc.CurrLineTextBaseOffset = 0.0
	dc.IsSameLine = false
	dc.IsSetPos = false

	if dc.LayoutType == ImGuiLayoutType.Horizontal then
		ImGui.SameLine()
	end
end

function ImGui.SameLine(offset_from_start_x, spacing_w)
	if offset_from_start_x == nil then offset_from_start_x = 0.0 end
	if spacing_w == nil then spacing_w = -1.0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	if offset_from_start_x ~= 0.0 then
		if spacing_w < 0.0 then
			spacing_w = 0.0
		end
		window.DC.CursorPos = ImVec2(window.Pos.x - window.Scroll.x + offset_from_start_x + spacing_w + window.DC.GroupOffset.x + window.DC.ColumnsOffset.x, window.DC.CursorPosPrevLine.y)
	else
		if spacing_w < 0.0 then
			spacing_w = g.Style.ItemSpacing.x
		end
		window.DC.CursorPos = ImVec2(window.DC.CursorPosPrevLine.x + spacing_w, window.DC.CursorPosPrevLine.y)
	end
	window.DC.CurrLineSize = window.DC.PrevLineSize
	window.DC.CurrLineTextBaseOffset = window.DC.PrevLineTextBaseOffset
	window.DC.IsSameLine = true
end

function ImGui.GetCursorScreenPos()
	local window = ImGui.GImGui.CurrentWindow
	return window.DC.CursorPos
end

function ImGui.SetCursorScreenPos(pos)
	local window = ImGui.GImGui.CurrentWindow
	window.WriteAccessed = true
	window.DC.CursorPos = pos
	window.DC.IsSetPos = true
end

function ImGui.GetCursorPos()
	local window = ImGui.GImGui.CurrentWindow
	return window.DC.CursorPos - window.Pos + window.Scroll
end

function ImGui.GetCursorPosX()
	local window = ImGui.GImGui.CurrentWindow
	return window.DC.CursorPos.x - window.Pos.x + window.Scroll.x
end

function ImGui.GetCursorPosY()
	local window = ImGui.GImGui.CurrentWindow
	return window.DC.CursorPos.y - window.Pos.y + window.Scroll.y
end

function ImGui.SetCursorPos(local_pos)
	local window = ImGui.GImGui.CurrentWindow
	window.WriteAccessed = true
	window.DC.CursorPos = window.Pos - window.Scroll + local_pos
	window.DC.IsSetPos = true
end

function ImGui.SetCursorPosX(x)
	local window = ImGui.GImGui.CurrentWindow
	window.WriteAccessed = true
	window.DC.CursorPos = ImVec2(window.Pos.x - window.Scroll.x + x, window.DC.CursorPos.y)
	window.DC.IsSetPos = true
end

function ImGui.SetCursorPosY(y)
	local window = ImGui.GImGui.CurrentWindow
	window.WriteAccessed = true
	window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, window.Pos.y - window.Scroll.y + y)
	window.DC.IsSetPos = true
end

function ImGui.GetCursorStartPos()
	local window = ImGui.GImGui.CurrentWindow
	return window.DC.CursorStartPos - window.Pos
end

function ImGui.Indent(indent_w)
	if indent_w == nil then indent_w = 0.0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	window.WriteAccessed = true
	window.DC.Indent.x += if indent_w ~= 0.0 then indent_w else g.Style.IndentSpacing
	window.DC.CursorPos = ImVec2(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x, window.DC.CursorPos.y)
end

function ImGui.Unindent(indent_w)
	if indent_w == nil then indent_w = 0.0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	window.WriteAccessed = true
	window.DC.Indent.x -= if indent_w ~= 0.0 then indent_w else g.Style.IndentSpacing
	window.DC.CursorPos = ImVec2(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x, window.DC.CursorPos.y)
end

function ImGui.SetNextItemWidth(item_width)
	local g = ImGui.GImGui
	g.NextItemData.HasFlags = bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasWidth)
	g.NextItemData.Width = item_width
end

function ImGui.PushItemWidth(item_width)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	window.DC.ItemWidthStack:push_back(window.DC.ItemWidth)
	window.DC.ItemWidth = if item_width == 0.0 then window.DC.ItemWidthDefault else item_width
	g.NextItemData.HasFlags = band(g.NextItemData.HasFlags, bnot(ImGuiNextItemDataFlags.HasWidth))
end

function ImGui.PushMultiItemsWidths(components, w_full)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(components > 0)
	local style = g.Style
	window.DC.ItemWidthStack:push_back(window.DC.ItemWidth)
	local w_items = w_full - style.ItemInnerSpacing.x * (components - 1)
	local prev_split = w_items
	for i = components - 1, 1, -1 do
		local next_split = IM_TRUNC(w_items * i / components)
		window.DC.ItemWidthStack:push_back(ImMax(prev_split - next_split, 1.0))
		prev_split = next_split
	end
	window.DC.ItemWidth = ImMax(prev_split, 1.0)
	g.NextItemData.HasFlags = band(g.NextItemData.HasFlags, bnot(ImGuiNextItemDataFlags.HasWidth))
end

function ImGui.PopItemWidth()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.DC.ItemWidthStack.Size <= 0 then
		IM_ASSERT_USER_ERROR(false, "Calling PopItemWidth() too many times!")
		return
	end
	window.DC.ItemWidth = window.DC.ItemWidthStack:back()
	window.DC.ItemWidthStack:pop_back()
end

function ImGui.CalcItemWidth()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local w
	if btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasWidth) then
		w = g.NextItemData.Width
	else
		w = window.DC.ItemWidth
	end
	if w < 0.0 then
		local region_avail_x = ImGui.GetContentRegionAvail().x
		w = ImMax(1.0, region_avail_x + w)
	end
	w = IM_TRUNC(w)
	return w
end

function ImGui.CalcItemSize(size, default_w, default_h)
	local avail
	if size.x < 0.0 or size.y < 0.0 then
		avail = ImGui.GetContentRegionAvail()
	end

	local x, y = size.x, size.y
	if x == 0.0 then
		x = default_w
	elseif x < 0.0 then
		x = ImMax(4.0, avail.x + x)
	end

	if y == 0.0 then
		y = default_h
	elseif y < 0.0 then
		y = ImMax(4.0, avail.y + y)
	end

	return ImVec2(x, y)
end

function ImGui.GetTextLineHeight()
	local g = ImGui.GImGui
	return g.FontSize
end

function ImGui.GetTextLineHeightWithSpacing()
	local g = ImGui.GImGui
	return g.FontSize + g.Style.ItemSpacing.y
end

function ImGui.GetFrameHeight()
	local g = ImGui.GImGui
	return g.FontSize + g.Style.FramePadding.y * 2.0
end

function ImGui.GetFrameHeightWithSpacing()
	local g = ImGui.GImGui
	return g.FontSize + g.Style.FramePadding.y * 2.0 + g.Style.ItemSpacing.y
end

function ImGui.GetContentRegionAvail()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local mx = if (window.DC.CurrentColumns or g.CurrentTable) then window.WorkRect.Max else window.ContentRegionRect.Max
	return mx - window.DC.CursorPos
end

function ImGui.BeginGroup()
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	g.GroupStack:push_back(Structs.ImGuiGroupData.new())
	local group_data = g.GroupStack:back()
	group_data.WindowID = window.ID
	group_data.BackupCursorPos = window.DC.CursorPos
	group_data.BackupCursorPosPrevLine = window.DC.CursorPosPrevLine
	group_data.BackupCursorMaxPos = window.DC.CursorMaxPos
	group_data.BackupIndent = { x = window.DC.Indent.x }
	group_data.BackupGroupOffset = { x = window.DC.GroupOffset.x }
	group_data.BackupCurrLineSize = window.DC.CurrLineSize
	group_data.BackupCurrLineTextBaseOffset = window.DC.CurrLineTextBaseOffset
	group_data.BackupActiveIdIsAlive = g.ActiveIdIsAlive
	group_data.BackupHoveredIdIsAlive = g.HoveredId ~= 0
	group_data.BackupIsSameLine = window.DC.IsSameLine
	group_data.BackupAnyIdHasBeenEditedThisFrame = g.AnyIdHasBeenEditedThisFrame
	group_data.BackupDeactivatedIdIsAlive = g.DeactivatedItemData.IsAlive
	group_data.EmitItem = true

	window.DC.GroupOffset.x = window.DC.CursorPos.x - window.Pos.x - window.DC.ColumnsOffset.x
	window.DC.Indent.x = window.DC.GroupOffset.x
	window.DC.CursorMaxPos = window.DC.CursorPos
	window.DC.CurrLineSize = ImVec2(0.0, 0.0)
	if g.LogEnabled then
		g.LogLinePosY = -FLT_MAX
	end
end

function ImGui.EndGroup()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(g.GroupStack.Size > 0)

	local group_data = g.GroupStack:back()
	assert(group_data.WindowID == window.ID)

	if window.DC.IsSetPos then
		ImGui.ErrorCheckUsingSetCursorPosToExtendParentBoundaries()
	end

	local group_bb = ImRect.new(group_data.BackupCursorPos, ImMax(ImMax(window.DC.CursorMaxPos, g.LastItemData.Rect.Max), group_data.BackupCursorPos))
	window.DC.CursorPos = group_data.BackupCursorPos
	window.DC.CursorPosPrevLine = group_data.BackupCursorPosPrevLine
	window.DC.CursorMaxPos = ImMax(group_data.BackupCursorMaxPos, group_bb.Max)
	window.DC.Indent.x = group_data.BackupIndent.x
	window.DC.GroupOffset.x = group_data.BackupGroupOffset.x
	window.DC.CurrLineSize = group_data.BackupCurrLineSize
	window.DC.CurrLineTextBaseOffset = group_data.BackupCurrLineTextBaseOffset
	window.DC.IsSameLine = group_data.BackupIsSameLine
	if g.LogEnabled then
		g.LogLinePosY = -FLT_MAX
	end

	if not group_data.EmitItem then
		g.GroupStack:pop_back()
		return
	end

	window.DC.CurrLineTextBaseOffset = ImMax(window.DC.PrevLineTextBaseOffset, group_data.BackupCurrLineTextBaseOffset)
	ImGui.ItemSize(group_bb:GetSize())
	ImGui.ItemAdd(group_bb, 0, nil, ImGuiItemFlags.NoTabStop)

	local group_contains_curr_active_id = (group_data.BackupActiveIdIsAlive ~= g.ActiveId) and (g.ActiveIdIsAlive == g.ActiveId) and g.ActiveId ~= 0
	local group_contains_deactivated_id = (group_data.BackupDeactivatedIdIsAlive == false) and (g.DeactivatedItemData.IsAlive == true)
	if group_contains_curr_active_id then
		g.LastItemData.ID = g.ActiveId
	elseif group_contains_deactivated_id then
		g.LastItemData.ID = g.DeactivatedItemData.ID
	end
	g.LastItemData.Rect = group_bb

	local group_contains_curr_hovered_id = (group_data.BackupHoveredIdIsAlive == false) and g.HoveredId ~= 0
	if group_contains_curr_hovered_id then
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
	end

	if g.AnyIdHasBeenEditedThisFrame and not group_data.BackupAnyIdHasBeenEditedThisFrame then
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Edited)
	end

	g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasDeactivated)
	if group_contains_deactivated_id then
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Deactivated)
	end

	g.GroupStack:pop_back()
	if g.DebugShowGroupRects then
		window.DrawList:AddRect(group_bb.Min, group_bb.Max, IM_COL32(255, 0, 255, 255))
	end
end

function ImGui.CalcScrollEdgeSnap(target, snap_min, snap_max, snap_threshold, center_ratio)
	if target <= snap_min + snap_threshold then
		return ImLerp(snap_min, target, center_ratio)
	end
	if target >= snap_max - snap_threshold then
		return ImLerp(target, snap_max, center_ratio)
	end
	return target
end

function ImGui.CalcNextScrollFromScrollTargetAndClamp(window)
	local scroll = { window.Scroll.x, window.Scroll.y }
	local decoration_size = { window.DecoOuterSizeX1 + window.DecoInnerSizeX1 + window.DecoOuterSizeX2, window.DecoOuterSizeY1 + window.DecoInnerSizeY1 + window.DecoOuterSizeY2 }
	local scroll_target_v = { window.ScrollTarget.x, window.ScrollTarget.y }
	local center_ratio_v = { window.ScrollTargetCenterRatio.x, window.ScrollTargetCenterRatio.y }
	local snap_dist_v = { window.ScrollTargetEdgeSnapDist.x, window.ScrollTargetEdgeSnapDist.y }
	local scroll_max_v = { window.ScrollMax.x, window.ScrollMax.y }
	local size_full_v = { window.SizeFull.x, window.SizeFull.y }
	for axis = 1, 2 do
		if scroll_target_v[axis] < FLT_MAX then
			local center_ratio = center_ratio_v[axis]
			local scroll_target = scroll_target_v[axis]
			if snap_dist_v[axis] > 0.0 then
				local snap_min = 0.0
				local snap_max = scroll_max_v[axis] + size_full_v[axis] - decoration_size[axis]
				scroll_target = ImGui.CalcScrollEdgeSnap(scroll_target, snap_min, snap_max, snap_dist_v[axis], center_ratio)
			end
			scroll[axis] = scroll_target - center_ratio * (size_full_v[axis] - decoration_size[axis])
		end
		scroll[axis] = ImRoundPositive64(ImMax(scroll[axis], 0.0))
		if not window.Collapsed and not window.SkipItems then
			scroll[axis] = ImMin(scroll[axis], scroll_max_v[axis])
		end
	end
	return ImVec2(scroll[1], scroll[2])
end

function ImGui.ScrollToItem(flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	ImGui.ScrollToRectEx(window, g.LastItemData.NavRect, flags)
end

function ImGui.ScrollToRect(window, item_rect, flags)
	if flags == nil then flags = 0 end
	ImGui.ScrollToRectEx(window, item_rect, flags)
end

function ImGui.ScrollToRectEx(window, item_rect, flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local scroll_rect = ImRect.new(window.InnerRect.Min - ImVec2(1, 1), window.InnerRect.Max + ImVec2(1, 1))
	scroll_rect = scroll_rect:WithMinX(ImMin(scroll_rect.Min.x + window.DecoInnerSizeX1, scroll_rect.Max.x))
	scroll_rect = scroll_rect:WithMinY(ImMin(scroll_rect.Min.y + window.DecoInnerSizeY1, scroll_rect.Max.y))

	assert(band(flags, ImGuiScrollFlags.MaskX_) == 0 or ImIsPowerOfTwo(band(flags, ImGuiScrollFlags.MaskX_)))
	assert(band(flags, ImGuiScrollFlags.MaskY_) == 0 or ImIsPowerOfTwo(band(flags, ImGuiScrollFlags.MaskY_)))

	local in_flags = flags
	if band(flags, ImGuiScrollFlags.MaskX_) == 0 and window.ScrollbarX then
		flags = bor(flags, ImGuiScrollFlags.KeepVisibleEdgeX)
	end
	if band(flags, ImGuiScrollFlags.MaskY_) == 0 then
		flags = bor(flags, if window.Appearing then ImGuiScrollFlags.AlwaysCenterY else ImGuiScrollFlags.KeepVisibleEdgeY)
	end

	local fully_visible_x = item_rect.Min.x >= scroll_rect.Min.x and item_rect.Max.x <= scroll_rect.Max.x
	local fully_visible_y = item_rect.Min.y >= scroll_rect.Min.y and item_rect.Max.y <= scroll_rect.Max.y
	local can_be_fully_visible_x = (item_rect:GetWidth() + g.Style.ItemSpacing.x * 2.0) <= scroll_rect:GetWidth() or (window.AutoFitFramesX > 0) or btest(window.Flags, ImGuiWindowFlags.AlwaysAutoResize)
	local can_be_fully_visible_y = (item_rect:GetHeight() + g.Style.ItemSpacing.y * 2.0) <= scroll_rect:GetHeight() or (window.AutoFitFramesY > 0) or btest(window.Flags, ImGuiWindowFlags.AlwaysAutoResize)

	if btest(flags, ImGuiScrollFlags.KeepVisibleEdgeX) and not fully_visible_x then
		if item_rect.Min.x < scroll_rect.Min.x or not can_be_fully_visible_x then
			ImGui.SetScrollFromPosX(window, item_rect.Min.x - g.Style.ItemSpacing.x - window.Pos.x, 0.0)
		elseif item_rect.Max.x >= scroll_rect.Max.x then
			ImGui.SetScrollFromPosX(window, item_rect.Max.x + g.Style.ItemSpacing.x - window.Pos.x, 1.0)
		end
	elseif (btest(flags, ImGuiScrollFlags.KeepVisibleCenterX) and not fully_visible_x) or btest(flags, ImGuiScrollFlags.AlwaysCenterX) then
		if can_be_fully_visible_x then
			ImGui.SetScrollFromPosX(window, ImTrunc((item_rect.Min.x + item_rect.Max.x) * 0.5) - window.Pos.x, 0.5)
		else
			ImGui.SetScrollFromPosX(window, item_rect.Min.x - window.Pos.x, 0.0)
		end
	end

	if btest(flags, ImGuiScrollFlags.KeepVisibleEdgeY) and not fully_visible_y then
		if item_rect.Min.y < scroll_rect.Min.y or not can_be_fully_visible_y then
			ImGui.SetScrollFromPosY(window, item_rect.Min.y - g.Style.ItemSpacing.y - window.Pos.y, 0.0)
		elseif item_rect.Max.y >= scroll_rect.Max.y then
			ImGui.SetScrollFromPosY(window, item_rect.Max.y + g.Style.ItemSpacing.y - window.Pos.y, 1.0)
		end
	elseif (btest(flags, ImGuiScrollFlags.KeepVisibleCenterY) and not fully_visible_y) or btest(flags, ImGuiScrollFlags.AlwaysCenterY) then
		if can_be_fully_visible_y then
			ImGui.SetScrollFromPosY(window, ImTrunc((item_rect.Min.y + item_rect.Max.y) * 0.5) - window.Pos.y, 0.5)
		else
			ImGui.SetScrollFromPosY(window, item_rect.Min.y - window.Pos.y, 0.0)
		end
	end

	local next_scroll = ImGui.CalcNextScrollFromScrollTargetAndClamp(window)
	local delta_scroll = next_scroll - window.Scroll

	if not btest(flags, ImGuiScrollFlags.NoScrollParent) and btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
		if btest(in_flags, bor(ImGuiScrollFlags.AlwaysCenterX, ImGuiScrollFlags.KeepVisibleCenterX)) then
			in_flags = bor(band(in_flags, bnot(ImGuiScrollFlags.MaskX_)), ImGuiScrollFlags.KeepVisibleEdgeX)
		end
		if btest(in_flags, bor(ImGuiScrollFlags.AlwaysCenterY, ImGuiScrollFlags.KeepVisibleCenterY)) then
			in_flags = bor(band(in_flags, bnot(ImGuiScrollFlags.MaskY_)), ImGuiScrollFlags.KeepVisibleEdgeY)
		end
		delta_scroll += ImGui.ScrollToRectEx(window.ParentWindow, ImRect.new(item_rect.Min - delta_scroll, item_rect.Max - delta_scroll), in_flags)
	end

	return delta_scroll
end

function ImGui.GetScrollX()
	local window = ImGui.GImGui.CurrentWindow
	return window.Scroll.x
end

function ImGui.GetScrollY()
	local window = ImGui.GImGui.CurrentWindow
	return window.Scroll.y
end

function ImGui.GetScrollMaxX()
	local window = ImGui.GImGui.CurrentWindow
	return window.ScrollMax.x
end

function ImGui.GetScrollMaxY()
	local window = ImGui.GImGui.CurrentWindow
	return window.ScrollMax.y
end

function ImGui.SetScrollX(window, scroll_x)
	if type(window) ~= "table" then
		scroll_x = window
		window = ImGui.GImGui.CurrentWindow
	end
	window.ScrollTarget = ImVec2(scroll_x, window.ScrollTarget.y)
	window.ScrollTargetCenterRatio = ImVec2(0.0, window.ScrollTargetCenterRatio.y)
	window.ScrollTargetEdgeSnapDist = ImVec2(0.0, window.ScrollTargetEdgeSnapDist.y)
end

function ImGui.SetScrollY(window, scroll_y)
	if type(window) ~= "table" then
		scroll_y = window
		window = ImGui.GImGui.CurrentWindow
	end
	window.ScrollTarget = ImVec2(window.ScrollTarget.x, scroll_y)
	window.ScrollTargetCenterRatio = ImVec2(window.ScrollTargetCenterRatio.x, 0.0)
	window.ScrollTargetEdgeSnapDist = ImVec2(window.ScrollTargetEdgeSnapDist.x, 0.0)
end

function ImGui.SetScrollFromPosX(window, local_x, center_x_ratio)
	if type(window) ~= "table" then
		center_x_ratio = if local_x == nil then 0.5 else local_x
		local_x = window
		window = ImGui.GImGui.CurrentWindow
	end
	assert(center_x_ratio >= 0.0 and center_x_ratio <= 1.0)
	window.ScrollTarget = ImVec2(IM_TRUNC(local_x - window.DecoOuterSizeX1 - window.DecoInnerSizeX1 + window.Scroll.x), window.ScrollTarget.y)
	window.ScrollTargetCenterRatio = ImVec2(center_x_ratio, window.ScrollTargetCenterRatio.y)
	window.ScrollTargetEdgeSnapDist = ImVec2(0.0, window.ScrollTargetEdgeSnapDist.y)
end

function ImGui.SetScrollFromPosY(window, local_y, center_y_ratio)
	if type(window) ~= "table" then
		center_y_ratio = if local_y == nil then 0.5 else local_y
		local_y = window
		window = ImGui.GImGui.CurrentWindow
	end
	assert(center_y_ratio >= 0.0 and center_y_ratio <= 1.0)
	window.ScrollTarget = ImVec2(window.ScrollTarget.x, IM_TRUNC(local_y - window.DecoOuterSizeY1 - window.DecoInnerSizeY1 + window.Scroll.y))
	window.ScrollTargetCenterRatio = ImVec2(window.ScrollTargetCenterRatio.x, center_y_ratio)
	window.ScrollTargetEdgeSnapDist = ImVec2(window.ScrollTargetEdgeSnapDist.x, 0.0)
end

function ImGui.SetScrollHereX(center_x_ratio)
	if center_x_ratio == nil then center_x_ratio = 0.5 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local spacing_x = ImMax(window.WindowPadding.x, g.Style.ItemSpacing.x)
	local target_pos_x = ImLerp(g.LastItemData.Rect.Min.x - spacing_x, g.LastItemData.Rect.Max.x + spacing_x, center_x_ratio)
	ImGui.SetScrollFromPosX(window, target_pos_x - window.Pos.x, center_x_ratio)

	window.ScrollTargetEdgeSnapDist = ImVec2(ImMax(0.0, window.WindowPadding.x - spacing_x), window.ScrollTargetEdgeSnapDist.y)
end

function ImGui.SetScrollHereY(center_y_ratio)
	if center_y_ratio == nil then center_y_ratio = 0.5 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local spacing_y = ImMax(window.WindowPadding.y, g.Style.ItemSpacing.y)
	local target_pos_y = ImLerp(window.DC.CursorPosPrevLine.y - spacing_y, window.DC.CursorPosPrevLine.y + window.DC.PrevLineSize.y + spacing_y, center_y_ratio)
	ImGui.SetScrollFromPosY(window, target_pos_y - window.Pos.y, center_y_ratio)

	window.ScrollTargetEdgeSnapDist = ImVec2(window.ScrollTargetEdgeSnapDist.x, ImMax(0.0, window.WindowPadding.y - spacing_y))
end

function ImGui.BeginTooltip()
	return ImGui.BeginTooltipEx(ImGuiTooltipFlags.None, ImGuiWindowFlags.None)
end

function ImGui.BeginItemTooltip()
	if not ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
		return false
	end
	return ImGui.BeginTooltipEx(ImGuiTooltipFlags.None, ImGuiWindowFlags.None)
end

function ImGui.BeginTooltipEx(tooltip_flags, extra_window_flags)
	local g = ImGui.GImGui

	local is_dragdrop_tooltip = g.DragDropWithinSource or g.DragDropWithinTarget
	if is_dragdrop_tooltip then
		local is_touchscreen = (g.IO.MouseSource == ImGuiMouseSource.TouchScreen)
		if band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasPos) == 0 then
			local tooltip_pos = if is_touchscreen then (g.IO.MousePos + TOOLTIP_DEFAULT_OFFSET_TOUCH * g.Style.MouseCursorScale) else (g.IO.MousePos + TOOLTIP_DEFAULT_OFFSET_MOUSE * g.Style.MouseCursorScale)
			local tooltip_pivot = if is_touchscreen then TOOLTIP_DEFAULT_PIVOT_TOUCH else ImVec2(0.0, 0.0)
			ImGui.SetNextWindowPos(tooltip_pos, ImGuiCond.None, tooltip_pivot)
		end

		ImGui.SetNextWindowBgAlpha(g.Style.Colors[ImGuiCol.PopupBg + 1].w * 0.60)
		tooltip_flags = bor(tooltip_flags, ImGuiTooltipFlags.OverridePrevious)
	end

	if btest(tooltip_flags, ImGuiTooltipFlags.OverridePrevious) and g.TooltipPreviousWindow ~= nil and g.TooltipPreviousWindow.Active and not ImGui.IsWindowInBeginStack(g.TooltipPreviousWindow) then
		ImGui.SetWindowHiddenAndSkipItemsForCurrentFrame(g.TooltipPreviousWindow)
		g.TooltipOverrideCount += 1
	end

	local window_name_template = if is_dragdrop_tooltip then "##Tooltip_DragDrop_%02d" else "##Tooltip_%02d"
	local window_name = Base.ImFormatString(window_name_template, g.TooltipOverrideCount)
	local flags = bor(ImGuiWindowFlags.Tooltip, ImGuiWindowFlags.NoInputs, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.AlwaysAutoResize)
	ImGui.Begin(window_name, nil, bor(flags, extra_window_flags))
	return true
end

function ImGui.EndTooltip()
	assert(btest(ImGui.GImGui.CurrentWindow.Flags, ImGuiWindowFlags.Tooltip))
	ImGui.End()
end

function ImGui.SetTooltip(fmt, ...)
	ImGui.SetTooltipV(fmt, ...)
end

function ImGui.SetTooltipV(fmt, ...)
	if not ImGui.BeginTooltipEx(ImGuiTooltipFlags.OverridePrevious, ImGuiWindowFlags.None) then
		return
	end
	ImGui.TextV(fmt, ...)
	ImGui.EndTooltip()
end

function ImGui.SetItemTooltip(fmt, ...)
	if ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
		ImGui.SetTooltipV(fmt, ...)
	end
end

function ImGui.SetItemTooltipV(fmt, ...)
	if ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
		ImGui.SetTooltipV(fmt, ...)
	end
end

local function IsPopupOpenID(id, popup_flags)
	local g = ImGui.GImGui
	if btest(popup_flags, ImGuiPopupFlags.AnyPopupId) then
		assert(id == 0)
		if btest(popup_flags, ImGuiPopupFlags.AnyPopupLevel) then
			return g.OpenPopupStack.Size > 0
		else
			return g.OpenPopupStack.Size > g.BeginPopupStack.Size
		end
	else
		if btest(popup_flags, ImGuiPopupFlags.AnyPopupLevel) then
			for n = 0, g.OpenPopupStack.Size - 1 do
				if g.OpenPopupStack[n + 1].PopupId == id then
					return true
				end
			end
			return false
		else
			return g.OpenPopupStack.Size > g.BeginPopupStack.Size and g.OpenPopupStack[g.BeginPopupStack.Size + 1].PopupId == id
		end
	end
end

function ImGui.IsPopupOpen(str_id_or_id, popup_flags)
	if popup_flags == nil then popup_flags = 0 end
	if type(str_id_or_id) == "number" then
		return IsPopupOpenID(str_id_or_id, popup_flags)
	end
	local g = ImGui.GImGui
	local id = if btest(popup_flags, ImGuiPopupFlags.AnyPopupId) then 0 else g.CurrentWindow:GetID(str_id_or_id)
	if btest(popup_flags, ImGuiPopupFlags.AnyPopupLevel) and id ~= 0 then
		assert(false, "Cannot use IsPopupOpen() with a string id and ImGuiPopupFlags_AnyPopupLevel.")
	end
	return IsPopupOpenID(id, popup_flags)
end

function ImGui.GetTopMostPopupModal()
	local g = ImGui.GImGui
	for n = g.OpenPopupStack.Size - 1, 0, -1 do
		local popup = g.OpenPopupStack[n + 1].Window
		if popup then
			if btest(popup.Flags, ImGuiWindowFlags.Modal) then
				return popup
			end
		end
	end
	return nil
end

function ImGui.GetTopMostAndVisiblePopupModal()
	local g = ImGui.GImGui
	for n = g.OpenPopupStack.Size - 1, 0, -1 do
		local popup = g.OpenPopupStack[n + 1].Window
		if popup then
			if btest(popup.Flags, ImGuiWindowFlags.Modal) and ImGui.IsWindowActiveAndVisible(popup) then
				return popup
			end
		end
	end
	return nil
end

function ImGui.FindBlockingModal(window)
	local g = ImGui.GImGui
	if g.OpenPopupStack.Size <= 0 then
		return nil
	end

	for n = 0, g.OpenPopupStack.Size - 1 do
		local popup_window = g.OpenPopupStack[n + 1].Window
		if popup_window == nil or not btest(popup_window.Flags, ImGuiWindowFlags.Modal) then
			continue
		end
		if not popup_window.Active and not popup_window.WasActive then
			continue
		end
		if window == nil then
			return popup_window
		end
		if ImGui.IsWindowWithinBeginStackOf(window, popup_window) then
			continue
		end
		return popup_window
	end
	return nil
end

function ImGui.OpenPopup(str_id_or_id, popup_flags)
	if popup_flags == nil then popup_flags = 0 end
	if type(str_id_or_id) == "number" then
		return ImGui.OpenPopupEx(str_id_or_id, popup_flags)
	end
	local g = ImGui.GImGui
	local id = g.CurrentWindow:GetID(str_id_or_id)
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventPopup) then
		ImGui.DebugLog("[popup] OpenPopup(\"%s\" -> 0x%08X)\n", str_id_or_id, id)
	end
	return ImGui.OpenPopupEx(id, popup_flags)
end

function ImGui.OpenPopupEx(id, popup_flags)
	if popup_flags == nil then popup_flags = ImGuiPopupFlags.None end
	local g = ImGui.GImGui
	local parent_window = g.CurrentWindow
	local current_stack_size = g.BeginPopupStack.Size

	if btest(popup_flags, ImGuiPopupFlags.NoOpenOverExistingPopup) then
		if ImGui.IsPopupOpen(0, ImGuiPopupFlags.AnyPopupId) then
			return false
		end
	end

	local popup_ref = Structs.ImGuiPopupData.new()
	popup_ref.PopupId = id
	popup_ref.Window = nil
	popup_ref.RestoreNavWindow = g.NavWindow
	popup_ref.OpenFrameCount = g.FrameCount
	popup_ref.OpenParentId = parent_window.IDStack:back()
	popup_ref.OpenPopupPos = ImGui.NavCalcPreferredRefPos(ImGuiWindowFlags.Popup)
	popup_ref.OpenMousePos = if ImGui.IsMousePosValid(g.IO.MousePos) then g.IO.MousePos else popup_ref.OpenPopupPos

	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventPopup) then
		ImGui.DebugLog("[popup] OpenPopupEx(0x%08X)\n", id)
	end
	if g.OpenPopupStack.Size < current_stack_size + 1 then
		g.OpenPopupStack:push_back(popup_ref)
		return true
	else
		local keep_existing = false
		local existing = g.OpenPopupStack[current_stack_size + 1]
		if existing.PopupId == id then
			if (existing.OpenFrameCount == g.FrameCount - 1) or btest(popup_flags, ImGuiPopupFlags.NoReopen) then
				keep_existing = true
			end
		end
		if keep_existing then
			existing.OpenFrameCount = popup_ref.OpenFrameCount
		else
			ImGui.ClosePopupToLevel(current_stack_size, true)
			g.OpenPopupStack:push_back(popup_ref)
		end

		return not keep_existing
	end
end

function ImGui.ClosePopupsOverWindow(ref_window, restore_focus_to_window_under_popup)
	local g = ImGui.GImGui
	if g.OpenPopupStack.Size == 0 then
		return
	end

	local popup_count_to_keep = 0
	if ref_window then
		while popup_count_to_keep < g.OpenPopupStack.Size do
			local popup = g.OpenPopupStack[popup_count_to_keep + 1]
			if not popup.Window then
				popup_count_to_keep += 1
				continue
			end
			assert(btest(popup.Window.Flags, ImGuiWindowFlags.Popup))

			local ref_window_is_descendant_of_popup = false
			for n = popup_count_to_keep, g.OpenPopupStack.Size - 1 do
				local popup_window = g.OpenPopupStack[n + 1].Window
				if popup_window then
					if ImGui.IsWindowWithinBeginStackOf(ref_window, popup_window) then
						ref_window_is_descendant_of_popup = true
						break
					end
				end
			end
			if not ref_window_is_descendant_of_popup then
				break
			end
			popup_count_to_keep += 1
		end
	end
	if popup_count_to_keep < g.OpenPopupStack.Size then
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventPopup) then
			ImGui.DebugLog("[popup] ClosePopupsOverWindow(\"%s\")\n", if ref_window then ref_window.Name else "<NULL>")
		end
		ImGui.ClosePopupToLevel(popup_count_to_keep, restore_focus_to_window_under_popup)
	end
end

function ImGui.ClosePopupsExceptModals()
	local g = ImGui.GImGui

	local popup_count_to_keep = g.OpenPopupStack.Size
	while popup_count_to_keep > 0 do
		local window = g.OpenPopupStack[popup_count_to_keep].Window
		if not window or btest(window.Flags, ImGuiWindowFlags.Modal) then
			break
		end
		popup_count_to_keep -= 1
	end
	if popup_count_to_keep < g.OpenPopupStack.Size then
		ImGui.ClosePopupToLevel(popup_count_to_keep, true)
	end
end

function ImGui.ClosePopupToLevel(remaining, restore_focus_to_window_under_popup)
	local g = ImGui.GImGui
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventPopup) then
		ImGui.DebugLog("[popup] ClosePopupToLevel(%d), restore_under=%d\n", remaining, restore_focus_to_window_under_popup and 1 or 0)
	end
	assert(remaining >= 0 and remaining < g.OpenPopupStack.Size)
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventPopup) then
		for n = remaining, g.OpenPopupStack.Size - 1 do
			local p = g.OpenPopupStack[n + 1]
			ImGui.DebugLog("[popup] - Closing PopupID 0x%08X Window \"%s\"\n", p.PopupId, if p.Window then p.Window.Name else "(null)")
		end
	end

	local prev_popup = g.OpenPopupStack[remaining + 1]
	g.OpenPopupStack:resize(remaining)

	if restore_focus_to_window_under_popup and prev_popup.Window then
		local popup_window = prev_popup.Window
		local focus_window = if btest(popup_window.Flags, ImGuiWindowFlags.ChildMenu) then popup_window.ParentWindow else prev_popup.RestoreNavWindow
		if focus_window and not focus_window.WasActive then
			ImGui.FocusTopMostWindowUnderOne(popup_window, nil, nil, ImGuiFocusRequestFlags.RestoreFocusedChild)
		else
			ImGui.FocusWindow(focus_window, if g.NavLayer == ImGuiNavLayer.Main then ImGuiFocusRequestFlags.RestoreFocusedChild else ImGuiFocusRequestFlags.None)
		end
	end
end

function ImGui.CloseCurrentPopup()
	local g = ImGui.GImGui
	local popup_idx = g.BeginPopupStack.Size - 1
	if popup_idx < 0 or popup_idx >= g.OpenPopupStack.Size or g.BeginPopupStack[popup_idx + 1].PopupId ~= g.OpenPopupStack[popup_idx + 1].PopupId then
		return
	end

	while popup_idx > 0 do
		local popup_window = g.OpenPopupStack[popup_idx + 1].Window
		local parent_popup_window = g.OpenPopupStack[popup_idx].Window
		local close_parent = false
		if popup_window and btest(popup_window.Flags, ImGuiWindowFlags.ChildMenu) then
			if parent_popup_window and not btest(parent_popup_window.Flags, ImGuiWindowFlags.MenuBar) then
				close_parent = true
			end
		end
		if not close_parent then
			break
		end
		popup_idx -= 1
	end
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventPopup) then
		ImGui.DebugLog("[popup] CloseCurrentPopup %d -> %d\n", g.BeginPopupStack.Size - 1, popup_idx)
	end
	ImGui.ClosePopupToLevel(popup_idx, true)

	local window = g.NavWindow
	if window then
		window.DC.NavHideHighlightOneFrame = true
	end
end

function ImGui.BeginPopupEx(id, extra_window_flags)
	local g = ImGui.GImGui
	if not ImGui.IsPopupOpen(id, ImGuiPopupFlags.None) then
		g.NextWindowData:ClearFlags()
		return false
	end

	assert(band(extra_window_flags, ImGuiWindowFlags.ChildMenu) == 0)
	local name = Base.ImFormatString("##Popup_%08x", id)

	local is_open = ImGui.Begin(name, nil, bor(extra_window_flags, ImGuiWindowFlags.Popup))
	if not is_open then
		ImGui.EndPopup()
	end
	return is_open
end

function ImGui.BeginPopupMenuEx(id, label, extra_window_flags)
	local g = ImGui.GImGui
	if not ImGui.IsPopupOpen(id, ImGuiPopupFlags.None) then
		g.NextWindowData:ClearFlags()
		return false
	end

	if btest(extra_window_flags, ImGuiWindowFlags.ChildWindow) and btest(extra_window_flags, ImGuiWindowFlags.AlwaysAutoResize) then
		ImGui.SetNextWindowChildFlags(ImGuiChildFlags.AlwaysAutoResize, true)
	end

	assert(btest(extra_window_flags, ImGuiWindowFlags.ChildMenu))
	local name = Base.ImFormatString("%s###Menu_%02d", label, g.BeginMenuDepth)
	local is_open = ImGui.Begin(name, nil, bor(extra_window_flags, ImGuiWindowFlags.Popup))
	if not is_open then
		ImGui.EndPopup()
	end
	return is_open
end

function ImGui.BeginPopup(str_id, flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	if g.OpenPopupStack.Size <= g.BeginPopupStack.Size then
		g.NextWindowData:ClearFlags()
		return false
	end
	flags = bor(flags, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings)
	local id = g.CurrentWindow:GetID(str_id)
	return ImGui.BeginPopupEx(id, flags)
end

function ImGui.BeginPopupModal(name, p_open, flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local id = window:GetID(name)
	if not ImGui.IsPopupOpen(id, ImGuiPopupFlags.None) then
		g.NextWindowData:ClearFlags()
		if p_open ~= nil and p_open then
			p_open = false
		end
		return false, p_open
	end

	if band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasPos) == 0 then
		local viewport = ImGui.GetMainViewport()
		ImGui.SetNextWindowPos(viewport:GetCenter(), ImGuiCond.FirstUseEver, ImVec2(0.5, 0.5))
	end

	flags = bor(flags, ImGuiWindowFlags.Popup, ImGuiWindowFlags.Modal, ImGuiWindowFlags.NoCollapse)
	local is_open
	is_open, p_open = ImGui.Begin(name, p_open, flags)
	if not is_open or (p_open ~= nil and not p_open) then
		ImGui.EndPopup()
		if is_open then
			ImGui.ClosePopupToLevel(g.BeginPopupStack.Size, true)
		end
		return false, p_open
	end
	return is_open, p_open
end

function ImGui.EndPopup()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if not (btest(window.Flags, ImGuiWindowFlags.Popup) and g.BeginPopupStack.Size > 0) then
		IM_ASSERT_USER_ERROR(false, "Calling EndPopup() in wrong window!")
		return
	end

	if g.NavWindow == window then
		ImGui.NavMoveRequestTryWrapping(window, ImGuiNavMoveFlags.LoopY)
	end

	local backup_within_end_popup_id = g.WithinEndPopupID
	local backup_within_end_child_id = g.WithinEndChildID
	g.WithinEndPopupID = window.ID
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
		g.WithinEndChildID = window.ID
	end
	ImGui.End()
	g.WithinEndPopupID = backup_within_end_popup_id
	g.WithinEndChildID = backup_within_end_child_id
end

function ImGui.GetMouseButtonFromPopupFlags(flags)
	assert(band(flags, ImGuiPopupFlags.InvalidMask_) == 0)
	if btest(flags, ImGuiPopupFlags.MouseButtonMask_) then
		return rshift(band(flags, ImGuiPopupFlags.MouseButtonMask_), ImGuiPopupFlags.MouseButtonShift_) - 1
	end
	return ImGuiMouseButton.Right
end

function ImGui.IsPopupOpenRequestForItem(popup_flags, id)
	local g = ImGui.GImGui
	local mouse_button = ImGui.GetMouseButtonFromPopupFlags(popup_flags)
	if ImGui.IsMouseReleased(mouse_button, id) and ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup) then
		return true
	end
	if g.NavOpenContextMenuItemId == id and (ImGui.IsItemFocused() or id == g.CurrentWindow.MoveId) then
		return true
	end
	return false
end

function ImGui.IsPopupOpenRequestForWindow(popup_flags)
	local g = ImGui.GImGui
	local mouse_button = ImGui.GetMouseButtonFromPopupFlags(popup_flags)
	if ImGui.IsMouseReleased(mouse_button, ImGuiKeyOwner.NoOwner) and ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup) then
		if not btest(popup_flags, ImGuiPopupFlags.NoOpenOverItems) or not ImGui.IsAnyItemHovered() then
			return true
		end
	end
	if g.NavOpenContextMenuWindowId ~= 0 and g.CurrentWindow.ID ~= 0 then
		if ImGui.IsWindowChildOf(g.NavWindow, g.CurrentWindow, false) then
			return true
		end
	end
	return false
end

function ImGui.OpenPopupOnItemClick(str_id, popup_flags)
	if popup_flags == nil then popup_flags = 0 end
	local g = ImGui.GImGui
	if ImGui.IsPopupOpenRequestForItem(popup_flags, g.LastItemData.ID) then
		local window = g.CurrentWindow
		local id = if str_id then window:GetID(str_id) else g.LastItemData.ID
		assert(id ~= 0)
		return ImGui.OpenPopupEx(id, popup_flags)
	end
	return false
end

function ImGui.BeginPopupContextItem(str_id, popup_flags)
	if popup_flags == nil then popup_flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false
	end
	local id = if str_id then window:GetID(str_id) else g.LastItemData.ID
	assert(id ~= 0)
	if ImGui.IsPopupOpenRequestForItem(popup_flags, g.LastItemData.ID) then
		ImGui.OpenPopupEx(id, popup_flags)
	end
	return ImGui.BeginPopupEx(id, bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings))
end

function ImGui.BeginPopupContextWindow(str_id, popup_flags)
	if popup_flags == nil then popup_flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if not str_id then
		str_id = "window_context"
	end
	local id = window:GetID(str_id)
	if ImGui.IsPopupOpenRequestForWindow(popup_flags) then
		ImGui.OpenPopupEx(id, popup_flags)
	end
	return ImGui.BeginPopupEx(id, bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings))
end

function ImGui.BeginPopupContextVoid(str_id, popup_flags)
	if popup_flags == nil then popup_flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if not str_id then
		str_id = "void_context"
	end
	local id = window:GetID(str_id)
	local mouse_button = ImGui.GetMouseButtonFromPopupFlags(popup_flags)
	if ImGui.IsMouseReleased(mouse_button, id) and not ImGui.IsWindowHovered(ImGuiHoveredFlags.AnyWindow) then
		if ImGui.GetTopMostPopupModal() == nil then
			ImGui.OpenPopupEx(id, popup_flags)
		end
	end
	return ImGui.BeginPopupEx(id, bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings))
end

local DIR_ORDER_COMBO = { ImGuiDir.Down, ImGuiDir.Right, ImGuiDir.Left, ImGuiDir.Up }
local DIR_ORDER_DEFAULT = { ImGuiDir.Right, ImGuiDir.Down, ImGuiDir.Up, ImGuiDir.Left }

function ImGui.FindBestWindowPosForPopupEx(ref_pos, size, last_dir, r_outer, r_avoid, policy)
	local base_pos_clamped = ImClamp(ref_pos, r_outer.Min, r_outer.Max - size)

	if policy == ImGuiPopupPositionPolicy.ComboBox then
		for n = if last_dir ~= ImGuiDir.None then -1 else 0, ImGuiDir.COUNT - 1 do
			local dir = if n == -1 then last_dir else DIR_ORDER_COMBO[n + 1]
			if n ~= -1 and dir == last_dir then
				continue
			end
			local pos
			if dir == ImGuiDir.Down then pos = ImVec2(r_avoid.Min.x, r_avoid.Max.y) end
			if dir == ImGuiDir.Right then pos = ImVec2(r_avoid.Min.x, r_avoid.Min.y - size.y) end
			if dir == ImGuiDir.Left then pos = ImVec2(r_avoid.Max.x - size.x, r_avoid.Max.y) end
			if dir == ImGuiDir.Up then pos = ImVec2(r_avoid.Max.x - size.x, r_avoid.Min.y - size.y) end
			if not r_outer:Contains(ImRect.new(pos, pos + size)) then
				continue
			end
			last_dir = dir
			return pos, last_dir
		end
	end

	if policy == ImGuiPopupPositionPolicy.Tooltip or policy == ImGuiPopupPositionPolicy.Default then
		for n = if last_dir ~= ImGuiDir.None then -1 else 0, ImGuiDir.COUNT - 1 do
			local dir = if n == -1 then last_dir else DIR_ORDER_DEFAULT[n + 1]
			if n ~= -1 and dir == last_dir then
				continue
			end

			local avail_w = (if dir == ImGuiDir.Left then r_avoid.Min.x else r_outer.Max.x) - (if dir == ImGuiDir.Right then r_avoid.Max.x else r_outer.Min.x)
			local avail_h = (if dir == ImGuiDir.Up then r_avoid.Min.y else r_outer.Max.y) - (if dir == ImGuiDir.Down then r_avoid.Max.y else r_outer.Min.y)

			if avail_w < size.x and (dir == ImGuiDir.Left or dir == ImGuiDir.Right) then
				continue
			end
			if avail_h < size.y and (dir == ImGuiDir.Up or dir == ImGuiDir.Down) then
				continue
			end

			local px = if dir == ImGuiDir.Left then r_avoid.Min.x - size.x elseif dir == ImGuiDir.Right then r_avoid.Max.x else base_pos_clamped.x
			local py = if dir == ImGuiDir.Up then r_avoid.Min.y - size.y elseif dir == ImGuiDir.Down then r_avoid.Max.y else base_pos_clamped.y

			px = ImMax(px, r_outer.Min.x)
			py = ImMax(py, r_outer.Min.y)

			last_dir = dir
			return ImVec2(px, py), last_dir
		end
	end

	last_dir = ImGuiDir.None

	if policy == ImGuiPopupPositionPolicy.Tooltip then
		return ref_pos + ImVec2(2, 2), last_dir
	end

	local px = ImMax(ImMin(ref_pos.x + size.x, r_outer.Max.x) - size.x, r_outer.Min.x)
	local py = ImMax(ImMin(ref_pos.y + size.y, r_outer.Max.y) - size.y, r_outer.Min.y)
	return ImVec2(px, py), last_dir
end

function ImGui.GetPopupAllowedExtentRect(window)
	local g = ImGui.GImGui
	local r_screen = ImGui.GetMainViewport():GetMainRect()
	local padding = g.Style.DisplaySafeAreaPadding
	r_screen = r_screen:Expanded(ImVec2(if r_screen:GetWidth() > padding.x * 2 then -padding.x else 0.0, if r_screen:GetHeight() > padding.y * 2 then -padding.y else 0.0))
	return r_screen
end

function ImGui.FindBestWindowPosForPopup(window)
	local g = ImGui.GImGui

	local r_outer = ImGui.GetPopupAllowedExtentRect(window)
	local pos
	if btest(window.Flags, ImGuiWindowFlags.ChildMenu) then
		assert(g.CurrentWindow == window)
		local parent_window = g.CurrentWindowStack[g.CurrentWindowStack.Size - 1].Window
		local horizontal_overlap = g.Style.ItemInnerSpacing.x
		local r_avoid
		if parent_window.DC.MenuBarAppending then
			r_avoid = ImRect.fromXY(-FLT_MAX, parent_window.ClipRect.Min.y, FLT_MAX, parent_window.ClipRect.Max.y)
		else
			r_avoid = ImRect.fromXY(parent_window.Pos.x + horizontal_overlap, -FLT_MAX, parent_window.Pos.x + parent_window.Size.x - horizontal_overlap - parent_window.ScrollbarSizes.x, FLT_MAX)
		end
		pos, window.AutoPosLastDirection = ImGui.FindBestWindowPosForPopupEx(window.Pos, window.Size, window.AutoPosLastDirection, r_outer, r_avoid, ImGuiPopupPositionPolicy.Default)
		return pos
	end
	if btest(window.Flags, ImGuiWindowFlags.Popup) then
		pos, window.AutoPosLastDirection = ImGui.FindBestWindowPosForPopupEx(window.Pos, window.Size, window.AutoPosLastDirection, r_outer, ImRect.new(window.Pos, window.Pos), ImGuiPopupPositionPolicy.Default)
		return pos
	end
	if btest(window.Flags, ImGuiWindowFlags.Tooltip) then
		assert(g.CurrentWindow == window)
		local scale = g.Style.MouseCursorScale
		local ref_pos = ImGui.NavCalcPreferredRefPos(ImGuiWindowFlags.Tooltip)

		if g.IO.MouseSource == ImGuiMouseSource.TouchScreen and ImGui.NavCalcPreferredRefPosSource(ImGuiWindowFlags.Tooltip) == ImGuiInputSource.Mouse then
			local tooltip_pos = ref_pos + TOOLTIP_DEFAULT_OFFSET_TOUCH * scale - (TOOLTIP_DEFAULT_PIVOT_TOUCH * window.Size)
			if r_outer:Contains(ImRect.new(tooltip_pos, tooltip_pos + window.Size)) then
				return tooltip_pos
			end
		end

		local tooltip_pos = ref_pos + TOOLTIP_DEFAULT_OFFSET_MOUSE * scale
		local r_avoid
		if g.NavCursorVisible and g.NavHighlightItemUnderNav and not g.IO.ConfigNavMoveSetMousePos then
			r_avoid = ImRect.fromXY(ref_pos.x - 16, ref_pos.y - 8, ref_pos.x + 16, ref_pos.y + 8)
		else
			r_avoid = ImRect.fromXY(ref_pos.x - 16, ref_pos.y - 8, ref_pos.x + 24 * scale, ref_pos.y + 24 * scale)
		end

		pos, window.AutoPosLastDirection = ImGui.FindBestWindowPosForPopupEx(tooltip_pos, window.Size, window.AutoPosLastDirection, r_outer, r_avoid, ImGuiPopupPositionPolicy.Tooltip)
		return pos
	end
	assert(false)
	return window.Pos
end

function ImGui.SetWindowFocus(...)
	if select("#", ...) == 0 then
		ImGui.FocusWindow(ImGui.GImGui.CurrentWindow)
		return
	end
	local name = ...
	if name then
		local window = ImGui.FindWindowByName(name)
		if window then
			ImGui.FocusWindow(window)
		end
	else
		ImGui.FocusWindow(nil)
	end
end

function ImGui.SetNextWindowFocus()
	local g = ImGui.GImGui
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasFocus)
end

function ImGui.IsWindowFocused(flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local ref_window = g.NavWindow
	local cur_window = g.CurrentWindow

	if ref_window == nil then
		return false
	end
	if btest(flags, ImGuiFocusedFlags.AnyWindow) then
		return true
	end

	assert(cur_window)
	local popup_hierarchy = band(flags, ImGuiFocusedFlags.NoPopupHierarchy) == 0
	if btest(flags, ImGuiFocusedFlags.RootWindow) then
		cur_window = ImGui.GetCombinedRootWindow(cur_window, popup_hierarchy)
	end

	if btest(flags, ImGuiFocusedFlags.ChildWindows) then
		return ImGui.IsWindowChildOf(ref_window, cur_window, popup_hierarchy)
	else
		return ref_window == cur_window
	end
end

function ImGui.FindWindowFocusIndex(window)
	local g = ImGui.GImGui
	local order = window.FocusOrder
	assert(window.RootWindow == window)
	assert(g.WindowsFocusOrder[order + 1] == window)
	return order
end

function ImGui.UpdateWindowInFocusOrderList(window, just_created, new_flags)
	local g = ImGui.GImGui

	local new_is_explicit_child = btest(new_flags, ImGuiWindowFlags.ChildWindow) and (not btest(new_flags, ImGuiWindowFlags.Popup) or btest(new_flags, ImGuiWindowFlags.ChildMenu))
	local child_flag_changed = new_is_explicit_child ~= window.IsExplicitChild
	if (just_created or child_flag_changed) and not new_is_explicit_child then
		assert(not g.WindowsFocusOrder:contains(window))
		g.WindowsFocusOrder:push_back(window)
		window.FocusOrder = g.WindowsFocusOrder.Size - 1
	elseif not just_created and child_flag_changed and new_is_explicit_child then
		assert(g.WindowsFocusOrder[window.FocusOrder + 1] == window)
		for n = window.FocusOrder + 1, g.WindowsFocusOrder.Size - 1 do
			local w = g.WindowsFocusOrder[n + 1]
			w.FocusOrder -= 1
		end
		g.WindowsFocusOrder:erase(window.FocusOrder)
		window.FocusOrder = -1
	end
	window.IsExplicitChild = new_is_explicit_child
end

function ImGui.BringWindowToFocusFront(window)
	local g = ImGui.GImGui
	assert(window == window.RootWindow)

	local cur_order = window.FocusOrder
	local order_list = g.WindowsFocusOrder
	assert(order_list[cur_order + 1] == window)
	if order_list:back() == window then
		return
	end

	local new_order = order_list.Size - 1
	for n = cur_order, new_order - 1 do
		local w = order_list[n + 2]
		order_list[n + 1] = w
		w.FocusOrder -= 1
		assert(w.FocusOrder == n)
	end
	order_list[new_order + 1] = window
	window.FocusOrder = new_order
end

function ImGui.BringWindowToDisplayFront(window)
	local g = ImGui.GImGui
	local windows = g.Windows
	local current_front_window = windows:back()
	if current_front_window == window or current_front_window.RootWindow == window then
		return
	end
	for i = windows.Size - 2, 0, -1 do
		if windows[i + 1] == window then
			table.move(windows, i + 2, windows.Size, i + 1)
			windows[windows.Size] = window
			break
		end
	end
end

function ImGui.BringWindowToDisplayBack(window)
	local g = ImGui.GImGui
	local windows = g.Windows
	if windows[1] == window then
		return
	end
	for i = 0, windows.Size - 1 do
		if windows[i + 1] == window then
			table.move(windows, 1, i, 2)
			windows[1] = window
			break
		end
	end
end

function ImGui.BringWindowToDisplayBehind(window, behind_window)
	assert(window ~= nil and behind_window ~= nil)
	local g = ImGui.GImGui
	local windows = g.Windows
	window = window.RootWindow
	behind_window = behind_window.RootWindow
	local pos_wnd = ImGui.FindWindowDisplayIndex(window)
	local pos_beh = ImGui.FindWindowDisplayIndex(behind_window)
	if pos_wnd < pos_beh then
		table.move(windows, pos_wnd + 2, pos_beh, pos_wnd + 1)
		windows[pos_beh] = window
	else
		table.move(windows, pos_beh + 1, pos_wnd, pos_beh + 2)
		windows[pos_beh + 1] = window
	end
end

function ImGui.FindWindowDisplayIndex(window)
	local g = ImGui.GImGui
	return g.Windows:find_index(window)
end

function ImGui.FocusWindow(window, flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui

	if btest(flags, ImGuiFocusRequestFlags.UnlessBelowModal) and (g.NavWindow ~= window) then
		local blocking_modal = ImGui.FindBlockingModal(window)
		if blocking_modal then
			if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
				ImGui.DebugLog("[focus] FocusWindow(\"%s\", UnlessBelowModal): prevented by \"%s\".\n", if window then window.Name else "<NULL>", blocking_modal.Name)
			end
			if window and window == window.RootWindow and not btest(window.Flags, ImGuiWindowFlags.NoBringToFrontOnFocus) then
				ImGui.BringWindowToDisplayBehind(window, blocking_modal)
			end
			ImGui.ClosePopupsOverWindow(ImGui.GetTopMostPopupModal(), false)
			return
		end
	end

	if btest(flags, ImGuiFocusRequestFlags.RestoreFocusedChild) and window ~= nil then
		window = ImGui.NavRestoreLastChildNavWindow(window)
	end

	if g.NavWindow ~= window then
		ImGui.SetNavWindow(window)
		if window and g.NavHighlightItemUnderNav then
			g.NavMousePosDirty = true
		end
		g.NavId = if window then window.NavLastIds[1] else 0
		g.NavLayer = ImGuiNavLayer.Main
		ImGui.SetNavFocusScope(if window then window.NavRootFocusScopeId else 0)
		g.NavIdIsAlive = false
		g.NavLastValidSelectionUserData = ImGuiSelectionUserData.Invalid

		ImGui.ClosePopupsOverWindow(window, false)
	end

	assert(window == nil or window.RootWindow ~= nil)
	local focus_front_window = if window then window.RootWindow else nil
	local display_front_window = if window then window.RootWindow else nil

	if g.ActiveId ~= 0 and g.ActiveIdWindow and g.ActiveIdWindow.RootWindow ~= focus_front_window then
		if not g.ActiveIdNoClearOnFocusLoss then
			ImGui.ClearActiveID()
		end
	end

	if not window then
		return
	end

	ImGui.BringWindowToFocusFront(focus_front_window)
	if not btest(bor(window.Flags, display_front_window.Flags), ImGuiWindowFlags.NoBringToFrontOnFocus) then
		ImGui.BringWindowToDisplayFront(display_front_window)
	end
end

function ImGui.FocusTopMostWindowUnderOne(under_this_window, ignore_window, filter_viewport, flags)
	local g = ImGui.GImGui
	local start_idx = g.WindowsFocusOrder.Size - 1
	if under_this_window ~= nil then
		local offset = -1
		while btest(under_this_window.Flags, ImGuiWindowFlags.ChildWindow) do
			under_this_window = under_this_window.ParentWindow
			offset = 0
		end
		start_idx = ImGui.FindWindowFocusIndex(under_this_window) + offset
	end
	for i = start_idx, 0, -1 do
		local window = g.WindowsFocusOrder[i + 1]
		if window == ignore_window or not window.WasActive then
			continue
		end
		local mask = bor(ImGuiWindowFlags.NoMouseInputs, ImGuiWindowFlags.NoNavInputs)
		if band(window.Flags, mask) ~= mask then
			ImGui.FocusWindow(window, flags)
			return
		end
	end
	ImGui.FocusWindow(nil, flags)
end

return true
