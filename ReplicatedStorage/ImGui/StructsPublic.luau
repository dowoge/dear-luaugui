local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local ImVector = Base.ImVector
local FLT_MAX, IM_PI = Base.FLT_MAX, Base.IM_PI
local ImGuiDir = Enums.ImGuiDir
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiMouseSource = Enums.ImGuiMouseSource
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiKey = Enums.ImGuiKey
local ImGuiCol = Enums.ImGuiCol

local M = {}

local function class(name)
	local c = {}
	c.__index = c
	M[name] = c
	return c
end

local function cloneVector(v, deep)
	local r = table.clone(v)
	if deep then
		for i = 1, v.Size do
			r[i] = v[i]:Copy()
		end
	end
	return r
end

local ImGuiTableSortSpecs = class("ImGuiTableSortSpecs")

function ImGuiTableSortSpecs.new()
	return setmetatable({
		Specs = nil,
		SpecsCount = 0,
		SpecsDirty = false,
	}, ImGuiTableSortSpecs)
end

function ImGuiTableSortSpecs:Copy()
	return table.clone(self)
end

local ImGuiTableColumnSortSpecs = class("ImGuiTableColumnSortSpecs")

function ImGuiTableColumnSortSpecs.new()
	return setmetatable({
		ColumnUserID = 0,
		ColumnIndex = 0,
		SortOrder = 0,
		SortDirection = 0,
	}, ImGuiTableColumnSortSpecs)
end

function ImGuiTableColumnSortSpecs:Copy()
	return table.clone(self)
end

local ImGuiStyle = class("ImGuiStyle")

function ImGuiStyle.new()
	local self = setmetatable({
		FontSizeBase = 0.0,
		FontScaleMain = 1.0,
		FontScaleDpi = 1.0,
		Alpha = 1.0,
		DisabledAlpha = 0.60,
		WindowPadding = ImVec2(8, 8),
		WindowRounding = 0.0,
		WindowBorderSize = 1.0,
		WindowBorderHoverPadding = 4.0,
		WindowMinSize = ImVec2(32, 32),
		WindowTitleAlign = ImVec2(0.0, 0.5),
		WindowMenuButtonPosition = ImGuiDir.Left,
		ChildRounding = 0.0,
		ChildBorderSize = 1.0,
		PopupRounding = 0.0,
		PopupBorderSize = 1.0,
		FramePadding = ImVec2(4, 3),
		FrameRounding = 0.0,
		FrameBorderSize = 0.0,
		ItemSpacing = ImVec2(8, 4),
		ItemInnerSpacing = ImVec2(4, 4),
		CellPadding = ImVec2(4, 2),
		TouchExtraPadding = ImVec2(0, 0),
		IndentSpacing = 21.0,
		ColumnsMinSpacing = 6.0,
		ScrollbarSize = 14.0,
		ScrollbarRounding = 9.0,
		ScrollbarPadding = 2.0,
		GrabMinSize = 12.0,
		GrabRounding = 0.0,
		LogSliderDeadzone = 4.0,
		ImageRounding = 0.0,
		ImageBorderSize = 0.0,
		TabRounding = 5.0,
		TabBorderSize = 0.0,
		TabMinWidthBase = 1.0,
		TabMinWidthShrink = 80.0,
		TabCloseButtonMinWidthSelected = -1.0,
		TabCloseButtonMinWidthUnselected = 0.0,
		TabBarBorderSize = 1.0,
		TabBarOverlineSize = 1.0,
		TableAngledHeadersAngle = 35.0 * (IM_PI / 180.0),
		TableAngledHeadersTextAlign = ImVec2(0.5, 0.0),
		TreeLinesFlags = ImGuiTreeNodeFlags.DrawLinesNone,
		TreeLinesSize = 1.0,
		TreeLinesRounding = 0.0,
		MenuItemRounding = 0.0,
		SelectableRounding = 0.0,
		DragDropTargetRounding = 0.0,
		DragDropTargetBorderSize = 2.0,
		DragDropTargetPadding = 3.0,
		ColorMarkerSize = 3.0,
		ColorButtonPosition = ImGuiDir.Right,
		ButtonTextAlign = ImVec2(0.5, 0.5),
		SelectableTextAlign = ImVec2(0.0, 0.0),
		InputTextCursorSize = 1.0,
		SeparatorSize = 1.0,
		SeparatorTextBorderSize = 3.0,
		SeparatorTextAlign = ImVec2(0.0, 0.5),
		SeparatorTextPadding = ImVec2(20.0, 3.0),
		DisplayWindowPadding = ImVec2(19, 19),
		DisplaySafeAreaPadding = ImVec2(3, 3),
		MouseCursorScale = 1.0,
		AntiAliasedLines = true,
		AntiAliasedLineEnds = false,
		AntiAliasedFill = true,
		CurveTessellationMaxError = 1.12,
		CircleTessellationMaxError = 0.30,
		Colors = table.create(ImGuiCol.COUNT, ImVec4(0, 0, 0, 0)),
		HoverStationaryDelay = 0.15,
		HoverDelayShort = 0.15,
		HoverDelayNormal = 0.40,
		HoverFlagsForTooltipMouse = bit32.bor(ImGuiHoveredFlags.Stationary, ImGuiHoveredFlags.DelayShort, ImGuiHoveredFlags.AllowWhenDisabled),
		HoverFlagsForTooltipNav = bit32.bor(ImGuiHoveredFlags.NoSharedDelay, ImGuiHoveredFlags.DelayNormal, ImGuiHoveredFlags.AllowWhenDisabled),
		_MainScale = 1.0,
		_NextFrameFontSizeBase = 0.0,
	}, ImGuiStyle)
	ImGui.StyleColorsDark(self)
	return self
end

function ImGuiStyle:Copy()
	local r = table.clone(self)
	r.Colors = table.clone(self.Colors)
	return r
end

local ImGuiKeyData = class("ImGuiKeyData")

function ImGuiKeyData.new()
	return setmetatable({
		Down = false,
		DownDuration = 0.0,
		DownDurationPrev = 0.0,
		AnalogValue = 0.0,
	}, ImGuiKeyData)
end

function ImGuiKeyData:Copy()
	return table.clone(self)
end

local ImGuiIO = class("ImGuiIO")

function ImGuiIO.new()
	local n = ImGuiMouseButton.COUNT
	local self = setmetatable({
		ConfigFlags = ImGuiConfigFlags.None,
		BackendFlags = ImGuiBackendFlags.RendererHasTextures,
		DisplaySize = ImVec2(-1.0, -1.0),
		DisplayFramebufferScale = ImVec2(1.0, 1.0),
		DeltaTime = 1.0 / 60.0,
		IniSavingRate = 5.0,
		IniFilename = nil,
		LogFilename = nil,
		UserData = nil,
		Fonts = nil,
		FontDefault = nil,
		FontAllowUserScaling = false,
		ConfigNavSwapGamepadButtons = false,
		ConfigNavMoveSetMousePos = false,
		ConfigNavCaptureKeyboard = true,
		ConfigNavEscapeClearFocusItem = true,
		ConfigNavEscapeClearFocusWindow = false,
		ConfigNavCursorVisibleAuto = true,
		ConfigNavCursorVisibleAlways = false,
		ConfigMacOSXBehaviors = false,
		ConfigInputTrickleEventQueue = true,
		ConfigInputTextCursorBlink = true,
		ConfigInputTextEnterKeepActive = false,
		ConfigColorEditFlags = ImGuiColorEditFlags.DefaultOptions_,
		ConfigDragClickToInputText = false,
		ConfigDragHideCursor = true,
		ConfigWindowsResizeFromEdges = true,
		ConfigWindowsMoveFromTitleBarOnly = false,
		ConfigWindowsCopyContentsWithCtrlC = false,
		ConfigScrollbarScrollByPage = true,
		ConfigIniSettingsSaveLastUsedDate = true,
		ConfigIniSettingsAutoDiscardMonths = 0,
		ConfigDebugIniSettings = false,
		MouseDrawCursor = false,
		ConfigMemoryCompactTimer = 60.0,
		MouseDoubleClickTime = 0.30,
		MouseDoubleClickMaxDist = 6.0,
		MouseSingleClickDelay = 0.50,
		MouseDragThreshold = 6.0,
		KeyRepeatDelay = 0.275,
		KeyRepeatRate = 0.050,
		ConfigErrorRecovery = true,
		ConfigErrorRecoveryEnableAssert = true,
		ConfigErrorRecoveryEnableDebugLog = true,
		ConfigErrorRecoveryEnableTooltip = true,
		ConfigDebugIsDebuggerPresent = false,
		ConfigDebugHighlightIdConflicts = true,
		ConfigDebugHighlightIdConflictsShowItemPicker = true,
		ConfigDebugBeginReturnValueOnce = false,
		ConfigDebugBeginReturnValueLoop = false,
		ConfigDebugIgnoreFocusLoss = false,
		ConfigDebugDrawListDefaultsToStrokeLegacy = false,
		BackendPlatformName = "imgui_impl_roblox",
		BackendRendererName = "imgui_impl_roblox",
		BackendPlatformUserData = nil,
		BackendRendererUserData = nil,
		BackendLanguageUserData = nil,
		WantCaptureMouse = false,
		WantCaptureKeyboard = false,
		WantTextInput = false,
		WantSetMousePos = false,
		WantSaveIniSettings = false,
		NavActive = false,
		NavVisible = false,
		Framerate = 0.0,
		MetricsRenderVertices = 0,
		MetricsRenderIndices = 0,
		MetricsRenderWindows = 0,
		MetricsActiveWindows = 0,
		MouseDelta = ImVec2(0, 0),
		Ctx = nil,
		MousePos = ImVec2(-FLT_MAX, -FLT_MAX),
		MouseDown = table.create(n, false),
		MouseWheel = 0.0,
		MouseWheelH = 0.0,
		MouseSource = ImGuiMouseSource.Mouse,
		KeyCtrl = false,
		KeyShift = false,
		KeyAlt = false,
		KeySuper = false,
		KeyMods = 0,
		KeysData = {},
		WantCaptureMouseUnlessPopupClose = false,
		MousePosPrev = ImVec2(-FLT_MAX, -FLT_MAX),
		MouseClickedPos = table.create(n, ImVec2(0, 0)),
		MouseClickedTime = table.create(n, 0.0),
		MouseClicked = table.create(n, false),
		MouseDoubleClicked = table.create(n, false),
		MouseClickedCount = table.create(n, 0),
		MouseClickedLastCount = table.create(n, 0),
		MouseReleased = table.create(n, false),
		MouseReleasedTime = table.create(n, 0.0),
		MouseDownOwned = table.create(n, false),
		MouseDownOwnedUnlessPopupClose = table.create(n, false),
		MouseWheelRequestAxisSwap = false,
		MouseCtrlLeftAsRightClick = false,
		MouseDownDuration = table.create(n, -1.0),
		MouseDownDurationPrev = table.create(n, -1.0),
		MouseDragMaxDistanceSqr = table.create(n, 0.0),
		PenPressure = 0.0,
		AppFocusLost = false,
		AppAcceptingEvents = true,
		InputQueueSurrogate = 0,
		InputQueueCharacters = ImVector.new(),
		MouseLockFrame = -1,
	}, ImGuiIO)
	for i = 1, ImGuiKey.NamedKey_COUNT do
		local kd = ImGuiKeyData.new()
		kd.DownDuration = -1.0
		kd.DownDurationPrev = -1.0
		self.KeysData[i] = kd
	end
	return self
end

local ioArrayFields = {
	"MouseDown", "MouseClickedPos", "MouseClickedTime", "MouseClicked", "MouseDoubleClicked",
	"MouseClickedCount", "MouseClickedLastCount", "MouseReleased", "MouseReleasedTime",
	"MouseDownOwned", "MouseDownOwnedUnlessPopupClose", "MouseDownDuration", "MouseDownDurationPrev",
	"MouseDragMaxDistanceSqr",
}

function ImGuiIO:Copy()
	local r = table.clone(self)
	for _, k in ioArrayFields do
		r[k] = table.clone(self[k])
	end
	local kd = table.create(#self.KeysData)
	for i, v in self.KeysData do
		kd[i] = v:Copy()
	end
	r.KeysData = kd
	r.InputQueueCharacters = cloneVector(self.InputQueueCharacters, false)
	return r
end

local ImGuiInputTextCallbackData = class("ImGuiInputTextCallbackData")

function ImGuiInputTextCallbackData.new()
	return setmetatable({
		Ctx = nil,
		EventFlag = 0,
		Flags = 0,
		UserData = nil,
		ID = 0,
		EventKey = 0,
		EventChar = 0,
		EventActivated = false,
		BufDirty = false,
		Buf = nil,
		BufTextLen = 0,
		BufSize = 0,
		CursorPos = 0,
		SelectionStart = 0,
		SelectionEnd = 0,
	}, ImGuiInputTextCallbackData)
end

function ImGuiInputTextCallbackData:SelectAll()
	self.SelectionStart = 0
	self.SelectionEnd = self.BufTextLen
	self.CursorPos = self.BufTextLen
end

function ImGuiInputTextCallbackData:SetSelection(s, e)
	assert(s >= 0 and s <= self.BufTextLen)
	assert(e >= 0 and e <= self.BufTextLen)
	self.SelectionStart = s
	self.SelectionEnd = e
	self.CursorPos = e
end

function ImGuiInputTextCallbackData:ClearSelection()
	self.SelectionStart = self.BufTextLen
	self.SelectionEnd = self.BufTextLen
end

function ImGuiInputTextCallbackData:HasSelection()
	return self.SelectionStart ~= self.SelectionEnd
end

function ImGuiInputTextCallbackData:Copy()
	return table.clone(self)
end

local ImGuiSizeCallbackData = class("ImGuiSizeCallbackData")

function ImGuiSizeCallbackData.new()
	return setmetatable({
		UserData = nil,
		Pos = ImVec2(0, 0),
		CurrentSize = ImVec2(0, 0),
		DesiredSize = ImVec2(0, 0),
	}, ImGuiSizeCallbackData)
end

function ImGuiSizeCallbackData:Copy()
	return table.clone(self)
end

local ImGuiPayload = class("ImGuiPayload")

function ImGuiPayload.new()
	local self = setmetatable({}, ImGuiPayload)
	self:Clear()
	return self
end

function ImGuiPayload:Clear()
	self.SourceId = 0
	self.SourceParentId = 0
	self.Data = nil
	self.DataSize = 0
	self.DataType = ""
	self.DataFrameCount = -1
	self.Preview = false
	self.Delivery = false
end

function ImGuiPayload:IsDataType(type)
	return self.DataFrameCount ~= -1 and type == self.DataType
end

function ImGuiPayload:IsPreview()
	return self.Preview
end

function ImGuiPayload:IsDelivery()
	return self.Delivery
end

function ImGuiPayload:Copy()
	return table.clone(self)
end

local ImGuiOnceUponAFrame = class("ImGuiOnceUponAFrame")

function ImGuiOnceUponAFrame.new()
	return setmetatable({ RefFrame = -1 }, ImGuiOnceUponAFrame)
end

function ImGuiOnceUponAFrame:__call()
	local current_frame = ImGui.GetFrameCount()
	if self.RefFrame == current_frame then
		return false
	end
	self.RefFrame = current_frame
	return true
end

function ImGuiOnceUponAFrame:Copy()
	return table.clone(self)
end

local ImGuiStoragePair = class("ImGuiStoragePair")

function ImGuiStoragePair.new(_key, _val)
	local self = setmetatable({ key = _key }, ImGuiStoragePair)
	if type(_val) == "number" then
		self.val_i = _val
		self.val_f = _val
	else
		self.val_p = _val
	end
	return self
end

function ImGuiStoragePair:Copy()
	return table.clone(self)
end

local ImSmallStack_ = class("ImSmallStack_")

function ImSmallStack_.new(capacity)
	return setmetatable({
		LocalData = {},
		Size = 0,
		Capacity = capacity,
	}, ImSmallStack_)
end

function ImSmallStack_:clear()
	self.Size = 0
end

function ImSmallStack_:back()
	assert(self.Size > 0)
	return self.LocalData[self.Size]
end

function ImSmallStack_:push_back(v)
	assert(self.Size < self.Capacity)
	self.LocalData[self.Size + 1] = v
	self.Size += 1
end

function ImSmallStack_:pop_back()
	assert(self.Size > 0)
	self.Size -= 1
end

function ImSmallStack_:capacity()
	return self.Capacity
end

function ImSmallStack_:Copy()
	local r = table.clone(self)
	r.LocalData = table.clone(self.LocalData)
	return r
end

local ImGuiListClipper = class("ImGuiListClipper")

function ImGuiListClipper.new()
	return setmetatable({
		DisplayStart = 0,
		DisplayEnd = 0,
		UserIndex = 0,
		ItemsCount = 0,
		ItemsHeight = 0.0,
		Flags = 0,
		StartPosY = 0.0,
		StartSeekOffsetY = 0.0,
		Ctx = nil,
		TempData = nil,
	}, ImGuiListClipper)
end

function ImGuiListClipper:IncludeItemByIndex(item_index)
	self:IncludeItemsByIndex(item_index, item_index + 1)
end

function ImGuiListClipper:Copy()
	return table.clone(self)
end

local ImColor = class("ImColor")

function ImColor.new(r, g, b, a)
	local value
	if r == nil then
		value = ImVec4(0, 0, 0, 0)
	elseif type(r) == "table" then
		value = r
	elseif g == nil then
		local rgba = r
		local sc = 1.0 / 255.0
		value = ImVec4(
			bit32.band(bit32.rshift(rgba, Base.IM_COL32_R_SHIFT), 0xFF) * sc,
			bit32.band(bit32.rshift(rgba, Base.IM_COL32_G_SHIFT), 0xFF) * sc,
			bit32.band(bit32.rshift(rgba, Base.IM_COL32_B_SHIFT), 0xFF) * sc,
			bit32.band(bit32.rshift(rgba, Base.IM_COL32_A_SHIFT), 0xFF) * sc
		)
	else
		value = ImVec4(r, g, b, if a == nil then 1.0 else a)
	end
	return setmetatable({ Value = value }, ImColor)
end

function ImColor.new_Int(r, g, b, a)
	if a == nil then
		a = 255
	end
	local sc = 1.0 / 255.0
	return setmetatable({ Value = ImVec4(r * sc, g * sc, b * sc, a * sc) }, ImColor)
end

function ImColor:ToImU32()
	return ImGui.ColorConvertFloat4ToU32(self.Value)
end

function ImColor:ToImVec4()
	return self.Value
end

function ImColor:SetHSV(h, s, v, a)
	if a == nil then
		a = 1.0
	end
	local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
	self.Value = ImVec4(r, g, b, a)
end

function ImColor.HSV(h, s, v, a)
	if a == nil then
		a = 1.0
	end
	local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
	return ImColor.new(r, g, b, a)
end

function ImColor:Copy()
	return table.clone(self)
end

local ImGuiSelectionRequest = class("ImGuiSelectionRequest")

function ImGuiSelectionRequest.new(Type, Selected, RangeDirection, RangeFirstItem, RangeLastItem)
	return setmetatable({
		Type = Type or 0,
		Selected = Selected or false,
		RangeDirection = RangeDirection or 0,
		RangeFirstItem = RangeFirstItem or 0,
		RangeLastItem = RangeLastItem or 0,
	}, ImGuiSelectionRequest)
end

function ImGuiSelectionRequest:Copy()
	return table.clone(self)
end

local ImGuiMultiSelectIO = class("ImGuiMultiSelectIO")

function ImGuiMultiSelectIO.new()
	return setmetatable({
		Requests = ImVector.new(),
		RangeSrcItem = 0,
		NavIdItem = 0,
		NavIdSelected = false,
		RangeSrcReset = false,
		ItemsCount = 0,
	}, ImGuiMultiSelectIO)
end

function ImGuiMultiSelectIO:Copy()
	local r = table.clone(self)
	r.Requests = cloneVector(self.Requests, true)
	return r
end

local ImGuiSelectionBasicStorage = class("ImGuiSelectionBasicStorage")

function ImGuiSelectionBasicStorage.new()
	return setmetatable({
		Size = 0,
		PreserveOrder = false,
		UserData = nil,
		AdapterIndexToStorageId = function(_, idx)
			return idx
		end,
		_SelectionOrder = 1,
		_Storage = Base.ImGuiStorage.new(),
	}, ImGuiSelectionBasicStorage)
end

function ImGuiSelectionBasicStorage:GetStorageIdFromIndex(idx)
	return self.AdapterIndexToStorageId(self, idx)
end

function ImGuiSelectionBasicStorage:Copy()
	local r = table.clone(self)
	r._Storage = self._Storage:Copy()
	return r
end

local ImGuiSelectionExternalStorage = class("ImGuiSelectionExternalStorage")

function ImGuiSelectionExternalStorage.new()
	return setmetatable({
		UserData = nil,
		AdapterSetItemSelected = nil,
	}, ImGuiSelectionExternalStorage)
end

function ImGuiSelectionExternalStorage:Copy()
	return table.clone(self)
end

local ImGuiViewport = class("ImGuiViewport")

function ImGuiViewport.new()
	return setmetatable({
		ID = 0,
		Flags = 0,
		Pos = ImVec2(0, 0),
		Size = ImVec2(0, 0),
		FramebufferScale = ImVec2(0, 0),
		WorkPos = ImVec2(0, 0),
		WorkSize = ImVec2(0, 0),
		PlatformHandle = nil,
		PlatformHandleRaw = nil,
	}, ImGuiViewport)
end

function ImGuiViewport:GetCenter()
	return ImVec2(self.Pos.x + self.Size.x * 0.5, self.Pos.y + self.Size.y * 0.5)
end

function ImGuiViewport:GetWorkCenter()
	return ImVec2(self.WorkPos.x + self.WorkSize.x * 0.5, self.WorkPos.y + self.WorkSize.y * 0.5)
end

function ImGuiViewport:Copy()
	return table.clone(self)
end

local ImGuiPlatformIO = class("ImGuiPlatformIO")

function ImGuiPlatformIO.new()
	return setmetatable({
		Platform_GetClipboardTextFn = nil,
		Platform_SetClipboardTextFn = nil,
		Platform_ClipboardUserData = nil,
		Platform_OpenInShellFn = nil,
		Platform_OpenInShellUserData = nil,
		Platform_SetImeDataFn = nil,
		Platform_ImeUserData = nil,
		Platform_LocaleDecimalPoint = string.byte("."),
		Platform_SessionDate = 0,
		Renderer_TextureMaxWidth = 0,
		Renderer_TextureMaxHeight = 0,
		Renderer_RenderState = nil,
		DrawCallback_ResetRenderState = nil,
		DrawCallback_SetSamplerLinear = nil,
		DrawCallback_SetSamplerNearest = nil,
		DrawCallback_SetSamplerFromTex = nil,
		Textures = ImVector.new(),
	}, ImGuiPlatformIO)
end

function ImGuiPlatformIO:Copy()
	local r = table.clone(self)
	r.Textures = cloneVector(self.Textures, false)
	return r
end

local ImGuiPlatformImeData = class("ImGuiPlatformImeData")

function ImGuiPlatformImeData.new()
	return setmetatable({
		WantVisible = false,
		WantTextInput = false,
		InputPos = ImVec2(0, 0),
		InputLineHeight = 0.0,
		ViewportId = 0,
	}, ImGuiPlatformImeData)
end

function ImGuiPlatformImeData:Copy()
	return table.clone(self)
end

return M
