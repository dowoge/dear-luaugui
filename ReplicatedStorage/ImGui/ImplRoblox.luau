local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local ContextActionService = game:GetService("ContextActionService")

local ImGui = require("./Namespace")
local Enums = require("./Enums")
local DrawList = require("./DrawList")
local Renderer = require("./ImplRobloxRenderer")

local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiMouseSource = Enums.ImGuiMouseSource

local Impl = {}

local KeyMap = {
	[Enum.KeyCode.Tab] = ImGuiKey.Tab,
	[Enum.KeyCode.Left] = ImGuiKey.LeftArrow,
	[Enum.KeyCode.Right] = ImGuiKey.RightArrow,
	[Enum.KeyCode.Up] = ImGuiKey.UpArrow,
	[Enum.KeyCode.Down] = ImGuiKey.DownArrow,
	[Enum.KeyCode.PageUp] = ImGuiKey.PageUp,
	[Enum.KeyCode.PageDown] = ImGuiKey.PageDown,
	[Enum.KeyCode.Home] = ImGuiKey.Home,
	[Enum.KeyCode.End] = ImGuiKey.End,
	[Enum.KeyCode.Insert] = ImGuiKey.Insert,
	[Enum.KeyCode.Delete] = ImGuiKey.Delete,
	[Enum.KeyCode.Backspace] = ImGuiKey.Backspace,
	[Enum.KeyCode.Space] = ImGuiKey.Space,
	[Enum.KeyCode.Return] = ImGuiKey.Enter,
	[Enum.KeyCode.Escape] = ImGuiKey.Escape,
	[Enum.KeyCode.LeftControl] = ImGuiKey.LeftCtrl,
	[Enum.KeyCode.LeftShift] = ImGuiKey.LeftShift,
	[Enum.KeyCode.LeftAlt] = ImGuiKey.LeftAlt,
	[Enum.KeyCode.LeftSuper] = ImGuiKey.LeftSuper,
	[Enum.KeyCode.LeftMeta] = ImGuiKey.LeftSuper,
	[Enum.KeyCode.RightControl] = ImGuiKey.RightCtrl,
	[Enum.KeyCode.RightShift] = ImGuiKey.RightShift,
	[Enum.KeyCode.RightAlt] = ImGuiKey.RightAlt,
	[Enum.KeyCode.RightSuper] = ImGuiKey.RightSuper,
	[Enum.KeyCode.RightMeta] = ImGuiKey.RightSuper,
	[Enum.KeyCode.Menu] = ImGuiKey.Menu,
	[Enum.KeyCode.Quote] = ImGuiKey.Apostrophe,
	[Enum.KeyCode.Comma] = ImGuiKey.Comma,
	[Enum.KeyCode.Minus] = ImGuiKey.Minus,
	[Enum.KeyCode.Period] = ImGuiKey.Period,
	[Enum.KeyCode.Slash] = ImGuiKey.Slash,
	[Enum.KeyCode.Semicolon] = ImGuiKey.Semicolon,
	[Enum.KeyCode.Equals] = ImGuiKey.Equal,
	[Enum.KeyCode.LeftBracket] = ImGuiKey.LeftBracket,
	[Enum.KeyCode.BackSlash] = ImGuiKey.Backslash,
	[Enum.KeyCode.RightBracket] = ImGuiKey.RightBracket,
	[Enum.KeyCode.Backquote] = ImGuiKey.GraveAccent,
	[Enum.KeyCode.CapsLock] = ImGuiKey.CapsLock,
	[Enum.KeyCode.ScrollLock] = ImGuiKey.ScrollLock,
	[Enum.KeyCode.NumLock] = ImGuiKey.NumLock,
	[Enum.KeyCode.Print] = ImGuiKey.PrintScreen,
	[Enum.KeyCode.Pause] = ImGuiKey.Pause,
	[Enum.KeyCode.KeypadPeriod] = ImGuiKey.KeypadDecimal,
	[Enum.KeyCode.KeypadDivide] = ImGuiKey.KeypadDivide,
	[Enum.KeyCode.KeypadMultiply] = ImGuiKey.KeypadMultiply,
	[Enum.KeyCode.KeypadMinus] = ImGuiKey.KeypadSubtract,
	[Enum.KeyCode.KeypadPlus] = ImGuiKey.KeypadAdd,
	[Enum.KeyCode.KeypadEnter] = ImGuiKey.KeypadEnter,
	[Enum.KeyCode.KeypadEquals] = ImGuiKey.KeypadEqual,
	[Enum.KeyCode.ButtonStart] = ImGuiKey.GamepadStart,
	[Enum.KeyCode.ButtonSelect] = ImGuiKey.GamepadBack,
	[Enum.KeyCode.ButtonX] = ImGuiKey.GamepadFaceLeft,
	[Enum.KeyCode.ButtonB] = ImGuiKey.GamepadFaceRight,
	[Enum.KeyCode.ButtonY] = ImGuiKey.GamepadFaceUp,
	[Enum.KeyCode.ButtonA] = ImGuiKey.GamepadFaceDown,
	[Enum.KeyCode.DPadLeft] = ImGuiKey.GamepadDpadLeft,
	[Enum.KeyCode.DPadRight] = ImGuiKey.GamepadDpadRight,
	[Enum.KeyCode.DPadUp] = ImGuiKey.GamepadDpadUp,
	[Enum.KeyCode.DPadDown] = ImGuiKey.GamepadDpadDown,
	[Enum.KeyCode.ButtonL1] = ImGuiKey.GamepadL1,
	[Enum.KeyCode.ButtonR1] = ImGuiKey.GamepadR1,
	[Enum.KeyCode.ButtonL3] = ImGuiKey.GamepadL3,
	[Enum.KeyCode.ButtonR3] = ImGuiKey.GamepadR3,
}

do
	local digits = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
	for i, name in digits do
		KeyMap[Enum.KeyCode[name]] = ImGuiKey[tostring(i - 1)]
		KeyMap[Enum.KeyCode["Keypad" .. name]] = ImGuiKey["Keypad" .. (i - 1)]
	end
	for c = string.byte("A"), string.byte("Z") do
		local ch = string.char(c)
		KeyMap[Enum.KeyCode[ch]] = ImGuiKey[ch]
	end
	for n = 1, 15 do
		KeyMap[Enum.KeyCode["F" .. n]] = ImGuiKey["F" .. n]
	end
end

local MouseButtonMap = {
	[Enum.UserInputType.MouseButton1] = 0,
	[Enum.UserInputType.MouseButton2] = 1,
	[Enum.UserInputType.MouseButton3] = 2,
}

local CursorIcons = {
	[ImGuiMouseCursor.Arrow] = "",
	[ImGuiMouseCursor.TextInput] = "rbxasset://SystemCursors/IBeam",
	[ImGuiMouseCursor.ResizeAll] = "rbxasset://SystemCursors/SizeAll",
	[ImGuiMouseCursor.ResizeNS] = "rbxasset://SystemCursors/SizeNS",
	[ImGuiMouseCursor.ResizeEW] = "rbxasset://SystemCursors/SizeEW",
	[ImGuiMouseCursor.ResizeNESW] = "rbxasset://SystemCursors/SizeNESW",
	[ImGuiMouseCursor.ResizeNWSE] = "rbxasset://SystemCursors/SizeNWSE",
	[ImGuiMouseCursor.Hand] = "rbxasset://SystemCursors/PointingHand",
	[ImGuiMouseCursor.Wait] = "rbxasset://SystemCursors/Wait",
	[ImGuiMouseCursor.Progress] = "rbxasset://SystemCursors/Busy",
	[ImGuiMouseCursor.NotAllowed] = "rbxasset://SystemCursors/Forbidden",
}

local metricsCache = {}
function Impl.MeasureCodeAdvance(size)
	local s = math.max(1, math.floor(size + 0.5))
	local v = metricsCache[s]
	if v == nil then
		v = TextService:GetTextSize(string.rep("M", 64), s, Enum.Font.Code, Vector2.new(1e6, 1e6)).X / 64
		metricsCache[s] = v
	end
	return v
end

local SINK_ACTION = "ImGuiImplRobloxSink"

local state = nil

local function addKey(io, key, down)
	io:AddKeyEvent(key, down)
end

local function updateModifiers(io)
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
	local super = UserInputService:IsKeyDown(Enum.KeyCode.LeftSuper) or UserInputService:IsKeyDown(Enum.KeyCode.RightSuper)
		or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta) or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
	io:AddKeyEvent(ImGuiMod.Ctrl, ctrl)
	io:AddKeyEvent(ImGuiMod.Shift, shift)
	io:AddKeyEvent(ImGuiMod.Alt, alt)
	io:AddKeyEvent(ImGuiMod.Super, super)
end

local function selectedText(g)
	local st = g.InputTextState
	if st == nil or st.ID == 0 or st.ID ~= g.ActiveId or st.Stb == nil or st.TextA == nil then
		return ""
	end
	local a, b = st.Stb.select_start, st.Stb.select_end
	if a == b then
		return ""
	end
	if a > b then
		a, b = b, a
	end
	return string.sub(st.TextA, a + 1, b)
end

local function syncTextBox(g)
	local tb = state.TextBox
	local sentinel = selectedText(g)
	state.Sentinel = sentinel
	state.IgnoreTextChange = true
	tb.Text = sentinel
	if sentinel ~= "" then
		tb.SelectionStart = 1
		tb.CursorPosition = #sentinel + 1
	else
		tb.CursorPosition = 1
		tb.SelectionStart = -1
	end
	state.IgnoreTextChange = false
end

local function onTextChanged()
	if state.IgnoreTextChange then
		return
	end
	local tb = state.TextBox
	local text = tb.Text
	if text == state.Sentinel then
		return
	end
	local io = ImGui.GetIO()
	local sentinel = state.Sentinel
	local inserted = text
	if sentinel ~= "" and string.sub(text, 1, #sentinel) == sentinel and #text > #sentinel then
		inserted = string.sub(text, #sentinel + 1)
	elseif #text < #sentinel then
		inserted = ""
	end
	if inserted ~= "" then
		if state.PendingPaste and #inserted > 1 then
			state.PendingPaste = false
			ImGui.SetClipboardText(inserted)
			io:AddKeyEvent(ImGuiMod.Ctrl, true)
			io:AddKeyEvent(ImGuiKey.V, true)
			io:AddKeyEvent(ImGuiKey.V, false)
		else
			inserted = string.gsub(inserted, "[%c]", "")
			if inserted ~= "" then
				io:AddInputCharactersUTF8(inserted)
			end
		end
	end
	state.NeedResync = true
end

local function sinkAction(_, inputState, input)
	if state == nil then
		return Enum.ContextActionResult.Pass
	end
	local io = ImGui.GetIO()
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if io.WantCaptureMouse then
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	if io.WantCaptureMouse and inputState == Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function Impl.Init(options)
	options = options or {}
	assert(state == nil, "ImplRoblox already initialized")
	local io = ImGui.GetIO()
	io.BackendPlatformName = "imgui_impl_roblox"
	io.BackendRendererName = "imgui_impl_roblox"
	io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.HasMouseCursors)

	local parent = options.Parent or Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = options.Name or "DearImGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = options.DisplayOrder or 1000
	gui.ScreenInsets = Enum.ScreenInsets.None

	local tb = Instance.new("TextBox")
	tb.Name = "TextInputSink"
	tb.BackgroundTransparency = 1
	tb.TextTransparency = 1
	tb.TextSize = 1
	tb.Size = UDim2.fromOffset(1, 1)
	tb.Position = UDim2.fromOffset(-10, -10)
	tb.ClearTextOnFocus = false
	tb.MultiLine = true
	tb.TextEditable = true
	tb.Text = ""
	tb.ZIndex = 0
	tb.Parent = gui

	state = {
		Gui = gui,
		TextBox = tb,
		Sentinel = "",
		IgnoreTextChange = false,
		NeedResync = true,
		PendingPaste = false,
		Connections = {},
		MouseLocked = false,
		LockPos = Vector2.zero,
		VirtualPos = Vector2.zero,
		LastCursor = nil,
		TextInputActive = false,
		WindowFocused = true,
	}
	state.Renderer = Renderer.new(gui)
	state.Renderer.MeasureAdvance = Impl.MeasureCodeAdvance
	DrawList.AdvanceForSize = Impl.MeasureCodeAdvance
	DrawList.ImFont.RobloxFontFace = Font.fromEnum(Enum.Font.Code)

	local conns = state.Connections
	table.insert(conns, tb:GetPropertyChangedSignal("Text"):Connect(onTextChanged))
	table.insert(conns, tb.FocusLost:Connect(function(enterPressed)
		state.TextBoxFocused = false
		if enterPressed then
			local io2 = ImGui.GetIO()
			io2:AddKeyEvent(ImGuiKey.Enter, true)
			io2:AddKeyEvent(ImGuiKey.Enter, false)
		end
	end))
	table.insert(conns, tb.Focused:Connect(function()
		state.TextBoxFocused = true
	end))

	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		local io2 = ImGui.GetIO()
		local t = input.UserInputType
		local button = MouseButtonMap[t]
		if button ~= nil then
			io2:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
			io2:AddMouseButtonEvent(button, true)
			return
		end
		if t == Enum.UserInputType.Keyboard or t.Name:sub(1, 7) == "Gamepad" then
			local key = KeyMap[input.KeyCode]
			if key ~= nil then
				updateModifiers(io2)
				if input.KeyCode == Enum.KeyCode.V and state.TextInputActive and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
					state.PendingPaste = true
					return
				end
				addKey(io2, key, true)
			end
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		local io2 = ImGui.GetIO()
		local t = input.UserInputType
		local button = MouseButtonMap[t]
		if button ~= nil then
			io2:AddMouseButtonEvent(button, false)
			return
		end
		if t == Enum.UserInputType.Keyboard or t.Name:sub(1, 7) == "Gamepad" then
			local key = KeyMap[input.KeyCode]
			if key ~= nil then
				updateModifiers(io2)
				addKey(io2, key, false)
			end
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		local io2 = ImGui.GetIO()
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseWheel then
			io2:AddMouseWheelEvent(0, input.Position.Z)
		elseif t == Enum.UserInputType.MouseMovement then
			if state.MouseLocked then
				local d = input.Delta
				state.VirtualPos += Vector2.new(d.X, d.Y)
			end
		elseif t == Enum.UserInputType.Gamepad1 then
			local kc = input.KeyCode
			if kc == Enum.KeyCode.ButtonL2 or kc == Enum.KeyCode.ButtonR2 then
				local key = kc == Enum.KeyCode.ButtonL2 and ImGuiKey.GamepadL2 or ImGuiKey.GamepadR2
				local v = input.Position.Z
				io2:AddKeyAnalogEvent(key, v > 0.1, v)
			elseif kc == Enum.KeyCode.Thumbstick1 or kc == Enum.KeyCode.Thumbstick2 then
				local p = input.Position
				local left = kc == Enum.KeyCode.Thumbstick1
				local function axis(neg, pos, v)
					local dead = 0.2
					local nv = math.clamp((-v - dead) / (1 - dead), 0, 1)
					local pv = math.clamp((v - dead) / (1 - dead), 0, 1)
					io2:AddKeyAnalogEvent(neg, nv > 0.1, nv)
					io2:AddKeyAnalogEvent(pos, pv > 0.1, pv)
				end
				if left then
					axis(ImGuiKey.GamepadLStickLeft, ImGuiKey.GamepadLStickRight, p.X)
					axis(ImGuiKey.GamepadLStickDown, ImGuiKey.GamepadLStickUp, p.Y)
				else
					axis(ImGuiKey.GamepadRStickLeft, ImGuiKey.GamepadRStickRight, p.X)
					axis(ImGuiKey.GamepadRStickDown, ImGuiKey.GamepadRStickUp, p.Y)
				end
			end
		end
	end))
	table.insert(conns, UserInputService.WindowFocused:Connect(function()
		ImGui.GetIO():AddFocusEvent(true)
	end))
	table.insert(conns, UserInputService.WindowFocusReleased:Connect(function()
		ImGui.GetIO():AddFocusEvent(false)
	end))

	ContextActionService:BindActionAtPriority(SINK_ACTION, sinkAction, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.UserInputType.MouseWheel, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3)

	local platform = ImGui.GetPlatformIO()
	platform.Platform_SetImeDataFn = function(_, _, data)
		if data ~= nil and data.WantVisible then
			state.ImePos = data.InputPos
			state.ImeLineHeight = data.InputLineHeight
		end
	end

	gui.Parent = parent
end

function Impl.Shutdown()
	if state == nil then
		return
	end
	for _, c in state.Connections do
		c:Disconnect()
	end
	ContextActionService:UnbindAction(SINK_ACTION)
	if state.MouseLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	UserInputService.MouseIconEnabled = true
	UserInputService.MouseIcon = ""
	state.Renderer:Destroy()
	state.Gui:Destroy()
	state = nil
end

function Impl.NewFrame(dt)
	state.FrameStart = os.clock()
	local io = ImGui.GetIO()
	local g = ImGui.GImGui
	local cam = workspace.CurrentCamera
	local size = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local guiSize = state.Gui.AbsoluteSize
	if guiSize.X > 0 and guiSize.Y > 0 then
		size = guiSize
	end
	io.DisplaySize = vector.create(size.X, size.Y, 0)
	io.DisplayFramebufferScale = vector.create(1, 1, 0)
	io.DeltaTime = (dt and dt > 0) and dt or (1 / 60)

	local lockRequested = io.MouseLockFrame >= g.FrameCount and io.ConfigDragHideCursor
	if lockRequested and not state.MouseLocked then
		state.MouseLocked = true
		state.LockPos = UserInputService:GetMouseLocation()
		state.VirtualPos = state.LockPos
	elseif not lockRequested and state.MouseLocked then
		state.MouseLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	if state.MouseLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UserInputService.MouseIconEnabled = false
		io:AddMousePosEvent(state.VirtualPos.X, state.VirtualPos.Y)
	else
		local p = UserInputService:GetMouseLocation()
		if state.WindowFocused ~= false then
			io:AddMousePosEvent(p.X, p.Y)
		end
	end

	local wantText = io.WantTextInput
	if wantText ~= state.TextInputActive then
		state.TextInputActive = wantText
		state.NeedResync = true
		if wantText then
			state.TextBox:CaptureFocus()
		else
			state.TextBox:ReleaseFocus(false)
		end
	elseif wantText and not state.TextBox:IsFocused() then
		state.TextBox:CaptureFocus()
	end
	if wantText then
		local sel = selectedText(g)
		if state.NeedResync or sel ~= state.Sentinel then
			state.NeedResync = false
			syncTextBox(g)
		end
		if state.ImePos then
			state.TextBox.Position = UDim2.fromOffset(state.ImePos.x, state.ImePos.y)
		end
	end
end

function Impl.RenderDrawData(drawData)
	local io = ImGui.GetIO()
	local g = ImGui.GImGui
	if not state.MouseLocked then
		local cursor = ImGui.GetMouseCursor()
		if io.MouseDrawCursor or bit32.btest(io.ConfigFlags, Enums.ImGuiConfigFlags.NoMouseCursorChange) then
			cursor = nil
		end
		if cursor ~= state.LastCursor then
			state.LastCursor = cursor
			if cursor == ImGuiMouseCursor.None then
				UserInputService.MouseIconEnabled = false
			elseif cursor ~= nil then
				UserInputService.MouseIconEnabled = true
				UserInputService.MouseIcon = CursorIcons[cursor] or ""
			end
		end
	else
		state.LastCursor = ImGuiMouseCursor.None
	end
	local t0 = os.clock()
	state.Renderer:Render(drawData, g)
	local t1 = os.clock()
	if state.FrameStart then
		state.Gui:SetAttribute("ImGuiFrameMs", (t0 - state.FrameStart) * 1000)
	end
	state.Gui:SetAttribute("RenderMs", (t1 - t0) * 1000)
end

local RENDER_STEP_NAME = "DearImGui"

function Impl.Start(drawFn, options)
	options = options or {}
	if ImGui.GetCurrentContext() == nil then
		ImGui.CreateContext()
	end
	if state == nil then
		Impl.Init(options)
	end
	local Structs = require("./Structs")
	local recoveryState = Structs.ImGuiErrorRecoveryState.new()
	local stepName = options.RenderStepName or RENDER_STEP_NAME
	RunService:BindToRenderStep(stepName, options.RenderPriority or Enum.RenderPriority.Last.Value, function(dt)
		Impl.NewFrame(dt)
		ImGui.NewFrame()
		ImGui.ErrorRecoveryStoreState(recoveryState)
		local ok, err = xpcall(drawFn, debug.traceback, dt)
		if not ok then
			warn(err)
			local io = ImGui.GetIO()
			local assertsEnabled = io.ConfigErrorRecoveryEnableAssert
			io.ConfigErrorRecoveryEnableAssert = false
			ImGui.ErrorRecoveryTryToRecoverState(recoveryState)
			io.ConfigErrorRecoveryEnableAssert = assertsEnabled
		end
		ImGui.Render()
		Impl.RenderDrawData(ImGui.GetDrawData())
	end)
	return function()
		RunService:UnbindFromRenderStep(stepName)
		Impl.Shutdown()
	end
end

function Impl.GetScreenGui()
	return state and state.Gui
end

return Impl
