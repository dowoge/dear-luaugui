--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local FLT_MAX = Base.FLT_MAX
local ImGuiTypingSelectFlags = Enums.ImGuiTypingSelectFlags
local ImGuiMultiSelectFlags = Enums.ImGuiMultiSelectFlags
local ImGuiSelectionRequestType = Enums.ImGuiSelectionRequestType
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiCol = Enums.ImGuiCol
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiPlotType = Enums.ImGuiPlotType
local ImGuiSelectionBasicStorage = Structs.ImGuiSelectionBasicStorage
local ImGuiSelectionExternalStorage = Structs.ImGuiSelectionExternalStorage

local ImGuiSelectionUserData_Invalid = Enums.ImGuiSelectionUserData.Invalid
local BOX_SELECT_FLAGS = bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)

function ImGui.GetTypingSelectRequest(flags)
	if flags == nil then
		flags = ImGuiTypingSelectFlags.None
	end
	local g = ImGui.GImGui
	local data = g.TypingSelectState
	local out_request = data.Request

	local TYPING_SELECT_RESET_TIMER = 1.80
	local TYPING_SELECT_SINGLE_CHAR_COUNT_FOR_LOCK = 4
	if data.SearchBuffer ~= "" then
		local clear_buffer = false
		clear_buffer = clear_buffer or (g.NavFocusScopeId ~= data.FocusScope)
		clear_buffer = clear_buffer or (data.LastRequestTime + TYPING_SELECT_RESET_TIMER < g.Time)
		clear_buffer = clear_buffer or g.NavAnyRequest
		clear_buffer = clear_buffer or (g.ActiveId ~= 0 and g.NavActivateId == 0)
		clear_buffer = clear_buffer or ImGui.IsKeyPressed(ImGuiKey.Escape) or ImGui.IsKeyPressed(ImGuiKey.Enter)
		clear_buffer = clear_buffer
			or (ImGui.IsKeyPressed(ImGuiKey.Backspace) and bit32.band(flags, ImGuiTypingSelectFlags.AllowBackspace) == 0)
		if clear_buffer then
			data:Clear()
		end
	end

	local buffer_max_len = 64 - 1
	local buffer_len = #data.SearchBuffer
	local select_request = false
	local queue = g.IO.InputQueueCharacters
	for i = 1, queue.Size do
		local w = queue[i]
		local w_buf = Base.ImTextCharToUtf8(w)
		local w_len = #w_buf
		if w < 32 or (buffer_len == 0 and Base.ImCharIsBlankW(w)) or (buffer_len + w_len > buffer_max_len) then
			continue
		end
		if
			data.SingleCharModeLock
			and w_len == out_request.SingleCharSize
			and string.sub(data.SearchBuffer, 1, w_len) == w_buf
		then
			select_request = true
			continue
		end
		if data.SingleCharModeLock then
			data:Clear()
			buffer_len = 0
		end
		data.SearchBuffer = string.sub(data.SearchBuffer, 1, buffer_len) .. w_buf
		buffer_len += w_len
		select_request = true
	end
	queue:resize(0)

	if
		bit32.btest(flags, ImGuiTypingSelectFlags.AllowBackspace)
		and ImGui.IsKeyPressed(ImGuiKey.Backspace, ImGuiInputFlags.Repeat, 0)
	then
		local p = Base.ImTextFindPreviousUtf8Codepoint(data.SearchBuffer, 1, 1 + buffer_len)
		data.SearchBuffer = string.sub(data.SearchBuffer, 1, p - 1)
		buffer_len = p - 1
	end

	if buffer_len == 0 then
		return nil
	end
	if select_request then
		data.FocusScope = g.NavFocusScopeId
		data.LastRequestFrame = g.FrameCount
		data.LastRequestTime = g.Time
	end
	out_request.Flags = flags
	out_request.SearchBufferLen = buffer_len
	out_request.SearchBuffer = data.SearchBuffer
	out_request.SelectRequest = (data.LastRequestFrame == g.FrameCount)
	out_request.SingleCharMode = false
	out_request.SingleCharSize = 0

	if bit32.btest(flags, ImGuiTypingSelectFlags.AllowSingleCharMode) then
		local buf = out_request.SearchBuffer
		local buf_end = 1 + out_request.SearchBufferLen
		local c0_len = Base.ImTextCharFromUtf8(buf, 1, buf_end)
		local c0 = string.sub(buf, 1, c0_len)
		local p = 1 + c0_len
		while p < buf_end do
			if string.sub(buf, p, p + c0_len - 1) ~= c0 then
				break
			end
			p += c0_len
		end
		local single_char_count = if p == buf_end then out_request.SearchBufferLen // c0_len else 0
		out_request.SingleCharMode = (single_char_count > 0 or data.SingleCharModeLock)
		out_request.SingleCharSize = c0_len
		data.SingleCharModeLock = data.SingleCharModeLock
			or (single_char_count >= TYPING_SELECT_SINGLE_CHAR_COUNT_FOR_LOCK)
	end

	return out_request
end

local function ImStrimatchlen(s1, s1_end, s2)
	local match_len = 0
	local i = 1
	while i < s1_end do
		local c1 = string.byte(s1, i) or 0
		local c2 = string.byte(s2, i) or 0
		i += 1
		if Base.ImToUpper(c1) ~= Base.ImToUpper(c2) then
			break
		end
		match_len += 1
	end
	return match_len
end

function ImGui.TypingSelectFindMatch(req, items_count, get_item_name_func, user_data, nav_item_idx)
	if req == nil or req.SelectRequest == false then
		return -1
	end
	local idx = -1
	if req.SingleCharMode and bit32.btest(req.Flags, ImGuiTypingSelectFlags.AllowSingleCharMode) then
		idx = ImGui.TypingSelectFindNextSingleCharMatch(req, items_count, get_item_name_func, user_data, nav_item_idx)
	else
		idx = ImGui.TypingSelectFindBestLeadingMatch(req, items_count, get_item_name_func, user_data)
	end
	if idx ~= -1 then
		ImGui.SetNavCursorVisibleAfterMove()
	end
	return idx
end

function ImGui.TypingSelectFindNextSingleCharMatch(req, items_count, get_item_name_func, user_data, nav_item_idx)
	local first_match_idx = -1
	local return_next_match = false
	for idx = 0, items_count - 1 do
		local item_name = get_item_name_func(user_data, idx)
		if ImStrimatchlen(req.SearchBuffer, 1 + req.SingleCharSize, item_name) < req.SingleCharSize then
			continue
		end
		if return_next_match then
			return idx
		end
		if first_match_idx == -1 and nav_item_idx == -1 then
			return idx
		end
		if first_match_idx == -1 then
			first_match_idx = idx
		end
		if nav_item_idx == idx then
			return_next_match = true
		end
	end
	return first_match_idx
end

function ImGui.TypingSelectFindBestLeadingMatch(req, items_count, get_item_name_func, user_data)
	local longest_match_idx = -1
	local longest_match_len = 0
	for idx = 0, items_count - 1 do
		local item_name = get_item_name_func(user_data, idx)
		local match_len = ImStrimatchlen(req.SearchBuffer, 1 + req.SearchBufferLen, item_name)
		if match_len <= longest_match_len then
			continue
		end
		longest_match_idx = idx
		longest_match_len = match_len
		if match_len == req.SearchBufferLen then
			break
		end
	end
	return longest_match_idx
end

function ImGui.DebugNodeTypingSelectState(data)
	ImGui.Text('SearchBuffer = "%s"', data.SearchBuffer)
	ImGui.Text(
		"SingleCharMode = %d, Size = %d, Lock = %d",
		data.Request.SingleCharMode and 1 or 0,
		data.Request.SingleCharSize,
		data.SingleCharModeLock and 1 or 0
	)
	ImGui.Text("LastRequest = time: %.2f, frame: %d", data.LastRequestTime, data.LastRequestFrame)
end

function ImGui.BoxSelectPreStartDrag(id, clicked_item)
	local g = ImGui.GImGui
	local bs = g.BoxSelectState
	bs.ID = id
	bs.IsStarting = true
	bs.IsStartedFromVoid = (clicked_item == ImGuiSelectionUserData_Invalid)
	bs.IsStartedSetNavIdOnce = bs.IsStartedFromVoid
	bs.KeyMods = g.IO.KeyMods
	bs.StartPosRel = ImGui.WindowPosAbsToRel(g.CurrentWindow, g.IO.MousePos)
	bs.EndPosRel = bs.StartPosRel
	bs.ScrollAccum = ImVec2(0.0, 0.0)
end

function ImGui.BoxSelectActivateDrag(bs, window)
	local g = ImGui.GImGui
	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
		ImGui.DebugLog("[selection] BeginBoxSelect() 0X%08X: Activate\n", bs.ID)
	end
	bs.IsActive = true
	bs.Window = window
	bs.IsStarting = false
	ImGui.SetActiveID(bs.ID, window)
	ImGui.SetActiveIdUsingAllKeyboardKeys()
	if bs.IsStartedFromVoid and bit32.band(bs.KeyMods, bit32.bor(ImGuiMod.Ctrl, ImGuiMod.Shift)) == 0 then
		bs.RequestClear = true
	end
end

function ImGui.BoxSelectDeactivateDrag(bs)
	local g = ImGui.GImGui
	bs.IsActive = false
	bs.IsStarting = false
	if g.ActiveId == bs.ID then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
			ImGui.DebugLog("[selection] BeginBoxSelect() 0X%08X: Deactivate\n", bs.ID)
		end
		ImGui.ClearActiveID()
	end
	bs.ID = 0
end

function ImGui.BoxSelectScrollWithMouseDrag(bs, window, inner_r)
	local g = ImGui.GImGui
	assert(bs.Window == window)
	for n = 0, 1 do
		local mouse_pos = if n == 0 then g.IO.MousePos.x else g.IO.MousePos.y
		local r_max = if n == 0 then inner_r.Max.x else inner_r.Max.y
		local r_min = if n == 0 then inner_r.Min.x else inner_r.Min.y
		local dist = if mouse_pos > r_max then mouse_pos - r_max elseif mouse_pos < r_min then mouse_pos - r_min else 0.0
		local scroll_curr = if n == 0 then window.Scroll.x else window.Scroll.y
		local scroll_max = if n == 0 then window.ScrollMax.x else window.ScrollMax.y
		if dist == 0.0 or (dist < 0.0 and scroll_curr < 0.0) or (dist > 0.0 and scroll_curr >= scroll_max) then
			continue
		end

		local speed_multiplier = Base.ImLinearRemapClamp(g.FontSize, g.FontSize * 5.0, 1.0, 4.0, Base.ImAbs(dist))
		local scroll_step = g.FontSize * 35.0 * speed_multiplier * Base.ImSign(dist) * g.IO.DeltaTime
		local accum = (if n == 0 then bs.ScrollAccum.x else bs.ScrollAccum.y) + scroll_step
		bs.ScrollAccum = if n == 0 then ImVec2(accum, bs.ScrollAccum.y) else ImVec2(bs.ScrollAccum.x, accum)

		local scroll_step_i = Base.ImFloor(accum)
		if scroll_step_i == 0.0 then
			continue
		end
		if n == 0 then
			ImGui.SetScrollX(window, scroll_curr + scroll_step_i)
		else
			ImGui.SetScrollY(window, scroll_curr + scroll_step_i)
		end
		accum -= scroll_step_i
		bs.ScrollAccum = if n == 0 then ImVec2(accum, bs.ScrollAccum.y) else ImVec2(bs.ScrollAccum.x, accum)
	end
end

local function RectAddX(r, x)
	return ImRect.fromXY(math.min(r.Min.x, x), r.Min.y, math.max(r.Max.x, x), r.Max.y)
end

local function RectAddY(r, y)
	return ImRect.fromXY(r.Min.x, math.min(r.Min.y, y), r.Max.x, math.max(r.Max.y, y))
end

function ImGui.BeginBoxSelect(scope_rect, window, box_select_id, ms_flags)
	local g = ImGui.GImGui
	local bs = g.BoxSelectState
	ImGui.KeepAliveID(box_select_id)
	if bs.ID ~= box_select_id then
		return false
	end

	bs.UnclipMode = false
	bs.RequestClear = false
	if bs.IsStarting and ImGui.IsMouseDragPastThreshold(0) then
		ImGui.BoxSelectActivateDrag(bs, window)
	elseif (bs.IsStarting or bs.IsActive) and g.IO.MouseDown[1] == false then
		ImGui.BoxSelectDeactivateDrag(bs)
	end
	if not bs.IsActive then
		return false
	end

	local start_pos_abs = ImGui.WindowPosRelToAbs(window, bs.StartPosRel)
	local prev_end_pos_abs = ImGui.WindowPosRelToAbs(window, bs.EndPosRel)
	local curr_end_pos_abs = g.IO.MousePos
	if bit32.btest(ms_flags, ImGuiMultiSelectFlags.ScopeWindow) then
		curr_end_pos_abs = ImClamp(curr_end_pos_abs, scope_rect.Min, scope_rect.Max)
	end
	bs.BoxSelectRectPrev = ImRect.new(ImMin(start_pos_abs, prev_end_pos_abs), ImMax(start_pos_abs, prev_end_pos_abs))
	bs.BoxSelectRectCurr = ImRect.new(ImMin(start_pos_abs, curr_end_pos_abs), ImMax(start_pos_abs, curr_end_pos_abs))

	if bit32.btest(ms_flags, BOX_SELECT_FLAGS) then
		local inverted = ImRect.fromXY(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
		local unclip0, unclip1 = inverted, inverted
		local curr, prev = bs.BoxSelectRectCurr, bs.BoxSelectRectPrev
		for side = 0, 1 do
			local d_min = if side == 0 then ImMin(curr.Min, prev.Min) else ImMin(curr.Max, prev.Max)
			local d_max = if side == 0 then ImMax(curr.Min, prev.Min) else ImMax(curr.Max, prev.Max)
			if d_min.x ~= d_max.x then
				unclip0 = RectAddX(unclip0, d_min.x)
				unclip0 = RectAddX(unclip0, d_max.x)
			end
			if d_min.y ~= d_max.y then
				unclip1 = RectAddY(unclip1, d_min.y)
				unclip1 = RectAddY(unclip1, d_max.y)
			end
		end

		local box_select_intersection = prev:Added(curr)
		if bit32.btest(ms_flags, ImGuiMultiSelectFlags.BoxSelect2d) then
			if prev.Min.x ~= curr.Min.x or prev.Max.x ~= curr.Max.x then
				unclip0 = RectAddY(unclip0, box_select_intersection.Min.y)
				unclip0 = RectAddY(unclip0, box_select_intersection.Max.y)
			end
		end
		if bit32.btest(ms_flags, BOX_SELECT_FLAGS) then
			if prev.Min.y ~= curr.Min.y or prev.Max.y ~= curr.Max.y then
				unclip1 = RectAddX(unclip1, box_select_intersection.Min.x)
				unclip1 = RectAddX(unclip1, box_select_intersection.Max.x)
			end
		end
		bs.UnclipRects[1] = unclip0
		bs.UnclipRects[2] = unclip1

		bs.UnclipRect = unclip0:Added(unclip1)
		if
			not bs.UnclipRect:IsInverted()
			and (not window.ClipRect:Contains(bs.UnclipRect.Min) or not window.ClipRect:Contains(bs.UnclipRect.Max))
		then
			bs.UnclipMode = true
		end
		if bs.UnclipMode and g.CurrentTable ~= nil then
			ImGui.TableApplyExternalUnclipRect(g.CurrentTable, bs.UnclipRect)
		end
	end

	return true
end

function ImGui.EndBoxSelect(scope_rect, ms_flags)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local bs = g.BoxSelectState
	assert(bs.IsActive)
	bs.UnclipMode = false

	bs.EndPosRel = ImGui.WindowPosAbsToRel(window, ImClamp(g.IO.MousePos, scope_rect.Min, scope_rect.Max))
	local box_select_r = bs.BoxSelectRectCurr:ClippedWith(scope_rect)
	local draw_window = ImGui.FindFrontMostVisibleChildWindow(window)
	draw_window.DrawList:AddRectFilled(
		box_select_r.Min,
		box_select_r.Max,
		ImGui.GetColorU32(ImGuiCol.SeparatorHovered, 0.30)
	)
	draw_window.DrawList:AddRect(box_select_r.Min, box_select_r.Max, ImGui.GetColorU32(ImGuiCol.NavCursor))

	local enable_scroll = bit32.btest(ms_flags, ImGuiMultiSelectFlags.ScopeWindow)
		and bit32.band(ms_flags, ImGuiMultiSelectFlags.BoxSelectNoScroll) == 0
	if enable_scroll then
		local scroll_r = scope_rect:Expanded(-g.FontSize)
		if not scroll_r:Contains(g.IO.MousePos) then
			ImGui.BoxSelectScrollWithMouseDrag(bs, window, scroll_r)
		end
	end
end

function ImGui.GetBoxSelectState(id)
	local g = ImGui.GImGui
	if id ~= 0 and g.BoxSelectState.ID == id and g.BoxSelectState.IsActive then
		return g.BoxSelectState
	end
	return nil
end

function ImGui.GetMultiSelectState(id)
	local g = ImGui.GImGui
	return g.MultiSelectStorage:GetByKey(id)
end

function ImGui.DebugLogMultiSelectRequests(func, io)
	local g = ImGui.GImGui
	local requests = io.Requests
	for i = 1, requests.Size do
		local req = requests[i]
		if req.Type == ImGuiSelectionRequestType.SetAll then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
				ImGui.DebugLog(
					"[selection] %s: Request: SetAll %d (= %s)\n",
					func,
					req.Selected and 1 or 0,
					if req.Selected then "SelectAll" else "Clear"
				)
			end
		end
		if req.Type == ImGuiSelectionRequestType.SetRange then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
				ImGui.DebugLog(
					"[selection] %s: Request: SetRange %d..%d (0x%X..0x%X) = %d (dir %d)\n",
					func,
					req.RangeFirstItem,
					req.RangeLastItem,
					req.RangeFirstItem,
					req.RangeLastItem,
					req.Selected and 1 or 0,
					req.RangeDirection
				)
			end
		end
	end
end

function ImGui.CalcScopeRect(ms, window)
	if bit32.btest(ms.Flags, ImGuiMultiSelectFlags.ScopeRect) then
		return ImRect.new(ms.ScopeRectMin, ImMax(window.DC.CursorMaxPos, ms.ScopeRectMin))
	else
		local scope_rect = window.InnerClipRect
		scope_rect =
			scope_rect:WithMin(ImMin(scope_rect.Min + ImVec2(window.DecoInnerSizeX1, window.DecoInnerSizeY1), scope_rect.Max))
		return scope_rect
	end
end

function ImGui.BeginMultiSelect(flags, selection_size, items_count)
	if selection_size == nil then
		selection_size = -1
	end
	if items_count == nil then
		items_count = -1
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	g.MultiSelectTempDataStacked += 1
	while g.MultiSelectTempData.Size < g.MultiSelectTempDataStacked do
		g.MultiSelectTempData:push_back(Structs.ImGuiMultiSelectTempData.new())
	end
	local ms = g.MultiSelectTempData[g.MultiSelectTempDataStacked]
	g.CurrentMultiSelect = ms
	if bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.ScopeWindow, ImGuiMultiSelectFlags.ScopeRect)) == 0 then
		flags = bit32.bor(flags, ImGuiMultiSelectFlags.ScopeWindow)
	end
	if bit32.btest(flags, ImGuiMultiSelectFlags.SingleSelect) then
		flags = bit32.band(flags, bit32.bnot(BOX_SELECT_FLAGS))
	end
	if bit32.btest(flags, ImGuiMultiSelectFlags.BoxSelect2d) then
		flags = bit32.band(flags, bit32.bnot(ImGuiMultiSelectFlags.BoxSelect1d))
	end

	local table = g.CurrentTable
	if table then
		if not table.IsLayoutLocked then
			ImGui.TableUpdateLayout(table)
		elseif table.CurrentColumn ~= -1 then
			ImGui.TableEndCell(table)
		end
	end

	local id = window.IDStack:back()
	ms:Clear()
	ms.FocusScopeId = id
	ms.Flags = flags
	ms.BackupCursorMaxPos = window.DC.CursorMaxPos
	ms.ScopeRectMin = window.DC.CursorPos
	if bit32.btest(flags, ImGuiMultiSelectFlags.ScopeRect) then
		window.DC.CursorMaxPos = ms.ScopeRectMin
	end
	ImGui.PushFocusScope(ms.FocusScopeId)
	ms.IsFocused = ImGui.IsInNavFocusRoute(g.CurrentFocusScopeId)
	if bit32.btest(flags, ImGuiMultiSelectFlags.ScopeWindow) then
		window.DC.NavLayersActiveMask = bit32.bor(window.DC.NavLayersActiveMask, bit32.lshift(1, ImGuiNavLayer.Main))
	end

	if g.NavJustMovedToId ~= 0 then
		ms.KeyMods = if g.NavJustMovedToIsTabbing then 0 else g.NavJustMovedToKeyMods
	else
		ms.KeyMods = g.IO.KeyMods
	end
	if bit32.btest(flags, ImGuiMultiSelectFlags.NoRangeSelect) then
		ms.KeyMods = bit32.band(ms.KeyMods, bit32.bnot(ImGuiMod.Shift))
	end

	local storage = g.MultiSelectStorage:GetOrAddByKey(id)
	storage.ID = id
	storage.LastFrameActive = g.FrameCount
	storage.LastSelectionSize = selection_size
	storage.Window = window
	ms.Storage = storage

	ms.IO.Requests:resize(0)
	ms.IO.RangeSrcItem = storage.RangeSrcItem
	ms.IO.NavIdItem = storage.NavIdItem
	ms.IO.NavIdSelected = (storage.NavIdSelected == 1)
	ms.IO.ItemsCount = items_count

	local ctrl_shift = bit32.bor(ImGuiMod.Ctrl, ImGuiMod.Shift)
	local no_auto = bit32.bor(ImGuiMultiSelectFlags.NoAutoClear, ImGuiMultiSelectFlags.NoAutoSelect)
	local request_clear = false
	local request_select_all = false
	if g.NavJustMovedToId ~= 0 and g.NavJustMovedToFocusScopeId == ms.FocusScopeId and g.NavJustMovedToHasSelectionData then
		if bit32.btest(ms.KeyMods, ImGuiMod.Shift) then
			ms.IsKeyboardSetRange = true
		end
		if ms.IsKeyboardSetRange then
			assert(storage.RangeSrcItem ~= ImGuiSelectionUserData_Invalid)
		end
		if bit32.band(ms.KeyMods, ctrl_shift) == 0 and bit32.band(flags, no_auto) == 0 then
			request_clear = true
		end
	elseif g.NavJustMovedFromFocusScopeId == ms.FocusScopeId then
		if bit32.band(ms.KeyMods, ctrl_shift) == 0 and bit32.band(flags, no_auto) == 0 then
			request_clear = true
		end
	end

	local bs = g.BoxSelectState
	if bit32.btest(flags, BOX_SELECT_FLAGS) then
		ms.BoxSelectId = ImGui.GetID("##BoxSelect")
		if ImGui.BeginBoxSelect(ImGui.CalcScopeRect(ms, window), window, ms.BoxSelectId, flags) then
			request_clear = request_clear or bs.RequestClear
		end
	end

	if ms.IsFocused then
		if bit32.btest(flags, ImGuiMultiSelectFlags.ClearOnEscape) then
			if selection_size ~= 0 or bs.IsActive then
				if ImGui.Shortcut(ImGuiKey.Escape, ImGuiInputFlags.None, if bs.IsActive then bs.ID else 0) then
					request_clear = true
					if bs.IsActive then
						ImGui.BoxSelectDeactivateDrag(bs)
					end
				end
			end
		end

		if
			not bit32.btest(flags, ImGuiMultiSelectFlags.SingleSelect)
			and not bit32.btest(flags, ImGuiMultiSelectFlags.NoSelectAll)
		then
			if ImGui.Shortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.A)) then
				request_select_all = true
			end
		end
	end

	if request_clear or request_select_all then
		ImGui.MultiSelectAddSetAll(ms, request_select_all)
		if not request_select_all then
			storage.LastSelectionSize = 0
		end
	end
	ms.LoopRequestSetAll = if request_select_all then 1 elseif request_clear then 0 else -1
	ms.IsSoleOrUnknownSelectionSize = (storage.LastSelectionSize == 1) or (storage.LastSelectionSize == -1)

	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
		ImGui.DebugLogMultiSelectRequests("BeginMultiSelect", ms.IO)
	end

	return ms.IO
end

function ImGui.EndMultiSelect()
	local g = ImGui.GImGui
	local ms = g.CurrentMultiSelect
	local storage = ms.Storage
	local window = g.CurrentWindow
	if not (ms.FocusScopeId == g.CurrentFocusScopeId) then
		if ImGui.ErrorLog("EndMultiSelect() FocusScope mismatch!") then
			assert(ms.FocusScopeId == g.CurrentFocusScopeId, "EndMultiSelect() FocusScope mismatch!")
		end
	end
	assert(g.CurrentMultiSelect ~= nil and storage.Window == g.CurrentWindow)
	assert(
		g.MultiSelectTempDataStacked > 0
			and g.MultiSelectTempData[g.MultiSelectTempDataStacked] == g.CurrentMultiSelect
	)

	local scope_rect = ImGui.CalcScopeRect(ms, window)
	if ms.IsFocused then
		if ms.IO.RangeSrcReset or (ms.RangeSrcPassedBy == false and ms.IO.RangeSrcItem ~= ImGuiSelectionUserData_Invalid) then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
				ImGui.DebugLog("[selection] EndMultiSelect: Reset RangeSrcItem.\n")
			end
			storage.RangeSrcItem = ImGuiSelectionUserData_Invalid
		end
		if ms.NavIdPassedBy == false and storage.NavIdItem ~= ImGuiSelectionUserData_Invalid then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
				ImGui.DebugLog("[selection] EndMultiSelect: Reset NavIdItem.\n")
			end
			storage.NavIdItem = ImGuiSelectionUserData_Invalid
			storage.NavIdSelected = -1
		end

		if bit32.btest(ms.Flags, BOX_SELECT_FLAGS) and ImGui.GetBoxSelectState(ms.BoxSelectId) then
			ImGui.EndBoxSelect(scope_rect, ms.Flags)
		end
	end

	if ms.IsEndIO == false then
		ms.IO.Requests:resize(0)
	end

	local scope_hovered = window.InnerRect:Contains(g.IO.MousePos)
		and ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)
	if scope_hovered and bit32.btest(ms.Flags, ImGuiMultiSelectFlags.ScopeRect) then
		scope_hovered = scope_hovered and scope_rect:Contains(g.IO.MousePos)
	end
	if scope_hovered and g.HoveredId == 0 and g.ActiveId == 0 then
		if bit32.btest(ms.Flags, BOX_SELECT_FLAGS) then
			if not g.BoxSelectState.IsActive and not g.BoxSelectState.IsStarting and g.IO.MouseClickedCount[1] == 1 then
				ImGui.BoxSelectPreStartDrag(ms.BoxSelectId, ImGuiSelectionUserData_Invalid)
				ImGui.FocusWindow(window, ImGuiFocusRequestFlags.UnlessBelowModal)
				ImGui.SetHoveredID(ms.BoxSelectId)
				if bit32.btest(ms.Flags, ImGuiMultiSelectFlags.ScopeRect) then
					ImGui.SetNavID(0, ImGuiNavLayer.Main, ms.FocusScopeId, ImRect.new(g.IO.MousePos, g.IO.MousePos))
				end
			end
		end

		if bit32.btest(ms.Flags, ImGuiMultiSelectFlags.ClearOnClickVoid) then
			if ImGui.IsMouseReleased(0) and ImGui.IsMouseDragPastThreshold(0) == false and g.IO.KeyMods == ImGuiMod.None then
				ImGui.MultiSelectAddSetAll(ms, false)
			end
		end
	end

	if bit32.btest(ms.Flags, ImGuiMultiSelectFlags.NavWrapX) then
		assert(bit32.btest(ms.Flags, ImGuiMultiSelectFlags.ScopeWindow))
		ImGui.NavMoveRequestTryWrapping(ImGui.GetCurrentWindow(), ImGuiNavMoveFlags.WrapX)
	end

	local table = g.CurrentTable
	if table then
		if table.IsInsideRow then
			ImGui.TableEndRow(table)
		end
	end
	window.DC.CursorMaxPos = ImMax(ms.BackupCursorMaxPos, window.DC.CursorMaxPos)
	ImGui.PopFocusScope()

	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) then
		ImGui.DebugLogMultiSelectRequests("EndMultiSelect", ms.IO)
	end

	ms.FocusScopeId = 0
	ms.Flags = ImGuiMultiSelectFlags.None
	g.MultiSelectTempDataStacked -= 1
	g.CurrentMultiSelect = if g.MultiSelectTempDataStacked > 0
		then g.MultiSelectTempData[g.MultiSelectTempDataStacked]
		else nil

	return ms.IO
end

function ImGui.SetNextItemSelectionUserData(selection_user_data)
	local g = ImGui.GImGui
	g.NextItemData.SelectionUserData = selection_user_data
	g.NextItemData.FocusScopeId = g.CurrentFocusScopeId

	local ms = g.CurrentMultiSelect
	if ms then
		g.NextItemData.ItemFlagsSet = bit32.bor(
			g.NextItemData.ItemFlagsSet,
			ImGuiItemFlags.HasSelectionUserData,
			ImGuiItemFlags.IsMultiSelect
		)
		if ms.IO.RangeSrcItem == selection_user_data then
			ms.RangeSrcPassedBy = true
		end
	else
		g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.HasSelectionUserData)
	end
end

function ImGui.MultiSelectItemHeader(id, p_selected, p_button_flags)
	local g = ImGui.GImGui
	local ms = g.CurrentMultiSelect

	local selected = p_selected
	if ms.IsFocused then
		local storage = ms.Storage
		local item_data = g.NextItemData.SelectionUserData
		assert(
			g.NextItemData.FocusScopeId == g.CurrentFocusScopeId,
			"Forgot to call SetNextItemSelectionUserData() prior to item, required in BeginMultiSelect()/EndMultiSelect() scope"
		)

		if ms.LoopRequestSetAll ~= -1 then
			selected = (ms.LoopRequestSetAll == 1)
		end

		if ms.IsKeyboardSetRange then
			assert(id ~= 0 and bit32.btest(ms.KeyMods, ImGuiMod.Shift))
			local is_range_dst = (ms.RangeDstPassedBy == false) and g.NavJustMovedToId == id
			if is_range_dst then
				ms.RangeDstPassedBy = true
			end
			if is_range_dst and storage.RangeSrcItem == ImGuiSelectionUserData_Invalid then
				storage.RangeSrcItem = item_data
				storage.RangeSelected = if selected then 1 else 0
			end
			local is_range_src = storage.RangeSrcItem == item_data
			if is_range_src or is_range_dst or ms.RangeSrcPassedBy ~= ms.RangeDstPassedBy then
				assert(storage.RangeSrcItem ~= ImGuiSelectionUserData_Invalid and storage.RangeSelected ~= -1)
				selected = (storage.RangeSelected ~= 0)
			elseif
				bit32.band(ms.KeyMods, ImGuiMod.Ctrl) == 0
				and bit32.band(ms.Flags, ImGuiMultiSelectFlags.NoAutoClear) == 0
			then
				selected = false
			end
		end
		p_selected = selected
	end

	if p_button_flags ~= nil then
		local button_flags = p_button_flags
		button_flags = bit32.bor(button_flags, ImGuiButtonFlags.NoHoveredOnFocus)
		button_flags = bit32.band(
			button_flags,
			bit32.bnot(bit32.bor(ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.PressedOnClickRelease))
		)
		if bit32.btest(ms.Flags, ImGuiMultiSelectFlags.SelectOnClickAlways) then
			button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClick)
		elseif bit32.btest(ms.Flags, ImGuiMultiSelectFlags.SelectOnClickRelease) then
			button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease)
		else
			button_flags = bit32.bor(
				button_flags,
				if not selected or (g.ActiveId == id and g.ActiveIdHasBeenPressedBefore)
					then ImGuiButtonFlags.PressedOnClick
					else ImGuiButtonFlags.PressedOnClickRelease
			)
		end
		p_button_flags = button_flags
	end
	return p_selected, p_button_flags
end

function ImGui.MultiSelectItemFooter(id, p_selected, p_pressed, extra_flags)
	if extra_flags == nil then
		extra_flags = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local selected = p_selected
	local pressed = p_pressed
	local ms = g.CurrentMultiSelect
	local storage = ms.Storage
	if pressed then
		ms.IsFocused = true
	end

	local hovered = false
	if bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) then
		hovered = ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)
	end
	if not ms.IsFocused and not hovered then
		return p_selected, p_pressed
	end

	local item_data = g.NextItemData.SelectionUserData

	local flags = bit32.bor(ms.Flags, extra_flags)
	local is_singleselect = bit32.btest(flags, ImGuiMultiSelectFlags.SingleSelect)
	local is_ctrl = bit32.btest(ms.KeyMods, ImGuiMod.Ctrl)
	local is_shift = bit32.btest(ms.KeyMods, ImGuiMod.Shift)

	local apply_to_range_src = false

	if g.NavId == id and storage.RangeSrcItem == ImGuiSelectionUserData_Invalid then
		apply_to_range_src = true
	end
	if ms.IsEndIO == false then
		ms.IO.Requests:resize(0)
		ms.IsEndIO = true
	end

	if g.NavJustMovedToId == id then
		if bit32.band(flags, ImGuiMultiSelectFlags.NoAutoSelect) == 0 then
			if is_ctrl and is_shift then
				pressed = true
			elseif not is_ctrl then
				selected = true
				pressed = true
			end
		else
			if is_shift then
				pressed = true
			elseif not is_ctrl then
				apply_to_range_src = true
			end
		end
	end

	if apply_to_range_src then
		storage.RangeSrcItem = item_data
		storage.RangeSelected = if selected then 1 else 0
	end

	if ms.BoxSelectId ~= 0 then
		local bs = ImGui.GetBoxSelectState(ms.BoxSelectId)
		if bs then
			local item_rect = g.LastItemData.Rect
			if not window.DC.NavIsScrollPushableX then
				local table = g.CurrentTable
				if table then
					if table.CurrentColumn ~= -1 then
						local column = table.Columns[table.CurrentColumn + 1]
						local has_clip_rect = bit32.btest(g.LastItemData.ItemFlags, ImGuiItemStatusFlags.HasClipRect)
						local clip_min_x = if has_clip_rect then g.LastItemData.ClipRect.Min.x else window.ClipRect.Min.x
						local clip_max_x = if has_clip_rect then g.LastItemData.ClipRect.Max.x else window.ClipRect.Max.x
						if clip_min_x ~= clip_max_x then
							item_rect = item_rect:WithMinX(ImMax(item_rect.Min.x, ImMin(column.MinX, clip_min_x)))
							item_rect = item_rect:WithMaxX(ImMin(item_rect.Max.x, ImMax(column.MaxX, clip_max_x)))
						else
							item_rect = item_rect:WithMinX(ImMax(item_rect.Min.x, column.MinX))
							item_rect = item_rect:WithMaxX(ImMin(item_rect.Max.x, column.MaxX))
						end
					end
				end
			end
			local rect_overlap_curr = bs.BoxSelectRectCurr:Overlaps(item_rect)
			local rect_overlap_prev = bs.BoxSelectRectPrev:Overlaps(item_rect)
			if (rect_overlap_curr and not rect_overlap_prev and not selected) or (rect_overlap_prev and not rect_overlap_curr) then
				if storage.LastSelectionSize <= 0 and bs.IsStartedSetNavIdOnce then
					pressed = true
					bs.IsStartedSetNavIdOnce = false
				else
					selected = not selected
					ImGui.MultiSelectAddSetRange(ms, selected, 1, item_data, item_data)
				end
				storage.LastSelectionSize = ImMax(storage.LastSelectionSize + 1, 1)
			end
		end
	end

	if
		hovered
		and ImGui.IsMouseClicked(1)
		and bit32.band(
				flags,
				bit32.bor(ImGuiMultiSelectFlags.NoAutoSelect, ImGuiMultiSelectFlags.NoSelectOnRightClick)
			)
			== 0
	then
		if g.ActiveId ~= 0 and g.ActiveId ~= id then
			ImGui.ClearActiveID()
		end
		ImGui.SetFocusID(id, window)
		if not pressed and not selected then
			pressed = true
			is_ctrl = false
			is_shift = false
		end
	end

	local enter_pressed = pressed
		and (g.NavActivateId == id)
		and bit32.btest(g.NavActivateFlags, ImGuiActivateFlags.PreferInput)

	if pressed and (not enter_pressed or not selected) then
		local input_source = if g.NavJustMovedToId == id or g.NavActivateId == id
			then g.NavInputSource
			else ImGuiInputSource.Mouse
		if bit32.btest(flags, BOX_SELECT_FLAGS) then
			if
				not g.BoxSelectState.IsActive
				and not g.BoxSelectState.IsStarting
				and input_source == ImGuiInputSource.Mouse
				and g.IO.MouseClickedCount[1] == 1
			then
				ImGui.BoxSelectPreStartDrag(ms.BoxSelectId, item_data)
			end
		end

		if bit32.band(flags, ImGuiMultiSelectFlags.NoAutoClear) == 0 then
			local request_clear = false
			if is_singleselect then
				request_clear = true
			elseif (input_source == ImGuiInputSource.Mouse or g.NavActivateId == id) and not is_ctrl then
				request_clear = if bit32.btest(flags, ImGuiMultiSelectFlags.NoAutoClearOnReselect)
					then not selected
					else true
			elseif
				(input_source == ImGuiInputSource.Keyboard or input_source == ImGuiInputSource.Gamepad)
				and is_shift
				and not is_ctrl
			then
				request_clear = true
			end
			if request_clear then
				ImGui.MultiSelectAddSetAll(ms, false)
			end
		end

		local range_direction
		local range_selected
		if is_shift and not is_singleselect then
			if storage.RangeSrcItem == ImGuiSelectionUserData_Invalid then
				storage.RangeSrcItem = item_data
			end
			if bit32.band(flags, ImGuiMultiSelectFlags.CheckboxMode_) == 0 then
				range_selected = if is_ctrl and storage.RangeSelected ~= -1 then (storage.RangeSelected ~= 0) else true
			else
				if ms.IsKeyboardSetRange then
					range_selected = if storage.RangeSelected ~= -1 then (storage.RangeSelected ~= 0) else true
				else
					range_selected = not selected
				end
			end
			range_direction = if ms.RangeSrcPassedBy then 1 else -1
		else
			if bit32.band(flags, ImGuiMultiSelectFlags.CheckboxMode_) == 0 then
				selected = if is_ctrl then not selected else true
			else
				selected = not selected
			end
			storage.RangeSrcItem = item_data
			range_selected = selected
			range_direction = 1
		end
		ImGui.MultiSelectAddSetRange(ms, range_selected, range_direction, storage.RangeSrcItem, item_data)
	end

	if storage.RangeSrcItem == item_data then
		storage.RangeSelected = if selected then 1 else 0
	end

	if g.NavId == id then
		storage.NavIdItem = item_data
		storage.NavIdSelected = if selected then 1 else 0
	end
	if storage.NavIdItem == item_data then
		ms.NavIdPassedBy = true
	end

	return selected, pressed
end

function ImGui.MultiSelectAddSetAll(ms, selected)
	local req = Structs.ImGuiSelectionRequest.new(
		ImGuiSelectionRequestType.SetAll,
		selected,
		0,
		ImGuiSelectionUserData_Invalid,
		ImGuiSelectionUserData_Invalid
	)
	ms.IO.Requests:resize(0)
	ms.IO.Requests:push_back(req)
end

function ImGui.MultiSelectAddSetRange(ms, selected, range_dir, first_item, last_item)
	local req = Structs.ImGuiSelectionRequest.new(
		ImGuiSelectionRequestType.SetRange,
		selected,
		range_dir,
		if range_dir > 0 then first_item else last_item,
		if range_dir > 0 then last_item else first_item
	)
	ms.IO.Requests:push_back(req)
end

function ImGui.DebugNodeMultiSelectState(storage)
	local is_active = (storage.LastFrameActive >= ImGui.GetFrameCount() - 2)
	if not is_active then
		ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyleColorVec4(ImGuiCol.TextDisabled))
	end
	local open = ImGui.TreeNode(
		storage.ID,
		"MultiSelect 0x%08X in '%s'%s",
		storage.ID,
		if storage.Window then storage.Window.Name else "N/A",
		if is_active then "" else " *Inactive*"
	)
	if not is_active then
		ImGui.PopStyleColor()
	end
	if not open then
		return
	end
	ImGui.Text(
		"RangeSrcItem = %d (0x%X), RangeSelected = %d",
		storage.RangeSrcItem,
		storage.RangeSrcItem,
		storage.RangeSelected
	)
	ImGui.Text("NavIdItem = %d (0x%X), NavIdSelected = %d", storage.NavIdItem, storage.NavIdItem, storage.NavIdSelected)
	ImGui.Text("LastSelectionSize = %d", storage.LastSelectionSize)
	ImGui.TreePop()
end

function ImGuiSelectionBasicStorage:Clear()
	self.Size = 0
	self._SelectionOrder = 1
	self._Storage.Data:resize(0)
end

function ImGuiSelectionBasicStorage:Swap(r)
	self.Size, r.Size = r.Size, self.Size
	self._SelectionOrder, r._SelectionOrder = r._SelectionOrder, self._SelectionOrder
	self._Storage.Data:swap(r._Storage.Data)
end

function ImGuiSelectionBasicStorage:Contains(id)
	return self._Storage:GetInt(id, 0) ~= 0
end

function ImGui.PairComparerByValueInt(lhs, rhs)
	local lhs_v = lhs.val_i
	local rhs_v = rhs.val_i
	return if lhs_v > rhs_v then 1 elseif lhs_v < rhs_v then -1 else 0
end

function ImGuiSelectionBasicStorage:GetNextSelectedItem(opaque_it)
	local data = self._Storage.Data
	local it = opaque_it
	local it_end = data.Size
	if self.PreserveOrder and (it == nil or it == 0) and it_end > 0 then
		Base.ImQsort(data, data.Size, ImGui.PairComparerByValueInt)
	end
	if it == nil then
		it = 0
	end
	assert(it >= 0 and it <= it_end)
	while it < it_end and data[it + 1].val_i == 0 do
		it += 1
	end
	local has_more = (it ~= it_end)
	local out_it = if has_more then it + 1 else it
	local out_id = if has_more then data[it + 1].key else 0
	if self.PreserveOrder and not has_more then
		self._Storage:BuildSortByKey()
	end
	return has_more, out_it, out_id
end

function ImGuiSelectionBasicStorage:SetItemSelected(id, selected)
	local v = self._Storage:GetInt(id, 0)
	if selected and v == 0 then
		self._Storage:SetInt(id, self._SelectionOrder)
		self._SelectionOrder += 1
		self.Size += 1
	elseif not selected and v ~= 0 then
		self._Storage:SetInt(id, 0)
		self.Size -= 1
	end
end

function ImGui.ImGuiSelectionBasicStorage_BatchSetItemSelected(selection, id, selected, size_before_amends, selection_order)
	local data = selection._Storage.Data
	local first = 0
	local count = size_before_amends
	while count > 0 do
		local count2 = bit32.rshift(count, 1)
		local mid = first + count2
		if data[mid + 1].key < id then
			first = mid + 1
			count -= count2 + 1
		else
			count = count2
		end
	end
	local it = data[first + 1]
	local is_contained = (first ~= size_before_amends) and (it.key == id)
	if selected == (is_contained and it.val_i ~= 0) then
		return
	end
	if selected and not is_contained then
		data:push_back(Structs.ImGuiStoragePair.new(id, selection_order))
	elseif is_contained then
		it.val_i = if selected then selection_order else 0
	end
	selection.Size += if selected then 1 else -1
end

function ImGui.ImGuiSelectionBasicStorage_BatchFinish(selection, selected, size_before_amends)
	local storage = selection._Storage
	if selected and selection.Size ~= size_before_amends then
		storage:BuildSortByKey()
	end
end

function ImGuiSelectionBasicStorage:ApplyRequests(ms_io)
	assert(ms_io.ItemsCount ~= -1, "Missing value for items_count in BeginMultiSelect() call!")
	assert(self.AdapterIndexToStorageId ~= nil)

	local requests = ms_io.Requests
	for i = 1, requests.Size do
		local req = requests[i]
		if req.Type == ImGuiSelectionRequestType.SetAll then
			self:Clear()
			if req.Selected then
				self._Storage.Data:reserve(ms_io.ItemsCount)
				local size_before_amends = self._Storage.Data.Size
				for idx = 0, ms_io.ItemsCount - 1 do
					ImGui.ImGuiSelectionBasicStorage_BatchSetItemSelected(
						self,
						self:GetStorageIdFromIndex(idx),
						req.Selected,
						size_before_amends,
						self._SelectionOrder
					)
					self._SelectionOrder += 1
				end
				ImGui.ImGuiSelectionBasicStorage_BatchFinish(self, req.Selected, size_before_amends)
			end
		elseif req.Type == ImGuiSelectionRequestType.SetRange then
			local first_item = Base.ImTruncToInt(req.RangeFirstItem)
			local last_item = Base.ImTruncToInt(req.RangeLastItem)
			local selection_changes = last_item - first_item + 1
			if selection_changes == 1 or (selection_changes < Base.ImTruncToInt(self.Size / 100)) then
				for idx = first_item, last_item do
					self:SetItemSelected(self:GetStorageIdFromIndex(idx), req.Selected)
				end
			else
				local size_before_amends = self._Storage.Data.Size
				local selection_order = self._SelectionOrder + (if req.RangeDirection < 0 then selection_changes - 1 else 0)
				for idx = first_item, last_item do
					ImGui.ImGuiSelectionBasicStorage_BatchSetItemSelected(
						self,
						self:GetStorageIdFromIndex(idx),
						req.Selected,
						size_before_amends,
						selection_order
					)
					selection_order += req.RangeDirection
				end
				if req.Selected then
					self._SelectionOrder += selection_changes
				end
				ImGui.ImGuiSelectionBasicStorage_BatchFinish(self, req.Selected, size_before_amends)
			end
		end
	end
end

function ImGuiSelectionExternalStorage:ApplyRequests(ms_io)
	assert(self.AdapterSetItemSelected)
	local requests = ms_io.Requests
	for i = 1, requests.Size do
		local req = requests[i]
		if req.Type == ImGuiSelectionRequestType.SetAll then
			for idx = 0, ms_io.ItemsCount - 1 do
				self.AdapterSetItemSelected(self, idx, req.Selected)
			end
		end
		if req.Type == ImGuiSelectionRequestType.SetRange then
			for idx = Base.ImTruncToInt(req.RangeFirstItem), Base.ImTruncToInt(req.RangeLastItem) do
				self.AdapterSetItemSelected(self, idx, req.Selected)
			end
		end
	end
end

function ImGui.BeginListBox(label, size_arg)
	if size_arg == nil then
		size_arg = ImVec2(0, 0)
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local style = g.Style
	local id = ImGui.GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local size = Base.ImTrunc(
		ImGui.CalcItemSize(
			size_arg,
			ImGui.CalcItemWidth(),
			ImGui.GetTextLineHeightWithSpacing() * 7.25 + style.FramePadding.y * 2.0
		)
	)
	local frame_size = ImVec2(size.x, ImMax(size.y, label_size.y))
	local frame_bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + frame_size)
	local bb = ImRect.new(
		frame_bb.Min,
		frame_bb.Max + ImVec2(if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0, 0.0)
	)
	g.NextItemData:ClearFlags()

	if not ImGui.IsRectVisible(bb.Min, bb.Max) then
		ImGui.ItemSize(bb:GetSize(), style.FramePadding.y)
		ImGui.ItemAdd(bb, 0, frame_bb)
		g.NextWindowData:ClearFlags()
		return false
	end

	ImGui.BeginGroup()
	if label_size.x > 0.0 then
		local label_pos = ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y)
		ImGui.RenderText(label_pos, label, label_end, false)
		window.DC.CursorMaxPos = ImMax(window.DC.CursorMaxPos, label_pos + label_size)
		ImGui.AlignTextToFramePadding()
	end

	ImGui.BeginChild(id, frame_bb:GetSize(), ImGuiChildFlags.FrameStyle)
	return true
end

function ImGui.EndListBox()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(
		bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow),
		"Mismatched BeginListBox/EndListBox calls. Did you test the return value of BeginListBox?"
	)

	ImGui.EndChild()
	ImGui.EndGroup()
end

function ImGui.ListBox(label, current_item, items_or_getter, ...)
	if type(items_or_getter) == "table" then
		local items_count, height_items = ...
		if items_count == nil then
			items_count = #items_or_getter
		end
		return ImGui.ListBox(label, current_item, ImGui.Items_ArrayGetter, items_or_getter, items_count, height_items)
	end

	local getter = items_or_getter
	local user_data, items_count, height_in_items = ...
	if height_in_items == nil then
		height_in_items = -1
	end
	local g = ImGui.GImGui

	if height_in_items < 0 then
		height_in_items = ImMin(items_count, 7)
	end
	local height_in_items_f = height_in_items + 0.25
	local size = ImVec2(
		0.0,
		Base.ImTrunc(ImGui.GetTextLineHeightWithSpacing() * height_in_items_f + g.Style.FramePadding.y * 2.0)
	)

	if not ImGui.BeginListBox(label, size) then
		return false, current_item
	end

	local value_changed = false
	local clipper = Structs.ImGuiListClipper.new()
	clipper:Begin(items_count, ImGui.GetTextLineHeightWithSpacing())
	clipper:IncludeItemByIndex(current_item)
	while clipper:Step() do
		for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
			local item_text = getter(user_data, i)
			if item_text == nil then
				item_text = "*Unknown item*"
			end

			ImGui.PushID(i)
			local item_selected = (i == current_item)
			if ImGui.Selectable(item_text, item_selected) then
				current_item = i
				value_changed = true
			end
			if item_selected then
				ImGui.SetItemDefaultFocus()
			end
			ImGui.PopID()
		end
	end
	ImGui.EndListBox()

	if value_changed then
		ImGui.MarkItemEdited(g.LastItemData.ID)
	end

	return value_changed, current_item
end

function ImGui.PlotEx(
	plot_type,
	label,
	values_getter,
	data,
	values_count,
	values_offset,
	overlay_text,
	scale_min,
	scale_max,
	size_arg
)
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return -1
	end

	local style = g.Style
	local id = window:GetID(label)

	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local frame_size = ImGui.CalcItemSize(size_arg, ImGui.CalcItemWidth(), label_size.y + style.FramePadding.y * 2.0)

	local frame_bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + frame_size)
	local inner_bb = ImRect.new(frame_bb.Min + style.FramePadding, frame_bb.Max - style.FramePadding)
	local total_bb = ImRect.new(
		frame_bb.Min,
		frame_bb.Max + ImVec2(if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0, 0)
	)
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(total_bb, id, frame_bb, ImGuiItemFlags.NoNav) then
		return -1
	end
	local _, hovered = ImGui.ButtonBehavior(frame_bb, id, nil, nil)

	if scale_min == FLT_MAX or scale_max == FLT_MAX then
		local v_min = FLT_MAX
		local v_max = -FLT_MAX
		for i = 0, values_count - 1 do
			local v = values_getter(data, i)
			if v ~= v then
				continue
			end
			v_min = ImMin(v_min, v)
			v_max = ImMax(v_max, v)
		end
		if scale_min == FLT_MAX then
			scale_min = v_min
		end
		if scale_max == FLT_MAX then
			scale_max = v_max
		end
	end

	ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), true, style.FrameRounding)

	local is_lines = plot_type == ImGuiPlotType.Lines
	local values_count_min = if is_lines then 2 else 1
	local idx_hovered = -1
	if values_count >= values_count_min then
		local res_w = ImMin(Base.ImTruncToInt(frame_size.x), values_count) + (if is_lines then -1 else 0)
		local item_count = values_count + (if is_lines then -1 else 0)

		if hovered and inner_bb:Contains(g.IO.MousePos) then
			local t = ImClamp((g.IO.MousePos.x - inner_bb.Min.x) / (inner_bb.Max.x - inner_bb.Min.x), 0.0, 0.999)
			local v_idx = Base.ImTruncToInt(t * item_count)
			assert(v_idx >= 0 and v_idx < values_count)

			local v0 = values_getter(data, (v_idx + values_offset) % values_count)
			local v1 = values_getter(data, (v_idx + 1 + values_offset) % values_count)
			if is_lines then
				ImGui.SetTooltip("%d: %8.4g\n%d: %8.4g", v_idx, v0, v_idx + 1, v1)
			elseif plot_type == ImGuiPlotType.Histogram then
				ImGui.SetTooltip("%d: %8.4g", v_idx, v0)
			end
			idx_hovered = v_idx
		end

		local t_step = 1.0 / res_w
		local inv_scale = if scale_min == scale_max then 0.0 else (1.0 / (scale_max - scale_min))

		local v0 = values_getter(data, (0 + values_offset) % values_count)
		local t0 = 0.0
		local tp0 = ImVec2(t0, 1.0 - Base.ImSaturate((v0 - scale_min) * inv_scale))
		local histogram_zero_line_t = if scale_min * scale_max < 0.0
			then (1 + scale_min * inv_scale)
			else (if scale_min < 0.0 then 0.0 else 1.0)

		local col_base = ImGui.GetColorU32(if is_lines then ImGuiCol.PlotLines else ImGuiCol.PlotHistogram)
		local col_hovered = ImGui.GetColorU32(if is_lines then ImGuiCol.PlotLinesHovered else ImGuiCol.PlotHistogramHovered)

		for _ = 0, res_w - 1 do
			local t1 = t0 + t_step
			local v1_idx = Base.ImTruncToInt(t0 * item_count + 0.5)
			assert(v1_idx >= 0 and v1_idx < values_count)
			local v1 = values_getter(data, (v1_idx + values_offset + 1) % values_count)
			local tp1 = ImVec2(t1, 1.0 - Base.ImSaturate((v1 - scale_min) * inv_scale))

			local pos0 = Base.ImLerp(inner_bb.Min, inner_bb.Max, tp0)
			local pos1 =
				Base.ImLerp(inner_bb.Min, inner_bb.Max, if is_lines then tp1 else ImVec2(tp1.x, histogram_zero_line_t))
			if is_lines then
				window.DrawList:AddLine(pos0, pos1, if idx_hovered == v1_idx then col_hovered else col_base)
			elseif plot_type == ImGuiPlotType.Histogram then
				if pos1.x >= pos0.x + 2.0 then
					pos1 = ImVec2(pos1.x - 1.0, pos1.y)
				end
				if pos0.y > pos1.y then
					pos0, pos1 = ImVec2(pos0.x, pos1.y), ImVec2(pos1.x, pos0.y)
				end
				window.DrawList:AddRectFilled(pos0, pos1, if idx_hovered == v1_idx then col_hovered else col_base)
			end

			t0 = t1
			tp0 = tp1
		end
	end

	if overlay_text then
		ImGui.RenderTextClipped(
			ImVec2(frame_bb.Min.x, frame_bb.Min.y + style.FramePadding.y),
			frame_bb.Max,
			overlay_text,
			nil,
			nil,
			ImVec2(0.5, 0.0)
		)
	end

	if label_size.x > 0.0 then
		ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, inner_bb.Min.y), label, label_end, false)
	end

	return idx_hovered
end

function ImGui.Plot_ArrayGetter(data, idx)
	return data.Values[(idx * data.Stride) // 4 + 1]
end

local function PlotDispatch(plot_type, label, values_or_getter, ...)
	local getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size
	if type(values_or_getter) == "function" then
		getter = values_or_getter
		data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size = ...
	else
		local stride
		values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride = ...
		if values_count == nil then
			values_count = #values_or_getter
		end
		getter = ImGui.Plot_ArrayGetter
		data = { Values = values_or_getter, Stride = if stride == nil then 4 else stride }
	end
	if values_offset == nil then
		values_offset = 0
	end
	if scale_min == nil then
		scale_min = FLT_MAX
	end
	if scale_max == nil then
		scale_max = FLT_MAX
	end
	if graph_size == nil then
		graph_size = ImVec2(0, 0)
	end
	ImGui.PlotEx(plot_type, label, getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size)
end

function ImGui.PlotLines(label, values_or_getter, ...)
	PlotDispatch(ImGuiPlotType.Lines, label, values_or_getter, ...)
end

function ImGui.PlotHistogram(label, values_or_getter, ...)
	PlotDispatch(ImGuiPlotType.Histogram, label, values_or_getter, ...)
end

function ImGui.Value(prefix, v, float_format)
	if type(v) == "boolean" then
		ImGui.Text("%s: %s", prefix, if v then "true" else "false")
	elseif float_format ~= nil or v ~= math.floor(v) then
		if float_format then
			local fmt = Base.ImFormatString("%%s: %s", float_format)
			ImGui.Text(fmt, prefix, v)
		else
			ImGui.Text("%s: %.3f", prefix, v)
		end
	else
		ImGui.Text("%s: %d", prefix, v)
	end
end

return true
