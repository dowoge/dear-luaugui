local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local Demo = ImGui._Demo

local _

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local FLT_MIN, FLT_MAX = Base.FLT_MIN, Base.FLT_MAX
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImTruncToInt = Base.ImTruncToInt
local IM_COL32 = Base.IM_COL32

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiCond = Enums.ImGuiCond
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiButtonFlags = Enums.ImGuiButtonFlags
local ImGuiMouseButton = Enums.ImGuiMouseButton
local ImGuiPopupFlags = Enums.ImGuiPopupFlags
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiTabBarFlags = Enums.ImGuiTabBarFlags
local ImGuiTabItemFlags = Enums.ImGuiTabItemFlags
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiCol = Enums.ImGuiCol
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiSortDirection = Enums.ImGuiSortDirection
local ImGuiMultiSelectFlags = Enums.ImGuiMultiSelectFlags
local ImDrawFlags = Enums.ImDrawFlags

local S_ShowExampleAppLongText = { test_type = 0, log = Base.ImGuiTextBuffer.new(), lines = 0 }
function Demo.ShowExampleAppLongText(p_open)
	local S = S_ShowExampleAppLongText
	ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver)
	local visible
	visible, p_open = ImGui.Begin("Example: Long text display", p_open)
	if not visible then
		ImGui.End()
		return p_open
	end
	local log = S.log
	ImGui.Text("Printing unusually long amount of text.")
	_, S.test_type = ImGui.Combo("Test type", S.test_type, {
		"Single call to TextUnformatted()",
		"Multiple calls to Text(), clipped",
		"Multiple calls to Text(), not clipped (slow)",
	})
	ImGui.Text("Buffer contents: %d lines, %d bytes", S.lines, log:size())
	if ImGui.Button("Clear") then
		log:clear()
		S.lines = 0
	end
	ImGui.SameLine()
	if ImGui.Button("Add 1000 lines") then
		for i = 0, 999 do
			log:appendf("%i The quick brown fox jumps over the lazy dog\n", S.lines + i)
		end
		S.lines = S.lines + 1000
	end
	ImGui.BeginChild("Log")
	if S.test_type == 0 then
		ImGui.TextUnformatted(log:c_str())
	elseif S.test_type == 1 then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		local clipper = Structs.ImGuiListClipper.new()
		clipper:Begin(S.lines)
		while clipper:Step() do
			for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
				ImGui.Text("%i The quick brown fox jumps over the lazy dog", i)
			end
		end
		ImGui.PopStyleVar()
	elseif S.test_type == 2 then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		for i = 0, S.lines - 1 do
			ImGui.Text("%i The quick brown fox jumps over the lazy dog", i)
		end
		ImGui.PopStyleVar()
	end
	ImGui.EndChild()
	ImGui.End()
	return p_open
end

local S_ShowExampleAppAutoResize = { lines = 10 }
function Demo.ShowExampleAppAutoResize(p_open)
	local S = S_ShowExampleAppAutoResize
	local visible
	visible, p_open = ImGui.Begin("Example: Auto-resizing window", p_open, ImGuiWindowFlags.AlwaysAutoResize)
	if not visible then
		ImGui.End()
		return p_open
	end
	ImGui.TextUnformatted("Window will resize every-frame to the size of its content.\nNote that you probably don't want to query the window size to\noutput your content because that would create a feedback loop.")
	_, S.lines = ImGui.SliderInt("Number of lines", S.lines, 1, 20)
	for i = 0, S.lines - 1 do
		ImGui.Text("%*sThis is line %d", i * 4, "", i)
	end
	ImGui.End()
	return p_open
end

Demo.CustomConstraints = {}

function Demo.CustomConstraints.AspectRatio(data)
	local aspect_ratio = data.UserData
	data.DesiredSize = ImVec2(data.DesiredSize.x, ImTruncToInt(data.DesiredSize.x / aspect_ratio))
end

function Demo.CustomConstraints.Square(data)
	local m = ImMax(data.DesiredSize.x, data.DesiredSize.y)
	data.DesiredSize = ImVec2(m, m)
end

function Demo.CustomConstraints.Step(data)
	local step = data.UserData
	data.DesiredSize = ImVec2(
		ImTruncToInt(data.DesiredSize.x / step + 0.5) * step,
		ImTruncToInt(data.DesiredSize.y / step + 0.5) * step
	)
end

local test_desc = {
	"Between 100x100 and 500x500",
	"At least 100x100",
	"Resize vertical + lock current width",
	"Resize horizontal + lock current height",
	"Width Between 400 and 500",
	"Height at least 400",
	"Custom: Aspect Ratio 16:9",
	"Custom: Always Square",
	"Custom: Fixed Steps (100)",
}

local S_ShowExampleAppConstrainedResize = { auto_resize = false, window_padding = true, type = 6, display_lines = 10 }
function Demo.ShowExampleAppConstrainedResize(p_open)
	local S = S_ShowExampleAppConstrainedResize
	local aspect_ratio = 16.0 / 9.0
	local fixed_step = 100.0

	if S.type == 0 then ImGui.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(500, 500)) end
	if S.type == 1 then ImGui.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(FLT_MAX, FLT_MAX)) end
	if S.type == 2 then ImGui.SetNextWindowSizeConstraints(ImVec2(-1, 0), ImVec2(-1, FLT_MAX)) end
	if S.type == 3 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, -1), ImVec2(FLT_MAX, -1)) end
	if S.type == 4 then ImGui.SetNextWindowSizeConstraints(ImVec2(400, -1), ImVec2(500, -1)) end
	if S.type == 5 then ImGui.SetNextWindowSizeConstraints(ImVec2(-1, 400), ImVec2(-1, FLT_MAX)) end
	if S.type == 6 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, FLT_MAX), Demo.CustomConstraints.AspectRatio, aspect_ratio) end
	if S.type == 7 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, FLT_MAX), Demo.CustomConstraints.Square) end
	if S.type == 8 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, FLT_MAX), Demo.CustomConstraints.Step, fixed_step) end

	if not S.window_padding then
		ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0.0, 0.0))
	end
	local window_flags = S.auto_resize and ImGuiWindowFlags.AlwaysAutoResize or 0
	local window_open
	window_open, p_open = ImGui.Begin("Example: Constrained Resize", p_open, window_flags)
	if not S.window_padding then
		ImGui.PopStyleVar()
	end
	if window_open then
		if ImGui.GetIO().KeyShift then
			local avail_size = ImGui.GetContentRegionAvail()
			local pos = ImGui.GetCursorScreenPos()
			ImGui.ColorButton("viewport", ImVec4(0.5, 0.2, 0.5, 1.0), bit32.bor(ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoDragDrop), avail_size)
			ImGui.SetCursorScreenPos(ImVec2(pos.x + 10, pos.y + 10))
			ImGui.Text("%.2f x %.2f", avail_size.x, avail_size.y)
		else
			ImGui.Text("(Hold Shift to display a dummy viewport)")
			if ImGui.Button("Set 200x200") then ImGui.SetWindowSize(ImVec2(200, 200)) end
			ImGui.SameLine()
			if ImGui.Button("Set 500x500") then ImGui.SetWindowSize(ImVec2(500, 500)) end
			ImGui.SameLine()
			if ImGui.Button("Set 800x200") then ImGui.SetWindowSize(ImVec2(800, 200)) end
			ImGui.SetNextItemWidth(ImGui.GetFontSize() * 20)
			_, S.type = ImGui.Combo("Constraint", S.type, test_desc, #test_desc)
			ImGui.SetNextItemWidth(ImGui.GetFontSize() * 20)
			_, S.display_lines = ImGui.DragInt("Lines", S.display_lines, 0.2, 1, 100)
			_, S.auto_resize = ImGui.Checkbox("Auto-resize", S.auto_resize)
			_, S.window_padding = ImGui.Checkbox("Window padding", S.window_padding)
			for i = 0, S.display_lines - 1 do
				ImGui.Text("%*sHello, sailor! Making this line long enough for the example.", i * 4, "")
			end
		end
	end
	ImGui.End()
	return p_open
end

local S_ShowExampleAppSimpleOverlay = { location = 0 }
function Demo.ShowExampleAppSimpleOverlay(p_open)
	local S = S_ShowExampleAppSimpleOverlay
	local io = ImGui.GetIO()
	local window_flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoNav)
	if S.location >= 0 then
		local PAD = 10.0
		local viewport = ImGui.GetMainViewport()
		local work_pos = viewport.WorkPos
		local work_size = viewport.WorkSize
		local right = bit32.btest(S.location, 1)
		local bottom = bit32.btest(S.location, 2)
		local window_pos = ImVec2(
			right and (work_pos.x + work_size.x - PAD) or (work_pos.x + PAD),
			bottom and (work_pos.y + work_size.y - PAD) or (work_pos.y + PAD)
		)
		local window_pos_pivot = ImVec2(right and 1.0 or 0.0, bottom and 1.0 or 0.0)
		ImGui.SetNextWindowPos(window_pos, ImGuiCond.Always, window_pos_pivot)
		window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoMove)
	elseif S.location == -2 then
		ImGui.SetNextWindowPos(ImGui.GetMainViewport():GetCenter(), ImGuiCond.Always, ImVec2(0.5, 0.5))
		window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoMove)
	end
	ImGui.SetNextWindowBgAlpha(0.35)
	local visible
	visible, p_open = ImGui.Begin("Example: Simple overlay", p_open, window_flags)
	if visible then
		ImGui.Text("Simple overlay\n(right-click to change position)")
		ImGui.Separator()
		if ImGui.IsMousePosValid() then
			ImGui.Text("Mouse Position: (%.1f,%.1f)", io.MousePos.x, io.MousePos.y)
		else
			ImGui.Text("Mouse Position: <invalid>")
		end
		if ImGui.BeginPopupContextWindow() then
			if ImGui.MenuItem("Custom", nil, S.location == -1) then S.location = -1 end
			if ImGui.MenuItem("Center", nil, S.location == -2) then S.location = -2 end
			if ImGui.MenuItem("Top-left", nil, S.location == 0) then S.location = 0 end
			if ImGui.MenuItem("Top-right", nil, S.location == 1) then S.location = 1 end
			if ImGui.MenuItem("Bottom-left", nil, S.location == 2) then S.location = 2 end
			if ImGui.MenuItem("Bottom-right", nil, S.location == 3) then S.location = 3 end
			if p_open ~= nil and ImGui.MenuItem("Close") then p_open = false end
			ImGui.EndPopup()
		end
	end
	ImGui.End()
	return p_open
end

local S_ShowExampleAppFullscreen = {
	use_work_area = true,
	flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoSavedSettings),
}
function Demo.ShowExampleAppFullscreen(p_open)
	local S = S_ShowExampleAppFullscreen
	local viewport = ImGui.GetMainViewport()
	ImGui.SetNextWindowPos(S.use_work_area and viewport.WorkPos or viewport.Pos)
	ImGui.SetNextWindowSize(S.use_work_area and viewport.WorkSize or viewport.Size)
	local visible
	visible, p_open = ImGui.Begin("Example: Fullscreen window", p_open, S.flags)
	if visible then
		_, S.use_work_area = ImGui.Checkbox("Use work area instead of main area", S.use_work_area)
		ImGui.SameLine()
		Demo.HelpMarker("Main Area = entire viewport,\nWork Area = entire viewport minus sections used by the main menu bars, task bars etc.\n\nEnable the main-menu bar in Examples menu to see the difference.")
		_, S.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoBackground", S.flags, ImGuiWindowFlags.NoBackground)
		_, S.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoDecoration", S.flags, ImGuiWindowFlags.NoDecoration)
		ImGui.Indent()
		_, S.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoTitleBar", S.flags, ImGuiWindowFlags.NoTitleBar)
		_, S.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoCollapse", S.flags, ImGuiWindowFlags.NoCollapse)
		_, S.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoScrollbar", S.flags, ImGuiWindowFlags.NoScrollbar)
		ImGui.Unindent()
		if p_open ~= nil and ImGui.Button("Close this window") then
			p_open = false
		end
	end
	ImGui.End()
	return p_open
end

function Demo.ShowExampleAppWindowTitles(p_open)
	local viewport = ImGui.GetMainViewport()
	local base_pos = viewport.Pos

	ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 100), ImGuiCond.FirstUseEver)
	ImGui.Begin("Same title as another window##1")
	ImGui.Text("This is window 1.\nMy title is the same as window 2, but my identifier is unique.")
	ImGui.End()

	ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 200), ImGuiCond.FirstUseEver)
	ImGui.Begin("Same title as another window##2")
	ImGui.Text("This is window 2.\nMy title is the same as window 1, but my identifier is unique.")
	ImGui.End()

	local idx = bit32.band(ImTruncToInt(ImGui.GetTime() / 0.25), 3)
	local buf = Base.ImFormatString("Animated title %c %d###AnimatedTitle", string.byte("|/-\\", idx + 1), ImGui.GetFrameCount())
	ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 300), ImGuiCond.FirstUseEver)
	ImGui.Begin(buf)
	ImGui.Text("This window has a changing title.")
	ImGui.End()
	return p_open
end

local S_ShowExampleAppCustomRendering = {
	sz = 42.0,
	base_rounding = 8.0,
	base_thickness = 3.0,
	animate_rounding = false,
	animate_thickness = false,
	ngon_segments = 6,
	circle_segments_override = false,
	circle_segments_override_v = 12,
	curve_segments_override = false,
	curve_segments_override_v = 8,
	colf_stroke = { 1.000, 0.384, 0.169, 1.000 },
	colf_fill = { 0.416, 0.378, 0.420, 1.000 },
	prim_stroke_flags = ImDrawFlags.None,
	prim_other_flags = ImDrawFlags.AALineEnds,
	scope_flags = nil,
	points = Base.ImVector.new(),
	scrolling = ImVec2(0.0, 0.0),
	opt_enable_grid = true,
	opt_enable_context_menu = true,
	adding_line = false,
	draw_bg = true,
	draw_fg = true,
}
function Demo.ShowExampleAppCustomRendering(p_open)
	local S = S_ShowExampleAppCustomRendering
	local visible
	visible, p_open = ImGui.Begin("Example: Custom rendering", p_open)
	if not visible then
		ImGui.End()
		return p_open
	end

	if ImGui.BeginTabBar("##TabBar") then
		if ImGui.BeginTabItem("Primitives") then
			ImGui.PushItemWidth(-ImGui.GetFontSize() * 15)
			ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, true)
			local draw_list = ImGui.GetWindowDrawList()

			ImGui.Text("Gradients")
			local gradient_size = ImVec2(ImGui.CalcItemWidth(), ImGui.GetFrameHeight())
			do
				ImGui.InvisibleButton("##gradient1", gradient_size)
				local col_a = ImGui.GetColorU32_U32(IM_COL32(0, 0, 0, 255))
				local col_b = ImGui.GetColorU32_U32(IM_COL32(255, 255, 255, 255))
				draw_list:AddRectFilledMultiColor(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), col_a, col_b, col_b, col_a)
			end
			do
				ImGui.InvisibleButton("##gradient2", gradient_size)
				local col_a = ImGui.GetColorU32_U32(IM_COL32(0, 255, 0, 255))
				local col_b = ImGui.GetColorU32_U32(IM_COL32(255, 0, 0, 255))
				draw_list:AddRectFilledMultiColor(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), col_a, col_b, col_b, col_a)
			end

			ImGui.Text("All primitives")
			_, S.sz = ImGui.DragFloat("Size", S.sz, 0.2, 0.2, 100.0, "%.0f")
			local sz = S.sz

			local rounding_anim_period = 3.0
			local rounding_wave = 1.0 - math.abs(math.fmod(ImGui.GetTime(), rounding_anim_period) * (2.0 / rounding_anim_period) - 1.0)
			local rounding = S.animate_rounding and (ImTruncToInt(rounding_wave * S.base_rounding * 10.0) / 10.0) or S.base_rounding
			_, S.base_rounding = ImGui.DragFloat("Rounding", S.base_rounding, 0.02, 0.0, 32.0, "%.1f")
			ImGui.SameLine()
			_, S.animate_rounding = ImGui.Checkbox("Animate##rounding", S.animate_rounding)
			ImGui.SameLine()
			ImGui.Text("%.2f", rounding)

			local thickness_anim_period = 5.0
			local thickness_wave = 1.0 - math.abs(math.fmod(ImGui.GetTime(), thickness_anim_period) * (2.0 / thickness_anim_period) - 1.0)
			local thickness = S.animate_thickness and thickness_wave * S.base_thickness or S.base_thickness
			_, S.base_thickness = ImGui.DragFloat("Thickness", S.base_thickness, 0.02, 0.0, 32.0, "%.02f")
			ImGui.SameLine()
			_, S.animate_thickness = ImGui.Checkbox("Animate##thickness", S.animate_thickness)
			ImGui.SameLine()
			ImGui.Text("%.2f", thickness)

			_, S.ngon_segments = ImGui.SliderInt("N-gon sides", S.ngon_segments, 3, 12)
			_, S.circle_segments_override = ImGui.Checkbox("##CircleSegmentOverride", S.circle_segments_override)
			ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
			local changed
			changed, S.circle_segments_override_v = ImGui.SliderInt("Circle segments override", S.circle_segments_override_v, 3, 30)
			S.circle_segments_override = S.circle_segments_override or changed
			_, S.curve_segments_override = ImGui.Checkbox("##CurvesSegmentOverride", S.curve_segments_override)
			ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
			changed, S.curve_segments_override_v = ImGui.SliderInt("Curves segments override", S.curve_segments_override_v, 3, 30)
			S.curve_segments_override = S.curve_segments_override or changed
			ImGui.ColorEdit4("Stroke Color", S.colf_stroke)
			ImGui.ColorEdit4("Fill Color", S.colf_fill)

			ImGui.SeparatorText("Per primitive flags (AddXXX functions)")
			_, S.prim_stroke_flags = ImGui.RadioButton("Default", S.prim_stroke_flags, ImDrawFlags.None)
			ImGui.SameLine()
			_, S.prim_stroke_flags = ImGui.RadioButton("Inside", S.prim_stroke_flags, ImDrawFlags.StrokeInside)
			ImGui.SameLine()
			_, S.prim_stroke_flags = ImGui.RadioButton("Center", S.prim_stroke_flags, ImDrawFlags.StrokeCenter)
			ImGui.SameLine()
			_, S.prim_stroke_flags = ImGui.RadioButton("CenterBiased", S.prim_stroke_flags, ImDrawFlags.StrokeCenterBiased)
			ImGui.SameLine()
			_, S.prim_stroke_flags = ImGui.RadioButton("Outside", S.prim_stroke_flags, ImDrawFlags.StrokeOutside)
			ImGui.SameLine()
			_, S.prim_stroke_flags = ImGui.RadioButton("Legacy", S.prim_stroke_flags, ImDrawFlags.StrokeLegacy)
			_, S.prim_other_flags = ImGui.CheckboxFlags("AAFill", S.prim_other_flags, ImDrawFlags.AAFill)
			ImGui.SameLine()
			_, S.prim_other_flags = ImGui.CheckboxFlags("AALines", S.prim_other_flags, ImDrawFlags.AALines)
			ImGui.SameLine()
			_, S.prim_other_flags = ImGui.CheckboxFlags("AALineEnds", S.prim_other_flags, ImDrawFlags.AALineEnds)
			ImGui.SameLine()
			_, S.prim_other_flags = ImGui.CheckboxFlags("JoinMiter", S.prim_other_flags, ImDrawFlags.JoinMiter)
			ImGui.SameLine()
			_, S.prim_other_flags = ImGui.CheckboxFlags("CapSquare", S.prim_other_flags, ImDrawFlags.CapSquare)

			if S.scope_flags == nil then
				S.scope_flags = bit32.band(draw_list.Flags, ImDrawFlags.AllowInPushScope_)
			end
			ImGui.SeparatorText("Current ImDrawList flags (e.g. PushDrawFlag function)")
			ImGui.PushID("ScopeFlags")
			_, S.scope_flags = ImGui.CheckboxFlags("AAFill", S.scope_flags, ImDrawFlags.AAFill)
			ImGui.SameLine()
			_, S.scope_flags = ImGui.CheckboxFlags("AALines", S.scope_flags, ImDrawFlags.AALines)
			ImGui.SameLine()
			_, S.scope_flags = ImGui.CheckboxFlags("AALineEnds", S.scope_flags, ImDrawFlags.AALineEnds)
			ImGui.SameLine()
			_, S.scope_flags = ImGui.CheckboxFlags("StrokeLegacy", S.scope_flags, ImDrawFlags.StrokeLegacy)
			ImGui.PopID()
			ImGui.Spacing()

			draw_list:PushDrawFlag(ImDrawFlags.AllowInPushScope_, false)
			draw_list:PushDrawFlag(S.scope_flags, true)
			local flags = bit32.bor(S.prim_stroke_flags, S.prim_other_flags)

			local start_pos = ImGui.GetCursorScreenPos()
			local pi = 3.141592
			local step = sz + 10.0
			local corners_tl_br = bit32.bor(ImDrawFlags.RoundTopLeft, ImDrawFlags.RoundBottomRight)
			local half_sz = sz * 0.5
			local circle_segments = S.circle_segments_override and S.circle_segments_override_v or 0
			local curve_segments = S.curve_segments_override and S.curve_segments_override_v or 0
			local cp3 = { ImVec2(0.0, sz * 0.6), ImVec2(sz * 0.5, -sz * 0.4), ImVec2(sz, sz) }
			local cp4 = { ImVec2(0.0, 0.0), ImVec2(sz * 1.3, sz * 0.3), ImVec2(sz - sz * 1.3, sz - sz * 0.3), ImVec2(sz, sz) }
			local concave_shape = { ImVec2(0.0, 0.0), ImVec2(0.3, 0.0), ImVec2(0.3, 0.7), ImVec2(0.7, 0.7), ImVec2(0.7, 0.0), ImVec2(1.0, 0.0), ImVec2(1.0, 1.0), ImVec2(0.0, 1.0) }
			local zigzag_shape = { ImVec2(0.0, 0.0), ImVec2(0.9, 0.0), ImVec2(1.0, 0.1), ImVec2(1.0, 0.9), ImVec2(0.9, 1.0), ImVec2(0.3, 1.0), ImVec2(0.3, 0.4), ImVec2(0.9, 0.4) }
			local rotating_square = {}
			for side = 0, 3 do
				local t = ImGui.GetTime() * 0.1 + side * pi * 0.5
				rotating_square[side + 1] = ImVec2(math.cos(t) * half_sz, math.sin(t) * half_sz)
			end

			local x = start_pos.x
			local y = start_pos.y
			for row = 0, 3 do
				x = start_pos.x
				local draw_fill = (row == 2 or row == 3)
				local draw_strokes = (row == 0 or row == 1 or row == 3)
				if draw_fill then
					local col = ImGui.ColorConvertFloat4ToU32(ImVec4(table.unpack(S.colf_fill)))
					draw_list:AddNgonFilled(ImVec2(x + half_sz, y + half_sz), half_sz, col, S.ngon_segments)
					x = x + step
					draw_list:AddCircleFilled(ImVec2(x + half_sz, y + half_sz), half_sz, col, circle_segments)
					x = x + step
					draw_list:AddEllipseFilled(ImVec2(x + half_sz, y + half_sz), ImVec2(half_sz, sz * 0.3), col, -0.3, circle_segments)
					x = x + step
					draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, 0.0, flags)
					x = x + step
					draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, flags)
					x = x + step
					draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, bit32.bor(flags, corners_tl_br))
					x = x + step
					draw_list:AddTriangleFilled(ImVec2(x + sz * 0.5, y), ImVec2(x + sz, y + sz), ImVec2(x, y + sz), col)
					x = x + step
					draw_list:AddTriangleFilled(ImVec2(x + sz * 0.2, y), ImVec2(x + sz * 0.4, y + sz), ImVec2(x, y + sz), col)
					x = x + (step - ImTruncToInt(sz * 0.6))

					for _, p in concave_shape do
						draw_list:PathLineTo(ImVec2(x + ImTruncToInt(sz * p.x), y + ImTruncToInt(sz * p.y)))
					end
					draw_list:PathFillConcave(col)
					x = x + step

					for _, p in zigzag_shape do
						draw_list:PathLineTo(ImVec2(x + ImTruncToInt(sz * p.x), y + ImTruncToInt(sz * p.y)))
					end
					draw_list:PathFillConcave(col)
					x = x + step

					draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + thickness), col)
					x = x + step
					draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + thickness, y + sz), col)
					x = x + (step - ImTruncToInt(half_sz))
					if not (draw_fill and draw_strokes) then
						local block_sz, off = 1, 0
						while block_sz < 16 and off + block_sz <= sz do
							draw_list:AddRectFilled(ImVec2(x, y + off), ImVec2(x + block_sz, y + off + block_sz), col)
							off = off + block_sz + 1
							block_sz = block_sz + 1
						end
					end
					x = x + (step - ImTruncToInt(half_sz))

					for n = 1, 4 do
						draw_list:PathLineTo(ImVec2(x + half_sz + rotating_square[n].x, y + half_sz + rotating_square[n].y))
					end
					draw_list:PathFillConvex(col, flags)
					x = x + step

					draw_list:PathArcTo(ImVec2(x + half_sz, y + half_sz), half_sz, pi * -0.5, pi * 1.1)
					draw_list:PathFillConvex(col)
					x = x + step

					draw_list:PathLineTo(ImVec2(x + cp3[1].x, y + cp3[1].y))
					draw_list:PathBezierQuadraticCurveTo(ImVec2(x + cp3[2].x, y + cp3[2].y), ImVec2(x + cp3[3].x, y + cp3[3].y), curve_segments)
					draw_list:PathFillConvex(col)
					x = x + step

					if not (draw_fill and draw_strokes) then
						draw_list:AddRectFilledMultiColor(ImVec2(x, y), ImVec2(x + sz, y + sz), IM_COL32(0, 0, 0, 255), IM_COL32(255, 0, 0, 255), IM_COL32(255, 255, 0, 255), IM_COL32(0, 255, 0, 255))
						x = x + step
					end
				end
				if draw_fill and draw_strokes then
					x = start_pos.x
				end
				if draw_strokes then
					local col = ImGui.ColorConvertFloat4ToU32(ImVec4(table.unpack(S.colf_stroke)))
					local th = (row == 0) and 1.0 or thickness
					draw_list:AddNgon(ImVec2(x + half_sz, y + half_sz), half_sz, col, S.ngon_segments, th, flags)
					x = x + step
					draw_list:AddCircle(ImVec2(x + half_sz, y + half_sz), half_sz, col, circle_segments, th, flags)
					x = x + step
					draw_list:AddEllipse(ImVec2(x + half_sz, y + half_sz), ImVec2(half_sz, sz * 0.3), col, -0.3, circle_segments, th, flags)
					x = x + step
					draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, 0.0, th, flags)
					x = x + step
					draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, th, flags)
					x = x + step
					draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, th, bit32.bor(flags, corners_tl_br))
					x = x + step
					draw_list:AddTriangle(ImVec2(x + sz * 0.5, y), ImVec2(x + sz, y + sz), ImVec2(x, y + sz), col, th, flags)
					x = x + step
					draw_list:AddTriangle(ImVec2(x + sz * 0.2, y), ImVec2(x + sz * 0.4, y + sz), ImVec2(x, y + sz), col, th, flags)
					x = x + (step - ImTruncToInt(sz * 0.6))

					for _, p in concave_shape do
						draw_list:PathLineTo(ImVec2(x + ImTruncToInt(sz * p.x), y + ImTruncToInt(sz * p.y)))
					end
					draw_list:PathStroke(col, th, bit32.bor(flags, ImDrawFlags.Closed))
					x = x + step

					for _, p in zigzag_shape do
						draw_list:PathLineTo(ImVec2(x + ImTruncToInt(sz * p.x), y + ImTruncToInt(sz * p.y)))
					end
					draw_list:PathStroke(col, th, bit32.bor(flags, ImDrawFlags.Closed))
					x = x + step

					local off = ImTruncToInt(sz * 0.4)
					draw_list:AddLineH(x, x + sz, y, col, th, flags)
					draw_list:AddLine(ImVec2(x, y + off), ImVec2(x + sz, y + off), col, th, flags)
					x = x + step
					draw_list:AddLineV(x, y, y + sz, col, th, flags)
					draw_list:AddLine(ImVec2(x + off, y + sz), ImVec2(x + off, y), col, th, flags)
					x = x + (step - ImTruncToInt(half_sz))
					if not (draw_fill and draw_strokes) then
						draw_list:AddLine(ImVec2(x, y), ImVec2(x + half_sz, y + sz), col, th, flags)
						draw_list:AddLine(ImVec2(x, y + sz), ImVec2(x + half_sz, y), col, th, flags)
					end
					x = x + (step - ImTruncToInt(half_sz))

					for n = 1, 4 do
						draw_list:PathLineTo(ImVec2(x + half_sz + rotating_square[n].x, y + half_sz + rotating_square[n].y))
					end
					draw_list:PathStroke(col, th, bit32.bor(flags, ImDrawFlags.Closed))
					x = x + step

					draw_list:PathArcTo(ImVec2(x + half_sz, y + half_sz), half_sz, pi * -0.5, pi * 1.1)
					draw_list:PathStroke(col, th, flags)
					x = x + step

					draw_list:AddBezierQuadratic(ImVec2(x + cp3[1].x, y + cp3[1].y), ImVec2(x + cp3[2].x, y + cp3[2].y), ImVec2(x + cp3[3].x, y + cp3[3].y), col, th, curve_segments, flags)
					x = x + step

					if not (draw_fill and draw_strokes) then
						draw_list:AddBezierCubic(ImVec2(x + cp4[1].x, y + cp4[1].y), ImVec2(x + cp4[2].x, y + cp4[2].y), ImVec2(x + cp4[3].x, y + cp4[3].y), ImVec2(x + cp4[4].x, y + cp4[4].y), col, th, curve_segments, flags)
						x = x + step
					end
				end
				y = y + step
			end

			ImGui.Dummy(ImVec2(step * 15.5, step * 4.0))
			draw_list:PopDrawFlag()
			draw_list:PopDrawFlag()

			ImGui.Text("ImDrawList Vector Rendering Reference:")
			ImGui.TextLinkOpenURL("https://github.com/ocornut/imgui/wiki/Draw-List")

			ImGui.PopItemFlag()
			ImGui.PopItemWidth()
			ImGui.EndTabItem()
		end

		if ImGui.BeginTabItem("Canvas") then
			_, S.opt_enable_grid = ImGui.Checkbox("Enable grid", S.opt_enable_grid)
			_, S.opt_enable_context_menu = ImGui.Checkbox("Enable context menu", S.opt_enable_context_menu)
			ImGui.Text("Mouse Left: drag to add lines,\nMouse Right: drag to scroll, click for context menu.")

			local canvas_p0 = ImGui.GetCursorScreenPos()
			local canvas_sz = ImGui.GetContentRegionAvail()
			if canvas_sz.x < 50.0 then canvas_sz = ImVec2(50.0, canvas_sz.y) end
			if canvas_sz.y < 50.0 then canvas_sz = ImVec2(canvas_sz.x, 50.0) end
			local canvas_p1 = ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y)

			local io = ImGui.GetIO()
			local draw_list = ImGui.GetWindowDrawList()
			draw_list:AddRectFilled(canvas_p0, canvas_p1, IM_COL32(50, 50, 50, 255))
			draw_list:AddRect(canvas_p0, canvas_p1, IM_COL32(255, 255, 255, 255))

			ImGui.InvisibleButton("canvas", canvas_sz, bit32.bor(ImGuiButtonFlags.MouseButtonLeft, ImGuiButtonFlags.MouseButtonRight))
			local is_hovered = ImGui.IsItemHovered()
			local is_active = ImGui.IsItemActive()
			local origin = ImVec2(canvas_p0.x + S.scrolling.x, canvas_p0.y + S.scrolling.y)
			local mouse_pos_in_canvas = ImVec2(io.MousePos.x - origin.x, io.MousePos.y - origin.y)

			if is_hovered and not S.adding_line and ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
				S.points:push_back(mouse_pos_in_canvas)
				S.points:push_back(mouse_pos_in_canvas)
				S.adding_line = true
			end
			if S.adding_line then
				S.points[S.points.Size] = mouse_pos_in_canvas
				if not ImGui.IsMouseDown(ImGuiMouseButton.Left) then
					S.adding_line = false
				end
			end

			local mouse_threshold_for_pan = S.opt_enable_context_menu and -1.0 or 0.0
			if is_active and ImGui.IsMouseDragging(ImGuiMouseButton.Right, mouse_threshold_for_pan) then
				S.scrolling = ImVec2(S.scrolling.x + io.MouseDelta.x, S.scrolling.y + io.MouseDelta.y)
			end

			local drag_delta = ImGui.GetMouseDragDelta(ImGuiMouseButton.Right)
			if S.opt_enable_context_menu and drag_delta.x == 0.0 and drag_delta.y == 0.0 then
				ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
			end
			if ImGui.BeginPopup("context") then
				if S.adding_line then
					S.points:resize(S.points.Size - 2)
				end
				S.adding_line = false
				if ImGui.MenuItem("Remove one", nil, false, S.points.Size > 0) then
					S.points:resize(S.points.Size - 2)
				end
				if ImGui.MenuItem("Remove all", nil, false, S.points.Size > 0) then
					S.points:clear()
				end
				ImGui.EndPopup()
			end

			draw_list:PushClipRect(canvas_p0, canvas_p1, true)
			if S.opt_enable_grid then
				local GRID_STEP = 64.0
				local gx = math.fmod(S.scrolling.x, GRID_STEP)
				while gx < canvas_sz.x do
					draw_list:AddLineV(canvas_p0.x + gx, canvas_p0.y, canvas_p1.y, IM_COL32(200, 200, 200, 40))
					gx = gx + GRID_STEP
				end
				local gy = math.fmod(S.scrolling.y, GRID_STEP)
				while gy < canvas_sz.y do
					draw_list:AddLineH(canvas_p0.x, canvas_p1.x, canvas_p0.y + gy, IM_COL32(200, 200, 200, 40))
					gy = gy + GRID_STEP
				end
			end
			for n = 0, S.points.Size - 1, 2 do
				draw_list:AddLine(ImVec2(origin.x + S.points[n + 1].x, origin.y + S.points[n + 1].y), ImVec2(origin.x + S.points[n + 2].x, origin.y + S.points[n + 2].y), IM_COL32(255, 255, 0, 255), 2.0)
			end
			draw_list:PopClipRect()

			ImGui.EndTabItem()
		end

		if ImGui.BeginTabItem("BG/FG draw lists") then
			_, S.draw_bg = ImGui.Checkbox("Draw in Background draw list", S.draw_bg)
			ImGui.SameLine()
			Demo.HelpMarker("The Background draw list will be rendered below every Dear ImGui windows.")
			_, S.draw_fg = ImGui.Checkbox("Draw in Foreground draw list", S.draw_fg)
			ImGui.SameLine()
			Demo.HelpMarker("The Foreground draw list will be rendered over every Dear ImGui windows.")
			local window_pos = ImGui.GetWindowPos()
			local window_size = ImGui.GetWindowSize()
			local window_center = ImVec2(window_pos.x + window_size.x * 0.5, window_pos.y + window_size.y * 0.5)
			if S.draw_bg then
				ImGui.GetBackgroundDrawList():AddCircle(window_center, window_size.x * 0.6, IM_COL32(255, 0, 0, 200), 0, 10 + 4)
			end
			if S.draw_fg then
				ImGui.GetForegroundDrawList():AddCircle(window_center, window_size.y * 0.6, IM_COL32(0, 255, 0, 200), 0, 10)
			end
			ImGui.EndTabItem()
		end

		if ImGui.BeginTabItem("Draw Channels") then
			local draw_list = ImGui.GetWindowDrawList()
			do
				ImGui.Text("Blue shape is drawn first: appears in back")
				ImGui.Text("Red shape is drawn after: appears in front")
				local p0 = ImGui.GetCursorScreenPos()
				draw_list:AddRectFilled(p0, ImVec2(p0.x + 50, p0.y + 50), IM_COL32(0, 0, 255, 255))
				draw_list:AddRectFilled(ImVec2(p0.x + 25, p0.y + 25), ImVec2(p0.x + 75, p0.y + 75), IM_COL32(255, 0, 0, 255))
				ImGui.Dummy(ImVec2(75, 75))
			end
			ImGui.Separator()
			do
				ImGui.Text("Blue shape is drawn first, into channel 1: appears in front")
				ImGui.Text("Red shape is drawn after, into channel 0: appears in back")
				local p1 = ImGui.GetCursorScreenPos()
				draw_list:ChannelsSplit(2)
				draw_list:ChannelsSetCurrent(1)
				draw_list:AddRectFilled(p1, ImVec2(p1.x + 50, p1.y + 50), IM_COL32(0, 0, 255, 255))
				draw_list:ChannelsSetCurrent(0)
				draw_list:AddRectFilled(ImVec2(p1.x + 25, p1.y + 25), ImVec2(p1.x + 75, p1.y + 75), IM_COL32(255, 0, 0, 255))
				draw_list:ChannelsMerge()
				ImGui.Dummy(ImVec2(75, 75))
				ImGui.Text("After reordering, contents of channel 0 appears below channel 1.")
			end
			ImGui.EndTabItem()
		end

		ImGui.EndTabBar()
	end

	ImGui.End()
	return p_open
end

local MyDocument = {}
MyDocument.__index = MyDocument

function MyDocument.new(uid, name, open, color)
	if open == nil then open = true end
	if color == nil then color = ImVec4(1.0, 1.0, 1.0, 1.0) end
	local self = setmetatable({}, MyDocument)
	self.UID = uid
	self.Name = string.sub(name, 1, 31)
	self.Open = open
	self.OpenPrev = open
	self.Dirty = false
	self.Color = color
	return self
end

function MyDocument:DoOpen()
	self.Open = true
end

function MyDocument:DoForceClose()
	self.Open = false
	self.Dirty = false
end

function MyDocument:DoSave()
	self.Dirty = false
end

Demo.MyDocument = MyDocument

local ExampleAppDocuments = {}
ExampleAppDocuments.__index = ExampleAppDocuments

function ExampleAppDocuments.new()
	local self = setmetatable({}, ExampleAppDocuments)
	self.Documents = Base.ImVector.new()
	self.CloseQueue = Base.ImVector.new()
	self.RenamingDoc = nil
	self.RenamingStarted = false
	self.Documents:push_back(MyDocument.new(0, "Lettuce", true, ImVec4(0.4, 0.8, 0.4, 1.0)))
	self.Documents:push_back(MyDocument.new(1, "Eggplant", true, ImVec4(0.8, 0.5, 1.0, 1.0)))
	self.Documents:push_back(MyDocument.new(2, "Carrot", true, ImVec4(1.0, 0.8, 0.5, 1.0)))
	self.Documents:push_back(MyDocument.new(3, "Tomato", false, ImVec4(1.0, 0.3, 0.4, 1.0)))
	self.Documents:push_back(MyDocument.new(4, "A Rather Long Title", false, ImVec4(0.4, 0.8, 0.8, 1.0)))
	self.Documents:push_back(MyDocument.new(5, "Some Document", false, ImVec4(0.8, 0.8, 1.0, 1.0)))
	return self
end

function ExampleAppDocuments:GetTabName(doc)
	return Base.ImFormatString("%s###doc%d", doc.Name, doc.UID)
end

function ExampleAppDocuments:DisplayDocContents(doc)
	ImGui.PushID(doc)
	ImGui.Text("Document \"%s\"", doc.Name)
	ImGui.PushStyleColor(ImGuiCol.Text, doc.Color)
	ImGui.TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
	ImGui.PopStyleColor()

	ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.R), ImGuiInputFlags.Tooltip)
	if ImGui.Button("Rename..") then
		self.RenamingDoc = doc
		self.RenamingStarted = true
	end
	ImGui.SameLine()

	ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.M), ImGuiInputFlags.Tooltip)
	if ImGui.Button("Modify") then
		doc.Dirty = true
	end

	ImGui.SameLine()
	ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.S), ImGuiInputFlags.Tooltip)
	if ImGui.Button("Save") then
		doc:DoSave()
	end

	ImGui.SameLine()
	ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.W), ImGuiInputFlags.Tooltip)
	if ImGui.Button("Close") then
		self.CloseQueue:push_back(doc)
	end
	local col = { doc.Color.x, doc.Color.y, doc.Color.z }
	ImGui.ColorEdit3("color", col)
	doc.Color = ImVec4(col[1], col[2], col[3], doc.Color.w)
	ImGui.PopID()
end

function ExampleAppDocuments:DisplayDocContextMenu(doc)
	if not ImGui.BeginPopupContextItem() then
		return
	end

	local buf = Base.ImFormatString("Save %s", doc.Name)
	if ImGui.MenuItem(buf, "Ctrl+S", false, doc.Open) then
		doc:DoSave()
	end
	if ImGui.MenuItem("Rename...", "Ctrl+R", false, doc.Open) then
		self.RenamingDoc = doc
	end
	if ImGui.MenuItem("Close", "Ctrl+W", false, doc.Open) then
		self.CloseQueue:push_back(doc)
	end
	ImGui.EndPopup()
end

function ExampleAppDocuments:NotifyOfDocumentsClosedElsewhere()
	for i = 0, self.Documents.Size - 1 do
		local doc = self.Documents[i + 1]
		if not doc.Open and doc.OpenPrev then
			ImGui.SetTabItemClosed(doc.Name)
		end
		doc.OpenPrev = doc.Open
	end
end

Demo.ExampleAppDocuments = ExampleAppDocuments

local S_ShowExampleAppDocuments = {
	app = nil,
	opt_reorderable = true,
	opt_fitting_flags = ImGuiTabBarFlags.FittingPolicyDefault_,
}
function Demo.ShowExampleAppDocuments(p_open)
	local S = S_ShowExampleAppDocuments
	if S.app == nil then
		S.app = ExampleAppDocuments.new()
	end
	local app = S.app

	local visible
	visible, p_open = ImGui.Begin("Example: Documents", p_open, ImGuiWindowFlags.MenuBar)
	if not visible then
		ImGui.End()
		return p_open
	end

	if ImGui.BeginMenuBar() then
		if ImGui.BeginMenu("File") then
			local open_count = 0
			for i = 0, app.Documents.Size - 1 do
				open_count = open_count + (app.Documents[i + 1].Open and 1 or 0)
			end

			if ImGui.BeginMenu("Open", open_count < app.Documents.Size) then
				for i = 0, app.Documents.Size - 1 do
					local doc = app.Documents[i + 1]
					if not doc.Open and ImGui.MenuItem(doc.Name) then
						doc:DoOpen()
					end
				end
				ImGui.EndMenu()
			end
			if ImGui.MenuItem("Close All Documents", nil, false, open_count > 0) then
				for i = 0, app.Documents.Size - 1 do
					app.CloseQueue:push_back(app.Documents[i + 1])
				end
			end
			if ImGui.MenuItem("Exit") and p_open ~= nil then
				p_open = false
			end
			ImGui.EndMenu()
		end
		ImGui.EndMenuBar()
	end

	for doc_n = 0, app.Documents.Size - 1 do
		local doc = app.Documents[doc_n + 1]
		if doc_n > 0 then
			ImGui.SameLine()
		end
		ImGui.PushID(doc)
		local changed
		changed, doc.Open = ImGui.Checkbox(doc.Name, doc.Open)
		if changed and not doc.Open then
			doc:DoForceClose()
		end
		ImGui.PopID()
	end

	ImGui.Separator()

	do
		local tab_bar_flags = bit32.bor(S.opt_fitting_flags, S.opt_reorderable and ImGuiTabBarFlags.Reorderable or 0)
		tab_bar_flags = bit32.bor(tab_bar_flags, ImGuiTabBarFlags.DrawSelectedOverline)
		if ImGui.BeginTabBar("##tabs", tab_bar_flags) then
			if S.opt_reorderable then
				app:NotifyOfDocumentsClosedElsewhere()
			end

			for i = 0, app.Documents.Size - 1 do
				local doc = app.Documents[i + 1]
				if doc.Open then
					local doc_name_buf = app:GetTabName(doc)
					local tab_flags = doc.Dirty and ImGuiTabItemFlags.UnsavedDocument or 0
					local tab_visible
					tab_visible, doc.Open = ImGui.BeginTabItem(doc_name_buf, doc.Open, tab_flags)

					if not doc.Open and doc.Dirty then
						doc.Open = true
						app.CloseQueue:push_back(doc)
					end

					app:DisplayDocContextMenu(doc)
					if tab_visible then
						app:DisplayDocContents(doc)
						ImGui.EndTabItem()
					end
				end
			end

			ImGui.EndTabBar()
		end
	end

	if app.RenamingDoc ~= nil then
		if app.RenamingStarted then
			ImGui.OpenPopup("Rename")
		end
		if ImGui.BeginPopup("Rename") then
			ImGui.SetNextItemWidth(ImGui.GetFontSize() * 30)
			local changed, name = ImGui.InputText("###Name", app.RenamingDoc.Name, ImGuiInputTextFlags.EnterReturnsTrue)
			app.RenamingDoc.Name = string.sub(name, 1, 31)
			if changed then
				ImGui.CloseCurrentPopup()
				app.RenamingDoc = nil
			end
			if app.RenamingStarted then
				ImGui.SetKeyboardFocusHere(-1)
			end
			ImGui.EndPopup()
		else
			app.RenamingDoc = nil
		end
		app.RenamingStarted = false
	end

	if not app.CloseQueue:empty() then
		local close_queue_unsaved_documents = 0
		for n = 0, app.CloseQueue.Size - 1 do
			if app.CloseQueue[n + 1].Dirty then
				close_queue_unsaved_documents = close_queue_unsaved_documents + 1
			end
		end

		if close_queue_unsaved_documents == 0 then
			for n = 0, app.CloseQueue.Size - 1 do
				app.CloseQueue[n + 1]:DoForceClose()
			end
			app.CloseQueue:clear()
		else
			if not ImGui.IsPopupOpen("Save?") then
				ImGui.OpenPopup("Save?")
			end
			if ImGui.BeginPopupModal("Save?", nil, ImGuiWindowFlags.AlwaysAutoResize) then
				ImGui.Text("Save change to the following items?")
				local item_height = ImGui.GetTextLineHeightWithSpacing()
				if ImGui.BeginChild(ImGui.GetID("frame"), ImVec2(-FLT_MIN, 6.25 * item_height), ImGuiChildFlags.FrameStyle) then
					for i = 0, app.CloseQueue.Size - 1 do
						local doc = app.CloseQueue[i + 1]
						if doc.Dirty then
							ImGui.Text("%s", doc.Name)
						end
					end
				end
				ImGui.EndChild()

				local button_size = ImVec2(ImGui.GetFontSize() * 7.0, 0.0)
				if ImGui.Button("Yes", button_size) then
					for i = 0, app.CloseQueue.Size - 1 do
						local doc = app.CloseQueue[i + 1]
						if doc.Dirty then
							doc:DoSave()
						end
						doc:DoForceClose()
					end
					app.CloseQueue:clear()
					ImGui.CloseCurrentPopup()
				end
				ImGui.SameLine()
				if ImGui.Button("No", button_size) then
					for i = 0, app.CloseQueue.Size - 1 do
						app.CloseQueue[i + 1]:DoForceClose()
					end
					app.CloseQueue:clear()
					ImGui.CloseCurrentPopup()
				end
				ImGui.SameLine()
				if ImGui.Button("Cancel", button_size) then
					app.CloseQueue:clear()
					ImGui.CloseCurrentPopup()
				end
				ImGui.EndPopup()
			end
		end
	end

	ImGui.End()
	return p_open
end

local ExampleAsset = {}
ExampleAsset.__index = ExampleAsset
ExampleAsset.s_current_sort_specs = nil

function ExampleAsset.new(id, asset_type)
	return setmetatable({ ID = id, Type = asset_type }, ExampleAsset)
end

function ExampleAsset.SortWithSortSpecs(sort_specs, items, items_count)
	ExampleAsset.s_current_sort_specs = sort_specs
	if items_count > 1 then
		table.sort(items, function(lhs, rhs)
			return ExampleAsset.CompareWithSortSpecs(lhs, rhs) < 0
		end)
	end
	ExampleAsset.s_current_sort_specs = nil
end

function ExampleAsset.CompareWithSortSpecs(lhs, rhs)
	local sort_specs = ExampleAsset.s_current_sort_specs
	for n = 0, sort_specs.SpecsCount - 1 do
		local sort_spec = sort_specs.Specs[n + 1]
		local delta = 0
		if sort_spec.ColumnIndex == 0 then
			delta = lhs.ID - rhs.ID
		elseif sort_spec.ColumnIndex == 1 then
			delta = lhs.Type - rhs.Type
		end
		if delta > 0 then
			return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and 1 or -1
		end
		if delta < 0 then
			return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and -1 or 1
		end
	end
	return lhs.ID - rhs.ID
end

Demo.ExampleAsset = ExampleAsset

local ExampleAssetsBrowser = {}
ExampleAssetsBrowser.__index = ExampleAssetsBrowser

function ExampleAssetsBrowser.new()
	local self = setmetatable({}, ExampleAssetsBrowser)
	self.ShowTypeOverlay = true
	self.AllowSorting = true
	self.AllowBoxSelect = true
	self.AllowBoxSelectInsideSelection = false
	self.AllowDragUnselected = false
	self.IconSize = 0
	self.IconSpacing = 10
	self.IconHitSpacing = 4
	self.StretchSpacing = true
	self.UseScrollX = false
	self.Items = Base.ImVector.new()
	self.Selection = Demo.ExampleSelectionWithDeletion.new()
	self.NextItemId = 0
	self.RequestDelete = false
	self.RequestSort = false
	self.ZoomWheelAccum = 0.0
	self.LayoutItemSize = ImVec2(0.0, 0.0)
	self.LayoutItemStep = ImVec2(0.0, 0.0)
	self.LayoutItemSpacing = 0.0
	self.LayoutSelectableSpacing = 0.0
	self.LayoutOuterPadding = 0.0
	self.LayoutColumnCount = 0
	self.LayoutLineCount = 0
	self:AddItems(10000)
	return self
end

function ExampleAssetsBrowser:AddItems(count)
	if self.Items.Size == 0 then
		self.NextItemId = 0
	end
	self.Items:reserve(self.Items.Size + count)
	for _ = 1, count do
		local asset_type = ((self.NextItemId % 20) < 15) and 0 or (((self.NextItemId % 20) < 18) and 1 or 2)
		self.Items:push_back(ExampleAsset.new(self.NextItemId, asset_type))
		self.NextItemId = self.NextItemId + 1
	end
	self.RequestSort = true
end

function ExampleAssetsBrowser:ClearItems()
	self.Items:clear()
	self.Selection:Clear()
end

function ExampleAssetsBrowser:UpdateLayoutSizes(avail_width)
	self.LayoutItemSpacing = self.IconSpacing
	if self.StretchSpacing == false then
		avail_width = avail_width + math.floor(self.LayoutItemSpacing * 0.5)
	end

	self.LayoutItemSize = ImVec2(math.floor(self.IconSize), math.floor(self.IconSize))
	self.LayoutColumnCount = ImMax(ImTruncToInt(avail_width / (self.LayoutItemSize.x + self.LayoutItemSpacing)), 1)

	if self.StretchSpacing and self.LayoutColumnCount > 1 then
		self.LayoutItemSpacing = math.floor(avail_width - self.LayoutItemSize.x * self.LayoutColumnCount) / self.LayoutColumnCount
	end

	if self.UseScrollX then
		self.LayoutColumnCount = self.LayoutColumnCount * 2
	end
	self.LayoutLineCount = (self.Items.Size + self.LayoutColumnCount - 1) // self.LayoutColumnCount

	self.LayoutItemStep = ImVec2(self.LayoutItemSize.x + self.LayoutItemSpacing, self.LayoutItemSize.y + self.LayoutItemSpacing)
	self.LayoutSelectableSpacing = ImMax(math.floor(self.LayoutItemSpacing) - self.IconHitSpacing, 0.0)
	self.LayoutOuterPadding = math.floor(self.LayoutItemSpacing * 0.5)
end

function ExampleAssetsBrowser:Draw(title, p_open)
	if self.IconSize <= 0.0 then
		self.IconSize = ImGui.CalcTextSize("99999").x
	end

	ImGui.SetNextWindowSize(ImVec2(self.IconSize * 25, self.IconSize * 15), ImGuiCond.FirstUseEver)
	local visible
	visible, p_open = ImGui.Begin(title, p_open, ImGuiWindowFlags.MenuBar)
	if not visible then
		ImGui.End()
		return p_open
	end

	if ImGui.BeginMenuBar() then
		if ImGui.BeginMenu("File") then
			if ImGui.MenuItem("Add 10000 items") then
				self:AddItems(10000)
			end
			if ImGui.MenuItem("Clear items") then
				self:ClearItems()
			end
			ImGui.Separator()
			if ImGui.MenuItem("Close", nil, false, p_open ~= nil) then
				p_open = false
			end
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Edit") then
			if ImGui.MenuItem("Delete", "Del", false, self.Selection.Size > 0) then
				self.RequestDelete = true
			end
			ImGui.EndMenu()
		end
		if ImGui.BeginMenu("Options") then
			ImGui.PushItemWidth(ImGui.GetFontSize() * 10)

			ImGui.SeparatorText("Contents")
			_, self.ShowTypeOverlay = ImGui.Checkbox("Show Type Overlay", self.ShowTypeOverlay)
			_, self.AllowSorting = ImGui.Checkbox("Allow Sorting", self.AllowSorting)

			ImGui.SeparatorText("Selection Behavior")
			_, self.AllowBoxSelect = ImGui.Checkbox("Allow box-selection", self.AllowBoxSelect)
			local changed
			changed, self.AllowBoxSelectInsideSelection = ImGui.Checkbox("Allow box-selection from selected items", self.AllowBoxSelectInsideSelection)
			if changed and self.AllowBoxSelectInsideSelection then
				self.AllowDragUnselected = false
			end
			changed, self.AllowDragUnselected = ImGui.Checkbox("Allow dragging unselected item", self.AllowDragUnselected)
			if changed and self.AllowDragUnselected then
				self.AllowBoxSelectInsideSelection = false
			end

			ImGui.SeparatorText("Layout")
			_, self.IconSize = ImGui.SliderFloat("Icon Size", self.IconSize, 16.0, 128.0, "%.0f")
			ImGui.SameLine()
			Demo.HelpMarker("Use Ctrl+Wheel to zoom")
			_, self.IconSpacing = ImGui.SliderInt("Icon Spacing", self.IconSpacing, 0, 32)
			_, self.IconHitSpacing = ImGui.SliderInt("Icon Hit Spacing", self.IconHitSpacing, 0, 32)
			_, self.StretchSpacing = ImGui.Checkbox("Stretch Spacing", self.StretchSpacing)
			_, self.UseScrollX = ImGui.Checkbox("Use ScrollX", self.UseScrollX)
			ImGui.PopItemWidth()
			ImGui.EndMenu()
		end
		ImGui.EndMenuBar()
	end

	if self.AllowSorting then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		local table_flags_for_sort_specs = bit32.bor(ImGuiTableFlags.Sortable, ImGuiTableFlags.SortMulti, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Borders)
		if ImGui.BeginTable("for_sort_specs_only", 2, table_flags_for_sort_specs, ImVec2(0.0, ImGui.GetFrameHeight())) then
			ImGui.TableSetupColumn("Index")
			ImGui.TableSetupColumn("Type")
			ImGui.TableHeadersRow()
			local sort_specs = ImGui.TableGetSortSpecs()
			if sort_specs then
				if sort_specs.SpecsDirty or self.RequestSort then
					ExampleAsset.SortWithSortSpecs(sort_specs, self.Items, self.Items.Size)
					sort_specs.SpecsDirty = false
					self.RequestSort = false
				end
			end
			ImGui.EndTable()
		end
		ImGui.PopStyleVar()
	end

	local io = ImGui.GetIO()
	ImGui.SetNextWindowContentSize(ImVec2(0.0, self.LayoutOuterPadding + self.LayoutLineCount * (self.LayoutItemSize.y + self.LayoutItemSpacing)))
	if ImGui.BeginChild("Assets", ImVec2(0.0, -ImGui.GetTextLineHeightWithSpacing()), ImGuiChildFlags.Borders, bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.HorizontalScrollbar)) then
		local draw_list = ImGui.GetWindowDrawList()

		local avail_width = ImGui.GetContentRegionAvail().x
		self:UpdateLayoutSizes(avail_width)

		local start_pos = ImGui.GetCursorScreenPos()
		start_pos = ImVec2(start_pos.x + self.LayoutOuterPadding, start_pos.y + self.LayoutOuterPadding)
		ImGui.SetCursorScreenPos(start_pos)

		local ms_flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.ClearOnClickVoid)
		if self.AllowBoxSelect then
			ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.BoxSelect2d)
		end
		if self.AllowDragUnselected then
			ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.SelectOnClickRelease)
		elseif self.AllowBoxSelectInsideSelection then
			ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.SelectOnClickAlways)
		end
		ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.NavWrapX)

		local ms_io = ImGui.BeginMultiSelect(ms_flags, self.Selection.Size, self.Items.Size)

		self.Selection.UserData = self
		self.Selection.AdapterIndexToStorageId = function(self_, idx)
			return self_.UserData.Items[idx + 1].ID
		end
		self.Selection:ApplyRequests(ms_io)

		local want_delete = (ImGui.Shortcut(ImGuiKey.Delete, ImGuiInputFlags.Repeat) and (self.Selection.Size > 0)) or self.RequestDelete
		local item_curr_idx_to_focus = -1
		if want_delete then
			item_curr_idx_to_focus = self.Selection:ApplyDeletionPreLoop(ms_io, self.Items.Size)
		end
		self.RequestDelete = false

		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(self.LayoutSelectableSpacing, self.LayoutSelectableSpacing))

		local icon_type_overlay_colors = { 0, IM_COL32(200, 70, 70, 255), IM_COL32(70, 170, 70, 255) }
		local icon_bg_color = ImGui.GetColorU32_U32(IM_COL32(35, 35, 35, 220))
		local icon_type_overlay_size = ImVec2(4.0, 4.0)
		local display_label = (self.LayoutItemSize.x >= ImGui.CalcTextSize("999").x)

		local column_count = self.LayoutColumnCount
		local clipper = Structs.ImGuiListClipper.new()
		clipper:Begin(self.LayoutLineCount, self.LayoutItemStep.y)
		if item_curr_idx_to_focus ~= -1 then
			clipper:IncludeItemByIndex(item_curr_idx_to_focus // column_count)
		end
		if ms_io.RangeSrcItem ~= -1 then
			clipper:IncludeItemByIndex(ms_io.RangeSrcItem // column_count)
		end
		while clipper:Step() do
			for line_idx = clipper.DisplayStart, clipper.DisplayEnd - 1 do
				local item_min_idx_for_current_line = line_idx * column_count
				local item_max_idx_for_current_line = ImMin((line_idx + 1) * column_count, self.Items.Size)
				for item_idx = item_min_idx_for_current_line, item_max_idx_for_current_line - 1 do
					local item_data = self.Items[item_idx + 1]
					ImGui.PushID(item_data.ID)

					local pos = ImVec2(start_pos.x + (item_idx % column_count) * self.LayoutItemStep.x, start_pos.y + line_idx * self.LayoutItemStep.y)
					ImGui.SetCursorScreenPos(pos)

					ImGui.SetNextItemSelectionUserData(item_idx)
					local item_is_selected = self.Selection:Contains(item_data.ID)
					local item_is_visible = ImGui.IsRectVisible(self.LayoutItemSize)
					ImGui.Selectable("", item_is_selected, ImGuiSelectableFlags.None, self.LayoutItemSize)

					if ImGui.IsItemToggledSelection() then
						item_is_selected = not item_is_selected
					end

					if item_curr_idx_to_focus == item_idx then
						ImGui.SetKeyboardFocusHere(-1)
					end

					if ImGui.BeginDragDropSource() then
						if ImGui.GetDragDropPayload() == nil then
							local payload_items = Base.ImVector.new()
							local it = nil
							local id = 0
							local ok
							if not item_is_selected then
								payload_items:push_back(item_data.ID)
							else
								ok, it, id = self.Selection:GetNextSelectedItem(it, id)
								while ok do
									payload_items:push_back(id)
									ok, it, id = self.Selection:GetNextSelectedItem(it, id)
								end
							end
							ImGui.SetDragDropPayload("ASSETS_BROWSER_ITEMS", payload_items, payload_items.Size * 4)
						end

						local payload = ImGui.GetDragDropPayload()
						local payload_count = payload.DataSize // 4
						ImGui.Text("%d assets", payload_count)

						ImGui.EndDragDropSource()
					end

					if item_is_visible then
						local box_min = ImVec2(pos.x - 1, pos.y - 1)
						local box_max = ImVec2(box_min.x + self.LayoutItemSize.x + 2, box_min.y + self.LayoutItemSize.y + 2)
						draw_list:AddRectFilled(box_min, box_max, icon_bg_color)
						if self.ShowTypeOverlay and item_data.Type ~= 0 then
							local type_col = icon_type_overlay_colors[(item_data.Type % #icon_type_overlay_colors) + 1]
							draw_list:AddRectFilled(ImVec2(box_max.x - 2 - icon_type_overlay_size.x, box_min.y + 2), ImVec2(box_max.x - 2, box_min.y + 2 + icon_type_overlay_size.y), type_col)
						end
						if display_label then
							local label_col = ImGui.GetColorU32(item_is_selected and ImGuiCol.Text or ImGuiCol.TextDisabled)
							local label = Base.ImFormatString("%d", item_data.ID)
							draw_list:AddText(ImVec2(box_min.x, box_max.y - ImGui.GetFontSize()), label_col, label)
						end
					end

					ImGui.PopID()
				end
			end
		end
		clipper:End()
		if self.Items.Size == 0 then
			ImGui.Dummy(ImVec2(0, 0))
		end
		ImGui.PopStyleVar()

		if ImGui.BeginPopupContextWindow() then
			ImGui.Text("Selection: %d items", self.Selection.Size)
			ImGui.Separator()
			if ImGui.MenuItem("Delete", "Del", false, self.Selection.Size > 0) then
				self.RequestDelete = true
			end
			ImGui.EndPopup()
		end

		ms_io = ImGui.EndMultiSelect()
		self.Selection:ApplyRequests(ms_io)
		if want_delete then
			self.Selection:ApplyDeletionPostLoop(ms_io, self.Items, item_curr_idx_to_focus)
		end

		if ImGui.IsWindowAppearing() then
			self.ZoomWheelAccum = 0.0
		end
		if ImGui.IsWindowHovered() and io.MouseWheel ~= 0.0 and ImGui.IsKeyDown(ImGuiMod.Ctrl) and ImGui.IsAnyItemActive() == false then
			self.ZoomWheelAccum = self.ZoomWheelAccum + io.MouseWheel
			if math.abs(self.ZoomWheelAccum) >= 1.0 then
				local hovered_item_nx = (io.MousePos.x - start_pos.x + self.LayoutItemSpacing * 0.5) / self.LayoutItemStep.x
				local hovered_item_ny = (io.MousePos.y - start_pos.y + self.LayoutItemSpacing * 0.5) / self.LayoutItemStep.y
				local hovered_item_idx = ImTruncToInt(hovered_item_ny) * self.LayoutColumnCount + ImTruncToInt(hovered_item_nx)

				self.IconSize = self.IconSize * (1.1 ^ ImTruncToInt(self.ZoomWheelAccum))
				self.IconSize = ImClamp(self.IconSize, 16.0, 128.0)
				self.ZoomWheelAccum = self.ZoomWheelAccum - ImTruncToInt(self.ZoomWheelAccum)
				self:UpdateLayoutSizes(avail_width)

				local hovered_item_rel_pos_y = (ImTruncToInt(hovered_item_idx / self.LayoutColumnCount) + math.fmod(hovered_item_ny, 1.0)) * self.LayoutItemStep.y
				hovered_item_rel_pos_y = hovered_item_rel_pos_y + ImGui.GetStyle().WindowPadding.y
				local mouse_local_y = io.MousePos.y - ImGui.GetWindowPos().y
				ImGui.SetScrollY(hovered_item_rel_pos_y - mouse_local_y)
			end
		end
	end
	ImGui.EndChild()

	ImGui.Text("Selected: %d/%d items", self.Selection.Size, self.Items.Size)
	ImGui.End()
	return p_open
end

Demo.ExampleAssetsBrowser = ExampleAssetsBrowser

local S_ShowExampleAppAssetsBrowser = { assets_browser = nil }
function Demo.ShowExampleAppAssetsBrowser(p_open)
	local S = S_ShowExampleAppAssetsBrowser
	if S.assets_browser == nil then
		S.assets_browser = ExampleAssetsBrowser.new()
	end
	p_open = S.assets_browser:Draw("Example: Assets Browser", p_open)
	return p_open
end

return true
