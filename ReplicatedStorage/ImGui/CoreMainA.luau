--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local DrawList = require("./DrawList")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax = Base.ImMin, Base.ImMax
local FLT_MAX = Base.FLT_MAX
local IM_COL32 = Base.IM_COL32
local IM_COL32_A_MASK = Base.IM_COL32_A_MASK
local IM_COL32_WHITE = Base.IM_COL32_WHITE
local IM_COL32_BLACK = Base.IM_COL32_BLACK
local ImHashStr = Base.ImHashStr
local ImQsort = Base.ImQsort

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiDragDropFlags = Enums.ImGuiDragDropFlags
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiWindowBgClickFlags = Enums.ImGuiWindowBgClickFlags
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiCond = Enums.ImGuiCond
local ImGuiContextHookType = Enums.ImGuiContextHookType
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiKey = Enums.ImGuiKey
local ImGuiDir = Enums.ImGuiDir
local ImGuiCol = Enums.ImGuiCol
local ImDrawFlags = Enums.ImDrawFlags
local ImFontAtlasFlags = Enums.ImFontAtlasFlags

local IMGUI_VIEWPORT_DEFAULT_ID = 0x11111111

function ImGui.SetCurrentWindow(window)
	local g = ImGui.GImGui
	g.CurrentWindow = window
	g.StackSizesInBeginForCurrentWindow = if g.CurrentWindow then g.CurrentWindowStack:back().StackSizesInBegin else nil
	g.CurrentTable = if window and window.DC.CurrentTableIdx ~= -1 then g.Tables:GetByIndex(window.DC.CurrentTableIdx) else nil
	g.CurrentDpiScale = 1.0
	if window then
		if bit32.btest(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) then
			local viewport = window.Viewport
			g.CurrentPixelDensity = if viewport.FramebufferScale.x ~= 0.0 then viewport.FramebufferScale.x else g.IO.DisplayFramebufferScale.x
		end
		local backup_skip_items = window.SkipItems
		window.SkipItems = false
		ImGui.UpdateCurrentFontSize(0.0)
		window.SkipItems = backup_skip_items
		ImGui.NavUpdateCurrentWindowIsScrollPushableX()
	end
end

function ImGui.GcCompactTransientMiscBuffers()
	local g = ImGui.GImGui
	g.ItemFlagsStack:clear()
	g.GroupStack:clear()
	g.InputTextLineIndex:clear()
	g.MultiSelectTempDataStacked = 0
	g.MultiSelectTempData:clear()
	ImGui.TableGcCompactSettings()
	for i = 1, g.FontAtlases.Size do
		g.FontAtlases[i]:CompactCache()
	end
end

function ImGui.GcCompactTransientWindowBuffers(window)
	window.MemoryCompacted = true
	window.MemoryDrawListIdxCapacity = window.DrawList:GetPrimCount()
	window.MemoryDrawListVtxCapacity = 0
	window.IDStack:clear()
	window.DrawList:_ClearFreeMemory()
	window.DC.ChildWindows:clear()
	window.DC.ItemWidthStack:clear()
	window.DC.TextWrapPosStack:clear()
end

function ImGui.GcAwakeTransientWindowBuffers(window)
	window.MemoryCompacted = false
	window.MemoryDrawListIdxCapacity = 0
	window.MemoryDrawListVtxCapacity = 0
end

function ImGui.SetActiveID(id, window)
	local g = ImGui.GImGui

	if g.ActiveId ~= 0 then
		local deactivated_data = g.DeactivatedItemData
		deactivated_data.ID = g.ActiveId
		deactivated_data.ElapseFrame = if g.LastItemData.ID == g.ActiveId then g.FrameCount else g.FrameCount + 1
		deactivated_data.HasBeenEditedBefore = g.ActiveIdHasBeenEditedBefore
		deactivated_data.IsAlive = (g.ActiveIdIsAlive == g.ActiveId)

		if g.InputTextState.ID == g.ActiveId then
			ImGui.InputTextDeactivateHook(g.ActiveId)
		end

		if g.MovingWindow ~= nil and g.ActiveId == g.MovingWindow.MoveId then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventActiveId) then
				ImGui.DebugLog("SetActiveID() cancel MovingWindow\n")
			end
			ImGui.StopMouseMovingWindow()
		end
	end

	g.ActiveIdIsJustActivated = (g.ActiveId ~= id)
	if g.ActiveIdIsJustActivated then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventActiveId) then
			local name = if window then window.Name else ""
			ImGui.DebugLog("SetActiveID() 0x%08X in \"%s\"%s(previously 0x%08X in \"%s\")\n", id, name,
				string.rep(" ", ImMax(0, 20 - #name)), g.ActiveId, if g.ActiveIdWindow then g.ActiveIdWindow.Name else "")
		end
		g.ActiveIdTimer = 0.0
		g.ActiveIdHasBeenPressedBefore = false
		g.ActiveIdHasBeenEditedBefore = false
		g.ActiveIdMouseButton = -1
		if id ~= 0 then
			g.LastActiveId = id
			g.LastActiveIdTimer = 0.0
		end
	end
	g.ActiveId = id
	g.ActiveIdAllowOverlap = false
	g.ActiveIdNoClearOnFocusLoss = false
	g.ActiveIdWindow = window
	g.ActiveIdHasBeenEditedThisFrame = false
	g.ActiveIdFromShortcut = false
	g.ActiveIdDisabledId = 0
	if id ~= 0 then
		g.ActiveIdIsAlive = id
		g.ActiveIdSource = if (g.NavActivateId == id or g.NavJustMovedToId == id) then g.NavInputSource else ImGuiInputSource.Mouse
		assert(g.ActiveIdSource ~= ImGuiInputSource.None)
	end

	g.ActiveIdUsingNavDirMask = 0x00
	g.ActiveIdUsingAllKeyboardKeys = false
end

function ImGui.ClearActiveID()
	ImGui.SetActiveID(0, nil)
end

function ImGui.SetHoveredID(id)
	local g = ImGui.GImGui
	g.HoveredId = id
	g.HoveredIdAllowOverlap = false
	if id ~= 0 and g.HoveredIdPreviousFrame ~= id then
		g.HoveredIdTimer = 0.0
		g.HoveredIdNotActiveTimer = 0.0
	end
end

function ImGui.GetHoveredID()
	local g = ImGui.GImGui
	return if g.HoveredId ~= 0 then g.HoveredId else g.HoveredIdPreviousFrame
end

function ImGui.MarkItemEdited(id)
	local g = ImGui.GImGui

	g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.EditedInternal)
	if bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.NoMarkEdited) then
		return
	end
	g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Edited)

	if g.ActiveId == id or g.ActiveId == 0 then
		g.AnyIdHasBeenEditedThisFrame = true
		g.ActiveIdHasBeenEditedThisFrame = true
		g.ActiveIdHasBeenEditedBefore = true
	end
	if g.DeactivatedItemData.ID == id then
		g.DeactivatedItemData.HasBeenEditedBefore = true
	end

	assert(g.DragDropActive or g.ActiveId == id or g.ActiveId == 0 or g.DeactivatedItemData.ID == id or g.ActiveIdPreviousFrame == id or g.NavJustMovedToId ~= 0 or (g.CurrentMultiSelect ~= nil and g.BoxSelectState.IsActive))
end

function ImGui.IsWindowContentHoverable(window, flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	if g.NavWindow then
		local focused_root_window = g.NavWindow.RootWindow
		if focused_root_window then
			if focused_root_window.WasActive and focused_root_window ~= window.RootWindow then
				local want_inhibit = false
				if bit32.btest(focused_root_window.Flags, ImGuiWindowFlags.Modal) then
					want_inhibit = true
				elseif bit32.btest(focused_root_window.Flags, ImGuiWindowFlags.Popup) and not bit32.btest(flags, ImGuiHoveredFlags.AllowWhenBlockedByPopup) then
					want_inhibit = true
				end

				if want_inhibit then
					if not ImGui.IsWindowWithinBeginStackOf(window.RootWindow, focused_root_window) then
						return false
					end
				end
			end
		end
	end
	return true
end

function ImGui.CalcDelayFromHoveredFlags(flags)
	local g = ImGui.GImGui
	if bit32.btest(flags, ImGuiHoveredFlags.DelayNormal) then
		return g.Style.HoverDelayNormal
	end
	if bit32.btest(flags, ImGuiHoveredFlags.DelayShort) then
		return g.Style.HoverDelayShort
	end
	return 0.0
end

function ImGui.ApplyHoverFlagsForTooltip(user_flags, shared_flags)
	local delay_mask = bit32.bor(ImGuiHoveredFlags.DelayNone, ImGuiHoveredFlags.DelayShort, ImGuiHoveredFlags.DelayNormal)
	if bit32.btest(user_flags, delay_mask) then
		shared_flags = bit32.band(shared_flags, bit32.bnot(delay_mask))
	end
	return bit32.bor(user_flags, shared_flags)
end

function ImGui.IsItemHovered(flags)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if not (bit32.band(flags, bit32.bnot(ImGuiHoveredFlags.AllowedMaskForIsItemHovered)) == 0) then
		if ImGui.ErrorLog("Invalid flags for IsItemHovered()!") then
			assert(false, "Invalid flags for IsItemHovered()!")
		end
	end

	if g.NavHighlightItemUnderNav and g.NavCursorVisible and not bit32.btest(flags, ImGuiHoveredFlags.NoNavOverride) then
		if not ImGui.IsItemFocused() then
			return false
		end
		if bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.Disabled) and not bit32.btest(flags, ImGuiHoveredFlags.AllowWhenDisabled) then
			return false
		end

		if bit32.btest(flags, ImGuiHoveredFlags.ForTooltip) then
			flags = ImGui.ApplyHoverFlagsForTooltip(flags, g.Style.HoverFlagsForTooltipNav)
		end
	else
		local status_flags = g.LastItemData.StatusFlags
		if not bit32.btest(status_flags, ImGuiItemStatusFlags.HoveredRect) then
			return false
		end

		if bit32.btest(flags, ImGuiHoveredFlags.ForTooltip) then
			flags = ImGui.ApplyHoverFlagsForTooltip(flags, g.Style.HoverFlagsForTooltipMouse)
		end

		if g.HoveredWindow ~= window and not bit32.btest(status_flags, ImGuiItemStatusFlags.HoveredWindow) then
			if not bit32.btest(flags, ImGuiHoveredFlags.AllowWhenOverlappedByWindow) then
				return false
			end
		end

		local id = g.LastItemData.ID
		if not bit32.btest(flags, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
			if g.ActiveId ~= 0 and g.ActiveId ~= id and not g.ActiveIdAllowOverlap and not g.ActiveIdFromShortcut then
				local cancel_is_hovered = true
				if g.ActiveId == window.MoveId and (id == 0 or g.ActiveIdDisabledId == id) then
					cancel_is_hovered = false
				end
				if cancel_is_hovered then
					return false
				end
			end
		end

		if not ImGui.IsWindowContentHoverable(window, flags) and not bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.NoWindowHoverableCheck) then
			return false
		end

		if bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.Disabled) and not bit32.btest(flags, ImGuiHoveredFlags.AllowWhenDisabled) then
			return false
		end

		if id == window.MoveId and window.WriteAccessed then
			return false
		end

		if bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowOverlap) and id ~= 0 then
			if not bit32.btest(flags, ImGuiHoveredFlags.AllowWhenOverlappedByItem) then
				if g.HoveredIdPreviousFrame ~= g.LastItemData.ID then
					return false
				end
			end
		end
	end

	local delay = ImGui.CalcDelayFromHoveredFlags(flags)
	if delay > 0.0 or bit32.btest(flags, ImGuiHoveredFlags.Stationary) then
		local hover_delay_id = if g.LastItemData.ID ~= 0 then g.LastItemData.ID else window:GetIDFromPos(g.LastItemData.Rect.Min)
		if bit32.btest(flags, ImGuiHoveredFlags.NoSharedDelay) and g.HoverItemDelayIdPreviousFrame ~= hover_delay_id then
			g.HoverItemDelayTimer = 0.0
		end
		g.HoverItemDelayId = hover_delay_id

		if bit32.btest(flags, ImGuiHoveredFlags.Stationary) and g.HoverItemUnlockedStationaryId ~= hover_delay_id then
			return false
		end

		if g.HoverItemDelayTimer < delay then
			return false
		end
	end

	return true
end

function ImGui.ItemHoverable(bb, id, item_flags)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	if id ~= 0 and g.HoveredIdPreviousFrame == id and not bit32.btest(item_flags, ImGuiItemFlags.AllowDuplicateId) then
		g.HoveredIdPreviousFrameItemCount += 1
		if g.DebugDrawIdConflictsId == id then
			window.DrawList:AddRect(bb.Min - ImVec2(1, 1), bb.Max + ImVec2(1, 1), IM_COL32(255, 0, 0, 255), 0.0, 2.0)
		end
	end

	if g.HoveredWindow ~= window then
		return false
	end
	if not ImGui.IsMouseHoveringRect(bb.Min, bb.Max) then
		return false
	end

	if g.HoveredId ~= 0 and g.HoveredId ~= id and not g.HoveredIdAllowOverlap then
		return false
	end
	if g.ActiveId ~= 0 and g.ActiveId ~= id and not g.ActiveIdAllowOverlap then
		if not g.ActiveIdFromShortcut then
			return false
		end
	end

	if not bit32.btest(item_flags, ImGuiItemFlags.NoWindowHoverableCheck) and not ImGui.IsWindowContentHoverable(window, ImGuiHoveredFlags.None) then
		g.HoveredIdIsDisabled = true
		return false
	end

	if id ~= 0 then
		if g.DragDropActive and g.DragDropPayload.SourceId == id and not bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceNoDisableHover) then
			return false
		end

		ImGui.SetHoveredID(id)

		if bit32.btest(item_flags, ImGuiItemFlags.AllowOverlap) then
			g.HoveredIdAllowOverlap = true
			if g.HoveredIdPreviousFrame ~= id then
				return false
			end
		end

		if id == g.LastItemData.ID and bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasShortcut) and g.ActiveId ~= id then
			if ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.ForTooltip, ImGuiHoveredFlags.DelayNormal)) then
				ImGui.SetTooltip("%s", ImGui.GetKeyChordName(g.LastItemData.Shortcut))
			end
		end
	end

	if bit32.btest(item_flags, ImGuiItemFlags.Disabled) then
		if g.ActiveId == id and id ~= 0 then
			ImGui.ClearActiveID()
		end
		g.HoveredIdIsDisabled = true
		return false
	end

	if id ~= 0 then
		if g.DebugItemPickerActive and g.HoveredIdPreviousFrame == id then
			ImGui.GetForegroundDrawList():AddRect(bb.Min, bb.Max, IM_COL32(255, 255, 0, 255))
		end
	end

	if g.NavHighlightItemUnderNav and not bit32.btest(item_flags, ImGuiItemFlags.NoNavDisableMouseHover) then
		return false
	end

	return true
end

function ImGui.IsClippedEx(bb, id)
	local g = ImGui.GImGui
	local clip_rect, bb_min, bb_max = g.CurrentWindow.ClipRect, bb.Min, bb.Max
	if not (clip_rect.Min.y < bb_max.y and clip_rect.Max.y > bb_min.y and clip_rect.Min.x < bb_max.x and clip_rect.Max.x > bb_min.x) then
		if id == 0 or (id ~= g.ActiveId and id ~= g.ActiveIdPreviousFrame and id ~= g.NavId and id ~= g.NavActivateId) then
			if not g.ItemUnclipByLog then
				return true
			end
		end
	end
	return false
end

function ImGui.SetLastItemData(item_id, item_flags, status_flags, item_rect)
	local g = ImGui.GImGui
	g.LastItemData.ID = item_id
	g.LastItemData.ItemFlags = item_flags
	g.LastItemData.StatusFlags = status_flags
	g.LastItemData.Rect = item_rect
	g.LastItemData.NavRect = item_rect
end

function ImGui.SetLastItemDataForWindow(window, rect)
	local g = ImGui.GImGui
	ImGui.SetLastItemData(window.MoveId, g.CurrentItemFlags, window.DC.WindowItemStatusFlags, rect)
end

function ImGui.SetLastItemDataForChildWindowItem(window, rect)
	local g = ImGui.GImGui
	ImGui.SetLastItemData(window.ChildId, g.CurrentItemFlags, window.DC.ChildItemStatusFlags, rect)
end

function ImGui.CalcWrapWidthForPos(pos, wrap_pos_x)
	if wrap_pos_x < 0.0 then
		return 0.0
	end

	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if wrap_pos_x == 0.0 then
		wrap_pos_x = window.WorkRect.Max.x
	elseif wrap_pos_x > 0.0 then
		wrap_pos_x += window.Pos.x - window.Scroll.x
	end

	return ImMax(wrap_pos_x - pos.x, 1.0)
end

function ImGui.MemAlloc(size)
	local ptr = {}
	local ctx = ImGui.GImGui
	if ctx then
		ImGui.DebugAllocHook(ctx.DebugAllocInfo, ctx.FrameCount, ptr, size)
	end
	return ptr
end

function ImGui.MemFree(ptr)
	if ptr ~= nil then
		local ctx = ImGui.GImGui
		if ctx then
			ImGui.DebugAllocHook(ctx.DebugAllocInfo, ctx.FrameCount, ptr, -1)
		end
	end
end

function ImGui.DemoMarker(file, line, section)
	local g = ImGui.GImGui
	if g.DemoMarkerCallback ~= nil then
		g.DemoMarkerCallback(file, line, section)
	end
end

function ImGui.DebugAllocHook(info, frame_count, ptr, size)
	local entry = info.LastEntriesBuf[info.LastEntriesIdx + 1]
	if entry.FrameCount ~= frame_count then
		info.LastEntriesIdx = (info.LastEntriesIdx + 1) % #info.LastEntriesBuf
		entry = info.LastEntriesBuf[info.LastEntriesIdx + 1]
		entry.FrameCount = frame_count
		entry.AllocCount = 0
		entry.FreeCount = 0
	end
	if size ~= -1 then
		entry.AllocCount += 1
		info.TotalAllocCount += 1
	else
		entry.FreeCount += 1
		info.TotalFreeCount += 1
	end
end

function ImGui.GetClipboardText()
	local g = ImGui.GImGui
	return if g.PlatformIO.Platform_GetClipboardTextFn then g.PlatformIO.Platform_GetClipboardTextFn(g) else nil
end

function ImGui.SetClipboardText(text)
	local g = ImGui.GImGui
	if g.PlatformIO.Platform_SetClipboardTextFn ~= nil then
		g.PlatformIO.Platform_SetClipboardTextFn(g, text)
	end
end

function ImGui.GetVersion()
	return Base.IMGUI_VERSION
end

function ImGui.GetIO(ctx)
	if ctx ~= nil then
		return ctx.IO
	end
	assert(ImGui.GImGui ~= nil, "No current context. Did you call ImGui::CreateContext() and ImGui::SetCurrentContext() ?")
	return ImGui.GImGui.IO
end

function ImGui.GetPlatformIO(ctx)
	if ctx ~= nil then
		return ctx.PlatformIO
	end
	assert(ImGui.GImGui ~= nil, "No current context. Did you call ImGui::CreateContext() and ImGui::SetCurrentContext()?")
	return ImGui.GImGui.PlatformIO
end

function ImGui.GetDrawData()
	local g = ImGui.GImGui
	local viewport = g.Viewports[1]
	return if viewport.DrawDataP.Valid then viewport.DrawDataP else nil
end

function ImGui.GetTime()
	return ImGui.GImGui.Time
end

function ImGui.GetFrameCount()
	return ImGui.GImGui.FrameCount
end

function ImGui.GetViewportBgFgDrawList(viewport, drawlist_no, drawlist_name)
	local g = ImGui.GImGui
	assert(drawlist_no < #viewport.BgFgDrawListsLastFrameActive)
	local draw_list = viewport.BgFgDrawLists[drawlist_no + 1]
	if draw_list == nil then
		draw_list = DrawList.ImDrawList.new(g.DrawListSharedData)
		draw_list._OwnerName = drawlist_name
		viewport.BgFgDrawLists[drawlist_no + 1] = draw_list
	end

	if viewport.BgFgDrawListsLastFrameActive[drawlist_no + 1] ~= g.FrameCount then
		draw_list:_ResetForNewFrame()
		draw_list:_SetPixelDensity(viewport.FramebufferScale.x)
		draw_list:PushTexture(g.IO.Fonts.TexRef)
		draw_list:PushClipRect(viewport.Pos, viewport.Pos + viewport.Size, false)
		viewport.BgFgDrawListsLastFrameActive[drawlist_no + 1] = g.FrameCount
		viewport.BgFgDrawListsLastTimeActive[drawlist_no + 1] = g.Time
	end
	return draw_list
end

function ImGui.GetBackgroundDrawList(viewport)
	if viewport == nil or viewport.BgFgDrawLists == nil then
		viewport = ImGui.GImGui.Viewports[1]
	end
	return ImGui.GetViewportBgFgDrawList(viewport, 0, "##Background")
end

function ImGui.GetForegroundDrawList(viewport)
	if viewport == nil or viewport.BgFgDrawLists == nil then
		viewport = ImGui.GImGui.Viewports[1]
	end
	return ImGui.GetViewportBgFgDrawList(viewport, 1, "##Foreground")
end

function ImGui.GetDrawListSharedData()
	return ImGui.GImGui.DrawListSharedData
end

function ImGui.StartMouseMovingWindow(window)
	local g = ImGui.GImGui
	ImGui.FocusWindow(window)
	ImGui.SetActiveID(window.MoveId, window)
	if g.IO.ConfigNavCursorVisibleAuto then
		g.NavCursorVisible = false
	end
	g.ActiveIdClickOffset = g.IO.MouseClickedPos[1] - window.RootWindow.Pos
	g.ActiveIdNoClearOnFocusLoss = true
	ImGui.SetActiveIdUsingAllKeyboardKeys()

	local can_move_window = true
	if bit32.btest(window.Flags, ImGuiWindowFlags.NoMove) or bit32.btest(window.RootWindow.Flags, ImGuiWindowFlags.NoMove) then
		can_move_window = false
	end
	if can_move_window then
		g.MovingWindow = window
	end
end

function ImGui.StopMouseMovingWindow()
	local g = ImGui.GImGui
	g.MovingWindow = nil
end

function ImGui.UpdateMouseMovingWindowNewFrame()
	local g = ImGui.GImGui
	if g.MovingWindow ~= nil then
		ImGui.KeepAliveID(g.ActiveId)
		assert(g.MovingWindow and g.MovingWindow.RootWindow)
		local moving_window = g.MovingWindow.RootWindow
		if g.IO.MouseDown[1] and ImGui.IsMousePosValid(g.IO.MousePos) then
			local pos = g.IO.MousePos - g.ActiveIdClickOffset
			ImGui.SetWindowPos(moving_window, pos, ImGuiCond.Always)
			ImGui.FocusWindow(g.MovingWindow)
		else
			ImGui.StopMouseMovingWindow()
			ImGui.ClearActiveID()
		end
	else
		if g.ActiveIdWindow and g.ActiveIdWindow.MoveId == g.ActiveId then
			ImGui.KeepAliveID(g.ActiveId)
			if not g.IO.MouseDown[1] then
				ImGui.ClearActiveID()
			end
		end
	end
end

function ImGui.UpdateMouseMovingWindowEndFrame()
	local g = ImGui.GImGui
	if g.ActiveId ~= 0 or (g.HoveredId ~= 0 and not g.HoveredIdIsDisabled) then
		return
	end

	if g.NavWindow and g.NavWindow.Appearing then
		return
	end

	local hovered_window = g.HoveredWindow

	if ImGui.IsMouseClicked(0, ImGuiInputFlags.None, ImGuiKeyOwner.NoOwner) then
		local hovered_root = if hovered_window then hovered_window.RootWindow else nil
		local is_closed_popup = hovered_root ~= nil and bit32.btest(hovered_root.Flags, ImGuiWindowFlags.Popup) and not ImGui.IsPopupOpen(hovered_root.PopupId, ImGuiPopupFlags.AnyPopupLevel)
		local is_queued_focus_request = g.NavMoveSubmitted and bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.FocusApi)

		if hovered_window ~= nil and not is_closed_popup and not is_queued_focus_request then
			ImGui.StartMouseMovingWindow(hovered_window)

			if not bit32.btest(hovered_window.BgClickFlags, ImGuiWindowBgClickFlags.Move) then
				if not bit32.btest(hovered_root.Flags, ImGuiWindowFlags.NoTitleBar) then
					if not hovered_root:TitleBarRect():Contains(g.IO.MouseClickedPos[1]) then
						g.MovingWindow = nil
					end
				end
			end

			if g.HoveredIdIsDisabled then
				g.MovingWindow = nil
				g.ActiveIdDisabledId = g.HoveredId
			end
		elseif hovered_window == nil and g.NavWindow ~= nil then
			ImGui.FocusWindow(nil, ImGuiFocusRequestFlags.UnlessBelowModal)
		end
	end

	if g.HoveredId == 0 and ImGui.IsMouseClicked(1, ImGuiInputFlags.None, ImGuiKeyOwner.NoOwner) then
		local modal = ImGui.GetTopMostPopupModal()
		local hovered_window_above_modal = hovered_window ~= nil and (modal == nil or ImGui.IsWindowAbove(hovered_window, modal))
		ImGui.ClosePopupsOverWindow(if hovered_window_above_modal then hovered_window else modal, true)
	end
end

function ImGui.IsWindowActiveAndVisible(window)
	return window.Active and not window.Hidden
end

function ImGui.UpdateHoveredWindowAndCaptureFlags(mouse_pos)
	local g = ImGui.GImGui
	local io = g.IO

	g.WindowsBorderHoverPadding = ImMax(ImMax(g.Style.TouchExtraPadding.x, g.Style.TouchExtraPadding.y), g.Style.WindowBorderHoverPadding)

	local clear_hovered_windows = false
	g.HoveredWindow, g.HoveredWindowUnderMovingWindow = ImGui.FindHoveredWindowEx(mouse_pos, false, nil, nil)
	g.HoveredWindowBeforeClear = g.HoveredWindow

	local modal_window = ImGui.GetTopMostPopupModal()
	if modal_window and g.HoveredWindow and not ImGui.IsWindowWithinBeginStackOf(g.HoveredWindow.RootWindow, modal_window) then
		clear_hovered_windows = true
	end

	if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoMouse) then
		clear_hovered_windows = true
	end

	local has_open_popup = (g.OpenPopupStack.Size > 0)
	local has_open_modal = (modal_window ~= nil)
	local mouse_earliest_down = -1
	local mouse_any_down = false
	for i = 0, #io.MouseDown - 1 do
		if io.MouseClicked[i + 1] then
			io.MouseDownOwned[i + 1] = (g.HoveredWindow ~= nil) or has_open_popup
			io.MouseDownOwnedUnlessPopupClose[i + 1] = (g.HoveredWindow ~= nil) or has_open_modal
		end
		mouse_any_down = mouse_any_down or io.MouseDown[i + 1]
		if io.MouseDown[i + 1] or io.MouseReleased[i + 1] then
			if mouse_earliest_down == -1 or io.MouseClickedTime[i + 1] < io.MouseClickedTime[mouse_earliest_down + 1] then
				mouse_earliest_down = i
			end
		end
	end
	local mouse_avail = (mouse_earliest_down == -1) or io.MouseDownOwned[mouse_earliest_down + 1]
	local mouse_avail_unless_popup_close = (mouse_earliest_down == -1) or io.MouseDownOwnedUnlessPopupClose[mouse_earliest_down + 1]

	local mouse_dragging_extern_payload = g.DragDropActive and bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceExtern)
	if not mouse_avail and not mouse_dragging_extern_payload then
		clear_hovered_windows = true
	end

	if clear_hovered_windows then
		g.HoveredWindow = nil
		g.HoveredWindowUnderMovingWindow = nil
	end

	if g.WantCaptureMouseNextFrame ~= -1 then
		io.WantCaptureMouse = (g.WantCaptureMouseNextFrame ~= 0)
		io.WantCaptureMouseUnlessPopupClose = io.WantCaptureMouse
	else
		io.WantCaptureMouse = (mouse_avail and (g.HoveredWindow ~= nil or mouse_any_down)) or has_open_popup
		io.WantCaptureMouseUnlessPopupClose = (mouse_avail_unless_popup_close and (g.HoveredWindow ~= nil or mouse_any_down)) or has_open_modal
	end

	io.WantCaptureKeyboard = false
	if not bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) then
		if g.ActiveId ~= 0 or modal_window ~= nil then
			io.WantCaptureKeyboard = true
		elseif io.NavActive and bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) and io.ConfigNavCaptureKeyboard then
			io.WantCaptureKeyboard = true
		end
	end
	if g.WantCaptureKeyboardNextFrame ~= -1 then
		io.WantCaptureKeyboard = (g.WantCaptureKeyboardNextFrame ~= 0)
	end

	io.WantTextInput = if g.WantTextInputNextFrame ~= -1 then (g.WantTextInputNextFrame ~= 0) else false
end

function ImGui.SetupDrawListSharedData()
	local g = ImGui.GImGui
	local virtual_space = ImRect.fromXY(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
	for i = 1, g.Viewports.Size do
		virtual_space = virtual_space:Added(g.Viewports[i]:GetMainRect())
	end
	local shared = g.DrawListSharedData
	shared.ClipRectFullscreen = virtual_space:ToVec4()
	shared.CurveTessellationMaxError = g.Style.CurveTessellationMaxError
	shared:SetCircleTessellationMaxError(g.Style.CircleTessellationMaxError)
	shared.InitialDrawFlags = ImDrawFlags.None
	if bit32.btest(g.IO.Fonts.Flags, ImFontAtlasFlags.NoBakedLines) then
		g.Style.AntiAliasedLines = false
		g.Style.AntiAliasedLineEnds = false
	end
	if g.Style.AntiAliasedFill then
		shared.InitialDrawFlags = bit32.bor(shared.InitialDrawFlags, ImDrawFlags.AAFill)
	end
	if g.Style.AntiAliasedLines then
		shared.InitialDrawFlags = bit32.bor(shared.InitialDrawFlags, ImDrawFlags.AALines)
	end
	if g.Style.AntiAliasedLineEnds then
		shared.InitialDrawFlags = bit32.bor(shared.InitialDrawFlags, ImDrawFlags.AALineEnds)
	end
	if g.IO.ConfigDebugDrawListDefaultsToStrokeLegacy then
		shared.InitialDrawFlags = bit32.bor(shared.InitialDrawFlags, ImDrawFlags.StrokeLegacy)
	end
	if not bit32.btest(g.IO.Fonts.Flags, ImFontAtlasFlags.NoBakedRoundCorners) then
		shared.InitialDrawFlags = bit32.bor(shared.InitialDrawFlags, ImDrawFlags.UseTexForRoundCorners, ImDrawFlags.AllowTexForRoundCorners_)
	end
	if bit32.btest(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasVtxOffset) then
		shared.InitialDrawFlags = bit32.bor(shared.InitialDrawFlags, ImDrawFlags.UseVtxOffset)
	end
end

function ImGui.NewFrame()
	assert(ImGui.GImGui ~= nil, "No current context. Did you call ImGui::CreateContext() and ImGui::SetCurrentContext() ?")
	local g = ImGui.GImGui

	for n = g.Hooks.Size - 1, 0, -1 do
		if g.Hooks[n + 1].Type == ImGuiContextHookType.PendingRemoval_ then
			g.Hooks:erase(n)
		end
	end

	ImGui.CallContextHooks(g, ImGuiContextHookType.NewFramePre)

	ImGui.ErrorCheckNewFrameSanityChecks()

	ImGui.UpdateSettings()

	g.Time += g.IO.DeltaTime
	g.FrameCount += 1
	g.SessionDate = Structs.ImGuiPackedDate.new(g.PlatformIO.Platform_SessionDate)
	g.TooltipOverrideCount = 0
	g.WindowsActiveCount = 0
	g.MenusIdSubmittedThisFrame:resize(0)

	g.FramerateSecPerFrameAccum += g.IO.DeltaTime - g.FramerateSecPerFrame[g.FramerateSecPerFrameIdx + 1]
	g.FramerateSecPerFrame[g.FramerateSecPerFrameIdx + 1] = g.IO.DeltaTime
	g.FramerateSecPerFrameIdx = (g.FramerateSecPerFrameIdx + 1) % #g.FramerateSecPerFrame
	g.FramerateSecPerFrameCount = ImMin(g.FramerateSecPerFrameCount + 1, #g.FramerateSecPerFrame)
	g.IO.Framerate = if g.FramerateSecPerFrameAccum > 0.0 then (1.0 / (g.FramerateSecPerFrameAccum / g.FramerateSecPerFrameCount)) else FLT_MAX

	g.InputEventsTrail:resize(0)
	ImGui.UpdateInputEvents(g.IO.ConfigInputTrickleEventQueue)

	ImGui.UpdateViewportsNewFrame()

	ImGui.UpdateTexturesNewFrame()

	ImGui.SetupDrawListSharedData()
	ImGui.UpdateFontsNewFrame()

	g.WithinFrameScope = true

	for i = 1, g.Viewports.Size do
		g.Viewports[i].DrawDataP.Valid = false
	end

	if g.DragDropActive and g.DragDropPayload.SourceId == g.ActiveId then
		ImGui.KeepAliveID(g.DragDropPayload.SourceId)
	end

	if not g.IO.ConfigDebugHighlightIdConflicts or not g.IO.KeyCtrl then
		g.DebugDrawIdConflictsId = 0
	end
	if g.IO.ConfigDebugHighlightIdConflicts and g.HoveredIdPreviousFrameItemCount > 1 then
		g.DebugDrawIdConflictsId = g.HoveredIdPreviousFrame
	end

	if g.HoveredIdPreviousFrame == 0 then
		g.HoveredIdTimer = 0.0
	end
	if g.HoveredIdPreviousFrame == 0 or (g.HoveredId ~= 0 and g.ActiveId == g.HoveredId) then
		g.HoveredIdNotActiveTimer = 0.0
	end
	if g.HoveredId ~= 0 then
		g.HoveredIdTimer += g.IO.DeltaTime
	end
	if g.HoveredId ~= 0 and g.ActiveId ~= g.HoveredId then
		g.HoveredIdNotActiveTimer += g.IO.DeltaTime
	end
	g.HoveredIdPreviousFrame = g.HoveredId
	g.HoveredIdPreviousFrameItemCount = 0
	g.HoveredId = 0
	g.HoveredIdAllowOverlap = false
	g.HoveredIdIsDisabled = false

	if g.ActiveId ~= 0 and g.ActiveIdIsAlive ~= g.ActiveId and g.ActiveIdPreviousFrame == g.ActiveId then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventActiveId) then
			ImGui.DebugLog("NewFrame(): ClearActiveID() 0x%08X because it isn't marked alive anymore!\n", g.ActiveId)
		end
		ImGui.ClearActiveID()
	end

	if g.ActiveId ~= 0 then
		g.ActiveIdTimer += g.IO.DeltaTime
	end
	if g.ActiveId ~= 0 and g.ActiveId == g.LastActiveId then
		g.LastActiveIdWasSelected = g.ActiveIdWasSelected
		g.LastActiveIdWasSoleSelected = g.ActiveIdWasSoleSelected
	end
	g.LastActiveIdTimer += g.IO.DeltaTime
	g.ActiveIdPreviousFrame = g.ActiveId
	g.ActiveIdIsAlive = 0
	g.AnyIdHasBeenEditedThisFrame = false
	g.ActiveIdHasBeenEditedThisFrame = false
	g.ActiveIdIsJustActivated = false
	if g.TempInputId ~= 0 and g.ActiveId ~= g.TempInputId then
		g.TempInputId = 0
	end
	if g.InputTextReactivateId ~= 0 and g.InputTextReactivateId ~= g.DeactivatedItemData.ID then
		g.InputTextReactivateId = 0
	end
	if g.ActiveId == 0 then
		g.ActiveIdUsingNavDirMask = 0x00
		g.ActiveIdUsingAllKeyboardKeys = false
	end
	if g.DeactivatedItemData.ElapseFrame < g.FrameCount then
		g.DeactivatedItemData.ID = 0
	end
	g.DeactivatedItemData.IsAlive = false
	if g.InputTextDeactivatedState.ElapseFrame < g.FrameCount then
		g.InputTextDeactivatedState.ID = 0
	end

	if g.HoverItemDelayId ~= 0 and g.MouseStationaryTimer >= g.Style.HoverStationaryDelay then
		g.HoverItemUnlockedStationaryId = g.HoverItemDelayId
	elseif g.HoverItemDelayId == 0 then
		g.HoverItemUnlockedStationaryId = 0
	end
	if g.HoveredWindow ~= nil and g.MouseStationaryTimer >= g.Style.HoverStationaryDelay then
		g.HoverWindowUnlockedStationaryId = g.HoveredWindow.ID
	elseif g.HoveredWindow == nil then
		g.HoverWindowUnlockedStationaryId = 0
	end

	g.HoverItemDelayIdPreviousFrame = g.HoverItemDelayId
	if g.HoverItemDelayId ~= 0 then
		g.HoverItemDelayTimer += g.IO.DeltaTime
		g.HoverItemDelayClearTimer = 0.0
		g.HoverItemDelayId = 0
	elseif g.HoverItemDelayTimer > 0.0 then
		g.HoverItemDelayClearTimer += g.IO.DeltaTime
		if g.HoverItemDelayClearTimer >= ImMax(0.25, g.IO.DeltaTime * 2.0) then
			g.HoverItemDelayTimer = 0.0
			g.HoverItemDelayClearTimer = 0.0
		end
	end

	ImGui.UpdateKeyboardInputs()

	g.DragDropAcceptIdPrev = g.DragDropAcceptIdCurr
	g.DragDropAcceptIdCurr = 0
	g.DragDropAcceptFlagsPrev = g.DragDropAcceptFlagsCurr
	g.DragDropAcceptFlagsCurr = ImGuiDragDropFlags.None
	g.DragDropAcceptIdCurrRectSurface = FLT_MAX
	g.DragDropWithinSource = false
	g.DragDropWithinTarget = false
	g.DragDropHoldJustPressedId = 0
	if g.DragDropActive then
		local owner_id = if g.ActiveId ~= 0 then g.ActiveId else ImHashStr("##DragDropCancelHandler")
		if ImGui.Shortcut(ImGuiKey.Escape, ImGuiInputFlags.RouteGlobal, owner_id) then
			ImGui.ClearActiveID()
			ImGui.ClearDragDrop()
		end
	end
	g.TooltipPreviousWindow = nil

	ImGui.NavUpdate()

	ImGui.UpdateMouseInputs()

	assert(g.WindowsFocusOrder.Size <= g.Windows.Size)
	local gc_all = (g.GcCompactAll or g.IO.ConfigMemoryCompactTimer < 0.0)
	local memory_compact_start_time = if gc_all then FLT_MAX else g.Time - g.IO.ConfigMemoryCompactTimer
	for i = 1, g.Windows.Size do
		local window = g.Windows[i]
		window.WasActive = window.Active
		window.Active = false
		window.WriteAccessed = false
		window.BeginCountPreviousFrame = window.BeginCount
		window.BeginCount = 0

		if (not window.WasActive or gc_all) and not window.MemoryCompacted and window.LastTimeActive < memory_compact_start_time then
			ImGui.GcCompactTransientWindowBuffers(window)
		end
	end

	ImGui.UpdateHoveredWindowAndCaptureFlags(g.IO.MousePos)

	ImGui.UpdateMouseMovingWindowNewFrame()

	if ImGui.GetTopMostPopupModal() ~= nil or (g.NavWindowingTarget ~= nil and g.NavWindowingHighlightAlpha > 0.0) then
		g.DimBgRatio = ImMin(g.DimBgRatio + g.IO.DeltaTime * 6.0, 1.0)
	else
		g.DimBgRatio = ImMax(g.DimBgRatio - g.IO.DeltaTime * 10.0, 0.0)
	end

	g.MouseCursor = ImGuiMouseCursor.Arrow
	g.WantCaptureMouseNextFrame = -1
	g.WantCaptureKeyboardNextFrame = -1
	g.WantTextInputNextFrame = -1

	g.PlatformImeDataPrev = g.PlatformImeData:Copy()
	g.PlatformImeData.WantVisible = false
	g.PlatformImeData.WantTextInput = false

	ImGui.UpdateMouseWheel()

	for i = 0, g.TablesLastTimeActive.Size - 1 do
		if g.TablesLastTimeActive[i + 1] >= 0.0 and g.TablesLastTimeActive[i + 1] < memory_compact_start_time then
			ImGui.TableGcCompactTransientBuffers(g.Tables:GetByIndex(i))
		end
	end
	for i = 1, g.TablesTempData.Size do
		local table_temp_data = g.TablesTempData[i]
		table_temp_data.ReconcileColumnsRequests:clear()
		if table_temp_data.LastTimeActive >= 0.0 and table_temp_data.LastTimeActive < memory_compact_start_time then
			ImGui.TableGcCompactTransientBuffers_TempData(table_temp_data)
		end
	end
	if g.GcCompactAll then
		ImGui.GcCompactTransientMiscBuffers()
	end
	g.GcCompactAll = false

	if g.NavWindow and not g.NavWindow.WasActive then
		ImGui.FocusTopMostWindowUnderOne(nil, nil, nil, ImGuiFocusRequestFlags.RestoreFocusedChild)
	end

	g.CurrentWindowStack:resize(0)
	g.BeginPopupStack:resize(0)
	g.ItemFlagsStack:resize(0)
	g.ItemFlagsStack:push_back(ImGuiItemFlags.Default_)
	g.CurrentItemFlags = g.ItemFlagsStack:back()
	g.GroupStack:resize(0)

	ImGui.UpdateDebugToolItemPicker()
	ImGui.UpdateDebugToolItemPathQuery()
	ImGui.UpdateDebugToolFlashStyleColor()
	if g.DebugLocateFrames > 0 then
		g.DebugLocateFrames -= 1
		if g.DebugLocateFrames == 0 then
			g.DebugLocateId = 0
			g.DebugBreakInLocateId = false
		end
	end
	if g.DebugLogAutoDisableFrames > 0 then
		g.DebugLogAutoDisableFrames -= 1
		if g.DebugLogAutoDisableFrames == 0 then
			ImGui.DebugLog("(Debug Log: Auto-disabled some ImGuiDebugLogFlags after 2 frames)\n")
			g.DebugLogFlags = bit32.band(g.DebugLogFlags, bit32.bnot(g.DebugLogAutoDisableFlags))
			g.DebugLogAutoDisableFlags = ImGuiDebugLogFlags.None
		end
	end

	g.WithinFrameScopeWithImplicitWindow = true
	ImGui.SetNextWindowSize(ImVec2(400, 400), ImGuiCond.FirstUseEver)
	ImGui.Begin("Debug##Default")
	assert(g.CurrentWindow.IsFallbackWindow == true)

	g.ErrorCountCurrentFrame = 0
	ImGui.ErrorRecoveryStoreState(g.StackSizesInNewFrame)

	if g.IO.ConfigDebugBeginReturnValueLoop then
		g.DebugBeginReturnValueCullDepth = if g.DebugBeginReturnValueCullDepth == -1 then 0 else ((g.DebugBeginReturnValueCullDepth + (if (g.FrameCount % 4) == 0 then 1 else 0)) % 10)
	else
		g.DebugBeginReturnValueCullDepth = -1
	end

	ImGui.CallContextHooks(g, ImGuiContextHookType.NewFramePost)
end

function ImGui.ChildWindowComparer(a, b)
	local d = bit32.band(a.Flags, ImGuiWindowFlags.Popup) - bit32.band(b.Flags, ImGuiWindowFlags.Popup)
	if d ~= 0 then
		return d
	end
	d = bit32.band(a.Flags, ImGuiWindowFlags.Tooltip) - bit32.band(b.Flags, ImGuiWindowFlags.Tooltip)
	if d ~= 0 then
		return d
	end
	return a.BeginOrderWithinParent - b.BeginOrderWithinParent
end

function ImGui.AddWindowToSortBuffer(out_sorted_windows, window)
	out_sorted_windows:push_back(window)
	if window.Active then
		local count = window.DC.ChildWindows.Size
		ImQsort(window.DC.ChildWindows, count, ImGui.ChildWindowComparer)
		for i = 0, count - 1 do
			local child = window.DC.ChildWindows[i + 1]
			if child.Active then
				ImGui.AddWindowToSortBuffer(out_sorted_windows, child)
			end
		end
	end
end

function ImGui.AddWindowToDrawData(window, layer)
	local g = ImGui.GImGui
	local viewport = g.Viewports[1]
	g.IO.MetricsRenderWindows += 1
	if window.DrawList._Splitter._Count > 1 then
		window.DrawList:ChannelsMerge()
	end
	ImGui.AddDrawListToDrawDataEx(viewport.DrawDataP, viewport.DrawDataBuilder.Layers[layer + 1], window.DrawList)
	local children = window.DC.ChildWindows
	for i = 1, children.Size do
		local child = children[i]
		if ImGui.IsWindowActiveAndVisible(child) then
			ImGui.AddWindowToDrawData(child, layer)
		end
	end
end

function ImGui.GetWindowDisplayLayer(window)
	return if bit32.btest(window.Flags, ImGuiWindowFlags.Tooltip) then 1 else 0
end

function ImGui.AddRootWindowToDrawData(window)
	ImGui.AddWindowToDrawData(window, ImGui.GetWindowDisplayLayer(window))
end

function ImGui.FlattenDrawDataIntoSingleLayer(builder)
	local layer0 = builder.Layers[1]
	local n = layer0.Size
	local full_size = n
	for i = 1, #builder.Layers - 1 do
		full_size += builder.Layers[i + 1].Size
	end
	layer0:resize(full_size)
	for layer_n = 1, #builder.Layers - 1 do
		local layer = builder.Layers[layer_n + 1]
		if layer:empty() then
			continue
		end
		for i = 1, layer.Size do
			layer0[n + i] = layer[i]
		end
		n += layer.Size
		layer:resize(0)
	end
end

function ImGui.InitViewportDrawData(viewport)
	local g = ImGui.GImGui
	local draw_data = viewport.DrawDataP

	viewport.DrawDataBuilder.Layers[1] = draw_data.CmdLists
	viewport.DrawDataBuilder.Layers[2] = viewport.DrawDataBuilder.LayerData1
	viewport.DrawDataBuilder.Layers[1]:resize(0)
	viewport.DrawDataBuilder.Layers[2]:resize(0)

	draw_data.Valid = true
	draw_data.FrameCount = g.FrameCount
	draw_data.TotalVtxCount = 0
	draw_data.TotalIdxCount = 0
	draw_data.DisplayPos = viewport.Pos
	draw_data.DisplaySize = viewport.Size
	draw_data.FramebufferScale = g.IO.DisplayFramebufferScale
	draw_data.OwnerViewport = viewport
	draw_data.Textures = g.PlatformIO.Textures
end

function ImGui.PushClipRect(clip_rect_min, clip_rect_max, intersect_with_current_clip_rect)
	local window = ImGui.GetCurrentWindow()
	window.DrawList:PushClipRect(clip_rect_min, clip_rect_max, intersect_with_current_clip_rect)
	window.ClipRect = ImRect.fromVec4(window.DrawList._ClipRectStack:back())
end

function ImGui.PopClipRect()
	local window = ImGui.GetCurrentWindow()
	window.DrawList:PopClipRect()
	window.ClipRect = ImRect.fromVec4(window.DrawList._ClipRectStack:back())
end

function ImGui.RenderDimmedBackgroundBehindWindow(window, col)
	if bit32.band(col, IM_COL32_A_MASK) == 0 then
		return
	end

	local viewport = ImGui.GetMainViewport()
	local viewport_rect = viewport:GetMainRect()

	local draw_list = window.RootWindow.DrawList
	if draw_list.CmdBuffer.Size == 0 then
		draw_list:AddDrawCmd()
	end
	draw_list:PushClipRect(viewport_rect.Min - ImVec2(1, 1), viewport_rect.Max + ImVec2(1, 1), false)
	draw_list:AddRectFilled(viewport_rect.Min, viewport_rect.Max, col)
	local cmd = draw_list.CmdBuffer:back()
	assert(cmd.ElemCount == 1)
	draw_list.CmdBuffer:pop_back()
	draw_list.CmdBuffer:push_front(cmd)
	draw_list:AddDrawCmd()
	draw_list:PopClipRect()
end

function ImGui.FindBottomMostVisibleWindowWithinBeginStack(parent_window)
	local g = ImGui.GImGui
	local bottom_most_visible_window = parent_window
	for i = ImGui.FindWindowDisplayIndex(parent_window), 0, -1 do
		local window = g.Windows[i + 1]
		if bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
			continue
		end
		if not ImGui.IsWindowWithinBeginStackOf(window, parent_window) then
			break
		end
		if ImGui.IsWindowActiveAndVisible(window) and ImGui.GetWindowDisplayLayer(window) <= ImGui.GetWindowDisplayLayer(parent_window) then
			bottom_most_visible_window = window
		end
	end
	return bottom_most_visible_window
end

function ImGui.RenderDimmedBackgrounds()
	local g = ImGui.GImGui
	local modal_window = ImGui.GetTopMostAndVisiblePopupModal()
	if g.DimBgRatio <= 0.0 and g.NavWindowingHighlightAlpha <= 0.0 then
		return
	end
	local dim_bg_for_modal = (modal_window ~= nil)
	local dim_bg_for_window_list = (g.NavWindowingTargetAnim ~= nil and g.NavWindowingTargetAnim.Active)
	if not dim_bg_for_modal and not dim_bg_for_window_list then
		return
	end

	if dim_bg_for_modal then
		local dim_behind_window = ImGui.FindBottomMostVisibleWindowWithinBeginStack(modal_window)
		ImGui.RenderDimmedBackgroundBehindWindow(dim_behind_window, ImGui.GetColorU32_U32(modal_window.DC.ModalDimBgColor, g.DimBgRatio))
	elseif dim_bg_for_window_list then
		ImGui.RenderDimmedBackgroundBehindWindow(g.NavWindowingTargetAnim, ImGui.GetColorU32(ImGuiCol.NavWindowingDimBg, g.DimBgRatio))

		local window = g.NavWindowingTargetAnim
		local viewport = ImGui.GetMainViewport()
		local distance = g.FontSize
		local bb = window:Rect()
		bb = bb:Expanded(distance)
		if bb:GetWidth() >= viewport.Size.x and bb:GetHeight() >= viewport.Size.y then
			bb = bb:Expanded(-distance - 1.0)
		end
		if window.DrawList.CmdBuffer.Size == 0 then
			window.DrawList:AddDrawCmd()
		end
		window.DrawList:PushClipRect(viewport.Pos, viewport.Pos + viewport.Size)
		window.DrawList:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.NavWindowingHighlight, g.NavWindowingHighlightAlpha), window.WindowRounding, 3.0)
		window.DrawList:PopClipRect()
	end
end

local function ImeDataEquals(a, b)
	return a.WantVisible == b.WantVisible and a.WantTextInput == b.WantTextInput and a.InputPos == b.InputPos
		and a.InputLineHeight == b.InputLineHeight and a.ViewportId == b.ViewportId
end

function ImGui.EndFrame()
	local g = ImGui.GImGui
	assert(g.Initialized)

	if g.FrameCountEnded == g.FrameCount then
		return
	end
	if not g.WithinFrameScope then
		if ImGui.ErrorLog("Forgot to call ImGui::NewFrame()?") then
			assert(false, "Forgot to call ImGui::NewFrame()?")
		end
		return
	end

	ImGui.CallContextHooks(g, ImGuiContextHookType.EndFramePre)

	if g.IO.ConfigErrorRecovery then
		ImGui.ErrorRecoveryTryToRecoverState(g.StackSizesInNewFrame)
	end
	ImGui.ErrorCheckEndFrameSanityChecks()
	ImGui.ErrorCheckEndFrameFinalizeErrorTooltip()

	local ime_data = g.PlatformImeData
	if g.PlatformIO.Platform_SetImeDataFn ~= nil and not ImeDataEquals(ime_data, g.PlatformImeDataPrev) then
		assert(ime_data.ViewportId == IMGUI_VIEWPORT_DEFAULT_ID)
		local viewport = ImGui.GetMainViewport()
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventIO) then
			ImGui.DebugLog("[io] Calling Platform_SetImeDataFn(): WantVisible: %d, InputPos (%.2f,%.2f) for Viewport 0x%08X\n", if ime_data.WantVisible then 1 else 0, ime_data.InputPos.x, ime_data.InputPos.y, viewport.ID)
		end
		g.PlatformIO.Platform_SetImeDataFn(g, viewport, ime_data)
	end
	g.WantTextInputNextFrame = if ime_data.WantTextInput then 1 else 0

	g.WithinFrameScopeWithImplicitWindow = false
	if g.CurrentWindow and g.CurrentWindow.IsFallbackWindow and g.CurrentWindow.WriteAccessed == false then
		g.CurrentWindow.Active = false
		if g.NavWindow and g.NavWindow.RootWindow == g.CurrentWindow then
			ImGui.FocusWindow(nil)
		end
	end
	ImGui.End()

	ImGui.NavEndFrame()

	if g.DragDropActive then
		local is_delivered = g.DragDropPayload.Delivery
		local is_elapsed = (g.DragDropSourceFrameCount + 1 < g.FrameCount) and (bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.PayloadAutoExpire) or g.DragDropMouseButton == -1 or not ImGui.IsMouseDown(g.DragDropMouseButton))
		if is_delivered or is_elapsed then
			ImGui.ClearDragDrop()
		end
	end

	if g.DragDropActive and g.DragDropSourceFrameCount + 1 < g.FrameCount and not bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceNoPreviewTooltip) then
		g.DragDropWithinSource = true
		ImGui.SetTooltip("...")
		g.DragDropWithinSource = false
	end

	g.WithinFrameScope = false
	g.FrameCountEnded = g.FrameCount
	ImGui.UpdateFontsEndFrame()

	ImGui.UpdateMouseMovingWindowEndFrame()

	g.WindowsTempSortBuffer:resize(0)
	g.WindowsTempSortBuffer:reserve(g.Windows.Size)
	for i = 1, g.Windows.Size do
		local window = g.Windows[i]
		if window.Active and bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
			continue
		end
		ImGui.AddWindowToSortBuffer(g.WindowsTempSortBuffer, window)
	end

	assert(g.Windows.Size == g.WindowsTempSortBuffer.Size)
	g.Windows:swap(g.WindowsTempSortBuffer)
	g.IO.MetricsActiveWindows = g.WindowsActiveCount

	ImGui.UpdateTexturesEndFrame()

	for i = 1, g.FontAtlases.Size do
		g.FontAtlases[i].Locked = false
	end

	g.IO.MousePosPrev = g.IO.MousePos
	g.IO.AppFocusLost = false
	g.IO.MouseWheel = 0.0
	g.IO.MouseWheelH = 0.0
	g.IO.InputQueueCharacters:resize(0)

	ImGui.CallContextHooks(g, ImGuiContextHookType.EndFramePost)
end

function ImGui.Render()
	local g = ImGui.GImGui
	assert(g.Initialized)

	if g.FrameCountEnded ~= g.FrameCount then
		ImGui.EndFrame()
	end
	if g.FrameCountRendered == g.FrameCount then
		return
	end
	g.FrameCountRendered = g.FrameCount

	g.IO.MetricsRenderWindows = 0
	ImGui.CallContextHooks(g, ImGuiContextHookType.RenderPre)

	for i = 1, g.Viewports.Size do
		local viewport = g.Viewports[i]
		ImGui.InitViewportDrawData(viewport)
		if viewport.BgFgDrawLists[1] ~= nil and viewport.BgFgDrawListsLastFrameActive[1] == g.FrameCount then
			ImGui.AddDrawListToDrawDataEx(viewport.DrawDataP, viewport.DrawDataBuilder.Layers[1], ImGui.GetBackgroundDrawList(viewport))
		end
	end

	ImGui.RenderDimmedBackgrounds()

	local top_most_0 = if g.NavWindowingTarget and not bit32.btest(g.NavWindowingTarget.Flags, ImGuiWindowFlags.NoBringToFrontOnFocus) then g.NavWindowingTarget.RootWindow else nil
	local top_most_1 = if g.NavWindowingTarget then g.NavWindowingListWindow else nil
	for i = 1, g.Windows.Size do
		local window = g.Windows[i]
		if ImGui.IsWindowActiveAndVisible(window) and not bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow) and window ~= top_most_0 and window ~= top_most_1 then
			ImGui.AddRootWindowToDrawData(window)
		end
	end
	if top_most_0 and ImGui.IsWindowActiveAndVisible(top_most_0) then
		ImGui.AddRootWindowToDrawData(top_most_0)
	end
	if top_most_1 and ImGui.IsWindowActiveAndVisible(top_most_1) then
		ImGui.AddRootWindowToDrawData(top_most_1)
	end

	if g.IO.MouseDrawCursor and g.MouseCursor ~= ImGuiMouseCursor.None then
		ImGui.RenderMouseCursor(g.IO.MousePos, g.Style.MouseCursorScale, g.MouseCursor, IM_COL32_WHITE, IM_COL32_BLACK, IM_COL32(0, 0, 0, 48))
	end

	g.IO.MetricsRenderVertices = 0
	g.IO.MetricsRenderIndices = 0
	for i = 1, g.Viewports.Size do
		local viewport = g.Viewports[i]
		ImGui.FlattenDrawDataIntoSingleLayer(viewport.DrawDataBuilder)

		if viewport.BgFgDrawLists[2] ~= nil and viewport.BgFgDrawListsLastFrameActive[2] == g.FrameCount then
			ImGui.AddDrawListToDrawDataEx(viewport.DrawDataP, viewport.DrawDataBuilder.Layers[1], ImGui.GetForegroundDrawList(viewport))
		end

		local draw_data = viewport.DrawDataP
		for j = 1, draw_data.CmdLists.Size do
			draw_data.CmdLists[j]:_PopUnusedDrawCmd()
		end
		g.IO.MetricsRenderVertices += draw_data.TotalVtxCount
		g.IO.MetricsRenderIndices += draw_data.TotalIdxCount
	end

	if bit32.btest(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) then
		for i = 1, g.FontAtlases.Size do
			DrawList.ImFontAtlasDebugLogTextureRequests(g.FontAtlases[i])
		end
	end

	ImGui.CallContextHooks(g, ImGuiContextHookType.RenderPost)
end

function ImGui.CalcTextSize(text, text_end, hide_text_after_double_hash, wrap_width)
	if hide_text_after_double_hash == nil then hide_text_after_double_hash = false end
	if wrap_width == nil then wrap_width = -1.0 end
	local g = ImGui.GImGui
	if text_end == nil then text_end = #text + 1 end

	local text_display_end
	if hide_text_after_double_hash then
		text_display_end = ImGui.FindRenderedTextEnd(text, text_end)
	else
		text_display_end = text_end
	end

	local font = g.Font
	local font_size = g.FontSize
	if text_display_end == 1 then
		return ImVec2(0.0, font_size)
	end
	local text_size = font:CalcTextSizeA(font_size, FLT_MAX, wrap_width, text, text_display_end)

	return ImVec2(math.ceil(text_size.x), text_size.y)
end

function ImGui.FindHoveredWindowEx(pos, find_first_and_in_any_viewport, out_hovered_window, out_hovered_window_under_moving_window)
	local g = ImGui.GImGui
	local hovered_window = nil
	local hovered_window_under_moving_window = nil

	if find_first_and_in_any_viewport == false and g.MovingWindow and not bit32.btest(g.MovingWindow.Flags, ImGuiWindowFlags.NoMouseInputs) then
		hovered_window = g.MovingWindow
	end

	local padding_regular = g.Style.TouchExtraPadding
	local padding_for_resize = ImMax(g.Style.TouchExtraPadding, ImVec2(g.Style.WindowBorderHoverPadding, g.Style.WindowBorderHoverPadding))
	for i = g.Windows.Size - 1, 0, -1 do
		local window = g.Windows[i + 1]
		if not window.WasActive or window.Hidden then
			continue
		end
		if bit32.btest(window.Flags, ImGuiWindowFlags.NoMouseInputs) then
			continue
		end

		local hit_padding = if bit32.btest(window.Flags, bit32.bor(ImGuiWindowFlags.NoResize, ImGuiWindowFlags.AlwaysAutoResize)) then padding_regular else padding_for_resize
		if not window.OuterRectClipped:ContainsWithPad(pos, hit_padding) then
			continue
		end

		if window.HitTestHoleSize.x ~= 0 then
			local hole_pos = ImVec2(window.Pos.x + window.HitTestHoleOffset.x, window.Pos.y + window.HitTestHoleOffset.y)
			local hole_size = ImVec2(window.HitTestHoleSize.x, window.HitTestHoleSize.y)
			if ImRect.new(hole_pos, hole_pos + hole_size):Contains(pos) then
				continue
			end
		end

		if find_first_and_in_any_viewport then
			hovered_window = window
			break
		else
			if hovered_window == nil then
				hovered_window = window
			end
			if hovered_window_under_moving_window == nil and (not g.MovingWindow or window.RootWindow ~= g.MovingWindow.RootWindow) then
				hovered_window_under_moving_window = window
			end
			if hovered_window and hovered_window_under_moving_window then
				break
			end
		end
	end

	return hovered_window, hovered_window_under_moving_window
end

function ImGui.IsItemActive()
	local g = ImGui.GImGui
	if g.ActiveId ~= 0 then
		return g.ActiveId == g.LastItemData.ID
	end
	return false
end

function ImGui.IsItemActivated()
	local g = ImGui.GImGui
	if g.ActiveId ~= 0 then
		if g.ActiveId == g.LastItemData.ID and g.ActiveIdPreviousFrame ~= g.LastItemData.ID then
			return true
		end
	end
	return false
end

function ImGui.IsItemDeactivated()
	local g = ImGui.GImGui
	if bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasDeactivated) then
		return bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Deactivated)
	end
	return g.DeactivatedItemData.ID == g.LastItemData.ID and g.LastItemData.ID ~= 0 and g.DeactivatedItemData.ElapseFrame >= g.FrameCount
end

function ImGui.IsItemDeactivatedAfterEdit()
	local g = ImGui.GImGui
	return ImGui.IsItemDeactivated() and g.DeactivatedItemData.HasBeenEditedBefore
end

function ImGui.IsItemFocused()
	local g = ImGui.GImGui
	return g.NavId == g.LastItemData.ID and g.NavId ~= 0
end

function ImGui.IsItemClicked(mouse_button)
	if mouse_button == nil then mouse_button = 0 end
	return ImGui.IsMouseClicked(mouse_button) and ImGui.IsItemHovered(ImGuiHoveredFlags.None)
end

function ImGui.IsItemToggledOpen()
	local g = ImGui.GImGui
	return bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledOpen)
end

function ImGui.IsItemToggledSelection()
	local g = ImGui.GImGui
	assert(g.CurrentMultiSelect ~= nil)
	return bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledSelection)
end

function ImGui.IsAnyItemHovered()
	local g = ImGui.GImGui
	return g.HoveredId ~= 0 or g.HoveredIdPreviousFrame ~= 0
end

function ImGui.IsAnyItemActive()
	local g = ImGui.GImGui
	return g.ActiveId ~= 0
end

function ImGui.IsAnyItemFocused()
	local g = ImGui.GImGui
	return g.NavId ~= 0 and g.NavCursorVisible
end

function ImGui.IsItemVisible()
	local g = ImGui.GImGui
	return bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible)
end

function ImGui.IsItemEdited()
	local g = ImGui.GImGui
	return bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Edited)
end

function ImGui.SetNextItemAllowOverlap()
	local g = ImGui.GImGui
	g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.AllowOverlap)
end

function ImGui.SetActiveIdUsingAllKeyboardKeys()
	local g = ImGui.GImGui
	assert(g.ActiveId ~= 0)
	g.ActiveIdUsingNavDirMask = bit32.lshift(1, ImGuiDir.COUNT) - 1
	g.ActiveIdUsingAllKeyboardKeys = true
	ImGui.NavMoveRequestCancel()
end

function ImGui.GetItemID()
	local g = ImGui.GImGui
	return g.LastItemData.ID
end

function ImGui.GetItemRectMin()
	local g = ImGui.GImGui
	return g.LastItemData.Rect.Min
end

function ImGui.GetItemRectMax()
	local g = ImGui.GImGui
	return g.LastItemData.Rect.Max
end

function ImGui.GetItemRectSize()
	local g = ImGui.GImGui
	return g.LastItemData.Rect:GetSize()
end

function ImGui.GetItemFlags()
	local g = ImGui.GImGui
	return g.LastItemData.ItemFlags
end

function ImGui.BeginChild(str_id_or_id, size_arg, child_flags, window_flags)
	if size_arg == nil then size_arg = ImVec2(0, 0) end
	if child_flags == nil then child_flags = 0 end
	if window_flags == nil then window_flags = 0 end
	if type(str_id_or_id) == "string" then
		local id = ImGui.GetCurrentWindow():GetID(str_id_or_id)
		return ImGui.BeginChildEx(str_id_or_id, id, size_arg, child_flags, window_flags)
	end
	return ImGui.BeginChildEx(nil, str_id_or_id, size_arg, child_flags, window_flags)
end

return true
