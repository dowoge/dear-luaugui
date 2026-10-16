--!native
local ImGui = require("./Namespace")
local Base = require("./Base")
local Enums = require("./Enums")

local ImVec4 = Base.ImVec4
local ImVector = Base.ImVector
local ImTextCharFromUtf8 = Base.ImTextCharFromUtf8
local FLT_MAX = Base.FLT_MAX

local ImDrawFlags = Enums.ImDrawFlags
local ImDrawTextFlags = Enums.ImDrawTextFlags
local ImFontFlags = Enums.ImFontFlags
local ImTextureFormat = Enums.ImTextureFormat
local ImTextureStatus = Enums.ImTextureStatus
local ImGuiCol = Enums.ImGuiCol
local ImGuiDir = Enums.ImGuiDir
local ImGuiBackendFlags = Enums.ImGuiBackendFlags
local ImGuiDebugLogFlags = Enums.ImGuiDebugLogFlags
local ImWcharClass = Enums.ImWcharClass

local band, bor, bnot, btest, lshift, rshift = bit32.band, bit32.bor, bit32.bnot, bit32.btest, bit32.lshift, bit32.rshift
local vcreate = vector.create
local floor, ceil, sqrt, cos, sin, abs, max, min = math.floor, math.ceil, math.sqrt, math.cos, math.sin, math.abs, math.max, math.min
local sbyte, ssub, sfind = string.byte, string.sub, string.find
local IM_PI = math.pi

local IM_COL32_A_MASK = 0xFF000000
local IM_DRAWLIST_ARCFAST_TABLE_SIZE = 48
local IM_DRAWLIST_ARCFAST_SAMPLE_MAX = 48
local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN = 4
local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX = 512
local IM_TABSIZE = 4
local IM_FONTGLYPH_INDEX_UNUSED = 0xFFFF
local IM_FONTGLYPH_INDEX_NOT_FOUND = 0xFFFE
local IM_UNICODE_CODEPOINT_INVALID = 0xFFFD
local IM_UNICODE_CODEPOINT_MAX = 0x10FFFF
local PRIM_STRIDE = 12
local DEFAULT_ADVANCE_RATIO = 7 / 13
local ROBLOX_FONT_NAME = "Code"

local DF_Closed = ImDrawFlags.Closed
local DF_JoinMiter = ImDrawFlags.JoinMiter
local DF_CapSquare = ImDrawFlags.CapSquare
local DF_AALines = ImDrawFlags.AALines
local DF_AALineEnds = ImDrawFlags.AALineEnds
local DF_StrokeInside = ImDrawFlags.StrokeInside
local DF_StrokeCenter = ImDrawFlags.StrokeCenter
local DF_StrokeCenterBiased = ImDrawFlags.StrokeCenterBiased
local DF_StrokeOutside = ImDrawFlags.StrokeOutside
local DF_StrokeLegacy = ImDrawFlags.StrokeLegacy
local DF_StrokeMask = ImDrawFlags.StrokeMask_
local DF_RoundMask = ImDrawFlags.RoundMask_
local DF_RoundAll = ImDrawFlags.RoundAll
local DF_RoundNone = ImDrawFlags.RoundNone
local DF_RoundTopLeft = ImDrawFlags.RoundTopLeft
local DF_RoundTopRight = ImDrawFlags.RoundTopRight
local DF_RoundBottomLeft = ImDrawFlags.RoundBottomLeft
local DF_RoundBottomRight = ImDrawFlags.RoundBottomRight
local DF_RoundTop = ImDrawFlags.RoundTop
local DF_RoundBottom = ImDrawFlags.RoundBottom
local DF_RoundLeft = ImDrawFlags.RoundLeft
local DF_RoundRight = ImDrawFlags.RoundRight
local DF_TextNoPixelSnap = ImDrawFlags.TextNoPixelSnap
local DF_InvalidMask = ImDrawFlags.InvalidMask_

local PrimKind = {
	RectFilled = 1,
	Rect = 2,
	Line = 3,
	TriangleFilled = 4,
	TriangleMultiColor = 5,
	CircleFilled = 6,
	Circle = 7,
	Text = 8,
	Image = 9,
	RectMultiColor = 10,
}
local PK_RectFilled = PrimKind.RectFilled
local PK_Rect = PrimKind.Rect
local PK_Line = PrimKind.Line
local PK_TriangleFilled = PrimKind.TriangleFilled
local PK_TriangleMultiColor = PrimKind.TriangleMultiColor
local PK_CircleFilled = PrimKind.CircleFilled
local PK_Circle = PrimKind.Circle
local PK_Text = PrimKind.Text
local PK_Image = PrimKind.Image
local PK_RectMultiColor = PrimKind.RectMultiColor

local ZERO4 = ImVec4(0, 0, 0, 0)
local MonoInfos = setmetatable({}, { __mode = "k" })
local VEC2_ZERO = vcreate(0, 0, 0)

local DrawList = {}

local function trunc(x)
	if x >= 0 then
		return floor(x)
	end
	return -floor(-x)
end

local function IM_ROUND(x)
	return trunc(x + 0.5)
end

local function IsTruncated(x)
	return x == trunc(x)
end

local function UserError(msg)
	local f = ImGui.ErrorLog
	if f == nil or ImGui.GImGui == nil or f(msg) then
		error(msg, 2)
	end
end

local function DebugLogFont(fmt, ...)
	local g = ImGui.GImGui
	if g ~= nil and btest(g.DebugLogFlags, ImGuiDebugLogFlags.EventFont) then
		ImGui.DebugLog(fmt, ...)
	end
end

local function Vec4Eq(a, b)
	return a == b or (a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w)
end

local function HeaderEq(a, b)
	return Vec4Eq(a.ClipRect, b.ClipRect) and a.TexRef == b.TexRef and a.VtxOffset == b.VtxOffset
end

local function HeaderCopy(dst, src)
	dst.ClipRect = src.ClipRect
	dst.TexRef = src.TexRef
	dst.VtxOffset = src.VtxOffset
end

local function ImAlphaMultiply(col, alpha_mul)
	local a = rshift(col, 24)
	a = trunc(a * alpha_mul)
	return bor(band(col, 0x00FFFFFF), lshift(a, 24))
end

local function GetStrokePos(flags, default_stroke_pos)
	local s = band(flags, DF_StrokeMask)
	if s ~= 0 then
		return s
	end
	return default_stroke_pos
end

local function CircleAutoSegmentCalc(rad, max_error)
	local v = trunc(ceil(IM_PI / math.acos(1 - min(max_error, rad) / rad)))
	v = ((v + 1) // 2) * 2
	return math.clamp(v, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX)
end

local function CircleAutoSegmentCalcR(n, max_error)
	return max_error / (1 - cos(IM_PI / max(n, IM_PI)))
end

local function PushPrim(dl, kind, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
	local pb = dl.PrimBuffer
	local b = dl.PrimCount * PRIM_STRIDE
	pb[b + 1] = kind
	pb[b + 2] = a1
	pb[b + 3] = a2
	pb[b + 4] = a3
	pb[b + 5] = a4
	pb[b + 6] = a5
	pb[b + 7] = a6
	pb[b + 8] = a7
	pb[b + 9] = a8
	pb[b + 10] = a9
	pb[b + 11] = a10
	pb[b + 12] = a11
	dl.PrimCount += 1
	local cb = dl.CmdBuffer
	local cmd = cb[cb.Size]
	cmd.ElemCount += 1
end

local ImTextureData = {}
ImTextureData.__index = ImTextureData

local function ImTextureRefGetTexID(tex_ref)
	if type(tex_ref) == "table" and getmetatable(tex_ref) == ImTextureData then
		return tex_ref.TexID
	end
	return tex_ref
end

local ImDrawCmd = {}
ImDrawCmd.__index = ImDrawCmd

function ImDrawCmd.new()
	return setmetatable({
		ClipRect = ZERO4,
		TexRef = nil,
		VtxOffset = 0,
		IdxOffset = 0,
		ElemCount = 0,
		UserCallback = nil,
		UserCallbackData = nil,
		UserCallbackDataSize = 0,
		UserCallbackDataOffset = 0,
	}, ImDrawCmd)
end

function ImDrawCmd:Copy()
	local c = ImDrawCmd.new()
	c.ClipRect = self.ClipRect
	c.TexRef = self.TexRef
	c.VtxOffset = self.VtxOffset
	c.IdxOffset = self.IdxOffset
	c.ElemCount = self.ElemCount
	c.UserCallback = self.UserCallback
	c.UserCallbackData = self.UserCallbackData
	c.UserCallbackDataSize = self.UserCallbackDataSize
	c.UserCallbackDataOffset = self.UserCallbackDataOffset
	return c
end

function ImDrawCmd:GetTexID()
	local tex_ref = self.TexRef
	local tex_id = ImTextureRefGetTexID(tex_ref)
	if tex_ref ~= tex_id then
		assert(tex_id ~= nil, "ImDrawCmd is referring to ImTextureData that wasn't uploaded to graphics system. Backend must call ImTextureData::SetTexID() after handling ImTextureStatus_WantCreate request!")
	end
	return tex_id
end

local ImDrawCmdHeader = {}
ImDrawCmdHeader.__index = ImDrawCmdHeader

function ImDrawCmdHeader.new()
	return setmetatable({ ClipRect = ZERO4, TexRef = nil, VtxOffset = 0 }, ImDrawCmdHeader)
end

function ImDrawCmdHeader:Copy()
	local h = ImDrawCmdHeader.new()
	HeaderCopy(h, self)
	return h
end

local ImDrawChannel = {}
ImDrawChannel.__index = ImDrawChannel

function ImDrawChannel.new()
	return setmetatable({ _CmdBuffer = ImVector.new(), _PrimBuffer = {}, _PrimCount = 0 }, ImDrawChannel)
end

local ImDrawListSharedData = {}
ImDrawListSharedData.__index = ImDrawListSharedData

function ImDrawListSharedData.new()
	local self = setmetatable({
		TexUvWhitePixel = VEC2_ZERO,
		TexUvLines = nil,
		TexUvCorners = nil,
		FontAtlas = nil,
		Font = nil,
		FontSize = 0,
		FontScale = 0,
		CurveTessellationMaxError = 0,
		CircleTessellationMaxError = 0,
		InitialDrawFlags = 0,
		ClipRectFullscreen = ZERO4,
		TempBuffer = ImVector.new(),
		DrawLists = ImVector.new(),
		Context = nil,
		ArcFastVtx = table.create(IM_DRAWLIST_ARCFAST_TABLE_SIZE),
		ArcFastRadiusCutoff = 0,
		CircleSegmentCounts = table.create(64, 0),
	}, ImDrawListSharedData)
	for i = 0, IM_DRAWLIST_ARCFAST_TABLE_SIZE - 1 do
		local a = (i * 2 * IM_PI) / IM_DRAWLIST_ARCFAST_TABLE_SIZE
		self.ArcFastVtx[i + 1] = vcreate(cos(a), sin(a), 0)
	end
	return self
end

function ImDrawListSharedData:SetCircleTessellationMaxError(max_error)
	if self.CircleTessellationMaxError == max_error then
		return
	end
	assert(max_error > 0)
	self.CircleTessellationMaxError = max_error
	for i = 0, 63 do
		local radius = i
		local v = if i > 0 then CircleAutoSegmentCalc(radius, max_error) else IM_DRAWLIST_ARCFAST_SAMPLE_MAX
		self.CircleSegmentCounts[i + 1] = band(v, 0xFF)
	end
	self.ArcFastRadiusCutoff = CircleAutoSegmentCalcR(IM_DRAWLIST_ARCFAST_SAMPLE_MAX, max_error)
end

local ImDrawListSplitter = {}
ImDrawListSplitter.__index = ImDrawListSplitter

function ImDrawListSplitter.new()
	return setmetatable({ _Current = 0, _Count = 0, _Channels = ImVector.new() }, ImDrawListSplitter)
end

function ImDrawListSplitter:Clear()
	self._Current = 0
	self._Count = 1
end

local ImDrawList = {}
ImDrawList.__index = ImDrawList

function ImDrawList.new(shared_data)
	local self = setmetatable({
		CmdBuffer = ImVector.new(),
		PrimBuffer = {},
		PrimCount = 0,
		Flags = 0,
		_VtxCurrentIdx = 0,
		_Data = nil,
		_Path = ImVector.new(),
		_CmdHeader = ImDrawCmdHeader.new(),
		_Splitter = ImDrawListSplitter.new(),
		_ClipRectStack = ImVector.new(),
		_TextureStack = ImVector.new(),
		_CallbacksDataBuf = ImVector.new(),
		_DrawFlagsStack = ImVector.new(),
		_FringeScale = 1,
		_InvFringeScale = 1,
		_FringeScaleIsInteger = true,
		_OwnerName = nil,
		_PathRectEnd = -1,
		_PathRectMin = VEC2_ZERO,
		_PathRectMax = VEC2_ZERO,
		_PathRectRounding = 0,
		_PathRectFlags = 0,
		_PrimVtxPos = {},
		_PrimVtxCol = {},
		_PrimIdx = {},
		_PrimIdxCount = 0,
		_PrimIdxRead = 1,
	}, ImDrawList)
	self:_SetDrawListSharedData(shared_data)
	return self
end

function ImDrawList:_SetDrawListSharedData(data)
	if self._Data ~= nil then
		self._Data.DrawLists:find_erase_unsorted(self)
	end
	self._Data = data
	if data ~= nil then
		data.DrawLists:push_back(self)
	end
end

local function PrimVtxReset(self)
	table.clear(self._PrimVtxPos)
	table.clear(self._PrimVtxCol)
	table.clear(self._PrimIdx)
	self._PrimIdxCount = 0
	self._PrimIdxRead = 1
end

function ImDrawList:_ResetForNewFrame()
	if self._Splitter._Count > 1 then
		self._Splitter:Merge(self)
	end
	self.CmdBuffer:resize(0)
	self.PrimCount = 0
	self.Flags = self._Data.InitialDrawFlags
	assert(band(self.Flags, bnot(ImDrawFlags.AllowInFrameScope_)) == 0)
	local h = self._CmdHeader
	h.ClipRect = ZERO4
	h.TexRef = nil
	h.VtxOffset = 0
	self._VtxCurrentIdx = 0
	self._ClipRectStack:resize(0)
	self._TextureStack:resize(0)
	self._CallbacksDataBuf:resize(0)
	self._DrawFlagsStack:resize(0)
	self._Path:resize(0)
	self._PathRectEnd = -1
	PrimVtxReset(self)
	self._Splitter:Clear()
	self.CmdBuffer:push_back(ImDrawCmd.new())
end

function ImDrawList:_ClearFreeMemory()
	self.CmdBuffer:clear()
	self.PrimBuffer = {}
	self.PrimCount = 0
	self.Flags = ImDrawFlags.None
	self._VtxCurrentIdx = 0
	self._ClipRectStack:clear()
	self._TextureStack:clear()
	self._CallbacksDataBuf:clear()
	self._DrawFlagsStack:clear()
	self._Path:clear()
	self._PathRectEnd = -1
	PrimVtxReset(self)
	self._Splitter:ClearFreeMemory()
end

function ImDrawList:CloneOutput()
	local dst = ImDrawList.new(nil)
	for i = 1, self.CmdBuffer.Size do
		dst.CmdBuffer:push_back(self.CmdBuffer[i]:Copy())
	end
	dst.PrimBuffer = table.move(self.PrimBuffer, 1, self.PrimCount * PRIM_STRIDE, 1, {})
	dst.PrimCount = self.PrimCount
	dst.Flags = self.Flags
	return dst
end

function ImDrawList:GetPrimCount()
	return self.PrimCount
end

function ImDrawList:AddDrawCmd()
	local draw_cmd = ImDrawCmd.new()
	HeaderCopy(draw_cmd, self._CmdHeader)
	draw_cmd.IdxOffset = self.PrimCount
	local cr = draw_cmd.ClipRect
	assert(cr.x <= cr.z and cr.y <= cr.w)
	self.CmdBuffer:push_back(draw_cmd)
end

function ImDrawList:_PopUnusedDrawCmd()
	local cb = self.CmdBuffer
	while cb.Size > 0 do
		local curr_cmd = cb[cb.Size]
		if curr_cmd.ElemCount ~= 0 or curr_cmd.UserCallback ~= nil then
			return
		end
		cb:pop_back()
	end
end

function ImDrawList:AddCallback(callback, userdata, userdata_size)
	if userdata_size == nil then
		userdata_size = 0
	end
	assert(callback ~= nil)
	local cb = self.CmdBuffer
	local curr_cmd = cb[cb.Size]
	assert(curr_cmd.UserCallback == nil)
	if curr_cmd.ElemCount ~= 0 then
		self:AddDrawCmd()
		curr_cmd = cb[cb.Size]
	end
	curr_cmd.UserCallback = callback
	if userdata_size == 0 then
		curr_cmd.UserCallbackData = userdata
		curr_cmd.UserCallbackDataSize = 0
		curr_cmd.UserCallbackDataOffset = -1
	else
		assert(userdata ~= nil)
		curr_cmd.UserCallbackData = userdata
		curr_cmd.UserCallbackDataSize = userdata_size
		curr_cmd.UserCallbackDataOffset = -1
	end
	self:AddDrawCmd()
end

local function AreSequentialIdxOffset(cmd0, cmd1)
	return cmd0.IdxOffset + cmd0.ElemCount == cmd1.IdxOffset
end

function ImDrawList:_TryMergeDrawCmds()
	local cb = self.CmdBuffer
	local curr_cmd = cb[cb.Size]
	local prev_cmd = cb[cb.Size - 1]
	if prev_cmd == nil then
		return
	end
	if HeaderEq(curr_cmd, prev_cmd) and AreSequentialIdxOffset(prev_cmd, curr_cmd) and curr_cmd.UserCallback == nil and prev_cmd.UserCallback == nil then
		prev_cmd.ElemCount += curr_cmd.ElemCount
		cb:pop_back()
	end
end

function ImDrawList:_OnChangedClipRect()
	local cb = self.CmdBuffer
	local curr_cmd = cb[cb.Size]
	local header = self._CmdHeader
	if curr_cmd.ElemCount ~= 0 and not Vec4Eq(curr_cmd.ClipRect, header.ClipRect) then
		self:AddDrawCmd()
		return
	end
	assert(curr_cmd.UserCallback == nil)
	local prev_cmd = cb[cb.Size - 1]
	if curr_cmd.ElemCount == 0 and cb.Size > 1 and HeaderEq(header, prev_cmd) and AreSequentialIdxOffset(prev_cmd, curr_cmd) and prev_cmd.UserCallback == nil then
		cb:pop_back()
		return
	end
	curr_cmd.ClipRect = header.ClipRect
end

function ImDrawList:_OnChangedTexture()
	local cb = self.CmdBuffer
	local curr_cmd = cb[cb.Size]
	local header = self._CmdHeader
	if curr_cmd.ElemCount ~= 0 and curr_cmd.TexRef ~= header.TexRef then
		self:AddDrawCmd()
		return
	end
	if curr_cmd.UserCallback ~= nil then
		return
	end
	local prev_cmd = cb[cb.Size - 1]
	if curr_cmd.ElemCount == 0 and cb.Size > 1 and HeaderEq(header, prev_cmd) and AreSequentialIdxOffset(prev_cmd, curr_cmd) and prev_cmd.UserCallback == nil then
		cb:pop_back()
		return
	end
	curr_cmd.TexRef = header.TexRef
end

function ImDrawList:_OnChangedVtxOffset() end

function ImDrawList:_CalcCircleAutoSegmentCount(radius)
	radius *= self._InvFringeScale
	local radius_idx = trunc(radius + 0.999)
	if radius_idx >= 0 and radius_idx < 64 then
		return self._Data.CircleSegmentCounts[radius_idx + 1]
	end
	return CircleAutoSegmentCalc(radius, self._Data.CircleTessellationMaxError)
end

function ImDrawList:PushClipRect(cr_min, cr_max, intersect_with_current_clip_rect)
	local x, y, z, w = cr_min.x, cr_min.y, cr_max.x, cr_max.y
	if intersect_with_current_clip_rect then
		local current = self._CmdHeader.ClipRect
		if x < current.x then
			x = current.x
		end
		if y < current.y then
			y = current.y
		end
		if z > current.z then
			z = current.z
		end
		if w > current.w then
			w = current.w
		end
	end
	if z < x then
		z = x
	end
	if w < y then
		w = y
	end
	local cr = ImVec4(x, y, z, w)
	self._ClipRectStack:push_back(cr)
	self._CmdHeader.ClipRect = cr
	self:_OnChangedClipRect()
end

function ImDrawList:PushClipRectFullScreen()
	local cr = self._Data.ClipRectFullscreen
	self:PushClipRect(vcreate(cr.x, cr.y, 0), vcreate(cr.z, cr.w, 0))
end

function ImDrawList:PopClipRect()
	local stack = self._ClipRectStack
	stack:pop_back()
	self._CmdHeader.ClipRect = if stack.Size == 0 then self._Data.ClipRectFullscreen else stack[stack.Size]
	self:_OnChangedClipRect()
end

function ImDrawList:GetClipRectMin()
	local cr = self._ClipRectStack:back()
	return vcreate(cr.x, cr.y, 0)
end

function ImDrawList:GetClipRectMax()
	local cr = self._ClipRectStack:back()
	return vcreate(cr.z, cr.w, 0)
end

function ImDrawList:PushTexture(tex_ref)
	self._TextureStack:push_back(tex_ref)
	self._CmdHeader.TexRef = tex_ref
	if type(tex_ref) == "table" and getmetatable(tex_ref) == ImTextureData then
		assert(tex_ref.Status ~= ImTextureStatus.WantDestroy and tex_ref.Status ~= ImTextureStatus.Destroyed)
	end
	self:_OnChangedTexture()
end

function ImDrawList:PopTexture()
	local stack = self._TextureStack
	stack:pop_back()
	self._CmdHeader.TexRef = if stack.Size == 0 then nil else stack[stack.Size]
	self:_OnChangedTexture()
end

function ImDrawList:PushDrawFlag(flags, enabled)
	assert(band(flags, bnot(ImDrawFlags.AllowInPushScope_)) == 0)
	assert(band(flags, DF_StrokeMask) == 0 or band(flags, DF_StrokeMask) == DF_StrokeLegacy)
	if not (self._DrawFlagsStack.Size < 3) then
		UserError("PushDrawFlag() has a depth limit. Contact us.")
		return
	end
	self._DrawFlagsStack:push_back(self.Flags)
	if enabled then
		self.Flags = bor(self.Flags, flags)
	else
		self.Flags = band(self.Flags, bnot(flags))
	end
end

function ImDrawList:PopDrawFlag()
	if not (self._DrawFlagsStack.Size > 0) then
		UserError("Calling PopDrawFlag() too many times!")
		return
	end
	self.Flags = self._DrawFlagsStack:back()
	self._DrawFlagsStack:pop_back()
end

function ImDrawList:_SetTexture(tex_ref)
	if self._CmdHeader.TexRef == tex_ref then
		return
	end
	self._CmdHeader.TexRef = tex_ref
	local stack = self._TextureStack
	if stack.Size > 0 then
		stack[stack.Size] = tex_ref
	end
	self:_OnChangedTexture()
end

function ImDrawList:_SetPixelDensity(pixel_density)
	assert(pixel_density > 0)
	self._FringeScale = 1 / pixel_density
	self._InvFringeScale = pixel_density
	self._FringeScaleIsInteger = IsTruncated(self._InvFringeScale)
end

local function FlushPrimTris(self)
	local idx = self._PrimIdx
	local r = self._PrimIdxRead
	local n = self._PrimIdxCount
	local vp, vc = self._PrimVtxPos, self._PrimVtxCol
	while n - r + 1 >= 3 do
		local i0, i1, i2 = idx[r], idx[r + 1], idx[r + 2]
		local p0, p1, p2 = vp[i0], vp[i1], vp[i2]
		if p0 == nil or p1 == nil or p2 == nil then
			break
		end
		PushPrim(self, PK_TriangleMultiColor, p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, vc[i0], vc[i1], vc[i2], 0, 0)
		r += 3
	end
	self._PrimIdxRead = r
end

function ImDrawList:PrimReserve(idx_count, vtx_count)
	assert(idx_count >= 0 and vtx_count >= 0)
	PrimVtxReset(self)
end

function ImDrawList:PrimUnreserve(idx_count, vtx_count)
	assert(idx_count >= 0 and vtx_count >= 0)
	PrimVtxReset(self)
end

function ImDrawList:PrimRect(a, c, col)
	PushPrim(self, PK_RectFilled, a.x, a.y, c.x, c.y, col, 0, 0, 0, 0, 0, 0)
end

function ImDrawList:PrimRectUV(a, c, uv_a, uv_c, col)
	PushPrim(self, PK_Image, a.x, a.y, c.x, c.y, uv_a.x, uv_a.y, uv_c.x, uv_c.y, col, self._CmdHeader.TexRef, 0)
end

function ImDrawList:PrimQuadUV(a, b, c, d, uv_a, uv_b, uv_c, uv_d, col)
	local x1, y1 = min(a.x, b.x, c.x, d.x), min(a.y, b.y, c.y, d.y)
	local x2, y2 = max(a.x, b.x, c.x, d.x), max(a.y, b.y, c.y, d.y)
	PushPrim(self, PK_Image, x1, y1, x2, y2, uv_a.x, uv_a.y, uv_c.x, uv_c.y, col, self._CmdHeader.TexRef, 0)
end

function ImDrawList:PrimWriteVtx(pos, uv, col)
	local i = self._VtxCurrentIdx
	self._PrimVtxPos[i] = pos
	self._PrimVtxCol[i] = col
	self._VtxCurrentIdx = i + 1
	FlushPrimTris(self)
end

function ImDrawList:PrimWriteIdx(idx)
	local n = self._PrimIdxCount + 1
	self._PrimIdx[n] = idx
	self._PrimIdxCount = n
	FlushPrimTris(self)
end

function ImDrawList:PrimVtx(pos, uv, col)
	self:PrimWriteIdx(self._VtxCurrentIdx)
	self:PrimWriteVtx(pos, uv, col)
end

function ImDrawList:_CalculateCenterBiasedOffset(thickness)
	local screen_thickness = thickness * self._InvFringeScale
	local s_thickness = trunc(screen_thickness)
	return ((s_thickness // 2) + band(s_thickness, 1) * (screen_thickness - s_thickness)) * self._FringeScale
end

function ImDrawList:_SelectLineTexture(screen_thickness, out_uv0, out_uv1, out_fringe, flags)
	local uv = self._Data.TexUvWhitePixel
	return uv, uv, 0
end

local function StrokeOffsets(self, stroke_pos, thickness)
	local thickness0 = thickness * 0.5
	if stroke_pos == DF_StrokeOutside then
		thickness0 = thickness
	elseif stroke_pos == DF_StrokeCenterBiased then
		thickness0 = self:_CalculateCenterBiasedOffset(thickness)
	elseif stroke_pos == DF_StrokeInside then
		thickness0 = 0
	end
	return thickness0, thickness - thickness0
end

local function ThinStroke(self, col, thickness)
	local screen_thickness = thickness * self._InvFringeScale
	if screen_thickness < 1 then
		if screen_thickness < 1 / 255 then
			return nil, thickness
		end
		return ImAlphaMultiply(col, screen_thickness), self._FringeScale
	end
	return col, thickness
end

local function HasRounding(self, rad)
	return rad >= 0.25 * self._FringeScale
end

local function ClampRounding(rounding, width, height, flags)
	rounding = min(rounding, abs(width) * (if band(flags, DF_RoundTop) == DF_RoundTop or band(flags, DF_RoundBottom) == DF_RoundBottom then 0.5 else 1) - 1)
	rounding = min(rounding, abs(height) * (if band(flags, DF_RoundLeft) == DF_RoundLeft or band(flags, DF_RoundRight) == DF_RoundRight then 0.5 else 1) - 1)
	return rounding
end

function ImDrawList:_AddPolyline(points, points_count, col, thickness, flags, max_inner_offset)
	if points_count < 2 or band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	col, thickness = ThinStroke(self, col, thickness)
	if col == nil then
		return
	end
	flags = bor(flags, self.Flags)
	if band(flags, DF_InvalidMask) ~= 0 then
		UserError("Incorrect parameter. Did you swap 'thickness' and 'flags'?")
		return
	end
	local stroke_pos = GetStrokePos(flags, DF_StrokeCenter)
	if stroke_pos == DF_StrokeLegacy then
		flags = band(bor(flags, DF_JoinMiter), bnot(DF_AALineEnds))
	end
	local thickness0, thickness1 = StrokeOffsets(self, stroke_pos, thickness)
	local off = (thickness1 - thickness0) * 0.5
	local closed = btest(flags, DF_Closed)
	local cap = btest(flags, DF_CapSquare) and not closed
	local half = thickness * 0.5
	local count = if closed then points_count else points_count - 1
	for i = 1, count do
		local pa = points[i]
		local pb = points[if i == points_count then 1 else i + 1]
		local ax, ay, bx, by = pa.x, pa.y, pb.x, pb.y
		local dx, dy = bx - ax, by - ay
		local d2 = dx * dx + dy * dy
		if d2 > 0 then
			local inv_len = 1 / sqrt(d2)
			dx *= inv_len
			dy *= inv_len
			local nx, ny = -dy * off, dx * off
			ax += nx
			ay += ny
			bx += nx
			by += ny
			if cap then
				if i == 1 then
					ax -= dx * half
					ay -= dy * half
				end
				if i == count then
					bx += dx * half
					by += dy * half
				end
			end
			PushPrim(self, PK_Line, ax, ay, bx, by, col, thickness, 0, 0, 0, 0, 0)
		end
	end
end

function ImDrawList:AddPolyline(points, num_points, col, thickness, flags)
	self:_AddPolyline(points, num_points, col, thickness, flags or 0, FLT_MAX)
end

function ImDrawList:AddConvexPolyFilled(points, points_count, col, flags)
	if points_count < 3 or band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local p0 = points[1]
	local x0, y0 = p0.x, p0.y
	for i = 3, points_count do
		local p1, p2 = points[i - 1], points[i]
		PushPrim(self, PK_TriangleFilled, x0, y0, p1.x, p1.y, p2.x, p2.y, col, 0, 0, 0, 0)
	end
end

local function CalcCornerArcStepAndCount(segment_count)
	local arc_step = math.clamp(IM_DRAWLIST_ARCFAST_SAMPLE_MAX // segment_count, 1, IM_DRAWLIST_ARCFAST_TABLE_SIZE // 4)
	local arc_step_count = (IM_DRAWLIST_ARCFAST_TABLE_SIZE // 4) // arc_step
	if arc_step * arc_step_count ~= IM_DRAWLIST_ARCFAST_TABLE_SIZE // 4 then
		arc_step = (IM_DRAWLIST_ARCFAST_TABLE_SIZE // 4) // arc_step_count
	end
	return arc_step, arc_step_count
end

function ImDrawList:_PathArcToFastEx(center, radius, a_min_sample, a_max_sample, a_step)
	local path = self._Path
	if not HasRounding(self, radius) then
		path:push_back(center)
		return
	end
	if a_step <= 0 then
		a_step = CalcCornerArcStepAndCount(self:_CalcCircleAutoSegmentCount(radius))
	else
		a_step = math.clamp(a_step, 1, IM_DRAWLIST_ARCFAST_TABLE_SIZE // 4)
	end
	local sample_range = abs(a_max_sample - a_min_sample)
	local a_next_step = a_step
	local extra_max_sample = false
	if a_step > 1 then
		local overstep = sample_range % a_step
		if overstep > 0 then
			extra_max_sample = true
			if sample_range > 0 then
				a_step -= (a_step - overstep) // 2
			end
		end
	end
	local sample_index = a_min_sample
	if sample_index < 0 or sample_index >= IM_DRAWLIST_ARCFAST_SAMPLE_MAX then
		sample_index = math.fmod(sample_index, IM_DRAWLIST_ARCFAST_SAMPLE_MAX)
		if sample_index < 0 then
			sample_index += IM_DRAWLIST_ARCFAST_SAMPLE_MAX
		end
	end
	local arc = self._Data.ArcFastVtx
	local cx, cy = center.x, center.y
	if a_max_sample >= a_min_sample then
		local a = a_min_sample
		while a <= a_max_sample do
			if sample_index >= IM_DRAWLIST_ARCFAST_SAMPLE_MAX then
				sample_index -= IM_DRAWLIST_ARCFAST_SAMPLE_MAX
			end
			local s = arc[sample_index + 1]
			path:push_back(vcreate(cx + s.x * radius, cy + s.y * radius, 0))
			a += a_step
			sample_index += a_step
			a_step = a_next_step
		end
	else
		local a = a_min_sample
		while a >= a_max_sample do
			if sample_index < 0 then
				sample_index += IM_DRAWLIST_ARCFAST_SAMPLE_MAX
			end
			local s = arc[sample_index + 1]
			path:push_back(vcreate(cx + s.x * radius, cy + s.y * radius, 0))
			a -= a_step
			sample_index -= a_step
			a_step = a_next_step
		end
	end
	if extra_max_sample then
		local normalized_max_sample = math.fmod(a_max_sample, IM_DRAWLIST_ARCFAST_SAMPLE_MAX)
		if normalized_max_sample < 0 then
			normalized_max_sample += IM_DRAWLIST_ARCFAST_SAMPLE_MAX
		end
		local s = arc[normalized_max_sample + 1]
		path:push_back(vcreate(cx + s.x * radius, cy + s.y * radius, 0))
	end
end

function ImDrawList:_PathArcToN(center, radius, a_min, a_max, num_segments)
	local path = self._Path
	if not HasRounding(self, radius) then
		path:push_back(center)
		return
	end
	for i = 0, num_segments do
		local a = a_min + (i / num_segments) * (a_max - a_min)
		path:push_back(vcreate(center.x + cos(a) * radius, center.y + sin(a) * radius, 0))
	end
end

function ImDrawList:PathArcToFast(center, radius, a_min_of_12, a_max_of_12)
	if not HasRounding(self, radius) then
		self._Path:push_back(center)
		return
	end
	self:_PathArcToFastEx(center, radius, trunc(a_min_of_12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12), trunc(a_max_of_12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12), 0)
end

function ImDrawList:PathArcTo(center, radius, a_min, a_max, num_segments)
	if num_segments == nil then
		num_segments = 0
	end
	local path = self._Path
	if not HasRounding(self, radius) then
		path:push_back(center)
		return
	end
	if num_segments > 0 then
		self:_PathArcToN(center, radius, a_min, a_max, num_segments)
		return
	end
	if radius <= self._Data.ArcFastRadiusCutoff then
		local a_is_reverse = a_max < a_min
		local arc_step, arc_step_count = CalcCornerArcStepAndCount(self:_CalcCircleAutoSegmentCount(radius))
		local arc_seg_count = arc_step_count * 4
		local a_min_sample_f = arc_seg_count * a_min / (IM_PI * 2)
		local a_max_sample_f = arc_seg_count * a_max / (IM_PI * 2)
		local a_min_sample = (if a_is_reverse then trunc(floor(a_min_sample_f)) else trunc(ceil(a_min_sample_f))) * arc_step
		local a_max_sample = (if a_is_reverse then trunc(ceil(a_max_sample_f)) else trunc(floor(a_max_sample_f))) * arc_step
		local a_mid_samples = if a_is_reverse then max(a_min_sample - a_max_sample, 0) else max(a_max_sample - a_min_sample, 0)
		local a_min_segment_angle = a_min_sample * IM_PI * 2 / IM_DRAWLIST_ARCFAST_SAMPLE_MAX
		local a_max_segment_angle = a_max_sample * IM_PI * 2 / IM_DRAWLIST_ARCFAST_SAMPLE_MAX
		local a_emit_start = abs(a_min_segment_angle - a_min) >= 1e-5
		local a_emit_end = abs(a_max - a_max_segment_angle) >= 1e-5
		if a_emit_start then
			path:push_back(vcreate(center.x + cos(a_min) * radius, center.y + sin(a_min) * radius, 0))
		end
		if a_mid_samples > 0 then
			self:_PathArcToFastEx(center, radius, a_min_sample, a_max_sample, arc_step)
		end
		if a_emit_end then
			path:push_back(vcreate(center.x + cos(a_max) * radius, center.y + sin(a_max) * radius, 0))
		end
	else
		local arc_length = abs(a_max - a_min)
		local circle_segment_count = self:_CalcCircleAutoSegmentCount(radius)
		local arc_segment_count = max(trunc(ceil(circle_segment_count * arc_length / (IM_PI * 2))), 1)
		self:_PathArcToN(center, radius, a_min, a_max, arc_segment_count)
	end
end

function ImDrawList:PathEllipticalArcTo(center, radius, rot, a_min, a_max, num_segments)
	if num_segments == nil or num_segments <= 0 then
		num_segments = self:_CalcCircleAutoSegmentCount(max(radius.x, radius.y))
	end
	local cos_rot, sin_rot = cos(rot), sin(rot)
	for i = 0, num_segments do
		local a = a_min + (i / num_segments) * (a_max - a_min)
		local px, py = cos(a) * radius.x, sin(a) * radius.y
		self._Path:push_back(vcreate(px * cos_rot - py * sin_rot + center.x, px * sin_rot + py * cos_rot + center.y, 0))
	end
end

local function BezierCubicCalc(p1, p2, p3, p4, t)
	local u = 1 - t
	local w1 = u * u * u
	local w2 = 3 * u * u * t
	local w3 = 3 * u * t * t
	local w4 = t * t * t
	return vcreate(w1 * p1.x + w2 * p2.x + w3 * p3.x + w4 * p4.x, w1 * p1.y + w2 * p2.y + w3 * p3.y + w4 * p4.y, 0)
end

local function BezierQuadraticCalc(p1, p2, p3, t)
	local u = 1 - t
	local w1 = u * u
	local w2 = 2 * u * t
	local w3 = t * t
	return vcreate(w1 * p1.x + w2 * p2.x + w3 * p3.x, w1 * p1.y + w2 * p2.y + w3 * p3.y, 0)
end

local function PathBezierCubicCurveToCasteljau(path, x1, y1, x2, y2, x3, y3, x4, y4, max_error_sqr, level)
	local dx = x4 - x1
	local dy = y4 - y1
	local d2 = abs((x2 - x4) * dy - (y2 - y4) * dx)
	local d3 = abs((x3 - x4) * dy - (y3 - y4) * dx)
	if (d2 + d3) * (d2 + d3) < max_error_sqr * (dx * dx + dy * dy) then
		path:push_back(vcreate(x4, y4, 0))
	elseif level < 10 then
		local x12, y12 = (x1 + x2) * 0.5, (y1 + y2) * 0.5
		local x23, y23 = (x2 + x3) * 0.5, (y2 + y3) * 0.5
		local x34, y34 = (x3 + x4) * 0.5, (y3 + y4) * 0.5
		local x123, y123 = (x12 + x23) * 0.5, (y12 + y23) * 0.5
		local x234, y234 = (x23 + x34) * 0.5, (y23 + y34) * 0.5
		local x1234, y1234 = (x123 + x234) * 0.5, (y123 + y234) * 0.5
		PathBezierCubicCurveToCasteljau(path, x1, y1, x12, y12, x123, y123, x1234, y1234, max_error_sqr, level + 1)
		PathBezierCubicCurveToCasteljau(path, x1234, y1234, x234, y234, x34, y34, x4, y4, max_error_sqr, level + 1)
	end
end

local function PathBezierQuadraticCurveToCasteljau(path, x1, y1, x2, y2, x3, y3, max_error_sqr, level)
	local dx, dy = x3 - x1, y3 - y1
	local det = (x2 - x3) * dy - (y2 - y3) * dx
	if det * det * 4 < max_error_sqr * (dx * dx + dy * dy) then
		path:push_back(vcreate(x3, y3, 0))
	elseif level < 10 then
		local x12, y12 = (x1 + x2) * 0.5, (y1 + y2) * 0.5
		local x23, y23 = (x2 + x3) * 0.5, (y2 + y3) * 0.5
		local x123, y123 = (x12 + x23) * 0.5, (y12 + y23) * 0.5
		PathBezierQuadraticCurveToCasteljau(path, x1, y1, x12, y12, x123, y123, max_error_sqr, level + 1)
		PathBezierQuadraticCurveToCasteljau(path, x123, y123, x23, y23, x3, y3, max_error_sqr, level + 1)
	end
end

function ImDrawList:PathBezierCubicCurveTo(p2, p3, p4, num_segments)
	local path = self._Path
	local p1 = path:back()
	if num_segments == nil or num_segments == 0 then
		local tol = self._Data.CurveTessellationMaxError
		assert(tol > 0)
		local e = tol * self._FringeScale
		PathBezierCubicCurveToCasteljau(path, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, e * e, 0)
	else
		local t_step = 1 / num_segments
		for i_step = 1, num_segments do
			path:push_back(BezierCubicCalc(p1, p2, p3, p4, t_step * i_step))
		end
	end
end

function ImDrawList:PathBezierQuadraticCurveTo(p2, p3, num_segments)
	local path = self._Path
	local p1 = path:back()
	if num_segments == nil or num_segments == 0 then
		local tol = self._Data.CurveTessellationMaxError
		assert(tol > 0)
		local e = tol * self._FringeScale
		PathBezierQuadraticCurveToCasteljau(path, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, e * e, 0)
	else
		local t_step = 1 / num_segments
		for i_step = 1, num_segments do
			path:push_back(BezierQuadraticCalc(p1, p2, p3, t_step * i_step))
		end
	end
end

function ImDrawList:PathRect(a, b, rounding, flags)
	if rounding == nil then
		rounding = 0
	end
	if flags == nil then
		flags = 0
	end
	local path = self._Path
	local start = path.Size
	local has_rounding = HasRounding(self, rounding)
	if has_rounding then
		if band(flags, DF_RoundMask) == 0 then
			flags = bor(flags, DF_RoundAll)
		end
		rounding = ClampRounding(rounding, b.x - a.x, b.y - a.y, flags)
	end
	local effective_rounding = 0
	if not has_rounding or band(flags, DF_RoundMask) == DF_RoundNone then
		path:push_back(a)
		path:push_back(vcreate(b.x, a.y, 0))
		path:push_back(b)
		path:push_back(vcreate(a.x, b.y, 0))
	else
		local rounding_tl = if btest(flags, DF_RoundTopLeft) then rounding else 0
		local rounding_tr = if btest(flags, DF_RoundTopRight) then rounding else 0
		local rounding_br = if btest(flags, DF_RoundBottomRight) then rounding else 0
		local rounding_bl = if btest(flags, DF_RoundBottomLeft) then rounding else 0
		self:PathArcToFast(vcreate(a.x + rounding_tl, a.y + rounding_tl, 0), rounding_tl, 6, 9)
		self:PathArcToFast(vcreate(b.x - rounding_tr, a.y + rounding_tr, 0), rounding_tr, 9, 12)
		self:PathArcToFast(vcreate(b.x - rounding_br, b.y - rounding_br, 0), rounding_br, 0, 3)
		self:PathArcToFast(vcreate(a.x + rounding_bl, b.y - rounding_bl, 0), rounding_bl, 3, 6)
		if HasRounding(self, rounding) then
			effective_rounding = rounding
		end
	end
	if start == 0 then
		self._PathRectEnd = path.Size
		self._PathRectMin = a
		self._PathRectMax = b
		self._PathRectRounding = effective_rounding
		self._PathRectFlags = if effective_rounding > 0 then band(flags, DF_RoundAll) else 0
	else
		self._PathRectEnd = -1
	end
end

function ImDrawList:PathClear()
	self._Path.Size = 0
	self._PathRectEnd = -1
end

function ImDrawList:PathLineTo(pos)
	self._Path:push_back(pos)
end

function ImDrawList:PathLineToMergeDuplicate(pos)
	local path = self._Path
	if path.Size == 0 or path[path.Size] ~= pos then
		path:push_back(pos)
	end
end

local function PathIsSingleRect(self)
	local n = self._Path.Size
	return n > 0 and self._PathRectEnd == n
end

function ImDrawList:PathFillConvex(col, flags)
	if flags == nil then
		flags = 0
	end
	local path = self._Path
	if PathIsSingleRect(self) then
		if band(col, IM_COL32_A_MASK) ~= 0 then
			local a, b = self._PathRectMin, self._PathRectMax
			PushPrim(self, PK_RectFilled, a.x, a.y, b.x, b.y, col, self._PathRectRounding, self._PathRectFlags, 0, 0, 0, 0)
		end
	else
		self:AddConvexPolyFilled(path, path.Size, col, flags)
	end
	path.Size = 0
	self._PathRectEnd = -1
end

function ImDrawList:PathFillConcave(col)
	local path = self._Path
	if PathIsSingleRect(self) then
		if band(col, IM_COL32_A_MASK) ~= 0 then
			local a, b = self._PathRectMin, self._PathRectMax
			PushPrim(self, PK_RectFilled, a.x, a.y, b.x, b.y, col, self._PathRectRounding, self._PathRectFlags, 0, 0, 0, 0)
		end
	else
		self:AddConcavePolyFilled(path, path.Size, col)
	end
	path.Size = 0
	self._PathRectEnd = -1
end

local function AddPathRectStroke(self, col, thickness, flags)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	col, thickness = ThinStroke(self, col, thickness)
	if col == nil then
		return
	end
	flags = bor(flags, self.Flags)
	local stroke_pos = GetStrokePos(flags, DF_StrokeCenter)
	if stroke_pos == DF_StrokeLegacy then
		stroke_pos = DF_StrokeCenter
	end
	local offset = StrokeOffsets(self, stroke_pos, thickness)
	local a, b = self._PathRectMin, self._PathRectMax
	local x1, y1, x2, y2 = a.x - offset, a.y - offset, b.x + offset, b.y + offset
	local rounding = self._PathRectRounding
	if rounding > 0 then
		rounding += offset
	end
	if min(x2 - x1, y2 - y1) * 0.5 <= thickness then
		PushPrim(self, PK_RectFilled, x1, y1, x2, y2, col, rounding, self._PathRectFlags, 0, 0, 0, 0)
	else
		PushPrim(self, PK_Rect, x1, y1, x2, y2, col, rounding, self._PathRectFlags, thickness, 0, 0, 0)
	end
end

function ImDrawList:PathStroke(col, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	local path = self._Path
	if PathIsSingleRect(self) and btest(flags, DF_Closed) then
		AddPathRectStroke(self, col, thickness, flags)
	else
		self:_AddPolyline(path, path.Size, col, thickness, flags, FLT_MAX)
	end
	path.Size = 0
	self._PathRectEnd = -1
end

function ImDrawList:_AddLine(p1, p2, col, thickness, flags)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	col, thickness = ThinStroke(self, col, thickness)
	if col == nil then
		return
	end
	flags = bor(flags, self.Flags)
	local dir_x, dir_y = p2.x - p1.x, p2.y - p1.y
	local d2 = dir_x * dir_x + dir_y * dir_y
	local inv_len = if d2 > 0 then 1 / sqrt(d2) else 0
	dir_x *= inv_len
	dir_y *= inv_len
	local stroke_pos = GetStrokePos(flags, DF_StrokeCenter)
	if stroke_pos == DF_StrokeLegacy then
		flags = band(bor(flags, DF_JoinMiter), bnot(DF_AALineEnds))
	end
	local thickness0, thickness1 = StrokeOffsets(self, stroke_pos, thickness)
	local off = (thickness1 - thickness0) * 0.5
	local nx, ny = -dir_y * off, dir_x * off
	local p1_x, p1_y, p2_x, p2_y = p1.x + nx, p1.y + ny, p2.x + nx, p2.y + ny
	if btest(flags, DF_CapSquare) then
		local half_thickness = thickness * 0.5
		p1_x -= dir_x * half_thickness
		p1_y -= dir_y * half_thickness
		p2_x += dir_x * half_thickness
		p2_y += dir_y * half_thickness
	end
	PushPrim(self, PK_Line, p1_x, p1_y, p2_x, p2_y, col, thickness, 0, 0, 0, 0, 0)
end

function ImDrawList:AddLine(p1, p2, col, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	flags = bor(flags, self.Flags)
	if GetStrokePos(flags, DF_StrokeCenter) == DF_StrokeLegacy then
		self:_AddLine(vcreate(p1.x + 0.5, p1.y + 0.5, 0), vcreate(p2.x + 0.5, p2.y + 0.5, 0), col, thickness, flags)
		return
	end
	self:_AddLine(p1, p2, col, thickness, flags)
end

function ImDrawList:AddLineH(min_x, max_x, y, col, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	flags = bor(flags, self.Flags)
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	if stroke_pos == DF_StrokeLegacy then
		self:_AddLine(vcreate(min_x + 0.5, y + 0.5, 0), vcreate(max_x + 0.5, y + 0.5, 0), col, thickness, flags)
		return
	end
	local top_y = y
	if stroke_pos == DF_StrokeCenter then
		top_y -= thickness * 0.5
	elseif stroke_pos == DF_StrokeCenterBiased then
		top_y -= self:_CalculateCenterBiasedOffset(thickness)
	elseif stroke_pos == DF_StrokeOutside then
		top_y -= thickness
	end
	local is_truncated = IsTruncated(min_x) and IsTruncated(max_x) and IsTruncated(top_y) and IsTruncated(thickness)
	if self._FringeScaleIsInteger and is_truncated and not btest(flags, DF_CapSquare) then
		if thickness < self._FringeScale then
			if thickness < (1 / 255) * self._FringeScale then
				return
			end
			col = ImAlphaMultiply(col, thickness * self._InvFringeScale)
			thickness = self._FringeScale
		end
		PushPrim(self, PK_RectFilled, min_x, top_y, max_x, top_y + thickness, col, 0, 0, 0, 0, 0, 0)
	else
		flags = bor(band(flags, bnot(DF_StrokeMask)), stroke_pos)
		self:_AddLine(vcreate(min_x, y, 0), vcreate(max_x, y, 0), col, thickness, flags)
	end
end

function ImDrawList:AddLineV(x, min_y, max_y, col, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	flags = bor(flags, self.Flags)
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	if stroke_pos == DF_StrokeLegacy then
		self:_AddLine(vcreate(x + 0.5, min_y + 0.5, 0), vcreate(x + 0.5, max_y + 0.5, 0), col, thickness, flags)
		return
	end
	local left_x = x
	if stroke_pos == DF_StrokeCenter then
		left_x -= thickness * 0.5
	elseif stroke_pos == DF_StrokeCenterBiased then
		left_x -= self:_CalculateCenterBiasedOffset(thickness)
	elseif stroke_pos == DF_StrokeOutside then
		left_x -= thickness
	end
	local is_truncated = IsTruncated(left_x) and IsTruncated(min_y) and IsTruncated(max_y) and IsTruncated(thickness)
	if self._FringeScaleIsInteger and is_truncated and not btest(flags, DF_CapSquare) then
		if thickness < self._FringeScale then
			if thickness < (1 / 255) * self._FringeScale then
				return
			end
			col = ImAlphaMultiply(col, thickness * self._InvFringeScale)
			thickness = self._FringeScale
		end
		PushPrim(self, PK_RectFilled, left_x, min_y, left_x + thickness, max_y, col, 0, 0, 0, 0, 0, 0)
	else
		flags = bor(band(flags, bnot(DF_StrokeMask)), stroke_pos)
		self:_AddLine(vcreate(x, max_y, 0), vcreate(x, min_y, 0), col, thickness, flags)
	end
end

function ImDrawList:_AddRectBaked(p_min, p_max, col, r, t, tex_uvs, flags)
	PushPrim(self, PK_Rect, p_min.x, p_min.y, p_max.x, p_max.y, col, r, band(flags, DF_RoundAll), t, 0, 0, 0)
end

function ImDrawList:_AddRectFilledBaked(p_min, p_max, col, r, tex_uvs, flags)
	PushPrim(self, PK_RectFilled, p_min.x, p_min.y, p_max.x, p_max.y, col, r, band(flags, DF_RoundAll), 0, 0, 0, 0)
end

function ImDrawList:_AddRectTinyRounding(p_min, p_max, col, rounding, thickness, flags)
	col, thickness = ThinStroke(self, col, thickness)
	if col == nil then
		return
	end
	flags = bor(flags, self.Flags)
	PushPrim(self, PK_Rect, p_min.x, p_min.y, p_max.x, p_max.y, col, rounding, band(flags, DF_RoundAll), thickness, 0, 0, 0)
end

function ImDrawList:AddRect(p_min, p_max, col, rounding, thickness, flags)
	if rounding == nil then
		rounding = 0
	end
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(flags, DF_InvalidMask) ~= 0 then
		UserError("Incorrect parameter. Did you swap 'thickness' and 'flags'?")
		return
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	flags = bor(flags, self.Flags)
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	if stroke_pos == DF_StrokeLegacy then
		if btest(flags, DF_AALines) then
			self:PathRect(vcreate(p_min.x + 0.5, p_min.y + 0.5, 0), vcreate(p_max.x - 0.5, p_max.y - 0.5, 0), rounding, flags)
		else
			self:PathRect(vcreate(p_min.x + 0.5, p_min.y + 0.5, 0), vcreate(p_max.x - 0.49, p_max.y - 0.49, 0), rounding, flags)
		end
		self:PathStroke(col, thickness, bor(DF_Closed, DF_JoinMiter, DF_StrokeCenter, band(flags, bnot(DF_StrokeMask))))
		return
	end
	local has_rounding = HasRounding(self, rounding)
	local offset = 0
	if stroke_pos == DF_StrokeCenter then
		offset = thickness * 0.5
	elseif stroke_pos == DF_StrokeCenterBiased then
		offset = self:_CalculateCenterBiasedOffset(thickness)
	elseif stroke_pos == DF_StrokeOutside then
		offset = thickness
	end
	local x1, y1, x2, y2 = p_min.x - offset, p_min.y - offset, p_max.x + offset, p_max.y + offset
	local outer_rounding = rounding + (if has_rounding then offset else 0)
	local width = x2 - x1
	local height = y2 - y1
	local half_min_dim = min(width, height) * 0.5
	if half_min_dim <= thickness then
		self:AddRectFilled(vcreate(x1, y1, 0), vcreate(x2, y2, 0), col, outer_rounding, flags)
		return
	end
	if band(flags, DF_RoundMask) == 0 then
		flags = bor(flags, DF_RoundAll)
	end
	if has_rounding then
		outer_rounding = ClampRounding(outer_rounding, width, height, flags)
	end
	local is_truncated = IsTruncated(x1) and IsTruncated(y1) and IsTruncated(x2) and IsTruncated(y2) and IsTruncated(outer_rounding) and IsTruncated(thickness)
	if self._FringeScaleIsInteger and is_truncated then
		if trunc(thickness * self._InvFringeScale) <= 0 then
			return
		end
	end
	if not has_rounding or band(flags, DF_RoundMask) == DF_RoundNone or not HasRounding(self, outer_rounding) then
		col, thickness = ThinStroke(self, col, thickness)
		if col == nil then
			return
		end
		PushPrim(self, PK_Rect, x1, y1, x2, y2, col, 0, 0, thickness, 0, 0, 0)
		return
	end
	if thickness + (0.75 * self._FringeScale) > outer_rounding then
		self:_AddRectTinyRounding(vcreate(x1, y1, 0), vcreate(x2, y2, 0), col, outer_rounding, thickness, flags)
		return
	end
	col, thickness = ThinStroke(self, col, thickness)
	if col == nil then
		return
	end
	PushPrim(self, PK_Rect, x1, y1, x2, y2, col, outer_rounding, band(flags, DF_RoundAll), thickness, 0, 0, 0)
end

function ImDrawList:AddRectFilled(p_min, p_max, col, rounding, flags)
	if rounding == nil then
		rounding = 0
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local width = p_max.x - p_min.x
	local height = p_max.y - p_min.y
	local min_dim = min(width, height)
	flags = bor(flags, self.Flags)
	if band(flags, DF_StrokeMask) == DF_StrokeLegacy and rounding < 0.5 then
		PushPrim(self, PK_RectFilled, p_min.x, p_min.y, p_max.x, p_max.y, col, 0, 0, 0, 0, 0, 0)
		return
	end
	local fs = self._FringeScale
	if min_dim < fs then
		if min_dim < (1 / 255) * fs then
			return
		end
		if width < fs then
			col = ImAlphaMultiply(col, width * self._InvFringeScale)
			width = fs
		end
		if height < fs then
			col = ImAlphaMultiply(col, height * self._InvFringeScale)
			height = fs
		end
		PushPrim(self, PK_RectFilled, p_min.x, p_min.y, p_min.x + width, p_min.y + height, col, 0, 0, 0, 0, 0, 0)
		return
	end
	local has_rounding = band(flags, DF_RoundMask) ~= DF_RoundNone and HasRounding(self, rounding)
	if not has_rounding then
		PushPrim(self, PK_RectFilled, p_min.x, p_min.y, p_max.x, p_max.y, col, 0, 0, 0, 0, 0, 0)
		return
	end
	if band(flags, DF_RoundMask) == 0 then
		flags = bor(flags, DF_RoundAll)
	end
	rounding = ClampRounding(rounding, width, height, flags)
	local is_truncated = IsTruncated(p_min.x) and IsTruncated(p_min.y) and IsTruncated(p_max.x) and IsTruncated(p_max.y) and IsTruncated(rounding)
	if (self._FringeScaleIsInteger and is_truncated and trunc(rounding * self._InvFringeScale) <= 0) or not HasRounding(self, rounding) or band(flags, DF_RoundAll) == 0 then
		PushPrim(self, PK_RectFilled, p_min.x, p_min.y, p_max.x, p_max.y, col, 0, 0, 0, 0, 0, 0)
		return
	end
	PushPrim(self, PK_RectFilled, p_min.x, p_min.y, p_max.x, p_max.y, col, rounding, band(flags, DF_RoundAll), 0, 0, 0, 0)
end

function ImDrawList:AddRectFilledMultiColor(p_min, p_max, col_upr_left, col_upr_right, col_bot_right, col_bot_left)
	if band(bor(col_upr_left, col_upr_right, col_bot_right, col_bot_left), IM_COL32_A_MASK) == 0 then
		return
	end
	PushPrim(self, PK_RectMultiColor, p_min.x, p_min.y, p_max.x, p_max.y, col_upr_left, col_upr_right, col_bot_right, col_bot_left, 0, 0, 0)
end

function ImDrawList:AddQuad(p1, p2, p3, p4, col, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	flags = bor(band(flags, bnot(DF_StrokeMask)), stroke_pos)
	self:_AddPolyline({ p1, p2, p3, p4 }, 4, col, thickness, bor(flags, DF_Closed), FLT_MAX)
end

function ImDrawList:AddQuadFilled(p1, p2, p3, p4, col)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	self:AddConvexPolyFilled({ p1, p2, p3, p4 }, 4, col)
end

function ImDrawList:AddTriangle(p1, p2, p3, col, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	flags = bor(band(flags, bnot(DF_StrokeMask)), stroke_pos)
	self:_AddPolyline({ p1, p2, p3 }, 3, col, thickness, bor(flags, DF_Closed), FLT_MAX)
end

function ImDrawList:AddTriangleFilled(p1, p2, p3, col)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	PushPrim(self, PK_TriangleFilled, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, col, 0, 0, 0, 0)
end

local function ApproxApothem(num_segments)
	local u = 1 / num_segments
	return ((4.058712 * u * u) - 4.934802) * u * u + 1
end

function ImDrawList:AddCircle(center, radius, col, num_segments, thickness, flags)
	if num_segments == nil then
		num_segments = 0
	end
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	flags = bor(flags, self.Flags)
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	if stroke_pos == DF_StrokeLegacy then
		radius -= 0.5
		stroke_pos = DF_StrokeCenter
	end
	radius = max(0.01, radius)
	local outer_radius = radius
	if stroke_pos == DF_StrokeCenter then
		outer_radius = radius + thickness * 0.5
	elseif stroke_pos == DF_StrokeCenterBiased then
		outer_radius = radius + self:_CalculateCenterBiasedOffset(thickness)
	elseif stroke_pos == DF_StrokeOutside then
		outer_radius = radius + thickness
	end
	if outer_radius <= thickness then
		self:AddCircleFilled(center, outer_radius, col, num_segments)
		return
	end
	col, thickness = ThinStroke(self, col, thickness)
	if col == nil then
		return
	end
	PushPrim(self, PK_Circle, center.x, center.y, outer_radius, col, thickness, 0, 0, 0, 0, 0, 0)
end

function ImDrawList:AddCircleFilled(center, radius, col, num_segments)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local min_radius = self._FringeScale * 1.41421356 * 0.5
	if radius < min_radius then
		if radius < (1 / 255) * min_radius then
			return
		end
		col = ImAlphaMultiply(col, radius / min_radius)
		radius = min_radius
	end
	PushPrim(self, PK_CircleFilled, center.x, center.y, radius, col, 0, 0, 0, 0, 0, 0, 0)
end

function ImDrawList:AddNgon(center, radius, col, num_segments, thickness, flags)
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 or num_segments <= 2 then
		return
	end
	flags = bor(flags, self.Flags)
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	if stroke_pos == DF_StrokeLegacy then
		radius -= 0.5
		stroke_pos = DF_StrokeCenter
	end
	radius = max(0.01, radius)
	local unit_apothem = ApproxApothem(num_segments)
	local edge_dist = radius * unit_apothem
	if radius < thickness * 2 then
		local outer_radius = radius
		if stroke_pos == DF_StrokeCenter then
			outer_radius = radius + thickness * 0.5
		elseif stroke_pos == DF_StrokeCenterBiased then
			outer_radius = radius + self:_CalculateCenterBiasedOffset(thickness)
		elseif stroke_pos == DF_StrokeOutside then
			outer_radius = radius + thickness
		end
		if outer_radius * unit_apothem <= thickness then
			self:AddNgonFilled(center, outer_radius, col, num_segments)
			return
		end
	end
	local a_max = (IM_PI * 2) * (num_segments - 1) / num_segments
	self:PathArcTo(center, radius, 0, a_max, num_segments - 1)
	self:_AddPolyline(self._Path, self._Path.Size, col, thickness, bor(DF_Closed, DF_JoinMiter, stroke_pos), edge_dist)
	self._Path.Size = 0
	self._PathRectEnd = -1
end

function ImDrawList:AddNgonFilled(center, radius, col, num_segments)
	if band(col, IM_COL32_A_MASK) == 0 or num_segments <= 2 then
		return
	end
	local diameter = radius * 2
	if diameter < self._FringeScale then
		if diameter < (1 / 255) * self._FringeScale then
			return
		end
		col = ImAlphaMultiply(col, diameter * self._InvFringeScale)
		radius = self._FringeScale * 0.5
	end
	local a_max = (IM_PI * 2) * (num_segments - 1) / num_segments
	self:PathArcTo(center, radius, 0, a_max, num_segments - 1)
	self:PathFillConvex(col, DF_JoinMiter)
end

function ImDrawList:AddEllipse(center, radius, col, rot, num_segments, thickness, flags)
	if rot == nil then
		rot = 0
	end
	if num_segments == nil then
		num_segments = 0
	end
	if thickness == nil then
		thickness = 1
	end
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local stroke_pos = GetStrokePos(flags, DF_StrokeInside)
	if stroke_pos == DF_StrokeLegacy then
		stroke_pos = DF_StrokeCenter
	end
	local rad = vcreate(max(0.01, radius.x), max(0.01, radius.y), 0)
	if num_segments <= 0 then
		num_segments = self:_CalcCircleAutoSegmentCount(max(rad.x, rad.y))
	end
	local a_max = IM_PI * 2 * (num_segments - 1) / num_segments
	self:PathEllipticalArcTo(center, rad, rot, 0, a_max, num_segments - 1)
	local max_inner_offset = min(rad.x, rad.y)
	self:_AddPolyline(self._Path, self._Path.Size, col, thickness, bor(DF_Closed, DF_JoinMiter, stroke_pos), max_inner_offset)
	self._Path.Size = 0
	self._PathRectEnd = -1
end

function ImDrawList:AddEllipseFilled(center, radius, col, rot, num_segments)
	if rot == nil then
		rot = 0
	end
	if num_segments == nil then
		num_segments = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local diameter_x = radius.x * 2
	local diameter_y = radius.y * 2
	local min_dim = min(diameter_x, diameter_y)
	if min_dim < self._FringeScale then
		if min_dim < (1 / 255) * self._FringeScale then
			return
		end
		if diameter_x < self._FringeScale then
			col = ImAlphaMultiply(col, diameter_x * self._InvFringeScale)
		end
		if diameter_y < self._FringeScale then
			col = ImAlphaMultiply(col, diameter_y * self._InvFringeScale)
		end
	end
	if num_segments <= 0 then
		num_segments = self:_CalcCircleAutoSegmentCount(max(radius.x, radius.y))
	end
	local a_max = IM_PI * 2 * (num_segments - 1) / num_segments
	self:PathEllipticalArcTo(center, radius, rot, 0, a_max, num_segments - 1)
	self:PathFillConvex(col)
end

function ImDrawList:AddBezierCubic(p1, p2, p3, p4, col, thickness, num_segments, flags)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	self:PathLineTo(p1)
	self:PathBezierCubicCurveTo(p2, p3, p4, num_segments or 0)
	self:PathStroke(col, thickness, flags or 0)
end

function ImDrawList:AddBezierQuadratic(p1, p2, p3, col, thickness, num_segments, flags)
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	self:PathLineTo(p1)
	self:PathBezierQuadraticCurveTo(p2, p3, num_segments or 0)
	self:PathStroke(col, thickness, flags or 0)
end

function ImDrawList:AddText(a1, a2, a3, a4, a5, a6, a7, a8)
	if type(a1) == "vector" then
		self:AddText(self._Data.Font, self._Data.FontSize, a1, a2, a3, a4)
		return
	end
	local font, font_size, pos, col, text, text_end, wrap_width, cpu_fine_clip_rect = a1, a2, a3, a4, a5, a6, a7, a8
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	if text_end == 1 then
		return
	end
	local c0 = sbyte(text, 1)
	if c0 == nil or c0 == 0 then
		return
	end
	if font == nil then
		font = self._Data.Font
	end
	if font_size == nil or font_size == 0 then
		font_size = self._Data.FontSize
	end
	local clip_rect = self._CmdHeader.ClipRect
	if cpu_fine_clip_rect ~= nil then
		clip_rect = ImVec4(max(clip_rect.x, cpu_fine_clip_rect.x), max(clip_rect.y, cpu_fine_clip_rect.y), min(clip_rect.z, cpu_fine_clip_rect.z), min(clip_rect.w, cpu_fine_clip_rect.w))
	end
	font:RenderText(self, font_size, pos, col, clip_rect, text, text_end, wrap_width or 0, if cpu_fine_clip_rect ~= nil then ImDrawTextFlags.CpuFineClip else ImDrawTextFlags.None)
end

function ImDrawList:AddImage(tex_ref, p_min, p_max, uv_min, uv_max, col)
	if uv_min == nil then
		uv_min = VEC2_ZERO
	end
	if uv_max == nil then
		uv_max = vcreate(1, 1, 0)
	end
	if col == nil then
		col = 0xFFFFFFFF
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local push_texture_id = tex_ref ~= self._CmdHeader.TexRef
	if push_texture_id then
		self:PushTexture(tex_ref)
	end
	PushPrim(self, PK_Image, p_min.x, p_min.y, p_max.x, p_max.y, uv_min.x, uv_min.y, uv_max.x, uv_max.y, col, tex_ref, 0)
	if push_texture_id then
		self:PopTexture()
	end
end

function ImDrawList:AddImageQuad(tex_ref, p1, p2, p3, p4, uv1, uv2, uv3, uv4, col)
	if uv1 == nil then
		uv1 = VEC2_ZERO
	end
	if uv2 == nil then
		uv2 = vcreate(1, 0, 0)
	end
	if uv3 == nil then
		uv3 = vcreate(1, 1, 0)
	end
	if uv4 == nil then
		uv4 = vcreate(0, 1, 0)
	end
	if col == nil then
		col = 0xFFFFFFFF
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local push_texture_id = tex_ref ~= self._CmdHeader.TexRef
	if push_texture_id then
		self:PushTexture(tex_ref)
	end
	self:PrimQuadUV(p1, p2, p3, p4, uv1, uv2, uv3, uv4, col)
	if push_texture_id then
		self:PopTexture()
	end
end

function ImDrawList:AddImageRounded(tex_ref, p_min, p_max, uv_min, uv_max, col, rounding, flags)
	if flags == nil then
		flags = 0
	end
	if band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	assert(band(flags, 0x0F) == 0, "Misuse of legacy hardcoded ImDrawCornerFlags values!")
	if band(flags, DF_RoundMask) == 0 then
		flags = bor(flags, DF_RoundAll)
	end
	if rounding < 0.5 or band(flags, DF_RoundMask) == DF_RoundNone then
		self:AddImage(tex_ref, p_min, p_max, uv_min, uv_max, col)
		return
	end
	local push_texture_id = tex_ref ~= self._CmdHeader.TexRef
	if push_texture_id then
		self:PushTexture(tex_ref)
	end
	rounding = max(0, ClampRounding(rounding, p_max.x - p_min.x, p_max.y - p_min.y, flags))
	PushPrim(self, PK_Image, p_min.x, p_min.y, p_max.x, p_max.y, uv_min.x, uv_min.y, uv_max.x, uv_max.y, col, tex_ref, rounding)
	if push_texture_id then
		self:PopTexture()
	end
end

local TRI_CONVEX, TRI_EAR, TRI_REFLEX = 0, 1, 2

local ImTriangulator = {}
ImTriangulator.__index = ImTriangulator

function ImTriangulator.new()
	return setmetatable({ _TrianglesLeft = 0, _Nodes = nil, _Ears = {}, _EarsSize = 0, _Reflexes = {}, _ReflexesSize = 0 }, ImTriangulator)
end

function ImTriangulator:Init(points, points_count)
	assert(points_count >= 3)
	self._TrianglesLeft = points_count - 2
	local nodes = table.create(points_count)
	for i = 0, points_count - 1 do
		nodes[i + 1] = { Type = TRI_CONVEX, Index = i, Pos = points[i + 1], Next = false, Prev = false }
	end
	for i = 1, points_count do
		nodes[i].Next = nodes[(i % points_count) + 1]
		nodes[i].Prev = nodes[((i - 2) % points_count) + 1]
	end
	self._Nodes = nodes[1]
	self._EarsSize = 0
	self._ReflexesSize = 0
	self:BuildReflexes()
	self:BuildEars()
end

function ImTriangulator:BuildReflexes()
	local n1 = self._Nodes
	for _ = self._TrianglesLeft, 0, -1 do
		if not Base.ImTriangleIsClockwise(n1.Prev.Pos, n1.Pos, n1.Next.Pos) then
			n1.Type = TRI_REFLEX
			self._ReflexesSize += 1
			self._Reflexes[self._ReflexesSize] = n1
		end
		n1 = n1.Next
	end
end

function ImTriangulator:BuildEars()
	local n1 = self._Nodes
	for _ = self._TrianglesLeft, 0, -1 do
		if n1.Type == TRI_CONVEX and self:IsEar(n1.Prev.Index, n1.Index, n1.Next.Index, n1.Prev.Pos, n1.Pos, n1.Next.Pos) then
			n1.Type = TRI_EAR
			self._EarsSize += 1
			self._Ears[self._EarsSize] = n1
		end
		n1 = n1.Next
	end
end

function ImTriangulator:GetNextTriangle()
	if self._EarsSize == 0 then
		self:FlipNodeList()
		local node = self._Nodes
		for _ = self._TrianglesLeft, 0, -1 do
			node.Type = TRI_CONVEX
			node = node.Next
		end
		self._ReflexesSize = 0
		self:BuildReflexes()
		self:BuildEars()
		if self._EarsSize == 0 then
			assert(self._TrianglesLeft > 0)
			self._Ears[1] = self._Nodes
			self._EarsSize = 1
		end
	end
	local ear = self._Ears[self._EarsSize]
	self._EarsSize -= 1
	local i0, i1, i2 = ear.Prev.Index, ear.Index, ear.Next.Index
	ear.Next.Prev = ear.Prev
	ear.Prev.Next = ear.Next
	if ear == self._Nodes then
		self._Nodes = ear.Next
	end
	self:ReclassifyNode(ear.Prev)
	self:ReclassifyNode(ear.Next)
	self._TrianglesLeft -= 1
	return i0, i1, i2
end

function ImTriangulator:FlipNodeList()
	local nodes = self._Nodes
	local prev = nodes
	local current = nodes.Next
	prev.Next = prev
	prev.Prev = prev
	while current ~= nodes do
		local temp = current.Next
		current.Next = prev
		prev.Prev = current
		nodes.Next = current
		current.Prev = nodes
		prev = current
		current = temp
	end
	self._Nodes = prev
end

function ImTriangulator:IsEar(i0, i1, i2, v0, v1, v2)
	local reflexes = self._Reflexes
	for i = 1, self._ReflexesSize do
		local reflex = reflexes[i]
		if reflex.Index ~= i0 and reflex.Index ~= i1 and reflex.Index ~= i2 then
			if Base.ImTriangleContainsPoint(v0, v1, v2, reflex.Pos) then
				return false
			end
		end
	end
	return true
end

local function SpanFindEraseUnsorted(data, size, idx)
	for i = size, 1, -1 do
		if data[i].Index == idx then
			data[i] = data[size]
			return size - 1
		end
	end
	return size
end

function ImTriangulator:ReclassifyNode(n1)
	local n0 = n1.Prev
	local n2 = n1.Next
	local node_type
	if not Base.ImTriangleIsClockwise(n0.Pos, n1.Pos, n2.Pos) then
		node_type = TRI_REFLEX
	elseif self:IsEar(n0.Index, n1.Index, n2.Index, n0.Pos, n1.Pos, n2.Pos) then
		node_type = TRI_EAR
	else
		node_type = TRI_CONVEX
	end
	if node_type == n1.Type then
		return
	end
	if n1.Type == TRI_REFLEX then
		self._ReflexesSize = SpanFindEraseUnsorted(self._Reflexes, self._ReflexesSize, n1.Index)
	elseif n1.Type == TRI_EAR then
		self._EarsSize = SpanFindEraseUnsorted(self._Ears, self._EarsSize, n1.Index)
	end
	if node_type == TRI_REFLEX then
		self._ReflexesSize += 1
		self._Reflexes[self._ReflexesSize] = n1
	elseif node_type == TRI_EAR then
		self._EarsSize += 1
		self._Ears[self._EarsSize] = n1
	end
	n1.Type = node_type
end

function ImDrawList:AddConcavePolyFilled(points, points_count, col)
	if points_count < 3 or band(col, IM_COL32_A_MASK) == 0 then
		return
	end
	local triangulator = ImTriangulator.new()
	triangulator:Init(points, points_count)
	while triangulator._TrianglesLeft > 0 do
		local i0, i1, i2 = triangulator:GetNextTriangle()
		local a, b, c = points[i0 + 1], points[i1 + 1], points[i2 + 1]
		PushPrim(self, PK_TriangleFilled, a.x, a.y, b.x, b.y, c.x, c.y, col, 0, 0, 0, 0)
	end
end

function ImDrawList:ChannelsSplit(count)
	self._Splitter:Split(self, count)
end

function ImDrawList:ChannelsMerge()
	self._Splitter:Merge(self)
end

function ImDrawList:ChannelsSetCurrent(n)
	self._Splitter:SetCurrentChannel(self, n)
end

function ImDrawListSplitter:ClearFreeMemory()
	self._Channels:clear()
	self._Current = 0
	self._Count = 1
end

function ImDrawListSplitter:Split(draw_list, channels_count)
	assert(self._Current == 0 and self._Count <= 1, "Nested channel splitting is not supported. Please use separate instances of ImDrawListSplitter.")
	local channels = self._Channels
	local old_channels_count = channels.Size
	if old_channels_count < channels_count then
		for _ = old_channels_count, channels_count - 1 do
			channels:push_back(ImDrawChannel.new())
		end
	end
	self._Count = channels_count
	local ch0 = channels[1]
	ch0._CmdBuffer = nil
	ch0._PrimBuffer = nil
	ch0._PrimCount = 0
	for i = 1, channels_count - 1 do
		if i < old_channels_count then
			local ch = channels[i + 1]
			ch._CmdBuffer:resize(0)
			ch._PrimCount = 0
		end
	end
end

function ImDrawListSplitter:Merge(draw_list)
	if self._Count <= 1 then
		return
	end
	self:SetCurrentChannel(draw_list, 0)
	draw_list:_PopUnusedDrawCmd()
	local channels = self._Channels
	local dcb = draw_list.CmdBuffer
	local new_prim_count = 0
	local last_cmd = if self._Count > 0 and dcb.Size > 0 then dcb[dcb.Size] else nil
	local idx_offset = if last_cmd ~= nil then last_cmd.IdxOffset + last_cmd.ElemCount else 0
	for i = 1, self._Count - 1 do
		local ch = channels[i + 1]
		local ccb = ch._CmdBuffer
		if ccb.Size > 0 and ccb[ccb.Size].ElemCount == 0 and ccb[ccb.Size].UserCallback == nil then
			ccb:pop_back()
		end
		if ccb.Size > 0 and last_cmd ~= nil then
			local next_cmd = ccb[1]
			if HeaderEq(last_cmd, next_cmd) and last_cmd.UserCallback == nil and next_cmd.UserCallback == nil then
				last_cmd.ElemCount += next_cmd.ElemCount
				idx_offset += next_cmd.ElemCount
				ccb:erase(0)
			end
		end
		if ccb.Size > 0 then
			last_cmd = ccb[ccb.Size]
		end
		new_prim_count += ch._PrimCount
		for cmd_n = 1, ccb.Size do
			local cmd = ccb[cmd_n]
			cmd.IdxOffset = idx_offset
			idx_offset += cmd.ElemCount
		end
	end
	local pb = draw_list.PrimBuffer
	local write = draw_list.PrimCount * PRIM_STRIDE
	for i = 1, self._Count - 1 do
		local ch = channels[i + 1]
		local ccb = ch._CmdBuffer
		for cmd_n = 1, ccb.Size do
			dcb:push_back(ccb[cmd_n])
		end
		local n = ch._PrimCount * PRIM_STRIDE
		if n > 0 then
			table.move(ch._PrimBuffer, 1, n, write + 1, pb)
			write += n
		end
	end
	draw_list.PrimCount += new_prim_count
	if dcb.Size == 0 or dcb[dcb.Size].UserCallback ~= nil then
		draw_list:AddDrawCmd()
	end
	local curr_cmd = dcb[dcb.Size]
	if curr_cmd.ElemCount == 0 then
		HeaderCopy(curr_cmd, draw_list._CmdHeader)
	elseif not HeaderEq(curr_cmd, draw_list._CmdHeader) then
		draw_list:AddDrawCmd()
	end
	self._Count = 1
end

function ImDrawListSplitter:SetCurrentChannel(draw_list, idx)
	assert(idx >= 0 and idx < self._Count)
	if self._Current == idx then
		return
	end
	local channels = self._Channels
	local cur = channels[self._Current + 1]
	cur._CmdBuffer = draw_list.CmdBuffer
	cur._PrimBuffer = draw_list.PrimBuffer
	cur._PrimCount = draw_list.PrimCount
	self._Current = idx
	local ch = channels[idx + 1]
	draw_list.CmdBuffer = ch._CmdBuffer
	draw_list.PrimBuffer = ch._PrimBuffer
	draw_list.PrimCount = ch._PrimCount
	local cb = draw_list.CmdBuffer
	local curr_cmd = if cb.Size == 0 then nil else cb[cb.Size]
	if curr_cmd == nil then
		draw_list:AddDrawCmd()
	elseif curr_cmd.ElemCount == 0 then
		HeaderCopy(curr_cmd, draw_list._CmdHeader)
	elseif not HeaderEq(curr_cmd, draw_list._CmdHeader) then
		draw_list:AddDrawCmd()
	end
end

local ImDrawData = {}
ImDrawData.__index = ImDrawData

function ImDrawData.new()
	local self = setmetatable({ CmdLists = ImVector.new() }, ImDrawData)
	self:Clear()
	return self
end

function ImDrawData:Clear()
	self.Valid = false
	self.FrameCount = 0
	self.TotalIdxCount = 0
	self.TotalVtxCount = 0
	self.CmdLists:resize(0)
	self.DisplayPos = VEC2_ZERO
	self.DisplaySize = VEC2_ZERO
	self.FramebufferScale = VEC2_ZERO
	self.OwnerViewport = nil
	self.Textures = nil
	self.CmdListsCount = 0
end

function ImGui.AddDrawListToDrawDataEx(draw_data, out_list, draw_list)
	local cb = draw_list.CmdBuffer
	if cb.Size == 0 then
		return
	end
	if cb.Size == 1 and cb[1].ElemCount == 0 and cb[1].UserCallback == nil then
		return
	end
	out_list:push_back(draw_list)
	draw_data.TotalIdxCount += draw_list.PrimCount
end

function ImDrawData:AddDrawList(draw_list)
	draw_list:_PopUnusedDrawCmd()
	ImGui.AddDrawListToDrawDataEx(self, self.CmdLists, draw_list)
end

function ImDrawData:DeIndexAllBuffers() end

function ImDrawData:ScaleClipRects(fb_scale)
	local lists = self.CmdLists
	for i = 1, lists.Size do
		local cb = lists[i].CmdBuffer
		for j = 1, cb.Size do
			local cmd = cb[j]
			local cr = cmd.ClipRect
			cmd.ClipRect = ImVec4(cr.x * fb_scale.x, cr.y * fb_scale.y, cr.z * fb_scale.x, cr.w * fb_scale.y)
		end
	end
end

local ImDrawDataBuilder = {}
ImDrawDataBuilder.__index = ImDrawDataBuilder

function ImDrawDataBuilder.new()
	return setmetatable({ Layers = {}, LayerData1 = ImVector.new() }, ImDrawDataBuilder)
end

local PrimColorSlots = {
	[PK_RectFilled] = { 5 },
	[PK_Rect] = { 5 },
	[PK_Line] = { 5 },
	[PK_TriangleFilled] = { 7 },
	[PK_CircleFilled] = { 4 },
	[PK_Circle] = { 4 },
	[PK_Text] = { 3 },
	[PK_Image] = { 9 },
}

local function GradientColor(px, py, p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, col)
	local d = (px - p0x) * ex + (py - p0y) * ey
	local t = math.clamp(d * inv_len2, 0, 1)
	local r = trunc(col0_r + dr * t)
	local g = trunc(col0_g + dg * t)
	local b = trunc(col0_b + db * t)
	return bor(r, lshift(g, 8), lshift(b, 16), band(col, IM_COL32_A_MASK))
end

function ImGui.ShadeVertsLinearColorGradientKeepAlpha(draw_list, vert_start_idx, vert_end_idx, gradient_p0, gradient_p1, col0, col1)
	local ex, ey = gradient_p1.x - gradient_p0.x, gradient_p1.y - gradient_p0.y
	local inv_len2 = 1 / (ex * ex + ey * ey)
	local p0x, p0y = gradient_p0.x, gradient_p0.y
	local col0_r = band(col0, 0xFF)
	local col0_g = band(rshift(col0, 8), 0xFF)
	local col0_b = band(rshift(col0, 16), 0xFF)
	local dr = band(col1, 0xFF) - col0_r
	local dg = band(rshift(col1, 8), 0xFF) - col0_g
	local db = band(rshift(col1, 16), 0xFF) - col0_b
	local pb = draw_list.PrimBuffer
	for n = vert_start_idx, vert_end_idx - 1 do
		local b = n * PRIM_STRIDE
		local kind = pb[b + 1]
		if kind == PK_TriangleMultiColor then
			for k = 0, 2 do
				local slot = b + 9 + k
				pb[slot] = GradientColor(pb[b + 2 + k * 2], pb[b + 3 + k * 2], p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, pb[slot])
			end
		elseif kind == PK_RectMultiColor then
			local x1, y1, x2, y2 = pb[b + 2], pb[b + 3], pb[b + 4], pb[b + 5]
			pb[b + 6] = GradientColor(x1, y1, p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, pb[b + 6])
			pb[b + 7] = GradientColor(x2, y1, p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, pb[b + 7])
			pb[b + 8] = GradientColor(x2, y2, p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, pb[b + 8])
			pb[b + 9] = GradientColor(x1, y2, p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, pb[b + 9])
		else
			local slots = PrimColorSlots[kind]
			if slots ~= nil then
				local cx, cy
				if kind == PK_TriangleFilled then
					cx, cy = (pb[b + 2] + pb[b + 4] + pb[b + 6]) / 3, (pb[b + 3] + pb[b + 5] + pb[b + 7]) / 3
				elseif kind == PK_CircleFilled or kind == PK_Circle or kind == PK_Text then
					cx, cy = pb[b + 2], pb[b + 3]
				else
					cx, cy = (pb[b + 2] + pb[b + 4]) * 0.5, (pb[b + 3] + pb[b + 5]) * 0.5
				end
				local slot = b + 1 + slots[1]
				pb[slot] = GradientColor(cx, cy, p0x, p0y, ex, ey, inv_len2, col0_r, col0_g, col0_b, dr, dg, db, pb[slot])
			end
		end
	end
end

function ImGui.ShadeVertsLinearUV(draw_list, vert_start_idx, vert_end_idx, a, b, uv_a, uv_b, clamp)
	local size_x, size_y = b.x - a.x, b.y - a.y
	local uv_size_x, uv_size_y = uv_b.x - uv_a.x, uv_b.y - uv_a.y
	local scale_x = if size_x ~= 0 then uv_size_x / size_x else 0
	local scale_y = if size_y ~= 0 then uv_size_y / size_y else 0
	local min_u, min_v = min(uv_a.x, uv_b.x), min(uv_a.y, uv_b.y)
	local max_u, max_v = max(uv_a.x, uv_b.x), max(uv_a.y, uv_b.y)
	local pb = draw_list.PrimBuffer
	for n = vert_start_idx, vert_end_idx - 1 do
		local base = n * PRIM_STRIDE
		if pb[base + 1] == PK_Image then
			local u0 = uv_a.x + (pb[base + 2] - a.x) * scale_x
			local v0 = uv_a.y + (pb[base + 3] - a.y) * scale_y
			local u1 = uv_a.x + (pb[base + 4] - a.x) * scale_x
			local v1 = uv_a.y + (pb[base + 5] - a.y) * scale_y
			if clamp then
				u0, v0 = math.clamp(u0, min_u, max_u), math.clamp(v0, min_v, max_v)
				u1, v1 = math.clamp(u1, min_u, max_u), math.clamp(v1, min_v, max_v)
			end
			pb[base + 6], pb[base + 7], pb[base + 8], pb[base + 9] = u0, v0, u1, v1
		end
	end
end

function ImGui.ShadeVertsTransformPos(draw_list, vert_start_idx, vert_end_idx, pivot_in, cos_a, sin_a, pivot_out)
	local pb = draw_list.PrimBuffer
	local pix, piy, pox, poy = pivot_in.x, pivot_in.y, pivot_out.x, pivot_out.y
	local function tx(x, y)
		local dx, dy = x - pix, y - piy
		return dx * cos_a - dy * sin_a + pox, dx * sin_a + dy * cos_a + poy
	end
	local angle = math.atan2(sin_a, cos_a)
	for n = vert_start_idx, vert_end_idx - 1 do
		local b = n * PRIM_STRIDE
		local kind = pb[b + 1]
		if kind == PK_Text then
			pb[b + 2], pb[b + 3] = tx(pb[b + 2], pb[b + 3])
			pb[b + 12] = (pb[b + 12] or 0) + angle
			if angle ~= 0 then
				pb[b + 8], pb[b + 9], pb[b + 10], pb[b + 11] = -FLT_MAX, -FLT_MAX, FLT_MAX, FLT_MAX
			end
		elseif kind == PK_Line then
			pb[b + 2], pb[b + 3] = tx(pb[b + 2], pb[b + 3])
			pb[b + 4], pb[b + 5] = tx(pb[b + 4], pb[b + 5])
		elseif kind == PK_TriangleFilled or kind == PK_TriangleMultiColor then
			pb[b + 2], pb[b + 3] = tx(pb[b + 2], pb[b + 3])
			pb[b + 4], pb[b + 5] = tx(pb[b + 4], pb[b + 5])
			pb[b + 6], pb[b + 7] = tx(pb[b + 6], pb[b + 7])
		elseif kind == PK_CircleFilled or kind == PK_Circle then
			pb[b + 2], pb[b + 3] = tx(pb[b + 2], pb[b + 3])
		elseif kind ~= nil then
			local x1, y1 = tx(pb[b + 2], pb[b + 3])
			local x2, y2 = tx(pb[b + 4], pb[b + 5])
			pb[b + 2], pb[b + 3], pb[b + 4], pb[b + 5] = min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2)
		end
	end
end

function ImTextureData.new()
	return setmetatable({
		UniqueID = 0,
		Status = ImTextureStatus.Destroyed,
		BackendUserData = nil,
		QueueUserData = nil,
		TexID = nil,
		Format = ImTextureFormat.RGBA32,
		Width = 0,
		Height = 0,
		BytesPerPixel = 0,
		Pixels = nil,
		UsedRect = { x = 0, y = 0, w = 0, h = 0 },
		UpdateRect = { x = 0, y = 0, w = 0, h = 0 },
		Updates = ImVector.new(),
		UnusedFrames = 0,
		RefCount = 0,
		UseColors = false,
		WantDestroyNextFrame = false,
	}, ImTextureData)
end

local function ImTextureDataGetFormatBytesPerPixel(format)
	if format == ImTextureFormat.Alpha8 then
		return 1
	elseif format == ImTextureFormat.RGBA32 then
		return 4
	end
	assert(false)
	return 0
end
DrawList.ImTextureDataGetFormatBytesPerPixel = ImTextureDataGetFormatBytesPerPixel

local TextureStatusNames = {
	[ImTextureStatus.OK] = "OK",
	[ImTextureStatus.Destroyed] = "Destroyed",
	[ImTextureStatus.WantCreate] = "WantCreate",
	[ImTextureStatus.WantUpdates] = "WantUpdates",
	[ImTextureStatus.WantDestroy] = "WantDestroy",
}

function DrawList.ImTextureDataGetStatusName(status)
	return TextureStatusNames[status] or "N/A"
end

function DrawList.ImTextureDataGetFormatName(format)
	if format == ImTextureFormat.Alpha8 then
		return "Alpha8"
	elseif format == ImTextureFormat.RGBA32 then
		return "RGBA32"
	end
	return "N/A"
end

function ImTextureData:Create(format, w, h)
	assert(self.Status == ImTextureStatus.Destroyed)
	self:DestroyPixels()
	self.Format = format
	self.Status = ImTextureStatus.WantCreate
	self.Width = w
	self.Height = h
	self.BytesPerPixel = ImTextureDataGetFormatBytesPerPixel(format)
	self.UseColors = false
	self.Pixels = nil
	self.UsedRect = { x = 0, y = 0, w = 0, h = 0 }
	self.UpdateRect = { x = 0xFFFF, y = 0xFFFF, w = 0, h = 0 }
end

function ImTextureData:DestroyPixels()
	self.Pixels = nil
	self.UseColors = false
end

function ImTextureData:GetPixels()
	assert(self.Pixels ~= nil)
	return self.Pixels
end

function ImTextureData:GetPixelsAt(x, y)
	assert(self.Pixels ~= nil)
	return (x + y * self.Width) * self.BytesPerPixel
end

function ImTextureData:GetSizeInBytes()
	return self.Width * self.Height * self.BytesPerPixel
end

function ImTextureData:GetPitch()
	return self.Width * self.BytesPerPixel
end

function ImTextureData:GetTexRef()
	return self
end

function ImTextureData:GetTexID()
	return self.TexID
end

function ImTextureData:SetTexID(tex_id)
	self.TexID = tex_id
end

function ImTextureData:SetStatus(status)
	self.Status = status
	if status == ImTextureStatus.Destroyed and not self.WantDestroyNextFrame and self.Pixels ~= nil then
		self.Status = ImTextureStatus.WantCreate
	end
end

function DrawList.ImTextureDataUpdateNewFrame(tex)
	local remove_from_list = false
	if tex.Status == ImTextureStatus.OK then
		tex.Updates:resize(0)
		tex.UpdateRect = { x = 0xFFFF, y = 0xFFFF, w = 0, h = 0 }
	end
	if tex.WantDestroyNextFrame and tex.Status ~= ImTextureStatus.Destroyed and tex.Status ~= ImTextureStatus.WantDestroy then
		assert(tex.Status == ImTextureStatus.OK or tex.Status == ImTextureStatus.WantCreate or tex.Status == ImTextureStatus.WantUpdates)
		tex.Status = ImTextureStatus.WantDestroy
	end
	if tex.Status == ImTextureStatus.WantDestroy and tex.TexID == nil and tex.BackendUserData == nil and tex.QueueUserData == nil then
		tex.Status = ImTextureStatus.Destroyed
	end
	if tex.Status == ImTextureStatus.Destroyed then
		assert(tex.TexID == nil and tex.BackendUserData == nil, "Backend set texture Status to Destroyed but did not clear TexID/BackendUserData!")
		assert(tex.QueueUserData == nil, "Texture queue set Status to Destroyed but did not clear QueueUserData!")
		if tex.WantDestroyNextFrame then
			remove_from_list = true
		else
			tex.Status = ImTextureStatus.WantCreate
		end
	end
	if tex.Status == ImTextureStatus.WantDestroy then
		tex.UnusedFrames += 1
	end
	return remove_from_list
end

function DrawList.ImTextureDataQueueUpload(tex, x, y, w, h)
	assert(tex.Status ~= ImTextureStatus.WantDestroy and tex.Status ~= ImTextureStatus.Destroyed)
	local ur, us = tex.UpdateRect, tex.UsedRect
	local new_x1 = max(if ur.w == 0 then 0 else ur.x + ur.w, x + w)
	local new_y1 = max(if ur.h == 0 then 0 else ur.y + ur.h, y + h)
	ur.x = min(ur.x, x)
	ur.y = min(ur.y, y)
	ur.w = new_x1 - ur.x
	ur.h = new_y1 - ur.y
	local used_x1 = max(us.x + us.w, x + w)
	local used_y1 = max(us.y + us.h, y + h)
	us.x = min(us.x, x)
	us.y = min(us.y, y)
	us.w = used_x1 - us.x
	us.h = used_y1 - us.y
	if tex.Status == ImTextureStatus.OK or tex.Status == ImTextureStatus.WantUpdates then
		tex.Status = ImTextureStatus.WantUpdates
		tex.Updates:push_back({ x = x, y = y, w = w, h = h })
	end
end

local ImFontConfig = {}
ImFontConfig.__index = ImFontConfig

function ImFontConfig.new()
	return setmetatable({
		Name = "",
		FontData = nil,
		FontDataSize = 0,
		FontDataOwnedByAtlas = true,
		MergeMode = false,
		PixelSnapH = false,
		OversampleH = 0,
		OversampleV = 0,
		EllipsisChar = 0,
		SizePixels = 0,
		GlyphRanges = nil,
		GlyphExcludeRanges = nil,
		GlyphOffset = VEC2_ZERO,
		GlyphMinAdvanceX = 0,
		GlyphMaxAdvanceX = FLT_MAX,
		GlyphExtraAdvanceX = 0,
		FontNo = 0,
		FontLoaderFlags = 0,
		RasterizerMultiply = 1,
		RasterizerDensity = 1,
		ExtraSizeScale = 1,
		Flags = 0,
		DstFont = nil,
		FontLoader = nil,
		FontLoaderData = nil,
	}, ImFontConfig)
end

function ImFontConfig:Copy()
	return setmetatable(table.clone(self), ImFontConfig)
end

local ImFontGlyph = {}
ImFontGlyph.__index = ImFontGlyph

function ImFontGlyph.new()
	return setmetatable({
		Colored = false,
		Visible = false,
		SourceIdx = 0,
		Codepoint = 0,
		AdvanceX = 0,
		X0 = 0,
		Y0 = 0,
		X1 = 0,
		Y1 = 0,
		U0 = 0,
		V0 = 0,
		U1 = 0,
		V1 = 0,
		PackId = -1,
	}, ImFontGlyph)
end

function ImFontGlyph:Copy()
	return setmetatable(table.clone(self), ImFontGlyph)
end

local ImFontAtlasRect = {}
ImFontAtlasRect.__index = ImFontAtlasRect

function ImFontAtlasRect.new()
	return setmetatable({ x = 0, y = 0, w = 0, h = 0, uv0 = VEC2_ZERO, uv1 = VEC2_ZERO }, ImFontAtlasRect)
end

local ImFontBaked = {}
ImFontBaked.__index = ImFontBaked

function ImFontBaked.new()
	return setmetatable({
		IndexAdvanceX = ImVector.new(),
		FallbackAdvanceX = 0,
		Size = 0,
		RasterizerDensity = 0,
		IndexLookup = ImVector.new(),
		Glyphs = ImVector.new(),
		FallbackGlyphIndex = -1,
		Ascent = 0,
		Descent = 0,
		MetricsTotalSurface = 0,
		WantDestroy = false,
		LoadNoFallback = false,
		LoadNoRenderOnLayout = false,
		LastUsedFrame = 0,
		BakedId = 0,
		OwnerFont = nil,
		FontLoaderDatas = nil,
	}, ImFontBaked)
end

function ImFontBaked:ClearOutputData()
	self.FallbackAdvanceX = 0
	self.Glyphs:clear()
	self.IndexAdvanceX:clear()
	self.IndexLookup:clear()
	MonoInfos[self] = nil
	self.FallbackGlyphIndex = -1
	self.Ascent = 0
	self.Descent = 0
	self.MetricsTotalSurface = 0
end

local ImFont = {}
ImFont.__index = ImFont
ImFont.RobloxFontFace = nil

function ImFont.new()
	return setmetatable({
		LastBaked = nil,
		OwnerAtlas = nil,
		Flags = 0,
		CurrentRasterizerDensity = 0,
		FontId = 0,
		LegacySize = 0,
		Sources = ImVector.new(),
		EllipsisChar = 0,
		FallbackChar = 0,
		Used8kPagesMap = table.create((IM_UNICODE_CODEPOINT_MAX + 1) // 8192 // 8, 0),
		EllipsisAutoBake = false,
		RemapPairs = {},
		RemapPairsCount = 0,
		Scale = 1,
		AdvanceRatio = DEFAULT_ADVANCE_RATIO,
		RobloxFont = ROBLOX_FONT_NAME,
	}, ImFont)
end

local ImFontAtlasBuilder = {}
ImFontAtlasBuilder.__index = ImFontAtlasBuilder

function ImFontAtlasBuilder.new()
	return setmetatable({
		Rects = {},
		RectsIndex = ImVector.new(),
		RectsIndexFreeListStart = -1,
		RectsPackedCount = 0,
		RectsPackedSurface = 0,
		RectsDiscardedCount = 0,
		RectsDiscardedSurface = 0,
		FrameCount = -1,
		MaxRectSize = VEC2_ZERO,
		MaxRectBounds = VEC2_ZERO,
		LockDisableResize = false,
		PreloadedAllGlyphsRanges = false,
		BakedPool = ImVector.new(),
		BakedMap = {},
		BakedDiscardedCount = 0,
		PackIdMouseCursors = -1,
		PackIdLinesTexData = -1,
		PackIdLineFractTexData = -1,
		PackIdCornersTexData = -1,
		TexUvLines = {},
		TexUvCorners = {},
		_NextRectId = 0,
	}, ImFontAtlasBuilder)
end

local ImFontAtlas = {}
ImFontAtlas.__index = ImFontAtlas

function ImFontAtlas.new()
	return setmetatable({
		Flags = 0,
		TexDesiredFormat = ImTextureFormat.RGBA32,
		TexGlyphPadding = 1,
		TexMinWidth = 512,
		TexMinHeight = 128,
		TexMaxWidth = 8192,
		TexMaxHeight = 8192,
		UserData = nil,
		TexRef = nil,
		TexData = nil,
		TexList = ImVector.new(),
		Locked = false,
		RendererHasTextures = false,
		TexIsBuilt = false,
		TexPixelsUseColors = false,
		TexUvScale = vcreate(1, 1, 0),
		TexUvWhitePixel = VEC2_ZERO,
		Fonts = ImVector.new(),
		Sources = ImVector.new(),
		TexNextUniqueID = 1,
		FontNextUniqueID = 1,
		DrawListSharedDatas = ImVector.new(),
		Builder = nil,
		FontLoader = nil,
		FontLoaderName = nil,
		FontLoaderData = nil,
		FontLoaderFlags = 0,
		RefCount = 0,
		OwnerContext = nil,
		TempRect = ImFontAtlasRect.new(),
	}, ImFontAtlas)
end

local RobloxFontLoader = {
	Name = "RobloxMonospace",
	LoaderInit = nil,
	LoaderShutdown = nil,
	FontSrcInit = nil,
	FontSrcDestroy = nil,
	FontSrcGetGlyphIndexFromCodepoint = function(atlas, src, codepoint)
		if codepoint < 32 or (codepoint >= 0x7F and codepoint < 0xA0) or (codepoint >= 0xD800 and codepoint <= 0xDFFF) or codepoint > 0xFFFF then
			return 0
		end
		return codepoint
	end,
	FontSrcContainsGlyph = function(atlas, src, glyph_index)
		return glyph_index ~= 0
	end,
	FontBakedInit = function(atlas, src, baked, loader_data_for_baked_src)
		baked.Ascent = baked.Size
		baked.Descent = 0
		return true
	end,
	FontBakedDestroy = nil,
	FontBakedLoadGlyph = function(atlas, src, baked, loader_data_for_baked_src, glyph_index, out_glyph, out_advance_x)
		local advance_for_size = DrawList.AdvanceForSize
		local advance_x = if advance_for_size ~= nil then advance_for_size(baked.Size) else baked.Size * baked.OwnerFont.AdvanceRatio
		if out_glyph ~= nil then
			out_glyph.AdvanceX = advance_x
			out_glyph.X0 = 0
			out_glyph.Y0 = 0
			out_glyph.X1 = advance_x
			out_glyph.Y1 = baked.Size
			out_glyph.Visible = true
		end
		return true, advance_x
	end,
	FontBakedSrcLoaderDataSize = 0,
}

function DrawList.ImFontAtlasGetFontLoaderForStbTruetype()
	return RobloxFontLoader
end

local function FontLoaderOf(atlas, src)
	return src.FontLoader or atlas.FontLoader
end

local function ImFontBaked_BuildGrowIndex(baked, new_size)
	assert(baked.IndexAdvanceX.Size == baked.IndexLookup.Size)
	if new_size <= baked.IndexLookup.Size then
		return
	end
	baked.IndexAdvanceX:resize(new_size, -1)
	baked.IndexLookup:resize(new_size, IM_FONTGLYPH_INDEX_UNUSED)
end

local function ImFontAtlasBakedAddFontGlyph(atlas, baked, src, in_glyph)
	local glyph_idx = baked.Glyphs.Size
	local glyph = in_glyph:Copy()
	baked.Glyphs:push_back(glyph)
	assert(baked.Glyphs.Size < 0xFFFE)
	if src ~= nil then
		local ref_size = baked.OwnerFont.Sources[1].SizePixels
		local offsets_scale = if ref_size ~= 0 then baked.Size / ref_size else 1
		local advance_x = math.clamp(glyph.AdvanceX, src.GlyphMinAdvanceX * offsets_scale, src.GlyphMaxAdvanceX * offsets_scale)
		if advance_x ~= glyph.AdvanceX then
			local char_off_x = if src.PixelSnapH then trunc((advance_x - glyph.AdvanceX) * 0.5) else (advance_x - glyph.AdvanceX) * 0.5
			glyph.X0 += char_off_x
			glyph.X1 += char_off_x
		end
		glyph.AdvanceX = advance_x + src.GlyphExtraAdvanceX
	end
	if glyph.Colored then
		atlas.TexPixelsUseColors = true
		if atlas.TexData ~= nil then
			atlas.TexData.UseColors = true
		end
	end
	local codepoint = glyph.Codepoint
	ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
	baked.IndexAdvanceX[codepoint + 1] = glyph.AdvanceX
	baked.IndexLookup[codepoint + 1] = glyph_idx
	local page_n = codepoint // 8192
	local pages = baked.OwnerFont.Used8kPagesMap
	local k = rshift(page_n, 3) + 1
	pages[k] = bor(pages[k] or 0, lshift(1, band(page_n, 7)))
	return glyph
end
DrawList.ImFontAtlasBakedAddFontGlyph = ImFontAtlasBakedAddFontGlyph

function DrawList.ImFontAtlasBakedAddFontGlyphAdvancedX(atlas, baked, src, codepoint, advance_x)
	if src ~= nil then
		local ref_size = baked.OwnerFont.Sources[1].SizePixels
		local offsets_scale = if ref_size ~= 0 then baked.Size / ref_size else 1
		advance_x = math.clamp(advance_x, src.GlyphMinAdvanceX * offsets_scale, src.GlyphMaxAdvanceX * offsets_scale)
		advance_x += src.GlyphExtraAdvanceX
	end
	ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
	baked.IndexAdvanceX[codepoint + 1] = advance_x
	MonoInfos[baked] = nil
end

function DrawList.ImFontAtlasBakedSetFontGlyphBitmap(atlas, baked, src, glyph, r, src_pixels, src_fmt, src_pitch) end

local function ImFontAtlasBuildSetupFontBakedFallback(baked)
	assert(baked.FallbackGlyphIndex == -1)
	assert(baked.FallbackAdvanceX == 0)
	local font = baked.OwnerFont
	local fallback_glyph = nil
	if font.FallbackChar ~= 0 then
		fallback_glyph = baked:FindGlyphNoFallback(font.FallbackChar)
	end
	if fallback_glyph == nil then
		local space_glyph = baked:FindGlyphNoFallback(32)
		local glyph = ImFontGlyph.new()
		glyph.Codepoint = 0
		glyph.AdvanceX = if space_glyph ~= nil then space_glyph.AdvanceX else IM_ROUND(baked.Size * 0.40)
		fallback_glyph = ImFontAtlasBakedAddFontGlyph(font.OwnerAtlas, baked, nil, glyph)
	end
	baked.FallbackGlyphIndex = baked.Glyphs:index_from_ptr(fallback_glyph)
	baked.FallbackAdvanceX = fallback_glyph.AdvanceX
end

local function ImFontAtlasBuildSetupFontBakedBlanks(atlas, baked)
	local space_glyph = baked:FindGlyphNoFallback(32)
	if space_glyph ~= nil then
		space_glyph.Visible = false
	end
	if baked:FindGlyphNoFallback(9) == nil and space_glyph ~= nil then
		local tab_glyph = ImFontGlyph.new()
		tab_glyph.Codepoint = 9
		tab_glyph.AdvanceX = space_glyph.AdvanceX * IM_TABSIZE
		ImFontAtlasBakedAddFontGlyph(atlas, baked, nil, tab_glyph)
	end
end

local function ImFontAtlasBuildAcceptCodepointForSource(src, codepoint)
	local exclude_list = src.GlyphExcludeRanges
	if exclude_list ~= nil then
		local i = 1
		while exclude_list[i] ~= nil and exclude_list[i] ~= 0 do
			if codepoint >= exclude_list[i] and codepoint <= exclude_list[i + 1] then
				return false
			end
			i += 2
		end
	end
	return true
end

local IMFONT_REMAPVALUE_GLYPHIDX_SHIFT = 0
local IMFONT_REMAPVALUE_GLYPHIDX_MASK = 0xFFFF
local IMFONT_REMAPVALUE_FONTSRCIDX_SHIFT = 16
local IMFONT_REMAPVALUE_FONTSRCIDX_MASK = 0xFF0000

function ImFont:AddRemapCodepoint(from_codepoint, to_codepoint)
	assert(band(to_codepoint, 0x80000000) == 0)
	if self.RemapPairs[from_codepoint] == nil then
		self.RemapPairsCount += 1
	end
	self.RemapPairs[from_codepoint] = to_codepoint
end

function ImFont:AddRemapCodepointToGlyphIndex(from_codepoint, font_src_idx, glyph_idx)
	if font_src_idx == -1 then
		font_src_idx = self.Sources.Size - 1
	end
	assert(font_src_idx >= 0 and font_src_idx < self.Sources.Size and band(lshift(font_src_idx, IMFONT_REMAPVALUE_FONTSRCIDX_SHIFT), bnot(IMFONT_REMAPVALUE_FONTSRCIDX_MASK)) == 0)
	assert(glyph_idx >= 0 and band(lshift(glyph_idx, IMFONT_REMAPVALUE_GLYPHIDX_SHIFT), bnot(IMFONT_REMAPVALUE_GLYPHIDX_MASK)) == 0)
	local data = bor(lshift(glyph_idx, IMFONT_REMAPVALUE_GLYPHIDX_SHIFT), lshift(font_src_idx, IMFONT_REMAPVALUE_FONTSRCIDX_SHIFT), 0x80000000)
	if self.RemapPairs[from_codepoint] == nil then
		self.RemapPairsCount += 1
	end
	self.RemapPairs[from_codepoint] = data
end

local function ImFontAtlas_FontHookRemapCodepoint(atlas, font, codepoint)
	if font.RemapPairsCount == 0 then
		return codepoint, -1, -1
	end
	local data = font.RemapPairs[codepoint]
	if data == nil then
		return codepoint, -1, -1
	end
	if btest(data, 0x80000000) then
		return -1, rshift(band(data, IMFONT_REMAPVALUE_FONTSRCIDX_MASK), IMFONT_REMAPVALUE_FONTSRCIDX_SHIFT), rshift(band(data, IMFONT_REMAPVALUE_GLYPHIDX_MASK), IMFONT_REMAPVALUE_GLYPHIDX_SHIFT)
	end
	return data, -1, -1
end

local function ImFontBaked_BuildLoadGlyph(baked, codepoint)
	local font = baked.OwnerFont
	local atlas = font.OwnerAtlas
	if btest(font.Flags, ImFontFlags.NoLoadGlyphs) then
		if baked.FallbackGlyphIndex == -1 and not baked.LoadNoFallback then
			ImFontAtlasBuildSetupFontBakedFallback(baked)
		end
		return nil
	end
	local src_codepoint, src_font_idx, src_glyph_idx = ImFontAtlas_FontHookRemapCodepoint(atlas, font, codepoint)
	local sources = font.Sources
	for src_n = 0, sources.Size - 1 do
		local src = sources[src_n + 1]
		local loader = FontLoaderOf(atlas, src)
		local glyph_index
		if src_codepoint ~= -1 then
			if src.GlyphExcludeRanges ~= nil and not ImFontAtlasBuildAcceptCodepointForSource(src, src_codepoint) then
				continue
			end
			glyph_index = loader.FontSrcGetGlyphIndexFromCodepoint(atlas, src, src_codepoint)
		else
			if src_n ~= src_font_idx then
				continue
			end
			glyph_index = src_glyph_idx
		end
		if glyph_index == 0 then
			continue
		end
		local glyph_buf = ImFontGlyph.new()
		glyph_buf.Codepoint = codepoint
		if loader.FontBakedLoadGlyph(atlas, src, baked, nil, glyph_index, glyph_buf, nil) then
			glyph_buf.SourceIdx = src_n
			return ImFontAtlasBakedAddFontGlyph(atlas, baked, src, glyph_buf)
		end
	end
	if baked.LoadNoFallback then
		return nil
	end
	if baked.FallbackGlyphIndex == -1 then
		ImFontAtlasBuildSetupFontBakedFallback(baked)
	end
	ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
	baked.IndexAdvanceX[codepoint + 1] = baked.FallbackAdvanceX
	baked.IndexLookup[codepoint + 1] = IM_FONTGLYPH_INDEX_NOT_FOUND
	return nil
end

local function BuildLoadGlyphGetAdvanceOrFallback(baked, codepoint)
	local glyph = ImFontBaked_BuildLoadGlyph(baked, codepoint)
	if glyph ~= nil then
		return glyph.AdvanceX
	end
	return baked.FallbackAdvanceX
end
DrawList.ImFontBaked_BuildLoadGlyphAdvanceX = BuildLoadGlyphGetAdvanceOrFallback

function ImFontBaked:FindGlyph(c)
	local lookup = self.IndexLookup
	if c < lookup.Size then
		local i = lookup[c + 1]
		if i == IM_FONTGLYPH_INDEX_NOT_FOUND then
			return self.Glyphs[self.FallbackGlyphIndex + 1]
		end
		if i ~= IM_FONTGLYPH_INDEX_UNUSED then
			return self.Glyphs[i + 1]
		end
	end
	local glyph = ImFontBaked_BuildLoadGlyph(self, c)
	return glyph or self.Glyphs[self.FallbackGlyphIndex + 1]
end

function ImFontBaked:FindGlyphNoFallback(c)
	local lookup = self.IndexLookup
	if c < lookup.Size then
		local i = lookup[c + 1]
		if i == IM_FONTGLYPH_INDEX_NOT_FOUND then
			return nil
		end
		if i ~= IM_FONTGLYPH_INDEX_UNUSED then
			return self.Glyphs[i + 1]
		end
	end
	self.LoadNoFallback = true
	local glyph = ImFontBaked_BuildLoadGlyph(self, c)
	self.LoadNoFallback = false
	return glyph
end

function ImFontBaked:IsGlyphLoaded(c)
	local lookup = self.IndexLookup
	if c < lookup.Size then
		local i = lookup[c + 1]
		if i == IM_FONTGLYPH_INDEX_NOT_FOUND then
			return false
		end
		if i ~= IM_FONTGLYPH_INDEX_UNUSED then
			return true
		end
	end
	return false
end

function ImFontBaked:GetCharAdvance(c)
	local adv = self.IndexAdvanceX
	if c < adv.Size then
		local x = adv[c + 1]
		if x >= 0 then
			return x
		end
	end
	return BuildLoadGlyphGetAdvanceOrFallback(self, c)
end

function ImFont:IsGlyphInFont(c)
	local atlas = self.OwnerAtlas
	local src_codepoint, src_font_idx, src_glyph_idx = ImFontAtlas_FontHookRemapCodepoint(atlas, self, c)
	if src_font_idx ~= -1 then
		local src = self.Sources[src_font_idx + 1]
		local loader = FontLoaderOf(atlas, src)
		if loader.FontSrcContainsGlyph ~= nil then
			return loader.FontSrcContainsGlyph(atlas, src, src_glyph_idx)
		end
		return false
	end
	local sources = self.Sources
	for i = 1, sources.Size do
		local src = sources[i]
		local loader = FontLoaderOf(atlas, src)
		if loader.FontSrcGetGlyphIndexFromCodepoint(atlas, src, src_codepoint) ~= 0 then
			return true
		end
	end
	return false
end

function ImFont:IsLoaded()
	return self.OwnerAtlas ~= nil
end

function ImFont:GetDebugName()
	if self.Sources.Size ~= 0 then
		return self.Sources[1].Name
	end
	return "<unknown>"
end

function ImFont:ClearOutputData()
	local atlas = self.OwnerAtlas
	if atlas ~= nil then
		DrawList.ImFontAtlasFontDiscardBakes(atlas, self, 0)
	end
	table.clear(self.Used8kPagesMap)
	for i = 1, (IM_UNICODE_CODEPOINT_MAX + 1) // 8192 // 8 do
		self.Used8kPagesMap[i] = 0
	end
	self.LastBaked = nil
end

function ImFont:IsGlyphRangeUnused(c_begin, c_last)
	local page_begin = c_begin // 8192
	local page_last = c_last // 8192
	local pages = self.Used8kPagesMap
	for page_n = page_begin, page_last do
		local k = rshift(page_n, 3) + 1
		if k <= #pages and btest(pages[k], lshift(1, band(page_n, 7))) then
			return false
		end
	end
	return true
end

local function ImFontAtlasBakedGetId(font_id, baked_size, rasterizer_density)
	return Base.ImHashStr(string.format("%d|%.9g|%.9g", font_id, baked_size, rasterizer_density))
end
DrawList.ImFontAtlasBakedGetId = ImFontAtlasBakedGetId

function DrawList.ImFontAtlasBakedAdd(atlas, font, font_size, font_rasterizer_density, baked_id)
	DebugLogFont("[font] Created baked %.2fpx\n", font_size)
	local builder = atlas.Builder
	local baked = ImFontBaked.new()
	builder.BakedPool:push_back(baked)
	baked.Size = font_size
	baked.RasterizerDensity = font_rasterizer_density
	baked.BakedId = baked_id
	baked.OwnerFont = font
	baked.LastUsedFrame = builder.FrameCount
	local sources = font.Sources
	for i = 1, sources.Size do
		local src = sources[i]
		local loader = FontLoaderOf(atlas, src)
		if loader.FontBakedInit ~= nil then
			loader.FontBakedInit(atlas, src, baked, nil)
		end
	end
	ImFontAtlasBuildSetupFontBakedBlanks(atlas, baked)
	return baked
end

function DrawList.ImFontAtlasBakedGetClosestMatch(atlas, font, font_size, font_rasterizer_density)
	local pool = atlas.Builder.BakedPool
	for step_n = 0, 1 do
		local closest_larger_match = nil
		local closest_smaller_match = nil
		for baked_n = 1, pool.Size do
			local baked = pool[baked_n]
			if baked.OwnerFont ~= font or baked.WantDestroy then
				continue
			end
			if step_n == 0 and baked.RasterizerDensity ~= font_rasterizer_density then
				continue
			end
			if baked.Size > font_size and (closest_larger_match == nil or baked.Size < closest_larger_match.Size) then
				closest_larger_match = baked
			end
			if baked.Size < font_size and (closest_smaller_match == nil or baked.Size > closest_smaller_match.Size) then
				closest_smaller_match = baked
			end
		end
		if closest_larger_match ~= nil then
			if closest_smaller_match == nil or (closest_larger_match.Size >= font_size * 2 and closest_smaller_match.Size > font_size * 0.5) then
				return closest_larger_match
			end
		end
		if closest_smaller_match ~= nil then
			return closest_smaller_match
		end
	end
	return nil
end

function DrawList.ImFontAtlasBakedDiscard(atlas, font, baked)
	local builder = atlas.Builder
	DebugLogFont("[font] Discard baked %.2f for \"%s\"\n", baked.Size, font:GetDebugName())
	local glyphs = baked.Glyphs
	for i = 1, glyphs.Size do
		if glyphs[i].PackId ~= -1 then
			DrawList.ImFontAtlasPackDiscardRect(atlas, glyphs[i].PackId)
		end
	end
	local sources = font.Sources
	for i = 1, sources.Size do
		local src = sources[i]
		local loader = FontLoaderOf(atlas, src)
		if loader ~= nil and loader.FontBakedDestroy ~= nil then
			loader.FontBakedDestroy(atlas, src, baked, nil)
		end
	end
	baked.FontLoaderDatas = nil
	builder.BakedMap[baked.BakedId] = nil
	builder.BakedDiscardedCount += 1
	baked:ClearOutputData()
	baked.WantDestroy = true
	font.LastBaked = nil
end

function DrawList.ImFontAtlasFontDiscardBakes(atlas, font, unused_frames)
	local builder = atlas.Builder
	if builder ~= nil then
		local pool = builder.BakedPool
		for baked_n = 1, pool.Size do
			local baked = pool[baked_n]
			if baked.LastUsedFrame + unused_frames > builder.FrameCount then
				continue
			end
			if baked.OwnerFont ~= font or baked.WantDestroy then
				continue
			end
			DrawList.ImFontAtlasBakedDiscard(atlas, font, baked)
		end
	end
end

function DrawList.ImFontAtlasBuildDiscardBakes(atlas, unused_frames)
	local builder = atlas.Builder
	local pool = builder.BakedPool
	for baked_n = 1, pool.Size do
		local baked = pool[baked_n]
		if baked.LastUsedFrame + unused_frames > builder.FrameCount then
			continue
		end
		if baked.WantDestroy or btest(baked.OwnerFont.Flags, ImFontFlags.LockBakedSizes) then
			continue
		end
		DrawList.ImFontAtlasBakedDiscard(atlas, baked.OwnerFont, baked)
	end
end

function DrawList.ImFontAtlasBakedGetOrAdd(atlas, font, font_size, font_rasterizer_density)
	assert(font_size > 0 and font_rasterizer_density > 0)
	local baked_id = ImFontAtlasBakedGetId(font.FontId, font_size, font_rasterizer_density)
	local builder = atlas.Builder
	local baked = builder.BakedMap[baked_id]
	if baked ~= nil then
		assert(baked.Size == font_size and baked.OwnerFont == font and baked.BakedId == baked_id)
		return baked
	end
	if btest(font.Flags, ImFontFlags.LockBakedSizes) then
		baked = DrawList.ImFontAtlasBakedGetClosestMatch(atlas, font, font_size, font_rasterizer_density)
		if baked ~= nil then
			return baked
		end
	end
	baked = DrawList.ImFontAtlasBakedAdd(atlas, font, font_size, font_rasterizer_density, baked_id)
	builder.BakedMap[baked_id] = baked
	return baked
end

function DrawList.ImFontAtlasBakedDiscardFontGlyph(atlas, font, baked, glyph)
	if glyph.PackId ~= -1 then
		DrawList.ImFontAtlasPackDiscardRect(atlas, glyph.PackId)
		glyph.PackId = -1
	end
	local c = glyph.Codepoint
	assert(font.FallbackChar ~= c and font.EllipsisChar ~= c)
	baked.IndexLookup[c + 1] = IM_FONTGLYPH_INDEX_UNUSED
	baked.IndexAdvanceX[c + 1] = baked.FallbackAdvanceX
	MonoInfos[baked] = nil
end

function ImFont:GetFontBaked(size, density)
	local baked = self.LastBaked
	size = IM_ROUND(size)
	if density == nil or density < 0 then
		density = self.CurrentRasterizerDensity
	end
	if baked ~= nil and baked.Size == size and baked.RasterizerDensity == density then
		return baked
	end
	local atlas = self.OwnerAtlas
	local builder = atlas.Builder
	baked = DrawList.ImFontAtlasBakedGetOrAdd(atlas, self, size, density)
	if baked == nil then
		return nil
	end
	baked.LastUsedFrame = builder.FrameCount
	self.LastBaked = baked
	return baked
end

local CharClassifier_0000_007f = table.create(128 // 16, 0)
local CharClassifier_3000_300f = table.create(16 // 16, 0)

local function ImTextClassifierSetCharClass(bits, codepoint_min, codepoint_end, char_class, c)
	assert(c >= codepoint_min and c < codepoint_end)
	c -= codepoint_min
	local shift = lshift(band(c, 15), 1)
	local k = rshift(c, 4) + 1
	bits[k] = bor(band(bits[k], bnot(lshift(0x03, shift))), lshift(char_class, shift))
end
DrawList.ImTextClassifierSetCharClass = ImTextClassifierSetCharClass

local function ImTextClassifierClear(bits, codepoint_min, codepoint_end, char_class)
	for c = codepoint_min, codepoint_end - 1 do
		ImTextClassifierSetCharClass(bits, codepoint_min, codepoint_end, char_class, c)
	end
end
DrawList.ImTextClassifierClear = ImTextClassifierClear

local function ImTextClassifierSetCharClassFromStr(bits, codepoint_min, codepoint_end, char_class, s)
	local s_end = #s + 1
	local i = 1
	while i < s_end do
		local n, c = ImTextCharFromUtf8(s, i, s_end)
		i += n
		ImTextClassifierSetCharClass(bits, codepoint_min, codepoint_end, char_class, c)
	end
end
DrawList.ImTextClassifierSetCharClassFromStr = ImTextClassifierSetCharClassFromStr

local function ImTextClassifierGet(bits, char_offset)
	return band(rshift(bits[rshift(char_offset, 4) + 1], lshift(band(char_offset, 15), 1)), 0x03)
end

local function ImTextInitClassifiers()
	if ImTextClassifierGet(CharClassifier_0000_007f, 44) ~= 0 then
		return
	end
	ImTextClassifierClear(CharClassifier_0000_007f, 0, 128, ImWcharClass.Other)
	ImTextClassifierSetCharClassFromStr(CharClassifier_0000_007f, 0, 128, ImWcharClass.Blank, " \t")
	ImTextClassifierSetCharClassFromStr(CharClassifier_0000_007f, 0, 128, ImWcharClass.Punct, ".,;!?\"")
	ImTextClassifierClear(CharClassifier_3000_300f, 0x3000, 0x300F, ImWcharClass.Other)
	ImTextClassifierSetCharClass(CharClassifier_3000_300f, 0x3000, 0x300F, ImWcharClass.Blank, 0x3000)
	ImTextClassifierSetCharClass(CharClassifier_3000_300f, 0x3000, 0x300F, ImWcharClass.Punct, 0x3001)
	ImTextClassifierSetCharClass(CharClassifier_3000_300f, 0x3000, 0x300F, ImWcharClass.Punct, 0x3002)
end
DrawList.ImTextInitClassifiers = ImTextInitClassifiers

local function TextCalcWordWrapNextLineStart(text, s, text_end, flags)
	if not btest(flags, ImDrawTextFlags.WrapKeepBlanks) then
		while s < text_end do
			local c = sbyte(text, s)
			if c ~= 32 and c ~= 9 then
				break
			end
			s += 1
		end
	end
	if s < text_end and sbyte(text, s) == 10 then
		s += 1
	end
	return s
end

function DrawList.ImTextCalcWordWrapNextLineStart(text, text_end, flags, text_begin)
	return TextCalcWordWrapNextLineStart(text, text_begin or 1, text_end or #text + 1, flags or 0)
end

local CLASS_BLANK, CLASS_PUNCT, CLASS_OTHER = ImWcharClass.Blank, ImWcharClass.Punct, ImWcharClass.Other

local function FontCalcWordWrapPosition(font, size, text, s, text_end, wrap_width, flags)
	local baked = font:GetFontBaked(size)
	local scale = size / baked.Size
	local line_width = 0
	local blank_width = 0
	wrap_width /= scale
	local text_begin = s
	local prev_type = CLASS_OTHER
	local keep_blanks = btest(flags, ImDrawTextFlags.WrapKeepBlanks)
	local span_end = s
	local span_width = 0
	local adv = baked.IndexAdvanceX
	while s < text_end do
		local c = sbyte(text, s)
		local next_s
		if c < 0x80 then
			next_s = s + 1
		else
			local n
			n, c = ImTextCharFromUtf8(text, s, text_end)
			next_s = s + n
		end
		if c < 32 then
			if c == 10 then
				return s
			end
			if c == 13 then
				s = next_s
				continue
			end
		end
		local char_width = if c < adv.Size then adv[c + 1] else -1
		if char_width < 0 then
			char_width = BuildLoadGlyphGetAdvanceOrFallback(baked, c)
		end
		local curr_type
		if c < 128 then
			curr_type = ImTextClassifierGet(CharClassifier_0000_007f, c)
		elseif c >= 0x3000 and c < 0x3010 then
			curr_type = ImTextClassifierGet(CharClassifier_3000_300f, band(c, 15))
		else
			curr_type = CLASS_OTHER
		end
		if curr_type == CLASS_BLANK then
			if prev_type ~= CLASS_BLANK and not keep_blanks then
				span_end = s
				line_width += span_width
				span_width = 0
			end
			blank_width += char_width
		else
			if prev_type == CLASS_PUNCT and curr_type ~= CLASS_PUNCT and not (c >= 48 and c <= 57) then
				span_end = s
				line_width += span_width + blank_width
				span_width = 0
				blank_width = 0
			elseif prev_type == CLASS_BLANK and keep_blanks then
				span_end = s
				line_width += span_width + blank_width
				span_width = 0
				blank_width = 0
			end
			span_width += char_width
		end
		if span_width + blank_width + line_width > wrap_width then
			if span_width + blank_width > wrap_width then
				break
			end
			return span_end
		end
		prev_type = curr_type
		s = next_s
	end
	if s == text_begin and text_begin < text_end then
		return s + (ImTextCharFromUtf8(text, s, text_end))
	end
	return s
end

function DrawList.ImFontCalcWordWrapPositionEx(font, size, text, text_end, wrap_width, flags, text_begin)
	return FontCalcWordWrapPosition(font, size, text, text_begin or 1, text_end or #text + 1, wrap_width, flags or 0)
end

function ImFont:CalcWordWrapPosition(size, text, text_end, wrap_width, text_begin)
	return FontCalcWordWrapPosition(self, size, text, text_begin or 1, text_end or #text + 1, wrap_width, 0)
end

local MONO_EXACT_SCALE = 1048576
local MONO_EXACT_LIMIT = 1073741824

local MONO_MEMO_MAX_LEN = 1024
local MONO_MEMO_MAX_COUNT = 8192
local MONO_FULL_PATTERN = "[^\n -~]"
local MonoMemo = {}
local MonoMemoCount = 0
local MONO_PATTERN_SPECIAL = { [37] = true, [45] = true, [93] = true, [94] = true }

local function FontBakedMonoInfo(baked)
	local glyphs = baked.Glyphs
	local info = MonoInfos[baked]
	if info == nil or info.GlyphsSize ~= glyphs.Size then
		info = { GlyphsSize = glyphs.Size }
		MonoInfos[baked] = info
		local lookup, adv = baked.IndexLookup, baked.IndexAdvanceX
		local advance, x0, x1 = nil, 0, 0
		local has_visible = false
		local ok = {}
		for c = 32, 126 do
			local gi = if c < lookup.Size then lookup[c + 1] else IM_FONTGLYPH_INDEX_UNUSED
			if gi < IM_FONTGLYPH_INDEX_NOT_FOUND then
				local glyph = glyphs[gi + 1]
				local a = glyph.AdvanceX
				if advance == nil and a > 0 then
					advance = a
				end
				if glyph.Codepoint == c and a == advance and adv[c + 1] == a then
					if c == 32 then
						if not glyph.Visible then
							ok[c] = true
						end
					elseif glyph.Visible then
						if not has_visible then
							has_visible = true
							x0, x1 = glyph.X0, glyph.X1
						end
						if glyph.X0 == x0 and glyph.X1 == x1 then
							ok[c] = true
						end
					end
				end
			end
		end
		local parts = { "[^\n" }
		local c = 32
		while c <= 126 do
			if ok[c] then
				local a, b = c, c
				while b < 126 and ok[b + 1] do
					b += 1
				end
				c = b + 1
				while a <= b and MONO_PATTERN_SPECIAL[a] do
					parts[#parts + 1] = "%" .. string.char(a)
					a += 1
				end
				while a < b and MONO_PATTERN_SPECIAL[b] do
					parts[#parts + 1] = "%" .. string.char(b)
					b -= 1
				end
				if a < b then
					parts[#parts + 1] = string.char(a) .. "-" .. string.char(b)
				elseif a == b then
					local ch = string.char(a)
					parts[#parts + 1] = if sfind(ch, "%w") then ch else "%" .. ch
				end
			else
				c += 1
			end
		end
		parts[#parts + 1] = "]"
		info.Pattern = if advance ~= nil then table.concat(parts) else nil
		info.Advance = advance or 0
		info.X0 = x0
		info.X1 = x1
	end
	return info
end

local function MonoRange(baked, scale, x, text, s, e)
	local info = MonoInfos[baked]
	if info == nil or info.GlyphsSize ~= baked.Glyphs.Size then
		info = FontBakedMonoInfo(baked)
	end
	local pat = info.Pattern
	if pat == nil then
		return nil
	end
	local w = info.Advance * scale
	local qw, qx = w * MONO_EXACT_SCALE, x * MONO_EXACT_SCALE
	if not (w > 0 and w < MONO_EXACT_LIMIT and qw == floor(qw) and qx == floor(qx) and abs(x) + (e - s) * w < MONO_EXACT_LIMIT) then
		return nil
	end
	local len = #text
	local bad = 0
	if pat == MONO_FULL_PATTERN and len <= MONO_MEMO_MAX_LEN then
		bad = MonoMemo[text]
		if bad == nil then
			bad = sfind(text, pat) or len + 1
			if MonoMemoCount >= MONO_MEMO_MAX_COUNT then
				table.clear(MonoMemo)
				MonoMemoCount = 0
			end
			MonoMemoCount += 1
			MonoMemo[text] = bad
		end
		if bad >= s and bad < e then
			return nil
		end
	end
	if len - e >= 64 then
		local sub = ssub(text, s, e - 1)
		if bad < s and sfind(sub, pat) ~= nil then
			return nil
		end
		return sub, s - 1, w
	end
	if bad < s then
		local p = sfind(text, pat, s)
		if p ~= nil and p < e then
			return nil
		end
	end
	return text, 0, w
end

local function FontCalcTextSize(font, size, max_width, wrap_width, text, s, text_end_display, text_end, flags)
	if text_end == nil then
		text_end = #text + 1
	end
	if text_end_display == nil then
		text_end_display = text_end
	end
	local baked = font:GetFontBaked(size)
	local line_height = size
	local scale = line_height / baked.Size
	local text_size_x, text_size_y = 0, 0
	local line_width = 0
	local word_wrap_enabled = wrap_width > 0
	local word_wrap_eol = nil
	local stop_on_new_line = btest(flags, ImDrawTextFlags.StopOnNewLine)
	local mono_str, mono_off, mono_w = nil, 0, 0
	if not word_wrap_enabled then
		mono_str, mono_off, mono_w = MonoRange(baked, scale, 0, text, s, text_end_display)
	end
	if mono_str ~= nil then
		local p, pe = s - mono_off, text_end_display - mono_off
		while p < pe do
			local nl = sfind(mono_str, "\n", p, true)
			if nl ~= nil and nl >= pe then
				nl = nil
			end
			local n = (nl or pe) - p
			if n > 0 and n * mono_w >= max_width then
				local k = ceil(max_width / mono_w) - 1
				if k > n - 1 then
					k = n - 1
				end
				if k < 0 then
					k = 0
				end
				while k > 0 and (k - 1) * mono_w + mono_w >= max_width do
					k -= 1
				end
				while k < n - 1 and k * mono_w + mono_w < max_width do
					k += 1
				end
				line_width = k * mono_w
				p += k
				break
			end
			line_width = n * mono_w
			if nl == nil then
				p = pe
				break
			end
			text_size_x = max(text_size_x, line_width)
			text_size_y += line_height
			line_width = 0
			p = nl + 1
			if stop_on_new_line then
				break
			end
		end
		s = p + mono_off
	else
		local adv = baked.IndexAdvanceX
		while s < text_end_display do
			if word_wrap_enabled then
				if word_wrap_eol == nil then
					word_wrap_eol = FontCalcWordWrapPosition(font, size, text, s, text_end, wrap_width - line_width, flags)
				end
				if s >= word_wrap_eol then
					if text_size_x < line_width then
						text_size_x = line_width
					end
					text_size_y += line_height
					line_width = 0
					s = TextCalcWordWrapNextLineStart(text, s, text_end, flags)
					if stop_on_new_line then
						break
					end
					word_wrap_eol = nil
					continue
				end
			end
			local prev_s = s
			local c = sbyte(text, s)
			if c < 0x80 then
				s += 1
			else
				local n
				n, c = ImTextCharFromUtf8(text, s, text_end)
				s += n
			end
			if c == 10 then
				text_size_x = max(text_size_x, line_width)
				text_size_y += line_height
				line_width = 0
				if stop_on_new_line then
					break
				end
				continue
			end
			if c == 13 then
				continue
			end
			local char_width = if c < adv.Size then adv[c + 1] else -1
			if char_width < 0 then
				char_width = BuildLoadGlyphGetAdvanceOrFallback(baked, c)
			end
			char_width *= scale
			if line_width + char_width >= max_width then
				s = prev_s
				break
			end
			line_width += char_width
		end
	end
	if text_size_x < line_width then
		text_size_x = line_width
	end
	local out_offset = vcreate(line_width, text_size_y + line_height, 0)
	if line_width > 0 or text_size_y == 0 then
		text_size_y += line_height
	end
	return vcreate(text_size_x, text_size_y, 0), s, out_offset
end

function DrawList.ImFontCalcTextSizeEx(font, size, max_width, wrap_width, text, text_end_display, text_end, out_remaining, out_offset, flags, text_begin)
	return FontCalcTextSize(font, size, max_width, wrap_width, text, text_begin or 1, text_end_display, text_end, flags or 0)
end

function ImFont:CalcTextSizeA(size, max_width, wrap_width, text, text_end, out_remaining, text_begin)
	local text_size, remaining = FontCalcTextSize(self, size, max_width, wrap_width, text, text_begin or 1, text_end, text_end, 0)
	return text_size, remaining
end

local function SubstituteText(baked, text, a, b)
	local parts = {}
	local n = 0
	local s = a
	while s < b do
		local c = sbyte(text, s)
		local len = 1
		if c >= 0x80 then
			len, c = ImTextCharFromUtf8(text, s, b)
		end
		if c ~= 13 and c ~= 10 then
			local glyph = baked:FindGlyph(c)
			local gc = glyph.Codepoint
			n += 1
			if gc == 9 then
				parts[n] = string.rep(" ", IM_TABSIZE)
			elseif gc ~= c then
				parts[n] = if gc >= 32 then utf8.char(gc) else " "
			else
				parts[n] = ssub(text, s, s + len - 1)
			end
		end
		s += len
	end
	return table.concat(parts)
end

local function EmitTextLine(draw_list, font, baked, text, a, b, sub, x, x2, y, col, size, fine, cx1, cy1, cx2, cy2)
	local str = if sub then SubstituteText(baked, text, a, b) else ssub(text, a, b - 1)
	if fine and (x < cx1 or x2 > cx2 or y < cy1 or y + size > cy2) then
		PushPrim(draw_list, PK_Text, x, y, col, str, size, font, cx1, cy1, cx2, cy2, 0)
	else
		PushPrim(draw_list, PK_Text, x, y, col, str, size, font, -FLT_MAX, -FLT_MAX, FLT_MAX, FLT_MAX, 0)
	end
end

local function RenderTextMono(draw_list, font, baked, str, p, e, w, scale, x, y, col, size, fine, line_visible, cx1, cy1, cx2, cy2)
	local info = MonoInfos[baked]
	local x0s, x1s = info.X0 * scale, info.X1 * scale
	while p < e do
		local nl = sfind(str, "\n", p, true)
		if nl ~= nil and nl >= e then
			nl = nil
		end
		local le = nl or e
		if line_visible and le > p then
			local n = le - p
			local kmin = ceil((cx1 - x1s - x) / w)
			if kmin > n then
				kmin = n
			end
			if kmin < 0 then
				kmin = 0
			end
			while kmin > 0 and (x + (kmin - 1) * w) + x1s >= cx1 do
				kmin -= 1
			end
			while kmin < n and (x + kmin * w) + x1s < cx1 do
				kmin += 1
			end
			local kmax = floor((cx2 - x0s - x) / w)
			if kmax > n - 1 then
				kmax = n - 1
			end
			if kmax < -1 then
				kmax = -1
			end
			while kmax < n - 1 and (x + (kmax + 1) * w) + x0s <= cx2 do
				kmax += 1
			end
			while kmax >= 0 and (x + kmax * w) + x0s > cx2 do
				kmax -= 1
			end
			if kmin <= kmax then
				local a = sfind(str, "[^ ]", p + kmin)
				local b = p + kmax
				if a ~= nil and a <= b then
					while sbyte(str, b) == 32 do
						b -= 1
					end
					EmitTextLine(draw_list, font, baked, str, a, b + 1, false, (x + (a - p) * w) + x0s, (x + (b - p) * w) + x1s, y, col, size, fine, cx1, cy1, cx2, cy2)
				end
			end
		end
		if nl == nil then
			break
		end
		y += size
		if y > cy2 then
			break
		end
		line_visible = not fine or max(y, cy1) < min(y + size, cy2)
		p = nl + 1
	end
end

function ImFont:RenderText(draw_list, size, pos, col, clip_rect, text, text_end, wrap_width, flags, text_begin)
	if wrap_width == nil then
		wrap_width = 0
	end
	if flags == nil then
		flags = 0
	end
	local x, y = pos.x, pos.y
	local cx1, cy1, cx2, cy2 = clip_rect.x, clip_rect.y, clip_rect.z, clip_rect.w
	if y > cy2 then
		return
	end
	flags = bor(flags, draw_list.Flags)
	if not btest(flags, DF_TextNoPixelSnap) then
		x = trunc(x)
		y = trunc(y)
	end
	if text_end == nil then
		text_end = #text + 1
	end
	local line_height = size
	local baked = self:GetFontBaked(size)
	local scale = size / baked.Size
	local origin_x = x
	local word_wrap_enabled = wrap_width > 0
	local s = text_begin or 1
	if y + line_height < cy1 then
		while y + line_height < cy1 and s < text_end do
			local line_end = sfind(text, "\n", s, true)
			if line_end ~= nil and line_end >= text_end then
				line_end = nil
			end
			if word_wrap_enabled then
				s = FontCalcWordWrapPosition(self, size, text, s, line_end or text_end, wrap_width, flags)
				s = TextCalcWordWrapNextLineStart(text, s, text_end, flags)
			else
				s = if line_end ~= nil then line_end + 1 else text_end
			end
			y += line_height
		end
	end
	if text_end - s > 10000 and not word_wrap_enabled then
		local s_end = s
		local y_end = y
		while y_end < cy2 and s_end < text_end do
			local nl = sfind(text, "\n", s_end, true)
			s_end = if nl ~= nil and nl < text_end then nl + 1 else text_end
			y_end += line_height
		end
		text_end = s_end
	end
	if s == text_end then
		return
	end
	local cpu_fine_clip = btest(flags, ImDrawTextFlags.CpuFineClip)
	local line_visible = not cpu_fine_clip or max(y, cy1) < min(y + size, cy2)
	if not word_wrap_enabled then
		local str, off, w = MonoRange(baked, scale, x, text, s, text_end)
		if str ~= nil then
			RenderTextMono(draw_list, self, baked, str, s - off, text_end - off, w, scale, x, y, col, size, cpu_fine_clip, line_visible, cx1, cy1, cx2, cy2)
			return
		end
	end
	local lookup = baked.IndexLookup
	local glyphs = baked.Glyphs
	local word_wrap_eol = nil
	local seg_first, seg_last, seg_x, seg_x2, seg_sub = 0, 0, 0, 0, false
	while s < text_end do
		if word_wrap_enabled then
			if word_wrap_eol == nil then
				word_wrap_eol = FontCalcWordWrapPosition(self, size, text, s, text_end, wrap_width - (x - origin_x), flags)
			end
			if s >= word_wrap_eol then
				if seg_first ~= 0 then
					EmitTextLine(draw_list, self, baked, text, seg_first, seg_last, seg_sub, seg_x, seg_x2, y, col, size, cpu_fine_clip, cx1, cy1, cx2, cy2)
					seg_first = 0
				end
				x = origin_x
				y += line_height
				if y > cy2 then
					break
				end
				line_visible = not cpu_fine_clip or max(y, cy1) < min(y + size, cy2)
				word_wrap_eol = nil
				s = TextCalcWordWrapNextLineStart(text, s, text_end, flags)
				continue
			end
		end
		local cs = s
		local c = sbyte(text, s)
		if c < 0x80 then
			s += 1
		else
			local n
			n, c = ImTextCharFromUtf8(text, s, text_end)
			s += n
		end
		if c < 32 then
			if c == 10 then
				if seg_first ~= 0 then
					EmitTextLine(draw_list, self, baked, text, seg_first, seg_last, seg_sub, seg_x, seg_x2, y, col, size, cpu_fine_clip, cx1, cy1, cx2, cy2)
					seg_first = 0
				end
				x = origin_x
				y += line_height
				if y > cy2 then
					break
				end
				line_visible = not cpu_fine_clip or max(y, cy1) < min(y + size, cy2)
				continue
			end
			if c == 13 then
				if seg_first ~= 0 then
					seg_sub = true
				end
				continue
			end
		end
		local gi = if c < lookup.Size then lookup[c + 1] else IM_FONTGLYPH_INDEX_UNUSED
		local glyph
		if gi < IM_FONTGLYPH_INDEX_NOT_FOUND then
			glyph = glyphs[gi + 1]
		else
			glyph = baked:FindGlyph(c)
		end
		local char_width = glyph.AdvanceX * scale
		if glyph.Visible then
			local x1 = x + glyph.X0 * scale
			local x2 = x + glyph.X1 * scale
			if x1 <= cx2 and x2 >= cx1 and line_visible then
				if seg_first == 0 then
					seg_first = cs
					seg_x = x1
					seg_sub = false
				end
				seg_last = s
				seg_x2 = x2
				if c < 32 or glyph.Codepoint ~= c then
					seg_sub = true
				end
			end
		elseif seg_first ~= 0 and (c < 32 or glyph.Codepoint ~= c) then
			seg_sub = true
		end
		x += char_width
	end
	if seg_first ~= 0 then
		EmitTextLine(draw_list, self, baked, text, seg_first, seg_last, seg_sub, seg_x, seg_x2, y, col, size, cpu_fine_clip, cx1, cy1, cx2, cy2)
	end
end

function ImFont:RenderChar(draw_list, size, pos, col, c, cpu_fine_clip)
	local baked = self:GetFontBaked(size)
	local glyph = baked:FindGlyph(c)
	if glyph == nil or not glyph.Visible then
		return
	end
	local scale = if size >= 0 then size / baked.Size else 1
	local x, y = pos.x, pos.y
	if not btest(draw_list.Flags, DF_TextNoPixelSnap) then
		x = trunc(x)
		y = trunc(y)
	end
	local x1 = x + glyph.X0 * scale
	local x2 = x + glyph.X1 * scale
	if cpu_fine_clip ~= nil and (x1 > cpu_fine_clip.z or x2 < cpu_fine_clip.x) then
		return
	end
	local y1 = y + glyph.Y0 * scale
	local y2 = y + glyph.Y1 * scale
	local gc = glyph.Codepoint
	local str = if gc >= 32 then utf8.char(gc) else " "
	if cpu_fine_clip ~= nil then
		local fx1, fy1, fx2, fy2 = cpu_fine_clip.x, cpu_fine_clip.y, cpu_fine_clip.z, cpu_fine_clip.w
		if max(y1, fy1) >= min(y2, fy2) then
			return
		end
		if x1 < fx1 or y1 < fy1 or x2 > fx2 or y2 > fy2 then
			PushPrim(draw_list, PK_Text, x1, y1, col, str, size, self, fx1, fy1, fx2, fy2, 0)
			return
		end
	end
	PushPrim(draw_list, PK_Text, x1, y1, col, str, size, self, -FLT_MAX, -FLT_MAX, FLT_MAX, FLT_MAX, 0)
end

local function GetTextureAdd(atlas, w, h)
	local tex = ImTextureData.new()
	tex.UniqueID = atlas.TexNextUniqueID
	atlas.TexNextUniqueID += 1
	tex.Format = atlas.TexDesiredFormat
	tex.BytesPerPixel = ImTextureDataGetFormatBytesPerPixel(tex.Format)
	tex.Width = w
	tex.Height = h
	tex.Status = ImTextureStatus.OK
	atlas.TexList:push_back(tex)
	atlas.TexData = tex
	atlas.TexUvScale = vcreate(1 / w, 1 / h, 0)
	return tex
end

function DrawList.ImFontAtlasTextureAdd(atlas, w, h)
	local old_tex = atlas.TexData
	if old_tex ~= nil then
		old_tex.WantDestroyNextFrame = true
	end
	return GetTextureAdd(atlas, w, h)
end

function DrawList.ImFontAtlasTextureMakeSpace(atlas) end
function DrawList.ImFontAtlasTextureRepack(atlas, w, h) end
function DrawList.ImFontAtlasTextureGrow(atlas, old_w, old_h) end

function DrawList.ImFontAtlasTextureCompact(atlas)
	DrawList.ImFontAtlasBuildDiscardBakes(atlas, 1)
end

function DrawList.ImFontAtlasTextureGetSizeEstimate(atlas)
	return vcreate(atlas.TexMinWidth, atlas.TexMinHeight, 0)
end

function DrawList.ImFontAtlasTextureBlockConvert(src_pixels, src_fmt, src_pitch, dst_pixels, dst_fmt, dst_pitch, w, h) end
function DrawList.ImFontAtlasTextureBlockPostProcess(data) end
function DrawList.ImFontAtlasTextureBlockPostProcessMultiply(data, multiply_factor) end
function DrawList.ImFontAtlasTextureBlockFill(dst_tex, dst_x, dst_y, w, h, col) end
function DrawList.ImFontAtlasTextureBlockCopy(src_tex, src_x, src_y, dst_tex, dst_x, dst_y, w, h) end

function DrawList.ImFontAtlasTextureBlockQueueUpload(atlas, tex, x, y, w, h)
	DrawList.ImTextureDataQueueUpload(tex, x, y, w, h)
	atlas.TexIsBuilt = false
end

function DrawList.ImFontAtlasBuildRenderBitmapFromString(atlas, x, y, w, h, in_str, in_marker_char) end
function DrawList.ImFontAtlasDebugLogTextureRequests(atlas) end

function DrawList.ImFontAtlasPackInit(atlas)
	local builder = atlas.Builder
	builder.Rects = {}
	builder._NextRectId = 0
end

function DrawList.ImFontAtlasPackAddRect(atlas, w, h, overwrite_entry)
	local builder = atlas.Builder
	local id = builder._NextRectId
	builder._NextRectId = id + 1
	builder.Rects[id] = { x = 0, y = 0, w = w, h = h }
	builder.RectsPackedCount += 1
	builder.RectsPackedSurface += w * h
	return id
end

function DrawList.ImFontAtlasPackGetRect(atlas, id)
	local r = atlas.Builder.Rects[id]
	assert(r ~= nil)
	return r
end

function DrawList.ImFontAtlasPackGetRectSafe(atlas, id)
	if id == -1 or atlas.Builder == nil then
		return nil
	end
	return atlas.Builder.Rects[id]
end

function DrawList.ImFontAtlasPackDiscardRect(atlas, id)
	local builder = atlas.Builder
	local r = builder.Rects[id]
	if r == nil then
		return
	end
	builder.Rects[id] = nil
	builder.RectsPackedCount -= 1
	builder.RectsPackedSurface -= r.w * r.h
	builder.RectsDiscardedCount += 1
	builder.RectsDiscardedSurface += r.w * r.h
end

function DrawList.ImFontAtlasGetMouseCursorTexData(atlas, cursor_type, out_offset, out_size, out_uv_border, out_uv_fill)
	return false, out_offset, out_size
end

local function ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas)
	local datas = atlas.DrawListSharedDatas
	for i = 1, datas.Size do
		local imgui_ctx = datas[i].Context
		if imgui_ctx ~= nil then
			atlas.RendererHasTextures = btest(imgui_ctx.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures)
			break
		end
	end
end

function DrawList.ImFontAtlasBuildUpdatePointers(atlas)
	local fonts = atlas.Fonts
	for i = 1, fonts.Size do
		fonts[i].Sources:resize(0)
	end
	local sources = atlas.Sources
	for i = 1, sources.Size do
		local src = sources[i]
		src.DstFont.Sources:push_back(src)
	end
end

function DrawList.ImFontAtlasUpdateDrawListsSharedData(atlas)
	local datas = atlas.DrawListSharedDatas
	for i = 1, datas.Size do
		local shared_data = datas[i]
		if shared_data.FontAtlas == atlas then
			shared_data.TexUvWhitePixel = atlas.TexUvWhitePixel
			shared_data.TexUvLines = atlas.Builder.TexUvLines
			shared_data.TexUvCorners = atlas.Builder.TexUvCorners
		end
	end
end

function DrawList.ImFontAtlasUpdateDrawListsTextures(atlas, old_tex, new_tex)
	local datas = atlas.DrawListSharedDatas
	for i = 1, datas.Size do
		local shared_data = datas[i]
		if shared_data.Context ~= nil and not shared_data.Context.WithinFrameScope then
			continue
		end
		local lists = shared_data.DrawLists
		for j = 1, lists.Size do
			local draw_list = lists[j]
			if draw_list.CmdBuffer.Size > 0 and draw_list._CmdHeader.TexRef == old_tex then
				draw_list:_SetTexture(new_tex)
			end
			local stack = draw_list._TextureStack
			for k = 1, stack.Size do
				if stack[k] == old_tex then
					stack[k] = new_tex
				end
			end
		end
	end
end

function DrawList.ImFontAtlasAddDrawListSharedData(atlas, data)
	assert(not atlas.DrawListSharedDatas:contains(data))
	atlas.DrawListSharedDatas:push_back(data)
end

function DrawList.ImFontAtlasRemoveDrawListSharedData(atlas, data)
	assert(atlas.DrawListSharedDatas:contains(data))
	atlas.DrawListSharedDatas:find_erase(data)
end

function DrawList.ImFontAtlasBuildNotifySetFont(atlas, old_font, new_font)
	local datas = atlas.DrawListSharedDatas
	for i = 1, datas.Size do
		local shared_data = datas[i]
		if shared_data.Font == old_font then
			shared_data.Font = new_font
		end
		local ctx = shared_data.Context
		if ctx ~= nil then
			if old_font == nil and ctx.Font == nil and ctx.FontSizeBase == 0 then
				continue
			end
			if ctx.IO.FontDefault == old_font then
				ctx.IO.FontDefault = new_font
			end
			if ctx.Font == old_font then
				local curr_ctx = ImGui.GetCurrentContext()
				local need_bind_ctx = ctx ~= curr_ctx
				if need_bind_ctx then
					ImGui.SetCurrentContext(ctx)
				end
				ImGui.SetCurrentFont(new_font, ctx.FontSizeBase, ctx.FontSize)
				if need_bind_ctx then
					ImGui.SetCurrentContext(curr_ctx)
				end
			end
			local stack = ctx.FontStack
			for k = 1, stack.Size do
				if stack[k].Font == old_font then
					stack[k].Font = new_font
				end
			end
		end
	end
end

function DrawList.ImFontAtlasFontSourceInit(atlas, src)
	local loader = FontLoaderOf(atlas, src)
	if loader.FontSrcInit ~= nil and not loader.FontSrcInit(atlas, src) then
		return false
	end
	return true
end

function DrawList.ImFontAtlasBuildSetupFontSpecialGlyphs(atlas, font, src)
	assert(font.Sources:contains(src))
	if font.FallbackChar == 0 then
		for _, candidate_char in { font.FallbackChar, IM_UNICODE_CODEPOINT_INVALID, 63, 32 } do
			if candidate_char ~= 0 and font:IsGlyphInFont(candidate_char) then
				font.FallbackChar = candidate_char
				break
			end
		end
	end
	if font.EllipsisChar == 0 then
		for _, candidate_char in { src.EllipsisChar, 0x2026, 0x0085 } do
			if candidate_char ~= 0 and font:IsGlyphInFont(candidate_char) then
				font.EllipsisChar = candidate_char
				break
			end
		end
	end
	if font.EllipsisChar == 0 then
		font.EllipsisChar = 0x0085
		font.EllipsisAutoBake = true
	end
end

function DrawList.ImFontAtlasFontSourceAddToFont(atlas, font, src)
	if not src.MergeMode then
		font:ClearOutputData()
		font.OwnerAtlas = atlas
		assert(font.Sources[1] == src)
	end
	atlas.TexIsBuilt = false
	DrawList.ImFontAtlasBuildSetupFontSpecialGlyphs(atlas, font, src)
end

function DrawList.ImFontAtlasFontDestroySourceData(atlas, src)
	src.FontData = nil
	src.GlyphExcludeRanges = nil
end

function DrawList.ImFontAtlasFontInitOutput(atlas, font)
	local ret = true
	local sources = font.Sources
	for i = 1, sources.Size do
		if not DrawList.ImFontAtlasFontSourceInit(atlas, sources[i]) then
			ret = false
		end
	end
	assert(ret)
	return ret
end

function DrawList.ImFontAtlasFontDestroyOutput(atlas, font)
	font:ClearOutputData()
	local sources = font.Sources
	for i = 1, sources.Size do
		local src = sources[i]
		local loader = FontLoaderOf(atlas, src)
		if loader ~= nil and loader.FontSrcDestroy ~= nil then
			loader.FontSrcDestroy(atlas, src)
		end
	end
end

function DrawList.ImFontAtlasFontRebuildOutput(atlas, font)
	DrawList.ImFontAtlasFontDestroyOutput(atlas, font)
	DrawList.ImFontAtlasFontInitOutput(atlas, font)
end

function DrawList.ImFontAtlasBuildSetupFontLoader(atlas, font_loader)
	if atlas.FontLoader == font_loader then
		return
	end
	assert(not atlas.Locked, "Cannot modify a locked ImFontAtlas!")
	local fonts = atlas.Fonts
	for i = 1, fonts.Size do
		DrawList.ImFontAtlasFontDestroyOutput(atlas, fonts[i])
	end
	if atlas.Builder ~= nil and atlas.FontLoader ~= nil and atlas.FontLoader.LoaderShutdown ~= nil then
		atlas.FontLoader.LoaderShutdown(atlas)
	end
	atlas.FontLoader = font_loader
	atlas.FontLoaderName = if font_loader ~= nil then font_loader.Name else "NULL"
	assert(atlas.FontLoaderData == nil)
	if atlas.Builder ~= nil and atlas.FontLoader ~= nil and atlas.FontLoader.LoaderInit ~= nil then
		atlas.FontLoader.LoaderInit(atlas)
	end
	for i = 1, fonts.Size do
		DrawList.ImFontAtlasFontInitOutput(atlas, fonts[i])
	end
	for i = 1, fonts.Size do
		local font = fonts[i]
		local sources = font.Sources
		for j = 1, sources.Size do
			DrawList.ImFontAtlasFontSourceAddToFont(atlas, font, sources[j])
		end
	end
end

function DrawList.ImFontAtlasBuildInit(atlas)
	if atlas.FontLoader == nil then
		atlas:SetFontLoader(DrawList.ImFontAtlasGetFontLoaderForStbTruetype())
	end
	if atlas.TexData == nil then
		GetTextureAdd(atlas, Base.ImUpperPowerOfTwo(atlas.TexMinWidth), Base.ImUpperPowerOfTwo(atlas.TexMinHeight))
	end
	atlas.Builder = ImFontAtlasBuilder.new()
	if atlas.FontLoader.LoaderInit ~= nil then
		atlas.FontLoader.LoaderInit(atlas)
	end
	ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas)
	DrawList.ImFontAtlasPackInit(atlas)
	DrawList.ImFontAtlasBuildUpdatePointers(atlas)
	DrawList.ImFontAtlasUpdateDrawListsSharedData(atlas)
	ImTextInitClassifiers()
end

function DrawList.ImFontAtlasBuildDestroy(atlas)
	local fonts = atlas.Fonts
	for i = 1, fonts.Size do
		DrawList.ImFontAtlasFontDestroyOutput(atlas, fonts[i])
	end
	if atlas.Builder ~= nil and atlas.FontLoader ~= nil and atlas.FontLoader.LoaderShutdown ~= nil then
		atlas.FontLoader.LoaderShutdown(atlas)
		assert(atlas.FontLoaderData == nil)
	end
	atlas.Builder = nil
end

function DrawList.ImFontAtlasBuildClear(atlas)
	DrawList.ImFontAtlasBuildDestroy(atlas)
	DrawList.ImFontAtlasBuildInit(atlas)
	local sources = atlas.Sources
	for i = 1, sources.Size do
		DrawList.ImFontAtlasFontSourceInit(atlas, sources[i])
	end
	local fonts = atlas.Fonts
	for i = 1, fonts.Size do
		local font = fonts[i]
		for j = 1, font.Sources.Size do
			DrawList.ImFontAtlasFontSourceAddToFont(atlas, font, font.Sources[j])
		end
	end
end

function DrawList.ImFontAtlasBuildGetOversampleFactors(src, baked, out_oversample_h, out_oversample_v)
	local raster_size = baked.Size * baked.RasterizerDensity * src.RasterizerDensity
	local h = if src.OversampleH ~= 0 then src.OversampleH elseif raster_size > 36 or src.PixelSnapH then 1 else 2
	local v = if src.OversampleV ~= 0 then src.OversampleV else 1
	return h, v
end

function DrawList.ImFontAtlasBuildLegacyPreloadAllGlyphRanges(atlas)
	atlas.Builder.PreloadedAllGlyphsRanges = true
	local fonts = atlas.Fonts
	for i = 1, fonts.Size do
		local font = fonts[i]
		local baked = font:GetFontBaked(font.LegacySize)
		if font.FallbackChar ~= 0 then
			baked:FindGlyph(font.FallbackChar)
		end
		if font.EllipsisChar ~= 0 then
			baked:FindGlyph(font.EllipsisChar)
		end
		local sources = font.Sources
		for j = 1, sources.Size do
			local ranges = sources[j].GlyphRanges or atlas:GetGlyphRangesDefault()
			local k = 1
			while ranges[k] ~= nil and ranges[k] ~= 0 do
				for c = ranges[k], min(ranges[k + 1], IM_UNICODE_CODEPOINT_MAX) do
					baked:FindGlyph(c)
				end
				k += 2
			end
		end
	end
end

function DrawList.ImFontAtlasBuildMain(atlas)
	assert(not atlas.Locked, "Cannot modify a locked ImFontAtlas!")
	if atlas.TexData ~= nil and atlas.TexData.Format ~= atlas.TexDesiredFormat then
		DrawList.ImFontAtlasBuildClear(atlas)
	end
	if atlas.Builder == nil then
		DrawList.ImFontAtlasBuildInit(atlas)
	end
	if atlas.Sources.Size == 0 then
		atlas:AddFontDefault()
	end
	ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas)
	if not atlas.RendererHasTextures then
		DrawList.ImFontAtlasBuildLegacyPreloadAllGlyphRanges(atlas)
	end
	atlas.TexIsBuilt = true
end

function DrawList.ImFontAtlasUpdateNewFrame(atlas, frame_count, renderer_has_textures)
	assert(atlas.Builder == nil or atlas.Builder.FrameCount < frame_count)
	atlas.RendererHasTextures = renderer_has_textures
	local tex_list = atlas.TexList
	local tex_n = 0
	while tex_n < tex_list.Size do
		local tex = tex_list[tex_n + 1]
		if tex.Status == ImTextureStatus.WantCreate and atlas.RendererHasTextures then
			assert(tex.TexID == nil and tex.BackendUserData == nil, "Backend set texture's TexID/BackendUserData but did not update Status to OK.")
		end
		local remove_from_list = DrawList.ImTextureDataUpdateNewFrame(tex)
		if remove_from_list then
			assert(atlas.TexData ~= tex)
			tex:DestroyPixels()
			tex_list:erase(tex_n)
			tex_n -= 1
		end
		tex_n += 1
	end
	if atlas.RendererHasTextures then
		atlas.TexIsBuilt = true
		if atlas.Builder == nil then
			DrawList.ImFontAtlasBuildMain(atlas)
		end
	end
	if not atlas.RendererHasTextures and not atlas.TexIsBuilt then
		UserError("Backend does not support ImGuiBackendFlags_RendererHasTextures, and font atlas is not built! Update backend OR make sure you called ImGui_ImplXXXX_NewFrame() function for renderer backend, which should call io.Fonts->GetTexDataAsRGBA32() / GetTexDataAsAlpha8().")
	end
	if atlas.TexIsBuilt and atlas.Builder.PreloadedAllGlyphsRanges and atlas.RendererHasTextures then
		UserError("Called ImFontAtlas::Build() before ImGuiBackendFlags_RendererHasTextures got set! With new backends: you don't need to call Build().")
	end
	local builder = atlas.Builder
	builder.FrameCount = frame_count
	local fonts = atlas.Fonts
	for i = 1, fonts.Size do
		fonts[i].LastBaked = nil
	end
	if builder.BakedDiscardedCount > 0 then
		local pool = builder.BakedPool
		local dst_n = 0
		for src_n = 1, pool.Size do
			local baked = pool[src_n]
			if not baked.WantDestroy then
				dst_n += 1
				pool[dst_n] = baked
			end
		end
		assert(dst_n + builder.BakedDiscardedCount == pool.Size)
		for k = dst_n + 1, pool.Size do
			pool[k] = nil
		end
		pool.Size = dst_n
		builder.BakedDiscardedCount = 0
	end
end

function ImFontAtlas:AddFont(font_cfg_in)
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	assert((font_cfg_in.FontData ~= nil and font_cfg_in.FontDataSize > 0) or font_cfg_in.FontLoader ~= nil)
	assert(font_cfg_in.RasterizerDensity > 0, "Is ImFontConfig struct correctly initialized?")
	if font_cfg_in.GlyphOffset.x ~= 0 or font_cfg_in.GlyphOffset.y ~= 0 or font_cfg_in.GlyphMinAdvanceX ~= 0 or font_cfg_in.GlyphMaxAdvanceX ~= FLT_MAX then
		assert(font_cfg_in.SizePixels ~= 0, "Specifying glyph offset/advances requires a reference size to base it on.")
	end
	if self.Builder == nil then
		DrawList.ImFontAtlasBuildInit(self)
	end
	local is_first_font = self.Fonts.Size == 0
	local font
	if not font_cfg_in.MergeMode then
		font = ImFont.new()
		font.FontId = self.FontNextUniqueID
		self.FontNextUniqueID += 1
		font.Flags = font_cfg_in.Flags
		font.LegacySize = font_cfg_in.SizePixels
		font.CurrentRasterizerDensity = font_cfg_in.RasterizerDensity
		self.Fonts:push_back(font)
	else
		assert(self.Fonts.Size > 0, "Cannot use MergeMode for the first font!")
		font = font_cfg_in.DstFont or self.Fonts:back()
		DrawList.ImFontAtlasFontDiscardBakes(self, font, 0)
	end
	local font_cfg = font_cfg_in:Copy()
	self.Sources:push_back(font_cfg)
	if font_cfg.DstFont == nil then
		font_cfg.DstFont = font
	end
	font.Sources:push_back(font_cfg)
	DrawList.ImFontAtlasBuildUpdatePointers(self)
	if font_cfg.GlyphExcludeRanges ~= nil then
		local size = 0
		while font_cfg.GlyphExcludeRanges[size + 1] ~= nil and font_cfg.GlyphExcludeRanges[size + 1] ~= 0 do
			size += 1
		end
		assert(band(size, 1) == 0, "GlyphExcludeRanges[] size must be multiple of two!")
		assert(size <= 64, "GlyphExcludeRanges[] size must be small!")
		font_cfg.GlyphExcludeRanges = table.clone(font_cfg.GlyphExcludeRanges)
	end
	if font_cfg.FontLoader ~= nil then
		assert(font_cfg.FontLoader.FontSrcGetGlyphIndexFromCodepoint ~= nil and font_cfg.FontLoader.FontBakedLoadGlyph ~= nil)
		assert(font_cfg.FontLoader.LoaderInit == nil and font_cfg.FontLoader.LoaderShutdown == nil)
	end
	if font_cfg_in.MergeMode and font_cfg_in.SizePixels > 0 then
		assert(not btest(font.Flags, ImFontFlags.ImplicitRefSize), "Cannot use MergeMode with an explicit reference size when the destination font used an implicit reference size!")
	end
	assert(font_cfg.FontLoaderData == nil)
	if not DrawList.ImFontAtlasFontSourceInit(self, font_cfg) then
		DrawList.ImFontAtlasFontDestroySourceData(self, font_cfg)
		self.Sources:pop_back()
		font.Sources:pop_back()
		if not font_cfg.MergeMode then
			self.Fonts:pop_back()
		end
		return nil
	end
	DrawList.ImFontAtlasFontSourceAddToFont(self, font, font_cfg)
	if is_first_font then
		DrawList.ImFontAtlasBuildNotifySetFont(self, nil, font)
	end
	return font
end

local function GetExpectedContextFontSize(ctx)
	local io = ctx.IO
	local fb_scale = if io.DisplayFramebufferScale.x ~= 0 then io.DisplayFramebufferScale.x else 1
	if io.DisplayFramebufferScale.x == 1 and io.DisplaySize.x <= 0 and io.ConfigMacOSXBehaviors then
		fb_scale = 2
	end
	local scale = ctx.Style.FontScaleMain * ctx.Style.FontScaleDpi * fb_scale
	return (if ctx.Style.FontSizeBase > 0 then ctx.Style.FontSizeBase else 13) * scale
end

function ImFontAtlas:AddFontDefault(font_cfg)
	if self.OwnerContext == nil or GetExpectedContextFontSize(self.OwnerContext) >= 15 then
		return self:AddFontDefaultVector(font_cfg)
	end
	return self:AddFontDefaultBitmap(font_cfg)
end

local function DefaultFontConfig(font_cfg_template, name)
	local font_cfg = if font_cfg_template ~= nil then font_cfg_template:Copy() else ImFontConfig.new()
	if font_cfg_template == nil then
		font_cfg.PixelSnapH = true
	end
	if font_cfg.SizePixels <= 0 then
		font_cfg.SizePixels = 13
		font_cfg.Flags = bor(font_cfg.Flags, ImFontFlags.ImplicitRefSize)
	end
	if font_cfg.Name == "" then
		font_cfg.Name = name
	end
	font_cfg.FontData = ROBLOX_FONT_NAME
	font_cfg.FontDataSize = #ROBLOX_FONT_NAME
	font_cfg.FontDataOwnedByAtlas = false
	return font_cfg
end

function ImFontAtlas:AddFontDefaultBitmap(font_cfg_template)
	local font_cfg = DefaultFontConfig(font_cfg_template, "ProggyClean.ttf")
	font_cfg.EllipsisChar = 0x0085
	font_cfg.GlyphOffset = vcreate(font_cfg.GlyphOffset.x, font_cfg.GlyphOffset.y + 1 * (font_cfg.SizePixels / 13), 0)
	return self:AddFont(font_cfg)
end

function ImFontAtlas:AddFontDefaultVector(font_cfg_template)
	local font_cfg = DefaultFontConfig(font_cfg_template, "ProggyForever.ttf")
	font_cfg.ExtraSizeScale *= 1.015
	font_cfg.GlyphOffset = vcreate(font_cfg.GlyphOffset.x, font_cfg.GlyphOffset.y + 0.5 * (font_cfg.SizePixels / 16), 0)
	return self:AddFont(font_cfg)
end

function ImFontAtlas:AddFontFromFileTTF(filename, size_pixels, font_cfg_template, glyph_ranges)
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	local data, data_size = Base.ImFileLoadToMemory(filename, "rb", nil, 0)
	if data == nil then
		if font_cfg_template == nil or not btest(font_cfg_template.Flags, ImFontFlags.NoLoadError) then
			ImGui.DebugLog("While loading '%s'\n", filename)
			UserError("Could not load font file!")
		end
		return nil
	end
	local font_cfg = if font_cfg_template ~= nil then font_cfg_template:Copy() else ImFontConfig.new()
	if font_cfg.Name == "" then
		font_cfg.Name = string.match(filename, "([^/\\]*)$") or filename
	end
	return self:AddFontFromMemoryTTF(data, data_size, size_pixels, font_cfg, glyph_ranges)
end

function ImFontAtlas:AddFontFromMemoryTTF(font_data, font_data_size, size_pixels, font_cfg_template, glyph_ranges)
	if size_pixels == nil then
		size_pixels = 0
	end
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	local font_cfg = if font_cfg_template ~= nil then font_cfg_template:Copy() else ImFontConfig.new()
	assert(font_cfg.FontData == nil)
	assert(font_data_size > 100, "Incorrect value for font_data_size!")
	font_cfg.FontData = font_data
	font_cfg.FontDataSize = font_data_size
	font_cfg.SizePixels = if size_pixels > 0 then size_pixels else font_cfg.SizePixels
	if glyph_ranges ~= nil then
		font_cfg.GlyphRanges = glyph_ranges
	end
	return self:AddFont(font_cfg)
end

function ImFontAtlas:AddFontFromMemoryCompressedTTF(compressed_font_data, compressed_font_data_size, size_pixels, font_cfg_template, glyph_ranges)
	local font_cfg = if font_cfg_template ~= nil then font_cfg_template:Copy() else ImFontConfig.new()
	assert(font_cfg.FontData == nil)
	font_cfg.FontDataOwnedByAtlas = true
	return self:AddFontFromMemoryTTF(compressed_font_data, compressed_font_data_size, size_pixels, font_cfg, glyph_ranges)
end

function ImFontAtlas:AddFontFromMemoryCompressedBase85TTF(compressed_font_data_base85, size_pixels, font_cfg, glyph_ranges)
	local compressed_ttf_size = ((#compressed_font_data_base85 + 4) // 5) * 4
	return self:AddFontFromMemoryCompressedTTF(compressed_font_data_base85, compressed_ttf_size, size_pixels, font_cfg, glyph_ranges)
end

function ImFontAtlas:RemoveFont(font)
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	DrawList.ImFontAtlasFontDestroyOutput(self, font)
	for i = 1, font.Sources.Size do
		DrawList.ImFontAtlasFontDestroySourceData(self, font.Sources[i])
	end
	local sources = self.Sources
	local src_n = 0
	while src_n < sources.Size do
		if sources[src_n + 1].DstFont == font then
			sources:erase(src_n)
		else
			src_n += 1
		end
	end
	local removed = self.Fonts:find_erase(font)
	assert(removed)
	DrawList.ImFontAtlasBuildUpdatePointers(self)
	font.OwnerAtlas = nil
	local new_current_font = if self.Fonts:empty() then nil else self.Fonts[1]
	DrawList.ImFontAtlasBuildNotifySetFont(self, font, new_current_font)
end

function ImFontAtlas:CompactCache()
	DrawList.ImFontAtlasTextureCompact(self)
end

function ImFontAtlas:SetFontLoader(font_loader)
	DrawList.ImFontAtlasBuildSetupFontLoader(self, font_loader)
end

function ImFontAtlas:Clear()
	DebugLogFont("[font] ImFontAtlas::Clear()\n")
	local backup_renderer_has_textures = self.RendererHasTextures
	self.RendererHasTextures = false
	self:ClearFonts()
	self:ClearTexData()
	self.RendererHasTextures = backup_renderer_has_textures
end

function ImFontAtlas:ClearFonts()
	DebugLogFont("[font] ImFontAtlas::ClearFonts()\n")
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	local fonts = self.Fonts
	for i = 1, fonts.Size do
		DrawList.ImFontAtlasBuildNotifySetFont(self, fonts[i], nil)
	end
	DrawList.ImFontAtlasBuildDestroy(self)
	self:ClearInputData()
	self.Fonts:clear()
	self.TexIsBuilt = false
	local datas = self.DrawListSharedDatas
	for i = 1, datas.Size do
		local shared_data = datas[i]
		if shared_data.FontAtlas == self then
			shared_data.Font = nil
			shared_data.FontScale = 0
			shared_data.FontSize = 0
		end
	end
end

function ImFontAtlas:ClearInputData()
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	local fonts = self.Fonts
	for i = 1, fonts.Size do
		DrawList.ImFontAtlasFontDestroyOutput(self, fonts[i])
	end
	for i = 1, self.Sources.Size do
		DrawList.ImFontAtlasFontDestroySourceData(self, self.Sources[i])
	end
	for i = 1, fonts.Size do
		local font = fonts[i]
		font.Sources:clear()
		font.Flags = bor(font.Flags, ImFontFlags.NoLoadGlyphs)
	end
	self.Sources:clear()
end

function ImFontAtlas:ClearTexData()
	assert(not self.Locked, "Cannot modify a locked ImFontAtlas!")
	assert(self.RendererHasTextures == false, "Not supported for dynamic atlases, but you may call Clear().")
	local list = self.TexList
	for i = 1, list.Size do
		list[i]:DestroyPixels()
	end
end

function ImFontAtlas:Build()
	DrawList.ImFontAtlasBuildMain(self)
	return true
end

function ImFontAtlas:GetTexDataAsAlpha8(out_pixels, out_width, out_height, out_bytes_per_pixel)
	if self.TexData == nil or self.Builder == nil then
		DrawList.ImFontAtlasBuildMain(self)
	end
	local tex = self.TexData
	return tex.Pixels, tex.Width, tex.Height, 1
end

function ImFontAtlas:GetTexDataAsRGBA32(out_pixels, out_width, out_height, out_bytes_per_pixel)
	if self.TexData == nil or self.Builder == nil then
		DrawList.ImFontAtlasBuildMain(self)
	end
	local tex = self.TexData
	return tex.Pixels, tex.Width, tex.Height, 4
end

function ImFontAtlas:SetTexID(id)
	if self.TexData ~= nil then
		self.TexData.TexID = id
	end
end

function ImFontAtlas:IsBuilt()
	return self.Fonts.Size > 0 and self.TexIsBuilt
end

function ImFontAtlas:GetGlyphRangesDefault()
	return { 0x0020, 0x00FF, 0 }
end

function ImFontAtlas:AddCustomRect(width, height, out_r)
	assert(width > 0 and width <= 0xFFFF)
	assert(height > 0 and height <= 0xFFFF)
	if self.Builder == nil then
		DrawList.ImFontAtlasBuildInit(self)
	end
	local r_id = DrawList.ImFontAtlasPackAddRect(self, width, height)
	if out_r ~= nil then
		self:GetCustomRect(r_id, out_r)
	end
	return r_id
end

function ImFontAtlas:RemoveCustomRect(id)
	if DrawList.ImFontAtlasPackGetRectSafe(self, id) == nil then
		return
	end
	DrawList.ImFontAtlasPackDiscardRect(self, id)
end

function ImFontAtlas:GetCustomRect(id, out_r)
	local r = DrawList.ImFontAtlasPackGetRectSafe(self, id)
	if r == nil then
		return false
	end
	assert(self.TexData.Width > 0 and self.TexData.Height > 0)
	if out_r == nil then
		return true
	end
	out_r.x = r.x
	out_r.y = r.y
	out_r.w = r.w
	out_r.h = r.h
	out_r.uv0 = vcreate(r.x, r.y, 0) * self.TexUvScale
	out_r.uv1 = vcreate(r.x + r.w, r.y + r.h, 0) * self.TexUvScale
	return true
end

function ImGui.RenderArrow(draw_list, pos, col, dir, scale)
	if scale == nil then
		scale = 1
	end
	local h = draw_list._Data.FontSize * 1.00
	local r = h * 0.40 * scale
	local center = pos + vcreate(h * 0.50, h * 0.50 * scale, 0)
	local a, b, c
	if dir == ImGuiDir.Up or dir == ImGuiDir.Down then
		if dir == ImGuiDir.Up then
			r = -r
		end
		a = vcreate(0.000, 0.750, 0) * r
		b = vcreate(-0.866, -0.750, 0) * r
		c = vcreate(0.866, -0.750, 0) * r
	elseif dir == ImGuiDir.Left or dir == ImGuiDir.Right then
		if dir == ImGuiDir.Left then
			r = -r
		end
		a = vcreate(0.750, 0.000, 0) * r
		b = vcreate(-0.750, 0.866, 0) * r
		c = vcreate(-0.750, -0.866, 0) * r
	else
		assert(false)
	end
	draw_list:AddTriangleFilled(center + a, center + b, center + c, col)
end

function ImGui.RenderBullet(draw_list, pos, col)
	local font_size = draw_list._Data.FontSize
	draw_list:AddCircleFilled(pos, font_size * 0.20, col, if font_size < 22 then 8 elseif font_size < 40 then 12 else 0)
end

function ImGui.RenderCheckMark(draw_list, pos, col, sz)
	local thickness = max(sz / 5, 1)
	sz -= thickness * 0.5
	pos += vcreate(thickness * 0.25, thickness * 0.25, 0)
	local third = sz / 3
	local bx = pos.x + third
	local by = pos.y + sz - third * 0.5
	draw_list:PathLineTo(vcreate(bx - third, by - third, 0))
	draw_list:PathLineTo(vcreate(bx, by, 0))
	draw_list:PathLineTo(vcreate(bx + third * 2, by - third * 2, 0))
	draw_list:PathStroke(col, thickness, DF_AALineEnds)
end

function ImGui.RenderArrowPointingAt(draw_list, pos, half_sz, direction, col)
	if direction == ImGuiDir.Left then
		draw_list:AddTriangleFilled(vcreate(pos.x + half_sz.x, pos.y - half_sz.y, 0), vcreate(pos.x + half_sz.x, pos.y + half_sz.y, 0), pos, col)
	elseif direction == ImGuiDir.Right then
		draw_list:AddTriangleFilled(vcreate(pos.x - half_sz.x, pos.y + half_sz.y, 0), vcreate(pos.x - half_sz.x, pos.y - half_sz.y, 0), pos, col)
	elseif direction == ImGuiDir.Up then
		draw_list:AddTriangleFilled(vcreate(pos.x + half_sz.x, pos.y + half_sz.y, 0), vcreate(pos.x - half_sz.x, pos.y + half_sz.y, 0), pos, col)
	elseif direction == ImGuiDir.Down then
		draw_list:AddTriangleFilled(vcreate(pos.x - half_sz.x, pos.y - half_sz.y, 0), vcreate(pos.x + half_sz.x, pos.y - half_sz.y, 0), pos, col)
	end
end

local function ImAcos01(x)
	if x <= 0 then
		return IM_PI * 0.5
	end
	if x >= 1 then
		return 0
	end
	return math.acos(x)
end

function ImGui.RenderRectFilledInRangeH(draw_list, rect, col, fill_x0, fill_x1, rounding)
	if fill_x0 > fill_x1 then
		return
	end
	local p0 = vcreate(fill_x0, rect.Min.y, 0)
	local p1 = vcreate(fill_x1, rect.Max.y, 0)
	if rounding == 0 then
		draw_list:AddRectFilled(p0, p1, col, 0)
		return
	end
	rounding = math.clamp(min((rect.Max.x - rect.Min.x) * 0.5, (rect.Max.y - rect.Min.y) * 0.5) - 1, 0, rounding)
	local inv_rounding = 1 / rounding
	local arc0_b = ImAcos01(1 - (p0.x - rect.Min.x) * inv_rounding)
	local arc0_e = ImAcos01(1 - (p1.x - rect.Min.x) * inv_rounding)
	local half_pi = IM_PI * 0.5
	local x0 = max(p0.x, rect.Min.x + rounding)
	if arc0_b == arc0_e then
		draw_list:PathLineTo(vcreate(x0, p1.y, 0))
		draw_list:PathLineTo(vcreate(x0, p0.y, 0))
	elseif arc0_b == 0 and arc0_e == half_pi then
		draw_list:PathArcToFast(vcreate(x0, p1.y - rounding, 0), rounding, 3, 6)
		draw_list:PathArcToFast(vcreate(x0, p0.y + rounding, 0), rounding, 6, 9)
	else
		draw_list:PathArcTo(vcreate(x0, p1.y - rounding, 0), rounding, IM_PI - arc0_e, IM_PI - arc0_b)
		draw_list:PathArcTo(vcreate(x0, p0.y + rounding, 0), rounding, IM_PI + arc0_b, IM_PI + arc0_e)
	end
	if p1.x > rect.Min.x + rounding then
		local arc1_b = ImAcos01(1 - (rect.Max.x - p1.x) * inv_rounding)
		local arc1_e = ImAcos01(1 - (rect.Max.x - p0.x) * inv_rounding)
		local x1 = min(p1.x, rect.Max.x - rounding)
		if arc1_b == arc1_e then
			draw_list:PathLineTo(vcreate(x1, p0.y, 0))
			draw_list:PathLineTo(vcreate(x1, p1.y, 0))
		elseif arc1_b == 0 and arc1_e == half_pi then
			draw_list:PathArcToFast(vcreate(x1, p0.y + rounding, 0), rounding, 9, 12)
			draw_list:PathArcToFast(vcreate(x1, p1.y - rounding, 0), rounding, 0, 3)
		else
			draw_list:PathArcTo(vcreate(x1, p0.y + rounding, 0), rounding, -arc1_e, -arc1_b)
			draw_list:PathArcTo(vcreate(x1, p1.y - rounding, 0), rounding, arc1_b, arc1_e)
		end
	end
	draw_list:PathFillConvex(col, DF_JoinMiter)
end

function ImGui.RenderRectFilledWithHole(draw_list, outer, inner, col, rounding)
	local fill_L = inner.Min.x > outer.Min.x
	local fill_R = inner.Max.x < outer.Max.x
	local fill_U = inner.Min.y > outer.Min.y
	local fill_D = inner.Max.y < outer.Max.y
	if fill_L then
		draw_list:AddRectFilled(vcreate(outer.Min.x, inner.Min.y, 0), vcreate(inner.Min.x, inner.Max.y, 0), col, rounding, bor(DF_RoundNone, if fill_U then 0 else DF_RoundTopLeft, if fill_D then 0 else DF_RoundBottomLeft))
	end
	if fill_R then
		draw_list:AddRectFilled(vcreate(inner.Max.x, inner.Min.y, 0), vcreate(outer.Max.x, inner.Max.y, 0), col, rounding, bor(DF_RoundNone, if fill_U then 0 else DF_RoundTopRight, if fill_D then 0 else DF_RoundBottomRight))
	end
	if fill_U then
		draw_list:AddRectFilled(vcreate(inner.Min.x, outer.Min.y, 0), vcreate(inner.Max.x, inner.Min.y, 0), col, rounding, bor(DF_RoundNone, if fill_L then 0 else DF_RoundTopLeft, if fill_R then 0 else DF_RoundTopRight))
	end
	if fill_D then
		draw_list:AddRectFilled(vcreate(inner.Min.x, inner.Max.y, 0), vcreate(inner.Max.x, outer.Max.y, 0), col, rounding, bor(DF_RoundNone, if fill_L then 0 else DF_RoundBottomLeft, if fill_R then 0 else DF_RoundBottomRight))
	end
	if fill_L and fill_U then
		draw_list:AddRectFilled(vcreate(outer.Min.x, outer.Min.y, 0), vcreate(inner.Min.x, inner.Min.y, 0), col, rounding, DF_RoundTopLeft)
	end
	if fill_R and fill_U then
		draw_list:AddRectFilled(vcreate(inner.Max.x, outer.Min.y, 0), vcreate(outer.Max.x, inner.Min.y, 0), col, rounding, DF_RoundTopRight)
	end
	if fill_L and fill_D then
		draw_list:AddRectFilled(vcreate(outer.Min.x, inner.Max.y, 0), vcreate(inner.Min.x, outer.Max.y, 0), col, rounding, DF_RoundBottomLeft)
	end
	if fill_R and fill_D then
		draw_list:AddRectFilled(vcreate(inner.Max.x, inner.Max.y, 0), vcreate(outer.Max.x, outer.Max.y, 0), col, rounding, DF_RoundBottomRight)
	end
end

function ImGui.CalcRoundingFlagsForRectInRect(r_in, r_outer, threshold)
	local round_l = r_in.Min.x <= r_outer.Min.x + threshold
	local round_r = r_in.Max.x >= r_outer.Max.x - threshold
	local round_t = r_in.Min.y <= r_outer.Min.y + threshold
	local round_b = r_in.Max.y >= r_outer.Max.y - threshold
	return bor(
		DF_RoundNone,
		if round_t and round_l then DF_RoundTopLeft else 0,
		if round_t and round_r then DF_RoundTopRight else 0,
		if round_b and round_l then DF_RoundBottomLeft else 0,
		if round_b and round_r then DF_RoundBottomRight else 0
	)
end

function ImGui.RenderColorRectWithAlphaCheckerboard(draw_list, p_min, p_max, col, alpha, grid_step, grid_off, rounding, flags)
	if rounding == nil then
		rounding = 0
	end
	if flags == nil then
		flags = 0
	end
	if band(flags, DF_RoundMask) == 0 then
		flags = DF_RoundAll
	end
	if rshift(band(col, IM_COL32_A_MASK), 24) < 0xFF then
		assert(alpha >= 0 and alpha <= 1)
		local a_mask = lshift(trunc(alpha * 255), 24)
		local col_bg1 = bor(band(Base.ImAlphaBlendColors(Base.IM_COL32(128, 128, 128, 255), col), bnot(IM_COL32_A_MASK)), a_mask)
		local col_bg2 = bor(band(Base.ImAlphaBlendColors(Base.IM_COL32(204, 204, 204, 255), col), bnot(IM_COL32_A_MASK)), a_mask)
		local dual_layer = alpha == 1
		if dual_layer then
			draw_list:AddRectFilled(p_min, p_max, col_bg1, rounding, flags)
		end
		local yi = 0
		local y = p_min.y + grid_off.y
		while y < p_max.y do
			local y1 = math.clamp(trunc(y), p_min.y, p_max.y)
			local y2 = min(trunc(y + grid_step), p_max.y)
			if y2 > y1 then
				local x_start_off = if dual_layer then band(bit32.bxor(yi, 1), 1) * grid_step else 0
				local x_step = if dual_layer then grid_step * 2 else grid_step
				local xi = 0
				local x = p_min.x + grid_off.x + x_start_off
				while x < p_max.x do
					local x1 = math.clamp(trunc(x), p_min.x, p_max.x)
					local x2 = min(trunc(x + grid_step), p_max.x)
					if x2 > x1 then
						local cell_flags = DF_RoundNone
						if y1 <= p_min.y then
							if x1 <= p_min.x then
								cell_flags = bor(cell_flags, DF_RoundTopLeft)
							end
							if x2 >= p_max.x then
								cell_flags = bor(cell_flags, DF_RoundTopRight)
							end
						end
						if y2 >= p_max.y then
							if x1 <= p_min.x then
								cell_flags = bor(cell_flags, DF_RoundBottomLeft)
							end
							if x2 >= p_max.x then
								cell_flags = bor(cell_flags, DF_RoundBottomRight)
							end
						end
						cell_flags = if flags == DF_RoundNone or cell_flags == DF_RoundNone then DF_RoundNone else band(cell_flags, flags)
						local col_bg = if dual_layer then col_bg2 elseif band(yi + xi, 1) ~= 0 then col_bg2 else col_bg1
						draw_list:AddRectFilled(vcreate(x1, y1, 0), vcreate(x2, y2, 0), col_bg, rounding, cell_flags)
					end
					x += x_step
					xi += 1
				end
			end
			y += grid_step
			yi += 1
		end
	else
		draw_list:AddRectFilled(p_min, p_max, col, rounding, flags)
	end
end

local function Lerp4(a, b, t)
	return ImVec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t)
end

function ImGui.StyleColorsDark(dst)
	local style = if dst ~= nil then dst else ImGui.GetStyle()
	local colors = style.Colors
	colors[ImGuiCol.Text + 1] = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[ImGuiCol.TextDisabled + 1] = ImVec4(0.58, 0.58, 0.58, 1.00)
	colors[ImGuiCol.WindowBg + 1] = ImVec4(0.18, 0.18, 0.18, 1.00)
	colors[ImGuiCol.ChildBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.PopupBg + 1] = ImVec4(0.08, 0.08, 0.08, 0.94)
	colors[ImGuiCol.Border + 1] = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[ImGuiCol.BorderShadow + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.FrameBg + 1] = ImVec4(0.10, 0.10, 0.10, 1.00)
	colors[ImGuiCol.FrameBgHovered + 1] = ImVec4(0.19, 0.25, 0.31, 1.00)
	colors[ImGuiCol.FrameBgActive + 1] = ImVec4(0.21, 0.33, 0.47, 1.00)
	colors[ImGuiCol.TitleBg + 1] = ImVec4(0.04, 0.04, 0.04, 1.00)
	colors[ImGuiCol.TitleBgActive + 1] = ImVec4(0.16, 0.29, 0.48, 1.00)
	colors[ImGuiCol.TitleBgCollapsed + 1] = ImVec4(0.00, 0.00, 0.00, 0.51)
	colors[ImGuiCol.MenuBarBg + 1] = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[ImGuiCol.ScrollbarBg + 1] = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[ImGuiCol.ScrollbarGrab + 1] = ImVec4(0.31, 0.31, 0.31, 1.00)
	colors[ImGuiCol.ScrollbarGrabHovered + 1] = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[ImGuiCol.ScrollbarGrabActive + 1] = ImVec4(0.51, 0.51, 0.51, 1.00)
	colors[ImGuiCol.CheckMark + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.CheckboxSelectedBg + 1] = Lerp4(colors[ImGuiCol.FrameBg + 1], colors[ImGuiCol.FrameBgHovered + 1], 0.65)
	colors[ImGuiCol.SliderGrab + 1] = ImVec4(0.24, 0.52, 0.88, 1.00)
	colors[ImGuiCol.SliderGrabActive + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.Button + 1] = ImVec4(0.26, 0.59, 0.98, 0.40)
	colors[ImGuiCol.ButtonHovered + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.ButtonActive + 1] = ImVec4(0.06, 0.53, 0.98, 1.00)
	colors[ImGuiCol.Header + 1] = ImVec4(0.26, 0.59, 0.98, 0.31)
	colors[ImGuiCol.HeaderHovered + 1] = ImVec4(0.26, 0.59, 0.98, 0.80)
	colors[ImGuiCol.HeaderActive + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.Separator + 1] = colors[ImGuiCol.Border + 1]
	colors[ImGuiCol.SeparatorHovered + 1] = ImVec4(0.10, 0.40, 0.75, 0.78)
	colors[ImGuiCol.SeparatorActive + 1] = ImVec4(0.10, 0.40, 0.75, 1.00)
	colors[ImGuiCol.ResizeGrip + 1] = ImVec4(0.26, 0.59, 0.98, 0.20)
	colors[ImGuiCol.ResizeGripHovered + 1] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[ImGuiCol.ResizeGripActive + 1] = ImVec4(0.26, 0.59, 0.98, 0.95)
	colors[ImGuiCol.InputTextCursor + 1] = colors[ImGuiCol.Text + 1]
	colors[ImGuiCol.TabHovered + 1] = colors[ImGuiCol.HeaderHovered + 1]
	colors[ImGuiCol.Tab + 1] = Lerp4(colors[ImGuiCol.Header + 1], colors[ImGuiCol.TitleBgActive + 1], 0.80)
	colors[ImGuiCol.TabSelected + 1] = Lerp4(colors[ImGuiCol.HeaderActive + 1], colors[ImGuiCol.TitleBgActive + 1], 0.60)
	colors[ImGuiCol.TabSelectedOverline + 1] = colors[ImGuiCol.HeaderActive + 1]
	colors[ImGuiCol.TabDimmed + 1] = Lerp4(colors[ImGuiCol.Tab + 1], colors[ImGuiCol.TitleBg + 1], 0.80)
	colors[ImGuiCol.TabDimmedSelected + 1] = Lerp4(colors[ImGuiCol.TabSelected + 1], colors[ImGuiCol.TitleBg + 1], 0.40)
	colors[ImGuiCol.TabDimmedSelectedOverline + 1] = ImVec4(0.50, 0.50, 0.50, 0.00)
	colors[ImGuiCol.PlotLines + 1] = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[ImGuiCol.PlotLinesHovered + 1] = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[ImGuiCol.PlotHistogram + 1] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[ImGuiCol.PlotHistogramHovered + 1] = ImVec4(1.00, 0.60, 0.00, 1.00)
	colors[ImGuiCol.TableHeaderBg + 1] = ImVec4(0.28, 0.28, 0.29, 1.00)
	colors[ImGuiCol.TableBorderStrong + 1] = ImVec4(0.40, 0.40, 0.45, 1.00)
	colors[ImGuiCol.TableBorderLight + 1] = ImVec4(0.32, 0.32, 0.34, 1.00)
	colors[ImGuiCol.TableRowBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.TableRowBgAlt + 1] = ImVec4(1.00, 1.00, 1.00, 0.06)
	colors[ImGuiCol.TextLink + 1] = colors[ImGuiCol.HeaderActive + 1]
	colors[ImGuiCol.TextSelectedBg + 1] = ImVec4(0.26, 0.59, 0.98, 0.35)
	colors[ImGuiCol.TreeLines + 1] = colors[ImGuiCol.Border + 1]
	colors[ImGuiCol.DragDropTarget + 1] = ImVec4(1.00, 1.00, 0.00, 0.90)
	colors[ImGuiCol.DragDropTargetBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.UnsavedMarker + 1] = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[ImGuiCol.NavCursor + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.NavWindowingHighlight + 1] = ImVec4(1.00, 1.00, 1.00, 0.70)
	colors[ImGuiCol.NavWindowingDimBg + 1] = ImVec4(0.80, 0.80, 0.80, 0.20)
	colors[ImGuiCol.ModalWindowDimBg + 1] = ImVec4(0.80, 0.80, 0.80, 0.35)
end

function ImGui.StyleColorsClassic(dst)
	local style = if dst ~= nil then dst else ImGui.GetStyle()
	local colors = style.Colors
	colors[ImGuiCol.Text + 1] = ImVec4(0.90, 0.90, 0.90, 1.00)
	colors[ImGuiCol.TextDisabled + 1] = ImVec4(0.60, 0.60, 0.60, 1.00)
	colors[ImGuiCol.WindowBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.85)
	colors[ImGuiCol.ChildBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.PopupBg + 1] = ImVec4(0.11, 0.11, 0.14, 0.92)
	colors[ImGuiCol.Border + 1] = ImVec4(0.50, 0.50, 0.50, 0.50)
	colors[ImGuiCol.BorderShadow + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.FrameBg + 1] = ImVec4(0.43, 0.43, 0.43, 0.39)
	colors[ImGuiCol.FrameBgHovered + 1] = ImVec4(0.47, 0.47, 0.69, 0.40)
	colors[ImGuiCol.FrameBgActive + 1] = ImVec4(0.42, 0.41, 0.64, 0.69)
	colors[ImGuiCol.TitleBg + 1] = ImVec4(0.27, 0.27, 0.54, 0.83)
	colors[ImGuiCol.TitleBgActive + 1] = ImVec4(0.32, 0.32, 0.63, 0.87)
	colors[ImGuiCol.TitleBgCollapsed + 1] = ImVec4(0.40, 0.40, 0.80, 0.20)
	colors[ImGuiCol.MenuBarBg + 1] = ImVec4(0.40, 0.40, 0.55, 0.80)
	colors[ImGuiCol.ScrollbarBg + 1] = ImVec4(0.20, 0.25, 0.30, 0.60)
	colors[ImGuiCol.ScrollbarGrab + 1] = ImVec4(0.40, 0.40, 0.80, 0.30)
	colors[ImGuiCol.ScrollbarGrabHovered + 1] = ImVec4(0.40, 0.40, 0.80, 0.40)
	colors[ImGuiCol.ScrollbarGrabActive + 1] = ImVec4(0.41, 0.39, 0.80, 0.60)
	colors[ImGuiCol.CheckMark + 1] = ImVec4(0.90, 0.90, 0.90, 0.50)
	colors[ImGuiCol.CheckboxSelectedBg + 1] = Lerp4(colors[ImGuiCol.FrameBg + 1], colors[ImGuiCol.FrameBgActive + 1], 0.65)
	colors[ImGuiCol.SliderGrab + 1] = ImVec4(1.00, 1.00, 1.00, 0.30)
	colors[ImGuiCol.SliderGrabActive + 1] = ImVec4(0.41, 0.39, 0.80, 0.60)
	colors[ImGuiCol.Button + 1] = ImVec4(0.35, 0.40, 0.61, 0.62)
	colors[ImGuiCol.ButtonHovered + 1] = ImVec4(0.40, 0.48, 0.71, 0.79)
	colors[ImGuiCol.ButtonActive + 1] = ImVec4(0.46, 0.54, 0.80, 1.00)
	colors[ImGuiCol.Header + 1] = ImVec4(0.40, 0.40, 0.90, 0.45)
	colors[ImGuiCol.HeaderHovered + 1] = ImVec4(0.45, 0.45, 0.90, 0.80)
	colors[ImGuiCol.HeaderActive + 1] = ImVec4(0.53, 0.53, 0.87, 0.80)
	colors[ImGuiCol.Separator + 1] = ImVec4(0.50, 0.50, 0.50, 0.60)
	colors[ImGuiCol.SeparatorHovered + 1] = ImVec4(0.60, 0.60, 0.70, 1.00)
	colors[ImGuiCol.SeparatorActive + 1] = ImVec4(0.70, 0.70, 0.90, 1.00)
	colors[ImGuiCol.ResizeGrip + 1] = ImVec4(1.00, 1.00, 1.00, 0.10)
	colors[ImGuiCol.ResizeGripHovered + 1] = ImVec4(0.78, 0.82, 1.00, 0.60)
	colors[ImGuiCol.ResizeGripActive + 1] = ImVec4(0.78, 0.82, 1.00, 0.90)
	colors[ImGuiCol.InputTextCursor + 1] = colors[ImGuiCol.Text + 1]
	colors[ImGuiCol.TabHovered + 1] = colors[ImGuiCol.HeaderHovered + 1]
	colors[ImGuiCol.Tab + 1] = Lerp4(colors[ImGuiCol.Header + 1], colors[ImGuiCol.TitleBgActive + 1], 0.80)
	colors[ImGuiCol.TabSelected + 1] = Lerp4(colors[ImGuiCol.HeaderActive + 1], colors[ImGuiCol.TitleBgActive + 1], 0.60)
	colors[ImGuiCol.TabSelectedOverline + 1] = colors[ImGuiCol.HeaderActive + 1]
	colors[ImGuiCol.TabDimmed + 1] = Lerp4(colors[ImGuiCol.Tab + 1], colors[ImGuiCol.TitleBg + 1], 0.80)
	colors[ImGuiCol.TabDimmedSelected + 1] = Lerp4(colors[ImGuiCol.TabSelected + 1], colors[ImGuiCol.TitleBg + 1], 0.40)
	colors[ImGuiCol.TabDimmedSelectedOverline + 1] = ImVec4(0.53, 0.53, 0.87, 0.00)
	colors[ImGuiCol.PlotLines + 1] = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[ImGuiCol.PlotLinesHovered + 1] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[ImGuiCol.PlotHistogram + 1] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[ImGuiCol.PlotHistogramHovered + 1] = ImVec4(1.00, 0.60, 0.00, 1.00)
	colors[ImGuiCol.TableHeaderBg + 1] = ImVec4(0.27, 0.27, 0.38, 1.00)
	colors[ImGuiCol.TableBorderStrong + 1] = ImVec4(0.31, 0.31, 0.45, 1.00)
	colors[ImGuiCol.TableBorderLight + 1] = ImVec4(0.26, 0.26, 0.28, 1.00)
	colors[ImGuiCol.TableRowBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.TableRowBgAlt + 1] = ImVec4(1.00, 1.00, 1.00, 0.07)
	colors[ImGuiCol.TextLink + 1] = colors[ImGuiCol.HeaderActive + 1]
	colors[ImGuiCol.TextSelectedBg + 1] = ImVec4(0.00, 0.00, 1.00, 0.35)
	colors[ImGuiCol.TreeLines + 1] = colors[ImGuiCol.Border + 1]
	colors[ImGuiCol.DragDropTarget + 1] = ImVec4(1.00, 1.00, 0.00, 0.90)
	colors[ImGuiCol.DragDropTargetBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.UnsavedMarker + 1] = ImVec4(0.90, 0.90, 0.90, 1.00)
	colors[ImGuiCol.NavCursor + 1] = colors[ImGuiCol.HeaderHovered + 1]
	colors[ImGuiCol.NavWindowingHighlight + 1] = ImVec4(1.00, 1.00, 1.00, 0.70)
	colors[ImGuiCol.NavWindowingDimBg + 1] = ImVec4(0.80, 0.80, 0.80, 0.20)
	colors[ImGuiCol.ModalWindowDimBg + 1] = ImVec4(0.20, 0.20, 0.20, 0.35)
end

function ImGui.StyleColorsLight(dst)
	local style = if dst ~= nil then dst else ImGui.GetStyle()
	local colors = style.Colors
	colors[ImGuiCol.Text + 1] = ImVec4(0.00, 0.00, 0.00, 1.00)
	colors[ImGuiCol.TextDisabled + 1] = ImVec4(0.60, 0.60, 0.60, 1.00)
	colors[ImGuiCol.WindowBg + 1] = ImVec4(0.94, 0.94, 0.94, 1.00)
	colors[ImGuiCol.ChildBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.PopupBg + 1] = ImVec4(1.00, 1.00, 1.00, 0.98)
	colors[ImGuiCol.Border + 1] = ImVec4(0.00, 0.00, 0.00, 0.30)
	colors[ImGuiCol.BorderShadow + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.FrameBg + 1] = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[ImGuiCol.FrameBgHovered + 1] = ImVec4(0.26, 0.59, 0.98, 0.40)
	colors[ImGuiCol.FrameBgActive + 1] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[ImGuiCol.TitleBg + 1] = ImVec4(0.82, 0.82, 0.82, 1.00)
	colors[ImGuiCol.TitleBgActive + 1] = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[ImGuiCol.TitleBgCollapsed + 1] = ImVec4(1.00, 1.00, 1.00, 0.43)
	colors[ImGuiCol.MenuBarBg + 1] = ImVec4(0.86, 0.86, 0.86, 1.00)
	colors[ImGuiCol.ScrollbarBg + 1] = ImVec4(0.98, 0.98, 0.98, 0.53)
	colors[ImGuiCol.ScrollbarGrab + 1] = ImVec4(0.69, 0.69, 0.69, 0.80)
	colors[ImGuiCol.ScrollbarGrabHovered + 1] = ImVec4(0.49, 0.49, 0.49, 0.80)
	colors[ImGuiCol.ScrollbarGrabActive + 1] = ImVec4(0.49, 0.49, 0.49, 1.00)
	colors[ImGuiCol.CheckMark + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.CheckboxSelectedBg + 1] = ImVec4(0.95, 0.97, 1.00, 1.00)
	colors[ImGuiCol.SliderGrab + 1] = ImVec4(0.26, 0.59, 0.98, 0.78)
	colors[ImGuiCol.SliderGrabActive + 1] = ImVec4(0.46, 0.54, 0.80, 0.60)
	colors[ImGuiCol.Button + 1] = ImVec4(0.26, 0.59, 0.98, 0.40)
	colors[ImGuiCol.ButtonHovered + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.ButtonActive + 1] = ImVec4(0.06, 0.53, 0.98, 1.00)
	colors[ImGuiCol.Header + 1] = ImVec4(0.26, 0.59, 0.98, 0.31)
	colors[ImGuiCol.HeaderHovered + 1] = ImVec4(0.26, 0.59, 0.98, 0.80)
	colors[ImGuiCol.HeaderActive + 1] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[ImGuiCol.Separator + 1] = ImVec4(0.39, 0.39, 0.39, 0.62)
	colors[ImGuiCol.SeparatorHovered + 1] = ImVec4(0.14, 0.44, 0.80, 0.78)
	colors[ImGuiCol.SeparatorActive + 1] = ImVec4(0.14, 0.44, 0.80, 1.00)
	colors[ImGuiCol.ResizeGrip + 1] = ImVec4(0.35, 0.35, 0.35, 0.17)
	colors[ImGuiCol.ResizeGripHovered + 1] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[ImGuiCol.ResizeGripActive + 1] = ImVec4(0.26, 0.59, 0.98, 0.95)
	colors[ImGuiCol.InputTextCursor + 1] = colors[ImGuiCol.Text + 1]
	colors[ImGuiCol.TabHovered + 1] = colors[ImGuiCol.HeaderHovered + 1]
	colors[ImGuiCol.Tab + 1] = Lerp4(colors[ImGuiCol.Header + 1], colors[ImGuiCol.TitleBgActive + 1], 0.90)
	colors[ImGuiCol.TabSelected + 1] = Lerp4(colors[ImGuiCol.HeaderActive + 1], colors[ImGuiCol.TitleBgActive + 1], 0.60)
	colors[ImGuiCol.TabSelectedOverline + 1] = colors[ImGuiCol.HeaderActive + 1]
	colors[ImGuiCol.TabDimmed + 1] = Lerp4(colors[ImGuiCol.Tab + 1], colors[ImGuiCol.TitleBg + 1], 0.80)
	colors[ImGuiCol.TabDimmedSelected + 1] = Lerp4(colors[ImGuiCol.TabSelected + 1], colors[ImGuiCol.TitleBg + 1], 0.40)
	colors[ImGuiCol.TabDimmedSelectedOverline + 1] = ImVec4(0.26, 0.59, 1.00, 0.00)
	colors[ImGuiCol.PlotLines + 1] = ImVec4(0.39, 0.39, 0.39, 1.00)
	colors[ImGuiCol.PlotLinesHovered + 1] = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[ImGuiCol.PlotHistogram + 1] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[ImGuiCol.PlotHistogramHovered + 1] = ImVec4(1.00, 0.45, 0.00, 1.00)
	colors[ImGuiCol.TableHeaderBg + 1] = ImVec4(0.78, 0.87, 0.98, 1.00)
	colors[ImGuiCol.TableBorderStrong + 1] = ImVec4(0.57, 0.57, 0.64, 1.00)
	colors[ImGuiCol.TableBorderLight + 1] = ImVec4(0.68, 0.68, 0.74, 1.00)
	colors[ImGuiCol.TableRowBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.TableRowBgAlt + 1] = ImVec4(0.30, 0.30, 0.30, 0.09)
	colors[ImGuiCol.TextLink + 1] = colors[ImGuiCol.HeaderActive + 1]
	colors[ImGuiCol.TextSelectedBg + 1] = ImVec4(0.26, 0.59, 0.98, 0.35)
	colors[ImGuiCol.TreeLines + 1] = colors[ImGuiCol.Border + 1]
	colors[ImGuiCol.DragDropTarget + 1] = ImVec4(0.26, 0.59, 0.98, 0.95)
	colors[ImGuiCol.DragDropTargetBg + 1] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[ImGuiCol.UnsavedMarker + 1] = ImVec4(0.00, 0.00, 0.00, 1.00)
	colors[ImGuiCol.NavCursor + 1] = colors[ImGuiCol.HeaderHovered + 1]
	colors[ImGuiCol.NavWindowingHighlight + 1] = ImVec4(0.70, 0.70, 0.70, 0.70)
	colors[ImGuiCol.NavWindowingDimBg + 1] = ImVec4(0.20, 0.20, 0.20, 0.20)
	colors[ImGuiCol.ModalWindowDimBg + 1] = ImVec4(0.20, 0.20, 0.20, 0.35)
end

ImTextInitClassifiers()

DrawList.ImDrawList = ImDrawList
DrawList.ImDrawListSharedData = ImDrawListSharedData
DrawList.ImDrawListSplitter = ImDrawListSplitter
DrawList.ImDrawChannel = ImDrawChannel
DrawList.ImDrawCmd = ImDrawCmd
DrawList.ImDrawCmdHeader = ImDrawCmdHeader
DrawList.ImDrawData = ImDrawData
DrawList.ImDrawDataBuilder = ImDrawDataBuilder
DrawList.ImFont = ImFont
DrawList.ImFontBaked = ImFontBaked
DrawList.ImFontAtlas = ImFontAtlas
DrawList.ImFontAtlasBuilder = ImFontAtlasBuilder
DrawList.ImFontAtlasRect = ImFontAtlasRect
DrawList.ImFontConfig = ImFontConfig
DrawList.ImFontGlyph = ImFontGlyph
DrawList.ImTextureData = ImTextureData
DrawList.ImTriangulator = ImTriangulator
DrawList.ImTextureRefGetTexID = ImTextureRefGetTexID
DrawList.ImBezierCubicCalc = BezierCubicCalc
DrawList.ImBezierQuadraticCalc = BezierQuadraticCalc
DrawList.PrimKind = PrimKind
DrawList.AdvanceForSize = nil
DrawList.PRIM_STRIDE = PRIM_STRIDE

return DrawList
