--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImClamp, ImLerp = Base.ImMin, Base.ImMax, Base.ImClamp, Base.ImLerp
local ImTrunc, ImFloor = Base.ImTrunc, Base.ImFloor
local IM_TRUNC, IM_ROUND = Base.IM_TRUNC, Base.IM_ROUND
local FLT_MAX, IM_PI = Base.FLT_MAX, Base.IM_PI

local band, bor, bnot, btest, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.btest, bit32.lshift

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiNextWindowDataFlags = Enums.ImGuiNextWindowDataFlags
local ImGuiCond = Enums.ImGuiCond
local ImGuiCol = Enums.ImGuiCol
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiDir = Enums.ImGuiDir
local ImGuiAxis = Enums.ImGuiAxis
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiNavRenderCursorFlags = Enums.ImGuiNavRenderCursorFlags
local ImGuiWindowBgClickFlags = Enums.ImGuiWindowBgClickFlags
local ImGuiWindowRefreshFlags = Enums.ImGuiWindowRefreshFlags
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiLayoutType = Enums.ImGuiLayoutType
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiScrollFlags = Enums.ImGuiScrollFlags
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImDrawFlags = Enums.ImDrawFlags

local IMGUI_WINDOW_HARD_MIN_SIZE = Enums.Defines.IMGUI_WINDOW_HARD_MIN_SIZE
local WINDOWS_RESIZE_FROM_EDGES_FEEDBACK_TIMER = 0.04

local function IM_ASSERT_USER_ERROR(cond, msg)
	if not cond then
		if ImGui.ErrorLog(msg) then
			assert(cond, msg)
		end
	end
end

local function GetCurrentWindow()
	local g = ImGui.GImGui
	g.CurrentWindow.WriteAccessed = true
	return g.CurrentWindow
end

local function AxisGet(v, axis)
	if axis == 0 then
		return v.x
	end
	return v.y
end

local function AxisSet(v, axis, value)
	if axis == 0 then
		return ImVec2(value, v.y)
	end
	return ImVec2(v.x, value)
end

local function NewFocusScopeData(id, window_id)
	local data = Structs.ImGuiFocusScopeData.new()
	data.ID = id
	data.WindowID = window_id
	return data
end

function ImGui.BeginChildEx(name, id, size_arg, child_flags, window_flags)
	local g = ImGui.GImGui
	local parent_window = g.CurrentWindow
	assert(id ~= 0)

	if btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasChildFlags) then
		child_flags = band(bor(child_flags, g.NextWindowData.ChildFlagsSet), bnot(g.NextWindowData.ChildFlagsClear))
	end

	local ImGuiChildFlags_SupportedMask_ = bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AlwaysUseWindowPadding, ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY, ImGuiChildFlags.AutoResizeX, ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize, ImGuiChildFlags.FrameStyle, ImGuiChildFlags.NavFlattened)
	assert(band(child_flags, bnot(ImGuiChildFlags_SupportedMask_)) == 0, "Illegal ImGuiChildFlags value. Did you pass ImGuiWindowFlags values instead of ImGuiChildFlags?")
	assert(band(window_flags, ImGuiWindowFlags.AlwaysAutoResize) == 0, "Cannot specify ImGuiWindowFlags_AlwaysAutoResize for BeginChild(). Use ImGuiChildFlags_AlwaysAutoResize!")
	if btest(child_flags, ImGuiChildFlags.AlwaysAutoResize) then
		assert(band(child_flags, bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY)) == 0, "Cannot use ImGuiChildFlags_ResizeX or ImGuiChildFlags_ResizeY with ImGuiChildFlags_AlwaysAutoResize!")
		assert(band(child_flags, bor(ImGuiChildFlags.AutoResizeX, ImGuiChildFlags.AutoResizeY)) ~= 0, "Must use ImGuiChildFlags_AutoResizeX or ImGuiChildFlags_AutoResizeY with ImGuiChildFlags_AlwaysAutoResize!")
	end
	if btest(child_flags, ImGuiChildFlags.AutoResizeX) then
		child_flags = band(child_flags, bnot(ImGuiChildFlags.ResizeX))
	end
	if btest(child_flags, ImGuiChildFlags.AutoResizeY) then
		child_flags = band(child_flags, bnot(ImGuiChildFlags.ResizeY))
	end

	window_flags = bor(window_flags, ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.NoTitleBar)
	window_flags = bor(window_flags, band(parent_window.Flags, ImGuiWindowFlags.NoMove))
	if btest(child_flags, bor(ImGuiChildFlags.AutoResizeX, ImGuiChildFlags.AutoResizeY, ImGuiChildFlags.AlwaysAutoResize)) then
		window_flags = bor(window_flags, ImGuiWindowFlags.AlwaysAutoResize)
	end
	if band(child_flags, bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY)) == 0 then
		window_flags = bor(window_flags, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoSavedSettings)
	end

	if btest(child_flags, ImGuiChildFlags.FrameStyle) then
		ImGui.PushStyleColor(ImGuiCol.ChildBg, g.Style.Colors[ImGuiCol.FrameBg + 1])
		ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, g.Style.FrameRounding)
		ImGui.PushStyleVar(ImGuiStyleVar.ChildBorderSize, g.Style.FrameBorderSize)
		ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, g.Style.FramePadding)
		child_flags = bor(child_flags, ImGuiChildFlags.Borders, ImGuiChildFlags.AlwaysUseWindowPadding)
		window_flags = bor(window_flags, ImGuiWindowFlags.NoMove)
	end

	local size_avail = ImGui.GetContentRegionAvail()
	local size_default = ImVec2(btest(child_flags, ImGuiChildFlags.AutoResizeX) and 0 or size_avail.x, btest(child_flags, ImGuiChildFlags.AutoResizeY) and 0 or size_avail.y)
	local size = ImGui.CalcItemSize(size_arg, size_default.x, size_default.y)

	if band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) ~= 0 and band(g.NextWindowData.SizeCond, ImGuiCond.Always) ~= 0 then
		if g.NextWindowData.SizeVal.x > 0 then
			size = ImVec2(g.NextWindowData.SizeVal.x, size.y)
			child_flags = band(child_flags, bnot(ImGuiChildFlags.ResizeX))
		end
		if g.NextWindowData.SizeVal.y > 0 then
			size = ImVec2(size.x, g.NextWindowData.SizeVal.y)
			child_flags = band(child_flags, bnot(ImGuiChildFlags.ResizeY))
		end
	end
	ImGui.SetNextWindowSize(size)
	ImGui.SetNextWindowChildFlags(child_flags, true)

	local temp_window_name
	if name then
		temp_window_name = Base.ImFormatString("%s/%s_%08X", parent_window.Name, name, id)
	else
		temp_window_name = Base.ImFormatString("%s/%08X", parent_window.Name, id)
	end

	local backup_border_size = g.Style.ChildBorderSize
	if band(child_flags, ImGuiChildFlags.Borders) == 0 then
		g.Style.ChildBorderSize = 0
	end

	local ret = ImGui.Begin(temp_window_name, nil, window_flags)

	g.Style.ChildBorderSize = backup_border_size
	if btest(child_flags, ImGuiChildFlags.FrameStyle) then
		ImGui.PopStyleVar(3)
		ImGui.PopStyleColor()
	end

	local child_window = g.CurrentWindow
	child_window.ChildId = id

	if child_window.BeginCount == 1 then
		parent_window.DC.CursorPos = child_window.Pos
	end

	local temp_id_for_activation = Base.ImHashStr("##Child", 0, id)
	if g.ActiveId == temp_id_for_activation then
		ImGui.ClearActiveID()
	end
	if g.NavActivateId == id and not btest(child_flags, ImGuiChildFlags.NavFlattened) and (child_window.DC.NavLayersActiveMask ~= 0 or child_window.DC.NavWindowHasScrollY) then
		ImGui.FocusWindow(child_window)
		ImGui.NavInitWindow(child_window, false)
		ImGui.SetActiveID(temp_id_for_activation, child_window)
		g.ActiveIdSource = g.NavInputSource
	end
	return ret
end

function ImGui.EndChild()
	local g = ImGui.GImGui
	local child_window = g.CurrentWindow

	local backup_within_end_child_id = g.WithinEndChildID
	assert(btest(child_window.Flags, ImGuiWindowFlags.ChildWindow))

	g.WithinEndChildID = child_window.ID
	local child_size = child_window.Size
	ImGui.End()
	if child_window.BeginCount == 1 then
		local parent_window = g.CurrentWindow
		local bb = ImRect.new(parent_window.DC.CursorPos, parent_window.DC.CursorPos + child_size)
		ImGui.ItemSize(child_size)
		local nav_flattened = band(child_window.ChildFlags, ImGuiChildFlags.NavFlattened) ~= 0
		if (child_window.DC.NavLayersActiveMask ~= 0 or child_window.DC.NavWindowHasScrollY) and not nav_flattened then
			ImGui.ItemAdd(bb, child_window.ChildId)
			ImGui.RenderNavCursor(bb, child_window.ChildId)

			if child_window.DC.NavLayersActiveMask == 0 and child_window == g.NavWindow then
				ImGui.RenderNavCursor(ImRect.new(bb.Min - ImVec2(2, 2), bb.Max + ImVec2(2, 2)), g.NavId, ImGuiNavRenderCursorFlags.Compact)
			end
		else
			ImGui.ItemAdd(bb, child_window.ChildId, nil, ImGuiItemFlags.NoNav)

			if nav_flattened then
				parent_window.DC.NavLayersActiveMaskNext = bor(parent_window.DC.NavLayersActiveMaskNext, child_window.DC.NavLayersActiveMaskNext)
			end
		end
		if g.HoveredWindow == child_window then
			g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
		end
		child_window.DC.ChildItemStatusFlags = g.LastItemData.StatusFlags
	else
		ImGui.SetLastItemDataForChildWindowItem(child_window, child_window:Rect())
	end

	g.WithinEndChildID = backup_within_end_child_id
	g.LogLinePosY = -FLT_MAX
end

function ImGui.FindFrontMostVisibleChildWindow(window)
	for n = window.DC.ChildWindows.Size - 1, 0, -1 do
		if ImGui.IsWindowActiveAndVisible(window.DC.ChildWindows[n + 1]) then
			return ImGui.FindFrontMostVisibleChildWindow(window.DC.ChildWindows[n + 1])
		end
	end
	return window
end

function ImGui.SetWindowConditionAllowFlags(window, flags, enabled)
	if enabled then
		window.SetWindowPosAllowFlags = bor(window.SetWindowPosAllowFlags, flags)
		window.SetWindowSizeAllowFlags = bor(window.SetWindowSizeAllowFlags, flags)
		window.SetWindowCollapsedAllowFlags = bor(window.SetWindowCollapsedAllowFlags, flags)
	else
		window.SetWindowPosAllowFlags = band(window.SetWindowPosAllowFlags, bnot(flags))
		window.SetWindowSizeAllowFlags = band(window.SetWindowSizeAllowFlags, bnot(flags))
		window.SetWindowCollapsedAllowFlags = band(window.SetWindowCollapsedAllowFlags, bnot(flags))
	end
end

function ImGui.FindWindowByID(id)
	local g = ImGui.GImGui
	return g.WindowsById:GetVoidPtr(id)
end

function ImGui.FindWindowByName(name)
	local id = Base.ImHashStr(name)
	return ImGui.FindWindowByID(id)
end

function ImGui.ApplyWindowSettings(window, settings)
	if settings ~= nil then
		window.Pos = ImTrunc(ImVec2(settings.Pos.x, settings.Pos.y))
		if settings.Size.x > 0 and settings.Size.y > 0 then
			window.Size = ImTrunc(ImVec2(settings.Size.x, settings.Size.y))
			window.SizeFull = window.Size
			window.AutoFitFramesX = 0
			window.AutoFitFramesY = 0
		end
		window.Collapsed = settings.Collapsed
		ImGui.SetWindowConditionAllowFlags(window, ImGuiCond.FirstUseEver, false)
	end

	window.DC.CursorStartPos = window.Pos
	window.DC.CursorMaxPos = window.Pos
	window.DC.IdealMaxPos = window.Pos
	if band(window.Flags, ImGuiWindowFlags.AlwaysAutoResize) ~= 0 then
		window.AutoFitFramesX = 2
		window.AutoFitFramesY = 2
		window.AutoFitOnlyGrows = false
	else
		window.AutoFitFramesX = (window.Size.x <= 0) and 2 or 0
		window.AutoFitFramesY = (window.Size.y <= 0) and 2 or 0
		window.AutoFitOnlyGrows = (window.AutoFitFramesX > 0) or (window.AutoFitFramesY > 0)
	end
end

function ImGui.InitOrLoadWindowSettings(window, settings)
	local g = ImGui.GImGui
	local main_viewport = ImGui.GetMainViewport()
	window.Pos = main_viewport.Pos + ImVec2(60, 60)
	window.Size = ImVec2(0, 0)
	window.SizeFull = ImVec2(0, 0)
	local allow = bor(ImGuiCond.Always, ImGuiCond.Once, ImGuiCond.FirstUseEver, ImGuiCond.Appearing)
	window.SetWindowPosAllowFlags = allow
	window.SetWindowSizeAllowFlags = allow
	window.SetWindowCollapsedAllowFlags = allow
	ImGui.ApplyWindowSettings(window, settings)
	if settings ~= nil then
		settings.LastUsedDate = g.SessionDate
	end
end

function ImGui.CreateNewWindow(name, flags)
	local g = ImGui.GImGui
	local window = Structs.ImGuiWindow.new(g, name)
	window.Flags = flags
	g.WindowsById:SetVoidPtr(window.ID, window)

	local settings = nil
	if not btest(flags, ImGuiWindowFlags.NoSavedSettings) then
		settings = ImGui.FindWindowSettingsByWindow(window)
		if settings ~= nil then
			window.SettingsOffset = g.SettingsWindows:offset_from_ptr(settings)
		end
	end

	ImGui.InitOrLoadWindowSettings(window, settings)

	if btest(flags, ImGuiWindowFlags.NoBringToFrontOnFocus) then
		g.Windows:push_front(window)
	else
		g.Windows:push_back(window)
	end

	return window
end

function ImGui.CalcWindowMinSize(window)
	local g = ImGui.GImGui
	local size_min_x, size_min_y
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) and not btest(window.Flags, ImGuiWindowFlags.Popup) then
		size_min_x = btest(window.ChildFlags, ImGuiChildFlags.ResizeX) and g.Style.WindowMinSize.x or IMGUI_WINDOW_HARD_MIN_SIZE
		size_min_y = btest(window.ChildFlags, ImGuiChildFlags.ResizeY) and g.Style.WindowMinSize.y or IMGUI_WINDOW_HARD_MIN_SIZE
	else
		size_min_x = (band(window.Flags, ImGuiWindowFlags.AlwaysAutoResize) == 0) and g.Style.WindowMinSize.x or IMGUI_WINDOW_HARD_MIN_SIZE
		size_min_y = (band(window.Flags, ImGuiWindowFlags.AlwaysAutoResize) == 0) and g.Style.WindowMinSize.y or IMGUI_WINDOW_HARD_MIN_SIZE
	end

	local window_for_height = window
	size_min_y = ImMax(size_min_y, window_for_height.TitleBarHeight + window_for_height.MenuBarHeight + ImMax(0, g.Style.WindowRounding - 1))
	return ImVec2(size_min_x, size_min_y)
end

function ImGui.CalcWindowSizeAfterConstraint(window, size_desired)
	local g = ImGui.GImGui
	local new_size = size_desired
	if btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSizeConstraint) then
		local cr = g.NextWindowData.SizeConstraintRect
		local new_x = (cr.Min.x >= 0 and cr.Max.x >= 0) and ImClamp(new_size.x, cr.Min.x, cr.Max.x) or window.SizeFull.x
		local new_y = (cr.Min.y >= 0 and cr.Max.y >= 0) and ImClamp(new_size.y, cr.Min.y, cr.Max.y) or window.SizeFull.y
		new_size = ImVec2(new_x, new_y)
		if g.NextWindowData.SizeCallback then
			local data = Structs.ImGuiSizeCallbackData.new()
			data.UserData = g.NextWindowData.SizeCallbackUserData
			data.Pos = window.Pos
			data.CurrentSize = window.SizeFull
			data.DesiredSize = new_size
			g.NextWindowData.SizeCallback(data)
			new_size = data.DesiredSize
		end
		new_size = ImVec2(IM_TRUNC(new_size.x), IM_TRUNC(new_size.y))
	end

	local size_min = ImGui.CalcWindowMinSize(window)
	return ImMax(new_size, size_min)
end

function ImGui.CalcWindowContentSizes(window, content_size_current, content_size_ideal)
	local preserve_old_content_sizes = false
	if window.Collapsed and window.AutoFitFramesX <= 0 and window.AutoFitFramesY <= 0 then
		preserve_old_content_sizes = true
	elseif window.Hidden and window.HiddenFramesCannotSkipItems == 0 and window.HiddenFramesCanSkipItems > 0 then
		preserve_old_content_sizes = true
	end
	if preserve_old_content_sizes then
		return window.ContentSize, window.ContentSizeIdeal
	end

	local dc = window.DC
	local explicit = window.ContentSizeExplicit
	content_size_current = ImVec2(
		(explicit.x ~= 0) and explicit.x or Base.ImTrunc64(dc.CursorMaxPos.x - dc.CursorStartPos.x),
		(explicit.y ~= 0) and explicit.y or Base.ImTrunc64(dc.CursorMaxPos.y - dc.CursorStartPos.y)
	)
	content_size_ideal = ImVec2(
		(explicit.x ~= 0) and explicit.x or Base.ImTrunc64(ImMax(dc.CursorMaxPos.x, dc.IdealMaxPos.x) - dc.CursorStartPos.x),
		(explicit.y ~= 0) and explicit.y or Base.ImTrunc64(ImMax(dc.CursorMaxPos.y, dc.IdealMaxPos.y) - dc.CursorStartPos.y)
	)
	return content_size_current, content_size_ideal
end

function ImGui.CalcWindowAutoFitSize(window, size_contents, axis_mask)
	local g = ImGui.GImGui
	local style = g.Style
	local decoration_w_without_scrollbars = window.DecoOuterSizeX1 + window.DecoOuterSizeX2 - window.ScrollbarSizes.x
	local decoration_h_without_scrollbars = window.DecoOuterSizeY1 + window.DecoOuterSizeY2 - window.ScrollbarSizes.y
	local size_pad = window.WindowPadding * 2
	local size_desired = ImVec2(
		btest(axis_mask, 1) and (size_contents.x + size_pad.x + decoration_w_without_scrollbars) or window.Size.x,
		btest(axis_mask, 2) and (size_contents.y + size_pad.y + decoration_h_without_scrollbars) or window.Size.y
	)

	local size_max
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) and not btest(window.Flags, ImGuiWindowFlags.Popup) then
		size_max = ImVec2(FLT_MAX, FLT_MAX)
	else
		size_max = ImGui.GetMainViewport().WorkSize - style.DisplaySafeAreaPadding * 2
	end

	if btest(window.Flags, ImGuiWindowFlags.Tooltip) then
		return ImMin(size_desired, size_max)
	else
		local size_min = ImGui.CalcWindowMinSize(window)
		local size_auto_fit = ImClamp(size_desired, ImMin(size_min, size_max), size_max)

		local size_auto_fit_after_constraint = ImGui.CalcWindowSizeAfterConstraint(window, size_auto_fit)
		local size_contents_for_scrollbar_x = btest(axis_mask, 1) and size_contents.x or window.ContentSize.x
		local size_contents_for_scrollbar_y = btest(axis_mask, 2) and size_contents.y or window.ContentSize.y
		local will_have_scrollbar_x = (size_auto_fit_after_constraint.x < size_contents_for_scrollbar_x + size_pad.x + decoration_w_without_scrollbars and not btest(window.Flags, ImGuiWindowFlags.NoScrollbar) and btest(window.Flags, ImGuiWindowFlags.HorizontalScrollbar)) or btest(window.Flags, ImGuiWindowFlags.AlwaysHorizontalScrollbar)
		local will_have_scrollbar_y = (size_auto_fit_after_constraint.y < size_contents_for_scrollbar_y + size_pad.y + decoration_h_without_scrollbars and not btest(window.Flags, ImGuiWindowFlags.NoScrollbar)) or btest(window.Flags, ImGuiWindowFlags.AlwaysVerticalScrollbar)
		if will_have_scrollbar_x then
			size_auto_fit = ImVec2(size_auto_fit.x, size_auto_fit.y + style.ScrollbarSize)
		end
		if will_have_scrollbar_y then
			size_auto_fit = ImVec2(size_auto_fit.x + style.ScrollbarSize, size_auto_fit.y)
		end
		return size_auto_fit
	end
end

function ImGui.CalcWindowNextAutoFitSize(window)
	local _, size_contents_ideal = ImGui.CalcWindowContentSizes(window, nil, nil)
	local size_auto_fit = ImGui.CalcWindowAutoFitSize(window, size_contents_ideal, 0xFFFFFFFF)
	local size_final = ImGui.CalcWindowSizeAfterConstraint(window, size_auto_fit)
	return size_final
end

function ImGui.GetWindowBgColorIdx(window)
	if btest(window.Flags, bor(ImGuiWindowFlags.Tooltip, ImGuiWindowFlags.Popup)) then
		return ImGuiCol.PopupBg
	end
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
		return ImGuiCol.ChildBg
	end
	return ImGuiCol.WindowBg
end

function ImGui.CalcResizePosSizeFromAnyCorner(window, corner_target_arg, corner_norm, out_pos, out_size)
	local corner_target = corner_target_arg
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
		local parent_window = window.ParentWindow
		local parent_flags = parent_window.Flags
		local limit_rect = parent_window.InnerRect
		limit_rect = limit_rect:Expanded(ImVec2(-ImMax(parent_window.WindowPadding.x, parent_window.WindowBorderSize), -ImMax(parent_window.WindowPadding.y, parent_window.WindowBorderSize)))
		if band(parent_flags, bor(ImGuiWindowFlags.HorizontalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar)) == 0 or btest(parent_flags, ImGuiWindowFlags.NoScrollbar) then
			corner_target = ImVec2(ImClamp(corner_target.x, limit_rect.Min.x, limit_rect.Max.x), corner_target.y)
		end
		if btest(parent_flags, ImGuiWindowFlags.NoScrollbar) then
			corner_target = ImVec2(corner_target.x, ImClamp(corner_target.y, limit_rect.Min.y, limit_rect.Max.y))
		end
	end
	local pos_min = ImLerp(corner_target, window.Pos, corner_norm)
	local pos_max = ImLerp(window.Pos + window.Size, corner_target, corner_norm)
	local size_expected = pos_max - pos_min
	local size_constrained = ImGui.CalcWindowSizeAfterConstraint(window, size_expected)
	out_pos = pos_min
	if corner_norm.x == 0 then
		out_pos = ImVec2(out_pos.x - (size_constrained.x - size_expected.x), out_pos.y)
	end
	if corner_norm.y == 0 then
		out_pos = ImVec2(out_pos.x, out_pos.y - (size_constrained.y - size_expected.y))
	end
	out_size = size_constrained
	return out_pos, out_size
end

local resize_grip_def = {
	{ CornerPosN = ImVec2(1, 1), InnerDir = ImVec2(-1, -1), AngleMin12 = 0, AngleMax12 = 3 },
	{ CornerPosN = ImVec2(0, 1), InnerDir = ImVec2(1, -1), AngleMin12 = 3, AngleMax12 = 6 },
	{ CornerPosN = ImVec2(0, 0), InnerDir = ImVec2(1, 1), AngleMin12 = 6, AngleMax12 = 9 },
	{ CornerPosN = ImVec2(1, 0), InnerDir = ImVec2(-1, 1), AngleMin12 = 9, AngleMax12 = 12 },
}

local resize_border_def = {
	{ InnerDir = ImVec2(1, 0), SegmentN1 = ImVec2(0, 1), SegmentN2 = ImVec2(0, 0), OuterAngle = IM_PI * 1.00 },
	{ InnerDir = ImVec2(-1, 0), SegmentN1 = ImVec2(1, 0), SegmentN2 = ImVec2(1, 1), OuterAngle = IM_PI * 0.00 },
	{ InnerDir = ImVec2(0, 1), SegmentN1 = ImVec2(0, 0), SegmentN2 = ImVec2(1, 0), OuterAngle = IM_PI * 1.50 },
	{ InnerDir = ImVec2(0, -1), SegmentN1 = ImVec2(1, 1), SegmentN2 = ImVec2(0, 1), OuterAngle = IM_PI * 0.50 },
}

function ImGui.GetResizeBorderRect(window, border_n, perp_padding, thickness)
	local rect = window:Rect()
	if thickness == 0 then
		rect = rect:WithMax(rect.Max - ImVec2(1, 1))
	end
	if border_n == ImGuiDir.Left then return ImRect.fromXY(rect.Min.x - thickness, rect.Min.y + perp_padding, rect.Min.x + thickness, rect.Max.y - perp_padding) end
	if border_n == ImGuiDir.Right then return ImRect.fromXY(rect.Max.x - thickness, rect.Min.y + perp_padding, rect.Max.x + thickness, rect.Max.y - perp_padding) end
	if border_n == ImGuiDir.Up then return ImRect.fromXY(rect.Min.x + perp_padding, rect.Min.y - thickness, rect.Max.x - perp_padding, rect.Min.y + thickness) end
	if border_n == ImGuiDir.Down then return ImRect.fromXY(rect.Min.x + perp_padding, rect.Max.y - thickness, rect.Max.x - perp_padding, rect.Max.y + thickness) end
	assert(false)
	return ImRect.new()
end

function ImGui.GetWindowResizeCornerID(window, n)
	assert(n >= 0 and n < 4)
	local id = window.ID
	id = Base.ImHashStr("#RESIZE", 0, id)
	id = Base.ImHashData(string.pack("<I4", n), 4, id)
	return id
end

function ImGui.GetWindowResizeBorderID(window, dir)
	assert(dir >= 0 and dir < 4)
	local n = dir + 4
	local id = window.ID
	id = Base.ImHashStr("#RESIZE", 0, id)
	id = Base.ImHashData(string.pack("<I4", n), 4, id)
	return id
end

function ImGui.UpdateWindowManualResize(window, border_hovered, border_held, resize_grip_count, resize_grip_col, visibility_rect)
	local g = ImGui.GImGui
	local flags = window.Flags

	if btest(flags, ImGuiWindowFlags.NoResize) or window.AutoFitFramesX > 0 or window.AutoFitFramesY > 0 then
		return 0, border_hovered, border_held
	end
	if btest(flags, ImGuiWindowFlags.AlwaysAutoResize) and band(window.ChildFlags, bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY)) == 0 then
		return 0, border_hovered, border_held
	end
	if window.WasActive == false then
		return 0, border_hovered, border_held
	end

	local ret_auto_fit_mask = 0x00
	local grip_draw_size = IM_TRUNC(ImMax(g.FontSize * 1.35, window.WindowRounding + 1 + g.FontSize * 0.2))
	local grip_hover_inner_size = (resize_grip_count > 0) and IM_TRUNC(grip_draw_size * 0.75) or 0
	local grip_hover_outer_size = g.WindowsBorderHoverPadding

	local clamp_rect = visibility_rect
	local window_move_from_title_bar = not btest(window.BgClickFlags, ImGuiWindowBgClickFlags.Move) and not btest(window.Flags, ImGuiWindowFlags.NoTitleBar)
	if window_move_from_title_bar then
		clamp_rect = clamp_rect:WithMinY(clamp_rect.Min.y - window.TitleBarHeight)
	end

	local pos_target = ImVec2(FLT_MAX, FLT_MAX)
	local size_target = ImVec2(FLT_MAX, FLT_MAX)

	window.DC.NavLayerCurrent = ImGuiNavLayer.Menu

	ImGui.PushID("#RESIZE")
	for resize_grip_n = 0, resize_grip_count - 1 do
		local def = resize_grip_def[resize_grip_n + 1]
		local corner = ImLerp(window.Pos, window.Pos + window.Size, def.CornerPosN)

		local p1 = corner - def.InnerDir * grip_hover_outer_size
		local p2 = corner + def.InnerDir * grip_hover_inner_size
		local resize_rect = ImRect.fromXY(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.max(p1.x, p2.x), math.max(p1.y, p2.y))
		local resize_grip_id = window:GetID(resize_grip_n)
		ImGui.ItemAdd(resize_rect, resize_grip_id, nil, ImGuiItemFlags.NoNav)
		local _, hovered, held = ImGui.ButtonBehavior(resize_rect, resize_grip_id, nil, nil, bor(ImGuiButtonFlags.FlattenChildren, ImGuiButtonFlags.NoNavFocus))
		if hovered or held then
			ImGui.SetMouseCursor(btest(resize_grip_n, 1) and ImGuiMouseCursor.ResizeNESW or ImGuiMouseCursor.ResizeNWSE)
		end

		if held and g.IO.MouseDoubleClicked[1] then
			local size_auto_fit = ImGui.CalcWindowAutoFitSize(window, window.ContentSizeIdeal, 0xFFFFFFFF)
			size_target = ImGui.CalcWindowSizeAfterConstraint(window, size_auto_fit)
			ret_auto_fit_mask = 0x03
			ImGui.ClearActiveID()
		elseif held then
			local clamp_min = ImVec2((def.CornerPosN.x == 1) and clamp_rect.Min.x or -FLT_MAX, (def.CornerPosN.y == 1 or (def.CornerPosN.y == 0 and window_move_from_title_bar)) and clamp_rect.Min.y or -FLT_MAX)
			local clamp_max = ImVec2((def.CornerPosN.x == 0) and clamp_rect.Max.x or FLT_MAX, (def.CornerPosN.y == 0) and clamp_rect.Max.y or FLT_MAX)
			local corner_target = g.IO.MousePos - g.ActiveIdClickOffset + ImLerp(def.InnerDir * grip_hover_outer_size, def.InnerDir * -grip_hover_inner_size, def.CornerPosN)
			corner_target = ImClamp(corner_target, clamp_min, clamp_max)
			pos_target, size_target = ImGui.CalcResizePosSizeFromAnyCorner(window, corner_target, def.CornerPosN, pos_target, size_target)
		end

		local resize_grip_visible = held or hovered or (resize_grip_n == 0 and band(window.Flags, ImGuiWindowFlags.ChildWindow) == 0)
		if resize_grip_visible then
			local col_idx
			if held then
				col_idx = ImGuiCol.ResizeGripActive
			elseif hovered then
				col_idx = ImGuiCol.ResizeGripHovered
			else
				col_idx = ImGuiCol.ResizeGrip
			end
			resize_grip_col[resize_grip_n + 1] = ImGui.GetColorU32(col_idx)
		end
	end

	local resize_border_mask = 0x00
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
		resize_border_mask = bor(resize_border_mask, btest(window.ChildFlags, ImGuiChildFlags.ResizeX) and 0x02 or 0, btest(window.ChildFlags, ImGuiChildFlags.ResizeY) and 0x08 or 0)
	else
		resize_border_mask = g.IO.ConfigWindowsResizeFromEdges and 0x0F or 0x00
	end
	for border_n = 0, 3 do
		if band(resize_border_mask, lshift(1, border_n)) == 0 then
			continue
		end
		local def = resize_border_def[border_n + 1]
		local axis = (border_n == ImGuiDir.Left or border_n == ImGuiDir.Right) and ImGuiAxis.X or ImGuiAxis.Y

		local border_rect = ImGui.GetResizeBorderRect(window, border_n, grip_hover_inner_size, g.WindowsBorderHoverPadding)
		local border_id = window:GetID(border_n + 4)
		ImGui.ItemAdd(border_rect, border_id, nil, ImGuiItemFlags.NoNav)
		local _, hovered, held = ImGui.ButtonBehavior(border_rect, border_id, nil, nil, bor(ImGuiButtonFlags.FlattenChildren, ImGuiButtonFlags.NoNavFocus))
		if hovered and g.HoveredIdTimer <= WINDOWS_RESIZE_FROM_EDGES_FEEDBACK_TIMER then
			hovered = false
		end
		if hovered or held then
			ImGui.SetMouseCursor((axis == ImGuiAxis.X) and ImGuiMouseCursor.ResizeEW or ImGuiMouseCursor.ResizeNS)
		end
		if held and g.IO.MouseDoubleClicked[1] then
			if border_n == 1 or border_n == 3 then
				local size_auto_fit = ImGui.CalcWindowAutoFitSize(window, window.ContentSizeIdeal, lshift(1, axis))
				size_target = AxisSet(size_target, axis, AxisGet(ImGui.CalcWindowSizeAfterConstraint(window, size_auto_fit), axis))
				ret_auto_fit_mask = bor(ret_auto_fit_mask, lshift(1, axis))
				hovered = false
				held = false
			end
			ImGui.ClearActiveID()
		elseif held then
			local just_scrolled_manually_while_resizing = (g.WheelingWindow ~= nil and g.WheelingWindowScrolledFrame == g.FrameCount and ImGui.IsWindowChildOf(window, g.WheelingWindow, false))
			if g.ActiveIdIsJustActivated or just_scrolled_manually_while_resizing then
				g.WindowResizeBorderExpectedRect = border_rect
				g.WindowResizeRelativeMode = false
			end
			if btest(window.Flags, ImGuiWindowFlags.ChildWindow) and (g.WindowResizeBorderExpectedRect.Min ~= border_rect.Min or g.WindowResizeBorderExpectedRect.Max ~= border_rect.Max) then
				g.WindowResizeRelativeMode = true
			end

			local border_curr = window.Pos + ImMin(def.SegmentN1, def.SegmentN2) * window.Size
			local border_target_rel_mode_for_axis = AxisGet(border_curr, axis) + AxisGet(g.IO.MouseDelta, axis)
			local border_target_abs_mode_for_axis = AxisGet(g.IO.MousePos, axis) - AxisGet(g.ActiveIdClickOffset, axis) + g.WindowsBorderHoverPadding

			local border_target = window.Pos
			border_target = AxisSet(border_target, axis, border_target_abs_mode_for_axis)

			local ignore_resize = false
			if g.WindowResizeRelativeMode then
				border_target = AxisSet(border_target, axis, border_target_rel_mode_for_axis)
				local mouse_delta_axis = AxisGet(g.IO.MouseDelta, axis)
				if mouse_delta_axis == 0 or (mouse_delta_axis > 0) == (border_target_rel_mode_for_axis > border_target_abs_mode_for_axis) then
					ignore_resize = true
				end
			end

			local clamp_min = ImVec2((border_n == ImGuiDir.Right) and clamp_rect.Min.x or -FLT_MAX, (border_n == ImGuiDir.Down or (border_n == ImGuiDir.Up and window_move_from_title_bar)) and clamp_rect.Min.y or -FLT_MAX)
			local clamp_max = ImVec2((border_n == ImGuiDir.Left) and clamp_rect.Max.x or FLT_MAX, (border_n == ImGuiDir.Up) and clamp_rect.Max.y or FLT_MAX)
			border_target = ImClamp(border_target, clamp_min, clamp_max)
			if not ignore_resize then
				pos_target, size_target = ImGui.CalcResizePosSizeFromAnyCorner(window, border_target, ImMin(def.SegmentN1, def.SegmentN2), pos_target, size_target)
			end
		end
		if hovered then
			border_hovered = border_n
		end
		if held then
			border_held = border_n
		end
	end
	ImGui.PopID()

	window.DC.NavLayerCurrent = ImGuiNavLayer.Main

	if g.NavWindowingTarget and g.NavWindowingTarget.RootWindow == window then
		local nav_resize_dir = ImVec2(0, 0)
		if g.NavInputSource == ImGuiInputSource.Keyboard and g.IO.KeyShift then
			nav_resize_dir = ImGui.GetKeyMagnitude2d(ImGuiKey.LeftArrow, ImGuiKey.RightArrow, ImGuiKey.UpArrow, ImGuiKey.DownArrow)
		end
		if g.NavInputSource == ImGuiInputSource.Gamepad then
			nav_resize_dir = ImGui.GetKeyMagnitude2d(ImGuiKey.GamepadDpadLeft, ImGuiKey.GamepadDpadRight, ImGuiKey.GamepadDpadUp, ImGuiKey.GamepadDpadDown)
		end
		if nav_resize_dir.x ~= 0 or nav_resize_dir.y ~= 0 then
			local NAV_RESIZE_SPEED = 600
			local resize_step = NAV_RESIZE_SPEED * g.IO.DeltaTime * g.Style._MainScale
			g.NavWindowingAccumDeltaSize += nav_resize_dir * resize_step
			g.NavWindowingAccumDeltaSize = ImMax(g.NavWindowingAccumDeltaSize, clamp_rect.Min - window.Pos - window.Size)
			g.NavWindowingToggleLayer = false
			g.NavHighlightItemUnderNav = true
			resize_grip_col[1] = ImGui.GetColorU32(ImGuiCol.ResizeGripActive)
			local accum_floored = ImTrunc(g.NavWindowingAccumDeltaSize)
			if accum_floored.x ~= 0 or accum_floored.y ~= 0 then
				size_target = ImGui.CalcWindowSizeAfterConstraint(window, window.SizeFull + accum_floored)
				g.NavWindowingAccumDeltaSize -= accum_floored
			end
		end
	end

	local old_pos = window.Pos
	local old_size = window.SizeFull
	if size_target.x ~= FLT_MAX and (window.Size.x ~= size_target.x or window.SizeFull.x ~= size_target.x) then
		window.SizeFull = ImVec2(size_target.x, window.SizeFull.y)
		window.Size = ImVec2(size_target.x, window.Size.y)
	end
	if size_target.y ~= FLT_MAX and (window.Size.y ~= size_target.y or window.SizeFull.y ~= size_target.y) then
		window.SizeFull = ImVec2(window.SizeFull.x, size_target.y)
		window.Size = ImVec2(window.Size.x, size_target.y)
	end
	if pos_target.x ~= FLT_MAX and window.Pos.x ~= ImTrunc(pos_target.x) then
		window.Pos = ImVec2(ImTrunc(pos_target.x), window.Pos.y)
	end
	if pos_target.y ~= FLT_MAX and window.Pos.y ~= ImTrunc(pos_target.y) then
		window.Pos = ImVec2(window.Pos.x, ImTrunc(pos_target.y))
	end
	if old_pos.x ~= window.Pos.x or old_pos.y ~= window.Pos.y or old_size.x ~= window.SizeFull.x or old_size.y ~= window.SizeFull.y then
		ImGui.MarkIniSettingsDirty(window)
	end

	if border_held ~= -1 then
		g.WindowResizeBorderExpectedRect = ImGui.GetResizeBorderRect(window, border_held, grip_hover_inner_size, g.WindowsBorderHoverPadding)
	end

	return ret_auto_fit_mask, border_hovered, border_held
end

function ImGui.ClampWindowPos(window, visibility_rect)
	local size_for_clamping = window.Size
	if not btest(window.BgClickFlags, ImGuiWindowBgClickFlags.Move) and not btest(window.Flags, ImGuiWindowFlags.NoTitleBar) then
		size_for_clamping = ImVec2(size_for_clamping.x, window.TitleBarHeight)
	end
	window.Pos = ImClamp(window.Pos, visibility_rect.Min - size_for_clamping, visibility_rect.Max)
end

function ImGui.RenderWindowOuterSingleBorder(window, border_n, border_col, border_size)
	local def = resize_border_def[border_n + 1]
	local rounding = window.WindowRounding
	local border_r = ImGui.GetResizeBorderRect(window, border_n, rounding, 0)
	window.DrawList:PathArcTo(ImLerp(border_r.Min, border_r.Max, def.SegmentN1) + ImVec2(0.5, 0.5) + def.InnerDir * rounding, rounding, def.OuterAngle - IM_PI * 0.25, def.OuterAngle)
	window.DrawList:PathArcTo(ImLerp(border_r.Min, border_r.Max, def.SegmentN2) + ImVec2(0.5, 0.5) + def.InnerDir * rounding, rounding, def.OuterAngle, def.OuterAngle + IM_PI * 0.25)
	window.DrawList:PathStroke(border_col, border_size)
end

function ImGui.RenderWindowOuterBorders(window)
	local g = ImGui.GImGui
	local border_size = window.WindowBorderSize
	local border_col = ImGui.GetColorU32(ImGuiCol.Border)
	if border_size > 0 and band(window.Flags, ImGuiWindowFlags.NoBackground) == 0 then
		window.DrawList:AddRect(window.Pos, window.Pos + window.Size, border_col, window.WindowRounding, window.WindowBorderSize)
	elseif border_size > 0 then
		if btest(window.ChildFlags, ImGuiChildFlags.ResizeX) then
			ImGui.RenderWindowOuterSingleBorder(window, 1, border_col, border_size)
		end
		if btest(window.ChildFlags, ImGuiChildFlags.ResizeY) then
			ImGui.RenderWindowOuterSingleBorder(window, 3, border_col, border_size)
		end
	end
	if window.ResizeBorderHovered ~= -1 or window.ResizeBorderHeld ~= -1 then
		local border_n = (window.ResizeBorderHeld ~= -1) and window.ResizeBorderHeld or window.ResizeBorderHovered
		local border_col_resizing = ImGui.GetColorU32((window.ResizeBorderHeld ~= -1) and ImGuiCol.SeparatorActive or ImGuiCol.SeparatorHovered)
		ImGui.RenderWindowOuterSingleBorder(window, border_n, border_col_resizing, ImMax(2, window.WindowBorderSize))
	end
	if g.Style.FrameBorderSize > 0 and not btest(window.Flags, ImGuiWindowFlags.NoTitleBar) then
		local y = window.Pos.y + window.TitleBarHeight - 1
		window.DrawList:AddLineH(window.Pos.x + border_size, window.Pos.x + window.Size.x - border_size, y, border_col, g.Style.FrameBorderSize, ImDrawFlags.StrokeCenterBiased)
	end
end

function ImGui.RenderWindowDecorations(window, title_bar_rect, title_bar_is_highlight, handle_borders_and_resize_grips, resize_grip_count, resize_grip_col, resize_grip_draw_size)
	local g = ImGui.GImGui
	local style = g.Style
	local flags = window.Flags

	assert(window.BeginCount == 0)
	window.SkipItems = false
	window.DC.NavLayerCurrent = ImGuiNavLayer.Menu

	local window_rounding = window.WindowRounding
	local window_border_size = window.WindowBorderSize
	if window.Collapsed then
		local backup_border_size = style.FrameBorderSize
		g.Style.FrameBorderSize = window.WindowBorderSize
		local title_bar_col = ImGui.GetColorU32((title_bar_is_highlight and g.NavCursorVisible) and ImGuiCol.TitleBgActive or ImGuiCol.TitleBgCollapsed)
		ImGui.RenderFrame(title_bar_rect.Min, title_bar_rect.Max, title_bar_col, true, window_rounding)
		g.Style.FrameBorderSize = backup_border_size
	else
		if not btest(flags, ImGuiWindowFlags.NoBackground) then
			local bg_col = ImGui.GetColorU32(ImGui.GetWindowBgColorIdx(window))
			local override_alpha = false
			local alpha = 1
			if btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasBgAlpha) then
				alpha = g.NextWindowData.BgAlphaVal
				override_alpha = true
			end
			if override_alpha then
				bg_col = bor(band(bg_col, bnot(Base.IM_COL32_A_MASK)), lshift(Base.IM_F32_TO_INT8_SAT(alpha), Base.IM_COL32_A_SHIFT))
			end
			if band(bg_col, Base.IM_COL32_A_MASK) ~= 0 then
				local bg_rect = ImRect.new(window.Pos + ImVec2(0, window.TitleBarHeight), window.Pos + window.Size)
				local bg_rounding_flags = btest(flags, ImGuiWindowFlags.NoTitleBar) and ImDrawFlags.RoundAll or ImDrawFlags.RoundBottom
				local bg_draw_list = window.DrawList
				bg_draw_list:AddRectFilled(bg_rect.Min, bg_rect.Max, bg_col, window_rounding, bg_rounding_flags)
			end
		end

		if not btest(flags, ImGuiWindowFlags.NoTitleBar) then
			local title_bar_col = ImGui.GetColorU32(title_bar_is_highlight and ImGuiCol.TitleBgActive or ImGuiCol.TitleBg)
			window.DrawList:AddRectFilled(title_bar_rect.Min, title_bar_rect.Max, title_bar_col, window_rounding, ImDrawFlags.RoundTop)
		end

		if btest(flags, ImGuiWindowFlags.MenuBar) then
			local menu_bar_rect = window:MenuBarRect()
			menu_bar_rect = menu_bar_rect:ClippedWith(window:Rect())
			window.DrawList:AddRectFilled(menu_bar_rect.Min, menu_bar_rect.Max, ImGui.GetColorU32(ImGuiCol.MenuBarBg), btest(flags, ImGuiWindowFlags.NoTitleBar) and window_rounding or 0, ImDrawFlags.RoundTop)
			if style.FrameBorderSize > 0 and menu_bar_rect.Max.y < window.Pos.y + window.Size.y then
				window.DrawList:AddLineH(menu_bar_rect.Min.x + window_border_size, menu_bar_rect.Max.x - window_border_size, menu_bar_rect.Max.y, ImGui.GetColorU32(ImGuiCol.Border), style.FrameBorderSize, ImDrawFlags.StrokeCenterBiased)
			end
		end

		if window.ScrollbarX then
			ImGui.Scrollbar(ImGuiAxis.X)
		end
		if window.ScrollbarY then
			ImGui.Scrollbar(ImGuiAxis.Y)
		end

		if handle_borders_and_resize_grips and not btest(flags, ImGuiWindowFlags.NoResize) then
			for resize_grip_n = 0, resize_grip_count - 1 do
				local col = resize_grip_col[resize_grip_n + 1]
				if band(col, Base.IM_COL32_A_MASK) == 0 then
					continue
				end
				local grip = resize_grip_def[resize_grip_n + 1]
				local corner = ImLerp(window.Pos, window.Pos + window.Size, grip.CornerPosN)
				local border_inner = IM_ROUND(window_border_size * 0.5)
				local odd = btest(resize_grip_n, 1)
				window.DrawList:PathLineTo(corner + grip.InnerDir * (odd and ImVec2(border_inner, resize_grip_draw_size) or ImVec2(resize_grip_draw_size, border_inner)))
				window.DrawList:PathLineTo(corner + grip.InnerDir * (odd and ImVec2(resize_grip_draw_size, border_inner) or ImVec2(border_inner, resize_grip_draw_size)))
				window.DrawList:PathArcToFast(ImVec2(corner.x + grip.InnerDir.x * (window_rounding + border_inner), corner.y + grip.InnerDir.y * (window_rounding + border_inner)), window_rounding, grip.AngleMin12, grip.AngleMax12)
				window.DrawList:PathFillConvex(col)
			end
		end

		if handle_borders_and_resize_grips then
			ImGui.RenderWindowOuterBorders(window)
		end
	end
	window.DC.NavLayerCurrent = ImGuiNavLayer.Main
end

function ImGui.RenderWindowTitleBarContents(window, title_bar_rect, name, p_open)
	local g = ImGui.GImGui
	local style = g.Style
	local flags = window.Flags

	local has_close_button = (p_open ~= nil)
	local has_collapse_button = not btest(flags, ImGuiWindowFlags.NoCollapse) and (style.WindowMenuButtonPosition ~= ImGuiDir.None)

	local item_flags_backup = g.CurrentItemFlags
	g.CurrentItemFlags = bor(g.CurrentItemFlags, ImGuiItemFlags.NoNavDefaultFocus)
	window.DC.NavLayerCurrent = ImGuiNavLayer.Menu

	local pad_l = style.FramePadding.x
	local pad_r = style.FramePadding.x
	local button_sz = g.FontSize
	local close_button_pos = ImVec2(0, 0)
	local collapse_button_pos = ImVec2(0, 0)
	if has_close_button then
		close_button_pos = ImVec2(title_bar_rect.Max.x - pad_r - button_sz, title_bar_rect.Min.y + style.FramePadding.y)
		pad_r += button_sz + style.ItemInnerSpacing.x
	end
	if has_collapse_button and style.WindowMenuButtonPosition == ImGuiDir.Right then
		collapse_button_pos = ImVec2(title_bar_rect.Max.x - pad_r - button_sz, title_bar_rect.Min.y + style.FramePadding.y)
		pad_r += button_sz + style.ItemInnerSpacing.x
	end
	if has_collapse_button and style.WindowMenuButtonPosition == ImGuiDir.Left then
		collapse_button_pos = ImVec2(title_bar_rect.Min.x + pad_l, title_bar_rect.Min.y + style.FramePadding.y)
		pad_l += button_sz + style.ItemInnerSpacing.x
	end

	if has_collapse_button then
		if ImGui.CollapseButton(window:GetID("#COLLAPSE"), collapse_button_pos) then
			window.WantCollapseToggle = true
		end
	end

	if has_close_button then
		local backup_item_flags = g.CurrentItemFlags
		g.CurrentItemFlags = bor(g.CurrentItemFlags, ImGuiItemFlags.NoFocus)
		if ImGui.CloseButton(window:GetID("#CLOSE"), close_button_pos) then
			p_open = false
		end
		g.CurrentItemFlags = backup_item_flags
	end

	window.DC.NavLayerCurrent = ImGuiNavLayer.Main
	g.CurrentItemFlags = item_flags_backup

	local marker_size_x = btest(flags, ImGuiWindowFlags.UnsavedDocument) and button_sz * 0.80 or 0
	local text_size = ImGui.CalcTextSize(name, nil, true) + ImVec2(marker_size_x, 0)

	if pad_l > style.FramePadding.x then
		pad_l += g.Style.ItemInnerSpacing.x
	end
	if pad_r > style.FramePadding.x then
		pad_r += g.Style.ItemInnerSpacing.x
	end
	if style.WindowTitleAlign.x > 0 and style.WindowTitleAlign.x < 1 then
		local centerness = Base.ImSaturate(1 - math.abs(style.WindowTitleAlign.x - 0.5) * 2)
		local pad_extend = ImMin(ImMax(pad_l, pad_r), title_bar_rect:GetWidth() - pad_l - pad_r - text_size.x)
		pad_l = ImMax(pad_l, pad_extend * centerness)
		pad_r = ImMax(pad_r, pad_extend * centerness)
	end

	local layout_r = ImRect.fromXY(title_bar_rect.Min.x + pad_l, title_bar_rect.Min.y, title_bar_rect.Max.x - pad_r, title_bar_rect.Max.y)
	local clip_r = ImRect.fromXY(layout_r.Min.x, layout_r.Min.y, ImMin(layout_r.Max.x + g.Style.ItemInnerSpacing.x, title_bar_rect.Max.x), layout_r.Max.y)
	if btest(flags, ImGuiWindowFlags.UnsavedDocument) then
		local marker_pos = ImVec2(
			ImClamp(layout_r.Min.x + (layout_r:GetWidth() - text_size.x) * style.WindowTitleAlign.x + text_size.x, layout_r.Min.x, layout_r.Max.x),
			(layout_r.Min.y + layout_r.Max.y) * 0.5
		)
		if marker_pos.x > layout_r.Min.x then
			ImGui.RenderBullet(window.DrawList, marker_pos, ImGui.GetColorU32(ImGuiCol.UnsavedMarker))
			clip_r = clip_r:WithMaxX(ImMin(clip_r.Max.x, marker_pos.x - Base.ImTruncToInt(marker_size_x * 0.5)))
		end
	end
	ImGui.RenderTextClipped(layout_r.Min, layout_r.Max, name, nil, text_size, style.WindowTitleAlign, clip_r)
	return p_open
end

function ImGui.UpdateWindowParentAndRootLinks(window, flags, parent_window)
	window.ParentWindow = parent_window
	window.RootWindow = window
	window.RootWindowPopupTree = window
	window.RootWindowForTitleBarHighlight = window
	window.RootWindowForNav = window
	if parent_window and btest(flags, ImGuiWindowFlags.ChildWindow) and not btest(flags, ImGuiWindowFlags.Tooltip) then
		window.RootWindow = parent_window.RootWindow
	end
	if parent_window and btest(flags, ImGuiWindowFlags.Popup) then
		window.RootWindowPopupTree = parent_window.RootWindowPopupTree
	end
	if parent_window and not btest(flags, ImGuiWindowFlags.Modal) and btest(flags, bor(ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.Popup, ImGuiWindowFlags.Tooltip)) then
		window.RootWindowForTitleBarHighlight = parent_window.RootWindowForTitleBarHighlight
	end
	while btest(window.RootWindowForNav.ChildFlags, ImGuiChildFlags.NavFlattened) do
		assert(window.RootWindowForNav.ParentWindow ~= nil)
		window.RootWindowForNav = window.RootWindowForNav.ParentWindow
	end
end

function ImGui.UpdateWindowSkipRefresh(window)
	local g = ImGui.GImGui
	window.SkipRefresh = false
	if band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasRefreshPolicy) == 0 then
		return
	end
	if btest(g.NextWindowData.RefreshFlagsVal, ImGuiWindowRefreshFlags.TryToAvoidRefresh) then
		if window.Appearing then
			return
		end
		if window.Hidden then
			return
		end
		if btest(g.NextWindowData.RefreshFlagsVal, ImGuiWindowRefreshFlags.RefreshOnHover) and g.HoveredWindow then
			if window.RootWindow == g.HoveredWindow.RootWindow or ImGui.IsWindowWithinBeginStackOf(g.HoveredWindow.RootWindow, window) then
				return
			end
		end
		if btest(g.NextWindowData.RefreshFlagsVal, ImGuiWindowRefreshFlags.RefreshOnFocus) and g.NavWindow then
			if window.RootWindow == g.NavWindow.RootWindow or ImGui.IsWindowWithinBeginStackOf(g.NavWindow.RootWindow, window) then
				return
			end
		end
		window.DrawList = nil
		window.SkipRefresh = true
	end
end

function ImGui.SetWindowActiveForSkipRefresh(window)
	window.Active = true
	local children = window.DC.ChildWindows
	for i = 1, children.Size do
		local child = children[i]
		if not child.Hidden then
			child.Active = true
			child.SkipRefresh = true
			ImGui.SetWindowActiveForSkipRefresh(child)
		end
	end
end

function ImGui.Begin(name, p_open, flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local style = g.Style
	assert(name ~= nil and name ~= "")
	assert(g.WithinFrameScope)
	assert(g.FrameCountEnded ~= g.FrameCount)

	local window = ImGui.FindWindowByName(name)
	local window_just_created = (window == nil)
	if window_just_created then
		window = ImGui.CreateNewWindow(name, flags)
	end

	if btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasWindowFlags) then
		flags = band(bor(flags, g.NextWindowData.WindowFlagsSet), bnot(g.NextWindowData.WindowFlagsClear))
	end

	if band(flags, ImGuiWindowFlags.NoInputs) == ImGuiWindowFlags.NoInputs then
		flags = bor(flags, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize)
	end

	local current_frame = g.FrameCount
	local first_begin_of_the_frame = (window.LastFrameActive ~= current_frame)
	window.IsFallbackWindow = (g.CurrentWindowStack.Size == 0 and g.WithinFrameScopeWithImplicitWindow)

	local window_just_activated_by_user = (window.LastFrameActive < current_frame - 1)
	if btest(flags, ImGuiWindowFlags.Popup) then
		local popup_ref = g.OpenPopupStack[g.BeginPopupStack.Size + 1]
		window_just_activated_by_user = window_just_activated_by_user or (window.PopupId ~= popup_ref.PopupId)
		window_just_activated_by_user = window_just_activated_by_user or (window ~= popup_ref.Window)
	end
	window.Appearing = window_just_activated_by_user
	if window.Appearing then
		ImGui.SetWindowConditionAllowFlags(window, ImGuiCond.Appearing, true)
	end

	if first_begin_of_the_frame then
		ImGui.UpdateWindowInFocusOrderList(window, window_just_created, flags)
		window.Flags = flags
		window.ChildFlags = btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasChildFlags) and g.NextWindowData.ChildFlagsSet or 0
		window.LastFrameActive = current_frame
		window.LastTimeActive = g.Time
		window.BeginOrderWithinParent = 0
		window.BeginOrderWithinContext = g.WindowsActiveCount
		g.WindowsActiveCount += 1
	else
		flags = window.Flags
	end

	local parent_window_in_stack = nil
	if not g.CurrentWindowStack:empty() then
		parent_window_in_stack = g.CurrentWindowStack:back().Window
	end
	local parent_window
	if first_begin_of_the_frame then
		if btest(flags, bor(ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.Popup, ImGuiWindowFlags.Tooltip)) then
			parent_window = parent_window_in_stack
		else
			parent_window = nil
		end
	else
		parent_window = window.ParentWindow
	end
	assert(parent_window ~= nil or not btest(flags, ImGuiWindowFlags.ChildWindow))

	if window.IDStack.Size == 0 then
		window.IDStack:push_back(window.ID)
	end

	g.CurrentWindow = window
	local window_stack_data = Structs.ImGuiWindowStackData.new()
	g.CurrentWindowStack:push_back(window_stack_data)
	window_stack_data.Window = window
	window_stack_data.ParentLastItemDataBackup = g.LastItemData:Copy()
	window_stack_data.DisabledOverrideReenable = btest(flags, ImGuiWindowFlags.Tooltip) and btest(g.CurrentItemFlags, ImGuiItemFlags.Disabled)
	window_stack_data.DisabledOverrideReenableAlphaBackup = 0
	ImGui.ErrorRecoveryStoreState(window_stack_data.StackSizesInBegin)
	g.StackSizesInBeginForCurrentWindow = window_stack_data.StackSizesInBegin
	if btest(flags, ImGuiWindowFlags.ChildMenu) then
		g.BeginMenuDepth += 1
	end

	if first_begin_of_the_frame then
		ImGui.UpdateWindowParentAndRootLinks(window, flags, parent_window)
		window.ParentWindowInBeginStack = parent_window_in_stack

		if btest(flags, ImGuiWindowFlags.ChildWindow) then
			window.ParentWindowForFocusRoute = parent_window_in_stack
		else
			window.ParentWindowForFocusRoute = nil
		end

		window.FontWindowScaleParents = parent_window and parent_window.FontWindowScaleParents * parent_window.FontWindowScale or 1
	end

	ImGui.PushFocusScope(btest(window.ChildFlags, ImGuiChildFlags.NavFlattened) and g.CurrentFocusScopeId or window.ID)
	window.NavRootFocusScopeId = g.CurrentFocusScopeId

	if btest(flags, ImGuiWindowFlags.Popup) then
		local popup_ref = g.OpenPopupStack[g.BeginPopupStack.Size + 1]
		popup_ref.Window = window
		popup_ref.ParentNavLayer = parent_window_in_stack.DC.NavLayerCurrent
		g.BeginPopupStack:push_back(popup_ref:Copy())
		window.PopupId = popup_ref.PopupId
	end

	local nwd = g.NextWindowData
	local window_pos_set_by_api = false
	local window_size_x_set_by_api, window_size_y_set_by_api = false, false
	if btest(nwd.HasFlags, ImGuiNextWindowDataFlags.HasPos) then
		window_pos_set_by_api = band(window.SetWindowPosAllowFlags, nwd.PosCond) ~= 0
		if window_pos_set_by_api and Base.ImLengthSqr(nwd.PosPivotVal) > 0.00001 then
			window.SetWindowPosVal = nwd.PosVal
			window.SetWindowPosPivot = nwd.PosPivotVal
			window.SetWindowPosAllowFlags = band(window.SetWindowPosAllowFlags, bnot(bor(ImGuiCond.Once, ImGuiCond.FirstUseEver, ImGuiCond.Appearing)))
		else
			ImGui.SetWindowPos(window, nwd.PosVal, nwd.PosCond)
		end
	end
	if btest(nwd.HasFlags, ImGuiNextWindowDataFlags.HasSize) then
		window_size_x_set_by_api = band(window.SetWindowSizeAllowFlags, nwd.SizeCond) ~= 0 and (nwd.SizeVal.x > 0)
		window_size_y_set_by_api = band(window.SetWindowSizeAllowFlags, nwd.SizeCond) ~= 0 and (nwd.SizeVal.y > 0)
		if btest(window.ChildFlags, ImGuiChildFlags.ResizeX) and band(window.SetWindowSizeAllowFlags, ImGuiCond.FirstUseEver) == 0 then
			nwd.SizeVal = ImVec2(window.SizeFull.x, nwd.SizeVal.y)
		end
		if btest(window.ChildFlags, ImGuiChildFlags.ResizeY) and band(window.SetWindowSizeAllowFlags, ImGuiCond.FirstUseEver) == 0 then
			nwd.SizeVal = ImVec2(nwd.SizeVal.x, window.SizeFull.y)
		end
		ImGui.SetWindowSize(window, nwd.SizeVal, nwd.SizeCond)
	end
	if btest(nwd.HasFlags, ImGuiNextWindowDataFlags.HasScroll) then
		if nwd.ScrollVal.x >= 0 then
			window.ScrollTarget = ImVec2(nwd.ScrollVal.x, window.ScrollTarget.y)
			window.ScrollTargetCenterRatio = ImVec2(0, window.ScrollTargetCenterRatio.y)
		end
		if nwd.ScrollVal.y >= 0 then
			window.ScrollTarget = ImVec2(window.ScrollTarget.x, nwd.ScrollVal.y)
			window.ScrollTargetCenterRatio = ImVec2(window.ScrollTargetCenterRatio.x, 0)
		end
	end
	if btest(nwd.HasFlags, ImGuiNextWindowDataFlags.HasContentSize) then
		window.ContentSizeExplicit = nwd.ContentSizeVal
	elseif first_begin_of_the_frame then
		window.ContentSizeExplicit = ImVec2(0, 0)
	end
	if btest(nwd.HasFlags, ImGuiNextWindowDataFlags.HasCollapsed) then
		ImGui.SetWindowCollapsed(window, nwd.CollapsedVal, nwd.CollapsedCond)
	end
	if btest(nwd.HasFlags, ImGuiNextWindowDataFlags.HasFocus) then
		ImGui.FocusWindow(window)
	end
	if window.Appearing then
		ImGui.SetWindowConditionAllowFlags(window, ImGuiCond.Appearing, false)
	end

	ImGui.UpdateWindowSkipRefresh(window)

	if window_stack_data.DisabledOverrideReenable and window.RootWindow == window then
		ImGui.BeginDisabledOverrideReenable()
	end

	g.CurrentWindow = nil

	if first_begin_of_the_frame and not window.SkipRefresh then
		local window_is_child_tooltip = btest(flags, ImGuiWindowFlags.ChildWindow) and btest(flags, ImGuiWindowFlags.Tooltip)
		local window_just_appearing_after_hidden_for_resize = (window.HiddenFramesCannotSkipItems > 0)
		window.Active = true
		window.HasCloseButton = (p_open ~= nil)
		window.ClipRect = ImRect.fromXY(-FLT_MAX, -FLT_MAX, FLT_MAX, FLT_MAX)
		window.IDStack:resize(1)
		window.DrawList:_ResetForNewFrame()
		window.DC.CurrentTableIdx = -1

		if window.MemoryCompacted then
			ImGui.GcAwakeTransientWindowBuffers(window)
		end

		local window_title_visible_elsewhere = false
		if g.NavWindowingListWindow ~= nil and g.NavWindowingListWindow.WasActive and band(flags, ImGuiWindowFlags.NoNavFocus) == 0 then
			window_title_visible_elsewhere = true
		end
		if btest(flags, ImGuiWindowFlags.ChildMenu) then
			window_title_visible_elsewhere = true
		end
		if (window_title_visible_elsewhere or window_just_activated_by_user) and not window_just_created and name ~= window.Name then
			window.Name = name
			window.NameBufLen = math.max(window.NameBufLen, #name + 1)
			window.DrawList._OwnerName = window.Name
		end

		window.ContentSize, window.ContentSizeIdeal = ImGui.CalcWindowContentSizes(window, window.ContentSize, window.ContentSizeIdeal)
		if window.HiddenFramesCanSkipItems > 0 then
			window.HiddenFramesCanSkipItems -= 1
		end
		if window.HiddenFramesCannotSkipItems > 0 then
			window.HiddenFramesCannotSkipItems -= 1
		end
		if window.HiddenFramesForRenderOnly > 0 then
			window.HiddenFramesForRenderOnly -= 1
		end

		if window_just_created and (not window_size_x_set_by_api or not window_size_y_set_by_api) then
			window.HiddenFramesCannotSkipItems = 1
		end

		if window_just_activated_by_user and band(flags, bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.Tooltip)) ~= 0 then
			window.HiddenFramesCannotSkipItems = 1
			if btest(flags, ImGuiWindowFlags.AlwaysAutoResize) then
				if not window_size_x_set_by_api then
					window.SizeFull = ImVec2(0, window.SizeFull.y)
					window.Size = ImVec2(0, window.Size.y)
				end
				if not window_size_y_set_by_api then
					window.SizeFull = ImVec2(window.SizeFull.x, 0)
					window.Size = ImVec2(window.Size.x, 0)
				end
				window.ContentSize = ImVec2(0, 0)
				window.ContentSizeIdeal = ImVec2(0, 0)
			end
		end

		local viewport = ImGui.GetMainViewport()
		ImGui.SetWindowViewport(window, viewport)
		ImGui.SetCurrentWindow(window)

		if btest(flags, ImGuiWindowFlags.ChildWindow) then
			window.WindowBorderSize = style.ChildBorderSize
		else
			window.WindowBorderSize = (btest(flags, bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.Tooltip)) and not btest(flags, ImGuiWindowFlags.Modal)) and style.PopupBorderSize or style.WindowBorderSize
		end
		window.WindowPadding = style.WindowPadding
		if btest(flags, ImGuiWindowFlags.ChildWindow) and not btest(flags, ImGuiWindowFlags.Popup) and not btest(window.ChildFlags, ImGuiChildFlags.AlwaysUseWindowPadding) and window.WindowBorderSize == 0 then
			window.WindowPadding = ImVec2(0, btest(flags, ImGuiWindowFlags.MenuBar) and style.WindowPadding.y or 0)
		end

		window.DC.MenuBarOffset = ImVec2(ImMax(ImMax(window.WindowPadding.x, style.ItemSpacing.x), nwd.MenuBarOffsetMinVal.x), nwd.MenuBarOffsetMinVal.y)
		window.TitleBarHeight = btest(flags, ImGuiWindowFlags.NoTitleBar) and 0 or g.FontSize + g.Style.FramePadding.y * 2
		window.MenuBarHeight = btest(flags, ImGuiWindowFlags.MenuBar) and window.DC.MenuBarOffset.y + g.FontSize + g.Style.FramePadding.y * 2 or 0
		window.FontRefSize = g.FontSize

		local use_current_size_for_scrollbar_x = window_just_created
		local use_current_size_for_scrollbar_y = window_just_created
		if window_size_x_set_by_api and window.ContentSizeExplicit.x ~= 0 then
			use_current_size_for_scrollbar_x = true
		end
		if window_size_y_set_by_api and window.ContentSizeExplicit.y ~= 0 then
			use_current_size_for_scrollbar_y = true
		end

		if not btest(flags, ImGuiWindowFlags.NoTitleBar) and not btest(flags, ImGuiWindowFlags.NoCollapse) then
			local title_bar_rect = window:TitleBarRect()
			if g.HoveredWindow == window and g.HoveredId == 0 and g.HoveredIdPreviousFrame == 0 and g.ActiveId == 0 and ImGui.IsMouseHoveringRect(title_bar_rect.Min, title_bar_rect.Max) then
				if g.IO.MouseClickedCount[1] == 2 and ImGui.GetKeyOwner(ImGuiKey.MouseLeft) == ImGuiKeyOwner.NoOwner then
					window.WantCollapseToggle = true
					ImGui.SetKeyOwner(ImGuiKey.MouseLeft, window.MoveId)
				end
			end
			if window.WantCollapseToggle then
				window.Collapsed = not window.Collapsed
				if not window.Collapsed then
					use_current_size_for_scrollbar_y = true
				end
				ImGui.MarkIniSettingsDirty(window)
			end
		else
			window.Collapsed = false
		end
		window.WantCollapseToggle = false

		local scrollbar_sizes_from_last_frame = window.ScrollbarSizes
		window.DecoOuterSizeX1 = 0
		window.DecoOuterSizeX2 = 0
		window.DecoOuterSizeY1 = window.TitleBarHeight + window.MenuBarHeight
		window.DecoOuterSizeY2 = 0
		window.ScrollbarSizes = ImVec2(0, 0)

		do
			local size_auto_fit_x_always = not window_size_x_set_by_api and btest(flags, ImGuiWindowFlags.AlwaysAutoResize) and not window.Collapsed
			local size_auto_fit_y_always = not window_size_y_set_by_api and btest(flags, ImGuiWindowFlags.AlwaysAutoResize) and not window.Collapsed
			local size_auto_fit_x_current = not window_size_x_set_by_api and (window.AutoFitFramesX > 0)
			local size_auto_fit_y_current = not window_size_y_set_by_api and (window.AutoFitFramesY > 0)
			local size_auto_fit_mask = 0
			if size_auto_fit_x_always or size_auto_fit_x_current then
				size_auto_fit_mask = bor(size_auto_fit_mask, lshift(1, ImGuiAxis.X))
			end
			if size_auto_fit_y_always or size_auto_fit_y_current then
				size_auto_fit_mask = bor(size_auto_fit_mask, lshift(1, ImGuiAxis.Y))
			end
			local size_auto_fit = ImGui.CalcWindowAutoFitSize(window, window.ContentSizeIdeal, size_auto_fit_mask)

			local old_size = window.SizeFull
			if size_auto_fit_x_always or size_auto_fit_x_current then
				if size_auto_fit_x_always then
					window.SizeFull = ImVec2(size_auto_fit.x, window.SizeFull.y)
				else
					window.SizeFull = ImVec2(window.AutoFitOnlyGrows and ImMax(window.SizeFull.x, size_auto_fit.x) or size_auto_fit.x, window.SizeFull.y)
				end
				use_current_size_for_scrollbar_x = true
			end
			if size_auto_fit_y_always or size_auto_fit_y_current then
				if size_auto_fit_y_always then
					window.SizeFull = ImVec2(window.SizeFull.x, size_auto_fit.y)
				else
					window.SizeFull = ImVec2(window.SizeFull.x, window.AutoFitOnlyGrows and ImMax(window.SizeFull.y, size_auto_fit.y) or size_auto_fit.y)
				end
				use_current_size_for_scrollbar_y = true
			end
			if old_size.x ~= window.SizeFull.x or old_size.y ~= window.SizeFull.y then
				ImGui.MarkIniSettingsDirty(window)
			end
		end

		window.SizeFull = ImGui.CalcWindowSizeAfterConstraint(window, window.SizeFull)
		if window.Collapsed and not btest(flags, ImGuiWindowFlags.ChildWindow) then
			window.Size = window:TitleBarRect():GetSize()
		else
			window.Size = window.SizeFull
		end

		if window_just_activated_by_user then
			window.AutoPosLastDirection = ImGuiDir.None
			if btest(flags, ImGuiWindowFlags.Popup) and not btest(flags, ImGuiWindowFlags.Modal) and not window_pos_set_by_api then
				window.Pos = g.BeginPopupStack:back().OpenPopupPos
			end
		end

		if btest(flags, ImGuiWindowFlags.ChildWindow) then
			assert(parent_window and parent_window.Active)
			window.BeginOrderWithinParent = parent_window.DC.ChildWindows.Size
			parent_window.DC.ChildWindows:push_back(window)
			if not btest(flags, ImGuiWindowFlags.Popup) and not window_pos_set_by_api and not window_is_child_tooltip then
				window.Pos = parent_window.DC.CursorPos
			end
		end

		local window_pos_with_pivot = (window.SetWindowPosVal.x ~= FLT_MAX and window.HiddenFramesCannotSkipItems == 0)
		if window_pos_with_pivot then
			ImGui.SetWindowPos(window, window.SetWindowPosVal - window.Size * window.SetWindowPosPivot, 0)
		elseif btest(flags, ImGuiWindowFlags.ChildMenu) then
			window.Pos = ImGui.FindBestWindowPosForPopup(window)
		elseif btest(flags, ImGuiWindowFlags.Popup) and not window_pos_set_by_api and window_just_appearing_after_hidden_for_resize then
			window.Pos = ImGui.FindBestWindowPosForPopup(window)
		elseif btest(flags, ImGuiWindowFlags.Tooltip) and not window_pos_set_by_api and not window_is_child_tooltip then
			window.Pos = ImGui.FindBestWindowPosForPopup(window)
		end

		local viewport_rect = viewport:GetMainRect()
		local viewport_work_rect = viewport:GetWorkRect()
		local visibility_padding = ImMax(style.DisplayWindowPadding, style.DisplaySafeAreaPadding)
		local visibility_rect = ImRect.new(viewport_work_rect.Min + visibility_padding, viewport_work_rect.Max - visibility_padding)

		if not window_pos_set_by_api and not btest(flags, ImGuiWindowFlags.ChildWindow) then
			if viewport_rect:GetWidth() > 0 and viewport_rect:GetHeight() > 0 then
				ImGui.ClampWindowPos(window, visibility_rect)
			end
		end
		window.Pos = ImTrunc(window.Pos)

		if btest(flags, ImGuiWindowFlags.ChildWindow) then
			window.WindowRounding = style.ChildRounding
		elseif btest(flags, ImGuiWindowFlags.Popup) and not btest(flags, ImGuiWindowFlags.Modal) then
			window.WindowRounding = style.PopupRounding
		else
			window.WindowRounding = style.WindowRounding
		end

		local want_focus = false
		if window_just_activated_by_user and not btest(flags, ImGuiWindowFlags.NoFocusOnAppearing) then
			if btest(flags, ImGuiWindowFlags.Popup) then
				want_focus = true
			elseif band(flags, bor(ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.Tooltip)) == 0 then
				want_focus = true
			end
		end

		local handle_borders_and_resize_grips = true
		if btest(flags, ImGuiWindowFlags.ChildWindow) and window.ParentWindow.SkipItems then
			handle_borders_and_resize_grips = false
		end

		local border_hovered, border_held = -1, -1
		local resize_grip_col = { 0, 0, 0, 0 }
		local resize_grip_count
		if btest(flags, ImGuiWindowFlags.ChildWindow) and not btest(flags, ImGuiWindowFlags.Popup) then
			resize_grip_count = (btest(window.ChildFlags, ImGuiChildFlags.ResizeX) and btest(window.ChildFlags, ImGuiChildFlags.ResizeY)) and 1 or 0
		else
			resize_grip_count = g.IO.ConfigWindowsResizeFromEdges and 2 or 1
		end

		local resize_grip_draw_size = IM_TRUNC(ImMax(g.FontSize * 1.10, window.WindowRounding + 1 + g.FontSize * 0.2))
		if handle_borders_and_resize_grips and not window.Collapsed then
			local auto_fit_mask
			auto_fit_mask, border_hovered, border_held = ImGui.UpdateWindowManualResize(window, border_hovered, border_held, resize_grip_count, resize_grip_col, visibility_rect)
			if auto_fit_mask ~= 0 then
				if btest(auto_fit_mask, lshift(1, ImGuiAxis.X)) then
					use_current_size_for_scrollbar_x = true
				end
				if btest(auto_fit_mask, lshift(1, ImGuiAxis.Y)) then
					use_current_size_for_scrollbar_y = true
				end
			end
		end
		window.ResizeBorderHovered = border_hovered
		window.ResizeBorderHeld = border_held

		if not window.Collapsed then
			local avail_size_from_current_frame = ImVec2(window.SizeFull.x, window.SizeFull.y - (window.DecoOuterSizeY1 + window.DecoOuterSizeY2))
			local avail_size_from_last_frame = window.InnerRect:GetSize() + scrollbar_sizes_from_last_frame
			local needed_size_from_last_frame = window_just_created and ImVec2(0, 0) or window.ContentSize + window.WindowPadding * 2
			local size_for_scrollbars_x = use_current_size_for_scrollbar_x and avail_size_from_current_frame.x or avail_size_from_last_frame.x
			local size_for_scrollbars_y = use_current_size_for_scrollbar_y and avail_size_from_current_frame.y or avail_size_from_last_frame.y
			local scrollbar_x_prev = window.ScrollbarX
			window.ScrollbarY = btest(flags, ImGuiWindowFlags.AlwaysVerticalScrollbar) or ((needed_size_from_last_frame.y > size_for_scrollbars_y) and not btest(flags, ImGuiWindowFlags.NoScrollbar))
			window.ScrollbarX = btest(flags, ImGuiWindowFlags.AlwaysHorizontalScrollbar) or ((needed_size_from_last_frame.x > size_for_scrollbars_x - (window.ScrollbarY and style.ScrollbarSize or 0)) and not btest(flags, ImGuiWindowFlags.NoScrollbar) and btest(flags, ImGuiWindowFlags.HorizontalScrollbar))

			window.ScrollbarXStabilizeToggledHistory = band(lshift(window.ScrollbarXStabilizeToggledHistory, 1), 0xFF)
			window.ScrollbarXStabilizeToggledHistory = bor(window.ScrollbarXStabilizeToggledHistory, (scrollbar_x_prev ~= window.ScrollbarX) and 0x01 or 0x00)
			local scrollbar_x_stabilize = (window.ScrollbarXStabilizeToggledHistory ~= 0) and Base.ImCountSetBits(window.ScrollbarXStabilizeToggledHistory) >= 4
			if scrollbar_x_stabilize then
				window.ScrollbarX = true
			end
			window.ScrollbarXStabilizeEnabled = scrollbar_x_stabilize

			if window.ScrollbarX and not window.ScrollbarY then
				window.ScrollbarY = (needed_size_from_last_frame.y > size_for_scrollbars_y - style.ScrollbarSize) and not btest(flags, ImGuiWindowFlags.NoScrollbar)
			end
			window.ScrollbarSizes = ImVec2(window.ScrollbarY and style.ScrollbarSize or 0, window.ScrollbarX and style.ScrollbarSize or 0)

			window.DecoOuterSizeX2 += window.ScrollbarSizes.x
			window.DecoOuterSizeY2 += window.ScrollbarSizes.y
		end

		local host_rect
		if btest(flags, ImGuiWindowFlags.ChildWindow) and not btest(flags, ImGuiWindowFlags.Popup) and not window_is_child_tooltip then
			host_rect = parent_window.ClipRect
		else
			host_rect = viewport_rect
		end
		local outer_rect = window:Rect()
		local title_bar_rect = window:TitleBarRect()
		window.OuterRectClipped = outer_rect:ClippedWith(host_rect)

		window.InnerRect = ImRect.fromXY(
			window.Pos.x + window.DecoOuterSizeX1,
			window.Pos.y + window.DecoOuterSizeY1,
			window.Pos.x + window.Size.x - window.DecoOuterSizeX2,
			window.Pos.y + window.Size.y - window.DecoOuterSizeY2
		)

		local top_border_size = (btest(flags, ImGuiWindowFlags.MenuBar) or not btest(flags, ImGuiWindowFlags.NoTitleBar)) and style.FrameBorderSize or window.WindowBorderSize

		window.InnerClipRect = ImRect.fromXY(
			ImFloor(0.5 + window.InnerRect.Min.x + window.WindowBorderSize * 0.5),
			ImFloor(0.5 + window.InnerRect.Min.y + top_border_size * 0.5),
			ImFloor(window.InnerRect.Max.x - window.WindowBorderSize * 0.5),
			ImFloor(window.InnerRect.Max.y - window.WindowBorderSize * 0.5)
		):ClippedWithFull(host_rect)

		window.ScrollMax = ImVec2(
			ImMax(0, window.ContentSize.x + window.WindowPadding.x * 2 - window.InnerRect:GetWidth()),
			ImMax(0, window.ContentSize.y + window.WindowPadding.y * 2 - window.InnerRect:GetHeight())
		)

		window.Scroll = ImGui.CalcNextScrollFromScrollTargetAndClamp(window)
		window.ScrollTarget = ImVec2(FLT_MAX, FLT_MAX)
		window.DecoInnerSizeX1 = 0
		window.DecoInnerSizeY1 = 0

		assert(window.DrawList.CmdBuffer.Size == 1 and window.DrawList.CmdBuffer[1].ElemCount == 0)
		window.DrawList:_SetPixelDensity(window.Viewport.FramebufferScale.x)
		window.DrawList:PushTexture(g.Font.OwnerAtlas.TexRef)
		ImGui.PushClipRect(host_rect.Min, host_rect.Max, false)

		do
			local render_decorations_in_parent = false
			if btest(flags, ImGuiWindowFlags.ChildWindow) and not btest(flags, ImGuiWindowFlags.Popup) and not window_is_child_tooltip then
				local previous_child = nil
				if parent_window.DC.ChildWindows.Size >= 2 then
					previous_child = parent_window.DC.ChildWindows[parent_window.DC.ChildWindows.Size - 1]
				end
				local previous_child_overlapping = false
				if previous_child then
					previous_child_overlapping = previous_child:Rect():Overlaps(window:Rect())
				end
				local parent_is_empty = (parent_window.DrawList:GetPrimCount() == 0)
				if window.DrawList.CmdBuffer:back().ElemCount == 0 and not parent_is_empty and not previous_child_overlapping then
					render_decorations_in_parent = true
				end
			end
			if render_decorations_in_parent then
				window.DrawList = parent_window.DrawList
			end

			local window_to_highlight = g.NavWindowingTarget or g.NavWindow
			local title_bar_is_highlight = want_focus or (window_to_highlight ~= nil and window.RootWindowForTitleBarHighlight == window_to_highlight.RootWindowForTitleBarHighlight)
			ImGui.RenderWindowDecorations(window, title_bar_rect, title_bar_is_highlight, handle_borders_and_resize_grips, resize_grip_count, resize_grip_col, resize_grip_draw_size)

			if render_decorations_in_parent then
				window.DrawList = window.DrawListInst
			end
		end

		local allow_scrollbar_x = not btest(flags, ImGuiWindowFlags.NoScrollbar) and btest(flags, ImGuiWindowFlags.HorizontalScrollbar)
		local allow_scrollbar_y = not btest(flags, ImGuiWindowFlags.NoScrollbar)
		local work_rect_size_x = (window.ContentSizeExplicit.x ~= 0) and window.ContentSizeExplicit.x or ImMax(allow_scrollbar_x and window.ContentSize.x or 0, window.Size.x - window.WindowPadding.x * 2 - (window.DecoOuterSizeX1 + window.DecoOuterSizeX2))
		local work_rect_size_y = (window.ContentSizeExplicit.y ~= 0) and window.ContentSizeExplicit.y or ImMax(allow_scrollbar_y and window.ContentSize.y or 0, window.Size.y - window.WindowPadding.y * 2 - (window.DecoOuterSizeY1 + window.DecoOuterSizeY2))
		local work_min_x = ImTrunc(window.InnerRect.Min.x - window.Scroll.x + ImMax(window.WindowPadding.x, window.WindowBorderSize))
		local work_min_y = ImTrunc(window.InnerRect.Min.y - window.Scroll.y + ImMax(window.WindowPadding.y, window.WindowBorderSize))
		window.WorkRect = ImRect.fromXY(work_min_x, work_min_y, work_min_x + work_rect_size_x, work_min_y + work_rect_size_y)
		window.ParentWorkRect = window.WorkRect

		local content_min_x = window.Pos.x - window.Scroll.x + window.WindowPadding.x + window.DecoOuterSizeX1
		local content_min_y = window.Pos.y - window.Scroll.y + window.WindowPadding.y + window.DecoOuterSizeY1
		window.ContentRegionRect = ImRect.fromXY(
			content_min_x,
			content_min_y,
			content_min_x + ((window.ContentSizeExplicit.x ~= 0) and window.ContentSizeExplicit.x or (window.Size.x - window.WindowPadding.x * 2 - (window.DecoOuterSizeX1 + window.DecoOuterSizeX2))),
			content_min_y + ((window.ContentSizeExplicit.y ~= 0) and window.ContentSizeExplicit.y or (window.Size.y - window.WindowPadding.y * 2 - (window.DecoOuterSizeY1 + window.DecoOuterSizeY2)))
		)

		local dc = window.DC
		dc.Indent.x = window.DecoOuterSizeX1 + window.WindowPadding.x - window.Scroll.x
		dc.GroupOffset.x = 0
		dc.ColumnsOffset.x = 0

		local start_pos_highp_x = window.Pos.x + window.WindowPadding.x - window.Scroll.x + window.DecoOuterSizeX1 + dc.ColumnsOffset.x
		local start_pos_highp_y = window.Pos.y + window.WindowPadding.y - window.Scroll.y + window.DecoOuterSizeY1
		dc.CursorStartPos = ImVec2(start_pos_highp_x, start_pos_highp_y)
		dc.CursorStartPosLossyness = ImVec2(start_pos_highp_x - dc.CursorStartPos.x, start_pos_highp_y - dc.CursorStartPos.y)
		dc.CursorPos = dc.CursorStartPos
		dc.CursorPosPrevLine = dc.CursorPos
		dc.CursorMaxPos = dc.CursorStartPos
		dc.IdealMaxPos = dc.CursorStartPos
		dc.CurrLineSize = ImVec2(0, 0)
		dc.PrevLineSize = ImVec2(0, 0)
		dc.CurrLineTextBaseOffset = 0
		dc.PrevLineTextBaseOffset = 0
		dc.IsSameLine = false
		dc.IsSetPos = false

		dc.NavLayerCurrent = ImGuiNavLayer.Main
		dc.NavLayersActiveMask = dc.NavLayersActiveMaskNext
		dc.NavLayersActiveMaskNext = 0x00
		dc.NavIsScrollPushableX = true
		dc.NavHideHighlightOneFrame = false
		dc.NavWindowHasScrollY = (window.ScrollMax.y > 0)

		dc.MenuBarAppending = false
		dc.MenuColumns:Update(style.ItemSpacing.x, window_just_activated_by_user)
		dc.TreeDepth = 0
		dc.TreeHasStackDataDepthMask = 0x00
		dc.TreeRecordsClippedNodesY2Mask = 0x00
		dc.ChildWindows:resize(0)
		dc.StateStorage = window.StateStorage
		dc.CurrentColumns = nil
		dc.LayoutType = ImGuiLayoutType.Vertical
		dc.ParentLayoutType = parent_window and parent_window.DC.LayoutType or ImGuiLayoutType.Vertical

		local is_resizable_width
		if btest(flags, ImGuiWindowFlags.ChildWindow) then
			is_resizable_width = (window.Size.x > 0) and not btest(window.ChildFlags, bor(ImGuiChildFlags.AutoResizeX, ImGuiChildFlags.AlwaysAutoResize))
		else
			is_resizable_width = (window.Size.x > 0) and not btest(flags, ImGuiWindowFlags.AlwaysAutoResize)
		end
		if is_resizable_width then
			dc.ItemWidthDefault = ImTrunc(window.Size.x * 0.65)
		else
			dc.ItemWidthDefault = ImTrunc(g.FontSize * 16)
		end
		dc.ItemWidth = dc.ItemWidthDefault
		dc.ItemWidthStack:resize(0)
		dc.TextWrapPos = -1
		dc.TextWrapPosStack:resize(0)
		if btest(flags, ImGuiWindowFlags.Modal) then
			dc.ModalDimBgColor = ImGui.ColorConvertFloat4ToU32(ImGui.GetStyleColorVec4(ImGuiCol.ModalWindowDimBg))
		end

		if window.AutoFitFramesX > 0 then
			window.AutoFitFramesX -= 1
		end
		if window.AutoFitFramesY > 0 then
			window.AutoFitFramesY -= 1
		end

		if want_focus then
			ImGui.FocusWindow(window, ImGuiFocusRequestFlags.UnlessBelowModal)
		end
		if want_focus and window == g.NavWindow then
			ImGui.NavInitWindow(window, false)
		end

		if g.IO.ConfigWindowsCopyContentsWithCtrlC then
			if g.NavWindow and g.NavWindow.RootWindow == window and g.ActiveId == 0 and ImGui.Shortcut(bor(ImGuiMod.Ctrl, ImGuiKey.C)) then
				ImGui.LogToClipboard(0)
			end
		end

		if not btest(flags, ImGuiWindowFlags.NoTitleBar) then
			p_open = ImGui.RenderWindowTitleBarContents(window, ImRect.fromXY(title_bar_rect.Min.x + window.WindowBorderSize, title_bar_rect.Min.y, title_bar_rect.Max.x - window.WindowBorderSize, title_bar_rect.Max.y), name, p_open)
		end

		window.HitTestHoleSize = ImVec2(0, 0)

		if btest(flags, ImGuiWindowFlags.Tooltip) then
			g.TooltipPreviousWindow = window
		end

		if btest(flags, ImGuiWindowFlags.ChildWindow) then
			window.BgClickFlags = parent_window.BgClickFlags
		else
			window.BgClickFlags = g.IO.ConfigWindowsMoveFromTitleBarOnly and ImGuiWindowBgClickFlags.None or ImGuiWindowBgClickFlags.Move
		end

		dc.WindowItemStatusFlags = ImGuiItemStatusFlags.None
		dc.WindowItemStatusFlags = bor(dc.WindowItemStatusFlags, ImGui.IsMouseHoveringRect(title_bar_rect.Min, title_bar_rect.Max, false) and ImGuiItemStatusFlags.HoveredRect or 0)
		ImGui.SetLastItemDataForWindow(window, title_bar_rect)

		if g.DebugLocateId ~= 0 and (window.ID == g.DebugLocateId or window.MoveId == g.DebugLocateId) then
			ImGui.DebugLocateItemResolveWithLastItem()
		end
	else
		if window.SkipRefresh then
			ImGui.SetWindowActiveForSkipRefresh(window)
		end

		ImGui.SetCurrentWindow(window)
		ImGui.SetLastItemDataForWindow(window, window:TitleBarRect())
	end

	if not window.SkipRefresh then
		ImGui.PushClipRect(window.InnerClipRect.Min, window.InnerClipRect.Max, true)
	end

	window.WriteAccessed = false
	window.BeginCount += 1
	g.NextWindowData:ClearFlags()

	if first_begin_of_the_frame and not window.SkipRefresh then
		if btest(flags, ImGuiWindowFlags.ChildWindow) and not btest(flags, ImGuiWindowFlags.ChildMenu) then
			assert(band(flags, ImGuiWindowFlags.NoTitleBar) ~= 0)
			local nav_request = btest(window.ChildFlags, ImGuiChildFlags.NavFlattened) and (g.NavAnyRequest and g.NavWindow ~= nil and g.NavWindow.RootWindowForNav == window.RootWindowForNav)
			if not g.LogEnabled and not nav_request then
				if window.OuterRectClipped.Min.x >= window.OuterRectClipped.Max.x or window.OuterRectClipped.Min.y >= window.OuterRectClipped.Max.y then
					if window.AutoFitFramesX > 0 or window.AutoFitFramesY > 0 then
						window.HiddenFramesCannotSkipItems = 1
					else
						window.HiddenFramesCanSkipItems = 1
					end
				end
			end

			if parent_window and (parent_window.Collapsed or parent_window.HiddenFramesCanSkipItems > 0) then
				window.HiddenFramesCanSkipItems = 1
			end
			if parent_window and parent_window.HiddenFramesCannotSkipItems > 0 then
				window.HiddenFramesCannotSkipItems = 1
			end
		end

		if style.Alpha <= 0 then
			window.HiddenFramesCanSkipItems = 1
		end

		local hidden_regular = (window.HiddenFramesCanSkipItems > 0) or (window.HiddenFramesCannotSkipItems > 0)
		window.Hidden = hidden_regular or (window.HiddenFramesForRenderOnly > 0)

		if window.DisableInputsFrames > 0 then
			window.DisableInputsFrames -= 1
			window.Flags = bor(window.Flags, ImGuiWindowFlags.NoInputs)
		end

		local skip_items = false
		if window.Collapsed or not window.Active or hidden_regular then
			if window.AutoFitFramesX <= 0 and window.AutoFitFramesY <= 0 and window.HiddenFramesCannotSkipItems <= 0 then
				skip_items = true
			end
		end
		window.SkipItems = skip_items
	elseif first_begin_of_the_frame then
		window.SkipItems = true
	end

	if not window.IsFallbackWindow then
		if (g.IO.ConfigDebugBeginReturnValueOnce and window_just_created) or (g.IO.ConfigDebugBeginReturnValueLoop and g.DebugBeginReturnValueCullDepth == g.CurrentWindowStack.Size) then
			if window.AutoFitFramesX > 0 then
				window.AutoFitFramesX += 1
			end
			if window.AutoFitFramesY > 0 then
				window.AutoFitFramesY += 1
			end
			return false, p_open
		end
	end

	return not window.SkipItems, p_open
end

function ImGui.End()
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	if g.CurrentWindowStack.Size <= 1 and g.WithinFrameScopeWithImplicitWindow then
		IM_ASSERT_USER_ERROR(g.CurrentWindowStack.Size > 1, "Calling End() too many times!")
		return
	end
	local window_stack_data = g.CurrentWindowStack:back()

	if btest(window.Flags, ImGuiWindowFlags.Popup) then
		IM_ASSERT_USER_ERROR(g.WithinEndPopupID == window.ID, "Must call EndPopup() and not End()!")
	end
	if btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
		IM_ASSERT_USER_ERROR(g.WithinEndChildID == window.ID, "Must call EndChild() and not End()!")
	end

	if window.DC.CurrentColumns then
		ImGui.EndColumns()
	end
	if not window.SkipRefresh then
		ImGui.PopClipRect()
	end
	ImGui.PopFocusScope()
	if window_stack_data.DisabledOverrideReenable and window.RootWindow == window then
		ImGui.EndDisabledOverrideReenable()
	end

	if window.SkipRefresh then
		assert(window.DrawList == nil)
		window.DrawList = window.DrawListInst
	end

	if g.LogWindow == window then
		ImGui.LogFinish()
	end

	if window.DC.IsSetPos then
		ImGui.ErrorCheckUsingSetCursorPosToExtendParentBoundaries()
	end

	g.LastItemData = window_stack_data.ParentLastItemDataBackup
	if btest(window.Flags, ImGuiWindowFlags.ChildMenu) then
		g.BeginMenuDepth -= 1
	end
	if btest(window.Flags, ImGuiWindowFlags.Popup) then
		g.BeginPopupStack:pop_back()
	end

	if g.IO.ConfigErrorRecovery then
		ImGui.ErrorRecoveryTryToRecoverWindowState(window_stack_data.StackSizesInBegin)
	end

	g.CurrentWindowStack:pop_back()
	if g.CurrentWindowStack.Size == 0 then
		ImGui.SetCurrentWindow(nil)
	else
		ImGui.SetCurrentWindow(g.CurrentWindowStack:back().Window)
	end
end

function ImGui.PushItemFlag(option, enabled)
	local g = ImGui.GImGui
	local item_flags = g.CurrentItemFlags
	assert(item_flags == g.ItemFlagsStack:back())
	if enabled then
		item_flags = bor(item_flags, option)
	else
		item_flags = band(item_flags, bnot(option))
	end
	g.CurrentItemFlags = item_flags
	g.ItemFlagsStack:push_back(item_flags)
end

function ImGui.PopItemFlag()
	local g = ImGui.GImGui
	if not (g.ItemFlagsStack.Size > 1) then
		IM_ASSERT_USER_ERROR(false, "Calling PopItemFlag() too many times!")
		return
	end
	g.ItemFlagsStack:pop_back()
	g.CurrentItemFlags = g.ItemFlagsStack:back()
end

function ImGui.BeginDisabled(disabled)
	if disabled == nil then disabled = true end
	local g = ImGui.GImGui
	local was_disabled = band(g.CurrentItemFlags, ImGuiItemFlags.Disabled) ~= 0
	if not was_disabled and disabled then
		g.DisabledAlphaBackup = g.Style.Alpha
		g.Style.Alpha *= g.Style.DisabledAlpha
	end
	if was_disabled or disabled then
		g.CurrentItemFlags = bor(g.CurrentItemFlags, ImGuiItemFlags.Disabled)
	end
	g.ItemFlagsStack:push_back(g.CurrentItemFlags)
	g.DisabledStackSize += 1
end

function ImGui.EndDisabled()
	local g = ImGui.GImGui
	if not (g.DisabledStackSize > 0) then
		IM_ASSERT_USER_ERROR(false, "Calling EndDisabled() too many times!")
		return
	end
	g.DisabledStackSize -= 1
	local was_disabled = band(g.CurrentItemFlags, ImGuiItemFlags.Disabled) ~= 0
	g.ItemFlagsStack:pop_back()
	g.CurrentItemFlags = g.ItemFlagsStack:back()
	if was_disabled and band(g.CurrentItemFlags, ImGuiItemFlags.Disabled) == 0 then
		g.Style.Alpha = g.DisabledAlphaBackup
	end
end

function ImGui.BeginDisabledOverrideReenable()
	local g = ImGui.GImGui
	assert(btest(g.CurrentItemFlags, ImGuiItemFlags.Disabled))
	g.CurrentWindowStack:back().DisabledOverrideReenableAlphaBackup = g.Style.Alpha
	g.Style.Alpha = g.DisabledAlphaBackup
	g.CurrentItemFlags = band(g.CurrentItemFlags, bnot(ImGuiItemFlags.Disabled))
	g.ItemFlagsStack:push_back(g.CurrentItemFlags)
	g.DisabledStackSize += 1
end

function ImGui.EndDisabledOverrideReenable()
	local g = ImGui.GImGui
	assert(g.DisabledStackSize > 0)
	g.DisabledStackSize -= 1
	g.ItemFlagsStack:pop_back()
	g.CurrentItemFlags = g.ItemFlagsStack:back()
	g.Style.Alpha = g.CurrentWindowStack:back().DisabledOverrideReenableAlphaBackup
end

function ImGui.PushTextWrapPos(wrap_local_pos_x)
	if wrap_local_pos_x == nil then wrap_local_pos_x = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	window.DC.TextWrapPosStack:push_back(window.DC.TextWrapPos)
	window.DC.TextWrapPos = wrap_local_pos_x
end

function ImGui.PopTextWrapPos()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if not (window.DC.TextWrapPosStack.Size > 0) then
		IM_ASSERT_USER_ERROR(false, "Calling PopTextWrapPos() too many times!")
		return
	end
	window.DC.TextWrapPos = window.DC.TextWrapPosStack:back()
	window.DC.TextWrapPosStack:pop_back()
end

function ImGui.GetCombinedRootWindow(window, popup_hierarchy)
	local last_window = nil
	while last_window ~= window do
		last_window = window
		window = window.RootWindow
		if popup_hierarchy then
			window = window.RootWindowPopupTree
		end
	end
	return window
end

function ImGui.IsWindowChildOf(window, potential_parent, popup_hierarchy)
	local window_root = ImGui.GetCombinedRootWindow(window, popup_hierarchy)
	if window_root == potential_parent then
		return true
	end
	while window ~= nil do
		if window == potential_parent then
			return true
		end
		if window == window_root then
			return false
		end
		window = window.ParentWindow
	end
	return false
end

function ImGui.IsWindowInBeginStack(window)
	local g = ImGui.GImGui
	for n = g.CurrentWindowStack.Size - 1, 0, -1 do
		if g.CurrentWindowStack[n + 1].Window == window then
			return true
		end
	end
	return false
end

function ImGui.IsWindowWithinBeginStackOf(window, potential_parent)
	if window.RootWindow == potential_parent then
		return true
	end
	while window ~= nil do
		if window == potential_parent then
			return true
		end
		window = window.ParentWindowInBeginStack
	end
	return false
end

function ImGui.IsWindowAbove(potential_above, potential_below)
	local g = ImGui.GImGui

	local display_layer_delta = ImGui.GetWindowDisplayLayer(potential_above) - ImGui.GetWindowDisplayLayer(potential_below)
	if display_layer_delta ~= 0 then
		return display_layer_delta > 0
	end

	for i = g.Windows.Size - 1, 0, -1 do
		local candidate_window = g.Windows[i + 1]
		if candidate_window == potential_above then
			return true
		end
		if candidate_window == potential_below then
			return false
		end
	end
	return false
end

function ImGui.IsWindowHovered(flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	IM_ASSERT_USER_ERROR(band(flags, bnot(ImGuiHoveredFlags.AllowedMaskForIsWindowHovered)) == 0, "Invalid flags for IsWindowHovered()!")

	local ref_window = g.HoveredWindow
	local cur_window = g.CurrentWindow
	if ref_window == nil then
		return false
	end

	if band(flags, ImGuiHoveredFlags.AnyWindow) == 0 then
		assert(cur_window)
		local popup_hierarchy = band(flags, ImGuiHoveredFlags.NoPopupHierarchy) == 0
		if btest(flags, ImGuiHoveredFlags.RootWindow) then
			cur_window = ImGui.GetCombinedRootWindow(cur_window, popup_hierarchy)
		end

		local result
		if btest(flags, ImGuiHoveredFlags.ChildWindows) then
			result = ImGui.IsWindowChildOf(ref_window, cur_window, popup_hierarchy)
		else
			result = (ref_window == cur_window)
		end
		if not result then
			return false
		end
	end

	if not ImGui.IsWindowContentHoverable(ref_window, flags) then
		return false
	end
	if not btest(flags, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
		if g.ActiveId ~= 0 and not g.ActiveIdAllowOverlap and g.ActiveId ~= ref_window.MoveId then
			return false
		end
	end

	if btest(flags, ImGuiHoveredFlags.ForTooltip) then
		flags = ImGui.ApplyHoverFlagsForTooltip(flags, g.Style.HoverFlagsForTooltipMouse)
	end
	if band(flags, ImGuiHoveredFlags.Stationary) ~= 0 and g.HoverWindowUnlockedStationaryId ~= ref_window.ID then
		return false
	end

	return true
end

function ImGui.GetWindowWidth()
	local window = ImGui.GImGui.CurrentWindow
	return window.Size.x
end

function ImGui.GetWindowHeight()
	local window = ImGui.GImGui.CurrentWindow
	return window.Size.y
end

function ImGui.GetWindowPos()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	return window.Pos
end

local function SetWindowPosEx(window, pos, cond)
	if cond == nil then cond = 0 end
	if cond ~= 0 and band(window.SetWindowPosAllowFlags, cond) == 0 then
		return
	end

	assert(cond == 0 or Base.ImIsPowerOfTwo(cond))
	window.SetWindowPosAllowFlags = band(window.SetWindowPosAllowFlags, bnot(bor(ImGuiCond.Once, ImGuiCond.FirstUseEver, ImGuiCond.Appearing)))
	window.SetWindowPosVal = ImVec2(FLT_MAX, FLT_MAX)

	local old_pos = window.Pos
	window.Pos = ImTrunc(pos)
	local offset = window.Pos - old_pos
	if offset.x == 0 and offset.y == 0 then
		return
	end
	ImGui.MarkIniSettingsDirty(window)
	window.DC.CursorPos += offset
	window.DC.CursorMaxPos += offset
	window.DC.IdealMaxPos += offset
	window.DC.CursorStartPos += offset
end

function ImGui.SetWindowPos(a, b, c)
	if type(a) == "vector" then
		SetWindowPosEx(ImGui.GImGui.CurrentWindow, a, b)
	elseif type(a) == "string" then
		local window = ImGui.FindWindowByName(a)
		if window then
			SetWindowPosEx(window, b, c)
		end
	else
		SetWindowPosEx(a, b, c)
	end
end

function ImGui.GetWindowSize()
	local window = ImGui.GImGui.CurrentWindow
	return window.Size
end

local function SetWindowSizeEx(window, size, cond)
	if cond == nil then cond = 0 end
	if cond ~= 0 and band(window.SetWindowSizeAllowFlags, cond) == 0 then
		return
	end

	assert(cond == 0 or Base.ImIsPowerOfTwo(cond))
	window.SetWindowSizeAllowFlags = band(window.SetWindowSizeAllowFlags, bnot(bor(ImGuiCond.Once, ImGuiCond.FirstUseEver, ImGuiCond.Appearing)))

	if band(window.Flags, ImGuiWindowFlags.ChildWindow) == 0 or window.Appearing or band(window.ChildFlags, ImGuiChildFlags.AlwaysAutoResize) ~= 0 then
		window.AutoFitFramesX = (size.x <= 0) and 2 or 0
	end
	if band(window.Flags, ImGuiWindowFlags.ChildWindow) == 0 or window.Appearing or band(window.ChildFlags, ImGuiChildFlags.AlwaysAutoResize) ~= 0 then
		window.AutoFitFramesY = (size.y <= 0) and 2 or 0
	end

	local old_size = window.SizeFull
	if size.x <= 0 then
		window.AutoFitOnlyGrows = false
	else
		window.SizeFull = ImVec2(IM_TRUNC(size.x), window.SizeFull.y)
	end
	if size.y <= 0 then
		window.AutoFitOnlyGrows = false
	else
		window.SizeFull = ImVec2(window.SizeFull.x, IM_TRUNC(size.y))
	end
	if old_size.x ~= window.SizeFull.x or old_size.y ~= window.SizeFull.y then
		ImGui.MarkIniSettingsDirty(window)
	end
end

function ImGui.SetWindowSize(a, b, c)
	if type(a) == "vector" then
		SetWindowSizeEx(ImGui.GImGui.CurrentWindow, a, b)
	elseif type(a) == "string" then
		local window = ImGui.FindWindowByName(a)
		if window then
			SetWindowSizeEx(window, b, c)
		end
	else
		SetWindowSizeEx(a, b, c)
	end
end

local function SetWindowCollapsedEx(window, collapsed, cond)
	if cond == nil then cond = 0 end
	if cond ~= 0 and band(window.SetWindowCollapsedAllowFlags, cond) == 0 then
		return
	end
	window.SetWindowCollapsedAllowFlags = band(window.SetWindowCollapsedAllowFlags, bnot(bor(ImGuiCond.Once, ImGuiCond.FirstUseEver, ImGuiCond.Appearing)))

	if window.WantCollapseToggle then
		window.Collapsed = not window.Collapsed
	end
	window.WantCollapseToggle = (window.Collapsed ~= collapsed)
end

function ImGui.SetWindowCollapsed(a, b, c)
	if type(a) == "boolean" or a == nil then
		SetWindowCollapsedEx(ImGui.GImGui.CurrentWindow, a == true, b)
	elseif type(a) == "string" then
		local window = ImGui.FindWindowByName(a)
		if window then
			SetWindowCollapsedEx(window, b, c)
		end
	else
		SetWindowCollapsedEx(a, b, c)
	end
end

function ImGui.SetWindowHitTestHole(window, pos, size)
	assert(window.HitTestHoleSize.x == 0)
	window.HitTestHoleSize = ImTrunc(size)
	window.HitTestHoleOffset = ImTrunc(pos - window.Pos)
end

function ImGui.SetWindowHiddenAndSkipItemsForCurrentFrame(window)
	window.Hidden = true
	window.SkipItems = true
	window.HiddenFramesCanSkipItems = 1
end

function ImGui.IsWindowCollapsed()
	local window = ImGui.GImGui.CurrentWindow
	return window.Collapsed
end

function ImGui.IsWindowAppearing()
	local window = ImGui.GImGui.CurrentWindow
	return window.Appearing
end

function ImGui.SetNextWindowPos(pos, cond, pivot)
	if cond == nil then cond = 0 end
	if pivot == nil then pivot = ImVec2(0, 0) end
	local g = ImGui.GImGui
	assert(cond == 0 or Base.ImIsPowerOfTwo(cond))
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasPos)
	g.NextWindowData.PosVal = pos
	g.NextWindowData.PosPivotVal = pivot
	g.NextWindowData.PosCond = (cond ~= 0) and cond or ImGuiCond.Always
end

function ImGui.SetNextWindowSize(size, cond)
	if cond == nil then cond = 0 end
	local g = ImGui.GImGui
	assert(cond == 0 or Base.ImIsPowerOfTwo(cond))
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize)
	g.NextWindowData.SizeVal = size
	g.NextWindowData.SizeCond = (cond ~= 0) and cond or ImGuiCond.Always
end

function ImGui.SetNextWindowSizeConstraints(size_min, size_max, custom_callback, custom_callback_user_data)
	local g = ImGui.GImGui
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSizeConstraint)
	g.NextWindowData.SizeConstraintRect = ImRect.new(size_min, size_max)
	g.NextWindowData.SizeCallback = custom_callback
	g.NextWindowData.SizeCallbackUserData = custom_callback_user_data
end

function ImGui.SetNextWindowContentSize(size)
	local g = ImGui.GImGui
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasContentSize)
	g.NextWindowData.ContentSizeVal = ImTrunc(size)
end

function ImGui.SetNextWindowScroll(scroll)
	local g = ImGui.GImGui
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasScroll)
	g.NextWindowData.ScrollVal = scroll
end

function ImGui.SetNextWindowCollapsed(collapsed, cond)
	if cond == nil then cond = 0 end
	local g = ImGui.GImGui
	assert(cond == 0 or Base.ImIsPowerOfTwo(cond))
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasCollapsed)
	g.NextWindowData.CollapsedVal = collapsed
	g.NextWindowData.CollapsedCond = (cond ~= 0) and cond or ImGuiCond.Always
end

function ImGui.SetNextWindowBgAlpha(alpha)
	local g = ImGui.GImGui
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasBgAlpha)
	g.NextWindowData.BgAlphaVal = alpha
end

function ImGui.SetNextWindowRefreshPolicy(flags)
	local g = ImGui.GImGui
	g.NextWindowData.HasFlags = bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasRefreshPolicy)
	g.NextWindowData.RefreshFlagsVal = flags
end

function ImGui.SetNextWindowFlags(flags, enabled)
	local g = ImGui.GImGui
	local nwd = g.NextWindowData
	if band(nwd.HasFlags, ImGuiNextWindowDataFlags.HasWindowFlags) == 0 then
		nwd.WindowFlagsSet = ImGuiChildFlags.None
		nwd.WindowFlagsClear = ImGuiChildFlags.None
	end
	nwd.WindowFlagsSet = enabled and bor(nwd.WindowFlagsSet, flags) or band(nwd.WindowFlagsSet, bnot(flags))
	nwd.WindowFlagsClear = (not enabled) and bor(nwd.WindowFlagsClear, flags) or band(nwd.WindowFlagsClear, bnot(flags))
	nwd.HasFlags = bor(nwd.HasFlags, ImGuiNextWindowDataFlags.HasWindowFlags)
end

function ImGui.SetNextWindowChildFlags(flags, enabled)
	local g = ImGui.GImGui
	local nwd = g.NextWindowData
	if band(nwd.HasFlags, ImGuiNextWindowDataFlags.HasChildFlags) == 0 then
		nwd.ChildFlagsSet = ImGuiChildFlags.None
		nwd.ChildFlagsClear = ImGuiChildFlags.None
	end
	nwd.ChildFlagsSet = enabled and bor(nwd.ChildFlagsSet, flags) or band(nwd.ChildFlagsSet, bnot(flags))
	nwd.ChildFlagsClear = (not enabled) and bor(nwd.ChildFlagsClear, flags) or band(nwd.ChildFlagsClear, bnot(flags))
	nwd.HasFlags = bor(nwd.HasFlags, ImGuiNextWindowDataFlags.HasChildFlags)
end

function ImGui.GetWindowDrawList()
	local window = GetCurrentWindow()
	return window.DrawList
end

function ImGui.GetFont()
	return ImGui.GImGui.Font
end

function ImGui.GetFontBaked()
	return ImGui.GImGui.FontBaked
end

function ImGui.GetFontSize()
	return ImGui.GImGui.FontSize
end

function ImGui.GetFontTexUvWhitePixel()
	return ImGui.GImGui.DrawListSharedData.TexUvWhitePixel
end

function ImGui.PushFocusScope(id)
	local g = ImGui.GImGui
	g.FocusScopeStack:push_back(NewFocusScopeData(id, g.CurrentWindow.ID))
	g.CurrentFocusScopeId = id
end

function ImGui.PopFocusScope()
	local g = ImGui.GImGui
	if not (g.FocusScopeStack.Size > g.StackSizesInBeginForCurrentWindow.SizeOfFocusScopeStack) then
		IM_ASSERT_USER_ERROR(false, "Calling PopFocusScope() too many times!")
		return
	end
	g.FocusScopeStack:pop_back()
	g.CurrentFocusScopeId = (g.FocusScopeStack.Size ~= 0) and g.FocusScopeStack:back().ID or 0
end

function ImGui.IsInNavFocusRoute(focus_scope_id)
	local g = ImGui.GImGui
	if g.NavFocusScopeId == focus_scope_id then
		return true
	end
	local route = g.NavFocusRoute
	for i = 1, route.Size do
		if route[i].ID == focus_scope_id then
			return true
		end
	end
	return false
end

function ImGui.SetNavFocusScope(focus_scope_id)
	local g = ImGui.GImGui
	g.NavFocusScopeId = focus_scope_id
	g.NavFocusRoute:resize(0)
	if focus_scope_id == 0 then
		return
	end
	assert(g.NavWindow ~= nil)

	if focus_scope_id == g.CurrentFocusScopeId then
		local n = g.FocusScopeStack.Size - 1
		while n >= 0 and g.FocusScopeStack[n + 1].WindowID == g.CurrentWindow.ID do
			local src = g.FocusScopeStack[n + 1]
			g.NavFocusRoute:push_back(NewFocusScopeData(src.ID, src.WindowID))
			n -= 1
		end
	elseif focus_scope_id == g.NavWindow.NavRootFocusScopeId then
		g.NavFocusRoute:push_back(NewFocusScopeData(focus_scope_id, g.NavWindow.ID))
	else
		return
	end

	local window = g.NavWindow.ParentWindowForFocusRoute
	while window ~= nil do
		g.NavFocusRoute:push_back(NewFocusScopeData(window.NavRootFocusScopeId, window.ID))
		window = window.ParentWindowForFocusRoute
	end
	assert(g.NavFocusRoute.Size < 100)
end

function ImGui.FocusItem()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
		ImGui.DebugLog("FocusItem(0x%08x) in window \"%s\"\n", g.LastItemData.ID, window.Name)
	end
	if g.DragDropActive or g.MovingWindow ~= nil then
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
			ImGui.DebugLog("FocusItem() ignored while DragDropActive!\n")
		end
		return
	end

	local move_flags = bor(ImGuiNavMoveFlags.IsTabbing, ImGuiNavMoveFlags.FocusApi, ImGuiNavMoveFlags.NoSetNavCursorVisible, ImGuiNavMoveFlags.NoSelect)
	local scroll_flags = window.Appearing and bor(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.AlwaysCenterY) or bor(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.KeepVisibleEdgeY)
	ImGui.SetNavWindow(window)
	ImGui.NavMoveRequestSubmit(ImGuiDir.None, ImGuiDir.Up, move_flags, scroll_flags)
	ImGui.NavMoveRequestResolveWithLastItem(g.NavMoveResultLocal)
end

function ImGui.ActivateItemByID(id)
	local g = ImGui.GImGui
	g.NavNextActivateId = id
	g.NavNextActivateFlags = ImGuiActivateFlags.None
end

function ImGui.SetKeyboardFocusHere(offset)
	if offset == nil then offset = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(offset >= -1)
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
		ImGui.DebugLog("SetKeyboardFocusHere(%d) in window \"%s\"\n", offset, window.Name)
	end

	if g.DragDropActive or g.MovingWindow ~= nil then
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
			ImGui.DebugLog("SetKeyboardFocusHere() ignored while DragDropActive!\n")
		end
		return
	end

	ImGui.SetNavWindow(window)

	local move_flags = bor(ImGuiNavMoveFlags.IsTabbing, ImGuiNavMoveFlags.Activate, ImGuiNavMoveFlags.FocusApi, ImGuiNavMoveFlags.NoSetNavCursorVisible)
	local scroll_flags = window.Appearing and bor(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.AlwaysCenterY) or bor(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.KeepVisibleEdgeY)
	ImGui.NavMoveRequestSubmit(ImGuiDir.None, (offset < 0) and ImGuiDir.Up or ImGuiDir.Down, move_flags, scroll_flags)
	if offset == -1 then
		ImGui.NavMoveRequestResolveWithLastItem(g.NavMoveResultLocal)
	else
		g.NavTabbingDir = 1
		g.NavTabbingCounter = offset + 1
	end
end

function ImGui.SetItemDefaultFocus()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if not window.Appearing then
		return
	end
	if g.NavWindow ~= window.RootWindowForNav or (not g.NavInitRequest and g.NavInitResult.ID == 0) or g.NavLayer ~= window.DC.NavLayerCurrent then
		return
	end

	g.NavInitRequest = false
	ImGui.NavApplyItemToResult(g.NavInitResult)
	ImGui.NavUpdateAnyRequestFlag()

	if not window.ClipRect:Contains(g.LastItemData.Rect) then
		ImGui.ScrollToRectEx(window, g.LastItemData.Rect, ImGuiScrollFlags.None)
	end
end

function ImGui.SetStateStorage(tree)
	local window = ImGui.GImGui.CurrentWindow
	window.DC.StateStorage = tree or window.StateStorage
end

function ImGui.GetStateStorage()
	local window = ImGui.GImGui.CurrentWindow
	return window.DC.StateStorage
end

function ImGui.IsRectVisible(a, b)
	local window = ImGui.GImGui.CurrentWindow
	if b == nil then
		return window.ClipRect:Overlaps(ImRect.new(window.DC.CursorPos, window.DC.CursorPos + a))
	end
	return window.ClipRect:Overlaps(ImRect.new(a, b))
end

return true
