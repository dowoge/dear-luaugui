--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImVec4, ImRect = Base.ImVec2, Base.ImVec4, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImLerp, ImSaturate, ImTrunc, ImFloor, ImFmod = Base.ImLerp, Base.ImSaturate, Base.ImTrunc, Base.ImFloor, Base.ImFmod
local ImTruncToInt, ImFormatString, ImHashStr, ImIsPowerOfTwo, ImQsort =
	Base.ImTruncToInt, Base.ImFormatString, Base.ImHashStr, Base.ImIsPowerOfTwo, Base.ImQsort
local IM_TRUNC, IM_ROUND, IM_COL32_A_MASK = Base.IM_TRUNC, Base.IM_ROUND, Base.IM_COL32_A_MASK
local FLT_MAX, FLT_MIN = Base.FLT_MAX, Base.FLT_MIN

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiComboFlags = Enums.ImGuiComboFlags
local ImGuiSeparatorFlags = Enums.ImGuiSeparatorFlags
local ImGuiTextFlags = Enums.ImGuiTextFlags
local ImGuiNextWindowDataFlags = Enums.ImGuiNextWindowDataFlags
local ImGuiNavRenderCursorFlags = Enums.ImGuiNavRenderCursorFlags
local ImGuiFocusRequestFlags = Enums.ImGuiFocusRequestFlags
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiDragDropFlags = Enums.ImGuiDragDropFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiMultiSelectFlags = Enums.ImGuiMultiSelectFlags
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiPopupPositionPolicy = Enums.ImGuiPopupPositionPolicy
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiLayoutType = Enums.ImGuiLayoutType
local ImGuiLocKey = Enums.ImGuiLocKey
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiKey = Enums.ImGuiKey
local ImGuiAxis = Enums.ImGuiAxis
local ImGuiDir = Enums.ImGuiDir
local ImGuiCol = Enums.ImGuiCol
local ImDrawFlags = Enums.ImDrawFlags

local DRAGDROP_HOLD_TO_OPEN_TIMER = 0.70
ImGui.DRAGDROP_HOLD_TO_OPEN_TIMER = DRAGDROP_HOLD_TO_OPEN_TIMER
ImGui.DRAG_MOUSE_THRESHOLD_FACTOR = 0.50
ImGui.IM_S8_MIN = -128
ImGui.IM_S8_MAX = 127
ImGui.IM_U8_MIN = 0
ImGui.IM_U8_MAX = 0xFF
ImGui.IM_S16_MIN = -32768
ImGui.IM_S16_MAX = 32767
ImGui.IM_U16_MIN = 0
ImGui.IM_U16_MAX = 0xFFFF
ImGui.IM_S32_MIN = -2147483648
ImGui.IM_S32_MAX = 2147483647
ImGui.IM_U32_MIN = 0
ImGui.IM_U32_MAX = 0xFFFFFFFF
ImGui.IM_S64_MIN = -(2 ^ 63)
ImGui.IM_S64_MAX = 2 ^ 63 - 1
ImGui.IM_U64_MIN = 0
ImGui.IM_U64_MAX = 2 ^ 64 - 1

local function VecAxis(v, axis)
	if axis == ImGuiAxis.X then
		return v.x
	end
	return v.y
end

local function VecWithAxis(v, axis, value)
	if axis == ImGuiAxis.X then
		return ImVec2(value, v.y)
	end
	return ImVec2(v.x, value)
end

local function FormatText(fmt, ...)
	if select("#", ...) == 0 then
		return fmt
	end
	return ImFormatString(fmt, ...)
end

function ImGui.TextEx(text, text_end, flags)
	if flags == nil then
		flags = 0
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end
	local g = ImGui.GImGui

	if text_end == 1 then
		text = ""
		text_end = 1
	end

	local text_begin = 1
	if text_end == nil then
		text_end = #text + 1
	end

	local text_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)
	local wrap_pos_x = window.DC.TextWrapPos
	local wrap_enabled = wrap_pos_x >= 0.0
	if text_end - text_begin <= 2000 or wrap_enabled then
		local wrap_width = wrap_enabled and ImGui.CalcWrapWidthForPos(window.DC.CursorPos, wrap_pos_x) or 0.0
		local text_size = ImGui.CalcTextSize(text, text_end, false, wrap_width)

		local bb = ImRect.new(text_pos, text_pos + text_size)
		ImGui.ItemSize(text_size, 0.0)
		if not ImGui.ItemAdd(bb, 0) then
			return
		end

		ImGui.RenderTextWrapped(bb.Min, text, text_end, wrap_width)
	else
		local line = text_begin
		local line_height = ImGui.GetTextLineHeight()
		local text_size_x = 0.0

		local pos = text_pos
		if not g.LogEnabled then
			local lines_skippable = ImTruncToInt((window.ClipRect.Min.y - text_pos.y) / line_height)
			if lines_skippable > 0 then
				local lines_skipped = 0
				while line < text_end and lines_skipped < lines_skippable do
					local line_end = string.find(text, "\n", line, true)
					if line_end == nil or line_end >= text_end then
						line_end = text_end
					end
					if bit32.band(flags, ImGuiTextFlags.NoWidthForLargeClippedText) == 0 then
						text_size_x = ImMax(text_size_x, ImGui.CalcTextSize(string.sub(text, line, line_end - 1)).x)
					end
					line = line_end + 1
					lines_skipped += 1
				end
				pos = ImVec2(pos.x, pos.y + lines_skipped * line_height)
			end
		end

		if line < text_end then
			local line_rect = ImRect.new(pos, pos + ImVec2(FLT_MAX, line_height))
			while line < text_end do
				if ImGui.IsClippedEx(line_rect, 0) then
					break
				end

				local line_end = string.find(text, "\n", line, true)
				if line_end == nil or line_end >= text_end then
					line_end = text_end
				end
				local line_text = string.sub(text, line, line_end - 1)
				text_size_x = ImMax(text_size_x, ImGui.CalcTextSize(line_text).x)
				ImGui.RenderText(pos, line_text, nil, false)
				line = line_end + 1
				line_rect = line_rect:TranslatedY(line_height)
				pos = ImVec2(pos.x, pos.y + line_height)
			end

			local lines_skipped = 0
			while line < text_end do
				local line_end = string.find(text, "\n", line, true)
				if line_end == nil or line_end >= text_end then
					line_end = text_end
				end
				if bit32.band(flags, ImGuiTextFlags.NoWidthForLargeClippedText) == 0 then
					text_size_x = ImMax(text_size_x, ImGui.CalcTextSize(string.sub(text, line, line_end - 1)).x)
				end
				line = line_end + 1
				lines_skipped += 1
			end
			pos = ImVec2(pos.x, pos.y + lines_skipped * line_height)
		end
		local text_size = ImVec2(text_size_x, (pos - text_pos).y)

		local bb = ImRect.new(text_pos, text_pos + text_size)
		ImGui.ItemSize(text_size, 0.0)
		ImGui.ItemAdd(bb, 0)
	end
end

function ImGui.TextUnformatted(text, text_end)
	ImGui.TextEx(text, text_end, ImGuiTextFlags.NoWidthForLargeClippedText)
end

function ImGui.Text(fmt, ...)
	ImGui.TextV(fmt, ...)
end

function ImGui.TextV(fmt, ...)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local text = FormatText(fmt, ...)
	ImGui.TextEx(text, #text + 1, ImGuiTextFlags.NoWidthForLargeClippedText)
end

function ImGui.TextColored(col, fmt, ...)
	ImGui.TextColoredV(col, fmt, ...)
end

function ImGui.TextColoredV(col, fmt, ...)
	ImGui.PushStyleColor(ImGuiCol.Text, col)
	ImGui.TextV(fmt, ...)
	ImGui.PopStyleColor()
end

function ImGui.TextDisabled(fmt, ...)
	ImGui.TextDisabledV(fmt, ...)
end

function ImGui.TextDisabledV(fmt, ...)
	local g = ImGui.GImGui
	ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled + 1])
	ImGui.TextV(fmt, ...)
	ImGui.PopStyleColor()
end

function ImGui.TextWrapped(fmt, ...)
	ImGui.TextWrappedV(fmt, ...)
end

function ImGui.TextWrappedV(fmt, ...)
	local g = ImGui.GImGui
	local need_backup = g.CurrentWindow.DC.TextWrapPos < 0.0
	if need_backup then
		ImGui.PushTextWrapPos(0.0)
	end
	ImGui.TextV(fmt, ...)
	if need_backup then
		ImGui.PopTextWrapPos()
	end
end

function ImGui.TextAligned(align_x, width, fmt, ...)
	ImGui.TextAlignedV(align_x, width, fmt, ...)
end

function ImGui.TextAlignedV(align_x, width, fmt, ...)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local text = FormatText(fmt, ...)
	local text_end = #text + 1
	local text_size = ImGui.CalcTextSize(text, text_end)

	local size = ImGui.CalcItemSize(ImVec2(width, 0.0), 0.0, text_size.y)
	local pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)
	local pos_max = ImVec2(pos.x + size.x, window.ClipRect.Max.y)

	window.DC.CursorMaxPos = ImVec2(ImMax(window.DC.CursorMaxPos.x, pos.x + text_size.x), window.DC.CursorMaxPos.y)
	window.DC.IdealMaxPos = ImVec2(ImMax(window.DC.IdealMaxPos.x, pos.x + text_size.x), window.DC.IdealMaxPos.y)
	local backup_max_pos = window.DC.CursorMaxPos
	ImGui.ItemSize(size)
	local is_visible = ImGui.ItemAdd(ImRect.new(pos, pos + size), 0)
	window.DC.CursorMaxPos = ImVec2(backup_max_pos.x, window.DC.CursorMaxPos.y)
	if not is_visible then
		return
	end

	if align_x > 0.0 and text_size.x < size.x then
		pos = ImVec2(pos.x + ImTrunc((size.x - text_size.x) * align_x), pos.y)
	end
	ImGui.RenderTextEllipsis(window.DrawList, pos, pos_max, pos_max.x, text, text_end, text_size)

	if size.x < text_size.x and ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.NoNavOverride, ImGuiHoveredFlags.AllowWhenDisabled, ImGuiHoveredFlags.ForTooltip)) then
		ImGui.SetTooltip("%s", text)
	end
end

function ImGui.LabelText(label, fmt, ...)
	ImGui.LabelTextV(label, fmt, ...)
end

function ImGui.LabelTextV(label, fmt, ...)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	local style = g.Style
	local w = ImGui.CalcItemWidth()

	local value_text = FormatText(fmt, ...)
	local value_text_end = #value_text + 1
	local value_size = ImGui.CalcTextSize(value_text, value_text_end, false)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local pos = window.DC.CursorPos
	local value_bb = ImRect.new(pos, pos + ImVec2(w, value_size.y + style.FramePadding.y * 2))
	local total_bb = ImRect.new(pos, pos + ImVec2(w + (if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0), ImMax(value_size.y, label_size.y) + style.FramePadding.y * 2))
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(total_bb, 0) then
		return
	end

	ImGui.RenderTextClipped(value_bb.Min + style.FramePadding, value_bb.Max, value_text, value_text_end, value_size, ImVec2(0.0, 0.0))
	if label_size.x > 0.0 then
		ImGui.RenderText(ImVec2(value_bb.Max.x + style.ItemInnerSpacing.x, value_bb.Min.y + style.FramePadding.y), label, label_end, false)
	end
end

function ImGui.BulletText(fmt, ...)
	ImGui.BulletTextV(fmt, ...)
end

function ImGui.BulletTextV(fmt, ...)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	local style = g.Style

	local text = FormatText(fmt, ...)
	local text_end = #text + 1
	local label_size = ImGui.CalcTextSize(text, text_end, false)
	local total_size = ImVec2(g.FontSize + (if label_size.x > 0.0 then label_size.x + style.FramePadding.x * 2 else 0.0), label_size.y)
	local pos = window.DC.CursorPos
	pos = ImVec2(pos.x, pos.y + window.DC.CurrLineTextBaseOffset)
	ImGui.ItemSize(total_size, 0.0)
	local bb = ImRect.new(pos, pos + total_size)
	if not ImGui.ItemAdd(bb, 0) then
		return
	end

	local text_col = ImGui.GetColorU32(ImGuiCol.Text)
	ImGui.RenderBullet(window.DrawList, bb.Min + ImVec2(style.FramePadding.x + g.FontSize * 0.5, g.FontSize * 0.5), text_col)
	ImGui.RenderText(bb.Min + ImVec2(g.FontSize + style.FramePadding.x * 2, 0.0), text, text_end, false)
end

function ImGui.ButtonBehavior(bb, id, out_hovered, out_held, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()

	local item_flags = if g.LastItemData.ID == id then g.LastItemData.ItemFlags else g.CurrentItemFlags
	if bit32.btest(flags, ImGuiButtonFlags.AllowOverlap) then
		item_flags = bit32.bor(item_flags, ImGuiItemFlags.AllowOverlap)
	end
	if bit32.btest(item_flags, ImGuiItemFlags.NoFocus) then
		flags = bit32.bor(flags, ImGuiButtonFlags.NoFocus, ImGuiButtonFlags.NoNavFocus)
	end

	if bit32.band(flags, ImGuiButtonFlags.MouseButtonMask_) == 0 then
		flags = bit32.bor(flags, ImGuiButtonFlags.MouseButtonLeft)
	end

	if bit32.band(flags, ImGuiButtonFlags.PressedOnMask_) == 0 then
		flags = bit32.bor(flags, if bit32.btest(item_flags, ImGuiItemFlags.ButtonRepeat) then ImGuiButtonFlags.PressedOnClick else ImGuiButtonFlags.PressedOnDefault_)
	end

	local backup_hovered_window = g.HoveredWindow
	local flatten_hovered_children = bit32.btest(flags, ImGuiButtonFlags.FlattenChildren) and g.HoveredWindow ~= nil and g.HoveredWindow.RootWindow == window.RootWindow
	if flatten_hovered_children then
		g.HoveredWindow = window
	end

	local pressed = false
	local hovered = ImGui.ItemHoverable(bb, id, item_flags)

	if g.DragDropActive then
		if bit32.btest(flags, ImGuiButtonFlags.PressedOnDragDropHold) and not bit32.btest(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceNoHoldToOpenOthers) and ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
			hovered = true
			ImGui.SetHoveredID(id)
			if g.HoveredIdTimer - g.IO.DeltaTime <= DRAGDROP_HOLD_TO_OPEN_TIMER and g.HoveredIdTimer >= DRAGDROP_HOLD_TO_OPEN_TIMER then
				pressed = true
				g.DragDropHoldJustPressedId = id
				ImGui.FocusWindow(window)
			end
		end
		if g.DragDropAcceptIdPrev == id and bit32.btest(g.DragDropAcceptFlagsPrev, ImGuiDragDropFlags.AcceptDrawAsHovered) then
			hovered = true
		end
	end

	if flatten_hovered_children then
		g.HoveredWindow = backup_hovered_window
	end

	local test_owner_id = if bit32.btest(flags, ImGuiButtonFlags.NoTestKeyOwner) then ImGuiKeyOwner.Any else id
	if hovered then
		assert(id ~= 0)

		local mouse_button_clicked = -1
		local mouse_button_released = -1
		for button = 0, 2 do
			if bit32.btest(flags, bit32.lshift(ImGuiButtonFlags.MouseButtonLeft, button)) then
				if ImGui.IsMouseClicked(button, ImGuiInputFlags.None, test_owner_id) and mouse_button_clicked == -1 then
					mouse_button_clicked = button
				end
				if ImGui.IsMouseReleased(button, test_owner_id) and mouse_button_released == -1 then
					mouse_button_released = button
				end
			end
		end

		local mods_ok = not bit32.btest(flags, ImGuiButtonFlags.NoKeyModsAllowed) or (not g.IO.KeyCtrl and not g.IO.KeyShift and not g.IO.KeyAlt)
		if mods_ok then
			if mouse_button_clicked ~= -1 and g.ActiveId ~= id then
				if not bit32.btest(flags, ImGuiButtonFlags.NoSetKeyOwner) then
					ImGui.SetKeyOwner(ImGui.MouseButtonToKey(mouse_button_clicked), id)
				end
				if bit32.btest(flags, bit32.bor(ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnClickReleaseAnywhere)) then
					ImGui.SetActiveID(id, window)
					g.ActiveIdMouseButton = mouse_button_clicked
					if not bit32.btest(flags, ImGuiButtonFlags.NoNavFocus) then
						ImGui.SetFocusID(id, window)
						ImGui.FocusWindow(window)
					elseif not bit32.btest(flags, ImGuiButtonFlags.NoFocus) then
						ImGui.FocusWindow(window, ImGuiFocusRequestFlags.RestoreFocusedChild)
					end
				end
				if bit32.btest(flags, ImGuiButtonFlags.PressedOnClick) or (bit32.btest(flags, ImGuiButtonFlags.PressedOnDoubleClick) and g.IO.MouseClickedCount[mouse_button_clicked + 1] == 2) then
					pressed = true
					if bit32.btest(flags, ImGuiButtonFlags.NoHoldingActiveId) then
						ImGui.ClearActiveID()
					else
						ImGui.SetActiveID(id, window)
					end
					g.ActiveIdMouseButton = mouse_button_clicked
					if not bit32.btest(flags, ImGuiButtonFlags.NoNavFocus) then
						ImGui.SetFocusID(id, window)
						ImGui.FocusWindow(window)
					elseif not bit32.btest(flags, ImGuiButtonFlags.NoFocus) then
						ImGui.FocusWindow(window, ImGuiFocusRequestFlags.RestoreFocusedChild)
					end
				end
				if bit32.btest(flags, ImGuiButtonFlags.PressedOnRelease) then
					if not bit32.btest(flags, ImGuiButtonFlags.NoHoldingActiveId) then
						ImGui.SetActiveID(id, window)
					end
					g.ActiveIdMouseButton = mouse_button_clicked
				end
			end
			if bit32.btest(flags, ImGuiButtonFlags.PressedOnRelease) then
				if mouse_button_released ~= -1 then
					local has_repeated_at_least_once = bit32.btest(item_flags, ImGuiItemFlags.ButtonRepeat) and g.IO.MouseDownDurationPrev[mouse_button_released + 1] >= g.IO.KeyRepeatDelay
					if not has_repeated_at_least_once then
						pressed = true
					end
					if not bit32.btest(flags, ImGuiButtonFlags.NoNavFocus) then
						ImGui.SetFocusID(id, window)
					end
					ImGui.ClearActiveID()
				end
			end

			if g.ActiveId == id and bit32.btest(item_flags, ImGuiItemFlags.ButtonRepeat) then
				if g.IO.MouseDownDuration[g.ActiveIdMouseButton + 1] > 0.0 and ImGui.IsMouseClicked(g.ActiveIdMouseButton, ImGuiInputFlags.Repeat, test_owner_id) then
					pressed = true
				end
			end
		end

		if pressed and g.IO.ConfigNavCursorVisibleAuto then
			g.NavCursorVisible = false
		end
	end

	if bit32.band(item_flags, ImGuiItemFlags.Disabled) == 0 then
		if g.NavId == id and g.NavCursorVisible and g.NavHighlightItemUnderNav then
			if not bit32.btest(flags, ImGuiButtonFlags.NoHoveredOnFocus) then
				hovered = true
			end
		end
		if g.NavActivateDownId == id then
			local nav_activated_by_code = g.NavActivateId == id
			local nav_activated_by_inputs = g.NavActivatePressedId == id
			if not nav_activated_by_inputs and bit32.btest(item_flags, ImGuiItemFlags.ButtonRepeat) then
				local key1 = ImGui.GetKeyData(g, ImGuiKey.Space)
				local key2 = ImGui.GetKeyData(g, ImGuiKey.Enter)
				local key3 = ImGui.GetKeyData(g, if g.IO.ConfigNavSwapGamepadButtons then ImGuiKey.GamepadFaceRight else ImGuiKey.GamepadFaceDown)
				local t1 = ImMax(ImMax(key1.DownDuration, key2.DownDuration), key3.DownDuration)
				nav_activated_by_inputs = ImGui.CalcTypematicRepeatAmount(t1 - g.IO.DeltaTime, t1, g.IO.KeyRepeatDelay, g.IO.KeyRepeatRate) > 0
			end
			if nav_activated_by_code or nav_activated_by_inputs then
				pressed = true
				ImGui.SetActiveID(id, window)
				g.ActiveIdSource = g.NavInputSource
				if not bit32.btest(flags, ImGuiButtonFlags.NoNavFocus) and not bit32.btest(g.NavActivateFlags, ImGuiActivateFlags.FromShortcut) then
					ImGui.SetFocusID(id, window)
				end
				if bit32.btest(g.NavActivateFlags, ImGuiActivateFlags.FromShortcut) then
					g.ActiveIdFromShortcut = true
				end
			end
		end
	end

	local held = false
	if g.ActiveId == id then
		if g.ActiveIdSource == ImGuiInputSource.Mouse then
			if g.ActiveIdIsJustActivated then
				g.ActiveIdClickOffset = g.IO.MousePos - bb.Min
			end

			local mouse_button = g.ActiveIdMouseButton
			if mouse_button == -1 then
				ImGui.ClearActiveID()
			elseif ImGui.IsMouseDown(mouse_button, test_owner_id) then
				held = true
			else
				local release_in = hovered and bit32.band(flags, ImGuiButtonFlags.PressedOnClickRelease) ~= 0
				local release_anywhere = bit32.band(flags, ImGuiButtonFlags.PressedOnClickReleaseAnywhere) ~= 0
				if (release_in or release_anywhere) and not g.DragDropActive then
					local is_double_click_release = bit32.btest(flags, ImGuiButtonFlags.PressedOnDoubleClick) and g.IO.MouseReleased[mouse_button + 1] and g.IO.MouseClickedLastCount[mouse_button + 1] == 2
					local is_repeating_already = bit32.btest(item_flags, ImGuiItemFlags.ButtonRepeat) and g.IO.MouseDownDurationPrev[mouse_button + 1] >= g.IO.KeyRepeatDelay
					local is_button_avail_or_owned = ImGui.TestKeyOwner(ImGui.MouseButtonToKey(mouse_button), test_owner_id)
					if not is_double_click_release and not is_repeating_already and is_button_avail_or_owned then
						pressed = true
					end
				end
				ImGui.ClearActiveID()
			end
			if not bit32.btest(flags, ImGuiButtonFlags.NoNavFocus) and g.IO.ConfigNavCursorVisibleAuto then
				g.NavCursorVisible = false
			end
		elseif g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
			if g.NavActivateDownId == id then
				held = true
			else
				ImGui.ClearActiveID()
			end
		end
		if pressed then
			g.ActiveIdHasBeenPressedBefore = true
		end
	end

	if g.NavHighlightActivatedId == id and bit32.band(item_flags, ImGuiItemFlags.Disabled) == 0 then
		hovered = true
	end

	return pressed, hovered, held
end

function ImGui.ButtonEx(label, size_arg, flags)
	if size_arg == nil then
		size_arg = ImVec2(0, 0)
	end
	if flags == nil then
		flags = 0
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local pos = window.DC.CursorPos
	if bit32.btest(flags, ImGuiButtonFlags.AlignTextBaseLine) and style.FramePadding.y < window.DC.CurrLineTextBaseOffset then
		pos = ImVec2(pos.x, pos.y + window.DC.CurrLineTextBaseOffset - style.FramePadding.y)
	end
	local size = ImGui.CalcItemSize(size_arg, label_size.x + style.FramePadding.x * 2.0, label_size.y + style.FramePadding.y * 2.0)

	local bb = ImRect.new(pos, pos + size)
	ImGui.ItemSize(size, style.FramePadding.y)
	if not ImGui.ItemAdd(bb, id) then
		return false
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, flags)

	local col = ImGui.GetColorU32(if held and hovered then ImGuiCol.ButtonActive elseif hovered then ImGuiCol.ButtonHovered else ImGuiCol.Button)
	ImGui.RenderNavCursor(bb, id)
	ImGui.RenderFrame(bb.Min, bb.Max, col, true, style.FrameRounding)

	if g.LogEnabled then
		ImGui.LogSetNextTextDecoration("[", "]")
	end
	ImGui.RenderTextClipped(bb.Min + style.FramePadding, bb.Max - style.FramePadding, label, label_end, label_size, style.ButtonTextAlign, bb)

	return pressed
end

function ImGui.Button(label, size_arg)
	if size_arg == nil then
		size_arg = ImVec2(0, 0)
	end
	return ImGui.ButtonEx(label, size_arg, ImGuiButtonFlags.None)
end

function ImGui.SmallButton(label)
	local g = ImGui.GImGui
	local backup_padding_y = g.Style.FramePadding.y
	g.Style.FramePadding = ImVec2(g.Style.FramePadding.x, 0.0)
	local pressed = ImGui.ButtonEx(label, ImVec2(0, 0), ImGuiButtonFlags.AlignTextBaseLine)
	g.Style.FramePadding = ImVec2(g.Style.FramePadding.x, backup_padding_y)
	return pressed
end

function ImGui.InvisibleButton(str_id, size_arg, flags)
	if flags == nil then
		flags = 0
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local size = ImGui.CalcItemSize(ImVec2(if size_arg.x ~= 0.0 then size_arg.x else -FLT_MIN, if size_arg.y ~= 0.0 then size_arg.y else -FLT_MIN), 0.0, 0.0)

	local id = window:GetID(str_id)
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + size)
	ImGui.ItemSize(size)
	if not ImGui.ItemAdd(bb, id, nil, if bit32.btest(flags, ImGuiButtonFlags.EnableNav) then ImGuiItemFlags.None else ImGuiItemFlags.NoNav) then
		return false
	end

	local pressed = ImGui.ButtonBehavior(bb, id, nil, nil, flags)
	ImGui.RenderNavCursor(bb, id)

	return pressed
end

function ImGui.ArrowButtonEx(str_id, dir, size, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local id = window:GetID(str_id)
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + size)
	local default_size = ImGui.GetFrameHeight()
	ImGui.ItemSize(size, if size.y >= default_size then g.Style.FramePadding.y else -1.0)
	if not ImGui.ItemAdd(bb, id) then
		return false
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, flags)

	local bg_col = ImGui.GetColorU32(if held and hovered then ImGuiCol.ButtonActive elseif hovered then ImGuiCol.ButtonHovered else ImGuiCol.Button)
	local text_col = ImGui.GetColorU32(ImGuiCol.Text)
	ImGui.RenderNavCursor(bb, id)
	ImGui.RenderFrame(bb.Min, bb.Max, bg_col, true, g.Style.FrameRounding)
	ImGui.RenderArrow(window.DrawList, bb.Min + ImVec2(ImMax(0.0, (size.x - g.FontSize) * 0.5), ImMax(0.0, (size.y - g.FontSize) * 0.5)), text_col, dir)

	return pressed
end

function ImGui.ArrowButton(str_id, dir)
	local sz = ImGui.GetFrameHeight()
	return ImGui.ArrowButtonEx(str_id, dir, ImVec2(sz, sz), ImGuiButtonFlags.None)
end

function ImGui.CloseButton(id, pos)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local bb = ImRect.new(pos, pos + ImVec2(g.FontSize, g.FontSize))
	local bb_interact = bb
	local area_to_visible_ratio = window.OuterRectClipped:GetArea() / bb:GetArea()
	if area_to_visible_ratio < 1.5 then
		bb_interact = bb_interact:Expanded(ImTrunc(bb_interact:GetSize() * -0.25))
	end

	local is_clipped = not ImGui.ItemAdd(bb_interact, id)

	local pressed, hovered, held = ImGui.ButtonBehavior(bb_interact, id, nil, nil)
	if is_clipped then
		return pressed
	end

	local bg_col = ImGui.GetColorU32(if held then ImGuiCol.ButtonActive else ImGuiCol.ButtonHovered)
	if hovered then
		window.DrawList:AddRectFilled(bb.Min, bb.Max, bg_col)
	end
	ImGui.RenderNavCursor(bb, id, ImGuiNavRenderCursorFlags.Compact)
	local cross_col = ImGui.GetColorU32(ImGuiCol.Text)
	local cross_center = bb:GetCenter()
	local cross_extent = g.FontSize * 0.5 * 0.7071 - 1.0
	local cross_thickness = 1.0 * ImTruncToInt(g.Style._MainScale)
	window.DrawList:AddLine(cross_center + ImVec2(cross_extent, cross_extent), cross_center + ImVec2(-cross_extent, -cross_extent), cross_col, cross_thickness)
	window.DrawList:AddLine(cross_center + ImVec2(cross_extent, -cross_extent), cross_center + ImVec2(-cross_extent, cross_extent), cross_col, cross_thickness)

	return pressed
end

function ImGui.CollapseButton(id, pos)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local bb = ImRect.new(pos, pos + ImVec2(g.FontSize, g.FontSize))
	local is_clipped = not ImGui.ItemAdd(bb, id)
	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, ImGuiButtonFlags.None)
	if is_clipped then
		return pressed
	end

	local bg_col = ImGui.GetColorU32(if held and hovered then ImGuiCol.ButtonActive elseif hovered then ImGuiCol.ButtonHovered else ImGuiCol.Button)
	local text_col = ImGui.GetColorU32(ImGuiCol.Text)
	if hovered or held then
		window.DrawList:AddRectFilled(bb.Min, bb.Max, bg_col)
	end
	ImGui.RenderNavCursor(bb, id, ImGuiNavRenderCursorFlags.Compact)
	ImGui.RenderArrow(window.DrawList, bb.Min, text_col, if window.Collapsed then ImGuiDir.Right else ImGuiDir.Down, 1.0)

	if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) then
		ImGui.StartMouseMovingWindow(window)
	end

	return pressed
end

function ImGui.GetWindowScrollbarID(window, axis)
	return window:GetID(if axis == ImGuiAxis.X then "#SCROLLX" else "#SCROLLY")
end

function ImGui.GetWindowScrollbarRect(window, axis)
	local g = ImGui.GImGui
	local outer_rect = window:Rect()
	local inner_rect = window.InnerRect
	local scrollbar_size = VecAxis(window.ScrollbarSizes, bit32.bxor(axis, 1))
	assert(scrollbar_size >= 0.0)
	local border_size = IM_ROUND(window.WindowBorderSize * 0.5)
	local border_top = if bit32.btest(window.Flags, ImGuiWindowFlags.MenuBar)
		then IM_ROUND(g.Style.FrameBorderSize * 0.5)
		elseif bit32.btest(window.Flags, ImGuiWindowFlags.NoTitleBar) then border_size
		else 0
	if axis == ImGuiAxis.X then
		return ImRect.fromXY(inner_rect.Min.x + border_size, ImMax(outer_rect.Min.y + border_size, outer_rect.Max.y - border_size - scrollbar_size), inner_rect.Max.x - border_size, outer_rect.Max.y - border_size)
	else
		return ImRect.fromXY(ImMax(outer_rect.Min.x, outer_rect.Max.x - border_size - scrollbar_size), inner_rect.Min.y + border_top, outer_rect.Max.x - border_size, inner_rect.Max.y - border_size)
	end
end

function ImGui.ExtendHitBoxWhenNearViewportEdge(window, bb, threshold, axis)
	local window_rect = window.RootWindow:Rect()
	local viewport_rect = window.Viewport:GetMainRect()
	local window_min, window_max = VecAxis(window_rect.Min, axis), VecAxis(window_rect.Max, axis)
	if window_min == VecAxis(viewport_rect.Min, axis) and VecAxis(bb.Min, axis) > window_min and VecAxis(bb.Min, axis) - threshold <= window_min then
		bb = bb:WithMin(VecWithAxis(bb.Min, axis, window_min))
	end
	if window_max == VecAxis(viewport_rect.Max, axis) and VecAxis(bb.Max, axis) < window_max and VecAxis(bb.Max, axis) + threshold >= window_max then
		bb = bb:WithMax(VecWithAxis(bb.Max, axis, window_max))
	end
	return bb
end

function ImGui.Scrollbar(axis)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local id = ImGui.GetWindowScrollbarID(window, axis)

	local bb = ImGui.GetWindowScrollbarRect(window, axis)
	local rounding_corners = ImGui.CalcRoundingFlagsForRectInRect(bb, window:Rect(), g.Style.WindowBorderSize)
	local size_visible = VecAxis(window.InnerRect.Max, axis) - VecAxis(window.InnerRect.Min, axis)
	local size_contents = VecAxis(window.ContentSize, axis) + VecAxis(window.WindowPadding, axis) * 2.0
	local scroll = ImTruncToInt(VecAxis(window.Scroll, axis))
	local _
	_, scroll = ImGui.ScrollbarEx(bb, id, axis, scroll, ImTruncToInt(size_visible), ImTruncToInt(size_contents), rounding_corners)
	window.Scroll = VecWithAxis(window.Scroll, axis, scroll)
end

function ImGui.ScrollbarEx(bb_frame, id, axis, p_scroll_v, size_visible_v, size_contents_v, draw_rounding_flags)
	if draw_rounding_flags == nil then
		draw_rounding_flags = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false, p_scroll_v
	end

	local bb_frame_width = bb_frame:GetWidth()
	local bb_frame_height = bb_frame:GetHeight()
	if bb_frame_width <= 0.0 or bb_frame_height <= 0.0 then
		return false, p_scroll_v
	end

	local alpha = 1.0
	if axis == ImGuiAxis.Y and bb_frame_height < bb_frame_width then
		alpha = ImSaturate(bb_frame_height / ImMax(bb_frame_width * 2.0, 1.0))
	end
	if alpha <= 0.0 then
		return false, p_scroll_v
	end

	local style = g.Style
	local allow_interaction = alpha >= 1.0

	local bb = bb_frame
	local padding = IM_TRUNC(ImMin(style.ScrollbarPadding, ImMin(bb_frame_width, bb_frame_height) * 0.5))
	bb = bb:Expanded(-padding)

	local scrollbar_size_v = if axis == ImGuiAxis.X then bb:GetWidth() else bb:GetHeight()
	if scrollbar_size_v < 1.0 then
		return false, p_scroll_v
	end

	assert(ImMax(size_contents_v, size_visible_v) > 0.0)
	local win_size_v = ImMax(ImMax(size_contents_v, size_visible_v), 1)
	local grab_h_minsize = ImMin(VecAxis(bb:GetSize(), axis), style.GrabMinSize)
	local grab_h_pixels = ImTruncToInt(ImClamp(scrollbar_size_v * (size_visible_v / win_size_v), grab_h_minsize, scrollbar_size_v))
	local grab_h_norm = grab_h_pixels / scrollbar_size_v

	local bb_hit = ImGui.ExtendHitBoxWhenNearViewportEdge(window, bb_frame, g.Style.WindowBorderSize, bit32.bxor(axis, 1))

	ImGui.ItemAdd(bb_frame, id, nil, ImGuiItemFlags.NoNav)
	local _, hovered, held = ImGui.ButtonBehavior(bb_hit, id, nil, nil, ImGuiButtonFlags.NoNavFocus)

	local scroll_max = ImMax(1, size_contents_v - size_visible_v)
	local scroll_ratio = ImSaturate(p_scroll_v / scroll_max)
	local grab_v_norm = scroll_ratio * (scrollbar_size_v - grab_h_pixels) / scrollbar_size_v
	if held and allow_interaction and grab_h_norm < 1.0 then
		local scrollbar_pos_v = VecAxis(bb.Min, axis)
		local mouse_pos_v = VecAxis(g.IO.MousePos, axis)

		local clicked_v_norm = ImSaturate((mouse_pos_v - scrollbar_pos_v) / scrollbar_size_v)

		local held_dir = if clicked_v_norm < grab_v_norm then -1 elseif clicked_v_norm > grab_v_norm + grab_h_norm then 1 else 0
		if g.ActiveIdIsJustActivated then
			local scroll_to_clicked_location = g.IO.ConfigScrollbarScrollByPage == false or g.IO.KeyShift or held_dir == 0
			g.ScrollbarSeekMode = if scroll_to_clicked_location then 0 else held_dir
			g.ScrollbarClickDeltaToGrabCenter = if held_dir == 0 and not g.IO.KeyShift then clicked_v_norm - grab_v_norm - grab_h_norm * 0.5 else 0.0
		end

		if g.ScrollbarSeekMode == 0 then
			local scroll_v_norm = ImSaturate((clicked_v_norm - g.ScrollbarClickDeltaToGrabCenter - grab_h_norm * 0.5) / (1.0 - grab_h_norm))
			p_scroll_v = ImTruncToInt(scroll_v_norm * scroll_max)
		else
			if ImGui.IsMouseClicked(ImGuiMouseButton.Left, ImGuiInputFlags.Repeat, 0) and held_dir == g.ScrollbarSeekMode then
				local page_dir = if g.ScrollbarSeekMode > 0.0 then 1.0 else -1.0
				p_scroll_v = ImClamp(p_scroll_v + ImTruncToInt(page_dir * size_visible_v), 0, scroll_max)
			end
		end

		scroll_ratio = ImSaturate(p_scroll_v / scroll_max)
		grab_v_norm = scroll_ratio * (scrollbar_size_v - grab_h_pixels) / scrollbar_size_v
	end

	local bg_col = ImGui.GetColorU32(ImGuiCol.ScrollbarBg)
	local grab_col = ImGui.GetColorU32(if held then ImGuiCol.ScrollbarGrabActive elseif hovered then ImGuiCol.ScrollbarGrabHovered else ImGuiCol.ScrollbarGrab, alpha)
	window.DrawList:AddRectFilled(bb_frame.Min, bb_frame.Max, bg_col, window.WindowRounding, draw_rounding_flags)
	local grab_rect
	if axis == ImGuiAxis.X then
		grab_rect = ImRect.fromXY(ImLerp(bb.Min.x, bb.Max.x, grab_v_norm), bb.Min.y, ImLerp(bb.Min.x, bb.Max.x, grab_v_norm) + grab_h_pixels, bb.Max.y)
	else
		grab_rect = ImRect.fromXY(bb.Min.x, ImLerp(bb.Min.y, bb.Max.y, grab_v_norm), bb.Max.x, ImLerp(bb.Min.y, bb.Max.y, grab_v_norm) + grab_h_pixels)
	end
	window.DrawList:AddRectFilled(grab_rect.Min, grab_rect.Max, grab_col, style.ScrollbarRounding)

	return held, p_scroll_v
end

function ImGui.ImageWithBg(tex_ref, image_size, uv0, uv1, bg_col, tint_col)
	if uv0 == nil then
		uv0 = ImVec2(0, 0)
	end
	if uv1 == nil then
		uv1 = ImVec2(1, 1)
	end
	if bg_col == nil then
		bg_col = ImVec4(0, 0, 0, 0)
	end
	if tint_col == nil then
		tint_col = ImVec4(1, 1, 1, 1)
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local padding = ImVec2(g.Style.ImageBorderSize, g.Style.ImageBorderSize)
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + image_size + padding * 2.0)
	ImGui.ItemSize(bb:GetSize())
	if not ImGui.ItemAdd(bb, 0) then
		return
	end

	local rounding = g.Style.ImageRounding
	if bg_col.w > 0.0 then
		window.DrawList:AddRectFilled(bb.Min + padding, bb.Max - padding, ImGui.GetColorU32(bg_col), rounding)
	end
	if rounding > 0.0 then
		window.DrawList:AddImageRounded(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col), rounding)
	else
		window.DrawList:AddImage(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col))
	end
	if g.Style.ImageBorderSize > 0.0 then
		window.DrawList:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Border), rounding, g.Style.ImageBorderSize)
	end
end

function ImGui.Image(tex_ref, image_size, uv0, uv1)
	ImGui.ImageWithBg(tex_ref, image_size, uv0, uv1)
end

function ImGui.ImageButtonEx(id, tex_ref, image_size, uv0, uv1, bg_col, tint_col, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local padding = g.Style.FramePadding
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + image_size + padding * 2.0)
	ImGui.ItemSize(bb:GetSize())
	if not ImGui.ItemAdd(bb, id) then
		return false
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, flags)

	local col = ImGui.GetColorU32(if held and hovered then ImGuiCol.ButtonActive elseif hovered then ImGuiCol.ButtonHovered else ImGuiCol.Button)
	ImGui.RenderNavCursor(bb, id)
	ImGui.RenderFrame(bb.Min, bb.Max, col, true, g.Style.FrameRounding)
	if bg_col.w > 0.0 then
		window.DrawList:AddRectFilled(bb.Min + padding, bb.Max - padding, ImGui.GetColorU32(bg_col))
	end
	local image_rounding = ImMax(g.Style.FrameRounding - ImMax(padding.x, padding.y), g.Style.ImageRounding)
	if image_rounding > 0.0 then
		window.DrawList:AddImageRounded(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col), image_rounding)
	else
		window.DrawList:AddImage(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col))
	end

	return pressed
end

function ImGui.ImageButton(str_id, tex_ref, image_size, uv0, uv1, bg_col, tint_col)
	if uv0 == nil then
		uv0 = ImVec2(0, 0)
	end
	if uv1 == nil then
		uv1 = ImVec2(1, 1)
	end
	if bg_col == nil then
		bg_col = ImVec4(0, 0, 0, 0)
	end
	if tint_col == nil then
		tint_col = ImVec4(1, 1, 1, 1)
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return false
	end

	return ImGui.ImageButtonEx(window:GetID(str_id), tex_ref, image_size, uv0, uv1, bg_col, tint_col)
end

function ImGui.Checkbox(label, v)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, v
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local square_sz = ImGui.GetFrameHeight()
	local pos = window.DC.CursorPos
	local total_bb = ImRect.new(pos, pos + ImVec2(square_sz + (if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0), label_size.y + style.FramePadding.y * 2.0))
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	local is_visible = ImGui.ItemAdd(total_bb, id)
	local is_multi_select = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.IsMultiSelect) ~= 0
	if not is_visible then
		if not is_multi_select or not g.BoxSelectState.UnclipMode or not g.BoxSelectState.UnclipRect:Overlaps(total_bb) then
			return false, v
		end
	end

	local checked = v
	if is_multi_select then
		checked = ImGui.MultiSelectItemHeader(id, checked, nil)
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(total_bb, id, nil, nil)

	if is_multi_select then
		checked, pressed = ImGui.MultiSelectItemFooter(id, checked, pressed, ImGuiMultiSelectFlags.CheckboxMode_)
	elseif pressed then
		checked = not checked
	end

	if v ~= checked then
		v = checked
		pressed = true
		ImGui.MarkItemEdited(id)
	end

	local check_bb = ImRect.new(pos, pos + ImVec2(square_sz, square_sz))
	local mixed_value = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0
	if is_visible then
		ImGui.RenderNavCursor(total_bb, id)
		local bg_col = ImGui.GetColorU32(if held and hovered
			then ImGuiCol.FrameBgActive
			elseif hovered then ImGuiCol.FrameBgHovered
			elseif mixed_value or checked then ImGuiCol.CheckboxSelectedBg
			else ImGuiCol.FrameBg)
		local check_col = ImGui.GetColorU32(ImGuiCol.CheckMark)
		ImGui.RenderFrame(check_bb.Min, check_bb.Max, bg_col, true, style.FrameRounding)
		if mixed_value then
			local pad = ImVec2(ImMax(1.0, IM_TRUNC(square_sz / 3.6)), ImMax(1.0, IM_TRUNC(square_sz / 3.6)))
			window.DrawList:AddRectFilled(check_bb.Min + pad, check_bb.Max - pad, check_col, style.FrameRounding)
		elseif v then
			local pad = ImMax(1.0, IM_TRUNC(square_sz / 6.0))
			ImGui.RenderCheckMark(window.DrawList, check_bb.Min + ImVec2(pad, pad), check_col, square_sz - pad * 2.0)
		end
	end
	local label_pos = ImVec2(check_bb.Max.x + style.ItemInnerSpacing.x, check_bb.Min.y + style.FramePadding.y)
	if g.LogEnabled then
		ImGui.LogRenderedText(label_pos, if mixed_value then "[~]" elseif v then "[x]" else "[ ]")
	end
	if is_visible and label_size.x > 0.0 then
		ImGui.RenderText(label_pos, label, label_end, false)
	end

	return pressed, v
end

function ImGui.CheckboxFlags(label, flags, flags_value)
	local all_on = bit32.band(flags, flags_value) == flags_value
	local any_on = bit32.band(flags, flags_value) ~= 0
	local pressed
	if not all_on and any_on then
		local g = ImGui.GImGui
		g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.MixedValue)
		pressed, all_on = ImGui.Checkbox(label, all_on)
	else
		pressed, all_on = ImGui.Checkbox(label, all_on)
	end
	if pressed then
		if all_on then
			flags = bit32.bor(flags, flags_value)
		else
			flags = bit32.band(flags, bit32.bnot(flags_value))
		end
	end
	return pressed, flags
end

function ImGui.RadioButton(label, active, v_button)
	if type(active) == "number" then
		local v = active
		local pressed = ImGui.RadioButton(label, v == v_button)
		if pressed then
			v = v_button
		end
		return pressed, v
	end

	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local square_sz = ImGui.GetFrameHeight()
	local pos = window.DC.CursorPos
	local check_bb = ImRect.new(pos, pos + ImVec2(square_sz, square_sz))
	local total_bb = ImRect.new(pos, pos + ImVec2(square_sz + (if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0), label_size.y + style.FramePadding.y * 2.0))
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(total_bb, id) then
		return false
	end

	local center = check_bb:GetCenter()
	center = ImVec2(IM_ROUND(center.x), IM_ROUND(center.y))
	local radius = (square_sz - 1.0) * 0.5

	local pressed, hovered, held = ImGui.ButtonBehavior(total_bb, id, nil, nil)
	if pressed then
		ImGui.MarkItemEdited(id)
	end

	ImGui.RenderNavCursor(total_bb, id)
	local num_segment = window.DrawList:_CalcCircleAutoSegmentCount(radius)
	window.DrawList:AddCircleFilled(center, radius, ImGui.GetColorU32(if held and hovered then ImGuiCol.FrameBgActive elseif hovered then ImGuiCol.FrameBgHovered else ImGuiCol.FrameBg), num_segment)
	if active and bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) == 0 then
		local pad = ImMax(1.0, IM_TRUNC(square_sz / 6.0))
		window.DrawList:AddCircleFilled(center, radius - pad, ImGui.GetColorU32(ImGuiCol.CheckMark))
	end

	if style.FrameBorderSize > 0.0 then
		window.DrawList:AddCircle(center + ImVec2(1, 1), radius, ImGui.GetColorU32(ImGuiCol.BorderShadow), num_segment, style.FrameBorderSize)
		window.DrawList:AddCircle(center, radius, ImGui.GetColorU32(ImGuiCol.Border), num_segment, style.FrameBorderSize)
	end

	local label_pos = ImVec2(check_bb.Max.x + style.ItemInnerSpacing.x, check_bb.Min.y + style.FramePadding.y)
	if g.LogEnabled then
		ImGui.LogRenderedText(label_pos, if active then "(x)" else "( )")
	end
	if label_size.x > 0.0 then
		ImGui.RenderText(label_pos, label, label_end, false)
	end

	return pressed
end

function ImGui.ProgressBar(fraction, size_arg, overlay)
	if size_arg == nil then
		size_arg = ImVec2(-FLT_MIN, 0)
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	local style = g.Style

	local pos = window.DC.CursorPos
	local size = ImGui.CalcItemSize(size_arg, ImGui.CalcItemWidth(), g.FontSize + style.FramePadding.y * 2.0)
	local bb = ImRect.new(pos, pos + size)
	ImGui.ItemSize(size, style.FramePadding.y)
	if not ImGui.ItemAdd(bb, 0) then
		return
	end

	local is_indeterminate = fraction < 0.0
	if not is_indeterminate then
		fraction = ImSaturate(fraction)
	end

	local fill_n0 = 0.0
	local fill_n1 = if fraction == fraction then fraction else 0.0

	if is_indeterminate then
		local fill_width_n = 0.2
		fill_n0 = ImFmod(-fraction, 1.0) * (1.0 + fill_width_n) - fill_width_n
		fill_n1 = ImSaturate(fill_n0 + fill_width_n)
		fill_n0 = ImSaturate(fill_n0)
	end

	ImGui.RenderFrame(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), true, style.FrameRounding)
	bb = bb:Expanded(ImVec2(-style.FrameBorderSize, -style.FrameBorderSize))
	local fill_x0 = ImLerp(bb.Min.x, bb.Max.x, fill_n0)
	local fill_x1 = ImLerp(bb.Min.x, bb.Max.x, fill_n1)
	if fill_x0 < fill_x1 then
		ImGui.RenderRectFilledInRangeH(window.DrawList, bb, ImGui.GetColorU32(ImGuiCol.PlotHistogram), fill_x0, fill_x1, style.FrameRounding)
	end

	if not is_indeterminate or overlay ~= nil then
		if overlay == nil then
			overlay = ImFormatString("%.0f%%", fraction * 100 + 0.01)
		end

		local overlay_size = ImGui.CalcTextSize(overlay, nil)
		if overlay_size.x > 0.0 then
			local text_x = if is_indeterminate then (bb.Min.x + bb.Max.x - overlay_size.x) * 0.5 else fill_x1 + style.ItemSpacing.x
			ImGui.RenderTextClipped(ImVec2(ImClamp(text_x, bb.Min.x, bb.Max.x - overlay_size.x - style.ItemInnerSpacing.x), bb.Min.y), bb.Max, overlay, nil, overlay_size, ImVec2(0.0, 0.5), bb)
		end
	end
end

function ImGui.Bullet()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	local style = g.Style
	local line_height = ImMax(ImMin(window.DC.CurrLineSize.y, g.FontSize + style.FramePadding.y * 2), g.FontSize)
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + ImVec2(g.FontSize, line_height))
	ImGui.ItemSize(bb:GetSize())
	if not ImGui.ItemAdd(bb, 0) then
		ImGui.SameLine(0, style.FramePadding.x * 2)
		return
	end

	local text_col = ImGui.GetColorU32(ImGuiCol.Text)
	ImGui.RenderBullet(window.DrawList, bb.Min + ImVec2(style.FramePadding.x + g.FontSize * 0.5, line_height * 0.5), text_col)
	ImGui.SameLine(0, style.FramePadding.x * 2.0)
end

function ImGui.TextLink(label)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local id = window:GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)

	local pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)
	local size = ImGui.CalcTextSize(label, label_end, false)
	local bb = ImRect.new(pos, pos + size)
	ImGui.ItemSize(size, 0.0)
	if not ImGui.ItemAdd(bb, id) then
		return false
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil)
	ImGui.RenderNavCursor(bb, id)

	if hovered then
		ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
	end

	local text_colf = g.Style.Colors[ImGuiCol.TextLink + 1]
	local line_colf = text_colf
	do
		local h, s, v = ImGui.ColorConvertRGBtoHSV(text_colf.x, text_colf.y, text_colf.z)
		if held or hovered then
			v = ImSaturate(v + (if held then 0.4 else 0.3))
			h = ImFmod(h + 0.02, 1.0)
		end
		local r, gg, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
		text_colf = ImVec4(r, gg, b, text_colf.w)
		v = ImSaturate(v - 0.20)
		r, gg, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
		line_colf = ImVec4(r, gg, b, line_colf.w)
	end

	local line_y = bb.Max.y + ImFloor(g.FontBaked.Descent * g.FontBakedScale * 0.20)
	window.DrawList:AddLineH(bb.Min.x, bb.Max.x, line_y, ImGui.GetColorU32(line_colf), 1.0 * ImTruncToInt(g.Style._MainScale))

	ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(text_colf))
	ImGui.RenderText(bb.Min, label, label_end, false)
	ImGui.PopStyleColor()

	return pressed
end

function ImGui.TextLinkOpenURL(label, url)
	local g = ImGui.GImGui
	if url == nil then
		url = label
	end
	local pressed = ImGui.TextLink(label)
	if pressed and g.PlatformIO.Platform_OpenInShellFn ~= nil then
		g.PlatformIO.Platform_OpenInShellFn(g, url)
	end
	ImGui.SetItemTooltip(ImGui.LocalizeGetMsg(ImGuiLocKey.OpenLink_s), url)
	if ImGui.BeginPopupContextItem() then
		if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.CopyLink)) then
			ImGui.SetClipboardText(url)
		end
		ImGui.EndPopup()
	end
	return pressed
end

function ImGui.Spacing()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end
	ImGui.ItemSize(ImVec2(0, 0))
end

function ImGui.Dummy(size)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + size)
	ImGui.ItemSize(size)
	ImGui.ItemAdd(bb, 0)
end

function ImGui.NewLine()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	local backup_layout_type = window.DC.LayoutType
	window.DC.LayoutType = ImGuiLayoutType.Vertical
	window.DC.IsSameLine = false
	if window.DC.CurrLineSize.y > 0.0 then
		ImGui.ItemSize(ImVec2(0, 0))
	else
		ImGui.ItemSize(ImVec2(0.0, g.FontSize))
	end
	window.DC.LayoutType = backup_layout_type
end

function ImGui.AlignTextToFramePadding()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	window.DC.CurrLineSize = ImVec2(window.DC.CurrLineSize.x, ImMax(window.DC.CurrLineSize.y, g.FontSize + g.Style.FramePadding.y * 2))
	window.DC.CurrLineTextBaseOffset = ImMax(window.DC.CurrLineTextBaseOffset, g.Style.FramePadding.y)
end

function ImGui.SeparatorEx(flags, thickness)
	if thickness == nil then
		thickness = 1.0
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	local g = ImGui.GImGui
	assert(ImIsPowerOfTwo(bit32.band(flags, bit32.bor(ImGuiSeparatorFlags.Horizontal, ImGuiSeparatorFlags.Vertical))))
	assert(thickness > 0.0)

	if bit32.btest(flags, ImGuiSeparatorFlags.Vertical) then
		local y1 = window.DC.CursorPos.y
		local y2 = window.DC.CursorPos.y + window.DC.CurrLineSize.y
		local bb = ImRect.new(ImVec2(window.DC.CursorPos.x, y1), ImVec2(window.DC.CursorPos.x + thickness, y2))
		ImGui.ItemSize(ImVec2(thickness, 0.0))
		if not ImGui.ItemAdd(bb, 0) then
			return
		end

		window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Separator))
		if g.LogEnabled then
			ImGui.LogText(" |")
		end
	elseif bit32.btest(flags, ImGuiSeparatorFlags.Horizontal) then
		local x1 = window.DC.CursorPos.x
		local x2 = window.WorkRect.Max.x

		local columns = if bit32.btest(flags, ImGuiSeparatorFlags.SpanAllColumns) then window.DC.CurrentColumns else nil
		if columns then
			x1 = window.Pos.x + window.DC.Indent.x
			x2 = window.Pos.x + window.Size.x
			ImGui.PushColumnsBackground()
		end

		local bb = ImRect.new(ImVec2(x1, window.DC.CursorPos.y), ImVec2(x2, window.DC.CursorPos.y + thickness))
		ImGui.ItemSize(ImVec2(0.0, thickness))

		if ImGui.ItemAdd(bb, 0) then
			window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Separator))
			if g.LogEnabled then
				ImGui.LogRenderedText(bb.Min, "--------------------------------\n")
			end
		end
		if columns then
			ImGui.PopColumnsBackground()
			columns.LineMinY = window.DC.CursorPos.y
		end
	end
end

function ImGui.Separator()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	local flags = if window.DC.LayoutType == ImGuiLayoutType.Horizontal then ImGuiSeparatorFlags.Vertical else ImGuiSeparatorFlags.Horizontal

	if window.DC.CurrentColumns then
		flags = bit32.bor(flags, ImGuiSeparatorFlags.SpanAllColumns)
	end

	ImGui.SeparatorEx(flags, ImMax(g.Style.SeparatorSize, 1.0))
end

function ImGui.SeparatorTextEx(id, label, label_end, extra_w)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local style = g.Style

	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local pos = window.DC.CursorPos
	local padding = style.SeparatorTextPadding

	local separator_thickness = style.SeparatorTextBorderSize
	local min_size = ImVec2(label_size.x + extra_w + padding.x * 2.0, ImMax(label_size.y + padding.y * 2.0, separator_thickness))
	local bb = ImRect.new(pos, ImVec2(window.WorkRect.Max.x, pos.y + min_size.y))
	local text_baseline_y = ImTrunc((bb:GetHeight() - label_size.y) * style.SeparatorTextAlign.y + 0.999)
	ImGui.ItemSize(min_size, text_baseline_y)
	if not ImGui.ItemAdd(bb, id) then
		return
	end

	local sep1_x1 = pos.x
	local sep2_x2 = bb.Max.x
	local seps_y = ImTrunc((bb.Min.y + bb.Max.y) * 0.5) + 1.0

	local label_avail_w = ImMax(0.0, sep2_x2 - sep1_x1 - padding.x * 2.0)
	local label_pos = ImVec2(pos.x + padding.x + ImMax(0.0, (label_avail_w - label_size.x - extra_w) * style.SeparatorTextAlign.x), pos.y + text_baseline_y)

	window.DC.CursorPosPrevLine = ImVec2(label_pos.x + label_size.x, window.DC.CursorPosPrevLine.y)

	local separator_col = ImGui.GetColorU32(ImGuiCol.Separator)
	if label_size.x > 0.0 then
		local sep1_x2 = label_pos.x - style.ItemSpacing.x
		local sep2_x1 = label_pos.x + label_size.x + extra_w + style.ItemSpacing.x
		if sep1_x2 > sep1_x1 and separator_thickness > 0.0 then
			window.DrawList:AddLineH(sep1_x1, sep1_x2, seps_y, separator_col, separator_thickness, ImDrawFlags.StrokeCenterBiased)
		end
		if sep2_x2 > sep2_x1 and separator_thickness > 0.0 then
			window.DrawList:AddLineH(sep2_x1, sep2_x2, seps_y, separator_col, separator_thickness, ImDrawFlags.StrokeCenterBiased)
		end
		if g.LogEnabled then
			ImGui.LogSetNextTextDecoration("---", nil)
		end
		ImGui.RenderTextEllipsis(window.DrawList, label_pos, ImVec2(bb.Max.x, bb.Max.y + style.ItemSpacing.y), bb.Max.x, label, label_end, label_size)
	else
		if g.LogEnabled then
			ImGui.LogText("---")
		end
		if separator_thickness > 0.0 then
			window.DrawList:AddLineH(sep1_x1, sep2_x2, seps_y, separator_col, separator_thickness, ImDrawFlags.StrokeCenterBiased)
		end
	end
end

function ImGui.SeparatorText(label)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return
	end

	ImGui.SeparatorTextEx(0, label, ImGui.FindRenderedTextEnd(label), 0.0)
end

function ImGui.SplitterBehavior(bb, id, axis, size1, size2, min_size1, min_size2, hover_extend, hover_visibility_delay, bg_col)
	if hover_extend == nil then
		hover_extend = 0.0
	end
	if hover_visibility_delay == nil then
		hover_visibility_delay = 0.0
	end
	if bg_col == nil then
		bg_col = 0
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	if not ImGui.ItemAdd(bb, id, nil, ImGuiItemFlags.NoNav) then
		return false, size1, size2
	end

	local button_flags = ImGuiButtonFlags.FlattenChildren

	local bb_interact = bb:Expanded(if axis == ImGuiAxis.Y then ImVec2(0.0, hover_extend) else ImVec2(hover_extend, 0.0))
	local _, hovered, held = ImGui.ButtonBehavior(bb_interact, id, nil, nil, button_flags)
	if hovered then
		g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect)
	end

	if held or (hovered and g.HoveredIdPreviousFrame == id and g.HoveredIdTimer >= hover_visibility_delay) then
		ImGui.SetMouseCursor(if axis == ImGuiAxis.Y then ImGuiMouseCursor.ResizeNS else ImGuiMouseCursor.ResizeEW)
	end

	local bb_render = bb
	if held then
		local mouse_delta = VecAxis(g.IO.MousePos - g.ActiveIdClickOffset - bb_interact.Min, axis)

		local size_1_maximum_delta = ImMax(0.0, size1 - min_size1)
		local size_2_maximum_delta = ImMax(0.0, size2 - min_size2)
		if mouse_delta < -size_1_maximum_delta then
			mouse_delta = -size_1_maximum_delta
		end
		if mouse_delta > size_2_maximum_delta then
			mouse_delta = size_2_maximum_delta
		end

		if mouse_delta ~= 0.0 then
			size1 = ImMax(size1 + mouse_delta, min_size1)
			size2 = ImMax(size2 - mouse_delta, min_size2)
			bb_render = bb_render:Translated(if axis == ImGuiAxis.X then ImVec2(mouse_delta, 0.0) else ImVec2(0.0, mouse_delta))
			ImGui.MarkItemEdited(id)
		end
	end

	if bit32.btest(bg_col, IM_COL32_A_MASK) then
		window.DrawList:AddRectFilled(bb_render.Min, bb_render.Max, bg_col, 0.0)
	end
	local col = ImGui.GetColorU32(if held
		then ImGuiCol.SeparatorActive
		elseif hovered and g.HoveredIdTimer >= hover_visibility_delay then ImGuiCol.SeparatorHovered
		else ImGuiCol.Separator)
	window.DrawList:AddRectFilled(bb_render.Min, bb_render.Max, col, 0.0)

	return held, size1, size2
end

function ImGui.ShrinkWidthItemComparer(a, b)
	local d = ImTruncToInt(b.Width - a.Width)
	if d ~= 0 then
		return d
	end
	return b.Index - a.Index
end

function ImGui.ShrinkWidths(items, count, width_excess, width_min)
	if count == 1 then
		if items[1].Width >= 0.0 then
			items[1].Width = ImMax(items[1].Width - width_excess, width_min)
		end
		return
	end
	ImQsort(items, count, ImGui.ShrinkWidthItemComparer)
	local count_same_width = 1
	while width_excess > 0.001 and count_same_width < count do
		while count_same_width < count and items[1].Width <= items[count_same_width + 1].Width do
			count_same_width += 1
		end
		local max_width_to_remove_per_item = if count_same_width < count and items[count_same_width + 1].Width >= 0.0
			then items[1].Width - items[count_same_width + 1].Width
			else items[1].Width - 1.0
		max_width_to_remove_per_item = ImMin(items[1].Width - width_min, max_width_to_remove_per_item)
		if max_width_to_remove_per_item <= 0.0 then
			break
		end
		local base_width_to_remove_per_item = ImMin(width_excess / count_same_width, max_width_to_remove_per_item)
		for item_n = 0, count_same_width - 1 do
			local item = items[item_n + 1]
			local width_to_remove_for_this_item = ImMin(base_width_to_remove_per_item, item.Width - width_min)
			item.Width -= width_to_remove_for_this_item
			width_excess -= width_to_remove_for_this_item
		end
	end

	width_excess = 0.0
	for n = 0, count - 1 do
		local item = items[n + 1]
		local width_rounded = ImTrunc(item.Width)
		width_excess += item.Width - width_rounded
		item.Width = width_rounded
	end
	while width_excess > 0.0 do
		local n = 0
		while n < count and width_excess > 0.0 do
			local item = items[n + 1]
			local width_to_add = ImMin(item.InitialWidth - item.Width, 1.0)
			item.Width += width_to_add
			width_excess -= width_to_add
			n += 1
		end
	end
end

function ImGui.CalcMaxPopupHeightFromItemCount(items_count)
	local g = ImGui.GImGui
	if items_count <= 0 then
		return FLT_MAX
	end
	return (g.FontSize + g.Style.ItemSpacing.y) * items_count - g.Style.ItemSpacing.y + (g.Style.WindowPadding.y * 2)
end

function ImGui.BeginCombo(label, preview_value, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()

	local backup_next_window_data_flags = g.NextWindowData.HasFlags
	g.NextWindowData:ClearFlags()
	if window.SkipItems then
		return false
	end

	local style = g.Style
	local id = window:GetID(label)
	assert(bit32.band(flags, bit32.bor(ImGuiComboFlags.NoArrowButton, ImGuiComboFlags.NoPreview)) ~= bit32.bor(ImGuiComboFlags.NoArrowButton, ImGuiComboFlags.NoPreview))
	if bit32.btest(flags, ImGuiComboFlags.WidthFitPreview) then
		assert(bit32.band(flags, ImGuiComboFlags.NoPreview) == 0)
	end

	local arrow_size = if bit32.btest(flags, ImGuiComboFlags.NoArrowButton) then 0.0 else ImGui.GetFrameHeight()
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local preview_width = if bit32.btest(flags, ImGuiComboFlags.WidthFitPreview) and preview_value ~= nil then ImGui.CalcTextSize(preview_value, nil, false).x else 0.0
	local w = if bit32.btest(flags, ImGuiComboFlags.NoPreview)
		then arrow_size
		elseif bit32.btest(flags, ImGuiComboFlags.WidthFitPreview) then arrow_size + preview_width + style.FramePadding.x * 2.0
		else ImGui.CalcItemWidth()
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + ImVec2(w, label_size.y + style.FramePadding.y * 2.0))
	local total_bb = ImRect.new(bb.Min, bb.Max + ImVec2(if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0, 0.0))
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(total_bb, id, bb) then
		return false
	end

	local pressed, hovered = ImGui.ButtonBehavior(bb, id, nil, nil)
	local popup_id = ImHashStr("##ComboPopup", nil, id)
	local popup_open = ImGui.IsPopupOpen(popup_id, ImGuiPopupFlags.None)
	if pressed and not popup_open then
		ImGui.OpenPopupEx(popup_id, ImGuiPopupFlags.None)
		popup_open = true
	end

	local frame_col = ImGui.GetColorU32(if hovered then ImGuiCol.FrameBgHovered else ImGuiCol.FrameBg)
	local value_x2 = ImMax(bb.Min.x, bb.Max.x - arrow_size)
	ImGui.RenderNavCursor(bb, id)
	if not bit32.btest(flags, ImGuiComboFlags.NoPreview) then
		window.DrawList:AddRectFilled(bb.Min, ImVec2(value_x2, bb.Max.y), frame_col, style.FrameRounding, if bit32.btest(flags, ImGuiComboFlags.NoArrowButton) then ImDrawFlags.RoundAll else ImDrawFlags.RoundLeft)
	end
	if not bit32.btest(flags, ImGuiComboFlags.NoArrowButton) then
		local bg_col = ImGui.GetColorU32(if popup_open or hovered then ImGuiCol.ButtonHovered else ImGuiCol.Button)
		local text_col = ImGui.GetColorU32(ImGuiCol.Text)
		window.DrawList:AddRectFilled(ImVec2(value_x2, bb.Min.y), bb.Max, bg_col, style.FrameRounding, if w <= arrow_size then ImDrawFlags.RoundAll else ImDrawFlags.RoundRight)
		if value_x2 + arrow_size - style.FramePadding.x <= bb.Max.x then
			ImGui.RenderArrow(window.DrawList, ImVec2(value_x2 + style.FramePadding.y, bb.Min.y + style.FramePadding.y), text_col, ImGuiDir.Down, 1.0)
		end
	end
	ImGui.RenderFrameBorder(bb.Min, bb.Max, style.FrameRounding)

	g.ComboPreviewData.PreviewRect = if bit32.btest(flags, ImGuiComboFlags.NoPreview) then ImRect.new() else ImRect.fromXY(bb.Min.x, bb.Min.y, value_x2, bb.Max.y)

	if preview_value ~= nil and not bit32.btest(flags, ImGuiComboFlags.NoPreview) then
		if g.LogEnabled then
			ImGui.LogSetNextTextDecoration("{", "}")
		end
		ImGui.RenderTextClipped(bb.Min + style.FramePadding, ImVec2(value_x2, bb.Max.y), preview_value, nil, nil)
	end
	if label_size.x > 0 then
		ImGui.RenderText(ImVec2(bb.Max.x + style.ItemInnerSpacing.x, bb.Min.y + style.FramePadding.y), label, label_end, false)
	end

	if not popup_open then
		return false
	end

	g.NextWindowData.HasFlags = backup_next_window_data_flags
	return ImGui.BeginComboPopup(popup_id, bb, flags)
end

function ImGui.BeginComboPopup(popup_id, bb, flags)
	local g = ImGui.GImGui
	if not ImGui.IsPopupOpen(popup_id, ImGuiPopupFlags.None) then
		g.NextWindowData:ClearFlags()
		return false
	end

	local w = bb:GetWidth()
	if bit32.btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSizeConstraint) then
		g.NextWindowData.SizeConstraintRect = g.NextWindowData.SizeConstraintRect:WithMinX(ImMax(g.NextWindowData.SizeConstraintRect.Min.x, w))
	else
		if bit32.band(flags, ImGuiComboFlags.HeightMask_) == 0 then
			flags = bit32.bor(flags, ImGuiComboFlags.HeightRegular)
		end
		assert(ImIsPowerOfTwo(bit32.band(flags, ImGuiComboFlags.HeightMask_)))
		local popup_max_height_in_items = -1
		if bit32.btest(flags, ImGuiComboFlags.HeightRegular) then
			popup_max_height_in_items = 8
		elseif bit32.btest(flags, ImGuiComboFlags.HeightSmall) then
			popup_max_height_in_items = 4
		elseif bit32.btest(flags, ImGuiComboFlags.HeightLarge) then
			popup_max_height_in_items = 20
		end
		local constraint_min, constraint_max = ImVec2(0.0, 0.0), ImVec2(FLT_MAX, FLT_MAX)
		if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 or g.NextWindowData.SizeVal.x <= 0.0 then
			constraint_min = ImVec2(w, constraint_min.y)
		end
		if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 or g.NextWindowData.SizeVal.y <= 0.0 then
			constraint_max = ImVec2(constraint_max.x, ImGui.CalcMaxPopupHeightFromItemCount(popup_max_height_in_items))
		end
		ImGui.SetNextWindowSizeConstraints(constraint_min, constraint_max)
	end

	local name = ImFormatString("##Combo_%02d", g.BeginComboDepth)

	local popup_window = ImGui.FindWindowByName(name)
	if popup_window then
		if popup_window.WasActive then
			local size_expected = ImGui.CalcWindowNextAutoFitSize(popup_window)
			popup_window.AutoPosLastDirection = if bit32.btest(flags, ImGuiComboFlags.PopupAlignLeft) then ImGuiDir.Left else ImGuiDir.Down
			local r_outer = ImGui.GetPopupAllowedExtentRect(popup_window)
			local pos
			pos, popup_window.AutoPosLastDirection = ImGui.FindBestWindowPosForPopupEx(bb:GetBL(), size_expected, popup_window.AutoPosLastDirection, r_outer, bb, ImGuiPopupPositionPolicy.ComboBox)
			ImGui.SetNextWindowPos(pos)
		end
	end

	local window_flags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.Popup, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoMove)
	ImGui.PushStyleVarX(ImGuiStyleVar.WindowPadding, g.Style.FramePadding.x)
	local ret = ImGui.Begin(name, nil, window_flags)
	ImGui.PopStyleVar()
	if not ret then
		ImGui.EndPopup()
		if not g.IO.ConfigDebugBeginReturnValueOnce and not g.IO.ConfigDebugBeginReturnValueLoop then
			assert(false)
		end
		return false
	end
	g.BeginComboDepth += 1
	g.CurrentWindowStack:back().ParentLastComboPreviewRect = g.ComboPreviewData.PreviewRect
	return true
end

function ImGui.EndCombo()
	local g = ImGui.GImGui
	g.BeginComboDepth -= 1
	g.ComboPreviewData.PreviewRect = g.CurrentWindowStack:back().ParentLastComboPreviewRect
	local name = ImFormatString("##Combo_%02d", g.BeginComboDepth)
	if g.CurrentWindow.Name ~= name then
		if ImGui.ErrorLog("Calling EndCombo() in wrong window!") then
			assert(false, "Calling EndCombo() in wrong window!")
		end
		return
	end
	ImGui.EndPopup()
end

function ImGui.BeginComboPreview()
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	if window.SkipItems or not bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) then
		return false
	end
	local preview_data = g.ComboPreviewData
	if not window.ClipRect:Overlaps(preview_data.PreviewRect) or preview_data.PreviewRect:GetWidth() <= 0.0 then
		return false
	end
	if not (g.LastItemData.Rect.Min.x == preview_data.PreviewRect.Min.x and g.LastItemData.Rect.Min.y == preview_data.PreviewRect.Min.y) then
		if ImGui.ErrorLog("Call BeginComboPreview() after BeginCombo(), not after EndCombo()!") then
			assert(false, "Call BeginComboPreview() after BeginCombo(), not after EndCombo()!")
		end
		return false
	end
	if preview_data.WithinPreview ~= false then
		if ImGui.ErrorLog("Cannot recurse BeginComboPreview(): call EndComboPreview() before opening another combo.") then
			assert(false, "Cannot recurse BeginComboPreview(): call EndComboPreview() before opening another combo.")
		end
		return false
	end

	preview_data.BackupCursorPos = window.DC.CursorPos
	preview_data.BackupCursorMaxPos = window.DC.CursorMaxPos
	preview_data.BackupCursorPosPrevLine = window.DC.CursorPosPrevLine
	preview_data.BackupPrevLineTextBaseOffset = window.DC.PrevLineTextBaseOffset
	preview_data.BackupLayout = window.DC.LayoutType
	preview_data.WithinPreview = true
	preview_data.BackupWorkRectMaxX = window.WorkRect.Max.x
	preview_data.BackupContentRectMaxX = window.ContentRegionRect.Max.x
	local max_x = preview_data.PreviewRect.Max.x - g.Style.FramePadding.x
	window.ContentRegionRect = window.ContentRegionRect:WithMaxX(max_x)
	window.WorkRect = window.WorkRect:WithMaxX(max_x)
	window.DC.CursorPos = preview_data.PreviewRect.Min + g.Style.FramePadding
	window.DC.CursorMaxPos = window.DC.CursorPos
	window.DC.LayoutType = ImGuiLayoutType.Horizontal
	window.DC.IsSameLine = false
	ImGui.PushClipRect(preview_data.PreviewRect.Min, preview_data.PreviewRect.Max, true)

	return true
end

function ImGui.EndComboPreview()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local preview_data = g.ComboPreviewData

	local draw_list = window.DrawList
	if window.DC.CursorMaxPos.x < preview_data.PreviewRect.Max.x and window.DC.CursorMaxPos.y < preview_data.PreviewRect.Max.y then
		if draw_list.CmdBuffer.Size > 1 then
			local clip_rect = draw_list.CmdBuffer[draw_list.CmdBuffer.Size - 1].ClipRect
			draw_list.CmdBuffer[draw_list.CmdBuffer.Size].ClipRect = clip_rect
			draw_list._CmdHeader.ClipRect = clip_rect
			draw_list:_TryMergeDrawCmds()
		end
	end
	ImGui.PopClipRect()
	window.DC.CursorPos = preview_data.BackupCursorPos
	window.DC.CursorMaxPos = ImMax(window.DC.CursorMaxPos, preview_data.BackupCursorMaxPos)
	window.DC.CursorPosPrevLine = preview_data.BackupCursorPosPrevLine
	window.DC.PrevLineTextBaseOffset = preview_data.BackupPrevLineTextBaseOffset
	window.WorkRect = window.WorkRect:WithMaxX(preview_data.BackupWorkRectMaxX)
	window.ContentRegionRect = window.ContentRegionRect:WithMaxX(preview_data.BackupContentRectMaxX)
	window.DC.LayoutType = preview_data.BackupLayout
	window.DC.IsSameLine = false
	preview_data.WithinPreview = false
end

function ImGui.Items_ArrayGetter(data, idx)
	return data[idx + 1]
end

function ImGui.Items_SingleStringGetter(data, idx)
	local items_count = 0
	local p = 1
	local len = #data
	while p <= len and string.byte(data, p) ~= 0 do
		if idx == items_count then
			break
		end
		p = (string.find(data, "\0", p, true) or (len + 1)) + 1
		items_count += 1
	end
	if p <= len and string.byte(data, p) ~= 0 then
		return string.sub(data, p, (string.find(data, "\0", p, true) or (len + 1)) - 1)
	end
	return nil
end

local function ComboGetter(label, current_item, getter, user_data, items_count, popup_max_height_in_items)
	if popup_max_height_in_items == nil then
		popup_max_height_in_items = -1
	end
	local g = ImGui.GImGui

	local preview_value = nil
	if bit32.btest(bit32.bor(g.NextItemData.ItemFlagsSet, g.CurrentItemFlags), ImGuiItemFlags.MixedValue) then
		preview_value = ""
	elseif current_item >= 0 and current_item < items_count then
		preview_value = getter(user_data, current_item)
	end

	if popup_max_height_in_items ~= -1 and not bit32.btest(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSizeConstraint) then
		ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, ImGui.CalcMaxPopupHeightFromItemCount(popup_max_height_in_items)))
	end

	if not ImGui.BeginCombo(label, preview_value, ImGuiComboFlags.None) then
		return false, current_item
	end

	local value_changed = false
	local clipper = Structs.ImGuiListClipper.new()
	clipper:Begin(items_count)
	clipper:IncludeItemByIndex(current_item)
	while clipper:Step() do
		for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
			local item_text = getter(user_data, i)
			if item_text == nil then
				item_text = "*Unknown item*"
			end

			ImGui.PushID(i)
			local item_selected = i == current_item
			if ImGui.Selectable(item_text, item_selected) and current_item ~= i then
				value_changed = true
				current_item = i
			end
			if item_selected then
				ImGui.SetItemDefaultFocus()
			end
			ImGui.PopID()
		end
	end

	ImGui.EndCombo()
	if value_changed then
		ImGui.MarkItemEdited(g.LastItemData.ID)
	end

	return value_changed, current_item
end

function ImGui.Combo(label, current_item, items, a4, a5, a6)
	if type(items) == "function" then
		return ComboGetter(label, current_item, items, a4, a5, a6)
	elseif type(items) == "string" then
		local items_count = 0
		local p = 1
		local len = #items
		while p <= len and string.byte(items, p) ~= 0 do
			p = (string.find(items, "\0", p, true) or (len + 1)) + 1
			items_count += 1
		end
		return ComboGetter(label, current_item, ImGui.Items_SingleStringGetter, items, items_count, a4)
	end
	local items_count = if a4 == nil then #items else a4
	return ComboGetter(label, current_item, ImGui.Items_ArrayGetter, items, items_count, a5)
end

return true
