--!native
local ImGui = require("./Namespace")

local Base = {}

local band, bor, bxor, bnot, lshift, rshift = bit32.band, bit32.bor, bit32.bxor, bit32.bnot, bit32.lshift, bit32.rshift
local vcreate, vmin, vmax = vector.create, vector.min, vector.max
local floor, ceil, mabs, sqrt, fmod = math.floor, math.ceil, math.abs, math.sqrt, math.fmod
local sbyte, ssub, schar, sfind, sformat, smatch = string.byte, string.sub, string.char, string.find, string.format, string.match

Base.IMGUI_VERSION = "1.93.1 WIP"
Base.IMGUI_VERSION_NUM = 19301

local FLT_MAX = 3.4028234663852886e+38
local IM_PI = 3.14159265358979323846
Base.FLT_MAX = FLT_MAX
Base.FLT_MIN = 1.1754943508222875e-38
Base.IM_PI = IM_PI
Base.INT_MAX = 2147483647
Base.INT_MIN = -2147483648
Base.IM_NEWLINE = "\n"
Base.IM_TABSIZE = 4
Base.IM_UNICODE_CODEPOINT_INVALID = 0xFFFD
Base.IM_UNICODE_CODEPOINT_MAX = 0x10FFFF
Base.IM_PRId64 = "lld"
Base.IM_PRIu64 = "llu"
Base.IM_PRIX64 = "llX"

local function ImTruncToInt(x)
	if x >= 0 then
		return floor(x)
	end
	return ceil(x)
end
Base.ImTruncToInt = ImTruncToInt

local PtrRegistry = setmetatable({}, { __mode = "k" })
local PtrNext = 0x10000
function Base.ImPtrToInt(v)
	if v == nil then
		return 0
	end
	local id = PtrRegistry[v]
	if id == nil then
		PtrNext += 16
		id = PtrNext
		PtrRegistry[v] = id
	end
	return id
end

local function ImVec2(x, y)
	return vcreate(x or 0, y or 0, 0)
end
Base.ImVec2 = ImVec2
local VEC2_ZERO = vcreate(0, 0, 0)

function Base.ImVec2i(x, y)
	return vcreate(ImTruncToInt(x or 0), ImTruncToInt(y or 0), 0)
end
function Base.ImVec2ih(x, y)
	if type(x) == "vector" then
		return vcreate(ImTruncToInt(x.x), ImTruncToInt(x.y), 0)
	end
	return vcreate(ImTruncToInt(x or 0), ImTruncToInt(y or 0), 0)
end

local ImVec4Meta = {}
local function ImVec4(x, y, z, w)
	return table.freeze(setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 0 }, ImVec4Meta))
end
Base.ImVec4 = ImVec4
Base.ImVec4Meta = ImVec4Meta
ImVec4Meta.__add = function(a, b)
	return ImVec4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
end
ImVec4Meta.__sub = function(a, b)
	return ImVec4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
end
ImVec4Meta.__mul = function(a, b)
	if type(a) == "number" then
		return ImVec4(a * b.x, a * b.y, a * b.z, a * b.w)
	elseif type(b) == "number" then
		return ImVec4(a.x * b, a.y * b, a.z * b, a.w * b)
	end
	return ImVec4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w)
end
ImVec4Meta.__div = function(a, b)
	if type(b) == "number" then
		return ImVec4(a.x / b, a.y / b, a.z / b, a.w / b)
	end
	return ImVec4(a.x / b.x, a.y / b.y, a.z / b.z, a.w / b.w)
end
ImVec4Meta.__unm = function(a)
	return ImVec4(-a.x, -a.y, -a.z, -a.w)
end
ImVec4Meta.__eq = function(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end
ImVec4Meta.__tostring = function(a)
	return sformat("ImVec4(%g, %g, %g, %g)", a.x, a.y, a.z, a.w)
end

local function ImClampNum(v, mn, mx)
	if v < mn then
		return mn
	elseif v > mx then
		return mx
	end
	return v
end

local function ImMin(a, b)
	if type(a) == "number" then
		return if a < b then a else b
	end
	return vmin(a, b)
end
local function ImMax(a, b)
	if type(a) == "number" then
		return if a >= b then a else b
	end
	return vmax(a, b)
end
local function ImClamp(v, mn, mx)
	if type(v) == "number" then
		return ImClampNum(v, mn, mx)
	end
	return vcreate(ImClampNum(v.x, mn.x, mx.x), ImClampNum(v.y, mn.y, mx.y), 0)
end
Base.ImMin = ImMin
Base.ImMax = ImMax
Base.ImClamp = ImClamp

function Base.ImLerp(a, b, t)
	local ta = type(a)
	if ta == "number" or ta == "vector" then
		return a + (b - a) * t
	end
	return ImVec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t)
end

function Base.ImSwap(a, b)
	return b, a
end

function Base.ImAddClampOverflow(a, b, mn, mx)
	if b < 0 and (a < mn - b) then
		return mn
	end
	if b > 0 and (a > mx - b) then
		return mx
	end
	return a + b
end

function Base.ImSubClampOverflow(a, b, mn, mx)
	if b > 0 and (a < mn + b) then
		return mn
	end
	if b < 0 and (a > mx + b) then
		return mx
	end
	return a - b
end

local function ImSaturate(f)
	if f < 0 then
		return 0
	elseif f > 1 then
		return 1
	end
	return f
end
Base.ImSaturate = ImSaturate

local function ImLengthSqr(v)
	if type(v) == "vector" then
		return v.x * v.x + v.y * v.y
	end
	return v.x * v.x + v.y * v.y + v.z * v.z + v.w * v.w
end
Base.ImLengthSqr = ImLengthSqr

local function ImRsqrt(x)
	return 1 / sqrt(x)
end
Base.ImRsqrt = ImRsqrt
Base.ImRsqrtPrecise = ImRsqrt

function Base.ImInvLength(v, fail_value)
	local d = v.x * v.x + v.y * v.y
	if d > 0 then
		return ImRsqrt(d)
	end
	return fail_value
end

local function ImTrunc(f)
	if type(f) == "number" then
		return ImTruncToInt(f)
	end
	return vcreate(ImTruncToInt(f.x), ImTruncToInt(f.y), 0)
end
Base.ImTrunc = ImTrunc

function Base.ImFloor(f)
	if type(f) == "number" then
		return floor(f)
	end
	return vector.floor(f)
end

Base.ImTrunc64 = ImTruncToInt
function Base.ImRoundPositive64(f)
	return ImTruncToInt(f + 0.5)
end
function Base.ImRoundSigned64(f)
	return ImTruncToInt(if f >= 0 then f + 0.5 else f - 0.5)
end
Base.ImRound64 = Base.ImRoundPositive64
function Base.ImCeilFast(f)
	local i = ImTruncToInt(f)
	return i + (if f > i then 1 else 0)
end
function Base.ImIsTruncated(x)
	return ImTruncToInt(x) == x
end
function Base.ImIsTruncated4(x, y, z, w)
	return ImTruncToInt(x) == x and ImTruncToInt(y) == y and ImTruncToInt(z) == z and ImTruncToInt(w) == w
end

function Base.ImModPositive(a, b)
	return fmod(a + b, b)
end

local function ImDot(a, b)
	return a.x * b.x + a.y * b.y
end
Base.ImDot = ImDot

function Base.ImRotate(v, cos_a, sin_a)
	return vcreate(v.x * cos_a - v.y * sin_a, v.x * sin_a + v.y * cos_a, 0)
end

function Base.ImLinearSweep(current, target, speed)
	if current < target then
		return ImMin(current + speed, target)
	end
	if current > target then
		return ImMax(current - speed, target)
	end
	return current
end

function Base.ImLinearRemapClamp(s0, s1, d0, d1, x)
	return ImSaturate((x - s0) / (s1 - s0)) * (d1 - d0) + d0
end

function Base.ImMul(lhs, rhs)
	return lhs * rhs
end

function Base.ImIsFloatAboveGuaranteedIntegerPrecision(f)
	return f <= -16777216 or f >= 16777216
end

function Base.ImExponentialMovingAverage(avg, sample, n)
	avg -= avg / n
	avg += sample / n
	return avg
end

function Base.ImAbs(x)
	if type(x) == "number" then
		return mabs(x)
	end
	return vector.abs(x)
end
Base.ImFabs = mabs

function Base.ImSign(x)
	if x < 0 then
		return -1
	elseif x > 0 then
		return 1
	end
	return 0
end

Base.ImPow = math.pow
Base.ImLog = math.log
Base.ImFmod = fmod
Base.ImCos = math.cos
Base.ImSin = math.sin
Base.ImAcos = math.acos
Base.ImAtan2 = math.atan2
Base.ImCeil = ceil
Base.ImSqrt = sqrt

function Base.ImIsPowerOfTwo(v)
	return v ~= 0 and band(v, v - 1) == 0
end

function Base.ImUpperPowerOfTwo(v)
	v -= 1
	v = bor(v, rshift(v, 1))
	v = bor(v, rshift(v, 2))
	v = bor(v, rshift(v, 4))
	v = bor(v, rshift(v, 8))
	v = bor(v, rshift(v, 16))
	v += 1
	return v
end

function Base.ImCountSetBits(v)
	local count = 0
	while v > 0 do
		v = band(v, v - 1)
		count += 1
	end
	return count
end

local IM_COL32_R_SHIFT, IM_COL32_G_SHIFT, IM_COL32_B_SHIFT, IM_COL32_A_SHIFT = 0, 8, 16, 24
Base.IM_COL32_R_SHIFT = IM_COL32_R_SHIFT
Base.IM_COL32_G_SHIFT = IM_COL32_G_SHIFT
Base.IM_COL32_B_SHIFT = IM_COL32_B_SHIFT
Base.IM_COL32_A_SHIFT = IM_COL32_A_SHIFT
Base.IM_COL32_A_MASK = 0xFF000000
local function IM_COL32(r, g, b, a)
	return bor(lshift(a, IM_COL32_A_SHIFT), lshift(b, IM_COL32_B_SHIFT), lshift(g, IM_COL32_G_SHIFT), lshift(r, IM_COL32_R_SHIFT))
end
Base.IM_COL32 = IM_COL32
Base.IM_COL32_WHITE = 0xFFFFFFFF
Base.IM_COL32_BLACK = 0xFF000000
Base.IM_COL32_BLACK_TRANS = 0

function Base.IM_F32_TO_INT8_UNBOUND(v)
	return ImTruncToInt(v * 255 + (if v >= 0 then 0.5 else -0.5))
end
local function IM_F32_TO_INT8_SAT(v)
	return ImTruncToInt(ImSaturate(v) * 255 + 0.5)
end
Base.IM_F32_TO_INT8_SAT = IM_F32_TO_INT8_SAT
Base.IM_TRUNC = ImTruncToInt
function Base.IM_ROUND(v)
	return ImTruncToInt(v + 0.5)
end
function Base.IM_MEMALIGN(off, align)
	return band(off + align - 1, bnot(align - 1))
end

local function IM_ROUNDUP_TO_EVEN(v)
	return ImTruncToInt((v + 1) / 2) * 2
end
Base.IM_ROUNDUP_TO_EVEN = IM_ROUNDUP_TO_EVEN
Base.IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN = 4
Base.IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX = 512
function Base.IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(rad, max_error)
	return ImClampNum(IM_ROUNDUP_TO_EVEN(ImTruncToInt(ceil(IM_PI / math.acos(1 - ImMin(max_error, rad) / rad)))), 4, 512)
end
function Base.IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_R(n, max_error)
	return max_error / (1 - math.cos(IM_PI / ImMax(n, IM_PI)))
end
function Base.IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_ERROR(n, rad)
	return (1 - math.cos(IM_PI / ImMax(n, IM_PI))) / rad
end
Base.IM_DRAWLIST_ARCFAST_TABLE_SIZE = 48
Base.IM_DRAWLIST_ARCFAST_SAMPLE_MAX = 48
Base.IM_DRAWLIST_TEX_LINES_WIDTH_MAX = 32
Base.IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH = 4
Base.IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT = 4
Base.IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX = 16
Base.IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX = 4
Base.IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT = 13

local ImRect = {}
ImRect.__index = ImRect
Base.ImRect = ImRect

local function NewRect(min, max)
	return table.freeze(setmetatable({ Min = min, Max = max }, ImRect))
end

function ImRect.new(min, max)
	return NewRect(min or VEC2_ZERO, max or VEC2_ZERO)
end
function ImRect.fromXY(x1, y1, x2, y2)
	return NewRect(vcreate(x1, y1, 0), vcreate(x2, y2, 0))
end
function ImRect.fromVec4(v)
	return NewRect(vcreate(v.x, v.y, 0), vcreate(v.z, v.w, 0))
end
function ImRect:GetCenter()
	return vcreate((self.Min.x + self.Max.x) * 0.5, (self.Min.y + self.Max.y) * 0.5, 0)
end
function ImRect:GetSize()
	return vcreate(self.Max.x - self.Min.x, self.Max.y - self.Min.y, 0)
end
function ImRect:GetWidth()
	return self.Max.x - self.Min.x
end
function ImRect:GetHeight()
	return self.Max.y - self.Min.y
end
function ImRect:GetArea()
	return (self.Max.x - self.Min.x) * (self.Max.y - self.Min.y)
end
function ImRect:GetTL()
	return self.Min
end
function ImRect:GetTR()
	return vcreate(self.Max.x, self.Min.y, 0)
end
function ImRect:GetBL()
	return vcreate(self.Min.x, self.Max.y, 0)
end
function ImRect:GetBR()
	return self.Max
end
function ImRect:Contains(p)
	local mn, mx = self.Min, self.Max
	if type(p) == "vector" then
		return p.x >= mn.x and p.y >= mn.y and p.x < mx.x and p.y < mx.y
	end
	return p.Min.x >= mn.x and p.Min.y >= mn.y and p.Max.x <= mx.x and p.Max.y <= mx.y
end
function ImRect:ContainsWithPad(p, pad)
	local mn, mx = self.Min, self.Max
	return p.x >= mn.x - pad.x and p.y >= mn.y - pad.y and p.x < mx.x + pad.x and p.y < mx.y + pad.y
end
function ImRect:Overlaps(r)
	local mn, mx = self.Min, self.Max
	return r.Min.y < mx.y and r.Max.y > mn.y and r.Min.x < mx.x and r.Max.x > mn.x
end
function ImRect:Added(p)
	if type(p) == "vector" then
		return NewRect(vmin(self.Min, p), vmax(self.Max, p))
	end
	return NewRect(vmin(self.Min, p.Min), vmax(self.Max, p.Max))
end
function ImRect:AddedX(x)
	local mn, mx = self.Min, self.Max
	return NewRect(vcreate(if mn.x > x then x else mn.x, mn.y, 0), vcreate(if mx.x < x then x else mx.x, mx.y, 0))
end
function ImRect:AddedY(y)
	local mn, mx = self.Min, self.Max
	return NewRect(vcreate(mn.x, if mn.y > y then y else mn.y, 0), vcreate(mx.x, if mx.y < y then y else mx.y, 0))
end
function ImRect:Expanded(amount)
	if type(amount) == "number" then
		local a = vcreate(amount, amount, 0)
		return NewRect(self.Min - a, self.Max + a)
	end
	return NewRect(self.Min - amount, self.Max + amount)
end
function ImRect:Translated(d)
	return NewRect(self.Min + d, self.Max + d)
end
function ImRect:TranslatedX(dx)
	local d = vcreate(dx, 0, 0)
	return NewRect(self.Min + d, self.Max + d)
end
function ImRect:TranslatedY(dy)
	local d = vcreate(0, dy, 0)
	return NewRect(self.Min + d, self.Max + d)
end
function ImRect:ClippedWith(r)
	return NewRect(vmax(self.Min, r.Min), vmin(self.Max, r.Max))
end
function ImRect:ClippedWithFull(r)
	return NewRect(ImClamp(self.Min, r.Min, r.Max), ImClamp(self.Max, r.Min, r.Max))
end
function ImRect:Floored()
	return NewRect(ImTrunc(self.Min), ImTrunc(self.Max))
end
function ImRect:IsInverted()
	return self.Min.x > self.Max.x or self.Min.y > self.Max.y
end
function ImRect:ToVec4()
	return ImVec4(self.Min.x, self.Min.y, self.Max.x, self.Max.y)
end
ImRect.AsVec4 = ImRect.ToVec4
function ImRect:WithMin(v)
	return NewRect(v, self.Max)
end
function ImRect:WithMax(v)
	return NewRect(self.Min, v)
end
function ImRect:WithMinX(x)
	return NewRect(vcreate(x, self.Min.y, 0), self.Max)
end
function ImRect:WithMinY(y)
	return NewRect(vcreate(self.Min.x, y, 0), self.Max)
end
function ImRect:WithMaxX(x)
	return NewRect(self.Min, vcreate(x, self.Max.y, 0))
end
function ImRect:WithMaxY(y)
	return NewRect(self.Min, vcreate(self.Max.x, y, 0))
end
ImRect.__tostring = function(r)
	return sformat("ImRect(%g, %g, %g, %g)", r.Min.x, r.Min.y, r.Max.x, r.Max.y)
end

local function ImBezierCubicCalc(p1, p2, p3, p4, t)
	local u = 1 - t
	local w1 = u * u * u
	local w2 = 3 * u * u * t
	local w3 = 3 * u * t * t
	local w4 = t * t * t
	return vcreate(w1 * p1.x + w2 * p2.x + w3 * p3.x + w4 * p4.x, w1 * p1.y + w2 * p2.y + w3 * p3.y + w4 * p4.y, 0)
end
Base.ImBezierCubicCalc = ImBezierCubicCalc

function Base.ImBezierQuadraticCalc(p1, p2, p3, t)
	local u = 1 - t
	local w1 = u * u
	local w2 = 2 * u * t
	local w3 = t * t
	return vcreate(w1 * p1.x + w2 * p2.x + w3 * p3.x, w1 * p1.y + w2 * p2.y + w3 * p3.y, 0)
end

local function ImLineClosestPoint(a, b, p)
	local ap = p - a
	local ab_dir = b - a
	local dot = ap.x * ab_dir.x + ap.y * ab_dir.y
	if dot < 0 then
		return a
	end
	local ab_len_sqr = ab_dir.x * ab_dir.x + ab_dir.y * ab_dir.y
	if dot > ab_len_sqr then
		return b
	end
	return a + ab_dir * dot / ab_len_sqr
end
Base.ImLineClosestPoint = ImLineClosestPoint

function Base.ImBezierCubicClosestPoint(p1, p2, p3, p4, p, num_segments)
	assert(num_segments > 0)
	local p_last = p1
	local p_closest = VEC2_ZERO
	local p_closest_dist2 = FLT_MAX
	local t_step = 1 / num_segments
	for i_step = 1, num_segments do
		local p_current = ImBezierCubicCalc(p1, p2, p3, p4, t_step * i_step)
		local p_line = ImLineClosestPoint(p_last, p_current, p)
		local dist2 = ImLengthSqr(p - p_line)
		if dist2 < p_closest_dist2 then
			p_closest = p_line
			p_closest_dist2 = dist2
		end
		p_last = p_current
	end
	return p_closest
end

local function ImBezierCubicClosestPointCasteljauStep(p, st, x1, y1, x2, y2, x3, y3, x4, y4, max_error_sqr, level)
	local dx = x4 - x1
	local dy = y4 - y1
	local d2 = ((x2 - x4) * dy - (y2 - y4) * dx)
	local d3 = ((x3 - x4) * dy - (y3 - y4) * dx)
	d2 = if d2 >= 0 then d2 else -d2
	d3 = if d3 >= 0 then d3 else -d3
	if (d2 + d3) * (d2 + d3) < max_error_sqr * (dx * dx + dy * dy) then
		local p_current = vcreate(x4, y4, 0)
		local p_line = ImLineClosestPoint(st.p_last, p_current, p)
		local dist2 = ImLengthSqr(p - p_line)
		if dist2 < st.p_closest_dist2 then
			st.p_closest = p_line
			st.p_closest_dist2 = dist2
		end
		st.p_last = p_current
	elseif level < 10 then
		local x12, y12 = (x1 + x2) * 0.5, (y1 + y2) * 0.5
		local x23, y23 = (x2 + x3) * 0.5, (y2 + y3) * 0.5
		local x34, y34 = (x3 + x4) * 0.5, (y3 + y4) * 0.5
		local x123, y123 = (x12 + x23) * 0.5, (y12 + y23) * 0.5
		local x234, y234 = (x23 + x34) * 0.5, (y23 + y34) * 0.5
		local x1234, y1234 = (x123 + x234) * 0.5, (y123 + y234) * 0.5
		ImBezierCubicClosestPointCasteljauStep(p, st, x1, y1, x12, y12, x123, y123, x1234, y1234, max_error_sqr, level + 1)
		ImBezierCubicClosestPointCasteljauStep(p, st, x1234, y1234, x234, y234, x34, y34, x4, y4, max_error_sqr, level + 1)
	end
end

function Base.ImBezierCubicClosestPointCasteljau(p1, p2, p3, p4, p, max_error)
	assert(max_error > 0)
	local st = { p_last = p1, p_closest = VEC2_ZERO, p_closest_dist2 = FLT_MAX }
	ImBezierCubicClosestPointCasteljauStep(p, st, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, max_error * max_error, 0)
	return st.p_closest
end

function Base.ImTriangleContainsPoint(a, b, c, p)
	local b1 = ((p.x - b.x) * (a.y - b.y) - (p.y - b.y) * (a.x - b.x)) < 0
	local b2 = ((p.x - c.x) * (b.y - c.y) - (p.y - c.y) * (b.x - c.x)) < 0
	local b3 = ((p.x - a.x) * (c.y - a.y) - (p.y - a.y) * (c.x - a.x)) < 0
	return (b1 == b2) and (b2 == b3)
end

function Base.ImTriangleBarycentricCoords(a, b, c, p)
	local v0 = b - a
	local v1 = c - a
	local v2 = p - a
	local denom = v0.x * v1.y - v1.x * v0.y
	local out_v = (v2.x * v1.y - v1.x * v2.y) / denom
	local out_w = (v0.x * v2.y - v2.x * v0.y) / denom
	local out_u = 1 - out_v - out_w
	return out_u, out_v, out_w
end

function Base.ImTriangleClosestPoint(a, b, c, p)
	local proj_ab = ImLineClosestPoint(a, b, p)
	local proj_bc = ImLineClosestPoint(b, c, p)
	local proj_ca = ImLineClosestPoint(c, a, p)
	local dist2_ab = ImLengthSqr(p - proj_ab)
	local dist2_bc = ImLengthSqr(p - proj_bc)
	local dist2_ca = ImLengthSqr(p - proj_ca)
	local m = ImMin(dist2_ab, ImMin(dist2_bc, dist2_ca))
	if m == dist2_ab then
		return proj_ab
	end
	if m == dist2_bc then
		return proj_bc
	end
	return proj_ca
end

function Base.ImTriangleArea(a, b, c)
	return mabs((a.x * (b.y - c.y)) + (b.x * (c.y - a.y)) + (c.x * (a.y - b.y))) * 0.5
end

function Base.ImTriangleIsClockwise(a, b, c)
	return ((b.x - a.x) * (c.y - b.y)) - ((c.x - b.x) * (b.y - a.y)) > 0
end

local function ImToUpper(c)
	if c >= 97 and c <= 122 then
		return c - 32
	end
	return c
end
Base.ImToUpper = ImToUpper

local function ImCharIsBlankA(c)
	return c == 32 or c == 9
end
Base.ImCharIsBlankA = ImCharIsBlankA

function Base.ImCharIsBlankW(c)
	return c == 32 or c == 9 or c == 0x3000
end

function Base.ImCharIsXdigitA(c)
	if c == nil then
		return false
	end
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102)
end

function Base.ImStricmp(str1, str2)
	local i = 1
	while true do
		local c1 = sbyte(str1, i) or 0
		local d = ImToUpper(sbyte(str2, i) or 0) - ImToUpper(c1)
		if d ~= 0 or c1 == 0 then
			return d
		end
		i += 1
	end
end

function Base.ImStrnicmp(str1, str2, count)
	local d = 0
	local i = 1
	while count > 0 do
		local c1 = sbyte(str1, i) or 0
		d = ImToUpper(sbyte(str2, i) or 0) - ImToUpper(c1)
		if d ~= 0 or c1 == 0 then
			break
		end
		i += 1
		count -= 1
	end
	return d
end

local function ImStrncpy(dst, src, count)
	if count == nil then
		src, count = dst, src
	end
	if count < 1 then
		return ""
	end
	local z = sfind(src, "\0", 1, true)
	if z ~= nil and z <= count - 1 then
		return ssub(src, 1, z - 1)
	end
	return ssub(src, 1, count - 1)
end
Base.ImStrncpy = ImStrncpy

function Base.ImStrdup(str)
	return str
end

function Base.ImMemdup(src, size)
	if type(src) == "table" then
		return table.clone(src)
	end
	return src
end

function Base.ImStrdupcpy(dst, p_dst_size, src)
	local src_size = #src + 1
	if p_dst_size ~= nil and p_dst_size < src_size then
		p_dst_size = src_size
	end
	return src, p_dst_size
end

local function ImStrchrRange(s, i, s_end, c)
	if type(c) == "string" then
		c = sbyte(c)
	end
	if s_end == nil then
		s_end = #s + 1
	end
	local p = sfind(s, schar(c), i, true)
	if p ~= nil and p < s_end then
		return p
	end
	return nil
end
Base.ImStrchrRange = ImStrchrRange

function Base.ImStrlenW(str)
	local n = 0
	while (str[n + 1] or 0) ~= 0 do
		n += 1
	end
	return n
end

function Base.ImStreolRange(s, i, s_end)
	if s_end == nil then
		s_end = #s + 1
	end
	local p = sfind(s, "\n", i, true)
	if p ~= nil and p < s_end then
		return p
	end
	return s_end
end

function Base.ImStrbol(s, mid_i, begin_i)
	if begin_i == nil then
		begin_i = 1
	end
	while mid_i > begin_i and sbyte(s, mid_i - 1) ~= 10 do
		mid_i -= 1
	end
	return mid_i
end

local function ImStristrRange(h, hi, h_end, n, ni, n_end)
	if n_end == nil then
		n_end = #n + 1
	end
	local un0 = ImToUpper(sbyte(n, ni) or 0)
	while (h_end == nil and (sbyte(h, hi) or 0) ~= 0) or (h_end ~= nil and hi < h_end) do
		if ImToUpper(sbyte(h, hi) or 0) == un0 then
			local b = ni + 1
			local a = hi + 1
			while b < n_end do
				if ImToUpper(sbyte(h, a) or 0) ~= ImToUpper(sbyte(n, b) or 0) then
					break
				end
				a += 1
				b += 1
			end
			if b == n_end then
				return hi
			end
		end
		hi += 1
	end
	return nil
end

function Base.ImStristr(haystack, haystack_end, needle, needle_end)
	return ImStristrRange(haystack, 1, haystack_end, needle, 1, needle_end)
end

function Base.ImStrTrimBlanks(buf)
	local p = 1
	local n = #buf
	while p <= n and ImCharIsBlankA(sbyte(buf, p)) do
		p += 1
	end
	local e = n
	while e >= p and ImCharIsBlankA(sbyte(buf, e)) do
		e -= 1
	end
	return ssub(buf, p, e)
end

function Base.ImStrSkipBlank(str, i)
	if i == nil then
		i = 1
	end
	while ImCharIsBlankA(sbyte(str, i)) do
		i += 1
	end
	return i
end

function Base.ImStrlen(s)
	return #s
end

local function IsSpace(c)
	return c == 32 or (c ~= nil and c >= 9 and c <= 13)
end

local function ScanFloat(s, i, limit)
	local sub = ssub(s, i, limit)
	local m = smatch(sub, "^[+-]?%d+%.?%d*[eE][+-]?%d+")
		or smatch(sub, "^[+-]?%.%d+[eE][+-]?%d+")
		or smatch(sub, "^[+-]?%d+%.?%d*")
		or smatch(sub, "^[+-]?%.%d+")
	if m ~= nil then
		return tonumber(m), i + #m
	end
	local sign, word = smatch(sub, "^([+-]?)(%a+)")
	if word ~= nil then
		local lw = string.lower(word)
		local v = nil
		if ssub(lw, 1, 8) == "infinity" then
			v, word = math.huge, ssub(word, 1, 8)
		elseif ssub(lw, 1, 3) == "inf" then
			v, word = math.huge, ssub(word, 1, 3)
		elseif ssub(lw, 1, 3) == "nan" then
			v, word = 0 / 0, ssub(word, 1, 3)
		end
		if v ~= nil then
			return (if sign == "-" then -v else v), i + #sign + #word
		end
	end
	return nil, i
end

function Base.ImAtof(str)
	local i = 1
	while IsSpace(sbyte(str, i)) do
		i += 1
	end
	return (ScanFloat(str, i, #str)) or 0
end

local function ScanInt(s, i, limit, base)
	local sub = ssub(s, i, limit)
	local sign, digits, m
	if base == 0 then
		sign, digits = smatch(sub, "^([+-]?)0[xX](%x+)")
		if digits ~= nil then
			base = 16
			m = #sign + 2 + #digits
		else
			sign, digits = smatch(sub, "^([+-]?)(0[0-7]*)")
			if digits ~= nil then
				base = 8
			else
				sign, digits = smatch(sub, "^([+-]?)(%d+)")
				base = 10
			end
		end
	elseif base == 16 then
		sign, digits = smatch(sub, "^([+-]?)0[xX](%x+)")
		if digits ~= nil then
			m = #sign + 2 + #digits
		else
			sign, digits = smatch(sub, "^([+-]?)(%x+)")
		end
	elseif base == 8 then
		sign, digits = smatch(sub, "^([+-]?)([0-7]+)")
	else
		sign, digits = smatch(sub, "^([+-]?)(%d+)")
	end
	if digits == nil then
		return nil, i
	end
	local v = tonumber(digits, base)
	if sign == "-" then
		v = -v
	end
	return v, i + (m or (#sign + #digits))
end

function Base.ImSscanf(str, fmt)
	local out, nout = {}, 0
	local si, fi = 1, 1
	local slen, flen = #str, #fmt
	while fi <= flen do
		local fc = sbyte(fmt, fi)
		if IsSpace(fc) then
			while fi <= flen and IsSpace(sbyte(fmt, fi)) do
				fi += 1
			end
			while si <= slen and IsSpace(sbyte(str, si)) do
				si += 1
			end
		elseif fc ~= 37 then
			if sbyte(str, si) ~= fc then
				break
			end
			si += 1
			fi += 1
		else
			fi += 1
			local suppress = false
			if sbyte(fmt, fi) == 42 then
				suppress = true
				fi += 1
			end
			local ws = fi
			while true do
				local c = sbyte(fmt, fi)
				if c == nil or c < 48 or c > 57 then
					break
				end
				fi += 1
			end
			local width = if fi > ws then tonumber(ssub(fmt, ws, fi - 1)) else nil
			while true do
				local c = sbyte(fmt, fi)
				if c == 73 then
					if ssub(fmt, fi, fi + 2) == "I64" or ssub(fmt, fi, fi + 2) == "I32" then
						fi += 3
					else
						fi += 1
					end
				elseif c == 104 or c == 108 or c == 76 or c == 113 or c == 106 or c == 122 or c == 116 then
					fi += 1
				else
					break
				end
			end
			local conv = sbyte(fmt, fi)
			fi += 1
			if conv == nil then
				break
			end
			if conv ~= 99 and conv ~= 110 and conv ~= 91 then
				while si <= slen and IsSpace(sbyte(str, si)) do
					si += 1
				end
			end
			local limit = if width ~= nil then si + width - 1 else slen
			if limit > slen then
				limit = slen
			end
			local v
			if conv == 37 then
				if sbyte(str, si) ~= 37 then
					break
				end
				si += 1
				continue
			elseif conv == 110 then
				if not suppress then
					nout += 1
					out[nout] = si - 1
				end
				continue
			elseif conv == 99 then
				local w = width or 1
				if si + w - 1 > slen then
					break
				end
				v = if w == 1 then sbyte(str, si) else ssub(str, si, si + w - 1)
				si += w
			elseif conv == 115 then
				local e = si
				while e <= limit and not IsSpace(sbyte(str, e)) do
					e += 1
				end
				if e == si then
					break
				end
				v = ssub(str, si, e - 1)
				si = e
			elseif conv == 100 or conv == 117 then
				v, si = ScanInt(str, si, limit, 10)
				if v ~= nil and conv == 117 and v < 0 then
					v += 4294967296
				end
			elseif conv == 105 then
				v, si = ScanInt(str, si, limit, 0)
			elseif conv == 120 or conv == 88 then
				v, si = ScanInt(str, si, limit, 16)
			elseif conv == 111 then
				v, si = ScanInt(str, si, limit, 8)
			elseif conv == 102 or conv == 101 or conv == 103 or conv == 69 or conv == 71 or conv == 97 or conv == 65 or conv == 70 then
				v, si = ScanFloat(str, si, limit)
			else
				break
			end
			if v == nil then
				break
			end
			if not suppress then
				nout += 1
				out[nout] = v
			end
		end
	end
	return table.unpack(out, 1, nout)
end

local FormatCache = {}

local function FormatConvArg(kind, v)
	local tv = type(v)
	if kind == "s" then
		if v == nil then
			return "(null)"
		end
		if tv ~= "string" then
			return tostring(v)
		end
		return v
	end
	if kind == "p" then
		return Base.ImPtrToInt(v)
	end
	if tv == "boolean" then
		v = if v then 1 else 0
	elseif tv == "string" then
		if kind == "c" and #v > 0 then
			return sbyte(v)
		end
		v = tonumber(v) or 0
	elseif tv ~= "number" then
		v = 0
	end
	if kind == "f" then
		return v
	end
	if v ~= v or v >= 9.2233720368547758e18 or v <= -9.2233720368547758e18 then
		return 0
	end
	v = ImTruncToInt(v)
	if (kind == "u" or kind == "x") and v < 0 then
		v += 4294967296
	end
	return v
end

local FORMAT_CONV = {
	d = { "d", "i" },
	i = { "d", "i" },
	u = { "d", "u" },
	x = { "x", "x" },
	X = { "X", "x" },
	o = { "o", "x" },
	c = { "c", "c" },
	s = { "s", "s" },
	p = { "x", "p" },
	f = { "f", "f" },
	F = { "f", "f" },
	e = { "e", "f" },
	E = { "E", "f" },
	g = { "g", "f" },
	G = { "G", "f" },
	a = { "a", "f" },
	A = { "A", "f" },
	n = { "", "n" },
}

local function ClampFormatNum(s)
	if s ~= "" and tonumber(s) > 99 then
		return "99"
	end
	return s
end

local function CompileFormat(fmt)
	local specs = {}
	local pieces = {}
	local has_star = false
	local i, n = 1, #fmt
	while i <= n do
		local p = sfind(fmt, "%", i, true)
		if p == nil then
			pieces[#pieces + 1] = ssub(fmt, i)
			break
		end
		if p > i then
			pieces[#pieces + 1] = ssub(fmt, i, p - 1)
		end
		local flags, width, dot, prec, j = smatch(fmt, "^([-+ #0'_$]*)(%*?%d*)(%.?)(%*?%d*)()", p + 1)
		while true do
			local c = ssub(fmt, j, j)
			if c == "I" then
				local t = ssub(fmt, j, j + 2)
				j += if t == "I64" or t == "I32" then 3 else 1
			elseif c == "h" or c == "l" or c == "L" or c == "q" or c == "j" or c == "z" or c == "t" or c == "w" then
				j += 1
			else
				break
			end
		end
		local conv = ssub(fmt, j, j)
		local info = FORMAT_CONV[conv]
		if conv == "%" then
			pieces[#pieces + 1] = "%%"
			i = j + 1
		elseif info == nil then
			pieces[#pieces + 1] = "%%"
			i = p + 1
		else
			flags = string.gsub(flags, "['_$]", "")
			if #flags > 5 then
				flags = ssub(flags, 1, 5)
			end
			local spec = {
				piece = #pieces + 1,
				flags = flags,
				width = if width == "*" then "*" else ClampFormatNum(width),
				dot = dot,
				prec = if prec == "*" then "*" else ClampFormatNum(prec),
				conv = info[1],
				kind = info[2],
			}
			if spec.width == "*" or spec.prec == "*" then
				has_star = true
			end
			specs[#specs + 1] = spec
			if spec.kind == "n" then
				pieces[#pieces + 1] = ""
			else
				pieces[#pieces + 1] = "%" .. flags .. spec.width .. dot .. spec.prec .. spec.conv
			end
			i = j + 1
		end
	end
	local compiled = { specs = specs, pieces = pieces, has_star = has_star }
	if not has_star then
		compiled.luafmt = table.concat(pieces)
		local kinds = {}
		for k = 1, #specs do
			kinds[k] = specs[k].kind
		end
		compiled.kinds = kinds
		if #specs == 0 then
			compiled.literal = sformat(compiled.luafmt)
		end
	end
	return compiled
end

local function ImFormatString(fmt, ...)
	local c = FormatCache[fmt]
	if c == nil then
		c = CompileFormat(fmt)
		FormatCache[fmt] = c
	end
	if c.literal ~= nil then
		return c.literal
	end
	if not c.has_star then
		local kinds = c.kinds
		local nk = #kinds
		if nk == 1 then
			local k1 = kinds[1]
			if k1 ~= "n" then
				return sformat(c.luafmt, FormatConvArg(k1, (...)))
			end
		elseif nk == 2 then
			local k1, k2 = kinds[1], kinds[2]
			if k1 ~= "n" and k2 ~= "n" then
				local a1, a2 = ...
				return sformat(c.luafmt, FormatConvArg(k1, a1), FormatConvArg(k2, a2))
			end
		end
		local args = { ... }
		local out = table.create(nk)
		local no = 0
		for k = 1, nk do
			local kind = kinds[k]
			if kind ~= "n" then
				no += 1
				out[no] = FormatConvArg(kind, args[k])
			end
		end
		return sformat(c.luafmt, table.unpack(out, 1, no))
	end
	local args = { ... }
	local pieces = table.clone(c.pieces)
	local out = {}
	local no = 0
	local ai = 1
	for _, spec in c.specs do
		local width, prec, flags = spec.width, spec.prec, spec.flags
		if width == "*" then
			local w = ImTruncToInt(tonumber(args[ai]) or 0)
			ai += 1
			if w < 0 then
				flags = "-" .. flags
				w = -w
			end
			width = ClampFormatNum(tostring(w))
		end
		if prec == "*" then
			local pr = ImTruncToInt(tonumber(args[ai]) or 0)
			ai += 1
			prec = if pr < 0 then "" else ClampFormatNum(tostring(pr))
		end
		local v = args[ai]
		ai += 1
		if spec.kind ~= "n" then
			local dot = spec.dot
			if prec == "" and spec.prec == "*" then
				dot = ""
			end
			pieces[spec.piece] = "%" .. flags .. width .. dot .. prec .. spec.conv
			no += 1
			out[no] = FormatConvArg(spec.kind, v)
		end
	end
	return sformat(table.concat(pieces), table.unpack(out, 1, no))
end
Base.ImFormatString = ImFormatString
Base.ImFormatStringV = ImFormatString

local function ImFormatStringToTempBuffer(fmt, ...)
	local buf
	if fmt == "%s" then
		buf = ...
		if buf == nil then
			buf = "(null)"
		end
	elseif fmt == "%.*s" then
		local buf_len, b = ...
		if b == nil then
			b = "(null)"
			buf_len = ImMin(buf_len, 6)
		end
		buf = ssub(b, 1, buf_len)
	else
		buf = ImFormatString(fmt, ...)
	end
	return buf, #buf + 1
end
Base.ImFormatStringToTempBuffer = ImFormatStringToTempBuffer
Base.ImFormatStringToTempBufferV = ImFormatStringToTempBuffer

local function ImParseFormatFindStart(fmt, i)
	if i == nil then
		i = 1
	end
	while true do
		local c = sbyte(fmt, i)
		if c == nil or c == 0 then
			return i
		end
		if c == 37 and sbyte(fmt, i + 1) ~= 37 then
			return i
		elseif c == 37 then
			i += 1
		end
		i += 1
	end
end
Base.ImParseFormatFindStart = ImParseFormatFindStart

local PARSE_IGNORED_UPPER = bor(lshift(1, 73 - 65), lshift(1, 76 - 65))
local PARSE_IGNORED_LOWER = bor(lshift(1, 104 - 97), lshift(1, 106 - 97), lshift(1, 108 - 97), lshift(1, 116 - 97), lshift(1, 119 - 97), lshift(1, 122 - 97))

local function ImParseFormatFindEnd(fmt, i)
	if i == nil then
		i = 1
	end
	if sbyte(fmt, i) ~= 37 then
		return i
	end
	while true do
		local c = sbyte(fmt, i)
		if c == nil or c == 0 then
			return i
		end
		if c >= 65 and c <= 90 and band(lshift(1, c - 65), PARSE_IGNORED_UPPER) == 0 then
			return i + 1
		end
		if c >= 97 and c <= 122 and band(lshift(1, c - 97), PARSE_IGNORED_LOWER) == 0 then
			return i + 1
		end
		i += 1
	end
end
Base.ImParseFormatFindEnd = ImParseFormatFindEnd

function Base.ImParseFormatTrimDecorations(fmt)
	local fmt_start = ImParseFormatFindStart(fmt)
	if sbyte(fmt, fmt_start) ~= 37 then
		return ""
	end
	local fmt_end = ImParseFormatFindEnd(fmt, fmt_start)
	local c = sbyte(fmt, fmt_end)
	if c == nil or c == 0 then
		return ssub(fmt, fmt_start)
	end
	return ssub(fmt, fmt_start, fmt_end - 1)
end

function Base.ImParseFormatSanitizeForPrinting(fmt_in)
	local fmt_end = ImParseFormatFindEnd(fmt_in)
	local out = {}
	for i = 1, fmt_end - 1 do
		local c = sbyte(fmt_in, i)
		if c ~= 39 and c ~= 36 and c ~= 95 then
			out[#out + 1] = schar(c)
		end
	end
	return table.concat(out)
end

function Base.ImParseFormatSanitizeForScanning(fmt_in)
	local fmt_end = ImParseFormatFindEnd(fmt_in)
	local out = {}
	local has_type = false
	for i = 1, fmt_end - 1 do
		local c = sbyte(fmt_in, i)
		if not has_type and ((c >= 48 and c <= 57) or c == 46 or c == 43 or c == 35) then
			continue
		end
		has_type = has_type or ((c >= 97 and c <= 122) or (c >= 65 and c <= 90))
		if c ~= 39 and c ~= 36 and c ~= 95 then
			out[#out + 1] = schar(c)
		end
	end
	return table.concat(out)
end

function Base.ImParseFormatPrecision(fmt, default_precision)
	local i = ImParseFormatFindStart(fmt)
	if sbyte(fmt, i) ~= 37 then
		return default_precision
	end
	i += 1
	local function isdigit(c)
		return c ~= nil and c >= 48 and c <= 57
	end
	while isdigit(sbyte(fmt, i)) do
		i += 1
	end
	local INT_MAX = 2147483647
	local precision = INT_MAX
	if sbyte(fmt, i) == 46 then
		i += 1
		local negative = false
		if sbyte(fmt, i) == 45 then
			negative = true
			i += 1
		end
		if sbyte(fmt, i) == 43 then
			i += 1
		end
		local v = 0
		while isdigit(sbyte(fmt, i)) do
			v = (v * 10) + (sbyte(fmt, i) - 48)
			i += 1
		end
		precision = if negative then -v else v
		if precision < 0 or precision > 99 then
			precision = default_precision
		end
	end
	local c = sbyte(fmt, i)
	if c == 101 or c == 69 then
		precision = -1
	end
	if (c == 103 or c == 71) and precision == INT_MAX then
		precision = -1
	end
	return if precision == INT_MAX then default_precision else precision
end

local GCrc32LookupTable = {
	0x00000000,0xF26B8303,0xE13B70F7,0x1350F3F4,0xC79A971F,0x35F1141C,0x26A1E7E8,0xD4CA64EB,
	0x8AD958CF,0x78B2DBCC,0x6BE22838,0x9989AB3B,0x4D43CFD0,0xBF284CD3,0xAC78BF27,0x5E133C24,
	0x105EC76F,0xE235446C,0xF165B798,0x030E349B,0xD7C45070,0x25AFD373,0x36FF2087,0xC494A384,
	0x9A879FA0,0x68EC1CA3,0x7BBCEF57,0x89D76C54,0x5D1D08BF,0xAF768BBC,0xBC267848,0x4E4DFB4B,
	0x20BD8EDE,0xD2D60DDD,0xC186FE29,0x33ED7D2A,0xE72719C1,0x154C9AC2,0x061C6936,0xF477EA35,
	0xAA64D611,0x580F5512,0x4B5FA6E6,0xB93425E5,0x6DFE410E,0x9F95C20D,0x8CC531F9,0x7EAEB2FA,
	0x30E349B1,0xC288CAB2,0xD1D83946,0x23B3BA45,0xF779DEAE,0x05125DAD,0x1642AE59,0xE4292D5A,
	0xBA3A117E,0x4851927D,0x5B016189,0xA96AE28A,0x7DA08661,0x8FCB0562,0x9C9BF696,0x6EF07595,
	0x417B1DBC,0xB3109EBF,0xA0406D4B,0x522BEE48,0x86E18AA3,0x748A09A0,0x67DAFA54,0x95B17957,
	0xCBA24573,0x39C9C670,0x2A993584,0xD8F2B687,0x0C38D26C,0xFE53516F,0xED03A29B,0x1F682198,
	0x5125DAD3,0xA34E59D0,0xB01EAA24,0x42752927,0x96BF4DCC,0x64D4CECF,0x77843D3B,0x85EFBE38,
	0xDBFC821C,0x2997011F,0x3AC7F2EB,0xC8AC71E8,0x1C661503,0xEE0D9600,0xFD5D65F4,0x0F36E6F7,
	0x61C69362,0x93AD1061,0x80FDE395,0x72966096,0xA65C047D,0x5437877E,0x4767748A,0xB50CF789,
	0xEB1FCBAD,0x197448AE,0x0A24BB5A,0xF84F3859,0x2C855CB2,0xDEEEDFB1,0xCDBE2C45,0x3FD5AF46,
	0x7198540D,0x83F3D70E,0x90A324FA,0x62C8A7F9,0xB602C312,0x44694011,0x5739B3E5,0xA55230E6,
	0xFB410CC2,0x092A8FC1,0x1A7A7C35,0xE811FF36,0x3CDB9BDD,0xCEB018DE,0xDDE0EB2A,0x2F8B6829,
	0x82F63B78,0x709DB87B,0x63CD4B8F,0x91A6C88C,0x456CAC67,0xB7072F64,0xA457DC90,0x563C5F93,
	0x082F63B7,0xFA44E0B4,0xE9141340,0x1B7F9043,0xCFB5F4A8,0x3DDE77AB,0x2E8E845F,0xDCE5075C,
	0x92A8FC17,0x60C37F14,0x73938CE0,0x81F80FE3,0x55326B08,0xA759E80B,0xB4091BFF,0x466298FC,
	0x1871A4D8,0xEA1A27DB,0xF94AD42F,0x0B21572C,0xDFEB33C7,0x2D80B0C4,0x3ED04330,0xCCBBC033,
	0xA24BB5A6,0x502036A5,0x4370C551,0xB11B4652,0x65D122B9,0x97BAA1BA,0x84EA524E,0x7681D14D,
	0x2892ED69,0xDAF96E6A,0xC9A99D9E,0x3BC21E9D,0xEF087A76,0x1D63F975,0x0E330A81,0xFC588982,
	0xB21572C9,0x407EF1CA,0x532E023E,0xA145813D,0x758FE5D6,0x87E466D5,0x94B49521,0x66DF1622,
	0x38CC2A06,0xCAA7A905,0xD9F75AF1,0x2B9CD9F2,0xFF56BD19,0x0D3D3E1A,0x1E6DCDEE,0xEC064EED,
	0xC38D26C4,0x31E6A5C7,0x22B65633,0xD0DDD530,0x0417B1DB,0xF67C32D8,0xE52CC12C,0x1747422F,
	0x49547E0B,0xBB3FFD08,0xA86F0EFC,0x5A048DFF,0x8ECEE914,0x7CA56A17,0x6FF599E3,0x9D9E1AE0,
	0xD3D3E1AB,0x21B862A8,0x32E8915C,0xC083125F,0x144976B4,0xE622F5B7,0xF5720643,0x07198540,
	0x590AB964,0xAB613A67,0xB831C993,0x4A5A4A90,0x9E902E7B,0x6CFBAD78,0x7FAB5E8C,0x8DC0DD8F,
	0xE330A81A,0x115B2B19,0x020BD8ED,0xF0605BEE,0x24AA3F05,0xD6C1BC06,0xC5914FF2,0x37FACCF1,
	0x69E9F0D5,0x9B8273D6,0x88D28022,0x7AB90321,0xAE7367CA,0x5C18E4C9,0x4F48173D,0xBD23943E,
	0xF36E6F75,0x0105EC76,0x12551F82,0xE03E9C81,0x34F4F86A,0xC69F7B69,0xD5CF889D,0x27A40B9E,
	0x79B737BA,0x8BDCB4B9,0x988C474D,0x6AE7C44E,0xBE2DA0A5,0x4C4623A6,0x5F16D052,0xAD7D5351,
}

function Base.ImHashData(data, data_size, seed)
	local crc = bnot(seed or 0)
	local lut = GCrc32LookupTable
	local t = type(data)
	if t == "number" then
		local size = data_size or 4
		local n = ImTruncToInt(data)
		local lo = n % 4294967296
		local hi = floor(n / 4294967296) % 4294967296
		for k = 0, size - 1 do
			local byte
			if k < 4 then
				byte = band(rshift(lo, k * 8), 0xFF)
			else
				byte = band(rshift(hi, (k - 4) * 8), 0xFF)
			end
			crc = bxor(rshift(crc, 8), lut[bxor(band(crc, 0xFF), byte) + 1])
		end
		return bnot(crc)
	end
	local s
	if t == "string" then
		s = data
	elseif t == "vector" then
		s = string.pack("<ff", data.x, data.y)
	elseif getmetatable(data) == ImRect then
		s = string.pack("<ffff", data.Min.x, data.Min.y, data.Max.x, data.Max.y)
	elseif getmetatable(data) == ImVec4Meta then
		s = string.pack("<ffff", data.x, data.y, data.z, data.w)
	else
		local parts = {}
		for k = 1, #data do
			parts[k] = string.pack("<I4", ImTruncToInt(data[k]) % 4294967296)
		end
		s = table.concat(parts)
	end
	for k = 1, data_size or #s do
		crc = bxor(rshift(crc, 8), lut[bxor(band(crc, 0xFF), sbyte(s, k) or 0) + 1])
	end
	return bnot(crc)
end

local HASHSTR_MEMO_MAX_COUNT = 16384
local HASHSTR_MEMO_MAX_LEN = 256
local HashStrMemo = {}
local HashStrMemoCount = 0

local function ImHashStrCompute(data, data_size, seed)
	seed = bnot(seed or 0)
	local crc = seed
	local lut = GCrc32LookupTable
	local i = 1
	if data_size ~= nil and data_size ~= 0 then
		while data_size > 0 do
			data_size -= 1
			local c = sbyte(data, i) or 0
			i += 1
			if c == 35 and data_size >= 2 and sbyte(data, i) == 35 and sbyte(data, i + 1) == 35 then
				crc = seed
				i += 2
				data_size -= 2
				continue
			end
			crc = bxor(rshift(crc, 8), lut[bxor(band(crc, 0xFF), c) + 1])
		end
	else
		while true do
			local c = sbyte(data, i)
			i += 1
			if c == nil or c == 0 then
				break
			end
			if c == 35 and sbyte(data, i) == 35 and sbyte(data, i + 1) == 35 then
				crc = seed
				i += 2
				continue
			end
			crc = bxor(rshift(crc, 8), lut[bxor(band(crc, 0xFF), c) + 1])
		end
	end
	return bnot(crc)
end

function Base.ImHashStr(data, data_size, seed)
	if (data_size == nil or data_size == 0) and type(data) == "string" and #data <= HASHSTR_MEMO_MAX_LEN then
		local key = seed or 0
		local m = HashStrMemo[key]
		if m == nil then
			m = {}
			HashStrMemo[key] = m
		end
		local h = m[data]
		if h == nil then
			h = ImHashStrCompute(data, data_size, seed)
			if HashStrMemoCount >= HASHSTR_MEMO_MAX_COUNT then
				table.clear(HashStrMemo)
				HashStrMemoCount = 0
				HashStrMemo[key] = m
				table.clear(m)
			end
			HashStrMemoCount += 1
			m[data] = h
		end
		return h
	end
	return ImHashStrCompute(data, data_size, seed)
end

function Base.ImHashSkipUncontributingPrefix(label)
	local result = 1
	local i = 1
	while true do
		local c = sbyte(label, i)
		if c == nil or c == 0 then
			break
		end
		i += 1
		if c == 35 and sbyte(label, i) == 35 and sbyte(label, i + 1) == 35 then
			result = i + 2
		end
	end
	return result
end

local function MergeSortRange(a, tmp, lo, hi, cmp)
	if hi - lo < 12 then
		for i = lo + 1, hi do
			local v = a[i]
			local j = i - 1
			while j >= lo and cmp(a[j], v) > 0 do
				a[j + 1] = a[j]
				j -= 1
			end
			a[j + 1] = v
		end
		return
	end
	local mid = (lo + hi) // 2
	MergeSortRange(a, tmp, lo, mid, cmp)
	MergeSortRange(a, tmp, mid + 1, hi, cmp)
	if cmp(a[mid], a[mid + 1]) <= 0 then
		return
	end
	table.move(a, lo, mid, lo, tmp)
	local i, j, k = lo, mid + 1, lo
	while i <= mid and j <= hi do
		if cmp(a[j], tmp[i]) < 0 then
			a[k] = a[j]
			j += 1
		else
			a[k] = tmp[i]
			i += 1
		end
		k += 1
	end
	while i <= mid do
		a[k] = tmp[i]
		i += 1
		k += 1
	end
end

local function ImQsort(tbl, count, cmp, cmp_if_sized)
	if cmp_if_sized ~= nil then
		cmp = cmp_if_sized
	end
	if count > 1 then
		MergeSortRange(tbl, {}, 1, count, cmp)
	end
end
Base.ImQsort = ImQsort

function Base.ImAlphaBlendColors(col_a, col_b)
	local t = band(rshift(col_b, IM_COL32_A_SHIFT), 0xFF) / 255
	local function lerp(a, b)
		return ImTruncToInt(a + (b - a) * t)
	end
	local r = lerp(band(rshift(col_a, IM_COL32_R_SHIFT), 0xFF), band(rshift(col_b, IM_COL32_R_SHIFT), 0xFF))
	local g = lerp(band(rshift(col_a, IM_COL32_G_SHIFT), 0xFF), band(rshift(col_b, IM_COL32_G_SHIFT), 0xFF))
	local b = lerp(band(rshift(col_a, IM_COL32_B_SHIFT), 0xFF), band(rshift(col_b, IM_COL32_B_SHIFT), 0xFF))
	return IM_COL32(r, g, b, 0xFF)
end

local UTF8_LENGTHS = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 3, 3, 4, 0 }
local UTF8_MASKS = { [0] = 0x00, 0x7f, 0x1f, 0x0f, 0x07 }
local UTF8_MINS = { [0] = 0x400000, 0, 0x80, 0x800, 0x10000 }
local UTF8_SHIFTC = { [0] = 0, 18, 12, 6, 0 }
local UTF8_SHIFTE = { [0] = 0, 6, 4, 2, 0 }

local function ImTextCharFromUtf8(s, i, s_end)
	if i == nil then
		i = 1
	end
	local b0 = sbyte(s, i) or 0
	local len = UTF8_LENGTHS[rshift(b0, 3) + 1]
	local wanted = len + (if len ~= 0 then 0 else 1)
	if s_end == nil then
		s_end = i + wanted
	end
	local s0 = if i < s_end then b0 else 0
	local s1 = if i + 1 < s_end then (sbyte(s, i + 1) or 0) else 0
	local s2 = if i + 2 < s_end then (sbyte(s, i + 2) or 0) else 0
	local s3 = if i + 3 < s_end then (sbyte(s, i + 3) or 0) else 0
	local c = bor(lshift(band(s0, UTF8_MASKS[len]), 18), lshift(band(s1, 0x3f), 12), lshift(band(s2, 0x3f), 6), band(s3, 0x3f))
	c = rshift(c, UTF8_SHIFTC[len])
	local e = if c < UTF8_MINS[len] then 64 else 0
	if rshift(c, 11) == 0x1b then
		e = bor(e, 128)
	end
	if c > 0x10FFFF then
		e = bor(e, 256)
	end
	e = bor(e, rshift(band(s1, 0xc0), 2), rshift(band(s2, 0xc0), 4), rshift(s3, 6))
	e = bxor(e, 0x2a)
	e = rshift(e, UTF8_SHIFTE[len])
	if e ~= 0 then
		local avail = (if s0 ~= 0 then 1 else 0) + (if s1 ~= 0 then 1 else 0) + (if s2 ~= 0 then 1 else 0) + (if s3 ~= 0 then 1 else 0)
		if avail < wanted then
			wanted = avail
		end
		c = 0xFFFD
	end
	return wanted, c
end
Base.ImTextCharFromUtf8 = ImTextCharFromUtf8

function Base.ImTextStrFromUtf8(buf, buf_size, in_text, in_text_end)
	local n = 0
	local i = 1
	local max_n = if buf_size ~= nil then buf_size - 1 else math.huge
	while n < max_n and (in_text_end == nil or i < in_text_end) and (sbyte(in_text, i) or 0) ~= 0 do
		local l, c = ImTextCharFromUtf8(in_text, i, in_text_end)
		i += l
		n += 1
		buf[n] = c
	end
	buf[n + 1] = 0
	return n, i
end

function Base.ImTextCountCharsFromUtf8(s, i, s_end)
	if i == nil then
		i = 1
	end
	local char_count = 0
	while (s_end == nil or i < s_end) and (sbyte(s, i) or 0) ~= 0 do
		local l = ImTextCharFromUtf8(s, i, s_end)
		i += l
		char_count += 1
	end
	return char_count
end

local function ImTextCharToUtf8_inline(c)
	if c < 0x80 then
		return schar(c)
	end
	if c < 0x800 then
		return schar(0xc0 + rshift(c, 6), 0x80 + band(c, 0x3f))
	end
	if c < 0x10000 then
		return schar(0xe0 + rshift(c, 12), 0x80 + band(rshift(c, 6), 0x3f), 0x80 + band(c, 0x3f))
	end
	if c <= 0x10FFFF then
		return schar(0xf0 + rshift(c, 18), 0x80 + band(rshift(c, 12), 0x3f), 0x80 + band(rshift(c, 6), 0x3f), 0x80 + band(c, 0x3f))
	end
	return ""
end

function Base.ImTextCharToUtf8(a, b)
	local s = ImTextCharToUtf8_inline(if b ~= nil then b else a)
	return s, #s
end

function Base.ImTextCountUtf8BytesFromChar(s, a, b)
	if b ~= nil then
		return (ImTextCharFromUtf8(s, a, b))
	end
	return (ImTextCharFromUtf8(s, 1, a))
end

local function ImTextCountUtf8BytesFromCodepoint(c)
	if c < 0x80 then
		return 1
	end
	if c < 0x800 then
		return 2
	end
	if c < 0x10000 then
		return 3
	end
	if c <= 0x10FFFF then
		return 4
	end
	return 3
end

function Base.ImTextStrToUtf8(in_text, in_text_end)
	local out = {}
	local i = 1
	while (in_text_end == nil or i < in_text_end) and (in_text[i] or 0) ~= 0 do
		out[#out + 1] = ImTextCharToUtf8_inline(in_text[i])
		i += 1
	end
	local s = table.concat(out)
	return s, #s
end

function Base.ImTextCountUtf8BytesFromStr(in_text, in_text_end)
	if type(in_text) == "number" then
		in_text = { in_text }
	end
	local bytes_count = 0
	local i = 1
	while (in_text_end == nil or i < in_text_end) and (in_text[i] or 0) ~= 0 do
		bytes_count += ImTextCountUtf8BytesFromCodepoint(in_text[i])
		i += 1
	end
	return bytes_count
end

local function ImTextFindPreviousUtf8Codepoint(s, i_start, i)
	while i > i_start do
		i -= 1
		if band(sbyte(s, i) or 0, 0xC0) ~= 0x80 then
			return i
		end
	end
	return i_start
end
Base.ImTextFindPreviousUtf8Codepoint = ImTextFindPreviousUtf8Codepoint

function Base.ImTextFindValidUtf8CodepointEnd(s, i_start, a, b)
	local s_end, p
	if b ~= nil then
		s_end, p = a, b
	else
		s_end, p = #s + 1, a
	end
	if i_start == p then
		return i_start
	end
	local prev = ImTextFindPreviousUtf8Codepoint(s, i_start, p)
	local prev_c_len, prev_c = ImTextCharFromUtf8(s, prev, s_end)
	if prev_c ~= 0xFFFD and prev_c_len <= p - prev then
		return p
	end
	return prev
end

function Base.ImTextCountLines(text, text_end)
	if text_end == nil then
		text_end = #text + 1
	end
	local count = 0
	local i = 1
	while i < text_end do
		local line_end = sfind(text, "\n", i, true)
		if line_end ~= nil and line_end < text_end then
			i = line_end + 1
		else
			i = text_end
		end
		count += 1
	end
	return count
end

function Base.ImFileOpen(filename, mode)
	return nil
end
function Base.ImFileClose(f)
	return false
end
function Base.ImFileGetSize(f)
	return -1
end
function Base.ImFileRead(data, sz, count, f)
	return 0
end
function Base.ImFileWrite(data, sz, count, f)
	return 0
end

function Base.ImFileLoadToMemory(filename, mode, out_file_size, padding_bytes)
	assert(filename and mode)
	local f = Base.ImFileOpen(filename, mode)
	if f == nil then
		return nil, 0
	end
	local file_size = Base.ImFileGetSize(f)
	if file_size == -1 then
		Base.ImFileClose(f)
		return nil, 0
	end
	local file_data = {}
	if Base.ImFileRead(file_data, 1, file_size, f) ~= file_size then
		Base.ImFileClose(f)
		return nil, 0
	end
	Base.ImFileClose(f)
	return file_data, file_size
end

function ImGui.ColorConvertU32ToFloat4(u32)
	local s = 1 / 255
	return ImVec4(
		band(rshift(u32, IM_COL32_R_SHIFT), 0xFF) * s,
		band(rshift(u32, IM_COL32_G_SHIFT), 0xFF) * s,
		band(rshift(u32, IM_COL32_B_SHIFT), 0xFF) * s,
		band(rshift(u32, IM_COL32_A_SHIFT), 0xFF) * s
	)
end

local function ColorConvertFloat4ToU32XYZW(x, y, z, w)
	if x < 0 then
		x = 0
	elseif x > 1 then
		x = 1
	end
	if y < 0 then
		y = 0
	elseif y > 1 then
		y = 1
	end
	if z < 0 then
		z = 0
	elseif z > 1 then
		z = 1
	end
	if w < 0 then
		w = 0
	elseif w > 1 then
		w = 1
	end
	local out = lshift(floor(x * 255 + 0.5), IM_COL32_R_SHIFT)
	out = bor(out, lshift(floor(y * 255 + 0.5), IM_COL32_G_SHIFT))
	out = bor(out, lshift(floor(z * 255 + 0.5), IM_COL32_B_SHIFT))
	out = bor(out, lshift(floor(w * 255 + 0.5), IM_COL32_A_SHIFT))
	return out
end
Base.ColorConvertFloat4ToU32XYZW = ColorConvertFloat4ToU32XYZW

function ImGui.ColorConvertFloat4ToU32(v)
	return ColorConvertFloat4ToU32XYZW(v.x, v.y, v.z, v.w)
end

function ImGui.ColorConvertRGBtoHSV(r, g, b)
	local K = 0
	if g < b then
		g, b = b, g
		K = -1
	end
	if r < g then
		r, g = g, r
		K = -2 / 6 - K
	end
	local chroma = r - (if g < b then g else b)
	local out_h = mabs(K + (g - b) / (6 * chroma + 1e-20))
	local out_s = chroma / (r + 1e-20)
	local out_v = r
	return out_h, out_s, out_v
end

function ImGui.ColorConvertHSVtoRGB(h, s, v)
	if s == 0 then
		return v, v, v
	end
	h = fmod(h, 1) / (60 / 360)
	local i = ImTruncToInt(h)
	local f = h - i
	local p = v * (1 - s)
	local q = v * (1 - s * f)
	local t = v * (1 - s * (1 - f))
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	end
	return v, p, q
end

local ImVector = {}
ImVector.__index = ImVector
Base.ImVector = ImVector

function ImVector.new()
	return setmetatable({ Size = 0, Capacity = 0 }, ImVector)
end
function ImVector:Copy()
	local v = setmetatable({ Size = self.Size, Capacity = self.Size }, ImVector)
	table.move(self, 1, self.Size, 1, v)
	return v
end
function ImVector:clear()
	table.clear(self)
	self.Size = 0
	self.Capacity = 0
end
ImVector.clear_delete = ImVector.clear
ImVector.clear_destruct = ImVector.clear
function ImVector:empty()
	return self.Size == 0
end
function ImVector:size()
	return self.Size
end
function ImVector:size_in_bytes()
	return self.Size * 8
end
function ImVector:capacity()
	return self.Capacity
end
function ImVector:front()
	assert(self.Size > 0)
	return self[1]
end
function ImVector:back()
	assert(self.Size > 0)
	return self[self.Size]
end
function ImVector:swap(rhs)
	local n = if self.Size > rhs.Size then self.Size else rhs.Size
	for i = 1, n do
		self[i], rhs[i] = rhs[i], self[i]
	end
	self.Size, rhs.Size = rhs.Size, self.Size
	self.Capacity, rhs.Capacity = rhs.Capacity, self.Capacity
end
function ImVector:_grow_capacity(sz)
	local new_capacity = if self.Capacity ~= 0 then (self.Capacity + self.Capacity // 2) else 8
	return if new_capacity > sz then new_capacity else sz
end
function ImVector:resize(new_size, v)
	if new_size > self.Capacity then
		self:reserve(self:_grow_capacity(new_size))
	end
	if v ~= nil and new_size > self.Size then
		for n = self.Size + 1, new_size do
			self[n] = v
		end
	end
	self.Size = new_size
end
function ImVector:shrink(new_size)
	assert(new_size <= self.Size)
	self.Size = new_size
end
function ImVector:reserve(new_capacity)
	if new_capacity > self.Capacity then
		self.Capacity = new_capacity
	end
end
ImVector.reserve_discard = ImVector.reserve
function ImVector:push_back(v)
	local n = self.Size
	if n == self.Capacity then
		self:reserve(self:_grow_capacity(n + 1))
	end
	n += 1
	self[n] = v
	self.Size = n
end
function ImVector:pop_back()
	assert(self.Size > 0)
	self.Size -= 1
end
function ImVector:push_front(v)
	if self.Size == 0 then
		self:push_back(v)
	else
		self:insert(0, v)
	end
end
function ImVector:erase(it, it_last)
	local size = self.Size
	local count = if it_last ~= nil then it_last - it else 1
	assert(it >= 0 and it < size and it + count <= size)
	table.move(self, it + 1 + count, size, it + 1)
	for n = size - count + 1, size do
		self[n] = nil
	end
	self.Size = size - count
	return it
end
function ImVector:erase_unsorted(it)
	local size = self.Size
	assert(it >= 0 and it < size)
	if it < size - 1 then
		self[it + 1] = self[size]
	end
	self[size] = nil
	self.Size = size - 1
	return it
end
function ImVector:insert(it, v)
	local size = self.Size
	assert(it >= 0 and it <= size)
	if size == self.Capacity then
		self:reserve(self:_grow_capacity(size + 1))
	end
	if it < size then
		table.move(self, it + 1, size, it + 2)
	end
	self[it + 1] = v
	self.Size = size + 1
	return it
end
function ImVector:contains(v)
	for i = 1, self.Size do
		if self[i] == v then
			return true
		end
	end
	return false
end
function ImVector:find(v)
	for i = 1, self.Size do
		if self[i] == v then
			return i - 1
		end
	end
	return self.Size
end
function ImVector:find_index(v)
	local it = self:find(v)
	if it == self.Size then
		return -1
	end
	return it
end
function ImVector:find_erase(v)
	local it = self:find(v)
	if it < self.Size then
		self:erase(it)
		return true
	end
	return false
end
function ImVector:find_erase_unsorted(v)
	local it = self:find(v)
	if it < self.Size then
		self:erase_unsorted(it)
		return true
	end
	return false
end
function ImVector:index_from_ptr(v)
	local it = self:find(v)
	assert(it < self.Size)
	return it
end

local function ImBitArrayTestBit(arr, n)
	local mask = lshift(1, band(n, 31))
	return band(arr[rshift(n, 5) + 1] or 0, mask) ~= 0
end
local function ImBitArrayClearBit(arr, n)
	local mask = lshift(1, band(n, 31))
	local w = rshift(n, 5) + 1
	arr[w] = band(arr[w] or 0, bnot(mask))
end
local function ImBitArraySetBit(arr, n)
	local mask = lshift(1, band(n, 31))
	local w = rshift(n, 5) + 1
	arr[w] = bor(arr[w] or 0, mask)
end
Base.ImBitArrayTestBit = ImBitArrayTestBit
Base.ImBitArrayClearBit = ImBitArrayClearBit
Base.ImBitArraySetBit = ImBitArraySetBit

function Base.ImBitArraySetBitRange(arr, n, n2)
	n2 -= 1
	while n <= n2 do
		local a_mod = band(n, 31)
		local b_mod = (if n2 > bor(n, 31) then 31 else band(n2, 31)) + 1
		local mask = 2 ^ b_mod - 2 ^ a_mod
		local w = rshift(n, 5) + 1
		arr[w] = bor(arr[w] or 0, mask)
		n = band(n + 32, bnot(31))
	end
end

function Base.ImBitArrayGetStorageSizeInBytes(bitcount)
	return lshift(rshift(bitcount + 31, 5), 2)
end

function Base.ImBitArrayClearAllBits(arr, bitcount)
	for i = 1, rshift(bitcount + 31, 5) do
		arr[i] = 0
	end
end

local ImBitVector = {}
ImBitVector.__index = ImBitVector
Base.ImBitVector = ImBitVector

function ImBitVector.new()
	return setmetatable({ Storage = ImVector.new() }, ImBitVector)
end
function ImBitVector:Create(sz)
	local storage = self.Storage
	storage:resize(rshift(sz + 31, 5))
	for i = 1, storage.Size do
		storage[i] = 0
	end
end
function ImBitVector:Clear()
	self.Storage:clear()
end
function ImBitVector:TestBit(n)
	assert(n < lshift(self.Storage.Size, 5))
	return ImBitArrayTestBit(self.Storage, n)
end
function ImBitVector:SetBit(n)
	assert(n < lshift(self.Storage.Size, 5))
	ImBitArraySetBit(self.Storage, n)
end
function ImBitVector:ClearBit(n)
	assert(n < lshift(self.Storage.Size, 5))
	ImBitArrayClearBit(self.Storage, n)
end

local ImGuiStoragePair = {}
Base.ImGuiStoragePair = ImGuiStoragePair
function ImGuiStoragePair.new(key, val)
	return { key = key, val_i = val, val_f = val, val_p = val }
end

local function ImLowerBound(data, in_begin, in_end, key)
	local p = in_begin
	local count = in_end - p
	while count > 0 do
		local count2 = rshift(count, 1)
		local mid = p + count2
		if data[mid + 1].key < key then
			p = mid + 1
			count -= count2 + 1
		else
			count = count2
		end
	end
	return p
end
Base.ImLowerBound = ImLowerBound

local function PairComparerByID(lhs, rhs)
	local lhs_v = lhs.key
	local rhs_v = rhs.key
	return if lhs_v > rhs_v then 1 elseif lhs_v < rhs_v then -1 else 0
end

local ImGuiStorage = {}
ImGuiStorage.__index = ImGuiStorage
Base.ImGuiStorage = ImGuiStorage

function ImGuiStorage.new()
	return setmetatable({ Data = ImVector.new() }, ImGuiStorage)
end
function ImGuiStorage:Clear()
	self.Data:clear()
end
function ImGuiStorage:BuildSortByKey()
	ImQsort(self.Data, self.Data.Size, PairComparerByID)
end
local function StorageFind(self, key)
	local data = self.Data
	local it = ImLowerBound(data, 0, data.Size, key)
	if it == data.Size or data[it + 1].key ~= key then
		return nil, it
	end
	return data[it + 1], it
end
function ImGuiStorage:GetInt(key, default_val)
	local pair = StorageFind(self, key)
	if pair == nil then
		return default_val or 0
	end
	return pair.val_i
end
function ImGuiStorage:GetBool(key, default_val)
	return self:GetInt(key, if default_val then 1 else 0) ~= 0
end
function ImGuiStorage:GetFloat(key, default_val)
	local pair = StorageFind(self, key)
	if pair == nil then
		return default_val or 0
	end
	return pair.val_f
end
function ImGuiStorage:GetVoidPtr(key)
	local pair = StorageFind(self, key)
	if pair == nil then
		return nil
	end
	return pair.val_p
end
local function StorageSet(self, key, val)
	local pair, it = StorageFind(self, key)
	if pair == nil then
		self.Data:insert(it, ImGuiStoragePair.new(key, val))
	else
		pair.val_i = val
		pair.val_f = val
		pair.val_p = val
	end
end
ImGuiStorage.SetInt = StorageSet
ImGuiStorage.SetFloat = StorageSet
ImGuiStorage.SetVoidPtr = StorageSet
function ImGuiStorage:SetBool(key, val)
	StorageSet(self, key, if val then 1 else 0)
end
function ImGuiStorage:SetAllInt(v)
	local data = self.Data
	for i = 1, data.Size do
		local pair = data[i]
		pair.val_i = v
		pair.val_f = v
		pair.val_p = v
	end
end

local ImPool = {}
ImPool.__index = ImPool
Base.ImPool = ImPool

function ImPool.new(ctor)
	return setmetatable({
		Buf = ImVector.new(),
		Map = ImGuiStorage.new(),
		FreeIdx = 0,
		AliveCount = 0,
		_Ctor = ctor,
		_IndexOf = {},
		_FreeNext = {},
	}, ImPool)
end
function ImPool:GetByKey(key)
	local idx = self.Map:GetInt(key, -1)
	if idx ~= -1 then
		return self.Buf[idx + 1]
	end
	return nil
end
function ImPool:GetByIndex(n)
	return self.Buf[n + 1]
end
function ImPool:GetIndex(p)
	local idx = self._IndexOf[p]
	assert(idx ~= nil)
	return idx
end
function ImPool:GetOrAddByKey(key)
	local idx = self.Map:GetInt(key, -1)
	if idx ~= -1 then
		return self.Buf[idx + 1]
	end
	self.Map:SetInt(key, self.FreeIdx)
	return self:Add()
end
function ImPool:Contains(p)
	return self._IndexOf[p] ~= nil
end
function ImPool:Clear()
	self.Map:Clear()
	self.Buf:clear()
	self.FreeIdx = 0
	self.AliveCount = 0
	table.clear(self._IndexOf)
	table.clear(self._FreeNext)
end
function ImPool:Add()
	local idx = self.FreeIdx
	if idx == self.Buf.Size then
		self.Buf:resize(self.Buf.Size + 1)
		self.FreeIdx += 1
	else
		self.FreeIdx = self._FreeNext[idx]
		self._FreeNext[idx] = nil
	end
	local obj = self._Ctor()
	self.Buf[idx + 1] = obj
	self._IndexOf[obj] = idx
	self.AliveCount += 1
	return obj
end
function ImPool:Remove(key, p)
	local idx = if type(p) == "number" then p else self:GetIndex(p)
	local obj = self.Buf[idx + 1]
	if obj ~= nil then
		self._IndexOf[obj] = nil
	end
	self.Buf[idx + 1] = nil
	self._FreeNext[idx] = self.FreeIdx
	self.FreeIdx = idx
	self.Map:SetInt(key, -1)
	self.AliveCount -= 1
end
function ImPool:Reserve(capacity)
	self.Buf:reserve(capacity)
	self.Map.Data:reserve(capacity)
end
function ImPool:GetAliveCount()
	return self.AliveCount
end
function ImPool:GetBufSize()
	return self.Buf.Size
end
function ImPool:GetMapSize()
	return self.Map.Data.Size
end
function ImPool:TryGetMapData(n)
	local idx = self.Map.Data[n + 1].val_i
	if idx == -1 then
		return nil
	end
	return self:GetByIndex(idx)
end

local ImChunkStream = {}
ImChunkStream.__index = ImChunkStream
Base.ImChunkStream = ImChunkStream

function ImChunkStream.new()
	return setmetatable({ Buf = ImVector.new(), _Offsets = {} }, ImChunkStream)
end
function ImChunkStream:clear()
	self.Buf:clear()
	table.clear(self._Offsets)
end
function ImChunkStream:empty()
	return self.Buf.Size == 0
end
function ImChunkStream:size()
	return self.Buf.Size
end
function ImChunkStream:alloc_chunk(obj)
	self._Offsets[obj] = self.Buf.Size
	self.Buf:push_back(obj)
	return obj
end
function ImChunkStream:begin()
	if self.Buf.Size == 0 then
		return nil
	end
	return self.Buf[1]
end
function ImChunkStream:next_chunk(p)
	local off = self._Offsets[p]
	assert(off ~= nil)
	if off + 1 >= self.Buf.Size then
		return nil
	end
	return self.Buf[off + 2]
end
function ImChunkStream:offset_from_ptr(p)
	local off = self._Offsets[p]
	assert(off ~= nil)
	return off
end
function ImChunkStream:ptr_from_offset(off)
	assert(off >= 0 and off < self.Buf.Size)
	return self.Buf[off + 1]
end
function ImChunkStream:swap(rhs)
	self.Buf, rhs.Buf = rhs.Buf, self.Buf
	self._Offsets, rhs._Offsets = rhs._Offsets, self._Offsets
end

local ImGuiTextIndex = {}
ImGuiTextIndex.__index = ImGuiTextIndex
Base.ImGuiTextIndex = ImGuiTextIndex

function ImGuiTextIndex.new()
	return setmetatable({ Offsets = ImVector.new(), EndOffset = 0 }, ImGuiTextIndex)
end
function ImGuiTextIndex:clear()
	self.Offsets:clear()
	self.EndOffset = 0
end
function ImGuiTextIndex:size()
	return self.Offsets.Size
end
function ImGuiTextIndex:get_line_begin(base, n)
	return 1 + (if self.Offsets.Size ~= 0 then self.Offsets[n + 1] else 0)
end
function ImGuiTextIndex:get_line_end(base, n)
	return 1 + (if n + 1 < self.Offsets.Size then (self.Offsets[n + 2] - 1) else self.EndOffset)
end
function ImGuiTextIndex:append(base, old_size, new_size)
	assert(old_size >= 0 and new_size >= old_size and new_size >= self.EndOffset)
	if old_size == new_size then
		return
	end
	if self.EndOffset == 0 or sbyte(base, self.EndOffset) == 10 then
		self.Offsets:push_back(self.EndOffset)
	end
	local p = old_size
	while true do
		local found = sfind(base, "\n", p + 1, true)
		if found == nil or found > new_size then
			break
		end
		p = found
		if p < new_size then
			self.Offsets:push_back(p)
		end
	end
	self.EndOffset = ImMax(self.EndOffset, new_size)
end

local ImGuiTextBuffer = {}
Base.ImGuiTextBuffer = ImGuiTextBuffer
ImGuiTextBuffer.EmptyString = ""

local TextBufferBuf = {}
TextBufferBuf.__index = TextBufferBuf

local function TextBufferSetText(self, s)
	local parts = self._Parts
	table.clear(parts)
	if #s > 0 then
		parts[1] = s
	end
end

function ImGuiTextBuffer.new()
	local self = setmetatable({ _Parts = {} }, ImGuiTextBuffer)
	self.Buf = setmetatable({ Size = 0, Capacity = 0, _Owner = self }, TextBufferBuf)
	return self
end
function ImGuiTextBuffer:c_str()
	local parts = self._Parts
	local n = #parts
	if n == 0 then
		return ""
	elseif n > 1 then
		local s = table.concat(parts)
		table.clear(parts)
		parts[1] = s
		return s
	end
	return parts[1]
end
ImGuiTextBuffer.begin = ImGuiTextBuffer.c_str
ImGuiTextBuffer["end"] = function(self)
	return self:size() + 1
end
ImGuiTextBuffer.__index = function(self, k)
	if type(k) == "number" then
		return sbyte(ImGuiTextBuffer.c_str(self), k)
	end
	return ImGuiTextBuffer[k]
end
function ImGuiTextBuffer:size()
	local n = self.Buf.Size
	return if n ~= 0 then n - 1 else 0
end
function ImGuiTextBuffer:empty()
	return self.Buf.Size <= 1
end
function ImGuiTextBuffer:clear()
	table.clear(self._Parts)
	self.Buf.Size = 0
	self.Buf.Capacity = 0
end
function ImGuiTextBuffer:resize(size)
	local s = self:c_str()
	if #s > size then
		s = ssub(s, 1, size)
	elseif #s < size then
		s ..= string.rep("\0", size - #s)
	end
	TextBufferSetText(self, s)
	self.Buf.Size = if size ~= 0 then size + 1 else 0
end
function ImGuiTextBuffer:reserve(capacity)
	self.Buf:reserve(capacity)
end
function ImGuiTextBuffer:append(str, str_end)
	local len = if str_end ~= nil then str_end - 1 else #str
	if len < #str then
		str = ssub(str, 1, len)
	end
	local buf = self.Buf
	local write_off = if buf.Size ~= 0 then buf.Size else 1
	local needed_sz = write_off + len
	if needed_sz >= buf.Capacity then
		local new_capacity = buf.Capacity * 2
		buf:reserve(if needed_sz > new_capacity then needed_sz else new_capacity)
	end
	buf.Size = needed_sz
	if len > 0 then
		local parts = self._Parts
		parts[#parts + 1] = str
	end
end
function ImGuiTextBuffer:appendf(fmt, ...)
	local s = ImFormatString(fmt, ...)
	if #s <= 0 then
		return
	end
	self:append(s)
end
ImGuiTextBuffer.appendfv = ImGuiTextBuffer.appendf

function TextBufferBuf:reserve(capacity)
	if capacity > self.Capacity then
		self.Capacity = capacity
	end
end
function TextBufferBuf:resize(n)
	local owner = self._Owner
	local len = if n > 0 then n - 1 else 0
	local s = owner:c_str()
	if #s > len then
		s = ssub(s, 1, len)
	elseif #s < len then
		s ..= string.rep("\0", len - #s)
	end
	TextBufferSetText(owner, s)
	self:reserve(n)
	self.Size = n
end
function TextBufferBuf:push_back(c)
	if self.Size ~= 0 and c ~= 0 then
		self._Owner:append(schar(c))
	else
		self.Size += 1
	end
end
function TextBufferBuf:clear()
	self._Owner:clear()
end

local ImGuiTextFilterItem = {}
ImGuiTextFilterItem.__index = ImGuiTextFilterItem
Base.ImGuiTextFilterItem = ImGuiTextFilterItem

function ImGuiTextFilterItem.new(b, e)
	assert(e > b)
	return setmetatable({ Begin = b, Len = e - b, CountInclude = 0, MatchIncludesMask = 0 }, ImGuiTextFilterItem)
end

local ImGuiTextFilter = {}
ImGuiTextFilter.__index = ImGuiTextFilter
Base.ImGuiTextFilter = ImGuiTextFilter

function ImGuiTextFilter.new(default_filter)
	if default_filter == nil then
		default_filter = ""
	end
	local self = setmetatable({ InputBuf = "", _CountExclude = 0, _Items = ImVector.new() }, ImGuiTextFilter)
	self.InputBuf = ImStrncpy(default_filter, 256)
	self:Build()
	return self
end
function ImGuiTextFilter:Clear()
	self.InputBuf = ""
	self:Build()
end
function ImGuiTextFilter:IsActive()
	return self._Items.Size ~= 0
end
function ImGuiTextFilter:Draw(label)
	if label == nil then
		label = "Filter"
	end
	return self:DrawWithHint(label, "incl -excl")
end
function ImGuiTextFilter:DrawWithHint(label, hint)
	if label == nil then
		label = "Filter"
	end
	if hint == nil then
		hint = "incl -excl"
	end
	local value_changed
	value_changed, self.InputBuf = ImGui.InputTextWithHint(label, hint, self.InputBuf)
	if value_changed then
		self:Build()
	end
	return value_changed
end
function ImGuiTextFilter:Build()
	local items = self._Items
	items:resize(0)
	self._CountExclude = 0
	local buf = self.InputBuf
	local buf_e = #buf + 1
	local seq_start_idx = -1
	local word_b = 1
	while word_b < buf_e do
		while word_b < buf_e and ImCharIsBlankA(sbyte(buf, word_b)) do
			word_b += 1
		end
		local is_excl = word_b < buf_e and sbyte(buf, word_b) == 45
		if is_excl then
			word_b += 1
		end
		local is_quote = word_b < buf_e and sbyte(buf, word_b) == 34
		local word_e
		if is_quote then
			word_b += 1
			word_e = ImStrchrRange(buf, word_b, buf_e, 34)
			if word_e == nil then
				word_e = buf_e
			end
		else
			word_e = word_b
			while word_e < buf_e do
				local c = sbyte(buf, word_e)
				if c == 32 or c == 44 then
					break
				end
				word_e += 1
			end
		end
		if word_e - word_b > 0 then
			if is_excl then
				items:insert(self._CountExclude, ImGuiTextFilterItem.new(word_b, word_e))
				self._CountExclude += 1
				if seq_start_idx ~= -1 then
					seq_start_idx += 1
				end
			else
				if seq_start_idx == -1 then
					seq_start_idx = items.Size
				end
				items:insert(items.Size, ImGuiTextFilterItem.new(word_b, word_e))
				local seq_item = items[seq_start_idx + 1]
				seq_item.CountInclude += 1
			end
		end
		if sbyte(buf, word_e) == 44 then
			seq_start_idx = -1
		end
		word_b = word_e + 1
	end
end
function ImGuiTextFilter:PassFilter(text, text_end)
	local items = self._Items
	if items.Size == 0 then
		return true
	end
	if text == nil then
		text = ""
		text_end = 1
	end
	local buf = self.InputBuf
	local seq = 0
	local seq_excl_end = self._CountExclude
	while seq < seq_excl_end do
		local item = items[seq + 1]
		if ImStristrRange(text, 1, text_end, buf, item.Begin, item.Begin + item.Len) ~= nil then
			return false
		end
		seq += 1
	end
	local seq_end = items.Size
	if seq == seq_end then
		return true
	end
	while seq < seq_end do
		local seq_incl_end = seq + items[seq + 1].CountInclude
		while seq < seq_incl_end do
			local item = items[seq + 1]
			if ImStristrRange(text, 1, text_end, buf, item.Begin, item.Begin + item.Len) == nil then
				break
			end
			seq += 1
		end
		if seq == seq_incl_end then
			return true
		end
		seq = seq_incl_end
	end
	return false
end

return Base
