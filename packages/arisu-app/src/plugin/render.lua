local ffi = require("ffi")
local hood = require("hood")

local VertexLayout = require("hood.vertex_layout")
local TextureManager = require("arisu-app.util.texture_manager")
local FontManager = require("arisu-app.util.font_manager")

local isVulkan = os.getenv("VULKAN") and true or false
local shaderType = isVulkan and "spirv" or "glsl"
local shaderExt = isVulkan and "spv" or "glsl"

---@class arisu.plugin.Render.Context
---@field window winit.Window
---@field swapchain hood.Swapchain
---@field quadPipeline hood.Pipeline
---@field quadVertex hood.Buffer
---@field quadIndex hood.Buffer
---@field overlayPipeline hood.Pipeline
---@field overlayVertex hood.Buffer
---@field overlayIndex hood.Buffer
---@field depthBuffer hood.Texture
---@field ui? arisu.Element
---@field layoutTree? arisu.Layout
---@field computedLayout? arisu.ComputedLayout
---@field nIndices number

---@class arisu.plugin.Render.SharedResources
---@field textureManager TextureManager
---@field fontManager FontManager
---@field bindGroup hood.BindGroup

---@class arisu.plugin.Render<Message>: { onWindowCreate: Message }
---@field windowPlugin arisu.plugin.Window<any>
---@field mainCtx arisu.plugin.Render.Context?
---@field contexts table<winit.Window, arisu.plugin.Render.Context>
---@field sharedResources arisu.plugin.Render.SharedResources?
---@field device hood.Device
local RenderPlugin = {}
RenderPlugin.__index = RenderPlugin

---@param windowPlugin arisu.plugin.Window
function RenderPlugin.new(windowPlugin)
	local adapter = windowPlugin.instance:requestAdapter({ powerPreference = "high-performance" })
	local device = adapter:requestDevice()

	return setmetatable({ device = device, contexts = {}, windowPlugin = windowPlugin }, RenderPlugin)
end

---@param window winit.Window
---@param vertexData number[]
---@param indexData number[]
function RenderPlugin:setRenderData(window, vertexData, indexData)
	local ctx = self:getContext(window)

	local vertexSize = ffi.sizeof("float") * #vertexData
	self.device.queue:writeBuffer(ctx.quadVertex, vertexSize, ffi.new("float[?]", #vertexData, vertexData))

	local indexSize = ffi.sizeof("uint32_t") * #indexData
	self.device.queue:writeBuffer(ctx.quadIndex, indexSize, ffi.new("uint32_t[?]", #indexData, indexData))

	ctx.nIndices = #indexData
end

local dirName = debug.getinfo(1, "S").source:sub(2):match("(.*/)")

---@param window winit.Window
function RenderPlugin:register(window)
	local ctx = self.windowPlugin:getContext(window)
	assert(ctx, "Window context not found for render plugin")

	local swapchain = ctx.surface:configure(self.device, { presentMode = "fifo" })

	local vertexDescriptor = VertexLayout
		.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 }) -- position (vec3)
		:withAttribute({ type = "f32", size = 4, offset = 12 }) -- color (rgba)
		:withAttribute({ type = "f32", size = 2, offset = 28 }) -- uv
		:withAttribute({ type = "f32", size = 1, offset = 36 }) -- texture id

	local quadVertex = self.device:createBuffer({ size = vertexDescriptor:getStride() * 100000, usages = { "VERTEX", "COPY_DST" } })
	local quadIndex = self.device:createBuffer({ size = ffi.sizeof("uint32_t") * 10000, usages = { "INDEX", "COPY_DST" } })

	local quadPipeline = self.device:createPipeline({
		vertex = {
			module = { type = shaderType, source = io.open(dirName .. "../shaders/main.vert." .. shaderExt, "rb"):read("*a") },
			buffers = { vertexDescriptor },
		},
		fragment = {
			module = { type = shaderType, source = io.open(dirName .. "../shaders/main.frag." .. shaderExt, "rb"):read("*a") },
			targets = {
				{
					blend = hood.BlendState.AlphaBlending,
					writeMask = hood.ColorWrites.All,
					format = hood.TextureFormat.Rgba8UNorm,
				},
			},
		},
		depthStencil = {
			depthWriteEnabled = true,
			depthCompare = hood.CompareFunction.LessEqual,
			format = hood.TextureFormat.Depth24Plus,
		},
	})

	local overlayVertex = self.device:createBuffer({ size = vertexDescriptor:getStride() * 1000, usages = { "VERTEX", "COPY_DST" } })
	local overlayIndex = self.device:createBuffer({ size = ffi.sizeof("uint32_t") * 1000, usages = { "INDEX", "COPY_DST" } })

	local overlayVertexDescriptor = VertexLayout
		.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 }) -- position (vec3)
		:withAttribute({ type = "f32", size = 4, offset = 12 }) -- color (rgba)
		:withAttribute({ type = "f32", size = 2, offset = 28 }) -- uv

	local overlayPipeline = self.device:createPipeline({
		vertex = {
			module = { type = shaderType, source = io.open("../arisu/shaders/overlay.vert." .. shaderExt, "rb"):read("*a") },
			buffers = { overlayVertexDescriptor },
		},
		fragment = {
			module = { type = shaderType, source = io.open("../arisu/shaders/overlay.frag." .. shaderExt, "rb"):read("*a") },
			targets = {
				{
					blend = hood.BlendState.AlphaBlending,
					writeMask = hood.ColorWrites.All,
					format = hood.TextureFormat.Rgba8UNorm,
				},
			},
		},
	})

	local depthBuffer = self.device:createTexture({
		extents = { dim = "2d", width = window.width, height = window.height },
		format = hood.TextureFormat.Depth24Plus,
		usages = { "RENDER_ATTACHMENT" },
	})

	-- Initialize shared resources
	if not self.mainCtx then
		local textureManager = TextureManager.new(self.device)
		local bindGroup = textureManager:createBindGroup(0, 0, 1)
		local fontManager = FontManager.new(textureManager)

		self.sharedResources = {
			bindGroup = bindGroup,
			textureManager = textureManager,
			fontManager = fontManager,
		}
	end

	---@type arisu.plugin.Render.Context
	local ctx = {
		window = window,
		swapchain = swapchain,
		quadPipeline = quadPipeline,
		quadVertex = quadVertex,
		quadIndex = quadIndex,
		overlayPipeline = overlayPipeline,
		overlayVertex = overlayVertex,
		overlayIndex = overlayIndex,
		nIndices = 0,
		depthBuffer = depthBuffer,
	}

	self.contexts[window] = ctx
	return ctx
end

--- SAFETY: Returns non-nil as we will assume user registers all windows properly :)
function RenderPlugin:getContext(window)
	return self.contexts[window]
end

---@param ctx arisu.plugin.Render.Context
function RenderPlugin:draw(ctx)
	local encoder = self.device:createCommandEncoder()
	encoder:beginRendering({
		colorAttachments = {
			{
				op = {
					type = "clear",
					color = {
						r = (math.sin(os.clock()) + 1) / 2,
						g = 0,
						b = (math.cos(os.clock()) + 1) / 2,
						a = 1,
					},
				},
				texture = ctx.swapchain:getCurrentTexture(),
			},
		},
		depthStencilAttachment = {
			op = { type = "clear", depth = 1 },
			texture = ctx.depthBuffer,
		},
	})
	encoder:setPipeline(ctx.quadPipeline)
	encoder:setBindGroup(0, self.sharedResources.bindGroup)
	encoder:setViewport(0, 0, ctx.window.width, ctx.window.height)
	encoder:setVertexBuffer(0, ctx.quadVertex)
	encoder:setIndexBuffer(ctx.quadIndex, hood.IndexType.u32)
	encoder:drawIndexed(ctx.nIndices, 1)
	encoder:endRendering()

	local commandBuffer = encoder:finish()
	self.device.queue:submit(commandBuffer, ctx.swapchain)
	self.device.queue:present(ctx.swapchain)
end

---@param event winit.Event
---@param handler winit.EventManager
function RenderPlugin:event(event, handler)
	if event.name == "resize" then
		local ctx = self:getContext(event.window)
		-- ctx.swapchain.ctx:makeCurrent()
		-- gl.viewport(0, 0, ctx.window.width, ctx.window.height)

		if ffi.os == "Windows" then
			handler:requestRedraw(event.window)
		end
	end
end

return RenderPlugin
