local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local Demo = ImGui._Demo

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local ImVector = Base.ImVector
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local FLT_MIN, FLT_MAX = Base.FLT_MIN, Base.FLT_MAX
local ImGuiListClipper = Structs.ImGuiListClipper
local ImColor = Structs.ImColor
local ImGuiSelectionBasicStorage = Structs.ImGuiSelectionBasicStorage
local ImGuiSelectionExternalStorage = Structs.ImGuiSelectionExternalStorage
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiSliderFlags = Enums.ImGuiSliderFlags
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiFocusedFlags = Enums.ImGuiFocusedFlags
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTableColumnFlags = Enums.ImGuiTableColumnFlags
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiKey = Enums.ImGuiKey
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiMultiSelectFlags = Enums.ImGuiMultiSelectFlags
local ImGuiSelectionRequestType = Enums.ImGuiSelectionRequestType

local function b2i(v)
	if v then
		return 1
	end
	return 0
end

Demo.ExampleNames = {
	"Artichoke", "Arugula", "Asparagus", "Avocado", "Bamboo Shoots", "Bean Sprouts", "Beans", "Beet", "Belgian Endive", "Bell Pepper",
	"Bitter Gourd", "Bok Choy", "Broccoli", "Brussels Sprouts", "Burdock Root", "Cabbage", "Calabash", "Capers", "Carrot", "Cassava",
	"Cauliflower", "Celery", "Celery Root", "Celcuce", "Chayote", "Chinese Broccoli", "Corn", "Cucumber",
}

local ExampleSelectionWithDeletion = {}
ExampleSelectionWithDeletion.__index = ExampleSelectionWithDeletion
setmetatable(ExampleSelectionWithDeletion, { __index = ImGuiSelectionBasicStorage })
Demo.ExampleSelectionWithDeletion = ExampleSelectionWithDeletion

function ExampleSelectionWithDeletion.new()
	return setmetatable(ImGuiSelectionBasicStorage.new(), ExampleSelectionWithDeletion)
end

function ExampleSelectionWithDeletion:ApplyDeletionPreLoop(ms_io, items_count)
	if self.Size == 0 then
		return -1
	end

	local focused_idx = ms_io.NavIdItem
	if ms_io.NavIdSelected == false then
		ms_io.RangeSrcReset = true
		return focused_idx
	end

	for idx = focused_idx + 1, items_count - 1 do
		if not self:Contains(self:GetStorageIdFromIndex(idx)) then
			return idx
		end
	end

	for idx = ImMin(focused_idx, items_count) - 1, 0, -1 do
		if not self:Contains(self:GetStorageIdFromIndex(idx)) then
			return idx
		end
	end

	return -1
end

function ExampleSelectionWithDeletion:ApplyDeletionPostLoop(ms_io, items, item_curr_idx_to_select)
	local new_items = ImVector.new()
	new_items:reserve(items.Size - self.Size)
	local item_next_idx_to_select = -1
	for idx = 0, items.Size - 1 do
		if not self:Contains(self:GetStorageIdFromIndex(idx)) then
			new_items:push_back(items[idx + 1])
		end
		if item_curr_idx_to_select == idx then
			item_next_idx_to_select = new_items.Size - 1
		end
	end
	items:swap(new_items)

	self:Clear()
	if item_next_idx_to_select ~= -1 and ms_io.NavIdSelected then
		self:SetItemSelected(self:GetStorageIdFromIndex(item_next_idx_to_select), true)
	end
end

local ExampleDualListBox = {}
ExampleDualListBox.__index = ExampleDualListBox
Demo.ExampleDualListBox = ExampleDualListBox

function ExampleDualListBox.new()
	return setmetatable({
		Items = { ImVector.new(), ImVector.new() },
		Selections = { ImGuiSelectionBasicStorage.new(), ImGuiSelectionBasicStorage.new() },
		OptKeepSorted = true,
	}, ExampleDualListBox)
end

function ExampleDualListBox:MoveAll(src, dst)
	assert((src == 0 and dst == 1) or (src == 1 and dst == 0))
	local src_items = self.Items[src + 1]
	local dst_items = self.Items[dst + 1]
	for i = 1, src_items.Size do
		dst_items:push_back(src_items[i])
	end
	src_items:clear()
	self:SortItems(dst)
	self.Selections[src + 1]:Swap(self.Selections[dst + 1])
	self.Selections[src + 1]:Clear()
end

function ExampleDualListBox:MoveSelected(src, dst)
	local src_items = self.Items[src + 1]
	local dst_items = self.Items[dst + 1]
	local src_selection = self.Selections[src + 1]
	local src_n = 0
	while src_n < src_items.Size do
		local item_id = src_items[src_n + 1]
		if src_selection:Contains(item_id) then
			src_items:erase(src_n)
			dst_items:push_back(item_id)
		else
			src_n = src_n + 1
		end
	end
	if self.OptKeepSorted then
		self:SortItems(dst)
	end
	src_selection:Swap(self.Selections[dst + 1])
	src_selection:Clear()
end

function ExampleDualListBox:ApplySelectionRequests(ms_io, side)
	local selection = self.Selections[side + 1]
	selection.UserData = self.Items[side + 1]
	selection.AdapterIndexToStorageId = function(self_, idx)
		return self_.UserData[idx + 1]
	end
	selection:ApplyRequests(ms_io)
end

function ExampleDualListBox.CompareItemsByValue(lhs, rhs)
	return lhs - rhs
end

function ExampleDualListBox:SortItems(n)
	local items = self.Items[n + 1]
	Base.ImQsort(items, items.Size, ExampleDualListBox.CompareItemsByValue)
end

function ExampleDualListBox:Show()
	if ImGui.BeginTable("split", 3, ImGuiTableFlags.None) then
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed)
		ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableNextRow()

		local request_move_selected = -1
		local request_move_all = -1
		local child_height_0 = 0.0
		for side = 0, 1 do
			local items = self.Items[side + 1]
			local selection = self.Selections[side + 1]

			ImGui.TableSetColumnIndex(if side == 0 then 0 else 2)
			ImGui.Text("%s (%d)", if side == 0 then "Available" else "Basket", items.Size)

			local items_height = ImGui.GetTextLineHeightWithSpacing()
			ImGui.SetNextWindowContentSize(ImVec2(0.0, items.Size * items_height))

			local child_visible
			if side == 0 then
				ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetFrameHeightWithSpacing() * 4), ImVec2(FLT_MAX, FLT_MAX))
				child_visible = ImGui.BeginChild("0", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY))
				child_height_0 = ImGui.GetWindowSize().y
			else
				child_visible = ImGui.BeginChild("1", ImVec2(-FLT_MIN, child_height_0), ImGuiChildFlags.FrameStyle)
			end
			if child_visible then
				local flags = ImGuiMultiSelectFlags.BoxSelect1d
				local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, items.Size)
				self:ApplySelectionRequests(ms_io, side)

				for item_n = 0, items.Size - 1 do
					local item_id = items[item_n + 1]
					local item_is_selected = selection:Contains(item_id)
					ImGui.SetNextItemSelectionUserData(item_n)
					ImGui.Selectable(Demo.ExampleNames[item_id + 1], item_is_selected, ImGuiSelectableFlags.AllowDoubleClick)
					if ImGui.IsItemFocused() then
						if ImGui.IsKeyPressed(ImGuiKey.Enter) or ImGui.IsKeyPressed(ImGuiKey.KeypadEnter) then
							request_move_selected = side
						end
						if ImGui.IsMouseDoubleClicked(0) then
							request_move_selected = side
						end
					end
				end

				ms_io = ImGui.EndMultiSelect()
				self:ApplySelectionRequests(ms_io, side)
			end
			ImGui.EndChild()
		end

		ImGui.TableSetColumnIndex(1)
		ImGui.NewLine()
		local button_sz = ImVec2(ImGui.GetFrameHeight(), ImGui.GetFrameHeight())

		if ImGui.Button(">>", button_sz) then
			request_move_all = 0
		end
		if ImGui.Button(">", button_sz) then
			request_move_selected = 0
		end
		if ImGui.Button("<", button_sz) then
			request_move_selected = 1
		end
		if ImGui.Button("<<", button_sz) then
			request_move_all = 1
		end

		if request_move_all ~= -1 then
			self:MoveAll(request_move_all, bit32.bxor(request_move_all, 1))
		end
		if request_move_selected ~= -1 then
			self:MoveSelected(request_move_selected, bit32.bxor(request_move_selected, 1))
		end

		ImGui.EndTable()
	end
end

function Demo.DemoWindowWidgetsFonts()
	if ImGui.TreeNode("Fonts") then
		local atlas = ImGui.GetIO().Fonts
		ImGui.ShowFontAtlas(atlas)
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsImages = { pressed_count = 0, image_viewer = nil }
function Demo.DemoWindowWidgetsImages()
	local S = S_DemoWindowWidgetsImages
	if ImGui.TreeNode("Images") then
		local io = ImGui.GetIO()
		ImGui.TextWrapped(
			"Below we are displaying the font texture (which is the only texture we have access to in this demo). " ..
			"Use the 'ImTextureID' type as storage to pass pointers or identifier to your own texture data. " ..
			"Hover the texture for a zoomed view!"
		)

		local atlas = io.Fonts
		local my_tex_id = Demo.DemoTexture
		local my_tex_w = atlas.TexData.Width
		local my_tex_h = atlas.TexData.Height
		ImGui.Text("%.0fx%.0f", my_tex_w, my_tex_h)

		ImGui.SeparatorText("Image()/ImageWithBg() function")
		local uv_min = ImVec2(0.0, 0.0)
		local uv_max = ImVec2(1.0, 1.0)
		ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, ImMax(1.0, ImGui.GetStyle().ImageBorderSize))
		if my_tex_id ~= nil then
			ImGui.ImageWithBg(my_tex_id, ImVec2(my_tex_w, my_tex_h), uv_min, uv_max, ImVec4(0.0, 0.0, 0.0, 1.0))
		end
		ImGui.PopStyleVar()

		ImGui.SeparatorText("Interactive Image Viewer")
		if S.image_viewer == nil then
			S.image_viewer = Demo.ExampleImageViewerData.new()
		end
		local canvas_size = ImVec2(ImGui.GetContentRegionAvail().x, my_tex_h * 2.0)
		Demo.ExampleImageViewer_DrawOptions(S.image_viewer)
		if my_tex_id ~= nil then
			Demo.ExampleImageViewer_DrawCanvas(S.image_viewer, canvas_size, my_tex_id, my_tex_w, my_tex_h)
		end

		ImGui.SeparatorText("Textured Buttons")
		ImGui.TextWrapped("And now some textured buttons..")
		for i = 0, 7 do
			ImGui.PushID(i)
			if i > 0 then
				ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(i - 1.0, i - 1.0))
			end
			local size = ImVec2(32.0, 32.0)
			local uv0 = ImVec2(0.0, 0.0)
			local uv1 = ImVec2(32.0 / my_tex_w, 32.0 / my_tex_h)
			local bg_col = ImVec4(0.0, 0.0, 0.0, 1.0)
			local tint_col = ImVec4(1.0, 1.0, 1.0, 1.0)
			if my_tex_id ~= nil and ImGui.ImageButton("", my_tex_id, size, uv0, uv1, bg_col, tint_col) then
				S.pressed_count = S.pressed_count + 1
			end
			if i > 0 then
				ImGui.PopStyleVar()
			end
			ImGui.PopID()
			ImGui.SameLine()
		end
		ImGui.NewLine()
		ImGui.Text("Pressed %d times.", S.pressed_count)
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsListBoxes = { item_selected_idx = 0, item_highlight = false }
function Demo.DemoWindowWidgetsListBoxes()
	local S = S_DemoWindowWidgetsListBoxes
	local _
	if ImGui.TreeNode("List Boxes") then
		local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
		local item_highlighted_idx = -1
		_, S.item_highlight = ImGui.Checkbox("Highlight hovered item in second listbox", S.item_highlight)

		if ImGui.BeginListBox("listbox 1") then
			for n = 0, #items - 1 do
				local is_selected = (S.item_selected_idx == n)
				if ImGui.Selectable(items[n + 1], is_selected) then
					S.item_selected_idx = n
				end

				if S.item_highlight and ImGui.IsItemHovered() then
					item_highlighted_idx = n
				end

				if is_selected then
					ImGui.SetItemDefaultFocus()
				end
			end
			ImGui.EndListBox()
		end
		ImGui.SameLine()
		Demo.HelpMarker("Here we are sharing selection state between both boxes.")

		ImGui.Text("Full-width:")
		if ImGui.BeginListBox("##listbox 2", ImVec2(-FLT_MIN, 5 * ImGui.GetTextLineHeightWithSpacing())) then
			for n = 0, #items - 1 do
				local is_selected = (S.item_selected_idx == n)
				local flags = if item_highlighted_idx == n then ImGuiSelectableFlags.Highlight else 0
				if ImGui.Selectable(items[n + 1], is_selected, flags) then
					S.item_selected_idx = n
				end

				if is_selected then
					ImGui.SetItemDefaultFocus()
				end
			end
			ImGui.EndListBox()
		end

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsLiveEdit = { str = "", i = 0, f = 0.0 }
function Demo.DemoWindowWidgetsLiveEdit(demo_data)
	local S = S_DemoWindowWidgetsLiveEdit
	local _
	if ImGui.TreeNode("Live Edit Flags") then
		ImGui.TextWrapped("Select whether to apply keyboard edits to backing variables _while_ typing.")

		_, demo_data.LiveEditOverride = ImGui.Checkbox("Override Live Edit Flags in Demo Window", demo_data.LiveEditOverride)
		if not demo_data.LiveEditOverride then
			demo_data.LiveEditFlags = ImGui.GetItemFlags()
		end

		ImGui.BeginDisabled(demo_data.LiveEditOverride == false)
		ImGui.Indent()
		_, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputText", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText)
		_, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputScalar", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar)
		ImGui.Unindent()
		ImGui.EndDisabled()

		ImGui.Text("Try typing '123' and seeing effect on backing value:")
		_, S.str = ImGui.InputText("str", S.str)
		ImGui.Text("Backing value: \"%s\"", S.str)
		_, S.i = ImGui.InputInt("int", S.i, 0, 0)
		ImGui.Text("Backing value: %d", S.i)
		_, S.f = ImGui.SliderFloat("float", S.f, 0.0, 100.0)
		ImGui.Text("Backing value: %f", S.f)

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsMixedValues = { use_liveedit = false, items = { 12.0, 0.0, 0.0 } }
function Demo.DemoWindowWidgetsMixedValues()
	local S = S_DemoWindowWidgetsMixedValues
	local _
	if ImGui.TreeNode("Mixed Values") then
		Demo.HelpMarker("Using ImGuiItemFlags_MixedValue.")

		_, S.use_liveedit = ImGui.Checkbox("ImGuiItemFlags_LiveEditOnInput", S.use_liveedit)

		ImGui.SeparatorText("Scalar/Text Widgets")
		local is_mixed = S.items[1] ~= S.items[2] or S.items[1] ~= S.items[3]

		ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, S.use_liveedit)
		ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, is_mixed)
		local edited = false
		local changed
		changed, S.items[1] = ImGui.DragFloat("DragFloat", S.items[1])
		edited = edited or changed
		changed, S.items[1] = ImGui.SliderFloat("SliderFloat", S.items[1], 0.0, 100.0)
		edited = edited or changed
		changed, S.items[1] = ImGui.InputFloat("InputFloat", S.items[1], 1.0)
		edited = edited or changed
		if edited then
			for i = 2, 3 do
				S.items[i] = S.items[1]
			end
		end
		ImGui.PopItemFlag()

		ImGui.Text("Underlying data:")
		_, S.items[1] = ImGui.InputFloat("item 0 (ref)", S.items[1])
		_, S.items[2] = ImGui.InputFloat("item 1", S.items[2])
		_, S.items[3] = ImGui.InputFloat("item 2", S.items[3])
		ImGui.PopItemFlag()

		ImGui.SeparatorText("Others Widgets")
		ImGui.Text("(note: edits are not applied in this demo)")
		local b_on = true
		local b_off = false
		_, b_on = ImGui.Checkbox("Checkbox On", b_on)
		_, b_off = ImGui.Checkbox("Checkbox Off", b_off)
		ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true)
		_, b_off = ImGui.Checkbox("Checkbox Mixed", b_off)
		ImGui.RadioButton("RadioButton Mixed", true)
		ImGui.SameLine()
		ImGui.RadioButton("RadioButton Mixed##2", true)
		local combo_idx = 0
		_, combo_idx = ImGui.Combo("Combo", combo_idx, "One\0Two\0Three\0")
		local color = { 0.5, 0.5, 0.5, 0.5 }
		ImGui.ColorEdit4("ColorEdit4", color)
		ImGui.PopItemFlag()

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsMultiComponents = {
	vec4f = { 0.10, 0.20, 0.30, 0.44 },
	vec4i = { 1, 5, 100, 255 },
	flags = 0,
	range_begin = 10.0,
	range_end = 90.0,
	begin_i = 100,
	end_i = 1000,
}
function Demo.DemoWindowWidgetsMultiComponents()
	local S = S_DemoWindowWidgetsMultiComponents
	local _
	if ImGui.TreeNode("Multi-component Widgets") then
		_, S.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ColorMarkers", S.flags, ImGuiSliderFlags.ColorMarkers)

		ImGui.SeparatorText("2-wide")
		ImGui.InputFloat2("input float2", S.vec4f)
		ImGui.InputInt2("input int2", S.vec4i)
		ImGui.DragFloat2("drag float2", S.vec4f, 0.01, 0.0, 1.0, nil, S.flags)
		ImGui.DragInt2("drag int2", S.vec4i, 1, 0, 255, nil, S.flags)
		ImGui.SliderFloat2("slider float2", S.vec4f, 0.0, 1.0, nil, S.flags)
		ImGui.SliderInt2("slider int2", S.vec4i, 0, 255, nil, S.flags)

		ImGui.SeparatorText("3-wide")
		ImGui.InputFloat3("input float3", S.vec4f)
		ImGui.InputInt3("input int3", S.vec4i)
		ImGui.DragFloat3("drag float3", S.vec4f, 0.01, 0.0, 1.0, nil, S.flags)
		ImGui.DragInt3("drag int3", S.vec4i, 1, 0, 255, nil, S.flags)
		ImGui.SliderFloat3("slider float3", S.vec4f, 0.0, 1.0, nil, S.flags)
		ImGui.SliderInt3("slider int3", S.vec4i, 0, 255, nil, S.flags)

		ImGui.SeparatorText("4-wide")
		ImGui.InputFloat4("input float4", S.vec4f)
		ImGui.InputInt4("input int4", S.vec4i)
		ImGui.DragFloat4("drag float4", S.vec4f, 0.01, 0.0, 1.0, nil, S.flags)
		ImGui.DragInt4("drag int4", S.vec4i, 1, 0, 255, nil, S.flags)
		ImGui.SliderFloat4("slider float4", S.vec4f, 0.0, 1.0, nil, S.flags)
		ImGui.SliderInt4("slider int4", S.vec4i, 0, 255, nil, S.flags)

		ImGui.SeparatorText("Ranges")
		_, S.range_begin, S.range_end = ImGui.DragFloatRange2("range float", S.range_begin, S.range_end, 0.25, 0.0, 100.0, "Min: %.1f %%", "Max: %.1f %%", ImGuiSliderFlags.AlwaysClamp)
		_, S.begin_i, S.end_i = ImGui.DragIntRange2("range int", S.begin_i, S.end_i, 5, 0, 1000, "Min: %d units", "Max: %d units")
		_, S.begin_i, S.end_i = ImGui.DragIntRange2("range int (no bounds)", S.begin_i, S.end_i, 5, 0, 0, "Min: %d units", "Max: %d units")

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsPlotting = {
	animate = true,
	arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 },
	values = table.create(90, 0.0),
	values_offset = 0,
	refresh_time = 0.0,
	phase = 0.0,
	func_type = 0,
	display_count = 70,
}
function Demo.DemoWindowWidgetsPlotting()
	local S = S_DemoWindowWidgetsPlotting
	local _
	if ImGui.TreeNode("Plotting") then
		ImGui.Text("Need better plotting and graphing? Consider using ImPlot:")
		ImGui.TextLinkOpenURL("https://github.com/epezent/implot")
		ImGui.Separator()

		_, S.animate = ImGui.Checkbox("Animate", S.animate)

		local plot_sz = ImVec2(0.0, ImGui.GetFrameHeight() * 4.0)

		ImGui.PlotLines("Frame Times", S.arr, #S.arr)
		ImGui.PlotHistogram("Histogram", S.arr, #S.arr, 0, nil, 0.0, 1.0, plot_sz)

		if not S.animate or S.refresh_time == 0.0 then
			S.refresh_time = ImGui.GetTime()
		end
		while S.refresh_time < ImGui.GetTime() do
			S.values[S.values_offset + 1] = math.cos(S.phase)
			S.values_offset = (S.values_offset + 1) % #S.values
			S.phase = S.phase + 0.10 * S.values_offset
			S.refresh_time = S.refresh_time + 1.0 / 60.0
		end

		do
			local average = 0.0
			for n = 1, #S.values do
				average = average + S.values[n]
			end
			average = average / #S.values
			local overlay = Base.ImFormatString("avg %f", average)
			ImGui.PlotLines("Lines", S.values, #S.values, S.values_offset, overlay, -1.0, 1.0, plot_sz)
		end

		local function Sin(_, i)
			return math.sin(i * 0.1)
		end
		local function Saw(_, i)
			if bit32.btest(i, 1) then
				return 1.0
			end
			return -1.0
		end

		ImGui.SeparatorText("Functions")
		ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
		_, S.func_type = ImGui.Combo("func", S.func_type, "Sin\0Saw\0")
		ImGui.SameLine()
		_, S.display_count = ImGui.SliderInt("Sample count", S.display_count, 1, 400)
		local func = if S.func_type == 0 then Sin else Saw
		ImGui.PlotLines("Lines##2", func, nil, S.display_count, 0, nil, -1.0, 1.0, plot_sz)
		ImGui.PlotHistogram("Histogram##2", func, nil, S.display_count, 0, nil, -1.0, 1.0, plot_sz)

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsProgressBars = { progress_accum = 0.0, progress_dir = 1.0 }
function Demo.DemoWindowWidgetsProgressBars()
	local S = S_DemoWindowWidgetsProgressBars
	if ImGui.TreeNode("Progress Bars") then
		S.progress_accum = S.progress_accum + S.progress_dir * 0.4 * ImGui.GetIO().DeltaTime
		if S.progress_accum >= 1.1 then
			S.progress_accum = 1.1
			S.progress_dir = S.progress_dir * -1.0
		end
		if S.progress_accum <= -0.1 then
			S.progress_accum = -0.1
			S.progress_dir = S.progress_dir * -1.0
		end

		local progress = ImClamp(S.progress_accum, 0.0, 1.0)

		ImGui.ProgressBar(progress, ImVec2(0.0, 0.0))
		ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
		ImGui.Text("Progress Bar")

		local buf = Base.ImFormatString("%d/%d", Base.ImTruncToInt(progress * 1753), 1753)
		ImGui.ProgressBar(progress, ImVec2(0.0, 0.0), buf)

		ImGui.ProgressBar(-1.0 * ImGui.GetTime(), ImVec2(0.0, 0.0), "Searching..")
		ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
		ImGui.Text("Indeterminate")

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsQueryingStatuses = {
	item_type = 4,
	item_disabled = false,
	item_mixedvalue = false,
	liveedit_flags_override = false,
	liveedit_flags = 0,
	b = false,
	col4f = { 1.0, 0.5, 0.0, 1.0 },
	str = "",
	combo_current = 1,
	listbox_current = 1,
	embed_all_inside_a_child_window = false,
	test_window = false,
}
function Demo.DemoWindowWidgetsQueryingStatuses()
	local S = S_DemoWindowWidgetsQueryingStatuses
	local _
	if ImGui.TreeNode("Querying Item Status (Edited/Active/Hovered etc.)") then
		local item_names = {
			"Text", "Button", "Button (w/ repeat)", "Checkbox", "SliderFloat", "InputText", "InputTextMultiline", "InputFloat",
			"InputFloat3", "ColorEdit4", "Selectable", "MenuItem", "TreeNode", "TreeNode (w/ double-click)", "Combo", "ListBox",
		}
		_, S.item_type = ImGui.Combo("Item Type", S.item_type, item_names, #item_names, #item_names)
		ImGui.SameLine()
		Demo.HelpMarker("Testing how various types of items are interacting with the IsItemXXX functions. Note that the bool return value of most ImGui function is generally equivalent to calling ImGui::IsItemHovered().")
		_, S.item_disabled = ImGui.Checkbox("Item Disabled", S.item_disabled)
		_, S.item_mixedvalue = ImGui.Checkbox("Item MixedValue", S.item_mixedvalue)
		_, S.liveedit_flags_override = ImGui.Checkbox("Override LiveEdit:", S.liveedit_flags_override)
		ImGui.SameLine()
		if not S.liveedit_flags_override then
			S.liveedit_flags = ImGui.GetItemFlags()
		end
		ImGui.BeginDisabled(S.liveedit_flags_override == false)
		_, S.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInput", S.liveedit_flags, ImGuiItemFlags.LiveEditOnInput)
		ImGui.SameLine()
		_, S.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputText", S.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText)
		ImGui.SameLine()
		_, S.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputScalar", S.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar)
		ImGui.EndDisabled()
		if S.liveedit_flags_override then
			ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, bit32.btest(S.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText))
			ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, bit32.btest(S.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar))
		end

		local ret = false
		if S.item_disabled then
			ImGui.BeginDisabled(true)
		end
		if S.item_mixedvalue then
			ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true)
		end
		if S.item_type == 0 then
			ImGui.Text("ITEM: Text")
		end
		if S.item_type == 1 then
			ret = ImGui.Button("ITEM: Button")
		end
		if S.item_type == 2 then
			ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true)
			ret = ImGui.Button("ITEM: Button")
			ImGui.PopItemFlag()
		end
		if S.item_type == 3 then
			ret, S.b = ImGui.Checkbox("ITEM: Checkbox", S.b)
		end
		if S.item_type == 4 then
			ret, S.col4f[1] = ImGui.SliderFloat("ITEM: SliderFloat", S.col4f[1], 0.0, 1.0)
		end
		if S.item_type == 5 then
			ret, S.str = ImGui.InputText("ITEM: InputText", S.str)
		end
		if S.item_type == 6 then
			ret, S.str = ImGui.InputTextMultiline("ITEM: InputTextMultiline", S.str, ImVec2(0.0, 0.0))
		end
		if S.item_type == 7 then
			ret, S.col4f[1] = ImGui.InputFloat("ITEM: InputFloat", S.col4f[1], 1.0)
		end
		if S.item_type == 8 then
			ret = ImGui.InputFloat3("ITEM: InputFloat3", S.col4f)
		end
		if S.item_type == 9 then
			ret = ImGui.ColorEdit4("ITEM: ColorEdit4", S.col4f)
		end
		if S.item_type == 10 then
			ret = ImGui.Selectable("ITEM: Selectable", false)
		end
		if S.item_type == 11 then
			ret = ImGui.MenuItem("ITEM: MenuItem")
		end
		if S.item_type == 12 then
			ret = ImGui.TreeNode("ITEM: TreeNode")
			if ret then
				ImGui.TreePop()
			end
		end
		if S.item_type == 13 then
			ret = ImGui.TreeNodeEx("ITEM: TreeNode w/ ImGuiTreeNodeFlags_OpenOnDoubleClick", bit32.bor(ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.NoTreePushOnOpen))
		end
		if S.item_type == 14 then
			local items = { "Apple", "Banana", "Cherry", "Kiwi" }
			ret, S.combo_current = ImGui.Combo("ITEM: Combo", S.combo_current, items, #items)
		end
		if S.item_type == 15 then
			local items = { "Apple", "Banana", "Cherry", "Kiwi" }
			ret, S.listbox_current = ImGui.ListBox("ITEM: ListBox", S.listbox_current, items, #items, #items)
		end

		local hovered_delay_none = ImGui.IsItemHovered()
		local hovered_delay_stationary = ImGui.IsItemHovered(ImGuiHoveredFlags.Stationary)
		local hovered_delay_short = ImGui.IsItemHovered(ImGuiHoveredFlags.DelayShort)
		local hovered_delay_normal = ImGui.IsItemHovered(ImGuiHoveredFlags.DelayNormal)
		local hovered_delay_tooltip = ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip)

		ImGui.BulletText(
			"Return value = %d\n" ..
			"IsItemFocused() = %d\n" ..
			"IsItemHovered() = %d\n" ..
			"IsItemHovered(_AllowWhenBlockedByPopup) = %d\n" ..
			"IsItemHovered(_AllowWhenBlockedByActiveItem) = %d\n" ..
			"IsItemHovered(_AllowWhenOverlappedByItem) = %d\n" ..
			"IsItemHovered(_AllowWhenOverlappedByWindow) = %d\n" ..
			"IsItemHovered(_AllowWhenDisabled) = %d\n" ..
			"IsItemHovered(_RectOnly) = %d\n" ..
			"IsItemActive() = %d\n" ..
			"IsItemEdited() = %d\n" ..
			"IsItemActivated() = %d\n" ..
			"IsItemDeactivated() = %d\n" ..
			"IsItemDeactivatedAfterEdit() = %d\n" ..
			"IsItemVisible() = %d\n" ..
			"IsItemClicked() = %d\n" ..
			"IsItemToggledOpen() = %d\n" ..
			"GetItemRectMin() = (%.1f, %.1f)\n" ..
			"GetItemRectMax() = (%.1f, %.1f)\n" ..
			"GetItemRectSize() = (%.1f, %.1f)",
			b2i(ret),
			b2i(ImGui.IsItemFocused()),
			b2i(ImGui.IsItemHovered()),
			b2i(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)),
			b2i(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem)),
			b2i(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenOverlappedByItem)),
			b2i(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenOverlappedByWindow)),
			b2i(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled)),
			b2i(ImGui.IsItemHovered(ImGuiHoveredFlags.RectOnly)),
			b2i(ImGui.IsItemActive()),
			b2i(ImGui.IsItemEdited()),
			b2i(ImGui.IsItemActivated()),
			b2i(ImGui.IsItemDeactivated()),
			b2i(ImGui.IsItemDeactivatedAfterEdit()),
			b2i(ImGui.IsItemVisible()),
			b2i(ImGui.IsItemClicked()),
			b2i(ImGui.IsItemToggledOpen()),
			ImGui.GetItemRectMin().x, ImGui.GetItemRectMin().y,
			ImGui.GetItemRectMax().x, ImGui.GetItemRectMax().y,
			ImGui.GetItemRectSize().x, ImGui.GetItemRectSize().y
		)
		ImGui.BulletText(
			"with Hovering Delay or Stationary test:\n" ..
			"IsItemHovered() = %d\n" ..
			"IsItemHovered(_Stationary) = %d\n" ..
			"IsItemHovered(_DelayShort) = %d\n" ..
			"IsItemHovered(_DelayNormal) = %d\n" ..
			"IsItemHovered(_Tooltip) = %d",
			b2i(hovered_delay_none), b2i(hovered_delay_stationary), b2i(hovered_delay_short), b2i(hovered_delay_normal), b2i(hovered_delay_tooltip)
		)

		if S.liveedit_flags_override then
			ImGui.PopItemFlag()
			ImGui.PopItemFlag()
		end
		if S.item_mixedvalue then
			ImGui.PopItemFlag()
		end
		if S.item_disabled then
			ImGui.EndDisabled()
		end

		ImGui.InputText("unused", "", ImGuiInputTextFlags.ReadOnly)
		ImGui.SameLine()
		Demo.HelpMarker("This widget is only here to be able to tab-out of the widgets above and see e.g. Deactivated() status.")

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Querying Window Status (Focused/Hovered etc.)") then
		_, S.embed_all_inside_a_child_window = ImGui.Checkbox("Embed everything inside a child window for testing _RootWindow flag.", S.embed_all_inside_a_child_window)
		if S.embed_all_inside_a_child_window then
			ImGui.BeginChild("outer_child", ImVec2(0, ImGui.GetFontSize() * 20.0), ImGuiChildFlags.Borders)
		end

		ImGui.BulletText(
			"IsWindowFocused() = %d\n" ..
			"IsWindowFocused(_ChildWindows) = %d\n" ..
			"IsWindowFocused(_ChildWindows|_NoPopupHierarchy) = %d\n" ..
			"IsWindowFocused(_ChildWindows|_RootWindow) = %d\n" ..
			"IsWindowFocused(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\n" ..
			"IsWindowFocused(_RootWindow) = %d\n" ..
			"IsWindowFocused(_RootWindow|_NoPopupHierarchy) = %d\n" ..
			"IsWindowFocused(_AnyWindow) = %d\n",
			b2i(ImGui.IsWindowFocused()),
			b2i(ImGui.IsWindowFocused(ImGuiFocusedFlags.ChildWindows)),
			b2i(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.NoPopupHierarchy))),
			b2i(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.RootWindow))),
			b2i(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.NoPopupHierarchy))),
			b2i(ImGui.IsWindowFocused(ImGuiFocusedFlags.RootWindow)),
			b2i(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.NoPopupHierarchy))),
			b2i(ImGui.IsWindowFocused(ImGuiFocusedFlags.AnyWindow))
		)

		ImGui.BulletText(
			"IsWindowHovered() = %d\n" ..
			"IsWindowHovered(_AllowWhenBlockedByPopup) = %d\n" ..
			"IsWindowHovered(_AllowWhenBlockedByActiveItem) = %d\n" ..
			"IsWindowHovered(_ChildWindows) = %d\n" ..
			"IsWindowHovered(_ChildWindows|_NoPopupHierarchy) = %d\n" ..
			"IsWindowHovered(_ChildWindows|_RootWindow) = %d\n" ..
			"IsWindowHovered(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\n" ..
			"IsWindowHovered(_RootWindow) = %d\n" ..
			"IsWindowHovered(_RootWindow|_NoPopupHierarchy) = %d\n" ..
			"IsWindowHovered(_ChildWindows|_AllowWhenBlockedByPopup) = %d\n" ..
			"IsWindowHovered(_AnyWindow) = %d\n" ..
			"IsWindowHovered(_Stationary) = %d\n",
			b2i(ImGui.IsWindowHovered()),
			b2i(ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)),
			b2i(ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem)),
			b2i(ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)),
			b2i(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.NoPopupHierarchy))),
			b2i(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.RootWindow))),
			b2i(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.NoPopupHierarchy))),
			b2i(ImGui.IsWindowHovered(ImGuiHoveredFlags.RootWindow)),
			b2i(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.NoPopupHierarchy))),
			b2i(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.AllowWhenBlockedByPopup))),
			b2i(ImGui.IsWindowHovered(ImGuiHoveredFlags.AnyWindow)),
			b2i(ImGui.IsWindowHovered(ImGuiHoveredFlags.Stationary))
		)

		ImGui.BeginChild("child", ImVec2(0, 50), ImGuiChildFlags.Borders)
		ImGui.Text("This is another child window for testing the _ChildWindows flag.")
		ImGui.EndChild()
		if S.embed_all_inside_a_child_window then
			ImGui.EndChild()
		end

		_, S.test_window = ImGui.Checkbox("Hovered/Active tests after Begin() for title bar testing", S.test_window)
		if S.test_window then
			_, S.test_window = ImGui.Begin("Title bar Hovered/Active tests", S.test_window)
			if ImGui.BeginPopupContextItem() then
				if ImGui.MenuItem("Close") then
					S.test_window = false
				end
				ImGui.EndPopup()
			end
			ImGui.Text(
				"IsItemHovered() after begin = %d (== is title bar hovered)\n" ..
				"IsItemActive() after begin = %d (== is window being clicked/moved)\n",
				b2i(ImGui.IsItemHovered()), b2i(ImGui.IsItemActive())
			)
			ImGui.End()
		end

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsSelectables = {
	basic_selection = { false, true, false, false, false },
	multi_selected = { false, false, false },
	checked = table.create(5, false),
	selected_n = 0,
	table_selected = table.create(10, false),
	grid_selected = {
		{ 1, 0, 0, 0 },
		{ 0, 1, 0, 0 },
		{ 0, 0, 1, 0 },
		{ 0, 0, 0, 1 },
	},
	align_selected = { true, false, true, false, true, false, true, false, true },
}
function Demo.DemoWindowWidgetsSelectables()
	local S = S_DemoWindowWidgetsSelectables
	local _
	if ImGui.TreeNode("Selectables") then
		if ImGui.TreeNode("Basic") then
			_, S.basic_selection[1] = ImGui.Selectable("1. I am selectable", S.basic_selection[1])
			_, S.basic_selection[2] = ImGui.Selectable("2. I am selectable", S.basic_selection[2])
			_, S.basic_selection[3] = ImGui.Selectable("3. I am selectable", S.basic_selection[3])
			if ImGui.Selectable("4. I am double clickable", S.basic_selection[4], ImGuiSelectableFlags.AllowDoubleClick) then
				if ImGui.IsMouseDoubleClicked(0) then
					S.basic_selection[4] = not S.basic_selection[4]
				end
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multiple items on the same line") then
			do
				ImGui.SetNextItemAllowOverlap()
				_, S.multi_selected[1] = ImGui.Selectable("main.c", S.multi_selected[1])
				ImGui.SameLine()
				ImGui.SmallButton("Link 1")
				ImGui.SetNextItemAllowOverlap()
				_, S.multi_selected[2] = ImGui.Selectable("hello.cpp", S.multi_selected[2])
				ImGui.SameLine()
				ImGui.SmallButton("Link 2")
				ImGui.SetNextItemAllowOverlap()
				_, S.multi_selected[3] = ImGui.Selectable("hello.h", S.multi_selected[3])
				ImGui.SameLine()
				ImGui.SmallButton("Link 3")
			end

			ImGui.Spacing()
			do
				local color_marker_w = ImGui.CalcTextSize("x").x
				for n = 0, 4 do
					ImGui.PushID(n)
					ImGui.AlignTextToFramePadding()
					if ImGui.Selectable("##selectable", S.selected_n == n, ImGuiSelectableFlags.AllowOverlap) then
						S.selected_n = n
					end
					ImGui.SameLine(0, 0)
					_, S.checked[n + 1] = ImGui.Checkbox("##check", S.checked[n + 1])
					ImGui.SameLine()
					local color = ImVec4(if bit32.btest(n, 1) then 1.0 else 0.2, if bit32.btest(n, 2) then 1.0 else 0.2, 0.2, 1.0)
					ImGui.ColorButton("##color", color, ImGuiColorEditFlags.NoTooltip, ImVec2(color_marker_w, 0))
					ImGui.SameLine()
					ImGui.Text("Some label")
					ImGui.PopID()
				end
			end

			ImGui.TreePop()
		end

		if ImGui.TreeNode("In Tables") then
			if ImGui.BeginTable("split1", 3, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings, ImGuiTableFlags.Borders)) then
				for i = 0, 9 do
					local label = Base.ImFormatString("Item %d", i)
					ImGui.TableNextColumn()
					_, S.table_selected[i + 1] = ImGui.Selectable(label, S.table_selected[i + 1])
				end
				ImGui.EndTable()
			end
			ImGui.Spacing()
			if ImGui.BeginTable("split2", 3, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings, ImGuiTableFlags.Borders)) then
				for i = 0, 9 do
					local label = Base.ImFormatString("Item %d", i)
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					_, S.table_selected[i + 1] = ImGui.Selectable(label, S.table_selected[i + 1], ImGuiSelectableFlags.SpanAllColumns)
					ImGui.TableNextColumn()
					ImGui.Text("Some other contents")
					ImGui.TableNextColumn()
					ImGui.Text("123456")
				end
				ImGui.EndTable()
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Grid") then
			local selected = S.grid_selected
			local time = ImGui.GetTime()
			local winning_state = true
			for y = 1, 4 do
				for x = 1, 4 do
					if selected[y][x] == 0 then
						winning_state = false
					end
				end
			end
			if winning_state then
				ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, ImVec2(0.5 + 0.5 * math.cos(time * 2.0), 0.5 + 0.5 * math.sin(time * 3.0)))
			end

			local size = ImGui.CalcTextSize("Sailor").x
			for y = 0, 3 do
				for x = 0, 3 do
					if x > 0 then
						ImGui.SameLine()
					end
					ImGui.PushID(y * 4 + x)
					if ImGui.Selectable("Sailor", selected[y + 1][x + 1] ~= 0, 0, ImVec2(size, size)) then
						selected[y + 1][x + 1] = bit32.bxor(selected[y + 1][x + 1], 1)
						if x > 0 then
							selected[y + 1][x] = bit32.bxor(selected[y + 1][x], 1)
						end
						if x < 3 then
							selected[y + 1][x + 2] = bit32.bxor(selected[y + 1][x + 2], 1)
						end
						if y > 0 then
							selected[y][x + 1] = bit32.bxor(selected[y][x + 1], 1)
						end
						if y < 3 then
							selected[y + 2][x + 1] = bit32.bxor(selected[y + 2][x + 1], 1)
						end
					end
					ImGui.PopID()
				end
			end

			if winning_state then
				ImGui.PopStyleVar()
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Alignment") then
			Demo.HelpMarker(
				"By default, Selectables uses style.SelectableTextAlign but it can be overridden on a per-item " ..
				"basis using PushStyleVar(). You'll probably want to always keep your default situation to " ..
				"left-align otherwise it becomes difficult to layout multiple items on a same line"
			)

			local size = ImGui.CalcTextSize("(1.0,1.0)").x
			for y = 0, 2 do
				for x = 0, 2 do
					local alignment = ImVec2(x / 2.0, y / 2.0)
					local name = Base.ImFormatString("(%.1f,%.1f)", alignment.x, alignment.y)
					if x > 0 then
						ImGui.SameLine()
					end
					ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, alignment)
					_, S.align_selected[3 * y + x + 1] = ImGui.Selectable(name, S.align_selected[3 * y + x + 1], ImGuiSelectableFlags.None, ImVec2(size, size))
					ImGui.PopStyleVar()
				end
			end
			ImGui.TreePop()
		end
		ImGui.TreePop()
	end
end

local ExampleTreeFuncs = {}
Demo.ExampleTreeFuncs = ExampleTreeFuncs

function ExampleTreeFuncs.DrawNode(node, selection)
	local tree_node_flags = bit32.bor(ImGuiTreeNodeFlags.SpanAvailWidth, ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick)
	tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent)
	if node.Childs.Size == 0 then
		tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.Leaf)
	end
	if selection:Contains(node.UID) then
		tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.Selected)
	end

	ImGui.SetNextItemSelectionUserData(node)
	ImGui.SetNextItemStorageID(node.UID)
	if ImGui.TreeNodeEx(node.Name, tree_node_flags) then
		for i = 1, node.Childs.Size do
			ExampleTreeFuncs.DrawNode(node.Childs[i], selection)
		end
		ImGui.TreePop()
	elseif ImGui.IsItemToggledOpen() then
		ExampleTreeFuncs.TreeCloseAndUnselectChildNodes(node, selection)
	end
end

function ExampleTreeFuncs.TreeCloseAndUnselectChildNodes(node, selection, depth)
	if depth == nil then
		depth = 0
	end
	local unselected_count = if selection:Contains(node.UID) then 1 else 0
	if depth == 0 or ImGui.TreeNodeGetOpen(node.UID) then
		for i = 1, node.Childs.Size do
			unselected_count = unselected_count + ExampleTreeFuncs.TreeCloseAndUnselectChildNodes(node.Childs[i], selection, depth + 1)
		end
		ImGui.TreeNodeSetOpen(node.UID, false)
	end

	selection:SetItemSelected(node.UID, depth == 0 and unselected_count > 0)
	return unselected_count
end

function ExampleTreeFuncs.ApplySelectionRequests(ms_io, tree, selection)
	for i = 1, ms_io.Requests.Size do
		local req = ms_io.Requests[i]
		if req.Type == ImGuiSelectionRequestType.SetAll then
			if req.Selected then
				ExampleTreeFuncs.TreeSetAllInOpenNodes(tree, selection, req.Selected)
			else
				selection:Clear()
			end
		elseif req.Type == ImGuiSelectionRequestType.SetRange then
			local first_node = req.RangeFirstItem
			local last_node = req.RangeLastItem
			local node = first_node
			while node ~= nil do
				selection:SetItemSelected(node.UID, req.Selected)
				node = ExampleTreeFuncs.TreeGetNextNodeInVisibleOrder(node, last_node)
			end
		end
	end
end

function ExampleTreeFuncs.TreeSetAllInOpenNodes(node, selection, selected)
	if node.Parent ~= nil then
		selection:SetItemSelected(node.UID, selected)
	end
	if node.Parent == nil or ImGui.TreeNodeGetOpen(node.UID) then
		for i = 1, node.Childs.Size do
			ExampleTreeFuncs.TreeSetAllInOpenNodes(node.Childs[i], selection, selected)
		end
	end
end

function ExampleTreeFuncs.TreeGetNextNodeInVisibleOrder(curr_node, last_node)
	if curr_node == last_node then
		return nil
	end

	if curr_node.Childs.Size > 0 and ImGui.TreeNodeGetOpen(curr_node.UID) then
		return curr_node.Childs[1]
	end

	while curr_node.Parent ~= nil do
		if curr_node.IndexInParent + 1 < curr_node.Parent.Childs.Size then
			return curr_node.Parent.Childs[curr_node.IndexInParent + 2]
		end
		curr_node = curr_node.Parent
	end
	return nil
end

local S_DemoWindowWidgetsSelectionAndMultiSelect = {
	single_selected = -1,
	manual_selection = table.create(5, false),
	basic_selection = ImGuiSelectionBasicStorage.new(),
	clipper_selection = ImGuiSelectionBasicStorage.new(),
	del_items = ImVector.new(),
	del_selection = ExampleSelectionWithDeletion.new(),
	del_items_next_id = 0,
	dlb = ExampleDualListBox.new(),
	table_selection = ImGuiSelectionBasicStorage.new(),
	check_items = table.create(20, false),
	check_flags = bit32.bor(ImGuiMultiSelectFlags.NoAutoSelect, ImGuiMultiSelectFlags.NoAutoClear, ImGuiMultiSelectFlags.ClearOnEscape),
	scope_selections = {
		ImGuiSelectionBasicStorage.new(),
		ImGuiSelectionBasicStorage.new(),
		ImGuiSelectionBasicStorage.new(),
	},
	scope_flags = bit32.bor(ImGuiMultiSelectFlags.ScopeRect, ImGuiMultiSelectFlags.ClearOnEscape),
	tree_selection = ImGuiSelectionBasicStorage.new(),
	adv_use_clipper = true,
	adv_use_deletion = true,
	adv_use_drag_drop = true,
	adv_show_in_table = false,
	adv_show_color_button = true,
	adv_flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d),
	adv_widget_type = 0,
	adv_items = ImVector.new(),
	adv_items_next_id = 0,
	adv_selection = ExampleSelectionWithDeletion.new(),
	adv_request_deletion_from_menu = false,
}
function Demo.DemoWindowWidgetsSelectionAndMultiSelect(demo_data)
	local S = S_DemoWindowWidgetsSelectionAndMultiSelect
	local _
	local pressed
	local WidgetType = { Selectable = 0, TreeNode = 1 }
	if ImGui.TreeNode("Selection State & Multi-Select") then
		Demo.HelpMarker("Selections can be built using Selectable(), TreeNode() or other widgets. Selection state is owned by application code/data.")

		ImGui.BulletText("Wiki page:")
		ImGui.SameLine()
		ImGui.TextLinkOpenURL("imgui/wiki/Multi-Select", "https://github.com/ocornut/imgui/wiki/Multi-Select")

		if ImGui.TreeNode("Single-Select") then
			for n = 0, 4 do
				local buf = Base.ImFormatString("Object %d", n)
				if ImGui.Selectable(buf, S.single_selected == n) then
					S.single_selected = n
				end
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (manual/simplified, without BeginMultiSelect)") then
			Demo.HelpMarker("Hold Ctrl and Click to select multiple items.")
			for n = 0, 4 do
				local buf = Base.ImFormatString("Object %d", n)
				if ImGui.Selectable(buf, S.manual_selection[n + 1]) then
					if not ImGui.GetIO().KeyCtrl then
						for i = 1, 5 do
							S.manual_selection[i] = false
						end
					end
					S.manual_selection[n + 1] = not S.manual_selection[n + 1]
				end
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select") then
			ImGui.Text("Supported features:")
			ImGui.BulletText("Keyboard navigation (arrows, page up/down, home/end, space).")
			ImGui.BulletText("Ctrl modifier to preserve and toggle selection.")
			ImGui.BulletText("Shift modifier for range selection.")
			ImGui.BulletText("Ctrl+A to select all.")
			ImGui.BulletText("Escape to clear selection.")
			ImGui.BulletText("Click and drag to box-select.")
			ImGui.Text("Tip: Use 'Demo->Tools->Debug Log->Selection' to see selection requests as they happen.")

			local ITEMS_COUNT = 50
			ImGui.Text("Selection: %d/%d", S.basic_selection.Size, ITEMS_COUNT)

			if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
				local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
				local ms_io = ImGui.BeginMultiSelect(flags, S.basic_selection.Size, ITEMS_COUNT)
				S.basic_selection:ApplyRequests(ms_io)

				for n = 0, ITEMS_COUNT - 1 do
					local label = Base.ImFormatString("Object %05d: %s", n, Demo.ExampleNames[(n % #Demo.ExampleNames) + 1])
					local item_is_selected = S.basic_selection:Contains(n)
					ImGui.SetNextItemSelectionUserData(n)
					ImGui.Selectable(label, item_is_selected)
				end

				ms_io = ImGui.EndMultiSelect()
				S.basic_selection:ApplyRequests(ms_io)
			end
			ImGui.EndChild()
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (with clipper)") then
			ImGui.Text("Added features:")
			ImGui.BulletText("Using ImGuiListClipper.")

			local ITEMS_COUNT = 10000
			ImGui.Text("Selection: %d/%d", S.clipper_selection.Size, ITEMS_COUNT)
			if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
				local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
				local ms_io = ImGui.BeginMultiSelect(flags, S.clipper_selection.Size, ITEMS_COUNT)
				S.clipper_selection:ApplyRequests(ms_io)

				local clipper = ImGuiListClipper.new()
				clipper:Begin(ITEMS_COUNT)
				if ms_io.RangeSrcItem ~= -1 then
					clipper:IncludeItemByIndex(ms_io.RangeSrcItem)
				end
				while clipper:Step() do
					for n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
						local label = Base.ImFormatString("Object %05d: %s", n, Demo.ExampleNames[(n % #Demo.ExampleNames) + 1])
						local item_is_selected = S.clipper_selection:Contains(n)
						ImGui.SetNextItemSelectionUserData(n)
						ImGui.Selectable(label, item_is_selected)
					end
				end

				ms_io = ImGui.EndMultiSelect()
				S.clipper_selection:ApplyRequests(ms_io)
			end
			ImGui.EndChild()
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (with deletion)") then
			local items = S.del_items
			local selection = S.del_selection
			selection.UserData = items
			selection.AdapterIndexToStorageId = function(self_, idx)
				return self_.UserData[idx + 1]
			end

			ImGui.Text("Added features:")
			ImGui.BulletText("Dynamic list with Delete key support.")
			ImGui.Text("Selection size: %d/%d", selection.Size, items.Size)

			if S.del_items_next_id == 0 then
				for n = 0, 49 do
					items:push_back(S.del_items_next_id)
					S.del_items_next_id = S.del_items_next_id + 1
				end
			end
			if ImGui.SmallButton("Add 20 items") then
				for n = 0, 19 do
					items:push_back(S.del_items_next_id)
					S.del_items_next_id = S.del_items_next_id + 1
				end
			end
			ImGui.SameLine()
			if ImGui.SmallButton("Remove 20 items") then
				for n = ImMin(20, items.Size), 1, -1 do
					selection:SetItemSelected(items:back(), false)
					items:pop_back()
				end
			end

			local items_height = ImGui.GetTextLineHeightWithSpacing()
			ImGui.SetNextWindowContentSize(ImVec2(0.0, items.Size * items_height))

			if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
				local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
				local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, items.Size)
				selection:ApplyRequests(ms_io)

				local want_delete = ImGui.Shortcut(ImGuiKey.Delete, ImGuiInputFlags.Repeat) and (selection.Size > 0)
				local item_curr_idx_to_focus = if want_delete then selection:ApplyDeletionPreLoop(ms_io, items.Size) else -1

				for n = 0, items.Size - 1 do
					local item_id = items[n + 1]
					local label = Base.ImFormatString("Object %05u: %s", item_id, Demo.ExampleNames[(item_id % #Demo.ExampleNames) + 1])

					local item_is_selected = selection:Contains(item_id)
					ImGui.SetNextItemSelectionUserData(n)
					ImGui.Selectable(label, item_is_selected)
					if item_curr_idx_to_focus == n then
						ImGui.SetKeyboardFocusHere(-1)
					end
				end

				ms_io = ImGui.EndMultiSelect()
				selection:ApplyRequests(ms_io)
				if want_delete then
					selection:ApplyDeletionPostLoop(ms_io, items, item_curr_idx_to_focus)
				end
			end
			ImGui.EndChild()
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (dual list box)") then
			local dlb = S.dlb
			if dlb.Items[1].Size == 0 and dlb.Items[2].Size == 0 then
				for item_id = 0, #Demo.ExampleNames - 1 do
					dlb.Items[1]:push_back(item_id)
				end
			end

			dlb:Show()

			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (in a table)") then
			local selection = S.table_selection

			local ITEMS_COUNT = 10000
			ImGui.Text("Selection: %d/%d", selection.Size, ITEMS_COUNT)
			if ImGui.BeginTable("##Basket", 2, bit32.bor(ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter), ImVec2(0.0, ImGui.GetFontSize() * 20)) then
				ImGui.TableSetupColumn("Object")
				ImGui.TableSetupColumn("Action")
				ImGui.TableSetupScrollFreeze(0, 1)
				ImGui.TableHeadersRow()

				local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
				local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, ITEMS_COUNT)
				selection:ApplyRequests(ms_io)

				local clipper = ImGuiListClipper.new()
				clipper:Begin(ITEMS_COUNT)
				if ms_io.RangeSrcItem ~= -1 then
					clipper:IncludeItemByIndex(ms_io.RangeSrcItem)
				end
				while clipper:Step() do
					for n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
						ImGui.TableNextRow()
						ImGui.TableNextColumn()
						ImGui.PushID(n)
						local label = Base.ImFormatString("Object %05d: %s", n, Demo.ExampleNames[(n % #Demo.ExampleNames) + 1])
						local item_is_selected = selection:Contains(n)
						ImGui.SetNextItemSelectionUserData(n)
						ImGui.Selectable(label, item_is_selected, bit32.bor(ImGuiSelectableFlags.SpanAllColumns, ImGuiSelectableFlags.AllowOverlap))
						ImGui.TableNextColumn()
						ImGui.SmallButton("hello")
						ImGui.PopID()
					end
				end

				ms_io = ImGui.EndMultiSelect()
				selection:ApplyRequests(ms_io)
				ImGui.EndTable()
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (checkboxes)") then
			ImGui.Text("In a list of checkboxes (not selectable):")
			ImGui.BulletText("Using _NoAutoSelect + _NoAutoClear flags.")
			ImGui.BulletText("Shift+Click to check multiple boxes.")
			ImGui.BulletText("Shift+Keyboard to copy current value to other boxes.")

			_, S.check_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoSelect", S.check_flags, ImGuiMultiSelectFlags.NoAutoSelect)
			_, S.check_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoClear", S.check_flags, ImGuiMultiSelectFlags.NoAutoClear)
			_, S.check_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect2d", S.check_flags, ImGuiMultiSelectFlags.BoxSelect2d)

			if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then
				local ms_io = ImGui.BeginMultiSelect(S.check_flags, -1, #S.check_items)
				local storage_wrapper = ImGuiSelectionExternalStorage.new()
				storage_wrapper.UserData = S.check_items
				storage_wrapper.AdapterSetItemSelected = function(self_, n, selected)
					self_.UserData[n + 1] = selected
				end
				storage_wrapper:ApplyRequests(ms_io)
				for n = 0, 19 do
					local label = Base.ImFormatString("Item %d", n)
					ImGui.SetNextItemSelectionUserData(n)
					_, S.check_items[n + 1] = ImGui.Checkbox(label, S.check_items[n + 1])
				end
				ms_io = ImGui.EndMultiSelect()
				storage_wrapper:ApplyRequests(ms_io)
			end
			ImGui.EndChild()

			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (multiple scopes)") then
			local SCOPES_COUNT = 3
			local ITEMS_COUNT = 8

			pressed, S.scope_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeWindow", S.scope_flags, ImGuiMultiSelectFlags.ScopeWindow)
			if pressed and bit32.btest(S.scope_flags, ImGuiMultiSelectFlags.ScopeWindow) then
				S.scope_flags = bit32.band(S.scope_flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeRect))
			end
			pressed, S.scope_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeRect", S.scope_flags, ImGuiMultiSelectFlags.ScopeRect)
			if pressed and bit32.btest(S.scope_flags, ImGuiMultiSelectFlags.ScopeRect) then
				S.scope_flags = bit32.band(S.scope_flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeWindow))
			end
			_, S.scope_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ClearOnClickVoid", S.scope_flags, ImGuiMultiSelectFlags.ClearOnClickVoid)
			_, S.scope_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect1d", S.scope_flags, ImGuiMultiSelectFlags.BoxSelect1d)

			for selection_scope_n = 0, SCOPES_COUNT - 1 do
				ImGui.PushID(selection_scope_n)
				local selection = S.scope_selections[selection_scope_n + 1]
				local ms_io = ImGui.BeginMultiSelect(S.scope_flags, selection.Size, ITEMS_COUNT)
				selection:ApplyRequests(ms_io)

				ImGui.SeparatorText("Selection scope")
				ImGui.Text("Selection size: %d/%d", selection.Size, ITEMS_COUNT)

				for n = 0, ITEMS_COUNT - 1 do
					local label = Base.ImFormatString("Object %05d: %s", n, Demo.ExampleNames[(n % #Demo.ExampleNames) + 1])
					local item_is_selected = selection:Contains(n)
					ImGui.SetNextItemSelectionUserData(n)
					ImGui.Selectable(label, item_is_selected)
				end

				ms_io = ImGui.EndMultiSelect()
				selection:ApplyRequests(ms_io)
				ImGui.PopID()
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (tiled assets browser)") then
			_, demo_data.ShowAppAssetsBrowser = ImGui.Checkbox("Assets Browser", demo_data.ShowAppAssetsBrowser)
			ImGui.Text("(also access from 'Examples->Assets Browser' in menu)")
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (trees)") then
			Demo.HelpMarker(
				"This is rather advanced and experimental. If you are getting started with multi-select, " ..
				"please don't start by looking at how to use it for a tree!\n\n" ..
				"Future versions will try to simplify and formalize some of this."
			)

			local selection = S.tree_selection
			if demo_data.DemoTree == nil then
				demo_data.DemoTree = Demo.ExampleTree_CreateDemoTree()
			end
			ImGui.Text("Selection size: %d", selection.Size)

			if ImGui.BeginChild("##Tree", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
				local tree = demo_data.DemoTree
				local ms_flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect2d)
				local ms_io = ImGui.BeginMultiSelect(ms_flags, selection.Size, -1)
				ExampleTreeFuncs.ApplySelectionRequests(ms_io, tree, selection)
				for i = 1, tree.Childs.Size do
					ExampleTreeFuncs.DrawNode(tree.Childs[i], selection)
				end
				ms_io = ImGui.EndMultiSelect()
				ExampleTreeFuncs.ApplySelectionRequests(ms_io, tree, selection)
			end
			ImGui.EndChild()

			ImGui.TreePop()
		end

		if ImGui.TreeNode("Multi-Select (advanced)") then
			if ImGui.TreeNode("Options") then
				if ImGui.RadioButton("Selectables", S.adv_widget_type == WidgetType.Selectable) then
					S.adv_widget_type = WidgetType.Selectable
				end
				ImGui.SameLine()
				if ImGui.RadioButton("Tree nodes", S.adv_widget_type == WidgetType.TreeNode) then
					S.adv_widget_type = WidgetType.TreeNode
				end
				ImGui.SameLine()
				Demo.HelpMarker("TreeNode() is technically supported but... using this correctly is more complicated (you need some sort of linear/random access to your tree, which is suited to advanced trees setups already implementing filters and clipper. We will work toward simplifying and demoing this.\n\nFor now the tree demo is actually a little bit meaningless because it is an empty tree with only root nodes.")
				_, S.adv_use_clipper = ImGui.Checkbox("Enable clipper", S.adv_use_clipper)
				_, S.adv_use_deletion = ImGui.Checkbox("Enable deletion", S.adv_use_deletion)
				_, S.adv_use_drag_drop = ImGui.Checkbox("Enable drag & drop", S.adv_use_drag_drop)
				_, S.adv_show_in_table = ImGui.Checkbox("Show in a table", S.adv_show_in_table)
				_, S.adv_show_color_button = ImGui.Checkbox("Show color button", S.adv_show_color_button)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SingleSelect", S.adv_flags, ImGuiMultiSelectFlags.SingleSelect)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoSelectAll", S.adv_flags, ImGuiMultiSelectFlags.NoSelectAll)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoRangeSelect", S.adv_flags, ImGuiMultiSelectFlags.NoRangeSelect)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoSelect", S.adv_flags, ImGuiMultiSelectFlags.NoAutoSelect)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoClear", S.adv_flags, ImGuiMultiSelectFlags.NoAutoClear)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoClearOnReselect", S.adv_flags, ImGuiMultiSelectFlags.NoAutoClearOnReselect)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoSelectOnRightClick", S.adv_flags, ImGuiMultiSelectFlags.NoSelectOnRightClick)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect1d", S.adv_flags, ImGuiMultiSelectFlags.BoxSelect1d)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect2d", S.adv_flags, ImGuiMultiSelectFlags.BoxSelect2d)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelectNoScroll", S.adv_flags, ImGuiMultiSelectFlags.BoxSelectNoScroll)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ClearOnEscape", S.adv_flags, ImGuiMultiSelectFlags.ClearOnEscape)
				_, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ClearOnClickVoid", S.adv_flags, ImGuiMultiSelectFlags.ClearOnClickVoid)
				pressed, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeWindow", S.adv_flags, ImGuiMultiSelectFlags.ScopeWindow)
				if pressed and bit32.btest(S.adv_flags, ImGuiMultiSelectFlags.ScopeWindow) then
					S.adv_flags = bit32.band(S.adv_flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeRect))
				end
				pressed, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeRect", S.adv_flags, ImGuiMultiSelectFlags.ScopeRect)
				if pressed and bit32.btest(S.adv_flags, ImGuiMultiSelectFlags.ScopeRect) then
					S.adv_flags = bit32.band(S.adv_flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeWindow))
				end
				pressed, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SelectOnAuto", S.adv_flags, ImGuiMultiSelectFlags.SelectOnAuto)
				if pressed then
					S.adv_flags = bit32.band(S.adv_flags, bit32.bnot(bit32.bxor(ImGuiMultiSelectFlags.SelectOnMask_, ImGuiMultiSelectFlags.SelectOnAuto)))
				end
				ImGui.SameLine()
				Demo.HelpMarker("Apply selection on mouse down when clicking on unselected item, on mouse up when clicking on selected item. (Default)")
				pressed, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SelectOnClickAlways", S.adv_flags, ImGuiMultiSelectFlags.SelectOnClickAlways)
				if pressed then
					S.adv_flags = bit32.band(S.adv_flags, bit32.bnot(bit32.bxor(ImGuiMultiSelectFlags.SelectOnMask_, ImGuiMultiSelectFlags.SelectOnClickAlways)))
				end
				ImGui.SameLine()
				Demo.HelpMarker("Prevents Drag and Drop from being used on multi-selection, but allows e.g. BoxSelect to always reselect even when clicking inside an existing selection. (Excel style behavior)")
				pressed, S.adv_flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SelectOnClickRelease", S.adv_flags, ImGuiMultiSelectFlags.SelectOnClickRelease)
				if pressed then
					S.adv_flags = bit32.band(S.adv_flags, bit32.bnot(bit32.bxor(ImGuiMultiSelectFlags.SelectOnMask_, ImGuiMultiSelectFlags.SelectOnClickRelease)))
				end
				ImGui.SameLine()
				Demo.HelpMarker("Allow dragging an unselected item without altering selection.")
				ImGui.TreePop()
			end

			local items = S.adv_items
			if S.adv_items_next_id == 0 then
				for n = 0, 999 do
					items:push_back(S.adv_items_next_id)
					S.adv_items_next_id = S.adv_items_next_id + 1
				end
			end
			local selection = S.adv_selection
			local request_deletion_from_menu = S.adv_request_deletion_from_menu
			selection.UserData = items
			selection.AdapterIndexToStorageId = function(self_, idx)
				return self_.UserData[idx + 1]
			end

			ImGui.Text("Selection size: %d/%d", selection.Size, items.Size)

			local items_height = if S.adv_widget_type == WidgetType.TreeNode then ImGui.GetTextLineHeight() else ImGui.GetTextLineHeightWithSpacing()
			ImGui.SetNextWindowContentSize(ImVec2(0.0, items.Size * items_height))
			if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
				local color_button_sz = ImVec2(ImGui.GetFontSize(), ImGui.GetFontSize())
				if S.adv_widget_type == WidgetType.TreeNode then
					ImGui.PushStyleVarY(ImGuiStyleVar.ItemSpacing, 0.0)
				end

				local ms_io = ImGui.BeginMultiSelect(S.adv_flags, selection.Size, items.Size)
				selection:ApplyRequests(ms_io)

				local want_delete = (ImGui.Shortcut(ImGuiKey.Delete, ImGuiInputFlags.Repeat) and (selection.Size > 0)) or request_deletion_from_menu
				local item_curr_idx_to_focus = if want_delete then selection:ApplyDeletionPreLoop(ms_io, items.Size) else -1
				request_deletion_from_menu = false

				if S.adv_show_in_table then
					if S.adv_widget_type == WidgetType.TreeNode then
						ImGui.PushStyleVar(ImGuiStyleVar.CellPadding, ImVec2(0.0, 0.0))
					end
					ImGui.BeginTable("##Split", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings, ImGuiTableFlags.NoPadOuterX))
					ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 0.70)
					ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 0.30)
				end

				local clipper = ImGuiListClipper.new()
				if S.adv_use_clipper then
					clipper:Begin(items.Size)
					if item_curr_idx_to_focus ~= -1 then
						clipper:IncludeItemByIndex(item_curr_idx_to_focus)
					end
					if ms_io.RangeSrcItem ~= -1 then
						clipper:IncludeItemByIndex(ms_io.RangeSrcItem)
					end
				end

				while not S.adv_use_clipper or clipper:Step() do
					local item_begin = if S.adv_use_clipper then clipper.DisplayStart else 0
					local item_end = if S.adv_use_clipper then clipper.DisplayEnd else items.Size
					for n = item_begin, item_end - 1 do
						if S.adv_show_in_table then
							ImGui.TableNextColumn()
						end

						local item_id = items[n + 1]
						local item_category = Demo.ExampleNames[(item_id % #Demo.ExampleNames) + 1]
						local label = Base.ImFormatString("Object %05d: %s", item_id, item_category)

						ImGui.PushID(item_id)

						if S.adv_show_color_button then
							local dummy_col = bit32.bor((n * 0xC250B74B) % 4294967296, Base.IM_COL32_A_MASK)
							ImGui.ColorButton("##", ImColor.new(dummy_col):ToImVec4(), ImGuiColorEditFlags.NoTooltip, color_button_sz)
							ImGui.SameLine()
						end

						local item_is_selected = selection:Contains(n)
						local item_is_open = false
						ImGui.SetNextItemSelectionUserData(n)
						if S.adv_widget_type == WidgetType.Selectable then
							ImGui.Selectable(label, item_is_selected, ImGuiSelectableFlags.None)
						elseif S.adv_widget_type == WidgetType.TreeNode then
							local tree_node_flags = bit32.bor(ImGuiTreeNodeFlags.SpanAvailWidth, ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick)
							if item_is_selected then
								tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.Selected)
							end
							item_is_open = ImGui.TreeNodeEx(label, tree_node_flags)
						end

						if item_curr_idx_to_focus == n then
							ImGui.SetKeyboardFocusHere(-1)
						end

						if S.adv_use_drag_drop and ImGui.BeginDragDropSource() then
							if ImGui.GetDragDropPayload() == nil then
								local payload_items = ImVector.new()
								if not item_is_selected then
									payload_items:push_back(item_id)
								else
									local it
									local ok, id
									ok, it, id = selection:GetNextSelectedItem(it)
									while ok do
										payload_items:push_back(id)
										ok, it, id = selection:GetNextSelectedItem(it)
									end
								end
								ImGui.SetDragDropPayload("MULTISELECT_DEMO_ITEMS", payload_items, payload_items.Size * 4)
							end

							local payload = ImGui.GetDragDropPayload()
							local payload_items = payload.Data
							local payload_count = payload.DataSize // 4
							if payload_count == 1 then
								ImGui.Text("Object %05d: %s", payload_items[1], Demo.ExampleNames[(payload_items[1] % #Demo.ExampleNames) + 1])
							else
								ImGui.Text("Dragging %d objects", payload_count)
							end

							ImGui.EndDragDropSource()
						end

						if S.adv_widget_type == WidgetType.TreeNode and item_is_open then
							ImGui.TreePop()
						end

						if ImGui.BeginPopupContextItem() then
							ImGui.BeginDisabled(not S.adv_use_deletion or selection.Size == 0)
							label = Base.ImFormatString("Delete %d item(s)###DeleteSelected", selection.Size)
							if ImGui.Selectable(label, false) then
								request_deletion_from_menu = true
							end
							ImGui.EndDisabled()
							ImGui.Selectable("Close", false)
							ImGui.EndPopup()
						end

						if S.adv_show_in_table then
							ImGui.TableNextColumn()
							ImGui.SetNextItemWidth(-FLT_MIN)
							ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0.0, 0.0))
							ImGui.InputText("##NoLabel", item_category, ImGuiInputTextFlags.ReadOnly)
							ImGui.PopStyleVar()
						end

						ImGui.PopID()
					end
					if not S.adv_use_clipper then
						break
					end
				end

				if S.adv_show_in_table then
					ImGui.EndTable()
					if S.adv_widget_type == WidgetType.TreeNode then
						ImGui.PopStyleVar()
					end
				end

				ms_io = ImGui.EndMultiSelect()
				selection:ApplyRequests(ms_io)
				if want_delete then
					selection:ApplyDeletionPostLoop(ms_io, items, item_curr_idx_to_focus)
				end

				if S.adv_widget_type == WidgetType.TreeNode then
					ImGui.PopStyleVar()
				end
			end
			ImGui.EndChild()
			S.adv_request_deletion_from_menu = request_deletion_from_menu
			ImGui.TreePop()
		end
		ImGui.TreePop()
	end
end

return true
