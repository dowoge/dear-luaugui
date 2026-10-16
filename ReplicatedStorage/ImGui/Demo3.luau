local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local FLT_MIN, FLT_MAX = Base.FLT_MIN, Base.FLT_MAX
local ImMin, ImTruncToInt = Base.ImMin, Base.ImTruncToInt
local IM_COL32, IM_COL32_WHITE = Base.IM_COL32, Base.IM_COL32_WHITE
local ImFormatString, ImPtrToInt = Base.ImFormatString, Base.ImPtrToInt
local ImColor = Structs.ImColor

local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiCol = Enums.ImGuiCol
local ImGuiCond = Enums.ImGuiCond
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiKey = Enums.ImGuiKey
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiTabBarFlags = Enums.ImGuiTabBarFlags
local ImGuiTabItemFlags = Enums.ImGuiTabItemFlags
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiWindowFlags = Enums.ImGuiWindowFlags

local Demo = ImGui._Demo

local _

local S_DemoWindowWidgetsTabs = {
	adv_tab_bar_flags = ImGuiTabBarFlags.Reorderable,
	opened = { true, true, true, true },
	active_tabs = Base.ImVector.new(),
	next_tab_id = 0,
	show_leading_button = true,
	show_trailing_button = true,
	show_leading_trailing_tabs = false,
	tbi_tab_bar_flags = bit32.bor(ImGuiTabBarFlags.AutoSelectNewTabs, ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.FittingPolicyMixed),
}

function Demo.EditTabBarFittingPolicyFlags(p_flags)
	if bit32.band(p_flags, ImGuiTabBarFlags.FittingPolicyMask_) == 0 then
		p_flags = bit32.bor(p_flags, ImGuiTabBarFlags.FittingPolicyDefault_)
	end
	local pressed
	pressed, p_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_FittingPolicyMixed", p_flags, ImGuiTabBarFlags.FittingPolicyMixed)
	if pressed then
		p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTabBarFlags.FittingPolicyMask_, ImGuiTabBarFlags.FittingPolicyMixed)))
	end
	pressed, p_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_FittingPolicyShrink", p_flags, ImGuiTabBarFlags.FittingPolicyShrink)
	if pressed then
		p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTabBarFlags.FittingPolicyMask_, ImGuiTabBarFlags.FittingPolicyShrink)))
	end
	pressed, p_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_FittingPolicyScroll", p_flags, ImGuiTabBarFlags.FittingPolicyScroll)
	if pressed then
		p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTabBarFlags.FittingPolicyMask_, ImGuiTabBarFlags.FittingPolicyScroll)))
	end
	return p_flags
end

function Demo.DemoWindowWidgetsTabs()
	if ImGui.TreeNode("Tabs") then
		if ImGui.TreeNode("Basic") then
			if ImGui.BeginTabBar("MyTabBar", ImGuiTabBarFlags.None) then
				if ImGui.BeginTabItem("Avocado") then
					ImGui.Text("This is the Avocado tab!\nblah blah blah blah blah")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Broccoli") then
					ImGui.Text("This is the Broccoli tab!\nblah blah blah blah blah")
					ImGui.EndTabItem()
				end
				if ImGui.BeginTabItem("Cucumber") then
					ImGui.Text("This is the Cucumber tab!\nblah blah blah blah blah")
					ImGui.EndTabItem()
				end
				ImGui.EndTabBar()
			end
			ImGui.Separator()
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Advanced & Close Button") then
			local S = S_DemoWindowWidgetsTabs
			_, S.adv_tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_Reorderable", S.adv_tab_bar_flags, ImGuiTabBarFlags.Reorderable)
			_, S.adv_tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_AutoSelectNewTabs", S.adv_tab_bar_flags, ImGuiTabBarFlags.AutoSelectNewTabs)
			_, S.adv_tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_TabListPopupButton", S.adv_tab_bar_flags, ImGuiTabBarFlags.TabListPopupButton)
			_, S.adv_tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_NoCloseWithMiddleMouseButton", S.adv_tab_bar_flags, ImGuiTabBarFlags.NoCloseWithMiddleMouseButton)
			_, S.adv_tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_DrawSelectedOverline", S.adv_tab_bar_flags, ImGuiTabBarFlags.DrawSelectedOverline)
			S.adv_tab_bar_flags = Demo.EditTabBarFittingPolicyFlags(S.adv_tab_bar_flags)

			ImGui.AlignTextToFramePadding()
			ImGui.Text("Opened:")
			local names = { "Artichoke", "Beetroot", "Celery", "Daikon" }
			for n = 0, #S.opened - 1 do
				ImGui.SameLine()
				_, S.opened[n + 1] = ImGui.Checkbox(names[n + 1], S.opened[n + 1])
			end

			if ImGui.BeginTabBar("MyTabBar", S.adv_tab_bar_flags) then
				for n = 0, #S.opened - 1 do
					local item_visible = false
					if S.opened[n + 1] then
						item_visible, S.opened[n + 1] = ImGui.BeginTabItem(names[n + 1], S.opened[n + 1], ImGuiTabItemFlags.None)
					end
					if item_visible then
						ImGui.Text("This is the %s tab!", names[n + 1])
						if bit32.btest(n, 1) then
							ImGui.Text("I am an odd tab.")
						end
						ImGui.EndTabItem()
					end
				end
				ImGui.EndTabBar()
			end
			ImGui.Separator()
			ImGui.TreePop()
		end

		if ImGui.TreeNode("TabItemButton & Leading/Trailing flags") then
			local S = S_DemoWindowWidgetsTabs
			if S.next_tab_id == 0 then
				for i = 0, 2 do
					S.active_tabs:push_back(S.next_tab_id)
					S.next_tab_id = S.next_tab_id + 1
				end
			end

			_, S.show_leading_button = ImGui.Checkbox("Show Leading TabItemButton()", S.show_leading_button)
			_, S.show_trailing_button = ImGui.Checkbox("Show Trailing TabItemButton()", S.show_trailing_button)
			_, S.show_leading_trailing_tabs = ImGui.Checkbox("Show Leading+Trailing TabItem()", S.show_leading_trailing_tabs)

			S.tbi_tab_bar_flags = Demo.EditTabBarFittingPolicyFlags(S.tbi_tab_bar_flags)

			if ImGui.BeginTabBar("MyTabBar", S.tbi_tab_bar_flags) then
				if S.show_leading_button then
					if ImGui.TabItemButton("?", bit32.bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.NoTooltip)) then
						ImGui.OpenPopup("MyHelpMenu")
					end
				end
				if ImGui.BeginPopup("MyHelpMenu") then
					ImGui.Selectable("Hello!")
					ImGui.EndPopup()
				end

				if S.show_leading_trailing_tabs then
					if ImGui.BeginTabItem("Leading", nil, ImGuiTabItemFlags.Leading) then
						ImGui.EndTabItem()
					end
					if ImGui.BeginTabItem("Trailing", nil, ImGuiTabItemFlags.Trailing) then
						ImGui.EndTabItem()
					end
				end

				if S.show_trailing_button then
					if ImGui.TabItemButton("+", bit32.bor(ImGuiTabItemFlags.Trailing, ImGuiTabItemFlags.NoTooltip)) then
						S.active_tabs:push_back(S.next_tab_id)
						S.next_tab_id = S.next_tab_id + 1
					end
				end

				local n = 0
				while n < S.active_tabs.Size do
					local open = true
					local name = ImFormatString("%04d", S.active_tabs[n + 1])
					local tab_visible
					tab_visible, open = ImGui.BeginTabItem(name, open, ImGuiTabItemFlags.None)
					if tab_visible then
						ImGui.Text("This is the %s tab!", name)
						ImGui.EndTabItem()
					end

					if not open then
						S.active_tabs:erase(n)
					else
						n = n + 1
					end
				end

				ImGui.EndTabBar()
			end
			ImGui.Separator()
			ImGui.TreePop()
		end
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsText = {
	custom_size = 16.0,
	custom_scale = 1.0,
	wrap_width = 200.0,
	utf8_buf = "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e",
}

function Demo.DemoWindowWidgetsText()
	if ImGui.TreeNode("Text") then
		local S = S_DemoWindowWidgetsText
		if ImGui.TreeNode("Colorful Text") then
			ImGui.TextColored(ImVec4(1.0, 0.0, 1.0, 1.0), "Pink")
			ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Yellow")
			ImGui.TextDisabled("Disabled")
			ImGui.SameLine()
			Demo.HelpMarker("The TextDisabled color is stored in ImGuiStyle.")
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Font Size") then
			local style = ImGui.GetStyle()
			local global_scale = style.FontScaleMain * style.FontScaleDpi
			ImGui.Text("style.FontScaleMain = %0.2f", style.FontScaleMain)
			ImGui.Text("style.FontScaleDpi = %0.2f", style.FontScaleDpi)
			ImGui.Text("global_scale = ~%0.2f", global_scale)
			ImGui.Text("FontSize = %0.2f", ImGui.GetFontSize())

			ImGui.SeparatorText("")
			_, S.custom_size = ImGui.SliderFloat("custom_size", S.custom_size, 10.0, 100.0, "%.0f")
			ImGui.Text("ImGui::PushFont(nullptr, custom_size);")
			ImGui.PushFont(nil, S.custom_size)
			ImGui.Text("FontSize = %.2f (== %.2f * global_scale)", ImGui.GetFontSize(), S.custom_size)
			ImGui.PopFont()

			ImGui.SeparatorText("")
			_, S.custom_scale = ImGui.SliderFloat("custom_scale", S.custom_scale, 0.5, 4.0, "%.2f")
			ImGui.Text("ImGui::PushFont(nullptr, style.FontSizeBase * custom_scale);")
			ImGui.PushFont(nil, style.FontSizeBase * S.custom_scale)
			ImGui.Text("FontSize = %.2f (== style.FontSizeBase * %.2f * global_scale)", ImGui.GetFontSize(), S.custom_scale)
			ImGui.PopFont()

			ImGui.SeparatorText("")
			for scaling = 0.5, 4.0, 0.5 do
				ImGui.PushFont(nil, style.FontSizeBase * scaling)
				ImGui.Text("FontSize = %.2f (== style.FontSizeBase * %.2f * global_scale)", ImGui.GetFontSize(), scaling)
				ImGui.PopFont()
			end

			ImGui.TreePop()
		end

		if ImGui.TreeNode("Word Wrapping") then
			ImGui.TextWrapped("This text should automatically wrap on the edge of the window. The current implementation " ..
				"for text wrapping follows simple rules suitable for English and possibly other languages.")
			ImGui.Spacing()

			_, S.wrap_width = ImGui.SliderFloat("Wrap width", S.wrap_width, -20, 600, "%.0f")

			local draw_list = ImGui.GetWindowDrawList()
			for n = 0, 1 do
				ImGui.Text("Test paragraph %d:", n)
				local pos = ImGui.GetCursorScreenPos()
				local marker_min = ImVec2(pos.x + S.wrap_width, pos.y)
				local marker_max = ImVec2(pos.x + S.wrap_width + 10, pos.y + ImGui.GetTextLineHeight())
				ImGui.PushTextWrapPos(ImGui.GetCursorPos().x + S.wrap_width)
				if n == 0 then
					ImGui.Text("The lazy dog is a good dog. This paragraph should fit within %.0f pixels. Testing a 1 character word. The quick brown fox jumps over the lazy dog.", S.wrap_width)
				else
					ImGui.Text("aaaaaaaa bbbbbbbb, c cccccccc,dddddddd. d eeeeeeee   ffffffff. gggggggg!hhhhhhhh")
				end

				draw_list:AddRect(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), IM_COL32(255, 255, 0, 255))
				draw_list:AddRectFilled(marker_min, marker_max, IM_COL32(255, 0, 255, 255))
				ImGui.PopTextWrapPos()
			end

			ImGui.TreePop()
		end

		if ImGui.TreeNode("UTF-8 Text") then
			ImGui.TextWrapped("CJK text will only appear if the font was loaded with the appropriate CJK character ranges. " ..
				"Call io.Fonts->AddFontFromFileTTF() manually to load extra character ranges. " ..
				"Read docs/FONTS.md for details.")
			ImGui.Text("Hiragana: \xe3\x81\x8b\xe3\x81\x8d\xe3\x81\x8f\xe3\x81\x91\xe3\x81\x93 (kakikukeko)")
			ImGui.Text("Kanjis: \xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e (nihongo)")
			_, S.utf8_buf = ImGui.InputText("UTF-8 input", S.utf8_buf)
			ImGui.TreePop()
		end
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsTextFilter = {
	filter = Base.ImGuiTextFilter.new(""),
}

function Demo.DemoWindowWidgetsTextFilter()
	if ImGui.TreeNode("Text Filter") then
		local S = S_DemoWindowWidgetsTextFilter
		Demo.HelpMarker("Not a widget per-se, but ImGuiTextFilter is a helper to perform simple filtering on text strings.")
		ImGui.Text("Filter usage:\n" ..
			"  \"\"         display all lines\n" ..
			"  xxx        display lines containing \"xxx\"\n" ..
			"  xxx yyy    display lines containing \"xxx\" and \"yyy\"\n" ..
			"  \"xxx yyy\"  display lines containing \"xxx yyy\"\n" ..
			"  xxx,yyy    display lines containing \"xxx\" or \"yyy\"\n" ..
			"  -xxx       hide lines containing \"xxx\"")
		ImGui.SetNextItemWidth(-FLT_MIN)
		S.filter:DrawWithHint("##Filter", "Filter (incl -excl)")
		if ImGui.BeginChild("##items", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 15), ImGuiChildFlags.FrameStyle) then
			local lines = { "aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world" }
			for _, item in ipairs(lines) do
				if S.filter:PassFilter(item) then
					ImGui.TextUnformatted(item)
				end
			end
			for _, item in ipairs(Demo.ExampleNames) do
				if S.filter:PassFilter(item) then
					ImGui.TextUnformatted(item)
				end
			end
		end
		ImGui.EndChild()
		ImGui.TreePop()
	end
end

Demo.TextFilters = {}

function Demo.TextFilters.FilterCasingSwap(data)
	if data.EventChar >= string.byte("a") and data.EventChar <= string.byte("z") then
		data.EventChar = data.EventChar - (string.byte("a") - string.byte("A"))
	elseif data.EventChar >= string.byte("A") and data.EventChar <= string.byte("Z") then
		data.EventChar = data.EventChar + (string.byte("a") - string.byte("A"))
	end
	return 0
end

function Demo.TextFilters.FilterImGuiLetters(data)
	if data.EventChar < 256 and string.find("imgui", string.char(data.EventChar), 1, true) then
		return 0
	end
	return 1
end

Demo.CompletionFuncs = {}

function Demo.CompletionFuncs.MyCallback(data)
	if data.EventFlag == ImGuiInputTextFlags.CallbackCompletion then
		data:InsertChars(data.CursorPos, "..")
	elseif data.EventFlag == ImGuiInputTextFlags.CallbackHistory then
		if data.EventKey == ImGuiKey.UpArrow then
			data:DeleteChars(0, data.BufTextLen)
			data:InsertChars(0, "Pressed Up!")
			data:SelectAll()
		elseif data.EventKey == ImGuiKey.DownArrow then
			data:DeleteChars(0, data.BufTextLen)
			data:InsertChars(0, "Pressed Down!")
			data:SelectAll()
		end
	elseif data.EventFlag == ImGuiInputTextFlags.CallbackEdit then
		local c = string.byte(data.Buf, 1) or 0
		if (c >= string.byte("a") and c <= string.byte("z")) or (c >= string.byte("A") and c <= string.byte("Z")) then
			data.Buf = string.char(bit32.bxor(c, 32)) .. string.sub(data.Buf, 2)
		end
		data.BufDirty = true

		local p_int = data.UserData
		p_int.edit_count = p_int.edit_count + 1
	end
	return 0
end

Demo.ResizeFuncs = {}

function Demo.ResizeFuncs.MyResizeCallback(data)
	if data.EventFlag == ImGuiInputTextFlags.CallbackResize then
		data.UserData.my_str = data.Buf
	end
	return 0
end

function Demo.ResizeFuncs.MyInputTextMultiline(label, holder, size, flags)
	if flags == nil then
		flags = 0
	end
	assert(not bit32.btest(flags, ImGuiInputTextFlags.CallbackResize))
	local changed
	changed, holder.my_str = ImGui.InputTextMultiline(label, holder.my_str, size, bit32.bor(flags, ImGuiInputTextFlags.CallbackResize), Demo.ResizeFuncs.MyResizeCallback, holder)
	return changed
end

local S_DemoWindowWidgetsTextInput = {
	text = "/*\n" ..
		" The Pentium F00F bug, shorthand for F0 0F C7 C8,\n" ..
		" the hexadecimal encoding of one offending instruction,\n" ..
		" more formally, the invalid operand with locked CMPXCHG8B\n" ..
		" instruction bug, is a design flaw in the majority of\n" ..
		" Intel Pentium, Pentium MMX, and Pentium OverDrive\n" ..
		" processors (all in the P5 microarchitecture).\n" ..
		"*/\n\n" ..
		"label:\n" ..
		"\tlock cmpxchg8b eax\n",
	multiline_flags = ImGuiInputTextFlags.AllowTabInput,
	filt_default = "",
	filt_decimal = "",
	filt_hex = "",
	filt_upper = "",
	filt_noblank = "",
	filt_casing = "",
	filt_imgui = "",
	comp_buf = "",
	hist_buf = "",
	edit_buf = "",
	edit_count = 0,
	password = "password123",
	my_str = "",
	resize_flags = ImGuiInputTextFlags.None,
	path_buf = "/path/to/some/folder/with/long/filename.cpp",
	eliding_flags = ImGuiInputTextFlags.ElideLeft,
	misc_buf = "",
	misc_flags = ImGuiInputTextFlags.EscapeClearsAll,
}

function Demo.DemoWindowWidgetsTextInput()
	if ImGui.TreeNode("Text Input") then
		local S = S_DemoWindowWidgetsTextInput
		if ImGui.TreeNode("Multi-line Text Input") then
			Demo.HelpMarker("You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputTextMultiline() to a dynamic string type. See misc/cpp/imgui_stdlib.h for an example. (This is not demonstrated in imgui_demo.cpp because we don't want to include <string> in here)")
			_, S.multiline_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", S.multiline_flags, ImGuiInputTextFlags.ReadOnly)
			_, S.multiline_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_WordWrap", S.multiline_flags, ImGuiInputTextFlags.WordWrap)
			ImGui.SameLine()
			Demo.HelpMarker("Feature is currently in Beta. Please read comments in imgui.h")
			_, S.multiline_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_AllowTabInput", S.multiline_flags, ImGuiInputTextFlags.AllowTabInput)
			ImGui.SameLine()
			Demo.HelpMarker("When _AllowTabInput is set, passing through the widget with Tabbing doesn't automatically activate it, in order to also cycling through subsequent widgets.")
			_, S.multiline_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_CtrlEnterForNewLine", S.multiline_flags, ImGuiInputTextFlags.CtrlEnterForNewLine)
			_, S.text = ImGui.InputTextMultiline("##source", S.text, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), S.multiline_flags)
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Filtered Text Input") then
			_, S.filt_default = ImGui.InputText("default", S.filt_default)
			_, S.filt_decimal = ImGui.InputText("decimal", S.filt_decimal, ImGuiInputTextFlags.CharsDecimal)
			_, S.filt_hex = ImGui.InputText("hexadecimal", S.filt_hex, bit32.bor(ImGuiInputTextFlags.CharsHexadecimal, ImGuiInputTextFlags.CharsUppercase))
			_, S.filt_upper = ImGui.InputText("uppercase", S.filt_upper, ImGuiInputTextFlags.CharsUppercase)
			_, S.filt_noblank = ImGui.InputText("no blank", S.filt_noblank, ImGuiInputTextFlags.CharsNoBlank)
			_, S.filt_casing = ImGui.InputText("casing swap", S.filt_casing, ImGuiInputTextFlags.CallbackCharFilter, Demo.TextFilters.FilterCasingSwap)
			_, S.filt_imgui = ImGui.InputText("\"imgui\"", S.filt_imgui, ImGuiInputTextFlags.CallbackCharFilter, Demo.TextFilters.FilterImGuiLetters)
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Password Input") then
			_, S.password = ImGui.InputText("password", S.password, ImGuiInputTextFlags.Password)
			ImGui.SameLine()
			Demo.HelpMarker("Display all characters as '*'.\nDisable clipboard cut and copy.\nDisable logging.\n")
			_, S.password = ImGui.InputTextWithHint("password (w/ hint)", "<password>", S.password, ImGuiInputTextFlags.Password)
			_, S.password = ImGui.InputText("password (clear)", S.password)
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Completion, History, Edit Callbacks") then
			_, S.comp_buf = ImGui.InputText("Completion", S.comp_buf, ImGuiInputTextFlags.CallbackCompletion, Demo.CompletionFuncs.MyCallback)
			ImGui.SameLine()
			Demo.HelpMarker("Here we append \"..\" each time Tab is pressed. " ..
				"See 'Examples>Console' for a more meaningful demonstration of using this callback.")

			_, S.hist_buf = ImGui.InputText("History", S.hist_buf, ImGuiInputTextFlags.CallbackHistory, Demo.CompletionFuncs.MyCallback)
			ImGui.SameLine()
			Demo.HelpMarker("Here we replace and select text each time Up/Down are pressed. " ..
				"See 'Examples>Console' for a more meaningful demonstration of using this callback.")

			_, S.edit_buf = ImGui.InputText("Edit", S.edit_buf, ImGuiInputTextFlags.CallbackEdit, Demo.CompletionFuncs.MyCallback, S)
			ImGui.SameLine()
			Demo.HelpMarker("Here we toggle the casing of the first character on every edit + count edits.")
			ImGui.SameLine()
			ImGui.Text("(%d)", S.edit_count)

			ImGui.TreePop()
		end

		if ImGui.TreeNode("Resize Callback") then
			Demo.HelpMarker("Using ImGuiInputTextFlags_CallbackResize to wire your custom string type to InputText().\n\n" ..
				"See misc/cpp/imgui_stdlib.h for an implementation of this for std::string.")

			_, S.resize_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_WordWrap", S.resize_flags, ImGuiInputTextFlags.WordWrap)

			Demo.ResizeFuncs.MyInputTextMultiline("##MyStr", S, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), S.resize_flags)
			ImGui.Text("Data: %p\nSize: %d\nCapacity: %d", ImPtrToInt(S), #S.my_str + 1, #S.my_str + 1)
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Eliding, Alignment") then
			_, S.eliding_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ElideLeft", S.eliding_flags, ImGuiInputTextFlags.ElideLeft)
			_, S.path_buf = ImGui.InputText("Path", S.path_buf, S.eliding_flags)
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Miscellaneous") then
			_, S.misc_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_EscapeClearsAll", S.misc_flags, ImGuiInputTextFlags.EscapeClearsAll)
			_, S.misc_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", S.misc_flags, ImGuiInputTextFlags.ReadOnly)
			_, S.misc_flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_NoUndoRedo", S.misc_flags, ImGuiInputTextFlags.NoUndoRedo)
			_, S.misc_buf = ImGui.InputText("Hello", S.misc_buf, S.misc_flags)
			ImGui.TreePop()
		end

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsTooltips = {
	arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 },
	always_on = 0,
}

function Demo.DemoWindowWidgetsTooltips()
	if ImGui.TreeNode("Tooltips") then
		local S = S_DemoWindowWidgetsTooltips
		ImGui.SeparatorText("General")

		Demo.HelpMarker("Tooltip are typically created by using a IsItemHovered() + SetTooltip() sequence.\n\n" ..
			"We provide a helper SetItemTooltip() function to perform the two with standards flags.")

		local sz = ImVec2(-FLT_MIN, 0.0)

		ImGui.Button("Basic", sz)
		ImGui.SetItemTooltip("I am a tooltip")

		ImGui.Button("Fancy", sz)
		if ImGui.BeginItemTooltip() then
			ImGui.Text("I am a fancy tooltip")
			ImGui.PlotLines("Curve", S.arr, #S.arr)
			ImGui.Text("Sin(time) = %f", math.sin(ImGui.GetTime()))
			ImGui.EndTooltip()
		end

		ImGui.SeparatorText("Always On")

		_, S.always_on = ImGui.RadioButton("Off", S.always_on, 0)
		ImGui.SameLine()
		_, S.always_on = ImGui.RadioButton("Always On (Simple)", S.always_on, 1)
		ImGui.SameLine()
		_, S.always_on = ImGui.RadioButton("Always On (Advanced)", S.always_on, 2)
		if S.always_on == 1 then
			ImGui.SetTooltip("I am following you around.")
		elseif S.always_on == 2 and ImGui.BeginTooltip() then
			ImGui.ProgressBar(math.sin(ImGui.GetTime()) * 0.5 + 0.5, ImVec2(ImGui.GetFontSize() * 25, 0.0))
			ImGui.EndTooltip()
		end

		ImGui.SeparatorText("Custom")

		Demo.HelpMarker("Passing ImGuiHoveredFlags_ForTooltip to IsItemHovered() is the preferred way to standardize " ..
			"tooltip activation details across your application. You may however decide to use custom " ..
			"flags for a specific tooltip instance.")

		ImGui.Button("Manual", sz)
		if ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
			ImGui.SetTooltip("I am a manually emitted tooltip.")
		end

		ImGui.Button("DelayNone", sz)
		if ImGui.IsItemHovered(ImGuiHoveredFlags.DelayNone) then
			ImGui.SetTooltip("I am a tooltip with no delay.")
		end

		ImGui.Button("DelayShort", sz)
		if ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.DelayShort, ImGuiHoveredFlags.NoSharedDelay)) then
			ImGui.SetTooltip("I am a tooltip with a short delay (%0.2f sec).", ImGui.GetStyle().HoverDelayShort)
		end

		ImGui.Button("DelayLong", sz)
		if ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.DelayNormal, ImGuiHoveredFlags.NoSharedDelay)) then
			ImGui.SetTooltip("I am a tooltip with a long delay (%0.2f sec).", ImGui.GetStyle().HoverDelayNormal)
		end

		ImGui.Button("Stationary", sz)
		if ImGui.IsItemHovered(ImGuiHoveredFlags.Stationary) then
			ImGui.SetTooltip("I am a tooltip requiring mouse to be stationary before activating.")
		end

		ImGui.BeginDisabled()
		ImGui.Button("Disabled item", sz)
		if ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
			ImGui.SetTooltip("I am a tooltip for a disabled item.")
		end
		ImGui.EndDisabled()

		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsTreeNodes = {
	hier_base_flags = bit32.bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DefaultOpen),
	selection_mask = 0,
	adv_base_flags = bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.SpanAvailWidth),
	align_label_with_current_x_position = false,
	use_drag_and_drop = false,
}

function Demo.DemoWindowWidgetsTreeNodes()
	if ImGui.TreeNode("Tree Nodes") then
		local S = S_DemoWindowWidgetsTreeNodes
		if ImGui.TreeNode("Basic Trees") then
			for i = 0, 4 do
				if i == 0 then
					ImGui.SetNextItemOpen(true, ImGuiCond.Once)
				end

				ImGui.PushID(i)
				if ImGui.TreeNode("", "Child %d", i) then
					ImGui.Text("blah blah")
					ImGui.SameLine()
					ImGui.SmallButton("button")
					ImGui.TreePop()
				end
				ImGui.PopID()
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Hierarchy Lines") then
			Demo.HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
			_, S.hier_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesNone", S.hier_base_flags, ImGuiTreeNodeFlags.DrawLinesNone)
			_, S.hier_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesFull", S.hier_base_flags, ImGuiTreeNodeFlags.DrawLinesFull)
			_, S.hier_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesToNodes", S.hier_base_flags, ImGuiTreeNodeFlags.DrawLinesToNodes)

			if ImGui.TreeNodeEx("Parent", S.hier_base_flags) then
				if ImGui.TreeNodeEx("Child 1", S.hier_base_flags) then
					ImGui.Button("Button for Child 1")
					ImGui.TreePop()
				end
				if ImGui.TreeNodeEx("Child 2", S.hier_base_flags) then
					ImGui.Button("Button for Child 2")
					ImGui.TreePop()
				end
				ImGui.Text("Remaining contents")
				ImGui.Text("Remaining contents")
				ImGui.TreePop()
			end

			ImGui.TreePop()
		end

		if ImGui.TreeNode("Clipping Large Trees") then
			ImGui.TextWrapped("- Using ImGuiListClipper with trees is a less easy than on arrays or grids.\n" ..
				"- Refer to 'Demo->Examples->Property Editor' for an example of how to do that.\n" ..
				"- Discuss in #3823")
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Selectable Nodes") then
			Demo.HelpMarker("Manually implemented selectable nodes.\n" ..
				"Click to select, Ctrl+Click to toggle, click on arrows or double-click to open.\n\n" ..
				"You may also use the multi-select API (see 'Demo->Widgets->Selection State & Multi-Select') for more advanced multi-selection features.")

			local node_clicked_idx = -1
			for node_n = 0, 5 do
				local flags = bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.SpanAvailWidth)
				if bit32.btest(S.selection_mask, bit32.lshift(1, node_n)) then
					flags = bit32.bor(flags, ImGuiTreeNodeFlags.Selected)
				end

				local is_open = ImGui.TreeNodeEx(node_n, flags, "Selectable Node %d", node_n)
				if ImGui.IsItemClicked() and not ImGui.IsItemToggledOpen() then
					node_clicked_idx = node_n
				end
				if is_open then
					ImGui.BulletText("<Node contents here>")
					ImGui.TreePop()
				end
			end
			if node_clicked_idx ~= -1 then
				if ImGui.GetIO().KeyCtrl then
					S.selection_mask = bit32.bxor(S.selection_mask, bit32.lshift(1, node_clicked_idx))
				else
					S.selection_mask = bit32.lshift(1, node_clicked_idx)
				end
			end
			ImGui.TreePop()
		end

		if ImGui.TreeNode("Advanced") then
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_OpenOnArrow", S.adv_base_flags, ImGuiTreeNodeFlags.OpenOnArrow)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_OpenOnDoubleClick", S.adv_base_flags, ImGuiTreeNodeFlags.OpenOnDoubleClick)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAvailWidth", S.adv_base_flags, ImGuiTreeNodeFlags.SpanAvailWidth)
			ImGui.SameLine()
			Demo.HelpMarker("Extend hit area to all available width instead of allowing more items to be laid out after the node.")
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth", S.adv_base_flags, ImGuiTreeNodeFlags.SpanFullWidth)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanLabelWidth", S.adv_base_flags, ImGuiTreeNodeFlags.SpanLabelWidth)
			ImGui.SameLine()
			Demo.HelpMarker("Reduce hit area to the text label and a bit of margin.")
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAllColumns", S.adv_base_flags, ImGuiTreeNodeFlags.SpanAllColumns)
			ImGui.SameLine()
			Demo.HelpMarker("For use in Tables only.")
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_AllowOverlap", S.adv_base_flags, ImGuiTreeNodeFlags.AllowOverlap)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_Framed", S.adv_base_flags, ImGuiTreeNodeFlags.Framed)
			ImGui.SameLine()
			Demo.HelpMarker("Draw frame with background (e.g. for CollapsingHeader)")
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_FramePadding", S.adv_base_flags, ImGuiTreeNodeFlags.FramePadding)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_NavLeftJumpsToParent", S.adv_base_flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent)

			Demo.HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesNone", S.adv_base_flags, ImGuiTreeNodeFlags.DrawLinesNone)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesFull", S.adv_base_flags, ImGuiTreeNodeFlags.DrawLinesFull)
			_, S.adv_base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesToNodes", S.adv_base_flags, ImGuiTreeNodeFlags.DrawLinesToNodes)

			_, S.align_label_with_current_x_position = ImGui.Checkbox("Align label with current X position", S.align_label_with_current_x_position)
			_, S.use_drag_and_drop = ImGui.Checkbox("Make Tree Nodes as drag & drop sources", S.use_drag_and_drop)
			if S.align_label_with_current_x_position then
				ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing())
			end

			for node_n = 0, 5 do
				local node_flags = S.adv_base_flags
				if node_n < 3 then
					local is_open = ImGui.TreeNodeEx(node_n, node_flags, "Selectable Node %d", node_n)
					if S.use_drag_and_drop and ImGui.BeginDragDropSource() then
						ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
						ImGui.Text("This is a drag and drop source")
						ImGui.EndDragDropSource()
					end
					if node_n == 2 and bit32.btest(node_flags, ImGuiTreeNodeFlags.SpanLabelWidth) then
						ImGui.SameLine()
						ImGui.SmallButton("button")
					end
					if is_open then
						ImGui.BulletText("Blah blah\nBlah Blah")
						ImGui.SameLine()
						ImGui.SmallButton("Button")
						ImGui.TreePop()
					end
				else
					node_flags = bit32.bor(node_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.NoTreePushOnOpen)
					ImGui.TreeNodeEx(node_n, node_flags, "Selectable Leaf %d", node_n)
					if S.use_drag_and_drop and ImGui.BeginDragDropSource() then
						ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
						ImGui.Text("This is a drag and drop source")
						ImGui.EndDragDropSource()
					end
				end
			end
			if S.align_label_with_current_x_position then
				ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing())
			end
			ImGui.TreePop()
		end
		ImGui.TreePop()
	end
end

local S_DemoWindowWidgetsVerticalSliders = {
	int_value = 0,
	values = { 0.0, 0.60, 0.35, 0.9, 0.70, 0.20, 0.0 },
	values2 = { 0.20, 0.80, 0.40, 0.25 },
}

function Demo.DemoWindowWidgetsVerticalSliders()
	if ImGui.TreeNode("Vertical Sliders") then
		local S = S_DemoWindowWidgetsVerticalSliders
		local style = ImGui.GetStyle()
		local slider_sz = ImVec2(ImGui.GetFrameHeight(), ImGui.GetFrameHeight() * 9)

		ImGui.PushStyleVarX(ImGuiStyleVar.ItemSpacing, ImTruncToInt(style.ItemSpacing.x * 0.5))
		ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, ImTruncToInt(slider_sz.x * 0.25))
		ImGui.PushStyleVar(ImGuiStyleVar.GrabRounding, ImTruncToInt(slider_sz.x * 0.25))
		local spacing = style.ItemSpacing.x

		_, S.int_value = ImGui.VSliderInt("##int", slider_sz, S.int_value, 0, 5)
		ImGui.SameLine()

		ImGui.PushID("set1")
		for i = 0, 6 do
			if i > 0 then
				ImGui.SameLine()
			end
			ImGui.PushID(i)
			ImGui.PushStyleColor(ImGuiCol.FrameBg, ImColor.HSV(i / 7.0, 0.5, 0.5):ToImVec4())
			ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, ImColor.HSV(i / 7.0, 0.6, 0.5):ToImVec4())
			ImGui.PushStyleColor(ImGuiCol.FrameBgActive, ImColor.HSV(i / 7.0, 0.7, 0.5):ToImVec4())
			ImGui.PushStyleColor(ImGuiCol.SliderGrab, ImColor.HSV(i / 7.0, 0.8, 0.7):ToImVec4())
			ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, ImColor.HSV(i / 7.0, 0.9, 0.9):ToImVec4())
			_, S.values[i + 1] = ImGui.VSliderFloat("##v", slider_sz, S.values[i + 1], 0.0, 1.0, "")
			if ImGui.IsItemActive() or ImGui.IsItemHovered() then
				ImGui.SetTooltip("%.3f", S.values[i + 1])
			end
			ImGui.PopStyleColor(5)
			ImGui.PopID()
		end
		ImGui.PopID()

		ImGui.SameLine()
		ImGui.PushID("set2")
		local rows = 3
		local slider_size_small = ImVec2(slider_sz.x, ImTruncToInt((slider_sz.y - (rows - 1) * spacing) / rows))
		for nx = 0, 3 do
			if nx > 0 then
				ImGui.SameLine()
			end
			ImGui.BeginGroup()
			for ny = 0, rows - 1 do
				ImGui.PushID(nx * rows + ny)
				_, S.values2[nx + 1] = ImGui.VSliderFloat("##v", slider_size_small, S.values2[nx + 1], 0.0, 1.0, "")
				if ImGui.IsItemActive() or ImGui.IsItemHovered() then
					ImGui.SetTooltip("%.3f", S.values2[nx + 1])
				end
				ImGui.PopID()
			end
			ImGui.EndGroup()
		end
		ImGui.PopID()

		ImGui.SameLine()
		ImGui.PushID("set3")
		for i = 0, 3 do
			if i > 0 then
				ImGui.SameLine()
			end
			ImGui.PushID(i)
			ImGui.PushStyleVar(ImGuiStyleVar.GrabMinSize, slider_sz.y * 0.25)
			_, S.values[i + 1] = ImGui.VSliderFloat("##v", ImVec2(slider_sz.x * 2.0, slider_sz.y), S.values[i + 1], 0.0, 1.0, "%.2f\nsec")
			ImGui.PopStyleVar()
			ImGui.PopID()
		end
		ImGui.PopID()

		ImGui.PopStyleVar(3)
		ImGui.TreePop()
	end
end

function Demo.DemoWindowWidgets(demo_data)
	if not ImGui.CollapsingHeader("Widgets") then
		return
	end

	local disable_all = demo_data.DisableSections
	local override_liveedit = demo_data.LiveEditOverride
	if disable_all then
		ImGui.BeginDisabled()
	end
	if override_liveedit then
		ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, bit32.btest(demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText))
		ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, bit32.btest(demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar))
	end

	Demo.DemoWindowWidgetsBasic()
	Demo.DemoWindowWidgetsBullets()
	Demo.DemoWindowWidgetsCollapsingHeaders()
	Demo.DemoWindowWidgetsComboBoxes()
	Demo.DemoWindowWidgetsColorAndPickers()
	Demo.DemoWindowWidgetsDataTypes()

	if disable_all then
		ImGui.EndDisabled()
	end
	Demo.DemoWindowWidgetsDisableBlocks(demo_data)
	if disable_all then
		ImGui.BeginDisabled()
	end

	Demo.DemoWindowWidgetsDragAndDrop()
	Demo.DemoWindowWidgetsDragsAndSliders()
	Demo.DemoWindowWidgetsFonts()
	Demo.DemoWindowWidgetsImages()
	Demo.DemoWindowWidgetsListBoxes()
	Demo.DemoWindowWidgetsLiveEdit(demo_data)
	Demo.DemoWindowWidgetsMixedValues()
	Demo.DemoWindowWidgetsMultiComponents()
	Demo.DemoWindowWidgetsPlotting()
	Demo.DemoWindowWidgetsProgressBars()
	Demo.DemoWindowWidgetsQueryingStatuses()
	Demo.DemoWindowWidgetsSelectables()
	Demo.DemoWindowWidgetsSelectionAndMultiSelect(demo_data)
	Demo.DemoWindowWidgetsTabs()
	Demo.DemoWindowWidgetsText()
	Demo.DemoWindowWidgetsTextFilter()
	Demo.DemoWindowWidgetsTextInput()
	Demo.DemoWindowWidgetsTooltips()
	Demo.DemoWindowWidgetsTreeNodes()
	Demo.DemoWindowWidgetsVerticalSliders()

	if override_liveedit then
		ImGui.PopItemFlag()
		ImGui.PopItemFlag()
	end
	if disable_all then
		ImGui.EndDisabled()
	end
end

local S_DemoWindowLayout = {
	disable_mouse_wheel = false,
	disable_menu = false,
	draw_lines = 3,
	max_height_in_lines = 10,
	offset_x = 0,
	override_bg_color = true,
	child_flags = bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY),
	f = 0.0,
	show_indented_items = true,
	c1 = false,
	c2 = false,
	c3 = false,
	c4 = false,
	f0 = 1.0,
	f1 = 2.0,
	f2 = 3.0,
	item = -1,
	selection = { 0, 1, 2, 3 },
	track_item = 50,
	enable_track = true,
	enable_extra_decorations = false,
	scroll_to_off_px = 0.0,
	scroll_to_pos_px = 200.0,
	lines = 7,
	show_contents_demo = false,
	show_h_scrollbar = true,
	show_button = true,
	show_tree_nodes = true,
	show_text_wrapped = false,
	show_columns = true,
	show_tab_bar = true,
	show_child = false,
	explicit_content_size = false,
	contents_size_x = 300.0,
	clip_size = { 100.0, 100.0 },
	clip_offset = { 30.0, 30.0 },
	enable_allow_overlap = true,
}

function Demo.DemoWindowLayout()
	if not ImGui.CollapsingHeader("Layout & Scrolling") then
		return
	end

	local S = S_DemoWindowLayout

	if ImGui.TreeNode("Child windows") then
		ImGui.SeparatorText("Child windows")

		Demo.HelpMarker("Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window.")
		_, S.disable_mouse_wheel = ImGui.Checkbox("Disable Mouse Wheel", S.disable_mouse_wheel)
		_, S.disable_menu = ImGui.Checkbox("Disable Menu", S.disable_menu)

		do
			local window_flags = ImGuiWindowFlags.HorizontalScrollbar
			if S.disable_mouse_wheel then
				window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollWithMouse)
			end
			ImGui.BeginChild("ChildL", ImVec2(ImGui.GetContentRegionAvail().x * 0.5, 260), ImGuiChildFlags.None, window_flags)
			for i = 0, 99 do
				ImGui.Text("%04d: scrollable region", i)
			end
			ImGui.EndChild()
		end

		ImGui.SameLine()

		do
			local window_flags = ImGuiWindowFlags.None
			if S.disable_mouse_wheel then
				window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollWithMouse)
			end
			if not S.disable_menu then
				window_flags = bit32.bor(window_flags, ImGuiWindowFlags.MenuBar)
			end
			ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, 5.0)
			ImGui.BeginChild("ChildR", ImVec2(0, 260), ImGuiChildFlags.Borders, window_flags)
			if not S.disable_menu and ImGui.BeginMenuBar() then
				if ImGui.BeginMenu("Menu") then
					Demo.ShowExampleMenuFile()
					ImGui.EndMenu()
				end
				ImGui.EndMenuBar()
			end
			if ImGui.BeginTable("split", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings)) then
				for i = 0, 99 do
					local buf = ImFormatString("%03d", i)
					ImGui.TableNextColumn()
					ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
				end
				ImGui.EndTable()
			end
			ImGui.EndChild()
			ImGui.PopStyleVar()
		end

		ImGui.SeparatorText("Manual-resize")
		do
			Demo.HelpMarker("Drag bottom border to resize. Double-click bottom border to auto-fit to vertical contents.")

			ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetStyleColorVec4(ImGuiCol.FrameBg))
			if ImGui.BeginChild("ResizableChild", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 8), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then
				for n = 0, 9 do
					ImGui.Text("Line %04d", n)
				end
			end
			ImGui.PopStyleColor()
			ImGui.EndChild()
		end

		ImGui.SeparatorText("Auto-resize with constraints")
		do
			ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
			_, S.draw_lines = ImGui.DragInt("Lines Count", S.draw_lines, 0.2)
			ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
			_, S.max_height_in_lines = ImGui.DragInt("Max Height (in Lines)", S.max_height_in_lines, 0.2)

			ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 1), ImVec2(FLT_MAX, ImGui.GetTextLineHeightWithSpacing() * S.max_height_in_lines))
			if ImGui.BeginChild("ConstrainedChild", ImVec2(-FLT_MIN, 0.0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AutoResizeY)) then
				for n = 0, S.draw_lines - 1 do
					ImGui.Text("Line %04d", n)
				end
			end
			ImGui.EndChild()
		end

		ImGui.SeparatorText("Misc/Advanced")

		do
			ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
			_, S.offset_x = ImGui.DragInt("Offset X", S.offset_x, 1.0, -1000, 1000)
			_, S.override_bg_color = ImGui.Checkbox("Override ChildBg color", S.override_bg_color)
			_, S.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_Borders", S.child_flags, ImGuiChildFlags.Borders)
			_, S.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_AlwaysUseWindowPadding", S.child_flags, ImGuiChildFlags.AlwaysUseWindowPadding)
			_, S.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_ResizeX", S.child_flags, ImGuiChildFlags.ResizeX)
			_, S.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_ResizeY", S.child_flags, ImGuiChildFlags.ResizeY)
			_, S.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_FrameStyle", S.child_flags, ImGuiChildFlags.FrameStyle)
			ImGui.SameLine()
			Demo.HelpMarker("Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.")
			if bit32.btest(S.child_flags, ImGuiChildFlags.FrameStyle) then
				S.override_bg_color = false
			end

			ImGui.SetCursorPosX(ImGui.GetCursorPosX() + S.offset_x)
			if S.override_bg_color then
				ImGui.PushStyleColor(ImGuiCol.ChildBg, IM_COL32(255, 0, 0, 100))
			end
			ImGui.BeginChild("Red", ImVec2(200, 100), S.child_flags, ImGuiWindowFlags.None)
			if S.override_bg_color then
				ImGui.PopStyleColor()
			end

			for n = 0, 49 do
				ImGui.Text("Some test %d", n)
			end
			ImGui.EndChild()
			local child_is_hovered = ImGui.IsItemHovered()
			local child_rect_min = ImGui.GetItemRectMin()
			local child_rect_max = ImGui.GetItemRectMax()
			ImGui.Text("Hovered: %d", child_is_hovered and 1 or 0)
			ImGui.Text("Rect of child window is: (%.0f,%.0f) (%.0f,%.0f)", child_rect_min.x, child_rect_min.y, child_rect_max.x, child_rect_max.y)
		end

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Widgets Width") then
		_, S.show_indented_items = ImGui.Checkbox("Show indented items", S.show_indented_items)

		ImGui.Text("SetNextItemWidth/PushItemWidth(100)")
		ImGui.SameLine()
		Demo.HelpMarker("Fixed width.")
		ImGui.PushItemWidth(100)
		_, S.f = ImGui.DragFloat("float##1b", S.f)
		if S.show_indented_items then
			ImGui.Indent()
			_, S.f = ImGui.DragFloat("float (indented)##1b", S.f)
			ImGui.Unindent()
		end
		ImGui.PopItemWidth()

		ImGui.Text("SetNextItemWidth/PushItemWidth(-100)")
		ImGui.SameLine()
		Demo.HelpMarker("Align to right edge minus 100")
		ImGui.PushItemWidth(-100)
		_, S.f = ImGui.DragFloat("float##2a", S.f)
		if S.show_indented_items then
			ImGui.Indent()
			_, S.f = ImGui.DragFloat("float (indented)##2b", S.f)
			ImGui.Unindent()
		end
		ImGui.PopItemWidth()

		ImGui.Text("SetNextItemWidth/PushItemWidth(GetContentRegionAvail().x * 0.5f)")
		ImGui.SameLine()
		Demo.HelpMarker("Half of available width.\n(~ right-cursor_pos)\n(works within a column set)")
		ImGui.PushItemWidth(ImGui.GetContentRegionAvail().x * 0.5)
		_, S.f = ImGui.DragFloat("float##3a", S.f)
		if S.show_indented_items then
			ImGui.Indent()
			_, S.f = ImGui.DragFloat("float (indented)##3b", S.f)
			ImGui.Unindent()
		end
		ImGui.PopItemWidth()

		ImGui.Text("SetNextItemWidth/PushItemWidth(-GetContentRegionAvail().x * 0.5f)")
		ImGui.SameLine()
		Demo.HelpMarker("Align to right edge minus half")
		ImGui.PushItemWidth(-ImGui.GetContentRegionAvail().x * 0.5)
		_, S.f = ImGui.DragFloat("float##4a", S.f)
		if S.show_indented_items then
			ImGui.Indent()
			_, S.f = ImGui.DragFloat("float (indented)##4b", S.f)
			ImGui.Unindent()
		end
		ImGui.PopItemWidth()

		ImGui.Text("SetNextItemWidth/PushItemWidth(-Min(GetContentRegionAvail().x * 0.40f, GetFontSize() * 12))")
		ImGui.PushItemWidth(-ImMin(ImGui.GetFontSize() * 12, ImGui.GetContentRegionAvail().x * 0.40))
		_, S.f = ImGui.DragFloat("float##5a", S.f)
		if S.show_indented_items then
			ImGui.Indent()
			_, S.f = ImGui.DragFloat("float (indented)##5b", S.f)
			ImGui.Unindent()
		end
		ImGui.PopItemWidth()

		ImGui.Text("SetNextItemWidth/PushItemWidth(-FLT_MIN)")
		ImGui.SameLine()
		Demo.HelpMarker("Align to right edge")
		ImGui.PushItemWidth(-FLT_MIN)
		_, S.f = ImGui.DragFloat("##float6a", S.f)
		if S.show_indented_items then
			ImGui.Indent()
			_, S.f = ImGui.DragFloat("float (indented)##6b", S.f)
			ImGui.Unindent()
		end
		ImGui.PopItemWidth()

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Basic Horizontal Layout") then
		ImGui.TextWrapped("(Use ImGui::SameLine() to keep adding items to the right of the preceding item)")

		ImGui.Text("Two items: Hello")
		ImGui.SameLine()
		ImGui.TextColored(ImVec4(1, 1, 0, 1), "Sailor")

		ImGui.Text("More spacing: Hello")
		ImGui.SameLine(0, 20)
		ImGui.TextColored(ImVec4(1, 1, 0, 1), "Sailor")

		ImGui.AlignTextToFramePadding()
		ImGui.Text("Normal buttons")
		ImGui.SameLine()
		ImGui.Button("Banana")
		ImGui.SameLine()
		ImGui.Button("Apple")
		ImGui.SameLine()
		ImGui.Button("Corniflower")

		ImGui.Text("Small buttons")
		ImGui.SameLine()
		ImGui.SmallButton("Like this one")
		ImGui.SameLine()
		ImGui.Text("can fit within a text block.")

		ImGui.Text("Aligned")
		ImGui.SameLine(150)
		ImGui.Text("x=150")
		ImGui.SameLine(300)
		ImGui.Text("x=300")
		ImGui.Text("Aligned")
		ImGui.SameLine(150)
		ImGui.SmallButton("x=150")
		ImGui.SameLine(300)
		ImGui.SmallButton("x=300")

		_, S.c1 = ImGui.Checkbox("My", S.c1)
		ImGui.SameLine()
		_, S.c2 = ImGui.Checkbox("Tailor", S.c2)
		ImGui.SameLine()
		_, S.c3 = ImGui.Checkbox("Is", S.c3)
		ImGui.SameLine()
		_, S.c4 = ImGui.Checkbox("Rich", S.c4)

		ImGui.PushItemWidth(ImGui.CalcTextSize("AAAAAAA").x)
		local items = { "AAAA", "BBBB", "CCCC", "DDDD" }
		_, S.item = ImGui.Combo("Combo", S.item, items, #items)
		ImGui.SameLine()
		_, S.f0 = ImGui.SliderFloat("X", S.f0, 0.0, 5.0)
		ImGui.SameLine()
		_, S.f1 = ImGui.SliderFloat("Y", S.f1, 0.0, 5.0)
		ImGui.SameLine()
		_, S.f2 = ImGui.SliderFloat("Z", S.f2, 0.0, 5.0)

		ImGui.Text("Lists:")
		for i = 0, 3 do
			if i > 0 then
				ImGui.SameLine()
			end
			ImGui.PushID(i)
			_, S.selection[i + 1] = ImGui.ListBox("", S.selection[i + 1], items, #items)
			ImGui.PopID()
		end
		ImGui.PopItemWidth()

		local button_sz = ImVec2(40, 40)
		ImGui.Button("A", button_sz)
		ImGui.SameLine()
		ImGui.Dummy(button_sz)
		ImGui.SameLine()
		ImGui.Button("B", button_sz)

		ImGui.Text("Manual wrapping:")
		local style = ImGui.GetStyle()
		local buttons_count = 20
		local window_visible_x2 = ImGui.GetCursorScreenPos().x + ImGui.GetContentRegionAvail().x
		for n = 0, buttons_count - 1 do
			ImGui.PushID(n)
			ImGui.Button("Box", button_sz)
			local last_button_x2 = ImGui.GetItemRectMax().x
			local next_button_x2 = last_button_x2 + style.ItemSpacing.x + button_sz.x
			if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
				ImGui.SameLine()
			end
			ImGui.PopID()
		end

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Groups") then
		Demo.HelpMarker("BeginGroup() basically locks the horizontal position for new line. " ..
			"EndGroup() bundles the whole group so that you can use \"item\" functions such as " ..
			"IsItemHovered()/IsItemActive() or SameLine() etc. on the whole group.")
		ImGui.BeginGroup()
		do
			ImGui.BeginGroup()
			ImGui.Button("AAA")
			ImGui.SameLine()
			ImGui.Button("BBB")
			ImGui.SameLine()
			ImGui.BeginGroup()
			ImGui.Button("CCC")
			ImGui.Button("DDD")
			ImGui.EndGroup()
			ImGui.SameLine()
			ImGui.Button("EEE")
			ImGui.EndGroup()
			ImGui.SetItemTooltip("First group hovered")
		end
		local size = ImGui.GetItemRectSize()
		local values = { 0.5, 0.20, 0.80, 0.60, 0.25 }
		ImGui.PlotHistogram("##values", values, #values, 0, nil, 0.0, 1.0, size)

		ImGui.Button("ACTION", ImVec2((size.x - ImGui.GetStyle().ItemSpacing.x) * 0.5, size.y))
		ImGui.SameLine()
		ImGui.Button("REACTION", ImVec2((size.x - ImGui.GetStyle().ItemSpacing.x) * 0.5, size.y))
		ImGui.EndGroup()
		ImGui.SameLine()

		ImGui.Button("LEVERAGE\nBUZZWORD", size)
		ImGui.SameLine()

		if ImGui.BeginListBox("List", size) then
			ImGui.Selectable("Selected", true)
			ImGui.Selectable("Not Selected", false)
			ImGui.EndListBox()
		end

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Text Baseline Alignment") then
		do
			ImGui.BulletText("Text baseline:")
			ImGui.SameLine()
			Demo.HelpMarker("This is testing the vertical alignment that gets applied on text to keep it aligned with widgets. " ..
				"Lines only composed of text or \"small\" widgets use less vertical space than lines with framed widgets.")
			ImGui.Indent()

			ImGui.Text("KO Blahblah")
			ImGui.SameLine()
			ImGui.Button("Some framed item")
			ImGui.SameLine()
			Demo.HelpMarker("Baseline of button will look misaligned with text..")

			ImGui.AlignTextToFramePadding()
			ImGui.Text("OK Blahblah")
			ImGui.SameLine()
			ImGui.Button("Some framed item##2")
			ImGui.SameLine()
			Demo.HelpMarker("We call AlignTextToFramePadding() to vertically align the text baseline by +FramePadding.y")

			ImGui.Button("TEST##1")
			ImGui.SameLine()
			ImGui.Text("TEST")
			ImGui.SameLine()
			ImGui.SmallButton("TEST##2")

			ImGui.AlignTextToFramePadding()
			ImGui.Text("Text aligned to framed item")
			ImGui.SameLine()
			ImGui.Button("Item##1")
			ImGui.SameLine()
			ImGui.Text("Item")
			ImGui.SameLine()
			ImGui.SmallButton("Item##2")
			ImGui.SameLine()
			ImGui.Button("Item##3")

			ImGui.Unindent()
		end

		ImGui.Spacing()

		do
			ImGui.BulletText("Multi-line text:")
			ImGui.Indent()
			ImGui.Text("One\nTwo\nThree")
			ImGui.SameLine()
			ImGui.Text("Hello\nWorld")
			ImGui.SameLine()
			ImGui.Text("Banana")

			ImGui.Text("Banana")
			ImGui.SameLine()
			ImGui.Text("Hello\nWorld")
			ImGui.SameLine()
			ImGui.Text("One\nTwo\nThree")

			ImGui.Button("HOP##1")
			ImGui.SameLine()
			ImGui.Text("Banana")
			ImGui.SameLine()
			ImGui.Text("Hello\nWorld")
			ImGui.SameLine()
			ImGui.Text("Banana")

			ImGui.Button("HOP##2")
			ImGui.SameLine()
			ImGui.Text("Hello\nWorld")
			ImGui.SameLine()
			ImGui.Text("Banana")
			ImGui.Unindent()
		end

		ImGui.Spacing()

		do
			ImGui.BulletText("Misc items:")
			ImGui.Indent()

			ImGui.Button("80x80", ImVec2(80, 80))
			ImGui.SameLine()
			ImGui.Button("50x50", ImVec2(50, 50))
			ImGui.SameLine()
			ImGui.Button("Button()")
			ImGui.SameLine()
			ImGui.SmallButton("SmallButton()")

			local spacing = ImGui.GetStyle().ItemInnerSpacing.x
			ImGui.Button("Button##1")
			ImGui.SameLine(0.0, spacing)
			if ImGui.TreeNodeEx("Node##1", ImGuiTreeNodeFlags.DrawLinesNone) then
				for i = 0, 5 do
					ImGui.BulletText("Item %d..", i)
				end
				ImGui.TreePop()
			end

			local padding = ImTruncToInt(ImGui.GetFontSize() * 1.20)
			ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, padding)
			ImGui.Button("Button##2")
			ImGui.PopStyleVar()
			ImGui.SameLine(0.0, spacing)
			if ImGui.TreeNodeEx("Node##2", ImGuiTreeNodeFlags.DrawLinesNone) then
				ImGui.TreePop()
			end

			ImGui.AlignTextToFramePadding()

			local node_open = ImGui.TreeNode("Node##3")
			ImGui.SameLine(0.0, spacing)
			ImGui.Button("Button##3")
			if node_open then
				for i = 0, 5 do
					ImGui.BulletText("Item %d..", i)
				end
				ImGui.TreePop()
			end

			ImGui.Button("Button##4")
			ImGui.SameLine(0.0, spacing)
			ImGui.BulletText("Bullet text")

			ImGui.AlignTextToFramePadding()
			ImGui.BulletText("Node")
			ImGui.SameLine(0.0, spacing)
			ImGui.Button("Button##5")
			ImGui.Unindent()
		end

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Scrolling") then
		Demo.HelpMarker("Use SetScrollHereY() or SetScrollFromPosY() to scroll to a given vertical position.")

		_, S.enable_extra_decorations = ImGui.Checkbox("Decoration", S.enable_extra_decorations)

		ImGui.PushItemWidth(ImGui.GetFontSize() * 10)
		local changed
		changed, S.track_item = ImGui.DragInt("##item", S.track_item, 0.25, 0, 99, "Item = %d")
		S.enable_track = S.enable_track or changed
		ImGui.SameLine()
		_, S.enable_track = ImGui.Checkbox("Track", S.enable_track)

		local scroll_to_off
		scroll_to_off, S.scroll_to_off_px = ImGui.DragFloat("##off", S.scroll_to_off_px, 1.00, 0, FLT_MAX, "+%.0f px")
		ImGui.SameLine()
		scroll_to_off = ImGui.Button("Scroll Offset") or scroll_to_off

		local scroll_to_pos
		scroll_to_pos, S.scroll_to_pos_px = ImGui.DragFloat("##pos", S.scroll_to_pos_px, 1.00, -10, FLT_MAX, "X/Y = %.0f px")
		ImGui.SameLine()
		scroll_to_pos = ImGui.Button("Scroll To Pos") or scroll_to_pos
		ImGui.PopItemWidth()

		if scroll_to_off or scroll_to_pos then
			S.enable_track = false
		end

		local style = ImGui.GetStyle()
		local child_w = (ImGui.GetContentRegionAvail().x - 4 * style.ItemSpacing.x) / 5
		if child_w < 1.0 then
			child_w = 1.0
		end
		ImGui.PushID("##VerticalScrolling")
		for i = 0, 4 do
			if i > 0 then
				ImGui.SameLine()
			end
			ImGui.BeginGroup()
			local names = { "Top", "25%", "Center", "75%", "Bottom" }
			ImGui.TextUnformatted(names[i + 1])

			local child_flags = S.enable_extra_decorations and ImGuiWindowFlags.MenuBar or 0
			local child_id = ImGui.GetID(i)
			local child_is_visible = ImGui.BeginChild(child_id, ImVec2(child_w, 200.0), ImGuiChildFlags.Borders, child_flags)
			if ImGui.BeginMenuBar() then
				ImGui.TextUnformatted("abc")
				ImGui.EndMenuBar()
			end
			if scroll_to_off then
				ImGui.SetScrollY(S.scroll_to_off_px)
			end
			if scroll_to_pos then
				ImGui.SetScrollFromPosY(ImGui.GetCursorStartPos().y + S.scroll_to_pos_px, i * 0.25)
			end
			if child_is_visible then
				for item = 0, 99 do
					if S.enable_track and item == S.track_item then
						ImGui.TextColored(ImVec4(1, 1, 0, 1), "Item %d", item)
						ImGui.SetScrollHereY(i * 0.25)
					else
						ImGui.Text("Item %d", item)
					end
				end
			end
			local scroll_y = ImGui.GetScrollY()
			local scroll_max_y = ImGui.GetScrollMaxY()
			ImGui.EndChild()
			ImGui.Text("%.0f/%.0f", scroll_y, scroll_max_y)
			ImGui.EndGroup()
		end
		ImGui.PopID()

		ImGui.Spacing()
		Demo.HelpMarker("Use SetScrollHereX() or SetScrollFromPosX() to scroll to a given horizontal position.\n\n" ..
			"Because the clipping rectangle of most window hides half worth of WindowPadding on the " ..
			"left/right, using SetScrollFromPosX(+1) will usually result in clipped text whereas the " ..
			"equivalent SetScrollFromPosY(+1) wouldn't.")
		ImGui.PushID("##HorizontalScrolling")
		for i = 0, 4 do
			local child_height = ImGui.GetTextLineHeight() + style.ScrollbarSize + style.WindowPadding.y * 2.0
			local child_flags = bit32.bor(ImGuiWindowFlags.HorizontalScrollbar, S.enable_extra_decorations and ImGuiWindowFlags.AlwaysVerticalScrollbar or 0)
			local child_id = ImGui.GetID(i)
			local child_is_visible = ImGui.BeginChild(child_id, ImVec2(-100, child_height), ImGuiChildFlags.Borders, child_flags)
			if scroll_to_off then
				ImGui.SetScrollX(S.scroll_to_off_px)
			end
			if scroll_to_pos then
				ImGui.SetScrollFromPosX(ImGui.GetCursorStartPos().x + S.scroll_to_pos_px, i * 0.25)
			end
			if child_is_visible then
				for item = 0, 99 do
					if item > 0 then
						ImGui.SameLine()
					end
					if S.enable_track and item == S.track_item then
						ImGui.TextColored(ImVec4(1, 1, 0, 1), "Item %d", item)
						ImGui.SetScrollHereX(i * 0.25)
					else
						ImGui.Text("Item %d", item)
					end
				end
			end
			local scroll_x = ImGui.GetScrollX()
			local scroll_max_x = ImGui.GetScrollMaxX()
			ImGui.EndChild()
			ImGui.SameLine()
			local names = { "Left", "25%", "Center", "75%", "Right" }
			ImGui.Text("%s\n%.0f/%.0f", names[i + 1], scroll_x, scroll_max_x)
			ImGui.Spacing()
		end
		ImGui.PopID()

		Demo.HelpMarker("Horizontal scrolling for a window is enabled via the ImGuiWindowFlags_HorizontalScrollbar flag.\n\n" ..
			"You may want to also explicitly specify content width by using SetNextWindowContentWidth() before Begin().")
		_, S.lines = ImGui.SliderInt("Lines", S.lines, 1, 15)
		ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 3.0)
		ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(2.0, 1.0))
		local scrolling_child_size = ImVec2(0, ImGui.GetFrameHeightWithSpacing() * 7 + 30)
		ImGui.BeginChild("scrolling", scrolling_child_size, ImGuiChildFlags.Borders, ImGuiWindowFlags.HorizontalScrollbar)
		for line = 0, S.lines - 1 do
			local num_buttons = 10 + (bit32.btest(line, 1) and line * 9 or line * 3)
			local base_w = ImGui.GetFontSize() * 3
			for n = 0, num_buttons - 1 do
				if n > 0 then
					ImGui.SameLine()
				end
				ImGui.PushID(n + line * 1000)
				local num_buf = ImFormatString("%d", n)
				local label = (n % 15 == 0) and "FizzBuzz" or (n % 3 == 0) and "Fizz" or (n % 5 == 0) and "Buzz" or num_buf
				local hue = n * 0.05
				ImGui.PushStyleColor(ImGuiCol.Button, ImColor.HSV(hue, 0.6, 0.6):ToImVec4())
				ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImColor.HSV(hue, 0.7, 0.7):ToImVec4())
				ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImColor.HSV(hue, 0.8, 0.8):ToImVec4())
				ImGui.Button(label, ImVec2(base_w + math.sin(line + n) * base_w * 0.5, 0.0))
				ImGui.PopStyleColor(3)
				ImGui.PopID()
			end
		end
		local scroll_x = ImGui.GetScrollX()
		local scroll_max_x = ImGui.GetScrollMaxX()
		ImGui.EndChild()
		ImGui.PopStyleVar(2)
		local scroll_x_delta = 0.0
		ImGui.SmallButton("<<")
		if ImGui.IsItemActive() then
			scroll_x_delta = -ImGui.GetIO().DeltaTime * 1000.0
		end
		ImGui.SameLine()
		ImGui.Text("Scroll from code")
		ImGui.SameLine()
		ImGui.SmallButton(">>")
		if ImGui.IsItemActive() then
			scroll_x_delta = ImGui.GetIO().DeltaTime * 1000.0
		end
		ImGui.SameLine()
		ImGui.Text("%.0f/%.0f", scroll_x, scroll_max_x)
		if scroll_x_delta ~= 0.0 then
			ImGui.BeginChild("scrolling")
			ImGui.SetScrollX(ImGui.GetScrollX() + scroll_x_delta)
			ImGui.EndChild()
		end
		ImGui.Spacing()

		_, S.show_contents_demo = ImGui.Checkbox("Show Horizontal contents size demo window", S.show_contents_demo)

		if S.show_contents_demo then
			if S.explicit_content_size then
				ImGui.SetNextWindowContentSize(ImVec2(S.contents_size_x, 0.0))
			end
			_, S.show_contents_demo = ImGui.Begin("Horizontal contents size demo window", S.show_contents_demo, S.show_h_scrollbar and ImGuiWindowFlags.HorizontalScrollbar or 0)
			ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(2, 0))
			ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(2, 0))
			Demo.HelpMarker("Test how different widgets react and impact the work rectangle growing when horizontal scrolling is enabled.\n\n" ..
				"Use 'Metrics->Tools->Show windows rectangles' to visualize rectangles.")
			_, S.show_h_scrollbar = ImGui.Checkbox("H-scrollbar", S.show_h_scrollbar)
			_, S.show_button = ImGui.Checkbox("Button", S.show_button)
			_, S.show_tree_nodes = ImGui.Checkbox("Tree nodes", S.show_tree_nodes)
			_, S.show_text_wrapped = ImGui.Checkbox("Text wrapped", S.show_text_wrapped)
			_, S.show_columns = ImGui.Checkbox("Columns", S.show_columns)
			_, S.show_tab_bar = ImGui.Checkbox("Tab bar", S.show_tab_bar)
			_, S.show_child = ImGui.Checkbox("Child", S.show_child)
			_, S.explicit_content_size = ImGui.Checkbox("Explicit content size", S.explicit_content_size)
			ImGui.Text("Scroll %.1f/%.1f %.1f/%.1f", ImGui.GetScrollX(), ImGui.GetScrollMaxX(), ImGui.GetScrollY(), ImGui.GetScrollMaxY())
			if S.explicit_content_size then
				ImGui.SameLine()
				ImGui.SetNextItemWidth(ImGui.CalcTextSize("123456").x)
				_, S.contents_size_x = ImGui.DragFloat("##csx", S.contents_size_x)
				local p = ImGui.GetCursorScreenPos()
				ImGui.GetWindowDrawList():AddRectFilled(p, ImVec2(p.x + 10, p.y + 10), IM_COL32_WHITE)
				ImGui.GetWindowDrawList():AddRectFilled(ImVec2(p.x + S.contents_size_x - 10, p.y), ImVec2(p.x + S.contents_size_x, p.y + 10), IM_COL32_WHITE)
				ImGui.Dummy(ImVec2(0, 10))
			end
			ImGui.PopStyleVar(2)
			ImGui.Separator()
			if S.show_button then
				ImGui.Button("this is a 300-wide button", ImVec2(300, 0))
			end
			if S.show_tree_nodes then
				local open = true
				if ImGui.TreeNode("this is a tree node") then
					if ImGui.TreeNode("another one of those tree node...") then
						ImGui.Text("Some tree contents")
						ImGui.TreePop()
					end
					ImGui.TreePop()
				end
				_, open = ImGui.CollapsingHeader("CollapsingHeader", open)
			end
			if S.show_text_wrapped then
				ImGui.TextWrapped("This text should automatically wrap on the edge of the work rectangle.")
			end
			if S.show_columns then
				ImGui.Text("Tables:")
				if ImGui.BeginTable("table", 4, ImGuiTableFlags.Borders) then
					for n = 0, 3 do
						ImGui.TableNextColumn()
						ImGui.Text("Width %.2f", ImGui.GetContentRegionAvail().x)
					end
					ImGui.EndTable()
				end
				ImGui.Text("Columns:")
				ImGui.Columns(4)
				for n = 0, 3 do
					ImGui.Text("Width %.2f", ImGui.GetColumnWidth())
					ImGui.NextColumn()
				end
				ImGui.Columns(1)
			end
			if S.show_tab_bar and ImGui.BeginTabBar("Hello") then
				if ImGui.BeginTabItem("OneOneOne") then ImGui.EndTabItem() end
				if ImGui.BeginTabItem("TwoTwoTwo") then ImGui.EndTabItem() end
				if ImGui.BeginTabItem("ThreeThreeThree") then ImGui.EndTabItem() end
				if ImGui.BeginTabItem("FourFourFour") then ImGui.EndTabItem() end
				ImGui.EndTabBar()
			end
			if S.show_child then
				ImGui.BeginChild("child", ImVec2(0, 0), ImGuiChildFlags.Borders)
				ImGui.EndChild()
			end
			ImGui.End()
		end

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Text Clipping") then
		ImGui.DragFloat2("size", S.clip_size, 0.5, 1.0, 200.0, "%.0f")
		ImGui.TextWrapped("(Click and drag to scroll)")

		Demo.HelpMarker("(Left) Using ImGui::PushClipRect():\n" ..
			"Will alter ImGui hit-testing logic + ImDrawList rendering.\n" ..
			"(use this if you want your clipping rectangle to affect interactions)\n\n" ..
			"(Center) Using ImDrawList::PushClipRect():\n" ..
			"Will alter ImDrawList rendering only.\n" ..
			"(use this as a shortcut if you are only using ImDrawList calls)\n\n" ..
			"(Right) Using ImDrawList::AddText() with a fine ClipRect:\n" ..
			"Will alter only this specific ImDrawList::AddText() rendering.\n" ..
			"This is often used internally to avoid altering the clipping rectangle and minimize draw calls.")

		for n = 0, 2 do
			if n > 0 then
				ImGui.SameLine()
			end

			ImGui.PushID(n)
			ImGui.InvisibleButton("##canvas", ImVec2(S.clip_size[1], S.clip_size[2]))
			if ImGui.IsItemActive() and ImGui.IsMouseDragging(ImGuiMouseButton.Left) then
				S.clip_offset[1] = S.clip_offset[1] + ImGui.GetIO().MouseDelta.x
				S.clip_offset[2] = S.clip_offset[2] + ImGui.GetIO().MouseDelta.y
			end
			ImGui.PopID()
			if not ImGui.IsItemVisible() then
				continue
			end

			local p0 = ImGui.GetItemRectMin()
			local p1 = ImGui.GetItemRectMax()
			local text_str = "Line 1 hello\nLine 2 clip me!"
			local text_pos = ImVec2(p0.x + S.clip_offset[1], p0.y + S.clip_offset[2])
			local draw_list = ImGui.GetWindowDrawList()
			if n == 0 then
				ImGui.PushClipRect(p0, p1, true)
				draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
				draw_list:AddText(text_pos, IM_COL32_WHITE, text_str)
				ImGui.PopClipRect()
			elseif n == 1 then
				draw_list:PushClipRect(p0, p1, true)
				draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
				draw_list:AddText(text_pos, IM_COL32_WHITE, text_str)
				draw_list:PopClipRect()
			elseif n == 2 then
				local clip_rect = ImVec4(p0.x, p0.y, p1.x, p1.y)
				draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
				draw_list:AddText(ImGui.GetFont(), ImGui.GetFontSize(), text_pos, IM_COL32_WHITE, text_str, nil, 0.0, clip_rect)
			end
		end

		ImGui.TreePop()
	end

	if ImGui.TreeNode("Overlap Mode") then
		Demo.HelpMarker("Hit-testing is by default performed in item submission order, which generally is perceived as 'back-to-front'.\n\n" ..
			"By using SetNextItemAllowOverlap() you can notify that an item may be overlapped by another. " ..
			"Doing so alters the hovering logic: items using AllowOverlap mode requires an extra frame to accept hovered state.")
		_, S.enable_allow_overlap = ImGui.Checkbox("Enable AllowOverlap", S.enable_allow_overlap)

		local button1_pos = ImGui.GetCursorScreenPos()
		local button2_pos = ImVec2(button1_pos.x + 50.0, button1_pos.y + 50.0)
		if S.enable_allow_overlap then
			ImGui.SetNextItemAllowOverlap()
		end
		ImGui.Button("Button 1", ImVec2(80, 80))
		ImGui.SetCursorScreenPos(button2_pos)
		ImGui.Button("Button 2", ImVec2(80, 80))

		if S.enable_allow_overlap then
			ImGui.SetNextItemAllowOverlap()
		end
		ImGui.Selectable("Some Selectable", false)
		ImGui.SameLine()
		ImGui.SmallButton("++")

		ImGui.TreePop()
	end
end

return true
