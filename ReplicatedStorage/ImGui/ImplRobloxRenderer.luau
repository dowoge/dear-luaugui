--!native
local DrawList = require("./DrawList")

local PrimKind = DrawList.PrimKind
local STRIDE = DrawList.PRIM_STRIDE

local floor, sqrt, atan2, deg, abs, max, min = math.floor, math.sqrt, math.atan2, math.deg, math.abs, math.max, math.min
local band, rshift, btest = bit32.band, bit32.rshift, bit32.btest

local ROUND_TL, ROUND_TR, ROUND_BL, ROUND_BR, ROUND_NONE = 16, 32, 64, 128, 256
local ROUND_MASK = 0x1F0
local CODE_FONT = Font.fromEnum(Enum.Font.Code)

local colorCache = {}
local function unpackColor(col)
	local c = colorCache[col]
	if c == nil then
		c = {
			Color3.fromRGB(band(col, 0xFF), band(rshift(col, 8), 0xFF), band(rshift(col, 16), 0xFF)),
			1 - band(rshift(col, 24), 0xFF) / 255,
		}
		colorCache[col] = c
	end
	return c[1], c[2]
end

local function round(v)
	return floor(v + 0.5)
end

local function newFrame(parent)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

local Element = {}
Element.__index = Element

local function newElement(renderer, kind)
	local container = Instance.new("Frame")
	container.Name = "P"
	container.BorderSizePixel = 0
	container.BackgroundTransparency = 1
	container.ClipsDescendants = true
	local el = setmetatable({ Container = container, Kind = kind, Visible = true }, Element)
	if kind == "Text" then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.BorderSizePixel = 0
		t.FontFace = CODE_FONT
		t.RichText = false
		t.TextWrapped = false
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.AutoLocalize = false
		t.Parent = container
		el.Content = t
	elseif kind == "Image" or kind == "Raster" or kind == "TriMask" then
		local im = Instance.new("ImageLabel")
		im.BackgroundTransparency = 1
		im.BorderSizePixel = 0
		im.Parent = container
		el.Content = im
	elseif kind == "Tri" then
		el.Content = newFrame(container)
		el.Content2 = newFrame(container)
		for _, f in { el.Content, el.Content2 } do
			f.BackgroundTransparency = 0
			f.BackgroundColor3 = Color3.new(1, 1, 1)
			local gr = Instance.new("UIGradient")
			gr.Parent = f
		end
		el.Grad = el.Content:FindFirstChildOfClass("UIGradient")
		el.Grad2 = el.Content2:FindFirstChildOfClass("UIGradient")
	else
		el.Content = newFrame(container)
		if kind == "RectMulti" then
			el.Content.BackgroundTransparency = 0
			el.Content.BackgroundColor3 = Color3.new(1, 1, 1)
			el.Grad = Instance.new("UIGradient")
			el.Grad.Parent = el.Content
		end
	end
	container.Parent = renderer.Root
	return el
end

function Element:SetContainer(x, y, w, h, z)
	if self.cx ~= x or self.cy ~= y then
		self.cx, self.cy = x, y
		self.Container.Position = UDim2.fromOffset(x, y)
	end
	if self.cw ~= w or self.ch ~= h then
		self.cw, self.ch = w, h
		self.Container.Size = UDim2.fromOffset(w, h)
	end
	if self.z ~= z then
		self.z = z
		self.Container.ZIndex = z
	end
	if not self.Visible then
		self.Visible = true
		self.Container.Visible = true
	end
end

local function setFrameGeom(el, f, keyPrefix, x, y, w, h, rot)
	local k = el[keyPrefix]
	if k == nil then
		k = {}
		el[keyPrefix] = k
	end
	if k.x ~= x or k.y ~= y then
		k.x, k.y = x, y
		f.Position = UDim2.fromOffset(x, y)
	end
	if k.w ~= w or k.h ~= h then
		k.w, k.h = w, h
		f.Size = UDim2.fromOffset(w, h)
	end
	rot = rot or 0
	if k.r ~= rot then
		k.r = rot
		f.Rotation = rot
	end
end

local function setAnchorCenter(el, f, keyPrefix, on)
	local k = keyPrefix .. "_ac"
	if el[k] ~= on then
		el[k] = on
		f.AnchorPoint = on and Vector2.new(0.5, 0.5) or Vector2.zero
	end
end

local function setBg(el, f, keyPrefix, col)
	local k = keyPrefix .. "_bg"
	if el[k] ~= col then
		el[k] = col
		local c3, tr = unpackColor(col)
		f.BackgroundColor3 = c3
		f.BackgroundTransparency = tr
	end
end

local function setNoBg(el, f, keyPrefix)
	local k = keyPrefix .. "_bg"
	if el[k] ~= false then
		el[k] = false
		f.BackgroundTransparency = 1
	end
end

local function setCorner(el, f, radius, scale)
	local key = (scale and "s" or "o") .. radius
	if el.cornerKey == key then
		return
	end
	el.cornerKey = key
	if radius <= 0 then
		if el.Corner then
			el.Corner.Parent = nil
		end
		return
	end
	if el.Corner == nil then
		el.Corner = Instance.new("UICorner")
	end
	el.Corner.CornerRadius = scale and UDim.new(radius, 0) or UDim.new(0, radius)
	el.Corner.Parent = f
end

local function setStroke(el, f, col, thickness)
	if thickness == nil then
		if el.Stroke and el.strokeOn then
			el.strokeOn = false
			el.Stroke.Enabled = false
		end
		return
	end
	if el.Stroke == nil then
		el.Stroke = Instance.new("UIStroke")
		el.Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		pcall(function()
			el.Stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		end)
		el.Stroke.Parent = f
	end
	if not el.strokeOn then
		el.strokeOn = true
		el.Stroke.Enabled = true
	end
	if el.strokeCol ~= col then
		el.strokeCol = col
		local c3, tr = unpackColor(col)
		el.Stroke.Color = c3
		el.Stroke.Transparency = tr
	end
	if el.strokeT ~= thickness then
		el.strokeT = thickness
		el.Stroke.Thickness = thickness
	end
end

local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(gui)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 1
	root.Parent = gui
	local blockers = Instance.new("Frame")
	blockers.Name = "InputBlockers"
	blockers.BackgroundTransparency = 1
	blockers.Size = UDim2.fromScale(1, 1)
	blockers.ZIndex = 0
	blockers.Parent = gui
	local self = setmetatable({
		Gui = gui,
		Root = root,
		BlockerRoot = blockers,
		Pools = {},
		Used = {},
		Blockers = {},
		Z = 0,
	}, Renderer)
	return self
end

function Renderer:Acquire(kind)
	local pool = self.Pools[kind]
	if pool == nil then
		pool = {}
		self.Pools[kind] = pool
	end
	local n = (self.Used[kind] or 0) + 1
	self.Used[kind] = n
	local el = pool[n]
	if el == nil then
		el = newElement(self, kind)
		pool[n] = el
	end
	return el
end

local function clipBox(cx1, cy1, cx2, cy2, x1, y1, x2, y2)
	local ax1 = max(cx1, x1)
	local ay1 = max(cy1, y1)
	local ax2 = min(cx2, x2)
	local ay2 = min(cy2, y2)
	if ax2 <= ax1 or ay2 <= ay1 then
		return nil
	end
	local ix1, iy1 = floor(ax1), floor(ay1)
	return ix1, iy1, math.ceil(ax2) - ix1, math.ceil(ay2) - iy1
end

local function cornerPlan(flags, rounding, w, h)
	if rounding <= 0 then
		return 0
	end
	rounding = min(rounding, w * 0.5, h * 0.5)
	if rounding <= 0.5 then
		return 0
	end
	local corners = band(flags, ROUND_MASK)
	if btest(corners, ROUND_NONE) then
		return 0
	end
	if corners == 0 or corners == 0xF0 then
		return rounding, 0, 0, 0, 0
	end
	local tl, tr, bl, br = btest(corners, ROUND_TL), btest(corners, ROUND_TR), btest(corners, ROUND_BL), btest(corners, ROUND_BR)
	local r = rounding
	local eL = (not tl and not bl) and r or 0
	local eR = (not tr and not br) and r or 0
	local eT = (not tl and not tr) and r or 0
	local eB = (not bl and not br) and r or 0
	return r, eL, eT, eR, eB
end

function Renderer:DrawRect(buf, b, z, cx1, cy1, cx2, cy2, filled)
	local x1, y1, x2, y2 = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5]
	local col, rounding, flags = buf[b + 6], buf[b + 7], buf[b + 8]
	if band(rshift(col, 24), 0xFF) == 0 then
		return
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x1, y1, x2, y2)
	if rx == nil then
		return
	end
	local el = self:Acquire(filled and "RectFilled" or "Rect")
	el:SetContainer(rx, ry, rw, rh, z)
	local px1, py1 = round(x1), round(y1)
	local pw, ph = round(x2) - px1, round(y2) - py1
	local r, eL, eT, eR, eB = cornerPlan(flags or 0, rounding or 0, pw, ph)
	local f = el.Content
	if r > 0 then
		local ir = round(r)
		setFrameGeom(el, f, "g", px1 - rx - eL, py1 - ry - eT, pw + eL + eR, ph + eT + eB)
		setCorner(el, f, ir, false)
	else
		setFrameGeom(el, f, "g", px1 - rx, py1 - ry, pw, ph)
		setCorner(el, f, 0, false)
	end
	if filled then
		setBg(el, f, "g", col)
	else
		setNoBg(el, f, "g")
		setStroke(el, f, col, max(1, round(buf[b + 9] or 1)))
	end
end

function Renderer:DrawLine(buf, b, z, cx1, cy1, cx2, cy2)
	local x1, y1, x2, y2 = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5]
	local col, t = buf[b + 6], buf[b + 7] or 1
	if band(rshift(col, 24), 0xFF) == 0 then
		return
	end
	if t < 1 then
		t = 1
	end
	local el
	if y1 == y2 or x1 == x2 then
		local fx1, fy1, fx2, fy2
		if y1 == y2 then
			fx1, fx2 = min(x1, x2), max(x1, x2)
			fy1 = y1 - t * 0.5
			fy2 = fy1 + t
			if fx2 - fx1 < 1 then
				fx2 = fx1 + 1
			end
		else
			fy1, fy2 = min(y1, y2), max(y1, y2)
			fx1 = x1 - t * 0.5
			fx2 = fx1 + t
			if fy2 - fy1 < 1 then
				fy2 = fy1 + 1
			end
		end
		local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, fx1, fy1, fx2, fy2)
		if rx == nil then
			return
		end
		el = self:Acquire("Line")
		el:SetContainer(rx, ry, rw, rh, z)
		local f = el.Content
		setAnchorCenter(el, f, "g", false)
		setFrameGeom(el, f, "g", round(fx1) - rx, round(fy1) - ry, max(1, round(fx2 - fx1)), max(1, round(fy2 - fy1)), 0)
		setBg(el, f, "g", col)
		return
	end
	local dx, dy = x2 - x1, y2 - y1
	local len = sqrt(dx * dx + dy * dy)
	local pad = t + 1
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, min(x1, x2) - pad, min(y1, y2) - pad, max(x1, x2) + pad + 1, max(y1, y2) + pad + 1)
	if rx == nil then
		return
	end
	el = self:Acquire("Line")
	el:SetContainer(rx, ry, rw, rh, z)
	local f = el.Content
	setAnchorCenter(el, f, "g", true)
	local mx, my = (x1 + x2) * 0.5, (y1 + y2) * 0.5
	setFrameGeom(el, f, "g", round(mx) - rx, round(my) - ry, round(len), max(1, round(t)), deg(atan2(dy, dx)))
	setBg(el, f, "g", col)
end

local function rightTriangle(el, f, grad, keyPrefix, dxp, dyp, ux, uy, w, vx, vy, h, rx, ry, col)
	local cxp = dxp + ux * w * 0.5 + vx * h * 0.5
	local cyp = dyp + uy * w * 0.5 + vy * h * 0.5
	setAnchorCenter(el, f, keyPrefix, true)
	local iw, ih = max(1, round(w)), max(1, round(h))
	setFrameGeom(el, f, keyPrefix, round(cxp) - rx, round(cyp) - ry, iw, ih, deg(atan2(uy, ux)))
	local gk = keyPrefix .. "_grad"
	local diag = sqrt(iw * iw + ih * ih)
	local key = iw .. "," .. ih
	if el[gk] ~= key then
		el[gk] = key
		grad.Rotation = deg(atan2(iw, ih))
		local span = 2 * iw * ih / diag
		local e = min(0.49, 0.5 / max(span, 1))
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5 - e, 0),
			NumberSequenceKeypoint.new(0.5 + e, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	local ck = keyPrefix .. "_col"
	if el[ck] ~= col then
		el[ck] = col
		local c3, tr = unpackColor(col)
		f.BackgroundColor3 = c3
		f.BackgroundTransparency = tr
	end
end

local function hideFrame(el, f, keyPrefix)
	local k = keyPrefix .. "_vis"
	if el[k] ~= false then
		el[k] = false
		f.Visible = false
	end
end

local function showFrame(el, f, keyPrefix)
	local k = keyPrefix .. "_vis"
	if el[k] == false then
		el[k] = true
		f.Visible = true
	end
end

function Renderer:FillTriangle(z, cx1, cy1, cx2, cy2, ax, ay, bx, by, qx, qy, col)
	if band(rshift(col, 24), 0xFF) == 0 then
		return
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, min(ax, bx, qx) - 1, min(ay, by, qy) - 1, max(ax, bx, qx) + 1, max(ay, by, qy) + 1)
	if rx == nil then
		return
	end
	local lab = (bx - ax) ^ 2 + (by - ay) ^ 2
	local lbc = (qx - bx) ^ 2 + (qy - by) ^ 2
	local lca = (ax - qx) ^ 2 + (ay - qy) ^ 2
	if lbc > lab and lbc >= lca then
		ax, ay, bx, by, qx, qy = bx, by, qx, qy, ax, ay
		lab = lbc
	elseif lca > lab and lca > lbc then
		ax, ay, bx, by, qx, qy = qx, qy, ax, ay, bx, by
		lab = lca
	end
	if lab < 1e-6 then
		return
	end
	local L = sqrt(lab)
	local ex, ey = (bx - ax) / L, (by - ay) / L
	local t = (qx - ax) * ex + (qy - ay) * ey
	local dxp, dyp = ax + ex * t, ay + ey * t
	local hx, hy = qx - dxp, qy - dyp
	local h = sqrt(hx * hx + hy * hy)
	if h < 1e-3 then
		return
	end
	local vx, vy = hx / h, hy / h
	local el = self:Acquire("Tri")
	el:SetContainer(rx, ry, rw, rh, z)
	local parts = {
		{ el.Content, el.Grad, "a", -ex, -ey, t },
		{ el.Content2, el.Grad2, "b", ex, ey, L - t },
	}
	for _, p in parts do
		local f, grad, kp, ux, uy, w = p[1], p[2], p[3], p[4], p[5], p[6]
		if w < 0.25 then
			hideFrame(el, f, kp)
		else
			showFrame(el, f, kp)
			local px, py, pw, ph = vx, vy, h, w
			local cross = ux * vy - uy * vx
			if cross > 0 then
				rightTriangle(el, f, grad, kp, dxp - rx, dyp - ry, ux, uy, w, vx, vy, h, 0, 0, col)
			else
				rightTriangle(el, f, grad, kp, dxp - rx, dyp - ry, px, py, pw, ux, uy, ph, 0, 0, col)
			end
		end
	end
end

function Renderer:DrawCircle(buf, b, z, cx1, cy1, cx2, cy2, filled)
	local cx, cy, r, col = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5]
	if band(rshift(col, 24), 0xFF) == 0 or r <= 0 then
		return
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)
	if rx == nil then
		return
	end
	local el = self:Acquire(filled and "CircleFilled" or "Circle")
	el:SetContainer(rx, ry, rw, rh, z)
	local f = el.Content
	local d = max(1, round(r * 2))
	setFrameGeom(el, f, "g", round(cx - d * 0.5) - rx, round(cy - d * 0.5) - ry, d, d)
	setCorner(el, f, 0.5, true)
	if filled then
		setBg(el, f, "g", col)
	else
		setNoBg(el, f, "g")
		setStroke(el, f, col, max(1, round(buf[b + 6] or 1)))
	end
end

local function textWidth(str, advance)
	local n = utf8.len(str) or #str
	return n * advance
end

function Renderer:DrawText(buf, b, z, cx1, cy1, cx2, cy2)
	local x, y, col, str, size, font = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5], buf[b + 6], buf[b + 7]
	local fcx1, fcy1, fcx2, fcy2, angle = buf[b + 8], buf[b + 9], buf[b + 10], buf[b + 11], buf[b + 12]
	if band(rshift(col, 24), 0xFF) == 0 or str == nil or str == "" then
		return
	end
	if string.find(str, "\t", 1, true) then
		str = string.gsub(str, "\t", "    ")
	end
	local isize = max(1, round(size))
	local advance = self.MeasureAdvance and self.MeasureAdvance(isize) or isize * 7 / 13
	local w = textWidth(str, advance)
	local h = isize
	if fcx1 and fcx2 and fcx2 > fcx1 then
		cx1, cy1, cx2, cy2 = max(cx1, fcx1), max(cy1, fcy1), min(cx2, fcx2), min(cy2, fcy2)
	end
	local el
	if angle and angle ~= 0 then
		local c, s = math.cos(angle), math.sin(angle)
		local px = { x, x + w * c, x - h * s, x + w * c - h * s }
		local py = { y, y + w * s, y + h * c, y + w * s + h * c }
		local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, min(px[1], px[2], px[3], px[4]), min(py[1], py[2], py[3], py[4]), max(px[1], px[2], px[3], px[4]), max(py[1], py[2], py[3], py[4]))
		if rx == nil then
			return
		end
		el = self:Acquire("Text")
		el:SetContainer(rx, ry, rw, rh, z)
		local mx = x + (w * c - h * s) * 0.5
		local my = y + (w * s + h * c) * 0.5
		setAnchorCenter(el, el.Content, "g", true)
		setFrameGeom(el, el.Content, "g", round(mx) - rx, round(my) - ry, math.ceil(w), h, deg(angle))
	else
		local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x, y, x + w + 1, y + h)
		if rx == nil then
			return
		end
		el = self:Acquire("Text")
		el:SetContainer(rx, ry, rw, rh, z)
		setAnchorCenter(el, el.Content, "g", false)
		setFrameGeom(el, el.Content, "g", round(x) - rx, round(y) - ry, math.ceil(w) + 2, h, 0)
	end
	local t = el.Content
	if el.str ~= str then
		el.str = str
		t.Text = str
	end
	if el.size ~= isize then
		el.size = isize
		t.TextSize = isize
	end
	if el.col ~= col then
		el.col = col
		local c3, tr = unpackColor(col)
		t.TextColor3 = c3
		t.TextTransparency = tr
	end
	local rf = font and font.RobloxFontFace
	if rf and el.font ~= rf then
		el.font = rf
		t.FontFace = rf
	end
end

function Renderer:DrawImage(buf, b, z, cx1, cy1, cx2, cy2)
	local x1, y1, x2, y2 = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5]
	local u0, v0, u1, v1 = buf[b + 6], buf[b + 7], buf[b + 8], buf[b + 9]
	local col, tex, rounding = buf[b + 10], buf[b + 11], buf[b + 12] or 0
	if tex == nil or band(rshift(col, 24), 0xFF) == 0 then
		return
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x1, y1, x2, y2)
	if rx == nil then
		return
	end
	local el = self:Acquire("Image")
	el:SetContainer(rx, ry, rw, rh, z)
	local im = el.Content
	local px1, py1 = round(x1), round(y1)
	setFrameGeom(el, im, "g", px1 - rx, py1 - ry, round(x2) - px1, round(y2) - py1)
	local image, texSize
	if type(tex) == "table" then
		image, texSize = tex.Image, tex.Size
	else
		image = tex
	end
	if el.image ~= image then
		el.image = image
		im.Image = image
	end
	local rectKey
	if texSize and (u0 ~= 0 or v0 ~= 0 or u1 ~= 1 or v1 ~= 1) then
		rectKey = u0 .. "," .. v0 .. "," .. u1 .. "," .. v1
	end
	if el.rectKey ~= rectKey then
		el.rectKey = rectKey
		if rectKey then
			im.ImageRectOffset = Vector2.new(min(u0, u1) * texSize.X, min(v0, v1) * texSize.Y)
			im.ImageRectSize = Vector2.new(abs(u1 - u0) * texSize.X, abs(v1 - v0) * texSize.Y)
		else
			im.ImageRectOffset = Vector2.zero
			im.ImageRectSize = Vector2.zero
		end
	end
	if el.col ~= col then
		el.col = col
		local c3, tr = unpackColor(col)
		im.ImageColor3 = c3
		im.ImageTransparency = tr
	end
	setCorner(el, im, round(rounding), false)
end

local function lerpCol(a, b2)
	local c1, t1 = unpackColor(a)
	local c2, t2 = unpackColor(b2)
	return c1, t1, c2, t2
end

function Renderer:DrawRectMulti(buf, b, z, cx1, cy1, cx2, cy2)
	local x1, y1, x2, y2 = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5]
	local ul, ur, br, bl = buf[b + 6], buf[b + 7], buf[b + 8], buf[b + 9]
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x1, y1, x2, y2)
	if rx == nil then
		return
	end
	local el = self:Acquire("RectMulti")
	el:SetContainer(rx, ry, rw, rh, z)
	local f = el.Content
	local px1, py1 = round(x1), round(y1)
	setFrameGeom(el, f, "g", px1 - rx, py1 - ry, round(x2) - px1, round(y2) - py1)
	local key = ul .. "," .. ur .. "," .. br .. "," .. bl
	if el.gkey == key then
		return
	end
	el.gkey = key
	local rot, ca, cb
	if ul == ur and bl == br then
		rot, ca, cb = 90, ul, bl
	elseif ul == bl and ur == br then
		rot, ca, cb = 0, ul, ur
	else
		rot, ca, cb = 0, ul, br
	end
	local c1, t1, c2, t2 = lerpCol(ca, cb)
	local g = el.Grad
	g.Rotation = rot
	g.Color = ColorSequence.new(c1, c2)
	g.Transparency = NumberSequence.new(t1, t2)
end

local function lerpColorAt(l1, l2, l3, c1, c2, c3)
	local function ch(c, sh)
		return band(rshift(c, sh), 0xFF)
	end
	local r = ch(c1, 0) * l1 + ch(c2, 0) * l2 + ch(c3, 0) * l3
	local gg = ch(c1, 8) * l1 + ch(c2, 8) * l2 + ch(c3, 8) * l3
	local bb = ch(c1, 16) * l1 + ch(c2, 16) * l2 + ch(c3, 16) * l3
	local a = ch(c1, 24) * l1 + ch(c2, 24) * l2 + ch(c3, 24) * l3
	return Color3.fromRGB(floor(r + 0.5), floor(gg + 0.5), floor(bb + 0.5)), 1 - a / 255
end

function Renderer:DrawTriangleMultiColorStrips(buf, b, z, cx1, cy1, cx2, cy2)
	local ax, ay, bx, by, qx, qy = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5], buf[b + 6], buf[b + 7]
	local c1, c2, c3 = buf[b + 8], buf[b + 9], buf[b + 10]
	local x1, y1 = floor(min(ax, bx, qx)), floor(min(ay, by, qy))
	local x2, y2 = math.ceil(max(ax, bx, qx)), math.ceil(max(ay, by, qy))
	local h = y2 - y1
	if h < 1 or x2 - x1 < 1 or h > 2048 then
		return false
	end
	local det = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
	if abs(det) < 1e-6 then
		return true
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x1, y1, x2, y2)
	if rx == nil then
		return true
	end
	local el = self:Acquire("TriStrips")
	el:SetContainer(rx, ry, rw, rh, z)
	local key = string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d,%d", ax - rx, ay - ry, bx - rx, by - ry, qx - rx, qy - ry, c1, c2, c3, rx, ry)
	if el.triKey == key then
		return true
	end
	el.triKey = key
	el.Strips = el.Strips or {}
	local strips = el.Strips
	local inv = 1 / det
	local edges = { { ax, ay, bx, by }, { bx, by, qx, qy }, { qx, qy, ax, ay } }
	local n = 0
	for py = y1, y2 - 1 do
		local y = py + 0.5
		local xl, xr = math.huge, -math.huge
		for _, e in edges do
			local ex1, ey1, ex2, ey2 = e[1], e[2], e[3], e[4]
			if (y >= ey1 and y <= ey2) or (y >= ey2 and y <= ey1) then
				if ey1 == ey2 then
					xl, xr = min(xl, ex1, ex2), max(xr, ex1, ex2)
				else
					local x = ex1 + (y - ey1) * (ex2 - ex1) / (ey2 - ey1)
					xl, xr = min(xl, x), max(xr, x)
				end
			end
		end
		if xr > xl then
			n += 1
			local f = strips[n]
			if f == nil then
				f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.BackgroundColor3 = Color3.new(1, 1, 1)
				local gr = Instance.new("UIGradient")
				gr.Parent = f
				f.Parent = el.Container
				strips[n] = f
			end
			f.Visible = true
			local ixl, ixr = floor(xl + 0.5), floor(xr + 0.5)
			if ixr <= ixl then
				ixr = ixl + 1
			end
			f.Position = UDim2.fromOffset(ixl - rx, py - ry)
			f.Size = UDim2.fromOffset(ixr - ixl, 1)
			local function bary(x)
				local l1 = ((by - qy) * (x - qx) + (qx - bx) * (y - qy)) * inv
				local l2 = ((qy - ay) * (x - qx) + (ax - qx) * (y - qy)) * inv
				l1, l2 = max(0, min(1, l1)), max(0, min(1, l2))
				local l3 = max(0, 1 - l1 - l2)
				local sum = l1 + l2 + l3
				return l1 / sum, l2 / sum, l3 / sum
			end
			local la1, la2, la3 = bary(ixl + 0.5)
			local lb1, lb2, lb3 = bary(ixr - 0.5)
			local ca, ta = lerpColorAt(la1, la2, la3, c1, c2, c3)
			local cb, tb = lerpColorAt(lb1, lb2, lb3, c1, c2, c3)
			local gr = f:FindFirstChildOfClass("UIGradient")
			gr.Color = ColorSequence.new(ca, cb)
			gr.Transparency = NumberSequence.new(ta, tb)
		end
	end
	for i = n + 1, #strips do
		strips[i].Visible = false
	end
	return true
end

local AssetService = game:GetService("AssetService")
local editableAllowed = nil
local editableLastError = nil

local function createEditable(w, h)
	if editableAllowed == false then
		return nil
	end
	local ok, img = pcall(AssetService.CreateEditableImage, AssetService, { Size = Vector2.new(w, h) })
	if ok and img ~= nil then
		editableAllowed = true
		return img
	end
	editableLastError = tostring(img)
	if editableAllowed == nil then
		editableAllowed = false
	end
	return nil
end

function Renderer:DrawRaster(z, cx1, cy1, cx2, cy2, x1, y1, w, h, key, rasterFn)
	if editableAllowed == false or w < 1 or h < 1 or w > 1024 or h > 1024 then
		return false
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x1, y1, x1 + w, y1 + h)
	if rx == nil then
		return true
	end
	local el = self:Acquire("Raster")
	el:SetContainer(rx, ry, rw, rh, z)
	setFrameGeom(el, el.Content, "g", x1 - rx, y1 - ry, w, h)
	if el.rasterKey ~= key then
		if el.Editable == nil or el.EditW ~= w or el.EditH ~= h then
			local img = createEditable(w, h)
			if img == nil then
				el.Visible = false
				el.Container.Visible = false
				return false
			end
			if el.Editable ~= nil then
				el.Editable:Destroy()
			end
			el.Editable, el.EditW, el.EditH = img, w, h
			el.Content.ImageContent = Content.fromObject(img)
		end
		el.rasterKey = key
		el.Editable:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), rasterFn(w, h))
	end
	return true
end

local function chan(c, sh)
	return band(rshift(c, sh), 0xFF)
end

function Renderer:DrawTriangleMultiColor(buf, b, z, cx1, cy1, cx2, cy2)
	local ax, ay, bx, by, qx, qy = buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5], buf[b + 6], buf[b + 7]
	local c1, c2, c3 = buf[b + 8], buf[b + 9], buf[b + 10]
	local x1, y1 = floor(min(ax, bx, qx)) - 1, floor(min(ay, by, qy)) - 1
	local w, h = math.ceil(max(ax, bx, qx)) + 1 - x1, math.ceil(max(ay, by, qy)) + 1 - y1
	local det = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
	if abs(det) < 1e-6 then
		return true
	end
	local key = string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d", ax - x1, ay - y1, bx - x1, by - y1, qx - x1, qy - y1, c1, c2, c3)
	local drawn = self:DrawRaster(z, cx1, cy1, cx2, cy2, x1, y1, w, h, key, function(iw, ih)
		local data = buffer.create(iw * ih * 4)
		local inv = 1 / det
		local area2 = abs(det)
		local ha = area2 / sqrt((bx - qx) ^ 2 + (by - qy) ^ 2)
		local hb = area2 / sqrt((qx - ax) ^ 2 + (qy - ay) ^ 2)
		local hc = area2 / sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
		local r1, g1, b1, a1 = chan(c1, 0), chan(c1, 8), chan(c1, 16), chan(c1, 24)
		local r2, g2, b2, a2 = chan(c2, 0), chan(c2, 8), chan(c2, 16), chan(c2, 24)
		local r3, g3, b3, a3 = chan(c3, 0), chan(c3, 8), chan(c3, 16), chan(c3, 24)
		for py = 0, ih - 1 do
			local y = y1 + py + 0.5
			for px = 0, iw - 1 do
				local x = x1 + px + 0.5
				local l1 = ((by - qy) * (x - qx) + (qx - bx) * (y - qy)) * inv
				local l2 = ((qy - ay) * (x - qx) + (ax - qx) * (y - qy)) * inv
				local l3 = 1 - l1 - l2
				local cov = min(l1 * ha, l2 * hb, l3 * hc) + 0.5
				if cov > 0 then
					if cov > 1 then
						cov = 1
					end
					l1, l2, l3 = max(l1, 0), max(l2, 0), max(l3, 0)
					local sum = l1 + l2 + l3
					l1, l2, l3 = l1 / sum, l2 / sum, l3 / sum
					local o = (py * iw + px) * 4
					buffer.writeu8(data, o, floor(r1 * l1 + r2 * l2 + r3 * l3 + 0.5))
					buffer.writeu8(data, o + 1, floor(g1 * l1 + g2 * l2 + g3 * l3 + 0.5))
					buffer.writeu8(data, o + 2, floor(b1 * l1 + b2 * l2 + b3 * l3 + 0.5))
					buffer.writeu8(data, o + 3, floor((a1 * l1 + a2 * l2 + a3 * l3) * cov + 0.5))
				end
			end
		end
		return data
	end)
	if drawn then
		return true
	end
	return self:DrawTriangleMultiColorStrips(buf, b, z, cx1, cy1, cx2, cy2)
end

function Renderer:TryDrawPolyline(buf, p, last, z, cx1, cy1, cx2, cy2)
	if editableAllowed == false then
		return 0
	end
	local b0 = p * STRIDE
	local t = buf[b0 + 7]
	local n = 1
	local ex, ey = buf[b0 + 4], buf[b0 + 5]
	while p + n <= last do
		local b = (p + n) * STRIDE
		if buf[b + 1] ~= PrimKind.Line or buf[b + 7] ~= t or abs(buf[b + 2] - ex) > 0.01 or abs(buf[b + 3] - ey) > 0.01 then
			break
		end
		ex, ey = buf[b + 4], buf[b + 5]
		n += 1
	end
	if n < 2 then
		return 0
	end
	local hw = t * 0.5
	local mnx, mny, mxx, mxy = math.huge, math.huge, -math.huge, -math.huge
	local parts = table.create(n * 5)
	for i = 0, n - 1 do
		local b = (p + i) * STRIDE
		mnx = min(mnx, buf[b + 2], buf[b + 4])
		mny = min(mny, buf[b + 3], buf[b + 5])
		mxx = max(mxx, buf[b + 2], buf[b + 4])
		mxy = max(mxy, buf[b + 3], buf[b + 5])
	end
	local x1, y1 = floor(mnx - hw) - 1, floor(mny - hw) - 1
	local w, h = math.ceil(mxx + hw) + 1 - x1, math.ceil(mxy + hw) + 1 - y1
	for i = 0, n - 1 do
		local b = (p + i) * STRIDE
		parts[#parts + 1] = string.format("%.2f,%.2f,%.2f,%.2f,%d", buf[b + 2] - x1, buf[b + 3] - y1, buf[b + 4] - x1, buf[b + 5] - y1, buf[b + 6])
	end
	parts[#parts + 1] = tostring(t)
	local key = table.concat(parts, ";")
	local drawn = self:DrawRaster(z, cx1, cy1, cx2, cy2, x1, y1, w, h, key, function(iw, ih)
		local data = buffer.create(iw * ih * 4)
		local covs = buffer.create(iw * ih * 4)
		local bl = (p + n - 1) * STRIDE
		local closed = abs(buf[bl + 4] - buf[b0 + 2]) < 0.01 and abs(buf[bl + 5] - buf[b0 + 3]) < 0.01
		for i = 0, n - 1 do
			local capStart = i == 0 and not closed
			local capEnd = i == n - 1 and not closed
			local b = (p + i) * STRIDE
			local sx, sy, tx, ty, col = buf[b + 2] - x1, buf[b + 3] - y1, buf[b + 4] - x1, buf[b + 5] - y1, buf[b + 6]
			local dx, dy = tx - sx, ty - sy
			local len2 = dx * dx + dy * dy
			local cr, cg, cb, ca = chan(col, 0), chan(col, 8), chan(col, 16), chan(col, 24)
			local px0 = max(0, floor(min(sx, tx) - hw - 1))
			local px1 = min(iw - 1, math.ceil(max(sx, tx) + hw + 1))
			local py0 = max(0, floor(min(sy, ty) - hw - 1))
			local py1 = min(ih - 1, math.ceil(max(sy, ty) + hw + 1))
			for py = py0, py1 do
				local y = py + 0.5
				for px = px0, px1 do
					local x = px + 0.5
					local u = if len2 > 0 then ((x - sx) * dx + (y - sy) * dy) / len2 else 0
					if (capStart and u < 0) or (capEnd and u > 1) then
						continue
					end
					if u < 0 then
						u = 0
					elseif u > 1 then
						u = 1
					end
					local qx, qy = sx + dx * u - x, sy + dy * u - y
					local cov = hw - sqrt(qx * qx + qy * qy) + 0.5
					if cov > 0 then
						if cov > 1 then
							cov = 1
						end
						local idx = (py * iw + px) * 4
						if cov > buffer.readf32(covs, idx) then
							buffer.writef32(covs, idx, cov)
							buffer.writeu8(data, idx, cr)
							buffer.writeu8(data, idx + 1, cg)
							buffer.writeu8(data, idx + 2, cb)
							buffer.writeu8(data, idx + 3, floor(ca * cov + 0.5))
						end
					end
				end
			end
		end
		return data
	end)
	if drawn then
		return n
	end
	return 0
end

local maskCache = {}
local maskCacheCount = 0
local maskGen = 0
local MASK_CACHE_MAX = 512

local function getPolygonMask(key, w, h, pts)
	local entry = maskCache[key]
	if entry ~= nil then
		return entry
	end
	local img = createEditable(w, h)
	if img == nil then
		return nil
	end
	if maskCacheCount >= MASK_CACHE_MAX then
		for _, e in maskCache do
			e.Image:Destroy()
		end
		table.clear(maskCache)
		maskCacheCount = 0
		maskGen += 1
	end
	local n = #pts // 2
	local area = 0
	for i = 0, n - 1 do
		local j = (i + 1) % n
		area += pts[i * 2 + 1] * pts[j * 2 + 2] - pts[j * 2 + 1] * pts[i * 2 + 2]
	end
	local sign = if area < 0 then -1 else 1
	local edges = {}
	for i = 0, n - 1 do
		local j = (i + 1) % n
		local ex, ey = pts[i * 2 + 1], pts[i * 2 + 2]
		local dx, dy = pts[j * 2 + 1] - ex, pts[j * 2 + 2] - ey
		if dx * dx + dy * dy > 1e-12 then
			table.insert(edges, { ex, ey, -dy * sign, dx * sign })
		end
	end
	local data = buffer.create(w * h * 4)
	local SS = 4
	local step = 1 / SS
	local full = SS * SS
	for py = 0, h - 1 do
		for px = 0, w - 1 do
			local hits = 0
			for sy = 0, SS - 1 do
				local y = py + (sy + 0.5) * step
				for sx = 0, SS - 1 do
					local x = px + (sx + 0.5) * step
					local inside = true
					for _, e in edges do
						if (x - e[1]) * e[3] + (y - e[2]) * e[4] < 0 then
							inside = false
							break
						end
					end
					if inside then
						hits += 1
					end
				end
			end
			if hits > 0 then
				local o = (py * w + px) * 4
				buffer.writeu8(data, o, 255)
				buffer.writeu8(data, o + 1, 255)
				buffer.writeu8(data, o + 2, 255)
				buffer.writeu8(data, o + 3, floor(hits * 255 / full + 0.5))
			end
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), data)
	entry = { Image = img, Content = Content.fromObject(img) }
	maskCache[key] = entry
	maskCacheCount += 1
	return entry
end

local function sameXY(ax, ay, bx, by)
	return abs(ax - bx) < 0.001 and abs(ay - by) < 0.001
end

function Renderer:TryDrawFilledPolygon(buf, p, last, z, cx1, cy1, cx2, cy2)
	if editableAllowed == false then
		return 0
	end
	local b0 = p * STRIDE
	local col = buf[b0 + 8]
	if band(rshift(col, 24), 0xFF) == 0 then
		return 1
	end
	local pts = { buf[b0 + 2], buf[b0 + 3], buf[b0 + 4], buf[b0 + 5], buf[b0 + 6], buf[b0 + 7] }
	local n = 1
	while p + n <= last and n < 128 do
		local b = (p + n) * STRIDE
		if buf[b + 1] ~= PrimKind.TriangleFilled or buf[b + 8] ~= col then
			break
		end
		local lx, ly = pts[#pts - 1], pts[#pts]
		if not sameXY(buf[b + 2], buf[b + 3], pts[1], pts[2]) or not sameXY(buf[b + 4], buf[b + 5], lx, ly) then
			break
		end
		table.insert(pts, buf[b + 6])
		table.insert(pts, buf[b + 7])
		n += 1
	end
	local mnx, mny, mxx, mxy = math.huge, math.huge, -math.huge, -math.huge
	for i = 1, #pts, 2 do
		mnx, mxx = min(mnx, pts[i]), max(mxx, pts[i])
		mny, mxy = min(mny, pts[i + 1]), max(mxy, pts[i + 1])
	end
	local x1, y1 = floor(mnx), floor(mny)
	local x2, y2 = math.ceil(mxx), math.ceil(mxy)
	local w, h = x2 - x1, y2 - y1
	if w < 1 or h < 1 or w > 256 or h > 256 then
		return 0
	end
	local rel = table.create(#pts)
	local parts = table.create(#pts + 2)
	parts[1], parts[2] = w, h
	for i = 1, #pts, 2 do
		local rx_ = floor((pts[i] - x1) * 8 + 0.5) / 8
		local ry_ = floor((pts[i + 1] - y1) * 8 + 0.5) / 8
		rel[i], rel[i + 1] = rx_, ry_
		parts[#parts + 1] = rx_
		parts[#parts + 1] = ry_
	end
	local key = table.concat(parts, ",")
	local mask = getPolygonMask(key, w, h, rel)
	if mask == nil then
		return 0
	end
	local rx, ry, rw, rh = clipBox(cx1, cy1, cx2, cy2, x1, y1, x2, y2)
	if rx == nil then
		return n
	end
	local el = self:Acquire("TriMask")
	el:SetContainer(rx, ry, rw, rh, z)
	local im = el.Content
	setFrameGeom(el, im, "g", x1 - rx, y1 - ry, w, h)
	if el.maskKey ~= key or el.maskGen ~= maskGen then
		el.maskKey, el.maskGen = key, maskGen
		im.ImageContent = mask.Content
	end
	if el.col ~= col then
		el.col = col
		local c3, tr = unpackColor(col)
		im.ImageColor3 = c3
		im.ImageTransparency = tr
	end
	return n
end

function Renderer:DrawPrim(buf, b, z, cx1, cy1, cx2, cy2)
	local kind = buf[b + 1]
	if kind == PrimKind.RectFilled then
		self:DrawRect(buf, b, z, cx1, cy1, cx2, cy2, true)
	elseif kind == PrimKind.Text then
		self:DrawText(buf, b, z, cx1, cy1, cx2, cy2)
	elseif kind == PrimKind.Rect then
		self:DrawRect(buf, b, z, cx1, cy1, cx2, cy2, false)
	elseif kind == PrimKind.Line then
		self:DrawLine(buf, b, z, cx1, cy1, cx2, cy2)
	elseif kind == PrimKind.TriangleFilled then
		self:FillTriangle(z, cx1, cy1, cx2, cy2, buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5], buf[b + 6], buf[b + 7], buf[b + 8])
	elseif kind == PrimKind.TriangleMultiColor then
		if not self:DrawTriangleMultiColor(buf, b, z, cx1, cy1, cx2, cy2) then
			local c1, c2, c3 = buf[b + 8], buf[b + 9], buf[b + 10]
			local avg = 0
			for s = 0, 24, 8 do
				local v = floor((band(rshift(c1, s), 0xFF) + band(rshift(c2, s), 0xFF) + band(rshift(c3, s), 0xFF)) / 3 + 0.5)
				avg = bit32.bor(avg, bit32.lshift(v, s))
			end
			self:FillTriangle(z, cx1, cy1, cx2, cy2, buf[b + 2], buf[b + 3], buf[b + 4], buf[b + 5], buf[b + 6], buf[b + 7], avg)
		end
	elseif kind == PrimKind.CircleFilled then
		self:DrawCircle(buf, b, z, cx1, cy1, cx2, cy2, true)
	elseif kind == PrimKind.Circle then
		self:DrawCircle(buf, b, z, cx1, cy1, cx2, cy2, false)
	elseif kind == PrimKind.Image then
		self:DrawImage(buf, b, z, cx1, cy1, cx2, cy2)
	elseif kind == PrimKind.RectMultiColor then
		self:DrawRectMulti(buf, b, z, cx1, cy1, cx2, cy2)
	end
end

function Renderer:UpdateBlockers(g)
	local n = 0
	if g ~= nil then
		for i = 1, g.Windows.Size do
			local w = g.Windows[i]
			if w.Active and not w.Hidden and w.ParentWindow == nil then
				n += 1
				local f = self.Blockers[n]
				if f == nil then
					f = Instance.new("Frame")
					f.BackgroundTransparency = 1
					f.BorderSizePixel = 0
					f.Active = true
					f.Parent = self.BlockerRoot
					self.Blockers[n] = f
				end
				f.Position = UDim2.fromOffset(w.Pos.x, w.Pos.y)
				f.Size = UDim2.fromOffset(w.Size.x, w.Size.y)
				f.Visible = true
			end
		end
	end
	for i = n + 1, #self.Blockers do
		self.Blockers[i].Visible = false
	end
end

function Renderer:Render(drawData, g)
	table.clear(self.Used)
	local z = 0
	if drawData ~= nil and drawData.Valid then
		local lists = drawData.CmdLists
		for li = 1, lists.Size do
			local dl = lists[li]
			local buf = dl.PrimBuffer
			local cmds = dl.CmdBuffer
			for ci = 1, cmds.Size do
				local cmd = cmds[ci]
				if cmd.UserCallback == nil and cmd.ElemCount > 0 then
					local clip = cmd.ClipRect
					local cx1, cy1, cx2, cy2 = clip.x, clip.y, clip.z, clip.w
					local first = cmd.IdxOffset
					local last = first + cmd.ElemCount - 1
					local p = first
					while p <= last do
						z += 1
						local b = p * STRIDE
						local consumed = 0
						local k = buf[b + 1]
						if k == PrimKind.Line and buf[b + 7] >= 2.5 and p < last then
							consumed = self:TryDrawPolyline(buf, p, last, z, cx1, cy1, cx2, cy2)
						elseif k == PrimKind.TriangleFilled then
							consumed = self:TryDrawFilledPolygon(buf, p, last, z, cx1, cy1, cx2, cy2)
						end
						if consumed == 0 then
							self:DrawPrim(buf, b, z, cx1, cy1, cx2, cy2)
							consumed = 1
						end
						p += consumed
					end
				end
			end
		end
	end
	for kind, pool in self.Pools do
		local used = self.Used[kind] or 0
		for i = used + 1, #pool do
			local el = pool[i]
			if el.Visible then
				el.Visible = false
				el.Container.Visible = false
			end
		end
	end
	self:UpdateBlockers(g)
	if editableLastError ~= self.ReportedEditableError then
		self.ReportedEditableError = editableLastError
		self.Gui:SetAttribute("EditableImageError", editableLastError)
	end
end

function Renderer:Destroy()
	self.Root:Destroy()
	self.BlockerRoot:Destroy()
end

return Renderer
