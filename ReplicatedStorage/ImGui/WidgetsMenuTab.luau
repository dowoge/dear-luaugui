--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImVec4, ImRect = Base.ImVec2, Base.ImVec4, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local IM_TRUNC, IM_ROUND = Base.IM_TRUNC, Base.IM_ROUND
local ImTruncToInt = Base.ImTruncToInt
local ImQsort = Base.ImQsort
local ImHashStr = Base.ImHashStr
local ImLinearSweep = Base.ImLinearSweep
local ImTriangleContainsPoint = Base.ImTriangleContainsPoint

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiLayoutType = Enums.ImGuiLayoutType
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiDir = Enums.ImGuiDir
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiAxis = Enums.ImGuiAxis
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiKey = Enums.ImGuiKey
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiCol = Enums.ImGuiCol
local ImGuiCond = Enums.ImGuiCond
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiTabBarFlags = Enums.ImGuiTabBarFlags
local ImGuiTabItemFlags = Enums.ImGuiTabItemFlags
local ImGuiNextItemDataFlags = Enums.ImGuiNextItemDataFlags
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiComboFlags = Enums.ImGuiComboFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImDrawFlags = Enums.ImDrawFlags

local ImGuiMenuColumns = Structs.ImGuiMenuColumns
local ImGuiTabItem = Structs.ImGuiTabItem
local ImGuiShrinkWidthItem = Structs.ImGuiShrinkWidthItem

local btest, band, bor, bnot = bit32.btest, bit32.band, bit32.bor, bit32.bnot

function ImGuiMenuColumns:Update(spacing, window_reappearing)
	if window_reappearing then
		for i = 1, 4 do
			self.Widths[i] = 0
		end
	end
	self.Spacing = ImTruncToInt(spacing)
	self:CalcNextTotalWidth(true)
	for i = 1, 4 do
		self.Widths[i] = 0
	end
	self.TotalWidth = self.NextTotalWidth
	self.NextTotalWidth = 0
end

function ImGuiMenuColumns:CalcNextTotalWidth(update_offsets)
	local offset = 0
	local want_spacing = false
	for i = 0, 3 do
		local width = self.Widths[i + 1]
		if want_spacing and width > 0 then
			offset += self.Spacing
		end
		want_spacing = want_spacing or (width > 0)
		if update_offsets then
			if i == 1 then
				self.OffsetLabel = offset
			end
			if i == 2 then
				self.OffsetShortcut = offset
			end
			if i == 3 then
				self.OffsetMark = offset
			end
		end
		offset += width
	end
	self.NextTotalWidth = offset
end

function ImGuiMenuColumns:DeclColumns(w_icon, w_label, w_shortcut, w_mark)
	local Widths = self.Widths
	Widths[1] = ImMax(Widths[1], ImTruncToInt(w_icon))
	Widths[2] = ImMax(Widths[2], ImTruncToInt(w_label))
	Widths[3] = ImMax(Widths[3], ImTruncToInt(w_shortcut))
	Widths[4] = ImMax(Widths[4], ImTruncToInt(w_mark))
	self:CalcNextTotalWidth(false)
	return ImMax(self.TotalWidth, self.NextTotalWidth)
end

function ImGui.BeginMenuBar()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end
	if not btest(window.Flags, ImGuiWindowFlags.MenuBar) then
		return false
	end

	assert(not window.DC.MenuBarAppending)
	ImGui.BeginGroup()
	ImGui.PushID("##MenuBar")

	local border_top = ImMax(window.WindowBorderSize * 0.5 - window.TitleBarHeight, 0.0)
	local bar_rect = window:MenuBarRect()
	local clip_rect = ImRect.fromXY(
		IM_ROUND(bar_rect.Min.x + window.WindowBorderSize * 0.5),
		IM_ROUND(bar_rect.Min.y + border_top),
		IM_ROUND(ImMax(bar_rect.Min.x, bar_rect.Max.x - ImMax(window.WindowRounding, window.WindowBorderSize * 0.5))),
		IM_ROUND(bar_rect.Max.y)
	)
	clip_rect = clip_rect:ClippedWith(window.OuterRectClipped)
	ImGui.PushClipRect(clip_rect.Min, clip_rect.Max, false)

	local cursor = ImVec2(bar_rect.Min.x + window.DC.MenuBarOffset.x, bar_rect.Min.y + window.DC.MenuBarOffset.y)
	window.DC.CursorPos = cursor
	window.DC.CursorMaxPos = cursor
	window.DC.LayoutType = ImGuiLayoutType.Horizontal
	window.DC.IsSameLine = false
	window.DC.NavLayerCurrent = ImGuiNavLayer.Menu
	window.DC.MenuBarAppending = true
	ImGui.AlignTextToFramePadding()
	return true
end

function ImGui.EndMenuBar()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end
	local g = ImGui.GImGui

	assert(btest(window.Flags, ImGuiWindowFlags.MenuBar))
	assert(window.DC.MenuBarAppending)

	if
		ImGui.NavMoveRequestButNoResultYet()
		and (g.NavMoveDir == ImGuiDir.Left or g.NavMoveDir == ImGuiDir.Right)
		and btest(g.NavWindow.Flags, ImGuiWindowFlags.ChildMenu)
	then
		local nav_earliest_child = g.NavWindow
		while nav_earliest_child.ParentWindow and btest(nav_earliest_child.ParentWindow.Flags, ImGuiWindowFlags.ChildMenu) do
			nav_earliest_child = nav_earliest_child.ParentWindow
		end
		if
			nav_earliest_child.ParentWindow == window
			and nav_earliest_child.DC.ParentLayoutType == ImGuiLayoutType.Horizontal
			and band(g.NavMoveFlags, ImGuiNavMoveFlags.Forwarded) == 0
		then
			local layer = ImGuiNavLayer.Menu
			assert(btest(window.DC.NavLayersActiveMaskNext, bit32.lshift(1, layer)))
			ImGui.FocusWindow(window)
			ImGui.SetNavID(window.NavLastIds[layer + 1], layer, 0, window.NavRectRel[layer + 1])
			if g.NavCursorVisible then
				g.NavCursorVisible = false
				g.NavCursorHideFrames = 2
			end
			g.NavHighlightItemUnderNav = true
			g.NavMousePosDirty = true
			ImGui.NavMoveRequestForward(g.NavMoveDir, g.NavMoveClipDir, g.NavMoveFlags, g.NavMoveScrollFlags)
		end
	else
		ImGui.NavMoveRequestTryWrapping(window, ImGuiNavMoveFlags.WrapX)
	end

	ImGui.PopClipRect()
	ImGui.PopID()
	window.DC.MenuBarOffset = ImVec2(window.DC.CursorPos.x - window.Pos.x, window.DC.MenuBarOffset.y)

	local group_data = g.GroupStack:back()
	group_data.EmitItem = false
	local restore_cursor_max_pos = group_data.BackupCursorMaxPos
	window.DC.IdealMaxPos = ImVec2(ImMax(window.DC.IdealMaxPos.x, window.DC.CursorMaxPos.x - window.Scroll.x), window.DC.IdealMaxPos.y)
	ImGui.EndGroup()
	window.DC.LayoutType = ImGuiLayoutType.Vertical
	window.DC.IsSameLine = false
	window.DC.NavLayerCurrent = ImGuiNavLayer.Main
	window.DC.MenuBarAppending = false
	window.DC.CursorMaxPos = restore_cursor_max_pos
end

local function GetAxis(v, axis)
	if axis == ImGuiAxis.X then
		return v.x
	end
	return v.y
end

local function WithAxis(v, axis, val)
	if axis == ImGuiAxis.X then
		return ImVec2(val, v.y)
	end
	return ImVec2(v.x, val)
end

function ImGui.BeginViewportSideBar(name, viewport_p, dir, axis_size, window_flags)
	assert(dir ~= ImGuiDir.None)

	local bar_window = ImGui.FindWindowByName(name)
	if bar_window == nil or bar_window.BeginCount == 0 then
		local viewport = viewport_p or ImGui.GetMainViewport()
		local avail_rect = viewport:GetBuildWorkRect()
		local axis = (dir == ImGuiDir.Up or dir == ImGuiDir.Down) and ImGuiAxis.Y or ImGuiAxis.X
		local pos = avail_rect.Min
		if dir == ImGuiDir.Right or dir == ImGuiDir.Down then
			pos = WithAxis(pos, axis, GetAxis(avail_rect.Max, axis) - axis_size)
		end
		local size = avail_rect:GetSize()
		size = WithAxis(size, axis, axis_size)
		ImGui.SetNextWindowPos(pos)
		ImGui.SetNextWindowSize(size)

		if dir == ImGuiDir.Up or dir == ImGuiDir.Left then
			viewport.BuildWorkInsetMin = WithAxis(viewport.BuildWorkInsetMin, axis, GetAxis(viewport.BuildWorkInsetMin, axis) + axis_size)
		elseif dir == ImGuiDir.Down or dir == ImGuiDir.Right then
			viewport.BuildWorkInsetMax = WithAxis(viewport.BuildWorkInsetMax, axis, GetAxis(viewport.BuildWorkInsetMax, axis) + axis_size)
		end
	end

	window_flags = bor(window_flags, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove)
	ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
	ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, ImVec2(0, 0))
	local is_open = ImGui.Begin(name, nil, window_flags)
	ImGui.PopStyleVar(2)

	return is_open
end

function ImGui.BeginMainMenuBar()
	local g = ImGui.GImGui
	local viewport = ImGui.GetMainViewport()

	g.NextWindowData.MenuBarOffsetMinVal = ImVec2(g.Style.DisplaySafeAreaPadding.x, ImMax(g.Style.DisplaySafeAreaPadding.y - g.Style.FramePadding.y, 0.0))
	local window_flags = bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.MenuBar)
	local height = ImGui.GetFrameHeight()
	local is_open = ImGui.BeginViewportSideBar("##MainMenuBar", viewport, ImGuiDir.Up, height, window_flags)
	g.NextWindowData.MenuBarOffsetMinVal = ImVec2(0.0, 0.0)
	if not is_open then
		ImGui.End()
		return false
	end

	g.CurrentWindow.Flags = band(g.CurrentWindow.Flags, bnot(ImGuiWindowFlags.NoSavedSettings))
	ImGui.BeginMenuBar()
	return is_open
end

function ImGui.EndMainMenuBar()
	local g = ImGui.GImGui
	if not g.CurrentWindow.DC.MenuBarAppending then
		local msg = "Calling EndMainMenuBar() not from a menu-bar!"
		if ImGui.ErrorLog(msg) then
			assert(g.CurrentWindow.DC.MenuBarAppending, msg)
		end
		return
	end

	ImGui.EndMenuBar()
	g.CurrentWindow.Flags = bor(g.CurrentWindow.Flags, ImGuiWindowFlags.NoSavedSettings)

	if g.CurrentWindow == g.NavWindow and g.NavLayer == ImGuiNavLayer.Main and not g.NavAnyRequest and g.ActiveId == 0 then
		ImGui.FocusTopMostWindowUnderOne(
			g.NavWindow,
			nil,
			nil,
			bor(ImGuiFocusRequestFlags.UnlessBelowModal, ImGuiFocusRequestFlags.RestoreFocusedChild)
		)
	end

	ImGui.End()
end

function ImGui.IsRootOfOpenMenuSet()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if (g.OpenPopupStack.Size <= g.BeginPopupStack.Size) or btest(window.Flags, ImGuiWindowFlags.ChildMenu) then
		return false
	end

	local upper_popup = g.OpenPopupStack[g.BeginPopupStack.Size + 1]
	if window.DC.NavLayerCurrent ~= upper_popup.ParentNavLayer then
		return false
	end
	return upper_popup.Window ~= nil
		and btest(upper_popup.Window.Flags, ImGuiWindowFlags.ChildMenu)
		and ImGui.IsWindowChildOf(upper_popup.Window, window, true)
end

function ImGui.BeginMenuEx(label, icon, enabled)
	if enabled == nil then
		enabled = true
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)
	local menu_is_open = ImGui.IsPopupOpen(id, ImGuiPopupFlags.None)

	local window_flags = bor(
		ImGuiWindowFlags.ChildMenu,
		ImGuiWindowFlags.AlwaysAutoResize,
		ImGuiWindowFlags.NoMove,
		ImGuiWindowFlags.NoTitleBar,
		ImGuiWindowFlags.NoSavedSettings,
		ImGuiWindowFlags.NoNavFocus
	)
	if btest(window.Flags, ImGuiWindowFlags.ChildMenu) then
		window_flags = bor(window_flags, ImGuiWindowFlags.ChildWindow)
	end

	if g.MenusIdSubmittedThisFrame:contains(id) then
		if menu_is_open then
			menu_is_open = ImGui.BeginPopupMenuEx(id, label, window_flags)
		else
			g.NextWindowData:ClearFlags()
		end
		return menu_is_open
	end

	g.MenusIdSubmittedThisFrame:push_back(id)

	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local menuset_is_open = ImGui.IsRootOfOpenMenuSet()
	if menuset_is_open then
		g.NextItemData.ItemFlagsSet = bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.NoWindowHoverableCheck)
	end

	local popup_pos
	local pos = window.DC.CursorPos
	ImGui.PushID(label)
	if not enabled then
		ImGui.BeginDisabled()
	end

	local pressed

	local backup_rounding = style.SelectableRounding
	style.SelectableRounding = style.MenuItemRounding
	local selectable_flags = bor(ImGuiSelectableFlags.NoAutoClosePopups, ImGuiSelectableFlags.SelectOnClick)
	local offsets = window.DC.MenuColumns
	if window.DC.LayoutType == ImGuiLayoutType.Horizontal then
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * 0.5), window.DC.CursorPos.y)
		ImGui.PushStyleVarX(ImGuiStyleVar.ItemSpacing, style.ItemSpacing.x * 2.0)
		local text_pos = ImVec2(window.DC.CursorPos.x + offsets.OffsetLabel, pos.y + window.DC.CurrLineTextBaseOffset)
		pressed = ImGui.Selectable("", menu_is_open, selectable_flags, label_size)
		ImGui.LogSetNextTextDecoration("[", "]")
		ImGui.RenderText(text_pos, label, label_end, false)
		ImGui.PopStyleVar()
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * (-1.0 + 0.5)), window.DC.CursorPos.y)
		popup_pos = ImVec2(pos.x - 1.0 - IM_TRUNC(style.ItemSpacing.x * 0.5), text_pos.y - style.FramePadding.y + window.MenuBarHeight)
	else
		local icon_w = (icon ~= nil and icon ~= "") and ImGui.CalcTextSize(icon, nil).x or 0.0
		local checkmark_w = IM_TRUNC(g.FontSize * 1.20)
		local min_w = offsets:DeclColumns(icon_w, label_size.x, 0.0, checkmark_w)
		local extra_w = ImMax(0.0, ImGui.GetContentRegionAvail().x - min_w)
		local text_pos = ImVec2(window.DC.CursorPos.x, pos.y + window.DC.CurrLineTextBaseOffset)
		pressed = ImGui.Selectable("", menu_is_open, bor(selectable_flags, ImGuiSelectableFlags.SpanAvailWidth), ImVec2(min_w, label_size.y))
		ImGui.LogSetNextTextDecoration("", ">")
		ImGui.RenderText(ImVec2(text_pos.x + offsets.OffsetLabel, text_pos.y), label, label_end, false)
		if icon_w > 0.0 then
			ImGui.RenderText(ImVec2(text_pos.x + offsets.OffsetIcon, text_pos.y), icon)
		end
		ImGui.RenderArrow(
			window.DrawList,
			ImVec2(text_pos.x + offsets.OffsetMark + extra_w + g.FontSize * 0.30, text_pos.y),
			ImGui.GetColorU32(ImGuiCol.Text),
			ImGuiDir.Right
		)
		popup_pos = ImVec2(pos.x, text_pos.y - style.WindowPadding.y)
	end
	style.SelectableRounding = backup_rounding
	if not enabled then
		ImGui.EndDisabled()
	end

	if g.ActiveId == id and g.HoveredId ~= id and g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMouseDragging(0) then
		ImGui.ClearActiveID()
		ImGui.SetKeyOwner(ImGuiKey.MouseLeft, ImGuiKeyOwner.NoOwner)
	end

	local hovered = (g.HoveredId == id) and enabled and not g.NavHighlightItemUnderNav

	local want_open = false
	local want_open_nav_init = false
	local want_close = false
	if window.DC.LayoutType == ImGuiLayoutType.Vertical then
		local moving_toward_child_menu = false
		local child_popup = if g.BeginPopupStack.Size < g.OpenPopupStack.Size then g.OpenPopupStack[g.BeginPopupStack.Size + 1] else nil
		local child_menu_window = if child_popup and child_popup.Window and child_popup.Window.ParentWindow == window
			then child_popup.Window
			else nil
		if g.HoveredWindow == window and child_menu_window ~= nil then
			local ref_unit = g.FontSize
			local child_dir = (window.Pos.x < child_menu_window.Pos.x) and 1.0 or -1.0
			local next_window_rect = child_menu_window:Rect()
			local ta = g.IO.MousePos - g.IO.MouseDelta
			local tb = if child_dir > 0.0 then next_window_rect:GetTL() else next_window_rect:GetTR()
			local tc = if child_dir > 0.0 then next_window_rect:GetBL() else next_window_rect:GetBR()
			local pad_farmost_h = ImClamp(math.abs(ta.x - tb.x) * 0.30, ref_unit * 0.5, ref_unit * 2.5)
			ta = ImVec2(ta.x + child_dir * -0.5, ta.y)
			tb = ImVec2(tb.x + child_dir * ref_unit, tb.y)
			tc = ImVec2(tc.x + child_dir * ref_unit, tc.y)
			tb = ImVec2(tb.x, ta.y + ImMax((tb.y - pad_farmost_h) - ta.y, -ref_unit * 8.0))
			tc = ImVec2(tc.x, ta.y + ImMin((tc.y + pad_farmost_h) - ta.y, ref_unit * 8.0))
			moving_toward_child_menu = ImTriangleContainsPoint(ta, tb, tc, g.IO.MousePos)
		end

		if menu_is_open and not hovered and g.HoveredWindow == window and not moving_toward_child_menu and not g.NavHighlightItemUnderNav and g.ActiveId == 0 then
			want_close = true
		end

		if not menu_is_open and pressed then
			want_open = true
		elseif not menu_is_open and hovered and not moving_toward_child_menu then
			want_open = true
		elseif not menu_is_open and hovered and g.HoveredIdTimer >= 0.30 and g.MouseStationaryTimer >= 0.30 then
			want_open = true
		end
		if g.NavId == id and g.NavMoveDir == ImGuiDir.Right then
			want_open = true
			want_open_nav_init = true
			ImGui.NavMoveRequestCancel()
			ImGui.SetNavCursorVisibleAfterMove()
		end
	else
		if menu_is_open and pressed and menuset_is_open then
			want_close = true
			want_open = false
			menu_is_open = false
		elseif pressed or (hovered and menuset_is_open and not menu_is_open) then
			want_open = true
		elseif g.NavId == id and g.NavMoveDir == ImGuiDir.Down then
			want_open = true
			ImGui.NavMoveRequestCancel()
		end
	end

	if not enabled then
		want_close = true
	end
	if want_close and ImGui.IsPopupOpen(id, ImGuiPopupFlags.None) then
		ImGui.ClosePopupToLevel(g.BeginPopupStack.Size, true)
	end

	ImGui.PopID()

	if g.ActiveId == id and want_open then
		g.ActiveIdNoClearOnFocusLoss = true
	end

	if want_open and not menu_is_open and g.OpenPopupStack.Size > g.BeginPopupStack.Size then
		ImGui.OpenPopup(label)
	elseif want_open then
		menu_is_open = true
		ImGui.OpenPopup(label, ImGuiPopupFlags.NoReopen)
	end

	if menu_is_open then
		local last_item_in_parent = g.LastItemData:Copy()
		ImGui.SetNextWindowPos(popup_pos, ImGuiCond.Always)
		ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, style.PopupRounding)
		menu_is_open = ImGui.BeginPopupMenuEx(id, label, window_flags)
		ImGui.PopStyleVar()
		if menu_is_open then
			if want_open and want_open_nav_init and not g.NavInitRequest then
				ImGui.FocusWindow(g.CurrentWindow, ImGuiFocusRequestFlags.UnlessBelowModal)
				ImGui.NavInitWindow(g.CurrentWindow, false)
			end

			g.LastItemData = last_item_in_parent
			if g.HoveredWindow == window then
				g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
			end
		end
	else
		g.NextWindowData:ClearFlags()
	end

	return menu_is_open
end

function ImGui.BeginMenu(label, enabled)
	if enabled == nil then
		enabled = true
	end
	return ImGui.BeginMenuEx(label, nil, enabled)
end

function ImGui.EndMenu()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local both = bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.ChildMenu)
	if band(window.Flags, both) ~= both then
		local msg = "Calling EndMenu() in wrong window!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return
	end

	local parent_window = window.ParentWindow
	if window.BeginCount == window.BeginCountPreviousFrame then
		if g.NavMoveDir == ImGuiDir.Left and ImGui.NavMoveRequestButNoResultYet() then
			if g.NavWindow and (g.NavWindow.RootWindowForNav == window) and parent_window.DC.LayoutType == ImGuiLayoutType.Vertical then
				ImGui.ClosePopupToLevel(g.BeginPopupStack.Size - 1, true)
				ImGui.NavMoveRequestCancel()
			end
		end
	end

	ImGui.EndPopup()
end

function ImGui.MenuItemEx(label, icon, shortcut, selected, enabled)
	if selected == nil then
		selected = false
	end
	if enabled == nil then
		enabled = true
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local style = g.Style
	local pos = window.DC.CursorPos
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local menuset_is_open = ImGui.IsRootOfOpenMenuSet()
	if menuset_is_open then
		g.NextItemData.ItemFlagsSet = bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.NoWindowHoverableCheck)
	end

	local pressed
	ImGui.PushID(label)
	if not enabled then
		ImGui.BeginDisabled()
	end

	local backup_rounding = style.SelectableRounding
	style.SelectableRounding = style.MenuItemRounding
	local selectable_flags = bor(ImGuiSelectableFlags.SelectOnRelease, ImGuiSelectableFlags.SetNavIdOnHover)
	local offsets = window.DC.MenuColumns
	if window.DC.LayoutType == ImGuiLayoutType.Horizontal then
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * 0.5), window.DC.CursorPos.y)
		local text_pos = ImVec2(window.DC.CursorPos.x + offsets.OffsetLabel, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)
		ImGui.PushStyleVarX(ImGuiStyleVar.ItemSpacing, style.ItemSpacing.x * 2.0)
		pressed = ImGui.Selectable("", selected, selectable_flags, ImVec2(label_size.x, 0.0))
		ImGui.PopStyleVar()
		if btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) then
			ImGui.RenderText(text_pos, label, label_end, false)
		end
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * (-1.0 + 0.5)), window.DC.CursorPos.y)
	else
		local icon_w = (icon ~= nil and icon ~= "") and ImGui.CalcTextSize(icon, nil).x or 0.0
		local shortcut_w = (shortcut ~= nil and shortcut ~= "") and ImGui.CalcTextSize(shortcut, nil).x or 0.0
		local checkmark_w = IM_TRUNC(g.FontSize * 1.20)
		local min_w = offsets:DeclColumns(icon_w, label_size.x, shortcut_w, checkmark_w)
		local stretch_w = ImMax(0.0, ImGui.GetContentRegionAvail().x - min_w)
		local text_pos = ImVec2(pos.x, pos.y + window.DC.CurrLineTextBaseOffset)
		pressed = ImGui.Selectable("", false, bor(selectable_flags, ImGuiSelectableFlags.SpanAvailWidth), ImVec2(min_w, label_size.y))
		if btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) then
			ImGui.RenderText(text_pos + ImVec2(offsets.OffsetLabel, 0.0), label, label_end, false)
			if icon_w > 0.0 then
				ImGui.RenderText(text_pos + ImVec2(offsets.OffsetIcon, 0.0), icon)
			end
			if shortcut_w > 0.0 then
				ImGui.PushStyleColor(ImGuiCol.Text, style.Colors[ImGuiCol.TextDisabled + 1])
				ImGui.LogSetNextTextDecoration("(", ")")
				ImGui.RenderText(text_pos + ImVec2(offsets.OffsetShortcut + stretch_w, 0.0), shortcut, nil, false)
				ImGui.PopStyleColor()
			end
			if selected then
				ImGui.RenderCheckMark(
					window.DrawList,
					text_pos + ImVec2(offsets.OffsetMark + stretch_w + g.FontSize * 0.40, g.FontSize * 0.134 * 0.5),
					ImGui.GetColorU32(ImGuiCol.Text),
					g.FontSize * 0.866
				)
			end
		end
	end
	style.SelectableRounding = backup_rounding

	local id = g.LastItemData.ID
	if g.ActiveId == id and g.HoveredId ~= id and g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMouseDragging(0) then
		ImGui.ClearActiveID()
		ImGui.SetKeyOwner(ImGuiKey.MouseLeft, ImGuiKeyOwner.NoOwner)
	end

	if not enabled then
		ImGui.EndDisabled()
	end
	ImGui.PopID()

	return pressed
end

function ImGui.MenuItem(label, shortcut, selected, enabled)
	if enabled == nil then
		enabled = true
	end
	if ImGui.MenuItemEx(label, nil, shortcut, selected or false, enabled) then
		if selected ~= nil then
			selected = not selected
		end
		return true, selected
	end
	return false, selected
end

local function TabItemGetSectionIdx(tab)
	if btest(tab.Flags, ImGuiTabItemFlags.Leading) then
		return 0
	elseif btest(tab.Flags, ImGuiTabItemFlags.Trailing) then
		return 2
	end
	return 1
end

function ImGui.TabItemComparerBySection(a, b)
	local a_section = TabItemGetSectionIdx(a)
	local b_section = TabItemGetSectionIdx(b)
	if a_section ~= b_section then
		return a_section - b_section
	end
	return a.IndexDuringLayout - b.IndexDuringLayout
end

function ImGui.TabItemComparerByBeginOrder(a, b)
	return a.BeginOrder - b.BeginOrder
end

function ImGui.GetTabBarFromTabBarRef(ref)
	local g = ImGui.GImGui
	if ref.Ptr then
		return ref.Ptr
	end
	return g.TabBars:GetByIndex(ref.Index)
end

function ImGui.GetTabBarRefFromTabBar(tab_bar)
	local g = ImGui.GImGui
	if g.TabBars:Contains(tab_bar) then
		return { Ptr = nil, Index = g.TabBars:GetIndex(tab_bar) }
	end
	return { Ptr = tab_bar, Index = -1 }
end

function ImGui.TabBarFindByID(id)
	local g = ImGui.GImGui
	return g.TabBars:GetByKey(id)
end

function ImGui.TabBarRemove(tab_bar)
	local g = ImGui.GImGui
	g.TabBars:Remove(tab_bar.ID, tab_bar)
end

function ImGui.BeginTabBar(str_id, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false
	end

	local id = window:GetID(str_id)
	local tab_bar = g.TabBars:GetOrAddByKey(id)
	local tab_bar_bb = ImRect.fromXY(
		window.DC.CursorPos.x,
		window.DC.CursorPos.y,
		window.WorkRect.Max.x,
		window.DC.CursorPos.y + g.FontSize + g.Style.FramePadding.y * 2
	)
	tab_bar.ID = id
	tab_bar.SeparatorMinX = tab_bar_bb.Min.x - IM_TRUNC(window.WindowPadding.x * 0.5)
	tab_bar.SeparatorMaxX = tab_bar_bb.Max.x + IM_TRUNC(window.WindowPadding.x * 0.5)
	flags = bor(flags, ImGuiTabBarFlags.IsFocused)
	return ImGui.BeginTabBarEx(tab_bar, tab_bar_bb, flags)
end

function ImGui.BeginTabBarEx(tab_bar, tab_bar_bb, flags)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false
	end

	assert(tab_bar.ID ~= 0)
	if band(flags, ImGuiTabBarFlags.DockNode) == 0 then
		ImGui.PushOverrideID(tab_bar.ID)
	end

	g.CurrentTabBarStack:push_back(ImGui.GetTabBarRefFromTabBar(tab_bar))
	g.CurrentTabBar = tab_bar
	tab_bar.Window = window

	tab_bar.BackupCursorPos = window.DC.CursorPos
	if tab_bar.CurrFrameVisible == g.FrameCount then
		window.DC.CursorPos = ImVec2(tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.y + tab_bar.ItemSpacingY)
		tab_bar.BeginCount += 1
		return true
	end

	if
		band(flags, ImGuiTabBarFlags.Reorderable) ~= band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable)
		or (tab_bar.TabsAddedNew and not btest(flags, ImGuiTabBarFlags.Reorderable))
	then
		ImQsort(tab_bar.Tabs, tab_bar.Tabs.Size, ImGui.TabItemComparerByBeginOrder)
	end
	tab_bar.TabsAddedNew = false

	if band(flags, ImGuiTabBarFlags.FittingPolicyMask_) == 0 then
		flags = bor(flags, ImGuiTabBarFlags.FittingPolicyDefault_)
	end

	tab_bar.Flags = flags
	tab_bar.BarRect = tab_bar_bb
	tab_bar.WantLayout = true
	tab_bar.PrevFrameVisible = tab_bar.CurrFrameVisible
	tab_bar.CurrFrameVisible = g.FrameCount
	tab_bar.PrevTabsContentsHeight = tab_bar.CurrTabsContentsHeight
	tab_bar.CurrTabsContentsHeight = 0.0
	tab_bar.ItemSpacingY = g.Style.ItemSpacing.y
	tab_bar.FramePadding = g.Style.FramePadding
	tab_bar.TabsActiveCount = 0
	tab_bar.LastTabItemIdx = -1
	tab_bar.BeginCount = 1

	window.DC.CursorPos = ImVec2(tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.y + tab_bar.ItemSpacingY)

	local col = ImGui.GetColorU32(if btest(flags, ImGuiTabBarFlags.IsFocused) then ImGuiCol.TabSelected else ImGuiCol.TabDimmedSelected)
	if g.Style.TabBarBorderSize > 0.0 then
		local y = tab_bar.BarRect.Max.y
		window.DrawList:AddRectFilled(ImVec2(tab_bar.SeparatorMinX, y - g.Style.TabBarBorderSize), ImVec2(tab_bar.SeparatorMaxX, y), col)
	end
	return true
end

function ImGui.EndTabBar()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	local tab_bar = g.CurrentTabBar
	if tab_bar == nil then
		local msg = "Mismatched BeginTabBar()/EndTabBar()!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return
	end

	if tab_bar.WantLayout then
		ImGui.TabBarLayout(tab_bar)
	end

	local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
	if tab_bar.VisibleTabWasSubmitted or tab_bar.VisibleTabId == 0 or tab_bar_appearing then
		tab_bar.CurrTabsContentsHeight = ImMax(window.DC.CursorPos.y - tab_bar.BarRect.Max.y, tab_bar.CurrTabsContentsHeight)
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, tab_bar.BarRect.Max.y + tab_bar.CurrTabsContentsHeight)
	else
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, tab_bar.BarRect.Max.y + tab_bar.PrevTabsContentsHeight)
	end
	if tab_bar.BeginCount > 1 then
		window.DC.CursorPos = tab_bar.BackupCursorPos
	end

	tab_bar.LastTabItemIdx = -1
	if band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) == 0 then
		ImGui.PopID()
	end

	g.CurrentTabBarStack:pop_back()
	g.CurrentTabBar = if g.CurrentTabBarStack:empty() then nil else ImGui.GetTabBarFromTabBarRef(g.CurrentTabBarStack:back())
end

function ImGui.TabBarCalcScrollableWidth(tab_bar, sections)
	return tab_bar.BarRect:GetWidth() - sections[1].Width - sections[3].Width - sections[2].Spacing
end

function ImGui.TabBarLayout(tab_bar)
	local g = ImGui.GImGui
	tab_bar.WantLayout = false

	local scroll_to_selected_tab = (tab_bar.BarRectPrevWidth > tab_bar.BarRect:GetWidth())
	tab_bar.BarRectPrevWidth = tab_bar.BarRect:GetWidth()

	local tabs = tab_bar.Tabs
	local tab_dst_n = 0
	local need_sort_by_section = false
	local sections = {}
	for i = 1, 3 do
		sections[i] = { TabCount = 0, Width = 0.0, WidthAfterShrinkMinWidth = 0.0, Spacing = 0.0 }
	end
	for tab_src_n = 0, tabs.Size - 1 do
		local tab = tabs[tab_src_n + 1]
		if tab.LastFrameVisible < tab_bar.PrevFrameVisible or tab.WantClose then
			if tab_bar.VisibleTabId == tab.ID then
				tab_bar.VisibleTabId = 0
			end
			if tab_bar.SelectedTabId == tab.ID then
				tab_bar.SelectedTabId = 0
			end
			if tab_bar.NextSelectedTabId == tab.ID then
				tab_bar.NextSelectedTabId = 0
			end
			continue
		end
		if tab_dst_n ~= tab_src_n then
			tabs[tab_dst_n + 1] = tabs[tab_src_n + 1]
		end

		tab = tabs[tab_dst_n + 1]
		tab.IndexDuringLayout = tab_dst_n

		local curr_tab_section_n = TabItemGetSectionIdx(tab)
		if tab_dst_n > 0 then
			local prev_tab = tabs[tab_dst_n]
			local prev_tab_section_n = TabItemGetSectionIdx(prev_tab)
			if curr_tab_section_n == 0 and prev_tab_section_n ~= 0 then
				need_sort_by_section = true
			end
			if prev_tab_section_n == 2 and curr_tab_section_n ~= 2 then
				need_sort_by_section = true
			end
		end

		sections[curr_tab_section_n + 1].TabCount += 1
		tab_dst_n += 1
	end
	if tabs.Size ~= tab_dst_n then
		tabs:resize(tab_dst_n)
	end

	if need_sort_by_section then
		ImQsort(tabs, tabs.Size, ImGui.TabItemComparerBySection)
	end

	local tab_spacing = g.Style.ItemInnerSpacing.x
	sections[1].Spacing = if sections[1].TabCount > 0 and (sections[2].TabCount + sections[3].TabCount) > 0 then tab_spacing else 0.0
	sections[2].Spacing = if sections[2].TabCount > 0 and sections[3].TabCount > 0 then tab_spacing else 0.0

	local scroll_to_tab_id = 0
	if tab_bar.NextScrollToTabId ~= 0 then
		scroll_to_tab_id = tab_bar.NextScrollToTabId
		tab_bar.NextScrollToTabId = 0
	end
	if tab_bar.NextSelectedTabId ~= 0 then
		tab_bar.SelectedTabId = tab_bar.NextSelectedTabId
		tab_bar.NextSelectedTabId = 0
		scroll_to_tab_id = tab_bar.SelectedTabId
	end

	if tab_bar.ReorderRequestTabId ~= 0 then
		if ImGui.TabBarProcessReorder(tab_bar) then
			if tab_bar.ReorderRequestTabId == tab_bar.SelectedTabId then
				scroll_to_tab_id = tab_bar.ReorderRequestTabId
			end
		end
		tab_bar.ReorderRequestTabId = 0
	end

	local tab_list_popup_button = band(tab_bar.Flags, ImGuiTabBarFlags.TabListPopupButton) ~= 0
	if tab_list_popup_button then
		local tab_to_select = ImGui.TabBarTabListPopupButton(tab_bar)
		if tab_to_select then
			tab_bar.SelectedTabId = tab_to_select.ID
			scroll_to_tab_id = tab_to_select.ID
		end
	end

	local shrink_buffer_indexes = { 0, sections[1].TabCount + sections[3].TabCount, sections[1].TabCount }
	local shrink_buffer = g.ShrinkWidthBuffer
	shrink_buffer:resize(tabs.Size)
	for i = 1, shrink_buffer.Size do
		if shrink_buffer[i] == nil then
			shrink_buffer[i] = ImGuiShrinkWidthItem.new()
		end
	end

	local shrink_min_width = if btest(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) then g.Style.TabMinWidthShrink else 1.0

	local most_recently_selected_tab = nil
	local curr_section_n = -1
	local found_selected_tab_id = false
	for tab_n = 0, tabs.Size - 1 do
		local tab = tabs[tab_n + 1]
		assert(tab.LastFrameVisible >= tab_bar.PrevFrameVisible)

		if
			(most_recently_selected_tab == nil or most_recently_selected_tab.LastFrameSelected < tab.LastFrameSelected)
			and not btest(tab.Flags, ImGuiTabItemFlags.Button)
		then
			most_recently_selected_tab = tab
		end
		if tab.ID == tab_bar.SelectedTabId then
			found_selected_tab_id = true
		end
		if scroll_to_tab_id == 0 and g.NavJustMovedToId == tab.ID then
			scroll_to_tab_id = tab.ID
		end

		local tab_name = ImGui.TabBarGetTabName(tab_bar, tab)
		local has_close_button_or_unsaved_marker = band(tab.Flags, ImGuiTabItemFlags.NoCloseButton) == 0
			or btest(tab.Flags, ImGuiTabItemFlags.UnsavedDocument)
		tab.ContentWidth = if tab.RequestedWidth >= 0.0
			then tab.RequestedWidth
			else ImGui.TabItemCalcSize(tab_name, has_close_button_or_unsaved_marker).x
		if band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
			tab.ContentWidth = ImMax(tab.ContentWidth, g.Style.TabMinWidthBase)
		end

		local section_n = TabItemGetSectionIdx(tab)
		local section = sections[section_n + 1]
		section.Width += tab.ContentWidth + (if section_n == curr_section_n then tab_spacing else 0.0)
		section.WidthAfterShrinkMinWidth += ImMin(tab.ContentWidth, shrink_min_width) + (if section_n == curr_section_n then tab_spacing else 0.0)
		curr_section_n = section_n

		local shrink_width_item = shrink_buffer[shrink_buffer_indexes[section_n + 1] + 1]
		shrink_buffer_indexes[section_n + 1] += 1
		shrink_width_item.Index = tab_n
		shrink_width_item.Width = tab.ContentWidth
		shrink_width_item.InitialWidth = tab.ContentWidth
		tab.Width = ImMax(tab.ContentWidth, 1.0)
	end

	local width_all_tabs_after_min_width_shrink = 0.0
	tab_bar.WidthAllTabsIdeal = 0.0
	for section_n = 1, 3 do
		tab_bar.WidthAllTabsIdeal += sections[section_n].Width + sections[section_n].Spacing
		width_all_tabs_after_min_width_shrink += sections[section_n].WidthAfterShrinkMinWidth + sections[section_n].Spacing
	end

	local can_scroll = btest(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyScroll) or btest(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed)
	local width_all_tabs_to_use_for_scroll = if btest(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyScroll)
		then tab_bar.WidthAllTabs
		else width_all_tabs_after_min_width_shrink
	tab_bar.ScrollButtonEnabled = (width_all_tabs_to_use_for_scroll > tab_bar.BarRect:GetWidth() and tabs.Size > 1)
		and not btest(tab_bar.Flags, ImGuiTabBarFlags.NoTabListScrollingButtons)
		and can_scroll
	if tab_bar.ScrollButtonEnabled then
		local scroll_and_select_tab = ImGui.TabBarScrollingButtons(tab_bar)
		if scroll_and_select_tab then
			if band(scroll_and_select_tab.Flags, ImGuiTabItemFlags.Button) == 0 then
				tab_bar.SelectedTabId = scroll_and_select_tab.ID
			end
			scroll_to_tab_id = scroll_and_select_tab.ID
		end
	end
	if scroll_to_tab_id == 0 and scroll_to_selected_tab then
		scroll_to_tab_id = tab_bar.SelectedTabId
	end

	local section_0_w = sections[1].Width + sections[1].Spacing
	local section_1_w = sections[2].Width + sections[2].Spacing
	local section_2_w = sections[3].Width + sections[3].Spacing
	local central_section_is_visible = (section_0_w + section_2_w) < tab_bar.BarRect:GetWidth()
	local width_excess
	if central_section_is_visible then
		width_excess = ImMax(section_1_w - (tab_bar.BarRect:GetWidth() - section_0_w - section_2_w), 0.0)
	else
		width_excess = (section_0_w + section_2_w) - tab_bar.BarRect:GetWidth()
	end

	local can_shrink = btest(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyShrink) or btest(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed)
	if width_excess >= 1.0 and (can_shrink or not central_section_is_visible) then
		local shrink_data_count = if central_section_is_visible then sections[2].TabCount else sections[1].TabCount + sections[3].TabCount
		local shrink_data_offset = if central_section_is_visible then sections[1].TabCount + sections[3].TabCount else 0
		local shrink_items = table.create(shrink_data_count)
		for i = 1, shrink_data_count do
			shrink_items[i] = shrink_buffer[shrink_data_offset + i]
		end
		ImGui.ShrinkWidths(shrink_items, shrink_data_count, width_excess, shrink_min_width)

		for i = 1, shrink_data_count do
			local tab = tabs[shrink_items[i].Index + 1]
			local shrinked_width = IM_TRUNC(shrink_items[i].Width)
			if shrinked_width < 0.0 then
				continue
			end

			shrinked_width = ImMax(1.0, shrinked_width)
			local section_n = TabItemGetSectionIdx(tab)
			sections[section_n + 1].Width -= (tab.Width - shrinked_width)
			tab.Width = shrinked_width
		end
	end

	local section_tab_index = 0
	local tab_offset = 0.0
	tab_bar.WidthAllTabs = 0.0
	for section_n = 0, 2 do
		local section = sections[section_n + 1]
		if section_n == 2 then
			tab_offset = ImMin(ImMax(0.0, tab_bar.BarRect:GetWidth() - section.Width), tab_offset)
		end

		for tab_n = 0, section.TabCount - 1 do
			local tab = tabs[section_tab_index + tab_n + 1]
			tab.Offset = tab_offset
			tab.NameOffset = -1
			tab_offset += tab.Width + (if tab_n < section.TabCount - 1 then g.Style.ItemInnerSpacing.x else 0.0)
		end
		tab_bar.WidthAllTabs += ImMax(section.Width + section.Spacing, 0.0)
		tab_offset += section.Spacing
		section_tab_index += section.TabCount
	end

	tab_bar.TabsNames:clear()

	local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
	if found_selected_tab_id == false and not tab_bar_appearing then
		tab_bar.SelectedTabId = 0
	end
	if tab_bar.SelectedTabId == 0 and tab_bar.NextSelectedTabId == 0 and most_recently_selected_tab ~= nil then
		tab_bar.SelectedTabId = most_recently_selected_tab.ID
		scroll_to_tab_id = tab_bar.SelectedTabId
	end

	tab_bar.VisibleTabId = tab_bar.SelectedTabId
	tab_bar.VisibleTabWasSubmitted = false

	if scroll_to_tab_id ~= 0 then
		ImGui.TabBarScrollToTab(tab_bar, scroll_to_tab_id, sections)
	elseif
		tab_bar.ScrollButtonEnabled
		and ImGui.IsMouseHoveringRect(tab_bar.BarRect.Min, tab_bar.BarRect.Max, true)
		and ImGui.IsWindowContentHoverable(g.CurrentWindow)
	then
		local wheel = if g.IO.MouseWheelRequestAxisSwap then g.IO.MouseWheel else g.IO.MouseWheelH
		local wheel_key = if g.IO.MouseWheelRequestAxisSwap then ImGuiKey.MouseWheelY else ImGuiKey.MouseWheelX
		if ImGui.TestKeyOwner(wheel_key, tab_bar.ID) and wheel ~= 0.0 then
			local scroll_step = wheel * ImGui.TabBarCalcScrollableWidth(tab_bar, sections) / 3.0
			tab_bar.ScrollingTargetDistToVisibility = 0.0
			tab_bar.ScrollingTarget = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingTarget - scroll_step)
		end
		ImGui.SetKeyOwner(wheel_key, tab_bar.ID)
	end

	tab_bar.ScrollingAnim = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingAnim)
	tab_bar.ScrollingTarget = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingTarget)
	if tab_bar.ScrollingAnim ~= tab_bar.ScrollingTarget then
		tab_bar.ScrollingSpeed = ImMax(tab_bar.ScrollingSpeed, 70.0 * g.FontSize)
		tab_bar.ScrollingSpeed = ImMax(tab_bar.ScrollingSpeed, math.abs(tab_bar.ScrollingTarget - tab_bar.ScrollingAnim) / 0.3)
		local teleport = (tab_bar.PrevFrameVisible + 1 < g.FrameCount) or (tab_bar.ScrollingTargetDistToVisibility > 10.0 * g.FontSize)
		tab_bar.ScrollingAnim = if teleport
			then tab_bar.ScrollingTarget
			else ImLinearSweep(tab_bar.ScrollingAnim, tab_bar.ScrollingTarget, g.IO.DeltaTime * tab_bar.ScrollingSpeed)
	else
		tab_bar.ScrollingSpeed = 0.0
	end
	tab_bar.ScrollingRectMinX = tab_bar.BarRect.Min.x + sections[1].Width + sections[1].Spacing
	tab_bar.ScrollingRectMaxX = tab_bar.BarRect.Max.x - sections[3].Width - sections[2].Spacing

	local window = g.CurrentWindow
	window.DC.CursorPos = tab_bar.BarRect.Min
	ImGui.ItemSize(ImVec2(tab_bar.WidthAllTabs, tab_bar.BarRect:GetHeight()), tab_bar.FramePadding.y)
	window.DC.IdealMaxPos = ImVec2(ImMax(window.DC.IdealMaxPos.x, tab_bar.BarRect.Min.x + tab_bar.WidthAllTabsIdeal), window.DC.IdealMaxPos.y)
end

function ImGui.TabBarCalcTabID(tab_bar, label, docked_window)
	assert(docked_window == nil)
	if btest(tab_bar.Flags, ImGuiTabBarFlags.DockNode) then
		local id = ImHashStr(label)
		ImGui.KeepAliveID(id)
		return id
	else
		local window = ImGui.GImGui.CurrentWindow
		return window:GetID(label)
	end
end

function ImGui.TabBarCalcMaxTabWidth()
	local g = ImGui.GImGui
	return g.FontSize * 20.0
end

function ImGui.TabBarFindTabByID(tab_bar, tab_id)
	if tab_id ~= 0 then
		for n = 1, tab_bar.Tabs.Size do
			if tab_bar.Tabs[n].ID == tab_id then
				return tab_bar.Tabs[n]
			end
		end
	end
	return nil
end

function ImGui.TabBarFindTabByOrder(tab_bar, order)
	if order < 0 or order >= tab_bar.Tabs.Size then
		return nil
	end
	return tab_bar.Tabs[order + 1]
end

function ImGui.TabBarGetCurrentTab(tab_bar)
	if tab_bar.LastTabItemIdx < 0 or tab_bar.LastTabItemIdx >= tab_bar.Tabs.Size then
		return nil
	end
	return tab_bar.Tabs[tab_bar.LastTabItemIdx + 1]
end

function ImGui.TabBarGetTabOrder(tab_bar, tab)
	return tab_bar.Tabs:index_from_ptr(tab)
end

function ImGui.TabBarGetTabName(tab_bar, tab)
	if tab.NameOffset == -1 then
		return "N/A"
	end
	assert(tab.NameOffset < tab_bar.TabsNames:size() + 1)
	local buf = tab_bar.TabsNames:c_str()
	local name_end = string.find(buf, "\0", tab.NameOffset + 1, true)
	return string.sub(buf, tab.NameOffset + 1, (name_end or #buf + 1) - 1)
end

function ImGui.TabBarGetTabPos(tab_bar, tab)
	if band(tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0 then
		return tab_bar.BarRect.Min + ImVec2(IM_TRUNC(tab.Offset - tab_bar.ScrollingAnim), 0.0)
	else
		return tab_bar.BarRect.Min + ImVec2(tab.Offset, 0.0)
	end
end

function ImGui.TabBarRemoveTab(tab_bar, tab_id)
	local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
	if tab then
		tab_bar.Tabs:erase(tab_bar.Tabs:index_from_ptr(tab))
	end
	if tab_bar.VisibleTabId == tab_id then
		tab_bar.VisibleTabId = 0
	end
	if tab_bar.SelectedTabId == tab_id then
		tab_bar.SelectedTabId = 0
	end
	if tab_bar.NextSelectedTabId == tab_id then
		tab_bar.NextSelectedTabId = 0
	end
end

function ImGui.TabBarCloseTab(tab_bar, tab)
	if btest(tab.Flags, ImGuiTabItemFlags.Button) then
		return
	end

	if band(tab.Flags, bor(ImGuiTabItemFlags.UnsavedDocument, ImGuiTabItemFlags.NoAssumedClosure)) == 0 then
		tab.WantClose = true
		if tab_bar.VisibleTabId == tab.ID then
			tab.LastFrameVisible = -1
			tab_bar.SelectedTabId = 0
			tab_bar.NextSelectedTabId = 0
		end
	else
		if tab_bar.VisibleTabId ~= tab.ID then
			ImGui.TabBarQueueFocus(tab_bar, tab)
		end
	end
end

function ImGui.TabBarScrollClamp(tab_bar, scrolling)
	scrolling = ImMin(scrolling, tab_bar.WidthAllTabs - tab_bar.BarRect:GetWidth())
	return ImMax(scrolling, 0.0)
end

function ImGui.TabBarScrollToTab(tab_bar, tab_id, sections)
	local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
	if tab == nil then
		return
	end

	if btest(tab.Flags, ImGuiTabItemFlags.Leading) then
		tab = tab_bar.Tabs[sections[1].TabCount + 1]
	elseif btest(tab.Flags, ImGuiTabItemFlags.Trailing) then
		tab = tab_bar.Tabs[sections[1].TabCount + sections[2].TabCount + 1]
	end
	if btest(tab.Flags, ImGuiTabItemFlags.SectionMask_) then
		return
	end

	local g = ImGui.GImGui
	local margin = ImClamp(tab_bar.ScrollingRectMaxX - tab_bar.ScrollingRectMinX - tab.Width, g.Style.ItemInnerSpacing.x, g.FontSize * 1.0)
	local order = ImGui.TabBarGetTabOrder(tab_bar, tab)

	local scrollable_width = ImGui.TabBarCalcScrollableWidth(tab_bar, sections)

	local tab_x1 = tab.Offset - sections[1].Width + (if order > sections[1].TabCount - 1 then -margin else 0.0)
	local tab_x2 = tab.Offset - sections[1].Width + tab.Width + (if order + 1 < tab_bar.Tabs.Size - sections[3].TabCount then margin else 1.0)
	tab_bar.ScrollingTargetDistToVisibility = 0.0
	if tab_bar.ScrollingTarget > tab_x1 or (tab_x2 - tab_x1 >= scrollable_width) then
		tab_bar.ScrollingTargetDistToVisibility = ImMax(tab_bar.ScrollingAnim - tab_x2, 0.0)
		tab_bar.ScrollingTarget = tab_x1
	elseif tab_bar.ScrollingTarget < tab_x2 - scrollable_width then
		tab_bar.ScrollingTargetDistToVisibility = ImMax((tab_x1 - scrollable_width) - tab_bar.ScrollingAnim, 0.0)
		tab_bar.ScrollingTarget = tab_x2 - scrollable_width
	end
end

function ImGui.TabBarQueueFocus(tab_bar, tab_or_name)
	if type(tab_or_name) == "string" then
		assert(band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) == 0)
		local tab_id = ImGui.TabBarCalcTabID(tab_bar, tab_or_name, nil)
		tab_bar.NextSelectedTabId = tab_id
		return
	end
	tab_bar.NextSelectedTabId = tab_or_name.ID
end

function ImGui.TabBarQueueReorder(tab_bar, tab, offset)
	assert(offset ~= 0)
	assert(tab_bar.ReorderRequestTabId == 0)
	tab_bar.ReorderRequestTabId = tab.ID
	tab_bar.ReorderRequestOffset = offset
end

function ImGui.TabBarQueueReorderFromMousePos(tab_bar, src_tab, mouse_pos)
	local g = ImGui.GImGui
	assert(tab_bar.ReorderRequestTabId == 0)
	if band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) == 0 then
		return
	end

	local tab_spacing = g.Style.ItemInnerSpacing.x
	local is_central_section = band(src_tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0
	local bar_offset = tab_bar.BarRect.Min.x - (if is_central_section then tab_bar.ScrollingTarget else 0)

	local dir = if (bar_offset + src_tab.Offset) > mouse_pos.x then -1 else 1
	local src_idx = tab_bar.Tabs:index_from_ptr(src_tab)
	local dst_idx = src_idx
	local i = src_idx
	while i >= 0 and i < tab_bar.Tabs.Size do
		local dst_tab = tab_bar.Tabs[i + 1]
		if btest(dst_tab.Flags, ImGuiTabItemFlags.NoReorder) then
			break
		end
		if band(dst_tab.Flags, ImGuiTabItemFlags.SectionMask_) ~= band(src_tab.Flags, ImGuiTabItemFlags.SectionMask_) then
			break
		end
		dst_idx = i

		local x1 = bar_offset + dst_tab.Offset - tab_spacing
		local x2 = bar_offset + dst_tab.Offset + dst_tab.Width + tab_spacing
		if (dir < 0 and mouse_pos.x > x1) or (dir > 0 and mouse_pos.x < x2) then
			break
		end
		i += dir
	end

	if dst_idx ~= src_idx then
		ImGui.TabBarQueueReorder(tab_bar, src_tab, dst_idx - src_idx)
	end
end

function ImGui.TabBarProcessReorder(tab_bar)
	local tab1 = ImGui.TabBarFindTabByID(tab_bar, tab_bar.ReorderRequestTabId)
	if tab1 == nil or btest(tab1.Flags, ImGuiTabItemFlags.NoReorder) then
		return false
	end

	local tab1_order = ImGui.TabBarGetTabOrder(tab_bar, tab1)
	local tab2_order = tab1_order + tab_bar.ReorderRequestOffset
	if tab2_order < 0 or tab2_order >= tab_bar.Tabs.Size then
		return false
	end

	local tabs = tab_bar.Tabs
	local tab2 = tabs[tab2_order + 1]
	if btest(tab2.Flags, ImGuiTabItemFlags.NoReorder) then
		return false
	end
	if band(tab1.Flags, ImGuiTabItemFlags.SectionMask_) ~= band(tab2.Flags, ImGuiTabItemFlags.SectionMask_) then
		return false
	end

	local item_tmp = tab1
	if tab_bar.ReorderRequestOffset > 0 then
		for n = tab1_order, tab2_order - 1 do
			tabs[n + 1] = tabs[n + 2]
		end
	else
		for n = tab1_order, tab2_order + 1, -1 do
			tabs[n + 1] = tabs[n]
		end
	end
	tabs[tab2_order + 1] = item_tmp

	if btest(tab_bar.Flags, ImGuiTabBarFlags.SaveSettings) then
		ImGui.MarkIniSettingsDirty()
	end
	return true
end

function ImGui.TabBarScrollingButtons(tab_bar)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local arrow_button_size = ImVec2(g.FontSize - 2.0, g.FontSize + g.Style.FramePadding.y * 2.0)
	local scrolling_buttons_width = arrow_button_size.x * 2.0

	local backup_cursor_pos = window.DC.CursorPos

	local select_dir = 0
	local arrow_col = g.Style.Colors[ImGuiCol.Text + 1]
	arrow_col = ImVec4(arrow_col.x, arrow_col.y, arrow_col.z, arrow_col.w * 0.5)

	ImGui.PushStyleColor(ImGuiCol.Text, arrow_col)
	ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
	ImGui.PushItemFlag(bor(ImGuiItemFlags.ButtonRepeat, ImGuiItemFlags.NoNav), true)
	local backup_repeat_delay = g.IO.KeyRepeatDelay
	local backup_repeat_rate = g.IO.KeyRepeatRate
	g.IO.KeyRepeatDelay = 0.250
	g.IO.KeyRepeatRate = 0.200
	local x = ImMax(tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.x - scrolling_buttons_width)
	window.DC.CursorPos = ImVec2(x, tab_bar.BarRect.Min.y)
	if ImGui.ArrowButtonEx("##<", ImGuiDir.Left, arrow_button_size, ImGuiButtonFlags.PressedOnClick) then
		select_dir = -1
	end
	window.DC.CursorPos = ImVec2(x + arrow_button_size.x, tab_bar.BarRect.Min.y)
	if ImGui.ArrowButtonEx("##>", ImGuiDir.Right, arrow_button_size, ImGuiButtonFlags.PressedOnClick) then
		select_dir = 1
	end
	ImGui.PopItemFlag()
	ImGui.PopStyleColor(2)
	g.IO.KeyRepeatRate = backup_repeat_rate
	g.IO.KeyRepeatDelay = backup_repeat_delay

	local tab_to_scroll_to = nil
	if select_dir ~= 0 then
		local tab_item = ImGui.TabBarFindTabByID(tab_bar, tab_bar.SelectedTabId)
		if tab_item then
			local selected_order = ImGui.TabBarGetTabOrder(tab_bar, tab_item)
			local target_order = selected_order + select_dir

			while tab_to_scroll_to == nil do
				tab_to_scroll_to = tab_bar.Tabs[(if target_order >= 0 and target_order < tab_bar.Tabs.Size then target_order else selected_order) + 1]

				if btest(tab_to_scroll_to.Flags, ImGuiTabItemFlags.Button) then
					target_order += select_dir
					selected_order += select_dir
					tab_to_scroll_to = if target_order < 0 or target_order >= tab_bar.Tabs.Size then tab_to_scroll_to else nil
				end
			end
		end
	end
	window.DC.CursorPos = backup_cursor_pos
	tab_bar.BarRect = tab_bar.BarRect:WithMaxX(tab_bar.BarRect.Max.x - (scrolling_buttons_width + 1.0))

	return tab_to_scroll_to
end

function ImGui.TabBarTabListPopupButton(tab_bar)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local tab_list_popup_button_width = g.FontSize + g.Style.FramePadding.y
	local backup_cursor_pos = window.DC.CursorPos
	window.DC.CursorPos = ImVec2(tab_bar.BarRect.Min.x - g.Style.FramePadding.y, tab_bar.BarRect.Min.y)
	tab_bar.BarRect = tab_bar.BarRect:WithMinX(tab_bar.BarRect.Min.x + tab_list_popup_button_width)

	local arrow_col = g.Style.Colors[ImGuiCol.Text + 1]
	arrow_col = ImVec4(arrow_col.x, arrow_col.y, arrow_col.z, arrow_col.w * 0.5)
	ImGui.PushStyleColor(ImGuiCol.Text, arrow_col)
	ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
	local open = ImGui.BeginCombo("##v", nil, bor(ImGuiComboFlags.NoPreview, ImGuiComboFlags.HeightLargest))
	ImGui.PopStyleColor(2)

	local tab_to_select = nil
	if open then
		for tab_n = 0, tab_bar.Tabs.Size - 1 do
			local tab = tab_bar.Tabs[tab_n + 1]
			if btest(tab.Flags, ImGuiTabItemFlags.Button) then
				continue
			end

			local tab_name = ImGui.TabBarGetTabName(tab_bar, tab)
			if ImGui.Selectable(tab_name, tab_bar.SelectedTabId == tab.ID) then
				tab_to_select = tab
			end
		end
		ImGui.EndCombo()
	end

	window.DC.CursorPos = backup_cursor_pos
	return tab_to_select
end

function ImGui.BeginTabItem(label, p_open, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false, p_open
	end

	local tab_bar = g.CurrentTabBar
	if tab_bar == nil then
		local msg = "Needs to be called between BeginTabBar() and EndTabBar()!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return false, p_open
	end
	assert(band(flags, ImGuiTabItemFlags.Button) == 0)

	local ret
	ret, p_open = ImGui.TabItemEx(tab_bar, label, p_open, flags, nil)
	if ret and not btest(flags, ImGuiTabItemFlags.NoPushId) then
		local tab = tab_bar.Tabs[tab_bar.LastTabItemIdx + 1]
		ImGui.PushOverrideID(tab.ID)
	end
	return ret, p_open
end

function ImGui.EndTabItem()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	local tab_bar = g.CurrentTabBar
	if tab_bar == nil then
		local msg = "Needs to be called between BeginTabBar() and EndTabBar()!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return
	end
	assert(tab_bar.LastTabItemIdx >= 0)
	local tab = tab_bar.Tabs[tab_bar.LastTabItemIdx + 1]
	if not btest(tab.Flags, ImGuiTabItemFlags.NoPushId) then
		ImGui.PopID()
	end
end

function ImGui.TabItemButton(label, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false
	end

	local tab_bar = g.CurrentTabBar
	if tab_bar == nil then
		local msg = "Needs to be called between BeginTabBar() and EndTabBar()!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return false
	end
	return (ImGui.TabItemEx(tab_bar, label, nil, bor(flags, ImGuiTabItemFlags.Button, ImGuiTabItemFlags.NoReorder), nil))
end

function ImGui.TabItemSpacing(str_id, flags, width)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	local tab_bar = g.CurrentTabBar
	if tab_bar == nil then
		local msg = "Needs to be called between BeginTabBar() and EndTabBar()!"
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return
	end
	ImGui.SetNextItemWidth(width)
	ImGui.TabItemEx(
		tab_bar,
		str_id,
		nil,
		bor(flags, ImGuiTabItemFlags.Button, ImGuiTabItemFlags.NoReorder, ImGuiTabItemFlags.Invisible),
		nil
	)
end

function ImGui.TabItemEx(tab_bar, label, p_open, flags, docked_window)
	local g = ImGui.GImGui
	if tab_bar.WantLayout then
		local backup_next_item_data = g.NextItemData:Copy()
		ImGui.TabBarLayout(tab_bar)
		g.NextItemData = backup_next_item_data
	end
	local window = g.CurrentWindow
	if window.SkipItems then
		return false, p_open
	end

	local style = g.Style
	local id = ImGui.TabBarCalcTabID(tab_bar, label, docked_window)

	if p_open == false then
		ImGui.ItemAdd(ImRect.new(), id, nil, ImGuiItemFlags.NoNav)
		return false, p_open
	end

	assert(p_open == nil or not btest(flags, ImGuiTabItemFlags.Button))
	assert(
		band(flags, bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing)) ~= bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing)
	)

	local p_open_out = p_open
	if btest(flags, ImGuiTabItemFlags.NoCloseButton) then
		p_open = nil
	elseif p_open == nil then
		flags = bor(flags, ImGuiTabItemFlags.NoCloseButton)
	end

	local tab = ImGui.TabBarFindTabByID(tab_bar, id)
	local tab_is_new = false
	if tab == nil then
		tab = ImGuiTabItem.new()
		tab_bar.Tabs:push_back(tab)
		tab.ID = id
		tab_bar.TabsAddedNew = true
		tab_is_new = true
	end
	tab_bar.LastTabItemIdx = tab_bar.Tabs:index_from_ptr(tab)

	local size = ImGui.TabItemCalcSize(label, (p_open ~= nil) or btest(flags, ImGuiTabItemFlags.UnsavedDocument))
	tab.RequestedWidth = -1.0
	if btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasWidth) then
		tab.RequestedWidth = g.NextItemData.Width
		size = ImVec2(g.NextItemData.Width, size.y)
	end
	if tab_is_new then
		tab.Width = ImMax(1.0, size.x)
	end
	tab.ContentWidth = size.x
	tab.BeginOrder = tab_bar.TabsActiveCount
	tab_bar.TabsActiveCount += 1

	local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
	local tab_bar_focused = band(tab_bar.Flags, ImGuiTabBarFlags.IsFocused) ~= 0
	local tab_appearing = (tab.LastFrameVisible + 1 < g.FrameCount)
	local tab_just_unsaved = btest(flags, ImGuiTabItemFlags.UnsavedDocument) and not btest(tab.Flags, ImGuiTabItemFlags.UnsavedDocument)
	local is_tab_button = band(flags, ImGuiTabItemFlags.Button) ~= 0
	tab.LastFrameVisible = g.FrameCount
	tab.Flags = flags

	if docked_window ~= nil then
		assert(docked_window == nil)
	else
		tab.NameOffset = tab_bar.TabsNames:size()
		tab_bar.TabsNames:append(label .. "\0")
	end

	if not is_tab_button then
		if tab_appearing and btest(tab_bar.Flags, ImGuiTabBarFlags.AutoSelectNewTabs) and tab_bar.NextSelectedTabId == 0 then
			if not tab_bar_appearing or tab_bar.SelectedTabId == 0 then
				ImGui.TabBarQueueFocus(tab_bar, tab)
			end
		end
		if btest(flags, ImGuiTabItemFlags.SetSelected) and (tab_bar.SelectedTabId ~= id) then
			ImGui.TabBarQueueFocus(tab_bar, tab)
		end
	end

	local tab_contents_visible = (tab_bar.VisibleTabId == id)
	if tab_contents_visible then
		tab_bar.VisibleTabWasSubmitted = true
	end

	if not tab_contents_visible and tab_bar.SelectedTabId == 0 and tab_bar_appearing then
		if tab_bar.Tabs.Size == 1 and not btest(tab_bar.Flags, ImGuiTabBarFlags.AutoSelectNewTabs) then
			tab_contents_visible = true
		end
	end

	if tab_appearing and (not tab_bar_appearing or tab_is_new) then
		ImGui.ItemAdd(ImRect.new(), id, nil, ImGuiItemFlags.NoNav)
		if is_tab_button then
			return false, p_open_out
		end
		return tab_contents_visible, p_open_out
	end

	if tab_bar.SelectedTabId == id then
		tab.LastFrameSelected = g.FrameCount
	end

	local backup_main_cursor_pos = window.DC.CursorPos

	local is_central_section = band(tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0
	size = ImVec2(tab.Width, size.y)
	window.DC.CursorPos = ImGui.TabBarGetTabPos(tab_bar, tab)
	local pos = window.DC.CursorPos
	local bb = ImRect.new(pos, pos + size)

	local want_clip_rect = is_central_section and (bb.Min.x < tab_bar.ScrollingRectMinX or bb.Max.x > tab_bar.ScrollingRectMaxX)
	if want_clip_rect then
		ImGui.PushClipRect(
			ImVec2(ImClamp(bb.Min.x, tab_bar.ScrollingRectMinX, tab_bar.ScrollingRectMaxX), bb.Min.y - 1),
			ImVec2(tab_bar.ScrollingRectMaxX, bb.Max.y),
			true
		)
	end

	local backup_cursor_max_pos = window.DC.CursorMaxPos
	ImGui.ItemSize(bb:GetSize(), style.FramePadding.y)
	window.DC.CursorMaxPos = backup_cursor_max_pos

	if not ImGui.ItemAdd(bb, id) then
		if want_clip_rect then
			ImGui.PopClipRect()
		end
		window.DC.CursorPos = backup_main_cursor_pos
		return tab_contents_visible, p_open_out
	end

	local button_flags = bor(
		if is_tab_button then ImGuiButtonFlags.PressedOnClickRelease else ImGuiButtonFlags.PressedOnClick,
		ImGuiButtonFlags.AllowOverlap
	)
	if g.DragDropActive then
		button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnDragDropHold)
	end
	local hovered, held, pressed
	if btest(flags, ImGuiTabItemFlags.Invisible) then
		hovered, held, pressed = false, false, false
	else
		pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, button_flags)
	end
	if pressed and not is_tab_button then
		ImGui.TabBarQueueFocus(tab_bar, tab)
	end

	if held and not tab_appearing and ImGui.IsMouseDragging(0) then
		if not g.DragDropActive and btest(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) then
			if g.IO.MouseDelta.x < 0.0 and g.IO.MousePos.x < bb.Min.x then
				ImGui.TabBarQueueReorderFromMousePos(tab_bar, tab, g.IO.MousePos)
			elseif g.IO.MouseDelta.x > 0.0 and g.IO.MousePos.x > bb.Max.x then
				ImGui.TabBarQueueReorderFromMousePos(tab_bar, tab, g.IO.MousePos)
			end
		end
	end

	local is_visible = btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) and not btest(flags, ImGuiTabItemFlags.Invisible)
	if is_visible then
		local display_draw_list = window.DrawList
		local tab_col_idx
		if held or hovered then
			tab_col_idx = ImGuiCol.TabHovered
		elseif tab_contents_visible then
			tab_col_idx = if tab_bar_focused then ImGuiCol.TabSelected else ImGuiCol.TabDimmedSelected
		else
			tab_col_idx = if tab_bar_focused then ImGuiCol.Tab else ImGuiCol.TabDimmed
		end
		local tab_col = ImGui.GetColorU32(tab_col_idx)
		ImGui.TabItemBackground(display_draw_list, bb, flags, tab_col)
		if tab_contents_visible and btest(tab_bar.Flags, ImGuiTabBarFlags.DrawSelectedOverline) and style.TabBarOverlineSize > 0.0 then
			local tl = bb:GetTL() + ImVec2(0, style.TabBarOverlineSize * 0.5)
			local tr = bb:GetTR() + ImVec2(0, style.TabBarOverlineSize * 0.5)
			local overline_col = ImGui.GetColorU32(if tab_bar_focused then ImGuiCol.TabSelectedOverline else ImGuiCol.TabDimmedSelectedOverline)
			if style.TabRounding > 0.0 then
				local rounding = style.TabRounding
				display_draw_list:PathArcToFast(tl + ImVec2(rounding, rounding), rounding, 7, 9)
				display_draw_list:PathArcToFast(tr + ImVec2(-rounding, rounding), rounding, 9, 11)
				display_draw_list:PathStroke(overline_col, style.TabBarOverlineSize)
			else
				display_draw_list:AddLine(tl, tr, overline_col, style.TabBarOverlineSize)
			end
		end
		ImGui.RenderNavCursor(bb, id)

		local hovered_unblocked = ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)
		if tab_bar.SelectedTabId ~= tab.ID and hovered_unblocked and (ImGui.IsMouseClicked(1) or ImGui.IsMouseReleased(1)) and not is_tab_button then
			ImGui.TabBarQueueFocus(tab_bar, tab)
		end

		if btest(tab_bar.Flags, ImGuiTabBarFlags.NoCloseWithMiddleMouseButton) then
			flags = bor(flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton)
		end

		local close_button_id = if p_open ~= nil then ImGui.GetIDWithSeed("#CLOSE", nil, id) else 0
		local just_closed, text_clipped = ImGui.TabItemLabelAndCloseButton(
			display_draw_list,
			bb,
			if tab_just_unsaved then band(flags, bnot(ImGuiTabItemFlags.UnsavedDocument)) else flags,
			tab_bar.FramePadding,
			label,
			id,
			close_button_id,
			tab_contents_visible,
			nil,
			nil
		)
		if just_closed and p_open ~= nil then
			p_open = false
			p_open_out = false
			ImGui.TabBarCloseTab(tab_bar, tab)
		end

		if text_clipped and g.HoveredId == id and not held then
			if not btest(tab_bar.Flags, ImGuiTabBarFlags.NoTooltip) and not btest(tab.Flags, ImGuiTabItemFlags.NoTooltip) then
				ImGui.SetItemTooltip("%s", string.sub(label, 1, ImGui.FindRenderedTextEnd(label) - 1))
			end
		end
	end

	if want_clip_rect then
		ImGui.PopClipRect()
	end
	window.DC.CursorPos = backup_main_cursor_pos

	assert(not is_tab_button or not (tab_bar.SelectedTabId == tab.ID and is_tab_button))
	if is_tab_button then
		return pressed, p_open_out
	end
	return tab_contents_visible, p_open_out
end

function ImGui.SetTabItemClosed(label)
	local g = ImGui.GImGui
	local is_within_manual_tab_bar = g.CurrentTabBar ~= nil and not btest(g.CurrentTabBar.Flags, ImGuiTabBarFlags.DockNode)
	if is_within_manual_tab_bar then
		local tab_bar = g.CurrentTabBar
		local tab_id = ImGui.TabBarCalcTabID(tab_bar, label, nil)
		local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
		if tab then
			tab.WantClose = true
		end
	end
end

function ImGui.TabItemCalcSize(label, has_close_button_or_unsaved_marker)
	if type(label) ~= "string" then
		assert(false)
		return ImVec2(0.0, 0.0)
	end
	local g = ImGui.GImGui
	local label_size = ImGui.CalcTextSize(label, nil, true)
	local size_x = label_size.x + g.Style.FramePadding.x
	local size_y = label_size.y + g.Style.FramePadding.y * 2.0
	if has_close_button_or_unsaved_marker then
		size_x += g.Style.FramePadding.x + (g.Style.ItemInnerSpacing.x + g.FontSize)
	else
		size_x += g.Style.FramePadding.x + 1.0
	end
	return ImVec2(ImMin(size_x, ImGui.TabBarCalcMaxTabWidth()), size_y)
end

function ImGui.TabItemBackground(draw_list, bb, flags, col)
	local g = ImGui.GImGui
	local width = bb:GetWidth()
	assert(width > 0.0)
	local rounding = ImMax(0.0, ImMin(if btest(flags, ImGuiTabItemFlags.Button) then g.Style.FrameRounding else g.Style.TabRounding, width * 0.5 - 1.0))
	local y1 = bb.Min.y + 1.0
	local y2 = bb.Max.y - g.Style.TabBarBorderSize
	draw_list:AddRectFilled(ImVec2(bb.Min.x, y1), ImVec2(bb.Max.x, y2), col, rounding, ImDrawFlags.RoundTop)
	if g.Style.TabBorderSize > 0.0 then
		draw_list:PathLineTo(ImVec2(bb.Min.x, y2))
		draw_list:PathArcToFast(ImVec2(bb.Min.x + rounding, y1 + rounding), rounding, 6, 9)
		draw_list:PathArcToFast(ImVec2(bb.Max.x - rounding, y1 + rounding), rounding, 9, 12)
		draw_list:PathLineTo(ImVec2(bb.Max.x, y2))
		draw_list:PathStroke(ImGui.GetColorU32(ImGuiCol.Border), g.Style.TabBorderSize, ImDrawFlags.StrokeCenterBiased)
	end
end

function ImGui.TabItemLabelAndCloseButton(draw_list, bb, flags, frame_padding, label, tab_id, close_button_id, is_contents_visible, out_just_closed, out_text_clipped)
	local g = ImGui.GImGui
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	if bb:GetWidth() <= 1.0 then
		return false, false
	end

	local text_ellipsis_clip_bb = ImRect.fromXY(bb.Min.x + frame_padding.x, bb.Min.y + frame_padding.y, bb.Max.x - frame_padding.x, bb.Max.y)

	local text_clipped = (text_ellipsis_clip_bb.Min.x + label_size.x) > text_ellipsis_clip_bb.Max.x

	local button_sz = g.FontSize
	local button_pos = ImVec2(ImMax(bb.Min.x, bb.Max.x - frame_padding.x - button_sz), bb.Min.y + frame_padding.y)

	local close_button_pressed = false
	local close_button_visible = false
	local is_hovered = g.HoveredId == tab_id or g.HoveredId == close_button_id or g.ActiveId == tab_id or g.ActiveId == close_button_id

	if close_button_id ~= 0 then
		if is_contents_visible then
			close_button_visible = if g.Style.TabCloseButtonMinWidthSelected < 0.0
				then true
				else (is_hovered and bb:GetWidth() >= ImMax(button_sz, g.Style.TabCloseButtonMinWidthSelected))
		else
			close_button_visible = if g.Style.TabCloseButtonMinWidthUnselected < 0.0
				then true
				else (is_hovered and bb:GetWidth() >= ImMax(button_sz, g.Style.TabCloseButtonMinWidthUnselected))
		end
	end

	local unsaved_marker_visible = band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0
		and (button_pos.x + button_sz <= bb.Max.x)
		and (not close_button_visible or not is_hovered)
	if unsaved_marker_visible then
		local bullet_pos = button_pos + ImVec2(button_sz, button_sz) * 0.5
		ImGui.RenderBullet(draw_list, bullet_pos, ImGui.GetColorU32(ImGuiCol.UnsavedMarker))
	elseif close_button_visible then
		local last_item_backup = g.LastItemData:Copy()
		if ImGui.CloseButton(close_button_id, button_pos) then
			close_button_pressed = true
		end
		g.LastItemData = last_item_backup

		if is_hovered and not btest(flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton) and ImGui.IsMouseClicked(2) then
			close_button_pressed = true
		end
	end

	local ellipsis_max_x = text_ellipsis_clip_bb.Max.x
	if close_button_visible or unsaved_marker_visible then
		local visible_without_hover = unsaved_marker_visible
			or (if is_contents_visible then g.Style.TabCloseButtonMinWidthSelected else g.Style.TabCloseButtonMinWidthUnselected) < 0.0
		if visible_without_hover then
			text_ellipsis_clip_bb = text_ellipsis_clip_bb:WithMaxX(text_ellipsis_clip_bb.Max.x - button_sz * 0.90)
			ellipsis_max_x -= button_sz * 0.90
		else
			text_ellipsis_clip_bb = text_ellipsis_clip_bb:WithMaxX(text_ellipsis_clip_bb.Max.x - button_sz * 1.00)
		end
	end
	ImGui.LogSetNextTextDecoration("/", "\\")
	ImGui.RenderTextEllipsis(draw_list, text_ellipsis_clip_bb.Min, text_ellipsis_clip_bb.Max, ellipsis_max_x, label, label_end, label_size)

	return close_button_pressed, text_clipped
end

return true
