local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")

local ImRect, ImVec2 = Base.ImRect, Base.ImVec2
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiScrollFlags = Enums.ImGuiScrollFlags
local ImGuiNextItemDataFlags = Enums.ImGuiNextItemDataFlags
local ImGuiMouseButton = Enums.ImGuiMouseButton

local inline = {}

function inline.GetCurrentTable()
	return ImGui.GImGui.CurrentTable
end

function inline.TableGetInstanceData(table, instance_no)
	if instance_no == 0 then
		return table.InstanceDataFirst
	end
	return table.InstanceDataExtra[instance_no]
end

function inline.TableGetInstanceID(table, instance_no)
	return ImGui.TableGetInstanceData(table, instance_no).TableInstanceID
end

function inline.GetScale()
	return ImGui.GImGui.Style._MainScale
end

function inline.GetCurrentWindowRead()
	return ImGui.GImGui.CurrentWindow
end

function inline.GetCurrentWindow()
	local g = ImGui.GImGui
	g.CurrentWindow.WriteAccessed = true
	return g.CurrentWindow
end

function inline.SetWindowParentWindowForFocusRoute(window, parent_window)
	window.ParentWindowForFocusRoute = parent_window
end

function inline.WindowRectAbsToRel(window, r)
	local off = window.DC.CursorStartPos
	return ImRect.fromXY(r.Min.x - off.x, r.Min.y - off.y, r.Max.x - off.x, r.Max.y - off.y)
end

function inline.WindowRectRelToAbs(window, r)
	local off = window.DC.CursorStartPos
	return ImRect.fromXY(r.Min.x + off.x, r.Min.y + off.y, r.Max.x + off.x, r.Max.y + off.y)
end

function inline.WindowPosAbsToRel(window, p)
	local off = window.DC.CursorStartPos
	return ImVec2(p.x - off.x, p.y - off.y)
end

function inline.WindowPosRelToAbs(window, p)
	local off = window.DC.CursorStartPos
	return ImVec2(p.x + off.x, p.y + off.y)
end

function inline.GetPixelDensity()
	return ImGui.GImGui.CurrentPixelDensity
end

function inline.GetRoundedFontSize(size)
	return math.floor(size + 0.5)
end

function inline.GetWindowViewport()
	return ImGui.GetMainViewport()
end

function inline.LocalizeGetMsg(key)
	local msg = ImGui.GImGui.LocalizationTable[key + 1]
	return msg or "*Missing Text*"
end

function inline.ScrollToBringRectIntoView(window, rect)
	ImGui.ScrollToRect(window, rect, ImGuiScrollFlags.KeepVisibleEdgeY)
end

function inline.GetItemStatusFlags()
	return ImGui.GImGui.LastItemData.StatusFlags
end

function inline.GetActiveID()
	return ImGui.GImGui.ActiveId
end

function inline.GetFocusID()
	return ImGui.GImGui.NavId
end

function inline.IsNamedKey(key)
	return key >= ImGuiKey.NamedKey_BEGIN and key < ImGuiKey.NamedKey_END
end

function inline.IsNamedKeyOrMod(key)
	return (key >= ImGuiKey.NamedKey_BEGIN and key < ImGuiKey.NamedKey_END) or key == ImGuiMod.Ctrl or key == ImGuiMod.Shift or key == ImGuiMod.Alt or key == ImGuiMod.Super
end

function inline.IsLegacyKey(key)
	return key >= ImGuiKey.LegacyNativeKey_BEGIN and key < ImGuiKey.LegacyNativeKey_END
end

function inline.IsKeyboardKey(key)
	return key >= ImGuiKey.Keyboard_BEGIN and key < ImGuiKey.Keyboard_END
end

function inline.IsGamepadKey(key)
	return key >= ImGuiKey.Gamepad_BEGIN and key < ImGuiKey.Gamepad_END
end

function inline.IsMouseKey(key)
	return key >= ImGuiKey.Mouse_BEGIN and key < ImGuiKey.Mouse_END
end

function inline.IsAliasKey(key)
	return key >= ImGuiKey.Aliases_BEGIN and key < ImGuiKey.Aliases_END
end

function inline.IsLRModKey(key)
	return key >= ImGuiKey.LeftCtrl and key <= ImGuiKey.RightSuper
end

function inline.MouseButtonToKey(button)
	assert(button >= 0 and button < ImGuiMouseButton.COUNT)
	return ImGuiKey.MouseLeft + button
end

function inline.IsActiveIdUsingNavDir(dir)
	return bit32.btest(ImGui.GImGui.ActiveIdUsingNavDirMask, bit32.lshift(1, dir))
end

function inline.GetCurrentFocusScope()
	return ImGui.GImGui.CurrentFocusScopeId
end

function inline.GetBoxSelectState(id)
	local g = ImGui.GImGui
	if id ~= 0 and g.BoxSelectState.ID == id and g.BoxSelectState.IsActive then
		return g.BoxSelectState
	end
	return nil
end

function inline.GetMultiSelectState(id)
	return ImGui.GImGui.MultiSelectStorage:GetByKey(id)
end

function inline.GetCurrentTabBar()
	return ImGui.GImGui.CurrentTabBar
end

function inline.TabBarGetTabOrder(tab_bar, tab)
	return tab_bar.Tabs:index_from_ptr(tab)
end

function inline.RenderNavHighlight(bb, id, flags)
	ImGui.RenderNavCursor(bb, id, flags or 0)
end

function inline.TempInputIsActive(id)
	local g = ImGui.GImGui
	return (g.TempInputId == id and g.ActiveId == id) or (g.InputTextDeactivatedState.ID == id)
end

function inline.GetInputTextState(id)
	local g = ImGui.GImGui
	if id ~= 0 and g.InputTextState.ID == id then
		return g.InputTextState
	end
	return nil
end

function inline.IsItemActiveAsInputText()
	local g = ImGui.GImGui
	return g.ActiveId ~= 0 and g.ActiveId == g.LastItemData.ID and g.InputTextState.ID == g.LastItemData.ID
end

function inline.SetNextItemColorMarker(col)
	local g = ImGui.GImGui
	g.NextItemData.HasFlags = bit32.bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasColorMarker)
	g.NextItemData.ColorMarker = col
end

for name, fn in inline do
	if ImGui[name] == nil then
		ImGui[name] = fn
	end
end

return true
