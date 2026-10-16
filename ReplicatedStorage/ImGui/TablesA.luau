--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImTrunc, ImCeil, IM_TRUNC = Base.ImTrunc, Base.ImCeil, Base.IM_TRUNC
local ImIsPowerOfTwo, ImHashStr = Base.ImIsPowerOfTwo, Base.ImHashStr
local ImBitArrayTestBit, ImBitArraySetBit, ImBitArrayClearAllBits = Base.ImBitArrayTestBit, Base.ImBitArraySetBit, Base.ImBitArrayClearAllBits
local FLT_MAX, FLT_MIN = Base.FLT_MAX, Base.FLT_MIN

local band, bor, bnot, btest = bit32.band, bit32.bor, bit32.bnot, bit32.btest
local lshift, rshift = bit32.lshift, bit32.rshift
local tfind, tcreate = table.find, table.create

local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTableColumnFlags = Enums.ImGuiTableColumnFlags
local ImGuiTableRowFlags = Enums.ImGuiTableRowFlags
local ImGuiTableBgTarget = Enums.ImGuiTableBgTarget
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiNextWindowDataFlags = Enums.ImGuiNextWindowDataFlags
local ImGuiSortDirection = Enums.ImGuiSortDirection
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiCol = Enums.ImGuiCol
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local Defines = Enums.Defines

local ImGuiTableColumn = Structs.ImGuiTableColumn

local IMGUI_TABLE_MAX_COLUMNS = Defines.IMGUI_TABLE_MAX_COLUMNS or 512
local IMGUI_WINDOW_HARD_MIN_SIZE = Defines.IMGUI_WINDOW_HARD_MIN_SIZE or 4
local IM_COL32_DISABLE = Defines.IM_COL32_DISABLE or 0x01000000

local TABLE_DRAW_CHANNEL_BG0 = 0
local TABLE_DRAW_CHANNEL_NOCLIP = 2
local TABLE_BORDER_SIZE = 1.0
local TABLE_RESIZE_SEPARATOR_HALF_THICKNESS = 4.0
local TABLE_RESIZE_SEPARATOR_FEEDBACK_TIMER = 0.06

local function UserError(msg)
	if ImGui.ErrorLog(msg) then
		assert(false, msg)
	end
end

local function OldColumnsSize(temp_data)
	local old = temp_data.OldColumnsData
	if old == nil then
		return 0
	end
	return #old
end

function ImGui.TableFixFlags(flags, outer_window)
	if band(flags, ImGuiTableFlags.SizingMask_) == 0 then
		flags = bor(flags, (btest(flags, ImGuiTableFlags.ScrollX) or btest(outer_window.Flags, ImGuiWindowFlags.AlwaysAutoResize)) and ImGuiTableFlags.SizingFixedFit or ImGuiTableFlags.SizingStretchSame)
	end
	if band(flags, ImGuiTableFlags.SizingMask_) == ImGuiTableFlags.SizingFixedSame then
		flags = bor(flags, ImGuiTableFlags.NoKeepColumnsVisible)
	end
	if btest(flags, ImGuiTableFlags.Resizable) then
		flags = bor(flags, ImGuiTableFlags.BordersInnerV)
	end
	if btest(flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY)) then
		flags = band(flags, bnot(bor(ImGuiTableFlags.NoHostExtendX, ImGuiTableFlags.NoHostExtendY)))
	end
	if btest(flags, ImGuiTableFlags.NoBordersInBodyUntilResize) then
		flags = band(flags, bnot(ImGuiTableFlags.NoBordersInBody))
	end
	if band(flags, bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Sortable)) == 0 then
		flags = bor(flags, ImGuiTableFlags.NoSavedSettings)
	end
	if btest(outer_window.RootWindow.Flags, ImGuiWindowFlags.NoSavedSettings) then
		flags = bor(flags, ImGuiTableFlags.NoSavedSettings)
	end
	return flags
end

function ImGui.TableFindByID(id)
	local g = ImGui.GImGui
	return g.Tables:GetByKey(id)
end

function ImGui.TableGetInstanceData(table, instance_no)
	if instance_no == 0 then
		return table.InstanceDataFirst
	end
	return table.InstanceDataExtra[instance_no]
end

function ImGui.TableGetInstanceID(table, instance_no)
	return ImGui.TableGetInstanceData(table, instance_no).TableInstanceID
end

function ImGui.BeginTable(str_id, columns_count, flags, outer_size, inner_width)
	local id = ImGui.GetID(str_id)
	return ImGui.BeginTableEx(str_id, id, columns_count, flags, outer_size, inner_width)
end

function ImGui.BeginTableEx(name, id, columns_count, flags, outer_size, inner_width)
	if flags == nil then flags = 0 end
	if outer_size == nil then outer_size = ImVec2(0, 0) end
	if inner_width == nil then inner_width = 0.0 end
	local g = ImGui.GImGui
	local outer_window = ImGui.GetCurrentWindow()
	if outer_window.SkipItems then
		return false
	end

	assert(columns_count > 0 and columns_count < IMGUI_TABLE_MAX_COLUMNS)
	if btest(flags, ImGuiTableFlags.ScrollX) then
		assert(inner_width >= 0.0)
	end

	local use_child_window = btest(flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY))
	local avail_size = ImGui.GetContentRegionAvail()
	local actual_outer_size = ImTrunc(ImGui.CalcItemSize(outer_size, ImMax(avail_size.x, IMGUI_WINDOW_HARD_MIN_SIZE), use_child_window and ImMax(avail_size.y, IMGUI_WINDOW_HARD_MIN_SIZE) or 0.0))
	local outer_rect = ImRect.new(outer_window.DC.CursorPos, outer_window.DC.CursorPos + actual_outer_size)
	local outer_window_is_measuring_size = (outer_window.AutoFitFramesX > 0) or (outer_window.AutoFitFramesY > 0)
	if use_child_window and ImGui.IsClippedEx(outer_rect, 0) and not outer_window_is_measuring_size then
		ImGui.ItemSize(outer_rect:GetSize())
		ImGui.ItemAdd(outer_rect, id)
		g.NextWindowData:ClearFlags()
		return false
	end

	local table = g.Tables:GetOrAddByKey(id)

	local table_idx = g.Tables:GetIndex(table)
	g.TablesTempDataStacked += 1
	while g.TablesTempData.Size < g.TablesTempDataStacked do
		g.TablesTempData:push_back(Structs.ImGuiTableTempData.new())
	end
	local temp_data = g.TablesTempData[g.TablesTempDataStacked]
	table.TempData = temp_data
	temp_data.TableIndex = table_idx
	temp_data.ReconcileColumnsRequests:resize(0)
	table.DrawSplitter = table.TempData.DrawSplitter
	table.DrawSplitter:Clear()

	table.IsDefaultSizingPolicy = band(flags, ImGuiTableFlags.SizingMask_) == 0
	flags = ImGui.TableFixFlags(flags, outer_window)

	local previous_frame_active = table.LastFrameActive
	local instance_no = (previous_frame_active ~= g.FrameCount) and 0 or table.InstanceCurrent + 1
	local previous_flags = table.Flags
	table.ID = id
	table.Flags = flags
	table.LastFrameActive = g.FrameCount
	table.OuterWindow = outer_window
	table.InnerWindow = outer_window
	table.ColumnsCount = columns_count
	table.IsLayoutLocked = false
	table.InnerWidth = inner_width
	table.NavLayer = outer_window.DC.NavLayerCurrent
	table.IsNewTable = (previous_frame_active == -1)
	temp_data.UserOuterSize = outer_size

	local instance_id
	table.InstanceCurrent = instance_no
	if instance_no > 0 then
		assert(table.ColumnsCount == columns_count, "BeginTable(): Cannot change columns count mid-frame while preserving same ID")
		if table.InstanceDataExtra.Size < instance_no then
			table.InstanceDataExtra:push_back(Structs.ImGuiTableInstanceData.new())
		end
		instance_id = ImGui.GetIDWithSeed(instance_no, ImGui.GetIDWithSeed("##Instances", nil, id))
	else
		instance_id = id
	end
	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	table_instance.TableInstanceID = instance_id

	if use_child_window then
		local override_content_size_x, override_content_size_y = FLT_MAX, FLT_MAX
		if btest(flags, ImGuiTableFlags.ScrollX) and not btest(flags, ImGuiTableFlags.ScrollY) then
			override_content_size_y = FLT_MIN
		end

		if btest(flags, ImGuiTableFlags.ScrollX) and inner_width > 0.0 then
			override_content_size_x = inner_width
		end

		if override_content_size_x ~= FLT_MAX or override_content_size_y ~= FLT_MAX then
			ImGui.SetNextWindowContentSize(ImVec2(override_content_size_x ~= FLT_MAX and override_content_size_x or 0.0, override_content_size_y ~= FLT_MAX and override_content_size_y or 0.0))
		end

		if band(previous_flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY)) == 0 then
			if band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasScroll) == 0 then
				ImGui.SetNextWindowScroll(ImVec2(0.0, 0.0))
			end
		end

		local child_window_flags = btest(flags, ImGuiTableFlags.ScrollX) and ImGuiWindowFlags.HorizontalScrollbar or ImGuiWindowFlags.None
		ImGui.BeginChildEx(name, instance_id, outer_rect:GetSize(), ImGuiChildFlags.None, child_window_flags)
		table.InnerWindow = g.CurrentWindow
		table.WorkRect = table.InnerWindow.WorkRect
		table.OuterRect = table.InnerWindow:Rect()
		table.InnerRect = table.InnerWindow.InnerRect
		assert(table.InnerWindow.WindowPadding.x == 0.0 and table.InnerWindow.WindowPadding.y == 0.0 and table.InnerWindow.WindowBorderSize == 0.0)

		if table.InnerWindow.SkipItems and outer_window_is_measuring_size then
			table.InnerWindow.SkipItems = false
		end

		if instance_no == 0 then
			table.HasScrollbarYPrev = table.HasScrollbarYCurr
			table.HasScrollbarYCurr = false
		end
		table.HasScrollbarYCurr = table.HasScrollbarYCurr or table.InnerWindow.ScrollbarY
	else
		table.WorkRect = outer_rect
		table.OuterRect = outer_rect
		table.InnerRect = outer_rect
		table.HasScrollbarYPrev = false
		table.HasScrollbarYCurr = false
		table.InnerWindow.DC.TreeDepth += 1
	end

	ImGui.PushOverrideID(id)
	if instance_no > 0 then
		ImGui.PushOverrideID(instance_id)
	end

	local inner_window = table.InnerWindow
	table.HostIndentX = inner_window.DC.Indent.x
	table.HostClipRect = inner_window.ClipRect
	table.HostSkipItems = inner_window.SkipItems
	temp_data.WindowID = inner_window.ID
	temp_data.HostBackupWorkRect = inner_window.WorkRect
	temp_data.HostBackupParentWorkRect = inner_window.ParentWorkRect
	temp_data.HostBackupColumnsOffset = outer_window.DC.ColumnsOffset.x
	temp_data.HostBackupPrevLineSize = inner_window.DC.PrevLineSize
	temp_data.HostBackupCurrLineSize = inner_window.DC.CurrLineSize
	temp_data.HostBackupCursorMaxPos = inner_window.DC.CursorMaxPos
	temp_data.HostBackupItemWidth = outer_window.DC.ItemWidth
	temp_data.HostBackupItemWidthStackSize = outer_window.DC.ItemWidthStack.Size
	inner_window.DC.PrevLineSize = ImVec2(0.0, 0.0)
	inner_window.DC.CurrLineSize = ImVec2(0.0, 0.0)

	if inner_window ~= outer_window then
		local border_size = TABLE_BORDER_SIZE
		if btest(flags, ImGuiTableFlags.BordersOuterV) then
			local r = table.HostClipRect
			r = r:WithMinX(ImMin(r.Min.x + border_size, r.Max.x))
			if inner_window.DecoOuterSizeX2 == 0.0 then
				r = r:WithMaxX(ImMax(r.Max.x - border_size, r.Min.x))
			end
			table.HostClipRect = r
		end
		if btest(flags, ImGuiTableFlags.BordersOuterH) then
			local r = table.HostClipRect
			r = r:WithMinY(ImMin(r.Min.y + border_size, r.Max.y))
			if inner_window.DecoOuterSizeY2 == 0.0 then
				r = r:WithMaxY(ImMax(r.Max.y - border_size, r.Min.y))
			end
			table.HostClipRect = r
		end
	end

	local pad_outer_x
	if btest(flags, ImGuiTableFlags.NoPadOuterX) then
		pad_outer_x = false
	elseif btest(flags, ImGuiTableFlags.PadOuterX) then
		pad_outer_x = true
	else
		pad_outer_x = btest(flags, ImGuiTableFlags.BordersOuterV)
	end
	local pad_inner_x = not btest(flags, ImGuiTableFlags.NoPadInnerX)
	local inner_spacing_for_border = btest(flags, ImGuiTableFlags.BordersInnerV) and TABLE_BORDER_SIZE or 0.0
	local inner_spacing_explicit = (pad_inner_x and not btest(flags, ImGuiTableFlags.BordersInnerV)) and g.Style.CellPadding.x or 0.0
	local inner_padding_explicit = (pad_inner_x and btest(flags, ImGuiTableFlags.BordersInnerV)) and g.Style.CellPadding.x or 0.0
	table.CellSpacingX1 = inner_spacing_explicit + inner_spacing_for_border
	table.CellSpacingX2 = inner_spacing_explicit
	table.CellPaddingX = inner_padding_explicit

	local outer_padding_for_border = btest(flags, ImGuiTableFlags.BordersOuterV) and TABLE_BORDER_SIZE or 0.0
	local outer_padding_explicit = pad_outer_x and g.Style.CellPadding.x or 0.0
	table.OuterPaddingX = (outer_padding_for_border + outer_padding_explicit) - table.CellPaddingX

	table.CurrentColumn = -1
	table.CurrentRow = -1
	table.RowBgColorCounter = 0
	table.LastRowFlags = ImGuiTableRowFlags.None
	local inner_clip_rect = (inner_window == outer_window) and table.WorkRect or inner_window.ClipRect
	inner_clip_rect = inner_clip_rect:ClippedWith(table.WorkRect)
	inner_clip_rect = inner_clip_rect:ClippedWithFull(table.HostClipRect)
	inner_clip_rect = inner_clip_rect:WithMaxY(btest(flags, ImGuiTableFlags.NoHostExtendY) and ImMin(inner_clip_rect.Max.y, inner_window.WorkRect.Max.y) or table.HostClipRect.Max.y)
	table.InnerClipRect = inner_clip_rect

	table.RowPosY1 = table.WorkRect.Min.y
	table.RowPosY2 = table.WorkRect.Min.y
	table.RowTextBaseline = 0.0
	table.RowCellPaddingY = 0.0
	table.FreezeRowsRequest = 0
	table.FreezeRowsCount = 0
	table.FreezeColumnsRequest = 0
	table.FreezeColumnsCount = 0
	table.IsUnfrozenRows = true
	table.DeclColumnsCount = 0
	table.AngledHeadersCount = 0
	if previous_frame_active + 1 < g.FrameCount then
		table.IsActiveIdInTable = false
	end
	table.AngledHeadersHeight = 0.0
	temp_data.AngledHeadersExtraWidth = 0.0

	table.BorderColorStrong = ImGui.GetColorU32(ImGuiCol.TableBorderStrong)
	table.BorderColorLight = ImGui.GetColorU32(ImGuiCol.TableBorderLight)

	g.CurrentTable = table
	inner_window.DC.NavIsScrollPushableX = false
	outer_window.DC.CurrentTableIdx = table_idx
	if inner_window ~= outer_window then
		inner_window.DC.CurrentTableIdx = table_idx
	end

	if btest(previous_flags, ImGuiTableFlags.Reorderable) and not btest(flags, ImGuiTableFlags.Reorderable) then
		table.IsResetDisplayOrderRequest = true
	end

	if table_idx >= g.TablesLastTimeActive.Size then
		g.TablesLastTimeActive:resize(table_idx + 1, -1.0)
	end
	g.TablesLastTimeActive[table_idx + 1] = g.Time
	temp_data.LastTimeActive = g.Time
	table.MemoryCompacted = false

	local old_columns_count = (table.RawData ~= nil and table.Columns ~= nil) and #table.Columns or 0
	if old_columns_count ~= 0 and old_columns_count ~= columns_count then
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventTable) then
			ImGui.DebugLog("[table] Table 0x%08X column count %d -> %d, recreating storage.\n", table.ID, old_columns_count, columns_count)
		end
		assert(temp_data.OldColumnsRawData == nil)
		temp_data.OldColumnsRawData = table.RawData
		temp_data.OldColumnsData = table.Columns
		local old_columns = table.TempData.OldColumnsData
		for n = 1, #old_columns do
			old_columns[n].IsNeedReconcileSrc = true
		end
		table.RawData = nil
	end
	if table.RawData == nil then
		ImGui.TableBeginInitMemory(table, columns_count)
		table.IsInitializing = true
	end
	if table.IsResetAllRequest then
		ImGui.TableResetSettings(table)
	end
	if table.IsInitializing then
		if table.IsNewTable then
			table.SettingsOffset = -1
			table.IsSettingsRequestLoad = true
		end
		table.IsSortSpecsDirty = true
		table.IsSettingsDirty = true
		table.IsReconcileMode = false
		table.InstanceInteracted = -1
		table.ContextPopupColumn = -1
		table.ReorderColumn = -1
		table.ReorderColumnDstOrder = -1
		table.ResizedColumn = -1
		table.LastResizedColumn = -1
		table.AutoFitSingleColumn = -1
		table.HoveredColumnBody = -1
		table.HoveredColumnBorder = -1
		local old_columns = temp_data.OldColumnsData
		local old_count = OldColumnsSize(temp_data)
		for n = 0, columns_count - 1 do
			local column = table.Columns[n + 1]
			if old_count > 0 and n < old_count then
				column = old_columns[n + 1]:Copy()
			else
				local width_auto = column.WidthAuto
				column = ImGuiTableColumn.new()
				column.WidthAuto = width_auto
				column.IsPreserveWidthAuto = true
				column.IsEnabled = true
				column.IsUserEnabled = true
				column.IsUserEnabledNextFrame = true
				column.DisplayOrder = n
			end
			table.Columns[n + 1] = column
			table.DisplayOrderToIndex[n + 1] = column.DisplayOrder
		end
	end

	if table.IsSettingsRequestLoad then
		ImGui.TableLoadSettings(table)
	end

	inner_window.SkipItems = true

	if table.ColumnsNames:size() > 0 then
		table.ColumnsNames:clear()
	end

	return true
end

function ImGui.TableBeginInitMemory(table, columns_count)
	local columns_bit_array_words = (columns_count + 31) // 32
	local columns = tcreate(columns_count)
	local display_order_to_index = tcreate(columns_count, 0)
	local row_cell_data = tcreate(columns_count)
	for n = 1, columns_count do
		columns[n] = ImGuiTableColumn.new()
		row_cell_data[n] = Structs.ImGuiTableCellData.new()
	end
	table.Columns = columns
	table.DisplayOrderToIndex = display_order_to_index
	table.RowCellData = row_cell_data
	table.EnabledMaskByDisplayOrder = tcreate(columns_bit_array_words, 0)
	table.EnabledMaskByIndex = tcreate(columns_bit_array_words, 0)
	table.VisibleMaskByIndex = tcreate(columns_bit_array_words, 0)
	table.RawData = true
end

function ImGui.TableApplyQueuedRequests(table)
	if table.InstanceCurrent == 0 then
		if table.ResizedColumn ~= -1 and table.ResizedColumnNextWidth ~= FLT_MAX then
			ImGui.TableSetColumnWidth(table.ResizedColumn, table.ResizedColumnNextWidth)
		end
		table.LastResizedColumn = table.ResizedColumn
		table.ResizedColumnNextWidth = FLT_MAX
		table.ResizedColumn = -1

		if table.AutoFitSingleColumn ~= -1 then
			ImGui.TableSetColumnWidth(table.AutoFitSingleColumn, table.Columns[table.AutoFitSingleColumn + 1].WidthAuto)
			table.AutoFitSingleColumn = -1
		end
	end

	if table.InstanceCurrent == 0 then
		table.LastHeldHeaderColumn = table.HeldHeaderColumn
		table.HeldHeaderColumn = -1
		if table.ReorderColumn ~= -1 and table.ReorderColumnDstOrder ~= -1 then
			ImGui.TableSetColumnDisplayOrder(table, table.ReorderColumn, table.ReorderColumnDstOrder)
			table.ReorderColumnDstOrder = -1
		end

		local g = ImGui.GImGui
		if g.ActiveId == 0 then
			table.ReorderColumn = -1
		end
	end

	if table.IsResetDisplayOrderRequest then
		for n = 0, table.ColumnsCount - 1 do
			table.Columns[n + 1].DisplayOrder = n
			table.DisplayOrderToIndex[n + 1] = n
		end
		table.IsResetDisplayOrderRequest = false
		table.IsSettingsDirty = true
	end
	if table.IsResetVisibilityRequest then
		for n = 1, table.ColumnsCount do
			local column = table.Columns[n]
			local enabled = not btest(column.Flags, ImGuiTableColumnFlags.DefaultHide)
			column.IsUserEnabled = enabled
			column.IsUserEnabledNextFrame = enabled
		end
		table.IsResetVisibilityRequest = false
		table.IsSettingsDirty = true
	end
end

function ImGui.TableSetColumnDisplayOrder(table, column_n, dst_order)
	assert(column_n >= 0 and column_n < table.ColumnsCount)
	assert(dst_order >= 0 and dst_order < table.ColumnsCount)

	local src_column = table.Columns[column_n + 1]
	local src_order = src_column.DisplayOrder
	if src_order == dst_order then
		return
	end
	local reorder_dir = (dst_order < src_order) and -1 or 1

	src_column.DisplayOrder = dst_order
	for order_n = src_order + reorder_dir, dst_order, reorder_dir do
		local c = table.Columns[table.DisplayOrderToIndex[order_n + 1] + 1]
		c.DisplayOrder -= reorder_dir
	end

	for n = 0, table.ColumnsCount - 1 do
		table.DisplayOrderToIndex[table.Columns[n + 1].DisplayOrder + 1] = n
	end
	table.IsSettingsDirty = true
end

function ImGui.TableGetMaxDisplayOrderAllowed(table, src_order, dst_order)
	dst_order = ImClamp(dst_order, 0, table.ColumnsCount - 1)
	if src_order == dst_order then
		return dst_order
	end

	if table.FreezeColumnsRequest > 0 then
		dst_order = (src_order < table.FreezeColumnsRequest) and ImMin(dst_order, table.FreezeColumnsRequest - 1) or ImMax(dst_order, table.FreezeColumnsRequest)
	end

	local reorder_dir = (src_order < dst_order) and 1 or -1
	local order_n = src_order
	while (src_order < dst_order and order_n <= dst_order) or (dst_order < src_order and order_n >= dst_order) do
		if btest(table.Columns[table.DisplayOrderToIndex[order_n + 1] + 1].Flags, ImGuiTableColumnFlags.NoReorder) then
			dst_order = (order_n == src_order) and src_order or order_n - reorder_dir
			break
		end
		order_n += reorder_dir
	end
	return dst_order
end

function ImGui.TableQueueSetColumnDisplayOrder(table, column_n, dst_order)
	local src_order = table.Columns[column_n + 1].DisplayOrder
	table.ReorderColumn = column_n
	table.ReorderColumnDstOrder = -1
	dst_order = ImGui.TableGetMaxDisplayOrderAllowed(table, src_order, dst_order)
	if table.IsLayoutLocked and dst_order == src_order then
		return
	end
	table.ReorderColumnDstOrder = dst_order
end

function ImGui.TableSetupColumnFlags(table, column, flags_in)
	local flags = flags_in

	if band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 then
		local table_sizing_policy = band(table.Flags, ImGuiTableFlags.SizingMask_)
		if table_sizing_policy == ImGuiTableFlags.SizingFixedFit or table_sizing_policy == ImGuiTableFlags.SizingFixedSame then
			flags = bor(flags, ImGuiTableColumnFlags.WidthFixed)
		else
			flags = bor(flags, ImGuiTableColumnFlags.WidthStretch)
		end
	else
		assert(ImIsPowerOfTwo(band(flags, ImGuiTableColumnFlags.WidthMask_)))
	end

	if not btest(table.Flags, ImGuiTableFlags.Resizable) then
		flags = bor(flags, ImGuiTableColumnFlags.NoResize)
	end

	if btest(flags, ImGuiTableColumnFlags.NoSortAscending) and btest(flags, ImGuiTableColumnFlags.NoSortDescending) then
		flags = bor(flags, ImGuiTableColumnFlags.NoSort)
	end

	if band(flags, ImGuiTableColumnFlags.IndentMask_) == 0 then
		flags = bor(flags, (table.Columns[1] == column) and ImGuiTableColumnFlags.IndentEnable or ImGuiTableColumnFlags.IndentDisable)
	end

	column.Flags = bor(flags, band(column.Flags, ImGuiTableColumnFlags.StatusMask_))

	column.SortDirectionsAvailCount = 0
	column.SortDirectionsAvailMask = 0
	column.SortDirectionsAvailList = 0
	if btest(table.Flags, ImGuiTableFlags.Sortable) then
		local count, mask, list = 0, 0, 0
		local Asc, Desc = ImGuiSortDirection.Ascending, ImGuiSortDirection.Descending
		if btest(flags, ImGuiTableColumnFlags.PreferSortAscending) and not btest(flags, ImGuiTableColumnFlags.NoSortAscending) then
			mask = bor(mask, lshift(1, Asc)); list = bor(list, lshift(Asc, lshift(count, 1))); count += 1
		end
		if btest(flags, ImGuiTableColumnFlags.PreferSortDescending) and not btest(flags, ImGuiTableColumnFlags.NoSortDescending) then
			mask = bor(mask, lshift(1, Desc)); list = bor(list, lshift(Desc, lshift(count, 1))); count += 1
		end
		if not btest(flags, ImGuiTableColumnFlags.PreferSortAscending) and not btest(flags, ImGuiTableColumnFlags.NoSortAscending) then
			mask = bor(mask, lshift(1, Asc)); list = bor(list, lshift(Asc, lshift(count, 1))); count += 1
		end
		if not btest(flags, ImGuiTableColumnFlags.PreferSortDescending) and not btest(flags, ImGuiTableColumnFlags.NoSortDescending) then
			mask = bor(mask, lshift(1, Desc)); list = bor(list, lshift(Desc, lshift(count, 1))); count += 1
		end
		if btest(table.Flags, ImGuiTableFlags.SortTristate) or count == 0 then
			mask = bor(mask, lshift(1, ImGuiSortDirection.None)); count += 1
		end
		column.SortDirectionsAvailList = band(list, 0xFF)
		column.SortDirectionsAvailMask = band(mask, 0xFF)
		column.SortDirectionsAvailCount = band(count, 0xFF)
		ImGui.TableFixColumnSortDirection(table, column)
	end
end

function ImGui.TableUpdateLayout(table)
	local g = ImGui.GImGui
	local temp_data = table.TempData
	assert(table.IsLayoutLocked == false)
	local columns_count = table.ColumnsCount
	local columns = table.Columns

	if temp_data.ReconcileColumnsRequests.Size > 0 then
		ImGui.TableReconcileColumns(table)
	end
	if temp_data.OldColumnsRawData then
		temp_data.OldColumnsRawData = nil
		temp_data.OldColumnsData = nil
	end

	if table.IsSettingsRequestLoad then
		ImGui.TableLoadSettingsForColumns(table)
	end
	if table.IsInitializing or table.IsSettingsRequestLoad then
		for n = 1, columns_count do
			local column = columns[n]
			local init_flags
			if table.IsSettingsRequestLoad then
				init_flags = column.IsLoadedSettings and bnot(table.SettingsLoadedFlags) or bnot(0)
			else
				init_flags = column.IsJustCreated and bnot(0) or 0
			end
			ImGui.TableInitColumnDefaults(table, column, init_flags)
		end
		ImGui.TableFixDisplayOrder(table)
		table.IsSettingsRequestLoad = false
	end

	ImGui.TableApplyQueuedRequests(table)

	local new_ref_scale_unit = g.FontSize
	if table.RefScale ~= 0.0 and table.RefScale ~= new_ref_scale_unit then
		local scale_factor = new_ref_scale_unit / table.RefScale
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventTable) then
			ImGui.DebugLog("[table] 0x%08X RefScale %.3f -> %.3f, scaling width by %.3f\n", table.ID, table.RefScale, new_ref_scale_unit, scale_factor)
		end
		for n = 1, columns_count do
			columns[n].WidthRequest = columns[n].WidthRequest * scale_factor
		end
	end
	table.RefScale = new_ref_scale_unit

	local table_sizing_policy = band(table.Flags, ImGuiTableFlags.SizingMask_)
	table.IsDefaultDisplayOrder = true
	table.IsDefaultVisibility = true
	table.ColumnsEnabledCount = 0
	ImBitArrayClearAllBits(table.EnabledMaskByIndex, columns_count)
	ImBitArrayClearAllBits(table.EnabledMaskByDisplayOrder, columns_count)
	table.LeftMostEnabledColumn = -1
	table.MinColumnWidth = ImMax(1.0, g.Style.FramePadding.x * 1.0)

	local count_fixed = 0
	local count_stretch = 0
	local prev_visible_column_idx = -1
	local has_auto_fit_request = false
	local has_resizable = false
	local stretch_sum_width_auto = 0.0
	local fixed_max_width_auto = 0.0
	local force_enabled_column_n = table.DisplayOrderToIndex[1]
	for column_n = 0, columns_count - 1 do
		local column = columns[column_n + 1]
		local column_flags = if table.DeclColumnsCount <= column_n then 0 else column.Flags
		local user_enabled = column.IsUserEnabledNextFrame or not btest(table.Flags, ImGuiTableFlags.Hideable) or btest(column_flags, ImGuiTableColumnFlags.NoHide)
		if user_enabled and not btest(column_flags, ImGuiTableColumnFlags.Disabled) then
			force_enabled_column_n = -1
			break
		end
	end
	for order_n = 0, columns_count - 1 do
		local column_n = table.DisplayOrderToIndex[order_n + 1]
		local column = columns[column_n + 1]

		if table.DeclColumnsCount <= column_n then
			ImGui.TableSetupColumnFlags(table, column, ImGuiTableColumnFlags.None)
			column.NameOffset = -1
			column.ID = 0
			column.UserData = 0
			column.InitStretchWeightOrWidth = -1.0
		end

		if not btest(table.Flags, ImGuiTableFlags.Hideable) or btest(column.Flags, ImGuiTableColumnFlags.NoHide) then
			column.IsUserEnabledNextFrame = true
		end
		if column.IsUserEnabled ~= column.IsUserEnabledNextFrame then
			column.IsUserEnabled = column.IsUserEnabledNextFrame
			table.IsSettingsDirty = true
		end
		column.IsEnabled = (column.IsUserEnabled and not btest(column.Flags, ImGuiTableColumnFlags.Disabled)) or column_n == force_enabled_column_n
		column.IsJustCreated = false

		if column.IsEnabled ~= (not btest(column.Flags, ImGuiTableColumnFlags.DefaultHide)) then
			table.IsDefaultVisibility = false
		end
		if column_n ~= order_n then
			table.IsDefaultDisplayOrder = false
		end

		if column.SortOrder ~= -1 and not column.IsEnabled then
			table.IsSortSpecsDirty = true
		end
		if column.SortOrder > 0 and not btest(table.Flags, ImGuiTableFlags.SortMulti) then
			table.IsSortSpecsDirty = true
		end

		local start_auto_fit
		if btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) then
			start_auto_fit = column.WidthRequest < 0.0
		else
			start_auto_fit = column.StretchWeight < 0.0
		end
		if start_auto_fit then
			column.AutoFitQueue = 7
			column.CannotSkipItemsQueue = 7
		end

		if not column.IsEnabled then
			column.IndexWithinEnabledSet = -1
			continue
		end

		column.PrevEnabledColumn = prev_visible_column_idx
		column.NextEnabledColumn = -1
		if prev_visible_column_idx ~= -1 then
			columns[prev_visible_column_idx + 1].NextEnabledColumn = column_n
		else
			table.LeftMostEnabledColumn = column_n
		end
		column.IndexWithinEnabledSet = table.ColumnsEnabledCount
		table.ColumnsEnabledCount += 1
		ImBitArraySetBit(table.EnabledMaskByIndex, column_n)
		ImBitArraySetBit(table.EnabledMaskByDisplayOrder, column.DisplayOrder)
		prev_visible_column_idx = column_n
		assert(column.IndexWithinEnabledSet <= column.DisplayOrder)

		if not column.IsPreserveWidthAuto and table.InstanceCurrent == 0 then
			column.WidthAuto = ImGui.TableGetColumnWidthAuto(table, column)
		end

		local column_is_resizable = not btest(column.Flags, ImGuiTableColumnFlags.NoResize)
		if column_is_resizable then
			has_resizable = true
		end
		if btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) and column.InitStretchWeightOrWidth > 0.0 and not column_is_resizable then
			column.WidthAuto = column.InitStretchWeightOrWidth
		end

		if column.AutoFitQueue ~= 0 then
			has_auto_fit_request = true
		end
		if btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) then
			stretch_sum_width_auto += column.WidthAuto
			count_stretch += 1
		else
			fixed_max_width_auto = ImMax(fixed_max_width_auto, column.WidthAuto)
			count_fixed += 1
		end
	end
	if btest(table.Flags, ImGuiTableFlags.Sortable) and table.SortSpecsCount == 0 and not btest(table.Flags, ImGuiTableFlags.SortTristate) then
		table.IsSortSpecsDirty = true
	end
	table.RightMostEnabledColumn = prev_visible_column_idx
	assert(table.LeftMostEnabledColumn >= 0 and table.RightMostEnabledColumn >= 0)

	if has_auto_fit_request and table.OuterWindow ~= table.InnerWindow then
		table.InnerWindow.SkipItems = false
	end
	if has_auto_fit_request then
		table.IsSettingsDirty = true
	end

	local sum_width_requests = 0.0
	local stretch_sum_weights = 0.0
	table.LeftMostStretchedColumn = -1
	table.RightMostStretchedColumn = -1
	for column_n = 0, columns_count - 1 do
		if not ImBitArrayTestBit(table.EnabledMaskByIndex, column_n) then
			continue
		end
		local column = columns[column_n + 1]

		local column_is_resizable = not btest(column.Flags, ImGuiTableColumnFlags.NoResize)
		if btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) then
			local width_auto = column.WidthAuto
			if table_sizing_policy == ImGuiTableFlags.SizingFixedSame and (column.AutoFitQueue ~= 0 or not column_is_resizable) then
				width_auto = fixed_max_width_auto
			end

			if column.AutoFitQueue ~= 0 then
				column.WidthRequest = width_auto
			elseif btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) and not column_is_resizable and column.IsRequestOutput then
				column.WidthRequest = width_auto
			end

			if column.AutoFitQueue > 1 and table.IsInitializing and not column.IsPreserveWidthAuto then
				column.WidthRequest = ImMax(column.WidthRequest, table.MinColumnWidth * 4.0)
			end
			sum_width_requests += column.WidthRequest
		else
			if column.AutoFitQueue ~= 0 or column.StretchWeight < 0.0 or not column_is_resizable then
				if column.InitStretchWeightOrWidth > 0.0 then
					column.StretchWeight = column.InitStretchWeightOrWidth
				elseif table_sizing_policy == ImGuiTableFlags.SizingStretchProp then
					column.StretchWeight = (column.WidthAuto / stretch_sum_width_auto) * count_stretch
				else
					column.StretchWeight = 1.0
				end
			end

			stretch_sum_weights += column.StretchWeight
			if table.LeftMostStretchedColumn == -1 or columns[table.LeftMostStretchedColumn + 1].DisplayOrder > column.DisplayOrder then
				table.LeftMostStretchedColumn = column_n
			end
			if table.RightMostStretchedColumn == -1 or columns[table.RightMostStretchedColumn + 1].DisplayOrder < column.DisplayOrder then
				table.RightMostStretchedColumn = column_n
			end
		end
		column.IsPreserveWidthAuto = false
		sum_width_requests += table.CellPaddingX * 2.0
	end
	table.ColumnsEnabledFixedCount = count_fixed
	table.ColumnsStretchSumWeights = stretch_sum_weights

	local work_rect = table.WorkRect
	local width_spacings = (table.OuterPaddingX * 2.0) + (table.CellSpacingX1 + table.CellSpacingX2) * (table.ColumnsEnabledCount - 1)
	local width_removed = (table.HasScrollbarYPrev and not table.InnerWindow.ScrollbarY) and g.Style.ScrollbarSize or 0.0
	local width_avail = ImMax(1.0, ((btest(table.Flags, ImGuiTableFlags.ScrollX) and table.InnerWidth == 0.0) and table.InnerClipRect:GetWidth() or work_rect:GetWidth()) - width_removed)
	local width_avail_for_stretched_columns = width_avail - width_spacings - sum_width_requests
	local width_remaining_for_stretched_columns = width_avail_for_stretched_columns
	table.ColumnsGivenWidth = width_spacings + (table.CellPaddingX * 2.0) * table.ColumnsEnabledCount
	for column_n = 0, columns_count - 1 do
		if not ImBitArrayTestBit(table.EnabledMaskByIndex, column_n) then
			continue
		end
		local column = columns[column_n + 1]

		if btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) then
			local weight_ratio = column.StretchWeight / stretch_sum_weights
			column.WidthRequest = IM_TRUNC(ImMax(width_avail_for_stretched_columns * weight_ratio, table.MinColumnWidth) + 0.01)
			width_remaining_for_stretched_columns -= column.WidthRequest
		end

		if column.NextEnabledColumn == -1 and table.LeftMostStretchedColumn ~= -1 then
			column.Flags = bor(column.Flags, ImGuiTableColumnFlags.NoDirectResize_)
		end

		column.WidthGiven = ImTrunc(ImMax(column.WidthRequest, table.MinColumnWidth))
		table.ColumnsGivenWidth += column.WidthGiven
	end

	if width_remaining_for_stretched_columns >= 1.0 and not btest(table.Flags, ImGuiTableFlags.PreciseWidths) then
		local order_n = columns_count - 1
		while stretch_sum_weights > 0.0 and width_remaining_for_stretched_columns >= 1.0 and order_n >= 0 do
			if ImBitArrayTestBit(table.EnabledMaskByDisplayOrder, order_n) then
				local column = columns[table.DisplayOrderToIndex[order_n + 1] + 1]
				if btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) then
					column.WidthRequest += 1.0
					column.WidthGiven += 1.0
					width_remaining_for_stretched_columns -= 1.0
				end
			end
			order_n -= 1
		end
	end

	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	table_instance.HoveredRowLast = table_instance.HoveredRowNext
	table_instance.HoveredRowNext = -1
	table.HoveredColumnBody = -1
	table.HoveredColumnBorder = -1
	local mouse_hit_rect = ImRect.fromXY(table.OuterRect.Min.x, table.OuterRect.Min.y, table.OuterRect.Max.x, ImMax(table.OuterRect.Max.y, table.OuterRect.Min.y + table_instance.LastOuterHeight))
	local backup_active_id = g.ActiveId
	g.ActiveId = 0
	local is_hovering_table = ImGui.ItemHoverable(mouse_hit_rect, 0, ImGuiItemFlags.None)
	g.ActiveId = backup_active_id

	local mouse_skewed_x = g.IO.MousePos.x
	if table.AngledHeadersHeight > 0.0 then
		if g.IO.MousePos.y >= table.OuterRect.Min.y and g.IO.MousePos.y <= table.OuterRect.Min.y + table.AngledHeadersHeight then
			mouse_skewed_x += ImTrunc((table.OuterRect.Min.y + table.AngledHeadersHeight - g.IO.MousePos.y) * table.AngledHeadersSlope)
		end
	end

	local has_at_least_one_column_requesting_output = false
	local offset_x_frozen = (table.FreezeColumnsCount > 0)
	local offset_x = ((table.FreezeColumnsCount > 0) and table.OuterRect.Min.x or work_rect.Min.x) + table.OuterPaddingX - table.CellSpacingX1
	local host_clip_rect = table.InnerClipRect
	ImBitArrayClearAllBits(table.VisibleMaskByIndex, columns_count)
	for order_n = 0, columns_count - 1 do
		local column_n = table.DisplayOrderToIndex[order_n + 1]
		local column = columns[column_n + 1]

		column.NavLayerCurrent = (table.FreezeRowsCount > 0) and ImGuiNavLayer.Menu or table.NavLayer

		if offset_x_frozen and table.FreezeColumnsCount == order_n then
			offset_x += work_rect.Min.x - table.OuterRect.Min.x
			offset_x_frozen = false
		end

		column.Flags = band(column.Flags, bnot(ImGuiTableColumnFlags.StatusMask_))

		if not ImBitArrayTestBit(table.EnabledMaskByDisplayOrder, order_n) then
			column.MinX = offset_x
			column.MaxX = offset_x
			column.WorkMinX = offset_x
			column.WidthGiven = 0.0
			column.ClipRect = ImRect.fromXY(offset_x, work_rect.Min.y, offset_x, FLT_MAX):ClippedWithFull(host_clip_rect)
			column.IsVisibleX = false
			column.IsVisibleY = false
			column.IsRequestOutput = false
			column.IsSkipItems = true
			column.ItemWidth = 1.0
			continue
		end

		column.MinX = offset_x

		column.WidthMax = ImGui.TableCalcMaxColumnWidth(table, column_n)
		column.WidthGiven = ImMin(column.WidthGiven, column.WidthMax)
		column.WidthGiven = ImMax(column.WidthGiven, ImMin(column.WidthRequest, table.MinColumnWidth))
		column.MaxX = offset_x + column.WidthGiven + table.CellSpacingX1 + table.CellSpacingX2 + table.CellPaddingX * 2.0

		local previous_instance_work_min_x = column.WorkMinX
		column.WorkMinX = column.MinX + table.CellPaddingX + table.CellSpacingX1
		column.WorkMaxX = column.MaxX - table.CellPaddingX - table.CellSpacingX2
		column.ItemWidth = ImTrunc(column.WidthGiven * 0.65)
		column.ClipRect = ImRect.fromXY(column.MinX, work_rect.Min.y, column.MaxX, FLT_MAX):ClippedWithFull(host_clip_rect)

		column.IsVisibleX = (column.ClipRect.Max.x > column.ClipRect.Min.x)
		column.IsVisibleY = true
		local is_visible = column.IsVisibleX
		if is_visible then
			ImBitArraySetBit(table.VisibleMaskByIndex, column_n)
		end

		column.IsRequestOutput = is_visible or column.AutoFitQueue ~= 0 or column.CannotSkipItemsQueue ~= 0

		column.IsSkipItems = not column.IsEnabled or table.HostSkipItems
		if column.IsSkipItems then
			assert(not is_visible)
		end
		if column.IsRequestOutput and not column.IsSkipItems then
			has_at_least_one_column_requesting_output = true
		end

		column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsEnabled)
		if is_visible then
			column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsVisible)
		end
		if column.SortOrder ~= -1 then
			column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsSorted)
		end

		if is_hovering_table and mouse_skewed_x >= column.ClipRect.Min.x and mouse_skewed_x < column.ClipRect.Max.x then
			column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsHovered)
			table.HoveredColumnBody = column_n
		end

		if table.InstanceCurrent == 0 then
			column.ContentMaxXFrozen = column.WorkMinX
			column.ContentMaxXUnfrozen = column.WorkMinX
			column.ContentMaxXHeadersUsed = column.WorkMinX
			column.ContentMaxXHeadersIdeal = column.WorkMinX
		else
			local offset_from_previous_instance = column.WorkMinX - previous_instance_work_min_x
			column.ContentMaxXFrozen += offset_from_previous_instance
			column.ContentMaxXUnfrozen += offset_from_previous_instance
			column.ContentMaxXHeadersUsed += offset_from_previous_instance
			column.ContentMaxXHeadersIdeal += offset_from_previous_instance
		end

		if table.HostSkipItems == false and table.InstanceCurrent == 0 then
			column.AutoFitQueue = rshift(column.AutoFitQueue, 1)
			column.CannotSkipItemsQueue = rshift(column.CannotSkipItemsQueue, 1)
		end

		if order_n < table.FreezeColumnsCount then
			host_clip_rect = host_clip_rect:WithMinX(ImClamp(column.MaxX + TABLE_BORDER_SIZE, host_clip_rect.Min.x, host_clip_rect.Max.x))
		end

		offset_x += column.WidthGiven + table.CellSpacingX1 + table.CellSpacingX2 + table.CellPaddingX * 2.0
	end

	if has_at_least_one_column_requesting_output == false then
		columns[table.LeftMostEnabledColumn + 1].IsRequestOutput = true
		columns[table.LeftMostEnabledColumn + 1].IsSkipItems = false
	end

	local unused_x1 = ImMax(table.WorkRect.Min.x, columns[table.RightMostEnabledColumn + 1].ClipRect.Max.x)
	if is_hovering_table and table.HoveredColumnBody == -1 then
		if mouse_skewed_x >= unused_x1 then
			table.HoveredColumnBody = columns_count
		end
	end
	if has_resizable == false and btest(table.Flags, ImGuiTableFlags.Resizable) then
		table.Flags = band(table.Flags, bnot(ImGuiTableFlags.Resizable))
	end

	table.IsActiveIdAliveBeforeTable = (g.ActiveIdIsAlive ~= 0)

	if table.RightMostStretchedColumn ~= -1 then
		table.Flags = band(table.Flags, bnot(ImGuiTableFlags.NoHostExtendX))
	end
	if btest(table.Flags, ImGuiTableFlags.NoHostExtendX) then
		table.OuterRect = table.OuterRect:WithMaxX(unused_x1)
		table.WorkRect = table.WorkRect:WithMaxX(unused_x1)
		table.InnerClipRect = table.InnerClipRect:WithMaxX(ImMin(table.InnerClipRect.Max.x, unused_x1))
	end
	table.InnerWindow.ParentWorkRect = table.WorkRect
	table.BorderX1 = table.InnerClipRect.Min.x
	table.BorderX2 = table.InnerClipRect.Max.x

	local window_content_max_y
	if btest(table.Flags, ImGuiTableFlags.NoHostExtendY) then
		window_content_max_y = table.OuterRect.Max.y
	else
		window_content_max_y = ImMax(table.InnerWindow.ContentRegionRect.Max.y, btest(table.Flags, ImGuiTableFlags.ScrollY) and 0.0 or table.OuterRect.Max.y)
	end
	local iw_work_rect = table.InnerWindow.WorkRect
	table.InnerWindow.WorkRect = iw_work_rect:WithMaxY(ImClamp(window_content_max_y - g.Style.CellPadding.y, iw_work_rect.Min.y, iw_work_rect.Max.y))

	ImGui.TableSetupDrawChannels(table)

	if btest(table.Flags, ImGuiTableFlags.Resizable) then
		ImGui.TableUpdateBorders(table)
	end
	table_instance.LastTopHeadersRowHeight = 0.0
	table.IsLayoutLocked = true
	table.IsUsingHeaders = false

	table.HighlightColumnHeader = -1
	if table.IsContextPopupOpen and table.ContextPopupColumn ~= -1 and table.InstanceInteracted == table.InstanceCurrent then
		table.HighlightColumnHeader = table.ContextPopupColumn
	elseif btest(table.Flags, ImGuiTableFlags.HighlightHoveredColumn) and table.HoveredColumnBody ~= -1 and table.HoveredColumnBody ~= columns_count and table.HoveredColumnBorder == -1 then
		if g.ActiveId == 0 or (table.IsActiveIdInTable or g.DragDropActive) then
			table.HighlightColumnHeader = table.HoveredColumnBody
		end
	end

	if table.DisableDefaultContextMenu == false and ImGui.TableBeginContextMenuPopup(table) then
		ImGui.TableDrawDefaultContextMenu(table, table.Flags)
		ImGui.EndPopup()
	end

	if table.IsSortSpecsDirty and btest(table.Flags, ImGuiTableFlags.Sortable) then
		ImGui.TableSortSpecsBuild(table)
	end

	if table.FreezeColumnsRequest > 0 then
		table.InnerWindow.DecoInnerSizeX1 = columns[table.DisplayOrderToIndex[table.FreezeColumnsRequest] + 1].MaxX - table.OuterRect.Min.x
	end
	if table.FreezeRowsRequest > 0 then
		table.InnerWindow.DecoInnerSizeY1 = table_instance.LastFrozenHeight
	end
	table_instance.LastFrozenHeight = 0.0

	local inner_window = table.InnerWindow
	local bs = g.BoxSelectState
	if bs.Window == inner_window and bs.UnclipMode then
		ImGui.TableApplyExternalUnclipRect(table, bs.UnclipRect)
	end

	if btest(table.Flags, ImGuiTableFlags.NoClip) then
		table.DrawSplitter:SetCurrentChannel(inner_window.DrawList, TABLE_DRAW_CHANNEL_NOCLIP)
	else
		inner_window.DrawList:PushClipRect(inner_window.InnerClipRect.Min, inner_window.InnerClipRect.Max, false)
	end
end

function ImGui.TableApplyExternalUnclipRect(table, rect)
	if rect:IsInverted() then
		return rect
	end
	for column_n = 0, table.ColumnsCount - 1 do
		local column = table.Columns[column_n + 1]
		if not column.IsRequestOutput then
			if rect:Overlaps(ImRect.fromXY(column.MinX, table.WorkRect.Min.y, column.MaxX, FLT_MAX)) then
				column.IsRequestOutput = true
			end
		end
	end
	return rect
end

function ImGui.TableUpdateBorders(table)
	local g = ImGui.GImGui
	assert(btest(table.Flags, ImGuiTableFlags.Resizable))

	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	local hit_half_width = ImTrunc(TABLE_RESIZE_SEPARATOR_HALF_THICKNESS * g.CurrentDpiScale)
	local hit_y1 = ((table.FreezeRowsCount >= 1) and table.OuterRect.Min.y or table.WorkRect.Min.y) + table.AngledHeadersHeight
	local hit_y2_body = ImMax(table.OuterRect.Max.y, hit_y1 + table_instance.LastOuterHeight - table.AngledHeadersHeight)
	local hit_y2_head = hit_y1 + table_instance.LastTopHeadersRowHeight

	for order_n = 0, table.ColumnsCount - 1 do
		if not ImBitArrayTestBit(table.EnabledMaskByDisplayOrder, order_n) then
			continue
		end

		local column_n = table.DisplayOrderToIndex[order_n + 1]
		local column = table.Columns[column_n + 1]
		if btest(column.Flags, bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoDirectResize_)) then
			continue
		end

		local border_y2_hit = btest(table.Flags, ImGuiTableFlags.NoBordersInBody) and hit_y2_head or hit_y2_body
		if btest(table.Flags, ImGuiTableFlags.NoBordersInBody) and table.IsUsingHeaders == false then
			continue
		end

		if not column.IsVisibleX and table.LastResizedColumn ~= column_n then
			continue
		end

		local column_id = ImGui.TableGetColumnResizeID(table, column_n, table.InstanceCurrent)
		local hit_rect = ImRect.fromXY(column.MaxX - hit_half_width, hit_y1, column.MaxX + hit_half_width, border_y2_hit)
		ImGui.ItemAdd(hit_rect, column_id, nil, ImGuiItemFlags.NoNav)

		local pressed, hovered, held = ImGui.ButtonBehavior(hit_rect, column_id, nil, nil, bor(ImGuiButtonFlags.FlattenChildren, ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.PressedOnDoubleClick, ImGuiButtonFlags.NoNavFocus))
		if pressed and ImGui.IsMouseDoubleClicked(0) then
			ImGui.TableSetColumnWidthAutoSingle(table, column_n)
			ImGui.ClearActiveID()
			held = false
		end
		if held then
			if table.LastResizedColumn == -1 then
				table.ResizeLockMinContentsX2 = (table.RightMostEnabledColumn ~= -1) and table.Columns[table.RightMostEnabledColumn + 1].MaxX or -FLT_MAX
			end
			table.ResizedColumn = column_n
			table.InstanceInteracted = table.InstanceCurrent
		end
		if (hovered and g.HoveredIdTimer > TABLE_RESIZE_SEPARATOR_FEEDBACK_TIMER) or held then
			table.HoveredColumnBorder = column_n
			ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
		end
	end
end

function ImGui.EndTable()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if table == nil then
		UserError("EndTable() call should only be done while in BeginTable() scope!")
		return
	end

	if not table.IsLayoutLocked then
		ImGui.TableUpdateLayout(table)
	end

	local flags = table.Flags
	local inner_window = table.InnerWindow
	local outer_window = table.OuterWindow
	local temp_data = table.TempData
	assert(inner_window == g.CurrentWindow and inner_window.ID == temp_data.WindowID)
	assert(outer_window == inner_window or outer_window == inner_window.ParentWindow)

	if table.IsInsideRow then
		ImGui.TableEndRow(table)
	end

	if btest(flags, ImGuiTableFlags.ContextMenuInBody) then
		if table.HoveredColumnBody ~= -1 and not ImGui.IsAnyItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Right) then
			ImGui.TableOpenContextMenu(table.HoveredColumnBody)
		end
	end

	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	inner_window.DC.PrevLineSize = temp_data.HostBackupPrevLineSize
	inner_window.DC.CurrLineSize = temp_data.HostBackupCurrLineSize
	inner_window.DC.CursorMaxPos = temp_data.HostBackupCursorMaxPos
	local inner_content_max_y = ImCeil(table.RowPosY2)
	assert(table.RowPosY2 == inner_window.DC.CursorPos.y)
	if inner_window ~= outer_window then
		inner_window.DC.CursorMaxPos = ImVec2(inner_window.DC.CursorMaxPos.x, inner_content_max_y)
	elseif not btest(flags, ImGuiTableFlags.NoHostExtendY) then
		local max_y = ImMax(table.OuterRect.Max.y, inner_content_max_y)
		table.OuterRect = table.OuterRect:WithMaxY(max_y)
		table.InnerRect = table.InnerRect:WithMaxY(max_y)
	end
	table.WorkRect = table.WorkRect:WithMaxY(ImMax(table.WorkRect.Max.y, table.OuterRect.Max.y))
	table_instance.LastOuterHeight = table.OuterRect:GetHeight()

	if btest(table.Flags, ImGuiTableFlags.ScrollX) then
		local outer_padding_for_border = btest(table.Flags, ImGuiTableFlags.BordersOuterV) and TABLE_BORDER_SIZE or 0.0
		local max_pos_x = inner_window.DC.CursorMaxPos.x
		if table.RightMostEnabledColumn ~= -1 then
			max_pos_x = ImMax(max_pos_x, table.Columns[table.RightMostEnabledColumn + 1].WorkMaxX + table.CellPaddingX + table.OuterPaddingX - outer_padding_for_border)
		end
		if table.ResizedColumn ~= -1 then
			max_pos_x = ImMax(max_pos_x, table.ResizeLockMinContentsX2)
		end
		inner_window.DC.CursorMaxPos = ImVec2(max_pos_x + table.TempData.AngledHeadersExtraWidth, inner_window.DC.CursorMaxPos.y)
	end

	if not btest(flags, ImGuiTableFlags.NoClip) then
		inner_window.DrawList:PopClipRect()
	end
	inner_window.ClipRect = ImRect.fromVec4(inner_window.DrawList._ClipRectStack:back())

	if btest(flags, ImGuiTableFlags.Borders) then
		ImGui.TableDrawBorders(table)
	end

	local splitter = table.DrawSplitter
	splitter:SetCurrentChannel(inner_window.DrawList, 0)
	if not btest(table.Flags, ImGuiTableFlags.NoClip) then
		ImGui.TableMergeDrawChannels(table)
	end
	splitter:Merge(inner_window.DrawList)

	local auto_fit_width_for_fixed = 0.0
	local auto_fit_width_for_stretched = 0.0
	local auto_fit_width_for_stretched_min = 0.0
	for column_n = 0, table.ColumnsCount - 1 do
		if ImBitArrayTestBit(table.EnabledMaskByIndex, column_n) then
			local column = table.Columns[column_n + 1]
			local column_width_request
			if btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) and not btest(column.Flags, ImGuiTableColumnFlags.NoResize) then
				column_width_request = column.WidthRequest
			else
				column_width_request = ImGui.TableGetColumnWidthAuto(table, column)
			end
			if btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) then
				auto_fit_width_for_fixed += column_width_request
			else
				auto_fit_width_for_stretched += column_width_request
			end
			if btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) and btest(column.Flags, ImGuiTableColumnFlags.NoResize) then
				auto_fit_width_for_stretched_min = ImMax(auto_fit_width_for_stretched_min, column_width_request / (column.StretchWeight / table.ColumnsStretchSumWeights))
			end
		end
	end
	local width_spacings = (table.OuterPaddingX * 2.0) + (table.CellSpacingX1 + table.CellSpacingX2) * (table.ColumnsEnabledCount - 1)
	table.ColumnsAutoFitWidth = width_spacings + (table.CellPaddingX * 2.0) * table.ColumnsEnabledCount + auto_fit_width_for_fixed + ImMax(auto_fit_width_for_stretched, auto_fit_width_for_stretched_min)

	if not btest(table.Flags, ImGuiTableFlags.ScrollX) and inner_window ~= outer_window then
		inner_window.Scroll = ImVec2(0.0, inner_window.Scroll.y)
	elseif table.LastResizedColumn ~= -1 and table.ResizedColumn == -1 and inner_window.ScrollbarX and table.InstanceInteracted == table.InstanceCurrent then
		local neighbor_width_to_keep_visible = table.MinColumnWidth + table.CellPaddingX * 2.0
		local column = table.Columns[table.LastResizedColumn + 1]
		if column.MaxX < table.InnerClipRect.Min.x then
			ImGui.SetScrollFromPosX(inner_window, column.MaxX - inner_window.Pos.x - neighbor_width_to_keep_visible, 1.0)
		elseif column.MaxX > table.InnerClipRect.Max.x then
			ImGui.SetScrollFromPosX(inner_window, column.MaxX - inner_window.Pos.x + neighbor_width_to_keep_visible, 1.0)
		end
	end

	if table.ResizedColumn ~= -1 and table.InstanceCurrent == table.InstanceInteracted then
		local column = table.Columns[table.ResizedColumn + 1]
		local new_x2 = (g.IO.MousePos.x - g.ActiveIdClickOffset.x + ImTrunc(TABLE_RESIZE_SEPARATOR_HALF_THICKNESS * g.CurrentDpiScale))
		local new_width = ImTrunc(new_x2 - column.MinX - table.CellSpacingX1 - table.CellPaddingX * 2.0)
		table.ResizedColumnNextWidth = new_width
	end

	table.IsActiveIdInTable = (g.ActiveIdIsAlive ~= 0 and table.IsActiveIdAliveBeforeTable == false)

	if not (inner_window.IDStack:back() == table_instance.TableInstanceID) then
		UserError("Mismatching PushID/PopID!")
	end
	if not (outer_window.DC.ItemWidthStack.Size >= temp_data.HostBackupItemWidthStackSize) then
		UserError("Too many PopItemWidth!")
	end
	if table.InstanceCurrent > 0 then
		ImGui.PopID()
	end
	ImGui.PopID()

	local backup_outer_max_pos = outer_window.DC.CursorMaxPos
	inner_window.WorkRect = temp_data.HostBackupWorkRect
	inner_window.ParentWorkRect = temp_data.HostBackupParentWorkRect
	inner_window.SkipItems = table.HostSkipItems
	outer_window.DC.CursorPos = table.OuterRect.Min
	outer_window.DC.ItemWidth = temp_data.HostBackupItemWidth
	outer_window.DC.ItemWidthStack:resize(temp_data.HostBackupItemWidthStackSize)
	outer_window.DC.ColumnsOffset.x = temp_data.HostBackupColumnsOffset

	if inner_window ~= outer_window then
		local backup_nav_layers_active_mask = inner_window.DC.NavLayersActiveMask
		inner_window.DC.NavLayersActiveMask = bor(inner_window.DC.NavLayersActiveMask, lshift(1, table.NavLayer))
		g.CurrentTable = nil
		ImGui.EndChild()
		g.CurrentTable = table
		inner_window.DC.NavLayersActiveMask = backup_nav_layers_active_mask
	else
		inner_window.DC.TreeDepth -= 1
		ImGui.ItemSize(table.OuterRect:GetSize())
		ImGui.ItemAdd(table.OuterRect, 0)
	end

	if btest(table.Flags, ImGuiTableFlags.NoHostExtendX) then
		assert(not btest(table.Flags, ImGuiTableFlags.ScrollX))
		outer_window.DC.CursorMaxPos = ImVec2(ImMax(backup_outer_max_pos.x, table.OuterRect.Min.x + table.ColumnsAutoFitWidth), outer_window.DC.CursorMaxPos.y)
	elseif temp_data.UserOuterSize.x <= 0.0 then
		local outer_content_max_x = table.OuterRect.Min.x + table.ColumnsAutoFitWidth
		local decoration_size = table.TempData.AngledHeadersExtraWidth + ((inner_window ~= outer_window) and inner_window.ScrollbarSizes.x or 0.0)
		outer_window.DC.IdealMaxPos = ImVec2(ImMax(outer_window.DC.IdealMaxPos.x, outer_content_max_x + decoration_size - temp_data.UserOuterSize.x), outer_window.DC.IdealMaxPos.y)
		outer_window.DC.CursorMaxPos = ImVec2(ImMax(backup_outer_max_pos.x, ImMin(table.OuterRect.Max.x, outer_content_max_x + decoration_size)), outer_window.DC.CursorMaxPos.y)
	else
		outer_window.DC.CursorMaxPos = ImVec2(ImMax(backup_outer_max_pos.x, table.OuterRect.Max.x), outer_window.DC.CursorMaxPos.y)
	end
	if temp_data.UserOuterSize.y <= 0.0 then
		local outer_content_size_y = (inner_window == outer_window) and (inner_content_max_y - table.InnerRect.Min.y) or (inner_content_max_y - inner_window.DC.CursorStartPos.y)
		local outer_content_max_y = table.OuterRect.Min.y + outer_content_size_y
		local decoration_size = (inner_window ~= outer_window) and inner_window.ScrollbarSizes.y or 0.0
		outer_window.DC.IdealMaxPos = ImVec2(outer_window.DC.IdealMaxPos.x, ImMax(outer_window.DC.IdealMaxPos.y, outer_content_max_y + decoration_size - temp_data.UserOuterSize.y))
		outer_window.DC.CursorMaxPos = ImVec2(outer_window.DC.CursorMaxPos.x, ImMax(backup_outer_max_pos.y, ImMin(table.OuterRect.Max.y, outer_content_max_y + decoration_size)))
	else
		outer_window.DC.CursorMaxPos = ImVec2(outer_window.DC.CursorMaxPos.x, ImMax(backup_outer_max_pos.y, table.OuterRect.Max.y))
	end

	if table.IsSettingsDirty then
		ImGui.TableSaveSettings(table)
	end
	table.IsInitializing = false

	assert(g.CurrentWindow == outer_window and g.CurrentTable == table)
	assert(g.TablesTempDataStacked > 0)
	g.TablesTempDataStacked -= 1
	temp_data = (g.TablesTempDataStacked > 0) and g.TablesTempData[g.TablesTempDataStacked] or nil
	if temp_data and temp_data.WindowID == outer_window.ID then
		g.CurrentTable = g.Tables:GetByIndex(temp_data.TableIndex)
	else
		g.CurrentTable = nil
	end
	if g.CurrentTable then
		g.CurrentTable.TempData = temp_data
		g.CurrentTable.DrawSplitter = temp_data.DrawSplitter
	end
	outer_window.DC.CurrentTableIdx = g.CurrentTable and g.Tables:GetIndex(g.CurrentTable) or -1
	ImGui.NavUpdateCurrentWindowIsScrollPushableX()
end

function ImGui.TableInitColumnDefaults(table, column, init_mask)
	local flags = column.Flags
	if btest(init_mask, ImGuiTableFlags.Resizable) then
		local init_width_or_weight = column.InitStretchWeightOrWidth
		column.WidthRequest = (btest(flags, ImGuiTableColumnFlags.WidthFixed) and init_width_or_weight > 0.0) and init_width_or_weight or -1.0
		column.StretchWeight = (init_width_or_weight > 0.0 and btest(flags, ImGuiTableColumnFlags.WidthStretch)) and init_width_or_weight or -1.0
		if init_width_or_weight > 0.0 then
			column.AutoFitQueue = 0
		end
	end
	if btest(init_mask, ImGuiTableFlags.Reorderable) then
		column.DisplayOrder = btest(table.Flags, ImGuiTableFlags.Reorderable) and -1 or (tfind(table.Columns, column) - 1)
	end
	if btest(init_mask, ImGuiTableFlags.Hideable) then
		local enabled = not btest(flags, ImGuiTableColumnFlags.DefaultHide)
		column.IsUserEnabled = enabled
		column.IsUserEnabledNextFrame = enabled
	end
	if btest(init_mask, ImGuiTableFlags.Sortable) then
		column.SortOrder = btest(flags, ImGuiTableColumnFlags.DefaultSort) and 0 or -1
		if btest(flags, ImGuiTableColumnFlags.DefaultSort) then
			column.SortDirection = btest(flags, ImGuiTableColumnFlags.PreferSortDescending) and ImGuiSortDirection.Descending or ImGuiSortDirection.Ascending
		else
			column.SortDirection = ImGuiSortDirection.None
		end
	end
end

function ImGui.TableSetupColumnApply(table, idx, id, name_offset, flags, init_width_or_weight, user_data)
	local column = table.Columns[idx + 1]

	if table.IsDefaultSizingPolicy and band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 and band(flags, ImGuiTableFlags.ScrollX) == 0 then
		if not (init_width_or_weight <= 0.0) then
			UserError("TableSetupColumn(): can only specify width/weight if sizing policy is set explicitly in either Table or Column.")
			return
		end
	end

	if band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 and init_width_or_weight > 0.0 then
		if band(table.Flags, ImGuiTableFlags.SizingMask_) == ImGuiTableFlags.SizingFixedFit or band(table.Flags, ImGuiTableFlags.SizingMask_) == ImGuiTableFlags.SizingFixedSame then
			flags = bor(flags, ImGuiTableColumnFlags.WidthFixed)
		end
	end
	if btest(flags, ImGuiTableColumnFlags.AngledHeader) then
		flags = bor(flags, ImGuiTableColumnFlags.NoHeaderLabel)
		table.AngledHeadersCount += 1
	end

	ImGui.TableSetupColumnFlags(table, column, flags)
	column.ID = id
	column.UserData = user_data
	column.NameOffset = name_offset
	column.InitStretchWeightOrWidth = init_width_or_weight
end

function ImGui.TableSetupColumn(label, flags, init_width_or_weight, user_data)
	if flags == nil then flags = 0 end
	if init_width_or_weight == nil then init_width_or_weight = 0.0 end
	if user_data == nil then user_data = 0 end
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if table == nil then
		UserError("Call should only be done while in BeginTable() scope!")
		return
	end
	if not (table.DeclColumnsCount < table.ColumnsCount) then
		UserError("TableSetupColumn(): called too many times!")
		return
	end
	if not (table.IsLayoutLocked == false) then
		UserError("TableSetupColumn(): need to call before first row!")
		return
	end
	assert(band(flags, ImGuiTableColumnFlags.StatusMask_) == 0, "Illegal to pass StatusMask values to TableSetupColumn()")

	local name_offset = -1
	if label ~= nil and label ~= "" then
		name_offset = table.ColumnsNames:size()
		table.ColumnsNames:append(label .. "\0")
	end
	local column_id = (label ~= nil and label ~= "") and ImHashStr(label) or 0

	local column_idx = table.DeclColumnsCount
	table.DeclColumnsCount += 1
	local column = table.Columns[column_idx + 1]

	if table.IsReconcileMode == false and column.ID ~= column_id and not table.IsNewTable then
		table.IsReconcileMode = true
		table.TempData.ReconcileColumnsRequests:reserve(table.ColumnsCount - column_idx)
	end

	if table.IsReconcileMode == false then
		ImGui.TableSetupColumnApply(table, column_idx, column_id, name_offset, flags, init_width_or_weight, user_data)
		column.IsNeedReconcileSrc = false
		column.IsNeedReconcileDst = false
		if column_idx < OldColumnsSize(table.TempData) then
			table.TempData.OldColumnsData[column_idx + 1].IsNeedReconcileSrc = false
		end
		return
	end

	table.TempData.ReconcileColumnsRequests:push_back(Structs.ImGuiTableReconcileColumnData.new())
	local reconcile_data = table.TempData.ReconcileColumnsRequests:back()
	reconcile_data.ID = column_id
	reconcile_data.NameOffset = name_offset
	reconcile_data.Flags = flags
	reconcile_data.InitWidthOrWeight = init_width_or_weight
	reconcile_data.UserData = user_data
	reconcile_data.ColumnNewIdx = column_idx
	reconcile_data.ColumnOldIdx = -1
	column.NameOffset = name_offset
	column.IsNeedReconcileSrc = true
	column.IsNeedReconcileDst = true
end

function ImGui.TableReconcileColumns(table)
	local g = ImGui.GImGui
	local temp_data = table.TempData
	if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventTable) then
		ImGui.DebugLog("[table] Reconcile columns for table 0x%08X\n", table.ID)
	end

	local dst_columns = table.Columns
	local src_columns = (OldColumnsSize(table.TempData) == 0) and table.Columns or table.TempData.OldColumnsData
	local src_count = #src_columns

	local matches = 0
	local reconcile_requests = temp_data.ReconcileColumnsRequests
	for r = 1, reconcile_requests.Size do
		local reconcile_data = reconcile_requests[r]
		if reconcile_data.ID ~= 0 then
			for s = 1, src_count do
				local src_column = src_columns[s]
				if src_column.ID == reconcile_data.ID and src_column.IsNeedReconcileSrc then
					local dst_column = dst_columns[reconcile_data.ColumnNewIdx + 1]
					assert(src_column.IsNeedReconcileSrc and dst_column.IsNeedReconcileDst)
					src_column.IsNeedReconcileSrc = false
					dst_column.IsNeedReconcileDst = false
					reconcile_data.ColumnOldIdx = s - 1
					reconcile_data.ColumnOldData = src_column:Copy()
					matches += 1
					break
				end
			end
		end
	end

	local dst_idx = 0
	if matches ~= reconcile_requests.Size then
		for s = 1, src_count do
			local src_column = src_columns[s]
			if not src_column.IsNeedReconcileSrc then
				continue
			end
			while dst_idx < reconcile_requests.Size and reconcile_requests[dst_idx + 1].ColumnOldIdx ~= -1 do
				dst_idx += 1
			end
			if dst_idx == reconcile_requests.Size then
				break
			end
			local reconcile_data = reconcile_requests[dst_idx + 1]
			local dst_column = dst_columns[reconcile_data.ColumnNewIdx + 1]
			assert(src_column.IsNeedReconcileSrc and dst_column.IsNeedReconcileDst)
			src_column.IsNeedReconcileSrc = false
			dst_column.IsNeedReconcileDst = false
			reconcile_data.ColumnOldIdx = s - 1
			reconcile_data.ColumnOldData = src_column:Copy()
		end
	end

	for r = 1, reconcile_requests.Size do
		local reconcile_data = reconcile_requests[r]
		table.Columns[reconcile_data.ColumnNewIdx + 1] = reconcile_data.ColumnOldData:Copy()
		ImGui.TableSetupColumnApply(table, reconcile_data.ColumnNewIdx, reconcile_data.ID, reconcile_data.NameOffset, reconcile_data.Flags, reconcile_data.InitWidthOrWeight, reconcile_data.UserData)
		if btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventTable) then
			ImGui.DebugLog("[table] - old %d -> new %d \"%s\"\n", reconcile_data.ColumnOldIdx, reconcile_data.ColumnNewIdx, ImGui.TableGetColumnName(table, reconcile_data.ColumnNewIdx))
		end
	end
	ImGui.TableFixDisplayOrder(table)
	table.IsSettingsDirty = true
	table.IsReconcileMode = false
	reconcile_requests:resize(0)
end

function ImGui.TableSetupScrollFreeze(columns, rows)
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if table == nil then
		UserError("Call should only be done while in BeginTable() scope!")
		return
	end
	assert(table.IsLayoutLocked == false, "TableSetupColumn(): need to call before first row!")
	assert(columns >= 0 and columns < IMGUI_TABLE_MAX_COLUMNS)
	assert(rows >= 0 and rows < 128)

	table.FreezeColumnsRequest = btest(table.Flags, ImGuiTableFlags.ScrollX) and ImMin(columns, table.ColumnsCount) or 0
	table.FreezeColumnsCount = (table.InnerWindow.Scroll.x ~= 0.0) and table.FreezeColumnsRequest or 0
	table.FreezeRowsRequest = btest(table.Flags, ImGuiTableFlags.ScrollY) and rows or 0
	table.FreezeRowsCount = (table.InnerWindow.Scroll.y ~= 0.0) and table.FreezeRowsRequest or 0
	table.IsUnfrozenRows = (table.FreezeRowsCount == 0)
end

function ImGui.TableGetColumnCount()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	return table and table.ColumnsCount or 0
end

function ImGui.TableGetColumnName(a, b)
	if type(a) == "table" then
		local table, column_n = a, b
		if table.IsLayoutLocked == false and column_n >= table.DeclColumnsCount then
			return ""
		end
		local column = table.Columns[column_n + 1]
		if column.NameOffset == -1 then
			return ""
		end
		local buf = table.ColumnsNames:c_str()
		local name_end = string.find(buf, "\0", column.NameOffset + 1, true)
		return string.sub(buf, column.NameOffset + 1, name_end and name_end - 1 or #buf)
	end
	local column_n = a
	if column_n == nil then column_n = -1 end
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return nil
	end
	if column_n < 0 then
		column_n = table.CurrentColumn
	end
	return ImGui.TableGetColumnName(table, column_n)
end

function ImGui.TableSetColumnEnabled(column_n, enabled)
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if table == nil then
		UserError("Call should only be done while in BeginTable() scope!")
		return
	end
	assert(btest(table.Flags, ImGuiTableFlags.Hideable))
	if column_n < 0 then
		column_n = table.CurrentColumn
	end
	assert(column_n >= 0 and column_n < table.ColumnsCount)
	local column = table.Columns[column_n + 1]
	column.IsUserEnabledNextFrame = enabled
end

function ImGui.TableGetColumnFlags(column_n)
	if column_n == nil then column_n = -1 end
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return ImGuiTableColumnFlags.None
	end
	if column_n < 0 then
		column_n = table.CurrentColumn
	end
	if column_n == table.ColumnsCount then
		return (table.HoveredColumnBody == column_n) and ImGuiTableColumnFlags.IsHovered or ImGuiTableColumnFlags.None
	end
	return table.Columns[column_n + 1].Flags
end

function ImGui.TableGetCellBgRect(table, column_n)
	local column = table.Columns[column_n + 1]
	local x1 = column.MinX
	local x2 = column.MaxX
	x1 = ImMax(x1, table.WorkRect.Min.x)
	x2 = ImMin(x2, table.WorkRect.Max.x)
	return ImRect.fromXY(x1, table.RowPosY1, x2, table.RowPosY2)
end

function ImGui.TableGetColumnResizeID(table, column_n, instance_no)
	if instance_no == nil then instance_no = 0 end
	assert(column_n >= 0 and column_n < table.ColumnsCount)
	local instance_id = ImGui.TableGetInstanceID(table, instance_no)
	return band(instance_id + 1 + column_n, 0xFFFFFFFF)
end

function ImGui.TableGetHoveredColumn()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return -1
	end
	return table.HoveredColumnBody
end

function ImGui.TableGetHoveredRow()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return -1
	end
	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	return table_instance.HoveredRowLast
end

function ImGui.TableSetBgColor(target, color, column_n)
	if column_n == nil then column_n = -1 end
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if table == nil then
		UserError("Call should only be done while in BeginTable() scope!")
		return
	end
	assert(target ~= ImGuiTableBgTarget.None)

	if color == IM_COL32_DISABLE then
		color = 0
	end

	if target == ImGuiTableBgTarget.CellBg then
		if table.RowPosY1 > table.InnerClipRect.Max.y then
			return
		end
		if column_n == -1 then
			column_n = table.CurrentColumn
		end
		if not ImBitArrayTestBit(table.VisibleMaskByIndex, column_n) then
			return
		end
		if table.RowCellDataCurrent < 0 or table.RowCellData[table.RowCellDataCurrent + 1].Column ~= column_n then
			table.RowCellDataCurrent += 1
		end
		local cell_data = table.RowCellData[table.RowCellDataCurrent + 1]
		cell_data.BgColor = color
		cell_data.Column = column_n
	elseif target == ImGuiTableBgTarget.RowBg0 or target == ImGuiTableBgTarget.RowBg1 then
		if table.RowPosY1 > table.InnerClipRect.Max.y then
			return
		end
		assert(column_n == -1)
		local bg_idx = (target == ImGuiTableBgTarget.RowBg1) and 1 or 0
		table.RowBgColor[bg_idx + 1] = color
	else
		assert(false)
	end
end

function ImGui.TableGetRowIndex()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return 0
	end
	return table.CurrentRow
end

function ImGui.TableNextRow(row_flags, row_min_height)
	if row_flags == nil then row_flags = 0 end
	if row_min_height == nil then row_min_height = 0.0 end
	local g = ImGui.GImGui
	local table = g.CurrentTable

	if not table.IsLayoutLocked then
		ImGui.TableUpdateLayout(table)
	end
	if table.IsInsideRow then
		ImGui.TableEndRow(table)
	end

	table.LastRowFlags = table.RowFlags
	table.RowFlags = row_flags
	table.RowCellPaddingY = g.Style.CellPadding.y
	table.RowMinHeight = row_min_height
	ImGui.TableBeginRow(table)

	table.RowPosY2 += table.RowCellPaddingY * 2.0
	table.RowPosY2 = ImMax(table.RowPosY2, table.RowPosY1 + row_min_height)

	table.InnerWindow.SkipItems = true
end

function ImGui.TableBeginRow(table)
	local window = table.InnerWindow
	assert(not table.IsInsideRow)

	table.CurrentRow += 1
	table.CurrentColumn = -1
	table.RowBgColor[1] = IM_COL32_DISABLE
	table.RowBgColor[2] = IM_COL32_DISABLE
	table.RowCellDataCurrent = -1
	table.IsInsideRow = true

	local next_y1 = table.RowPosY2
	if table.CurrentRow == 0 and table.FreezeRowsCount > 0 then
		next_y1 = table.OuterRect.Min.y
		window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, next_y1)
	end

	table.RowPosY1 = next_y1
	table.RowPosY2 = next_y1
	table.RowTextBaseline = 0.0
	table.RowIndentOffsetX = window.DC.Indent.x - table.HostIndentX

	window.DC.PrevLineTextBaseOffset = 0.0
	window.DC.CursorPosPrevLine = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + table.RowCellPaddingY)
	window.DC.PrevLineSize = ImVec2(0.0, 0.0)
	window.DC.CurrLineSize = ImVec2(0.0, 0.0)
	window.DC.IsSameLine = false
	window.DC.IsSetPos = false
	window.DC.CursorMaxPos = ImVec2(window.DC.CursorMaxPos.x, next_y1)

	if btest(table.RowFlags, ImGuiTableRowFlags.Headers) then
		ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, ImGui.GetColorU32(ImGuiCol.TableHeaderBg))
		if table.CurrentRow == 0 then
			table.IsUsingHeaders = true
		end
	end
end

function ImGui.TableEndRow(table)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(window == table.InnerWindow)
	assert(table.IsInsideRow)

	if table.CurrentColumn ~= -1 then
		ImGui.TableEndCell(table)
		table.CurrentColumn = -1
	end

	if g.LogEnabled then
		ImGui.LogRenderedText(nil, "|")
	end

	window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, table.RowPosY2)

	local bg_y1 = table.RowPosY1
	local bg_y2 = table.RowPosY2
	local unfreeze_rows_actual = (table.CurrentRow + 1 == table.FreezeRowsCount)
	local unfreeze_rows_request = (table.CurrentRow + 1 == table.FreezeRowsRequest)
	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	if btest(table.RowFlags, ImGuiTableRowFlags.Headers) and (table.CurrentRow == 0 or btest(table.LastRowFlags, ImGuiTableRowFlags.Headers)) then
		table_instance.LastTopHeadersRowHeight += bg_y2 - bg_y1
	end

	local is_visible = (bg_y2 >= table.InnerClipRect.Min.y and bg_y1 <= table.InnerClipRect.Max.y)
	if is_visible then
		if table.HoveredColumnBody ~= -1 and g.IO.MousePos.y >= bg_y1 and g.IO.MousePos.y < bg_y2 and table_instance.HoveredRowNext < 0 then
			table_instance.HoveredRowNext = table.CurrentRow
		end

		local bg_col0 = 0
		local bg_col1 = 0
		if table.RowBgColor[1] ~= IM_COL32_DISABLE then
			bg_col0 = table.RowBgColor[1]
		elseif btest(table.Flags, ImGuiTableFlags.RowBg) then
			bg_col0 = ImGui.GetColorU32(btest(table.RowBgColorCounter, 1) and ImGuiCol.TableRowBgAlt or ImGuiCol.TableRowBg)
		end
		if table.RowBgColor[2] ~= IM_COL32_DISABLE then
			bg_col1 = table.RowBgColor[2]
		end

		local top_border_col = 0
		local border_size = TABLE_BORDER_SIZE
		if table.CurrentRow > 0 and btest(table.Flags, ImGuiTableFlags.BordersInnerH) then
			top_border_col = btest(table.LastRowFlags, ImGuiTableRowFlags.Headers) and table.BorderColorStrong or table.BorderColorLight
		end

		local draw_cell_bg_color = table.RowCellDataCurrent >= 0
		local draw_strong_bottom_border = unfreeze_rows_actual
		if bor(bg_col0, bg_col1, top_border_col) ~= 0 or draw_strong_bottom_border or draw_cell_bg_color then
			if not btest(table.Flags, ImGuiTableFlags.NoClip) then
				window.DrawList._CmdHeader.ClipRect = table.Bg0ClipRectForDrawCmd:ToVec4()
			end
			table.DrawSplitter:SetCurrentChannel(window.DrawList, TABLE_DRAW_CHANNEL_BG0)
		end

		if bg_col0 ~= 0 or bg_col1 ~= 0 then
			local row_rect = ImRect.fromXY(table.WorkRect.Min.x, bg_y1, table.WorkRect.Max.x, bg_y2)
			row_rect = row_rect:ClippedWith(table.BgClipRect)
			if bg_col0 ~= 0 and row_rect.Min.y < row_rect.Max.y then
				window.DrawList:AddRectFilled(row_rect.Min, row_rect.Max, bg_col0)
			end
			if bg_col1 ~= 0 and row_rect.Min.y < row_rect.Max.y then
				window.DrawList:AddRectFilled(row_rect.Min, row_rect.Max, bg_col1)
			end
		end

		if draw_cell_bg_color then
			for i = 1, table.RowCellDataCurrent + 1 do
				local cell_data = table.RowCellData[i]
				local column = table.Columns[cell_data.Column + 1]
				local cell_bg_rect = ImGui.TableGetCellBgRect(table, cell_data.Column)
				cell_bg_rect = cell_bg_rect:ClippedWith(table.BgClipRect)
				cell_bg_rect = cell_bg_rect:WithMinX(ImMax(cell_bg_rect.Min.x, column.ClipRect.Min.x))
				cell_bg_rect = cell_bg_rect:WithMaxX(ImMin(cell_bg_rect.Max.x, column.MaxX))
				if cell_bg_rect.Min.y < cell_bg_rect.Max.y then
					window.DrawList:AddRectFilled(cell_bg_rect.Min, cell_bg_rect.Max, cell_data.BgColor)
				end
			end
		end

		if top_border_col ~= 0 and bg_y1 >= table.BgClipRect.Min.y and bg_y1 < table.BgClipRect.Max.y then
			window.DrawList:AddLineH(table.BorderX1, table.BorderX2, bg_y1, top_border_col, border_size)
		end

		if draw_strong_bottom_border and bg_y2 >= table.BgClipRect.Min.y and bg_y2 < table.BgClipRect.Max.y then
			window.DrawList:AddLineH(table.BorderX1, table.BorderX2, bg_y2, table.BorderColorStrong, border_size)
		end
	end

	if unfreeze_rows_request then
		assert(table.FreezeRowsRequest > 0)
		for column_n = 1, table.ColumnsCount do
			table.Columns[column_n].NavLayerCurrent = table.NavLayer
		end
		local y0 = ImMax(table.RowPosY2 + 1, table.InnerClipRect.Min.y)
		table_instance.LastFrozenHeight = y0 - table.OuterRect.Min.y

		if unfreeze_rows_actual then
			assert(table.IsUnfrozenRows == false)
			table.IsUnfrozenRows = true

			local min_y = ImMin(y0, table.InnerClipRect.Max.y)
			local max_y = table.InnerClipRect.Max.y
			table.BgClipRect = table.BgClipRect:WithMinY(min_y):WithMaxY(max_y)
			table.Bg2ClipRectForDrawCmd = table.Bg2ClipRectForDrawCmd:WithMinY(min_y):WithMaxY(max_y)
			table.Bg2DrawChannelCurrent = table.Bg2DrawChannelUnfrozen
			assert(table.Bg2ClipRectForDrawCmd.Min.y <= table.Bg2ClipRectForDrawCmd.Max.y)

			local row_height = table.RowPosY2 - table.RowPosY1
			table.RowPosY2 = table.WorkRect.Min.y + table.RowPosY2 - table.OuterRect.Min.y
			window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, table.RowPosY2)
			table.RowPosY1 = table.RowPosY2 - row_height
			for column_n = 1, table.ColumnsCount do
				local column = table.Columns[column_n]
				column.DrawChannelCurrent = column.DrawChannelUnfrozen
				column.ClipRect = column.ClipRect:WithMinY(table.Bg2ClipRectForDrawCmd.Min.y)
			end

			ImGui.SetWindowClipRectBeforeSetChannel(window, table.Columns[1].ClipRect)
			table.DrawSplitter:SetCurrentChannel(window.DrawList, table.Columns[1].DrawChannelCurrent)
		end
	end

	if not btest(table.RowFlags, ImGuiTableRowFlags.Headers) then
		table.RowBgColorCounter += 1
	end
	table.IsInsideRow = false
end

function ImGui.TableGetColumnIndex()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return 0
	end
	return table.CurrentColumn
end

function ImGui.TableSetColumnIndex(column_n)
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return false
	end

	if table.CurrentColumn ~= column_n then
		if table.CurrentColumn ~= -1 then
			ImGui.TableEndCell(table)
		end
		if not (column_n >= 0 and column_n < table.ColumnsCount) then
			UserError("TableSetColumnIndex() invalid column index!")
			return false
		end
		ImGui.TableBeginCell(table, column_n)
	end

	return table.Columns[column_n + 1].IsRequestOutput
end

function ImGui.TableNextColumn()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if not table then
		return false
	end

	if table.IsInsideRow and table.CurrentColumn + 1 < table.ColumnsCount then
		if table.CurrentColumn ~= -1 then
			ImGui.TableEndCell(table)
		end
		ImGui.TableBeginCell(table, table.CurrentColumn + 1)
	else
		ImGui.TableNextRow()
		ImGui.TableBeginCell(table, 0)
	end

	return table.Columns[table.CurrentColumn + 1].IsRequestOutput
end

function ImGui.TableBeginCell(table, column_n)
	local g = ImGui.GImGui
	local column = table.Columns[column_n + 1]
	local window = table.InnerWindow
	table.CurrentColumn = column_n

	local start_x = column.WorkMinX
	if btest(column.Flags, ImGuiTableColumnFlags.IndentEnable) then
		start_x += table.RowIndentOffsetX
	end

	local dc = window.DC
	dc.CursorPos = ImVec2(start_x, table.RowPosY1 + table.RowCellPaddingY)
	dc.CursorMaxPos = ImVec2(dc.CursorPos.x, dc.CursorMaxPos.y)
	dc.ColumnsOffset.x = start_x - window.Pos.x - dc.Indent.x
	dc.CursorPosPrevLine = ImVec2(dc.CursorPos.x, dc.CursorPosPrevLine.y)
	dc.CurrLineTextBaseOffset = table.RowTextBaseline
	dc.NavLayerCurrent = column.NavLayerCurrent

	window.WorkRect = ImRect.fromXY(column.WorkMinX, dc.CursorPos.y, column.WorkMaxX, window.WorkRect.Max.y)
	dc.ItemWidth = column.ItemWidth

	window.SkipItems = column.IsSkipItems
	if column.IsSkipItems then
		g.LastItemData.ID = 0
		g.LastItemData.StatusFlags = 0
	end

	if btest(table.Flags, ImGuiTableFlags.NoClip) then
		table.DrawSplitter:SetCurrentChannel(window.DrawList, TABLE_DRAW_CHANNEL_NOCLIP)
	else
		ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
		table.DrawSplitter:SetCurrentChannel(window.DrawList, column.DrawChannelCurrent)
	end

	if g.LogEnabled and not column.IsSkipItems then
		ImGui.LogRenderedText(dc.CursorPos, "|")
		g.LogLinePosY = FLT_MAX
	end
end

function ImGui.TableEndCell(table)
	local column = table.Columns[table.CurrentColumn + 1]
	local window = table.InnerWindow

	if window.DC.IsSetPos then
		ImGui.ErrorCheckUsingSetCursorPosToExtendParentBoundaries()
	end

	local max_pos_field
	if btest(table.RowFlags, ImGuiTableRowFlags.Headers) then
		max_pos_field = "ContentMaxXHeadersUsed"
	else
		max_pos_field = table.IsUnfrozenRows and "ContentMaxXUnfrozen" or "ContentMaxXFrozen"
	end
	column[max_pos_field] = ImMax(column[max_pos_field], window.DC.CursorMaxPos.x)
	if column.IsEnabled then
		table.RowPosY2 = ImMax(table.RowPosY2, window.DC.CursorMaxPos.y + table.RowCellPaddingY)
	end
	column.ItemWidth = window.DC.ItemWidth

	table.RowTextBaseline = ImMax(table.RowTextBaseline, window.DC.PrevLineTextBaseOffset)
end

function ImGui.TableCalcMaxColumnWidth(table, column_n)
	local column = table.Columns[column_n + 1]
	local max_width = FLT_MAX
	local min_column_distance = table.MinColumnWidth + table.CellPaddingX * 2.0 + table.CellSpacingX1 + table.CellSpacingX2
	if btest(table.Flags, ImGuiTableFlags.ScrollX) then
		if column.DisplayOrder < table.FreezeColumnsRequest then
			max_width = (table.InnerClipRect.Max.x - (table.FreezeColumnsRequest - column.DisplayOrder) * min_column_distance) - column.MinX
			max_width = max_width - table.OuterPaddingX - table.CellPaddingX - table.CellSpacingX2
		end
	elseif not btest(table.Flags, ImGuiTableFlags.NoKeepColumnsVisible) then
		max_width = table.WorkRect.Max.x - (table.ColumnsEnabledCount - column.IndexWithinEnabledSet - 1) * min_column_distance - column.MinX
		max_width -= table.CellSpacingX2
		max_width -= table.CellPaddingX * 2.0
		max_width -= table.OuterPaddingX
	end
	return max_width
end

function ImGui.TableGetColumnWidthAuto(table, column)
	local content_width_body = ImMax(column.ContentMaxXFrozen, column.ContentMaxXUnfrozen) - column.WorkMinX
	local content_width_headers = column.ContentMaxXHeadersIdeal - column.WorkMinX
	local width_auto = content_width_body
	if not btest(column.Flags, ImGuiTableColumnFlags.NoHeaderWidth) then
		width_auto = ImMax(width_auto, content_width_headers)
	end

	if btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) and column.InitStretchWeightOrWidth > 0.0 then
		if not btest(table.Flags, ImGuiTableFlags.Resizable) or btest(column.Flags, ImGuiTableColumnFlags.NoResize) then
			width_auto = column.InitStretchWeightOrWidth
		end
	end

	return ImMax(width_auto, table.MinColumnWidth)
end

function ImGui.TableSetColumnWidth(column_n, width)
	local g = ImGui.GImGui
	local table = g.CurrentTable
	assert(table ~= nil and table.IsLayoutLocked == false)
	assert(column_n >= 0 and column_n < table.ColumnsCount)
	local column_0 = table.Columns[column_n + 1]
	local column_0_width = width

	assert(table.MinColumnWidth > 0.0)
	local min_width = table.MinColumnWidth
	local max_width = ImMax(min_width, column_0.WidthMax)
	column_0_width = ImClamp(column_0_width, min_width, max_width)
	if column_0.WidthGiven == column_0_width or column_0.WidthRequest == column_0_width then
		return
	end

	local column_1 = (column_0.NextEnabledColumn ~= -1) and table.Columns[column_0.NextEnabledColumn + 1] or nil

	if btest(column_0.Flags, ImGuiTableColumnFlags.WidthFixed) then
		if not column_1 or table.LeftMostStretchedColumn == -1 or table.Columns[table.LeftMostStretchedColumn + 1].DisplayOrder >= column_0.DisplayOrder then
			column_0.WidthRequest = column_0_width
			table.IsSettingsDirty = true
			return
		end
	end

	if column_1 == nil then
		column_1 = (column_0.PrevEnabledColumn ~= -1) and table.Columns[column_0.PrevEnabledColumn + 1] or nil
	end
	if column_1 == nil then
		return
	end

	local column_1_width = ImMax(column_1.WidthRequest - (column_0_width - column_0.WidthRequest), min_width)
	column_0_width = column_0.WidthRequest + column_1.WidthRequest - column_1_width
	assert(column_0_width > 0.0 and column_1_width > 0.0)
	column_0.WidthRequest = column_0_width
	column_1.WidthRequest = column_1_width
	if btest(bor(column_0.Flags, column_1.Flags), ImGuiTableColumnFlags.WidthStretch) then
		ImGui.TableUpdateColumnsWeightFromWidth(table)
	end
	table.IsSettingsDirty = true
end

function ImGui.TableSetColumnWidthAutoSingle(table, column_n)
	local column = table.Columns[column_n + 1]
	if not column.IsEnabled then
		return
	end
	column.CannotSkipItemsQueue = 1
	table.AutoFitSingleColumn = column_n
end

function ImGui.TableSetColumnWidthAutoAll(table)
	for column_n = 1, table.ColumnsCount do
		local column = table.Columns[column_n]
		if not column.IsEnabled and not btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) then
			continue
		end
		column.CannotSkipItemsQueue = 1
		column.AutoFitQueue = 2
	end
end

function ImGui.TableUpdateColumnsWeightFromWidth(table)
	assert(table.LeftMostStretchedColumn ~= -1 and table.RightMostStretchedColumn ~= -1)

	local visible_weight = 0.0
	local visible_width = 0.0
	for column_n = 1, table.ColumnsCount do
		local column = table.Columns[column_n]
		if not column.IsEnabled or not btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) then
			continue
		end
		assert(column.StretchWeight > 0.0)
		visible_weight += column.StretchWeight
		visible_width += column.WidthRequest
	end
	assert(visible_weight > 0.0 and visible_width > 0.0)

	for column_n = 1, table.ColumnsCount do
		local column = table.Columns[column_n]
		if not column.IsEnabled or not btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) then
			continue
		end
		column.StretchWeight = (column.WidthRequest / visible_width) * visible_weight
		assert(column.StretchWeight > 0.0)
	end
end

return true
