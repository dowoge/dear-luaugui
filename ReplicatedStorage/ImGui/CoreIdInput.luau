--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local DrawList = require("./DrawList")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImAbs, ImFloor, ImTrunc = Base.ImAbs, Base.ImFloor, Base.ImTrunc
local ImLengthSqr = Base.ImLengthSqr
local ImHashStr, ImHashData = Base.ImHashStr, Base.ImHashData
local ImPtrToInt = Base.ImPtrToInt
local ImTruncToInt = Base.ImTruncToInt
local ImFormatString = Base.ImFormatString
local FLT_MAX = Base.FLT_MAX
local VEC2_ZERO = vector.create(0, 0, 0)

local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiDataType = Enums.ImGuiDataType
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiMouseSource = Enums.ImGuiMouseSource
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiInputEventType = Enums.ImGuiInputEventType
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiNextItemDataFlags = Enums.ImGuiNextItemDataFlags
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiAxis = Enums.ImGuiAxis
local Defines = Enums.Defines
local ImGuiWindow = Structs.ImGuiWindow

local FONT_DEFAULT_SIZE_BASE = 20.0
local WINDOWS_MOUSE_WHEEL_SCROLL_LOCK_TIMER = 0.70
local NamedKey_BEGIN = ImGuiKey.NamedKey_BEGIN
local NOT_MOD_MASK = bit32.bnot(ImGuiMod.Mask_)

function ImGui.UpdateTexturesNewFrame()
	local g = ImGui.GImGui
	local has_textures = bit32.band(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) ~= 0
	for i = 0, g.FontAtlases.Size - 1 do
		local atlas = g.FontAtlases[i + 1]
		if atlas.OwnerContext == g then
			DrawList.ImFontAtlasUpdateNewFrame(atlas, g.FrameCount, has_textures)
		else
			assert(atlas.Builder ~= nil and atlas.Builder.FrameCount ~= -1)
			assert(atlas.RendererHasTextures == has_textures)
		end
	end
	for i = 0, g.UserTextures.Size - 1 do
		DrawList.ImTextureDataUpdateNewFrame(g.UserTextures[i + 1])
	end
end

function ImGui.UpdateTexturesEndFrame()
	local g = ImGui.GImGui
	g.PlatformIO.Textures:resize(0)
	for i = 0, g.FontAtlases.Size - 1 do
		local atlas = g.FontAtlases[i + 1]
		for j = 0, atlas.TexList.Size - 1 do
			local tex = atlas.TexList[j + 1]
			tex.RefCount = atlas.RefCount
			g.PlatformIO.Textures:push_back(tex)
		end
	end
	for i = 0, g.UserTextures.Size - 1 do
		g.PlatformIO.Textures:push_back(g.UserTextures[i + 1])
	end
end

function ImGui.UpdateFontsNewFrame()
	local g = ImGui.GImGui
	if bit32.band(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) == 0 then
		for i = 0, g.FontAtlases.Size - 1 do
			g.FontAtlases[i + 1].Locked = true
		end
	end

	if g.Style._NextFrameFontSizeBase ~= 0.0 then
		g.Style.FontSizeBase = g.Style._NextFrameFontSizeBase
		g.Style._NextFrameFontSizeBase = 0.0
	end

	local font = ImGui.GetDefaultFont()
	if g.Style.FontSizeBase <= 0.0 then
		g.Style.FontSizeBase = if font.LegacySize > 0.0 then font.LegacySize else FONT_DEFAULT_SIZE_BASE
	end

	g.Font = font
	g.FontSizeBase = g.Style.FontSizeBase
	g.FontSize = 0.0
	local font_stack_data = Structs.ImFontStackData.new()
	font_stack_data.Font = font
	font_stack_data.FontSizeBeforeScaling = g.Style.FontSizeBase
	font_stack_data.FontSizeAfterScaling = g.Style.FontSizeBase
	ImGui.SetCurrentFont(font_stack_data.Font, font_stack_data.FontSizeBeforeScaling, 0.0)
	g.FontStack:push_back(font_stack_data)
	assert(g.Font:IsLoaded())
end

function ImGui.UpdateFontsEndFrame()
	ImGui.PopFont()
end

function ImGui.GetDefaultFont()
	local g = ImGui.GImGui
	local atlas = g.IO.Fonts
	if atlas.Builder == nil or atlas.Fonts.Size == 0 then
		DrawList.ImFontAtlasBuildMain(atlas)
	end
	return if g.IO.FontDefault then g.IO.FontDefault else atlas.Fonts[1]
end

function ImGui.RegisterUserTexture(tex)
	local g = ImGui.GImGui
	tex.RefCount += 1
	g.UserTextures:push_back(tex)
end

function ImGui.UnregisterUserTexture(tex)
	local g = ImGui.GImGui
	assert(tex.RefCount > 0)
	tex.RefCount -= 1
	g.UserTextures:find_erase(tex)
end

function ImGui.RegisterFontAtlas(atlas)
	local g = ImGui.GImGui
	if g.FontAtlases.Size == 0 then
		assert(atlas == g.IO.Fonts)
	end
	atlas.RefCount += 1
	g.FontAtlases:push_back(atlas)
	DrawList.ImFontAtlasAddDrawListSharedData(atlas, g.DrawListSharedData)
	for i = 0, atlas.TexList.Size - 1 do
		atlas.TexList[i + 1].RefCount = atlas.RefCount
	end
end

function ImGui.UnregisterFontAtlas(atlas)
	local g = ImGui.GImGui
	assert(atlas.RefCount > 0)
	DrawList.ImFontAtlasRemoveDrawListSharedData(atlas, g.DrawListSharedData)
	g.FontAtlases:find_erase(atlas)
	atlas.RefCount -= 1
	for i = 0, atlas.TexList.Size - 1 do
		atlas.TexList[i + 1].RefCount = atlas.RefCount
	end
end

function ImGui.SetCurrentFont(font, font_size_before_scaling, font_size_after_scaling)
	local g = ImGui.GImGui
	g.Font = font
	g.FontSizeBase = font_size_before_scaling
	ImGui.UpdateCurrentFontSize(font_size_after_scaling)

	if font ~= nil then
		assert(font and font:IsLoaded())
		local atlas = font.OwnerAtlas
		g.DrawListSharedData.FontAtlas = atlas
		g.DrawListSharedData.Font = font
		DrawList.ImFontAtlasUpdateDrawListsSharedData(atlas)
		if g.CurrentWindow ~= nil then
			g.CurrentWindow.DrawList:_SetTexture(atlas.TexRef)
		end
	end
end

function ImGui.UpdateCurrentFontSize(restore_font_size_after_scaling)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	g.Style.FontSizeBase = g.FontSizeBase

	local final_size = if restore_font_size_after_scaling > 0.0 then restore_font_size_after_scaling else 0.0
	if final_size == 0.0 then
		final_size = g.FontSizeBase
		final_size *= g.Style.FontScaleMain
		final_size *= g.Style.FontScaleDpi
		if window ~= nil then
			final_size *= window.FontWindowScale
		end
	end

	final_size = ImGui.GetRoundedFontSize(final_size)
	final_size = ImClamp(final_size, 1.0, Defines.IMGUI_FONT_SIZE_MAX)
	if g.Font ~= nil and bit32.btest(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) then
		g.Font.CurrentRasterizerDensity = g.CurrentPixelDensity
	end

	g.FontSize = final_size
	g.DrawListSharedData.FontSize = g.FontSize

	if window ~= nil and window.SkipItems then
		local tbl = g.CurrentTable
		local allow_early_out = tbl == nil
			or (tbl.CurrentColumn ~= -1 and tbl.Columns[tbl.CurrentColumn + 1].IsSkipItems == false)
		if allow_early_out then
			return
		end
	end

	g.FontBaked = if g.Font ~= nil and window ~= nil then g.Font:GetFontBaked(final_size) else nil
	g.FontBakedScale = if g.FontBaked ~= nil then g.FontSize / g.FontBaked.Size else 0.0
	g.DrawListSharedData.FontScale = g.FontBakedScale
end

function ImGui.SetPixelDensity(pixel_density)
	local g = ImGui.GImGui
	assert(bit32.btest(g.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures))
	if g.CurrentPixelDensity == pixel_density then
		return
	end
	g.CurrentPixelDensity = pixel_density
	ImGui.UpdateCurrentFontSize(0.0)
end

function ImGui.GetPixelDensity()
	return ImGui.GImGui.CurrentPixelDensity
end

function ImGui.GetRoundedFontSize(size)
	return Base.IM_ROUND(size)
end

function ImGui.PushFont(font, font_size_base)
	local g = ImGui.GImGui
	if font == nil then
		font = g.Font
	end
	assert(font ~= nil)
	assert(font_size_base >= 0.0)

	local data = Structs.ImFontStackData.new()
	data.Font = g.Font
	data.FontSizeBeforeScaling = g.FontSizeBase
	data.FontSizeAfterScaling = g.FontSize
	g.FontStack:push_back(data)
	if font_size_base == 0.0 then
		font_size_base = g.FontSizeBase
	end
	ImGui.SetCurrentFont(font, font_size_base, 0.0)
end

function ImGui.PopFont()
	local g = ImGui.GImGui
	if not (g.FontStack.Size > 0) then
		if ImGui.ErrorLog("Calling PopFont() too many times!") then
			assert(false, "Calling PopFont() too many times!")
		end
		return
	end
	local font_stack_data = g.FontStack:back()
	ImGui.SetCurrentFont(font_stack_data.Font, font_stack_data.FontSizeBeforeScaling, font_stack_data.FontSizeAfterScaling)
	g.FontStack:pop_back()
end

function ImGuiWindow:GetID(str, str_end)
	local seed = self.IDStack:back()
	local id
	local g = self.Ctx
	local t = type(str)
	if t == "string" then
		id = ImHashStr(str, if str_end then str_end - 1 else 0, seed)
		if g.DebugHookIdInfoId == id then
			ImGui.DebugHookIdInfo(id, ImGuiDataType.String, str, str_end)
		end
	elseif t == "number" then
		id = ImHashData(string.pack("<I4", bit32.band(str, 0xFFFFFFFF)), 4, seed)
		if g.DebugHookIdInfoId == id then
			ImGui.DebugHookIdInfo(id, ImGuiDataType.S32, str, nil)
		end
	else
		local n = if str == nil then 0 else ImPtrToInt(str)
		id = ImHashData(string.pack("<I8", n), 8, seed)
		if g.DebugHookIdInfoId == id then
			ImGui.DebugHookIdInfo(id, ImGuiDataType.Pointer, str, nil)
		end
	end
	return id
end

function ImGuiWindow:GetIDFromPos(p_abs)
	local seed = self.IDStack:back()
	local p_rel = ImGui.WindowPosAbsToRel(self, p_abs)
	return ImHashData(string.pack("<ff", p_rel.x, p_rel.y), 8, seed)
end

function ImGuiWindow:GetIDFromRectangle(r_abs)
	local seed = self.IDStack:back()
	local r_rel = ImGui.WindowRectAbsToRel(self, r_abs)
	return ImHashData(string.pack("<ffff", r_rel.Min.x, r_rel.Min.y, r_rel.Max.x, r_rel.Max.y), 16, seed)
end

function ImGui.PushID(str_id, str_id_end)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local id = window:GetID(str_id, str_id_end)
	window.IDStack:push_back(id)
end

function ImGui.PushOverrideID(id)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if g.DebugHookIdInfoId == id then
		ImGui.DebugHookIdInfo(id, ImGuiDataType.ID, nil, nil)
	end
	window.IDStack:push_back(id)
end

function ImGui.GetIDWithSeed(a, b, c)
	local g = ImGui.GImGui
	local id
	if type(a) == "string" then
		local str, str_end, seed = a, b, c
		id = ImHashStr(str, if str_end then str_end - 1 else 0, seed)
		if g.DebugHookIdInfoId == id then
			ImGui.DebugHookIdInfo(id, ImGuiDataType.String, str, str_end)
		end
	else
		local n, seed = a, b
		id = ImHashData(string.pack("<I4", bit32.band(n, 0xFFFFFFFF)), 4, seed)
		if g.DebugHookIdInfoId == id then
			ImGui.DebugHookIdInfo(id, ImGuiDataType.S32, n, nil)
		end
	end
	return id
end

function ImGui.PopID()
	local window = ImGui.GImGui.CurrentWindow
	if not (window.IDStack.Size > 1) then
		if ImGui.ErrorLog("Calling PopID() too many times!") then
			assert(false, "Calling PopID() too many times!")
		end
		return
	end
	window.IDStack:pop_back()
end

function ImGui.GetID(str_id, str_id_end)
	local window = ImGui.GImGui.CurrentWindow
	return window:GetID(str_id, str_id_end)
end

function ImGui.IsNamedKey(key)
	return key >= ImGuiKey.NamedKey_BEGIN and key < ImGuiKey.NamedKey_END
end

function ImGui.IsNamedKeyOrMod(key)
	return (key >= ImGuiKey.NamedKey_BEGIN and key < ImGuiKey.NamedKey_END)
		or key == ImGuiMod.Ctrl
		or key == ImGuiMod.Shift
		or key == ImGuiMod.Alt
		or key == ImGuiMod.Super
end

function ImGui.IsLegacyKey(key)
	return key >= ImGuiKey.LegacyNativeKey_BEGIN and key < ImGuiKey.LegacyNativeKey_END
end

function ImGui.IsKeyboardKey(key)
	return key >= ImGuiKey.Keyboard_BEGIN and key < ImGuiKey.Keyboard_END
end

function ImGui.IsGamepadKey(key)
	return key >= ImGuiKey.Gamepad_BEGIN and key < ImGuiKey.Gamepad_END
end

function ImGui.IsMouseKey(key)
	return key >= ImGuiKey.Mouse_BEGIN and key < ImGuiKey.Mouse_END
end

function ImGui.IsAliasKey(key)
	return key >= ImGuiKey.Aliases_BEGIN and key < ImGuiKey.Aliases_END
end

function ImGui.IsLRModKey(key)
	return key >= ImGuiKey.LeftCtrl and key <= ImGuiKey.RightSuper
end

function ImGui.ConvertSingleModFlagToKey(key)
	if key == ImGuiMod.Ctrl then
		return ImGuiKey.ReservedForModCtrl
	end
	if key == ImGuiMod.Shift then
		return ImGuiKey.ReservedForModShift
	end
	if key == ImGuiMod.Alt then
		return ImGuiKey.ReservedForModAlt
	end
	if key == ImGuiMod.Super then
		return ImGuiKey.ReservedForModSuper
	end
	return key
end

function ImGui.MouseButtonToKey(button)
	assert(button >= 0 and button < ImGuiMouseButton.COUNT)
	return ImGuiKey.MouseLeft + button
end

function ImGui.IsActiveIdUsingNavDir(dir)
	local g = ImGui.GImGui
	return bit32.band(g.ActiveIdUsingNavDirMask, bit32.lshift(1, dir)) ~= 0
end

function ImGui.GetKeyOwnerData(ctx, key)
	if bit32.btest(key, ImGuiMod.Mask_) then
		key = ImGui.ConvertSingleModFlagToKey(key)
	end
	assert(ImGui.IsNamedKey(key))
	return ctx.KeysOwnerData[key - NamedKey_BEGIN + 1]
end

function ImGui.GetModForLRModKey(key)
	if key == ImGuiKey.LeftCtrl or key == ImGuiKey.RightCtrl then
		return ImGuiMod.Ctrl
	end
	if key == ImGuiKey.LeftShift or key == ImGuiKey.RightShift then
		return ImGuiMod.Shift
	end
	if key == ImGuiKey.LeftAlt or key == ImGuiKey.RightAlt then
		return ImGuiMod.Alt
	end
	if key == ImGuiKey.LeftSuper or key == ImGuiKey.RightSuper then
		return ImGuiMod.Super
	end
	return ImGuiMod.None
end

function ImGui.FixupKeyChord(key_chord)
	local key = bit32.band(key_chord, NOT_MOD_MASK)
	if ImGui.IsLRModKey(key) then
		key_chord = bit32.bor(key_chord, ImGui.GetModForLRModKey(key))
	end
	return key_chord
end

function ImGui.GetKeyData(ctx, key)
	if type(ctx) ~= "table" then
		key = ctx
		ctx = ImGui.GImGui
	end
	local g = ctx

	if bit32.btest(key, ImGuiMod.Mask_) then
		key = ImGui.ConvertSingleModFlagToKey(key)
	end

	assert(
		ImGui.IsNamedKey(key),
		"Support for user key indices was dropped in favor of ImGuiKey. Please update backend & user code."
	)
	return g.IO.KeysData[key - NamedKey_BEGIN + 1]
end

local GKeyNames = {
	"Tab", "LeftArrow", "RightArrow", "UpArrow", "DownArrow", "PageUp", "PageDown",
	"Home", "End", "Insert", "Delete", "Backspace", "Space", "Enter", "Escape",
	"LeftCtrl", "LeftShift", "LeftAlt", "LeftSuper", "RightCtrl", "RightShift", "RightAlt", "RightSuper", "Menu",
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H",
	"I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
	"F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23", "F24",
	"Apostrophe", "Comma", "Minus", "Period", "Slash", "Semicolon", "Equal", "LeftBracket",
	"Backslash", "RightBracket", "GraveAccent", "CapsLock", "ScrollLock", "NumLock", "PrintScreen",
	"Pause", "Keypad0", "Keypad1", "Keypad2", "Keypad3", "Keypad4", "Keypad5", "Keypad6",
	"Keypad7", "Keypad8", "Keypad9", "KeypadDecimal", "KeypadDivide", "KeypadMultiply",
	"KeypadSubtract", "KeypadAdd", "KeypadEnter", "KeypadEqual",
	"AppBack", "AppForward", "Oem102",
	"GamepadStart", "GamepadBack",
	"GamepadFaceLeft", "GamepadFaceRight", "GamepadFaceUp", "GamepadFaceDown",
	"GamepadDpadLeft", "GamepadDpadRight", "GamepadDpadUp", "GamepadDpadDown",
	"GamepadL1", "GamepadR1", "GamepadL2", "GamepadR2", "GamepadL3", "GamepadR3",
	"GamepadLStickLeft", "GamepadLStickRight", "GamepadLStickUp", "GamepadLStickDown",
	"GamepadRStickLeft", "GamepadRStickRight", "GamepadRStickUp", "GamepadRStickDown",
	"MouseLeft", "MouseRight", "MouseMiddle", "MouseX1", "MouseX2", "MouseWheelX", "MouseWheelY",
	"ModCtrl", "ModShift", "ModAlt", "ModSuper",
}
assert(ImGuiKey.NamedKey_COUNT == #GKeyNames)

function ImGui.GetKeyName(key)
	if key == ImGuiKey.None then
		return "None"
	end
	assert(
		ImGui.IsNamedKeyOrMod(key),
		"Support for user key indices was dropped in favor of ImGuiKey. Please update backend and user code."
	)
	if bit32.btest(key, ImGuiMod.Mask_) then
		key = ImGui.ConvertSingleModFlagToKey(key)
	end
	if not ImGui.IsNamedKey(key) then
		return "Unknown"
	end

	return GKeyNames[key - NamedKey_BEGIN + 1]
end

function ImGui.GetKeyChordName(key_chord)
	local g = ImGui.GImGui

	local key = bit32.band(key_chord, NOT_MOD_MASK)
	if ImGui.IsLRModKey(key) then
		key_chord = bit32.band(key_chord, bit32.bnot(ImGui.GetModForLRModKey(key)))
	end
	local s = ImFormatString(
		"%s%s%s%s%s",
		if bit32.btest(key_chord, ImGuiMod.Ctrl) then "Ctrl+" else "",
		if bit32.btest(key_chord, ImGuiMod.Shift) then "Shift+" else "",
		if bit32.btest(key_chord, ImGuiMod.Alt) then "Alt+" else "",
		if bit32.btest(key_chord, ImGuiMod.Super) then "Super+" else "",
		if key ~= ImGuiKey.None or key_chord == ImGuiKey.None then ImGui.GetKeyName(key) else ""
	)
	if key == ImGuiKey.None and key_chord ~= 0 then
		if #s ~= 0 then
			s = string.sub(s, 1, #s - 1)
		end
	end
	g.TempKeychordName = s
	return s
end

function ImGui.CalcTypematicRepeatAmount(t0, t1, repeat_delay, repeat_rate)
	if t1 == 0.0 then
		return 1
	end
	if t0 >= t1 then
		return 0
	end
	if repeat_rate <= 0.0 then
		return if t0 < repeat_delay and t1 >= repeat_delay then 1 else 0
	end
	local count_t0 = if t0 < repeat_delay then -1 else ImTruncToInt((t0 - repeat_delay) / repeat_rate)
	local count_t1 = if t1 < repeat_delay then -1 else ImTruncToInt((t1 - repeat_delay) / repeat_rate)
	local count = count_t1 - count_t0
	return count
end

function ImGui.GetTypematicRepeatRate(flags, repeat_delay, repeat_rate)
	local g = ImGui.GImGui
	local rate_flags = bit32.band(flags, ImGuiInputFlags.RepeatRateMask_)
	if rate_flags == ImGuiInputFlags.RepeatRateNavMove then
		return g.IO.KeyRepeatDelay * 0.72, g.IO.KeyRepeatRate * 0.80
	elseif rate_flags == ImGuiInputFlags.RepeatRateNavTweak then
		return g.IO.KeyRepeatDelay * 0.72, g.IO.KeyRepeatRate * 0.30
	else
		return g.IO.KeyRepeatDelay * 1.00, g.IO.KeyRepeatRate * 1.00
	end
end

function ImGui.GetKeyPressedAmount(key, repeat_delay, repeat_rate)
	local g = ImGui.GImGui
	local key_data = ImGui.GetKeyData(key)
	if not key_data.Down then
		return 0
	end
	local t = key_data.DownDuration
	return ImGui.CalcTypematicRepeatAmount(t - g.IO.DeltaTime, t, repeat_delay, repeat_rate)
end

function ImGui.GetKeyMagnitude2d(key_left, key_right, key_up, key_down)
	return ImVec2(
		ImGui.GetKeyData(key_right).AnalogValue - ImGui.GetKeyData(key_left).AnalogValue,
		ImGui.GetKeyData(key_down).AnalogValue - ImGui.GetKeyData(key_up).AnalogValue
	)
end

function ImGui.UpdateKeyRoutingTable(rt)
	local g = ImGui.GImGui
	rt.EntriesNext:resize(0)
	for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
		local new_routing_start_idx = rt.EntriesNext.Size
		local old_routing_idx = rt.Index[key - NamedKey_BEGIN + 1]
		while old_routing_idx ~= -1 do
			local routing_entry = rt.Entries[old_routing_idx + 1]
			routing_entry.RoutingCurrScore = routing_entry.RoutingNextScore
			routing_entry.RoutingCurr = routing_entry.RoutingNext
			routing_entry.RoutingNext = ImGuiKeyOwner.NoOwner
			routing_entry.RoutingNextScore = 0
			if routing_entry.RoutingCurr ~= ImGuiKeyOwner.NoOwner then
				rt.EntriesNext:push_back(routing_entry:Copy())

				if routing_entry.Mods == g.IO.KeyMods then
					local owner_data = ImGui.GetKeyOwnerData(g, key)
					if owner_data.OwnerCurr == ImGuiKeyOwner.NoOwner then
						owner_data.OwnerCurr = routing_entry.RoutingCurr
					end
				end
			end
			old_routing_idx = routing_entry.NextEntryIndex
		end

		rt.Index[key - NamedKey_BEGIN + 1] = if new_routing_start_idx < rt.EntriesNext.Size then new_routing_start_idx else -1
		for n = new_routing_start_idx, rt.EntriesNext.Size - 1 do
			rt.EntriesNext[n + 1].NextEntryIndex = if n + 1 < rt.EntriesNext.Size then n + 1 else -1
		end
	end
	rt.Entries:swap(rt.EntriesNext)
end

function ImGui.GetRoutingIdFromOwnerId(owner_id)
	local g = ImGui.GImGui
	return if owner_id ~= ImGuiKeyOwner.NoOwner and owner_id ~= ImGuiKeyOwner.Any then owner_id else g.CurrentFocusScopeId
end

function ImGui.GetShortcutRoutingData(key_chord)
	local g = ImGui.GImGui
	local rt = g.KeysRoutingTable
	local routing_data
	local key = bit32.band(key_chord, NOT_MOD_MASK)
	local mods = bit32.band(key_chord, ImGuiMod.Mask_)
	if key == ImGuiKey.None then
		key = ImGui.ConvertSingleModFlagToKey(mods)
	end
	assert(ImGui.IsNamedKey(key))

	local idx = rt.Index[key - NamedKey_BEGIN + 1]
	while idx ~= -1 do
		routing_data = rt.Entries[idx + 1]
		if routing_data.Mods == mods then
			return routing_data
		end
		idx = routing_data.NextEntryIndex
	end

	local routing_data_idx = rt.Entries.Size
	rt.Entries:push_back(Structs.ImGuiKeyRoutingData.new())
	routing_data = rt.Entries[routing_data_idx + 1]
	routing_data.Mods = mods
	routing_data.NextEntryIndex = rt.Index[key - NamedKey_BEGIN + 1]
	rt.Index[key - NamedKey_BEGIN + 1] = routing_data_idx
	return routing_data
end

function ImGui.CalcRoutingScore(focus_scope_id, owner_id, flags)
	local g = ImGui.GImGui
	if bit32.btest(flags, ImGuiInputFlags.RouteFocused) then
		if owner_id ~= 0 and g.ActiveId == owner_id then
			return 300
		end

		if focus_scope_id == 0 then
			return 0
		end
		for index_in_focus_path = 0, g.NavFocusRoute.Size - 1 do
			if g.NavFocusRoute[index_in_focus_path + 1].ID == focus_scope_id then
				if bit32.btest(flags, ImGuiInputFlags.RouteOverActive) then
					return 599 - index_in_focus_path
				else
					return 199 - index_in_focus_path
				end
			end
		end
		return 0
	elseif bit32.btest(flags, ImGuiInputFlags.RouteActive) then
		if owner_id ~= 0 and g.ActiveId == owner_id then
			return 300
		end
		return 0
	elseif bit32.btest(flags, ImGuiInputFlags.RouteGlobal) then
		if bit32.btest(flags, ImGuiInputFlags.RouteOverActive) then
			return 400
		end
		if owner_id ~= 0 and g.ActiveId == owner_id then
			return 300
		end
		if bit32.btest(flags, ImGuiInputFlags.RouteOverFocused) then
			return 200
		end
		return 1
	end
	assert(false)
	return 0
end

function ImGui.IsKeyChordPotentiallyCharInput(key_chord)
	local g = ImGui.GImGui

	local mods = bit32.band(key_chord, ImGuiMod.Mask_)
	local ignore_char_inputs = (bit32.btest(mods, ImGuiMod.Ctrl) and not bit32.btest(mods, ImGuiMod.Alt))
		or (g.IO.ConfigMacOSXBehaviors and bit32.btest(mods, ImGuiMod.Ctrl))
	if ignore_char_inputs then
		return false
	end

	local key = bit32.band(key_chord, NOT_MOD_MASK)
	if key == ImGuiKey.None then
		return false
	end
	return Base.ImBitArrayTestBit(g.KeysMayBeCharInput, key - NamedKey_BEGIN)
end

function ImGui.SetShortcutRouting(key_chord, flags, owner_id)
	local g = ImGui.GImGui
	if bit32.band(flags, ImGuiInputFlags.RouteTypeMask_) == 0 then
		flags = bit32.bor(flags, ImGuiInputFlags.RouteGlobal, ImGuiInputFlags.RouteOverFocused, ImGuiInputFlags.RouteOverActive)
	else
		assert(Base.ImIsPowerOfTwo(bit32.band(flags, ImGuiInputFlags.RouteTypeMask_)))
	end
	assert(owner_id ~= ImGuiKeyOwner.Any and owner_id ~= ImGuiKeyOwner.NoOwner)
	if bit32.btest(flags, bit32.bor(ImGuiInputFlags.RouteOverFocused, ImGuiInputFlags.RouteUnlessBgFocused)) then
		assert(bit32.btest(flags, ImGuiInputFlags.RouteGlobal))
	end
	if bit32.btest(flags, ImGuiInputFlags.RouteOverActive) then
		assert(bit32.btest(flags, bit32.bor(ImGuiInputFlags.RouteGlobal, ImGuiInputFlags.RouteFocused)))
	end

	key_chord = ImGui.FixupKeyChord(key_chord)

	if bit32.btest(flags, ImGuiInputFlags.RouteUnlessBgFocused) then
		if g.NavWindow == nil then
			return false
		end
	end

	if bit32.btest(flags, ImGuiInputFlags.RouteAlways) then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventInputRouting) then
			ImGui.DebugLog("SetShortcutRouting(%s, flags=%04X, owner_id=0x%08X) -> always, no register\n", ImGui.GetKeyChordName(key_chord), flags, owner_id)
		end
		return true
	end

	if g.ActiveId ~= 0 and g.ActiveId ~= owner_id then
		if bit32.btest(flags, ImGuiInputFlags.RouteActive) then
			return false
		end

		if g.IO.WantTextInput and ImGui.IsKeyChordPotentiallyCharInput(key_chord) then
			if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventInputRouting) then
				ImGui.DebugLog("SetShortcutRouting(%s, flags=%04X, owner_id=0x%08X) -> filtered as potential char input\n", ImGui.GetKeyChordName(key_chord), flags, owner_id)
			end
			return false
		end

		if bit32.band(flags, ImGuiInputFlags.RouteOverActive) == 0 and g.ActiveIdUsingAllKeyboardKeys then
			local key = bit32.band(key_chord, NOT_MOD_MASK)
			if key == ImGuiKey.None then
				key = ImGui.ConvertSingleModFlagToKey(bit32.band(key_chord, ImGuiMod.Mask_))
			end
			if key >= ImGuiKey.Keyboard_BEGIN and key < ImGuiKey.Keyboard_END then
				return false
			end
		end
	end

	local focus_scope_id = g.CurrentFocusScopeId
	if bit32.btest(flags, ImGuiInputFlags.RouteFromRootWindow) then
		focus_scope_id = g.CurrentWindow.RootWindow.ID
	end

	local score = ImGui.CalcRoutingScore(focus_scope_id, owner_id, flags)
	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventInputRouting) then
		ImGui.DebugLog("SetShortcutRouting(%s, flags=%04X, owner_id=0x%08X) -> score %d\n", ImGui.GetKeyChordName(key_chord), flags, owner_id, score)
	end
	if score == 0 then
		return false
	end

	local routing_data = ImGui.GetShortcutRoutingData(key_chord)
	if score > routing_data.RoutingNextScore then
		routing_data.RoutingNext = owner_id
		routing_data.RoutingNextScore = score
	end

	if routing_data.RoutingCurr == owner_id then
		if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventInputRouting) then
			ImGui.DebugLog("--> granting current route\n")
		end
	end
	return routing_data.RoutingCurr == owner_id
end

function ImGui.TestShortcutRouting(key_chord, owner_id)
	local routing_id = ImGui.GetRoutingIdFromOwnerId(owner_id)
	key_chord = ImGui.FixupKeyChord(key_chord)
	local routing_data = ImGui.GetShortcutRoutingData(key_chord)
	return routing_data.RoutingCurr == routing_id
end

function ImGui.IsKeyDown(key, owner_id)
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local key_data = ImGui.GetKeyData(key)
	if not key_data.Down then
		return false
	end
	if not ImGui.TestKeyOwner(key, owner_id) then
		return false
	end
	return true
end

function ImGui.IsKeyPressed(key, flags, owner_id)
	if type(flags) ~= "number" then
		local repeat_ = flags
		if repeat_ == nil then
			repeat_ = true
		end
		flags = if repeat_ then ImGuiInputFlags.Repeat else ImGuiInputFlags.None
		owner_id = ImGuiKeyOwner.Any
	elseif owner_id == nil then
		owner_id = 0
	end
	local key_data = ImGui.GetKeyData(key)
	if not key_data.Down then
		return false
	end
	local t = key_data.DownDuration
	if t < 0.0 then
		return false
	end
	assert(bit32.band(flags, bit32.bnot(ImGuiInputFlags.SupportedByIsKeyPressed)) == 0)
	if bit32.btest(flags, bit32.bor(ImGuiInputFlags.RepeatRateMask_, ImGuiInputFlags.RepeatUntilMask_)) then
		flags = bit32.bor(flags, ImGuiInputFlags.Repeat)
	end

	local pressed = (t == 0.0)
	if not pressed and bit32.band(flags, ImGuiInputFlags.Repeat) ~= 0 then
		local repeat_delay, repeat_rate = ImGui.GetTypematicRepeatRate(flags)
		pressed = (t > repeat_delay) and ImGui.GetKeyPressedAmount(key, repeat_delay, repeat_rate) > 0
		if pressed and bit32.btest(flags, ImGuiInputFlags.RepeatUntilMask_) then
			local g = ImGui.GImGui
			local key_pressed_time = g.Time - t + 0.00001
			if bit32.btest(flags, ImGuiInputFlags.RepeatUntilKeyModsChange) and g.LastKeyModsChangeTime > key_pressed_time then
				pressed = false
			end
			if bit32.btest(flags, ImGuiInputFlags.RepeatUntilKeyModsChangeFromNone) and g.LastKeyModsChangeFromNoneTime > key_pressed_time then
				pressed = false
			end
			if bit32.btest(flags, ImGuiInputFlags.RepeatUntilOtherKeyPress) and g.LastKeyboardKeyPressTime > key_pressed_time then
				pressed = false
			end
		end
	end
	if not pressed then
		return false
	end
	if not ImGui.TestKeyOwner(key, owner_id) then
		return false
	end
	return true
end

function ImGui.IsKeyReleased(key, owner_id)
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local key_data = ImGui.GetKeyData(key)
	if key_data.DownDurationPrev < 0.0 or key_data.Down then
		return false
	end
	if not ImGui.TestKeyOwner(key, owner_id) then
		return false
	end
	return true
end

function ImGui.IsMouseDown(button, owner_id)
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	return g.IO.MouseDown[button + 1] and ImGui.TestKeyOwner(ImGui.MouseButtonToKey(button), owner_id)
end

function ImGui.IsMouseClicked(button, flags, owner_id)
	if type(flags) ~= "number" then
		flags = if flags then ImGuiInputFlags.Repeat else ImGuiInputFlags.None
		owner_id = ImGuiKeyOwner.Any
	elseif owner_id == nil then
		owner_id = 0
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	if not g.IO.MouseDown[button + 1] then
		return false
	end
	local t = g.IO.MouseDownDuration[button + 1]
	if t < 0.0 then
		return false
	end
	assert(bit32.band(flags, bit32.bnot(ImGuiInputFlags.SupportedByIsMouseClicked)) == 0)

	local repeat_ = bit32.band(flags, ImGuiInputFlags.Repeat) ~= 0
	local pressed = (t == 0.0)
		or (
			repeat_
			and t > g.IO.KeyRepeatDelay
			and ImGui.CalcTypematicRepeatAmount(t - g.IO.DeltaTime, t, g.IO.KeyRepeatDelay, g.IO.KeyRepeatRate) > 0
		)
	if not pressed then
		return false
	end

	if not ImGui.TestKeyOwner(ImGui.MouseButtonToKey(button), owner_id) then
		return false
	end

	return true
end

function ImGui.IsMouseReleased(button, owner_id)
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	return g.IO.MouseReleased[button + 1] and ImGui.TestKeyOwner(ImGui.MouseButtonToKey(button), owner_id)
end

function ImGui.IsMouseReleasedWithDelay(button, delay)
	if delay == nil then
		delay = -1.0
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	if ImGui.IsMouseDown(button) then
		return false
	end
	if delay < 0.0 then
		delay = g.IO.MouseSingleClickDelay
	end
	local time_since_release = g.Time - g.IO.MouseReleasedTime[button + 1]
	return (time_since_release - g.IO.DeltaTime < delay) and (time_since_release >= delay)
end

function ImGui.IsMouseDoubleClicked(button, owner_id)
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	return g.IO.MouseClickedCount[button + 1] == 2 and ImGui.TestKeyOwner(ImGui.MouseButtonToKey(button), owner_id)
end

function ImGui.GetMouseClickedCount(button)
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	return g.IO.MouseClickedCount[button + 1]
end

function ImGui.LastItemOverlayButtonForNullId(mouse_button)
	local g = ImGui.GImGui
	assert(g.LastItemData.ID == 0)
	local window = g.CurrentWindow
	local id = window:GetIDFromRectangle(g.LastItemData.Rect)
	if g.IO.MouseClicked[mouse_button + 1] and ImGui.ItemHoverable(g.LastItemData.Rect, id, g.LastItemData.ItemFlags) then
		ImGui.SetActiveID(id, window)
		ImGui.FocusWindow(window)
	elseif g.ActiveId == id then
		ImGui.KeepAliveID(id)
		if not g.IO.MouseDown[mouse_button + 1] then
			ImGui.ClearActiveID()
		end
	end
	return id
end

function ImGui.GetItemClickedCountWithSingleClickDelay(mouse_button, delay)
	if mouse_button == nil then
		mouse_button = 0
	end
	if delay == nil then
		delay = -1.0
	end
	local g = ImGui.GImGui
	if g.IO.MouseClickedCount[mouse_button + 1] >= 2 and ImGui.IsItemClicked(mouse_button) then
		return g.IO.MouseClickedCount[mouse_button + 1]
	end

	local id = g.LastItemData.ID
	if id == 0 then
		id = ImGui.LastItemOverlayButtonForNullId(mouse_button)
	end
	if g.LastActiveId == id then
		if delay >= 0.0 then
			delay = ImMax(delay, g.IO.MouseDoubleClickTime + 0.01)
		end
		if ImGui.IsMouseReleasedWithDelay(mouse_button, delay) and g.IO.MouseClickedLastCount[mouse_button + 1] == 1 then
			return 1
		end
	end
	return 0
end

function ImGui.IsMouseHoveringRect(r_min, r_max, clip)
	if clip == nil then
		clip = true
	end
	local g = ImGui.GImGui

	local mn, mx = r_min or VEC2_ZERO, r_max or VEC2_ZERO
	if clip then
		local clip_rect = g.CurrentWindow.ClipRect
		mn = vector.max(mn, clip_rect.Min)
		mx = vector.min(mx, clip_rect.Max)
	end

	local p, pad = g.IO.MousePos, g.Style.TouchExtraPadding
	if not (p.x >= mn.x - pad.x and p.y >= mn.y - pad.y and p.x < mx.x + pad.x and p.y < mx.y + pad.y) then
		return false
	end
	return true
end

function ImGui.IsMouseDragPastThreshold(button, lock_threshold)
	if lock_threshold == nil then
		lock_threshold = -1.0
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	if lock_threshold < 0.0 then
		lock_threshold = g.IO.MouseDragThreshold
	end
	return g.IO.MouseDragMaxDistanceSqr[button + 1] >= lock_threshold * lock_threshold
end

function ImGui.IsMouseDragging(button, lock_threshold)
	if lock_threshold == nil then
		lock_threshold = -1.0
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	if not g.IO.MouseDown[button + 1] then
		return false
	end
	return ImGui.IsMouseDragPastThreshold(button, lock_threshold)
end

function ImGui.GetMousePos()
	local g = ImGui.GImGui
	return g.IO.MousePos
end

function ImGui.TeleportMousePos(pos)
	local g = ImGui.GImGui
	g.IO.MousePosPrev = pos
	g.IO.MousePos = pos
	g.IO.MouseDelta = ImVec2(0.0, 0.0)
	g.IO.WantSetMousePos = true
end

function ImGui.GetMousePosOnOpeningCurrentPopup()
	local g = ImGui.GImGui
	if g.BeginPopupStack.Size > 0 then
		return g.BeginPopupStack[g.BeginPopupStack.Size].OpenMousePos
	end
	return g.IO.MousePos
end

function ImGui.IsMousePosValid(mouse_pos)
	assert(ImGui.GImGui ~= nil)
	local MOUSE_INVALID = -256000.0
	local p = if mouse_pos then mouse_pos else ImGui.GImGui.IO.MousePos
	return p.x >= MOUSE_INVALID and p.y >= MOUSE_INVALID
end

function ImGui.IsAnyMouseDown()
	local g = ImGui.GImGui
	for n = 0, #g.IO.MouseDown - 1 do
		if g.IO.MouseDown[n + 1] then
			return true
		end
	end
	return false
end

function ImGui.GetMouseDragDelta(button, lock_threshold)
	if button == nil then
		button = 0
	end
	if lock_threshold == nil then
		lock_threshold = -1.0
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	if lock_threshold < 0.0 then
		lock_threshold = g.IO.MouseDragThreshold
	end
	if g.IO.MouseDown[button + 1] or g.IO.MouseReleased[button + 1] then
		if g.IO.MouseDragMaxDistanceSqr[button + 1] >= lock_threshold * lock_threshold then
			if ImGui.IsMousePosValid(g.IO.MousePos) and ImGui.IsMousePosValid(g.IO.MouseClickedPos[button + 1]) then
				return g.IO.MousePos - g.IO.MouseClickedPos[button + 1]
			end
		end
	end
	return ImVec2(0.0, 0.0)
end

function ImGui.ResetMouseDragDelta(button)
	if button == nil then
		button = 0
	end
	local g = ImGui.GImGui
	assert(button >= 0 and button < #g.IO.MouseDown)
	g.IO.MouseClickedPos[button + 1] = g.IO.MousePos
end

function ImGui.GetMouseCursor()
	local g = ImGui.GImGui
	return g.MouseCursor
end

function ImGui.SetMouseCursor(cursor_type)
	local g = ImGui.GImGui
	g.MouseCursor = cursor_type
end

function ImGui.UpdateAliasKey(key, v, analog_value)
	assert(ImGui.IsAliasKey(key))
	local key_data = ImGui.GetKeyData(key)
	key_data.Down = v
	key_data.AnalogValue = analog_value
end

function ImGui.GetMergedModsFromKeys()
	local mods = 0
	if ImGui.GetKeyData(ImGuiMod.Ctrl).Down then
		mods = bit32.bor(mods, ImGuiMod.Ctrl)
	end
	if ImGui.GetKeyData(ImGuiMod.Shift).Down then
		mods = bit32.bor(mods, ImGuiMod.Shift)
	end
	if ImGui.GetKeyData(ImGuiMod.Alt).Down then
		mods = bit32.bor(mods, ImGuiMod.Alt)
	end
	if ImGui.GetKeyData(ImGuiMod.Super).Down then
		mods = bit32.bor(mods, ImGuiMod.Super)
	end
	return mods
end

function ImGui.UpdateKeyboardInputs()
	local g = ImGui.GImGui
	local io = g.IO

	if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) then
		io:ClearInputKeys()
	end

	for n = 0, ImGuiMouseButton.COUNT - 1 do
		ImGui.UpdateAliasKey(ImGui.MouseButtonToKey(n), io.MouseDown[n + 1], if io.MouseDown[n + 1] then 1.0 else 0.0)
	end
	ImGui.UpdateAliasKey(ImGuiKey.MouseWheelX, io.MouseWheelH ~= 0.0, io.MouseWheelH)
	ImGui.UpdateAliasKey(ImGuiKey.MouseWheelY, io.MouseWheel ~= 0.0, io.MouseWheel)

	local prev_key_mods = io.KeyMods
	io.KeyMods = ImGui.GetMergedModsFromKeys()
	io.KeyCtrl = bit32.band(io.KeyMods, ImGuiMod.Ctrl) ~= 0
	io.KeyShift = bit32.band(io.KeyMods, ImGuiMod.Shift) ~= 0
	io.KeyAlt = bit32.band(io.KeyMods, ImGuiMod.Alt) ~= 0
	io.KeySuper = bit32.band(io.KeyMods, ImGuiMod.Super) ~= 0
	if prev_key_mods ~= io.KeyMods then
		g.LastKeyModsChangeTime = g.Time
	end
	if prev_key_mods ~= io.KeyMods and prev_key_mods == 0 then
		g.LastKeyModsChangeFromNoneTime = g.Time
	end

	if bit32.band(io.BackendFlags, ImGuiBackendFlags.HasGamepad) == 0 then
		for key = ImGuiKey.Gamepad_BEGIN, ImGuiKey.Gamepad_END - 1 do
			io.KeysData[key - NamedKey_BEGIN + 1].Down = false
			io.KeysData[key - NamedKey_BEGIN + 1].AnalogValue = 0.0
		end
	end

	for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
		local key_data = io.KeysData[key - NamedKey_BEGIN + 1]
		key_data.DownDurationPrev = key_data.DownDuration
		key_data.DownDuration = if key_data.Down
			then (if key_data.DownDuration < 0.0 then 0.0 else key_data.DownDuration + io.DeltaTime)
			else -1.0
		if key_data.DownDuration == 0.0 then
			if ImGui.IsKeyboardKey(key) then
				g.LastKeyboardKeyPressTime = g.Time
			elseif
				key == ImGuiKey.ReservedForModCtrl
				or key == ImGuiKey.ReservedForModShift
				or key == ImGuiKey.ReservedForModAlt
				or key == ImGuiKey.ReservedForModSuper
			then
				g.LastKeyboardKeyPressTime = g.Time
			end
		end
	end

	for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
		local key_data = io.KeysData[key - NamedKey_BEGIN + 1]
		local owner_data = g.KeysOwnerData[key - NamedKey_BEGIN + 1]
		owner_data.OwnerCurr = owner_data.OwnerNext
		if not key_data.Down then
			owner_data.OwnerNext = ImGuiKeyOwner.NoOwner
		end
		owner_data.LockUntilRelease = owner_data.LockUntilRelease and key_data.Down
		owner_data.LockThisFrame = owner_data.LockUntilRelease
	end

	ImGui.UpdateKeyRoutingTable(g.KeysRoutingTable)
end

function ImGui.UpdateMouseInputs()
	local g = ImGui.GImGui
	local io = g.IO

	io.MouseWheelRequestAxisSwap = io.KeyShift and not io.ConfigMacOSXBehaviors

	if ImGui.IsMousePosValid(io.MousePos) then
		g.MouseLastValidPos = ImFloor(io.MousePos)
		io.MousePos = g.MouseLastValidPos
	end

	if ImGui.IsMousePosValid(io.MousePos) and ImGui.IsMousePosValid(io.MousePosPrev) then
		io.MouseDelta = io.MousePos - io.MousePosPrev
	else
		io.MouseDelta = ImVec2(0.0, 0.0)
	end

	local mouse_stationary_threshold = if io.MouseSource == ImGuiMouseSource.Mouse then 2.0 else 3.0
	local mouse_stationary = (ImLengthSqr(io.MouseDelta) <= mouse_stationary_threshold * mouse_stationary_threshold)
	g.MouseStationaryTimer = if mouse_stationary then (g.MouseStationaryTimer + io.DeltaTime) else 0.0

	if io.MouseDelta.x ~= 0.0 or io.MouseDelta.y ~= 0.0 then
		g.NavHighlightItemUnderNav = false
	end

	for i = 1, #io.MouseDown do
		io.MouseClicked[i] = io.MouseDown[i] and io.MouseDownDuration[i] < 0.0
		io.MouseClickedCount[i] = 0
		io.MouseReleased[i] = not io.MouseDown[i] and io.MouseDownDuration[i] >= 0.0
		if io.MouseReleased[i] then
			io.MouseReleasedTime[i] = g.Time
		end
		io.MouseDownDurationPrev[i] = io.MouseDownDuration[i]
		io.MouseDownDuration[i] = if io.MouseDown[i]
			then (if io.MouseDownDuration[i] < 0.0 then 0.0 else io.MouseDownDuration[i] + io.DeltaTime)
			else -1.0
		if io.MouseClicked[i] then
			local is_repeated_click = false
			if g.Time - io.MouseClickedTime[i] < io.MouseDoubleClickTime then
				local delta_from_click_pos = if ImGui.IsMousePosValid(io.MousePos)
					then (io.MousePos - io.MouseClickedPos[i])
					else ImVec2(0.0, 0.0)
				if ImLengthSqr(delta_from_click_pos) < io.MouseDoubleClickMaxDist * io.MouseDoubleClickMaxDist then
					is_repeated_click = true
				end
			end
			if is_repeated_click then
				io.MouseClickedLastCount[i] += 1
			else
				io.MouseClickedLastCount[i] = 1
			end
			io.MouseClickedTime[i] = g.Time
			io.MouseClickedPos[i] = io.MousePos
			io.MouseClickedCount[i] = io.MouseClickedLastCount[i]
			io.MouseDragMaxDistanceSqr[i] = 0.0
		elseif io.MouseDown[i] then
			local delta_sqr_click_pos = if ImGui.IsMousePosValid(io.MousePos)
				then ImLengthSqr(io.MousePos - io.MouseClickedPos[i])
				else 0.0
			io.MouseDragMaxDistanceSqr[i] = ImMax(io.MouseDragMaxDistanceSqr[i], delta_sqr_click_pos)
		end

		io.MouseDoubleClicked[i] = (io.MouseClickedCount[i] == 2)

		if io.MouseClicked[i] then
			g.NavHighlightItemUnderNav = false
		end
	end
end

function ImGui.LockWheelingWindow(window, wheel_amount)
	local g = ImGui.GImGui
	if window then
		g.WheelingWindowReleaseTimer = ImMin(
			g.WheelingWindowReleaseTimer + ImAbs(wheel_amount) * WINDOWS_MOUSE_WHEEL_SCROLL_LOCK_TIMER,
			WINDOWS_MOUSE_WHEEL_SCROLL_LOCK_TIMER
		)
	else
		g.WheelingWindowReleaseTimer = 0.0
	end
	if g.WheelingWindow == window then
		return
	end
	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventIO) then
		ImGui.DebugLog("[io] LockWheelingWindow() \"%s\"\n", if window then window.Name else "NULL")
	end
	g.WheelingWindow = window
	g.WheelingWindowRefMousePos = g.IO.MousePos
	if window == nil then
		g.WheelingWindowStartFrame = -1
		g.WheelingAxisAvg = ImVec2(0.0, 0.0)
	end
end

function ImGui.FindBestWheelingWindow(wheel)
	local g = ImGui.GImGui
	local windows = { nil, nil }
	for axis = 0, 1 do
		local wheel_v = if axis == 0 then wheel.x else wheel.y
		if wheel_v ~= 0.0 then
			local window = g.HoveredWindow
			windows[axis + 1] = window
			while bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow) do
				local scroll_max = if axis == 0 then window.ScrollMax.x else window.ScrollMax.y
				local has_scrolling = (scroll_max ~= 0.0)
				local inputs_disabled = bit32.btest(window.Flags, ImGuiWindowFlags.NoScrollWithMouse)
					and not bit32.btest(window.Flags, ImGuiWindowFlags.NoMouseInputs)
				if has_scrolling and not inputs_disabled then
					break
				end
				window = window.ParentWindow
				windows[axis + 1] = window
			end
		end
	end
	local w0, w1 = windows[1], windows[2]
	if w0 == nil and w1 == nil then
		return nil
	end

	if w0 == w1 or w0 == nil or w1 == nil then
		return if w1 then w1 else w0
	end

	if g.WheelingWindowStartFrame == -1 then
		g.WheelingWindowStartFrame = g.FrameCount
	end
	if
		(g.WheelingWindowStartFrame == g.FrameCount and wheel.x ~= 0.0 and wheel.y ~= 0.0)
		or (g.WheelingAxisAvg.x == g.WheelingAxisAvg.y)
	then
		g.WheelingWindowWheelRemainder = wheel
		return nil
	end
	return if g.WheelingAxisAvg.x > g.WheelingAxisAvg.y then w0 else w1
end

function ImGui.UpdateMouseWheel()
	local g = ImGui.GImGui
	if g.WheelingWindow ~= nil then
		g.WheelingWindowReleaseTimer -= g.IO.DeltaTime
		if
			ImGui.IsMousePosValid()
			and ImLengthSqr(g.IO.MousePos - g.WheelingWindowRefMousePos) > g.IO.MouseDragThreshold * g.IO.MouseDragThreshold
		then
			g.WheelingWindowReleaseTimer = 0.0
		end
		if g.WheelingWindowReleaseTimer <= 0.0 then
			ImGui.LockWheelingWindow(nil, 0.0)
		end
	end

	local mouse_window = if g.WheelingWindow then g.WheelingWindow else g.HoveredWindow
	if not mouse_window or mouse_window.Collapsed then
		return
	end

	local owner_id = mouse_window.ID
	local wheel = ImVec2(
		if ImGui.TestKeyOwner(ImGuiKey.MouseWheelX, owner_id) then g.IO.MouseWheelH else 0.0,
		if ImGui.TestKeyOwner(ImGuiKey.MouseWheelY, owner_id) then g.IO.MouseWheel else 0.0
	)
	if g.WheelingWindow ~= nil then
		ImGui.SetKeyOwner(ImGuiKey.MouseWheelX, owner_id)
		ImGui.SetKeyOwner(ImGuiKey.MouseWheelY, owner_id)
	end

	if wheel.y ~= 0.0 and g.IO.KeyCtrl and g.IO.FontAllowUserScaling then
		ImGui.LockWheelingWindow(mouse_window, wheel.y)
		local window = mouse_window
		local new_font_scale = ImClamp(window.FontWindowScale + g.IO.MouseWheel * 0.10, 0.50, 2.50)
		local scale = new_font_scale / window.FontWindowScale
		window.FontWindowScale = new_font_scale
		if window == window.RootWindow then
			local offset = window.Size * (1.0 - scale) * (g.IO.MousePos - window.Pos) / window.Size
			ImGui.SetWindowPos(window, window.Pos + offset, 0)
			window.Size = ImTrunc(window.Size * scale)
			window.SizeFull = ImTrunc(window.SizeFull * scale)
			ImGui.MarkIniSettingsDirty(window)
		end
		return
	end
	if g.IO.KeyCtrl then
		return
	end

	if g.IO.MouseWheelRequestAxisSwap then
		wheel = ImVec2(wheel.y, 0.0)
	end

	g.WheelingAxisAvg = ImVec2(
		Base.ImExponentialMovingAverage(g.WheelingAxisAvg.x, ImAbs(wheel.x), 30),
		Base.ImExponentialMovingAverage(g.WheelingAxisAvg.y, ImAbs(wheel.y), 30)
	)

	wheel += g.WheelingWindowWheelRemainder
	g.WheelingWindowWheelRemainder = ImVec2(0.0, 0.0)
	if wheel.x == 0.0 and wheel.y == 0.0 then
		return
	end

	local window = if g.WheelingWindow then g.WheelingWindow else ImGui.FindBestWheelingWindow(wheel)
	if window then
		if
			not bit32.btest(window.Flags, ImGuiWindowFlags.NoScrollWithMouse)
			and not bit32.btest(window.Flags, ImGuiWindowFlags.NoMouseInputs)
		then
			local do_scroll = { wheel.x ~= 0.0 and window.ScrollMax.x ~= 0.0, wheel.y ~= 0.0 and window.ScrollMax.y ~= 0.0 }
			if do_scroll[ImGuiAxis.X + 1] and do_scroll[ImGuiAxis.Y + 1] then
				do_scroll[(if g.WheelingAxisAvg.x > g.WheelingAxisAvg.y then ImGuiAxis.Y else ImGuiAxis.X) + 1] = false
			end
			if do_scroll[ImGuiAxis.X + 1] then
				ImGui.LockWheelingWindow(window, wheel.x)
				local max_step = window.InnerRect:GetWidth() * 0.67
				local scroll_step = ImTrunc(ImMin(2 * window.FontRefSize, max_step))
				ImGui.SetScrollX(window, window.Scroll.x - wheel.x * scroll_step)
				g.WheelingWindowScrolledFrame = g.FrameCount
			end
			if do_scroll[ImGuiAxis.Y + 1] then
				ImGui.LockWheelingWindow(window, wheel.y)
				local max_step = window.InnerRect:GetHeight() * 0.67
				local scroll_step = ImTrunc(ImMin(5 * window.FontRefSize, max_step))
				ImGui.SetScrollY(window, window.Scroll.y - wheel.y * scroll_step)
				g.WheelingWindowScrolledFrame = g.FrameCount
			end
		end
	end
end

function ImGui.SetNextFrameWantCaptureKeyboard(want_capture_keyboard)
	local g = ImGui.GImGui
	g.WantCaptureKeyboardNextFrame = if want_capture_keyboard then 1 else 0
end

function ImGui.SetNextFrameWantCaptureMouse(want_capture_mouse)
	local g = ImGui.GImGui
	g.WantCaptureMouseNextFrame = if want_capture_mouse then 1 else 0
end

local input_source_names = { "None", "Mouse", "Keyboard", "Gamepad" }
function ImGui.GetInputSourceName(source)
	assert(#input_source_names == ImGuiInputSource.COUNT)
	if source < 0 or source >= ImGuiInputSource.COUNT then
		return "Unknown"
	end
	return input_source_names[source + 1]
end

local mouse_source_names = { "Mouse", "TouchScreen", "Pen" }
function ImGui.GetMouseSourceName(source)
	assert(#mouse_source_names == ImGuiMouseSource.COUNT)
	if source < 0 or source >= ImGuiMouseSource.COUNT then
		return "Unknown"
	end
	return mouse_source_names[source + 1]
end

function ImGui.DebugPrintInputEvent(prefix, e)
	local g = ImGui.GImGui
	local log_io = bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventIO)
	if e.Type == ImGuiInputEventType.MousePos then
		if e.MousePos.PosX == -FLT_MAX and e.MousePos.PosY == -FLT_MAX then
			if log_io then
				ImGui.DebugLog("[io] %s: MousePos (-FLT_MAX, -FLT_MAX)\n", prefix)
			end
		else
			if log_io then
				ImGui.DebugLog("[io] %s: MousePos (%.1f, %.1f) (%s)\n", prefix, e.MousePos.PosX, e.MousePos.PosY, ImGui.GetMouseSourceName(e.MousePos.MouseSource))
			end
		end
		return
	end
	if e.Type == ImGuiInputEventType.MouseButton then
		if log_io then
			ImGui.DebugLog("[io] %s: MouseButton %d %s (%s)\n", prefix, e.MouseButton.Button, if e.MouseButton.Down then "Down" else "Up", ImGui.GetMouseSourceName(e.MouseButton.MouseSource))
		end
		return
	end
	if e.Type == ImGuiInputEventType.MouseWheel then
		if log_io then
			ImGui.DebugLog("[io] %s: MouseWheel (%.3f, %.3f) (%s)\n", prefix, e.MouseWheel.WheelX, e.MouseWheel.WheelY, ImGui.GetMouseSourceName(e.MouseWheel.MouseSource))
		end
		return
	end
	if e.Type == ImGuiInputEventType.Key then
		if log_io then
			ImGui.DebugLog("[io] %s: Key \"%s\" %s\n", prefix, ImGui.GetKeyName(e.Key.Key), if e.Key.Down then "Down" else "Up")
		end
		return
	end
	if e.Type == ImGuiInputEventType.Text then
		local buf = Base.ImTextCharToUtf8(e.Text.Char)
		if log_io then
			ImGui.DebugLog("[io] %s: Text: '%s' (U+%08X)\n", prefix, buf, e.Text.Char)
		end
		return
	end
	if e.Type == ImGuiInputEventType.Focus then
		if log_io then
			ImGui.DebugLog("[io] %s: AppFocused %d\n", prefix, if e.AppFocused.Focused then 1 else 0)
		end
		return
	end
end

function ImGui.UpdateInputEvents(trickle_fast_inputs)
	local g = ImGui.GImGui
	local io = g.IO

	local trickle_interleaved_nonchar_keys_and_text = (trickle_fast_inputs and g.WantTextInputNextFrame == 1)

	local mouse_moved, mouse_wheeled, key_changed, key_changed_nonchar, text_inputted = false, false, false, false, false
	local mouse_button_changed = 0x00
	local key_changed_mask = table.create((ImGuiKey.NamedKey_COUNT + 31) // 32, 0)

	local event_n = 0
	while event_n < g.InputEventsQueue.Size do
		local e = g.InputEventsQueue[event_n + 1]
		if e.Type == ImGuiInputEventType.MousePos then
			if not g.IO.WantSetMousePos then
				local event_pos = ImVec2(e.MousePos.PosX, e.MousePos.PosY)
				if trickle_fast_inputs and (mouse_button_changed ~= 0 or mouse_wheeled or key_changed or text_inputted) then
					break
				end
				io.MousePos = event_pos
				io.MouseSource = e.MousePos.MouseSource
				mouse_moved = true
			end
		elseif e.Type == ImGuiInputEventType.MouseButton then
			local button = e.MouseButton.Button
			assert(button >= 0 and button < ImGuiMouseButton.COUNT)
			if trickle_fast_inputs and (bit32.btest(mouse_button_changed, bit32.lshift(1, button)) or mouse_wheeled) then
				break
			end
			if trickle_fast_inputs and e.MouseButton.MouseSource == ImGuiMouseSource.TouchScreen and mouse_moved then
				break
			end
			io.MouseDown[button + 1] = e.MouseButton.Down
			io.MouseSource = e.MouseButton.MouseSource
			mouse_button_changed = bit32.bor(mouse_button_changed, bit32.lshift(1, button))
		elseif e.Type == ImGuiInputEventType.MouseWheel then
			if trickle_fast_inputs and (mouse_moved or mouse_button_changed ~= 0) then
				break
			end
			io.MouseWheelH += e.MouseWheel.WheelX
			io.MouseWheel += e.MouseWheel.WheelY
			io.MouseSource = e.MouseWheel.MouseSource
			mouse_wheeled = true
		elseif e.Type == ImGuiInputEventType.Key then
			if not bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) then
				local key = e.Key.Key
				assert(key ~= ImGuiKey.None)
				local key_data = ImGui.GetKeyData(key)
				local storage_key = if bit32.btest(key, ImGuiMod.Mask_) then ImGui.ConvertSingleModFlagToKey(key) else key
				local key_data_index = storage_key - NamedKey_BEGIN
				if
					trickle_fast_inputs
					and key_data.Down ~= e.Key.Down
					and (Base.ImBitArrayTestBit(key_changed_mask, key_data_index) or mouse_button_changed ~= 0)
				then
					break
				end

				local key_is_potentially_for_char_input =
					ImGui.IsKeyChordPotentiallyCharInput(bit32.bor(ImGui.GetMergedModsFromKeys(), key))
				if trickle_interleaved_nonchar_keys_and_text and (text_inputted and not key_is_potentially_for_char_input) then
					break
				end

				if key_data.Down ~= e.Key.Down then
					key_changed = true
					Base.ImBitArraySetBit(key_changed_mask, key_data_index)
					if trickle_interleaved_nonchar_keys_and_text and not key_is_potentially_for_char_input then
						key_changed_nonchar = true
					end
				end

				key_data.Down = e.Key.Down
				key_data.AnalogValue = e.Key.AnalogValue
			end
		elseif e.Type == ImGuiInputEventType.Text then
			if not bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) then
				if trickle_fast_inputs and (mouse_button_changed ~= 0 or mouse_moved or mouse_wheeled) then
					break
				end
				if trickle_interleaved_nonchar_keys_and_text and key_changed_nonchar then
					break
				end
				local c = e.Text.Char
				io.InputQueueCharacters:push_back(if c <= Defines.IM_UNICODE_CODEPOINT_MAX then c else Defines.IM_UNICODE_CODEPOINT_INVALID)
				if trickle_interleaved_nonchar_keys_and_text then
					text_inputted = true
				end
			end
		elseif e.Type == ImGuiInputEventType.Focus then
			local focus_lost = not e.AppFocused.Focused
			io.AppFocusLost = focus_lost
		else
			assert(false, "Unknown event!")
		end
		event_n += 1
	end

	for n = 0, event_n - 1 do
		g.InputEventsTrail:push_back(g.InputEventsQueue[n + 1])
	end

	if event_n ~= 0 and bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventIO) then
		for n = 0, g.InputEventsQueue.Size - 1 do
			ImGui.DebugPrintInputEvent(if n < event_n then "Processed" else "Remaining", g.InputEventsQueue[n + 1])
		end
	end

	if event_n == g.InputEventsQueue.Size then
		g.InputEventsQueue:resize(0)
	else
		for _ = 1, event_n do
			g.InputEventsQueue:erase(0)
		end
	end

	if g.IO.AppFocusLost then
		g.IO:ClearInputKeys()
		g.IO:ClearInputMouse()
	end
end

function ImGui.GetKeyOwner(key)
	if not ImGui.IsNamedKeyOrMod(key) then
		return ImGuiKeyOwner.NoOwner
	end

	local g = ImGui.GImGui
	local owner_data = ImGui.GetKeyOwnerData(g, key)
	local owner_id = owner_data.OwnerCurr

	if g.ActiveIdUsingAllKeyboardKeys and owner_id ~= g.ActiveId and owner_id ~= ImGuiKeyOwner.Any then
		if key >= ImGuiKey.Keyboard_BEGIN and key < ImGuiKey.Keyboard_END then
			return ImGuiKeyOwner.NoOwner
		end
	end

	return owner_id
end

function ImGui.TestKeyOwner(key, owner_id)
	if not ImGui.IsNamedKeyOrMod(key) then
		return true
	end

	local g = ImGui.GImGui
	if g.ActiveIdUsingAllKeyboardKeys and owner_id ~= g.ActiveId and owner_id ~= ImGuiKeyOwner.Any then
		if key >= ImGuiKey.Keyboard_BEGIN and key < ImGuiKey.Keyboard_END then
			return false
		end
	end

	local owner_data = ImGui.GetKeyOwnerData(g, key)
	if owner_id == ImGuiKeyOwner.Any then
		return owner_data.LockThisFrame == false
	end

	if owner_data.OwnerCurr ~= owner_id then
		if owner_data.LockThisFrame then
			return false
		end
		if owner_data.OwnerCurr ~= ImGuiKeyOwner.NoOwner then
			return false
		end
	end

	return true
end

function ImGui.SetKeyOwner(key, owner_id, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	assert(
		ImGui.IsNamedKeyOrMod(key)
			and (
				owner_id ~= ImGuiKeyOwner.Any
				or bit32.btest(flags, bit32.bor(ImGuiInputFlags.LockThisFrame, ImGuiInputFlags.LockUntilRelease))
			)
	)
	assert(bit32.band(flags, bit32.bnot(ImGuiInputFlags.SupportedBySetKeyOwner)) == 0)

	local owner_data = ImGui.GetKeyOwnerData(g, key)
	owner_data.OwnerNext = owner_id
	owner_data.OwnerCurr = owner_id

	owner_data.LockUntilRelease = bit32.band(flags, ImGuiInputFlags.LockUntilRelease) ~= 0
	owner_data.LockThisFrame = bit32.band(flags, ImGuiInputFlags.LockThisFrame) ~= 0 or owner_data.LockUntilRelease
end

function ImGui.SetKeyOwnersForKeyChord(key_chord, owner_id, flags)
	if flags == nil then
		flags = 0
	end
	if bit32.btest(key_chord, ImGuiMod.Ctrl) then
		ImGui.SetKeyOwner(ImGuiMod.Ctrl, owner_id, flags)
	end
	if bit32.btest(key_chord, ImGuiMod.Shift) then
		ImGui.SetKeyOwner(ImGuiMod.Shift, owner_id, flags)
	end
	if bit32.btest(key_chord, ImGuiMod.Alt) then
		ImGui.SetKeyOwner(ImGuiMod.Alt, owner_id, flags)
	end
	if bit32.btest(key_chord, ImGuiMod.Super) then
		ImGui.SetKeyOwner(ImGuiMod.Super, owner_id, flags)
	end
	if bit32.btest(key_chord, NOT_MOD_MASK) then
		ImGui.SetKeyOwner(bit32.band(key_chord, NOT_MOD_MASK), owner_id, flags)
	end
end

function ImGui.SetItemKeyOwner(key, flags)
	if flags == nil then
		flags = ImGuiInputFlags.None
	end
	local g = ImGui.GImGui
	local id = g.LastItemData.ID
	if id == 0 or (g.HoveredId ~= id and g.ActiveId ~= id) then
		return false
	end
	if bit32.band(flags, ImGuiInputFlags.CondMask_) == 0 then
		flags = bit32.bor(flags, ImGuiInputFlags.CondDefault_)
	end
	if
		(g.HoveredId == id and bit32.btest(flags, ImGuiInputFlags.CondHovered))
		or (g.ActiveId == id and bit32.btest(flags, ImGuiInputFlags.CondActive))
	then
		assert(bit32.band(flags, bit32.bnot(ImGuiInputFlags.SupportedBySetItemKeyOwner)) == 0)
		if not ImGui.TestKeyOwner(key, id) then
			return false
		end
		ImGui.SetKeyOwner(key, id, bit32.band(flags, bit32.bnot(ImGuiInputFlags.CondMask_)))
		return true
	end
	return false
end

function ImGui.IsKeyChordPressed(key_chord, flags, owner_id)
	if flags == nil then
		flags = ImGuiInputFlags.None
	end
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local g = ImGui.GImGui
	key_chord = ImGui.FixupKeyChord(key_chord)
	local mods = bit32.band(key_chord, ImGuiMod.Mask_)
	if g.IO.KeyMods ~= mods then
		return false
	end

	local key = bit32.band(key_chord, NOT_MOD_MASK)
	if key == ImGuiKey.None then
		key = ImGui.ConvertSingleModFlagToKey(mods)
	end
	if not ImGui.IsKeyPressed(key, bit32.band(flags, ImGuiInputFlags.RepeatMask_), owner_id) then
		return false
	end
	return true
end

function ImGui.SetNextItemShortcut(key_chord, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	g.NextItemData.HasFlags = bit32.bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasShortcut)
	g.NextItemData.Shortcut = key_chord
	g.NextItemData.ShortcutFlags = flags
end

function ImGui.ItemHandleShortcut(id)
	local g = ImGui.GImGui
	local flags = g.NextItemData.ShortcutFlags
	assert(bit32.band(flags, bit32.bnot(ImGuiInputFlags.SupportedBySetNextItemShortcut)) == 0)

	if bit32.btest(g.LastItemData.ItemFlags, ImGuiItemFlags.Disabled) then
		return
	end
	if bit32.btest(flags, ImGuiInputFlags.Tooltip) then
		g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasShortcut)
		g.LastItemData.Shortcut = g.NextItemData.Shortcut
	end
	if not ImGui.Shortcut(g.NextItemData.Shortcut, bit32.band(flags, ImGuiInputFlags.SupportedByShortcut), id) or g.NavActivateId ~= 0 then
		return
	end

	g.NavActivateId = id
	g.NavActivateFlags = bit32.bor(ImGuiActivateFlags.PreferInput, ImGuiActivateFlags.FromShortcut)
	g.NavActivatePressedId = id
	g.NavActivateDownId = id
	ImGui.NavHighlightActivated(id)
end

function ImGui.Shortcut(key_chord, flags, owner_id)
	if flags == nil then
		flags = 0
	end
	if owner_id == nil then
		owner_id = ImGuiKeyOwner.Any
	end
	local g = ImGui.GImGui

	if bit32.band(flags, ImGuiInputFlags.RouteTypeMask_) == 0 then
		flags = bit32.bor(flags, ImGuiInputFlags.RouteFocused)
	end

	if owner_id == ImGuiKeyOwner.Any or owner_id == ImGuiKeyOwner.NoOwner then
		owner_id = ImGui.GetRoutingIdFromOwnerId(owner_id)
	end

	if bit32.btest(g.CurrentItemFlags, ImGuiItemFlags.Disabled) then
		return false
	end

	if not ImGui.SetShortcutRouting(key_chord, flags, owner_id) then
		return false
	end

	if bit32.band(flags, ImGuiInputFlags.Repeat) ~= 0 and bit32.band(flags, ImGuiInputFlags.RepeatUntilMask_) == 0 then
		flags = bit32.bor(flags, ImGuiInputFlags.RepeatUntilKeyModsChange)
	end

	if not ImGui.IsKeyChordPressed(key_chord, flags, owner_id) then
		return false
	end

	ImGui.SetKeyOwnersForKeyChord(bit32.band(key_chord, ImGuiMod.Mask_), owner_id)

	assert(bit32.band(flags, bit32.bnot(ImGuiInputFlags.SupportedByShortcut)) == 0)
	return true
end

return true
