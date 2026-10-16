--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImClamp = Base.ImClamp
local FLT_MAX, FLT_MIN, IM_PI = Base.FLT_MAX, Base.FLT_MIN, Base.IM_PI
local IM_COL32 = Base.IM_COL32
local ImGuiDataType = Enums.ImGuiDataType
local ImGuiSliderFlags = Enums.ImGuiSliderFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiAxis = Enums.ImGuiAxis
local ImGuiKey = Enums.ImGuiKey
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiNextItemDataFlags = Enums.ImGuiNextItemDataFlags
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiDir = Enums.ImGuiDir
local ImGuiCol = Enums.ImGuiCol
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags

local btest, band, bor, bnot, lshift = bit32.btest, bit32.band, bit32.bor, bit32.bnot, bit32.lshift

local DRAG_MOUSE_THRESHOLD_FACTOR = 0.50

local IM_S8_MIN, IM_S8_MAX = -128, 127
local IM_U8_MIN, IM_U8_MAX = 0, 0xFF
local IM_S16_MIN, IM_S16_MAX = -32768, 32767
local IM_U16_MIN, IM_U16_MAX = 0, 0xFFFF
local IM_S32_MIN, IM_S32_MAX = -2147483648, 2147483647
local IM_U32_MIN, IM_U32_MAX = 0, 0xFFFFFFFF
local IM_S64_MIN, IM_S64_MAX = -2 ^ 63, 2 ^ 63 - 1
local IM_U64_MIN, IM_U64_MAX = 0, 2 ^ 64 - 1
local INT_MIN, INT_MAX = IM_S32_MIN, IM_S32_MAX
local DBL_MAX = 1.7976931348623157e308

local CHAR_PLUS, CHAR_MINUS, CHAR_PERCENT = 43, 45, 37

local DT_S8, DT_U8, DT_S16, DT_U16 = ImGuiDataType.S8, ImGuiDataType.U8, ImGuiDataType.S16, ImGuiDataType.U16
local DT_S32, DT_U32, DT_S64, DT_U64 = ImGuiDataType.S32, ImGuiDataType.U32, ImGuiDataType.S64, ImGuiDataType.U64
local DT_Float, DT_Double = ImGuiDataType.Float, ImGuiDataType.Double

local IntTypeRange = {
	[DT_S8] = { IM_S8_MIN, IM_S8_MAX },
	[DT_U8] = { IM_U8_MIN, IM_U8_MAX },
	[DT_S16] = { IM_S16_MIN, IM_S16_MAX },
	[DT_U16] = { IM_U16_MIN, IM_U16_MAX },
	[DT_S32] = { IM_S32_MIN, IM_S32_MAX },
	[DT_U32] = { IM_U32_MIN, IM_U32_MAX },
	[DT_S64] = { IM_S64_MIN, IM_S64_MAX },
	[DT_U64] = { IM_U64_MIN, IM_U64_MAX },
}

local IntTypeWrap = {
	[DT_S8] = { 8, true },
	[DT_U8] = { 8, false },
	[DT_S16] = { 16, true },
	[DT_U16] = { 16, false },
	[DT_S32] = { 32, true },
	[DT_U32] = { 32, false },
}

local GDefaultRgbaColorMarkers = {
	IM_COL32(240, 20, 20, 255), IM_COL32(20, 240, 20, 255), IM_COL32(20, 20, 240, 255), IM_COL32(140, 140, 140, 255),
}

local GDataTypeInfo = {
	{ Size = 1, Name = "S8", PrintFmt = "%d", ScanFmt = "%d" },
	{ Size = 1, Name = "U8", PrintFmt = "%u", ScanFmt = "%u" },
	{ Size = 2, Name = "S16", PrintFmt = "%d", ScanFmt = "%d" },
	{ Size = 2, Name = "U16", PrintFmt = "%u", ScanFmt = "%u" },
	{ Size = 4, Name = "S32", PrintFmt = "%d", ScanFmt = "%d" },
	{ Size = 4, Name = "U32", PrintFmt = "%u", ScanFmt = "%u" },
	{ Size = 8, Name = "S64", PrintFmt = "%lld", ScanFmt = "%lld" },
	{ Size = 8, Name = "U64", PrintFmt = "%llu", ScanFmt = "%llu" },
	{ Size = 4, Name = "float", PrintFmt = "%.3f", ScanFmt = "%f" },
	{ Size = 8, Name = "double", PrintFmt = "%f", ScanFmt = "%lf" },
	{ Size = 1, Name = "bool", PrintFmt = "%d", ScanFmt = "%d" },
	{ Size = 0, Name = "char*", PrintFmt = "%s", ScanFmt = "%s" },
}
assert(#GDataTypeInfo == ImGuiDataType.COUNT)

local function Trunc(x)
	if x >= 0 then
		return math.floor(x)
	end
	return math.ceil(x)
end

local function WrapInt(x, bits, signed)
	local m = 2 ^ bits
	x = x % m
	if signed and x >= m / 2 then
		x -= m
	end
	return x
end

local function IsFloatType(data_type)
	return data_type == DT_Float or data_type == DT_Double
end

local function CastToType(data_type, x)
	if IsFloatType(data_type) then
		return x
	end
	x = Trunc(x)
	local w = IntTypeWrap[data_type]
	if w then
		return WrapInt(x, w[1], w[2])
	end
	return x
end

local function CastToSigned(data_type, x)
	if IsFloatType(data_type) then
		return x
	end
	x = Trunc(x)
	if data_type == DT_S32 or data_type == DT_U32 then
		return WrapInt(x, 32, true)
	end
	return x
end

local function AxisComponent(v, axis)
	if axis == ImGuiAxis.X then
		return v.x
	end
	return v.y
end

local function TrimBlanks(s)
	return string.match(s, "^[ \t]*(.-)[ \t]*$")
end

function ImGui.DataTypeGetInfo(data_type)
	assert(data_type >= 0 and data_type < ImGuiDataType.COUNT)
	return GDataTypeInfo[data_type + 1]
end

function ImGui.DataTypeFormatString(data_type, p_data, format)
	if data_type >= DT_S8 and data_type <= DT_Double then
		return Base.ImFormatString(format, p_data)
	end
	assert(false)
	return ""
end

function ImGui.DataTypeApplyOp(data_type, op, output, arg1, arg2)
	if type(op) == "string" then
		op = string.byte(op)
	end
	assert(op == CHAR_PLUS or op == CHAR_MINUS)
	local range = IntTypeRange[data_type]
	if range then
		if op == CHAR_PLUS then
			output = Base.ImAddClampOverflow(arg1, arg2, range[1], range[2])
		end
		if op == CHAR_MINUS then
			output = Base.ImSubClampOverflow(arg1, arg2, range[1], range[2])
		end
		return output
	elseif IsFloatType(data_type) then
		if op == CHAR_PLUS then
			output = arg1 + arg2
		end
		if op == CHAR_MINUS then
			output = arg1 - arg2
		end
		return output
	end
	assert(false)
	return output
end

function ImGui.DataTypeApplyFromText(buf, data_type, p_data, format, p_data_when_empty)
	local type_info = ImGui.DataTypeGetInfo(data_type)
	local data_backup = p_data

	local i = 1
	while true do
		local c = string.byte(buf, i)
		if c ~= 32 and c ~= 9 then
			break
		end
		i += 1
	end
	if i > #buf then
		if p_data_when_empty ~= nil then
			p_data = p_data_when_empty
			return data_backup ~= p_data, p_data
		end
		return false, p_data
	end

	if IsFloatType(data_type) then
		format = type_info.ScanFmt
	else
		format = Base.ImParseFormatSanitizeForScanning(format)
		if format == "" then
			format = type_info.ScanFmt
		end
	end

	local v = Base.ImSscanf(string.sub(buf, i), format)
	if type(v) ~= "number" then
		return false, p_data
	end
	if type_info.Size < 4 then
		local v32 = WrapInt(Trunc(v), 32, true)
		local range = IntTypeRange[data_type]
		if range and data_type <= DT_U16 then
			p_data = ImClamp(v32, range[1], range[2])
		else
			assert(false)
		end
	else
		p_data = CastToType(data_type, v)
	end

	return data_backup ~= p_data, p_data
end

function ImGui.DataTypeCompare(data_type, arg_1, arg_2)
	if data_type >= DT_S8 and data_type <= DT_Double then
		if arg_1 < arg_2 then
			return -1
		end
		if arg_1 > arg_2 then
			return 1
		end
		return 0
	end
	assert(false)
	return 0
end

function ImGui.DataTypeClamp(data_type, p_data, p_min, p_max)
	if data_type >= DT_S8 and data_type <= DT_Double then
		if p_min ~= nil and p_data < p_min then
			return true, p_min
		end
		if p_max ~= nil and p_data > p_max then
			return true, p_max
		end
		return false, p_data
	end
	assert(false)
	return false, p_data
end

function ImGui.DataTypeIsZero(data_type, p_data)
	local g = ImGui.GImGui
	return ImGui.DataTypeCompare(data_type, p_data, g.DataTypeZeroValue) == 0
end

local min_steps = { 1.0, 0.1, 0.01, 0.001, 0.0001, 0.00001, 0.000001, 0.0000001, 0.00000001, 0.000000001 }

function ImGui.GetMinimumStepAtDecimalPrecision(decimal_precision)
	if decimal_precision < 0 then
		return FLT_MIN
	end
	if decimal_precision < #min_steps then
		return min_steps[decimal_precision + 1]
	end
	return 10.0 ^ -decimal_precision
end

function ImGui.RoundScalarWithFormatT(format, data_type, v)
	assert(data_type == DT_Float or data_type == DT_Double)
	local fmt_start = Base.ImParseFormatFindStart(format)
	if string.byte(format, fmt_start) ~= CHAR_PERCENT or string.byte(format, fmt_start + 1) == CHAR_PERCENT then
		return v
	end

	local fmt_sanitized = Base.ImParseFormatSanitizeForPrinting(string.sub(format, fmt_start))

	local v_str = Base.ImFormatString(fmt_sanitized, v)
	local p = 1
	while string.byte(v_str, p) == 32 do
		p += 1
	end
	v = Base.ImAtof(string.sub(v_str, p))

	return v
end

function ImGui.DragBehaviorT(data_type, v, v_speed, v_min, v_max, format, flags)
	local g = ImGui.GImGui
	local axis = btest(flags, ImGuiSliderFlags.Vertical) and ImGuiAxis.Y or ImGuiAxis.X
	local is_bounded = (v_min < v_max) or ((v_min == v_max) and (v_min ~= 0 or btest(flags, ImGuiSliderFlags.ClampZeroRange)))
	local is_wrapped = is_bounded and btest(flags, ImGuiSliderFlags.WrapAround)
	local is_logarithmic = btest(flags, ImGuiSliderFlags.Logarithmic)
	local is_floating_point = IsFloatType(data_type)
	local v_range = CastToType(data_type, v_max - v_min)

	if v_speed == 0 and is_bounded and (v_range < FLT_MAX) then
		v_speed = v_range * g.DragSpeedDefaultRatio
	end

	local adjust_delta = 0.0
	if g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMousePosValid() and ImGui.IsMouseDragPastThreshold(0, g.IO.MouseDragThreshold * DRAG_MOUSE_THRESHOLD_FACTOR) then
		adjust_delta = AxisComponent(g.IO.MouseDelta, axis)
		if g.IO.KeyAlt and not btest(flags, ImGuiSliderFlags.NoSpeedTweaks) then
			adjust_delta *= 1.0 / 100.0
		end
		if g.IO.KeyShift and not btest(flags, ImGuiSliderFlags.NoSpeedTweaks) then
			adjust_delta *= 10.0
		end
	elseif g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
		local decimal_precision = is_floating_point and Base.ImParseFormatPrecision(format, 3) or 0
		local tweak_slow = ImGui.IsKeyDown((g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakSlow or ImGuiKey.NavKeyboardTweakSlow)
		local tweak_fast = ImGui.IsKeyDown((g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakFast or ImGuiKey.NavKeyboardTweakFast)
		local tweak_factor
		if btest(flags, ImGuiSliderFlags.NoSpeedTweaks) then
			tweak_factor = 1.0
		elseif tweak_slow then
			tweak_factor = 1.0 / 10.0
		elseif tweak_fast then
			tweak_factor = 10.0
		else
			tweak_factor = 1.0
		end
		adjust_delta = ImGui.GetNavTweakPressedAmount(axis) * tweak_factor
		v_speed = math.max(v_speed, ImGui.GetMinimumStepAtDecimalPrecision(decimal_precision))
	end
	adjust_delta *= v_speed

	if axis == ImGuiAxis.Y then
		adjust_delta = -adjust_delta
	end

	if is_logarithmic and (v_range < FLT_MAX) and (v_range > 0.000001) then
		adjust_delta /= v_range
	end

	local is_just_activated = g.ActiveIdIsJustActivated
	local is_already_past_limits_and_pushing_outward = is_bounded and not is_wrapped and ((v >= v_max and adjust_delta > 0.0) or (v <= v_min and adjust_delta < 0.0))
	if is_just_activated or is_already_past_limits_and_pushing_outward then
		g.DragCurrentAccum = 0.0
		g.DragCurrentAccumDirty = false
	elseif adjust_delta ~= 0.0 then
		g.DragCurrentAccum += adjust_delta
		g.DragCurrentAccumDirty = true
	end

	if not g.DragCurrentAccumDirty then
		return false, v
	end

	local v_cur = v
	local v_old_ref_for_accum_remainder = 0.0

	local logarithmic_zero_epsilon = 0.0
	local zero_deadzone_halfsize = 0.0
	if is_logarithmic then
		local decimal_precision = is_floating_point and Base.ImParseFormatPrecision(format, 3) or 1
		logarithmic_zero_epsilon = 0.1 ^ decimal_precision

		local v_old_parametric = ImGui.ScaleRatioFromValueT(data_type, v_cur, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
		local v_new_parametric = v_old_parametric + g.DragCurrentAccum
		v_cur = ImGui.ScaleValueFromRatioT(data_type, v_new_parametric, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
		v_old_ref_for_accum_remainder = v_old_parametric
	else
		v_cur = CastToType(data_type, v_cur + CastToSigned(data_type, g.DragCurrentAccum))
	end

	if is_floating_point and not btest(flags, ImGuiSliderFlags.NoRoundToFormat) then
		v_cur = ImGui.RoundScalarWithFormatT(format, data_type, v_cur)
	end

	g.DragCurrentAccumDirty = false
	if is_logarithmic then
		local v_new_parametric = ImGui.ScaleRatioFromValueT(data_type, v_cur, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
		g.DragCurrentAccum -= v_new_parametric - v_old_ref_for_accum_remainder
	else
		g.DragCurrentAccum -= CastToSigned(data_type, CastToSigned(data_type, v_cur) - CastToSigned(data_type, v))
	end

	if v_cur == 0 then
		v_cur = 0
	end

	if v ~= v_cur and is_bounded then
		if is_wrapped then
			local wrap_range = v_max - v_min + (is_floating_point and 0 or 1)
			if v_cur < v_min then
				v_cur = CastToType(data_type, v_cur + wrap_range)
			end
			if v_cur > v_max then
				v_cur = CastToType(data_type, v_cur - wrap_range)
			end
		else
			if v_cur < v_min or (v_cur > v and adjust_delta < 0.0 and not is_floating_point) then
				v_cur = v_min
			end
			if v_cur > v_max or (v_cur < v and adjust_delta > 0.0 and not is_floating_point) then
				v_cur = v_max
			end
		end
	end

	if v == v_cur then
		return false, v
	end
	return true, v_cur
end

function ImGui.ShortcutsForCancel(id)
	local g = ImGui.GImGui
	local is_cancel_with_keyboard = ImGui.Shortcut(ImGuiKey.Escape, ImGuiInputFlags.None, id)
	local nav_gamepad_cancel = g.IO.ConfigNavSwapGamepadButtons and ImGuiKey.GamepadFaceDown or ImGuiKey.GamepadFaceRight
	local is_cancel_with_gamepad = btest(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) and btest(g.IO.BackendFlags, ImGuiBackendFlags.HasGamepad) and ImGui.Shortcut(nav_gamepad_cancel, ImGuiInputFlags.None, id)
	local is_cancel_with_mouse = ImGui.IsMouseReleased(ImGuiMouseButton.Right, id)
	if is_cancel_with_mouse then
		ImGui.SetKeyOwner(ImGuiKey.MouseRight, id)
	end
	return is_cancel_with_keyboard or is_cancel_with_gamepad or is_cancel_with_mouse
end

local function BehaviorCancelRevert(g, p_v)
	local value_changed = p_v ~= g.ActiveIdValueOnActivation
	p_v = g.ActiveIdValueOnActivation
	ImGui.ClearActiveID()
	return value_changed, p_v
end

function ImGui.DragBehavior(id, data_type, p_v, v_speed, p_min, p_max, format, flags)
	assert((flags == 1 or band(flags, ImGuiSliderFlags.InvalidMask_) == 0), "Invalid ImGuiSliderFlags flags! Has the legacy 'float power' argument been mistakenly cast to flags? Call function with ImGuiSliderFlags_Logarithmic flags instead.")

	local g = ImGui.GImGui
	if g.ActiveId == id then
		if g.ActiveIdSource == ImGuiInputSource.Mouse and not g.IO.MouseDown[1] then
			ImGui.ClearActiveID()
		elseif (g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad) and g.NavActivatePressedId == id and not g.ActiveIdIsJustActivated then
			ImGui.ClearActiveID()
		end
		if ImGui.ShortcutsForCancel(id) and g.ActiveId == id then
			return BehaviorCancelRevert(g, p_v)
		end
	end
	if g.ActiveId ~= id then
		return false, p_v
	end
	if g.IO.ConfigDragHideCursor and g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMouseDragPastThreshold(0, g.IO.MouseDragThreshold * DRAG_MOUSE_THRESHOLD_FACTOR) then
		g.IO.MouseLockFrame = g.FrameCount
	end
	if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) or btest(flags, ImGuiSliderFlags.ReadOnly) then
		return false, p_v
	end

	local range = IntTypeRange[data_type]
	if data_type == DT_S8 or data_type == DT_S16 then
		local r, v32 = ImGui.DragBehaviorT(DT_S32, p_v, v_speed, p_min or range[1], p_max or range[2], format, flags)
		if r then
			p_v = CastToType(data_type, v32)
		end
		return r, p_v
	elseif data_type == DT_U8 or data_type == DT_U16 then
		local r, v32 = ImGui.DragBehaviorT(DT_U32, p_v, v_speed, p_min or range[1], p_max or range[2], format, flags)
		if r then
			p_v = CastToType(data_type, v32)
		end
		return r, p_v
	elseif range then
		return ImGui.DragBehaviorT(data_type, p_v, v_speed, p_min or range[1], p_max or range[2], format, flags)
	elseif data_type == DT_Float then
		return ImGui.DragBehaviorT(data_type, p_v, v_speed, p_min or -FLT_MAX, p_max or FLT_MAX, format, flags)
	elseif data_type == DT_Double then
		return ImGui.DragBehaviorT(data_type, p_v, v_speed, p_min or -DBL_MAX, p_max or DBL_MAX, format, flags)
	end
	assert(false)
	return false, p_v
end

function ImGui.TempInputIsClampEnabled(flags, data_type, p_min, p_max)
	if btest(flags, ImGuiSliderFlags.ClampOnInput) and (p_min ~= nil or p_max ~= nil) then
		local clamp_range_dir = (p_min ~= nil and p_max ~= nil) and ImGui.DataTypeCompare(data_type, p_min, p_max) or 0
		if p_min == nil or p_max == nil or clamp_range_dir < 0 then
			return true
		end
		if clamp_range_dir == 0 then
			if ImGui.DataTypeIsZero(data_type, p_min) then
				return btest(flags, ImGuiSliderFlags.ClampZeroRange)
			end
			return true
		end
	end
	return false
end

local function RenderScalarValueText(g, data_type, p_data, format, pos_min, pos_max, align, log_decoration)
	local is_mixed = btest(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue)
	local value_buf = ImGui.DataTypeFormatString(data_type, p_data, (is_mixed and g.MixedValueLabel ~= nil) and g.MixedValueLabel or format)
	if log_decoration and g.LogEnabled then
		ImGui.LogSetNextTextDecoration("{", "}")
	end
	if is_mixed then
		ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextMixedValue + 1])
	end
	ImGui.RenderTextClipped(pos_min, pos_max, value_buf, nil, nil, align)
	if is_mixed then
		ImGui.PopStyleColor()
	end
end

function ImGui.DragScalar(label, data_type, p_data, v_speed, p_min, p_max, format, flags)
	if v_speed == nil then v_speed = 1.0 end
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, p_data
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)
	local w = ImGui.CalcItemWidth()
	local color_marker = btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasColorMarker) and g.NextItemData.ColorMarker or 0

	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local frame_bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + ImVec2(w, label_size.y + style.FramePadding.y * 2.0))
	local total_bb = ImRect.new(frame_bb.Min, frame_bb.Max + ImVec2(label_size.x > 0.0 and style.ItemInnerSpacing.x + label_size.x or 0.0, 0.0))

	local temp_input_allowed = not btest(flags, ImGuiSliderFlags.NoInput)
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(total_bb, id, frame_bb, temp_input_allowed and ImGuiItemFlags.Inputable or 0) then
		return false, p_data
	end

	if format == nil then
		format = ImGui.DataTypeGetInfo(data_type).PrintFmt
	end

	local hovered = ImGui.ItemHoverable(frame_bb, id, g.LastItemData.ItemFlags)
	local temp_input_is_active = temp_input_allowed and ImGui.TempInputIsActive(id)
	if not temp_input_is_active then
		local clicked = hovered and ImGui.IsMouseClicked(0, ImGuiInputFlags.None, id)
		local double_clicked = hovered and g.IO.MouseClickedCount[1] == 2 and ImGui.TestKeyOwner(ImGuiKey.MouseLeft, id)
		local make_active = clicked or double_clicked or g.NavActivateId == id
		if make_active and (clicked or double_clicked) then
			ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
		end
		if make_active and temp_input_allowed then
			if (clicked and g.IO.KeyCtrl) or double_clicked or (g.NavActivateId == id and btest(g.NavActivateFlags, ImGuiActivateFlags.PreferInput)) then
				temp_input_is_active = true
			end
		end

		if g.IO.ConfigDragClickToInputText and temp_input_allowed and not temp_input_is_active then
			if g.ActiveId == id and hovered and g.IO.MouseReleased[1] and not ImGui.IsMouseDragPastThreshold(0, g.IO.MouseDragThreshold * DRAG_MOUSE_THRESHOLD_FACTOR) then
				g.NavActivateId = id
				g.NavActivateFlags = ImGuiActivateFlags.PreferInput
				temp_input_is_active = true
			end
		end

		if make_active then
			g.ActiveIdValueOnActivation = p_data
		end

		if make_active and not temp_input_is_active then
			ImGui.SetActiveID(id, window)
			ImGui.SetFocusID(id, window)
			ImGui.FocusWindow(window)
			g.ActiveIdUsingNavDirMask = bor(lshift(1, ImGuiDir.Left), lshift(1, ImGuiDir.Right))
		end
	end

	if temp_input_is_active then
		local clamp_enabled = ImGui.TempInputIsClampEnabled(flags, data_type, p_min, p_max)
		return ImGui.TempInputScalar(frame_bb, id, label, data_type, p_data, format, clamp_enabled and p_min or nil, clamp_enabled and p_max or nil)
	end

	local frame_col = ImGui.GetColorU32(g.ActiveId == id and ImGuiCol.FrameBgActive or (hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg))
	ImGui.RenderNavCursor(frame_bb, id)
	ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, frame_col, false, style.FrameRounding)
	if color_marker ~= 0 and style.ColorMarkerSize > 0.0 then
		ImGui.RenderColorComponentMarker(frame_bb, ImGui.GetColorU32_U32(color_marker), style.FrameRounding)
	end
	ImGui.RenderFrameBorder(frame_bb.Min, frame_bb.Max, g.Style.FrameRounding)

	local value_changed
	value_changed, p_data = ImGui.DragBehavior(id, data_type, p_data, v_speed, p_min, p_max, format, flags)
	if value_changed then
		ImGui.MarkItemEdited(id)
	end

	RenderScalarValueText(g, data_type, p_data, format, frame_bb.Min, frame_bb.Max, ImVec2(0.5, 0.5), true)

	if label_size.x > 0.0 then
		ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y), label, label_end, false)
	end

	return value_changed, p_data
end

function ImGui.DragScalarN(label, data_type, p_data, components, v_speed, p_min, p_max, format, flags)
	if v_speed == nil then v_speed = 1.0 end
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local value_changed = false
	ImGui.BeginGroup()
	ImGui.PushID(label)
	ImGui.PushMultiItemsWidths(components, ImGui.CalcItemWidth())
	for i = 0, components - 1 do
		ImGui.PushID(i)
		if i > 0 then
			ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
		end
		if btest(flags, ImGuiSliderFlags.ColorMarkers) then
			ImGui.SetNextItemColorMarker(GDefaultRgbaColorMarkers[i + 1])
		end
		local changed
		changed, p_data[i + 1] = ImGui.DragScalar("", data_type, p_data[i + 1], v_speed, p_min, p_max, format, flags)
		value_changed = value_changed or changed
		ImGui.PopID()
		ImGui.PopItemWidth()
	end
	ImGui.PopID()

	local label_end = ImGui.FindRenderedTextEnd(label)
	if label_end ~= 1 then
		ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
		ImGui.TextEx(label, label_end)
	end

	ImGui.EndGroup()
	return value_changed
end

function ImGui.DragFloat(label, v, v_speed, v_min, v_max, format, flags)
	if v_speed == nil then v_speed = 1.0 end
	if v_min == nil then v_min = 0.0 end
	if v_max == nil then v_max = 0.0 end
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.DragScalar(label, DT_Float, v, v_speed, v_min, v_max, format, flags)
end

local function DragFloatN(label, v, components, v_speed, v_min, v_max, format, flags)
	if v_speed == nil then v_speed = 1.0 end
	if v_min == nil then v_min = 0.0 end
	if v_max == nil then v_max = 0.0 end
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.DragScalarN(label, DT_Float, v, components, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragFloat2(label, v, v_speed, v_min, v_max, format, flags)
	return DragFloatN(label, v, 2, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragFloat3(label, v, v_speed, v_min, v_max, format, flags)
	return DragFloatN(label, v, 3, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragFloat4(label, v, v_speed, v_min, v_max, format, flags)
	return DragFloatN(label, v, 4, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragFloatRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
	if v_speed == nil then v_speed = 1.0 end
	if v_min == nil then v_min = 0.0 end
	if v_max == nil then v_max = 0.0 end
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, v_current_min, v_current_max
	end

	local g = ImGui.GImGui
	ImGui.PushID(label)
	ImGui.BeginGroup()
	ImGui.PushMultiItemsWidths(2, ImGui.CalcItemWidth())

	local min_min = (v_min >= v_max) and -FLT_MAX or v_min
	local min_max = (v_min >= v_max) and v_current_max or math.min(v_max, v_current_max)
	local min_flags = bor(flags, (min_min == min_max) and ImGuiSliderFlags.ReadOnly or 0)
	local value_changed
	value_changed, v_current_min = ImGui.DragScalar("##min", DT_Float, v_current_min, v_speed, min_min, min_max, format, min_flags)
	ImGui.PopItemWidth()
	ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)

	local max_min = (v_min >= v_max) and v_current_min or math.max(v_min, v_current_min)
	local max_max = (v_min >= v_max) and FLT_MAX or v_max
	local max_flags = bor(flags, (max_min == max_max) and ImGuiSliderFlags.ReadOnly or 0)
	local changed
	changed, v_current_max = ImGui.DragScalar("##max", DT_Float, v_current_max, v_speed, max_min, max_max, format_max or format, max_flags)
	value_changed = value_changed or changed
	ImGui.PopItemWidth()
	ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)

	ImGui.TextEx(label, ImGui.FindRenderedTextEnd(label))
	ImGui.EndGroup()
	ImGui.PopID()

	return value_changed, v_current_min, v_current_max
end

function ImGui.DragInt(label, v, v_speed, v_min, v_max, format, flags)
	if v_speed == nil then v_speed = 1.0 end
	if v_min == nil then v_min = 0 end
	if v_max == nil then v_max = 0 end
	if format == nil then format = "%d" end
	if flags == nil then flags = 0 end
	return ImGui.DragScalar(label, DT_S32, v, v_speed, v_min, v_max, format, flags)
end

local function DragIntN(label, v, components, v_speed, v_min, v_max, format, flags)
	if v_speed == nil then v_speed = 1.0 end
	if v_min == nil then v_min = 0 end
	if v_max == nil then v_max = 0 end
	if format == nil then format = "%d" end
	if flags == nil then flags = 0 end
	return ImGui.DragScalarN(label, DT_S32, v, components, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragInt2(label, v, v_speed, v_min, v_max, format, flags)
	return DragIntN(label, v, 2, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragInt3(label, v, v_speed, v_min, v_max, format, flags)
	return DragIntN(label, v, 3, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragInt4(label, v, v_speed, v_min, v_max, format, flags)
	return DragIntN(label, v, 4, v_speed, v_min, v_max, format, flags)
end

function ImGui.DragIntRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
	if v_speed == nil then v_speed = 1.0 end
	if v_min == nil then v_min = 0 end
	if v_max == nil then v_max = 0 end
	if format == nil then format = "%d" end
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, v_current_min, v_current_max
	end

	local g = ImGui.GImGui
	ImGui.PushID(label)
	ImGui.BeginGroup()
	ImGui.PushMultiItemsWidths(2, ImGui.CalcItemWidth())

	local min_min = (v_min >= v_max) and INT_MIN or v_min
	local min_max = (v_min >= v_max) and v_current_max or math.min(v_max, v_current_max)
	local min_flags = bor(flags, (min_min == min_max) and ImGuiSliderFlags.ReadOnly or 0)
	local value_changed
	value_changed, v_current_min = ImGui.DragInt("##min", v_current_min, v_speed, min_min, min_max, format, min_flags)
	ImGui.PopItemWidth()
	ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)

	local max_min = (v_min >= v_max) and v_current_min or math.max(v_min, v_current_min)
	local max_max = (v_min >= v_max) and INT_MAX or v_max
	local max_flags = bor(flags, (max_min == max_max) and ImGuiSliderFlags.ReadOnly or 0)
	local changed
	changed, v_current_max = ImGui.DragInt("##max", v_current_max, v_speed, max_min, max_max, format_max or format, max_flags)
	value_changed = value_changed or changed
	ImGui.PopItemWidth()
	ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)

	ImGui.TextEx(label, ImGui.FindRenderedTextEnd(label))
	ImGui.EndGroup()
	ImGui.PopID()

	return value_changed, v_current_min, v_current_max
end

local function LogFudge(v, logarithmic_zero_epsilon)
	if math.abs(v) < logarithmic_zero_epsilon then
		return (v < 0.0) and -logarithmic_zero_epsilon or logarithmic_zero_epsilon
	end
	return v
end

function ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
	if v_min == v_max then
		return 0.0
	end

	local v_clamped = (v_min < v_max) and ImClamp(v, v_min, v_max) or ImClamp(v, v_max, v_min)
	if logarithmic_zero_epsilon > 0.0 then
		local flipped = v_max < v_min

		if flipped then
			v_min, v_max = v_max, v_min
		end

		local v_min_fudged = LogFudge(v_min, logarithmic_zero_epsilon)
		local v_max_fudged = LogFudge(v_max, logarithmic_zero_epsilon)

		if (v_min == 0.0) and (v_max < 0.0) then
			v_min_fudged = -logarithmic_zero_epsilon
		elseif (v_max == 0.0) and (v_min < 0.0) then
			v_max_fudged = -logarithmic_zero_epsilon
		end

		local result
		if v_clamped <= v_min_fudged then
			result = 0.0
		elseif v_clamped >= v_max_fudged then
			result = 1.0
		elseif (v_min * v_max) < 0.0 then
			local zero_point_center = (-v_min) / (v_max - v_min)
			local zero_point_snap_L = zero_point_center - zero_deadzone_halfsize
			local zero_point_snap_R = zero_point_center + zero_deadzone_halfsize
			if v == 0.0 then
				result = zero_point_center
			elseif v < 0.0 then
				result = (1.0 - (math.log(-v_clamped / logarithmic_zero_epsilon) / math.log(-v_min_fudged / logarithmic_zero_epsilon))) * zero_point_snap_L
			else
				result = zero_point_snap_R + ((math.log(v_clamped / logarithmic_zero_epsilon) / math.log(v_max_fudged / logarithmic_zero_epsilon)) * (1.0 - zero_point_snap_R))
			end
		elseif (v_min < 0.0) or (v_max < 0.0) then
			result = 1.0 - (math.log(-v_clamped / -v_max_fudged) / math.log(-v_min_fudged / -v_max_fudged))
		else
			result = math.log(v_clamped / v_min_fudged) / math.log(v_max_fudged / v_min_fudged)
		end

		if flipped then
			return 1.0 - result
		end
		return result
	else
		return CastToSigned(data_type, v_clamped - v_min) / CastToSigned(data_type, v_max - v_min)
	end
end

function ImGui.ScaleValueFromRatioT(data_type, t, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
	if t <= 0.0 or v_min == v_max then
		return v_min
	end
	if t >= 1.0 then
		return v_max
	end

	local result = 0
	if logarithmic_zero_epsilon > 0.0 then
		local v_min_fudged = LogFudge(v_min, logarithmic_zero_epsilon)
		local v_max_fudged = LogFudge(v_max, logarithmic_zero_epsilon)

		local flipped = v_max < v_min
		if flipped then
			v_min_fudged, v_max_fudged = v_max_fudged, v_min_fudged
		end

		if (v_max == 0.0) and (v_min < 0.0) then
			v_max_fudged = -logarithmic_zero_epsilon
		end

		local t_with_flip = flipped and (1.0 - t) or t

		if (v_min * v_max) < 0.0 then
			local zero_point_center = (-math.min(v_min, v_max)) / math.abs(v_max - v_min)
			local zero_point_snap_L = zero_point_center - zero_deadzone_halfsize
			local zero_point_snap_R = zero_point_center + zero_deadzone_halfsize
			if t_with_flip >= zero_point_snap_L and t_with_flip <= zero_point_snap_R then
				result = 0
			elseif t_with_flip < zero_point_center then
				result = CastToType(data_type, -(logarithmic_zero_epsilon * (-v_min_fudged / logarithmic_zero_epsilon) ^ (1.0 - (t_with_flip / zero_point_snap_L))))
			else
				result = CastToType(data_type, logarithmic_zero_epsilon * (v_max_fudged / logarithmic_zero_epsilon) ^ ((t_with_flip - zero_point_snap_R) / (1.0 - zero_point_snap_R)))
			end
		elseif (v_min < 0.0) or (v_max < 0.0) then
			result = CastToType(data_type, -(-v_max_fudged * (-v_min_fudged / -v_max_fudged) ^ (1.0 - t_with_flip)))
		else
			result = CastToType(data_type, v_min_fudged * (v_max_fudged / v_min_fudged) ^ t_with_flip)
		end
	else
		if IsFloatType(data_type) then
			result = v_min + (v_max - v_min) * t
		else
			local v_new_off_f = CastToSigned(data_type, v_max - v_min) * t
			result = CastToType(data_type, CastToSigned(data_type, v_min) + CastToSigned(data_type, v_new_off_f + ((v_min > v_max) and -0.5 or 0.5)))
		end
	end

	return result
end

function ImGui.SliderBehaviorT(bb, id, data_type, v, v_min, v_max, format, flags, out_grab_bb)
	local g = ImGui.GImGui
	local style = g.Style

	local axis = btest(flags, ImGuiSliderFlags.Vertical) and ImGuiAxis.Y or ImGuiAxis.X
	local is_logarithmic = btest(flags, ImGuiSliderFlags.Logarithmic)
	local is_floating_point = IsFloatType(data_type)
	local v_range_f = CastToType(data_type, (v_min < v_max) and (v_max - v_min) or (v_min - v_max))

	local grab_padding = 2.0
	local slider_sz = (AxisComponent(bb.Max, axis) - AxisComponent(bb.Min, axis)) - grab_padding * 2.0
	local grab_sz = style.GrabMinSize
	if not is_floating_point and v_range_f >= 0.0 then
		grab_sz = math.max(slider_sz / (v_range_f + 1), style.GrabMinSize)
	end
	grab_sz = math.min(grab_sz, slider_sz)
	local slider_usable_sz = slider_sz - grab_sz
	local slider_usable_pos_min = AxisComponent(bb.Min, axis) + grab_padding + grab_sz * 0.5
	local slider_usable_pos_max = AxisComponent(bb.Max, axis) - grab_padding - grab_sz * 0.5

	local logarithmic_zero_epsilon = 0.0
	local zero_deadzone_halfsize = 0.0
	if is_logarithmic then
		local decimal_precision = is_floating_point and Base.ImParseFormatPrecision(format, 3) or 1
		logarithmic_zero_epsilon = 0.1 ^ decimal_precision
		zero_deadzone_halfsize = (style.LogSliderDeadzone * 0.5) / math.max(slider_usable_sz, 1.0)
	end

	local value_changed = false
	if g.ActiveId == id then
		local set_new_value = false
		local clicked_t = 0.0
		if g.ActiveIdSource == ImGuiInputSource.Mouse then
			local mouse_pos = AxisComponent(g.IO.MousePos, axis)
			if g.ActiveIdIsJustActivated then
				local grab_t = ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
				if axis == ImGuiAxis.Y then
					grab_t = 1.0 - grab_t
				end
				local grab_pos = slider_usable_pos_min + (slider_usable_pos_max - slider_usable_pos_min) * grab_t
				local clicked_around_grab = (mouse_pos >= grab_pos - grab_sz * 0.5 - 1.0) and (mouse_pos <= grab_pos + grab_sz * 0.5 + 1.0)
				g.SliderGrabClickOffset = (clicked_around_grab and is_floating_point) and mouse_pos - grab_pos or 0.0
			end
			if slider_usable_sz > 0.0 then
				clicked_t = Base.ImSaturate((mouse_pos - g.SliderGrabClickOffset - slider_usable_pos_min) / slider_usable_sz)
			end
			if axis == ImGuiAxis.Y then
				clicked_t = 1.0 - clicked_t
			end
			set_new_value = true
		elseif g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
			local input_delta = (axis == ImGuiAxis.X) and ImGui.GetNavTweakPressedAmount(axis) or -ImGui.GetNavTweakPressedAmount(axis)
			if input_delta ~= 0.0 then
				local tweak_slow = ImGui.IsKeyDown((g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakSlow or ImGuiKey.NavKeyboardTweakSlow)
				local tweak_fast = ImGui.IsKeyDown((g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakFast or ImGuiKey.NavKeyboardTweakFast)
				local decimal_precision = is_floating_point and Base.ImParseFormatPrecision(format, 3) or 0
				if decimal_precision > 0 then
					input_delta /= 100.0
					if tweak_slow then
						input_delta /= 10.0
					end
				else
					if (v_range_f >= -100.0 and v_range_f <= 100.0 and v_range_f ~= 0.0) or tweak_slow then
						input_delta = ((input_delta < 0.0) and -1.0 or 1.0) / v_range_f
					else
						input_delta /= 100.0
					end
				end
				if tweak_fast then
					input_delta *= 10.0
				end

				g.SliderCurrentAccum += input_delta
				g.SliderCurrentAccumDirty = true
			end

			local delta = g.SliderCurrentAccum
			if g.SliderCurrentAccumDirty then
				clicked_t = ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)

				if (clicked_t >= 1.0 and delta > 0.0) or (clicked_t <= 0.0 and delta < 0.0) then
					set_new_value = false
					g.SliderCurrentAccum = 0.0
				else
					set_new_value = true
					local old_clicked_t = clicked_t
					clicked_t = Base.ImSaturate(clicked_t + delta)

					local v_new = ImGui.ScaleValueFromRatioT(data_type, clicked_t, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
					if is_floating_point and not btest(flags, ImGuiSliderFlags.NoRoundToFormat) then
						v_new = ImGui.RoundScalarWithFormatT(format, data_type, v_new)
					end
					local new_clicked_t = ImGui.ScaleRatioFromValueT(data_type, v_new, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)

					if delta > 0 then
						g.SliderCurrentAccum -= math.min(new_clicked_t - old_clicked_t, delta)
					else
						g.SliderCurrentAccum -= math.max(new_clicked_t - old_clicked_t, delta)
					end
				end
				g.SliderCurrentAccumDirty = false
			end
		end

		if set_new_value then
			if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) or btest(flags, ImGuiSliderFlags.ReadOnly) then
				set_new_value = false
			end
		end

		if set_new_value then
			local v_new = ImGui.ScaleValueFromRatioT(data_type, clicked_t, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)

			if is_floating_point and not btest(flags, ImGuiSliderFlags.NoRoundToFormat) then
				v_new = ImGui.RoundScalarWithFormatT(format, data_type, v_new)
			end

			if v ~= v_new then
				v = v_new
				value_changed = true
			end
		end
	end

	if slider_sz < 1.0 then
		out_grab_bb = ImRect.new(bb.Min, bb.Min)
	else
		local grab_t = ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
		if axis == ImGuiAxis.Y then
			grab_t = 1.0 - grab_t
		end
		local grab_pos = slider_usable_pos_min + (slider_usable_pos_max - slider_usable_pos_min) * grab_t
		if axis == ImGuiAxis.X then
			out_grab_bb = ImRect.fromXY(grab_pos - grab_sz * 0.5, bb.Min.y + grab_padding, grab_pos + grab_sz * 0.5, bb.Max.y - grab_padding)
		else
			out_grab_bb = ImRect.fromXY(bb.Min.x + grab_padding, grab_pos - grab_sz * 0.5, bb.Max.x - grab_padding, grab_pos + grab_sz * 0.5)
		end
	end

	return value_changed, v, out_grab_bb
end

function ImGui.SliderBehavior(bb, id, data_type, p_v, p_min, p_max, format, flags, out_grab_bb)
	assert((flags == 1 or band(flags, ImGuiSliderFlags.InvalidMask_) == 0), "Invalid ImGuiSliderFlags flags! Has the legacy 'float power' argument been mistakenly cast to flags? Call function with ImGuiSliderFlags_Logarithmic flags instead.")
	assert(not btest(flags, ImGuiSliderFlags.WrapAround))

	local g = ImGui.GImGui
	if g.ActiveId == id then
		if g.ActiveIdSource == ImGuiInputSource.Mouse and not g.IO.MouseDown[1] then
			ImGui.ClearActiveID()
		end
		if g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
			if g.ActiveIdIsJustActivated then
				g.SliderCurrentAccum = 0.0
				g.SliderCurrentAccumDirty = false
			end
			if g.NavActivatePressedId == id and not g.ActiveIdIsJustActivated then
				ImGui.ClearActiveID()
			end
		end
		if ImGui.ShortcutsForCancel(id) and g.ActiveId == id then
			local value_changed
			value_changed, p_v = BehaviorCancelRevert(g, p_v)
			return value_changed, p_v, out_grab_bb
		end
	end

	if data_type == DT_S8 or data_type == DT_S16 or data_type == DT_U8 or data_type == DT_U16 then
		local dt32 = (data_type == DT_S8 or data_type == DT_S16) and DT_S32 or DT_U32
		local r, v32, grab_bb = ImGui.SliderBehaviorT(bb, id, dt32, p_v, p_min, p_max, format, flags, out_grab_bb)
		if r then
			p_v = CastToType(data_type, v32)
		end
		return r, p_v, grab_bb
	elseif data_type == DT_S32 then
		assert(p_min >= Trunc(IM_S32_MIN / 2) and p_max <= Trunc(IM_S32_MAX / 2))
	elseif data_type == DT_U32 then
		assert(p_max <= Trunc(IM_U32_MAX / 2))
	elseif data_type == DT_S64 then
		assert(p_min >= IM_S64_MIN / 2 and p_max <= IM_S64_MAX / 2)
	elseif data_type == DT_U64 then
		assert(p_max <= IM_U64_MAX / 2)
	elseif data_type == DT_Float then
		assert(p_min >= -FLT_MAX / 2.0 and p_max <= FLT_MAX / 2.0)
	elseif data_type == DT_Double then
		assert(p_min >= -DBL_MAX / 2.0 and p_max <= DBL_MAX / 2.0)
	else
		assert(false)
		return false, p_v, out_grab_bb
	end
	return ImGui.SliderBehaviorT(bb, id, data_type, p_v, p_min, p_max, format, flags, out_grab_bb)
end

function ImGui.SliderScalar(label, data_type, p_data, p_min, p_max, format, flags)
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, p_data
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)
	local w = ImGui.CalcItemWidth()
	local color_marker = btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasColorMarker) and g.NextItemData.ColorMarker or 0

	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local frame_bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + ImVec2(w, label_size.y + style.FramePadding.y * 2.0))
	local total_bb = ImRect.new(frame_bb.Min, frame_bb.Max + ImVec2(label_size.x > 0.0 and style.ItemInnerSpacing.x + label_size.x or 0.0, 0.0))

	local temp_input_allowed = not btest(flags, ImGuiSliderFlags.NoInput)
	ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(total_bb, id, frame_bb, temp_input_allowed and ImGuiItemFlags.Inputable or 0) then
		return false, p_data
	end

	if format == nil then
		format = ImGui.DataTypeGetInfo(data_type).PrintFmt
	end

	local hovered = ImGui.ItemHoverable(frame_bb, id, g.LastItemData.ItemFlags)
	local temp_input_is_active = temp_input_allowed and ImGui.TempInputIsActive(id)
	if not temp_input_is_active then
		local clicked = hovered and ImGui.IsMouseClicked(0, ImGuiInputFlags.None, id)
		local make_active = clicked or g.NavActivateId == id
		if make_active and clicked then
			ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
		end
		if make_active and temp_input_allowed then
			if (clicked and g.IO.KeyCtrl) or (g.NavActivateId == id and btest(g.NavActivateFlags, ImGuiActivateFlags.PreferInput)) then
				temp_input_is_active = true
			end
		end

		if make_active then
			g.ActiveIdValueOnActivation = p_data
		end

		if make_active and not temp_input_is_active then
			ImGui.SetActiveID(id, window)
			ImGui.SetFocusID(id, window)
			ImGui.FocusWindow(window)
			g.ActiveIdUsingNavDirMask = bor(g.ActiveIdUsingNavDirMask, lshift(1, ImGuiDir.Left), lshift(1, ImGuiDir.Right))
		end
	end

	if temp_input_is_active then
		local clamp_enabled = btest(flags, ImGuiSliderFlags.ClampOnInput)
		return ImGui.TempInputScalar(frame_bb, id, label, data_type, p_data, format, clamp_enabled and p_min or nil, clamp_enabled and p_max or nil)
	end

	local frame_col = ImGui.GetColorU32(g.ActiveId == id and ImGuiCol.FrameBgActive or (hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg))
	ImGui.RenderNavCursor(frame_bb, id)
	ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, frame_col, false, style.FrameRounding)
	if color_marker ~= 0 and style.ColorMarkerSize > 0.0 then
		ImGui.RenderColorComponentMarker(frame_bb, ImGui.GetColorU32_U32(color_marker), style.FrameRounding)
	end
	ImGui.RenderFrameBorder(frame_bb.Min, frame_bb.Max, g.Style.FrameRounding)

	local value_changed, grab_bb
	value_changed, p_data, grab_bb = ImGui.SliderBehavior(frame_bb, id, data_type, p_data, p_min, p_max, format, flags, ImRect.new())
	if value_changed then
		ImGui.MarkItemEdited(id)
	end

	if grab_bb.Max.x > grab_bb.Min.x then
		window.DrawList:AddRectFilled(grab_bb.Min, grab_bb.Max, ImGui.GetColorU32(g.ActiveId == id and ImGuiCol.SliderGrabActive or ImGuiCol.SliderGrab), style.GrabRounding)
	end

	RenderScalarValueText(g, data_type, p_data, format, frame_bb.Min, frame_bb.Max, ImVec2(0.5, 0.5), true)

	if label_size.x > 0.0 then
		ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y), label, label_end, false)
	end

	return value_changed, p_data
end

function ImGui.SliderScalarN(label, data_type, v, components, v_min, v_max, format, flags)
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local value_changed = false
	ImGui.BeginGroup()
	ImGui.PushID(label)
	ImGui.PushMultiItemsWidths(components, ImGui.CalcItemWidth())
	for i = 0, components - 1 do
		ImGui.PushID(i)
		if i > 0 then
			ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
		end
		if btest(flags, ImGuiSliderFlags.ColorMarkers) then
			ImGui.SetNextItemColorMarker(GDefaultRgbaColorMarkers[i + 1])
		end
		local changed
		changed, v[i + 1] = ImGui.SliderScalar("", data_type, v[i + 1], v_min, v_max, format, flags)
		value_changed = value_changed or changed
		ImGui.PopID()
		ImGui.PopItemWidth()
	end
	ImGui.PopID()

	local label_end = ImGui.FindRenderedTextEnd(label)
	if label_end ~= 1 then
		ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
		ImGui.TextEx(label, label_end)
	end

	ImGui.EndGroup()
	return value_changed
end

function ImGui.SliderFloat(label, v, v_min, v_max, format, flags)
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.SliderScalar(label, DT_Float, v, v_min, v_max, format, flags)
end

local function SliderFloatN(label, v, components, v_min, v_max, format, flags)
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.SliderScalarN(label, DT_Float, v, components, v_min, v_max, format, flags)
end

function ImGui.SliderFloat2(label, v, v_min, v_max, format, flags)
	return SliderFloatN(label, v, 2, v_min, v_max, format, flags)
end

function ImGui.SliderFloat3(label, v, v_min, v_max, format, flags)
	return SliderFloatN(label, v, 3, v_min, v_max, format, flags)
end

function ImGui.SliderFloat4(label, v, v_min, v_max, format, flags)
	return SliderFloatN(label, v, 4, v_min, v_max, format, flags)
end

function ImGui.SliderAngle(label, v_rad, v_degrees_min, v_degrees_max, format, flags)
	if v_degrees_min == nil then v_degrees_min = -360.0 end
	if v_degrees_max == nil then v_degrees_max = 360.0 end
	if flags == nil then flags = 0 end
	if format == nil then
		format = "%.0f deg"
	end
	local v_deg = v_rad * 360.0 / (2 * IM_PI)
	local value_changed
	value_changed, v_deg = ImGui.SliderFloat(label, v_deg, v_degrees_min, v_degrees_max, format, flags)
	if value_changed then
		v_rad = v_deg * (2 * IM_PI) / 360.0
	end
	return value_changed, v_rad
end

function ImGui.SliderInt(label, v, v_min, v_max, format, flags)
	if format == nil then format = "%d" end
	if flags == nil then flags = 0 end
	return ImGui.SliderScalar(label, DT_S32, v, v_min, v_max, format, flags)
end

local function SliderIntN(label, v, components, v_min, v_max, format, flags)
	if format == nil then format = "%d" end
	if flags == nil then flags = 0 end
	return ImGui.SliderScalarN(label, DT_S32, v, components, v_min, v_max, format, flags)
end

function ImGui.SliderInt2(label, v, v_min, v_max, format, flags)
	return SliderIntN(label, v, 2, v_min, v_max, format, flags)
end

function ImGui.SliderInt3(label, v, v_min, v_max, format, flags)
	return SliderIntN(label, v, 3, v_min, v_max, format, flags)
end

function ImGui.SliderInt4(label, v, v_min, v_max, format, flags)
	return SliderIntN(label, v, 4, v_min, v_max, format, flags)
end

function ImGui.VSliderScalar(label, size, data_type, p_data, p_min, p_max, format, flags)
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, p_data
	end

	local g = ImGui.GImGui
	local style = g.Style
	local id = window:GetID(label)

	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local frame_bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + size)
	local bb = ImRect.new(frame_bb.Min, frame_bb.Max + ImVec2(label_size.x > 0.0 and style.ItemInnerSpacing.x + label_size.x or 0.0, 0.0))

	ImGui.ItemSize(bb:GetSize(), style.FramePadding.y)
	if not ImGui.ItemAdd(frame_bb, id) then
		return false, p_data
	end

	if format == nil then
		format = ImGui.DataTypeGetInfo(data_type).PrintFmt
	end

	local hovered = ImGui.ItemHoverable(frame_bb, id, g.LastItemData.ItemFlags)
	local clicked = hovered and ImGui.IsMouseClicked(0, ImGuiInputFlags.None, id)
	if clicked or g.NavActivateId == id then
		if clicked then
			ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
		end
		ImGui.SetActiveID(id, window)
		ImGui.SetFocusID(id, window)
		ImGui.FocusWindow(window)
		g.ActiveIdUsingNavDirMask = bor(g.ActiveIdUsingNavDirMask, lshift(1, ImGuiDir.Up), lshift(1, ImGuiDir.Down))
	end

	local frame_col = ImGui.GetColorU32(g.ActiveId == id and ImGuiCol.FrameBgActive or (hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg))
	ImGui.RenderNavCursor(frame_bb, id)
	ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, frame_col, true, g.Style.FrameRounding)

	local value_changed, grab_bb
	value_changed, p_data, grab_bb = ImGui.SliderBehavior(frame_bb, id, data_type, p_data, p_min, p_max, format, bor(flags, ImGuiSliderFlags.Vertical), ImRect.new())
	if value_changed then
		ImGui.MarkItemEdited(id)
	end

	if grab_bb.Max.y > grab_bb.Min.y then
		window.DrawList:AddRectFilled(grab_bb.Min, grab_bb.Max, ImGui.GetColorU32(g.ActiveId == id and ImGuiCol.SliderGrabActive or ImGuiCol.SliderGrab), style.GrabRounding)
	end

	RenderScalarValueText(g, data_type, p_data, format, ImVec2(frame_bb.Min.x, frame_bb.Min.y + style.FramePadding.y), frame_bb.Max, ImVec2(0.5, 0.0), false)

	if label_size.x > 0.0 then
		ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y), label, label_end, false)
	end

	return value_changed, p_data
end

function ImGui.VSliderFloat(label, size, v, v_min, v_max, format, flags)
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.VSliderScalar(label, size, DT_Float, v, v_min, v_max, format, flags)
end

function ImGui.VSliderInt(label, size, v, v_min, v_max, format, flags)
	if format == nil then format = "%d" end
	if flags == nil then flags = 0 end
	return ImGui.VSliderScalar(label, size, DT_S32, v, v_min, v_max, format, flags)
end

function ImGui.TempInputIsActive(id)
	local g = ImGui.GImGui
	return (g.TempInputId == id and g.ActiveId == id) or (g.InputTextDeactivatedState.ID == id)
end

function ImGui.TempInputText(bb, id, label, buf, flags, callback, user_data)
	if flags == nil then flags = 0 end
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local is_deactivated = g.InputTextDeactivatedState.ID == id
	local is_active = g.TempInputId == id
	if not is_active and not is_deactivated then
		ImGui.ClearActiveID()
	end

	local backup_pos = window.DC.CursorPos
	window.DC.CursorPos = bb.Min
	g.LastItemData.ItemFlags = bor(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowDuplicateId)
	local value_changed
	value_changed, buf = ImGui.InputTextEx(label, nil, buf, bb:GetSize(), bor(flags, ImGuiInputTextFlags.TempInput, ImGuiInputTextFlags.AutoSelectAll), callback, user_data)
	ImGui.KeepAliveID(id)
	if not is_active and not is_deactivated then
		assert(g.ActiveId == id)
		g.TempInputId = g.ActiveId
	end
	if is_active and g.ActiveId ~= id then
		g.TempInputId = 0
	end
	window.DC.CursorPos = backup_pos
	return value_changed, buf
end

local function InputTextStateChangedThisFrame(g)
	if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) then
		local state = ImGui.GetInputTextState(g.LastItemData.ID)
		if state then
			if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) then
				return state.EditedThisFrame or state.ValidatedThisFrame
			end
			return state.ValidatedThisFrame
		end
	end
	return false
end

function ImGui.TempInputScalar(bb, id, label, data_type, p_data, format, p_clamp_min, p_clamp_max)
	local g = ImGui.GImGui
	local type_info = ImGui.DataTypeGetInfo(data_type)
	format = Base.ImParseFormatTrimDecorations(format)
	if format == "" then
		format = type_info.PrintFmt
	end
	local data_buf = TrimBlanks(ImGui.DataTypeFormatString(data_type, p_data, format))

	local flags = bor(ImGuiInputTextFlags.AutoSelectAll, ImGuiInputTextFlags.LocalizeDecimalPoint)
	g.LastItemData.ItemFlags = bor(g.LastItemData.ItemFlags, ImGuiItemFlags.NoMarkEdited)
	if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) then
		g.LastItemData.ItemFlags = bor(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputText)
	else
		g.LastItemData.ItemFlags = band(g.LastItemData.ItemFlags, bnot(ImGuiItemFlags.LiveEditOnInputText))
	end
	local text_changed
	text_changed, data_buf = ImGui.TempInputText(bb, id, label, data_buf, flags)
	if not text_changed then
		return false, p_data
	end

	local data_backup = p_data

	local _
	_, p_data = ImGui.DataTypeApplyFromText(data_buf, data_type, p_data, format, nil)
	if p_clamp_min ~= nil or p_clamp_max ~= nil then
		if p_clamp_min ~= nil and p_clamp_max ~= nil and ImGui.DataTypeCompare(data_type, p_clamp_min, p_clamp_max) > 0 then
			p_clamp_min, p_clamp_max = p_clamp_max, p_clamp_min
		end
		_, p_data = ImGui.DataTypeClamp(data_type, p_data, p_clamp_min, p_clamp_max)
	end

	g.LastItemData.ItemFlags = band(g.LastItemData.ItemFlags, bnot(ImGuiItemFlags.NoMarkEdited))
	local value_changed = data_backup ~= p_data
	if InputTextStateChangedThisFrame(g) then
		value_changed = true
	end

	if value_changed then
		ImGui.MarkItemEdited(id)
	end
	return value_changed, p_data
end

function ImGui.SetNextItemRefVal(data_type, p_data)
	local g = ImGui.GImGui
	g.NextItemData.HasFlags = bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasRefVal)
	g.NextItemData.RefVal = p_data
	return p_data
end

function ImGui.InputScalar(label, data_type, p_data, p_step, p_step_fast, format, flags)
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, p_data
	end

	local g = ImGui.GImGui
	local style = g.Style

	if format == nil then
		format = ImGui.DataTypeGetInfo(data_type).PrintFmt
	end

	local p_data_default
	if btest(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasRefVal) then
		p_data_default = g.NextItemData.RefVal
	else
		p_data_default = g.DataTypeZeroValue
	end

	local buf
	if btest(flags, ImGuiInputTextFlags.DisplayEmptyRefVal) and ImGui.DataTypeCompare(data_type, p_data, p_data_default) == 0 then
		buf = ""
	else
		buf = ImGui.DataTypeFormatString(data_type, p_data, format)
	end

	g.NextItemData.ItemFlagsSet = bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.NoMarkEdited)
	flags = bor(flags, ImGuiInputTextFlags.AutoSelectAll, ImGuiInputTextFlags.LocalizeDecimalPoint)

	local has_step_buttons = p_step ~= nil
	local button_size = has_step_buttons and ImGui.GetFrameHeight() or 0.0
	local ret
	if has_step_buttons then
		ImGui.BeginGroup()
		ImGui.PushID(label)
		ImGui.SetNextItemWidth(math.max(1.0, ImGui.CalcItemWidth() - (button_size + style.ItemInnerSpacing.x) * 2))
		ret, buf = ImGui.InputText("", buf, flags)
	else
		ret, buf = ImGui.InputText(label, buf, flags)
	end

	local value_changed = false
	local p_data_when_empty = btest(flags, ImGuiInputTextFlags.ParseEmptyRefVal) and p_data_default or nil
	if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) then
		local input_edited = btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.EditedInternal)
		if input_edited then
			value_changed, p_data = ImGui.DataTypeApplyFromText(buf, data_type, p_data, format, p_data_when_empty)
		end
	else
		if g.DeactivatedItemData.ID == g.LastItemData.ID then
			value_changed, p_data = ImGui.DataTypeApplyFromText(buf, data_type, p_data, format, p_data_when_empty)
		end
	end
	if InputTextStateChangedThisFrame(g) then
		value_changed = true
	end

	if has_step_buttons then
		local backup_frame_padding = style.FramePadding
		style.FramePadding = ImVec2(style.FramePadding.y, style.FramePadding.y)
		if btest(flags, ImGuiInputTextFlags.ReadOnly) then
			ImGui.BeginDisabled()
		end
		ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true)
		ImGui.SameLine(0, style.ItemInnerSpacing.x)
		local step = (g.IO.KeyCtrl and p_step_fast ~= nil) and p_step_fast or p_step
		if ImGui.ButtonEx("-", ImVec2(button_size, button_size)) then
			p_data = ImGui.DataTypeApplyOp(data_type, CHAR_MINUS, p_data, p_data, step)
			value_changed = true
			ret = true
		end
		ImGui.SameLine(0, style.ItemInnerSpacing.x)
		if ImGui.ButtonEx("+", ImVec2(button_size, button_size)) then
			p_data = ImGui.DataTypeApplyOp(data_type, CHAR_PLUS, p_data, p_data, step)
			value_changed = true
			ret = true
		end
		ImGui.PopItemFlag()
		if btest(flags, ImGuiInputTextFlags.ReadOnly) then
			ImGui.EndDisabled()
		end

		local label_end = ImGui.FindRenderedTextEnd(label)
		if label_end ~= 1 then
			ImGui.SameLine(0, style.ItemInnerSpacing.x)
			ImGui.TextEx(label, label_end)
		end
		style.FramePadding = backup_frame_padding

		ImGui.PopID()
		ImGui.EndGroup()
	end

	g.LastItemData.ItemFlags = band(g.LastItemData.ItemFlags, bnot(ImGuiItemFlags.NoMarkEdited))
	if value_changed then
		ImGui.MarkItemEdited(g.LastItemData.ID)
	end

	if btest(flags, ImGuiInputTextFlags.EnterReturnsTrue) then
		return ret, p_data
	end
	return value_changed, p_data
end

function ImGui.InputScalarN(label, data_type, p_data, components, p_step, p_step_fast, format, flags)
	if flags == nil then flags = 0 end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local value_changed = false
	ImGui.BeginGroup()
	ImGui.PushID(label)
	ImGui.PushMultiItemsWidths(components, ImGui.CalcItemWidth())
	for i = 0, components - 1 do
		ImGui.PushID(i)
		if i > 0 then
			ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
		end
		local changed
		changed, p_data[i + 1] = ImGui.InputScalar("", data_type, p_data[i + 1], p_step, p_step_fast, format, flags)
		value_changed = value_changed or changed
		ImGui.PopID()
		ImGui.PopItemWidth()
	end
	ImGui.PopID()

	local label_end = ImGui.FindRenderedTextEnd(label)
	if label_end ~= 1 then
		ImGui.SameLine(0.0, g.Style.ItemInnerSpacing.x)
		ImGui.TextEx(label, label_end)
	end

	ImGui.EndGroup()
	return value_changed
end

function ImGui.InputFloat(label, v, step, step_fast, format, flags)
	if step == nil then step = 0.0 end
	if step_fast == nil then step_fast = 0.0 end
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.InputScalar(label, DT_Float, v, step > 0.0 and step or nil, step_fast > 0.0 and step_fast or nil, format, flags)
end

local function InputFloatN(label, v, components, format, flags)
	if format == nil then format = "%.3f" end
	if flags == nil then flags = 0 end
	return ImGui.InputScalarN(label, DT_Float, v, components, nil, nil, format, flags)
end

function ImGui.InputFloat2(label, v, format, flags)
	return InputFloatN(label, v, 2, format, flags)
end

function ImGui.InputFloat3(label, v, format, flags)
	return InputFloatN(label, v, 3, format, flags)
end

function ImGui.InputFloat4(label, v, format, flags)
	return InputFloatN(label, v, 4, format, flags)
end

function ImGui.InputInt(label, v, step, step_fast, flags)
	if step == nil then step = 1 end
	if step_fast == nil then step_fast = 100 end
	if flags == nil then flags = 0 end
	local format = btest(flags, ImGuiInputTextFlags.CharsHexadecimal) and "%08X" or "%d"
	return ImGui.InputScalar(label, DT_S32, v, step > 0 and step or nil, step_fast > 0 and step_fast or nil, format, flags)
end

function ImGui.InputInt2(label, v, flags)
	return ImGui.InputScalarN(label, DT_S32, v, 2, nil, nil, "%d", flags or 0)
end

function ImGui.InputInt3(label, v, flags)
	return ImGui.InputScalarN(label, DT_S32, v, 3, nil, nil, "%d", flags or 0)
end

function ImGui.InputInt4(label, v, flags)
	return ImGui.InputScalarN(label, DT_S32, v, 4, nil, nil, "%d", flags or 0)
end

function ImGui.InputDouble(label, v, step, step_fast, format, flags)
	if step == nil then step = 0.0 end
	if step_fast == nil then step_fast = 0.0 end
	if format == nil then format = "%.6f" end
	if flags == nil then flags = 0 end
	return ImGui.InputScalar(label, DT_Double, v, step > 0.0 and step or nil, step_fast > 0.0 and step_fast or nil, format, flags)
end

return true
