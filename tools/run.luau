local t0 = os.clock()
local ImGui = require("@ImGui")
local Demo = ImGui._Demo

local args = { ... }
local mode = args[1] or "basic"
local frames = tonumber(args[2]) or 60
local seed = tonumber(args[3]) or 1
local big = args[4] == "big"

ImGui.CreateContext()
local io = ImGui.GetIO()
io.DisplaySize = if big then vector.create(3000, 60000, 0) else vector.create(1600, 1000, 0)
io.DeltaTime = 1 / 60

local openAll = mode == "openall" or mode == "fuzzall"
local fuzz = mode == "fuzz" or mode == "fuzzall"
local tools = mode ~= "basic" and mode ~= "fuzz"

if openAll then
	local orig = ImGui.TreeNodeUpdateNextOpen
	ImGui.TreeNodeUpdateNextOpen = function(...)
		local r = orig(...)
		local w = ImGui.GImGui.CurrentWindow
		local name = w and w.RootWindow and w.RootWindow.Name or ""
		if string.find(name, "Metrics", 1, true) or string.find(name, "ID Stack", 1, true) or string.find(name, "Debug Log", 1, true) then
			return r
		end
		return true
	end
end

local apps = {
	"ShowExampleAppMainMenuBar", "ShowExampleAppConsole", "ShowExampleAppLog", "ShowExampleAppLayout",
	"ShowExampleAppPropertyEditor", "ShowExampleAppLongText", "ShowExampleAppAutoResize",
	"ShowExampleAppConstrainedResize", "ShowExampleAppSimpleOverlay", "ShowExampleAppFullscreen",
	"ShowExampleAppWindowTitles", "ShowExampleAppCustomRendering", "ShowExampleAppDocuments",
	"ShowExampleAppAssetsBrowser", "ShowExampleAppImageViewer",
}

local demoData = {}
math.randomseed(seed)
local mx, my = 100, 100
local down = false
for frame = 1, frames do
	if fuzz then
		local r = math.random()
		if r < 0.5 then
			mx = math.clamp(mx + math.random(-60, 60), 0, io.DisplaySize.x)
			my = math.clamp(my + math.random(-60, 60), 0, math.min(io.DisplaySize.y, 4000))
		elseif r < 0.6 then
			mx, my = math.random(0, io.DisplaySize.x), math.random(0, math.min(io.DisplaySize.y, 4000))
		end
		io:AddMousePosEvent(mx, my)
		if math.random() < 0.15 then
			down = not down
			io:AddMouseButtonEvent(0, down)
		end
		if math.random() < 0.03 then
			io:AddMouseButtonEvent(1, true)
			io:AddMouseButtonEvent(1, false)
		end
		if math.random() < 0.05 then
			io:AddMouseWheelEvent(0, math.random(-2, 2))
		end
		if math.random() < 0.05 then
			io:AddInputCharactersUTF8("ab1")
		end
	end
	ImGui.NewFrame()
	ImGui.ShowDemoWindow(true)
	if tools then
		ImGui.ShowMetricsWindow(true)
		ImGui.ShowDebugLogWindow(true)
		ImGui.ShowIDStackToolWindow(true)
		ImGui.Begin("Style Editor")
		ImGui.ShowStyleEditor()
		ImGui.End()
		ImGui.ShowUserGuide()
		ImGui.ShowAboutWindow(true)
		for _, name in apps do
			if Demo[name] then
				Demo[name](true, demoData)
			end
		end
	end
	if big and frame == 2 then
		ImGui.SetWindowPos("Dear ImGui Demo", vector.create(0, 0, 0))
		ImGui.SetWindowSize("Dear ImGui Demo", vector.create(2900, 59000, 0))
	end
	ImGui.Render()
end

local dd = ImGui.GetDrawData()
local prims = 0
for i = 1, dd.CmdLists.Size do
	prims += dd.CmdLists[i]:GetPrimCount()
end
print(string.format("PASS %s %d %d%s windows=%d prims=%d time=%.2fs", mode, frames, seed, if big then " big" else "", ImGui.GImGui.Windows.Size, prims, os.clock() - t0))
