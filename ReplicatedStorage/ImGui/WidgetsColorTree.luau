--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImVec4, ImRect = Base.ImVec2, Base.ImVec4, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImSaturate, ImLerp, ImTrunc = Base.ImSaturate, Base.ImLerp, Base.ImTrunc
local ImCos, ImSin, ImAtan2 = Base.ImCos, Base.ImSin, Base.ImAtan2
local ImLengthSqr, ImRotate = Base.ImLengthSqr, Base.ImRotate
local ImTriangleContainsPoint, ImTriangleClosestPoint, ImTriangleBarycentricCoords = Base.ImTriangleContainsPoint, Base.ImTriangleClosestPoint, Base.ImTriangleBarycentricCoords
local ImIsPowerOfTwo, ImTruncToInt = Base.ImIsPowerOfTwo, Base.ImTruncToInt
local ImFormatString, ImSscanf, ImCharIsBlankA = Base.ImFormatString, Base.ImSscanf, Base.ImCharIsBlankA
local IM_COL32, IM_COL32_A_MASK = Base.IM_COL32, Base.IM_COL32_A_MASK
local IM_F32_TO_INT8_SAT, IM_F32_TO_INT8_UNBOUND = Base.IM_F32_TO_INT8_SAT, Base.IM_F32_TO_INT8_UNBOUND
local IM_TRUNC, IM_ROUND, IM_PI, FLT_MAX = Base.IM_TRUNC, Base.IM_ROUND, Base.IM_PI, Base.FLT_MAX

local band, bor, bnot, btest, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.btest, bit32.lshift

local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiNavRenderCursorFlags = Enums.ImGuiNavRenderCursorFlags
local ImGuiNextItemDataFlags = Enums.ImGuiNextItemDataFlags
local ImGuiTooltipFlags = Enums.ImGuiTooltipFlags
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiSliderFlags = Enums.ImGuiSliderFlags
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiCond = Enums.ImGuiCond
local ImGuiCol = Enums.ImGuiCol
local ImGuiDir = Enums.ImGuiDir
local ImGuiAxis = Enums.ImGuiAxis
local ImGuiMod = Enums.ImGuiMod
local ImDrawFlags = Enums.ImDrawFlags

local IMGUI_PAYLOAD_TYPE_COLOR_3F = "_COL3F"
local IMGUI_PAYLOAD_TYPE_COLOR_4F = "_COL4F"

local GDefaultRgbaColorMarkers = {
	IM_COL32(240, 20, 20, 255), IM_COL32(20, 240, 20, 255), IM_COL32(20, 20, 240, 255), IM_COL32(140, 140, 140, 255),
}

function ImGui.ColorEdit3(label, col, flags)
	if flags == nil then flags = 0 end
	return ImGui.ColorEdit4(label, col, bor(flags, ImGuiColorEditFlags.NoAlpha))
end

function ImGui.ColorEditRestoreH(col, H)
	local g = ImGui.GImGui
	assert(g.ColorEditCurrentID ~= 0)
	if g.ColorEditSavedID ~= g.ColorEditCurrentID or g.ColorEditSavedColor ~= ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], 0)) then
		return H
	end
	return g.ColorEditSavedHue
end

function ImGui.ColorEditRestoreHS(col, H, S, V)
	local g = ImGui.GImGui
	assert(g.ColorEditCurrentID ~= 0)
	if g.ColorEditSavedID ~= g.ColorEditCurrentID or g.ColorEditSavedColor ~= ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], 0)) then
		return H, S, V
	end
	if S == 0.0 or (H == 0.0 and g.ColorEditSavedHue == 1) then
		H = g.ColorEditSavedHue
	end
	if V == 0.0 then
		S = g.ColorEditSavedSat
	end
	return H, S, V
end

local ColorEdit_ids = { "##X", "##Y", "##Z", "##W" }
local ColorEdit_fmt_table_int = {
	{ "%3d", "%3d", "%3d", "%3d" },
	{ "R:%3d", "G:%3d", "B:%3d", "A:%3d" },
	{ "H:%3d", "S:%3d", "V:%3d", "A:%3d" },
}
local ColorEdit_fmt_table_float = {
	{ "%0.3f", "%0.3f", "%0.3f", "%0.3f" },
	{ "R:%0.3f", "G:%0.3f", "B:%0.3f", "A:%0.3f" },
	{ "H:%0.3f", "S:%0.3f", "V:%0.3f", "A:%0.3f" },
}

function ImGui.ColorEdit4(label, col, flags)
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local style = g.Style
	local square_sz = ImGui.GetFrameHeight()
	local label_display_end = ImGui.FindRenderedTextEnd(label)
	local w_full = ImGui.CalcItemWidth()
	g.NextItemData:ClearFlags()

	ImGui.BeginGroup()
	ImGui.PushID(label)
	local set_current_color_edit_id = (g.ColorEditCurrentID == 0)
	if set_current_color_edit_id then
		g.ColorEditCurrentID = window.IDStack:back()
	end

	local flags_untouched = flags
	if btest(flags, ImGuiColorEditFlags.NoInputs) then
		flags = bor(band(flags, bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.NoOptions)
	end

	if not btest(flags, ImGuiColorEditFlags.NoOptions) then
		ImGui.ColorEditOptionsPopup(col, flags)
	end

	local cfg = g.IO.ConfigColorEditFlags
	if not btest(flags, ImGuiColorEditFlags.DisplayMask_) then
		flags = bor(flags, band(cfg, ImGuiColorEditFlags.DisplayMask_))
	end
	if not btest(flags, ImGuiColorEditFlags.DataTypeMask_) then
		flags = bor(flags, band(cfg, ImGuiColorEditFlags.DataTypeMask_))
	end
	if not btest(flags, ImGuiColorEditFlags.PickerMask_) then
		flags = bor(flags, band(cfg, ImGuiColorEditFlags.PickerMask_))
	end
	if not btest(flags, ImGuiColorEditFlags.InputMask_) then
		flags = bor(flags, band(cfg, ImGuiColorEditFlags.InputMask_))
	end
	flags = bor(flags, band(cfg, bnot(bor(ImGuiColorEditFlags.DisplayMask_, ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.PickerMask_, ImGuiColorEditFlags.InputMask_))))
	assert(ImIsPowerOfTwo(band(flags, ImGuiColorEditFlags.DisplayMask_)))
	assert(ImIsPowerOfTwo(band(flags, ImGuiColorEditFlags.InputMask_)))

	local alpha = band(flags, ImGuiColorEditFlags.NoAlpha) == 0
	local hdr = band(flags, ImGuiColorEditFlags.HDR) ~= 0
	local components = alpha and 4 or 3
	local w_button = if btest(flags, ImGuiColorEditFlags.NoSmallPreview) then 0.0 else (square_sz + style.ItemInnerSpacing.x)
	local w_inputs = ImMax(w_full - w_button, 1.0)
	w_full = w_inputs + w_button

	local f = { col[1], col[2], col[3], alpha and col[4] or 1.0 }
	if btest(flags, ImGuiColorEditFlags.InputHSV) and btest(flags, ImGuiColorEditFlags.DisplayRGB) then
		f[1], f[2], f[3] = ImGui.ColorConvertHSVtoRGB(f[1], f[2], f[3])
	elseif btest(flags, ImGuiColorEditFlags.InputRGB) and btest(flags, ImGuiColorEditFlags.DisplayHSV) then
		f[1], f[2], f[3] = ImGui.ColorConvertRGBtoHSV(f[1], f[2], f[3])
		f[1], f[2], f[3] = ImGui.ColorEditRestoreHS(col, f[1], f[2], f[3])
	end
	local i = { IM_F32_TO_INT8_UNBOUND(f[1]), IM_F32_TO_INT8_UNBOUND(f[2]), IM_F32_TO_INT8_UNBOUND(f[3]), IM_F32_TO_INT8_UNBOUND(f[4]) }

	local value_changed = false
	local value_changed_as_float = false

	local pos = window.DC.CursorPos
	local inputs_offset_x = if style.ColorButtonPosition == ImGuiDir.Left then w_button else 0.0
	window.DC.CursorPos = ImVec2(pos.x + inputs_offset_x, window.DC.CursorPos.y)

	if band(flags, bor(ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.DisplayHSV)) ~= 0 and band(flags, ImGuiColorEditFlags.NoInputs) == 0 then
		local w_items = w_inputs - style.ItemInnerSpacing.x * (components - 1)
		local w_per_component = IM_TRUNC(w_items / components)
		local draw_color_marker = band(flags, bor(ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.NoColorMarkers)) == 0

		local hide_prefix = draw_color_marker or (w_per_component <= ImGui.CalcTextSize(if btest(flags, ImGuiColorEditFlags.Float) then "M:0.000" else "M:000").x)
		local fmt_idx = if hide_prefix then 0 elseif btest(flags, ImGuiColorEditFlags.DisplayHSV) then 2 else 1
		local drag_flags = if draw_color_marker then ImGuiSliderFlags.ColorMarkers else ImGuiSliderFlags.None

		local prev_split = 0.0
		for n = 0, components - 1 do
			if n > 0 then
				ImGui.SameLine(0, style.ItemInnerSpacing.x)
			end
			local next_split = IM_TRUNC(w_items * (n + 1) / components)
			ImGui.SetNextItemWidth(ImMax(next_split - prev_split, 1.0))
			prev_split = next_split
			if draw_color_marker then
				ImGui.SetNextItemColorMarker(GDefaultRgbaColorMarkers[n + 1])
			end

			if btest(flags, ImGuiColorEditFlags.Float) then
				local changed
				changed, f[n + 1] = ImGui.DragFloat(ColorEdit_ids[n + 1], f[n + 1], 1.0 / 255.0, 0.0, if hdr then 0.0 else 1.0, ColorEdit_fmt_table_float[fmt_idx + 1][n + 1], drag_flags)
				value_changed = value_changed or changed
				value_changed_as_float = value_changed_as_float or value_changed
			else
				local changed
				changed, i[n + 1] = ImGui.DragInt(ColorEdit_ids[n + 1], i[n + 1], 1.0, 0, if hdr then 0 else 255, ColorEdit_fmt_table_int[fmt_idx + 1][n + 1], drag_flags)
				value_changed = value_changed or changed
			end
			if not btest(flags, ImGuiColorEditFlags.NoOptions) then
				ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
			end
		end
	elseif band(flags, ImGuiColorEditFlags.DisplayHex) ~= 0 and band(flags, ImGuiColorEditFlags.NoInputs) == 0 then
		local buf
		if alpha then
			buf = ImFormatString("#%02X%02X%02X%02X", ImClamp(i[1], 0, 255), ImClamp(i[2], 0, 255), ImClamp(i[3], 0, 255), ImClamp(i[4], 0, 255))
		else
			buf = ImFormatString("#%02X%02X%02X", ImClamp(i[1], 0, 255), ImClamp(i[2], 0, 255), ImClamp(i[3], 0, 255))
		end
		ImGui.SetNextItemWidth(w_inputs)
		local changed
		changed, buf = ImGui.InputText("##Text", buf, ImGuiInputTextFlags.CharsUppercase)
		if changed then
			value_changed = true
			local p = 1
			while true do
				local c = string.byte(buf, p)
				if c == nil or not (c == 35 or ImCharIsBlankA(c)) then
					break
				end
				p += 1
			end
			local s = string.sub(buf, p)
			i[1], i[2], i[3] = 0, 0, 0
			i[4] = 0xFF
			local r0, r1, r2, r3
			if alpha then
				r0, r1, r2, r3 = ImSscanf(s, "%02X%02X%02X%02X")
			else
				r0, r1, r2 = ImSscanf(s, "%02X%02X%02X")
			end
			if r0 ~= nil then i[1] = r0 end
			if r1 ~= nil then i[2] = r1 end
			if r2 ~= nil then i[3] = r2 end
			if r3 ~= nil then i[4] = r3 end
		end
		if not btest(flags, ImGuiColorEditFlags.NoOptions) then
			ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
		end
	end

	local picker_active_window = nil
	if not btest(flags, ImGuiColorEditFlags.NoSmallPreview) then
		local button_offset_x = if (btest(flags, ImGuiColorEditFlags.NoInputs) or (style.ColorButtonPosition == ImGuiDir.Left)) then 0.0 else w_inputs + style.ItemInnerSpacing.x
		window.DC.CursorPos = ImVec2(pos.x + button_offset_x, pos.y)

		local col_v4 = ImVec4(col[1], col[2], col[3], alpha and col[4] or 1.0)
		if ImGui.ColorButton("##ColorButton", col_v4, flags) then
			if not btest(flags, ImGuiColorEditFlags.NoPicker) then
				g.ColorPickerRef = col_v4
				ImGui.OpenPopup("picker")
				ImGui.SetNextWindowPos(g.LastItemData.Rect:GetBL() + ImVec2(0.0, style.ItemSpacing.y))
			end
		end
		if not btest(flags, ImGuiColorEditFlags.NoOptions) then
			ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
		end

		if ImGui.BeginPopup("picker") then
			if g.CurrentWindow.BeginCount == 1 then
				picker_active_window = g.CurrentWindow
				if label_display_end ~= 1 then
					ImGui.TextEx(label, label_display_end)
					ImGui.Spacing()
				end
				local picker_flags_to_forward = bor(ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.PickerMask_, ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.AlphaBar)
				local picker_flags = bor(band(flags_untouched, picker_flags_to_forward), ImGuiColorEditFlags.DisplayMask_, ImGuiColorEditFlags.NoLabel, ImGuiColorEditFlags.AlphaPreviewHalf)
				ImGui.SetNextItemWidth(square_sz * 12.0)
				ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, false)
				local ref = g.ColorPickerRef
				value_changed = ImGui.ColorPicker4("##picker", col, picker_flags, { ref.x, ref.y, ref.z, ref.w }) or value_changed
				ImGui.PopItemFlag()
			end
			ImGui.EndPopup()
		end
	end

	if label_display_end ~= 1 and not btest(flags, ImGuiColorEditFlags.NoLabel) then
		ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
		window.DC.CursorPos = ImVec2(pos.x + (if btest(flags, ImGuiColorEditFlags.NoInputs) then w_button else w_full + style.ItemInnerSpacing.x), window.DC.CursorPos.y)
		ImGui.TextEx(label, label_display_end)
	end

	if value_changed and picker_active_window == nil then
		if not value_changed_as_float then
			for n = 1, 4 do
				f[n] = i[n] / 255.0
			end
		end
		if btest(flags, ImGuiColorEditFlags.DisplayHSV) and btest(flags, ImGuiColorEditFlags.InputRGB) then
			g.ColorEditSavedHue = f[1]
			g.ColorEditSavedSat = f[2]
			f[1], f[2], f[3] = ImGui.ColorConvertHSVtoRGB(f[1], f[2], f[3])
			g.ColorEditSavedID = g.ColorEditCurrentID
			g.ColorEditSavedColor = ImGui.ColorConvertFloat4ToU32(ImVec4(f[1], f[2], f[3], 0))
		end
		if btest(flags, ImGuiColorEditFlags.DisplayRGB) and btest(flags, ImGuiColorEditFlags.InputHSV) then
			f[1], f[2], f[3] = ImGui.ColorConvertRGBtoHSV(f[1], f[2], f[3])
		end

		col[1] = f[1]
		col[2] = f[2]
		col[3] = f[3]
		if alpha then
			col[4] = f[4]
		end
	end

	if set_current_color_edit_id then
		g.ColorEditCurrentID = 0
	end
	ImGui.PopID()
	ImGui.EndGroup()

	if btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) and not btest(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) and not btest(flags, ImGuiColorEditFlags.NoDragDrop) and ImGui.BeginDragDropTarget() then
		local accepted_drag_drop = false
		local payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F)
		if payload then
			for n = 1, 3 do
				col[n] = payload.Data[n]
			end
			accepted_drag_drop = true
			value_changed = true
		end
		payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F)
		if payload then
			for n = 1, components do
				col[n] = payload.Data[n]
			end
			accepted_drag_drop = true
			value_changed = true
		end

		if accepted_drag_drop and btest(flags, ImGuiColorEditFlags.InputHSV) then
			col[1], col[2], col[3] = ImGui.ColorConvertRGBtoHSV(col[1], col[2], col[3])
		end
		ImGui.EndDragDropTarget()
	end

	if picker_active_window and g.ActiveId ~= 0 and g.ActiveIdWindow == picker_active_window then
		g.LastItemData.ID = g.ActiveId
	end

	if value_changed and g.LastItemData.ID ~= 0 then
		ImGui.MarkItemEdited(g.LastItemData.ID)
	end

	return value_changed
end

function ImGui.ColorPicker3(label, col, flags)
	if flags == nil then flags = 0 end
	local col4 = { col[1], col[2], col[3], 1.0 }
	if not ImGui.ColorPicker4(label, col4, bor(flags, ImGuiColorEditFlags.NoAlpha)) then
		return false
	end
	col[1] = col4[1]
	col[2] = col4[2]
	col[3] = col4[3]
	return true
end

function ImGui.RenderArrowsForVerticalBar(draw_list, pos, half_sz, bar_w, alpha)
	local alpha8 = IM_F32_TO_INT8_SAT(alpha)
	ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + half_sz.x + 1, pos.y), ImVec2(half_sz.x + 2, half_sz.y + 1), ImGuiDir.Right, IM_COL32(0, 0, 0, alpha8))
	ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + half_sz.x, pos.y), half_sz, ImGuiDir.Right, IM_COL32(255, 255, 255, alpha8))
	ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + bar_w - half_sz.x - 1, pos.y), ImVec2(half_sz.x + 2, half_sz.y + 1), ImGuiDir.Left, IM_COL32(0, 0, 0, alpha8))
	ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + bar_w - half_sz.x, pos.y), half_sz, ImGuiDir.Left, IM_COL32(255, 255, 255, alpha8))
end

function ImGui.ColorPicker4(label, col, flags, ref_col)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local draw_list = window.DrawList
	local style = g.Style
	local io = g.IO

	local width = ImGui.CalcItemWidth()
	local is_readonly = band(bor(g.NextItemData.ItemFlagsSet, g.CurrentItemFlags), ImGuiItemFlags.ReadOnly) ~= 0
	g.NextItemData:ClearFlags()

	local backup_alpha = g.Style.Alpha
	if g.DisabledStackSize > 0 then
		g.Style.Alpha = g.DisabledAlphaBackup
	end

	ImGui.PushID(label)
	local set_current_color_edit_id = (g.ColorEditCurrentID == 0)
	if set_current_color_edit_id then
		g.ColorEditCurrentID = window.IDStack:back()
	end
	ImGui.BeginGroup()

	if not btest(flags, ImGuiColorEditFlags.NoSidePreview) then
		flags = bor(flags, ImGuiColorEditFlags.NoSmallPreview)
	end

	if not btest(flags, ImGuiColorEditFlags.NoOptions) then
		ImGui.ColorPickerOptionsPopup(col, flags)
	end

	if not btest(flags, ImGuiColorEditFlags.PickerMask_) then
		flags = bor(flags, band(if btest(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.PickerMask_) then g.IO.ConfigColorEditFlags else ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.PickerMask_))
	end
	if not btest(flags, ImGuiColorEditFlags.InputMask_) then
		flags = bor(flags, band(if btest(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.InputMask_) then g.IO.ConfigColorEditFlags else ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.InputMask_))
	end
	assert(ImIsPowerOfTwo(band(flags, ImGuiColorEditFlags.PickerMask_)))
	assert(ImIsPowerOfTwo(band(flags, ImGuiColorEditFlags.InputMask_)))
	if not btest(flags, ImGuiColorEditFlags.NoOptions) then
		flags = bor(flags, band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.AlphaBar))
	end

	local components = if btest(flags, ImGuiColorEditFlags.NoAlpha) then 3 else 4
	local alpha_bar = btest(flags, ImGuiColorEditFlags.AlphaBar) and not btest(flags, ImGuiColorEditFlags.NoAlpha)
	local picker_pos = window.DC.CursorPos
	local square_sz = ImGui.GetFrameHeight()
	local bars_width = square_sz
	local sv_picker_size = ImMax(bars_width * 1, width - (if alpha_bar then 2 else 1) * (bars_width + style.ItemInnerSpacing.x))
	local bar0_pos_x = picker_pos.x + sv_picker_size + style.ItemInnerSpacing.x
	local bar1_pos_x = bar0_pos_x + bars_width + style.ItemInnerSpacing.x
	local bars_triangles_half_sz = IM_TRUNC(bars_width * 0.20)

	local backup_initial_col = {}
	for n = 1, components do
		backup_initial_col[n] = col[n]
	end

	local wheel_thickness = sv_picker_size * 0.08
	local wheel_r_outer = sv_picker_size * 0.50
	local wheel_r_inner = wheel_r_outer - wheel_thickness
	local wheel_center = ImVec2(picker_pos.x + (sv_picker_size + bars_width) * 0.5, picker_pos.y + sv_picker_size * 0.5)

	local triangle_rotate = band(flags, ImGuiColorEditFlags.PickerNoRotate) == 0
	local triangle_r = wheel_r_inner - ImTruncToInt(sv_picker_size * 0.027)
	local triangle_pa = if triangle_rotate then ImVec2(triangle_r, 0.0) else ImVec2(triangle_r * 0.866, triangle_r * 0.5)
	local triangle_pb = if triangle_rotate then ImVec2(triangle_r * -0.5, triangle_r * -0.866) else ImVec2(0.0, -triangle_r)
	local triangle_pc = if triangle_rotate then ImVec2(triangle_r * -0.5, triangle_r * 0.866) else ImVec2(triangle_r * -0.866, triangle_r * 0.5)

	local H, S, V = col[1], col[2], col[3]
	local R, G, B = col[1], col[2], col[3]
	if btest(flags, ImGuiColorEditFlags.InputRGB) then
		H, S, V = ImGui.ColorConvertRGBtoHSV(R, G, B)
		H, S, V = ImGui.ColorEditRestoreHS(col, H, S, V)
	elseif btest(flags, ImGuiColorEditFlags.InputHSV) then
		R, G, B = ImGui.ColorConvertHSVtoRGB(H, S, V)
	end

	local value_changed, value_changed_h, value_changed_sv = false, false, false

	ImGui.PushItemFlag(ImGuiItemFlags.NoNav, true)
	if btest(flags, ImGuiColorEditFlags.PickerHueWheel) then
		ImGui.InvisibleButton("hsv", ImVec2(sv_picker_size + style.ItemInnerSpacing.x + bars_width, sv_picker_size))
		if ImGui.IsItemActive() and not is_readonly then
			local initial_off = g.IO.MouseClickedPos[1] - wheel_center
			local current_off = g.IO.MousePos - wheel_center
			local initial_dist2 = ImLengthSqr(initial_off)
			if initial_dist2 >= (wheel_r_inner - 1) * (wheel_r_inner - 1) and initial_dist2 <= (wheel_r_outer + 1) * (wheel_r_outer + 1) then
				H = ImAtan2(current_off.y, current_off.x) / IM_PI * 0.5
				if H < 0.0 then
					H += 1.0
				end
				value_changed = true
				value_changed_h = true
			end
			local cos_hue_angle = if triangle_rotate then ImCos(-H * 2.0 * IM_PI) else 1.0
			local sin_hue_angle = if triangle_rotate then ImSin(-H * 2.0 * IM_PI) else 0.0
			if ImTriangleContainsPoint(triangle_pa, triangle_pb, triangle_pc, ImRotate(initial_off, cos_hue_angle, sin_hue_angle)) then
				local current_off_unrotated = ImRotate(current_off, cos_hue_angle, sin_hue_angle)
				if not ImTriangleContainsPoint(triangle_pa, triangle_pb, triangle_pc, current_off_unrotated) then
					current_off_unrotated = ImTriangleClosestPoint(triangle_pa, triangle_pb, triangle_pc, current_off_unrotated)
				end
				local uu, vv = ImTriangleBarycentricCoords(triangle_pa, triangle_pb, triangle_pc, current_off_unrotated)
				V = ImClamp(1.0 - vv, 0.0001, 1.0)
				S = ImClamp(uu / V, 0.0001, 1.0)
				value_changed = true
				value_changed_sv = true
			end
		end
		if not btest(flags, ImGuiColorEditFlags.NoOptions) then
			ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
		end
	elseif btest(flags, ImGuiColorEditFlags.PickerHueBar) then
		ImGui.InvisibleButton("sv", ImVec2(sv_picker_size, sv_picker_size))
		if ImGui.IsItemActive() and not is_readonly then
			S = ImSaturate((io.MousePos.x - picker_pos.x) / (sv_picker_size - 1))
			V = 1.0 - ImSaturate((io.MousePos.y - picker_pos.y) / (sv_picker_size - 1))
			H = ImGui.ColorEditRestoreH(col, H)
			value_changed = true
			value_changed_sv = true
		end
		if not btest(flags, ImGuiColorEditFlags.NoOptions) then
			ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
		end

		ImGui.SetCursorScreenPos(ImVec2(bar0_pos_x, picker_pos.y))
		ImGui.InvisibleButton("hue", ImVec2(bars_width, sv_picker_size))
		if ImGui.IsItemActive() and not is_readonly then
			H = ImSaturate((io.MousePos.y - picker_pos.y) / (sv_picker_size - 1))
			value_changed = true
			value_changed_h = true
		end
	end

	if alpha_bar then
		ImGui.SetCursorScreenPos(ImVec2(bar1_pos_x, picker_pos.y))
		ImGui.InvisibleButton("alpha", ImVec2(bars_width, sv_picker_size))
		if ImGui.IsItemActive() then
			col[4] = 1.0 - ImSaturate((io.MousePos.y - picker_pos.y) / (sv_picker_size - 1))
			value_changed = true
		end
	end
	ImGui.PopItemFlag()

	if not btest(flags, ImGuiColorEditFlags.NoSidePreview) then
		ImGui.SameLine(0, style.ItemInnerSpacing.x)
		ImGui.BeginGroup()
	end

	if not btest(flags, ImGuiColorEditFlags.NoLabel) then
		local label_display_end = ImGui.FindRenderedTextEnd(label)
		if label_display_end ~= 1 then
			if btest(flags, ImGuiColorEditFlags.NoSidePreview) then
				ImGui.SameLine(0, style.ItemInnerSpacing.x)
			end
			ImGui.TextEx(label, label_display_end)
		end
	end

	if not btest(flags, ImGuiColorEditFlags.NoSidePreview) then
		ImGui.PushItemFlag(ImGuiItemFlags.NoNavDefaultFocus, true)
		ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, false)
		local col_v4 = ImVec4(col[1], col[2], col[3], if btest(flags, ImGuiColorEditFlags.NoAlpha) then 1.0 else col[4])
		if btest(flags, ImGuiColorEditFlags.NoLabel) then
			ImGui.Text("Current")
		end

		local sub_flags_to_forward = bor(ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.AlphaMask_, ImGuiColorEditFlags.NoTooltip)
		ImGui.ColorButton("##current", col_v4, band(flags, sub_flags_to_forward), ImVec2(square_sz * 3, square_sz * 2))
		if ref_col ~= nil then
			ImGui.Text("Original")
			local ref_col_v4 = ImVec4(ref_col[1], ref_col[2], ref_col[3], if btest(flags, ImGuiColorEditFlags.NoAlpha) then 1.0 else ref_col[4])
			if ImGui.ColorButton("##original", ref_col_v4, band(flags, sub_flags_to_forward), ImVec2(square_sz * 3, square_sz * 2)) then
				for n = 1, components do
					col[n] = ref_col[n]
				end
				value_changed = true
			end
		end
		ImGui.PopItemFlag()
		ImGui.PopItemFlag()
		ImGui.EndGroup()
	end

	if value_changed_h or value_changed_sv then
		if btest(flags, ImGuiColorEditFlags.InputRGB) then
			col[1], col[2], col[3] = ImGui.ColorConvertHSVtoRGB(H, S, V)
			g.ColorEditSavedHue = H
			g.ColorEditSavedSat = S
			g.ColorEditSavedID = g.ColorEditCurrentID
			g.ColorEditSavedColor = ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], 0))
		elseif btest(flags, ImGuiColorEditFlags.InputHSV) then
			col[1] = H
			col[2] = S
			col[3] = V
		end
	end

	local value_changed_fix_hue_wrap = false
	if band(flags, ImGuiColorEditFlags.NoInputs) == 0 then
		ImGui.PushItemWidth((if alpha_bar then bar1_pos_x else bar0_pos_x) + bars_width - picker_pos.x)
		local sub_flags_to_forward = bor(ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.AlphaMask_, ImGuiColorEditFlags.NoOptions, ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoSmallPreview)
		local sub_flags = bor(band(flags, sub_flags_to_forward), ImGuiColorEditFlags.NoPicker)
		if btest(flags, ImGuiColorEditFlags.DisplayRGB) or band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
			if ImGui.ColorEdit4("##rgb", col, bor(sub_flags, ImGuiColorEditFlags.DisplayRGB)) then
				value_changed_fix_hue_wrap = (g.ActiveId ~= 0 and not g.ActiveIdAllowOverlap)
				value_changed = true
			end
		end
		if btest(flags, ImGuiColorEditFlags.DisplayHSV) or band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
			value_changed = ImGui.ColorEdit4("##hsv", col, bor(sub_flags, ImGuiColorEditFlags.DisplayHSV)) or value_changed
		end
		if btest(flags, ImGuiColorEditFlags.DisplayHex) or band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
			value_changed = ImGui.ColorEdit4("##hex", col, bor(sub_flags, ImGuiColorEditFlags.DisplayHex)) or value_changed
		end
		ImGui.PopItemWidth()
	end

	if value_changed_fix_hue_wrap and btest(flags, ImGuiColorEditFlags.InputRGB) then
		local new_H, new_S, new_V = ImGui.ColorConvertRGBtoHSV(col[1], col[2], col[3])
		if new_H <= 0 and H > 0 then
			if new_V <= 0 and V ~= new_V then
				col[1], col[2], col[3] = ImGui.ColorConvertHSVtoRGB(H, S, if new_V <= 0 then V * 0.5 else new_V)
			elseif new_S <= 0 then
				col[1], col[2], col[3] = ImGui.ColorConvertHSVtoRGB(H, if new_S <= 0 then S * 0.5 else new_S, new_V)
			end
		end
	end

	if value_changed then
		if btest(flags, ImGuiColorEditFlags.InputRGB) then
			R = col[1]
			G = col[2]
			B = col[3]
			H, S, V = ImGui.ColorConvertRGBtoHSV(R, G, B)
			H, S, V = ImGui.ColorEditRestoreHS(col, H, S, V)
		elseif btest(flags, ImGuiColorEditFlags.InputHSV) then
			H = col[1]
			S = col[2]
			V = col[3]
			R, G, B = ImGui.ColorConvertHSVtoRGB(H, S, V)
		end
	end

	local style_alpha8 = IM_F32_TO_INT8_SAT(style.Alpha)
	local col_black = IM_COL32(0, 0, 0, style_alpha8)
	local col_white = IM_COL32(255, 255, 255, style_alpha8)
	local col_midgrey = IM_COL32(128, 128, 128, style_alpha8)
	local col_hues = {
		IM_COL32(255, 0, 0, style_alpha8), IM_COL32(255, 255, 0, style_alpha8), IM_COL32(0, 255, 0, style_alpha8),
		IM_COL32(0, 255, 255, style_alpha8), IM_COL32(0, 0, 255, style_alpha8), IM_COL32(255, 0, 255, style_alpha8),
		IM_COL32(255, 0, 0, style_alpha8),
	}

	local hue_r, hue_g, hue_b = ImGui.ColorConvertHSVtoRGB(H, 1, 1)
	local hue_color_f = ImVec4(hue_r, hue_g, hue_b, style.Alpha)
	local hue_color32 = ImGui.ColorConvertFloat4ToU32(hue_color_f)
	local user_col32_striped_of_alpha = ImGui.ColorConvertFloat4ToU32(ImVec4(R, G, B, style.Alpha))

	local sv_cursor_pos = ImVec2(0, 0)

	if btest(flags, ImGuiColorEditFlags.PickerHueWheel) then
		local aeps = 0.5 / wheel_r_outer
		local segment_per_arc = ImMax(4, ImTruncToInt(wheel_r_outer) // 12)
		for n = 0, 5 do
			local a0 = n / 6.0 * 2.0 * IM_PI - aeps
			local a1 = (n + 1.0) / 6.0 * 2.0 * IM_PI + aeps
			local vert_start_idx = draw_list:GetPrimCount()
			draw_list:PathArcTo(wheel_center, (wheel_r_inner + wheel_r_outer) * 0.5, a0, a1, segment_per_arc)
			draw_list:PathStroke(col_white, wheel_thickness)
			local vert_end_idx = draw_list:GetPrimCount()

			local gradient_p0 = ImVec2(wheel_center.x + ImCos(a0) * wheel_r_inner, wheel_center.y + ImSin(a0) * wheel_r_inner)
			local gradient_p1 = ImVec2(wheel_center.x + ImCos(a1) * wheel_r_inner, wheel_center.y + ImSin(a1) * wheel_r_inner)
			ImGui.ShadeVertsLinearColorGradientKeepAlpha(draw_list, vert_start_idx, vert_end_idx, gradient_p0, gradient_p1, col_hues[n + 1], col_hues[n + 2])
		end

		local cos_hue_angle = ImCos(H * 2.0 * IM_PI)
		local sin_hue_angle = ImSin(H * 2.0 * IM_PI)
		local hue_cursor_pos = ImVec2(wheel_center.x + cos_hue_angle * (wheel_r_inner + wheel_r_outer) * 0.5, wheel_center.y + sin_hue_angle * (wheel_r_inner + wheel_r_outer) * 0.5)
		local hue_cursor_rad = if value_changed_h then wheel_thickness * 0.65 else wheel_thickness * 0.55
		local hue_cursor_segments = draw_list:_CalcCircleAutoSegmentCount(hue_cursor_rad)
		draw_list:AddCircleFilled(hue_cursor_pos, hue_cursor_rad, hue_color32, hue_cursor_segments)
		draw_list:AddCircle(hue_cursor_pos, hue_cursor_rad + 1, col_midgrey, hue_cursor_segments)
		draw_list:AddCircle(hue_cursor_pos, hue_cursor_rad, col_white, hue_cursor_segments)
		if triangle_rotate == false then
			cos_hue_angle = 1.0
			sin_hue_angle = 0.0
		end

		local tra = wheel_center + ImRotate(triangle_pa, cos_hue_angle, sin_hue_angle)
		local trb = wheel_center + ImRotate(triangle_pb, cos_hue_angle, sin_hue_angle)
		local trc = wheel_center + ImRotate(triangle_pc, cos_hue_angle, sin_hue_angle)
		local uv_white = ImGui.GetFontTexUvWhitePixel()
		draw_list:PrimReserve(3, 3)
		draw_list:PrimVtx(tra, uv_white, hue_color32)
		draw_list:PrimVtx(trb, uv_white, col_black)
		draw_list:PrimVtx(trc, uv_white, col_white)
		draw_list:AddTriangle(tra, trb, trc, col_midgrey, 1.5)
		sv_cursor_pos = ImLerp(ImLerp(trc, tra, ImSaturate(S)), trb, ImSaturate(1 - V))
	elseif btest(flags, ImGuiColorEditFlags.PickerHueBar) then
		draw_list:AddRectFilledMultiColor(picker_pos, picker_pos + ImVec2(sv_picker_size, sv_picker_size), col_white, hue_color32, hue_color32, col_white)
		draw_list:AddRectFilledMultiColor(picker_pos, picker_pos + ImVec2(sv_picker_size, sv_picker_size), 0, 0, col_black, col_black)
		ImGui.RenderFrameBorder(picker_pos, picker_pos + ImVec2(sv_picker_size, sv_picker_size), 0.0)
		sv_cursor_pos = ImVec2(
			ImClamp(IM_ROUND(picker_pos.x + ImSaturate(S) * sv_picker_size), picker_pos.x + 2, picker_pos.x + sv_picker_size - 2),
			ImClamp(IM_ROUND(picker_pos.y + ImSaturate(1 - V) * sv_picker_size), picker_pos.y + 2, picker_pos.y + sv_picker_size - 2)
		)

		for n = 0, 5 do
			draw_list:AddRectFilledMultiColor(ImVec2(bar0_pos_x, picker_pos.y + n * (sv_picker_size / 6)), ImVec2(bar0_pos_x + bars_width, picker_pos.y + (n + 1) * (sv_picker_size / 6)), col_hues[n + 1], col_hues[n + 1], col_hues[n + 2], col_hues[n + 2])
		end
		local bar0_line_y = IM_ROUND(picker_pos.y + H * sv_picker_size)
		ImGui.RenderFrameBorder(ImVec2(bar0_pos_x, picker_pos.y), ImVec2(bar0_pos_x + bars_width, picker_pos.y + sv_picker_size), 0.0)
		ImGui.RenderArrowsForVerticalBar(draw_list, ImVec2(bar0_pos_x - 1, bar0_line_y), ImVec2(bars_triangles_half_sz + 1, bars_triangles_half_sz), bars_width + 2.0, style.Alpha)
	end

	local sv_cursor_rad = if value_changed_sv then wheel_thickness * 0.55 else wheel_thickness * 0.40
	local sv_cursor_segments = draw_list:_CalcCircleAutoSegmentCount(sv_cursor_rad)
	draw_list:AddCircleFilled(sv_cursor_pos, sv_cursor_rad, user_col32_striped_of_alpha, sv_cursor_segments)
	draw_list:AddCircle(sv_cursor_pos, sv_cursor_rad + 1, col_midgrey, sv_cursor_segments)
	draw_list:AddCircle(sv_cursor_pos, sv_cursor_rad, col_white, sv_cursor_segments)

	if alpha_bar then
		local alpha = ImSaturate(col[4])
		local bar1_bb = ImRect.fromXY(bar1_pos_x, picker_pos.y, bar1_pos_x + bars_width, picker_pos.y + sv_picker_size)
		ImGui.RenderColorRectWithAlphaCheckerboard(draw_list, bar1_bb.Min, bar1_bb.Max, IM_COL32(0, 0, 0, 0), style.Alpha, bar1_bb:GetWidth() / 2.0, ImVec2(0.0, 0.0))
		local user_col32_no_alpha = band(user_col32_striped_of_alpha, bnot(IM_COL32_A_MASK))
		draw_list:AddRectFilledMultiColor(bar1_bb.Min, bar1_bb.Max, user_col32_striped_of_alpha, user_col32_striped_of_alpha, user_col32_no_alpha, user_col32_no_alpha)
		local bar1_line_y = IM_ROUND(picker_pos.y + (1.0 - alpha) * sv_picker_size)
		ImGui.RenderFrameBorder(bar1_bb.Min, bar1_bb.Max, 0.0)
		ImGui.RenderArrowsForVerticalBar(draw_list, ImVec2(bar1_pos_x - 1, bar1_line_y), ImVec2(bars_triangles_half_sz + 1, bars_triangles_half_sz), bars_width + 2.0, style.Alpha)
	end

	ImGui.EndGroup()

	if value_changed then
		local same = true
		for n = 1, components do
			if backup_initial_col[n] ~= col[n] then
				same = false
				break
			end
		end
		if same then
			value_changed = false
		end
	end
	if value_changed and g.LastItemData.ID ~= 0 then
		ImGui.MarkItemEdited(g.LastItemData.ID)
	end

	if set_current_color_edit_id then
		g.ColorEditCurrentID = 0
	end
	ImGui.PopID()

	if g.DisabledStackSize > 0 then
		g.Style.Alpha = backup_alpha
	end

	return value_changed
end

function ImGui.ColorButton(desc_id, col, flags, size_arg)
	if flags == nil then flags = 0 end
	if size_arg == nil then size_arg = ImVec2(0, 0) end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local id = window:GetID(desc_id)
	local default_size = ImGui.GetFrameHeight()
	local size = ImVec2(if size_arg.x == 0.0 then default_size else size_arg.x, if size_arg.y == 0.0 then default_size else size_arg.y)
	local bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + size)
	ImGui.ItemSize(bb:GetSize(), if size.y >= default_size then g.Style.FramePadding.y else 0.0)
	if not ImGui.ItemAdd(bb, id) then
		return false
	end

	local pressed, hovered = ImGui.ButtonBehavior(bb, id, nil, nil)

	if btest(flags, bor(ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.AlphaOpaque)) then
		flags = band(flags, bnot(bor(ImGuiColorEditFlags.AlphaNoBg, ImGuiColorEditFlags.AlphaPreviewHalf)))
	end

	local col_rgb = col
	if btest(flags, ImGuiColorEditFlags.InputHSV) then
		local r, gg, b = ImGui.ColorConvertHSVtoRGB(col_rgb.x, col_rgb.y, col_rgb.z)
		col_rgb = ImVec4(r, gg, b, col_rgb.w)
	end

	local col_rgb_without_alpha = ImVec4(col_rgb.x, col_rgb.y, col_rgb.z, 1.0)
	local grid_step = ImMin(size.x, size.y) / 2.99
	local rounding = ImMin(g.Style.FrameRounding, grid_step * 0.5)
	local is_mixed = band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0

	local backup_alpha = g.Style.Alpha
	if g.DisabledStackSize > 0 then
		g.Style.Alpha = g.DisabledAlphaBackup
	end
	if is_mixed then
		window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), rounding)
		ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextMixedValue + 1])
		if g.MixedValueLabel ~= nil then
			ImGui.RenderTextClipped(ImVec2(bb.Min.x, bb.Min.y + g.Style.FramePadding.y), bb.Max, g.MixedValueLabel, nil, nil, ImVec2(0.5, 0.0))
		end
		ImGui.PopStyleColor()
	elseif btest(flags, ImGuiColorEditFlags.AlphaPreviewHalf) and col_rgb.w < 1.0 then
		local mid_x = IM_ROUND((bb.Min.x + bb.Max.x) * 0.5)
		if band(flags, ImGuiColorEditFlags.AlphaNoBg) == 0 then
			ImGui.RenderColorRectWithAlphaCheckerboard(window.DrawList, ImVec2(bb.Min.x + grid_step, bb.Min.y), bb.Max, ImGui.ColorConvertFloat4ToU32(col_rgb), g.Style.Alpha, grid_step, ImVec2(-grid_step, 0.0), rounding, ImDrawFlags.RoundRight)
		else
			window.DrawList:AddRectFilled(ImVec2(bb.Min.x + grid_step, bb.Min.y), bb.Max, ImGui.GetColorU32(col_rgb), rounding, ImDrawFlags.RoundRight)
		end
		window.DrawList:AddRectFilled(bb.Min, ImVec2(mid_x, bb.Max.y), ImGui.GetColorU32(col_rgb_without_alpha), rounding, ImDrawFlags.RoundLeft)
	else
		local col_source = if btest(flags, ImGuiColorEditFlags.AlphaOpaque) then col_rgb_without_alpha else col_rgb
		if col_source.w < 1.0 and band(flags, ImGuiColorEditFlags.AlphaNoBg) == 0 then
			ImGui.RenderColorRectWithAlphaCheckerboard(window.DrawList, bb.Min, bb.Max, ImGui.ColorConvertFloat4ToU32(col_source), g.Style.Alpha, grid_step, ImVec2(0.0, 0.0), rounding)
		else
			window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(col_source), rounding)
		end
	end
	if g.DisabledStackSize > 0 then
		g.Style.Alpha = backup_alpha
	end
	ImGui.RenderNavCursor(bb, id)
	if band(flags, ImGuiColorEditFlags.NoBorder) == 0 then
		if g.Style.FrameBorderSize > 0.0 then
			ImGui.RenderFrameBorder(bb.Min, bb.Max, rounding)
		else
			window.DrawList:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), rounding, 1.0 * ImTruncToInt(g.Style._MainScale))
		end
	end

	if g.ActiveId == id and not btest(flags, ImGuiColorEditFlags.NoDragDrop) and ImGui.BeginDragDropSource() then
		if btest(flags, ImGuiColorEditFlags.NoAlpha) then
			ImGui.SetDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F, { col_rgb.x, col_rgb.y, col_rgb.z }, 4 * 3, ImGuiCond.Once)
		else
			ImGui.SetDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F, { col_rgb.x, col_rgb.y, col_rgb.z, col_rgb.w }, 4 * 4, ImGuiCond.Once)
		end
		ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, false)
		ImGui.ColorButton(desc_id, col, flags)
		ImGui.PopItemFlag()
		ImGui.SameLine()
		ImGui.TextEx("Color")
		ImGui.EndDragDropSource()
	end

	if not btest(flags, ImGuiColorEditFlags.NoTooltip) and hovered and ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
		ImGui.ColorTooltip(desc_id, { col.x, col.y, col.z, col.w }, band(flags, bor(ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.AlphaMask_)))
	end

	return pressed
end

function ImGui.SetColorEditOptions(flags)
	local g = ImGui.GImGui
	if band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
		flags = bor(flags, band(ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.DisplayMask_))
	end
	if band(flags, ImGuiColorEditFlags.DataTypeMask_) == 0 then
		flags = bor(flags, band(ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.DataTypeMask_))
	end
	if band(flags, ImGuiColorEditFlags.PickerMask_) == 0 then
		flags = bor(flags, band(ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.PickerMask_))
	end
	if band(flags, ImGuiColorEditFlags.InputMask_) == 0 then
		flags = bor(flags, band(ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.InputMask_))
	end
	g.IO.ConfigColorEditFlags = flags
end

function ImGui.ColorTooltip(text, col, flags)
	local g = ImGui.GImGui

	if not ImGui.BeginTooltipEx(ImGuiTooltipFlags.OverridePrevious, ImGuiWindowFlags.None) then
		return
	end
	local text_end = if text then ImGui.FindRenderedTextEnd(text, nil) else 1
	if text_end > 1 then
		ImGui.TextEx(text, text_end)
		ImGui.Separator()
	end

	local sz = ImVec2(g.FontSize * 3 + g.Style.FramePadding.y * 2, g.FontSize * 3 + g.Style.FramePadding.y * 2)
	local no_alpha = btest(flags, ImGuiColorEditFlags.NoAlpha)
	local cf = ImVec4(col[1], col[2], col[3], if no_alpha then 1.0 else col[4])
	local cr, cg, cb = IM_F32_TO_INT8_SAT(col[1]), IM_F32_TO_INT8_SAT(col[2]), IM_F32_TO_INT8_SAT(col[3])
	local ca = if no_alpha then 255 else IM_F32_TO_INT8_SAT(col[4])
	local flags_to_forward = bor(ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.AlphaMask_)
	ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, false)
	ImGui.ColorButton("##preview", cf, bor(band(flags, flags_to_forward), ImGuiColorEditFlags.NoTooltip), sz)
	ImGui.PopItemFlag()
	ImGui.SameLine()
	if btest(flags, ImGuiColorEditFlags.InputRGB) or not btest(flags, ImGuiColorEditFlags.InputMask_) then
		if no_alpha then
			ImGui.Text("#%02X%02X%02X\nR: %d, G: %d, B: %d\n(%.3f, %.3f, %.3f)", cr, cg, cb, cr, cg, cb, col[1], col[2], col[3])
		else
			ImGui.Text("#%02X%02X%02X%02X\nR:%d, G:%d, B:%d, A:%d\n(%.3f, %.3f, %.3f, %.3f)", cr, cg, cb, ca, cr, cg, cb, ca, col[1], col[2], col[3], col[4])
		end
	elseif btest(flags, ImGuiColorEditFlags.InputHSV) then
		if no_alpha then
			ImGui.Text("H: %.3f, S: %.3f, V: %.3f", col[1], col[2], col[3])
		else
			ImGui.Text("H: %.3f, S: %.3f, V: %.3f, A: %.3f", col[1], col[2], col[3], col[4])
		end
	end
	ImGui.EndTooltip()
end

function ImGui.ColorEditOptionsPopup(col, flags)
	local allow_opt_inputs = not btest(flags, ImGuiColorEditFlags.DisplayMask_)
	local allow_opt_datatype = not btest(flags, ImGuiColorEditFlags.DataTypeMask_)
	if (not allow_opt_inputs and not allow_opt_datatype) or not ImGui.BeginPopup("context") then
		return
	end

	local g = ImGui.GImGui
	ImGui.PushItemFlag(ImGuiItemFlags.NoMarkEdited, true)
	local opts = g.IO.ConfigColorEditFlags
	if allow_opt_inputs then
		if ImGui.RadioButton("RGB", btest(opts, ImGuiColorEditFlags.DisplayRGB)) then
			opts = bor(band(opts, bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayRGB)
		end
		if ImGui.RadioButton("HSV", btest(opts, ImGuiColorEditFlags.DisplayHSV)) then
			opts = bor(band(opts, bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayHSV)
		end
		if ImGui.RadioButton("Hex", btest(opts, ImGuiColorEditFlags.DisplayHex)) then
			opts = bor(band(opts, bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayHex)
		end
	end
	if allow_opt_datatype then
		if allow_opt_inputs then
			ImGui.Separator()
		end
		if ImGui.RadioButton("0..255", btest(opts, ImGuiColorEditFlags.Uint8)) then
			opts = bor(band(opts, bnot(ImGuiColorEditFlags.DataTypeMask_)), ImGuiColorEditFlags.Uint8)
		end
		if ImGui.RadioButton("0.00..1.00", btest(opts, ImGuiColorEditFlags.Float)) then
			opts = bor(band(opts, bnot(ImGuiColorEditFlags.DataTypeMask_)), ImGuiColorEditFlags.Float)
		end
	end

	if allow_opt_inputs or allow_opt_datatype then
		ImGui.Separator()
	end
	if ImGui.Button("Copy as..", ImVec2(-1, 0)) then
		ImGui.OpenPopup("Copy")
	end
	if ImGui.BeginPopup("Copy") then
		local no_alpha = btest(flags, ImGuiColorEditFlags.NoAlpha)
		local cr, cg, cb = IM_F32_TO_INT8_SAT(col[1]), IM_F32_TO_INT8_SAT(col[2]), IM_F32_TO_INT8_SAT(col[3])
		local ca = if no_alpha then 255 else IM_F32_TO_INT8_SAT(col[4])
		local buf = ImFormatString("(%.3ff, %.3ff, %.3ff, %.3ff)", col[1], col[2], col[3], if no_alpha then 1.0 else col[4])
		if ImGui.Selectable(buf) then
			ImGui.SetClipboardText(buf)
		end
		buf = ImFormatString("(%d,%d,%d,%d)", cr, cg, cb, ca)
		if ImGui.Selectable(buf) then
			ImGui.SetClipboardText(buf)
		end
		buf = ImFormatString("#%02X%02X%02X", cr, cg, cb)
		if ImGui.Selectable(buf) then
			ImGui.SetClipboardText(buf)
		end
		if not no_alpha then
			buf = ImFormatString("#%02X%02X%02X%02X", cr, cg, cb, ca)
			if ImGui.Selectable(buf) then
				ImGui.SetClipboardText(buf)
			end
		end
		ImGui.EndPopup()
	end

	g.IO.ConfigColorEditFlags = opts
	ImGui.PopItemFlag()
	ImGui.EndPopup()
end

function ImGui.ColorPickerOptionsPopup(ref_col, flags)
	local allow_opt_picker = not btest(flags, ImGuiColorEditFlags.PickerMask_)
	local allow_opt_alpha_bar = not btest(flags, ImGuiColorEditFlags.NoAlpha) and not btest(flags, ImGuiColorEditFlags.AlphaBar)
	if (not allow_opt_picker and not allow_opt_alpha_bar) or not ImGui.BeginPopup("context") then
		return
	end

	local g = ImGui.GImGui
	ImGui.PushItemFlag(ImGuiItemFlags.NoMarkEdited, true)
	if allow_opt_picker then
		local picker_size = ImVec2(g.FontSize * 8, ImMax(g.FontSize * 8 - (ImGui.GetFrameHeight() + g.Style.ItemInnerSpacing.x), 1.0))
		ImGui.PushItemWidth(picker_size.x)
		for picker_type = 0, 1 do
			if picker_type > 0 then
				ImGui.Separator()
			end
			ImGui.PushID(picker_type)
			local picker_flags = bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoOptions, ImGuiColorEditFlags.NoLabel, ImGuiColorEditFlags.NoSidePreview, band(flags, ImGuiColorEditFlags.NoAlpha))
			if picker_type == 0 then
				picker_flags = bor(picker_flags, ImGuiColorEditFlags.PickerHueBar)
			end
			if picker_type == 1 then
				picker_flags = bor(picker_flags, ImGuiColorEditFlags.PickerHueWheel)
			end
			local backup_pos = ImGui.GetCursorScreenPos()
			if ImGui.Selectable("##selectable", false, 0, picker_size) then
				g.IO.ConfigColorEditFlags = bor(band(g.IO.ConfigColorEditFlags, bnot(ImGuiColorEditFlags.PickerMask_)), band(picker_flags, ImGuiColorEditFlags.PickerMask_))
			end
			ImGui.SetCursorScreenPos(backup_pos)
			local previewing_ref_col = { 0, 0, 0, 0 }
			for n = 1, if btest(picker_flags, ImGuiColorEditFlags.NoAlpha) then 3 else 4 do
				previewing_ref_col[n] = ref_col[n]
			end
			ImGui.ColorPicker4("##previewing_picker", previewing_ref_col, picker_flags)
			ImGui.PopID()
		end
		ImGui.PopItemWidth()
	end
	if allow_opt_alpha_bar then
		if allow_opt_picker then
			ImGui.Separator()
		end
		local _
		_, g.IO.ConfigColorEditFlags = ImGui.CheckboxFlags("Alpha Bar", g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.AlphaBar)
	end
	ImGui.PopItemFlag()
	ImGui.EndPopup()
end

function ImGui.TreeNode(str_id_or_label, fmt, ...)
	if fmt == nil then
		local window = ImGui.GetCurrentWindow()
		if window.SkipItems then
			return false
		end
		local id = window:GetID(str_id_or_label)
		return ImGui.TreeNodeBehavior(id, ImGuiTreeNodeFlags.None, str_id_or_label, nil)
	end
	return ImGui.TreeNodeExV(str_id_or_label, 0, fmt, ...)
end

function ImGui.TreeNodeV(str_or_ptr_id, fmt, ...)
	return ImGui.TreeNodeExV(str_or_ptr_id, 0, fmt, ...)
end

function ImGui.TreeNodeEx(str_id_or_label, flags, fmt, ...)
	if flags == nil then flags = 0 end
	if fmt == nil then
		local window = ImGui.GetCurrentWindow()
		if window.SkipItems then
			return false
		end
		local id = window:GetID(str_id_or_label)
		return ImGui.TreeNodeBehavior(id, flags, str_id_or_label, nil)
	end
	return ImGui.TreeNodeExV(str_id_or_label, flags, fmt, ...)
end

function ImGui.TreeNodeExV(str_or_ptr_id, flags, fmt, ...)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local id = window:GetID(str_or_ptr_id)
	local label = if select("#", ...) == 0 then fmt else ImFormatString(fmt, ...)
	return ImGui.TreeNodeBehavior(id, flags, label, #label + 1)
end

function ImGui.TreeNodeGetOpen(storage_id)
	local g = ImGui.GImGui
	local storage = g.CurrentWindow.DC.StateStorage
	return storage:GetInt(storage_id, 0) ~= 0
end

function ImGui.TreeNodeSetOpen(storage_id, is_open)
	local g = ImGui.GImGui
	local storage = g.CurrentWindow.DC.StateStorage
	storage:SetInt(storage_id, if is_open then 1 else 0)
end

function ImGui.TreeNodeUpdateNextOpen(storage_id, flags)
	if btest(flags, ImGuiTreeNodeFlags.Leaf) then
		return true
	end

	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local storage = window.DC.StateStorage

	local is_open
	if btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasOpen) then
		if btest(g.NextItemData.OpenCond, ImGuiCond.Always) then
			is_open = g.NextItemData.OpenVal
			ImGui.TreeNodeSetOpen(storage_id, is_open)
		else
			local stored_value = storage:GetInt(storage_id, -1)
			if stored_value == -1 then
				is_open = g.NextItemData.OpenVal
				ImGui.TreeNodeSetOpen(storage_id, is_open)
			else
				is_open = stored_value ~= 0
			end
		end
	else
		is_open = storage:GetInt(storage_id, if btest(flags, ImGuiTreeNodeFlags.DefaultOpen) then 1 else 0) ~= 0
	end

	if g.LogEnabled and not btest(flags, ImGuiTreeNodeFlags.NoAutoOpenOnLog) and (window.DC.TreeDepth - g.LogDepthRef) < g.LogDepthToExpand then
		is_open = true
	end

	return is_open
end

function ImGui.TreeNodeStoreStackData(flags, x1)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local tree_node_data = Structs.ImGuiTreeNodeStackData.new()
	g.TreeNodeStack:push_back(tree_node_data)
	tree_node_data.ID = g.LastItemData.ID
	tree_node_data.TreeFlags = flags
	tree_node_data.ItemFlags = g.LastItemData.ItemFlags
	tree_node_data.NavRect = g.LastItemData.NavRect

	local draw_lines = band(flags, bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes)) ~= 0
	tree_node_data.DrawLinesX1 = if draw_lines then (x1 + g.FontSize * 0.5 + g.Style.FramePadding.x) else FLT_MAX
	tree_node_data.DrawLinesTableColumn = if (draw_lines and g.CurrentTable) then g.CurrentTable.CurrentColumn else -1
	tree_node_data.DrawLinesToNodesY2 = -FLT_MAX
	window.DC.TreeHasStackDataDepthMask = bor(window.DC.TreeHasStackDataDepthMask, lshift(1, window.DC.TreeDepth))
	if btest(flags, ImGuiTreeNodeFlags.DrawLinesToNodes) then
		window.DC.TreeRecordsClippedNodesY2Mask = bor(window.DC.TreeRecordsClippedNodesY2Mask, lshift(1, window.DC.TreeDepth))
	end
end

local TREE_NODE_MAX_DEPTH = 32

local function TREE_NODE_GET_DEPTH_MASK(depth)
	if depth >= 0 and depth < TREE_NODE_MAX_DEPTH then
		return lshift(1, depth)
	end
	return 0
end

function ImGui.TreeNodeBehavior(id, flags, label, label_end)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local style = g.Style

	local display_frame = band(flags, ImGuiTreeNodeFlags.Framed) ~= 0
	local use_frame_padding = display_frame or btest(flags, ImGuiTreeNodeFlags.FramePadding)
	local padding = if use_frame_padding then style.FramePadding else ImVec2(style.FramePadding.x, ImMin(window.DC.CurrLineTextBaseOffset, style.FramePadding.y))

	if not label_end then
		label_end = ImGui.FindRenderedTextEnd(label)
	end
	local label_size = ImGui.CalcTextSize(label, label_end, false)

	local text_offset_x = g.FontSize + (if display_frame then padding.x * 3 else padding.x * 2)
	local text_offset_y = if use_frame_padding then ImMax(style.FramePadding.y, window.DC.CurrLineTextBaseOffset) else window.DC.CurrLineTextBaseOffset
	local text_width = g.FontSize + label_size.x + padding.x * 2

	local frame_height = label_size.y + padding.y * 2
	local span_all_columns = band(flags, ImGuiTreeNodeFlags.SpanAllColumns) ~= 0 and (g.CurrentTable ~= nil)
	local span_all_columns_label = band(flags, ImGuiTreeNodeFlags.LabelSpanAllColumns) ~= 0 and (g.CurrentTable ~= nil)
	local cursor_pos = window.DC.CursorPos
	local frame_min_x = if span_all_columns then window.ParentWorkRect.Min.x elseif btest(flags, ImGuiTreeNodeFlags.SpanFullWidth) then window.WorkRect.Min.x else cursor_pos.x
	local frame_min_y = cursor_pos.y + (text_offset_y - padding.y)
	local frame_max_x = if span_all_columns then window.ParentWorkRect.Max.x elseif btest(flags, ImGuiTreeNodeFlags.SpanLabelWidth) then cursor_pos.x + text_width + padding.x else window.WorkRect.Max.x
	local frame_max_y = cursor_pos.y + (text_offset_y - padding.y) + frame_height
	if display_frame then
		local outer_extend = IM_TRUNC(window.WindowPadding.x * 0.5)
		frame_min_x -= outer_extend
		frame_max_x += outer_extend
	end
	local frame_bb = ImRect.fromXY(frame_min_x, frame_min_y, frame_max_x, frame_max_y)

	local text_pos = ImVec2(cursor_pos.x + text_offset_x, cursor_pos.y + text_offset_y)
	ImGui.ItemSize(ImVec2(text_width, frame_height), padding.y)

	local interact_bb = frame_bb
	if band(flags, bor(ImGuiTreeNodeFlags.Framed, ImGuiTreeNodeFlags.SpanAvailWidth, ImGuiTreeNodeFlags.SpanFullWidth, ImGuiTreeNodeFlags.SpanLabelWidth, ImGuiTreeNodeFlags.SpanAllColumns)) == 0 then
		interact_bb = interact_bb:WithMaxX(frame_bb.Min.x + text_width + (if label_size.x > 0.0 then style.ItemSpacing.x * 2.0 else 0.0))
	end

	local storage_id = if btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasStorageID) then g.NextItemData.StorageId else id
	local is_open = ImGui.TreeNodeUpdateNextOpen(storage_id, flags)

	local is_visible
	if span_all_columns or span_all_columns_label then
		local backup_clip_rect_min_x = window.ClipRect.Min.x
		local backup_clip_rect_max_x = window.ClipRect.Max.x
		window.ClipRect = window.ClipRect:WithMinX(window.ParentWorkRect.Min.x):WithMaxX(window.ParentWorkRect.Max.x)
		is_visible = ImGui.ItemAdd(interact_bb, id)
		window.ClipRect = window.ClipRect:WithMinX(backup_clip_rect_min_x):WithMaxX(backup_clip_rect_max_x)
	else
		is_visible = ImGui.ItemAdd(interact_bb, id)
	end
	g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasDisplayRect)
	g.LastItemData.DisplayRect = frame_bb

	local store_tree_node_stack_data = false
	if band(flags, ImGuiTreeNodeFlags.DrawLinesMask_) == 0 then
		flags = bor(flags, g.Style.TreeLinesFlags)
	end
	local draw_tree_lines = btest(flags, bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes)) and (frame_bb.Min.y < window.ClipRect.Max.y) and (g.Style.TreeLinesSize > 0.0)
	if not btest(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) and window.DC.TreeDepth < TREE_NODE_MAX_DEPTH then
		store_tree_node_stack_data = draw_tree_lines
		if btest(flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent) and not g.NavIdIsAlive then
			if g.NavMoveDir == ImGuiDir.Left and g.NavWindow == window and ImGui.NavMoveRequestButNoResultYet() then
				store_tree_node_stack_data = true
			end
		end
	end

	local is_leaf = band(flags, ImGuiTreeNodeFlags.Leaf) ~= 0
	if not is_visible then
		if btest(flags, ImGuiTreeNodeFlags.DrawLinesToNodes) then
			local tree_depth_mask = TREE_NODE_GET_DEPTH_MASK(window.DC.TreeDepth - 1)
			if btest(window.DC.TreeRecordsClippedNodesY2Mask, tree_depth_mask) then
				local parent_data = g.TreeNodeStack[g.TreeNodeStack.Size]
				parent_data.DrawLinesToNodesY2 = ImMax(parent_data.DrawLinesToNodesY2, window.DC.CursorPos.y)
				if frame_bb.Min.y >= window.ClipRect.Max.y then
					window.DC.TreeRecordsClippedNodesY2Mask = band(window.DC.TreeRecordsClippedNodesY2Mask, bnot(tree_depth_mask))
				end
			end
		end
		if is_open and store_tree_node_stack_data then
			ImGui.TreeNodeStoreStackData(flags, text_pos.x - text_offset_x)
		end
		if is_open and not btest(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) then
			ImGui.TreePushOverrideID(id)
		end
		return is_open
	end

	if span_all_columns or span_all_columns_label then
		ImGui.TablePushBackgroundChannel()
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasClipRect)
		g.LastItemData.ClipRect = window.ClipRect
	end

	local button_flags = ImGuiTreeNodeFlags.None
	if btest(flags, ImGuiTreeNodeFlags.AllowOverlap) or btest(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowOverlap) then
		button_flags = bor(button_flags, ImGuiButtonFlags.AllowOverlap)
	end
	if not is_leaf then
		button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnDragDropHold)
	end

	local arrow_hit_x1 = (text_pos.x - text_offset_x) - style.TouchExtraPadding.x
	local arrow_hit_x2 = (text_pos.x - text_offset_x) + (g.FontSize + padding.x * 2.0) + style.TouchExtraPadding.x
	local is_mouse_x_over_arrow = (g.IO.MousePos.x >= arrow_hit_x1 and g.IO.MousePos.x < arrow_hit_x2)

	local is_multi_select = band(g.LastItemData.ItemFlags, ImGuiItemFlags.IsMultiSelect) ~= 0
	if is_multi_select then
		flags = bor(flags, if band(flags, ImGuiTreeNodeFlags.OpenOnMask_) == 0 then bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick) else ImGuiTreeNodeFlags.OpenOnArrow)
	end

	if is_mouse_x_over_arrow then
		button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnClick)
	elseif btest(flags, ImGuiTreeNodeFlags.OpenOnDoubleClick) then
		button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnDoubleClick)
	else
		button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease)
	end
	if btest(flags, ImGuiTreeNodeFlags.NoNavFocus) then
		button_flags = bor(button_flags, ImGuiButtonFlags.NoNavFocus)
	end

	local selected = band(flags, ImGuiTreeNodeFlags.Selected) ~= 0
	local was_selected = selected

	if is_multi_select then
		selected, button_flags = ImGui.MultiSelectItemHeader(id, selected, button_flags)
		if is_mouse_x_over_arrow then
			button_flags = band(bor(button_flags, ImGuiButtonFlags.PressedOnClick), bnot(ImGuiButtonFlags.PressedOnClickRelease))
		end
	else
		if window ~= g.HoveredWindow or not is_mouse_x_over_arrow then
			button_flags = bor(button_flags, ImGuiButtonFlags.NoKeyModsAllowed)
		end
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(interact_bb, id, nil, nil, button_flags)
	local toggled = false
	if not is_leaf then
		if pressed and g.DragDropHoldJustPressedId ~= id then
			if band(flags, ImGuiTreeNodeFlags.OpenOnMask_) == 0 or (g.NavActivateId == id and not is_multi_select) then
				toggled = true
			end
			if btest(flags, ImGuiTreeNodeFlags.OpenOnArrow) then
				toggled = toggled or (is_mouse_x_over_arrow and not g.NavHighlightItemUnderNav)
			end
			if btest(flags, ImGuiTreeNodeFlags.OpenOnDoubleClick) and g.IO.MouseClickedCount[1] == 2 then
				toggled = true
			end
		elseif pressed and g.DragDropHoldJustPressedId == id then
			assert(btest(button_flags, ImGuiButtonFlags.PressedOnDragDropHold))
			if not is_open then
				toggled = true
			else
				pressed = false
			end
		end

		if g.NavId == id and g.NavMoveDir == ImGuiDir.Left and is_open then
			toggled = true
			ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
			ImGui.NavMoveRequestCancel()
		end
		if g.NavId == id and g.NavMoveDir == ImGuiDir.Right and not is_open then
			toggled = true
			ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
			ImGui.NavMoveRequestCancel()
		end

		if toggled then
			is_open = not is_open
			window.DC.StateStorage:SetInt(storage_id, if is_open then 1 else 0)
			g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledOpen)
		end
	end

	if is_multi_select then
		local pressed_copy = pressed and not toggled
		selected, pressed_copy = ImGui.MultiSelectItemFooter(id, selected, pressed_copy)
		if pressed then
			ImGui.SetNavID(id, window.DC.NavLayerCurrent, g.CurrentFocusScopeId, interact_bb)
		end
	end

	if selected ~= was_selected then
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledSelection)
	end

	do
		local text_col = ImGui.GetColorU32(ImGuiCol.Text)
		local nav_render_cursor_flags = ImGuiNavRenderCursorFlags.Compact
		if is_multi_select then
			nav_render_cursor_flags = bor(nav_render_cursor_flags, ImGuiNavRenderCursorFlags.AlwaysDraw)
		end
		if display_frame then
			local bg_col = ImGui.GetColorU32(if (held and hovered) then ImGuiCol.HeaderActive elseif hovered then ImGuiCol.HeaderHovered else ImGuiCol.Header)
			ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, bg_col, true, style.FrameRounding)
			ImGui.RenderNavCursor(frame_bb, id, nav_render_cursor_flags)
			if span_all_columns and not span_all_columns_label then
				ImGui.TablePopBackgroundChannel()
			end
			if btest(flags, ImGuiTreeNodeFlags.Bullet) then
				ImGui.RenderBullet(window.DrawList, ImVec2(text_pos.x - text_offset_x * 0.60, text_pos.y + g.FontSize * 0.5), text_col)
			elseif not is_leaf then
				ImGui.RenderArrow(window.DrawList, ImVec2(text_pos.x - text_offset_x + padding.x, text_pos.y), text_col, if is_open then (if btest(flags, ImGuiTreeNodeFlags.UpsideDownArrow) then ImGuiDir.Up else ImGuiDir.Down) else ImGuiDir.Right, 1.0)
			else
				text_pos = ImVec2(text_pos.x - (text_offset_x - padding.x), text_pos.y)
			end
			if btest(flags, ImGuiTreeNodeFlags.ClipLabelForTrailingButton) then
				frame_bb = frame_bb:WithMaxX(frame_bb.Max.x - (g.FontSize + style.FramePadding.x))
			end
			if g.LogEnabled then
				ImGui.LogSetNextTextDecoration("###", "###")
			end
		else
			if hovered or selected then
				local bg_col = ImGui.GetColorU32(if (held and hovered) then ImGuiCol.HeaderActive elseif hovered then ImGuiCol.HeaderHovered else ImGuiCol.Header)
				ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, bg_col, false, 0.0)
			end
			ImGui.RenderNavCursor(frame_bb, id, nav_render_cursor_flags, 0.0)
			if span_all_columns and not span_all_columns_label then
				ImGui.TablePopBackgroundChannel()
			end
			if btest(flags, ImGuiTreeNodeFlags.Bullet) then
				ImGui.RenderBullet(window.DrawList, ImVec2(text_pos.x - text_offset_x * 0.5, text_pos.y + g.FontSize * 0.5), text_col)
			elseif not is_leaf then
				ImGui.RenderArrow(window.DrawList, ImVec2(text_pos.x - text_offset_x + padding.x, text_pos.y + g.FontSize * 0.15), text_col, if is_open then (if btest(flags, ImGuiTreeNodeFlags.UpsideDownArrow) then ImGuiDir.Up else ImGuiDir.Down) else ImGuiDir.Right, 0.70)
			end
			if g.LogEnabled then
				ImGui.LogSetNextTextDecoration(">", nil)
			end
		end

		if draw_tree_lines then
			ImGui.TreeNodeDrawLineToChildNode(ImVec2(text_pos.x - text_offset_x + padding.x, text_pos.y + g.FontSize * 0.5))
		end

		if display_frame then
			ImGui.RenderTextClipped(text_pos, frame_bb.Max, label, label_end, label_size)
		else
			ImGui.RenderText(text_pos, label, label_end, false)
		end

		if span_all_columns_label then
			ImGui.TablePopBackgroundChannel()
		end
	end

	if is_open and store_tree_node_stack_data then
		ImGui.TreeNodeStoreStackData(flags, text_pos.x - text_offset_x)
	end
	if is_open and not btest(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) then
		ImGui.TreePushOverrideID(id)
	end

	return is_open
end

function ImGui.TreeNodeDrawLineToChildNode(target_pos)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if band(window.DC.TreeHasStackDataDepthMask, TREE_NODE_GET_DEPTH_MASK(window.DC.TreeDepth - 1)) == 0 then
		return
	end

	local parent_data = g.TreeNodeStack[g.TreeNodeStack.Size]
	local half_size = g.Style.TreeLinesSize * 0.5
	local x1 = ImTrunc(parent_data.DrawLinesX1 - half_size) + half_size
	local x2 = ImTrunc(target_pos.x - g.Style.ItemInnerSpacing.x)
	local y = ImTrunc(target_pos.y - half_size) + half_size
	local rounding = if g.Style.TreeLinesRounding > 0.0 then ImMin(x2 - x1, g.Style.TreeLinesRounding) else 0.0
	parent_data.DrawLinesToNodesY2 = ImMax(parent_data.DrawLinesToNodesY2, y - rounding)
	if x1 >= x2 then
		return
	end
	if rounding > 0.0 and rounding > half_size then
		x1 += rounding
		window.DrawList:PathArcToFast(ImVec2(x1, y - rounding), rounding, 6, 3)
		if x1 < x2 then
			window.DrawList:PathLineTo(ImVec2(x2, y))
		end
		window.DrawList:PathStroke(ImGui.GetColorU32(ImGuiCol.TreeLines), g.Style.TreeLinesSize)
	else
		x1 += half_size
		window.DrawList:AddLine(ImVec2(x1, y), ImVec2(x2, y), ImGui.GetColorU32(ImGuiCol.TreeLines), g.Style.TreeLinesSize)
	end
end

function ImGui.TreeNodeDrawLineToTreePop(data)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local y1 = ImMax(data.NavRect.Max.y, window.ClipRect.Min.y)
	local y2 = data.DrawLinesToNodesY2
	if btest(data.TreeFlags, ImGuiTreeNodeFlags.DrawLinesFull) then
		local y2_full = window.DC.CursorPos.y
		if g.CurrentTable then
			y2_full = ImMax(g.CurrentTable.RowPosY2, y2_full)
		end
		y2_full = ImTrunc(y2_full - g.Style.ItemSpacing.y - g.FontSize * 0.5)
		if y2 + (g.Style.ItemSpacing.y + g.Style.TreeLinesRounding) < y2_full then
			y2 = y2_full
		end
	end
	y2 = ImMin(y2, window.ClipRect.Max.y)
	if y2 <= y1 then
		return
	end
	local x = ImTrunc(data.DrawLinesX1 - g.Style.TreeLinesSize * 0.5) + g.Style.TreeLinesSize * 0.5
	if data.DrawLinesTableColumn ~= -1 then
		ImGui.TablePushColumnChannel(data.DrawLinesTableColumn)
	end

	window.DrawList:AddLine(ImVec2(x, y1), ImVec2(x, y2), ImGui.GetColorU32(ImGuiCol.TreeLines), g.Style.TreeLinesSize)
	if data.DrawLinesTableColumn ~= -1 then
		ImGui.TablePopColumnChannel()
	end
end

function ImGui.TreePush(str_or_ptr_id)
	local window = ImGui.GetCurrentWindow()
	ImGui.Indent()
	window.DC.TreeDepth += 1
	ImGui.PushID(str_or_ptr_id)
end

function ImGui.TreePushOverrideID(id)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	ImGui.Indent()
	window.DC.TreeDepth += 1
	ImGui.PushOverrideID(id)
end

function ImGui.TreePop()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	ImGui.Unindent()

	window.DC.TreeDepth -= 1
	local tree_depth_mask = TREE_NODE_GET_DEPTH_MASK(window.DC.TreeDepth)
	if btest(window.DC.TreeHasStackDataDepthMask, tree_depth_mask) then
		local data = g.TreeNodeStack[g.TreeNodeStack.Size]
		assert(data.ID == window.IDStack:back())

		if btest(data.TreeFlags, ImGuiTreeNodeFlags.NavLeftJumpsToParent) then
			if g.NavIdIsAlive and g.NavMoveDir == ImGuiDir.Left and g.NavWindow == window and ImGui.NavMoveRequestButNoResultYet() then
				ImGui.NavMoveRequestResolveWithPastTreeNode(g.NavMoveResultLocal, data)
			end
		end

		if data.DrawLinesX1 ~= FLT_MAX and window.DC.CursorPos.y >= window.ClipRect.Min.y then
			ImGui.TreeNodeDrawLineToTreePop(data)
		end

		g.TreeNodeStack:pop_back()
		window.DC.TreeHasStackDataDepthMask = band(window.DC.TreeHasStackDataDepthMask, bnot(tree_depth_mask))
		window.DC.TreeRecordsClippedNodesY2Mask = band(window.DC.TreeRecordsClippedNodesY2Mask, bnot(tree_depth_mask))
	end

	assert(window.IDStack.Size > 1)
	ImGui.PopID()
end

function ImGui.GetTreeNodeToLabelSpacing()
	local g = ImGui.GImGui
	return g.FontSize + (g.Style.FramePadding.x * 2.0)
end

function ImGui.SetNextItemOpen(is_open, cond)
	if cond == nil then cond = 0 end
	local g = ImGui.GImGui
	if g.CurrentWindow.SkipItems then
		return
	end
	g.NextItemData.HasFlags = bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasOpen)
	g.NextItemData.OpenVal = is_open
	g.NextItemData.OpenCond = if cond ~= 0 then cond else ImGuiCond.Always
end

function ImGui.SetNextItemStorageID(storage_id)
	local g = ImGui.GImGui
	if g.CurrentWindow.SkipItems then
		return
	end
	g.NextItemData.HasFlags = bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasStorageID)
	g.NextItemData.StorageId = storage_id
end

function ImGui.CollapsingHeader(label, p_visible_or_flags, flags)
	if type(p_visible_or_flags) ~= "boolean" then
		local f = p_visible_or_flags or flags or 0
		local window = ImGui.GetCurrentWindow()
		if window.SkipItems then
			return false
		end
		local id = window:GetID(label)
		return ImGui.TreeNodeBehavior(id, bor(f, ImGuiTreeNodeFlags.CollapsingHeader), label)
	end

	local p_visible = p_visible_or_flags
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, p_visible
	end

	if not p_visible then
		return false, p_visible
	end

	local id = window:GetID(label)
	flags = bor(flags, ImGuiTreeNodeFlags.CollapsingHeader, ImGuiTreeNodeFlags.AllowOverlap, ImGuiTreeNodeFlags.ClipLabelForTrailingButton)
	local is_open = ImGui.TreeNodeBehavior(id, flags, label)
	do
		local g = ImGui.GImGui
		local last_item_backup = g.LastItemData:Copy()
		local button_size = g.FontSize
		local button_x = ImMax(g.LastItemData.Rect.Min.x, g.LastItemData.Rect.Max.x - g.Style.FramePadding.x - button_size)
		local button_y = g.LastItemData.Rect.Min.y + g.Style.FramePadding.y
		local close_button_id = ImGui.GetIDWithSeed("#CLOSE", nil, id)
		if ImGui.CloseButton(close_button_id, ImVec2(button_x, button_y)) then
			p_visible = false
		end
		g.LastItemData = last_item_backup
	end

	return is_open, p_visible
end

function ImGui.Selectable(label, selected_in, flags, size_arg)
	if selected_in == nil then selected_in = false end
	if flags == nil then flags = 0 end
	if size_arg == nil then size_arg = ImVec2(0, 0) end
	local selected = selected_in
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, selected_in
	end

	local g = ImGui.GImGui
	local style = g.Style

	local id = window:GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local size = ImVec2(if size_arg.x ~= 0.0 then size_arg.x else label_size.x, if size_arg.y ~= 0.0 then size_arg.y else label_size.y)
	local pos = window.DC.CursorPos
	pos = ImVec2(pos.x, pos.y + window.DC.CurrLineTextBaseOffset)
	ImGui.ItemSize(size, 0.0)

	local span_all_columns = band(flags, ImGuiSelectableFlags.SpanAllColumns) ~= 0
	local min_x = if span_all_columns then window.ParentWorkRect.Min.x else pos.x
	local max_x = if span_all_columns then window.ParentWorkRect.Max.x else window.WorkRect.Max.x
	if size_arg.x == 0.0 or btest(flags, ImGuiSelectableFlags.SpanAvailWidth) then
		size = ImVec2(ImMax(label_size.x, max_x - min_x), size.y)
	end

	local bb = ImRect.fromXY(min_x, pos.y, min_x + size.x, pos.y + size.y)
	if band(flags, ImGuiSelectableFlags.NoPadWithHalfSpacing) == 0 then
		local spacing_x = if span_all_columns then 0.0 else style.ItemSpacing.x
		local spacing_y = style.ItemSpacing.y
		local spacing_L = IM_TRUNC(spacing_x * 0.50)
		local spacing_U = IM_TRUNC(spacing_y * 0.50)
		bb = ImRect.fromXY(bb.Min.x - spacing_L, bb.Min.y - spacing_U, bb.Max.x + (spacing_x - spacing_L), bb.Max.y + (spacing_y - spacing_U))
	end

	local disabled_item = band(flags, ImGuiSelectableFlags.Disabled) ~= 0
	local extra_item_flags = if disabled_item then ImGuiItemFlags.Disabled else ImGuiItemFlags.None
	local is_visible
	if span_all_columns then
		local backup_clip_rect_min_x = window.ClipRect.Min.x
		local backup_clip_rect_max_x = window.ClipRect.Max.x
		window.ClipRect = window.ClipRect:WithMinX(window.ParentWorkRect.Min.x):WithMaxX(window.ParentWorkRect.Max.x)
		is_visible = ImGui.ItemAdd(bb, id, nil, extra_item_flags)
		window.ClipRect = window.ClipRect:WithMinX(backup_clip_rect_min_x):WithMaxX(backup_clip_rect_max_x)
	else
		is_visible = ImGui.ItemAdd(bb, id, nil, extra_item_flags)
	end

	local is_multi_select = band(g.LastItemData.ItemFlags, ImGuiItemFlags.IsMultiSelect) ~= 0
	if not is_visible then
		if not is_multi_select or not g.BoxSelectState.UnclipMode or not g.BoxSelectState.UnclipRect:Overlaps(bb) then
			return false, selected_in
		end
	end

	local disabled_global = band(g.CurrentItemFlags, ImGuiItemFlags.Disabled) ~= 0
	if disabled_item and not disabled_global then
		ImGui.BeginDisabled()
	end

	if span_all_columns then
		if g.CurrentTable then
			ImGui.TablePushBackgroundChannel()
		elseif window.DC.CurrentColumns then
			ImGui.PushColumnsBackground()
		end
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasClipRect)
		g.LastItemData.ClipRect = window.ClipRect
	end

	local button_flags = 0
	if btest(flags, ImGuiSelectableFlags.NoHoldingActiveID) then button_flags = bor(button_flags, ImGuiButtonFlags.NoHoldingActiveId) end
	if btest(flags, ImGuiSelectableFlags.NoSetKeyOwner) then button_flags = bor(button_flags, ImGuiButtonFlags.NoSetKeyOwner) end
	if btest(flags, ImGuiSelectableFlags.SelectOnClick) then button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnClick) end
	if btest(flags, ImGuiSelectableFlags.SelectOnRelease) then button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnRelease) end
	if btest(flags, ImGuiSelectableFlags.AllowDoubleClick) then button_flags = bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnDoubleClick) end
	if btest(flags, ImGuiSelectableFlags.AllowOverlap) or btest(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowOverlap) then button_flags = bor(button_flags, ImGuiButtonFlags.AllowOverlap) end

	local was_selected = selected
	if is_multi_select then
		selected, button_flags = ImGui.MultiSelectItemHeader(id, selected, button_flags)
	end

	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, button_flags)
	local auto_selected = false

	if is_multi_select then
		selected, pressed = ImGui.MultiSelectItemFooter(id, selected, pressed)
	else
		if btest(flags, ImGuiSelectableFlags.SelectOnNav) and g.NavJustMovedToId ~= 0 and g.NavJustMovedToFocusScopeId == g.CurrentFocusScopeId and not g.NavJustMovedToIsInit then
			if g.NavJustMovedToId == id and band(g.NavJustMovedToKeyMods, ImGuiMod.Ctrl) == 0 then
				selected = true
				pressed = true
				auto_selected = true
			end
		end
	end

	if pressed or (hovered and btest(flags, ImGuiSelectableFlags.SetNavIdOnHover)) then
		if not g.NavHighlightItemUnderNav and g.NavWindow == window and g.NavLayer == window.DC.NavLayerCurrent then
			ImGui.SetNavID(id, window.DC.NavLayerCurrent, g.CurrentFocusScopeId, ImGui.WindowRectAbsToRel(window, bb))
			if g.IO.ConfigNavCursorVisibleAuto then
				g.NavCursorVisible = false
			end
		end
	end
	if pressed then
		ImGui.MarkItemEdited(id)
	end

	if selected ~= was_selected then
		g.LastItemData.StatusFlags = bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledSelection)
	end
	if g.ActiveId == id and g.ActiveIdIsJustActivated then
		g.ActiveIdWasSelected = was_selected
		g.ActiveIdWasSoleSelected = was_selected and (not is_multi_select or g.CurrentMultiSelect.IsSoleOrUnknownSelectionSize)
	end

	if is_visible then
		local highlighted = hovered or btest(flags, ImGuiSelectableFlags.Highlight)
		if highlighted or selected then
			local col = ImGui.GetColorU32(if (held and highlighted) then ImGuiCol.HeaderActive elseif highlighted then ImGuiCol.HeaderHovered else ImGuiCol.Header)
			ImGui.RenderFrame(bb.Min, bb.Max, col, false, style.SelectableRounding)
		end
		if g.NavId == id then
			local nav_render_cursor_flags = ImGuiNavRenderCursorFlags.Compact
			if is_multi_select then
				nav_render_cursor_flags = bor(nav_render_cursor_flags, ImGuiNavRenderCursorFlags.AlwaysDraw)
			end
			ImGui.RenderNavCursor(bb, id, nav_render_cursor_flags, style.SelectableRounding)
		end
	end

	if span_all_columns then
		if g.CurrentTable then
			ImGui.TablePopBackgroundChannel()
		elseif window.DC.CurrentColumns then
			ImGui.PopColumnsBackground()
		end
	end

	if is_visible then
		ImGui.RenderTextClipped(pos, ImVec2(ImMin(pos.x + size.x, window.WorkRect.Max.x), pos.y + size.y), label, label_end, label_size, style.SelectableTextAlign, bb)
	end

	if pressed and not auto_selected and btest(window.Flags, ImGuiWindowFlags.Popup) and not btest(flags, ImGuiSelectableFlags.NoAutoClosePopups) and btest(g.LastItemData.ItemFlags, ImGuiItemFlags.AutoClosePopups) then
		ImGui.CloseCurrentPopup()
	end

	if disabled_item and not disabled_global then
		ImGui.EndDisabled()
	end

	if pressed then
		return true, not selected_in
	end
	return false, selected_in
end

return true
