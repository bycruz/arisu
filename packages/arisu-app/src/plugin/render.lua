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
---@field depthBufferView hood.TextureView
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

local bindings = {
	centralTexture = 0,
	centralSampler = isVulkan and 1 or 0, -- Combine for OpenGL
	dimsBuffer = 2
}

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

	local quadLayout = self.device:createBindGroupLayout({
		{
			type = "texture",
			binding = bindings.centralTexture,
			visibility = { "FRAGMENT" }
		},
		{
			type = "sampler",
			binding = bindings.centralSampler,
			visibility = { "FRAGMENT" }
		},
		{
			type = "buffer",
			binding = bindings.dimsBuffer,
			visibility = { "FRAGMENT" }
		}
	})

	local quadPipeline = self.device:createPipeline({
		layout = quadLayout,
		vertex = {
			module = { type = shaderType, source = require("arisu-app.shaders.main.vert." .. shaderExt) },
			buffers = { vertexDescriptor }
		},
		fragment = {
			module = { type = shaderType, source = require("arisu-app.shaders.main.frag." .. shaderExt) },
			targets = {
				{
					blend = "alpha-blending",
					writeMask = hood.ColorWrites.All,
					format = swapchain.format
				}
			}
		},
		depthStencil = {
			depthWriteEnabled = true,
			depthCompare = "less-equal",
			format = "depth24plus"
		}
	})

	local overlayVertex = self.device:createBuffer({ size = vertexDescriptor:getStride() * 1000, usages = { "VERTEX", "COPY_DST" } })
	local overlayIndex = self.device:createBuffer({ size = ffi.sizeof("uint32_t") * 1000, usages = { "INDEX", "COPY_DST" } })

	local overlayVertexDescriptor = VertexLayout
		.new()
		:withAttribute({ type = "f32", size = 3, offset = 0 }) -- position (vec3)
		:withAttribute({ type = "f32", size = 4, offset = 12 }) -- color (rgba)
		:withAttribute({ type = "f32", size = 2, offset = 28 }) -- uv

	local overlayLayout = self.device:createBindGroupLayout({
		{
			type = "buffer",
			binding = 0,
			visibility = { "FRAGMENT" }
		}
	})

	local overlayPipeline = self.device:createPipeline({
		layout = overlayLayout,
		vertex = {
			module = { type = shaderType, source = require("arisu.shaders.overlay.vert." .. shaderExt) },
			buffers = { overlayVertexDescriptor }
		},
		fragment = {
			module = { type = shaderType, source = require("arisu.shaders.overlay.frag." .. shaderExt) },
			targets = {
				{
					blend = "alpha-blending",
					writeMask = hood.ColorWrites.All,
					format = "rgba8unorm"
				}
			}
		}
	})

	local depthBuffer = self.device:createTexture({
		extents = { dim = "2d", width = window.width, height = window.height },
		format = "depth24plus",
		usages = { "RENDER_ATTACHMENT" }
	})

	-- Initialize shared resources
	if not self.mainCtx then
		local textureManager = TextureManager.new(self.device)

		local bindGroupLayout = textureManager:createBindGroupLayout(
			bindings.centralTexture,
			bindings.centralSampler,
			bindings.dimsBuffer
		)

		local bindGroup = textureManager:createBindGroup(
			bindGroupLayout,
			bindings.centralTexture,
			bindings.centralSampler,
			bindings.dimsBuffer
		)

		local fontManager = FontManager.new(textureManager)

		self.sharedResources = {
			bindGroup = bindGroup,
			bindGroupLayout = bindGroupLayout,
			textureManager = textureManager,
			fontManager = fontManager
		}
	end

	---@type arisu.plugin.Render.Context
	local ctx = {
		window = window,
		swapchain = swapchain,
		quadBindGroupLayout = quadLayout,
		quadPipeline = quadPipeline,
		quadVertex = quadVertex,
		quadIndex = quadIndex,
		overlayBindGroupLayout = overlayLayout,
		overlayPipeline = overlayPipeline,
		overlayVertex = overlayVertex,
		overlayIndex = overlayIndex,
		nIndices = 0,
		depthBuffer = depthBuffer,
		depthBufferView = depthBuffer:createView({})
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
	local texture = ctx.swapchain:getCurrentTexture()
	if not texture then
		local windowCtx = assert(self.windowPlugin:getContext(ctx.window))
		local ctx = self:getContext(ctx.window)
		ctx.swapchain = windowCtx.surface:configure(self.device, { presentMode = "fifo" }, ctx.swapchain)

		return
	end

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
						a = 1
					}
				},
				texture = texture:createView({})
			}
		},
		depthStencilAttachment = {
			op = { type = "clear", depth = 1 },
			texture = ctx.depthBufferView
		}
	})
	encoder:setPipeline(ctx.quadPipeline)
	encoder:setBindGroup(0, self.sharedResources.bindGroup)
	encoder:setViewport(0, 0, ctx.window.width, ctx.window.height)
	encoder:setVertexBuffer(0, ctx.quadVertex)
	encoder:setIndexBuffer(ctx.quadIndex, "u32")
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
		-- local windowCtx = assert(self.windowPlugin:getContext(event.window))
		-- local ctx = self:getContext(event.window)
		-- ctx.swapchain = windowCtx.surface:configure(self.device, { presentMode = "fifo", oldSwapchain = ctx.swapchain })

		if ffi.os == "Windows" then
			handler:requestRedraw(event.window)
		end
	end
end

return RenderPlugin
