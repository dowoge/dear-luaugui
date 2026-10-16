local Base = require("./Base")
local Enums = require("./Enums")

local ImVec2, ImVec4, ImRect, ImVector = Base.ImVec2, Base.ImVec4, Base.ImRect, Base.ImVector
local FLT_MAX = Base.FLT_MAX
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiDir = Enums.ImGuiDir
local ImGuiCol = Enums.ImGuiCol
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiSortDirection = Enums.ImGuiSortDirection
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiNavLayer = Enums.ImGuiNavLayer

local V0 = vector.create(0, 0, 0)
local SelectionUserData_Invalid = -1

local function Public()
	return require("./StructsPublic")
end

local function DrawListModule()
	return require("./DrawList")
end

local ImVectorMeta

local function CloneStruct(v)
	if v.Copy then
		return v:Copy()
	end
	if ImVectorMeta == nil then
		ImVectorMeta = getmetatable(ImVector.new())
	end
	local n = table.clone(v)
	for k, x in v do
		if type(x) == "table" and getmetatable(x) == ImVectorMeta then
			n[k] = table.clone(x)
		end
	end
	return n
end

local function CopyWith(src, spec)
	local dst = table.clone(src)
	if spec then
		for k, kind in spec do
			local v = src[k]
			if v ~= nil then
				if kind == "S" then
					dst[k] = CloneStruct(v)
				else
					local n = table.clone(v)
					if kind == "D" then
						for i = 1, v.Size or #v do
							if v[i] ~= nil then
								n[i] = CloneStruct(v[i])
							end
						end
					end
					dst[k] = n
				end
			end
		end
	end
	return dst
end

local function Class(spec)
	local C = {}
	C.__index = C
	function C:Copy()
		return CopyWith(self, spec)
	end
	return C
end

local ImVec1 = Class()
function ImVec1.new(x)
	return setmetatable({ x = x or 0 }, ImVec1)
end

local ImVec2i = {}
function ImVec2i.new(x, y)
	return vector.create(x or 0, y or 0, 0)
end

local ImVec2ih = {}
function ImVec2ih.new(x, y)
	if type(x) == "vector" then
		return vector.create(Base.ImTruncToInt(x.x), Base.ImTruncToInt(x.y), 0)
	end
	return vector.create(x or 0, y or 0, 0)
end

local ImGuiTextFilterItem = Class()
function ImGuiTextFilterItem.new(b, e)
	assert(e > b)
	return setmetatable({ Begin = b, Len = e - b, CountInclude = 0, MatchIncludesMask = 0 }, ImGuiTextFilterItem)
end

local ImGuiPackedDate = Class()
function ImGuiPackedDate.new(yyyymmdd)
	local self = setmetatable({ Year = 0, Month = 0, Day = 0 }, ImGuiPackedDate)
	if yyyymmdd ~= nil then
		self.Year = bit32.band(yyyymmdd // 10000 - 2000, 0x7F)
		self.Month = bit32.band((yyyymmdd // 100) % 100, 0xF)
		self.Day = bit32.band(yyyymmdd % 100, 0x1F)
	end
	return self
end
function ImGuiPackedDate:IsValid()
	return self.Year ~= 0 and self.Month ~= 0 and self.Day ~= 0
end
function ImGuiPackedDate:Unpack()
	if self.Year ~= 0 and self.Month ~= 0 and self.Day ~= 0 then
		return ((self.Year + 2000) * 10000) + (self.Month * 100) + self.Day
	end
	return 0
end
function ImGuiPackedDate:SubtractMonths(m)
	while m > 0 do
		self.Year = bit32.band(self.Year - (self.Month == 1 and 1 or 0), 0x7F)
		self.Month = if self.Month == 1 then 12 else bit32.band(self.Month - 1, 0xF)
		m -= 1
	end
end

local ImFontStackData = Class()
function ImFontStackData.new(font, size_before_scaling, size_after_scaling)
	return setmetatable({
		Font = font,
		FontSizeBeforeScaling = size_before_scaling or 0,
		FontSizeAfterScaling = size_after_scaling or 0,
	}, ImFontStackData)
end

local ImGuiStyleVarInfo = Class()
function ImGuiStyleVarInfo.new(count, data_type, offset)
	return setmetatable({ Count = count or 0, DataType = data_type or 0, Offset = offset or 0 }, ImGuiStyleVarInfo)
end
function ImGuiStyleVarInfo:GetVarPtr(parent)
	return parent[self.Offset]
end

local ImGuiColorMod = Class()
function ImGuiColorMod.new(col, backup_value)
	return setmetatable({ Col = col or 0, BackupValue = backup_value or ImVec4(0, 0, 0, 0) }, ImGuiColorMod)
end

local ImGuiStyleMod = {}
ImGuiStyleMod.__index = ImGuiStyleMod
function ImGuiStyleMod.new(idx, v)
	local backup = { 0, 0 }
	if type(v) == "vector" then
		backup[1] = v.x
		backup[2] = v.y
	elseif v ~= nil then
		backup[1] = v
	end
	return setmetatable({ VarIdx = idx, BackupInt = backup, BackupFloat = backup }, ImGuiStyleMod)
end
function ImGuiStyleMod:Copy()
	local backup = table.clone(self.BackupFloat)
	local dst = table.clone(self)
	dst.BackupInt = backup
	dst.BackupFloat = backup
	return dst
end

local ImGuiDataTypeStorage = Class()
function ImGuiDataTypeStorage.new()
	return setmetatable({ Data = 0 }, ImGuiDataTypeStorage)
end

local ImGuiDataTypeInfo = Class()
function ImGuiDataTypeInfo.new(size, name, print_fmt, scan_fmt)
	return setmetatable({ Size = size or 0, Name = name, PrintFmt = print_fmt, ScanFmt = scan_fmt }, ImGuiDataTypeInfo)
end

local ImGuiComboPreviewData = Class()
function ImGuiComboPreviewData.new()
	return setmetatable({
		PreviewRect = ImRect.new(),
		BackupCursorPos = V0,
		BackupCursorMaxPos = V0,
		BackupCursorPosPrevLine = V0,
		BackupPrevLineTextBaseOffset = 0,
		BackupWorkRectMaxX = 0,
		BackupContentRectMaxX = 0,
		BackupLayout = 0,
		WithinPreview = false,
	}, ImGuiComboPreviewData)
end

local ImGuiGroupData = Class({ BackupIndent = "S", BackupGroupOffset = "S" })
function ImGuiGroupData.new()
	return setmetatable({
		WindowID = 0,
		BackupCursorPos = V0,
		BackupCursorMaxPos = V0,
		BackupCursorPosPrevLine = V0,
		BackupIndent = ImVec1.new(),
		BackupGroupOffset = ImVec1.new(),
		BackupCurrLineSize = V0,
		BackupCurrLineTextBaseOffset = 0,
		BackupActiveIdIsAlive = 0,
		BackupAnyIdHasBeenEditedThisFrame = false,
		BackupDeactivatedIdIsAlive = false,
		BackupHoveredIdIsAlive = false,
		BackupIsSameLine = false,
		EmitItem = false,
	}, ImGuiGroupData)
end

local ImGuiMenuColumns = Class({ Widths = "C" })
function ImGuiMenuColumns.new()
	return setmetatable({
		TotalWidth = 0,
		NextTotalWidth = 0,
		Spacing = 0,
		OffsetIcon = 0,
		OffsetLabel = 0,
		OffsetShortcut = 0,
		OffsetMark = 0,
		Widths = { 0, 0, 0, 0 },
	}, ImGuiMenuColumns)
end

local ImGuiInputTextDeactivatedState = Class()
function ImGuiInputTextDeactivatedState.new()
	return setmetatable({ ID = 0, ElapseFrame = 0, TextA = "" }, ImGuiInputTextDeactivatedState)
end
function ImGuiInputTextDeactivatedState:ClearFreeMemory()
	self.ID = 0
	self.ElapseFrame = 0
	self.TextA = ""
end

local ImGuiInputTextState = Class()
function ImGuiInputTextState.new()
	return setmetatable({
		Ctx = nil,
		Stb = nil,
		Flags = 0,
		ID = 0,
		TextLen = 0,
		TextSrc = nil,
		TextA = "",
		TextToRevertTo = "",
		CallbackTextBackup = "",
		BufCapacity = 0,
		Scroll = V0,
		LineCount = 0,
		WrapWidth = 0,
		CursorAnim = 0,
		CursorFollow = false,
		CursorCenterY = false,
		SelectedAllMouseLock = false,
		EditedBefore = false,
		EditedThisFrame = false,
		ValidatedThisFrame = false,
		WantReloadUserBuf = false,
		LastMoveDirectionLR = 0,
		ReloadSelectionStart = 0,
		ReloadSelectionEnd = 0,
	}, ImGuiInputTextState)
end
function ImGuiInputTextState:ClearText()
	self.TextLen = 0
	self.TextA = ""
	self:CursorClamp()
end
function ImGuiInputTextState:ClearFreeMemory()
	self.TextA = ""
	self.TextToRevertTo = ""
end
function ImGuiInputTextState:GetText()
	return self.TextA or ""
end

local ImGuiNextWindowData = Class()
function ImGuiNextWindowData.new()
	return setmetatable({
		HasFlags = 0,
		PosCond = 0,
		SizeCond = 0,
		CollapsedCond = 0,
		PosVal = V0,
		PosPivotVal = V0,
		SizeVal = V0,
		ContentSizeVal = V0,
		ScrollVal = V0,
		WindowFlagsSet = 0,
		WindowFlagsClear = 0,
		ChildFlagsSet = 0,
		ChildFlagsClear = 0,
		CollapsedVal = false,
		SizeConstraintRect = ImRect.new(),
		SizeCallback = nil,
		SizeCallbackUserData = nil,
		BgAlphaVal = 0,
		MenuBarOffsetMinVal = V0,
		RefreshFlagsVal = 0,
	}, ImGuiNextWindowData)
end
function ImGuiNextWindowData:ClearFlags()
	self.HasFlags = 0
end

local ImGuiNextItemData = Class()
function ImGuiNextItemData.new()
	return setmetatable({
		HasFlags = 0,
		ItemFlagsSet = 0,
		FocusScopeId = 0,
		SelectionUserData = -1,
		Width = 0,
		Shortcut = 0,
		ShortcutFlags = 0,
		OpenVal = false,
		OpenCond = 0,
		RefVal = 0,
		StorageId = 0,
		ColorMarker = 0,
	}, ImGuiNextItemData)
end
function ImGuiNextItemData:ClearFlags()
	self.HasFlags = 0
	self.ItemFlagsSet = 0
end

local ImGuiLastItemData = Class()
function ImGuiLastItemData.new()
	return setmetatable({
		ID = 0,
		ItemFlags = 0,
		StatusFlags = 0,
		Rect = ImRect.new(),
		NavRect = ImRect.new(),
		DisplayRect = ImRect.new(),
		ClipRect = ImRect.new(),
		Shortcut = 0,
	}, ImGuiLastItemData)
end

local ImGuiTreeNodeStackData = Class()
function ImGuiTreeNodeStackData.new()
	return setmetatable({
		ID = 0,
		TreeFlags = 0,
		ItemFlags = 0,
		NavRect = ImRect.new(),
		DrawLinesX1 = 0,
		DrawLinesToNodesY2 = 0,
		DrawLinesTableColumn = 0,
	}, ImGuiTreeNodeStackData)
end

local ImGuiErrorRecoveryState = Class()
function ImGuiErrorRecoveryState.new()
	return setmetatable({
		SizeOfWindowStack = 0,
		SizeOfIDStack = 0,
		SizeOfTreeStack = 0,
		SizeOfColorStack = 0,
		SizeOfStyleVarStack = 0,
		SizeOfFontStack = 0,
		SizeOfFocusScopeStack = 0,
		SizeOfGroupStack = 0,
		SizeOfItemFlagsStack = 0,
		SizeOfBeginPopupStack = 0,
		SizeOfDisabledStack = 0,
	}, ImGuiErrorRecoveryState)
end

local ImGuiWindowStackData = Class({ ParentLastItemDataBackup = "S", StackSizesInBegin = "S" })
function ImGuiWindowStackData.new()
	return setmetatable({
		Window = nil,
		ParentLastItemDataBackup = ImGuiLastItemData.new(),
		StackSizesInBegin = ImGuiErrorRecoveryState.new(),
		DisabledOverrideReenable = false,
		DisabledOverrideReenableAlphaBackup = 0,
		ParentLastComboPreviewRect = ImRect.new(),
	}, ImGuiWindowStackData)
end

local ImGuiShrinkWidthItem = Class()
function ImGuiShrinkWidthItem.new()
	return setmetatable({ Index = 0, Width = 0, InitialWidth = 0 }, ImGuiShrinkWidthItem)
end

local ImGuiPtrOrIndex = Class()
function ImGuiPtrOrIndex.new(ptr_or_index)
	if type(ptr_or_index) == "number" then
		return setmetatable({ Ptr = nil, Index = ptr_or_index }, ImGuiPtrOrIndex)
	end
	return setmetatable({ Ptr = ptr_or_index, Index = -1 }, ImGuiPtrOrIndex)
end

local ImGuiDeactivatedItemData = Class()
function ImGuiDeactivatedItemData.new()
	return setmetatable({ ID = 0, ElapseFrame = 0, HasBeenEditedBefore = false, IsAlive = false }, ImGuiDeactivatedItemData)
end

local ImGuiPopupData = Class()
function ImGuiPopupData.new()
	return setmetatable({
		PopupId = 0,
		Window = nil,
		RestoreNavWindow = nil,
		ParentNavLayer = -1,
		OpenFrameCount = -1,
		OpenParentId = 0,
		OpenPopupPos = V0,
		OpenMousePos = V0,
	}, ImGuiPopupData)
end

local ImGuiInputEvent = Class({ MousePos = "C", MouseWheel = "C", MouseButton = "C", Key = "C", Text = "C", AppFocused = "C" })
function ImGuiInputEvent.new()
	return setmetatable({
		Type = 0,
		Source = 0,
		EventId = 0,
		MousePos = { PosX = 0, PosY = 0, MouseSource = 0 },
		MouseWheel = { WheelX = 0, WheelY = 0, MouseSource = 0 },
		MouseButton = { Button = 0, Down = false, MouseSource = 0 },
		Key = { Key = 0, Down = false, AnalogValue = 0 },
		Text = { Char = 0 },
		AppFocused = { Focused = false },
		AddedByTestEngine = false,
	}, ImGuiInputEvent)
end

local ImGuiKeyRoutingData = Class()
function ImGuiKeyRoutingData.new()
	return setmetatable({
		NextEntryIndex = -1,
		Mods = 0,
		RoutingCurrScore = 0,
		RoutingNextScore = 0,
		RoutingCurr = ImGuiKeyOwner.NoOwner,
		RoutingNext = ImGuiKeyOwner.NoOwner,
	}, ImGuiKeyRoutingData)
end

local ImGuiKeyRoutingTable = Class({ Index = "C", Entries = "D", EntriesNext = "D" })
function ImGuiKeyRoutingTable.new()
	local self = setmetatable({ Index = {}, Entries = ImVector.new(), EntriesNext = ImVector.new() }, ImGuiKeyRoutingTable)
	self:Clear()
	return self
end
function ImGuiKeyRoutingTable:Clear()
	local index = self.Index
	for n = 1, ImGuiKey.NamedKey_COUNT do
		index[n] = -1
	end
	self.Entries:clear()
	self.EntriesNext:clear()
end

local ImGuiKeyOwnerData = Class()
function ImGuiKeyOwnerData.new()
	return setmetatable({
		OwnerCurr = ImGuiKeyOwner.NoOwner,
		OwnerNext = ImGuiKeyOwner.NoOwner,
		LockThisFrame = false,
		LockUntilRelease = false,
	}, ImGuiKeyOwnerData)
end

local ImGuiListClipperRange = Class()
function ImGuiListClipperRange.new(min, max, pos_to_index_convert, pos_to_index_offset_min, pos_to_index_offset_max)
	return setmetatable({
		Min = min or 0,
		Max = max or 0,
		PosToIndexConvert = pos_to_index_convert or false,
		PosToIndexOffsetMin = pos_to_index_offset_min or 0,
		PosToIndexOffsetMax = pos_to_index_offset_max or 0,
	}, ImGuiListClipperRange)
end
function ImGuiListClipperRange.FromIndices(min, max)
	return ImGuiListClipperRange.new(min, max, false, 0, 0)
end
function ImGuiListClipperRange.FromPositions(y1, y2, off_min, off_max)
	return ImGuiListClipperRange.new(Base.ImTruncToInt(y1), Base.ImTruncToInt(y2), true, off_min, off_max)
end

local ImGuiListClipperData = Class({ Ranges = "D" })
function ImGuiListClipperData.new()
	return setmetatable({
		ListClipper = nil,
		LossynessOffset = 0,
		StepNo = 0,
		ItemsFrozen = 0,
		Ranges = ImVector.new(),
	}, ImGuiListClipperData)
end
function ImGuiListClipperData:Reset(clipper)
	self.ListClipper = clipper
	self.StepNo = 0
	self.ItemsFrozen = 0
	self.Ranges:resize(0)
end

local ImGuiNavItemData = Class()
function ImGuiNavItemData.new()
	local self = setmetatable({ RectRel = ImRect.new() }, ImGuiNavItemData)
	self:Clear()
	return self
end
function ImGuiNavItemData:Clear()
	self.Window = nil
	self.ID = 0
	self.FocusScopeId = 0
	self.ItemFlags = 0
	self.SelectionUserData = -1
	self.DistBox = FLT_MAX
	self.DistCenter = FLT_MAX
	self.DistAxial = FLT_MAX
end

local ImGuiFocusScopeData = Class()
function ImGuiFocusScopeData.new(id, window_id)
	return setmetatable({ ID = id or 0, WindowID = window_id or 0 }, ImGuiFocusScopeData)
end

local ImGuiTypingSelectRequest = Class()
function ImGuiTypingSelectRequest.new()
	return setmetatable({
		Flags = 0,
		SearchBufferLen = 0,
		SearchBuffer = nil,
		SelectRequest = false,
		SingleCharMode = false,
		SingleCharSize = 0,
	}, ImGuiTypingSelectRequest)
end

local ImGuiTypingSelectState = Class({ Request = "S" })
function ImGuiTypingSelectState.new()
	return setmetatable({
		Request = ImGuiTypingSelectRequest.new(),
		SearchBuffer = "",
		FocusScope = 0,
		LastRequestFrame = 0,
		LastRequestTime = 0,
		SingleCharModeLock = false,
	}, ImGuiTypingSelectState)
end
function ImGuiTypingSelectState:Clear()
	self.SearchBuffer = ""
	self.SingleCharModeLock = false
end

local ImGuiOldColumnData = Class()
function ImGuiOldColumnData.new()
	return setmetatable({
		OffsetNorm = 0,
		OffsetNormBeforeResize = 0,
		Flags = 0,
		ClipRect = ImRect.new(),
	}, ImGuiOldColumnData)
end

local ImGuiOldColumns = Class({ Columns = "D", Splitter = "S" })
function ImGuiOldColumns.new()
	return setmetatable({
		ID = 0,
		Flags = 0,
		IsFirstFrame = false,
		IsBeingResized = false,
		Current = 0,
		Count = 0,
		OffMinX = 0,
		OffMaxX = 0,
		LineMinY = 0,
		LineMaxY = 0,
		HostCursorPosY = 0,
		HostCursorMaxPosX = 0,
		HostInitialClipRect = ImRect.new(),
		HostBackupClipRect = ImRect.new(),
		HostBackupParentWorkRect = ImRect.new(),
		Columns = ImVector.new(),
		Splitter = DrawListModule().ImDrawListSplitter.new(),
	}, ImGuiOldColumns)
end

local ImGuiBoxSelectState = Class({ UnclipRects = "C" })
function ImGuiBoxSelectState.new()
	return setmetatable({
		ID = 0,
		IsActive = false,
		IsStarting = false,
		IsStartedFromVoid = false,
		IsStartedSetNavIdOnce = false,
		RequestClear = false,
		KeyMods = 0,
		StartPosRel = V0,
		EndPosRel = V0,
		ScrollAccum = V0,
		Window = nil,
		UnclipMode = false,
		UnclipRect = ImRect.new(),
		UnclipRects = { ImRect.new(), ImRect.new() },
		BoxSelectRectPrev = ImRect.new(),
		BoxSelectRectCurr = ImRect.new(),
	}, ImGuiBoxSelectState)
end

local ImGuiMultiSelectTempData = Class({ IO = "S" })
function ImGuiMultiSelectTempData.new()
	local self = setmetatable({ IO = Public().ImGuiMultiSelectIO.new() }, ImGuiMultiSelectTempData)
	self:Clear()
	return self
end
function ImGuiMultiSelectTempData:Clear()
	self:ClearIO()
	self.Storage = nil
	self.FocusScopeId = 0
	self.Flags = 0
	self.ScopeRectMin = V0
	self.BackupCursorMaxPos = V0
	self.BoxSelectId = 0
	self.KeyMods = 0
	self.LoopRequestSetAll = 0
	self.IsEndIO = false
	self.IsFocused = false
	self.IsKeyboardSetRange = false
	self.NavIdPassedBy = false
	self.RangeSrcPassedBy = false
	self.RangeDstPassedBy = false
	self.IsSoleOrUnknownSelectionSize = false
end
function ImGuiMultiSelectTempData:ClearIO()
	local io = self.IO
	io.Requests:resize(0)
	io.RangeSrcItem = SelectionUserData_Invalid
	io.NavIdItem = SelectionUserData_Invalid
	io.NavIdSelected = false
	io.RangeSrcReset = false
end

local ImGuiMultiSelectState = Class()
function ImGuiMultiSelectState.new()
	return setmetatable({
		Window = nil,
		ID = 0,
		LastFrameActive = 0,
		LastSelectionSize = 0,
		RangeSelected = -1,
		NavIdSelected = -1,
		RangeSrcItem = SelectionUserData_Invalid,
		NavIdItem = SelectionUserData_Invalid,
	}, ImGuiMultiSelectState)
end

local ImGuiViewportP = Class({
	BgFgDrawLists = "C",
	BgFgDrawListsLastFrameActive = "C",
	BgFgDrawListsLastTimeActive = "C",
	DrawDataP = "S",
	DrawDataBuilder = "S",
})
setmetatable(ImGuiViewportP, {
	__index = function(_, k)
		return Public().ImGuiViewport[k]
	end,
})
function ImGuiViewportP.new()
	local DL = DrawListModule()
	local self = setmetatable(Public().ImGuiViewport.new(), ImGuiViewportP)
	self.BgFgDrawLists = {}
	self.BgFgDrawListsLastFrameActive = { -1, -1 }
	self.BgFgDrawListsLastTimeActive = { -1, -1 }
	self.DrawDataP = DL.ImDrawData.new()
	self.DrawDataBuilder = DL.ImDrawDataBuilder.new()
	self.WorkInsetMin = V0
	self.WorkInsetMax = V0
	self.BuildWorkInsetMin = V0
	self.BuildWorkInsetMax = V0
	return self
end
function ImGuiViewportP:CalcWorkRectPos(inset_min)
	return ImVec2(self.Pos.x + inset_min.x, self.Pos.y + inset_min.y)
end
function ImGuiViewportP:CalcWorkRectSize(inset_min, inset_max)
	return ImVec2(math.max(0, self.Size.x - inset_min.x - inset_max.x), math.max(0, self.Size.y - inset_min.y - inset_max.y))
end
function ImGuiViewportP:UpdateWorkRect()
	self.WorkPos = self:CalcWorkRectPos(self.WorkInsetMin)
	self.WorkSize = self:CalcWorkRectSize(self.WorkInsetMin, self.WorkInsetMax)
end
function ImGuiViewportP:GetMainRect()
	return ImRect.fromXY(self.Pos.x, self.Pos.y, self.Pos.x + self.Size.x, self.Pos.y + self.Size.y)
end
function ImGuiViewportP:GetWorkRect()
	return ImRect.fromXY(self.WorkPos.x, self.WorkPos.y, self.WorkPos.x + self.WorkSize.x, self.WorkPos.y + self.WorkSize.y)
end
function ImGuiViewportP:GetBuildWorkRect()
	local pos = self:CalcWorkRectPos(self.BuildWorkInsetMin)
	local size = self:CalcWorkRectSize(self.BuildWorkInsetMin, self.BuildWorkInsetMax)
	return ImRect.fromXY(pos.x, pos.y, pos.x + size.x, pos.y + size.y)
end

local ImGuiWindowSettings = Class({ LastUsedDate = "S" })
function ImGuiWindowSettings.new()
	return setmetatable({
		ID = 0,
		Pos = V0,
		Size = V0,
		LastUsedDate = ImGuiPackedDate.new(),
		Collapsed = false,
		IsChild = false,
		WantApply = false,
		WantDelete = false,
		Name = "",
	}, ImGuiWindowSettings)
end
function ImGuiWindowSettings:GetName()
	return self.Name
end

local ImGuiSettingsCleanupArgs = Class()
function ImGuiSettingsCleanupArgs.new()
	return setmetatable({
		TypeHashFilter = 0,
		DiscardOlderThanMonths = 0,
		DiscardWhenMissingDate = false,
		DiscardAll = false,
		SetCurrentSessionDateToAll = false,
		SetCurrentSessionDateWhenMissingDate = false,
		_DiscardOlderThanDate = 0,
	}, ImGuiSettingsCleanupArgs)
end

local ImGuiSettingsHandler = Class()
function ImGuiSettingsHandler.new()
	return setmetatable({
		TypeName = nil,
		TypeHash = 0,
		ClearAllFn = nil,
		ReadInitFn = nil,
		ReadOpenFn = nil,
		ReadLineFn = nil,
		ApplyAllFn = nil,
		WriteAllFn = nil,
		CleanupFn = nil,
		UserData = nil,
	}, ImGuiSettingsHandler)
end

local ImGuiLocEntry = Class()
function ImGuiLocEntry.new(key, text)
	return setmetatable({ Key = key or 0, Text = text }, ImGuiLocEntry)
end

local ImGuiDebugAllocEntry = Class()
function ImGuiDebugAllocEntry.new()
	return setmetatable({ FrameCount = 0, AllocCount = 0, FreeCount = 0 }, ImGuiDebugAllocEntry)
end

local ImGuiDebugAllocInfo = Class({ LastEntriesBuf = "D" })
function ImGuiDebugAllocInfo.new()
	local buf = {}
	for i = 1, 6 do
		buf[i] = ImGuiDebugAllocEntry.new()
	end
	return setmetatable({ TotalAllocCount = 0, TotalFreeCount = 0, LastEntriesIdx = 0, LastEntriesBuf = buf }, ImGuiDebugAllocInfo)
end

local ImGuiMetricsConfig = Class()
function ImGuiMetricsConfig.new()
	return setmetatable({
		ShowDebugLog = false,
		ShowIDStackTool = false,
		ShowWindowsRects = false,
		ShowWindowsBeginOrder = false,
		ShowTablesRects = false,
		ShowDrawCmdMesh = true,
		ShowDrawCmdBoundingBoxes = true,
		ShowTextEncodingViewer = false,
		ShowTextureUsedRect = false,
		ShowWindowsRectsType = -1,
		ShowTablesRectsType = -1,
		HighlightMonitorIdx = -1,
		HighlightViewportID = 0,
		SettingsDiscardMonths = 6,
		SettingsHighlightOldEntries = false,
		ShowFontPreview = true,
	}, ImGuiMetricsConfig)
end

local ImGuiStackLevelInfo = Class()
function ImGuiStackLevelInfo.new()
	return setmetatable({
		ID = 0,
		QueryFrameCount = 0,
		QuerySuccess = false,
		DataType = -1,
		DescOffset = -1,
	}, ImGuiStackLevelInfo)
end

local ImGuiDebugItemPathQuery = Class({ Results = "D", ResultsDescBuf = "S", ResultPathBuf = "S" })
function ImGuiDebugItemPathQuery.new()
	return setmetatable({
		MainID = 0,
		Active = false,
		Complete = false,
		Step = 0,
		Results = ImVector.new(),
		ResultsDescBuf = Base.ImGuiTextBuffer.new(),
		ResultPathBuf = Base.ImGuiTextBuffer.new(),
	}, ImGuiDebugItemPathQuery)
end

local ImGuiIDStackTool = Class()
function ImGuiIDStackTool.new()
	return setmetatable({
		OptHexEncodeNonAsciiChars = true,
		OptCopyToClipboardOnCtrlC = false,
		LastActiveFrame = -1,
		CopyToClipboardLastTime = -FLT_MAX,
	}, ImGuiIDStackTool)
end

local ImGuiContextHook = Class()
function ImGuiContextHook.new()
	return setmetatable({ HookId = 0, Type = 0, Owner = 0, Callback = nil, UserData = nil }, ImGuiContextHook)
end

local ImGuiWindowTempData = Class({
	Indent = "S",
	ColumnsOffset = "S",
	GroupOffset = "S",
	MenuColumns = "S",
	ChildWindows = "C",
	ItemWidthStack = "C",
	TextWrapPosStack = "C",
})
function ImGuiWindowTempData.new()
	return setmetatable({
		CursorPos = V0,
		CursorPosPrevLine = V0,
		CursorStartPos = V0,
		CursorMaxPos = V0,
		IdealMaxPos = V0,
		CurrLineSize = V0,
		PrevLineSize = V0,
		CurrLineTextBaseOffset = 0,
		PrevLineTextBaseOffset = 0,
		IsSameLine = false,
		IsSetPos = false,
		Indent = ImVec1.new(),
		ColumnsOffset = ImVec1.new(),
		GroupOffset = ImVec1.new(),
		CursorStartPosLossyness = V0,
		NavLayerCurrent = 0,
		NavLayersActiveMask = 0,
		NavLayersActiveMaskNext = 0,
		NavIsScrollPushableX = false,
		NavHideHighlightOneFrame = false,
		NavWindowHasScrollY = false,
		MenuBarAppending = false,
		MenuBarOffset = V0,
		MenuColumns = ImGuiMenuColumns.new(),
		TreeDepth = 0,
		TreeHasStackDataDepthMask = 0,
		TreeRecordsClippedNodesY2Mask = 0,
		ChildWindows = ImVector.new(),
		StateStorage = nil,
		CurrentColumns = nil,
		CurrentTableIdx = 0,
		LayoutType = 0,
		ParentLayoutType = 0,
		ModalDimBgColor = 0,
		WindowItemStatusFlags = 0,
		ChildItemStatusFlags = 0,
		ItemWidth = 0,
		ItemWidthDefault = 0,
		TextWrapPos = 0,
		ItemWidthStack = ImVector.new(),
		TextWrapPosStack = ImVector.new(),
	}, ImGuiWindowTempData)
end

local ImGuiWindow = Class({
	IDStack = "C",
	DC = "S",
	StateStorage = "S",
	ColumnsStorage = "D",
	DrawListInst = "S",
	NavLastIds = "C",
	NavRectRel = "C",
	NavPreferredScoringPosRel = "C",
})
function ImGuiWindow.new(ctx, name)
	local self = setmetatable({
		Ctx = ctx,
		Name = name,
		ID = 0,
		Flags = 0,
		ChildFlags = 0,
		Viewport = nil,
		Pos = V0,
		Size = V0,
		SizeFull = V0,
		ContentSize = V0,
		ContentSizeIdeal = V0,
		ContentSizeExplicit = V0,
		WindowPadding = V0,
		WindowRounding = 0,
		WindowBorderSize = 0,
		TitleBarHeight = 0,
		MenuBarHeight = 0,
		DecoOuterSizeX1 = 0,
		DecoOuterSizeY1 = 0,
		DecoOuterSizeX2 = 0,
		DecoOuterSizeY2 = 0,
		DecoInnerSizeX1 = 0,
		DecoInnerSizeY1 = 0,
		NameBufLen = #name + 1,
		MoveId = 0,
		ChildId = 0,
		PopupId = 0,
		Scroll = V0,
		ScrollMax = V0,
		ScrollTarget = ImVec2(FLT_MAX, FLT_MAX),
		ScrollTargetCenterRatio = ImVec2(0.5, 0.5),
		ScrollTargetEdgeSnapDist = V0,
		ScrollbarSizes = V0,
		ScrollbarX = false,
		ScrollbarY = false,
		ScrollbarXStabilizeEnabled = false,
		ScrollbarXStabilizeToggledHistory = 0,
		Active = false,
		WasActive = false,
		WriteAccessed = false,
		Collapsed = false,
		WantCollapseToggle = false,
		SkipItems = false,
		SkipRefresh = false,
		Appearing = false,
		Hidden = false,
		IsFallbackWindow = false,
		IsExplicitChild = false,
		HasCloseButton = false,
		ResizeBorderHovered = 0,
		ResizeBorderHeld = 0,
		BeginCount = 0,
		BeginCountPreviousFrame = 0,
		BeginOrderWithinParent = 0,
		BeginOrderWithinContext = 0,
		FocusOrder = 0,
		AutoPosLastDirection = ImGuiDir.None,
		AutoFitFramesX = -1,
		AutoFitFramesY = -1,
		AutoFitOnlyGrows = false,
		HiddenFramesCanSkipItems = 0,
		HiddenFramesCannotSkipItems = 0,
		HiddenFramesForRenderOnly = 0,
		DisableInputsFrames = 0,
		BgClickFlags = 0,
		SetWindowPosAllowFlags = 0,
		SetWindowSizeAllowFlags = 0,
		SetWindowCollapsedAllowFlags = 0,
		SetWindowPosVal = ImVec2(FLT_MAX, FLT_MAX),
		SetWindowPosPivot = ImVec2(FLT_MAX, FLT_MAX),
		IDStack = ImVector.new(),
		DC = ImGuiWindowTempData.new(),
		OuterRectClipped = ImRect.new(),
		InnerRect = ImRect.new(),
		InnerClipRect = ImRect.new(),
		WorkRect = ImRect.new(),
		ParentWorkRect = ImRect.new(),
		ClipRect = ImRect.new(),
		ContentRegionRect = ImRect.new(),
		HitTestHoleSize = V0,
		HitTestHoleOffset = V0,
		LastFrameActive = -1,
		LastTimeActive = -1,
		StateStorage = Base.ImGuiStorage.new(),
		ColumnsStorage = ImVector.new(),
		FontWindowScale = 1,
		FontWindowScaleParents = 1,
		FontRefSize = 0,
		SettingsOffset = -1,
		DrawList = nil,
		DrawListInst = nil,
		ParentWindow = nil,
		ParentWindowInBeginStack = nil,
		RootWindow = nil,
		RootWindowPopupTree = nil,
		RootWindowForTitleBarHighlight = nil,
		RootWindowForNav = nil,
		ParentWindowForFocusRoute = nil,
		NavLastChildNavWindow = nil,
		NavLastIds = { 0, 0 },
		NavRectRel = { ImRect.new(), ImRect.new() },
		NavPreferredScoringPosRel = { ImVec2(FLT_MAX, FLT_MAX), ImVec2(FLT_MAX, FLT_MAX) },
		NavRootFocusScopeId = 0,
		MemoryDrawListIdxCapacity = 0,
		MemoryDrawListVtxCapacity = 0,
		MemoryCompacted = false,
	}, ImGuiWindow)
	self.ID = Base.ImHashStr(name)
	self.IDStack:push_back(self.ID)
	self.MoveId = self:GetID("#MOVE")
	self.DrawListInst = DrawListModule().ImDrawList.new(ctx.DrawListSharedData)
	self.DrawList = self.DrawListInst
	self.DrawList._OwnerName = self.Name
	return self
end
function ImGuiWindow:Rect()
	return ImRect.fromXY(self.Pos.x, self.Pos.y, self.Pos.x + self.Size.x, self.Pos.y + self.Size.y)
end
function ImGuiWindow:TitleBarRect()
	return ImRect.new(self.Pos, ImVec2(self.Pos.x + self.SizeFull.x, self.Pos.y + self.TitleBarHeight))
end
function ImGuiWindow:MenuBarRect()
	local y1 = self.Pos.y + self.TitleBarHeight
	return ImRect.fromXY(self.Pos.x, y1, self.Pos.x + self.SizeFull.x, y1 + self.MenuBarHeight)
end

local ImGuiTabItem = Class()
function ImGuiTabItem.new()
	return setmetatable({
		ID = 0,
		Flags = 0,
		LastFrameVisible = -1,
		LastFrameSelected = -1,
		Offset = 0,
		Width = 0,
		ContentWidth = 0,
		RequestedWidth = -1,
		NameOffset = -1,
		BeginOrder = -1,
		IndexDuringLayout = -1,
		WantClose = false,
	}, ImGuiTabItem)
end

local ImGuiTabBar = Class({ Tabs = "D", TabsNames = "S" })
function ImGuiTabBar.new()
	return setmetatable({
		Window = nil,
		Tabs = ImVector.new(),
		Flags = 0,
		ID = 0,
		SelectedTabId = 0,
		NextSelectedTabId = 0,
		NextScrollToTabId = 0,
		VisibleTabId = 0,
		CurrFrameVisible = -1,
		PrevFrameVisible = -1,
		BarRect = ImRect.new(),
		BarRectPrevWidth = 0,
		CurrTabsContentsHeight = 0,
		PrevTabsContentsHeight = 0,
		WidthAllTabs = 0,
		WidthAllTabsIdeal = 0,
		ScrollingAnim = 0,
		ScrollingTarget = 0,
		ScrollingTargetDistToVisibility = 0,
		ScrollingSpeed = 0,
		ScrollingRectMinX = 0,
		ScrollingRectMaxX = 0,
		SeparatorMinX = 0,
		SeparatorMaxX = 0,
		ReorderRequestTabId = 0,
		ReorderRequestOffset = 0,
		BeginCount = 0,
		WantLayout = false,
		VisibleTabWasSubmitted = false,
		TabsAddedNew = false,
		ScrollButtonEnabled = false,
		TabsActiveCount = 0,
		LastTabItemIdx = -1,
		ItemSpacingY = 0,
		FramePadding = V0,
		BackupCursorPos = V0,
		TabsNames = Base.ImGuiTextBuffer.new(),
	}, ImGuiTabBar)
end

local ImGuiTableColumn = Class()
function ImGuiTableColumn.new()
	return setmetatable({
		Flags = 0,
		WidthGiven = 0,
		MinX = 0,
		MaxX = 0,
		WidthRequest = -1,
		WidthAuto = 0,
		WidthMax = 0,
		StretchWeight = -1,
		InitStretchWeightOrWidth = 0,
		ClipRect = ImRect.new(),
		ID = 0,
		UserData = 0,
		WorkMinX = 0,
		WorkMaxX = 0,
		ItemWidth = 0,
		ContentMaxXFrozen = 0,
		ContentMaxXUnfrozen = 0,
		ContentMaxXHeadersUsed = 0,
		ContentMaxXHeadersIdeal = 0,
		NameOffset = -1,
		DisplayOrder = -1,
		IndexWithinEnabledSet = -1,
		PrevEnabledColumn = -1,
		NextEnabledColumn = -1,
		SortOrder = -1,
		DrawChannelCurrent = 255,
		DrawChannelFrozen = 255,
		DrawChannelUnfrozen = 255,
		IsEnabled = false,
		IsUserEnabled = false,
		IsUserEnabledNextFrame = false,
		IsVisibleX = false,
		IsVisibleY = false,
		IsRequestOutput = false,
		IsSkipItems = false,
		IsPreserveWidthAuto = false,
		IsJustCreated = true,
		IsLoadedSettings = false,
		IsNeedReconcileSrc = false,
		IsNeedReconcileDst = false,
		NavLayerCurrent = 0,
		AutoFitQueue = 0,
		CannotSkipItemsQueue = 0,
		SortDirection = ImGuiSortDirection.None,
		SortDirectionsAvailCount = 0,
		SortDirectionsAvailMask = 0,
		SortDirectionsAvailList = 0,
	}, ImGuiTableColumn)
end

local ImGuiTableReconcileColumnData = Class({ ColumnOldData = "S" })
function ImGuiTableReconcileColumnData.new()
	return setmetatable({
		ID = 0,
		NameOffset = 0,
		Flags = 0,
		InitWidthOrWeight = 0,
		UserData = 0,
		ColumnNewIdx = 0,
		ColumnOldIdx = 0,
		ColumnOldData = ImGuiTableColumn.new(),
	}, ImGuiTableReconcileColumnData)
end

local ImGuiTableCellData = Class()
function ImGuiTableCellData.new()
	return setmetatable({ BgColor = 0, Column = 0 }, ImGuiTableCellData)
end

local ImGuiTableHeaderData = Class()
function ImGuiTableHeaderData.new()
	return setmetatable({ Index = 0, TextColor = 0, BgColor0 = 0, BgColor1 = 0 }, ImGuiTableHeaderData)
end

local ImGuiTableInstanceData = Class()
function ImGuiTableInstanceData.new()
	return setmetatable({
		TableInstanceID = 0,
		LastOuterHeight = 0,
		LastTopHeadersRowHeight = 0,
		LastFrozenHeight = 0,
		HoveredRowLast = -1,
		HoveredRowNext = -1,
	}, ImGuiTableInstanceData)
end

local ImGuiTable = Class({
	RowBgColor = "C",
	ColumnsNames = "S",
	InstanceDataFirst = "S",
	InstanceDataExtra = "D",
	SortSpecs = "S",
	SortSpecsMulti = "D",
	SortSpecsSingle = "S",
})
function ImGuiTable.new()
	local P = Public()
	local instance_data_first = ImGuiTableInstanceData.new()
	instance_data_first.HoveredRowLast = 0
	instance_data_first.HoveredRowNext = 0
	return setmetatable({
		ID = 0,
		Flags = 0,
		RawData = nil,
		TempData = nil,
		Columns = {},
		DisplayOrderToIndex = {},
		RowCellData = {},
		EnabledMaskByDisplayOrder = nil,
		EnabledMaskByIndex = nil,
		VisibleMaskByIndex = nil,
		SettingsLoadedFlags = 0,
		SettingsOffset = 0,
		LastFrameActive = -1,
		ColumnsCount = 0,
		CurrentRow = 0,
		CurrentColumn = 0,
		InstanceCurrent = 0,
		InstanceInteracted = 0,
		RowPosY1 = 0,
		RowPosY2 = 0,
		RowMinHeight = 0,
		RowCellPaddingY = 0,
		RowTextBaseline = 0,
		RowIndentOffsetX = 0,
		RowFlags = 0,
		LastRowFlags = 0,
		RowBgColorCounter = 0,
		RowBgColor = { 0, 0 },
		BorderColorStrong = 0,
		BorderColorLight = 0,
		BorderX1 = 0,
		BorderX2 = 0,
		HostIndentX = 0,
		MinColumnWidth = 0,
		OuterPaddingX = 0,
		CellPaddingX = 0,
		CellSpacingX1 = 0,
		CellSpacingX2 = 0,
		InnerWidth = 0,
		ColumnsGivenWidth = 0,
		ColumnsAutoFitWidth = 0,
		ColumnsStretchSumWeights = 0,
		ResizedColumnNextWidth = 0,
		ResizeLockMinContentsX2 = 0,
		RefScale = 0,
		AngledHeadersHeight = 0,
		AngledHeadersSlope = 0,
		OuterRect = ImRect.new(),
		InnerRect = ImRect.new(),
		WorkRect = ImRect.new(),
		InnerClipRect = ImRect.new(),
		BgClipRect = ImRect.new(),
		Bg0ClipRectForDrawCmd = ImRect.new(),
		Bg2ClipRectForDrawCmd = ImRect.new(),
		HostClipRect = ImRect.new(),
		HostBackupInnerClipRect = ImRect.new(),
		OuterWindow = nil,
		InnerWindow = nil,
		ColumnsNames = Base.ImGuiTextBuffer.new(),
		DrawSplitter = nil,
		InstanceDataFirst = instance_data_first,
		InstanceDataExtra = ImVector.new(),
		SortSpecs = P.ImGuiTableSortSpecs.new(),
		SortSpecsMulti = ImVector.new(),
		SortSpecsSingle = P.ImGuiTableColumnSortSpecs.new(),
		SortSpecsCount = 0,
		ColumnsEnabledCount = 0,
		ColumnsEnabledFixedCount = 0,
		DeclColumnsCount = 0,
		AngledHeadersCount = 0,
		HoveredColumnBody = 0,
		HoveredColumnBorder = 0,
		HighlightColumnHeader = 0,
		AutoFitSingleColumn = 0,
		ResizedColumn = 0,
		LastResizedColumn = 0,
		HeldHeaderColumn = 0,
		LastHeldHeaderColumn = 0,
		ReorderColumn = 0,
		ReorderColumnDstOrder = 0,
		LeftMostEnabledColumn = 0,
		RightMostEnabledColumn = 0,
		LeftMostStretchedColumn = 0,
		RightMostStretchedColumn = 0,
		ContextPopupColumn = 0,
		FreezeRowsRequest = 0,
		FreezeRowsCount = 0,
		FreezeColumnsRequest = 0,
		FreezeColumnsCount = 0,
		RowCellDataCurrent = 0,
		DummyDrawChannel = 0,
		Bg2DrawChannelCurrent = 0,
		Bg2DrawChannelUnfrozen = 0,
		NavLayer = 0,
		IsLayoutLocked = false,
		IsInsideRow = false,
		IsNewTable = false,
		IsInitializing = false,
		IsReconcileMode = false,
		IsSortSpecsDirty = false,
		IsUsingHeaders = false,
		IsContextPopupOpen = false,
		DisableDefaultContextMenu = false,
		IsSettingsRequestLoad = false,
		IsSettingsDirty = false,
		IsDefaultDisplayOrder = false,
		IsDefaultVisibility = false,
		IsResetAllRequest = false,
		IsResetDisplayOrderRequest = false,
		IsResetVisibilityRequest = false,
		IsUnfrozenRows = false,
		IsDefaultSizingPolicy = false,
		IsActiveIdAliveBeforeTable = false,
		IsActiveIdInTable = false,
		HasScrollbarYCurr = false,
		HasScrollbarYPrev = false,
		MemoryCompacted = false,
		HostSkipItems = false,
	}, ImGuiTable)
end

local ImGuiTableTempData = Class({
	AngledHeadersRequests = "D",
	ReconcileColumnsRequests = "D",
	DrawSplitter = "S",
	HostBackupColumnsOffset = "S",
})
function ImGuiTableTempData.new()
	return setmetatable({
		WindowID = 0,
		TableIndex = 0,
		LastTimeActive = -1,
		AngledHeadersExtraWidth = 0,
		AngledHeadersRequests = ImVector.new(),
		ReconcileColumnsRequests = ImVector.new(),
		OldColumnsRawData = nil,
		OldColumnsData = {},
		UserOuterSize = V0,
		DrawSplitter = DrawListModule().ImDrawListSplitter.new(),
		HostBackupWorkRect = ImRect.new(),
		HostBackupParentWorkRect = ImRect.new(),
		HostBackupPrevLineSize = V0,
		HostBackupCurrLineSize = V0,
		HostBackupCursorMaxPos = V0,
		HostBackupColumnsOffset = ImVec1.new(),
		HostBackupItemWidth = 0,
		HostBackupItemWidthStackSize = 0,
	}, ImGuiTableTempData)
end

local ImGuiTableColumnSettings = Class()
function ImGuiTableColumnSettings.new()
	return setmetatable({
		WidthOrWeight = 0,
		ID = 0,
		Index = -1,
		DisplayOrder = -1,
		SortOrder = -1,
		SortDirection = ImGuiSortDirection.None,
		IsEnabled = -1,
		IsStretch = 0,
		IsLoaded = false,
	}, ImGuiTableColumnSettings)
end

local ImGuiTableSettings = Class({ LastUsedDate = "S", ColumnSettings = "D" })
function ImGuiTableSettings.new()
	return setmetatable({
		ID = 0,
		SaveFlags = 0,
		RefScale = 0,
		ColumnsCount = 0,
		ColumnsCountMax = 0,
		LastUsedDate = ImGuiPackedDate.new(),
		WantApply = false,
		ColumnSettings = {},
	}, ImGuiTableSettings)
end
function ImGuiTableSettings:GetColumnSettings()
	return self.ColumnSettings
end

local ImGuiContext = Class({
	IO = "S",
	PlatformIO = "S",
	Style = "S",
	FontAtlases = "C",
	DrawListSharedData = "S",
	InputEventsQueue = "D",
	InputEventsTrail = "D",
	Windows = "C",
	WindowsFocusOrder = "C",
	WindowsTempSortBuffer = "C",
	CurrentWindowStack = "D",
	WindowsById = "S",
	DeactivatedItemData = "S",
	KeysMayBeCharInput = "C",
	KeysOwnerData = "D",
	KeysRoutingTable = "S",
	NextItemData = "S",
	LastItemData = "S",
	NextWindowData = "S",
	ColorStack = "D",
	StyleVarStack = "D",
	FontStack = "D",
	FocusScopeStack = "D",
	ItemFlagsStack = "C",
	GroupStack = "D",
	OpenPopupStack = "D",
	BeginPopupStack = "D",
	TreeNodeStack = "D",
	Viewports = "C",
	NavFocusRoute = "D",
	NavInitResult = "S",
	NavMoveResultLocal = "S",
	NavMoveResultLocalVisible = "S",
	NavMoveResultOther = "S",
	NavTabbingResultFirst = "S",
	DragDropPayload = "S",
	DragDropPayloadBufHeap = "C",
	DragDropPayloadBufLocal = "C",
	ClipperTempData = "D",
	TablesTempData = "D",
	Tables = "S",
	TablesLastTimeActive = "C",
	DrawChannelsTempMergeBuffer = "C",
	TabBars = "S",
	CurrentTabBarStack = "D",
	ShrinkWidthBuffer = "D",
	BoxSelectState = "S",
	MultiSelectTempData = "D",
	MultiSelectStorage = "S",
	InputTextState = "S",
	InputTextLineIndex = "S",
	InputTextDeactivatedState = "S",
	InputTextPasswordFontBackupBaked = "S",
	ComboPreviewData = "S",
	ClipboardHandlerData = "C",
	MenusIdSubmittedThisFrame = "C",
	TypingSelectState = "S",
	PlatformImeData = "S",
	PlatformImeDataPrev = "S",
	UserTextures = "C",
	SessionDate = "S",
	SettingsIniData = "S",
	SettingsHandlers = "D",
	SettingsWindows = "S",
	SettingsTables = "S",
	Hooks = "D",
	LocalizationTable = "C",
	LogBuffer = "S",
	StackSizesInNewFrame = "S",
	DebugLogBuf = "S",
	DebugLogIndex = "S",
	DebugMetricsConfig = "S",
	DebugItemPathQuery = "S",
	DebugIDStackTool = "S",
	DebugAllocInfo = "S",
	FramerateSecPerFrame = "C",
	TempBuffer = "C",
})

local function InitContextCore(g, P, DL, shared_font_atlas)
	g.Initialized = false
	g.WithinFrameScope = false
	g.WithinFrameScopeWithImplicitWindow = false
	g.TestEngineHookItems = false
	g.FrameCount = 0
	g.FrameCountEnded = -1
	g.FrameCountRendered = -1
	g.Time = 0
	g.ContextName = ""
	g.IO = P.ImGuiIO.new()
	g.PlatformIO = P.ImGuiPlatformIO.new()
	g.Style = P.ImGuiStyle.new()
	g.FontAtlases = ImVector.new()
	g.Font = nil
	g.FontBaked = nil
	g.FontSize = 0
	g.FontSizeBase = 0
	g.FontBakedScale = 0
	g.CurrentPixelDensity = 1
	g.CurrentDpiScale = 0
	g.DrawListSharedData = DL.ImDrawListSharedData.new()
	g.WithinEndChildID = 0
	g.WithinEndPopupID = 0
	g.TestEngine = nil

	g.InputTextState = ImGuiInputTextState.new()
	g.IO.Ctx = g
	g.InputTextState.Ctx = g
	g.IO.Fonts = shared_font_atlas or DL.ImFontAtlas.new()
	if shared_font_atlas == nil then
		g.IO.Fonts.OwnerContext = g
	end

	g.InputEventsQueue = ImVector.new()
	g.InputEventsTrail = ImVector.new()
	g.InputEventsNextMouseSource = Enums.ImGuiMouseSource.Mouse
	g.InputEventsNextEventId = 1

	g.Windows = ImVector.new()
	g.WindowsFocusOrder = ImVector.new()
	g.WindowsTempSortBuffer = ImVector.new()
	g.CurrentWindowStack = ImVector.new()
	g.WindowsById = Base.ImGuiStorage.new()
	g.WindowsActiveCount = 0
	g.WindowsBorderHoverPadding = 0
	g.DebugBreakInWindow = 0
	g.CurrentWindow = nil
	g.HoveredWindow = nil
	g.HoveredWindowUnderMovingWindow = nil
	g.HoveredWindowBeforeClear = nil
	g.MovingWindow = nil
	g.WheelingWindow = nil
	g.WheelingWindowRefMousePos = V0
	g.WheelingWindowStartFrame = -1
	g.WheelingWindowScrolledFrame = -1
	g.WheelingWindowReleaseTimer = 0
	g.WheelingWindowWheelRemainder = V0
	g.WheelingAxisAvg = V0

	g.MixedValueLabel = "-"
	g.DebugDrawIdConflictsId = 0
	g.DebugHookIdInfoId = 0
	g.HoveredId = 0
	g.HoveredIdPreviousFrame = 0
	g.HoveredIdPreviousFrameItemCount = 0
	g.HoveredIdTimer = 0
	g.HoveredIdNotActiveTimer = 0
	g.HoveredIdAllowOverlap = false
	g.HoveredIdIsDisabled = false
	g.ItemUnclipByLog = false
	g.AnyIdHasBeenEditedThisFrame = false
	g.ActiveId = 0
	g.ActiveIdIsAlive = 0
	g.ActiveIdTimer = 0
	g.ActiveIdIsJustActivated = false
	g.ActiveIdWasSelected = false
	g.ActiveIdWasSoleSelected = false
	g.ActiveIdAllowOverlap = false
	g.ActiveIdNoClearOnFocusLoss = false
	g.ActiveIdHasBeenPressedBefore = false
	g.ActiveIdHasBeenEditedBefore = false
	g.ActiveIdHasBeenEditedThisFrame = false
	g.ActiveIdFromShortcut = false
	g.ActiveIdMouseButton = -1
	g.ActiveIdDisabledId = 0
	g.ActiveIdClickOffset = ImVec2(-1, -1)
	g.ActiveIdSource = ImGuiInputSource.None
	g.ActiveIdWindow = nil
	g.ActiveIdPreviousFrame = 0
	g.DeactivatedItemData = ImGuiDeactivatedItemData.new()
	g.ActiveIdValueOnActivation = 0
	g.LastActiveId = 0
	g.LastActiveIdTimer = 0
	g.LastActiveIdWasSelected = false
	g.LastActiveIdWasSoleSelected = false

	g.LastKeyModsChangeTime = -1
	g.LastKeyModsChangeFromNoneTime = -1
	g.LastKeyboardKeyPressTime = -1
	g.KeysMayBeCharInput = table.create(bit32.rshift(ImGuiKey.NamedKey_COUNT + 31, 5), 0)
	local keys_owner_data = table.create(ImGuiKey.NamedKey_COUNT)
	for n = 1, ImGuiKey.NamedKey_COUNT do
		keys_owner_data[n] = ImGuiKeyOwnerData.new()
	end
	g.KeysOwnerData = keys_owner_data
	g.KeysRoutingTable = ImGuiKeyRoutingTable.new()
	g.ActiveIdUsingNavDirMask = 0
	g.ActiveIdUsingAllKeyboardKeys = false
	g.DebugBreakInShortcutRouting = ImGuiKey.None

	g.CurrentFocusScopeId = 0
	g.CurrentItemFlags = 0
	g.DebugLocateId = 0
	g.NextItemData = ImGuiNextItemData.new()
	g.LastItemData = ImGuiLastItemData.new()
	g.NextWindowData = ImGuiNextWindowData.new()
	g.DebugShowGroupRects = false
	g.GcCompactAll = false

	g.DebugFlashStyleColorIdx = ImGuiCol.COUNT
	g.ColorStack = ImVector.new()
	g.StyleVarStack = ImVector.new()
	g.FontStack = ImVector.new()
	g.FocusScopeStack = ImVector.new()
	g.ItemFlagsStack = ImVector.new()
	g.GroupStack = ImVector.new()
	g.OpenPopupStack = ImVector.new()
	g.BeginPopupStack = ImVector.new()
	g.TreeNodeStack = ImVector.new()

	g.Viewports = ImVector.new()
end

local function InitContextNav(g)
	g.NavCursorVisible = false
	g.NavHighlightItemUnderNav = false
	g.NavMousePosDirty = false
	g.NavIdIsAlive = false
	g.NavId = 0
	g.NavWindow = nil
	g.NavFocusScopeId = 0
	g.NavLayer = ImGuiNavLayer.Main
	g.NavIdItemFlags = 0
	g.NavActivateId = 0
	g.NavActivateDownId = 0
	g.NavActivatePressedId = 0
	g.NavActivateFlags = 0
	g.NavFocusRoute = ImVector.new()
	g.NavHighlightActivatedId = 0
	g.NavHighlightActivatedTimer = 0
	g.NavOpenContextMenuItemId = 0
	g.NavOpenContextMenuWindowId = 0
	g.NavNextActivateId = 0
	g.NavNextActivateFlags = 0
	g.NavInputSource = ImGuiInputSource.Keyboard
	g.NavLastValidSelectionUserData = SelectionUserData_Invalid
	g.NavCursorHideFrames = 0

	g.NavAnyRequest = false
	g.NavInitRequest = false
	g.NavInitRequestFromMove = false
	g.NavInitResult = ImGuiNavItemData.new()
	g.NavMoveSubmitted = false
	g.NavMoveScoringItems = false
	g.NavMoveForwardToNextFrame = false
	g.NavMoveFlags = 0
	g.NavMoveScrollFlags = 0
	g.NavMoveKeyMods = ImGuiMod.None
	g.NavMoveDir = ImGuiDir.None
	g.NavMoveDirForDebug = ImGuiDir.None
	g.NavMoveClipDir = ImGuiDir.None
	g.NavScoringRect = ImRect.new()
	g.NavScoringNoClipRect = ImRect.new()
	g.NavScoringDebugCount = 0
	g.NavTabbingDir = 0
	g.NavTabbingCounter = 0
	g.NavMoveResultLocal = ImGuiNavItemData.new()
	g.NavMoveResultLocalVisible = ImGuiNavItemData.new()
	g.NavMoveResultOther = ImGuiNavItemData.new()
	g.NavTabbingResultFirst = ImGuiNavItemData.new()

	g.NavJustMovedFromFocusScopeId = 0
	g.NavJustMovedToId = 0
	g.NavJustMovedToFocusScopeId = 0
	g.NavJustMovedToKeyMods = ImGuiMod.None
	g.NavJustMovedToIsTabbing = false
	g.NavJustMovedToIsInit = false
	g.NavJustMovedToHasSelectionData = false

	g.ConfigNavEnableTabbing = true
	g.ConfigNavWindowingWithGamepad = true
	if g.IO.ConfigMacOSXBehaviors then
		g.ConfigNavWindowingKeyNext = bit32.bor(ImGuiMod.Super, ImGuiKey.Tab)
		g.ConfigNavWindowingKeyPrev = bit32.bor(ImGuiMod.Super, ImGuiMod.Shift, ImGuiKey.Tab)
	else
		g.ConfigNavWindowingKeyNext = bit32.bor(ImGuiMod.Ctrl, ImGuiKey.Tab)
		g.ConfigNavWindowingKeyPrev = bit32.bor(ImGuiMod.Ctrl, ImGuiMod.Shift, ImGuiKey.Tab)
	end

	g.NavWindowingTarget = nil
	g.NavWindowingTargetAnim = nil
	g.NavWindowingListWindow = nil
	g.NavWindowingTimer = 0
	g.NavWindowingHighlightAlpha = 0
	g.NavWindowingInputSource = ImGuiInputSource.None
	g.NavWindowingToggleLayer = false
	g.NavWindowingToggleKey = ImGuiKey.None
	g.NavWindowingAccumDeltaPos = V0
	g.NavWindowingAccumDeltaSize = V0

	g.DimBgRatio = 0
end

local function InitContextMisc(g, P, DL)
	g.DragDropActive = false
	g.DragDropWithinSource = false
	g.DragDropWithinTarget = false
	g.DragDropSourceFlags = 0
	g.DragDropSourceFrameCount = -1
	g.DragDropMouseButton = -1
	g.DragDropPayload = P.ImGuiPayload.new()
	g.DragDropTargetRect = ImRect.new()
	g.DragDropTargetClipRect = ImRect.new()
	g.DragDropTargetId = 0
	g.DragDropTargetFullViewport = 0
	g.DragDropAcceptFlagsCurr = 0
	g.DragDropAcceptFlagsPrev = 0
	g.DragDropAcceptIdCurrRectSurface = 0
	g.DragDropAcceptIdCurr = 0
	g.DragDropAcceptIdPrev = 0
	g.DragDropAcceptFrameCount = -1
	g.DragDropHoldJustPressedId = 0
	g.DragDropPayloadBufHeap = ImVector.new()
	g.DragDropPayloadBufLocal = table.create(16, 0)

	g.ClipperTempDataStacked = 0
	g.ClipperTempData = ImVector.new()

	g.CurrentTable = nil
	g.DebugBreakInTable = 0
	g.TablesTempDataStacked = 0
	g.TablesTempData = ImVector.new()
	g.Tables = Base.ImPool.new(ImGuiTable.new)
	g.TablesLastTimeActive = ImVector.new()
	g.DrawChannelsTempMergeBuffer = ImVector.new()

	g.CurrentTabBar = nil
	g.TabBars = Base.ImPool.new(ImGuiTabBar.new)
	g.CurrentTabBarStack = ImVector.new()
	g.ShrinkWidthBuffer = ImVector.new()

	g.BoxSelectState = ImGuiBoxSelectState.new()
	g.CurrentMultiSelect = nil
	g.MultiSelectTempDataStacked = 0
	g.MultiSelectTempData = ImVector.new()
	g.MultiSelectStorage = Base.ImPool.new(ImGuiMultiSelectState.new)

	g.HoverItemDelayId = 0
	g.HoverItemDelayIdPreviousFrame = 0
	g.HoverItemDelayTimer = 0
	g.HoverItemDelayClearTimer = 0
	g.HoverItemUnlockedStationaryId = 0
	g.HoverWindowUnlockedStationaryId = 0

	g.MouseCursor = Enums.ImGuiMouseCursor.Arrow
	g.MouseStationaryTimer = 0
	g.MouseLastValidPos = V0

	g.InputTextLineIndex = Base.ImGuiTextIndex.new()
	g.InputTextDeactivatedState = ImGuiInputTextDeactivatedState.new()
	g.InputTextPasswordFontBackupBaked = DL.ImFontBaked.new()
	g.InputTextPasswordFontBackupFlags = Enums.ImFontFlags.None
	g.InputTextReactivateId = 0
	g.TempInputId = 0
	g.DataTypeZeroValue = 0
	g.BeginMenuDepth = 0
	g.BeginComboDepth = 0
	g.ColorEditCurrentID = 0
	g.ColorEditSavedID = 0
	g.ColorEditSavedHue = 0
	g.ColorEditSavedSat = 0
	g.ColorEditSavedColor = 0
	g.ColorPickerRef = ImVec4(0, 0, 0, 0)
	g.ComboPreviewData = ImGuiComboPreviewData.new()
	g.WindowResizeBorderExpectedRect = ImRect.new()
	g.WindowResizeRelativeMode = false
	g.ScrollbarSeekMode = 0
	g.ScrollbarClickDeltaToGrabCenter = 0
	g.SliderGrabClickOffset = 0
	g.SliderCurrentAccum = 0
	g.SliderCurrentAccumDirty = false
	g.DragCurrentAccumDirty = false
	g.DragCurrentAccum = 0
	g.DragSpeedDefaultRatio = 1 / 100
	g.DisabledAlphaBackup = 0
	g.DisabledStackSize = 0
	g.TooltipOverrideCount = 0
	g.TooltipPreviousWindow = nil
	g.ClipboardHandlerData = ImVector.new()
	g.MenusIdSubmittedThisFrame = ImVector.new()
	g.TypingSelectState = ImGuiTypingSelectState.new()

	g.PlatformImeData = P.ImGuiPlatformImeData.new()
	g.PlatformImeDataPrev = P.ImGuiPlatformImeData.new()
	g.PlatformImeData.InputPos = ImVec2(0, 0)
	g.PlatformImeDataPrev.InputPos = ImVec2(-1, -1)

	g.UserTextures = ImVector.new()

	g.SessionDate = ImGuiPackedDate.new()
	g.SettingsLoaded = false
	g.SettingsDirtyTimer = 0
	g.SettingsIniData = Base.ImGuiTextBuffer.new()
	g.SettingsHandlers = ImVector.new()
	g.SettingsWindows = Base.ImChunkStream.new()
	g.SettingsTables = Base.ImChunkStream.new()

	g.Hooks = ImVector.new()
	g.HookIdNext = 0
	g.DemoMarkerCallback = nil

	g.LocalizationTable = {}

	g.LogEnabled = false
	g.LogLineFirstItem = false
	g.LogFlags = Enums.ImGuiLogFlags.None
	g.LogWindow = nil
	g.LogFile = nil
	g.LogBuffer = Base.ImGuiTextBuffer.new()
	g.LogNextPrefix = nil
	g.LogNextSuffix = nil
	g.LogLinePosY = FLT_MAX
	g.LogDepthRef = 0
	g.LogDepthToExpand = 2
	g.LogDepthToExpandDefault = 2

	g.ErrorCallback = nil
	g.ErrorCallbackUserData = nil
	g.ErrorTooltipLockedPos = V0
	g.ErrorFirst = true
	g.ErrorCountCurrentFrame = 0
	g.StackSizesInNewFrame = ImGuiErrorRecoveryState.new()
	g.StackSizesInBeginForCurrentWindow = nil

	g.DebugDrawIdConflictsCount = 0
	g.DebugLogFlags = bit32.bor(ImGuiDebugLogFlags.EventError, ImGuiDebugLogFlags.OutputToTTY)
	g.DebugLogBuf = Base.ImGuiTextBuffer.new()
	g.DebugLogIndex = Base.ImGuiTextIndex.new()
	g.DebugLogSkippedErrors = 0
	g.DebugLogAutoDisableFlags = ImGuiDebugLogFlags.None
	g.DebugLogAutoDisableFrames = 0
	g.DebugLocateFrames = 0
	g.DebugBreakInLocateId = false
	g.DebugBreakKeyChord = ImGuiKey.Pause
	g.DebugBeginReturnValueCullDepth = -1
	g.DebugItemPickerActive = false
	g.DebugItemPickerMouseButton = Enums.ImGuiMouseButton.Left
	g.DebugItemPickerBreakId = 0
	g.DebugFlashStyleColorTime = 0
	g.DebugFlashStyleColorBackup = ImVec4(0, 0, 0, 0)
	g.DebugMetricsConfig = ImGuiMetricsConfig.new()
	g.DebugItemPathQuery = ImGuiDebugItemPathQuery.new()
	g.DebugIDStackTool = ImGuiIDStackTool.new()
	g.DebugAllocInfo = ImGuiDebugAllocInfo.new()

	g.FramerateSecPerFrame = table.create(60, 0)
	g.FramerateSecPerFrameIdx = 0
	g.FramerateSecPerFrameCount = 0
	g.FramerateSecPerFrameAccum = 0
	g.WantCaptureMouseNextFrame = -1
	g.WantCaptureKeyboardNextFrame = -1
	g.WantTextInputNextFrame = -1
	g.TempBuffer = ImVector.new()
	g.TempKeychordName = ""
end

function ImGuiContext.new(shared_font_atlas)
	local P = Public()
	local DL = DrawListModule()
	local g = setmetatable({}, ImGuiContext)
	InitContextCore(g, P, DL, shared_font_atlas)
	InitContextNav(g)
	InitContextMisc(g, P, DL)
	return g
end

return {
	ImVec1 = ImVec1,
	ImVec2i = ImVec2i,
	ImVec2ih = ImVec2ih,
	ImGuiTextFilterItem = ImGuiTextFilterItem,
	ImGuiPackedDate = ImGuiPackedDate,
	ImFontStackData = ImFontStackData,
	ImGuiStyleVarInfo = ImGuiStyleVarInfo,
	ImGuiColorMod = ImGuiColorMod,
	ImGuiStyleMod = ImGuiStyleMod,
	ImGuiDataTypeStorage = ImGuiDataTypeStorage,
	ImGuiDataTypeInfo = ImGuiDataTypeInfo,
	ImGuiComboPreviewData = ImGuiComboPreviewData,
	ImGuiGroupData = ImGuiGroupData,
	ImGuiMenuColumns = ImGuiMenuColumns,
	ImGuiInputTextDeactivatedState = ImGuiInputTextDeactivatedState,
	ImGuiInputTextState = ImGuiInputTextState,
	ImGuiNextWindowData = ImGuiNextWindowData,
	ImGuiNextItemData = ImGuiNextItemData,
	ImGuiLastItemData = ImGuiLastItemData,
	ImGuiTreeNodeStackData = ImGuiTreeNodeStackData,
	ImGuiErrorRecoveryState = ImGuiErrorRecoveryState,
	ImGuiWindowStackData = ImGuiWindowStackData,
	ImGuiShrinkWidthItem = ImGuiShrinkWidthItem,
	ImGuiPtrOrIndex = ImGuiPtrOrIndex,
	ImGuiDeactivatedItemData = ImGuiDeactivatedItemData,
	ImGuiPopupData = ImGuiPopupData,
	ImGuiInputEvent = ImGuiInputEvent,
	ImGuiKeyRoutingData = ImGuiKeyRoutingData,
	ImGuiKeyRoutingTable = ImGuiKeyRoutingTable,
	ImGuiKeyOwnerData = ImGuiKeyOwnerData,
	ImGuiListClipperRange = ImGuiListClipperRange,
	ImGuiListClipperData = ImGuiListClipperData,
	ImGuiNavItemData = ImGuiNavItemData,
	ImGuiFocusScopeData = ImGuiFocusScopeData,
	ImGuiTypingSelectRequest = ImGuiTypingSelectRequest,
	ImGuiTypingSelectState = ImGuiTypingSelectState,
	ImGuiOldColumnData = ImGuiOldColumnData,
	ImGuiOldColumns = ImGuiOldColumns,
	ImGuiBoxSelectState = ImGuiBoxSelectState,
	ImGuiMultiSelectTempData = ImGuiMultiSelectTempData,
	ImGuiMultiSelectState = ImGuiMultiSelectState,
	ImGuiViewportP = ImGuiViewportP,
	ImGuiWindowSettings = ImGuiWindowSettings,
	ImGuiSettingsCleanupArgs = ImGuiSettingsCleanupArgs,
	ImGuiSettingsHandler = ImGuiSettingsHandler,
	ImGuiLocEntry = ImGuiLocEntry,
	ImGuiDebugAllocEntry = ImGuiDebugAllocEntry,
	ImGuiDebugAllocInfo = ImGuiDebugAllocInfo,
	ImGuiMetricsConfig = ImGuiMetricsConfig,
	ImGuiStackLevelInfo = ImGuiStackLevelInfo,
	ImGuiDebugItemPathQuery = ImGuiDebugItemPathQuery,
	ImGuiIDStackTool = ImGuiIDStackTool,
	ImGuiContextHook = ImGuiContextHook,
	ImGuiContext = ImGuiContext,
	ImGuiWindowTempData = ImGuiWindowTempData,
	ImGuiWindow = ImGuiWindow,
	ImGuiTabItem = ImGuiTabItem,
	ImGuiTabBar = ImGuiTabBar,
	ImGuiTableColumn = ImGuiTableColumn,
	ImGuiTableReconcileColumnData = ImGuiTableReconcileColumnData,
	ImGuiTableCellData = ImGuiTableCellData,
	ImGuiTableHeaderData = ImGuiTableHeaderData,
	ImGuiTableInstanceData = ImGuiTableInstanceData,
	ImGuiTable = ImGuiTable,
	ImGuiTableTempData = ImGuiTableTempData,
	ImGuiTableColumnSettings = ImGuiTableColumnSettings,
	ImGuiTableSettings = ImGuiTableSettings,
}
