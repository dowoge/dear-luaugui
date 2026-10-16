--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")
local Structs = require("./Structs")
local DrawList = require("./DrawList")

local ImVec2, ImRect = Base.ImVec2, Base.ImRect
local ImMin, ImMax, ImClamp = Base.ImMin, Base.ImMax, Base.ImClamp
local ImTrunc, IM_TRUNC = Base.ImTrunc, Base.IM_TRUNC
local FLT_MAX = Base.FLT_MAX
local IM_COL32_A_MASK = Base.IM_COL32_A_MASK
local ImTextCharFromUtf8 = Base.ImTextCharFromUtf8
local ImCharIsBlankW = Base.ImCharIsBlankW

local ImGuiInputTextFlags = Enums.ImGuiInputTextFlags
local ImGuiItemFlags = Enums.ImGuiItemFlags
local ImGuiItemStatusFlags = Enums.ImGuiItemStatusFlags
local ImGuiDir = Enums.ImGuiDir
local ImGuiKey = Enums.ImGuiKey
local ImGuiMod = Enums.ImGuiMod
local ImGuiInputFlags = Enums.ImGuiInputFlags
local ImGuiConfigFlags = Enums.ImGuiConfigFlags
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiCol = Enums.ImGuiCol
local ImGuiStyleVar = Enums.ImGuiStyleVar
local ImGuiChildFlags = Enums.ImGuiChildFlags
local ImGuiWindowFlags = Enums.ImGuiWindowFlags
local ImGuiMouseCursor = Enums.ImGuiMouseCursor
local ImGuiActivateFlags = Enums.ImGuiActivateFlags
local ImGuiAxis = Enums.ImGuiAxis
local ImDrawFlags = Enums.ImDrawFlags
local ImDrawTextFlags = Enums.ImDrawTextFlags

local ImGuiInputTextState = Structs.ImGuiInputTextState
local ImGuiInputTextCallbackData = Structs.ImGuiInputTextCallbackData

local band, bor, bnot, btest, lshift = bit32.band, bit32.bor, bit32.bnot, bit32.btest, bit32.lshift
local sbyte, ssub, sfind = string.byte, string.sub, string.find

local INT_MAX = 0x7FFFFFFF
local IM_UNICODE_CODEPOINT_MAX = Base.IM_UNICODE_CODEPOINT_MAX or 0xFFFF

local IMSTB_TEXTEDIT_UNDOSTATECOUNT = 99
local IMSTB_TEXTEDIT_UNDOCHARCOUNT = 999
local IMSTB_TEXTEDIT_GETWIDTH_NEWLINE = -1.0
local STB_TEXTEDIT_NEWLINE = 10

local STB_TEXTEDIT_K_LEFT = 0x200000
local STB_TEXTEDIT_K_RIGHT = 0x200001
local STB_TEXTEDIT_K_UP = 0x200002
local STB_TEXTEDIT_K_DOWN = 0x200003
local STB_TEXTEDIT_K_LINESTART = 0x200004
local STB_TEXTEDIT_K_LINEEND = 0x200005
local STB_TEXTEDIT_K_TEXTSTART = 0x200006
local STB_TEXTEDIT_K_TEXTEND = 0x200007
local STB_TEXTEDIT_K_DELETE = 0x200008
local STB_TEXTEDIT_K_BACKSPACE = 0x200009
local STB_TEXTEDIT_K_UNDO = 0x20000A
local STB_TEXTEDIT_K_REDO = 0x20000B
local STB_TEXTEDIT_K_WORDLEFT = 0x20000C
local STB_TEXTEDIT_K_WORDRIGHT = 0x20000D
local STB_TEXTEDIT_K_PGUP = 0x20000E
local STB_TEXTEDIT_K_PGDOWN = 0x20000F
local STB_TEXTEDIT_K_SHIFT = 0x400000

local function ImFontCalcTextSizeEx(...)
	return (DrawList.ImFontCalcTextSizeEx or Base.ImFontCalcTextSizeEx)(...)
end

local function ImFontCalcWordWrapPositionEx(...)
	return (DrawList.ImFontCalcWordWrapPositionEx or Base.ImFontCalcWordWrapPositionEx)(...)
end

local function LineEndAfterNewline(text, from, text_end)
	local e = sfind(text, "\n", from + 1, true)
	if e == nil or e > text_end then
		return text_end
	end
	return e
end

local function InputTextCalcTextSize(ctx, text, text_begin, text_end_display, text_end, flags)
	local g = ctx
	local obj = g.InputTextState
	assert(text_end_display >= text_begin and text_end_display <= text_end)
	local lim
	if btest(flags, ImDrawTextFlags.StopOnNewLine) then
		lim = LineEndAfterNewline(text, text_begin, text_end)
		text_end_display = ImMin(text_end_display, lim)
	else
		lim = LineEndAfterNewline(text, text_end_display, text_end)
	end
	local size, remaining, offset = ImFontCalcTextSizeEx(g.Font, g.FontSize, FLT_MAX, obj.WrapWidth, ssub(text, text_begin + 1, lim), text_end_display - text_begin + 1, lim - text_begin + 1, nil, nil, flags)
	return size, text_begin + (remaining or 1) - 1, offset
end

local function WrapPositionEx(g, text, p, text_end, wrap_width, flags)
	local lim = LineEndAfterNewline(text, p, text_end)
	local r = ImFontCalcWordWrapPositionEx(g.Font, g.FontSize, ssub(text, p + 1, lim), nil, wrap_width, flags)
	return p + r - 1
end

local function PrevCodepoint(text, start, p)
	while p > start do
		p -= 1
		if band(sbyte(text, p + 1), 0xC0) ~= 0x80 then
			return p
		end
	end
	return start
end

local function DecodeAt(obj, idx)
	if idx >= obj.TextLen then
		return 0
	end
	local _, c = ImTextCharFromUtf8(obj.TextSrc, idx + 1, obj.TextLen + 1)
	return c
end

local function STB_TEXTEDIT_GETCHAR(obj, idx)
	assert(idx >= 0 and idx <= obj.TextLen)
	return sbyte(obj.TextSrc, idx + 1) or 0
end

local function STB_TEXTEDIT_GETWIDTH(obj, line_start_idx, char_idx)
	local c = DecodeAt(obj, line_start_idx + char_idx)
	if c == STB_TEXTEDIT_NEWLINE then
		return IMSTB_TEXTEDIT_GETWIDTH_NEWLINE
	end
	local g = obj.Ctx
	return g.FontBaked:GetCharAdvance(c) * g.FontBakedScale
end

local function STB_TEXTEDIT_LAYOUTROW(r, obj, line_start_idx)
	local size, text_remaining = InputTextCalcTextSize(obj.Ctx, obj.TextSrc, line_start_idx, obj.TextLen, obj.TextLen, bor(ImDrawTextFlags.StopOnNewLine, ImDrawTextFlags.WrapKeepBlanks))
	r.x0 = 0.0
	r.x1 = size.x
	r.baseline_y_delta = size.y
	r.ymin = 0.0
	r.ymax = size.y
	r.num_chars = text_remaining - line_start_idx
end

local function IMSTB_TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
	if idx >= obj.TextLen then
		return obj.TextLen + 1
	end
	local n = ImTextCharFromUtf8(obj.TextSrc, idx + 1, obj.TextLen + 1)
	return idx + ImMax(n, 1)
end

local function IMSTB_TEXTEDIT_GETPREVCHARINDEX(obj, idx)
	if idx <= 0 then
		return -1
	end
	return PrevCodepoint(obj.TextSrc, 0, idx)
end

local separator_list = {}
for _, c in { 44, 0x3001, 46, 0x3002, 59, 0xFF1B, 40, 0xFF08, 41, 0xFF09, 123, 0xFF5B, 125, 0xFF5D, 91, 0x300C, 93, 0x300D, 124, 0xFF5C, 33, 0xFF01, 92, 0xFFE5, 47, 0x30FB, 0xFF0F, 10, 13 } do
	separator_list[c] = true
end

local function ImCharIsSeparatorW(c)
	return separator_list[c] == true
end

local function is_word_boundary_from_right(obj, idx)
	if btest(obj.Flags, ImGuiInputTextFlags.Password) or idx <= 0 then
		return false
	end
	local prev_p = PrevCodepoint(obj.TextSrc, 0, idx)
	local curr_c = DecodeAt(obj, idx)
	local prev_c = DecodeAt(obj, prev_p)
	local prev_white = ImCharIsBlankW(prev_c)
	local prev_separ = ImCharIsSeparatorW(prev_c)
	local curr_white = ImCharIsBlankW(curr_c)
	local curr_separ = ImCharIsSeparatorW(curr_c)
	return ((prev_white or prev_separ) and not (curr_separ or curr_white)) or (curr_separ and not prev_separ)
end

local function is_word_boundary_from_left(obj, idx)
	if btest(obj.Flags, ImGuiInputTextFlags.Password) or idx <= 0 then
		return false
	end
	local prev_p = PrevCodepoint(obj.TextSrc, 0, idx)
	local prev_c = DecodeAt(obj, idx)
	local curr_c = DecodeAt(obj, prev_p)
	local prev_white = ImCharIsBlankW(prev_c)
	local prev_separ = ImCharIsSeparatorW(prev_c)
	local curr_white = ImCharIsBlankW(curr_c)
	local curr_separ = ImCharIsSeparatorW(curr_c)
	return (prev_white and not (curr_separ or curr_white)) or (curr_separ and not prev_separ)
end

local function STB_TEXTEDIT_MOVEWORDLEFT(obj, idx)
	idx = IMSTB_TEXTEDIT_GETPREVCHARINDEX(obj, idx)
	while idx >= 0 and not is_word_boundary_from_right(obj, idx) do
		idx = IMSTB_TEXTEDIT_GETPREVCHARINDEX(obj, idx)
	end
	return if idx < 0 then 0 else idx
end

local function STB_TEXTEDIT_MOVEWORDRIGHT_MAC(obj, idx)
	local len = obj.TextLen
	idx = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
	while idx < len and not is_word_boundary_from_left(obj, idx) do
		idx = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
	end
	return if idx > len then len else idx
end

local function STB_TEXTEDIT_MOVEWORDRIGHT_WIN(obj, idx)
	idx = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
	local len = obj.TextLen
	while idx < len and not is_word_boundary_from_right(obj, idx) do
		idx = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
	end
	return if idx > len then len else idx
end

local function STB_TEXTEDIT_MOVEWORDRIGHT(obj, idx)
	local g = obj.Ctx
	if g.IO.ConfigMacOSXBehaviors then
		return STB_TEXTEDIT_MOVEWORDRIGHT_MAC(obj, idx)
	end
	return STB_TEXTEDIT_MOVEWORDRIGHT_WIN(obj, idx)
end

local function ImStrbol(text, p)
	while p > 0 and sbyte(text, p) ~= 10 do
		p -= 1
	end
	return p
end

local function STB_TEXTEDIT_MOVELINESTART(obj, state, cursor)
	if state.single_line ~= 0 then
		return 0
	end
	if obj.WrapWidth > 0.0 then
		local g = obj.Ctx
		local src = obj.TextSrc
		local p_cursor = cursor
		local p_bol = ImStrbol(src, p_cursor)
		local p = p_bol
		local text_end = obj.TextLen
		while p >= p_bol do
			local p_eol = WrapPositionEx(g, src, p, text_end, obj.WrapWidth, ImDrawTextFlags.WrapKeepBlanks)
			if p == p_cursor then
				return p_bol
			end
			if p_eol == p_cursor and sbyte(src, cursor + 1) ~= 10 and obj.LastMoveDirectionLR == ImGuiDir.Left then
				return p_bol
			end
			if p_eol >= p_cursor then
				return p
			end
			p = if sbyte(src, p_eol + 1) == 10 then p_eol + 1 else p_eol
		end
	end
	while cursor > 0 do
		local prev_cursor = IMSTB_TEXTEDIT_GETPREVCHARINDEX(obj, cursor)
		if STB_TEXTEDIT_GETCHAR(obj, prev_cursor) == STB_TEXTEDIT_NEWLINE then
			break
		end
		cursor = prev_cursor
	end
	return cursor
end

local function STB_TEXTEDIT_MOVELINEEND(obj, state, cursor)
	local n = obj.TextLen
	if state.single_line ~= 0 then
		return n
	end
	if obj.WrapWidth > 0.0 then
		local g = obj.Ctx
		local src = obj.TextSrc
		local p_cursor = cursor
		local p = ImStrbol(src, p_cursor)
		local text_end = obj.TextLen
		while p < text_end do
			local p_eol = WrapPositionEx(g, src, p, text_end, obj.WrapWidth, ImDrawTextFlags.WrapKeepBlanks)
			cursor = p_eol
			if p_eol == p_cursor and obj.LastMoveDirectionLR ~= ImGuiDir.Left then
				break
			end
			if p_eol > p_cursor then
				return cursor
			end
			p = if sbyte(src, p_eol + 1) == 10 then p_eol + 1 else p_eol
		end
	end
	while cursor < n and STB_TEXTEDIT_GETCHAR(obj, cursor) ~= STB_TEXTEDIT_NEWLINE do
		cursor = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(obj, cursor)
	end
	return cursor
end

local function STB_TEXTEDIT_DELETECHARS(obj, pos, n)
	assert(obj.TextSrc == obj.TextA)
	local t = obj.TextA
	t = ssub(t, 1, pos) .. ssub(t, pos + n + 1)
	obj.TextA = t
	obj.TextSrc = t
	obj.EditedBefore = true
	obj.EditedThisFrame = true
	obj.TextLen -= n
end

local function STB_TEXTEDIT_INSERTCHARS(obj, pos, new_text, new_text_len)
	local text_len = obj.TextLen
	assert(pos <= text_len)
	if new_text_len == 0 then
		return 0
	end
	assert(obj.TextSrc == obj.TextA)
	local t = obj.TextA
	t = ssub(t, 1, pos) .. ssub(new_text, 1, new_text_len) .. ssub(t, pos + 1)
	obj.TextA = t
	obj.TextSrc = t
	obj.EditedBefore = true
	obj.EditedThisFrame = true
	obj.TextLen += new_text_len
	return new_text_len
end

local stb_states = setmetatable({}, { __mode = "k" })

local function stb_new_state()
	local undo_rec = table.create(IMSTB_TEXTEDIT_UNDOSTATECOUNT)
	for i = 1, IMSTB_TEXTEDIT_UNDOSTATECOUNT do
		undo_rec[i] = { where = 0, insert_length = 0, delete_length = 0, char_storage = 0 }
	end
	local st = {
		cursor = 0,
		select_start = 0,
		select_end = 0,
		insert_mode = 0,
		row_count_per_page = 0,
		cursor_at_end_of_line = 0,
		initialized = 0,
		has_preferred_x = 0,
		single_line = 0,
		preferred_x = 0.0,
		undostate = {
			undo_rec = undo_rec,
			undo_char = table.create(IMSTB_TEXTEDIT_UNDOCHARCOUNT, 0),
			undo_point = 0,
			redo_point = 0,
			undo_char_point = 0,
			redo_char_point = 0,
		},
	}
	stb_states[st] = true
	return st
end

local function stb_undo_rec_copy(dst, src)
	dst.where = src.where
	dst.insert_length = src.insert_length
	dst.delete_length = src.delete_length
	dst.char_storage = src.char_storage
end

local function stb_undo_chars(s, off, len)
	return string.char(table.unpack(s.undo_char, off + 1, off + len))
end

local function STB_TEXT_HAS_SELECTION(s)
	return s.select_start ~= s.select_end
end

local function stb_text_locate_coord(str, x, y)
	local r = { x0 = 0, x1 = 0, baseline_y_delta = 0, ymin = 0, ymax = 0, num_chars = 0 }
	local n = str.TextLen
	local base_y = 0
	local i = 0
	while i < n do
		STB_TEXTEDIT_LAYOUTROW(r, str, i)
		if r.num_chars <= 0 then
			return n, 0
		end
		if i == 0 and y < base_y + r.ymin then
			return 0, 0
		end
		if y < base_y + r.ymax then
			break
		end
		i += r.num_chars
		base_y += r.baseline_y_delta
	end
	if i >= n then
		return n, 1
	end
	if x < r.x0 then
		return i, 0
	end
	if x < r.x1 then
		local prev_x = r.x0
		local k = 0
		while k < r.num_chars do
			local w = STB_TEXTEDIT_GETWIDTH(str, i, k)
			if x < prev_x + w then
				local side_on_line = if k == 0 then 0 else 1
				if x < prev_x + w / 2 then
					return k + i, side_on_line
				end
				return IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, i + k), side_on_line
			end
			prev_x += w
			k = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, i + k) - i
		end
	end
	if STB_TEXTEDIT_GETCHAR(str, i + r.num_chars - 1) == STB_TEXTEDIT_NEWLINE then
		return i + r.num_chars - 1, 1
	end
	return i + r.num_chars, 1
end

local function stb_textedit_click(str, state, x, y)
	if state.single_line ~= 0 then
		local r = {}
		STB_TEXTEDIT_LAYOUTROW(r, str, 0)
		y = r.ymin
	end
	local cursor, side_on_line = stb_text_locate_coord(str, x, y)
	state.cursor = cursor
	state.select_start = state.cursor
	state.select_end = state.cursor
	state.has_preferred_x = 0
	str.LastMoveDirectionLR = if side_on_line ~= 0 then ImGuiDir.Right else ImGuiDir.Left
end

local function stb_textedit_drag(str, state, x, y)
	if state.single_line ~= 0 then
		local r = {}
		STB_TEXTEDIT_LAYOUTROW(r, str, 0)
		y = r.ymin
	end
	if state.select_start == state.select_end then
		state.select_start = state.cursor
	end
	local p, side_on_line = stb_text_locate_coord(str, x, y)
	state.cursor = p
	state.select_end = p
	str.LastMoveDirectionLR = if side_on_line ~= 0 then ImGuiDir.Right else ImGuiDir.Left
end

local function stb_textedit_find_charpos(find, str, n, single_line)
	local r = { x0 = 0, x1 = 0, baseline_y_delta = 0, ymin = 0, ymax = 0, num_chars = 0 }
	local prev_start = 0
	local z = str.TextLen
	local i = 0
	if n == z and single_line ~= 0 then
		STB_TEXTEDIT_LAYOUTROW(r, str, 0)
		find.y = 0
		find.first_char = 0
		find.length = z
		find.height = r.ymax - r.ymin
		find.x = r.x1
		return
	end
	find.y = 0
	while true do
		STB_TEXTEDIT_LAYOUTROW(r, str, i)
		if n < i + r.num_chars then
			break
		end
		if str.LastMoveDirectionLR == ImGuiDir.Right and str.Stb.cursor > 0 and str.Stb.cursor == i + r.num_chars and STB_TEXTEDIT_GETCHAR(str, i + r.num_chars - 1) ~= STB_TEXTEDIT_NEWLINE then
			break
		end
		if i + r.num_chars == z and z > 0 and STB_TEXTEDIT_GETCHAR(str, z - 1) ~= STB_TEXTEDIT_NEWLINE then
			break
		end
		prev_start = i
		i += r.num_chars
		find.y += r.baseline_y_delta
		if i == z then
			r.num_chars = 0
			break
		end
	end
	local first = i
	find.first_char = first
	find.length = r.num_chars
	find.height = r.ymax - r.ymin
	find.prev_first = prev_start
	find.x = r.x0
	i = 0
	while first + i < n do
		find.x += STB_TEXTEDIT_GETWIDTH(str, first, i)
		i = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, first + i) - first
	end
end

local function stb_textedit_clamp(str, state)
	local n = str.TextLen
	if STB_TEXT_HAS_SELECTION(state) then
		if state.select_start > n then
			state.select_start = n
		end
		if state.select_end > n then
			state.select_end = n
		end
		if state.select_start == state.select_end then
			state.cursor = state.select_start
		end
	end
	if state.cursor > n then
		state.cursor = n
	end
end

local function stb_textedit_flush_redo(state)
	state.redo_point = IMSTB_TEXTEDIT_UNDOSTATECOUNT
	state.redo_char_point = IMSTB_TEXTEDIT_UNDOCHARCOUNT
end

local function stb_textedit_discard_undo(state)
	if state.undo_point > 0 then
		local rec = state.undo_rec
		if rec[1].char_storage >= 0 then
			local n = rec[1].insert_length
			state.undo_char_point -= n
			table.move(state.undo_char, n + 1, n + state.undo_char_point, 1)
			for i = 0, state.undo_point - 1 do
				if rec[i + 1].char_storage >= 0 then
					rec[i + 1].char_storage -= n
				end
			end
		end
		state.undo_point -= 1
		for i = 1, state.undo_point do
			stb_undo_rec_copy(rec[i], rec[i + 1])
		end
	end
end

local function stb_textedit_discard_redo(state)
	local k = IMSTB_TEXTEDIT_UNDOSTATECOUNT - 1
	if state.redo_point <= k then
		local rec = state.undo_rec
		if rec[k + 1].char_storage >= 0 then
			local n = rec[k + 1].insert_length
			state.redo_char_point += n
			local count = IMSTB_TEXTEDIT_UNDOCHARCOUNT - state.redo_char_point
			table.move(state.undo_char, state.redo_char_point - n + 1, state.redo_char_point - n + count, state.redo_char_point + 1)
			for i = state.redo_point, k - 1 do
				if rec[i + 1].char_storage >= 0 then
					rec[i + 1].char_storage += n
				end
			end
		end
		local move_count = IMSTB_TEXTEDIT_UNDOSTATECOUNT - state.redo_point - 1
		assert(state.redo_point >= 0)
		assert(state.redo_point + 1 + move_count <= IMSTB_TEXTEDIT_UNDOSTATECOUNT)
		for i = move_count - 1, 0, -1 do
			stb_undo_rec_copy(rec[state.redo_point + i + 2], rec[state.redo_point + i + 1])
		end
		state.redo_point += 1
	end
end

local function stb_text_create_undo_record(state, numchars)
	stb_textedit_flush_redo(state)
	if state.undo_point == IMSTB_TEXTEDIT_UNDOSTATECOUNT then
		stb_textedit_discard_undo(state)
	end
	if numchars > IMSTB_TEXTEDIT_UNDOCHARCOUNT then
		state.undo_point = 0
		state.undo_char_point = 0
		return nil
	end
	while state.undo_char_point + numchars > IMSTB_TEXTEDIT_UNDOCHARCOUNT do
		stb_textedit_discard_undo(state)
	end
	state.undo_point += 1
	return state.undo_rec[state.undo_point]
end

local function stb_text_createundo(state, pos, insert_len, delete_len)
	local r = stb_text_create_undo_record(state, insert_len)
	if r == nil then
		return nil
	end
	r.where = pos
	r.insert_length = insert_len
	r.delete_length = delete_len
	if insert_len == 0 then
		r.char_storage = -1
		return nil
	end
	r.char_storage = state.undo_char_point
	state.undo_char_point += insert_len
	return r.char_storage
end

local function stb_text_undo(str, state)
	local s = state.undostate
	if s.undo_point == 0 then
		return
	end
	local ur = s.undo_rec[s.undo_point]
	local u_where, u_insert_length, u_delete_length, u_char_storage = ur.where, ur.insert_length, ur.delete_length, ur.char_storage
	local r = s.undo_rec[s.redo_point]
	r.char_storage = -1
	r.insert_length = u_delete_length
	r.delete_length = u_insert_length
	r.where = u_where
	if u_delete_length ~= 0 then
		if s.undo_char_point + u_delete_length >= IMSTB_TEXTEDIT_UNDOCHARCOUNT then
			r.insert_length = 0
		else
			while s.undo_char_point + u_delete_length > s.redo_char_point do
				if s.redo_point == IMSTB_TEXTEDIT_UNDOSTATECOUNT then
					return
				end
				stb_textedit_discard_redo(s)
			end
			r = s.undo_rec[s.redo_point]
			r.char_storage = s.redo_char_point - u_delete_length
			s.redo_char_point = s.redo_char_point - u_delete_length
			for i = 0, u_delete_length - 1 do
				s.undo_char[r.char_storage + i + 1] = STB_TEXTEDIT_GETCHAR(str, u_where + i)
			end
		end
		STB_TEXTEDIT_DELETECHARS(str, u_where, u_delete_length)
	end
	if u_insert_length ~= 0 then
		u_insert_length = STB_TEXTEDIT_INSERTCHARS(str, u_where, stb_undo_chars(s, u_char_storage, u_insert_length), u_insert_length)
		s.undo_char_point -= u_insert_length
	end
	state.cursor = u_where + u_insert_length
	s.undo_point -= 1
	s.redo_point -= 1
end

local function stb_text_redo(str, state)
	local s = state.undostate
	if s.redo_point == IMSTB_TEXTEDIT_UNDOSTATECOUNT then
		return
	end
	local u = s.undo_rec[s.undo_point + 1]
	local rr = s.undo_rec[s.redo_point + 1]
	local r_where, r_insert_length, r_delete_length, r_char_storage = rr.where, rr.insert_length, rr.delete_length, rr.char_storage
	u.delete_length = r_insert_length
	u.insert_length = r_delete_length
	u.where = r_where
	u.char_storage = -1
	if r_delete_length ~= 0 then
		if s.undo_char_point + u.insert_length > s.redo_char_point then
			u.insert_length = 0
			u.delete_length = 0
		else
			u.char_storage = s.undo_char_point
			s.undo_char_point = s.undo_char_point + u.insert_length
			for i = 0, u.insert_length - 1 do
				s.undo_char[u.char_storage + i + 1] = STB_TEXTEDIT_GETCHAR(str, u.where + i)
			end
		end
		STB_TEXTEDIT_DELETECHARS(str, r_where, r_delete_length)
	end
	if r_insert_length ~= 0 then
		r_insert_length = STB_TEXTEDIT_INSERTCHARS(str, r_where, stb_undo_chars(s, r_char_storage, r_insert_length), r_insert_length)
		s.redo_char_point += r_insert_length
	end
	state.cursor = r_where + r_insert_length
	s.undo_point += 1
	s.redo_point += 1
end

local function stb_text_makeundo_insert(state, where, length)
	stb_text_createundo(state.undostate, where, 0, length)
end

local function stb_text_makeundo_delete(str, state, where, length)
	local p = stb_text_createundo(state.undostate, where, length, 0)
	if p then
		local undo_char = state.undostate.undo_char
		for i = 0, length - 1 do
			undo_char[p + i + 1] = STB_TEXTEDIT_GETCHAR(str, where + i)
		end
	end
end

local function stb_text_makeundo_replace(str, state, where, old_length, new_length)
	local p = stb_text_createundo(state.undostate, where, old_length, new_length)
	if p then
		local undo_char = state.undostate.undo_char
		for i = 0, old_length - 1 do
			undo_char[p + i + 1] = STB_TEXTEDIT_GETCHAR(str, where + i)
		end
	end
end

local function stb_textedit_delete(str, state, where, len)
	stb_text_makeundo_delete(str, state, where, len)
	STB_TEXTEDIT_DELETECHARS(str, where, len)
	state.has_preferred_x = 0
end

local function stb_textedit_delete_selection(str, state)
	stb_textedit_clamp(str, state)
	if STB_TEXT_HAS_SELECTION(state) then
		if state.select_start < state.select_end then
			stb_textedit_delete(str, state, state.select_start, state.select_end - state.select_start)
			state.select_end = state.select_start
			state.cursor = state.select_start
		else
			stb_textedit_delete(str, state, state.select_end, state.select_start - state.select_end)
			state.select_start = state.select_end
			state.cursor = state.select_end
		end
		state.has_preferred_x = 0
	end
end

local function stb_textedit_sortselection(state)
	if state.select_end < state.select_start then
		state.select_start, state.select_end = state.select_end, state.select_start
	end
end

local function stb_textedit_move_to_first(state)
	if STB_TEXT_HAS_SELECTION(state) then
		stb_textedit_sortselection(state)
		state.cursor = state.select_start
		state.select_end = state.select_start
		state.has_preferred_x = 0
	end
end

local function stb_textedit_move_to_last(str, state)
	if STB_TEXT_HAS_SELECTION(state) then
		stb_textedit_sortselection(state)
		stb_textedit_clamp(str, state)
		state.cursor = state.select_end
		state.select_start = state.select_end
		state.has_preferred_x = 0
	end
end

local function stb_textedit_prep_selection_at_cursor(state)
	if not STB_TEXT_HAS_SELECTION(state) then
		state.select_start = state.cursor
		state.select_end = state.cursor
	else
		state.cursor = state.select_end
	end
end

local function stb_textedit_cut(str, state)
	if STB_TEXT_HAS_SELECTION(state) then
		stb_textedit_delete_selection(str, state)
		state.has_preferred_x = 0
		return 1
	end
	return 0
end

local function stb_textedit_paste_internal(str, state, text, len)
	stb_textedit_clamp(str, state)
	stb_textedit_delete_selection(str, state)
	len = STB_TEXTEDIT_INSERTCHARS(str, state.cursor, text, len)
	if len ~= 0 then
		stb_text_makeundo_insert(state, state.cursor, len)
		state.cursor += len
		state.has_preferred_x = 0
		return 1
	end
	return 0
end

local function stb_textedit_text(str, state, text, text_len)
	if sbyte(text, 1) == STB_TEXTEDIT_NEWLINE and state.single_line ~= 0 then
		return
	end
	if state.insert_mode ~= 0 and not STB_TEXT_HAS_SELECTION(state) and state.cursor < str.TextLen then
		stb_text_makeundo_replace(str, state, state.cursor, 1, 1)
		STB_TEXTEDIT_DELETECHARS(str, state.cursor, 1)
		text_len = STB_TEXTEDIT_INSERTCHARS(str, state.cursor, text, text_len)
		if text_len ~= 0 then
			state.cursor += text_len
			state.has_preferred_x = 0
		end
	else
		stb_textedit_delete_selection(str, state)
		text_len = STB_TEXTEDIT_INSERTCHARS(str, state.cursor, text, text_len)
		if text_len ~= 0 then
			stb_text_makeundo_insert(state, state.cursor, text_len)
			state.cursor += text_len
			state.has_preferred_x = 0
		end
	end
end

local K_SHIFT = STB_TEXTEDIT_K_SHIFT

local function stb_textedit_key(str, state, key)
	if key == STB_TEXTEDIT_K_UNDO then
		stb_text_undo(str, state)
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_REDO then
		stb_text_redo(str, state)
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_LEFT then
		if STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_move_to_first(state)
		elseif state.cursor > 0 then
			state.cursor = IMSTB_TEXTEDIT_GETPREVCHARINDEX(str, state.cursor)
		end
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_RIGHT then
		if STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_move_to_last(str, state)
		else
			state.cursor = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, state.cursor)
		end
		stb_textedit_clamp(str, state)
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_LEFT + K_SHIFT then
		stb_textedit_clamp(str, state)
		stb_textedit_prep_selection_at_cursor(state)
		if state.select_end > 0 then
			state.select_end = IMSTB_TEXTEDIT_GETPREVCHARINDEX(str, state.select_end)
		end
		state.cursor = state.select_end
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_WORDLEFT then
		if STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_move_to_first(state)
		else
			state.cursor = STB_TEXTEDIT_MOVEWORDLEFT(str, state.cursor)
			stb_textedit_clamp(str, state)
		end
	elseif key == STB_TEXTEDIT_K_WORDLEFT + K_SHIFT then
		if not STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_prep_selection_at_cursor(state)
		end
		state.cursor = STB_TEXTEDIT_MOVEWORDLEFT(str, state.cursor)
		state.select_end = state.cursor
		stb_textedit_clamp(str, state)
	elseif key == STB_TEXTEDIT_K_WORDRIGHT then
		if STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_move_to_last(str, state)
		else
			state.cursor = STB_TEXTEDIT_MOVEWORDRIGHT(str, state.cursor)
			stb_textedit_clamp(str, state)
		end
	elseif key == STB_TEXTEDIT_K_WORDRIGHT + K_SHIFT then
		if not STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_prep_selection_at_cursor(state)
		end
		state.cursor = STB_TEXTEDIT_MOVEWORDRIGHT(str, state.cursor)
		state.select_end = state.cursor
		stb_textedit_clamp(str, state)
	elseif key == STB_TEXTEDIT_K_RIGHT + K_SHIFT then
		stb_textedit_prep_selection_at_cursor(state)
		state.select_end = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, state.select_end)
		stb_textedit_clamp(str, state)
		state.cursor = state.select_end
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_DOWN or key == STB_TEXTEDIT_K_DOWN + K_SHIFT or key == STB_TEXTEDIT_K_PGDOWN or key == STB_TEXTEDIT_K_PGDOWN + K_SHIFT then
		local sel = btest(key, K_SHIFT)
		local is_page = band(key, bnot(K_SHIFT)) == STB_TEXTEDIT_K_PGDOWN
		local row_count = if is_page then state.row_count_per_page else 1
		if not is_page and state.single_line ~= 0 then
			return stb_textedit_key(str, state, bor(STB_TEXTEDIT_K_RIGHT, band(key, K_SHIFT)))
		end
		if sel then
			stb_textedit_prep_selection_at_cursor(state)
		elseif STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_move_to_last(str, state)
		end
		stb_textedit_clamp(str, state)
		local find = { x = 0, y = 0, height = 0, first_char = 0, length = 0, prev_first = 0 }
		stb_textedit_find_charpos(find, str, state.cursor, state.single_line)
		local row = { x0 = 0, x1 = 0, baseline_y_delta = 0, ymin = 0, ymax = 0, num_chars = 0 }
		for _ = 0, row_count - 1 do
			local goal_x = if state.has_preferred_x ~= 0 then state.preferred_x else find.x
			local start = find.first_char + find.length
			if find.length == 0 then
				break
			end
			state.cursor = start
			STB_TEXTEDIT_LAYOUTROW(row, str, state.cursor)
			local x = row.x0
			local i = 0
			while i < row.num_chars do
				local dx = STB_TEXTEDIT_GETWIDTH(str, start, i)
				local next = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, state.cursor)
				if dx == IMSTB_TEXTEDIT_GETWIDTH_NEWLINE then
					break
				end
				x += dx
				if x > goal_x then
					break
				end
				i += next - state.cursor
				state.cursor = next
			end
			stb_textedit_clamp(str, state)
			if state.cursor == find.first_char + find.length then
				str.LastMoveDirectionLR = ImGuiDir.Left
			end
			state.has_preferred_x = 1
			state.preferred_x = goal_x
			if sel then
				state.select_end = state.cursor
			end
			find.first_char = find.first_char + find.length
			find.length = row.num_chars
		end
	elseif key == STB_TEXTEDIT_K_UP or key == STB_TEXTEDIT_K_UP + K_SHIFT or key == STB_TEXTEDIT_K_PGUP or key == STB_TEXTEDIT_K_PGUP + K_SHIFT then
		local sel = btest(key, K_SHIFT)
		local is_page = band(key, bnot(K_SHIFT)) == STB_TEXTEDIT_K_PGUP
		local row_count = if is_page then state.row_count_per_page else 1
		if not is_page and state.single_line ~= 0 then
			return stb_textedit_key(str, state, bor(STB_TEXTEDIT_K_LEFT, band(key, K_SHIFT)))
		end
		if sel then
			stb_textedit_prep_selection_at_cursor(state)
		elseif STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_move_to_first(state)
		end
		stb_textedit_clamp(str, state)
		local find = { x = 0, y = 0, height = 0, first_char = 0, length = 0, prev_first = 0 }
		stb_textedit_find_charpos(find, str, state.cursor, state.single_line)
		local row = { x0 = 0, x1 = 0, baseline_y_delta = 0, ymin = 0, ymax = 0, num_chars = 0 }
		for _ = 0, row_count - 1 do
			local goal_x = if state.has_preferred_x ~= 0 then state.preferred_x else find.x
			if find.prev_first == find.first_char then
				break
			end
			state.cursor = find.prev_first
			STB_TEXTEDIT_LAYOUTROW(row, str, state.cursor)
			local x = row.x0
			local i = 0
			while i < row.num_chars do
				local dx = STB_TEXTEDIT_GETWIDTH(str, find.prev_first, i)
				local next = IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, state.cursor)
				if dx == IMSTB_TEXTEDIT_GETWIDTH_NEWLINE then
					break
				end
				x += dx
				if x > goal_x then
					break
				end
				i += next - state.cursor
				state.cursor = next
			end
			stb_textedit_clamp(str, state)
			if state.cursor == find.first_char then
				str.LastMoveDirectionLR = ImGuiDir.Right
			elseif state.cursor == find.prev_first then
				str.LastMoveDirectionLR = ImGuiDir.Left
			end
			state.has_preferred_x = 1
			state.preferred_x = goal_x
			if sel then
				state.select_end = state.cursor
			end
			local prev_scan = if find.prev_first > 0 then find.prev_first - 1 else 0
			while prev_scan > 0 do
				local prev = IMSTB_TEXTEDIT_GETPREVCHARINDEX(str, prev_scan)
				if STB_TEXTEDIT_GETCHAR(str, prev) == STB_TEXTEDIT_NEWLINE then
					break
				end
				prev_scan = prev
			end
			find.first_char = find.prev_first
			find.prev_first = STB_TEXTEDIT_MOVELINESTART(str, state, prev_scan)
		end
	elseif key == STB_TEXTEDIT_K_DELETE or key == STB_TEXTEDIT_K_DELETE + K_SHIFT then
		if STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_delete_selection(str, state)
		else
			local n = str.TextLen
			if state.cursor < n then
				stb_textedit_delete(str, state, state.cursor, IMSTB_TEXTEDIT_GETNEXTCHARINDEX(str, state.cursor) - state.cursor)
			end
		end
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_BACKSPACE or key == STB_TEXTEDIT_K_BACKSPACE + K_SHIFT then
		if STB_TEXT_HAS_SELECTION(state) then
			stb_textedit_delete_selection(str, state)
		else
			stb_textedit_clamp(str, state)
			if state.cursor > 0 then
				local prev = IMSTB_TEXTEDIT_GETPREVCHARINDEX(str, state.cursor)
				stb_textedit_delete(str, state, prev, state.cursor - prev)
				state.cursor = prev
			end
		end
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_TEXTSTART then
		state.cursor = 0
		state.select_start = 0
		state.select_end = 0
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_TEXTEND then
		state.cursor = str.TextLen
		state.select_start = 0
		state.select_end = 0
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_TEXTSTART + K_SHIFT then
		stb_textedit_prep_selection_at_cursor(state)
		state.cursor = 0
		state.select_end = 0
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_TEXTEND + K_SHIFT then
		stb_textedit_prep_selection_at_cursor(state)
		state.cursor = str.TextLen
		state.select_end = state.cursor
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_LINESTART then
		stb_textedit_clamp(str, state)
		stb_textedit_move_to_first(state)
		state.cursor = STB_TEXTEDIT_MOVELINESTART(str, state, state.cursor)
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_LINEEND then
		stb_textedit_clamp(str, state)
		stb_textedit_move_to_last(str, state)
		state.cursor = STB_TEXTEDIT_MOVELINEEND(str, state, state.cursor)
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_LINESTART + K_SHIFT then
		stb_textedit_clamp(str, state)
		stb_textedit_prep_selection_at_cursor(state)
		state.cursor = STB_TEXTEDIT_MOVELINESTART(str, state, state.cursor)
		state.select_end = state.cursor
		state.has_preferred_x = 0
	elseif key == STB_TEXTEDIT_K_LINEEND + K_SHIFT then
		stb_textedit_clamp(str, state)
		stb_textedit_prep_selection_at_cursor(state)
		state.cursor = STB_TEXTEDIT_MOVELINEEND(str, state, state.cursor)
		state.select_end = state.cursor
		state.has_preferred_x = 0
	end
end

local function stb_textedit_clear_state(state, is_single_line)
	state.undostate.undo_point = 0
	state.undostate.undo_char_point = 0
	state.undostate.redo_point = IMSTB_TEXTEDIT_UNDOSTATECOUNT
	state.undostate.redo_char_point = IMSTB_TEXTEDIT_UNDOCHARCOUNT
	state.select_end = 0
	state.select_start = 0
	state.cursor = 0
	state.has_preferred_x = 0
	state.preferred_x = 0
	state.cursor_at_end_of_line = 0
	state.initialized = 1
	state.single_line = is_single_line
	state.insert_mode = 0
	state.row_count_per_page = 0
end

local function stb_textedit_initialize_state(state, is_single_line)
	stb_textedit_clear_state(state, is_single_line)
end

local function stb_textedit_paste(str, state, ctext, len)
	return stb_textedit_paste_internal(str, state, ctext, len)
end

local function stb_textedit_replace(str, state, text, text_len)
	stb_text_makeundo_replace(str, state, 0, str.TextLen, text_len)
	STB_TEXTEDIT_DELETECHARS(str, 0, str.TextLen)
	state.cursor = 0
	state.select_start = 0
	state.select_end = 0
	if text_len <= 0 then
		return
	end
	local text_len_inserted = STB_TEXTEDIT_INSERTCHARS(str, 0, text, text_len)
	if text_len_inserted > 0 then
		state.cursor = text_len
		state.select_start = text_len
		state.select_end = text_len
		state.has_preferred_x = 0
		return
	end
	assert(false)
end

local function InputTextStatePrepare(state, g)
	if state.Ctx == nil then
		state.Ctx = g
	end
	if not stb_states[state.Stb] then
		state.Stb = stb_new_state()
	end
	if type(state.TextA) ~= "string" then
		state.TextA = ""
	end
	if type(state.TextToRevertTo) ~= "string" then
		state.TextToRevertTo = ""
	end
	if type(state.CallbackTextBackup) ~= "string" then
		state.CallbackTextBackup = ""
	end
end

function ImGuiInputTextState:OnKeyPressed(key)
	stb_textedit_key(self, self.Stb, key)
	self.CursorFollow = true
	self:CursorAnimReset()
	local key_u = band(key, bnot(STB_TEXTEDIT_K_SHIFT))
	if key_u == STB_TEXTEDIT_K_LEFT or key_u == STB_TEXTEDIT_K_LINESTART or key_u == STB_TEXTEDIT_K_TEXTSTART or key_u == STB_TEXTEDIT_K_BACKSPACE or key_u == STB_TEXTEDIT_K_WORDLEFT then
		self.LastMoveDirectionLR = ImGuiDir.Left
	elseif key_u == STB_TEXTEDIT_K_RIGHT or key_u == STB_TEXTEDIT_K_LINEEND or key_u == STB_TEXTEDIT_K_TEXTEND or key_u == STB_TEXTEDIT_K_DELETE or key_u == STB_TEXTEDIT_K_WORDRIGHT then
		self.LastMoveDirectionLR = ImGuiDir.Right
	end
end

function ImGuiInputTextState:OnCharPressed(c)
	local utf8_text = utf8.char(c)
	stb_textedit_text(self, self.Stb, utf8_text, #utf8_text)
	self.CursorFollow = true
	self:CursorAnimReset()
end

function ImGuiInputTextState:CursorAnimReset()
	self.CursorAnim = -0.30
end

function ImGuiInputTextState:CursorClamp()
	local stb = self.Stb
	stb.cursor = ImMin(stb.cursor, self.TextLen)
	stb.select_start = ImMin(stb.select_start, self.TextLen)
	stb.select_end = ImMin(stb.select_end, self.TextLen)
end

function ImGuiInputTextState:HasSelection()
	return self.Stb.select_start ~= self.Stb.select_end
end

function ImGuiInputTextState:ClearSelection()
	self.Stb.select_start = self.Stb.cursor
	self.Stb.select_end = self.Stb.cursor
end

function ImGuiInputTextState:GetCursorPos()
	return self.Stb.cursor
end

function ImGuiInputTextState:GetSelectionStart()
	return self.Stb.select_start
end

function ImGuiInputTextState:GetSelectionEnd()
	return self.Stb.select_end
end

function ImGuiInputTextState:SetSelection(start, end_)
	self.Stb.select_start = start
	self.Stb.cursor = end_
	self.Stb.select_end = end_
end

function ImGuiInputTextState:GetPreferredOffsetX()
	return if self.Stb.has_preferred_x ~= 0 then self.Stb.preferred_x else -1
end

function ImGuiInputTextState:SelectAll()
	self.Stb.select_start = 0
	self.Stb.cursor = self.TextLen
	self.Stb.select_end = self.TextLen
	self.Stb.has_preferred_x = 0
end

function ImGuiInputTextState:ReloadUserBufAndSelectAll()
	self.WantReloadUserBuf = true
	self.ReloadSelectionStart = 0
	self.ReloadSelectionEnd = INT_MAX
end

function ImGuiInputTextState:ReloadUserBufAndKeepSelection()
	self.WantReloadUserBuf = true
	self.ReloadSelectionStart = self.Stb.select_start
	self.ReloadSelectionEnd = self.Stb.select_end
end

function ImGuiInputTextState:ReloadUserBufAndMoveToEnd()
	self.WantReloadUserBuf = true
	self.ReloadSelectionStart = INT_MAX
	self.ReloadSelectionEnd = INT_MAX
end

function ImGuiInputTextState:ClearText()
	InputTextStatePrepare(self, self.Ctx)
	self.TextLen = 0
	self.TextA = ""
	if self.TextSrc ~= nil then
		self.TextSrc = self.TextA
	end
	self:CursorClamp()
end

function ImGuiInputTextCallbackData:DeleteChars(pos, bytes_count)
	assert(pos + bytes_count <= self.BufTextLen)
	self.Buf = ssub(self.Buf, 1, pos) .. ssub(self.Buf, pos + bytes_count + 1)
	if self.CursorPos >= pos + bytes_count then
		self.CursorPos -= bytes_count
	elseif self.CursorPos >= pos then
		self.CursorPos = pos
	end
	self.SelectionStart = self.CursorPos
	self.SelectionEnd = self.CursorPos
	self.BufDirty = true
	self.BufTextLen -= bytes_count
end

function ImGuiInputTextCallbackData:InsertChars(pos, new_text, new_text_end)
	if new_text_end == nil then
		new_text_end = #new_text + 1
	end
	if new_text_end <= 1 then
		return
	end
	local g = self.Ctx
	local obj = g.InputTextState
	assert(obj.ID ~= 0 and g.ActiveId == obj.ID)
	local new_text_len = new_text_end - 1
	if self.BufTextLen + new_text_len + 1 > self.BufSize then
		self.BufSize = self.BufTextLen + new_text_len + 1
		obj.BufCapacity = self.BufSize
	end
	self.Buf = ssub(self.Buf, 1, pos) .. ssub(new_text, 1, new_text_len) .. ssub(self.Buf, pos + 1)
	self.BufDirty = true
	self.BufTextLen += new_text_len
	if self.CursorPos >= pos then
		self.CursorPos += new_text_len
	end
	self.CursorPos = ImClamp(self.CursorPos, 0, self.BufTextLen)
	self.SelectionStart = self.CursorPos
	self.SelectionEnd = self.CursorPos
end

function ImGui.PushPasswordFont()
	local g = ImGui.GImGui
	g.InputTextPasswordFontBackupFlags = g.Font.Flags
end

function ImGui.PopPasswordFont()
	local g = ImGui.GImGui
	g.Font.Flags = g.InputTextPasswordFontBackupFlags
end

local function InputTextFilterCharacter(ctx, state, c, callback, user_data, input_source_is_clipboard)
	assert(state ~= nil)
	local flags = state.Flags
	local apply_named_filters = true
	if c < 0x20 then
		local pass = false
		pass = pass or (c == 10 and btest(flags, ImGuiInputTextFlags.Multiline))
		if c == 10 and input_source_is_clipboard and not btest(flags, ImGuiInputTextFlags.Multiline) then
			c = 32
			pass = true
		end
		pass = pass or (c == 10 and btest(flags, ImGuiInputTextFlags.Multiline))
		pass = pass or (c == 9 and btest(flags, ImGuiInputTextFlags.AllowTabInput))
		if not pass then
			return false, c
		end
		apply_named_filters = false
	end

	if not input_source_is_clipboard then
		if c == 127 then
			return false, c
		end
		if c >= 0xE000 and c <= 0xF8FF then
			return false, c
		end
	end

	if c > IM_UNICODE_CODEPOINT_MAX then
		return false, c
	end

	if apply_named_filters and btest(flags, bor(ImGuiInputTextFlags.CharsDecimal, ImGuiInputTextFlags.CharsHexadecimal, ImGuiInputTextFlags.CharsUppercase, ImGuiInputTextFlags.CharsNoBlank, ImGuiInputTextFlags.CharsScientific, ImGuiInputTextFlags.LocalizeDecimalPoint)) then
		local g = ctx
		local c_decimal_point = g.PlatformIO.Platform_LocaleDecimalPoint
		if btest(flags, bor(ImGuiInputTextFlags.CharsDecimal, ImGuiInputTextFlags.CharsScientific, ImGuiInputTextFlags.LocalizeDecimalPoint)) then
			if c == sbyte(".") or c == sbyte(",") then
				c = c_decimal_point
			end
		end
		if btest(flags, bor(ImGuiInputTextFlags.CharsDecimal, ImGuiInputTextFlags.CharsScientific, ImGuiInputTextFlags.CharsHexadecimal)) then
			if c >= 0xFF01 and c <= 0xFF5E then
				c = c - 0xFF01 + 0x21
			end
		end
		local is_digit = c >= sbyte("0") and c <= sbyte("9")
		if btest(flags, ImGuiInputTextFlags.CharsDecimal) then
			if not is_digit and c ~= c_decimal_point and c ~= sbyte("-") and c ~= sbyte("+") and c ~= sbyte("*") and c ~= sbyte("/") then
				return false, c
			end
		end
		if btest(flags, ImGuiInputTextFlags.CharsScientific) then
			if not is_digit and c ~= c_decimal_point and c ~= sbyte("-") and c ~= sbyte("+") and c ~= sbyte("*") and c ~= sbyte("/") and c ~= sbyte("e") and c ~= sbyte("E") then
				return false, c
			end
		end
		if btest(flags, ImGuiInputTextFlags.CharsHexadecimal) then
			if not is_digit and not (c >= sbyte("a") and c <= sbyte("f")) and not (c >= sbyte("A") and c <= sbyte("F")) then
				return false, c
			end
		end
		if btest(flags, ImGuiInputTextFlags.CharsUppercase) then
			if c >= sbyte("a") and c <= sbyte("z") then
				c += sbyte("A") - sbyte("a")
			end
		end
		if btest(flags, ImGuiInputTextFlags.CharsNoBlank) then
			if ImCharIsBlankW(c) then
				return false, c
			end
		end
	end

	if btest(flags, ImGuiInputTextFlags.CallbackCharFilter) then
		local g = ImGui.GImGui
		local callback_data = ImGuiInputTextCallbackData.new()
		callback_data.Ctx = g
		callback_data.ID = state.ID
		callback_data.Flags = flags
		callback_data.EventFlag = ImGuiInputTextFlags.CallbackCharFilter
		callback_data.EventChar = c
		callback_data.EventActivated = (g.ActiveId == state.ID and g.ActiveIdIsJustActivated)
		callback_data.CursorPos = state.Stb.cursor
		callback_data.SelectionStart = state.Stb.select_start
		callback_data.SelectionEnd = state.Stb.select_end
		callback_data.UserData = user_data
		local ret = callback(callback_data)
		if ret ~= nil and ret ~= 0 and ret ~= false then
			return false, c
		end
		c = callback_data.EventChar
		if c == 0 or c == nil then
			return false, 0
		end
	end

	return true, c
end

local function InputTextReconcileUndoState(state, old_buf, old_length, new_buf, new_length)
	local shorter_length = ImMin(old_length, new_length)
	local first_diff = 0
	while first_diff < shorter_length do
		if sbyte(old_buf, first_diff + 1) ~= sbyte(new_buf, first_diff + 1) then
			break
		end
		first_diff += 1
	end
	if first_diff == old_length and first_diff == new_length then
		return
	end
	local old_last_diff = old_length - 1
	local new_last_diff = new_length - 1
	while old_last_diff >= first_diff and new_last_diff >= first_diff do
		if sbyte(old_buf, old_last_diff + 1) ~= sbyte(new_buf, new_last_diff + 1) then
			break
		end
		old_last_diff -= 1
		new_last_diff -= 1
	end
	local insert_len = new_last_diff - first_diff + 1
	local delete_len = old_last_diff - first_diff + 1
	if insert_len > 0 or delete_len > 0 then
		local undostate = state.Stb.undostate
		local p = stb_text_createundo(undostate, first_diff, delete_len, insert_len)
		if p then
			for i = 0, delete_len - 1 do
				undostate.undo_char[p + i + 1] = sbyte(old_buf, first_diff + i + 1)
			end
		end
	end
end

function ImGui.InputTextDeactivateHook(id)
	local g = ImGui.GImGui
	local state = g.InputTextState
	if id == 0 or state.ID ~= id or g.ActiveId ~= id then
		return
	end
	if not state.EditedBefore then
		return
	end
	state.EditedBefore = false
	g.InputTextDeactivatedState.ID = state.ID
	g.InputTextDeactivatedState.ElapseFrame = g.FrameCount + 1
	if btest(state.Flags, ImGuiInputTextFlags.ReadOnly) then
		g.InputTextDeactivatedState.TextA = ""
	else
		assert(state.TextA ~= nil)
		g.InputTextDeactivatedState.TextA = ssub(state.TextA, 1, state.TextLen)
	end
end

local function ImLowerBound(offsets, in_begin, in_end, v)
	local in_p = in_begin
	local count = in_end - in_p
	while count > 0 do
		local count2 = count // 2
		local mid = in_p + count2
		if offsets[mid + 1] < v then
			in_p = mid + 1
			count -= count2 + 1
		else
			count = count2
		end
	end
	return in_p
end

local function LineIndexGetLineBegin(line_index, n)
	local offsets = line_index.Offsets
	return if offsets.Size ~= 0 then offsets[n + 1] else 0
end

local function LineIndexGetLineEnd(line_index, n)
	local offsets = line_index.Offsets
	return if n + 1 < offsets.Size then offsets[n + 2] - 1 else line_index.EndOffset
end

local function InputTextLineIndexBuild(flags, line_index, buf, buf_end, wrap_width, max_output_buffer_size)
	local g = ImGui.GImGui
	local offsets = line_index.Offsets
	local size = 0
	local s
	local trailing_line_already_counted = false
	if btest(flags, ImGuiInputTextFlags.WordWrap) then
		s = 0
		while s < buf_end do
			if size <= max_output_buffer_size then
				offsets:push_back(s)
			end
			size += 1
			s = WrapPositionEx(g, buf, s, buf_end, wrap_width, ImDrawTextFlags.WrapKeepBlanks)
			if sbyte(buf, s + 1) == 10 and s < buf_end then
				s += 1
			end
		end
	elseif buf_end ~= nil then
		s = 0
		while s < buf_end do
			if size <= max_output_buffer_size then
				offsets:push_back(s)
			end
			size += 1
			local e = sfind(buf, "\n", s + 1, true)
			s = if e ~= nil and e <= buf_end then e else buf_end
		end
	else
		s = 0
		while true do
			if size <= max_output_buffer_size then
				offsets:push_back(s)
			end
			size += 1
			local e = sfind(buf, "\n", s + 1, true)
			if e ~= nil then
				s = e
				continue
			end
			s = #buf
			trailing_line_already_counted = true
			break
		end
	end
	buf_end = s
	if size == 0 then
		offsets:push_back(0)
		size += 1
	end
	if buf_end > 0 and sbyte(buf, buf_end) == 10 and not trailing_line_already_counted then
		if size <= max_output_buffer_size then
			offsets:push_back(buf_end)
		end
		size += 1
	end
	return size, s
end

local function InputTextLineIndexGetPosOffset(g, state, line_index, buf, buf_end, cursor_n)
	local offsets = line_index.Offsets
	local it_begin, it_end = 0, offsets.Size
	local it = ImLowerBound(offsets, it_begin, it_end, cursor_n)
	if it > it_begin then
		local prev_c = sbyte(buf, cursor_n) or 0
		if it == it_end or offsets[it + 1] ~= cursor_n or (state ~= nil and state.WrapWidth > 0.0 and state.LastMoveDirectionLR == ImGuiDir.Right and prev_c ~= 10 and prev_c ~= 0) then
			it -= 1
		end
	end
	local line_no = if it == it_begin then 0 else it
	local line_start = LineIndexGetLineBegin(line_index, line_no)
	local x = InputTextCalcTextSize(g, buf, line_start, cursor_n, buf_end, ImDrawTextFlags.WrapKeepBlanks).x
	return ImVec2(x, (line_no + 1) * g.FontSize)
end

function ImGui.InputText(label, text, flags, callback, user_data)
	if flags == nil then
		flags = 0
	end
	assert(not btest(flags, ImGuiInputTextFlags.Multiline))
	return ImGui.InputTextEx(label, nil, text, ImVec2(0, 0), flags, callback, user_data)
end

function ImGui.InputTextMultiline(label, text, size, flags, callback, user_data)
	if size == nil then
		size = ImVec2(0, 0)
	end
	if flags == nil then
		flags = 0
	end
	return ImGui.InputTextEx(label, nil, text, size, bor(flags, ImGuiInputTextFlags.Multiline), callback, user_data)
end

function ImGui.InputTextWithHint(label, hint, text, flags, callback, user_data)
	if flags == nil then
		flags = 0
	end
	assert(not btest(flags, ImGuiInputTextFlags.Multiline))
	return ImGui.InputTextEx(label, hint, text, ImVec2(0, 0), flags, callback, user_data)
end

local always_owned_keys = { ImGuiKey.LeftArrow, ImGuiKey.RightArrow, ImGuiKey.Delete, ImGuiKey.Backspace, ImGuiKey.Home, ImGuiKey.End }

function ImGui.InputTextEx(label, hint, buf, size_arg, flags, callback, callback_user_data)
	if flags == nil then
		flags = 0
	end
	if size_arg == nil then
		size_arg = ImVec2(0, 0)
	end
	local window = ImGui.GetCurrentWindow()
	if window.SkipItems then
		return false, buf
	end

	assert(buf ~= nil)
	assert(not (btest(flags, ImGuiInputTextFlags.CallbackHistory) and btest(flags, ImGuiInputTextFlags.Multiline)))
	assert(not (btest(flags, ImGuiInputTextFlags.CallbackCompletion) and btest(flags, ImGuiInputTextFlags.AllowTabInput)))
	assert(not (btest(flags, ImGuiInputTextFlags.ElideLeft) and btest(flags, ImGuiInputTextFlags.Multiline)))
	assert(not btest(flags, ImGuiInputTextFlags.WordWrap) or not btest(flags, ImGuiInputTextFlags.Password))
	assert(not btest(flags, ImGuiInputTextFlags.WordWrap) or btest(flags, ImGuiInputTextFlags.Multiline))

	local g = ImGui.GImGui
	local io = g.IO
	local style = g.Style

	local RENDER_SELECTION_WHEN_INACTIVE = false
	local is_multiline = btest(flags, ImGuiInputTextFlags.Multiline)

	if is_multiline then
		ImGui.BeginGroup()
	end
	local id = window:GetID(label)
	local label_end = ImGui.FindRenderedTextEnd(label)
	local label_size = ImGui.CalcTextSize(label, label_end, false)
	local frame_size = ImGui.CalcItemSize(size_arg, ImGui.CalcItemWidth(), (if is_multiline then g.FontSize * 8.0 else label_size.y) + style.FramePadding.y * 2.0)
	local total_size = ImVec2(frame_size.x + (if label_size.x > 0.0 then style.ItemInnerSpacing.x + label_size.x else 0.0), frame_size.y)

	local frame_bb = ImRect.new(window.DC.CursorPos, window.DC.CursorPos + frame_size)
	local total_bb = ImRect.new(frame_bb.Min, frame_bb.Min + total_size)

	local draw_window = window
	local inner_size = frame_size
	local item_data_backup = nil
	if is_multiline then
		local backup_pos = window.DC.CursorPos
		ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
		local no_clip = (g.InputTextDeactivatedState.ID == id) or (g.ActiveId == id) or (id == g.NavActivateId)
		if not ImGui.ItemAdd(total_bb, id, frame_bb, ImGuiItemFlags.Inputable) and not no_clip then
			ImGui.EndGroup()
			return false, buf
		end
		item_data_backup = g.LastItemData:Copy()
		window.DC.CursorPos = backup_pos

		if g.NavActivateId == id and btest(g.NavActivateFlags, ImGuiActivateFlags.FromTabbing) and not btest(g.NavActivateFlags, ImGuiActivateFlags.FromFocusApi) and btest(flags, ImGuiInputTextFlags.AllowTabInput) then
			g.NavActivateId = 0
		end

		local backup_activate_id = g.NavActivateId
		if g.ActiveId == id then
			g.NavActivateId = 0
		end

		ImGui.PushStyleColor(ImGuiCol.ChildBg, style.Colors[ImGuiCol.FrameBg + 1])
		ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, style.FrameRounding)
		ImGui.PushStyleVar(ImGuiStyleVar.ChildBorderSize, style.FrameBorderSize)
		ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0, 0))
		local child_visible = ImGui.BeginChildEx(label, id, frame_bb:GetSize(), ImGuiChildFlags.Borders, ImGuiWindowFlags.NoMove)
		g.NavActivateId = backup_activate_id
		ImGui.PopStyleVar(3)
		ImGui.PopStyleColor()
		if not child_visible and not no_clip then
			ImGui.EndChild()
			ImGui.EndGroup()
			return false, buf
		end
		draw_window = g.CurrentWindow
		draw_window.DC.NavLayersActiveMaskNext = bor(draw_window.DC.NavLayersActiveMaskNext, lshift(1, draw_window.DC.NavLayerCurrent))
		draw_window.DC.CursorPos += style.FramePadding
		inner_size = ImVec2(inner_size.x - draw_window.ScrollbarSizes.x, inner_size.y)

		g.LastItemData.ID = id
		g.LastItemData.ItemFlags = item_data_backup.ItemFlags
		g.LastItemData.StatusFlags = item_data_backup.StatusFlags
	else
		ImGui.ItemSize(total_bb:GetSize(), style.FramePadding.y)
		if not btest(flags, ImGuiInputTextFlags.TempInput) then
			if not ImGui.ItemAdd(total_bb, id, frame_bb, ImGuiItemFlags.Inputable) then
				return false, buf
			end
		end
	end

	local hovered = ImGui.ItemHoverable(frame_bb, id, bor(g.LastItemData.ItemFlags, ImGuiItemFlags.NoNavDisableMouseHover))
	if hovered then
		ImGui.SetMouseCursor(ImGuiMouseCursor.TextInput)
	end
	if hovered and g.NavHighlightItemUnderNav then
		hovered = false
	end

	local state = if id ~= 0 and g.InputTextState.ID == id then g.InputTextState else nil

	if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) then
		flags = bor(flags, ImGuiInputTextFlags.ReadOnly)
	end
	local is_readonly = btest(flags, ImGuiInputTextFlags.ReadOnly)
	local is_password = btest(flags, ImGuiInputTextFlags.Password)
	local is_undoable = not btest(flags, ImGuiInputTextFlags.NoUndoRedo)
	local is_resizable = btest(flags, ImGuiInputTextFlags.CallbackResize)
	local is_mixed = btest(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue)
	if is_resizable then
		assert(callback ~= nil)
	end

	local is_wordwrap = btest(flags, ImGuiInputTextFlags.WordWrap)
	local wrap_width = 0.0
	if is_wordwrap then
		wrap_width = ImMax(1.0, ImGui.GetContentRegionAvail().x + (if draw_window.ScrollbarY then 0.0 else -g.Style.ScrollbarSize))
	end

	local user_clicked = hovered and io.MouseClicked[1]
	local input_requested_by_nav = (g.ActiveId ~= id) and (g.NavActivateId == id)
	local input_requested_by_reactivate = (g.InputTextReactivateId == id)
	local input_requested_by_user = user_clicked or (g.ActiveId == 0 and btest(flags, ImGuiInputTextFlags.TempInput) and g.InputTextDeactivatedState.ID ~= id)
	local scrollbar_id = if is_multiline and state ~= nil then ImGui.GetWindowScrollbarID(draw_window, ImGuiAxis.Y) else 0
	local user_scroll_finish = is_multiline and state ~= nil and g.ActiveId == 0 and g.ActiveIdPreviousFrame == scrollbar_id
	local user_scroll_active = is_multiline and state ~= nil and g.ActiveId == scrollbar_id
	local clear_active_id = false
	local select_all = false

	local scroll_y = if is_multiline then draw_window.Scroll.y else FLT_MAX

	local init_reload_from_user_buf = state ~= nil and state.WantReloadUserBuf == true
	local init_changed_specs_multiline = state ~= nil and ((state.Stb.single_line ~= 0) ~= not is_multiline)
	local init_changed_specs_readonly = state ~= nil and btest(bit32.bxor(state.Flags, flags), ImGuiInputTextFlags.ReadOnly)
	local init_make_active = input_requested_by_user or input_requested_by_nav or input_requested_by_reactivate or user_scroll_finish
	if init_reload_from_user_buf then
		local new_len = #buf
		state.WantReloadUserBuf = false
		InputTextReconcileUndoState(state, state.TextA, state.TextLen, buf, new_len)
		state.TextA = buf
		state.TextLen = new_len
		state.Stb.select_start = state.ReloadSelectionStart
		state.Stb.cursor = state.ReloadSelectionEnd
		state.Stb.select_end = state.ReloadSelectionEnd
	elseif (init_make_active and g.ActiveId ~= id) or init_changed_specs_multiline or init_changed_specs_readonly then
		state = g.InputTextState
		InputTextStatePrepare(state, g)
		state:CursorAnimReset()

		if state.ID ~= id and state.ID == g.ActiveId and (init_make_active and g.ActiveId ~= id) then
			ImGui.InputTextDeactivateHook(state.ID)
		end

		local buf_len = #buf
		if not user_scroll_finish then
			state.TextToRevertTo = buf
		end

		local recycle_state = (state.ID == id and not init_changed_specs_multiline)
		if recycle_state and not init_changed_specs_readonly and (state.TextLen ~= buf_len or ssub(state.TextA, 1, buf_len) ~= buf) then
			recycle_state = false
		end

		state.ID = id
		state.TextLen = buf_len
		state.EditedBefore = false
		if not is_readonly then
			state.TextA = buf
		end

		state.Scroll = ImVec2(0.0, 0.0)
		if btest(flags, ImGuiInputTextFlags.ElideLeft) then
			state.Scroll = ImVec2(state.Scroll.x + ImMax(0.0, ImGui.CalcTextSize(buf).x - frame_size.x + style.FramePadding.x * 2.0), state.Scroll.y)
		end

		if not recycle_state then
			stb_textedit_initialize_state(state.Stb, if is_multiline then 0 else 1)
		end

		if not is_multiline then
			if btest(flags, ImGuiInputTextFlags.AutoSelectAll) or is_mixed then
				select_all = true
			end
			if input_requested_by_nav and (not recycle_state or not btest(g.NavActivateFlags, ImGuiActivateFlags.TryToPreserveState)) then
				select_all = true
			end
			if user_clicked and io.KeyCtrl then
				select_all = true
			end
		end

		if btest(flags, ImGuiInputTextFlags.AlwaysOverwrite) then
			state.Stb.insert_mode = 1
		end
	end

	local is_osx = io.ConfigMacOSXBehaviors
	if init_make_active and g.ActiveId ~= id then
		assert(state ~= nil and state.ID == id)
		ImGui.SetActiveID(id, window)
		ImGui.SetFocusID(id, window)
		ImGui.FocusWindow(window)
		if input_requested_by_nav then
			ImGui.SetNavCursorVisibleAfterMove()
		end
	end
	if g.ActiveId == id then
		for _, key in always_owned_keys do
			ImGui.SetKeyOwner(key, id)
		end
		if user_clicked then
			ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
		end
		g.ActiveIdUsingNavDirMask = bor(g.ActiveIdUsingNavDirMask, lshift(1, ImGuiDir.Left), lshift(1, ImGuiDir.Right))
		if is_multiline or btest(flags, ImGuiInputTextFlags.CallbackHistory) then
			g.ActiveIdUsingNavDirMask = bor(g.ActiveIdUsingNavDirMask, lshift(1, ImGuiDir.Up), lshift(1, ImGuiDir.Down))
			ImGui.SetKeyOwner(ImGuiKey.UpArrow, id)
			ImGui.SetKeyOwner(ImGuiKey.DownArrow, id)
		end
		if is_multiline then
			ImGui.SetKeyOwner(ImGuiKey.PageUp, id)
			ImGui.SetKeyOwner(ImGuiKey.PageDown, id)
		end
		if is_osx then
			ImGui.SetKeyOwner(ImGuiMod.Alt, id)
		end

		if is_multiline and state ~= nil then
			state.Scroll = ImVec2(state.Scroll.x, draw_window.Scroll.y)
		end

		if is_readonly and state ~= nil then
			state.TextLen = #buf
			state.TextA = buf
		end
		if state ~= nil then
			state:CursorClamp()
		end
	end
	if state ~= nil then
		state.TextSrc = if is_readonly then buf else state.TextA
	end

	if g.ActiveId == id and state == nil then
		ImGui.ClearActiveID()
	end

	if g.ActiveId == id and io.MouseClicked[1] and not init_make_active then
		clear_active_id = true
	end

	local render_cursor = (g.ActiveId == id) or (state ~= nil and user_scroll_active)
	local render_selection = state ~= nil and (state:HasSelection() or select_all) and (RENDER_SELECTION_WHEN_INACTIVE or render_cursor)
	local value_changed = false
	local validated = false

	local buf_display_from_state = (render_cursor or render_selection or g.ActiveId == id) and not is_readonly and state ~= nil
	local is_displaying_hint = (hint ~= nil and #(if buf_display_from_state then state.TextSrc else buf) == 0) and not is_mixed

	if is_password and not is_displaying_hint then
		ImGui.PushPasswordFont()
	end

	if state ~= nil and state.ID == id then
		state.Flags = flags
		state.EditedThisFrame = false
		state.ValidatedThisFrame = false
		if is_wordwrap and state.WrapWidth ~= wrap_width then
			state.CursorCenterY = true
			state.WrapWidth = wrap_width
			render_cursor = true
		end
	end

	if g.ActiveId == id then
		assert(state ~= nil)
		state.BufCapacity = #buf + 1
		state.WrapWidth = wrap_width

		g.ActiveIdAllowOverlap = not io.MouseDown[1]

		local mouse_x = (io.MousePos.x - frame_bb.Min.x - style.FramePadding.x) + state.Scroll.x
		local mouse_y = if is_multiline then (io.MousePos.y - draw_window.DC.CursorPos.y) else (g.FontSize * 0.5)

		local stb = state.Stb
		if select_all then
			state:SelectAll()
			state.SelectedAllMouseLock = true
		elseif hovered and io.MouseClickedCount[1] >= 2 and not io.KeyShift then
			stb_textedit_click(state, stb, mouse_x, mouse_y)
			local multiclick_count = io.MouseClickedCount[1] - 2
			if (multiclick_count % 2) == 0 then
				local is_bol = (stb.cursor == 0) or STB_TEXTEDIT_GETCHAR(state, stb.cursor - 1) == 10
				if STB_TEXT_HAS_SELECTION(stb) or not is_bol then
					state:OnKeyPressed(STB_TEXTEDIT_K_WORDLEFT)
				end
				if not STB_TEXT_HAS_SELECTION(stb) then
					stb_textedit_prep_selection_at_cursor(stb)
				end
				stb.cursor = STB_TEXTEDIT_MOVEWORDRIGHT_MAC(state, stb.cursor)
				stb.select_end = stb.cursor
				stb_textedit_clamp(state, stb)
			else
				local is_eol = STB_TEXTEDIT_GETCHAR(state, stb.cursor) == 10
				state.WrapWidth = 0.0
				state:OnKeyPressed(STB_TEXTEDIT_K_LINESTART)
				state:OnKeyPressed(bor(STB_TEXTEDIT_K_LINEEND, STB_TEXTEDIT_K_SHIFT))
				state:OnKeyPressed(bor(STB_TEXTEDIT_K_RIGHT, STB_TEXTEDIT_K_SHIFT))
				state.WrapWidth = wrap_width
				if not is_eol and is_multiline then
					stb.select_start, stb.select_end = stb.select_end, stb.select_start
					stb.cursor = stb.select_end
				end
				state.CursorFollow = false
			end
			state:CursorAnimReset()
		elseif io.MouseClicked[1] and not state.SelectedAllMouseLock then
			if hovered then
				if io.KeyShift then
					stb_textedit_drag(state, stb, mouse_x, mouse_y)
				else
					stb_textedit_click(state, stb, mouse_x, mouse_y)
				end
				state:CursorAnimReset()
			end
		elseif io.MouseDown[1] and not state.SelectedAllMouseLock and (io.MouseDelta.x ~= 0.0 or io.MouseDelta.y ~= 0.0) then
			stb_textedit_drag(state, stb, mouse_x, mouse_y)
			state:CursorAnimReset()
			state.CursorFollow = true
		end
		if state.SelectedAllMouseLock and not io.MouseDown[1] then
			state.SelectedAllMouseLock = false
		end

		if btest(flags, ImGuiInputTextFlags.AllowTabInput) and not is_readonly then
			if ImGui.Shortcut(ImGuiKey.Tab, ImGuiInputFlags.Repeat, id) then
				local ok, c = InputTextFilterCharacter(g, state, 9, callback, callback_user_data, false)
				if ok then
					state:OnCharPressed(c)
				end
			end
		end

		local ignore_char_inputs = (io.KeyCtrl and not io.KeyAlt) or (is_osx and io.KeyCtrl)
		if io.InputQueueCharacters.Size > 0 then
			if not ignore_char_inputs and not is_readonly and not input_requested_by_nav then
				for n = 0, io.InputQueueCharacters.Size - 1 do
					local c = io.InputQueueCharacters[n + 1]
					if c == 9 then
						continue
					end
					local ok
					ok, c = InputTextFilterCharacter(g, state, c, callback, callback_user_data, false)
					if ok then
						state:OnCharPressed(c)
					end
				end
			end
			io.InputQueueCharacters:resize(0)
		end
	end

	local revert_edit = false
	if g.ActiveId == id and not g.ActiveIdIsJustActivated and not clear_active_id then
		assert(state ~= nil)

		local row_count_per_page = ImMax(Base.ImTruncToInt((inner_size.y - style.FramePadding.y) / g.FontSize), 1)
		state.Stb.row_count_per_page = row_count_per_page

		local k_mask = if io.KeyShift then STB_TEXTEDIT_K_SHIFT else 0
		local is_wordmove_key_down = if is_osx then io.KeyAlt else io.KeyCtrl
		local is_startend_key_down = is_osx and io.KeyCtrl and not io.KeySuper and not io.KeyAlt

		local f_repeat = ImGuiInputFlags.Repeat
		local Ctrl, Shift = ImGuiMod.Ctrl, ImGuiMod.Shift
		local is_cut = (ImGui.Shortcut(bor(Ctrl, ImGuiKey.X), f_repeat, id) or ImGui.Shortcut(bor(Shift, ImGuiKey.Delete), f_repeat, id)) and not is_readonly and not is_password and (not is_multiline or state:HasSelection())
		local is_copy = (ImGui.Shortcut(bor(Ctrl, ImGuiKey.C), 0, id) or ImGui.Shortcut(bor(Ctrl, ImGuiKey.Insert), 0, id)) and not is_password and (not is_multiline or state:HasSelection())
		local is_paste = (ImGui.Shortcut(bor(Ctrl, ImGuiKey.V), f_repeat, id) or ImGui.Shortcut(bor(Shift, ImGuiKey.Insert), f_repeat, id)) and not is_readonly
		local is_undo = ImGui.Shortcut(bor(Ctrl, ImGuiKey.Z), f_repeat, id) and not is_readonly and is_undoable
		local is_redo = (ImGui.Shortcut(bor(Ctrl, ImGuiKey.Y), f_repeat, id) or ImGui.Shortcut(bor(Ctrl, Shift, ImGuiKey.Z), f_repeat, id)) and not is_readonly and is_undoable
		local is_select_all = ImGui.Shortcut(bor(Ctrl, ImGuiKey.A), 0, id)

		local nav_gamepad_active = btest(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) and btest(io.BackendFlags, ImGuiBackendFlags.HasGamepad)
		local key_nav_activate = if g.IO.ConfigNavSwapGamepadButtons then ImGuiKey.GamepadFaceRight else ImGuiKey.GamepadFaceDown
		local key_nav_cancel = if g.IO.ConfigNavSwapGamepadButtons then ImGuiKey.GamepadFaceDown else ImGuiKey.GamepadFaceRight
		local is_enter = ImGui.Shortcut(ImGuiKey.Enter, f_repeat, id) or ImGui.Shortcut(ImGuiKey.KeypadEnter, f_repeat, id)
		local is_ctrl_enter = ImGui.Shortcut(bor(Ctrl, ImGuiKey.Enter), f_repeat, id) or ImGui.Shortcut(bor(Ctrl, ImGuiKey.KeypadEnter), f_repeat, id)
		local is_shift_enter = ImGui.Shortcut(bor(Shift, ImGuiKey.Enter), f_repeat, id) or ImGui.Shortcut(bor(Shift, ImGuiKey.KeypadEnter), f_repeat, id)
		local is_gamepad_validate = nav_gamepad_active and ImGui.IsKeyPressed(key_nav_activate, false)
		local is_cancel = ImGui.Shortcut(ImGuiKey.Escape, f_repeat, id) or (nav_gamepad_active and ImGui.Shortcut(key_nav_cancel, f_repeat, id))

		if ImGui.IsKeyPressed(ImGuiKey.LeftArrow) then
			state:OnKeyPressed(bor(if is_startend_key_down then STB_TEXTEDIT_K_LINESTART elseif is_wordmove_key_down then STB_TEXTEDIT_K_WORDLEFT else STB_TEXTEDIT_K_LEFT, k_mask))
		elseif ImGui.IsKeyPressed(ImGuiKey.RightArrow) then
			state:OnKeyPressed(bor(if is_startend_key_down then STB_TEXTEDIT_K_LINEEND elseif is_wordmove_key_down then STB_TEXTEDIT_K_WORDRIGHT else STB_TEXTEDIT_K_RIGHT, k_mask))
		elseif ImGui.IsKeyPressed(ImGuiKey.UpArrow) and is_multiline then
			if io.KeyCtrl then
				ImGui.SetScrollY(draw_window, ImMax(draw_window.Scroll.y - g.FontSize, 0.0))
			else
				state:OnKeyPressed(bor(if is_startend_key_down then STB_TEXTEDIT_K_TEXTSTART else STB_TEXTEDIT_K_UP, k_mask))
			end
		elseif ImGui.IsKeyPressed(ImGuiKey.DownArrow) and is_multiline then
			if io.KeyCtrl then
				ImGui.SetScrollY(draw_window, ImMin(draw_window.Scroll.y + g.FontSize, ImGui.GetScrollMaxY()))
			else
				state:OnKeyPressed(bor(if is_startend_key_down then STB_TEXTEDIT_K_TEXTEND else STB_TEXTEDIT_K_DOWN, k_mask))
			end
		elseif ImGui.IsKeyPressed(ImGuiKey.PageUp) and is_multiline then
			state:OnKeyPressed(bor(STB_TEXTEDIT_K_PGUP, k_mask))
			scroll_y -= row_count_per_page * g.FontSize
		elseif ImGui.IsKeyPressed(ImGuiKey.PageDown) and is_multiline then
			state:OnKeyPressed(bor(STB_TEXTEDIT_K_PGDOWN, k_mask))
			scroll_y += row_count_per_page * g.FontSize
		elseif ImGui.IsKeyPressed(ImGuiKey.Home) then
			state:OnKeyPressed(if io.KeyCtrl then bor(STB_TEXTEDIT_K_TEXTSTART, k_mask) else bor(STB_TEXTEDIT_K_LINESTART, k_mask))
		elseif ImGui.IsKeyPressed(ImGuiKey.End) then
			state:OnKeyPressed(if io.KeyCtrl then bor(STB_TEXTEDIT_K_TEXTEND, k_mask) else bor(STB_TEXTEDIT_K_LINEEND, k_mask))
		elseif ImGui.IsKeyPressed(ImGuiKey.Delete) and not is_readonly and not is_cut then
			if not state:HasSelection() then
				if is_wordmove_key_down then
					state:OnKeyPressed(bor(STB_TEXTEDIT_K_WORDRIGHT, STB_TEXTEDIT_K_SHIFT))
				end
			end
			state:OnKeyPressed(bor(STB_TEXTEDIT_K_DELETE, k_mask))
		elseif ImGui.IsKeyPressed(ImGuiKey.Backspace) and not is_readonly then
			if not state:HasSelection() then
				if is_wordmove_key_down then
					state:OnKeyPressed(bor(STB_TEXTEDIT_K_WORDLEFT, STB_TEXTEDIT_K_SHIFT))
				elseif is_osx and io.KeyCtrl and not io.KeyAlt and not io.KeySuper then
					state:OnKeyPressed(bor(STB_TEXTEDIT_K_LINESTART, STB_TEXTEDIT_K_SHIFT))
				end
			end
			state:OnKeyPressed(bor(STB_TEXTEDIT_K_BACKSPACE, k_mask))
		elseif is_enter or is_ctrl_enter or is_shift_enter or is_gamepad_validate then
			local ctrl_enter_for_new_line = btest(flags, ImGuiInputTextFlags.CtrlEnterForNewLine)
			local is_new_line = is_multiline and not is_gamepad_validate and (is_shift_enter or (is_enter and not ctrl_enter_for_new_line) or (is_ctrl_enter and ctrl_enter_for_new_line))
			if not is_new_line then
				validated = true
				clear_active_id = true
				if io.ConfigInputTextEnterKeepActive and not is_multiline and not is_ctrl_enter and not is_shift_enter then
					state:SelectAll()
					g.InputTextReactivateId = id
				end
			elseif not is_readonly then
				local ok, c = InputTextFilterCharacter(g, state, 10, callback, callback_user_data, false)
				if ok then
					state:OnCharPressed(c)
				end
			end
		elseif is_cancel then
			if btest(flags, ImGuiInputTextFlags.EscapeClearsAll) then
				if #state.TextSrc ~= 0 then
					revert_edit = true
				else
					render_cursor = false
					render_selection = false
					clear_active_id = true
				end
			else
				clear_active_id = true
				revert_edit = true
				render_cursor = false
				render_selection = false
			end
		elseif is_undo or is_redo then
			state:OnKeyPressed(if is_undo then STB_TEXTEDIT_K_UNDO else STB_TEXTEDIT_K_REDO)
			state:ClearSelection()
		elseif is_select_all then
			state:SelectAll()
			state.CursorFollow = true
		elseif is_cut or is_copy then
			if g.PlatformIO.Platform_SetClipboardTextFn ~= nil then
				local stb = state.Stb
				local ib = if state:HasSelection() then ImMin(stb.select_start, stb.select_end) else 0
				local ie = if state:HasSelection() then ImMax(stb.select_start, stb.select_end) else state.TextLen
				ImGui.SetClipboardText(ssub(state.TextSrc, ib + 1, ie))
			end
			if is_cut then
				if not state:HasSelection() then
					state:SelectAll()
				end
				state.CursorFollow = true
				stb_textedit_cut(state, state.Stb)
			end
		elseif is_paste then
			local clipboard = ImGui.GetClipboardText()
			if clipboard then
				local clipboard_len = #clipboard
				local clipboard_filtered = {}
				local s = 1
				while s <= clipboard_len and sbyte(clipboard, s) ~= 0 do
					local in_len, c = ImTextCharFromUtf8(clipboard, s, clipboard_len + 1)
					s += in_len
					local ok
					ok, c = InputTextFilterCharacter(g, state, c, callback, callback_user_data, true)
					if ok then
						table.insert(clipboard_filtered, utf8.char(c))
					end
				end
				local filtered = table.concat(clipboard_filtered)
				if #filtered > 0 then
					stb_textedit_paste(state, state.Stb, filtered, #filtered)
					state.CursorFollow = true
				end
			end
		end

		render_selection = render_selection or (state:HasSelection() and (RENDER_SELECTION_WHEN_INACTIVE or render_cursor))
	end

	local apply_new_text = nil
	local apply_new_text_length = 0
	if g.ActiveId == id then
		assert(state ~= nil)
		if revert_edit and not is_readonly then
			if btest(flags, ImGuiInputTextFlags.EscapeClearsAll) then
				assert(#state.TextSrc ~= 0)
				apply_new_text = ""
				apply_new_text_length = 0
				value_changed = true
				stb_textedit_replace(state, state.Stb, "", 0)
			elseif state.TextSrc ~= state.TextToRevertTo then
				apply_new_text = state.TextToRevertTo
				apply_new_text_length = #state.TextToRevertTo
				value_changed = true
				stb_textedit_replace(state, state.Stb, state.TextToRevertTo, #state.TextToRevertTo)
			end
		end

		if btest(flags, bor(ImGuiInputTextFlags.CallbackCompletion, ImGuiInputTextFlags.CallbackHistory, ImGuiInputTextFlags.CallbackEdit, ImGuiInputTextFlags.CallbackAlways)) then
			assert(callback ~= nil)
			local event_flag = 0
			local event_key = ImGuiKey.None
			if btest(flags, ImGuiInputTextFlags.CallbackCompletion) and ImGui.Shortcut(ImGuiKey.Tab, 0, id) then
				event_flag = ImGuiInputTextFlags.CallbackCompletion
				event_key = ImGuiKey.Tab
			elseif btest(flags, ImGuiInputTextFlags.CallbackHistory) and ImGui.IsKeyPressed(ImGuiKey.UpArrow) then
				event_flag = ImGuiInputTextFlags.CallbackHistory
				event_key = ImGuiKey.UpArrow
			elseif btest(flags, ImGuiInputTextFlags.CallbackHistory) and ImGui.IsKeyPressed(ImGuiKey.DownArrow) then
				event_flag = ImGuiInputTextFlags.CallbackHistory
				event_key = ImGuiKey.DownArrow
			elseif btest(flags, ImGuiInputTextFlags.CallbackEdit) and state.EditedThisFrame then
				event_flag = ImGuiInputTextFlags.CallbackEdit
			elseif btest(flags, ImGuiInputTextFlags.CallbackAlways) then
				event_flag = ImGuiInputTextFlags.CallbackAlways
			end

			if event_flag ~= 0 then
				local callback_data = ImGuiInputTextCallbackData.new()
				callback_data.Ctx = g
				callback_data.ID = id
				callback_data.Flags = flags
				callback_data.EventFlag = event_flag
				callback_data.EventActivated = (g.ActiveId == state.ID and g.ActiveIdIsJustActivated)
				callback_data.UserData = callback_user_data

				local callback_buf = if is_readonly then buf else state.TextA
				assert(callback_buf == state.TextSrc)
				state.CallbackTextBackup = ssub(callback_buf, 1, state.TextLen)

				callback_data.EventKey = event_key
				callback_data.Buf = callback_buf
				callback_data.BufTextLen = state.TextLen
				callback_data.BufSize = state.BufCapacity
				callback_data.BufDirty = false
				callback_data.CursorPos = state.Stb.cursor
				callback_data.SelectionStart = state.Stb.select_start
				callback_data.SelectionEnd = state.Stb.select_end

				callback(callback_data)

				assert(callback_data.BufSize == state.BufCapacity)
				assert(callback_data.Flags == flags)
				if callback_data.BufDirty or callback_data.CursorPos ~= state.Stb.cursor then
					state.CursorFollow = true
				end
				state.Stb.cursor = ImClamp(callback_data.CursorPos, 0, callback_data.BufTextLen)
				state.Stb.select_start = ImClamp(callback_data.SelectionStart, 0, callback_data.BufTextLen)
				state.Stb.select_end = ImClamp(callback_data.SelectionEnd, 0, callback_data.BufTextLen)
				if callback_data.BufDirty then
					assert(callback_data.BufTextLen == #callback_data.Buf)
					InputTextReconcileUndoState(state, state.CallbackTextBackup, #state.CallbackTextBackup, callback_data.Buf, callback_data.BufTextLen)
					if is_readonly then
						buf = callback_data.Buf
					end
					state.TextA = callback_data.Buf
					state.TextSrc = callback_data.Buf
					state.TextLen = callback_data.BufTextLen
					state.EditedBefore = true
					state.EditedThisFrame = true
					state:CursorAnimReset()
				end
			end
		end

		if not is_readonly then
			if btest(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputText) then
				if state.TextSrc ~= buf or (is_mixed and (state.EditedThisFrame or validated)) then
					apply_new_text = state.TextSrc
					apply_new_text_length = state.TextLen
					value_changed = true
				end
			else
				value_changed = (validated or clear_active_id or revert_edit) and (state.TextSrc ~= buf or (is_mixed and validated))
				apply_new_text = if value_changed then state.TextSrc else nil
				apply_new_text_length = if value_changed then state.TextLen else 0
			end
		end
	end

	if g.InputTextDeactivatedState.ID == id then
		if (g.ActiveId ~= id and ImGui.IsItemDeactivated()) or (g.ActiveId == id and btest(flags, ImGuiInputTextFlags.TempInput)) then
			if not is_readonly and g.InputTextDeactivatedState.TextA ~= buf then
				apply_new_text = g.InputTextDeactivatedState.TextA
				apply_new_text_length = #apply_new_text
				value_changed = true
			end
		end
		g.InputTextDeactivatedState.ID = 0
	end

	if apply_new_text ~= nil then
		assert(apply_new_text_length >= 0)
		buf = ssub(apply_new_text, 1, apply_new_text_length)
		if is_resizable then
			local callback_data = ImGuiInputTextCallbackData.new()
			callback_data.Ctx = g
			callback_data.ID = id
			callback_data.Flags = flags
			callback_data.EventFlag = ImGuiInputTextFlags.CallbackResize
			callback_data.EventActivated = (state ~= nil and g.ActiveId == state.ID and g.ActiveIdIsJustActivated)
			callback_data.Buf = buf
			callback_data.BufTextLen = apply_new_text_length
			callback_data.BufSize = apply_new_text_length + 1
			callback_data.UserData = callback_user_data
			callback(callback_data)
		end
	end

	if g.ActiveId == id and clear_active_id then
		state.EditedBefore = false
		ImGui.ClearActiveID()
	end

	if not is_multiline then
		ImGui.RenderNavCursor(frame_bb, id)
		ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), true, style.FrameRounding)
	end

	local draw_pos = if is_multiline then draw_window.DC.CursorPos else frame_bb.Min + style.FramePadding
	local clip_rect = ImRect.fromXY(frame_bb.Min.x, frame_bb.Min.y, frame_bb.Min.x + inner_size.x, frame_bb.Min.y + inner_size.y)
	if is_multiline then
		clip_rect = clip_rect:ClippedWith(draw_window.ClipRect)
	end

	local buf_display_max_length = 2 * 1024 * 1024
	local buf_display = if buf_display_from_state then state.TextA else buf
	local buf_display_end = nil

	local new_is_displaying_hint = (hint ~= nil and #(if buf_display_from_state then state.TextA else buf) == 0) and not is_mixed
	if new_is_displaying_hint ~= is_displaying_hint then
		if is_password and not is_displaying_hint then
			ImGui.PopPasswordFont()
		end
		is_displaying_hint = new_is_displaying_hint
		if is_password and not is_displaying_hint then
			ImGui.PushPasswordFont()
		end
	end
	local is_displaying_mixed = is_mixed and g.ActiveId ~= id and apply_new_text == nil
	if is_displaying_mixed and g.MixedValueLabel ~= nil then
		buf_display = g.MixedValueLabel
		buf_display_end = #buf_display
		render_cursor = false
		render_selection = false
	elseif is_displaying_hint then
		buf_display = hint
		buf_display_end = #buf_display
	else
		if render_cursor or render_selection or g.ActiveId == id then
			buf_display_end = state.TextLen
		elseif is_multiline and not is_wordwrap then
			buf_display_end = nil
		else
			buf_display_end = #buf_display
		end
	end

	local line_visible_n0, line_visible_n1 = 0, 1
	if is_multiline then
		line_visible_n0, line_visible_n1 = ImGui.CalcClipRectVisibleItemsY(clip_rect, draw_pos, g.FontSize, nil, nil)
	end

	local line_index = g.InputTextLineIndex
	line_index.Offsets:resize(0)
	local line_count = 1
	if is_multiline then
		local will_scroll_y = state ~= nil and ((state.CursorFollow and render_cursor) or (state.CursorCenterY and (render_cursor or render_selection)))
		local out_buf_end
		line_count, out_buf_end = InputTextLineIndexBuild(flags, line_index, buf_display, buf_display_end, wrap_width, if will_scroll_y then INT_MAX else line_visible_n1 + 1)
		if buf_display_end == nil then
			buf_display_end = out_buf_end
		end
	end
	line_index.EndOffset = buf_display_end
	line_visible_n1 = ImMin(line_visible_n1, line_count)

	local text_size_y = line_count * g.FontSize

	local cursor_offset = if render_cursor and state then InputTextLineIndexGetPosOffset(g, state, line_index, buf_display, buf_display_end, state.Stb.cursor) else ImVec2(0.0, 0.0)
	local draw_scroll = ImVec2(0.0, 0.0)

	local text_col = ImGui.GetColorU32(if is_displaying_mixed then ImGuiCol.TextMixedValue elseif is_displaying_hint then ImGuiCol.TextDisabled else ImGuiCol.Text)
	if render_cursor or render_selection then
		assert(state ~= nil)
		state.LineCount = line_count

		local new_scroll_y = scroll_y
		if render_cursor and state.CursorFollow then
			if not btest(flags, ImGuiInputTextFlags.NoHorizontalScroll) then
				local scroll_increment_x = inner_size.x * 0.25
				local visible_width = inner_size.x - style.FramePadding.x
				if cursor_offset.x < state.Scroll.x then
					state.Scroll = ImVec2(IM_TRUNC(ImMax(0.0, cursor_offset.x - scroll_increment_x)), state.Scroll.y)
				elseif cursor_offset.x - visible_width >= state.Scroll.x then
					state.Scroll = ImVec2(IM_TRUNC(cursor_offset.x - visible_width + scroll_increment_x), state.Scroll.y)
				end
			else
				state.Scroll = ImVec2(0.0, state.Scroll.y)
			end

			if is_multiline then
				if cursor_offset.y - g.FontSize < scroll_y then
					new_scroll_y = ImMax(0.0, cursor_offset.y - g.FontSize)
				elseif cursor_offset.y - (inner_size.y - style.FramePadding.y * 2.0) >= scroll_y then
					new_scroll_y = cursor_offset.y - inner_size.y + style.FramePadding.y * 2.0
				end
			end
			state.CursorFollow = false
		end
		if state.CursorCenterY then
			if is_multiline then
				new_scroll_y = cursor_offset.y - g.FontSize - (inner_size.y * 0.5 - style.FramePadding.y)
			end
			state.CursorCenterY = false
			render_cursor = false
		end
		if new_scroll_y ~= scroll_y then
			local scroll_max_y = ImMax((text_size_y + style.FramePadding.y * 2.0) - inner_size.y, 0.0)
			scroll_y = ImClamp(new_scroll_y, 0.0, scroll_max_y)
			draw_pos = ImVec2(draw_pos.x, draw_pos.y + (draw_window.Scroll.y - scroll_y))
			draw_window.Scroll = ImVec2(draw_window.Scroll.x, scroll_y)
			line_visible_n0, line_visible_n1 = ImGui.CalcClipRectVisibleItemsY(clip_rect, draw_pos, g.FontSize, nil, nil)
			line_visible_n1 = ImMin(line_visible_n1, line_count)
		end

		draw_scroll = ImVec2(state.Scroll.x, draw_scroll.y)
		if render_selection then
			local bg_color = ImGui.GetColorU32(ImGuiCol.TextSelectedBg, if render_cursor then 1.0 else 0.6)
			local bg_offy_up = if is_multiline then 0.0 else -1.0
			local bg_offy_dn = if is_multiline then 0.0 else 2.0
			local bg_eol_width = IM_TRUNC(g.FontBaked:GetCharAdvance(32) * 0.50)

			local text_selected_begin = ImMin(state.Stb.select_start, state.Stb.select_end)
			local text_selected_end = ImMax(state.Stb.select_start, state.Stb.select_end)
			for line_n = line_visible_n0, line_visible_n1 - 1 do
				local p = LineIndexGetLineBegin(line_index, line_n)
				local p_eol = LineIndexGetLineEnd(line_index, line_n)
				local p_eol_is_wrap = p_eol < buf_display_end and sbyte(buf_display, p_eol + 1) ~= 10
				if p_eol_is_wrap then
					p_eol += 1
				end
				local line_selected_begin = if text_selected_begin > p then text_selected_begin else p
				local line_selected_end = if text_selected_end < p_eol then text_selected_end else p_eol

				local rect_width = 0.0
				if line_selected_begin < line_selected_end then
					rect_width += ImGui.CalcTextSize(ssub(buf_display, line_selected_begin + 1, line_selected_end)).x
				end
				if text_selected_begin <= p_eol and text_selected_end > p_eol and not p_eol_is_wrap then
					rect_width += bg_eol_width
				end
				if rect_width == 0.0 then
					continue
				end

				local min_x = draw_pos.x - draw_scroll.x + ImGui.CalcTextSize(ssub(buf_display, p + 1, line_selected_begin)).x
				local min_y = draw_pos.y - draw_scroll.y + line_n * g.FontSize
				local rect = ImRect.fromXY(min_x, min_y + bg_offy_up, min_x + rect_width, min_y + bg_offy_dn + g.FontSize)
				rect = rect:ClippedWith(clip_rect)
				draw_window.DrawList:AddRectFilled(rect.Min, rect.Max, bg_color)
			end
		end
	end

	if g.ActiveId ~= id and btest(flags, ImGuiInputTextFlags.ElideLeft) and not render_cursor and not render_selection then
		draw_pos = ImVec2(ImMin(draw_pos.x, frame_bb.Max.x - ImGui.CalcTextSize(buf_display, nil).x - style.FramePadding.x), draw_pos.y)
	end

	if (is_multiline or buf_display_end < buf_display_max_length) and band(text_col, IM_COL32_A_MASK) ~= 0 and line_visible_n0 < line_visible_n1 then
		local display_text = ssub(buf_display, LineIndexGetLineBegin(line_index, line_visible_n0) + 1, LineIndexGetLineEnd(line_index, line_visible_n1 - 1))
		if is_password and not is_displaying_hint then
			display_text = string.gsub(display_text, "[^\n\128-\191][\128-\191]*", "*")
		end
		g.Font:RenderText(draw_window.DrawList, g.FontSize, draw_pos - draw_scroll + ImVec2(0.0, line_visible_n0 * g.FontSize), text_col, clip_rect:ToVec4(), display_text, nil, wrap_width, bor(ImDrawTextFlags.WrapKeepBlanks, ImDrawTextFlags.CpuFineClip))
	end

	if render_cursor then
		state.CursorAnim += io.DeltaTime
		local cursor_is_visible = (not g.IO.ConfigInputTextCursorBlink) or (state.CursorAnim <= 0.0) or math.fmod(state.CursorAnim, 1.20) <= 0.80
		local cursor_screen_pos = ImTrunc(draw_pos + cursor_offset - draw_scroll)
		local cursor_screen_rect = ImRect.fromXY(cursor_screen_pos.x, cursor_screen_pos.y - g.FontSize + 1.0, cursor_screen_pos.x + 1.0, cursor_screen_pos.y - 1.0)
		if cursor_is_visible and cursor_screen_rect:Overlaps(clip_rect) then
			draw_window.DrawList:AddLineV(cursor_screen_rect.Min.x, cursor_screen_rect.Min.y, cursor_screen_rect.Max.y, ImGui.GetColorU32(ImGuiCol.InputTextCursor), style.InputTextCursorSize, ImDrawFlags.StrokeInside)
		end

		if not is_readonly and g.ActiveId == id then
			local ime_data = g.PlatformImeData
			ime_data.WantVisible = true
			ime_data.WantTextInput = true
			ime_data.InputPos = ImVec2(cursor_screen_pos.x - 1.0, cursor_screen_pos.y - g.FontSize)
			ime_data.InputLineHeight = g.FontSize
			ime_data.ViewportId = window.Viewport.ID
		end
	end

	if is_password and not is_displaying_hint then
		ImGui.PopPasswordFont()
	end

	if is_multiline then
		ImGui.Dummy(ImVec2(0.0, text_size_y + style.FramePadding.y))
		g.NextItemData.ItemFlagsSet = bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.Inputable, ImGuiItemFlags.NoTabStop)
		ImGui.EndChild()
		item_data_backup.StatusFlags = bor(item_data_backup.StatusFlags, band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow))

		ImGui.EndGroup()
		if g.LastItemData.ID == 0 or g.LastItemData.ID ~= ImGui.GetWindowScrollbarID(draw_window, ImGuiAxis.Y) then
			g.LastItemData.ID = id
			g.LastItemData.ItemFlags = item_data_backup.ItemFlags
			g.LastItemData.StatusFlags = item_data_backup.StatusFlags
		end
	end
	if state and is_readonly then
		state.TextSrc = nil
	end

	if g.LogEnabled and (not is_password or is_displaying_hint) then
		ImGui.LogSetNextTextDecoration("{", "}")
		ImGui.LogRenderedText(draw_pos, buf_display, buf_display_end + 1)
	end

	if label_size.x > 0 then
		ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y), label, label_end, false)
	end

	if state and validated then
		state.ValidatedThisFrame = true
	end
	if value_changed then
		ImGui.MarkItemEdited(id)
	end

	if btest(flags, ImGuiInputTextFlags.EnterReturnsTrue) then
		return validated, buf
	end
	return value_changed, buf
end

function ImGui.DebugNodeInputTextState(state)
	local g = ImGui.GImGui
	InputTextStatePrepare(state, g)
	local stb_state = state.Stb
	local undo_state = stb_state.undostate
	ImGui.Text("ID: 0x%08X, ActiveID: 0x%08X", state.ID, g.ActiveId)
	ImGui.DebugLocateItemOnHover(state.ID)
	ImGui.Text("TextLen: %d, Cursor: %d%s, Selection: %d..%d", state.TextLen, stb_state.cursor, if btest(state.Flags, ImGuiInputTextFlags.WordWrap) then (if state.LastMoveDirectionLR == ImGuiDir.Left then " (L)" else " (R)") else "", stb_state.select_start, stb_state.select_end)
	ImGui.Text("BufCapacity: %d, LineCount: %d", state.BufCapacity, state.LineCount)
	ImGui.Text("(Internal Buffer: TextA Size: %d, Capacity: %d)", #state.TextA + 1, #state.TextA + 1)
	ImGui.Text("has_preferred_x: %d (%.2f)", stb_state.has_preferred_x, stb_state.preferred_x)
	ImGui.Text("undo_point: %d, redo_point: %d, undo_char_point: %d, redo_char_point: %d", undo_state.undo_point, undo_state.redo_point, undo_state.undo_char_point, undo_state.redo_char_point)
	if ImGui.BeginChild("undopoints", ImVec2(0.0, ImGui.GetTextLineHeight() * 10), bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then
		ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
		for n = 0, IMSTB_TEXTEDIT_UNDOSTATECOUNT - 1 do
			local undo_rec = undo_state.undo_rec[n + 1]
			local undo_rec_type = if n < undo_state.undo_point then "u" elseif n >= undo_state.redo_point then "r" else " "
			if undo_rec_type == " " then
				ImGui.BeginDisabled()
			end
			local buf_preview_len = if undo_rec_type ~= " " and undo_rec.char_storage ~= -1 then undo_rec.insert_length else 0
			local buf_preview_str = ""
			if buf_preview_len > 0 and undo_rec.char_storage >= 0 and undo_rec.char_storage + buf_preview_len <= IMSTB_TEXTEDIT_UNDOCHARCOUNT then
				buf_preview_str = stb_undo_chars(undo_state, undo_rec.char_storage, buf_preview_len)
			end
			ImGui.Text("%s [%02d] where %03d, insert %03d, delete %03d, char_storage %03d \"%s\"", undo_rec_type, n, undo_rec.where, undo_rec.insert_length, undo_rec.delete_length, undo_rec.char_storage, buf_preview_str)
			if undo_rec_type == " " then
				ImGui.EndDisabled()
			end
		end
		ImGui.PopStyleVar()
	end
	ImGui.EndChild()
end

return true
