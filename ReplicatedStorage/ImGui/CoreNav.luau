--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImLerp, ImTrunc, ImSaturate = Base.ImLerp, Base.ImTrunc, Base.ImSaturate
local IM_ROUND = Base.IM_ROUND
local ImHashStr = Base.ImHashStr
local FLT_MAX = Base.FLT_MAX
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiNavMoveFlags = Enums.ImGuiNavMoveFlags
local ImGuiAxis = Enums.ImGuiAxis
local ImGuiDir = Enums.ImGuiDir
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiScrollFlags = Enums.ImGuiScrollFlags
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiSelectionUserData = Enums.ImGuiSelectionUserData
local ImGuiLocKey = Enums.ImGuiLocKey
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiCond = Enums.ImGuiCond

local NAV_WINDOWING_HIGHLIGHT_DELAY = 0.20
local NAV_WINDOWING_LIST_APPEAR_DELAY = 0.15
local NAV_ACTIVATE_HIGHLIGHT_TIMER = 0.10
local NAV_ACTIVATE_INPUT_WITH_GAMEPAD_DELAY = 0.60
local INT_MAX = 2147483647

local function VecGetAxis(v, axis)
	if axis == 0 then
		return v.x
	end
	return v.y
end

local function VecWithAxis(v, axis, value)
	if axis == 0 then
		return ImVec2(value, v.y)
	end
	return ImVec2(v.x, value)
end

function ImGui.SetNavCursorVisible(visible)
	local g = ImGui.GImGui
	if g.NavWindow and bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs) then
		visible = false
	elseif g.IO.ConfigNavCursorVisibleAlways then
		visible = true
	end
	g.NavCursorVisible = visible
end

function ImGui.SetNavCursorVisibleAfterMove()
	local g = ImGui.GImGui
	if g.NavWindow and bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs) then
		g.NavCursorVisible = false
	elseif g.NavInputSource == ImGuiInputSource.Keyboard and bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) == 0 then
		g.NavCursorVisible = false
	elseif g.NavInputSource == ImGuiInputSource.Gamepad and bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) == 0 then
		g.NavCursorVisible = false
	elseif g.IO.ConfigNavCursorVisibleAuto then
		g.NavCursorVisible = true
	end
	g.NavHighlightItemUnderNav = true
	g.NavMousePosDirty = true
end

function ImGui.SetNavWindow(window)
	local g = ImGui.GImGui
	if g.NavWindow ~= window then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
			ImGui.DebugLog("[focus] SetNavWindow(\"%s\")\n", window and window.Name or "<NULL>")
		end
		g.NavWindow = window
		g.NavLastValidSelectionUserData = ImGuiSelectionUserData.Invalid
	end
	g.NavInitRequest = false
	g.NavMoveSubmitted = false
	g.NavMoveScoringItems = false
	ImGui.NavUpdateAnyRequestFlag()
end

function ImGui.NavHighlightActivated(id)
	local g = ImGui.GImGui
	g.NavHighlightActivatedId = id
	g.NavHighlightActivatedTimer = NAV_ACTIVATE_HIGHLIGHT_TIMER
end

function ImGui.NavClearPreferredPosForAxis(axis)
	local g = ImGui.GImGui
	local root = g.NavWindow.RootWindowForNav
	local layer = g.NavLayer + 1
	root.NavPreferredScoringPosRel[layer] = VecWithAxis(root.NavPreferredScoringPosRel[layer], axis, FLT_MAX)
end

function ImGui.SetNavID(id, nav_layer, focus_scope_id, rect_rel)
	local g = ImGui.GImGui
	assert(g.NavWindow ~= nil)
	assert(nav_layer == ImGuiNavLayer.Main or nav_layer == ImGuiNavLayer.Menu)
	g.NavId = id
	g.NavLayer = nav_layer
	ImGui.SetNavFocusScope(focus_scope_id)
	g.NavWindow.NavLastIds[nav_layer + 1] = id
	g.NavWindow.NavRectRel[nav_layer + 1] = rect_rel

	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.Y)
end

function ImGui.SetFocusID(id, window)
	local g = ImGui.GImGui
	assert(id ~= 0)

	if g.NavWindow ~= window then
		ImGui.SetNavWindow(window)
	end

	local nav_layer = window.DC.NavLayerCurrent
	g.NavId = id
	g.NavLayer = nav_layer
	ImGui.SetNavFocusScope(g.CurrentFocusScopeId)
	window.NavLastIds[nav_layer + 1] = id
	if g.LastItemData.ID == id then
		window.NavRectRel[nav_layer + 1] = ImGui.WindowRectAbsToRel(window, g.LastItemData.NavRect)
	end
	g.NavIdItemFlags = if g.LastItemData.ID == id then g.LastItemData.ItemFlags else ImGuiItemFlags.None
	if id == g.ActiveIdIsAlive then
		g.NavIdIsAlive = true
	end

	if g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
		g.NavHighlightItemUnderNav = true
	elseif g.IO.ConfigNavCursorVisibleAuto then
		g.NavCursorVisible = false
	end

	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.Y)
end

local function ImGetDirQuadrantFromDelta(dx, dy)
	if math.abs(dx) > math.abs(dy) then
		return if dx > 0.0 then ImGuiDir.Right else ImGuiDir.Left
	end
	return if dy > 0.0 then ImGuiDir.Down else ImGuiDir.Up
end

local function NavScoreItemDistInterval(cand_min, cand_max, curr_min, curr_max)
	if cand_max < curr_min then
		return cand_max - curr_min
	end
	if curr_max < cand_min then
		return cand_min - curr_max
	end
	return 0.0
end

function ImGui.NavScoreItem(result, nav_bb)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if g.NavLayer ~= window.DC.NavLayerCurrent then
		return false
	end

	local cand = nav_bb
	local curr = g.NavScoringRect
	g.NavScoringDebugCount += 1

	if window.ParentWindow == g.NavWindow then
		assert(bit32.btest(bit32.bor(window.ChildFlags, g.NavWindow.ChildFlags), ImGuiChildFlags.NavFlattened))
		if not window.ClipRect:Overlaps(cand) then
			return false
		end
		cand = cand:ClippedWithFull(window.ClipRect)
	end

	local dbx = NavScoreItemDistInterval(cand.Min.x, cand.Max.x, curr.Min.x, curr.Max.x)
	local dby = NavScoreItemDistInterval(ImLerp(cand.Min.y, cand.Max.y, 0.2), ImLerp(cand.Min.y, cand.Max.y, 0.8), ImLerp(curr.Min.y, curr.Max.y, 0.2), ImLerp(curr.Min.y, curr.Max.y, 0.8))
	if dby ~= 0.0 and dbx ~= 0.0 then
		dbx = (dbx / 1000.0) + (if dbx > 0.0 then 1.0 else -1.0)
	end
	local dist_box = math.abs(dbx) + math.abs(dby)

	local dcx = (cand.Min.x + cand.Max.x) - (curr.Min.x + curr.Max.x)
	local dcy = (cand.Min.y + cand.Max.y) - (curr.Min.y + curr.Max.y)
	local dist_center = math.abs(dcx) + math.abs(dcy)

	local quadrant
	local dax, day, dist_axial = 0.0, 0.0, 0.0
	if dbx ~= 0.0 or dby ~= 0.0 then
		dax = dbx
		day = dby
		dist_axial = dist_box
		quadrant = ImGetDirQuadrantFromDelta(dbx, dby)
	elseif dcx ~= 0.0 or dcy ~= 0.0 then
		dax = dcx
		day = dcy
		dist_axial = dist_center
		quadrant = ImGetDirQuadrantFromDelta(dcx, dcy)
	else
		quadrant = if g.LastItemData.ID < g.NavId then ImGuiDir.Left else ImGuiDir.Right
	end

	local move_dir = g.NavMoveDir

	local new_best = false
	if quadrant == move_dir then
		if dist_box < result.DistBox then
			result.DistBox = dist_box
			result.DistCenter = dist_center
			return true
		end
		if dist_box == result.DistBox then
			if dist_center < result.DistCenter then
				result.DistCenter = dist_center
				new_best = true
			elseif dist_center == result.DistCenter then
				if (if move_dir == ImGuiDir.Up or move_dir == ImGuiDir.Down then dby else dbx) < 0.0 then
					new_best = true
				end
			end
		end
	end

	if result.DistBox == FLT_MAX and dist_axial < result.DistAxial then
		if g.NavLayer == ImGuiNavLayer.Menu and not bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.ChildMenu) then
			if (move_dir == ImGuiDir.Left and dax < 0.0) or (move_dir == ImGuiDir.Right and dax > 0.0) or (move_dir == ImGuiDir.Up and day < 0.0) or (move_dir == ImGuiDir.Down and day > 0.0) then
				result.DistAxial = dist_axial
				new_best = true
			end
		end
	end

	return new_best
end

function ImGui.NavApplyItemToResult(result)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	result.Window = window
	result.ID = g.LastItemData.ID
	result.FocusScopeId = g.CurrentFocusScopeId
	result.ItemFlags = g.LastItemData.ItemFlags
	result.RectRel = ImGui.WindowRectAbsToRel(window, g.LastItemData.NavRect)
	if bit32.btest(result.ItemFlags, ImGuiItemFlags.HasSelectionUserData) then
		assert(g.NextItemData.SelectionUserData ~= ImGuiSelectionUserData.Invalid)
		result.SelectionUserData = g.NextItemData.SelectionUserData
	end
end

function ImGui.NavUpdateCurrentWindowIsScrollPushableX()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	window.DC.NavIsScrollPushableX = (g.CurrentTable == nil and window.DC.CurrentColumns == nil)
end

function ImGui.NavProcessItem()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local id = g.LastItemData.ID
	local item_flags = g.LastItemData.ItemFlags

	local nav_bb = g.LastItemData.NavRect
	if window.DC.NavIsScrollPushableX == false then
		nav_bb = nav_bb:WithMinX(ImClamp(nav_bb.Min.x, window.ClipRect.Min.x, window.ClipRect.Max.x))
		nav_bb = nav_bb:WithMaxX(ImClamp(nav_bb.Max.x, window.ClipRect.Min.x, window.ClipRect.Max.x))
	end

	if g.NavInitRequest and g.NavLayer == window.DC.NavLayerCurrent and bit32.band(item_flags, ImGuiItemFlags.Disabled) == 0 then
		local candidate_for_nav_default_focus = bit32.band(item_flags, ImGuiItemFlags.NoNavDefaultFocus) == 0
		if candidate_for_nav_default_focus or g.NavInitResult.ID == 0 then
			ImGui.NavApplyItemToResult(g.NavInitResult)
		end
		if candidate_for_nav_default_focus then
			g.NavInitRequest = false
			ImGui.NavUpdateAnyRequestFlag()
		end
	end

	if g.NavMoveScoringItems and bit32.band(item_flags, ImGuiItemFlags.Disabled) == 0 then
		if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.FocusApi) or bit32.band(window.Flags, ImGuiWindowFlags.NoNavInputs) == 0 then
			local is_tabbing = bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) ~= 0
			if is_tabbing then
				ImGui.NavProcessItemForTabbingRequest(id, item_flags, g.NavMoveFlags)
			elseif g.NavId ~= id or bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.AllowCurrentNavId) then
				local result = if window == g.NavWindow then g.NavMoveResultLocal else g.NavMoveResultOther
				if ImGui.NavScoreItem(result, nav_bb) then
					ImGui.NavApplyItemToResult(result)
				end

				local VISIBLE_RATIO = 0.70
				if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.AlsoScoreVisibleSet) then
					local r = window.InnerRect
					if r:Overlaps(nav_bb) then
						if ImClamp(nav_bb.Max.y, r.Min.y, r.Max.y) - ImClamp(nav_bb.Min.y, r.Min.y, r.Max.y) >= (nav_bb.Max.y - nav_bb.Min.y) * VISIBLE_RATIO then
							if ImGui.NavScoreItem(g.NavMoveResultLocalVisible, nav_bb) then
								ImGui.NavApplyItemToResult(g.NavMoveResultLocalVisible)
							end
						end
					end
				end
			end
		end
	end

	if g.NavId == id then
		if g.NavWindow ~= window then
			ImGui.SetNavWindow(window)
		end
		g.NavLayer = window.DC.NavLayerCurrent
		ImGui.SetNavFocusScope(g.CurrentFocusScopeId)
		g.NavFocusScopeId = g.CurrentFocusScopeId
		g.NavIdIsAlive = true
		g.NavIdItemFlags = item_flags
		if bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.HasSelectionUserData) then
			assert(g.NextItemData.SelectionUserData ~= ImGuiSelectionUserData.Invalid)
			g.NavLastValidSelectionUserData = g.NextItemData.SelectionUserData
		end
		window.NavRectRel[window.DC.NavLayerCurrent + 1] = ImGui.WindowRectAbsToRel(window, nav_bb)
	end
end

function ImGui.NavProcessItemForTabbingRequest(id, item_flags, move_flags)
	local g = ImGui.GImGui

	if bit32.band(move_flags, ImGuiNavMoveFlags.FocusApi) == 0 then
		if g.NavLayer ~= g.CurrentWindow.DC.NavLayerCurrent then
			return
		end
		if g.NavFocusScopeId ~= g.CurrentFocusScopeId then
			return
		end
	end

	local can_stop
	if bit32.btest(move_flags, ImGuiNavMoveFlags.FocusApi) then
		can_stop = true
	else
		can_stop = bit32.band(item_flags, ImGuiItemFlags.NoTabStop) == 0 and (bit32.btest(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) or bit32.btest(item_flags, ImGuiItemFlags.Inputable))
	end

	local result = g.NavMoveResultLocal
	if g.NavTabbingDir == 1 then
		if can_stop and g.NavTabbingResultFirst.ID == 0 then
			ImGui.NavApplyItemToResult(g.NavTabbingResultFirst)
		end
		local resolved = false
		if can_stop and g.NavTabbingCounter > 0 then
			g.NavTabbingCounter -= 1
			resolved = g.NavTabbingCounter == 0
		end
		if resolved then
			ImGui.NavMoveRequestResolveWithLastItem(result)
		elseif g.NavId == id then
			g.NavTabbingCounter = 1
		end
	elseif g.NavTabbingDir == -1 then
		if g.NavId == id then
			if result.ID ~= 0 then
				g.NavMoveScoringItems = false
				ImGui.NavUpdateAnyRequestFlag()
			end
		elseif can_stop then
			ImGui.NavApplyItemToResult(result)
		end
	elseif g.NavTabbingDir == 0 then
		if can_stop and g.NavId == id then
			ImGui.NavMoveRequestResolveWithLastItem(result)
		end
		if can_stop and g.NavTabbingResultFirst.ID == 0 then
			ImGui.NavApplyItemToResult(g.NavTabbingResultFirst)
		end
	end
end

function ImGui.NavMoveRequestButNoResultYet()
	local g = ImGui.GImGui
	return g.NavMoveScoringItems and g.NavMoveResultLocal.ID == 0 and g.NavMoveResultOther.ID == 0
end

function ImGui.NavMoveRequestSubmit(move_dir, clip_dir, move_flags, scroll_flags)
	local g = ImGui.GImGui
	assert(g.NavWindow ~= nil)

	if bit32.btest(move_flags, ImGuiNavMoveFlags.IsTabbing) then
		move_flags = bit32.bor(move_flags, ImGuiNavMoveFlags.AllowCurrentNavId)
	end

	g.NavMoveSubmitted = true
	g.NavMoveScoringItems = true
	g.NavMoveDir = move_dir
	g.NavMoveDirForDebug = move_dir
	g.NavMoveClipDir = clip_dir
	g.NavMoveFlags = move_flags
	g.NavMoveScrollFlags = scroll_flags
	g.NavMoveForwardToNextFrame = false
	g.NavMoveKeyMods = if bit32.btest(move_flags, ImGuiNavMoveFlags.FocusApi) then 0 else g.IO.KeyMods
	g.NavMoveResultLocal:Clear()
	g.NavMoveResultLocalVisible:Clear()
	g.NavMoveResultOther:Clear()
	g.NavTabbingCounter = 0
	g.NavTabbingResultFirst:Clear()
	ImGui.NavUpdateAnyRequestFlag()
end

function ImGui.NavMoveRequestResolveWithLastItem(result)
	local g = ImGui.GImGui
	g.NavMoveScoringItems = false
	ImGui.NavApplyItemToResult(result)
	ImGui.NavUpdateAnyRequestFlag()
end

function ImGui.NavMoveRequestResolveWithPastTreeNode(result, tree_node_data)
	local g = ImGui.GImGui
	g.NavMoveScoringItems = false
	g.LastItemData.ID = tree_node_data.ID
	g.LastItemData.ItemFlags = bit32.band(tree_node_data.ItemFlags, bit32.bnot(ImGuiItemFlags.HasSelectionUserData))
	g.LastItemData.NavRect = tree_node_data.NavRect
	ImGui.NavApplyItemToResult(result)
	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.Y)
	ImGui.NavUpdateAnyRequestFlag()
end

function ImGui.NavMoveRequestCancel()
	local g = ImGui.GImGui
	g.NavMoveSubmitted = false
	g.NavMoveScoringItems = false
	ImGui.NavUpdateAnyRequestFlag()
end

function ImGui.NavMoveRequestForward(move_dir, clip_dir, move_flags, scroll_flags)
	local g = ImGui.GImGui
	assert(g.NavMoveForwardToNextFrame == false)
	ImGui.NavMoveRequestCancel()
	g.NavMoveForwardToNextFrame = true
	g.NavMoveDir = move_dir
	g.NavMoveClipDir = clip_dir
	g.NavMoveFlags = bit32.bor(move_flags, ImGuiNavMoveFlags.Forwarded)
	g.NavMoveScrollFlags = scroll_flags
end

function ImGui.NavMoveRequestTryWrapping(window, wrap_flags)
	local g = ImGui.GImGui
	assert(bit32.band(wrap_flags, ImGuiNavMoveFlags.WrapMask_) ~= 0 and bit32.band(wrap_flags, bit32.bnot(ImGuiNavMoveFlags.WrapMask_)) == 0)

	if g.NavWindow == window and g.NavMoveScoringItems and g.NavLayer == window.DC.NavLayerCurrent then
		g.NavMoveFlags = bit32.bor(bit32.band(g.NavMoveFlags, bit32.bnot(ImGuiNavMoveFlags.WrapMask_)), wrap_flags)
	end
end

function ImGui.NavSaveLastChildNavWindowIntoParent(nav_window)
	local parent = nav_window
	while parent and parent.RootWindow ~= parent and bit32.band(parent.Flags, bit32.bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.ChildMenu)) == 0 do
		parent = parent.ParentWindow
	end
	if parent and parent ~= nav_window then
		parent.NavLastChildNavWindow = nav_window
	end
end

function ImGui.NavRestoreLastChildNavWindow(window)
	if window.NavLastChildNavWindow and window.NavLastChildNavWindow.WasActive then
		return window.NavLastChildNavWindow
	end
	return window
end

function ImGui.NavRestoreLayer(layer)
	local g = ImGui.GImGui
	if layer == ImGuiNavLayer.Main then
		local prev_nav_window = g.NavWindow
		g.NavWindow = ImGui.NavRestoreLastChildNavWindow(g.NavWindow)
		g.NavLastValidSelectionUserData = ImGuiSelectionUserData.Invalid
		if prev_nav_window and bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
			ImGui.DebugLog("[focus] NavRestoreLayer: from \"%s\" to SetNavWindow(\"%s\")\n", prev_nav_window.Name, g.NavWindow.Name)
		end
	end
	local window = g.NavWindow
	if window.NavLastIds[layer + 1] ~= 0 then
		ImGui.SetNavID(window.NavLastIds[layer + 1], layer, 0, window.NavRectRel[layer + 1])
	else
		g.NavLayer = layer
		ImGui.NavInitWindow(window, true)
	end
end

function ImGui.NavUpdateAnyRequestFlag()
	local g = ImGui.GImGui
	g.NavAnyRequest = g.NavMoveScoringItems or g.NavInitRequest
	if g.NavAnyRequest then
		assert(g.NavWindow ~= nil)
	end
end

function ImGui.NavInitWindow(window, force_reinit)
	local g = ImGui.GImGui
	assert(window == g.NavWindow)

	if bit32.btest(window.Flags, ImGuiWindowFlags.NoNavInputs) then
		g.NavId = 0
		ImGui.SetNavFocusScope(window.NavRootFocusScopeId)
		return
	end

	local init_for_nav = false
	if window == window.RootWindow or bit32.btest(window.Flags, ImGuiWindowFlags.Popup) or window.NavLastIds[1] == 0 or force_reinit then
		init_for_nav = true
	end
	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
		ImGui.DebugLog("[nav] NavInitRequest: from NavInitWindow(), init_for_nav=%d, window=\"%s\", layer=%d\n", if init_for_nav then 1 else 0, window.Name, g.NavLayer)
	end
	if init_for_nav then
		ImGui.SetNavID(0, g.NavLayer, window.NavRootFocusScopeId, ImRect.new())
		g.NavInitRequest = true
		g.NavInitRequestFromMove = false
		g.NavInitResult.ID = 0
		ImGui.NavUpdateAnyRequestFlag()
	else
		g.NavId = window.NavLastIds[1]
		ImGui.SetNavFocusScope(window.NavRootFocusScopeId)
	end
end

function ImGui.NavCalcPreferredRefPosSource(window_type)
	local g = ImGui.GImGui
	local window = g.NavWindow

	local activated_shortcut = g.ActiveId ~= 0 and g.ActiveIdFromShortcut and g.ActiveId == g.LastItemData.ID
	if bit32.btest(window_type, ImGuiWindowFlags.Popup) and activated_shortcut then
		return ImGuiInputSource.Keyboard
	end

	if not g.NavCursorVisible or not g.NavHighlightItemUnderNav or not window then
		return ImGuiInputSource.Mouse
	else
		return ImGuiInputSource.Keyboard
	end
end

function ImGui.NavCalcPreferredRefPos(window_type)
	local g = ImGui.GImGui
	local window = g.NavWindow
	local source = ImGui.NavCalcPreferredRefPosSource(window_type)

	if source == ImGuiInputSource.Mouse then
		local p = if ImGui.IsMousePosValid(g.IO.MousePos) then g.IO.MousePos else g.MouseLastValidPos
		return ImVec2(p.x + 1.0, p.y)
	else
		local activated_shortcut = g.ActiveId ~= 0 and g.ActiveIdFromShortcut and g.ActiveId == g.LastItemData.ID
		local ref_rect = ImRect.new()
		if activated_shortcut and bit32.btest(window_type, ImGuiWindowFlags.Popup) then
			ref_rect = g.LastItemData.NavRect
		elseif window ~= nil then
			ref_rect = ImGui.WindowRectRelToAbs(window, window.NavRectRel[g.NavLayer + 1])
		end

		if window ~= nil and window.LastFrameActive ~= g.FrameCount and (window.ScrollTarget.x ~= FLT_MAX or window.ScrollTarget.y ~= FLT_MAX) then
			local next_scroll = ImGui.CalcNextScrollFromScrollTargetAndClamp(window)
			ref_rect = ref_rect:Translated(window.Scroll - next_scroll)
		end
		local pos = ImVec2(ref_rect.Min.x + ImMin(g.Style.FramePadding.x * 4, ref_rect:GetWidth()), ref_rect.Max.y - ImMin(g.Style.FramePadding.y, ref_rect:GetHeight()))
		local viewport = ImGui.GetMainViewport()
		return ImTrunc(ImClamp(pos, viewport.Pos, viewport.Pos + viewport.Size))
	end
end

function ImGui.GetNavTweakPressedAmount(axis)
	local g = ImGui.GImGui
	local repeat_delay, repeat_rate = ImGui.GetTypematicRepeatRate(ImGuiInputFlags.RepeatRateNavTweak, nil, nil)

	local key_less, key_more
	if g.NavInputSource == ImGuiInputSource.Gamepad then
		key_less = if axis == ImGuiAxis.X then ImGuiKey.GamepadDpadLeft else ImGuiKey.GamepadDpadUp
		key_more = if axis == ImGuiAxis.X then ImGuiKey.GamepadDpadRight else ImGuiKey.GamepadDpadDown
	else
		key_less = if axis == ImGuiAxis.X then ImGuiKey.LeftArrow else ImGuiKey.UpArrow
		key_more = if axis == ImGuiAxis.X then ImGuiKey.RightArrow else ImGuiKey.DownArrow
	end
	local amount = ImGui.GetKeyPressedAmount(key_more, repeat_delay, repeat_rate) - ImGui.GetKeyPressedAmount(key_less, repeat_delay, repeat_rate)
	if amount ~= 0.0 and ImGui.IsKeyDown(key_less) and ImGui.IsKeyDown(key_more) then
		amount = 0.0
	end
	return amount
end

local nav_gamepad_keys_to_change_source = { ImGuiKey.GamepadFaceRight, ImGuiKey.GamepadFaceLeft, ImGuiKey.GamepadFaceUp, ImGuiKey.GamepadFaceDown, ImGuiKey.GamepadDpadRight, ImGuiKey.GamepadDpadLeft, ImGuiKey.GamepadDpadUp, ImGuiKey.GamepadDpadDown }
local nav_keyboard_keys_to_change_source = { ImGuiKey.Space, ImGuiKey.Enter, ImGuiKey.Escape, ImGuiKey.RightArrow, ImGuiKey.LeftArrow, ImGuiKey.UpArrow, ImGuiKey.DownArrow }

function ImGui.NavUpdate()
	local g = ImGui.GImGui
	local io = g.IO

	io.WantSetMousePos = false

	local nav_gamepad_active = bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0 and bit32.band(io.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0
	if nav_gamepad_active and g.NavInputSource ~= ImGuiInputSource.Gamepad then
		for _, key in nav_gamepad_keys_to_change_source do
			if ImGui.IsKeyDown(key) then
				g.NavInputSource = ImGuiInputSource.Gamepad
			end
		end
	end
	local nav_keyboard_active = bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0
	if nav_keyboard_active and g.NavInputSource ~= ImGuiInputSource.Keyboard then
		for _, key in nav_keyboard_keys_to_change_source do
			if ImGui.IsKeyDown(key) then
				g.NavInputSource = ImGuiInputSource.Keyboard
			end
		end
	end

	g.NavJustMovedToId = 0
	g.NavJustMovedToFocusScopeId = 0
	g.NavJustMovedFromFocusScopeId = 0
	if g.NavInitResult.ID ~= 0 then
		ImGui.NavInitRequestApplyResult()
	end
	g.NavInitRequest = false
	g.NavInitRequestFromMove = false
	g.NavInitResult.ID = 0

	if g.NavMoveSubmitted then
		ImGui.NavMoveRequestApplyResult()
	end
	g.NavTabbingCounter = 0
	g.NavMoveSubmitted = false
	g.NavMoveScoringItems = false
	if g.NavCursorHideFrames > 0 then
		g.NavCursorHideFrames -= 1
		if g.NavCursorHideFrames == 0 then
			g.NavCursorVisible = true
		end
	end

	local set_mouse_pos = false
	if g.NavMousePosDirty and g.NavIdIsAlive then
		if g.NavCursorVisible and g.NavHighlightItemUnderNav and g.NavWindow then
			set_mouse_pos = true
		end
	end
	g.NavMousePosDirty = false
	assert(g.NavLayer == ImGuiNavLayer.Main or g.NavLayer == ImGuiNavLayer.Menu)

	if g.NavWindow then
		ImGui.NavSaveLastChildNavWindowIntoParent(g.NavWindow)
	end
	if g.NavWindow and g.NavWindow.NavLastChildNavWindow ~= nil and g.NavLayer == ImGuiNavLayer.Main then
		g.NavWindow.NavLastChildNavWindow = nil
	end

	ImGui.NavUpdateWindowing()

	io.NavActive = (nav_keyboard_active or nav_gamepad_active) and g.NavWindow ~= nil and not bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs)
	io.NavVisible = (io.NavActive and g.NavId ~= 0 and g.NavCursorVisible) or (g.NavWindowingTarget ~= nil)

	ImGui.NavUpdateCancelRequest()
	ImGui.NavUpdateContextMenuRequest()

	g.NavActivateId = 0
	g.NavActivateDownId = 0
	g.NavActivatePressedId = 0
	g.NavActivateFlags = ImGuiActivateFlags.None
	local ImGuiKey_NavGamepadActivate = if g.IO.ConfigNavSwapGamepadButtons then ImGuiKey.GamepadFaceRight else ImGuiKey.GamepadFaceDown
	if g.NavId ~= 0 and g.NavCursorVisible and not g.NavWindowingTarget and g.NavWindow and not bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs) then
		local activate_down = (nav_keyboard_active and ImGui.IsKeyDown(ImGuiKey.Space, ImGuiKeyOwner.NoOwner)) or (nav_gamepad_active and ImGui.IsKeyDown(ImGuiKey_NavGamepadActivate, ImGuiKeyOwner.NoOwner))
		local activate_pressed = activate_down and ((nav_keyboard_active and ImGui.IsKeyPressed(ImGuiKey.Space, 0, ImGuiKeyOwner.NoOwner)) or (nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey_NavGamepadActivate, 0, ImGuiKeyOwner.NoOwner)))
		local input_pressed_keyboard = nav_keyboard_active and (ImGui.IsKeyPressed(ImGuiKey.Enter, 0, ImGuiKeyOwner.NoOwner) or ImGui.IsKeyPressed(ImGuiKey.KeypadEnter, 0, ImGuiKeyOwner.NoOwner))
		local input_pressed_gamepad = false
		if activate_down and nav_gamepad_active and ImGui.IsKeyDown(ImGuiKey_NavGamepadActivate, ImGuiKeyOwner.NoOwner) and bit32.btest(g.NavIdItemFlags, ImGuiItemFlags.Inputable) then
			if ImGui.GetKeyData(ImGuiKey_NavGamepadActivate).DownDurationPrev < NAV_ACTIVATE_INPUT_WITH_GAMEPAD_DELAY and ImGui.GetKeyData(ImGuiKey_NavGamepadActivate).DownDuration >= NAV_ACTIVATE_INPUT_WITH_GAMEPAD_DELAY then
				input_pressed_gamepad = true
			end
		end

		if g.ActiveId == 0 and activate_pressed then
			g.NavActivateId = g.NavId
			g.NavActivateFlags = ImGuiActivateFlags.PreferTweak
		end
		if (g.ActiveId == 0 or g.ActiveId == g.NavId) and (input_pressed_keyboard or input_pressed_gamepad) then
			g.NavActivateId = g.NavId
			g.NavActivateFlags = ImGuiActivateFlags.PreferInput
		end
		if (g.ActiveId == 0 or g.ActiveId == g.NavId) and (activate_down or input_pressed_keyboard or input_pressed_gamepad) then
			g.NavActivateDownId = g.NavId
		end
		if (g.ActiveId == 0 or g.ActiveId == g.NavId) and (activate_pressed or input_pressed_keyboard or input_pressed_gamepad) then
			g.NavActivatePressedId = g.NavId
			ImGui.NavHighlightActivated(g.NavId)
		end
	end
	if g.NavWindow and bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs) then
		g.NavCursorVisible = false
	elseif g.IO.ConfigNavCursorVisibleAlways and g.NavCursorHideFrames == 0 then
		g.NavCursorVisible = true
	end
	if g.NavActivateId ~= 0 then
		assert(g.NavActivateDownId == g.NavActivateId)
	end

	if g.NavHighlightActivatedTimer > 0.0 then
		g.NavHighlightActivatedTimer = ImMax(0.0, g.NavHighlightActivatedTimer - io.DeltaTime)
	end
	if g.NavHighlightActivatedTimer == 0.0 then
		g.NavHighlightActivatedId = 0
	end

	if g.NavNextActivateId ~= 0 then
		g.NavActivateId = g.NavNextActivateId
		g.NavActivateDownId = g.NavNextActivateId
		g.NavActivatePressedId = g.NavNextActivateId
		g.NavActivateFlags = g.NavNextActivateFlags
	end
	g.NavNextActivateId = 0

	ImGui.NavUpdateCreateMoveRequest()
	if g.NavMoveDir == ImGuiDir.None then
		ImGui.NavUpdateCreateTabbingRequest()
	end
	ImGui.NavUpdateAnyRequestFlag()
	g.NavIdIsAlive = false

	if g.NavWindow and not bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs) and not g.NavWindowingTarget then
		local window = g.NavWindow
		local scroll_speed = IM_ROUND(window.FontRefSize * 100 * io.DeltaTime)
		local move_dir = g.NavMoveDir
		if window.DC.NavLayersActiveMask == 0x00 and window.DC.NavWindowHasScrollY and move_dir ~= ImGuiDir.None then
			if move_dir == ImGuiDir.Left or move_dir == ImGuiDir.Right then
				ImGui.SetScrollX(window, ImTrunc(window.Scroll.x + (if move_dir == ImGuiDir.Left then -1.0 else 1.0) * scroll_speed))
			end
			if move_dir == ImGuiDir.Up or move_dir == ImGuiDir.Down then
				ImGui.SetScrollY(window, ImTrunc(window.Scroll.y + (if move_dir == ImGuiDir.Up then -1.0 else 1.0) * scroll_speed))
			end
		end

		if nav_gamepad_active then
			local scroll_dir = ImGui.GetKeyMagnitude2d(ImGuiKey.GamepadLStickLeft, ImGuiKey.GamepadLStickRight, ImGuiKey.GamepadLStickUp, ImGuiKey.GamepadLStickDown)
			local tweak_factor = if ImGui.IsKeyDown(ImGuiKey.NavGamepadTweakSlow) then 1.0 / 10.0 elseif ImGui.IsKeyDown(ImGuiKey.NavGamepadTweakFast) then 10.0 else 1.0
			if scroll_dir.x ~= 0.0 and window.ScrollbarX then
				ImGui.SetScrollX(window, ImTrunc(window.Scroll.x + scroll_dir.x * scroll_speed * tweak_factor))
			end
			if scroll_dir.y ~= 0.0 then
				ImGui.SetScrollY(window, ImTrunc(window.Scroll.y + scroll_dir.y * scroll_speed * tweak_factor))
			end
		end
	end

	if not nav_keyboard_active and not nav_gamepad_active then
		g.NavCursorVisible = false
		g.NavHighlightItemUnderNav = false
		set_mouse_pos = false
	end

	if set_mouse_pos and io.ConfigNavMoveSetMousePos and bit32.btest(io.BackendFlags, ImGuiBackendFlags.HasSetMousePos) then
		ImGui.TeleportMousePos(ImGui.NavCalcPreferredRefPos(ImGuiWindowFlags.Popup))
	end

	g.NavScoringDebugCount = 0
end

function ImGui.NavInitRequestApplyResult()
	local g = ImGui.GImGui
	if not g.NavWindow then
		return
	end

	local result = g.NavInitResult
	if g.NavId ~= result.ID then
		g.NavJustMovedFromFocusScopeId = g.NavFocusScopeId
		g.NavJustMovedToId = result.ID
		g.NavJustMovedToFocusScopeId = result.FocusScopeId
		g.NavJustMovedToKeyMods = 0
		g.NavJustMovedToIsTabbing = false
		g.NavJustMovedToIsInit = true
		g.NavJustMovedToHasSelectionData = bit32.band(result.ItemFlags, ImGuiItemFlags.HasSelectionUserData) ~= 0
	end

	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
		ImGui.DebugLog("[nav] NavInitRequest: ApplyResult: NavID 0x%08X in Layer %d Window \"%s\"\n", result.ID, g.NavLayer, g.NavWindow.Name)
	end
	ImGui.SetNavID(result.ID, g.NavLayer, result.FocusScopeId, result.RectRel)
	g.NavIdIsAlive = true
	if result.SelectionUserData ~= ImGuiSelectionUserData.Invalid then
		g.NavLastValidSelectionUserData = result.SelectionUserData
	end
	if g.NavInitRequestFromMove then
		ImGui.SetNavCursorVisibleAfterMove()
	end
end

local function NavBiasScoringRect(r, preferred_pos_rel, move_dir, move_flags)
	local g = ImGui.GImGui
	local rel_to_abs_offset = g.NavWindow.DC.CursorStartPos

	if bit32.band(move_flags, ImGuiNavMoveFlags.Forwarded) == 0 then
		if preferred_pos_rel.x == FLT_MAX then
			preferred_pos_rel = ImVec2(ImMin(r.Min.x + 1.0, r.Max.x) - rel_to_abs_offset.x, preferred_pos_rel.y)
		end
		if preferred_pos_rel.y == FLT_MAX then
			preferred_pos_rel = ImVec2(preferred_pos_rel.x, r:GetCenter().y - rel_to_abs_offset.y)
		end
	end

	if (move_dir == ImGuiDir.Up or move_dir == ImGuiDir.Down) and preferred_pos_rel.x ~= FLT_MAX then
		local x = preferred_pos_rel.x + rel_to_abs_offset.x
		r = ImRect.fromXY(x, r.Min.y, x, r.Max.y)
	elseif (move_dir == ImGuiDir.Left or move_dir == ImGuiDir.Right) and preferred_pos_rel.y ~= FLT_MAX then
		local y = preferred_pos_rel.y + rel_to_abs_offset.y
		r = ImRect.fromXY(r.Min.x, y, r.Max.x, y)
	end
	return r, preferred_pos_rel
end

function ImGui.NavUpdateCreateMoveRequest()
	local g = ImGui.GImGui
	local io = g.IO
	local window = g.NavWindow
	local nav_gamepad_active = bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0 and bit32.band(io.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0
	local nav_keyboard_active = bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0

	if g.NavMoveForwardToNextFrame and window ~= nil then
		assert(g.NavMoveDir ~= ImGuiDir.None and g.NavMoveClipDir ~= ImGuiDir.None)
		assert(bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.Forwarded))
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
			ImGui.DebugLog("[nav] NavMoveRequestForward %d\n", g.NavMoveDir)
		end
	else
		g.NavMoveDir = ImGuiDir.None
		g.NavMoveFlags = ImGuiNavMoveFlags.None
		g.NavMoveScrollFlags = ImGuiScrollFlags.None
		if window and not g.NavWindowingTarget and not bit32.btest(window.Flags, ImGuiWindowFlags.NoNavInputs) then
			local repeat_mode = bit32.bor(ImGuiInputFlags.Repeat, ImGuiInputFlags.RepeatRateNavMove)
			if not ImGui.IsActiveIdUsingNavDir(ImGuiDir.Left) and ((nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey.GamepadDpadLeft, repeat_mode, ImGuiKeyOwner.NoOwner)) or (nav_keyboard_active and ImGui.IsKeyPressed(ImGuiKey.LeftArrow, repeat_mode, ImGuiKeyOwner.NoOwner))) then
				g.NavMoveDir = ImGuiDir.Left
			end
			if not ImGui.IsActiveIdUsingNavDir(ImGuiDir.Right) and ((nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey.GamepadDpadRight, repeat_mode, ImGuiKeyOwner.NoOwner)) or (nav_keyboard_active and ImGui.IsKeyPressed(ImGuiKey.RightArrow, repeat_mode, ImGuiKeyOwner.NoOwner))) then
				g.NavMoveDir = ImGuiDir.Right
			end
			if not ImGui.IsActiveIdUsingNavDir(ImGuiDir.Up) and ((nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey.GamepadDpadUp, repeat_mode, ImGuiKeyOwner.NoOwner)) or (nav_keyboard_active and ImGui.IsKeyPressed(ImGuiKey.UpArrow, repeat_mode, ImGuiKeyOwner.NoOwner))) then
				g.NavMoveDir = ImGuiDir.Up
			end
			if not ImGui.IsActiveIdUsingNavDir(ImGuiDir.Down) and ((nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey.GamepadDpadDown, repeat_mode, ImGuiKeyOwner.NoOwner)) or (nav_keyboard_active and ImGui.IsKeyPressed(ImGuiKey.DownArrow, repeat_mode, ImGuiKeyOwner.NoOwner))) then
				g.NavMoveDir = ImGuiDir.Down
			end
		end
		g.NavMoveClipDir = g.NavMoveDir
		g.NavScoringNoClipRect = ImRect.fromXY(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
	end

	local scoring_page_offset_y = 0.0
	if window and g.NavMoveDir == ImGuiDir.None and nav_keyboard_active then
		scoring_page_offset_y = ImGui.NavUpdatePageUpPageDown()
	end

	g.NavMoveForwardToNextFrame = false
	if g.NavMoveDir ~= ImGuiDir.None then
		ImGui.NavMoveRequestSubmit(g.NavMoveDir, g.NavMoveClipDir, g.NavMoveFlags, g.NavMoveScrollFlags)
	end

	if g.NavMoveSubmitted and g.NavId == 0 then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
			ImGui.DebugLog("[nav] NavInitRequest: from move, window \"%s\", layer=%d\n", window and window.Name or "<NULL>", g.NavLayer)
		end
		g.NavInitRequest = true
		g.NavInitRequestFromMove = true
		g.NavInitResult.ID = 0
		if g.IO.ConfigNavCursorVisibleAuto then
			g.NavCursorVisible = true
		end
	end

	if g.NavMoveSubmitted and g.NavInputSource == ImGuiInputSource.Gamepad and g.NavLayer == ImGuiNavLayer.Main and window ~= nil then
		local clamp_x = bit32.band(g.NavMoveFlags, bit32.bor(ImGuiNavMoveFlags.LoopX, ImGuiNavMoveFlags.WrapX)) == 0
		local clamp_y = bit32.band(g.NavMoveFlags, bit32.bor(ImGuiNavMoveFlags.LoopY, ImGuiNavMoveFlags.WrapY)) == 0
		local inner_rect_rel = ImGui.WindowRectAbsToRel(window, ImRect.new(window.InnerRect.Min - ImVec2(1, 1), window.InnerRect.Max + ImVec2(1, 1)))

		inner_rect_rel = inner_rect_rel:Translated(ImGui.CalcNextScrollFromScrollTargetAndClamp(window) - window.Scroll)

		if (clamp_x or clamp_y) and not inner_rect_rel:Contains(window.NavRectRel[g.NavLayer + 1]) then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
				ImGui.DebugLog("[nav] NavMoveRequest: clamp NavRectRel for gamepad move\n")
			end
			local pad_x = ImMin(inner_rect_rel:GetWidth(), window.FontRefSize * 0.5)
			local pad_y = ImMin(inner_rect_rel:GetHeight(), window.FontRefSize * 0.5)
			inner_rect_rel = ImRect.fromXY(
				if clamp_x then (inner_rect_rel.Min.x + pad_x) else -FLT_MAX,
				if clamp_y then (inner_rect_rel.Min.y + pad_y) else -FLT_MAX,
				if clamp_x then (inner_rect_rel.Max.x - pad_x) else FLT_MAX,
				if clamp_y then (inner_rect_rel.Max.y - pad_y) else FLT_MAX
			)
			window.NavRectRel[g.NavLayer + 1] = window.NavRectRel[g.NavLayer + 1]:ClippedWithFull(inner_rect_rel)
			g.NavId = 0
		end
	end

	local scoring_rect = ImRect.new()
	if window ~= nil then
		local nav_rect_rel = if not window.NavRectRel[g.NavLayer + 1]:IsInverted() then window.NavRectRel[g.NavLayer + 1] else ImRect.fromXY(0, 0, 0, 0)
		scoring_rect = ImGui.WindowRectRelToAbs(window, nav_rect_rel)

		if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsPageMove) then
			if window.InnerRect:Contains(scoring_rect) then
				g.NavMoveFlags = bit32.bor(g.NavMoveFlags, ImGuiNavMoveFlags.AlsoScoreVisibleSet)
			end
			g.NavScoringNoClipRect = scoring_rect
			scoring_rect = scoring_rect:TranslatedY(scoring_page_offset_y)
			g.NavScoringNoClipRect = g.NavScoringNoClipRect:Added(scoring_rect)
		end

		if g.NavMoveSubmitted then
			local root = window.RootWindowForNav
			local layer = g.NavLayer + 1
			scoring_rect, root.NavPreferredScoringPosRel[layer] = NavBiasScoringRect(scoring_rect, root.NavPreferredScoringPosRel[layer], g.NavMoveDir, g.NavMoveFlags)
		end
		assert(not scoring_rect:IsInverted())
	end
	g.NavScoringRect = scoring_rect
end

function ImGui.NavUpdateCreateTabbingRequest()
	local g = ImGui.GImGui
	local window = g.NavWindow
	assert(g.NavMoveDir == ImGuiDir.None)
	if window == nil or g.NavWindowingTarget ~= nil or bit32.btest(window.Flags, ImGuiWindowFlags.NoNavInputs) or not g.ConfigNavEnableTabbing then
		return
	end

	local tab_pressed = ImGui.IsKeyPressed(ImGuiKey.Tab, ImGuiInputFlags.Repeat, ImGuiKeyOwner.NoOwner) and not g.IO.KeyCtrl and not g.IO.KeyAlt
	if not tab_pressed then
		return
	end

	local nav_keyboard_active = bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0
	if nav_keyboard_active then
		g.NavTabbingDir = if g.IO.KeyShift then -1 elseif g.NavCursorVisible == false and g.ActiveId == 0 then 0 else 1
	else
		g.NavTabbingDir = if g.IO.KeyShift then -1 elseif g.ActiveId == 0 then 0 else 1
	end
	local move_flags = bit32.bor(ImGuiNavMoveFlags.IsTabbing, ImGuiNavMoveFlags.Activate)
	local scroll_flags = if window.Appearing then bit32.bor(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.AlwaysCenterY) else bit32.bor(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.KeepVisibleEdgeY)
	local clip_dir = if g.NavTabbingDir < 0 then ImGuiDir.Up else ImGuiDir.Down
	ImGui.NavMoveRequestSubmit(ImGuiDir.None, clip_dir, move_flags, scroll_flags)
	g.NavTabbingCounter = -1
end

function ImGui.NavMoveRequestApplyResult()
	local g = ImGui.GImGui

	local result = if g.NavMoveResultLocal.ID ~= 0 then g.NavMoveResultLocal elseif g.NavMoveResultOther.ID ~= 0 then g.NavMoveResultOther else nil

	if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) and result == nil then
		if (g.NavTabbingCounter == 1 or g.NavTabbingDir == 0) and g.NavTabbingResultFirst.ID ~= 0 then
			result = g.NavTabbingResultFirst
		end
	end

	local axis = if g.NavMoveDir == ImGuiDir.Up or g.NavMoveDir == ImGuiDir.Down then ImGuiAxis.Y else ImGuiAxis.X
	if result == nil then
		if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) then
			g.NavMoveFlags = bit32.bor(g.NavMoveFlags, ImGuiNavMoveFlags.NoSetNavCursorVisible)
		end
		if g.NavId ~= 0 and bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.NoSetNavCursorVisible) == 0 then
			ImGui.SetNavCursorVisibleAfterMove()
		end
		ImGui.NavClearPreferredPosForAxis(axis)
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
			ImGui.DebugLog("[nav] NavMoveSubmitted but not led to a result!\n")
		end
		return
	end

	if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.AlsoScoreVisibleSet) then
		if g.NavMoveResultLocalVisible.ID ~= 0 and g.NavMoveResultLocalVisible.ID ~= g.NavId then
			result = g.NavMoveResultLocalVisible
		end
	end

	if result ~= g.NavMoveResultOther and g.NavMoveResultOther.ID ~= 0 and g.NavMoveResultOther.Window.ParentWindow == g.NavWindow then
		if (g.NavMoveResultOther.DistBox < result.DistBox) or (g.NavMoveResultOther.DistBox == result.DistBox and g.NavMoveResultOther.DistCenter < result.DistCenter) then
			result = g.NavMoveResultOther
		end
	end
	assert(g.NavWindow and result.Window)

	if g.NavLayer == ImGuiNavLayer.Main then
		local rect_abs = ImGui.WindowRectRelToAbs(result.Window, result.RectRel)
		ImGui.ScrollToRectEx(result.Window, rect_abs, g.NavMoveScrollFlags)

		if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.ScrollToEdgeY) then
			local scroll_target = if g.NavMoveDir == ImGuiDir.Up then result.Window.ScrollMax.y else 0.0
			ImGui.SetScrollY(result.Window, scroll_target)
		end
	end

	if g.NavWindow ~= result.Window then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFocus) then
			ImGui.DebugLog("[focus] NavMoveRequest: SetNavWindow(\"%s\")\n", result.Window.Name)
		end
		g.NavWindow = result.Window
		g.NavLastValidSelectionUserData = ImGuiSelectionUserData.Invalid
	end

	if g.ActiveId ~= result.ID and bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.NoClearActiveId) == 0 then
		ImGui.ClearActiveID()
	end

	if (g.NavId ~= result.ID or bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsPageMove)) and bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.NoSelect) == 0 then
		g.NavJustMovedFromFocusScopeId = g.NavFocusScopeId
		g.NavJustMovedToId = result.ID
		g.NavJustMovedToFocusScopeId = result.FocusScopeId
		g.NavJustMovedToKeyMods = g.NavMoveKeyMods
		g.NavJustMovedToIsTabbing = bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) ~= 0
		g.NavJustMovedToIsInit = false
		g.NavJustMovedToHasSelectionData = bit32.band(result.ItemFlags, ImGuiItemFlags.HasSelectionUserData) ~= 0
	end

	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
		ImGui.DebugLog("[nav] NavMoveRequest: result NavID 0x%08X in Layer %d Window \"%s\"\n", result.ID, g.NavLayer, g.NavWindow.Name)
	end
	local preferred_scoring_pos_rel = g.NavWindow.RootWindowForNav.NavPreferredScoringPosRel[g.NavLayer + 1]
	ImGui.SetNavID(result.ID, g.NavLayer, result.FocusScopeId, result.RectRel)
	if result.SelectionUserData ~= ImGuiSelectionUserData.Invalid then
		g.NavLastValidSelectionUserData = result.SelectionUserData
	end

	if bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) == 0 then
		preferred_scoring_pos_rel = VecWithAxis(preferred_scoring_pos_rel, axis, VecGetAxis(result.RectRel:GetCenter(), axis))
		g.NavWindow.RootWindowForNav.NavPreferredScoringPosRel[g.NavLayer + 1] = preferred_scoring_pos_rel
	end

	if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) and bit32.band(result.ItemFlags, ImGuiItemFlags.Inputable) == 0 then
		g.NavMoveFlags = bit32.band(g.NavMoveFlags, bit32.bnot(ImGuiNavMoveFlags.Activate))
	end

	if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.Activate) then
		g.NavNextActivateId = result.ID
		g.NavNextActivateFlags = ImGuiActivateFlags.None
		if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.FocusApi) then
			g.NavNextActivateFlags = bit32.bor(g.NavNextActivateFlags, ImGuiActivateFlags.FromFocusApi)
		end
		if bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.IsTabbing) then
			g.NavNextActivateFlags = bit32.bor(g.NavNextActivateFlags, ImGuiActivateFlags.PreferInput, ImGuiActivateFlags.TryToPreserveState, ImGuiActivateFlags.FromTabbing)
		end
	end

	if bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.NoSetNavCursorVisible) == 0 then
		ImGui.SetNavCursorVisibleAfterMove()
	end
end

function ImGui.NavUpdateCancelRequest()
	local g = ImGui.GImGui
	local nav_gamepad_active = bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0 and bit32.band(g.IO.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0
	local nav_keyboard_active = bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0
	local ImGuiKey_NavGamepadCancel = if g.IO.ConfigNavSwapGamepadButtons then ImGuiKey.GamepadFaceDown else ImGuiKey.GamepadFaceRight
	if not (nav_keyboard_active and ImGui.IsKeyPressed(ImGuiKey.Escape, 0, ImGuiKeyOwner.NoOwner)) and not (nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey_NavGamepadCancel, 0, ImGuiKeyOwner.NoOwner)) then
		return
	end

	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventNav) then
		ImGui.DebugLog("[nav] NavUpdateCancelRequest()\n")
	end
	if g.ActiveId ~= 0 then
		ImGui.ClearActiveID()
	elseif g.NavLayer ~= ImGuiNavLayer.Main then
		ImGui.NavRestoreLayer(ImGuiNavLayer.Main)
		ImGui.SetNavCursorVisibleAfterMove()
	elseif g.NavWindow and g.NavWindow ~= g.NavWindow.RootWindow and not bit32.btest(g.NavWindow.RootWindowForNav.Flags, ImGuiWindowFlags.Popup) and g.NavWindow.RootWindowForNav.ParentWindow then
		local child_window = g.NavWindow.RootWindowForNav
		local parent_window = child_window.ParentWindow
		assert(child_window.ChildId ~= 0)
		ImGui.FocusWindow(parent_window)
		ImGui.SetNavID(child_window.ChildId, ImGuiNavLayer.Main, 0, ImGui.WindowRectAbsToRel(parent_window, child_window:Rect()))
		ImGui.SetNavCursorVisibleAfterMove()
	elseif g.OpenPopupStack.Size > 0 and g.OpenPopupStack:back().Window ~= nil and not bit32.btest(g.OpenPopupStack:back().Window.Flags, ImGuiWindowFlags.Modal) then
		ImGui.ClosePopupToLevel(g.OpenPopupStack.Size - 1, true)
	else
		if g.IO.ConfigNavEscapeClearFocusItem or g.IO.ConfigNavEscapeClearFocusWindow then
			if g.NavWindow and bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.Popup) then
				g.NavWindow.NavLastIds[1] = 0
			end
		end

		if g.IO.ConfigNavEscapeClearFocusItem or g.IO.ConfigNavEscapeClearFocusWindow then
			g.NavId = 0
		end
		if g.IO.ConfigNavEscapeClearFocusWindow then
			ImGui.FocusWindow(nil)
		end
	end
end

function ImGui.NavUpdateContextMenuRequest()
	local g = ImGui.GImGui
	g.NavOpenContextMenuItemId = 0
	g.NavOpenContextMenuWindowId = 0
	local nav_keyboard_active = bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0
	local nav_gamepad_active = bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0
	if (not nav_keyboard_active and not nav_gamepad_active) or g.NavWindow == nil then
		return
	end

	local request = false
	request = request or (nav_keyboard_active and (ImGui.IsKeyReleased(ImGuiKey.Menu, ImGuiKeyOwner.NoOwner) or (ImGui.IsKeyPressed(ImGuiKey.F10, ImGuiInputFlags.None, ImGuiKeyOwner.NoOwner) and g.IO.KeyMods == ImGuiMod.Shift)))
	request = request or (nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey.NavGamepadContextMenu, ImGuiInputFlags.None, ImGuiKeyOwner.NoOwner))
	if not request then
		return
	end
	g.NavOpenContextMenuItemId = g.NavId
	g.NavOpenContextMenuWindowId = g.NavWindow.ID

	if g.NavId == g.NavWindow:GetID("#CLOSE") or g.NavId == g.NavWindow:GetID("#COLLAPSE") then
		g.NavOpenContextMenuItemId = g.NavWindow.MoveId
	end

	g.NavInputSource = ImGuiInputSource.Keyboard
	ImGui.SetNavCursorVisibleAfterMove()
end

function ImGui.NavUpdatePageUpPageDown()
	local g = ImGui.GImGui
	local window = g.NavWindow
	if bit32.btest(window.Flags, ImGuiWindowFlags.NoNavInputs) or g.NavWindowingTarget ~= nil then
		return 0.0
	end

	local page_up_held = ImGui.IsKeyDown(ImGuiKey.PageUp, ImGuiKeyOwner.NoOwner)
	local page_down_held = ImGui.IsKeyDown(ImGuiKey.PageDown, ImGuiKeyOwner.NoOwner)
	local home_pressed = ImGui.IsKeyPressed(ImGuiKey.Home, ImGuiInputFlags.Repeat, ImGuiKeyOwner.NoOwner)
	local end_pressed = ImGui.IsKeyPressed(ImGuiKey.End, ImGuiInputFlags.Repeat, ImGuiKeyOwner.NoOwner)
	if page_up_held == page_down_held and home_pressed == end_pressed then
		return 0.0
	end

	if g.NavLayer ~= ImGuiNavLayer.Main then
		ImGui.NavRestoreLayer(ImGuiNavLayer.Main)
	end

	if bit32.band(window.DC.NavLayersActiveMask, bit32.lshift(1, ImGuiNavLayer.Main)) == 0 and window.DC.NavWindowHasScrollY then
		if ImGui.IsKeyPressed(ImGuiKey.PageUp, ImGuiInputFlags.Repeat, ImGuiKeyOwner.NoOwner) then
			ImGui.SetScrollY(window, window.Scroll.y - window.InnerRect:GetHeight())
		elseif ImGui.IsKeyPressed(ImGuiKey.PageDown, ImGuiInputFlags.Repeat, ImGuiKeyOwner.NoOwner) then
			ImGui.SetScrollY(window, window.Scroll.y + window.InnerRect:GetHeight())
		elseif home_pressed then
			ImGui.SetScrollY(window, 0.0)
		elseif end_pressed then
			ImGui.SetScrollY(window, window.ScrollMax.y)
		end
	else
		local layer = g.NavLayer + 1
		local nav_rect_rel = window.NavRectRel[layer]
		local page_offset_y = ImMax(0.0, window.InnerRect:GetHeight() - window.FontRefSize * 1.0 + nav_rect_rel:GetHeight())
		local nav_scoring_rect_offset_y = 0.0
		if ImGui.IsKeyPressed(ImGuiKey.PageUp, true) then
			nav_scoring_rect_offset_y = -page_offset_y
			g.NavMoveDir = ImGuiDir.Down
			g.NavMoveClipDir = ImGuiDir.Up
			g.NavMoveFlags = bit32.bor(ImGuiNavMoveFlags.AllowCurrentNavId, ImGuiNavMoveFlags.IsPageMove)
		elseif ImGui.IsKeyPressed(ImGuiKey.PageDown, true) then
			nav_scoring_rect_offset_y = page_offset_y
			g.NavMoveDir = ImGuiDir.Up
			g.NavMoveClipDir = ImGuiDir.Down
			g.NavMoveFlags = bit32.bor(ImGuiNavMoveFlags.AllowCurrentNavId, ImGuiNavMoveFlags.IsPageMove)
		elseif home_pressed then
			nav_rect_rel = ImRect.fromXY(nav_rect_rel.Min.x, 0.0, nav_rect_rel.Max.x, 0.0)
			if nav_rect_rel:IsInverted() then
				nav_rect_rel = ImRect.fromXY(0.0, nav_rect_rel.Min.y, 0.0, nav_rect_rel.Max.y)
			end
			window.NavRectRel[layer] = nav_rect_rel
			g.NavMoveDir = ImGuiDir.Down
			g.NavMoveFlags = bit32.bor(ImGuiNavMoveFlags.AllowCurrentNavId, ImGuiNavMoveFlags.ScrollToEdgeY)
		elseif end_pressed then
			local y = window.ContentSize.y
			nav_rect_rel = ImRect.fromXY(nav_rect_rel.Min.x, y, nav_rect_rel.Max.x, y)
			if nav_rect_rel:IsInverted() then
				nav_rect_rel = ImRect.fromXY(0.0, nav_rect_rel.Min.y, 0.0, nav_rect_rel.Max.y)
			end
			window.NavRectRel[layer] = nav_rect_rel
			g.NavMoveDir = ImGuiDir.Up
			g.NavMoveFlags = bit32.bor(ImGuiNavMoveFlags.AllowCurrentNavId, ImGuiNavMoveFlags.ScrollToEdgeY)
		end
		return nav_scoring_rect_offset_y
	end
	return 0.0
end

function ImGui.NavEndFrame()
	local g = ImGui.GImGui

	if g.NavWindowingTarget ~= nil then
		ImGui.NavUpdateWindowingOverlay()
	end

	if g.NavWindow and ImGui.NavMoveRequestButNoResultYet() and bit32.btest(g.NavMoveFlags, ImGuiNavMoveFlags.WrapMask_) and bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.Forwarded) == 0 then
		ImGui.NavUpdateCreateWrappingRequest()
	end
end

function ImGui.NavUpdateCreateWrappingRequest()
	local g = ImGui.GImGui
	local window = g.NavWindow

	local do_forward = false
	local bb_rel = window.NavRectRel[g.NavLayer + 1]
	local clip_dir = g.NavMoveDir

	local move_flags = g.NavMoveFlags

	local wrap_size = if g.NavLayer == ImGuiNavLayer.Menu then window.Size else window.ContentSize + window.WindowPadding

	if g.NavMoveDir == ImGuiDir.Left and bit32.btest(move_flags, bit32.bor(ImGuiNavMoveFlags.WrapX, ImGuiNavMoveFlags.LoopX)) then
		bb_rel = ImRect.fromXY(wrap_size.x, bb_rel.Min.y, wrap_size.x, bb_rel.Max.y)
		if bit32.btest(move_flags, ImGuiNavMoveFlags.WrapX) then
			bb_rel = bb_rel:TranslatedY(-bb_rel:GetHeight())
			clip_dir = ImGuiDir.Up
		end
		do_forward = true
	end
	if g.NavMoveDir == ImGuiDir.Right and bit32.btest(move_flags, bit32.bor(ImGuiNavMoveFlags.WrapX, ImGuiNavMoveFlags.LoopX)) then
		bb_rel = ImRect.fromXY(-window.WindowPadding.x, bb_rel.Min.y, -window.WindowPadding.x, bb_rel.Max.y)
		if bit32.btest(move_flags, ImGuiNavMoveFlags.WrapX) then
			bb_rel = bb_rel:TranslatedY(bb_rel:GetHeight())
			clip_dir = ImGuiDir.Down
		end
		do_forward = true
	end
	if g.NavMoveDir == ImGuiDir.Up and bit32.btest(move_flags, bit32.bor(ImGuiNavMoveFlags.WrapY, ImGuiNavMoveFlags.LoopY)) then
		bb_rel = ImRect.fromXY(bb_rel.Min.x, wrap_size.y, bb_rel.Max.x, wrap_size.y)
		if bit32.btest(move_flags, ImGuiNavMoveFlags.WrapY) then
			bb_rel = bb_rel:TranslatedX(-bb_rel:GetWidth())
			clip_dir = ImGuiDir.Left
		end
		do_forward = true
	end
	if g.NavMoveDir == ImGuiDir.Down and bit32.btest(move_flags, bit32.bor(ImGuiNavMoveFlags.WrapY, ImGuiNavMoveFlags.LoopY)) then
		bb_rel = ImRect.fromXY(bb_rel.Min.x, -window.WindowPadding.y, bb_rel.Max.x, -window.WindowPadding.y)
		if bit32.btest(move_flags, ImGuiNavMoveFlags.WrapY) then
			bb_rel = bb_rel:TranslatedX(bb_rel:GetWidth())
			clip_dir = ImGuiDir.Right
		end
		do_forward = true
	end
	if not do_forward then
		return
	end
	window.NavRectRel[g.NavLayer + 1] = bb_rel
	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
	ImGui.NavClearPreferredPosForAxis(ImGuiAxis.Y)
	ImGui.NavMoveRequestForward(g.NavMoveDir, clip_dir, move_flags, g.NavMoveScrollFlags)
end

function ImGui.IsWindowNavFocusable(window)
	return window.WasActive and window == window.RootWindow and not bit32.btest(window.Flags, ImGuiWindowFlags.NoNavFocus)
end

local function FindWindowNavFocusable(i_start, i_stop, dir)
	local g = ImGui.GImGui
	local i = i_start
	while i >= 0 and i < g.WindowsFocusOrder.Size and i ~= i_stop do
		if ImGui.IsWindowNavFocusable(g.WindowsFocusOrder[i + 1]) then
			return g.WindowsFocusOrder[i + 1]
		end
		i += dir
	end
	return nil
end

local function NavUpdateWindowingTarget(focus_change_dir)
	local g = ImGui.GImGui
	assert(g.NavWindowingTarget)
	if bit32.btest(g.NavWindowingTarget.Flags, ImGuiWindowFlags.Modal) then
		return
	end

	local i_current = ImGui.FindWindowFocusIndex(g.NavWindowingTarget)
	local window_target = FindWindowNavFocusable(i_current + focus_change_dir, -INT_MAX, focus_change_dir)
	if not window_target then
		window_target = FindWindowNavFocusable(if focus_change_dir < 0 then (g.WindowsFocusOrder.Size - 1) else 0, i_current, focus_change_dir)
	end
	if window_target then
		g.NavWindowingTarget = window_target
		g.NavWindowingTargetAnim = window_target
		g.NavWindowingAccumDeltaPos = ImVec2(0.0, 0.0)
		g.NavWindowingAccumDeltaSize = ImVec2(0.0, 0.0)
	end
	g.NavWindowingToggleLayer = false
end

function ImGui.NavUpdateWindowingApplyFocus(apply_focus_window)
	local g = ImGui.GImGui
	if g.NavWindow == nil or apply_focus_window ~= g.NavWindow.RootWindow then
		ImGui.ClearActiveID()
		ImGui.SetNavCursorVisibleAfterMove()
		ImGui.ClosePopupsOverWindow(apply_focus_window, false)
		ImGui.FocusWindow(apply_focus_window, ImGuiFocusRequestFlags.RestoreFocusedChild)
		assert(g.NavWindow ~= nil)
		apply_focus_window = g.NavWindow
		if apply_focus_window.NavLastIds[1] == 0 then
			ImGui.NavInitWindow(apply_focus_window, false)
		end

		if apply_focus_window.DC.NavLayersActiveMaskNext == bit32.lshift(1, ImGuiNavLayer.Menu) then
			g.NavLayer = ImGuiNavLayer.Menu
		end
	end
	g.NavWindowingTarget = nil
end

local windowing_toggle_keys = { ImGuiKey.LeftAlt, ImGuiKey.RightAlt }

function ImGui.NavUpdateWindowing()
	local g = ImGui.GImGui
	local io = g.IO

	local apply_focus_window = nil
	local apply_toggle_layer = false

	local modal_window = ImGui.GetTopMostPopupModal()
	local allow_windowing = (modal_window == nil)
	if not allow_windowing then
		g.NavWindowingTarget = nil
	end

	if g.NavWindowingTargetAnim and g.NavWindowingTarget == nil then
		g.NavWindowingHighlightAlpha = ImMax(g.NavWindowingHighlightAlpha - io.DeltaTime * 10.0, 0.0)
		if g.DimBgRatio <= 0.0 and g.NavWindowingHighlightAlpha <= 0.0 then
			g.NavWindowingTargetAnim = nil
		end
	end

	local owner_id = ImHashStr("##NavUpdateWindowing")
	local nav_gamepad_active = bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0 and bit32.band(io.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0
	local nav_keyboard_active = bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0
	local keyboard_next_window = allow_windowing and g.ConfigNavWindowingKeyNext ~= 0 and ImGui.Shortcut(g.ConfigNavWindowingKeyNext, bit32.bor(ImGuiInputFlags.Repeat, ImGuiInputFlags.RouteAlways), owner_id)
	local keyboard_prev_window = allow_windowing and g.ConfigNavWindowingKeyPrev ~= 0 and ImGui.Shortcut(g.ConfigNavWindowingKeyPrev, bit32.bor(ImGuiInputFlags.Repeat, ImGuiInputFlags.RouteAlways), owner_id)
	local start_toggling_with_gamepad = nav_gamepad_active and not g.NavWindowingTarget and ImGui.Shortcut(ImGuiKey.NavGamepadMenu, ImGuiInputFlags.RouteAlways, owner_id)
	local start_windowing_with_gamepad = allow_windowing and start_toggling_with_gamepad
	local start_windowing_with_keyboard = allow_windowing and not g.NavWindowingTarget and (keyboard_next_window or keyboard_prev_window)
	local just_started_windowing_from_null_focus = false
	if start_toggling_with_gamepad then
		g.NavWindowingToggleLayer = true
		g.NavWindowingToggleKey = ImGuiKey.NavGamepadMenu
		g.NavInputSource = ImGuiInputSource.Gamepad
		g.NavWindowingInputSource = ImGuiInputSource.Gamepad
	end
	if start_windowing_with_gamepad or start_windowing_with_keyboard then
		local window = if g.NavWindow and ImGui.IsWindowNavFocusable(g.NavWindow) then g.NavWindow else FindWindowNavFocusable(g.WindowsFocusOrder.Size - 1, -INT_MAX, -1)
		if window then
			if start_windowing_with_keyboard or g.ConfigNavWindowingWithGamepad then
				g.NavWindowingTarget = window.RootWindow
				g.NavWindowingTargetAnim = window.RootWindow
			end
			g.NavWindowingTimer = 0.0
			g.NavWindowingHighlightAlpha = 0.0
			g.NavWindowingAccumDeltaPos = ImVec2(0.0, 0.0)
			g.NavWindowingAccumDeltaSize = ImVec2(0.0, 0.0)
			g.NavInputSource = if start_windowing_with_keyboard then ImGuiInputSource.Keyboard else ImGuiInputSource.Gamepad
			g.NavWindowingInputSource = g.NavInputSource
			if g.NavWindow == nil then
				just_started_windowing_from_null_focus = true
			end

			if keyboard_next_window or keyboard_prev_window then
				ImGui.SetKeyOwnersForKeyChord(bit32.band(bit32.bor(g.ConfigNavWindowingKeyNext, g.ConfigNavWindowingKeyPrev), ImGuiMod.Mask_), owner_id)
			end
		end
	end

	if (g.NavWindowingTarget or g.NavWindowingToggleLayer) and g.NavWindowingInputSource == ImGuiInputSource.Gamepad then
		if g.NavWindowingTarget ~= nil then
			g.NavWindowingTimer += io.DeltaTime
			g.NavWindowingHighlightAlpha = ImMax(g.NavWindowingHighlightAlpha, ImSaturate((g.NavWindowingTimer - NAV_WINDOWING_HIGHLIGHT_DELAY) / 0.05))

			local focus_change_dir = (if ImGui.IsKeyPressed(ImGuiKey.GamepadL1) then 1 else 0) - (if ImGui.IsKeyPressed(ImGuiKey.GamepadR1) then 1 else 0)
			if focus_change_dir ~= 0 and not just_started_windowing_from_null_focus then
				NavUpdateWindowingTarget(focus_change_dir)
				g.NavWindowingHighlightAlpha = 1.0
			end
		end

		if not ImGui.IsKeyDown(ImGuiKey.NavGamepadMenu) then
			g.NavWindowingToggleLayer = g.NavWindowingToggleLayer and (g.NavWindowingHighlightAlpha < 1.0)
			if g.NavWindowingToggleLayer and g.NavWindow then
				apply_toggle_layer = true
			elseif not g.NavWindowingToggleLayer then
				apply_focus_window = g.NavWindowingTarget
			end
			g.NavWindowingTarget = nil
			g.NavWindowingToggleLayer = false
		end
	end

	if g.NavWindowingTarget and g.NavWindowingInputSource == ImGuiInputSource.Keyboard then
		local next_mods = if g.ConfigNavWindowingKeyNext ~= 0 then g.ConfigNavWindowingKeyNext else ImGuiMod.Mask_
		local prev_mods = if g.ConfigNavWindowingKeyPrev ~= 0 then g.ConfigNavWindowingKeyPrev else ImGuiMod.Mask_
		local shared_mods = bit32.band(next_mods, prev_mods, ImGuiMod.Mask_)
		assert(shared_mods ~= 0)
		g.NavWindowingTimer += io.DeltaTime
		g.NavWindowingHighlightAlpha = ImMax(g.NavWindowingHighlightAlpha, ImSaturate((g.NavWindowingTimer - NAV_WINDOWING_HIGHLIGHT_DELAY) / 0.05))
		if (keyboard_next_window or keyboard_prev_window) and not just_started_windowing_from_null_focus then
			NavUpdateWindowingTarget(if keyboard_next_window then -1 else 1)
		elseif bit32.band(io.KeyMods, shared_mods) ~= shared_mods then
			apply_focus_window = g.NavWindowingTarget
		end
	end

	local windowing_toggle_layer_start = false
	if g.NavWindow ~= nil and not bit32.btest(g.NavWindow.Flags, ImGuiWindowFlags.NoNavInputs) then
		for _, windowing_toggle_key in windowing_toggle_keys do
			if nav_keyboard_active and ImGui.IsKeyPressed(windowing_toggle_key, 0, ImGuiKeyOwner.NoOwner) then
				windowing_toggle_layer_start = true
				g.NavWindowingToggleLayer = true
				g.NavWindowingToggleKey = windowing_toggle_key
				g.NavInputSource = ImGuiInputSource.Keyboard
				g.NavWindowingInputSource = ImGuiInputSource.Keyboard
				break
			end
		end
	end
	if g.NavWindowingToggleLayer and g.NavWindowingInputSource == ImGuiInputSource.Keyboard then
		if io.InputQueueCharacters.Size > 0 or io.KeyCtrl or io.KeyShift or io.KeySuper then
			g.NavWindowingToggleLayer = false
		elseif windowing_toggle_layer_start == false and g.LastKeyboardKeyPressTime == g.Time then
			g.NavWindowingToggleLayer = false
		elseif ImGui.TestKeyOwner(g.NavWindowingToggleKey, ImGuiKeyOwner.NoOwner) == false or ImGui.TestKeyOwner(ImGuiMod.Alt, ImGuiKeyOwner.NoOwner) == false then
			g.NavWindowingToggleLayer = false
		end

		if ImGui.IsKeyReleased(g.NavWindowingToggleKey) and g.NavWindowingToggleLayer then
			if g.ActiveId == 0 or g.ActiveIdAllowOverlap then
				if ImGui.IsMousePosValid(io.MousePos) == ImGui.IsMousePosValid(io.MousePosPrev) then
					apply_toggle_layer = true
				end
			end
		end
		if not ImGui.IsKeyDown(g.NavWindowingToggleKey) then
			g.NavWindowingToggleLayer = false
		end
	end

	if g.NavWindowingTarget and not bit32.btest(g.NavWindowingTarget.Flags, ImGuiWindowFlags.NoMove) then
		local nav_move_dir = ImVec2(0.0, 0.0)
		if g.NavInputSource == ImGuiInputSource.Keyboard and not io.KeyShift then
			nav_move_dir = ImGui.GetKeyMagnitude2d(ImGuiKey.LeftArrow, ImGuiKey.RightArrow, ImGuiKey.UpArrow, ImGuiKey.DownArrow)
		end
		if g.NavInputSource == ImGuiInputSource.Gamepad then
			nav_move_dir = ImGui.GetKeyMagnitude2d(ImGuiKey.GamepadLStickLeft, ImGuiKey.GamepadLStickRight, ImGuiKey.GamepadLStickUp, ImGuiKey.GamepadLStickDown)
		end
		if nav_move_dir.x ~= 0.0 or nav_move_dir.y ~= 0.0 then
			local NAV_MOVE_SPEED = 800.0
			local move_step = NAV_MOVE_SPEED * io.DeltaTime * ImGui.GetScale()
			g.NavWindowingAccumDeltaPos += nav_move_dir * move_step
			g.NavHighlightItemUnderNav = true
			local accum_floored = ImTrunc(g.NavWindowingAccumDeltaPos)
			if accum_floored.x ~= 0.0 or accum_floored.y ~= 0.0 then
				local moving_window = g.NavWindowingTarget.RootWindow
				ImGui.SetWindowPos(moving_window, moving_window.Pos + accum_floored, ImGuiCond.Always)
				g.NavWindowingAccumDeltaPos -= accum_floored
			end
		end
	end

	if apply_focus_window then
		ImGui.NavUpdateWindowingApplyFocus(apply_focus_window)
	end

	if apply_toggle_layer and g.NavWindow then
		ImGui.ClearActiveID()

		local new_nav_window = g.NavWindow
		while new_nav_window.ParentWindow
			and bit32.band(new_nav_window.DC.NavLayersActiveMask, bit32.lshift(1, ImGuiNavLayer.Menu)) == 0
			and bit32.band(new_nav_window.Flags, ImGuiWindowFlags.ChildWindow) ~= 0
			and bit32.band(new_nav_window.Flags, bit32.bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.ChildMenu)) == 0
		do
			new_nav_window = new_nav_window.ParentWindow
		end
		if new_nav_window ~= g.NavWindow then
			local old_nav_window = g.NavWindow
			ImGui.FocusWindow(new_nav_window)
			new_nav_window.NavLastChildNavWindow = old_nav_window
		end

		local new_nav_layer = if bit32.btest(g.NavWindow.DC.NavLayersActiveMask, bit32.lshift(1, ImGuiNavLayer.Menu)) then bit32.bxor(g.NavLayer, 1) else ImGuiNavLayer.Main
		if new_nav_layer ~= g.NavLayer then
			if new_nav_layer == ImGuiNavLayer.Menu then
				g.NavWindow.NavLastIds[new_nav_layer + 1] = 0
			end
			ImGui.NavRestoreLayer(new_nav_layer)
			ImGui.SetNavCursorVisibleAfterMove()
		end
	end
end

local function GetFallbackWindowNameForWindowingList(window)
	if bit32.btest(window.Flags, ImGuiWindowFlags.Popup) then
		return ImGui.LocalizeGetMsg(ImGuiLocKey.WindowingPopup)
	end
	if bit32.btest(window.Flags, ImGuiWindowFlags.MenuBar) and window.Name == "##MainMenuBar" then
		return ImGui.LocalizeGetMsg(ImGuiLocKey.WindowingMainMenuBar)
	end
	return ImGui.LocalizeGetMsg(ImGuiLocKey.WindowingUntitled)
end

function ImGui.NavUpdateWindowingOverlay()
	local g = ImGui.GImGui
	assert(g.NavWindowingTarget ~= nil)

	if g.NavWindowingTimer < NAV_WINDOWING_LIST_APPEAR_DELAY then
		return
	end

	local viewport = ImGui.GetMainViewport()
	ImGui.SetNextWindowSizeConstraints(ImVec2(viewport.Size.x * 0.20, viewport.Size.y * 0.20), ImVec2(FLT_MAX, FLT_MAX))
	ImGui.SetNextWindowPos(viewport:GetCenter(), ImGuiCond.Always, ImVec2(0.5, 0.5))
	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, g.Style.WindowPadding * 2.0)
	ImGui.Begin("##NavWindowingOverlay", nil, bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoInputs, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoSavedSettings))
	g.NavWindowingListWindow = g.CurrentWindow
	if g.ContextName ~= nil and g.ContextName ~= "" then
		ImGui.SeparatorText(g.ContextName)
	end
	for n = g.WindowsFocusOrder.Size - 1, 0, -1 do
		local window = g.WindowsFocusOrder[n + 1]
		assert(window ~= nil)
		if not ImGui.IsWindowNavFocusable(window) then
			continue
		end
		local label = window.Name
		if ImGui.FindRenderedTextEnd(label) == 1 then
			label = GetFallbackWindowNameForWindowingList(window)
		end
		ImGui.Selectable(label, g.NavWindowingTarget == window)
	end
	ImGui.End()
	ImGui.PopStyleVar()
end

return true
