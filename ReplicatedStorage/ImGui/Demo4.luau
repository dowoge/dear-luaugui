local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local Demo = ImGui._Demo

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local FLT_MIN, FLT_MAX = Base.FLT_MIN, Base.FLT_MAX
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiCond = Enums.ImGuiCond
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiCol = Enums.ImGuiCol
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTableColumnFlags = Enums.ImGuiTableColumnFlags
local ImGuiTableRowFlags = Enums.ImGuiTableRowFlags
local ImGuiTableBgTarget = Enums.ImGuiTableBgTarget
local ImGuiSliderFlags = Enums.ImGuiSliderFlags
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiSortDirection = Enums.ImGuiSortDirection

local S_DemoWindowPopups_Popups = { selected_fish = -1, toggles = { true, false, false, false, false } }
function Demo.DemoWindowPopups_Popups()
	local S = S_DemoWindowPopups_Popups
	local names = { "Bream", "Haddock", "Mackerel", "Pollock", "Tilefish" }
	ImGui.TextWrapped("When a popup is active, it inhibits interacting with windows that are behind the popup. Clicking outside the popup closes it.")
	if ImGui.Button("Select..") then
		ImGui.OpenPopup("my_select_popup")
	end
	ImGui.SameLine()
	ImGui.TextUnformatted(S.selected_fish == -1 and "<None>" or names[S.selected_fish + 1])
	if ImGui.BeginPopup("my_select_popup") then
		ImGui.SeparatorText("Aquarium")
		for i = 0, #names - 1 do
			if ImGui.Selectable(names[i + 1]) then
				S.selected_fish = i
			end
		end
		ImGui.EndPopup()
	end
	if ImGui.Button("Toggle..") then
		ImGui.OpenPopup("my_toggle_popup")
	end
	if ImGui.BeginPopup("my_toggle_popup") then
		for i = 0, #names - 1 do
			_, S.toggles[i + 1] = ImGui.MenuItem(names[i + 1], "", S.toggles[i + 1])
		end
		if ImGui.BeginMenu("Sub-menu") then
			ImGui.MenuItem("Click me")
			ImGui.EndMenu()
		end
		ImGui.Separator()
		ImGui.Text("Tooltip here")
		ImGui.SetItemTooltip("I am a tooltip over a popup")
		if ImGui.Button("Stacked Popup") then
			ImGui.OpenPopup("another popup")
		end
		if ImGui.BeginPopup("another popup") then
			for i = 0, #names - 1 do
				_, S.toggles[i + 1] = ImGui.MenuItem(names[i + 1], "", S.toggles[i + 1])
			end
			if ImGui.BeginMenu("Sub-menu") then
				ImGui.MenuItem("Click me")
				if ImGui.Button("Stacked Popup") then
					ImGui.OpenPopup("another popup")
				end
				if ImGui.BeginPopup("another popup") then
					ImGui.Text("I am the last one here.")
					ImGui.EndPopup()
				end
				ImGui.EndMenu()
			end
			ImGui.EndPopup()
		end
		ImGui.EndPopup()
	end
	if ImGui.Button("With a menu..") then
		ImGui.OpenPopup("my_file_popup")
	end
	if ImGui.BeginPopup("my_file_popup", ImGuiWindowFlags.MenuBar) then
		if ImGui.BeginMenuBar() then
			if ImGui.BeginMenu("File") then
				Demo.ShowExampleMenuFile()
				ImGui.EndMenu()
			end
			if ImGui.BeginMenu("Edit") then
				ImGui.MenuItem("Dummy")
				ImGui.EndMenu()
			end
			ImGui.EndMenuBar()
		end
		ImGui.Text("Hello from popup!")
		ImGui.Button("This is a dummy button..")
		ImGui.EndPopup()
	end
end

local S_DemoWindowPopups_ContextMenus = { selected = -1, value = 0.5, name = "Label1" }
function Demo.DemoWindowPopups_ContextMenus()
	local S = S_DemoWindowPopups_ContextMenus
	Demo.HelpMarker("\"Context\" functions are simple helpers to associate a Popup to a given Item or Window identifier.")
	do
		local names = { "Label1", "Label2", "Label3", "Label4", "Label5" }
		for n = 0, 4 do
			if ImGui.Selectable(names[n + 1], S.selected == n) then
				S.selected = n
			end
			if ImGui.BeginPopupContextItem() then
				S.selected = n
				ImGui.Text("This is a popup for \"%s\"!", names[n + 1])
				if ImGui.Button("Close") then
					ImGui.CloseCurrentPopup()
				end
				ImGui.EndPopup()
			end
			ImGui.SetItemTooltip("Right-click to open popup")
		end
	end
	do
		Demo.HelpMarker("Text() elements don't have stable identifiers so we need to provide one.")
		ImGui.Text("Value = %.3f <-- (1) right-click this text", S.value)
		if ImGui.BeginPopupContextItem("my popup") then
			if ImGui.Selectable("Set to zero") then
				S.value = 0.0
			end
			if ImGui.Selectable("Set to PI") then
				S.value = 3.1415
			end
			ImGui.SetNextItemWidth(-FLT_MIN)
			_, S.value = ImGui.DragFloat("##Value", S.value, 0.1, 0.0, 0.0)
			ImGui.EndPopup()
		end
		ImGui.Text("(2) Or right-click this text")
		ImGui.OpenPopupOnItemClick("my popup", ImGuiPopupFlags.MouseButtonRight)
		if ImGui.Button("(3) Or click this button") then
			ImGui.OpenPopup("my popup")
		end
	end
	do
		Demo.HelpMarker("Showcase using a popup ID linked to item ID, with the item having a changing label + stable ID using the ### operator.")
		local buf = Base.ImFormatString("Button: %s###Button", S.name)
		ImGui.Button(buf)
		if ImGui.BeginPopupContextItem() then
			ImGui.Text("Edit name:")
			_, S.name = ImGui.InputText("##edit", S.name)
			if ImGui.Button("Close") then
				ImGui.CloseCurrentPopup()
			end
			ImGui.EndPopup()
		end
		ImGui.SameLine()
		ImGui.Text("(<-- right-click here)")
	end
end

local S_DemoWindowPopups_Modals = { dont_ask_me_next_time = false, item = 1, color = { 0.4, 0.7, 0.0, 0.5 } }
function Demo.DemoWindowPopups_Modals()
	local S = S_DemoWindowPopups_Modals
	ImGui.TextWrapped("Modal windows are like popups but the user cannot close them by clicking outside.")
	if ImGui.Button("Delete..") then
		ImGui.OpenPopup("Delete?")
	end
	local center = ImGui.GetMainViewport():GetCenter()
	ImGui.SetNextWindowPos(center, ImGuiCond.Appearing, ImVec2(0.5, 0.5))
	if ImGui.BeginPopupModal("Delete?", nil, ImGuiWindowFlags.AlwaysAutoResize) then
		ImGui.Text("All those beautiful files will be deleted.\nThis operation cannot be undone!")
		ImGui.Separator()
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0, 0))
		_, S.dont_ask_me_next_time = ImGui.Checkbox("Don't ask me next time", S.dont_ask_me_next_time)
		ImGui.PopStyleVar()
		if ImGui.Button("OK", ImVec2(120, 0)) then
			ImGui.CloseCurrentPopup()
		end
		ImGui.SetItemDefaultFocus()
		ImGui.SameLine()
		if ImGui.Button("Cancel", ImVec2(120, 0)) then
			ImGui.CloseCurrentPopup()
		end
		ImGui.EndPopup()
	end
	if ImGui.Button("Stacked modals..") then
		ImGui.OpenPopup("Stacked 1")
	end
	if ImGui.BeginPopupModal("Stacked 1", nil, ImGuiWindowFlags.MenuBar) then
		if ImGui.BeginMenuBar() then
			if ImGui.BeginMenu("File") then
				ImGui.MenuItem("Some menu item")
				ImGui.EndMenu()
			end
			ImGui.EndMenuBar()
		end
		ImGui.Text("Hello from Stacked The First\nUsing style.Colors[ImGuiCol_ModalWindowDimBg] behind it.")
		_, S.item = ImGui.Combo("Combo", S.item, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")
		ImGui.ColorEdit4("Color", S.color)
		if ImGui.Button("Add another modal..") then
			ImGui.OpenPopup("Stacked 2")
		end
		local unused_open = true
		if ImGui.BeginPopupModal("Stacked 2", unused_open) then
			ImGui.Text("Hello from Stacked The Second!")
			ImGui.ColorEdit4("Color", S.color)
			if ImGui.Button("Close") then
				ImGui.CloseCurrentPopup()
			end
			ImGui.EndPopup()
		end
		if ImGui.Button("Close") then
			ImGui.CloseCurrentPopup()
		end
		ImGui.EndPopup()
	end
end

function Demo.DemoWindowPopups_MenusInRegularWindow()
	ImGui.TextWrapped("Below we are testing adding menu items to a regular window. It's rather unusual but should work!")
	ImGui.Separator()
	ImGui.MenuItem("Menu item", "Ctrl+M")
	if ImGui.BeginMenu("Menu inside a regular window") then
		Demo.ShowExampleMenuFile()
		ImGui.EndMenu()
	end
	ImGui.Separator()
end

function Demo.DemoWindowPopups()
	if not ImGui.CollapsingHeader("Popups & Modal windows") then
		return
	end
	if ImGui.TreeNode("Popups") then
		Demo.DemoWindowPopups_Popups()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Context menus") then
		Demo.DemoWindowPopups_ContextMenus()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Modals") then
		Demo.DemoWindowPopups_Modals()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Menus inside a regular window") then
		Demo.DemoWindowPopups_MenusInRegularWindow()
		ImGui.TreePop()
	end
end

local MyItemColumnID = { ID = 0, Name = 1, Action = 2, Quantity = 3, Description = 4 }

local MyItem = {}
MyItem.__index = MyItem
MyItem.s_current_sort_specs = nil

function MyItem.new(ID, Name, Quantity)
	return setmetatable({ ID = ID, Name = Name, Quantity = Quantity }, MyItem)
end

function MyItem.SortWithSortSpecs(sort_specs, items, items_count)
	MyItem.s_current_sort_specs = sort_specs
	if items_count > 1 then
		Base.ImQsort(items, items_count, MyItem.CompareWithSortSpecs)
	end
	MyItem.s_current_sort_specs = nil
end

function MyItem.CompareWithSortSpecs(lhs, rhs)
	local a = lhs
	local b = rhs
	local specs = MyItem.s_current_sort_specs
	for n = 0, specs.SpecsCount - 1 do
		local sort_spec = specs.Specs[n + 1]
		local delta = 0
		local uid = sort_spec.ColumnUserID
		if uid == MyItemColumnID.ID then
			delta = a.ID - b.ID
		elseif uid == MyItemColumnID.Name then
			delta = a.Name == b.Name and 0 or (a.Name < b.Name and -1 or 1)
		elseif uid == MyItemColumnID.Quantity then
			delta = a.Quantity - b.Quantity
		elseif uid == MyItemColumnID.Description then
			delta = a.Name == b.Name and 0 or (a.Name < b.Name and -1 or 1)
		else
			assert(false)
		end
		if delta > 0 then
			return sort_spec.SortDirection == ImGuiSortDirection.Ascending and 1 or -1
		end
		if delta < 0 then
			return sort_spec.SortDirection == ImGuiSortDirection.Ascending and -1 or 1
		end
	end
	return a.ID - b.ID
end

Demo.MyItem = MyItem

function Demo.PushStyleCompact()
	local style = ImGui.GetStyle()
	ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, Base.ImTruncToInt(style.FramePadding.y * 0.60))
	ImGui.PushStyleVarY(ImGuiStyleVar.ItemSpacing, Base.ImTruncToInt(style.ItemSpacing.y * 0.60))
end

function Demo.PopStyleCompact()
	ImGui.PopStyleVar(2)
end

local sizing_policies = {
	{ Value = ImGuiTableFlags.None, Name = "Default", Tooltip = "Use default sizing policy:\n- ImGuiTableFlags_SizingFixedFit if ScrollX is on or if host window has ImGuiWindowFlags_AlwaysAutoResize.\n- ImGuiTableFlags_SizingStretchSame otherwise." },
	{ Value = ImGuiTableFlags.SizingFixedFit, Name = "ImGuiTableFlags_SizingFixedFit", Tooltip = "Columns default to _WidthFixed (if resizable) or _WidthAuto (if not resizable), matching contents width." },
	{ Value = ImGuiTableFlags.SizingFixedSame, Name = "ImGuiTableFlags_SizingFixedSame", Tooltip = "Columns are all the same width, matching the maximum contents width.\nImplicitly disable ImGuiTableFlags_Resizable and enable ImGuiTableFlags_NoKeepColumnsVisible." },
	{ Value = ImGuiTableFlags.SizingStretchProp, Name = "ImGuiTableFlags_SizingStretchProp", Tooltip = "Columns default to _WidthStretch with weights proportional to their widths." },
	{ Value = ImGuiTableFlags.SizingStretchSame, Name = "ImGuiTableFlags_SizingStretchSame", Tooltip = "Columns default to _WidthStretch with same weights." },
}

function Demo.EditTableSizingFlags(flags)
	local masked = bit32.band(flags, ImGuiTableFlags.SizingMask_)
	local idx = 0
	while idx < #sizing_policies do
		if sizing_policies[idx + 1].Value == masked then
			break
		end
		idx = idx + 1
	end
	local preview_text = ""
	if idx < #sizing_policies then
		preview_text = sizing_policies[idx + 1].Name
		if idx > 0 then
			preview_text = string.sub(preview_text, 16)
		end
	end
	if ImGui.BeginCombo("Sizing Policy", preview_text) then
		for n = 0, #sizing_policies - 1 do
			if ImGui.Selectable(sizing_policies[n + 1].Name, idx == n) then
				flags = bit32.bor(bit32.band(flags, bit32.bnot(ImGuiTableFlags.SizingMask_)), sizing_policies[n + 1].Value)
			end
		end
		ImGui.EndCombo()
	end
	ImGui.SameLine()
	ImGui.TextDisabled("(?)")
	if ImGui.BeginItemTooltip() then
		ImGui.PushTextWrapPos(ImGui.GetFontSize() * 50.0)
		for m = 0, #sizing_policies - 1 do
			ImGui.Separator()
			ImGui.Text("%s:", sizing_policies[m + 1].Name)
			ImGui.Separator()
			ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ImGui.GetStyle().IndentSpacing * 0.5)
			ImGui.TextUnformatted(sizing_policies[m + 1].Tooltip)
		end
		ImGui.PopTextWrapPos()
		ImGui.EndTooltip()
	end
	return flags
end

function Demo.EditTableColumnsFlags(flags)
	_, flags = ImGui.CheckboxFlags("_Disabled", flags, ImGuiTableColumnFlags.Disabled)
	ImGui.SameLine()
	Demo.HelpMarker("Master disable flag (also hide from context menu)")
	_, flags = ImGui.CheckboxFlags("_DefaultHide", flags, ImGuiTableColumnFlags.DefaultHide)
	_, flags = ImGui.CheckboxFlags("_DefaultSort", flags, ImGuiTableColumnFlags.DefaultSort)
	local pressed
	pressed, flags = ImGui.CheckboxFlags("_WidthStretch", flags, ImGuiTableColumnFlags.WidthStretch)
	if pressed then
		flags = bit32.band(flags, bit32.bnot(bit32.bxor(ImGuiTableColumnFlags.WidthMask_, ImGuiTableColumnFlags.WidthStretch)))
	end
	pressed, flags = ImGui.CheckboxFlags("_WidthFixed", flags, ImGuiTableColumnFlags.WidthFixed)
	if pressed then
		flags = bit32.band(flags, bit32.bnot(bit32.bxor(ImGuiTableColumnFlags.WidthMask_, ImGuiTableColumnFlags.WidthFixed)))
	end
	_, flags = ImGui.CheckboxFlags("_NoResize", flags, ImGuiTableColumnFlags.NoResize)
	_, flags = ImGui.CheckboxFlags("_NoReorder", flags, ImGuiTableColumnFlags.NoReorder)
	_, flags = ImGui.CheckboxFlags("_NoHide", flags, ImGuiTableColumnFlags.NoHide)
	_, flags = ImGui.CheckboxFlags("_NoClip", flags, ImGuiTableColumnFlags.NoClip)
	_, flags = ImGui.CheckboxFlags("_NoSort", flags, ImGuiTableColumnFlags.NoSort)
	_, flags = ImGui.CheckboxFlags("_NoSortAscending", flags, ImGuiTableColumnFlags.NoSortAscending)
	_, flags = ImGui.CheckboxFlags("_NoSortDescending", flags, ImGuiTableColumnFlags.NoSortDescending)
	_, flags = ImGui.CheckboxFlags("_NoHeaderLabel", flags, ImGuiTableColumnFlags.NoHeaderLabel)
	_, flags = ImGui.CheckboxFlags("_NoHeaderWidth", flags, ImGuiTableColumnFlags.NoHeaderWidth)
	_, flags = ImGui.CheckboxFlags("_PreferSortAscending", flags, ImGuiTableColumnFlags.PreferSortAscending)
	_, flags = ImGui.CheckboxFlags("_PreferSortDescending", flags, ImGuiTableColumnFlags.PreferSortDescending)
	_, flags = ImGui.CheckboxFlags("_IndentEnable", flags, ImGuiTableColumnFlags.IndentEnable)
	ImGui.SameLine()
	Demo.HelpMarker("Default for column 0")
	_, flags = ImGui.CheckboxFlags("_IndentDisable", flags, ImGuiTableColumnFlags.IndentDisable)
	ImGui.SameLine()
	Demo.HelpMarker("Default for column >0")
	_, flags = ImGui.CheckboxFlags("_AngledHeader", flags, ImGuiTableColumnFlags.AngledHeader)
	return flags
end

function Demo.ShowTableColumnsStatusFlags(flags)
	_, flags = ImGui.CheckboxFlags("_IsEnabled", flags, ImGuiTableColumnFlags.IsEnabled)
	_, flags = ImGui.CheckboxFlags("_IsVisible", flags, ImGuiTableColumnFlags.IsVisible)
	_, flags = ImGui.CheckboxFlags("_IsSorted", flags, ImGuiTableColumnFlags.IsSorted)
	_, flags = ImGui.CheckboxFlags("_IsHovered", flags, ImGuiTableColumnFlags.IsHovered)
end

function Demo.DemoWindowTables_Basic()
	Demo.HelpMarker("Using TableNextRow() + calling TableSetColumnIndex() _before_ each cell, in a loop.")
	if ImGui.BeginTable("table1", 3) then
		for row = 0, 3 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Row %d Column %d", row, column)
			end
		end
		ImGui.EndTable()
	end
	Demo.HelpMarker("Using TableNextRow() + calling TableNextColumn() _before_ each cell, manually.")
	if ImGui.BeginTable("table2", 3) then
		for row = 0, 3 do
			ImGui.TableNextRow()
			ImGui.TableNextColumn()
			ImGui.Text("Row %d", row)
			ImGui.TableNextColumn()
			ImGui.Text("Some contents")
			ImGui.TableNextColumn()
			ImGui.Text("123.456")
		end
		ImGui.EndTable()
	end
	Demo.HelpMarker("Only using TableNextColumn(), which tends to be convenient for tables where every cell contains the same type of contents.\n This is also more similar to the old NextColumn() function of the Columns API, and provided to facilitate the Columns->Tables API transition.")
	if ImGui.BeginTable("table3", 3) then
		for item = 0, 13 do
			ImGui.TableNextColumn()
			ImGui.Text("Item %d", item)
		end
		ImGui.EndTable()
	end
end

local CT_Text = 0
local CT_FillButton = 1
local S_DemoWindowTables_Borders = { flags = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg), display_headers = false, contents_type = CT_Text }
function Demo.DemoWindowTables_Borders()
	local S = S_DemoWindowTables_Borders
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", S.flags, ImGuiTableFlags.RowBg)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", S.flags, ImGuiTableFlags.Borders)
	ImGui.SameLine()
	Demo.HelpMarker("ImGuiTableFlags_Borders\n = ImGuiTableFlags_BordersInnerV\n | ImGuiTableFlags_BordersOuterV\n | ImGuiTableFlags_BordersInnerH\n | ImGuiTableFlags_BordersOuterH")
	ImGui.Indent()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", S.flags, ImGuiTableFlags.BordersH)
	ImGui.Indent()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterH", S.flags, ImGuiTableFlags.BordersOuterH)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerH", S.flags, ImGuiTableFlags.BordersInnerH)
	ImGui.Unindent()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", S.flags, ImGuiTableFlags.BordersV)
	ImGui.Indent()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", S.flags, ImGuiTableFlags.BordersOuterV)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", S.flags, ImGuiTableFlags.BordersInnerV)
	ImGui.Unindent()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuter", S.flags, ImGuiTableFlags.BordersOuter)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInner", S.flags, ImGuiTableFlags.BordersInner)
	ImGui.Unindent()
	ImGui.AlignTextToFramePadding()
	ImGui.Text("Cell contents:")
	ImGui.SameLine()
	_, S.contents_type = ImGui.RadioButton("Text", S.contents_type, CT_Text)
	ImGui.SameLine()
	_, S.contents_type = ImGui.RadioButton("FillButton", S.contents_type, CT_FillButton)
	_, S.display_headers = ImGui.Checkbox("Display headers", S.display_headers)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", S.flags, ImGuiTableFlags.NoBordersInBody)
	ImGui.SameLine()
	Demo.HelpMarker("Disable vertical borders in columns Body (borders will always appear in Headers)")
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table1", 3, S.flags) then
		if S.display_headers then
			ImGui.TableSetupColumn("One")
			ImGui.TableSetupColumn("Two")
			ImGui.TableSetupColumn("Three")
			ImGui.TableHeadersRow()
		end
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				local buf = Base.ImFormatString("Hello %d,%d", column, row)
				if S.contents_type == CT_Text then
					ImGui.TextUnformatted(buf)
				elseif S.contents_type == CT_FillButton then
					ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
				end
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ResizableStretch = { flags = bit32.bor(ImGuiTableFlags.SizingStretchSame, ImGuiTableFlags.Resizable, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ContextMenuInBody) }
function Demo.DemoWindowTables_ResizableStretch()
	local S = S_DemoWindowTables_ResizableStretch
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags, ImGuiTableFlags.Resizable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", S.flags, ImGuiTableFlags.BordersV)
	ImGui.SameLine()
	Demo.HelpMarker("Using the _Resizable flag automatically enables the _BordersInnerV flag as well, this is why the resize borders are still showing when unchecking this.")
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table1", 3, S.flags) then
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Hello %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ResizableFixed = { flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Resizable, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ContextMenuInBody) }
function Demo.DemoWindowTables_ResizableFixed()
	local S = S_DemoWindowTables_ResizableFixed
	Demo.HelpMarker("Using _Resizable + _SizingFixedFit flags.\nFixed-width columns generally makes more sense if you want to use horizontal scrolling.\n\nDouble-click a column border to auto-fit the column to its contents.")
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", S.flags, ImGuiTableFlags.NoHostExtendX)
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table1", 3, S.flags) then
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Hello %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ResizableMixed = { flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable) }
function Demo.DemoWindowTables_ResizableMixed()
	local S = S_DemoWindowTables_ResizableMixed
	Demo.HelpMarker("Using TableSetupColumn() to alter resizing policy on a per-column basis.\n\nWhen combining Fixed and Stretch columns, generally you only want one, maybe two trailing columns to use _WidthStretch.")
	if ImGui.BeginTable("table1", 3, S.flags) then
		ImGui.TableSetupColumn("AAA", ImGuiTableColumnFlags.WidthFixed)
		ImGui.TableSetupColumn("BBB", ImGuiTableColumnFlags.WidthFixed)
		ImGui.TableSetupColumn("CCC", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableHeadersRow()
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("%s %d,%d", column == 2 and "Stretch" or "Fixed", column, row)
			end
		end
		ImGui.EndTable()
	end
	if ImGui.BeginTable("table2", 6, S.flags) then
		ImGui.TableSetupColumn("AAA", ImGuiTableColumnFlags.WidthFixed)
		ImGui.TableSetupColumn("BBB", ImGuiTableColumnFlags.WidthFixed)
		ImGui.TableSetupColumn("CCC", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultHide))
		ImGui.TableSetupColumn("DDD", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("EEE", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("FFF", bit32.bor(ImGuiTableColumnFlags.WidthStretch, ImGuiTableColumnFlags.DefaultHide))
		ImGui.TableHeadersRow()
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 5 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("%s %d,%d", column >= 3 and "Stretch" or "Fixed", column, row)
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ReorderableHideable = { flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV) }
function Demo.DemoWindowTables_ReorderableHideable()
	local S = S_DemoWindowTables_ReorderableHideable
	Demo.HelpMarker("Click and drag column headers to reorder columns.\n\nRight-click on a header to open a context menu.")
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags, ImGuiTableFlags.Resizable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Reorderable", S.flags, ImGuiTableFlags.Reorderable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Hideable", S.flags, ImGuiTableFlags.Hideable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", S.flags, ImGuiTableFlags.NoBordersInBody)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", S.flags, ImGuiTableFlags.NoBordersInBodyUntilResize)
	ImGui.SameLine()
	Demo.HelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)")
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", S.flags, ImGuiTableFlags.HighlightHoveredColumn)
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table1", 3, S.flags) then
		ImGui.TableSetupColumn("One")
		ImGui.TableSetupColumn("Two")
		ImGui.TableSetupColumn("Three")
		ImGui.TableHeadersRow()
		for row = 0, 5 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Hello %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
	if ImGui.BeginTable("table2", 3, bit32.bor(S.flags, ImGuiTableFlags.SizingFixedFit), ImVec2(0.0, 0.0)) then
		ImGui.TableSetupColumn("One")
		ImGui.TableSetupColumn("Two")
		ImGui.TableSetupColumn("Three")
		ImGui.TableHeadersRow()
		for row = 0, 5 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Fixed %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_Padding = { flags1 = ImGuiTableFlags.BordersV, show_headers = false, flags2 = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg), cell_padding = { 0.0, 0.0 }, show_widget_frame_bg = true, text_bufs = {}, init = true }
function Demo.DemoWindowTables_Padding()
	local S = S_DemoWindowTables_Padding
	Demo.HelpMarker("We often want outer padding activated when any using features which makes the edges of a column visible:\ne.g.:\n- BorderOuterV\n- any form of row selection\nBecause of this, activating BorderOuterV sets the default to PadOuterX. Using PadOuterX or NoPadOuterX you can override the default.\n\nActual padding values are using style.CellPadding.\n\nIn this demo we don't show horizontal borders to emphasize how they don't affect default horizontal padding.")
	Demo.PushStyleCompact()
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_PadOuterX", S.flags1, ImGuiTableFlags.PadOuterX)
	ImGui.SameLine()
	Demo.HelpMarker("Enable outer-most padding (default if ImGuiTableFlags_BordersOuterV is set)")
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadOuterX", S.flags1, ImGuiTableFlags.NoPadOuterX)
	ImGui.SameLine()
	Demo.HelpMarker("Disable outer-most padding (default if ImGuiTableFlags_BordersOuterV is not set)")
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadInnerX", S.flags1, ImGuiTableFlags.NoPadInnerX)
	ImGui.SameLine()
	Demo.HelpMarker("Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off)")
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", S.flags1, ImGuiTableFlags.BordersOuterV)
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", S.flags1, ImGuiTableFlags.BordersInnerV)
	_, S.show_headers = ImGui.Checkbox("show_headers", S.show_headers)
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table_padding", 3, S.flags1) then
		if S.show_headers then
			ImGui.TableSetupColumn("One")
			ImGui.TableSetupColumn("Two")
			ImGui.TableSetupColumn("Three")
			ImGui.TableHeadersRow()
		end
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				if row == 0 then
					ImGui.Text("Avail %.2f", ImGui.GetContentRegionAvail().x)
				else
					local buf = Base.ImFormatString("Hello %d,%d", column, row)
					ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
				end
			end
		end
		ImGui.EndTable()
	end
	Demo.HelpMarker("Setting style.CellPadding to (0,0) or a custom value.")
	Demo.PushStyleCompact()
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", S.flags2, ImGuiTableFlags.Borders)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", S.flags2, ImGuiTableFlags.BordersH)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", S.flags2, ImGuiTableFlags.BordersV)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInner", S.flags2, ImGuiTableFlags.BordersInner)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuter", S.flags2, ImGuiTableFlags.BordersOuter)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", S.flags2, ImGuiTableFlags.RowBg)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags2, ImGuiTableFlags.Resizable)
	_, S.show_widget_frame_bg = ImGui.Checkbox("show_widget_frame_bg", S.show_widget_frame_bg)
	ImGui.SliderFloat2("CellPadding", S.cell_padding, 0.0, 10.0, "%.0f")
	Demo.PopStyleCompact()
	ImGui.PushStyleVar(ImGuiStyleVar.CellPadding, ImVec2(S.cell_padding[1], S.cell_padding[2]))
	if ImGui.BeginTable("table_padding_2", 3, S.flags2) then
		if not S.show_widget_frame_bg then
			ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
		end
		for cell = 0, 3 * 5 - 1 do
			ImGui.TableNextColumn()
			if S.init then
				S.text_bufs[cell + 1] = "edit me"
			end
			ImGui.SetNextItemWidth(-FLT_MIN)
			ImGui.PushID(cell)
			_, S.text_bufs[cell + 1] = ImGui.InputText("##cell", S.text_bufs[cell + 1])
			ImGui.PopID()
		end
		if not S.show_widget_frame_bg then
			ImGui.PopStyleColor()
		end
		S.init = false
		ImGui.EndTable()
	end
	ImGui.PopStyleVar()
end

local ContentsTypeAdvanced = { ShowWidth = 0, ShortText = 1, LongText = 2, Button = 3, FillButton = 4, InputText = 5 }
local S_DemoWindowTables_SizingPolicies = {
	flags1 = bit32.bor(ImGuiTableFlags.BordersV, ImGuiTableFlags.BordersOuterH, ImGuiTableFlags.RowBg, ImGuiTableFlags.ContextMenuInBody),
	sizing_policy_flags = { ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.SizingFixedSame, ImGuiTableFlags.SizingStretchProp, ImGuiTableFlags.SizingStretchSame },
	flags = bit32.bor(ImGuiTableFlags.ScrollY, ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.Resizable),
	contents_type = ContentsTypeAdvanced.ShowWidth,
	column_count = 3,
	text_buf = "",
}
function Demo.DemoWindowTables_SizingPolicies(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_SizingPolicies
	Demo.PushStyleCompact()
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags1, ImGuiTableFlags.Resizable)
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", S.flags1, ImGuiTableFlags.NoHostExtendX)
	Demo.PopStyleCompact()
	for table_n = 0, 3 do
		ImGui.PushID(table_n)
		ImGui.SetNextItemWidth(TEXT_BASE_WIDTH * 30)
		S.sizing_policy_flags[table_n + 1] = Demo.EditTableSizingFlags(S.sizing_policy_flags[table_n + 1])
		if ImGui.BeginTable("table1", 3, bit32.bor(S.sizing_policy_flags[table_n + 1], S.flags1)) then
			for row = 0, 2 do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text("Oh dear")
				ImGui.TableNextColumn()
				ImGui.Text("Oh dear")
				ImGui.TableNextColumn()
				ImGui.Text("Oh dear")
			end
			ImGui.EndTable()
		end
		if ImGui.BeginTable("table2", 3, bit32.bor(S.sizing_policy_flags[table_n + 1], S.flags1)) then
			for row = 0, 2 do
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text("AAAA")
				ImGui.TableNextColumn()
				ImGui.Text("BBBBBBBB")
				ImGui.TableNextColumn()
				ImGui.Text("CCCCCCCCCCCC")
			end
			ImGui.EndTable()
		end
		ImGui.PopID()
	end
	ImGui.Spacing()
	ImGui.TextUnformatted("Advanced")
	ImGui.SameLine()
	Demo.HelpMarker("This section allows you to interact and see the effect of various sizing policies depending on whether Scroll is enabled and the contents of your columns.")
	Demo.PushStyleCompact()
	ImGui.PushID("Advanced")
	ImGui.PushItemWidth(TEXT_BASE_WIDTH * 30)
	S.flags = Demo.EditTableSizingFlags(S.flags)
	_, S.contents_type = ImGui.Combo("Contents", S.contents_type, "Show width\0Short Text\0Long Text\0Button\0Fill Button\0InputText\0")
	if S.contents_type == ContentsTypeAdvanced.FillButton then
		ImGui.SameLine()
		Demo.HelpMarker("Be mindful that using right-alignment (e.g. size.x = -FLT_MIN) creates a feedback loop where contents width can feed into auto-column width can feed into contents width.")
	end
	_, S.column_count = ImGui.DragInt("Columns", S.column_count, 0.1, 1, 64, "%d", ImGuiSliderFlags.AlwaysClamp)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags, ImGuiTableFlags.Resizable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PreciseWidths", S.flags, ImGuiTableFlags.PreciseWidths)
	ImGui.SameLine()
	Demo.HelpMarker("Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.")
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", S.flags, ImGuiTableFlags.ScrollX)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", S.flags, ImGuiTableFlags.ScrollY)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoClip", S.flags, ImGuiTableFlags.NoClip)
	ImGui.PopItemWidth()
	ImGui.PopID()
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table2", S.column_count, S.flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 7)) then
		for cell = 0, 10 * S.column_count - 1 do
			ImGui.TableNextColumn()
			local column = ImGui.TableGetColumnIndex()
			local row = ImGui.TableGetRowIndex()
			ImGui.PushID(cell)
			local label = Base.ImFormatString("Hello %d,%d", column, row)
			local ct = S.contents_type
			if ct == ContentsTypeAdvanced.ShortText then
				ImGui.TextUnformatted(label)
			elseif ct == ContentsTypeAdvanced.LongText then
				ImGui.Text("Some %s text %d,%d\nOver two lines..", column == 0 and "long" or "longeeer", column, row)
			elseif ct == ContentsTypeAdvanced.ShowWidth then
				ImGui.Text("W: %.1f", ImGui.GetContentRegionAvail().x)
			elseif ct == ContentsTypeAdvanced.Button then
				ImGui.Button(label)
			elseif ct == ContentsTypeAdvanced.FillButton then
				ImGui.Button(label, ImVec2(-FLT_MIN, 0.0))
			elseif ct == ContentsTypeAdvanced.InputText then
				ImGui.SetNextItemWidth(-FLT_MIN)
				_, S.text_buf = ImGui.InputText("##", S.text_buf)
			end
			ImGui.PopID()
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_VerticalScrolling = { flags = bit32.bor(ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable) }
function Demo.DemoWindowTables_VerticalScrolling(TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_VerticalScrolling
	Demo.HelpMarker("Here we activate ScrollY, which will create a child window container to allow hosting scrollable contents.\n\nWe also demonstrate using ImGuiListClipper to virtualize the submission of many items.")
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", S.flags, ImGuiTableFlags.ScrollY)
	Demo.PopStyleCompact()
	local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 8)
	if ImGui.BeginTable("table_scrolly", 3, S.flags, outer_size) then
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableSetupColumn("One", ImGuiTableColumnFlags.None)
		ImGui.TableSetupColumn("Two", ImGuiTableColumnFlags.None)
		ImGui.TableSetupColumn("Three", ImGuiTableColumnFlags.None)
		ImGui.TableHeadersRow()
		local clipper = Structs.ImGuiListClipper.new()
		clipper:Begin(1000)
		while clipper:Step() do
			for row = clipper.DisplayStart, clipper.DisplayEnd - 1 do
				ImGui.TableNextRow()
				for column = 0, 2 do
					ImGui.TableSetColumnIndex(column)
					ImGui.Text("Hello %d,%d", column, row)
				end
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_HorizontalScrolling = {
	flags = bit32.bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable),
	freeze_cols = 1,
	freeze_rows = 1,
	flags2 = bit32.bor(ImGuiTableFlags.SizingStretchSame, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.RowBg, ImGuiTableFlags.ContextMenuInBody),
	inner_width = 1000.0,
}
function Demo.DemoWindowTables_HorizontalScrolling(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_HorizontalScrolling
	Demo.HelpMarker("When ScrollX is enabled, the default sizing policy becomes ImGuiTableFlags_SizingFixedFit, as automatically stretching columns doesn't make much sense with horizontal scrolling.\n\nAlso note that as of the current version, you will almost always want to enable ScrollY along with ScrollX, because the container window won't automatically extend vertically to fix contents (this may be improved in future versions).")
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags, ImGuiTableFlags.Resizable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", S.flags, ImGuiTableFlags.ScrollX)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", S.flags, ImGuiTableFlags.ScrollY)
	ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
	_, S.freeze_cols = ImGui.DragInt("freeze_cols", S.freeze_cols, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
	ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
	_, S.freeze_rows = ImGui.DragInt("freeze_rows", S.freeze_rows, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
	Demo.PopStyleCompact()
	local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 8)
	if ImGui.BeginTable("table_scrollx", 7, S.flags, outer_size) then
		ImGui.TableSetupScrollFreeze(S.freeze_cols, S.freeze_rows)
		ImGui.TableSetupColumn("Line #", ImGuiTableColumnFlags.NoHide)
		ImGui.TableSetupColumn("One")
		ImGui.TableSetupColumn("Two")
		ImGui.TableSetupColumn("Three")
		ImGui.TableSetupColumn("Four")
		ImGui.TableSetupColumn("Five")
		ImGui.TableSetupColumn("Six")
		ImGui.TableHeadersRow()
		for row = 0, 19 do
			ImGui.TableNextRow()
			for column = 0, 6 do
				if not ImGui.TableSetColumnIndex(column) and column > 0 then
					continue
				end
				if column == 0 then
					ImGui.Text("Line %d", row)
				else
					ImGui.Text("Hello world %d,%d", column, row)
				end
			end
		end
		ImGui.EndTable()
	end
	ImGui.Spacing()
	ImGui.TextUnformatted("Stretch + ScrollX")
	ImGui.SameLine()
	Demo.HelpMarker("Showcase using Stretch columns + ScrollX together: this is rather unusual and only makes sense when specifying an 'inner_width' for the table!\nWithout an explicit value, inner_width is == outer_size.x and therefore using Stretch columns along with ScrollX doesn't make sense.")
	Demo.PushStyleCompact()
	ImGui.PushID("flags3")
	ImGui.PushItemWidth(TEXT_BASE_WIDTH * 30)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", S.flags2, ImGuiTableFlags.ScrollX)
	_, S.inner_width = ImGui.DragFloat("inner_width", S.inner_width, 1.0, 0.0, FLT_MAX, "%.1f")
	ImGui.PopItemWidth()
	ImGui.PopID()
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table2", 7, S.flags2, outer_size, S.inner_width) then
		for cell = 0, 20 * 7 - 1 do
			ImGui.TableNextColumn()
			ImGui.Text("Hello world %d,%d", ImGui.TableGetColumnIndex(), ImGui.TableGetRowIndex())
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ColumnsFlags = { column_flags = { ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.None, ImGuiTableColumnFlags.DefaultHide }, column_flags_out = { 0, 0, 0 } }
function Demo.DemoWindowTables_ColumnsFlags(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_ColumnsFlags
	local column_count = 3
	local column_names = { "One", "Two", "Three" }
	if ImGui.BeginTable("table_columns_flags_checkboxes", column_count, ImGuiTableFlags.None) then
		Demo.PushStyleCompact()
		for column = 0, column_count - 1 do
			ImGui.TableNextColumn()
			ImGui.PushID(column)
			ImGui.AlignTextToFramePadding()
			ImGui.Text("'%s'", column_names[column + 1])
			ImGui.Spacing()
			ImGui.Text("Input flags:")
			S.column_flags[column + 1] = Demo.EditTableColumnsFlags(S.column_flags[column + 1])
			ImGui.Spacing()
			ImGui.Text("Output flags:")
			ImGui.BeginDisabled()
			Demo.ShowTableColumnsStatusFlags(S.column_flags_out[column + 1])
			ImGui.EndDisabled()
			ImGui.PopID()
		end
		Demo.PopStyleCompact()
		ImGui.EndTable()
	end
	local flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY,
		ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV,
		ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable)
	local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 9)
	if ImGui.BeginTable("table_columns_flags", column_count, flags, outer_size) then
		local has_angled_header = false
		for column = 0, column_count - 1 do
			has_angled_header = has_angled_header or bit32.btest(S.column_flags[column + 1], ImGuiTableColumnFlags.AngledHeader)
			ImGui.TableSetupColumn(column_names[column + 1], S.column_flags[column + 1])
		end
		if has_angled_header then
			ImGui.TableAngledHeadersRow()
		end
		ImGui.TableHeadersRow()
		for column = 0, column_count - 1 do
			S.column_flags_out[column + 1] = ImGui.TableGetColumnFlags(column)
		end
		local indent_step = Base.ImTruncToInt(TEXT_BASE_WIDTH) // 2
		for row = 0, 7 do
			ImGui.Indent(indent_step)
			ImGui.TableNextRow()
			for column = 0, column_count - 1 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("%s %s", column == 0 and "Indented" or "Hello", ImGui.TableGetColumnName(column))
			end
		end
		ImGui.Unindent(indent_step * 8.0)
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ColumnsWidths = { flags1 = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.NoBordersInBodyUntilResize), flags2 = ImGuiTableFlags.None }
function Demo.DemoWindowTables_ColumnsWidths(TEXT_BASE_WIDTH)
	local S = S_DemoWindowTables_ColumnsWidths
	Demo.HelpMarker("Using TableSetupColumn() to setup default width.")
	Demo.PushStyleCompact()
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags1, ImGuiTableFlags.Resizable)
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", S.flags1, ImGuiTableFlags.NoBordersInBodyUntilResize)
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table1", 3, S.flags1) then
		ImGui.TableSetupColumn("one", ImGuiTableColumnFlags.WidthFixed, 100.0)
		ImGui.TableSetupColumn("two", ImGuiTableColumnFlags.WidthFixed, 200.0)
		ImGui.TableSetupColumn("three", ImGuiTableColumnFlags.WidthFixed)
		ImGui.TableHeadersRow()
		for row = 0, 3 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableSetColumnIndex(column)
				if row == 0 then
					ImGui.Text("(w: %5.1f)", ImGui.GetContentRegionAvail().x)
				else
					ImGui.Text("Hello %d,%d", column, row)
				end
			end
		end
		ImGui.EndTable()
	end
	Demo.HelpMarker("Using TableSetupColumn() to setup explicit width.\n\nUnless _NoKeepColumnsVisible is set, fixed columns with set width may still be shrunk down if there's not enough space in the host.")
	Demo.PushStyleCompact()
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_NoKeepColumnsVisible", S.flags2, ImGuiTableFlags.NoKeepColumnsVisible)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", S.flags2, ImGuiTableFlags.BordersInnerV)
	_, S.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", S.flags2, ImGuiTableFlags.BordersOuterV)
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table2", 4, S.flags2) then
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, 100.0)
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 15.0)
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 30.0)
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 15.0)
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 3 do
				ImGui.TableSetColumnIndex(column)
				if row == 0 then
					ImGui.Text("(w: %5.1f)", ImGui.GetContentRegionAvail().x)
				else
					ImGui.Text("Hello %d,%d", column, row)
				end
			end
		end
		ImGui.EndTable()
	end
end

function Demo.DemoWindowTables_NestedTables(TEXT_BASE_HEIGHT)
	Demo.HelpMarker("This demonstrates embedding a table into another table cell.")
	if ImGui.BeginTable("table_nested1", 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
		ImGui.TableSetupColumn("A0")
		ImGui.TableSetupColumn("A1")
		ImGui.TableHeadersRow()
		ImGui.TableNextColumn()
		ImGui.Text("A0 Row 0")
		do
			local rows_height = (TEXT_BASE_HEIGHT * 2.0) + (ImGui.GetStyle().CellPadding.y * 2.0)
			if ImGui.BeginTable("table_nested2", 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
				ImGui.TableSetupColumn("B0")
				ImGui.TableSetupColumn("B1")
				ImGui.TableHeadersRow()
				ImGui.TableNextRow(ImGuiTableRowFlags.None, rows_height)
				ImGui.TableNextColumn()
				ImGui.Text("B0 Row 0")
				ImGui.TableNextColumn()
				ImGui.Text("B1 Row 0")
				ImGui.TableNextRow(ImGuiTableRowFlags.None, rows_height)
				ImGui.TableNextColumn()
				ImGui.Text("B0 Row 1")
				ImGui.TableNextColumn()
				ImGui.Text("B1 Row 1")
				ImGui.EndTable()
			end
		end
		ImGui.TableNextColumn()
		ImGui.Text("A1 Row 0")
		ImGui.TableNextColumn()
		ImGui.Text("A0 Row 1")
		ImGui.TableNextColumn()
		ImGui.Text("A1 Row 1")
		ImGui.EndTable()
	end
end

function Demo.DemoWindowTables_RowHeight(TEXT_BASE_HEIGHT)
	Demo.HelpMarker("You can pass a 'min_row_height' to TableNextRow().\n\nRows are padded with 'style.CellPadding.y' on top and bottom, so effectively the minimum row height will always be >= 'style.CellPadding.y * 2.0f'.\n\nWe cannot honor a _maximum_ row height as that would require a unique clipping rectangle per row.")
	if ImGui.BeginTable("table_row_height", 1, ImGuiTableFlags.Borders) then
		for row = 0, 7 do
			local min_row_height = Base.ImTruncToInt(TEXT_BASE_HEIGHT * 0.30 * row + ImGui.GetStyle().CellPadding.y * 2.0)
			ImGui.TableNextRow(ImGuiTableRowFlags.None, min_row_height)
			ImGui.TableNextColumn()
			ImGui.Text("min_row_height = %.2f", min_row_height)
		end
		ImGui.EndTable()
	end
	Demo.HelpMarker("Showcase using SameLine(0,0) to share Current Line Height between cells.\n\nPlease note that Tables Row Height is not the same thing as Current Line Height, as a table cell may contains multiple lines.")
	if ImGui.BeginTable("table_share_lineheight", 2, ImGuiTableFlags.Borders) then
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		ImGui.ColorButton("##1", ImVec4(0.13, 0.26, 0.40, 1.0), ImGuiColorEditFlags.None, ImVec2(40, 40))
		ImGui.TableNextColumn()
		ImGui.Text("Line 1")
		ImGui.Text("Line 2")
		ImGui.TableNextRow()
		ImGui.TableNextColumn()
		ImGui.ColorButton("##2", ImVec4(0.13, 0.26, 0.40, 1.0), ImGuiColorEditFlags.None, ImVec2(40, 40))
		ImGui.TableNextColumn()
		ImGui.SameLine(0.0, 0.0)
		ImGui.Text("Line 1, with SameLine(0,0)")
		ImGui.Text("Line 2")
		ImGui.EndTable()
	end
	Demo.HelpMarker("Showcase altering CellPadding.y between rows. Note that CellPadding.x is locked for the entire table.")
	if ImGui.BeginTable("table_changing_cellpadding_y", 1, ImGuiTableFlags.Borders) then
		local style = ImGui.GetStyle()
		for row = 0, 7 do
			if row % 3 == 2 then
				ImGui.PushStyleVarY(ImGuiStyleVar.CellPadding, 20.0)
			end
			ImGui.TableNextRow(ImGuiTableRowFlags.None)
			ImGui.TableNextColumn()
			ImGui.Text("CellPadding.y = %.2f", style.CellPadding.y)
			if row % 3 == 2 then
				ImGui.PopStyleVar()
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_OuterSize = { flags = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ContextMenuInBody, ImGuiTableFlags.RowBg, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.NoHostExtendX) }
function Demo.DemoWindowTables_OuterSize(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_OuterSize
	ImGui.Text("Using NoHostExtendX and NoHostExtendY:")
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", S.flags, ImGuiTableFlags.NoHostExtendX)
	ImGui.SameLine()
	Demo.HelpMarker("Make outer width auto-fit to columns, overriding outer_size.x value.\n\nOnly available when ScrollX/ScrollY are disabled and Stretch columns are not used.")
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendY", S.flags, ImGuiTableFlags.NoHostExtendY)
	ImGui.SameLine()
	Demo.HelpMarker("Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit).\n\nOnly available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.")
	Demo.PopStyleCompact()
	local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 5.5)
	if ImGui.BeginTable("table1", 3, S.flags, outer_size) then
		for row = 0, 9 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableNextColumn()
				ImGui.Text("Cell %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
	ImGui.SameLine()
	ImGui.Text("Hello!")
	ImGui.Spacing()
	ImGui.Text("Using explicit size:")
	if ImGui.BeginTable("table2", 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg), ImVec2(TEXT_BASE_WIDTH * 30, 0.0)) then
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				ImGui.TableNextColumn()
				ImGui.Text("Cell %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
	ImGui.SameLine()
	if ImGui.BeginTable("table3", 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg), ImVec2(TEXT_BASE_WIDTH * 30, 0.0)) then
		local rows_height = TEXT_BASE_HEIGHT * 1.5 + ImGui.GetStyle().CellPadding.y * 2.0
		for row = 0, 2 do
			ImGui.TableNextRow(0, rows_height)
			for column = 0, 2 do
				ImGui.TableNextColumn()
				ImGui.Text("Cell %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_BackgroundColor = { flags = ImGuiTableFlags.RowBg, row_bg_type = 1, row_bg_target = 1, cell_bg_type = 1 }
function Demo.DemoWindowTables_BackgroundColor()
	local S = S_DemoWindowTables_BackgroundColor
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", S.flags, ImGuiTableFlags.Borders)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", S.flags, ImGuiTableFlags.RowBg)
	ImGui.SameLine()
	Demo.HelpMarker("ImGuiTableFlags_RowBg automatically sets RowBg0 to alternative colors pulled from the Style.")
	_, S.row_bg_type = ImGui.Combo("row bg type", S.row_bg_type, "None\0Red\0Gradient\0")
	_, S.row_bg_target = ImGui.Combo("row bg target", S.row_bg_target, "RowBg0\0RowBg1\0")
	ImGui.SameLine()
	Demo.HelpMarker("Target RowBg0 to override the alternating odd/even colors,\nTarget RowBg1 to blend with them.")
	_, S.cell_bg_type = ImGui.Combo("cell bg type", S.cell_bg_type, "None\0Blue\0")
	ImGui.SameLine()
	Demo.HelpMarker("We are colorizing cells to B1->C2 here.")
	assert(S.row_bg_type >= 0 and S.row_bg_type <= 2)
	assert(S.row_bg_target >= 0 and S.row_bg_target <= 1)
	assert(S.cell_bg_type >= 0 and S.cell_bg_type <= 1)
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table1", 5, S.flags) then
		for row = 0, 5 do
			ImGui.TableNextRow()
			if S.row_bg_type ~= 0 then
				local row_bg_color = ImGui.GetColorU32(S.row_bg_type == 1 and ImVec4(0.7, 0.3, 0.3, 0.65) or ImVec4(0.2 + row * 0.1, 0.2, 0.2, 0.65))
				ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + S.row_bg_target, row_bg_color)
			end
			for column = 0, 4 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("%c%c", string.byte("A") + row, string.byte("0") + column)
				if row >= 1 and row <= 2 and column >= 1 and column <= 2 and S.cell_bg_type == 1 then
					local cell_bg_color = ImGui.GetColorU32(ImVec4(0.3, 0.3, 0.7, 0.65))
					ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, cell_bg_color)
				end
			end
		end
		ImGui.EndTable()
	end
end

local MyTreeNode = {}
MyTreeNode.__index = MyTreeNode

function MyTreeNode.new(Name, Type, Size, ChildIdx, ChildCount)
	return setmetatable({ Name = Name, Type = Type, Size = Size, ChildIdx = ChildIdx, ChildCount = ChildCount }, MyTreeNode)
end

local S_DemoWindowTables_TreeView = {
	table_flags = bit32.bor(ImGuiTableFlags.BordersV, ImGuiTableFlags.BordersOuterH, ImGuiTableFlags.Resizable, ImGuiTableFlags.RowBg, ImGuiTableFlags.NoBordersInBody),
	tree_node_flags_base = bit32.bor(ImGuiTreeNodeFlags.SpanAllColumns, ImGuiTreeNodeFlags.DefaultOpen, ImGuiTreeNodeFlags.DrawLinesFull),
}

function MyTreeNode.DisplayNode(node, all_nodes)
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	local is_folder = node.ChildCount > 0
	local node_flags = S_DemoWindowTables_TreeView.tree_node_flags_base
	if node ~= all_nodes[1] then
		node_flags = bit32.band(node_flags, bit32.bnot(ImGuiTreeNodeFlags.LabelSpanAllColumns))
	end
	if is_folder then
		local open = ImGui.TreeNodeEx(node.Name, node_flags)
		if not bit32.btest(node_flags, ImGuiTreeNodeFlags.LabelSpanAllColumns) then
			ImGui.TableNextColumn()
			ImGui.TextDisabled("--")
			ImGui.TableNextColumn()
			ImGui.TextUnformatted(node.Type)
		end
		if open then
			for child_n = 0, node.ChildCount - 1 do
				MyTreeNode.DisplayNode(all_nodes[node.ChildIdx + child_n + 1], all_nodes)
			end
			ImGui.TreePop()
		end
	else
		ImGui.TreeNodeEx(node.Name, bit32.bor(node_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.NoTreePushOnOpen))
		ImGui.TableNextColumn()
		ImGui.Text("%d", node.Size)
		ImGui.TableNextColumn()
		ImGui.TextUnformatted(node.Type)
	end
end

Demo.MyTreeNode = MyTreeNode

local tree_nodes = {
	MyTreeNode.new("Root with Long Name", "Folder", -1, 1, 3),
	MyTreeNode.new("Music", "Folder", -1, 4, 2),
	MyTreeNode.new("Textures", "Folder", -1, 6, 3),
	MyTreeNode.new("desktop.ini", "System file", 1024, -1, -1),
	MyTreeNode.new("File1_a.wav", "Audio file", 123000, -1, -1),
	MyTreeNode.new("File1_b.wav", "Audio file", 456000, -1, -1),
	MyTreeNode.new("Image001.png", "Image file", 203128, -1, -1),
	MyTreeNode.new("Copy of Image001.png", "Image file", 203256, -1, -1),
	MyTreeNode.new("Copy of Image001 (Final2).png", "Image file", 203512, -1, -1),
}

function Demo.DemoWindowTables_TreeView(TEXT_BASE_WIDTH)
	local S = S_DemoWindowTables_TreeView
	_, S.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth", S.tree_node_flags_base, ImGuiTreeNodeFlags.SpanFullWidth)
	_, S.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanLabelWidth", S.tree_node_flags_base, ImGuiTreeNodeFlags.SpanLabelWidth)
	_, S.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAllColumns", S.tree_node_flags_base, ImGuiTreeNodeFlags.SpanAllColumns)
	_, S.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_LabelSpanAllColumns", S.tree_node_flags_base, ImGuiTreeNodeFlags.LabelSpanAllColumns)
	ImGui.SameLine()
	Demo.HelpMarker("Useful if you know that you aren't displaying contents in other columns")
	Demo.HelpMarker("See \"Columns flags\" section to configure how indentation is applied to individual columns.")
	if ImGui.BeginTable("3ways", 3, S.table_flags) then
		ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.NoHide)
		ImGui.TableSetupColumn("Size", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 12.0)
		ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 18.0)
		ImGui.TableHeadersRow()
		MyTreeNode.DisplayNode(tree_nodes[1], tree_nodes)
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ItemWidth = { dummy_f = 0.0 }
function Demo.DemoWindowTables_ItemWidth(TEXT_BASE_WIDTH)
	local S = S_DemoWindowTables_ItemWidth
	Demo.HelpMarker("Showcase using PushItemWidth() and how it is preserved on a per-column basis.\n\nNote that on auto-resizing non-resizable fixed columns, querying the content width for e.g. right-alignment doesn't make sense.")
	if ImGui.BeginTable("table_item_width", 3, ImGuiTableFlags.Borders) then
		ImGui.TableSetupColumn("small")
		ImGui.TableSetupColumn("half")
		ImGui.TableSetupColumn("right-align")
		ImGui.TableHeadersRow()
		for row = 0, 2 do
			ImGui.TableNextRow()
			if row == 0 then
				ImGui.TableSetColumnIndex(0)
				ImGui.PushItemWidth(TEXT_BASE_WIDTH * 3.0)
				ImGui.TableSetColumnIndex(1)
				ImGui.PushItemWidth(-ImGui.GetContentRegionAvail().x * 0.5)
				ImGui.TableSetColumnIndex(2)
				ImGui.PushItemWidth(-FLT_MIN)
			end
			ImGui.PushID(row)
			ImGui.TableSetColumnIndex(0)
			_, S.dummy_f = ImGui.SliderFloat("float0", S.dummy_f, 0.0, 1.0)
			ImGui.TableSetColumnIndex(1)
			_, S.dummy_f = ImGui.SliderFloat("float1", S.dummy_f, 0.0, 1.0)
			ImGui.TableSetColumnIndex(2)
			_, S.dummy_f = ImGui.SliderFloat("##float2", S.dummy_f, 0.0, 1.0)
			ImGui.PopID()
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_CustomHeaders = { column_selected = { false, false, false } }
function Demo.DemoWindowTables_CustomHeaders()
	local S = S_DemoWindowTables_CustomHeaders
	local COLUMNS_COUNT = 3
	if ImGui.BeginTable("table_custom_headers", COLUMNS_COUNT, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
		ImGui.TableSetupColumn("Apricot")
		ImGui.TableSetupColumn("Banana")
		ImGui.TableSetupColumn("Cherry")
		ImGui.TableNextRow(ImGuiTableRowFlags.Headers)
		for column = 0, COLUMNS_COUNT - 1 do
			ImGui.TableSetColumnIndex(column)
			local column_name = ImGui.TableGetColumnName(column)
			ImGui.PushID(column)
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0, 0))
			_, S.column_selected[column + 1] = ImGui.Checkbox("##checkall", S.column_selected[column + 1])
			ImGui.PopStyleVar()
			ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
			ImGui.TableHeader(column_name)
			ImGui.PopID()
		end
		for row = 0, 4 do
			ImGui.TableNextRow()
			for column = 0, 2 do
				local buf = Base.ImFormatString("Cell %d,%d", column, row)
				ImGui.TableSetColumnIndex(column)
				ImGui.Selectable(buf, S.column_selected[column + 1])
			end
		end
		ImGui.EndTable()
	end
end

local angled_column_names = { "Track", "cabasa", "ride", "smash", "tom-hi", "tom-mid", "tom-low", "hihat-o", "hihat-c", "snare-s", "snare-c", "clap", "rim", "kick" }
local S_DemoWindowTables_AngledHeaders = {
	table_flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersInnerH, ImGuiTableFlags.Hideable, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.HighlightHoveredColumn),
	column_flags = bit32.bor(ImGuiTableColumnFlags.AngledHeader, ImGuiTableColumnFlags.WidthFixed),
	bools = {},
	frozen_cols = 1,
	frozen_rows = 2,
}
for i = 1, #angled_column_names * 12 do
	S_DemoWindowTables_AngledHeaders.bools[i] = false
end
function Demo.DemoWindowTables_AngledHeaders(TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_AngledHeaders
	local columns_count = #angled_column_names
	local rows_count = 12
	_, S.table_flags = ImGui.CheckboxFlags("_ScrollX", S.table_flags, ImGuiTableFlags.ScrollX)
	_, S.table_flags = ImGui.CheckboxFlags("_ScrollY", S.table_flags, ImGuiTableFlags.ScrollY)
	_, S.table_flags = ImGui.CheckboxFlags("_Resizable", S.table_flags, ImGuiTableFlags.Resizable)
	_, S.table_flags = ImGui.CheckboxFlags("_Sortable", S.table_flags, ImGuiTableFlags.Sortable)
	_, S.table_flags = ImGui.CheckboxFlags("_NoBordersInBody", S.table_flags, ImGuiTableFlags.NoBordersInBody)
	_, S.table_flags = ImGui.CheckboxFlags("_HighlightHoveredColumn", S.table_flags, ImGuiTableFlags.HighlightHoveredColumn)
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
	_, S.frozen_cols = ImGui.SliderInt("Frozen columns", S.frozen_cols, 0, 2)
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
	_, S.frozen_rows = ImGui.SliderInt("Frozen rows", S.frozen_rows, 0, 2)
	_, S.column_flags = ImGui.CheckboxFlags("Disable header contributing to column width", S.column_flags, ImGuiTableColumnFlags.NoHeaderWidth)
	if ImGui.TreeNode("Style settings") then
		ImGui.SameLine()
		Demo.HelpMarker("Giving access to some ImGuiStyle value in this demo for convenience.")
		ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
		local style = ImGui.GetStyle()
		_, style.TableAngledHeadersAngle = ImGui.SliderAngle("style.TableAngledHeadersAngle", style.TableAngledHeadersAngle, -50.0, 50.0)
		ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
		local align = style.TableAngledHeadersTextAlign
		local align_arr = { align.x, align.y }
		ImGui.SliderFloat2("style.TableAngledHeadersTextAlign", align_arr, 0.0, 1.0, "%.2f")
		style.TableAngledHeadersTextAlign = ImVec2(align_arr[1], align_arr[2])
		ImGui.TreePop()
	end
	if ImGui.BeginTable("table_angled_headers", columns_count, S.table_flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 12)) then
		ImGui.TableSetupColumn(angled_column_names[1], bit32.bor(ImGuiTableColumnFlags.NoHide, ImGuiTableColumnFlags.NoReorder))
		for n = 1, columns_count - 1 do
			ImGui.TableSetupColumn(angled_column_names[n + 1], S.column_flags)
		end
		ImGui.TableSetupScrollFreeze(S.frozen_cols, S.frozen_rows)
		ImGui.TableAngledHeadersRow()
		ImGui.TableHeadersRow()
		for row = 0, rows_count - 1 do
			ImGui.PushID(row)
			ImGui.TableNextRow()
			ImGui.TableSetColumnIndex(0)
			ImGui.AlignTextToFramePadding()
			ImGui.Text("Track %d", row)
			for column = 1, columns_count - 1 do
				if ImGui.TableSetColumnIndex(column) then
					ImGui.PushID(column)
					_, S.bools[row * columns_count + column + 1] = ImGui.Checkbox("", S.bools[row * columns_count + column + 1])
					ImGui.PopID()
				end
			end
			ImGui.PopID()
		end
		ImGui.EndTable()
	end
end

local S_DemoWindowTables_ContextMenusTable = { flags1 = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Borders, ImGuiTableFlags.ContextMenuInBody) }
function Demo.DemoWindowTables_ContextMenusTable()
	local S = S_DemoWindowTables_ContextMenusTable
	Demo.HelpMarker("By default, right-clicking over a TableHeadersRow()/TableHeader() line will open the default context-menu.\nUsing ImGuiTableFlags_ContextMenuInBody we also allow right-clicking over columns body.")
	Demo.PushStyleCompact()
	_, S.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_ContextMenuInBody", S.flags1, ImGuiTableFlags.ContextMenuInBody)
	Demo.PopStyleCompact()
	local COLUMNS_COUNT = 3
	if ImGui.BeginTable("table_context_menu", COLUMNS_COUNT, S.flags1) then
		ImGui.TableSetupColumn("One")
		ImGui.TableSetupColumn("Two")
		ImGui.TableSetupColumn("Three")
		ImGui.TableHeadersRow()
		for row = 0, 3 do
			ImGui.TableNextRow()
			for column = 0, COLUMNS_COUNT - 1 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Cell %d,%d", column, row)
			end
		end
		ImGui.EndTable()
	end
	Demo.HelpMarker("Demonstrate mixing table context menu (over header), item context button (over button) and custom per-column context menu (over column body).")
	local flags2 = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Borders)
	if ImGui.BeginTable("table_context_menu_2", COLUMNS_COUNT, flags2) then
		ImGui.TableSetupColumn("One")
		ImGui.TableSetupColumn("Two")
		ImGui.TableSetupColumn("Three")
		ImGui.TableHeadersRow()
		for row = 0, 3 do
			ImGui.TableNextRow()
			for column = 0, COLUMNS_COUNT - 1 do
				ImGui.TableSetColumnIndex(column)
				ImGui.Text("Cell %d,%d", column, row)
				ImGui.SameLine()
				ImGui.PushID(row * COLUMNS_COUNT + column)
				ImGui.SmallButton("..")
				if ImGui.BeginPopupContextItem() then
					ImGui.Text("This is the popup for Button(\"..\") in Cell %d,%d", column, row)
					if ImGui.Button("Close") then
						ImGui.CloseCurrentPopup()
					end
					ImGui.EndPopup()
				end
				ImGui.PopID()
			end
		end
		local hovered_column = -1
		for column = 0, COLUMNS_COUNT do
			ImGui.PushID(column)
			if bit32.btest(ImGui.TableGetColumnFlags(column), ImGuiTableColumnFlags.IsHovered) then
				hovered_column = column
			end
			if hovered_column == column and not ImGui.IsAnyItemHovered() and ImGui.IsMouseReleased(1) then
				ImGui.OpenPopup("MyPopup")
			end
			if ImGui.BeginPopup("MyPopup") then
				if column == COLUMNS_COUNT then
					ImGui.Text("This is a custom popup for unused space after the last column.")
				else
					ImGui.Text("This is a custom popup for Column %d", column)
				end
				if ImGui.Button("Close") then
					ImGui.CloseCurrentPopup()
				end
				ImGui.EndPopup()
			end
			ImGui.PopID()
		end
		ImGui.EndTable()
		ImGui.Text("Hovered column: %d", hovered_column)
	end
end

local S_DemoWindowTables_SyncedInstances = { flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Borders, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.NoSavedSettings) }
function Demo.DemoWindowTables_SyncedInstances()
	local S = S_DemoWindowTables_SyncedInstances
	Demo.HelpMarker("Multiple tables with the same identifier will share their settings, width, visibility, order etc.")
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags, ImGuiTableFlags.Resizable)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", S.flags, ImGuiTableFlags.ScrollY)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SizingFixedFit", S.flags, ImGuiTableFlags.SizingFixedFit)
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", S.flags, ImGuiTableFlags.HighlightHoveredColumn)
	for n = 0, 2 do
		local buf = Base.ImFormatString("Synced Table %d", n)
		local open = ImGui.CollapsingHeader(buf, ImGuiTreeNodeFlags.DefaultOpen)
		if open and ImGui.BeginTable("Table", 3, S.flags, ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 5)) then
			ImGui.TableSetupColumn("One")
			ImGui.TableSetupColumn("Two")
			ImGui.TableSetupColumn("Three")
			ImGui.TableHeadersRow()
			local cell_count = n == 1 and 27 or 9
			for cell = 0, cell_count - 1 do
				ImGui.TableNextColumn()
				ImGui.Text("this cell %d", cell)
			end
			ImGui.EndTable()
		end
	end
end

local template_items_names = {
	"Banana", "Apple", "Cherry", "Watermelon", "Grapefruit", "Strawberry", "Mango",
	"Kiwi", "Orange", "Pineapple", "Blueberry", "Plum", "Coconut", "Pear", "Apricot",
}

local S_DemoWindowTables_Sorting = {
	items = Base.ImVector.new(),
	flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable, ImGuiTableFlags.SortMulti, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.ScrollY),
}
function Demo.DemoWindowTables_Sorting(TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_Sorting
	if S.items.Size == 0 then
		for n = 0, 49 do
			local template_n = n % #template_items_names
			S.items:push_back(MyItem.new(n, template_items_names[template_n + 1], (n * n - n) % 20))
		end
	end
	Demo.PushStyleCompact()
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortMulti", S.flags, ImGuiTableFlags.SortMulti)
	ImGui.SameLine()
	Demo.HelpMarker("When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).")
	_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortTristate", S.flags, ImGuiTableFlags.SortTristate)
	ImGui.SameLine()
	Demo.HelpMarker("When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).")
	Demo.PopStyleCompact()
	if ImGui.BeginTable("table_sorting", 4, S.flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 15), 0.0) then
		ImGui.TableSetupColumn("ID", bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed), 0.0, MyItemColumnID.ID)
		ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.WidthFixed, 0.0, MyItemColumnID.Name)
		ImGui.TableSetupColumn("Action", bit32.bor(ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed), 0.0, MyItemColumnID.Action)
		ImGui.TableSetupColumn("Quantity", bit32.bor(ImGuiTableColumnFlags.PreferSortDescending, ImGuiTableColumnFlags.WidthStretch), 0.0, MyItemColumnID.Quantity)
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableHeadersRow()
		local sort_specs = ImGui.TableGetSortSpecs()
		if sort_specs then
			if sort_specs.SpecsDirty then
				MyItem.SortWithSortSpecs(sort_specs, S.items, S.items.Size)
				sort_specs.SpecsDirty = false
			end
		end
		local clipper = Structs.ImGuiListClipper.new()
		clipper:Begin(S.items.Size)
		while clipper:Step() do
			for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
				local item = S.items[row_n + 1]
				ImGui.PushID(item.ID)
				ImGui.TableNextRow()
				ImGui.TableNextColumn()
				ImGui.Text("%04d", item.ID)
				ImGui.TableNextColumn()
				ImGui.TextUnformatted(item.Name)
				ImGui.TableNextColumn()
				ImGui.SmallButton("None")
				ImGui.TableNextColumn()
				ImGui.Text("%d", item.Quantity)
				ImGui.PopID()
			end
		end
		ImGui.EndTable()
	end
end

local AdvContents = { Text = 0, Button = 1, SmallButton = 2, FillButton = 3, Selectable = 4, SelectableSpanRow = 5 }
local S_DemoWindowTables_Advanced = {
	flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable, ImGuiTableFlags.SortMulti, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.SizingFixedFit),
	columns_base_flags = ImGuiTableColumnFlags.None,
	contents_type = AdvContents.SelectableSpanRow,
	contents_type_names = { "Text", "Button", "SmallButton", "FillButton", "Selectable", "Selectable (span row)" },
	freeze_cols = 1,
	freeze_rows = 1,
	items_count = #template_items_names * 2,
	outer_size_value = nil,
	row_min_height = 0.0,
	inner_width_with_scroll = 0.0,
	outer_size_enabled = true,
	show_headers = true,
	show_wrapped_text = false,
	items = Base.ImVector.new(),
	selection = Base.ImVector.new(),
	items_need_sort = false,
	show_debug_details = false,
}

function Demo.DemoWindowTables_AdvancedOptions(TEXT_BASE_WIDTH)
	local S = S_DemoWindowTables_Advanced
	Demo.PushStyleCompact()
	ImGui.PushItemWidth(TEXT_BASE_WIDTH * 28.0)
	if ImGui.TreeNodeEx("Features:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", S.flags, ImGuiTableFlags.Resizable)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Reorderable", S.flags, ImGuiTableFlags.Reorderable)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Hideable", S.flags, ImGuiTableFlags.Hideable)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Sortable", S.flags, ImGuiTableFlags.Sortable)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoSavedSettings", S.flags, ImGuiTableFlags.NoSavedSettings)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ContextMenuInBody", S.flags, ImGuiTableFlags.ContextMenuInBody)
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Decorations:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", S.flags, ImGuiTableFlags.RowBg)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", S.flags, ImGuiTableFlags.BordersV)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", S.flags, ImGuiTableFlags.BordersOuterV)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", S.flags, ImGuiTableFlags.BordersInnerV)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", S.flags, ImGuiTableFlags.BordersH)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterH", S.flags, ImGuiTableFlags.BordersOuterH)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerH", S.flags, ImGuiTableFlags.BordersInnerH)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", S.flags, ImGuiTableFlags.NoBordersInBody)
		ImGui.SameLine()
		Demo.HelpMarker("Disable vertical borders in columns Body (borders will always appear in Headers)")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", S.flags, ImGuiTableFlags.NoBordersInBodyUntilResize)
		ImGui.SameLine()
		Demo.HelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)")
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Sizing:", ImGuiTreeNodeFlags.DefaultOpen) then
		S.flags = Demo.EditTableSizingFlags(S.flags)
		ImGui.SameLine()
		Demo.HelpMarker("In the Advanced demo we override the policy of each column so those table-wide settings have less effect that typical.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", S.flags, ImGuiTableFlags.NoHostExtendX)
		ImGui.SameLine()
		Demo.HelpMarker("Make outer width auto-fit to columns, overriding outer_size.x value.\n\nOnly available when ScrollX/ScrollY are disabled and Stretch columns are not used.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendY", S.flags, ImGuiTableFlags.NoHostExtendY)
		ImGui.SameLine()
		Demo.HelpMarker("Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit).\n\nOnly available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoKeepColumnsVisible", S.flags, ImGuiTableFlags.NoKeepColumnsVisible)
		ImGui.SameLine()
		Demo.HelpMarker("Only available if ScrollX is disabled.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PreciseWidths", S.flags, ImGuiTableFlags.PreciseWidths)
		ImGui.SameLine()
		Demo.HelpMarker("Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoClip", S.flags, ImGuiTableFlags.NoClip)
		ImGui.SameLine()
		Demo.HelpMarker("Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with ScrollFreeze options.")
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Padding:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PadOuterX", S.flags, ImGuiTableFlags.PadOuterX)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadOuterX", S.flags, ImGuiTableFlags.NoPadOuterX)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadInnerX", S.flags, ImGuiTableFlags.NoPadInnerX)
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Scrolling:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", S.flags, ImGuiTableFlags.ScrollX)
		ImGui.SameLine()
		ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
		_, S.freeze_cols = ImGui.DragInt("freeze_cols", S.freeze_cols, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", S.flags, ImGuiTableFlags.ScrollY)
		ImGui.SameLine()
		ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
		_, S.freeze_rows = ImGui.DragInt("freeze_rows", S.freeze_rows, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Sorting:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortMulti", S.flags, ImGuiTableFlags.SortMulti)
		ImGui.SameLine()
		Demo.HelpMarker("When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).")
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortTristate", S.flags, ImGuiTableFlags.SortTristate)
		ImGui.SameLine()
		Demo.HelpMarker("When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).")
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Headers:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.show_headers = ImGui.Checkbox("show_headers", S.show_headers)
		_, S.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", S.flags, ImGuiTableFlags.HighlightHoveredColumn)
		_, S.columns_base_flags = ImGui.CheckboxFlags("ImGuiTableColumnFlags_AngledHeader", S.columns_base_flags, ImGuiTableColumnFlags.AngledHeader)
		ImGui.SameLine()
		Demo.HelpMarker("Enable AngledHeader on all columns. Best enabled on selected narrow columns (see \"Angled headers\" section of the demo).")
		ImGui.TreePop()
	end
	if ImGui.TreeNodeEx("Other:", ImGuiTreeNodeFlags.DefaultOpen) then
		_, S.show_wrapped_text = ImGui.Checkbox("show_wrapped_text", S.show_wrapped_text)
		ImGui.DragFloat2("##OuterSize", S.outer_size_value)
		ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
		_, S.outer_size_enabled = ImGui.Checkbox("outer_size", S.outer_size_enabled)
		ImGui.SameLine()
		Demo.HelpMarker("If scrolling is disabled (ScrollX and ScrollY not set):\n- The table is output directly in the parent window.\n- OuterSize.x < 0.0f will right-align the table.\n- OuterSize.x = 0.0f will narrow fit the table unless there are any Stretch columns.\n- OuterSize.y then becomes the minimum size for the table, which will extend vertically if there are more rows (unless NoHostExtendY is set).")
		_, S.inner_width_with_scroll = ImGui.DragFloat("inner_width (when ScrollX active)", S.inner_width_with_scroll, 1.0, 0.0, FLT_MAX)
		_, S.row_min_height = ImGui.DragFloat("row_min_height", S.row_min_height, 1.0, 0.0, FLT_MAX)
		ImGui.SameLine()
		Demo.HelpMarker("Specify height of the Selectable item.")
		_, S.items_count = ImGui.DragInt("items_count", S.items_count, 0.1, 0, 9999)
		_, S.contents_type = ImGui.Combo("items_type (first column)", S.contents_type, S.contents_type_names)
		ImGui.TreePop()
	end
	ImGui.PopItemWidth()
	Demo.PopStyleCompact()
	ImGui.Spacing()
end

function Demo.DemoWindowTables_AdvancedTable()
	local S = S_DemoWindowTables_Advanced
	if S.items.Size ~= S.items_count then
		S.items:clear()
		for n = 0, S.items_count - 1 do
			local template_n = n % #template_items_names
			S.items:push_back(MyItem.new(n, template_items_names[template_n + 1], template_n == 3 and 10 or (template_n == 4 and 20 or 0)))
		end
	end
	local parent_draw_list = ImGui.GetWindowDrawList()
	local parent_draw_list_draw_cmd_count = parent_draw_list.CmdBuffer.Size
	local table_scroll_cur = ImVec2(0.0, 0.0)
	local table_scroll_max = ImVec2(0.0, 0.0)
	local table_draw_list = nil
	local flags = S.flags
	local inner_width_to_use = bit32.btest(flags, ImGuiTableFlags.ScrollX) and S.inner_width_with_scroll or 0.0
	local outer_size = S.outer_size_enabled and ImVec2(S.outer_size_value[1], S.outer_size_value[2]) or ImVec2(0, 0)
	if ImGui.BeginTable("table_advanced", 6, flags, outer_size, inner_width_to_use) then
		ImGui.TableSetupColumn("ID", bit32.bor(S.columns_base_flags, ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoHide), 0.0, MyItemColumnID.ID)
		ImGui.TableSetupColumn("Name", bit32.bor(S.columns_base_flags, ImGuiTableColumnFlags.WidthFixed), 0.0, MyItemColumnID.Name)
		ImGui.TableSetupColumn("Action", bit32.bor(S.columns_base_flags, ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed), 0.0, MyItemColumnID.Action)
		ImGui.TableSetupColumn("Quantity", bit32.bor(S.columns_base_flags, ImGuiTableColumnFlags.PreferSortDescending), 0.0, MyItemColumnID.Quantity)
		ImGui.TableSetupColumn("Description", bit32.bor(S.columns_base_flags, bit32.btest(flags, ImGuiTableFlags.NoHostExtendX) and 0 or ImGuiTableColumnFlags.WidthStretch), 0.0, MyItemColumnID.Description)
		ImGui.TableSetupColumn("Hidden", bit32.bor(S.columns_base_flags, ImGuiTableColumnFlags.DefaultHide, ImGuiTableColumnFlags.NoSort))
		ImGui.TableSetupScrollFreeze(S.freeze_cols, S.freeze_rows)
		local sort_specs = ImGui.TableGetSortSpecs()
		if sort_specs and sort_specs.SpecsDirty then
			S.items_need_sort = true
		end
		if sort_specs and S.items_need_sort and S.items.Size > 1 then
			MyItem.SortWithSortSpecs(sort_specs, S.items, S.items.Size)
			sort_specs.SpecsDirty = false
		end
		S.items_need_sort = false
		local sorts_specs_using_quantity = bit32.btest(ImGui.TableGetColumnFlags(3), ImGuiTableColumnFlags.IsSorted)
		if S.show_headers and bit32.btest(S.columns_base_flags, ImGuiTableColumnFlags.AngledHeader) then
			ImGui.TableAngledHeadersRow()
		end
		if S.show_headers then
			ImGui.TableHeadersRow()
		end
		local clipper = Structs.ImGuiListClipper.new()
		clipper:Begin(S.items.Size)
		while clipper:Step() do
			for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
				local item = S.items[row_n + 1]
				local item_is_selected = S.selection:contains(item.ID)
				ImGui.PushID(item.ID)
				ImGui.TableNextRow(ImGuiTableRowFlags.None, S.row_min_height)
				ImGui.TableSetColumnIndex(0)
				local label = Base.ImFormatString("%04d", item.ID)
				local ct = S.contents_type
				if ct == AdvContents.Text then
					ImGui.TextUnformatted(label)
				elseif ct == AdvContents.Button then
					ImGui.Button(label)
				elseif ct == AdvContents.SmallButton then
					ImGui.SmallButton(label)
				elseif ct == AdvContents.FillButton then
					ImGui.Button(label, ImVec2(-FLT_MIN, 0.0))
				elseif ct == AdvContents.Selectable or ct == AdvContents.SelectableSpanRow then
					local selectable_flags = ImGuiSelectableFlags.None
					if ct == AdvContents.SelectableSpanRow then
						selectable_flags = bit32.bor(ImGuiSelectableFlags.SpanAllColumns, ImGuiSelectableFlags.AllowOverlap)
					end
					if ImGui.Selectable(label, item_is_selected, selectable_flags, ImVec2(0, S.row_min_height)) then
						if ImGui.GetIO().KeyCtrl then
							if item_is_selected then
								S.selection:find_erase_unsorted(item.ID)
							else
								S.selection:push_back(item.ID)
							end
						else
							S.selection:clear()
							S.selection:push_back(item.ID)
						end
					end
				end
				if ImGui.TableSetColumnIndex(1) then
					ImGui.TextUnformatted(item.Name)
				end
				if ImGui.TableSetColumnIndex(2) then
					if ImGui.SmallButton("Chop") then
						item.Quantity = item.Quantity + 1
					end
					if sorts_specs_using_quantity and ImGui.IsItemDeactivated() then
						S.items_need_sort = true
					end
					ImGui.SameLine()
					if ImGui.SmallButton("Eat") then
						item.Quantity = item.Quantity - 1
					end
					if sorts_specs_using_quantity and ImGui.IsItemDeactivated() then
						S.items_need_sort = true
					end
				end
				if ImGui.TableSetColumnIndex(3) then
					ImGui.Text("%d", item.Quantity)
				end
				ImGui.TableSetColumnIndex(4)
				if S.show_wrapped_text then
					ImGui.TextWrapped("Lorem ipsum dolor sit amet")
				else
					ImGui.Text("Lorem ipsum dolor sit amet")
				end
				if ImGui.TableSetColumnIndex(5) then
					ImGui.Text("1234")
				end
				ImGui.PopID()
			end
		end
		table_scroll_cur = ImVec2(ImGui.GetScrollX(), ImGui.GetScrollY())
		table_scroll_max = ImVec2(ImGui.GetScrollMaxX(), ImGui.GetScrollMaxY())
		table_draw_list = ImGui.GetWindowDrawList()
		ImGui.EndTable()
	end
	_, S.show_debug_details = ImGui.Checkbox("Debug details", S.show_debug_details)
	if S.show_debug_details and table_draw_list then
		ImGui.SameLine(0.0, 0.0)
		local table_draw_list_draw_cmd_count = table_draw_list.CmdBuffer.Size
		if table_draw_list == parent_draw_list then
			ImGui.Text(": DrawCmd: +%d (in same window)", table_draw_list_draw_cmd_count - parent_draw_list_draw_cmd_count)
		else
			ImGui.Text(": DrawCmd: +%d (in child window), Scroll: (%.f/%.f) (%.f/%.f)", table_draw_list_draw_cmd_count - 1, table_scroll_cur.x, table_scroll_max.x, table_scroll_cur.y, table_scroll_max.y)
		end
	end
end

function Demo.DemoWindowTables_Advanced(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
	local S = S_DemoWindowTables_Advanced
	if S.outer_size_value == nil then
		S.outer_size_value = { 0.0, TEXT_BASE_HEIGHT * 12 }
	end
	if ImGui.TreeNode("Options") then
		Demo.DemoWindowTables_AdvancedOptions(TEXT_BASE_WIDTH)
		ImGui.TreePop()
	end
	Demo.DemoWindowTables_AdvancedTable()
end

local S_DemoWindowColumns_Basic = { selected = -1 }
function Demo.DemoWindowColumns_Basic()
	local S = S_DemoWindowColumns_Basic
	ImGui.Text("Without border:")
	ImGui.Columns(3, "mycolumns3", false)
	ImGui.Separator()
	for n = 0, 13 do
		local label = Base.ImFormatString("Item %d", n)
		ImGui.Selectable(label)
		ImGui.NextColumn()
	end
	ImGui.Columns(1)
	ImGui.Separator()
	ImGui.Text("With border:")
	ImGui.Columns(4, "mycolumns")
	ImGui.Separator()
	ImGui.Text("ID")
	ImGui.NextColumn()
	ImGui.Text("Name")
	ImGui.NextColumn()
	ImGui.Text("Path")
	ImGui.NextColumn()
	ImGui.Text("Hovered")
	ImGui.NextColumn()
	ImGui.Separator()
	local names = { "One", "Two", "Three" }
	local paths = { "/path/one", "/path/two", "/path/three" }
	for i = 0, 2 do
		local label = Base.ImFormatString("%04d", i)
		if ImGui.Selectable(label, S.selected == i, ImGuiSelectableFlags.SpanAllColumns) then
			S.selected = i
		end
		local hovered = ImGui.IsItemHovered()
		ImGui.NextColumn()
		ImGui.Text(names[i + 1])
		ImGui.NextColumn()
		ImGui.Text(paths[i + 1])
		ImGui.NextColumn()
		ImGui.Text("%d", hovered and 1 or 0)
		ImGui.NextColumn()
	end
	ImGui.Columns(1)
	ImGui.Separator()
end

local S_DemoWindowColumns_Borders = { h_borders = true, v_borders = true, columns_count = 4 }
function Demo.DemoWindowColumns_Borders()
	local S = S_DemoWindowColumns_Borders
	local lines_count = 3
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
	_, S.columns_count = ImGui.DragInt("##columns_count", S.columns_count, 0.1, 2, 10, "%d columns")
	if S.columns_count < 2 then
		S.columns_count = 2
	end
	ImGui.SameLine()
	_, S.h_borders = ImGui.Checkbox("horizontal", S.h_borders)
	ImGui.SameLine()
	_, S.v_borders = ImGui.Checkbox("vertical", S.v_borders)
	ImGui.Columns(S.columns_count, nil, S.v_borders)
	for i = 0, S.columns_count * lines_count - 1 do
		if S.h_borders and ImGui.GetColumnIndex() == 0 then
			ImGui.Separator()
		end
		ImGui.PushID(i)
		ImGui.Text("%c%c%c", string.byte("a") + i, string.byte("a") + i, string.byte("a") + i)
		ImGui.Text("Width %.2f", ImGui.GetColumnWidth())
		ImGui.Text("Avail %.2f", ImGui.GetContentRegionAvail().x)
		ImGui.Text("Offset %.2f", ImGui.GetColumnOffset())
		ImGui.Text("Long text that is likely to clip")
		ImGui.Button("Button", ImVec2(-FLT_MIN, 0.0))
		ImGui.PopID()
		ImGui.NextColumn()
	end
	ImGui.Columns(1)
	if S.h_borders then
		ImGui.Separator()
	end
end

local S_DemoWindowColumns_MixedItems = { foo = 1.0, bar = 1.0 }
function Demo.DemoWindowColumns_MixedItems()
	local S = S_DemoWindowColumns_MixedItems
	ImGui.Columns(3, "mixed")
	ImGui.Separator()
	ImGui.Text("Hello")
	ImGui.Button("Banana")
	ImGui.NextColumn()
	ImGui.Text("ImGui")
	ImGui.Button("Apple")
	_, S.foo = ImGui.InputFloat("red", S.foo, 0.05, 0, "%.3f")
	ImGui.Text("An extra line here.")
	ImGui.NextColumn()
	ImGui.Text("Sailor")
	ImGui.Button("Corniflower")
	_, S.bar = ImGui.InputFloat("blue", S.bar, 0.05, 0, "%.3f")
	ImGui.NextColumn()
	if ImGui.CollapsingHeader("Category A") then
		ImGui.Text("Blah blah blah")
	end
	ImGui.NextColumn()
	if ImGui.CollapsingHeader("Category B") then
		ImGui.Text("Blah blah blah")
	end
	ImGui.NextColumn()
	if ImGui.CollapsingHeader("Category C") then
		ImGui.Text("Blah blah blah")
	end
	ImGui.NextColumn()
	ImGui.Columns(1)
	ImGui.Separator()
end

function Demo.DemoWindowColumns_WordWrapping()
	ImGui.Columns(2, "word-wrapping")
	ImGui.Separator()
	ImGui.TextWrapped("The quick brown fox jumps over the lazy dog.")
	ImGui.TextWrapped("Hello Left")
	ImGui.NextColumn()
	ImGui.TextWrapped("The quick brown fox jumps over the lazy dog.")
	ImGui.TextWrapped("Hello Right")
	ImGui.Columns(1)
	ImGui.Separator()
end

function Demo.DemoWindowColumns_HorizontalScrolling()
	ImGui.SetNextWindowContentSize(ImVec2(1500.0, 0.0))
	local child_size = ImVec2(0, ImGui.GetFontSize() * 20.0)
	ImGui.BeginChild("##ScrollingRegion", child_size, ImGuiChildFlags.None, ImGuiWindowFlags.HorizontalScrollbar)
	ImGui.Columns(10)
	local ITEMS_COUNT = 2000
	local clipper = Structs.ImGuiListClipper.new()
	clipper:Begin(ITEMS_COUNT)
	while clipper:Step() do
		for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
			for j = 0, 9 do
				ImGui.Text("Line %d Column %d...", i, j)
				ImGui.NextColumn()
			end
		end
	end
	ImGui.Columns(1)
	ImGui.EndChild()
end

function Demo.DemoWindowColumns_Tree()
	ImGui.Columns(2, "tree", true)
	for x = 0, 2 do
		local open1 = ImGui.TreeNode(x, "Node%d", x)
		ImGui.NextColumn()
		ImGui.Text("Node contents")
		ImGui.NextColumn()
		if open1 then
			for y = 0, 2 do
				local open2 = ImGui.TreeNode(y, "Node%d.%d", x, y)
				ImGui.NextColumn()
				ImGui.Text("Node contents")
				if open2 then
					ImGui.Text("Even more contents")
					if ImGui.TreeNode("Tree in column") then
						ImGui.Text("The quick brown fox jumps over the lazy dog")
						ImGui.TreePop()
					end
				end
				ImGui.NextColumn()
				if open2 then
					ImGui.TreePop()
				end
			end
			ImGui.TreePop()
		end
	end
	ImGui.Columns(1)
end

function Demo.DemoWindowColumns()
	local open = ImGui.TreeNode("Legacy Columns API")
	ImGui.SameLine()
	Demo.HelpMarker("Columns() is an old API! Prefer using the more flexible and powerful BeginTable() API!")
	if not open then
		return
	end
	if ImGui.TreeNode("Basic") then
		Demo.DemoWindowColumns_Basic()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Borders") then
		Demo.DemoWindowColumns_Borders()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Mixed items") then
		Demo.DemoWindowColumns_MixedItems()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Word-wrapping") then
		Demo.DemoWindowColumns_WordWrapping()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Horizontal Scrolling") then
		Demo.DemoWindowColumns_HorizontalScrolling()
		ImGui.TreePop()
	end
	if ImGui.TreeNode("Tree") then
		Demo.DemoWindowColumns_Tree()
		ImGui.TreePop()
	end
	ImGui.TreePop()
end

local S_DemoWindowTables = { disable_indent = false }
function Demo.DemoWindowTables()
	if not ImGui.CollapsingHeader("Tables & Columns") then
		return
	end
	local TEXT_BASE_WIDTH = ImGui.CalcTextSize("A").x
	local TEXT_BASE_HEIGHT = ImGui.GetTextLineHeightWithSpacing()
	local S = S_DemoWindowTables
	ImGui.PushID("Tables")
	local open_action = -1
	if ImGui.Button("Expand all") then
		open_action = 1
	end
	ImGui.SameLine()
	if ImGui.Button("Collapse all") then
		open_action = 0
	end
	ImGui.SameLine()
	_, S.disable_indent = ImGui.Checkbox("Disable tree indentation", S.disable_indent)
	ImGui.SameLine()
	Demo.HelpMarker("Disable the indenting of tree nodes so demo tables can use the full window width.")
	ImGui.Separator()
	if S.disable_indent then
		ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0.0)
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Basic") then
		Demo.DemoWindowTables_Basic()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Borders, background") then
		Demo.DemoWindowTables_Borders()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Resizable, stretch") then
		Demo.DemoWindowTables_ResizableStretch()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Resizable, fixed") then
		Demo.DemoWindowTables_ResizableFixed()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Resizable, mixed") then
		Demo.DemoWindowTables_ResizableMixed()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Reorderable, hideable, with headers") then
		Demo.DemoWindowTables_ReorderableHideable()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Padding") then
		Demo.DemoWindowTables_Padding()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Sizing policies") then
		Demo.DemoWindowTables_SizingPolicies(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Vertical scrolling, with clipping") then
		Demo.DemoWindowTables_VerticalScrolling(TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Horizontal scrolling") then
		Demo.DemoWindowTables_HorizontalScrolling(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Columns flags") then
		Demo.DemoWindowTables_ColumnsFlags(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Columns widths") then
		Demo.DemoWindowTables_ColumnsWidths(TEXT_BASE_WIDTH)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Nested tables") then
		Demo.DemoWindowTables_NestedTables(TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Row height") then
		Demo.DemoWindowTables_RowHeight(TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Outer size") then
		Demo.DemoWindowTables_OuterSize(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Background color") then
		Demo.DemoWindowTables_BackgroundColor()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Tree view") then
		Demo.DemoWindowTables_TreeView(TEXT_BASE_WIDTH)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Item width") then
		Demo.DemoWindowTables_ItemWidth(TEXT_BASE_WIDTH)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Custom headers") then
		Demo.DemoWindowTables_CustomHeaders()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Angled headers") then
		Demo.DemoWindowTables_AngledHeaders(TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Context menus") then
		Demo.DemoWindowTables_ContextMenusTable()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Synced instances") then
		Demo.DemoWindowTables_SyncedInstances()
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Sorting") then
		Demo.DemoWindowTables_Sorting(TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	if open_action ~= -1 then
		ImGui.SetNextItemOpen(open_action ~= 0)
	end
	if ImGui.TreeNode("Advanced") then
		Demo.DemoWindowTables_Advanced(TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT)
		ImGui.TreePop()
	end
	ImGui.PopID()
	Demo.DemoWindowColumns()
	if S.disable_indent then
		ImGui.PopStyleVar()
	end
end

return true
