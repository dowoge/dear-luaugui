local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local Demo = ImGui._Demo

local ImVec2, ImVec4 = Base.ImVec2, Base.ImVec4
local ImGuiTextFilter = Base.ImGuiTextFilter

local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiCol = Enums.ImGuiCol
local ImGuiColorEditFlags = Enums.ImGuiColorEditFlags
local ImGuiCond = Enums.ImGuiCond
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiDataType = Enums.ImGuiDataType
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImGuiSliderFlags = Enums.ImGuiSliderFlags
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiTabBarFlags = Enums.ImGuiTabBarFlags
local ImGuiTableColumnFlags = Enums.ImGuiTableColumnFlags
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local S_DemoWindowInputs = {
    capture_override_mouse = -1,
    capture_override_keyboard = -1,
    route_options = ImGuiInputFlags.Repeat,
    route_type = ImGuiInputFlags.RouteFocused,
    f = 0.5,
    tab_buf = "hello",
    focus_buf = "click on a button to set focus",
    f3 = { 0.0, 0.0, 0.0 },
}

function Demo.IsLegacyNativeDupe(key)
    return false
end

function Demo.DemoWindowInputs()
    local S = S_DemoWindowInputs
    if ImGui.CollapsingHeader("Inputs & Focus") then
        local io = ImGui.GetIO()

        ImGui.SetNextItemOpen(true, ImGuiCond.Once)
        local inputs_opened = ImGui.TreeNode("Inputs")
        ImGui.SameLine()
        Demo.HelpMarker(
            "This is a simplified view. See more detailed input state:\n"
            .. "- in 'Tools->Metrics/Debugger->Inputs'.\n"
            .. "- in 'Tools->Debug Log->IO'."
        )
        if inputs_opened then
            if ImGui.IsMousePosValid() then
                ImGui.Text("Mouse pos: (%g, %g)", io.MousePos.x, io.MousePos.y)
            else
                ImGui.Text("Mouse pos: <INVALID>")
            end
            ImGui.Text("Mouse delta: (%g, %g)", io.MouseDelta.x, io.MouseDelta.y)
            ImGui.Text("Mouse down:")
            for i = 0, #io.MouseDown - 1 do
                if ImGui.IsMouseDown(i) then
                    ImGui.SameLine()
                    ImGui.Text("b%d (%.02f secs)", i, io.MouseDownDuration[i + 1])
                end
            end
            ImGui.Text("Mouse wheel: %.1f", io.MouseWheel)
            ImGui.Text("Mouse clicked count:")
            for i = 0, #io.MouseDown - 1 do
                if io.MouseClickedCount[i + 1] > 0 then
                    ImGui.SameLine()
                    ImGui.Text("b%d: %d", i, io.MouseClickedCount[i + 1])
                end
            end

            local start_key = ImGuiKey.NamedKey_BEGIN
            ImGui.Text("Keys down:")
            for key = start_key, ImGuiKey.NamedKey_END - 1 do
                if Demo.IsLegacyNativeDupe(key) or not ImGui.IsKeyDown(key) then
                    continue
                end
                ImGui.SameLine()
                ImGui.Text(key < ImGuiKey.NamedKey_BEGIN and "\"%s\"" or "\"%s\" %d", ImGui.GetKeyName(key), key)
            end
            ImGui.Text(
                "Keys mods: %s%s%s%s",
                io.KeyCtrl and "CTRL " or "",
                io.KeyShift and "SHIFT " or "",
                io.KeyAlt and "ALT " or "",
                io.KeySuper and "SUPER " or ""
            )
            ImGui.Text("Chars queue:")
            for i = 0, io.InputQueueCharacters.Size - 1 do
                local c = io.InputQueueCharacters[i + 1]
                ImGui.SameLine()
                ImGui.Text("'%c' (0x%04X)", (c > 32 and c <= 255) and c or 63, c)
            end

            ImGui.TreePop()
        end

        ImGui.SetNextItemOpen(true, ImGuiCond.Once)
        local outputs_opened = ImGui.TreeNode("Outputs")
        ImGui.SameLine()
        Demo.HelpMarker(
            "The value of io.WantCaptureMouse and io.WantCaptureKeyboard are normally set by Dear ImGui "
            .. "to instruct your application of how to route inputs. Typically, when a value is true, it means "
            .. "Dear ImGui wants the corresponding inputs and we expect the underlying application to ignore them.\n\n"
            .. "The most typical case is: when hovering a window, Dear ImGui set io.WantCaptureMouse to true, "
            .. "and underlying application should ignore mouse inputs (in practice there are many and more subtle "
            .. "rules leading to how those flags are set)."
        )
        if outputs_opened then
            ImGui.Text("io.WantCaptureMouse: %d", io.WantCaptureMouse and 1 or 0)
            ImGui.Text("io.WantCaptureMouseUnlessPopupClose: %d", io.WantCaptureMouseUnlessPopupClose and 1 or 0)
            ImGui.Text("io.WantCaptureKeyboard: %d", io.WantCaptureKeyboard and 1 or 0)
            ImGui.Text("io.WantTextInput: %d", io.WantTextInput and 1 or 0)
            ImGui.Text("io.WantSetMousePos: %d", io.WantSetMousePos and 1 or 0)
            ImGui.Text("io.NavActive: %d, io.NavVisible: %d", io.NavActive and 1 or 0, io.NavVisible and 1 or 0)

            if ImGui.TreeNode("WantCapture override") then
                Demo.HelpMarker(
                    "Hovering the colored canvas will override io.WantCaptureXXX fields.\n"
                    .. "Notice how normally (when set to none), the value of io.WantCaptureKeyboard would be false when hovering "
                    .. "and true when clicking."
                )
                local capture_override_desc = { "None", "Set to false", "Set to true" }
                ImGui.SetNextItemWidth(ImGui.GetFontSize() * 15)
                _, S.capture_override_mouse = ImGui.SliderInt(
                    "SetNextFrameWantCaptureMouse() on hover",
                    S.capture_override_mouse,
                    -1,
                    1,
                    capture_override_desc[S.capture_override_mouse + 2],
                    ImGuiSliderFlags.AlwaysClamp
                )
                ImGui.SetNextItemWidth(ImGui.GetFontSize() * 15)
                _, S.capture_override_keyboard = ImGui.SliderInt(
                    "SetNextFrameWantCaptureKeyboard() on hover",
                    S.capture_override_keyboard,
                    -1,
                    1,
                    capture_override_desc[S.capture_override_keyboard + 2],
                    ImGuiSliderFlags.AlwaysClamp
                )

                local ref_sz = ImGui.GetFrameHeight() * 4.0
                ImGui.ColorButton(
                    "##panel",
                    ImVec4(0.7, 0.1, 0.7, 1.0),
                    bit32.bor(ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoDragDrop),
                    ImVec2(ref_sz, ref_sz)
                )
                if ImGui.IsItemHovered() and S.capture_override_mouse ~= -1 then
                    ImGui.SetNextFrameWantCaptureMouse(S.capture_override_mouse == 1)
                end
                if ImGui.IsItemHovered() and S.capture_override_keyboard ~= -1 then
                    ImGui.SetNextFrameWantCaptureKeyboard(S.capture_override_keyboard == 1)
                end

                ImGui.TreePop()
            end
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Shortcuts") then
            _, S.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_Repeat", S.route_options, ImGuiInputFlags.Repeat)
            _, S.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteActive", S.route_type, ImGuiInputFlags.RouteActive)
            _, S.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteFocused (default)", S.route_type, ImGuiInputFlags.RouteFocused)
            ImGui.Indent()
            ImGui.BeginDisabled(S.route_type ~= ImGuiInputFlags.RouteFocused)
            _, S.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteOverActive##0", S.route_options, ImGuiInputFlags.RouteOverActive)
            ImGui.EndDisabled()
            ImGui.Unindent()
            _, S.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteGlobal", S.route_type, ImGuiInputFlags.RouteGlobal)
            ImGui.Indent()
            ImGui.BeginDisabled(S.route_type ~= ImGuiInputFlags.RouteGlobal)
            _, S.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteOverFocused", S.route_options, ImGuiInputFlags.RouteOverFocused)
            _, S.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteOverActive", S.route_options, ImGuiInputFlags.RouteOverActive)
            _, S.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteUnlessBgFocused", S.route_options, ImGuiInputFlags.RouteUnlessBgFocused)
            ImGui.EndDisabled()
            ImGui.Unindent()
            _, S.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteAlways", S.route_type, ImGuiInputFlags.RouteAlways)
            local flags = bit32.bor(S.route_type, S.route_options)
            if S.route_type ~= ImGuiInputFlags.RouteGlobal then
                flags = bit32.band(flags, bit32.bnot(bit32.bor(
                    ImGuiInputFlags.RouteOverFocused,
                    ImGuiInputFlags.RouteOverActive,
                    ImGuiInputFlags.RouteUnlessBgFocused
                )))
            end

            ImGui.SeparatorText("Using SetNextItemShortcut()")
            ImGui.Text("Ctrl+S")
            ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.S), bit32.bor(flags, ImGuiInputFlags.Tooltip))
            ImGui.Button("Save")
            ImGui.Text("Alt+F")
            ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Alt, ImGuiKey.F), bit32.bor(flags, ImGuiInputFlags.Tooltip))
            _, S.f = ImGui.SliderFloat("Factor", S.f, 0.0, 1.0)

            ImGui.SeparatorText("Using Shortcut()")
            local line_height = ImGui.GetTextLineHeightWithSpacing()
            local key_chord = bit32.bor(ImGuiMod.Ctrl, ImGuiKey.A)

            ImGui.Text("Ctrl+A")
            ImGui.Text(
                "IsWindowFocused: %d, Shortcut: %s",
                ImGui.IsWindowFocused() and 1 or 0,
                ImGui.Shortcut(key_chord, flags) and "PRESSED" or "..."
            )

            ImGui.PushStyleColor(ImGuiCol.ChildBg, ImVec4(1.0, 0.0, 1.0, 0.1))

            ImGui.BeginChild("WindowA", ImVec2(-Base.FLT_MIN, line_height * 14), ImGuiChildFlags.Borders)
            ImGui.Text("Press Ctrl+A and see who receives it!")
            ImGui.Separator()

            ImGui.Text("(in WindowA)")
            ImGui.Text(
                "IsWindowFocused: %d, Shortcut: %s",
                ImGui.IsWindowFocused() and 1 or 0,
                ImGui.Shortcut(key_chord, flags) and "PRESSED" or "..."
            )

            ImGui.BeginChild("ChildD", ImVec2(-Base.FLT_MIN, line_height * 4), ImGuiChildFlags.Borders)
            ImGui.Text("(in ChildD: not using same Shortcut)")
            ImGui.Text("IsWindowFocused: %d", ImGui.IsWindowFocused() and 1 or 0)
            ImGui.EndChild()

            ImGui.BeginChild("ChildE", ImVec2(-Base.FLT_MIN, line_height * 4), ImGuiChildFlags.Borders)
            ImGui.Text("(in ChildE: using same Shortcut)")
            ImGui.Text(
                "IsWindowFocused: %d, Shortcut: %s",
                ImGui.IsWindowFocused() and 1 or 0,
                ImGui.Shortcut(key_chord, flags) and "PRESSED" or "..."
            )
            ImGui.EndChild()

            if ImGui.Button("Open Popup") then
                ImGui.OpenPopup("PopupF")
            end
            if ImGui.BeginPopup("PopupF") then
                ImGui.Text("(in PopupF)")
                ImGui.Text(
                    "IsWindowFocused: %d, Shortcut: %s",
                    ImGui.IsWindowFocused() and 1 or 0,
                    ImGui.Shortcut(key_chord, flags) and "PRESSED" or "..."
                )
                ImGui.EndPopup()
            end
            ImGui.EndChild()
            ImGui.PopStyleColor()

            ImGui.TreePop()
        end

        if ImGui.TreeNode("Mouse Cursors") then
            local mouse_cursors_names = { "Arrow", "TextInput", "ResizeAll", "ResizeNS", "ResizeEW", "ResizeNESW", "ResizeNWSE", "Hand", "Wait", "Progress", "NotAllowed" }
            assert(#mouse_cursors_names == ImGuiMouseCursor.COUNT)

            local current = ImGui.GetMouseCursor()
            local cursor_name = (current >= ImGuiMouseCursor.Arrow and current < ImGuiMouseCursor.COUNT) and mouse_cursors_names[current + 1] or "N/A"
            ImGui.Text("Current mouse cursor = %d: %s", current, cursor_name)
            ImGui.BeginDisabled(true)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseCursors", io.BackendFlags, ImGuiBackendFlags.HasMouseCursors)
            ImGui.EndDisabled()

            ImGui.Text("Hover to see mouse cursors:")
            ImGui.SameLine()
            Demo.HelpMarker(
                "Your application can render a different mouse cursor based on what ImGui::GetMouseCursor() returns. "
                .. "If software cursor rendering (io.MouseDrawCursor) is set ImGui will draw the right cursor for you, "
                .. "otherwise your backend needs to handle it."
            )
            for i = 0, ImGuiMouseCursor.COUNT - 1 do
                local label = Base.ImFormatString("Mouse cursor %d: %s", i, mouse_cursors_names[i + 1])
                ImGui.Bullet()
                ImGui.Selectable(label, false)
                if ImGui.IsItemHovered() then
                    ImGui.SetMouseCursor(i)
                end
            end
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Tabbing") then
            ImGui.Text("Use Tab/Shift+Tab to cycle through keyboard editable fields.")
            _, S.tab_buf = ImGui.InputText("1", S.tab_buf)
            _, S.tab_buf = ImGui.InputText("2", S.tab_buf)
            _, S.tab_buf = ImGui.InputText("3", S.tab_buf)
            ImGui.PushItemFlag(ImGuiItemFlags.NoTabStop, true)
            _, S.tab_buf = ImGui.InputText("4 (tab skip)", S.tab_buf)
            ImGui.SameLine()
            Demo.HelpMarker("Item won't be cycled through when using TAB or Shift+Tab.")
            ImGui.PopItemFlag()
            _, S.tab_buf = ImGui.InputText("5", S.tab_buf)
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Focus from code") then
            local focus_1 = ImGui.Button("Focus on 1")
            ImGui.SameLine()
            local focus_2 = ImGui.Button("Focus on 2")
            ImGui.SameLine()
            local focus_3 = ImGui.Button("Focus on 3")
            local has_focus = 0

            if focus_1 then
                ImGui.SetKeyboardFocusHere()
            end
            _, S.focus_buf = ImGui.InputText("1", S.focus_buf)
            if ImGui.IsItemActive() then
                has_focus = 1
            end

            if focus_2 then
                ImGui.SetKeyboardFocusHere()
            end
            _, S.focus_buf = ImGui.InputText("2", S.focus_buf)
            if ImGui.IsItemActive() then
                has_focus = 2
            end

            ImGui.PushItemFlag(ImGuiItemFlags.NoTabStop, true)
            if focus_3 then
                ImGui.SetKeyboardFocusHere()
            end
            _, S.focus_buf = ImGui.InputText("3 (tab skip)", S.focus_buf)
            if ImGui.IsItemActive() then
                has_focus = 3
            end
            ImGui.SameLine()
            Demo.HelpMarker("Item won't be cycled through when using TAB or Shift+Tab.")
            ImGui.PopItemFlag()

            if has_focus ~= 0 then
                ImGui.Text("Item with focus: %d", has_focus)
            else
                ImGui.Text("Item with focus: <none>")
            end

            local focus_ahead = -1
            if ImGui.Button("Focus on X") then
                focus_ahead = 0
            end
            ImGui.SameLine()
            if ImGui.Button("Focus on Y") then
                focus_ahead = 1
            end
            ImGui.SameLine()
            if ImGui.Button("Focus on Z") then
                focus_ahead = 2
            end
            if focus_ahead ~= -1 then
                ImGui.SetKeyboardFocusHere(focus_ahead)
            end
            ImGui.SliderFloat3("Float3", S.f3, 0.0, 1.0)

            ImGui.TextWrapped("NB: Cursor & selection are preserved when refocusing last used item in code.")
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Dragging") then
            ImGui.TextWrapped("You can use ImGui::GetMouseDragDelta(0) to query for the dragged amount on any widget.")
            for button = 0, 2 do
                ImGui.Text("IsMouseDragging(%d):", button)
                ImGui.Text("  w/ default threshold: %d,", ImGui.IsMouseDragging(button) and 1 or 0)
                ImGui.Text("  w/ zero threshold: %d,", ImGui.IsMouseDragging(button, 0.0) and 1 or 0)
                ImGui.Text("  w/ large threshold: %d,", ImGui.IsMouseDragging(button, 20.0) and 1 or 0)
            end

            ImGui.Button("Drag Me")
            if ImGui.IsItemActive() then
                ImGui.GetForegroundDrawList():AddLine(io.MouseClickedPos[1], io.MousePos, ImGui.GetColorU32(ImGuiCol.Button), 4.0)
            end

            local value_raw = ImGui.GetMouseDragDelta(0, 0.0)
            local value_with_lock_threshold = ImGui.GetMouseDragDelta(0)
            local mouse_delta = io.MouseDelta
            ImGui.Text("GetMouseDragDelta(0):")
            ImGui.Text("  w/ default threshold: (%.1f, %.1f)", value_with_lock_threshold.x, value_with_lock_threshold.y)
            ImGui.Text("  w/ zero threshold: (%.1f, %.1f)", value_raw.x, value_raw.y)
            ImGui.Text("io.MouseDelta: (%.1f, %.1f)", mouse_delta.x, mouse_delta.y)
            ImGui.TreePop()
        end
    end
end

local S_ShowAboutWindow = { show_config_info = false }

function ImGui.ShowAboutWindow(p_open)
    local S = S_ShowAboutWindow
    local visible
    visible, p_open = ImGui.Begin("About Dear ImGui", p_open, ImGuiWindowFlags.AlwaysAutoResize)
    if not visible then
        ImGui.End()
        return p_open
    end
    ImGui.Text("Dear ImGui %s (%d)", Base.IMGUI_VERSION, Base.IMGUI_VERSION_NUM)

    ImGui.TextLinkOpenURL("Homepage", "https://github.com/ocornut/imgui")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("FAQ", "https://github.com/ocornut/imgui/blob/master/docs/FAQ.md")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Wiki", "https://github.com/ocornut/imgui/wiki")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Extensions", "https://github.com/ocornut/imgui/wiki/Useful-Extensions")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Releases", "https://github.com/ocornut/imgui/releases")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Funding", "https://github.com/ocornut/imgui/wiki/Funding")

    ImGui.Separator()
    ImGui.Text("(c) 2014-2026 Omar Cornut")
    ImGui.Text("Developed by Omar Cornut and all Dear ImGui contributors.")
    ImGui.Text("Dear ImGui is licensed under the MIT License, see LICENSE for more information.")
    ImGui.Text("If your company uses this, please consider funding the project.")

    _, S.show_config_info = ImGui.Checkbox("Config/Build Information", S.show_config_info)
    if S.show_config_info then
        local io = ImGui.GetIO()
        local style = ImGui.GetStyle()

        local copy_to_clipboard = ImGui.Button("Copy to clipboard")
        local child_size = ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 18)
        ImGui.BeginChild(ImGui.GetID("cfg_infos"), child_size, ImGuiChildFlags.FrameStyle)
        if copy_to_clipboard then
            ImGui.LogToClipboard()
            ImGui.LogText("// (Copy from the next line. Keep the ``` markers for formatting.)\n")
            ImGui.LogText("```cpp\n")
        end

        ImGui.Text("Dear ImGui %s (%d)", Base.IMGUI_VERSION, Base.IMGUI_VERSION_NUM)
        ImGui.Separator()
        ImGui.Text("language: %s (number: float64, vector: float32x3)", _VERSION)
        ImGui.Text("define: ROBLOX")

        local assert_runs_expression = 0
        assert((function()
            assert_runs_expression = assert_runs_expression + 1
            return assert_runs_expression
        end)())
        local assert_expand_len = math.huge
        local assert_maybe_disabled = assert_runs_expression == 0 or assert_expand_len <= 16
        ImGui.Text("IM_ASSERT: runs expression: %s. expand size: %s%s",
            assert_runs_expression ~= 0 and "OK" or "KO",
            assert_expand_len > 16 and "OK" or "KO",
            assert_maybe_disabled and " (MAYBE DISABLED?!)" or "")
        if assert_maybe_disabled then
            ImGui.SameLine()
            Demo.HelpMarker("IM_ASSERT() calls assert() by default. Compiling with NDEBUG will usually strip out assert() to nothing, which is NOT recommended because we use asserts to notify of programmer mistakes!")
        end

        ImGui.Separator()
        ImGui.Text("io.BackendPlatformName: %s", io.BackendPlatformName or "NULL")
        ImGui.Text("io.BackendRendererName: %s", io.BackendRendererName or "NULL")
        ImGui.Text("io.ConfigFlags: 0x%08X", io.ConfigFlags)
        if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) then ImGui.Text(" NavEnableKeyboard") end
        if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) then ImGui.Text(" NavEnableGamepad") end
        if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoMouse) then ImGui.Text(" NoMouse") end
        if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoMouseCursorChange) then ImGui.Text(" NoMouseCursorChange") end
        if bit32.btest(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) then ImGui.Text(" NoKeyboard") end
        if io.MouseDrawCursor then ImGui.Text("io.MouseDrawCursor") end
        if io.ConfigMacOSXBehaviors then ImGui.Text("io.ConfigMacOSXBehaviors") end
        if io.ConfigNavMoveSetMousePos then ImGui.Text("io.ConfigNavMoveSetMousePos") end
        if io.ConfigNavCaptureKeyboard then ImGui.Text("io.ConfigNavCaptureKeyboard") end
        if io.ConfigInputTextCursorBlink then ImGui.Text("io.ConfigInputTextCursorBlink") end
        if io.ConfigWindowsResizeFromEdges then ImGui.Text("io.ConfigWindowsResizeFromEdges") end
        if io.ConfigWindowsMoveFromTitleBarOnly then ImGui.Text("io.ConfigWindowsMoveFromTitleBarOnly") end
        if io.ConfigMemoryCompactTimer >= 0.0 then ImGui.Text("io.ConfigMemoryCompactTimer = %.1f", io.ConfigMemoryCompactTimer) end
        ImGui.Text("io.BackendFlags: 0x%08X", io.BackendFlags)
        if bit32.btest(io.BackendFlags, ImGuiBackendFlags.HasGamepad) then ImGui.Text(" HasGamepad") end
        if bit32.btest(io.BackendFlags, ImGuiBackendFlags.HasMouseCursors) then ImGui.Text(" HasMouseCursors") end
        if bit32.btest(io.BackendFlags, ImGuiBackendFlags.HasSetMousePos) then ImGui.Text(" HasSetMousePos") end
        if bit32.btest(io.BackendFlags, ImGuiBackendFlags.RendererHasVtxOffset) then ImGui.Text(" RendererHasVtxOffset") end
        if bit32.btest(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures) then ImGui.Text(" RendererHasTextures") end
        ImGui.Separator()
        ImGui.Text("io.Fonts: %d fonts, Flags: 0x%08X, TexSize: %d,%d", io.Fonts.Fonts.Size, io.Fonts.Flags, io.Fonts.TexData.Width, io.Fonts.TexData.Height)
        ImGui.Text("io.Fonts->FontLoaderName: %s", io.Fonts.FontLoaderName or "NULL")
        ImGui.Text("io.DisplaySize: %.2f,%.2f", io.DisplaySize.x, io.DisplaySize.y)
        ImGui.Text("io.DisplayFramebufferScale: %.2f,%.2f", io.DisplayFramebufferScale.x, io.DisplayFramebufferScale.y)
        ImGui.Separator()
        ImGui.Text("style.WindowPadding: %.2f,%.2f", style.WindowPadding.x, style.WindowPadding.y)
        ImGui.Text("style.WindowBorderSize: %.2f", style.WindowBorderSize)
        ImGui.Text("style.FramePadding: %.2f,%.2f", style.FramePadding.x, style.FramePadding.y)
        ImGui.Text("style.FrameRounding: %.2f", style.FrameRounding)
        ImGui.Text("style.FrameBorderSize: %.2f", style.FrameBorderSize)
        ImGui.Text("style.ItemSpacing: %.2f,%.2f", style.ItemSpacing.x, style.ItemSpacing.y)
        ImGui.Text("style.ItemInnerSpacing: %.2f,%.2f", style.ItemInnerSpacing.x, style.ItemInnerSpacing.y)

        if copy_to_clipboard then
            ImGui.LogText("\n```\n")
            ImGui.LogFinish()
        end
        ImGui.EndChild()
    end
    ImGui.End()
    return p_open
end

local S_ShowStyleSelector = { style_idx = -1 }

function ImGui.ShowStyleSelector(label)
    local S = S_ShowStyleSelector
    local style_names = { "Dark", "Light", "Classic" }
    local ret = false
    if ImGui.BeginCombo(label, (S.style_idx >= 0 and S.style_idx < #style_names) and style_names[S.style_idx + 1] or "") then
        for n = 0, #style_names - 1 do
            if ImGui.Selectable(style_names[n + 1], S.style_idx == n, ImGuiSelectableFlags.SelectOnNav) then
                S.style_idx = n
                ret = true
                if S.style_idx == 0 then
                    ImGui.StyleColorsDark()
                elseif S.style_idx == 1 then
                    ImGui.StyleColorsLight()
                elseif S.style_idx == 2 then
                    ImGui.StyleColorsClassic()
                end
            elseif S.style_idx == n then
                ImGui.SetItemDefaultFocus()
            end
        end
        ImGui.EndCombo()
    end
    return ret
end

function Demo.GetTreeLinesFlagsName(flags)
    if flags == ImGuiTreeNodeFlags.DrawLinesNone then return "DrawLinesNone" end
    if flags == ImGuiTreeNodeFlags.DrawLinesFull then return "DrawLinesFull" end
    if flags == ImGuiTreeNodeFlags.DrawLinesToNodes then return "DrawLinesToNodes" end
    return ""
end

local function SliderFloat2Vec(label, v, min, max, fmt)
    local t = { v.x, v.y }
    ImGui.SliderFloat2(label, t, min, max, fmt)
    return ImVec2(t[1], t[2])
end

local function AssignStyle(dst, src)
    for k, v in pairs(src:Copy()) do
        dst[k] = v
    end
end

local S_ShowStyleEditor = {
    ref_saved_style = Structs.ImGuiStyle.new(),
    init = true,
    output_dest = 0,
    output_only_modified = true,
    alpha_flags = ImGuiColorEditFlags.None,
    filter = ImGuiTextFilter.new(),
}

function ImGui.ShowStyleEditor(ref)
    local S = S_ShowStyleEditor
    local style = ImGui.GetStyle()

    if S.init and ref == nil then
        S.ref_saved_style = style:Copy()
    end
    S.init = false
    if ref == nil then
        ref = S.ref_saved_style
    end

    local default_border_size = Base.ImTruncToInt(style._MainScale)
    local max_border_size = Base.ImMax(default_border_size, 2.0)

    ImGui.PushItemWidth(ImGui.GetWindowWidth() * 0.50)

    do
        ImGui.SeparatorText("General")
        if not bit32.btest(ImGui.GetIO().BackendFlags, ImGuiBackendFlags.RendererHasTextures) then
            ImGui.BulletText("Warning: Font scaling will NOT be smooth, because\nImGuiBackendFlags_RendererHasTextures is not set!")
            ImGui.BulletText("For instructions, see:")
            ImGui.SameLine()
            ImGui.TextLinkOpenURL("docs/BACKENDS.md", "https://github.com/ocornut/imgui/blob/master/docs/BACKENDS.md")
        end

        if ImGui.ShowStyleSelector("Colors##Selector") then
            S.ref_saved_style = style:Copy()
        end
        ImGui.ShowFontSelector("Fonts##Selector")
        local changed
        changed, style.FontSizeBase = ImGui.DragFloat("FontSizeBase", style.FontSizeBase, 0.20, 5.0, 100.0, "%.0f")
        if changed then
            style._NextFrameFontSizeBase = style.FontSizeBase
        end
        ImGui.SameLine(0.0, 0.0)
        ImGui.Text(" (out %.2f)", ImGui.GetFontSize())
        _, style.FontScaleMain = ImGui.DragFloat("FontScaleMain", style.FontScaleMain, 0.02, 0.5, 4.0)
        _, style.FontScaleDpi = ImGui.DragFloat("FontScaleDpi", style.FontScaleDpi, 0.02, 0.5, 4.0)

        changed, style.FrameRounding = ImGui.SliderFloat("FrameRounding", style.FrameRounding, 0.0, 12.0, "%.0f")
        if changed then
            style.GrabRounding = style.FrameRounding
        end
        do
            local border = style.WindowBorderSize > 0.0
            changed, border = ImGui.Checkbox("WindowBorder", border)
            if changed then
                style.WindowBorderSize = border and default_border_size or 0.0
            end
        end
        ImGui.SameLine()
        do
            local border = style.FrameBorderSize > 0.0
            changed, border = ImGui.Checkbox("FrameBorder", border)
            if changed then
                style.FrameBorderSize = border and default_border_size or 0.0
            end
        end
        ImGui.SameLine()
        do
            local border = style.PopupBorderSize > 0.0
            changed, border = ImGui.Checkbox("PopupBorder", border)
            if changed then
                style.PopupBorderSize = border and default_border_size or 0.0
            end
        end
    end

    if ImGui.Button("Save Ref") then
        S.ref_saved_style = style:Copy()
        AssignStyle(ref, S.ref_saved_style)
    end
    ImGui.SameLine()
    if ImGui.Button("Revert Ref") then
        AssignStyle(style, ref)
    end
    ImGui.SameLine()
    Demo.HelpMarker(
        "Save/Revert in local non-persistent storage. Default Colors definition are not affected. "
        .. "Use \"Export\" below to save them somewhere."
    )

    ImGui.SeparatorText("Details")
    if ImGui.BeginTabBar("##tabs", ImGuiTabBarFlags.None) then
        if ImGui.BeginTabItem("Sizes") then
            ImGui.SeparatorText("Main")
            style.WindowPadding = SliderFloat2Vec("WindowPadding", style.WindowPadding, 0.0, 20.0, "%.0f")
            style.FramePadding = SliderFloat2Vec("FramePadding", style.FramePadding, 0.0, 20.0, "%.0f")
            style.ItemSpacing = SliderFloat2Vec("ItemSpacing", style.ItemSpacing, 0.0, 20.0, "%.0f")
            style.ItemInnerSpacing = SliderFloat2Vec("ItemInnerSpacing", style.ItemInnerSpacing, 0.0, 20.0, "%.0f")
            style.TouchExtraPadding = SliderFloat2Vec("TouchExtraPadding", style.TouchExtraPadding, 0.0, 10.0, "%.0f")
            _, style.IndentSpacing = ImGui.SliderFloat("IndentSpacing", style.IndentSpacing, 0.0, 30.0, "%.0f")
            _, style.GrabMinSize = ImGui.SliderFloat("GrabMinSize", style.GrabMinSize, 1.0, 20.0, "%.0f")

            ImGui.SeparatorText("Borders")
            _, style.WindowBorderSize = ImGui.SliderFloat("WindowBorderSize", style.WindowBorderSize, 0.0, max_border_size, "%.0f")
            _, style.ChildBorderSize = ImGui.SliderFloat("ChildBorderSize", style.ChildBorderSize, 0.0, max_border_size, "%.0f")
            _, style.PopupBorderSize = ImGui.SliderFloat("PopupBorderSize", style.PopupBorderSize, 0.0, max_border_size, "%.0f")
            _, style.FrameBorderSize = ImGui.SliderFloat("FrameBorderSize", style.FrameBorderSize, 0.0, max_border_size, "%.0f")

            ImGui.SeparatorText("Rounding")
            _, style.WindowRounding = ImGui.SliderFloat("WindowRounding", style.WindowRounding, 0.0, 12.0, "%.0f")
            _, style.ChildRounding = ImGui.SliderFloat("ChildRounding", style.ChildRounding, 0.0, 12.0, "%.0f")
            _, style.FrameRounding = ImGui.SliderFloat("FrameRounding", style.FrameRounding, 0.0, 12.0, "%.0f")
            _, style.PopupRounding = ImGui.SliderFloat("PopupRounding", style.PopupRounding, 0.0, 12.0, "%.0f")
            _, style.GrabRounding = ImGui.SliderFloat("GrabRounding", style.GrabRounding, 0.0, 12.0, "%.0f")
            _, style.MenuItemRounding = ImGui.SliderFloat("MenuItemRounding", style.MenuItemRounding, 0.0, 12.0, "%.0f")

            ImGui.SeparatorText("Scrollbar")
            _, style.ScrollbarSize = ImGui.SliderFloat("ScrollbarSize", style.ScrollbarSize, 1.0, 20.0, "%.0f")
            _, style.ScrollbarRounding = ImGui.SliderFloat("ScrollbarRounding", style.ScrollbarRounding, 0.0, 12.0, "%.0f")
            _, style.ScrollbarPadding = ImGui.SliderFloat("ScrollbarPadding", style.ScrollbarPadding, 0.0, 10.0, "%.0f")

            ImGui.SeparatorText("Tabs")
            _, style.TabBorderSize = ImGui.SliderFloat("TabBorderSize", style.TabBorderSize, 0.0, max_border_size, "%.0f")
            _, style.TabBarBorderSize = ImGui.SliderFloat("TabBarBorderSize", style.TabBarBorderSize, 0.0, max_border_size, "%.0f")
            _, style.TabBarOverlineSize = ImGui.SliderFloat("TabBarOverlineSize", style.TabBarOverlineSize, 0.0, Base.ImMax(3.0, max_border_size), "%.0f")
            ImGui.SameLine()
            Demo.HelpMarker("Overline is only drawn over the selected tab when ImGuiTabBarFlags_DrawSelectedOverline is set.")
            _, style.TabMinWidthBase = ImGui.DragFloat("TabMinWidthBase", style.TabMinWidthBase, 0.5, 1.0, 500.0, "%.0f")
            _, style.TabMinWidthShrink = ImGui.DragFloat("TabMinWidthShrink", style.TabMinWidthShrink, 0.5, 1.0, 500.0, "%0.f")
            _, style.TabCloseButtonMinWidthSelected = ImGui.DragFloat("TabCloseButtonMinWidthSelected", style.TabCloseButtonMinWidthSelected, 0.5, -1.0, 100.0,
                (style.TabCloseButtonMinWidthSelected < 0.0) and "%.0f (Always)" or "%.0f")
            _, style.TabCloseButtonMinWidthUnselected = ImGui.DragFloat("TabCloseButtonMinWidthUnselected", style.TabCloseButtonMinWidthUnselected, 0.5, -1.0, 100.0,
                (style.TabCloseButtonMinWidthUnselected < 0.0) and "%.0f (Always)" or "%.0f")
            _, style.TabRounding = ImGui.SliderFloat("TabRounding", style.TabRounding, 0.0, 12.0, "%.0f")

            ImGui.SeparatorText("Tables")
            style.CellPadding = SliderFloat2Vec("CellPadding", style.CellPadding, 0.0, 20.0, "%.0f")
            _, style.TableAngledHeadersAngle = ImGui.SliderAngle("TableAngledHeadersAngle", style.TableAngledHeadersAngle, -50.0, 50.0)
            style.TableAngledHeadersTextAlign = SliderFloat2Vec("TableAngledHeadersTextAlign", style.TableAngledHeadersTextAlign, 0.0, 1.0, "%.2f")

            ImGui.SeparatorText("Trees")
            local combo_open = ImGui.BeginCombo("TreeLinesFlags", Demo.GetTreeLinesFlagsName(style.TreeLinesFlags))
            ImGui.SameLine()
            Demo.HelpMarker("[Experimental] Tree lines may not work in all situations (e.g. using a clipper) and may incurs slight traversal overhead.\n\nImGuiTreeNodeFlags_DrawLinesFull is faster than ImGuiTreeNodeFlags_DrawLinesToNode.")
            if combo_open then
                local options = { ImGuiTreeNodeFlags.DrawLinesNone, ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes }
                for _, option in ipairs(options) do
                    if ImGui.Selectable(Demo.GetTreeLinesFlagsName(option), style.TreeLinesFlags == option) then
                        style.TreeLinesFlags = option
                    end
                end
                ImGui.EndCombo()
            end
            _, style.TreeLinesSize = ImGui.SliderFloat("TreeLinesSize", style.TreeLinesSize, 0.0, max_border_size, "%.0f")
            _, style.TreeLinesRounding = ImGui.SliderFloat("TreeLinesRounding", style.TreeLinesRounding, 0.0, 12.0, "%.0f")

            ImGui.SeparatorText("Windows")
            style.WindowTitleAlign = SliderFloat2Vec("WindowTitleAlign", style.WindowTitleAlign, 0.0, 1.0, "%.2f")
            _, style.WindowBorderHoverPadding = ImGui.SliderFloat("WindowBorderHoverPadding", style.WindowBorderHoverPadding, 1.0, 20.0, "%.0f")
            local window_menu_button_position = style.WindowMenuButtonPosition + 1
            local wmbp_changed
            wmbp_changed, window_menu_button_position = ImGui.Combo("WindowMenuButtonPosition", window_menu_button_position, { "None", "Left", "Right" })
            if wmbp_changed then
                style.WindowMenuButtonPosition = window_menu_button_position - 1
            end

            ImGui.SeparatorText("Widgets")
            _, style.ColorMarkerSize = ImGui.SliderFloat("ColorMarkerSize", style.ColorMarkerSize, 0.0, 8.0, "%.0f")
            _, style.ColorButtonPosition = ImGui.Combo("ColorButtonPosition", style.ColorButtonPosition, { "Left", "Right" })
            style.ButtonTextAlign = SliderFloat2Vec("ButtonTextAlign", style.ButtonTextAlign, 0.0, 1.0, "%.2f")
            ImGui.SameLine()
            Demo.HelpMarker("Alignment applies when a button is larger than its text content.")
            style.SelectableTextAlign = SliderFloat2Vec("SelectableTextAlign", style.SelectableTextAlign, 0.0, 1.0, "%.2f")
            ImGui.SameLine()
            Demo.HelpMarker("Alignment applies when a selectable is larger than its text content.")
            _, style.SeparatorSize = ImGui.SliderFloat("SeparatorSize", style.SeparatorSize, 0.0, 10.0, "%.0f")
            _, style.SeparatorTextBorderSize = ImGui.SliderFloat("SeparatorTextBorderSize", style.SeparatorTextBorderSize, 0.0, 10.0, "%.0f")
            style.SeparatorTextAlign = SliderFloat2Vec("SeparatorTextAlign", style.SeparatorTextAlign, 0.0, 1.0, "%.2f")
            style.SeparatorTextPadding = SliderFloat2Vec("SeparatorTextPadding", style.SeparatorTextPadding, 0.0, 40.0, "%.0f")
            _, style.LogSliderDeadzone = ImGui.SliderFloat("LogSliderDeadzone", style.LogSliderDeadzone, 0.0, 12.0, "%.0f")
            _, style.ImageRounding = ImGui.SliderFloat("ImageRounding", style.ImageRounding, 0.0, 12.0, "%.0f")
            _, style.ImageBorderSize = ImGui.SliderFloat("ImageBorderSize", style.ImageBorderSize, 0.0, max_border_size, "%.0f")

            ImGui.SeparatorText("Tooltips")
            for n = 0, 1 do
                local key = n == 0 and "HoverFlagsForTooltipMouse" or "HoverFlagsForTooltipNav"
                if ImGui.TreeNodeEx(key) then
                    _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_DelayNone", style[key], ImGuiHoveredFlags.DelayNone)
                    _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_DelayShort", style[key], ImGuiHoveredFlags.DelayShort)
                    _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_DelayNormal", style[key], ImGuiHoveredFlags.DelayNormal)
                    _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_Stationary", style[key], ImGuiHoveredFlags.Stationary)
                    _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_NoSharedDelay", style[key], ImGuiHoveredFlags.NoSharedDelay)
                    ImGui.TreePop()
                end
            end

            ImGui.SeparatorText("Misc")
            style.DisplayWindowPadding = SliderFloat2Vec("DisplayWindowPadding", style.DisplayWindowPadding, 0.0, 30.0, "%.0f")
            ImGui.SameLine()
            Demo.HelpMarker("Apply to regular windows: amount which we enforce to keep visible when moving near edges of your screen.")
            style.DisplaySafeAreaPadding = SliderFloat2Vec("DisplaySafeAreaPadding", style.DisplaySafeAreaPadding, 0.0, 30.0, "%.0f")
            ImGui.SameLine()
            Demo.HelpMarker("Apply to every windows, menus, popups, tooltips: amount where we avoid displaying contents. Adjust if you cannot see the edges of your screen (e.g. on a TV where scaling has not been configured).")

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Colors") then
            if ImGui.Button("Export") then
                if S.output_dest == 0 then
                    ImGui.LogToClipboard()
                else
                    ImGui.LogToTTY()
                end
                ImGui.LogText("ImVec4* colors = GetStyle().Colors;\n")
                for i = 0, ImGuiCol.COUNT - 1 do
                    local col = style.Colors[i + 1]
                    local name = ImGui.GetStyleColorName(i)
                    if not S.output_only_modified or col ~= ref.Colors[i + 1] then
                        ImGui.LogText("colors[ImGuiCol_%s]%s= ImVec4(%.2ff, %.2ff, %.2ff, %.2ff);\n",
                            name, string.rep(" ", math.abs(23 - #name)), col.x, col.y, col.z, col.w)
                    end
                end
                ImGui.LogFinish()
            end
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 10)
            _, S.output_dest = ImGui.Combo("##output_type", S.output_dest, { "To Clipboard", "To TTY" })
            ImGui.SameLine()
            _, S.output_only_modified = ImGui.Checkbox("Only Modified Colors", S.output_only_modified)

            if ImGui.RadioButton("Opaque", S.alpha_flags == ImGuiColorEditFlags.AlphaOpaque) then
                S.alpha_flags = ImGuiColorEditFlags.AlphaOpaque
            end
            ImGui.SameLine()
            if ImGui.RadioButton("Alpha", S.alpha_flags == ImGuiColorEditFlags.None) then
                S.alpha_flags = ImGuiColorEditFlags.None
            end
            ImGui.SameLine()
            if ImGui.RadioButton("Both", S.alpha_flags == ImGuiColorEditFlags.AlphaPreviewHalf) then
                S.alpha_flags = ImGuiColorEditFlags.AlphaPreviewHalf
            end
            ImGui.SameLine()
            Demo.HelpMarker(
                "In the color list:\n"
                .. "Left-click on color square to open color picker,\n"
                .. "Right-click to open edit options menu."
            )

            ImGui.SetNextItemWidth(-Base.FLT_MIN)
            S.filter:DrawWithHint("##FilterColors", "Filter Colors (incl -excl)")

            ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 10), ImVec2(Base.FLT_MAX, Base.FLT_MAX))
            ImGui.BeginChild("##colors", ImVec2(0, 0),
                bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.NavFlattened),
                bit32.bor(ImGuiWindowFlags.AlwaysVerticalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar))
            ImGui.PushItemWidth(ImGui.GetFontSize() * -12)
            for i = 0, ImGuiCol.COUNT - 1 do
                local name = ImGui.GetStyleColorName(i)
                if S.filter:PassFilter(name) then
                    ImGui.PushID(i)
                    if ImGui.Button("?") then
                        ImGui.DebugFlashStyleColor(i)
                    end
                    ImGui.SetItemTooltip("Flash given color to identify places where it is used.")
                    ImGui.SameLine()
                    local c = style.Colors[i + 1]
                    local t = { c.x, c.y, c.z, c.w }
                    if ImGui.ColorEdit4("##color", t, bit32.bor(ImGuiColorEditFlags.AlphaBar, S.alpha_flags)) then
                        style.Colors[i + 1] = ImVec4(t[1], t[2], t[3], t[4])
                    end
                    if style.Colors[i + 1] ~= ref.Colors[i + 1] then
                        ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
                        if ImGui.Button("Save") then
                            ref.Colors[i + 1] = style.Colors[i + 1]
                        end
                        ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
                        if ImGui.Button("Revert") then
                            style.Colors[i + 1] = ref.Colors[i + 1]
                        end
                    end
                    ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
                    ImGui.TextUnformatted(name)
                    ImGui.PopID()
                end
            end
            ImGui.PopItemWidth()
            ImGui.EndChild()

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Fonts") then
            local io = ImGui.GetIO()
            local atlas = io.Fonts
            ImGui.ShowFontAtlas(atlas)

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Rendering") then
            local io = ImGui.GetIO()
            _, style.AntiAliasedLines = ImGui.Checkbox("Anti-aliased lines", style.AntiAliasedLines)
            ImGui.SameLine()
            Demo.HelpMarker("When disabling anti-aliasing lines, you'll probably want to disable borders in your style as well.")
            ImGui.BeginDisabled(style.AntiAliasedLines == false)
            _, style.AntiAliasedLineEnds = ImGui.Checkbox("Anti-aliased line ends", style.AntiAliasedLineEnds)
            ImGui.EndDisabled()

            _, style.AntiAliasedFill = ImGui.Checkbox("Anti-aliased fill", style.AntiAliasedFill)
            _, io.ConfigDebugDrawListDefaultsToStrokeLegacy = ImGui.Checkbox("Debug: DrawList Defaults to _StrokeLegacy", io.ConfigDebugDrawListDefaultsToStrokeLegacy)

            ImGui.PushItemWidth(ImGui.GetFontSize() * 8)
            _, style.CurveTessellationMaxError = ImGui.DragFloat("Curve Tessellation Max Error", style.CurveTessellationMaxError, 0.02, 0.10, 10.0, "%.2f")
            if style.CurveTessellationMaxError < 0.10 then
                style.CurveTessellationMaxError = 0.10
            end

            _, style.CircleTessellationMaxError = ImGui.DragFloat("Circle Tessellation Max Error", style.CircleTessellationMaxError, 0.005, 0.10, 5.0, "%.2f", ImGuiSliderFlags.AlwaysClamp)
            local show_samples = ImGui.IsItemActive()
            if show_samples then
                ImGui.SetNextWindowPos(ImGui.GetCursorScreenPos())
            end
            if show_samples and ImGui.BeginTooltip() then
                ImGui.TextUnformatted("(R = radius, N = approx number of segments)")
                ImGui.Spacing()
                local draw_list = ImGui.GetWindowDrawList()
                local min_widget_width = ImGui.CalcTextSize("R: MMM\nN: MMM").x
                for n = 0, 7 do
                    local RAD_MIN = 5.0
                    local RAD_MAX = 70.0
                    local rad = RAD_MIN + (RAD_MAX - RAD_MIN) * n / (8.0 - 1.0)

                    ImGui.BeginGroup()
                    ImGui.Text("R: %.f\nN: %d", rad, draw_list:_CalcCircleAutoSegmentCount(rad))

                    local canvas_width = Base.ImMax(min_widget_width, rad * 2.0)
                    local offset_x = math.floor(canvas_width * 0.5)
                    local offset_y = math.floor(RAD_MAX)

                    local p1 = ImGui.GetCursorScreenPos()
                    draw_list:AddCircle(ImVec2(p1.x + offset_x, p1.y + offset_y), rad, ImGui.GetColorU32(ImGuiCol.Text))
                    ImGui.Dummy(ImVec2(canvas_width, RAD_MAX * 2))

                    ImGui.EndGroup()
                    ImGui.SameLine()
                end
                ImGui.EndTooltip()
            end
            ImGui.SameLine()
            Demo.HelpMarker("When drawing circle primitives with \"num_segments == 0\" tessellation will be calculated automatically.")

            _, style.Alpha = ImGui.DragFloat("Global Alpha", style.Alpha, 0.005, 0.20, 1.0, "%.2f")
            _, style.DisabledAlpha = ImGui.DragFloat("Disabled Alpha", style.DisabledAlpha, 0.005, 0.0, 1.0, "%.2f")
            ImGui.SameLine()
            Demo.HelpMarker("Additional alpha multiplier for disabled items (multiply over current value of Alpha).")
            ImGui.PopItemWidth()

            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end
    ImGui.PopItemWidth()
end

function ImGui.ShowUserGuide()
    local io = ImGui.GetIO()
    ImGui.BulletText("Double-click on title bar to collapse window.")
    ImGui.BulletText(
        "Click and drag on lower corner or border to resize window.\n"
        .. "(double-click to auto fit window to its contents)"
    )
    ImGui.BulletText("Ctrl+Click on a slider or drag box to input value as text.")
    ImGui.BulletText("Tab/Shift+Tab to cycle through keyboard editable fields.")
    ImGui.BulletText("Ctrl+Tab/Ctrl+Shift+Tab to focus windows.")
    if io.FontAllowUserScaling then
        ImGui.BulletText("Ctrl+Mouse Wheel to zoom window contents.")
    end
    ImGui.BulletText("While inputting text:\n")
    ImGui.Indent()
    ImGui.BulletText("Ctrl+Left/Right to word jump.")
    ImGui.BulletText("Ctrl+A or double-click to select all.")
    ImGui.BulletText("Ctrl+X/C/V to use clipboard cut/copy/paste.")
    ImGui.BulletText("Ctrl+Z to undo, Ctrl+Y/Ctrl+Shift+Z to redo.")
    ImGui.BulletText("Escape to revert.")
    ImGui.Unindent()
    ImGui.BulletText("With Keyboard controls enabled:")
    ImGui.Indent()
    ImGui.BulletText("Arrow keys or Home/End/PageUp/PageDown to navigate.")
    ImGui.BulletText("Space to activate a widget.")
    ImGui.BulletText("Return to input text into a widget.")
    ImGui.BulletText("Escape to deactivate a widget, close popup,\nexit a child window or the menu layer, clear focus.")
    ImGui.BulletText("Alt to jump to the menu layer of a window.")
    ImGui.BulletText("Menu or Shift+F10 to open a context menu.")
    ImGui.Unindent()
    ImGui.BulletText("With Gamepad controls enabled:")
    ImGui.Indent()
    ImGui.BulletText("D-Pad: Navigate / Tweak / Resize (in Windowing mode).")
    ImGui.BulletText("%s Face button: Activate / Open / Toggle. Hold: activate with text input.", io.ConfigNavSwapGamepadButtons and "East" or "South")
    ImGui.BulletText("%s Face button: Cancel / Close / Exit.", io.ConfigNavSwapGamepadButtons and "South" or "East")
    ImGui.BulletText("West Face button: Toggle Menu. Hold for Windowing mode (Focus/Move/Resize windows).")
    ImGui.BulletText("North Face button: Open Context Menu.")
    ImGui.BulletText("L1/R1: Tweak Slower/Faster, Focus Previous/Next (in Windowing Mode).")
    ImGui.Unindent()
end

function Demo.ShowExampleAppMainMenuBar()
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu("File") then
            Demo.ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Edit") then
            ImGui.MenuItem("Undo", "Ctrl+Z")
            ImGui.MenuItem("Redo", "Ctrl+Y", false, false)
            ImGui.Separator()
            ImGui.MenuItem("Cut", "Ctrl+X")
            ImGui.MenuItem("Copy", "Ctrl+C")
            ImGui.MenuItem("Paste", "Ctrl+V")
            ImGui.EndMenu()
        end
        ImGui.EndMainMenuBar()
    end
end

local S_ShowExampleMenuFile = { enabled = true, n = 0, f = 0.5, b = true }

function Demo.ShowExampleMenuFile()
    local S = S_ShowExampleMenuFile
    ImGui.MenuItem("(demo menu)", nil, false, false)
    ImGui.MenuItem("New")
    ImGui.MenuItem("Open", "Ctrl+O")
    if ImGui.BeginMenu("Open Recent") then
        ImGui.MenuItem("fish_hat.c")
        ImGui.MenuItem("fish_hat.inl")
        ImGui.MenuItem("fish_hat.h")
        if ImGui.BeginMenu("More..") then
            ImGui.MenuItem("Hello")
            ImGui.MenuItem("Sailor")
            if ImGui.BeginMenu("Recurse..") then
                Demo.ShowExampleMenuFile()
                ImGui.EndMenu()
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenu()
    end
    ImGui.MenuItem("Save", "Ctrl+S")
    ImGui.MenuItem("Save As..")

    ImGui.Separator()
    if ImGui.BeginMenu("Options") then
        _, S.enabled = ImGui.MenuItem("Enabled", "", S.enabled, true)
        ImGui.BeginChild("child", ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 5.0), ImGuiChildFlags.Borders)
        for i = 0, 9 do
            ImGui.Text("Scrolling Text %d", i)
        end
        ImGui.EndChild()
        _, S.f = ImGui.SliderFloat("Value", S.f, 0.0, 1.0)
        _, S.f = ImGui.InputFloat("Input", S.f, 0.1)
        _, S.n = ImGui.Combo("Combo", S.n, { "Yes", "No", "Maybe" })
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Colors") then
        local sz = ImGui.GetTextLineHeight()
        for i = 0, ImGuiCol.COUNT - 1 do
            local name = ImGui.GetStyleColorName(i)
            local p = ImGui.GetCursorScreenPos()
            ImGui.GetWindowDrawList():AddRectFilled(p, ImVec2(p.x + sz, p.y + sz), ImGui.GetColorU32(i))
            ImGui.Dummy(ImVec2(sz, sz))
            ImGui.SameLine()
            ImGui.MenuItem(name)
        end
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Options") then
        _, S.b = ImGui.Checkbox("SomeOption", S.b)
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Disabled", false) then
        assert(false)
    end
    ImGui.MenuItem("Checked", nil, true)
    ImGui.Separator()
    ImGui.MenuItem("Quit", "Alt+F4")
end

Demo.ExampleAppConsole = {}
Demo.ExampleAppConsole.__index = Demo.ExampleAppConsole

function Demo.ExampleAppConsole.new()
    local self = setmetatable({
        InputBuf = "",
        Items = Base.ImVector.new(),
        Commands = Base.ImVector.new(),
        History = Base.ImVector.new(),
        HistoryPos = -1,
        Filter = Base.ImGuiTextFilter.new(),
        AutoScroll = true,
        ScrollToBottom = false,
    }, Demo.ExampleAppConsole)
    self.Commands:push_back("HELP")
    self.Commands:push_back("HISTORY")
    self.Commands:push_back("CLEAR")
    self.Commands:push_back("CLASSIFY")
    self:AddLog("Welcome to Dear ImGui!")
    return self
end

function Demo.ExampleAppConsole.Stricmp(s1, s2)
    local i = 1
    while true do
        local c1 = string.byte(s1, i) or 0
        local c2 = string.byte(s2, i) or 0
        local d = Base.ImToUpper(c2) - Base.ImToUpper(c1)
        if d ~= 0 or c1 == 0 then
            return d
        end
        i = i + 1
    end
end

function Demo.ExampleAppConsole.Strnicmp(s1, s2, n)
    local d = 0
    local i = 1
    while n > 0 do
        local c1 = string.byte(s1, i) or 0
        local c2 = string.byte(s2, i) or 0
        d = Base.ImToUpper(c2) - Base.ImToUpper(c1)
        if d ~= 0 or c1 == 0 then
            break
        end
        i = i + 1
        n = n - 1
    end
    return d
end

function Demo.ExampleAppConsole.Strtrimblanks(s)
    return (string.gsub(s, " +$", ""))
end

function Demo.ExampleAppConsole:ClearLog()
    self.Items:clear()
end

function Demo.ExampleAppConsole:AddLog(fmt, ...)
    local s = Base.ImFormatString(fmt, ...)
    self.Items:push_back(string.sub(s, 1, 1023))
end

function Demo.ExampleAppConsole:Draw(title, p_open)
    ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver)
    local visible
    visible, p_open = ImGui.Begin(title, p_open)
    if not visible then
        ImGui.End()
        return p_open
    end

    if ImGui.BeginPopupContextItem() then
        if ImGui.MenuItem("Close Console") then
            p_open = false
        end
        ImGui.EndPopup()
    end

    ImGui.TextWrapped(
        "This example implements a console with basic coloring, completion (TAB key) and history (Up/Down keys). A more elaborate "
        .. "implementation may want to store entries along with extra data such as timestamp, emitter, etc."
    )
    ImGui.TextWrapped("Enter 'HELP' for help.")

    if ImGui.SmallButton("Add Debug Text") then
        self:AddLog("%d some text", self.Items.Size)
        self:AddLog("some more text")
        self:AddLog("display very important message here!")
    end
    ImGui.SameLine()
    if ImGui.SmallButton("Add Debug Error") then
        self:AddLog("[error] something went wrong")
    end
    ImGui.SameLine()
    if ImGui.SmallButton("Clear") then
        self:ClearLog()
    end
    ImGui.SameLine()
    local copy_to_clipboard = ImGui.SmallButton("Copy")

    ImGui.Separator()

    if ImGui.BeginPopup("Options") then
        _, self.AutoScroll = ImGui.Checkbox("Auto-scroll", self.AutoScroll)
        ImGui.EndPopup()
    end

    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.O), ImGuiInputFlags.Tooltip)
    if ImGui.Button("Options") then
        ImGui.OpenPopup("Options")
    end
    ImGui.SameLine()

    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.F), ImGuiInputFlags.Tooltip)
    ImGui.SetNextItemWidth(-Base.FLT_MIN)
    self.Filter:DrawWithHint("##Filter", "Filter (incl -excl)")
    ImGui.Separator()

    local style = ImGui.GetStyle()
    local footer_height_to_reserve = style.SeparatorSize + style.ItemSpacing.y + ImGui.GetFrameHeightWithSpacing()
    if ImGui.BeginChild("ScrollingRegion", ImVec2(0, -footer_height_to_reserve), ImGuiChildFlags.NavFlattened, ImGuiWindowFlags.HorizontalScrollbar) then
        if ImGui.BeginPopupContextWindow() then
            if ImGui.Selectable("Clear") then
                self:ClearLog()
            end
            ImGui.EndPopup()
        end

        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(4, 1))
        if copy_to_clipboard then
            ImGui.LogToClipboard()
        end
        for i = 0, self.Items.Size - 1 do
            local item = self.Items[i + 1]
            if self.Filter:PassFilter(item) then
                local color
                local has_color = false
                if string.find(item, "[error]", 1, true) then
                    color = ImVec4(1.0, 0.4, 0.4, 1.0)
                    has_color = true
                elseif string.sub(item, 1, 2) == "# " then
                    color = ImVec4(1.0, 0.8, 0.6, 1.0)
                    has_color = true
                end
                if has_color then
                    ImGui.PushStyleColor(ImGuiCol.Text, color)
                end
                ImGui.TextUnformatted(item)
                if has_color then
                    ImGui.PopStyleColor()
                end
            end
        end
        if copy_to_clipboard then
            ImGui.LogFinish()
        end

        if self.ScrollToBottom or (self.AutoScroll and ImGui.GetScrollY() >= ImGui.GetScrollMaxY()) then
            ImGui.SetScrollHereY(1.0)
        end
        self.ScrollToBottom = false

        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
    ImGui.Separator()

    local reclaim_focus = false
    local input_text_flags = bit32.bor(
        ImGuiInputTextFlags.EnterReturnsTrue,
        ImGuiInputTextFlags.EscapeClearsAll,
        ImGuiInputTextFlags.CallbackCompletion,
        ImGuiInputTextFlags.CallbackHistory
    )
    local changed
    changed, self.InputBuf = ImGui.InputText("Input", self.InputBuf, input_text_flags, Demo.ExampleAppConsole.TextEditCallbackStub, self)
    if changed then
        local s = Demo.ExampleAppConsole.Strtrimblanks(self.InputBuf)
        if s ~= "" then
            self:ExecCommand(s)
        end
        self.InputBuf = ""
        reclaim_focus = true
    end

    ImGui.SetItemDefaultFocus()
    if reclaim_focus then
        ImGui.SetKeyboardFocusHere(-1)
    end

    ImGui.End()
    return p_open
end

function Demo.ExampleAppConsole:ExecCommand(command_line)
    self:AddLog("# %s\n", command_line)

    self.HistoryPos = -1
    for i = self.History.Size - 1, 0, -1 do
        if Demo.ExampleAppConsole.Stricmp(self.History[i + 1], command_line) == 0 then
            self.History:erase(i)
            break
        end
    end
    self.History:push_back(command_line)

    if Demo.ExampleAppConsole.Stricmp(command_line, "CLEAR") == 0 then
        self:ClearLog()
    elseif Demo.ExampleAppConsole.Stricmp(command_line, "HELP") == 0 then
        self:AddLog("Commands:")
        for i = 0, self.Commands.Size - 1 do
            self:AddLog("- %s", self.Commands[i + 1])
        end
    elseif Demo.ExampleAppConsole.Stricmp(command_line, "HISTORY") == 0 then
        local first = self.History.Size - 10
        for i = (first > 0) and first or 0, self.History.Size - 1 do
            self:AddLog("%3d: %s\n", i, self.History[i + 1])
        end
    else
        self:AddLog("Unknown command: '%s'\n", command_line)
    end

    self.ScrollToBottom = true
end

function Demo.ExampleAppConsole.TextEditCallbackStub(data)
    local console = data.UserData
    return console:TextEditCallback(data)
end

function Demo.ExampleAppConsole:TextEditCallback(data)
    local event_flag = data.EventFlag
    if event_flag == ImGuiInputTextFlags.CallbackCompletion then
        local word_end = data.CursorPos
        local word_start = word_end
        while word_start > 0 do
            local c = string.byte(data.Buf, word_start)
            if c == 32 or c == 9 or c == 44 or c == 59 then
                break
            end
            word_start = word_start - 1
        end

        local word = string.sub(data.Buf, word_start + 1, word_end)
        local candidates = Base.ImVector.new()
        for i = 0, self.Commands.Size - 1 do
            if Demo.ExampleAppConsole.Strnicmp(self.Commands[i + 1], word, #word) == 0 then
                candidates:push_back(self.Commands[i + 1])
            end
        end

        if candidates.Size == 0 then
            self:AddLog("No match for \"%s\"!\n", word)
        elseif candidates.Size == 1 then
            data:DeleteChars(word_start, word_end - word_start)
            data:InsertChars(data.CursorPos, candidates[1])
            data:InsertChars(data.CursorPos, " ")
        else
            local match_len = word_end - word_start
            while true do
                local c = 0
                local all_candidates_matches = true
                for i = 0, candidates.Size - 1 do
                    if not all_candidates_matches then
                        break
                    end
                    if i == 0 then
                        c = Base.ImToUpper(string.byte(candidates[i + 1], match_len + 1) or 0)
                    elseif c == 0 or c ~= Base.ImToUpper(string.byte(candidates[i + 1], match_len + 1) or 0) then
                        all_candidates_matches = false
                    end
                end
                if not all_candidates_matches then
                    break
                end
                match_len = match_len + 1
            end

            if match_len > 0 then
                data:DeleteChars(word_start, word_end - word_start)
                data:InsertChars(data.CursorPos, candidates[1], match_len + 1)
            end

            self:AddLog("Possible matches:\n")
            for i = 0, candidates.Size - 1 do
                self:AddLog("- %s\n", candidates[i + 1])
            end
        end
    elseif event_flag == ImGuiInputTextFlags.CallbackHistory then
        local prev_history_pos = self.HistoryPos
        if data.EventKey == ImGuiKey.UpArrow then
            if self.HistoryPos == -1 then
                self.HistoryPos = self.History.Size - 1
            elseif self.HistoryPos > 0 then
                self.HistoryPos = self.HistoryPos - 1
            end
        elseif data.EventKey == ImGuiKey.DownArrow then
            if self.HistoryPos ~= -1 then
                self.HistoryPos = self.HistoryPos + 1
                if self.HistoryPos >= self.History.Size then
                    self.HistoryPos = -1
                end
            end
        end

        if prev_history_pos ~= self.HistoryPos then
            local history_str = (self.HistoryPos >= 0) and self.History[self.HistoryPos + 1] or ""
            data:DeleteChars(0, data.BufTextLen)
            data:InsertChars(0, history_str)
        end
    end
    return 0
end

local S_ShowExampleAppConsole = { console = Demo.ExampleAppConsole.new() }

function Demo.ShowExampleAppConsole(p_open)
    p_open = S_ShowExampleAppConsole.console:Draw("Example: Console", p_open)
    return p_open
end

local S_ShowExampleAppImageViewer = {}

function Demo.ShowExampleAppImageViewer(p_open)
    local S = S_ShowExampleAppImageViewer
    if S.image_viewer == nil then
        S.image_viewer = Demo.ExampleImageViewerData.new()
    end
    local atlas = ImGui.GetIO().Fonts
    local tex_ref = atlas.TexRef
    local tex_w = atlas.TexData.Width
    local tex_h = atlas.TexData.Height
    local visible
    visible, p_open = ImGui.Begin("Example: Image Viewer", p_open)
    if visible then
        Demo.ExampleImageViewer_DrawOptions(S.image_viewer)
        local canvas_size = ImGui.GetContentRegionAvail()
        local canvas_min_size = ImGui.IsWindowAppearing() and ImVec2(3.0 * tex_w, 4.0 * tex_h) or ImVec2(1.0, 1.0)
        canvas_size = ImVec2(Base.ImMax(canvas_size.x, canvas_min_size.x), Base.ImMax(canvas_size.y, canvas_min_size.y))
        Demo.ExampleImageViewer_DrawCanvas(S.image_viewer, canvas_size, tex_ref, tex_w, tex_h)
    end
    ImGui.End()
    return p_open
end

Demo.ExampleAppLog = {}
Demo.ExampleAppLog.__index = Demo.ExampleAppLog

function Demo.ExampleAppLog.new()
    local self = setmetatable({
        Buf = Base.ImGuiTextBuffer.new(),
        Filter = Base.ImGuiTextFilter.new(),
        LineOffsets = Base.ImVector.new(),
        AutoScroll = true,
    }, Demo.ExampleAppLog)
    self:Clear()
    return self
end

function Demo.ExampleAppLog:Clear()
    self.Buf:clear()
    self.LineOffsets:clear()
    self.LineOffsets:push_back(0)
end

function Demo.ExampleAppLog:AddLog(fmt, ...)
    local old_size = self.Buf:size()
    self.Buf:appendfv(fmt, ...)
    local new_size = self.Buf:size()
    for i = old_size, new_size - 1 do
        if self.Buf[i + 1] == 10 then
            self.LineOffsets:push_back(i + 1)
        end
    end
end

function Demo.ExampleAppLog:Draw(title, p_open)
    local visible
    visible, p_open = ImGui.Begin(title, p_open)
    if not visible then
        ImGui.End()
        return p_open
    end

    if ImGui.BeginPopup("Options") then
        _, self.AutoScroll = ImGui.Checkbox("Auto-scroll", self.AutoScroll)
        ImGui.EndPopup()
    end

    if ImGui.Button("Options") then
        ImGui.OpenPopup("Options")
    end
    ImGui.SameLine()
    local clear = ImGui.Button("Clear")
    ImGui.SameLine()
    local copy = ImGui.Button("Copy")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(-Base.FLT_MIN)
    self.Filter:DrawWithHint("##Filter", "Filter (incl -excl)")

    ImGui.Separator()

    if ImGui.BeginChild("scrolling", ImVec2(0, 0), ImGuiChildFlags.None, ImGuiWindowFlags.HorizontalScrollbar) then
        if clear then
            self:Clear()
        end
        if copy then
            ImGui.LogToClipboard()
        end

        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local buf = self.Buf:begin()
        local buf_end = #buf
        if self.Filter:IsActive() then
            for line_no = 0, self.LineOffsets.Size - 1 do
                local line_start = self.LineOffsets[line_no + 1]
                local line_end = (line_no + 1 < self.LineOffsets.Size) and (self.LineOffsets[line_no + 2] - 1) or buf_end
                local line = string.sub(buf, line_start + 1, line_end)
                if self.Filter:PassFilter(line) then
                    ImGui.TextUnformatted(line)
                end
            end
        else
            local clipper = Structs.ImGuiListClipper.new()
            clipper:Begin(self.LineOffsets.Size)
            while clipper:Step() do
                for line_no = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    local line_start = self.LineOffsets[line_no + 1]
                    local line_end = (line_no + 1 < self.LineOffsets.Size) and (self.LineOffsets[line_no + 2] - 1) or buf_end
                    ImGui.TextUnformatted(string.sub(buf, line_start + 1, line_end))
                end
            end
            clipper:End()
        end
        ImGui.PopStyleVar()

        if self.AutoScroll and ImGui.GetScrollY() >= ImGui.GetScrollMaxY() then
            ImGui.SetScrollHereY(1.0)
        end
    end
    ImGui.EndChild()
    ImGui.End()
    return p_open
end

local S_ShowExampleAppLog = { log = Demo.ExampleAppLog.new(), counter = 0 }

function Demo.ShowExampleAppLog(p_open)
    local S = S_ShowExampleAppLog
    ImGui.SetNextWindowSize(ImVec2(500, 400), ImGuiCond.FirstUseEver)
    _, p_open = ImGui.Begin("Example: Log", p_open)
    if ImGui.SmallButton("[Debug] Add 5 entries") then
        local categories = { "info", "warn", "error" }
        local words = { "Bumfuzzled", "Cattywampus", "Snickersnee", "Abibliophobia", "Absquatulate", "Nincompoop", "Pauciloquent" }
        for n = 0, 4 do
            local category = categories[(S.counter % #categories) + 1]
            local word = words[(S.counter % #words) + 1]
            S.log:AddLog("[%05d] [%s] Hello, current time is %.1f, here's a word: '%s'\n",
                ImGui.GetFrameCount(), category, ImGui.GetTime(), word)
            S.counter = S.counter + 1
        end
    end
    ImGui.End()

    p_open = S.log:Draw("Example: Log", p_open)
    return p_open
end

local S_ShowExampleAppLayout = { selected = 0 }

function Demo.ShowExampleAppLayout(p_open)
    local S = S_ShowExampleAppLayout
    ImGui.SetNextWindowSize(ImVec2(500, 440), ImGuiCond.FirstUseEver)
    local visible
    visible, p_open = ImGui.Begin("Example: Simple layout", p_open, ImGuiWindowFlags.MenuBar)
    if visible then
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("File") then
                if ImGui.MenuItem("Close", "Ctrl+W") then
                    p_open = false
                end
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end

        do
            ImGui.BeginChild("left pane", ImVec2(150, 0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeX))
            for i = 0, 99 do
                local label = Base.ImFormatString("MyObject %d", i)
                if ImGui.Selectable(label, S.selected == i, ImGuiSelectableFlags.SelectOnNav) then
                    S.selected = i
                end
            end
            ImGui.EndChild()
        end
        ImGui.SameLine()

        do
            ImGui.BeginGroup()
            ImGui.BeginChild("item view", ImVec2(0, -ImGui.GetFrameHeightWithSpacing()))
            ImGui.Text("MyObject: %d", S.selected)
            ImGui.Separator()
            if ImGui.BeginTabBar("##Tabs", ImGuiTabBarFlags.None) then
                if ImGui.BeginTabItem("Description") then
                    ImGui.TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ")
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Details") then
                    ImGui.Text("ID: 0123456789")
                    ImGui.EndTabItem()
                end
                ImGui.EndTabBar()
            end
            ImGui.EndChild()
            ImGui.Button("Revert")
            ImGui.SameLine()
            ImGui.Button("Save")
            ImGui.EndGroup()
        end
    end
    ImGui.End()
    return p_open
end

Demo.ExampleAppPropertyEditor = {}
Demo.ExampleAppPropertyEditor.__index = Demo.ExampleAppPropertyEditor

function Demo.ExampleAppPropertyEditor.new()
    return setmetatable({
        Filter = Base.ImGuiTextFilter.new(),
        SelectedNode = nil,
        UseClipper = false,
    }, Demo.ExampleAppPropertyEditor)
end

function Demo.ExampleAppPropertyEditor:Draw(root_node)
    if ImGui.BeginChild("##tree", ImVec2(300, 0), bit32.bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.Borders, ImGuiChildFlags.NavFlattened)) then
        ImGui.PushItemFlag(ImGuiItemFlags.NoNavDefaultFocus, true)
        _, self.UseClipper = ImGui.Checkbox("Use Clipper", self.UseClipper)
        ImGui.SameLine()
        ImGui.Text("(%d root nodes)", root_node.Childs.Size)
        ImGui.SetNextItemWidth(-Base.FLT_MIN)
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.F), ImGuiInputFlags.Tooltip)
        local changed
        changed, self.Filter.InputBuf = ImGui.InputTextWithHint("##Filter", "incl -excl", self.Filter.InputBuf, ImGuiInputTextFlags.EscapeClearsAll)
        if changed then
            self.Filter:Build()
        end
        ImGui.PopItemFlag()

        if ImGui.BeginTable("##list", 1, ImGuiTableFlags.RowBg) then
            if self.UseClipper then
                self:DrawClippedTree(root_node)
            else
                self:DrawTree(root_node)
            end
            ImGui.EndTable()
        end
    end
    ImGui.EndChild()

    ImGui.SameLine()

    ImGui.BeginGroup()
    local node = self.SelectedNode
    if node then
        ImGui.Text("%s", node.Name)
        ImGui.TextDisabled("UID: 0x%08X", node.UID)
        ImGui.Separator()
        if ImGui.BeginTable("##properties", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)) then
            ImGui.PushID(node.UID)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 2.0)
            if node.HasData then
                for _, field_desc in ipairs(Demo.ExampleTreeNodeMemberInfos) do
                    ImGui.TableNextRow()
                    ImGui.PushID(field_desc.Name)
                    ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextUnformatted(field_desc.Name)
                    ImGui.TableNextColumn()
                    local key = field_desc.Field
                    if field_desc.DataType == ImGuiDataType.Bool then
                        assert(field_desc.DataCount == 1)
                        _, node[key] = ImGui.Checkbox("##Editor", node[key])
                    elseif field_desc.DataType == ImGuiDataType.S32 then
                        local v_min, v_max = -2147483648, 2147483647
                        ImGui.SetNextItemWidth(-Base.FLT_MIN)
                        local t = { node[key] }
                        ImGui.DragScalarN("##Editor", ImGuiDataType.S32, t, field_desc.DataCount, 1.0, v_min, v_max)
                        node[key] = t[1]
                    elseif field_desc.DataType == ImGuiDataType.Float then
                        local v_min, v_max = 0.0, 1.0
                        ImGui.SetNextItemWidth(-Base.FLT_MIN)
                        local t = { node[key].x, node[key].y }
                        ImGui.SliderScalarN("##Editor", ImGuiDataType.Float, t, field_desc.DataCount, v_min, v_max)
                        node[key] = ImVec2(t[1], t[2])
                    elseif field_desc.DataType == ImGuiDataType.String then
                        _, node[key] = ImGui.InputText("##Editor", node[key])
                    end
                    ImGui.PopID()
                end
            end
            ImGui.PopID()
            ImGui.EndTable()
        end
    end
    ImGui.EndGroup()
end

function Demo.ExampleAppPropertyEditor:IsNodePassingFilter(node)
    return node.Parent.Parent ~= nil or self.Filter:PassFilter(node.Name)
end

function Demo.ExampleAppPropertyEditor:DrawTree(node)
    for i = 0, node.Childs.Size - 1 do
        local child = node.Childs[i + 1]
        if self:IsNodePassingFilter(child) and self:DrawTreeNode(child) then
            self:DrawTree(child)
            ImGui.TreePop()
        end
    end
end

function Demo.ExampleAppPropertyEditor:DrawClippedTree(root_node)
    local node = root_node.Childs[1]
    local clipper = Structs.ImGuiListClipper.new()
    clipper:Begin(2147483647)
    while clipper:Step() do
        while clipper.UserIndex < clipper.DisplayEnd and node ~= nil do
            node = self:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
        end
    end

    while node ~= nil do
        node = self:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
    end
    clipper:SeekCursorForItem(clipper.UserIndex)
end

function Demo.ExampleAppPropertyEditor:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
    if self:IsNodePassingFilter(node) then
        local is_open = false
        if clipper.UserIndex >= clipper.DisplayStart and clipper.UserIndex < clipper.DisplayEnd then
            is_open = self:DrawTreeNode(node)
        else
            is_open = node.Childs.Size > 0 and ImGui.TreeNodeGetOpen(node.UID)
            if is_open then
                ImGui.TreePush(node.Name)
            end
        end
        clipper.UserIndex = clipper.UserIndex + 1

        if is_open then
            return node.Childs[1]
        end
    end

    while node ~= nil do
        if node.IndexInParent + 1 < node.Parent.Childs.Size then
            return node.Parent.Childs[node.IndexInParent + 2]
        end
        node = node.Parent
        if node.Parent == nil then
            break
        end
        ImGui.TreePop()
    end
    return nil
end

function Demo.ExampleAppPropertyEditor:DrawTreeNode(node)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    local tree_flags = ImGuiTreeNodeFlags.None
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick)
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent)
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.SpanFullWidth)
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.DrawLinesToNodes)
    if node == self.SelectedNode then
        tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.Selected)
    end
    if node.Childs.Size == 0 then
        tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.NoTreePushOnOpen)
    end
    if node.DataMyBool == false then
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyle().Colors[ImGuiCol.TextDisabled + 1])
    end
    ImGui.SetNextItemStorageID(node.UID)
    local is_open = ImGui.TreeNodeEx(node.UID, tree_flags, "%s", node.Name)
    if node.Childs.Size == 0 then
        is_open = false
    end
    if node.DataMyBool == false then
        ImGui.PopStyleColor()
    end
    if ImGui.IsItemFocused() then
        self.SelectedNode = node
    end
    return is_open
end

local S_ShowExampleAppPropertyEditor = { property_editor = Demo.ExampleAppPropertyEditor.new() }

function Demo.ShowExampleAppPropertyEditor(p_open, demo_data)
    local S = S_ShowExampleAppPropertyEditor
    ImGui.SetNextWindowSize(ImVec2(430, 450), ImGuiCond.FirstUseEver)
    local visible
    visible, p_open = ImGui.Begin("Example: Property editor", p_open)
    if not visible then
        ImGui.End()
        return p_open
    end

    if demo_data.DemoTree == nil then
        demo_data.DemoTree = Demo.ExampleTree_CreateDemoTree()
    end
    S.property_editor:Draw(demo_data.DemoTree)

    ImGui.End()
    return p_open
end

return true
