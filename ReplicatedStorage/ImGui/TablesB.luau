--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImLerp = Base.ImMin, Base.ImMax, Base.ImLerp
local ImTrunc, ImRotate, ImTextCountLines = Base.ImTrunc, Base.ImRotate, Base.ImTextCountLines
local ImHashStr, ImFormatString, ImTruncToInt = Base.ImHashStr, Base.ImFormatString, Base.ImTruncToInt
local ImBitArrayTestBit, ImBitArraySetBit, ImBitArrayClearBit = Base.ImBitArrayTestBit, Base.ImBitArraySetBit, Base.ImBitArrayClearBit
local ImBitArraySetBitRange = Base.ImBitArraySetBitRange
local IM_COL32, IM_TRUNC, IM_ROUND = Base.IM_COL32, Base.IM_TRUNC, Base.IM_ROUND
local FLT_MAX, IM_PI = Base.FLT_MAX, Base.IM_PI
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTableColumnFlags = Enums.ImGuiTableColumnFlags
local ImGuiTableRowFlags = Enums.ImGuiTableRowFlags
local ImGuiTableBgTarget = Enums.ImGuiTableBgTarget
local ImGuiSortDirection = Enums.ImGuiSortDirection
local ImGuiCol = Enums.ImGuiCol
local ImGuiDir = Enums.ImGuiDir
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiNavRenderCursorFlags = Enums.ImGuiNavRenderCursorFlags
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiLocKey = Enums.ImGuiLocKey
local ImGuiInputSource = Enums.ImGuiInputSource
local ImGuiOldColumnFlags = Enums.ImGuiOldColumnFlags
local ImGuiMouseCursor = Enums.ImGuiMouseCursor

local table_create = table.create

local TABLE_DRAW_CHANNEL_BG0 = 0
local TABLE_DRAW_CHANNEL_BG2_FROZEN = 1
local TABLE_BORDER_SIZE = 1.0
local IMGUI_TABLE_MAX_COLUMNS = 512
local COLUMNS_HIT_RECT_HALF_THICKNESS = 4.0

local function UserErrorRet(cond, msg)
	if not cond then
		if ImGui.ErrorLog(msg) then
			assert(false, msg)
		end
		return true
	end
	return false
end

function ImGui.TablePushBackgroundChannel()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local table = g.CurrentTable
	table.HostBackupInnerClipRect = window.ClipRect
	ImGui.SetWindowClipRectBeforeSetChannel(window, table.Bg2ClipRectForDrawCmd)
	table.DrawSplitter:SetCurrentChannel(window.DrawList, table.Bg2DrawChannelCurrent)
end

function ImGui.TablePopBackgroundChannel()
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local table = g.CurrentTable
	ImGui.SetWindowClipRectBeforeSetChannel(window, table.HostBackupInnerClipRect)
	table.DrawSplitter:SetCurrentChannel(window.DrawList, table.Columns[table.CurrentColumn + 1].DrawChannelCurrent)
end

function ImGui.TablePushColumnChannel(column_n)
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if bit32.btest(table.Flags, ImGuiTableFlags.NoClip) then
		return
	end
	local window = g.CurrentWindow
	local column = table.Columns[column_n + 1]
	ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
	table.DrawSplitter:SetCurrentChannel(window.DrawList, column.DrawChannelCurrent)
end

function ImGui.TablePopColumnChannel()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if bit32.btest(table.Flags, ImGuiTableFlags.NoClip) or table.CurrentColumn == -1 then
		return
	end
	local window = g.CurrentWindow
	local column = table.Columns[table.CurrentColumn + 1]
	ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
	table.DrawSplitter:SetCurrentChannel(window.DrawList, column.DrawChannelCurrent)
end

function ImGui.TableSetupDrawChannels(table)
	local freeze_row_multiplier = (table.FreezeRowsCount > 0) and 2 or 1
	local channels_for_row = bit32.btest(table.Flags, ImGuiTableFlags.NoClip) and 1 or table.ColumnsEnabledCount
	local channels_for_bg = 1 + 1 * freeze_row_multiplier
	local masks_differ = false
	for w = 1, bit32.rshift(table.ColumnsCount + 31, 5) do
		if table.VisibleMaskByIndex[w] ~= table.EnabledMaskByIndex[w] then
			masks_differ = true
			break
		end
	end
	local channels_for_dummy = (table.ColumnsEnabledCount < table.ColumnsCount or masks_differ) and 1 or 0
	local channels_total = channels_for_bg + (channels_for_row * freeze_row_multiplier) + channels_for_dummy
	table.DrawSplitter:Split(table.InnerWindow.DrawList, channels_total)
	table.DummyDrawChannel = (channels_for_dummy > 0) and channels_total - 1 or 0xFFFF
	table.Bg2DrawChannelCurrent = TABLE_DRAW_CHANNEL_BG2_FROZEN
	table.Bg2DrawChannelUnfrozen = (table.FreezeRowsCount > 0) and 2 + channels_for_row or TABLE_DRAW_CHANNEL_BG2_FROZEN

	local draw_channel_current = 2
	for column_n = 0, table.ColumnsCount - 1 do
		local column = table.Columns[column_n + 1]
		if column.IsVisibleX and column.IsVisibleY then
			column.DrawChannelFrozen = draw_channel_current
			column.DrawChannelUnfrozen = draw_channel_current + (table.FreezeRowsCount > 0 and channels_for_row + 1 or 0)
			if not bit32.btest(table.Flags, ImGuiTableFlags.NoClip) then
				draw_channel_current += 1
			end
		else
			column.DrawChannelFrozen = table.DummyDrawChannel
			column.DrawChannelUnfrozen = table.DummyDrawChannel
		end
		column.DrawChannelCurrent = column.DrawChannelFrozen
	end

	table.BgClipRect = table.InnerClipRect
	table.Bg0ClipRectForDrawCmd = table.OuterWindow.ClipRect
	table.Bg2ClipRectForDrawCmd = table.HostClipRect
	assert(table.BgClipRect.Min.y <= table.BgClipRect.Max.y)
end

function ImGui.TableMergeDrawChannels(table)
	local g = ImGui.GImGui
	local splitter = table.DrawSplitter
	local has_freeze_v = table.FreezeRowsCount > 0
	local has_freeze_h = table.FreezeColumnsCount > 0
	assert(splitter._Current == 0)

	local merge_group_mask = 0
	local max_draw_channels = 4 + table.ColumnsCount * 2
	local mask_words = bit32.rshift(max_draw_channels + 31, 5)
	local merge_groups = {}
	for n = 1, 4 do
		merge_groups[n] = { ClipRect = ImRect.new(), ChannelsCount = 0, ChannelsMask = table_create(mask_words, 0) }
	end
	local remaining_mask = table_create(mask_words, 0)

	for column_n = 0, table.ColumnsCount - 1 do
		if not ImBitArrayTestBit(table.VisibleMaskByIndex, column_n) then
			continue
		end
		local column = table.Columns[column_n + 1]

		local merge_group_sub_count = has_freeze_v and 2 or 1
		for merge_group_sub_n = 0, merge_group_sub_count - 1 do
			local channel_no = (merge_group_sub_n == 0) and column.DrawChannelFrozen or column.DrawChannelUnfrozen

			local src_channel = splitter._Channels[channel_no + 1]
			local cmd_buffer = src_channel._CmdBuffer
			if cmd_buffer.Size > 0 and cmd_buffer:back().ElemCount == 0 and cmd_buffer:back().UserCallback == nil then
				cmd_buffer:pop_back()
			end
			if cmd_buffer.Size ~= 1 then
				continue
			end

			if not bit32.btest(column.Flags, ImGuiTableColumnFlags.NoClip) then
				local content_max_x
				if not has_freeze_v then
					content_max_x = ImMax(column.ContentMaxXUnfrozen, column.ContentMaxXHeadersUsed)
				elseif merge_group_sub_n == 0 then
					content_max_x = ImMax(column.ContentMaxXFrozen, column.ContentMaxXHeadersUsed)
				else
					content_max_x = column.ContentMaxXUnfrozen
				end
				if content_max_x > column.ClipRect.Max.x then
					continue
				end
			end

			local merge_group_n = ((has_freeze_h and column_n < table.FreezeColumnsCount) and 0 or 1)
				+ ((has_freeze_v and merge_group_sub_n == 0) and 0 or 2)
			assert(channel_no < max_draw_channels)
			local merge_group = merge_groups[merge_group_n + 1]
			if merge_group.ChannelsCount == 0 then
				merge_group.ClipRect = ImRect.fromXY(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
			end
			ImBitArraySetBit(merge_group.ChannelsMask, channel_no)
			merge_group.ChannelsCount += 1
			merge_group.ClipRect = merge_group.ClipRect:Added(ImRect.fromVec4(cmd_buffer[1].ClipRect))
			merge_group_mask = bit32.bor(merge_group_mask, bit32.lshift(1, merge_group_n))
		end

		column.DrawChannelCurrent = 0xFFFF
	end

	if merge_group_mask ~= 0 then
		local LEADING_DRAW_CHANNELS = 2
		local tmp_buffer = g.DrawChannelsTempMergeBuffer
		tmp_buffer:resize(splitter._Count - LEADING_DRAW_CHANNELS)
		local dst_tmp = 0
		ImBitArraySetBitRange(remaining_mask, LEADING_DRAW_CHANNELS, splitter._Count)
		ImBitArrayClearBit(remaining_mask, table.Bg2DrawChannelUnfrozen)
		assert(has_freeze_v == false or table.Bg2DrawChannelUnfrozen ~= TABLE_DRAW_CHANNEL_BG2_FROZEN)
		local remaining_count = splitter._Count - (has_freeze_v and LEADING_DRAW_CHANNELS + 1 or LEADING_DRAW_CHANNELS)
		local host_rect = table.HostClipRect
		for merge_group_n = 0, 3 do
			local merge_group = merge_groups[merge_group_n + 1]
			local merge_channels_count = merge_group.ChannelsCount
			if merge_channels_count ~= 0 then
				local merge_clip_rect = merge_group.ClipRect

				if bit32.band(merge_group_n, 1) == 0 or not has_freeze_h then
					merge_clip_rect = merge_clip_rect:WithMinX(ImMin(merge_clip_rect.Min.x, host_rect.Min.x))
				end
				if bit32.band(merge_group_n, 2) == 0 or not has_freeze_v then
					merge_clip_rect = merge_clip_rect:WithMinY(ImMin(merge_clip_rect.Min.y, host_rect.Min.y))
				end
				if bit32.band(merge_group_n, 1) ~= 0 then
					merge_clip_rect = merge_clip_rect:WithMaxX(ImMax(merge_clip_rect.Max.x, host_rect.Max.x))
				end
				if bit32.band(merge_group_n, 2) ~= 0 and not bit32.btest(table.Flags, ImGuiTableFlags.NoHostExtendY) then
					merge_clip_rect = merge_clip_rect:WithMaxY(ImMax(merge_clip_rect.Max.y, host_rect.Max.y))
				end
				remaining_count -= merge_group.ChannelsCount
				for n = 1, mask_words do
					remaining_mask[n] = bit32.band(remaining_mask[n], bit32.bnot(merge_group.ChannelsMask[n]))
				end
				local n = 0
				while n < splitter._Count and merge_channels_count ~= 0 do
					if ImBitArrayTestBit(merge_group.ChannelsMask, n) then
						ImBitArrayClearBit(merge_group.ChannelsMask, n)
						merge_channels_count -= 1

						local channel = splitter._Channels[n + 1]
						assert(channel._CmdBuffer.Size == 1 and merge_clip_rect:Contains(ImRect.fromVec4(channel._CmdBuffer[1].ClipRect)))
						channel._CmdBuffer[1].ClipRect = merge_clip_rect:ToVec4()
						dst_tmp += 1
						tmp_buffer[dst_tmp] = channel
					end
					n += 1
				end
			end

			if merge_group_n == 1 and has_freeze_v then
				dst_tmp += 1
				tmp_buffer[dst_tmp] = splitter._Channels[table.Bg2DrawChannelUnfrozen + 1]
			end
		end

		local n = 0
		while n < splitter._Count and remaining_count ~= 0 do
			if ImBitArrayTestBit(remaining_mask, n) then
				dst_tmp += 1
				tmp_buffer[dst_tmp] = splitter._Channels[n + 1]
				remaining_count -= 1
			end
			n += 1
		end
		assert(dst_tmp == tmp_buffer.Size)
		for i = 1, splitter._Count - LEADING_DRAW_CHANNELS do
			splitter._Channels[LEADING_DRAW_CHANNELS + i] = tmp_buffer[i]
		end
	end
end

function ImGui.TableGetColumnBorderCol(table, order_n, column_n)
	local is_hovered = table.HoveredColumnBorder == column_n
	local is_resized = (table.ResizedColumn == column_n) and (table.InstanceInteracted == table.InstanceCurrent)
	local is_frozen_separator = table.FreezeColumnsCount == order_n + 1
	if is_resized or is_hovered then
		return ImGui.GetColorU32(is_resized and ImGuiCol.SeparatorActive or ImGuiCol.SeparatorHovered)
	end
	if is_frozen_separator or bit32.btest(table.Flags, bit32.bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoBordersInBodyUntilResize)) then
		return table.BorderColorStrong
	end
	return table.BorderColorLight
end

function ImGui.TableDrawBorders(table)
	local inner_window = table.InnerWindow
	if not table.OuterWindow.ClipRect:Overlaps(table.OuterRect) then
		return
	end

	local inner_drawlist = inner_window.DrawList
	table.DrawSplitter:SetCurrentChannel(inner_drawlist, TABLE_DRAW_CHANNEL_BG0)
	inner_drawlist:PushClipRect(table.Bg0ClipRectForDrawCmd.Min, table.Bg0ClipRectForDrawCmd.Max, false)

	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	local border_size = TABLE_BORDER_SIZE
	local head_base_y = (table.FreezeRowsCount >= 1) and table.InnerRect.Min.y or table.WorkRect.Min.y
	local draw_y1 = ImMax(table.InnerRect.Min.y, head_base_y + table.AngledHeadersHeight)
		+ (bit32.btest(table.Flags, ImGuiTableFlags.BordersOuterH) and border_size or 0.0)
	local draw_y2_body = table.InnerRect.Max.y
	local draw_y2_head = table.IsUsingHeaders and ImMin(table.InnerRect.Max.y, head_base_y + table_instance.LastTopHeadersRowHeight) or draw_y1
	if bit32.btest(table.Flags, ImGuiTableFlags.BordersInnerV) then
		for order_n = 0, table.ColumnsCount - 1 do
			if not ImBitArrayTestBit(table.EnabledMaskByDisplayOrder, order_n) then
				continue
			end

			local column_n = table.DisplayOrderToIndex[order_n + 1]
			local column = table.Columns[column_n + 1]
			local is_hovered = table.HoveredColumnBorder == column_n
			local is_resized = (table.ResizedColumn == column_n) and (table.InstanceInteracted == table.InstanceCurrent)
			local is_resizable = bit32.band(column.Flags, bit32.bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoDirectResize_)) == 0
			local is_frozen_separator = table.FreezeColumnsCount == order_n + 1
			if column.MaxX > table.InnerClipRect.Max.x and not is_resized then
				continue
			end

			if column.NextEnabledColumn == -1 and not is_resizable then
				if bit32.band(table.Flags, ImGuiTableFlags.SizingMask_) ~= ImGuiTableFlags.SizingFixedSame or bit32.btest(table.Flags, ImGuiTableFlags.NoHostExtendX) then
					continue
				end
			end
			if column.MaxX <= column.ClipRect.Min.x then
				continue
			end

			local draw_y2 = draw_y2_head
			if is_frozen_separator then
				draw_y2 = draw_y2_body
			elseif bit32.btest(table.Flags, ImGuiTableFlags.NoBordersInBodyUntilResize) and (is_hovered or is_resized) then
				draw_y2 = draw_y2_body
			elseif bit32.band(table.Flags, bit32.bor(ImGuiTableFlags.NoBordersInBodyUntilResize, ImGuiTableFlags.NoBordersInBody)) == 0 then
				draw_y2 = draw_y2_body
			end
			if draw_y2 > draw_y1 then
				inner_drawlist:AddLineV(column.MaxX, draw_y1, draw_y2, ImGui.TableGetColumnBorderCol(table, order_n, column_n), border_size)
			end
		end
	end

	if bit32.btest(table.Flags, ImGuiTableFlags.BordersOuter) then
		local outer_border = table.OuterRect
		local outer_col = table.BorderColorStrong
		if bit32.band(table.Flags, ImGuiTableFlags.BordersOuter) == ImGuiTableFlags.BordersOuter then
			inner_drawlist:AddRect(outer_border.Min, outer_border.Max, outer_col, 0.0, border_size)
		elseif bit32.btest(table.Flags, ImGuiTableFlags.BordersOuterV) then
			inner_drawlist:AddLineV(outer_border.Min.x, outer_border.Min.y, outer_border.Max.y, outer_col, border_size)
			inner_drawlist:AddLineV(outer_border.Max.x - border_size, outer_border.Min.y, outer_border.Max.y, outer_col, border_size)
		elseif bit32.btest(table.Flags, ImGuiTableFlags.BordersOuterH) then
			inner_drawlist:AddLineH(outer_border.Min.x, outer_border.Max.x, outer_border.Min.y, outer_col, border_size)
			inner_drawlist:AddLineH(outer_border.Min.x, outer_border.Max.x, outer_border.Max.y - border_size, outer_col, border_size)
		end
	end
	if bit32.btest(table.Flags, ImGuiTableFlags.BordersInnerH) and table.RowPosY2 < table.OuterRect.Max.y then
		local h_inset = bit32.btest(table.Flags, ImGuiTableFlags.BordersOuterV) and border_size or 0.0
		local border_y = table.RowPosY2
		if border_y >= table.BgClipRect.Min.y and border_y < table.BgClipRect.Max.y then
			inner_drawlist:AddLineH(table.BorderX1 + h_inset, table.BorderX2 - h_inset, border_y, table.BorderColorLight, border_size)
		end
	end

	inner_drawlist:PopClipRect()
end

function ImGui.TableGetSortSpecs()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if table == nil or not bit32.btest(table.Flags, ImGuiTableFlags.Sortable) then
		return nil
	end

	if not table.IsLayoutLocked then
		ImGui.TableUpdateLayout(table)
	end

	ImGui.TableSortSpecsBuild(table)
	return table.SortSpecs
end

function ImGui.TableGetColumnAvailSortDirection(column, n)
	assert(n < column.SortDirectionsAvailCount)
	return bit32.band(bit32.rshift(column.SortDirectionsAvailList, bit32.lshift(n, 1)), 0x03)
end

function ImGui.TableFixColumnSortDirection(table, column)
	if column.SortOrder == -1 or bit32.band(column.SortDirectionsAvailMask, bit32.lshift(1, column.SortDirection)) ~= 0 then
		return
	end
	column.SortDirection = ImGui.TableGetColumnAvailSortDirection(column, 0)
	table.IsSortSpecsDirty = true
end

function ImGui.TableGetColumnNextSortDirection(column)
	assert(column.SortDirectionsAvailCount > 0)
	if column.SortOrder == -1 then
		return ImGui.TableGetColumnAvailSortDirection(column, 0)
	end
	for n = 0, 2 do
		if column.SortDirection == ImGui.TableGetColumnAvailSortDirection(column, n) then
			return ImGui.TableGetColumnAvailSortDirection(column, (n + 1) % column.SortDirectionsAvailCount)
		end
	end
	assert(false)
	return ImGuiSortDirection.None
end

function ImGui.TableSetColumnSortDirection(column_n, sort_direction, append_to_sort_specs)
	local g = ImGui.GImGui
	local table = g.CurrentTable

	if not bit32.btest(table.Flags, ImGuiTableFlags.SortMulti) then
		append_to_sort_specs = false
	end
	if not bit32.btest(table.Flags, ImGuiTableFlags.SortTristate) then
		assert(sort_direction ~= ImGuiSortDirection.None)
	end

	local sort_order_max = 0
	if append_to_sort_specs then
		for other_column_n = 0, table.ColumnsCount - 1 do
			sort_order_max = ImMax(sort_order_max, table.Columns[other_column_n + 1].SortOrder)
		end
	end

	local column = table.Columns[column_n + 1]
	column.SortDirection = sort_direction
	if column.SortDirection == ImGuiSortDirection.None then
		column.SortOrder = -1
	elseif column.SortOrder == -1 or not append_to_sort_specs then
		column.SortOrder = append_to_sort_specs and sort_order_max + 1 or 0
	end

	for other_column_n = 0, table.ColumnsCount - 1 do
		local other_column = table.Columns[other_column_n + 1]
		if other_column ~= column and not append_to_sort_specs then
			other_column.SortOrder = -1
		end
		ImGui.TableFixColumnSortDirection(table, other_column)
	end
	table.IsSettingsDirty = true
	table.IsSortSpecsDirty = true
end

function ImGui.TableSortSpecsSanitize(table)
	assert(bit32.btest(table.Flags, ImGuiTableFlags.Sortable))

	local sort_order_count = 0
	local sort_order_present = {}
	for column_n = 0, table.ColumnsCount - 1 do
		local column = table.Columns[column_n + 1]
		if column.SortOrder ~= -1 and not column.IsEnabled then
			column.SortOrder = -1
		end
		if column.SortOrder == -1 then
			continue
		end
		sort_order_count += 1
		sort_order_present[column.SortOrder] = true
		assert(sort_order_count < 64)
	end

	local need_fix_linearize = false
	for k in sort_order_present do
		if k >= sort_order_count then
			need_fix_linearize = true
		end
	end
	for k = 0, sort_order_count - 1 do
		if not sort_order_present[k] then
			need_fix_linearize = true
		end
	end
	local need_fix_single_sort_order = (sort_order_count > 1) and not bit32.btest(table.Flags, ImGuiTableFlags.SortMulti)
	if need_fix_linearize or need_fix_single_sort_order then
		local fixed = {}
		for sort_n = 0, sort_order_count - 1 do
			local column_with_smallest_sort_order = -1
			for column_n = 0, table.ColumnsCount - 1 do
				if not fixed[column_n] and table.Columns[column_n + 1].SortOrder ~= -1 then
					if column_with_smallest_sort_order == -1 or table.Columns[column_n + 1].SortOrder < table.Columns[column_with_smallest_sort_order + 1].SortOrder then
						column_with_smallest_sort_order = column_n
					end
				end
			end
			assert(column_with_smallest_sort_order ~= -1)
			fixed[column_with_smallest_sort_order] = true
			table.Columns[column_with_smallest_sort_order + 1].SortOrder = sort_n

			if need_fix_single_sort_order then
				sort_order_count = 1
				for column_n = 0, table.ColumnsCount - 1 do
					if column_n ~= column_with_smallest_sort_order then
						table.Columns[column_n + 1].SortOrder = -1
					end
				end
				break
			end
		end
	end

	if sort_order_count == 0 and not bit32.btest(table.Flags, ImGuiTableFlags.SortTristate) then
		for column_n = 0, table.ColumnsCount - 1 do
			local column = table.Columns[column_n + 1]
			if column.IsEnabled and not bit32.btest(column.Flags, ImGuiTableColumnFlags.NoSort) then
				sort_order_count = 1
				column.SortOrder = 0
				column.SortDirection = ImGui.TableGetColumnAvailSortDirection(column, 0)
				break
			end
		end
	end

	table.SortSpecsCount = sort_order_count
end

function ImGui.TableSortSpecsBuild(table)
	local dirty = table.IsSortSpecsDirty
	if dirty then
		ImGui.TableSortSpecsSanitize(table)
		local multi = table.SortSpecsMulti
		local new_size = (table.SortSpecsCount <= 1) and 0 or table.SortSpecsCount
		multi:resize(new_size)
		for i = 1, new_size do
			if multi[i] == nil then
				multi[i] = Structs.ImGuiTableColumnSortSpecs.new()
			end
		end
		table.SortSpecs.SpecsDirty = true
		table.IsSortSpecsDirty = false
	end

	local sort_specs = nil
	if table.SortSpecsCount == 1 then
		sort_specs = { table.SortSpecsSingle }
	elseif table.SortSpecsCount > 1 then
		sort_specs = table.SortSpecsMulti
	end
	if dirty and sort_specs ~= nil then
		for column_n = 0, table.ColumnsCount - 1 do
			local column = table.Columns[column_n + 1]
			if column.SortOrder == -1 then
				continue
			end
			assert(column.SortOrder < table.SortSpecsCount)
			local sort_spec = sort_specs[column.SortOrder + 1]
			sort_spec.ColumnUserID = column.UserData
			sort_spec.ColumnIndex = column_n
			sort_spec.SortOrder = column.SortOrder
			sort_spec.SortDirection = column.SortDirection
		end
	end

	table.SortSpecs.Specs = sort_specs
	table.SortSpecs.SpecsCount = table.SortSpecsCount
end

function ImGui.TableGetHeaderRowHeight()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	local row_height = g.FontSize
	for column_n = 0, table.ColumnsCount - 1 do
		if ImBitArrayTestBit(table.EnabledMaskByIndex, column_n) then
			if bit32.band(table.Columns[column_n + 1].Flags, ImGuiTableColumnFlags.NoHeaderLabel) == 0 then
				row_height = ImMax(row_height, ImGui.CalcTextSize(ImGui.TableGetColumnName(table, column_n)).y)
			end
		end
	end
	return row_height + g.Style.CellPadding.y * 2.0
end

function ImGui.TableGetHeaderAngledMaxLabelWidth()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	local width = 0.0
	for column_n = 0, table.ColumnsCount - 1 do
		if ImBitArrayTestBit(table.EnabledMaskByIndex, column_n) then
			if bit32.btest(table.Columns[column_n + 1].Flags, ImGuiTableColumnFlags.AngledHeader) then
				width = ImMax(width, ImGui.CalcTextSize(ImGui.TableGetColumnName(table, column_n), nil, true).x)
			end
		end
	end
	return width + g.Style.CellPadding.y * 2.0
end

function ImGui.TableHeadersRow()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if UserErrorRet(table ~= nil, "Call should only be done while in BeginTable() scope!") then
		return
	end

	if not table.IsLayoutLocked then
		ImGui.TableUpdateLayout(table)
	end

	local row_height = ImGui.TableGetHeaderRowHeight()
	ImGui.TableNextRow(ImGuiTableRowFlags.Headers, row_height)
	local row_y1 = ImGui.GetCursorScreenPos().y
	if table.HostSkipItems then
		return
	end

	local columns_count = ImGui.TableGetColumnCount()
	for column_n = 0, columns_count - 1 do
		if not ImGui.TableSetColumnIndex(column_n) and table.LastHeldHeaderColumn ~= column_n then
			continue
		end

		local name = bit32.btest(ImGui.TableGetColumnFlags(column_n), ImGuiTableColumnFlags.NoHeaderLabel) and "" or ImGui.TableGetColumnName(column_n)
		ImGui.PushID(column_n)
		ImGui.TableHeader(name)
		ImGui.PopID()
	end

	local mouse_pos = ImGui.GetMousePos()
	if ImGui.IsMouseReleased(1) and ImGui.TableGetHoveredColumn() == columns_count then
		if mouse_pos.y >= row_y1 and mouse_pos.y < row_y1 + row_height then
			ImGui.TableOpenContextMenu(columns_count)
		end
	end
end

function ImGui.TableHeader(label)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	local table = g.CurrentTable
	if UserErrorRet(table ~= nil, "Call should only be done while in BeginTable() scope!") then
		return
	end
	assert(table.CurrentColumn ~= -1)
	local column_n = table.CurrentColumn
	local column = table.Columns[column_n + 1]

	if label == nil then
		label = ""
	end
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local label_pos = window.DC.CursorPos

	local cell_r = ImGui.TableGetCellBgRect(table, column_n)
	local label_height = ImMax(label_size.y, table.RowMinHeight - table.RowCellPaddingY * 2.0)

	local w_arrow = 0.0
	local w_sort_text = 0.0
	local sort_arrow = false
	local sort_order_suf = ""
	local ARROW_SCALE = 0.65
	if bit32.btest(table.Flags, ImGuiTableFlags.Sortable) and not bit32.btest(column.Flags, ImGuiTableColumnFlags.NoSort) then
		w_arrow = ImTrunc(g.FontSize * ARROW_SCALE + g.Style.FramePadding.x)
		if column.SortOrder ~= -1 then
			sort_arrow = true
		end
		if column.SortOrder > 0 then
			sort_order_suf = string.sub(ImFormatString("%d", column.SortOrder + 1), 1, 3)
			w_sort_text = g.Style.ItemInnerSpacing.x + ImGui.CalcTextSize(sort_order_suf).x
		end
	end

	local max_pos_x = label_pos.x + label_size.x + w_sort_text + w_arrow
	column.ContentMaxXHeadersUsed = ImMax(column.ContentMaxXHeadersUsed, sort_arrow and cell_r.Max.x or ImMin(max_pos_x, cell_r.Max.x))
	column.ContentMaxXHeadersIdeal = ImMax(column.ContentMaxXHeadersIdeal, max_pos_x)

	local id = window:GetID(label)
	local bb = ImRect.fromXY(cell_r.Min.x, cell_r.Min.y, cell_r.Max.x, ImMax(cell_r.Max.y, cell_r.Min.y + label_height + g.Style.CellPadding.y * 2.0))
	ImGui.ItemSize(ImVec2(0.0, label_height))
	if not ImGui.ItemAdd(bb, id) then
		return
	end

	local highlight = table.HighlightColumnHeader == column_n
	local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, nil, nil, ImGuiButtonFlags.AllowOverlap)
	if held or hovered or highlight then
		local col = ImGui.GetColorU32(held and ImGuiCol.HeaderActive or (hovered and ImGuiCol.HeaderHovered or ImGuiCol.Header))
		ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, col, table.CurrentColumn)
	else
		if bit32.band(table.RowFlags, ImGuiTableRowFlags.Headers) == 0 then
			ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, ImGui.GetColorU32(ImGuiCol.TableHeaderBg), table.CurrentColumn)
		end
	end
	ImGui.RenderNavCursor(bb, id, ImGuiNavRenderCursorFlags.Compact, 0.0)
	if held then
		table.HeldHeaderColumn = column_n
	end
	window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y - g.Style.ItemSpacing.y * 0.5)

	if held and bit32.btest(table.Flags, ImGuiTableFlags.Reorderable) and ImGui.IsMouseDragging(0) and not g.DragDropActive then
		table.InstanceInteracted = table.InstanceCurrent
		if g.IO.MouseDelta.x < 0.0 and g.IO.MousePos.x < cell_r.Min.x then
			local prev_column = (column.PrevEnabledColumn ~= -1) and table.Columns[column.PrevEnabledColumn + 1] or nil
			if prev_column then
				ImGui.TableQueueSetColumnDisplayOrder(table, column_n, prev_column.DisplayOrder)
			end
		end
		if g.IO.MouseDelta.x > 0.0 and g.IO.MousePos.x > cell_r.Max.x then
			local next_column = (column.NextEnabledColumn ~= -1) and table.Columns[column.NextEnabledColumn + 1] or nil
			if next_column then
				ImGui.TableQueueSetColumnDisplayOrder(table, column_n, next_column.DisplayOrder)
			end
		end
	end

	local ellipsis_max = ImMax(cell_r.Max.x - (sort_arrow and w_arrow + w_sort_text or 0.0), label_pos.x)
	if bit32.btest(table.Flags, ImGuiTableFlags.Sortable) and not bit32.btest(column.Flags, ImGuiTableColumnFlags.NoSort) then
		if column.SortOrder ~= -1 then
			local x = ImMax(cell_r.Min.x, cell_r.Max.x - w_arrow - w_sort_text)
			local y = label_pos.y
			if column.SortOrder > 0 then
				ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(ImGuiCol.Text, 0.70))
				ImGui.RenderText(ImVec2(x + g.Style.ItemInnerSpacing.x, y), sort_order_suf)
				ImGui.PopStyleColor()
				x += w_sort_text
			end
			ImGui.RenderArrow(window.DrawList, ImVec2(x, y), ImGui.GetColorU32(ImGuiCol.Text), column.SortDirection == ImGuiSortDirection.Ascending and ImGuiDir.Up or ImGuiDir.Down, ARROW_SCALE)
		end

		if pressed and table.ReorderColumn ~= column_n then
			local sort_direction = ImGui.TableGetColumnNextSortDirection(column)
			ImGui.TableSetColumnSortDirection(column_n, sort_direction, g.IO.KeyShift)
		end
	end

	ImGui.RenderTextEllipsis(window.DrawList, label_pos, ImVec2(ellipsis_max, bb.Max.y), ellipsis_max, label, label_end, label_size)

	local text_clipped = label_size.x > (ellipsis_max - label_pos.x)
	if text_clipped and hovered and g.ActiveId == 0 then
		ImGui.SetItemTooltip("%s", string.sub(label, 1, label_end - 1))
	end

	if ImGui.IsPopupOpenRequestForItem(ImGuiPopupFlags.None, id) then
		ImGui.TableOpenContextMenu(column_n)
	end
end

function ImGui.TableAngledHeadersRow()
	local g = ImGui.GImGui
	local table = g.CurrentTable
	local temp_data = table.TempData
	temp_data.AngledHeadersRequests:resize(0)
	temp_data.AngledHeadersRequests:reserve(table.ColumnsEnabledCount)

	local row_id = ImGui.GetID("##AngledHeaders")
	local table_instance = ImGui.TableGetInstanceData(table, table.InstanceCurrent)
	local highlight_column_n = (table.LastHeldHeaderColumn ~= -1) and table.LastHeldHeaderColumn or table.HighlightColumnHeader
	if highlight_column_n == -1 and table.HoveredColumnBody ~= -1 then
		if table_instance.HoveredRowLast == 0 and table.HoveredColumnBorder == -1 and (g.ActiveId == 0 or g.ActiveId == row_id or (table.IsActiveIdInTable or g.DragDropActive)) then
			highlight_column_n = table.HoveredColumnBody
		end
	end

	local col_header_bg = ImGui.GetColorU32(ImGuiCol.TableHeaderBg)
	local col_text = ImGui.GetColorU32(ImGuiCol.Text)
	for order_n = 0, table.ColumnsCount - 1 do
		if ImBitArrayTestBit(table.EnabledMaskByDisplayOrder, order_n) then
			local column_n = table.DisplayOrderToIndex[order_n + 1]
			local column = table.Columns[column_n + 1]
			if bit32.band(column.Flags, ImGuiTableColumnFlags.AngledHeader) == 0 then
				continue
			end
			local request = Structs.ImGuiTableHeaderData.new()
			request.Index = column_n
			request.TextColor = col_text
			request.BgColor0 = col_header_bg
			request.BgColor1 = (column_n == highlight_column_n) and ImGui.GetColorU32(ImGuiCol.Header) or 0
			temp_data.AngledHeadersRequests:push_back(request)
		end
	end

	ImGui.TableAngledHeadersRowEx(row_id, g.Style.TableAngledHeadersAngle, 0.0, temp_data.AngledHeadersRequests, temp_data.AngledHeadersRequests.Size)
end

function ImGui.TableAngledHeadersRowEx(row_id, angle, max_label_width, data, data_count)
	local g = ImGui.GImGui
	local table = g.CurrentTable
	local window = g.CurrentWindow
	local draw_list = window.DrawList
	if UserErrorRet(table ~= nil, "Call should only be done while in BeginTable() scope!") then
		return
	end
	assert(table.CurrentRow == -1, "Must be first row")

	if max_label_width == 0.0 then
		max_label_width = ImGui.TableGetHeaderAngledMaxLabelWidth()
	end

	local flip_label = angle < 0.0
	angle -= IM_PI * 0.5
	local cos_a = math.cos(angle)
	local sin_a = math.sin(angle)
	local label_cos_a = flip_label and math.cos(angle + IM_PI) or cos_a
	local label_sin_a = flip_label and math.sin(angle + IM_PI) or sin_a
	local unit_right = ImVec2(cos_a, sin_a)

	local header_height = g.FontSize + g.Style.CellPadding.x * 2.0
	local row_height = ImTrunc(math.abs(ImRotate(ImVec2(max_label_width, flip_label and header_height or -header_height), cos_a, sin_a).y))
	table.AngledHeadersHeight = row_height
	table.AngledHeadersSlope = (sin_a ~= 0.0) and (cos_a / sin_a) or 0.0
	local header_angled_vector = unit_right * (row_height / -sin_a)

	ImGui.TableNextRow(ImGuiTableRowFlags.Headers, row_height)
	ImGui.TableNextColumn()
	local row_r = ImRect.fromXY(table.WorkRect.Min.x, table.BgClipRect.Min.y, table.WorkRect.Max.x, table.RowPosY2)
	table.DrawSplitter:SetCurrentChannel(draw_list, TABLE_DRAW_CHANNEL_BG0)
	local clip_rect_min_x = table.BgClipRect.Min.x
	if table.FreezeColumnsCount > 0 then
		clip_rect_min_x = ImMax(clip_rect_min_x, table.Columns[table.DisplayOrderToIndex[table.FreezeColumnsCount] + 1].MaxX)
	end
	ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, 0)
	ImGui.PushClipRect(table.BgClipRect.Min, table.BgClipRect.Max, false)
	draw_list:AddRectFilled(ImVec2(table.BgClipRect.Min.x, row_r.Min.y), ImVec2(table.BgClipRect.Max.x, row_r.Max.y), ImGui.GetColorU32(ImGuiCol.TableHeaderBg, 0.25))
	ImGui.PushClipRect(ImVec2(clip_rect_min_x, table.BgClipRect.Min.y), table.BgClipRect.Max, true)

	ImGui.ButtonBehavior(row_r, row_id, nil, nil)
	ImGui.KeepAliveID(row_id)

	local ascent_scaled = g.FontBaked.Ascent * g.FontBakedScale
	local line_off_for_ascent_x = (ImMax((g.FontSize - ascent_scaled) * 0.5, 0.0) / -sin_a) * (flip_label and -1.0 or 1.0)
	local padding = g.Style.CellPadding
	local align = g.Style.TableAngledHeadersTextAlign

	local max_x = -FLT_MAX
	for pass = 0, 1 do
		for order_n = 0, data_count - 1 do
			local request = data[order_n + 1]
			local column_n = request.Index
			local column = table.Columns[column_n + 1]

			local bg_shape0 = ImVec2(column.MaxX, row_r.Max.y)
			local bg_shape1 = ImVec2(column.MinX, row_r.Max.y)
			local bg_shape2 = bg_shape1 + header_angled_vector
			local bg_shape3 = bg_shape0 + header_angled_vector
			if pass == 0 then
				draw_list:AddQuadFilled(bg_shape0, bg_shape1, bg_shape2, bg_shape3, request.BgColor0)
				draw_list:AddQuadFilled(bg_shape0, bg_shape1, bg_shape2, bg_shape3, request.BgColor1)
				max_x = ImMax(max_x, bg_shape3.x)

				local label_name = ImGui.TableGetColumnName(table, column_n)
				local label_name_end = ImGui.FindRenderedTextEnd(label_name)
				local line_off_step_x = g.FontSize / -sin_a
				local label_lines = ImTextCountLines(label_name, label_name_end)

				local line_off_curr_x = flip_label and (label_lines - 1) * line_off_step_x or 0.0
				local line_off_for_align_x = math.floor(ImMax((((column.MaxX - column.MinX) - padding.x * 2.0) - (label_lines * line_off_step_x)), 0.0) * align.x)
				line_off_curr_x += line_off_for_align_x - line_off_for_ascent_x

				column.ContentMaxXHeadersIdeal = column.WorkMinX + math.ceil(label_lines * line_off_step_x - line_off_for_align_x)
				column.ContentMaxXHeadersUsed = column.ContentMaxXHeadersIdeal

				local label_name_p = 1
				while label_name_p < label_name_end do
					local label_name_eol = string.find(label_name, "\n", label_name_p, true)
					if label_name_eol == nil then
						label_name_eol = label_name_end
					end
					local line_text = string.sub(label_name, label_name_p, label_name_eol - 1)

					local label_size = ImGui.CalcTextSize(line_text)
					local clip_width = max_label_width - padding.y
					local clip_height = ImMin(label_size.y, column.ClipRect.Max.x - column.WorkMinX - line_off_curr_x)
					local clip_r = ImRect.new(window.ClipRect.Min, window.ClipRect.Min + ImVec2(clip_width, clip_height))
					local vtx_idx_begin = draw_list:GetPrimCount()
					ImGui.PushStyleColor(ImGuiCol.Text, request.TextColor)
					ImGui.RenderTextEllipsis(draw_list, clip_r.Min, clip_r.Max, clip_r.Max.x, line_text, nil, label_size)
					ImGui.PopStyleColor()
					local vtx_idx_end = draw_list:GetPrimCount()

					local available_space = ImMax(clip_width - label_size.x + math.abs(padding.x * cos_a) * 2.0 - math.abs(padding.y * sin_a) * 2.0, 0.0)
					local vertical_offset = available_space * align.y * (flip_label and -1.0 or 1.0)

					local pivot_in = ImVec2(window.ClipRect.Min.x - vertical_offset, window.ClipRect.Min.y + label_size.y)
					local pivot_out = ImVec2(column.WorkMinX, row_r.Max.y)
					line_off_curr_x += flip_label and -line_off_step_x or line_off_step_x
					pivot_out += unit_right * padding.y
					if flip_label then
						pivot_out += unit_right * (clip_width - ImMax(0.0, clip_width - label_size.x))
					end
					pivot_out = ImVec2(pivot_out.x + (flip_label and line_off_curr_x + line_off_step_x or line_off_curr_x), pivot_out.y)
					ImGui.ShadeVertsTransformPos(draw_list, vtx_idx_begin, vtx_idx_end, pivot_in, label_cos_a, label_sin_a, pivot_out)

					label_name_p = label_name_eol + 1
				end
			end
			if pass == 1 then
				local border_size = TABLE_BORDER_SIZE
				draw_list:AddLine(bg_shape0 + ImVec2(border_size * 0.5, 0.0), bg_shape3 + ImVec2(border_size * 0.5, 0.0), ImGui.TableGetColumnBorderCol(table, order_n, column_n), border_size)
			end
		end
	end
	ImGui.PopClipRect()
	ImGui.PopClipRect()
	table.TempData.AngledHeadersExtraWidth = ImMax(0.0, max_x - table.Columns[table.RightMostEnabledColumn + 1].MaxX)
end

function ImGui.TableOpenContextMenu(column_n)
	if column_n == nil then
		column_n = -1
	end
	local g = ImGui.GImGui
	local table = g.CurrentTable
	if column_n == -1 and table.CurrentColumn ~= -1 then
		column_n = table.CurrentColumn
	end
	if column_n == table.ColumnsCount then
		column_n = -1
	end
	assert(column_n >= -1 and column_n < table.ColumnsCount)
	if bit32.btest(table.Flags, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
		table.IsContextPopupOpen = true
		table.ContextPopupColumn = column_n
		table.InstanceInteracted = table.InstanceCurrent
		local context_menu_id = ImHashStr("##ContextMenu", 0, table.ID)
		ImGui.OpenPopupEx(context_menu_id, ImGuiPopupFlags.None)
	end
end

function ImGui.TableBeginContextMenuPopup(table)
	if not table.IsContextPopupOpen or table.InstanceCurrent ~= table.InstanceInteracted then
		return false
	end
	local context_menu_id = ImHashStr("##ContextMenu", 0, table.ID)
	if ImGui.BeginPopupEx(context_menu_id, bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings)) then
		return true
	end
	table.IsContextPopupOpen = false
	return false
end

function ImGui.MenuItemForColumnReorder(label, selected, enabled)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local label_size = ImGui.CalcTextSize(label, nil, true)
	local offsets = window.DC.MenuColumns
	local checkmark_w = IM_TRUNC(g.FontSize * 1.20)
	local min_w = offsets:DeclColumns(0.0, label_size.x, 0.0, checkmark_w)
	local stretch_w = ImMax(0.0, ImGui.GetContentRegionAvail().x - min_w)
	local text_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)

	local id = ImGui.GetID(label)
	local selectable_flags = bit32.bor(ImGuiSelectableFlags.SelectOnRelease, ImGuiSelectableFlags.SpanAvailWidth)
	if g.ActiveId == id then
		selectable_flags = bit32.bor(selectable_flags, ImGuiSelectableFlags.Highlight)
	end
	local has_been_moved = (g.ActiveId == id) and g.ActiveIdHasBeenEditedBefore

	ImGui.BeginDisabled(not enabled)
	local ret = ImGui.Selectable(label, false, selectable_flags, ImVec2(min_w, label_size.y)) and not has_been_moved
	if bit32.btest(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) and selected then
		ImGui.RenderCheckMark(window.DrawList, text_pos + ImVec2(offsets.OffsetMark + stretch_w + g.FontSize * 0.40, g.FontSize * 0.134 * 0.5), ImGui.GetColorU32(ImGuiCol.Text), g.FontSize * 0.866)
	end
	ImGui.EndDisabled()

	return ret
end

function ImGui.TableDrawDefaultContextMenu(table, flags_for_section_to_display)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	if window.SkipItems then
		return
	end

	local want_separator = false
	local context_column_n = (table.ContextPopupColumn >= 0 and table.ContextPopupColumn < table.ColumnsCount) and table.ContextPopupColumn or -1
	local context_column = (context_column_n ~= -1) and table.Columns[context_column_n + 1] or nil

	if bit32.btest(flags_for_section_to_display, ImGuiTableFlags.Resizable) then
		if context_column ~= nil then
			local can_resize = not bit32.btest(context_column.Flags, ImGuiTableColumnFlags.NoResize) and context_column.IsEnabled
			if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableSizeOne), nil, false, can_resize) then
				ImGui.TableSetColumnWidthAutoSingle(table, context_column_n)
			end
		end

		local size_all_desc
		if table.ColumnsEnabledFixedCount == table.ColumnsEnabledCount and bit32.band(table.Flags, ImGuiTableFlags.SizingMask_) ~= ImGuiTableFlags.SizingFixedSame then
			size_all_desc = ImGui.LocalizeGetMsg(ImGuiLocKey.TableSizeAllFit)
		else
			size_all_desc = ImGui.LocalizeGetMsg(ImGuiLocKey.TableSizeAllDefault)
		end
		if ImGui.MenuItem(size_all_desc, nil) then
			ImGui.TableSetColumnWidthAutoAll(table)
		end
		want_separator = true
	end

	if bit32.btest(flags_for_section_to_display, bit32.bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
		if ImGui.BeginMenu(ImGui.LocalizeGetMsg(ImGuiLocKey.TableReset)) then
			if bit32.btest(flags_for_section_to_display, ImGuiTableFlags.Reorderable) then
				if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableResetOrder), nil, false, not table.IsDefaultDisplayOrder) then
					table.IsResetDisplayOrderRequest = true
				end
			end
			if bit32.btest(flags_for_section_to_display, ImGuiTableFlags.Hideable) then
				if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableResetVisibility), nil, false, not table.IsDefaultVisibility) then
					table.IsResetVisibilityRequest = true
				end
			end
			ImGui.EndMenu()
		end
	end

	if bit32.btest(flags_for_section_to_display, ImGuiTableFlags.Hideable) then
		if want_separator then
			ImGui.Separator()
		end
		want_separator = true

		local is_reordering = g.ActiveId ~= 0 and g.ActiveIdWindow == g.CurrentWindow and table.ReorderColumn ~= -1 and g.ActiveIdHasBeenEditedBefore
		local reorder_src_order = is_reordering and table.Columns[table.ReorderColumn + 1].DisplayOrder or -1
		local reorder_min_order = is_reordering and ImGui.TableGetMaxDisplayOrderAllowed(table, reorder_src_order, 0) or 0
		local reorder_max_order = is_reordering and ImGui.TableGetMaxDisplayOrderAllowed(table, reorder_src_order, table.ColumnsCount - 1) or table.ColumnsCount - 1
		ImGui.PushItemFlag(ImGuiItemFlags.AutoClosePopups, false)
		for order_n = 0, table.ColumnsCount - 1 do
			local column_n = table.DisplayOrderToIndex[order_n + 1]
			local column = table.Columns[column_n + 1]
			if bit32.btest(column.Flags, ImGuiTableColumnFlags.Disabled) then
				continue
			end

			local name = ImGui.TableGetColumnName(table, column_n)
			if name == nil or name == "" then
				name = "<Unknown>"
			end

			local menu_item_enabled = not bit32.btest(column.Flags, ImGuiTableColumnFlags.NoHide)
			if column.IsUserEnabled and table.ColumnsEnabledCount <= 1 then
				menu_item_enabled = false
			end
			if is_reordering and (column.DisplayOrder < reorder_min_order or column.DisplayOrder > reorder_max_order) then
				menu_item_enabled = false
			end
			if ImGui.MenuItemForColumnReorder(name, column.IsUserEnabled, menu_item_enabled) then
				column.IsUserEnabledNextFrame = not column.IsUserEnabled
			end

			if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) and g.ActiveIdSource == ImGuiInputSource.Mouse and bit32.btest(table.Flags, ImGuiTableFlags.Reorderable) then
				g.ActiveIdHasBeenEditedBefore = true
				table.ReorderColumn = column_n
				if not ImGui.IsItemHovered() then
					local item_rect = g.LastItemData.Rect
					local reorder_dir = (g.IO.MousePos.y < (item_rect.Min.y + item_rect.Max.y) * 0.5) and -1 or 1
					local reorder_amount = (reorder_dir < 0 and item_rect.Min.y - g.IO.MousePos.y or g.IO.MousePos.y - item_rect.Max.y) / item_rect:GetHeight()
					local dst_order = column.DisplayOrder + ImTruncToInt(math.ceil(reorder_amount)) * reorder_dir
					ImGui.TableQueueSetColumnDisplayOrder(table, column_n, dst_order)
				end
			end
		end
		ImGui.PopItemFlag()
	end
end

function ImGui.TableSettingsInit(settings, id, columns_count, columns_count_max)
	settings.SaveFlags = 0
	settings.RefScale = 0.0
	settings.LastUsedDate = Structs.ImGuiPackedDate.new()
	local column_settings = table_create(columns_count_max)
	for n = 1, columns_count_max do
		column_settings[n] = Structs.ImGuiTableColumnSettings.new()
	end
	settings.ColumnSettings = column_settings
	settings.ID = id
	settings.ColumnsCount = columns_count
	settings.ColumnsCountMax = columns_count_max
	settings.WantApply = true
end

function ImGui.TableSettingsCalcChunkSize(columns_count)
	return 20 + columns_count * 16
end

function ImGui.TableSettingsCreate(id, columns_count)
	local g = ImGui.GImGui
	local settings = ImGui.TableSettingsFindByID(id)
	if settings then
		if settings.ColumnsCountMax >= columns_count then
			ImGui.TableSettingsInit(settings, id, columns_count, settings.ColumnsCountMax)
			return settings
		end
		settings.ID = 0
	end
	settings = g.SettingsTables:alloc_chunk(Structs.ImGuiTableSettings.new())
	ImGui.TableSettingsInit(settings, id, columns_count, columns_count)
	return settings
end

function ImGui.TableSettingsFindByID(id)
	local g = ImGui.GImGui
	local settings = g.SettingsTables:begin()
	while settings ~= nil do
		if settings.ID == id then
			return settings
		end
		settings = g.SettingsTables:next_chunk(settings)
	end
	return nil
end

function ImGui.TableGetBoundSettings(table)
	if table.SettingsOffset == -1 then
		return nil
	end
	local g = ImGui.GImGui
	local settings = g.SettingsTables:ptr_from_offset(table.SettingsOffset)
	assert(settings.ID == table.ID)
	return settings
end

function ImGui.TableResetSettings(table)
	table.IsInitializing = true
	table.IsSettingsDirty = true
	table.IsResetAllRequest = false
	table.IsSettingsRequestLoad = false
	table.SettingsLoadedFlags = ImGuiTableFlags.None
end

function ImGui.TableSaveSettings(table)
	table.IsSettingsDirty = false
	if bit32.btest(table.Flags, ImGuiTableFlags.NoSavedSettings) then
		return
	end

	local g = ImGui.GImGui
	local settings = ImGui.TableGetBoundSettings(table)
	if settings ~= nil and table.ColumnsCount > settings.ColumnsCountMax then
		settings.ID = 0
		settings = nil
	end
	if settings == nil then
		settings = ImGui.TableSettingsCreate(table.ID, table.ColumnsCount)
		table.SettingsOffset = g.SettingsTables:offset_from_ptr(settings)
	end
	settings.ColumnsCount = table.ColumnsCount
	settings.LastUsedDate = g.SessionDate:Copy()

	assert(settings.ID == table.ID)
	assert(settings.ColumnsCount == table.ColumnsCount and settings.ColumnsCountMax >= settings.ColumnsCount)

	local save_ref_scale = false
	local save_flags = ImGuiTableFlags.None
	for n = 0, table.ColumnsCount - 1 do
		local column = table.Columns[n + 1]
		local column_settings = settings.ColumnSettings[n + 1]
		local is_stretch = bit32.btest(column.Flags, ImGuiTableColumnFlags.WidthStretch)
		local width_or_weight = is_stretch and column.StretchWeight or column.WidthRequest
		column_settings.ID = column.ID
		column_settings.WidthOrWeight = width_or_weight
		column_settings.Index = n
		column_settings.DisplayOrder = column.DisplayOrder
		column_settings.SortOrder = column.SortOrder
		column_settings.SortDirection = column.SortDirection
		column_settings.IsEnabled = column.IsUserEnabled and 1 or 0
		column_settings.IsStretch = is_stretch and 1 or 0
		if not is_stretch then
			save_ref_scale = true
		end

		if width_or_weight ~= column.InitStretchWeightOrWidth then
			save_flags = bit32.bor(save_flags, ImGuiTableFlags.Resizable)
		end
		if column.DisplayOrder ~= n then
			save_flags = bit32.bor(save_flags, ImGuiTableFlags.Reorderable)
		end
		if column.SortOrder ~= -1 then
			save_flags = bit32.bor(save_flags, ImGuiTableFlags.Sortable, ImGuiTableFlags.Reorderable)
		end
		if column.IsUserEnabled ~= (bit32.band(column.Flags, ImGuiTableColumnFlags.DefaultHide) == 0) then
			save_flags = bit32.bor(save_flags, ImGuiTableFlags.Hideable)
		end
	end
	settings.SaveFlags = bit32.band(save_flags, table.Flags)
	settings.RefScale = save_ref_scale and table.RefScale or 0.0

	ImGui.MarkIniSettingsDirty()
end

function ImGui.TableLoadSettings(table)
	local g = ImGui.GImGui
	if bit32.btest(table.Flags, ImGuiTableFlags.NoSavedSettings) then
		table.IsSettingsRequestLoad = false
		return
	end

	local settings
	if table.SettingsOffset == -1 then
		settings = ImGui.TableSettingsFindByID(table.ID)
		if settings == nil then
			return
		end
		if settings.ColumnsCount ~= table.ColumnsCount then
			table.IsSettingsDirty = true
		end
		table.SettingsOffset = g.SettingsTables:offset_from_ptr(settings)
	else
		settings = ImGui.TableGetBoundSettings(table)
	end

	table.SettingsLoadedFlags = settings.SaveFlags
	table.RefScale = settings.RefScale
	settings.LastUsedDate = g.SessionDate:Copy()
end

function ImGui.TableLoadSettingsForColumns(table)
	for n = 1, table.ColumnsCount do
		table.Columns[n].IsLoadedSettings = false
	end
	local settings = ImGui.TableGetBoundSettings(table)
	if settings == nil then
		return
	end

	table.SettingsLoadedFlags = bit32.bor(table.SettingsLoadedFlags, ImGuiTableFlags.Reorderable)

	local column_settings = settings.ColumnSettings

	local matches = 0
	for n = 0, table.ColumnsCount - 1 do
		if n >= settings.ColumnsCount or column_settings[n + 1].ID ~= table.Columns[n + 1].ID then
			break
		end
		ImGui.TableLoadSettingsForColumn(table.Columns[n + 1], column_settings[n + 1], settings.SaveFlags)
		matches += 1
	end
	if matches == settings.ColumnsCount then
		return
	end
	local settings_start_n = matches
	for n = settings_start_n, settings.ColumnsCount - 1 do
		column_settings[n + 1].IsLoaded = false
	end

	for c = 1, table.ColumnsCount do
		local column = table.Columns[c]
		if column.ID ~= 0 and not column.IsLoadedSettings then
			for n = settings_start_n, settings.ColumnsCount - 1 do
				if column_settings[n + 1].ID == column.ID and not column_settings[n + 1].IsLoaded then
					ImGui.TableLoadSettingsForColumn(column, column_settings[n + 1], settings.SaveFlags)
					matches += 1
					break
				end
			end
		end
	end

	local dst_idx = 0
	for n = settings_start_n, settings.ColumnsCount - 1 do
		if not column_settings[n + 1].IsLoaded then
			while dst_idx < table.ColumnsCount and table.Columns[dst_idx + 1].IsLoadedSettings do
				dst_idx += 1
			end
			if dst_idx >= table.ColumnsCount then
				break
			end
			ImGui.TableLoadSettingsForColumn(table.Columns[dst_idx + 1], column_settings[n + 1], settings.SaveFlags)
			dst_idx += 1
		end
	end
end

function ImGui.TableLoadSettingsForColumn(column, column_settings, load_flags)
	column.IsLoadedSettings = true
	column_settings.IsLoaded = true
	if bit32.btest(load_flags, ImGuiTableFlags.Resizable) then
		if column_settings.IsStretch ~= 0 then
			column.StretchWeight = column_settings.WidthOrWeight
		else
			column.WidthRequest = column_settings.WidthOrWeight
		end
		column.AutoFitQueue = 0x00
	end
	if bit32.btest(load_flags, ImGuiTableFlags.Reorderable) then
		column.DisplayOrder = column_settings.DisplayOrder
	else
		column.DisplayOrder = column_settings.Index
	end
	if bit32.btest(load_flags, ImGuiTableFlags.Hideable) and column_settings.IsEnabled ~= -1 then
		column.IsUserEnabled = column_settings.IsEnabled == 1
		column.IsUserEnabledNextFrame = column.IsUserEnabled
	end
	column.SortOrder = column_settings.SortOrder
	column.SortDirection = column_settings.SortDirection
end

function ImGui.TableFixDisplayOrderComparer(lhs, rhs)
	local table = lhs.Table
	local lhs_idx = lhs.Idx
	local rhs_idx = rhs.Idx
	local order_delta = bit32.band(table.Columns[lhs_idx + 1].DisplayOrder, 0xFFFF) - bit32.band(table.Columns[rhs_idx + 1].DisplayOrder, 0xFFFF)
	if order_delta > 0 then
		return 1
	elseif order_delta < 0 then
		return -1
	elseif lhs_idx > rhs_idx then
		return 1
	end
	return -1
end

function ImGui.TableFixDisplayOrder(table)
	if bit32.band(table.Flags, ImGuiTableFlags.Reorderable) == 0 then
		for n = 0, table.ColumnsCount - 1 do
			table.Columns[n + 1].DisplayOrder = n
			table.DisplayOrderToIndex[n + 1] = n
		end
		return
	end
	local fdo_columns = table_create(table.ColumnsCount)
	for n = 0, table.ColumnsCount - 1 do
		fdo_columns[n + 1] = { Idx = n, Table = table }
	end
	Base.ImQsort(fdo_columns, table.ColumnsCount, ImGui.TableFixDisplayOrderComparer)
	for n = 0, table.ColumnsCount - 1 do
		table.Columns[fdo_columns[n + 1].Idx + 1].DisplayOrder = n
	end
	for n = 0, table.ColumnsCount - 1 do
		table.DisplayOrderToIndex[table.Columns[n + 1].DisplayOrder + 1] = n
	end
end

local function ForEachTable(g, fn)
	for i = 0, g.Tables:GetMapSize() - 1 do
		local table = g.Tables:TryGetMapData(i)
		if table then
			fn(table)
		end
	end
end

function ImGui.TableSettingsHandler_ClearAll(ctx, handler)
	local g = ctx
	ForEachTable(g, function(table)
		table.SettingsOffset = -1
	end)
	g.SettingsTables:clear()
end

function ImGui.TableSettingsHandler_Cleanup(ctx, handler, args)
	local g = ctx
	ForEachTable(g, function(table)
		table.SettingsOffset = -1
	end)
	local settings = g.SettingsTables:begin()
	while settings ~= nil do
		local is_valid = settings.LastUsedDate:IsValid()
		if args._DiscardOlderThanDate ~= 0 and settings.LastUsedDate:Unpack() < args._DiscardOlderThanDate then
			settings.ID = 0
		elseif args.DiscardWhenMissingDate and not is_valid then
			settings.ID = 0
		elseif args.SetCurrentSessionDateToAll or (args.SetCurrentSessionDateWhenMissingDate and not is_valid) then
			settings.LastUsedDate = g.SessionDate:Copy()
		end
		settings = g.SettingsTables:next_chunk(settings)
	end
end

function ImGui.TableSettingsHandler_ApplyAll(ctx, handler)
	local g = ctx
	ForEachTable(g, function(table)
		table.IsSettingsRequestLoad = true
		table.SettingsOffset = -1
	end)
end

function ImGui.TableSettingsHandler_ReadOpen(ctx, handler, name)
	local id_str, count_str = string.match(name, "^0x(%x%x?%x?%x?%x?%x?%x?%x?),%s*([%+%-]?%d+)")
	if id_str == nil then
		return nil
	end
	local id = tonumber(id_str, 16)
	local columns_count = tonumber(count_str)
	if columns_count <= 0 or columns_count >= IMGUI_TABLE_MAX_COLUMNS then
		return nil
	end
	return ImGui.TableSettingsCreate(id, columns_count)
end

local function ScanInt(s, i)
	local v, e = string.match(s, "^%s*([%+%-]?%d+)()", i)
	if v == nil then
		return nil, i
	end
	return tonumber(v), e
end

local function ScanFloat(s, i)
	local v, e = string.match(s, "^%s*([%+%-]?[%d%.]+[eE][%+%-]?%d+)()", i)
	if v == nil then
		v, e = string.match(s, "^%s*([%+%-]?[%d%.]+)()", i)
	end
	local f = v and tonumber(v)
	if f == nil then
		return nil, i
	end
	return f, e
end

local function ScanHex8(s, i)
	local v, e = string.match(s, "^%s*(%x%x?%x?%x?%x?%x?%x?%x?)()", i)
	if v == nil then
		return nil, i
	end
	return tonumber(v, 16), e
end

local function StartsWith(s, prefix)
	return string.sub(s, 1, #prefix) == prefix
end

local function SkipBlankFrom(s, i)
	return string.sub(s, (string.match(s, "^[ \t]*()", i)))
end

function ImGui.TableSettingsHandler_ReadLine(ctx, handler, entry, line)
	local settings = entry
	local v, r

	if StartsWith(line, "RefScale=") then
		v = ScanFloat(line, 10)
		if v ~= nil then
			settings.RefScale = v
			return
		end
	end
	if StartsWith(line, "LastUsed=") then
		v = ScanInt(line, 10)
		if v ~= nil then
			settings.LastUsedDate = Structs.ImGuiPackedDate.new(v)
			return
		end
	end

	if not StartsWith(line, "Column") then
		return
	end
	local column_n
	column_n, r = ScanInt(line, 7)
	if column_n == nil then
		return
	end
	if column_n < 0 or column_n >= settings.ColumnsCount then
		return
	end
	line = SkipBlankFrom(line, r)
	local column = settings.ColumnSettings[column_n + 1]
	column.Index = column_n
	if StartsWith(line, "UserID=0x") then
		v, r = ScanHex8(line, 10)
		if v ~= nil then
			line = SkipBlankFrom(line, r)
		end
	end
	if StartsWith(line, "Width=") then
		v, r = ScanInt(line, 7)
		if v ~= nil then
			line = SkipBlankFrom(line, r)
			column.WidthOrWeight = v
			column.IsStretch = 0
			settings.SaveFlags = bit32.bor(settings.SaveFlags, ImGuiTableFlags.Resizable)
		end
	end
	if StartsWith(line, "Weight=") then
		v, r = ScanFloat(line, 8)
		if v ~= nil then
			line = SkipBlankFrom(line, r)
			column.WidthOrWeight = v
			column.IsStretch = 1
			settings.SaveFlags = bit32.bor(settings.SaveFlags, ImGuiTableFlags.Resizable)
		end
	end
	if StartsWith(line, "Visible=") then
		v, r = ScanInt(line, 9)
		if v ~= nil then
			line = SkipBlankFrom(line, r)
			column.IsEnabled = v
			settings.SaveFlags = bit32.bor(settings.SaveFlags, ImGuiTableFlags.Hideable)
		end
	end
	if StartsWith(line, "Order=") then
		v, r = ScanInt(line, 7)
		if v ~= nil then
			line = SkipBlankFrom(line, r)
			column.DisplayOrder = v
			settings.SaveFlags = bit32.bor(settings.SaveFlags, ImGuiTableFlags.Reorderable)
		end
	end
	if StartsWith(line, "Sort=") then
		v, r = ScanInt(line, 6)
		if v ~= nil and r <= #line then
			local c = string.sub(line, r, r)
			line = SkipBlankFrom(line, r + 1)
			column.SortOrder = v
			column.SortDirection = (c == "^") and ImGuiSortDirection.Descending or ImGuiSortDirection.Ascending
			settings.SaveFlags = bit32.bor(settings.SaveFlags, ImGuiTableFlags.Sortable)
		end
	end
	if StartsWith(line, "ID=0x") then
		v, r = ScanHex8(line, 6)
		if v ~= nil then
			line = SkipBlankFrom(line, r)
			column.ID = v
		end
	end
end

function ImGui.TableSettingsHandler_WriteAll(ctx, handler, buf)
	local g = ctx
	local settings = g.SettingsTables:begin()
	while settings ~= nil do
		if settings.ID ~= 0 then
			local save_size = bit32.btest(settings.SaveFlags, ImGuiTableFlags.Resizable)
			local save_visible = bit32.btest(settings.SaveFlags, ImGuiTableFlags.Hideable)
			local save_order = bit32.btest(settings.SaveFlags, ImGuiTableFlags.Reorderable)
			local save_sort = bit32.btest(settings.SaveFlags, ImGuiTableFlags.Sortable)

			buf:reserve(buf:size() + 30 + settings.ColumnsCount * 50)
			buf:appendf("[%s][0x%08X,%d]\n", handler.TypeName, settings.ID, settings.ColumnsCount)
			if settings.RefScale ~= 0.0 then
				buf:appendf("RefScale=%g\n", settings.RefScale)
			end
			for column_n = 0, settings.ColumnsCount - 1 do
				local column = settings.ColumnSettings[column_n + 1]
				local save_column = save_size or save_visible or save_order or (save_sort and column.SortOrder ~= -1)
				if not save_column then
					continue
				end
				buf:appendf("Column %-2d", column_n)
				if save_size and column.IsStretch ~= 0 then
					buf:appendf(" Weight=%.4f", column.WidthOrWeight)
				end
				if save_size and column.IsStretch == 0 then
					buf:appendf(" Width=%d", ImTruncToInt(column.WidthOrWeight))
				end
				if save_visible then
					buf:appendf(" Visible=%d", column.IsEnabled)
				end
				if save_order then
					buf:appendf(" Order=%d", column.DisplayOrder)
				end
				if save_sort and column.SortOrder ~= -1 then
					buf:appendf(" Sort=%d%s", column.SortOrder, (column.SortDirection == ImGuiSortDirection.Ascending) and "v" or "^")
				end
				if column.ID ~= 0 then
					buf:appendf(" ID=0x%08X", column.ID)
				end
				buf:append("\n")
			end
			if g.IO.ConfigIniSettingsSaveLastUsedDate then
				local last_used_date = settings.LastUsedDate:Unpack()
				if last_used_date ~= 0 then
					buf:appendf("LastUsed=%08d\n", last_used_date)
				end
			end
			buf:append("\n")
		end
		settings = g.SettingsTables:next_chunk(settings)
	end
end

function ImGui.TableSettingsAddSettingsHandler()
	local ini_handler = Structs.ImGuiSettingsHandler.new()
	ini_handler.TypeName = "Table"
	ini_handler.TypeHash = ImHashStr("Table")
	ini_handler.ClearAllFn = ImGui.TableSettingsHandler_ClearAll
	ini_handler.CleanupFn = ImGui.TableSettingsHandler_Cleanup
	ini_handler.ReadOpenFn = ImGui.TableSettingsHandler_ReadOpen
	ini_handler.ReadLineFn = ImGui.TableSettingsHandler_ReadLine
	ini_handler.ApplyAllFn = ImGui.TableSettingsHandler_ApplyAll
	ini_handler.WriteAllFn = ImGui.TableSettingsHandler_WriteAll
	ImGui.AddSettingsHandler(ini_handler)
end

function ImGui.TableRemove(table)
	local g = ImGui.GImGui
	local table_idx = g.Tables:GetIndex(table)
	g.Tables:Remove(table.ID, table)
	g.TablesLastTimeActive[table_idx + 1] = -1.0
end

function ImGui.TableGcCompactTransientBuffers(table)
	local g = ImGui.GImGui
	assert(table.MemoryCompacted == false)
	table.SortSpecs.Specs = nil
	table.SortSpecsMulti:clear()
	table.IsSortSpecsDirty = true
	table.ColumnsNames:clear()
	table.MemoryCompacted = true
	for n = 0, table.ColumnsCount - 1 do
		table.Columns[n + 1].NameOffset = -1
	end
	g.TablesLastTimeActive[g.Tables:GetIndex(table) + 1] = -1.0
end

function ImGui.TableGcCompactTransientBuffers_TempData(temp_data)
	temp_data.AngledHeadersRequests:clear()
	temp_data.DrawSplitter:ClearFreeMemory()
	temp_data.LastTimeActive = -1.0
end

function ImGui.TableGcCompactSettings()
	local g = ImGui.GImGui
	local required_memory = 0
	local current_memory = 0
	local kept = {}
	local settings = g.SettingsTables:begin()
	while settings ~= nil do
		current_memory += ImGui.TableSettingsCalcChunkSize(#settings.ColumnSettings)
		if settings.ID ~= 0 then
			required_memory += ImGui.TableSettingsCalcChunkSize(settings.ColumnsCount)
			table.insert(kept, settings)
		end
		settings = g.SettingsTables:next_chunk(settings)
	end
	if required_memory == current_memory then
		return
	end
	local new_chunk_stream = Base.ImChunkStream.new()
	for _, s in kept do
		local column_settings = s.ColumnSettings
		for i = #column_settings, s.ColumnsCount + 1, -1 do
			column_settings[i] = nil
		end
		new_chunk_stream:alloc_chunk(s)
	end
	g.SettingsTables:swap(new_chunk_stream)
	ForEachTable(g, function(t)
		t.SettingsOffset = -1
	end)
end

function ImGui.DebugNodeTableGetSizingPolicyDesc(sizing_policy)
	sizing_policy = bit32.band(sizing_policy, ImGuiTableFlags.SizingMask_)
	if sizing_policy == ImGuiTableFlags.SizingFixedFit then
		return "FixedFit"
	end
	if sizing_policy == ImGuiTableFlags.SizingFixedSame then
		return "FixedSame"
	end
	if sizing_policy == ImGuiTableFlags.SizingStretchProp then
		return "StretchProp"
	end
	if sizing_policy == ImGuiTableFlags.SizingStretchSame then
		return "StretchSame"
	end
	return "N/A"
end

local function b2i(b)
	return b and 1 or 0
end

function ImGui.DebugNodeTable(table)
	local g = ImGui.GImGui
	local is_active = table.LastFrameActive >= g.FrameCount - 2
	if not is_active then
		ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyleColorVec4(ImGuiCol.TextDisabled))
	end
	local open = ImGui.TreeNode(table, "Table 0x%08X (%d columns, in '%s')%s", table.ID, table.ColumnsCount, table.OuterWindow.Name, is_active and "" or " *Inactive*")
	if not is_active then
		ImGui.PopStyleColor()
	end
	if ImGui.IsItemHovered() then
		ImGui.GetForegroundDrawList(table.OuterWindow):AddRect(table.OuterRect.Min, table.OuterRect.Max, IM_COL32(255, 255, 0, 255))
	end
	if ImGui.IsItemVisible() and table.HoveredColumnBody ~= -1 then
		ImGui.GetForegroundDrawList(table.OuterWindow):AddRect(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), IM_COL32(255, 255, 0, 255))
	end
	if not open then
		return
	end
	if table.InstanceCurrent > 0 then
		ImGui.Text("** %d instances of same table! Some data below will refer to last instance.", table.InstanceCurrent + 1)
	end
	if g.IO.ConfigDebugIsDebuggerPresent then
		if ImGui.DebugBreakButton("**DebugBreak**", "in BeginTable()") then
			g.DebugBreakInTable = table.ID
		end
		ImGui.SameLine()
	end

	local clear_settings = ImGui.SmallButton("Clear settings")
	ImGui.BulletText("OuterRect: Pos: (%.1f,%.1f) Size: (%.1f,%.1f) Sizing: '%s'", table.OuterRect.Min.x, table.OuterRect.Min.y, table.OuterRect:GetWidth(), table.OuterRect:GetHeight(), ImGui.DebugNodeTableGetSizingPolicyDesc(table.Flags))
	ImGui.BulletText("ColumnsGivenWidth: %.1f, ColumnsAutoFitWidth: %.1f, InnerWidth: %.1f%s", table.ColumnsGivenWidth, table.ColumnsAutoFitWidth, table.InnerWidth, table.InnerWidth == 0.0 and " (auto)" or "")
	ImGui.BulletText("CellPaddingX: %.1f, CellSpacingX: %.1f/%.1f, OuterPaddingX: %.1f", table.CellPaddingX, table.CellSpacingX1, table.CellSpacingX2, table.OuterPaddingX)
	ImGui.BulletText("HoveredColumnBody: %d, HoveredColumnBorder: %d", table.HoveredColumnBody, table.HoveredColumnBorder)
	ImGui.BulletText("ResizedColumn: %d, HeldHeaderColumn: %d, ReorderColumn: %d", table.LastResizedColumn, table.LastHeldHeaderColumn, table.ReorderColumn)
	for n = 0, table.InstanceCurrent do
		local table_instance = ImGui.TableGetInstanceData(table, n)
		ImGui.BulletText("Instance %d: HoveredRow: %d, LastOuterHeight: %.2f", n, table_instance.HoveredRowLast, table_instance.LastOuterHeight)
	end
	local sum_weights = 0.0
	for n = 0, table.ColumnsCount - 1 do
		if bit32.btest(table.Columns[n + 1].Flags, ImGuiTableColumnFlags.WidthStretch) then
			sum_weights += table.Columns[n + 1].StretchWeight
		end
	end
	for n = 0, table.ColumnsCount - 1 do
		local column = table.Columns[n + 1]
		local name = ImGui.TableGetColumnName(table, n)
		local buf = ImFormatString(
			"Column %d order %d '%s': offset %+.2f to %+.2f%s\n"
				.. "Enabled: %d, VisibleX/Y: %d/%d, RequestOutput: %d, SkipItems: %d, DrawChannels: %d,%d\n"
				.. "WidthGiven: %.1f, Request/Auto: %.1f/%.1f, StretchWeight: %.3f (%.1f%%)\n"
				.. "MinX: %.1f, MaxX: %.1f (%+.1f), ClipRect: %.1f to %.1f (+%.1f)\n"
				.. "ContentWidth: %.1f,%.1f, HeadersUsed/Ideal %.1f/%.1f\n"
				.. "Sort: %d%s, UserData: 0x%08X, Flags: 0x%04X: %s%s%s..",
			n, column.DisplayOrder, name, column.MinX - table.WorkRect.Min.x, column.MaxX - table.WorkRect.Min.x, (n < table.FreezeColumnsRequest) and " (Frozen)" or "",
			b2i(column.IsEnabled), b2i(column.IsVisibleX), b2i(column.IsVisibleY), b2i(column.IsRequestOutput), b2i(column.IsSkipItems), column.DrawChannelFrozen, column.DrawChannelUnfrozen,
			column.WidthGiven, column.WidthRequest, column.WidthAuto, column.StretchWeight, column.StretchWeight > 0.0 and (column.StretchWeight / sum_weights) * 100.0 or 0.0,
			column.MinX, column.MaxX, column.MaxX - column.MinX, column.ClipRect.Min.x, column.ClipRect.Max.x, column.ClipRect.Max.x - column.ClipRect.Min.x,
			column.ContentMaxXFrozen - column.WorkMinX, column.ContentMaxXUnfrozen - column.WorkMinX, column.ContentMaxXHeadersUsed - column.WorkMinX, column.ContentMaxXHeadersIdeal - column.WorkMinX,
			column.SortOrder, (column.SortDirection == ImGuiSortDirection.Ascending) and " (Asc)" or ((column.SortDirection == ImGuiSortDirection.Descending) and " (Des)" or ""), column.UserData, column.Flags,
			bit32.btest(column.Flags, ImGuiTableColumnFlags.WidthStretch) and "WidthStretch " or "",
			bit32.btest(column.Flags, ImGuiTableColumnFlags.WidthFixed) and "WidthFixed " or "",
			bit32.btest(column.Flags, ImGuiTableColumnFlags.NoResize) and "NoResize " or ""
		)
		ImGui.Bullet()
		ImGui.Selectable(buf)
		if ImGui.IsItemHovered() then
			local r = ImRect.fromXY(column.MinX, table.OuterRect.Min.y, column.MaxX, table.OuterRect.Max.y)
			ImGui.GetForegroundDrawList(table.OuterWindow):AddRect(r.Min, r.Max, IM_COL32(255, 255, 0, 255))
		end
	end
	local settings = ImGui.TableGetBoundSettings(table)
	if settings then
		ImGui.DebugNodeTableSettings(settings, table)
	end
	if clear_settings then
		table.IsResetAllRequest = true
	end
	ImGui.TreePop()
end

function ImGui.DebugNodeTableSettings(settings, table)
	if settings.ID == 0 then
		ImGui.PushID(settings)
	end
	local open = ImGui.TreeNode(settings.ID, "Settings 0x%08X (%d columns)", settings.ID, settings.ColumnsCount)
	local hovered = ImGui.IsItemHovered()
	if hovered and table == nil and settings.ID ~= 0 then
		table = ImGui.TableFindByID(settings.ID)
	end
	if hovered and table ~= nil then
		ImGui.GetForegroundDrawList(table.OuterWindow):AddRect(table.OuterRect.Min, table.OuterRect.Max, IM_COL32(255, 255, 0, 255))
	end
	if open then
		ImGui.BulletText("SaveFlags: 0x%08X", settings.SaveFlags)
		ImGui.BulletText("ColumnsCount: %d (max %d)", settings.ColumnsCount, settings.ColumnsCountMax)
		for n = 0, settings.ColumnsCount - 1 do
			local column_settings = settings.ColumnSettings[n + 1]
			local sort_dir = (column_settings.SortOrder ~= -1) and column_settings.SortDirection or ImGuiSortDirection.None
			ImGui.BulletText("Column %d Order %d SortOrder %2d %s Vis %d %s %7.3f ID 0x%08X",
				n, column_settings.DisplayOrder, column_settings.SortOrder,
				(sort_dir == ImGuiSortDirection.Ascending) and "Asc" or ((sort_dir == ImGuiSortDirection.Descending) and "Des" or "---"),
				column_settings.IsEnabled, (column_settings.IsStretch ~= 0) and "Weight" or "Width ", column_settings.WidthOrWeight, column_settings.ID)
		end
		ImGui.TreePop()
	end
	if settings.ID == 0 then
		ImGui.PopID()
	end
end

function ImGui.SetWindowClipRectBeforeSetChannel(window, clip_rect)
	local clip_rect_vec4 = clip_rect:ToVec4()
	window.ClipRect = clip_rect
	local draw_list = window.DrawList
	draw_list._CmdHeader.ClipRect = clip_rect_vec4
	draw_list._ClipRectStack[draw_list._ClipRectStack.Size] = clip_rect_vec4
end

function ImGui.GetColumnIndex()
	local window = ImGui.GetCurrentWindowRead()
	return window.DC.CurrentColumns and window.DC.CurrentColumns.Current or 0
end

function ImGui.GetColumnsCount()
	local window = ImGui.GetCurrentWindowRead()
	return window.DC.CurrentColumns and window.DC.CurrentColumns.Count or 1
end

function ImGui.GetColumnOffsetFromNorm(columns, offset_norm)
	return offset_norm * (columns.OffMaxX - columns.OffMinX)
end

function ImGui.GetColumnNormFromOffset(columns, offset)
	return offset / (columns.OffMaxX - columns.OffMinX)
end

local function ColumnID(columns, n)
	return (columns.ID + n) % 4294967296
end

function ImGui.GetDraggedColumnOffset(columns, column_index)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	assert(column_index > 0)
	assert(g.ActiveId == ColumnID(columns, column_index))

	local x = g.IO.MousePos.x - g.ActiveIdClickOffset.x + ImTrunc(COLUMNS_HIT_RECT_HALF_THICKNESS * g.CurrentDpiScale) - window.Pos.x
	x = ImMax(x, ImGui.GetColumnOffset(column_index - 1) + g.Style.ColumnsMinSpacing)
	if bit32.btest(columns.Flags, ImGuiOldColumnFlags.NoPreserveWidths) then
		x = ImMin(x, ImGui.GetColumnOffset(column_index + 1) - g.Style.ColumnsMinSpacing)
	end

	return x
end

function ImGui.GetColumnOffset(column_index)
	if column_index == nil then
		column_index = -1
	end
	local window = ImGui.GetCurrentWindowRead()
	local columns = window.DC.CurrentColumns
	if columns == nil then
		return 0.0
	end

	if column_index < 0 then
		column_index = columns.Current
	end
	assert(column_index < columns.Columns.Size)

	local t = columns.Columns[column_index + 1].OffsetNorm
	local x_offset = ImLerp(columns.OffMinX, columns.OffMaxX, t)
	return x_offset
end

function ImGui.GetColumnWidthEx(columns, column_index, before_resize)
	if column_index < 0 then
		column_index = columns.Current
	end

	local offset_norm
	if before_resize then
		offset_norm = columns.Columns[column_index + 2].OffsetNormBeforeResize - columns.Columns[column_index + 1].OffsetNormBeforeResize
	else
		offset_norm = columns.Columns[column_index + 2].OffsetNorm - columns.Columns[column_index + 1].OffsetNorm
	end
	return ImGui.GetColumnOffsetFromNorm(columns, offset_norm)
end

function ImGui.GetColumnWidth(column_index)
	if column_index == nil then
		column_index = -1
	end
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local columns = window.DC.CurrentColumns
	if columns == nil then
		return ImGui.GetContentRegionAvail().x
	end

	if column_index < 0 then
		column_index = columns.Current
	end
	return ImGui.GetColumnOffsetFromNorm(columns, columns.Columns[column_index + 2].OffsetNorm - columns.Columns[column_index + 1].OffsetNorm)
end

function ImGui.SetColumnOffset(column_index, offset)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local columns = window.DC.CurrentColumns
	assert(columns ~= nil)

	if column_index < 0 then
		column_index = columns.Current
	end
	assert(column_index < columns.Columns.Size)

	local preserve_width = not bit32.btest(columns.Flags, ImGuiOldColumnFlags.NoPreserveWidths) and (column_index < columns.Count - 1)
	local width = preserve_width and ImGui.GetColumnWidthEx(columns, column_index, columns.IsBeingResized) or 0.0

	if not bit32.btest(columns.Flags, ImGuiOldColumnFlags.NoForceWithinWindow) then
		offset = ImMin(offset, columns.OffMaxX - g.Style.ColumnsMinSpacing * (columns.Count - column_index))
	end
	columns.Columns[column_index + 1].OffsetNorm = ImGui.GetColumnNormFromOffset(columns, offset - columns.OffMinX)

	if preserve_width then
		ImGui.SetColumnOffset(column_index + 1, offset + ImMax(g.Style.ColumnsMinSpacing, width))
	end
end

function ImGui.SetColumnWidth(column_index, width)
	local window = ImGui.GetCurrentWindowRead()
	local columns = window.DC.CurrentColumns
	assert(columns ~= nil)

	if column_index < 0 then
		column_index = columns.Current
	end
	ImGui.SetColumnOffset(column_index + 1, ImGui.GetColumnOffset(column_index) + width)
end

function ImGui.PushColumnClipRect(column_index)
	local window = ImGui.GetCurrentWindowRead()
	local columns = window.DC.CurrentColumns
	if column_index < 0 then
		column_index = columns.Current
	end

	local column = columns.Columns[column_index + 1]
	ImGui.PushClipRect(column.ClipRect.Min, column.ClipRect.Max, false)
end

function ImGui.PushColumnsBackground()
	local window = ImGui.GetCurrentWindowRead()
	local columns = window.DC.CurrentColumns
	if columns.Count == 1 then
		return
	end

	columns.HostBackupClipRect = window.ClipRect
	ImGui.SetWindowClipRectBeforeSetChannel(window, columns.HostInitialClipRect)
	columns.Splitter:SetCurrentChannel(window.DrawList, 0)
end

function ImGui.PopColumnsBackground()
	local window = ImGui.GetCurrentWindowRead()
	local columns = window.DC.CurrentColumns
	if columns.Count == 1 then
		return
	end

	ImGui.SetWindowClipRectBeforeSetChannel(window, columns.HostBackupClipRect)
	columns.Splitter:SetCurrentChannel(window.DrawList, columns.Current + 1)
end

function ImGui.FindOrCreateColumns(window, id)
	for n = 0, window.ColumnsStorage.Size - 1 do
		if window.ColumnsStorage[n + 1].ID == id then
			return window.ColumnsStorage[n + 1]
		end
	end

	window.ColumnsStorage:push_back(Structs.ImGuiOldColumns.new())
	local columns = window.ColumnsStorage:back()
	columns.ID = id
	return columns
end

function ImGui.GetColumnsID(str_id, columns_count)
	local window = ImGui.GetCurrentWindow()

	ImGui.PushID(0x11223347 + (str_id and 0 or columns_count))
	local id = window:GetID(str_id and str_id or "columns")
	ImGui.PopID()

	return id
end

function ImGui.BeginColumns(str_id, columns_count, flags)
	if flags == nil then
		flags = 0
	end
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()

	assert(columns_count >= 1)
	assert(window.DC.CurrentColumns == nil)

	local id = ImGui.GetColumnsID(str_id, columns_count)
	local columns = ImGui.FindOrCreateColumns(window, id)
	assert(columns.ID == id)
	columns.Current = 0
	columns.Count = columns_count
	columns.Flags = flags
	window.DC.CurrentColumns = columns
	window.DC.NavIsScrollPushableX = false

	columns.HostCursorPosY = window.DC.CursorPos.y
	columns.HostCursorMaxPosX = window.DC.CursorMaxPos.x
	columns.HostInitialClipRect = window.ClipRect
	columns.HostBackupParentWorkRect = window.ParentWorkRect
	window.ParentWorkRect = window.WorkRect

	local column_padding = g.Style.ItemSpacing.x
	local half_clip_extend_x = ImTrunc(ImMax(window.WindowPadding.x * 0.5, window.WindowBorderSize))
	local max_1 = window.WorkRect.Max.x + column_padding - ImMax(column_padding - window.WindowPadding.x, 0.0)
	local max_2 = window.WorkRect.Max.x + half_clip_extend_x
	columns.OffMinX = window.DC.Indent.x - column_padding + ImMax(column_padding - window.WindowPadding.x, 0.0)
	columns.OffMaxX = ImMax(ImMin(max_1, max_2) - window.Pos.x, columns.OffMinX + 1.0)
	columns.LineMinY = window.DC.CursorPos.y
	columns.LineMaxY = columns.LineMinY

	if columns.Columns.Size ~= 0 and columns.Columns.Size ~= columns_count + 1 then
		columns.Columns:resize(0)
	end

	columns.IsFirstFrame = columns.Columns.Size == 0
	if columns.Columns.Size == 0 then
		columns.Columns:reserve(columns_count + 1)
		for n = 0, columns_count do
			local column = Structs.ImGuiOldColumnData.new()
			column.OffsetNorm = n / columns_count
			columns.Columns:push_back(column)
		end
	end

	for n = 0, columns_count - 1 do
		local column = columns.Columns[n + 1]
		local clip_x1 = IM_ROUND(window.Pos.x + ImGui.GetColumnOffset(n))
		local clip_x2 = IM_ROUND(window.Pos.x + ImGui.GetColumnOffset(n + 1) - 1.0)
		column.ClipRect = ImRect.fromXY(clip_x1, -FLT_MAX, clip_x2, FLT_MAX):ClippedWithFull(window.ClipRect)
	end

	if columns.Count > 1 then
		columns.Splitter:Split(window.DrawList, 1 + columns.Count)
		columns.Splitter:SetCurrentChannel(window.DrawList, 1)
		ImGui.PushColumnClipRect(0)
	end

	local offset_0 = ImGui.GetColumnOffset(columns.Current)
	local offset_1 = ImGui.GetColumnOffset(columns.Current + 1)
	local width = offset_1 - offset_0
	ImGui.PushItemWidth(width * 0.65)
	window.DC.ColumnsOffset.x = ImMax(column_padding - window.WindowPadding.x, 0.0)
	window.DC.CursorPos = ImVec2(IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x), window.DC.CursorPos.y)
	window.WorkRect = window.WorkRect:WithMaxX(window.Pos.x + offset_1 - column_padding)
	window.WorkRect = window.WorkRect:WithMaxY(window.ContentRegionRect.Max.y)
end

function ImGui.NextColumn()
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems or window.DC.CurrentColumns == nil then
		return
	end

	local g = ImGui.GImGui
	local columns = window.DC.CurrentColumns

	if columns.Count == 1 then
		window.DC.CursorPos = ImVec2(IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x), window.DC.CursorPos.y)
		assert(columns.Current == 0)
		return
	end

	columns.Current += 1
	if columns.Current == columns.Count then
		columns.Current = 0
	end

	ImGui.PopItemWidth()

	local column = columns.Columns[columns.Current + 1]
	ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
	columns.Splitter:SetCurrentChannel(window.DrawList, columns.Current + 1)

	local column_padding = g.Style.ItemSpacing.x
	columns.LineMaxY = ImMax(columns.LineMaxY, window.DC.CursorPos.y)
	if columns.Current > 0 then
		window.DC.ColumnsOffset.x = ImGui.GetColumnOffset(columns.Current) - window.DC.Indent.x + column_padding
	else
		window.DC.ColumnsOffset.x = ImMax(column_padding - window.WindowPadding.x, 0.0)
		window.DC.IsSameLine = false
		columns.LineMinY = columns.LineMaxY
	end
	window.DC.CursorPos = ImVec2(IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x), columns.LineMinY)
	window.DC.CurrLineSize = ImVec2(0.0, 0.0)
	window.DC.CurrLineTextBaseOffset = 0.0

	local offset_0 = ImGui.GetColumnOffset(columns.Current)
	local offset_1 = ImGui.GetColumnOffset(columns.Current + 1)
	local width = offset_1 - offset_0
	ImGui.PushItemWidth(width * 0.65)
	window.WorkRect = window.WorkRect:WithMaxX(window.Pos.x + offset_1 - column_padding)
end

function ImGui.EndColumns()
	local g = ImGui.GImGui
	local window = ImGui.GetCurrentWindow()
	local columns = window.DC.CurrentColumns
	assert(columns ~= nil)

	ImGui.PopItemWidth()
	if columns.Count > 1 then
		ImGui.PopClipRect()
		columns.Splitter:Merge(window.DrawList)
	end

	local flags = columns.Flags
	columns.LineMaxY = ImMax(columns.LineMaxY, window.DC.CursorPos.y)
	window.DC.CursorPos = ImVec2(window.DC.CursorPos.x, columns.LineMaxY)
	if not bit32.btest(flags, ImGuiOldColumnFlags.GrowParentContentsSize) then
		window.DC.CursorMaxPos = ImVec2(columns.HostCursorMaxPosX, window.DC.CursorMaxPos.y)
	end

	local is_being_resized = false
	if not bit32.btest(flags, ImGuiOldColumnFlags.NoBorder) and not window.SkipItems then
		local y1 = ImMax(columns.HostCursorPosY, window.ClipRect.Min.y)
		local y2 = ImMin(window.DC.CursorPos.y, window.ClipRect.Max.y)
		local dragging_column = -1
		for n = 1, columns.Count - 1 do
			local column = columns.Columns[n + 1]
			local x = window.Pos.x + ImGui.GetColumnOffset(n)
			local column_id = ColumnID(columns, n)
			local column_hit_hw = ImTrunc(COLUMNS_HIT_RECT_HALF_THICKNESS * g.CurrentDpiScale)
			local column_hit_rect = ImRect.new(ImVec2(x - column_hit_hw, y1), ImVec2(x + column_hit_hw, y2))
			if not ImGui.ItemAdd(column_hit_rect, column_id, nil, ImGuiItemFlags.NoNav) then
				continue
			end

			local hovered, held = false, false
			if not bit32.btest(flags, ImGuiOldColumnFlags.NoResize) then
				local _pressed
				_pressed, hovered, held = ImGui.ButtonBehavior(column_hit_rect, column_id, hovered, held)
				if hovered or held then
					ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
				end
				if held and not bit32.btest(column.Flags, ImGuiOldColumnFlags.NoResize) then
					dragging_column = n
				end
			end

			local col = ImGui.GetColorU32(held and ImGuiCol.SeparatorActive or (hovered and ImGuiCol.SeparatorHovered or ImGuiCol.Separator))
			local xi = IM_TRUNC(x)
			window.DrawList:AddLineV(xi, y1 + 1.0, y2, col)
		end

		if dragging_column ~= -1 then
			if not columns.IsBeingResized then
				for n = 0, columns.Count do
					columns.Columns[n + 1].OffsetNormBeforeResize = columns.Columns[n + 1].OffsetNorm
				end
			end
			is_being_resized = true
			columns.IsBeingResized = true
			local x = ImGui.GetDraggedColumnOffset(columns, dragging_column)
			ImGui.SetColumnOffset(dragging_column, x)
		end
	end
	columns.IsBeingResized = is_being_resized

	window.WorkRect = window.ParentWorkRect
	window.ParentWorkRect = columns.HostBackupParentWorkRect
	window.DC.CurrentColumns = nil
	window.DC.ColumnsOffset.x = 0.0
	window.DC.CursorPos = ImVec2(IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x), window.DC.CursorPos.y)
	ImGui.NavUpdateCurrentWindowIsScrollPushableX()
end

function ImGui.Columns(columns_count, id, borders)
	if columns_count == nil then
		columns_count = 1
	end
	if borders == nil then
		borders = true
	end
	local window = ImGui.GetCurrentWindow()
	assert(columns_count >= 1)

	local flags = borders and 0 or ImGuiOldColumnFlags.NoBorder
	local columns = window.DC.CurrentColumns
	if columns ~= nil and columns.Count == columns_count and columns.Flags == flags then
		return
	end

	if columns ~= nil then
		ImGui.EndColumns()
	end

	if columns_count ~= 1 then
		ImGui.BeginColumns(id, columns_count, flags)
	end
end

return true
