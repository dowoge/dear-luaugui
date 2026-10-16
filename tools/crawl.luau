local ImGui = require("@ImGui")
local Structs = require("@ImGui/Structs")
local Demo = ImGui._Demo
local K = ImGui.Enums.ImGuiKey
local M = ImGui.Enums.ImGuiMod
local WF = ImGui.Enums.ImGuiWindowFlags
local IF = ImGui.Enums.ImGuiItemFlags

local args = { ... }
local target = args[1] or "list"
local shard = tonumber(args[2]) or 0
local nshards = tonumber(args[3]) or 1
local max_items = tonumber(args[4]) or math.huge
local verbose = args[5] == "v"

local DEMO = "Dear ImGui Demo"
local section = string.match(target, "^demo:(.+)$")
local sub = nil
do
	local a, b = string.match(section or "", "^(.-)/(.+)$")
	if a then
		section, sub = a, b
	end
end
local subs_seen = {}
local subs_list = {}
local is_demo = target == "demo" or target == "list" or section ~= nil
local big = is_demo
local demo_data = {}

local g, io
local cur, items, order = {}, {}, {}
local labels = {}
local sections = {}
local cur_section = nil
local frame_msgs = {}
local ctx_desc = "warmup"
local fails, fail_sigs, nfail = {}, {}, 0
local stats = { items = 0, actions = 0, popups = 0, frames = 0, skipped = 0 }
local reset_pending = false
local io_snap, style_snap, win_snap = {}, nil, {}

local oGetID = Structs.ImGuiWindow.GetID
Structs.ImGuiWindow.GetID = function(self, s, e)
	local id = oGetID(self, s, e)
	if type(s) == "string" and e == nil then
		labels[id] = s
	end
	return id
end

local oCH = ImGui.CollapsingHeader
ImGui.CollapsingHeader = function(label, ...)
	local w = g.CurrentWindow
	if w and w.Name == DEMO and w.IDStack.Size == 1 and w.DC.TreeDepth == 0 then
		cur_section = label
		if not sections[label] then
			sections[label] = true
			table.insert(sections, label)
		end
		if label == section or target == "list" then
			ImGui.SetNextItemOpen(true)
		end
	end
	return oCH(label, ...)
end

local oTN = ImGui.TreeNodeUpdateNextOpen
ImGui.TreeNodeUpdateNextOpen = function(storage_id, flags)
	local r = oTN(storage_id, flags)
	local w = g.CurrentWindow
	if not (w and w.RootWindow and w.RootWindow.Name == DEMO and cur_section) then
		return r
	end
	local l = labels[storage_id]
	if l == cur_section then
		return r
	end
	if target == "list" then
		if w.DC.TreeDepth == 0 and l and not subs_seen[cur_section .. "/" .. l] then
			subs_seen[cur_section .. "/" .. l] = true
			table.insert(subs_list, cur_section .. "/" .. l)
		end
		return r
	end
	if section and cur_section == section then
		if sub == nil or w.DC.TreeDepth > 0 then
			return true
		end
		return l == sub
	end
	return r
end

local close_extra = false
local oBegin = ImGui.Begin
ImGui.Begin = function(name, p_open, flags)
	local visible, p = oBegin(name, p_open, flags)
	if close_extra and p_open ~= nil and next(win_snap) ~= nil and not win_snap[name] then
		return visible, false
	end
	return visible, p
end

local oItemAdd = ImGui.ItemAdd
ImGui.ItemAdd = function(bb, id, nav_bb, extra)
	local r = oItemAdd(bb, id, nav_bb, extra)
	if r and id ~= 0 and not bit32.btest(g.LastItemData.ItemFlags, IF.Disabled) then
		local w = g.CurrentWindow
		local vb = bb:ClippedWith(w.ClipRect)
		if vb.Max.x - vb.Min.x >= 2 and vb.Max.y - vb.Min.y >= 2 then
			table.insert(cur, { id = id, win = w, bb = vb })
		end
	end
	return r
end

local function show()
	if is_demo then
		ImGui.ShowDemoWindow(true)
	elseif target == "metrics" then
		ImGui.ShowMetricsWindow(true)
	elseif target == "debuglog" then
		ImGui.ShowDebugLogWindow(true)
	elseif target == "idstack" then
		ImGui.ShowIDStackToolWindow(true)
	elseif target == "style" then
		ImGui.Begin("Dear ImGui Style Editor", true)
		ImGui.ShowStyleEditor()
		ImGui.End()
	elseif target == "about" then
		ImGui.ShowAboutWindow(true)
	elseif target == "userguide" then
		ImGui.Begin("User Guide")
		ImGui.ShowUserGuide()
		ImGui.End()
	else
		local app = string.match(target, "^app:(.+)$")
		Demo[app](true, demo_data)
	end
end

local function first_line(s)
	return string.match(tostring(s), "^[^\n]*") or tostring(s)
end

local function fail(kind, msg, tb)
	local loc = ""
	if tb then
		for l in string.gmatch(tb, "[^\n]+") do
			local m = string.match(l, "ImGui/([%w_]+%.luau:%d+)")
			if m and not string.find(l, "crawl.luau", 1, true) then
				loc = m
				break
			end
		end
	end
	local sig = kind .. "|" .. string.gsub(first_line(msg), "0x%x+", "") .. "|" .. loc
	nfail += 1
	if fail_sigs[sig] then
		fail_sigs[sig] += 1
		if verbose then
			print("FAIL+ " .. kind .. " @ " .. ctx_desc)
		end
		return
	end
	fail_sigs[sig] = 1
	table.insert(fails, sig)
	print(string.format("FAIL %s [%s] at %s\n  msg: %s", kind, target, ctx_desc, first_line(msg)))
	if tb then
		local n = 0
		for l in string.gmatch(tb, "[^\n]+") do
			if not string.find(l, "crawl.luau", 1, true) then
				print("  " .. l)
				n += 1
				if n >= 14 then
					break
				end
			end
		end
	end
end

local function setup_context()
	ImGui.CreateContext()
	g = ImGui.GImGui
	io = ImGui.GetIO()
	io.DisplaySize = if big then vector.create(3000, 40000, 0) else vector.create(1600, 1000, 0)
	io.DeltaTime = 1 / 60
	io.ConfigFlags = bit32.bor(io.ConfigFlags, ImGui.Enums.ImGuiConfigFlags.NavEnableKeyboard)
	io.ConfigErrorRecovery = true
	io.ConfigErrorRecoveryEnableAssert = false
	io.ConfigErrorRecoveryEnableTooltip = false
	io.ConfigErrorRecoveryEnableDebugLog = true
	g.ErrorCallback = function(_, _, msg)
		table.insert(frame_msgs, msg)
	end
	io_snap = {}
	for k, v in io do
		if type(k) == "string" and (string.sub(k, 1, 6) == "Config" or k == "MouseDrawCursor") and (type(v) == "boolean" or type(v) == "number") then
			io_snap[k] = v
		end
	end
	style_snap = g.Style:Copy()
end

local function restore_globals()
	for k, v in io_snap do
		io[k] = v
	end
	g.ErrorCallback = function(_, _, msg)
		table.insert(frame_msgs, msg)
	end
	local cur_style = g.Style
	local snap = style_snap:Copy()
	for k, v in snap do
		cur_style[k] = v
	end
end

local frame
local function fatal(stage, e)
	fail("FATAL-" .. stage, e, e)
	pcall(ImGui.DestroyContext)
	setup_context()
	frame()
end

function frame(dt)
	stats.frames += 1
	io.DeltaTime = dt or 1 / 60
	io.ConfigErrorRecovery = true
	io.ConfigErrorRecoveryEnableAssert = false
	io.ConfigErrorRecoveryEnableTooltip = false
	frame_msgs = {}
	cur = {}
	cur_section = nil
	local ok, e = xpcall(ImGui.NewFrame, debug.traceback)
	if not ok then
		return fatal("NewFrame", e)
	end
	if reset_pending then
		reset_pending = false
		if g.OpenPopupStack.Size > 0 then
			ImGui.ClosePopupToLevel(0, false)
		end
		if g.ActiveId ~= 0 then
			ImGui.ClearActiveID()
		end
	end
	local ok2, e2 = xpcall(show, debug.traceback)
	local msgs_before = frame_msgs
	if not ok2 then
		frame_msgs = {}
		local ok3, e3 = xpcall(ImGui.ErrorRecoveryTryToRecoverState, debug.traceback, g.StackSizesInNewFrame)
		if not ok3 then
			fail("ERROR", e2, e2)
			return fatal("Recover", e3)
		end
	end
	local ok4, e4 = xpcall(ImGui.Render, debug.traceback)
	if not ok2 then
		fail("ERROR", e2, e2)
	end
	for _, m in msgs_before do
		fail("USERERROR", m, nil)
	end
	if not ok2 then
		frame_msgs = {}
	end
	for _, m in frame_msgs do
		fail("USERERROR(EndFrame)", m, nil)
	end
	if not ok4 then
		return fatal("Render", e4)
	end
	if g.DebugDrawIdConflictsId ~= 0 then
		fail("IDCONFLICT", string.format("%s 0x%08X", tostring(labels[g.DebugDrawIdConflictsId]), g.DebugDrawIdConflictsId), nil)
	end
	items, order = {}, {}
	for _, it in cur do
		local key = it.win.Name .. "|" .. it.id
		if not items[key] then
			it.key = key
			items[key] = it
			table.insert(order, key)
		end
	end
end

local function pos(x, y)
	io:AddMousePosEvent(x, y)
end
local function btn(b, d)
	io:AddMouseButtonEvent(b, d)
end
local function key(k, d)
	io:AddKeyEvent(k, d)
end
local function mods(m, d)
	if m == "ctrl" then
		key(K.LeftCtrl, d)
		key(M.Ctrl, d)
	elseif m == "shift" then
		key(K.LeftShift, d)
		key(M.Shift, d)
	end
end
local function pump(n)
	frame()
	local i = 1
	while g.InputEventsQueue.Size > 0 and i < (n or 80) do
		frame()
		i += 1
	end
end
local function tap(k, m)
	if m then
		mods(m, true)
	end
	key(k, true)
	key(k, false)
	if m then
		mods(m, false)
	end
end

local function click(x, y, b)
	pos(x, y)
	frame()
	btn(b or 0, true)
	frame()
	btn(b or 0, false)
	frame()
end

local function text_active()
	return g.ActiveId ~= 0 and g.InputTextState.ID == g.ActiveId
end

local TEXT_KEYS = {
	{ K.LeftArrow }, { K.LeftArrow, "shift" }, { K.RightArrow }, { K.Home }, { K.End, "shift" }, { K.Backspace },
	{ K.Delete }, { K.A, "ctrl" }, { K.C, "ctrl" }, { K.X, "ctrl" }, { K.V, "ctrl" }, { K.V, "ctrl" }, { K.Z, "ctrl" },
	{ K.Y, "ctrl" }, { K.UpArrow }, { K.DownArrow }, { K.PageUp }, { K.PageDown }, { K.Enter },
}
local NAV_KEYS = { { K.LeftArrow }, { K.RightArrow }, { K.UpArrow }, { K.DownArrow }, { K.Space }, { K.Enter } }

local ACT = {}
function ACT.hover(x, y)
	pos(x, y)
	frame()
	frame(0.3)
	frame(0.3)
end
function ACT.click(x, y)
	click(x, y)
end
function ACT.dclick(x, y)
	pos(x, y)
	frame()
	btn(0, true)
	btn(0, false)
	btn(0, true)
	btn(0, false)
	pump()
end
function ACT.rclick(x, y)
	click(x, y, 1)
	frame()
end
function ACT.dragh(x, y)
	pos(x, y)
	frame()
	btn(0, true)
	frame()
	for i = 1, 4 do
		pos(x + 25 * i, y)
		frame()
	end
	pos(x - 40, y)
	frame()
	btn(0, false)
	frame()
end
function ACT.dragv(x, y)
	pos(x, y)
	frame()
	btn(0, true)
	frame()
	for i = 1, 4 do
		pos(x, y + 20 * i)
		frame()
	end
	pos(x, y - 30)
	frame()
	btn(0, false)
	frame()
end
function ACT.ctrlclick(x, y)
	pos(x, y)
	frame()
	mods("ctrl", true)
	btn(0, true)
	frame()
	btn(0, false)
	frame()
	mods("ctrl", false)
	frame()
end
function ACT.shiftclick(x, y)
	pos(x, y)
	frame()
	mods("shift", true)
	btn(0, true)
	frame()
	btn(0, false)
	frame()
	mods("shift", false)
	frame()
end
function ACT.type(x, y)
	click(x, y)
	if text_active() then
		io:AddInputCharactersUTF8("Ab1.5-\xC3\xA9 ")
		for _, k in TEXT_KEYS do
			tap(k[1], k[2])
		end
	else
		for _, k in NAV_KEYS do
			tap(k[1], k[2])
		end
	end
	pump()
end
function ACT.typeesc(x, y)
	click(x, y)
	io:AddInputCharactersUTF8("7x")
	tap(K.Escape)
	pump()
end
function ACT.typetab(x, y)
	click(x, y)
	io:AddInputCharactersUTF8("42")
	tap(K.Tab)
	tap(K.Tab, "shift")
	tap(K.Enter)
	pump()
end
function ACT.wheel(x, y)
	pos(x, y)
	frame()
	io:AddMouseWheelEvent(0, 1)
	frame()
	io:AddMouseWheelEvent(0, -2)
	frame()
	io:AddMouseWheelEvent(1, 0)
	frame()
	mods("ctrl", true)
	io:AddMouseWheelEvent(0, 1)
	frame()
	mods("ctrl", false)
	frame()
end

local TOP_ACTIONS = { "hover", "dclick", "rclick", "dragh", "dragv", "ctrlclick", "shiftclick", "type", "typeesc", "typetab", "wheel", "click" }
local POPUP_ACTIONS = { "hover", "rclick", "dragh", "ctrlclick", "type", "wheel", "click" }
local MAX_DEPTH = 3
local MAX_POPUP_ITEMS = 40

local function pick_point(it)
	local bb = it.bb
	for _, f in { { 0.5, 0.5 }, { 0.25, 0.5 }, { 0.75, 0.5 }, { 0.1, 0.5 }, { 0.9, 0.5 } } do
		local x = math.floor(bb.Min.x + (bb.Max.x - bb.Min.x) * f[1])
		local y = math.floor(bb.Min.y + (bb.Max.y - bb.Min.y) * f[2])
		local hw = ImGui.FindHoveredWindowEx(vector.create(x, y, 0), false)
		if hw and hw.RootWindow == it.win.RootWindow then
			return x, y
		end
	end
	return nil
end

local function describe(key)
	local it = items[key]
	local wn, id = string.match(key, "^(.*)|(%d+)$")
	local l = labels[tonumber(id)]
	return string.format("%s|%s", wn, l or string.format("0x%08X", tonumber(id)))
end

local function perform(key, act)
	local it = items[key]
	if not it then
		return false
	end
	local x, y = pick_point(it)
	if not x then
		return false
	end
	ACT[act](x, y)
	return true
end

local restore_windows
local function reset()
	btn(0, false)
	btn(1, false)
	reset_pending = true
	close_extra = true
	frame(0.5)
	frame()
	close_extra = false
	if restore_windows then
		restore_windows()
	end
	frame()
end

local function open_popups()
	local s = {}
	for i = 1, g.OpenPopupStack.Size do
		local w = g.OpenPopupStack[i].Window
		if w then
			s[w.Name] = w
		end
	end
	return s
end

local recursed = {}
local popup_count = {}

local function crawl_item(path, key, depth, actions)
	for _, act in actions do
		reset()
		local ok = true
		local desc = {}
		for _, step in path do
			if not perform(step[1], step[2]) then
				ok = false
				break
			end
			table.insert(desc, describe(step[1]) .. ":" .. step[2])
		end
		if not ok then
			stats.skipped += 1
			return
		end
		local before = open_popups()
		table.insert(desc, describe(key) .. ":" .. act)
		ctx_desc = table.concat(desc, " > ")
		if not items[key] then
			stats.skipped += 1
			return
		end
		if verbose then
			print("DO " .. ctx_desc)
		end
		if perform(key, act) then
			stats.actions += 1
			if depth < MAX_DEPTH then
				for name, w in open_popups() do
					if not before[name] and not recursed[key .. "#" .. name] and (popup_count[name] or 0) < 4 then
						recursed[key .. "#" .. name] = true
						popup_count[name] = (popup_count[name] or 0) + 1
						stats.popups += 1
						local child = {}
						for _, k in order do
							if items[k].win.RootWindow == w and #child < MAX_POPUP_ITEMS then
								table.insert(child, k)
							end
						end
						local npath = table.clone(path)
						table.insert(npath, { key, act })
						for _, ck in child do
							crawl_item(npath, ck, depth + 1, POPUP_ACTIONS)
						end
					end
				end
			end
		else
			stats.skipped += 1
		end
	end
end

local function snap_windows()
	win_snap = {}
	for i = 1, g.Windows.Size do
		local w = g.Windows[i]
		if w.Active and not bit32.btest(w.Flags, WF.ChildWindow) and not bit32.btest(w.Flags, WF.Popup) and not bit32.btest(w.Flags, WF.Tooltip) then
			win_snap[w.Name] = { pos = w.Pos, size = w.Size }
		end
	end
end

function restore_windows()
	for name, s in win_snap do
		local w = ImGui.FindWindowByName(name)
		if w then
			if w.Collapsed then
				ImGui.SetWindowCollapsed(w, false)
			end
			if w.Pos ~= s.pos then
				ImGui.SetWindowPos(w, s.pos)
			end
			if w.Size ~= s.size and not bit32.btest(w.Flags, WF.AlwaysAutoResize) then
				ImGui.SetWindowSize(w, s.size)
			end
		end
	end
end

setup_context()
frame()
if big then
	frame()
	ImGui.SetWindowPos(ImGui.FindWindowByName(DEMO), vector.create(0, 0, 0))
	ImGui.SetWindowSize(ImGui.FindWindowByName(DEMO), vector.create(2900, 39000, 0))
end
for _ = 1, 3 do
	frame()
end

if target == "list" then
	for _, s in ipairs(sections) do
		print("SECTION " .. s)
	end
	for _, s in ipairs(subs_list) do
		print("SUB " .. s)
	end
	return
end

snap_windows()
local t0 = os.clock()
local done = {}
local per_window = {}
for round = 1, 4 do
	local todo = {}
	for _, k in order do
		local it = items[k]
		if not done[k] and win_snap[it.win.RootWindow.Name] and it.id % nshards == shard and (per_window[it.win.Name] or 0) < 40 then
			per_window[it.win.Name] = (per_window[it.win.Name] or 0) + 1
			table.insert(todo, k)
		end
	end
	if #todo == 0 then
		break
	end
	for _, k in todo do
		if stats.items >= max_items then
			break
		end
		if not done[k] and items[k] then
			done[k] = true
			stats.items += 1
			crawl_item({}, k, 0, TOP_ACTIONS)
			ctx_desc = describe(k) .. ":settle"
			reset()
			restore_globals()
			restore_windows()
			frame()
		end
	end
	print(string.format("ROUND %d items=%d actions=%d t=%.1f", round, stats.items, stats.actions, os.clock() - t0))
end

print(string.format("SUMMARY target=%s shard=%d/%d items=%d actions=%d popups=%d skipped=%d frames=%d fails=%d unique=%d time=%.1f", target, shard, nshards, stats.items, stats.actions, stats.popups, stats.skipped, stats.frames, nfail, #fails, os.clock() - t0))
for _, s in fails do
	print(string.format("SIG %dx %s", fail_sigs[s], s))
end
