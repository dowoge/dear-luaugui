local ImGui = require("@self/Namespace")
local Base = require("@self/Base")
local Enums = require("@self/Enums")
local Structs = require("@self/Structs")
local DrawList = require("@self/DrawList")

require("@self/CoreInit")
require("@self/CoreMainA")
require("@self/CoreMainB")
require("@self/CoreIdInput")
require("@self/CoreItemLayout")
require("@self/CoreNav")
require("@self/CoreMisc")
require("@self/CoreDebug")
require("@self/WidgetsMain")
require("@self/WidgetsDragSlider")
require("@self/WidgetsInputText")
require("@self/WidgetsColorTree")
require("@self/WidgetsSelect")
require("@self/WidgetsMenuTab")
require("@self/TablesA")
require("@self/TablesB")
require("@self/InternalInline")
require("@self/Demo1")
require("@self/Demo2")
require("@self/Demo3")
require("@self/Demo4")
require("@self/Demo5")
require("@self/Demo6")

ImGui.Enums = Enums
ImGui.Base = Base
ImGui.Structs = Structs
ImGui.DrawListModule = DrawList
ImGui.ImVec2 = Base.ImVec2
ImGui.ImVec4 = Base.ImVec4
ImGui.ImRect = Base.ImRect
ImGui.IM_COL32 = Base.IM_COL32
for groupName, group in Enums do
	if ImGui[groupName] == nil then
		ImGui[groupName] = group
	end
	local short = string.match(groupName, "^ImGui(.+)$")
	if short and ImGui[short] == nil then
		ImGui[short] = group
	end
end

if game ~= nil then
	ImGui.ImplRoblox = require("@self/ImplRoblox")
end

return ImGui
