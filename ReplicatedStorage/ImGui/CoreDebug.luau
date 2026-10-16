local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local DrawList = require("./DrawList")

local ImVec2, ImVec4, ImRect = Base.ImVec2, Base.ImVec4, Base.ImRect
local ImMin, ImMax = Base.ImMin, Base.ImMax
local ImTrunc = Base.ImTrunc
local ImFormatString = Base.ImFormatString
local ImTruncToInt = Base.ImTruncToInt
local IM_COL32 = Base.IM_COL32
local FLT_MAX, FLT_MIN = Base.FLT_MAX, Base.FLT_MIN

local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiCol = Enums.ImGuiCol
local ImGuiTableFlags = Enums.ImGuiTableFlags
local ImGuiTableColumnFlags = Enums.ImGuiTableColumnFlags
local ImGuiTableBgTarget = Enums.ImGuiTableBgTarget
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiCond = Enums.ImGuiCond
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiKeyOwner = Enums.ImGuiKeyOwner
local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiTreeNodeFlags = Enums.ImGuiTreeNodeFlags
local ImGuiNavLayer = Enums.ImGuiNavLayer
local ImGuiViewportFlags = Enums.ImGuiViewportFlags
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImGuiNextWindowDataFlags = Enums.ImGuiNextWindowDataFlags
local ImGuiHoveredFlags = Enums.ImGuiHoveredFlags
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiDataType = Enums.ImGuiDataType
local ImGuiSelectableFlags = Enums.ImGuiSelectableFlags
local ImDrawFlags = Enums.ImDrawFlags
local ImFontAtlasRectId = Enums.ImFontAtlasRectId
local IM_UNICODE_CODEPOINT_MAX = Enums.Defines.IM_UNICODE_CODEPOINT_MAX

local DEBUG_LOCATE_ITEM_COLOR = IM_COL32(0, 255, 0, 255)
local _

local function BoolToInt(b)
	return b and 1 or 0
end

local function PtrToNum(p)
	if p == nil then
		return 0
	end
	if type(p) == "number" then
		return p
	end
	return Base.ImPtrToInt(p)
end

function ImGui.MetricsHelpMarker(desc)
	ImGui.TextDisabled("(?)")
	if ImGui.BeginItemTooltip() then
		ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
		ImGui.TextUnformatted(desc)
		ImGui.PopTextWrapPos()
		ImGui.EndTooltip()
	end
end

function ImGui.DebugRenderViewportThumbnail(draw_list, viewport, bb)
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local scale = bb:GetSize() / viewport.Size
	local off = bb.Min - viewport.Pos * scale
	local alpha_mul = 1.0
	window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Border, alpha_mul * 0.40))
	for i = 0, g.Windows.Size - 1 do
		local thumb_window = g.Windows[i + 1]
		if not thumb_window.WasActive or bit32.btest(thumb_window.Flags, ImGuiWindowFlags.ChildWindow) then
			continue
		end

		local thumb_r = thumb_window:Rect()
		local title_r = thumb_window:TitleBarRect()
		thumb_r = ImRect.new(ImTrunc(off + thumb_r.Min * scale), ImTrunc(off + thumb_r.Max * scale))
		title_r = ImRect.new(ImTrunc(off + title_r.Min * scale), ImTrunc(off + ImVec2(title_r.Max.x, title_r.Min.y + title_r:GetHeight() * 3.0) * scale))
		thumb_r = thumb_r:ClippedWithFull(bb)
		title_r = title_r:ClippedWithFull(bb)
		local window_is_focused = (g.NavWindow ~= nil and thumb_window.RootWindowForTitleBarHighlight == g.NavWindow.RootWindowForTitleBarHighlight)
		window.DrawList:AddRectFilled(thumb_r.Min, thumb_r.Max, ImGui.GetColorU32(ImGuiCol.WindowBg, alpha_mul))
		window.DrawList:AddRectFilled(title_r.Min, title_r.Max, ImGui.GetColorU32(window_is_focused and ImGuiCol.TitleBgActive or ImGuiCol.TitleBg, alpha_mul))
		window.DrawList:AddRect(thumb_r.Min, thumb_r.Max, ImGui.GetColorU32(ImGuiCol.Border, alpha_mul))
		window.DrawList:AddText(g.Font, g.FontSize * 1.0, title_r.Min, ImGui.GetColorU32(ImGuiCol.Text, alpha_mul), thumb_window.Name, ImGui.FindRenderedTextEnd(thumb_window.Name))
	end
	draw_list:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Border, alpha_mul))
	if viewport.ID == g.DebugMetricsConfig.HighlightViewportID then
		window.DrawList:AddRect(bb.Min, bb.Max, IM_COL32(255, 255, 0, 255))
	end
end

function ImGui.RenderViewportsThumbnails()
	local g = ImGui.GImGui
	local window = g.CurrentWindow

	local SCALE = 1.0 / 8.0
	local bb_full = ImRect.new(g.Viewports[1].Pos, g.Viewports[1].Pos + g.Viewports[1].Size)
	local p = window.DC.CursorPos
	local off = p - bb_full.Min * SCALE

	for i = 0, g.Viewports.Size - 1 do
		local viewport = g.Viewports[i + 1]
		local viewport_draw_bb = ImRect.new(off + viewport.Pos * SCALE, off + (viewport.Pos + viewport.Size) * SCALE)
		ImGui.DebugRenderViewportThumbnail(window.DrawList, viewport, viewport_draw_bb)
	end
	ImGui.Dummy(bb_full:GetSize() * SCALE)
end

local KEYS_TO_DISPLAY = {
	{ 0, 0, "", "Tab" }, { 0, 1, "Q", "Q" }, { 0, 2, "W", "W" }, { 0, 3, "E", "E" }, { 0, 4, "R", "R" },
	{ 1, 0, "", "CapsLock" }, { 1, 1, "A", "A" }, { 1, 2, "S", "S" }, { 1, 3, "D", "D" }, { 1, 4, "F", "F" },
	{ 2, 0, "", "LeftShift" }, { 2, 1, "Z", "Z" }, { 2, 2, "X", "X" }, { 2, 3, "C", "C" }, { 2, 4, "V", "V" },
}

function ImGui.DebugRenderKeyboardPreview(draw_list)
	local scale = ImGui.GetFontSize() / 13.0
	local key_size = ImVec2(35.0, 35.0) * scale
	local key_rounding = 3.0 * scale
	local key_face_size = ImVec2(25.0, 25.0) * scale
	local key_face_pos = ImVec2(5.0, 3.0) * scale
	local key_face_rounding = 2.0 * scale
	local key_label_pos = ImVec2(7.0, 4.0) * scale
	local key_step = ImVec2(key_size.x - 1.0, key_size.y - 1.0)
	local key_row_offset = 9.0 * scale

	local board_min = ImGui.GetCursorScreenPos()
	local board_max = ImVec2(board_min.x + 3 * key_step.x + 2 * key_row_offset + 10.0, board_min.y + 3 * key_step.y + 10.0)
	local start_pos = ImVec2(board_min.x + 5.0 - key_step.x, board_min.y)

	ImGui.Dummy(board_max - board_min)
	if not ImGui.IsItemVisible() then
		return
	end
	draw_list:PushClipRect(board_min, board_max, true)
	for n = 1, #KEYS_TO_DISPLAY do
		local key_data = KEYS_TO_DISPLAY[n]
		local row, col, label, key = key_data[1], key_data[2], key_data[3], ImGuiKey[key_data[4]]
		local key_min = ImVec2(start_pos.x + col * key_step.x + row * key_row_offset, start_pos.y + row * key_step.y)
		local key_max = key_min + key_size
		draw_list:AddRectFilled(key_min, key_max, IM_COL32(204, 204, 204, 255), key_rounding)
		draw_list:AddRect(key_min, key_max, IM_COL32(24, 24, 24, 255), key_rounding)
		local face_min = ImVec2(key_min.x + key_face_pos.x, key_min.y + key_face_pos.y)
		local face_max = ImVec2(face_min.x + key_face_size.x, face_min.y + key_face_size.y)
		draw_list:AddRect(face_min, face_max, IM_COL32(193, 193, 193, 255), key_face_rounding, 2.0)
		draw_list:AddRectFilled(face_min, face_max, IM_COL32(252, 252, 252, 255), key_face_rounding)
		local label_min = ImVec2(key_min.x + key_label_pos.x, key_min.y + key_label_pos.y)
		draw_list:AddText(label_min, IM_COL32(64, 64, 64, 255), label)
		if ImGui.IsKeyDown(key) then
			draw_list:AddRectFilled(key_min, key_max, IM_COL32(255, 0, 0, 128), key_rounding)
		end
	end
	draw_list:PopClipRect()
end

function ImGui.DebugTextEncoding(str)
	ImGui.Text("Text: \"%s\"", str)
	if not ImGui.BeginTable("##DebugTextEncoding", 4, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Resizable)) then
		return
	end
	ImGui.TableSetupColumn("Offset")
	ImGui.TableSetupColumn("UTF-8")
	ImGui.TableSetupColumn("Glyph")
	ImGui.TableSetupColumn("Codepoint")
	ImGui.TableHeadersRow()
	local str_end = #str + 1
	local p = 1
	while p < str_end and string.byte(str, p) ~= 0 do
		local c_utf8_len, c = Base.ImTextCharFromUtf8(str, p, str_end)
		ImGui.TableNextColumn()
		ImGui.Text("%d", p - 1)
		ImGui.TableNextColumn()
		for byte_index = 0, c_utf8_len - 1 do
			if byte_index > 0 then
				ImGui.SameLine()
			end
			ImGui.Text("0x%02X", string.byte(str, p + byte_index) or 0)
		end
		ImGui.TableNextColumn()
		ImGui.TextUnformatted(string.sub(str, p, p + c_utf8_len - 1))
		if not ImGui.GetFont():IsGlyphInFont(c) then
			ImGui.SameLine()
			ImGui.TextUnformatted("[missing]")
		end
		ImGui.TableNextColumn()
		ImGui.Text("U+%04X", c)
		p += c_utf8_len
	end
	ImGui.EndTable()
end

function ImGui.DebugFlashStyleColorStop()
	local g = ImGui.GImGui
	if g.DebugFlashStyleColorIdx ~= ImGuiCol.COUNT then
		g.Style.Colors[g.DebugFlashStyleColorIdx + 1] = g.DebugFlashStyleColorBackup
	end
	g.DebugFlashStyleColorIdx = ImGuiCol.COUNT
end

function ImGui.DebugFlashStyleColor(idx)
	local g = ImGui.GImGui
	ImGui.DebugFlashStyleColorStop()
	g.DebugFlashStyleColorTime = 0.5
	g.DebugFlashStyleColorIdx = idx
	g.DebugFlashStyleColorBackup = g.Style.Colors[idx + 1]
end

function ImGui.UpdateDebugToolFlashStyleColor()
	local g = ImGui.GImGui
	if g.DebugFlashStyleColorTime <= 0.0 then
		return
	end
	local r, gr, b = ImGui.ColorConvertHSVtoRGB(Base.ImCos(g.DebugFlashStyleColorTime * 6.0) * 0.5 + 0.5, 0.5, 0.5)
	g.Style.Colors[g.DebugFlashStyleColorIdx + 1] = ImVec4(r, gr, b, 1.0)
	g.DebugFlashStyleColorTime -= g.IO.DeltaTime
	if g.DebugFlashStyleColorTime <= 0.0 then
		ImGui.DebugFlashStyleColorStop()
	end
end

function ImGui.DebugTextureIDToU64(tex_id)
	return PtrToNum(tex_id)
end

function ImGui.FormatTextureRefForDebugDisplay(tex_ref)
	local buf = ""
	local tex_id = tex_ref
	if type(tex_ref) == "table" and tex_ref.GetTexID ~= nil then
		if tex_ref._TexData ~= nil then
			buf = ImFormatString("#%03d: ", tex_ref._TexData.UniqueID)
		end
		tex_id = tex_ref:GetTexID()
	end
	if type(tex_id) == "string" then
		return buf .. tex_id
	end
	return buf .. ImFormatString("0x%X", ImGui.DebugTextureIDToU64(tex_id))
end

function ImGui.ShowFontAtlas(atlas)
	local g = ImGui.GImGui
	local io = g.IO
	local style = g.Style
	local changed

	ImGui.BeginDisabled()
	_, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasTextures", io.BackendFlags, ImGuiBackendFlags.RendererHasTextures)
	ImGui.EndDisabled()
	ImGui.ShowFontSelector("Font")
	changed, style.FontSizeBase = ImGui.DragFloat("FontSizeBase", style.FontSizeBase, 0.20, 5.0, 100.0, "%.0f")
	if changed then
		style._NextFrameFontSizeBase = style.FontSizeBase
	end
	ImGui.SameLine(0.0, 0.0)
	ImGui.Text(" (out %.2f)", ImGui.GetFontSize())
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("- This is scaling font only. General scaling will come later.")
	_, style.FontScaleMain = ImGui.DragFloat("FontScaleMain", style.FontScaleMain, 0.02, 0.5, 4.0)
	_, style.FontScaleDpi = ImGui.DragFloat("FontScaleDpi", style.FontScaleDpi, 0.02, 0.5, 4.0)
	if bit32.band(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures) == 0 then
		ImGui.BulletText("Warning: Font scaling will NOT be smooth, because\nImGuiBackendFlags_RendererHasTextures is not set!")
		ImGui.BulletText("For instructions, see:")
		ImGui.SameLine()
		ImGui.TextLinkOpenURL("docs/BACKENDS.md", "https://github.com/ocornut/imgui/blob/master/docs/BACKENDS.md")
	end
	ImGui.BulletText("Load a nice font for better results!")
	ImGui.BulletText("Please submit feedback:")
	ImGui.SameLine()
	ImGui.TextLinkOpenURL("#8465", "https://github.com/ocornut/imgui/issues/8465")
	ImGui.BulletText("Read FAQ for more details:")
	ImGui.SameLine()
	ImGui.TextLinkOpenURL("dearimgui.com/faq", "https://www.dearimgui.com/faq/")

	ImGui.SeparatorText("Font List")

	local cfg = g.DebugMetricsConfig
	_, cfg.ShowFontPreview = ImGui.Checkbox("Show font preview", cfg.ShowFontPreview)

	if ImGui.TreeNode("Loader", "Loader: '%s'", atlas.FontLoaderName or "NULL") then
		ImGui.BeginDisabled(not atlas.RendererHasTextures)
		ImGui.BeginDisabled()
		ImGui.RadioButton("stb_truetype", false)
		ImGui.SetItemTooltip("Requires #define IMGUI_ENABLE_STB_TRUETYPE")
		ImGui.EndDisabled()
		ImGui.SameLine()
		ImGui.BeginDisabled()
		ImGui.RadioButton("FreeType", false)
		ImGui.SetItemTooltip("Requires #define IMGUI_ENABLE_FREETYPE + imgui_freetype.cpp.")
		ImGui.EndDisabled()
		ImGui.EndDisabled()
		ImGui.TreePop()
	end

	for i = 0, atlas.Fonts.Size - 1 do
		local font = atlas.Fonts[i + 1]
		ImGui.PushID(font)
		ImGui.DebugNodeFont(font)
		ImGui.PopID()
	end

	ImGui.SeparatorText("Font Atlas")
	if ImGui.Button("Compact") then
		atlas:CompactCache()
	end
	ImGui.SameLine()
	if ImGui.Button("Grow") then
		DrawList.ImFontAtlasTextureGrow(atlas)
	end
	ImGui.SameLine()
	if ImGui.Button("Clear All") then
		DrawList.ImFontAtlasBuildClear(atlas)
	end
	ImGui.SetItemTooltip("Destroy cache and custom rectangles.")

	local tex_list = atlas.TexList
	for tex_n = 0, tex_list.Size - 1 do
		local tex = tex_list[tex_n + 1]
		if tex_n > 0 then
			ImGui.SameLine()
		end
		ImGui.Text("Tex: %dx%d", tex.Width, tex.Height)
	end

	local builder = atlas.Builder
	local highlight_r_id = ImFontAtlasRectId.Invalid
	if builder ~= nil then
		local packed_surface_sqrt = ImTruncToInt(math.sqrt(builder.RectsPackedSurface))
		local discarded_surface_sqrt = ImTruncToInt(math.sqrt(builder.RectsDiscardedSurface))
		ImGui.Text("Packed rects: %d, area: about %d px ~%dx%d px", builder.RectsPackedCount, builder.RectsPackedSurface, packed_surface_sqrt, packed_surface_sqrt)
		ImGui.Text("incl. Discarded rects: %d, area: about %d px ~%dx%d px", builder.RectsDiscardedCount, builder.RectsDiscardedSurface, discarded_surface_sqrt, discarded_surface_sqrt)

		if ImGui.TreeNode("Rects Index", "Rects Index (%d)", builder.RectsPackedCount) then
			ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, 1.0)
			if ImGui.BeginTable("##table", 2, bit32.bor(ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.ScrollY), ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 12)) then
				for entry_n = 0, builder.RectsIndex.Size - 1 do
					local entry = builder.RectsIndex[entry_n + 1]
					if entry.IsUsed then
						local id = bit32.bor(entry_n, bit32.lshift(entry.Generation, ImFontAtlasRectId.GenerationShift_))
						local r = { x = 0, y = 0, w = 0, h = 0 }
						atlas:GetCustomRect(id, r)
						ImGui.TableNextColumn()
						ImGui.Selectable(ImFormatString("ID:%08X, used:%d, { w:%3d, h:%3d } { x:%4d, y:%4d }", id, BoolToInt(entry.IsUsed), r.w, r.h, r.x, r.y))
						if ImGui.IsItemHovered() then
							highlight_r_id = id
						end
						ImGui.TableNextColumn()
					end
				end
				ImGui.EndTable()
			end
			ImGui.PopStyleVar()
			ImGui.TreePop()
		end
	end

	local highlight_r = nil
	if highlight_r_id ~= ImFontAtlasRectId.Invalid then
		highlight_r = { x = 0, y = 0, w = 0, h = 0 }
		atlas:GetCustomRect(highlight_r_id, highlight_r)
	end
	for tex_n = 0, tex_list.Size - 1 do
		if tex_n == tex_list.Size - 1 then
			ImGui.SetNextItemOpen(true, ImGuiCond.Once)
		end
		ImGui.DebugNodeTexture(tex_list[tex_n + 1], tex_list.Size - 1 - tex_n, highlight_r)
	end
end

function ImGui.DebugNodeTexture(tex, int_id, highlight_rect)
	local g = ImGui.GImGui
	ImGui.PushID(int_id)
	if ImGui.TreeNode("", "Texture #%03d (%dx%d pixels)", tex.UniqueID, tex.Width, tex.Height) then
		local cfg = g.DebugMetricsConfig
		_, cfg.ShowTextureUsedRect = ImGui.Checkbox("Show used rect", cfg.ShowTextureUsedRect)
		ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, ImMax(1.0, g.Style.ImageBorderSize))
		local p = ImGui.GetCursorScreenPos()
		ImGui.Dummy(ImVec2(tex.Width, tex.Height))
		if cfg.ShowTextureUsedRect then
			ImGui.GetWindowDrawList():AddRect(ImVec2(p.x + tex.UsedRect.x, p.y + tex.UsedRect.y), ImVec2(p.x + tex.UsedRect.x + tex.UsedRect.w, p.y + tex.UsedRect.y + tex.UsedRect.h), IM_COL32(255, 0, 255, 255))
		end
		if highlight_rect ~= nil then
			local r_outer = ImRect.fromXY(p.x, p.y, p.x + tex.Width, p.y + tex.Height)
			local r_inner = ImRect.fromXY(p.x + highlight_rect.x, p.y + highlight_rect.y, p.x + highlight_rect.x + highlight_rect.w, p.y + highlight_rect.y + highlight_rect.h)
			ImGui.RenderRectFilledWithHole(ImGui.GetWindowDrawList(), r_outer, r_inner, IM_COL32(0, 0, 0, 100), 0.0)
			ImGui.GetWindowDrawList():AddRect(r_inner.Min - ImVec2(1, 1), r_inner.Max + ImVec2(1, 1), IM_COL32(255, 255, 0, 255))
		end
		ImGui.PopStyleVar()

		ImGui.Text("Status = %s (%d), Format = %s (%d), UseColors = %d", DrawList.ImTextureDataGetStatusName(tex.Status), tex.Status, DrawList.ImTextureDataGetFormatName(tex.Format), tex.Format, BoolToInt(tex.UseColors))
		ImGui.Text("TexRef = %s, BackendUserData = %p", ImGui.FormatTextureRefForDebugDisplay(tex:GetTexRef()), PtrToNum(tex.BackendUserData))
		ImGui.TreePop()
	end
	ImGui.PopID()
end

local S_ShowMetricsWindow = { buf = "" }

local WRT_OuterRect, WRT_OuterRectClipped, WRT_InnerRect, WRT_InnerClipRect, WRT_WorkRect, WRT_Content, WRT_ContentIdeal, WRT_ContentRegionRect, WRT_Count = 0, 1, 2, 3, 4, 5, 6, 7, 8
local wrt_rects_names = { "OuterRect", "OuterRectClipped", "InnerRect", "InnerClipRect", "WorkRect", "Content", "ContentIdeal", "ContentRegionRect" }
local TRT_OuterRect, TRT_InnerRect, TRT_WorkRect, TRT_HostClipRect, TRT_InnerClipRect, TRT_BackgroundClipRect, TRT_ColumnsRect, TRT_ColumnsWorkRect, TRT_ColumnsClipRect, TRT_ColumnsContentHeadersUsed, TRT_ColumnsContentHeadersIdeal, TRT_ColumnsContentFrozen, TRT_ColumnsContentUnfrozen, TRT_Count = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
local trt_rects_names = { "OuterRect", "InnerRect", "WorkRect", "HostClipRect", "InnerClipRect", "BackgroundClipRect", "ColumnsRect", "ColumnsWorkRect", "ColumnsClipRect", "ColumnsContentHeadersUsed", "ColumnsContentHeadersIdeal", "ColumnsContentFrozen", "ColumnsContentUnfrozen" }

local function GetTableRect(tbl, rect_type, n)
	local table_instance = ImGui.TableGetInstanceData(tbl, tbl.InstanceCurrent)
	if rect_type == TRT_OuterRect then
		return tbl.OuterRect
	elseif rect_type == TRT_InnerRect then
		return tbl.InnerRect
	elseif rect_type == TRT_WorkRect then
		return tbl.WorkRect
	elseif rect_type == TRT_HostClipRect then
		return tbl.HostClipRect
	elseif rect_type == TRT_InnerClipRect then
		return tbl.InnerClipRect
	elseif rect_type == TRT_BackgroundClipRect then
		return tbl.BgClipRect
	elseif rect_type == TRT_ColumnsRect then
		local c = tbl.Columns[n + 1]
		return ImRect.fromXY(c.MinX, tbl.InnerClipRect.Min.y, c.MaxX, tbl.InnerClipRect.Min.y + table_instance.LastOuterHeight)
	elseif rect_type == TRT_ColumnsWorkRect then
		local c = tbl.Columns[n + 1]
		return ImRect.fromXY(c.WorkMinX, tbl.WorkRect.Min.y, c.WorkMaxX, tbl.WorkRect.Max.y)
	elseif rect_type == TRT_ColumnsClipRect then
		local c = tbl.Columns[n + 1]
		return c.ClipRect
	elseif rect_type == TRT_ColumnsContentHeadersUsed then
		local c = tbl.Columns[n + 1]
		return ImRect.fromXY(c.WorkMinX, tbl.InnerClipRect.Min.y, c.ContentMaxXHeadersUsed, tbl.InnerClipRect.Min.y + table_instance.LastTopHeadersRowHeight)
	elseif rect_type == TRT_ColumnsContentHeadersIdeal then
		local c = tbl.Columns[n + 1]
		return ImRect.fromXY(c.WorkMinX, tbl.InnerClipRect.Min.y, c.ContentMaxXHeadersIdeal, tbl.InnerClipRect.Min.y + table_instance.LastTopHeadersRowHeight)
	elseif rect_type == TRT_ColumnsContentFrozen then
		local c = tbl.Columns[n + 1]
		return ImRect.fromXY(c.WorkMinX, tbl.InnerClipRect.Min.y, c.ContentMaxXFrozen, tbl.InnerClipRect.Min.y + table_instance.LastFrozenHeight)
	elseif rect_type == TRT_ColumnsContentUnfrozen then
		local c = tbl.Columns[n + 1]
		return ImRect.fromXY(c.WorkMinX, tbl.InnerClipRect.Min.y + table_instance.LastFrozenHeight, c.ContentMaxXUnfrozen, tbl.InnerClipRect.Max.y)
	end
	assert(false)
	return ImRect.new()
end

local function GetWindowRect(window, rect_type)
	if rect_type == WRT_OuterRect then
		return window:Rect()
	elseif rect_type == WRT_OuterRectClipped then
		return window.OuterRectClipped
	elseif rect_type == WRT_InnerRect then
		return window.InnerRect
	elseif rect_type == WRT_InnerClipRect then
		return window.InnerClipRect
	elseif rect_type == WRT_WorkRect then
		return window.WorkRect
	elseif rect_type == WRT_Content then
		local min = window.InnerRect.Min - window.Scroll + window.WindowPadding
		return ImRect.new(min, min + window.ContentSize)
	elseif rect_type == WRT_ContentIdeal then
		local min = window.InnerRect.Min - window.Scroll + window.WindowPadding
		return ImRect.new(min, min + window.ContentSizeIdeal)
	elseif rect_type == WRT_ContentRegionRect then
		return window.ContentRegionRect
	end
	assert(false)
	return ImRect.new()
end

local function ShowMetricsTools(g, io, cfg)
	ImGui.SeparatorTextEx(0, "Debug breaks", nil, ImGui.CalcTextSize("(?)").x + g.Style.SeparatorTextPadding.x)
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("Will call the IM_DEBUG_BREAK() macro to break in debugger.\nWarning: If you don't have a debugger attached, this will probably crash.")
	local pressed, changed
	pressed, g.DebugItemPickerActive = ImGui.Checkbox("Show Item Picker", g.DebugItemPickerActive)
	if pressed and g.DebugItemPickerActive then
		ImGui.DebugStartItemPicker()
	end
	_, g.IO.ConfigDebugIsDebuggerPresent = ImGui.Checkbox("Show \"Debug Break\" buttons in other sections (io.ConfigDebugIsDebuggerPresent)", g.IO.ConfigDebugIsDebuggerPresent)

	ImGui.SeparatorText("Visualize")

	_, cfg.ShowDebugLog = ImGui.Checkbox("Show Debug Log", cfg.ShowDebugLog)
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("You can also call ImGui::ShowDebugLogWindow() from your code.")

	_, cfg.ShowIDStackTool = ImGui.Checkbox("Show ID Stack Tool", cfg.ShowIDStackTool)
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("You can also call ImGui::ShowIDStackToolWindow() from your code.")

	_, cfg.ShowWindowsBeginOrder = ImGui.Checkbox("Show windows begin order", cfg.ShowWindowsBeginOrder)
	_, cfg.ShowWindowsRects = ImGui.Checkbox("Show windows rectangles", cfg.ShowWindowsRects)
	ImGui.SameLine()
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 12)
	changed, cfg.ShowWindowsRectsType = ImGui.Combo("##show_windows_rect_type", cfg.ShowWindowsRectsType, wrt_rects_names, WRT_Count, WRT_Count)
	cfg.ShowWindowsRects = cfg.ShowWindowsRects or changed
	if cfg.ShowWindowsRects and g.NavWindow ~= nil then
		ImGui.BulletText("'%s':", g.NavWindow.Name)
		ImGui.Indent()
		for rect_n = 0, WRT_Count - 1 do
			local r = GetWindowRect(g.NavWindow, rect_n)
			ImGui.Text("(%6.1f,%6.1f) (%6.1f,%6.1f) Size (%6.1f,%6.1f) %s", r.Min.x, r.Min.y, r.Max.x, r.Max.y, r:GetWidth(), r:GetHeight(), wrt_rects_names[rect_n + 1])
		end
		ImGui.Unindent()
	end

	_, cfg.ShowTablesRects = ImGui.Checkbox("Show tables rectangles", cfg.ShowTablesRects)
	ImGui.SameLine()
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 12)
	changed, cfg.ShowTablesRectsType = ImGui.Combo("##show_table_rects_type", cfg.ShowTablesRectsType, trt_rects_names, TRT_Count, TRT_Count)
	cfg.ShowTablesRects = cfg.ShowTablesRects or changed
	if cfg.ShowTablesRects and g.NavWindow ~= nil then
		for table_n = 0, g.Tables:GetMapSize() - 1 do
			local tbl = g.Tables:TryGetMapData(table_n)
			if tbl == nil or tbl.LastFrameActive < g.FrameCount - 1 or (tbl.OuterWindow ~= g.NavWindow and tbl.InnerWindow ~= g.NavWindow) then
				continue
			end

			ImGui.BulletText("Table 0x%08X (%d columns, in '%s')", tbl.ID, tbl.ColumnsCount, tbl.OuterWindow.Name)
			if ImGui.IsItemHovered() then
				ImGui.GetForegroundDrawList():AddRect(tbl.OuterRect.Min - ImVec2(1, 1), tbl.OuterRect.Max + ImVec2(1, 1), IM_COL32(255, 255, 0, 255), 0.0, 2.0)
			end
			ImGui.Indent()
			for rect_n = 0, TRT_Count - 1 do
				if rect_n >= TRT_ColumnsRect then
					if rect_n ~= TRT_ColumnsRect and rect_n ~= TRT_ColumnsClipRect then
						continue
					end
					for column_n = 0, tbl.ColumnsCount - 1 do
						local r = GetTableRect(tbl, rect_n, column_n)
						local buf = ImFormatString("(%6.1f,%6.1f) (%6.1f,%6.1f) Size (%6.1f,%6.1f) Col %d %s", r.Min.x, r.Min.y, r.Max.x, r.Max.y, r:GetWidth(), r:GetHeight(), column_n, trt_rects_names[rect_n + 1])
						ImGui.Selectable(buf)
						if ImGui.IsItemHovered() then
							ImGui.GetForegroundDrawList():AddRect(r.Min - ImVec2(1, 1), r.Max + ImVec2(1, 1), IM_COL32(255, 255, 0, 255), 0.0, 2.0)
						end
					end
				else
					local r = GetTableRect(tbl, rect_n, -1)
					local buf = ImFormatString("(%6.1f,%6.1f) (%6.1f,%6.1f) Size (%6.1f,%6.1f) %s", r.Min.x, r.Min.y, r.Max.x, r.Max.y, r:GetWidth(), r:GetHeight(), trt_rects_names[rect_n + 1])
					ImGui.Selectable(buf)
					if ImGui.IsItemHovered() then
						ImGui.GetForegroundDrawList():AddRect(r.Min - ImVec2(1, 1), r.Max + ImVec2(1, 1), IM_COL32(255, 255, 0, 255), 0.0, 2.0)
					end
				end
			end
			ImGui.Unindent()
		end
	end
	_, g.DebugShowGroupRects = ImGui.Checkbox("Show groups rectangles", g.DebugShowGroupRects)

	ImGui.SeparatorText("Validate")

	_, io.ConfigDebugBeginReturnValueLoop = ImGui.Checkbox("Debug Begin/BeginChild return value", io.ConfigDebugBeginReturnValueLoop)
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("Some calls to Begin()/BeginChild() will return false.\n\nWill cycle through window depths then repeat. Windows should be flickering while running.")

	_, cfg.ShowTextEncodingViewer = ImGui.Checkbox("UTF-8 Encoding viewer", cfg.ShowTextEncodingViewer)
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("You can also call ImGui::DebugTextEncoding() from your code with a given string to test that your UTF-8 encoding settings are correct.")
	if cfg.ShowTextEncodingViewer then
		local S = S_ShowMetricsWindow
		ImGui.SetNextItemWidth(-FLT_MIN)
		_, S.buf = ImGui.InputText("##DebugTextEncodingBuf", S.buf)
		if S.buf ~= "" then
			ImGui.DebugTextEncoding(S.buf)
		end
	end
end

local function ShowMetricsSettings(g, io, platform_io, cfg)
	if ImGui.SmallButton("Clear") then
		ImGui.ClearIniSettings()
	end
	ImGui.SameLine()
	if ImGui.SmallButton("Save to memory") then
		ImGui.SaveIniSettingsToMemory()
	end
	ImGui.SameLine()
	if ImGui.SmallButton("Save to disk") then
		ImGui.SaveIniSettingsToDisk(g.IO.IniFilename)
	end
	ImGui.SameLine()
	if g.IO.IniFilename then
		ImGui.Text("\"%s\"", g.IO.IniFilename)
	else
		ImGui.TextUnformatted("<NULL>")
	end
	ImGui.Text("SettingsDirtyTimer %.2f", g.SettingsDirtyTimer)

	local highlight_older_than_date = 0
	ImGui.Text("SessionDate: %d", platform_io.Platform_SessionDate)
	ImGui.BeginDisabled(platform_io.Platform_SessionDate == 0)
	_, cfg.SettingsHighlightOldEntries = ImGui.Checkbox("Highlight Entries Older Than", cfg.SettingsHighlightOldEntries)
	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
	ImGui.SameLine()
	_, cfg.SettingsDiscardMonths = ImGui.SliderInt("Months", cfg.SettingsDiscardMonths, 1, 24)
	if cfg.SettingsHighlightOldEntries and cfg.SettingsDiscardMonths > 0 then
		local cutoff_date = Structs.ImGuiPackedDate.new(platform_io.Platform_SessionDate)
		cutoff_date:SubtractMonths(cfg.SettingsDiscardMonths)
		highlight_older_than_date = cutoff_date:Unpack()
		ImGui.SameLine()
		local cleanup_args = Structs.ImGuiSettingsCleanupArgs.new()
		cleanup_args.DiscardOlderThanMonths = cfg.SettingsDiscardMonths
		if ImGui.Button("Discard") then
			ImGui.CleanupIniSettings(cleanup_args)
		end
	end
	ImGui.EndDisabled()
	_, io.ConfigDebugIniSettings = ImGui.Checkbox("io.ConfigDebugIniSettings", io.ConfigDebugIniSettings)

	local function PushHighlightOlderThan(cutoff_date, in_date)
		local highlight = cutoff_date ~= 0 and in_date:Unpack() < cutoff_date
		if highlight then
			ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.0, 0.4, 0.4, 1.0))
		end
		return highlight
	end

	if ImGui.TreeNode("SettingsHandlers", "Settings handlers: (%d)", g.SettingsHandlers.Size) then
		for i = 0, g.SettingsHandlers.Size - 1 do
			ImGui.BulletText("\"%s\"", g.SettingsHandlers[i + 1].TypeName)
		end
		ImGui.TreePop()
	end
	if ImGui.TreeNode("SettingsWindows", "Settings packed data: Windows: %d bytes", g.SettingsWindows:size()) then
		local settings = g.SettingsWindows:begin()
		while settings ~= nil do
			local highlight = PushHighlightOlderThan(highlight_older_than_date, settings.LastUsedDate)
			ImGui.DebugNodeWindowSettings(settings)
			if highlight then
				ImGui.PopStyleColor()
			end
			settings = g.SettingsWindows:next_chunk(settings)
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("SettingsTables", "Settings packed data: Tables: %d bytes", g.SettingsTables:size()) then
		local settings = g.SettingsTables:begin()
		while settings ~= nil do
			local highlight = PushHighlightOlderThan(highlight_older_than_date, settings.LastUsedDate)
			ImGui.DebugNodeTableSettings(settings, nil)
			if highlight then
				ImGui.PopStyleColor()
			end
			settings = g.SettingsTables:next_chunk(settings)
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("SettingsIniData", "Settings unpacked data (.ini): %d bytes", g.SettingsIniData:size()) then
		ImGui.InputTextMultiline("##Ini", g.SettingsIniData:c_str(), ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 20), ImGuiInputTextFlags.ReadOnly)
		ImGui.TreePop()
	end
end

local function ShowMetricsInputs(g, io)
	ImGui.Text("KEYBOARD/GAMEPAD/MOUSE KEYS")
	do
		ImGui.Indent()
		ImGui.Text("Keys down:")
		for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
			if not ImGui.IsKeyDown(key) then
				continue
			end
			ImGui.SameLine()
			ImGui.Text(ImGui.IsNamedKey(key) and "\"%s\"" or "\"%s\" %d", ImGui.GetKeyName(key), key)
			ImGui.SameLine()
			ImGui.Text("(%.02f)", ImGui.GetKeyData(key).DownDuration)
		end
		ImGui.Text("Keys pressed:")
		for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
			if not ImGui.IsKeyPressed(key) then
				continue
			end
			ImGui.SameLine()
			ImGui.Text(ImGui.IsNamedKey(key) and "\"%s\"" or "\"%s\" %d", ImGui.GetKeyName(key), key)
		end
		ImGui.Text("Keys released:")
		for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
			if not ImGui.IsKeyReleased(key) then
				continue
			end
			ImGui.SameLine()
			ImGui.Text(ImGui.IsNamedKey(key) and "\"%s\"" or "\"%s\" %d", ImGui.GetKeyName(key), key)
		end
		ImGui.Text("Keys mods: %s%s%s%s", io.KeyCtrl and "Ctrl " or "", io.KeyShift and "Shift " or "", io.KeyAlt and "Alt " or "", io.KeySuper and "Super " or "")
		ImGui.Text("Chars queue:")
		for i = 0, io.InputQueueCharacters.Size - 1 do
			local c = io.InputQueueCharacters[i + 1]
			ImGui.SameLine()
			ImGui.Text("'%c' (0x%04X)", (c > 32 and c <= 255) and c or 63, c)
		end
		ImGui.DebugRenderKeyboardPreview(ImGui.GetWindowDrawList())
		ImGui.Unindent()
	end

	ImGui.Text("MOUSE STATE")
	do
		ImGui.Indent()
		if ImGui.IsMousePosValid() then
			ImGui.Text("Mouse pos: (%g, %g)", io.MousePos.x, io.MousePos.y)
		else
			ImGui.Text("Mouse pos: <INVALID>")
		end
		ImGui.Text("Mouse delta: (%g, %g)", io.MouseDelta.x, io.MouseDelta.y)
		local count = #io.MouseDown
		ImGui.Text("Mouse down:")
		for i = 0, count - 1 do
			if ImGui.IsMouseDown(i) then
				ImGui.SameLine()
				ImGui.Text("b%d (%.02f secs)", i, io.MouseDownDuration[i + 1])
			end
		end
		ImGui.Text("Mouse clicked:")
		for i = 0, count - 1 do
			if ImGui.IsMouseClicked(i) then
				ImGui.SameLine()
				ImGui.Text("b%d (%d)", i, io.MouseClickedCount[i + 1])
			end
		end
		ImGui.Text("Mouse released:")
		for i = 0, count - 1 do
			if ImGui.IsMouseReleased(i) then
				ImGui.SameLine()
				ImGui.Text("b%d", i)
			end
		end
		ImGui.Text("Mouse wheel: %.1f", io.MouseWheel)
		ImGui.Text("MouseStationaryTimer: %.2f", g.MouseStationaryTimer)
		ImGui.Text("Mouse source: %s", ImGui.GetMouseSourceName(io.MouseSource))
		ImGui.Text("Pen Pressure: %.1f", io.PenPressure)
		ImGui.Unindent()
	end

	ImGui.Text("MOUSE WHEELING")
	do
		ImGui.Indent()
		ImGui.Text("WheelingWindow: '%s'", g.WheelingWindow and g.WheelingWindow.Name or "NULL")
		ImGui.Text("WheelingWindowReleaseTimer: %.2f", g.WheelingWindowReleaseTimer)
		ImGui.Text("WheelingAxisAvg[] = { %.3f, %.3f }, Main Axis: %s", g.WheelingAxisAvg.x, g.WheelingAxisAvg.y, (g.WheelingAxisAvg.x > g.WheelingAxisAvg.y) and "X" or ((g.WheelingAxisAvg.x < g.WheelingAxisAvg.y) and "Y" or "<none>"))
		ImGui.Unindent()
	end

	ImGui.Text("KEY OWNERS")
	do
		ImGui.Indent()
		if ImGui.BeginChild("##owners", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 8), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY), ImGuiWindowFlags.NoSavedSettings) then
			for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
				local owner_data = ImGui.GetKeyOwnerData(g, key)
				if owner_data.OwnerCurr == ImGuiKeyOwner.NoOwner then
					continue
				end
				ImGui.Text("%s: 0x%08X%s", ImGui.GetKeyName(key), owner_data.OwnerCurr, owner_data.LockUntilRelease and " LockUntilRelease" or (owner_data.LockThisFrame and " LockThisFrame" or ""))
				ImGui.DebugLocateItemOnHover(owner_data.OwnerCurr)
			end
		end
		ImGui.EndChild()
		ImGui.Unindent()
	end
	ImGui.Text("SHORTCUT ROUTING")
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("Declared shortcut routes automatically set key owner when mods matches.")
	do
		ImGui.Indent()
		if ImGui.BeginChild("##routes", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 8), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY), ImGuiWindowFlags.NoSavedSettings) then
			for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
				local rt = g.KeysRoutingTable
				local idx = rt.Index[key - ImGuiKey.NamedKey_BEGIN + 1]
				while idx ~= -1 do
					local routing_data = rt.Entries[idx + 1]
					local key_chord = bit32.bor(key, routing_data.Mods)
					ImGui.Text("%s: 0x%08X (scored %d)", ImGui.GetKeyChordName(key_chord), routing_data.RoutingCurr, routing_data.RoutingCurrScore)
					ImGui.DebugLocateItemOnHover(routing_data.RoutingCurr)
					if g.IO.ConfigDebugIsDebuggerPresent then
						ImGui.SameLine()
						if ImGui.DebugBreakButton("**DebugBreak**", "in SetShortcutRouting() for this KeyChord") then
							g.DebugBreakInShortcutRouting = key_chord
						end
					end
					idx = routing_data.NextEntryIndex
				end
			end
		end
		ImGui.EndChild()
		ImGui.Text("(ActiveIdUsing: AllKeyboardKeys: %d, NavDirMask: 0x%X)", BoolToInt(g.ActiveIdUsingAllKeyboardKeys), g.ActiveIdUsingNavDirMask)
		ImGui.Unindent()
	end
end

local function ShowMetricsInternalState(g)
	ImGui.Text("WINDOWING")
	ImGui.Indent()
	ImGui.Text("HoveredWindow: '%s'", g.HoveredWindow and g.HoveredWindow.Name or "NULL")
	ImGui.Text("HoveredWindow->Root: '%s'", g.HoveredWindow and g.HoveredWindow.RootWindow.Name or "NULL")
	ImGui.Text("HoveredWindowUnderMovingWindow: '%s'", g.HoveredWindowUnderMovingWindow and g.HoveredWindowUnderMovingWindow.Name or "NULL")
	ImGui.Text("MovingWindow: '%s'", g.MovingWindow and g.MovingWindow.Name or "NULL")
	ImGui.Unindent()

	ImGui.Text("ITEMS")
	ImGui.Indent()
	ImGui.Text("ActiveId: 0x%08X/0x%08X (%.2f sec), AllowOverlap: %d, Source: %s", g.ActiveId, g.ActiveIdPreviousFrame, g.ActiveIdTimer, BoolToInt(g.ActiveIdAllowOverlap), ImGui.GetInputSourceName(g.ActiveIdSource))
	ImGui.DebugLocateItemOnHover(g.ActiveId)
	ImGui.Text("ActiveIdWindow: '%s'", g.ActiveIdWindow and g.ActiveIdWindow.Name or "NULL")
	ImGui.Text("ActiveIdUsing: AllKeyboardKeys: %d, NavDirMask: %X", BoolToInt(g.ActiveIdUsingAllKeyboardKeys), g.ActiveIdUsingNavDirMask)
	ImGui.Text("HoveredId: 0x%08X (%.2f sec), AllowOverlap: %d", g.HoveredIdPreviousFrame, g.HoveredIdTimer, BoolToInt(g.HoveredIdAllowOverlap))
	ImGui.Text("HoverItemDelayId: 0x%08X, Timer: %.2f, ClearTimer: %.2f", g.HoverItemDelayId, g.HoverItemDelayTimer, g.HoverItemDelayClearTimer)
	ImGui.Text("DragDrop: %d, SourceId = 0x%08X, Payload \"%s\" (%d bytes)", BoolToInt(g.DragDropActive), g.DragDropPayload.SourceId, g.DragDropPayload.DataType, g.DragDropPayload.DataSize)
	ImGui.DebugLocateItemOnHover(g.DragDropPayload.SourceId)
	ImGui.Unindent()

	ImGui.Text("NAV,FOCUS")
	ImGui.Indent()
	ImGui.Text("NavWindow: '%s'", g.NavWindow and g.NavWindow.Name or "NULL")
	ImGui.Text("NavId: 0x%08X, NavLayer: %d", g.NavId, g.NavLayer)
	ImGui.DebugLocateItemOnHover(g.NavId)
	ImGui.Text("NavInputSource: %s", ImGui.GetInputSourceName(g.NavInputSource))
	ImGui.Text("NavLastValidSelectionUserData = %d (0x%X)", g.NavLastValidSelectionUserData, g.NavLastValidSelectionUserData)
	ImGui.Text("NavActive: %d, NavVisible: %d", BoolToInt(g.IO.NavActive), BoolToInt(g.IO.NavVisible))
	ImGui.Text("NavActivateId/DownId/PressedId: %08X/%08X/%08X", g.NavActivateId, g.NavActivateDownId, g.NavActivatePressedId)
	ImGui.Text("NavActivateFlags: %04X", g.NavActivateFlags)
	ImGui.Text("NavCursorVisible: %d, NavHighlightItemUnderNav: %d", BoolToInt(g.NavCursorVisible), BoolToInt(g.NavHighlightItemUnderNav))
	ImGui.Text("NavFocusScopeId = 0x%08X", g.NavFocusScopeId)
	ImGui.Text("NavFocusRoute[] = ")
	for path_n = g.NavFocusRoute.Size - 1, 0, -1 do
		local focus_scope = g.NavFocusRoute[path_n + 1]
		ImGui.SameLine(0.0, 0.0)
		ImGui.Text("0x%08X/", focus_scope.ID)
		ImGui.SetItemTooltip("In window \"%s\"", ImGui.FindWindowByID(focus_scope.WindowID).Name)
	end
	ImGui.Text("NavWindowingTarget: '%s'", g.NavWindowingTarget and g.NavWindowingTarget.Name or "NULL")
	ImGui.Unindent()
end

function ImGui.ShowMetricsWindow(p_open)
	local g = ImGui.GImGui
	local io = g.IO
	local platform_io = g.PlatformIO
	local cfg = g.DebugMetricsConfig
	if cfg.ShowDebugLog then
		cfg.ShowDebugLog = ImGui.ShowDebugLogWindow(cfg.ShowDebugLog)
	end
	if cfg.ShowIDStackTool then
		cfg.ShowIDStackTool = ImGui.ShowIDStackToolWindow(cfg.ShowIDStackTool)
	end

	local visible
	visible, p_open = ImGui.Begin("Dear ImGui Metrics/Debugger", p_open)
	if not visible or ImGui.GetCurrentWindow().BeginCount > 1 then
		ImGui.End()
		return p_open
	end

	ImGui.DebugBreakClearData()

	ImGui.Text("Dear ImGui %s (%d)", Base.IMGUI_VERSION, Base.IMGUI_VERSION_NUM)
	if g.ContextName ~= "" then
		ImGui.SameLine()
		ImGui.Text("(Context Name: \"%s\")", g.ContextName)
	end
	ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate)
	ImGui.Text("%d vertices, %d indices (%d triangles)", io.MetricsRenderVertices, io.MetricsRenderIndices, io.MetricsRenderIndices // 3)
	ImGui.Text("%d visible windows, %d current allocations", io.MetricsRenderWindows, g.DebugAllocInfo.TotalAllocCount - g.DebugAllocInfo.TotalFreeCount)

	ImGui.Separator()

	if cfg.ShowWindowsRectsType < 0 then
		cfg.ShowWindowsRectsType = WRT_WorkRect
	end
	if cfg.ShowTablesRectsType < 0 then
		cfg.ShowTablesRectsType = TRT_WorkRect
	end

	if ImGui.TreeNode("Tools") then
		ShowMetricsTools(g, io, cfg)
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Windows", "Windows (%d)", g.Windows.Size) then
		ImGui.DebugNodeWindowsList(g.Windows, "By display order")
		ImGui.DebugNodeWindowsList(g.WindowsFocusOrder, "By focus order (root windows)")
		if ImGui.TreeNode("By submission order (begin stack)") then
			local temp_buffer = g.WindowsTempSortBuffer
			temp_buffer:resize(0)
			for i = 0, g.Windows.Size - 1 do
				local window = g.Windows[i + 1]
				if window.LastFrameActive + 1 >= g.FrameCount then
					temp_buffer:push_back(window)
				end
			end
			Base.ImQsort(temp_buffer, temp_buffer.Size, function(lhs, rhs)
				return lhs.BeginOrderWithinContext - rhs.BeginOrderWithinContext
			end)
			ImGui.DebugNodeWindowsListByBeginStackParent(temp_buffer, temp_buffer.Size, nil)
			ImGui.TreePop()
		end

		ImGui.TreePop()
	end

	local drawlist_count = 0
	for i = 0, g.Viewports.Size - 1 do
		drawlist_count += g.Viewports[i + 1].DrawDataP.CmdLists.Size
	end
	if ImGui.TreeNode("DrawLists", "DrawLists (%d)", drawlist_count) then
		_, cfg.ShowDrawCmdMesh = ImGui.Checkbox("Show ImDrawCmd mesh when hovering", cfg.ShowDrawCmdMesh)
		_, cfg.ShowDrawCmdBoundingBoxes = ImGui.Checkbox("Show ImDrawCmd bounding boxes when hovering", cfg.ShowDrawCmdBoundingBoxes)
		for i = 0, g.Viewports.Size - 1 do
			local viewport = g.Viewports[i + 1]
			local cmd_lists = viewport.DrawDataP.CmdLists
			for j = 0, cmd_lists.Size - 1 do
				ImGui.DebugNodeDrawList(nil, viewport, cmd_lists[j + 1], "DrawList")
			end
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Viewports", "Viewports (%d)", g.Viewports.Size) then
		ImGui.SetNextItemOpen(true, ImGuiCond.Once)
		if ImGui.TreeNode("Windows Minimap") then
			ImGui.RenderViewportsThumbnails()
			ImGui.TreePop()
		end
		cfg.HighlightViewportID = 0

		for i = 0, g.Viewports.Size - 1 do
			ImGui.DebugNodeViewport(g.Viewports[i + 1])
		end
		ImGui.TreePop()
	end

	for i = 0, g.FontAtlases.Size - 1 do
		local atlas = g.FontAtlases[i + 1]
		if ImGui.TreeNode(atlas, "Fonts (%d), Textures (%d)", atlas.Fonts.Size, atlas.TexList.Size) then
			ImGui.ShowFontAtlas(atlas)
			ImGui.TreePop()
		end
	end

	if ImGui.TreeNode("Popups", "Popups (%d)", g.OpenPopupStack.Size) then
		for i = 0, g.OpenPopupStack.Size - 1 do
			local popup_data = g.OpenPopupStack[i + 1]
			local window = popup_data.Window
			ImGui.BulletText("PopupID: %08x, Window: '%s' (%s%s), RestoreNavWindow '%s', ParentWindow '%s'",
				popup_data.PopupId, window and window.Name or "NULL",
				(window and bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow)) and "Child;" or "",
				(window and bit32.btest(window.Flags, ImGuiWindowFlags.ChildMenu)) and "Menu;" or "",
				popup_data.RestoreNavWindow and popup_data.RestoreNavWindow.Name or "NULL",
				(window and window.ParentWindow) and window.ParentWindow.Name or "NULL")
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("TabBars", "Tab Bars (%d)", g.TabBars:GetAliveCount()) then
		for n = 0, g.TabBars:GetMapSize() - 1 do
			local tab_bar = g.TabBars:TryGetMapData(n)
			if tab_bar then
				ImGui.PushID(tab_bar)
				ImGui.DebugNodeTabBar(tab_bar, "TabBar")
				ImGui.PopID()
			end
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Tables", "Tables (%d)", g.Tables:GetAliveCount()) then
		for n = 0, g.Tables:GetMapSize() - 1 do
			local tbl = g.Tables:TryGetMapData(n)
			if tbl then
				ImGui.DebugNodeTable(tbl)
			end
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("InputText") then
		ImGui.DebugNodeInputTextState(g.InputTextState)
		ImGui.TreePop()
	end

	if ImGui.TreeNode("TypingSelect", "TypingSelect (%d)", g.TypingSelectState.SearchBuffer ~= "" and 1 or 0) then
		ImGui.DebugNodeTypingSelectState(g.TypingSelectState)
		ImGui.TreePop()
	end

	if ImGui.TreeNode("MultiSelect", "MultiSelect (%d)", g.MultiSelectStorage:GetAliveCount()) then
		local bs = g.BoxSelectState
		ImGui.BulletText("BoxSelect ID=0x%08X, Starting = %d, Active %d", bs.ID, BoolToInt(bs.IsStarting), BoolToInt(bs.IsActive))
		for n = 0, g.MultiSelectStorage:GetMapSize() - 1 do
			local state = g.MultiSelectStorage:TryGetMapData(n)
			if state then
				ImGui.DebugNodeMultiSelectState(state)
			end
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Settings") then
		ShowMetricsSettings(g, io, platform_io, cfg)
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Memory allocations") then
		local info = g.DebugAllocInfo
		ImGui.Text("%d current allocations", info.TotalAllocCount - info.TotalFreeCount)
		ImGui.Text("Releasing selected unused buffers after: %.2f secs", g.IO.ConfigMemoryCompactTimer)
		if ImGui.SmallButton("GC now") then
			g.GcCompactAll = true
		end
		ImGui.Text("Recent frames with allocations:")
		local buf_size = #info.LastEntriesBuf
		for n = buf_size - 1, 0, -1 do
			local entry = info.LastEntriesBuf[(info.LastEntriesIdx - n + buf_size) % buf_size + 1]
			ImGui.BulletText("Frame %06d: %+3d ( %2d alloc, %2d free )", entry.FrameCount, entry.AllocCount - entry.FreeCount, entry.AllocCount, entry.FreeCount)
			if n == 0 then
				ImGui.SameLine()
				ImGui.Text("<- %d frames ago", g.FrameCount - entry.FrameCount)
			end
		end
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Inputs") then
		ShowMetricsInputs(g, io)
		ImGui.TreePop()
	end

	if ImGui.TreeNode("Internal state") then
		ShowMetricsInternalState(g)
		ImGui.TreePop()
	end

	if cfg.ShowWindowsRects or cfg.ShowWindowsBeginOrder then
		for i = 0, g.Windows.Size - 1 do
			local window = g.Windows[i + 1]
			if not window.WasActive then
				continue
			end
			local draw_list = ImGui.GetForegroundDrawList()
			if cfg.ShowWindowsRects then
				local r = GetWindowRect(window, cfg.ShowWindowsRectsType)
				draw_list:AddRect(r.Min, r.Max, IM_COL32(255, 0, 128, 255))
			end
			if cfg.ShowWindowsBeginOrder and not bit32.btest(window.Flags, ImGuiWindowFlags.ChildWindow) then
				local buf = ImFormatString("%d", window.BeginOrderWithinContext)
				local font_size = ImGui.GetFontSize()
				draw_list:AddRectFilled(window.Pos, window.Pos + ImVec2(font_size, font_size), IM_COL32(200, 100, 100, 255))
				draw_list:AddText(window.Pos, IM_COL32(255, 255, 255, 255), buf)
			end
		end
	end

	if cfg.ShowTablesRects then
		for table_n = 0, g.Tables:GetMapSize() - 1 do
			local tbl = g.Tables:TryGetMapData(table_n)
			if tbl == nil or tbl.LastFrameActive < g.FrameCount - 1 then
				continue
			end
			local draw_list = ImGui.GetForegroundDrawList()
			if cfg.ShowTablesRectsType >= TRT_ColumnsRect then
				for column_n = 0, tbl.ColumnsCount - 1 do
					local r = GetTableRect(tbl, cfg.ShowTablesRectsType, column_n)
					local col = (tbl.HoveredColumnBody == column_n) and IM_COL32(255, 255, 128, 255) or IM_COL32(255, 0, 128, 255)
					local thickness = (tbl.HoveredColumnBody == column_n) and 3.0 or 1.0
					draw_list:AddRect(r.Min, r.Max, col, 0.0, thickness)
				end
			else
				local r = GetTableRect(tbl, cfg.ShowTablesRectsType, -1)
				draw_list:AddRect(r.Min, r.Max, IM_COL32(255, 0, 128, 255))
			end
		end
	end

	ImGui.End()
	return p_open
end

function ImGui.DebugBreakClearData()
	local g = ImGui.GImGui
	g.DebugBreakInWindow = 0
	g.DebugBreakInTable = 0
	g.DebugBreakInShortcutRouting = ImGuiKey.None
end

function ImGui.DebugBreakButtonTooltip(keyboard_only, description_of_location)
	if not ImGui.BeginItemTooltip() then
		return
	end
	ImGui.Text("To call IM_DEBUG_BREAK() %s:", description_of_location)
	ImGui.Separator()
	ImGui.TextUnformatted(keyboard_only and "- Press 'Pause/Break' on keyboard." or "- Press 'Pause/Break' on keyboard.\n- or Click (may alter focus/active id).\n- or navigate using keyboard and press space.")
	ImGui.Separator()
	ImGui.TextUnformatted("Choose one way that doesn't interfere with what you are trying to debug!\nYou need a debugger attached or this will crash!")
	ImGui.EndTooltip()
end

function ImGui.DebugBreakButton(label, description_of_location)
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false
	end

	local g = ImGui.GImGui
	local id = window:GetID(label)
	local label_size = ImGui.CalcTextSize(label, nil, true)
	local pos = window.DC.CursorPos + ImVec2(0.0, window.DC.CurrLineTextBaseOffset)
	local size = ImVec2(label_size.x + g.Style.FramePadding.x * 2.0, label_size.y)

	local bb = ImRect.new(pos, pos + size)
	ImGui.ItemSize(size, 0.0)
	if not ImGui.ItemAdd(bb, id) then
		return false
	end

	local hovered = ImGui.ItemHoverable(bb, id, g.CurrentItemFlags)
	local pressed = hovered and (ImGui.IsKeyChordPressed(g.DebugBreakKeyChord) or ImGui.IsMouseClicked(0) or g.NavActivateId == id)
	ImGui.DebugBreakButtonTooltip(false, description_of_location)

	local col4f = ImGui.GetStyleColorVec4(hovered and ImGuiCol.ButtonHovered or ImGuiCol.Button)
	local h, s, v = ImGui.ColorConvertRGBtoHSV(col4f.x, col4f.y, col4f.z)
	local r, gr, b = ImGui.ColorConvertHSVtoRGB(h + 0.20, s, v)
	col4f = ImVec4(r, gr, b, col4f.w)

	ImGui.RenderNavCursor(bb, id)
	ImGui.RenderFrame(bb.Min, bb.Max, ImGui.GetColorU32(col4f), true, g.Style.FrameRounding)
	ImGui.RenderTextClipped(bb.Min, bb.Max, label, nil, label_size, g.Style.ButtonTextAlign, bb)

	return pressed
end

function ImGui.DebugNodeColumns(columns)
	if not ImGui.TreeNode(columns.ID, "Columns Id: 0x%08X, Count: %d, Flags: 0x%04X", columns.ID, columns.Count, columns.Flags) then
		return
	end
	ImGui.BulletText("Width: %.1f (MinX: %.1f, MaxX: %.1f)", columns.OffMaxX - columns.OffMinX, columns.OffMinX, columns.OffMaxX)
	for i = 0, columns.Columns.Size - 1 do
		local column = columns.Columns[i + 1]
		ImGui.BulletText("Column %02d: OffsetNorm %.3f (= %.1f px)", i, column.OffsetNorm, ImGui.GetColumnOffsetFromNorm(columns, column.OffsetNorm))
	end
	ImGui.TreePop()
end

local function DebugPrimGetBounds(draw_list, prim_n)
	local K = DrawList.PrimKind
	local prims = draw_list.PrimBuffer
	local b = prim_n * DrawList.PRIM_STRIDE
	local kind = prims[b + 1]
	local a1, a2, a3, a4 = prims[b + 2], prims[b + 3], prims[b + 4], prims[b + 5]
	if kind == K.Line then
		return kind, ImVec2(math.min(a1, a3), math.min(a2, a4)), ImVec2(math.max(a1, a3), math.max(a2, a4))
	elseif kind == K.TriangleFilled or kind == K.TriangleMultiColor then
		local a5, a6 = prims[b + 6], prims[b + 7]
		return kind, ImVec2(math.min(a1, a3, a5), math.min(a2, a4, a6)), ImVec2(math.max(a1, a3, a5), math.max(a2, a4, a6))
	elseif kind == K.CircleFilled or kind == K.Circle then
		return kind, ImVec2(a1 - a3, a2 - a3), ImVec2(a1 + a3, a2 + a3)
	elseif kind == K.Text then
		local font, size = prims[b + 7], prims[b + 6]
		local text_size = (font ~= nil and a4 ~= nil) and font:CalcTextSizeA(size, FLT_MAX, 0.0, a4) or ImVec2(0.0, size)
		return kind, ImVec2(a1, a2), ImVec2(a1, a2) + text_size
	end
	return kind, ImVec2(a1, a2), ImVec2(a3, a4)
end

local function DebugPrimDrawOutline(out_draw_list, draw_list, prim_n, col)
	local K = DrawList.PrimKind
	local kind, p_min, p_max = DebugPrimGetBounds(draw_list, prim_n)
	local prims = draw_list.PrimBuffer
	local b = prim_n * DrawList.PRIM_STRIDE
	if kind == K.Line then
		out_draw_list:AddLine(ImVec2(prims[b + 2], prims[b + 3]), ImVec2(prims[b + 4], prims[b + 5]), col)
	elseif kind == K.TriangleFilled or kind == K.TriangleMultiColor then
		local triangle = { ImVec2(prims[b + 2], prims[b + 3]), ImVec2(prims[b + 4], prims[b + 5]), ImVec2(prims[b + 6], prims[b + 7]) }
		out_draw_list:AddPolyline(triangle, 3, col, 1.0, ImDrawFlags.Closed)
	elseif kind == K.CircleFilled or kind == K.Circle then
		out_draw_list:AddCircle(ImVec2(prims[b + 2], prims[b + 3]), prims[b + 4], col)
	else
		out_draw_list:AddRect(p_min, p_max, col)
	end
end

local PrimKindNames = nil

function ImGui.DebugNodeDrawList(window, viewport, draw_list, label)
	local g = ImGui.GImGui
	local cfg = g.DebugMetricsConfig
	local cmd_count = draw_list.CmdBuffer.Size
	if cmd_count > 0 and draw_list.CmdBuffer:back().ElemCount == 0 and draw_list.CmdBuffer:back().UserCallback == nil then
		cmd_count -= 1
	end
	local node_open = ImGui.TreeNode(draw_list, "%s: '%s' %d prims, %d cmds", label, draw_list._OwnerName or "", draw_list:GetPrimCount(), cmd_count)
	if draw_list == ImGui.GetWindowDrawList() then
		ImGui.SameLine()
		ImGui.TextColored(ImVec4(1.0, 0.4, 0.4, 1.0), "CURRENTLY APPENDING")
		if node_open then
			ImGui.TreePop()
		end
		return
	end

	local fg_draw_list = ImGui.GetForegroundDrawList()
	if window and ImGui.IsItemHovered() and fg_draw_list then
		fg_draw_list:AddRect(window.Pos, window.Pos + window.Size, IM_COL32(255, 255, 0, 255))
	end
	if not node_open then
		return
	end

	if window and not window.WasActive then
		ImGui.TextDisabled("Warning: owning Window is inactive. This DrawList is not being rendered!")
	end

	if PrimKindNames == nil then
		PrimKindNames = {}
		for name, kind in DrawList.PrimKind do
			PrimKindNames[kind] = name
		end
	end

	for cmd_n = 0, cmd_count - 1 do
		local pcmd = draw_list.CmdBuffer[cmd_n + 1]
		if pcmd.UserCallback then
			ImGui.BulletText("Callback %p, user_data %p", PtrToNum(pcmd.UserCallback), PtrToNum(pcmd.UserCallbackData))
			continue
		end

		local texid_desc = ImGui.FormatTextureRefForDebugDisplay(pcmd.TexRef)
		local buf = ImFormatString("DrawCmd:%5d prims, Tex %s, ClipRect (%4.0f,%4.0f)-(%4.0f,%4.0f)", pcmd.ElemCount, texid_desc, pcmd.ClipRect.x, pcmd.ClipRect.y, pcmd.ClipRect.z, pcmd.ClipRect.w)
		local pcmd_node_open = ImGui.TreeNode(cmd_n, "%s", buf)
		if ImGui.IsItemHovered() and (cfg.ShowDrawCmdMesh or cfg.ShowDrawCmdBoundingBoxes) and fg_draw_list then
			ImGui.DebugNodeDrawCmdShowMeshAndBoundingBox(fg_draw_list, draw_list, pcmd, cfg.ShowDrawCmdMesh, cfg.ShowDrawCmdBoundingBoxes)
		end
		if not pcmd_node_open then
			continue
		end

		buf = ImFormatString("Mesh: ElemCount: %d, IdxOffset: +%d", pcmd.ElemCount, pcmd.IdxOffset)
		ImGui.Selectable(buf)
		if ImGui.IsItemHovered() and fg_draw_list then
			ImGui.DebugNodeDrawCmdShowMeshAndBoundingBox(fg_draw_list, draw_list, pcmd, true, false)
		end

		local clipper = Structs.ImGuiListClipper.new()
		clipper:Begin(pcmd.ElemCount)
		while clipper:Step() do
			for prim = clipper.DisplayStart, clipper.DisplayEnd - 1 do
				local prim_n = pcmd.IdxOffset + prim
				local kind, p_min, p_max = DebugPrimGetBounds(draw_list, prim_n)
				buf = ImFormatString("Prim: %04d: %s (%8.2f,%8.2f)-(%8.2f,%8.2f)", prim_n, PrimKindNames[kind] or tostring(kind), p_min.x, p_min.y, p_max.x, p_max.y)
				ImGui.Selectable(buf, false)
				if fg_draw_list and ImGui.IsItemHovered() then
					fg_draw_list:PushDrawFlag(ImDrawFlags.AALines, false)
					DebugPrimDrawOutline(fg_draw_list, draw_list, prim_n, IM_COL32(255, 255, 0, 255))
					fg_draw_list:PopDrawFlag()
				end
			end
		end
		ImGui.TreePop()
	end
	ImGui.TreePop()
end

function ImGui.DebugNodeDrawCmdShowMeshAndBoundingBox(out_draw_list, draw_list, draw_cmd, show_mesh, show_aabb)
	assert(show_mesh or show_aabb)

	local clip_rect = ImRect.fromVec4(draw_cmd.ClipRect)
	local vtxs_rect = ImRect.fromXY(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
	out_draw_list:PushDrawFlag(ImDrawFlags.AALines, false)
	for prim_n = draw_cmd.IdxOffset, draw_cmd.IdxOffset + draw_cmd.ElemCount - 1 do
		local _, p_min, p_max = DebugPrimGetBounds(draw_list, prim_n)
		vtxs_rect = vtxs_rect:Added(p_min):Added(p_max)
		if show_mesh then
			DebugPrimDrawOutline(out_draw_list, draw_list, prim_n, IM_COL32(255, 255, 0, 255))
		end
	end
	if show_aabb then
		out_draw_list:AddRect(ImTrunc(clip_rect.Min), ImTrunc(clip_rect.Max), IM_COL32(255, 0, 255, 255))
		out_draw_list:AddRect(ImTrunc(vtxs_rect.Min), ImTrunc(vtxs_rect.Max), IM_COL32(0, 255, 255, 255))
	end
	out_draw_list:PopDrawFlag()
end

function ImGui.CalcFontGlyphSrcOverlapMask(atlas, font, codepoint)
	local mask, count = 0, 0
	for src_n = 0, font.Sources.Size - 1 do
		local src = font.Sources[src_n + 1]
		local loader = src.FontLoader or atlas.FontLoader
		if loader.FontSrcGetGlyphIndexFromCodepoint(atlas, src, codepoint) == 0 then
			continue
		end
		mask = bit32.bor(mask, bit32.lshift(1, src_n))
		count += 1
	end
	return count > 1 and mask or 0
end

local function DebugNodeFontOverlapTool(atlas, font)
	ImGui.TextWrapped("- First Input that contains the glyph is used.\n- Use ImFontConfig::GlyphExcludeRanges[] to specify ranges to ignore glyph in given Input.\n- Prefer using a small number of ranges as the list is scanned every time a new glyph is loaded,\n  - e.g. GlyphExcludeRanges[] = { ICON_MIN_FA, ICON_MAX_FA, 0 };\n- This tool doesn't cache results and is slow, don't keep it open!")
	if ImGui.BeginTable("table", 2) then
		local c = 0
		while c < 0x10000 do
			local overlap_mask = ImGui.CalcFontGlyphSrcOverlapMask(atlas, font, c)
			if overlap_mask ~= 0 then
				local c_end = c + 1
				while c_end < 0x10000 and ImGui.CalcFontGlyphSrcOverlapMask(atlas, font, c_end) == overlap_mask do
					c_end += 1
				end
				if ImGui.TableNextColumn() and ImGui.TreeNode(c, "U+%04X-U+%04X: %d codepoints in %d inputs", c, c_end - 1, c_end - c, Base.ImCountSetBits(overlap_mask)) then
					for n = c, c_end - 1 do
						ImGui.BulletText("Codepoint U+%04X (%s)", n, (Base.ImTextCharToUtf8(n)))
					end
					ImGui.TreePop()
				end
				ImGui.TableNextColumn()
				for src_n = 0, font.Sources.Size - 1 do
					if bit32.btest(overlap_mask, bit32.lshift(1, src_n)) then
						ImGui.Text("%d ", src_n)
						ImGui.SameLine()
					end
				end
				c = c_end - 1
			end
			c += 1
		end
		ImGui.EndTable()
	end
end

function ImGui.DebugNodeFont(font)
	local g = ImGui.GImGui
	local cfg = g.DebugMetricsConfig
	local atlas = font.OwnerAtlas
	local opened = ImGui.TreeNode(font, "Font: \"%s\": %d sources(s)", font:GetDebugName(), font.Sources.Size)

	if not opened then
		ImGui.Indent()
	end
	ImGui.Indent()
	if cfg.ShowFontPreview then
		ImGui.PushFont(font, 0.0)
		ImGui.Text("The quick brown fox jumps over the lazy dog")
		ImGui.PopFont()
	end
	if not opened then
		ImGui.Unindent()
		ImGui.Unindent()
		return
	end
	if ImGui.SmallButton("Set as default") then
		ImGui.GetIO().FontDefault = font
	end
	ImGui.SameLine()
	ImGui.BeginDisabled(atlas.Fonts.Size <= 1 or atlas.Locked)
	if ImGui.SmallButton("Remove") then
		atlas:RemoveFont(font)
	end
	ImGui.EndDisabled()
	ImGui.SameLine()
	if ImGui.SmallButton("Clear bakes") then
		DrawList.ImFontAtlasFontDiscardBakes(atlas, font, 0)
	end
	ImGui.SameLine()
	if ImGui.SmallButton("Clear unused") then
		DrawList.ImFontAtlasFontDiscardBakes(atlas, font, 2)
	end

	ImGui.Text("Fallback character: '%s' (U+%04X)", Base.ImTextCharToUtf8(font.FallbackChar), font.FallbackChar)
	ImGui.Text("Ellipsis character: '%s' (U+%04X)", Base.ImTextCharToUtf8(font.EllipsisChar), font.EllipsisChar)

	for src_n = 0, font.Sources.Size - 1 do
		local src = font.Sources[src_n + 1]
		if ImGui.TreeNode(src, "Input %d: '%s' [%d], Oversample: %d,%d, PixelSnapH: %d, Offset: (%.1f,%.1f)",
			src_n, src.Name, src.FontNo, src.OversampleH, src.OversampleV, BoolToInt(src.PixelSnapH), src.GlyphOffset.x, src.GlyphOffset.y) then
			local loader = src.FontLoader or atlas.FontLoader
			ImGui.Text("Loader: '%s'", (loader and loader.Name) or "N/A")
			ImGui.TreePop()
		end
	end
	if font.Sources.Size > 1 and ImGui.TreeNode("Input Glyphs Overlap Detection Tool") then
		DebugNodeFontOverlapTool(atlas, font)
		ImGui.TreePop()
	end

	local builder = atlas.Builder
	if builder ~= nil then
		for baked_n = 0, builder.BakedPool.Size - 1 do
			local baked = builder.BakedPool[baked_n + 1]
			if baked.OwnerFont ~= font then
				continue
			end
			ImGui.PushID(baked.BakedId)
			if ImGui.TreeNode("Glyphs", "Baked at { %.2fpx, d.%.2f }: %d glyphs%s", baked.Size, baked.RasterizerDensity, baked.Glyphs.Size, (baked.LastUsedFrame < builder.FrameCount - 1) and " *Unused*" or "") then
				if ImGui.SmallButton("Load all") then
					for base = 0, IM_UNICODE_CODEPOINT_MAX do
						baked:FindGlyph(base)
					end
				end

				local surface_sqrt = ImTruncToInt(Base.ImSqrt(baked.MetricsTotalSurface))
				ImGui.Text("Ascent: %f, Descent: %f, Ascent-Descent: %f", baked.Ascent, baked.Descent, baked.Ascent - baked.Descent)
				ImGui.Text("Texture Area: about %d px ~%dx%d px", baked.MetricsTotalSurface, surface_sqrt, surface_sqrt)
				for src_n = 0, font.Sources.Size - 1 do
					local src = font.Sources[src_n + 1]
					local oversample_h, oversample_v = DrawList.ImFontAtlasBuildGetOversampleFactors(src, baked, nil, nil)
					ImGui.BulletText("Input %d: '%s', Oversample: (%d=>%d,%d=>%d), PixelSnapH: %d, Offset: (%.1f,%.1f)",
						src_n, src.Name, src.OversampleH, oversample_h, src.OversampleV, oversample_v, BoolToInt(src.PixelSnapH), src.GlyphOffset.x, src.GlyphOffset.y)
				end

				ImGui.DebugNodeFontGlyphsForSrcMask(font, baked, bit32.bnot(0))
				ImGui.TreePop()
			end
			ImGui.PopID()
		end
	end
	ImGui.TreePop()
	ImGui.Unindent()
end

function ImGui.DebugNodeFontGlyphsForSrcMask(font, baked, src_mask)
	local draw_list = ImGui.GetWindowDrawList()
	local glyph_col = ImGui.GetColorU32(ImGuiCol.Text)
	local cell_size = baked.Size * 1
	local cell_spacing = ImGui.GetStyle().ItemSpacing.y
	local base = 0
	while base <= IM_UNICODE_CODEPOINT_MAX do
		repeat
			if bit32.band(base, 8191) == 0 and font:IsGlyphRangeUnused(base, base + 8191) then
				base += 8192 - 256
				break
			end

			local count = 0
			for n = 0, 255 do
				local glyph = baked:IsGlyphLoaded(base + n) and baked:FindGlyph(base + n) or nil
				if glyph and bit32.btest(src_mask, bit32.lshift(1, glyph.SourceIdx)) then
					count += 1
				end
			end
			if count <= 0 then
				break
			end
			if not ImGui.TreeNode(base, "U+%04X..U+%04X (%d %s)", base, base + 255, count, count > 1 and "glyphs" or "glyph") then
				break
			end

			local base_pos = ImGui.GetCursorScreenPos()
			for n = 0, 255 do
				local cell_p1 = ImVec2(base_pos.x + (n % 16) * (cell_size + cell_spacing), base_pos.y + (n // 16) * (cell_size + cell_spacing))
				local cell_p2 = ImVec2(cell_p1.x + cell_size, cell_p1.y + cell_size)
				local glyph = baked:IsGlyphLoaded(base + n) and baked:FindGlyph(base + n) or nil
				draw_list:AddRect(cell_p1, cell_p2, glyph and IM_COL32(255, 255, 255, 100) or IM_COL32(255, 255, 255, 50))
				if not glyph or not bit32.btest(src_mask, bit32.lshift(1, glyph.SourceIdx)) then
					continue
				end
				font:RenderChar(draw_list, cell_size, cell_p1, glyph_col, base + n)
				if ImGui.IsMouseHoveringRect(cell_p1, cell_p2) and ImGui.BeginTooltip() then
					ImGui.DebugNodeFontGlyph(font, glyph)
					ImGui.EndTooltip()
				end
			end
			ImGui.Dummy(ImVec2((cell_size + cell_spacing) * 16, (cell_size + cell_spacing) * 16))
			ImGui.TreePop()
		until true
		base += 256
	end
end

function ImGui.DebugNodeFontGlyph(font, glyph)
	ImGui.Text("Codepoint: U+%04X", glyph.Codepoint)
	ImGui.Separator()
	ImGui.Text("Visible: %d", BoolToInt(glyph.Visible))
	ImGui.Text("AdvanceX: %.1f", glyph.AdvanceX)
	ImGui.Text("Pos: (%.2f,%.2f)->(%.2f,%.2f)", glyph.X0, glyph.Y0, glyph.X1, glyph.Y1)
	ImGui.Text("UV: (%.3f,%.3f)->(%.3f,%.3f)", glyph.U0, glyph.V0, glyph.U1, glyph.V1)
	if glyph.PackId >= 0 then
		local r = DrawList.ImFontAtlasPackGetRect(font.OwnerAtlas, glyph.PackId)
		ImGui.Text("PackId: 0x%X (%dx%d rect at %d,%d)", glyph.PackId, r.w, r.h, r.x, r.y)
	end
	ImGui.Text("SourceIdx: %d", glyph.SourceIdx)
end

function ImGui.DebugNodeStorage(storage, label)
	if not ImGui.TreeNode(label, "%s: %d entries, %d bytes", label, storage.Data.Size, storage.Data.Size * 16) then
		return
	end
	for i = 0, storage.Data.Size - 1 do
		local p = storage.Data[i + 1]
		ImGui.BulletText("Key 0x%08X Value { i: %d }", p.key, p.val_i)
		ImGui.DebugLocateItemOnHover(p.key)
	end
	ImGui.TreePop()
end

function ImGui.DebugNodeTabBar(tab_bar, label)
	local is_active = (tab_bar.PrevFrameVisible >= ImGui.GetFrameCount() - 2)
	local parts = { ImFormatString("%s 0x%08X (%d tabs)%s  {", label, tab_bar.ID, tab_bar.Tabs.Size, is_active and "" or " *Inactive*") }
	for tab_n = 0, ImMin(tab_bar.Tabs.Size, 3) - 1 do
		local tab = tab_bar.Tabs[tab_n + 1]
		table.insert(parts, ImFormatString("%s'%s'", tab_n > 0 and ", " or "", ImGui.TabBarGetTabName(tab_bar, tab)))
	end
	table.insert(parts, (tab_bar.Tabs.Size > 3) and " ... }" or " } ")
	local buf = string.sub(table.concat(parts), 1, 255)
	if not is_active then
		ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyleColorVec4(ImGuiCol.TextDisabled))
	end
	local open = ImGui.TreeNode(label, "%s", buf)
	if not is_active then
		ImGui.PopStyleColor()
	end
	if is_active and ImGui.IsItemHovered() then
		local draw_list = ImGui.GetForegroundDrawList()
		draw_list:AddRect(tab_bar.BarRect.Min, tab_bar.BarRect.Max, IM_COL32(255, 255, 0, 255))
		draw_list:AddLineV(tab_bar.ScrollingRectMinX, tab_bar.BarRect.Min.y, tab_bar.BarRect.Max.y, IM_COL32(0, 255, 0, 255))
		draw_list:AddLineV(tab_bar.ScrollingRectMaxX, tab_bar.BarRect.Min.y, tab_bar.BarRect.Max.y, IM_COL32(0, 255, 0, 255))
	end
	if open then
		for tab_n = 0, tab_bar.Tabs.Size - 1 do
			local tab = tab_bar.Tabs[tab_n + 1]
			ImGui.PushID(tab)
			if ImGui.SmallButton("<") then
				ImGui.TabBarQueueReorder(tab_bar, tab, -1)
			end
			ImGui.SameLine(0, 2)
			if ImGui.SmallButton(">") then
				ImGui.TabBarQueueReorder(tab_bar, tab, 1)
			end
			ImGui.SameLine()
			ImGui.Text("%02d%c Tab 0x%08X '%s' Offset: %.2f, Width: %.2f/%.2f",
				tab_n, (tab.ID == tab_bar.SelectedTabId) and 42 or 32, tab.ID, ImGui.TabBarGetTabName(tab_bar, tab), tab.Offset, tab.Width, tab.ContentWidth)
			ImGui.PopID()
		end
		ImGui.TreePop()
	end
end

function ImGui.DebugNodeViewport(viewport)
	local g = ImGui.GImGui
	ImGui.SetNextItemOpen(true, ImGuiCond.Once)
	local open = ImGui.TreeNode("viewport0", "Viewport #%d", 0)
	if ImGui.IsItemHovered() then
		g.DebugMetricsConfig.HighlightViewportID = viewport.ID
	end
	if open then
		local flags = viewport.Flags
		ImGui.BulletText("Main Pos: (%.0f,%.0f), Size: (%.0f,%.0f)\nWorkArea Inset Left: %.0f Top: %.0f, Right: %.0f, Bottom: %.0f",
			viewport.Pos.x, viewport.Pos.y, viewport.Size.x, viewport.Size.y,
			viewport.WorkInsetMin.x, viewport.WorkInsetMin.y, viewport.WorkInsetMax.x, viewport.WorkInsetMax.y)
		ImGui.BulletText("Flags: 0x%04X =%s%s%s", viewport.Flags,
			bit32.btest(flags, ImGuiViewportFlags.IsPlatformWindow) and " IsPlatformWindow" or "",
			bit32.btest(flags, ImGuiViewportFlags.IsPlatformMonitor) and " IsPlatformMonitor" or "",
			bit32.btest(flags, ImGuiViewportFlags.OwnedByApp) and " OwnedByApp" or "")
		local cmd_lists = viewport.DrawDataP.CmdLists
		for i = 0, cmd_lists.Size - 1 do
			ImGui.DebugNodeDrawList(nil, viewport, cmd_lists[i + 1], "DrawList")
		end
		ImGui.TreePop()
	end
end

function ImGui.DebugNodeWindow(window, label)
	if window == nil then
		ImGui.BulletText("%s: NULL", label)
		return
	end

	local g = ImGui.GImGui
	local is_active = window.WasActive
	local tree_node_flags = (window == g.NavWindow) and ImGuiTreeNodeFlags.Selected or ImGuiTreeNodeFlags.None
	if not is_active then
		ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyleColorVec4(ImGuiCol.TextDisabled))
	end
	local open = ImGui.TreeNodeEx(label, tree_node_flags, "%s '%s'%s", label, window.Name, is_active and "" or " *Inactive*")
	if not is_active then
		ImGui.PopStyleColor()
	end
	if ImGui.IsItemHovered() and is_active then
		ImGui.GetForegroundDrawList():AddRect(window.Pos, window.Pos + window.Size, IM_COL32(255, 255, 0, 255))
	end
	if not open then
		return
	end

	if window.MemoryCompacted then
		ImGui.TextDisabled("Note: some memory buffers have been compacted/freed.")
	end

	if g.IO.ConfigDebugIsDebuggerPresent and ImGui.DebugBreakButton("**DebugBreak**", "in Begin()") then
		g.DebugBreakInWindow = window.ID
	end

	local flags = window.Flags
	ImGui.DebugNodeDrawList(window, window.Viewport, window.DrawList, "DrawList")
	ImGui.BulletText("Pos: (%.1f,%.1f), Size: (%.1f,%.1f), ContentSize (%.1f,%.1f) Ideal (%.1f,%.1f)", window.Pos.x, window.Pos.y, window.Size.x, window.Size.y, window.ContentSize.x, window.ContentSize.y, window.ContentSizeIdeal.x, window.ContentSizeIdeal.y)
	ImGui.BulletText("Flags: 0x%08X (%s%s%s%s%s%s%s%s%s..)", flags,
		bit32.btest(flags, ImGuiWindowFlags.ChildWindow) and "Child " or "", bit32.btest(flags, ImGuiWindowFlags.Tooltip) and "Tooltip " or "", bit32.btest(flags, ImGuiWindowFlags.Popup) and "Popup " or "",
		bit32.btest(flags, ImGuiWindowFlags.Modal) and "Modal " or "", bit32.btest(flags, ImGuiWindowFlags.ChildMenu) and "ChildMenu " or "", bit32.btest(flags, ImGuiWindowFlags.NoSavedSettings) and "NoSavedSettings " or "",
		bit32.btest(flags, ImGuiWindowFlags.NoMouseInputs) and "NoMouseInputs" or "", bit32.btest(flags, ImGuiWindowFlags.NoNavInputs) and "NoNavInputs" or "", bit32.btest(flags, ImGuiWindowFlags.AlwaysAutoResize) and "AlwaysAutoResize" or "")
	if bit32.btest(flags, ImGuiWindowFlags.ChildWindow) then
		ImGui.BulletText("ChildFlags: 0x%08X (%s%s%s%s..)", window.ChildFlags,
			bit32.btest(window.ChildFlags, ImGuiChildFlags.Borders) and "Borders " or "",
			bit32.btest(window.ChildFlags, ImGuiChildFlags.ResizeX) and "ResizeX " or "",
			bit32.btest(window.ChildFlags, ImGuiChildFlags.ResizeY) and "ResizeY " or "",
			bit32.btest(window.ChildFlags, ImGuiChildFlags.NavFlattened) and "NavFlattened " or "")
	end
	ImGui.BulletText("Scroll: (%.2f/%.2f,%.2f/%.2f) Scrollbar:%s%s", window.Scroll.x, window.ScrollMax.x, window.Scroll.y, window.ScrollMax.y, window.ScrollbarX and "X" or "", window.ScrollbarY and "Y" or "")
	ImGui.BulletText("Active: %d/%d, WriteAccessed: %d, BeginOrderWithinContext: %d", BoolToInt(window.Active), BoolToInt(window.WasActive), BoolToInt(window.WriteAccessed), (window.Active or window.WasActive) and window.BeginOrderWithinContext or -1)
	ImGui.BulletText("Appearing: %d, Hidden: %d (CanSkip %d Cannot %d), SkipItems: %d", BoolToInt(window.Appearing), BoolToInt(window.Hidden), window.HiddenFramesCanSkipItems, window.HiddenFramesCannotSkipItems, BoolToInt(window.SkipItems))
	for layer = 0, ImGuiNavLayer.COUNT - 1 do
		local r = window.NavRectRel[layer + 1]
		if r.Min.x >= r.Max.x and r.Min.y >= r.Max.y then
			ImGui.BulletText("NavLastIds[%d]: 0x%08X", layer, window.NavLastIds[layer + 1])
		else
			ImGui.BulletText("NavLastIds[%d]: 0x%08X at +(%.1f,%.1f)(%.1f,%.1f)", layer, window.NavLastIds[layer + 1], r.Min.x, r.Min.y, r.Max.x, r.Max.y)
		end
		ImGui.DebugLocateItemOnHover(window.NavLastIds[layer + 1])
	end
	local pr = window.NavPreferredScoringPosRel
	for layer = 0, ImGuiNavLayer.COUNT - 1 do
		local v = pr[layer + 1]
		ImGui.BulletText("NavPreferredScoringPosRel[%d] = (%.1f,%.1f)", layer, (v.x == FLT_MAX) and -99999.0 or v.x, (v.y == FLT_MAX) and -99999.0 or v.y)
	end
	ImGui.BulletText("NavLayersActiveMask: %X, NavLastChildNavWindow: %s", window.DC.NavLayersActiveMask, window.NavLastChildNavWindow and window.NavLastChildNavWindow.Name or "NULL")
	if window.RootWindow ~= window then
		ImGui.DebugNodeWindow(window.RootWindow, "RootWindow")
	end
	if window.ParentWindow ~= nil then
		ImGui.DebugNodeWindow(window.ParentWindow, "ParentWindow")
	end
	if window.ParentWindowForFocusRoute ~= nil then
		ImGui.DebugNodeWindow(window.ParentWindowForFocusRoute, "ParentWindowForFocusRoute")
	end
	if window.DC.ChildWindows.Size > 0 then
		ImGui.DebugNodeWindowsList(window.DC.ChildWindows, "ChildWindows")
	end
	if window.ColumnsStorage.Size > 0 and ImGui.TreeNode("Columns", "Columns sets (%d)", window.ColumnsStorage.Size) then
		for i = 0, window.ColumnsStorage.Size - 1 do
			ImGui.DebugNodeColumns(window.ColumnsStorage[i + 1])
		end
		ImGui.TreePop()
	end
	ImGui.DebugNodeStorage(window.StateStorage, "Storage")
	ImGui.TreePop()
end

function ImGui.DebugNodeWindowSettings(settings)
	if settings.WantDelete then
		ImGui.BeginDisabled()
	end
	ImGui.BulletText("0x%08X \"%s\" Pos (%d,%d) Size (%d,%d) Collapsed=%d",
		settings.ID, settings:GetName(), settings.Pos.x, settings.Pos.y, settings.Size.x, settings.Size.y, BoolToInt(settings.Collapsed))
	if settings.WantDelete then
		ImGui.EndDisabled()
	end
end

function ImGui.DebugNodeWindowsList(windows, label)
	if not ImGui.TreeNode(label, "%s (%d)", label, windows.Size) then
		return
	end
	for i = windows.Size - 1, 0, -1 do
		ImGui.PushID(windows[i + 1])
		ImGui.DebugNodeWindow(windows[i + 1], "Window")
		ImGui.PopID()
	end
	ImGui.TreePop()
end

function ImGui.DebugNodeWindowsListByBeginStackParent(windows, windows_size, parent_in_begin_stack)
	for i = 0, windows_size - 1 do
		local window = windows[i + 1]
		if window.ParentWindowInBeginStack ~= parent_in_begin_stack then
			continue
		end
		local buf = ImFormatString("[%04d] Window", window.BeginOrderWithinContext)
		ImGui.DebugNodeWindow(window, buf)
		ImGui.TreePush(buf)
		ImGui.DebugNodeWindowsListByBeginStackParent(table.move(windows, i + 2, windows_size, 1, {}), windows_size - i - 1, window)
		ImGui.TreePop()
	end
end

function ImGui.DebugLog(fmt, ...)
	ImGui.DebugLogV(fmt, ...)
end

function ImGui.DebugLogV(fmt, ...)
	local g = ImGui.GImGui
	local old_size = g.DebugLogBuf:size()
	if g.ContextName ~= "" then
		g.DebugLogBuf:append(ImFormatString("[%s] [%05d] ", g.ContextName, g.FrameCount))
	else
		g.DebugLogBuf:append(ImFormatString("[%05d] ", g.FrameCount))
	end
	g.DebugLogBuf:append(ImFormatString(fmt, ...))
	local buf = g.DebugLogBuf:c_str()
	g.DebugLogIndex:append(buf, old_size, g.DebugLogBuf:size())

	if bit32.btest(g.DebugLogFlags, ImGuiDebugLogFlags.OutputToTTY) then
		print((string.gsub(string.sub(buf, old_size + 1), "\n$", "")))
	end
end

function ImGui.SameLineOrWrap(size)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local pos = ImVec2(window.DC.CursorPosPrevLine.x + g.Style.ItemSpacing.x, window.DC.CursorPosPrevLine.y)
	if window.WorkRect:Contains(ImRect.new(pos, pos + size)) then
		ImGui.SameLine()
	end
end

function ImGui.ShowDebugLogFlag(name, flags)
	local g = ImGui.GImGui
	local size = ImVec2(ImGui.GetFrameHeight() + g.Style.ItemInnerSpacing.x + ImGui.CalcTextSize(name).x, ImGui.GetFrameHeight())
	ImGui.SameLineOrWrap(size)

	local highlight_errors = (flags == ImGuiDebugLogFlags.EventError and g.DebugLogSkippedErrors > 0)
	if highlight_errors then
		local a = g.Style.Colors[ImGuiCol.Text + 1]
		ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(a.x + (1.0 - a.x) * 0.30, a.y + (0.0 - a.y) * 0.30, a.z + (0.0 - a.z) * 0.30, a.w + (1.0 - a.w) * 0.30))
	end
	local pressed
	pressed, g.DebugLogFlags = ImGui.CheckboxFlags(name, g.DebugLogFlags, flags)
	if pressed and g.IO.KeyShift and bit32.band(g.DebugLogFlags, flags) ~= 0 then
		g.DebugLogAutoDisableFrames = 2
		g.DebugLogAutoDisableFlags = bit32.bor(g.DebugLogAutoDisableFlags, flags)
	end
	if highlight_errors then
		ImGui.PopStyleColor()
		ImGui.SetItemTooltip("%d past errors skipped.", g.DebugLogSkippedErrors)
	else
		ImGui.SetItemTooltip("Hold Shift when clicking to enable for 2 frames only (useful for spammy log entries)")
	end
end

function ImGui.ShowDebugLogWindow(p_open)
	local g = ImGui.GImGui
	if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 then
		ImGui.SetNextWindowSize(ImVec2(0.0, ImGui.GetFontSize() * 12.0), ImGuiCond.FirstUseEver)
	end
	local visible
	visible, p_open = ImGui.Begin("Dear ImGui Debug Log", p_open)
	if not visible or ImGui.GetCurrentWindow().BeginCount > 1 then
		ImGui.End()
		return p_open
	end

	local all_enable_flags = bit32.band(ImGuiDebugLogFlags.EventMask_, bit32.bnot(ImGuiDebugLogFlags.EventInputRouting))
	_, g.DebugLogFlags = ImGui.CheckboxFlags("All", g.DebugLogFlags, all_enable_flags)
	ImGui.SetItemTooltip("(except InputRouting which is spammy)")

	ImGui.ShowDebugLogFlag("Errors", ImGuiDebugLogFlags.EventError)
	ImGui.ShowDebugLogFlag("ActiveId", ImGuiDebugLogFlags.EventActiveId)
	ImGui.ShowDebugLogFlag("Clipper", ImGuiDebugLogFlags.EventClipper)
	ImGui.ShowDebugLogFlag("Focus", ImGuiDebugLogFlags.EventFocus)
	ImGui.ShowDebugLogFlag("IO", ImGuiDebugLogFlags.EventIO)
	ImGui.ShowDebugLogFlag("Font", ImGuiDebugLogFlags.EventFont)
	ImGui.ShowDebugLogFlag("Nav", ImGuiDebugLogFlags.EventNav)
	ImGui.ShowDebugLogFlag("Popup", ImGuiDebugLogFlags.EventPopup)
	ImGui.ShowDebugLogFlag("Selection", ImGuiDebugLogFlags.EventSelection)
	ImGui.ShowDebugLogFlag("Table", ImGuiDebugLogFlags.EventTable)
	ImGui.ShowDebugLogFlag("InputRouting", ImGuiDebugLogFlags.EventInputRouting)

	if ImGui.SmallButton("Clear") then
		g.DebugLogBuf:clear()
		g.DebugLogIndex:clear()
		g.DebugLogSkippedErrors = 0
	end
	ImGui.SameLine()
	if ImGui.SmallButton("Copy") then
		ImGui.SetClipboardText(g.DebugLogBuf:c_str())
	end
	ImGui.SameLine()
	if ImGui.SmallButton("Configure Outputs..") then
		ImGui.OpenPopup("Outputs")
	end
	if ImGui.BeginPopup("Outputs") then
		_, g.DebugLogFlags = ImGui.CheckboxFlags("OutputToTTY", g.DebugLogFlags, ImGuiDebugLogFlags.OutputToTTY)
		_, g.DebugLogFlags = ImGui.CheckboxFlags("OutputToDebugger", g.DebugLogFlags, ImGuiDebugLogFlags.OutputToDebugger)
		ImGui.BeginDisabled()
		_, g.DebugLogFlags = ImGui.CheckboxFlags("OutputToTestEngine", g.DebugLogFlags, ImGuiDebugLogFlags.OutputToTestEngine)
		ImGui.EndDisabled()
		ImGui.EndPopup()
	end

	ImGui.BeginChild("##log", ImVec2(0.0, 0.0), ImGuiChildFlags.Borders, bit32.bor(ImGuiWindowFlags.AlwaysVerticalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar))

	local backup_log_flags = g.DebugLogFlags
	g.DebugLogFlags = bit32.band(g.DebugLogFlags, bit32.bnot(ImGuiDebugLogFlags.EventClipper))

	local clipper = Structs.ImGuiListClipper.new()
	clipper:Begin(g.DebugLogIndex:size())
	local buf = g.DebugLogBuf:c_str()
	while clipper:Step() do
		for line_no = clipper.DisplayStart, clipper.DisplayEnd - 1 do
			local line_begin = g.DebugLogIndex:get_line_begin(buf, line_no)
			local line_end = g.DebugLogIndex:get_line_end(buf, line_no)
			ImGui.DebugTextUnformattedWithLocateItem(string.sub(buf, line_begin, line_end - 1), nil)
		end
	end
	g.DebugLogFlags = backup_log_flags
	if ImGui.GetScrollY() >= ImGui.GetScrollMaxY() then
		ImGui.SetScrollHereY(1.0)
	end
	ImGui.EndChild()

	ImGui.End()
	return p_open
end

function ImGui.DebugTextUnformattedWithLocateItem(line_begin, line_end)
	if line_end == nil then
		line_end = #line_begin + 1
	end
	ImGui.TextUnformatted(line_begin, line_end)
	if not ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.AllowWhenBlockedByPopup, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem)) then
		return
	end
	local g = ImGui.GImGui
	local text_rect = g.LastItemData.Rect
	local p = 1
	while p <= line_end - 10 do
		local b0, b1 = string.byte(line_begin, p, p + 1)
		local hex = (b0 == 48 and (b1 == 120 or b1 == 88)) and string.match(line_begin, "^%x+", p + 2) or nil
		if hex == nil or Base.ImCharIsXdigitA(string.byte(line_begin, p + 10) or 0) then
			p += 1
			continue
		end
		local id = tonumber(hex, 16)
		local p0 = ImGui.CalcTextSize(line_begin, p)
		local p1 = ImGui.CalcTextSize(string.sub(line_begin, p, p + 9))
		g.LastItemData.Rect = ImRect.new(text_rect.Min + ImVec2(p0.x, 0.0), text_rect.Min + ImVec2(p0.x + p1.x, p1.y))
		if ImGui.IsMouseHoveringRect(g.LastItemData.Rect.Min, g.LastItemData.Rect.Max, true) then
			ImGui.DebugLocateItemOnHover(id)
		end
		p += 11
	end
end

function ImGui.DebugDrawCursorPos(col)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local pos = window.DC.CursorPos
	window.DrawList:AddLineV(pos.x, pos.y - 3.0, pos.y + 4.0, col, 1.0)
	window.DrawList:AddLineH(pos.x - 3.0, pos.x + 4.0, pos.y, col, 1.0)
end

function ImGui.DebugDrawLineExtents(col)
	local g = ImGui.GImGui
	local window = g.CurrentWindow
	local curr_x = window.DC.CursorPos.x
	local line_y1 = window.DC.IsSameLine and window.DC.CursorPosPrevLine.y or window.DC.CursorPos.y
	local line_y2 = line_y1 + (window.DC.IsSameLine and window.DC.PrevLineSize.y or window.DC.CurrLineSize.y)
	window.DrawList:AddLineH(curr_x - 4.0, curr_x + 5.0, line_y1, col, 1.0)
	window.DrawList:AddLineV(curr_x, line_y1, line_y2, col, 1.0)
	window.DrawList:AddLineH(curr_x - 4.0, curr_x + 5.0, line_y2, col, 1.0)
end

function ImGui.DebugDrawItemRect(col)
	local g = ImGui.GImGui
	ImGui.GetForegroundDrawList():AddRect(g.LastItemData.Rect.Min, g.LastItemData.Rect.Max, col)
end

function ImGui.DebugLocateItem(target_id)
	local g = ImGui.GImGui
	g.DebugLocateId = target_id
	g.DebugLocateFrames = 2
	g.DebugBreakInLocateId = false
end

function ImGui.DebugLocateItemOnHover(target_id)
	if target_id == 0 or not ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem, ImGuiHoveredFlags.AllowWhenBlockedByPopup)) then
		return
	end
	local g = ImGui.GImGui
	ImGui.DebugLocateItem(target_id)
	ImGui.GetForegroundDrawList():AddRect(g.LastItemData.Rect.Min - ImVec2(3.0, 3.0), g.LastItemData.Rect.Max + ImVec2(3.0, 3.0), DEBUG_LOCATE_ITEM_COLOR)

	if g.IO.ConfigDebugIsDebuggerPresent and g.MouseStationaryTimer > 1.0 then
		ImGui.DebugBreakButtonTooltip(false, "in ItemAdd()")
		if ImGui.IsKeyChordPressed(g.DebugBreakKeyChord) then
			g.DebugBreakInLocateId = true
		end
	end
end

function ImGui.DebugLocateItemResolveWithLastItem()
	local g = ImGui.GImGui

	local item_data = g.LastItemData
	g.DebugLocateId = 0
	local draw_list = ImGui.GetForegroundDrawList()
	local r = item_data.Rect:Expanded(3.0)
	local p1 = g.IO.MousePos
	local p2 = ImVec2((p1.x < r.Min.x) and r.Min.x or ((p1.x > r.Max.x) and r.Max.x or p1.x), (p1.y < r.Min.y) and r.Min.y or ((p1.y > r.Max.y) and r.Max.y or p1.y))
	draw_list:AddRect(r.Min, r.Max, DEBUG_LOCATE_ITEM_COLOR)
	draw_list:AddLine(p1, p2, DEBUG_LOCATE_ITEM_COLOR)
end

function ImGui.DebugStartItemPicker()
	local g = ImGui.GImGui
	g.DebugItemPickerActive = true
end

local mouse_button_names = { "Left", "Right", "Middle" }

function ImGui.UpdateDebugToolItemPicker()
	local g = ImGui.GImGui
	g.DebugItemPickerBreakId = 0
	if not g.DebugItemPickerActive then
		return
	end

	local hovered_id = g.HoveredIdPreviousFrame
	ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
	if ImGui.IsKeyPressed(ImGuiKey.Escape) then
		g.DebugItemPickerActive = false
	end
	local change_mapping = g.IO.KeyMods == bit32.bor(ImGuiMod.Ctrl, ImGuiMod.Shift)
	if not change_mapping and ImGui.IsMouseClicked(g.DebugItemPickerMouseButton) and hovered_id ~= 0 then
		g.DebugItemPickerBreakId = hovered_id
		g.DebugItemPickerActive = false
	end
	for mouse_button = 0, 2 do
		if change_mapping and ImGui.IsMouseClicked(mouse_button) then
			g.DebugItemPickerMouseButton = mouse_button
		end
	end
	ImGui.SetNextWindowBgAlpha(0.70)
	if not ImGui.BeginTooltip() then
		return
	end
	ImGui.Text("HoveredId: 0x%08X", hovered_id)
	ImGui.Text("Press ESC to abort picking.")
	if change_mapping then
		ImGui.Text("Remap w/ Ctrl+Shift: click anywhere to select new mouse button.")
	else
		ImGui.TextColored(ImGui.GetStyleColorVec4(hovered_id ~= 0 and ImGuiCol.Text or ImGuiCol.TextDisabled), "Click %s Button to break in debugger! (remap w/ Ctrl+Shift)", mouse_button_names[g.DebugItemPickerMouseButton + 1])
	end
	ImGui.EndTooltip()
end

function ImGui.DebugItemPathQuery_UpdateAndGetHookId(query, id)
	if query.MainID ~= id then
		query.MainID = id
		query.Step = -1
		query.Complete = false
		query.Results:resize(0)
		query.ResultsDescBuf:clear()
	end
	query.Active = false
	if id == 0 then
		return 0
	end

	if query.Step >= 0 and query.Step < query.Results.Size then
		local info = query.Results[query.Step + 1]
		if info.QuerySuccess or info.QueryFrameCount > 2 then
			query.Step += 1
		end
	end

	query.Complete = (query.Step == query.Results.Size)
	if query.Step == -1 then
		query.Active = true
		return id
	elseif query.Step >= 0 and query.Step < query.Results.Size then
		local info = query.Results[query.Step + 1]
		info.QueryFrameCount += 1
		query.Active = true
		return info.ID
	end
	return 0
end

function ImGui.UpdateDebugToolItemPathQuery()
	local g = ImGui.GImGui
	local id = 0
	if g.DebugIDStackTool.LastActiveFrame + 1 == g.FrameCount then
		id = (g.HoveredIdPreviousFrame ~= 0) and g.HoveredIdPreviousFrame or g.ActiveId
	end
	g.DebugHookIdInfoId = ImGui.DebugItemPathQuery_UpdateAndGetHookId(g.DebugItemPathQuery, id)
end

function ImGui.DebugHookIdInfo(id, data_type, data_id, data_id_end)
	local g = ImGui.GImGui
	local query = g.DebugItemPathQuery
	if query.Active == false then
		assert(id == 0)
		return
	end
	local window = g.CurrentWindow

	if query.Step == -1 then
		assert(query.Results.Size == 0)
		query.Step += 1
		query.Results:resize(0)
		for n = 0, window.IDStack.Size do
			local info = Structs.ImGuiStackLevelInfo.new()
			info.ID = (n < window.IDStack.Size) and window.IDStack[n + 1] or id
			query.Results:push_back(info)
		end
		return
	end

	assert(query.Step >= 0)
	if query.Step ~= window.IDStack.Size then
		return
	end
	local info = query.Results[query.Step + 1]
	assert(info.ID == id and info.QueryFrameCount > 0)

	if info.DescOffset == -1 then
		local result = nil
		if data_type == ImGuiDataType.S32 then
			result = ImFormatString("%d", data_id)
		elseif data_type == ImGuiDataType.String then
			result = string.sub(data_id, 1, (data_id_end or (#data_id + 1)) - 1)
		elseif data_type == ImGuiDataType.Pointer then
			result = ImFormatString("(void*)0x%p", PtrToNum(data_id))
		elseif data_type == ImGuiDataType.ID then
			result = ImFormatString("0x%08X [override]", id)
		else
			assert(false)
		end
		info.DescOffset = query.ResultsDescBuf:size()
		query.ResultsDescBuf:append(result .. "\0")
	end
	info.QuerySuccess = true
	if info.DataType == -1 then
		info.DataType = data_type
	end
end

local function SkipUncontributingPrefix(label)
	return string.sub(label, Base.ImHashSkipUncontributingPrefix(label))
end

function ImGui.DebugItemPathQuery_FormatLevelInfo(query, n, format_for_ui)
	local info = query.Results[n + 1]
	local window = (info.DescOffset == -1 and n == 0) and ImGui.FindWindowByID(info.ID) or nil
	if window then
		return ImFormatString(format_for_ui and "\"%s\" [window]" or "%s", SkipUncontributingPrefix(window.Name))
	end
	if info.QuerySuccess then
		local desc_buf = query.ResultsDescBuf:c_str()
		local desc_end = string.find(desc_buf, "\0", info.DescOffset + 1, true)
		local desc = string.sub(desc_buf, info.DescOffset + 1, (desc_end or (#desc_buf + 1)) - 1)
		return ImFormatString((format_for_ui and info.DataType == ImGuiDataType.String) and "\"%s\"" or "%s", SkipUncontributingPrefix(desc))
	end
	if query.Step < query.Results.Size then
		return ""
	end
	return "???"
end

function ImGui.DebugItemPathQuery_GetResultAsPath(query, hex_encode_non_ascii_chars)
	local buf = query.ResultPathBuf
	buf:clear()
	for stack_n = 0, query.Results.Size - 1 do
		local level_desc = ImGui.DebugItemPathQuery_FormatLevelInfo(query, stack_n, false)
		buf:append(stack_n == 0 and "//" or "/")
		local level_desc_end = #level_desc + 1
		local p = 1
		while p < level_desc_end and string.byte(level_desc, p) ~= 0 do
			local c_len, c = Base.ImTextCharFromUtf8(level_desc, p, nil)
			local p_next = p + c_len
			if c == 47 then
				buf:append("\\")
			end
			if c < 256 or not hex_encode_non_ascii_chars then
				buf:append(string.sub(level_desc, p, p_next - 1))
			else
				while p < p_next do
					buf:append(ImFormatString("\\x%02x", string.byte(level_desc, p)))
					p += 1
				end
			end
			p = p_next
		end
	end
	return buf:c_str()
end

function ImGui.ShowIDStackToolWindow(p_open)
	local g = ImGui.GImGui
	if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 then
		ImGui.SetNextWindowSize(ImVec2(0.0, ImGui.GetFontSize() * 8.0), ImGuiCond.FirstUseEver)
	end
	local visible
	visible, p_open = ImGui.Begin("Dear ImGui ID Stack Tool", p_open)
	if not visible or ImGui.GetCurrentWindow().BeginCount > 1 then
		ImGui.End()
		return p_open
	end

	local query = g.DebugItemPathQuery
	local tool = g.DebugIDStackTool
	tool.LastActiveFrame = g.FrameCount
	local result_path = ImGui.DebugItemPathQuery_GetResultAsPath(query, tool.OptHexEncodeNonAsciiChars)
	ImGui.Text("0x%08X", query.MainID)
	ImGui.SameLine()
	ImGui.MetricsHelpMarker("Hover an item with the mouse to display elements of the ID Stack leading to the item's final ID.\nEach level of the stack correspond to a PushID() call.\nAll levels of the stack are hashed together to make the final ID of a widget (ID displayed at the bottom level of the stack).\nRead FAQ entry about the ID stack for details.")

	local time_since_copy = g.Time - tool.CopyToClipboardLastTime
	ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, 0.0)
	_, tool.OptHexEncodeNonAsciiChars = ImGui.Checkbox("Hex-encode non-ASCII", tool.OptHexEncodeNonAsciiChars)
	ImGui.SameLine()
	_, tool.OptCopyToClipboardOnCtrlC = ImGui.Checkbox("Ctrl+C: copy path", tool.OptCopyToClipboardOnCtrlC)
	ImGui.PopStyleVar()
	ImGui.SameLine()
	ImGui.TextColored((time_since_copy >= 0.0 and time_since_copy < 0.75 and Base.ImFmod(time_since_copy, 0.25) < 0.25 * 0.5) and ImVec4(1.0, 1.0, 0.3, 1.0) or ImVec4(), "*COPIED*")
	if tool.OptCopyToClipboardOnCtrlC and ImGui.Shortcut(bit32.bor(ImGuiMod.Ctrl, ImGuiKey.C), bit32.bor(ImGuiInputFlags.RouteGlobal, ImGuiInputFlags.RouteOverFocused)) then
		tool.CopyToClipboardLastTime = g.Time
		ImGui.SetClipboardText(result_path)
	end

	ImGui.Text("- Path \"%s\"", query.Complete and result_path or "")
	ImGui.Separator()

	if query.Results.Size > 0 and ImGui.BeginTable("##table", 3, ImGuiTableFlags.Borders) then
		local id_width = ImGui.CalcTextSize("0xDDDDDDDD").x
		ImGui.TableSetupColumn("Seed", ImGuiTableColumnFlags.WidthFixed, id_width)
		ImGui.TableSetupColumn("PushID", ImGuiTableColumnFlags.WidthStretch)
		ImGui.TableSetupColumn("Result", ImGuiTableColumnFlags.WidthFixed, id_width)
		ImGui.TableHeadersRow()
		for n = 0, query.Results.Size - 1 do
			local info = query.Results[n + 1]
			ImGui.TableNextColumn()
			ImGui.Text("0x%08X", (n > 0) and query.Results[n].ID or 0)
			ImGui.TableNextColumn()
			ImGui.TextUnformatted(ImGui.DebugItemPathQuery_FormatLevelInfo(query, n, true))
			ImGui.TableNextColumn()
			ImGui.Text("0x%08X", info.ID)
			if n == query.Results.Size - 1 then
				ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, ImGui.GetColorU32(ImGuiCol.Header))
			end
		end
		ImGui.EndTable()
	end
	ImGui.End()
	return p_open
end

function ImGui.ShowFontSelector(label)
	local io = ImGui.GetIO()
	local font_current = ImGui.GetFont()
	if ImGui.BeginCombo(label, font_current:GetDebugName()) then
		for i = 0, io.Fonts.Fonts.Size - 1 do
			local font = io.Fonts.Fonts[i + 1]
			ImGui.PushID(font)
			if ImGui.Selectable(font:GetDebugName(), font == font_current, ImGuiSelectableFlags.SelectOnNav) then
				io.FontDefault = font
			end
			if font == font_current then
				ImGui.SetItemDefaultFocus()
			end
			ImGui.PopID()
		end
		ImGui.EndCombo()
	end
	ImGui.SameLine()
	if bit32.btest(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures) then
		ImGui.MetricsHelpMarker("- Load additional fonts with io.Fonts->AddFontXXX() functions.\n- Read FAQ and docs/FONTS.md for more details.")
	else
		ImGui.MetricsHelpMarker("- Load additional fonts with io.Fonts->AddFontXXX() functions.\n- The font atlas is built when calling io.Fonts->GetTexDataAsXXXX() or io.Fonts->Build().\n- Read FAQ and docs/FONTS.md for more details.\n- Legacy backend: if you need to add/remove fonts at runtime (e.g. for DPI change), do it before calling NewFrame().")
	end
end

return true
