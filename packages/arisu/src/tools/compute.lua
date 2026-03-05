local ffi = require("ffi")

local isVulkan = os.getenv("VULKAN") and true or false
local shaderType = isVulkan and "spirv" or "glsl"
local shaderExt = isVulkan and "spv" or "glsl"

local computeSource = io.open("shaders/brush.compute." .. shaderExt, "rb"):read("*a") --[[@as string]]

---@class Compute
---@field pipeline hood.ComputePipeline
---@field inputs ComputeInputs
---@field inputsBuffer hood.Buffer
---@field canvas Texture
---@field temp Texture
---@field textureManager TextureManager
---@field bindGroup hood.BindGroup
---@field device hood.Device
local Compute = {}
Compute.__index = Compute

ffi.cdef([[
typedef struct {
    float color[4];
    float selectTopLeft[2];
    float selectBottomRight[2];
    int32_t center[2];
    int32_t lineEnd[2];
    float radius;
    int32_t tool;
} ComputeInputs;
]])

local sizeofComputeInputs = assert(ffi.sizeof("ComputeInputs"))

---@class ComputeInputs: ffi.cdata*
---@field center number[2]
---@field radius number
---@field color number[4]
---@field tool number
---@field selectTopLeft number[2]
---@field selectBottomRight number[2]
---@field lineEnd number[2]

---@param textureManager TextureManager
---@param canvas number
---@param device hood.Device
function Compute.new(textureManager, canvas, device)
	local inputs = ffi.new("ComputeInputs")

	local inputsBuffer = device:createBuffer({
		size = sizeofComputeInputs,
		usages = { "STORAGE", "COPY_DST" },
	})

	local bindGroupLayout = device:createBindGroupLayout({
		{
			binding = 0,
			type = "storageTexture",
			visibility = { "COMPUTE" },
		},
		{
			binding = 1,
			type = "buffer",
			visibility = { "COMPUTE" },
		},
	})

	local bindGroup = device:createBindGroup({
		layout = bindGroupLayout,
		entries = {
			{
				binding = 0,
				type = "storageTexture",
				texture = textureManager.texture:createView({}),
				visibility = { "COMPUTE" },
				layer = canvas,
				access = "WRITE_ONLY",
			},

			{
				binding = 1,
				type = "buffer",
				buffer = inputsBuffer,
				visibility = { "COMPUTE" },
			},
		},
	})

	local computePipeline = device:createComputePipeline({
		layout = bindGroupLayout,
		module = { type = shaderType, source = computeSource },
	})

	-- TODO: Un-hard code this when canvas is passed as a Texture with width/height
	local tempLayer = textureManager:allocate(800, 600)

	local self = setmetatable({
		device = device,
		textureManager = textureManager,
		canvas = canvas,
		temp = tempLayer,
		pipeline = computePipeline,
		inputs = inputs,
		inputsBuffer = inputsBuffer,
		bindGroup = bindGroup,
	}, Compute)

	self:resetSelection()
	return self
end

local TOOL_BRUSH = 0
local TOOL_ERASER = 1
local TOOL_FILL = 2
local TOOL_LINE = 3
local TOOL_RECTANGLE = 4
local TOOL_CIRCLE = 5

local WORK_GROUP_SIZE = 16

function Compute:updateInputs()
	self.device.queue:writeBuffer(self.inputsBuffer, sizeofComputeInputs, self.inputs)
end

function Compute:resetSelection()
	self:setSelection(-1, -1, -1, -1)
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function Compute:setSelection(x1, y1, x2, y2)
	self.inputs.selectTopLeft[0] = x1
	self.inputs.selectTopLeft[1] = y1
	self.inputs.selectBottomRight[0] = x2
	self.inputs.selectBottomRight[1] = y2
end

---@param x number
---@param y number
---@param radius number
---@param color { r: number, g: number, b: number, a: number }
function Compute:stamp(x, y, radius, color)
	self.inputs.center[0] = x
	self.inputs.center[1] = y
	self.inputs.radius = radius
	self.inputs.color[0] = color.r
	self.inputs.color[1] = color.g
	self.inputs.color[2] = color.b
	self.inputs.color[3] = color.a
	self.inputs.tool = TOOL_BRUSH

	local diameter = radius * 2
	local groupsX = math.ceil(diameter / WORK_GROUP_SIZE)
	local groupsY = math.ceil(diameter / WORK_GROUP_SIZE)

	self:updateInputs()
	local encoder = self.device:createCommandEncoder()
	encoder:beginComputePass({})
	encoder:setComputePipeline(self.pipeline)
	encoder:setBindGroup(0, self.bindGroup)
	encoder:dispatchWorkgroups(groupsX, groupsY, 1)
	self.device.queue:submit(encoder:finish())
end

---@param x number
---@param y number
---@param radius number
function Compute:erase(x, y, radius)
	self.inputs.center[0] = x
	self.inputs.center[1] = y
	self.inputs.radius = radius
	self.inputs.tool = TOOL_ERASER

	local diameter = radius * 2
	local groupsX = math.ceil(diameter / WORK_GROUP_SIZE)
	local groupsY = math.ceil(diameter / WORK_GROUP_SIZE)

	self:updateInputs()
	local encoder = self.device:createCommandEncoder()
	encoder:beginComputePass({})
	encoder:setComputePipeline(self.pipeline)
	encoder:setBindGroup(0, self.bindGroup)
	encoder:dispatchWorkgroups(groupsX, groupsY, 1)
	self.device.queue:submit(encoder:finish())
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param thickness number
---@param color { r: number, g: number, b: number, a: number }
function Compute:drawLine(x1, y1, x2, y2, thickness, color)
	self.inputs.center[0] = x1
	self.inputs.center[1] = y1
	self.inputs.lineEnd[0] = x2
	self.inputs.lineEnd[1] = y2
	self.inputs.radius = thickness
	self.inputs.color[0] = color.r
	self.inputs.color[1] = color.g
	self.inputs.color[2] = color.b
	self.inputs.color[3] = color.a
	self.inputs.tool = TOOL_LINE

	local groupsX = math.ceil(800 / WORK_GROUP_SIZE)
	local groupsY = math.ceil(600 / WORK_GROUP_SIZE)

	self:updateInputs()
	local encoder = self.device:createCommandEncoder()
	encoder:beginComputePass({})
	encoder:setComputePipeline(self.pipeline)
	encoder:setBindGroup(0, self.bindGroup)
	encoder:dispatchWorkgroups(groupsX, groupsY, 1)
	self.device.queue:submit(encoder:finish())
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param thickness number
---@param color { r: number, g: number, b: number, a: number }
function Compute:drawRectangle(x1, y1, x2, y2, thickness, color)
	self.inputs.center[0] = x1
	self.inputs.center[1] = y1
	self.inputs.lineEnd[0] = x2
	self.inputs.lineEnd[1] = y2
	self.inputs.radius = thickness
	self.inputs.color[0] = color.r
	self.inputs.color[1] = color.g
	self.inputs.color[2] = color.b
	self.inputs.color[3] = color.a
	self.inputs.tool = TOOL_RECTANGLE

	local groupsX = math.ceil(800 / WORK_GROUP_SIZE)
	local groupsY = math.ceil(600 / WORK_GROUP_SIZE)

	self:updateInputs()
	local encoder = self.device:createCommandEncoder()
	encoder:beginComputePass({})
	encoder:setComputePipeline(self.pipeline)
	encoder:setBindGroup(0, self.bindGroup)
	encoder:dispatchWorkgroups(groupsX, groupsY, 1)
	self.device.queue:submit(encoder:finish())
end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param thickness number
---@param color { r: number, g: number, b: number, a: number }
function Compute:drawEllipse(x1, y1, x2, y2, thickness, color)
	self.inputs.center[0] = x1
	self.inputs.center[1] = y1
	self.inputs.lineEnd[0] = x2
	self.inputs.lineEnd[1] = y2
	self.inputs.radius = thickness
	self.inputs.color[0] = color.r
	self.inputs.color[1] = color.g
	self.inputs.color[2] = color.b
	self.inputs.color[3] = color.a
	self.inputs.tool = TOOL_CIRCLE

	local groupsX = math.ceil(800 / WORK_GROUP_SIZE)
	local groupsY = math.ceil(600 / WORK_GROUP_SIZE)

	self:updateInputs()
	local encoder = self.device:createCommandEncoder()
	encoder:beginComputePass({})
	encoder:setComputePipeline(self.pipeline)
	encoder:setBindGroup(0, self.bindGroup)
	encoder:dispatchWorkgroups(groupsX, groupsY, 1)
	self.device.queue:submit(encoder:finish())
end

return Compute
