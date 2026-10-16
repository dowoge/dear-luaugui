local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ImGui = require(ReplicatedStorage.ImGui)

local showDemo = true
local counter = 0
local value = 0.5

ImGui.ImplRoblox.Start(function()
	if showDemo then
		showDemo = ImGui.ShowDemoWindow(showDemo)
	end

	ImGui.Begin("Hello, Roblox!")
	ImGui.Text("Dear ImGui %s running in Luau", ImGui.GetVersion())
	local _
	_, showDemo = ImGui.Checkbox("Demo Window", showDemo)
	_, value = ImGui.DragFloat("value", value, 0.01)
	if ImGui.Button("Button") then
		counter += 1
	end
	ImGui.SameLine()
	ImGui.Text("counter = %d", counter)
	ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000 / ImGui.GetIO().Framerate, ImGui.GetIO().Framerate)
	ImGui.End()
end)
